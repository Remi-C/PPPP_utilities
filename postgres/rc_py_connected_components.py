# -*- coding: utf-8 -*-
"""
Created on Fri Oct 17 15:23:08 2014

@author: remi
"""
# input = 2 arrays of node. (ar[1],ar[2]) = edge
#we want to compute the connected components
import numpy as np ;
import networkx as nx ; 

node1 = (1,1,1,2,3,3,4) ;   
node2 = (9,3,7,6,7,8,9) ; 


n1 = np.array(node1) ; 
n2 = np.array(node2) ;

edge = np.column_stack( (n1,n2) );

edge[0,0] ;
edge[1,1] ;


G=nx.Graph()
 
G.add_edges_from(edge)
nx.draw(G)
 
cc = sorted(nx.connected_components(G), key = len, reverse=True) ; 

result = list() ;  
for idx, val in enumerate(cc):
    print idx, val
    for n_val in val:
        result.append((n_val, idx)) ;
         
        
