/*
Rémi Cura 
THALES INTERNAL
28/08/2012

This function generate the query to vacuum all in a schema

same WARNING applies.

*/
DROP FUNCTION IF EXISTS rc_vacuum_all_in_schema(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_vacuum_all_in_schema(schema_name text) RETURNS text
AS $$
DECLARE
    the_row record;
    output_query text := ' ';
    the_query text;
    query_temp text := '';
BEGIN
	FOR the_row IN /*all tables in geometry_columns wich are not postgis specific table and are in the old schema*/
	SELECT DISTINCT ON (f_table_name) *
	FROM geometry_columns
	WHERE f_table_schema = schema_name
		AND f_table_name <> 'raster_columns'--remove postgis table

    LOOP
		the_query := 'SELECT rc_vacuum_table( '|| quote_literal(schema_name) ||',' ||quote_literal(the_row.f_table_name)||' );';
		EXECUTE the_query INTO query_temp ;
		output_query := output_query || 
		'
		' || query_temp ;
    END LOOP;
	RETURN output_query;
END;
$$LANGUAGE plpgsql; 

--exemple use-case : 
--SELECT rc_vacuum_all_in_schema('odparis_reworked'::Text);



DROP FUNCTION IF EXISTS rc_vacuum_table(text,text);

CREATE OR REPLACE FUNCTION rc_vacuum_table(schema_name text, table_name text) RETURNS text
AS $$
DECLARE
the_query text := '';
BEGIN
        the_query := ' VACUUM '||quote_ident(schema_name)||'.'|| quote_ident(table_name) ||' ;' ; 

        RETURN the_query;
END;
$$LANGUAGE plpgsql; 

-- exemple use-case 
--SELECT rc_vacuum_table('odparis_test'::text,'arbre'::text);
