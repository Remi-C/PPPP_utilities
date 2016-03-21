/***************************************
* Remi Curan Thales IGN, 2016
* function to perform weighted median, with plpython
* DEPENDS ON python 'weightedstats'
*******************************************/


DROP FUNCTION IF EXISTS rc_py_weighted_median( val FLOAT[] , weight FLOAT[] );
CREATE FUNCTION rc_py_weighted_median( val FLOAT[] , weight FLOAT[], OUT weighted_median FLOAT)
AS $$"""
This function take a list of values and wieght, are return the weighted median
require weightedstats
""" 
import numpy as np
import weightedstats as ws
val_ = np.array( val, dtype=np.float)
weight_ = np.array( weight, dtype=np.float) 
weighted_median = ws.numpy_weighted_median(val_, weights=weight_)
return weighted_median
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 

/*
	WITH idata AS (
		SELECT s,  round(random()::numeric,2) as rand
		FROM generate_series(1,10) AS s
	)
	, weighted_median AS (
		SELECT rc_py_weighted_median(array_agg(s  order by s), array_agg(rand  order by s)) as w_med
		FROm idata
	)
	SELECT s, round(rand/ (SELECT sum(rand) FROM idata),2)  AS n_rand, w_med
	FROM idata, weighted_median ; 
*/