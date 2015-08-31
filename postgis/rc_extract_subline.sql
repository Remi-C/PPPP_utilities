---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
--extract a substring around a point projection on a line
-- tolerant against strange arguments
--------------------------------------------


-- SET search_path TO rc_lib, public


DROP FUNCTION IF EXISTS rc_extract_subline(geometry, geometry, float ) ; 
CREATE OR REPLACE FUNCTION rc_extract_subline(  
	IN iline geometry
	, IN ipoint  geometry 
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT subline geometry
	 ) AS
$BODY$
DECLARE    
	ipoint_curvabs float ; 
	curvwidth float ;
BEGIN  
	/** given a point and a line, returns a small subline of the line around the point projection on the line 
	*/ 
		ipoint := rc_lib.rc_pointN(ipoint, 1)  ; --safeguard against mutlipoint or collection, etc
		
			IF(ST_IsEmpty(iline)=TRUE OR ST_IsEmpty(ipoint)) 
				--RAISE NOTICE 'at least one of the input geom is empty, returning null';
				THEN return;
			END IF;
			--safeguard against multiline/geomcollection
			SELECT DISTINCT ON (TRUE) dmp.geom INTO iline
			FROM ST_Dump(ST_CollectionExtract(iline,2)) AS dmp
			ORDER BY TRUE, ST_Distance(dmp.geom ,  ipoint) ASC   ;
 
			
			ipoint_curvabs  := ST_LineLocatePoint(iline , ipoint) ; 
			curvwidth := LEAST(support_line_size / ST_Length(iline),1) ; 
			subline  := ST_LineSubstring(iline,GREATEST(ipoint_curvabs - curvwidth,0), LEAST( ipoint_curvabs+curvwidth,1)  );  
 
			RETURN ; 
		END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 

/*
SELECT ST_AsText(r) 
FROM ST_GeomFromText('POINT(0 3)') AS ipoint ,
	ST_GeomFromText('MULTILINESTRING((0 0 , 10 10) , (1 0, 11 10))') AS iline 
	 , rc_extract_subline( iline, ipoint, 0.1 )  as r 
*/