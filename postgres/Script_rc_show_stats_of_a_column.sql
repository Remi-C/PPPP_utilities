/*
Remi Cura
THALES 

script to show stats about a column
see function rc_show_stats_of_a_column for mor informations
*/


--ALTER TABLE arbres ALTER COLUMN lib_etat_c SET STATISTICS 1000;
--ANALYZE VERBOSE arbres(lib_etat_c);
/*

WITH stats_table AS( --show only the part of the stats table we are interested in
	SELECT s.attname AS column_name, s.n_distinct AS nombre_valeurs_distinctes, s.most_common_vals AS most_common_vals, s.most_common_freqs AS frequency
	FROM pg_stats AS s
	WHERE schemaname ILIKE 'odparis' 
		AND tablename ILIKE 'arbres'
),
number_of_common_value AS ( --calculate the max number of most_common_vals
	SELECT rc_min(max(array_length(s.most_common_vals,1)),15) AS number_of_common_value
	FROM stats_table  AS s
	WHERE s.column_name ILIKE 'lib_type_e'
),
max_number_of_common_value AS ( --calculate the max number of most_common_vals
	SELECT rc_min(max(array_length(s.most_common_vals,1)),15) AS max_number_of_common_value
	FROM stats_table  AS s 
),

the_serie AS (
	SELECT generate_series(1, max.max_number_of_common_value) AS a_serie
	FROM max_number_of_common_value AS max
),
column_stats AS (
SELECT unnest(stats_table.most_common_vals::varchar::varchar[]) AS most_commons_vals , unnest(frequency::real[]) AS frequency
FROM   stats_table
WHERE stats_table.column_name ILIKE 'lib_type_e'
ORDER BY frequency DESC
),
column_stats_with_serie AS (
	
	SELECT DISTINCT ON (frequency) rank() OVER(order by frequency DESC) AS a_serie, most_commons_vals, frequency
	--SELECT DISTINCT generate_series(1, num.number_of_common_value) AS a_serie, column_stats.*
	FROM column_stats
	ORDER BY frequency
	--ORDER BY frequency DESC 
)
SELECT DISTINCT *
FROM column_stats_with_serie RIGHT OUTER JOIN the_serie USING(a_serie)
ORDER BY a_serie



--RIGHT OUTER JOIN the_serie USING(a_serie)



;




-- Query to join 2 stats result for 2 difreent column of a sma&e tbale together 
WITH lib_type_e AS (
	SELECT lib_type_e.* 
	FROM rc_show_stats_of_a_column('odparis','arbres','lib_type_e',15) AS lib_type_e(a_serie integer, most_commons_vals varchar, frequency real)
),
lib_etat_c AS (
	SELECT lib_etat_c.*
	FROM rc_show_stats_of_a_column('odparis','arbres','lib_etat_c',15) AS lib_etat_c(a_serie integer, most_commons_vals varchar, frequency real)
)
SELECT * FROM lib_type_e LEFT OUTER JOIN lib_etat_c USING(a_serie);


--query to get the number of the column names of a table 
WITH list_column_names AS( --get the list of the column name in the same order as in the pg_stats table

	SELECT s.attname AS column_name
	FROM pg_stats AS s
	WHERE schemaname ILIKE 'odparis' 
		AND tablename ILIKE 'arbres'
)
SELECT count(*)
FROM list_column_names


--query to  join 2 columns_stats table 
SELECT * FROM 
		rc_show_stats_of_a_column('odparis','eau','gid',15) AS column_stats(a_serie bigint, gid varchar, gid_frequency real) 
		LEFT OUTER JOIN 
			( SELECT * FROM 
			 rc_show_stats_of_a_column('odparis','eau','geom',15) AS column_stats(a_serie bigint, geom varchar, geom_frequency real) 
			) AS geom
		USING(a_serie)
		 
		LEFT OUTER JOIN 
			( SELECT * FROM 
			 rc_show_stats_of_a_column('odparis','eau','libelle',15) AS column_stats(a_serie bigint, libelle varchar, libelle_frequency real) 
			) AS libelle
		USING(a_serie)
		 
		LEFT OUTER JOIN 
			( SELECT * FROM 
			 rc_show_stats_of_a_column('odparis','eau','info',15) AS column_stats(a_serie bigint, info varchar, info_frequency real) 
			) AS info
		USING(a_serie)
        
        */