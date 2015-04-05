# -*- coding: utf-8 -*-
"""
Created on Tue Jan 20 12:18:45 2015

@author: remi
"""

from plyfile import PlyData, PlyElement
import datetime ; 
import numpy as np;
import pandas as pd
import numexpr ;
import bottleneck;

file_path = '/media/sf_perso_PROJETS/sample_riegl_18_01.ply' ; 

begin = datetime.datetime.now() ; 
#load ply data 
plydata = PlyData.read(file_path) ; 

end_loading = datetime.datetime.now() ;
print "was laoding 3 million points in %s" % (end_loading-begin) ;

#creating a numpy array with all points and all dimensions
numpy_arr_tmp = plydata.elements[0].data 
numpy_arr =  numpy_arr_tmp[['x','y','z']]
np_floor = numpy_arr 


np_floor = np.floor(np.array( numpy_arr_tmp[['x','y','z']].tolist()))
 
#getting all dimension names :
index_name = [] ; 
for i in range(0,len(plydata.elements[0].properties)):
    index_name.append(plydata.elements[0].properties[i].name);

#grouping points into 1 m3 
#creating a data frame from data 
rounded_column_list = ('x_f','y_f','z_f') ; 
df = pd.DataFrame(np_floor,columns=('x_f','y_f','z_f'))
#df.reset_index(level=1, inplace=True ) #creating a column index 
#df.set_index(['x_f','y_f','z_f'], inplace=True)  #indexing the data frame with x,y,z
#end_df = datetime.datetime.now() ;
print "df creation %s" % (end_df-end_loading) ;
##sort and gruop by
#creating a function for the group by
df['x_f'][12]

#def floor_xyz(row):
#    return floor(row[0]),floor(row[1]),floor(row[2])

grouped = df.groupby(rounded_column_list)
#grouped = df.groupby(floor_xyz) #groupby

grouped.first()

end_grouped = datetime.datetime.now() ;
print "grouping %s" % (end_grouped-end_df) ;


i=0;
patch = []; 
for (x_f, y_f,z_f), group in grouped:
    #print x_f,y_f,z_f;
    #print type(group), group
    #print group.index.get_values()
    i += 1
    if i >3:
        break
    point_index = np.asarray(group.index.get_values())
    #print point_index
    patch.append(plydata.elements[0].data[point_index]) ;  
 
end_patch = datetime.datetime.now() ;
print "grouping %s" % (end_patch-end_grouped) ;


sorted_points = np.sort(patch[1], axis=0, kind='quicksort', order=('GPS_time'))
grouped.groups
first_group = grouped.first()
first_group.values 
first_group.reset_index(level=1, inplace=True,)
first_group.set_index(['GPS_time'], inplace=True) 
print first_group
sorted_points = np.sort(numpy_arr, axis=0, kind='quicksort', order=('x','y','z'))
sorted_points[['GPS_time','x','y','z']]; 


plydata.elements[0].properties._get_name()
type(len(plydata.elements[0].properties[0])


    


#############
# Trying to read and write wkb points and patch 

import psycopg2 
# Connect to an existing database
conn = psycopg2.connect("dbname=test_pointcloud user=postgres password=postgres port=5433") 
# Open a cursor to perform database operations
cur = conn.cursor()

# Execute a command: this creates a new table
cur.execute("""SELECT pc_uncompress(patch) FROM public.test_python_pointcloud;  """)

patch_hex = cur.fetchone() ; 

# Make the changes to the database persistent
conn.commit()

# Close communication with the database
cur.close()
conn.close()

patch_hex[0][0:5]
type(patch_hex[0])

import binascii
import struct ; 
binary_string = binascii.unhexlify(patch_hex[0])
binary_string[2:10]
type(patch_hex[0])
#first byte = 2 hex : 0 or 1  for endianness
#uint32 = 4 byte = 8 hex       pcid 
#uint32: = 4 byte = 8 hex       type of compression 

endianness = struct.unpack_from("b",binary_string, offset=0 )
pcid = struct.unpack_from("I",binary_string, offset=1)
compression = struct.unpack_from("I",binary_string, offset=1+4)
point = struct.unpack_from("iiiH",binary_string, offset=1+4+4+4)
y = np.frombuffer(binary_string, dtype = [('x',np.int32),('y',np.int32),('z',np.int32),('intensity',np.uint16)], offset=1+4+4+4)
#a point : int32_t, int32_t,int32_t,uint16_t

scales = np.array([0.01,0.01,0.01,1]);
offset = np.array([50,100,10,0.1]);

y[0][0]

y.size

numpy_double = np.zeros((3,4), dtype=float64)
for i in range(0,3):
    for j in range(0,4):
        numpy_double[i][j] = y[i][j]*scales[j]+offset[j]
 y*scales.T+offset
#reading the xml : 
import xml.etree.ElementTree as ET

schema = """<?xml version="1.0" encoding="UTF-8"?>
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

 
for child in root:
    print child.tag," ", child.attrib
    for child_2 in child:
        print "\t",child_2.tag, child_2.attrib
    
    
for neighbor in  root.findall('.*position.*'):
    print neighbor.tag, neighbor.attrib

for child in root.findall(".//dimension"):
    print child.tag ,  child.attrib
    print int(child.find('./position').text)
    print int(child.find('./size').text)
    
    tmp = child.find('./scale') 
    if tmp!= None :
        print float(tmp.text )
    
    tmp = child.find('./offset') 
    print tmp
    if tmp != None :
        print int(tmp.text ) 
    print  child.find('./interpretation').text 
    print  child.find('./description').text 
    print  child.find('./name').text
     
    



from xml.etree.ElementTree import XML, XMLParser, tostring, TreeBuilder

class StripNamespace(TreeBuilder):
    def start(self, tag, attrib):
        index = tag.find('}')
        if index != -1:
            tag = tag[index+1:]
        super(StripNamespace, self).start(tag, attrib)
    def end(self, tag):
        index = tag.find('}')
        if index != -1:
            tag = tag[index+1:]
        super(StripNamespace, self).end(tag)

target = StripNamespace()
parser = XMLParser(target=target) 
root = XML(schema, parser=parser)
print tostring(root)


#if beginning with u : unsigned int
#if beginning with int : int
#if beginning with float : float
#size is read from the 'size' attribute
#it can only be 1 (f8),2 (small int),4 (int, float),8 (float64,int64)








