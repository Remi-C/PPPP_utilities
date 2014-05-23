-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--support function : given 3 segments sharing an end point, and either a radius or the tangency point, compute the parameter of the circle that is tangent to both segment and
--	passes by tangency point OR has given radius
--	python function to compute the center of circle given 2 segments and Radius OR tangency point 
------------------------------ 


 
DROP FUNCTION IF EXISTS rc_py_compute_circle_from_tangency ( f geometry(point), e geometry(point),g geometry(point),t1 geometry(point));
CREATE OR REPLACE FUNCTION rc_py_compute_circle_from_tangency ( i_f geometry(point), i_e geometry(point), i_g geometry(point), i_t1 geometry(point)
, OUT center geometry(point),OUT  radius FLOAT,OUT  t1 geometry(point), OUT  t2 geometry(point))  
AS $$
in_server = True;
	#importing the numpy package
import numpy as np;
    #importing shapely to read/write to from geom
from shapely import wkb ; 
from shapely.geometry import asPoint ;

	#storing the point coordinates as vector to allow fast operations on it.
_f = np.asarray( wkb.loads( i_f , hex=  in_server ) )  ;
_e = np.asarray( wkb.loads( i_e , hex= in_server ) )  ;
_g = np.asarray( wkb.loads( i_g , hex= in_server ) )  ;
_t1 = np.asarray( wkb.loads( i_t1 , hex= in_server ) )  ;

_ef = _f-_e;
_eg = _g-_e;
	
	#@DEBUG finding the _radius : = r = tan(theta) * dist(ET1), where theta is half of the angle beteen both segment
	##note that it is not necessary to explicit theta, we only need cos(theta), but we compute it for debug
theta = np.arccos( np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) )/2 ;

	#computing the _radius of the circle
_radius = np.tan(theta)*np.linalg.norm(_t1-_e) ;
plpy.notice(_radius) ; 
plpy.notice(theta) ; 
	
	#computing the position of the _center
	# E + ( EF + EG )/(norm(EF+EG)) * norm(ET1)/cos(theta)
_center = _e + (_ef+_eg) / (np.linalg.norm(_ef+_eg) ) * np.linalg.norm(_t1-_e) / (np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) );
	#plpy.notice(_center) ;  
	
t2_g = _e + ((_eg)/np.linalg.norm(_eg)) * np.linalg.norm(_t1-_e) ;
t2_f = _e + ((_ef)/np.linalg.norm(_ef)) * np.linalg.norm(_t1-_e) ;

if np.linalg.norm(t2_g - _t1) < np.linalg.norm(t2_f - _t1) :
	t2__ = t2_f  ;
else :
	t2__ = t2_g  ;

center = wkb.dumps(asPoint(_center), hex=in_server) ;
radius = _radius ;
t1 = i_t1 ;
t2 = wkb.dumps(asPoint(t2__), hex=in_server) ;
    
    
#plpy.notice(t2) ; 
if in_server != True :  
	print( center  , radius  , t1  , t2)
else :
	return [center,radius, t1,t2 ];
	#return { "_center": _center, "_radius": _radius ,  "t1": t1, "t2":t2}
	

$$ LANGUAGE plpythonu;

--testing
SELECT *
FROM rc_py_compute_circle_from_tangency(
		ST_MakePoint(13,3)
		,ST_MakePoint(0,0)
		,ST_MakePoint(14,-4)
		,ST_MakePoint(6,-2)
		)  ; 



DROP FUNCTION IF EXISTS rc_py_compute_circle_from_radius ( f geometry(point), e geometry(point),g geometry(point),r FLOAT );
CREATE OR REPLACE FUNCTION rc_py_compute_circle_from_radius ( i_f geometry(point), i_e geometry(point), i_g geometry(point), i_r FLOAT  
, OUT center geometry(point),OUT  radius FLOAT,OUT  t1 geometry(point),OUT  t2 geometry(point))  
AS $$
	###
	#this function assume that there is 2 input segments with a common point being e (seg fe and eg), along with radius of the circle that is tangent ot both seg
 
in_server = True;
	#importing the numpy package
import numpy as np;
    #importing shapely to read/write to from geom
from shapely import wkb ;
from shapely.geometry import asPoint ;

	#storing the point coordinates as vector to allow fast operations on it.
_f = np.asarray( wkb.loads( i_f , hex=  in_server ) )  ;
_e = np.asarray( wkb.loads( i_e , hex= in_server ) )  ;
_g = np.asarray( wkb.loads( i_g , hex= in_server ) )  ;

_ef = _f-_e;
_eg = _g-_e;

	#@DEBUG finding the radius : = r = tan(theta) * dist(ET1), where theta is half of the angle beteen both segment 
theta = np.arccos( np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) )/2 ;

	#computing the point T1, on EF
_t1 = _e + (_ef / np.linalg.norm(_ef) )* i_r/ np.tan(theta) ; 
	#plpy.notice(radius) ; 
	#plpy.notice(theta) ; 
	
	#computing the position of the center
	# E + ( EF + EG )/(norm(EF+EG)) * norm(ET1)/cos(theta)
_center = _e + (_ef+_eg) / (np.linalg.norm(_ef+_eg) ) * np.linalg.norm(_t1-_e) / (np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) );
	#plpy.notice(center) ;  
	
_t2  = _e + ((_eg)/np.linalg.norm(_eg)) * np.linalg.norm(_t1-_e) ; 
#	plpy.notice(t2) ;


center = wkb.dumps(asPoint(_center), hex=in_server) ;
radius = i_r  ;
t1 = wkb.dumps(asPoint(_t1), hex=in_server) ;
t2 = wkb.dumps(asPoint(_t2), hex=in_server) ;


return  [ center, radius  , t1 , t2 ]   ;	
$$ LANGUAGE plpythonu;

--testing
SELECT *
FROM rc_py_compute_circle_from_radius(
		ST_MakePoint(13,3)
		,ST_MakePoint(0,0)
		,ST_MakePoint(14,-4)
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