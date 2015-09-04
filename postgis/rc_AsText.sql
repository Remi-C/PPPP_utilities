---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
--wrapper around st_astext to integrate snapping option to reduce text size
--------------------------------------------


-- SET search_path TO rc_lib, public

DROP FUNCTION IF EXISTS rc_AsText(geometry, float ) ; 
CREATE OR REPLACE FUNCTION rc_AsText(  
	IN geom geometry
	, IN snapping_size FLOAT DEFAULT  NULL
	, OUT wkt_geom text 
	 ) AS
$BODY$
	/** wrapper around st_astext, with snapping to reduce text size */
	DECLARE    
	BEGIN  
		IF snapping_size IS NULL THEN wkt_geom := ST_AsText(geom) ; 
		ELSE
			wkt_geom := ST_AsText(ST_SnapToGrid(geom,snapping_size)) ; 
		END IF ; 
		RETURN ;

	END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 

SELECT rc_AsText(geom,0.1 )
FROM ST_GeomFromText('LINESTRING(1 1, 2.2 2.2, 3.23 3.23, 4.234 4.234, 5.2345 5.2345)') AS geom ; 