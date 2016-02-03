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

def filter_points(points, filter_point=False):
    if filter_point==True:
        max_dist =  np.max(np.abs(points),axis=0) 
        second_max = np.sort(max_dist)[1] 
        #all points with one value bigger than the max value of the second largest dim
        #wont be used
        points = points[np.all(np.less_equal(points,second_max),axis=1)]
    return points
    
    
def compute_3D_cov_matrix(points):
    """this function takes a numpy array of 3D points and compute the cov matrix"""
    import numpy as np
    
    #creating an empty matrix
    C = np.zeros((3,3),'float64')
    
    #averaging the points to find centroid
    Centroid = np.average(points, axis=0)
    points -= Centroid
    
    #pottentially remove points that are too far away, not a good idea
    points = filter_points(points, filter_point=False)
    #filling the empty matrix
    for pt in points:
        # note : inverted X.T x X because of numpy. newaxis necessary to make it understand that it is 2D array
        C += (np.dot((pt)[np.newaxis].T ,(-pt)[np.newaxis])) /(points.shape[0])
        #print(C)
    #C = C / (points.shape[0])
    #print(C)
    return C
#compute_3D_cov_matrix_test() 
def cov_matrix_to_dim_descriptors(cov_matrix):
    """ withcov matrix, compute dim descriptor"""
    
    #extract eigne values
    from scipy import linalg 
    eig_values = linalg.eigh(cov_matrix, b=None, eigvals_only=True, overwrite_a=True)
    #print eig_values
    #compute descriptors 
    eig_values[0] = 1 if eig_values[0] == 0 else eig_values[0] 
    descriptors = np.array((eig_values[0]-eig_values[1],eig_values[1]-eig_values[2],eig_values[2])) \
        / eig_values[0] 
    
    return descriptors


def compute_descriptors_from_points(points):
    """given 3D points, compute dim descriptors"""
    C = compute_3D_cov_matrix(points)
    #print C
    descriptors = cov_matrix_to_dim_descriptors(C)
    return descriptors

def compute_descriptors_from_points_test():
    """given 3D points, compute dim descriptors""" 
    import numpy as np 
    npoints = 100
    
    points = np.zeros((npoints,3))
    points[:,0] = np.arange(0,npoints)
    
    points = np.random.random([npoints,3])*10
    points[:,0] = 0.1
    points[:,1] = 0.1
     
    points = (points - np.average(points,axis=0) )
    max_r = 1 
    #look for max range in X then Y then Z, then take the max of it
    new_max = np.amax(np.amax(points.T,axis=1)) 
    if new_max !=0: #protection against pointcloud with only one points or line(2D) or flat(3D)
        max_r = new_max;
    points = points/max_r
    #points = 0.5 + points/ (np.max(points,axis=0) -  np.min(points,axis=0))
   
    
    #fig = plt.figure()
    #ax = fig.add_subplot(111, projection='3d')
    #ax.scatter(points[:,0],points[:,1],points[:,2]  )
 
    
    #print points
    return compute_descriptors_from_points(points)
#
#import matplotlib.pyplot as plt
#from mpl_toolkits.mplot3d import Axes3D 
#print(compute_descriptors_from_points_test())    

def proba_to_dim_power(p_dim):
    """ given p(1D,2D,3D), return d, so that d is the data of the dim"""
    return p_dim[0]+p_dim[1]*2+p_dim[2]*3
    
def compute_dim_descriptor_from_patch(uncompressed_patch, connection_string):
    """ given a patch, extract points and compute dim descriptors"""
    import pg_pointcloud_classes as pgp
  
    #convert patch to numpy array 
    GD = pgp.create_GD_if_not_exists()
    #cache mecanism for patch schema
    if 'rc' not in GD:  # creating the rc dict if necessary
        GD['rc'] = dict()
    if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
    	GD['rc']['schemas'] = dict() 
    
    restrict_dim = ["x","y","z"]
    pt_arr, (mschema,endianness, compression, npoints) = \
        pgp.patch_string_buff_to_numpy(uncompressed_patch, GD['rc']['schemas'], connection_string)
    #pt_arr, (mschema,endianness, compression, npoints) = pgp.patch_string_buff_to_numpy(uncompressed_patch, temp_schema, [])
    numpy_double, mschema = pgp.patch_numpy_to_numpy_double( \
        pt_arr[ restrict_dim], mschema,use_scale_offset=True,dim_to_use=restrict_dim) 
    ###########
    #warning: to be removed ! @TODO 
    #numpy_double[:,0] = numpy_double[:,0]  + 649000
    #numpy_double[:,1] = numpy_double[:,1]  + 6840000
    ########### 
    #computing descriptors 
    descriptors = compute_descriptors_from_points(numpy_double)
    return descriptors
    



#import numpy as np
#test = np.array([1,2,3])
#th_dim = 2.9
#r=   np.abs(test-th_dim)**2
#r = r / np.sum(r)
#print(r)

#########################################################
### Descriptor based on midoc ordering                  #
#########################################################


def reject_outliers(data, m = 2.):
    """ reject outlier quit robistly, found on internet."""
    import numpy as np
    d = np.abs(data - np.median(data)) 
    mdev = np.median(d) 
    return data[d<=m*mdev] 
    
def ppl_to_multiscale_dim(points_per_level,max_level_consolidated):
    """This function takes ppl arrya, max_leve, and return p_dim for 1D,2D,3D"""
    #computing the perfect distribution matrix for each dim, log2
    
    s_ppl = points_per_level[0:max_level_consolidated] 
    points_per_level = s_ppl 
    #print('sppl')
    #print(s_ppl)
    dif_ppl = np.zeros(points_per_level.size-1)
    for i in np.arange(1,points_per_level.size):
        dif_ppl[i-1] = np.log2(s_ppl[i]/s_ppl[i-1].astype('float32'))
     
    ppl  = np.zeros(points_per_level.size-1)
    for i in np.arange(1,points_per_level.size):
        ppl[i-1] = np.log2(s_ppl[i].astype('float32'))/(i)
    
    ppl[ppl<0] = 0
    dif_ppl[dif_ppl<0] = 0
    ppl[ppl>3] = 3
    dif_ppl[dif_ppl>3] = 3
    return  ppl ,  dif_ppl 
    
    
def compute_rough_descriptor(points_per_level,num_points):
    """ given the number of points per level (from MidOc), and the ttotal number of points
    , compute a dimensionality descriptor
    the idea is to measure the squarred distance to ideal distribution, taking into account 
    the possible lack of points""" 
      
    #with the number of points, what is the max level attainable 
    max_level_consolidated = find_max_usable_level(points_per_level,num_points)
    #print("max level consolidated : ",max_level_consolidated)
    
    #find the function best fitting the data from level 1 up to the max level
    theoretical_dim, cov = fit_data_to_theoretical_function(points_per_level,max_level_consolidated ) 
    
    #find the distance to each ideal distribution
    multiscale_dim, multiscale_dim_var = ppl_to_multiscale_dim(points_per_level,max_level_consolidated)
    
    
    multiscale_fused = reject_outliers(np.hstack((multiscale_dim, multiscale_dim_var)), m = 1.)
    multiscale_fused = np.average(multiscale_fused) 
    #print('max_dim')
    #print(max_dim)
    
    return multiscale_dim, multiscale_dim_var, multiscale_fused, theoretical_dim
    
def find_max_usable_level(points_per_level,num_points):
    """given a number of points per level, the total number of points in the
    patch, and the matrix with theretical points per level
    depending on dimension, find the max level that can reasonnably be used.
    Necessary because the number of points might not be sufficient to fill
    all level, yet this could be misinterpreted
    """
    #find the theoretical max level based on number of points 
    #this can t be used as upper limit though
    from math import log, floor
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
    #from scipy.optimize import curve_fit
    values = points_per_level[1:max_level_consolidated] 
    x = np.arange(1,max_level_consolidated) 
    if x.size == 0:
        return None,None
    theoretical_dim, cov  = fit_with_ransac(values,x)
    #theoretical_dim, cov = curve_fit(theoretical_function,  x , values )
    if theoretical_dim is not None: 
        theoretical_dim = theoretical_dim[0]
        if cov is not None:
            cov = cov[0][0]
    theoretical_dim = 0 if theoretical_dim <0 else theoretical_dim
    theoretical_dim = 3 if theoretical_dim >3 else theoretical_dim
    return theoretical_dim, cov 
def theoretical_function(x,k):
    """ theoretical function of space occupation"""
    from numpy import exp,log 
    return exp(x * log(2**k))
 
def compute_rough_descriptor_test():
    
    #points_per_level= np.array((1,2,4,7,15))
    #points_per_level= np.array((1,4,15,60,230))
    points_per_level= np.array((1,7,61,400,2500))
    points_per_level = np.array([ 1,2 ,4 ,8,16,63,83,23])
    #points_per_level= np.array((1,6,20,250,1000))
    #num_points = np.sum(points_per_level)
    num_points = 100 
    multiscale_dim, multiscale_dim_var, multiscale_dim_fuse, theoretical_dim = compute_rough_descriptor(points_per_level,num_points)
    #print(rough_dim_vector, theoretical_dim)

#compute_rough_descriptor_test()

def fit_with_ransac(points_per_level,x):
    """ given an input point_per_level, linear_regression with ransac on ln(ppl)/ln(2)"""
    import numpy as np 
    #working on that
    log_ppl = np.log2(points_per_level)[np.newaxis] 
    X = np.arange(0, log_ppl.size)[np.newaxis]
        
    #now ransac stuff 
    from sklearn import linear_model 
    model = linear_model.LinearRegression()
     
    model.fit(X.T, log_ppl.T) 
    # Robustly fit linear model with RANSAC algorithm
    model_ransac = linear_model.RANSACRegressor(linear_model.LinearRegression(),
                                                min_samples=2 ,max_trials=3000,
                                                residual_threshold=0.6)
    model_ransac.fit(X.T, log_ppl.T) 
     
    # Compare estimated coefficients 
    #print( model.coef_, model_ransac.estimator_.coef_)
    return model_ransac.estimator_.coef_[0] , None
   
   
def fit_with_ransac_test():
    """ """
    import numpy as np    
    nb_level = 5
    
    ref_dist = np.zeros((3,nb_level), dtype='float32')
    for i in np.arange(0,nb_level):
        ref_dist[:,i] = np.array((2**i, 4**i, 8**i))
    
    ppl = ref_dist[2,:]
    ppl= np.array((1,3,15,60,200))  
    ppl= np.array((1,7,50,500,5000))
    ppl = np.array((1,4,15,62,500))
    fit_with_ransac(ppl)
 
#compute_rough_descriptor_test()
#compute_rough_descriptor_test()