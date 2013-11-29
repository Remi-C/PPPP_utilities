/*
*Remi Cura , 16/09/2012
*Thales T&S  &&  TELECOM ParisTech
*
*This function is designed to register new imported table base on their utilization and usecase: 'plani2clip, 'plani2spread' ...
*exemple : utilisation : graphic, sethi , ...      ;   usecase : 'plani2cluip, plani2spread, plani2copy ....
*If no table 'source' exist, create on like :
* | nom_table	(text)			|  utilisation (text)		|  traitement (text)
* |					|				|  
* | maquette_importation.mytable	|  graphic			|  plani2clip
*

*if a source table exist : add an entry into utilisation registering the new table
*/

DROP FUNCTION IF EXISTS maquette_importation.rc_register_imported_table(table_name text, utilization text, usecase text, schema_name text, source_table text);
CREATE OR REPLACE FUNCTION maquette_importation.rc_register_imported_table(table_name text, utilization text, usecase text, schema_name text,  source_table text) RETURNS BOOLEAN
AS
$BODY$
DECLARE
the_query text := '';

BEGIN 
	--trying to create a utilisation table if it doesn''t exist, each column as a NOT NULL constraint.
	--
	BEGIN 
		the_query := 
		'
		CREATE TABLE IF NOT EXISTS '||quote_ident(schema_name)||'.'||quote_ident(source_table)||' (nom_table text NOT NULL, traitement text NOT NULL, utilisation text NOT NULL)  WITH OIDS ;' ;
		EXECUTE the_query ; 
		RAISE NOTICE 'trying to create the source table ░▒▓%.%▓▒░	 ',schema_name,source_table; 
	END;

	--trying to update the table by registering the table given as input
	--NOTE : if row already exist : raise an exception : do nothing
	BEGIN
		the_query := 
		' INSERT INTO maquette_importation.source (nom_table, traitement, utilisation) 
			VALUES ( SELECT '|| quote_literal(table_name) ||','||quote_literal(usecase)||','||quote_literal(utilization)||'  
			WHERE NOT EXISTS ( --cheking that this record does nt already exist
				SELECT 1 
				FROM '||quote_ident(schema_name)||'.'||quote_ident(source_table)||' 
				WHERE (nom_table,traitement,utilisation) = ('|| quote_literal(table_name) ||','||quote_literal(usecase)||','||quote_literal(utilization)||') ) )
			;' ;


		the_query := 
		'
			WITH already_exists AS(
				SELECT 1 
				FROM '||quote_ident(schema_name)||'.'||quote_ident(source_table)||' 
				WHERE (nom_table,traitement,utilisation) = ('|| quote_literal(table_name) ||','||quote_literal(usecase)||','||quote_literal(utilization)||') 
			)
			INSERT INTO '||quote_ident(schema_name)||'.'||quote_ident(source_table)||'  (nom_table, traitement, utilisation) 
					VALUES ( (SELECT '|| quote_literal(table_name) ||' WHERE NOT EXISTS (SELECT * FROM already_exists)),(SELECT '||quote_literal(usecase)||' WHERE NOT EXISTS (SELECT * FROM already_exists)),(SELECT '||quote_literal(utilization)||' WHERE NOT EXISTS (SELECT * FROM already_exists))
						
					 ) 
		;';
				
		RAISE NOTICE 'trying to update the source table with this row : ░▒▓(% , % , % )▓▒░	 ',table_name, usecase, utilization; 
		BEGIN
		EXECUTE the_query ;
		EXCEPTION
			WHEN not_null_violation
			THEN RAISE NOTICE 'error while trying to update the source table with this row : ░▒▓(% , % , % )▓▒░	 
			this row already exists in table % , stopping row inserting',table_name, usecase, utilization,source_table; 
			RETURN FALSE;
		END;
	END;

RETURN TRUE;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;


/*exemple of use : use case */
SELECT maquette_importation.rc_register_imported_table('the_shapefile_name__mytablename', 'the_graphic','plani2spread','the_schema_name__maquette_importation','source');
