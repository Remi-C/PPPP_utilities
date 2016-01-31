# -*- coding: utf-8 -*-
"""
Created on Sat Jan 30 14:57:02 2016

@author: Remi
"""

# -*- coding: utf-8 -*-
"""
MidOc ordering of point cloud

input is 3*n float list represeneting 3D poitns
we order the point by the MidOc ordering

@author: remi
"""

#importing modules
import numpy as np; 
#import matplotlib.pyplot as plt

#from numpy import random ;
#
def plot_points(point_cloud, points_scaled_quantized,result,piv):
    plt.clf()
    plt.cla()
    plt.close() 
    plt.close("all")
    piv_ar = [] ;
    r_ar = []; 
    piv_ar = np.array(piv)
    r_ar = np.array(result);  
    #print piv
    result_point = points_scaled_quantized[r_ar[:,0]] 

    
    fig1,ax1 = plt.subplots(nrows=1, ncols=1) ; 
    ax1.scatter(point_cloud[:,0], point_cloud[:,1],  c= 'red')
    #ax1.title('original_cloud')   
      
    fig, ( ax2,ax3,ax4) = plt.subplots(nrows=1, ncols=3,sharex=True,sharey=True);
     
   
    ax2.scatter(points_scaled_quantized[:,0], points_scaled_quantized[:,1], c='green');
    #ax2.title('scaled_quantized cloud');
    ax3.scatter(result_point[:,0], result_point[:,1],  c= 'blue')
    #ax3.title('chosen_points')    
    ax4.scatter(piv_ar[:,0], piv_ar[:,1], c='yellow');
    #ax4.title('mid octree points'); 
    fig1.show()
    fig.show()
    print(result);
 
def plot_points_3D(point_cloud, points_scaled_quantized,result,piv):
    from mpl_toolkits.mplot3d import Axes3D 
    
    plt.clf();plt.cla();plt.close() ;plt.close("all")
    piv_ar = [] ;r_ar = []; 
    #print type(piv)
    #print piv;
    piv_ar =  np.array(piv) 
    r_ar = np.array(result);  
    #print piv
    result_point = points_scaled_quantized[r_ar[:,0]] 
   
    
    
    fig3D = plt.figure()
    for i,(pc) in enumerate((point_cloud,points_scaled_quantized,result_point,piv_ar)):
        #print 'iteration : ',i      
        xs = pc[:,0]
        ys = pc[:,1]
        zs = pc[:,2] 
        ax1 = fig3D.add_subplot(140+i+1, projection='3d')
        ax1.scatter(xs, ys, zs, c='r', marker='o')
       
    fig3D.show();
    #print result ;

  
    
#order_by_octree();
def test_order_by_octree_pg():
    iar =  [-100.838, 1289.154, 38.265, -100.604, 1289.07, 38.264, -101.433, 1288.963, 38.276, -100.928, 1289.498, 38.265, -100.854, 1289.104, 38.264, -100.547, 1289.375, 38.257, -101.451, 1289.113, 38.276, -101.258, 1288.975, 38.274, -100.724, 1289.012, 38.266, -100.905, 1289.201, 38.264, -101.239, 1288.521, 38.276, -100.573, 1288.568, 38.268, -100.786, 1288.906, 38.262, -100.996, 1288.691, 38.269, -100.804, 1288.703, 38.27, -101.111, 1288.885, 38.269, -100.554, 1289.473, 38.26, -100.761, 1288.758, 38.266, -101.194, 1288.828, 38.273, -100.512, 1289.227, 38.261, -101.213, 1288.523, 38.276, -101.4, 1289.316, 38.273, -100.83, 1288.602, 38.27, -101.411, 1289.266, 38.271, -101.345, 1288.666, 38.279, -101.208, 1289.279, 38.27, -101.014, 1288.588, 38.271, -101.366, 1289.469, 38.271, -101.002, 1288.842, 38.27, -101.004, 1289.145, 38.269, -101.068, 1288.736, 38.273, -101.124, 1289.484, 38.27, -101.264, 1288.52, 38.276, -101.181, 1288.83, 38.273, -100.88, 1288.648, 38.267, -101.435, 1288.762, 38.277, -100.745, 1288.557, 38.268, -100.874, 1289.252, 38.264, -100.975, 1289.045, 38.267, -100.588, 1289.021, 38.263, -101.448, 1289.314, 38.272, -101.203, 1289.131, 38.271, -100.516, 1288.824, 38.261, -101.187, 1288.729, 38.27, -101.003, 1288.689, 38.269, -101.211, 1289.029, 38.271, -100.802, 1289.006, 38.265, -101.417, 1288.814, 38.278, -101.268, 1289.076, 38.27, -100.676, 1289.166, 38.262, -101.281, 1288.621, 38.275, -100.938, 1288.797, 38.271, -100.865, 1288.699, 38.271, -100.781, 1288.654, 38.268, -100.536, 1289.025, 38.262, -101.283, 1289.023, 38.272, -100.517, 1289.076, 38.262, -100.624, 1289.469, 38.261, -100.79, 1289.357, 38.26, -100.951, 1288.846, 38.269, -101.152, 1289.334, 38.267, -101.308, 1288.619, 38.278, -101.487, 1288.758, 38.276, -100.688, 1288.713, 38.264, -101.452, 1289.363, 38.27, -100.768, 1288.807, 38.265, -101.451, 1289.012, 38.276, -100.76, 1288.555, 38.266, -100.54, 1288.975, 38.264, -101.482, 1289.41, 38.271, -101.341, 1289.371, 38.27, -100.713, 1289.113, 38.266, -100.766, 1288.656, 38.269, -100.991, 1289.395, 38.269, -100.525, 1288.621, 38.263, -101.34, 1289.172, 38.274, -100.93, 1289.398, 38.265, -101.237, 1289.428, 38.267, -101.348, 1288.869, 38.276, -101.426, 1288.561, 38.28, -101.035, 1288.586, 38.271, -101.449, 1289.164, 38.273, -101.112, 1288.633, 38.275, -100.796, 1289.258, 38.264, -100.87, 1289.102, 38.267, -100.649, 1288.512, 38.266, -100.58, 1288.77, 38.264, -101.087, 1289.488, 38.267, -101.209, 1288.727, 38.275, -100.799, 1288.502, 38.264, -100.941, 1289.299, 38.266, -100.693, 1288.863, 38.263, -101.36, 1289.369, 38.27, -101.466, 1288.607, 38.278, -100.588, 1288.971, 38.261, -100.667, 1288.713, 38.267, -101.416, 1288.863, 38.277, -100.662, 1288.563, 38.264, -101.375, 1289.369, 38.274, -101.201, 1289.33, 38.27] ; 
    
    
    return order_by_octree_pg(iar,7,3,3);
    
    
def order_by_octree_test():
    #creating test data 
    tot_level,test_data_size,test_data_dim, pointcloud,index = \
        create_test_data(3,10,2); 
    
    #centering/scaling/quantizing the data
    pointcloud_int = center_scale_quantize(pointcloud,tot_level );  
    
    #print points_to_keep
    #initializing variablesoctree_ordering
    center_point,result,piv = preparing_tree_walking(tot_level) ;   
     
    #iterating trough octree : 
    recursive_octree_ordering(pointcloud_int,index,center_point, 0,tot_level,tot_level, result,piv) ;
    
    #print the result  
    plot_points(pointcloud, pointcloud_int,result, piv) ; 
    
    #test 


def order_by_octree(pointcloud,tot_level,stop_level):
    the_result = [];index =[]
    #creating the index array     
    index = np.arange(0,pointcloud.shape[0])   
    #centering/scaling/quantizing the data
    pointcloud_int = center_scale_quantize(pointcloud,tot_level )  
    
    #initializing variables
    center_point,the_result,piv = preparing_tree_walking(tot_level)    
    #iterating trough octree : 
    #recursive_octree_ordering(pointcloud_int,index,center_point, 0,tot_level,stop_level, the_result,piv) ;
    points_to_keep = np.arange(pointcloud.shape[0],dtype=int)
    recursive_octree_ordering_ptk(points_to_keep, pointcloud_int,index,center_point, 0,tot_level,stop_level, the_result,piv) 
     
    #plot_points_3D(pointcloud, pointcloud_int,the_result, piv)  
    the_result= np.array(the_result)
    return the_result 
 
def order_by_octree_pg(iar,tot_level,stop_level,data_dim):  
    
    the_result = [];index =[];
    #converting the 1D array to 2D array
    temp_pointcloud = np.reshape(np.array(iar), (-1, data_dim))  ; 
    
    #we convert to 2D for ease of use 
    #pointcloud = np.column_stack( (temp_pointcloud[:,0],temp_pointcloud[:,1]) )
    pointcloud = temp_pointcloud 
    
    #creating the index array     
    index = np.arange(0,pointcloud.shape[0])   
    #centering/scaling/quantizing the data
    pointcloud_int = center_scale_quantize(pointcloud,tot_level );   
    
    #initializing variables
    center_point,the_result,piv = preparing_tree_walking(tot_level) ;   
    #iterating trough octree : 
    #recursive_octree_ordering(pointcloud_int,index,center_point, 0,tot_level,stop_level, the_result,piv) ;
    points_to_keep = np.arange(pointcloud.shape[0],dtype=int);
    recursive_octree_ordering_ptk(points_to_keep, pointcloud_int,index,center_point, 0,tot_level,stop_level, the_result,piv) ;
     
    #plot_points_3D(pointcloud, pointcloud_int,the_result, piv) ; 
    the_result= np.array(the_result);
    the_result[:,0]= the_result[:,0]+1 #ppython is 0 indexed, postgres is 1 indexed , we need to convert
    return the_result ;

def count_points_per_class(result, stop_level):
    """ """
    #fabricating an arrayfor the pt per class
    pt_per_class = np.zeros(stop_level)
    #for each class, count the number of points in it
    for _i in range(0,stop_level):
        pt_per_class[_i] = result[result[:,1]==_i].shape[0] 
    return pt_per_class
    
def complete_and_shuffle_result(result, num_points):
    import numpy as np
    #creating a new index to play with    
    index = np.arange(0,num_points)
    #adding a column to store level (32767 default), and a random column to further ordering
    index = np.c_[ index,  np.full(num_points,32767),np.random.rand(num_points)  ]
    #filling with known level
    index[result[:,0],1]= result[:,1]
    #reordering following level, random 
    dt = [('col1', index.dtype),('col2', index.dtype),('col3', index.dtype)]
    assert index.flags['C_CONTIGUOUS']
    b = index.ravel().view(dt)
    b.sort(order=['col2','col3'])
    #replacing the undefined level by -1
    index[index[:,1]==32767,1] = -1
    
    #returning a table with (original index, level) , with definite ordering
    return index[:,(0,1)]
    
    

def create_test_data(tot_level,test_data_size,test_data_dim): 
    """Simple helper function to create a pointcloud with random values"""
    return tot_level,test_data_size,test_data_dim \
        ,np.random.rand(test_data_size,test_data_dim)\
        ,np.arange(0,test_data_size) ;
        
        
def center_scale_quantize(pointcloud,tot_level ):
    """ Centers/scale the data so that everything is between 0 and 1
        Don't deformate axis between theim. 
        Quantize using the number of level 
        @param a 2D numpy array, column = X,Y(,Z)  
        @param the number of bit we want to quantize on  
        @return a ne point cloud, same number of points, but everything between 0 and 1, and quantized
        """   
    data_dim = pointcloud.shape[1] ; 
    #centering data so that all dim start at 0 
    pointcloud_int = pointcloud - np.amin(pointcloud.T, axis=1); 
    
    #finding the max scaling, that is the biggest range in dimension X or Y or Z
    max_r = 1 ;
    new_max = np.amax(np.amax(pointcloud_int.T,axis=1)) #look for max range in X then Y then Z, then take the max of it
    if new_max !=0: #protection against pointcloud with only one points or line(2D) or flat(3D)
        max_r = new_max;
    
    #dividing so max scale is 0 . Now all the dimension are between [0,1]
    pointcloud_int = pointcloud_int/ max_r ; 
    
    #quantizing 
    smallest_int_size_possible = max(8*np.ceil(tot_level/8),8) #protection against 0 size
    if smallest_int_size_possible > 8 : 
        if smallest_int_size_possible > 32 :
            smallest_int_size_possible = max(32*np.ceil(tot_level/32),32) #protection against 0 size
        else :
            smallest_int_size_possible = max(16*np.ceil(tot_level/16),16) #protection against 0 size

    pointcloud_int =  np.trunc(abs((pointcloud_int* pow(2,tot_level) )))\
         .astype(np.dtype('uint'+str(int(smallest_int_size_possible))));
    #we have to take care of overflow : if we reach the max value of 1<<tot_level, we go one down
    pointcloud_int[pointcloud_int==pow(2,tot_level)]=(pow(2,tot_level)-1);     
    return pointcloud_int

 
def testBit(int_type, offset):
    mask = 1 << offset
    return( (int_type & mask)>0 ) 

def array_to_bit(array):
    funcs = [lambda x: np.binary_repr(x)]
    apply_vectorized = np.vectorize(lambda f, x: f(x))
    return apply_vectorized(funcs, array);
 

def preparing_tree_walking(tot_level): 
    """ preparing input/output of ordering, computing center_point, puttig result and iv to [];"""
    #preparing input/output of ordering
    #computing center_point, 
    point_coor = pow(2,tot_level-1) ;
    center_point = np.array([point_coor,point_coor,point_coor])
    #puttig result and iv to []; 
    return center_point,[],[];
    

def recursive_octree_ordering_print(point_array,index_array, center_point, level,tot_level, result,piv):
    #importing necessary lib
    import numpy as np;
    print('\n\n working on level : '+str(level)); 
    print('input points: \n\t'+point_array ); 
    print('index_array : \n\t'+index_array);
    print('center_point : \n\t'+center_point);
    print( 'level : \n\t'+level);
    print('tot_level : \n\t'+tot_level);
    print('result : \n\t'+result);
    #stopping condition : no points:
     
     
     
def recursive_octree_ordering(point_array,index_array, center_point, level,tot_level,stop_level, result,piv):
    
    #updatig level;
    sub_part_level = level+1 ;
    #print for debug
    #recursive_octree_ordering_print(point_array,index_array, center_point, level,tot_level, result,piv);
    
    if ( (len(point_array) == 0) | level >=min(tot_level,stop_level)):
        return;
     
    #print 'level ',level,' , points remaining : ',len(point_array) ;
    #print center_point; 
    piv.append(center_point.tolist()); #casting the point to a simple array, to simplify piv
 
    
    #find the close    st point to pivot 
    min_point = np.argmin(np.sum(pow(point_array - center_point ,2),axis=1))
    result.append(list((index_array[min_point],level))) ;  
    #print 'all the point ', point_array
    #print 'min_point ',min_point,'its index ', index_array[min_point],'the point ',  point_array[min_point] ; 
    
    #print 'n points before delete : ',len(point_array) ;     
    #removing the found point from the array of points   
    point_array= np.delete(point_array, min_point,axis=0 ) ;
    index_array= np.delete(index_array, min_point,axis=0 ) ; 
    #point_array[min_point,:]=-1; 
    #index_array[min_point] = -1; 
    #print 'n points after delete : ',len(point_array) ; 
    #print 'all the point after delete ', point_array
    #sprint '\n\n';
    #stopping if it remains no pioint : we won't divide further, same if we have reached max depth
    if (len(point_array) ==0 )|(level >= min(tot_level,stop_level)):
        return;

    bit_value_for_next_lev =  testBit(point_array,tot_level - level -1) ; 
    
   
    #compute the 8 sub parts
    for b_x in list((0,1))  :
        for b_y in list((0,1)) :
            for b_z in list((0,1)):
                #looping on all 8 sub parts
                #print (b_x*2-1), (b_y*2-1) ;
                half_voxel_size = (pow(2,tot_level - level -2  )) ; 
                udpate_to_pivot = np.asarray([ (b_x*2-1)* half_voxel_size
                    ,(b_y*2-1)*half_voxel_size
                    ,(b_z*2-1)*half_voxel_size
                ]); 
                sub_part_center_point = center_point +udpate_to_pivot; 
                
                 
                
                # we want to iterateon 
                # we need to update : : point_array , index_array    center_point  , level
                #update point_array and index_array : we need to find the points that are in the subparts
                #update center point, we need to add/substract to previous pivot 2^level+11
                
                #find the points concerned :
                point_in_subpart_mask = np.all( \
                    bit_value_for_next_lev == np.array([b_x,b_y,b_z]), axis=1); 
                #point_in_subpart_mask =( ( (
                #     testBit(point_array[:,0],tot_level - level -1 ) ==b_x)
                #    == ( testBit(point_array[:,1],tot_level - level -1 ) ==b_y ) )
                #    == ( testBit(point_array[:,2],tot_level - level -1 ) ==b_z )
                #    ); 
                
                #point_in_subpart_mask = np.all(    testBit(point_array,tot_level-level-1)== np.array([b_x,b_y]), axis=1)       
                #point_in_subpart_mask = np.all(testBit_arr(point_array, [b_x,b_y]),axis=1) ; 
                #point_in_subpart_mask = np.logical_and(
                #     testBit(point_array[:,0],level) ==b_x
                #    , testBit(point_array[:,1],level) ==b_y  ) ; 
                sub_part_points= point_array[point_in_subpart_mask]; 
                sub_part_index = index_array[point_in_subpart_mask];  
                #print 'lenght point : ',len(point_array),' length sub_part_point : ',len(sub_part_points); 
                if len(sub_part_points)==0: #no more point, don't go depper
                    continue; 
                else:#maybe many points, need to go deeper
                    recursive_octree_ordering(sub_part_points
                        ,sub_part_index
                        , sub_part_center_point
                        , sub_part_level
                        , tot_level
                        , stop_level
                        , result
                        , piv); 
                        #continue;  
    return point_array,index_array ,result,piv
    

     
def recursive_octree_ordering_ptk(points_to_keep, point_array,index_array, center_point, level,tot_level,stop_level, result,piv):
    #print 'points_to_keep : ',points_to_keep ; 
    #print 'points_to_keep length : ',len(points_to_keep) ; 
    
    #print 'toto :' ,point_array[points_to_keep]
    #updatig level;
    sub_part_level = level+1 ;
    #print for debug
    #recursive_octree_ordering_print(point_array,index_array, center_point, level,tot_level, result,piv);
    
    if ( (len(points_to_keep) == 0) | level >=min(tot_level,stop_level)):
        return;
    
    #print 'level ',level,' , points remaining : ',len(point_array) ;
    #print center_point; 
    piv.append(center_point.tolist()); #casting the point to a simple array, to simplify piv
 
    
    #find the close    st point to pivot 
    min_point = np.argmin(np.sum(pow(point_array[points_to_keep] - center_point ,2),axis=1))
    result.append(list((index_array[points_to_keep][min_point],level))) ;  
    #print 'all the point ', point_array
    #print 'min_point ',min_point,'its index ', index_array[min_point],'the point ',  point_array[min_point] ; 
    
    #print 'n points before delete : ',len(point_array) ;     
    #removing the found point from the array of points    
    points_to_keep = np.delete(points_to_keep,min_point,axis=0);
    
    #print 'n points after delete : ',len(point_array) ; 
    #print 'all the point after delete ', point_array
    #sprint '\n\n';
    #stopping if it remains no pioint : we won't divide further, same if we have reached max depth
    if (len(points_to_keep) ==0 )|(level >= min(tot_level,stop_level)):
        return;

    bit_value_for_next_lev =  testBit(point_array[points_to_keep],tot_level - level -1) ; 
    
   
    #compute the 8 sub parts
    for b_x in list((0,1))  :
        for b_y in list((0,1)) :
            for b_z in list((0,1)):
                #looping on all 8 sub parts
                #print (b_x*2-1), (b_y*2-1) ;
                half_voxel_size = (pow(2,tot_level - level -2  )) ; 
                udpate_to_pivot = np.asarray([ (b_x*2-1)* half_voxel_size
                    ,(b_y*2-1)*half_voxel_size
                    ,(b_z*2-1)*half_voxel_size
                ]); 
                sub_part_center_point = center_point +udpate_to_pivot; 
                
                 
                
                # we want to iterateon 
                # we need to update : : point_array , index_array    center_point  , level
                #update point_array and index_array : we need to find the points that are in the subparts
                #update center point, we need to add/substract to previous pivot 2^level+11
                
                #find the points concerned :
                point_in_subpart_mask = np.all( \
                    bit_value_for_next_lev == np.array([b_x,b_y,b_z]), axis=1);  
             
                if(len(points_to_keep[point_in_subpart_mask])==0): #no more point, don't go depper
                    #print '\t we dont go further';
                    continue; 
                else:#maybe many points, need to go deeper
                    recursive_octree_ordering_ptk(
                          points_to_keep[point_in_subpart_mask]    
                        , point_array
                        , index_array
                        , sub_part_center_point
                        , sub_part_level
                        , tot_level
                        , stop_level
                        , result
                        , piv); 
                        #continue;  
    return points_to_keep,result,piv


#correct_result = np.array(
#[[39,0],[89,1],[25,2],[79,2],[83,2],[16,2],[26,1],[76,2],[99,2],[42,2],[61,2],[18,1],[35,2],[13,2], [12,2],[92,2],[84,1],[85,2],[77,2],[ 2,2],[ 6,2]])


#result = test_order_by_octree_pg();
#print 'result : ',result
#print correct_result == result


#
#import cProfile 
#import pandas as pd
#import numpy as np
#cProfile.run('test_order_by_octree_pg();')
#toto =  test_order_by_octree_pg(); 
#print toto
#s = pd.Series(toto[:,0])
#print  np.array(s[s.duplicated()]).T 
#print  len(np.array(s[s.duplicated()]).T)