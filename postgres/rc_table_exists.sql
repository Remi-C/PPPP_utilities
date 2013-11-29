/*
Rémi Cura
THALES-TELECOM Terra Mobilita Project
29/08/2012

This function returns true if a table exists, and false else.
other function : returns true if a column exists in the given table

NOTE : same function with inout differnet : schema_name and table_name separated.


WARNING :prototype only, not properly tested and/or proofed
NOTE : we could have checked inside the postgres schema, but the exception-catching way is safer against data structure change.
*/
DROP FUNCTION IF EXISTS odparis.rc_table_exists(text);
CREATE OR REPLACE FUNCTION odparis.rc_table_exists(table_name_qualified text) RETURNS boolean AS
$$
DECLARE
	table_exists boolean := TRUE;

BEGIN
	EXECUTE 'SELECT 1 FROM '|| table_name_qualified || ' LIMIT 1; ' INTO table_exists;
	RETURN table_exists;
EXCEPTION 
	WHEN  undefined_table 
	THEN 
		table_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists, false name',table_name_qualified;
		RETURN table_exists;
	WHEN invalid_schema_name 
	THEN 
		table_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists, false schema',table_name_qualified;
		RETURN table_exists;
END;
$$LANGUAGE 'plpgsql';

--SELECT odparis.rc_table_exists('odparis.emplct_col');




DROP FUNCTION IF EXISTS odparis.rc_table_exists(text,text);
CREATE OR REPLACE FUNCTION odparis.rc_table_exists(schema_name text, table_name text) RETURNS boolean AS
$$
DECLARE
	table_exists boolean := TRUE;
	table_name_qualified text := schema_name || '.' || table_name ;
BEGIN
	EXECUTE 'SELECT 1 FROM '|| table_name_qualified || ' LIMIT 1; ' INTO table_exists;
	RETURN table_exists;
EXCEPTION 
	WHEN  undefined_table 
	THEN 
		table_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists, false name',table_name_qualified;
		RETURN table_exists;
	WHEN invalid_schema_name 
	THEN 
		table_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists, false schema',table_name_qualified;
		RETURN table_exists;
END;
$$LANGUAGE 'plpgsql';

--SELECT odparis.rc_table_exists('odparis'::text,'emplct_col'::text);




DROP FUNCTION IF EXISTS odparis.rc_column_exists(text,text) ;
CREATE OR REPLACE FUNCTION odparis.rc_column_exists(table_name_qualified text, column_name text) RETURNS boolean AS
$$
DECLARE
	column_exists boolean := TRUE;

BEGIN
	EXECUTE 'SELECT '||quote_ident(column_name)||' FROM '|| table_name_qualified || ' LIMIT 1; ';
	column_exists := TRUE ;
	RETURN column_exists;
EXCEPTION 
	WHEN  undefined_table 
	THEN 
		column_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists',table_name_qualified;
		RETURN column_exists;
	WHEN  invalid_schema_name 
	THEN 
		column_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists',table_name_qualified;
		RETURN column_exists;
	WHEN  	undefined_column OR duplicate_column OR ambiguous_column OR too_many_columns
	THEN 
		column_exists := FALSE ;	
		RAISE NOTICE 'the column  	░▒▓%▓▒░	in table ░▒▓%▓▒░ doesn t exists',column_name,table_name_qualified;
		RETURN column_exists;
END;
$$LANGUAGE 'plpgsql';

--SELECT odparis.rc_column_exists('odparis_test.eau','info');





DROP FUNCTION IF EXISTS odparis.rc_column_exists(text,text,text) ;
CREATE OR REPLACE FUNCTION odparis.rc_column_exists(schema_name text, table_name text, column_name text) RETURNS boolean AS
$$
DECLARE
	column_exists boolean := TRUE;
	table_name_qualified text := schema_name || '.' || table_name ;

BEGIN
	--RAISE NOTICE 'rc_column_exists : input : % % % ',$1,$2,$3;
	EXECUTE 'SELECT '||quote_ident(column_name)||' FROM '|| table_name_qualified || ' LIMIT 1; ';
	column_exists := TRUE ;
	RETURN column_exists;
EXCEPTION 
	WHEN  undefined_table 
	THEN 
		column_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists',table_name_qualified;
		RETURN column_exists;
	WHEN  invalid_schema_name 
	THEN 
		column_exists := FALSE ;	
		RAISE NOTICE 'the table 	░▒▓%▓▒░	 doesn t exists',table_name_qualified;
		RETURN column_exists;
	WHEN  	undefined_column OR duplicate_column OR ambiguous_column OR too_many_columns
	THEN 
		column_exists := FALSE ;	
		RAISE NOTICE 'the column  	░▒▓%▓▒░	in table ░▒▓%▓▒░ doesn t exists',column_name,table_name_qualified;
		RETURN column_exists;
END;
$$LANGUAGE 'plpgsql';

--SELECT odparis.rc_column_exists('odparis_test'::Text,'eau'::Text,'info');
