/*
 * Engine.java - word cloud layout engine for calligram (v2.0)
 *
 * Pure Java (no Stata classes), so it can be tested on its own.
 *
 * Method (follows the Python word_cloud library):
 *  - The canvas is a grid of pixels. Pixels outside the chosen shape or mask
 *    start out "occupied".
 *  - An integral image (a running-total table) answers "does this rectangle
 *    contain any occupied pixel?" with four lookups.
 *  - Words are placed largest first. For each word, every free position for
 *    its box is counted and one is picked at random (seeded, so results
 *    repeat). If none exists, the other orientation is tried, then the word
 *    is shrunk and tried again, down to the minimum font size.
 *  - Only the word's actual letter pixels (widened by the margin) are marked
 *    as occupied, so later words can tuck into gaps between letters.
 *  - Each word's size follows from the previous one:
 *        size = round((scaling * f/f_prev + (1 - scaling)) * size_prev)
 *    so scaling 0 sizes by rank only and scaling 1 by frequency.
 *  - If the largest size is not given, it is found from a trial layout of
 *    the two most frequent words (harmonic mean of their fitted sizes).
 */
package calligram;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.Shape;
import java.awt.font.FontRenderContext;
import java.awt.font.GlyphVector;
import java.awt.geom.AffineTransform;
import java.awt.geom.Area;
import java.awt.geom.Ellipse2D;
import java.awt.geom.Path2D;
import java.awt.geom.Rectangle2D;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Random;
import javax.imageio.ImageIO;

public final class Engine {

    public static final String[] SHAPES = {
        "rectangle", "ellipse", "circle", "square", "cloud",
        "heart", "diamond", "triangle", "star"
    };

    public static final class Params {
        public int width = 900, height = 500, margin = 4;
        public int maxFont = 0;          // 0 = automatic
        public int minFont = 8;
        public double scaling = 0.5;
        public long seed = 42;
        public String font = "Arial";
        public String rotate = "none";   // none | 90 | random
        public String shape = "rectangle";
        public String mask = "";         // image file; overrides shape
        public double outline = 0;       // outline stroke width in px; 0 = none
        /** clearance around each placed word as a share of its font size
         *  (at least margin/2 pixels), so big words keep small ones further away */
        public double spacing = 0.0;
        /** the mask image colours its regions (one colour per region); words
         *  can then be kept inside their own region (layout with regions) */
        public boolean regions = false;
        /** areas from a Stata-format shapefile (text export of _ID,_X,_Y); overrides shape and mask */
        public String shapes = "";
        public String projection = "auto";
        /** place words as close as possible to their point (location) */
        public boolean near = false;
    }

    public static final class Result {
        public int[] size, rot;
        public double[] tx, ty;
        public double[] bx, by, bw, bh;   // ink box on the canvas (for hovering)
        public double[] adv;              // advance width (for SVG textLength)
        public boolean[] placed;
        public int nPlaced;
    }

    private final Params p;
    private final int W, H;
    private final FontRenderContext frc;
    private final Fonts.Resolved rf;     // the chosen font
    private final Font fb;               // for words the chosen font cannot draw
    /** number of words drawn with the fallback font (for a note to the user) */
    public final java.util.concurrent.atomic.AtomicInteger fallbackWords = new java.util.concurrent.atomic.AtomicInteger();
    public String family() { return rf.family; }
    private final boolean[] allowed;
    private final int allowedCount;
    private Bits base;
    private int[] maskRGB;                 // region colour (or shapefile area label) of each pixel (-1 = none)
    private Shapes shapesObj;              // areas from a shapefile, if any
    public Shapes shapes() { return shapesObj; }
    private boolean[] interior;            // pixel far enough from any region border
    private final Map<Integer, Bits> notRegion = new HashMap<>();   // colour -> everything outside it
    private final Map<Integer, int[]> regionBox = new HashMap<>();  // colour -> x0, y0, x1, y1 of its room
    public final String warning;
    /** SVG path data ("d" attribute) of the shape outline, or "" if none. */
    public final String outlineSvg;

    public Engine(Params p) throws Exception {
        this.p = p;
        this.W = p.width;
        this.H = p.height;
        BufferedImage one = new BufferedImage(1, 1, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = one.createGraphics();
        hints(g);
        this.frc = g.getFontRenderContext();
        g.dispose();

        this.rf = Fonts.resolve(p.font);
        this.fb = Fonts.fallback();
        this.warning = rf.note;

        boolean[] a0;
        if (!p.shapes.isEmpty()) {
            shapesObj = new Shapes(p.shapes, p.projection, W, H);
            a0 = new boolean[W * H];
            maskRGB = new int[W * H];
            for (int i = 0; i < W * H; i++) {
                a0[i] = shapesObj.label[i] > 0;
                maskRGB[i] = a0[i] ? shapesObj.label[i] : -1;
            }
        } else {
            a0 = p.mask.isEmpty() ? shapeMask(p.shape) : imageMask(p.mask);
        }
        if (p.regions && maskRGB != null) {
            // keep words clear of region borders as they keep clear of the outline
            // keep words clear of region borders as they keep clear of the
            // outline, with a small clearance so narrow areas (Japan, Chile)
            // still have room
            int r = p.outline > 0 ? (int) Math.ceil(p.outline / 2.0) + 1 : 1;
            this.interior = regionInterior(maskRGB, W, H, r);
        }
        if (p.outline > 0) {
            this.outlineSvg = shapesObj != null ? shapesObj.borders
                : p.mask.isEmpty() ? shapePath(p.shape)
                : (p.regions && maskRGB != null ? regionBorders() : tracePath(a0));
            // Keep words clear of the line: shrink the usable area by half the
            // stroke width plus 2 px
            a0 = erode(a0, (int) Math.ceil(p.outline / 2.0) + 2);
        } else {
            this.outlineSvg = "";
        }
        this.allowed = a0;
        // starting canvas for every layout pass: occupied outside the shape
        this.base = new Bits(W, H);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (!a0[y * W + x]) base.set(x, y);
        int c = 0;
        for (boolean b : allowed) if (b) c++;
        this.allowedCount = c;
        if (c == 0) throw new IllegalArgumentException("the shape or mask leaves no room for words");
    }

    public boolean[] allowedPixels() { return allowed; }
    /** region colour of each canvas pixel (-1 = none); null without regions (for tests) */
    public int[] regionPixels() { return maskRGB; }

    private static void hints(Graphics2D g) {
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_ON);
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
    }

    /** The chosen font at a size (used by tests to draw Latin words). */
    public Font font(int size) {
        return rf.base.deriveFont((float) size);
    }

    /** The glyphs of a word at a size: the chosen font if it can draw every
     *  character, otherwise the fallback font. Scripts that need shaping
     *  (letters joining, right-to-left) are laid out properly. The same glyphs
     *  are used to measure, to pack and to draw (as SVG paths). */
    public GlyphVector glyphs(String word, int size) {
        Font base = rf.base.canDisplayUpTo(word) == -1 ? rf.base : fb;
        Font f = base.deriveFont((float) size);
        char[] c = word.toCharArray();
        if (Font.textRequiresLayout(c, 0, c.length)) {
            boolean rtl = java.text.Bidi.requiresBidi(c, 0, c.length)
                && !new java.text.Bidi(word, java.text.Bidi.DIRECTION_DEFAULT_LEFT_TO_RIGHT).baseIsLeftToRight();
            return f.layoutGlyphVector(frc, c, 0, c.length, rtl ? Font.LAYOUT_RIGHT_TO_LEFT : Font.LAYOUT_LEFT_TO_RIGHT);
        }
        return f.createGlyphVector(frc, word);
    }

    /** true if a word needs the fallback font */
    public boolean usesFallback(String word) { return rf.base.canDisplayUpTo(word) != -1; }

    /** Ink rectangle of a word relative to its text origin (left end of baseline). */
    public Rectangle2D ink(String word, int size) {
        return glyphs(word, size).getOutline().getBounds2D();
    }

    /** SVG path data for a placed word: its exact letter outlines, moved to
     *  the text origin (tx, ty) and turned by orient degrees. Written compactly:
     *  every point is first rounded to 0.1 pixel on the canvas, then stored as
     *  the step from the previous point (lower-case, relative commands), so the
     *  steps add up exactly and nothing drifts. */
    public String svgPath(String word, int size, int orient, double tx, double ty) {
        AffineTransform at = AffineTransform.getTranslateInstance(tx, ty);
        if (orient != 0) at.rotate(Math.toRadians(orient));
        java.awt.geom.PathIterator it = glyphs(word, size).getOutline().getPathIterator(at);
        StringBuilder b = new StringBuilder(word.length() * 120);
        double[] c = new double[6];
        long cx = 0, cy = 0, sx = 0, sy = 0;          // current point and subpath start, in tenths
        for (; !it.isDone(); it.next()) {
            int t = it.currentSegment(c), n;
            char cmd;
            switch (t) {
                case java.awt.geom.PathIterator.SEG_MOVETO:  cmd = 'm'; n = 1; break;
                case java.awt.geom.PathIterator.SEG_LINETO:  cmd = 'l'; n = 1; break;
                case java.awt.geom.PathIterator.SEG_QUADTO:  cmd = 'q'; n = 2; break;
                case java.awt.geom.PathIterator.SEG_CUBICTO: cmd = 'c'; n = 3; break;
                default: cmd = 'z'; n = 0; break;
            }
            b.append(cmd);
            if (n == 0) { cx = sx; cy = sy; continue; }
            long px = 0, py = 0;
            for (int k = 0; k < n; k++) {
                px = Math.round(c[2 * k] * 10);
                py = Math.round(c[2 * k + 1] * 10);
                num(b, px - cx, k > 0);
                num(b, py - cy, true);
            }
            cx = px; cy = py;                             // the segment's end point
            if (t == java.awt.geom.PathIterator.SEG_MOVETO) { sx = cx; sy = cy; }
        }
        return b.toString();
    }
    /** append a value given in tenths, as short as SVG allows */
    private static void num(StringBuilder b, long tenths, boolean sep) {
        boolean neg = tenths < 0;
        long a = Math.abs(tenths);
        if (neg) b.append('-');
        else if (sep) b.append(' ');
        if (a % 10 == 0) b.append(a / 10);
        else {
            if (a >= 10) b.append(a / 10);
            b.append('.').append(a % 10);
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    //
    // The canvas is a bitset: 64 pixels per long, one bit per pixel, 1 =
    // occupied (outside the shape, or already covered by a word). Finding a
    // spot for a word's box:
    //   1. try a few random positions, each checked a row at a time 64
    //      pixels per operation (most words find a spot in one or two tries);
    //   2. if none of those is free, scan every position at once with
    //      bit-parallel run detection, which either picks one at random or
    //      proves that none exists (then the word is turned or shrunk).
    // Both steps pick uniformly among the free positions, as before. Placing
    // a word marks only its own (widened) letter pixels, so the cost per word
    // no longer grows with the canvas.

    private static final int RANDOM_TRIES = 48;

    /** Lay out the words. pool may be null (single thread). For a single
     *  cloud the size search runs its candidate starting sizes in parallel;
     *  the result is the same as running them one after another. */
    public Result layout(String[] words, double[] freq, java.util.concurrent.ExecutorService pool) throws Exception {
        return layout(words, freq, null, pool);
    }

    /** Colours (#rrggbb) of the regions in the mask, as integers; words whose
     *  region is not in the mask cannot be placed. */
    public static int regionColor(String c) {
        if (c == null) return -1;
        c = c.trim().toLowerCase(Locale.ROOT);
        if (c.startsWith("#")) c = c.substring(1);
        if (c.length() == 3) c = "" + c.charAt(0) + c.charAt(0) + c.charAt(1) + c.charAt(1) + c.charAt(2) + c.charAt(2);
        if (!c.matches("[0-9a-f]{6}")) return -1;
        return Integer.parseInt(c, 16);
    }

    /** Region key of a word: "L<label>[@x,y]" (a shapefile area, optionally
     *  with the word's point on the canvas) or "#rrggbb" (a mask colour). */
    public static int regionKey(String r) {
        if (r == null) return -1;
        if (r.startsWith("L")) {
            int at = r.indexOf('@');
            try { return Integer.parseInt(at < 0 ? r.substring(1) : r.substring(1, at)); }
            catch (NumberFormatException e) { return -1; }
        }
        return regionColor(r);
    }
    /** the word's point on the canvas, or null */
    static double[] regionPoint(String r) {
        if (r == null) return null;
        int at = r.indexOf('@');
        if (at < 0) return null;
        String[] xy = r.substring(at + 1).split(",");
        try { return new double[]{Double.parseDouble(xy[0]), Double.parseDouble(xy[1])}; }
        catch (RuntimeException e) { return null; }
    }

    /** Lay out the words; region[i] (may be null) says which area of the mask
     *  or shapefile word i must stay inside (see regionKey). */
    public Result layout(String[] words, double[] freq, String[] region, java.util.concurrent.ExecutorService pool) throws Exception {
        int n = words.length;
        int[] reg = null;
        double[][] pts = null;
        if (region != null && p.regions && maskRGB != null) {
            reg = new int[n];
            pts = new double[n][];
            for (int i = 0; i < n; i++) { reg[i] = regionKey(region[i]); pts[i] = regionPoint(region[i]); }
            prepareRegions(reg);
        }
        final int[] rg = reg;
        final double[][] pt = pts;
        int start;
        if (p.maxFont > 0) {
            start = p.maxFont;
        } else if (rg != null) {
            // regions: the biggest words may sit in small regions, so a trial
            // with the first two words says little; start from a quarter of the
            // canvas height and let the size search below shrink if needed
            start = Math.max(p.minFont, H / 4);
        } else if (n == 1) {
            start = H;
        } else {
            Result r0 = pass(Arrays.copyOf(words, 2), Arrays.copyOf(freq, 2), H, null, null);
            if (r0.placed[0] && r0.placed[1]) {
                start = (int) (2.0 * r0.size[0] * r0.size[1] / (r0.size[0] + r0.size[1]));
            } else if (r0.placed[0]) {
                start = r0.size[0];
            } else {
                start = H;
            }
        }
        Result best = pass(words, freq, start, rg, pt);
        // Target: the placed words carry at least 95% of all mentions (counts).
        // Dropping a few of the rarest words then costs little, and the big
        // words keep their size; shrinking everything to fit every rare word
        // would flatten the cloud.
        double total = 0;
        for (double v : freq) total += Math.max(0, v);
        final double need = 0.95 * total;
        if (covered(best, freq) >= need) return best;

        // Fewer than 95% placed: try up to 8 smaller starting sizes (each 15%
        // smaller). Take the first, in that order, that reaches 95%, otherwise
        // the one that placed most. Run them in parallel when a pool is given.
        java.util.List<Integer> sizes = new java.util.ArrayList<>();
        int s = start;
        for (int k = 0; k < 8; k++) {
            s = (int) Math.floor(s * 0.85);
            if (s < p.minFont) break;
            sizes.add(s);
        }
        Result[] tries = new Result[sizes.size()];
        if (pool != null && sizes.size() > 1) {
            java.util.List<java.util.concurrent.Future<Result>> fs = new java.util.ArrayList<>();
            for (final int sz : sizes) fs.add(pool.submit(() -> pass(words, freq, sz, rg, pt)));
            for (int k = 0; k < fs.size(); k++) tries[k] = fs.get(k).get();
        } else {
            for (int k = 0; k < sizes.size(); k++) {
                tries[k] = pass(words, freq, sizes.get(k), rg, pt);
                if (covered(tries[k], freq) >= need) break;
            }
        }
        for (Result r : tries) {
            if (r == null) break;
            if (covered(r, freq) >= need) return r;
        }
        // 95% cannot be reached (e.g. regions too small for some words): take
        // the largest size that places nearly as much (97%) as the best trial,
        // rather than shrinking every word for a small gain
        double top = covered(best, freq);
        for (Result r : tries) if (r != null) top = Math.max(top, covered(r, freq));
        if (covered(best, freq) >= 0.97 * top) return best;
        for (Result r : tries) if (r != null && covered(r, freq) >= 0.97 * top) return r;
        return best;
    }

    /** total count of the words a layout placed */
    private static double covered(Result r, double[] freq) {
        double s = 0;
        for (int i = 0; i < freq.length; i++) if (r.placed[i]) s += Math.max(0, freq[i]);
        return s;
    }

    /** Single-threaded convenience (used by tests and the old entry point). */
    public Result layout(String[] words, double[] freq) {
        try { return layout(words, freq, null); }
        catch (Exception e) { throw new RuntimeException(e); }
    }

    private int preferred(int i, Random rng) {
        if (p.rotate.equals("90")) return (i % 2 == 0) ? 0 : 90;      // i is 0-based: biggest word horizontal
        if (p.rotate.equals("random")) return rng.nextDouble() < 0.6 ? 0 : 90;
        return 0;
    }

    private Result pass(String[] words, double[] freq, int startSize, int[] reg, double[][] pt) {
        int n = words.length;
        Result r = new Result();
        r.size = new int[n]; r.rot = new int[n];
        r.tx = new double[n]; r.ty = new double[n];
        r.bx = new double[n]; r.by = new double[n]; r.bw = new double[n]; r.bh = new double[n];
        r.adv = new double[n];
        r.placed = new boolean[n];

        Bits occ = new Bits(W, H);
        System.arraycopy(base.b, 0, occ.b, 0, base.b.length);
        Scan scan = new Scan(W, H);

        Random rng = new Random(p.seed);
        double fmax = freq[0] > 0 ? freq[0] : 1;
        double last = 1.0;
        int lastSize = startSize;   // size of the last word actually placed
        int size;
        int m = p.margin;

        for (int i = 0; i < n; i++) {
            double f = freq[i] / fmax;
            if (!(f > 0)) continue;
            size = lastSize;
            if (p.scaling != 0) {
                size = (int) Math.round((p.scaling * (f / last) + (1 - p.scaling)) * size);
            }
            // regions: each word's size comes straight from its count, scaled
            // to the largest (letter height ~ count^scaling, so with the default
            // 0.5 a word's area is in proportion to its count); a word may shrink
            // to fit its area but never grows beyond its share
            if (reg != null) size = Math.max(1, (int) Math.round(startSize * Math.pow(f, p.scaling)));
            int planned = size;
            Bits outside = null;
            if (reg != null) {
                outside = reg[i] < 0 ? null : notRegion.get(reg[i]);
                if (outside == null) { last = f; lastSize = planned; continue; }   // region not in the mask
            }
            int pref = preferred(i, rng);
            int orient = pref;
            boolean tried = false;
            int[] pos = null;
            Rectangle2D ink = null;
            int bw = 0, bh = 0;
            if (outside != null) {
                // the largest size (and an orientation) at which the word fits
                // in its region: the planned size, else bisection down to minFont
                int[] box = regionBox.get(reg[i]);
                double[] target = (p.near && pt != null) ? pt[i] : null;
                // near: first the largest size at which the word fits close to
                // its own point; only if it cannot, the nearest free spot anywhere
                Object[] hit = null;
                for (int stage = target == null ? 1 : 0; stage < 2 && hit == null; stage++) {
                    boolean strict = stage == 0;
                    hit = fitInRegion(words[i], size, pref, outside, box, occ, scan, rng, m, target, strict);
                    if (hit == null) {
                        int lo = p.minFont, hi = size - 1;
                        while (lo <= hi) {
                            int mid = (lo + hi) >>> 1;
                            Object[] h2 = fitInRegion(words[i], mid, pref, outside, box, occ, scan, rng, m, target, strict);
                            if (h2 != null) { hit = h2; lo = mid + 1; } else hi = mid - 1;
                        }
                    }
                }
                if (hit == null) { last = f; lastSize = planned; continue; }
                size = (Integer) hit[0]; orient = (Integer) hit[1]; pos = (int[]) hit[2];
                ink = (Rectangle2D) hit[3]; bw = (Integer) hit[4]; bh = (Integer) hit[5];
            }
            while (outside == null) {
                if (size < p.minFont) break;
                ink = ink(words[i], size);
                int iw = (int) Math.ceil(ink.getWidth()), ih = (int) Math.ceil(ink.getHeight());
                bw = (orient == 0 ? iw : ih) + m;
                bh = (orient == 0 ? ih : iw) + m;
                pos = find(occ, outside, scan, bw, bh, rng);
                if (pos != null) break;
                if (!tried && !p.rotate.equals("none")) {
                    orient = 90 - orient;
                    tried = true;
                } else {
                    size -= Math.max(1, size / 25);
                    orient = pref;
                }
            }
            // Did not fit even at the minimum size: skip this word but keep going,
            // since shorter words may still fit in the remaining gaps.
            if (size < p.minFont) { if (reg != null) { last = f; lastSize = planned; } continue; }

            double x0 = pos[0], y0 = pos[1];
            double tx, ty;
            if (orient == 0) {
                tx = x0 + m / 2.0 - ink.getX();
                ty = y0 + m / 2.0 - ink.getY();
            } else {
                tx = x0 + m / 2.0 + ink.getY() + ink.getHeight();
                ty = y0 + m / 2.0 - ink.getX();
            }
            r.size[i] = size; r.rot[i] = orient; r.tx[i] = tx; r.ty[i] = ty;
            r.bx[i] = x0 + m / 2.0; r.by[i] = y0 + m / 2.0;
            r.bw[i] = bw - m; r.bh[i] = bh - m;
            r.adv[i] = glyphs(words[i], size).getLogicalBounds().getWidth();
            r.placed[i] = true; r.nPlaced++;
            stamp(occ, words[i], size, orient, tx, ty, pos[0], pos[1], bw, bh);
            last = f;
            lastSize = reg != null ? planned : size;
        }
        return r;
    }

    /** A free top-left position for a bw x bh box (uniform over all free
     *  positions), or null if there is none. */
    private int[] find(Bits occ, Bits outside, Scan scan, int bw, int bh, Random rng) {
        if (bw > W || bh > H || bw <= 0 || bh <= 0) return null;
        int nx = W - bw + 1, ny = H - bh + 1;
        for (int t = 0; t < RANDOM_TRIES; t++) {
            int x = rng.nextInt(nx), y = rng.nextInt(ny);
            if (occ.boxFree(x, y, bw, bh, outside)) return new int[]{x, y};
        }
        return scan.pick(occ, outside, bw, bh, rng);
    }

    /** Try a word at one size in its region (both orientations if rotation is
     *  allowed): {size, orientation, position, ink, box width, box height}, or null. */
    private Object[] fitInRegion(String word, int size, int pref, Bits outside, int[] box,
                                 Bits occ, Scan scan, Random rng, int m, double[] target, boolean strict) {
        if (box == null) return null;
        Rectangle2D ink = ink(word, size);
        int iw = (int) Math.ceil(ink.getWidth()), ih = (int) Math.ceil(ink.getHeight());
        int[] orients = p.rotate.equals("none") ? new int[]{pref} : new int[]{pref, 90 - pref};
        for (int orient : orients) {
            int bw = (orient == 0 ? iw : ih) + m, bh = (orient == 0 ? ih : iw) + m;
            int x0 = Math.max(0, box[0] - m), y0 = Math.max(0, box[1] - m);
            int x1 = Math.min(W - 1, box[2] + m), y1 = Math.min(H - 1, box[3] + m);
            int nx = x1 - x0 - bw + 2, ny = y1 - y0 - bh + 2;
            if (nx <= 0 || ny <= 0) continue;
            int[] pos = null;
            if (target != null) {
                // near: the free position whose box centre is closest to the word's point
                // strict: the box centre must be within about the word's own width of its point
                double reach = strict ? Math.max(24, 0.75 * Math.max(bw, bh)) : Double.MAX_VALUE;
                pos = scan.pickNearest(occ, outside, bw, bh, y0, y1, target[0] - bw / 2.0, target[1] - bh / 2.0, reach);
                if (pos != null) return new Object[]{size, orient, pos, ink, bw, bh};
                continue;
            }
            for (int t = 0; t < RANDOM_TRIES && pos == null; t++) {
                int x = x0 + rng.nextInt(nx), y = y0 + rng.nextInt(ny);
                if (x + bw <= W && y + bh <= H && occ.boxFree(x, y, bw, bh, outside)) pos = new int[]{x, y};
            }
            if (pos == null) pos = scan.pick(occ, outside, bw, bh, rng, y0, y1);
            if (pos != null) return new Object[]{size, orient, pos, ink, bw, bh};
        }
        return null;
    }

    // ── Regions ──────────────────────────────────────────────────────────────

    /** Pixels at least r pixels (square) away from any change of region colour. */
    private static boolean[] regionInterior(int[] lab, int W, int H, int r) {
        boolean[] h = new boolean[W * H];
        for (int y = 0; y < H; y++) {
            int base = y * W;
            int run = 0;
            int[] left = new int[W];
            for (int x = 0; x < W; x++) { run = (x > 0 && lab[base + x] == lab[base + x - 1]) ? run + 1 : 0; left[x] = run; }
            run = 0;
            for (int x = W - 1; x >= 0; x--) {
                run = (x < W - 1 && lab[base + x] == lab[base + x + 1]) ? run + 1 : 0;
                h[base + x] = lab[base + x] >= 0 && left[x] >= r && run >= r;
            }
        }
        boolean[] out = new boolean[W * H];
        for (int x = 0; x < W; x++) {
            int[] up = new int[H];
            int run = 0;
            for (int y = 0; y < H; y++) { run = (y > 0 && h[y * W + x] && h[(y - 1) * W + x] && lab[y * W + x] == lab[(y - 1) * W + x]) ? run + 1 : 0; up[y] = run; }
            run = 0;
            for (int y = H - 1; y >= 0; y--) {
                run = (y < H - 1 && h[y * W + x] && h[(y + 1) * W + x] && lab[y * W + x] == lab[(y + 1) * W + x]) ? run + 1 : 0;
                out[y * W + x] = h[y * W + x] && up[y] >= r && run >= r;
            }
        }
        return out;
    }

    /** For every region colour used by the words: a bitset of everything
     *  outside that region's interior (plus outside the mask). */
    private synchronized void prepareRegions(int[] reg) {
        java.util.Set<Integer> want = new java.util.HashSet<>();
        for (int c : reg) if (c >= 0 && !notRegion.containsKey(c)) want.add(c);
        if (want.isEmpty()) return;
        Map<Integer, Bits> made = new HashMap<>();
        for (int c : want) {
            Bits b = new Bits(W, H);
            java.util.Arrays.fill(b.b, -1L);
            made.put(c, b);
        }
        Map<Integer, int[]> boxes = new HashMap<>();
        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) {
                int i = y * W + x;
                if (!allowed[i] || !interior[i]) continue;
                Bits b = made.get(maskRGB[i]);
                if (b == null) continue;
                b.b[y * b.WW + (x >>> 6)] &= ~(1L << (x & 63));
                int[] bx = boxes.get(maskRGB[i]);
                if (bx == null) boxes.put(maskRGB[i], new int[]{x, y, x, y});
                else { if (x < bx[0]) bx[0] = x; if (y < bx[1]) bx[1] = y; if (x > bx[2]) bx[2] = x; if (y > bx[3]) bx[3] = y; }
            }
        }
        regionBox.putAll(boxes);
        // a region with no room at all is left out (its words cannot be placed)
        for (Map.Entry<Integer, Bits> e : made.entrySet()) {
            boolean any = false;
            Bits b = e.getValue();
            long tail = (W & 63) == 0 ? -1L : (-1L >>> (64 - (W & 63)));
            for (int y = 0; y < H && !any; y++) {
                for (int k = 0; k < b.WW; k++) {
                    long free = ~b.b[y * b.WW + k];
                    if (k == b.WW - 1) free &= tail;
                    if (free != 0) { any = true; break; }
                }
            }
            if (any) notRegion.put(e.getKey(), b);
        }
    }

    /** Borders of every region in the mask, each traced inside its bounding box. */
    private String regionBorders() {
        Map<Integer, int[]> box = new HashMap<>();          // colour -> x0, y0, x1, y1
        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) {
                int c = maskRGB[y * W + x];
                if (c < 0) continue;
                int[] b = box.get(c);
                if (b == null) box.put(c, new int[]{x, y, x, y});
                else { if (x < b[0]) b[0] = x; if (y < b[1]) b[1] = y; if (x > b[2]) b[2] = x; if (y > b[3]) b[3] = y; }
            }
        }
        StringBuilder out = new StringBuilder();
        for (Map.Entry<Integer, int[]> e : box.entrySet()) {
            int[] b = e.getValue();
            int w = b[2] - b[0] + 1, h = b[3] - b[1] + 1;
            if (w < 3 || h < 3) continue;
            boolean[] in = new boolean[w * h];
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) in[y * w + x] = maskRGB[(b[1] + y) * W + b[0] + x] == e.getKey();
            out.append(tracePath(in, w, h, b[0], b[1]));
        }
        return out.toString();
    }

    /** Mark the word's letter pixels, widened by half the margin, as occupied. */
    private void stamp(Bits occ, String word, int size, int orient,
                       double tx, double ty, int bx, int by, int bw, int bh) {
        int r = Math.max((int) Math.ceil(p.margin / 2.0), (int) Math.round(p.spacing * size));
        int pad = r + 2;
        int ox = bx - pad, oy = by - pad;
        int iw = bw + 2 * pad, ih = bh + 2 * pad;
        BufferedImage img = new BufferedImage(iw, ih, BufferedImage.TYPE_BYTE_GRAY);
        Graphics2D g = img.createGraphics();
        hints(g);
        g.setColor(Color.WHITE);
        g.translate(tx - ox, ty - oy);
        if (orient != 0) g.rotate(Math.toRadians(orient));
        g.fill(glyphs(word, size).getOutline());
        g.dispose();
        byte[] px = ((java.awt.image.DataBufferByte) img.getRaster().getDataBuffer()).getData();

        // widen horizontally then vertically by r (sliding counts, linear time)
        boolean[] hd = new boolean[iw * ih];
        for (int yy = 0; yy < ih; yy++) {
            int run = 0, base = yy * iw;
            // count of ink pixels within [x-r, x+r]
            for (int xx = 0; xx < Math.min(r, iw); xx++) if (px[base + xx] != 0) run++;
            for (int xx = 0; xx < iw; xx++) {
                int add = xx + r, rem = xx - r - 1;
                if (add < iw && px[base + add] != 0) run++;
                if (rem >= 0 && px[base + rem] != 0) run--;
                hd[base + xx] = run > 0;
            }
        }
        for (int xx = 0; xx < iw; xx++) {
            int run = 0;
            for (int yy = 0; yy < Math.min(r, ih); yy++) if (hd[yy * iw + xx]) run++;
            for (int yy = 0; yy < ih; yy++) {
                int add = yy + r, rem = yy - r - 1;
                if (add < ih && hd[add * iw + xx]) run++;
                if (rem >= 0 && hd[rem * iw + xx]) run--;
                if (run > 0) {
                    int cx = ox + xx, cy = oy + yy;
                    if (cx >= 0 && cx < W && cy >= 0 && cy < H) occ.set(cx, cy);
                }
            }
        }
    }

    /** Canvas occupancy, 64 pixels per long. */
    static final class Bits {
        final int W, H, WW;
        final long[] b;
        Bits(int W, int H) { this.W = W; this.H = H; this.WW = (W + 63) >>> 6; this.b = new long[WW * H]; }
        void set(int x, int y) { b[y * WW + (x >>> 6)] |= 1L << (x & 63); }
        boolean get(int x, int y) { return (b[y * WW + (x >>> 6)] >>> (x & 63) & 1L) != 0; }
        /** true if no pixel in the w x h box at (x, y) is occupied */
        boolean boxFree(int x, int y, int w, int h) { return boxFree(x, y, w, h, null); }
        /** ... nor marked in extra (may be null): e.g. outside the word's region */
        boolean boxFree(int x, int y, int w, int h, Bits extra) {
            long[] e = extra == null ? null : extra.b;
            int x1 = x + w - 1, a = x >>> 6, z = x1 >>> 6;
            long first = -1L << (x & 63), lastMask = -1L >>> (63 - (x1 & 63));
            for (int yy = y; yy < y + h; yy++) {
                int base = yy * WW;
                if (a == z) {
                    long v = b[base + a] | (e == null ? 0 : e[base + a]);
                    if ((v & first & lastMask) != 0) return false;
                } else {
                    if (((b[base + a] | (e == null ? 0 : e[base + a])) & first) != 0) return false;
                    for (int k = a + 1; k < z; k++) if ((b[base + k] | (e == null ? 0 : e[base + k])) != 0) return false;
                    if (((b[base + z] | (e == null ? 0 : e[base + z])) & lastMask) != 0) return false;
                }
            }
            return true;
        }
    }

    /** Bit-parallel search for every free top-left position of a w x h box.
     *  Row step: a position is good if w free pixels start there (found by
     *  ANDing the free bits with shifted copies of themselves, doubling the
     *  run length each time). Column step: the same doubling over h rows. */
    static final class Scan {
        final int W, H, WW;
        final long[] A, T;
        Scan(int W, int H) { this.W = W; this.H = H; this.WW = (W + 63) >>> 6; A = new long[WW * H]; T = new long[WW]; }

        /** out[k] = in[k] shifted so that bit x takes the value of bit x+s (s >= 1) */
        private void shiftAnd(long[] arr, int base, int s) {
            int q = s >>> 6, r = s & 63;
            for (int k = 0; k < WW; k++) {
                int i0 = k + q, i1 = k + q + 1;
                long lo = i0 < WW ? arr[base + i0] : 0L;
                long v;
                if (r == 0) v = lo;
                else {
                    long hi = i1 < WW ? arr[base + i1] : 0L;
                    v = (lo >>> r) | (hi << (64 - r));
                }
                T[k] = v;
            }
            for (int k = 0; k < WW; k++) arr[base + k] &= T[k];
        }

        int[] pick(Bits occ, int w, int h, Random rng) { return pick(occ, null, w, h, rng, 0, H - 1); }
        int[] pick(Bits occ, Bits extra, int w, int h, Random rng) { return pick(occ, extra, w, h, rng, 0, H - 1); }
        /** only rows ry0..ry1 can hold the box (a region's bounding box) */
        int[] pick(Bits occ, Bits extra, int w, int h, Random rng, int ry0, int ry1) {
            if (ry1 - ry0 + 1 < h) return null;
            // free bits, with the bits past the right edge cleared
            long tail = (W & 63) == 0 ? -1L : (-1L >>> (64 - (W & 63)));
            for (int y = ry0; y <= ry1; y++) {
                int base = y * WW;
                if (extra == null) for (int k = 0; k < WW; k++) A[base + k] = ~occ.b[base + k];
                else for (int k = 0; k < WW; k++) A[base + k] = ~(occ.b[base + k] | extra.b[base + k]);
                A[base + WW - 1] &= tail;
                int s = 1;
                while (s * 2 <= w) { shiftAnd(A, base, s); s *= 2; }
                if (s < w) shiftAnd(A, base, w - s);
            }
            // columns: position (x, y) needs rows y .. y+h-1 all good
            int s = 1;
            while (s * 2 <= h) { rowsAnd(s, ry0, ry1); s *= 2; }
            if (s < h) rowsAnd(h - s, ry0, ry1);
            long count = 0;
            int ylim = ry1 - h + 1;
            for (int y = ry0; y <= ylim; y++) for (int k = 0; k < WW; k++) count += Long.bitCount(A[y * WW + k]);
            if (count == 0) return null;
            long target = (long) (rng.nextDouble() * count);
            for (int y = ry0; y <= ylim; y++) {
                for (int k = 0; k < WW; k++) {
                    long v = A[y * WW + k];
                    int c = Long.bitCount(v);
                    if (target >= c) { target -= c; continue; }
                    while (target-- > 0) v &= v - 1;          // drop lowest set bits
                    return new int[]{(k << 6) + Long.numberOfTrailingZeros(v), y};
                }
            }
            return null;
        }

        /** The free top-left position closest to (tx, ty), searching rows ry0..ry1. */
        int[] pickNearest(Bits occ, Bits extra, int w, int h, int ry0, int ry1, double tx, double ty, double reach) {
            if (ry1 - ry0 + 1 < h) return null;
            long tail = (W & 63) == 0 ? -1L : (-1L >>> (64 - (W & 63)));
            for (int y = ry0; y <= ry1; y++) {
                int base = y * WW;
                if (extra == null) for (int k = 0; k < WW; k++) A[base + k] = ~occ.b[base + k];
                else for (int k = 0; k < WW; k++) A[base + k] = ~(occ.b[base + k] | extra.b[base + k]);
                A[base + WW - 1] &= tail;
                int s = 1;
                while (s * 2 <= w) { shiftAnd(A, base, s); s *= 2; }
                if (s < w) shiftAnd(A, base, w - s);
            }
            int s = 1;
            while (s * 2 <= h) { rowsAnd(s, ry0, ry1); s *= 2; }
            if (s < h) rowsAnd(h - s, ry0, ry1);
            int bx = -1, by = -1;
            double bd = Double.MAX_VALUE;
            int ylim = ry1 - h + 1;
            for (int y = ry0; y <= ylim; y++) {
                double dy = y - ty, dy2 = dy * dy;
                if (dy2 >= bd) continue;
                for (int k = 0; k < WW; k++) {
                    long v = A[y * WW + k];
                    while (v != 0) {
                        int x = (k << 6) + Long.numberOfTrailingZeros(v);
                        v &= v - 1;
                        double dx = x - tx, d = dx * dx + dy2;
                        if (d < bd) { bd = d; bx = x; by = y; }
                    }
                }
            }
            if (bx < 0 || bd > reach * reach) return null;
            return new int[]{bx, by};
        }

        /** row y &= row y+s, for rows ry0..ry1 (rows past ry1 count as all-occupied) */
        private void rowsAnd(int s, int ry0, int ry1) {
            for (int y = ry0; y <= ry1; y++) {
                int base = y * WW, other = (y + s) * WW;
                if (y + s <= ry1) for (int k = 0; k < WW; k++) A[base + k] &= A[other + k];
                else for (int k = 0; k < WW; k++) A[base + k] = 0L;
            }
        }
    }

    // ── Shapes and masks ─────────────────────────────────────────────────────

    /** Outline of a named shape in its own unit coordinates. */
    public static Shape unitShape(String s) {
        switch (s) {
            case "circle":   return new Ellipse2D.Double(0, 0, 1, 1);
            case "square":   return new Rectangle2D.Double(0, 0, 1, 1);
            case "diamond":  return poly(new double[]{0.375, 0, 0.75, 0.5, 0.375, 1, 0, 0.5});
            case "triangle": return poly(new double[]{0.5, 0, 1, 0.866, 0, 0.866});
            case "star": {
                double[] c = new double[20];
                for (int k = 0; k < 10; k++) {
                    double rad = (k % 2 == 0) ? 1.0 : 0.55;
                    double a = -Math.PI / 2 + k * Math.PI / 5;
                    c[2 * k] = rad * Math.cos(a);
                    c[2 * k + 1] = rad * Math.sin(a);
                }
                return poly(c);
            }
            case "heart": {
                int N = 400;
                double[] c = new double[2 * N];
                for (int k = 0; k < N; k++) {
                    double t = 2 * Math.PI * k / N, st = Math.sin(t);
                    c[2 * k] = 16 * st * st * st;
                    c[2 * k + 1] = -(13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t));
                }
                return poly(c);
            }
            case "cloud": {
                Area a = new Area(new RoundRectangle2D.Double(0.10, 0.52, 1.80, 0.40, 0.40, 0.40));
                double[][] circles = {{0.45, 0.58, 0.30}, {0.85, 0.42, 0.38}, {1.28, 0.46, 0.33}, {1.62, 0.62, 0.26}};
                for (double[] c : circles) a.add(new Area(new Ellipse2D.Double(c[0] - c[2], c[1] - c[2], 2 * c[2], 2 * c[2])));
                return a;
            }
            default: return null;
        }
    }

    private static Shape poly(double[] c) {
        Path2D.Double path = new Path2D.Double();
        path.moveTo(c[0], c[1]);
        for (int k = 2; k < c.length; k += 2) path.lineTo(c[k], c[k + 1]);
        path.closePath();
        return path;
    }

    /** The named shape scaled to fill the canvas (ellipse) or to fit it
     *  keeping its proportions (all others), centred, in pixel coordinates. */
    public Shape fittedShape(String s) {
        double pad = 4;
        if (s.equals("ellipse")) return new Ellipse2D.Double(pad, pad, W - 2 * pad, H - 2 * pad);
        Shape u = unitShape(s);
        if (u == null) throw new IllegalArgumentException("unknown shape: " + s);
        Rectangle2D b = u.getBounds2D();
        double sc = Math.min((W - 2 * pad) / b.getWidth(), (H - 2 * pad) / b.getHeight());
        AffineTransform at = new AffineTransform();
        at.translate(W / 2.0, H / 2.0);
        at.scale(sc, sc);
        at.translate(-b.getCenterX(), -b.getCenterY());
        return at.createTransformedShape(u);
    }

    private boolean[] shapeMask(String s) {
        boolean[] a = new boolean[W * H];
        if (s.equals("rectangle")) {
            int pad = 4;   // same small inset as the other shapes
            for (int y = pad; y < H - pad; y++) for (int x = pad; x < W - pad; x++) a[y * W + x] = true;
            return a;
        }
        BufferedImage img = new BufferedImage(W, H, BufferedImage.TYPE_BYTE_GRAY);
        Graphics2D g = img.createGraphics();
        g.setColor(Color.WHITE);
        g.fill(fittedShape(s));
        g.dispose();
        byte[] px = ((java.awt.image.DataBufferByte) img.getRaster().getDataBuffer()).getData();
        for (int i = 0; i < W * H; i++) a[i] = (px[i] & 0xff) >= 128;
        return a;
    }

    /** A picture fitted to the canvas the way a mask is: cropped to its
     *  non-white, opaque content (if any), scaled to fit keeping its
     *  proportions, and centred. Used to colour words from a picture. */
    public static BufferedImage fitImage(String path, int W, int H) throws Exception { return fitImage(path, W, H, false); }
    /** cover: fill the whole canvas (cropping what overflows) instead of fitting inside it */
    public static BufferedImage fitImage(String path, int W, int H, boolean cover) throws Exception {
        File f = new File(path);
        if (!f.isFile()) throw new java.io.FileNotFoundException("colour image not found: " + path);
        BufferedImage src = ImageIO.read(f);
        if (src == null) throw new java.io.IOException("cannot read colour image (use PNG, JPG, GIF or BMP): " + path);
        int bx0 = Integer.MAX_VALUE, by0 = Integer.MAX_VALUE, bx1 = -1, by1 = -1;
        for (int y = 0; y < src.getHeight(); y++) {
            for (int x = 0; x < src.getWidth(); x++) {
                int v = src.getRGB(x, y);
                int al = v >>> 24, r = (v >> 16) & 0xff, gg = (v >> 8) & 0xff, bb = v & 0xff;
                if (al >= 128 && 0.299 * r + 0.587 * gg + 0.114 * bb < 240) {
                    if (x < bx0) bx0 = x;
                    if (x > bx1) bx1 = x;
                    if (y < by0) by0 = y;
                    if (y > by1) by1 = y;
                }
            }
        }
        if (bx1 >= 0) src = src.getSubimage(bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1);
        double sc = cover ? Math.max((double) W / src.getWidth(), (double) H / src.getHeight())
                          : Math.min((double) W / src.getWidth(), (double) H / src.getHeight());
        int dw = (int) Math.round(src.getWidth() * sc), dh = (int) Math.round(src.getHeight() * sc);
        BufferedImage img = new BufferedImage(W, H, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = img.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.drawImage(src, (W - dw) / 2, (H - dh) / 2, dw, dh, null);
        g.dispose();
        return img;
    }

    /** Image mask: a pixel is available if it is opaque and not (near) white.
     *  The image is cropped to its shape, then scaled to fit the canvas,
     *  keeping its proportions, and centred. */
    private boolean[] imageMask(String path) throws Exception {
        File f = new File(path);
        if (!f.isFile()) throw new java.io.FileNotFoundException("mask image not found: " + path);
        BufferedImage src = ImageIO.read(f);
        if (src == null) throw new java.io.IOException("cannot read mask image (use PNG, JPG, GIF or BMP): " + path);
        // Crop to the shape: white or transparent margins around it (common in
        // exported graphs and downloaded icons) would otherwise waste canvas.
        int bx0 = Integer.MAX_VALUE, by0 = Integer.MAX_VALUE, bx1 = -1, by1 = -1;
        for (int y = 0; y < src.getHeight(); y++) {
            for (int x = 0; x < src.getWidth(); x++) {
                int v = src.getRGB(x, y);
                int al = v >>> 24, r = (v >> 16) & 0xff, gg = (v >> 8) & 0xff, bb = v & 0xff;
                if (al >= 128 && 0.299 * r + 0.587 * gg + 0.114 * bb < 240) {
                    if (x < bx0) bx0 = x;
                    if (x > bx1) bx1 = x;
                    if (y < by0) by0 = y;
                    if (y > by1) by1 = y;
                }
            }
        }
        if (bx1 < 0) throw new IllegalArgumentException("the mask image has no dark or coloured area to fill: " + path);
        src = src.getSubimage(bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1);
        double sc = Math.min((double) W / src.getWidth(), (double) H / src.getHeight());
        int dw = (int) Math.round(src.getWidth() * sc), dh = (int) Math.round(src.getHeight() * sc);
        BufferedImage img = new BufferedImage(W, H, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = img.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, p.regions
            ? RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR       // keep region colours exact
            : RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.drawImage(src, (W - dw) / 2, (H - dh) / 2, dw, dh, null);
        g.dispose();
        boolean[] a = new boolean[W * H];
        if (p.regions) maskRGB = new int[W * H];
        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) {
                int v = img.getRGB(x, y);
                int al = v >>> 24, r = (v >> 16) & 0xff, gg = (v >> 8) & 0xff, b = v & 0xff;
                double lum = 0.299 * r + 0.587 * gg + 0.114 * b;
                a[y * W + x] = al >= 128 && lum < 240;
                if (p.regions) maskRGB[y * W + x] = a[y * W + x] ? (v & 0xffffff) : -1;
            }
        }
        return a;
    }

    // ── Outlines ─────────────────────────────────────────────────────────────

    private static String num(double v) {
        return String.format(Locale.ROOT, "%.1f", v);
    }

    /** Exact outline of a named shape as SVG path data. */
    private String shapePath(String s) {
        Shape sh;
        if (s.equals("rectangle")) {
            double pad = 4;
            sh = new Rectangle2D.Double(pad, pad, W - 2 * pad, H - 2 * pad);
        } else {
            sh = fittedShape(s);
        }
        StringBuilder b = new StringBuilder();
        double[] c = new double[6];
        for (java.awt.geom.PathIterator it = sh.getPathIterator(null); !it.isDone(); it.next()) {
            switch (it.currentSegment(c)) {
                case java.awt.geom.PathIterator.SEG_MOVETO:
                    b.append('M').append(num(c[0])).append(' ').append(num(c[1])); break;
                case java.awt.geom.PathIterator.SEG_LINETO:
                    b.append('L').append(num(c[0])).append(' ').append(num(c[1])); break;
                case java.awt.geom.PathIterator.SEG_QUADTO:
                    b.append('Q').append(num(c[0])).append(' ').append(num(c[1])).append(' ')
                     .append(num(c[2])).append(' ').append(num(c[3])); break;
                case java.awt.geom.PathIterator.SEG_CUBICTO:
                    b.append('C').append(num(c[0])).append(' ').append(num(c[1])).append(' ')
                     .append(num(c[2])).append(' ').append(num(c[3])).append(' ')
                     .append(num(c[4])).append(' ').append(num(c[5])); break;
                case java.awt.geom.PathIterator.SEG_CLOSE:
                    b.append('Z'); break;
                default: break;
            }
        }
        return b.toString();
    }

    /** Trace the edge of a pixel mask into SVG path data.
     *  Every edge between an inside and an outside pixel becomes a unit step,
     *  directed so the inside is always on the right; the steps are joined
     *  into closed loops, straight runs are merged, and pixel staircases are
     *  straightened (Ramer-Douglas-Peucker, 1 px tolerance). */
    private String tracePath(boolean[] in) { return tracePath(in, W, H, 0, 0); }

    /** Trace a w x h pixel grid; coordinates are shifted by (ox, oy). */
    private static String tracePath(boolean[] in, int W, int H, int ox, int oy) {
        int W1 = W + 1, NV = W1 * (H + 1);
        // up to two outgoing steps per grid corner; direction 0=right 1=down 2=left 3=up
        byte[] o1 = new byte[NV], o2 = new byte[NV];
        Arrays.fill(o1, (byte) -1);
        Arrays.fill(o2, (byte) -1);
        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) {
                if (!in[y * W + x]) continue;
                if (y == 0     || !in[(y - 1) * W + x]) add(o1, o2, y * W1 + x, 0);             // top edge, heading right
                if (x == W - 1 || !in[y * W + x + 1])   add(o1, o2, y * W1 + x + 1, 1);         // right edge, heading down
                if (y == H - 1 || !in[(y + 1) * W + x]) add(o1, o2, (y + 1) * W1 + x + 1, 2);   // bottom edge, heading left
                if (x == 0     || !in[y * W + x - 1])   add(o1, o2, (y + 1) * W1 + x, 3);       // left edge, heading up
            }
        }
        int[] dx = {1, 0, -1, 0}, dy = {0, 1, 0, -1};
        StringBuilder b = new StringBuilder();
        for (int v0 = 0; v0 < NV; v0++) {
            while (o1[v0] >= 0) {
                // follow one loop
                java.util.ArrayList<int[]> pts = new java.util.ArrayList<>();
                int v = v0, d = take(o1, o2, v0, -1);
                int x = v0 % W1, y = v0 / W1;
                pts.add(new int[]{x, y});
                int prevDir = d;
                while (true) {
                    x += dx[d];
                    y += dy[d];
                    v = y * W1 + x;
                    if (v == v0) break;                            // back at the start: loop closed
                    int nd = take(o1, o2, v, d);
                    if (nd < 0) break;
                    if (nd != prevDir) pts.add(new int[]{x, y});   // keep corners only
                    prevDir = nd;
                    d = nd;
                }
                if (pts.size() < 4) continue;
                int[][] poly = rdp(pts.toArray(new int[0][]), 1.0);
                if (poly.length < 3 || perimeter(poly) < 24) continue;   // skip specks
                b.append('M').append(poly[0][0] + ox).append(' ').append(poly[0][1] + oy);
                for (int k = 1; k < poly.length; k++) b.append('L').append(poly[k][0] + ox).append(' ').append(poly[k][1] + oy);
                b.append('Z');
            }
        }
        return b.toString();
    }

    private static void add(byte[] o1, byte[] o2, int v, int d) {
        if (o1[v] < 0) o1[v] = (byte) d; else o2[v] = (byte) d;
    }

    /** Remove and return an outgoing step from corner v. Where two loops touch
     *  at a corner, prefer turning right, then straight, so loops stay apart. */
    private static int take(byte[] o1, byte[] o2, int v, int incoming) {
        int a = o1[v], c = o2[v];
        if (a < 0) return -1;
        int pick = a;
        if (c >= 0 && incoming >= 0) {
            int[] pref = {(incoming + 1) % 4, incoming, (incoming + 3) % 4};
            for (int q : pref) { if (q == a) { pick = a; break; } if (q == c) { pick = c; break; } }
        }
        if (pick == a) { o1[v] = (byte) c; o2[v] = -1; }
        else { o2[v] = -1; }
        return pick;
    }

    private static double perimeter(int[][] p) {
        double s = 0;
        for (int k = 0; k < p.length; k++) {
            int[] a = p[k], b = p[(k + 1) % p.length];
            s += Math.hypot(a[0] - b[0], a[1] - b[1]);
        }
        return s;
    }

    /** Ramer-Douglas-Peucker simplification of a closed polygon. */
    private static int[][] rdp(int[][] p, double eps) {
        int n = p.length;
        int far = 0;
        double best = -1;
        for (int k = 1; k < n; k++) {
            double d = Math.hypot(p[k][0] - p[0][0], p[k][1] - p[0][1]);
            if (d > best) { best = d; far = k; }
        }
        boolean[] keep = new boolean[n];
        keep[0] = true;
        keep[far] = true;
        rdpRec(p, 0, far, eps, keep);
        rdpRec(p, far, n, eps, keep);
        java.util.ArrayList<int[]> out = new java.util.ArrayList<>();
        for (int k = 0; k < n; k++) if (keep[k]) out.add(p[k]);
        return out.toArray(new int[0][]);
    }

    private static void rdpRec(int[][] p, int i, int j, double eps, boolean[] keep) {
        int n = p.length;
        if (j - i < 2) return;
        int[] a = p[i], b = p[j % n];
        double vx = b[0] - a[0], vy = b[1] - a[1], len = Math.hypot(vx, vy);
        int idx = -1;
        double dmax = -1;
        for (int k = i + 1; k < j; k++) {
            double d = (len == 0) ? Math.hypot(p[k][0] - a[0], p[k][1] - a[1])
                                  : Math.abs(vx * (a[1] - p[k][1]) - vy * (a[0] - p[k][0])) / len;
            if (d > dmax) { dmax = d; idx = k; }
        }
        if (dmax > eps) {
            keep[idx] = true;
            rdpRec(p, i, idx, eps, keep);
            rdpRec(p, idx, j, eps, keep);
        }
    }

    /** Shrink the usable area: a pixel stays usable only if every pixel within
     *  distance r (square neighbourhood) is usable. */
    private boolean[] erode(boolean[] a, int r) {
        // pass 1: horizontal, pass 2: vertical (separable for a square)
        boolean[] h = new boolean[W * H], out = new boolean[W * H];
        for (int y = 0; y < H; y++) {
            int run = 0;
            int[] left = new int[W];
            for (int x = 0; x < W; x++) { run = a[y * W + x] ? run + 1 : 0; left[x] = run; }
            run = 0;
            for (int x = W - 1; x >= 0; x--) {
                run = a[y * W + x] ? run + 1 : 0;
                h[y * W + x] = left[x] > r && run > r;
            }
        }
        for (int x = 0; x < W; x++) {
            int run = 0;
            int[] up = new int[H];
            for (int y = 0; y < H; y++) { run = h[y * W + x] ? run + 1 : 0; up[y] = run; }
            run = 0;
            for (int y = H - 1; y >= 0; y--) {
                run = h[y * W + x] ? run + 1 : 0;
                out[y * W + x] = up[y] > r && run > r;
            }
        }
        return out;
    }
}
