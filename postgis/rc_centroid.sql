---------------------------------------------
-- Remi-C Thales & IGN , Terra Mobilita Project, 2014
--
----------------------------------------------
-- This script is a thin wrapper around st_centroid than enable to use it with circularstring
--
--
-- This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--
------------- 


DROP FUNCTION IF EXISTS public.rc_centroid(  igeom GEOMETRY);
CREATE OR REPLACE FUNCTION public.rc_centroid(
	igeom GEOMETRY
	)  RETURNS GEOMETRY AS
$BODY$
	--@brief : this function is a thin wrapper around st_centroid than enable to use it with circularstring
	--@param : a geom whose centroid we want 
	--@return : teh centroid

		DECLARE  
		BEGIN  

			--RAISE EXCEPTION 'hello,  % , %', st_astext(igeom), st_geometrytype(igeom) ;

			IF ST_GeometryType(igeom) ILIKE '%CircularString%'
			THEN 
				--special case, we cast the circularstring to multipoint
				
				RETURN ST_Centroid(ST_Collect(dmp.geom))
				FROM ST_DumpPoints(igeom) as dmp 
				WHERE dmp.path =ARRAY[1] OR dmp.path =ARRAY[3];
			END IF ; --cicular string

			RETURN ST_Centroid(igeom) ; 
		END ;
	--test 
	--SELECT ST_AsText(rc_centroid(geom ))
	--FROM st_geomfromtext('circularstring(0 0 , 1 1, 2 0)') as geom ; 
$BODY$
 LANGUAGE plpgsql IMMUTABLE STRICT;
 
	SELECT ST_AsText(rc_centroid(geom ))
	FROM st_geomfromtext('circularstring(0 0 , 1 1, 2 0)') as geom ; 

 
	SELECT ST_AsText( geom )
FROM st_geomfromtext('circularstring(0 0 , 1 1, 2 0)') as geom ;  
 