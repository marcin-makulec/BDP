--- 1

SELECT t19.*
FROM T2019_KAR_BUILDINGS AS t19
LEFT JOIN T2018_KAR_BUILDINGS AS t18
ON t19.wkb_geometry = right_table.wkb_geometry AND t19.height = t18.height
WHERE t18.wkb_geometry IS NULL;

--- 2

WITH buildings AS (
	SELECT t19.*
	FROM T2019_KAR_BUILDINGS AS t19
	LEFT JOIN T2018_KAR_BUILDINGS AS t18
	ON t19.wkb_geometry = t18.wkb_geometry AND t19.height = t18.height
	WHERE t18.wkb_geometry IS NULL
), buffer AS (
	SELECT ST_Buffer(ST_Union(wkb_geometry), 0.005) AS wkb_geometry FROM buildings
), new_poi AS (
	SELECT t19.*
	FROM T2019_KAR_POI_TABLE AS t19
	LEFT JOIN T2018_KAR_POI_TABLE AS t18
	ON t19.wkb_geometry = t18.wkb_geometry
	WHERE t18.wkb_geometry IS NULL
), count_poi AS (
	SELECT COUNT(CASE WHEN ST_Contains(p.wkb_geometry, b.wkb_geometry) THEN 1 END) AS count, type
	FROM new_poi AS p
	CROSS JOIN buffer AS b
	GROUP BY type
)

SELECT *
FROM count_poi
WHERE count != 0
ORDER BY count DESC;

--- 3

SELECT
	ogc_fid,
	link_id,
	st_name,
	ref_in_id,
	nref_in_id,
	func_class,
	speed_cat,
	fr_speed_l,
	to_speed_l,
	dir_travel,
	ST_Transform(wkb_geometry, 3068) AS wkb_geometry
INTO
	streets_reprojected
FROM
	T2019_KAR_STREETS;

--- 4

CREATE TABLE input_points (
	id SERIAL PRIMARY KEY,
	geometry geometry
);

INSERT INTO input_points(geometry)
VALUES
('POINT(8.36093 49.03174)'),
('POINT(8.39876 49.00644)');

--- 5

ALTER TABLE input_points
  ALTER COLUMN geometry
  TYPE geometry(Point)
  USING ST_Transform(ST_SetSRID(geometry, 4326), 3068);

--- 6

WITH intersections AS (
	SELECT node_id, ST_Transform(wkb_geometry, 3068) as geometry
	FROM T2019_KAR_STREET_NODE AS a
	WHERE a."intersect" = 'Y'
), new_line AS (
	SELECT ST_MakeLine(geometry) AS geometry FROM input_points
)

SELECT DISTINCT(left_table.*)
FROM intersections AS left_table
CROSS JOIN new_line AS right_table
WHERE ST_Contains(ST_Buffer(right_table.geometry, 0.002), left_table.geometry)

--- 7

WITH buffer AS (
	SELECT ST_Buffer(ST_Union(wkb_geometry), 0.003) AS wkb_geometry
	FROM T2019_KAR_LAND_USE_A
	WHERE "type" ILIKE '%park%'
), sport_pois AS (
	SELECT wkb_geometry FROM T2019_KAR_POI_TABLE WHERE "type" LIKE 'Sporting Goods Store'
)
SELECT COUNT(CASE WHEN ST_Contains(left_table.wkb_geometry, right_table.wkb_geometry) THEN 1 END) AS count
FROM sport_pois AS right_table
CROSS JOIN buffer AS left_table;

--- 8

SELECT DISTINCT(ST_Intersection(left_table.wkb_geometry, right_table.wkb_geometry)) AS wkb_geometry
INTO T2019_KAR_BRIDGES
FROM T2019_KAR_RAILWAYS AS left_table
CROSS JOIN T2019_KAR_WATER_LINES AS right_table
WHERE ST_Intersects(left_table.wkb_geometry, right_table.wkb_geometry)













