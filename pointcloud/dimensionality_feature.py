# -*- coding: utf-8 -*-
"""
Created on Sun Jan 31 17:57:57 2016

@author: Remi

this lib computes the dimensionality descriptor of a patch 
based on Weinmann 2015

idea is  : compute a kind of 3D auto-covariance matrix
find eigen values of it 
define dimensionality features based on eigenvalues
"""


import numpy as np
 
def compute_3D_cov_matrix_test():
    from numpy import random
    num_points =  1000
    #defining fake points
    points = random.random((num_points,3)) 
    points[:,2]= 3
    #print points
    C = compute_3D_cov_matrix(points)
    descriptors = cov_matrix_to_dim_descriptors(C)
    
    print( descriptors )

def compute_3D_cov_matrix(points):
    """this function takes a numpy array of 3D points and compute the cov matrix"""
    import numpy as np
    
    #creating an empty matrix
    C = np.zeros((3,3),'float64')
    
    #averaging the points to find centroid
    Centroid = np.average(points, axis=0)
    #print(Centroid)
    
    
    
    #filling the empty matrix
    for pt in points:
        # note : inverted X.T x X because of numpy. newaxis necessary to make it understand that it is 2D array
        C += (np.dot((pt-Centroid)[np.newaxis].T ,(Centroid-pt)[np.newaxis]))
        #print(C)
    C = C / (points.shape[0])
    #print(C)
    return C
    
def cov_matrix_to_dim_descriptors(cov_matrix):
    """ withcov matrix, compute dim descriptor"""
    
    #extract eigne values
    from scipy import linalg 
    eig_values = linalg.eigh(cov_matrix, b=None, eigvals_only=True, overwrite_a=True)
    #print eig_values
    #compute descriptors
    descriptors = np.array((eig_values[0]-eig_values[1],eig_values[1]-eig_values[2],eig_values[2])) \
        / eig_values[0] 
    
    return descriptors


def compute_descriptors_from_points(points):
    """given 3D points, compute dim descriptors"""
    C = compute_3D_cov_matrix(points)
    descriptors = cov_matrix_to_dim_descriptors(C)
    return descriptors
    
    
    
def compute_dim_descriptor_from_patch(uncompressed_patch):
    """ given a patch, extract points and compute dim descriptors"""
    import pg_pointcloud_classes as pgp
  
    #convert patch to numpy array 
    GD = pgp.create_GD_if_not_exists()
    #cache mecanism for patch schema
    if 'rc' not in GD:  # creating the rc dict if necessary
        GD['rc'] = dict()
    if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
    	GD['rc']['schemas'] = dict() 
    
    pt_arr, (mschema,endianness, compression, npoints) = \
        pgp.patch_string_buff_to_numpy(uncompressed_patch, GD['rc']['schemas'], [])
    #pt_arr, (mschema,endianness, compression, npoints) = pgp.patch_string_buff_to_numpy(uncompressed_patch, temp_schema, [])
    numpy_double, mschema = pgp.patch_numpy_to_numpy_double(pt_arr[ ["X","Y","Z"]], mschema)
    
    #computing descriptors 
    descriptors = compute_descriptors_from_points(numpy_double)
    return descriptors 
    





#########################################################
### Descriptor based on midoc ordering                  #
#########################################################


def reject_outliers(data, m = 2.):
    """ reject outlier quit robistly, found on internet."""
    import numpy as np
    d = np.abs(data - np.median(data)) 
    mdev = np.median(d) 
    return data[d<=m*mdev] 


def compute_rough_descriptor(points_per_level,num_points):
    """ given the number of points per level (from MidOc), and the ttotal number of points
    , compute a dimensionality descriptor
    the idea is to measure the squarred distance to ideal distribution, taking into account 
    the possible lack of points"""
    from math import log, ceil
    nb_level = points_per_level.shape[0]

    #computing the perfect distribution matrix
    ref_dist = np.zeros((3,nb_level), dtype='float32')
    for i in np.arange(0,nb_level):
        ref_dist[:,i] = np.array((2**i, 4**i, 8**i))
    #print ref_dist   

    #with the number of points, what is the max level attainable 
    max_level_consolidated = find_max_usable_level(points_per_level,num_points)
    #print("max level consolidated : ",max_level_consolidated)
    
    #find the function best fitting the data from level 1 up to the max level
    theoretical_dim, cov = fit_data_to_theoretical_function(points_per_level,max_level_consolidated ) 
    #print('theoretical_dim with least square fitting',theoretical_dim,' cov',cov)
        
    #measure the distance to ideal values
    s_dist = (ref_dist -  points_per_level)/ref_dist 
    
    #normalise
    s_dist= s_dist[:,1:max_level_consolidated]
    s_dist = np.abs(s_dist)
    #max should be 1 
    s_dist[s_dist > 1] = 1
    
    #creating result
    rough_dim_vector = np.zeros(3)
    #removing outliers with median
    for i in np.arange(0,3): 
        outliers = reject_outliers(s_dist[i,:])  
        #print('tokeep',outliers) 
        rough_dim_vector[i]=np.average(outliers)
    
    #inverting 
    rough_dim_vector = 1 - rough_dim_vector
    #sum should be 1 to mimic properties of real stuff
    rough_dim_vector = rough_dim_vector / np.sum(rough_dim_vector)
    #print rough_dim_vector
    
    return rough_dim_vector, theoretical_dim
    
def find_max_usable_level(points_per_level,num_points):
    """given a number of points per level, the total number of points in the
    patch, and the matrix with theretical points per level
    depending on dimension, find the max level that can reasonnably be used.
    Necessary because the number of points might not be sufficient to fill
    all level, yet this could be misinterpreted
    """
    #find the theoretical max level based on number of points 
    #this can t be used as upper limit though
    from math import ceil, log, floor
    max_theoretical_level = floor(log(num_points,2))  

    #find if any level has less points than the next, if it is the case
    # discard it
    max_less = points_per_level.shape[0]
    for i in np.arange(1,points_per_level.shape[0]):
        if points_per_level[i]< 1.5* points_per_level[i-1]:
            max_less = i 
     
    #the max level will be min(max(max_theroretical_level,max_less),points_per_level.shape[0]) 
    max_level_consolidated = min(max(max_theoretical_level,max_less),points_per_level.shape[0])
    return max_level_consolidated   

def fit_data_to_theoretical_function(points_per_level,max_level_consolidated ):
    """ the theoreticalfunction is exp(i * ln(2**k)), where is the level
    the data is points_per_level"""
    from scipy.optimize import curve_fit
    values = points_per_level[1:max_level_consolidated] 
    x = np.arange(1,max_level_consolidated) 
    if x.size == 0:
        return None,None
    theoretical_dim, cov = curve_fit(theoretical_function,  x , values ,
                                p0=None, sigma=None, absolute_sigma=False)
    if theoretical_dim is not None: 
        theoretical_dim = theoretical_dim[0]
        cov = cov[0][0]
    return theoretical_dim, cov 
def theoretical_function(x,k):
    """ theoretical function of space occupation"""
    from numpy import exp,log 
    return exp(x * log(2**k))
    
def compute_rough_descriptor_test():
    
    #points_per_level= np.array((1,2,3,7,15))
    points_per_level= np.array((1,4,15,62,220))
    points_per_level= np.array((1,7,61,500,4000))
    points_per_level= np.array((1,6,20,250,1000))
    #num_points = np.sum(points_per_level)
    num_points = 1
    
    rough_dim_vector, theoretical_dim = compute_rough_descriptor(points_per_level,num_points)


    
compute_rough_descriptor_test()
