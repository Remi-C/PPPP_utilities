--Remi Cura Thales/IGN  10/03/2014
--Function to rasterize patch using postgis raster


-------------------------------------------------------------
--
--this scrip intend to try to use postgis raster functionnality with point_cloud functionnality
--the goal is to create raster out of point cloud patches.
--
--The twist is this version uses ST_SetValues with a float[][] to set all pixel at the same time
--this fact brings modification , because we can compute the pixel index and pixel values once and for all, then set one band at a time.
--this is way faster !
-------------------------------------------------------------

--DROP SCHEMA IF EXISTS test_raster CASCADE;
--CREATE SCHEMA test_raster;

--SET search_path TO test_raster,acquisition_tmob_012013,public;
--SET client_min_messages TO WARNING;

----------------
--patch_to_raster
---------------


--------------
--function
--	patch2raster() : create a new raster out of a patch
--	rc_Patch2RasterBand() : add a band to a raster given a patch

	

	DROP FUNCTION IF EXISTS rc_Patch2Raster_arar(IN i_p PCPATCH,OUT o_r RASTER ,IN dimensions TEXT[],IN pixel_size FLOAT) ;
	CREATE OR REPLACE FUNCTION  rc_Patch2Raster_arar(IN i_p PCPATCH,  OUT o_r RASTER  ,IN dimensions TEXT[], IN pixel_size FLOAT) AS
	$BODY$
		--@brief this function convert a pointcloud patch to a postgis raster 
		--@param the patch to convert
		--@return : the raster producted by conversion

		--@TODO : add rounding to extend (snap to grid with pixel size size, manually done in a function)
		
		--pseudo code
			--create a raster
				--set pixel size
				--set raster localisation
			--create a temp table with the patch points and attributes, image indexed style (matrice of pixels with attributes)
			-- file raster with info :
				--for each patch dimension
					--call rc_Patch2RasterBand ( =  add band,file band ) 
			--return patch
		DECLARE
			_pixel_size FLOAT := pixel_size;
			bbox_p GEOMETRY := i_p::geometry;
			_min_x float := ST_XMin (bbox_p);
			_min_y float := ST_YMin (bbox_p);
			_max_x float := ST_XMax (bbox_p);
			_max_y float := ST_YMax (bbox_p);
			
			_width float = @(_max_x - _min_x);
			_height float=  @(_max_y - _min_y);
			_n_pix_x int = (trunc(_width/_pixel_size+1))::int;
			_n_pix_y int = (trunc(_height/_pixel_size+1))::int;
			_sql text;
			_temp_table_name text;
			dim text;
			i int;
			ndim int;
		BEGIN

			-- RAISE NOTICE 'upper left : % % ', rc_round(ST_XMin (bbox_p), pixel_size)-1*pixel_size/2,rc_round(ST_YMin (bbox_p), pixel_size)-1*pixel_size/2 ;
			-- RAISE NOTICE 'Should be : % ',ST_Astext(bbox_p) ; 
			-- RAISE NOTICE 'width  : %, heigth : %, giving number of pixels : % , %',width,height, trunc(width/pixel_size+1)::int+1 , trunc(height/pixel_size+1)::int+1 ;
			
			--create a raster  
				--set pixel size, --set raster localisation
				o_r := ST_MakeEmptyRaster( 
					_n_pix_x ,_n_pix_y  --we round and make sure we always include any points
					,upperleftx:=rc_round(ST_XMin (bbox_p), _pixel_size)-1.0*_pixel_size/2
					,upperlefty:=rc_round(ST_YMin (bbox_p), _pixel_size)-1.0*_pixel_size/2 
						--translating of pixel_size/2 to have the point in center of pixels
					,scalex:=_pixel_size , scaley:=_pixel_size 
					, skewx:=0 ,skewy:=0 
					, srid:=932011 ); --srid of translated lambert 93 to match laser referential

				--RAISE NOTICE 'raster info after creation : %',ST_Summary(o_r);


			--create a temp table with the patch points and attributes, image indexed style (matrice of pixels with attributes)

				_temp_table_name :=  rc_generate_pixel_table(i_p,_pixel_size, dimensions )::text ;

				--RAISE EXCEPTION 'hey : _sql : %',_sql;
			-- file raster with info :
				--for each patch dimension
				FOR dim IN SELECT value  FROM (SELECT * FROM rc_unnest_with_ordinality(dimensions)) AS sub ORDER BY ordinality ASC
				LOOP
					--RAISE NOTICE ' in da loop %', dim ;
					SELECT rc_Patch2RasterBand_arar(i_p,quote_ident(dim),o_r,_pixel_size, _temp_table_name)  INTO o_r;
 
				END LOOP;  
				--RAISE NOTICE 'o_r : before returning : %', ST_Summary(o_r);
				
		 RETURN;
		END;
	$BODY$
	 LANGUAGE plpgsql  IMMUTABLE STRICT;
 
  

	DROP FUNCTION IF EXISTS rc_Patch2RasterBand_arar(IN i_p PCPATCH, IN dim_name TEXT, in i_r RASTER , IN pixel_size FLOAT, IN temp_table_name regclass , OUT u_r RASTER) ;
	CREATE OR REPLACE FUNCTION rc_Patch2RasterBand_arar(IN i_p PCPATCH, IN dim_name TEXT , in i_r RASTER , IN pixel_size FLOAT, IN temp_table_name regclass, OUT u_r RASTER) 
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
		_sql text;
		geom_val_arr geomval[];
		_lux DOUBLE PRECISION;
		_luy DOUBLE PRECISION;
		r record;
		BEGIN

			_sql := format( '
					WITH pixel_table AS (
						SELECT *
						FROM %I
					)',temp_table_name);

					
					_sql := _sql ||
					
					',pixel_line AS (
					SELECT iy , array_agg('|| dim_name||' ORDER BY ix ASC) as pline
					FROM pixel_table
					GROUP BY iy
					)
					,pixel_mat AS (
						SELECT array_agg_custom( ARRAY[pline ] ORDER BY iy ASC) AS ar_ar_val
						FROM pixel_line
						GROUP BY TRUE
					)
					,adding_b AS (
						SELECT  ST_AddBand( $1, $2
								,pixeltype:=''32BF''
								, initialvalue:=''NaN''
								, nodataval:=''NaN'') AS rast
					) 
					--integer columnx, integer rowy, double precision[][] newvalueset, double precision nosetvalue, boolean keepnodata=FALSE);
					SELECT ST_SetValues(adding_b.rast,$2,1,1,ar_ar_val,NULL::double precision,FALSE) 
					FROM pixel_mat,adding_b ; ';
				EXECUTE _sql 	
					INTO u_r USING i_r, numband;
					RETURN ;
			 
		END;
	$BODY$
	 LANGUAGE plpgsql VOLATILE;




	DROP FUNCTION IF EXISTS rc_generate_pixel_table(IN i_p PCPATCH,IN pixel_size float,IN dimensions TEXT[], OUT temp_table_name regclass) ;
	CREATE OR REPLACE FUNCTION rc_generate_pixel_table(IN i_p PCPATCH,IN pixel_size float,IN dimensions TEXT[], OUT temp_table_name regclass) AS
	$BODY$
			--@brief : this function compute a pixel table given a patch 
			--points in the patch are rounded and grouped, those of minimal Z have priority, then the pixels are completed with empty pixels to have complete matrix of pixels.
		DECLARE	
			_pixel_size FLOAT =pixel_size;
			bbox_p GEOMETRY := i_p::geometry;
			_min_x float := ST_XMin (bbox_p);
			_min_y float := ST_YMin (bbox_p);
			_max_x float := ST_XMax (bbox_p);
			_max_y float := ST_YMax (bbox_p);
			
			_width float = @(_max_x - _min_x);
			_height float=  @(_max_y - _min_y);
			_n_pix_x int = (trunc(_width/_pixel_size))::int;
			_n_pix_y int = (trunc(_height/_pixel_size))::int;
			_sql text;
			_temp_table_name text;
			dim text;
			i int;
			ndim int;
		BEGIN 


				_temp_table_name :=  'tmp_p_to_r_arar_' || lower(rc_random_string(20));

				_sql :=format( '
				DROP TABLE IF EXISTS %I;
				CREATE TEMP TABLE %I AS 
				', _temp_table_name,_temp_table_name);

			
				
				_sql := _sql ||
				'
				WITH patch  AS (
					SELECT $1 AS pa,'||pixel_size||'::double precision as pixel_size  
				)
				,r_points AS (
						SELECT rc_round(PC_Get(pt,''x'')::double precision,pixel_size)::real AS coord_x
							, rc_round(pc_get(pt,''y'')::double precision,pixel_size)::real  AS  coord_y
							, rc_round(PC_Get(pt,''z'')::double precision,pixel_size)::real AS coord_z
							';

				FOR dim IN SELECT value  FROM (SELECT * FROM rc_unnest_with_ordinality(dimensions)) AS sub ORDER BY ordinality ASC
				LOOP
					--RAISE NOTICE ' in da loop %', dim ;
					_sql := _sql || ', pc_get(pt, ' ||quote_literal(dim)||')::real AS '||dim;
 
				END LOOP; 	
				
				_sql:=_sql ||
				' FROM patch, pc_explode(pa) AS pt
				) 
				,g_points AS ( 
						SELECT DISTINCT ON ( coord_x,coord_y  ) *
						FROM r_points 
						ORDER BY coord_x,coord_y ,coord_z ASC
				)
				, serie AS (
					SELECT  index_x,index_y , NULL::real AS coord_x,NULL::real AS coord_y,NULL::real AS coord_z
					';

				FOR dim IN SELECT value  FROM (SELECT * FROM rc_unnest_with_ordinality(dimensions)) AS sub ORDER BY ordinality ASC
				LOOP
					--RAISE NOTICE ' in da loop %', dim ;
					_sql := _sql || ', NULL::real AS ' ||quote_ident(dim);
				END LOOP; 	
					


				_sql:=_sql ||
				format('
					FROM generate_series(1,  %1$s  ) AS index_x, generate_series(1,  %2$s  ) AS index_y 
				)
				',_n_pix_x,_n_pix_y);
				
			_sql := _sql || 
				format(',index_points AS (
					SELECT trunc((coord_x-%s)*(%s-1))+1 AS ix,  trunc((coord_y-%s)*(%s-1)) +1 AS iy , *
					FROM g_points
				)',_min_x,_n_pix_x,_min_y,_n_pix_y);

				
				_sql:=_sql ||
				'
				,unioned_points AS (
					SELECT *
					FROM index_points 
					UNION
					SELECT *
					FROM serie
				)
				,filtered_pixels AS (
					SELECT DISTINCT ON (ix,iy) *
					FROM unioned_points
					ORDER BY ix, iy , coord_z ASC
					)
				SELECT *
				FROM filtered_pixels;';
				

				--RAISE EXCEPTION 'hey : _sql : %',_sql;		 
				EXECUTE _sql USING i_p;
		temp_table_name:=_temp_table_name
		RETURN ;
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




