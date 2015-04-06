# -*- coding: utf-8 -*-
"""
Created on Sun Apr  5 18:35:15 2015

@author: remi
"""


def patch_to_pcl(pgpatch, schemas, connection_string):
    import pcl
    import pg_pointcloud_classes as pgp
    import numpy as np

    #convert patch to numpy
    np_array,schema = pgp.WKB_patch_to_numpy_double(pgpatch, schemas,  connection_string)
    #np_points, (mschema,endianness, compression, npoints) = patch_string_buff_to_numpy(pgpatch, schemas, connection_string)
    x_column_indice = schema.getNameIndex('X')
    y_column_indice = schema.getNameIndex('Y')
    z_column_indice = schema.getNameIndex('Z')
    pt_xyz = np_array[:, (x_column_indice, y_column_indice, z_column_indice)]
    pt_xyz = pt_xyz.reshape(pt_xyz.shape[0], 3)
    #convert numpy to points
    p = pcl.PointCloud()
    p.from_array(pt_xyz.astype(np.float32))
    return p


def perform_1_ransac_segmentation(
    p
    , _ksearch
    , _search_radius
    , sac_model
    , _distance_weight
    , _max_iterations
    , _distance_threshold):
    """given a pointcloud, perform ransac segmetnation on it 
    :param p:  the point cloud
    :param _ksearch: number of neighboor considered for normal computation
    :param sac_model: the type of feature we are looking for. Can be pcl.SACMODEL_NORMAL_PLANE
    :param _distance_weight: between 0 and 1 . 0 make the filtering selective, 1 not selective
    :param _max_iterations: how many ransac iterations?
    :param _distance_threshold: how far can be a point from the feature to be considered in it?
    :return indices: the indices of the point in p that belongs to the feature
    :return model: the model of the feature
    """
    import pcl
    #prepare segmentation
    seg = p.make_segmenter_normals(ksearch=_ksearch, searchRadius=_search_radius)


    seg.set_optimize_coefficients(True)
    seg.set_model_type(sac_model)
    seg.set_normal_distance_weight(_distance_weight)  #Note : playing with this make the result more (0.5) or less(0.1) selective
    seg.set_method_type(pcl.SAC_RANSAC)
    seg.set_max_iterations(_max_iterations)
    seg.set_distance_threshold(_distance_threshold)
    #segment
    indices, model = seg.segment()

    return indices, model


def perform_N_ransac_segmentation(
    p
    , min_support_points
    , max_plane_number
    , _ksearch
    , _search_radius
    , sac_model
    , _distance_weight
    , _max_iterations
    , _distance_threshold):
    """given a pointcloud, perform ransac segmetnation on it 
    :param p:  the point cloud
    :param min_support_points: minimal number of points that should compose the feature 
    :param max_plane_number: maximum number of feature we want to find
    :param _ksearch: number of neighboor considered for normal computation
    :param sac_model: the type of feature we are looking for. Can be pcl.SACMODEL_NORMAL_PLANE
    :param _distance_weight: between 0 and 1 . 0 make the filtering selective, 1 not selective
    :param _max_iterations: how many ransac iterations?
    :param _distance_threshold: how far can be a point from the feature to be considered in it?
    :return indices: the indices of the point in p that belongs to the feature
    :return model: the model of the feature
    """
    import numpy as np
    index_array = np.arange(0, p.size, 1)
    #creating an array with original indexes
    #preparing loop
    i= 0
    result = list() 
    indices = [0] * (min_support_points + 1)
    
    #looking for feature recursively
    while ((len(indices) >= min_support_points)
        & (i <= max_plane_number)
        & (p.size >= min_support_points)): 
        indices, model = perform_1_ransac_segmentation( p , _ksearch , _search_radius
            , sac_model
            , _distance_weight , _max_iterations , _distance_threshold)
    
        #writting result if it it satisfaying
        if(len(indices) >= min_support_points):
             result.append(   ((index_array[indices] + 1 ), model,sac_model) ) 
             #should be # indices, model = seg.segment() 
            
            #prepare next iteration
        index_array = np.delete(index_array , indices)
        i += 1
        p =  p.extract(indices, negative=True)
        #removing from the cloud the points already used for this plan
    return (result), p


def patch_to_pcl_test():
    import pg_pointcloud_classes as pgp
    pgpatch = """0106000000000000000200000000005960695029420000E8EE4A4E724100007093B05FA94100002006B0131B41D6F7344DBFB7FD4E381B774A00F9F0C70063AE466776884625010000C088190C01010080E6BB695029420000C8F3514E7241000020B2B45FA941000040067C091B41BDF7344DE9B7FD4E501C774A80BD02C8006AAE46E835884625010000C088190C0101"""
    connection_string = """host=localhost dbname=test_pointcloud user=postgres password=postgres port=5433"""
    GD = pgp.create_GD_if_not_exists()
    pgp.create_schemas_if_not_exists()
    return patch_to_pcl(pgpatch, GD['rc']['schemas'], connection_string)


def perform_N_ransac_segmentation_test():
    import pcl
    
    p = patch_to_pcl_test()
    min_support_points = 10
    max_plane_number = 10
    _ksearch = 10
    _search_radius = 0.1
    sac_model = pcl.SACMODEL_NORMAL_PLANE
    _distance_weight = 1
    _max_iterations = 100
    _distance_threshold = 0.01
    (result), p = perform_N_ransac_segmentation(p
        , min_support_points
        , max_plane_number
        , _ksearch
        , _search_radius
        , sac_model
        , _distance_weight
        , _max_iterations
        , _distance_threshold) 
    print result
    
perform_N_ransac_segmentation_test()




