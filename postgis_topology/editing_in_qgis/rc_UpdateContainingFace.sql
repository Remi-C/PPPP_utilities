-----------/----------
--Rémi-C, Thales IGN
-- 02 / 2015
--
-- editing a postgis_topology in qgis
---------------------
--this function update the containing face of a node



DROP FUNCTION IF EXISTS topology.rc_UpdateContainingFace(topology_name text , node_id int, node_geom  geometry, is_isolated int  ,  INOUT containing_face int  )  ;
CREATE OR REPLACE FUNCTION topology.rc_UpdateContainingFace(topology_name text ,node_id int, node_geom geometry, is_isolated int DEFAULT -1,  INOUT containing_face int DEFAULT NULL) 
  AS
$BODY$  
	/**
	@brief this function  update the containing face of a node
		- if the containing_face is given, put the given containing face
		- if the node is not isolated (is_isolated >0 or can't find an edge linking to this node) , put null
		- else, find the proper face
		 
	*/ 
	DECLARE    
	_cface int := NULL; 
	BEGIN    
		IF containing_face IS NOT NULL THEN
			--containing face is given
			_cface := containing_face;
		ELSIF is_isolated >0 OR topology.GetNodeEdges(topology_name, node_id) IS NOT NULL  THEN 
			-- node is not isolated
			_cface := NULL ; 
		ELSE
			--node is isolated, find the face 
			_cface := topology.getfacebypoint(topology_name , node_geom,  0 ) ;
		END IF ;

		containing_face := _cface ;  
		--updating 
		UPDATE bdtopo_topological.node  AS n SET containing_face = _cface WHERE n.node_id = node_id ; 
		
		return ; 
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

  