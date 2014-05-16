-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--breaking geometry into segments, while conserving the order	 
------------------------------

	DROP FUNCTION IF EXISTS public.rc_DumpSegments(_line geometry ) ;
	CREATE OR REPLACE FUNCTION public.rc_DumpSegments(_line geometry)
		RETURNS SETOF geometry_dump
	AS
		$BODY$
			--this function breaks a line/multiline/geomCollection into minimal segments and return the segment, along with the path
			--There is no loss of information : operation can be reverted if there are no geometry collection
			--the srid is transmitted.
			
			--@param : a polylines which will be broken into 2points lines
			--@return : a set of 2points-lines composing the input polyline, along with it's path to avoid lose of information
			
			DECLARE
			_r record;
			--_srid integer;
			BEGIN

				--_srid := ST_SRID(_line);

				FOR _r in SELECT rc_DumpLines(_line) AS dp
				LOOP
					RETURN QUERY 
						WITH line AS( 
							SELECT --ST_GeomFromText('LINESTRING(12 1, 13 1, 14 2, 15 4)') AS line
								(_r.dp).path AS gpath, (_r.dp).geom AS line 
						),
						dump AS(
							SELECT gpath AS gpath, (ST_DumpPoints(line)) as dp, ST_SRID(line) AS srid
							FROM line
						),
						segments AS (
							SELECT 
								CASE
									WHEN gpath[1] IS NULL
									THEN ARRAY[(dp).path[1]-1]
									WHEN gpath[2] IS NULL 
									THEN ARRAY[gpath[1],(dp).path[1]-1]   
									ELSE
									ARRAY[gpath[1],gpath[2], (dp).path[1]-1] 
								END AS path
								,ST_SetSRID(ST_MakeLine( 
										lag((dp).geom , 1, NULL) OVER (ORDER BY  (dp).path)
										,(dp).geom
									),srid) AS geom
							FROM dump
						)
						SELECT path,geom
						FROM segments 
						WHERE geom  IS NOT NULL;
				END LOOP;--loop if multi linestring
				RETURN;
			END;
		$BODY$
	 LANGUAGE plpgsql  IMMUTABLE STRICT; 


 SELECT   ST_AsText(geom.geom) AS t_geom, dmp.path, ST_AsText((dmp).geom) AS t_dmplines, dmp
	FROM ST_GeomFromText(
		' LINESTRING(3 4,10 50,20 25)'
		) as geom, rc_DumpSegments(geom) AS dmp(path,geom);

 SELECT   ST_AsText(geom.geom) AS t_geom, dmp.path, ST_AsText((dmp).geom) AS t_dmplines, dmp
	FROM ST_GeomFromText(
		'GEOMETRYCOLLECTION( 
			POINT(4 6)
			, LINESTRING(4 6,7 10, 12 14) 
			, MULTILINESTRING((1 2 , 6 8 ),( 78 95, 65 41))
			,POINT(6 10)
			,LINESTRING(3 4,10 50,20 25)
			,POLYGON((1 1,5 1,5 5,1 5,1 1))
			,MULTIPOINT((3.5 5.6), (4.8 10.5))
			,MULTILINESTRING((3 4,10 50,20 25),(-5 -8,-10 -8,-15 -4))
			,MULTIPOLYGON(((1 1,5 1,5 5,1 5,1 1),(2 2,2 3,3 3,3 2,2 2)),((6 3,9 2,9 4,6 3)))
			,GEOMETRYCOLLECTION( 
				POINT(4 6)
				, LINESTRING(4 6,7 10, 12 14) 
				, MULTILINESTRING((1 2 , 6 8 ),( 78 95, 65 41))
				,POINT(6 10)
				,LINESTRING(3 4,10 50,20 25)
				,POLYGON((1 1,5 1,5 5,1 5,1 1))
				)
			)'
		) as geom, rc_DumpSegments(geom) AS dmp(path,geom);
