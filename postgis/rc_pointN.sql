---------------------------------------------
--Copyright Remi-C Thales IGN 06/2014
-- 
--This function returns the Nth point of anything dumpable to points, counting forward or backward
--------------------------------------------



DROP FUNCTION IF EXISTS rc_PointN(IN ig GEOMETRY,IN point_position int  
		,OUT n_point GEOMETRY(POINT));
		
CREATE OR REPLACE  FUNCTION rc_PointN(IN ig GEOMETRY,IN point_position int  
		,OUT n_point GEOMETRY(POINT) ) AS 
	$BODY$
			--@brief this function cast the input into points and return the point_position nth of it. return Null if no such point exists
			--@param : the geom containing the point
			--@param : the position of the point we want (1 is the first point). If negativ, count backward
			--@return : the point at the given position
		DECLARE
		toto int;
		BEGIN 	

			IF ST_GeometryType(ig)  ILIKE 'ST_LINESTRING' AND point_position >=0  --simple case, better use the build in function
				THEN n_point = ST_PointN(ig, point_position); 
				--raise notice 'using regular function';
				RETURN; 
			END IF ;

			
			with the_geom AS ( --input geom
				SELECT ig as geom 
			)
			, ppos AS ( --if position is negative, count backward
				SELECT  
					CASE WHEN point_position <0 THEN (ST_NPoints(ig)::int+point_position)*1+1 ELSE point_position END AS _point_position
				FROM the_geom 
			)
			,dump AS ( --dumping the points into input geom
			SELECT row_number() over() as id, dmp.path, dmp.geom 
			FROM the_geom, ST_DumpPoints(geom) as dmp 
			)
			--keep only the correct point, else return null
			SELECT geom::GEOMETRY(POINT) INTO n_point
			FROM dump, ppos
			WHERE id =  _point_position ; 

			return ;
		END ;
			----test case : 
			-- WITH the_geom AS (
			--	SELECT ST_SetSRID(geom,4326) As geom
			-- 	FROM ST_GeomFromText(' LINESTRING(1 1, 2 2, 3 3, 4 4, 5 5)') AS geom
			-- 	--FROM ST_GeomFromText('MULTILINESTRING((1 1, 2 2, 3 3, 4 4, 5 5),(6 6 , 7 7 , 8 8 , 9 9 ))') AS geom
			-- )
			-- SELECT ST_AsText(rc_PointN(geom,-1))
			-- FROM the_geom

		$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT;
  
  
----test case : 
	/*
			WITH the_geom AS (
				SELECT ST_SetSRID(geom,4326) As geom
			 	FROM ST_GeomFromText(' LINESTRING(1 1, 2 2, 3 3, 4 4, 5 5)') AS geom
				--FROM ST_GeomFromText('MULTILINESTRING((1 1, 2 2, 3 3, 4 4, 5 5),(6 6 , 7 7 , 8 8 , 9 9 ))') AS geom
			 )
			 SELECT ST_AsText(rc_PointN(geom,-1))
			FROM the_geom
	*/
