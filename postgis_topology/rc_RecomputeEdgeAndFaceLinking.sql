----------------------
-- Remi-C THALES IGN
--02/2015
----------------------
-- postgis topology function
----------------------
-- given nodes in a topology, where only start_node and end_node are supposed to be correct, recompute edge linking (next_left, next_right..), and face-linking (left_face, ...)


 

DROP FUNCTION IF EXISTS topology.rc_RecomputeEdgeAndFaceLinking(topology_name TEXT, node_to_update INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_RecomputeEdgeAndFaceLinking(topology_name TEXT, node_to_update INT[] )
 returnS VOID AS
$BODY$  
	/**
	@brief given nodes in a topology, where only start_node and end_node are supposed to be correct, recompute edge linking (next_left, next_right..), and face-linking (left_face, ...)
		--first need to recompute edge-linking
			--for each node : 
				--list edge clockwise order
				-- if edge is coming to node, set next_left_edge
				-- if edge is going out of node, set next_right_edge
		--then recompute face-linking
			--list all minimal edge cycles (aka future face) , and keep left and right face id
			for each cycle :
				-- in a cycle, if all edges agree on face name, it hasn't changed
				--else, create  a new face, update edges.
	*/ 
	DECLARE        
	BEGIN     	  
		--recomputing edge_linking :
		--for each node : 
				--list edge clockwise order
				-- if edge is coming to node, set next_left_edge
				-- if edge is going out of node, set next_right_edge
	RAISE EXCEPTION 'not implemetned yet';
		RETURN  ;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 

	WITH node AS (	
		SELECT 'bdtopo_topological'::text as schema_name, 185 as node_id
	)
	,nodes AS (
		SELECT DISTINCT start_node as node_id
		FROM node, bdtopo_topological.edge_data AS ed
		WHERE ed.end_node  = node_id
		UNION 
		SELECT DISTINCT end_node AS node_id 
		FROM node, bdtopo_topological.edge_data AS ed
		WHERE ed.start_node  = node_id
		UNION 
		SELECT node_id
		FROM node
	)
	, se_edge as (
		SELECT nodes.node_id, sequence as ordinality, edge as s_edge_id
		FROM node,nodes, topology.GetNodeEdges(schema_name, nodes.node_id) 
	) 
	, se_edges_with_following aS (
		SELECT node_id, ordinality, s_edge_id, COALESCE(lead(s_edge_id,1,NULL) OVER w,first_value(s_edge_id) over w ) as following_s_edge_id
		FROM se_edge
		WINDOW w AS (PARTITION BY node_id ORDER BY ordinality ASC)
		ORDER BY node_id, ordinality
	)
	,next_left_update AS (
	SELECT node_id, abs(s_edge_id) as edge_id, following_s_edge_id as next_left_edge 
	FROM se_edges_with_following
	WHERE s_edge_id <0 
	)
	 ,next_right_update AS (
	SELECT node_id, abs(s_edge_id) as edge_id, following_s_edge_id as next_right_edge 
	FROM se_edges_with_following
	WHERE s_edge_id >0 
	)
	SELECT nlu.edge_id , nlu.next_left_edge, nru.next_right_edges
	FROM next_left_update AS nlu
		INNER JOIN next_right_update  as nru ON (nlu.edge_id = nru.edge_id)
	;
-- 	SELECT se1.* , sub.s_edge_id AS after_s_edge_id
-- 	FROM  se_edge AS se1
-- 		LEFT OUTER JOIN n_edges as ne ON (se1.node_id = ne.node_id),  
-- 		LATERAL (SELECT * FROM  se_edge As se2 WHERE se1.node_id = se2.node_id AND se2.ordinality = (se1.ordinality % ne+.n_edge)+1  ) as sub
-- 	ORDER BY node_id, ordinality ASC
		--LEFT OUTER JOIN se_edge As se2 ON (se1.ordinality = (se2.ordinality % n_edges.n_edge)+1)
	--SELECT ordinality, s_edge_id, lead(s_edge_id,1,NULL) OVER(PARTITION BY node_id ORDER BY ordinality ASC)
	--FROM se_edge
--even when only one edeg, duplicate the first edge and put it to the end
--if edge  negativ : set next_left_edge and abs_next_left_edge to seq+1
--if edge is positiv : set next_right_edge and abs_... to seq+1
 