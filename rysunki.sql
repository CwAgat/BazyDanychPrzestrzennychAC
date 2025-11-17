--CREATE EXTENSION postgis;
 CREATE TABLE obiekty (
	id SERIAL PRIMARY KEY,
	nazwa VARCHAR(50),
	geom GEOMETRY 
 );

 --a--linie+łuki/wężyk
 INSERT INTO obiekty (nazwa, geom)
 VALUES (
	'obiekt1',
	ST_GeomFromText('COMPOUNDCURVE(
		(0 1, 1 1),
		CIRCULARSTRING(1 1, 2 0, 3 1),
		CIRCULARSTRING(3 1, 4 2, 5 1),
		(5 1, 6 1)
	)',0)
 );

--b--serce z dziurą
 INSERT INTO obiekty (nazwa, geom)
 VALUES (
	'obiekt2',
	ST_GeomFromText('MULTICURVE(
		COMPOUNDCURVE(
			(10 6, 14 6),
			CIRCULARSTRING(14 6, 16 4, 14 2),
			CIRCULARSTRING(14 2, 12 0, 10 2),
			(10 2, 10 6)
		),
		COMPOUNDCURVE(
			CIRCULARSTRING(11 2, 12 3, 13 2),
			CIRCULARSTRING(13 2, 12 1, 11 2)
		)	
	)',0)
 );


--c-- trójkąt/obrys
 INSERT INTO obiekty (nazwa, geom)
 VALUES (
	'obiekt3',
	ST_GeomFromText(
		'MULTILINESTRING( 
			(10 17, 12 13, 7 15, 10 17))',0)
 );

--d-- niedomknięty obrys
 INSERT INTO obiekty (nazwa, geom)
 VALUES (
	'obiekt4',
	ST_GeomFromText(
		'LINESTRING 
			(20 20, 25 25, 27 24, 25 22, 26 21, 22 19, 20.5 19.5)',0)
 );

--e-- punkty 3D
  INSERT INTO obiekty (nazwa, geom)
 VALUES (
	'obiekt5',
	ST_GeomFromText(
		'MULTIPOINT( 
		(38 32 234),
		(30 30 59)
			)',0)
 );

--f-- linia+punkt
   INSERT INTO obiekty (nazwa, geom)
 VALUES (
	'obiekt6',
	ST_GeomFromText('GEOMETRYCOLLECTION
		(POINT(4 2),
		LINESTRING(1 1, 3 2)
		)',0)	
 );


 --2-- pole powierzchni bufora o wielkości 5 jednostek 
 -- utworzonego wokół najkrótszej linii 
 --łączącej obiekt 3 i 4
 
INSERT INTO obiekty (nazwa, geom)
SELECT
    'shortest_line34',
    ST_ShortestLine(o3.geom, o4.geom)
FROM obiekty o3, obiekty o4
WHERE o3.nazwa = 'obiekt3'
  AND o4.nazwa = 'obiekt4';

INSERT INTO obiekty (nazwa, geom)
SELECT 'bufor', ST_Buffer(o.geom, 5)
FROM obiekty o
WHERE o.nazwa LIKE 'shortest_line34'

SELECT ST_Area(ST_Buffer(o.geom, 5))
FROM obiekty o
WHERE o.nazwa LIKE 'shortest_line34'

--3-- zmiana obiektu 4 na poligon
--dodanie punktu żeby zamknąc kontur
UPDATE obiekty
SET geom = ST_AddPoint(geom, ST_StartPoint(geom))
WHERE nazwa LIKE 'obiekt4';

UPDATE obiekty
SET geom = ST_BuildArea(geom)
WHERE nazwa = 'obiekt4';

--sprawdzenie typu
SELECT ST_GeometryType(o.geom)
FROM obiekty o
WHERE nazwa = 'obiekt4';

--4-- obiekt z obiektów 3,4
INSERT INTO obiekty (nazwa, geom)
SELECT 'obiekt7', ST_Collect(a.geom, b.geom) 
FROM obiekty a, obiekty b
WHERE a.nazwa = 'obiekt3'
  AND b.nazwa = 'obiekt4';

--sprawdzenie typu
SELECT ST_GeometryType(o.geom)
FROM obiekty o
WHERE nazwa LIKE 'obiekt7';

--5-- pole powierzchni wszystkich buforów (5jedn), 
--utworzonych wokół obiektów niezawierających łuków
SELECT SUM(ST_Area(ST_Buffer(o.geom,5)))
FROM obiekty o
WHERE ST_HasArc(o.geom) = false;


