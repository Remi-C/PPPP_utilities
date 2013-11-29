
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential

This function gather all the different info and libelle in a schema.

WARNING : prototype : non tested or proofed.

*/




DROP FUNCTION IF EXISTS rc_gather_all_info_libelle_columns(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_gather_all_info_libelle_columns(schema_name text) RETURNS TABLE( source_table text, info text, libelle text)
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
		first_table_query := '
			SELECT * 
			FROM geometry_columns 
			WHERE f_table_schema = '||quote_literal(schema_name)||' 
				AND rc_column_exists('|| quote_literal(schema_name)||',quote_ident(f_table_name),''info'') = TRUE
				AND rc_column_exists('|| quote_literal(schema_name)||',quote_ident(f_table_name),''libelle'') = TRUE
			ORDER BY f_table_name ASC 
			LIMIT 1;' ;

		--RAISE NOTICE ' first_table_query : % ',first_table_query;
		EXECUTE first_table_query INTO the_row_before;

		--RAISE NOTICE ' coucou : contenu de the_row_before avant la boucle : %',the_row_before;
		
	
		the_query :=
			'
			SELECT DISTINCT info,libelle FROM rc_gather_info_libelle_columns('||quote_literal(schema_name)||','||quote_literal(the_row_before.f_table_name)||'::Text)
			
			' ;

		for_query := 'SELECT * 
			FROM geometry_columns 
			WHERE f_table_schema = '||quote_literal(schema_name) ||'
				AND rc_column_exists('|| quote_literal(schema_name)||',quote_ident(f_table_name),''info'') = TRUE
				AND rc_column_exists('|| quote_literal(schema_name)||',quote_ident(f_table_name),''libelle'') = TRUE
			ORDER BY f_table_name ASC 
			OFFSET 1';
	
		FOR the_row IN EXECUTE for_query
			
		LOOP --loop to construct the query 
			BEGIN
			--RAISE NOTICE 'working on : %.%',schema_name,the_row.f_table_name;

		
			the_query := 
				'('|| the_query || ')
				UNION ALL
				(
					SELECT DISTINCT info,libelle FROM rc_gather_info_libelle_columns('||quote_literal(schema_name)||','||quote_literal(the_row.f_table_name)||')
				)
				' ;
			END;
		END LOOP;--end of query construction

		the_query := the_query || ' ;';
		

		RETURN QUERY EXECUTE the_query;	
	END;
	
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT * FROM rc_gather_all_info_libelle_columns('odparis_test');



DROP FUNCTION IF EXISTS rc_gather_info_libelle_columns(text,text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_gather_info_libelle_columns(schema_name text,table_name text) RETURNS TABLE( source_table text, info text, libelle text)
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	BEGIN --beigining of potential exception throwing block
		the_query := '
		SELECT '' '||schema_name||'.'||table_name||' ''::Text AS source_table,info, libelle
		FROM '||schema_name||'.'||table_name||'
		GROUP BY info, libelle
		';
	RETURN QUERY EXECUTE the_query ;
	EXCEPTION 
		WHEN undefined_table
		THEN RAISE NOTICE 'this table %.% doesn''t exist, skipping gathering',schema_name,table_name;
		WHEN undefined_column
		THEN RAISE NOTICE 'this table %.% has no __info__ column, skipping gathering',schema_name,table_name;
		WHEN duplicate_column OR ambiguous_column
		THEN RAISE NOTICE 'this table %.% has an amiguous column __info__ or to many of theim, skipping gathering',schema_name,table_name;
	RETURN ;
	END;
	
	/*END LOOP;*/
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT * FROM rc_gather_info_libelle_columns('odparis_reworked','detail_de_bati');


