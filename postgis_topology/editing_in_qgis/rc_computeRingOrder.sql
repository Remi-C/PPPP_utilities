------------
-- Rémi Cura Thales IGN
-- 02/2015
---------------


DROP FUNCTION IF EXISTS topology.rc_SignedArea( ring_of_edges INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_SignedArea(  ring_of_edges INT[] , OUT signedArea FLOAT)
 AS
$BODY$  
	/**
	@brief  given a ring (an ordered set of signed edge_id), compute the sum of angles between nodes
	*/ 
	DECLARE   
	BEGIN      
	
	WITH input_data AS (
		SELECT r.ordinality, r.value AS s_edge_id,  (count(*) over(partition by abs(r.value))  <>2) as is_simple
		FROM rc_unnest_with_ordinality(ring_of_edges) as r
	)
	,joined_to_edge AS (
		SELECT ordinality, s_edge_id, edge_id, dmp.geom as pt_geom, path[1] as path
		FROM input_data as id
			LEFT OUTER JOIN bdtopo_topological.edge_data as ed
				ON (abs(id.s_edge_id) = ed.edge_id)
			, ST_DumpPoints(geom) AS dmp
		WHERE s_edge_id <0 AND is_simple = TRUE
		UNION ALL 
		SELECT ordinality, s_edge_id, edge_id, dmp.geom as pt_geom, -path[1] as path
		FROM input_data as id
			LEFT OUTER JOIN bdtopo_topological.edge_data as ed
				ON (abs(id.s_edge_id) = ed.edge_id)
			, ST_DumpPoints(geom) AS dmp
		WHERE s_edge_id >0 AND is_simple = TRUE
	) 
	,getting_next_node AS (
		SELECT ordinality, s_edge_id , pt_geom as pt, COALESCE(lead(pt_geom,1) OVER(w) , first(pt_geom) OVER(w )) as n_pt  
		FROM joined_to_edge
		WINDOW w AS (ORDER BY ordinality ASC, path ASC)
	)
	SELECT sum(    (ST_X(n_pt)-ST_X(pt)) * (ST_Y(n_pt)+ST_Y(pt) )/2.0 )  INTO signedArea
	FROM getting_next_node ;
	 RETURN ; 
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 




DROP FUNCTION IF EXISTS topology.rc_GetRingEdges_notworking( topology_name text, s_edge_id int) ;
CREATE OR REPLACE FUNCTION topology.rc_GetRingEdges_notworking( topology_name text, s_edge_id int)
RETURNS TABLE (ordinality int, signed_edge_id INT)
 AS
$BODY$  
	/** @brief  given a signed edge, compute the ring it belongs to. It is a safer version than the traditionnal one, because it also work on flat faces
	*/ 
	DECLARE   
		_q text ; 
	BEGIN       
_q := format('
 WITH RECURSIVE edgering AS ( 
	WITH input_edge_id AS (
		SELECT %1$s  as signed_edge_id
		LIMIT 1
	)
	SELECT  signed_edge_id
		, edge_id
		, next_left_edge
		, next_right_edge  
	FROM input_edge_id, %2$I.edge_data as ed
	WHERE ed.next_left_edge = signed_edge_id OR ed.next_right_edge = signed_edge_id 
	UNION  
		SELECT  CASE WHEN p.signed_edge_id = p.next_right_edge THEN -1*p.edge_id ELSE p.edge_id END
			, ed.edge_id
			, ed.next_left_edge
			, ed.next_right_edge  
		FROM edgering AS p , %2$I.edge_data as ed
		WHERE ed.next_left_edge = 
			CASE WHEN p.signed_edge_id = p.next_right_edge THEN -1*p.edge_id
			ELSE p.edge_id END
			OR ed.next_right_edge = 
			CASE WHEN p.signed_edge_id = p.next_right_edge THEN -1*p.edge_id
			ELSE p.edge_id END
	)  --note : row_number is not safe here, it cannont guarantee the ordering
	SELECT (row_number() over())::int as ordinality, signed_edge_id::int
	FROM edgering ;',s_edge_id,topology_name);
	RETURN QUERY EXECUTE _q; 
	 RETURN ; 
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 



DROP FUNCTION IF EXISTS topology.rc_GetRingEdges( topology_name text, s_edge_id int) ;
CREATE OR REPLACE FUNCTION topology.rc_GetRingEdges( topology_name text, s_edge_id int)
RETURNS TABLE (sequence int, edge INT)
 AS
$BODY$  
	/** @brief  given a signed edge, compute the ring it belongs to. It is wrapper arround the traditional one, to correct bug
	*/ 
	DECLARE   
		_q text ; 
		_exception_case BOOLEAN ; 
	BEGIN   
		SELECT (abs(next_left_edge) =  abs(s_edge_id) OR abs(next_right_edge) =  abs(s_edge_id) ) AND  s_edge_id<0  INTO _exception_case
		FROM bdtopo_topological.edge_data as ed 
		WHERE edge_id = abs(s_edge_id) ; 

		IF _exception_case = FALSE THEN
			RETURN QUERY SELECT * FROM topology.GetRingEdges(topology_name, s_edge_id) ; 

		ELSE --huho, bug of GetRingEdges, need workaround
		RETURN QUERY 
			WITH inverted AS (
				SELECT f.sequence AS seq, -1*f.edge as i_edge
				FROM topology.GetRingEdges(topology_name, s_edge_id) as f 
			)
			SELECT  (row_number() over())::int , i_edge
			FROM inverted
			ORDER BY seq DeSC ; 
		END IF ; 

	 RETURN ; 
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 
 
/*

 */
 580
581
583
-583
-582
-580

580
-580
-581
-583
583
582




/*
 WITH input_data AS (
	SELECT -580 AS s_edge_id
	LIMIT 1 
 )
 SELECT f.*
 FROM input_data, topology.rc_GetRingEdges( 'bdtopo_topological', s_edge_id)  as f
 ORDER BY ordinality ASC; 


{-580,-582,-583,583,581,580}
{580,-580,-582,-583,583,581}

{-580,580,581,583,-583,-582}
{580,581,583,-583,-582,-580}

WITH ring AS (
	SELECT array_agg(f.signed_edge_id ORDER BY f.ordinality) as ordered_s_edge_ids
	FROM topology.rc_GetRingEdges('bdtopo_topological',580) as f
)
SELECT topology.rc_SignedArea(ordered_s_edge_ids)
FROM ring ;


WITH ring1 AS (
	SELECT  array_agg(f.edge ORDER BY f.sequence)  as ordered_s_edge_ids
	FROM topology.GetRingEdges('bdtopo_topological',580) as f
)
, ring2 AS (
	SELECT  array_agg(-1*f.edge ORDER BY f.sequence DESC)  as ordered_s_edge_ids
	FROM topology.GetRingEdges('bdtopo_topological',580) as f
)
SELECT topology.rc_SignedArea(ring1.ordered_s_edge_ids) , topology.rc_SignedArea(ring2.ordered_s_edge_ids)
FROM ring1,ring2 ;



WITH ring1 AS (
	SELECT  array_agg(f.edge ORDER BY f.sequence)  as ordered_s_edge_ids
	FROM topology.rc_GetRingEdges('bdtopo_topological',580) as f
)
, ring2 AS (
	SELECT  array_agg(f.edge ORDER BY f.sequence)  as ordered_s_edge_ids
	FROM topology.rc_GetRingEdges('bdtopo_topological',-580) as f
)
SELECT topology.rc_SignedArea(ring1.ordered_s_edge_ids) , topology.rc_SignedArea(ring2.ordered_s_edge_ids)
FROM ring1,ring2 ;

646.611495264675 : {522,-522,-523,-525,-519,518,-518,519,525,520,521}
891.071813764138 : {521,520,-523}
891.071813764167 : {520,-523,521}


588  : -491.547405002406	{588,591,-591,-590,-587,587,589}
591 : -491.54740500242	{591,-591,-590,-587,587,589,588}
-589 : -491.547405002406	{589,588,591,-591,-590,-587,587}
WITH ring AS (
	SELECT  array_agg(f.edge ORDER BY f.sequence)  as ordered_s_edge_ids
	FROM topology.rc_GetRingEdges('bdtopo_topological',589) as f
)
SELECT topology.rc_SignedArea(ring.ordered_s_edge_ids) , ordered_s_edge_ids
FROM ring ;
{522,523,525,519,-518,518,-519,-525,-520,-521,-522}

*/ 
 

SELECT *
FROM bdtopo_topological.edge_data as ed
WHERE ed.edge_id = 580


 WITH RECURSIVE edgering AS ( 
	WITH input_edge_id AS (
		SELECT 580 as signed_edge_id
		LIMIT 1
	)
	SELECT  signed_edge_id
		, edge_id
		, next_left_edge
		, next_right_edge  
	FROM input_edge_id, bdtopo_topological.edge_data as ed
	WHERE ed.next_left_edge = signed_edge_id OR ed.next_right_edge = signed_edge_id 
	UNION  
		SELECT  CASE WHEN p.signed_edge_id = p.next_right_edge THEN -1*p.edge_id ELSE p.edge_id END
			, ed.edge_id
			, ed.next_left_edge
			, ed.next_right_edge  
		FROM edgering AS p , bdtopo_topological.edge_data as ed
		WHERE ed.next_left_edge = 
			CASE WHEN p.signed_edge_id = p.next_right_edge THEN -1*p.edge_id
			ELSE p.edge_id END
			OR ed.next_right_edge = 
			CASE WHEN p.signed_edge_id = p.next_right_edge THEN -1*p.edge_id
			ELSE p.edge_id END
	)
	SELECT *
	FROM edgering
		
	SELECT 
		CASE WHEN p.signed_edge_id < 0 
			THEN p.next_right_edge  
			ELSE p.next_left_edge END
		, e.edge_id
		, e.next_left_edge
		, e.next_right_edge  
	FROM  bdtopo_topological.edge_data e, edgering p 
	WHERE e.edge_id = 
		CASE WHEN p.signed_edge_id < 0
		THEN abs(p.next_right_edge) 
		ELSE abs(p.next_left_edge) 
		END 
	)
	) 
	SELECT row_number() over() as ordinality, signed_edge_id 
	FROM edgering 

