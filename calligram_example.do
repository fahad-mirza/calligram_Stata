* calligram_example.do  —  examples and self-checks for calligram v1.0.10
* Run the whole file. Every check uses -assert-, so it stops at the first
* problem; reaching the final message means everything passed.
* HTML files are written to the current working directory.

version 17
clear all
set more off

* ---------------------------------------------------------------------------
* Sample data: open-ended survey responses
* (includes contractions, accented words, numbers and odd punctuation on
*  purpose, to exercise the text cleaning)
* ---------------------------------------------------------------------------
input str200 response
"The product quality is excellent and the service was outstanding"
"Great quality but delivery was slow and customer service needs improvement"
"Amazing experience with the product and very helpful support team"
"Poor quality product arrived damaged and customer service was unhelpful"
"Outstanding quality and excellent delivery speed highly recommend"
"The service team was helpful but the product quality could be better"
"Excellent customer experience product quality exceeded my expectations"
"Good quality product but packaging was damaged during delivery"
"Highly recommend excellent quality and very fast delivery service"
"The support team was amazing and the product quality is outstanding"
"Product quality is good but customer service response was very slow"
"Great delivery service but product quality did not meet expectations"
"It doesn't work and the app isn't helpful, couldn't log in during 2024"
"Doesn't matter: the café service was great, really great"
"El servicio del café fue rápido; año 2024 excelente servicio"
"Service <fast> & friendly, 'quoted' words"
end
* add a double-quoted phrase (input cannot take embedded double quotes)
replace response = response + " and " + char(34) + "double quoted" + char(34) + " words" in 16

* 1. Basic run ---------------------------------------------------------------
calligram, textvar(response) minfreq(1) savefile(cg_basic.html)
return list
assert r(N_placed) > 0
assert r(N_placed) <= r(N_words)
if r(java) == 0 {
    di as error "NOTE: the Java layout engine was not used (calligram.jar missing or failed)."
    di as error "      The cloud still works, but with the simpler layout and no shapes."
}

* 2. Contractions: "doesn't" must become the stopword "doesnt", not "doesn"
preserve
    calligram, textvar(response) minfreq(1) minlength(1) maxwords(500) savefile(cg_check.html)
restore
mata: st_local("html", invtokens(cat("cg_check.html")'))
foreach bad in "data-word='doesn'" "data-word='isn'" "data-word='couldn'" "data-word='t'" "data-word='2024'" {
    assert strpos(`"`html'"', `"`bad'"') == 0
}
* Accented words survive cleaning
assert strpos(`"`html'"', "data-word='café'") > 0
assert strpos(`"`html'"', "data-word='rápido'") > 0

* 3. HTML escaping with noclean: < > & and quotes must not break the page
calligram, textvar(response) minfreq(1) noclean nostopwords maxwords(500) savefile(cg_noclean.html)
mata: st_local("html", invtokens(cat("cg_noclean.html")'))
assert strpos(`"`html'"', "data-word='<fast>'") == 0
assert strpos(`"`html'"', "&lt;fast&gt;") > 0

* 4. Rotation ----------------------------------------------------------------
calligram, textvar(response) minfreq(1) rotate(90)     savefile(cg_rot90.html)
calligram, textvar(response) minfreq(1) rotate(random) savefile(cg_rotrandom.html)
mata: st_local("html", invtokens(cat("cg_rotrandom.html")'))
* (exact letter outlines have the turn built in; as text, the page says rotate(90))
calligram, textvar(response) minfreq(1) rotate(90) online savefile(cg_rot90_text.html)
mata: st_local("html", invtokens(cat("cg_rot90_text.html")'))
if r(java) == 1 assert strpos(`"`html'"', "rotate(90)") > 0

* Same data and options give the same cloud (no randomness leaks in).
* Only the word elements are compared: the page also stores its own file
* name (used to name saved images), which differs between the two files.
calligram, textvar(response) minfreq(1) rotate(random) savefile(cg_rotrandom2.html)
mata: wa = cat("cg_rotrandom.html"); wb = cat("cg_rotrandom2.html")
mata: st_local("same", strofreal(select(wa, strpos(wa, "class='w'")) == select(wb, strpos(wb, "class='w'"))))
assert `same' == 1

* 5. Fonts -------------------------------------------------------------------
calligram, textvar(response) minfreq(1) font(Verdana)         savefile(cg_verdana.html)
calligram, textvar(response) minfreq(1) font(Times New Roman) savefile(cg_times.html)

* 6. Gradient ----------------------------------------------------------------
calligram, textvar(response) minfreq(1) gradient(#ff6b6b #4ecdc4) savefile(cg_grad1.html)
mata: st_local("html", invtokens(cat("cg_grad1.html")'))
assert strpos(`"`html'"', "fill='#ff6b6b'") > 0
calligram, textvar(response) minfreq(1) gradient(navy gold) bgcolor(white) savefile(cg_grad2.html)
* On a white background the default title must be dark, not white
mata: st_local("html", invtokens(cat("cg_grad2.html")'))
* (the title uses the page's text colour, stored as the theme variable --ink)
assert strpos(`"`html'"', "--ink:#222222") > 0
calligram, textvar(response) minfreq(1) gradient(#f00 #00f) savefile(cg_grad3.html)

* 7. Errors that should be caught cleanly (return code 198) -----------------
capture calligram, textvar(response) gradient(red blue) palette(Set1)
assert _rc == 198
capture calligram, textvar(response) gradient(red)
assert _rc == 198
capture calligram, textvar(response) gradient(notacolour blue)
assert _rc == 198
capture calligram, textvar(response) rotate(45)
assert _rc == 198
capture calligram, textvar(response) bgcolor(#zz)
assert _rc == 198

* 8. Abbreviations: minfr() = minfreq(), minfo() = minfontsize() ------------
calligram, textvar(response) minfr(1) minfo(12) maxf(60) savefile(cg_abbrev.html)

* 9. Title, background and export button ------------------------------------
calligram, textvar(response) minfreq(1)                         ///
    title("Customer Feedback & Ratings", color(#ff6b6b) size(2em)) ///
    bgcolor(white) export(png) savefile(cg_export.html)
mata: st_local("html", invtokens(cat("cg_export.html")'))
assert strpos(`"`html'"', "Customer Feedback &amp; Ratings") > 0
* a comma inside the title stays part of it
calligram, textvar(response) minfreq(1) title("Ratings, by region") savefile(cg_title.html)
mata: st_local("html", invtokens(cat("cg_title.html")'))
assert strpos(`"`html'"', ">Ratings, by region</h1>") > 0
* saving is done by the toolbar's save buttons
if r(java) == 1 assert strpos(`"`html'"', "window.wcSave") > 0

* 10. Shapes -----------------------------------------------------------------
foreach s in rectangle ellipse circle square cloud heart diamond triangle star {
    calligram, textvar(response) minfreq(1) shape(`s') savefile(cg_shape_`s'.html)
    assert r(N_placed) > 0
    assert "`r(shape)'" == "`s'"
}
* Shapes look best on a canvas with matching proportions
calligram, textvar(response) minfreq(1) shape(circle) width(600) height(600) savefile(cg_shape_circle_square_canvas.html)
calligram, textvar(response) minfreq(1) shape(heart) rotate(random) width(600) height(560) savefile(cg_shape_heart_rotated.html)

* A different seed gives a different arrangement; the same seed the same one
calligram, textvar(response) minfreq(1) seed(7) savefile(cg_seed7.html)
mata: wa = cat("cg_basic.html"); wb = cat("cg_seed7.html")
mata: st_local("same", strofreal(select(wa, strpos(wa, "class='w'")) == select(wb, strpos(wb, "class='w'"))))
assert `same' == 0

* 11. Image mask: draw a black disc with Stata graphics and use it as a mask
capture noisily {
    twoway (function y =  sqrt(1 - x^2), range(-1 1) recast(area) color(black) base(0))   ///
           (function y = -sqrt(1 - x^2), range(-1 1) recast(area) color(black) base(0)),  ///
           xscale(off) yscale(off) legend(off) aspectratio(1)                            ///
           graphregion(color(white) margin(zero)) plotregion(color(white) margin(zero)) ///
           name(cg_mask, replace)
    graph export cg_mask_test.png, name(cg_mask) width(500) replace
}
if _rc == 0 {
    graph drop cg_mask
    calligram, textvar(response) minfreq(1) mask(cg_mask_test.png) bgcolor(white) savefile(cg_mask.html)
    assert r(N_placed) > 0
}
else di as text "(skipped the mask test: could not export a PNG on this system)"

* 12. Outlines and window fitting ---------------------------------------------
calligram, textvar(response) minfreq(1) shape(star) outline savefile(cg_outline_star.html)
assert r(outline) == 1
mata: st_local("html", invtokens(cat("cg_outline_star.html")'))
assert strpos(`"`html'"', "<path class='outline' data-default='1' d='M") > 0
* by default the cloud is scaled to the window (recorded as fixed:0)
if r(java) == 1 assert strpos(`"`html'"', "fixed:0") > 0
calligram, textvar(response) minfreq(1) shape(cloud) outlinecolor(#4ecdc4) outlinewidth(4) savefile(cg_outline_cloud.html)
assert r(outline) == 1
mata: st_local("html", invtokens(cat("cg_outline_cloud.html")'))
assert strpos(`"`html'"', "stroke='#4ecdc4' stroke-width='4'") > 0
capture confirm file cg_mask_test.png
if _rc == 0 {
    calligram, textvar(response) minfreq(1) mask(cg_mask_test.png) outline bgcolor(white) savefile(cg_outline_mask.html)
    assert r(outline) == 1
}
* fixed: no window fitting
calligram, textvar(response) minfreq(1) fixed savefile(cg_fixed.html)
mata: st_local("html", invtokens(cat("cg_fixed.html")'))
if r(java) == 1 assert strpos(`"`html'"', "fixed:1") > 0
assert r(outline) == 0
capture calligram, textvar(response) outlinewidth(50)
assert _rc == 198
capture calligram, textvar(response) outlinecolor(#zz)
assert _rc == 198

* 13. Side panel (search, slider, top words, zoom, themes, palettes, saving) -
calligram, textvar(response) minfreq(1) savefile(cg_toolbar.html)
if r(java) == 1 {
    assert r(toolbar) == 1
    mata: st_local("html", invtokens(cat("cg_toolbar.html")'))
    assert strpos(`"`html'"', "<aside id='panel'") > 0
    assert strpos(`"`html'"', "window.WC_CONFIG={toolbar:1") > 0
    assert strpos(`"`html'"', "function setPalette") > 0
    * words stay hidden until the fade-in starts at first paint
    assert strpos(`"`html'"', "classList.add('wc-pre')") > 0
}
* notoolbar: a plain page (no side panel); export() then adds a single save button
calligram, textvar(response) minfreq(1) notoolbar export(png) savefile(cg_notoolbar.html)
assert r(toolbar) == 0
mata: st_local("html", invtokens(cat("cg_notoolbar.html")'))
assert strpos(`"`html'"', "<aside id='panel'") == 0
if r(java) == 1 assert strpos(`"`html'"', "id='expbtn' data-fmt='png'") > 0

* 14. by(): one cloud per group, with tabs -----------------------------------
gen str5 region = cond(_n <= 8, "North", "South")
calligram, textvar(response) minfreq(1) by(region) savefile(cg_by.html)
assert r(N_groups) == 2
mata: st_local("html", invtokens(cat("cg_by.html")'))
assert strpos(`"`html'"', "data-label='North'") > 0
assert strpos(`"`html'"', "data-label='South'") > 0
if r(java) == 1 assert strpos(`"`html'"', "<div id='tabs'></div>") > 0

* numeric by() variable with value labels (labels become the tab names)
gen byte grp = 1 + (_n > 8)
label define grpl 1 "Group A" 2 "Group B & C"
label values grp grpl
calligram, textvar(response) minfreq(1) by(grp) shape(heart) outline width(600) height(560) savefile(cg_by_labels.html)
assert r(N_groups) == 2
mata: st_local("html", invtokens(cat("cg_by_labels.html")'))
assert strpos(`"`html'"', "data-label='Group B &amp; C'") > 0

* a group with nothing but stopwords is skipped, the others still drawn
preserve
    set obs 17
    replace response = "the and of it is" in 17
    replace region = "Empty" in 17
    calligram, textvar(response) minfreq(1) by(region) savefile(cg_by_skip.html)
    assert r(N_groups) == 2
restore
drop region grp
label drop grpl

* 15. if / in, and threads() ------------------------------------------------
calligram in 1/8, textvar(response) minfreq(1) savefile(cg_in.html)
assert r(N_obs) == 8
quietly count if strpos(response, "quality")
local k = r(N)
calligram if strpos(response, "quality"), textvar(response) minfreq(1) savefile(cg_if.html)
assert r(N_obs) == `k'
* one thread or all cores: the same cloud
calligram, textvar(response) minfreq(1) rotate(random) threads(1) savefile(cg_threads1.html)
mata: wa = cat("cg_rotrandom.html"); wb = cat("cg_threads1.html")
mata: st_local("same", strofreal(select(wa, strpos(wa, "class='w'")) == select(wb, strpos(wb, "class='w'"))))
assert `same' == 1
capture calligram, textvar(response) threads(-1)
assert _rc == 198

* 16. Large text: 100,000 responses (the sample repeated 6,250 times) ---------
preserve
    quietly expand 6250
    timer clear 1
    timer on 1
    calligram, textvar(response) savefile(cg_large.html)
    local nobs = r(N_obs)
    local isjava = r(java)
    timer off 1
    quietly timer list 1
    di as result "  100,000 responses: " %6.2f r(t1) " seconds in total"
    assert `nobs' == 100000
    * every count is exactly 6,250 times the small-sample count
    mata: st_local("html", invtokens(cat("cg_large.html")'))
    assert strpos(`"`html'"', "data-word='quality' data-count='68750'") > 0
    quietly gen byte half = 1 + (mod(_n, 2) == 0)
    timer clear 2
    timer on 2
    calligram, textvar(response) by(half) savefile(cg_large_by.html)
    local ng = r(N_groups)
    timer off 2
    quietly timer list 2
    di as result "  100,000 responses in 2 groups: " %6.2f r(t2) " seconds in total"
    assert `ng' == 2
restore

* 17. Offline by default; online option; fonts ------------------------------
calligram, textvar(response) minfreq(1) savefile(cg_offline.html)
local isj = r(java)
assert r(online) == 0
mata: st_local("html", invtokens(cat("cg_offline.html")'))
if `isj' {
    * words are their exact letter outlines, so they look the same everywhere
    assert strpos(`"`html'"', "<g class='w'") > 0
    assert strpos(`"`html'"', "<text class='w'") == 0
}
* nothing is fetched from the internet
assert strpos(`"`html'"', "https://") == 0
calligram, textvar(response) minfreq(1) font(Lato) online savefile(cg_online.html)
assert r(online) == 1
mata: st_local("html", invtokens(cat("cg_online.html")'))
assert strpos(`"`html'"', "<text class='w'") > 0
assert strpos(`"`html'"', "fonts.googleapis.com/css2?family=Lato:wght@700") > 0
* each word carries its exact width, so a substitute font cannot widen it
if r(java) == 1 assert strpos(`"`html'"', "lengthAdjust='spacingAndGlyphs'") > 0
* every bundled font works offline
foreach f in Arimo Tinos Roboto "Open Sans" Lato "Noto Sans" Merriweather {
    calligram, textvar(response) minfreq(1) font(`f') savefile(cg_font.html)
    assert r(N_placed) > 0
}
* words in other scripts (drawn with a fallback font when needed)
preserve
    clear
    quietly set obs 4
    gen strL response = ""
    quietly replace response = "Ελλάδα Ελλάδα ποιότητα" in 1
    quietly replace response = "качество качество сервис" in 2
    quietly replace response = "خدمة خدمة جودة" in 3
    quietly replace response = "服务 服务 质量" in 4
    calligram, textvar(response) minfreq(1) minlength(1) savefile(cg_scripts.html)
    assert r(N_placed) >= 6
restore

* spacing(): extra clear space around words in proportion to their size
* (default 0 = densest cloud; words never overlap at any setting)
calligram, textvar(response) minfreq(1) spacing(0.08) savefile(cg_spacing08.html)
assert r(N_placed) > 0
calligram, textvar(response) minfreq(1) spacing(0.15) savefile(cg_spacing15.html)
assert r(N_placed) > 0
capture calligram, textvar(response) spacing(0.9)
assert _rc == 198

* 18. Words, phrases, languages, weights, pre-counted words, saving() --------
* hyphenated words stay whole; plurals merge with their singulars
preserve
    clear
    quietly input str120 response
    "Sci-fi fans love sci-fi; the follow-up e-mail was slow"
    "The follow-up was quick, delays and more delays"
    "One delay, many delays; companies and a company"
    end
    calligram, textvar(response) minfreq(1) savefile(cg_hyphen.html)
    mata: st_local("html", invtokens(cat("cg_hyphen.html")'))
    assert strpos(`"`html'"', "data-word='sci-fi' data-count='2'") > 0
    assert strpos(`"`html'"', "data-word='follow-up' data-count='2'") > 0
    * delays (3) + delay (1) = 4, shown in the more common form
    assert strpos(`"`html'"', "data-word='delays' data-count='4'") > 0
    assert strpos(`"`html'"', "data-word='delay'") == 0
    * companies (1) + company (1): a tie is shown as the singular
    assert strpos(`"`html'"', "data-word='company' data-count='2'") > 0
    calligram, textvar(response) minfreq(1) splithyphens noplurals savefile(cg_hyphen2.html)
    mata: st_local("html", invtokens(cat("cg_hyphen2.html")'))
    assert strpos(`"`html'"', "data-word='sci-fi'") == 0
    assert strpos(`"`html'"', "data-word='delay' data-count='1'") > 0
    * French: elided articles are split off (l'entreprise -> entreprise)
    clear
    quietly input str120 response
    "L'entreprise d'électricité et l'entreprise de transport"
    end
    calligram, textvar(response) minfreq(1) language(fr) savefile(cg_french.html)
    mata: st_local("html", invtokens(cat("cg_french.html")'))
    assert strpos(`"`html'"', "data-word='entreprise' data-count='2'") > 0
    assert strpos(`"`html'"', "data-word='électricité'") > 0
restore

* Spanish stopwords: "del" and "fue" are dropped with language(en es)
calligram, textvar(response) minfreq(1) language(en es) savefile(cg_spanish.html)
mata: st_local("html", invtokens(cat("cg_spanish.html")'))
assert strpos(`"`html'"', "data-word='del'") == 0
assert strpos(`"`html'"', "data-word='fue'") == 0
assert strpos(`"`html'"', "data-word='servicio'") > 0

* two-word phrases (opt-in): found, listed, and shown as one entry
calligram, textvar(response) minfreq(1) phrases savefile(cg_phrases.html)
assert r(N_phrases) == 2
mata: st_local("html", invtokens(cat("cg_phrases.html")'))
assert strpos(`"`html'"', "data-word='product quality' data-count='6'") > 0
assert strpos(`"`html'"', "data-word='customer service' data-count='3'") > 0
* the words keep only their other uses: customer 4 - 3 = 1
assert strpos(`"`html'"', "data-word='customer' data-count='1'") > 0
calligram, textvar(response) minfreq(1) phrases addphrases("highly recommend") ///
    dropphrases("customer service") savefile(cg_phrases2.html)
assert r(N_phrases) == 2
mata: st_local("html", invtokens(cat("cg_phrases2.html")'))
assert strpos(`"`html'"', "data-word='highly recommend' data-count='2'") > 0
assert strpos(`"`html'"', "data-word='customer service'") == 0
* without phrases nothing is joined
calligram, textvar(response) minfreq(1) savefile(cg_nophrases.html)
assert r(N_phrases) == 0

* weights: every word counts with its response's weight
gen double w = 2.5
calligram [aw=w], textvar(response) minfreq(1) savefile(cg_weights.html)
mata: st_local("html", invtokens(cat("cg_weights.html")'))
assert strpos(`"`html'"', "data-word='quality' data-count='27.5'") > 0
gen byte k = 2
calligram [fw=k], textvar(response) minfreq(1) savefile(cg_fweights.html)
mata: st_local("html", invtokens(cat("cg_fweights.html")'))
assert strpos(`"`html'"', "data-word='quality' data-count='22'") > 0
capture calligram [fw=w], textvar(response)
assert _rc == 401
drop w k

* words already counted elsewhere (wordvar + countvar)
preserve
    clear
    quietly input str40 term n
    "customer service" 40
    "quality"          25
    "quality"           5
    "delivery"         12
    "the"              99
    end
    calligram, wordvar(term) countvar(n) minfreq(1) savefile(cg_precounted.html)
    mata: st_local("html", invtokens(cat("cg_precounted.html")'))
    assert strpos(`"`html'"', "data-word='customer service' data-count='40'") > 0
    assert strpos(`"`html'"', "data-word='quality' data-count='30'") > 0
    assert strpos(`"`html'"', "data-word='the'") == 0
restore

* saving(): the words, counts, sizes, positions and colours as a dataset
calligram, textvar(response) minfreq(1) phrases saving(cg_words, replace) savefile(cg_saving.html)
assert `"`r(saving)'"' != ""
preserve
    use cg_words, clear
    confirm variable group rank word count n placed fontsize rotation x y color
    quietly count if word == "product quality" & placed == 1 & count == 6
    assert r(N) == 1
    quietly count if placed == 1 & color == ""
    assert r(N) == 0
restore
capture calligram, textvar(response) minfreq(1) saving(cg_words)
assert _rc == 602

* image(): pictures written by calligram itself (PNG, JPG, SVG)
calligram, textvar(response) minfreq(1) shape(cloud) outline image(cg_image.png, replace)
confirm file cg_image.png
calligram, textvar(response) minfreq(1) image(cg_image.svg, replace) savefile(cg_image_svg.html)
confirm file cg_image.svg
mata: st_local("svg", invtokens(cat("cg_image.svg")'))
assert strpos(`"`svg'"', "<svg") > 0 & strpos(`"`svg'"', "<path d=") > 0
calligram, textvar(response) minfreq(1) online font(Lato) image(cg_image_online.jpg, replace scale(1))
confirm file cg_image_online.jpg
capture calligram, textvar(response) minfreq(1) image(cg_image.png)
assert _rc == 602
capture calligram, textvar(response) image(cg_image.gif)
assert _rc == 198
capture calligram, textvar(response) image(cg_image.png, replace scale(20))
assert _rc == 198
gen str5 region = cond(_n <= 8, "North", "South")
calligram, textvar(response) minfreq(1) by(region) image(cg_image_by.png, replace)
confirm file cg_image_by_North.png
confirm file cg_image_by_South.png
drop region

* shapes(): areas from a Stata-format shapefile; location(): each city in the
* country containing its point; near: as close as possible to it
capture confirm file cg_countries_shp.dta
local hasshp = (_rc == 0)
capture confirm file cg_cities.dta
if `hasshp' & _rc == 0 {
    preserve
        * a map of South America, cut from the world shapefile
        use cg_countries, clear
        quietly levelsof _ID if name == "Paraguay", local(pid)
        keep if continent == "South America"
        keep _ID
        merge 1:m _ID using cg_countries_shp, keep(match) nogenerate
        sort _ID shape_order
        save cg_sa_shp, replace
        use cg_cities, clear
        calligram if continent == "South America", wordvar(city) countvar(population) minfreq(1) ///
            shapes(cg_sa_shp.dta) location(lat lon) outline width(900) height(1200)               ///
            minfontsize(5) maxwords(124) saving(cg_shapes, replace)                               ///
            savefile(cg_shapes.html) image(cg_shapes.png, replace scale(1))
        assert r(N_placed) > 40
        confirm file cg_shapes.png
        use cg_shapes, clear
        confirm variable region
        * every placed city got a country (its area _ID)
        quietly count if placed == 1 & region == ""
        assert r(N) == 0
        * cities on a border land in their own country: Asunción and Ciudad del Este
        * (on Paraguay's borders with Argentina and Brazil) are in Paraguay
        * (pid: Paraguay's area number, taken when the map was cut, above)
        foreach c in "Asunción" "Ciudad del Este" {
            capture confirm string variable region
            if _rc == 0 quietly count if word == "`c'" & placed == 1 & region == "`pid'"
            else quietly count if word == "`c'" & placed == 1 & region == `pid'
            assert r(N) == 1
        }
        * narrow countries keep their cities: a word that does not fit across
        * its country is turned to run along it (Malawi, Togo on the Africa map)
        use cg_countries, clear
        keep if continent == "Africa"
        keep _ID
        merge 1:m _ID using cg_countries_shp, keep(match) nogenerate
        sort _ID shape_order
        save cg_af_shp, replace
        use cg_cities, clear
        calligram if continent == "Africa", wordvar(city) countvar(population) minfreq(1) ///
            shapes(cg_af_shp.dta) location(lat lon) width(900) height(1280) maxwords(500)  ///
            minfontsize(5) margin(2) font(Lato) saving(cg_af, replace) savefile(cg_africa_test.html)
        use cg_af, clear
        foreach c in "Lilongwe" "Lomé" {
            quietly count if word == "`c'" & placed == 1
            assert r(N) == 1
        }
        * small and thin countries keep their cities on the world map: a word that
        * fits nowhere with the usual clearance from coasts and borders is placed
        * in the country's own pixels (South Korea, Portugal, Taiwan); at this
        * scale some thin countries fit only short names (New Zealand's islands are
        * about 10 pixels across, too narrow for "Auckland" even at minfontsize(4))
        use cg_cities, clear
        calligram, wordvar(city) countvar(population) shapes(cg_countries_shp.dta) location(lat lon) ///
            outline outlinewidth(1) width(2400) height(1067) maxwords(1207) minfreq(1) minfontsize(4)  ///
            margin(2) font(Lato) saving(cg_world, replace) savefile(cg_world_test.html)
        use cg_world, clear
        foreach c in "Seoul" "Lisbon" "Taipei" {
            quietly count if word == "`c'" & placed == 1
            assert r(N) == 1
        }
        * near: Australia's cities as close as possible to where they are
        use cg_countries, clear
        keep if name == "Australia"
        keep _ID
        merge 1:m _ID using cg_countries_shp, keep(match) nogenerate
        sort _ID shape_order
        save cg_aus_shp, replace
        use cg_cities, clear
        calligram if country == "Australia", wordvar(city) countvar(population) minfreq(1)   ///
            shapes(cg_aus_shp.dta) location(lat lon) near outline width(1200) height(1000)       ///
            minfontsize(5) savefile(cg_near.html)
        assert r(N_placed) > 10
        capture calligram, wordvar(city) countvar(population) shapes(cg_countries_shp.dta) near
        assert _rc == 198
        capture calligram, wordvar(city) countvar(population) shapes(cg_countries_shp.dta) shape(heart)
        assert _rc == 198
    restore
}
* a shape from your own coordinates: one area (_ID 1), drawn as given
preserve
    clear
    input byte _ID double(_X _Y)
    1 0 0
    1 4 0
    1 4 1
    1 0 1
    1 0 0
    end
    save cg_rect_shp, replace
restore
calligram, textvar(response) minfreq(1) shapes(cg_rect_shp.dta) projection(none) outline savefile(cg_rect_shp.html)
assert r(N_placed) > 0
capture calligram, textvar(response) shapes(cg_rect_shp.dta) projection(mercator)
assert _rc == 198
capture calligram, textvar(response) regions(response)
assert _rc == 198

* colorby(): colours with meaning (a number, or categories), with a key
gen double rating = mod(_n, 5) + 1
calligram, textvar(response) minfreq(1) colorby(rating) saving(cg_colwords, replace) ///
    savefile(cg_colorby.html) image(cg_colorby.png, replace scale(1))
mata: st_local("html", invtokens(cat("cg_colorby.html")'))
assert strpos(`"`html'"', "class='legend'") > 0
assert strpos(`"`html'"', "data-note='rating: ") > 0
assert strpos(`"`html'"', "fixedcolors:1") > 0
confirm file cg_colorby.png
preserve
    use cg_colwords, clear
    confirm variable colorvalue
    quietly count if placed == 1 & missing(colorvalue)
    assert r(N) == 0
restore
gen str5 region = cond(_n <= 8, "North", "South")
gen byte rcode = 1 + (_n > 8)
* categories need enough text to tell groups apart: 10 copies of the responses
preserve
    quietly expand 10
    calligram, textvar(response) minfreq(1) colorby(region) saving(cg_colwords2, replace) savefile(cg_colorby2.html)
    calligram, textvar(response) minfreq(1) colorby(rcode, categories) savefile(cg_colorby3.html)
    use cg_colwords2, clear
    confirm variable colorgroup colorlift
    * some words belong clearly to one region (servicio, rápido: South only)
    quietly count if placed == 1 & colorgroup != ""
    assert r(N) > 0
    quietly count if word == "servicio" & colorgroup == "South"
    assert r(N) == 1
restore
capture calligram, textvar(response) colorby(rating) palette(Set1)
assert _rc == 198
capture calligram, textvar(response) colorby(nosuchvar)
assert _rc == 111
capture calligram, textvar(response) colorby(rating) colorimage(cg_mask_test.png)
assert _rc == 198
capture calligram, textvar(response) colorvar(region)
assert _rc == 198
capture calligram, textvar(response) colorimage(no_such_picture.png)
assert _rc == 601
drop rating region rcode
* colorvar(): a colour for each word; colorimage(): colours from a picture
preserve
    clear
    input str20 term n str10 col
    "quality" 30 "#e41a1c"
    "service" 20 "#377eb8"
    "delivery" 10 "navy"
    end
    calligram, wordvar(term) countvar(n) colorvar(col) minfreq(1) bgcolor(white) savefile(cg_colorvar.html)
    mata: st_local("html", invtokens(cat("cg_colorvar.html")'))
    assert strpos(`"`html'"', "fill='#e41a1c' data-word='quality'") > 0
restore
* a striped picture drawn in Stata (full-strength bar colours)
preserve
    clear
    quietly set obs 4
    gen x = _n
    gen y = 1
    capture noisily {
        twoway (bar y x if x == 1, color("200 30 45") fintensity(100) barwidth(1))   ///
               (bar y x if x == 2, color("230 120 0") fintensity(100) barwidth(1))   ///
               (bar y x if x == 3, color("20 130 110") fintensity(100) barwidth(1))  ///
               (bar y x if x == 4, color("40 80 160") fintensity(100) barwidth(1)),  ///
               xscale(off range(0.5 4.5)) yscale(off range(0 1)) xlabel(none, nogrid) ylabel(none, nogrid) ///
               legend(off) graphregion(color(white) margin(zero)) plotregion(color(white) margin(zero)) name(cg_stripes, replace)
        graph export cg_stripes.png, name(cg_stripes) width(800) replace
        graph drop cg_stripes
    }
restore
capture confirm file cg_stripes.png
if _rc == 0 {
    * without a mask the picture covers the canvas: every word gets a colour
    calligram, textvar(response) minfreq(1) colorimage(cg_stripes.png) bgcolor(white) saving(cg_colimg, replace) savefile(cg_colorimage.html)
    assert r(N_placed) > 0
    preserve
        use cg_colimg, clear
        quietly count if placed == 1 & color == "#9e9e9e"
        assert r(N) == 0
        * the words take several different colours from the stripes
        quietly levelsof color if placed == 1
        assert `: word count `r(levels)'' >= 4
    restore
}

* every writing system: words stay whole (Indian vowel signs and the virama,
* Thai and Arabic marks are part of the word), two-character Chinese words are
* kept, and colorby(script) gives every word its writing system
capture confirm file cg_languages.dta
if _rc == 0 {
    preserve
        use cg_languages, clear
        calligram [fweight = responses], textvar(text) colorby(script) minfreq(1) maxwords(300) ///
            saving(cg_lang, replace) savefile(cg_languages.html)
        use cg_lang, clear
        foreach w in "उत्कृष्ट" "गुणवत्ता" "চমৎকার" "சிறந்த" "ยอดเยี่ยม" "ممتازة" "بہترین" "کیفیت" "שירות" "服务" "很好" "素晴らしい" "훌륭한" "отличный" {
            quietly count if word == "`w'" & placed == 1
            assert r(N) == 1
        }
        quietly count if placed == 1 & colorgroup == ""
        assert r(N) == 0
    restore
}

* Urdu in Nastaliq: scriptfonts() chooses the font for a writing system, and
* stopwords() gives Urdu's common short words (there is no built-in Urdu list)
capture confirm file cg_urdu.dta
if _rc == 0 {
    preserve
        use cg_urdu, clear
        calligram [fweight = responses], textvar(text) minfreq(1) stopwords(اور تھی تھا لیکن مگر بہت ہوئی) ///
            scriptfonts(arabic "Noto Nastaliq Urdu") shape(circle) width(1000) height(1000)          ///
            saving(cg_urdu_words, replace) savefile(cg_urdu.html)
        assert r(N_placed) > 30
        use cg_urdu_words, clear
        foreach w in "سروس" "معیار" "ڈلیوری" "قیمت" "بہترین" {
            quietly count if word == "`w'" & placed == 1
            assert r(N) == 1
        }
        quietly count if word == "اور"
        assert r(N) == 0
    restore
}
capture calligram, textvar(response) scriptfonts(klingon Arial)
assert _rc == 198
capture calligram, textvar(response) scriptfonts(arabic)
assert _rc == 198

* errors for the new options
capture calligram, textvar(response) wordvar(response)
assert _rc == 198
capture calligram, textvar(response) countvar(_n)
assert _rc != 0
capture calligram, textvar(response) language(de)
assert _rc == 198
capture calligram, textvar(response) phrases phrasestrength(2)
assert _rc == 198

* 19. More errors that should be caught cleanly -------------------------------
capture calligram, textvar(response) shape(blob)
assert _rc == 198
capture calligram, textvar(response) shape(circle) mask(cg_mask_test.png)
assert _rc == 198
capture calligram, textvar(response) mask(no_such_file.png)
assert _rc == 601
capture calligram, textvar(response) scaling(2)
assert _rc == 198
capture calligram, textvar(response) maxfontsize(5) minfontsize(8)
assert _rc == 198

* 20. Caller's data is unchanged ---------------------------------------------
assert _N == 16
confirm string variable response

di as result _n "All calligram checks passed."
