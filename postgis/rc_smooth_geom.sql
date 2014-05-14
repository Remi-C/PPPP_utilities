-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--a function to smoth given line/polygon with a given turning radius 
--	the turning radius is expected to be in the measure data for each point
--	the turning radius is expected to be in  a table asociating each point to a turning radius (if equality, warning , smallest radius is taken)
--	or the default is used
------------------------------



DROP FUNCTION IF EXISTS rc_smooth_geom( igeom GEOMETRY ,radius_table regclass ,default_radius float );

CREATE OR REPLACE FUNCTION rc_smooth_geom(
	igeom GEOMETRY
	,radius_table regclass
	,default_radius float
	)
  RETURNS GEOMETRY AS 
	$BODY$
	
		-- @param : the input geometry: must be breakable into segments by rc_dumpsegments
		-- @param :  a table with a column geom containg the points and a column radius containing the associated radius. Null makes it revert to default
		-- @param :  if no information about radius is supplied, uses the default radius
		-- @return :  a geometry with turn smoothed so that th eline turns slower than the arc of circle of given radius in each point.
		DECLARE
		BEGIN 	
			--the function :
				--break input into segments, conserve order
				--for each pair of following segment
					--get the turning radius of the center point (end of the first segment, start of the second segment)
					--

				
		RETURN NULL;
		END ;
		$BODY$
  LANGUAGE plpgsql VOLATILE;

	

--test case 
	--construct an example linestring and an associated table
	DROP TABLE IF EXISTS test_rc_smooth_geom;
	CREATE TABLE test_rc_smooth_geom 
		(
		qgis_id int
		,geom geometry
		,radius float 
		);


	 
	WITH the_geom AS (
		SELECT row_number() over() as qgis_id, geom 
		FROM ST_Geomfromtext('LINESTRING(0 0, 0 100 , 100 100, 100 0, 0 0 )') AS geom
	)
	,inserting AS 
		(
		INSERT INTO test_rc_smooth_geom 
			SELECT row_number() over() AS qgis_id, geom2.geom AS geom  , 10+1- 2*random()::float AS radius
			FROM the_geom,ST_DumpPoints(geom) AS geom2
			RETURNING * 
		) 
	,breaking_to_segment AS (
		SELECT qgis_id, tg.geom , dump.path , dump.geom as geom_seg
		FROM the_geom AS tg , rc_DumpSegments(geom ) as dump
	)
	,generate_segment_pairs AS(
		SELECT bts1.*
			, COALESCE(
				lead((path,geom_seg)::geometry_dump ,1) OVER(ORDER BY path aSC) 
				, first_value((path,geom_seg)::geometry_dump) OVER (ORDER BY path aSC) 
			)  AS prev_s 
		FROM breaking_to_segment as bts1 
	)
	,cleaned_qseg_pair AS (
		SELECT qgis_id, geom ,path AS path1, geom_seg AS geom_seg1,   (prev_s).path AS path2, (prev_s).geom AS geom_seg2
		FROM generate_segment_pairs
	)
	SELECT ST_Azimuth(ST_StartPoint(geom_seg1),ST_End(geom_seg1)), ST_Azimuth(ST_Start(geom_seg2),ST_End(geom_seg2))
	--SELECT *, ST_Astext(geom_seg1), ST_Astext(geom_seg2)
	FROM cleaned_qseg_pair
	
	--SELECT qgis_id, geom , ST_AsText(geom), ST_IsValid(geom) , ST_Astext(rc_smooth_geom(geom, 'test_rc_smooth_geom'::regclass , 10)) as result 
	--FROM the_geom;