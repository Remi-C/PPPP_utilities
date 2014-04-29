---------------------------------------------
--Rémi-C , THALES
--22/08/2012
--
--Moving all table from a schema to another
-----------------------------------------------

--WARNING: always returns true, no control of execution, prototype : not properly tested and proofed.

 
 

DROP FUNCTION IF EXISTS rc_move_all_from_a_schema_to_another(text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION rc_move_all_from_a_schema_to_another(old_schema text, new_schema text) RETURNS boolean
AS $$
	--@brief : this function move all the table from a given schema to another.
	--@param : the old schema
	--@param : the new schema
	--@return : return always true

DECLARE
    row record;
    result boolean;
BEGIN
	FOR row IN /*all tables in geometry_columns wich are not postgis specific table and are in the old schema*/
	SELECT table_name FROM information_schema.tables 
	WHERE table_schema = old_schema  
    LOOP
		result := rc_move_table_from_a_schema_to_another( old_schema, new_schema, row.f_table_name );
    END LOOP;
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT tc_move_all_from_a_schema_to_another('public'::Text,'ODParis'::Text);





DROP FUNCTION IF EXISTS  rc_move_table_from_a_schema_to_another(text,text,text);

CREATE OR REPLACE FUNCTION rc_move_table_from_a_schema_to_another(old_schema text, new_schema text, table_name text) RETURNS boolean
AS $$
	--@brief : this function move one table from a given schema to another. The table must __not__ be schema qualified. 
	--@param : the old schema
	--@param : the new schema
	--@param : the table name (no schema qualifier)
	--@return : return always true
	
DECLARE
BEGIN
        EXECUTE 'ALTER TABLE ' || quote_ident(old_schema) || '.' || quote_ident(table_name) || ' SET SCHEMA ' || quote_ident(new_schema) || ';' ;
        RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case*/
--SELECT rc_move_table_from_a_schema_to_another('ODParis','public','arbres');