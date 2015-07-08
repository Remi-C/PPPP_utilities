----------
-- Rémi-C , IGN THALES
--02/2015
-- function that tell if a edge sequence forms a true face or a flat face

DROP FUNCTION IF EXISTS rc_IsRingFace(s_edge_ids int[]) ;
CREATE OR REPLACE FUNCTION rc_IsRingFace(s_edge_ids int[])
  RETURNS BOOLEAN AS
$BODY$
/** @brief this function tels if a ring of edge form a face, in  a robust to precision issue way.
By definition a ring doesn't form a face if all the edge involved a present 2 times in a ring with opposite sign.
For instance [1,2,-2,-1] is not a face, while [1,2,3,4,-2,-1] is a face.
*/
DECLARE 
	_is_ringface int; 
BEGIN
	WITH seq AS (
		SELECT unnest(s_edge_ids) as s_edge_id
	)
	SELECT count(*) INTO _is_ringface
	FROM (
		SELECT abs(s_edge_id), count(*) n_same_edge_id
		FROM seq
		GROUP BY abs(s_edge_id)
	) AS sub
	WHERE n_same_edge_id !=2 ; 

	RETURN  (_is_ringface>0) ; 
	 
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100; 
COMMENT ON FUNCTION rc_IsRingFace(s_edge_ids int[]) IS 
	'args: s_edge_ids - Return True or False depending on the fact that the given edge sequence (ring) forms a true face or not';

-- SELECT rc_lib.rc_IsRingFace(ARRAY[392 ,393 ,394 ,390 ,-390 ,-391 ,-392 ]) ; 
-- SELECT rc_lib.rc_IsRingFace(ARRAY[392 ,393 ,394 ,-393 ,-394 ,-392 ]) ; 