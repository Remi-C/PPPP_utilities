# -*- coding: utf-8 -*-
"""
Created on Fri May 23 14:15:24 2014

@author: remi
"""


####################################
# Header for outside testing :
    #checking if the code is executed from within the server or not
from os import environ as env;
in_server = "PG_GRANDPARENT_PID" in env;    
if in_server != True : #emulating server input
    f = '01010000000000000000002A400000000000000840';
    e = '010100000000000000000000000000000000000000';   
    g = '01010000000000000000002C4000000000000010C0';   
    t1 = '0101000000000000000000184000000000000000C0';   



####################################



#
# --------------------- python function to compute the _center of circle given 2 segments and _radius OR tangency point
#DROP FUNCTION IF EXISTS rc_py_compute_circle_from_tangency ( f float[2], e float[2],g float[2],t1 FLOAT[2]);
#CREATE OR REPLACE FUNCTION rc_py_compute_circle_from_tangency ( f float[2],e float[2],g float[2],t1 FLOAT[2] 
#, OUT _center FLOAT[2],OUT  _radius FLOAT,OUT  t1 FLOAT[2],OUT  t2 FLOAT[2])  
#AS $$
	###
	#this function assume that there is 2 input segments with a common point 
     #being e (seg fe and eg), along with th point where the circle is tangent that is t1

	#importing the numpy package
import numpy as np;
    #importing shapely to read/write to from geom
from shapely import wkb ; 
from shapely.geometry import asPoint ;

	#storing the point coordinates as vector to allow fast operations on it.
_f = np.asarray( wkb.loads( f, hex= not in_server ) )  ;
_e = np.asarray( wkb.loads( e, hex= not in_server ) )  ;
_g = np.asarray( wkb.loads( g, hex= not in_server ) )  ;
_t1 = np.asarray( wkb.loads( t1, hex= not in_server ) )  ;

_ef = _f-_e;
_eg = _g-_e;
	
	#@DEBUG finding the _radius : = r = tan(theta) * dist(ET1), where theta is half of the angle beteen both segment
	##note that it is not necessary to explicit theta, we only need cos(theta), but we compute it for debug
theta = np.arccos( np.dot(_ef,_eg)/(np.linalg.norm(_ef)*np.linalg.norm(_eg)) )/2 ;

	#computing the _radius of the circle
_radius = np.tan(theta)*np.linalg.norm(_t1-_e) ;
	#plpy.notice(_radius) ; 
	#plpy.notice(theta) ; 
	
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
t1 = _t1 ;
t2 = wkb.dumps(asPoint(t2__), hex=in_server) ;
    
    
#plpy.notice(t2) ; 
if in_server != True :  
	print( center  , radius  , t1  , t2)
else :
	return [center,radius, t1,t2 ];
	#return { "_center": _center, "_radius": _radius ,  "t1": t1, "t2":t2}
	#return { "_center": _center, "_radius": _radius ,  "t1": t1, "t2":t2}
	
     #$$ LANGUAGE plpythonu;

