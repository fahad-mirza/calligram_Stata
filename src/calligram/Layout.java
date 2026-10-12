/*
 * Layout.java - Stata entry point for the calligram layout engine (v2.0)
 *
 * Called from calligram.ado as:
 *   javacall calligram.Layout run, jars(calligram.jar) args(name=value ...)
 *   javacall calligram.Layout ui,  jars(calligram.jar) args(jsfile=... cssfile=...)
 *
 * Settings (values are percent-encoded: "%20" = space, "%25" = %):
 *   width height margin maxfont minfont scaling seed font rotate shape mask
 *   outline (stroke width, 0 = none) outfile (where to write the outline path)
 *
 * Reads:   word (string), freq (numeric), sorted most frequent first
 * Writes:  fontsize, rotation, tx, ty (text origin), placed (1/0)
 *
 * Return codes: 0 ok, 111 variables missing, 498 invalid setting,
 *               601 mask file not found, 610 mask file unreadable,
 *               5100 anything unexpected (calligram then falls back to Mata).
 */
package calligram;

import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;

import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

public class Layout {

    public static int run(String[] args) {
        try {
            return go(args);
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
        }
    }

    /** Second entry point: write the bundled interface files (ui.js, ui.css)
     *  to the paths Stata gives, so they can be inlined into the HTML page.
     *  javacall calligram.Layout ui, jars(calligram.jar) args(jsfile=... cssfile=...) */
    public static int ui(String[] args) {
        try {
            for (String a : args) {
                int k = a.indexOf('=');
                if (k < 0) continue;
                String key = a.substring(0, k), v = dec(a.substring(k + 1));
                if (key.equals("jsfile") && !v.isEmpty()) copy("ui.js", v);
                if (key.equals("cssfile") && !v.isEmpty()) copy("ui.css", v);
            }
            return 0;
        } catch (Throwable t) {
            SFIToolkit.errorln("calligram (Java): " + t);
            return 5100;
        }
    }

    private static void copy(String resource, String dest) throws IOException {
        try (java.io.InputStream in = Layout.class.getResourceAsStream(resource)) {
            if (in == null) throw new IOException("interface file missing from calligram.jar: " + resource);
            java.nio.file.Files.copy(in, java.nio.file.Paths.get(dest), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        }
    }

    /** Decode %XX sequences (UTF-8). */
    static String dec(String s) {
        if (s.indexOf('%') < 0) return s;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] b = s.getBytes(StandardCharsets.UTF_8);
        for (int i = 0; i < b.length; i++) {
            if (b[i] == '%' && i + 2 < b.length) {
                int v = Integer.parseInt(new String(b, i + 1, 2, StandardCharsets.US_ASCII), 16);
                out.write(v);
                i += 2;
            } else {
                out.write(b[i]);
            }
        }
        return new String(out.toByteArray(), StandardCharsets.UTF_8);
    }

    private static int var(String name) {
        int v = Data.getVarIndex(name);   // 0 if the variable does not exist
        if (v == 0) throw new IllegalStateException("variable " + name + " not found");
        return v;
    }

    static int go(String[] args) throws Exception {
        System.setProperty("java.awt.headless", "true");

        Engine.Params p = new Engine.Params();
        String outfile = "";
        for (String a : args) {
            int k = a.indexOf('=');
            if (k < 0) continue;
            String key = a.substring(0, k), v = dec(a.substring(k + 1));
            switch (key) {
                case "width":   p.width   = Integer.parseInt(v); break;
                case "height":  p.height  = Integer.parseInt(v); break;
                case "margin":  p.margin  = Integer.parseInt(v); break;
                case "maxfont": p.maxFont = Integer.parseInt(v); break;
                case "minfont": p.minFont = Integer.parseInt(v); break;
                case "scaling": p.scaling = Double.parseDouble(v); break;
                case "seed":    p.seed    = Long.parseLong(v); break;
                case "font":    p.font    = v; break;
                case "rotate":  p.rotate  = v; break;
                case "shape":   p.shape   = v.toLowerCase(); break;
                case "mask":    p.mask    = v; break;
                case "outline": p.outline = Double.parseDouble(v); break;
                case "outfile": outfile   = v; break;
                default: break;
            }
        }
        if (p.mask.isEmpty() && !Arrays.asList(Engine.SHAPES).contains(p.shape)) {
            throw new IllegalArgumentException("unknown shape: " + p.shape);
        }

        int vWord = var("word"), vFreq = var("freq"), vSize = var("fontsize"),
            vRot = var("rotation"), vTx = var("tx"), vTy = var("ty"), vPl = var("placed");

        int n = (int) Data.getObsTotal();
        String[] words = new String[n];
        double[] freq = new double[n];
        for (int i = 0; i < n; i++) {
            String w = Data.getStr(vWord, i + 1);
            words[i] = (w == null) ? "" : w;
            freq[i] = Data.getNum(vFreq, i + 1);
        }

        Engine e = new Engine(p);
        if (!e.warning.isEmpty()) SFIToolkit.displayln("{txt}calligram: " + e.warning);
        Engine.Result r = e.layout(words, freq);

        for (int i = 0; i < n; i++) {
            long obs = i + 1;
            Data.storeNum(vPl, obs, r.placed[i] ? 1 : 0);
            if (!r.placed[i]) continue;
            Data.storeNum(vSize, obs, r.size[i]);
            Data.storeNum(vRot, obs, r.rot[i]);
            Data.storeNum(vTx, obs, r.tx[i]);
            Data.storeNum(vTy, obs, r.ty[i]);
        }
        // Outline path data goes to a file named by Stata (it can be long)
        if (p.outline > 0 && !outfile.isEmpty()) {
            java.nio.file.Files.write(java.nio.file.Paths.get(outfile),
                e.outlineSvg.getBytes(StandardCharsets.UTF_8));
        }
        return 0;
    }
}
