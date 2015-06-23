/* Rémi C 
Thales  

rc_show_stats_of_a_table(schema_name text, table_name text, max_number_of_row integer)
this function looks in pg_stats table to gather statistics abouta table regarding the most common values and the associated frequency, the output max number of row is controlled by max_number_of_row

The function does as follow :



WARNING : prototype only: not really tested
Not safe in any way.
Not optimal : the 'for' loop is not optimal and is only here for output reasons
*/


DROP FUNCTION IF EXISTS rc_show_stats_of_a_table(text,text,integer);

CREATE OR REPLACE FUNCTION rc_show_stats_of_a_table(schema_name text, table_name text, max_number_of_row integer)
  RETURNS refcursor AS
$$
DECLARE
	test_cursor refcursor := 'test_cursor';
	r record;
	first_column_query text;
	for_query text;
	the_query text;
	number_of_column_query text;
	number_of_column integer;
	first_column_name text;
    
BEGIN
	for_query := ' -- returns rows containing column names
		WITH list_column_names AS( --get the list of the column name in the same order as in the pg_stats table

		SELECT s.attname AS column_name
		FROM pg_stats AS s
		WHERE schemaname ILIKE '||quote_literal(schema_name) ||' 
			AND tablename ILIKE '||quote_literal(table_name) ||'
		ORDER BY s.n_distinct ASC
		OFFSET 1
	)
	SELECT *
	FROM list_column_names;' ;

	first_column_query := ' -- returns one row containing the first column name
		WITH list_column_names AS( --get the list of the column name in the same order as in the pg_stats table

		SELECT s.attname AS column_name
		FROM pg_stats AS s
		WHERE schemaname ILIKE '||quote_literal(schema_name) ||' 
			AND tablename ILIKE '||quote_literal(table_name) ||'
		ORDER BY s.n_distinct ASC
		LIMIT 1
	)
	SELECT *
	FROM list_column_names;' ;

	number_of_column_query := ' --returns one row containing column number
		WITH list_column_names AS( --get the list of the column name in the same order as in the pg_stats table
		SELECT s.attname AS column_name
		FROM pg_stats AS s
		WHERE schemaname ILIKE '||quote_literal(schema_name) ||' 
			AND tablename ILIKE '||quote_literal(table_name) ||'
		OFFSET 1
	)
	SELECT count(*)
	FROM list_column_names;' ;

	EXECUTE number_of_column_query INTO number_of_column;
	EXECUTE first_column_query INTO first_column_name;
	RAISE NOTICE 'number_of_column : %, first column name : %',number_of_column,first_column_name;

	
	the_query := 'SELECT * FROM 
		rc_show_stats_of_a_column('||quote_literal(schema_name)||','||quote_literal(table_name)||','||quote_literal(first_column_name)||','||max_number_of_row||') AS column_stats(a_serie bigint, '||first_column_name||' varchar, '||first_column_name||'_frequency real) ' ;
	
	
	--loop on all the columns of the table :
	FOR r IN EXECUTE for_query --r.column_name contains the name of the column
	LOOP
		the_query :=
		' 
			' ||the_query || '
		LEFT OUTER JOIN 
			( SELECT * FROM 
			 rc_show_stats_of_a_column('||quote_literal(schema_name)||','||quote_literal(table_name)||','||quote_literal(r.column_name)||','||max_number_of_row||') AS column_stats(a_serie bigint, '||r.column_name||' varchar, '||r.column_name||'_frequency real) 
			) AS '||r.column_name||'
		USING(a_serie)
		 ';
		 RAISE NOTICE 'current_column_name : %',r.column_name;
	END LOOP;
	the_query := the_query || ';' ; --adding a end statemetn of the query

	OPEN test_cursor FOR EXECUTE the_query;
	RETURN test_cursor ;
END;
$$ LANGUAGE plpgsql;

/*
-- exemple use-case 
SELECT rc_show_stats_of_a_table('odparis','eau',15);
fetch all from test_cursor;
*/
