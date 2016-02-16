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
