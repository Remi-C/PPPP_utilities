# -*- coding: utf-8 -*-
"""
Created on Sat Apr 11 15:10:23 2015

@author: remi
"""

def creating_schema_and_patch_table(conn, cur):
    import psycopg2
     
    does_point_schema_exists = """SELECT pcid FROM pointcloud_formats WHERE pcid = 10"""
    
    cur.execute(does_point_schema_exists)    
    result_query = cur.fetchone() 
    schema_missing = result_query==None
    
    if schema_missing == True:
        point_schema_creation = """
    --creating the schema that will explain the points 
        
    
    INSERT INTO pointcloud_formats (pcid, srid, schema_name) VALUES (10, 931008,'Stereo_Point_cloud_Paris');--On crée un nouveau schema
			--Filling the entry
			UPDATE public.pointcloud_formats SET schema = 
			$$<?xml version="1.0" encoding="UTF-8"?>	<!-- Stereo Point cloud , offset for Paris -->
			<!--ply
			property float x
			property float y
			property float z
			property uchar red
			property uchar green
			property uchar blue
			end_header
			-->
			
			<pc:PointCloudSchema xmlns:pc="http://pointcloud.org/schemas/PC/1.1" 
			    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

			  <pc:dimension>
			    <pc:position>1</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>X coordinate, lambert 93</pc:description>
			    <pc:name>X</pc:name>
			    <pc:interpretation>int64_t</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>650000</pc:offset>
			  </pc:dimension>
			  
			  <pc:dimension>
			    <pc:position>2</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>Y coordinate, lambert 93</pc:description>
			    <pc:name>Y</pc:name>
			    <pc:interpretation>int64_t</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>6860000</pc:offset>
			  </pc:dimension>

			   <pc:dimension>
			    <pc:position>3</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>Z coordinate, lambert 93</pc:description>
			    <pc:name>Z</pc:name>
			    <pc:interpretation>int64_t</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			  
			  <pc:dimension>
			    <pc:position>4</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>red color</pc:description>
			    <pc:name>red</pc:name>
			    <pc:interpretation>uint8_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>
			
				
				<pc:dimension>
			    <pc:position>5</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>green color</pc:description>
			    <pc:name>green</pc:name>
			    <pc:interpretation>uint8_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
				</pc:dimension>
				
				<pc:dimension>
			    <pc:position>6</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>blue color</pc:description>
			    <pc:name>blue</pc:name>
			    <pc:interpretation>uint8_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
				</pc:dimension>

 
			  <pc:metadata>
			    <Metadata name="compression">dimensional</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>$$ 
			WHERE schema_name = 'Stereo_Point_cloud_Paris';
    """
        cur.execute(point_schema_creation)  
        conn.commit()
    #does the table exist?
    
    cur.execute("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = %s AND table_name = %s)",('trafi_pollu','goudron'))
    result_query = cur.fetchone()
    if result_query[0] == False:
        table_creation = """
        CREATE SCHEMA IF NOT EXISTS trafi_pollu ; 
        CREATE TABLE trafi_pollu.goudron
        (
          gid serial PRIMARY KEY,
          file_name text, 
          patch pcpatch(10) 
         ) ;
        """
        cur.execute(table_creation)
        conn.commit()


def find_all_ply_files(path_to_file):
    import os
    import fnmatch
    import re

    matches = []
    for root, dirnames, filenames in os.walk(path_to_file):
        for filename in fnmatch.filter(filenames, '*.ply'):
            matches.append(os.path.join(root, filename))
    
    return matches
    
def load_one_file((path_to_file,connection_string,pcid,writing_query,additional_offset,grouping_rules)):
    import ply_to_patch as ptp 
    return ptp.ply_to_patch(path_to_file,connection_string,pcid,writing_query,additional_offset,grouping_rules)
    
   
def load_points_clouds_files_into_base(path_to_file, num_processes):
    import psycopg2
    import numpy as np
    import multiprocessing as mp; 
    connection_string = """host=172.16.3.50 dbname=test_pointcloud user=postgres password=postgres port=5432""" 
    pcid = 10 
    writing_query = " INSERT INTO trafi_pollu.goudron (file_name, patch) VALUES (%s, %s::pcpatch(" + str(pcid) + ")) "
    additional_offset = np.array((650832.75,6860905.4,43,0,0,0), dtype = np.double) 
    grouping_rules = np.array((250.0,250.0,1.0)) 
    #connecting to database, 
    conn = psycopg2.connect(connection_string)
    cur = conn.cursor()
    
    creating_schema_and_patch_table(conn,cur)
    cur.close()
    conn.close() 
    
    point_file_paths  = find_all_ply_files(path_to_file)
    
    function_arg = [] 
    for path in point_file_paths:
        function_arg.append([path,connection_string,pcid,writing_query,additional_offset,grouping_rules])
    
    print function_arg  
    
    pool = mp.Pool(num_processes);
    results = pool.map(load_one_file, function_arg) 
    print results
    
#    for point_file_path in point_file_paths:
#        print point_file_path
#        load_one_file(point_file_path,connection_string,pcid,writing_query,additional_offset =additional_offset )
#        return 

    

def load_points_clouds_files_into_base_test():
    path_to_file = "/media/sf_USB_storage/DATA/Donnees_IGN/TrafiPollu/goudron_decoupe"
    num_processes = 1
    load_points_clouds_files_into_base(path_to_file, num_processes)


def only_loading_points_for_paris():
    import ply_to_patch as ptp
    import psycopg2
    import numpy as np
    import multiprocessing as mp; 
    import datetime 
    import datetime
    
    print 'starting to work',datetime.datetime.now()
    
    path_to_file = "/media/sf_USB_storage/DATA/Donnees_IGN/paris_20140616"
    num_processes = 1

    connection_string = """host=172.16.3.50 dbname=test_pointcloud user=postgres password=postgres port=5432""" 
    pcid = 6 
    writing_query = " INSERT INTO tmob_20140616.riegl_pcpatch_space_int_test (file_name, patch) VALUES (%s, %s::pcpatch(" + str(pcid) + ")) "
    additional_offset = np.array((0,0,0,0,0,0,0,650000,6860000,0,650000,6860000,0,0,0,0,0,0,0,0,0), dtype = np.double) 
    grouping_rules = np.array((1.0,1.0,1.0)) 
    #connecting to database,  
    point_file_paths  = find_all_ply_files(path_to_file)
    
    function_arg = [] 
    for path in point_file_paths:
        function_arg.append([path,connection_string,pcid,writing_query,additional_offset,grouping_rules])
    
    #print function_arg  
    
    pool = mp.Pool(num_processes);
    results = pool.map(load_one_file, function_arg) 
    
    print 'end of work',datetime.datetime.now()
    print results

#load_points_clouds_files_into_base_test()
#only_loading_points_for_paris()

#import ply_to_patch as ptp  
#path_to_file = "/media/sf_USB_storage/DATA/Donnees_IGN/TrafiPollu/goudron_decoupe/cloud_0.ply"
#connection_string = """host=localhost dbname=test_pointcloud user=postgres password=postgres port=5433""" 
#pcid = 10 
#writing_query = " INSERT INTO trafi_pollu.goudron (file_name, patch) VALUES (%s::pcpatch(" + str(pcid) + ")) "
#ptp.ply_to_patch(path_to_file,connection_string,pcid,writing_query)


import pg_pointcloud_classes as pgp ; schemas = {} ; connection_string = "host=172.16.3.50 dbname=test_pointcloud user=postgres password=postgres port=5432" ;print pgp.get_schema(6, schemas, connection_string)