--------------------------
-- Remi CUra, thales IGN 2016
--
-- octree occupancy through python module (wrapper)
--------------------------


DROP FUNCTION IF EXISTS rc_multipoints_to_ppl (geometry, int );
CREATE OR REPLACE FUNCTION rc_lib.rc_multipoints_to_ppl (ipoints geometry , tot_level int,OUT ppl int[])
AS $$ 
import numpy as np 
import rc_ppl_octree as rcppl 
#converting points to appropriate numpy array

#importing the shapely package to perform geometry manipulation
from shapely import wkb ; #loading geometry from postgres  
#importing the geometry 
points = np.asarray(wkb.loads( ipoints, hex=True) )    
#using external module
ppl = rcppl.pointcloud_to_ppl(points,tot_level)

return (ppl.tolist()) 
$$ LANGUAGE plpythonu;


DROP FUNCTION IF EXISTS rc_xyz_array_to_ppl (float[] , int );
CREATE OR REPLACE FUNCTION rc_xyz_array_to_ppl (coordinates float[] , tot_level int,OUT ppl int[])
AS $$
""" expects an array of X1 Y1, Z1, X2, Y2, Z2, X3 ..."""
import numpy as np 
import rc_ppl_octree as rcppl 
#converting points to appropriate numpy array
points = np.asarray(coordinates).reshape([-1,3]) 
 
#using external module
ppl = rcppl.pointcloud_to_ppl(points,tot_level)

return (ppl.tolist()) 
$$ LANGUAGE plpythonu;

/*
SELECT f.*
FROM CAST(8 AS int) AS tot_level
	, ST_GeomFromText('MULTIPOINTZ( 0 0 1, 1 0 0 , 2 0 0 , 0 1 0, 1 1 0 , 2 1 0  ,0 2 0, 1 2 0 , 2 2 1  )') AS ipoints
	,  rc_lib.rc_multipoints_to_XYZ_array(ipoints, rounding_digits:=3) as arr_coordinates
	,rc_lib.rc_xyz_array_to_ppl(arr_coordinates, tot_level) as f ;
*/

DROP FUNCTION IF EXISTS rc_patch_to_ppl (pcpatch, int );
CREATE OR REPLACE FUNCTION rc_patch_to_ppl (ipatch pcpatch , tot_level int,OUT ppl int[])
AS $$ 
import numpy as np 
import rc_ppl_octree as rcppl   
import pg_pointcloud_classes as pgp

#convert patch to numpy array 
GD = pgp.create_GD_if_not_exists()
#cache mecanism for patch schema
if 'rc' not in GD:  # creating the rc dict if necessary
	GD['rc'] = dict()
	if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
		GD['rc']['schemas'] = dict() 

restrict_dim = ["x","y","z"]
#converting patch to appropriate numpy array
points_double, mschema = pgp.WKB_patch_to_numpy_double(ipatch, GD['rc']['schemas'], None, dim_to_use=restrict_dim)
   
#using external module
ppl = rcppl.pointcloud_to_ppl(points_double,tot_level)

return (ppl.tolist()) 
$$ LANGUAGE plpythonu;

/*
SELECT  f.*
 FROM lod.bench_small_cubes ,  rc_patch_to_ppl( pc_uncompress(patch), 8) AS f 
 WHERE gid = 7359;  
 */