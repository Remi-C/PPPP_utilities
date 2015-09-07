---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
-- given an axis and a polygon, try to fitt a parallelogram to the surface, expressed as an angle and a width at the axis level
--------------------------------------------


-- SET search_path TO rc_lib, public

 
 


DROP FUNCTION IF EXISTS  rc_fit_parallelogram(geometry, geometry, float) CASCADE; 
CREATE OR REPLACE FUNCTION rc_fit_parallelogram(  
	IN axis_geom geometry -- edge_id of the axis the pedestrian crossing is refereing too
	, IN u_pcross  geometry  --the geometry representing a pedestrian crossing  
	, IN positionning_orientation_type FLOAT DEFAULT 1 
	, IN allowed_angle_margin FLOAT DEFAULT 40 --the angle of the paralleloid is going to be between 90 - margin, 90+margin
	, IN support_line_size FLOAT DEFAULT 0.1 --the axis geom is locally considered , this is how much locally 
	, OUT orientation float --angle of the pedestrian crossing, absolute 
	, OUT size float -- size fo the pcrossing on the axis, in meter 
	 ) AS
$BODY$
	/** given an axis and a polygon, try to fit  a parallelogram to the surface, expressed as an angle and a width at the axis level
	an optioannal argument positionning_orientation_type set if the returned angle of the parallelogramoid is absolute or relative to the axis
	*/
	DECLARE   
		_npoints int  := ST_NumPoints($2) ;  
	BEGIN  

		IF _npoints = 2 THEN
			--insert rectangle  
				--angle is 90 degrees in relative
			RETURN ; 
		ELSE
			WITH i_data AS (
				SELECT axis_geom AS  _axis_geom , ST_CollectionExtract($2,3) AS _u_pcross, $3 AS positionning_orientation_type
					,allowed_angle_margin AS marg
					, support_line_size AS _support_line_size
				 
			) 
			, getting_edge_information AS (
				SELECT axis_geom AS edge_geom 
				FROM i_data 
			)
			, getting_edge_geom_around_centroid AS(
				SELECT f.*  , degrees(ST_Azimuth(rc_lib.rc_PointN(subline,1) , rc_lib.rc_PointN(subline,-1) ))::int % 180 AS az_axis
				FROM i_data,  getting_edge_information AS gi,
					rc_lib.rc_extract_subline(  
						edge_geom
						, ST_Centroid(_u_pcross)   
						, _support_line_size  ) as f
			)
			 ,getting_all_seg AS ( --extract all segments 
				SELECT row_number() over() AS uid, f.geom AS seg_geom , (degrees(ST_Azimuth( rc_lib.rc_PointN(f.geom,1) , rc_lib.rc_PointN(f.geom,-1))))::int as az_seg
				FROM i_data, rc_lib.rc_DumpSegments( _u_pcross ) as f
			)
			 , filtering_seg AS ( --keeping on ly segs that have an angle compatible with the axis perpendicular +- margin
				SELECT seg_geom,  az_seg  AS possible_angle  
					, az_axis BETWEEN ( (az_seg + 90) -marg ) - 180*factor AND( (az_seg + 90) +marg ) - 180*factor AS lateral_seg
				FROM i_data, getting_edge_geom_around_centroid AS eg,   getting_all_seg AS seg  
					, CAST(round(  (az_seg + 90 + marg )::int/180,1) AS INT) AS factor
			)
			, final_angle_1 AS ( --averaging possible angle to compute last
				SELECT sum((possible_angle % 180 )*st_length(seg_geom))/sum(st_length(seg_geom))  as angle --, rc_lib.rc_msg_vol('here is the found angle : '||avg(possible_angle % 180)  ) 
				FROM filtering_seg
				WHERE lateral_seg = TRUE
			)
			, final_angle_2 AS ( --averaging possible angle to compute last
				SELECT CASE WHEN ST_NumPoints(ST_ExteriorRing(_u_pcross)) >2 THEN angle ELSE 90 END as angle
				FROM i_data, final_angle_1 
			)
			,final_angle_rel AS (
				SELECT CASE WHEN id.positionning_orientation_type >=0 THEN  (- angle::int + az_axis::int+360)::int %180 ELSE angle  END AS angle
					--, rc_lib.rc_msg_vol('here is the found angle after correction on num points: '||angle)   
				FROM i_data AS id, getting_edge_geom_around_centroid, final_angle_2
			)
			,  finding_seg_left_right AS (
				SELECT seg_geom , degrees(rc_lib.rc_angle(ST_Centroid(seg_geom),rc_lib.rc_PointN(subline,1) , rc_lib.rc_PointN(subline,-1) ) )  > 180  AS is_left 
				FROM getting_edge_geom_around_centroid , filtering_seg
				WHERE lateral_seg = FALSE
			)
			, finding_spacing AS(
				SELECT ST_LineLocatePoint(edge_geom , rc_lib.rc_pointN(seg_geom ,1)) AS curvabs, is_left 
				FROM getting_edge_information, finding_seg_left_right AS slr
				UNION ALL 
				SELECT ST_LineLocatePoint(edge_geom , rc_lib.rc_pointN(seg_geom ,-1)) AS curvabs, is_left 
				FROM getting_edge_information, finding_seg_left_right AS slr
			)
			, possible_size AS (
				SELECT (max(curvabs) - min(curvabs) ) * ST_Length(edge_geom) AS possible_size
				FROM getting_edge_information, finding_spacing
				GROUP BY ST_Length(edge_geom)  , is_left
			)
			, final_size AS (
				SELECT avg(possible_size) as _size
				FROM possible_size
			)
			SELECT angle , _size  INTO orientation, size
			FROM final_angle_rel, final_size ; 

			-- RAISE NOTICE  'orientation %',orientation ; 
		END IF ; -- if on npoints
		RETURN ; 
	END ; $BODY$
LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT ; 


/*DROP TABLE IF EXISTS test.test_crossing_editing ; 
CREATE TABLE test.test_crossing_editing (
	gid serial primary key
	, crossing geometry(polygon,932011) 
) 

SELECT ST_AsText(ST_SnapToGrid(crossing,0,1)) 
FROM test.test_crossing_editing


	WITH i_data AS (
		SELECT 80393 AS  _edge_id 
		,  ST_GeomFromText('POLYGON((33159.6995617901 281,33164.0355865176 290,33172.9530713345 278,33166.8989990735 269,33159.6995617901 281))',932011) AS _u_pcross  --the geometry representing a pedestrian crossing  
		, 1 AS positionning_orientation_type
	) 
	, getting_edge_information AS (
		SELECT ed.geom AS edge_geom, largeur AS edge_width
		FROM i_data,  bdtopo_topological.edge_data AS ed
			LEFT OUTER JOIN bdtopo.road AS r ON (ed.ign_id = r.id)
			WHERE ed.edge_id = _edge_id
	)
	, getting_edge_geom_around_centroid AS(
		SELECT f.*  , degrees(ST_Azimuth(rc_lib.rc_PointN(subline,1) , rc_lib.rc_PointN(subline,-1) ))::int % 180 AS az_axis
		FROM i_data,  getting_edge_information AS gi,
			rc_extract_subline(  
				edge_geom
				, ST_Centroid(_u_pcross)   
				, 0.1  ) as f
	)
	 ,getting_all_seg AS ( --extract all segments 
		SELECT row_number() over() AS uid, f.geom AS seg_geom , (degrees(ST_Azimuth( rc_lib.rc_PointN(f.geom,1) , rc_lib.rc_PointN(f.geom,-1))))::int as az_seg
		FROM i_data, rc_lib.rc_DumpSegments( _u_pcross ) as f
	)
	 , filtering_seg AS ( --keeping on ly segs that have an angle compatible with the axis perpendicular +- margin
		SELECT seg_geom,  az_seg + 90 AS possible_angle , az_axis BETWEEN ( (az_seg + 90) -40 ) % 180 AND( (az_seg + 90) +40 ) % 180  AS lateral_seg
		FROM getting_edge_geom_around_centroid AS eg,   getting_all_seg AS seg   
	)
	, final_angle AS ( --averaging possible angle to compute last
		SELECT sum(possible_angle*ST_Length(seg_geom))/sum(st_length(seg_geom)) as angle
		FROM filtering_seg
		WHERE lateral_seg = TRUE
	)
	,  finding_seg_left_right AS (
		SELECT seg_geom , degrees(rc_angle(ST_Centroid(seg_geom),rc_lib.rc_PointN(subline,1) , rc_lib.rc_PointN(subline,-1) ) )  > 180  AS is_left 
		FROM getting_edge_geom_around_centroid , filtering_seg
		WHERE lateral_seg = FALSE
	)
	, finding_spacing AS(
		SELECT ST_LineLocatePoint(edge_geom , rc_lib.rc_pointN(seg_geom ,1)) AS curvabs, is_left 
		FROM getting_edge_information, finding_seg_left_right AS slr
		UNION ALL 
		SELECT ST_LineLocatePoint(edge_geom , rc_lib.rc_pointN(seg_geom ,-1)) AS curvabs, is_left 
		FROM getting_edge_information, finding_seg_left_right AS slr
	)
	, possible_size AS (
		SELECT (max(curvabs) - min(curvabs) ) * ST_Length(edge_geom) AS possible_size
		FROM getting_edge_information, finding_spacing
		GROUP BY ST_Length(edge_geom)  , is_left
	)
	, final_size AS (
		SELECT avg(possible_size) as size
		FROM possible_size
	)
	SELECT angle , size
	FROM final_angle, final_size

*/