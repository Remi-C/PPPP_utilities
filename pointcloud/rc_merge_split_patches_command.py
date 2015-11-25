# -*- coding: utf-8 -*-
"""
Created on Mon Nov 16 14:57:27 2015

@author: remi
"""

def connect_to_base():
    import psycopg2
    conn = psycopg2.connect(
    database='test_pointcloud'
    ,user='postgres'
    ,password='postgres'
    ,host='localhost'
    ,port='5433' ) 
    cur = conn.cursor()
    return conn, cur 

def split_merging_one():
    min_density = 400
    max_density = 10000    
    from datetime import datetime as d
    beg = d.now()
    conn,cur = connect_to_base() 
    cur.execute(
    """
    SET search_path to test_grouping , rc_lib, public ;  
    SET client_min_messages to  WARNING;
    """);
    conn.commit()  
    
    condition = 1
    while condition>=1:
        condition +=1 
        patch_id = get_patch_to_work_on(min_density, max_density, cur, conn)
        if patch_id is None:
            condition = 0
            break ; 
        else:
            r = split_merge_patch(patch_id, min_density, max_density,cur, conn)
            print(patch_id,' gid, ', r)
    cur.close()
    conn.close()
    print beg
    print d.now() - beg
    return condition

def get_patch_to_work_on( min_density, max_density, cur, conn,):
    """function that gets a patch that need to be split or merged"""

    # send query
    cur.execute(
    """
    SELECT gid
    FROM copy_bench AS cp
    WHERE (num_points < %s OR 
		num_points > %s)
      AND COALESCE(merged_split,-1) != 0 
      ORDER BY gid ASC 
    LIMIT 1
    """, (min_density, max_density))
    # retrieve result
    result = cur.fetchone()
    conn.commit()  
    return result

def split_merge_patch(patch_id, min_density, max_density, cur, conn):
    """given a patch id , tries to split/merge this patch"""
    cur.execute(
    """
    SELECT f.*
	FROM copy_bench , rc_adapt_patch_size(
		patch_id:= gid
		, min_density:=%s
		, max_density:=%s
		) AS f
	WHERE copy_bench.gid = %s
    """, (min_density, max_density, patch_id)
    )
    result = cur.fetchone()
    conn.commit()
    return result


def main():
    split_merging_one()

main()
    
    