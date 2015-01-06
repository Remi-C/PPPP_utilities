-------- C Rémi-C
--12/2014
--plot histogramm using python



	--a plpython predicting gt_class, cross_validation , result per class 
	--gids,feature_iar,gt_classes    ,labels,class_list,k_folds,random_forest_ntree, plot_directory
DROP FUNCTION IF EXISTS rc_py_plot_hist(  dat  FLOAT[]  , file_name_with_path text, labels TEXT[],nbins int);
CREATE FUNCTION rc_py_plot_hist( dat FLOAT[] ,  file_name_with_path text,  labels TEXT[],nbins int DEFAULT 10)
RETURNS boolean 
AS $$"""
This function plot the histogram at the given path
"""  
plpy.notice(dat)
plpy.notice(file_name_with_path) 
import matplotlib 
matplotlib.use('Agg') 
import pylab as P;
import numpy as np

data_iar = np.array( dat, dtype=np.float)
data = np.reshape( data_iar,( len(data_iar)/len(labels),len(labels) )) ; 

fig = P.figure()
# create a new data-set
x = data 

n, bins, patches = P.hist(x, bins = nbins , normed=1, histtype='bar',
                           # color=['Blue', 'Green', 'Red'],
                            label=labels )

P.legend()

save  = P.savefig(file_name_with_path) ;  
P.clf()
P.cla()
P.close() 

return True ;
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 



WITH i_data AS (
	SELECT array_agg_custom(ARRAY[s*4,s*4+1,s*4+2,s*4+3] ) as dat
	FROM generate_series(0,99) AS s
 )
 SELECT r.*
 FROM i_data  
	,rc_py_plot_hist(
		dat
		,'/media/sf_E_RemiCura/PROJETS/point_cloud/PC_in_DB/LOD_ordering_for_patches_of_points/result_rforest/vosges/tmp/test_hist.png'
		,ARRAY['dim1','dim2','dim3','dim4']
		,30) as r 


 DROP FUNCTION IF EXISTS rc_py_plot_2_hist(  dat1  FLOAT[]  , dat2  FLOAT[]  ,file_name_with_path text, labels TEXT[],nbins int, use_log_y boolean );
CREATE FUNCTION rc_py_plot_2_hist( dat1 FLOAT[] ,dat2  FLOAT[]  ,  file_name_with_path text,  labels TEXT[],nbins int DEFAULT 10, use_log_y boolean DEFAULT FALSE)
RETURNS boolean 
AS $$"""
This function plot the histogram at the given path
"""    
import matplotlib 
matplotlib.use('Agg') 
import pylab as P;
import numpy as np

data_iar1 = np.array( dat1, dtype=np.float)
data1 = np.reshape( data_iar1,( len(data_iar1) ,1)) ; 
data_iar2 = np.array( dat2, dtype=np.float)
data2 = np.reshape( data_iar2,( len(data_iar2) ,1)) ; 
fig = P.figure()
# create a new data-set
x1,x2 = data1,data2

n, bins, patches = P.hist([x1,x2], bins=nbins, normed=False, histtype='bar',  
                            label=labels, log=use_log_y 
                            , color=['Blue', 'Red'],
                            )

P.legend()

save  = P.savefig(file_name_with_path) ;  
P.clf()
P.cla()
P.close() 

return True ;
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 




WITH i_data AS (
	SELECT array_agg (s ) as dat1, array_agg(s*2) AS dat2
	FROM generate_series(0,99) AS s
 )
 SELECT r.*
 FROM i_data  
	,rc_py_plot_2_hist(
		dat1,dat2
		,'/media/sf_E_RemiCura/PROJETS/point_cloud/PC_in_DB/LOD_ordering_for_patches_of_points/result_rforest/vosges/tmp/test_hist.png'
		,ARRAY['dim1','dim2' ]
		,30) as r 

		