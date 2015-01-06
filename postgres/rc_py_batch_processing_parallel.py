# -*- coding: utf-8 -*-
"""
Spyder Editor

this script allow to lauch sql query the parallel <ay cutting the data set into slides
we exploit a pkey gid, int, ideally serial
"""


import psycopg2

import  multiprocessing as mp; 
import time;  
import random; 
from random import shuffle

  
  
def execute_querry_features(cur, i,j):
    """ this function should execute the querry on the range of gid proposed """
    q = """
    
    
    
    UPDATE las_vosges_proxy as rps
    SET (avg_height, avg_Z,avg_intensity, avg_tot_return_number) = 
    	(patch_height,z_avg,intensity_avg,tot_return_number_avg )
	FROM (
         SELECT gid,COALESCE( round(PC_PatchMax(patch, 'Z')-PC_PatchMin(patch, 'Z'),3),0) AS patch_height  
    		,COALESCE( round(PC_PatchAvg(patch, 'Z'),3),0 ) AS z_avg
    		,  COALESCE( round(PC_PatchAvg(patch, 'intensity'),3),0 ) AS intensity_avg
    		,  COALESCE( round(PC_PatchAvg(patch, 'tot_return_number') ,3),0) AS tot_return_number_avg
    	FROM las_vosges 
    	WHERE gid BETWEEN %s AND %s
         ) AS sub
	WHERE  sub.gid = rps.gid 
    """ ;
    print q % (i,j) ;  
    cur.execute( q ,( i, j))
  

 
def execute_querry_LOD(cur, i,j):
    """ this function should execute the querry on the range of gid proposed """
    q = """
    UPDATE  vosges_2011.las_vosges as rps
	SET (patch,points_per_level) = ( nv.opatch, nv.points_per_level)
	FROM  (
		SELECT p.gid, r.opatch, r.points_per_level
		FROM vosges_2011.las_vosges as p 
			,rc_order_octree( p.patch , 8) as r  
		WHERE gid  BETWEEN %s AND %s  
        AND p.points_per_level IS NULL
		) as nv
		WHERE nv.gid  = rps.gid ; 
    """ ;
    #print q % (i,j) ;  
    cur.execute( q ,( i, j))
     
#execute query  
     
     

def batch_LOD_monoprocess((key_min,key_max,key_step)): 
    """ this function connect to databse, and execute the querry on the specified gid range, step by step"""    
    #connect to db
    conn = psycopg2.connect(  
        database='vosges'
        ,user='postgres'
        ,password='postgres'
        ,host='172.16.3.50'
        ,port='5432' ) ; 
    cur = conn.cursor()

    #setting the search path    
    cur.execute("""SET search_path to vosges_2011,ocs, public;"""); 
    conn.commit(); 
     
    i = key_min; 
    while i < key_max :
        #print i;
        #print i, i+key_step;
        execute_querry_features(cur, i,i+key_step)
        conn.commit() 
        i+=key_step+1 ; 
        print  (1.0*i-key_min)/(key_max*1.0-key_min*1.0)
    cur.close()
    conn.close()
 
 
def batch_LOD_monoprocess_test( ):
    """utility debug function"""
    key_min= 10000
    key_max = 10010
    key_step = 2
    batch_LOD_monoprocess(key_min,key_max,key_step) ;

#batch_LOD_monoprocess_test();

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
    print interval_to_process
    return interval_to_process
    

def batch_LOD_multiprocess(processes,split_number,key_tot_start,key_tot_end,the_step): 
    """Main function, execute a given query in parallel on server"""
    #splitting the start_end into split_number interval
    subintervals = split_interval_into_smaller_interval(split_number,key_tot_start,key_tot_end,the_step);
    #shuffle so that subintervals are in random order
    shuffle(subintervals); 
    
    #multiprocessing: 
    pool = mp.Pool(processes); 
    results = pool.map(batch_LOD_monoprocess, subintervals)
    return results

def batch_LOD_multiprocess_test():
    """ test of the main function, parameters adapted to IGN big server"""
    split_number = 8; 
    key_tot_start=8736
    key_tot_end= 590264
    key_step = 100 ;
    processes = 12 ;
    
    batch_LOD_multiprocess(processes,split_number,key_tot_start,key_tot_end,key_step); 
    
        
import datetime
initial_time = datetime.datetime.now()
batch_LOD_multiprocess_test();
end_time = datetime.datetime.now() ;
print 'begin : ',initial_time,' end : ',end_time;

  
 