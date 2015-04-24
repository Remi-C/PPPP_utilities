


--a plpython predicting gt_class, cross_validation , result per class
--gids,feature_iar,gt_classes ,labels,class_list,k_folds,random_forest_ntree, plot_directory
DROP FUNCTION IF EXISTS rc_py_cluster_points( igid int[], dat FLOAT[] ,ncluster int, max_iter INT );
CREATE FUNCTION rc_py_cluster_points( igid int[],dat FLOAT[] ,ncluster int, max_iter INT DEFAULT 300)
RETURNS table(gid int, label int)
AS $$"""
This function plot the histogram at the given path
"""
import numpy as np
from scipy import cluster
from sklearn import cluster
data_iar = np.array( dat, dtype=np.float)
gids = np.array( igid, dtype=np.int32)
vector_points = np.reshape( data_iar,( len(data_iar)/2,2 )) ; 

#centroid, label = cluster.vq.kmeans2(vector_points, ncluster, iter=10000, thresh=0, minit='random', missing='warn')
kmean = cluster.KMeans(n_clusters=ncluster, init='k-means++', n_init=10, max_iter=max_iter, tol=0.0001, precompute_distances='auto', verbose=0, random_state=None, copy_x=True, n_jobs=1)
label = kmean.fit_predict(vector_points)
result = [] 
for i in range(0,len(label)):
    result.append(( (gids[i]) , (label[i]) )) ; 
return result;
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 


