-- 2

--CREATE DATABASE IF NOT EXISTS public.uk_250k
--CREATE EXTENSION postgis;
--CREATE EXTENSION raster;

--DROP TABLE IF EXISTS public.uk_250k;

-- załadowanie danych bezpośrednio do bazy za pomoca narzędzia raster2pgsql

-- "C:\Program Files\PostgreSQL\16\bin\raster2pgsql.exe" -s 27700 -t 100x100\
---I -C -M -d "*.tif" public.uk_250k | "C:\Program Files\PostgreSQL\16\bin\psql.exe"\
---U postgres -d uk_lab7 -h localhost -p 5432


-- sprawdzenie ile kafelków załadowano
SELECT count(*) FROM public.uk_250k;
SELECT count(*) FROM public.ras_250gb_withouttiles;
SELECT count(*) FROM public.mosaic_union_1_10;
SELECT count(*) FROM public.b4;


--3 
-- Połączenie wszystkich kafli w mozaike ostatecznie również zrobiłam za pomocą gdala,
-- ponieważ próby wykonania tej operacji w pgadminie kończyły się zawieszeniem komputera.
-- Najpierw narzędziem gdalbuildvrt połączyłam kafle w jeden plik wirtualny, a następnie 
-- uzywając narzędzia gdal_translate wyexportowałam do formatu GeoTiFF

--gdalbuildvrt "C:/Users/Agata/SEMESTR5/BAZYPRZESTRZENNE/cw7/DANE/ras_250gb_mozaika.vrt"\
--C:/Users/Agata/SEMESTR5/BAZYPRZESTRZENNE/cw7/DANE/ras250_gb/data/*.tif

--gdal_translate "C:/Users/Agata/SEMESTR5/BAZYPRZESTRZENNE/cw7/DANE/ras_250gb_mozaika.vrt"\
--"C:/Users/Agata/SEMESTR5/BAZYPRZESTRZENNE/cw7/DANE/ras_250gb_mozaika.tif" -co COMPRESS=DEFLATE -a_srs EPSG:27700


--4 
-- dane w formacie gpkg - wektorowe

--5
-- Wgrałam dane do bazy na dwa sposoby: przes interface qgis oraz przez terminal z wykorzystaniemm narzędzia ogr2ogr

--C:\PROGRA~1\QGIS34~1.11>ogr2ogr -f "PostgreSQL"\
--PG:"host=localhost dbname=uk_lab7 user=postgres password=#Postgres"\
--"C:\Users\Agata\SEMESTR5\BAZYPRZESTRZENNE\cw7\DANE\OS_Open_Zoomstack\OS_Open_Zoomstack.gpkg"\
--national_parks -nln national_parks1 -lco GEOMETRY_NAME=geom -lco FID=id -nlt POLYGON -t_srs EPSG:27700

SELECT ST_SRID(geom) FROM national_parks LIMIT 1; --27700

-- 6 
CREATE TABLE lake_district AS
SELECT *
FROM public.national_parks
WHERE id = 1;

CREATE TABLE uk_lake_district_clip1 AS
SELECT ST_Clip(u.rast,1,p.geom) AS rast
FROM public.uk_250k u
JOIN public.national_parks p
	ON ST_Intersects(u.rast,p.geom)
WHERE p.id = 1;

CREATE INDEX idx_rast_gist ON public.uk_lake_district_clip1
USING gist (ST_ConvexHull(rast));
SELECT AddRasterConstraints('public'::name,
'uk_lake_district_clip1'::name,'rast'::name);


-- 7 export do geotiff
-- tym razem za pomocą large object

CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0, ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
 ) AS loid
FROM public.uk_lake_district_clip1;

SELECT lo_export(loid, 'C:\temp\myraster_lo.tif')
FROM tmp_out;

--dane w formacie.jp2

-- 9
-- połączenie dwóch zobrazowań dla kanału B03-Green oraz B08 - NIR w mozaikę za pomocą gdal analogicznie do punktu 3
-- załadowanie do bazy za pomoca raster2pgsql w oryginalnym układzie współrzędnych ESPG:32630

--dodanie kolumny z przetransformowanymi współrzędnymi
ALTER TABLE b3aa
ADD COLUMN rast_27700 raster;
UPDATE b3aa
SET rast_27700 = ST_Transform(rast, 27700);

ALTER TABLE b8aa
ADD COLUMN rast_27700 raster;
UPDATE b8aa
SET rast_27700 = ST_Transform(rast, 27700);

CREATE INDEX idx_b3aa_rast27700_gist
ON b3aa
USING gist (ST_ConvexHull(rast_27700));

CREATE INDEX idx_b8aa_rast27700_gist
ON b8aa
USING gist (ST_ConvexHull(rast_27700));

-- 10
--sprawdzenie układów współrzędnych
SELECT ST_SRID(rast_27700) FROM b3aa LIMIT 1;
SELECT ST_SRID(geom) FROM lake_district LIMIT 1;

--dla sprawdzenia
SELECT COUNT(*)
FROM b3aa b3
JOIN lake_district ld
ON ST_Intersects(ST_Transform(b3.rast,27700), ld.geom);

SELECT COUNT(*) AS b3_count
FROM b3aa b3
JOIN national_parks np
  ON ST_Intersects(ST_Transform(b3.rast,27700), np.geom)
WHERE np.id = 1;


CREATE TABLE ndwi_lake_district AS
SELECT
    ST_Clip(
        ST_MapAlgebra(
            b3.rast_27700,
            b8.rast_27700,
            'CASE 
                WHEN ([rast1.val] + [rast2.val]) = 0 THEN NULL
                ELSE ([rast1.val] - [rast2.val]) / ([rast1.val] + [rast2.val])
             END',
            '32BF'
        ),
        1,
        np.geom,
        true
    ) AS rast
FROM b3aa b3
JOIN b8aa b8
  ON b3.rid = b8.rid
JOIN national_parks np
  ON np.id = 1
WHERE ST_Intersects(b3.rast_27700, np.geom);

--warunek dla zabezpieczenia przed zerowymi wartościami

CREATE INDEX idx_ndwi_rast27700_gist
ON b3aa
USING gist (ST_ConvexHull(rast_27700));
SELECT AddRasterConstraints('public'::name,
'ndwi_lake_district'::name,'rast'::name);

-- 11
--export za pomocą gdal
--gdal_translate -co COMPRESS=DEFLATE -co ZLEVEL=9\
--PG:"host=localhost port=5432 dbname=uk_lab7\
--user=postgres password=#Postgres schema=public table=ndwi_lake_district mode=2"\
--C:\Users\Agata\SEMESTR5\BAZYPRZESTRZENNE\cw7\DANE\ndwi1.tiff

