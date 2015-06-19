-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--test suite for the  function to smoth given line/polygon with a given turning radius 
--	 
------------------------------
/*
--setting search path
	SET search_path TO buffer_variable,street_amp,bdtopo, public;


--perform test axe by axe

	DROP TABLE IF EXISTS test_on_bdtopo;
	CREATE TABLE test_on_bdtopo AS 
	SELECT row_number() over() AS qgis_id,route.id,  smooth.*, ST_Centroid(smooth.o_u_seg_closed) AS center_u_seg
		FROM bdtopo.route, test_rc_smooth_geom_line , rc_smooth_geom( igeom:=route.geom ,radius_table:='test_rc_smooth_geom_line' ,default_radius:=12.5/2 ) AS smooth
		WHERE
			(	--filtering on bdtopo to remove useless stuff to generate sidewalk
				nature != 'Sentier' --5480 case
				AND nature != 'Chemin' --138
				AND nature != 'Piste cyclable' --76
				AND nature != 'Escalier' --433
				AND nature != 'Route empierrée' --36
			)
			AND
			pos_sol = 0
			AND 
			nb_voies !=0
			AND ST_NPoints(route.geom)>2;--no need to work on axes where there are only 2 points !

	--analysing the repartition of error
  
		WITH prim_data AS (
			SELECT o_error_case, count(*) OVER (partition by o_error_case) g_count, count(*) over() o_count
			FROM test_on_bdtopo
		)
		SELECT DISTINCT ON (o_error_case, g_count, o_count) o_error_case, g_count::float/o_count::float
		FROM prim_data;

		--annalyzing the numerical weight of error
		with filtered_route AS (
			SELECT *
			FROM route
			WHERE
				(	--filtering on bdtopo to remove useless stuff to generate sidewalk
					nature != 'Sentier' --5480 case
					AND nature != 'Chemin' --138
					AND nature != 'Piste cyclable' --76
					AND nature != 'Escalier' --433
					AND nature != 'Route empierrée' --36
				)
				AND
				pos_sol = 0
				AND 
				nb_voies !=0
		)
		,the_count AS ( --total count of road axe
			SELECT count(*) over()  as g_count
			FROM filtered_route
			LIMIT 1
		 )
		,the_sum AS ( --number of poitns in road axes
			SELECT sum(ST_NPoints(geom)) as npoints
			FROM filtered_route
		)
		SELECT npoints AS total_n_points, g_count AS n_road_axes, npoints - 2*g_count AS number_of_possible_errors
		FROM the_count,the_sum
		--92187	25173	41841


--perform test 2 axes by 2 axes

	--cheking data source
	SELECT *
	FROM seg_pair LIMIT 1

	--looking ofr errors 2 axes by 2 axes
	DROP TABLE IF EXISTS test_on_bdtopo_2axes;
	CREATE TABLE test_on_bdtopo_2axes AS 
	SELECT row_number() over() AS qgis_id,sp.id,  smooth.*, ST_Centroid(smooth.o_u_seg_closed) AS center_u_seg
		FROM (
			SELECT * 
			FROM seg_pair 
			ORDER BY id1 ASC 
			--LIMIT 2000   OFFSET 10000 
			)AS sp 
			, rc_smooth_geom( 
				igeom:=ST_LineMerge(ST_Collect(ST_GeometryN(sp.geom_seg1,1),ST_GeometryN(geom_seg2,1)))
				,radius_table:='test_rc_smooth_geom_line' 
				,default_radius:=12.5/2 
				, the_precision:=0.001::float
				,buffer_option:='quad_segs=16'::text) AS smooth
		

	SELECT row_number() over() AS qgis_id,sp.id,  smooth.*, ST_Centroid(smooth.o_u_seg_closed) AS center_u_seg
		FROM (SELECT * FROM seg_pair WHERE id = '{TRONROUT0000000000182675,TRONROUT0000000000183403}' ORDER BY id1 ASC )AS sp 
			, rc_smooth_geom( 
				igeom:=ST_MakeLine(ST_GeometryN(sp.geom_seg1,1),ST_GeometryN(geom_seg2,1)) 
				,radius_table:='test_rc_smooth_geom_line' 
				,default_radius:=12.5/2 
				, the_precision:=0.01::float
				,buffer_option:='quad_segs=16'::text) AS smooth


	--on a specific case :
		WITH the_geom AS (
			SELECT * 
			FROM seg_pair 
			WHERE id = '{TRONROUT0000000000182675,TRONROUT0000000000183403}'
		)
		SELECT ST_Astext(ST_LineMerge(ST_Collect(ST_GeometryN(sp.geom_seg1,1),ST_GeometryN(geom_seg2,1))) )
		FROM the_geom AS sp

		LINESTRING(-383.80000001348 24638.5999984842,-275.300000013467 24531.0999984835,-277.800000013467 24520.0999984834,-215.200000013367 24432.7999984838,-268.500000013416 24505.3999984852,-277.800000013467 24520.0999984834)
        
        */