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
import java.util.HashMap;
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
}
