---------------------------------------------
--Copyright Remi-C Thales IGN 12/2015
--
--gven a multipolygon, returns the polygon with the largest area
--------------------------------------------

 

	DROP FUNCTION IF EXISTS rc_Largest_poly(igeom geometry) ;
	CREATE OR REPLACE FUNCTION rc_Largest_poly(igeom geometry,OUT largest_polygon geometry)
	RETURNS geometry AS
	$BODY$
		/** given a geometrty, return the largest polygon inside*/
		DECLARE  
		BEGIN 
				SELECT dmp.geom INTO largest_polygon
				FROM ST_Dump(ST_CollectionExtract(igeom,3)) AS dmp
				ORDER BY ST_Area(dmp.geom) DESC
				LIMIT 1 ; 
			RETURN;
		END;
	$BODY$
	 LANGUAGE plpgsql  IMMUTABLE STRICT;


	-- SELECT ST_AsText(rc_Largest_poly(geom)) 
	-- FROM ST_GeomFromtext('MULTIPOLYGON(((0 0, 1 0, 1 1, 0 1, 0 0 )),((10 10, 20 10, 20 20, 10 20, 10 10  )))') as geom ; 