-----------/----------
--Rémi-C, Thales IGN
-- 02 / 2015
--
-- editing a postgis_topology in qgis
---------------------
-- aim of this project is to support limited edition of a linestring topology in qgis, via triggers on postgis topology 

/**
--scope : only allowed modifications : on edge_data (view) and node (view) 
*/

--creating view for edition 
DROP VIEW IF EXISTS bdtopo_topological.edge_editing CASCADE; 
CREATE VIEW  bdtopo_topological.edge_editing  AS (
	SELECT edge_id, ST_Force2D(geom) as edge_geom
	FROM bdtopo_topological.edge_data
); 

SELECT *
FROM bdtopo_topological.edge_editing ;

--INSERT INTO bdtopo_topological.edge_editing (edge_geom ) VALUES (ST_GeometryFromText('LINESTRING(1451.8 21353.4 , 1447.6 21253.7)',932011)) ; 
--creating trigger for edition of edge
CREATE OR REPLACE FUNCTION rc_edit_edge_topology(  )
  RETURNS  trigger  AS
$BODY$  
	/**
	@brief this trigger is designed to allow simple update of edge topology via qgis 
	allowed interaction are :
		delete edges : simply delete the edge, don't delete node (std)
		create edge : create node if necessary, then create edge between 2 nodes (std)
		update edge : (most complicated) 
			create node if necessary, update edge, check that proposed update is valid (no crossing).   
	*/ 
	DECLARE     
	BEGIN  
	IF TG_OP = 'DELETE' THEN  
		SELECT f.deleted_edge_id , f.deleted_edge_geom INTO NEW.edge_id, NEW.edge_geom
		FROM topology.rc_DeleteEdgeSafe(TG_TABLE_SCHEMA::text,NEW.edge_id,NEW.edge_geom)   as f ; 
		 
		RETURN NULL ; 
		--returN NEW;
	END IF ; --end of delete dealing 

	IF TG_OP = 'INSERT' THEN 
		--update/insert case
		NEW.edge_geom = ST_Force3D(NEW.edge_geom) ;  --safeguard against qgis
		
		SELECT f.inserted_edge_id , f.inserted_edge_geom INTO NEW.edge_id, NEW.edge_geom
		FROM topology.rc_InsertEdgeSafe(TG_TABLE_SCHEMA::text, NEW.edge_id,NEW.edge_geom)   as f ; 
		 
		RETURN NULL ;  
	END IF ; --end of insert dealing

	
	IF TG_OP = 'UPDATE' THEN 
		--update/insert case
		NEW.node_geom = ST_Force3D(NEW.node_geom) ;  --safeguard against qgis
		SELECT f.moved_node_id , f.moved_node_geom INTO NEW.node_id, NEW.node_geom
		FROM topology.rc_MoveEdgeSafe(TG_TABLE_SCHEMA::text, NEW.node_id,NEW.node_geom)   as f ;  
		 
		RETURN NULL ; 
		--returN NEW;
	END IF ; --end of insert dealing

	returN NULL; 
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

DROP TRIGGER IF EXISTS  rc_edit_edge_topology ON bdtopo_topological.edge_editing; 
CREATE  TRIGGER rc_edit_edge_topology  INSTEAD OF INSERT OR UPDATE OR DELETE
 ON bdtopo_topological.edge_editing
FOR EACH ROW  
EXECUTE PROCEDURE rc_edit_edge_topology();  

 


DROP FUNCTION IF EXISTS topology.rc_InsertEdgeSafe(topology_name text , new_edge_id int ,new_geom geometry , OUT inserted_edge_id int, OUT inserted_edge_geom geometry)  ;
CREATE OR REPLACE FUNCTION topology.rc_InsertEdgeSafe(topology_name text , new_edge_id int ,new_geom geometry , OUT inserted_edge_id int, OUT inserted_edge_geom geometry)  AS
$BODY$  
	/**
	@brief this function safely add a edge to a topology.
		--for each end, safely insert a node (take care of near node and near edge)
		-- create an edge between 
		 
	*/ 
	DECLARE    
		_topology_precision float := 0 ; 
		_first_node record;  
		_second_node record;
		_second_node_geom geometry; 
		_e_geom geometry ;
	BEGIN    
		SELECT precision into _topology_precision
		FROM topology.topology
		WHERE name = topology_name  ;   

		--find a sequence number of node
		--inserting the first node if necessary
		SELECT inserted_node_id as node_id, inserted_node_geom as geom INTO _first_node
		FROM topology.rc_InsertNodeSafe(topology_name
			,  rc_FindNextValue(topology_name, 'node', 'node_id')   
			, ST_StartPoint(new_geom)); 

		--inserting the second node if necessary
		SELECT inserted_node_id as node_id, inserted_node_geom as geom INTO _second_node
		FROM topology.rc_InsertNodeSafe(topology_name
			,  rc_FindNextValue(topology_name, 'node', 'node_id')   
			, ST_EndPoint(new_geom)); 

		--updating the edge geom, so it correctly begins and end on added node
		_e_geom := rc_SetPoint(rc_SetPoint(new_geom,0, _first_node.geom),-1, _second_node.geom) ;
		
		--creating the edge between both nodes
		SELECT ST_AddEdgeModFace(topology_name , _first_node.node_id, _second_node.node_id, _e_geom) INTO inserted_edge_id; 
		inserted_edge_geom := _e_geom; 

		RETURN ;  
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;
			
DROP FUNCTION IF EXISTS topology.rc_MoveEdgeSafe(topology_name text , INOUT moved_node_id int , INOUT moved_node_geom geometry  )  ;
CREATE OR REPLACE FUNCTION topology.rc_MoveEdgeSafe(topology_name text , INOUT moved_node_id int , INOUT moved_node_geom geometry  )  AS
$BODY$  
	/**
	@brief this function safely move a edge within a topology 
	*/ 
	DECLARE      
		_topology_precision float := 0 ;  
	BEGIN     	 
		SELECT precision into _topology_precision
		FROM topology.topology
		WHERE name = topology_name  ;    

		RETURN  ;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE; 

			
DROP FUNCTION IF EXISTS topology.rc_DeleteEdgeSafe(topology_name text , INOUT deleted_node_id int , INOUT deleted_node_geom geometry  )  ;
CREATE OR REPLACE FUNCTION topology.rc_DeleteEdgeSafe(topology_name text , INOUT deleted_node_id int , INOUT deleted_node_geom geometry  )  AS
$BODY$  
	/**
	@brief this function safely delete an edge from a topology. 
	it is actually jsut a wrapper around already safe ST_RemEdgeModFace
	NOTE : it could be changeed to delete isolated node when deleting edge
	*/ 
	DECLARE  
	BEGIN     	  
		SELECT ST_RemEdgeModFace(topology_name,deleted_node_id)  INTO deleted_node_id ; 
		return ; 
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;
