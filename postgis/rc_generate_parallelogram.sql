---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
--project a point from a line to a given side of a buffer
--------------------------------------------


-- SET search_path TO rc_lib, public



 

DROP FUNCTION IF EXISTS rc_generate_parallelogram(
	IN iline geometry
	, IN center_point geometry
	, IN buffer geometry
	, IN  width FLOAT
	, IN alpha float
	,IN  support_line_size FLOAT
	,OUT parallelogramoid geometry
	 )  ;


	  
CREATE OR REPLACE FUNCTION rc_generate_parallelogram(  
	IN iline geometry
	, IN center_point geometry
	, IN buffer geometry
	, IN  width FLOAT
	, IN alpha float --expected ot be in degrees
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT parallelogramoid geometry
	 ) AS
$BODY$
	/** from 2 points, project left and right of axis on buffer, then create a surf out of 2 sublines.
	WARNING  angle is in degree  */
	DECLARE 
		_margin_times_width float := 10 ; --how many times of the pedestrian crossing width should we look for the border of the road
		_substr_l geometry ;
		_substr_r geometry ;
		_surf_line geometry ; 
		_abs float[] ;  
		_tmp float;  
		_buff_piece geometry[] ; 
	
	BEGIN  
		--project ipoint1 and ipoint2 on axis
		--project ipp1 and ipp2 on left and right of buffer
		--extract substrings of buffer
		--link substring to create a surface
		buffer := ST_ForceRHR(buffer )  ; 

		center_point := ST_CLosestPoint(iline, center_point) ; 
		IF alpha <0 THEN alpha :=(( (alpha*100)::int + 36000) %18000 )::int/100.0; END IF ;  --removing negativ values
 
		WITH i_data AS (
			SELECT iline AS _iline
			, ST_CLosestPoint(iline, center_point)  AS _center_point
			,  buffer  AS _buffer
			, width AS _width
			, radians(alpha) AS _alpha
			, support_line_size AS _support_line_size
		)
		, extracting_subline AS (
			SELECT  subline , rc_lib.rc_PointN(subline, 1) AS _ipoint1, rc_lib.rc_PointN(subline, -1) AS _ipoint2
			FROM i_data
				,  rc_lib.rc_extract_subline(   _iline , _center_point , _width )AS f 
		)
		, computing_limit_points_on_line AS (
			SELECT -1 as pos , 1 AS dir,  rc_lib.rc_project_point_on_buffer(_iline, _ipoint1, _buffer, _width*_margin_times_width, _alpha, _support_line_size) AS ppoint
			FROM i_data, extracting_subline UNION ALL
			SELECT  -1 as pos , -1 AS dir, rc_lib.rc_project_point_on_buffer(_iline, _ipoint1, _buffer, -_width*_margin_times_width, _alpha, _support_line_size)  
			FROM i_data, extracting_subline UNION ALL
			SELECT  +1 as pos , 1 AS dir, rc_lib.rc_project_point_on_buffer(_iline, _ipoint2, _buffer, _width*_margin_times_width, _alpha, _support_line_size)  
			FROM i_data, extracting_subline UNION ALL
			SELECT  +1 as pos , -1 AS dir, rc_lib.rc_project_point_on_buffer(_iline, _ipoint2, _buffer, -_width*_margin_times_width, _alpha, _support_line_size)  
			FROM i_data, extracting_subline  
		) 
		, numerised  AS (
			SELECT   dir , pos, ST_LineLocatePoint( ST_ExteriorRing(_buffer) , ppoint)  AS buff_point 
			FROM i_data, computing_limit_points_on_line  
		)
		 , aggregated AS (
			SELECT dir , array_agg(pos ORDER BY dir,pos*dir DESC) AS poss, array_agg(buff_point ORDER BY dir,pos*dir DESC)  AS buff_points 
			FROM numerised 
			GROUP BY dir 
		)
		SELECT array_agg( buff_piece ORDER BY dir ASC ) INTO _buff_piece
		FROM i_data, aggregated AS a  , rc_lib.rc_circularsubstring(ST_ExteriorRing(_buffer),buff_points[1], buff_points[2]  ) AS buff_piece
		GROUP BY TRUE;
  

		/*
		IF _abs[1]>_abs[2] THEN
			_substr_l := ST_Reverse(ST_LineSubstring(buffer, _abs[2], _abs[1]))  ;
		ELSIF _abs[3]>_abs[4] THEN
			_substr_r := ST_Reverse(ST_LineSubstring(buffer, _abs[3], _abs[4]))  ;
		ELSE 
			_substr_l := ST_LineSubstring(buffer, _abs[1], _abs[2]) ;
			_substr_r := ST_LineSubstring(buffer, _abs[3], _abs[4]) ;
		END IF;
		*/
		
		
		/*RAISE EXCEPTION 'coucou : 
%
%
%', ST_AsText(ST_SnapToGRid(_buff_piece[1],0.1)), ST_AsText(ST_SnapToGRid(_buff_piece[2],0.1)), St_AsText(rc_lib.rc_pointN(_buff_piece[1],1))  ; 
		--sewing substring 
	*/
		parallelogramoid := ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[_buff_piece[1] , _buff_piece[2], rc_lib.rc_pointN(_buff_piece[1],1)] )) , ST_SRID(buffer)) ;
		
	RETURN ;

	END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 
 
 
  /*
DROP SCHEMA IF EXISTS test ; 
CREATE SCHEMA IF NOT EXISTS test ;


DROP TABLE IF EXISTS test.making_parallelogram CASCADE; 
CREATE TABLE test.making_parallelogram AS
SELECT 1 AS gid, 
	iline::geometry(linestring,0), ibuff::geometry(polygon,0) 
	, width ,alpha, support_line_size 
	,rc_generate_parallelogram(
		 iline 
		, ST_Centroid(iline )  
		,  ibuff  
		,  width  
		, alpha
		,  support_line_size  
	)::geometry(polygon,0) as par
FROM  ST_GeomFromText('LINESTRING(-10 -10, 10 10)') as iline 
	, ST_Buffer(iline, 4 ) as ibuff
	, round(12.5::numeric,1) AS width
	, round(90::numeric,1) AS alpha
	, round(1::numeric,1)  AS support_line_size
	; 
	
	ALTER TABLE test.making_parallelogram ADD  PRIMARY KEY (gid) ; 



	CREATE OR REPLACE FUNCTION test.rc_update_parallelogram()
	RETURNS TRIGGER AS 
	$BODY$ 
	--- @brief :  udpate the geom of the parallelogram
	 
	DECLARE    
	BEGIN    
		NEW.ibuff :=  	ST_ForceRHR(ST_Reverse(ST_Buffer(NEW.iline,  NEW.width/4.0 ) ) )  ; 
		NEW.par :=  rc_lib.rc_generate_parallelogram(
			 NEW.iline 
			, ST_CLosestPoint(NEW.iline,ST_Centroid(NEW.iline ) )
			, NEW.ibuff 
			,  NEW.width  
			, NEW.alpha
			,  NEW.support_line_size  
		)::geometry(polygon,0) ; 
		RETURN NEW; 
	END ;
	$BODY$  
	 LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT;
 
DROP TRIGGER IF EXISTS  rc_update_parallelogram ON   test.making_parallelogram ;
CREATE TRIGGER rc_update_parallelogram 
BEFORE UPDATE OR INSERT 
ON  test.making_parallelogram 
FOR ROW 
EXECUTE PROCEDURE test.rc_update_parallelogram() ;
 */


 SELECT *
 FROM test.test_crossing_editing  
 WHERE gid = 5
  