-------------------------------
-- Remi-C , Thales IGN, 2014
-- 
--this function tells if a node is isolated or not
-- note : it doesn't use containg_face for that, but directly goes looking into edge_data table
------------------------------

  
DROP FUNCTION IF EXISTS topology.rc_IsNodeIsolated(varchar, int ); 
CREATE OR REPLACE FUNCTION topology.rc_IsNodeIsolated( IN atopology  varchar ,IN node_id  INT ,OUT is_isolated boolean)AS
$BODY$
		--@brief this function looks into edge_data to find if a node is isolated (no edge connected to it)
		DECLARE  
		BEGIN 
			EXECUTE format(
			'SELECT NOT(count(*)>0)::boolean
			FROM %1$I.edge_data AS ed
			WHERE ed.start_node = $1 OR ed.end_node = $1
			', atopology) INTO is_isolated USING node_id  ;
			
			RETURN; 
		END ;
	$BODY$
LANGUAGE plpgsql VOLATILE;


SELECT * FROM topology.rc_IsNodeIsolated('bdtopo_topological',2113) ;


