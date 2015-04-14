# -*- coding: utf-8 -*-
"""
Created on Sat Apr  4 18:19:12 2015

@author: remi
"""


from plyfile import PlyData, PlyElement
import datetime ; 
import numpy as np;
import pandas as pd
import numexpr ;
import bottleneck;

def writing_pgpatch_to_base(spec_array,schema,conn, cur, writing_query,file_name, schemas, additional_offset=None):
    """ this function writes pgpatch one by one in a given table"""
    import   pg_pointcloud_classes as pgp
    import psycopg2
    import sys
    import numpy as np

    connection_string = """host=localhost dbname=test_pointcloud user=postgres password=postgres port=5433"""
    
    #shitty move, casting back to numpy double should not be necessary ! 
    numpy_double, schema = pgp.patch_numpy_to_numpy_double(np.array(spec_array), schema,use_scale_offset=False)
    numpy_double = np.array(numpy_double)
    
    if additional_offset != None:
        numpy_double[:] += np.array(additional_offset)
        
    pgpatch = pgp.numpy_double_to_WKB_patch(np.array(numpy_double), schema)  
    cur.execute(writing_query,(file_name,pgpatch,) )
    
    conn.commit()
    #sys.exit("Error message")    
    
def making_pgpatch(numpy_spec_patch,connection_string,pcid,writing_query,file_name,additional_offset):
    """ this function takes an array of numpy spec array, and transform each into patch and send them to base"""
    import pg_pointcloud_classes as pgp
    import psycopg2
    
    pgp.create_GD_if_not_exists()
    schemas = pgp.create_schemas_if_not_exists()
    schema  = pgp.get_schema(pcid,schemas,connection_string)
    
    #conect to database
    conn = psycopg2.connect(connection_string)
    cur = conn.cursor()  
    
    for spec_array in numpy_spec_patch:
        writing_pgpatch_to_base(spec_array,schema,conn, cur, writing_query,file_name, schemas,additional_offset)
    print 'wrote ',spec_array.shape[0],' patches'
    return spec_array.shape[0]
    
def grouping_ply_data(plydata):
    """convert a parsed ply file into numpy array of patch"""
    import numpy as np
    
    #np_floor = np.floor(np.array( plydata.elements[0].data[['x','y','z']].tolist()))
    #creating a numpy array with all points and all dimensions
    numpy_arr =  plydata.elements[0].data[['x','y','z']]
    numpy_arr = numpy_arr.view(np.float32).reshape(numpy_arr.shape + (-1,))
    
    numpy_arr = numpy_arr[:]*np.array((250.0,250.0,1.0)) 
    np_floor = np.floor( numpy_arr)    
    
    rounded_column_list = ('x_f','y_f','z_f') ; 
    df = pd.DataFrame(np_floor,columns=rounded_column_list)
    
    #grouping the points 
    grouped = df.groupby(rounded_column_list)
    #fabricating an array of arrays of poiints
    patch = []
    for (x_f, y_f,z_f), group in grouped:
        
        point_index = np.asarray(group.index.get_values())
        patch.append(plydata.elements[0].data[point_index])
    return patch


def ply_to_patch(ply_file_path,connection_string,pcid,writing_query,additional_offset):
    """ This function read a ply file, group points into 1M3 patches, convert patches
    """
    from plyfile import PlyData
    plydata = PlyData.read(ply_file_path)
    numpy_spec_patch = grouping_ply_data(plydata)
    
    #to order the patch
    #sorted_points = np.sort(patch[1], axis=0, kind='quicksort', order=('GPS_time'))

    #send patch to database
    return making_pgpatch( numpy_spec_patch, connection_string, pcid, writing_query, ply_file_path, additional_offset)
    

def ply_to_patch_test():
    ply_file_path = '/media/sf_perso_PROJETS/TerMob2_LAMB93_000022.ply'
    connection_string = """host=localhost dbname=test_pointcloud user=postgres password=postgres port=5433"""
    pcid = 6
    writing_query = "INSERT INTO test_copy_python (patch) VALUES (%s::pcpatch(" + str(pcid) + ")) "
    print writing_query 
    ply_to_patch(ply_file_path,connection_string,pcid,writing_query)


#ply_to_patch_test()    


#import pg_pointcloud_classes as pgp
#import psycopg2
#connection_string = """host=localhost dbname=test_pointcloud user=postgres password=postgres port=5433"""
#writing_query = "INSERT INTO test_copy_python (patch) VALUES (%s::pcpatch(6)) "
#pcid = 6
#numpy_arr = np.array( ( ( 54212.6247039, 1520.2593994140625, 20694.22265625, -5.0588908195495605, 1891.431640625, 20929.576171875, 43.58432388305664, -4.8667426109313965, 442.18402099609375, -1.4219183921813965, 6L, 203000000L, 2, 2),) )
#
#
#pgp.create_GD_if_not_exists()
#schemas = pgp.create_schemas_if_not_exists()
#schema  = pgp.get_schema(pcid,schemas,connection_string)
#    
#
#pgpatch = pgp.numpy_double_to_WKB_patch(numpy_arr,schema)
#
#conn = psycopg2.connect(connection_string)
#cur = conn.cursor()
#
#cur.execute(writing_query,(pgpatch,) )
#
#conn.commit()
#cur.close()
#conn.close()
