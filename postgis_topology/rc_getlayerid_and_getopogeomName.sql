---------------------------------------------
--Copyright Remi-C Thales IGN 13/09/2013
--
--
--some postgis_topology utilities functions
--
--
--This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--we work on table "route", which contains all the road network in Ile De France and many attributes. It is provided by IGN
--------------------------------------------


-- __ creating utility topology function __ : 

	--getter 1

	DROP FUNCTION IF EXISTS public.rc_getlayerid(text, text);

	CREATE OR REPLACE FUNCTION public.rc_getlayerid(layer_name text, layer_schema text DEFAULT ''::text)
	  RETURNS integer AS
	$BODY$
	--Function to retrieve a layer id based on its name, giving schema name is optionnal
	--
	--
		DECLARE 
		layer_ids int[];
		array_size int;
		BEGIN 
			IF layer_schema = ''
			THEN
				--case where no optionnal arg is provided
				SELECT array_agg(layer_id::integer), array_length(array_agg(layer_id::integer),1)
				FROM topology.layer
				WHERE table_name = layer_name INTO layer_ids,array_size;
			ELSE
				--case where optional arg is provided
				SELECT array_agg(layer_id::integer) AS li, array_length(array_agg(layer_id::integer),1)
				FROM topology.layer
				WHERE table_name = layer_name 
				AND schema_name = layer_schema
				INTO layer_ids,array_size;
			END IF;

			--handling of no answer or multiple answer
			IF array_size=1
			THEN
				--no problem, outputing result
				RETURN layer_ids[1];
			ELSIF array_size IS NULL
			THEN
				--oups : no layer found
				--issuing warning and outputting NULL
				RAISE NOTICE ' the layer named (%) in the schema (%) wasn t found, please consider changing parameters',$1,$2;
				RETURN NULL;
			ELSE
				--oups : too many layers found
				--issuing warning and outputting NULL
				RAISE NOTICE ' too many layers found (%) for the layer (%). Please consider precising the layer schema name (%)',array_size,$1,$2;
				RETURN NULL;
			END IF;
			RETURN layer_ids;
			
		END; -- required for plpgsql
		$BODY$
	  LANGUAGE plpgsql VOLATILE;


	--getter 2 
	DROP FUNCTION IF EXISTS public.rc_getlayername(integer, text);

	CREATE OR REPLACE FUNCTION public.rc_getlayername(layer_id integer, layer_schema text)
	  RETURNS text AS
	$BODY$
			--This function returns the layer name of a topological layer given the layer id and the layer schema name
				--@input : layer_id : id of the layer we want to find the name of
				--@input : layer_schema : name of the (postgres) schema where the layer topogeom column is
				--@output : returns the name of the layer
				
			SELECT table_name
			FROM topology.layer
			WHERE layer_id= $1 AND schema_name = $2
			$BODY$
	  LANGUAGE sql VOLATILE;





	DROP FUNCTION IF EXISTS public.rc_ElementToTopo(_element_id INT , topogeom_column_name  TEXT, table_name TEXT, schema_name TEXT);
	CREATE FUNCTION public.rc_ElementToTopo(_element_id INT , topogeom_column_name  TEXT, table_name TEXT, schema_name TEXT)
		RETURNS SETOF TOPOGEOMETRY AS
		$BODY$
		-- This function,takes an element_id and a topogeometry def,
		--it will return the corresponding topogeometry based on the table relation
		DECLARE 
			_sn TEXT ;
			_r record;
			_q TEXT;
		BEGIN
			--test on inputs

			
			--*
			--get corresponding topogeom_id
			_q:=  format('
			WITH info AS (
				SELECT *
				FROM topology.layer 
				WHERE feature_column = %s
					AND table_name  = %s
					AND schema_name = %s 
				)',quote_literal(topogeom_column_name),quote_literal(table_name),quote_literal(schema_name));
			
			_q:= _q || format('
			, relation AS (
				SELECT r.*
				FROM %I.relation AS r , info
				WHERE r.layer_id = info.layer_id
					AND r.element_type = info.feature_type
					AND element_id = %s
			) 
			SELECT (%I).*
			FROM relation AS r LEFT JOIN %I.%I AS topo ON (r.topogeo_id = (topo.%I).id AND  r.layer_id = (topo.%I).layer_id AND r.element_type = (topo.%I).type)
			
			',schema_name,_element_id,topogeom_column_name,schema_name,table_name, topogeom_column_name,topogeom_column_name,topogeom_column_name);
			--RAISE NOTICE '_q %',_q;


			RETURN QUERY EXECUTE _q;
			RETURN;
			
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;


		SELECT public.rc_ElementToTopo( 
			1
			,'tg'::text,'route_demo'::text,'demo_zone_test'::text);




