-----------/----------
--Rémi-C, Thales IGN
-- 02 / 2015
--
-- editing a postgis_topology in qgis
---------------------
--this function updates the containing face of a set of nodes.
-- This function is lean because it avoids computing real face geometry when unecessary, and doesn't compute the same face real geometry several time. 


DROP FUNCTION IF EXISTS topology.rc_CorrectIsolatedNodes(topology_name TEXT, isolated_node_to_update INT[], faces_to_delete INT[]  ) ;
CREATE OR REPLACE FUNCTION topology.rc_CorrectIsolatedNodes(topology_name TEXT, isolated_node_to_update INT[], faces_to_delete INT[], OUT updated_node INT[] )
  AS
$BODY$  
	/**
	@brief given a topology where isolated_node may have wrong face ,correct the containing_face of this nodes. 

	for all nodes as input
		get the potential containing face (bbox intersection)
		list the unique potential containing face, compute the true geom of potential containing face
		assign the node to the smallest containing face,or universal face
		
	*/ 
	DECLARE     
		_q TEXT; 
		_r record;   
	BEGIN     	
	  
		WITH input_data AS ( --proxy to isolate input, and be able to test the query outside of function
		SELECT    faces_to_delete
			,isolated_node_to_update
		)
		,isolated_node_to_update AS (
			SELECT DISTINCT node_id
			FROM input_data AS id, unnest(id.isolated_node_to_update) AS node_id
		)
		, faces_to_delete AS ( --listing the face to delete, which should not be used as new value
			SELECT DISTINCT face_id --distinct is a security
			FROM input_data AS id, unnest(id.faces_to_delete) as face_id
		)
		, nodes_to_update AS ( --list of node whose containing_face field we want to update
			SELECT DISTINCT  node_id 
			FROM (
			SELECT node_id  --distinct is a security
			FROM faces_to_delete as fd , bdtopo_topological.node AS n 
			WHERE fd.face_id = n.containing_face 
				OR n.containing_face = 0 -- inlcuding all isolated node in universal face, not optimal ! 
			UNION
			SELECT node_id 
			FROM isolated_node_to_update) AS sub
		)
		 , nodes_with_geom AS ( --joing to topology to get the node geom
			SELECT *
			FROM nodes_to_update
				NATURAL JOIN bdtopo_topological.node
		)
		---- NOTE
		-- we first find the potentoal face_id, then compute geometry once per face (and not several time), then use it.
		-- This way we may avoid a lot of computing of face geometry, which is costly
		----
		, potential_face_id AS ( --getting the face potentially containing the node, (potentially because it is a bbox test)
			SELECT node_id, geom as node_geom , face_id  
			FROM nodes_with_geom as nw, bdtopo_topological.face as f
			WHERE (ST_Within(nw.geom,f.mbr) OR  f.face_id = 0) --including 0 face(univerqal face) for all nodes
				AND NOT EXISTS ( --dont include faces that will be deleted
					SELECT 1 
					FROM faces_to_delete as ftd
					WHERE ftd.face_id = f.face_id
					)
		)
		, potential_faces_geom AS(	--listing the potential face and finding their geometry
			SELECT face_id, node_geom
				, CASE --adding a security to alwys include 0 face, in case the ring is wihtin the universal face (0)
						WHEN face_id<> 0 THEN ST_GetFaceGeometry('bdtopo_topological', face_id) 
						ELSE NULL -- ST_GeomFromtext('POLYGON EMPTY',ST_SRID(node_geom)) 
				END as face_geom
			FROM (SELECT DISTINCT ON (face_id) face_id  , node_geom FROM potential_face_id) as sub 
		)
		,exact_face AS (--finding containing face with real face geometry. Use universal face by default, safe for absence of universal face
			SELECT DISTINCT ON (pi.node_id) pi.node_id, pi.face_id 
				, ST_Area(face_geom) as area
			FROM potential_face_id as pi
				NATURAL JOIN potential_faces_geom as pg
			WHERE ST_Intersects(face_geom,node_geom ) AND face_id != 0 OR  face_id = 0
			ORDER BY  pi.node_id, area ASC NULLS LAST, (pi.face_id=0) DESC,  pi.face_id DESC
				-- in the where, we see if the point is really intersecting the actual face, and not only the bbow
				--, while ignoring this test for universal face
				--complicated order by : getting prioritarly the smallest face (excluding NULL face)
				--, then  prioritary the 0 face if any, then the highest face id if there were no universal face
		) 
		, updating_node AS(--update the node accordingly if necessary
			UPDATE bdtopo_topological.node set containing_face = face_id
			FROM exact_face
			WHERE node.node_id = exact_face.node_id
				AND node.containing_face <> exact_face.face_id --no need to update if value is already correct
			RETURNING node.node_id
		)
		SELECT array_agg(node_id) as updated_node FROM updating_node INTO updated_node ; 

		--RAISE EXCEPTION 'updated_node : %',updated_node ;
		RETURN  ;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE  CALLED ON NULL INPUT; 