CREATE SCHEMA IF NOT EXISTS lod_low_disc ; 

SET search_path to lod_low_disc, rc_lib, public; 




DROP FUNCTION IF EXISTS rc_generate_Halton_seq (int,int );
CREATE FUNCTION rc_generate_Halton_seq ( 
 nb_of_dim int, nb_of_sample int
	) 
RETURNS  TABLE( ordering int, val FLOAT[]  )   
AS $$
"""
This function returns the Halton seq of given dimensionnality
"""
#importing needed modules
import ghalton

import numpy as np ;
import plpy ;
import networkx as nx;  

sequencer = ghalton.Halton(nb_of_dim) 
points = sequencer.get(nb_of_sample) 
result = list() 
for i  in range(0, nb_of_sample):  
        result.append((i, points[i]))
return result 
  
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 


SELECT *
from rc_generate_Halton_seq(2,20) ; 


