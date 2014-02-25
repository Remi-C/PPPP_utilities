---------------------------------------------
--Copyright Remi-C Thales IGN 29/11/2013
--
--a function to get a point on a line with a given number of digits
--------------------------------------------






	DROP FUNCTION IF EXISTS public.rc_DumpLines(_a_geom geometry ) ;
	CREATE OR REPLACE FUNCTION public.rc_DumpLines(_a_geom geometry)
	RETURNS SETOF geometry_dump AS
	$BODY$
		--this function breaks a polygon/geomCollection into lines and return the lines, along with the path
		--NOTE : the path is not compet, because ST_CollectionExtract lose some information (it aggregates every polygon/multipolygon into a multipolygon)
		--the srid is transmitted.
		DECLARE
		_r record;
		_i int :=0;
		--_srid integer;
		BEGIN
			--first, extract lines from polygon
			--second : extract lines from lines

			RETURN QUERY  --returning also all the simple lines
				SELECT path, geom
				FROM ST_Dump(ST_CollectionExtract (_a_geom,2)) AS dp(path, geom);

			FOR _r in SELECT row_number() over() AS id, dp FROM ST_Dump(ST_CollectionExtract (_a_geom,3)) AS dp --looping trough potential multipolygon
			LOOP
			_i:=_i+1;
			RETURN QUERY 
					WITH poly AS( 
						SELECT _r.id, (_r.dp).path AS gpath, (_r.dp).geom AS poly 
					),
					dump AS(
						SELECT ARRAY[id::int,(gpath[1])] AS gpath, (ST_DumpRings(poly)) as dp, ST_SRID(poly) AS srid
						FROM poly
					),
					line AS (
						SELECT 
							CASE 
								WHEN gpath IS NULL THEN ARRAY[(dp).path[1]-1] 
									ELSE ARRAY[gpath[1], (dp).path[1]] END AS path
							,ST_SetSRID( ST_ExteriorRing((dp).geom),srid) AS geom
							FROM dump
					)
					SELECT path,geom
					FROM line 
					WHERE geom  IS NOT NULL;
			END LOOP;--loop on multi polygon

			RETURN;
		END;
	$BODY$
	 LANGUAGE plpgsql  IMMUTABLE STRICT;



	--test : 
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
		) as geom, rc_DumpLines(geom) AS dmp(path,geom);




