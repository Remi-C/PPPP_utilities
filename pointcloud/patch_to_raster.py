# -*- coding: utf-8 -*-
"""
Created on Fri Jan 23 16:38:01 2015

@author: remi
"""
import pg_pointcloud_classes as pc
reload(pc)

def testModule():
    import numpy as np
    pt_arr = getTestPoints()
    print  pt_arr[0]   ;
    
    #find min max
    #translate points
    #find number of x_pixel, y_pixel
    #create a numpy array out of this
    #use https://pcjericks.github.io/py-gdalogr-cookbook/raster_layers.html#create-raster-from-array
    #    
    

def getTestPoints():
    import psycopg2 as psy
    import pg_pointcloud_classes as pc
    connection_string = """dbname=test_pointcloud user=postgres password=postgres port=5433"""
    create_GD_if_not_exists()
    create_schemas_if_not_exists()
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
    pts_arr = WKB_patch_to_numpy_double(b_patch,  GD['rc']['schemas'], connection_string)   
    
    return pts_arr

testModule()

