---------------------
--Rémi-C, Thales IGN
-- 05 / 2015
--
-- editing a postgis_topology with a non-topological editor
---------------------
-- aim of this project is to support the edition of baseis of a topology layer with non-topological GIS
-- aim of this project is to support edition of a linestring topology in qgis, via triggers on postgis topology 


/*
--creating view for edition 
DROP VIEW IF EXISTS bdtopo_topological.edge_editing CASCADE; 
CREATE VIEW  bdtopo_topological.edge_editing  AS (
	SELECT edge_id, ST_Force2D(geom) as edge_geom
	FROM bdtopo_topological.edge_data
); 

SELECT *
FROM bdtopo_topological.edge_editing ;

*/

--INSERT INTO bdtopo_topological.edge_editing (edge_geom ) VALUES (ST_GeometryFromText('LINESTRING(1451.8 21353.4 , 1447.6 21253.7)',932011)) ; 
--creating trigger for edition of edge
DROP FUNCTION IF EXISTS rc_edit_edge_topology(  ); 
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
		SELECT f.deleted_edge_id , f.deleted_edge_geom INTO OLD.edge_id, OLD.edge_geom
		FROM topology.rc_DeleteEdgeSafe(TG_TABLE_SCHEMA::text,OLD.edge_id,OLD.edge_geom)   as f ; 
		 
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
		NEW.edge_geom = ST_Force3D(NEW.edge_geom) ;  --safeguard against qgis
		SELECT f.moved_edge_id , f.moved_edge_geom INTO NEW.edge_id, NEW.edge_geom
		FROM topology.rc_MoveEdgeSafe(TG_TABLE_SCHEMA::text, OLD.edge_id,NEW.edge_geom)   as f ;  
		 
		RETURN NULL ; 
		--returN NEW;
	END IF ; --end of insert dealing

	returN NULL; 
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

  
  /*
DROP TRIGGER IF EXISTS  rc_edit_edge_topology ON bdtopo_topological.edge_editing; 
CREATE  TRIGGER rc_edit_edge_topology  INSTEAD OF INSERT OR UPDATE OR DELETE
 ON bdtopo_topological.edge_editing
FOR EACH ROW  
EXECUTE PROCEDURE rc_edit_edge_topology();  
*/
