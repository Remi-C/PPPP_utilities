# -*- coding: utf-8 -*-
"""
Created on Wed Apr 15 14:51:49 2015

@author: remi
"""


def exporting_pacth_from_server():
    from datetime import datetime 
    #loop on all patches id of a table
    import psycopg2
    import multiprocessing as mp; 
    connection_string = """host=172.16.3.50 dbname=vosges user=postgres password=postgres port=5432""" 
    num_processes  = 1
    output_folder = '/tmp'
    finding_file_names = """
    SELECT file_name FROM (
     SELECT  file_name, sum(num_points) as s
     FROM vosges_2011.las_vosges_int_proxy
     GROUP BY file_name
     ORDER BY s DESC, file_name ASC
     LIMIT 1
     ) as sub """    
    
    
    gid_query = """ 
    SELECT gid
    FROM vosges_2011.las_vosges_int_proxy
    WHERE file_name =%s
    -- LIMIT 10"""
    
    beginning = datetime.now()
    print beginning, 'starting the export process'
    conn = psycopg2.connect(connection_string)
    cur = conn.cursor() 
    cur.execute(finding_file_names)
    file_names_tmp = cur.fetchall()
    cur.close()
    conn.close() 
    
    file_names = [] 
    for f in file_names_tmp:
        file_names.append(f[0]) 
    
    function_arg = [] 
    for f in file_names:
        function_arg.append([f,connection_string, gid_query,output_folder])
    
        
        
    #pool = mp.Pool(num_processes) 
    #results = pool.map(export_one_file, function_arg) 
 
    #find files
    for file_name in file_names:
        export_one_file((file_name,connection_string, gid_query,output_folder))
    
    print datetime.now() , 'end of the export process'
    print 'duration ', datetime.now()-beginning
    return
        

def export_one_file((file_name,connection_string, gid_query,output_folder)):
    import os
    import psycopg2
    import pg_pointcloud_classes as pgp
    import os 
    from datetime import datetime
    pgp.create_GD_if_not_exists() 
    schemas = pgp.create_schemas_if_not_exists() 
    output_path = os.path.join(output_folder, file_name)
    f = open(output_path,'ab')
    print '\t ', datetime.now(), 'importing the file ',output_path
    
    #find all gid
    conn = psycopg2.connect(connection_string)
    cur = conn.cursor() 
    print '\t ', datetime.now(), 'getting gids of patches to export ' 
    cur.execute(gid_query, (file_name,))
    gids = cur.fetchall()   
    print '\t ', datetime.now(), 'exporting patches :total ' , len(gids)
    for (gid,) in gids:
        export_one_patch(gid, connection_string, conn,cur,schemas , f)
    #loop on all gid, 
        # export each patch 
    
    cur.close()
    conn.close() 
    print '\t ', datetime.now(), 'end of work on ',output_path, 'exported ',len(gids) , ' patches'
    return 

    
def export_one_patch(gid, connection_string, conn,cur,schemas,f ):
    """ """
    import pg_pointcloud_classes as pgp
    import numpy as np
    #get the patch
    patch_query = 'SELECT pc_uncompress(patch) FROM vosges_2011.las_vosges_int WHERE gid = %s'
    cur.execute(patch_query,(gid,))
    patch_tmp = cur.fetchall()
    
    #convert patch to numpy double     
    numpy_arr = pgp.patch_string_buff_to_numpy(patch_tmp[0][0],schemas,connection_string)
    np.save(f, np.array(numpy_arr))
    numpy_arr = None
    return
exporting_pacth_from_server()
