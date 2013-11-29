

/* --Test on null objetc and object with 'Objet sans identi...' as libelle
WITH table_source AS(
	SELECT * 
	FROM odparis_test.detail_de_bati

),
liste_info_null AS(
	SELECT *
	FROM table_source
	WHERE info IS NULL
),
	nbr_info_null AS(
		SELECT count(*)
		FROM liste_info_null
	),
liste_libelle_null AS(
	SELECT *
	FROM table_source
	WHERE libelle IS NULL
),
	nbr_libelle_null AS(
		SELECT count(*)
		FROM liste_libelle_null
	),
liste_libelle_objet AS(
	SELECT *
	FROM table_source
	WHERE libelle ~* '.*Objet.*'
),
	nbr_libelle_objet AS(
		SELECT count(*)
		FROM liste_libelle_objet
	),
liste_info_null_libelle_objet AS(
	SELECT *
	FROM table_source
	WHERE 	info IS NULL
		AND libelle ~* '.*Objet.*'
),
	nbr_info_null_libelle_objet AS(
		SELECT count(*)
		FROM liste_info_null_libelle_objet
	),
liste_info_nonull_libelle_objet AS(
	SELECT *
	FROM table_source
	WHERE 	info IS NOT NULL
		AND libelle ~* '.*Objet.*'
),
	nbr_info_nonull_libelle_objet AS(
		SELECT count(*)
		FROM liste_info_nonull_libelle_objet
	)


SELECT 	nbr_info_null.* AS __nbr_info_null,
	nbr_libelle_null.* AS __nbr_libelle_null, 
	nbr_libelle_objet.* AS __nbr_libelle_objet, 
	nbr_info_null_libelle_objet.* AS __nbr_info_null_libelle_objet, 
	nbr_info_nonull_libelle_objet.* AS __nbr_info_nonull_libelle_objet
	
FROM nbr_info_null, nbr_libelle_null,nbr_libelle_objet, nbr_info_null_libelle_objet, nbr_info_nonull_libelle_objet


SELECT distinct libelle, info, count(info),(SELECT count(*) FROM table_source), Round(count(info)*100.0/(SELECT count(*) from table_source),3) AS Pourcentage_De_Presence
FROM table_source
group by libelle, info
ORDER BY Pourcentage_De_Presence DESC

*/



--UPDATE odparis_reworked.sanisette SET libelle = libelle::TEXT || ' 2' WHERE info = 'WCH2';

--DELETE FROM odparis_reworked.assainissement WHERE info = '3' ;

/* script to show content of a table (fast way, using pg_stats)
ANALYZE odparis_reworked.arbre;
SELECT rc_show_content_of_a_table('odparis_reworked','arbre',60);
FETCH ALL FROM test_cursor
*/


/*This instructions execute fusion of bati to detail_de_bati

DROP TABLE IF EXISTS odparis_test.detail_de_bati;
DROP TABLE IF EXISTS odparis_test.bati;
SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','bati');
SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','detail_de_bati');
vacuum odparis_test.detail_de_bati;
analyze odparis_test.detail_de_bati;
vacuum odparis_test.bati;
analyze odparis_test.bati;
ALTER TABLE odparis_test.detail_de_bati ADD COLUMN niveau text DEFAULT 'unknown' ;
WITH number_of_rows AS(SELECT max(gid) AS nbr_o_r
FROM odparis_test.detail_de_bati)

WITH max_gid AS(SELECT max(gid) AS m_g
FROM odparis_test.borne)
INSERT INTO odparis_test.detail_de_bati ( gid, info, libelle, niveau, geom ) 
	SELECT gid+max_gid.m_g ,info ,libelle , niveau, geom 
	FROM odparis_test.bati, max_gid
	ORDER BY gid ASC;
*/





/*This instructions execute fusion of poteau to borne
--DROP TABLE IF EXISTS odparis_test.poteau
--DROP TABLE IF EXISTS odparis_test.borne
--SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','borne');
--SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','poteau');
vacuum odparis_test.borne
analyze odparis_test.borne

WITH max_gid AS(SELECT max(gid) AS m_g
FROM odparis_test.borne)
INSERT INTO odparis_test.borne ( gid, info, libelle, geom ) SELECT gid+max_gid.m_g,info, libelle, geom FROM odparis_test.poteau, max_gid ORDER BY gid ASC;
*/


/*exemple use-case :*/
--SELECT tc_move_all_from_a_schema_to_another('odparis_test', 'assainissement', 'ASS');


/*PREFIX al the info column if necessary (if info value not already prefixed)

SELECT rc_change_all_libelle_info_length_in_a_schema('odparis_test'::text);

WITH info_prefixed AS(
	SELECT 
		'DDB_' || info AS i_p,
		gid AS gid_prefixed
	FROM odparis_test.detail_de_bati
	WHERE info !~* 'DDB_.*'
)
UPDATE odparis_test.detail_de_bati SET info = info_prefixed.i_p FROM info_prefixed WHERE gid = info_prefixed.gid_prefixed


SELECT info, libelle
FROM odparis_test.assainissement
GROUP BY info, libelle

DROP TABLE IF EXISTS odparis_test.assainissement;
SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','borne');
SELECT rc_change_all_libelle_info_length_in_a_schema('odparis_test'::text);
DROP TABLE IF EXISTS odparis_test.eau;
SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','eau');
SELECT rc_change_all_libelle_info_length_in_a_schema('odparis_reworked'::text);


*/


/* this query generates all the combinaison of X-Y unique where X-Y and Y-X are considered as unique
DROP TABLE IF EXISTS odparis_test.test_all_pairs;
CREATE table odparis_test.test_all_pairs AS
with the_serie AS (
SELECT generate_series AS a_serie
FROM generate_series(1,100)
)
select foo.a_serie AS col1, bar.a_serie AS col2
from the_serie as foo, the_serie as bar
WHERE foo <= bar;


SELECT count(*) FROM odparis_test.test_all_pairs
*/

/*  --exemple to select all table with geometry ina  schema
SELECT * 
FROM geometry_columns
WHERE f_table_schema ILIkE '%odparis_reworked%'
ORDER BY f_table_name ASC
*/




/*the following commands test all the fucntions sequentially
--remove all in given schema
SELECT rc_delete_all_from_a_schema('odparis_reworked');

--copy all data from schema 'odparis' to target schema
SELECT rc_copy_all_from_a_schema_to_another('odparis','odparis_reworked');


--work on data to consolidate it
SELECT rc_filtering_raw_odparis('odparis_reworked');


--change data type of info and libelle column to text : (cancel the max length)
SELECT rc_change_all_libelle_info_length_in_a_schema('odparis_reworked');



--gathering of info and libelle value for analysiso

--analysis : doesn't work for most tables ,
--triyng on idividual tables


--lauching function
SELECT rc_add_prefix_to_info_column('odparis_reworked',ARRAY['assainissement','eau'],ARRAY['ASS','EAU']);
SELECT rc_add_prefix_to_info_column('odparis_test'::Text,'assainissement','ASS');

--analysing
SELECT * FROM rc_gather_info_libelle_columns('odparis_reworked','transport_public');
SELECT * FROM rc_gather_info_libelle_columns('odparis_reworked','eau') UNION ALL
SELECT * FROM rc_gather_info_libelle_columns('odparis_reworked','assainissement');
*/










/*
--print all categories
SELECT info,libelle
FROM odparis_test.borne_index
GROUP BY info,libelle;
*/

/*

--show all records for info = BOR_BAV
SELECT info,libelle
FROM odparis_test.borne_index
WHERE info = 'BOR_PIV';



*/


/*create an inndex for the info column*/


/*test on index*/
--create a borne table
SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','borne');
--rename it
ALTER TABLE odparis_test.borne RENAME TO borne_index;
--create index
CREATE INDEX info_btree_index ON odparis_test.borne_index (info);
--create a new borne table for benchmarking
SELECT rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','borne');
--create indexes on all table in the schema
SELECT rc_create_index_on_all_info_column_in_schema('odparis_test');
--create also geom indexes
SELECT rc_create_index_on_all_geom_column_in_schema('odparis_test');
--clustering selon l'index crée sur la colonne info
SELECT rc_cluster_on_info_column('odparis_test','borne');
SELECT rc_cluster_on_all_info_column_in_schema('odparis_reworked');
--test info gathering for speed eval
SELECT * FROM rc_gather_all_info_libelle_columns('odparis_test');




