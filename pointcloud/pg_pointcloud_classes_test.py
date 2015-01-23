# -*- coding: utf-8 -*-
"""
Created on Fri Jan 23 11:52:53 2015

@author: remi
"""

import pg_pointcloud_classes as pc

#del GD['rc']['schemas']['1']

xml_schema = """

<?xml version="1.0" encoding="UTF-8"?>	<!-- RIEGL Laser schema -->
			<!-- ply header: 
				#We are really going ot use : 
					property double GPS_time
					property float x
					property float y
					property float z
					property float x_origin
					property float y_origin
					property float z_origin
					property float reflectance
					property float range
					property float theta
					property uint id
					property uint class
					property uchar num_echo
					property uchar nb_of_echo  
			-->
			
			<pc:PointCloudSchema xmlns:pc="http://pointcloud.org/schemas/PC/1.1" 
			    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			  <pc:dimension>
			    <pc:position>1</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>le temps GPS du moement de l acquisition du points. Note : il faudrait utiliser l offset et s assurer qu il n y a pas de decallage</pc:description>
			    <pc:name>GPS_time</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.000001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  
			 <!-- origine du senseur dans repere Lambert93 (modulo translation)-->
			 <pc:dimension>
			    <pc:position>2</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>Coordonnées X du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>x</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<!--<pc:offset>649000</pc:offset>-->
			  </pc:dimension>
			<pc:dimension>
			    <pc:position>3</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>Coordonnées Y du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>y</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<!--<pc:offset>6840000</pc:offset>-->
			  </pc:dimension>
			<pc:dimension>
			    <pc:position>4</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>Coordonnées Z du senseur dans le repere Lambert 93, en metre,</pc:description>
			    <pc:name>z</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  
			   <!-- origine du senseur dans repere global (lamb93 translaté)-->
			  <pc:dimension>
			    <pc:position>5</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>x_origin : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>x_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>6</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>y_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>y_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>7</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>z_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>z_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  
			  <pc:dimension>
			    <pc:position>8</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>l amplitude de l onde de retour corrigee de la distance, attention : peut etre faux lors de retour multiples, attention : impropre pour classification, la corriger par formule trouveepar remi cura</pc:description>
			    <pc:name>reflectance</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			     <pc:dimension>
			    <pc:position>9</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Valeur du temps de vol lors de lacquisition. de env 2.25 a + de 400, probablement en milli. Il faudrait determiner le scale proprement</pc:description>
			    <pc:name>range</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			 
			 <pc:dimension>
			    <pc:position>10</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>angle entre la direction d acquision et le plan horizontal, codeé entre -3 et +3 env. Il faudrait voir loffset</pc:description>
			    <pc:name>theta</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  
			 <pc:dimension>
			    <pc:position>11</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Une grandeur que je ne connais pas, entre -1 et plusieurs dizaine de milliers , par pas de 1</pc:description>
			    <pc:name>id</pc:name>
			    <pc:interpretation>uint32_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
				</pc:dimension>
			  
			  <pc:dimension>
			    <pc:position>12</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Une grandeur que je ne connais pas, entre -1 et plusieurs dizaine de milliers , par pas de 1</pc:description>
			    <pc:name>class</pc:name>
			    <pc:interpretation>uint32_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
				</pc:dimension>
			  
			    <!-- echo multiple-->

			    <pc:dimension>
			    <pc:position>13</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>le numero du retour dont ona tiré le point (entre 1 et 4)</pc:description>
			    <pc:name>num_echo</pc:name>
			    <pc:interpretation>uint8_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>14</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>le nombre d echos obtenu par le rayon quia  donné ce point </pc:description>
			    <pc:name>nb_of_echo</pc:name>
			    <pc:interpretation>uint8_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension> 
			  
			  
			  <pc:metadata>
			    <Metadata name="compression">dimensional</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>
			"""
   
schema = pc.pcschema()
print schema
schema.parsexml(xml_schema)
print schema