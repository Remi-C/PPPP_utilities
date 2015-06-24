---------------
--Remi C 09/2014
--
--------------
--Handy function to compute range over an ttribute of a patch

--▓▒░define the function used for range indexing on an atribute▓▒░--

		----
		--deelte function if it exists
		DROP FUNCTION IF EXISTS  rc_compute_range_for_a_patch(PCPATCH,text); 
		CREATE OR REPLACE FUNCTION  rc_compute_range_for_a_patch(patch PCPATCH, nom_grandeur_pour_interval text)
		RETURNS NUMRANGE AS $$ 
		BEGIN
		/*
		This function input is a patch. It compute the range (from min to max) of a given attribute
		*/ 
            RETURN NUMRANGE(PC_PatchMin(patch, nom_grandeur_pour_interval),PC_PatchMax(patch, nom_grandeur_pour_interval),'[]');
		END;
		$$ LANGUAGE 'plpgsql' IMMUTABLE;

		--example use case
-- 		SELECT public.rc_compute_range_for_a_patch(patch,'gps_time')
-- 		FROM acquisition_tmob_012013.velo_pcpatch_space
-- 		LIMIT 100
 
--▓▒░Index on this function : ▓▒░--

	----
	--time index on riegl
-- 		CREATE INDEX acquisition_tmob_012013_riegl_pcpatch_space_patch_gist_range_gps_time
-- 			ON acquisition_tmob_012013.riegl_pcpatch_space
-- 			USING GIST (  rc_compute_range_for_a_patch(patch,'gps_time')); 