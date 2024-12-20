-- pg_restore -U marcin --dbname=lab67 postgis_raster.backup

ALTER SCHEMA schema_name RENAME TO makulec;

-- raster2pgsql -s 3763 -N -32767 -t 100x100 -I -C -M -d srtm_1arc_v3.tif rasters.dem | psql -d lab67 -U marcin
-- raster2pgsql -s 3763 -N -32767 -t 128x128 -I -C -M -d Landsat8_L1TP_RGBN.tif rasters.landsat8 | psql -d lab67 -U marcin

SELECT * FROM raster_columns;

CREATE TABLE makulec.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

alter table makulec.intersects
add column rid SERIAL PRIMARY KEY;

CREATE INDEX idx_intersects_rast_gist ON makulec.intersects
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('makulec'::name,
'intersects'::name,'rast'::name);

CREATE TABLE makulec.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

CREATE TABLE makulec.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);

CREATE TABLE makulec.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

DROP TABLE makulec.porto_parishes;
CREATE TABLE makulec.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

create table makulec.intersection as
SELECT
a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)
).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

CREATE TABLE makulec.dumppolygons AS
SELECT
a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);


CREATE TABLE makulec.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;


CREATE TABLE makulec.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);


CREATE TABLE makulec.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM makulec.paranhos_dem AS a;

CREATE TABLE makulec.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3',
'32BF',0)
FROM makulec.paranhos_slope AS a;

SELECT st_summarystats(a.rast) AS stats
FROM makulec.paranhos_dem AS a;

SELECT st_summarystats(ST_Union(a.rast))
FROM makulec.paranhos_dem AS a;

WITH t AS (
SELECT st_summarystats(ST_Union(a.rast)) AS stats
FROM makulec.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

WITH t AS (
SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast,
b.geom,true))) AS stats
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;

create table makulec.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

CREATE INDEX idx_tpi30_rast_gist ON makulec.tpi30
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('makulec'::name,
'tpi30'::name,'rast'::name);

-- samodzielne
create table makulec.tpi30_porto as
select ST_TPI(a.rast,1) as rast
from makulec.intersects a;

CREATE INDEX idx_tpi30_porto_rast_gist ON makulec.tpi30_porto
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('makulec'::name,
'tpi30_porto'::name,'rast'::name);










CREATE TABLE makulec.porto_ndvi AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] +
[rast1.val])::float','32BF'
) AS rast
FROM r;

CREATE INDEX idx_porto_ndvi_rast_gist ON makulec.porto_ndvi
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('makulec'::name,
'porto_ndvi'::name,'rast'::name);

create or replace function makulec.ndvi(
value double precision [] [] [],
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value[1][1][1]);
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;


CREATE TABLE makulec.porto_ndvi2 AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'makulec.ndvi(double precision[],
integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
) AS rast
FROM r;

CREATE INDEX idx_porto_ndvi2_rast_gist ON makulec.porto_ndvi2
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('makulec'::name,
'porto_ndvi2'::name,'rast'::name);





















