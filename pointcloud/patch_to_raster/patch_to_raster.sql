--Remi Cura Thales/IGN  10/03/2014
--Function to rasterize patch using postgis raster


-------------------------------------------------------------
--
--this scrip intend to try to use postgis raster functionnality with point_cloud functionnality
--the goal is to create raster out of point cloud patches.
--
--
-------------------------------------------------------------

DROP SCHEMA IF EXISTS test_raster CASCADE;
CREATE SCHEMA test_raster;

SET search_path TO test_raster,acquisition_tmob_012013,public;
--SET client_min_messages TO DEBUG5;

----------------
--patch_to_raster
---------------


--------------
--function
--	patch2raster() : create a new raster out of a patch

	

	DROP FUNCTION IF EXISTS rc_Patch2Raster(IN i_p PCPATCH,OUT o_r RASTER ,IN dimensions TEXT[]) ;
	CREATE OR REPLACE FUNCTION  rc_Patch2Raster(IN i_p PCPATCH,  OUT o_r RASTER  ,IN dimensions TEXT[]) AS
	$BODY$
		--@brief this function convert a pointcloud patch to a postgis raster 
		--@param the patch to convert
		--@return : the raster producted by conversion

		--@TODO : add rounding to extend (snap to grid with pixel size size, manually done in a function)
		
		--pseudo code
			--create a raster
				--set pixel size
				--set raster localisation
			-- file raster with info :
				--for each patch dimension
					--call rc_Patch2RasterBand ( =  add band,file band ) 
			--return patch
		DECLARE
			pixel_size FLOAT = 0.02;
			bbox_p GEOMETRY := i_p::geometry;
			width float = @(ST_XMax (bbox_p)-ST_XMin (bbox_p));
			height float=  @(ST_YMax (bbox_p)-ST_YMin (bbox_p));
			dim text;
			i int;
			ndim int;
		BEGIN

			-- RAISE NOTICE 'upper left : % % ', rc_round(ST_XMin (bbox_p), pixel_size)-1*pixel_size/2,rc_round(ST_YMin (bbox_p), pixel_size)-1*pixel_size/2 ;
			-- RAISE NOTICE 'Should be : % ',ST_Astext(bbox_p) ; 
			-- RAISE NOTICE 'width  : %, heigth : %, giving number of pixels : % , %',width,height, trunc(width/pixel_size+1)::int+1 , trunc(height/pixel_size+1)::int+1 ;
			
			--create a raster  
				--set pixel size
				--set raster localisation
				o_r := ST_MakeEmptyRaster( 
					trunc(width/pixel_size+1)::int+1 ,trunc(height/pixel_size+1)::int+1  --we round and make sure we always include any points
					,upperleftx:=rc_round(ST_XMin (bbox_p), pixel_size)-1*pixel_size/2
					,upperlefty:=rc_round(ST_YMin (bbox_p), pixel_size)-1*pixel_size/2 
						--translating of pixel_size/2 to have the point in center of pixels
					,scalex:=pixel_size , scaley:=pixel_size 
					, skewx:=0 ,skewy:=0 
					, srid:=932011 ); --srid of translated lambert 93 to match laser referential

				--RAISE NOTICE 'raster info after creation : %',ST_Summary(o_r);
			-- file raster with info :
				--for each patch dimension
				FOR dim IN SELECT value  FROM (SELECT * FROM rc_unnest_with_ordinality(dimensions)) AS sub ORDER BY ordinality ASC
				LOOP
					--RAISE NOTICE ' in da loop %', dim ;
					SELECT rc_Patch2RasterBand(i_p,quote_ident(dim),o_r,pixel_size)  INTO o_r;
 
				END LOOP;  
				--RAISE NOTICE 'o_r : before returning : %', ST_Summary(o_r);
				
		 RETURN;
		END;
	$BODY$
	 LANGUAGE plpgsql  IMMUTABLE STRICT;
 
	DROP TABLE IF EXISTS test_temp_raster;
	CREATE TABLE test_temp_raster AS 
	WITH patch  AS (
		SELECT gid,patch, pc_NumPoints(patch)
		FROM acquisition_tmob_012013.riegl_pcpatch_space
		WHERE gid = 361785   -- OR gid=361784 --big patch
		--WHERE gid = 360004 --little patch
	),
	arr AS (
	--	SELECT ARRAY ['gps_time','x_sensor','y_sensor','z_sensor','x_origin_sensor','y_origin_sensor','z_origin_sensor' ,'x','y','z','x_origin','y_origin','z_origin','echo_range','theta','phi','num_echo','nb_of_echo','amplitude','reflectance','deviation','background_radiation'] AS dimensions
	SELECT ARRAY ['gps_time', 'x','y','z','x_origin','y_origin','z_origin','echo_range','theta','phi' ,'amplitude','reflectance','deviation' ] AS dimensions
	)
	SELECT gid AS rid,   rc_Patch2Raster(patch,dimensions )  AS rast
	FROM patch,arr;
 
 
	 

	DROP FUNCTION IF EXISTS rc_Patch2RasterBand(IN i_p PCPATCH, IN dim_name TEXT, in i_r RASTER , IN pixel_size FLOAT ) ;
	CREATE OR REPLACE FUNCTION rc_Patch2RasterBand(IN i_p PCPATCH, IN dim_name TEXT , in i_r RASTER , IN pixel_size FLOAT ) 
	RETURNS RASTER AS
	$BODY$
		--@brief this function convert a pointcloud patch  dimension to a postgis raster band adde dto the input raster
		--@param the patch to convert
		--@param the name of the dim we want to convert
		--@param the raster to which add a new band and fill it
		--@return : the raster mdoified by function

			--pseudo code : 
		 
		DECLARE
		numband INT := ST_NumBands(i_r)+1;
		t_r raster; 
		u_r raster; 
		geom_val_arr geomval[];
		_lux DOUBLE PRECISION;
		_luy DOUBLE PRECISION;
		r record;
		BEGIN
 
					WITH points AS (
						SELECT pc_explode(i_p) AS pt
						)
					,r_points AS (
						SELECT rc_round(PC_Get(pt,'x')::double precision,pixel_size)::real AS coord_x
							, rc_round(pc_get(pt,'y')::double precision,pixel_size)::real  AS  coord_y
							, rc_round(PC_Get(pt,'z')::double precision,pixel_size)::real AS coord_z
							, pc_get(pt, dim_name )::real AS val
						FROM points
					) 
					,g_points AS ( 
							SELECT DISTINCT ON ( coord_x,coord_y  ) coord_x,coord_y , val 
							FROM r_points 
							ORDER BY coord_x,coord_y ,coord_z ASC, val ASC
							)
					,geomval AS (
							SELECT array_agg((ST_SetSRID(ST_MakePoint( coord_x,coord_y),932011),val)::geomval) AS arr
							FROM g_points AS p )
					,adding_b AS (
						SELECT  ST_AddBand( i_r, numband
								,pixeltype:='32BF'
								, initialvalue:='NaN'
								, nodataval:='NaN') AS rast
					)
					SELECT ST_SetValues(adding_b.rast,numband,arr,FALSE) 
					FROM geomval,adding_b
					INTO u_r;
					RETURN u_r;
			 
		END;
	$BODY$
	 LANGUAGE plpgsql VOLATILE;


 



	DROP FUNCTION IF EXISTS rc_round(in val anyelement , IN round_step anyelement, out o_val DOUBLE PRECISION) ;
	CREATE OR REPLACE FUNCTION rc_round(in val anyelement , IN round_step anyelement, out o_val double precision) AS
	$BODY$
			--@brief : this function round the input value to the nearest value multiple of round_step
		DECLARE			 
		BEGIN 

		o_val := (round(val::numeric/round_step::numeric)*round_step::numeric)::double precision;
		RETURN ;
		END;
	$BODY$
	 LANGUAGE plpgsql  IMMUTABLE STRICT;

	--SELECT rc_round(235.2499, 0.02)

	--select pg_backend_pid();





