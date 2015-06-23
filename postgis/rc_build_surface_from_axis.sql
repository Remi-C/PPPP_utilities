---------------------------------------------
--Copyright Remi-C Thales IGN 25/04/2015
-- 
--a function to construct a surface out of 2 linestring
--------------------------------------------

DROP FUNCTION IF EXISTS rc_build_surface_from_axis(g1 geometry,g2 geometry);
CREATE OR REPLACE FUNCTION rc_build_surface_from_axis(g1 geometry,g2 geometry, OUT surf geometry)
  AS
$BODY$
--this function takes 2 linestring having a point in common, and returns a surface formed by closing the linestring
DECLARE  
BEGIN 
	WITH geo AS ( 
		SELECT g1 AS _g1, g2 AS _g2
			, ST_StartPoint(g1) as p1_s
			, ST_StartPoint(g2) as p2_s
			, ST_EndPoint(g1) as p1_e
			, ST_EndPoint(g2) as p2_e 
	)
	, fabricated_lines AS (
	SELECT CASE WHEN ST_Distance(p1_s, p2_s) < ST_Distance(p1_s, p2_e) 
		THEN ST_AddPoint(ST_AddPoint( _g1,p2_s,0) , p2_e, -1)
		ELSE  ST_AddPoint(ST_AddPoint( _g1, p2_e,0) , p2_s, -1) END as l1 
	FROM geo
	)
	SELECT  ST_GeometryN(ST_CollectionExtract(ST_MakeValid(ST_MakePolygon(ST_AddPoint(l1, ST_StartPoint(l1), -1))),3),1) INTO surf
	FROM geo, fabricated_lines ; 
	RETURN;
END;
$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT;


-- 
-- FROM ST_GeomFromText('LINESTRING(0 0, 0 1 )') as g1
-- 		, ST_GeomFromText('LINESTRING(0.1 0.1, 1 0 )') as g2
-- 
-- WITH geo AS ( 
-- 	SELECT g1,g2
-- 		, ST_StartPoint(g1) as p1_s
-- 		, ST_StartPoint(g2) as p2_s
-- 		, ST_EndPoint(g1) as p1_e
-- 		, ST_EndPoint(g2) as p2_e
-- 	FROM ST_GeomFromText('LINESTRING(0 0, 0 1 )') as g1
-- 		, ST_GeomFromText('LINESTRING(0.1 0.1, 1 0 )') as g2
-- )
-- , fabricated_lines AS (
-- SELECT CASE WHEN ST_Distance(p1_s, p2_s) < ST_Distance(p1_s, p2_e) 
-- 	THEN ST_AddPoint(ST_AddPoint( g1,p2_s,0) , p2_e, -1)
-- 	ELSE  ST_AddPoint(ST_AddPoint( g1, p2_e,0) , p2_s, -1) END as l1 
-- FROM geo
-- )
-- SELECT  st_astext(ST_MakePolygon(ST_AddPoint(l1, ST_StartPoint(l1), -1))) 
-- FROM geo, fabricated_lines
/*
SELECT *
FROM (
SELECT  face_id, count(*) over(partition by face_id) as c
FROM  (
	SELECT left_face as face_id
	FROM bdtopo_topological.edge_data
	WHERE edge_id IN (2523,2528)
	UNION ALL
	SELECT right_face
	FROM bdtopo_topological.edge_data
	WHERE edge_id IN (2523,2528)
) as sub 
) as subsub
WHERE c >=2
LIMIT 1
*/