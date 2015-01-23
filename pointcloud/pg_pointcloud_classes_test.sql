﻿





DROP FUNCTION IF EXISTS test_global_dict_python() ; 
CREATE FUNCTION test_global_dict_python()
RETURNS pcpatch
AS $$
import sys
sys.path.insert(0, '/media/sf_E_RemiCura/PROJETS/PPPP_utilities/pointcloud/') 
#del GD['rc']['schemas']['1'] 
# test on pcschema classe

#del GD['rc']['schemas']


if 'rc' not in GD:  # creating the rc dict if necessary
        GD['rc'] = dict()
if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
	GD['rc']['schemas'] = dict()

pcid = 6
npoints = 10

import pg_pointcloud_classes
reload(pg_pointcloud_classes)
#pg_pointcloud_classes.test_schema(GD['rc']['schemas'])
schem = pg_pointcloud_classes.get_schema(pcid, GD['rc']['schemas'],[])
import numpy as np
import random

random.seed(1)

points_double = np.zeros((npoints, schem.ndims), dtype=np.float64)
for i in range (0,npoints):
	for j in range(0,schem.ndims):
		points_double[i][j] = random.random()*10


wkb_patch = pg_pointcloud_classes.numpy_double_to_WKB_patch(
	points_double
	, pg_pointcloud_classes.get_schema(pcid, GD['rc']['schemas'], [])
	, pcid)

#plpy.notice(GD['rc']['schemas']) 
##testing the other way :
pcpatch = """0106000000000000000A000000D680ED709A8034410245A6FA75B0F4405DCDEE6397A5F240F57EC5C3B9E8D84063E9F148627ADB4890141F492B0C9A4723A66A44F62B3145080000000400000007004CF031FC7BFD5041452D3F0DA09DF140BE5A54370E57D6406E1DE61CF113F74037135C49F7FBEE46B9CBC6463F7D5347F7BD12466CE8144702000000040000000002B1B5EFFB3EB45041D3D7232CA735E84054504D7B1CC3D640D326A9DDA98BD64042A755486F6AE048B47E8D48874F06451EDF02466F5D59470600000001000000090853551A994372324128D6D897B03EE040739A580D479DF140EFFFDDD4F25CF140899F6449601BCE483BA54A4947EB8247F69A3D451086654708000000080000000505D2EEBF34A91215418528A7D47FB4D7409D59CCCBC677F34068293ACCEC3AE440DAF32848ECFB05490CA42B494BBC83477C306A452A782B4705000000070000000503518918CD29AE5241DA00B527FE1AA740269E14A2BAFCB0404FFC7D57232CF1403B097049FCD11049F62FC048D715854616F39C45D5CFBF470700000005000000080296A970284D99534132143CD2EB40F740A9FD8C626F36EC4000FEC78A256BE640EF7B8348C5C90549C5AB69496EBA0E446BE4F4454C40A04708000000070000000805244A75A9026A5541B4EFCC2C22CEE440CBC5A16A54ECB54035738F3F903DF540F5280B49DB2743480F72F648836C3D4765FE5E45CB2F0747050000000600000006046ABF045D17131141DF883E33206CD640021DA50E484ED140987957C9C289EC400E3552496FEE4249999A4249DE759F470C8F1F453E67A44706000000000000000000F65129F0C6D25C4160814F0BFB5ED840530CEB6D6E62C540127456AB0682EE40DC2CA848B0C5874762E21B480A024E47622ED244E336D54607000000040000000304"""

np_arr = pg_pointcloud_classes.WKB_patch_to_numpy_double(pcpatch, GD['rc']['schemas'], [])
plpy.notice(np_arr)


return wkb_patch 
$$ LANGUAGE plpythonu;


SELECT  test_global_dict_python() ;
 