/*
 * Counter.java - parallel word counting for calligram (v3.2)
 *
 * Pure Java (no Stata classes), so it can be tested on its own.
 *
 * One thread reads rows (Stata's string reader must be called from a single
 * thread); batches of rows go to worker threads, each keeping one tally for
 * the whole run; tallies are merged once at the end. Memory grows with the
 * number of DISTINCT words, never with the amount of text.
 *
 * Cleaning (unless clean=false):
 *   - Unicode normalisation (NFC), then lower case
 *   - apostrophes are deleted, so "don't" -> "dont"; with French (elision=true)
 *     "l'", "d'", "qu'" etc. are split off instead: "l'entreprise" -> "entreprise"
 *   - a hyphen between two letters or digits stays inside the word
 *     ("sci-fi", "follow-up"); other characters that are not letters or digits
 *     separate words
 * Then tokens made only of digits, tokens shorter than minLength characters,
 * and stopwords are dropped. Without cleaning, words are split on spaces, tabs
 * and line breaks only.
 *
 * Plurals (plurals=true): a word is merged into its singular when the singular
 * also occurs in the text ("delays" -> "delay", "companies" -> "company",
 * "taxes" -> "tax", "follow-ups" -> "follow-up").
 *
 * Two-word phrases (phrases=true, opt-in):
 *   pass 1 counts words and pairs of neighbouring words; a pair is only formed
 *   inside one response, never across punctuation, a stopword or a dropped
 *   token. A pair becomes a phrase if
 *     - it occurs at least phraseMinCount (3) times,
 *     - the evidence that the words go together is significant at the 0.1%
 *       level (Dunning log-likelihood ratio >= 10.83), and
 *     - the strength of the link (normalised pointwise mutual information,
 *       -1..1, which does not grow with the amount of text) is at least
 *       phraseStrength (0.40).
 *   pass 2 counts again, joining accepted phrases into single entries, so the
 *   words of a phrase keep only their other uses.
 *   addPhrases are always joined; dropPhrases never.
 *
 * Weights: every occurrence adds the row's weight to the word's weighted
 * count; raw counts (plain occurrences) are kept as well and used for the
 * statistical tests and for minFreq. Pre-counted input (precounted=true): each
 * row is one word with its count (in weight).
 */
package calligram;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Future;

public final class Counter {

    public static final class Options {
        public boolean clean = true;
        public int minLength = 3;
        public Set<String> stop = new HashSet<>();
        public boolean keepHyphens = true;
        public boolean elision = false;
        public boolean plurals = true;
        public boolean phrases = false;
        public double phraseStrength = 0.40;
        public int phraseMinCount = 3;
        public double phraseEvidence = 10.83;        // chi-square(1) at p = 0.001
        public List<String> addPhrases = new ArrayList<>();
        public List<String> dropPhrases = new ArrayList<>();
        public boolean precounted = false;
        /** colour by a variable: 0 none, 1 numeric (average value per word),
         *  2 categories 1..K (the category that uses the word most, relative
         *  to its size), 3 a colour string per row (first one seen per word) */
        public int colorMode = 0;
        public int K = 0;
    }

    /** Where rows come from. Called from one thread only. */
    public interface RowSource {
        long size();                   // number of candidate rows
        boolean use(long i);           // row selected (if/in, non-missing)?
        String text(long i);
        int group(long i);             // 1..G (1 when there are no groups)
        default double weight(long i) { return 1.0; }
        /** region of the row (pre-counted words only); null if none */
        default String region(long i) { return null; }
        /** colour variable: value (mode 1) or category 1..K (mode 2); NaN if missing */
        default double cvalue(long i) { return Double.NaN; }
        /** colour string of the row (mode 3) */
        default String ccolor(long i) { return null; }
    }

    /** A counted word: weighted count (for sizes) and raw occurrences. */
    public static final class Entry {
        public final String word, region;
        public final double count, raw;
        /** colour information: average value (mode 1), the category the word is
         *  typical of and how many times more often it is used there than
         *  overall (mode 2), colour string (mode 3) */
        public double cval = Double.NaN, cshare = Double.NaN;
        public int ccat = 0;
        public String ccolor = null;
        Entry(String w, double c, double r) { this(w, c, r, null); }
        Entry(String w, double c, double r, String g) { word = w; count = c; raw = r; region = g; }
    }

    /** separates a region from the word in pre-counted keys */
    static final char RSEP = '\u0001';

    /** A joined phrase, for the report. */
    public static final class Phrase {
        public final String phrase;
        public final double count, evidence, strength;
        public final boolean added;
        Phrase(String p, double c, double e, double s, boolean a) { phrase = p; count = c; evidence = e; strength = s; added = a; }
    }

    /** Totals per group. */
    public static final class Totals { public long rows; public double tokens; public double[] catTok; }

    /** raw and weighted counts of one word, by group */
    static final class Cnt {
        final double[] n, w;
        double[] vs, vw;          // colour by a number: sum of weight * value, sum of weight
        double[][] cat;           // colour by categories: weight per group and category
        String col;               // a colour given for the word
        Cnt(int G) { n = new double[G + 1]; w = new double[G + 1]; }
        void add(Cnt o, int G) {
            for (int g = 1; g <= G; g++) { n[g] += o.n[g]; w[g] += o.w[g]; }
            if (o.vs != null) {
                if (vs == null) { vs = new double[G + 1]; vw = new double[G + 1]; }
                for (int g = 1; g <= G; g++) { vs[g] += o.vs[g]; vw[g] += o.vw[g]; }
            }
            if (o.cat != null) {
                if (cat == null) cat = new double[G + 1][];
                for (int g = 1; g <= G; g++) {
                    if (o.cat[g] == null) continue;
                    if (cat[g] == null) cat[g] = new double[o.cat[g].length];
                    for (int k = 0; k < o.cat[g].length; k++) cat[g][k] += o.cat[g][k];
                }
            }
            if (col == null) col = o.col;
        }
        double rawTotal(int G) { double s = 0; for (int g = 1; g <= G; g++) s += n[g]; return s; }
    }

    private static final Set<String> ELIDE = new HashSet<>(java.util.Arrays.asList(
        "l", "d", "j", "m", "n", "s", "t", "c", "qu", "jusqu", "lorsqu", "puisqu", "quoiqu"));

    private final Options o;
    public final List<String> notes = new ArrayList<>();

    public Counter(Options o) {
        this.o = o;
        Set<String> lower = new HashSet<>();
        for (String s : o.stop) lower.add(s.toLowerCase(Locale.ROOT));
        o.stop = lower;
    }

    // ── tokenising one text into a stream of words; null marks a break ───────

    private static boolean isNumber(int cp) {
        int t = Character.getType(cp);
        return t == Character.DECIMAL_DIGIT_NUMBER || t == Character.LETTER_NUMBER || t == Character.OTHER_NUMBER;
    }
    private static boolean isWordChar(int cp) { return cp >= 0 && (Character.isLetter(cp) || isNumber(cp)); }
    private static boolean isApostrophe(int cp) { return cp == '\'' || cp == 0x2018 || cp == 0x2019; }
    private static boolean isHyphen(int cp) { return cp == '-' || cp == 0x2010 || cp == 0x2011; }
    private static boolean isSpace(int cp) { return cp == ' ' || cp == '\t' || cp == '\n' || cp == '\r'; }

    /** The words of a text, in order, with null wherever a pair may not span
     *  (punctuation, a stopword, or a dropped token). */
    List<String> tokens(String text) {
        List<String> out = new ArrayList<>();
        if (text == null || text.isEmpty()) return out;
        if (!o.clean) {
            int len = text.length(), start = -1;
            for (int i = 0; i <= len; i++) {
                boolean sp = i == len || isSpace(text.charAt(i));
                if (!sp && start < 0) start = i;
                if (sp && start >= 0) { emit(out, text.substring(start, i)); start = -1; }
            }
            return out;
        }
        String s = text;
        if (!Normalizer.isNormalized(s, Normalizer.Form.NFC)) s = Normalizer.normalize(s, Normalizer.Form.NFC);
        s = s.toLowerCase(Locale.ROOT);
        StringBuilder tok = new StringBuilder(24);
        int len = s.length();
        int prev = -1;                                   // last code point added to tok
        for (int i = 0; i < len; ) {
            int cp = s.codePointAt(i);
            int step = Character.charCount(cp);
            int next = i + step < len ? s.codePointAt(i + step) : -1;
            if (isWordChar(cp)) {
                tok.appendCodePoint(cp); prev = cp;
            } else if (isApostrophe(cp)) {
                if (o.elision && isWordChar(next) && ELIDE.contains(tok.toString())) {
                    emit(out, tok.toString()); tok.setLength(0); prev = -1;   // French: l'entreprise
                }
                // otherwise deleted: "don't" -> "dont"
            } else if (o.keepHyphens && isHyphen(cp) && tok.length() > 0 && isWordChar(prev) && isWordChar(next)) {
                tok.append('-'); prev = '-';
            } else {
                if (tok.length() > 0) { emit(out, tok.toString()); tok.setLength(0); prev = -1; }
                if (!isSpace(cp)) out.add(null);           // punctuation: pairs may not span it
            }
            i += step;
        }
        if (tok.length() > 0) emit(out, tok.toString());
        return out;
    }

    private void emit(List<String> out, String w) {
        int cps = w.codePointCount(0, w.length());
        boolean digits = true;
        for (int i = 0; i < w.length(); ) {
            int cp = w.codePointAt(i);
            if (!isNumber(cp) && !isHyphen(cp)) { digits = false; break; }
            i += Character.charCount(cp);
        }
        String key = o.clean ? w : w.toLowerCase(Locale.ROOT);
        if (digits || cps < o.minLength || o.stop.contains(key)) out.add(null);
        else out.add(w);
    }

    /** A phrase given by the user, cleaned like the text: two words, or null. */
    String cleanPhrase(String p) {
        List<String> t = tokens(p);
        List<String> w = new ArrayList<>();
        for (String x : t) if (x != null) w.add(x);
        if (w.size() != 2 || t.size() != 2) return null;
        return w.get(0) + " " + w.get(1);
    }

    // ── plurals ──────────────────────────────────────────────────────────────

    /** words that only look plural */
    static final Set<String> NOT_PLURAL = new HashSet<>(java.util.Arrays.asList(
        "news", "series", "species", "means", "goods", "thanks", "physics", "economics", "politics",
        "mathematics", "statistics", "ethics", "athletics", "electronics", "logistics", "analytics",
        "lens", "bias", "gas", "chaos", "pants", "jeans", "glasses", "clothes", "headquarters",
        "premises", "savings", "earnings", "proceeds", "arrears", "outskirts", "surroundings",
        "belongings", "whereabouts", "species", "diabetes", "measles", "billiards", "aids"));

    /** plural -> singular, only where the singular occurs in vocab */
    static Map<String, String> pluralMap(Set<String> vocab) {
        Map<String, String> m = new HashMap<>();
        for (String w : vocab) {
            if (w.indexOf(' ') >= 0 || w.length() < 4 || NOT_PLURAL.contains(w)) continue;
            String s = null;
            if (w.endsWith("ies") && w.length() > 4) {
                String c = w.substring(0, w.length() - 3) + "y";
                if (vocab.contains(c)) s = c;
            }
            if (s == null && w.endsWith("es")) {
                String stem = w.substring(0, w.length() - 2);
                if ((stem.endsWith("s") || stem.endsWith("x") || stem.endsWith("z") || stem.endsWith("ch") || stem.endsWith("sh"))
                    && vocab.contains(stem)) s = stem;
            }
            if (s == null && w.endsWith("s") && !w.endsWith("ss") && !w.endsWith("us") && !w.endsWith("is")) {
                String c = w.substring(0, w.length() - 1);
                if (vocab.contains(c)) s = c;
            }
            if (s != null) m.put(w, s);
        }
        return m;
    }

    // ── one counting pass ────────────────────────────────────────────────────

    private static final class Batch {
        final String[] texts, regions, colors; final int[] groups; final double[] weights, cvalues; int size;
        Batch(int cap) {
            texts = new String[cap]; regions = new String[cap]; colors = new String[cap];
            groups = new int[cap]; weights = new double[cap]; cvalues = new double[cap];
        }
    }

    /** a tally: words (by group), and optionally pairs of neighbouring words */
    private static final class Partial {
        final Map<String, Cnt> uni = new HashMap<>(1 << 14);
        final Map<String, double[]> pairs;               // raw count, all groups together
        final Map<String, Map<String, Double>> surf = new HashMap<>();   // phrase -> forms seen
        final long[] rows; final double[] tokens;
        double[][] catTok;                               // per group: weighted mentions per category
        Partial(int G, boolean withPairs) {
            rows = new long[G + 1]; tokens = new double[G + 1];
            pairs = withPairs ? new HashMap<>(1 << 14) : null;
        }
    }

    /** settings of one pass */
    private static final class Pass {
        Map<String, Double> join = Collections.emptyMap();   // phrase -> strength (for overlaps)
        Map<String, String> plural = Collections.emptyMap();
        boolean pairs = false;
    }

    private static String canon(Pass ps, String w) { String s = ps.plural.get(w); return s == null ? w : s; }

    /** one mention of a word (weight wt) carries its row's colour information */
    private void colorAdd(Cnt c, int g, double wt, int G, Partial acc, double cv, String col) {
        if (o.colorMode == 1 && !Double.isNaN(cv)) {
            if (c.vs == null) { c.vs = new double[G + 1]; c.vw = new double[G + 1]; }
            c.vs[g] += wt * cv; c.vw[g] += wt;
        } else if (o.colorMode == 2 && !Double.isNaN(cv)) {
            int k = (int) Math.round(cv);
            if (k < 1 || k > o.K) return;
            if (c.cat == null) c.cat = new double[G + 1][];
            if (c.cat[g] == null) c.cat[g] = new double[o.K + 1];
            c.cat[g][k] += wt;
            if (acc.catTok == null) acc.catTok = new double[G + 1][o.K + 1];
            acc.catTok[g][k] += wt;
        } else if (o.colorMode == 3 && col != null && c.col == null) {
            c.col = col;
        }
    }

    private void countText(String text, int g, double wt, int G, Partial acc, Pass ps, String region, double cv, String col) {
        if (o.precounted) {
            String w = text == null ? "" : text.trim();
            if (w.isEmpty() || o.stop.contains(w.toLowerCase(Locale.ROOT))) return;
            if (region != null) w = region + RSEP + w;      // same name, different region: kept apart
            Cnt c = acc.uni.get(w);
            if (c == null) { c = new Cnt(G); acc.uni.put(w, c); }
            c.n[g] += wt; c.w[g] += wt; acc.tokens[g] += wt;
            if (o.colorMode > 0) colorAdd(c, g, wt, G, acc, cv, col);
            return;
        }
        List<String> t = tokens(text);
        int n = t.size();
        for (int i = 0; i < n; i++) {
            String a = t.get(i);
            if (a == null) continue;
            String b = i + 1 < n ? t.get(i + 1) : null;
            String word = a;
            if (b != null && !ps.join.isEmpty()) {
                String key = canon(ps, a) + " " + canon(ps, b);
                Double s = ps.join.get(key);
                if (s != null) {
                    // overlapping phrases (a b c): join the stronger pair
                    String c = i + 2 < n ? t.get(i + 2) : null;
                    Double s2 = c == null ? null : ps.join.get(canon(ps, b) + " " + canon(ps, c));
                    if (s2 == null || s >= s2) {
                        word = key; i++;
                        if (!ps.plural.isEmpty()) acc.surf.computeIfAbsent(key, k -> new HashMap<>()).merge(a + " " + b, 1.0, Double::sum);
                    }
                }
            }
            Cnt cnt = acc.uni.get(word);
            if (cnt == null) { cnt = new Cnt(G); acc.uni.put(word, cnt); }
            cnt.n[g] += 1; cnt.w[g] += wt; acc.tokens[g] += 1;
            if (o.colorMode > 0) colorAdd(cnt, g, wt, G, acc, cv, col);
            if (ps.pairs && word == a && b != null) {
                double[] pc = acc.pairs.get(a + " " + b);
                if (pc == null) acc.pairs.put(a + " " + b, new double[]{1});
                else pc[0]++;
            }
        }
    }

    private void work(Batch b, int G, Partial acc, Pass ps) {
        for (int i = 0; i < b.size; i++) {
            countText(b.texts[i], b.groups[i], b.weights[i], G, acc, ps, b.regions[i], b.cvalues[i], b.colors[i]);
            acc.rows[b.groups[i]]++;
        }
        // very large texts: keep the pair table bounded (drops pairs seen once)
        if (acc.pairs != null && acc.pairs.size() > 3_000_000) {
            for (Iterator<double[]> it = acc.pairs.values().iterator(); it.hasNext(); ) if (it.next()[0] <= 1) it.remove();
            synchronized (notes) {
                if (!notes.contains("pairs")) notes.add("pairs");
            }
        }
    }

    private static void merge(Partial into, Partial from, int G) {
        for (Map.Entry<String, Cnt> e : from.uni.entrySet()) {
            Cnt c = into.uni.get(e.getKey());
            if (c == null) into.uni.put(e.getKey(), e.getValue()); else c.add(e.getValue(), G);
        }
        if (into.pairs != null && from.pairs != null) {
            for (Map.Entry<String, double[]> e : from.pairs.entrySet()) {
                double[] c = into.pairs.get(e.getKey());
                if (c == null) into.pairs.put(e.getKey(), e.getValue()); else c[0] += e.getValue()[0];
            }
        }
        for (Map.Entry<String, Map<String, Double>> e : from.surf.entrySet()) {
            Map<String, Double> d = into.surf.computeIfAbsent(e.getKey(), k -> new HashMap<>());
            for (Map.Entry<String, Double> f : e.getValue().entrySet()) d.merge(f.getKey(), f.getValue(), Double::sum);
        }
        for (int g = 1; g <= G; g++) { into.tokens[g] += from.tokens[g]; into.rows[g] += from.rows[g]; }
        if (from.catTok != null) {
            if (into.catTok == null) into.catTok = new double[G + 1][from.catTok[1].length];
            for (int g = 1; g <= G; g++) for (int k = 0; k < from.catTok[g].length; k++) into.catTok[g][k] += from.catTok[g][k];
        }
    }

    private Partial pass(RowSource src, int G, ExecutorService pool, int threads, Pass ps) throws Exception {
        final int BATCH_ROWS = 4000;
        final int BATCH_CHARS = 2_000_000;
        Partial total;
        if (pool == null || threads <= 1) {
            total = new Partial(G, ps.pairs);
            Batch b = new Batch(BATCH_ROWS);
            long chars = 0;
            for (long i = 0, n = src.size(); i < n; i++) {
                if (!src.use(i)) continue;
                int g = src.group(i);
                if (g < 1 || g > G) continue;
                String t = src.text(i);
                if (t == null) continue;
                double w = src.weight(i);
                if (!(w >= 0) || Double.isInfinite(w)) continue;
                b.texts[b.size] = t; b.groups[b.size] = g; b.weights[b.size] = w; b.regions[b.size] = src.region(i);
                if (o.colorMode == 3) b.colors[b.size] = src.ccolor(i); else if (o.colorMode > 0) b.cvalues[b.size] = src.cvalue(i);
                b.size++;
                chars += t.length();
                if (b.size == BATCH_ROWS || chars >= BATCH_CHARS) { work(b, G, total, ps); b.size = 0; chars = 0; }
            }
            if (b.size > 0) work(b, G, total, ps);
        } else {
            final Batch STOP = new Batch(0);
            java.util.concurrent.BlockingQueue<Batch> q = new java.util.concurrent.ArrayBlockingQueue<>(threads * 2);
            List<Future<Partial>> workers = new ArrayList<>();
            for (int k = 0; k < threads; k++) {
                workers.add(pool.submit(() -> {
                    Partial acc = new Partial(G, ps.pairs);
                    while (true) {
                        Batch bb = q.take();
                        if (bb == STOP) return acc;
                        work(bb, G, acc, ps);
                    }
                }));
            }
            try {
                Batch b = new Batch(BATCH_ROWS);
                long chars = 0;
                for (long i = 0, n = src.size(); i < n; i++) {
                    if (!src.use(i)) continue;
                    int g = src.group(i);
                    if (g < 1 || g > G) continue;
                    String t = src.text(i);
                    if (t == null) continue;
                    double w = src.weight(i);
                    if (!(w >= 0) || Double.isInfinite(w)) continue;
                    b.texts[b.size] = t; b.groups[b.size] = g; b.weights[b.size] = w; b.regions[b.size] = src.region(i);
                if (o.colorMode == 3) b.colors[b.size] = src.ccolor(i); else if (o.colorMode > 0) b.cvalues[b.size] = src.cvalue(i);
                b.size++;
                    chars += t.length();
                    if (b.size == BATCH_ROWS || chars >= BATCH_CHARS) { q.put(b); b = new Batch(BATCH_ROWS); chars = 0; }
                }
                if (b.size > 0) q.put(b);
            } finally {
                for (int k = 0; k < threads; k++) q.put(STOP);
            }
            total = workers.get(0).get();
            for (int k = 1; k < threads; k++) merge(total, workers.get(k).get(), G);
        }
        return total;
    }

    // ── the whole count ──────────────────────────────────────────────────────

    private static double l(double k, double n, double x) {
        return Math.log(Math.max(x, 1e-10)) * k + Math.log(Math.max(1 - x, 1e-10)) * (n - k);
    }
    /** Dunning log-likelihood ratio for a pair seen c times; words seen c1, c2 times; N words */
    static double evidence(double c, double c1, double c2, double N) {
        double p = c2 / N, p1 = c / c1, p2 = (c2 - c) / (N - c1);
        return -2 * (l(c, c1, p) + l(c2 - c, N - c1, p) - l(c, c1, p1) - l(c2 - c, N - c1, p2));
    }
    /** normalised pointwise mutual information, -1..1 */
    static double strength(double c, double c1, double c2, double N) {
        if (c >= N) return 1;
        return Math.log(c * N / (c1 * c2)) / (-Math.log(c / N));
    }

    /** Count every selected row of src into G groups. pool may be null. */
    public Result count(RowSource src, int G, ExecutorService pool, int threads) throws Exception {
        Pass ps = new Pass();
        List<Phrase> report = new ArrayList<>();
        Map<String, String> plural = Collections.emptyMap();

        // phrases the user listed
        Map<String, Double> forced = new LinkedHashMap<>();
        Set<String> dropped = new HashSet<>();
        if (!o.precounted) {
            for (String p : o.addPhrases) {
                String c = cleanPhrase(p);
                if (c == null) notes.add("not a two-word phrase after cleaning (ignored): " + p);
                else forced.put(c, Double.POSITIVE_INFINITY);
            }
            for (String p : o.dropPhrases) { String c = cleanPhrase(p); if (c != null) dropped.add(c); }
        }
        boolean joining = !o.precounted && (o.phrases || !forced.isEmpty());
        Partial fin;
        Map<String, double[]> stats = new HashMap<>();   // phrase -> {evidence, strength}

        if (!joining) {
            fin = pass(src, G, pool, threads, ps);
            if (o.plurals && !o.precounted) plural = pluralMap(fin.uni.keySet());
        } else {
            // pass 1: words (and pairs, for automatic detection)
            Pass p1 = new Pass();
            p1.pairs = o.phrases;
            Partial first = pass(src, G, pool, threads, p1);
            if (o.plurals) plural = pluralMap(first.uni.keySet());
            Map<String, Double> join = new HashMap<>();
            if (o.phrases) {
                // word totals and pair totals after merging plurals
                Map<String, Double> ut = new HashMap<>();
                double N = 0;
                for (Map.Entry<String, Cnt> e : first.uni.entrySet()) {
                    String w = plural.getOrDefault(e.getKey(), e.getKey());
                    double r = e.getValue().rawTotal(G);
                    ut.merge(w, r, Double::sum);
                    N += r;
                }
                Map<String, Double> pt = new HashMap<>();
                for (Map.Entry<String, double[]> e : first.pairs.entrySet()) {
                    String k = e.getKey();
                    int sp = k.indexOf(' ');
                    String a = k.substring(0, sp), b = k.substring(sp + 1);
                    pt.merge(plural.getOrDefault(a, a) + " " + plural.getOrDefault(b, b), e.getValue()[0], Double::sum);
                }
                for (Map.Entry<String, Double> e : pt.entrySet()) {
                    double c = e.getValue();
                    if (c < o.phraseMinCount) continue;
                    String k = e.getKey();
                    int sp = k.indexOf(' ');
                    String a = k.substring(0, sp), b = k.substring(sp + 1);
                    if (a.equals(b)) continue;
                    Double ca = ut.get(a), cb = ut.get(b);
                    if (ca == null || cb == null) continue;
                    double ev = evidence(c, ca, cb, N), st = strength(c, ca, cb, N);
                    if (ev >= o.phraseEvidence && st >= o.phraseStrength && !dropped.contains(k)) {
                        join.put(k, st);
                        stats.put(k, new double[]{ev, st});
                    }
                }
            }
            for (String k : forced.keySet()) {
                String[] ab = k.split(" ");
                String kk = plural.getOrDefault(ab[0], ab[0]) + " " + plural.getOrDefault(ab[1], ab[1]);
                join.put(kk, Double.POSITIVE_INFINITY);
            }
            for (String k : dropped) join.remove(k);
            // pass 2: count again, joining the phrases
            ps.join = join;
            ps.plural = plural;
            fin = join.isEmpty() ? first : pass(src, G, pool, threads, ps);
            for (String k : join.keySet()) {
                Cnt c = fin.uni.get(k);
                double cnt = c == null ? 0 : c.rawTotal(G);
                if (cnt <= 0) continue;
                double[] s = stats.get(k);
                report.add(new Phrase(k, cnt, s == null ? Double.NaN : s[0], s == null ? Double.NaN : s[1], s == null));
            }
            Collections.sort(report, (x, y) -> x.count != y.count ? Double.compare(y.count, x.count) : x.phrase.compareTo(y.phrase));
        }

        // merge plurals into their singulars; the merged entry is shown in its
        // most common form ("delays" + "delay" shows "delay" if that is more frequent)
        Map<String, String> label = new HashMap<>();     // shown form -> for the report
        if (!plural.isEmpty()) {
            for (Map.Entry<String, String> e : plural.entrySet()) {
                Cnt c = fin.uni.remove(e.getKey());
                if (c == null) continue;
                Cnt s = fin.uni.remove(e.getValue());
                double pc = c.rawTotal(G), sc = s == null ? 0 : s.rawTotal(G);
                String show = pc > sc ? e.getKey() : e.getValue();
                if (s != null) c.add(s, G);
                fin.uni.put(show, c);
            }
            // joined phrases: the form seen most often ("special effects", "star wars")
            for (Map.Entry<String, Map<String, Double>> e : fin.surf.entrySet()) {
                String best = e.getKey();
                double bc = -1;
                for (Map.Entry<String, Double> f : e.getValue().entrySet()) {
                    if (f.getValue() > bc || (f.getValue() == bc && f.getKey().compareTo(best) < 0)) { best = f.getKey(); bc = f.getValue(); }
                }
                if (!best.equals(e.getKey())) {
                    Cnt c = fin.uni.remove(e.getKey());
                    if (c != null) { Cnt t = fin.uni.get(best); if (t == null) fin.uni.put(best, c); else t.add(c, G); }
                    label.put(e.getKey(), best);
                }
            }
        }
        if (!label.isEmpty()) {
            List<Phrase> rel = new ArrayList<>();
            for (Phrase x : report) rel.add(new Phrase(label.getOrDefault(x.phrase, x.phrase), x.count, x.evidence, x.strength, x.added));
            report = rel;
        }

        Result r = new Result(G, fin.uni, report, plural.size());
        for (int g = 1; g <= G; g++) {
            r.totals[g].rows = fin.rows[g]; r.totals[g].tokens = fin.tokens[g];
            r.totals[g].catTok = fin.catTok == null ? null : fin.catTok[g];
        }
        return r;
    }

    public static final class Result {
        public final Map<String, Cnt> map;
        public final Totals[] totals;
        public final List<Phrase> phrases;
        public final int pluralsMerged;
        Result(int G, Map<String, Cnt> map, List<Phrase> phrases, int pm) {
            this.map = map; this.phrases = phrases; this.pluralsMerged = pm;
            totals = new Totals[G + 1];
            for (int g = 0; g <= G; g++) totals[g] = new Totals();
        }
        /** Colour information of one word in group g. Categories: the category in
         *  which the word is used significantly more often than its overall rate
         *  predicts (largest z-score, at least 1.96, i.e. 95% confidence, judged
         *  only where the expected count is at least 5); a word
         *  used about evenly, or seen too little to tell, gets no category. Small
         *  categories therefore need strong evidence, not just a high rate. */
        void colorInfo(Entry en, Cnt c, int g) {
            if (c.vs != null && c.vw[g] > 0) en.cval = c.vs[g] / c.vw[g];
            if (c.cat != null && c.cat[g] != null) {
                double[] tok = totals[g].catTok;
                double all = 0, T = 0;
                for (int k = 1; k < c.cat[g].length; k++) {
                    all += c.cat[g][k];
                    if (tok != null) T += tok[k];
                }
                double p0 = T > 0 ? all / T : 0, bestZ = 1.96;
                int bk = 0;
                if (p0 > 0 && p0 < 1) {
                    for (int k = 1; k < c.cat[g].length; k++) {
                        double Tk = tok == null ? 0 : tok[k];
                        // too little text to judge: the z-score needs an expected count of at least 5
                        if (Tk <= 0 || Tk * p0 < 5) continue;
                        double z = (c.cat[g][k] - Tk * p0) / Math.sqrt(Tk * p0 * (1 - p0));
                        if (z > bestZ) { bestZ = z; bk = k; }
                    }
                }
                // how many times more often the word is used there than overall
                if (bk > 0) { en.ccat = bk; en.cshare = (c.cat[g][bk] / tok[bk]) / p0; }
            }
            en.ccolor = c.col;
        }
        /** Number of distinct words in group g. */
        public long distinct(int g) {
            long k = 0;
            for (Cnt c : map.values()) if (c.n[g] > 0) k++;
            return k;
        }
        /** Words seen at least minFreq times in group g (plain occurrences),
         *  largest weighted count first (ties alphabetical), at most maxWords. */
        public List<Entry> top(int g, double minFreq, int maxWords) {
            List<Entry> out = new ArrayList<>();
            for (Map.Entry<String, Cnt> e : map.entrySet()) {
                Cnt c = e.getValue();
                if (c.n[g] >= minFreq && c.n[g] > 0) {
                    String k = e.getKey();
                    int sep = k.indexOf(RSEP);
                    Entry en = sep >= 0 ? new Entry(k.substring(sep + 1), c.w[g], c.n[g], k.substring(0, sep))
                                        : new Entry(k, c.w[g], c.n[g]);
                    colorInfo(en, c, g);
                    out.add(en);
                }
            }
            Collections.sort(out, (a, b) -> a.count != b.count ? Double.compare(b.count, a.count)
                : a.word.compareTo(b.word) != 0 ? a.word.compareTo(b.word)
                : String.valueOf(a.region).compareTo(String.valueOf(b.region)));
            return out.size() > maxWords ? new ArrayList<>(out.subList(0, maxWords)) : out;
        }
    }
}
