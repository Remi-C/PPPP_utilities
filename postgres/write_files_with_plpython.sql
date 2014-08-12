 CREATE OR REPLACE FUNCTION write_file (param_bytes bytea, param_filepath text, chmod character varying (4))
RETURNS text
AS $$
import os
f = open(param_filepath, 'wb')
chmod_oct = int(chmod,8) # new addition (converts chmod octal code to associated integer value)
os.chmod(param_filepath,chmod_oct) # new addition (changes read/write permissions)
f.write(param_bytes)
f.close() # new addition (ensures file is closed after writing)
return param_filepath
$$ LANGUAGE plpythonu;

DROP FUNCTION IF EXISTS write_file_texte (param_bytes bytea, param_filepath text, chmod character varying (4));
 CREATE OR REPLACE FUNCTION write_file_texte (param_bytes text, param_filepath text, chmod character varying (4))
RETURNS text
AS $$
import os
f = open(param_filepath, 'w')
chmod_oct = int(chmod,8) # new addition (converts chmod octal code to associated integer value)
os.chmod(param_filepath,chmod_oct) # new addition (changes read/write permissions)
f.write(param_bytes)
f.close() # new addition (ensures file is closed after writing)
return param_filepath
$$ LANGUAGE plpythonu;


--Here’s an example of how to use this function:

SELECT write_file(ST_AsTIFF(ST_SetSRID(ST_Transform(rast,931008),931008)), '/tmp/rast_' || rid || '.tif','777')
FROM test_raster.temp_test_interpolation ;


-- SELECT *
-- FROM spatial_ref_sys
-- WHERE proj4text ILIKE '%LAMB93%'

 