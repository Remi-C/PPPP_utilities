----------------------
-- Remi-C THALES IGN
--02/2015
----------------------
-- postgis topology function
----------------------
-- given nodes in a topology, where only start_node and end_node are supposed to be correct, recompute edge linking (next_left, next_right..), and face-linking (left_face, ...)


 

DROP FUNCTION IF EXISTS topology.rc_RecomputeEdgeAndFaceLinking(topology_name TEXT, nodes_to_update INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_RecomputeEdgeAndFaceLinking(topology_name TEXT, nodes_to_update INT[] )
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
		--then update isolated node  face
	*/ 
	DECLARE  
		updated_edges INT[] ; 
		updated_faces INT[] ; 
	BEGIN     	  
		--recomputing edge_linking :
		--for each node : 
				--list edge clockwise order
				-- if edge is coming to node, set next_left_edge
				-- if edge is going out of node, set next_right_edge 
		SELECT  topology.rc_RecomputeEdgeLinking(topology_name , nodes_to_update) into updated_edges ; 
		SELECT  topology.rc_RecomputeFaceLinking_fewedges(topology_name , updated_edges) into updated_faces ; 
	--RAISE EXCEPTION 'not implemetned yet %',updated_edges;
		RETURN  ;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 



DROP FUNCTION IF EXISTS topology.rc_RecomputeEdgeLinking(topology_name TEXT, nodes_to_update INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_RecomputeEdgeLinking(topology_name TEXT, nodes_to_update INT[] )
 returnS int[] AS
$BODY$  
	/**
	@brief given nodes in a topology, where only start_node and end_node are supposed to be correct, recompute edge linking (next_left, next_right..), and face-linking (left_face, ...)
		--first need to recompute edge-linking
			--for each node : 
				--list edge clockwise order
				-- if edge is coming to node, set next_left_edge
				-- if edge is going out of node, set next_right_edge 
	*/ 
	DECLARE    
		updated_edges INT[] ; 
		_q TEXT; 
	BEGIN     	  
		RAISE NOTICE 'node to update : %', nodes_to_update  ;
		--recomputing edge_linking :

		_q := format('
		WITH node AS ( --input = all the node whose edges need to be updated	
		SELECT unnest($1) as node_id
		)
		,nodes AS ( --listing connnected nodes
			SELECT DISTINCT start_node as node_id
			FROM node,  %1$I.edge_data AS ed
			WHERE ed.end_node  = node_id
			UNION 
			SELECT DISTINCT end_node AS node_id 
			FROM node, %1$I.edge_data AS ed
			WHERE ed.start_node  = node_id
			UNION 
			SELECT node_id
			FROM node
		)
		, se_edge as (--for each node, list adjacent edges ordered clockwise
			SELECT nodes.node_id, sequence as ordinality, edge as s_edge_id
			FROM  nodes, topology.GetNodeEdges(%1$L, nodes.node_id) 
		) 
		, se_edges_with_following aS (--for each edge, get the next clockwise(for the last, the next is first)
			SELECT node_id, ordinality, s_edge_id, COALESCE(lead(s_edge_id,1,NULL) OVER w,first_value(s_edge_id) over w ) as following_s_edge_id
			FROM se_edge
			WINDOW w AS (PARTITION BY node_id ORDER BY ordinality ASC)
			ORDER BY node_id, ordinality
		)
		,next_left_update AS ( --for all edges going out, define the next_left_edge
			SELECT node_id, abs(s_edge_id) as edge_id, following_s_edge_id as next_left_edge 
			FROM se_edges_with_following
			WHERE s_edge_id <0 
		)
		 ,next_right_update AS (--for all edgees going in, define the next_right_edge
			SELECT node_id, abs(s_edge_id) as edge_id, following_s_edge_id as next_right_edge 
			FROM se_edges_with_following
			WHERE s_edge_id >0 
		)
		, value_to_update AS ( --we use both previous CTE to gather information to update
			SELECT nlu.edge_id , nlu.next_left_edge, nru.next_right_edge
			FROM next_left_update AS nlu
				INNER JOIN next_right_update  as nru ON (nlu.edge_id = nru.edge_id) 
		) 
--		, fake_update AS ( --for debug only
-- 			SELECT v.* , ed.next_left_edge, ed.next_right_edge
-- 			FROM value_to_update as v, %1$I.edge_data AS ed
-- 			WHERE v.edge_id =  ed.edge_id --updating only when we have results
-- 				AND (ed.next_left_edge != v.next_left_edge OR ed.next_right_edge != v.next_right_edge ) 
			 
		,the_update AS ( --we update topology only if needed
			UPDATE %1$I.edge_data AS ed SET (next_left_edge ,abs_next_left_edge,next_right_edge ,abs_next_right_edge)
			= (v.next_left_edge , abs(v.next_left_edge) , v.next_right_edge, abs(v.next_right_edge))
			FROM value_to_update as v
			WHERE v.edge_id =  ed.edge_id --updating only when we have results
				AND (ed.next_left_edge != v.next_left_edge OR ed.next_right_edge != v.next_right_edge ) -- don t update if no change
			RETURNING ed.edge_id
		)
		SELECT array_agg(edge_id)
		FROM the_update ; 
		',topology_name)  ; 
		EXECUTE _q  INTO updated_edges USING nodes_to_update ; 
			
		--RAISE EXCEPTION 'not implemetned yet %', updated_edges;
		RETURN  updated_edges;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 



DROP FUNCTION IF EXISTS topology.rc_RecomputeFaceLinking_fewedges(topology_name TEXT, edges_to_update INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_RecomputeFaceLinking_fewedges(topology_name TEXT, edges_to_update INT[] )
 returnS int[] AS
$BODY$  
	/**
	@brief given a topoology where node-edge likning is correct, and edge-edge linking also, update face-linking (left_face, ...)
		--for each edge to update
			compute cycle
			get associated left_face and right_face
			if all identical, do nothing
			else , set all to minimum of face_id
	*/ 
	DECLARE     
		_q TEXT; 
		_r record; 
		_face_ids_to_delete INT[] ;
		_new_face_edges_geom geometry[];
	BEGIN     	  
		RAISE NOTICE 'edges to update : %', edges_to_update  ;
		
		--for each edge to update, get ring
		-- GetRingEdges(varchar atopology, integer aring, integer max_edges=null);
		WITH edges_to_up AS ( -- unnesting the list of edges to update
		SELECT DISTINCT 
			unnest(edges_to_update)  
			AS edge_id
		)
		, rings AS ( --for each edge, geztting the ring it is in, (aka the face )
			SELECT edge_id as base_id, f.sequence as ordinality, f.edge AS edge_id
			FROM edges_to_up, topology.GetRingEdges('bdtopo_topological',edge_id ) AS f 
			ORDER BY base_id, ordinality, edge_id  
		)
		, list_of_edge_faces AS ( --joingin the edge with edge table, to get sign and face_id of edge
			SELECT r.base_id, r.ordinality, abs(r.edge_id) as edge_id, ed.left_face as face_id, geom as edge_geom, +1 as sign
			FROM rings AS r
				LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
			WHERE r.edge_id >0 
			UNION ALL 
				SELECT r.base_id, r.ordinality, abs(r.edge_id) as edge_id , ed.right_face as face_id, geom as edge_geom, -1 as sign
				FROM rings AS r
					LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
				WHERE r.edge_id <0    
		) 
		 , problematic_faces AS ( -- this is a list of ring with more than 1 face_id in it
			SELECT *
			FROM (
				SELECT base_id , count(*) as nb_of_different_face_id
				FROM 
				 ( 	SELECT base_id, face_id  
					FROM list_of_edge_faces
					GROUP BY base_id, face_id ) AS sub
				GROUP BY base_id ) AS nb_distinct_values
			WHERE nb_of_different_face_id> 1 
			ORDER BY base_id
		)
		, face_id_to_delete AS (--here is the list of face_id to delete because they are used in non-unanimous ring
			SELECT DISTINCT ON (face_id) face_id
			FROM problematic_faces as pf
				LEFT OUTER JOIN list_of_edge_faces as le ON (pf.base_id = le.base_id)
		)
		 , new_face_mbr AS ( --computing the bbox of new face
			SELECT base_id,  rc_FindNextValue('bdtopo_topological', 'face', 'face_id') as nv , ST_Envelope(ST_Collect(edge_geom) ) as mbr, ST_Collect(edge_geom)  as collection
			FROM list_of_edge_faces AS le 
			WHERE EXISTS (SELECT 1 FROM problematic_faces AS pf WHERE pf.base_id  = le.base_id)
			GROUP BY base_id
			ORDER BY base_id 
		)
		, new_faces as ( --inserting new faces  into face table
			INSERT INTO bdtopo_topological.face (face_id, mbr) 
			SELECT --rc_FindNextValue('bdtopo_topological', 'face', 'face_id') AS new_face_id,  
				nv , mbr
			FROm new_face_mbr AS pf  
			RETURNING face_id 
		)
		 , prepare_edges_update AS (--getting together information to prpare edge update
			SELECT nf.nv, lo.*
			FROM new_face_mbr AS nf,
				list_of_edge_faces as lo 
			WHERE nf.base_id = lo.base_id  
		)
		,update_left_face AS ( --updating edge
			UPDATE bdtopo_topological.edge_data AS ed SET  left_face   = nv 
			FROM prepare_edges_update AS pe
			WHERE pe.edge_id  = ed.edge_id AND pe.sign <0
			RETURNING ed.edge_id  
		) 
		,update_right_face AS ( --updating edge
			UPDATE bdtopo_topological.edge_data AS ed SET  right_face   = nv 
			FROM prepare_edges_update AS pe
			WHERE pe.edge_id  = ed.edge_id AND pe.sign >0
			RETURNING ed.edge_id  
		)
		SELECT  (SELECT array_agg(face_id) face_ids_to_delete FROM face_id_to_delete) as face_ids_to_delete
			 , (SELECT array_agg(collection) AS new_face_edges_geom FROM new_face_mbr) AS new_face_edges_geom
		INTO _face_ids_to_delete,  _new_face_edges_geom ;
		
		--recomputing edge_linking : 
		--RAISE EXCEPTION 'not implemetned yet  % %', _face_ids_to_delete,  _new_face_edges_geom ;
		RETURN  ARRAY[1,2];
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 

--121 , 122, 127



  UPDATE bdtopo_topological.edge_editing SET edge_geom = 
 ST_GeomFromtext('LINESTRINGZ(-3952.33 20574.37 0,-3953.10 20572.09 0)',932011) 
 WHERE edge_id = 122; 
  
  /*
	WITH edges_to_up AS ( -- unnesting the list of edges to update
		SELECT DISTINCT 
			unnest(ARRAY[121,122,127]) 
			--unnest(ARRAY[ 127]) 
			AS edge_id
	)
	, rings AS ( --for each edge, geztting the ring it is in, (aka the face )
		SELECT edge_id as base_id, f.sequence as ordinality, f.edge AS edge_id
		FROM edges_to_up, topology.GetRingEdges('bdtopo_topological',edge_id ) AS f 
		ORDER BY base_id, ordinality, edge_id  
	)
	, list_of_edge_faces AS ( --joingin the edge with edge table, to get sign and face_id of edge
		SELECT r.base_id, r.ordinality, abs(r.edge_id) as edge_id, ed.left_face as face_id, geom as edge_geom, +1 as sign
		FROM rings AS r
			LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
		WHERE r.edge_id >0 
		UNION ALL 
			SELECT r.base_id, r.ordinality, abs(r.edge_id) as edge_id , ed.right_face as face_id, geom as edge_geom, -1 as sign
			FROM rings AS r
				LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
			WHERE r.edge_id <0   
		UNION ALL --only for debug
		SELECT 121, 0,121,2, NULL, 1
		UNION ALL
		SELECT 127, 0,121,3, NULL, 1
	) 
	 , problematic_faces AS ( -- this is a list of ring with more than 1 face_id in it
		SELECT *
		FROM (
			SELECT base_id , count(*) as nb_of_different_face_id
			FROM 
			 ( 	SELECT base_id, face_id  
				FROM list_of_edge_faces
				GROUP BY base_id, face_id ) AS sub
			GROUP BY base_id ) AS nb_distinct_values
		WHERE nb_of_different_face_id> 1 
		ORDER BY base_id
	)
	, face_id_to_delete AS (--here is the list of face_id to delete because they are used in non-unanimous ring
		SELECT DISTINCT ON (face_id) face_id
		FROM problematic_faces as pf
			LEFT OUTER JOIN list_of_edge_faces as le ON (pf.base_id = le.base_id)
	)
	 , new_face_mbr AS ( --computing the bbox of new face
		SELECT base_id,  rc_FindNextValue('bdtopo_topological', 'face', 'face_id') as nv , ST_Envelope(ST_Collect(edge_geom) ) as mbr, ST_Collect(edge_geom)  as collection
		FROM list_of_edge_faces AS le 
		WHERE EXISTS (SELECT 1 FROM problematic_faces AS pf WHERE pf.base_id  = le.base_id)
		GROUP BY base_id
		ORDER BY base_id 
	)
	, new_faces as ( --inserting new faces  into face table
		INSERT INTO bdtopo_topological.face (face_id, mbr) 
		SELECT --rc_FindNextValue('bdtopo_topological', 'face', 'face_id') AS new_face_id,  
			nv , mbr
		FROm new_face_mbr AS pf  
		RETURNING face_id

-- 		SELECT 32 AS face_id
-- 		UNION 
-- 		SELECT 33 AS face_id
	)
	 , prepare_edges_update AS (--getting together information to prpare edge update
		SELECT nf.nv, lo.*
		FROM new_face_mbr AS nf,
			list_of_edge_faces as lo 
		WHERE nf.base_id = lo.base_id  
	)
	,update_left_face AS ( --updating edge
		UPDATE bdtopo_topological.edge_data AS ed SET  left_face   = nv 
		FROM prepare_edges_update AS pe
		WHERE pe.edge_id  = ed.edge_id AND pe.sign <0
		RETURNING ed.edge_id  
	) 
	,update_right_face AS ( --updating edge
		UPDATE bdtopo_topological.edge_data AS ed SET  right_face   = nv 
		FROM prepare_edges_update AS pe
		WHERE pe.edge_id  = ed.edge_id AND pe.sign >0
		RETURNING ed.edge_id  
	)
	SELECT 
		(SELECT array_agg(face_id_to_delete)FROM face_id_to_delete) as face_ids_to_delete, (SELECT array_agg(collection) FROM new_face_mbr) 

-- 	DELETE FROM bdtopo_topological.face
-- 	WHERE face_id >= 25 ; 

	
-- 	, to_update AS (
-- 		SELECT *
-- 		FROM list_of_edge_faces
-- 	) 
*/