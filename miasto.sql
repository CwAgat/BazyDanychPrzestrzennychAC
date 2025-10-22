CREATE TABLE BUILDINGS (
	ID SERIAL PRIMARY KEY,
	NAME VARCHAR(50),
	GEOMETRY GEOMETRY (POLYGON, 0)
);

CREATE TABLE ROADS (
	ID SERIAL PRIMARY KEY,
	NAME VARCHAR(50),
	GEOMETRY GEOMETRY (LINESTRING, 0)
);

CREATE TABLE POINTS (
	ID SERIAL PRIMARY KEY,
	NAME VARCHAR(50),
	GEOMETRY GEOMETRY (POINT, 0)
);


INSERT INTO buildings ("name",geometry)
VALUES 
	('BuildingC', ST_GeomFromText('POLYGON((3 6, 3 8, 5 8, 5 6, 3 6))',0)),
	('BuildingB', ST_GeomFromText('POLYGON((4 7, 6 7, 6 5, 4 5, 4 7))',0)),
	('BuildingA', ST_GeomFromText('POLYGON((8 4, 10.5 4, 10.5 1.5, 8 1.5, 8 4))',0)),
	('BuildingD', ST_GeomFromText('POLYGON((9 9, 10 9, 10 8, 9 8, 9 9))',0)),
	('BuildingF', ST_GeomFromText('POLYGON((1 2, 2 2, 2 1, 1 1, 1 2))',0));

INSERT INTO roads ("name",geometry)
VALUES 
	('RoadY', ST_GeomFromText('LINESTRING(7.5 10.5, 7.5 0)',0)),
	('RoadX', ST_GeomFromText('LINESTRING(0 4.5, 12 4.5)',0));

INSERT INTO points ("name",geometry)
VALUES 
	('H', ST_GeomFromText('POINT(5.5 1.5)',0)),
	('I', ST_GeomFromText('POINT(9.5 6)',0)),
	('J', ST_GeomFromText('POINT(6.5 6)',0)),
	('K', ST_GeomFromText('POINT(6 9.5)',0)),
	('G', ST_GeomFromText('POINT(1 3.5)',0));

--DROP table roads cascade;
--DROP table buildings cascade;
--DROP table points cascade;

SELECT * FROM buildings;

-- 6a) całkowita długość dróg
SELECT SUM(ST_Length(r.geometry))
FROM roads r


-- 6b) geometria w (WKT), pole powierzchni i obwód BuildingA
SELECT ST_AsText(b.geometry), ST_Area(b.geometry) as area, ST_Perimeter(b.geometry) as perimeter
FROM buildings b
WHERE b.name LIKE 'BuildingA'

-- 6c) nazwy i pola powierzchni wszystkich poligonów w warstwie budynki posortowane alfabetycznie
SELECT b.name, ST_Area(b.geometry) as area
FROM buildings b
ORDER BY b.name ASC

-- 6d) nazwy i obwodu 2 budynków o największej powierzchni
SELECT b.name, ST_Perimeter(b.geometry) as perimeter
FROM buildings b
ORDER BY ST_Area(b.geometry) DESC
LIMIT 2;

-- 6e) najkrótsza odległość pomiędzy BuildingC a punktem K
SELECT b.name, p.name, ST_Distance(b.geometry, p.geometry)
FROM buildings b
JOIN points p on p.name LIKE 'K'
WHERE b.name LIKE 'BuildingC'

SELECT b.name, p.name, ST_Distance(b.geometry, p.geometry)
FROM buildings b
CROSS JOIN points p
WHERE b.name LIKE 'BuildingC' AND p.name LIKE 'K'

-- 6f) pole powierzchni budynku C znajdującej się dalej niż 0.5 od budynku B
SELECT ST_Area(ST_Difference(b1.geometry, ST_Buffer(b2.geometry, 0.5)))
FROM buildings b1
cross join buildings b2
where b1.name like 'BuildingC' and b2.name like 'BuildingB'

-- 6g) budynki których centroid znajduje sie powyżej drogi RoadX
SELECT b.name
FROM buildings b
CROSS JOIN roads r
WHERE ST_Y(ST_Centroid(b.geometry)) > ST_Y(ST_StartPoint(r.geometry)) and r.name like 'RoadX'

-- 6h) pole powierzchni tych części budynku BuildingC i poligonu o współrzędnych (4 7, 6 7, 6 8, 4 8, 4 7), które nie są wspólne dla tych dwoch obiektów
SELECT 		ST_Area(b.geometry) - 
			ST_Area(ST_Intersection(b.geometry, ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))',0))) +
			ST_Area(ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))',0)) -
			ST_Area(ST_Intersection(b.geometry, ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))',0)))
			AS suma_różnic_zbiorów
			
FROM buildings b
WHERE b.name like 'BuildingC';

-- okaszuje się że dało się krócej
SELECT ST_Area(ST_SymDifference(b.geometry, ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))',0)))
FROM buildings b
WHERE b.name like 'BuildingC';

