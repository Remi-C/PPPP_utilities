/*
Rémi Cura 
THALES INTERNAL
28/08/2012

This function reset all the cluster id to NULL in a schema

same WARNING applies.

*/
DROP FUNCTION IF EXISTS odparis.rc_reset_cluster_to_NULL_in_schema(text,text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION odparis.rc_reset_cluster_to_NULL_in_schema(schema_name text,cluster_column_name text) RETURNS text
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
		the_query := 
		'BEGIN;
		SELECT odparis.rc_reset_cluster_to_NULL( '|| quote_literal(schema_name) ||',' ||quote_literal(the_row.f_table_name)||', '||quote_literal(cluster_column_name)|| ' );
		COMMIT;
		END;';

		output_query := output_query || 
		'
		' || the_query ;
    END LOOP;
	RETURN output_query;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
SELECT odparis.rc_reset_cluster_to_NULL_in_schema('odparis_reworked'::Text,'cluster_id'::text);



DROP FUNCTION IF EXISTS odparis.rc_reset_cluster_to_NULL(text,text,text);

CREATE OR REPLACE FUNCTION odparis.rc_reset_cluster_to_NULL(schema_name text, table_name text,cluster_column_name text) RETURNS boolean
AS $$
DECLARE
the_query text := '';
BEGIN
        the_query := '
        UPDATE '||quote_ident(schema_name)||'.'|| quote_ident(table_name) ||' SET '||quote_ident(cluster_column_name)|| ' = NULL ;' ; 
	RAISE NOTICE 'resetting % to NULL in table %.%',cluster_column_name,schema_name,table_name;
	EXECUTE the_query;
        RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case*/
--SELECT odparis.rc_reset_cluster_to_NULL('odparis_test'::text,'indicateur'::text,'cluster_id'::text);
