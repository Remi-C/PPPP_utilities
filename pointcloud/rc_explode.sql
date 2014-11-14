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
			IF n<=0 THEN 
			
			RETURN QUERY 
				SELECT PC_Explode(a_patch) ;

			ELSE 
			RETURN QUERY 
				SELECT PC_Explode(a_patch)
				LIMIT n;
			END IF; 
		return;
		END;
		$BODY$
		LANGUAGE plpgsql STRICT IMMUTABLE;

-- 	SELECT public.rc_ExplodeN(patch, 10)
-- 	FROM acquisition_tmob_012013.riegl_pcpatch_space
-- 	WHERE gid=120;



DROP FUNCTION IF EXISTS public.rc_ExplodeN_numbered( a_patch PCPATCH , n bigint);
		CREATE OR REPLACE FUNCTION  public.rc_ExplodeN_numbered( a_patch PCPATCH , n bigint DEFAULT 0)
		RETURNS table(ordinality bigint , point pcpoint ) AS
		$BODY$
		--this function is a wrapper around pc_explode to limit the number of points it returns	
		DECLARE
		numpoints INT :=  PC_NumPoints(a_patch) ;
		BEGIN
			if n <=0 OR n>numpoints then --we have to put this protection or calling with a really big limit could make the server crash 
					--+ it is pointless to have a limit bigger than nb of returned rows
				n := numpoints ;
			END IF; 
			
			RETURN QUERY 
				SELECT generate_series(1, n), PC_Explode(a_patch)
				LIMIT n;
		return;
		END;
		$BODY$
		LANGUAGE plpgsql STRICT IMMUTABLE;


		
-- Function: rc_exploden_random(pcpatch, bigint)

-- DROP FUNCTION rc_exploden_random(pcpatch, bigint);
CREATE OR REPLACE FUNCTION rc_exploden_random(a_patch pcpatch, n bigint)
  RETURNS SETOF pcpoint AS
$BODY$
		--this function is a wrapper around pc_explode to limit the number of points it returns	
		DECLARE
		BEGIN
			IF PC_NumPoints(a_patch) <= n THEN 
			RETURN QUERY SELECT * FROM rc_ExplodeN( a_patch , n );
			ELSE 
			RETURN QUERY 
				SELECT pt
				FROM 
					(SELECT PC_Explode(a_patch) AS pt, random() AS rand ) AS sub
				ORDER BY rand asc
				LIMIT n;
			END IF ;
		return;
		END;
		$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100
  ROWS 1000; 


-- DROP FUNCTION rc_exploden_grid(pcpatch, bigint,float);
CREATE OR REPLACE FUNCTION rc_exploden_grid(a_patch pcpatch, n bigint,voxel_size float)
  RETURNS SETOF pcpoint AS
$BODY$
		--this function is a wrapper around pc_explode to limit the number of points it returns
		--ig there are 	
		DECLARE
		BEGIN
			IF PC_NumPoints(a_patch) <= n OR n<=0 THEN 
			RETURN QUERY SELECT * FROM rc_ExplodeN( a_patch , n );
			ELSE   
			RETURN QUERY 
				SELECT DISTINCT ON (  (pc_get(pt,'x')/voxel_size)::int ,  (pc_get(pt,'y')/voxel_size)::int, (pc_get(pt,'z')/voxel_size)::int )*
				FROM PC_Explode(a_patch) AS pt 
				LIMIT n;
			END IF ;
		return;
		END;
		$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100
  ROWS 1000; 
 
 