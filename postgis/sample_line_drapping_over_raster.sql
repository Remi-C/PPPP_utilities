-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
-- some example of drapping a lien over a raster (we have a line and a dem, how to transfer info from dem to line.)
--	find the pixel under the line
--	transform those pixels into polygons along with height value (ST_PixelAsPolygons)
--	cut the line with those polygons (create new points at each enter/exit of pixels)
--	add the height information of each polygon into the line parts.
--	renode the line by assembling in the correct order the line parts.
------------------------------


/*
	WITH rast AS ( --getting a raster, and a diag line for this raster
		SELECT *  --, ST_Intersection(rast,line)--unnest(regexp_split_to_array(ST_Summary(rast),'\n'))
		FROM test_raster.test_temp_raster,ST_SetSRID(ST_GeomFromText('Linestring(651050. 6860677,651055 6860682)') ,931008) AS line
		WHERE rid = 273143
		LIMIT 1
	)
	,pix_under_line AS ( --get the pixels that are covered by the line, transform the pixels into square (pylgon), keep the value of the band 1 (heigth is supposed to be here)
						--this is suboptimal and could be replacer by using st_intersection
		SELECT pix.*, line 
		FROM rast,ST_PixelAsPolygons(rast,1) AS pix
		WHERE  ST_Intersects(pix.geom,line)=TRUE
			--AND pix.val!=0 --if raster from interpolation, no need to keep wrong parts
	)
	,cutting_line_with_pix AS (--splitting the line with the pixels in order to obtain multiple parts of the line, each covering one pixel 
							--(see https://github.com/Remi-C/PPPP_utilities/tree/master/postgis for rc_split_multi)
		SELECT  ST_Dump(rc_Split_multi(min(line), ST_Union(ST_Boundary(geom)),0.01)) AS splitted_line
		FROM pix_under_line
	)
	,splitted_line AS ( --filtering the obtained parts of line to remove ghost created by precision error and point-line
		SELECT (splitted_line).path, (splitted_line).geom, ST_AsText( (splitted_line).geom)
		FROM cutting_line_with_pix
		WHERE ST_Length((splitted_line).geom)>0.001
	)
	,sl_and_pix AS ( --for each parts of line, get the pixel polygon that it covers, along with the value of the pixel. Add this value to the parts of line
		SELECT DISTINCT ON (path) sl.*,  pul.*, ST_AddMeasure(sl.geom,pul.val,pul.val) AS l_heigth
		FROM splitted_line AS sl, pix_under_line AS pul
		WHERE  ST_Intersects(sl.geom,pul.geom)=TRUE
		ORDER BY path ASC, ST_Length(sl.geom) DESC
	)--fusion the line parts to create a single line (don't use ST_Union, it drops the M value)
	SELECT ST_Astext(ST_MakeLine(l_heigth ORDER BY path ASC) )  
	FROM sl_and_pix ; 
    
    
    */