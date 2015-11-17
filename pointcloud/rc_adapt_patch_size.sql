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

		--RAISE WARNING 'patch_id % , size %, merged_split %, num_points : % , min_density %, max_density %', patch_id , size , merged_split 
		--	, pc_numpoints(ipatch), min_density , max_density ; 
		--shall we split the patch (too big and was not merged)?
		IF pc_numpoints(ipatch) > max_density AND (merged_split != -1 OR merged_split IS NULL) THEN
			--RAISE NOTICE 'splitting' ; 
				--split patch
			WITH points AS (
				SELECT *
				FROM pc_explode(ipatch) as pt, pc_get(pt,'x') x , pc_get(pt,'y') y , pc_get(pt,'z') z 
					, pc_get(pt,'gps_time') gps_time 
			)
			, patches AS (
				SELECT pc_patch(pt) as n_patch
				FROM points
				GROUP BY floor(x/(size/2.0)), floor(y/(size/2.0)), floor(z/(size/2.0)) --, floor(gps_time/(size/2.0))  
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

		--	RAISE NOTICE 'inserted %' , _useless; 

			RETURN array_length(_useless,1); 

		ELSIF pc_numpoints(ipatch) < min_density AND (merged_split != 1 OR merged_split IS NULL )THEN
		--	RAISE NOTICE 'merging' ; 
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
					--AND floor(pc_patchavg(ipatch,'gps_time') / (2*size) ) = floor(avg_time / (2*size) )
					AND (cp.merged_split  != +1 OR cp.merged_split IS NULL) 
					AND num_points < max_density 

			)
			SELECT array_agg(gid) INTO _to_work_on 
			FROM patches_candidates;
			--RAISE NOTICE '% patches found for the merge', array_length(_to_work_on,1) ; 

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
					SELECT (select array_agg(-1*gid) from deleting_old_patches), (select * from inserting_merged_patch) 
						INTO _useless, _useless2 ; 
			ELSE
				--simply put a 0 in merged_split ot show it has been considered
				UPDATE copy_bench AS cp
				SET merged_split = 0  
				WHERE gid  = patch_id; 
			END IF ;

		

			--	RAISE NOTICE 'deleted % patches , inserted %',_useless , _useless2;

			RETURN sign(_useless[1]) * array_length(_useless,1);  

		ELSE
			--indicating that nothing can be done for this patch
			UPDATE copy_bench AS cp
				SET merged_split = 0  
				WHERE gid  = patch_id ;
		--	RAISE NOTICE 'doing nothing' ; 
			RETURN NULL ;	
		END IF ; 
		
		RETURN NULL;
		END ; 
		$$ LANGUAGE 'plpgsql' VOLATILE CALLED ON NULL INPUT; 


--creating a trigger to recompute   geom, num_points,  avg_z, avg_time when inserting or updating

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
	    EXECUTE PROCEDURE rc_update_patch_in_copy_bench(); 


	/** testing

--create a table to work with



DROP TABLE IF EXISTS copy_bench; 
TRUNCATE copy_bench ;

CREATE TABLE copy_bench (LIKE benchmark_cassette_2013.riegl_pcpatch_space INCLUDING ALL) ;
INSERT INTO copy_bench 
SELECT * ,  patch::geometry(polygon,932011) AS geom
	,  PC_NumPoints( patch) AS num_points
	, 1::float AS spatial_size
	, NULL AS merged_split
	, pc_patchavg(patch,'z') AS z
	, pc_patchavg(patch,'gps_time') AS avg_time
FROM benchmark_cassette_2013.riegl_pcpatch_space
WHERE ST_DWIthin(patch::geometry, ST_SetSRID(ST_MakePoint(1907.18,21165.05),932011),10)=TRUE; 

  

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
LIMIT 10

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
	WHERE gid= 26318 ; 

	 SELECT gid, *
    FROM copy_bench AS cp
    WHERE (num_points < 100 OR 
		num_points > 1000)
      AND COALESCE(merged_split,-1) != 0 
      ORDER BY gid ASC 
    LIMIT 1
    

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


create function h_int(text) returns int as $$
 select ('x'||substr(md5($1),1,8))::bit(32)::int;
$$ language sql;


COPY  (
WITH patches AS (
	SELECT gid, patch, random()*255  AS R, random()*255  AS G, random()*255  AS B , spatial_size
	FROM copy_bench
)
	SELECT  round(pc_get(pt,'x')::numeric,3) AS x, round(pc_get(pt,'y')::numeric,3) AS y, round(pc_get(pt,'z')::numeric,3) AS z,  gid, R::int, G::int , B::int , spatial_size
	FROM patches, pc_explode(patch) AS pt
)TO '/media/sf_E_RemiCura/export_pointcloud_patch_merged.csv'
WITH HEADER CSV

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


SELECT count(*)
FROM copy_bench 