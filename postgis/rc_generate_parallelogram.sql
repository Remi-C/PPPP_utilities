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
	 );


	  
CREATE OR REPLACE FUNCTION rc_generate_parallelogram(  
	IN iline geometry
	, IN ipoint1  geometry 
	, IN ipoint2 geometry 
	, IN buffer geometry
	, IN  width FLOAT
	, IN alpha float
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT osurf geometry
	 ) AS
$BODY$
	/** from 2 points, project left and right of axis on buffer, then create a surf out of 2 sublines.
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

		ipoint1 := ST_CLosestPoint(iline, ipoint1) ;
		ipoint2 := ST_CLosestPoint(iline, ipoint2) ;
		

		_ipb1_l  := rc_project_point_on_buffer(iline, ipoint1, buffer, width, alpha, support_line_size) ; 
		_ipb1_r  := rc_project_point_on_buffer(iline, ipoint1, buffer, -width, alpha, support_line_size) ;
		_ipb2_l  := rc_project_point_on_buffer(iline, ipoint2, buffer, width, alpha, support_line_size) ;
		_ipb2_r  := rc_project_point_on_buffer(iline, ipoint2, buffer, -width, alpha, support_line_size) ; 

		buffer := ST_ExteriorRing(buffer)  ; 
		--extracting substrings 
		SELECT array_agg(abs ORDER BY side, cat ) INTO _abs
		FROM (
		SELECT ST_LineLocatePoint(buffer,_ipb2_l) as abs, 2 AS cat, 'l' AS side
		UNION ALL  SELECT ST_LineLocatePoint(buffer,_ipb1_l)  ,1 AS cat, 'l' AS side
		UNION ALL  SELECT ST_LineLocatePoint(buffer,_ipb2_r)  ,2 AS cat, 'r' AS side
		UNION ALL  SELECT ST_LineLocatePoint(buffer,_ipb1_r) ,1 AS cat, 'r' AS side
		) AS sub ; 

		IF _abs[1]>_abs[2] THEN
			_substr_l := ST_Reverse(ST_LineSubstring(buffer, _abs[2], _abs[1]))  ;
		ELSIF _abs[3]>_abs[4] THEN
			_substr_r := ST_Reverse(ST_LineSubstring(buffer, _abs[3], _abs[4]))  ;
		ELSE 
			_substr_l := ST_LineSubstring(buffer, _abs[1], _abs[2]) ;
			_substr_r := ST_LineSubstring(buffer, _abs[3], _abs[4]) ;
		END IF;

		--RAISE EXCEPTION '_abs %', _abs;
		
		--RAISE EXCEPTION 'coucou' ; 
		--sewing substring 
		osurf := ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[_substr_l , _substr_r, rc_lib.rc_pointN(_substr_l,1)] )) , ST_SRID(buffer)) ;
		
	RETURN ;

	END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 
 
/*
DROP TABLE IF EXISTS temp_test ;
CREATE TABLE temp_test AS 
SELECT 1 AS gid, ipoint, iline, ibuff, f 
FROM  ST_MakePoint(1 ,1)  AS ipoint
	, ST_GeomFromText('LINESTRING(-10 -10, 10 10)') as iline 
	, ST_Buffer(iline, 4 ) as ibuff
	, rc_project_point_on_buffer(iline, ipoint, ibuff, 100, radians(-90), 0.1)  as f
*/
/*
SELECT ST_AsText(ST_MakeLine(iline1, iline2) ) 
FROM ST_GeomFromText('LINESTRING(0 0, 10 10)') as iline1 
	, ST_GeomFromText('LINESTRING( 0 10,-10 0)') as iline2 
*/
 
CREATE SCHEMA IF NOT EXISTS test ;
/*
DROP TABLE IF EXISTS test.making_parallelogram CASCADE; 
CREATE TABLE test.making_parallelogram AS
SELECT 1 AS gid, ipoint1::geometry(point,0), ipoint2::geometry(point,0) ,
	iline::geometry(linestring,0), ibuff::geometry(polygon,0) 
	, width ,alpha, support_line_size 
	 
FROM  ST_MakePoint(1 ,1)  AS ipoint1
	, ST_MakePoint(2 ,1) AS ipoint2
	, ST_GeomFromText('LINESTRING(-10 -10, 10 10)') as iline 
	, ST_Buffer(iline, 4 ) as ibuff
	, round(12.5::numeric,1) AS width
	, round(pi()::numeric/2,1) AS alpha
	, round(1::numeric,1)  AS support_line_size
	; 

*/

SELECT *
FROM  test.making_parallelogram  ; 


DROP TABLE IF EXISTS test.making_parallelogram_v CASCADE; 
CREATE TABLE test.making_parallelogram_v AS
SELECT DISTINCT ON (TRUE) 1 AS gid,  ST_SetSRID(rc_generate_parallelogram(
		 iline 
		, ipoint1  
		,  ipoint2  
		,  ST_Buffer(iline, 4 )   
		,  width  
		, radians(alpha)
		,  support_line_size  
	),4326)::geometry(polygon,4326) AS  f   
FROM test.making_parallelogram AS mp  ;
	
 