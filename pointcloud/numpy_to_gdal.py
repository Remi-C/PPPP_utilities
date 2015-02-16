# -*- coding: utf-8 -*-
"""
Created on Sat Jan 24 16:16:33 2015

@author: remi
#adapted from https://pcjericks.github.io/py-gdalogr-cookbook/raster_layers.html#create-raster-from-array
"""

import gdal, ogr, os, osr
import numpy as np



def numpy_to_ogr_type_conversion(numpy_dtype):
    """numpy_dtype must be a numpy.dtype object"""
    #dtype.itemsize
    #dtype.kind
    import gdal 
    if numpy_dtype.kind == 'u':
        if numpy_dtype.itemsize == 2:
            return gdal.GDT_UInt16
        if numpy_dtype.itemsize == 4:
            return gdal.GDT_UInt32
    if numpy_dtype.kind == 'i':
        if numpy_dtype.itemsize == 2:
            return gdal.GDT_Int16
        if numpy_dtype.itemsize == 4:
            return gdal.GDT_Int32
    if numpy_dtype.kind == 'f':
        if numpy_dtype.itemsize == 2:
            return gdal.GDT_Float32
        if numpy_dtype.itemsize == 4:
            return gdal.GDT_Float32
        if numpy_dtype.itemsize == 8:
            return gdal.GDT_Float64
    
    #default case
    return GDT_Unknown
    
    
class numpy_multi_band_image:
    """this classes hold the various meta data about the points that are being converted to multi band image"""
    def __init__(self):
        """constructor"""
        self.pixel_matrix = []
        self.bottom_left_coordinates = []
        self.pixel_size = 0.0
        self.band_name = []
        self.srtext = ''


    def setAttributes(self, pixel_matrix_, bottom_left_coordinates_, pixel_size_, band_name_, srtext_):
        self.pixel_matrix = pixel_matrix_
        self.bottom_left_coordinates = bottom_left_coordinates_
        self.pixel_size = pixel_size_
        self.band_name = band_name_
        self.srtext = srtext_

 

def array2raster(image_path,nmbi,band_number,no_data_value):
    """this function create a monoband raster  """
    driver = gdal.GetDriverByName('GTiff')
    outRaster = driver.Create(image_path+'_'+nmbi.band_name[band_number]+'.tif'
        , nmbi.pixel_matrix.shape[1]
        , nmbi.pixel_matrix.shape[0]
        , 1
        , numpy_to_ogr_type_conversion(nmbi.pixel_matrix.dtype[band_number]
                            ))
    outRaster.SetGeoTransform(
        (nmbi.bottom_left_coordinates[0]
            , nmbi.pixel_size, 0
            , nmbi.bottom_left_coordinates[1]
            , 0,  nmbi.pixel_size))
    outband = outRaster.GetRasterBand(1)
    outband.WriteArray(nmbi.pixel_matrix[nmbi.band_name[band_number]])
    #print ' no data value type is : %s' % type(no_data_value)
    outband.SetNoDataValue(int(no_data_value))
    outband.FlushCache()
    if nmbi.srtext is not None:
        outRaster.SetProjection(nmbi.srtext)
    outRaster = None

def array2rasters(image_path,nmbi):
    
    #getting numpy no data value for each dtype : 
    no_data_values = nmbi.pixel_matrix.fill_value
    #filling no data with numpy no data value
    nmbi.pixel_matrix = nmbi.pixel_matrix.filled() 
    
    
    for i in range(0,len(nmbi.band_name)):
        array2raster(image_path,nmbi,i,no_data_values[i] )
   

def test_module(multi_band_image):
    rasterOrigin = (-123.25745,45.43013)
    pixelWidth = multi_band_image.pixel_size
    pixelHeight = multi_band_image.pixel_size
    image_path = '/tmp/test'
    
    print multi_band_image.pixel_matrix.dtype.type
    #creating 
    array = np.array([[ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
                      [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
                      [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1],
                      [ 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1],
                      [ 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1],
                      [ 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1],
                      [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1],
                      [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
                      [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
                      [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]])
     # reverse array so the tif looks like the array
    #multi_band_image.pixel_matrix = multi_band_image.pixel_matrix[::-1]
    
    
    array2rasters(image_path,multi_band_image) # convert array to raster
     
    
#test_module()