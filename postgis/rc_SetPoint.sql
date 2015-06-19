---------------------------------------------
--Copyright Remi-C Thales IGN 06/2014
-- 
--This function returns the Nth point of anything dumpable to points, counting forward or backward
--------------------------------------------



DROP FUNCTION IF EXISTS rc_SetPoint(IN ig GEOMETRY,IN point_position int  , IN point_geom geometry 
		,OUT og geometry);
		
CREATE OR REPLACE  FUNCTION rc_SetPoint(IN ig GEOMETRY,IN point_position int  , IN point_geom geometry 
		,OUT og GEOMETRY  ) AS 
	$BODY$
	/**
			@brief this function set the point N numbered from 0 to the given point
			@param : the geom in which we want to set the point
			@param : the position of the point we want (0 is the first point). If negativ, count backward. If going too far, exception
			@param  : the new point ot put at the position
			@return : the corrected geometry
			*/
		DECLARE 
		BEGIN 	

			IF ST_GeometryType(ig)  ILIKE 'ST_LINESTRING' AND point_position >=0  --simple case, better use the build in function
				THEN og = ST_SetPoint(ig, point_position, point_geom); 
				--raise notice 'using regular function';
				RETURN; 
			END IF ;

			WITH the_geom AS (
				SELECT ig As geom , (CAST(point_position AS INT) +  npoints ) %  npoints as pos, point_geom as npoint
			 	FROM ST_NPoints( ig)  as npoints 
			)
			 , nodes AS (
				SELECT dmp.path[1], dmp.geom
				FROM the_geom, ST_DumpPoints(geom) as dmp
				WHERE dmp.path[1] <> pos +1
				UNION ALL 
				(SELECT pos+1 , npoint
				FROM the_geom
				LIMIT 1 )
			)
			SELECT  ST_MakeLine(geom ORDER BY path asc) INTO og
			FROM nodes  ; 
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
				SELECT ST_GeometryN(geom,1) As geom , (CAST(-1 AS INT) +  npoints ) %  npoints as pos, ST_SetSRID(ST_MakePoint(15,0 ),4326) as npoint
			 	FROM ST_GeomFromText(' LINESTRING(1 1 1 , 2 2 2 , 3 3 3 , 4 4 4, 5 5 5)', 4326) AS geom ,  ST_NPoints( geom)  as npoints
				--FROM ST_GeomFromText('MULTILINESTRING((1 1, 2 2, 3 3, 4 4, 5 5),(6 6 , 7 7 , 8 8 , 9 9 ))') AS geom
			)
			 , nodes AS (
				SELECT dmp.path[1], dmp.geom
				FROM the_geom, ST_DumpPoints(geom) as dmp
				WHERE dmp.path[1] <> pos +1
				UNION ALL 
				(SELECT pos+1 , npoint
				FROM the_geom
				LIMIT 1 )
			)
			SELECT ST_Astext(ST_MakeLine(geom ORDER BY path asc))
			FROM nodes 


	
		WITH the_geom AS (
				SELECT  geom, 1 as pos,npoint 
			 	FROM ST_GeomFromText(' LINESTRING(1 1 1 , 2 2 2 , 3 3 3 , 4 4 4, 5 5 5)', 4326) AS geom, ST_SetSRID(ST_MakePoint(15,0 ),4326) as npoint 
			)
			SELECT  ST_Astext(rc_SetPoint(geom,pos , npoint   ))
			FROM the_geom 
		*/
