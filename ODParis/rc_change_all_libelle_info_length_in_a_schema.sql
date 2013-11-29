/*
Rémi Cura 
THALES INTERNAL
22/08/2012

boolean rc_change_all_libelle_info_length_in_a_schema(schema_name text)

This function change all the columns info and libelle in a schema to be ot type text (without size limitation).
WARNING: always returns true, no control of execution,
prototype : not properly tested and proofed.


DEPENDS ON : 
boolean rc_change_all_libelle_info_length_in_a_table(schema_name text, table_name text) 
This function change the type of columns info and libelle of the given tbale to set it to text
same WARNING applies.

*/



DROP FUNCTION IF EXISTS rc_change_all_libelle_info_length_in_a_schema(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_change_all_libelle_info_length_in_a_schema(schema_name text) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
BEGIN
	FOR row IN /*all tables in geometry_columns wich are not postgis specific table and are in the given schema*/
	SELECT *
	FROM geometry_columns
	WHERE f_table_schema = schema_name
		AND f_table_name <> 'raster_columns'--remove postgis table

	LOOP --loop on all the tables
		result := rc_change_all_libelle_info_length_in_a_table( schema_name, row.f_table_name );
	END LOOP;

	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_change_all_libelle_info_length_in_a_schema('odparis_test'::Text);





DROP FUNCTION IF EXISTS rc_change_all_libelle_info_length_in_a_table(text,text) ;

CREATE OR REPLACE FUNCTION rc_change_all_libelle_info_length_in_a_table(schema_name text, table_name text)  RETURNS boolean
AS $$
DECLARE
the_query text;
BEGIN
	the_query := ' --change type of _libelle__ column to text
	ALTER TABLE '||quote_ident(schema_name)||'.'||quote_ident(table_name)||' ALTER COLUMN libelle SET DATA TYPE text ; '||'
	ALTER TABLE '||quote_ident(schema_name)||'.'||quote_ident(table_name)||' ALTER COLUMN info SET DATA TYPE text ;' ;
	BEGIN
		EXECUTE the_query ;
	EXCEPTION 
		WHEN undefined_table OR ambiguous_column OR invalid_column_reference OR undefined_column
		THEN RAISE WARNING 'Warning : trying to change type of a column that does''nt exist : %.%',schema_name,table_name;
	END;
        RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case*/
--SELECT rc_change_all_libelle_info_length_in_a_table('odparis_test','assainissement');