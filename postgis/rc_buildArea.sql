---------------------------------------------
--Copyright Remi-C Thales IGN 29/11/2013
--
--a wrapper around st_buildarea to take into account polygons with holes, and better deal with isolated linestring
--------------------------------------------




DROP FUNCTION IF EXISTS rc_buildArea(   IN i_geom GEOMETRY, OUT o_geom GEOMETRY );
	  
CREATE OR REPLACE FUNCTION rc_buildArea(   IN i_geom GEOMETRY, OUT o_geom GEOMETRY 
	 ) AS 
	$BODY$
		--@brief : this function takes (multi)polygons and (multi)linestring and build an area over it, removing the inner ring of the polygons
		DECLARE     
		BEGIN 	

			WITH dmp_geom AS (
				SELECT dmp.geom 
				FROM ST_Dump(ST_CollectionExtract(i_geom,3)) as dmp
			)
			,ext_ring AS (
				SELECT ST_Collect(ST_ExteriorRing(dmp.geom)) AS e_r 
				FROM dmp_geom  as dmp
			)
			,misc_line AS (
				SELECT line.geom AS line
				FROM  ST_Dump(ST_CollectionExtract(i_geom,2)) AS line
			)
			,int_ring AS (
				SELECT ST_Collect(dmp.geom) as geom
				FROM dmp_geom , ST_DumpRings(dmp_geom.geom) As dmp
				WHERE dmp.path[1] >0
			)
			,build_area AS (
				SELECT  ST_AsText(ST_SetSRID(ST_BuildArea( ST_Union( e_r , line) ) ,ST_SRID(e_r))) AS geom 
				FROM ext_ring, misc_line
			)
			,area_with_hole AS (
				SELECT ST_SymDifference(ba.geom,ir.geom) as geom
				FROM build_area as ba, int_ring AS ir
			)
			SELECT geom INTO o_geom
			FROM area_with_hole  ;

	RETURN ;
		END ;
		 	
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT;    


	
--testing  : 
	WITH the_geom AS (
		SELECT ST_COLLECT(ARRAY[geom1, ST_Translate(geom1, 3,0),line]) as geom
		FROM ST_GeomFromText('POLYGON((0 0, 4 0 , 4 4, 0 4, 0 0),(1 1, 3 1, 3 3, 1 3 , 1 1))') as geom1
			, ST_GeomFromText('LINESTRING (1 3 , 4 6 ,6  3)') as line
	)
	SELECT ST_AsText(rc_buildArea(geom))
	FROM the_geom; 

	/*
	WITH the_geom AS (
	SELECT ST_COLLECT(ARRAY[geom1, ST_Translate(geom1, 3,0),line]) as geom
	FROM ST_GeomFromText('POLYGON((0 0, 4 0 , 4 4, 0 4, 0 0),(1 1, 3 1, 3 3, 1 3 , 1 1))') as geom1
		, ST_GeomFromText('LINESTRING (1 3 , 4 6 ,6  3)') as line
	)
	,dmp_geom AS (
		SELECT dmp.geom 
		FROM the_geom, ST_Dump(ST_CollectionExtract(geom,3)) as dmp
	)
	,ext_ring AS (
		SELECT ST_Collect(ST_ExteriorRing(dmp.geom)) AS e_r 
		FROM dmp_geom  as dmp
	)
	,misc_line AS (
		SELECT line.geom AS line
		FROM the_geom  ,  ST_Dump(ST_CollectionExtract(geom,2)) AS line
	)
	,int_ring AS (
		SELECT ST_Collect(dmp.geom) as geom
		FROM dmp_geom , ST_DumpRings(dmp_geom.geom) As dmp
		WHERE dmp.path[1] >0
	)
	,build_area AS (
		SELECT  ST_AsText(ST_SetSRID(ST_BuildArea( ST_Union( e_r , line) ) ,ST_SRID(e_r))) AS geom 
		FROM ext_ring, misc_line
	)
	,area_with_hole AS (
		SELECT ST_SymDifference(ba.geom,ir.geom) as geom
		FROM build_area as ba, int_ring AS ir
	)
	SELECT ST_AsText(geom)
	FROM area_with_hole 
	*/

 