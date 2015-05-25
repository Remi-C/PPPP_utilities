-------------------------------
-- Remi-C , Thales IGN, 2014
-- 
--this function update the isolation status of a node
------------------------------

  
DROP FUNCTION IF EXISTS topology.rc_UpdateNodeisolation(varchar, int, geometry, int[] ); 
CREATE OR REPLACE FUNCTION topology.rc_UpdateNodeisolation( IN atopology  varchar ,IN node_id  INT , IN node_geom geometry, OUT containing_face int, IN transfered_edges int[] DEFAULT NULL)
AS
$BODY$
		--@brief this function moves a node and update all connected edges geometry accordingly, then delete the old node, then update the new node isolation level.
		DECLARE 
			_topology_precision float := 0 ; 
			_face_id int := NULL;  
			_nb_connected_edges int := 0 ; 
			_q TEXT; 
		BEGIN 
			SELECT precision into _topology_precision
			FROM topology.topology
			WHERE name = atopology  ;   

			--is this node isolated? 
			SELECT count(*) INTO _nb_connected_edges FROM (
				SELECT 1 FROM GetNodeEdges(atopology, node_id)
				UNION ALL 
				SELECT unnest(quote_literal(containing_face)::int[])
				 ) AS sub ;

			IF _nb_connected_edges = 0 THEN
				--the node is isolated, find the new containing face
				_face_id :=  topology.getfacebypoint(atopology , node_geom,  _topology_precision )  ; 
				_face_id := COALESCE(_face_id, 0); 
			ELSE 
				_face_id := NULL ;
			END IF ; 
			containing_face := _face_id ; 
			RETURN; 
		END ;
	$BODY$
LANGUAGE plpgsql VOLATILE;





