-----------/----------
--Rémi-C, Thales IGN
-- 05 / 2015
--
-- editing a postgis_topology with a non-topological editor
---------------------
--aim of this project is to support the edition of baseis of a topology layer with non-topological GIS
-- aim of this project is to support edition of a linestring topology in qgis, via triggers on postgis topology 



--creating view for edition

DROP VIEW IF EXISTS bdtopo_topological.node_editing CASCADE; 
CREATE VIEW  bdtopo_topological.node_editing  AS (
	SELECT node_id, ST_Force2D(geom) as node_geom
	FROM bdtopo_topological.node
); 
 


--creating trigger for edition of node
CREATE OR REPLACE FUNCTION rc_edit_node_topology(  )
  RETURNS  trigger  AS
$BODY$  
	/**
	@brief this trigger is designed to allow edition of a node topological layer with a non topological tool

	allowed interaction are :
		--centered on node : create/delete/move node if it preserve topology
	
	Change on node :
	DELETE :
		based on the number of edges that are connected to this node
		0 edge	->	Delete Node 			| 
		1 edge	->	Delete Node 			| Delete Edge
		2 edges	->	Delete Node 			| Heal edge
		3+ edges	->	RAISE ERROR 			| 
	UPDATE :
		Based on the new neighbour of the node --> action on node | action on neighbourg 
		no new neighb.			-> update geom and containing_face	| update connected edges geom
		neigh = 1 node			-> Delete							| update edge geom, Merge
		neigh = node+edges		-> Same							| Same
		neigh = 1 edge			-> Same with node from Split		| Split, then same
	INSERT :
		create new empty node, then UPDATE
	*/

	DECLARE     
	BEGIN      

	IF TG_OP = 'DELETE' THEN  
		SELECT f.deleted_node_id , f.deleted_node_geom INTO OLD.node_id, OLD.node_geom
		FROM topology.rc_DeleteNodeSafe(TG_TABLE_SCHEMA::text, OLD.node_id,OLD.node_geom)   as f ;  
		RETURN NULL ;  
	END IF ; --end of delete dealing 


	IF TG_OP = 'UPDATE' THEN 
		--update/insert case
		NEW.node_geom = ST_Force3D(NEW.node_geom) ;  --safeguard against qgis
		SELECT f.moved_node_id , f.moved_node_geom INTO NEW.node_id, NEW.node_geom
		FROM topology.rc_MoveNodeSafe(TG_TABLE_SCHEMA::text, NEW.node_id,NEW.node_geom)   as f ;  
		 
		RETURN NULL ; 
		--returN NEW;
	END IF ; --end of insert dealing


	IF TG_OP = 'INSERT' THEN 
		--update/insert case
		NEW.node_geom = ST_Force3D(NEW.node_geom) ;  --safeguard against qgis
		--SELECT f.inserted_node_id , f.inserted_node_geom INTO NEW.node_id, NEW.node_geom
		--FROM topology.rc_InsertNodeSafe(TG_TABLE_SCHEMA::text, NEW.node_id,NEW.node_geom,dont_update_face:= FALSE)   as f ;  
		INSERT INTO bdtopo_topological.node (geom, containing_face) VALUES (NEW.node_geom, 0); 
		RETURN NEW ;  
	END IF ; --end of insert dealing
/* */
	RETURN NEW;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

DROP TRIGGER IF EXISTS  rc_edit_node_topology ON bdtopo_topological.node_editing; 
CREATE  TRIGGER rc_edit_node_topology  INSTEAD OF INSERT OR UPDATE OR DELETE
 ON bdtopo_topological.node_editing
FOR EACH ROW  
EXECUTE PROCEDURE rc_edit_node_topology();  



DROP FUNCTION IF EXISTS topology.rc_DeleteNodeSafe(topology_name text , INOUT deleted_node_id int , INOUT deleted_node_geom geometry  )  ;
CREATE OR REPLACE FUNCTION topology.rc_DeleteNodeSafe(topology_name text , INOUT deleted_node_id int , INOUT deleted_node_geom geometry  )  AS
$BODY$  
	/**
	@brief this function safely delete a node from a topology. 
		DELETE :
		based on the number of edges that are connected to this node
		0 edge	->	Delete Node 			| 
		1 edge	->	Delete Node 			| Delete Edge
		2 edges	->	Delete Node 			| Heal edge
		3+ edges	->	(dummy :RAISE ERROR)
		3+ edges	->	delete edges			| 
	*/ 
	DECLARE     
	_n_edges INT; 
	_edges_have_loop INT; 
	_edge_id int ; 
	_user_is_dummy boolean := false ; 
	BEGIN     	 
		--how much edges are connected to this node?
		SELECT count(*) INTO _n_edges
		FROM (
			SELECT DISTINCT  edge_id 
				FROM bdtopo_topological.edge_data
				WHERE start_node = deleted_node_id OR end_node = deleted_node_id
			) as  sub ; 

		SELECT count(*) INTO _edges_have_loop
		FROM (
			SELECT DISTINCT  edge_id 
				FROM bdtopo_topological.edge_data
				WHERE start_node = deleted_node_id AND end_node = deleted_node_id
			) as  sub ; 
		
		--RAISE EXCEPTION '_n_edges % ,_edges_have_loop %',_n_edges,_edges_have_loop ; 
		--isolated node
		IF _n_edges =0 THEN 
			RAISE NOTICE 'node was isolated, deleting it'  ; 
			DELETE FROM bdtopo_topological.node WHERE node_id = deleted_node_id; 
			RETURN ;
		END IF; 

		IF _n_edges =1 THEN 
			RAISE NOTICE 'node had only one edge, deleting both node and edge'  ; 
			
			PERFORM DISTINCT ON (edge_id) ST_RemEdgeModFace(topology_name, edge_id) 
			FROM bdtopo_topological.edge_data
			WHERE start_node = deleted_node_id OR end_node = deleted_node_id ;
			DELETE FROM bdtopo_topological.node WHERE node_id = deleted_node_id; 
			RETURN ;
		END IF; 
		

		--node with exactly 2 edges, (no loop in edges). We merge the edges
		IF _n_edges =2 AND _edges_have_loop =0 THEN 
			RAISE NOTICE 'node has 2 distinct edge, we merge it'  ; 

			PERFORM ST_ModEdgeHeal(topology_name, edge_ids[1],edge_ids[2])
			FROM (
				SELECT array_agg( edge_id) edge_ids
				FROM bdtopo_topological.edge_data
				WHERE start_node = deleted_node_id OR end_node = deleted_node_id) as sub ;   
			RETURN ;
		END IF; 

		
		--other case, either : 
			-- we raise an error 
			--we delete all edges and delete the node
		IF _user_is_dummy = TRUE THEN 
			IF _edges_have_loop >0 THEN
			RAISE EXCEPTION 'SORRY, you are in dummy mode,
				you cant delete a node where connected edges form loop(s) (here, % loop(s) ), delete connected looping edges first !  ',_edges_have_loop ;
			END IF ; 
			RAISE EXCEPTION 'SORRY, you are in dummy mode,
			you cant delete a node connected to more than 2 edges  (here : %).
			Delete connected edges first  !',_n_edges ;
		END IF ; 
		--delete all connected edges
			--@DEBUG @FIXME @TEMP : here it should be rc_DeleteEdgeSafe that sohould be called ! 
		PERFORM DISTINCT ON (edge_id) ST_RemEdgeModFace(topology_name, edge_id) 
		FROM bdtopo_topological.edge_data
		WHERE start_node = deleted_node_id OR end_node = deleted_node_id ;
		--delete node
		DELETE FROM bdtopo_topological.node WHERE node_id = deleted_node_id; 
		RETURN ;
		
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;


  
DROP FUNCTION IF EXISTS topology.rc_MoveNodeSafe(topology_name text , INOUT moved_node_id int , INOUT moved_node_geom geometry , is_isolated int   )  ;
CREATE OR REPLACE FUNCTION topology.rc_MoveNodeSafe(topology_name text , INOUT moved_node_id int , INOUT moved_node_geom geometry ,is_isolated int DEFAULT -1 )  AS
$BODY$  
	/**
	@brief this function safely move a node within a topology
		if the new position is near an exisitng node (excepting old self)
			fuse the moved node to existing node, transfer edges, update edge_linking and face
		if the new position is near an exisitng edge (excepting self edges)
			split the edge, transfert edges to new split node, update edge_linking and face
			error case : if the edge to split is self edge
		else : simply move the node, update last/first summit of self edges
			error case : if updating produce self-crossing edges, or edges crossing other edges : warn user, rollback 

	*/ 
	DECLARE      
		_topology_precision float := 0 ; 
		_near_node_id INT := -1;
		_near_node_geom geometry;
		_near_edge_id INT := -1;
		_near_edge_geom geometry;
		_crossing_edges INT := -1 ; 
		_is_isolated boolean := FALSE ; 
	BEGIN     	 
		SELECT precision into _topology_precision
		FROM topology.topology
		WHERE name = topology_name  ;   

		--check if new position is near an exisitng node (excluding self)
		SELECT node_id,geom INTO _near_node_id, _near_node_geom
		FROM bdtopo_topological.node
		WHERE ST_DWithin(node.geom, moved_node_geom, _topology_precision) = TRUE
		AND node.node_id <>moved_node_id 
		ORDER BY ST_Distance(node.geom, moved_node_geom) ASC
		LIMIT 1 ; 
		
		-- check if the node is isolated
		SELECT (count(*)  = NULL) INTO _is_isolated
		FROM (
			SELECT 1 
			FROM bdtopo_topological.edge_data 
			WHERE start_node = moved_node_id OR end_node = moved_node_id
		) as sub ; 
		IF is_isolated != -1 THEN _is_isolated = is_isolated ; END IF ;  
		

		
		IF _near_node_id IS NOT NULL OR _near_node_id != -1 THEN -- need to merge moved node to existing, and transfer stuff
			RAISE EXCEPTION 'moving a node (%) close to an existing one (%), fusing the moved node to the existing one, transfering edges, recomputing edge_linking, delete moved node .NOT YET IMPLEMENTED\n'
				,moved_node_id,_near_node_id;

			-- transfer the edge one by one to the existing node
			--recompute edge_linking
			--delete moed node
		ELSE
			--the node is isoltaed, need to update it's containing face 
			UPDATE bdtopo_topological.node 
				SET containing_face = GetFaceByPoint('bdtopo_topological', moved_node_geom , 0.1)  
				WHERE node_id = moved_node_id ; 
			--RAISE EXCEPTION 'moving node, it was and stay isolated, need to update containing_face  ' ; 
		END IF; 

		--check if new position is near an exisitng edge (excluding self edges)
		SELECT edge_id,geom INTO _near_edge_id, _near_edge_geom
		FROM bdtopo_topological.edge_data AS ed
		WHERE ST_DWithin(ed.geom, moved_node_geom, _topology_precision) = TRUE
			--we don't want edge that are directly connected to the moved node
			AND ed.start_node <> moved_node_id AND ed.end_node <> moved_node_id 
		ORDER BY ST_Distance(ed.geom, moved_node_geom) ASC
		LIMIT 1 ;

		IF _near_edge_id IS NOT NULL OR _near_edge_id != -1 THEN 
			-- need to split the near edge, then transfer the moved node to new node from splitting (transfer edge, update  edge geom , recomputing edge_linking )
			RAISE EXCEPTION 'moving a node (%) close to an existing edge (%), splitting the edge, and fusing the moved edeg to node from split, transfering edges,updating edge geom,  recomputing edge_linking, deleting moved node. NOT YET IMPLEMENTED\n '
				,moved_node_id,_near_edge_id;

			-- transfer the edge one by one to the existing node
			--recompute edge_linking
			--delete moed node
		END IF;  

		--simply moving the node, updating edges geom. If new edge geom crosses other edges or generate invalid geom (self crossing), roolback.
		BEGIN
			--move node,change all edge geom, 
			PERFORM street_amp.rc_MoveNonIsoNode(topology_name,moved_node_id, moved_node_geom) ; 
			
			 
			--then check that they don't cross each other or other edges
			WITH self_edges AS (
				SELECT distinct edge_id, geom
				FROM bdtopo_topological.edge_data AS ed
				WHERE ed.start_node = moved_node_id OR ed.end_node = moved_node_id 
			)
			SELECT count(*) INTO _crossing_edges
			FROM bdtopo_topological.edge_data AS ed, self_edges as sed
			WHERE ST_Crosses(sed.geom, ed.geom) 
				AND sed.edge_id <> ed.edge_id ;

			IF  _crossing_edges >0 THEN
				RAISE EXCEPTION 'moving a node (%) conduced to update connected edges geometry. While doing so, one or more updated edge proved to crosses one or more other edges. NOT YET IMPLEMENTED/PERMITTED \n '
				,moved_node_id;
			END IF;  
		END ;

		RETURN  ;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE; 