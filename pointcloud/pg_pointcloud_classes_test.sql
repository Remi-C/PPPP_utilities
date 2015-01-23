





DROP FUNCTION IF EXISTS test_global_dict_python() ; 
CREATE FUNCTION test_global_dict_python()
RETURNS boolean
AS $$
import sys
sys.path.insert(0, '/media/sf_E_RemiCura/PROJETS/PPPP_utilities/pointcloud/') 

# test on pcschema classe
/media/sf_E_RemiCura/PROJETS/PPPP_utilities/pointcloud/pg_pointcloud_classes.py
return True 
$$ LANGUAGE plpythonu;


SELECT test_global_dict_python();
