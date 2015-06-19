---------------------------------------------------------------------
--Rémi Cura 
--IGN + THALES
--24/01/2013
--
--This function change srid fr all tables in a schema
--WARNING: always returns true, no control of execution,
--prototype : not properly tested and proofed.
---------------------------------------------------------------------


DROP FUNCTION IF EXISTS rc_change_srid_for_all_from_a_schema(text,bigint);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_change_srid_for_all_from_a_schema(schema_name text, newsrid bigint) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text :='';
BEGIN
	FOR row IN --all tables in geometry_columns wich are not postgis specific table and are in the old schema 
	SELECT *
	FROM geometry_columns
	WHERE f_table_schema = schema_name
		AND f_table_name <> 'raster_columns'--remove postgis table of the selection

	LOOP--loop on all tbale in schema
		BEGIN
		the_query := the_query ||'
		BEGIN;
		'||
		' SELECT UpdateGeometrySRID('|| quote_literal(schema_name) ||','|| quote_literal(row.f_table_name) ||',''geom'','||newsrid||');
		END;' ;

		
		--EXECUTE the_query ;
		END;

	END LOOP;

	RAISE NOTICE '   %  ', the_query;
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECTrc_change_srid_for_all_from_a_schema('odparis_reworked'::Text, 932007);

