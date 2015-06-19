---------------------------------------------
--Copyright Remi-C Thales IGN 29/11/2013
--
--a wrapper around st_EteriorRing to also work on multipolygon..
--------------------------------------------
 

DROP FUNCTION IF EXISTS rc_ExteriorRIng(   IN i_geom GEOMETRY, OUT o_geom GEOMETRY );
	  
CREATE OR REPLACE FUNCTION rc_ExteriorRing(   IN i_geom GEOMETRY, OUT o_geom GEOMETRY 
	 ) AS 
	$BODY$
		--@brief : this function takes (multi)polygons and return (multi)linestring
		DECLARE     
		BEGIN 	

			WITH dmp_geom AS (
				SELECT dmp.geom 
				FROM ST_Dump(ST_CollectionExtract(i_geom,3)) as dmp 
			) 
			,ext_ring AS (
				SELECT  ST_Collect(ST_ExteriorRing( dmp.geom ))   AS e_r
				FROM dmp_geom  as dmp 
				)
			SELECT e_r  INTO o_geom
			FROM ext_ring; 
			
	RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT;    


	
--testing  : 
/*
	WITH the_geom AS (
		SELECT ST_COLLECT(ARRAY[geom1, ST_Translate(geom1, 3,0),line]) as geom
		FROM ST_GeomFromText('POLYGON((0 0, 4 0 , 4 4, 0 4, 0 0),(1 1, 3 1, 3 3, 1 3 , 1 1))') as geom1
			, ST_GeomFromText('LINESTRING (1 3 , 4 6 ,6  3)') as line
	)
	SELECT ST_AsText(rc_ExteriorRing(geom))
	FROM the_geom; 
    

	WITH the_geom AS (
		SELECT  geom1  as geom
		FROM ST_GeomFromText('POLYGON((0 0, 4 0 , 4 4, 0 4, 0 0),(1 1, 3 1, 3 3, 1 3 , 1 1))') as geom1
			 
	)
	SELECT ST_AsText(rc_ExteriorRing(geom))
	FROM the_geom; 

	*/