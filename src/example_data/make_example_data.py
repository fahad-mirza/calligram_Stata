# Builds cg_countries.dta / cg_countries_shp.dta (Stata shapefile format) and cg_cities.dta
# from Natural Earth (public domain): ne_50m_admin_0_countries.geojson, ne_50m_populated_places_simple.geojson
import json, numpy as np, pandas as pd
c=json.load(open('ne_50m_admin_0_countries.geojson',encoding='utf-8'))['features']
c=sorted([f for f in c if f['properties']['CONTINENT']!='Antarctica'], key=lambda f:f['properties']['NAME'])
attr=[]; pts=[]
for i,f in enumerate(c,1):
    p=f['properties']; g=f['geometry']
    polys=[g['coordinates']] if g['type']=='Polygon' else g['coordinates']
    order=0; big=None
    for poly in polys:
        for ring in poly:
            order+=1; pts.append((i,np.nan,np.nan,order))       # each part starts with a missing point
            for lon,lat in ring:
                order+=1; pts.append((i,float(lon),float(lat),order))
            if big is None or len(ring)>len(big): big=ring
    attr.append({'_ID':i,'_CX':float(np.mean([q[0] for q in big])),'_CY':float(np.mean([q[1] for q in big])),
                 'name':p['NAME'],'iso3':p['ADM0_A3'],'continent':p['CONTINENT']})
pd.DataFrame(attr).to_stata('cg_countries.dta',write_index=False,version=118)
pd.DataFrame(pts,columns=['_ID','_X','_Y','shape_order']).to_stata('cg_countries_shp.dta',write_index=False,version=118)
cont={f['properties']['ADM0_A3']:f['properties']['CONTINENT'] for f in json.load(open('ne_50m_admin_0_countries.geojson',encoding='utf-8'))['features']}
pl=json.load(open('ne_50m_populated_places_simple.geojson',encoding='utf-8'))['features']
d=pd.DataFrame([{'city':f['properties']['name'],'country':f['properties']['adm0name'],'continent':cont.get(f['properties'].get('adm0_a3'),''),
                 'lat':float(f['properties']['latitude']),'lon':float(f['properties']['longitude']),'population':float(f['properties']['pop_max'])} for f in pl])
d=d[(d.population>0)&(d.continent!='Antarctica')].sort_values('population',ascending=False).drop_duplicates(['city','country'])
d.to_stata('cg_cities.dta',write_index=False,version=118)
