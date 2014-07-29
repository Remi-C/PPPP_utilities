
WITH the_geom AS (
	SELECT st_geomfromtext('linestring(0 0, 1 1, 2 2 , 3 3 )') AS line
	,st_geomfromtext('point(3 3 )') as pt
)
SELECT ST_ASText(ST_MakeLine(ST_Removepoint(line,3),pt))
FROM the_geomv


SELECT ST_AsText(geom)
FROM bdtopo_topological.node 



DROP FUNCTION IF EXISTS rc_MoveNonIsoNode(varchar, int, geometry(point)); 
CREATE OR REPLACE FUNCTION rc_MoveNonIsoNode( IN _atopology  varchar ,INOUT _node_id INT , IN _new_node_geom geometry(point)
	)
  RETURNS int AS
$BODY$
		--@brief this function move a node and udpate all the edges of this node accordingly. Such node move must not change topology !
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

SELECT rc_MoveNonIsoNode('bdtopo_topological',12646, ST_SetSRID(ST_MakePoint(1452.36,25334.02,0),932011));
 