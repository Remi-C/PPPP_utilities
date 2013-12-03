-----------------
--Rémi Cura 
--Thales/IGN
--3/12/2013
--
--2 functions to delete all table from a schema
--one to delete only geometry table
--the other to delete all table.
--WARNING : this is CASCADE ! 
--don't use this in a schema with spatial_ref_sys or whole postgis will be removed
--
--
DROP FUNCTION IF EXISTS public.rc_drop_all_geom_in_schema(text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION public.rc_drop_all_geom_in_schema( schema_name text) RETURNS boolean
AS $$ 
DECLARE
    _r record;
    result boolean;
BEGIN
	FOR _r IN /*all tables in geometry_columns wich are not postgis specific table and are in the old schema*/
		SELECT *
		FROM geometry_columns
		WHERE f_table_schema = schema_name
			AND f_table_name <> 'raster_columns'--remove postgis table of the selection
    LOOP
		EXECUTE  format(' DROP TABLE IF EXISTS %I.%I CASCADE;', _schema_name,_r.tablename ) ;
    END LOOP;
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_delete_all_geom_from_a_schema('odparis_reworked'::Text);


DROP FUNCTION IF EXISTS public.rc_drop_all_in_schema(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION public.rc_drop_all_in_schema(_schema_name text) RETURNS boolean
AS $$
DECLARE
    _r record;
    result boolean;
BEGIN
	FOR _r IN /*all tables in geometry_columns wich are not postgis specific table and are in the old schema*/
	SELECT *
	FROM pg_tables
	WHERE schemaname = _schema_name
		 

    LOOP
		EXECUTE  format(' DROP TABLE IF EXISTS %I.%I CASCADE;', _schema_name,_r.tablename ) ;
    END LOOP;
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_drop_all_in_schema('demo_zone_test'::Text);