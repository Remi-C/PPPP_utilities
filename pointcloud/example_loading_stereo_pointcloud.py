# -*- coding: utf-8 -*-
"""
Created on Sat Apr 11 15:10:23 2015

@author: remi
"""

def creating_schema_adn_patch_table():
    point_schema_creation = """
    --creating the schema that will explain the points 
    INSERT INTO pointcloud_formats (pcid, srid, nom_schema) VALUES (10, 931008,'Stereo_Point_cloud_Paris');--On crée un nouveau schema
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
    			WHERE nom_schema = 'Stereo_Point_cloud_Paris';
    """
    
    table_creation = """
    CREATE TABLE trafi_pollu.goudron
    (
      gid serial PRIMARY KEY,
      file_name text, 
      patch pcpatch(10) 
     ) ;
    """
    
    import psycopg2
    
    #connecting to database, 

path_to_file = "/media/sf_USB_storage/DATA/Donnees_IGN/TrafiPollu/goudron_decoupe"


import os
import fnmatch
import re

matches = []
for root, dirnames, filenames in os.walk(path_to_file):
    for filename in fnmatch.filter(filenames, '*.ply'):
        matches.append(os.path.join(root, filename))
        
for m in matches:
    print m

