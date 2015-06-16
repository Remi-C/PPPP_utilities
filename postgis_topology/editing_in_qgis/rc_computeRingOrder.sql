------------
-- Rémi Cura Thales IGN
-- 02/2015
---------------


DROP FUNCTION IF EXISTS topology.rc_SignedArea(topology_name TEXT ,  ring_of_edges INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_SignedArea( topology_name TEXT , ring_of_edges INT[] , OUT signedArea FLOAT)
 AS
$BODY$  
	/**
	@brief  given a ring (an ordered set of signed edge_id), compute the sum of angles between nodes
    The sign allows to decide in which order we do walk (clockwise <0 or counterclockwise >0)
	*/ 
	DECLARE   
    _q TEXT ; 
	BEGIN      
	
    _q := format('
	WITH input_data AS (
		SELECT r.ordinality, r.value AS s_edge_id,  (count(*) over(partition by abs(r.value))  <>2) as is_simple
		FROM rc_unnest_with_ordinality($1) as r
	)
	,joined_to_edge AS (
		SELECT ordinality, s_edge_id, edge_id, dmp.geom as pt_geom, path[1] as path
		FROM input_data as id
			LEFT OUTER JOIN %1$I.edge_data as ed
				ON (abs(id.s_edge_id) = ed.edge_id)
			, ST_DumpPoints(geom) AS dmp
		WHERE s_edge_id <0 AND is_simple = TRUE
		UNION ALL 
		SELECT ordinality, s_edge_id, edge_id, dmp.geom as pt_geom, -path[1] as path
		FROM input_data as id
			LEFT OUTER JOIN %1$I.edge_data as ed
				ON (abs(id.s_edge_id) = ed.edge_id)
			, ST_DumpPoints(geom) AS dmp
		WHERE s_edge_id >0 AND is_simple = TRUE
	) 
	,getting_next_node AS (
		SELECT ordinality, s_edge_id , pt_geom as pt, COALESCE(lead(pt_geom,1) OVER(w) , first(pt_geom) OVER(w )) as n_pt  
		FROM joined_to_edge
		WINDOW w AS (ORDER BY ordinality ASC, path ASC)
	)
	SELECT sum(    (ST_X(n_pt)-ST_X(pt)) * (ST_Y(n_pt)+ST_Y(pt) )/2.0 )  
	FROM getting_next_node ;
    ',topology_name) ;
    EXECUTE _q INTO signedArea USING ring_of_edges
	 RETURN ; 
	END ;
	$BODY$
LANGUAGE plpgsql ; 


 
   