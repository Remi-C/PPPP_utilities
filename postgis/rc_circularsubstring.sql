---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
--safe wrapper around ST_LineSubstring
--------------------------------------------

--SET search_path TO rc_lib, public
 
DROP FUNCTION IF EXISTS rc_circularsubstring( iline geometry, abs_1 double precision, abs_2 double precision) ; 
CREATE OR REPLACE FUNCTION rc_circularsubstring( iline geometry, abs_1 double precision, abs_2 double precision, OUT subline geometry)
  AS
$BODY$
	/** safe wrapper around st_linesubstring, doesn't give up when abs2>abs1
	*/
	DECLARE    
	BEGIN  
		IF abs_1 > abs_2 THEN 
			subline := ST_MAkeLine(ARRAY[ST_LineSubString(iline, abs_1, 1),ST_LineSubString(iline, 0, abs_2) ]) ; 
		ELSE
			subline := ST_LineSubString(iline, abs_1, abs_2)  ; 
		END IF ;  
		RETURN ; 
	END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 

/*
SELECT ST_Astext(rc_circularsubstring( iline , 0.9, 0.1 )) 
FROM ST_GeomFromText('LINESTRING(0 0 , 0 10 , 10 10 , 10 0 , 0 0)') AS iline
*/