
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential

This function will put in relation a table containing all the different info value and all the data table containing an info columns
WARNING : prototype : non tested or proofed.
*/
DROP FUNCTION IF EXISTS odparis.rc_create_foreign_keys_constraint_on_all_info_columns(text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_create_foreign_keys_constraint_on_all_info_columns(schema_name text,reference_table_name text) RETURNS boolean
AS $$
DECLARE
	the_row record;
	result boolean;
	the_query text := ' ';
	for_query text := ' ';
BEGIN
	BEGIN  

		--creating a table which possess all the differnet info values found in all the data table in the given schema

		
		BEGIN
			the_query := '
				CREATE TABLE '|| reference_table_name ||' WITH OIDS AS
				SELECT * FROM rc_gather_all_info_libelle_columns('|| quote_literal(schema_name) ||');
				;';
		EXECUTE the_query;	
		EXCEPTION
			WHEN duplicate_table
			THEN RAISE NOTICE 'this table   %    already exist, we don t create it',reference_table_name;
		END;

		
		BEGIN
			the_query := '
				ALTER TABLE '|| reference_table_name ||' ADD PRIMARY KEY (info);
				;';
		EXECUTE the_query;	
		EXCEPTION
			WHEN duplicate_object OR invalid_table_definition
			THEN RAISE NOTICE 'this table   %   has already a foreign key constraint defined on info, we don t add it',reference_table_name;
		END;

		
		for_query := 'SELECT * 
			FROM geometry_columns 
			WHERE f_table_schema = '||quote_literal(schema_name) ||'
				AND odparis.rc_column_exists('|| quote_literal(schema_name)||',quote_ident(f_table_name),''info'') = TRUE
			ORDER BY f_table_name ASC ;';

		
	
		FOR the_row IN EXECUTE for_query
			
		LOOP --loop on all table with info column in the schema
			BEGIN
			RAISE NOTICE 'working on : %.%',schema_name,the_row.f_table_name;

			the_query := '
				SELECT odparis.rc_create_foreign_keys_on_info_columns('||quote_literal(schema_name)||','||quote_literal(the_row.f_table_name)||','|| quote_literal(reference_table_name) ||');
				' ;
			EXECUTE the_query ;
			END;
		END LOOP;--end of query construction

	END;
RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
SELECT odparis.rc_create_foreign_keys_constraint_on_all_info_columns('odparis_reworked','odparis_reworked.nomenclature');
SELECT *
FROM odparis_reworked.nomenclature


/*
*this function create a foreign key constraint based on info values
*/

DROP FUNCTION IF EXISTS odparis.rc_create_foreign_keys_on_info_columns(text,text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_create_foreign_keys_on_info_columns(schema_name text,table_name text,reference_table_name text) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	BEGIN --beigining of potential exception throwing block
		the_query := '
		ALTER TABLE '||schema_name||'.'||table_name||' 
			ADD CONSTRAINT infofk 
				FOREIGN KEY (info)
				REFERENCES '|| reference_table_name ||' (info) MATCH FULL;
		';
	--RAISE NOTICE 'the LQL query to be executed : %',the_query;
	EXECUTE the_query ;
	EXCEPTION 
		WHEN undefined_table
		THEN RAISE NOTICE 'this table %.% doesn''t exist, skipping foreign key adding',schema_name,table_name;
		WHEN undefined_column
		THEN RAISE NOTICE 'this table %.% has no __info__ column, skipping foreign key adding',schema_name,table_name;
		WHEN duplicate_column OR ambiguous_column
		THEN RAISE NOTICE 'this table %.% has an amiguous column __info__ or to many of theim, skipping foreign key adding',schema_name,table_name;
		WHEN duplicate_object
		THEN RAISE NOTICE 'this table %.% as already a foreign key constraint defined on info, skipping adding foreign key',schema_name,table_name;
	RETURN FALSE;
	END;
	
	/*END LOOP;*/
RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT odparis.rc_create_foreign_keys_on_info_columns('odparis_test','assainissement','odparis_test.test_info_libelle');


