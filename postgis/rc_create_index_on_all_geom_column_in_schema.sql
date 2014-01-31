﻿
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential

This function create an index for all info column in schema

WARNING : prototype : non tested or proofed.

*/




DROP FUNCTION IF EXISTS rc_create_index_on_all_geom_column_in_schema(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_create_index_on_all_geom_column_in_schema(schema_name text) RETURNS boolean
AS $$
DECLARE

	first_table_query text;
	the_row_before record;
	the_row record;
	result boolean;
	the_query text := ' ';
	for_query text := ' ';
BEGIN
	BEGIN --beigining of result construction
	--first table 

		
		for_query := 'SELECT * 
			FROM geometry_columns 
			WHERE f_table_schema = '||quote_literal(schema_name) ||'
				AND f_table_name <> ''raster_column'' ';
	
		FOR the_row IN EXECUTE for_query
		LOOP --loop on all tbale in schema whxih contains an info column
			BEGIN
			RAISE NOTICE 'working on : %.%',schema_name,the_row.f_table_name;

			the_query := 'SELECT rc_create_index_on_geom_column('||quote_literal(schema_name)||','||quote_literal(the_row.f_table_name)||','|| quote_literal(the_row.f_geometry_column)||')';
			EXECUTE the_query;
			END;
		END LOOP;--end of query construction

		

		RETURN true;
	END;
	
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_create_index_on_all_geom_column_in_schema('odparis_test');



DROP FUNCTION IF EXISTS rc_create_index_on_geom_column(text,text,text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_create_index_on_geom_column(schema_name text,table_name text,geom_column_name text) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	BEGIN --beigining of potential exception throwing block : trying to create the schema
		the_query := '
		CREATE INDEX '||table_name||'_gist_index ON '||quote_ident(schema_name)||'.'||quote_ident(table_name)||' USING gist ('||quote_ident(geom_column_name)||') ;';
		RAISE NOTICE '	trying to index this table %.%',schema_name,table_name;
		--RAISE NOTICE 'the_qery : %',the_query;
		EXECUTE the_query ;
		RETURN TRUE;
	EXCEPTION 
		WHEN undefined_table
		THEN RAISE NOTICE '	this table %.% doesn''t exist, skipping indexing',schema_name,table_name;
		WHEN undefined_column
		THEN RAISE NOTICE '	this table %.% has no __geom__ column, skipping indexing',schema_name,table_name;
		WHEN duplicate_column OR ambiguous_column
		THEN RAISE NOTICE '	this table %.% has an amiguous column __geom__ or to many of theim, skipping indexing',schema_name,table_name;
		WHEN duplicate_table
		THEN RAISE NOTICE '	this table %.% has already a gist index named %_gist_index, skipping indexing',schema_name,table_name,table_name;
	RETURN TRUE;
	END;
	
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_create_index_on_geom_column('odparis_test','assainissement','geom');

