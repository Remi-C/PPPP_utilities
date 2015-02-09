---------------------
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
		
*/

--creating view for edition

DROP VIEW IF EXISTS bdtopo_topological.node_editing CASCADE; 
CREATE VIEW  bdtopo_topological.node_editing  AS (
	SELECT node_id, geom as node_geom
	FROM bdtopo_topological.node
); 

DROP VIEW IF EXISTS bdtopo_topological.edge_editing CASCADE; 
CREATE VIEW  bdtopo_topological.edge_editing  AS (
	SELECT edge_id, geom as edge_geom
	FROM bdtopo_topological.edge_data
); 


--creating trigger for edition of node
CREATE OR REPLACE FUNCTION rc_edit_node_topology(  )
  RETURNS  trigger  AS
$BODY$  
	/**
	@brief this trigger is designed to allow simple update of node topology via qgis
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
	_containing_face int:=0 ; 
	_number_of_neighbour int:=0 ; 
	_result int; 
	BEGIN   

	IF TG_OP = 'DELETE' THEN
		SELECT containing_face into _containing_face
		FROM bdtopo_topological.node
		WHERE node_id = OLD.node_id ;

		IF _containing_face =0 THEN 
			--nod eis isolated, simply delete it
			PERFORM ST_RemoveIsoNode('bdtopo_topological', OLD.node_id) ; 
			return OLD ; 
		END IF ; 

		SELECT count(*) into _number_of_neighbour --counting how much edge are linked to this node
		FROM bdtopo_topological.edge_data 
		WHERE start_node = OLD.node_id OR end_node = OLD.node_id ; 

		IF _number_of_neighbour != 2 THEN --we can't delete a node that is linked to ![2, 0] edges
			RAISE EXCEPTION 'deleting a node not used by 0 or 2 edges is forbiden. Either add edge or move/remove some'; 
			RETURN NULL ; --not executed
		END IF ; 

		--case when there is exactly 2 neighbours, we delete the node and merge the edges
		WITH edge_ids AS (
			SELECT array_agg(edge_id ORDER BY (start_node = OLD.node_id), edge_id ASC) as edge_ids
			FROM bdtopo_topological.edge_data 
			WHERE start_node = OLD.node_id OR end_node = OLD.node_id 
		)
		SELECT ST_ModEdgeHeal('bdtopo_topological',edge_ids[1],edge_ids[2]) into _result
		FROM edge_ids ;

		RETURN OLD; 
	END IF ; 
	returN NEW;
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

DROP TRIGGER IF EXISTS  rc_edit_node_topology ON bdtopo_topological.node_editing; 
CREATE  TRIGGER rc_update_result_on_road_attribute_change  INSTEAD OF INSERT OR UPDATE OR DELETE
 ON bdtopo_topological.node_editing
 FOR EACH ROW  
    EXECUTE PROCEDURE rc_edit_node_topology();  