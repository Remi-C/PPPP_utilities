 ---------------------------------------------
--Copyright Remi-C Thales IGN 05/2014
--
--this querry takes a network of polygon as input and break it to nonduplciate lines.
--------------------------------------------



DROP TABLE IF EXISTS temp_visu_qgis_to_delete;
CREATE TABLE temp_visu_qgis_to_delete AS

 WITH the_geom AS ( --creating a fake geom for test purpose, function available here :https://github.com/Remi-C/PPPP_utilities/blob/master/postgis/cdb_GenerateGrid.sql
		SELECT  row_number() over() AS id, geom
		FROM CDB_RectangleGrid(ST_GeomFromtext('polygon((0 0, 100 0, 100 100, 0 100 , 0 0))'), 10,10) AS geom
 )
 ,dmp_seg AS ( --breaking the boundary of polygons into segments. Function is available here: https://github.com/Remi-C/PPPP_utilities/blob/master/postgis/rc_DumpSegments.sql
	 SELECT id, rc_DumpSegments(ST_Boundary(geom)) as dmpgeom
	 FROm the_geom
 )
,cleaned_ds AS ( --snapping to grid to avoid precision issue, replace 0.1 by your alloxed precision
 SELECT id, (dmpgeom).path, ST_SNapToGrid((dmpgeom).geom,0.1) as geom
 FROM dmp_seg
 )
,dedup AS ( --deleting the duplicates in the segments, but not randomly : provide an order to be able ot reconstruct after
 SELECT DISTINCT ON ( geom  )  *
 FROM cleaned_ds
 ORDER BY  geom, id, path
 ) --reconstructing lines from segment, but again with the right order
 ,reconstructed_lines AS (
 SELECT id,   ST_MakeLine(array_agg(geom ORDER BY  dedup.path) ) as geom
 FROM dedup 
GROUP BY id  
 ) --simple check, can be suppressed : it should output no row
 SELECT id, geom 
 FROM reconstructed_lines
 WHERE st_IsValid(geom)  = FALSE