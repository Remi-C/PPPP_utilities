-----------/----------
--Rémi-C, Thales IGN
-- 02 / 2015
--
-- editing a postgis_topology in qgis
---------------------
-- aim of this project is to support limited edition of a linestring topology in qgis, via triggers on postgis topology 

/**
--scope : only allowed modifications : on edge_data (view) and node (view)

Change on node :
	CREATE :
		_if isolated : create isolated 
		-if along an existing edge : split existing edge, update both new edge
		- else : forbiden
	UPDATE : 
		move : move all adjacent edges last point, if  no crossing
		if crossing : forbiden
	DELETE :
		if isolated ,
		else : forbiden

Change on edge :
	CREATE 
		_ allowed between 2 nodes, non crossing
		else forbiden
	UPDATE 
		change geometry : all except last/first : if not crossing
		chang geometry : last OR first : update topo, 
		change geometry : last and first ! forbiden
	DELETE 
		propagate

Change on edge_data :
	on update or create, check that it is not crossing
	check that both ends are within precision of a node, snap, error if false
	check that edge is unique fo given precision (closest looking edge max distance is > precision)
Change on node : 
	on update / create  : if node dwihtin precision, merge
	if edgedwithin precision, split
	
		
*/

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
	@brief this trigger is designed to allow simple update of node topology via qgis

	allowed interaction are :
		centered on node : create/delete/move node if it preserve topology
	
	Change on node :
	CREATE :
		_if isolated : create isolated 
		-if along an existing edge : split existing edge, update both new edge
		- else : forbiden
	UPDATE : 
		move : move all adjacent edges last point, if  no crossing
		if crossing : forbiden
	DELETE :
		if isolated delete
		if exactly 2 edges, merge 2 edges, delete
		else : forbiden
	*/

	DECLARE     
	BEGIN      

	IF TG_OP = 'DELETE' THEN  
		SELECT f.deleted_node_id , f.deleted_node_geom INTO OLD.node_id, OLD.node_geom
		FROM topology.rc_DeleteNodeSafe(TG_TABLE_SCHEMA::text, OLD.node_id,OLD.node_geom)   as f ; 
		 
		RETURN NULL ; 
		--returN NEW;
	END IF ; --end of delete dealing 

	IF TG_OP = 'INSERT' THEN 
		--update/insert case
		NEW.node_geom = ST_Force3D(NEW.node_geom) ;  --safeguard against qgis
		SELECT f.inserted_node_id , f.inserted_node_geom INTO NEW.node_id, NEW.node_geom
		FROM topology.rc_InsertNodeSafe(TG_TABLE_SCHEMA::text, NEW.node_id,NEW.node_geom)   as f ; 
		 
		RETURN NULL ;  
	END IF ; --end of insert dealing

	
	IF TG_OP = 'UPDATE' THEN 
		--update/insert case
		NEW.node_geom = ST_Force3D(NEW.node_geom) ;  --safeguard against qgis
		SELECT f.moved_node_id , f.moved_node_geom INTO NEW.node_id, NEW.node_geom
		FROM topology.rc_MoveNodeSafe(TG_TABLE_SCHEMA::text, NEW.node_id,NEW.node_geom)   as f ;  
		 
		RETURN NULL ; 
		--returN NEW;
	END IF ; --end of insert dealing

	returN NEW;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

DROP TRIGGER IF EXISTS  rc_edit_node_topology ON bdtopo_topological.node_editing; 
CREATE  TRIGGER rc_edit_node_topology  INSTEAD OF INSERT OR UPDATE OR DELETE
 ON bdtopo_topological.node_editing
FOR EACH ROW  
EXECUTE PROCEDURE rc_edit_node_topology();  

 


DROP FUNCTION IF EXISTS topology.rc_InsertNodeSafe(topology_name text , new_node_id int ,new_geom geometry , IN edge_to_ignore INT ,IN dont_update_face BOOLEAN,  OUT inserted_node_id int, OUT inserted_node_geom geometry)  ;
CREATE OR REPLACE FUNCTION topology.rc_InsertNodeSafe(topology_name text , new_node_id int ,new_geom geometry , IN edge_to_ignore INT default NULL,IN dont_update_face BOOLEAN DEFAULT FALSE, OUT inserted_node_id int, OUT inserted_node_geom geometry)  AS
$BODY$  
	/**
	@brief this function safely add a node to a topology.
		If the node already exist, we return the existing node
		If the node is close to an existing edge, we split the edge (except if we must ignore this edge)
		if the node is isolated, we add it (with correct face)
	*/ 
	DECLARE    
		_topology_precision float := 0 ; 
		_t_node_id int:= -1; 
		_t_node_geom geometry := NULL; 
		_face_id int := -1 ;  
	BEGIN    
		SELECT precision into _topology_precision
		FROM topology.topology
		WHERE name = topology_name  ;   
		
		-- if inserting close to another node, don't insert anything, return the existing node
		SELECT  node_id, geom INTO _t_node_id, _t_node_geom
		FROM bdtopo_topological.node 
			WHERE ST_DWITHIN(node.geom,new_geom,_topology_precision ) 
			ORDER BY  ST_Distance(node.geom,new_geom)
			LIMIT 1; 
		

		IF _t_node_id IS NOT NULL AND _t_node_id <> -1 THEN --we insert close to another existing node, do nothing, return existing node
		
			RAISE NOTICE 'the inserted node is within tolerance (%) of an exisiting node (%)', _topology_precision , _t_node_id ; 
			inserted_node_id := _t_node_id ;
			inserted_node_geom := _t_node_geom ; 
			RETURN  ;
		END IF ;

		--if inserting close to an exisitng edge, split the edge  
		SELECT ed.edge_id INTO _t_node_id 
		FROM bdtopo_topological.edge_data AS ed
		WHERE ST_DWITHIN(ed.geom,new_geom,_topology_precision ) = TRUE
			AND ed.edge_id <> edge_to_ignore  
		ORDER BY  ST_Distance(ed.geom,new_geom) ASC
		LIMIT 1 ; 

		if _t_node_id IS NOT NULL AND _t_node_id <> -1 THEN --inserting close to an existing edge. Splitting the edge, returning the id and geom of node that split
			
			RAISE NOTICE 'the inserted node is within tolerance (%) of an exisiting edge, we split it)', _topology_precision ; 
			SELECT rc_ModEdgeSplit(topology_name, _t_node_id, new_geom)  INTO _t_node_id ;  
			SELECT geom intO _t_node_geom
			FROM bdtopo_topological.node
			WHERE node.node_id = _t_node_id ;

			inserted_node_id := _t_node_id ;
			inserted_node_geom := _t_node_geom ; 
			RETURN ; 
		END IF ;

		-- normal insert, add isolated node :
		IF dont_update_face = TRUE THEN 
			-- find face :
			SELECT  topology.getfacebypoint(topology_name , new_geom,  _topology_precision ) INTO _face_id ; 
		ELSE --we don(t want to update the face 
			_face_id := 0 ;
		END IF;
		-- find next value : 
		IF new_node_id IS NULL OR new_node_id<=0 THEN 
			new_node_id := public.rc_FindNextValue('bdtopo_topological', 'node', 'node_id') ;
		END IF  ;  

		
		INSERT INTO bdtopo_topological.node (node_id, containing_face  , geom) VALUES  (new_node_id, _face_id,new_geom) ;    
		inserted_node_id := new_node_id ;
		inserted_node_geom := new_geom ; 
		returN ;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;
			
DROP FUNCTION IF EXISTS topology.rc_MoveNodeSafe(topology_name text , INOUT moved_node_id int , INOUT moved_node_geom geometry  )  ;
CREATE OR REPLACE FUNCTION topology.rc_MoveNodeSafe(topology_name text , INOUT moved_node_id int , INOUT moved_node_geom geometry  )  AS
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

		IF _near_node_id IS NOT NULL OR _near_node_id != -1 THEN -- need to merge moved node to existing, and transfer stuff
			RAISE EXCEPTION 'moving a node (%) close to an existing one (%), fusing the moved node to the existing one, transfering edges, recomputing edge_linking, delete moved node .NOT YET IMPLEMENTED\n'
				,moved_node_id,_near_node_id;

			-- transfer the edge one by one to the existing node
			--recompute edge_linking
			--delete moed node
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

			
DROP FUNCTION IF EXISTS topology.rc_DeleteNodeSafe(topology_name text , INOUT deleted_node_id int , INOUT deleted_node_geom geometry  )  ;
CREATE OR REPLACE FUNCTION topology.rc_DeleteNodeSafe(topology_name text , INOUT deleted_node_id int , INOUT deleted_node_geom geometry  )  AS
$BODY$  
	/**
	@brief this function safely delete a node from a topology. 
		If the node is isolated, simply remove it
		if the node is shared by exactly 2 edges, modHeal the edges
		if the node is shared by one or more than 2 edges, delete the edges, delete the node. 
	*/ 
	DECLARE     
	_n_edges INT; 
	_edges_have_loop INT; 
	_edge_id int ; 
	BEGIN     	 
		--how much edges has this node?
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

		--other case, we delete all edges and delete the node
		--delete edges
		PERFORM DISTINCT ON (edge_id) ST_RemEdgeModFace(topology_name, edge_id) 
		FROM bdtopo_topological.edge_data
		WHERE start_node = deleted_node_id OR end_node = deleted_node_id ;
		--delete node
		DELETE FROM bdtopo_topological.node WHERE node_id = deleted_node_id; 
		RETURN ;
		
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;


--creating trigger for edition of node
DROP FUNCTION IF EXISTS street_amp.rc_node_manage_identical(topology_name text , new_node_id int ,new_geom geometry(point), OUT update_topology int)  ;
CREATE OR REPLACE FUNCTION street_amp.rc_node_manage_identical(topology_name text , new_node_id int ,new_geom geometry(point), OUT update_topology int)  AS
$BODY$  
	/**
	@brief this function is executed given a new/changed node in topology. It checks that no identical node exist, and deal with consequences

	if an existing node is clos eenough (topology precision)
		* merge both nodes
		else do nothing
	*/

	DECLARE    
		_topology_precision float := 0 ;  
		
	BEGIN   
		SELECT precision into _topology_precision
		FROM topology.topology
		WHERE name = topology_name  ; 
		update_topology := -1 ; 

		SELECT node_id  INTO update_topology
		FROM 
			(SELECT  DISTINCT ON (new_node_id) street_amp.rc_merge_nodes(topology_name, new_node_id,node_id), node_id
			FROM bdtopo_topological.node 
			WHERE ST_DWITHIN(node.geom,new_geom,_topology_precision )
			AND node.node_id <> new_node_id
			ORDER BY  new_node_id ,  ST_Distance(node.geom,new_geom)) as sub; 
	
		
		returN ;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;



--creating trigger for edition of node
DROP FUNCTION IF EXISTS street_amp.rc_node_manage_edge_near(topology_name text , new_node_id int ,new_geom geometry(point), OUT update_topology int) ; 
CREATE OR REPLACE FUNCTION street_amp.rc_node_manage_edge_near(topology_name text , new_node_id int ,new_geom geometry(point), OUT update_topology int)  AS
$BODY$  
	/**
	@brief this function is executed given a new/changed node in topology. It checks that the new position of node is not too close to an edge (excepting start/end)
	if it is close to middle of an edge, snap.
	It cannot be close to an edge end because it would be close to another edge, which has already been checked.

	find closest edge
		if below tolerance, split
	*/

	DECLARE    
		_topology_precision float := 0 ;  
		_new_node_id int :=0 ; 
		_temp_ei int:=0 ;  
		_x float;
		_y float ; 
	BEGIN   
		SELECT precision into _topology_precision
		FROM topology.topology
		WHERE name = topology_name  ; 
		update_topology := -1 ; 
		
		--find the closest edge, split it if it is too close
		/** @DEBUG @ERROR */
		SELECT DISTINCT ON (new_node_id)  
			rc_ModEdgeSplit(topology_name, ed.edge_id, ST_Force3D(ST_ClosestPoint(ed.geom,new_geom)))  
			INTO update_topology
		FROM bdtopo_topological.edge_data AS ed
		WHERE ST_DWITHIN(ed.geom,new_geom,_topology_precision ) = TRUE
		ORDER BY  new_node_id ,  ST_Distance(ed.geom,new_geom) ASC; 
		
		returN;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

  

DROP FUNCTION IF EXISTS street_amp.rc_merge_nodes(topology_name text, node_id_1 int, node_id_2 int); 
CREATE OR REPLACE FUNCTION street_amp.rc_merge_nodes(topology_name text, node_id_1 int, node_id_2 int)
returns int AS 
$BODY$  
	/**
	@brief this function merges two nodes of a topology.
	that means that all edges of node_1 are transfered to node_2, and that geom is chnaged accordingly,
	then node_1 is deleted.
	*/

	DECLARE    
		_new_node_id int :=0 ; 
	BEGIN
		--RAISE EXCEPTION 'mergiinf node % and %' , node_id_1, node_id_2  ; 
		IF node_id_1 = node_id_2 THEN
			RAISE EXCEPTION 'you can t merge a node with the same node ! ' ; 
			RETURN FALSE;
		END IF ;
		IF node_id_1 IS NULL OR  node_id_2 IS NULL THEN
			RAISE EXCEPTION 'one of the node to merge is null :node_id_1:%, node_id_2:% ', node_id_1, node_id_2 ; 
			RETURN FALSE;
		END IF ;
		--connect edge of node_1 to node_2
		UPDATE bdtopo_topological.edge_data  set start_node = node_id_2
		WHERE start_node = node_id_1 ; 
		UPDATE bdtopo_topological.edge_data  set end_node = node_id_2
		WHERE end_node = node_id_1 ; 

		--update edges geometry so they go to node_id_2
		PERFORM street_amp.rc_MoveNonIsoNode_edges(topology_name, node_id_2, geom)
		FROM bdtopo_topological.node 
		WHERE node_id = node_id_2; 

		DELETE FROM bdtopo_topological.node 
		WHERE node_id  = node_id_1 ;
		RETURN node_id_2 ;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;
 