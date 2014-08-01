---------------------------------------------
-- Remi-C Thales & IGN , Terra Mobilita Project, 2014
--
----------------------------------------------
-- This script scale a geometry with a scaling centerd on the centroid of the geom
--
--
-- This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--
------------- 


DROP FUNCTION IF EXISTS rc_scale_geom_local(  igeom GEOMETRY, scale float);
CREATE OR REPLACE FUNCTION rc_scale_geom_local(
	  igeom GEOMETRY, scale float
	)  RETURNS GEOMETRY AS
$BODY$
	--@brief : this function scale a geometry with a scaling centerd on the centroid of the geom
	--@param : a geom to be scaled
	--@param : the scale factor 
	--@return : a scaled geom 

		DECLARE  
		BEGIN  
		RETURN ST_Translate(
						ST_Scale(
							ST_translate(
								igeom
								, -ST_X(centroid)
								,-ST_Y(centroid)
								, COALESCE( -ST_Z(centroid) ,0) --we use the coalesce to avoid null input
								) 
						, scale
						,scale
						,scale)  
						,ST_X(centroid)
						,ST_Y(centroid)
						, COALESCE( ST_Z(centroid),0)
					 )
			FROM ST_Centroid(igeom) as centroid  ;
			 
		END ;
$BODY$
 LANGUAGE plpgsql IMMUTABLE ;
 
	SELECT ST_AsText( rc_scale_geom_local(geom, 0.5::float) ) 
	FROM ST_GeomFromText('LINESTRING(20 10, 30 40 )') AS geom ;

-- 
-- 	WITH the_geom AS (
-- 		SELECT ST_GeomFromText('LINESTRING(20 10, 30 40 )') AS geom, 0.1 AS scale
-- 	)
-- 	SELECT ST_Astext(
-- 		 ST_Translate(
-- 				ST_Scale(
-- 					 ST_translate(
-- 						geom
-- 					 	, -ST_X(centroid)
-- 					 	,-ST_Y(centroid)
-- 					 	, COALESCE(-ST_Z(centroid),0) 
-- 					 	) 
-- 				, scale
-- 				,scale
-- 				,scale)  
-- 				,ST_X(centroid)
-- 				,ST_Y(centroid)
-- 				, ST_Z(centroid)
-- 			 )
-- 			)
-- 	FROM the_geom, ST_Centroid(geom) as centroid  ;

  