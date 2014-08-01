﻿-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--this function allow to move a node ina topo schema without otpology change (ie, update of edge geometry) 
------------------------------


  
DROP FUNCTION IF EXISTS rc_MoveNonIsoNode_edges(varchar, int, geometry(point)); 
CREATE OR REPLACE FUNCTION rc_MoveNonIsoNode_edges( IN _atopology  varchar ,INOUT _node_id INT , IN _new_node_geom geometry(point)
	)
  RETURNS int AS
$BODY$
		--@brief this function udpate all the edges of a node we want to move . Such node move must not change topology !
		--@WARNING: there is no check about new edge geom, or preservation of correct topology.
		DECLARE 
		BEGIN 
			--update the outgoing edges by setting the first point of their geom
			EXECUTE format('UPDATE %s.edge_data AS ed SET geom = ST_SetPoint(ed.geom, 0 , $1) WHERE ed.start_node = $2 ',_atopology) USING _new_node_geom, _node_id ; 
			--update the incoming edge by setting the last point of their geom
			EXECUTE format('UPDATE %I.edge_data AS ed SET geom = ST_SetPoint(ed.geom, ST_Npoints(ed.geom)-1 , $1) WHERE ed.end_node = $2 ',_atopology) USING _new_node_geom, _node_id ;
			return; 
		END ;
	$BODY$
LANGUAGE plpgsql VOLATILE;
--SELECT rc_MoveNonIsoNode()

--SELECT rc_MoveNonIsoNode_edges('bdtopo_topological',12646, ST_SetSRID(ST_MakePoint(1452.36,25334.02,0),932011));



  
DROP FUNCTION IF EXISTS rc_MoveNonIsoNode(varchar, int, geometry(point)); 
CREATE OR REPLACE FUNCTION rc_MoveNonIsoNode( IN _atopology  varchar ,INOUT _node_id INT , IN _new_node_geom geometry(point)
	)
  RETURNS int AS
$BODY$
		--@brief this function move a node and udpate all the edges of this node accordingly. Such node move must not change topology !
		--@WARNING: there is no check about new edge geom, or preservation of correct topology.
		DECLARE 
		BEGIN 
			--moving the node
			EXECUTE format('UPDATE %s.node AS n SET geom = $1 WHERE n.node_id = $2 ',_atopology) USING _new_node_geom, _node_id ; 
			
			--updating the edges 
			PERFORM rc_MoveNonIsoNode_edges(_atopology, _node_id, _new_node_geom) ; 
			return; 
		END ;
	$BODY$
LANGUAGE plpgsql VOLATILE;
--SELECT rc_MoveNonIsoNode('bdtopo_topological',12646, ST_SetSRID(ST_MakePoint(1451.75,25332.82,0),932011));
