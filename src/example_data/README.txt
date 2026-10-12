How the example data were made (all sources are public domain)

cg_countries.dta, cg_countries_shp.dta
    Natural Earth 1:50m countries (ne_50m_admin_0_countries), Antarctica left out,
    in Stata's shapefile format as made by spshape2dta: cg_countries.dta has one row
    per country (_ID, _CX, _CY, name, iso3, continent); cg_countries_shp.dta has the
    boundary points (_ID, _X = longitude, _Y = latitude, shape_order), each polygon
    part starting with a row of missing coordinates. (make_example_data.py)

cg_cities.dta
    Natural Earth 1:50m populated places: city, country, continent, latitude,
    longitude and pop_max (population of the city and its surroundings). Cities
    with no population, in Antarctica, or listed twice (same name and country) are
    left out.

cg_inaugural.dta
    The 60 US presidential inaugural addresses 1789-2025 (NLTK "inaugural"
    corpus), one row per paragraph, with year, president and century.

cg_alice.dta
    Lewis Carroll, Alice's Adventures in Wonderland (1865), Project Gutenberg text
    from the NLTK "gutenberg" corpus, one row per paragraph, with chapter number
    and title.

Your own maps: any shapefile (name.shp + name.dbf) becomes name.dta and
name_shp.dta with Stata's  spshape2dta name ; use shapes(name_shp.dta).
