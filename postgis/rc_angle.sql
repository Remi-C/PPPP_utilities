---------------------------------------------
--Rémi Cura , 2015
----------------------------------------------
-- This script gives an absolute angle between 3 points
------------- 

--SET search_path to rc_lib, public;  

DROP FUNCTION IF EXISTS rc_angle(  geom1 geometry, geom2 geometry, geom3 geometry) ;
CREATE OR REPLACE FUNCTION rc_angle(  geom1 geometry, geom2 geometry, geom3 geometry) RETURNS FLOAT AS
$BODY$
	--@brief : returns the oriented angle in radian  of the 3 geom centroids
		DECLARE 
			_temp float;  
		BEGIN   
			SELECT az + (az<0)::int*2*pi() INTO _temp
			FROM (SELECT ST_Azimuth(ST_Centroid(geom1),ST_Centroid(geom2)) - ST_Azimuth(ST_Centroid(geom3),ST_Centroid(geom2)) AS az) AS sub; 
			
			RETURN _temp ; 
		END ;
	--test 
	--SELECT ST_AsText(rc_centroid(geom ))
	--FROM st_geomfromtext('circularstring(0 0 , 1 1, 2 0)') as geom ; 
	--227.726310993906
$BODY$
 LANGUAGE plpgsql IMMUTABLE STRICT;

/*
 --test : 
	SELECT degrees(rc_angle( geom3,geom2,geom1))
	FROM ST_GeomFromText('POINT(0 0)') AS geom1 
		, ST_GeomFromText('POINT(3 5 )') AS geom2
		, ST_GeomFromText('POINT(8 6 )') AS geom3
		--should be 227.726310993906
*/
 
 