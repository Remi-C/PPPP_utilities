# -*- coding: utf-8 -*-
"""
Created on Wed Jan 21 15:44:26 2015

@author: remi
"""
GD = {}
from xml.etree.ElementTree import TreeBuilder


class pcdimension:
    """ a simple class to store an equivalent to C PCSCHEMA struct
    name; name of the dimension (attribute)
    description; a description of the dimension
    position; the position in the dimension array
    interpretation; text explaining how the data should be read from binary
    scale; the real data will be otbained by multiplying stored data by scale
    offset; the real data will be otbained by adding stored data by offset
   """
    def __init__(self):
        """Constructor, define also the attribute"""
        self.name = ""
        self.description = ""
        self.position = 0
        self.interpretation = ""
        self.scale = 0
        self.offset = 0

    def __repr__(self):
        return "name : %s\n, decription : %s\n , position : %s\n, interpretation : %s\n, scale : %s\n, offset : %s \n" %\
        (self.name, self.description, self.position, self.interpretation, self.scale, self.offset)

    def __str__(self):
        return "name : %s\n, decription : %s \n, position : %s\n, interpretation : %s\n, scale : %s\n, offset : %s \n" %\
        (self.name, self.description, self.position, self.interpretation, self.scale, self.offset)

    def parse_xml(self, dim):
        """this function uses a pointer one an element tree node representing a dimension
        to fill its parameters """
        #import xml.etree.ElementTree as ET
        #mandatory : missing values will send an error

        self.position = int(dim.find('./position').text)
        self.size = int(dim.find('./size').text)
        self.name = str(dim.find('./name').text)
        self.interpretation = str(dim.find('./interpretation').text)

        #optionnal; if absent, put default parameter
        tmp = dim.find('./scale')
        if tmp != None:
            self.scale = float(tmp.text)
        else:
            self.scale = float(0.0)
        tmp = dim.find('./offset')
        if tmp != None:
            self.offset = int(tmp.text)
        else:
            self.offset = int(0)

        tmp = dim.find('./description')
        if tmp != None:
            self.description = str(tmp.text)
        else:
            self.description = str("No description")


class pcschema:
    """ a simple class to store an equivalent to C PCSCHEMA struct
    pcid;        /* Unique ID for schema */
    ndims;       /* How many dimensions does this schema have? */
    pcdimension[] dims;   /* Array of dimension */
    srid;        /* Foreign key reference to SPATIAL_REF_SYS */
     namehash;  /*array of dimension name */"""
    def __init__(self):
        """Constructor, define also the attribute"""
        self.pcid = 0
        self.ndims = 0
        self.dims = []
        self.srid = 0
        self.namehash = []
        self.numpy_dtype = []
        self.srid = 0
        self.srtext = None

    def __repr__(self):
        return " pcid : %s \n, ndims : %s\n, \n\t dims: %s \n, srid : %s\n, namehash:%s\n, numpy_dtype:%s\n"\
            % (self.pcid, self.ndims, self.dims, self.srid, self.namehash, self.numpy_dtype)

    def __str__(self):
        return " pcid : %s \n, ndims : %s\n, \n\t dims: %s \n, srid : %s\n, namehash:%s\n, numpy_dtype:%s\n"\
            % (self.pcid, self.ndims, self.dims, self.srid, self.namehash, self.numpy_dtype)

    def getNameIndex(self,name):
        """This function loop trough dimension and return the dim number where the dim is"""
        return [i for i,x in enumerate(self.namehash) if x.upper() ==  name.upper()]

    
    def getNamesIndexesDictionnary(self):
        """this function output a dictionnary associatingthe index number to each name"""
        namesIndexesDict = {}        
        for i, dim in enumerate(self.dims):
            namesIndexesDict[dim.name] = i
        return namesIndexesDict

    def parsexml(self, xml_schema):
        """parse the input wml string and fill schema class member with it"""
        #import xml.etree.ElementTree as ET
        xml_schema = xml_schema.lstrip().encode("utf-8")
        root = parse_no_namespace(xml_schema)
        self.ndims = len(root.findall(".//dimension"))

        #creating the dims
        for i in range(0, self.ndims):
            self.dims.append(pcdimension())

        for dim in root.findall(".//dimension"):
            position = int(dim.find('./position').text)
            self.dims[position - 1].parse_xml(dim)

        for dim in self.dims:
            self.namehash.append(dim.name)
        self.construct_dtype()

    def construct_dtype(self):
        """loop trough dims to construct the corersponding numpy dtype"""
        for dim in self.dims:
            self.numpy_dtype.append((dim.name, interpretation_ctype().interpretation[dim.interpretation]))

    def construct_scales_offset(self):
        """construct a numpy array with the scale for each dimension"""
        import numpy as np
        scales = np.zeros(self.ndims, dtype=np.float64)
        offsets = np.zeros(self.ndims, dtype=np.float64)
        for i, (dim) in enumerate(self.dims):
            scales[i] = dim.scale if (dim.scale != None and dim.scale != 0) else 1
            offsets[i] = dim.offset if dim.offset != None else 0
        return scales, offsets


class interpretation_ctype:
    """this class is a copy of C class that list understood formats"""
    import numpy as np
    interpretation = {'int8_t': np.int8, 'uint8_t': np.uint8,\
    'int16_t': np.int16, 'uint16_t': np.uint16,\
    'int32_t': np.int32, 'uint32_t': np.uint32,\
    'int64_t': np.int64, 'uint64_t': np.uint64,\
    'double': np.float64, 'float': np.float32,\
    'float64': np.float64, 'float32' : np.float32 }


class StripNamespace(TreeBuilder):
    """ Found on internet, remove the annoying trailing namespace
    from xml node name """
    #from xml.etree.ElementTree import XML, XMLParser, tostring

    def start(self, tag, attrib):
        index = tag.find('}')
        if index != -1:
            tag = tag[index + 1:]
        super(StripNamespace, self).start(tag, attrib)

    def end(self, tag):
        index = tag.find('}')
        if index != -1:
            tag = tag[index + 1:]
        super(StripNamespace, self).end(tag)


def parse_no_namespace(xml):
    """given a valid xml string, parse it and return the root of the xml tree"""
    from xml.etree.ElementTree import XML, XMLParser
    target = StripNamespace()
    parser = XMLParser(target=target)
    return XML(xml, parser=parser)


def patch_string_buff_to_numpy(string_buf, schemas, connection_string):
    """convert the output of psycopg of a pcpatch to a numpy array"""
    import binascii
    import numpy as np
    import struct
    #convert the string to hex
    binary_string = binascii.unhexlify(string_buf)

    #understanding the first 4 informations contained in patch binary:
    #endianness, pcid, compression, npoints
    (endianness,pcid,compression,npoints) = struct.unpack_from("=BIII",binary_string, offset=0 )  
    #getting the schema corresponding to the pcid
    mschema = get_schema(pcid, schemas, connection_string) 
    return np.frombuffer(binary_string, dtype=mschema.numpy_dtype, offset=1 + 4 + 4 + 4) ,  (mschema,endianness, compression, npoints) 


def patch_numpy_to_numpy_double(numpy_spec_dtype, mschema,use_scale_offset=True):
    """convert an input numpy point array with custom dtype to numpy with double[] dtype"""
    """ @FIXME : using a double loop is very lame, could be done with pure numpy"""
    import numpy as np
    #create result
    points_double = np.zeros((numpy_spec_dtype.shape[0], mschema.ndims), dtype=np.float64)
    
    if use_scale_offset == True: 
        #getting offset and scales
        scales, offsets = mschema.construct_scales_offset()
        #print scales, offsets
        #filling it
        for i in range(0, numpy_spec_dtype.shape[0]):
            for j in range(0, mschema.ndims):
                points_double[i][j] = numpy_spec_dtype[i][j] * scales[j] + offsets[j]

           
    if use_scale_offset == False: 
        for i in range(0, numpy_spec_dtype.shape[0]):
            for j in range(0, mschema.ndims):
                points_double[i][j] = numpy_spec_dtype[i][j]
    
    return points_double, mschema


def WKB_patch_to_numpy_double(binary_patch_text, schemas, connection_string):
    """This function uses as input a binary representation of the patch
    and convert it to a 2D numpy double array
    """
    np_points, (mschema,endianness, compression, npoints) = patch_string_buff_to_numpy(binary_patch_text, schemas, connection_string)
    return patch_numpy_to_numpy_double(np_points, mschema)


def numpy_double_to_numpy_spec(numpy_double_array_2D, mschema):
    """This function creates a specialized numpy array adapted to point type out of generic numpy double array
    @param numpy_double_array_2D: a numpy 2D double array with columns = attributes and row = each point
    @param mschema : the schema of points of this patch
    """
    #creating a specilaized numpy array:
    import numpy as np
    numpy_spec = np.zeros(numpy_double_array_2D.shape[0],\
        dtype=mschema.numpy_dtype)
    scales, offsets = mschema.construct_scales_offset()
    for i in range(0, numpy_double_array_2D.shape[0]):
        for j in range(0, mschema.ndims):
            numpy_spec[i][j] = (numpy_double_array_2D[i][j] - offsets[j])\
            / np.float(scales[j])
    return numpy_spec


def numpy_spec_to_patch(numpy_spec_array, mschema):
    """This function convert a specialized numpy array (with custom dtype) into a pcpatch
    the return is a string representing hex content that can be casted to pcpatch in database
    """
    import struct
    import binascii
    import ctypes
    #creating the header of uncompressed patch
    s = struct.Struct('=bIII')
    values = [1, mschema.pcid, 0, numpy_spec_array.shape[0]]
    #endianness, pcid, compression=0,num_points
    b = ctypes.create_string_buffer(s.size)
    s.pack_into(b, 0, *values)
    hex_begin = binascii.hexlify(b.raw)
    #converting numpy array to hex
    points_hex = binascii.hexlify(numpy_spec_array.data)
    return hex_begin + points_hex


def numpy_double_to_WKB_patch(numpy_double_patch, mschema):
    """This function uses as input a 2D numpy double array,
    and convert it to a text representing the patch as WKB
    """
    import numpy as np
    numpy_spec = numpy_double_to_numpy_spec(numpy_double_patch, mschema)
    np.set_printoptions(precision=16)
    #print 'numpy_spec from double' , numpy_spec
    return numpy_spec_to_patch(numpy_spec, mschema)


def create_GD_if_not_exists():
    """this function construct a Global Dictionnary if it doesn't exist"""
    if 'GD' not in globals():
    #we are not executing in postgres, we need to emulate postgres global dict 
        global GD        
        GD = {}
    return GD  


def create_schemas_if_not_exists():
    """this function a rc dictionnary in GD and a schema dictionnary in rc if necessary"""
    if 'rc' not in GD:  # creating the rc dict if necessary
        GD['rc'] = dict()
    if 'schemas' not in GD['rc']:  # creating the schemas dict if necessary
        GD['rc']['schemas'] = dict()
    
    return GD['rc']['schemas']

def executing_from_postgres():
    """this function returns True or False depending if it is executed from within postgres"""
    from_within_postgres = True
    try:
        plpy.quote_ident('titi')
    except NameError:
        from_within_postgres = False
    return from_within_postgres


def get_schema(pcid, schemas, connection_string):
    """this function returns a pcschema object, either taking it from GD
    or taking it from within database, or taking it from outside database"""
    #create_GD_if_not_exists()
    #create_schemas_if_not_exists()

    #trying to get the schema from GD
    if str(pcid) in schemas:
        print "schema %s was in global dictionnary GD\n" % pcid
        return schemas[str(pcid)]
        #if we get it, stop there

    #are we inside or outside the database (plpython or python)
    try:
        import plpy
        executing_in_postgres = True
    except ImportError:
        executing_in_postgres = False

    if executing_in_postgres == True:
        #use DBAPI to get the schema with given pcid
        print "getting the schema of pcid : %s from within database (DBAPI)\n" % pcid
        plpy.notice("getting the schema of pcid : "+str(pcid)+" from within database (DBAPI)\n")
        query = """SELECT pf.srid, pf.schema, srs.srtext
            FROM pointcloud_formats as pf 
                LEFT OUTER JOIN public.spatial_ref_sys AS srs ON (srs.srid = pf.srid)
            WHERE pcid = %d""" % pcid 
        result_query = plpy.execute(query, 1)  
        schema_xml = (result_query[0]['schema']).encode('utf-8')
        srid = int(result_query[0]['srid'])
        srtext = result_query[0]['srtext']
    else:
        #use psycopg2 api to get the schema
        import psycopg2
        print "getting the schema of pcid : %s from outside database (PSYCOPG2)\n" % pcid
        conn = psycopg2.connect(connection_string)
        conn.set_client_encoding('utf-8')
        cur = conn.cursor() 
        cur.execute("""SELECT pf.srid, convert_to(pf.schema,'UTF8') as schema, srs.srtext
            FROM pointcloud_formats as pf 
                LEFT OUTER JOIN public.spatial_ref_sys AS srs ON (srs.srid = pf.srid)
            WHERE pcid = %s""", [pcid])
        result_query = cur.fetchone()
        print result_query[1]
        result_query[1] = result_query[1].encode('utf-8')
        schema_xml = (result_query[1]).encode('utf-8')
        srid = int(result_query[0])
        srtext = result_query[2]
        conn.commit()
        cur.close()
        conn.close()

    #both case : create a pcpschema, store it
    pc_schema = pcschema()
    pc_schema.parsexml(schema_xml)
    pc_schema.pcid = pcid
    pc_schema.srid = srid
    pc_schema.srtext = srtext
    schemas[str(pcid)] = pc_schema

    return pc_schema


def test_schema(schemas, connection_string):
    """this function simply test class creation from xml with the most classical schema example  """
    xml_schema = """<?xml version="1.0" encoding="UTF-8"?>
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
    #schema = pcschema()
    #schema.parsexml(xml_schema)
    #print schema
    #print interpretation_ctype.interpretation[schema.dims[0].interpretation]

    patch_text = "010100000000000000" +\
        "03000000B30200007D0200001C00000007001B020000DC030000E" +\
        "F0000000200EB020000E3010000A40200000300"
    np_points,(mschema,endianness, compression, npoints) = patch_string_buff_to_numpy(patch_text, schemas, connection_string)
    print np_points
        
    schema  = get_schema(1,schemas,connection_string)
    name_index_dict = schema.getNamesIndexesDictionnary()
    print name_index_dict['X']
    #print np_points
    numpy_double, schema = patch_numpy_to_numpy_double(np_points, schema)
    numpy_spec = numpy_double_to_numpy_spec(numpy_double, schema)
    patch = numpy_spec_to_patch(numpy_spec, schema)
    import difflib
    print "\n".join(difflib.ndiff([patch_text.upper()], [patch.upper()]))
    
    #print schema
    try:
        import plpy
        executing_in_postgres = True
        #plpy.notice(schemas);
    except ImportError:
        executing_in_postgres = False

def test_from_outside_db():
    connection_string = """dbname=test_pointcloud user=postgres password=postgres port=5433"""
    create_GD_if_not_exists()
    create_schemas_if_not_exists()
    test_schema(GD['rc']['schemas'], connection_string);

#test_from_outside_db()