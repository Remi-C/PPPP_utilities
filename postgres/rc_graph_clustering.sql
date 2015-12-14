


DROP FUNCTION IF EXISTS rc_graph_clustering ( INT[], INT[] , float[],  int,eps float, min_samples int, preference int);
CREATE FUNCTION rc_graph_clustering (  node1 INT[], node2 INT[] , tcost float[] , n_clusters int,eps float, min_samples int, preference int)  
RETURNS TABLE( seq int, cluster_id INT )   
AS $$
"""
Tis function takes pairs of nodes of a network as input, plus the cost associated to the distance between those nodes. 
one pair is an edge of the graph, the cost is the weight
we use networkx top generate  a sparse connectivity matrix, then skearn to exploit this matrix for clustering
We use spectral clustering or DBSCAN to cluster the graph into subgraph
require networkx
"""
import numpy as np ;
import plpy ;
import networkx as nx;  

import matplotlib 
matplotlib.use('Agg')
import pylab as P;
from matplotlib import cm as cmap
from sklearn.cluster import spectral_clustering
from sklearn.cluster import DBSCAN
from sklearn.cluster import AffinityPropagation


file_name_with_path = '/ExportPointCloud/test.svg'


# converting the 1D array to numpy array
n1 = np.array(node1) ; 
n2 = np.array(node2) ;  
tweight = np.array(tcost) ;  

# creating graph
edge = np.column_stack( (n1,n2,tweight) );
G=nx.Graph() 
G.add_weighted_edges_from(edge)

# optionnaly drawing graph
"""
nx.draw(G,edge_color = [ i[2]['weight'] for i in G.edges(data=True) ], edge_cmap=cmap.get_cmap('ocean') 
, width=2,style ='dashed',font_size=14,font_weight=1000,pos = nx.spectral_layout(G, dim=2, weight='weight', scale=1) ) 
save  = P.savefig(file_name_with_path) ;  
P.clf()
P.cla()
P.close() 
"""



"""
for idx, val in enumerate(cc): 
    for n_val in val:
        result.append((n_val, idx)) ;
"""


#getting a sparse adjacency matrix from graph 
G_sparse_m = nx.to_scipy_sparse_matrix(G)

if n_clusters <2 or n_clusters is None:
	ap = AffinityPropagation(damping=0.5, max_iter=200, convergence_iter=15, copy=False,preference=preference, affinity='precomputed', verbose=False)
	ap.fit(G_sparse_m)
	labels = ap.labels_
	
	#db = DBSCAN(eps=eps, min_samples=min_samples, metric="precomputed")
	#db.fit(G_sparse_m)
	#labels = db.labels_ 
else: 
	#using spectral clustering from sklearn on it
	spec = spectral_clustering(G_sparse_m,  n_clusters=n_clusters, eigen_solver='arpack')	

	#spec.fit(G_sparse_m)
	labels = spec  
	
"""
# import sklearn
# plpy.error(sklearn.__version__) 
"""
# plpy.error(labels)
result = [] 
for i in range(0,len(labels)):
    result.append(( (i) , (labels[i]) ))  
return result;
  
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 


-- SET search_path to patch_connectivity, benchmark_cassette_2013, test_grouping, public ;
	
 
