# -*- coding: utf-8 -*-
"""
Created on Sat Feb 06 17:28:04 2016

@author: Remi
this functions extract the number of points per octree level (real)
using z ordering
"""

#necessitate zorder.py
import numpy as np


def test_ppl_octree():
    npoints = [9,9,9]
    multi = 100
    random_strength = 0.1
    points = []
    for i in np.arange(1,npoints[0]):
        for j  in np.arange(1,npoints[1]): 
            for k  in np.arange(1,npoints[2]): 
                to_append=  ( np.array([i,j,k])  + (0.5 - np.random.random()) * random_strength ) * multi 
                points.append(
                   to_append.astype(np.int)
                    )
    
    points = np.asarray(points)
    #the points should be translated inreference to 0 
    points = points- np.min(points)
    return ppl_octree(points.astype(np.int32) )
    
def plot_points(points):
    import numpy as np
    from mpl_toolkits.mplot3d import Axes3D
    import matplotlib.pyplot as plt
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d') 
    ax.scatter(points[:,0], points[:,1], points[:,2] ) 
    plt.show()


# test : creating an array of random points
# order by zcurve
# count
# return count 

def affected_cell_number(diff_points):
    """ from the differnece of 2 morton codes, look for the highest bit and 
    conclude about cell level"""
    import math 
    return int(np.floor(math.log(diff_points, 2)))    
    
    
def ppl_octree(points):
    import zorder
    #orde rpoints following z order
    ndim = 3
    
    enc = zorder.ZEncoder(ndim, bits = 64)
    morton = np.apply_along_axis(enc.encode, 1, points) 
    
    morton = np.sort(morton)
    
    #plot_points(points)
    
    #print morton
    #loop on points, for each pair of successive points, compute the affected cell
    #level  =0)
    
    diff = np.bitwise_xor(morton ,np.roll(morton,1,axis=0))
    
    #print 'diff', diff
    
    decoding = np.vectorize(enc.decode)
    decoded = decoding( diff)
    decoded =  np.max(decoded,axis = 0 )
    
    finding_c_number = np.vectorize(affected_cell_number)
    decoded_log = finding_c_number( decoded)
    level = -( decoded_log-np.max(decoded_log))
    #print decoded_log
    #print level
    print np.bincount(level)
    return 
    
    
    for i in decoded:
        print("\t \t",affected_cell_number(i))
        print np.binary_repr(i, width = 8)
        
    print decoded
    print -(decoded- np.max(decoded))
    
    
    for i in diff:
        #print np.binary_repr(i,width=32)
        max_level = np.max(enc.decode(i)) 
        print("\t \t",affected_cell_number(max_level))
        print np.binary_repr(max_level, width = 8)
        
    
    
    level = np.floor( np.log(diff)/np.log(2)/3.0).astype(np.int)
    print(level-3)    
    print np.bincount(level)
    return
      
    finding_c_number = np.vectorize(affected_cell_number)
    lev_offset = finding_c_number( diff)
    print('lev_offset')
    print lev_offset
    lev = lev_offset 
    
    max_level = np.max(lev) - np.min(lev_offset) +1 
    print('max_level')
    print max_level
    ppl_octree = np.zeros(max_level-1)
    ppl_octree[0]=1
    for i in np.arange(1,max_level-1):
        print('i', i) 
        print('i+ np.min(lev_offset)+1')
        print(i+ np.min(lev_offset)+1)
        ppl_octree[i] =  np.sum((lev <= i+ np.min(lev_offset)+1 ).astype(np.int))
        print('size')
        print np.sum((lev <= i+ np.min(lev_offset)+1 ).astype(np.int))
    
    print('ppl_octree')
    print ppl_octree
           
    return ppl_octree

test_ppl_octree()