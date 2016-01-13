
--SET SEARCH_PATH to rc_lib, public;  


DROP FUNCTION IF EXISTS rc_to_graphML (  int[], float[], INT[], INT[] , float[],  path_to_file text);
CREATE FUNCTION rc_to_graphML ( node int[], node_z float[], node1 INT[], node2 INT[] , tcost float[] ,  path_to_file text )  
RETURNS boolean
AS $$
"""
Tis function takes pairs of nodes of a network as input, plus the cost associated to the distance between those nodes. 
one pair is an edge of the graph, the cost is the weight
we use networkx top generate  a graph, then export it in GraphML 
require networkx
"""
import numpy as np ;
import plpy ;
import networkx as nx;  
  

# converting the 1D array to numpy array
nodes= np.array(node)
nodes_Z = np.array(node_z)
n1 = np.array(node1) 
n2 = np.array(node2) 
tweight = np.array(tcost) 

# creating graph
G=nx.Graph() 

# creating the nodes
for n,node_ in enumerate(nodes):
	G.add_node(node_, Z=float(nodes_Z[n]))

#creating the edges
#G.add_weighted_edges_from(edge)
for  i,n1_ in enumerate( n1):
	G.add_edge(int(n1_),int(n2[i]), weight=float(tweight[i]) )

#writting GraphML
writting = nx.write_graphml(G, path_to_file)

return writting;
  
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 
 
	
 
