---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
--project a point from a line to a given side of a buffer
--------------------------------------------


-- SET search_path TO rc_lib, public



 

DROP FUNCTION IF EXISTS rc_project_point_on_buffer(
	IN iline geometry
	, IN ipoint geometry 
	, IN buffer geometry
	, IN  width FLOAT
	, IN alpha float
	,IN  support_line_size FLOAT
	,OUT opoint geometry
	 );


	  
CREATE OR REPLACE FUNCTION rc_project_point_on_buffer(  
	IN iline geometry
	, IN ipoint  geometry 
	, IN buffer geometry
	, IN  width FLOAT
	, IN alpha float
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT opoint geometry
	 ) AS
$BODY$
	/** from a point, project it to the line, then create a new line with width/2 length with the correct angle as cutting blade, then cut the buffer and return the closest cut point
	*/
	DECLARE    
	 
	BEGIN  
		IF ST_GeometryType(buffer) ILIKE '%line%'  THEN 
			buffer := ST_GeometryN(buffer,1) ; 
		ELSIF ST_GeometryType(buffer) ILIKE '%polygon%'  THEN 
			buffer := ST_ExteriorRing(ST_GeometryN(buffer,1)) ; 
		ELSE
			RETURN ; 
		END IF ;
		
		WITH cutting_blade AS (
			SELECT f.oline AS cb
			FROM rc_lib.rc_generate_angled_line(
					 iline 
					,  ipoint  
					,  width  
					,   alpha 
					, support_line_size     )   AS f
		) 
		SELECT DISTINCT ON (TRUE) dmp.geom INTO opoint
		FROM cutting_blade, ST_Intersection(cb, buffer ) AS inter, ST_DumpPoints(inter) as dmp
		ORDER BY TRUE, ST_Distance(dmp.geom, rc_lib.rc_PointN(iline,1))  ;

		
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

 