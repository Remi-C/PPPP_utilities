
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential
This function define gid as primary key for all tbale in schema

WARNING : prototype : non tested or proofed.
*/
DROP FUNCTION IF EXISTS odparis.rc_count_points_in_each_table(text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_count_points_in_each_table(text_output boolean, schema_input text, schema_output text, table_output text)
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
			WHERE f_table_schema = '||quote_literal(schema_input) ||'
			ORDER BY f_table_name ASC ;';

		FOR the_row IN EXECUTE for_query	
		LOOP --loop on all table with info column in the schema
			BEGIN
			RAISE NOTICE 'working on : %.%',schema_input,the_row.f_table_name;

			the_query := 
				'CREATE TABLE IF NOT EXISTS '||quote_ident(schema_output)||'.'||quote_ident(table_output)||' (nom_table text, point_number bigint )WITH OIDS;
				WITH titi AS (SELECT count(*) AS the_count
					FROM (SELECT ST_DumpPoints(geom) FROM '||quote_ident(schema_input)||'.'||quote_ident(the_row.f_table_name)||') as toto
				)INSERT INTO '||quote_ident(schema_output)||'.'||quote_ident(table_output)||' SELECT '||quote_literal(the_row.f_table_name)||', the_count FROM titi
				;';
				
			IF text_output = FALSE
				THEN EXECUTE the_query ;
				ELSE output_query := output_query || 
				'
				BEGIN;
				' || the_query ||
				' COMMIT;
				END;
				';
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
LANGUAGE plpgsql VOLATILE;

/*exemple use-case :*/

SELECT odparis.rc_count_points_in_each_table(text_output:=TRUE, schema_input:='odparis_reworked', schema_output := 'odparis_test', table_output := 'test_nombre_points');
/*
SELECT *
FROM odparis_reworked.nomenclature
*/

