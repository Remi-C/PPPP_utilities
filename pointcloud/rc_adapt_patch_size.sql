---------------
--Remi C 09/2014
--
--------------
--function to adapt patch size so the patch density is bounded in given range


-- CREATE SCHEMA IF NOT EXISTS test_grouping ;
-- SET search_path to test_grouping , rc_lib, public ; 


--create test table
	/*
	DROP TABLE IF EXISTS copy_bench; 
	TRUNCATE copy_bench ;

	CREATE TABLE copy_bench  ( -- LIKE benchmark_cassette_2013.riegl_pcpatch_space INCLUDING ALL) 
		LIKE medical. stereo_medical INCLUDING ALL);
	INSERT INTO copy_bench 
	SELECT *,  patch::geometry(polygon,0) AS geom
		,  PC_NumPoints( patch) AS num_points
		, 0.01::float AS spatial_size
		, NULL AS merged_split
		, pc_patchavg(patch,'z') AS z
		, NULL -- pc_patchavg(patch,'gps_time') AS avg_time 
	FROM medical. stereo_medical -- benchmark_cassette_2013.riegl_pcpatch_space
	WHERE ST_DWIthin(patch::geometry, ST_SetSRID(ST_MakePoint(1907.18,21165.05),932011),50)=TRUE; 

	  

	ALTER TABLE copy_bench ADD COLUMN geom   geometry(polygon,932011)  ;
	CREATE INDEX ON copy_bench USING GIST(geom) ;
	ALTER TABLE copy_bench ADD COLUMN num_points   float ;
	CREATE INDEX ON copy_bench  (num_points) ;
	ALTER TABLE copy_bench ADD COLUMN spatial_size   float ;
	CREATE INDEX ON copy_bench  (spatial_size) ;
	ALTER TABLE copy_bench ADD COLUMN merged_split   SMALLINT ;
	CREATE INDEX ON copy_bench  (merged_split) ;
	-- -1 means merging, +1 means split
	ALTER TABLE copy_bench ADD COLUMN avg_z   float ;
	CREATE INDEX ON copy_bench  (avg_z) ; 
	ALTER TABLE copy_bench ADD COLUMN avg_time   float ;
	CREATE INDEX ON copy_bench  (avg_time) ; 

	UPDATE copy_bench SET geom = patch::geometry(polygon,932011) ;  
	UPDATE copy_bench SET num_points = PC_NumPoints(patch); 
	UPDATE copy_bench SET avg_z =pc_patchavg(patch,'z'); 
	UPDATE copy_bench SET avg_time =pc_patchavg(patch,'gps_time'); 

	UPDATE copy_bench_3  SET spatial_size =1.0 ; 
*/


--???define the function used for range indexing on an atribute???--
	
	----
	--delete function if it exists
	DROP FUNCTION IF EXISTS  rc_adapt_patch_size(int ,  int, int); 
	CREATE OR REPLACE FUNCTION rc_adapt_patch_size(patch_id int, min_density INT, max_density INT)
	RETURNS INT AS $$ 
	DECLARE
		_useless int[] ;
		_useless2 int ;  
		_to_work_on int[];
		_ipatch PCPATCH ; 
		_size FLOAT ; 
		_num_points float ; 
		_merged_split INT; 
		_sum_n_points INT;  
	BEGIN
	/** given a patch id, this function may merge it or split it, so it fits in the target density */
	--get the patch patch, numpoints, merged_split, size 
	SELECT patch, num_points, merged_split, COALESCE(spatial_size,1) INTO _ipatch, _num_points, _merged_split, _size 
	FROM copy_bench WHERE gid = patch_id ; 
	
	--shall we split the patch (too big and was not merged)?
	IF _num_points > max_density AND (_merged_split != -1 OR _merged_split IS NULL) THEN
		WITH points AS (
			SELECT *
			FROM pc_explode(_ipatch) as pt, CAST(pt AS geometry) AS point, st_x(point) as x, st_y(point) as y, st_z(point) as z -- pc_get(pt,'x') x , pc_get(pt,'y') y , pc_get(pt,'z') z 
				-- , pc_get(pt,'gps_time') gps_time 
		)
		, patches AS (
			SELECT pc_patch(pt) as n_patch
			FROM points
			GROUP BY floor(x/(_size/2.0)), floor(y/(_size/2.0)), floor(z/(_size/2.0)) --, floor(gps_time/(_size/2.0))  
		)
		, deleting_patch AS (
			DELETE FROM copy_bench WHERE gid = patch_id RETURNING gid )
		, inserting_patch AS (
			INSERT INTO copy_bench (patch,spatial_size, merged_split)
			SELECT n_patch , _size/2.0 ,  +1
			FROM patches
			RETURNING gid, patch
		) 
		SELECT array_agg(gid)  INTO _useless FROM inserting_patch ; 

		RETURN array_length(_useless,1); 
		
	ELSIF _num_points < min_density AND (_merged_split != 1 OR _merged_split IS NULL )
	THEN
	--	RAISE NOTICE 'merging' ;  

		WITH patches_candidates AS( 
			SELECT gid, geom, patch, num_points
			FROM copy_bench AS cp, ST_Centroid(_ipatch::geometry) as centre
				, ST_Centroid( cp.geom) as candidate_centre	
			WHERE ST_DWithin(geom, _ipatch::geometry, _size * 2) -- to use indexes
				AND floor(ST_X(centre) / (2.0*_size) ) = floor(ST_X(candidate_centre) / (2.0*spatial_size) )
				AND floor(ST_Y(centre) / (2.0*_size) ) = floor(ST_Y(candidate_centre) / (2.0*spatial_size) )
				AND floor(pc_patchavg(_ipatch,'z') / (2.0*_size) ) = floor(avg_z / (2.0*spatial_size) )
				--AND floor(pc_patchavg(_ipatch,'gps_time') / (2*_size) ) = floor(avg_time / (2*spatial_size) )
				AND (cp.merged_split  != +1 OR cp.merged_split IS NULL) 
				AND num_points < max_density  
		)
		SELECT array_agg(gid), sum(num_points) INTO _to_work_on , _sum_n_points
		FROM patches_candidates; 

		IF array_length(_to_work_on,1) > 1 AND _sum_n_points < max_density THEN --only merging if more than one patch to merge !
			WITH patches_candidates AS (
				SELECT gid, geom, patch, spatial_size
				FROM copy_bench AS cp
				WHERE cp.gid = ANY (_to_work_on) 
			)
			, inserting_merged_patch AS (
				INSERT INTO copy_bench (patch, spatial_size, merged_split)
				SELECT pc_union(patch) , greatest(_size,max(spatial_size))* 2.0 , -1
				FROM patches_candidates  
				WHERE (
					SELECT count(*)
					FROM patches_candidates
				) > 1
			RETURNING gid
			)
			, deleting_old_patches AS (
				DELETE FROM copy_bench
				WHERE EXISTS ( SELECT 1 
					FROM patches_candidates
					WHERE copy_bench.gid = patches_candidates.gid )
				RETURNING gid
			)
			SELECT (select array_agg(-1*gid) from deleting_old_patches), (select * from inserting_merged_patch) 
				INTO _useless, _useless2 ; 
		ELSE
			--simply put a 0 in merged_split to show it has been considered
			UPDATE copy_bench AS cp
			SET merged_split = 0  
			WHERE gid  = patch_id; 
		END IF ; 
		RETURN sign(_useless[1]) * array_length(_useless,1);  

	ELSE
		--indicating that nothing can be done for this patch
		UPDATE copy_bench AS cp
			SET merged_split = 0  
			WHERE gid  = patch_id ; 
		RETURN NULL ;	
	END IF ; 
	
	RETURN NULL; END ; 
	$$ LANGUAGE 'plpgsql' VOLATILE CALLED ON NULL INPUT; 


--creating a trigger to recompute   geom, num_points,  avg_z, avg_time when inserting or updating
	/*
	CREATE OR REPLACE FUNCTION rc_update_patch_in_copy_bench(  )
	  RETURNS  trigger  AS
	$BODY$ 
		--update secondary fields 
			DECLARE  
			BEGIN  
			--	RAISE NOTICE 'updating' ;
				NEW.geom := NEW.patch::geometry(polygon,932011) ;  
				NEW.num_points := PC_NumPoints(NEW.patch); 
				NEW.avg_z := pc_patchavg(NEW.patch,'z'); 
				NEW.avg_time := pc_patchavg(NEW.patch,'gps_time'); 

				IF NEW.spatial_size IS NULL THEN NEW.spatial_size := 1; END IF ; 

			--	RAISE NOTICE 'NEW.geom : %, NEW.num_points % , NEW.avg_z % , NEW.avg_time % ', NEW.geom, NEW.num_points, NEW.avg_z, NEW.avg_time ; 
				 
			RETURN NEW;
			END ;
			$BODY$
	  LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT;

	DROP TRIGGER IF EXISTS  rc_update_patch_in_copy_bench ON test_grouping.copy_bench; 
	CREATE  TRIGGER rc_update_patch_in_copy_bench   BEFORE  INSERT OR UPDATE 
	    ON test_grouping.copy_bench
	 FOR EACH ROW  
	 WHEN (NEW.geom IS NULL OR  NEW.num_points IS NULL OR  NEW.avg_z IS NULL OR NEW.avg_time IS NULL)
	    EXECUTE PROCEDURE rc_update_patch_in_copy_bench(); 
	*/
  
    
/* -- testing

SELECT *
	FROM copy_bench , rc_adapt_patch_size(
		patch_id:= gid 
		, min_density:=100
		, max_density:=1000
		) 
	WHERE (--num_points < 100 or 
		num_points > 1000 ) 
		AND COALESCE(merged_split,-1) != 0 
	ORDER BY gid ASC 
 LIMIT 1

*/ 

-- writting point cloud result to file
	/*
	COPY  ( 
		SELECT  round(pc_get(pt,'x')::numeric,3) AS x, round(pc_get(pt,'y')::numeric,3) AS y, round(pc_get(pt,'z')::numeric,3) AS z,  gid  , spatial_size, ln(spatial_size)/ln(2) AS ss_log
		FROM copy_bench,pc_explode(patch) as pt --  rc_exploden_random(patch,300) AS pt
		--LIMIT  10000
	)TO '/media/sf_E_RemiCura/PROJETS/articles_ISPRS_Geospatial_Week/experiments/grouping_rules/variable_patch_size/export_pointcloud_patch_merged_random_medical.csv'
	WITH HEADER CSV; 
	*/

-- writting histogram to file
	/*
	WITH npoints_copy_bench_2 AS (
		SELECT  array_agg( num_points -- log(num_points)
			) as np1
		FROM copy_bench_2 
		WHERE num_points BETWEEN 1 AND 100000
	 )
	 , npoints_copy_bench AS (
		SELECT array_agg(   num_points -- log(num_points)
			) as np2
		FROM copy_bench
		WHERE num_points BETWEEN 1 AND 100000
	 )
	 SELECT r.*
	 FROM npoints_copy_bench_2,   npoints_copy_bench
		,rc_py_plot_2_hist(
			np1,np2
			,'/media/sf_E_RemiCura/PROJETS/articles_ISPRS_Geospatial_Week/experiments/grouping_rules/variable_patch_size/hist_of_density.svg'
			,ARRAY['Density of constant size ','Density of varying size' ]
			,40
			,use_log_y := true) as r 
	*/

-- vacuuming to perform meaningfull size analysis
	/*
	VACUUM FULL ANALYSE copy_bench ; 
	VACUUM FULL ANALYSE copy_bench_2 ;
	*/

-- how much row reduction ? 
	SELECT 1-cp*1.0/cp2*1.0
	FROM (SELECT count(*) AS cp
	FROM copy_bench )AS cp , (SELECT count(*) AS cp2
	FROM copy_bench_2 ) AS cp2
-- analysing what functions are most called

	/*
	SELECT pg_stat_reset();

	SELECT funcname,calls, total_time/1000.0 AS total_time, self_time/1000.0 AS self_time, sum(self_time/1000.0) OVER (order by self_time DESC) As cum_self_time
	FROM pg_stat_user_functions
	ORDER BY  -- total_time DESC  ,
		self_time DESC;  
	*/