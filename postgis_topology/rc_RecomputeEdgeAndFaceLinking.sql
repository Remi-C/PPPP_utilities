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
	RAISE EXCEPTION 'not implemetned yet';
		RETURN  ;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 