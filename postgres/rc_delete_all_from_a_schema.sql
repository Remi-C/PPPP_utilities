/*
Rémi Cura 
THALES INTERNAL
22/08/2012

boolean delete_all_from_a_schema_to_another(schema_name text)
This function delete all the geometric data tables from a schema.
WARNING: always returns true, no control of execution,
prototype : not properly tested and proofed.

*/



DROP FUNCTION IF EXISTS rc_delete_all_from_a_schema(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_delete_all_from_a_schema(schema_name text) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	FOR row IN /*all tables in geometry_columns wich are not postgis specific table and are in the old schema*/
	SELECT *
	FROM geometry_columns
	WHERE f_table_schema = schema_name
		AND f_table_name <> 'raster_columns'--remove postgis table of the selection

	LOOP--loop on all tbale in schema
		BEGIN
		the_query := ' DROP TABLE '|| schema_name ||'.' || row.f_table_name || '; ' ;
		
		EXECUTE the_query ;
		END;

	END LOOP;
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_delete_all_from_a_schema('odparis_reworked'::Text);

