{smcl}
{* *! calligram v1.0.10 (Beta)  Fahad Mirza & Claude  11oct2026}{...}
{viewerjumpto "Syntax" "calligram##syntax"}{...}
{viewerjumpto "Description" "calligram##description"}{...}
{viewerjumpto "Options" "calligram##options"}{...}
{viewerjumpto "Color formats" "calligram##colors"}{...}
{viewerjumpto "Palette integration" "calligram##palette"}{...}
{viewerjumpto "Export" "calligram##export"}{...}
{viewerjumpto "Shapes and masks" "calligram##shapes"}{...}
{viewerjumpto "In the browser" "calligram##browser"}{...}
{viewerjumpto "Examples" "calligram##examples"}{...}
{viewerjumpto "Processing pipeline" "calligram##pipeline"}{...}
{viewerjumpto "Stored results" "calligram##results"}{...}
{viewerjumpto "Authors" "calligram##authors"}{...}

{title:Title}

{phang}
{bf:calligram} {hline 2} Word clouds in any shape, from survey text to maps {it:(Beta)}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:calligram} {ifin} {weight}{cmd:,}
{cmdab:textvar(}{it:varname}{cmd:)}
[{it:options}]

{p 8 17 2}
{cmdab:calligram} {ifin}{cmd:,}
{cmdab:wordvar(}{it:varname}{cmd:)}
[{cmdab:countvar(}{it:varname}{cmd:)} {it:options}]

{p 4 6 2}
{cmd:aweight}s, {cmd:fweight}s, {cmd:pweight}s and {cmd:iweight}s are allowed with
{cmd:textvar()}; see {help weight}.

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input (one of)}
{synopt:{cmdab:textvar(}{it:varname}{cmd:)}}string variable containing free text{p_end}
{synopt:{cmdab:wordvar(}{it:varname}{cmd:)}}string variable of words or phrases already counted{p_end}
{synopt:{cmdab:countvar(}{it:varname}{cmd:)}}their counts (with {cmd:wordvar()}; default 1 per row){p_end}

{syntab:Groups}
{synopt:{cmd:by(}{it:varname}{cmd:)}}one cloud per group, shown as tabs on the same page{p_end}

{syntab:Text processing}
{synopt:{cmdab:maxw:ords(}{it:#}{cmd:)}}maximum number of words to display; default is {cmd:maxwords(100)}{p_end}
{synopt:{cmdab:minfr:eq(}{it:#}{cmd:)}}minimum word frequency to include; default is {cmd:minfreq(2)}{p_end}
{synopt:{cmdab:minl:ength(}{it:#}{cmd:)}}minimum word character length; default is {cmd:minlength(3)}{p_end}
{synopt:{cmdab:stopw:ords(}{it:string}{cmd:)}}space-delimited list of additional stopwords to remove{p_end}
{synopt:{cmd:nostopwords}}suppress built-in English stopword removal{p_end}
{synopt:{cmd:noclean}}suppress lowercasing and punctuation removal{p_end}
{synopt:{cmdab:lang:uage(}{it:list}{cmd:)}}stopword languages: {cmd:en} (default), {cmd:fr}, {cmd:es}, {cmd:pt}, or {cmd:all}{p_end}
{synopt:{cmdab:splith:yphens}}split hyphenated words ({it:sci-fi}) into separate words{p_end}
{synopt:{cmdab:nopl:urals}}do not merge plurals with their singulars{p_end}

{syntab:Phrases (opt-in)}
{synopt:{cmd:phrases}}find two-word phrases ({it:customer service}) and show them as one entry{p_end}
{synopt:{cmdab:phrasest:rength(}{it:#}{cmd:)}}how strongly the two words must belong together; default {cmd:0.4}{p_end}
{synopt:{cmdab:addph:rases(}{it:list}{cmd:)}}phrases always joined, e.g. {cmd:addphrases("net promoter" "help desk")}{p_end}
{synopt:{cmdab:dropph:rases(}{it:list}{cmd:)}}phrases never joined{p_end}

{syntab:Appearance}
{synopt:{cmdab:ti:tle(}{it:string}[{cmd:,} {cmd:color(}{it:color}{cmd:)} {cmd:size(}{it:size}{cmd:)}]{cmd:)}}chart title with optional color and font size{p_end}
{synopt:{cmdab:w:idth(}{it:#}{cmd:)}}canvas width in pixels; default is {cmd:width(1600)}{p_end}
{synopt:{cmdab:h:eight(}{it:#}{cmd:)}}canvas height in pixels; default is {cmd:height(800)}{p_end}
{synopt:{cmdab:mar:gin(}{it:#}{cmd:)}}minimum gap between words in pixels; default is {cmd:margin(4)}{p_end}
{synopt:{cmdab:spac:ing(}{it:#}{cmd:)}}extra clearance around each word as a share of its font size; default is {cmd:spacing(0)}{p_end}
{synopt:{cmdab:maxf:ontsize(}{it:#}{cmd:)}}largest font size; default is automatic (fills the space){p_end}
{synopt:{cmdab:minfo:ntsize(}{it:#}{cmd:)}}smallest font size words may shrink to; default is {cmd:minfontsize(8)}{p_end}
{synopt:{cmdab:sca:ling(}{it:#}{cmd:)}}how strongly size follows frequency, 0 to 1; default is {cmd:scaling(0.5)}{p_end}
{synopt:{cmdab:sha:pe(}{it:name}{cmd:)}}outline to fill: {cmd:rectangle} (default), {cmd:ellipse}, {cmd:circle}, {cmd:square}, {cmd:cloud}, {cmd:heart}, {cmd:diamond}, {cmd:triangle}, {cmd:star}{p_end}
{synopt:{cmd:mask(}{it:filename}{cmd:)}}fill the dark area of an image (PNG, JPG, GIF, BMP){p_end}
{synopt:{cmdab:shape:s(}{it:filename}{cmd:)}}areas from a Stata-format shapefile ({it:name}{cmd:_shp.dta}, made by {help spshape2dta}){p_end}
{synopt:{cmdab:loc:ation(}{it:yvar xvar}{cmd:)}}put each word in the area containing its point (latitude longitude){p_end}
{synopt:{cmd:near}}with {cmd:location()}: place each word as close as possible to its point{p_end}
{synopt:{cmdab:reg:ions(}{it:varname}{cmd:)}}keep each word inside its own area: area ID with {cmd:shapes()}, colour with {cmd:mask()}{p_end}
{synopt:{cmdab:proj:ection(}{it:name}{cmd:)}}{cmd:auto} (default), {cmd:equalearth} or {cmd:none}{p_end}
{synopt:{cmd:seed(}{it:#}{cmd:)}}layout seed; change it for a different arrangement; default is {cmd:seed(42)}{p_end}
{synopt:{cmdab:outl:ine}}draw the edge of the shape or mask behind the words{p_end}
{synopt:{cmdab:outlinec:olor(}{it:color}{cmd:)}}outline color; implies {cmd:outline}{p_end}
{synopt:{cmdab:outlinew:idth(}{it:#}{cmd:)}}outline width in pixels; implies {cmd:outline}; default is {cmd:2}{p_end}
{synopt:{cmdab:fix:ed}}show the cloud at its exact pixel size instead of scaling it to the window{p_end}
{synopt:{cmdab:bgc:olor(}{it:color}{cmd:)}}background color; default is {cmd:bgcolor(#16213e)}{p_end}
{synopt:{cmdab:pal:ette(}{it:name}{cmd:)}}color palette name from Ben Jann's {cmd:colorpalette}{p_end}
{synopt:{cmdab:grad:ient(}{it:color1 color2}{cmd:)}}color words along a gradient from most to least frequent{p_end}
{synopt:{cmdab:colorb:y(}{it:varname}[{cmd:, categories}]{cmd:)}}colour words by a variable: its average (numbers) or the group each word is typical of{p_end}
{synopt:{cmdab:colorv:ar(}{it:varname}{cmd:)}}with {cmd:wordvar()}: a colour for each word{p_end}
{synopt:{cmdab:colori:mage(}{it:filename}{cmd:)}}colour each word from a picture{p_end}
{synopt:{cmdab:fon:t(}{it:name}{cmd:)}}font used to measure and draw words; default is {cmd:font(Arial)}{p_end}
{synopt:{cmdab:scriptf:onts(}{it:script font} ...{cmd:)}}font for a writing system, e.g. {cmd:arabic "Noto Nastaliq Urdu"}{p_end}
{synopt:{cmdab:onl:ine}}write words as text and load the font from Google Fonts (smaller file; needs internet){p_end}
{synopt:{cmdab:rot:ate(}{it:mode}{cmd:)}}word rotation: {cmd:none}, {cmd:90}, or {cmd:random}; default is {cmd:rotate(none)}{p_end}

{syntab:Performance}
{synopt:{cmdab:thr:eads(}{it:#}{cmd:)}}number of processor cores to use; default is {cmd:threads(0)}, all cores{p_end}

{syntab:Output}
{synopt:{cmdab:savef:ile(}{it:filename}{cmd:)}}output HTML file path; default is {cmd:savefile(calligram.html)}{p_end}
{synopt:{cmdab:sav:ing(}{it:filename}[{cmd:, replace}]{cmd:)}}also save the words, counts, sizes, positions and colours as a dataset{p_end}
{synopt:{cmdab:im:age(}{it:filename}[{cmd:, replace scale(}{it:#}{cmd:)}]{cmd:)}}also save the cloud as a PNG, JPG or SVG image{p_end}
{synopt:{cmdab:notool:bar}}leave out the side panel (search, filter, top words, zoom, colours, saving){p_end}
{synopt:{cmdab:exp:ort(}{it:format}{cmd:)}}with {cmd:notoolbar}: add a single save button ({cmd:png}, {cmd:jpg}, or {cmd:svg}){p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:calligram} reads a string variable containing free text, counts word
frequencies across all observations, and renders the results as an interactive
HTML/SVG word cloud. Words are sized by frequency and packed into the whole
canvas, or into a chosen shape or image silhouette. The output is a
self-contained HTML file that can be opened in any modern web browser.

{pstd}
{cmd:calligram} is built for large amounts of text. Words are counted by a
Java engine that reads the selected observations directly from the data in
memory, without copying the dataset or expanding it to one row per word, and
that uses all processor cores: one reads the text while the others clean,
split and count it. Memory use grows with the number of {it:different} words,
not with the amount of text. Only the most frequent words per group are passed
back to Stata. Use {cmd:if} and {cmd:in} to restrict the observations.

{pstd}
The layout algorithm mirrors the approach used by the Python
{browse "https://github.com/amueller/word_cloud":amueller/word_cloud} library:
words are placed largest first at a random free position on a pixel grid;
a word only blocks out its actual letter pixels, so smaller words can tuck into
the gaps between larger ones; a word that does not fit is tried in the other
orientation (if rotation is on) and then shrunk until it does; and the largest
font size is found automatically so that the cloud fills the space. The layout
is done by a small Java engine ({cmd:calligram.jar}) that is installed with
the package and runs on Stata's own built-in Java.

{pstd}
The HTML output is interactive: hovering over any word displays a tooltip
showing the word and its exact frequency count. If {cmd:export()} is specified,
a download button is embedded in the page for static export.

{pstd}
{cmd:calligram} uses {cmd:preserve} and {cmd:restore} internally, so the
caller's dataset is never modified.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{cmdab:textvar(}{it:varname}{cmd:)} specifies the string variable containing
the free text to visualise, typically one response per observation. The
variable may be any string type, including {cmd:strL}. With weights, every word
in a response counts with that response's weight (see {help calligram##weights:Weights}).

{phang}
{cmdab:wordvar(}{it:varname}{cmd:)} is used instead of {cmd:textvar()} when the
words have already been counted elsewhere (for example the output of a topic
model, or a table of keywords): each observation holds one word or phrase,
used as given (only stopwords are removed), and rows with the same entry are
added up. {cmdab:countvar(}{it:varname}{cmd:)} gives each row's count; without
it every row counts once. {cmd:wordvar()} needs the Java engine; weights,
{cmd:phrases} and {cmd:addphrases()} do not apply to it.

{dlgtab:Groups}

{phang}
{cmd:by(}{it:varname}{cmd:)} draws one cloud for each value of {it:varname} (for
example country, sector, or survey wave), each counted and laid out separately,
and puts them all in the same HTML page with a tab for each group. Tabs are
labelled with the value labels of a numeric variable, or with the values
themselves. Observations with a missing {it:varname} are left out. A group
whose text has no words left after filtering is skipped with a message. At most
50 groups are allowed. All other options apply to every group.

{dlgtab:Text processing}

{phang}
{cmdab:maxw:ords(}{it:#}{cmd:)} sets the maximum number of words shown in the
cloud. Words are selected by frequency (most frequent first) before the layout
algorithm runs. Default is {cmd:100}.

{phang}
{cmdab:minfr:eq(}{it:#}{cmd:)} excludes words appearing fewer than {it:#}
times. Raising this threshold reduces noise in large corpora. Default is
{cmd:2}.

{phang}
{cmdab:minl:ength(}{it:#}{cmd:)} excludes words shorter than {it:#}
characters after cleaning. Default is {cmd:3}.

{phang}
{cmdab:stopw:ords(}{it:string}{cmd:)} specifies additional stopwords as a
space-delimited list. These supplement the built-in English stopword list
unless {cmd:nostopwords} is also specified.

{pmore}
Example: {cmd:stopwords(respondent survey questionnaire n/a)}

{phang}
{cmd:nostopwords} suppresses the built-in stopword lists. Only words supplied in
{cmd:stopwords()}, if any, are removed.

{phang}
{cmdab:lang:uage(}{it:list}{cmd:)} chooses the built-in stopword lists: {cmd:en}
English (the default, about 300 words: function words, pronouns, auxiliary
verbs, number words, and filler such as {it:like}, {it:just}, {it:even}),
{cmd:fr} French, {cmd:es} Spanish and {cmd:pt} Portuguese; several can be given,
for example {cmd:language(en es)} for responses in both languages, or
{cmd:language(all)}. With French, elided articles are split off, so
{it:l'entreprise} counts as {it:entreprise} and {it:d'électricité} as
{it:électricité}.

{phang}
{cmdab:splith:yphens} splits words at hyphens. By default a hyphen between two
letters or digits keeps the word whole, so {it:sci-fi}, {it:e-mail},
{it:follow-up} and {it:15-year-old} each count as one word; a dash with spaces
around it ({it:good - but slow}) or a long dash always separates words.

{phang}
{cmdab:nopl:urals} keeps plurals apart from their singulars. By default a word
is merged with its singular when the singular also occurs in the text:
{it:delays} with {it:delay}, {it:companies} with {it:company}, {it:taxes} with
{it:tax}, {it:follow-ups} with {it:follow-up}. Words that only look plural
({it:news}, {it:series}, {it:goods}, {it:status}, {it:analysis}, {it:bus}) are
left alone. The merged entry is shown in whichever form occurs more often.
The number of plural forms merged is reported.

{dlgtab:Phrases}

{phang}
{cmd:phrases} finds two-word phrases, such as {it:customer service} or
{it:product quality}, and shows each as one entry in the cloud; the two words
then keep only their other uses. A pair of neighbouring words becomes a phrase
when all of these hold:

{phang2}- the two words are next to each other within one response, with no
punctuation or stopword between them (pairs never cross from one response to
the next);{p_end}
{phang2}- the pair occurs at least 3 times;{p_end}
{phang2}- there is clear evidence that the words go together more often than by
chance (a log-likelihood ratio test, significant at the 0.1% level); and{p_end}
{phang2}- the link is strong: the pair's normalised pointwise mutual information,
a measure from 0 (no link) to 1 (the words only occur together) that does not
grow with the amount of text, is at least {cmd:phrasestrength()}.{p_end}

{pmore}
The phrases joined are listed in the Results window, so they can be checked.
Phrases are found on all the selected text, also with {cmd:by()}, so every group
uses the same phrases. Plural forms count as the same phrase ({it:customer
services} with {it:customer service}). Finding phrases reads the text twice, so
it takes about two to three times as long.

{phang}
{cmdab:phrasest:rength(}{it:#}{cmd:)} sets the strength a pair needs, between 0 and
1. The default, 0.4, keeps phrases such as {it:special effects},
{it:science fiction}, {it:supporting cast} and {it:real life} while rejecting
loose pairs such as {it:really good}. Lower values join more pairs; higher
values only very fixed expressions and names.

{phang}
{cmdab:addph:rases(}{it:list}{cmd:)} lists phrases that are always joined, with or
without {cmd:phrases}, each in double quotes:
{cmd:addphrases("net promoter" "help desk")}. Each must be two words after
cleaning.

{phang}
{cmdab:dropph:rases(}{it:list}{cmd:)} lists phrases that are never joined, for
example a pair that {cmd:phrases} joined but that should stay as two words.

{phang}
{cmd:noclean} suppresses automatic text normalisation. By default,
{cmd:calligram} lowercases all text (Unicode-aware, so accented capitals are
handled), deletes apostrophes so that contractions such as {it:don't} become
{it:dont}, and replaces any character that is not a letter or digit (in any
script) with a space. Tokens made only of digits, such as {it:2024}, are
dropped; mixed tokens such as {it:covid19} are kept. Specifying {cmd:noclean}
passes the text through unchanged apart from splitting on whitespace.

{dlgtab:Appearance}

{phang}
{cmdab:ti:tle(}{it:string}[{cmd:,} {cmd:color(}{it:color}{cmd:)}
{cmd:size(}{it:size}{cmd:)}]{cmd:)} sets the chart title displayed above the
word cloud. The title text is separated from sub-options by a comma.
Sub-options may appear in any order.

{pmore}
{cmd:color(}{it:color}{cmd:)} sets the title text color using any CSS color
value. Default is {cmd:color(#eeeeee)}. See
{help calligram##colors:Color formats}.

{pmore}
{cmd:size(}{it:size}{cmd:)} sets the title font size. Accepts any CSS
font-size value. A plain number with no unit is treated as {it:em}.
Default is {cmd:size(1.4em)}.

{pmore}
Examples:

{pmore2}
{cmd:title("Customer Feedback")}{break}
{cmd:title("Customer Feedback", color(#ff6b6b))}{break}
{cmd:title("Customer Feedback", size(2em))}{break}
{cmd:title("Customer Feedback", color(white) size(28px))}{break}
{cmd:title("Customer Feedback", color(rgb(0,128,255)) size(2em))}

{phang}
{cmdab:w:idth(}{it:#}{cmd:)} sets the canvas width in pixels the layout is
computed for. Default is {cmd:1600}. The cloud is scaled to fit the browser
window, so this sets the proportions and the level of detail rather than the
size on screen; the default 2:1 shape matches a typical browser window.

{phang}
{cmdab:h:eight(}{it:#}{cmd:)} sets the canvas height in pixels. Default is
{cmd:800}. For round shapes such as {cmd:shape(circle)} a square canvas, for
example {cmd:width(900) height(900)}, gives the largest words.

{phang}
{cmdab:mar:gin(}{it:#}{cmd:)} sets the minimum gap between the letters of
neighbouring words, in pixels. Larger values produce sparser clouds. Default is
{cmd:4}.

{phang}
{cmdab:spac:ing(}{it:#}{cmd:)} adds clear space around each word in proportion to
its font size, so large words keep smaller ones further away. The default,
{cmd:spacing(0)}, gives the densest cloud: every word keeps the same
{cmd:margin()} from its neighbours, and small words fill the gaps between and
around large letters. Words never overlap at any setting. For a more open look
try {cmd:spacing(0.05)} to {cmd:spacing(0.1)}: with {cmd:spacing(0.08)} a
300-pixel word keeps 24 pixels clear. Values up to 0.5 are allowed; wider
spacing makes the smallest words slightly smaller.

{phang}
{cmdab:maxf:ontsize(}{it:#}{cmd:)} sets the largest font size in pixels, used
for the most frequent word. By default ({cmd:maxfontsize(0)}) it is chosen
automatically so that the cloud fills the canvas or shape: a trial layout of
the two most frequent words sets the starting size, and if the words that fit
carry less than 95% of all mentions, the layout is repeated with smaller sizes.
A few of the rarest words may then be left out rather than every word shrunk,
which keeps the difference in size between frequent and rare words. A value you give
is a starting point; words still shrink if they do not fit.

{phang}
{cmdab:minfo:ntsize(}{it:#}{cmd:)} sets the smallest font size a word may
shrink to. A word that does not fit even at this size is left out (the number
left out is reported). Default is {cmd:8}.

{phang}
{cmdab:sca:ling(}{it:#}{cmd:)} sets how strongly font size follows frequency,
between 0 and 1 (Python word_cloud's {it:relative_scaling}). Each word's size is
derived from the previous word's: {it:size} = ({it:#} x {it:f}/{it:f_prev} +
1 - {it:#}) x {it:size_prev}. With {cmd:scaling(0)} size depends only on rank;
with {cmd:scaling(1)} a word twice as frequent is twice as large. Default is
{cmd:0.5}.

{phang}
{cmdab:bgc:olor(}{it:color}{cmd:)} sets the background color of both the page
and the SVG canvas. Default is {cmd:bgcolor(#16213e)} (dark navy). Accepts the
same CSS color formats as the {cmd:color()} sub-option of {cmd:title()};
see {help calligram##colors:Color formats}.

{phang}
{cmdab:pal:ette(}{it:name}{cmd:)} specifies a color palette for the word
cloud using Ben Jann's {cmd:colorpalette} package. Any palette recognised by
{cmd:colorpalette} may be used. If {cmd:colorpalette} is not installed or the
palette name is unrecognised, {cmd:calligram} falls back to its built-in
ten-color Tableau-inspired palette with a warning. See
{help calligram##palette:Palette integration}.

{phang}
{cmdab:grad:ient(}{it:color1 color2}{cmd:)} colors words along a smooth
gradient: the most frequent word gets {it:color1} and the least frequent gets
{it:color2}. Colors are blended in HSL space (hue, saturation, lightness), which
keeps intermediate colors vivid instead of passing through muddy greys. Each
color may be a hex code ({cmd:#rrggbb} or {cmd:#rgb}) or a common CSS color
name such as {cmd:navy}, {cmd:tomato}, or {cmd:teal}. {cmd:gradient()} cannot
be combined with {cmd:palette()}.

{pmore}
Examples: {cmd:gradient(#ff6b6b #4ecdc4)}{space 3}{cmd:gradient(navy gold)}

{phang}
{cmdab:fon:t(}{it:name}{cmd:)} sets the font. By default each word is stored
in the page as the exact outlines of its letters (see
{help calligram##offline:Offline and online pages}), so the font only needs to
be available when the cloud is made, not on the computers that open the page.
Default is {cmd:font(Arial)}.

{pmore}
Seven free fonts come with {cmd:calligram}, so they work on any computer:
{bf:Arimo} (the same letter widths as Arial), {bf:Tinos} (the same letter
widths as Times New Roman), {bf:Roboto}, {bf:Open Sans}, {bf:Lato},
{bf:Noto Sans}, and the serif {bf:Merriweather}, all in bold. Any font
installed on your computer can also be named. If it is not installed,
{cmd:calligram} says so and uses Arimo instead. Words with characters the
font does not have (for example Arabic or Chinese words with a Latin font)
are drawn with Java's system font, which covers most scripts; a note says how
many. Names may contain letters, digits, spaces, and hyphens.

{pmore}
Examples: {cmd:font(Lato)}{space 3}{cmd:font(Open Sans)}{space 3}{cmd:font(Merriweather)}{space 3}{cmd:font(Times New Roman)}

{phang}
{cmdab:onl:ine} writes the words as text and, for the seven bundled fonts, adds
a link that loads the same font from Google Fonts when the page is opened.
Pages are smaller and the words can be selected and copied, but the page needs
an internet connection to look right; see
{help calligram##offline:Offline and online pages}.

{phang}
{cmdab:rot:ate(}{it:mode}{cmd:)} controls word orientation.
{cmd:none} (the default) keeps all words horizontal.
{cmd:90} alternates horizontal and vertical words, starting with a horizontal
most-frequent word.
{cmd:random} makes about 60% of words horizontal and 40% vertical, using a
fixed internal seed so the same data always give the same cloud (Stata's own
random-number state is not touched).
With {cmd:90} or {cmd:random}, a word that does not fit in its preferred
orientation is retried in the other one before it is shrunk.

{phang}
{cmdab:sha:pe(}{it:name}{cmd:)} chooses the outline the words fill. The default,
{cmd:rectangle}, uses the whole canvas. {cmd:ellipse} stretches to the canvas;
{cmd:circle}, {cmd:square}, {cmd:cloud}, {cmd:heart}, {cmd:diamond},
{cmd:triangle}, and {cmd:star} keep their proportions and are centred, so on a
wide canvas they leave space at the sides (use, for example,
{cmd:width(600) height(600)} for a circle). See
{help calligram##shapes:Shapes and masks}.

{phang}
{cmd:mask(}{it:filename}{cmd:)} fills the silhouette in an image instead of a
named shape. Words go where the image is dark (any pixel that is not near-white)
and opaque; white or transparent areas stay empty. White or transparent margins
around the shape are cropped off, and the shape is then scaled to fit the canvas,
keeping its proportions, so an image exported from a Stata graph can be used as it
is. Good masks are solid silhouettes on a white or transparent background: maps,
logos, icons, letters. Photographs, line drawings, and light grey backgrounds do
not work (a light grey background counts as part of the shape). For the largest
words, give the canvas the shape's proportions with {cmd:width()} and
{cmd:height()}. PNG, JPG, GIF, and BMP files are accepted, a
leading {cmd:~} means your home folder, and relative paths are relative to the
current working directory. {cmd:mask()} cannot be combined with {cmd:shape()}.

{phang}
{cmdab:shape:s(}{it:filename}{cmd:)} fills the areas of a shapefile, for example
the countries of a map, instead of a shape or mask. {it:filename} is a
Stata-format shapefile: the {it:name}{cmd:_shp.dta} file that {help spshape2dta}
makes from {it:name}{cmd:.shp} and {it:name}{cmd:.dbf} (variables {cmd:_ID},
{cmd:_X}, {cmd:_Y}, and usually {cmd:shape_order}). Areas with several parts
(islands) and holes (lakes) are handled. With {cmd:outline}, the border of every
area is drawn exactly, as vector lines. The map is scaled to fit the canvas; give
the canvas the map's proportions with {cmd:width()} and {cmd:height()}. To use
only some areas, keep them in the {it:name}{cmd:.dta} file and merge with
{it:name}{cmd:_shp.dta} (see the example below). {cmd:shapes()} cannot be combined
with {cmd:shape()} or {cmd:mask()}. Any outline you can compute works the same way:
save its points with the variables {cmd:_ID} (the same number for every point of
one area), {cmd:_X} and {cmd:_Y}, in order around the edge, and give
{cmd:projection(none)} unless they are longitudes and latitudes.

{phang}
{cmdab:loc:ation(}{it:yvar xvar}{cmd:)} puts each word into the area of
{cmd:shapes()} that contains its point: latitude and longitude for maps in
longitude/latitude, or y and x in the shapefile's own coordinates. Points just
off a coastline (where the map's border is simplified) go to the nearest area
within a few pixels. It needs {cmd:wordvar()} (one word per row); words with the
same text but different points (two cities called San Jose) are kept apart.

{phang}
{cmd:near}, with {cmd:location()}, places each word as close as possible to its
point inside its area, so the cloud keeps the geography (west coast cities in the
west). A word first shrinks until it fits close to its point; only if it cannot,
even at {cmd:minfontsize()}, does it go to the nearest free spot in its area.
Without {cmd:near}, words go anywhere in their area.
In areas, a word's size is limited by the room it has: a word can be no wider
than its area. Without {cmd:rotate()}, a word that does not fit across its area
at any size is turned to run along it (a narrow country such as Malawi). With
{cmd:rotate(random)} or {cmd:rotate(90)}, words can run along tall or narrow areas,
so large areas with few words are filled better. Words keep a small clearance from coasts and borders; a word that fits nowhere
with it is placed in its area's own pixels, closer to the lines. Areas too small
for any word at {cmd:minfontsize()} stay empty; the words that did not fit are listed in the
Results window.

{phang}
{cmdab:reg:ions(}{it:varname}{cmd:)} keeps each word inside its own area. With
{cmd:shapes()}, {it:varname} is the numeric area ID ({cmd:_ID}) of each word, for
example after merging your data with the shapefile's {it:name}{cmd:.dta} file.
With {cmd:mask()}, {it:varname} is a string with the colour (#{it:rrggbb}) of the
word's area in a mask image in which every area has its own colour (drawn
without antialiasing). It needs {cmd:wordvar()}. With {cmd:regions()} or
{cmd:location()}, each word's size comes straight from its count: letter height
in proportion to count^{cmd:scaling()}, so with the default 0.5 a word's area is in
proportion to its count. A word shrinks if its area has too little room, but
never grows beyond its share. Words that do not fit in their area even at
{cmd:minfontsize()}, or whose area is not found, are left out and counted in a
message; a larger canvas leaves room for small or narrow areas.

{phang}
{cmdab:proj:ection(}{it:name}{cmd:)} sets how {cmd:shapes()} coordinates are
drawn. {cmd:auto} (the default) uses the Equal Earth projection, which keeps
areas in proportion, when all coordinates are longitudes and latitudes, and
draws other coordinates as they are; {cmd:equalearth} and {cmd:none} force one
or the other.

{pmore}
Example: {cmd:calligram, wordvar(city) countvar(population) shapes(countries_shp.dta) location(lat lon) near outline}

{phang}
{cmd:seed(}{it:#}{cmd:)} sets the seed for the random choices in the layout
(positions and, with {cmd:rotate(random)}, orientations). The same data and
options always give the same cloud; a different seed gives a different
arrangement. Stata's own random-number state is not affected. Default is
{cmd:42}.

{phang}
{cmdab:outl:ine} draws the edge of the shape (or of the silhouette in a
{cmd:mask()} image) as a line behind the words, which makes the shape easy to
see even when few words fill it. Named shapes use their exact outline; image
silhouettes are traced from the image, including any holes. Words are kept a
few pixels clear of the line. With the default {cmd:rectangle} shape the line
frames the canvas.

{phang}
{cmdab:outlinec:olor(}{it:color}{cmd:)} sets the outline color using any CSS
color value. The default is the title text color at 45% opacity. Specifying
this option turns the outline on.

{phang}
{cmdab:outlinew:idth(}{it:#}{cmd:)} sets the outline width in pixels, greater
than 0 and at most 20. Default is {cmd:2}. Specifying this option turns the
outline on.

{dlgtab:Performance}

{phang}
{cmdab:thr:eads(}{it:#}{cmd:)} sets how many processor cores the Java engine
may use for counting words and for laying out clouds. The default,
{cmd:threads(0)}, uses all cores. With {cmd:by()}, groups are laid out at the
same time on different cores. Results do not depend on the number of threads:
the same data and options always give the same clouds. Set a smaller number on
a shared computer.

{dlgtab:Output}

{phang}
{cmdab:colorb:y(}{it:varname}[{cmd:, categories}]{cmd:)} colours the words by a
variable, so the colour carries meaning; a key appears under the cloud (and in
{cmd:image()} pictures), and the hover card gives each word's value.

{pmore}
With a numeric variable (a rating, a sentiment score, a year), each word gets the
average of the variable over the responses it appears in (weighted, if weights
are given), placed on a gradient from the lowest to the highest average among the
words shown; {cmd:gradient(}{it:low high}{cmd:)} sets the two colours (default red
to green). Missing values are ignored.

{pmore}
With categories (a string variable, a numeric variable with value labels, or any
variable with the {cmd:categories} sub-option), each word takes the colour of the
category it is most typical of: the one where it is used significantly more often
than its overall rate predicts (an exact binomial test at 95% confidence, split
across the categories so that no small group claims a word by chance). Words
used about evenly, or too rarely to tell, are grey ("no clear group"). Small
categories therefore need strong evidence to claim a word. The hover card (and
{cmd:saving()}, variable {cmd:colorlift}) says how many times as often the word is
used in its category as overall. {cmd:palette()} or
{cmd:gradient()} sets the colours; at most 30 categories.

{phang}
{cmdab:colorv:ar(}{it:varname}{cmd:)}, with {cmd:wordvar()}, gives each word its
own colour: a string variable with hex ({cmd:#}{it:rrggbb}), {cmd:rgb(}{it:r,g,b}{cmd:)}
or CSS colour names. Compute it in Stata however you like. Words without a usable
colour are grey.

{phang}
{cmdab:colori:mage(}{it:filename}{cmd:)} colours each word with the average colour
of a picture (PNG, JPG, GIF, BMP) under its letters. The picture covers the whole
canvas (what overflows is cropped); with {cmd:mask()} it is fitted the same way as
the mask instead, so the same picture can be both. Only one of
{cmd:colorby()}, {cmd:colorvar()} and {cmd:colorimage()} can be given.

{phang}
{cmdab:scriptf:onts(}{it:script font} [{it:script font} ...]{cmd:)} chooses the font for
a writing system, used for every word written in it even when {cmd:font()} could draw
it. Writing systems: {cmd:arabic} (Arabic, Persian, Urdu), {cmd:hebrew}, {cmd:devanagari},
{cmd:bengali}, {cmd:tamil}, {cmd:telugu}, {cmd:gurmukhi}, {cmd:gujarati}, {cmd:thai},
{cmd:chinese}, {cmd:japanese}, {cmd:korean}, {cmd:cyrillic}, {cmd:greek}, {cmd:latin},
{cmd:ethiopic}. Put font names with spaces in quotes. For example,
{cmd:scriptfonts(arabic "Noto Nastaliq Urdu")} draws Urdu in Nastaliq, its usual
calligraphic style; that font is bundled with calligram. Without this option, words in
a writing system the main font lacks are drawn with an installed font that covers it
(on Windows, for example, Nirmala UI for Hindi, Bengali and Tamil, Segoe UI for Arabic
script including Urdu, Microsoft YaHei for Chinese), and Stata says which.

{phang}
{cmdab:im:age(}{it:filename}[{cmd:, replace scale(}{it:#}{cmd:)}]{cmd:)} also saves
the cloud as a picture, written directly by {cmd:calligram} while it runs (no
browser needed), for reports, slides, or do-files that rebuild figures. The
extension sets the format: {cmd:.png} (the default), {cmd:.jpg}, or {cmd:.svg}
(vector, for print or further editing). The picture is drawn from the same letter
outlines as the page, so it looks exactly like the cloud on screen, with the
background colour and any {cmd:outline}; the title is not included. PNG and JPG
pictures are {cmd:scale()} times the canvas size, default 2 (3200 x 1600 pixels
for the default canvas); {cmd:scale(1)} gives the canvas size. With {cmd:by()},
each group gets its own file, named with the group added, for example
{cmd:cloud_North.png}. {cmd:replace} overwrites existing files. {cmd:image()}
needs the Java engine.

{pmore}
Example: {cmd:image(results/cloud.png, replace)}

{phang}
{cmdab:sav:ing(}{it:filename}[{cmd:, replace}]{cmd:)} also saves the result as a
Stata dataset: one row per word (or phrase) considered, with {cmd:group} (and
{cmd:group_label} with {cmd:by()}), {cmd:rank}, {cmd:word}, {cmd:count}
(weighted, if weights were used), {cmd:n} (number of occurrences), {cmd:placed},
{cmd:fontsize}, {cmd:rotation}, {cmd:x}, {cmd:y} and {cmd:color}. Use it for
tables of the most frequent words, to compare groups, or to document a figure.

{phang}
{cmdab:savef:ile(}{it:filename}{cmd:)} specifies the output HTML file path.
Any existing file is replaced. Default is {cmd:calligram.html} in the current
working directory (type {cmd:pwd} to see it; this is the same rule Stata's
{cmd:save} and {cmd:graph export} follow). A leading {cmd:~} means your home
folder, for example {cmd:savefile(~/Documents/cloud.html)}. If the name does not
end in {cmd:.html} or {cmd:.htm}, {cmd:.html} is added. The folder must already
exist. The full path of the file written is shown at the end as a clickable
link and stored in {cmd:r(savefile)}.

{phang}
{cmdab:fix:ed} shows the cloud at its own pixel size ({cmd:width()} x
{cmd:height()}, or smaller if the window is narrower), and the page scrolls if
needed. By default the cloud is scaled, keeping its proportions, to fill the
space beside the panel and below the header, and it rescales when the window is resized; because the cloud
is a vector image it stays sharp at any size. The layout itself is the same
either way.

{phang}
{cmdab:notool:bar} leaves out the side panel described under
{help calligram##browser:In the browser}, giving a plain page with the cloud
and hover tooltips, for example for embedding. Tabs for {cmd:by()} groups are
still shown.

{phang}
{cmdab:exp:ort(}{it:format}{cmd:)} is only needed with {cmd:notoolbar}: the
side panel already has buttons to save PNG, SVG, and JPG. With {cmd:notoolbar},
{cmd:export()} adds a single save button for the chosen format, {cmd:png},
{cmd:jpg} (or {cmd:jpeg}), or {cmd:svg}. Saved files are named after
{cmd:savefile()} (with the group added for {cmd:by()}) and go to the browser's
download folder.

{pmore}
Example: {cmd:savefile(results/cloud.html) notoolbar export(png)} embeds a
button that downloads {cmd:cloud.png}.

{pmore}
See {help calligram##export:Export} for details.


{marker colors}{...}
{title:Color formats}

{pstd}
Both {cmd:bgcolor()} and the {cmd:color()} sub-option of {cmd:title()} accept
any valid CSS color value in a consistent bare format — no extra quotation marks
are needed.

{p2colset 5 30 31 2}{...}
{p2col:{it:Format}}Example{p_end}
{p2line}
{p2col:Hex shorthand}{cmd:bgcolor(#fff)}{p_end}
{p2col:Hex full}{cmd:bgcolor(#16213e)}{p_end}
{p2col:Named color}{cmd:bgcolor(white)}{cmd:, bgcolor(navy)}{p_end}
{p2col:RGB}{cmd:bgcolor(rgb(0,30,60))}{p_end}
{p2col:RGBA (with alpha)}{cmd:bgcolor(rgba(0,30,60,0.9))}{p_end}
{p2col:HSL}{cmd:bgcolor(hsl(220,60%,15%))}{p_end}
{p2line}
{p2colreset}{...}

{pstd}
Named CSS colors include common names such as {cmd:white}, {cmd:black},
{cmd:navy}, {cmd:steelblue}, {cmd:tomato}, {cmd:gold}, {cmd:lightgray}, and
hundreds of others. A full reference is available at
{browse "https://developer.mozilla.org/en-US/docs/Web/CSS/named-color":MDN Web Docs}.


{marker palette}{...}
{title:Palette integration}

{pstd}
{cmd:calligram} integrates with Ben Jann's
{browse "https://repec.sowi.unibe.ch/stata/palettes/":colorpalette} package.
Install from SSC if needed:

{phang2}{cmd:. ssc install palettes, replace}{p_end}
{phang2}{cmd:. ssc install colrspace, replace}{p_end}
{phang2}{cmd:. ssc install moremata, replace}{p_end}

{pstd}
When {cmd:palette(}{it:name}{cmd:)} is specified, {cmd:calligram} internally
calls {cmd:colorpalette} {it:name}{cmd:, n(}{it:nplaced}{cmd:) nograph}, where
{it:nplaced} is the number of words successfully placed in the layout. The
palette is automatically interpolated or cycled to exactly that number of
colors. Colors returned by {cmd:colorpalette} as Stata RGB triplets
({it:"R G B"}) are converted to CSS {cmd:rgb(R,G,B)} notation for the HTML.

{pstd}
Some commonly used palette names:

{p2colset 5 20 21 2}{...}
{p2col:{it:Name}}Description{p_end}
{p2line}
{p2col:{cmd:Set1}}ColorBrewer qualitative, high contrast{p_end}
{p2col:{cmd:Set2}}ColorBrewer qualitative, pastel tones{p_end}
{p2col:{cmd:Set3}}ColorBrewer qualitative, 12 colors{p_end}
{p2col:{cmd:Dark2}}ColorBrewer qualitative, darker tones{p_end}
{p2col:{cmd:Accent}}ColorBrewer qualitative with accents{p_end}
{p2col:{cmd:Paired}}ColorBrewer qualitative, paired colors{p_end}
{p2col:{cmd:tableau}}Tableau 10 (Tableau's default palette){p_end}
{p2col:{cmd:viridis}}Perceptually uniform, blue-green-yellow{p_end}
{p2col:{cmd:plasma}}Perceptually uniform, purple-orange{p_end}
{p2col:{cmd:magma}}Perceptually uniform, black-purple-yellow{p_end}
{p2col:{cmd:inferno}}Perceptually uniform, black-red-yellow{p_end}
{p2line}
{p2colreset}{...}

{pstd}
If {cmd:palette()} is not specified, {cmd:calligram} uses a built-in
ten-color Tableau-inspired palette that cycles for word counts above ten.


{marker export}{...}
{title:Export}

{pstd}
Images are saved from the HTML page in a browser, with the side panel's
{bf:Save image} buttons (or, with {cmd:notoolbar}, the single button added by
{cmd:export()}); they cannot be triggered from within Stata. Files are named
after {cmd:savefile()} and go to the browser's download folder. What is saved is
what is on screen: zoom, hidden words, background and colours.

{pstd}
{ul:PNG and JPG} — The SVG is drawn onto an off-screen HTML5 Canvas at twice
its pixel size. The background is filled first with the current background
color (important for JPG,
which cannot represent transparency), and the canvas is then exported via the
browser's {cmd:toDataURL()} API. This is entirely client-side and requires no
additional software.

{pstd}
{ul:SVG} — The SVG element is serialised directly using the browser's
{cmd:XMLSerializer} and downloaded as a vector file. SVG output scales without
quality loss and can be edited in vector graphics applications.


{marker shapes}{...}
{title:Shapes and masks}

{pstd}
By default words fill the whole canvas. {cmd:shape()} restricts them to an
outline and {cmd:mask()} to the dark part of an image. Inside the outline the
cloud is packed the same way: largest words first, smaller words in the gaps.
Small or narrow shapes hold fewer words at a given size, so sizes come out
smaller; if a few rarely used words still do not fit, they are left out and
reported. A canvas with the same proportions as the shape gives the largest
words, for example:

{phang2}{cmd:. calligram, textvar(response) shape(circle) width(600) height(600)}{p_end}
{phang2}{cmd:. calligram, textvar(response) shape(cloud)}{p_end}
{phang2}{cmd:. calligram, textvar(response) shape(heart) rotate(random) width(600) height(560)}{p_end}
{phang2}{cmd:. calligram, textvar(response) mask(logo.png) bgcolor(white)}{p_end}
{phang2}{cmd:. calligram, textvar(response) shape(star) outline}{p_end}
{phang2}{cmd:. calligram, textvar(response) by(country) shape(cloud) outline}{p_end}
{phang2}{cmd:. calligram, textvar(response) mask(logo.png) outlinecolor(#4e79a7) outlinewidth(3)}{p_end}

{pstd}
For a mask, any image with a dark silhouette on a white (or transparent)
background works, such as a logo, a country outline, or a pictogram exported
from another program.


{marker browser}{...}
{title:In the browser}

{pstd}
The HTML page is interactive. A slim header shows the title, the number of
words, and (with {cmd:by()}) a tab for each group. The cloud fills the rest of
the window. On the right is a panel that can be open, with labelled controls,
or collapsed to a narrow column of icons with a vertical slider; it starts open
on wide screens. The panel offers:

{phang2}{bf:Search} {hline 2} type part of a word; matching words stay bright, the
rest fade, and the word list shows only matches.{p_end}
{phang2}{bf:Minimum count} {hline 2} a slider that hides words seen fewer times
than the chosen count, to see which themes remain.{p_end}
{phang2}{bf:Top words} {hline 2} the words ranked by count, each with a bar
in its cloud colour. Hovering a row highlights the word in the cloud; clicking
a row hides or shows it. The list shows the top 15, or all words on
request.{p_end}
{phang2}{bf:Hide words} {hline 2} clicking a word in the cloud hides it too (for
example a word that should have been a stopword); {bf:Show hidden words} brings
them back. Hidden words leave a gap; rerun {cmd:calligram} with
{cmd:stopwords()} to repack the cloud without them.{p_end}
{phang2}{bf:View} {hline 2} zoom with the mouse wheel or the buttons, drag to
move around, reset, and fullscreen.{p_end}
{phang2}{bf:Appearance} {hline 2} switch between a light and a dark background,
and recolour the words with another palette (Tableau 10, Viridis, Warm, Cool,
Greys) or go back to the colours as drawn.{p_end}
{phang2}{bf:Save image} {hline 2} download what is on screen (including zoom,
hidden words, background and colours) as PNG, SVG, or JPG, at twice the
canvas's pixel size.{p_end}

{pstd}
Hovering over a word shows a card with its count, its rank, and its share of
all word mentions in the cloud; the other words fade slightly so it stands out.
Words fade in, largest first, when the page opens and each time you switch to
another group's tab (not if the computer is set to reduce motion).

{pstd}
{bf:Keyboard shortcuts:} {cmd:/} search, {cmd:Esc} clear search, {cmd:+} and
{cmd:-} zoom, {cmd:0} reset zoom, {cmd:F} fullscreen, {cmd:P} open or collapse
the panel, {cmd:T} light or dark background, {cmd:C} next palette, {cmd:H} show
hidden words, the left and right arrows switch groups, and {cmd:?} lists the
shortcuts.

{pstd}
Nothing in the panel changes the layout itself: sizes and positions are those
computed by {cmd:calligram}. The panel is part of the HTML file, so it works
offline and wherever the file is opened. {cmd:notoolbar} leaves it out.


{marker examples}{...}
{title:Examples}

{pstd}
All examples below use the following synthetic dataset of open-ended survey
responses. Enter or load it before running any of the examples.

{phang2}{cmd:clear}{p_end}
{phang2}{cmd:input str200 response}{p_end}
{phang2}{cmd:"The product quality is excellent and the service was outstanding"}{p_end}
{phang2}{cmd:"Great quality but delivery was slow and customer service needs improvement"}{p_end}
{phang2}{cmd:"Amazing experience with the product and very helpful support team"}{p_end}
{phang2}{cmd:"Poor quality product arrived damaged and customer service was unhelpful"}{p_end}
{phang2}{cmd:"Outstanding quality and excellent delivery speed highly recommend"}{p_end}
{phang2}{cmd:"The service team was helpful but the product quality could be better"}{p_end}
{phang2}{cmd:"Excellent customer experience product quality exceeded my expectations"}{p_end}
{phang2}{cmd:"Good quality product but packaging was damaged during delivery"}{p_end}
{phang2}{cmd:"Highly recommend excellent quality and very fast delivery service"}{p_end}
{phang2}{cmd:"The support team was amazing and the product quality is outstanding"}{p_end}
{phang2}{cmd:"Product quality is good but customer service response was very slow"}{p_end}
{phang2}{cmd:"Great delivery service but product quality did not meet expectations"}{p_end}
{phang2}{cmd:"Excellent quality product and outstanding customer service experience"}{p_end}
{phang2}{cmd:"The product arrived damaged but the customer service team was helpful"}{p_end}
{phang2}{cmd:"Amazing support team excellent delivery and outstanding product quality"}{p_end}
{phang2}{cmd:end}{p_end}

{pstd}{ul:Example 1 — Basic call using all defaults}{p_end}

{pstd}
The simplest usage: just point {cmd:calligram} at the text variable.
The built-in English stopword list is applied, words appearing fewer than
twice are dropped, and the result is saved as {cmd:calligram.html} in the
current working directory.

{phang2}{cmd:. calligram, textvar(response)}{p_end}

{pstd}{ul:Example 2 — Full customisation with export}{p_end}

{pstd}
A fully customised call matching the options available in {cmd:calligram}.
This example uses all words (including rare ones), suppresses the built-in
stopword list, applies the Tableau color palette on a white background,
adjusts canvas dimensions and font scaling, and embeds a PNG download button.

{phang2}
{cmd:. calligram,}{break}
{cmd:      textvar(response)}{break}
{cmd:      maxwords(80)}{break}
{cmd:      minfreq(1)}{break}
{cmd:      minlength(4)}{break}
{cmd:      title("Customer Feedback Word Cloud", color(rgb(100,100,100)) size(4))}{break}
{cmd:      palette(tableau)}{break}
{cmd:      width(1000)}{break}
{cmd:      height(550)}{break}
{cmd:      margin(1)}{break}
{cmd:      maxfontsize(100)}{break}
{cmd:      minfontsize(10)}{break}
{cmd:      nostopwords}{break}
{cmd:      bgcolor(rgb(255,255,255))}{break}
{cmd:      savefile("feedback_cloud.html")}{break}
{cmd:      export(png)}
{p_end}

{pstd}
To open the saved HTML file in your default browser after running the command:

{phang2}{cmd:. shell start feedback_cloud.html}{space 5}{it:(Windows)}{p_end}
{phang2}{cmd:. shell open feedback_cloud.html}{space 6}{it:(Mac)}{p_end}
{phang2}{cmd:. shell xdg-open feedback_cloud.html}{space 3}{it:(Linux)}{p_end}

{pstd}{ul:Example 3 — Variations on title and color}{p_end}

{pstd}
Exploring different title and background color options on the same data.

{phang2}{cmd:. calligram, textvar(response) title("Customer Feedback")}{p_end}

{phang2}{cmd:. calligram, textvar(response) title("Customer Feedback", color(#ff6b6b) size(2em))}{p_end}

{phang2}{cmd:. calligram, textvar(response) title("Customer Feedback", color(rgb(0,128,255)) size(2em)) bgcolor(#1a1a2e)}{p_end}

{phang2}{cmd:. calligram, textvar(response) title("Customer Feedback", color(white) size(28px)) bgcolor(#2c3e50)}{p_end}

{pstd}{ul:Example 4 — Color palettes}{p_end}

{pstd}
Requires {cmd:colorpalette} and {cmd:colrspace} from SSC. If not installed,
{cmd:calligram} falls back to the built-in tab10 palette with a warning.

{phang2}{cmd:. calligram, textvar(response) palette(Set1)}{p_end}

{phang2}{cmd:. calligram, textvar(response) palette(Dark2) bgcolor(white)}{p_end}

{phang2}{cmd:. calligram, textvar(response) palette(viridis) bgcolor(#16213e)}{p_end}

{pstd}{ul:Example 5 — Filtering and stopwords}{p_end}

{pstd}
Tighten the word selection by raising frequency and length thresholds, or
provide domain-specific stopwords to remove alongside the built-in list.

{phang2}{cmd:. calligram, textvar(response) minfreq(3) minlength(5)}{p_end}

{phang2}{cmd:. calligram, textvar(response) minfreq(1) nostopwords}{p_end}

{phang2}{cmd:. calligram, textvar(response) stopwords(product service) minfreq(2)}{p_end}

{pstd}{ul:Example 6 — Static export formats}{p_end}

{phang2}{cmd:. calligram, textvar(response) savefile(feedback_cloud.html) export(png)}{p_end}

{phang2}{cmd:. calligram, textvar(response) savefile(feedback_cloud.html) export(jpg)}{p_end}

{phang2}{cmd:. calligram, textvar(response) savefile(feedback_cloud.html) export(svg)}{p_end}

{pstd}{ul:Example 7 — Using your own data}{p_end}

{pstd}
Replace the synthetic data above with a real survey dataset. The variable
passed to {cmd:textvar()} must be a string variable; all observations are
pooled before processing.

{phang2}
{cmd:. use "your_survey_data.dta", clear}{break}
{p_end}

{phang2}
{cmd:. calligram,}{break}
{cmd:      textvar(open_ended_comments)}{break}
{cmd:      maxwords(120)}{break}
{cmd:      minfreq(3)}{break}
{cmd:      title("Open-Ended Survey Responses")}{break}
{cmd:      savefile("survey_wordcloud.html")}
{p_end}


{pstd}
{bf:Rotation, fonts and gradients}

{phang2}{cmd:. calligram, textvar(response) minfreq(1) rotate(90)}{p_end}
{phang2}{cmd:. calligram, textvar(response) minfreq(1) rotate(random) font(Verdana)}{p_end}
{phang2}{cmd:. calligram, textvar(response) minfreq(1) gradient(#ff6b6b #4ecdc4)}{p_end}
{phang2}{cmd:. calligram, textvar(response) minfreq(1) gradient(navy gold) bgcolor(white)}{p_end}
{phang2}{cmd:. return list}{p_end}


{marker weights}{...}
{title:Weights}

{pstd}
With weights, every word in a response counts with that response's weight
instead of once, so word sizes and ranks reflect the weighted share of
mentions, for example with survey sampling weights. All weight types give the
same result here, because only the relative sizes of the counts matter;
{cmd:fweight}s must be whole numbers. {cmd:minfreq()} and the tests in
{cmd:phrases} use the plain number of occurrences, so a word mentioned once by
a heavily weighted respondent is still a single mention. The hover card shows
the weighted count.

{marker offline}{...}
{title:Offline and online pages}

{pstd}
By default the page works fully offline and looks the same on every computer.
Everything is inside the one HTML file: the cloud, the side panel, and the
words themselves, each stored as the exact outlines of its letters (SVG
paths) in the font used to lay out the cloud. Nothing is loaded from the
internet, the viewer does not need the font, and words can never overlap
because of a different font on the viewer's computer. Saving images (PNG,
SVG, JPG) from the panel gives exactly what is on screen.

{pstd}
With {cmd:online}, words are written as text instead. For the bundled fonts
the page loads the font from Google Fonts when opened. As a safeguard, every
word also carries its exact width from the layout, so if a viewer's browser has
to use a substitute font (no internet, or the font is blocked), it stretches or
squeezes each word to that width and words keep the space the layout gave them
side by side. Files are much
smaller (the letter outlines take roughly 1-2 KB per word) and words can be
selected and copied as text. Without an
internet connection, or with a font that is not bundled and not installed on
the viewer's computer, the browser substitutes another font and words may
touch. Images saved from the panel may also use a substitute font, because
browsers do not pass web fonts to saved images. For reports and sharing,
keep the default.

{pstd}
{bf:Font licences.} The bundled fonts are free and are included unmodified
with their licences: Arimo, Tinos, Open Sans, Lato, Noto Sans and Merriweather
under the SIL Open Font License 1.1, and Roboto under the Apache License 2.0.
The licence files are inside {cmd:calligram.jar} (folder
{cmd:calligram/fonts}) and in the package's {cmd:src/calligram/fonts}
folder. The licences allow the fonts to be used, bundled and redistributed,
including in the pages {cmd:calligram} creates.

{marker pipeline}{...}
{title:Processing pipeline}

{pstd}
{cmd:calligram} does not change or copy your data. It works in these steps:

{phang}
{bf:Steps 1-5 — Reading, cleaning and counting.}
The Java engine reads the selected observations (those meeting {cmd:if} and
{cmd:in}, with non-empty text) directly from memory, one batch at a time, and
worker threads clean, split and count the words. Unless {cmd:noclean} is
specified, text is put in a standard Unicode form, lowercased, apostrophes are
removed (so {it:don't} becomes {it:dont}; with French, elided articles such as
{it:l'} are split off), a hyphen between two letters or digits stays inside the
word ({it:sci-fi}), and any other character that is not a letter or digit
separates words. Tokens made only of digits, words shorter
than {cmd:minlength()}, and stopwords are dropped. Words seen fewer than
{cmd:minfreq()} times are dropped and the {cmd:maxwords()} most frequent are
kept per group, ties in alphabetical order. Plurals are merged with their
singulars where both occur. With {cmd:phrases}, the text is read twice: the
first pass counts words and pairs of neighbouring words and picks the phrases
(see {help calligram##options:phrases}), the second counts again with the
phrases joined.

{phang}
{bf:Steps 6-8 — Sizing and layout.}
Each group's cloud is laid out on a pixel grid of the canvas in which
everything outside the shape or mask counts as occupied, stored as bits, 64
pixels per number. Words are placed largest first; each word's size follows
from the previous word's through {cmd:scaling()}. For each word a few random
positions are tested a row at a time, and if none is free every position is
checked at once with a bit-parallel scan, which either picks a free position
at random (using {cmd:seed()}) or shows that none exists; then the other
orientation is tried (with rotation), and then the word is made slightly
smaller, down to {cmd:minfontsize()}. Only the word's letter pixels, widened by
{cmd:margin()}, are then marked as occupied, so smaller words can fit into the
gaps. The starting size is found automatically unless {cmd:maxfontsize()} is
given, and if the words that fit carry less than 95% of all mentions, smaller
starting sizes are tried (in parallel). With {cmd:by()}, groups are laid out in parallel.

{pmore}
If Java is unavailable, a slower Stata/Mata pipeline is used instead: the
selected text is copied, split into one row per word and counted with
{cmd:contract}, sizes are estimated from character counts, and words are kept
apart by their rectangles. Shapes, masks, outlines and the side panel need
the Java engine.

{phang}
{bf:Step 9 — Color assignment.}
Colors come from {cmd:gradient()}, from {cmd:palette()} via
{cmd:colorpalette}, or from the built-in ten-color palette, cycling for larger
word counts.

{phang}
{bf:Step 10 — HTML output.}
A self-contained HTML file is written containing the SVG cloud, hover
tooltips, and (if {cmd:export()} is specified) an in-browser export button.
Word text is HTML-escaped, so characters such as {cmd:<} or {cmd:&} display
correctly.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:calligram} stores the following in {cmd:r()}:

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_obs)}}number of observations whose text was used{p_end}
{synopt:{cmd:r(N_phrases)}}number of two-word phrases joined{p_end}
{synopt:{cmd:r(online)}}1 with {cmd:online} (words as text), 0 for exact letter outlines{p_end}
{synopt:{cmd:r(N_words)}}number of words after filtering (before layout); with {cmd:by()}, summed over groups{p_end}
{synopt:{cmd:r(N_placed)}}number of words placed; with {cmd:by()}, summed over groups{p_end}
{synopt:{cmd:r(maxfontsize)}}largest font size used{p_end}
{synopt:{cmd:r(java)}}1 if the Java layout engine was used, 0 if the Mata fallback{p_end}
{synopt:{cmd:r(outline)}}1 if an outline was drawn{p_end}
{synopt:{cmd:r(toolbar)}}1 if the page has the side panel{p_end}
{synopt:{cmd:r(N_groups)}}with {cmd:by()}: number of groups drawn{p_end}

{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(savefile)}}full path of the HTML file written{p_end}
{synopt:{cmd:r(shape)}}shape used{p_end}
{synopt:{cmd:r(saving)}}the dataset saved by {cmd:saving()}{p_end}
{synopt:{cmd:r(image)}}the image file(s) written by {cmd:image()}{p_end}
{p2colreset}{...}


{marker authors}{...}
{title:Authors}

{pstd}
{bf:Fahad Mirza} (Author)

{pmore}
{browse "https://www.linkedin.com/in/fahad-mirza/":LinkedIn}{space 3}
{browse "https://medium.com/@fahad-mirza": Medium Blog}{space 3}
{browse "https://github.com/fahad-mirza/":GitHub}

{pstd}
{bf:Claude} (Anthropic) | Editor and Co-developer. This program was built
collaboratively between the author and Claude, which assisted with algorithm
implementation, debugging, and feature development.

{title:Note}

{pstd}
{cmd:calligram} is currently in {bf:Beta}. The core functionality is stable
but improvements, new options, and refinements are planned over time. Feedback
and bug reports are welcome via the project GitHub page.

{pstd}
{cmd:calligram} requires Stata 17 or later. The layout engine is the
{cmd:calligram.jar} file installed alongside the command; it runs on the Java
runtime that ships with Stata, so nothing else needs to be installed. The {cmd:palette()} option additionally requires {cmd:colorpalette}
and {cmd:colrspace} by Ben Jann (available from SSC).


{title:Also see}

{psee}
{bf:Project repository:} {browse "https://github.com/fahad-mirza/calligram_Stata_stata":calligram on GitHub}
{p_end}


{psee}
{bf:Dependency:} {browse "https://repec.sowi.unibe.ch/stata/palettes/":colorpalette documentation (Ben Jann)}
{p_end}
