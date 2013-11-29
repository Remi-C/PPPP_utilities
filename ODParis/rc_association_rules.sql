/*
*Rémi Cura , 14/09/2012
*THALES T&S  &  TELECOM ParisTech
*CONFIDENTIAL
*
*This function snap all geom in a table to a grid and put it in another table 
*
*/


/*
function prototype : 
_loop on each table with geom in schema
	_execute snap to grid
	_put result of snapping in a new common table, along with source_table_name and info

_create a set of points at grid crossing with an unique id
_snap this points to the same grid to be really sure

_loop on each of those points
	_get intersecting geom from common table
	_write (distinct) intersecting geom info in an array next to point
_launch 
*/

/*creating a table 
gid | info |libelle |geom
which contains signalisation, barriere, eclairage_public, detail_de_bati
*/
	----creating the association table structure
	--
	CREATE TABLE IF NOT EXISTS odparis_test.association ( LIKE odparis_reworked.signalisation  INCLUDING ALL)

	----dropping useless columns
	--
	ALTER TABLE odparis_test.association DROP COLUMN geom_surface;
	ALTER TABLE odparis_test.association DROP COLUMN geom_concsurface;
	ALTER TABLE odparis_test.association DROP COLUMN area_surface;
	ALTER TABLE odparis_test.association DROP COLUMN area_concsurface;
	ALTER TABLE odparis_test.association DROP COLUMN cluster_id;

	---checking result 
	--
	SELECT info, libelle
	FROM odparis_test.association
	GROUP BY info, libelle
	ORDER BY info ASC

	----inserting several table into association
	--
	WITH count_association AS (
		SELECT max(gid) AS max_gid
		FROM odparis_test.association
	)
	INSERT INTO odparis_test.association 
		SELECT 	gid+ c_a.max_gid AS gid
			,info
			,libelle
			,geom
		FROM odparis_reworked.signalisation , count_association AS c_a;

	WITH count_association AS (
		SELECT max(gid) AS max_gid
		FROM odparis_test.association
	)
	INSERT INTO odparis_test.association 
		SELECT 	gid+ c_a.max_gid AS gid
			,info
			,libelle
			,geom
		FROM odparis_reworked.barriere, count_association AS c_a;
	COMMIT TRANSACTION;
	
	WITH count_association AS (
		SELECT max(gid) AS max_gid
		FROM odparis_test.association
	)
	INSERT INTO odparis_test.association 
		SELECT 	gid+ c_a.max_gid AS gid
			,info
			,libelle
			,geom
		FROM odparis_reworked.borne, count_association AS c_a;
	COMMIT TRANSACTION;
	WITH count_association AS (
		SELECT max(gid) AS max_gid
		FROM odparis_test.association
	)
	INSERT INTO odparis_test.association 
		SELECT 	gid+ c_a.max_gid AS gid
			,info
			,libelle
			,geom
		FROM odparis_reworked.eclairage_public , count_association AS c_a;
	COMMIT TRANSACTION;
	WITH count_association AS (
		SELECT max(gid) AS max_gid
		FROM odparis_test.association
	)
	INSERT INTO odparis_test.association 
		SELECT 	gid+ c_a.max_gid AS gid
			,info
			,libelle
			,geom
		FROM odparis_reworked.mobilier_urbain, count_association AS c_a;
	COMMIT TRANSACTION;
	WITH count_association AS (
		SELECT max(gid) AS max_gid
		FROM odparis_test.association
	)
	INSERT INTO odparis_test.association 
		SELECT 	gid+ c_a.max_gid AS gid
			,info
			,libelle
			,geom
		FROM odparis_reworked.trottoir , count_association AS c_a;
	WITH count_association AS (
		SELECT max(gid) AS max_gid
		FROM odparis_test.association
	)
	INSERT INTO odparis_test.association 
		SELECT 	gid+ c_a.max_gid AS gid
			,info
			,libelle
			,geom
		FROM odparis_reworked.detail_de_bati , count_association AS c_a;
	

	----trying to generate data for association rules ming algorithm using a grid
	--
		----generating a grid used to snap 
		--doing this in qgis : size of each cell : 10 meters
		--name of the table : odparis_test.__grille_centree_repu_x_egal_10
		SELECT *
		FROM odparis_test.__grille_centree_repu_x_egal_10


		----the table odparis_reworked.detail_de_bati seems to be corrupted, trying to clean it. Also no index, recreating it
		--
		VACUUM odparis_reworked.detail_de_bati
		CREATE INDEX detail_de_bati_gist_index ON odparis_reworked.detail_de_bati USING GIST(geom);
		CREATE INDEX detail_de_bati_btree_index ON odparis_reworked.detail_de_bati USING btree (info);
		ANALYZE odparis_reworked.detail_de_bati


		----creating a trnasaction table with result of intersect on grid and association.
		--NOTE : the result is not in the right form to be used
		DROP TABLE IF EXISTS odparis_test.transaction_grille_temp;
		CREATE TABLE odparis_test.transaction_grille_temp AS
		SELECT DISTINCT grille.id AS transaction_id, assoc.info AS product_id
		FROM odparis_test.__grille_centree_repu_x_egal_10 AS grille, odparis_test.association AS assoc
		WHERE ST_Intersects(grille.geom, assoc.geom)=TRUE

		----creating a canonical transaction result : a transaction id (the cell grid id) and an array of associated products
		--
		DROP TABLE IF EXISTS odparis_test.transaction_grille;
		CREATE TABLE odparis_test.transaction_grille WITH OIDS AS
		SELECT transaction_id , array_agg(product_id) AS product_id_array
		FROM odparis_test.transaction_grille_temp
		GROUP BY transaction_id

		----showing result with some filter based on wanted data type and min length 
		--
		SELECT *
		FROM odparis_test.transaction_grille
		WHERE ARRAY['SIG_PVPPAPI'] <@ product_id_array
		AND array_length(product_id_array,1)>=2
		ORDER BY array_length(product_id_array,1) DESC

		----test on array
		-- a test to see if 2 array contains same values
		SELECT (ARRAY[1,2,4] <@ ARRAY[2,4,1] AND ARRAY[1,2,4] @> ARRAY[2,4,1])


	----CREATING A SAMPLE TABLE : 10k rows taken randomly from association
	--
	CREATE TABLE IF NOT EXISTS odparis_test.association_sample ( LIKE odparis_test.association  INCLUDING ALL);
	INSERT INTO odparis_test.association_sample
		SELECT 	*
		FROM odparis_test.association
		ORDER BY random()
		LIMIT 10000;

		----checking created table
		--
		SELECT *
		FROM odparis_test.association_sample

		----updating newgeom_column with computed geom
		--
		UPDATE odparis_test.association_sample SET geom_buffer_conv = St_ConvexHull(ST_Buffer(geom, 5 ,'quad_segs=4')); --computing new geom
		----taking care of perf
		--
		CREATE INDEX association_sample_geom_buffer_conv_index ON odparis_test.association_sample USING gist(geom_buffer_conv); --creating an index on newgeom 
		VACUUM ANALYZE odparis_test.association_sample ; --updating stats and cleaning table
		ALTER TABLE odparis_test.association_sample ALTER COLUMN geom_buffer_conv SET DATA TYPE geometry(polygon,0); --ading new geom column
		
		----for each pedestrian crosswalk, getting the info of intersecting geometries
		--
		DROP TABLE IF EXISTS odparis_test.transaction_pedestrian_temp;
		CREATE TABLE odparis_test.transaction_pedestrian_temp AS
		SELECT DISTINCT pedestrian.gid AS transaction_id, assoc.info AS product_id
		FROM odparis_reworked.signalisation AS pedestrian, odparis_test.association_sample AS assoc
		WHERE ST_Intersects(pedestrian.geom, assoc.geom)=TRUE 
			AND pedestrian.info = 'SIG_PVPPAPI'


		----putting the result in canonical form : 
		--a transaction id and a list of object id.
		--
		DROP TABLE IF EXISTS odparis_test.transaction_pedestrian;
		CREATE TABLE odparis_test.transaction_pedestrian WITH OIDS AS
		SELECT transaction_id , array_agg(product_id) AS product_id_array
		FROM odparis_test.transaction_pedestrian_temp
		GROUP BY transaction_id

		----showing result
		--
		SELECT * , array_length(product_id_array,1)
		FROM odparis_test.transaction_pedestrian
		WHERE array_length(product_id_array,1)>=2
		ORDER BY array_length(product_id_array,1) DESC

		----trying to count each category based on length, generating stats
		WITH the_count AS (
			SELECT count(array_length(product_id_array,1)) AS category_count, array_length(product_id_array,1) AS array_length
			FROM odparis_test.transaction_pedestrian
			GROUP BY array_length(product_id_array,1)
		)
		SELECT category_count*1.0 / (SELECT sum(category_count) FROM the_count) AS stats , array_length
		FROM the_count
		
	-----trying to generate data for association rules mining algorithm using a 10 meter buffer around objects
	--focusing on pedestrian crosswalk

		----test on new geom column computing time to find optimum
		--
		
		

		---- generating a new geom column to do intersection test : 10 meter buffer, using convex hull
		--
		ALTER TABLE odparis_test.association ADD COLUMN geom_buffer_conv geometry; --ading new geom column
		UPDATE odparis_test.association SET geom_buffer_conv = St_ConvexHull(ST_Buffer(geom, 5 ,'quad_segs=4')) --computing new geom

		

		--///CURSEUR DE LA SUITE DU CODE A EXECUTER\\\
		CREATE INDEX association_geom_buffer_conv_index ON odparis_test.association USING gist(geom_buffer_conv); --creating an index on newgeom 
		VACUUM ANALYZE odparis_test.association ; --updating stats and cleaning table


		----we focus on pedstrian crosswalk
		--id : 'SIG_PVPPAPI'
		--we want to get a list of objects at less than 10 meter from pedestrian wrosswalk
		--then we get corresponding info

		----analyzing count of pedestrian crosswalk :
		--
		SELECT count(*)
		FROM odparis_reworked.signalisation
		WHERE info = 'SIG_PVPPAPI'
		-- => 54 k pedstrian crosswalks in paris

		--note : we should fuse linestring of pedestrina crosswalk because in odparis data ONE crosswalk in represented by (at least) 2 (roughly) parallel linestring.

		----for each pedestrian crosswalk, getting the info of intersecting geometries
		--
		DROP TABLE IF EXISTS odparis_test.transaction_pedestrian_temp;
		CREATE TABLE odparis_test.transaction_pedestrian_temp AS
		SELECT DISTINCT pedestrian.gid AS transaction_id, assoc.info AS product_id
		FROM odparis_reworked.signalisation AS pedestrian, odparis_test.association AS assoc
		WHERE ST_Intersects(pedestrian.geom, assoc.geom)=TRUE 
			AND pedestrian.info = 'SIG_PVPPAPI';


		----putting the result in canonical form : 
		--a transaction id and a list of object id.
		--
		DROP TABLE IF EXISTS odparis_test.transaction_pedestrian;
		CREATE TABLE odparis_test.transaction_grille WITH OIDS AS
		SELECT transaction_id , array_agg(product_id) AS product_id_array
		FROM odparis_test.transaction_pedestrian_temp
		GROUP BY transaction_id;


		
