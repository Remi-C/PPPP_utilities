---------------------------------------------
--Copyright Remi-C Thales IGN 07/2014
--
--generating an othogonal line of given width at given point of input line
--
--
--this script create the data model for street_gen_3
--------------------------------------------






DROP FUNCTION IF EXISTS rc_generate_orthogonal_line(
	IN iline geometry
	, IN ipoint geometry
	, IN  width FLOAT
	,IN  support_line_size FLOAT
	,oUT oline geometry
	 );
	  
CREATE OR REPLACE FUNCTION rc_generate_orthogonal_line(  
	IN iline geometry
	, IN ipoint  geometry
	, IN  width FLOAT
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT oline geometry
	 ) AS
$BODY$
DECLARE    
	ipoint_curvabs float := ST_LineLocatePoint(iline , ipoint) ;
	curvwidth FLOAT; 
	sub  geometry ; 
	spt1 geometry;
	spt2 geometry ;
	d_vect_x float ;
	d_vect_y float ;
	d_norm FLOAT ; 
BEGIN 
		--@brief this function compute an orthogonale output line tothe iline at thegiven ipoint of width width. For doing so it uses the st_linesubstring functionn hence the paramter support_line_size that define the size of the substring used to compute iline 

			--check input type 
			--get curvabs of ipoint on iline if necessary 
			--transpose width into curvabs size
			--get support substring 
			--compute normal vector 
			--apply normal vector to get 2 new points of oline, construct line with it.
			 
			
			--RAISE NOTICE 'type of input : %',  ipoint_type%TYPE ; 

			curvwidth := LEAST(support_line_size / ST_Length(iline),1) ; 
			sub  := ST_LineSubstring(iline,GREATEST(ipoint_curvabs - curvwidth,0), LEAST( ipoint_curvabs+curvwidth,1)  );  

			spt1 := rc_pointN(sub,1);
			spt2 := rc_pointN(sub,-1);
			d_vect_x := ST_X(spt1) -ST_X(spt2) ;
			d_vect_y := ST_Y(spt1) -ST_Y(spt2) ;

			d_norm := sqrt(d_vect_x^2+d_vect_y^2) ;
			d_vect_x := d_vect_x/d_norm; 
			d_vect_y := d_vect_y/d_norm;

			oline := ST_SetSRID(ST_MakeLine(
				ST_MakePoint(
					ST_X(ipoint) -  width/2 * d_vect_y
					,ST_Y(ipoint) + width/2 * d_vect_x   )
				,ST_MakePoint(
					ST_X(ipoint) +  width/2 * d_vect_y
					,ST_Y(ipoint) - width/2 * d_vect_x   )
				), ST_SRID(iline))
			RETURN ;
		END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 

	--testing
/*	SELECT st_astext(r.oline)
	FROM 
		ST_GeomFromtext('linestring(0 0, 1 0 , 0 1 )') AS l, 
		ST_GeomFromtext('POINT( 1 0  )') AS p, 
		rc_generate_orthogonal_line(  
			 l
			, p
			, 5
			, 0.1  
			 )  AS r
*/