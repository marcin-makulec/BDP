--- 3

CREATE EXTENSION postgis;

--- 4

CREATE TABLE buildings (
	id SERIAL PRIMARY KEY,
	geometry geometry,
	name VARCHAR(32)
);

CREATE TABLE roads (
	id SERIAL PRIMARY KEY,
	geometry geometry,
	name VARCHAR(32)
);

CREATE TABLE poi (
	id SERIAL PRIMARY KEY,
	geometry geometry,
	name VARCHAR(32)
);

--- 5

INSERT INTO buildings(name, geometry)
VALUES
('BuildingA', ST_GeomFromEWKT('SRID=0;POLYGON((8 4, 10.5 4, 10.5 1.5, 8 1.5, 8 4))')),
('BuildingB', ST_GeomFromEWKT('SRID=0;POLYGON((4 7, 6 7, 6 5, 4 5, 4 7))')),
('BuildingC', ST_GeomFromEWKT('SRID=0;POLYGON((3 8, 5 8, 5 6, 3 6, 3 8))')),
('BuildingD', ST_GeomFromEWKT('SRID=0;POLYGON((9 9, 10 9, 10 8, 9 8, 9 9))')),
('BuildingF', ST_GeomFromEWKT('SRID=0;POLYGON((1 2, 2 2, 2 1, 1 1, 1 2))'));

INSERT INTO poi(name, geometry)
VALUES
('G', ST_GeomFromEWKT('SRID=0;POINT(1 3.5)')),
('H', ST_GeomFromEWKT('SRID=0;POINT(5.5 1.5)')),
('I', ST_GeomFromEWKT('SRID=0;POINT(9.5 6)')),
('J', ST_GeomFromEWKT('SRID=0;POINT(6.5 6)')),
('K', ST_GeomFromEWKT('SRID=0;POINT(6 9.5)'));

INSERT INTO roads(name, geometry)
VALUES
('RoadX', ST_GeomFromEWKT('SRID=0;LINESTRING(0 4.5, 12 4.5)')),
('RoadY', ST_GeomFromEWKT('SRID=0;LINESTRING(7.5 10.5, 7.5 0)'));

--- 6a

SELECT SUM(ST_Length(geometry)) AS roads_length_total FROM roads;

--- 6b

SELECT ST_AsText(geometry) AS wkt, ST_Area(geometry) AS area, ST_Perimeter(geometry) AS perimeter
FROM buildings
WHERE name = 'BuildingA';

--- 6c

SELECT name, ST_Area(geometry) AS area
FROM buildings
ORDER BY name;

--- 6d

WITH rank_area AS (
	SELECT name, geometry, RANK () OVER (ORDER BY ST_Area(geometry) DESC) as rank_area
	FROM buildings
)
SELECT name, ST_Perimeter(geometry) AS perimeter
FROM rank_area
ORDER BY rank_area
LIMIT 2;

--- 6e

WITH point_k_geometry AS (
	SELECT geometry
	FROM poi
	WHERE name = 'K'
), building_c_geometry AS (
	SELECT geometry
	FROM buildings
	WHERE name = 'BuildingC'
)
SELECT ST_Distance(a.geometry, b.geometry) AS distance
FROM point_k_geometry AS a
CROSS JOIN building_c_geometry AS b;

--- 6f

WITH building_b_buffer AS(
	SELECT ST_Buffer(geometry, 0.5, 16) AS geometry
	FROM buildings
	WHERE name = 'BuildingB'
), building_c AS(
	SELECT geometry
	FROM buildings
	WHERE name = 'BuildingC'
)
SELECT ST_Area(ST_Difference(a.geometry, b.geometry)) AS area
FROM building_c AS a
CROSS JOIN building_b_buffer AS b;

--- 6g

WITH building_centroids AS (
	SELECT ST_Y(ST_Centroid(geometry)) AS y, name, id, geometry
	FROM buildings
), roadX_geometry AS (
	SELECT ST_Y(ST_Centroid(geometry)) AS y
	FROM roads
	WHERE name = 'RoadX'
)

SELECT a.id, a.name, ST_AsText(a.geometry) AS geometry
FROM building_centroids AS a
CROSS JOIN roadX_geometry AS b
WHERE a.y > b.y;

--- 6h

WITH building_c AS (
	SELECT geometry
	FROM buildings
	WHERE name = 'BuildingC'
)
SELECT ST_Area(
	ST_SymDifference(
		geometry,
		ST_GeomFromEWKT('SRID=0;POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))')
	)
)
FROM building_c;


















