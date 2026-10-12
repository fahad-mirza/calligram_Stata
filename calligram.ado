*! calligram v1.0.8  12oct2026  (formerly wordcloud2 3.5)
*! Word clouds in any shape, from survey text to maps (HTML, PNG, JPG, SVG)
*! Author: Fahad Mirza | Editor: Claude (Anthropic)
*!
*! Requires Stata 17+. Layout and the in-page toolbar come from the bundled
*! calligram.jar, which runs on Stata's own Java (nothing else to install):
*! pixel-level packing, automatic sizing, shapes, image masks, outlines,
*! search, frequency filter, zoom, themes, palettes and by() group tabs.
*! If the JAR is unavailable, a simpler Mata layout is used instead.

program define calligram, rclass
    version 17.0

    syntax [if] [in] [aweight fweight pweight iweight] [, ///
        TEXTvar(varname string)         ///
        WORDvar(varname string)         ///
        COUNTvar(varname numeric)       ///
        BY(varname)                     ///
        MAXWords(integer 100)           ///
        MINFReq(integer 2)              ///
        MINLength(integer 3)            ///
        STOPWords(string)               ///
        NOSTOPwords                     ///
        NOCLean                         ///
        TItle(string)                   ///
        Width(integer 1600)             ///
        Height(integer 800)             ///
        MARgin(integer 4)               ///
        MAXFontsize(integer 0)          ///
        MINFOntsize(integer 8)          ///
        SCAling(real 0.5)               ///
        SHApe(string)                   ///
        MASK(string)                    ///
        SEED(integer 42)                ///
        OUTLine                         ///
        OUTLINEColor(string)            ///
        OUTLINEWidth(real -1)           ///
        FIXed                           ///
        NOTOOLbar                       ///
        THReads(integer 0)              ///
        ONLine                          ///
        SPACing(real 0)                 ///
        FONt(string)                    ///
        ROTate(string)                  ///
        SAVEFile(string)                ///
        EXPort(string)                  ///
        BGColor(string)                 ///
        PALette(string)                 ///
        GRADient(string)                ///
        PHRASES                         ///
        PHRASESTrength(real 0.4)        ///
        ADDPHrases(string asis)         ///
        DROPPHrases(string asis)        ///
        SPLITHyphens                    ///
        NOPLurals                       ///
        LANGuage(string)                ///
        SAVing(string)                  ///
        IMage(string)                   ///
        REGions(varname)                ///
        SHAPEs(string)                  ///
        LOCation(varlist numeric min=2 max=2) ///
        NEAR                            ///
        PROJection(string)              ///
        COLORBy(string)                 ///
        COLORVar(varname string)        ///
        COLORImage(string)              ///
        SCRIPTFonts(string asis)        ///
        ]

    // =========================================================================
    // OPTION CHECKS (all before preserve, so errors leave data untouched)
    // =========================================================================
    // Input: text to split into words, or words already counted
    if "`textvar'" == "" & "`wordvar'" == "" {
        di as error "calligram: give textvar() (text to split into words) or wordvar() (words already counted)"
        exit 198
    }
    if "`textvar'" != "" & "`wordvar'" != "" {
        di as error "calligram: give textvar() or wordvar(), not both"
        exit 198
    }
    if "`countvar'" != "" & "`wordvar'" == "" {
        di as error "calligram: countvar() goes with wordvar() (words already counted)"
        exit 198
    }
    local _pre = ("`wordvar'" != "")
    // Areas: a Stata-format shapefile (shapes()) or a colour-coded mask image
    local _shp ""
    if `"`shapes'"' != "" {
        local _shp = strtrim(`"`shapes'"')
        if !ustrregexm(`"`_shp'"', "\.dta$") local _shp `"`_shp'.dta"'
        confirm file `"`_shp'"'
        if !inlist(lower(strtrim(`"`shape'"')), "", "rectangle") {
            di as error "calligram: give shapes() or shape(), not both (the shapefile's areas are the shape)"
            exit 198
        }
        if `"`mask'"' != "" {
            di as error "calligram: give shapes() or mask(), not both"
            exit 198
        }
    }
    local _proj = lower(strtrim(`"`projection'"'))
    if "`_proj'" == "" local _proj "auto"
    if !inlist("`_proj'", "auto", "equalearth", "none") {
        di as error "calligram: projection() must be auto, equalearth or none"
        exit 198
    }
    if "`regions'" != "" & "`location'" != "" {
        di as error "calligram: give regions() or location(), not both"
        exit 198
    }
    if "`regions'" != "" | "`location'" != "" {
        if !`_pre' {
            di as error "calligram: regions() and location() need wordvar() (one word per row)"
            exit 198
        }
    }
    if "`regions'" != "" {
        if `"`_shp'"' != "" {
            capture confirm numeric variable `regions'
            if _rc {
                di as error "calligram: with shapes(), regions() is the numeric area ID (_ID) of each word"
                exit 198
            }
        }
        else if `"`mask'"' != "" {
            capture confirm string variable `regions'
            if _rc {
                di as error "calligram: with mask(), regions() is a string variable with each word's area colour (#rrggbb)"
                exit 198
            }
        }
        else {
            di as error "calligram: regions() needs shapes() (a Stata-format shapefile) or mask() (a colour-coded image)"
            exit 198
        }
    }
    if "`location'" != "" & `"`_shp'"' == "" {
        di as error "calligram: location() needs shapes() (a Stata-format shapefile)"
        exit 198
    }
    if "`near'" != "" & "`location'" == "" {
        di as error "calligram: near needs location()"
        exit 198
    }
    if `_pre' {
        if "`weight'" != "" {
            di as error "calligram: with wordvar(), give the counts in countvar() instead of weights"
            exit 198
        }
        if "`phrases'" != "" | `"`addphrases'"' != "" {
            di as error "calligram: phrases and addphrases() need textvar(); with wordvar() the entries are used as given"
            exit 198
        }
        local textvar `wordvar'
    }
    if `phrasestrength' < 0 | `phrasestrength' > 1 {
        di as error "calligram: phrasestrength() must be between 0 and 1 (default 0.4)"
        exit 198
    }
    local _langs = lower(strtrim(`"`language'"'))
    if "`_langs'" == "" local _langs "en"
    if "`_langs'" == "all" local _langs "en fr es pt"
    foreach _l of local _langs {
        if !inlist("`_l'", "en", "fr", "es", "pt") {
            di as error `"calligram: language(`language'): use en (English), fr (French), es (Spanish), pt (Portuguese), or all"'
            exit 198
        }
    }
    local _elision = strpos(" `_langs' ", " fr ") > 0
    local _savfile ""
    local _savrep 0
    if `"`saving'"' != "" {
        gettoken _savfile _savopt : saving, parse(",")
        local _savfile = strtrim(`"`_savfile'"')
        local _savopt = strtrim(subinstr(`"`_savopt'"', ",", "", 1))
        if !inlist(`"`_savopt'"', "", "replace") {
            di as error `"calligram: saving(`saving'): the only sub-option is replace"'
            exit 198
        }
        local _savrep = (`"`_savopt'"' == "replace")
        if !ustrregexm(`"`_savfile'"', "\.dta$") local _savfile `"`_savfile'.dta"'
        if !`_savrep' {
            capture confirm new file `"`_savfile'"'
            if _rc {
                di as error `"calligram: saving(): file `_savfile' already exists; add the replace sub-option"'
                exit 602
            }
        }
    }

    // image(filename[, replace scale(#)]): a static PNG/JPG/SVG of each cloud
    local _img ""
    local _imgrep 0
    local _imgscale 2
    if `"`image'"' != "" {
        gettoken _img _imgopt : image, parse(",")
        local _img = strtrim(`"`_img'"')
        local _imgopt = strtrim(subinstr(`"`_imgopt'"', ",", "", 1))
        if `"`_img'"' == "" {
            di as error "calligram: image() needs a file name, e.g. image(cloud.png)"
            exit 198
        }
        foreach _o of local _imgopt {
            if "`_o'" == "replace" local _imgrep 1
            else if ustrregexm("`_o'", "^scale\(([0-9.]+)\)$") local _imgscale = real(ustrregexs(1))
            else {
                di as error `"calligram: image(): unknown sub-option `_o' (use replace and scale(#))"'
                exit 198
            }
        }
        if !(`_imgscale' > 0 & `_imgscale' <= 8) {
            di as error "calligram: image(..., scale(#)): # must be above 0 and at most 8 (default 2)"
            exit 198
        }
        // Java resolves relative paths against its own start-up folder, not
        // Stata's working directory, so the image path is made absolute (as
        // for savefile() and mask()); ~ means the home folder
        if ustrregexm(`"`_img'"', "^~([/\\]|$)") {
            local _home : env USERPROFILE
            if `"`_home'"' == "" local _home : env HOME
            local _rest = substr(`"`_img'"', 2, .)
            local _img `"`_home'`_rest'"'
        }
        if !ustrregexm(`"`_img'"', "^([A-Za-z]:|[/\\])") local _img `"`c(pwd)'/`_img'"'
        mata: st_local("_imgdir", strofreal(cg_dir_exists(st_local("_img"))))
        if `_imgdir' == 0 {
            di as error `"calligram: the folder for image() does not exist: `_img'"'
            exit 603
        }
        if !ustrregexm(lower(`"`_img'"'), "\.(png|jpg|jpeg|svg)$") {
            if ustrregexm(`"`_img'"', "\.[A-Za-z0-9]+$") {
                di as error "calligram: image() files can be .png, .jpg or .svg"
                exit 198
            }
            local _img `"`_img'.png"'
        }
    }

    if `width' < 50 | `height' < 50 {
        di as error "calligram: width() and height() must be at least 50"
        exit 198
    }
    if `margin' < 0 {
        di as error "calligram: margin() cannot be negative"
        exit 198
    }
    if `minfontsize' < 1 {
        di as error "calligram: minfontsize() must be at least 1"
        exit 198
    }
    if `maxfontsize' < 0 | (`maxfontsize' > 0 & `maxfontsize' < `minfontsize') {
        di as error "calligram: maxfontsize() must be 0 (automatic) or at least minfontsize()"
        exit 198
    }
    if `scaling' < 0 | `scaling' > 1 {
        di as error "calligram: scaling() must be between 0 and 1"
        exit 198
    }
    if `seed' < 0 {
        di as error "calligram: seed() cannot be negative"
        exit 198
    }
    if `spacing' < 0 | `spacing' > 0.5 {
        di as error "calligram: spacing() must be between 0 and 0.5 (a share of each word's font size)"
        exit 198
    }
    if `threads' < 0 {
        di as error "calligram: threads() cannot be negative (0 = use all cores)"
        exit 198
    }
    if `maxwords' < 1 {
        di as error "calligram: maxwords() must be at least 1"
        exit 198
    }

    // ── Font ─────────────────────────────────────────────────────────────────
    // Letters, digits, spaces and hyphens only: the name is written into the
    // SVG and passed to Java, so anything else could break either.
    if `"`font'"' == "" local font "Arial"
    local font = strtrim(`"`font'"')
    if !ustrregexm(`"`font'"', "^[A-Za-z0-9 \-]+$") {
        di as error "calligram: font() may contain only letters, digits, spaces and hyphens"
        exit 198
    }

    // ── Rotation ─────────────────────────────────────────────────────────────
    if `"`rotate'"' == "" local rotate "none"
    local rotate = lower(strtrim(`"`rotate'"'))
    if !inlist(`"`rotate'"', "none", "90", "random") {
        di as error "calligram: rotate() must be none, 90, or random"
        exit 198
    }

    // ── Title: "text", color(...) size(...) ──────────────────────────────────
    if `"`title'"' == "" local title "Word Cloud"
    // settings follow the last comma that is followed only by color() and size();
    // any other comma is part of the title ("Sales, by region")
    local title_text `"`title'"'
    local _topts ""
    if ustrregexm(`"`title'"', "^(.*),\s*((?:(?:color|size)\((?:[a-z]+\([^)]*\)|[^)])*\)\s*)+)$", 1) {
        local title_text = strtrim(ustrregexs(1))
        local _topts     = strtrim(ustrregexs(2))
    }

    local title_color ""
    if regexm(`"`_topts'"', "color\((rgba?[^)]+\)|hsla?[^)]+\)|[^)]+)\)") {
        local title_color = strtrim(regexs(1))
    }
    local title_size "1.4em"
    if regexm(`"`_topts'"', "size\(([^)]+)\)") {
        local _rawsize = strtrim(regexs(1))
        if regexm(`"`_rawsize'"', "^[0-9]+(\.[0-9]+)?$") local title_size "`_rawsize'em"
        else local title_size `"`_rawsize'"'
    }
    if `"`title_color'"' != "" & !ustrregexm(`"`title_color'"', "^(#[0-9A-Fa-f]{3,8}|[A-Za-z]+|(rgb|rgba|hsl|hsla)\([0-9., %]+\))$") {
        di as error "calligram: title color() is not a valid CSS color: `title_color'"
        di as error "  Use: color(#ff0000)  color(white)  color(rgb(0,128,255))"
        exit 198
    }
    if !ustrregexm(`"`title_size'"', "^[0-9]+(\.[0-9]+)?(em|rem|px|pt|%)$") {
        di as error "calligram: title size() is not a valid CSS size: `title_size'"
        di as error "  Use: size(2em)  size(24px)  size(1.5rem)  size(120%)"
        exit 198
    }
    // Strip surrounding quotes and make the title safe to put inside HTML
    mata: cg_title_html("title_text", "title_html")

    // ── Output file ──────────────────────────────────────────────────────────
    // Default: calligram.html in the current working directory (see -pwd-).
    // "~" at the start means the user's home folder; ".html" is added if
    // missing; relative paths are made absolute so the final message shows
    // exactly where the file went.
    if `"`savefile'"' == "" local savefile "calligram.html"
    local savefile = strtrim(`"`savefile'"')
    if ustrregexm(`"`savefile'"', "^~([/\\]|$)") {
        local _home : env USERPROFILE
        if `"`_home'"' == "" local _home : env HOME
        if `"`_home'"' == "" {
            di as error "calligram: cannot find your home folder to expand ~ in savefile()"
            exit 198
        }
        local _rest = substr(`"`savefile'"', 2, .)
        local savefile `"`_home'`_rest'"'
    }
    if !ustrregexm(lower(`"`savefile'"'), "\.html?$") local savefile `"`savefile'.html"'
    if !ustrregexm(`"`savefile'"', "^([A-Za-z]:|[/\\])") {
        local savefile `"`c(pwd)'/`savefile'"'
    }
    mata: st_local("_dirok", strofreal(cg_dir_exists(st_local("savefile"))))
    if `_dirok' == 0 {
        di as error `"calligram: the folder for savefile() does not exist:"'
        di as error `"  `savefile'"'
        exit 603
    }

    // ── Export format ────────────────────────────────────────────────────────
    local export_fmt = lower(strtrim(`"`export'"'))
    if !inlist(`"`export_fmt'"', "", "png", "jpg", "jpeg", "svg") {
        di as error "calligram: export() must be png, jpg, jpeg, or svg"
        exit 198
    }
    if `"`export_fmt'"' == "jpeg" local export_fmt "jpg"
    local fmt_upper = upper(`"`export_fmt'"')

    // ── Background colour ────────────────────────────────────────────────────
    if `"`bgcolor'"' == "" local bgcolor "#16213e"
    local bgcolor = strtrim(`"`bgcolor'"')
    if !ustrregexm(`"`bgcolor'"', "^(#[0-9A-Fa-f]{3,8}|[A-Za-z]+|(rgb|rgba|hsl|hsla)\([0-9., %]+\))$") {
        di as error "calligram: bgcolor() is not a valid CSS color: `bgcolor'"
        di as error "  Use: bgcolor(#16213e)  bgcolor(white)  bgcolor(rgb(0,30,60))"
        exit 198
    }
    // Text colour for the title (unless color() was given) and the footer:
    // dark on light backgrounds, light on dark ones
    mata: st_local("_light", strofreal(cg_is_light(st_local("bgcolor"))))
    local _ink = cond(`_light', "#222222", "#eeeeee")
    local _tdef = (`"`title_color'"' == "")
    if `_tdef' local title_color "`_ink'"

    // ── Outline: on if outline, outlinecolor() or outlinewidth() is given ──────
    local _ol 0
    if "`outline'" != "" | `"`outlinecolor'"' != "" | `outlinewidth' != -1 local _ol 1
    if `outlinewidth' == -1 local outlinewidth 2
    if `_ol' & (`outlinewidth' <= 0 | `outlinewidth' > 20) {
        di as error "calligram: outlinewidth() must be greater than 0 and at most 20"
        exit 198
    }
    // Default: the title/footer text colour, semi-transparent
    local _olop 1
    local _oldef 0
    if `"`outlinecolor'"' == "" {
        local outlinecolor "`_ink'"
        local _olop 0.45
        local _oldef 1
    }
    local outlinecolor = strtrim(`"`outlinecolor'"')
    if `_ol' & !ustrregexm(`"`outlinecolor'"', "^(#[0-9A-Fa-f]{3,8}|[A-Za-z]+|(rgb|rgba|hsl|hsla)\([0-9., %]+\))$") {
        di as error "calligram: outlinecolor() is not a valid CSS color: `outlinecolor'"
        exit 198
    }
    local _olw = cond(`_ol', `outlinewidth', 0)

    // Fonts bundled with calligram (free licences; also on Google Fonts)
    local _online = ("`online'" != "")
    local _fkey = lower(subinstr(subinstr(`"`font'"', " ", "", .), "-", "", .))
    local _gfam ""
    local _gnames "arimo Arimo tinos Tinos roboto Roboto opensans Open+Sans lato Lato notosans Noto+Sans merriweather Merriweather"
    local _nn : word count `_gnames'
    forvalues _k = 1(2)`_nn' {
        if "`_fkey'" == "`: word `_k' of `_gnames''" local _gfam "`: word `=`_k'+1' of `_gnames''"
    }
    local _bundled = ("`_gfam'" != "")


    // ── Gradient: two hex or named colours ───────────────────────────────────
    if `"`gradient'"' != "" {
        if `"`palette'"' != "" {
            di as error "calligram: gradient() and palette() are mutually exclusive"
            exit 198
        }
        local _grad_c1 : word 1 of `gradient'
        local _grad_c2 : word 2 of `gradient'
        local _grad_n  : word count `gradient'
        if `_grad_n' != 2 {
            di as error "calligram: gradient() needs exactly two colours, e.g. gradient(#ff6b6b #4ecdc4)"
            exit 198
        }
        forvalues _k = 1/2 {
            local _gval `"`_grad_c`_k''"'
            mata: st_local("_ok", strofreal(cg_css_valid(st_local("_gval"))))
            if `_ok' == 0 {
                di as error `"calligram: gradient() colour not recognised: `_gval'"'
                di as error "  Use hex (#rrggbb or #rgb) or a common CSS colour name (navy, tomato, ...)"
                exit 198
            }
        }
    }

    // ── Colour by a variable, colours per word, colours from a picture ──────
    local _cbv ""
    local _cbcat 0
    if (`"`colorby'"' != "") + ("`colorvar'" != "") + (`"`colorimage'"' != "") > 1 {
        di as error "calligram: give only one of colorby(), colorvar() and colorimage()"
        exit 198
    }
    if `"`colorby'"' != "" {
        gettoken _cbv _cbo : colorby, parse(",")
        local _cbv = strtrim(`"`_cbv'"')
        local _cbo = lower(strtrim(subinstr(`"`_cbo'"', ",", "", 1)))
        capture unab _cbv : `_cbv', max(1)
        if _rc {
            di as error `"calligram: colorby(): `_cbv' is not one variable in the data"'
            exit 111
        }
        if !inlist("`_cbo'", "", "categories", "category", "cat") {
            di as error `"calligram: colorby(): unknown sub-option `_cbo' (use: colorby(varname, categories))"'
            exit 198
        }
        if "`_cbo'" != "" local _cbcat 1
        capture confirm string variable `_cbv'
        if !_rc local _cbcat 1
        else if `"`: value label `_cbv''"' != "" local _cbcat 1
        local _cblab : variable label `_cbv'
        if `"`_cblab'"' == "" local _cblab "`_cbv'"
        if !`_cbcat' & `"`palette'"' != "" {
            di as error "calligram: palette() colours categories; for a numeric colorby() use gradient(low high)"
            exit 198
        }
    }
    if "`colorvar'" != "" & !`_pre' {
        di as error "calligram: colorvar() needs wordvar() (one word per row, with its colour)"
        exit 198
    }
    if ("`colorvar'" != "" | `"`colorimage'"' != "") & (`"`palette'"' != "" | `"`gradient'"' != "") {
        di as error "calligram: with colorvar() or colorimage() the colours are given; drop palette() and gradient()"
        exit 198
    }
    // fonts chosen per writing system: scriptfonts(arabic "Noto Nastaliq Urdu" chinese SimHei)
    local _jsf ""
    if `"`scriptfonts'"' != "" {
        local _sf `"`scriptfonts'"'
        local _spec ""
        while `"`_sf'"' != "" {
            gettoken _s _sf : _sf
            gettoken _f _sf : _sf
            local _s = lower(`"`_s'"')
            if !inlist(`"`_s'"', "arabic", "hebrew", "devanagari", "bengali", "tamil", "telugu", "gurmukhi", "gujarati", "thai") ///
             & !inlist(`"`_s'"', "chinese", "japanese", "korean", "cyrillic", "greek", "latin", "ethiopic") {
                di as error `"calligram: scriptfonts(): unknown writing system "`_s'""'
                di as error "  use arabic, hebrew, devanagari, bengali, tamil, telugu, gurmukhi, gujarati, thai,"
                di as error "  chinese, japanese, korean, cyrillic, greek, latin or ethiopic"
                exit 198
            }
            if `"`_f'"' == "" {
                di as error `"calligram: scriptfonts(): give a font name after `_s'"'
                exit 198
            }
            local _spec `"`_spec'`_s'=`_f';"'
        }
        mata: st_local("_jsf", cg_enc(st_local("_spec")))
    }
    local _cimg ""
    if `"`colorimage'"' != "" {
        local _cimg = strtrim(`"`colorimage'"')
        if ustrregexm(`"`_cimg'"', "^~([/\\]|$)") {
            local _home : env USERPROFILE
            if `"`_home'"' == "" local _home : env HOME
            local _rest = substr(`"`_cimg'"', 2, .)
            local _cimg `"`_home'`_rest'"'
        }
        if !ustrregexm(`"`_cimg'"', "^([A-Za-z]:|[/\\])") local _cimg `"`c(pwd)'/`_cimg'"'
        capture confirm file `"`_cimg'"'
        if _rc {
            di as error `"calligram: colorimage(): file not found: `_cimg'"'
            exit 601
        }
    }

    // ── Shape and mask ───────────────────────────────────────────────────────
    local _shape_given = `"`shape'"' != ""
    if `"`shape'"' == "" local shape "rectangle"
    local shape = lower(strtrim(`"`shape'"'))
    local _shapes "rectangle ellipse circle square cloud heart diamond triangle star"
    if !`: list shape in _shapes' {
        di as error "calligram: shape() must be one of: `_shapes'"
        exit 198
    }
    if `"`mask'"' != "" {
        if `_shape_given' {
            di as error "calligram: specify shape() or mask(), not both"
            exit 198
        }
        local mask = strtrim(`"`mask'"')
        if ustrregexm(`"`mask'"', "^~([/\\]|$)") {
            local _home : env USERPROFILE
            if `"`_home'"' == "" local _home : env HOME
            local _rest = substr(`"`mask'"', 2, .)
            local mask `"`_home'`_rest'"'
        }
        // Java resolves relative paths against its own start-up folder, not
        // Stata's working directory, so always pass an absolute path
        if !ustrregexm(`"`mask'"', "^([A-Za-z]:|[/\\])") local mask `"`c(pwd)'/`mask'"'
        capture confirm file `"`mask'"'
        if _rc {
            di as error `"calligram: mask() file not found: `mask'"'
            exit 601
        }
    }

    // =========================================================================
    // DATA  Which rows to use, and group numbers for by()
    //   Nothing is copied here: the Java engine reads the selected rows
    //   straight from the data in memory.
    // =========================================================================
    marksample touse, novarlist
    // weights (or, with wordvar(), the counts): one number per row
    local _hasw = ("`weight'" != "" | `_pre')
    tempvar wv
    if "`weight'" != "" {
        quietly gen double `wv' `exp' if `touse'
    }
    else if `_pre' {
        if "`countvar'" != "" quietly gen double `wv' = `countvar' if `touse'
        else quietly gen double `wv' = 1 if `touse'
    }
    if `_hasw' {
        quietly replace `touse' = 0 if missing(`wv')
        quietly count if `touse' & `wv' < 0
        if r(N) > 0 {
            di as error "calligram: weights and counts cannot be negative (" r(N) " rows)"
            exit 402
        }
        if "`weight'" == "fweight" {
            quietly count if `touse' & `wv' != int(`wv')
            if r(N) > 0 {
                di as error "calligram: frequency weights (fweight) must be whole numbers"
                exit 401
            }
        }
    }
    markout `touse' `textvar', strok
    quietly replace `touse' = 0 if strtrim(`textvar') == ""
    tempvar grp
    if "`by'" != "" {
        // group 1..G, value-labelled with the original values or labels
        quietly egen long `grp' = group(`by') if `touse', label
        quietly replace `touse' = 0 if missing(`grp')
    }
    else {
        quietly gen byte `grp' = 1 if `touse'
    }
    quietly count if `touse'
    if r(N) == 0 {
        di as error "calligram: `textvar' has no non-empty text in the selected observations"
        exit 2000
    }
    local _nuse = r(N)
    quietly summarize `grp' if `touse', meanonly
    local G = r(max)
    if `G' > 50 {
        di as error "calligram: by(`by') has `G' groups; at most 50 are supported"
        exit 198
    }
    // group labels (tab names), read once
    forvalues g = 1/`G' {
        local _lab`g' ""
        if "`by'" != "" local _lab`g' : label (`grp') `g'
    }

    // Built-in stopwords for the chosen languages (language(); default English),
    // plus any given in stopwords()
    if "`nostopwords'" == "" {
        local _sw_en ///
            a about above after again against all am an and any are arent as at be ///
            because been before being below between both but by cant cannot could ///
            couldnt did didnt do does doesnt doing dont down during each few for from ///
            further get got had hadnt has hasnt have havent having he hed hell hes her ///
            here heres hers herself him himself his how hows id ill im ive if in into is ///
            isnt it its itself lets me more most mustnt my myself no nor not of off on ///
            once only or other ought our ours ourselves out over own same shant she shed ///
            shell shes should shouldnt so some such than that thats the their theirs ///
            them themselves then there theres these they theyd theyll theyre theyve this ///
            those through to too under until up very was wasnt we wed well were weve ///
            werent what whats when whens where wheres which while who whos whom why whys ///
            will with wont would wouldnt you youd youll youre youve your yours yourself ///
            yourselves also although always among another anyone anything anyway around ///
            away became become becomes becoming beside besides beyond can come comes ///
            either else elsewhere enough etc even ever every everyone everything ///
            everywhere first go goes going gone however just last least less like likely ///
            lot lots made make makes many may maybe might much must neither never next ///
            nobody none nothing now often one ones onto others otherwise perhaps per ///
            quite rather said say says see seem seemed seems seen shall since something ///
            sometimes somewhat still sure take taken thing things though thus together ///
            toward towards upon us use used uses using via want wants way ways whatever ///
            whenever whether within without yet ago two three four five six seven eight ///
            nine ten hundred thousand
        local _sw_fr ///
            au aux avec ce ces dans de des du elle elles en et eux il ils je la le les ///
            leur leurs lui ma mais me même mêmes mes moi mon ne nos notre nous on ou où ///
            par pas pour qu que qui sa se ses son sur ta te tes toi ton tu un une vos ///
            votre vous ça cela ceci cet cette ceux celle celles celui ici là y été étée ///
            étés étant suis es est sommes êtes sont serai seras sera serons serez seront ///
            serais serait serions seriez seraient étais était étions étiez étaient fus ///
            fut fûmes fûtes furent sois soit soyons soyez soient ai as avons avez ont ///
            aurai auras aura aurons aurez auront aurais aurait aurions auriez auraient ///
            avais avait avions aviez avaient eut eûmes eûtes eurent aie aies ait ayons ///
            ayez aient eu être avoir fait faire très plus moins aussi bien tout tous ///
            toute toutes comme donc alors car quand dont si sans sous chez entre vers ///
            depuis pendant avant après encore déjà peu trop chaque quelque quelques ///
            autre autres aucun aucune lequel laquelle lesquels lesquelles
        local _sw_es ///
            de la que el en y a los del se las por un para con no una su al lo como más ///
            pero sus le ya o este sí porque esta entre cuando muy sin sobre también me ///
            hasta hay donde quien desde todo nos durante todos uno les ni contra otros ///
            ese eso ante ellos e esto mí antes algunos qué unos yo otro otras otra él ///
            tanto esa estos mucho quienes nada muchos cual poco ella estar estas algunas ///
            algo nosotros mi mis tú te ti tu tus ellas nosotras vosotros vosotras os mío ///
            mía míos mías tuyo tuya tuyos tuyas suyo suya suyos suyas nuestro nuestra ///
            nuestros nuestras vuestro vuestra vuestros vuestras esos esas estoy estás ///
            está estamos estáis están esté estés estemos estéis estén estaba estabas ///
            estábamos estaban estuve estuvo estuvimos estuvieron ser es son soy eres ///
            somos sois era eras éramos eran fui fue fuimos fueron sido siendo sea sean ///
            he has ha hemos habéis han había habías habíamos habían hube hubo haber ///
            tengo tienes tiene tenemos tenéis tienen tenía tenían tuve tuvo tener hace ///
            hacer así aquí allí ahora entonces aunque cada mismo misma mismos mismas vez ///
            veces bien según tan
        local _sw_pt ///
            de a o que e do da em um para é com não uma os no se na por mais as dos como ///
            mas foi ao ele das tem à seu sua ou ser quando muito há nos já está eu ///
            também só pelo pela até isso ela entre era depois sem mesmo aos ter seus ///
            quem nas me esse eles estão você tinha foram essa num nem suas meu às minha ///
            têm numa pelos elas havia seja qual será nós tenho lhe deles essas esses ///
            pelas este fosse dele tu te vocês vos lhes meus minhas teu tua teus tuas ///
            nosso nossa nossos nossas dela delas esta estes estas aquele aquela aqueles ///
            aquelas isto aquilo estou estamos estive esteve estivemos estiveram estava ///
            estávamos estavam sou somos são eram fui fomos sido sendo hei havemos hão ///
            houve tive teve tivemos tiveram tenha tinham fazer faz feito assim aqui ali ///
            agora então embora cada mesma mesmos mesmas vez vezes bem tão pois
        local builtin_sw ""
        foreach _l of local _langs {
            local builtin_sw `"`builtin_sw' `_sw_`_l''"'
        }
        local all_sw `"`builtin_sw' `stopwords'"'
    }
    else local all_sw `"`stopwords'"'

    // =========================================================================
    // INTERFACE FILES  (search, slider, zoom, themes, tabs, saving) are kept
    // inside calligram.jar; ask Java to write them out so they can be
    // copied into the page. Without Java the page keeps a basic tooltip.
    // =========================================================================
    local _ui 0
    capture findfile calligram.jar
    local _hasjar = (_rc == 0)
    if `_hasjar' {
        tempfile _uijs _uicss
        mata: st_local("_e1", cg_enc(st_local("_uijs")))
        mata: st_local("_e2", cg_enc(st_local("_uicss")))
        capture javacall calligram.Layout ui, jars(calligram.jar) args(jsfile=`_e1' cssfile=`_e2')
        if _rc == 0 local _ui 1
    }
    local _toolbar = ("`notoolbar'" == "" & `_ui')

    // =========================================================================
    // PAGE HEAD
    // =========================================================================
    local stem    = ustrregexra(`"`savefile'"', "\.html?$", "")
    local _base   = ustrregexra(`"`stem'"', "^.*[/\\]", "")
    local _jsstem = ustrregexra(`"`_base'"', "[^A-Za-z0-9_.\-]", "_")
    local _tcss   = cond(`_tdef', "var(--ink)", `"`title_color'"')

    tempname fh
    capture file open `fh' using `"`savefile'"', write replace text
    if _rc {
        local _frc = _rc
        di as error `"calligram: could not write `savefile'"'
        di as error "  Check that the folder is writable and the file is not open in another program."
        exit `_frc'
    }
    file write `fh' `"<!DOCTYPE html>"' _n
    file write `fh' `"<html lang='en'><head>"' _n
    file write `fh' `"<meta charset='UTF-8'>"' _n
    file write `fh' `"<meta name='viewport' content='width=device-width, initial-scale=1'>"' _n
    if `_online' & `_bundled' {
        // online option: load the font from Google Fonts. Every word also
        // carries its exact width (textLength), so a substitute font (no
        // internet, font blocked) cannot make words run into each other sideways.
        file write `fh' `"<link rel='preconnect' href='https://fonts.googleapis.com'>"' _n
        file write `fh' `"<link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>"' _n
        file write `fh' `"<link rel='stylesheet' href='https://fonts.googleapis.com/css2?family=`_gfam':wght@700&amp;display=block'>"' _n
    }
    if `_ui' {
        // Hide the words until the fade-in starts at first paint (ui.js removes
        // the class; this falls back to showing them after 4 seconds regardless)
        file write `fh' `"<script>(function(){var m=window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches;"' _n
        file write `fh' `"if(!m){var h=document.documentElement;h.classList.add('wc-pre');setTimeout(function(){h.classList.remove('wc-pre');},4000);}})();</script>"' _n
    }
    file write `fh' `"<title>`title_html'</title>"' _n
    file write `fh' `"<style>"' _n
    // Layout: a slim header across the top, the cloud area below it, and
    // (with the toolbar) the side panel on the right. Works without scripts.
    file write `fh' `"  *{box-sizing:border-box}"' _n
    file write `fh' `"  body{margin:0;min-height:100vh;background:var(--bg);color:var(--ink);"' _n
    file write `fh' `"       font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;"' _n
    file write `fh' `"       display:grid;grid-template-columns:minmax(0,1fr) auto;grid-template-rows:auto minmax(0,1fr)}"' _n
    file write `fh' `"  #hdr{grid-column:1/-1;grid-row:1;display:flex;align-items:center;flex-wrap:wrap;gap:6px 16px;"' _n
    file write `fh' `"       padding:10px 20px;border-bottom:1px solid rgba(127,127,127,.22)}"' _n
    file write `fh' `"  #hdr h1{margin:0;font-weight:700;letter-spacing:.3px;line-height:1.25}"' _n
    file write `fh' `"  #nw{font-size:14px;opacity:.6}"' _n
    file write `fh' `"  #tabs{display:flex;flex-wrap:wrap;gap:6px;margin-left:auto}"' _n
    file write `fh' `"  #stage{grid-column:1;grid-row:2;min-height:0;display:flex;flex-direction:column;align-items:center;"' _n
    file write `fh' `"       justify-content:center;gap:14px;padding:12px;min-width:0}"' _n
    file write `fh' `"  .pane{display:flex;flex-direction:column;align-items:center}"' _n
    file write `fh' `"  .plabel{font-weight:600;opacity:.85}"' _n
    file write `fh' `"  .legend{display:flex;align-items:center;justify-content:center;flex-wrap:wrap;gap:6px 14px;margin-top:8px;font-size:13px}"' _n
    file write `fh' `"  .legend .lt{font-weight:600;opacity:.85}"' _n
    file write `fh' `"  .legend .bar{display:inline-block;width:170px;height:10px;border-radius:5px}"' _n
    file write `fh' `"  .legend .sw{display:inline-flex;align-items:center;gap:6px}"' _n
    file write `fh' `"  .legend .sw i{display:inline-block;width:12px;height:12px;border-radius:3px}"' _n
    file write `fh' `"  svg.wc{display:block;max-width:100%;height:auto}"' _n
    file write `fh' `"  #tt{position:fixed;display:none;pointer-events:none;z-index:30;background:rgba(0,0,0,.85);"' _n
    file write `fh' `"       color:#fff;padding:6px 10px;border-radius:6px;font-size:13px}"' _n
    file write `fh' `"  #credit{position:fixed;left:14px;bottom:8px;font-size:11px;opacity:.4}"' _n
    file write `fh' `"  #panel~#credit{display:none}"' _n
    file write `fh' `"  #expbtn{position:fixed;right:16px;bottom:14px;padding:9px 18px;border:none;border-radius:8px;"' _n
    file write `fh' `"       background:#4e79a7;color:#fff;font:inherit;font-size:14px;cursor:pointer;"' _n
    file write `fh' `"       box-shadow:0 6px 18px rgba(0,0,0,.3)}"' _n
    file close `fh'
    if `_ui' {
        mata: st_local("_arc", strofreal(cg_append_file(st_local("savefile"), st_local("_uicss"))))
    }
    file open `fh' using `"`savefile'"', write append text
    file write `fh' `"</style></head>"' _n
    file write `fh' `"<body style='--bg:`bgcolor';--ink:`_ink''>"' _n
    file write `fh' `"<header id='hdr'>"' _n
    file write `fh' `"<h1 style='color:`_tcss';font-size:`title_size''>`title_html'</h1>"' _n
    file write `fh' `"<span id='nw'></span>"' _n
    if `G' > 1 & `_ui' file write `fh' `"<div id='tabs'></div>"' _n
    file write `fh' `"</header>"' _n
    file write `fh' `"<main id='stage'>"' _n
    file close `fh'

    // Font settings live on the SVG group (not page CSS) so they survive SVG
    // export. Kerning and ligatures are off to match how Java measured.
    local _fstack = cond(lower(`"`font'"') == "arial", "Arial, Helvetica, sans-serif", `"`font', Arial, Helvetica, sans-serif"')
    if `_bundled' {
        local _fname = subinstr("`_gfam'", "+", " ", .)
        local _fstack = cond(inlist("`_fkey'", "tinos", "merriweather"), "`_fname', Georgia, serif", "`_fname', Arial, sans-serif")
    }

    // =========================================================================
    // COUNT AND LAY OUT
    //   Java engine (one call for all groups): reads the selected rows,
    //   counts words in parallel, lays out every group's cloud (groups in
    //   parallel), and returns the words, sizes and positions in a frame.
    //   Fallback (no Java): the Stata/Mata pipeline on a preserved copy.
    // =========================================================================
    local _jpath 0
    tempname wcf wcg wcp wcs _sc fhs
    // options that only the Java engine supports
    local _needj ""
    if "`weight'" != "" local _needj "weights"
    if `_pre' local _needj "wordvar()"
    if "`phrases'" != "" | `"`addphrases'"' != "" local _needj "phrases"
    if `"`_img'"' != "" local _needj "image()"
    if `"`_shp'"' != "" local _needj "shapes()"
    if `"`colorby'"' != "" local _needj "colorby()"
    if "`colorvar'" != "" local _needj "colorvar()"
    if `"`colorimage'"' != "" local _needj "colorimage()"
    if `"`scriptfonts'"' != "" local _needj "scriptfonts()"
    if !`_hasjar' & "`_needj'" != "" {
        di as error "calligram: `_needj' need the Java engine (calligram.jar), which was not found."
        di as error "  Reinstall with {cmd:net install calligram, replace}."
        exit 198
    }
    if `_hasjar' {
        tempfile _swfile _olfile
        // (a new temporary file: no 'replace', so Stata prints no "file not found" note)
        file open `fhs' using `"`_swfile'"', write text
        foreach _w of local all_sw {
            file write `fhs' `"`_w'"' _n
        }
        file close `fhs'
        mata: st_local("_jsw",   cg_enc(st_local("_swfile")))
        mata: st_local("_jolf",  cg_enc(st_local("_olfile")))
        mata: st_local("_jfont", cg_enc(st_local("font")))
        mata: st_local("_jmask", cg_enc(st_local("mask")))
        local _clean = ("`noclean'" == "")
        // phrases to join or keep apart: one per line, in temporary files
        local _jadd ""
        local _jdrop ""
        local _jpf ""
        if `"`addphrases'"' != "" {
            tempfile _addf
            file open `fhs' using `"`_addf'"', write text
            foreach _p of local addphrases {
                file write `fhs' `"`_p'"' _n
            }
            file close `fhs'
            mata: st_local("_jadd", cg_enc(st_local("_addf")))
        }
        if `"`dropphrases'"' != "" {
            tempfile _dropf
            file open `fhs' using `"`_dropf'"', write text
            foreach _p of local dropphrases {
                file write `fhs' `"`_p'"' _n
            }
            file close `fhs'
            mata: st_local("_jdrop", cg_enc(st_local("_dropf")))
        }
        if "`phrases'" != "" | `"`addphrases'"' != "" local _jpf "`wcp'"
        local _wvar = cond(`_hasw', "`wv'", "")
        if "`regions'" != "" local _wvar "`wv' `regions'"
        if "`location'" != "" local _wvar "`wv' `location'"
        local _rmode ""
        if "`location'" != "" local _rmode "location"
        else if "`regions'" != "" local _rmode = cond(`"`_shp'"' != "", "id", "color")
        // shapes(): the boundary points (_ID, _X, _Y) as text for the Java engine
        local _jshp ""
        if `"`_shp'"' != "" {
            tempfile _shptxt
            tempname shpfr
            frame create `shpfr'
            frame `shpfr': quietly use `"`_shp'"', clear
            capture frame `shpfr': confirm numeric variable _ID _X _Y
            if _rc {
                di as error `"calligram: shapes(`shapes'): needs the variables _ID, _X and _Y (a *_shp.dta file made by spshape2dta)"'
                exit 111
            }
            capture frame `shpfr': confirm variable shape_order
            if !_rc frame `shpfr': sort _ID shape_order
            frame `shpfr': quietly export delimited _ID _X _Y using `"`_shptxt'"', novarnames nolabel replace
            frame drop `shpfr'
            mata: st_local("_jshp", cg_enc(st_local("_shptxt")))
        }
        // colour by a variable: categories are numbered 1..K (names kept), numbers passed as they are
        local _cjm ""
        local _cjv ""
        local _cK 0
        if "`_cbv'" != "" {
            if `_cbcat' {
                tempvar _ccode
                quietly egen long `_ccode' = group(`_cbv') if `touse', label
                quietly summarize `_ccode', meanonly
                local _cK = cond(missing(r(max)), 0, r(max))
                if `_cK' > 30 {
                    di as error "calligram: colorby(): `_cbv' has `_cK' categories; at most 30 can be told apart by colour"
                    exit 198
                }
                forvalues _k = 1/`_cK' {
                    local _ccn`_k' : label (`_ccode') `_k'
                }
                local _cjm "category"
                local _cjv "`_ccode'"
            }
            else {
                local _cjm "numeric"
                local _cjv "`_cbv'"
            }
        }
        else if "`colorvar'" != "" {
            local _cjm "color"
            local _cjv "`colorvar'"
        }
        local _cpos = 3 + `: word count `_wvar''
        local _jcimg ""
        if `"`_cimg'"' != "" mata: st_local("_jcimg", cg_enc(st_local("_cimg")))
        capture noisily javacall calligram.Cloud run `textvar' `grp' `_wvar' `_cjv' if `touse', ///
            jars(calligram.jar)                                                ///
            args(frame=`wcf' groups=`G' threads=`threads' stopfile=`_jsw'       ///
                 clean=`_clean' minlength=`minlength' minfreq=`minfreq'        ///
                 maxwords=`maxwords' width=`width' height=`height'             ///
                 margin=`margin' maxfont=`maxfontsize' minfont=`minfontsize'   ///
                 scaling=`scaling' seed=`seed' rotate=`rotate' shape=`shape'   ///
                 font=`_jfont' mask=`_jmask' outline=`_olw' outfile=`_jolf'  ///
                 mode=`=cond(`_online', "text", "paths")' spacing=`spacing'  ///
                 hyphens=`=("`splithyphens'" == "")' plurals=`=("`noplurals'" == "")' ///
                 elision=`_elision' phrases=`=("`phrases'" != "")'            ///
                 phrasestrength=`phrasestrength' addfile=`_jadd'              ///
                 dropfile=`_jdrop' pframe=`_jpf' precounted=`_pre'            ///
                 weight=`=("`weight'" != "")' paths=`=(`"`_img'"' != "")' ///
                 regionmode=`_rmode' shapesfile=`_jshp' projection=`_proj' ///
                 near=`=("`near'" != "")' colormode=`_cjm' colork=`_cK'      ///
                 colorpos=`_cpos' colorimage=`_jcimg' scriptfonts=`_jsf')
        local _jrc = _rc
        if `_jrc' == 0 {
            local _jpath 1
        }
        else if inlist(`_jrc', 111, 498, 601, 610) {
            // A problem with the settings or mask file: stop here
            exit `_jrc'
        }
        else if "`_needj'" != "" {
            di as error "calligram: the Java engine failed (error `_jrc'), and `_needj' need it."
            exit `_jrc'
        }
        else {
            di as text "calligram: the Java engine failed (error `_jrc'); using the slower Stata/Mata pipeline."
        }
    }
    else {
        di as text "calligram: calligram.jar not found on the ado-path; using the slower Stata/Mata pipeline."
        di as text "  Reinstall with {cmd:net install calligram, replace} for speed, shapes, masks and the side panel."
    }

    // Phrases joined (listed so they can be checked; see addphrases()/dropphrases())
    local _nphr 0
    if `_jpath' & "`_jpf'" != "" {
        mata: cg_phrase_report("`wcp'", 25)
    }

    if !`_jpath' {
        if "`splithyphens'`noplurals'" == "" | "`language'" != "" {
            di as text "  (without the Java engine, hyphenated words are split and plurals are not merged)"
        }
        if "`shape'" != "rectangle" | `"`mask'"' != "" {
            di as text "  (shape() and mask() need the Java engine; drawing a rectangular cloud instead)"
        }
        if `_ol' di as text "  (outline needs the Java engine; no outline drawn)"
        // Fallback: work on a copy of just the selected text
        preserve
        quietly keep if `touse'
        quietly keep `textvar' `grp'
        rename `textvar' _wc_text
        rename `grp' _wc_g
        if "`noclean'" == "" {
            quietly {
                replace _wc_text = ustrlower(_wc_text)
                replace _wc_text = ustrregexra(_wc_text, "['\x{2018}\x{2019}]", "")
                replace _wc_text = ustrregexra(_wc_text, "[^\p{L}\p{N}\s]", " ")
            }
        }
        tempfile _alltext
        quietly save `"`_alltext'"'
    }

    // =========================================================================
    // ONE CLOUD PER GROUP (a single cloud without by())
    // =========================================================================
    if `_online' & !`_bundled' {
        di as text `"calligram: online: "`font'" is not one of the bundled fonts, so the page uses the viewer's own copy of it;"'
        di as text "  words could look different on computers without it. Bundled fonts: Arimo, Tinos, Roboto, Open Sans, Lato, Noto Sans, Merriweather."
    }
    if !`_jpath' & !`_online' {
        di as text "  (without the Java engine, words are written as text in the viewer's fonts, not as exact outlines)"
    }

    local _ngood      0
    local _tot_words  0
    local _tot_placed 0
    local _maxfs_all  0
    local _ol_any     0
    local _ol_g = cond(`_jpath', `_ol', 0)

    forvalues g = 1/`G' {
        local _lab `"`_lab`g''"'
        local _pre = cond("`by'" != "", `"calligram [`_lab']: "', "calligram: ")
        local _skip ""

        if `_jpath' {
            // this group's rows of the results frame
            capture frame drop `wcg'
            frame `wcf': quietly frame put if g == `g', into(`wcg')
            local _fr "`wcg'"
            frame `_fr': quietly count
            if r(N) == 0 local _skip "no words remain after filtering (try lowering minfreq() or minlength())"
        }
        else {
            // ── Fallback steps 1-8 in the preserved copy ─────────────────────
            quietly use `"`_alltext'"', clear
            quietly keep if _wc_g == `g'
            quietly keep _wc_text
            if _N == 0 {
                local _skip "no text"
            }
            else {
                mata: cg_tokenize("_wc_text")
                if _N == 0 local _skip "no words found"
            }
            if "`_skip'" == "" {
                quietly {
                    gen byte _wc_drop = 0
                    if strtrim(`"`all_sw'"') != "" {
                        mata: cg_mark_stopwords("all_sw", "_wc_drop")
                    }
                    replace _wc_drop = 1 if ustrregexm(word, "^\p{N}+$")
                    replace _wc_drop = 1 if ustrlen(word) < `minlength'
                    drop if _wc_drop
                    drop _wc_drop
                }
                if _N > 0 {
                    quietly {
                        contract word, freq(freq)
                        drop if freq < `minfreq'
                        gsort -freq word
                        if _N > `maxwords' keep in 1/`maxwords'
                    }
                }
                if _N == 0 local _skip "no words remain after filtering (try lowering minfreq() or minlength())"
            }
            if "`_skip'" == "" {
                quietly {
                    gen double fontsize = .
                    gen double rotation = 0
                    gen double tx = .
                    gen double ty = .
                    gen byte   placed = 0
                }
                local _start = cond(`maxfontsize' > 0, `maxfontsize', 80)
                mata: cg_rs_sizes(`scaling', `_start', `minfontsize')
                quietly {
                    // Size estimates from character count (Java measures exactly)
                    gen double ink_x = 0
                    gen double ink_y = -0.80 * fontsize
                    gen double ink_h =  1.05 * fontsize
                    gen double ink_w =  0.60 * fontsize * ustrlen(word)
                    gen double px = .
                    gen double py = .
                }
                mata: cg_layout(`width', `height', `margin', "`rotate'")
            }
            local _fr "`c(frame)'"
        }

        if "`_skip'" != "" {
            if "`by'" == "" {
                di as error "calligram: `_skip'"
                exit 2000
            }
            di as text `"`_pre'`_skip'; group skipped."'
            continue
        }

        // ── From here the same for both paths; data commands run in frame _fr
        local F "frame `_fr':"
        `F' quietly count
        local nwords = r(N)
        `F' quietly count if placed
        local nplaced = r(N)
        `F' quietly gen long _wc_rank = _n
        if `"`_savfile'"' != "" {
            capture frame drop `wcs'
            frame copy `_fr' `wcs'
        }
        `F' quietly keep if placed
        if `nplaced' == 0 {
            if "`by'" == "" {
                di as error "calligram: no words fit; try a larger width()/height(), a roomier shape, or a smaller minfontsize()"
                exit 2000
            }
            di as text `"`_pre'no words fit; group skipped."'
            continue
        }
        `F' quietly summarize fontsize, meanonly
        local _maxfs = r(max)
        di as text `"`_pre'`nplaced' of `nwords' words placed (largest font `_maxfs'px)."'
        if `nplaced' < `nwords' {
            if "`regions'`location'" != "" {
                di as text "  (`=`nwords'-`nplaced'' words did not fit in their own area even at minfontsize(`minfontsize');"
                di as text "   small or crowded areas fill first; a larger canvas or a smaller minfontsize() would fit more)"
            }
            else {
                di as text "  (`=`nwords'-`nplaced'' rarely used words did not fit even at minfontsize(`minfontsize');"
                di as text "   a larger canvas, a roomier shape or a smaller minfontsize() would fit more)"
            }
        }

        // ── Step 9: colours (rows are still most- to least-frequent) ─────────
        `F' quietly gen str40 color = ""
        local _tab10 "#4e79a7 #f28e2b #e15759 #76b7b2 #59a14f #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac"
        local _legend ""
        local _lgn 0
        if "`_cjm'" != "" | `"`_cimg'"' != "" {
            // colours that carry meaning; each word also gets a note for the hover card
            `F' quietly gen strL note = ""
            mata: st_local("_lth", cg_html(st_local("_cblab")))
            if "`_cjm'" == "numeric" {
                local _cc1 "#d73027"
                local _cc2 "#1a9850"
                if `"`gradient'"' != "" {
                    local _cc1 `"`_grad_c1'"'
                    local _cc2 `"`_grad_c2'"'
                }
                `F' quietly summarize cval if placed == 1, meanonly
                local _clo = r(min)
                local _chi = r(max)
                // (values go into frame-prefixed Mata as text, as elsewhere in this program)
                `F' mata: cg_color_numeric(`"`_cc1'"', `"`_cc2'"', `=cond(missing(`_clo'), 0, `_clo')', `=cond(missing(`_chi'), 0, `_chi')', `"`_cblab'"')
                if !missing(`_clo') {
                    local _flo = strtrim(string(`_clo', "%9.3g"))
                    local _fhi = strtrim(string(`_chi', "%9.3g"))
                    mata: st_local("_cstops", cg_grad_stops(st_local("_cc1"), st_local("_cc2"), 7))
                    local _legend `"<div class='legend'><span class='lt'>`_lth'</span><span>`_flo'</span><span class='bar' style='background:linear-gradient(90deg,`_cstops')'></span><span>`_fhi'</span></div>"'
                    local _lgn 1
                    local _lg1 `"grad`=char(9)'`_cc1'`=char(9)'`_cc2'`=char(9)'`_flo'`=char(9)'`_fhi'"'
                }
                if `g' == 1 di as text `"calligram: colours: average of `_cblab' over the responses each word appears in (low `_cc1', high `_cc2')"'
            }
            else if "`_cjm'" == "category" {
                // one colour per category: palette(), gradient() or the built-in colours
                local _usep 0
                if `"`palette'"' != "" {
                    capture which colorpalette
                    if !_rc {
                        capture colorpalette `palette', n(`_cK') nograph
                        if !_rc local _usep 1
                    }
                }
                if `"`gradient'"' != "" & `_cK' > 0 mata: st_local("_cgl", cg_grad_stops(st_local("_grad_c1"), st_local("_grad_c2"), `_cK'))
                forvalues _k = 1/`_cK' {
                    local _c ""
                    if `_usep' {
                        local _p `"`r(p`_k')'"'
                        if ustrregexm(`"`_p'"', "^ *([0-9]+) +([0-9]+) +([0-9]+) *$") local _c "rgb(`=ustrregexs(1)',`=ustrregexs(2)',`=ustrregexs(3)')"
                        else if ustrregexm(`"`_p'"', "^#[0-9A-Fa-f]{6}$") local _c `"`_p'"'
                    }
                    if `"`_c'"' == "" & `"`gradient'"' != "" local _c : word `_k' of `=subinstr("`_cgl'", ",", " ", .)'
                    // more than 10 groups: 20 distinct colours (Tableau 20 order) before repeating
                    local _tab20 "#4e79a7 #f28e2b #e15759 #76b7b2 #59a14f #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac #a0cbe8 #ffbe7d #ff9d9a #8cd17d #f1ce63 #d4a6c8 #86bcb6 #fabfd2 #d7b5a6 #79706e"
                    if `"`_c'"' == "" & `_cK' > 10 local _c : word `=mod(`_k' - 1, 20) + 1' of `_tab20'
                    if `"`_c'"' == "" local _c : word `=mod(`_k' - 1, 10) + 1' of `_tab10'
                    local _ccol`_k' `"`_c'"'
                }
                // each word in the colour of the category it is most typical of
                `F' quietly replace color = "#9e9e9e"
                `F' quietly replace note = `"`_cblab': no clear group (used about evenly)"'
                forvalues _k = 1/`_cK' {
                    `F' quietly replace color = `"`_ccol`_k''"' if ccat == `_k'
                    `F' quietly replace note = `"`_cblab': most typical of `_ccn`_k''"' if ccat == `_k'
                }
                `F' quietly replace note = note + " (used " + strtrim(string(cshare, "%9.2g")) + " times as often as overall)" if !missing(ccat) & !missing(cshare)
                `F' quietly levelsof ccat if placed == 1 & !missing(ccat)
                local _cpresent `"`r(levels)'"'
                local _legend `"<div class='legend'><span class='lt'>`_lth'</span>"'
                foreach _k of local _cpresent {
                    mata: st_local("_cnh", cg_html(st_local("_ccn`_k'")))
                    // (the colour goes through a plain macro: a nested macro followed by the
                    //  HTML quote would swallow that quote and break the legend's markup)
                    local _cck `"`_ccol`_k''"'
                    local _legend `"`_legend'<span class='sw' data-cat='`_k''><i style='background:`_cck''></i>`_cnh'</span>"'
                    local ++_lgn
                    local _lg`_lgn' `"cat`=char(9)'`_ccol`_k''`=char(9)'`_ccn`_k''"'
                }
                `F' quietly count if placed == 1 & missing(ccat)
                if r(N) > 0 {
                    local _legend `"`_legend'<span class='sw' data-cat='0'><i style='background:#9e9e9e'></i>no clear group</span>"'
                    local ++_lgn
                    local _lg`_lgn' `"cat`=char(9)'#9e9e9e`=char(9)'no clear group"'
                }
                local _legend `"`_legend'</div>"'
                if `_lgn' == 0 local _legend ""
                if `g' == 1 di as text `"calligram: colours: `_cblab', the group each word is most typical of (used significantly more there, 95% confidence; grey: no clear group)"'
            }
            else {
                // colours given per word (colorvar()) or taken from a picture (colorimage())
                `F' mata: st_numscalar("`_sc'", cg_color_given())
                local _cbad = scalar(`_sc')
                if `_cbad' > 0 & `"`_cimg'"' != "" di as text `"`_pre'`_cbad' placed word`=cond(`_cbad' == 1, "", "s")' had no picture under the letters; drawn in grey."'
                else if `_cbad' > 0 di as text `"`_pre'`_cbad' placed word`=cond(`_cbad' == 1, "", "s")' had no usable colour; drawn in grey."'
                if `g' == 1 & `"`_cimg'"' != "" di as text "calligram: each word takes the average colour of the picture under its letters"
            }
        }
        else if `"`gradient'"' != "" {
            `F' mata: cg_hsl_gradient(`"`_grad_c1'"', `"`_grad_c2'"', "color")
            if `g' == 1 di as text `"calligram: gradient from `_grad_c1' to `_grad_c2' (HSL interpolation)"'
        }
        else {
            local _use_palette 0
            if `"`palette'"' != "" {
                capture which colorpalette
                if _rc {
                    if `g' == 1 {
                        di as text "calligram: colorpalette not installed; using built-in colours."
                        di as text "  To use palette(): ssc install palettes, ssc install colrspace"
                    }
                }
                else {
                    capture colorpalette `palette', n(`nplaced') nograph
                    if _rc {
                        if `g' == 1 di as text `"calligram: colorpalette could not create palette "`palette'"; using built-in colours."'
                    }
                    else local _use_palette 1
                }
            }
            forvalues _ci = 1/`nplaced' {
                local _c ""
                if `_use_palette' {
                    local _p `"`r(p`_ci')'"'
                    if ustrregexm(`"`_p'"', "^ *([0-9]+) +([0-9]+) +([0-9]+) *$") {
                        local _c "rgb(`=ustrregexs(1)',`=ustrregexs(2)',`=ustrregexs(3)')"
                    }
                    else if ustrregexm(`"`_p'"', "^#[0-9A-Fa-f]{6}$") local _c `"`_p'"'
                }
                if `"`_c'"' == "" local _c : word `=mod(`_ci' - 1, 10) + 1' of `_tab10'
                `F' quietly replace color = `"`_c'"' in `_ci'
            }
        }

        // ── Step 10: this group's cloud ──────────────────────────────────────
        mata: st_local("_labh", cg_html(st_local("_lab")))
        local _labf = ustrregexra(`"`_lab'"', "[^A-Za-z0-9_\-]", "_")
        file open `fh' using `"`savefile'"', write append text
        file write `fh' `"<div class='pane' data-label='`_labh'' data-file='`_labf''>"' _n
        if "`by'" != "" file write `fh' `"<div class='plabel'>`_labh'</div>"' _n
        file write `fh' `"<svg class='wc' width='`width'' height='`height'' viewBox='0 0 `width' `height''"' _n
        file write `fh' `"     xmlns='http://www.w3.org/2000/svg'>"' _n
        file write `fh' `"<rect class='bg' width='`width'' height='`height'' fill='`bgcolor'' rx='12'/>"' _n
        file close `fh'
        if `_ol_g' {
            mata: st_local("_orc", strofreal(cg_write_outline(st_local("savefile"), st_local("_olfile"), st_local("outlinecolor"), `outlinewidth', `_olop', `_oldef')))
            if `_orc' != 0 {
                di as error `"calligram: could not append to `savefile' (error `_orc')"'
                exit 603
            }
            local _ol_any 1
        }
        file open `fh' using `"`savefile'"', write append text
        file write `fh' `"<g font-family='`_fstack'' font-weight='bold'"' _n
        file write `fh' `"   style='font-kerning:none;font-variant-ligatures:none'>"' _n
        file close `fh'
        // (the return code comes back through a scalar, which every frame shares)
        if `_jpath' & !`_online' {
            // the words' exact letter outlines: identical on every computer, no internet needed
            `F' mata: st_numscalar("`_sc'", cg_write_paths(`"`savefile'"'))
        }
        else {
            `F' mata: st_numscalar("`_sc'", cg_write_words(`"`savefile'"'))
        }
        if scalar(`_sc') != 0 {
            di as error `"calligram: could not append to `savefile' (error `=scalar(`_sc')')"'
            exit 603
        }
        file open `fh' using `"`savefile'"', write append text
        file write `fh' `"</g></svg>"' _n
        if `"`_legend'"' != "" file write `fh' `"`_legend'"' _n
        file write `fh' `"</div>"' _n
        file close `fh'

        // image(): a static PNG/JPG/SVG of this group's cloud, drawn by Java
        if `"`_img'"' != "" {
            local _imgf `"`_img'"'
            if "`by'" != "" & ustrregexm(`"`_img'"', "^(.*)(\.[A-Za-z]+)$") {
                local _imgf = ustrregexs(1) + "_`_labf'" + ustrregexs(2)
            }
            if !`_imgrep' {
                capture confirm new file `"`_imgf'"'
                if _rc {
                    di as error `"calligram: image(): `_imgf' already exists; add the replace sub-option"'
                    exit 602
                }
            }
            local _bgx `"`bgcolor'"'
            if !ustrregexm(`"`_bgx'"', "^(#|rgb)") {
                mata: st_local("_bgx", "#" + cg_named_hex(strlower(strtrim(st_local("bgcolor")))))
            }
            local _olx `"`outlinecolor'"'
            if !ustrregexm(`"`_olx'"', "^(#|rgb)") {
                mata: st_local("_olx", "#" + cg_named_hex(strlower(strtrim(st_local("outlinecolor")))))
            }
            mata: st_local("_jimg", cg_enc(st_local("_imgf")))
            mata: st_local("_jbg",  cg_enc(st_local("_bgx")))
            mata: st_local("_jolx", cg_enc(st_local("_olx")))
            local _jolw = cond(`_ol_g', `outlinewidth', 0)
            // the legend, for the picture: one line per entry (title, then a gradient or categories)
            local _jlg ""
            if `_lgn' > 0 {
                tempfile _lgf
                tempname _lgh
                quietly file open `_lgh' using `"`_lgf'"', write text replace
                file write `_lgh' `"title`=char(9)'`_cblab'"' _n
                forvalues _k = 1/`_lgn' {
                    file write `_lgh' `"`_lg`_k''"' _n
                }
                file close `_lgh'
                mata: st_local("_jlg", cg_enc(st_local("_lgf")))
            }
            mata: st_local("_jink", cg_enc(st_local("_ink")))
            capture noisily `F' javacall calligram.Render run path color, jars(calligram.jar) ///
                args(out=`_jimg' width=`width' height=`height' scale=`_imgscale' bg=`_jbg' ///
                     olfile=`_jolf' olcolor=`_jolx' olwidth=`_jolw' olopacity=`_olop' ///
                     legend=`_jlg' ink=`_jink')
            local _rrc = _rc
            if `_rrc' {
                di as error `"calligram: could not write the image `_imgf'"'
                exit `_rrc'
            }
            local _imglist `"`_imglist' `"`_imgf'"'"'
            di as text `"`_pre'image saved to {browse `"`_imgf'"'}"'
        }

        // saving(): this group's words with colours, placed or not
        if `"`_savfile'"' != "" {
            tempfile _svp _sv`g'
            `F' quietly save `"`_svp'"'
            frame `wcs': quietly keep if !placed
            frame `wcs': quietly append using `"`_svp'"'
            frame `wcs': quietly replace color = "" if missing(color)
            frame `wcs': sort _wc_rank
            frame `wcs': quietly gen long group = `g'
            if "`by'" != "" frame `wcs': quietly gen strL group_label = `"`_lab'"'
            frame `wcs': quietly save `"`_sv`g''"'
            local _svlist `"`_svlist' `"`_sv`g''"'"'
        }

        local _ngood      = `_ngood' + 1
        local _tot_words  = `_tot_words' + `nwords'
        local _tot_placed = `_tot_placed' + `nplaced'
        local _maxfs_all  = max(`_maxfs_all', `_maxfs')
    }

    if `_ngood' == 0 {
        di as error "calligram: no group had any words to show"
        exit 2000
    }

    if `"`_savfile'"' != "" {
        capture frame drop `wcs'
        frame create `wcs'
        local _first 1
        foreach _f of local _svlist {
            if `_first' frame `wcs': quietly use `"`_f'"', clear
            else frame `wcs': quietly append using `"`_f'"'
            local _first 0
        }
        local W "frame `wcs':"
        capture `W' confirm variable nraw
        if _rc `W' quietly gen double nraw = freq
        `W' rename freq count
        `W' rename nraw n
        `W' rename _wc_rank rank
        `W' rename tx x
        `W' rename ty y
        local _keep group
        if "`by'" != "" local _keep `_keep' group_label
        local _rk ""
        if "`regions'`location'" != "" local _rk region
        local _ck ""
        capture `W' confirm variable cval
        if !_rc {
            `W' rename cval colorvalue
            local _ck "colorvalue"
        }
        capture `W' confirm variable ccat
        if !_rc {
            `W' quietly gen strL colorgroup = ""
            forvalues _k = 1/`_cK' {
                `W' quietly replace colorgroup = `"`_ccn`_k''"' if ccat == `_k'
            }
            `W' rename cshare colorlift
            local _ck "colorgroup colorlift"
        }
        `W' keep `_keep' rank word `_rk' count n placed fontsize rotation x y color `_ck'
        `W' order `_keep' rank word `_rk' count n placed fontsize rotation x y color `_ck'
        capture `W' label variable colorvalue `"average `_cblab' of the responses with the word"'
        capture `W' label variable colorgroup `"the `_cblab' the word is most typical of (empty: no clear group)"'
        capture `W' label variable colorlift "times as often as overall the word is used in that group"
        if "`regions'`location'" != "" `W' label variable region "area of the word (_ID with shapes(), colour with mask())"
        `W' label variable group     "group number (by())"
        if "`by'" != "" `W' label variable group_label "group (by())"
        `W' label variable rank      "rank in the group (1 = most frequent)"
        `W' label variable word      "word or two-word phrase"
        `W' label variable count     "count (weighted, if weights were used)"
        `W' label variable n         "number of occurrences"
        `W' label variable placed    "1 if the word fitted in the cloud"
        `W' label variable fontsize  "font size in pixels"
        `W' label variable rotation  "rotation in degrees"
        `W' label variable x         "x of the text origin on the canvas (pixels)"
        `W' label variable y         "y of the text baseline on the canvas (pixels)"
        `W' label variable color     "colour"
        `W' quietly compress
        if `_savrep' `W' quietly save `"`_savfile'"', replace
        else `W' quietly save `"`_savfile'"'
        di as text `"calligram: words, counts, sizes and positions saved to {browse `"`_savfile'"'}"'
    }

    // =========================================================================
    // PAGE END: optional single save button, footer, scripts
    // =========================================================================
    file open `fh' using `"`savefile'"', write append text
    file write `fh' `"</main>"' _n
    if `_toolbar' file write `fh' `"<aside id='panel' aria-label='Explore the word cloud'></aside>"' _n
    file write `fh' `"<div id='tt'></div>"' _n
    file write `fh' `"<div id='credit'>calligram.ado &nbsp;&middot;&nbsp; `_tot_placed' words</div>"' _n
    if `"`export_fmt'"' != "" & !`_toolbar' & `_ui' {
        file write `fh' `"<button id='expbtn' data-fmt='`export_fmt''>&#11015; Save as `fmt_upper'</button>"' _n
    }
    if `_ui' {
        local _fx = ("`fixed'" != "")
        local _cfg "toolbar:`_toolbar',fixed:`_fx',light:`_light',bg:'`bgcolor'',ink:'`_ink'',stem:'`_jsstem''"
        if "`_cjm'" != "" | `"`_cimg'"' != "" local _cfg "`_cfg',fixedcolors:1"
        file write `fh' `"<script>window.WC_CONFIG={`_cfg'};</script>"' _n
        file write `fh' `"<script>"' _n
        file close `fh'
        mata: st_local("_arc", strofreal(cg_append_file(st_local("savefile"), st_local("_uijs"))))
        file open `fh' using `"`savefile'"', write append text
        file write `fh' `"</script>"' _n
    }
    else {
        // Basic tooltip only (no Java available)
        file write `fh' `"<script>"' _n
        file write `fh' `"const tt=document.getElementById('tt');"' _n
        file write `fh' `"document.querySelectorAll('.w').forEach(el=>{"' _n
        file write `fh' `"  el.addEventListener('mousemove',ev=>{"' _n
        file write `fh' `"    tt.style.display='block';"' _n
        file write `fh' `"    tt.style.left=(ev.clientX+14)+'px';"' _n
        file write `fh' `"    tt.style.top=(ev.clientY-28)+'px';"' _n
        file write `fh' `"    tt.textContent=el.dataset.word+': count = '+el.dataset.count;"' _n
        file write `fh' `"  });"' _n
        file write `fh' `"  el.addEventListener('mouseleave',()=>tt.style.display='none');"' _n
        file write `fh' `"});"' _n
        file write `fh' `"</script>"' _n
    }
    file write `fh' `"</body></html>"' _n
    file close `fh'

    di as result `"Word cloud saved to {browse `"`savefile'"':`savefile'}"'
    di as text   "Click the path above, or open the file in any web browser."

    // (the fallback path preserved the data; Stata restores it on exit)

    return scalar N_words     = `_tot_words'
    return scalar N_placed    = `_tot_placed'
    return scalar maxfontsize = `_maxfs_all'
    return scalar java        = `_jpath'
    return scalar N_obs       = `_nuse'
    return scalar N_phrases   = `_nphr'
    if `"`_savfile'"' != "" return local saving `"`_savfile'"'
    if `"`_img'"' != "" return local image `"`_imglist'"'
    return scalar online      = `_online'
    return scalar outline     = `_ol_any'
    return scalar toolbar     = `_toolbar'
    if "`by'" != "" return scalar N_groups = `_ngood'
    return local  shape `"`shape'"'
    return local  savefile `"`savefile'"'
end


version 17.0
mata:

// ── Text ─────────────────────────────────────────────────────────────────────

// Split every row of varname into words and replace the dataset with one
// word per row in a str# variable called word. tokeninit's third argument
// ("") switches off quote-grouping, so a stray " cannot glue words together.
void cg_tokenize(string scalar varname)
{
    string colvector  rows
    string rowvector  toks
    transmorphic scalar t
    real scalar       n, maxlen

    rows = st_sdata(., varname)
    t = tokeninit(" " + char(9) + char(10) + char(13), "", "")
    tokenset(t, invtokens(rows'))
    toks = tokengetall(t)
    n = cols(toks)

    stata("drop _all")
    if (n == 0) return

    maxlen = max(strlen(toks))
    if (maxlen > 2045) maxlen = 2045
    st_addobs(n)
    (void) st_addvar("str" + strofreal(maxlen), "word")
    st_sstore(., "word", toks')
}

// Flag rows whose word is in the stopword list held in local swlocal.
// Comparison is case-insensitive. Plain lookup, so stopwords containing
// characters like . or + are matched literally.
void cg_mark_stopwords(string scalar swlocal, string scalar flagvar)
{
    string rowvector  sw
    string colvector  w
    transmorphic scalar A
    real colvector    flag
    real scalar       i

    sw = tokens(ustrlower(st_local(swlocal)))
    A  = asarray_create()
    for (i = 1; i <= cols(sw); i++) asarray(A, sw[i], 1)

    w    = ustrlower(st_sdata(., "word"))
    flag = J(rows(w), 1, 0)
    for (i = 1; i <= rows(w); i++) flag[i] = asarray_contains(A, w[i])
    st_store(., flagvar, flag)
}

// Escape the five characters that are special in HTML.
string scalar cg_html(string scalar s)
{
    s = subinstr(s, "&", "&amp;")
    s = subinstr(s, "<", "&lt;")
    s = subinstr(s, ">", "&gt;")
    s = subinstr(s, char(34), "&quot;")
    s = subinstr(s, char(39), "&#39;")
    return(s)
}

// Read the title from local inlocal, drop surrounding double quotes,
// escape it for HTML and store it in local outlocal.
void cg_title_html(string scalar inlocal, string scalar outlocal)
{
    string scalar s
    real scalar   L

    s = strtrim(st_local(inlocal))
    L = strlen(s)
    if (L >= 2) {
        if (substr(s, 1, 1) == char(34) & substr(s, L, 1) == char(34)) {
            s = substr(s, 2, L - 2)
        }
    }
    st_local(outlocal, cg_html(s))
}

// ── Layout ───────────────────────────────────────────────────────────────────

// Place words (already sorted largest first) on a W x H canvas.
//   rotmode "none"   all horizontal
//           "90"     alternate, starting horizontal for the biggest word
//           "random" 60% horizontal, fixed seed so results repeat
// If a word does not fit in its preferred orientation, the other one is
// tried (unless rotmode is "none").
// Candidate positions follow an Archimedean spiral (radius grows with the
// angle) out from the centre; each is tested against every placed box.
// Stores rotation, box top-left (px, py), text origin (tx, ty), placed.
void cg_layout(real scalar W, real scalar H, real scalar m, string scalar rotmode)
{
    real colvector ix, iy, iw, ih, pref, rot, px, py, tx, ty, placed
    real colvector X1, Y1, X2, Y2
    real scalar    n, i, k, ntry, o, bw, bh, t, r, rmax, x0, y0
    real scalar    cx, cy, np, hit, seed, done, asp

    n  = st_nobs()
    ix = st_data(., "ink_x")
    iy = st_data(., "ink_y")
    iw = st_data(., "ink_w")
    ih = st_data(., "ink_h")

    pref = J(n, 1, 0)
    if (rotmode == "90") {
        for (i = 1; i <= n; i++) pref[i] = (mod(i, 2) == 0 ? 90 : 0)
    }
    else if (rotmode == "random") {
        // Park-Miller generator: deterministic and leaves Stata's own
        // random-number state untouched
        seed = 42
        for (i = 1; i <= n; i++) {
            seed = mod(16807 * seed, 2147483647)
            pref[i] = (seed / 2147483647 < 0.6 ? 0 : 90)
        }
    }

    rot = J(n, 1, 0);  px = J(n, 1, .);  py = J(n, 1, .)
    tx  = J(n, 1, .);  ty = J(n, 1, .);  placed = J(n, 1, 0)
    X1 = J(n, 1, .);   Y1 = J(n, 1, .);  X2 = J(n, 1, .);  Y2 = J(n, 1, .)

    // The spiral is stretched to the canvas shape (as in Python's
    // word_cloud) so wide canvases fill sideways too
    cx   = W / 2
    cy   = H / 2
    asp  = W / H
    rmax = sqrt((W / (2 * asp))^2 + (H / 2)^2)
    np   = 0
    ntry = (rotmode == "none" ? 1 : 2)

    for (i = 1; i <= n; i++) {
        done = 0
        for (k = 1; k <= ntry & !done; k++) {
            o  = (k == 1 ? pref[i] : 90 - pref[i])
            bw = (o == 0 ? iw[i] : ih[i]) + m
            bh = (o == 0 ? ih[i] : iw[i]) + m
            if (bw > W | bh > H) continue

            t = 0
            while (!done) {
                r = t
                if (r > rmax) break
                x0 = cx + asp * r * cos(t) - bw / 2
                y0 = cy + r * sin(t) - bh / 2
                if (x0 >= 0 & y0 >= 0 & x0 + bw <= W & y0 + bh <= H) {
                    hit = 0
                    if (np > 0) {
                        hit = any((x0 :< X2[|1 \ np|]) :& (x0 + bw :> X1[|1 \ np|]) :& (y0 :< Y2[|1 \ np|]) :& (y0 + bh :> Y1[|1 \ np|]))
                    }
                    if (!hit) {
                        np = np + 1
                        X1[np] = x0;  Y1[np] = y0;  X2[np] = x0 + bw;  Y2[np] = y0 + bh
                        px[i] = x0;  py[i] = y0;  rot[i] = o;  placed[i] = 1
                        // Text origin so that the ink sits centred in the box.
                        // For 90 degrees the text is turned clockwise about
                        // its origin, so ink x-offsets become y-offsets.
                        if (o == 0) {
                            tx[i] = x0 + m / 2 - ix[i]
                            ty[i] = y0 + m / 2 - iy[i]
                        }
                        else {
                            tx[i] = x0 + m / 2 + iy[i] + ih[i]
                            ty[i] = y0 + m / 2 - ix[i]
                        }
                        done = 1
                    }
                }
                // Advance about 2 pixels along the spiral each step
                t = t + (r < 4 ? 0.5 : 2 / (max((asp, 1)) * r))
            }
        }
    }

    st_store(., "rotation", rot)
    st_store(., "px", px)
    st_store(., "py", py)
    st_store(., "tx", tx)
    st_store(., "ty", ty)
    st_store(., "placed", placed)
}

// Append one SVG <text> element per word to the HTML file.
// All lines are built in memory before the file is opened, so an error while
// formatting can never leave the file open (and locked on Windows).
// Returns 0 on success, otherwise a negative file error code.
real scalar cg_write_words(string scalar fname)
{
    string colvector w, col, lines, nt
    real colvector   fr, fs, tx, ty, rot, ck
    real scalar      fh, i
    string scalar    tr, ew, tl
    real colvector   adv

    w   = st_sdata(., "word")
    nt  = (_st_varindex("note") < .) ? st_sdata(., "note") : J(rows(w), 1, "")
    ck  = (_st_varindex("ccat") < .) ? st_data(., "ccat") : J(rows(w), 1, .z)
    // exact width of each word from the Java engine (absent in the fallback path)
    adv = (st_varindex("adv") < .) ? st_data(., "adv") : J(rows(st_sdata(., "word")), 1, 0)
    col = st_sdata(., "color")
    fr  = st_data(., "freq")
    fs  = st_data(., "fontsize")
    tx  = st_data(., "tx")
    ty  = st_data(., "ty")
    rot = st_data(., "rotation")

    lines = J(rows(w), 1, "")
    for (i = 1; i <= rows(w); i++) {
        tr = "translate(" + strtrim(strofreal(tx[i], "%12.1f")) + "," + strtrim(strofreal(ty[i], "%12.1f")) + ")"
        if (rot[i] != 0) tr = tr + " rotate(" + strofreal(rot[i]) + ")"
        ew = cg_html(w[i])
        lines[i] = "<text class='w' transform='" + tr + "'"
        lines[i] = lines[i] + " font-size='" + strtrim(strofreal(fs[i], "%12.0f")) + "' fill='" + cg_html(col[i]) + "'"
        // fix the word's width so another version of the font cannot change it
        if (adv[i] > 0) {
            tl = strtrim(strofreal(adv[i], "%12.1f"))
            lines[i] = lines[i] + " textLength='" + tl + "' lengthAdjust='spacingAndGlyphs'"
        }
        lines[i] = lines[i] + " data-word='" + ew + "' data-count='" + cg_num(fr[i]) + "'"
        if (nt[i] != "") lines[i] = lines[i] + " data-note='" + cg_html(nt[i]) + "'"
        if (ck[i] != .z) lines[i] = lines[i] + " data-cat='" + (missing(ck[i]) ? "0" : strofreal(ck[i])) + "'"
        lines[i] = lines[i] + ">" + ew + "</text>"
    }

    fh = _fopen(fname, "a")
    if (fh < 0) return(fh)
    for (i = 1; i <= rows(lines); i++) fput(fh, lines[i])
    fclose(fh)
    return(0)
}

// Append the words of the current frame as exact letter outlines: one
// <g class='w'> per word with an invisible box (for hovering) and the path.
// Path data holds only m l q c z, digits, spaces, dots and minus signs.
real scalar cg_write_paths(string scalar fname)
{
    string colvector w, col, pth, lines, nt
    real colvector   fr, bx, by, bw, bh, ck
    real scalar      fh, i
    string scalar    box

    w   = st_sdata(., "word")
    col = st_sdata(., "color")
    pth = st_sdata(., "path")
    nt  = (_st_varindex("note") < .) ? st_sdata(., "note") : J(rows(w), 1, "")
    // category of each word (colorby() with categories), for the clickable legend
    ck  = (_st_varindex("ccat") < .) ? st_data(., "ccat") : J(rows(w), 1, .z)
    fr  = st_data(., "freq")
    bx  = st_data(., "bx")
    by  = st_data(., "by")
    bw  = st_data(., "bw")
    bh  = st_data(., "bh")

    lines = J(rows(w), 1, "")
    for (i = 1; i <= rows(w); i++) {
        box = "x='" + strtrim(strofreal(bx[i], "%12.1f")) + "' y='" + strtrim(strofreal(by[i], "%12.1f"))
        box = box + "' width='" + strtrim(strofreal(bw[i], "%12.1f")) + "' height='" + strtrim(strofreal(bh[i], "%12.1f")) + "'"
        lines[i] = "<g class='w' fill='" + cg_html(col[i]) + "' data-word='" + cg_html(w[i])
        lines[i] = lines[i] + "' data-count='" + cg_num(fr[i]) + "'"
        if (nt[i] != "") lines[i] = lines[i] + " data-note='" + cg_html(nt[i]) + "'"
        if (ck[i] != .z) lines[i] = lines[i] + " data-cat='" + (missing(ck[i]) ? "0" : strofreal(ck[i])) + "'"
        lines[i] = lines[i] + ">"
        lines[i] = lines[i] + "<rect class='hit' " + box + " fill='transparent'/><path d='" + pth[i] + "'/></g>"
    }

    fh = _fopen(fname, "a")
    if (fh < 0) return(fh)
    for (i = 1; i <= rows(lines); i++) fput(fh, lines[i])
    fclose(fh)
    return(0)
}

// A count for display: whole numbers as they are, otherwise up to 2 decimals
string scalar cg_num(real scalar x)
{
    string scalar s

    if (x == floor(x)) return(strtrim(strofreal(x, "%20.0f")))
    s = strtrim(strofreal(x, "%20.2f"))
    if (substr(s, -1, 1) == "0") s = substr(s, 1, strlen(s) - 1)
    return(s)
}

// Text shown in the Results window with braces made harmless for SMCL
string scalar cg_smcl(string scalar s)
{
    s = subinstr(s, "{", "{c -(}", .)
    s = subinstr(s, "}", "{c )-}", .)
    return(s)
}

// List the joined phrases (frame fr: phrase, count, added), at most k of
// them, and put their number in the local _nphr.
void cg_phrase_report(string scalar fr, real scalar k)
{
    string scalar    cur, line
    string colvector p
    real colvector   c, a
    real scalar      n, i

    cur = st_framecurrent()
    st_framecurrent(fr)
    n = st_nobs()
    if (n > 0) {
        p = st_sdata(., "phrase")
        c = st_data(., "count")
        a = st_data(., "added")
    }
    st_framecurrent(cur)
    st_local("_nphr", strofreal(n))
    if (n == 0) {
        printf("{txt}calligram: no two-word phrases passed the tests; a lower phrasestrength() relaxes them.\n")
        return
    }
    line = ""
    for (i = 1; i <= min((n, k)); i++) {
        if (i > 1) line = line + ", "
        line = line + cg_smcl(p[i]) + " (" + cg_num(c[i])
        if (a[i]) line = line + ", added"
        line = line + ")"
    }
    if (n > k) line = line + ", ... and " + strofreal(n - k) + " more (all of them with saving())"
    printf("{txt}calligram: %s two-word phrase%s joined: %s\n", strofreal(n), (n == 1 ? "" : "s"), line)
}

// 1 if the folder part of a file path exists (or there is none), else 0
real scalar cg_dir_exists(string scalar fname)
{
    string scalar d, f

    pathsplit(fname, d, f)
    if (d == "") return(1)
    return(direxists(d))
}

// ── Colour ───────────────────────────────────────────────────────────────────

// Common CSS colour names -> "rrggbb" ("" if unknown)
string scalar cg_named_hex(string scalar name)
{
    string matrix L
    real scalar   k

    L = J(0, 2, "")
    L = L \ ("black", "000000")    \ ("white", "ffffff")    \ ("red", "ff0000")
    L = L \ ("lime", "00ff00")     \ ("blue", "0000ff")     \ ("yellow", "ffff00")
    L = L \ ("cyan", "00ffff")     \ ("aqua", "00ffff")     \ ("magenta", "ff00ff")
    L = L \ ("fuchsia", "ff00ff")  \ ("silver", "c0c0c0")   \ ("gray", "808080")
    L = L \ ("grey", "808080")     \ ("maroon", "800000")   \ ("olive", "808000")
    L = L \ ("green", "008000")    \ ("purple", "800080")   \ ("teal", "008080")
    L = L \ ("navy", "000080")     \ ("orange", "ffa500")   \ ("coral", "ff7f50")
    L = L \ ("tomato", "ff6347")   \ ("gold", "ffd700")     \ ("pink", "ffc0cb")
    L = L \ ("salmon", "fa8072")   \ ("violet", "ee82ee")   \ ("indigo", "4b0082")
    L = L \ ("crimson", "dc143c")  \ ("skyblue", "87ceeb")  \ ("steelblue", "4682b4")
    L = L \ ("turquoise", "40e0d0") \ ("sienna", "a0522d")  \ ("tan", "d2b48c")
    L = L \ ("khaki", "f0e68c")    \ ("lavender", "e6e6fa") \ ("plum", "dda0dd")
    L = L \ ("orchid", "da70d6")   \ ("peru", "cd853f")     \ ("darkgreen", "006400")
    L = L \ ("darkblue", "00008b") \ ("darkred", "8b0000")  \ ("firebrick", "b22222")
    L = L \ ("whitesmoke", "f5f5f5") \ ("ivory", "fffff0") \ ("beige", "f5f5dc")
    L = L \ ("linen", "faf0e6")   \ ("snow", "fffafa")     \ ("lightgray", "d3d3d3")
    L = L \ ("lightgrey", "d3d3d3") \ ("gainsboro", "dcdcdc") \ ("lightyellow", "ffffe0")

    name = strlower(strtrim(name))
    for (k = 1; k <= rows(L); k++) {
        if (L[k, 1] == name) return(L[k, 2])
    }
    return("")
}

// "#rrggbb", "#rgb" or a colour name -> (r, g, b) in [0, 1]; missing if invalid
real rowvector cg_css_rgb(string scalar css)
{
    string scalar s, hexd
    real rowvector v
    real scalar   k, d

    s = strlower(strtrim(css))
    if (substr(s, 1, 1) == "#") s = substr(s, 2, .)
    else s = cg_named_hex(s)

    if (strlen(s) == 3) {
        s = substr(s,1,1) + substr(s,1,1) + substr(s,2,1) + substr(s,2,1) + substr(s,3,1) + substr(s,3,1)
    }
    if (strlen(s) != 6) return((., ., .))

    hexd = "0123456789abcdef"
    v = J(1, 6, .)
    for (k = 1; k <= 6; k++) {
        d = strpos(hexd, substr(s, k, 1)) - 1
        if (d < 0) return((., ., .))
        v[k] = d
    }
    return(((16*v[1] + v[2]), (16*v[3] + v[4]), (16*v[5] + v[6])) / 255)
}

real scalar cg_css_valid(string scalar css)
{
    real rowvector v

    v = cg_css_rgb(css)
    return(!missing(v[1]))
}

// (r, g, b) in [0,1] -> (h in degrees, s, l)
real rowvector cg_rgb_hsl(real rowvector c)
{
    real scalar r, g, b, mx, mn, d, h, s, l

    r = c[1];  g = c[2];  b = c[3]
    mx = max(c);  mn = min(c);  d = mx - mn
    l = (mx + mn) / 2
    if (d == 0) return((0, 0, l))
    s = d / (1 - abs(2 * l - 1))
    if      (mx == r) h = 60 * mod((g - b) / d, 6)
    else if (mx == g) h = 60 * ((b - r) / d + 2)
    else              h = 60 * ((r - g) / d + 4)
    return((h, s, l))
}

// (h, s, l) -> (r, g, b) in [0,1]
real rowvector cg_hsl_rgb(real rowvector c)
{
    real scalar h, s, l, ch, hp, x, m, r, g, b

    h = c[1];  s = c[2];  l = c[3]
    ch = (1 - abs(2 * l - 1)) * s
    hp = h / 60
    x  = ch * (1 - abs(mod(hp, 2) - 1))
    // Each branch sets (r, g, b) for one 60-degree sector of the hue circle
    r = 0
    g = 0
    b = 0
    if (hp < 1) {
        r = ch
        g = x
    }
    else if (hp < 2) {
        r = x
        g = ch
    }
    else if (hp < 3) {
        g = ch
        b = x
    }
    else if (hp < 4) {
        g = x
        b = ch
    }
    else if (hp < 5) {
        r = x
        b = ch
    }
    else {
        r = ch
        b = x
    }
    m = l - ch / 2
    return((r + m, g + m, b + m))
}

// value in [0,1] -> two hex digits
string scalar cg_hex2(real scalar v)
{
    string scalar hexd
    real scalar   iv

    hexd = "0123456789abcdef"
    iv = round(v * 255)
    if (iv < 0)   iv = 0
    if (iv > 255) iv = 255
    return(substr(hexd, floor(iv / 16) + 1, 1) + substr(hexd, mod(iv, 16) + 1, 1))
}

// Fill string variable colorvar with an HSL gradient from c1 (row 1, most
// frequent word) to c2 (last row). Hue takes the shorter way round the
// colour wheel; a grey endpoint borrows the other end's hue so the blend
// does not detour through unrelated colours.
void cg_hsl_gradient(string scalar c1, string scalar c2, string scalar colorvar)
{
    real rowvector a, b, c
    real scalar    n, i, t, dh
    string colvector out

    a = cg_rgb_hsl(cg_css_rgb(c1))
    b = cg_rgb_hsl(cg_css_rgb(c2))
    if (a[2] == 0) a[1] = b[1]
    if (b[2] == 0) b[1] = a[1]
    dh = b[1] - a[1]
    if (dh >  180) dh = dh - 360
    if (dh < -180) dh = dh + 360

    n = st_nobs()
    out = J(n, 1, "")
    for (i = 1; i <= n; i++) {
        t = (n == 1 ? 0 : (i - 1) / (n - 1))
        c = cg_hsl_rgb((mod(a[1] + t * dh, 360), a[2] + t * (b[2] - a[2]), a[3] + t * (b[3] - a[3])))
        out[i] = "#" + cg_hex2(c[1]) + cg_hex2(c[2]) + cg_hex2(c[3])
    }
    st_sstore(., colorvar, out)
}

// A colour at position t (0..1) between c1 and c2, interpolated in HSL
// (the same way as the rank gradient), as #rrggbb
string scalar cg_grad_at(string scalar c1, string scalar c2, real scalar t)
{
    real rowvector a, b, c
    real scalar    dh

    a = cg_rgb_hsl(cg_css_rgb(c1))
    b = cg_rgb_hsl(cg_css_rgb(c2))
    if (a[2] == 0) a[1] = b[1]
    if (b[2] == 0) b[1] = a[1]
    dh = b[1] - a[1]
    if (dh >  180) dh = dh - 360
    if (dh < -180) dh = dh + 360
    c = cg_hsl_rgb((mod(a[1] + t * dh, 360), a[2] + t * (b[2] - a[2]), a[3] + t * (b[3] - a[3])))
    return("#" + cg_hex2(c[1]) + cg_hex2(c[2]) + cg_hex2(c[3]))
}

// n evenly spaced gradient colours, comma separated (legend bar, category colours)
string scalar cg_grad_stops(string scalar c1, string scalar c2, real scalar n)
{
    string scalar s
    real scalar   i

    s = ""
    for (i = 1; i <= n; i++) s = s + (i > 1 ? "," : "") + cg_grad_at(c1, c2, (n == 1 ? 0 : (i - 1) / (n - 1)))
    return(s)
}

// colorby() with a number: each word's average value placed on the gradient
// from the lowest to the highest average among the placed words; no value: grey
void cg_color_numeric(string scalar c1, string scalar c2, real scalar lo, real scalar hi, string scalar lab)
{
    real colvector   v
    string colvector col, note
    real scalar      i, t

    v = st_data(., "cval")
    col = J(rows(v), 1, "")
    note = J(rows(v), 1, "")
    for (i = 1; i <= rows(v); i++) {
        if (missing(v[i])) {
            col[i] = "#9e9e9e"
            note[i] = lab + ": no value"
            continue
        }
        t = (hi > lo ? (v[i] - lo) / (hi - lo) : 0.5)
        col[i] = cg_grad_at(c1, c2, t)
        note[i] = lab + ": " + strtrim(strofreal(v[i], "%9.3g")) + " on average"
    }
    st_sstore(., "color", col)
    st_sstore(., "note", note)
}

// colorvar() and colorimage(): colours given per word; returns how many placed
// words have no usable colour (drawn in grey)
real scalar cg_color_given()
{
    string colvector c, col
    real colvector   pl
    real scalar      i, bad

    pl = st_data(., "placed")
    c = (_st_varindex("ccolor") < .) ? st_sdata(., "ccolor") : J(rows(pl), 1, "")
    col = J(rows(c), 1, "")
    bad = 0
    for (i = 1; i <= rows(c); i++) {
        if (strtrim(c[i]) != "" & cg_css_valid(strtrim(c[i]))) col[i] = strtrim(c[i])
        else {
            col[i] = "#9e9e9e"
            if (pl[i] == 1) bad++
        }
    }
    st_sstore(., "color", col)
    return(bad)
}

// Percent-encode characters that javacall's args() would split or misread
string scalar cg_enc(string scalar s)
{
    s = subinstr(s, "%", "%25")
    s = subinstr(s, " ", "%20")
    s = subinstr(s, "(", "%28")
    s = subinstr(s, ")", "%29")
    return(s)
}

// 1 if a CSS colour is light (so text on it should be dark), else 0.
// Unknown colours are treated as dark.
real scalar cg_is_light(string scalar css)
{
    string scalar   s
    string rowvector t
    real rowvector  v

    s = strlower(strtrim(css))
    if (substr(s, 1, 3) == "rgb" | substr(s, 1, 3) == "hsl") {
        t = tokens(subinstr(subinstr(subinstr(substr(s, strpos(s, "(") + 1, .), ")", ""), ",", " "), "%", ""))
        if (cols(t) < 3) return(0)
        if (substr(s, 1, 3) == "hsl") return(strtoreal(t[3]) > 60)
        v = (strtoreal(t[1]), strtoreal(t[2]), strtoreal(t[3])) / 255
    }
    else {
        v = cg_css_rgb(s)
    }
    if (missing(v[1])) return(0)
    return(0.2126 * v[1] + 0.7152 * v[2] + 0.0722 * v[3] > 0.5)
}

// Fallback font sizes (same rule as the Java engine, without shrinking):
// size = round((rs * f/f_prev + (1 - rs)) * size_prev), f relative to the top word
void cg_rs_sizes(real scalar rs, real scalar start, real scalar minf)
{
    real colvector f, out
    real scalar    n, i, last, size, fi

    f    = st_data(., "freq")
    n    = rows(f)
    out  = J(n, 1, .)
    last = 1
    size = start
    for (i = 1; i <= n; i++) {
        fi = f[i] / f[1]
        if (rs != 0) size = round((rs * (fi / last) + (1 - rs)) * size)
        if (size < minf) size = minf
        out[i] = size
        last = fi
    }
    st_store(., "fontsize", out)
}

// Append the outline <path> (data written by Java to pathfile) to the HTML.
// Returns 0 on success (or if there is no outline), else a file error code.
real scalar cg_write_outline(string scalar fname, string scalar pathfile, string scalar color, real scalar w, real scalar op, real scalar isdef)
{
    string scalar d, line
    real scalar   fh

    if (!fileexists(pathfile)) return(0)
    // read the file exactly as it is: cat() splits lines longer than 32,768
    // characters, and joining the pieces again breaks numbers in long paths
    d = strtrim(cg_read_file(pathfile))
    if (d == "") return(0)
    line = "<path class='outline' data-default='" + strofreal(isdef) + "' d='" + d + "' fill='none' fill-rule='evenodd'"
    line = line + " stroke='" + cg_html(color) + "' stroke-width='" + strofreal(w) + "'"
    line = line + " stroke-opacity='" + strofreal(op) + "' stroke-linejoin='round'/>"
    fh = _fopen(fname, "a")
    if (fh < 0) return(fh)
    fwrite(fh, line + char(10))
    fclose(fh)
    return(0)
}

// The whole content of a file, byte for byte (no line splitting)
string scalar cg_read_file(string scalar src)
{
    string scalar d, chunk
    real scalar   fi

    fi = _fopen(src, "r")
    if (fi < 0) return("")
    d = ""
    while ((chunk = fread(fi, 1000000)) != J(0, 0, "")) d = d + chunk
    fclose(fi)
    return(d)
}

// Copy a text file (the interface CSS or JavaScript) into the HTML file.
// Returns 0 on success, else a file error code.
real scalar cg_append_file(string scalar fname, string scalar src)
{
    string scalar d
    real scalar   fh

    if (!fileexists(src)) return(-601)
    d = cg_read_file(src)
    if (d != "" & substr(d, -1, 1) != char(10)) d = d + char(10)
    fh = _fopen(fname, "a")
    if (fh < 0) return(fh)
    fwrite(fh, d)
    fclose(fh)
    return(0)
}

end
