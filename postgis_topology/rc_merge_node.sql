-------------------------------
-- Remi-C , Thales IGN, 2014
-- 
--this function merge a topo node A into a topo node B.
--This means it transfer all the edges of A to B, then update the geometry of trasnfered edges, and checks for errors.
------------------------------

  
DROP FUNCTION IF EXISTS topology.rc_MergeNodeIntoAnother(varchar, int, int, geometry, geometry, int[] ); 
CREATE OR REPLACE FUNCTION topology.rc_MergeNodeIntoAnother( IN atopology  varchar ,INOUT from_node_id  INT ,INOUT to_node_id  INT, IN from_node_geom geometry 
,  to_node_geom geometry, edge_to_transfer int[] DEFAULT NULL)AS
$BODY$
		--@brief this function moves a node and update all connected edges geometry accordingly, then delete the old node, then update the new node isolation level.
		DECLARE 
			_topology_precision float := 0 ; 
			_face_id int := NULL;  
			_nb_connected_edges int := 0 ; 
			_q TEXT;
			_edges_to_transfer int[] ; 
		BEGIN 
			
			SELECT precision into _topology_precision
			FROM topology.topology
			WHERE name = atopology  ;   

			-- getting the edges to transfer :
			EXECUTE format('SELECT array_agg(edge_id) FROM  %I.edge_data AS e WHERE e.start_node = $1 OR e.end_node = $1 ',atopology) INTO _edges_to_transfer USING from_node_id  ; 

			
			--transfer edges
			IF _edges_to_transfer IS NOT NULL THEN --no need to transfer is there is nothing to transfer
				_q := format('UPDATE %I.edge_data AS e SET start_node = $2 WHERE e.start_node = $1 ',atopology);
				EXECUTE _q  USING from_node_id, to_node_id;
				_q := format('UPDATE %I.edge_data AS e SET end_node = $2 WHERE e.end_node = $1 ',atopology);
				EXECUTE _q  USING from_node_id, to_node_id;

			--updating the tansfered edges
				PERFORM topology.rc_MoveNonIsoNode_edges(atopology, to_node_id, to_node_geom,_edges_to_transfer, _topology_precision) ; 

			END IF ; 
		
			--delete old node
			EXECUTE format('DELETE FROM  %I.node AS n WHERE node_id = $1 ',atopology) USING from_node_id  ; 

			
			--update new node isolation if needed.
				PERFORM topology.rc_UpdateNodeisolation( atopology, to_node_id ,to_node_geom, _edges_to_transfer); 
			
			--RAISE EXCEPTION '_edges_to_transfer : % ',_edges_to_transfer  ; 
			
			--RAISE EXCEPTION 'input to_node : %, % ', to_node_id, st_astext(to_node_geom)  ; 
			
			RETURN; 
		END ;
	$BODY$
LANGUAGE plpgsql VOLATILE;





