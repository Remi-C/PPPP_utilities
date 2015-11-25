---------------------------------------------
--Copyright Remi-C Thales IGN 29/11/2013
--
--a function to construct a ring based on any input with points. 
--complete thering if necessary
--------------------------------------------

 
 

	DROP FUNCTION IF EXISTS rc_MakeRing(igeom geometry ) ;
	CREATE OR REPLACE FUNCTION rc_MakeRing(igeom geometry, OUT ring geometry) AS
	$BODY$
		--this function tries to create a ring from a multipoint or linestring, possib ly adding the missing point to close the stuff
		DECLARE
			_temp_points GEOMETRY[] ; 
		BEGIN
			SELECT array_agg(dmp.geom ORDER BY dmp.path)  INTO _temp_points 
			FROM ST_DumpPoints(igeom) AS dmp;
 
			IF ST_Equals(_temp_points[1],  _temp_points[array_length(_temp_points,1)]) THEN
				ring :=  ST_MakeLine(_temp_points)  ;  
				 
			ELSE
				ring = ST_Addpoint(ST_MakeLine(_temp_points),_temp_points[1]) ; 
				 
			END IF; 

			RETURN;
		END;
	$BODY$
	 LANGUAGE plpgsql  IMMUTABLE STRICT;
 
	--testing
		SELECT ST_AsText(result) 
		FROM ST_GeomFromText('LINESTRING(4 6,7 10,12 14,4 6)', 931008) as geom 
			,  rc_MakeRing(geom )  AS result ; 

 