# -*- coding: utf-8 -*-
"""
Created on Sat Jan 30 14:01:09 2016

@author: Remi

reading an uncompressed patch, convert it to point,
order point following midoc ordering
reorder patch
return an uncompressed reordered patch
""" 
 
def reordering_patch_following_midoc_test( ):
    tot_level = 4
    stop_level = 3
    uncompressed_patch = "010100000000000000" +\
        "03000000B30200007D0200001C00000007001B020000DC030000E" +\
        "F0000000200EB020000E3010000A40200000300" 
    re = reordering_patch_following_midoc(uncompressed_patch, tot_level, stop_level, connection_string)
    print re
    
def reordering_patch_following_midoc(uncompressed_patch, tot_level, stop_level, connection_string):
    """ main function : reorder patch following midoc ordering"""
    import pg_pointcloud_classes as pgp
    import midoc_ordering as midoc
     
    
    ################# only for test
    temp_schema = dict()
    temp_schema["1"]= artificial_schema()
    #################
    
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
    numpy_double, mschema = pgp.patch_numpy_to_numpy_double(pt_arr[ restrict_dim], mschema,use_scale_offset=True,dim_to_use=restrict_dim)
     
    ######################
    # WARNING DEBUG
    # to be removed
    # numpy_double [:,0] = numpy_double [:,0] #+ 649000
    #numpy_double [:,1] = numpy_double [:,1] + 6840000
    ######################
      
    #keep only the relevant dimensions   
    pt_xyz = numpy_double
    num_points = npoints
    
    #compute midoc ordering 
    result = midoc.order_by_octree(pt_xyz, tot_level, stop_level)
    result_completed = midoc.complete_and_shuffle_result(result, num_points)
    pt_per_class = midoc.count_points_per_class(result, stop_level)
    #transfer ordering to full points 
    reordered_arr = pt_arr[result_completed[:,0].astype('int32')] 
    #create new patch
    
    wkb_ordered_patch = pgp.numpy_double_to_WKB_patch(reordered_arr, mschema)
    return wkb_ordered_patch, pt_per_class
    

def artificial_schema():
    xml_schema = """<?xml version="1.0" encoding="UTF-8"?>
            <pc:PointCloudSchema xmlns:pc="http://pointcloud.org/schemas/PC/1.1"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <pc:dimension>
                <pc:position>1</pc:position>
                <pc:size>4</pc:size>
                <pc:description>X coordinate as a long integer. You must use the
                        scale and offset information of the header to
                        determine the double value.</pc:description>
                <pc:name>X</pc:name>
                <pc:interpretation>int32_t</pc:interpretation>
                <pc:scale>0.01</pc:scale>
              </pc:dimension>
              <pc:dimension>
                <pc:position>2</pc:position>
                <pc:size>4</pc:size>
                <pc:description>Y coordinate as a long integer. You must use the
                        scale and offset information of the header to
                        determine the double value.</pc:description>
                <pc:name>Y</pc:name>
                <pc:interpretation>int32_t</pc:interpretation>
                <pc:scale>0.01</pc:scale>
              </pc:dimension>
              <pc:dimension>
                <pc:position>3</pc:position>
                <pc:size>4</pc:size>
                <pc:description>Z coordinate as a long integer. You must use the
                        scale and offset information of the header to
                        determine the double value.</pc:description>
                <pc:name>Z</pc:name>
                <pc:interpretation>int32_t</pc:interpretation>
                <pc:scale>0.01</pc:scale>
              </pc:dimension>
              <pc:dimension>
                <pc:position>4</pc:position>
                <pc:size>2</pc:size>
               <pc:description>The intensity value is the integer representation
                        of the pulse return magnitude. This value is optional
                        and system specific. However, it should always be
                        included if available.</pc:description>
                <pc:name>Intensity</pc:name>
                <pc:interpretation>uint16_t</pc:interpretation>
                <pc:scale>1</pc:scale>
              </pc:dimension>
              <pc:metadata>
                <Metadata name="compression">dimensional</Metadata>
              </pc:metadata>
            </pc:PointCloudSchema>
    """
    import pg_pointcloud_classes as pgp
    schema = pgp.pcschema()
    schema.parsexml(xml_schema)
    return schema
     

def connect_to_base():
    import psycopg2
    conn = psycopg2.connect(  
        database='test_pointcloud'
        ,user='postgres'
        ,password='postgres'
        ,host='172.16.3.50'
        ,port='5432' ) ; 
    cur = conn.cursor()
    return conn, cur ; 

def execute_querry(q,arg_list,conn,cur): 
    import psycopg2
    #print q % arg_list ;  
    cur.execute( q ,arg_list)
    conn.commit() 
    
def test_ordering_with_real_data():
    """ read a patch on the server and order it""" 
    import psycopg2
    import numpy as np
    conn, cur  =connect_to_base()  
    
    gid = 906855
    tot_level = 7
    stop_level = 7
    
    #print("connectin string : ", conn.dsn)
    connection_string = "dbname=test_pointcloud user=postgres password=postgres host=172.16.3.50 port=5432"
    q =  """
        SELECT pc_uncompress(patch)
        FROM acquisition_tmob_012013.riegl_pcpatch_space_proxy 
        ORDER BY gid ASC        
        OFFSET 100        
        LIMIT 1  
    """ ;
    arg_list = [gid] ; 
    execute_querry(q,arg_list,conn,cur) ;
    patch =  cur.fetchall() 
    
    import rc_patch_LOD as rcp
    wkb_ordered_patch, pt_per_class = rcp.reordering_patch_following_midoc(patch[0][0], tot_level, stop_level,connection_string)    
    #print("point per class : ", np.sum( pt_per_class))
    conn.close()
    
#test_ordering_with_real_data()