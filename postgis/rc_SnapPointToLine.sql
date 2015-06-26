---------------------------------------------
--Copyright Remi-C Thales IGN 25/11/2013
--
--
--utility function for postgis : snap apoint to a line with a tolerance
--
--
--This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--ALSO : the patch about line-point precision should be applied
--------------------------------------------




	DROP FUNCTION IF EXISTS rc_SnapPointToLine(point geometry, line geometry , tolerance double precision,tolerance_vertex double precision);
	CREATE FUNCTION rc_SnapPointToLine(point geometry, line geometry , tolerance double precision,tolerance_vertex double precision DEFAULT 0)
		RETURNS geometry AS
		$BODY$
		-- This function snap a point to a line : if under a given tolerance distance
		--	if a vertex is close enough (tolerance_vertex), we snap to it
		--	else, if the line is close enough, take the closest point on line (projection)
		--	else, return the original point
		DECLARE 
		_s boolean ;
		_cline geometry;
		_cpoint geometry;
		
		BEGIN
			--if tolerance_vertex wasn't set
			IF tolerance_vertex=0 OR tolerance_vertex > tolerance  THEN tolerance_vertex:= tolerance; END IF;
			
			--checking if line is close enough, else return original point
			_s := ST_DWithin(line, point,tolerance);

			IF _s = FALSE THEN -- distance is too fare, we just return the original point
				return point; 
			ELSE
				SELECT dmp.geom INTO _cline 
				FROM  rc_DumpSegments(line) AS dmp
				WHERE ST_DWithin(geom,point,tolerance)=TRUE
				ORDER BY ST_Distance(geom,point) ASC 
				LIMIT 1; 
				
				--RAISE NOTICE '_cline %',ST_AsText(_cline);

				
				SELECT geom INTO _cpoint
				FROM ST_DumpPoints(_cline)
				WHERE ST_DWithin(geom,point,tolerance_vertex)=TRUE
				ORDER BY ST_Distance(geom,point) ASC 
				LIMIT 1 ;

				--RAISE NOTICE '_cpoint : %',_cpoint;

				IF ST_IsEmpty(_cpoint)=FALSE AND (_cpoint IS NULL)=FALSE THEN
					--we found a vertex close enough
					return _cpoint;

				ELSE
					--line is close enough, but no vertex, we project the point onto the closest line to create a new point
					RETURN ST_ClosestPoint(_cline,point);
					
				END IF ; --is a vertex close enough?

				
			END IF;--is a line close enough?
			RETURN NULL;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

		--DROP TABLE IF EXISTS temp_test_snappointtoline;
		--CREATE TABLE temp_test_snappointtoline AS 
		--SELECT point, line, 1 AS tolerance, rc_SnapPointToLine(point  , line  , 1, 0.5  ) AS spoint 
		--FROM ST_MakePoint(1,1) AS point, ST_GeomFromText('LINESTRING(0 0, 0 10, 0 100)') AS line


	DROP FUNCTION IF EXISTS rc_SnapPointToLineEfficient(geometry(point), geometry(linestring) , tolerance double precision );
	CREATE FUNCTION rc_SnapPointToLineEfficient(INOUT point geometry(point), IN line geometry(linestring) ,IN tolerance double precision ) AS
		$BODY$
		-- This function snap a point to a line : if under a given tolerance distance 
		--	else, if the line is close enough, take the closest point on line (projection)
		--	else, return the original point
		DECLARE  
		_cpoint geometry(point);
		
		BEGIN 
			--projecting the ponint :
			_cpoint := ST_ClosestPoint(line,point) ;

			IF ST_DWithin(_cpoint, point,tolerance) = TRUE THEN 
				point := _cpoint;
				RETURN ;
			ELSE 
				RETURN ;
			END IF;  

			 
			RETURN;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

		--DROP TABLE IF EXISTS temp_test_snappointtoline;
		--CREATE TABLE temp_test_snappointtoline AS 
		--SELECT point, line, 1 AS tolerance, rc_SnapPointToLineEfficient(point  , line  , 1   ) AS spoint 
		--FROM ST_MakePoint(1,1) AS point, ST_GeomFromText('LINESTRING(0 0, 0 10, 0 100)') AS line



		DROP FUNCTION IF EXISTS rc_SnapLineToLine(line_to_snap geometry, line geometry , tolerance double precision,tolerance_vertex double precision);
	CREATE FUNCTION rc_SnapLineToLine(line_to_snap geometry, line geometry , tolerance double precision,tolerance_vertex double precision DEFAULT 0)
		RETURNS geometry AS
		$BODY$
		-- This function snap all the points of a line ot another line: if under a given tolerance distance
		--	if a vertex is close enough (tolerance_vertex), we snap to it
		--	else, if the line is close enough, take the closest point on line (projection)
		--	else, return the original point
		DECLARE  
		_cline geometry; 
		
		BEGIN
				WITH d_lines AS (
					SELECT dmp.geom, dmp.path As line_path
					FROM rc_DumpLines(line_to_snap) AS dmp
				)
				,snapped_lines AS (
					SELECT ST_Makeline(rc_SnapPointToLine(dmp.geom,line,tolerance, tolerance_vertex) ORDER BY dmp.path ASC) AS slines 
					FROM d_lines, ST_DumpPoints( geom) AS dmp 
					GROUP BY line_path 
				)SELECT ST_Collect(slines) INTO _cline
				FROM snapped_lines
				LIMIT 1;
		 
			RETURN _cline;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;
/*
		SELECT  1 AS tolerance, ST_AsText(rc_SnapLineToLine(line1  , line2  , 0.6, 0.5  )) AS sline 
		--FROM ST_GeomFromText('MULTILINESTRING((0.1 0, 1 10, 0.1 100),(0.2 0 , 1.5 10))') AS line1, ST_GeomFromText('LINESTRING(0 0, 0 10, 0 100)') AS line2
		FROM ST_GeomFromText('LINESTRING(0.1 0, 1 10, 0.1 100)') AS line1, ST_GeomFromText('LINESTRING(0 0, 0 10, 0 100)') AS line2;
*/
		 


			DROP FUNCTION IF EXISTS rc_SnapLineToLineEfficient(line_to_snap geometry, line geometry , tolerance float);
	CREATE FUNCTION rc_SnapLineToLineEfficient(INOUT line_to_snap geometry, line geometry , tolerance float ) AS
		$BODY$
		-- This function snap all the points of a line ot another line , if the other line is not too far 
		DECLARE   
		BEGIN
				WITH d_lines AS (
					SELECT dmp.geom, dmp.path As line_path
					FROM ST_Dump(ST_CollectionExtract(line_to_snap,2)) AS dmp
				)
				,snapped_lines AS (
					SELECT ST_Makeline(rc_SnapPointToLineEfficient(dmp.geom,line,tolerance) ORDER BY dmp.path ASC) AS slines 
					FROM d_lines, ST_DumpPoints( geom) AS dmp 
					GROUP BY line_path 
				)SELECT ST_Collect(slines) INTO line_to_snap
				FROM snapped_lines
				LIMIT 1;
		 
			RETURN;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;
