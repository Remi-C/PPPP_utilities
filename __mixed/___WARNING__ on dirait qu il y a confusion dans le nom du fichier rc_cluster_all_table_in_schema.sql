
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential

This function will cluster all tbales in a schema

WARNING : prototype : non tested or proofed.

*/




DROP FUNCTION IF EXISTS odparis.rc_compute_geom_all_table_in_schema(text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION  odparis.rc_compute_geom_all_table_in_schema(schema_name text) RETURNS boolean
AS $$
DECLARE

	first_table_query text;
	the_row_before record;
	the_row record;
	result boolean;
	the_query text := ' ';
	for_query text := ' ';
BEGIN
	BEGIN --beigining of result construction
	--first table 

		
		for_query := 'SELECT DISTINCT ON(f_table_name) * 
			FROM geometry_columns 
			WHERE f_table_schema = '||quote_literal(schema_name) || ' 
			AND f_table_name <> ''nomenclature'' 
			AND f_geometry_column = ''geom''
			AND type <> ''POINT''
			AND type <> ''MULTIPOINT'' 
			ORDER BY f_table_name ASC;';
	
		FOR the_row IN EXECUTE for_query
		LOOP --loop on all tbale in schema whxih contains an info column
			BEGIN
			RAISE NOTICE 'working on : %.%',schema_name,the_row.f_table_name;

			the_query := '
				SELECT odparis.rc_compute_geom_table('||quote_literal(schema_name)||'::Text,'||quote_literal(the_row.f_table_name)||'::Text) ;';
			EXECUTE the_query;
			END;
		END LOOP;--end of query construction
		RETURN true;
	END;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT  odparis.rc_compute_geom_all_table_in_schema('odparis_reworked');






DROP FUNCTION IF EXISTS  odparis.rc_compute_geom_table(text,text);--remove the function before re-creating it : act as a security versus function-type change
/*
*this functioncompute geometrie and geometrie descriptor used for clustering using the plr function odparis.rc_plr_cluster_using_nnclust(schema_name text,table_name text,column_name text, output_column_name text);
*/
CREATE OR REPLACE FUNCTION odparis.rc_compute_geom_table(schema_name text,table_name text) RETURNS integer
AS $$
DECLARE
    result boolean;
    the_query text;
BEGIN
	----trying to create appropriate columns, skip if columns already exists
	-- 	--add a geom_surface column based on a bufferized verison of the geom
		--add a geom_concsurface column based on the concav envelop of the bufferized geom
		--add two columns to hold value of area calculation
		--add a cluster_id column to hold result of the clustering
	BEGIN 
		RAISE NOTICE 'trying to create appropriate columns, skip if columns already exists';
		the_query := '
			ALTER TABLE '||quote_ident(schema_name)||'.'|| quote_ident(table_name)||' 
			ADD COLUMN geom_surface geometry(MultiPolygon),
			ADD COLUMN geom_concsurface geometry(MultiPolygon),
			ADD COLUMN area_surface numeric,
			ADD COLUMN area_concsurface numeric,
			ADD COLUMN cluster_id bigint;';
		EXECUTE the_query ;
	EXCEPTION
		WHEN undefined_table
		THEN RAISE EXCEPTION '	this table %.% doesn''t exist, skipping geometry surface calculation',schema_name,table_name;
		RETURN 0;
		WHEN duplicate_column OR ambiguous_column
		THEN RAISE NOTICE '	this table %.% has an ambiguous column or to many of theim, skipping column creation continuing geom computing',schema_name,table_name;
	END;

	----trying to populate columns with geom and area
	--
	BEGIN
		RAISE NOTICE 'trying to populate columns with geom and area';
		the_query := '
			UPDATE '||quote_ident(schema_name)||'.'|| quote_ident(table_name)||' 
				SET geom_surface = ST_Multi(ST_CollectionExtract(ST_Buffer(geom,0.01),3)),
				geom_concsurface = ST_Multi(ST_CollectionExtract(ST_ConcaveHull(ST_Buffer(geom,0.01),0.99),3));	
			UPDATE '||quote_ident(schema_name)||'.'|| quote_ident(table_name)||'
				SET area_surface = ST_Area(geom_surface),
				area_concsurface = ST_Area(geom_concsurface); ' ;
		EXECUTE the_query ;
	--EXCEPTION	
	END;

RETURN 1;
END;
$$ LANGUAGE plpgsql; 

/*exemple of use case*/
--SELECT odparis.rc_compute_geom_table('odparis_reworked','detail_de_bati');


/*
*this function only compute the cluster of a table (NOT creatig any column and/or computing any geometry) using the plr function odparis.rc_plr_cluster_using_nnclust(schema_name text,table_name text,column_name text, output_column_name text);
*SO it is assumed hat the input sql query return :
*	first table : an unique id (bigint) : gid
*	n other table : each 1 D numeric descriptor (or int)
*NOTE : this function can apply offset to cluster_id : cluster_id_put_in_table = cluster_id_computed + cluster_offset
*/
DROP FUNCTION IF EXISTS  odparis.rc_only_compute_cluster(text,text,text,text,bigint);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_only_compute_cluster(schema_name text, table_name text, query_to_get_data text,cluster_column text,cluster_offset bigint) RETURNS boolean
AS $$
DECLARE
    result boolean;
    the_query text;
BEGIN
	----computing clustering : computing is easy, 
	-- but the table has to be updated with right gid
	--
	BEGIN
		RAISE NOTICE 'computing clustering and update column % with clusters',cluster_column;
		
		the_query := '
				UPDATE '||quote_ident(schema_name)||'.'|| quote_ident(table_name)||' AS table_to_update
			SET '||quote_ident(cluster_column)||' = CASE WHEN r.cluster_id IS NULL THEN -'||cluster_offset||' ELSE (r.cluster_id+'||cluster_offset||') END
			FROM odparis.rc_plr_cluster_using_nnclust_on_info(
				'|| quote_literal(query_to_get_data)||'::text
				, 0.0000002
				, 1
				, 0
				) AS r(gid bigint, cluster_id bigint)
			WHERE table_to_update.gid = r.gid
		;';
		EXECUTE the_query;
	--EXCEPTION
	END;

RETURN TRUE;
END;
$$ LANGUAGE plpgsql; 


/*testing the*/
/*exemple use-case :*/
/*
SELECT odparis.rc_only_compute_cluster(
	'odparis_reworked'
	,'stationnement'
	,'SELECT gid AS gid, area_surface
		FROM odparis_reworked.stationnement
		WHERE info = ''STA_HOR''
		--ORDER BY gid ASC;'::text
	,'cluster_id'
	,10);

	SELECT info, cluster_id
	FROM odparis_reworked.stationnement
	WHERE info = 'STA_HOR'
	GROUP BY info, cluster_id
	ORDER BY info ASC , cluster_id DESC

*/

/*
*	This computing clustering for all distinct value in info : we try to find cluster in each "info" distinct value.
*	The output hsould be either 1 or many : 1 if this info represent symbols, many if this info represents true geometric data
*/

DROP FUNCTION IF EXISTS  odparis.rc_compute_cluster_for_all_distinct_info_in_table(text,text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_compute_cluster_for_all_distinct_info_in_table(schema_name text, table_name text,cluster_column text) RETURNS boolean
AS $$
DECLARE
    result boolean;
    query_for_distinct_info text := '';
    the_query text;
    distinct_info record;
    the_offset bigint := 0;
    the_row record;
BEGIN
	----retrieving all distinct info value:
	--plus test
	BEGIN
	query_for_distinct_info := 
	'SELECT DISTINCT info AS info
	FROM '||quote_ident(schema_name)||'.'|| quote_ident(table_name)||' ;' ;
	
	RAISE NOTICE 'first query to get the number of distinct info : %',query_for_distinct_info;

	EXECUTE query_for_distinct_info INTO distinct_info;
	
	EXCEPTION
		WHEN undefined_column OR duplicate_column OR ambiguous_column
		THEN RAISE NOTICE 'problem with the info column, stopping clustering for all distinct info value';
		RETURN FALSE;
	END;
	--RAISE NOTICE 'distinct_info : %',distinct_info;
	
	----Loop on all distinct "info" value
	--for each distinct info value, comput clustering
	--keep record of the previous max id of cluster  --> the idea is to NOT have 2 clusters with the same id in differnet info.
	BEGIN
		FOR the_row IN EXECUTE query_for_distinct_info
		LOOP--loop on all distinct info value
		
		RAISE NOTICE '	working on info : %',the_row.info;
		
		EXECUTE '	SELECT DISTINCT max('||quote_ident(cluster_column)||') 
				FROM '||quote_ident(schema_name)||'.'|| quote_ident(table_name)||';'
		INTO the_offset;--getiing the max cluster_id of the table

		--RAISE NOTICE '	the offset : %',the_offset;

		IF the_offset IS NULL
		THEN the_offset :=0;
		END IF;
		
		the_query := 'SELECT odparis.rc_only_compute_cluster(
				'||quote_literal(schema_name)||'
				,'|| quote_literal(table_name)||'
				,'' SELECT gid AS gid, area_surface
					FROM '||quote_ident(schema_name)||'.'|| quote_ident(table_name)||'
					WHERE info = '''|| quote_literal(the_row.info) ||'''; ''::text
				,'||quote_literal(cluster_column)||'
				,'|| the_offset ||' ); ';
		EXECUTE the_query;
		----compute the max cluster_id of the calculated cluster
		--
		 --get the max cluster_id, so no cluster_id with different info can have same id.
		END LOOP;
	END;
RETURN TRUE;
END;
$$ LANGUAGE plpgsql; 


/*test case :*/
--SELECT odparis.rc_compute_cluster_for_all_distinct_info_in_table('odparis_reworked', 'jardin','cluster_id');
--SELECT odparis.rc_compute_cluster_for_all_distinct_info_in_table('odparis_test', 'assainissement','cluster_id');


/*
this function will compute clustering for each table for each distinct info value and will gie incrementing cluster_id in a same table
EXCEPT for data based on point : no need to try to cluster it by surface !
NOTE : comes with a test_output mode : no query is executed instead a text query is created with lots of commit.
*/

DROP FUNCTION IF EXISTS  odparis.rc_compute_cluster_for_all_distinct_info_in_schema(boolean,text,text);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION odparis.rc_compute_cluster_for_all_distinct_info_in_schema(text_output boolean, schema_name text,cluster_column text) RETURNS text
AS $$
DECLARE
    query_for_distinct_info text := '';
    the_query text;
    distinct_info record;
    the_offset bigint := 0;
    the_row record;
    for_query text;
    output_query text := '';
BEGIN
	for_query := 'SELECT DISTINCT ON (f_table_name) * 
			FROM geometry_columns 
			WHERE f_table_schema = '||quote_literal(schema_name) || ' 
			AND f_table_name <> ''nomenclature'' 
			AND f_geometry_column = ''geom''
			AND type <> ''POINT''
			AND type <> ''MULTIPOINT''
			ORDER BY f_table_name ASC;';
	
		FOR the_row IN EXECUTE for_query
		LOOP --loop on all table in schema whxih contains an info column
			BEGIN
			RAISE NOTICE 'working on : %.%',schema_name,the_row.f_table_name;
			
			
			the_query := 
				'SELECT odparis.rc_compute_cluster_for_all_distinct_info_in_table('||quote_literal(schema_name)||', '||quote_literal(the_row.f_table_name)||','||quote_literal(cluster_column)||');';
				--RAISE NOTICE 'coucou';
				IF text_output = FALSE
					THEN EXECUTE the_query;
					ELSE output_query := output_query  ||
					'
					BEGIN;
					' ||the_query || ' COMMIT; 
					END; 
					'  ;
				END IF;
			END;
		END LOOP;--end of query construction
	IF text_output = FALSE
		THEN RETURN 'TRUE';
		ELSE RETURN output_query;  
	END IF;
			
RETURN 'TRUE';
END;
$$ LANGUAGE plpgsql; 


/*test case :*/
--SELECT odparis.rc_compute_cluster_for_all_distinct_info_in_schema(TRUE,'odparis_reworked'::text,'cluster_id'::text);
--SELECT odparis.rc_compute_cluster_for_all_distinct_info_in_table('odparis_reworked', 'detail_de_bati','cluster_id');


