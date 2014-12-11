-----------------------------------------------------------
--
--Rémi-C , Thales IGN
--11/2014
-- 
  ----------------------


	--we need an array agg for array, found in PPPP_utilities
			DROP AGGREGATE public.array_agg_custom(anyarray) ;
			CREATE AGGREGATE public.array_agg_custom(anyarray)
				( SFUNC = array_cat,
				STYPE = anyarray
				);

	--a wrapper function to convert from patch to array[array[]], so to be able to transmit information	
	DROP FUNCTION IF EXISTS rc_patch_to_XYZ_array(ipatch PCPATCH,maxpoints INT, int);
	CREATE OR REPLACE FUNCTION rc_patch_to_XYZ_array(ipatch PCPATCH,maxpoints INT DEFAULT 0, rounding_digits int default 3
		)
	  RETURNS FLOAT[] AS
	$BODY$
			--@brief this function clean result tables
			-- @return :  nothing 
			DECLARE 
			BEGIN 
				RETURN array_agg_custom(
					ARRAY[
						round(PC_Get(pt.point,'X'),rounding_digits)
						, round(PC_Get(pt.point,'Y'),rounding_digits)
						, round(PC_Get(pt.point,'Z'),rounding_digits)
					] ORDER BY pt.ordinality ASC )
				FROM public.rc_ExplodeN_numbered(  ipatch,maxpoints) as pt ; 
			END ; 
		$BODY$
	LANGUAGE plpgsql IMMUTABLE STRICT;
	--SELECT rc_patch_to_XYZ_array()
 