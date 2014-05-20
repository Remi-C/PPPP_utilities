-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--support function : given 3 segments sharing an end point, and either a radius or the tangency point, compute the parameter of the circle that is tangent to both segment and
--	passes by tangency point OR has given radius
--	 
------------------------------


 --------------------- python function to compute the center of circle given 2 segments and Radius OR tangency point
DROP FUNCTION IF EXISTS rc_py_compute_circle_from_tangency ( f float[2], e float[2],g float[2],t1 FLOAT[2]);
CREATE OR REPLACE FUNCTION rc_py_compute_circle_from_tangency ( f float[2],e float[2],g float[2],t1 FLOAT[2] 
, OUT center FLOAT[2],OUT  radius FLOAT,OUT  t1 FLOAT[2],OUT  t2 FLOAT[2])  
AS $$
	###
	#this function assume that there is 2 input segments with a common point being e (seg fe and eg), along with th point where the circle is tangent that is t1

	
	#importing the numpy package
	import numpy as np;
	#storing the point coordinates as vector to allow fast operations on it.
	_f = np.asarray( f ) ;
	_e = np.asarray( e ) ;
	_g = np.asarray( g ) ;
	_t1 = np.asarray( t1 ) ;

	_ef = _f-_e;
	_eg = _g-_e;
	
	#@DEBUG finding the radius : = r = tan(theta) * dist(ET1), where theta is half of the angle beteen both segment
	##note that it is not necessary to explicit theta, we only need cos(theta), but we compute it for debug
	theta = np.arccos( np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) )/2 ;

	#computing the radius of the circle
	radius = np.tan(theta)*np.linalg.norm(_t1-_e) ;
	#plpy.notice(radius) ; 
	#plpy.notice(theta) ; 
	
	#computing the position of the center
	# E + ( EF + EG )/(norm(EF+EG)) * norm(ET1)/cos(theta)
	center = _e + (_ef+_eg) / (np.linalg.norm(_ef+_eg) ) * np.linalg.norm(_t1-_e) / (np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) );
	#plpy.notice(center) ;  
	
	t2_g = _e + ((_eg)/np.linalg.norm(_eg)) * np.linalg.norm(_t1-_e) ;
	t2_f = _e + ((_ef)/np.linalg.norm(_ef)) * np.linalg.norm(_t1-_e) ;

	if np.linalg.norm(t2_g - t1) < np.linalg.norm(t2_f - _t1) :
		t2 = t2_f  ;
	else :
		t2 = t2_g  ;

	_t1 ;
	#end if on side of t1

	
	plpy.notice(t2) ; 
	return  [center  , radius  , _t1  , t2]   ;
	#return { "center": center, "radius": radius ,  "t1": t1, "t2":t2}
	
$$ LANGUAGE plpythonu;

SELECT *
FROM rc_py_compute_circle_from_tangency(
		ARRAY[13,3]
		,ARRAY[0,0]
		,ARRAY[14,-4]
		,ARRAY[6,-2]
		)  ;





DROP FUNCTION IF EXISTS rc_py_compute_circle_from_radius ( f float[2], e float[2],g float[2],r FLOAT );
CREATE OR REPLACE FUNCTION rc_py_compute_circle_from_radius ( f float[2],e float[2],g float[2],r FLOAT  
, OUT center FLOAT[2],OUT  radius FLOAT,OUT  t1 FLOAT[2],OUT  t2 FLOAT[2])  
AS $$
	###
	#this function assume that there is 2 input segments with a common point being e (seg fe and eg), along with radius of the circle that is tangent ot both seg

	
	#importing the numpy package
	import numpy as np;
	#storing the point coordinates as vector to allow fast operations on it.
	_f = np.asarray( f ) ;
	_e = np.asarray( e ) ;
	_g = np.asarray( g ) ;
	radius = r;

	_ef = _f-_e;
	_eg = _g-_e;
	
	#@DEBUG finding the radius : = r = tan(theta) * dist(ET1), where theta is half of the angle beteen both segment
	##note that it is not necessary to explicit theta, we only need cos(theta), but we compute it for debug
	theta = np.arccos( np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) )/2 ;

	#computing the point T1, on EF
	_t1 = _e + (_ef / np.linalg.norm(_ef) )* radius / np.tan(theta) ; 
	#plpy.notice(radius) ; 
	#plpy.notice(theta) ; 
	
	#computing the position of the center
	# E + ( EF + EG )/(norm(EF+EG)) * norm(ET1)/cos(theta)
	center = _e + (_ef+_eg) / (np.linalg.norm(_ef+_eg) ) * np.linalg.norm(_t1-_e) / (np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) );
	#plpy.notice(center) ;  
	
	t2  = _e + ((_eg)/np.linalg.norm(_eg)) * np.linalg.norm(_t1-_e) ;
	t1 = _t1 ;
	plpy.notice(t2) ; 
	return  [center  , radius  , t1  , t2]   ;
	return { "center": center, "radius": radius ,  "t1": t1, "t2":t2}
	
$$ LANGUAGE plpythonu;

SELECT *
FROM rc_py_compute_circle_from_radius(
		ARRAY[13,3]
		,ARRAY[0,0]
		,ARRAY[14,-4]
		,1.63
		)  ;


		
/*
DROP FUNCTION IF EXISTS rc_py_distance_point_line ( a float[2], b float[2],p float[2] );
CREATE OR REPLACE FUNCTION rc_py_distance_point_line ( a float[2], b float[2],p float[2])
  RETURNS  FLOAT  --TABLE (center FLOAT[2], radius FLOAT 
AS $$
	###
	#this function assume that a and b are the coordinate of 2 endpoint of a segment, and p is a point . It returns the minimal euclidian distance from point to line passong by 2 endpoints of segment 
	
	#importing the numpy package
	import numpy as np;
	#storing the point coordinates as vector to allow fast operations on it.
	_a= np.asarray( a ) ;
	_b = np.asarray( b ) ;
	_p = np.asarray( p ) ; 
	n = (_b-_a)/np.linalg.norm(_b-_a);
 
	#the formula compute distance from point to line, not point to segment. 
	distance = np.linalg.norm( _a-_p - n *np.dot( _a-_p,n ) ) ; 
	return distance ; 
$$ LANGUAGE plpythonu;

SELECT rc_py_distance_point_line( ARRAY[0 ,0] , ARRAY[10,0] ,  ARRAY[-10,-10] );
*/