---------------
--Remi C 09/2014
--
--------------
--function to adapt patch size so the patch density is bounded in given range


-- CREATE SCHEMA IF NOT EXISTS test_grouping ;
-- SET search_path to test_grouping , rc_lib, public ; 


--???define the function used for range indexing on an atribute???--
	
		----
		--delete function if it exists
		DROP FUNCTION IF EXISTS  rc_adapt_patch_size(int, PCPATCH,float,int, int, int);

		----
		--creating function
		CREATE OR REPLACE FUNCTION rc_adapt_patch_size(patch_id int, ipatch PCPATCH
			, size FLOAT, merged_split INT, min_density INT, max_density INT)
		RETURNS INT AS $$ 
		DECLARE
			_useless int[] ;
			_useless2 int ;  
			_to_work_on int[];
		BEGIN
		/** given a patch, this function may merge it or split it, so it fits in the target density
		*/

		RAISE WARNING 'patch_id % , size %, merged_split %, num_points : % , min_density %, max_density %', patch_id , size , merged_split 
			, pc_numpoints(ipatch), min_density , max_density ; 
		--shall we split the patch (too big and was not merged)?
		IF pc_numpoints(ipatch) > max_density AND (merged_split != -1 OR merged_split IS NULL) THEN
			RAISE NOTICE 'splitting' ; 
				--split patch
			WITH points AS (
				SELECT *
				FROM pc_explode(ipatch) as pt, pc_get(pt,'x') x , pc_get(pt,'y') y , pc_get(pt,'z') z 
					, pc_get(pt,'gps_time') gps_time 
			)
			, patches AS (
				SELECT pc_patch(pt) as n_patch
				FROM points
				GROUP BY floor(x/(size/2.0)), floor(y/(size/2.0)), floor(z/(size/2.0)), floor(gps_time/(size/2.0))  
			)
			, deleting_patch AS (
				DELETE FROM copy_bench WHERE gid = patch_id RETURNING gid
			)
			, inserting_patch AS (
				INSERT INTO copy_bench (patch,spatial_size, merged_split)
				SELECT n_patch , size/2.0 ,  +1
				FROM patches
				RETURNING gid, patch
			)
			--, inserting_proxy AS (
			--	INSERT INTO copy_bench (gid, geom , spatial_size, merged_split)
			--	SELECT (gid, patch::geometry, size / 2.0 , +1) 
			--	FROM inserting_patch
			--	RETURNING gid 
			--)
			SELECT array_agg(gid)  INTO _useless
			FROM inserting_patch ; 

			RAISE NOTICE 'inserted %' , _useless; 

			RETURN array_length(_useless,1); 

		ELSIF pc_numpoints(ipatch) < min_density AND (merged_split != 1 OR merged_split IS NULL )THEN
			RAISE NOTICE 'merging' ; 
		--shall we merge the patch (too small and was not split)?
			-- get the patches that would be merged
			-- if the merging doesn't produces a patch too big, merge
			WITH patches_candidates AS( 
				SELECT gid, geom, patch
				FROM copy_bench AS cp, ST_Centroid(cp.patch::geometry) as centre
					, ST_Centroid( cp.geom) as candidate_centre	
				WHERE ST_DWithin(ipatch::geometry, geom, size * 2) -- to use indexes
					AND floor(ST_X(centre) / (2*size) ) = floor(ST_X(candidate_centre) / (2*size) )
					AND floor(ST_Y(centre) / (2*size) ) = floor(ST_Y(candidate_centre) / (2*size) )
					AND floor(pc_patchavg(ipatch,'z') / (2*size) ) = floor(avg_z / (2*size) )
					AND floor(pc_patchavg(ipatch,'gps_time') / (2*size) ) = floor(avg_time / (2*size) )
					AND (cp.merged_split  != +1 OR cp.merged_split IS NULL) 
					AND num_points < max_density 

			)
			SELECT array_agg(gid) INTO _to_work_on 
			FROM patches_candidates;

			IF array_length(_to_work_on,1) > 1 THEN 
				--merge
				
					WITH patches_candidates AS (
						SELECT gid, geom, patch
						FROM copy_bench AS cp
						WHERE cp.gid = ANY (_to_work_on) 
					)
					, inserting_merged_patch AS (
						INSERT INTO copy_bench (patch, spatial_size, merged_split)
						SELECT pc_union(patch) , size * 2 , -1
						FROM patches_candidates  
						WHERE (
							SELECT count(*)
							FROM patches_candidates
						) > 1
					RETURNING gid
					)
					, deleting_old_patches AS (
						DELETE FROM copy_bench
						WHERE EXISTS (
							SELECT 1 
							FROM patches_candidates
							WHERE copy_bench.gid = patches_candidates.gid
						)
					RETURNING gid
					)
					SELECT (select array_agg(gid) from deleting_old_patches), (select * from inserting_merged_patch) 
						INTO _useless, _useless2 ; 
			ELSE
				--simply put a 0 in merged_split ot show it has been considered
				UPDATE copy_bench AS cp
				SET merged_split = 0  
				WHERE gid  = patch_id
					AND cp.merged_split IS NULL;
			END IF ;

		

				RAISE NOTICE 'deleted % patches , inserted %',_useless , _useless2;

			RETURN array_length(_useless,1);  

		ELSE
			--doing nothing
			RAISE NOTICE 'doing nothing' ; 
			RETURN NULL ;	
		END IF ; 
		
		RETURN NULL;
		END ; 
		$$ LANGUAGE 'plpgsql' VOLATILE CALLED ON NULL INPUT; 

	/** testing

--create a table to work with



DROP TABLE IF EXISTS copy_bench; 
TRUNCATE copy_bench ;

CREATE TABLE copy_bench (LIKE benchmark_cassette_2013.riegl_pcpatch_space INCLUDING ALL) ;
INSERT INTO copy_bench 
SELECT * 
FROM benchmark_cassette_2013.riegl_pcpatch_space
WHERE gid < 1000  ; 

  

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

UPDATE copy_bench SET spatial_size =1.0 ; 

SELECT *
FROM copy_bench
LIMIT 1

	*/ 


	SELECT *
	FROM copy_bench, rc_adapt_patch_size(
		patch_id:= gid
		, ipatch:= patch
		, size:=spatial_size
		, merged_split:=merged_split
		, min_density:=100
		, max_density:=1000
		)
	WHERE gid= 55 ; 

/**
	SELECT count(*)
	FROM copy_bench

	SELECT *
	FROM copy_bench
	WHERE gid > 23000


	WITH idata AS (
		SELECT *
		FROM copy_bench 
		WHERE gid= 55
		LIMIT 1 
	)
	SELECT cp.gid, cp.geom, cp.patch , * 
	FROM idata, copy_bench AS cp, ST_Centroid(cp.patch::geometry) as centre
					, ST_Centroid( cp.geom) as candidate_centre	
	WHERE ST_DWithin(idata.patch::geometry, cp.geom, cp.spatial_size * 2) -- to use indexes
		AND round(ST_X(centre) / (2*idata.spatial_size) ) = round(ST_X(candidate_centre) / (2*cp.spatial_size) )
		AND round(ST_Y(centre) / (2*idata.spatial_size) ) = round(ST_Y(candidate_centre) / (2*cp.spatial_size) )
		AND round(pc_patchavg(idata.patch,'z') / (2*cp.spatial_size) ) = round(cp.avg_z / (2*cp.spatial_size) )
		AND round(pc_patchavg(idata.patch,'gps_time') / (2*idata.spatial_size) ) = round(cp.avg_time / (2*cp.spatial_size) )
		AND ( cp.merged_split != +1 OR cp.merged_split IS NULL) 
		AND cp.num_points < 1000
 */

SELECT *
	FROM copy_bench , rc_adapt_patch_size(
		patch_id:= gid
		, ipatch:= patch
		, size:=spatial_size
		, merged_split:=merged_split
		, min_density:=100
		, max_density:=1000
		) 
	WHERE (--num_points < 100 or 
		num_points > 1000 ) 
		AND COALESCE(merged_split,-1) != 0 
	ORDER BY gid ASC 
 LIMIT 1


SELECT *
FROM copy_bench
WHERE (
 SELECT count(*)
 FROM copy_bench
 LIMIT 1 ) > 1 
 LIMIT 1


			WITH idata AS (
				SELECT *, 1.0 AS size
				FROM copy_bench
				WHERE gid = 24124
			)
			 , points AS (
				SELECT row_number() over() as id, pt, x, y , z ,   gps_time, size
				FROM idata, pc_explode(patch) as pt, pc_get(pt,'x') x , pc_get(pt,'y') y , pc_get(pt,'z') z 
					, pc_get(pt,'gps_time') gps_time 
			)
			--, patches AS (
				SELECT array_agg(id)  --  round(x*1/(size/2.0) ), round(y/(size/2.0)), round(z/(size/2.0)), round(gps_time/(size/2.0))    -- array_agg(id) -- pc_patch(pt) as n_patch
				FROM points
				GROUP BY floor(x/(size/2.0)), floor(y/(size/2.0)), floor(z/(size/2.0))  , floor(gps_time/(size/2.0))  
			)
			, deleting_patch AS (
				DELETE FROM copy_bench WHERE gid = patch_id RETURNING gid
			)
			, inserting_patch AS (
				INSERT INTO copy_bench (patch,spatial_size, merged_split)
				SELECT n_patch , size/2.0 ,  +1
				FROM patches
				RETURNING gid, patch
			)
			--, inserting_proxy AS (
			--	INSERT INTO copy_bench (gid, geom , spatial_size, merged_split)
			--	SELECT (gid, patch::geometry, size / 2.0 , +1) 
			--	FROM inserting_patch
			--	RETURNING gid 
			--)
			SELECT array_agg(gid)  INTO _useless
			FROM inserting_patch ; 