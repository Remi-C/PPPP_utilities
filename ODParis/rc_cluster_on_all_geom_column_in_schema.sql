
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential

This function cluster all tabls in a schema on the index based on info column

WARNING : prototype : non tested or proofed.

*/




DROP FUNCTION IF EXISTS rc_cluster_on_all_geom_column(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_cluster_on_all_geom_column(schema_name text) RETURNS boolean
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
				AND rc_column_exists('|| quote_literal(schema_name)||',quote_ident(f_table_name),''info'') = TRUE
			;';
	
		FOR the_row IN EXECUTE for_query
		LOOP --loop on all tbale in schema whxih contains an info column
			BEGIN
			RAISE NOTICE 'working on : %.%',schema_name,the_row.f_table_name;

			the_query := 'SELECT rc_cluster_on_info_column('||quote_literal(schema_name)||','||quote_literal(the_row.f_table_name)||')';
			EXECUTE the_query;
			END;
		END LOOP;--end of query construction
		RETURN true;
	END;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
SELECT rc_cluster_on_all_geom_column('odparis_test');



DROP FUNCTION IF EXISTS rc_cluster_on_geom_column(text,text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_cluster_on_geom_column(schema_name text,table_name text) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	BEGIN --beigining of potential exception throwing block : trying to create the schema
		the_query := '
		CLUSTER VERBOSE '||quote_ident(schema_name)||'.'||quote_ident(table_name)||' USING '||table_name||'_btree_index ;';
		RAISE NOTICE '		trying to cluster this table %.%',schema_name,table_name;
		--RAISE NOTICE 'the_query : %',the_query;
		EXECUTE the_query ;

		
	EXCEPTION 
		WHEN undefined_table
		THEN RAISE NOTICE '	this table %.% doesn''t exist, skipping clustering',schema_name,table_name;
		WHEN undefined_column
		THEN RAISE NOTICE '	this table %.% has no __info__ column, skipping clustering',schema_name,table_name;
		WHEN duplicate_column OR ambiguous_column
		THEN RAISE NOTICE '	this table %.% has an amiguous column __info__ or to many of theim, skipping clustering',schema_name,table_name;
		WHEN duplicate_object OR duplicate_table
		THEN RAISE NOTICE '	this table %.% has already an index nammed %_btree_index, skipping clustering',schema_name,table_name,table_name;
	RETURN TRUE ;
	END;
RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
SELECT rc_cluster_on_geom_column('odparis_test','borne');


