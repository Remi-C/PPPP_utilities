---------------------------
--Rémi -C  09/2014
--
--
----------------------------
--function to create an oriented bbox from center, axis, rotation.
------

-- SET search_path to rc_lib, public; 


	DROP FUNCTION IF EXISTS rc_BboxOrientedFromAxis(x_center float,y_center float,z_center float,axis_1 float, axis_2 float , angle float)  ; 
	CREATE OR REPLACE FUNCTION rc_BboxOrientedFromAxis(x_center float,y_center float,z_center float,axis_1 float, axis_2 float , angle float, OUT OBbox geometry(polygon) ) 
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
/*
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

*/




-- Function: trajectory.rc_cuttrajectoryintoextractparis140616(integer, integer)

 DROP FUNCTION IF EXISTS rc_BboxOrientedFromGeom(i_geom geometry); 
CREATE OR REPLACE FUNCTION rc_BboxOrientedFromGeom(i_geom geometry, OUT angle float, out l1 float, out l2 float,  out obbox geometry(polygon))
  AS
$BODY$
		--@brief : this function takes a geom and computes its oriented bbox, that is the mnimal area rectangle containing the geom
		DECLARE      
		BEGIN 	   

		
		WITH convex_hull AS (
			SELECT ST_CollectionExtract(ST_ConvexHull(i_geom),3) AS ch,ST_Centroid(i_geom) AS centroid  
		)
		,segments AS (
			SELECT  dmp.geom AS geom,convex_hull.ch,convex_hull.centroid, angle.angle
			FROM convex_hull   
				, rc_lib.rc_DumpSegments(ST_ExteriorRing(ch) ) AS dmp 
				,ST_Azimuth(ST_StartPoint(dmp.geom),ST_EndPoint(dmp.geom)) AS angle
				WHERE ST_IsEmpty(convex_hull.ch) = FALSE
		)  
		,areas AS (
			SELECT s.angle
				, ST_XMax(box)-ST_XMin(box) AS l1
				, ST_YMax(box)-ST_YMin(box) AS l2   
				,   area,   s.centroid 
				,box
			FROM segments AS s
				,Box2D(ST_Rotate(ch, s.angle,s.centroid)) AS box
				, ST_Area(box) as area
			ORDER BY area ASC , l1 ASC, l2 ASC
			LIMIT 1 
		)
		SELECT a.angle, a.l1,a.l2, obbox.obbox  INTO angle, l1,l2,obbox
		FROM  areas AS a
			, ST_Rotate(ST_Centroid(box),  -a.angle ,  centroid) aS rot_bbox_center
			,rc_lib.rc_BboxOrientedFromAxis(ST_X(rot_bbox_center), ST_Y(rot_bbox_center), 0 , a.l1,a.l2, - a.angle * 180/3.14)  AS obbox ;
	 
		obbox := ST_SetSRID(obbox,ST_SRID(i_geom)) ; 
	RETURN  ;
END ; 
	$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT ;

-- SELECT f.*, ST_AsText(obbox)
-- FROM ST_Geomfromtext('POLYGON((0 0 , 1 0 , 2 2 , 1 1,  0 1, -1 1  , 0 0))' )as geom, rc_BboxOrientedFromGeom(geom) AS f;
