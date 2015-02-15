# -*- coding: utf-8 -*-
"""
Created on Sat Jan 24 16:16:33 2015

@author: remi
#adapted from https://pcjericks.github.io/py-gdalogr-cookbook/raster_layers.html#create-raster-from-array
"""

import gdal, ogr, os, osr
import numpy as np


class numpy_multi_band_image:
    """this classes hold the various meta data about the points that are being converted to multi band image"""
    def __init__(self):
        """constructor"""
        self.pixel_matrix = []
        self.bottom_left_coordinates = []
        self.pixel_size = 0.0
        self.band_name = []


    def setAttributes(self, pixel_matrix_, bottom_left_coordinates_, pixel_size_, band_name_):
        self.pixel_matrix = pixel_matrix_
        self.bottom_left_coordinates = bottom_left_coordinates_
        self.pixel_size = pixel_size_
        self.band_name = band_name_


def matrix_to_band(numpy_multi_band_image):
     """add a band to """   
    
def array2raster(image_path,nmbi):
    cols = nmbi.pixel_matrix.shape[1]
    rows = nmbi.pixel_matrix.shape[0]
    originX = nmbi.bottom_left_coordinates[0]
    originY = nmbi.bottom_left_coordinates[1]

    driver = gdal.GetDriverByName('VRT')
    #driver = gdal.GetDriverByName('JPEG2000')
    print "driver : %s " % driver
    
    outRaster = driver.Create(image_path, cols, rows, 1,gdal.GDT_Int32) # len(nmbi.band_name)
    outRaster.SetGeoTransform((originX, nmbi.pixel_size, 0, originY, 0,  nmbi.pixel_size))
    outRasterSRS = osr.SpatialReference()
    outRasterSRS.ImportFromEPSG(3057)
    outRaster.SetProjection(outRasterSRS.ExportToWkt())
    
    outRaster.AddBand(gdal.GDT_Int32)
    outRaster.AddBand(gdal.GDT_Int32)
    outRaster.AddBand(gdal.GDT_Int32)
    
    
    outband = outRaster.GetRasterBand(1)
    outband.WriteArray(array)
    
    outRaster.SetProjection(outRasterSRS.ExportToWkt())
    outband.FlushCache() 
   

def test_module(multi_band_image):
    rasterOrigin = (-123.25745,45.43013)
    pixelWidth = multi_band_image.pixel_size
    pixelHeight = multi_band_image.pixel_size
    image_path = '/tmp/test.tif'
    
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
    multi_band_image.pixel_matrix = multi_band_image.pixel_matrix[::-1]
    array2raster(image_path,multi_band_image) # convert array to raster
     
    
#test_module()