---------------------------------------------
--Copyright Remi-C Thales IGN 13/09/2013
--
--
--some postgis_topology utilities functions
--
--
--This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled 
--------------------------------------------


-- __ creating utility topology function __ : 

	--getter 1

	DROP FUNCTION IF EXISTS rc_getlayerid(text, text); 
	CREATE OR REPLACE FUNCTION rc_getlayerid(layer_name text, layer_schema text DEFAULT ''::text)
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

 
	DROP FUNCTION IF EXISTS rc_getlayername(integer, text); 
	CREATE OR REPLACE FUNCTION rc_getlayername(layer_id integer, layer_schema text)
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

 
