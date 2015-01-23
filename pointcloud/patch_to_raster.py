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

    print x_max,x_min,y_max,y_min
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
    
    print "pixel number on x :%s , y : %s" % (x_pix_number, y_pix_number)

    #create a numpy array out of this
    pixel_index_array = np.zeros([y_pix_number, x_pix_number], dtype=np.int)
    pixel_index_array = pixel_index_array * float('NaN')
    return pixel_index_array, pt_xyz


def pointsToPixels(pixel_index_array, pt_xyz, pixel_size):
    """this function takes a list of points translated and assign the points index to a pixel array, depedning on 
Z"""
    #creating a temp Z buffer :
    import numpy as  np
    import math
    z_buf = np.zeros(pixel_index_array.shape, dtype = double);
    z_buf = (z_buf+1) * float("inf")
    print z_buf
    for i in range(0, pt_xyz.shape[0]):
        #finding the pixel coordinates of this point floor(x/pixel_size)
        x_pixel_index = math.floor(pt_xyz[i,0]/pixel_size)
        y_pixel_index = math.floor(pt_xyz[i,1]/pixel_size)
        if pt_xyz[i,2] < z_buf[y_pixel_index,x_pixel_index]:
            z_buf[y_pixel_index,x_pixel_index] = pt_xyz[i,2]
            pixel_index_array[y_pixel_index,x_pixel_index] = i
    
    return pixel_index_array


def testModule():
    import numpy as np
    pixel_size = 0.04
    pt_arr, schema = getTestPoints()
    
    pixel_index_array, pt_xy = translatePointArray(pt_arr, schema, pixel_size)
    
    pixel_index_array = pointsToPixels(pixel_index_array, pt_xy, pixel_size)
    print pixel_index_array
    import matplotlib;
    import pylab as pl 
    
    plt.imshow(pixel_index_array)
    
    #use https://pcjericks.github.io/py-gdalogr-cookbook/raster_layers.html#create-raster-from-array
    #    
    

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
    SELECT pc_uncompress(patch)
    FROM acquisition_tmob_012013.riegl_pcpatch_space   
    WHERE PC_NumPoints(patch) between 1000 and 1200
    LIMIT 1 
    """);  
    b_patch = cur.fetchone()[0]
    conn.commit()  
    cur.close()
    conn.close()
    #(pts_arr, (mschema,endianness, compression, npoints)) = pc.patch_string_buff_to_numpy(b_patch, GD['rc']['schemas'], connection_string)
    pts_arr, schema = pc.WKB_patch_to_numpy_double(b_patch, GD['rc']['schemas'], connection_string)   
    
    return pts_arr, schema

import pg_pointcloud_classes as pc
pc.create_GD_if_not_exists()
testModule()

