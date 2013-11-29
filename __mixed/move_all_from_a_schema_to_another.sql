/* Rémi Cura 
THALES INTERNAL
22/08/2012

boolean move_all_from_a_schema_to_another(old_schema text, new_schema text)
This function moves all the geometric data tables from on schema over an other.
WARNING: always returns true, no control of execution,
prototype : not properly tested and proofed.

DEPENDS ON : 
boolean move_table_from_a_schema_to_another(old_schema text, new_schema text, table_name text) 
This function moves a table from a schema to another
same WARNING applies.
*/

DROP FUNCTION rc_move_all_from_a_schema_to_another(text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION rc_move_all_from_a_schema_to_another(old_schema text, new_schema text) RETURNS boolean
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
		result := rc_move_table_from_a_schema_to_another( old_schema, new_schema, row.f_table_name );
    END LOOP;
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 
/*exemple use-case :*/
--SELECT rc_move_all_from_a_schema_to_another('public'::Text,'ODParis'::Text);



DROP FUNCTION rc_move_table_from_a_schema_to_another(text,text,text);
CREATE OR REPLACE FUNCTION rc_move_table_from_a_schema_to_another(old_schema text, new_schema text, table_name text) RETURNS boolean
AS $$
DECLARE
BEGIN
        EXECUTE 'ALTER TABLE ' || quote_ident(old_schema) || '.' || quote_ident(table_name) || ' SET SCHEMA ' || quote_ident(new_schema) || ';' ;
        RETURN TRUE;
END;
$$LANGUAGE plpgsql; 
/*exemple use-case*/
--SELECT rc_move_table_from_a_schema_to_another('ODParis','public','arbres');