----------------------
-- Remi-C THALES IGN
--02/2015
----------------------
-- postgis topology function
----------------------
-- given (relative) edge_ids, correct face for those edges and other implicated edges


 
DROP FUNCTION IF EXISTS topology.rc_RecomputeFaceLinking(topology_name TEXT, edges_to_update INT[] ) ;
CREATE OR REPLACE FUNCTION topology.rc_RecomputeFaceLinking(topology_name TEXT, edges_to_update INT[],
OUT updated_edges INT[], OUT updated_nodes INT[], OUT created_faces INT[] , OUT deleted_faces INT[]
 )
AS
$BODY$  
	/**
	@brief given a topoology where node-edge likning is correct, and edge-edge linking also, update face-linking (left_face, right_face , manage face )
		see svg schema for documentation

		- find rings
		- deduplicate rings
		- for each ring (sub-function in plpgsql) 
		  - if the ring is an inside or an (outside or flat) ring
		  inside : 
		     - if the relevant face linked by edges of the ring are all the same and not 0
		       - do nothing
		     - else
		       -  create a new face
		  outside : 
		     - find bounding face (0 by default)
		  - update left_face, right_face
		  - delete useless face
		  - update isolated nodes
	*/ 
	DECLARE     
		_q TEXT; 
		_r record;  
		_updated_edges INT[] ; 
		_inserted_face INT[] ; 
		_updated_nodes INT[] ; 
		_deleted_faces INT[] ; 
		_created_faces INT[]  ;
		
	BEGIN     	   

		WITH edges_to_up AS ( -- unnesting the list of edges to update
			SELECT DISTINCT 
			unnest(ARRAY[832,-832,833,830,-830])  
			AS edge_id
		) 
		 ,rings AS  ( --for each edge, geztting the ring it is in, (aka the face ), but we don't want the same ring twice
			SELECT DISTINCT ON (edge_id) edge_id as base_id, f.sequence as ordinality, f.edge AS edge_id
			FROM edges_to_up, topology.GetRingEdges(topology_name,edge_id ) AS f 
			ORDER BY edge_id , base_id
		) 
		SELECT topology.rc_RingToFace(topology_name, array_agg(edge_id ORDER BY ordinality))
			INTO _r
		FROM rings
		GROUP BY base_id ; 
		
		updated_edges := _updated_edges ; updated_nodes := _updated_nodes ;
		created_faces := _inserted_face ; deleted_faces := _deleted_faces ; 
		RETURN  ;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 



	WITH edges_to_up AS ( -- unnesting the list of edges to update
			SELECT DISTINCT 
			unnest(ARRAY[832,-832,833])  
			AS edge_id
		) 
		 ,rings AS  ( --for each edge, geztting the ring it is in, (aka the face ), but we don't want the same ring twice
			SELECT DISTINCT ON (edge_id) edge_id as base_id, f.sequence as ordinality, f.edge AS edge_id
			FROM edges_to_up, topology.GetRingEdges('bdtopo_topological',edge_id ) AS f 
			ORDER BY edge_id , base_id
		)
		SELECT topology.rc_RingToFace('bdtopo_topological' ,array_agg(edge_id ORDER BY ordinality) ) 
		FROM rings
		ORDER BY base_id, ordinality




	DROP FUNCTION IF EXISTS topology.rc_RingToFace(topology_name TEXT, signed_edges_of_ring INT[] ) ;
	CREATE OR REPLACE FUNCTION  topology.rc_RingToFace(topology_name TEXT, signed_edges_of_ring INT[]  )
	RETURNS BOOLEAN
	AS $BODY$   
		/** given a ring, will update correct left_face, right_face  of edges of ring, and manage face
		 - if the ring is an inside or an (outside or flat) ring
		  inside : 
		     - if the relevant face linked by edges of the ring are all the same and not 0
		       - do nothing
		     - else
		       -  create a new face
		  outside : 
		     - find bounding face (0 by default)
		  - update left_face, right_face
		  - delete useless face
		  - update isolated nodes
		*/
		DECLARE 
		 _is_inside BOOLEAN ; 
		 _is_flat BOOLEAN ; 
		BEGIN

			--is the ring inside or outside?
			_is_inside := topology.rc_SignedArea(topology_name, signed_edges_of_ring ) >0 ; 
			--is the ring flat?
			_is_flat := topology.rc_IsRingFace(signed_edges_of_ring) ; 

			--deal first with the simple is_inside case
			IF _is_inside = TRUE THEN
			
				WITH rings AS ( -- unnesting the list of edges to update
						SELECT DISTINCT ON (edge_id) f.* AS s_edges
						FROM  rc_unnest_with_ordinality( ARRAY[-832,833,-833,830,-831])  AS f(edge_id,ordinality)
						ORDER BY edge_id
					 
				)  
				, list_of_edge_faces AS ( --joingin the edge with edge table, to get sign and face_id of edge
					SELECT  r.ordinality,r.edge_id AS s_edge_id, abs(r.edge_id) as edge_id, ed.left_face as face_id, geom as edge_geom, +1 as sign
					FROM rings AS r
						LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
					WHERE r.edge_id >0 
						UNION ALL 
						SELECT   r.ordinality,r.edge_id AS s_edge_id, abs(r.edge_id) as edge_id , ed.right_face as face_id, geom as edge_geom, -1 as sign
					FROM rings AS r
						LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id)
					WHERE r.edge_id <0    
				) 
				, problematic_rings AS ( -- this is a list of ring with not homogeneous face_id
				-- are the face id different?
				-- are the face id identical and all egal to 0
					SELECT  (nb_of_different_face_id>0)::boolean AS need_to_create_face
					FROM (
						SELECT  count(*) as nb_of_different_face_id, max(sum_abs_face_ids) AS sum_abs_face_ids
						FROM 
						 ( 	SELECT  face_id ,   sum(abs(face_id))  AS sum_abs_face_ids
							FROM list_of_edge_faces as r 
							GROUP BY  face_id 
							) AS sub
						  )AS nb_distinct_values
					WHERE nb_of_different_face_id> 1 
						OR sum_abs_face_ids = 0 --this  adds the ring if it is only constitued of 0 face_id (universal face can't have a ring !) 
				)
				, face_id_to_delete AS (--here is the list of face_id to delete because they are used in non-unanimous ring
						SELECT DISTINCT ON (face_id) face_id
						FROM list_of_edge_faces, problematic_rings
						WHERE face_id != 0
				) , creating_face AS (
					SELECT topology.rc_CreateFaceFromRing(topology_name, array_agg(edge_id)) AS face_id
					FROM rings 
				) 
				, updating_edges AS(
					SELECT topology.Update_face_of_RingEdges(topology_name, array_agg(edge_id) ,face_id) AS correctly_updated
					FROM rings, creating_face
				)
				SELECT correctly_updated
				FROM  updating_edges; 
			END IF ; 
			

		RETURN  TRUE;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE; 



DROP FUNCTION IF EXISTS topology.Update_face_of_RingEdges(topology_name TEXT, signed_edges_of_ring INT[] , new_face_id int) ;
	CREATE OR REPLACE FUNCTION  topology.Update_face_of_RingEdges(topology_name TEXT, signed_edges_of_ring INT[] , new_face_id int )
	RETURNS BOOLEAN 
	AS $BODY$   
		/** @brief given a ring, and a face_id, update the left/right_face of the edges of the ring 
		*/
		DECLARE
			_useless int ; 
		BEGIN
		EXECUTE format('
		
	WITH rings AS ( -- unnesting the list of edges to update
			SELECT abs(s_edges) AS edge_id , sign(s_edges) as sign 
				,  floor($2)::int AS new_face_id
			FROM   unnest ($1)  AS s_edges 
			ORDER BY edge_id
		)  
		, prepare_edges_update AS (--getting together information to prpare edge update
			SELECT DISTINCT ON (edge_id)  new_face_id AS nv
				,edge_id 
				, sign 
				,  (count(*) over(PARTITION by edge_id) -1)::int::boolean AS need_update_left_and_right
				 
				--we need to separate case when needong to update BOTH, because several update of same row is forbiden in CTE
			FROM rings AS nf   
		) 
		------
		--NOTE : postgres limitation : can t update same things in several CTE, hence the need to do 3 separate update. 
		------
		,update_edge_only_left_face AS (  --updating left_face of edge with new face id
			UPDATE %1$I.edge_data AS ed SET  left_face   = nv 
			FROM prepare_edges_update AS pe
			WHERE pe.edge_id  = ed.edge_id AND pe.sign >0
				AND need_update_left_and_right = FALSE
			RETURNING ed.edge_id  
		)
		,update_edge_only_right_face AS (   --updating right_face of edge with new face id
			UPDATE %1$I.edge_data AS ed SET  right_face   = nv 
			FROM prepare_edges_update AS pe
			WHERE pe.edge_id  = ed.edge_id AND pe.sign <0
				AND need_update_left_and_right = FALSE
			RETURNING ed.edge_id   
		)
		,update_edge_right_and_left AS( --updating both left_face and right_face of edge with new face id
			UPDATE %1$I.edge_data AS ed SET (left_face,right_face )  = (nv, nv)
			FROM prepare_edges_update AS pe
			WHERE  pe.edge_id  = ed.edge_id
				AND need_update_left_and_right = TRUE
			RETURNING ed.edge_id   
		)
		SELECT 1  ; ',topology_name) INTO _useless    USING signed_edges_of_ring,new_face_id; 
		RETURN _useless IS NOT NULL;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE STRICT; 
