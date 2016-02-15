---------------------------------------------
--Copyright Remi-C Thales IGN 07/2014
--
--generating an othogonal line of given width at given point of input line
--
--
--this script create the data model for street_gen_3
--------------------------------------------


-- set search_path to rc_lib, public

 
DROP FUNCTION IF EXISTS rc_generate_orthogonal_point(
	IN iline geometry
	, IN icurvabs float
	, IN  width FLOAT
	,IN  support_line_size FLOAT 
	 );
 
CREATE OR REPLACE FUNCTION rc_generate_orthogonal_point(  
	IN iline geometry
	, IN icurvabs float
	, IN  width FLOAT
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT opoint geometry
	 ) AS
$BODY$
DECLARE    
	ipoint geometry ;
	ipoint_curvabs float ;
	curvwidth FLOAT; 
	sub  geometry ; 
	spt1 geometry;
	spt2 geometry ;
	d_vect_x float ;
	d_vect_y float ;
	d_norm FLOAT ; 
	text_var1 text;
BEGIN 
	--BEGIN
	
		--@brief this function compute an orthogonale output point tothe iline at thegiven ipoint of width width. For doing so it uses the st_linesubstring functionn hence the paramter support_line_size that define the size of the substring used to compute iline 

			--check input type 
			--get curvabs of ipoint on iline if necessary 
			--transpose width into curvabs size
			--get support substring 
			--compute normal vector 
			--apply normal vector to get 2 new points of oline, construct line with it.
			 
			IF(ST_IsEmpty(iline)=TRUE OR icurvabs IS NULL OR icurvabs > 1 OR icurvabs < 0)
				--RAISE NOTICE 'at least one of the input geom is empty, returning null';
				THEN return;
			END IF;

			ipoint_curvabs  := icurvabs ;
			ipoint := ST_LineInterpolatePoint(iline,icurvabs) ; 
			--RAISE NOTICE 'type of input : %',  ipoint_type%TYPE ; 

			curvwidth := LEAST(support_line_size / ST_Length(iline),1) ; 
			sub  := ST_LineSubstring(iline,GREATEST(ipoint_curvabs - curvwidth,0), LEAST( ipoint_curvabs+curvwidth,1)  );  

			spt1 := rc_lib.rc_pointN(sub,1);
			spt2 := rc_lib.rc_pointN(sub,-1);
			d_vect_x := ST_X(spt1) -ST_X(spt2) ;
			d_vect_y := ST_Y(spt1) -ST_Y(spt2) ;

			d_norm := sqrt(d_vect_x^2+d_vect_y^2) ;
			d_vect_x := d_vect_x/d_norm; 
			d_vect_y := d_vect_y/d_norm;

			opoint := ST_SetSRID( 
				ST_MakePoint(
					ST_X(ipoint) -  width/2 * d_vect_y
					,ST_Y(ipoint) + width/2 * d_vect_x   ) 
				 , ST_SRID(iline)) ; 
			RETURN ;
		--EXCEPTION WHEN OTHERS THEN
		--	GET STACKED DIAGNOSTICS text_var1 = MESSAGE_TEXT;
		--	RAISE NOTICE 'big problem : %', text_var1;
		--	RAISE NOTICE 'faulty input: % , %, % ,%' ,ST_AsText(iline) ,ST_Astext(ipoint ) , width , support_line_size;
		--END;
		END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 

DROP FUNCTION IF EXISTS rc_generate_orthogonal_point(  
	IN iline geometry
	, IN ipoint  geometry
	, IN  width FLOAT
	,IN  support_line_size  ) ;  
CREATE OR REPLACE FUNCTION rc_generate_orthogonal_point(  
	IN iline geometry
	, IN ipoint  geometry
	, IN  width FLOAT
	,IN  support_line_size FLOAT DEFAULT 0.1  
	, OUT opoint geometry
	 ) AS
$BODY$
DECLARE    
	ipoint_curvabs float ;
	curvwidth FLOAT; 
	sub  geometry ; 
	spt1 geometry;
	spt2 geometry ;
	d_vect_x float ;
	d_vect_y float ;
	d_norm FLOAT ; 
	text_var1 text;
BEGIN 
	--BEGIN
	
		--@brief this function compute an orthogonale output point tothe iline at thegiven ipoint of width width. For doing so it uses the st_linesubstring functionn hence the paramter support_line_size that define the size of the substring used to compute iline 

			--check input type 
			--get curvabs of ipoint on iline if necessary 
			--transpose width into curvabs size
			--get support substring 
			--compute normal vector 
			--apply normal vector to get 2 new points of oline, construct line with it.
			 
			IF(ST_IsEmpty(iline)=TRUE OR ST_IsEmpty(ipoint)) 
				--RAISE NOTICE 'at least one of the input geom is empty, returning null';
				THEN return;
			END IF;

			ipoint_curvabs  := ST_LineLocatePoint(iline , ipoint) ;
			--RAISE NOTICE 'type of input : %',  ipoint_type%TYPE ; 

			opoint := rc_generate_orthogonal_point(  iline ,ipoint_curvabs  , width  , support_line_size   ) ; 
			
			RETURN ;
		--EXCEPTION WHEN OTHERS THEN
		--	GET STACKED DIAGNOSTICS text_var1 = MESSAGE_TEXT;
		--	RAISE NOTICE 'big problem : %', text_var1;
		--	RAISE NOTICE 'faulty input: % , %, % ,%' ,ST_AsText(iline) ,ST_Astext(ipoint ) , width , support_line_size;
		--END;
		END ;
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT; 

/*
SELECT f.* , ST_AsText(opoint) 
FROM ST_GeomFromText('LINESTRING(0 0, 10 10 )') AS line1,
	ST_GeomFromText('POINT(1 1 )') AS point
	,rc_generate_orthogonal_point(  
	line1
	,point
	, - 10
	,support_line_size:=0.1  ) as f ; 
*/

DROP FUNCTION IF EXISTS rc_generate_orthogonal_line(
	IN iline geometry
	, IN ipoint geometry
	, IN  width FLOAT
	,IN  support_line_size FLOAT
	,OUT oline geometry
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
	ipoint_curvabs float ;
	curvwidth FLOAT; 
	sub  geometry ; 
	spt1 geometry;
	spt2 geometry ;
	d_vect_x float ;
	d_vect_y float ;
	d_norm FLOAT ; 
	text_var1 text;
BEGIN 
	--BEGIN
	
		--@brief this function compute an orthogonale output line tothe iline at thegiven ipoint of width width. For doing so it uses the st_linesubstring functionn hence the paramter support_line_size that define the size of the substring used to compute iline 

			--check input type 
			--get curvabs of ipoint on iline if necessary 
			--transpose width into curvabs size
			--get support substring 
			--compute normal vector 
			--apply normal vector to get 2 new points of oline, construct line with it.
			 
			IF(ST_IsEmpty(iline)=TRUE OR ST_IsEmpty(ipoint)) 
				--RAISE NOTICE 'at least one of the input geom is empty, returning null';
				THEN return;
			END IF;

			ipoint_curvabs  := ST_LineLocatePoint(iline , ipoint) ;
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
		--EXCEPTION WHEN OTHERS THEN
		--	GET STACKED DIAGNOSTICS text_var1 = MESSAGE_TEXT;
		--	RAISE NOTICE 'big problem : %', text_var1;
		--	RAISE NOTICE 'faulty input: % , %, % ,%' ,ST_AsText(iline) ,ST_Astext(ipoint ) , width , support_line_size;
		--END;
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


SELECT st_astext(r.oline),  ST_IsEmpty('01020000A0AB380E0000000000'::geometry) , ST_AsText('01020000A0AB380E0000000000'::geometry)
	FROM  
		rc_generate_orthogonal_line(  
			 '01020000A0AB380E0000000000'::geometry
			,'0101000020AB380E00C2CCFFFFFFA6B5400539939939A0D540'::geometry
			, 9.01
			, 0.01  
			 )  AS r ; 
 */ 


