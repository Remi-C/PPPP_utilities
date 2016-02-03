
SET search_path to lod, acquisition_tmob_012013, rc_lib, public; 


------------------------ creating a proxy table for old acquisition
/*
DROP TABLE IF EXISTS acquisition_tmob_012013.riegl_pcpatch_space_proxy ; 
CREATE TABLE acquisition_tmob_012013.riegl_pcpatch_space_proxy
(
  gid int  PRIMARY KEY REFERENCES acquisition_tmob_012013.riegl_pcpatch_space_proxy(gid),
  file_name text, 
  num_points int, 
  points_per_level integer[], 
  avg_time  numrange,  
  geom geometry(polygon,932011),
   patch pcpatch(4), 
   patch_ordered pcpatch(4)
) ;
TRUNCATE riegl_pcpatch_space_proxy ; 
INSERT INTO riegl_pcpatch_space_proxy
SELECT gid, file_name, pc_numpoints(patch), points_per_level
	,   numrange(pc_patchmin(patch,'gps_time'),pc_patchmax(patch,'gps_time'))
	,patch::geometry(polygon,932011)
	,patch
	, NULL
FROM ST_SetSRID(ST_MakePoint(1902.8,21232.0),932011) as ref_point, riegl_pcpatch_space as pa
WHERE -- ST_DWIthin(ref_point, pa.patch::geometry,110) AND
	 acquisition_tmob_012013.rc_compute_range_for_a_patch(patch, 'gps_time'::text) 
		&& numrange( 54325.2523459474, 54374.6008751621);

CREATE INDEX ON riegl_pcpatch_space_proxy (file_name);
CREATE INDEX ON riegl_pcpatch_space_proxy (num_points);
CREATE INDEX ON riegl_pcpatch_space_proxy USING GIN (points_per_level);
CREATE INDEX ON riegl_pcpatch_space_proxy USING GIST(avg_time);
CREATE INDEX ON riegl_pcpatch_space_proxy USING GIST(geom);
*/
------------------------  
  

DROP FUNCTION IF EXISTS rc_py_Cov_to_proba_dim( uncompressed_patch PCPATCH );
CREATE OR REPLACE FUNCTION rc_py_Cov_to_proba_dim(uncompressed_patch PCPATCH , OUT cov_desc float[], OUT cov_desc_i float)
  AS  
$BODY$
""" this function takes an uncompressed patch and compute the probability of dimension based on the cov matrix""" 
import dimensionality_feature as dim  
import numpy as np
descriptors  = dim.compute_dim_descriptor_from_patch(uncompressed_patch,None) 
descriptors = np.round( descriptors, 3) 
cov_desc_i = dim.proba_to_dim_power(descriptors) 
return [descriptors, cov_desc_i]
$BODY$
LANGUAGE plpythonu STABLE STRICT; 

DROP FUNCTION IF EXISTS rc_py_ppl_to_proba_dim( points_per_level int[], num_points int);
CREATE OR REPLACE FUNCTION rc_py_ppl_to_proba_dim( points_per_level int[], num_points int
	, OUT theoretical_i float,OUT multiscale_dim float[],OUT multiscale_dim_var float[],OUT multiscale_fused float )  AS
$BODY$
""" this function takes an uncompressed patch and compute the probability of dimension based on way its increase over level"""  

import dimensionality_feature as dim 
#reload(dim)
import numpy as np
multiscale_dim, multiscale_dim_var, multiscale_fused, theoretical_dim = dim.compute_rough_descriptor(np.asarray(points_per_level),num_points)
theoretical_dim = np.round(theoretical_dim,3)
multiscale_dim = np.round(multiscale_dim,3)
multiscale_dim_var = np.round(multiscale_dim_var,3)
multiscale_fused = np.round(multiscale_fused,3)   
return  [theoretical_dim,multiscale_dim, multiscale_dim_var,multiscale_fused] 
$BODY$
LANGUAGE plpythonu STABLE STRICT; 


SELECT gid, points_per_level 
	, f1.*
	, f2.*
FROM riegl_pcpatch_space_proxy , rc_py_Cov_to_proba_dim(pc_uncompress(patch) ) AS f1
	 , rc_py_ppl_to_proba_dim( points_per_level[1:7]  , num_points ) AS f2
WHERE gid BETWEEN 906843 AND 906844 ; 


DROP TABLE IF EXISTS dim_descr_comparison ; 
CREATE TABLE dim_descr_comparison (
	gid int primary key references riegl_pcpatch_space_proxy(gid)
	, points_per_level int[] --copy from original data, computed with midoc
	, points_per_level_py int[] --recomputed with pythn
	, cov_desc float[] -- diim descriptor computed on full points using cov matrix
	, cov_to_i float -- this dim descriptor converted to a dim indice
	, theoretical_i float -- using ransac to best fit a linear function to log2(ppl), this is the coef of the line, aka the dim indice
	, th_confidence float -- witht previous result, ransac gives a kind of confidence
	, multiscale_dim float[] -- for each level, the dim i, computed only with log2(ppl[i])/i
	, multiscale_dim_var float[] -- for each level, the dim i, computed by log2(ppl[i]/ppl[i-1])
	, multiscale_fused float   -- for each scale, the max dim from dim and dim_var
) ;
CREATE INDEX ON dim_descr_comparison USING GIN(points_per_level);
CREATE INDEX ON dim_descr_comparison USING GIN(cov_desc);
CREATE INDEX ON dim_descr_comparison (cov_to_i) ;
CREATE INDEX ON dim_descr_comparison (theoretical_i) ;
CREATE INDEX ON dim_descr_comparison USING GIN(multiscale_dim);
CREATE INDEX ON dim_descr_comparison USING GIN(multiscale_dim_var);
CREATE INDEX ON dim_descr_comparison  (multiscale_fused); 

TRUNCATE dim_descr_comparison;  
	 INSERT INTO dim_descr_comparison
	SELECT gid, points_per_level 
		--, f1.*
		, NULL, NULL
		, NULL, NULL, NULL, NULL
		--, f2.*
	FROM riegl_pcpatch_space_proxy 
		--, rc_py_Cov_to_proba_dim(pc_uncompress(patch) ) AS f1
		--, rc_py_ppl_to_proba_dim( points_per_level[1:7]  , num_points ) AS f2
	WHERE --gid BETWEEN 906843 AND 906943 AND
	  points_per_level IS NOT NULL; 

SELECT f.points_per_level
FROM riegl_pcpatch_space, 
	lod.rc_order_octree(
	    patch,5 ) AS f
   WHERE gid = 908193

   UPDATE riegl_pcpatch_space_proxy  SET points_per_level = ARRAY[1, 2, 4, 8, 16, 63, 83, 23]
   WHERE gid = 908193

SELECT --corr(
	COALESCE( points_per_level[2],NULL), COALESCE(points_per_level_py[2],NULL)
	--) 
FROM dim_descr_comparison


SELECT gid, points_per_level, points_per_level_py, cov_to_i, theoretical_i, multiscale_fused, th_confidence
FROM dim_descr_comparison
WHERE points_per_level_py[6]=0

WHERE gid = 908196

WITH the_data AS (
	SELECT  dd.* , rp.num_points
	FROM dim_descr_comparison AS dd
		LEFT OUTER JOIN  riegl_pcpatch_space_proxy AS rp USING(gid)
	WHERE abs(cov_to_i-theoretical_i) < 0.5
)
, sub1 AS (
	SELECT sum(num_points) AS filtered_points
	FROM the_data 
)
 , sub2 AS (
	SELECT sum(num_points) AS total_points
	FROM dim_descr_comparison 
		LEFT OUTER JOIN  riegl_pcpatch_space_proxy AS rp USING(gid) 
) 
SELECT  corr(cov_to_i,theoretical_i) ,  corr(cov_to_i,multiscale_fused) -- multiscale_fused 
	, (SELECT count(*) FROM the_data) /(SELECT count(*) FROM dim_descr_comparison)::float as c
	  ,  min(filtered_points)/min(total_points)::float 
FROM the_data 
	,    sub1
	, sub2 ; 

--0.27419214238594;0.793817533095223;0.931160863676201;0.964468338156149
--0.323377626988885;0.788861112764582;0.929009640666082;0.954213338567443


-------------
-- exporting the point cloud with computed data

COPY ( 
	SELECT ST_X(pt) AS x, ST_Y(pt) AS y, ST_Z(pt) AS z
		, gid, cov_desc[1] AS one_D, cov_desc[2] AS two_D, cov_desc[3] AS three_D, cov_to_i, theoretical_i, multiscale_fused
		, th_confidence
	FROM dim_descr_comparison
		LEFT OUTER JOIN riegl_pcpatch_space AS rps USING(gid)
		, pc_explode (patch) as point
		, CAST(point AS geometry) AS pt 
	 WHERE abs(theoretical_i-cov_to_i) > 0.5
)
TO '/ExportPointCloud/points_with_dim_descriptors_only_faulty.csv' WITH CSV HEADER DELIMITER AS ',' ;
	

COPY (
	WITH ra AS (SELECT one_D,  two_D,  three_D, theoretical_dim 
		,  CASE WHEN theoretical_dim  < 1 THEN ARRAY[1-theoretical_dim,theoretical_dim,0]
			WHEN theoretical_dim  >=1 AND theoretical_dim  <2 THEN ARRAY[2- theoretical_dim , theoretical_dim  -1,0]
			WHEN theoretical_dim  >=2 AND theoretical_dim  <3 THEN ARRAY[0, 3- theoretical_dim , theoretical_dim  -2]
			END AS th_t_r  
	FROM dim_descr_comparison
	WHERE points_per_level is NOT null
	)
	SELECT  one_D,  two_D,  three_D, theoretical_dim , 
		th_t_r[1] th_1 ,th_t_r[2] th_2,th_t_r[3] th_3
	FROM ra
)
TO '/ExportPointCloud/dim_descriptors.csv' WITH CSV HEADER DELIMITER AS ',' ;

COPY (
	WITH ra AS (SELECT one_d_rough ,  two_D_rough ,  three_D_rough ,  theoretical_dim
		,  CASE WHEN theoretical_dim  < 1 THEN ARRAY[1-theoretical_dim,theoretical_dim,0]
		WHEN theoretical_dim  >=1 AND theoretical_dim  <2 THEN ARRAY[2- theoretical_dim , theoretical_dim  -1,0]
		WHEN theoretical_dim  >=2 AND theoretical_dim  <3 THEN ARRAY[0, 3- theoretical_dim , theoretical_dim  -2]
		END AS th_t_r  
	FROM dim_descr_comparison  
	WHERE points_per_level is NOT null
	)
	SELECT one_d_rough ,  two_D_rough ,  three_D_rough ,  theoretical_dim, 
		th_t_r[1],th_t_r[2],th_t_r[3]
	FROM ra
)
TO '/ExportPointCloud/dim_descriptors_rough.csv' WITH CSV HEADER DELIMITER AS ',' ;

COPY (
	SELECT one_d_rough AS x,  two_D_rough AS y,  three_D_rough AS Z,  theoretical_dim
		
	FROM dim_descr_comparison
	WHERE points_per_level is NOT null
)
TO '/ExportPointCloud/dim_descriptors_rough.csv' WITH CSV HEADER DELIMITER AS ',' ;