---------------------------
--Rémi -C  09/2014
--
--
----------------------------
--function to create an oriented bbox from center, axis, rotation.
------
	DROP FUNCTION IF EXISTS public.rc_BboxOrientedFromAxis(x_center float,y_center float,z_center float,axis_1 float, axis_2 float , angle float)  ; 
	CREATE OR REPLACE FUNCTION public.rc_BboxOrientedFromAxis(x_center float,y_center float,z_center float,axis_1 float, axis_2 float , angle float, OUT OBbox geometry(polygon) ) 
	RETURNS geometry AS 
		$BODY$
			--@brief : this function output the rectangle defined by 2 axe, a roation and a center. Rotation is in degree
			DECLARE      
			BEGIN 	 
		
				WITH i_d AS (
					SELECT 
						 x_center
						,  y_center
						, z_center
						, axis_1 
						, axis_2
						, angle
				)
				SELECT   t_o_bbox INTO OBbox
				FROM i_d
					,ST_MakeEnvelope(-i_d.axis_1/2.0 ,-i_d.axis_2/2.0, i_d.axis_1/2.0, i_d.axis_2/2.0) AS bbox
					,ST_Rotate(bbox, radians(i_d.angle)) as bbox_rot
					,ST_translate(bbox_rot, i_d.x_center, i_d.y_center, i_d.z_center) as t_o_bbox ;
				
			RETURN ;
			END ; 
		$BODY$
	LANGUAGE plpgsql IMMUTABLE STRICT;     
 
	SELECT  ST_AsText(geom)
	FROM rc_BboxOrientedFromAxis( 651367.2,6860701.73085937,50 , 0.3 , 0.2  , 34.7219773903111 ) AS geom;

	WITH i_d AS (
		SELECT 
			651367.2 as x_center
			,6860701.73085937 AS y_center
			,50 AS z_center
			,0.3 AS axis_1 
			,0.2 AS axis_2
			,34.7 AS angle
	)
	SELECT   * 
	FROM i_d
		,ST_MakeEnvelope(-axis_1/2.0 ,-axis_2/2.0, axis_1/2.0, axis_2/2.0) AS bbox
		,ST_Rotate(bbox, radians(angle)) as bbox_rot
		,ST_Astext(ST_translate(bbox_rot, x_center, y_center, z_center))  ;
