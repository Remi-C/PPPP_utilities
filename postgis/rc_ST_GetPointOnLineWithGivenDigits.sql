---------------------------------------------
--Copyright Remi-C Thales IGN 29/11/2013
--
--a function to get a point on a line with a given number of digits
--------------------------------------------







/*
-----------------------------------rc_ST_GetPointOnLineWithGivenDigits-------------------
--
--This function is a projector of a point to a line with 2 differnces :
--if the point is farther than "tolerance" of the line, we don't project
--else, we take the closest point on the line, and we return the closest point to this point which have coordinates with "n_more_digits" digits than max number of digits in line.
--------
-- USefullness: this function allow to get a point on a line with a given number of digits, no more. 
-- 	It introduces small rounding error, and has no warrante of sucess (because theoretically there  sin't always a solution)
--
--
	DROP FUNCTION IF EXISTS rc_GetPointOnLineWithGivenDigitsNb( line geometry, point geometry, n_more_digits INT,tolerance double precision );
		CREATE OR REPLACE FUNCTION rc_GetPointOnLineWithGivenDigitsNb( line geometry, point geometry, n_more_digits int,tolerance double precision DEFAULT 0)
		RETURNS geometry AS  
		$BODY$
			--this function returns the closest point to "point" on "line" with "n_more_digits" more digits than the max number of digits in "line".
			----
			--@input :	"line" 			: the line on which the result would be (except if it is too far)
			--@input :	"point" 			: the point we want to project and  approximate on the line
			--@input :	"n_more_digits"	: we allow the result coordinates to have at most "n_more_digits" more digits than max digits in coordinates of line
			--@input :	"tolerance"		: we won't do anything if "point" is farthest than "tolerance" from "line" . If "tolerance"="0", we ignore it. Default value : "0" : 
			--@output :	"geometry"		: a point with same srid as "point", either "point" if "point" is farthest than "tolerance" from "line", 
			--							or the closest point on "line" to "point" with at most "n_more_digits" than max number of digits from line. 
			DECLARE
			_srid_l int := ST_SRID(line);
			_srid_p int := ST_SRID(point);
			_cpoint geometry;
			_r record; --to hold extremities of concerned segment
			_x_1 numeric(100,50); _x_2 numeric(100,50);  --first point of the segment
			 _y_1 numeric(100,50);   _y_2 numeric(100,50); --second point of the segment

			_k NUMERIC(100,50); --the fraction of length of the segment where the projected point is
			_ts numeric(100,50) ; --the fraction of length of the segment where the projected point with good number if digits is.
			
			BEGIN
				--if mixed SRID, waringni and stopping
				IF _srid_l!= _srid_p THEN
					RAISE WARNING 'warning : point and line have mixed srids : % and %', _srid_p, _srid_l;
				END IF;
			
				--if point is not too far from line, we project it and go on, 
				--else we return the original point
				IF ST_DWithin(line,point,tolerance)=FALSE  AND tolerance !=0 THEN
					--no changes because point is too far from line
					RETURN point;
				END IF;

				--computing the closest point ,  i.e projecting
				_cpoint:= ST_SetSRID(ST_ClosestPoint(line, point), _srid_l); 


			--now we want the closest point to the closest point with a given number of digits (at most)
				--getting the concerned segment (we explode the line into segments and take the closest)
					SELECT INTO _r array_agg(geom)  AS pt
					FROM (
						SELECT  (St_DumpPoints(seg.geom)).geom AS geom
						FROM rc_DumpSegments(line) AS seg(path,geom)
						ORDER BY ST_Distance(seg.geom,point) ASc
							,(St_DumpPoints(seg.geom)).path ASC
						LIMIT 2
					) AS foo;
				--	RAISE NOTICE 'seg found : % , %', St_AsText(_r.pt[1]), ST_AsText(_r.pt[2]);

				
					--x_1 is the first point on the segment : P1
						_x_1:= ST_X(_r.pt[1]); _y_1:=ST_Y(_r.pt[1]);
					--x_2 is the second point on the segment : P2
						_x_2:=ST_X(_r.pt[2]); _y_2:=ST_Y(_r.pt[2]);

				--now we compute k, wich is the normalized distance from P1 to the projected point
					_k := ST_Distance(
						ST_SetSRID(
							ST_makePoint(_x_1,_y_1)
							,_srid_l)
						,_cpoint) 
						/ 
						ST_Distance(
							ST_SetSRID(
							ST_MakePoint(_x_1,_y_1)
							,_srid_l)
						,ST_SetSRID(ST_MakePoint(_x_2,_y_2),_srid_l)) ;

					--_ts is now a version of _k with a guaranteed max number of digits
					_ts := round(_k , n_more_digits  );

					--abs(_ts) should be between 0 and 1 
					IF abs(_ts) >1 THEN
						--this is a security , but we shouldn't enter here
						_ts = sign(_ts)*1  ;
					END IF; 
					
					--now we create a point using _ts, along the line
					RETURN ST_SetSRID(ST_MakePoint(_x_1 + _ts*(_x_2-_x_1),_y_1 + _ts*(_y_2-_y_1)),ST_SRID(point));

			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;

		---- test of the function
		SELECT ST_Intersects(cpoint , line) , ST_AsText(cpoint )
		 FROM ST_GeomFromText('LINESTRING(405.8 344.8,395.5 377.789)') AS line
		 	,ST_GeomFromtext('POINT(400 360)') As point
		 	,rc_GetPointOnLineWithGivenDigitsNb( line , point , 1) AS cpoint;
		  

*/
		
		DROP FUNCTION IF EXISTS rc_Closest( geom_array geometry[], geom2 geometry, max_distance double precision );
		CREATE OR REPLACE FUNCTION rc_Closest( geom_array geometry[], geom2 geometry,max_distance double precision DEFAULT 0)
		RETURNS geometry AS 
		$BODY$
			--This function returns one element of "geom_array" wich is the closest to "geom2", or nothing if this closest element is farthest than "max_distance"
			--
			--@input :	"geom_array" 		: an array of geom
			--@input :	"geom2" 			: a geom as reference
			--@input :	"max_distance"	: there will be no result is the result is farthest from "geom2" than "max_distance". IF max_distance = 0 , we don"t use it. Default value to 0
			--
			--@output :	"geometry"		: output one element of "geom_array" which is the closest to "geom2", if it is closest than "max_distance"
			
		DECLARE
			
			_r geometry; --to hold extremities of concerned segment
			_x_1 numeric(100,50); _x_2 numeric(100,50);  --first point of the segment
			 _y_1 numeric(100,50);   _y_2 numeric(100,50); --second point of the segment			
			BEGIN
			
				SELECT geom	INTO _r 
					FROM (
						SELECT  geom
						FROM unnest(geom_array) AS geom
						WHERE ST_DWithin(geom,geom2,max_distance)=TRUE OR max_distance = 0 --if max_distance = 0 , we ignore it.
						ORDER BY ST_Distance(geom,geom2) ASc
							,geom ASC --note : this is here only to ensure predictable output if  the 2 closest geometry 
															--have same distance to geom2  
						LIMIT 1
					) AS foo;
					
					RETURN _r;
			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;
/*
		SELECT  *
		FROM (SELECT ARRAY[ST_GeomFromText('LINESTRING(405.8 344.8,395.5 377.789)'),ST_GeomFromText('LINESTRING(401.8 350.8,399.5 380.789)')] AS line) AS line
			,ST_GeomFromtext('POINT(400 360)') As point
			,rc_Closest( line , point , 0) AS cpoint;
*/



		
		DROP FUNCTION IF EXISTS rc_ClosestSegment( line geometry, point geometry,max_distance double precision );
		CREATE OR REPLACE FUNCTION rc_ClosestSegment( line geometry, point geometry,max_distance double precision DEFAULT 0)
		RETURNS geometry AS 
		$BODY$
		DECLARE
			
			_r record; --to hold extremities of concerned segment
			_x_1 numeric(100,50); _x_2 numeric(100,50);  --first point of the segment
			 _y_1 numeric(100,50);   _y_2 numeric(100,50); --second point of the segment			
			BEGIN

				SELECT INTO _r  geom  AS geom
					FROM (
						SELECT  seg.geom AS geom
						FROM rc_DumpSegments(line) AS seg(path,geom)
						WHERE ST_DWithin(seg.geom,point,max_distance)=TRUE OR max_distance = 0 --if max_distance = 0 , we ignore it.
						ORDER BY ST_Distance(seg.geom,point) ASc
							,seg.path ASC --note : this is here only to ensure predictable output if  the 2 closest segments 
															--have same distance to point (distance = 0)
						
						LIMIT 2
					) AS foo;
					--RAISE NOTICE 'seg found : % , %', St_AsText(_r.pt[1]), ST_AsText(_r.pt[2]);

					RETURN _r.geom;
			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;
/*
		
		SELECT row_number() over() AS id,  ST_AsText(cseg ) t_cseg,cseg , line, point
		FROM ST_GeomFromText('LINESTRING(0 10, 0 20, 0 30 )') AS line
			,ST_GeomFromtext('POINT(10 25)') As point
			,rc_ClosestSegment( line , point ,0) AS cseg;
*/

		-- @TODO
		--DROP FUNCTION IF EXISTS rc_ClosestSegment( line geometry, point geometry,tolerance double precision );

		-- @TODO
		--DROP FUNCTION IF EXISTS rc_DumpLines( line geometry, point geometry,tolerance double precision );

		
