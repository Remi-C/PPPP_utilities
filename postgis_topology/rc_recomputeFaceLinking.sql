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
		_face_to_delete INT[] ; 
		_face_created INT; 
		_face_updated INT ; 
		_edge_updated INT[] ; 
		_node_updated INT[] ;
		_edge_updated_outside INT[] ;
		BEGIN

			--is the ring inside or outside?
			_is_inside := topology.rc_SignedArea(topology_name, signed_edges_of_ring ) >0 ; 
			--is the ring flat?
			_is_flat := topology.rc_IsRingFace(signed_edges_of_ring) ; 

			--deal first with the simple is_inside case
			IF _is_inside = TRUE THEN
			
				SELECT *
				FROM  topology.rc_RingToFace_inside(topology_name, signed_edges_of_ring) 
				INTO _face_to_delete, _face_created, _edge_updated, _face_updated ;
			ELSE
				RAISE EXCEPTION 'ring is an outside ring "%" or a flat ring "%"',NOT _is_inside,_is_flat  ; 
				--outside ring, or flat ring 
				SELECT *
				FROM  topology.rc_RingToFace_outside(topology_name, signed_edges_of_ring,_face_to_delete) 
				INTO  _edge_updated_outside ;
				
			END IF ; 

			-- update isolated nodes
			WITH faces_where_node_should_be_updated AS (
				SELECT unnest(_face_to_delete) AS face_id
				UNION  SELECT _face_updated
				UNION SELECT _face_created
			)
			,isolated_node_to_update AS ( --we take all the nodes that are isolated and may have been affected (geometrically), and may have been affteced (semantically). 
				SELECT n.node_id
				FROM faces_where_node_should_be_updated AS fw
					LEFT OUTER JOIN bdtopo_topological.face AS f USING (face_id)
					, bdtopo_topological.node AS n  
				WHERE ST_Intersects(n.geom , f.mbr ) = TRUE
					AND n.containing_face IS NOT NULL
					OR n.containing_face = _face_created
					OR n.containing_face = _face_updated
					OR n.containing_face = ANY (_face_to_delete)
			)
			SELECT rc_CorrectIsolatedNodes(topology_name, array_agg(node_id),_face_to_delete) INTO _node_updated
			FROM isolated_node_to_update ; 
			 
			
			-- delete useless face 
			DELETE FROM bdtopo_topological.face WHERE
			face_id = ANY (_face_to_delete) ; 
			

			RAISE EXCEPTION ' _face_created %, _face_updated % , _edge_updated %, _edge_updated_outside %, _node_updated %, _face_to_delete %  '
				 , _face_created, _face_updated,  _edge_updated ,_edge_updated_outside ,  _node_updated,_face_to_delete; 
		RETURN  TRUE;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE STRICT; 

	DROP FUNCTION IF EXISTS topology.rc_RingToFace_inside(topology_name TEXT, signed_edges_of_ring INT[] ) ;
	CREATE OR REPLACE FUNCTION  topology.rc_RingToFace_inside(topology_name TEXT, signed_edges_of_ring INT[] 
		,OUT face_to_delete INT[], OUT face_created INT,OUT  edge_updated INT[], OUT face_updated INT)
	AS $BODY$   
		/** this is a helper function. Given a ring, will update correct left_face, right_face  of edges of ring, and manage face.
		Works only for inside face.
		WARNING : should not be used alone, there is no deletion of useless face, nor update of isolated nodes.
		 - if the ring is an inside  
		     - if the relevant face linked by edges of the ring are all the same and not 0
		       - update face MBR
		     - else
		       -  create a new face 
		*/
		DECLARE  
		_face_to_delete INT[] ; 
		_face_created INT; 
		_face_updated INT ; 
		_edge_updated INT[] ; 
		BEGIN

			 
			
				WITH rings AS ( -- unnesting the list of edges to update
						SELECT DISTINCT ON (edge_id) f.* AS s_edges
						FROM  rc_unnest_with_ordinality( signed_edges_of_ring)  AS f(edge_id,ordinality)
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
				, list_fo_face AS (
					SELECT DISTINCT face_id
					FROM list_of_edge_faces
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
				)  
				, creating_face AS (
					SELECT topology.rc_CreateFaceFromRing(topology_name, array_agg(edge_id)) AS face_id
					FROM problematic_rings, rings 
				) 
				, updating_face_MBR AS ( --updating the face MBR if the face wasn't created
					SELECT topology.rc_UpdateFaceMBRFromRing(topology_name, array_agg(lo.edge_id)  
						, (
						SELECT face_id 
						FROM list_fo_face
						WHERE face_id !=0
						EXCEPT 
						SELECT face_id 
						FROM creating_face 
						WHERE face_id !=0
						) )  AS updated_face
					FROM list_of_edge_faces AS lo 
				)
				, updating_edges AS(
					SELECT topology.Update_face_of_RingEdges(topology_name, array_agg(edge_id) ,face_id) AS updated_edges
					FROM problematic_rings, rings, creating_face
					GROUP BY face_id --useless
				)  
				SELECT (SELECT array_agg(face_id) 
						FROM  face_id_to_delete) 
					,(SELECT  face_id  
						FROM  creating_face) 
					,(SELECT updated_edges FROM updating_edges) 
					, (SELECT updated_face FROM updating_face_MBR)
				INTO face_to_delete, face_created, edge_updated, face_updated ;
			 

			--RAISE EXCEPTION '_face_to_delete %, _face_created %, _face_updated % , _edge_updated % ',_face_to_delete, _face_created, _face_updated,  _edge_updated ; 
		RETURN  ;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE STRICT; 



	DROP FUNCTION IF EXISTS topology.rc_RingToFace_outside(topology_name TEXT, signed_edges_of_ring INT[] , face_to_delete INT[]) ;
	CREATE OR REPLACE FUNCTION  topology.rc_RingToFace_outside(topology_name TEXT, signed_edges_of_ring INT[] , face_to_delete INT[]
		 ,OUT  edge_updated INT[] )
	AS $BODY$   
		/** this is a helper function. Given a ring, will update correct left_face, right_face  of edges of ring 
		Works only for outside face.
		WARNING : should not be used alone, there is no deletion of useless face, nor update of isolated nodes.
		 - if the ring is an  outside : 
		     - find bounding face (0 by default)
		  - update left_face, right_face
		*/
		DECLARE   
		_edge_updated INT[] ; 
		BEGIN
  
			WITH rings AS ( -- unnesting the list of edges to update
				SELECT DISTINCT ON (edge_id) f.* AS s_edges
				FROM  rc_unnest_with_ordinality( signed_edges_of_ring)  AS f(edge_id,ordinality)
				ORDER BY edge_id 
			 
			)  
			, faces_to_delete AS (
				SELECT DISTINCT u AS face_id
				FROM unnest(face_to_delete) AS u
			)
			, list_of_edges AS ( --joingin the edge with edge table, to get sign and face_id of edge
				SELECT  r.ordinality,r.edge_id AS s_edge_id, abs(r.edge_id) as edge_id, sign(r.edge_id) AS sign , geom as edge_geom
				FROM rings AS r
					LEFT OUTER JOIN bdtopo_topological.edge_data AS ed ON (abs(r.edge_id ) = ed.edge_id) 
			) 
			,geom_collected AS (--constructing a grouping of edge geom per ring
				SELECT  ST_Collect(edge_geom) AS edge_collected
				FROM list_of_edges 
			)
			,potential_faces AS (--getting potential face where the ring could potentially within, and that are not in the deleted list
				--it is potential because we use bbox, but we must check with actual geometry
				SELECT  edge_collected,  f.face_id AS potential_face_id
					,CASE --adding a security to alwys include 0 face, in case the ring is wihtin the universal face (0)
						WHEN  f.face_id<> 0 THEN ST_GetFaceGeometry('bdtopo_topological',  f.face_id) 
						ELSE ST_GeomFromtext('POLYGON EMPTY',ST_SRID(edge_collected)) 
					END as face_geom
				FROM geom_collected as gc, bdtopo_topological.face as f
				WHERE (ST_Within(gc.edge_collected,f.mbr) OR  f.face_id = 0) --including 0 face 
					AND NOT EXISTS (--must not choose face that will be deleted ! 
						SELECT *
						FROM faces_to_delete AS fd
						WHERE fd.face_id  =  f.face_id
					)
					   
			)
			,exact_face AS ( --use the actual face geometry to perform the within test, include the 0 face in case there are no others
				SELECT  potential_face_id --the disctinct and ORDER are essentials
					, CASE WHEN ST_Area(face_geom) >0 THEN ST_Area(face_geom) ELSE NULL END  as area --we assign the NULL area to universal face 
				FROM potential_faces
					WHERE (ST_Within(edge_collected,face_geom) = TRUE OR potential_face_id = 0)
					ORDER BY  area ASC NULLS LAST, potential_face_id ASC --null is for the universal face, that should be used in last resort
				LIMIT 1 
			) 
			,preparing_update AS ( --listing edge with associated new face_id 
				SELECT DISTINCT ON (ei.s_edge_id)   ei.s_edge_id, ei.ordinality,  potential_face_id --distinct is just a security
				FROM exact_face as ef , list_of_edges as ei 
			)
			, updating_edges AS(
				SELECT topology.Update_face_of_RingEdges(topology_name, array_agg(s_edge_id ORDER BY ordinality ASC) ,potential_face_id) AS updated_edges
				FROM preparing_update 
				GROUP BY potential_face_id --useless
			)  
			SELECT  
				(SELECT  updated_edges  FROM updating_edges)  
			INTO   edge_updated ;
			 

			--RAISE EXCEPTION '  _edge_updated % ',  _edge_updated ; 
		RETURN  ;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT ; 



DROP FUNCTION IF EXISTS topology.Update_face_of_RingEdges(topology_name TEXT, signed_edges_of_ring INT[] , new_face_id int) ;
	CREATE OR REPLACE FUNCTION  topology.Update_face_of_RingEdges(topology_name TEXT, signed_edges_of_ring INT[] , new_face_id int, OUT updated_edges INT[] ) 
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
				AND left_face != nv
			RETURNING ed.edge_id  
		)
		,update_edge_only_right_face AS (   --updating right_face of edge with new face id
			UPDATE %1$I.edge_data AS ed SET  right_face   = nv 
			FROM prepare_edges_update AS pe
			WHERE pe.edge_id  = ed.edge_id AND pe.sign <0
				AND need_update_left_and_right = FALSE
				AND right_face != nv
			RETURNING ed.edge_id   
		)
		,update_edge_right_and_left AS( --updating both left_face and right_face of edge with new face id
			UPDATE %1$I.edge_data AS ed SET (left_face,right_face )  = (nv, nv)
			FROM prepare_edges_update AS pe
			WHERE  pe.edge_id  = ed.edge_id
				AND need_update_left_and_right = TRUE
				AND (right_face != nv OR left_face != nv)
			RETURNING ed.edge_id   
		)
		, updated_edges AS (
			SELECT edge_id
			FROM update_edge_only_left_face
			UNION SELECT edge_id
			FROM update_edge_only_right_face
			UNION SELECT edge_id
			FROM update_edge_right_and_left 
		)
		SELECT array_agg(edge_id)
		FROM updated_edges ; ',topology_name) INTO updated_edges USING signed_edges_of_ring,new_face_id; 
		RETURN  ;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE STRICT; 
