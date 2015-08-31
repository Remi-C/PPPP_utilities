---------------------------------------------
--Copyright Remi-C Thales IGN 2015
--
--generate a line with a given angle to the input one
--------------------------------------------


-- SET search_path TO rc_lib, public



 

DROP FUNCTION IF EXISTS rc_generate_angled_line(
	IN iline geometry
	, IN ipoint geometry 
	, IN  width FLOAT
	, IN alpha float
	,IN  support_line_size FLOAT
	,OUT aline geometry
	 );


	  
CREATE OR REPLACE FUNCTION rc_generate_angled_line(  
	IN iline geometry
	, IN ipoint  geometry 
	, IN  width FLOAT
	, IN alpha float
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT oline geometry
	 ) AS
$BODY$
	/** from a point, project it to the line, then create a new line with width/2 length with the correct angle
	*/
	DECLARE    
	ipoint_curvabs float ;
	_p_ipoint geometry ; 
	curvwidth FLOAT; 
	sub  geometry ; 
	spt1 geometry;
	spt2 geometry ;
	d_vect_x float ;
	d_vect_y float ;
	d_norm FLOAT ; 
	text_var1 text;
	BEGIN  
		ipoint := rc_lib.rc_pointN(ipoint, 1)  ; --safeguard against mutlipoint or collection, etc
		
		IF(ST_IsEmpty(iline)=TRUE OR ST_IsEmpty(ipoint)) 
			--RAISE NOTICE 'at least one of the input geom is empty, returning null';
			THEN RETURN;
		END IF;
		--safeguard against multiline/geomcollection
		SELECT DISTINCT ON (TRUE) dmp.geom INTO iline
		FROM ST_Dump(ST_CollectionExtract(iline,2)) AS dmp
		ORDER BY TRUE, ST_Distance(dmp.geom ,  ipoint) ASC   ;

		--project the point on the line
		ipoint_curvabs  := ST_LineLocatePoint(iline , ipoint) ; 
		_p_ipoint := ST_LineInterpolatePoint( iline,ipoint_curvabs) ;
		curvwidth := LEAST(support_line_size / ST_Length(iline),1) ; 
		sub  := ST_LineSubstring(iline,GREATEST(ipoint_curvabs - curvwidth,0), LEAST( ipoint_curvabs+curvwidth,1)  );  

		--get a substring, get director vector
		spt1 := rc_lib.rc_pointN(sub,1);
		spt2 := rc_lib.rc_pointN(sub,-1);
		d_vect_x := ST_X(spt1) -ST_X(spt2) ;
		d_vect_y := ST_Y(spt1) -ST_Y(spt2) ;

		d_norm := sqrt(d_vect_x^2+d_vect_y^2) ;
		d_vect_x := d_vect_x/d_norm; 
		d_vect_y := d_vect_y/d_norm;

		-- create new point and make a line out of it
		oline := ST_MakeLine(
			ST_SetSRID( 
			_p_ipoint
			 , ST_SRID(iline))
			,
			ST_SetSRID( 
			ST_MakePoint(
				ST_X(_p_ipoint) +  width/2.0 * (d_vect_x * cos(alpha) -  d_vect_y* sin(alpha) )
				,ST_Y(_p_ipoint) + width/2.0 * (d_vect_x* sin(alpha)  + d_vect_y * cos(alpha) ) ) 
			 , ST_SRID(iline))
			 ) ;
		RETURN ;

	END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 

/*
SELECT st_astext(r.oline)    
	FROM 
		ST_GeomFromtext('linestring(0 0, 10 10 )') AS l, 
		ST_GeomFromtext('POINT( 3 0  )') AS p, 
		rc_generate_angled_line(  
			 l
			, p
			, -5
			, pi()/2
			, 0.1  
			)  AS r ; 
*/