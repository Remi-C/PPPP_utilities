
DROP FUNCTION IF EXISTS rc_rotate_point_given_2_vectors_py (vect1 geometry, vect2 geometry, point geometry );
CREATE OR REPLACE FUNCTION rc_rotate_point_given_2_vectors_py (vect1 geometry, vect2 geometry, point geometry)
RETURNS float[]
AS $$ 
from numpy import linalg as LA
from math import pi,cos,sin,acos 
import numpy as np;

#importing the shapely package to perform geometry manipulation
from shapely import wkb ; #loading geometry from postgres
from shapely.geometry import asMultiPoint #to cast point to numpy array
from shapely.geometry import asPolygon #to cast array to polygon  

##importing the geom
#importing the geometry #NOTE : if outside postgres, hex = True, If inside postgres, Hex = False
geom1 = wkb.loads( vect1, hex=True) ;
v1 = np.asarray(geom1) ;#putting the geom into an array
geom2 = wkb.loads( vect2, hex=True ) ;
v2 = np.asarray(geom2) ;#putting the geom into an array
geom3 = wkb.loads( point, hex=True ) ;
pt = np.asarray(geom3) ;#putting the geom into an array


def rotate(v,angle=0,ref=np.array([0,0,1]),deg=False):
    '''Rotates a vector a given angle respect the 
        given reference. Option: deg=False (default)'''
    if(abs(angle) < 1e-5):
        return v
    if(deg):
        angle = angle*pi/180
    # Define rotation reference system
    ref = versor(ref) # rotation axis
    # n1 & n2 are perpendicular to ref, and to themselves 
    n1 = versor(np.cross(ref,np.array([-ref[1],ref[2],ref[0]])))
    n2 = np.cross(ref,n1)
    vp = np.inner(v,ref)*ref # parallel to ref vector
    vn = v-vp # perpendicular to ref vector
    vn_abs = LA.norm(vn)
    if(vn_abs < 1e-5):
        return v
    alp = acos(np.inner(vn,n1)/vn_abs) # angle between vn & n1
    if(triprod(ref,n1,vn) < 0):
        alp = -alp # correct if necesary
    return vp+vn_abs*(n1*cos(alp+angle)+n2*sin(alp+angle))

def triprod(a,b,c):
    '''Triple product of vectors: a·(b x c)'''
    return np.inner(a,np.cross(b,c))

def versor(v):
    '''Unitary vector in the direction of the one given as input'''
    v = np.array(v)
    return v/LA.norm(v)

###### Test ################################################

a = v1
b = v2 
c = pt
r = acos(np.inner(a,b)/(LA.norm(a)*LA.norm(b)))
ref = versor(np.cross(a,b))
pt_rotated = rotate(c,angle=r,ref=ref)
#plpy.notice( rotate(c,angle=r,ref=ref) )
#plpy.notice(r)
return pt_rotated; 
$$ LANGUAGE plpythonu;



DROP FUNCTION IF EXISTS rc_rotate_point_given_2_vectors(vect1 geometry, vect2 geometry, point geometry );
CREATE OR REPLACE FUNCTION rc_rotate_point_given_2_vectors (vect1 geometry, vect2 geometry, point geometry, OUT rotated_point geometry)
AS $$ 
DECLARE
BEGIN 
SELECT ST_SetSRID(ST_MAkePoint(r[1],r[2],r[3]),ST_SRID(point)) INTO rotated_point
FROM  rc_rotate_point_given_2_vectors_py (
vect1
,vect2
, point
) AS r ; 
RETURN ;
END 
$$ LANGUAGE plpgsql IMMUTABLE STRICT;


SELECT ST_aSText(rc_rotate_point_given_2_vectors (
	ST_MakePoint( 1,1,1)
	,ST_MakePoint(0,0,1)
	, ST_MakePoint(0.2,0.2,0.2)
	)) 