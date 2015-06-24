---------------------------------------------
--Copyright Remi-C Thales IGN  03/12/2013
--
--
--some postgis_topology utilities functions
--
--
--This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled 
--------------------------------------------

	DROP FUNCTION IF EXISTS rc_ElementToTopo(_element_id INT , topogeom_column_name  TEXT, table_name TEXT, schema_name TEXT);
	CREATE FUNCTION rc_ElementToTopo(_element_id INT , topogeom_column_name  TEXT, table_name TEXT, schema_name TEXT)
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
			SELECT  DISTINCT (%I).*
			FROM relation AS r LEFT JOIN %I.%I AS topo ON (r.topogeo_id = (topo.%I).id AND  r.layer_id = (topo.%I).layer_id AND r.element_type = (topo.%I).type)
			
			',schema_name,_element_id,topogeom_column_name,schema_name,table_name, topogeom_column_name,topogeom_column_name,topogeom_column_name);
			--RAISE NOTICE '_q %',_q;


			RETURN QUERY EXECUTE _q;
			RETURN;
			
		END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

/*
		SELECT rc_ElementToTopo( 
			1
			,'tg'::text,'route_demo'::text,'demo_zone_test'::text);
*/