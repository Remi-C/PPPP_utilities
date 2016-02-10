# -*- coding: utf-8 -*-
"""
Created on Sat Feb 06 17:28:04 2016

@author: Remi
this functions extract the number of points per octree level (real)
using z ordering
"""

#necessitate zorder.py
import numpy as np


def benchmark_ppl():
    import matplotlib.pyplot as plt
    duration = []
    square_size = []
    min_square_size = 2
    max_square_size = 64
    for i in np.arange(min_square_size,max_square_size):
        dur = test_ppl_octree(i)
        duration.append(dur.total_seconds())
        square_size.append(i)
    
    print duration 
    print square_size
    plt.plot(square_size,duration)
    #plt.show()
    
     
def test_ppl_octree(npo):
    import datetime ; 
    # creating test data 
    npoints = [npo,npo,npo]
    
    multi = 1
    tot_level = 8
    random_strength = 0. 
    points = []
    for i in np.arange(0,npoints[0]):
        for j  in np.arange(0,npoints[1]): 
            for k  in np.arange(0,npoints[2]): 
                #to_append=  np.round( ( np.array([i,j,k])  + (0.5 - np.random.random()) * random_strength ) * multi)
                to_append = np.array([i,j,k])
                points.append(
                   to_append.astype(np.int)
                    )  
    points = np.vstack([points,points])
    print points
    points = np.asarray(points)
    #plot_points(points)
    print('snb of points : ', points.shape[0])
    #points should be proprerly scaled, based on the expected precision,
    #the biggest dimension between 0 and 2^N
    time_start = datetime.datetime.now() 
    ppl = pointcloud_to_ppl(points,tot_level)
    time_end = datetime.datetime.now() 
    duration = time_end-time_start
    print 'duration : %s ' % (time_end-time_start)
    print ppl
    return duration
    
    
    #return ppl_octree(points.astype(np.int32) )
    
def plot_points(points, level=None):
    import numpy as np
    from mpl_toolkits.mplot3d import Axes3D
    import matplotlib.pyplot as plt
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d') 
    if level is None:
        ax.scatter(points[:,0], points[:,1], points[:,2] ) 
    else:
        ax.scatter(points[:,0], points[:,1], points[:,2] ,linewidths=10/(level+1)) 
    plt.show()

def plot_points_with_level(morton,level,enc):
    """ given the morton code of points and a level per code and the encodor
    print the points  with the code"""
    
    #decode morton
    decoding = np.vectorize(enc.decode)
    points = decoding( morton)
    print points
    print level
    plot_points(np.asarray(points).T,level)

# test : creating an array of random points
# order by zcurve
# count
# return count 
      
def center_scale_quantize(pointcloud,tot_level):
    """ Centers/scale the data so that everything is between 0 and 1
        Don't deformate axis between theim. 
        Quantize using the number of level 
        @param a 2D numpy array, column = X,Y(,Z)  
        @param the number of bit we want to quantize on  
        @return a ne point cloud, same number of points, but everything between 0 and 1, and quantized
        """    
    #centering data so that all dim start at 0 
    pointcloud_int = pointcloud - np.amin(pointcloud.T, axis=1); 
     
    
    #finding the max scaling, that is the biggest range in dimension X or Y or Z
    max_r = 1.0 ;
    new_max = np.amax(np.amax(pointcloud_int.T,axis=1)) #look for max range in X then Y then Z, then take the max of it

    if new_max !=0: #protection against pointcloud with only one points or line(2D) or flat(3D)
        max_r = new_max;
    
    #dividing so max scale is 0 . Now all the dimension are between [0,1]
    pointcloud_int = pointcloud_int/ float(max_r) ; 
    
    #quantizing 
    smallest_int_size_possible = max(8*np.ceil(tot_level/8.0)+1,8) #protection against 0 size
    if smallest_int_size_possible > 8 : 
        if smallest_int_size_possible > 32 :
            smallest_int_size_possible = max(32*np.ceil(tot_level/32.0),32) #protection against 0 size
        else :
            smallest_int_size_possible = max(16*np.ceil(tot_level/16.0),16) #protection against 0 size
     
    pointcloud_int =  np.trunc(abs((pointcloud_int* pow(2,tot_level) )))\
         .astype(np.dtype('uint'+str(int(smallest_int_size_possible))))
    #plot_points(pointcloud_int)
    #we have to take care of overflow : if we reach the max value of 1<<tot_level, we go one down
    pointcloud_int[pointcloud_int==pow(2,tot_level)]=(pow(2,tot_level)-1);     
    return pointcloud_int, smallest_int_size_possible
 
def unique_rows(a): 
    """ found on stack overflow"""
    a = np.ascontiguousarray(a)
    unique_a = np.unique(a.view([('', a.dtype)]*a.shape[1]))
    return unique_a.view(a.dtype).reshape((unique_a.shape[0], a.shape[1]))    
 

def highest_bit_set(point ):
    """given an int, look for the highest bit set""" 
    return int(point).bit_length()    
    
def order_array_by_morton(points, coordinate_bit_size):
    import zorder
    ndim = points.shape[1] 
    #could be 32 or 64, we shalel chose
    bits = 64
    if coordinate_bit_size*3 <= 32:
        bits = 32 
    bits = 64 
    enc = zorder.ZEncoder(ndim, bits)
    morton = np.apply_along_axis(enc.encode, 1, points)   
    return np.asarray(np.sort(morton)), enc
 
def pointcloud_to_ppl(untranslated_unscaled_points,tot_level):
    """ given points, center scale quantize points, order pby morton
    get number of points per level"""
    #points need to be in [0,1]^3 * tot_level^2
    #print untranslated_unscaled_points
    points, coordinate_bit_size = center_scale_quantize(untranslated_unscaled_points,tot_level)
    #plot_points(points)
    
    #removing duplicated points (would gives a wrong result and this is faster)
    points = unique_rows(points)
    
    #converting coordinates to morton, order
    morton_o, enc = order_array_by_morton(points, coordinate_bit_size) 
    
    #for each coordinate, apply XOR with next in morton order
    diff = np.bitwise_xor(morton_o ,np.roll(morton_o,1,axis=0))
    
    #find the highest bit used (still interleaved, so warning)
    h_bit_set = np.vectorize(highest_bit_set)
    h_b_i = h_bit_set( diff)  
    
    #converting the interleaved highest bit to a non interleaved highest bit
    ndim = points.shape[1] 
    h_bit = np.floor((h_b_i +ndim-1 )/float(ndim))

    #converting to level
    level = -1 * ( h_bit-np.max(h_bit))
    #plot_points_with_level(morton_o,level,enc)
    
    #counting point per level
    ppl_iso = np.bincount(level.astype(int)) 
    
    #a point in level X should also be in level X + k
    ppl = np.zeros(ppl_iso.shape[0]+1,dtype=np.int)
    ppl[1:] = ppl_iso
    for i in np.arange(2,ppl.shape[0]):
        ppl[i] = ppl[i] + ppl[i-1]
    ppl[0] = 1 #level 0  should always be at 1 if the patch is not empty
    #returning result
    return ppl     

#test_ppl_octree(10)
#benchmark_ppl()