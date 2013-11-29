
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential
This function define gid as primary key for all tbale in schema

WARNING : prototype : non tested or proofed.
*/
DROP FUNCTION IF EXISTS odparis.rc_create_primary_key_constraint_on_all_gid_columns(text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_create_primary_key_constraint_on_all_gid_columns(text_output boolean, schema_name text, pkey_table text)
  RETURNS text AS
$BODY$
DECLARE
	the_row record;
	result boolean;
	the_query text := ' ';
	for_query text := ' ';
	output_query text := '';
BEGIN
	BEGIN 
		
		for_query := 'SELECT DISTINCT ON (f_table_name) * 
			FROM geometry_columns 
			WHERE f_table_schema = '||quote_literal(schema_name) ||'
				AND odparis.rc_column_exists('|| quote_literal(schema_name)||',quote_ident(f_table_name),'|| quote_literal(pkey_table) ||') = TRUE
			ORDER BY f_table_name ASC ;';

		
	
		FOR the_row IN EXECUTE for_query
			
		LOOP --loop on all table with info column in the schema
			BEGIN
			RAISE NOTICE 'working on : %.%',schema_name,the_row.f_table_name;

			the_query := 
				'SELECT rc_create_primary_key_constraint_on_gid_columns('||quote_literal(schema_name)||','||quote_literal(the_row.f_table_name)||','|| quote_literal(pkey_table) ||');
				' ;
			IF text_output = FALSE
				THEN EXECUTE the_query ;
				ELSE output_query := output_query || 
				'
				BEGIN;
				' || the_query ||
				' COMMIT;
				END;' ;
			END IF;
			END;
		END LOOP;--end of query construction

	END;
IF text_output = FALSE
	THEN RETURN 'TRUE';
	ELSE RETURN output_query;
END IF;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE

/*exemple use-case :*/

SELECT odparis.rc_create_primary_key_constraint_on_all_gid_columns(TRUE,'odparis_reworked','gid');
/*
SELECT *
FROM odparis_reworked.nomenclature
*/

/*
*this function define a given column as a primary key
*/

DROP FUNCTION IF EXISTS odparis.rc_create_primary_key_constraint_on_gid_columns(text,text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_create_primary_key_constraint_on_gid_columns(schema_name text,table_name text,pkey_column text) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	BEGIN --beigining of potential exception throwing block
		the_query := '
		ALTER TABLE '||schema_name||'.'||table_name||' 
			ADD PRIMARY KEY ('|| pkey_column ||') ;
		';
	--RAISE NOTICE 'the SQL query to be executed : %',the_query;
	EXECUTE the_query ;
	EXCEPTION 
		WHEN undefined_table
		THEN RAISE NOTICE 'this table %.% doesn''t exist, skipping primary key adding',schema_name,table_name;
		WHEN undefined_column
		THEN RAISE NOTICE 'this table %.% has no __%__ column, skipping primary key adding',schema_name,table_name,pkey_column;
		WHEN duplicate_column OR ambiguous_column
		THEN RAISE NOTICE 'this table %.% has an amiguous column __%__ or to many of theim, skipping primary key adding',schema_name,table_name,pkey_column;
		WHEN duplicate_object OR invalid_table_definition
		THEN RAISE NOTICE 'this table %.% as already a primary key defined on %, skipping primary key adding',schema_name,table_name,pkey_column;
	RETURN FALSE;
	END;
	
	/*END LOOP;*/
RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT odparis.rc_create_primary_key_constraint_on_gid_columns('odparis_test','assainissement','gid');


