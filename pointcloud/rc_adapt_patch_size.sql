---------------
--Remi C 09/2014
--
--------------
--function to adapt patch size so the patch density is bounded in given range

--???define the function used for range indexing on an atribute???--

		----
		--deelte function if it exists
		DROP FUNCTION IF EXISTS public.rc_adapt_patch_size(int, PCPATCH,float,int, int, int);

		----
		--creating function
		CREATE OR REPLACE FUNCTION public.rc_adapt_patch_size(patch_id int, patch PCPATCH
			, size FLOAT, merged_split INT, min_density INT, max_density INT)
		RETURNS INT AS $$ 
		DECLARE
			_useless int ;
			_useless2 int ;  
		BEGIN
		/** given a patch, this function may merge it or split it, so it fits in the target density
		*/
		
		--shall we split the patch (too big and was not merged)?
		IF pc_numpoints(patch) > max_threshold AND merged_split != -1 THEN
			
			--split patch
WITH points AS (
	SELECT *
	FROM pc_explodes(patch) as pt, pc_get(pt,'x') x , pc_get(pt,'y') y , pc_get(pt,'z') z 
		, pc_get(pt,'gps_time') gps_time 
)
, patches AS (
	SELECT pc_patch(pt) as n_patch
	FROM points
	GROUP BY round(x*size/2), round(y*size/2), round(z*size/2), round(gps_time*size/2)  
)
, deleting_patch AS (
	DELETE FROM patch_table WHERE gid = patch_id RETURNING gid
)
, inserting_patch AS (
	INSERT INTO patch_table (patch)
	SELECT n_patch 
	FROM patches
	RETURNING gid, patch
)
, inserting_proxy AS (
	INSERT INTO patch_table_proxy (gid, geom , size, merged_split)
	(gid, patch::geom, size / 2.0 , +1) 
	FROM inserting_patch
)
SELECT count(*) INTO _useless
FROM inserting_proxy ; 

RETURN _useless; 

		ELSIF pc_numpoints(patch) < min_threshold AND merged_split != 1 THEN
		--shall we merge the patch (too small and was not split)?
			-- get the patches that would be merged
			-- if the merging doesn't produces a patch too big, merge
			WITH patches_candidates AS( 
SELECT gid, geom
FROM my_patch_proxy, ST_Centroid(patch::geom) as centre
	, ST_Centroid( geom) as candidate_centre	
WHERE ST_DWithin(patch::geom, geom, size * 2) -- to use indexes
	AND round(ST_X(centre) / (2*size) ) = round(ST_X(candidate_centre) / (2*size) )
	AND round(ST_Y(centre) / (2*size) ) = round(ST_Y(candidate_centre) / (2*size) )
	AND round(pc_patchavg(patch,'z') / (2*size) ) = round(avg_z / (2*size) )
	AND round(pc_patchavg(patch,'gps_time') / (2*size) ) = round(avg_time / (2*size) )
	AND merged_split != +1
	AND num_points < max_density

)
, inserting_merged_patch AS (
	INSERT INTO my_patch_table (patch)
	SELECT pc_union(patch)
	FROM patches_candidates NATURAL JOIN my_patch_table ,
RETURNING gid
)
, deleting_old_patches AS (
	DELETE FROM my_patch_table WHERE EXISTS (
	SELECT 1 FROM patches_candidates
	WHERE my_patch_table.gid = patches_candidtates.gid
)
RETURNING gid
)
SELECT (select count(*) from deleting_old_patches), (select * from inserting_merged_patch) 
	INTO _useless, _useless2 ; 

RETURN _useless;  

		ELSE
			--doing nothing
			RETURN NULL ;	
		END IF ; 
		
		RETURN NULL;
		$$ LANGUAGE 'plpgsql' VOLATILE;
