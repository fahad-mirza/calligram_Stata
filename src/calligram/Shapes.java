/*
 * Shapes.java - areas from a Stata-format shapefile, for calligram (v3.5)
 *
 * Input: a text file written by calligram.ado from a *_shp.dta file (as made
 * by Stata's spshape2dta): one line per point, "_ID,_X,_Y". A line with an
 * empty or missing coordinate starts a new part (ring) of the area; a ring
 * that returns to its first point also ends there. Rings are filled with the
 * even-odd rule, so holes (lakes, enclaves) stay empty.
 *
 * Projection: "auto" uses Equal Earth when every coordinate looks like
 * longitude/latitude (|x| <= 180, |y| <= 90), otherwise the coordinates are
 * drawn as they are; "equalearth" and "none" force one or the other. North
 * is up. The map is scaled to fit the canvas, keeping its proportions.
 *
 * Gives: a label for every canvas pixel (0 = no area; 1..N = area), the exact
 * borders as SVG path data, the label of an area _ID, and the canvas position
 * (and area) of a longitude/latitude point.
 */
package calligram;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.Path2D;
import java.awt.image.BufferedImage;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class Shapes {

    /** _ID -> rings (each ring: x0, y0, x1, y1, ... in the file's coordinates) */
    private final LinkedHashMap<Double, List<double[]>> areas = new LinkedHashMap<>();
    private final Map<Double, Integer> labelOf = new HashMap<>();
    private final List<Double> idOfLabel = new ArrayList<>();
    private boolean lonlat;
    private double sx, ox, oy;                      // canvas = (proj - min) * sx + offset
    private double px0, py1;                        // projected min x, max y
    public final int W, H;
    public final int[] label;                       // per canvas pixel, 0 = none
    public final String borders;                    // SVG path data of every area's border

    public Shapes(String file, String projection, int W, int H) throws Exception {
        this.W = W;
        this.H = H;
        read(file);
        if (areas.isEmpty()) throw new IllegalArgumentException("the shapefile has no areas (no _ID with coordinates)");
        boolean ll = true;
        for (List<double[]> rings : areas.values())
            for (double[] r : rings)
                for (int k = 0; k < r.length; k += 2) if (Math.abs(r[k]) > 180.0001 || Math.abs(r[k + 1]) > 90.0001) ll = false;
        String pr = projection == null ? "auto" : projection.toLowerCase(Locale.ROOT);
        if (pr.equals("auto")) lonlat = ll;
        else if (pr.equals("equalearth")) {
            if (!ll) throw new IllegalArgumentException("projection(equalearth) needs longitude/latitude coordinates");
            lonlat = true;
        } else if (pr.equals("none")) lonlat = false;
        else throw new IllegalArgumentException("projection() must be auto, equalearth or none");
        fit();
        int k = 0;
        for (Double id : areas.keySet()) { labelOf.put(id, ++k); idOfLabel.add(id); }
        this.label = rasterise();
        this.borders = borderPaths();
    }

    private void read(String file) throws Exception {
        List<String> lines = Files.readAllLines(Paths.get(file), StandardCharsets.UTF_8);
        Map<Double, List<Double>> cur = new HashMap<>();   // open ring per _ID
        for (String line : lines) {
            String[] t = line.split(",", -1);
            if (t.length < 3) continue;
            double id;
            try { id = Double.parseDouble(t[0].trim()); } catch (NumberFormatException e) { continue; }   // header or blank
            double x = num(t[1]), y = num(t[2]);
            List<double[]> rings = areas.computeIfAbsent(id, z -> new ArrayList<>());
            List<Double> ring = cur.get(id);
            if (Double.isNaN(x) || Double.isNaN(y)) {                 // a new part begins
                close(rings, ring);
                cur.put(id, new ArrayList<>());
                continue;
            }
            if (ring == null) { ring = new ArrayList<>(); cur.put(id, ring); }
            ring.add(x); ring.add(y);
            // a ring that returns to its first point ends there
            if (ring.size() >= 8 && x == ring.get(0) && y == ring.get(1)) {
                close(rings, ring);
                cur.put(id, new ArrayList<>());
            }
        }
        for (Map.Entry<Double, List<Double>> e : cur.entrySet()) close(areas.get(e.getKey()), e.getValue());
        areas.values().removeIf(List::isEmpty);
    }

    private static double num(String s) {
        s = s.trim();
        if (s.isEmpty() || s.equals(".")) return Double.NaN;
        try { return Double.parseDouble(s); } catch (NumberFormatException e) { return Double.NaN; }
    }

    private static void close(List<double[]> rings, List<Double> ring) {
        if (rings == null || ring == null || ring.size() < 6) return;   // fewer than 3 points
        double[] r = new double[ring.size()];
        for (int i = 0; i < r.length; i++) r[i] = ring.get(i);
        rings.add(r);
    }

    // ── projection ───────────────────────────────────────────────────────────

    private static double[] equalEarth(double lon, double lat) {
        final double A1 = 1.340264, A2 = -0.081106, A3 = 0.000893, A4 = 0.003796, M = Math.sqrt(3) / 2;
        double th = Math.asin(M * Math.sin(Math.toRadians(lat))), t2 = th * th, t6 = t2 * t2 * t2;
        double x = Math.toRadians(lon) * Math.cos(th) / (M * (A1 + 3 * A2 * t2 + t6 * (7 * A3 + 9 * A4 * t2)));
        double y = th * (A1 + A2 * t2 + t6 * (A3 + A4 * t2));
        return new double[]{x, y};
    }

    private double[] project(double x, double y) { return lonlat ? equalEarth(x, y) : new double[]{x, y}; }

    private void fit() {
        double x0 = Double.MAX_VALUE, x1 = -Double.MAX_VALUE, y0 = Double.MAX_VALUE, y1 = -Double.MAX_VALUE;
        for (List<double[]> rings : areas.values())
            for (double[] r : rings)
                for (int k = 0; k < r.length; k += 2) {
                    double[] q = project(r[k], r[k + 1]);
                    x0 = Math.min(x0, q[0]); x1 = Math.max(x1, q[0]); y0 = Math.min(y0, q[1]); y1 = Math.max(y1, q[1]);
                }
        double pad = 0.01;
        double w = Math.max(x1 - x0, 1e-12), h = Math.max(y1 - y0, 1e-12);
        sx = Math.min(W * (1 - 2 * pad) / w, H * (1 - 2 * pad) / h);
        ox = (W - w * sx) / 2;
        oy = (H - h * sx) / 2;
        px0 = x0;
        py1 = y1;
    }

    /** canvas position of a point given in the file's coordinates (lon/lat if projected) */
    public double[] canvas(double x, double y) {
        double[] q = project(x, y);
        return new double[]{(q[0] - px0) * sx + ox, (py1 - q[1]) * sx + oy};
    }

    // ── areas on the canvas ──────────────────────────────────────────────────

    private Path2D path(List<double[]> rings) {
        Path2D.Double p = new Path2D.Double(Path2D.WIND_EVEN_ODD);
        for (double[] r : rings) {
            for (int k = 0; k < r.length; k += 2) {
                double[] c = canvas(r[k], r[k + 1]);
                if (k == 0) p.moveTo(c[0], c[1]); else p.lineTo(c[0], c[1]);
            }
            p.closePath();
        }
        return p;
    }

    private int[] rasterise() {
        BufferedImage img = new BufferedImage(W, H, BufferedImage.TYPE_INT_RGB);   // black = no area
        Graphics2D g = img.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_OFF);   // exact labels
        for (Map.Entry<Double, List<double[]>> e : areas.entrySet()) {
            g.setColor(new Color(labelOf.get(e.getKey())));
            g.fill(path(e.getValue()));
        }
        g.dispose();
        int[] out = new int[W * H];
        img.getRGB(0, 0, W, H, out, 0, W);
        for (int i = 0; i < out.length; i++) out[i] &= 0xffffff;
        return out;
    }

    /** The drawn borders. Points closer than 0.6 pixels to the previous one cannot
     *  be seen and are left out, as are parts smaller than about a pixel, so the
     *  page stays light (a world map has some 96,000 points). Word placement uses
     *  the full-detail areas, not this drawing. */
    private String borderPaths() {
        final double MIN = 0.6;
        StringBuilder b = new StringBuilder();
        for (List<double[]> rings : areas.values()) {
            for (double[] r : rings) {
                List<double[]> kept = new ArrayList<>();
                double x0 = Double.MAX_VALUE, y0 = Double.MAX_VALUE, x1 = -Double.MAX_VALUE, y1 = -Double.MAX_VALUE;
                for (int k = 0; k < r.length; k += 2) {
                    double[] c = canvas(r[k], r[k + 1]);
                    x0 = Math.min(x0, c[0]); y0 = Math.min(y0, c[1]); x1 = Math.max(x1, c[0]); y1 = Math.max(y1, c[1]);
                    if (kept.isEmpty()) { kept.add(c); continue; }
                    double[] q = kept.get(kept.size() - 1);
                    if (Math.hypot(c[0] - q[0], c[1] - q[1]) >= MIN || k == r.length - 2) kept.add(c);
                }
                if (kept.size() < 3 || (x1 - x0 < 1 && y1 - y0 < 1)) continue;
                for (int k = 0; k < kept.size(); k++) {
                    double[] c = kept.get(k);
                    b.append(k == 0 ? 'M' : 'L').append(String.format(Locale.ROOT, "%.1f %.1f", c[0], c[1]));
                }
                b.append('Z');
            }
        }
        return b.toString();
    }

    /** label (1..N) of an area _ID, or 0 if the file has no such area */
    public int labelOfId(double id) { Integer l = labelOf.get(id); return l == null ? 0 : l; }

    /** _ID of a label */
    public double idOfLabel(int l) { return l >= 1 && l <= idOfLabel.size() ? idOfLabel.get(l - 1) : Double.NaN; }

    /** label of the area containing canvas point (x, y), looking up to r pixels
     *  around it (points on a coast can fall just outside a simplified border) */
    // ── exact point-in-area test on the border lines (not the pixels) ─────────
    private double[][] vRings;      // each ring's points on the canvas: x0,y0,x1,y1,...
    private int[] vLabel;           // the area label of each ring
    private double[][] vBox;        // each ring's bounding box: minx, miny, maxx, maxy
    private synchronized void buildVector() {
        if (vRings != null) return;
        List<double[]> rs = new ArrayList<>(); List<Integer> ls = new ArrayList<>(); List<double[]> bs = new ArrayList<>();
        for (Map.Entry<Double, List<double[]>> e : areas.entrySet()) {
            int lab = labelOf.get(e.getKey());
            for (double[] r : e.getValue()) {
                double[] c = new double[r.length];
                double x0 = Double.MAX_VALUE, y0 = Double.MAX_VALUE, x1 = -Double.MAX_VALUE, y1 = -Double.MAX_VALUE;
                for (int k = 0; k < r.length; k += 2) {
                    double[] q = canvas(r[k], r[k + 1]);
                    c[k] = q[0]; c[k + 1] = q[1];
                    x0 = Math.min(x0, q[0]); y0 = Math.min(y0, q[1]); x1 = Math.max(x1, q[0]); y1 = Math.max(y1, q[1]);
                }
                rs.add(c); ls.add(lab); bs.add(new double[]{x0, y0, x1, y1});
            }
        }
        vRings = rs.toArray(new double[0][]); vBox = bs.toArray(new double[0][]);
        vLabel = new int[ls.size()];
        for (int i = 0; i < vLabel.length; i++) vLabel[i] = ls.get(i);
    }
    private static boolean inRing(double[] c, double x, double y) {
        boolean in = false;
        int n = c.length / 2;
        for (int i = 0, j = n - 1; i < n; j = i++) {
            double xi = c[2 * i], yi = c[2 * i + 1], xj = c[2 * j], yj = c[2 * j + 1];
            if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) in = !in;
        }
        return in;
    }
    /** The area whose borders contain the point (even-odd over all of an area's
     *  rings, so holes and islands count right), or 0. */
    public int vectorLabelAt(double x, double y) {
        buildVector();
        Map<Integer, Boolean> parity = new HashMap<>();
        for (int i = 0; i < vRings.length; i++) {
            double[] b = vBox[i];
            if (x < b[0] || x > b[2] || y < b[1] || y > b[3]) continue;
            if (inRing(vRings[i], x, y)) parity.merge(vLabel[i], true, (p, q) -> !p);
        }
        for (Map.Entry<Integer, Boolean> e : parity.entrySet()) if (e.getValue()) return e.getKey();
        return 0;
    }
    /** The area containing a point: by its exact borders first; for a point just
     *  outside every area (a coastal city on a simplified coastline), the nearest
     *  area on the pixel map within r pixels. */
    public int labelAt(double x, double y, int r) {
        int v = vectorLabelAt(x, y);
        if (v > 0) return v;
        return rasterLabelAt(x, y, r);
    }
    /** The pixel-map lookup alone (the area drawn at the point's pixel, else the nearest within r). */
    public int rasterLabelAt(double x, double y, int r) {
        int cx = (int) Math.round(x), cy = (int) Math.round(y);
        if (cx >= 0 && cy >= 0 && cx < W && cy < H && label[cy * W + cx] > 0) return label[cy * W + cx];
        int best = 0;
        double bd = Double.MAX_VALUE;
        for (int dy = -r; dy <= r; dy++) {
            for (int dx = -r; dx <= r; dx++) {
                int xx = cx + dx, yy = cy + dy;
                if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
                int l = label[yy * W + xx];
                double d = dx * dx + dy * dy;
                if (l > 0 && d < bd && d <= r * r) { bd = d; best = l; }
            }
        }
        return best;
    }

    public boolean projected() { return lonlat; }
}
