---------------------------------------------
--Copyright Remi-C  08/2014
--
--
--This script expects a postgres >= 9.3, Postgis >= 2.0.2 , pointcloud
--
--
--------------------------------------------

----------Abstract-------------------
--
--This scriptproposes function that are thin wrapper around pc_explode. Those wrapper add 2 new functionnality :
--first the order of points is always the same and is the order of wwritting in the patch
--second we can retrieve only a limited number of points
--
--------------------------------------

	DROP FUNCTION IF EXISTS public.rc_ExplodeN( a_patch PCPATCH , n bigint);
		CREATE OR REPLACE FUNCTION  public.rc_ExplodeN( a_patch PCPATCH , n bigint)
		RETURNS SETOF pcpoint AS
		$BODY$
		--this function is a wrapper around pc_explode to limit the number of points it returns	
		DECLARE
		BEGIN
			RETURN QUERY 
				SELECT PC_Explode(a_patch)
				LIMIT n;
		return;
		END;
		$BODY$
		LANGUAGE plpgsql STRICT VOLATILE;

	SELECT public.rc_ExplodeN(patch, 10)
	FROM acquisition_tmob_012013.riegl_pcpatch_space
	WHERE gid=120;



DROP FUNCTION IF EXISTS public.rc_ExplodeN_numbered( a_patch PCPATCH , n bigint);
		CREATE OR REPLACE FUNCTION  public.rc_ExplodeN_numbered( a_patch PCPATCH , n bigint)
		RETURNS table(num bigint , point pcpoint ) AS
		$BODY$
		--this function is a wrapper around pc_explode to limit the number of points it returns	
		DECLARE
		BEGIN
			RETURN QUERY 
				SELECT generate_series(1, n), PC_Explode(a_patch)
				LIMIT n;
		return;
		END;
		$BODY$
		LANGUAGE plpgsql STRICT VOLATILE;


		
		
		
		