# -*- coding: utf-8 -*-
"""
Created on Mon Feb 01 10:30:04 2016

@author: RCura
"""

import psycopg2
 

#########################
#########################


import psycopg2

def connect_to_base():
    conn = psycopg2.connect(  
        database='test_pointcloud'
        ,user='postgres'
        ,password='postgres'
        ,host='172.16.3.50'
        ,port='5432' ) 
    cur = conn.cursor()
    return conn, cur  

def execute_querry(q,arg_list,conn,cur):  
    #print q % arg_list    
    cur.execute( q ,arg_list)
    conn.commit()
    
    
def get_list_of_job(limit):
    import numpy as np
    #connect to database
    conn, cur = connect_to_base()
    #get thelist of job
    q = """ SELECT gid 
        FROM lod.dim_descr_comparison
        WHERE points_per_level IS NOT NULL
        --AND gid = 908193
        ORDER BY gid ASC 
        LIMIT %s """ 
    execute_querry(q,[limit],conn,cur)
    gid = cur.fetchall() 
    gid = np.asarray(gid).T[0]
    cur.close()
    conn.close()
    return gid


def cut_list_into_chunk(gid, max_chunk_size):
    """ given a list , tries to cut it into smaller parts of max_chunk_size """
    import numpy as np
    import math
    result = []
    for i in np.arange(0,math.floor(gid.size/max_chunk_size)+1):
        key_local_start = int(math.ceil(i * max_chunk_size)) 
        key_local_end = int(math.trunc((i+1) * max_chunk_size))
        key_local_end = gid.size if key_local_end > gid.size else key_local_end
        extract = gid[np.arange(key_local_start,key_local_end)]
        if extract.size >0 :
            result.append(gid[np.arange(key_local_start,key_local_end)])
                
    return result 


def process_one_chunk( gid_extract  ):
    """ given a subset of the gid, do something with it"""    
    connection_string = "dbname=test_pointcloud user=postgres password=postgres host=172.16.3.50 port=5432"
    
    #create connection
    conn, cur = connect_to_base()
    #deal with the chunk
    for i in gid_extract:
        #print('i ',i)
        result = process_one_gid(i,conn, cur,connection_string)
    #close connection
    cur.close()
    conn.close()
    return result


def process_one_gid(one_gid, conn, cur, connection_string):
    """given one gid, process """ 
    import rc_patch_LOD as rcp
    import numpy as np
    #get data
    tot_level = 8
    stop_level = 6
    data_dim = 3
    
    q = """ SELECT pc_uncompress(patch) AS patch 
        FROM acquisition_tmob_012013.riegl_pcpatch_space 
        WHERE gid = %s   """
    arg_list = [one_gid.tolist()]
    execute_querry(q,arg_list,conn,cur)
    result =  cur.fetchall()[0]
    u_patch = result[0] 
    
    #process
    opatch,ppl = rcp.reordering_patch_following_midoc(u_patch, tot_level, stop_level, connection_string) 
    ppl = ppl.astype('int32').tolist() 
    opatch = u_patch  
    q = """
        UPDATE lod.dim_descr_comparison 
            SET ( points_per_level_py) = ( %s)
        WHERE gid = %s;
        """
    #arg_list = [opatch,ppl ,gid] 
    arg_list = [ ppl ,one_gid] 
    execute_querry(q,arg_list,conn,cur) 
    return True
 
    
    
def test_mono():
    import numpy as np
    max_chunk_size = 8
    overall_max = 8 
    
    gid = get_list_of_job(overall_max)
    #print("gid : ",gid)
    gid_sequenced = cut_list_into_chunk(np.asarray(gid), max_chunk_size)
    #print('gid_sequenced ',gid_sequenced)
    for i in gid_sequenced:
        process_one_chunk(i)



def multiprocess():
    import  multiprocessing as mp; 
    import random;  
    import numpy as np
    import datetime ; 
    
    time_start = datetime.datetime.now(); 
    print 'starting : %s ' % (time_start); 
    
    processes = 8
    max_chunk_size = 10
    overall_max = 25000
    
    gid = get_list_of_job(overall_max)
    
    #print("gid : ",gid)
    gid_sequenced = cut_list_into_chunk(np.asarray(gid), max_chunk_size) 
    random.shuffle(gid_sequenced)
    print 'job in line, ready to process : %s ' % (datetime.datetime.now()); 
    #print('gid_sequenced ',gid_sequenced) 
    pool = mp.Pool(processes)
    results = pool.map(process_one_chunk, gid_sequenced)
    time_end = datetime.datetime.now(); 
    print 'ending : %s ' % (time_end); 
    print 'duration : %s ' % (time_end-time_start)
    return results
    
#test_mono()


##dirty windows trick
def main():
    multiprocess()
if __name__ == "__main__":
    main()