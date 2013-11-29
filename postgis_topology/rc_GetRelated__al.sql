---------------------------------------------
--Copyright Remi-C Thales IGN 22/10/2013
--
--
--add on to postgis_topology
--
--
--This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--
--
--adding utility functions to postgis_topology
--
--
-------------------------------------
--------Abstract-------------------
--We add several utility function and  a major function to postgis_topology :
--this is a function that gives, for a topogeom A in a layer and another layer B, all the topogeom in B which are impacted if A changes.
--this function works for finding [puntal,lineal, areal] related to [puntal, lineal, areal]
-- 
--
---------------
--Script organization
---------------
--This file is organized as follow :
--	doc
--	function def
--		public.rc_GetRelatedTopogeom(source_topo topogeometry, target_topo_layer_id INT);
--			public.rc_FromNodeToTopo(input_element_id INT, output_topo_type INT);
--			public.rc_FromTopoToNode(input_element_id INT, input_topo_type INT);
--				public.rc_GetNodeFromEdge(edge_id INT);
--				public.rc_GetEdgeFromNode(input_node_id INT);
--				public.rc_GetFaceFromEdge(edge_id INT);
--				public.rc_GetEdgeFromFace(input_face_id INT);
--	old_function def
--		public.rc_GetRelatedLineal(source_topogeom TOPOGEOMETRY,  topo_lid INT)
--	test_querry
--	Test
--		creating test env
--			define test schema
--			create 2 puntal,lineal, areal topogeom tables
--		testing top function
--			[puntal, lineal, areal] x [puntal, lineal, areal]
--
------------------------------------
--Details
------------
--Implemented function (reverse dependency order)
--
--	public.rc_GetRelatedTopogeom(source_topo topogeometry, target_topo_layer_id INT);
--		public.rc_FromNodeToTopo(input_element_id INT, output_topo_type INT);
--		public.rc_FromTopoToNode(input_element_id INT, input_topo_type INT);
--			public.rc_GetNodeFromEdge(edge_id INT);
--			public.rc_GetEdgeFromNode(input_node_id INT);
--			public.rc_GetFaceFromEdge(edge_id INT);
--			public.rc_GetEdgeFromFace(input_face_id INT);
--
------
--Implementation notes : 
------
--we chose code lisibility over performance.
---the difficult part is allowing all combination of [puntal,lineal,areal] to [puntal, lineal, areal], as it significantly changes the invovled SQL.
--the faster way to do it would be to have a switch for all 9 cases, then execute SQL
--the more readable way is to have subfunction doing the switch work so that the top querry doesn't see the complexity.
--
--
------------
--@TODO @TOCHECK
-----
--the behavior with several different topology remains to be tested
--mixed topogeom input should be detected
--there is no check on inputs whatsoever.
--
--the top function has been tested on :
--		puntal , puntal	: 
--		puntal , lineal		:
-- 		puntal , areal 		:
--		lineal , puntal		:
--		lineal , lineal		:
--		lineal , areal		:
--		areal , puntal		:
--		areal , lineal		:
--		areal , areal 		:
--------------------------------------------





-- __Preparing everything__
	-- __Setting work env__
		--setting path to avoid préfixing table
		SET search_path TO demo_zone_test,bdtopo,bdtopo_bati,bdtopo_reseau_route,topology,public;
		SET postgis.backend = 'sfcgal';

	--__Preparing some test env__

--	DROP TABLE IF EXISTS  public.test_getrelated



	



DROP FUNCTION IF EXISTS public.rc_GetRelatedTopogeom(source_topo topogeometry, target_topo_layer_id INT);
CREATE FUNCTION public.rc_GetRelatedTopogeom(source_topogeom TOPOGEOMETRY,  topo_lid INT)
		RETURNS SETOF TOPOGEOMETRY AS
		$BODY$
		-- This function, given a topogeometry, return all the topogeom of given layer_id that relate to the input topogeom, according to table edge_data
		--topogeom_input <--> relation1 <-->  edge_data <--> relation2 <--> topogeom_target
		--
		--NOTE:  this function expects an operator for topogeometry = topogeometry
		----
		--@TODO : test on inputs
		DECLARE
		the_query TEXT:='';
		target_type INT;
		--from_topo_to_node TEXT :='';
		
		BEGIN
			--test on inputs
			--RETURn QUERY 
			--getting target topogeom type :

			SELECT DISTINCT feature_type
			FROM topology.layer
			WHERE layer_id=topo_lid
			INTO target_type;

			RAISE NOTICE ' target_type : %',target_type;
			
				the_query:= format('
				WITH the_topogeom AS (
					SELECT %s AS topology_id, %s AS layer_id, %s AS id, %s AS type
					LIMIT 1
				),
				the_topogeom_target_info AS (
						SELECT l.*
						FROM the_topogeom as st, topology.layer as l
						WHERE l.layer_id = $1 AND l.topology_id = st.topology_id
						LIMIT 1
					),
				the_relation As ( --relation
					SELECT r.element_id
					FROM the_topogeom as tt
						INNER JOIN relation as r ON ( 
							tt.layer_id= r.layer_id
							AND tt.id= r.topogeo_id 
							AND tt.type = r.element_type
							) 
					LIMIT 1)
				', (source_topogeom).topology_id,(source_topogeom).layer_id,(source_topogeom).id, (source_topogeom).type ) ;

				the_query := the_query || 
					',
					r_to_node AS (
						SELECT DISTINCT rc_FromTopoToNode(r.element_id, tt.type) AS edge_id
						FROM the_relation r, the_topogeom tt)
					,
					node_to_r AS(
						SELECT DISTINCT rc_FromNodeToTopo(rtp.edge_id, ttti.feature_type ) AS edge_id
						FROM r_to_node rtp , the_topogeom_target_info ttti
					)';

				the_query := the_query || 
					',
					the_relation2 As ( --relation
						SELECT DISTINCT r.topogeo_id,r.layer_id,r.element_id, r.element_type
						FROM the_topogeom_target_info AS ti, node_to_r as ted 
							INNER JOIN relation as r ON (r.element_id= ted.edge_id )
							WHERE r.layer_id = ti.layer_id AND  r.element_type = ti.feature_type
					),
					the_topogeom_target AS(
						SELECT ti.topology_id, r.layer_id, r.topogeo_id, ti.feature_type AS type
						FROM the_relation2 AS r LEFT JOIN the_topogeom_target_info AS ti ON (r.layer_id=ti.layer_id)
						WHERE r.element_type =ti.feature_type
					)
					SELECT *
					FROM the_topogeom_target
					;';
				RAISE NOTICE '
				%
				',the_query;
				RETURN QUERY EXECUTE the_query USING topo_lid;
			RETURN  ;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;


		--SELECT public.rc_GetRelatedTopogeom(  (13,1,100,2)::topogeometry ,1);





DROP FUNCTION IF EXISTS public.rc_FromTopoToNode(input_element_id INT, input_topo_type INT);
		CREATE FUNCTION  public.rc_FromTopoToNode(input_element_id INT, input_topo_type INT)
		RETURNS SETOF int AS
		$BODY$
		-- This function takes an element_id and depending on type call cascaded functions to convert from an element id to node_id
		--example : face_id -> edge_id -> node_id
		--@TODO : test on inputs
		DECLARE
		BEGIN
			CASE input_topo_type
			WHEN 1 THEN
				--nothing to do, already on node level
				return NEXT input_element_id AS element_id; RETURN ;
			WHEN 2 THEN
				--converting from edge to node
				RETURN QUERY SELECT DISTINCT rc_GetNodeFromEdge(input_element_id) AS element_id; RETURN ;
			WHEN 3 THEN
				RETURN QUERY SELECT DISTINCT rc_GetNodeFromEdge(rc_GetEdgeFromFace(input_element_id)) AS element_id;RETURN ;	
			ELSE
				--there is a problem
				RAISE NOTICE 'FromTopoToNode : the given type is not allowed :"%"',input_topo_type; 	RETURN NEXT NULL; 	RETURN ;
			END CASE;
		RETURN ;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

		
	--SELECT  rc_FromTopoToNode(51,1);


	DROP FUNCTION IF EXISTS public.rc_FromNodeToTopo(input_element_id INT, output_topo_type INT);
		CREATE FUNCTION  public.rc_FromNodeToTopo(input_element_id INT, output_topo_type INT)
		RETURNS SETOF int AS
		$BODY$
		-- This function takes an element_id and depending on type call cascaded functions to convert from an element id to node_id
		--example : face_id -> edge_id -> node_id
		--@TODO : test on inputs
		DECLARE
		BEGIN
			CASE output_topo_type
			WHEN 1 THEN
				--nothing to do, already on node level
				return NEXT input_element_id AS element_id; RETURN ;
			WHEN 2 THEN
				--converting from edge to node
				RETURN QUERY SELECT DISTINCT rc_GetEdgeFromNode(input_element_id) AS element_id; RETURN ;
			WHEN 3 THEN
				RETURN QUERY SELECT DISTINCT rc_GetFaceFromEdge(rc_GetEdgeFromNode(input_element_id)) AS element_id;RETURN ;	
			ELSE
				--there is a problem
				RAISE NOTICE 'FromNodeToTopo : the given type is not allowed :"%"',input_topo_type; 	RETURN NEXT NULL; 	RETURN ;
			END CASE;
		RETURN ;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

		
	--SELECT  rc_FromNodeToTopo(51,2);



	DROP FUNCTION IF EXISTS public.rc_GetNodeFromEdge(edge_id INT);
		CREATE FUNCTION  public.rc_GetNodeFromEdge(input_edge_id INT)
		RETURNS SETOF int AS
		$BODY$
		-- This function takes an edge_id and return the starting and ending node of this edge from the table edge_data
		--@TODO : test on inputs
		DECLARE
		BEGIN
			RETURN  QUERY 
				SELECT ed.start_node AS edge_id
					FROM edge_data ed
					WHERE ed.edge_id = input_edge_id 
				UNION
				SELECT ed.end_node AS edge_id
					FROM edge_data ed
					WHERE ed.edge_id = input_edge_id  	;
		RETURN ;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;
	--SELECT  rc_GetNodeFromEdge(10);


	DROP FUNCTION IF EXISTS public.rc_GetEdgeFromNode(input_node_id INT);
		CREATE FUNCTION  public.rc_GetEdgeFromNode(input_node_id INT)
		RETURNS SETOF int AS
		$BODY$
		-- This function takes an edge_id and return the starting and ending node of this edge from the table edge_data
		--@TODO : test on inputs
		DECLARE
		BEGIN
			RETURN  QUERY 
				SELECT DISTINCT ed.edge_id AS edge_id
					FROM edge_data ed
					WHERE ed.start_node = input_node_id OR ed.end_node = input_node_id;

		RETURN ;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;
	--SELECT  rc_GetEdgeFromNode(10);

	----
	--source of a bug
	---- WHY??
	DROP FUNCTION IF EXISTS public.rc_GetFaceFromEdge(edge_id INT);
		CREATE FUNCTION  public.rc_GetFaceFromEdge(input_edge_id INT)
		RETURNS SETOF int AS
		$BODY$
		-- This function takes an edge_id and return the starting and ending node of this edge from the table edge_data
		--@TODO : test on inputs
		DECLARE
		BEGIN
			RETURN  QUERY 
				SELECT DISTINCT ed.left_face AS edge_id
					FROM edge_data ed
					WHERE ed.edge_id = input_edge_id 
				UNION
				SELECT DISTINCT ed.right_face AS edge_id
					FROM edge_data ed
					WHERE ed.edge_id = input_edge_id  	;
		RETURN ;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;
	--SELECT  rc_GetFaceFromEdge(10);

	DROP FUNCTION IF EXISTS public.rc_GetEdgeFromFace(input_face_id INT);
		CREATE FUNCTION  public.rc_GetEdgeFromFace(input_face_id INT)
		RETURNS SETOF int AS
		$BODY$
		-- This function takes an edge_id and return the starting and ending node of this edge from the table edge_data
		--@TODO : test on inputs
		DECLARE
		BEGIN
			RETURN  QUERY 
				SELECT DISTINCT ed.edge_id AS edge_id
					FROM edge_data ed
					WHERE ed.left_face = input_face_id OR ed.right_face = input_face_id;

		RETURN ;
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;
	--SELECT  rc_GetEdgeFromFace(10);




	
/*

----------------
--Test query : 
-- this query is used to test the sql side of plppgsql function
--it is only for test purpose.
--
----------------
	SELECT ARRAY[ARRAY['start_node','end_node'] ,ARRAY['abs_next_left_edge','abs_next_right_edge'] ,ARRAY['next_face','right_face'] ];

--topogeom_puntal <--> relation <--> node <--> edge_data <--> relation <--> topogeom_lineal



		DROP TABLE IF EXISTS public.temp_test_topogeom;
		CREATE TABLE public.temp_test_topogeom AS
		--SELECT row_number() over() AS qgis_id,  (13,1,100,2)::topogeometry AS tg
		SELECT row_number() over() AS qgis_id,  public.rc_GetRelatedTopogeom( 
			--(13,1,100,2)::topogeometry ,3) AS tg;
			(13,3,15,1)::topogeometry ,1) AS tg;
		
		WITH the_topogeom AS ( --(13,3,51,1)
			SELECT (tg).topology_id, (tg).layer_id , (tg).id, (tg).type
			FROM (
				--SELECT (13,3,51,1)::topogeometry AS tg --@TODO
				--SELECT (13,1,75,2)::topogeometry AS tg --@TODO
				SELECT (13,1,100,2)::topogeometry AS tg --@TODO
				) as foo
		),
		the_relation As ( --relation
			SELECT r.element_id
			FROM the_topogeom as tt
				INNER JOIN relation as r ON ( 
					tt.layer_id= r.layer_id
					AND tt.id= r.topogeo_id 
					AND tt.type = r.element_type --@TODO
					) 
			LIMIT 1
		),
		r_to_point AS(
			SELECT rc_GetNodeFromEdge(r.element_id) as edge_id
			FROM the_relation r
		),
		point_to_r AS(
			SELECT rc_GetEdgeFromNode(rtp.edge_id) AS edge_id
			FROM r_to_point rtp 
				
		),
		unioned_target_element_id AS (
			SELECT DISTINCT  edge_id AS element_id
			FROM point_to_r	
		),
		the_relation2 As ( --relation
			SELECT r.* --,r.topogeo_id
			FROM unioned_target_element_id as ted
				LEFT JOIN relation as r ON (r.layer_id = 1 AND r.element_id= ted.element_id)
		)
		SELECT row_number() over() AS qgis_id, (13,layer_id,topogeo_id,element_type)::topogeometry AS tg
		FROM the_relation2;


*/
/*
-----------------------------------
--	Test
----------------------------------
--		creating test env
--			define test schema
--			create 2 puntal,lineal, areal topogeom tables
--		testing top function
--			[puntal, lineal, areal] x [puntal, lineal, areal]
-----------------------------------

--		creating test env

			--creating a test schema
			DROP SCHEMA IF EXISTS tst_getrelated CASCADE;
			CREATE SCHEMA  tst_getrelated  ;

			--updating work path
			SET search_path TO  tst_getrelated  ,public, topology;
			SET postgis.backend = 'sfcgal';

--		create 2 puntal,lineal, areal topogeom tables

			--creating a new topology schema :
			-- 	___Creating a new toposchema to store extract___
				SELECT DropTopology('tst_getrelated');
				
				SELECT CreateTopology('tst_getrelated',931008,0.1,false); --18

			--Defining a small test zone : 
				DROP TABLE IF EXISTS tst_getrelated.def_zone_test CASCADE;
				CREATE TABLE tst_getrelated.def_zone_test
				(  gid SERIAL ,
				  id bigint,
				  geom geometry(Polygon,0),
				  CONSTRAINT "def_zone_test_pkey" PRIMARY KEY (gid) );
				  
				INSERT INTO def_zone_test (geom) VALUES (ST_SetSRID(ST_GeomFromText('POLYGON((650991.51060457 6861392.60845766,650724.076746027 6861401.19608631,650147.942099103 6861473.40053484,650123.971278786 6861049.54744332,650221.676622952 6860617.41381724,651129.576702797 6860523.21707174,651656.017999444 6860808.72222041,651381.295241903 6861094.39332507,651251.741239699 6861168.99366869,651187.656333314 6861356.24467468,650991.51060457 6861392.60845766))'),931008));

				SELECT ST_AsText(geom)
				FROM def_zone_test;

			--importing a real topogeom layer :
				
				-- creating a table
				DROP TABLE IF EXISTS tst_getrelated.route_demo ;
				CREATE TABLE tst_getrelated.route_demo (gid SERIAL PRIMARY KEY, id text );
				--adding topology column
				SELECT AddTopoGeometryColumn('tst_getrelated','tst_getrelated','route_demo','tg','LINE');--1
				--importing into route_demo
				
				INSERT INTO tst_getrelated.route_demo (id, tg) 
					SELECT id AS id, toTopoGeom(ST_Force2D(r.geom),'tst_getrelated',rc_getlayerid('route_demo','tst_getrelated'),0.1)
					FROM 
						( SELECT DISTINCT ON (r.id) r.*
						FROM bdtopo.route as r, tst_getrelated.def_zone_test AS dt
						WHERE ST_Within(ST_SetSRID(r.geom,931008),ST_SetSRID(dt.geom,931008))=TRUE
						) as r
					WHERE pos_sol = 0
					ORDER BY id ASC;

			--creating puntal table
				--creating puntal table 1
					DROP TABLE IF EXISTS tst_getrelated.puntal1 ;
					CREATE TABLE tst_getrelated.puntal1 (gid SERIAL PRIMARY KEY);
					--adding topology column
					SELECT AddTopoGeometryColumn('tst_getrelated','tst_getrelated','puntal1','tg','POINT');--1
					--SELECT DropTopoGeometryColumn('tst_getrelated', 'puntal1', 'tg') ;
					INSERT INTO tst_getrelated.puntal1 ( tg) 
						SELECT  toTopoGeom(ST_Force2D(n.geom),'tst_getrelated',rc_getlayerid('puntal1','tst_getrelated'),0.1)
						FROM 
							( SELECT DISTINCT geom
							FROM node n
							WHERE node_id = 71
							) AS n;

				--creatng puntal table 2
					DROP TABLE IF EXISTS tst_getrelated.puntal2 ;
					CREATE TABLE tst_getrelated.puntal2 (gid SERIAL PRIMARY KEY);
					--adding topology column
					SELECT AddTopoGeometryColumn('tst_getrelated','tst_getrelated','puntal2','tg','POINT');--1
					--SELECT DropTopoGeometryColumn('tst_getrelated', 'puntal2', 'tg') ;
					INSERT INTO tst_getrelated.puntal2 ( tg) 
						SELECT  toTopoGeom(ST_Force2D(n.geom),'tst_getrelated',rc_getlayerid('puntal2','tst_getrelated'),0.1)
						FROM 
							( SELECT DISTINCT geom
							FROM node n
							WHERE random() < 0.80
							) AS n;
			--creating lineal table
				--creating lineal table 1
					DROP TABLE IF EXISTS tst_getrelated.lineal1 ;
					CREATE TABLE tst_getrelated.lineal1 (gid SERIAL PRIMARY KEY);
					--adding topology column
					SELECT AddTopoGeometryColumn('tst_getrelated','tst_getrelated','lineal1','tg','LINE');--1
					--SELECT DropTopoGeometryColumn('tst_getrelated', 'lineal1', 'tg') ;
					INSERT INTO tst_getrelated.lineal1 ( tg) 
						SELECT  toTopoGeom(ST_Force2D(n.geom),'tst_getrelated',rc_getlayerid('lineal1','tst_getrelated'),0.1)
						FROM 
							( SELECT DISTINCT geom
							FROM edge_data n
							WHERE edge_id = 84
							) AS n;

				--creating lineal table 2
					DROP TABLE IF EXISTS tst_getrelated.lineal2 ;
					CREATE TABLE tst_getrelated.lineal2 (gid SERIAL PRIMARY KEY);
					--adding topology column
					SELECT AddTopoGeometryColumn('tst_getrelated','tst_getrelated','lineal2','tg','LINE');--1
					--SELECT DropTopoGeometryColumn('tst_getrelated', 'lineal2', 'tg') ;
					INSERT INTO tst_getrelated.lineal2 ( tg) 
						SELECT  toTopoGeom(ST_Force2D(n.geom),'tst_getrelated',rc_getlayerid('lineal2','tst_getrelated'),0.1)
						FROM 
							( SELECT DISTINCT geom
							FROM edge_data n
							WHERE random() < 0.80
							) AS n;
			--creating areal table
				--creating areal table 1
					DROP TABLE IF EXISTS tst_getrelated.areal1 ;
					CREATE TABLE tst_getrelated.areal1 (gid SERIAL PRIMARY KEY);
					--adding topology column
					SELECT AddTopoGeometryColumn('tst_getrelated','tst_getrelated','areal1','tg','POLYGON');--1
					--SELECT DropTopoGeometryColumn('tst_getrelated', 'areal1', 'tg') ;
					INSERT INTO tst_getrelated.areal1 ( tg) 
						SELECT  toTopoGeom(ST_Force2D(n.geom),'tst_getrelated',rc_getlayerid('areal1','tst_getrelated'),0.1)
						FROM 
							( SELECT ST_GetFaceGeometry('tst_getrelated', face_id) AS geom
							FROM face
							WHERE ST_IsEmpty(mbr) = FALSE AND face_id = 19
							) AS n;

				--creating areal table 2
					DROP TABLE IF EXISTS tst_getrelated.areal2 ;
					CREATE TABLE tst_getrelated.areal2 (gid SERIAL PRIMARY KEY);
					--adding topology column
					SELECT AddTopoGeometryColumn('tst_getrelated','tst_getrelated','areal2','tg','POLYGON');--1
					--SELECT DropTopoGeometryColumn('tst_getrelated', 'areal2', 'tg') ;
					DELETE FROM tst_getrelated.areal2 ;
					INSERT INTO tst_getrelated.areal2 ( tg) 
						SELECT DISTINCT ON (n.geom) toTopoGeom(ST_Force2D(n.geom),'tst_getrelated',rc_getlayerid('areal2','tst_getrelated'),0.1)
						FROM 
							( SELECT ST_GetFaceGeometry('tst_getrelated', face_id) AS geom
							FROM face
							WHERE ST_IsEmpty(mbr) = FALSE 
							AND random() < 0.75
							) AS n;

--		testing top function
--			[puntal, lineal, areal] x [puntal, lineal, areal]
--

--corrected  :
-- punt -> punt 
--	adding the topology_id as selection criteria in the target_.. cte, so to avoid wrong output with duplicate layer_id when using multiple topology schema

--lineal -> punt :
	
--the top function has been tested on :
--puntal - *


--		puntal , puntal	: 

				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM puntal1
						--WHERE gid = 93
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('puntal2','tst_getrelated')::int ) f;

			


--lineal - *
	--		lineal , puntal		:
				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM lineal1
						--WHERE gid = 134
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('puntal2','tst_getrelated')::int ) f;

					
	
	--		areal , puntal		:

				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM areal1
						--WHERE gid = 17
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('puntal2','tst_getrelated')::int ) f;

	--		puntal , lineal		:

				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM puntal1
						--WHERE gid = 93
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('lineal2','tst_getrelated')::int ) f;

					
	--		lineal , lineal		:

				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM lineal1
						--WHERE gid = 134
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('lineal2','tst_getrelated')::int ) f;

	--		areal , lineal		:
				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM areal1
						--WHERE gid = 17
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('lineal2','tst_getrelated')::int ) f;

	
	-- 		puntal , areal 		:

				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM puntal1
						--WHERE gid = 93
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('areal2','tst_getrelated')::int ) f;


	--		lineal , areal		:

				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM lineal1
						--WHERE gid = 134
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('areal2','tst_getrelated')::int ) f;


	--		areal , areal 		:

				DROP TABLE IF EXISTS public.temp_getrelated;
				CREATE TABLE public.temp_getrelated AS 
					WITH the_topogeom AS(
						SELECT tg
						FROM areal1
						--WHERE gid = 17
						LIMIT 1
					)
					SELECT row_number() over() as qgis_id, f::topogeometry, f::topogeometry::geometry AS geom
					FROM the_topogeom tt,public.rc_GetRelatedTopogeom(tt.tg, rc_getlayerid('areal2','tst_getrelated')::int ) f;


*/
		