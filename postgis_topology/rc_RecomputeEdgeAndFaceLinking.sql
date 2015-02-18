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
		--SELECT  topology.rc_RecomputeFaceLinking_fewedges(topology_name , updated_edges) into updated_faces ; 
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

		givena list of edge to update
			compute the cicle for each edge
			deduplicate the cycles
			for each cycle, check if it forms a face or not
				not_forming_face are separated to be dealt with later
			for each cycle, check if the corresponding face_id (left or right depending on the sign) are homogenous (that is, all face_id in a cycle should be identical)
				if homogeneous, do nothing
				if not homogenous, 
					create a new face corresponding to the cicle
					collect the different face_id in the non-homogeneous cycle (aka face_to_delete)
					update all face_id (left or right depending on the sign of s_edge_id) with new face

			deal with not_forming_face_ring
				check in which face they are included
					first check in which mbr
					then for each mbr found, compute the face geom,
					check in which face geom the not_forming_face_ring is
					collect old face_id of the not_forming_face_ring
					update face_id with containing face

			Merge face_to_delete list
				merge list from both sources (not_forming_face_ring and regular)

			deal with isolated node
				for all isolated node that are in the face_to_delete list, update the containing_face

			delete face_to_delete.
				Try to delete, an error in relation means something went wrong.
			 
	*/ 
	DECLARE     
		_q TEXT; 
		_r record; 
		_face_ids_to_delete INT[] ; 
		_edges_in_non_face_ring TEXT[]; 
		_updated_edges INT[] ; 
	BEGIN     	  
		RAISE NOTICE 'edges to update : %', edges_to_update  ;

		--create new face, update edge left and right face when dealing with regular face (ie non-flat face)
		SELECT topology.rc_RecomputeFaceLinking_fewedges_onlyvalidface(topology_name  , edges_to_update)
		INTO _face_ids_to_delete, _edges_in_non_face_ring, _updated_edges ;

		--
		
		--recomputing edge_linking : 
		--RAISE EXCEPTION 'not implemetned yet  % %', _face_ids_to_delete,  _new_face_edges_geom ;
		RETURN  ARRAY[1,2];
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 




DROP FUNCTION IF EXISTS topology.rc_RecomputeFaceLinking_fewedges_onlyvalidface(topology_name TEXT, edges_to_update INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_RecomputeFaceLinking_fewedges_onlyvalidface(topology_name TEXT, edges_to_update INT[],
	OUT _updated_edges INT[], OUT _face_ids_to_delete INT[],OUT _edges_in_non_face_ring TEXT[] )
  AS
$BODY$  
	/**
	@brief given a topoology where node-edge likning is correct, and edge-edge linking also, update face-linking (left_face, ...)
	@WARNING DONT USE THIS FUNCTION ALONE (also need to deal with flat-face, isolatednode, and delete old face_id)
		givena list of edge to update
			compute the cicle for each edge
			deduplicate the cycles
			for each cycle, check if it forms a face or not
				not_forming_face are separated to be dealt with later
			for each cycle, check if the corresponding face_id (left or right depending on the sign) are homogenous (that is, all face_id in a cycle should be identical)
				if homogeneous, do nothing
				if not homogenous, 
					create a new face corresponding to the cicle
					collect the different face_id in the non-homogeneous cycle (aka face_to_delete)
					update all face_id (left or right depending on the sign of s_edge_id) with new face 

		@return _updated_edges : edge that have been modified (left_face and right_face column exclusively)
		@return _face_ids_to_delete : list of faces that were used by updated edge. NOT safe to delete until flat-face have been dealt with and isolated_node too
		@return _edges_in_non_face_ring : array of ring (array of edge) that for flat face. 
	*/ 
	DECLARE     
		_q TEXT; 
		_r record;   
	BEGIN     	  
		RAISE NOTICE 'edges to update : %', edges_to_update  ;
		
		--for each edge to update, get ring
		-- GetRingEdges(varchar atopology, integer aring, integer max_edges=null);
		WITH edges_to_up AS ( -- unnesting the list of edges to update
		SELECT DISTINCT 
			unnest(edges_to_update)  
			AS edge_id
		) 
		 ,rings AS  ( --for each edge, geztting the ring it is in, (aka the face ), but we don't want the same ring twice
			SELECT DISTINCT ON (edge_id) edge_id as base_id, f.sequence as ordinality, f.edge AS edge_id
			FROM edges_to_up, topology.GetRingEdges('bdtopo_topological',edge_id ) AS f 
			ORDER BY edge_id , base_id
		)
		,real_faces AS ( --check wether the ring form a real face (i.e not a flat face)
			SELECT base_id, topology.rc_IsRingFace(array_agg(edge_id)) as is_this_ring_a_real_face
			FROM rings
			GROUP BY base_id 
		)
		, list_of_edge_faces AS ( --joingin the edge with edge table, to get sign and face_id of edge
			SELECT r.base_id, r.ordinality, abs(r.edge_id) as edge_id, ed.left_face as face_id, geom as edge_geom, +1 as sign
			FROM rings AS r
				LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
			WHERE r.edge_id >0 
				--AND EXISTS --we don't take ring that dont form real face
				--	(SELECT 1 FROM real_faces  as rf WHERE rf.base_id = r.base_id AND is_this_ring_a_real_face = TRUE)
				UNION ALL 
				SELECT r.base_id, r.ordinality, abs(r.edge_id) as edge_id , ed.right_face as face_id, geom as edge_geom, -1 as sign
			FROM rings AS r
				LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
			WHERE r.edge_id <0    
				--AND EXISTS --we don't take ring that dont form real face
				--	(SELECT 1 FROM real_faces  as rf WHERE rf.base_id = r.base_id AND is_this_ring_a_real_face = TRUE)
		) 
		, problematic_rings AS ( -- this is a list of ring with not homogeneous face_id
			SELECT *
			FROM (
				SELECT base_id , count(*) as nb_of_different_face_id
				FROM 
				 ( 	SELECT base_id, face_id  
					FROM list_of_edge_faces as r 
					WHERE   EXISTS --we don't take ring that dont form real face
						(SELECT 1 FROM real_faces  as rf WHERE rf.base_id = r.base_id AND rf.is_this_ring_a_real_face = TRUE)
					GROUP BY base_id, face_id 
					) AS sub
				GROUP BY base_id ) AS nb_distinct_values
			WHERE nb_of_different_face_id> 1 
			ORDER BY base_id
		)
		, face_id_to_delete AS (--here is the list of face_id to delete because they are used in non-unanimous ring
			SELECT DISTINCT ON (face_id) face_id
			FROM problematic_rings as pf
				LEFT OUTER JOIN list_of_edge_faces as le ON (pf.base_id = le.base_id)
		)
		, new_face_mbr AS ( --computing the bbox of new face
			SELECT base_id
				,  rc_FindNextValue('bdtopo_topological', 'face', 'face_id') as nv 
				, ST_Envelope(ST_Collect(edge_geom) ) as mbr
				--, ST_Collect(edge_geom)  as collection
				--, ST_Astext(ST_GeometryN(ST_Polygonize(edge_geom),1) )AS face_geom
			FROM list_of_edge_faces AS le 
			WHERE EXISTS (SELECT 1 FROM problematic_rings AS pf WHERE pf.base_id  = le.base_id)
			GROUP BY base_id
			ORDER BY base_id 
		)
		, new_faces as ( --inserting new faces  into face table
			INSERT INTO bdtopo_topological.face (face_id, mbr) 
			SELECT 
				nv , mbr
			FROm new_face_mbr AS pf  
			RETURNING face_id 
		)
		 , prepare_edges_update AS (--getting together information to prpare edge update
			SELECT nf.nv, lo.*
				,  (count(*) over(PARTITION by edge_id) -1)::int::boolean AS need_update_left_and_right
				--we need to separate case when needong to update BOTH, because several update of same row is forbiden in CTE
			FROM new_face_mbr AS nf,
				list_of_edge_faces as lo 
			WHERE nf.base_id = lo.base_id  
		) 
		------
		--NOTE : postgres limitation : can't update same things in several CTE, hence the need to do 3 separate update. 
		------
		,update_edge_only_left_face AS (  --updating left_face of edge with new face id
			UPDATE bdtopo_topological.edge_data AS ed SET  left_face   = nv 
			FROM prepare_edges_update AS pe
			WHERE pe.edge_id  = ed.edge_id AND pe.sign >0
				AND need_update_left_and_right = FALSE
			RETURNING ed.edge_id  
		)
		,update_edge_only_right_face AS (   --updating right_face of edge with new face id
			UPDATE bdtopo_topological.edge_data AS ed SET  right_face   = nv 
			FROM prepare_edges_update AS pe
			WHERE pe.edge_id  = ed.edge_id AND pe.sign <0
				AND need_update_left_and_right = FALSE
			RETURNING ed.edge_id   
		)
		,update_edge_right_and_left AS( --updating both left_face and right_face of edge with new face id
			UPDATE bdtopo_topological.edge_data AS ed SET (left_face,right_face )  = (face_ids[1],face_ids[2])
			FROM ( --first grouping left and right face_id, so they are on one row
				SELECT edge_id, array_agg(nv ORDER BY sign DESC) as face_ids
				FROM prepare_edges_update
				WHERE need_update_left_and_right = TRUE
				GROUP BY edge_id
			) AS sub
			WHERE ed.edge_id = sub.edge_id
			RETURNING ed.edge_id  
		)
		SELECT --finale
			(SELECT array_agg(face_id_to_delete)FROM face_id_to_delete) as face_ids_to_delete 
			, ( --very compliated, because by default there is no (int[])[], so we use a (text)[], where text is in fact int[]
				--grouping all ring
				SELECT array_agg(sub2.edges_to_update::text) AS edges_to_update
				FROM ( --grouping by ring
					SELECT base_id, array_agg(edge_to_update )  as edges_to_update
					FROM ( --getting list of edge in ring that are not proper face
						SELECT DISTINCT rf.base_id, abs(edge_id)  as edge_to_update
						FROM real_faces  AS rf , rings as r
						WHERE is_this_ring_a_real_face = FALSE
							AND r.base_id = rf.base_id
					)  as sub
					GROUP BY base_id )  as sub2
			) as edges_in_non_face_ring
			, (--grouping
				SELECT array_agg(edge_id) 
				FROM --gettting together all update result. Union to avoid duplicates
				(	SELECT * FROM update_edge_only_left_face
					UNION SELECT * FROM update_edge_only_right_face
					UNION SELECT * FROM update_edge_right_and_left 
				)AS update_face  
			) as updated_edges
		INTO _face_ids_to_delete, _edges_in_non_face_ring, _updated_edges ;
		 
		RETURN   ;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 

--121 , 122, 127


/*


  UPDATE bdtopo_topological.edge_editing SET edge_geom = 
 ST_GeomFromtext('LINESTRINGZ(-3952.33 20574.37 0,-3953.10 20572.09 0)',932011) 
 WHERE edge_id = 122; 
 */
 
 /*
  given a list of edge to update
			compute the cicle for each edge
			deduplicate the cycles
			for each cycle, check if it forms a face or not
				not_forming_face are separated to be dealt with later
			for each cycle, check if the corresponding face_id (left or right depending on the sign) are homogenous (that is, all face_id in a cycle should be identical)
				if homogeneous, do nothing
				if not homogenous, 
					create a new face corresponding to the cicle
					collect the different face_id in the non-homogeneous cycle (aka face_to_delete)
					update all face_id (left or right depending on the sign of s_edge_id) with new face
*/

	--WITH result_on_non_flat_face AS (
	SELECT *
	FROM topology.rc_RecomputeFaceLinking_fewedges_onlyvalidface('bdtopo_topological'  , ARRAY[405,406,407,411])
	--)