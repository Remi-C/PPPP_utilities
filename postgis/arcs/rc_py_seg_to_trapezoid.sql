-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--support function : given a segment and 2 floats, compute the trapesoid formed by the perpendicular to the segment passing by 2 end point and of length of the float
--	 tis python function demonstrate how to read and write geometry from postgis to shapely to postgis, and perform some computing using numpy
------------------------------


 --------------------- python function to compute the center of circle given 2 segments and Radius OR tangency point
 
DROP FUNCTION IF EXISTS rc_py_seg_to_trapezoid ( igeom bytea,r1 float ,r2 FLOAT );
CREATE OR REPLACE FUNCTION rc_py_seg_to_trapezoid ( igeom bytea,r1 float,r2 FLOAT
, OUT o_geo geometry )  
AS $$
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
	geom = wkb.loads( igeom, hex=False ) ;

	p = np.asarray(geom) ;#putting the geom into an array



	 #compute normal orientation of the segment
	normal =  (p[1]-p[0]) * np.array([ 1,-1] ) ; 
	normal[0], normal[1], = normal[1],normal[0] ; #exchanging x and y, wihtout copy
	normal = normal/np.linalg.norm(normal) ;
	#print(normal) ;
	 
	 #creating the upper point and down point for first and second (hopefully last) point in segment
	p1u = p[0] + normal * r1 ;
	p1d = p[0] - normal * r1 ;

	p2u = p[1] + normal * r2 ;
	p2d = p[1] - normal * r2 ;
	 
	output_line = (p1u,p2u,p2d,p1d,p1u) ;
	 
	ogeom = asPolygon(output_line) ;
	 

	#print(ogeom) ; 
	pp1.pprint( str(geom)); 

	#outputing for postgis : @NOTE : if inside postgres, hex =False, if outside, hex=True
	output = wkb.dumps(ogeom, hex=True);

	 
	return   output   ;
	#return { "center": center, "radius": radius ,  "t1": t1, "t2":t2} 
$$ LANGUAGE plpythonu;

SELECT * ,  St_Astext(rc_py_seg_to_trapezoid( geom   ,2 ::float,3::float )   )
FROM ST_GeomFromtext('LINESTRING(0 0 , 10 0 )') AS geom;



