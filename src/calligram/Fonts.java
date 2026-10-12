/*
 * Fonts.java - fonts for calligram (v3.1)
 *
 * Bundled fonts (inside calligram.jar, bold weight, unmodified, each with its
 * licence file in /calligram/fonts/):
 *   Arimo         Apache/OFL  (free, metric-compatible with Arial)
 *   Tinos         OFL         (free, metric-compatible with Times New Roman)
 *   Roboto        Apache 2.0
 *   Open Sans     OFL
 *   Lato          OFL
 *   Noto Sans     OFL
 *   Merriweather  OFL (serif)
 * Any of these can be named in font(); they are also available on Google
 * Fonts under the same names, which is what the online option uses.
 *
 * Other names are looked up among the fonts installed on the computer. If the
 * font is not installed, Arimo is used instead (same letter widths as Arial).
 * Words with characters the chosen font cannot draw (for example Arabic or
 * Chinese in a Latin font) are measured and drawn with Java's built-in system
 * font for that word, so they still appear correctly.
 */
package calligram;

import java.awt.Font;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.Locale;
import java.util.Map;

public final class Fonts {

    /** name without spaces/hyphens, lower case -> resource file */
    private static final Map<String, String> BUNDLED = new HashMap<>();
    /** name without spaces/hyphens, lower case -> proper family name */
    private static final Map<String, String> FAMILY = new HashMap<>();
    static {
        add("Arimo", "Arimo-Bold.ttf");
        add("Tinos", "Tinos-Bold.ttf");
        add("Roboto", "Roboto-Bold.ttf");
        add("Open Sans", "OpenSans-Bold.ttf");
        add("Lato", "Lato-Bold.ttf");
        add("Noto Sans", "NotoSans-Bold.ttf");
        add("Merriweather", "Merriweather-Bold.ttf");
        add("Noto Nastaliq Urdu", "NotoNastaliqUrdu-Bold.ttf");   // Urdu in its usual Nastaliq style
    }
    private static void add(String family, String file) {
        BUNDLED.put(key(family), file);
        FAMILY.put(key(family), family);
    }
    static String key(String s) { return s.toLowerCase(Locale.ROOT).replaceAll("[\\s\\-_]", ""); }

    private static final Map<String, Font> CACHE = new HashMap<>();

    /** Load a bundled font (size 1); null if the resource is missing. */
    static synchronized Font bundled(String name) {
        String k = key(name);
        String file = BUNDLED.get(k);
        if (file == null) return null;
        Font f = CACHE.get(k);
        if (f != null) return f;
        try (InputStream in = Fonts.class.getResourceAsStream("fonts/" + file)) {
            if (in == null) return null;
            f = Font.createFont(Font.TRUETYPE_FONT, in);    // already the bold weight
            CACHE.put(k, f);
            return f;
        } catch (Exception e) {
            return null;
        }
    }

    public static boolean isBundled(String name) { return BUNDLED.containsKey(key(name)); }

    /** The font to use for a font() name, plus a note if a substitute was used. */
    public static final class Resolved {
        public final Font base;          // size 1; derive sizes from it
        public final String family;      // family actually used
        public final boolean bundled;
        public final String note;        // "" unless a substitute was used
        Resolved(Font b, String f, boolean bu, String n) { base = b; family = f; bundled = bu; note = n; }
    }

    public static Resolved resolve(String name) {
        Font b = bundled(name);
        if (b != null) return new Resolved(b, FAMILY.get(key(name)), true, "");
        Font sys = new Font(name, Font.BOLD, 1);
        if (sys.getFamily(Locale.ROOT).equalsIgnoreCase(name)) return new Resolved(sys, name, false, "");
        Font arimo = bundled("Arimo");
        if (arimo != null) {
            return new Resolved(arimo, "Arimo", true,
                "font \"" + name + "\" is not installed; using Arimo (a free font with the same letter widths as Arial) instead.");
        }
        return new Resolved(sys, sys.getFamily(Locale.ROOT), false,
            "font \"" + name + "\" not found; using \"" + sys.getFamily(Locale.ROOT) + "\" instead.");
    }

    /** Java's built-in composite font, which draws most scripts on most systems. */
    static Font fallback() { return new Font(Font.DIALOG, Font.BOLD, 1); }

    /** Fonts known to cover each script, Windows first, then macOS, then Noto
     *  (Linux and anyone who installed them). The first one that is installed and
     *  can draw the whole word is used. */
    private static final Map<Character.UnicodeScript, String[]> BY_SCRIPT = new HashMap<>();
    static {
        String[] cjkSC = {"Microsoft YaHei", "Microsoft YaHei UI", "SimHei", "DengXian", "PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC"};
        String[] jp = {"Yu Gothic", "Yu Gothic UI", "Meiryo", "MS Gothic", "Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP"};
        String[] kr = {"Malgun Gothic", "Gulim", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR"};
        String[] arab = {"Segoe UI", "Arial", "Tahoma", "Geeza Pro", "Noto Sans Arabic", "Noto Naskh Arabic", "DejaVu Sans"};
        String[] indic = {"Nirmala UI", "Nirmala Text", "Kohinoor Devanagari", "Kohinoor Bangla", "Tamil Sangam MN", "Mangal", "Vrinda", "Latha"};
        BY_SCRIPT.put(Character.UnicodeScript.HAN, cjkSC);
        BY_SCRIPT.put(Character.UnicodeScript.HIRAGANA, jp);
        BY_SCRIPT.put(Character.UnicodeScript.KATAKANA, jp);
        BY_SCRIPT.put(Character.UnicodeScript.HANGUL, kr);
        BY_SCRIPT.put(Character.UnicodeScript.ARABIC, arab);
        BY_SCRIPT.put(Character.UnicodeScript.HEBREW, new String[]{"Segoe UI", "Arial", "Tahoma", "Arial Hebrew", "Noto Sans Hebrew", "DejaVu Sans"});
        BY_SCRIPT.put(Character.UnicodeScript.DEVANAGARI, concat(indic, "Noto Sans Devanagari"));
        BY_SCRIPT.put(Character.UnicodeScript.BENGALI, concat(indic, "Noto Sans Bengali"));
        BY_SCRIPT.put(Character.UnicodeScript.TAMIL, concat(indic, "Noto Sans Tamil"));
        BY_SCRIPT.put(Character.UnicodeScript.TELUGU, concat(indic, "Noto Sans Telugu"));
        BY_SCRIPT.put(Character.UnicodeScript.GURMUKHI, concat(indic, "Noto Sans Gurmukhi"));
        BY_SCRIPT.put(Character.UnicodeScript.GUJARATI, concat(indic, "Noto Sans Gujarati"));
        BY_SCRIPT.put(Character.UnicodeScript.THAI, new String[]{"Leelawadee UI", "Leelawadee", "Tahoma", "Thonburi", "Noto Sans Thai", "Noto Sans Thai Looped"});
        BY_SCRIPT.put(Character.UnicodeScript.ETHIOPIC, new String[]{"Ebrima", "Nyala", "Kefa", "Noto Sans Ethiopic"});
    }
    private static String[] concat(String[] a, String b) { String[] r = Arrays.copyOf(a, a.length + 1); r[a.length] = b; return r; }
    private static final String[] GENERAL = {"Segoe UI", "Arial Unicode MS", "Noto Sans", "DejaVu Sans"};
    private static final Map<String, Font> CHOSEN = new java.util.concurrent.ConcurrentHashMap<>();
    private static volatile Set<String> installed;
    private static Set<String> installed() {
        if (installed == null) {
            Set<String> s = new HashSet<>();
            for (String f : java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment().getAvailableFontFamilyNames(Locale.ROOT)) s.add(f.toLowerCase(Locale.ROOT));
            installed = s;
        }
        return installed;
    }
    /** The main script of a word (its first character that is not shared punctuation or a mark). */
    static Character.UnicodeScript scriptOf(String w) {
        for (int i = 0; i < w.length(); ) {
            int cp = w.codePointAt(i);
            Character.UnicodeScript sc = Character.UnicodeScript.of(cp);
            if (sc != Character.UnicodeScript.COMMON && sc != Character.UnicodeScript.INHERITED) return sc;
            i += Character.charCount(cp);
        }
        return Character.UnicodeScript.COMMON;
    }
    /** Fonts chosen with scriptfonts(): writing system -> font, used for every word
     *  of that writing system even when the main font could draw it. */
    private static final Map<String, Font> OVERRIDE = new java.util.concurrent.ConcurrentHashMap<>();
    /** Reads "arabic=Noto Nastaliq Urdu;chinese=SimHei;" and returns notes on fonts not found. */
    static List<String> setOverrides(String spec) {
        OVERRIDE.clear();
        List<String> notes = new ArrayList<>();
        if (spec == null) return notes;
        for (String part : spec.split(";")) {
            int e = part.indexOf('=');
            if (e <= 0) continue;
            String script = part.substring(0, e).trim().toLowerCase(Locale.ROOT), name = part.substring(e + 1).trim();
            Font f = bundled(name);
            if (f == null && installed().contains(name.toLowerCase(Locale.ROOT))) f = new Font(name, Font.BOLD, 1);
            if (f == null) { notes.add("scriptfonts(): font \"" + name + "\" is not installed; " + script + " uses the usual font."); continue; }
            OVERRIDE.put(script, f);
        }
        return notes;
    }
    /** The writing-system name scriptfonts() uses for a word. */
    static String scriptKey(String w) {
        for (int i = 0; i < w.length(); ) {
            int cp = w.codePointAt(i);
            Character.UnicodeScript sc = Character.UnicodeScript.of(cp);
            if (sc == Character.UnicodeScript.HIRAGANA || sc == Character.UnicodeScript.KATAKANA) return "japanese";
            i += Character.charCount(cp);
        }
        Character.UnicodeScript sc = scriptOf(w);
        switch (sc) {
            case HAN: return "chinese";
            case HANGUL: return "korean";
            default: return sc.name().toLowerCase(Locale.ROOT);
        }
    }
    /** The scriptfonts() font for this word, if one was chosen and can draw it. */
    static Font overrideFor(String word) {
        if (OVERRIDE.isEmpty()) return null;
        Font f = OVERRIDE.get(scriptKey(word));
        return f != null && f.canDisplayUpTo(word) == -1 ? f : null;
    }
    /** A font that can draw the whole word: one known to cover its script, else any
     *  installed font that can, else Java's logical font. Chosen once per script. */
    static Font fallbackFor(String word) {
        Character.UnicodeScript sc = scriptOf(word);
        String key = sc.name();
        Font f = CHOSEN.get(key);
        if (f != null && f.canDisplayUpTo(word) == -1) return f;
        List<String> names = new ArrayList<>();
        if (BY_SCRIPT.containsKey(sc)) names.addAll(Arrays.asList(BY_SCRIPT.get(sc)));
        names.addAll(Arrays.asList(GENERAL));
        Set<String> have = installed();
        for (String n : names) {
            if (!have.contains(n.toLowerCase(Locale.ROOT))) continue;
            Font c = new Font(n, Font.BOLD, 1);
            if (c.canDisplayUpTo(word) == -1) { CHOSEN.put(key, c); return c; }
        }
        // any installed font that can draw it (sans-serif names first)
        List<String> all = new ArrayList<>(Arrays.asList(java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment().getAvailableFontFamilyNames(Locale.ROOT)));
        all.sort((a, b) -> Boolean.compare(!a.toLowerCase(Locale.ROOT).contains("sans"), !b.toLowerCase(Locale.ROOT).contains("sans")));
        for (String n : all) {
            Font c = new Font(n, Font.BOLD, 1);
            if (c.canDisplayUpTo(word) == -1) { CHOSEN.put(key, c); return c; }
        }
        return fallback();
    }
}
