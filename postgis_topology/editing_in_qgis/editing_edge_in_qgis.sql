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
 

DROP VIEW IF EXISTS bdtopo_topological.edge_editing CASCADE; 
CREATE VIEW  bdtopo_topological.edge_editing  AS (
	SELECT edge_id, geom as edge_geom
	FROM bdtopo_topological.edge_data
); 


--creating trigger for edition of node
CREATE OR REPLACE FUNCTION rc_edit_edge_topology(  )
  RETURNS  trigger  AS
$BODY$  
	/**
	@brief this trigger is designed to allow simple update of edge topology via qgis

	allowed interaction are :
		delete edges : simply delete the edge
		create edge : create node if necessary, then create edge
		update edge : create node if necessary, update edge, check that proposed update is valid (no crossing).  
	 
	*/

	DECLARE     
	BEGIN      

	IF TG_OP = 'DELETE' THEN  
		SELECT f.deleted_node_id , f.deleted_node_geom INTO OLD.node_id, OLD.node_geom
		FROM topology.rc_DeleteEdgeSafe(TG_TABLE_SCHEMA::text, OLD.node_id,OLD.node_geom)   as f ; 
		 
		RETURN NULL ; 
		--returN NEW;
	END IF ; --end of delete dealing 

	IF TG_OP = 'INSERT' THEN 
		--update/insert case
		NEW.node_geom = ST_Force3D(NEW.node_geom) ;  --safeguard against qgis
		SELECT f.inserted_node_id , f.inserted_node_geom INTO NEW.node_id, NEW.node_geom
		FROM topology.rc_InsertEdgeSafe(TG_TABLE_SCHEMA::text, NEW.node_id,NEW.node_geom)   as f ; 
		 
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

	returN NEW;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

DROP TRIGGER IF EXISTS  rc_edit_edge_topology ON bdtopo_topological.edge_editing; 
CREATE  TRIGGER rc_edit_edge_topology  INSTEAD OF INSERT OR UPDATE OR DELETE
 ON bdtopo_topological.edge_editing
FOR EACH ROW  
EXECUTE PROCEDURE rc_edit_edge_topology();  

 


DROP FUNCTION IF EXISTS topology.rc_InsertEdgeSafe(topology_name text , new_node_id int ,new_geom geometry , OUT inserted_node_id int, OUT inserted_node_geom geometry)  ;
CREATE OR REPLACE FUNCTION topology.rc_InsertEdgeSafe(topology_name text , new_node_id int ,new_geom geometry , OUT inserted_node_id int, OUT inserted_node_geom geometry)  AS
$BODY$  
	/**
	@brief this function safely add a edge to a topology.
		 
	*/ 
	DECLARE    
		_topology_precision float := 0 ;  
	BEGIN    
		SELECT precision into _topology_precision
		FROM topology.topology
		WHERE name = topology_name  ;   
	 
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
	*/ 
	DECLARE  
	BEGIN     	 
		return ; 
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;
