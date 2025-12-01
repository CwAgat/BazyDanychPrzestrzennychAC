--TWORZENIE RASTRÓW Z RASTRÓW

--ST_INTERSECTS

CREATE TABLE schema_agata.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

alter table schema_agata.intersects
add column rid SERIAL PRIMARY KEY;

CREATE INDEX idx_intersects_rast_gist ON schema_agata.intersects
USING gist (ST_ConvexHull(rast));

-- schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('schema_agata'::name,
'intersects'::name,'rast'::name);


--ST_CLIP

CREATE TABLE schema_agata.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

--ST_UNION

CREATE TABLE schema_agata.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);

--Oprócz powyższego przykładu, st_union pozwala również na operacje na nakładających się rastrach
--opartych na danej funkcji agregującej, a mianowicie FIRST LAST SUM COUNT MEAN lub RANGE. 
--Na przykład, jeśli mamy wiele rastrów z danymi o opadach atmosferycznych i potrzebujemy średniej
--wartości, możemy użyć st_union lub map_algebra. Aby uzyskać więcej informacji na temat st_union,
--sprawdź dokumentację: https://postgis.net/docs/RT_ST_Union.html


--TWORZENIE RASTRÓW Z WEKTORÓW
--ST_AsRaster

CREATE TABLE schema_agata.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--Przykładowe zapytanie używa piksela typu '8BUI' tworząc 8-bitową nieoznaczoną liczbę całkowitą (8-
--bit unsigned integer). Unsigned integer może reprezentować tylko nieujemne liczby całkowite; signed
--integer mogą również reprezentować liczby całkowite ujemne. Aby uzyskać więcej informacji o
--typach rastrowych PostGIS, zapoznaj się z dokumentacją:
--https://postgis.net/docs/RT_ST_BandPixelType.html


--Wynikowy raster z poprzedniego zadania to jedna parafia na rekord, na wiersz tabeli. Użyj QGIS lub
--ArcGIS do wizualizacji wyników.
--Drugi przykład łączy rekordy z poprzedniego przykładu przy użyciu funkcji ST_UNION w pojedynczy
--raster.

--ST_UNION

DROP TABLE schema_agata.porto_parishes; --> drop table porto_parishes first
CREATE TABLE schema_agata.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto'

--ST_Tile

DROP TABLE schema_agata.porto_parishes; --> drop table porto_parishes first
CREATE TABLE schema_agata.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-
32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--Rastry na wektory
-- https://postgis.net/docs/RT_reference.html#Raster_Processing_Geometry

--st_intersection
create table schema_agata.intersection as
SELECT
a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)
).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--ST_DumpAsPolygons - konwertuje rastry w poligony (wektory)
CREATE TABLE schema_agata.dumppolygons AS
SELECT
a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

-- obie metody zwracają typ geoval

--ANALIZA RASTRÓW
--ST_Band - wyodrębnianie pasm z rastra

CREATE TABLE schema_agata.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

CREATE TABLE schema_agata.landsat_blue AS
SELECT rid, ST_Band(rast,3) AS rast
FROM rasters.landsat8;

-- ST_CLip -może byc używane do wycięcia rastra z innego eastra

CREATE TABLE schema_agata.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--ST_Slope
CREATE TABLE schema_agata.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM schema_agata.paranhos_dem AS a

--ST_Reclass
CREATE TABLE schema_agata.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3',
'32BF',0)
FROM schema_agata.paranhos_slope AS a;

--ST_SummaryStats
SELECT st_summarystats(a.rast) AS stats
FROM schema_agata.paranhos_dem AS a;


--ST_SummaryStats oraz Union
SELECT st_summarystats(ST_Union(a.rast))
FROM schema_agata.paranhos_dem AS a;

--ST_SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (
SELECT st_summarystats(ST_Union(a.rast)) AS stats
FROM schema_agata.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

 --ST_SummaryStats w połączeniu z GROUP BY
WITH t AS (
SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast,
b.geom,true))) AS stats
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

 --ST_Value
 SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;


--TPI (Topographic Position Index)

--ST_TPI
create table schema_agata.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

CREATE INDEX idx_tpi30_rast_gist ON schema_agata.tpi30
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('schema_agata'::name,
'tpi30'::name,'rast'::name);

--Algebra map

CREATE TABLE schema_agata.porto_ndvi AS
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
FROM r

CREATE INDEX idx_porto_ndvi_rast_gist ON schema_agata.porto_ndvi
USING gist (ST_ConvexHull(rast));


SELECT AddRasterConstraints('schema_agata'::name,
'porto_ndvi'::name,'rast'::name);


--funkcja zwrotna
create or replace function schema_agata.ndvi(
value double precision [] [] [],
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debugpurposes
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value
[1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;
--
CREATE TABLE schema_agata.porto_ndvi2 AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'schema_agata.ndvi(double precision[],
integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
) AS rast
FROM r;

CREATE INDEX idx_porto_ndvi2_rast_gist ON schema_agata.porto_ndvi2
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('schema_agata'::name,
'porto_ndvi2'::name,'rast'::name);


--export
SELECT ST_AsTiff(ST_Union(rast))
FROM schema_agata.porto_ndvi;


SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
FROM schema_agata.porto_ndvi;

SELECT ST_GDALDrivers();
