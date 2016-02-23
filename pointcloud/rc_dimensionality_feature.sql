--------------------------
-- Remi CUra, thales IGN 2016
--
-- Dimensionality feature through inbase processing (wrapper for python functions)
--------------------------


DROP FUNCTION IF EXISTS rc_ppl_to_dim_feature (int[], int );
CREATE OR REPLACE FUNCTION rc_ppl_to_dim_feature (IN ppl int[], IN num_points int,out median_dim float,OUT ransac_dim float,OUT ransac_confidence float,OUT dim_lod float[],OUT dim_loddiff float[])
AS $$ 
import numpy as np
import dimensionality_feature as dim 

ppl2 = np.asarray(ppl).astype(np.float64)

multiscale_dim, multiscale_dim_var, multiscale_fused, theoretical_dim, cov = dim.compute_rough_descriptor(ppl2,num_points)
 
median_dim = multiscale_fused
ransac_dim = theoretical_dim
ransac_confidence= cov
dim_lod = np.round(multiscale_dim,3).tolist()
dim_loddiff = np.round(multiscale_dim_var,3).tolist()

return (median_dim,ransac_dim ,ransac_confidence, dim_lod , dim_loddiff) 
$$ LANGUAGE plpythonu;


-- SELECT *
-- FROM rc_ppl_to_dim_feature(ARRAY[1,4,16,62],83) ; 

DROP FUNCTION IF EXISTS rc_patch_to_dim_cov (PCPATCH );
CREATE OR REPLACE FUNCTION rc_patch_to_dim_cov (ipatch PCPATCH, OUT dim_cov FLOAT)
AS $$ 
import numpy as np
import dimensionality_feature as dim 
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

p_dim = dim.compute_descriptors_from_points(points_double)
dim_cov = dim.proba_to_dim_power(p_dim)
 
return (dim_cov) 
$$ LANGUAGE plpythonu;

