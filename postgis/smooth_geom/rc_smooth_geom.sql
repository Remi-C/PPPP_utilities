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

	CREATE SCHEMA iF NOT EXISTS buffer_variable;
	SET search_path TO buffer_variable,bdtopo, public;

/* 

DROP FUNCTION IF EXISTS rc_smooth_geom( igeom GEOMETRY ,radius_table regclass ,default_radius float , the_precision FLOAT , buffer_option TEXT  );
CREATE OR REPLACE FUNCTION rc_smooth_geom(
	igeom GEOMETRY
	,radius_table regclass
	,default_radius float
	, the_precision FLOAT 
	, buffer_option TEXT DEFAULT 'quad_segs=8'::text
	)
  RETURNS TABLE(o_gids int[], o_u_seg_closed geometry, o_radiuses float[], o_error_case int) AS 
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
 
			RETURN QUERY 
				SELECT *
				FROM (
					WITH the_geom AS (
						SELECT 1 AS gid, igeom AS geom
						--FROM test_rc_smooth_geom_line AS geom
						--,setseed(0.2) --adding a setseed to control random for test purpose
					)
					,breaking_to_segment AS (
						SELECT gid, tg.geom , dump.path , dump.geom as geom_seg
						FROM the_geom AS tg , rc_DumpSegments(geom ) as dump
					)
					,generate_segment_pairs AS(
						SELECT bts1.*
							,-- COALESCE( --note : this is to used when dealing with polygons
								lead((path,geom_seg)::geometry_dump ,1) OVER(ORDER BY path aSC) 
							--	, first_value((path,geom_seg)::geometry_dump) OVER (ORDER BY path aSC) )
							  AS prev_s 
						FROM breaking_to_segment as bts1 
					)
					,cleaned_qseg_pair AS (
						SELECT row_number() over() AS gid, gid AS line_gid, geom ,path AS path1, geom_seg AS geom_seg1,   (prev_s).path AS path2, (prev_s).geom AS geom_seg2
						FROM generate_segment_pairs
						ORDER BY path1
					)
					,pair_and_radius AS(
						----this version is adapted when a table is given with list of radius per point
						--SELECT cp.*, tg.radius 
						--FROM cleaned_qseg_pair AS cp LEFT OUTER JOIN test_rc_smooth_geom as tg ON (  ST_DWithin(ST_EndPoint(cp.geom_seg1),tg.geom,0.001) ) 
						--WHERE geom_seg2 IS NOT NULL --@DEBUG : only when dealing with line, if polygon, remove
						--ORDER BY cp.gid ASC  

						----this version is adapted when on ly a default radius is available
						SELECT cp.*, default_radius AS radius
						FROM cleaned_qseg_pair AS cp
						WHERE geom_seg2 IS NOT NULL --@DEBUG : only when dealing with line, if polygon, remove
						ORDER BY cp.gid ASC  
					)
					,pair_and_closing AS (
						SELECT pr.*,seg_closed
							, ST_AsText(seg_closed)--@DEBUG
						FROM pair_and_radius AS pr, rc_morpho_closing_opening(ST_MakeLine(geom_seg1,geom_seg2),radius,  the_precision , buffer_option) AS seg_closed
					)
					--,insert_closed AS (
					--	INSERT INTO test_rc_smooth_closed 
					--		SELECT gid, seg_closed
					--		FROM pair_and_closing
					--)
					,wrong_neighboor_case AS (
						SELECT  DISTINCT ON (cp1.gid,cp2.gid) cp1.*, cp2.* 
							, cp1.gid AS gid1, cp2.gid AS gid2, cp1.seg_closed AS seg_closed1,  cp2.seg_closed AS seg_closed2, cp1.radius AS radius1, cp2.radius AS radius2
						FROM pair_and_closing as cp1, pair_and_closing as cp2
						WHERE  cp1.gid<cp2.gid --this is stricly the part to compute all the pair cp1,cp2 wihtout duplicates (lower diag of matrix wihtout diag)
							AND 
							(
								ST_DWithin( cp1.seg_closed, cp2.seg_closed,the_precision) --no shared surface
								)
					)
					,wrong_extremities_case AS (
						SELECT cp1.*
						FROM pair_and_closing as cp1
						WHERE  ST_DWithin(cp1.seg_closed, ST_StartPoint(cp1.geom_seg1),the_precision*10)   
							OR ST_DWithin(cp1.seg_closed, ST_EndPoint(cp1.geom_seg2),the_precision*10)   
					)  
					,insert_error_case AS ( 
					 --INSERT INTO test_rc_smooth_error_case
						(
						SELECT ARRAY[gid1, gid2] AS gids, gid1, gid2,ST_Collect(seg_closed1,seg_closed2) AS u_seg_closed,ARRAY[radius1,radius2] AS radiuses
							,CASE WHEN @(gid1-gid2)=1 THEN 2 ELSE 3 END AS error_case
						FROM wrong_neighboor_case
						UNION ALL
						SELECT ARRAY[gid, NULL] AS gids, gid , null ,seg_closed AS u_seg_closed, ARRAY[radius,NULL] AS radiuses, 1 AS error_case
						FROM wrong_extremities_case
						 ) ORDER BY gid1,gid2
					--RETURNING *   
					)
					SELECT gids::int[],u_seg_closed,radiuses, error_case
					FROM insert_error_case
				) AS sub;

			 
		END ;
		$BODY$
  LANGUAGE plpgsql VOLATILE;
	--test :
	SELECT smooth.*
	FROM  test_rc_smooth_geom_line , rc_smooth_geom( igeom:=geom ,radius_table:='test_rc_smooth_geom_line' ,default_radius:=70,buffer_option:='quad_segs=8' ) AS smooth

	
	 


DROP FUNCTION IF EXISTS rc_morpho_closing_opening ( igeom GEOMETRY ,radius FLOAT, the_precision FLOAT ,buffer_option text);
CREATE OR REPLACE FUNCTION rc_morpho_closing_opening( igeom GEOMETRY ,radius FLOAT, the_precision FLOAT ,buffer_option text)
  RETURNS GEOMETRY AS 
	$BODY$
	
		-- @param : the input geometry:  
		-- @param : the radius of the closing operation (radius for the circle element that will be used). If radius is negatif, it is an opening operation
		-- @param :  we deal with non exact computing, hence the precision is a safeguard. putting it to 0 gives pure result
		-- @return :  a geometry on which was performed a mathematical morphology closing with a circle of radius radius.
		DECLARE
		BEGIN 	
			RETURN  
					 ST_Buffer(
						ST_Buffer(
							ST_Buffer(igeom,radius/2,buffer_option)
						,-radius/2-sign(radius)*the_precision,buffer_option)
					,+sign(radius)*the_precision,'join=mitre mitre_limit=5.0')
					;
 
		END ;
			--testing : 
			--SELECT ST_Astext(rc_morpho_closing(geom,-10,0, 'quad_segs=16'))
			--FROM ST_Geomfromtext('POLYGON((-45  30, 0 100 , 100 100, 35 70 ,-45  30 ))') AS geom
			--testing : 
			--SELECT ST_Astext(rc_morpho_closing(geom,10,0, 'quad_segs=16'))
			--FROM ST_Geomfromtext('LINESTRING(-45  30, 0 100 , 100 100, 35 70 )') AS geom
		$BODY$
  LANGUAGE plpgsql VOLATILE;


	 */


  
DROP FUNCTION IF EXISTS rc_successiveSegments ( igeom GEOMETRY   );
CREATE OR REPLACE FUNCTION rc_successiveSegments ( igeom GEOMETRY   )
  RETURNS TABLE(ordinality int, geom1 geometry(linestring), geom2 geometry(linestring), path1 int[], path2 int[]) AS 
	$BODY$
	
		-- @param : the input geometry:   
		
		-- @return :  a set of rows with in each 2 successiv segment along with path
		DECLARE
		 
		BEGIN 	
			--detecting if it (multi)polygon or (multi)linestring
			IF   geometrytype(igeom) ILIKE '%LINESTRING%'
			THEN
				--RAISE NOTICE 'type line'; 
			ELSIF  geometrytype(igeom) ILIKE '%POLYGON%'
			THEN 
				--RAISE NOTICE 'type polygon'; 
			ELSE 
				RAISE EXCEPTION 'the geometry must be a (multi)linestring (z m) or a (multi)polygon(z m)';
			END IF;
			  
			RETURN QUERY 
				SELECT *
				FROM (
					WITH the_geom AS (
						SELECT 1 AS gid, igeom AS geom
						--FROM test_rc_smooth_geom_line AS geom
						--,setseed(0.2) --adding a setseed to control random for test purpose
					)
					,breaking_to_segment AS (
						SELECT gid, tg.geom , dump.path , dump.geom as geom_seg
						FROM the_geom AS tg , rc_DumpSegments(geom ) as dump
					)
					,generate_segment_pairs AS(
						SELECT bts1.*
							, CASE WHEN geometrytype(igeom) ILIKE '%LINESTRING%' 
									THEN 
									lead((path,geom_seg)::geometry_dump ,1) OVER(PARTITION BY path[0:(array_length(path,1)-1)] ORDER BY path aSC) 
								ELSE 
									COALESCE(  
									lead((path,geom_seg)::geometry_dump ,1) OVER(PARTITION BY path[0:(array_length(path,1)-1)] ORDER BY path aSC) 
									, first_value((path,geom_seg)::geometry_dump) OVER (PARTITION BY path[0:(array_length(path,1)-1)] ORDER BY path aSC) )
								END AS prev_s 
						FROM breaking_to_segment as bts1 
					)
					,cleaned_qseg_pair AS (
						SELECT row_number() over() AS gid
							, gid AS line_gid
							, geom 
							,path AS _path1
							, geom_seg AS geom_seg1
							,   (prev_s).path AS _path2
							, (prev_s).geom AS geom_seg2
						FROM generate_segment_pairs
						WHERE (prev_s).path IS NOT NULL
						ORDER BY path1 ASC
					)
					SELECT gid ::int
						, geom_seg1 
						, geom_seg2 
						, _path1  
						, _path2 
					FROM cleaned_qseg_pair
				 )AS sub; 
		END ;
			--testing : 
			 
		$BODY$
  LANGUAGE plpgsql VOLATILE;

	--test case :
	WITH the_geom AS (
		SELECT row_number() over() as qgis_id, geom , 40 AS base_radius, 0.5 AS pertubation_radius
		--FROM ST_Geomfromtext('LINESTRING (-40 30, -45  30, -25 100 , 100 100  )') AS geom
		FROM ST_Geomfromtext('POLYGON((-40 30, -45  30, -25 100 , 100 100 ,-40 30 ),(12 34 , 56 36 , 49 39, 12 34))') AS geom
		--FROM ST_Geomfromtext('MULTILINESTRING ((-40 30, -45  30, -25 100 , 100 100, -20 30,47 25, -10 -10 ,85 -65, 110 50 , 10 35 ,12 40 ),(1 10 , 20 20, 30 30, 60 60),(1 10 , 20 20, 30 30, 60 60))') AS geom
		--FROM ST_Geomfromtext('POLYGON((-40 30 1 3, -45  30 1 4, 10 10 6 9 , 23 40 8 5 ,-40 30 1 3))') AS geom
			,setseed(0.2) --adding a setseed to control random for test purpose
	)
	--SELECT *
	--FROM the_geom, rc_DumpSegments(geom ) as dump
	SELECT sseg.*, ST_Astext(geom1), St_AsText(geom2) 
	FROM the_geom ,rc_successiveSegments (geom ) as sseg;


	SELECT ar[0:2]
	FROM (SELECT ARRAY[1,2,3,4] as ar) AS ar;


/*
--test case 
	--construct an example linestring and an associated table
	DROP TABLE IF EXISTS test_rc_smooth_geom;
	CREATE TABLE test_rc_smooth_geom 
		(
		gid int PRIMARY KEY
		,geom geometry
		,radius float  
		);

	DROP TABLE IF EXISTS test_rc_smooth_geom_line;
	CREATE TABLE test_rc_smooth_geom_line
		(
		gid int PRIMARY KEY
		,geom geometry 
		);
		
	DROP TABLE IF EXISTS test_rc_smooth_closed;
	CREATE TABLE test_rc_smooth_closed  
	(
		gid int PRIMARY KEY
		,geom geometry 
		);

	DROP TABLE IF EXISTS test_rc_smooth_error_case;
	CREATE TABLE test_rc_smooth_error_case  
	(
		qgis_id INT[]
		,gid1 int
		,gid2 INT
		,u_seg_closed GEOMETRY
		,radiuses float[]
		,error_case INT 
		);
		
	--populating the table 
	WITH the_geom AS (
		SELECT row_number() over() as qgis_id, geom , 40 AS base_radius, 0.5 AS pertubation_radius
		FROM ST_Geomfromtext('LINESTRING(-40 30, -45  30, -25 100 , 100 100, -20 30,47 25, -10 -10 ,85 -65, 110 50 , 10 35 ,12 40 )') AS geom
			,setseed(0.2) --adding a setseed to control random for test purpose
	)
	,inserting AS ( --populating the table 	
		INSERT INTO test_rc_smooth_geom 
			SELECT row_number() over() AS gid, geom2.geom AS geom  , base_radius*(1- pertubation_radius*round(random()::numeric,3)::float )AS radius
			FROM the_geom,ST_DumpPoints(geom) AS geom2
			RETURNING * 
	)
	INSERT INTO test_rc_smooth_geom_line
		SELECT qgis_id,geom
		FROM the_geom;
	
	


	
		WITH the_geom AS (
		SELECT *
		FROM test_rc_smooth_geom_line AS geom
			,setseed(0.2) --adding a setseed to control random for test purpose
		)
		,breaking_to_segment AS (
			SELECT gid, tg.geom , dump.path , dump.geom as geom_seg
			FROM the_geom AS tg , rc_DumpSegments(geom ) as dump
		)
		,generate_segment_pairs AS(
			SELECT bts1.*
				,-- COALESCE( --note : this is to used when dealing with polygons
					lead((path,geom_seg)::geometry_dump ,1) OVER(ORDER BY path aSC) 
				--	, first_value((path,geom_seg)::geometry_dump) OVER (ORDER BY path aSC) )
				  AS prev_s 
			FROM breaking_to_segment as bts1 
		)
		,cleaned_qseg_pair AS (
			SELECT row_number() over() AS gid, gid AS line_gid, geom ,path AS path1, geom_seg AS geom_seg1,   (prev_s).path AS path2, (prev_s).geom AS geom_seg2
			FROM generate_segment_pairs
			ORDER BY path1
		)
		,pair_and_radius AS(
			SELECT cp.*, tg.radius 
			FROM cleaned_qseg_pair AS cp LEFT OUTER JOIN test_rc_smooth_geom as tg ON (  ST_DWithin(ST_EndPoint(cp.geom_seg1),tg.geom,0.001) ) 
			WHERE geom_seg2 IS NOT NULL --@DEBUG : only when dealing with line, if polygon, remove
			ORDER BY cp.gid ASC  
		)
		,pair_and_closing AS (
			SELECT pr.*,seg_closed
				, ST_AsText(seg_closed)--@DEBUG
			FROM pair_and_radius AS pr, rc_morpho_closing_opening(ST_MakeLine(geom_seg1,geom_seg2),radius,0.001, 'quad_segs=64') AS seg_closed
		)
		,insert_closed AS (
			INSERT INTO test_rc_smooth_closed 
				SELECT gid, seg_closed
				FROM pair_and_closing
		)
		,wrong_neighboor_case AS (
			SELECT  DISTINCT ON (cp1.gid,cp2.gid) cp1.*, cp2.* 
				, cp1.gid AS gid1, cp2.gid AS gid2, cp1.seg_closed AS seg_closed1,  cp2.seg_closed AS seg_closed2, cp1.radius AS radius1, cp2.radius AS radius2
			FROM pair_and_closing as cp1, pair_and_closing as cp2
			WHERE  cp1.gid<cp2.gid --this is stricly the part to compute all the pair cp1,cp2 wihtout duplicates (lower diag of matrix wihtout diag)
				AND 
				(
					ST_DWithin( cp1.seg_closed, cp2.seg_closed,0.001) --no shared surface
					)
		)
		,wrong_extremities_case AS (
			SELECT cp1.*
			FROM pair_and_closing as cp1
			WHERE  ST_DWithin(cp1.seg_closed, ST_StartPoint(cp1.geom_seg1),0.01)   
				OR ST_DWithin(cp1.seg_closed, ST_EndPoint(cp1.geom_seg2),0.01)   
		)  
		,insert_error_case AS ( 
		 INSERT INTO test_rc_smooth_error_case
			(
			SELECT ARRAY[gid1, gid2] AS gids, gid1, gid2,ST_Union(seg_closed1,seg_closed2) AS u_seg_closed,ARRAY[radius1,radius2] AS radiuses
				,CASE WHEN @(gid1-gid2)=1 THEN 2 ELSE 3 END AS error_case
			FROM wrong_neighboor_case
			UNION ALL
			SELECT ARRAY[gid, NULL] AS gids, gid , null ,seg_closed AS u_seg_closed, ARRAY[radius,NULL] AS radiuses, 1 AS error_case
			FROM wrong_extremities_case
			 ) ORDER BY gid1,gid2
		RETURNING *   
		)
		SELECT *
		FROM insert_error_case;
	
	--SELECT qgis_id, geom , ST_AsText(geom), ST_IsValid(geom) , ST_Astext(rc_smooth_geom(geom, 'test_rc_smooth_geom'::regclass , 10)) as result 
	--FROM the_geom;
	--SELECT * --ST_Azimuth(ST_StartPoint(geom_seg1),ST_End(geom_seg1)), ST_Azimuth(ST_Start(geom_seg2),ST_End(geom_seg2))
	--SELECT *, ST_Astext(geom_seg1), ST_Astext(geom_seg2)
	--FROM cleaned_qseg_pair

 

---test on buffer about M value, minkowky_sum
	--same : both function drop Z or M value

	--
*/