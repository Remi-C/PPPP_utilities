# -*- coding: utf-8 -*-
"""
Created on Thu May 22 15:57:10 2014
shapely
@author: remi
"""
 

###emulation of postgres input
igeom = '0102000000020000000000000000000000000000000000000000000000000024400000000000000000';
r1 = 1 ;
r2 = 2 ;
	###
	#this function assume that the input geom is a segment

##import of packages
#importing the numpy package to be able ot perform vector operation
import numpy as np; 

#importing the shapely package to perform geometry manipulation
from shapely import wkb ; #loading geometry from postgres
from shapely.geometry import asMultiPoint #to cast point to numpy array
from shapely.geometry import asPolygon #to cast array to polygon
#pretty print :
import pprint as pp;
pp1 = pp.PrettyPrinter(indent=4,depth=6,width=50) ;
  
##importing the geom

#importing the geometry #NOTE : if outside postgres, hex = True, If inside postgres, Hex = False
geom = wkb.loads( igeom, hex=True ) ;

p = np.asarray(geom) ;#putting the geom into an array



 #compute normal orientation of the segment
normal =  (p[1]-p[0]) * np.array([ 1,-1] ) ; 
normal[0], normal[1], = normal[1],normal[0] ; #exchanging x and y, wihtout copy
normal = normal/np.linalg.norm(normal) ;
print(normal) ;
 
 #creating the upper point and down point for first and second (hopefully last) point in segment
p1u = p[0] + normal * r1 ;
p1d = p[0] - normal * r1 ;

p2u = p[1] + normal * r2 ;
p2d = p[1] - normal * r2 ;
 
output_line = (p1u,p2u,p2d,p1d,p1u) ;
 
ogeom = asPolygon(output_line) ;
 

print(ogeom) ; 
pp1.pprint( str(geom)); 

#outputing for postgis : @NOTE : if inside postgres, hex =False, if outside, hex=True
output = wkb.dumps(ogeom, hex=True);

print(output) ;
 
# ##emulation of postgres output
# #return   None   ;
# 	#return { "center": center, "radius": radius ,  "t1": t1, "t2":t2}
#==============================================================================
	
 

