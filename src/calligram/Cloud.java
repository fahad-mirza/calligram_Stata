/*
 * Cloud.java - one-call Stata entry point for calligram (v3)
 *
 *   javacall calligram.Cloud run textvar groupvar [weightvar] if touse,
 *       jars(calligram.jar) args(name=value ...)
 *
 * Reads the selected rows straight from the user's data (no copy), counts
 * words in parallel, lays out every group's cloud (groups in parallel), and
 * writes the results to a NEW Stata frame named by frame=, one row per
 * candidate word:
 *     g  word  freq  placed  fontsize  rotation  tx  ty  bx  by  bw  bh
 *     path  nrows  ntok  adv   (adv = advance width, for SVG textLength)
 * (bx..bh = the word's ink box on the canvas; path = the word's exact letter
 * outlines as SVG path data, filled only when mode=paths, the default)
 * (g = group 1..G; rows in rank order within each group; nrows/ntok = number
 * of responses and words counted in that group).
 *
 * Settings (mode=paths|text; hyphens, elision, plurals, phrases (0/1),
 * phrasestrength, addfile/dropfile (one phrase per line), pframe (frame for
 * the joined phrases), precounted (0/1: rows are word + count), weight (0/1);
 * values percent-encoded: "%20" = space, "%25" = %, "%28"/"%29" = parentheses):
 *   frame groups threads stopfile clean minlength minfreq maxwords
 *   width height margin maxfont minfont scaling seed font rotate shape mask
 *   outline outfile mode spacing shapesfile projection regionmode near
 *
 * Return codes: 0 ok, 111 variables, 498 invalid setting, 601 mask file not
 * found, 610 mask file unreadable, 5100 anything unexpected.
 */
package calligram;

import com.stata.sfi.Data;
import com.stata.sfi.Frame;
import com.stata.sfi.SFIToolkit;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class Cloud {

    public static int run(String[] args) {
        ExecutorService pool = null;
        try {
            Settings s = new Settings(args);
            if (s.threads > 1) {
                pool = Executors.newFixedThreadPool(s.threads, r -> {
                    Thread t = new Thread(r, "calligram");
                    t.setDaemon(true);
                    return t;
                });
            }
            return go(s, pool);
        } catch (IllegalStateException e) {
            SFIToolkit.errorln("calligram (Java): " + e.getMessage());
            return 111;
        } catch (IllegalArgumentException e) {
            SFIToolkit.errorln("calligram: " + e.getMessage());
            return 498;
        } catch (FileNotFoundException e) {
            SFIToolkit.errorln("calligram: " + e.getMessage());
            return 601;
        } catch (IOException e) {
            SFIToolkit.errorln("calligram: " + e.getMessage());
            return 610;
        } catch (Throwable t) {
            SFIToolkit.errorln("calligram (Java): " + t);
            return 5100;
        } finally {
            if (pool != null) pool.shutdownNow();
        }
    }

    static final class Settings {
        String frame = "", stopfile = "", outfile = "", mode = "paths", pframe = "", addfile = "", dropfile = "";
        boolean hyphens = true, elision = false, plurals = true, phrases = false, precounted = false, hasWeight = false;
        boolean forcePaths = false;      // outlines also in text mode (needed for static images)
        boolean regions = false;         // words are tied to areas (regionmode below)
        String regionMode = "";
        int colorMode = 0, colorK = 0, colorPos = 0;   // colour by a variable: mode, categories, variable position
        String colorImage = "";                        // colour each word from this picture          // color (4th var, mask colour) | id (4th var, shapefile _ID) | location (4th, 5th: y x)
        double phraseStrength = 0.40;
        int groups = 1, threads = 0, minLength = 3, minFreq = 2, maxWords = 100;
        boolean clean = true;
        Engine.Params p = new Engine.Params();

        Settings(String[] args) {
            for (String a : args) {
                int k = a.indexOf('=');
                if (k < 0) continue;
                String key = a.substring(0, k), v = Layout.dec(a.substring(k + 1));
                switch (key) {
                    case "frame":     frame = v; break;
                    case "groups":    groups = Integer.parseInt(v); break;
                    case "threads":   threads = Integer.parseInt(v); break;
                    case "stopfile":  stopfile = v; break;
                    case "clean":     clean = !v.equals("0"); break;
                    case "minlength": minLength = Integer.parseInt(v); break;
                    case "minfreq":   minFreq = Integer.parseInt(v); break;
                    case "maxwords":  maxWords = Integer.parseInt(v); break;
                    case "width":     p.width = Integer.parseInt(v); break;
                    case "height":    p.height = Integer.parseInt(v); break;
                    case "margin":    p.margin = Integer.parseInt(v); break;
                    case "maxfont":   p.maxFont = Integer.parseInt(v); break;
                    case "minfont":   p.minFont = Integer.parseInt(v); break;
                    case "scaling":   p.scaling = Double.parseDouble(v); break;
                    case "seed":      p.seed = Long.parseLong(v); break;
                    case "font":      p.font = v; break;
                    case "rotate":    p.rotate = v; break;
                    case "shape":     p.shape = v.toLowerCase(); break;
                    case "mask":      p.mask = v; break;
                    case "outline":   p.outline = Double.parseDouble(v); break;
                    case "outfile":   outfile = v; break;
                    case "mode":      mode = v; break;
                    case "spacing":   p.spacing = Double.parseDouble(v); break;
                    case "pframe":    pframe = v; break;
                    case "addfile":   addfile = v; break;
                    case "dropfile":  dropfile = v; break;
                    case "hyphens":   hyphens = !v.equals("0"); break;
                    case "elision":   elision = v.equals("1"); break;
                    case "plurals":   plurals = !v.equals("0"); break;
                    case "phrases":   phrases = v.equals("1"); break;
                    case "phrasestrength": phraseStrength = Double.parseDouble(v); break;
                    case "precounted": precounted = v.equals("1"); break;
                    case "weight":    hasWeight = v.equals("1"); break;
                    case "paths":     forcePaths = v.equals("1"); break;
                    case "colormode": colorMode = v.equals("numeric") ? 1 : v.equals("category") ? 2 : v.equals("color") ? 3 : 0; break;
                    case "colork":    colorK = Integer.parseInt(v); break;
                    case "colorpos":  colorPos = Integer.parseInt(v); break;
                    case "colorimage": colorImage = v; if (!v.isEmpty()) forcePaths = true; break;
                    case "regions":   regions = v.equals("1"); p.regions = regions; if (regions && regionMode.isEmpty()) regionMode = "color"; break;
                    case "regionmode": regionMode = v; regions = !v.isEmpty(); p.regions = regions; break;
                    case "shapesfile": p.shapes = v; break;
                    case "projection": p.projection = v; break;
                    case "near":      p.near = v.equals("1"); break;
                    default: break;
                }
            }
            if (frame.isEmpty()) throw new IllegalArgumentException("no output frame name given");
            if (groups < 1) throw new IllegalArgumentException("groups must be at least 1");
            if (!mode.equals("paths") && !mode.equals("text")) throw new IllegalArgumentException("mode must be paths or text");
            if (p.mask.isEmpty() && !Arrays.asList(Engine.SHAPES).contains(p.shape)) {
                throw new IllegalArgumentException("unknown shape: " + p.shape);
            }
            int cores = Runtime.getRuntime().availableProcessors();
            if (threads <= 0) threads = cores;
            threads = Math.max(1, Math.min(threads, 64));
        }
    }

    static int go(Settings s, ExecutorService pool) throws Exception {
        System.setProperty("java.awt.headless", "true");
        final int G = s.groups;

        // ── which variables: 1 = text, 2 = group (optional) ──────────────────
        int nv = Data.getParsedVarCount();
        if (nv < 1) throw new IllegalStateException("no text variable given");
        final int vText = Data.mapParsedVarIndex(1);
        final int vGroup = nv >= 2 ? Data.mapParsedVarIndex(2) : 0;
        final int vWeight = (s.hasWeight || s.precounted) && nv >= 3 ? Data.mapParsedVarIndex(3) : 0;
        if ((s.hasWeight || s.precounted) && vWeight == 0) throw new IllegalStateException("no weight/count variable given");
        final int vRegion = s.regions && nv >= 4 ? Data.mapParsedVarIndex(4) : 0;
        final int vColor = s.colorMode > 0 && s.colorPos >= 1 && s.colorPos <= nv ? Data.mapParsedVarIndex(s.colorPos) : 0;
        if (s.colorMode > 0 && vColor == 0) throw new IllegalStateException("no colour variable given");
        if (s.regions && vRegion == 0) throw new IllegalStateException("no region variable given");
        final boolean byLocation = s.regionMode.equals("location");
        final int vX = byLocation && nv >= 5 ? Data.mapParsedVarIndex(5) : 0;      // location(y x): 4th = y, 5th = x
        if (byLocation && vX == 0) throw new IllegalStateException("location() needs two variables");
        // the shape/shapefile is needed while reading (points are matched to areas)
        final Engine engine = new Engine(s.p);
        final Shapes shp = engine.shapes();
        if ((s.regionMode.equals("id") || byLocation) && shp == null) throw new IllegalArgumentException("regions with area IDs or location() need shapes()");
        final long in1 = Data.getObsParsedIn1(), in2 = Data.getObsParsedIn2();

        // ── count ─────────────────────────────────────────────────────────────
        Counter.Options o = new Counter.Options();
        o.clean = s.clean;
        o.minLength = s.minLength;
        o.keepHyphens = s.hyphens;
        o.elision = s.elision;
        o.plurals = s.plurals;
        o.phrases = s.phrases;
        o.phraseStrength = s.phraseStrength;
        o.precounted = s.precounted;
        o.colorMode = s.colorMode;
        o.K = s.colorK;
        if (!s.addfile.isEmpty()) for (String line : Files.readAllLines(Paths.get(s.addfile), StandardCharsets.UTF_8)) if (!line.trim().isEmpty()) o.addPhrases.add(line.trim());
        if (!s.dropfile.isEmpty()) for (String line : Files.readAllLines(Paths.get(s.dropfile), StandardCharsets.UTF_8)) if (!line.trim().isEmpty()) o.dropPhrases.add(line.trim());
        if (!s.stopfile.isEmpty()) {
            for (String line : Files.readAllLines(Paths.get(s.stopfile), StandardCharsets.UTF_8)) {
                for (String w : line.trim().split("\\s+")) if (!w.isEmpty()) o.stop.add(w);
            }
        }
        Counter counter = new Counter(o);
        Counter.RowSource src = new Counter.RowSource() {
            public long size() { return in2 - in1 + 1; }
            public boolean use(long i) { return Data.isParsedIfTrue(in1 + i); }
            public String text(long i) { return Data.getStr(vText, in1 + i); }
            public int group(long i) {
                if (vGroup == 0) return 1;
                double v = Data.getNum(vGroup, in1 + i);
                return (v >= 1 && v <= G) ? (int) v : 0;     // missing or out of range: skipped
            }
            public double cvalue(long i) {
                double v = Data.getNum(vColor, in1 + i);
                return Math.abs(v) < 8.98e307 ? v : Double.NaN;
            }
            public String ccolor(long i) {
                String c = Data.getStr(vColor, in1 + i);
                return c == null || c.trim().isEmpty() ? null : c.trim();
            }
            public String region(long i) {
                if (vRegion == 0) return null;
                if (byLocation) {
                    double y = Data.getNum(vRegion, in1 + i), x = Data.getNum(vX, in1 + i);
                    if (!(Math.abs(y) < 8.98e307) || !(Math.abs(x) < 8.98e307)) return "L0";
                    double[] c = shp.canvas(x, y);
                    int l = shp.labelAt(c[0], c[1], 6);
                    return String.format(java.util.Locale.ROOT, "L%d@%.1f,%.1f", l, c[0], c[1]);
                }
                if (s.regionMode.equals("id")) {
                    double v = Data.getNum(vRegion, in1 + i);
                    return "L" + (Math.abs(v) < 8.98e307 ? shp.labelOfId(v) : 0);
                }
                String r = Data.getStr(vRegion, in1 + i);
                return r == null || r.trim().isEmpty() ? null : r.trim();
            }
            public double weight(long i) {
                if (vWeight == 0) return 1.0;
                double v = Data.getNum(vWeight, in1 + i);
                return (v >= 0 && v < 8.98e307) ? v : -1;    // missing or negative: row skipped
            }
        };
        long t0 = System.nanoTime();
        Counter.Result cr = counter.count(src, G, pool, s.threads);
        long t1 = System.nanoTime();

        // ── top words per group ───────────────────────────────────────────────
        List<List<Counter.Entry>> tops = new ArrayList<>();
        tops.add(null);
        for (int g = 1; g <= G; g++) tops.add(cr.top(g, s.minFreq, s.maxWords));

        // ── layout: one engine (shape/mask built once), groups in parallel ────
        if (!engine.warning.isEmpty()) SFIToolkit.displayln("{txt}calligram: " + engine.warning);
        final boolean paths = s.mode.equals("paths") || s.forcePaths;
        Engine.Result[] res = new Engine.Result[G + 1];
        String[][] pathsOf = new String[G + 1][];
        List<Integer> todo = new ArrayList<>();
        for (int g = 1; g <= G; g++) if (!tops.get(g).isEmpty()) todo.add(g);
        if (pool != null && todo.size() > 1) {
            List<Future<Object[]>> fs = new ArrayList<>();
            for (int g : todo) {
                final List<Counter.Entry> t = tops.get(g);
                fs.add(pool.submit(() -> {
                    Engine.Result r = engine.layout(wordsOf(t), freqsOf(t), regionsOf(t), null);
                    return new Object[]{r, paths ? pathsFor(engine, t, r) : null};
                }));
            }
            for (int k = 0; k < todo.size(); k++) {
                Object[] out = fs.get(k).get();
                res[todo.get(k)] = (Engine.Result) out[0];
                pathsOf[todo.get(k)] = (String[]) out[1];
            }
        } else {
            for (int g : todo) {
                res[g] = engine.layout(wordsOf(tops.get(g)), freqsOf(tops.get(g)), regionsOf(tops.get(g)), pool);
                if (paths) pathsOf[g] = pathsFor(engine, tops.get(g), res[g]);
            }
        }
        if (!s.colorImage.isEmpty()) {
            // with a mask the picture lines up with it (fitted the same way); otherwise it
            // covers the whole canvas, so every word has picture under its letters
            java.awt.image.BufferedImage pic = Engine.fitImage(s.colorImage, s.p.width, s.p.height, s.p.mask.isEmpty());
            for (int g : todo) {
                List<Counter.Entry> t = tops.get(g);
                for (int i = 0; i < t.size(); i++) {
                    if (res[g] == null || !res[g].placed[i] || pathsOf[g] == null || pathsOf[g][i] == null) continue;
                    t.get(i).ccolor = averageColor(pic, Render.path(pathsOf[g][i]));
                }
            }
        }
        long t2 = System.nanoTime();
        if (s.regions) {
            int noRegion = 0;
            for (int g : todo) for (int i = 0; i < tops.get(g).size(); i++) {
                if (res[g] != null && !res[g].placed[i] && Engine.regionKey(tops.get(g).get(i).region) <= 0) noRegion++;
            }
            if (noRegion > 0) {
                String why = shp == null ? "no valid region colour (#rrggbb)"
                    : byLocation ? "a location outside every area of the shapefile"
                    : "an area ID that is not in the shapefile";
                SFIToolkit.displayln("{txt}calligram: " + noRegion + " word" + (noRegion == 1 ? " has " : "s have ") + why + " and could not be placed.");
            }
        }
        int nfb = 0;
        for (int g : todo) for (int i = 0; i < tops.get(g).size(); i++) {
            if (res[g].placed[i] && engine.usesFallback(tops.get(g).get(i).word)) nfb++;
        }
        if (nfb > 0) {
            SFIToolkit.displayln("{txt}calligram: " + nfb + " word" + (nfb == 1 ? "" : "s")
                + " use characters " + engine.family() + " does not have; drawn with the system font instead.");
        }

        // ── results into a new frame ──────────────────────────────────────────
        long rows = 0;
        int maxBytes = 1;
        for (int g = 1; g <= G; g++) {
            rows += tops.get(g).size();
            for (Counter.Entry e : tops.get(g)) maxBytes = Math.max(maxBytes, e.word.getBytes(StandardCharsets.UTF_8).length);
        }
        Frame f = Frame.create(s.frame);
        String[] num = {"g", "freq", "placed", "fontsize", "rotation", "tx", "ty", "bx", "by", "bw", "bh", "nrows", "ntok", "adv", "nraw"};
        check(f.addVarDouble("g"));
        if (maxBytes <= 2045) check(f.addVarStr("word", maxBytes));
        else check(f.addVarStrL("word"));
        for (int k = 1; k < num.length; k++) check(f.addVarDouble(num[k]));
        check(f.addVarStrL("path"));
        int vPath = f.getVarIndex("path");
        int vReg = 0;
        if (s.regions) { check(f.addVarStr("region", 16)); vReg = f.getVarIndex("region"); }
        int vCval = 0, vCcat = 0, vCshare = 0, vCcol = 0;
        if (s.colorMode == 1) { check(f.addVarDouble("cval")); vCval = f.getVarIndex("cval"); }
        if (s.colorMode == 2) {
            check(f.addVarDouble("ccat")); vCcat = f.getVarIndex("ccat");
            check(f.addVarDouble("cshare")); vCshare = f.getVarIndex("cshare");
        }
        if (s.colorMode == 3 || !s.colorImage.isEmpty()) { check(f.addVarStr("ccolor", 40)); vCcol = f.getVarIndex("ccolor"); }
        int[] vi = new int[num.length];
        for (int k = 0; k < num.length; k++) vi[k] = f.getVarIndex(num[k]);
        int vWord = f.getVarIndex("word");
        check(f.setObsTotal(rows));
        long obs = 0;
        for (int g = 1; g <= G; g++) {
            List<Counter.Entry> t = tops.get(g);
            Engine.Result r = res[g];
            for (int i = 0; i < t.size(); i++) {
                obs++;
                boolean pl = r != null && r.placed[i];
                f.storeNum(vi[0], obs, g);
                f.storeStr(vWord, obs, t.get(i).word);
                f.storeNum(vi[1], obs, t.get(i).count);
                f.storeNum(vi[2], obs, pl ? 1 : 0);
                f.storeNum(vi[3], obs, pl ? r.size[i] : 0);
                f.storeNum(vi[4], obs, pl ? r.rot[i] : 0);
                f.storeNum(vi[5], obs, pl ? r.tx[i] : 0);
                f.storeNum(vi[6], obs, pl ? r.ty[i] : 0);
                f.storeNum(vi[7], obs, pl ? r.bx[i] : 0);
                f.storeNum(vi[8], obs, pl ? r.by[i] : 0);
                f.storeNum(vi[9], obs, pl ? r.bw[i] : 0);
                f.storeNum(vi[10], obs, pl ? r.bh[i] : 0);
                f.storeNum(vi[11], obs, cr.totals[g].rows);
                f.storeNum(vi[12], obs, cr.totals[g].tokens);
                f.storeNum(vi[13], obs, pl ? r.adv[i] : 0);
                f.storeNum(vi[14], obs, t.get(i).raw);
                if (pl && pathsOf[g] != null) f.storeStr(vPath, obs, pathsOf[g][i]);
                Counter.Entry ce = t.get(i);
                // (values left unset stay missing: new observations start out missing)
                if (vCval > 0 && !Double.isNaN(ce.cval)) f.storeNum(vCval, obs, ce.cval);
                if (vCcat > 0 && ce.ccat > 0) {
                    f.storeNum(vCcat, obs, ce.ccat);
                    if (!Double.isNaN(ce.cshare)) f.storeNum(vCshare, obs, ce.cshare);
                }
                if (vCcol > 0 && ce.ccolor != null) f.storeStr(vCcol, obs, ce.ccolor.length() > 40 ? ce.ccolor.substring(0, 40) : ce.ccolor);
                if (vReg > 0 && t.get(i).region != null) {
                    String rv = t.get(i).region;
                    if (shp != null && rv.startsWith("L")) {
                        double id = shp.idOfLabel(Engine.regionKey(rv));
                        rv = Double.isNaN(id) ? "" : (id == Math.rint(id) ? String.valueOf((long) id) : String.valueOf(id));
                    }
                    f.storeStr(vReg, obs, rv);
                }
            }
        }

        // ── the joined phrases, for the report in Stata ───────────────────────
        if (!s.pframe.isEmpty()) {
            Frame pf = Frame.create(s.pframe);
            int pb = 1;
            for (Counter.Phrase x : cr.phrases) pb = Math.max(pb, x.phrase.getBytes(StandardCharsets.UTF_8).length);
            check(pb <= 2045 ? pf.addVarStr("phrase", pb) : pf.addVarStrL("phrase"));
            for (String v : new String[]{"count", "evidence", "strength", "added"}) check(pf.addVarDouble(v));
            check(pf.setObsTotal(cr.phrases.size()));
            int ip = pf.getVarIndex("phrase"), ic = pf.getVarIndex("count"), ie = pf.getVarIndex("evidence"),
                is = pf.getVarIndex("strength"), ia = pf.getVarIndex("added");
            long k = 0;
            for (Counter.Phrase x : cr.phrases) {
                k++;
                pf.storeStr(ip, k, x.phrase);
                pf.storeNum(ic, k, x.count);
                if (!Double.isNaN(x.evidence)) pf.storeNum(ie, k, x.evidence);
                if (!Double.isNaN(x.strength)) pf.storeNum(is, k, x.strength);
                pf.storeNum(ia, k, x.added ? 1 : 0);
            }
        }
        for (String n : counter.notes) {
            if (n.equals("pairs")) SFIToolkit.displayln("{txt}calligram: very large text: to save memory, word pairs seen only once were dropped while looking for phrases.");
            else SFIToolkit.displayln("{txt}calligram: " + n);
        }

        // ── outline (the same for every group) ────────────────────────────────
        if (s.p.outline > 0 && !s.outfile.isEmpty()) {
            Files.write(Paths.get(s.outfile), engine.outlineSvg.getBytes(StandardCharsets.UTF_8));
        }

        long nrows = 0; double ntok = 0;
        for (int g = 1; g <= G; g++) { nrows += cr.totals[g].rows; ntok += cr.totals[g].tokens; }
        if (cr.pluralsMerged > 0) SFIToolkit.displayln("{txt}calligram: " + String.format(java.util.Locale.ROOT, "%,d", cr.pluralsMerged) + " plural form" + (cr.pluralsMerged == 1 ? "" : "s") + " merged with the singular (noplurals keeps them apart).");
        String what = s.precounted
            // words already counted: rows of words with their counts (e.g. cities with populations)
            ? String.format(java.util.Locale.ROOT, "read %,d %s of counted words (total count %s)",
                nrows, nrows == 1 ? "row" : "rows", total(ntok))
            : String.format(java.util.Locale.ROOT, "counted %,d %s in %,d %s",
                Math.round(ntok), Math.round(ntok) == 1 ? "word" : "words", nrows, nrows == 1 ? "response" : "responses");
        SFIToolkit.displayln(String.format(java.util.Locale.ROOT,
            "{txt}calligram: %s (%.2f s); laid out %d cloud%s (%.2f s); %d thread%s.",
            what, (t1 - t0) / 1e9, todo.size(), todo.size() == 1 ? "" : "s", (t2 - t1) / 1e9,
            s.threads, s.threads == 1 ? "" : "s"));
        return 0;
    }

    private static void check(int rc) {
        if (rc != 0) throw new RuntimeException("Stata frame operation failed (rc " + rc + ")");
    }
    /** exact letter outlines of each placed word (null for words not placed) */
    private static String[] pathsFor(Engine e, List<Counter.Entry> t, Engine.Result r) {
        String[] out = new String[t.size()];
        for (int i = 0; i < out.length; i++) {
            if (r.placed[i]) out[i] = e.svgPath(t.get(i).word, r.size[i], r.rot[i], r.tx[i], r.ty[i]);
        }
        return out;
    }
    /** a total for messages: whole numbers with separators, otherwise 4 significant digits */
    private static String total(double v) {
        if (Math.abs(v - Math.rint(v)) < 1e-9) return String.format(java.util.Locale.ROOT, "%,d", Math.round(v));
        return String.format(java.util.Locale.ROOT, "%,.4g", v);
    }
    /** Average colour of the opaque picture pixels under a word's letters,
     *  as #rrggbb (null if the letters cover no opaque pixel). */
    static String averageColor(java.awt.image.BufferedImage pic, java.awt.Shape sh) {
        java.awt.Rectangle b = sh.getBounds();
        int x0 = Math.max(0, b.x), y0 = Math.max(0, b.y);
        int x1 = Math.min(pic.getWidth(), b.x + b.width + 1), y1 = Math.min(pic.getHeight(), b.y + b.height + 1);
        double r = 0, gg = 0, bb = 0, n = 0;
        for (int y = y0; y < y1; y++) {
            for (int x = x0; x < x1; x++) {
                if (!sh.contains(x + 0.5, y + 0.5)) continue;
                int v = pic.getRGB(x, y);
                if ((v >>> 24) < 128) continue;
                r += (v >> 16) & 0xff; gg += (v >> 8) & 0xff; bb += v & 0xff; n++;
            }
        }
        if (n == 0) return null;
        return String.format(java.util.Locale.ROOT, "#%02x%02x%02x", Math.round(r / n), Math.round(gg / n), Math.round(bb / n));
    }

    private static String[] regionsOf(List<Counter.Entry> t) {
        boolean any = false;
        String[] r = new String[t.size()];
        for (int i = 0; i < r.length; i++) { r[i] = t.get(i).region; if (r[i] != null) any = true; }
        return any ? r : null;
    }
    private static String[] wordsOf(List<Counter.Entry> t) {
        String[] w = new String[t.size()];
        for (int i = 0; i < w.length; i++) w[i] = t.get(i).word;
        return w;
    }
    private static double[] freqsOf(List<Counter.Entry> t) {
        double[] f = new double[t.size()];
        for (int i = 0; i < f.length; i++) f[i] = t.get(i).count;   // weighted count
        return f;
    }
}
