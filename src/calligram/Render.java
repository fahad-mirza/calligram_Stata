/*
 * Render.java - static images of a word cloud, straight from Stata (v3.3)
 *
 *   frame <results>: javacall calligram.Render run pathvar colorvar,
 *       jars(calligram.jar) args(out=... width=... height=... scale=...
 *                                 bg=#rrggbb olfile=... olcolor=#rrggbb
 *                                 olwidth=# olopacity=#)
 *
 * Reads, for every row of the current frame, a word's exact letter outlines
 * (SVG path data, as written by Cloud) and its colour, and draws the cloud:
 *   .png / .jpg  antialiased bitmap at scale x the canvas size (default 2)
 *   .svg         standalone vector image (same paths as the web page)
 * Colours: #rgb, #rrggbb or rgb(r,g,b). The image matches the page exactly,
 * because both are drawn from the same outlines.
 *
 * Return codes: 0 ok, 111 variables, 498 invalid setting, 603 cannot write.
 */
package calligram;

import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;

import java.awt.Color;
import java.awt.BasicStroke;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.AffineTransform;
import java.awt.geom.Path2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class Render {

    public static int run(String[] args) {
        try {
            return go(args);
        } catch (IllegalStateException e) {
            SFIToolkit.errorln("calligram (Java): " + e.getMessage());
            return 111;
        } catch (IllegalArgumentException e) {
            SFIToolkit.errorln("calligram: " + e.getMessage());
            return 498;
        } catch (IOException e) {
            SFIToolkit.errorln("calligram: cannot write the image: " + e.getMessage());
            return 603;
        } catch (Throwable t) {
            SFIToolkit.errorln("calligram (Java): " + t);
            return 5100;
        }
    }

    static int go(String[] args) throws Exception {
        System.setProperty("java.awt.headless", "true");
        String out = "", bg = "#ffffff", olfile = "", olcolor = "#000000", legend = "", ink = "#222222";
        int W = 0, H = 0;
        double scale = 2, olwidth = 0, olop = 1;
        for (String a : args) {
            int k = a.indexOf('=');
            if (k < 0) continue;
            String key = a.substring(0, k), v = Layout.dec(a.substring(k + 1));
            switch (key) {
                case "out":       out = v; break;
                case "width":     W = Integer.parseInt(v); break;
                case "height":    H = Integer.parseInt(v); break;
                case "scale":     scale = Double.parseDouble(v); break;
                case "bg":        bg = v; break;
                case "olfile":    olfile = v; break;
                case "olcolor":   olcolor = v; break;
                case "olwidth":   olwidth = Double.parseDouble(v); break;
                case "olopacity": olop = Double.parseDouble(v); break;
                case "legend":    legend = v; break;
                case "ink":       ink = v; break;
                default: break;
            }
        }
        if (out.isEmpty()) throw new IllegalArgumentException("no image file name given");
        if (W < 1 || H < 1) throw new IllegalArgumentException("canvas size missing");
        if (!(scale > 0) || scale > 8) throw new IllegalArgumentException("scale() must be above 0 and at most 8");
        String fmt = out.toLowerCase(Locale.ROOT);
        fmt = fmt.endsWith(".svg") ? "svg" : (fmt.endsWith(".jpg") || fmt.endsWith(".jpeg")) ? "jpg" : "png";

        // the words: path data and colour, in rank order
        if (Data.getParsedVarCount() < 2) throw new IllegalStateException("path and colour variables needed");
        int vPath = Data.mapParsedVarIndex(1), vCol = Data.mapParsedVarIndex(2);
        long n1 = Data.getObsParsedIn1(), n2 = Data.getObsParsedIn2();
        List<String> paths = new ArrayList<>(), cols = new ArrayList<>();
        for (long i = n1; i <= n2; i++) {
            if (!Data.isParsedIfTrue(i)) continue;
            String p = Data.getStr(vPath, i);
            if (p == null || p.isEmpty()) continue;
            paths.add(p);
            cols.add(Data.getStr(vCol, i));
        }
        Legend lg = legend.isEmpty() ? null : Legend.read(legend, W, H);
        // the key goes in a strip below the cloud, so it never covers a word
        final int HO = lg == null ? H : (int) Math.ceil(H + lg.h + lg.fs * 0.8);
        if (lg != null) lg.y = H;
        String outline = olfile.isEmpty() || olwidth <= 0 ? "" :
            new String(Files.readAllBytes(Paths.get(olfile)), StandardCharsets.UTF_8).trim();

        if (fmt.equals("svg")) {
            StringBuilder b = new StringBuilder();
            b.append("<svg xmlns='http://www.w3.org/2000/svg' width='").append(W).append("' height='").append(HO)
             .append("' viewBox='0 0 ").append(W).append(' ').append(HO).append("'>\n");
            b.append("<rect width='").append(W).append("' height='").append(HO).append("' fill='").append(hex(parse(bg))).append("'/>\n");
            if (!outline.isEmpty()) {
                b.append("<path d='").append(outline).append("' fill='none' stroke='").append(hex(parse(olcolor)))
                 .append("' stroke-width='").append(olwidth).append("' stroke-opacity='").append(olop)
                 .append("' stroke-linejoin='round'/>\n");
            }
            for (int i = 0; i < paths.size(); i++) {
                b.append("<path d='").append(paths.get(i)).append("' fill='").append(hex(parse(cols.get(i)))).append("'/>\n");
            }
            if (lg != null) b.append(lg.svg(parse(bg), parse(ink)));
            b.append("</svg>\n");
            // java.io.File, like the PNG/JPG writer: one way of resolving the path for every format
            Files.write(new File(out).getAbsoluteFile().toPath(), b.toString().getBytes(StandardCharsets.UTF_8));
        } else {
            int w = (int) Math.round(W * scale), h = (int) Math.round(HO * scale);
            BufferedImage img = new BufferedImage(w, h, fmt.equals("jpg") ? BufferedImage.TYPE_INT_RGB : BufferedImage.TYPE_INT_ARGB);
            Graphics2D g = img.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
            g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
            g.setColor(parse(bg));
            g.fillRect(0, 0, w, h);
            g.transform(AffineTransform.getScaleInstance(scale, scale));
            if (!outline.isEmpty()) {
                Color c = parse(olcolor);
                g.setColor(new Color(c.getRed(), c.getGreen(), c.getBlue(), (int) Math.round(255 * Math.max(0, Math.min(1, olop)))));
                g.setStroke(new BasicStroke((float) olwidth, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
                g.draw(path(outline));
            }
            for (int i = 0; i < paths.size(); i++) {
                g.setColor(parse(cols.get(i)));
                g.fill(path(paths.get(i)));
            }
            if (lg != null) lg.draw(g, parse(bg), parse(ink));
            g.dispose();
            File f = new File(out).getAbsoluteFile();
            boolean ok = javax.imageio.ImageIO.write(img, fmt.equals("jpg") ? "jpg" : "png", f);
            if (!ok) throw new IOException("no image writer for " + fmt);
        }
        return 0;
    }

    /** The colour key in the bottom-left corner: a title, then either a
     *  gradient bar with its low and high values or one swatch per category.
     *  File lines (tab separated): title|text, grad|c1|c2|low|high, cat|colour|name. */
    static final class Legend {
        String title = "", c1, c2, lo, hi;
        final List<String[]> cats = new ArrayList<>();
        int W, H;
        double x, y, w, h, fs, pad, row;
        java.awt.Font font;
        final java.awt.font.FontRenderContext frc = new java.awt.font.FontRenderContext(null, true, true);

        static Legend read(String file, int W, int H) throws IOException {
            Legend L = new Legend();
            L.W = W; L.H = H;
            for (String line : Files.readAllLines(Paths.get(file), StandardCharsets.UTF_8)) {
                String[] t = line.split("\t", -1);
                if (t[0].equals("title") && t.length > 1) L.title = t[1];
                else if (t[0].equals("grad") && t.length > 4) { L.c1 = t[1]; L.c2 = t[2]; L.lo = t[3]; L.hi = t[4]; }
                else if (t[0].equals("cat") && t.length > 2) L.cats.add(new String[]{t[1], t[2]});
            }
            if (L.c1 == null && L.cats.isEmpty()) return null;
            L.fs = Math.max(11, Math.min(W, H) / 48.0);
            L.font = Fonts.resolve("Arimo").base.deriveFont(java.awt.Font.BOLD, (float) L.fs);
            L.pad = L.fs * 0.8;
            L.row = L.fs * 1.5;
            double tw = L.textW(L.title);
            if (L.c1 != null) tw = Math.max(tw, L.textW(L.lo) + L.fs * 10 + L.textW(L.hi) + L.fs);
            for (String[] c : L.cats) tw = Math.max(tw, L.fs * 1.4 + L.textW(c[1]));
            L.w = tw + 2 * L.pad;
            L.h = 2 * L.pad + L.row * (1 + (L.c1 != null ? 1 : L.cats.size()));
            L.x = L.fs;
            L.y = H - L.h - L.fs;
            return L;
        }
        double textW(String s) { return font.getStringBounds(s, frc).getWidth(); }
        /** baseline of row k (0 = title) */
        double base(int k) { return y + pad + row * k + fs; }

        void draw(Graphics2D g, Color bg, Color ink) {
            g.setColor(new Color(bg.getRed(), bg.getGreen(), bg.getBlue(), 215));
            g.fill(new java.awt.geom.RoundRectangle2D.Double(x, y, w, h, fs, fs));
            g.setFont(font);
            g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
            g.setColor(ink);
            g.drawString(title, (float) (x + pad), (float) base(0));
            if (c1 != null) {
                double bx = x + pad + textW(lo) + fs * 0.5, bw = fs * 9, by = base(1) - fs * 0.75;
                g.drawString(lo, (float) (x + pad), (float) base(1));
                for (int k = 0; k < 64; k++) {
                    g.setColor(gradAt(k / 63.0));
                    g.fill(new java.awt.geom.Rectangle2D.Double(bx + bw * k / 64.0, by, bw / 64.0 + 0.6, fs * 0.7));
                }
                g.setColor(ink);
                g.drawString(hi, (float) (bx + bw + fs * 0.5), (float) base(1));
            }
            for (int k = 0; k < cats.size(); k++) {
                g.setColor(parse(cats.get(k)[0]));
                g.fill(new java.awt.geom.RoundRectangle2D.Double(x + pad, base(k + 1) - fs * 0.8, fs * 0.85, fs * 0.85, fs * 0.25, fs * 0.25));
                g.setColor(ink);
                g.drawString(cats.get(k)[1], (float) (x + pad + fs * 1.4), (float) base(k + 1));
            }
        }

        String svg(Color bg, Color ink) {
            StringBuilder b = new StringBuilder();
            String f = String.format(Locale.ROOT, "font-family='Arimo, Arial, Helvetica, sans-serif' font-weight='bold' font-size='%.1f'", fs);
            b.append(String.format(Locale.ROOT, "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' rx='%.1f' fill='%s' fill-opacity='0.84'/>%n", x, y, w, h, fs / 2, hex(bg)));
            b.append(String.format(Locale.ROOT, "<text x='%.1f' y='%.1f' %s fill='%s'>%s</text>%n", x + pad, base(0), f, hex(ink), esc(title)));
            if (c1 != null) {
                double bx = x + pad + textW(lo) + fs * 0.5, bw = fs * 9, by = base(1) - fs * 0.75;
                b.append("<defs><linearGradient id='cg-legend'>");
                for (int k = 0; k <= 8; k++) b.append(String.format(Locale.ROOT, "<stop offset='%.3f' stop-color='%s'/>", k / 8.0, hex(gradAt(k / 8.0))));
                b.append("</linearGradient></defs>\n");
                b.append(String.format(Locale.ROOT, "<text x='%.1f' y='%.1f' %s fill='%s'>%s</text>%n", x + pad, base(1), f, hex(ink), esc(lo)));
                b.append(String.format(Locale.ROOT, "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' fill='url(#cg-legend)'/>%n", bx, by, bw, fs * 0.7));
                b.append(String.format(Locale.ROOT, "<text x='%.1f' y='%.1f' %s fill='%s'>%s</text>%n", bx + bw + fs * 0.5, base(1), f, hex(ink), esc(hi)));
            }
            for (int k = 0; k < cats.size(); k++) {
                b.append(String.format(Locale.ROOT, "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' rx='%.1f' fill='%s'/>%n",
                    x + pad, base(k + 1) - fs * 0.8, fs * 0.85, fs * 0.85, fs * 0.25, hex(parse(cats.get(k)[0]))));
                b.append(String.format(Locale.ROOT, "<text x='%.1f' y='%.1f' %s fill='%s'>%s</text>%n", x + pad + fs * 1.4, base(k + 1), f, hex(ink), esc(cats.get(k)[1])));
            }
            return b.toString();
        }

        /** the gradient between c1 and c2 at t, in HSL (as the words are coloured) */
        Color gradAt(double t) {
            Color A = parse(c1), B = parse(c2);
            double[] h1 = hsl(A), h2 = hsl(B);
            if (h1[1] == 0) h1[0] = h2[0];
            if (h2[1] == 0) h2[0] = h1[0];
            double dh = h2[0] - h1[0];
            if (dh > 180) dh -= 360;
            if (dh < -180) dh += 360;
            return fromHsl(((h1[0] + t * dh) % 360 + 360) % 360, h1[1] + t * (h2[1] - h1[1]), h1[2] + t * (h2[2] - h1[2]));
        }
        static double[] hsl(Color c) {
            double r = c.getRed() / 255.0, g = c.getGreen() / 255.0, b = c.getBlue() / 255.0;
            double mx = Math.max(r, Math.max(g, b)), mn = Math.min(r, Math.min(g, b)), l = (mx + mn) / 2, h = 0, s = 0;
            if (mx != mn) {
                double d = mx - mn;
                s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
                if (mx == r) h = ((g - b) / d + (g < b ? 6 : 0)) * 60;
                else if (mx == g) h = ((b - r) / d + 2) * 60;
                else h = ((r - g) / d + 4) * 60;
            }
            return new double[]{h, s, l};
        }
        static Color fromHsl(double h, double s, double l) {
            double c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2, r, g, b;
            if (h < 60) { r = c; g = x; b = 0; } else if (h < 120) { r = x; g = c; b = 0; } else if (h < 180) { r = 0; g = c; b = x; }
            else if (h < 240) { r = 0; g = x; b = c; } else if (h < 300) { r = x; g = 0; b = c; } else { r = c; g = 0; b = x; }
            return new Color((int) Math.round((r + m) * 255), (int) Math.round((g + m) * 255), (int) Math.round((b + m) * 255));
        }
        static String esc(String s) { return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&#39;"); }
    }

    /** #rgb, #rrggbb or rgb(r,g,b); anything else is mid grey */
    static Color parse(String s) {
        if (s == null) return Color.GRAY;
        s = s.trim().toLowerCase(Locale.ROOT);
        try {
            if (s.startsWith("#")) {
                String h = s.substring(1);
                if (h.length() == 3) h = "" + h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2);
                if (h.length() == 6) return new Color(Integer.parseInt(h, 16));
            } else if (s.startsWith("rgb(") && s.endsWith(")")) {
                String[] p = s.substring(4, s.length() - 1).split(",");
                if (p.length == 3) return new Color(Integer.parseInt(p[0].trim()), Integer.parseInt(p[1].trim()), Integer.parseInt(p[2].trim()));
            }
        } catch (RuntimeException e) { /* fall through */ }
        return Color.GRAY;
    }

    static String hex(Color c) { return String.format(Locale.ROOT, "#%02x%02x%02x", c.getRed(), c.getGreen(), c.getBlue()); }

    /** SVG path data (absolute or relative M L Q C Z) to a Java shape */
    static Path2D path(String d) {
        Path2D.Double p = new Path2D.Double(Path2D.WIND_NON_ZERO);
        int n = d.length(), i = 0;
        double cx = 0, cy = 0, sx = 0, sy = 0;
        char cmd = 0;
        double[] v = new double[6];
        while (i < n) {
            char c = d.charAt(i);
            if (Character.isLetter(c)) { cmd = c; i++; if (c == 'z' || c == 'Z') { p.closePath(); cx = sx; cy = sy; } continue; }
            if (c == ' ' || c == ',' || c == '\n') { i++; continue; }
            int need;
            switch (Character.toLowerCase(cmd)) { case 'm': case 'l': need = 2; break; case 'q': need = 4; break; case 'c': need = 6; break; default: i++; continue; }
            for (int k = 0; k < need; k++) {
                while (i < n && (d.charAt(i) == ' ' || d.charAt(i) == ',')) i++;
                int st = i;
                if (i < n && (d.charAt(i) == '-' || d.charAt(i) == '+')) i++;
                boolean dot = false;
                while (i < n) {
                    char ch = d.charAt(i);
                    if (Character.isDigit(ch)) i++;
                    else if (ch == '.' && !dot) { dot = true; i++; }
                    else break;
                }
                v[k] = Double.parseDouble(d.substring(st, i));
            }
            boolean rel = Character.isLowerCase(cmd);
            double ox = rel ? cx : 0, oy = rel ? cy : 0;
            switch (Character.toLowerCase(cmd)) {
                case 'm': cx = ox + v[0]; cy = oy + v[1]; p.moveTo(cx, cy); sx = cx; sy = cy; cmd = rel ? 'l' : 'L'; break;
                case 'l': cx = ox + v[0]; cy = oy + v[1]; p.lineTo(cx, cy); break;
                case 'q': p.quadTo(ox + v[0], oy + v[1], ox + v[2], oy + v[3]); cx = ox + v[2]; cy = oy + v[3]; break;
                case 'c': p.curveTo(ox + v[0], oy + v[1], ox + v[2], oy + v[3], ox + v[4], oy + v[5]); cx = ox + v[4]; cy = oy + v[5]; break;
                default: break;
            }
        }
        return p;
    }
}
