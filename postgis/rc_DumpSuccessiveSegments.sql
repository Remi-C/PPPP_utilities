-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--breaking geometry into successiv pair of segments, while conserving the order	 
------------------------------


DROP FUNCTION IF EXISTS rc_DumpSuccessiveSegments ( igeom GEOMETRY   );
CREATE OR REPLACE FUNCTION rc_DumpSuccessiveSegments ( igeom GEOMETRY   )
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
	FROM the_geom ,rc_DumpSuccessiveSegments (geom ) as sseg;
