-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--variable radius buffer
------------------------------


DROP FUNCTION IF EXISTS public.rc_variableBuffer(i_geom geometry );
		CREATE FUNCTION public.rc_variableBuffer(i_geom geometry , OUT buffered_geom geometry)
			RETURNS geometry AS
		$BODY$
			--@brief this function computes a variable buffer given a geometry and a raidus in M dimension of each point
			--@WARNING : only dilatation , doesn't do erosion
			--@WARNING : very naive implementation.
			--Idea from Mathieu B.
			DECLARE  
			 segs geometry; 
			BEGIN
				
				with dump AS (
					SELECT DISTINCT dmp.*
					FROM   rc_DumpSegments(i_geom ) AS dmp
				)
				,trapezoid AS (
				SELECT rc_py_seg_to_trapezoid(ST_Force2D(geom), ST_M(ST_StartPoint(geom)),ST_M(ST_EndPoint(geom))) AS geom
				FROM dump
				)
				,pts_and_radius AS (
				SELECT (ST_DumpPoints(i_geom)).geom  
				)
				,buf_pts AS (
				SELECT ST_Buffer(geom,ST_M(geom)) AS geom
				FROM pts_and_radius
				)
				,all_geom AS (
				SELECT geom
				FROM buf_pts
				UNION ALL 
				SELECT geom
				FROM trapezoid
				)
				,unioned_geom AS (
				SELECT ST_union(geom) AS geom
				FROM all_geom
				)
				--,result AS (
				
					--SELECT ST_Difference(tg.geom, ug.geom) AS geom --case whendoing a erosion
				--	SELECT ST_Union(tg.geom, ug.geom) AS geom --case whendoing a dilatation
				--FROM result ;
				SELECT geom INTO buffered_geom
				FROM unioned_geom 
			return  ;
			END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

	---testing
	SELECT ST_AsText(rc_variableBuffer(geom ))
	FROM ST_GeomFromtext('LINESTRINGM(0 0 1, 10 0 2, 20 20 3 )') AS geom;

/*
	with the_geom AS (
	SELECT ST_GeomFromtext('LINESTRING(0 0 , 10 0 , 20 20, 20 5, 5 10 )') AS geom, ARRAY[1,2,3,4,5] AS radiuses
	)
	,dump AS (
		SELECT DISTINCT radiuses,row_number() over() AS id,  dmp.*
		FROM the_geom as g, rc_DumpSegments(geom ) AS dmp
	)
	,trapezoid AS (
	SELECT rc_py_seg_to_trapezoid(geom, radiuses[id],radiuses[id+1]) AS geom
	FROM dump
	)
	,pts_and_radius AS (
	SELECT (ST_DumpPoints(geom)).geom, unnest(radiuses) AS radius
	FROM the_geom
	)
	,buf_pts AS (
	SELECT ST_Buffer(geom,radius) AS geom
	FROM pts_and_radius
	)
	,all_geom AS (
	SELECT geom
	FROM buf_pts
	UNION ALL 
	SELECT geom
	FROM trapezoid
	)
	,unioned_geom AS (
	SELECT ST_union(geom) AS geom
	FROM all_geom
	)
	,result AS (
	
		--SELECT ST_Difference(tg.geom, ug.geom) AS geom --case whendoing a erosion
		SELECT ST_Union(tg.geom, ug.geom) AS geom --case whendoing a dilatation
		FROM the_geom AS tg, unioned_geom AS ug
	)
	SELECT ST_Astext(geom)
	FROM result ;


	 
	--SELECT St_AsText(ST_Union(geom, ST_Translate(geom, 5 ,-6 )))
	--FROM ST_GeomFromtext('LINESTRING M (0 0 1, 10 0 2, 20 20 3, 20 5 4, 5 10 5)') AS geom ;

 */
 