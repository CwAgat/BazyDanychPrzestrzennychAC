
--import warstw
--PS C:\Users\Agata\SEMESTR5\BAZYPRZESTRZENNE\cw3> "C:\Program Files\PostgreSQL\16\bin\shp2pgsql.exe" -I -s 4326 T2018_KAR_BUILDINGS.shp public.buildings | "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d niemcy -h localhost

--1--
--Znajdź budynki, które zostały wybudowane lub wyremontowane na przestrzeni roku 
--(zmiana pomiędzy 2018 a 2019).

--opcja 1 łączenie po id
SELECT b2019.polygon_id, b2018.polygon_id
FROM buildings2019 b2019
LEFT JOIN buildings2018 b2018
ON b2019.polygon_id = b2018.polygon_id
WHERE b2018.polygon_id IS NULL
OR NOT ST_Equals(b2019.geom, b2018.geom);

--opcja 2 łączenie po geometrii
SELECT b2019.polygon_id as id19, b2018.polygon_id as id18
FROM buildings2019 b2019
LEFT JOIN buildings2018 b2018
ON ST_Equals(b2019.geom, b2018.geom)
WHERE b2018.polygon_id IS NULL;

--to zwróci tylko nowe budynki
--SELECT b2019.polygon_id
--FROM buildings2019 b2019
--EXCEPT
--SELECT b2018.polygon_id
--FROM buildings2018 b2018;

--UWAGA TO ROBI CROSS JOINA  !!!!!!!!!
--SELECT b8.polygon_id, b9.polygon_id
--FROM  buildings2018 b8, buildings2019 b9;

--2--
--Znajdź ile nowych POI pojawiło się w promieniu 500 m od wyremontowanych lub
--wybudowanych budynków, które znalezione zostały w zadaniu 1. Policz je wg ich kategorii.

--w przypadku tabeli z punktami łączenie po id daje inne wyniki niż po geom, ale skoro chodzi nam o to co zmieniło się w przestrzeni to łączę po geom

WITH new_buildings AS (
  SELECT b2019.*
  FROM buildings2019 b2019
  LEFT JOIN buildings2018 b2018
    ON b2019.polygon_id = b2018.polygon_id
    WHERE b2018.polygon_id IS NULL 
	OR NOT ST_Equals(b2019.geom, b2018.geom)
),
new_points AS (
  SELECT p2019.*
  FROM points2019 p2019
  LEFT JOIN points2018 p2018
    ON ST_Equals(p2019.geom, p2018.geom)
    WHERE p2018.geom IS NULL

)
SELECT p.type, COUNT(DISTINCT p.poi_id) AS liczba_poi
FROM new_points p
JOIN new_buildings b
  ON ST_DWithin(p.geom::geography, b.geom::geography, 500)
GROUP BY p.type
ORDER BY liczba_poi DESC;

--SELECT ST_SRID(p.geom) FROM points2019 p LIMIT 1;
--SELECT ST_SRID(b.geom) FROM buildings2019 b LIMIT 1;
--3--

CREATE TABLE streets_reprojected AS
SELECT 
    gid,link_id,st_name,ref_in_id,nref_in_id,func_class,speed_cat,fr_speed_l,to_speed_l,dir_travel,
    ST_Transform(geom, 3068) AS geom  
FROM streets2019;

--SELECT ST_SRID(geom) FROM streets2019 LIMIT 1;
--SELECT ST_SRID(geom) FROM input_points LIMIT 1;
--drop table input_points cascade;

--4--
--Stwórz tabelę o nazwie ‘input_points’ i dodaj do niej dwa rekordy o geometrii punktowej.
--Użyj następujących współrzędnych:
--X Y
-- 8.36093 49.03174
-- 8.39876 49.00644

CREATE TABLE input_points (
	point_id SERIAL,
	geom GEOMETRY(POINT,0)
)

INSERT INTO input_points (geom)
VALUES 
	(ST_GeomFromText('POINT(8.36093 49.03174)',4326)),
	(ST_GeomFromText('POINT(8.39876 49.00644)',4326));
	
--5--
--Zaktualizuj dane w tabeli ‘input_points’ tak, aby punkty te były w układzie współrzędnych
--DHDN.Berlin/Cassini.
UPDATE input_points
SET geom = ST_Transform(geom, 3068);

--6--
--Znajdź wszystkie skrzyżowania, które znajdują się w odległości 200 m od linii zbudowanej
--z punktów w tabeli ‘input_points’. Wykorzystaj tabelę T2019_STREET_NODE. Dokonaj
--reprojekcji geometrii, aby była zgodna z resztą tabel.

--SELECT ST_SRID(geom_3068) FROM street_node2019 LIMIT 1;

ALTER TABLE street_node2019
ADD COLUMN geom_3068 geometry(POINT, 3068);

UPDATE street_node2019
SET geom_3068 = ST_Transform(geom, 3068);

WITH line_from_points AS (
    SELECT ST_MakeLine(geom) AS geom 
    FROM input_points
)
SELECT n.*
FROM street_node2019 n
JOIN line_from_points l
  ON ST_DWithin(n.geom_3068, l.geom, 200); 

--7--
--Policz jak wiele sklepów sportowych (‘Sporting Goods Store’ - tabela POIs) znajduje się
--w odległości 300 m od parków (LAND_USE_A).

SELECT DISTINCT p19.poi_id, p19.poi_name
FROM points2019 p19
JOIN landa lA
  ON ST_DWithin(p19.geom::geography, lA.geom::geography, 300) 
WHERE p19.type LIKE 'Sporting Goods Store' AND lA.type LIKE 'Park (City/County)'
ORDER BY p19.poi_name ASC;

--SELECT ST_SRID(p19.geom) FROM points2019 p19 LIMIT 1;
--SELECT ST_SRID(lA.geom) FROM landa lA LIMIT 1;


--8--
--Znajdź punkty przecięcia torów kolejowych (RAILWAYS) z ciekami (WATER_LINES). Zapisz
--znalezioną geometrię do osobnej tabeli o nazwie ‘bridges201998’.
SELECT ST_SRID(GEOM) FROM water_lines2019 LIMIT 1;

CREATE TABLE bridges2019 (
    id SERIAL PRIMARY KEY,
    geom geometry(Point, 4326)
);

INSERT INTO bridges2019 (geom)
SELECT ST_Intersection(r.geom, w.geom) AS geom
FROM railways2019 r
JOIN water_lines2019 w
  ON ST_Intersects(r.geom, w.geom)
WHERE ST_GeometryType(ST_Intersection(r.geom, w.geom)) = 'ST_Point';

