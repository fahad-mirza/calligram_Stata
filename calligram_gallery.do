* calligram_gallery.do  —  the example gallery for calligram (v1.0.11)
*
* Builds every example shown in the README: for each one an interactive HTML
* page and a PNG image (written by calligram itself, with the image() option),
* all in a subfolder called gallery.
*
* Before running, get the example data into the current folder:
*     net get calligram, from(<where you installed calligram from>)
* which copies cg_cities.dta, cg_countries.dta, cg_countries_shp.dta,
* cg_inaugural.dta, cg_alice.dta, cg_languages.dta and cg_urdu.dta.
*
* Data sources (all public domain):
*   - cities and country boundaries: Natural Earth (naturalearthdata.com);
*     the boundaries are in Stata's shapefile format (as made by spshape2dta)
*   - US presidential inaugural addresses, 1789-2025
*   - Lewis Carroll, Alice's Adventures in Wonderland (1865), Project Gutenberg
*   - sysuse auto (shipped with Stata)

version 17
clear all
set more off
capture mkdir gallery

* Religious words are left out of every text example (the inaugural addresses
* use words such as these often); stopwords() removes them, and with them
* phrases such as "god bless".
local noreligion "god gods almighty lord providence heaven heavenly divine prayer prayers pray bless blessed blessing blessings creator sacred holy church churches religion religious faith worship scripture bible christ christian christianity amen soul souls angel angels"

foreach f in cg_cities.dta cg_countries.dta cg_countries_shp.dta cg_inaugural.dta cg_alice.dta cg_languages.dta cg_urdu.dta {
    capture confirm file `f'
    if _rc {
        di as error "`f' not found in the current folder: run  net get calligram, from(...)  first"
        exit 601
    }
}

* ---------------------------------------------------------------------------
* A small set of open-ended survey responses, used by examples 1-3 and 12
* (saved once, then loaded where needed)
* ---------------------------------------------------------------------------
clear
input str100 response
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
"Fast shipping, friendly staff and a fair price for good quality"
"Customer service solved my problem quickly, very helpful staff"
"Delivery was late twice and tracking information was confusing"
"Easy ordering, secure payment and quick refund when needed"
end
save gallery/cg_survey, replace

* 1. The basics: a cloud of survey responses ---------------------------------
use gallery/cg_survey, clear
calligram, textvar(response) minfreq(1)                           ///
    savefile(gallery/01_survey.html) image(gallery/01_survey.png, replace scale(1))

* 2. Light background, title and a colour gradient ---------------------------
calligram, textvar(response) minfreq(1) bgcolor(white)            ///
    gradient(#1d3557 #e63946) title("What customers said")           ///
    savefile(gallery/02_gradient.html) image(gallery/02_gradient.png, replace scale(1))

* 3. Rotated words and another font -----------------------------------------
calligram, textvar(response) minfreq(1) rotate(random) font(Roboto) ///
    savefile(gallery/03_rotated.html) image(gallery/03_rotated.png, replace scale(1))

* 4. Named shapes: a heart, and a star with its outline --------------------
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') shape(heart) width(1000) height(900)     ///
    maxwords(250) rotate(random)                                    ///
    savefile(gallery/04_heart.html) image(gallery/04_heart.png, replace scale(1))
calligram, textvar(text) stopwords(`noreligion') shape(star) outline width(1000) height(1000) ///
    maxwords(250) font(Lato)                                        ///
    savefile(gallery/04_star.html) image(gallery/04_star.png, replace scale(1))

* 5. Any shape you can describe with coordinates: a random blob -----------
*    The edge wobbles randomly (set seed to change it). Saved with the
*    variables _ID, _X and _Y, the points are a one-area shapefile, which
*    shapes() fills directly: the outline is exact, no picture is needed.
*    projection(none): the coordinates are drawn as they are (they are not
*    longitudes and latitudes).
clear
set seed 2024
set obs 2881
gen double t = (_n - 1) * 2 * _pi / 2880
local a1 = runiform(0.10, 0.22)
local a2 = runiform(0.10, 0.22)
local a3 = runiform(0.10, 0.22)
local p1 = runiform(0, 2 * _pi)
local p2 = runiform(0, 2 * _pi)
local p3 = runiform(0, 2 * _pi)
gen double r = 1 + `a1' * sin(2 * t + `p1') + `a2' * sin(3 * t + `p2') + `a3' * sin(5 * t + `p3')
gen double _X = r * cos(t)
gen double _Y = r * sin(t)
gen byte _ID = 1
gen int shape_order = _n
keep _ID _X _Y shape_order
save gallery/cg_blob_shp, replace
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') shapes(gallery/cg_blob_shp.dta) projection(none) outline ///
    width(1000) height(1000) maxwords(300) phrases rotate(90) font(Roboto)          ///
    savefile(gallery/05_blob.html) image(gallery/05_blob.png, replace scale(1))

* 5b. ... or as a picture: a Stata graph exported as PNG, used as a mask() -----
*     Thin spikes from the centre fill the blob in black on white (no grid);
*     two invisible corner points give both axes the same range, so the shape
*     keeps its proportions. calligram crops the white margin.
use gallery/cg_blob_shp, clear
gen byte zero = 0
twoway (pcspike _Y _X zero zero, lcolor(black) lwidth(medthick))     ///
       (line _Y _X, lcolor(black) lwidth(medthick))                  ///
       (scatteri -1.6 -1.6 1.6 1.6, msymbol(none)),                  ///
       aspectratio(1) xscale(off) yscale(off)                         ///
       xlabel(none, nogrid) ylabel(none, nogrid) legend(off)          ///
       graphregion(color(white) margin(zero))                         ///
       plotregion(color(white) margin(zero)) name(blob, replace)
graph export gallery/cg_mask_blob.png, name(blob) width(1000) replace
graph drop blob
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') mask(gallery/cg_mask_blob.png) outline       ///
    width(1000) height(1000) maxwords(300) rotate(random) font(Lato)    ///
    savefile(gallery/05b_blob_mask.html) image(gallery/05b_blob_mask.png, replace scale(1))

* 6. A world map: every city inside its own country --------------------------
*    shapes(): country boundaries from a Stata-format shapefile (any shapefile
*    converted with spshape2dta works). location(lat lon): each city goes into
*    the country that contains its point. outline draws the borders.
use cg_cities, clear
calligram, wordvar(city) countvar(population) shapes(cg_countries_shp.dta)  ///
    location(lat lon) outline outlinewidth(1) outlinecolor(#b8b8b8)            ///
    width(2400) height(1067) maxwords(1207) minfreq(1) minfontsize(4) margin(2) ///
    font(Lato) bgcolor(white) title("The world's cities, each in its own country") ///
    savefile(gallery/06_world.html) image(gallery/06_world.png, replace scale(1))

* 6b. ... and each as close as possible to where it really is (near) ---------
calligram, wordvar(city) countvar(population) shapes(cg_countries_shp.dta)  ///
    location(lat lon) near outline outlinewidth(1) outlinecolor(#b8b8b8)       ///
    width(2400) height(1067) maxwords(1207) minfreq(1) minfontsize(4) margin(2) ///
    font(Lato) bgcolor(white) title("The world's cities, near their location")  ///
    savefile(gallery/06_world_near.html) image(gallery/06_world_near.png, replace scale(1))

* 7. Africa: a map cut from the world shapefile with ordinary Stata commands --
use cg_countries, clear
keep if continent == "Africa"
keep _ID
merge 1:m _ID using cg_countries_shp, keep(match) nogenerate
sort _ID shape_order
save gallery/cg_africa_shp, replace
use cg_cities, clear
calligram if continent == "Africa", wordvar(city) countvar(population)     ///
    shapes(gallery/cg_africa_shp.dta) location(lat lon) outline outlinewidth(1) ///
    width(900) height(1280) maxwords(500) minfreq(1) minfontsize(5) margin(2)    ///
    font(Lato) title("Africa's cities") savefile(gallery/07_africa.html)         ///
    image(gallery/07_africa.png, replace scale(1))

* 7b. ... with words turned to fill each country: rotate(random) lets words
*     run along tall or narrow countries (Chad, Madagascar, Mozambique), so
*     large countries with few cities are less empty. (Without rotate(), a word
*     that does not fit across a narrow country is still turned to fit along
*     it, as Lilongwe in Malawi and Lomé in Togo.)
calligram if continent == "Africa", wordvar(city) countvar(population)     ///
    shapes(gallery/cg_africa_shp.dta) location(lat lon) outline outlinewidth(1) ///
    width(900) height(1280) maxwords(500) minfreq(1) minfontsize(5) margin(2)    ///
    rotate(random) font(Lato) title("Africa's cities, turned to fill each country") ///
    savefile(gallery/07b_africa_turned.html) image(gallery/07b_africa_turned.png, replace scale(1))

* 8. Two-word phrases: US inaugural addresses, 1789-2025 ---------------------
*    phrases joins pairs such as "united states" and "fellow citizens";
*    the phrases found are listed in the Results window.
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') phrases maxwords(200) font(Merriweather)   ///
    title("US inaugural addresses, 1789-2025")                       ///
    savefile(gallery/08_inaugural.html) image(gallery/08_inaugural.png, replace scale(1))

* 9. One cloud per group: the addresses by century (tabs in the page, ----------
*    and one image per century: 09_by_century_18th_century.png etc.)
calligram, textvar(text) stopwords(`noreligion') by(century) phrases maxwords(120) font(Merriweather) ///
    savefile(gallery/09_by_century.html) image(gallery/09_by_century.png, replace scale(1))

* 10. A book in a circle: Alice's Adventures in Wonderland --------------------
*     phrases finds "mock turtle", "march hare", "white rabbit", "cheshire cat"
use cg_alice, clear
calligram, textvar(text) stopwords(`noreligion') phrases shape(circle) width(1000) height(1000) ///
    maxwords(250) minfreq(3) rotate(random) font(Merriweather)            ///
    bgcolor(#fdfaf3) gradient(#7b2d26 #33658a)                            ///
    savefile(gallery/10_alice.html) image(gallery/10_alice.png, replace scale(1))

* 11. Stata's own data: car makes in sysuse auto, sized by total price ------
sysuse auto, clear
gen brand = word(make, 1)
calligram, wordvar(brand) countvar(price) minfreq(1) nostopwords      ///
    shape(ellipse) font(Open Sans) bgcolor(white)                      ///
    title("1978 cars: makes sized by total price")                     ///
    savefile(gallery/11_auto.html) image(gallery/11_auto.png, replace scale(1))

* 12. Weights: some responses count more than others -------------------------
*     (for example survey sampling weights)
use gallery/cg_survey, clear
gen double weight = cond(_n <= 8, 1, 4)
calligram [aweight = weight], textvar(response) minfreq(1)            ///
    savefile(gallery/12_weights.html) image(gallery/12_weights.png, replace scale(1))

* 13. Keep the results as data: the most frequent words as a table -----------
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') phrases maxwords(100)                        ///
    saving(gallery/13_words, replace) savefile(gallery/13_saving.html)
preserve
    use gallery/13_words, clear
    list rank word count fontsize in 1/10, noobs sep(0)
restore

* 14. Large amounts of text: 50 copies of every address (about 80,000 ----------
*     paragraphs; about 3 million words counted after removing stopwords)
use cg_inaugural, clear
quietly expand 50
timer clear 1
timer on 1
calligram, textvar(text) stopwords(`noreligion') savefile(gallery/14_large.html)
timer off 1
timer clear 2
timer on 2
calligram, textvar(text) stopwords(`noreligion') phrases savefile(gallery/14_large_phrases.html)
timer off 2
quietly timer list
di as result "  words only:   " %6.2f r(t1) " seconds in total"
di as result "  with phrases: " %6.2f r(t2) " seconds in total"

* 15. Online pages: smaller files, text instead of letter outlines -----------
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') online font(Lato) maxwords(200)              ///
    savefile(gallery/15_online.html)

* 16. Colour with meaning: each word by the average year of the addresses it
*     appears in (old-fashioned words orange, modern words purple); key below
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') colorby(year) gradient(#d95f02 #5e3c99) phrases   ///
    maxwords(200) font(Merriweather) title("Inaugural addresses: words by average year") ///
    savefile(gallery/16_colorby_year.html) image(gallery/16_colorby_year.png, replace scale(1))

* 17. ... or by the century each word is most typical of (used significantly
*     more there; grey: no clear group)
calligram, textvar(text) stopwords(`noreligion') colorby(century) phrases maxwords(200) font(Merriweather) ///
    title("Inaugural addresses: words by century") ///
    savefile(gallery/17_colorby_century.html) image(gallery/17_colorby_century.png, replace scale(1))

* 18. Categories from a labelled variable: car makes, domestic or foreign
sysuse auto, clear
gen brand = word(make, 1)
calligram, wordvar(brand) countvar(price) colorby(foreign) minfreq(1) nostopwords ///
    shape(ellipse) font(Open Sans) bgcolor(white)                                 ///
    savefile(gallery/18_colorby_foreign.html) image(gallery/18_colorby_foreign.png, replace scale(1))

* 19. Colours from a picture: stripes drawn in Stata, on a heart
clear
set obs 6
gen x = _n
gen y = 1
twoway (bar y x if x == 1, color("200 30 45") fintensity(100) barwidth(1))  ///
       (bar y x if x == 2, color("230 100 20") fintensity(100) barwidth(1))  ///
       (bar y x if x == 3, color("190 140 0") fintensity(100) barwidth(1))  ///
       (bar y x if x == 4, color("20 130 110") fintensity(100) barwidth(1))  ///
       (bar y x if x == 5, color("30 80 150") fintensity(100) barwidth(1))  ///
       (bar y x if x == 6, color("110 40 170") fintensity(100) barwidth(1)), ///
       aspectratio(0.9) xscale(off range(0.5 6.5)) yscale(off range(0 1)) ///
       xlabel(none, nogrid) ylabel(none, nogrid) legend(off)              ///
       graphregion(color(white) margin(zero)) plotregion(color(white) margin(zero)) name(stripes, replace)
graph export gallery/cg_stripes.png, name(stripes) width(1000) replace
graph drop stripes
use cg_inaugural, clear
calligram, textvar(text) stopwords(`noreligion') shape(heart) colorimage(gallery/cg_stripes.png)  ///
    width(1000) height(900) maxwords(250) rotate(random) bgcolor(white)    ///
    savefile(gallery/19_colorimage.html) image(gallery/19_colorimage.png, replace scale(1))

* 20. Every writing system: short customer comments in 20 languages, coloured
*     by writing system (Latin, Cyrillic, Greek, Arabic, Hebrew, Devanagari,
*     Bengali, Tamil, Thai, Chinese characters, Japanese, Hangul). Words are
*     drawn with fonts that cover each script and stored as letter outlines, so
*     the page shows them correctly on any computer. Chinese, Japanese and Thai
*     are written without spaces: split them into words first (here they are).
use cg_languages, clear
calligram [fweight = responses], textvar(text) stopwords(`noreligion') colorby(script) minfreq(1)        ///
    maxwords(250) scaling(0.35) font(Lato) title("Customer comments in 20 languages") ///
    savefile(gallery/20_languages.html) image(gallery/20_languages.png, replace scale(1))

* 21. Urdu in its own calligraphic style, Nastaliq: short customer comments,
*     drawn with the bundled Noto Nastaliq Urdu font, chosen with scriptfonts().
*     Urdu has no built-in stopword list, so its common short words are given
*     with stopwords().
use cg_urdu, clear
calligram [fweight = responses], textvar(text) minfreq(1)                       ///
    stopwords(`noreligion' اور تھی تھا ہے لیکن مگر بہت ہوئی ضرور کروں)          ///
    scriptfonts(arabic "Noto Nastaliq Urdu") shape(circle) width(1000) height(1000) ///
    bgcolor(#0b3d2e) title("Customer comments in Urdu, in Nastaliq")              ///
    savefile(gallery/21_urdu.html) image(gallery/21_urdu.png, replace scale(1))

di as result _n "Gallery written to the folder gallery: open any .html file in a browser."
