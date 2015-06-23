/*
Rémi Cura
THALES-TELECOM Terra Mobilita Project
29/08/2012

This function gather most common values of a column
NOTE : can be long because first staitstics are gathered by ANALYZE 


WARNING :prototype only, not properly tested and/or proofed
*/


-- Function: rc_show_content_of_a_column(text, text, text, integer)

DROP FUNCTION IF EXISTS rc_show_content_of_a_column(text, text, text, integer);

CREATE OR REPLACE FUNCTION rc_show_content_of_a_column(schema_name text, table_name text, column_name text, max_number_of_row integer)
  RETURNS SETOF record AS
$BODY$
DECLARE
    r record;
    query_for_stats text;
    query_for_results text;
BEGIN
	query_for_stats := --update pg_stats with statistics, the 'set statistics 1000' is to increase the time spent on statistics gathering.
	'
	ALTER TABLE ' || quote_ident(schema_name) ||'.' || quote_ident(table_name) ||' ALTER COLUMN '|| quote_ident(column_name) ||'  SET STATISTICS 10000; --increase the time allowed to gather statistics
	ANALYZE ' || quote_ident(schema_name) ||'.' || quote_ident(table_name) ||'('|| quote_ident(column_name) ||'); --gather statitiscs and  update pg_stats, may be long
	';

	EXECUTE query_for_stats; --update the statistics in 'pg_stats'
	
	query_for_results :=
	'
	WITH stats_table AS( --show only the part of the stats table we are interested in
		SELECT s.attname AS column_name, s.n_distinct AS nombre_valeurs_distinctes, s.most_common_vals AS most_common_vals, s.most_common_freqs AS frequency
		FROM pg_stats AS s
		WHERE schemaname ILIKE ' || quote_literal(schema_name) ||' 
			AND tablename ILIKE '|| quote_literal(table_name) ||'
	),
	number_of_common_value AS ( --calculate the max number of most_common_vals
		SELECT rc_min(max(array_length(s.most_common_vals,1)),'||max_number_of_row||') AS number_of_common_value
		FROM stats_table  AS s
		WHERE s.column_name ILIKE '|| quote_literal(column_name) ||'
	),
	max_number_of_common_value AS ( --calculate the max number of most_common_vals
		SELECT rc_min(max(array_length(s.most_common_vals,1)),'||max_number_of_row||') AS max_number_of_common_value
		FROM stats_table  AS s 
	),
	the_serie AS (
		SELECT generate_series(1, max.max_number_of_common_value) AS a_serie
		FROM max_number_of_common_value AS max
	),
	column_stats AS (
		SELECT unnest(stats_table.most_common_vals::varchar::varchar[]) AS most_commons_vals , unnest(frequency::real[]) AS frequency
		FROM   stats_table
		WHERE stats_table.column_name ILIKE '|| quote_literal(column_name) ||'
		ORDER BY frequency DESC
	),
	column_stats_with_serie AS (
		
		SELECT DISTINCT ON (frequency) rank() OVER(order by frequency DESC NULLS LAST) AS a_serie, most_commons_vals
		FROM column_stats
		ORDER BY frequency DESC
	)
	SELECT DISTINCT *
	FROM column_stats_with_serie RIGHT OUTER JOIN the_serie USING(a_serie)
	ORDER BY a_serie ;' ;

	RETURN QUERY EXECUTE query_for_results;
	RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE;

 --SELECT * FROM rc_show_content_of_a_column('odparis_filtered', 'eau', 'info',30) AS toto(a_serie bigint, most_commons_vals varchar);