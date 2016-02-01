# -*- coding: utf-8 -*-
"""
Created on Mon Feb 01 10:30:04 2016

@author: RCura
"""

import psycopg2

def connect_to_base():
    conn = psycopg2.connect(  
        database='vosges'
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
    
def order_patch_by_octree(conn,cur,ipatch, tot_level,stop_level,data_dim):
    import numpy as np;  
    import rc_patch_LOD as rcp
    connection_string = "dbname=vosges user=postgres password=postgres host=172.16.3.50 port=5432"
    
    wkb_ordered_patch, pt_per_class = rcp.reordering_patch_following_midoc(ipatch, tot_level, stop_level,connection_string)    
    #print("point per class : ", np.sum( pt_per_class))
    return wkb_ordered_patch, pt_per_class

def simple_order(gid, tot_level,stop_level,data_dim,conn,cur):
    import numpy as np
    import psycopg2   
    import rc_patch_LOD as rcp   
    q = """
        SELECT gid, pc_uncompress(patch) AS patch
        FROM lod.las_vosges_int_lod
        WHERE gid = %s
        """
    arg_list = [gid]
    execute_querry(q,arg_list,conn,cur)
    #print gid
    gid , patch =  cur.fetchall()[0]
    #opatch,ppl = order_patch_by_octree(conn,cur, patch, tot_level,stop_level,data_dim)
    #ppl = ppl.astype('int32').tolist()
    
    opatch = patch
    ppl = np.array([0,0,0,0,0]).astype('int32').tolist()  
    #print("ppl:",ppl) 
    q = """
        UPDATE lod.las_vosges_int_lod
            SET (patch_ordered, points_per_level_py) = (%s,%s)
        WHERE gid = %s;
        """
    arg_list = [opatch,ppl ,gid]
    execute_querry(q,arg_list,conn,cur)
    return gid 


def batch_LOD_multiprocess(processes,split_number,key_tot_start,key_tot_end,the_step): 
    """Main function, execute a given query in parallel on server"""
    import  multiprocessing as mp; 
    import random; 
    #splitting the start_end into split_number interval
    subintervals = split_interval_into_smaller_interval(split_number,key_tot_start,key_tot_end,the_step);
    #shuffle so that subintervals are in random order
    random.shuffle(subintervals); 
    #print subintervals
    #batch_LOD_monoprocess([1,100,1]);
    #return 
    #multiprocessing: 
    pool = mp.Pool(processes); 
    results = pool.map(batch_LOD_monoprocess, subintervals)
    return results
    
def split_interval_into_smaller_interval(split_number,key_tot_start,key_tot_end, the_step):
    """ simply takes a big interval and split it into small pieces. Warning, possible overlaps of 1 elements at the beginning/end"""
    import numpy as np    
    import math
    key_range = abs(key_tot_end-key_tot_start)/(split_number *1.0) 
    interval_to_process = [] ;
    for i,(proc) in enumerate(np.arange(1,split_number+1)):
        key_local_start = int(math.ceil(key_tot_start+i * key_range)) ;
        key_local_end = int(math.trunc(key_tot_start+(i+1) * key_range)); 
        interval_to_process.append([ key_local_start , key_local_end, the_step])        
        #batch_LOD_monoprocess(key_min,key_max,key_step):
    #print interval_to_process
    return interval_to_process 
   

def batch_LOD_monoprocess((key_min,key_max,key_step)): 
    """ this function connect to databse, and execute the querry on the specified gid range, step by step"""    
    tot_level = 8;
    stop_level = 6 ;
    data_dim = 3 ; 
    #connect to db
    conn,cur = connect_to_base(); 

    #setting the search path    
    #cur.execute("""SET search_path to vosges , public;"""); 
    #conn.commit(); 
    
    
    i = key_min; 
    while i <= key_max :
        simple_order(i, tot_level,stop_level,data_dim,conn,cur) ;
        i+=key_step ; 
        #if i %int(key_max/10.0-key_min/10.0) == 0 : 
        #    adv = round((1.0*i-key_min)/(key_max*1.0-key_min*1.0),2);
        #    print '\t %s: %s %s ' % (str(multiprocessing.current_process().name),' '*int(10*adv),str(adv))
    #print '\t %s' % str(multiprocessing.current_process().name) ; 
    cur.close()
    conn.close()
    
def batch_LOD_multiprocess_test():
    """ test of the main function, parameters adapted to IGN big server"""  
    
    import datetime ; 
    time_start = datetime.datetime.now(); 
    print 'starting : %s ' % (time_start); 
    
    key_tot_start=17856
    key_tot_end=18856 #599525 #6554548
    key_step = 1  
    processes = 14  
    split_number = 50 #100 #processes*20  
    # creating a table to hold results    

    
    batch_LOD_multiprocess(processes,split_number,key_tot_start,key_tot_end,key_step); 
    time_end = datetime.datetime.now(); 
    print 'ending : %s ' % (time_end); 
    print 'duration : %s ' % (time_end-time_start)

#dirty windows trick
def main():
    batch_LOD_multiprocess_test()
if __name__ == "__main__":
    main()
#import datetime
#time_start = datetime.datetime.now()
#batch_LOD_monoprocess((17856, 18856, 5))
#time_end = datetime.datetime.now()
#print('duration : %s ' % (time_end-time_start))


