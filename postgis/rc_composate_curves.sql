--------------------
-- Rémi Cura, Thales IGN, 2016
-- function to compose 2 curves
-------------------


DROP FUNCTION IF EXISTS   rc_composate_curves(geometry,geometry, float);
CREATE OR REPLACE FUNCTION  rc_composate_curves(curve_b geometry, curve_c geometry, support_line_size float, OUT composated geometry)  AS 
	$BODY$
		/** construct a new curve so that for each point of curve_c, it gets considered orthogonaly to curv_b at the same curv abs
			-- X of curve_c is expected to contain curv abs
		*/
		DECLARE       
		BEGIN 
			WITH input_data AS (
				SELECT curve_b , curve_c 
			)
			, points AS ( -- extracting points from curve_c
				SELECT dmp.path , dmp.geom , ST_X(geom )AS curvabs
				FROM input_data, st_dumppoints(input_data.curve_c) AS dmp
			)
			, has_m AS  (
				SELECT min(ST_M(geom))IS NOT NULL AS has_m
				FROM points
			)
			SELECT  CASE WHEN has_m = FALSE THEN 
				ST_MakeLine(ST_MakePoint(ST_X(off_point), ST_Y(off_point) , curvabs) ORDER BY path ASC) 
				ELSE 
					ST_MakeLine(ST_MakePoint(ST_X(off_point), ST_Y(off_point) , curvabs, ST_M(geom)) ORDER BY path ASC) 
				END
				INTO composated 
			FROM input_data, has_m , points ,  ST_LineInterpolatePoint(input_data.curve_b, curvabs) AS new_base_point
				, rc_lib.rc_generate_orthogonal_point(  input_data.curve_b  , new_base_point , - ST_Y(geom)  ,  support_line_size ) as off_point  
			 GROUP BY has_m ; 
			RETURN ; 
		END ;  
	$BODY$
LANGUAGE plpgsql STABLE STRICT; 

/*
  --test
SELECT ST_AsText(f.*)
FROM  st_geomfromtext('LINESTRING(0 0, 1 1, 2 2 ,3 3, 4 4)')  AS curve_b
	, st_geomfromtext('LINESTRING(0 0.5,0.2 0.2, 0.4 0.4 ,0.6 0.1, 0.8 0.2,1 0.8)')  AS curve_c
		, rc_composate_curves(curve_b,curve_c, ST_Length(curve_b)/100.0) as f ; 
*/



