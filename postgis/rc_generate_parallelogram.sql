---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
--project a point from a line to a given side of a buffer
--------------------------------------------


-- SET search_path TO rc_lib, public



 

DROP FUNCTION IF EXISTS rc_generate_parallelogram(
	IN iline geometry
	, IN ipoint1 geometry 
	, IN ipoint2 geometry 
	, IN buffer geometry
	, IN  width FLOAT
	, IN alpha float
	,IN  support_line_size FLOAT
	,OUT opoint geometry
	 )  ;


	  
CREATE OR REPLACE FUNCTION rc_generate_parallelogram(  
	IN iline geometry
	, IN ipoint1  geometry 
	, IN ipoint2 geometry 
	, IN buffer geometry
	, IN  width FLOAT
	, IN alpha float --expected ot be in degrees
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT osurf geometry
	 ) AS
$BODY$
	/** from 2 points, project left and right of axis on buffer, then create a surf out of 2 sublines.
	WARNING  angle is in degree
	*/
	DECLARE
		_ipb1_l geometry ;
		_ipb1_r geometry ;
		_ipb2_l geometry ;
		_ipb2_r geometry ;
		_substr_l geometry ;
		_substr_r geometry ;
		_surf_line geometry ; 
		_abs float[] ;  
		_tmp float;  
	
	BEGIN  
		--project ipoint1 and ipoint2 on axis
		--project ipp1 and ipp2 on left and right of buffer
		--extract substrings of buffer
		--link substring to create a surface
		buffer := ST_ExteriorRing(buffer ) ; 

		ipoint1 := ST_CLosestPoint(iline, ipoint1) ;
		ipoint2 := ST_CLosestPoint(iline, ipoint2) ; 
 
		WITH i_data AS (
			SELECT iline AS _iline
			,  ipoint1  AS _ipoint1
			,  ipoint2 AS _ipoint2
			,  buffer  AS _buffer
			, width AS _width
			, radians(alpha) AS _alpha
			, support_line_size AS _support_line_size
		)
		,projecting_points AS ( --projecting points on buffer
			SELECT  rc_lib.rc_project_point_on_buffer(_iline, _ipoint1, _buffer, _width, _alpha, _support_line_size)   AS ipb1_l
				 ,  rc_lib.rc_project_point_on_buffer(_iline, _ipoint1, _buffer, -_width, _alpha, _support_line_size)  AS ipb1_r
				,   rc_lib.rc_project_point_on_buffer(_iline, _ipoint2, _buffer, _width, _alpha, _support_line_size)   AS ipb2_l
				,   rc_lib.rc_project_point_on_buffer(_iline, _ipoint2, _buffer, -_width, _alpha, _support_line_size)  AS ipb2_r
			FROM i_data
		)  
		--,converting_to_curv_abs As ( -- converting each projected point to  a curvilinear abcisia
		SELECT ARRAY[ST_LineLocatePoint(_buffer, ipb2_l)  
			, ST_LineLocatePoint(_buffer, ipb1_l) 
			,ST_LineLocatePoint(_buffer, ipb1_r) 
			, ST_LineLocatePoint(_buffer, ipb2_r)  ]
			INTO _abs 
		FROM i_data , projecting_points ;

		--RAISE EXCEPTION '_abs % ',_abs; 

		_substr_l := rc_lib.rc_circularsubstring(buffer, _abs[1], _abs[2]) ;
		_substr_r := rc_lib.rc_circularsubstring(buffer, _abs[3], _abs[4]) ;

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
		
		
		--RAISE EXCEPTION 'coucou' ; 
		--sewing substring 
		osurf := ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[_substr_l , _substr_r, rc_lib.rc_pointN(_substr_l,1)] )) , ST_SRID(buffer)) ;
		
	RETURN ;

	END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 
 
 
  /*
DROP SCHEMA IF EXISTS test ; 
CREATE SCHEMA IF NOT EXISTS test ;


DROP TABLE IF EXISTS test.making_parallelogram CASCADE; 
CREATE TABLE test.making_parallelogram AS
SELECT 1 AS gid, ipoint1::geometry(point,0), ipoint2::geometry(point,0) ,
	iline::geometry(linestring,0), ibuff::geometry(polygon,0) 
	, width ,alpha, support_line_size 
	,rc_generate_parallelogram(
		 iline 
		, ipoint1  
		,  ipoint2  
		,  ibuff  
		,  width  
		, alpha
		,  support_line_size  
	)::geometry(polygon,0) as par
FROM  ST_MakePoint(1 ,1)  AS ipoint1
	, ST_MakePoint(2 ,1) AS ipoint2
	, ST_GeomFromText('LINESTRING(-10 -10, 10 10)') as iline 
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
		NEW.ibuff := ST_Buffer(NEW.iline,  NEW.width/4.0 ); 
		NEW.ipoint1  := ST_CLosestPoint(NEW.iline, NEW.ipoint1 ) ; 
		NEW.ipoint2  := ST_CLosestPoint(NEW.iline, NEW.ipoint2 ) ; 
		NEW.par :=  rc_lib.rc_generate_parallelogram(
			 NEW.iline 
			, NEW.ipoint1  
			,  NEW.ipoint2  
			,  NEW.ibuff  
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
 