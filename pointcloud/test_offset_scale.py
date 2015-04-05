# -*- coding: utf-8 -*-
"""
Created on Tue Mar 17 17:53:07 2015

@author: remi
"""

import pg_pointcloud_classes as pc

patch_text = """0104000000000000000A00000060AE0A00819E03002D07000060AE0A0090A803000E09000060AE0A0005990300040B000060AE0A00A69D0300F30B000060AE0A00499D0300180C000060AE0A00EAA803001A09000060AE0A00E9B20300390A000060AE0A00C5AD0300190A000060AE0A00DCBC03008410000060AE0A003FCF0300E3140000"""

connection_string = """host=172.16.3.50 dbname=vosges user=postgres password=postgres port=5432"""
global GD        
GD = {}

if 'rc' not in GD:  # creating the rc dict if necessary
    GD['rc'] = dict()
if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
    GD['rc']['schemas'] = dict()
  
np_points,(mschema,endianness, compression, npoints) = pc.patch_string_buff_to_numpy(patch_text, GD['rc']['schemas'], connection_string)

print np_points



pc.create_schemas_if_not_exists()

print GD['rc']['schemas']



import psycopg2 
# Connect to an existing database
conn = psycopg2.connect("dbname=test_pointcloud user=postgres password=postgres port=5433") 
# Open a cursor to perform database operations
cur = conn.cursor()

# Execute a command: this creates a new table

cur.execute("""INSERT INTO test_copy_python (patch) VALUES ( %s)""",())




