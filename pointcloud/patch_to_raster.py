# -*- coding: utf-8 -*-
"""
Created on Fri Jan 23 16:38:01 2015

@author: remi
"""
import pg_pointcloud_classes as pc
reload(pc)

def translatePointArray(pt_arr, schema, pixel_size):
    """this function simply extract X,Y,Z and translate x and y and compute and allocate pixel array"""
    import numpy as np
    import math
    x_column_indice = schema.getNameIndex('X')
    y_column_indice = schema.getNameIndex('Y')
    z_column_indice = schema.getNameIndex('Z')
    pt_xyz = pt_arr[:, [x_column_indice, y_column_indice, z_column_indice]]
    #print pt_xyz.shape
    #find min max of x and y
    x_max = np.nanmax(pt_xyz[:, 0], axis=0)[0]
    x_min = np.nanmin(pt_xyz[:, 0], axis=0)[0]
    y_max = np.nanmax(pt_xyz[:, 1], axis=0)[0]
    y_min = np.nanmin(pt_xyz[:, 1], axis=0)[0]
    bottom_left = [x_min - (x_min % pixel_size), y_min - (y_min % pixel_size)]

    #print x_max,x_min,y_max,y_min
    #translate points
    #removing ceil(x_min, y_min)
    pt_xyz[:, 0] -= x_min - (x_min % pixel_size)
    pt_xyz[:, 1] -= y_min - (y_min % pixel_size)
    x_max -= x_min - (x_min % pixel_size)
    y_max -= y_min - (y_min % pixel_size)

    #print pt_xyz[:,[0,1]] / 0.04
    #find number of x_pixel, y_pixel
    #this is ceil(x_max/pixel_size)
    x_pix_number = math.ceil(x_max / pixel_size)
    y_pix_number = math.ceil(y_max / pixel_size)
    
    #print "pixel number on x :%s , y : %s" % (x_pix_number, y_pix_number)

    #create a numpy array out of this
    pixel_index_array = np.zeros([y_pix_number, x_pix_number], dtype=np.int)
    pixel_index_array = pixel_index_array * float('NaN')
    return pixel_index_array, pt_xyz, bottom_left

#del GD
def pointsToPixels(pixel_index_array, pt_xyz, pixel_size):
    """this function takes a list of points translated and assign the points index to a pixel array, depedning on 
Z"""
    #creating a temp Z buffer  and an accum buffer
    import numpy as  np
    import math
    z_buf = np.zeros(pixel_index_array.shape, dtype = double);
    z_buf = (z_buf+1) * float("inf")
    accum = np.zeros(pixel_index_array.shape, dtype = int32);
    
    #print z_buf
    for i in range(0, pt_xyz.shape[0]):
        #finding the pixel coordinates of this point floor(x/pixel_size)
        x_pixel_index = math.floor(pt_xyz[i,0]/pixel_size)
        y_pixel_index = math.floor(pt_xyz[i,1]/pixel_size)
        if pt_xyz[i,2] < z_buf[y_pixel_index,x_pixel_index]:
            accum[y_pixel_index,x_pixel_index] += 1
            z_buf[y_pixel_index,x_pixel_index] = pt_xyz[i,2]
            pixel_index_array[y_pixel_index,x_pixel_index] = i
    
    return pixel_index_array, accum

def onePointToBandsArray(one_point, dim_name_index_dictionnary):
    """this is a custom function that will indicates how to compute the bands"""
    import numpy as np 
    #print dim_name_index_dictionnary
    dnd = dim_name_index_dictionnary
    #for this application, we are interested in this :
    #z-z_origin , reflectance, echo_range, deviation, accum
 
    band_array = np.zeros(1,dtype = [
        ('relative_height',np.float32)
        ,('reflectance',np.float32)
        #,('echo_range',np.float32)
        #,('deviation',np.float32)
        ,('accumulation',np.uint16)
        ])
    band_array[0][0] = one_point[dnd['z']] - one_point[dnd['z_origin']]
    band_array[0][1] = one_point[dnd['reflectance']]
    #band_array[0][2] = one_point[dnd['echo_range']]
    #band_array[0][3] = one_point[dnd['deviation']]
    band_array[0][2] = one_point[dnd['accumulation']]
    return band_array


        
        

def print_matrix_band(matrix, band_name):
    """facility function to print one band of the matrix rperesenting the image"""
    import matplotlib
    import pylab as pl 

    #plt.imshow(pixel_index_array, origin='lower')
    plt.imshow(matrix[:][:][band_name], origin='lower', interpolation='none') # note : origin necessary to get the image in correct order


def constructing_image_matrix(pt_arr, pixel_index_array, accum, schema, onePointToBandsArray):
    """this functions takes the list of points, and the matrix of index,\
    and the function to compute band, and create and fill the final image matrix"""    
    import numpy.ma as ma
    import numpy as np
    
    nameIndex = schema.getNamesIndexesDictionnary()
    #modifying the nameInde to ad an 'accum' at the last position
    nameIndex['accumulation'] = pt_arr[0].shape
   
    #creating an augmented point with added attribute 'accum'
    augmented_point = np.append(pt_arr[0],accum[0,0] )
    test_band = onePointToBandsArray(augmented_point, nameIndex)
    #now we have the type of each dim of band
    
     #Now we construct the final array (3D), with in 3D the values we want to write in band.
    #getting the array type returned by the custom function
    image_matrix = np.zeros(pixel_index_array.shape , dtype = test_band.dtype)
    image_matrix = image_matrix.view(ma.MaskedArray)
    image_matrix.mask = True
    #setting the Nan value to min possible for int, or Nan for float
    
    
    #filling this matrix with actual values
    for x in range(0, image_matrix.shape[1]):
        for y in range(0, image_matrix.shape[0]):
            if np.isnan(pixel_index_array[y,x])==False:
                image_matrix[y,x] = onePointToBandsArray(\
                    np.append(pt_arr[pixel_index_array[y,x]], accum[y,x]) 
                    , nameIndex)
    #print_matrix_band(image_matrix,'reflectance')
    return image_matrix

def patchToNumpyMatrix(pt_arr, schema, pixel_size):
    """main function converting a double array representing points to a matrix representing a multiband image"""
    import numpy_to_gdal as n2g; 
    #prepare data stgructure for computing and prepare points
    pixel_index_array, pt_xy, bottom_left = translatePointArray(pt_arr, schema, pixel_size)
    #put points into pixel
    pixel_index_array, accum  = pointsToPixels(pixel_index_array, pt_xy, pixel_size) 
    
    
    image_matrix = constructing_image_matrix(pt_arr, pixel_index_array, accum, schema, onePointToBandsArray)
    #creating an object to store all meta data
    #band_name = 
    multi_band_image = n2g.numpy_multi_band_image()
    print ' srtext : %s ' % schema.srtext
    multi_band_image.setAttributes(\
        image_matrix, bottom_left, pixel_size, image_matrix[0, 0].dtype.names, schema.srtext)
    
    return multi_band_image

def testModule():
    import numpy as np
    import numpy_to_gdal as n2g
    reload(n2g)
    pixel_size = 0.04
    pt_arr, schema = getTestPoints()
    multi_band_image = patchToNumpyMatrix(pt_arr, schema, pixel_size) 
    print 'here is the array band %s' % multi_band_image.pixel_matrix[1,1]
    
    #using the conversion to gdal
    n2g.test_module(multi_band_image)

def getTestPoints():
    import psycopg2 as psy
    import pg_pointcloud_classes as pc 
    connection_string = """dbname=test_pointcloud user=postgres password=postgres port=5433"""
    if 'GD' not in globals():        
        global GD        
        GD = {}
    if 'rc' not in GD:  # creating the rc dict if necessary
        GD['rc'] = dict()
    if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
        GD['rc']['schemas'] = dict()
    #get a patch from base  
    conn = psy.connect(connection_string)  
    cur = conn.cursor()  
    cur.execute("""
    SELECT gid, pc_uncompress(patch)
    FROM --acquisition_tmob_012013.riegl_pcpatch_space 
    benchmark_cassette_2013.riegl_pcpatch_space  
    WHERE PC_NumPoints(patch) between 5000 and 10000
    LIMIT 1 
    """); 
    result = cur.fetchone()
    print 'patch found : %s'% result[0]
    b_patch = result[1]
    conn.commit()  
    cur.close()
    conn.close()
    #(pts_arr, (mschema,endianness, compression, npoints)) = pc.patch_string_buff_to_numpy(b_patch, GD['rc']['schemas'], connection_string)
    pts_arr, schema = pc.WKB_patch_to_numpy_double(b_patch, GD['rc']['schemas'], connection_string)   
    
    return pts_arr, schema

import pg_pointcloud_classes as pc
pc.create_GD_if_not_exists()
testModule()

