-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--a function to smoth given line/polygon with a given turning radius 
--	the turning radius is expected to be in the measure data for each point
--	the turning radius is expected to be in  a table asociating each point to a turning radius (if equality, warning , smallest radius is taken)
--	or the default is used

--
--in case where 2 succesive turn are in conflict, and it is concave : way to find tangents : --http://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Tangents_between_two_circles
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
					WITH cleaned_qseg_pair AS (

						SELECT   ordinality AS gid, igeom AS geom, path1 ,geom1 AS geom_seg1, path2 ,geom2 AS geom_seg2
						FROM rc_successiveSegments ( igeom   ) 
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
	FROM  test_rc_smooth_geom_line 
		, rc_smooth_geom( igeom:=geom 
			,radius_table:='test_rc_smooth_geom_line' 
			,default_radius:=56
			,the_precision:=0.01
			,buffer_option:='quad_segs=8'
			 ) AS smooth

	


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
		SELECT row_number() over() as qgis_id, geom , 30 AS base_radius, 0.2 AS pertubation_radius
		--FROM ST_Geomfromtext('LINESTRING(-40 30, -45  30, -25 100 , 100 100, -20 30,47 25, -10 -10 ,85 -65, 110 50 , 10 35 ,12 40 )') AS geom
		--FROM ST_Geomfromtext('LINESTRING( 170 150, -25 100 , 100 100, -20 30,47 25, -10 -10 ,85 -65, 35 -80 , 40 -55 , 20 -62, 10 -45, -15 -75 )') AS geom
		FROM ST_Geomfromtext('LINESTRING(120 57,196 -16,206 -14,220 74,170 150,-25 100,100 100,-20 30,47 25,-10 -10,109 -79,59 -94,64 -69,44 -76,34 -59,9 -89,-35 -72,-16 -132,-64 -81,-60 -127,-151 -102,-193 -134)') AS geom
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
	
	--SELECT ST_Astext(ST_SnapToGrid(geom,1))
	--FROM test_rc_smooth_geom_line


	
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
		--,pair_and_closing AS (
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




	WITH the_geom AS (
		SELECT *, ST_Astext(geom)
		FROM test_rc_smooth_geom_line AS geom
			,setseed(0.2) --adding a setseed to control random for test purpose
		)
	  ,couple AS (
		SELECT  
			 smooth.*
			 ,  o_u_seg_closed
			  ,dmp.*
			   , ST_Astext(o_u_seg_closed)
			--    ST_Astext(morpho)
		FROM the_geom
			-- , rc_morpho_closing_opening(geom,30,0.001, 'quad_segs=16') as morpho
			-- ,rc_DumpsuccessiveSegments(geom)
			  ,rc_smooth_geom( igeom:=geom 
			 	,radius_table:='test_rc_smooth_geom_line' 
			 	,default_radius:=30
			 	,the_precision:=0.01
			 	,buffer_option:='quad_segs=8'
			  ) AS smooth
			 ,ST_Dump(smooth.o_u_seg_closed) AS dmp
	)
	,geom_as_array AS (
	SELECT array_agg(geom) as geom
	FROM couple
	GROUP BY o_gids[1]
	)
	SELECT ST_Astext(
			 ST_Centroid( 
				ST_Intersection(
					ST_Buffer(geom[1],0.01)
					,St_Buffer(geom[2],0.01) 
			 	)
			 )
		 ) as geom
	FROM geom_as_array


	WITH dmped AS (
	SELECT tr.*  , dmp.*
	FROM test_rc_smooth_error_case AS tr, ST_Dump( u_seg_closed) As dmp
	)
	,geom_as_array AS (
	SELECT array_agg(geom) as geom
	FROM dmped
	GROUP BY gid1
	)
	SELECT ST_Astext(
			  ST_Centroid( 
				ST_Intersection(
					ST_Buffer(geom[1],0.01)
					,St_Buffer(geom[2],0.01) 
			 	)
			 )
		 ) as geom
	FROM geom_as_array




---------------
--converting result of closing on 2 successiv segment to a curve.



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
		,line_for_arc AS (
			SELECT gid, ST_Difference( 
				ST_Boundary(seg_closed)
				,ST_Union(ST_Buffer(geom_seg1,0.01),ST_Buffer( geom_seg2,0.01) )
				--,0.01
				)AS geom
			FROM pair_and_closing
		)
		SELECT gid, geom, ST_Astext(geom),ST_Astext( ST_LineToCurve(geom))
		FROM line_for_arc


		
	WITH dmped AS (
	SELECT gid, geom  
	FROM test_rc_smooth_closed   
	)
	SELECT ST_Difference()
	,geom_as_array AS (
	SELECT array_agg(geom) as geom
	FROM dmped
	GROUP BY gid1
	)
	SELECT ST_Astext(
			  ST_Centroid( 
				ST_Intersection(
					ST_Buffer(geom[1],0.01)
					,St_Buffer(geom[2],0.01) 
			 	)
			 )
		 ) as geom
	FROM geom_as_array
*/
