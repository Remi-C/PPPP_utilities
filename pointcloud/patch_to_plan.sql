



	--a plpython function taking the array of double precision and converting it to pointcloud, then looking for planes inside, then cylinder
	--note that we could do the same to detect cylinder
DROP FUNCTION IF EXISTS rc_py_plane_and_cylinder_detection_from_patch ( pcpatch,  INT,INT, FLOAT, INT ,FLOAT,FLOAT,INT);
CREATE FUNCTION rc_py_plane_and_cylinder_detection_from_patch (
	uncompressed_pcpatch pcpatch
	,plane_min_support_points INT DEFAULT 4
	,plane_max_number INT DEFAULT 100
	,plane_distance_threshold FLOAT DEFAULT 0.1
	,plane_ksearch INT DEFAULT 50
	,plane_search_radius FLOAT DEFAULT 0.1
	,plane_distance_weight FLOAT DEFAULT 0.5 --between 0 and 1 . 
	,plane_max_iterations INT DEFAULT 100 
)
RETURNS TABLE( support_point_index int[] , model FLOAT[], model_type INT)   
AS $$
"""
this function demonstrate how to convert input float[] into a numpy array
then importing it into a pointcloud (pcl)
then iteratively finding plan in the cloud using ransac
	find a plan and points in it. 
	remove thoses points from the cloud
	keep their number
	iterate
	note :about index_array. the problem is each time we perform segmentation we get indices of points in plane. The problem is when the cloud has changed, this indices in the indices  of points in the new cloud and not indices of points in the original cloud. 
	We use therefore index_array to keep the information of orginal position in original cloud. We change it along to adapt to removal of points.
"""
#importing neede modules
import numpy as np
import pcl 
import sys
#reload(pcl)
sys.path.insert(1, '/media/big2to/PPPP_utilities/pointcloud') 


import patch_to_plan as ptp
#reload(ptp)
import pg_pointcloud_classes as pgp
#reload(pgp)
connection_string = """host=localhost dbname=test_pointcloud user=postgres password=postgres port=5432"""
if 'rc' not in GD:  # creating the rc dict if necessary
    GD['rc'] = dict()
if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
    GD['rc']['schemas'] = dict()

    
#converting the (uncompressed) patch to numpy point cloud p
p = ptp.patch_to_pcl(uncompressed_pcpatch, GD['rc']['schemas'], connection_string)
#plpy.notice(p)
#finding the plane 
result , p_reduced = ptp.perform_N_ransac_segmentation(
	    p
	    ,plane_min_support_points
	    ,plane_max_number
	    , plane_search_radius
	    , pcl.SACMODEL_PLANE
	    , plane_distance_weight
	    , plane_max_iterations
	    , plane_distance_threshold) ;

#plpy.notice(p_reduced)

return result ; 
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 


/*
WITH pa AS (
	SELECT gid, pc_uncompress(patch) as u_patch , pc_numpoints(patch) --, * 
	FROM benchmark_cassette_2013.riegl_pcpatch_space
	WHERE -- pc_numpoints(patch) BETWEEN 100 AND 110 --1000 AND 5000
		 gid  = 918
		--AND gid = 4523
	LIMIT 1  
	
)
SELECT gid, r.*
FROM pa ,rc_py_plane_and_cylinder_detection_from_patch (
	u_patch
	,plane_min_support_points := 100
	,plane_max_number := 10
	,plane_distance_threshold := 0.1
	,plane_ksearch := 10
	,plane_search_radius := 1
	,plane_distance_weight := 0.5 --between 0 and 1 . 
	,plane_max_iterations := 10000
	) as r
-- 
-- 
-- COPY (
-- 		SELECT pc_uncompress(patch) as u_patch 
-- 	FROM benchmark_cassette_2013.riegl_pcpatch_space
-- 	WHERE gid = 4523
-- )
-- TO '/tmp/test_patch'
*/
