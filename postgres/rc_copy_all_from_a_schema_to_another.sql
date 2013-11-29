/*
Rémi Cura 
THALES INTERNAL
28/08/2012

boolean rc_copy_all_from_a_schema_to_another(old_schema text, new_schema text)
This function copy all the geometric data tables from one schema over an other.
WARNING: always returns true, no control of execution,
prototype : not properly tested and proofed.

ERROR : table are copied, but not index, constraint, etc etc

DEPENDS ON : 
boolean rc_copy_table_from_a_schema_to_another(old_schema text, new_schema text, table_name text) 
This function copy a table from a schema to another
same WARNING applies.

*/
DROP FUNCTION IF EXISTS rc_copy_all_from_a_schema_to_another(text,text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_copy_all_from_a_schema_to_another(old_schema text, new_schema text) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
BEGIN
	FOR row IN /*all tables in geometry_columns wich are not postgis specific table and are in the old schema*/
	SELECT *
	FROM geometry_columns
	WHERE f_table_schema = old_schema
		AND f_table_name <> 'raster_columns'--remove postgis table

    LOOP
		result := rc_copy_table_from_a_schema_to_another( old_schema, new_schema, row.f_table_name );
    END LOOP;
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_copy_all_from_a_schema_to_another('odparis'::Text,'odparis_filtered'::Text);



DROP FUNCTION IF EXISTS rc_copy_table_from_a_schema_to_another(text,text,text);

CREATE OR REPLACE FUNCTION rc_copy_table_from_a_schema_to_another(old_schema text, new_schema text, table_name text) RETURNS boolean
AS $$
DECLARE
BEGIN
        EXECUTE '--remove the table in the destination schema if it already exists
		DROP TABLE IF EXISTS '|| quote_ident(new_schema) || '.' || quote_ident(table_name) ||';' ;
	EXECUTE '
		CREATE TABLE '|| quote_ident(new_schema) || '.' || quote_ident(table_name) || ' WITH OIDS AS 
		SELECT * FROM '|| quote_ident(old_schema) || '.' || quote_ident(table_name) || ';' ; 

        RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case*/
--SELECT rc_copy_table_from_a_schema_to_another('odparis','odparis_filtered','arbres');
