--------------------------------------------------------------------------
-- Rémi Cura , Thales & IGN , Terra Mobilita Project, 2014 
--
--------------------------------------------------------------------------
-- This script perform cleaning of topology
--------------------------------------------------------------------------



SET search_path TO  bdtopo_topological, topology, public ;
 

DROP FUNCTION IF EXISTS rc_CleanEdge_geom(toponame character varying, IN  iedge_id integer, INOUT igeom GEOMETRY, IN tolerance FLOAT  );
  
CREATE OR REPLACE FUNCTION public.rc_CleanEdge_geom(toponame character varying, IN  iedge_id integer, INOUT igeom GEOMETRY, IN tolerance FLOAT DEFAULT 0.01 )   AS
$BODY$
	--@brief given a precision , for an edge in edge_data (we use the geom that is provided), snap the start/end point to node if it is within the correct distance
DECLARE 
r record; 
q text;
BEGIN

	--getting the end point
	q:= '  SELECT ed.edge_id, ed.start_node, ed.end_node, ed.geom ,
			n1.geom AS start_node_geom, n2.geom AS end_node_geom
			, ST_StartPoint($2) AS start_point, ST_EndPoint($2) AS end_point
			,ST_NPoints($2)-1 AS npoints
		FROM  ' || quote_ident(toponame)||'.edge_data AS ed
			INNER JOIN  ' || quote_ident(toponame)||'.node AS n1 ON (ed.start_node = n1.node_id)
			INNER JOIN  ' || quote_ident(toponame)||'.node AS n2 ON (ed.end_node = n2.node_id)
		WHERE ed.edge_id = $1 ;';

	EXECUTE q INTO r USING iedge_id, igeom; 
	 
	IF ST_DWithin(r.start_point ,r.start_node_geom , tolerance) THEN igeom:= ST_SetPoint(igeom, 0, r.start_node_geom);
	END IF;
	IF ST_DWithin( r.end_point ,r.end_node_geom , tolerance) THEN igeom:= ST_SetPoint(igeom, r.npoints, r.end_node_geom);
	END IF; 
	
	RETURN ; 
END
$BODY$
  LANGUAGE plpgsql VOLATILE ;

 SELECT  rc_CleanEdge_geom('bdtopo_topological', 2541,geom)   
 FROM edge_data 
 WHERE edge_id = 2541

 
--DROP FUNCTION public.rc_CleanEdge(character varying, integer, float);

CREATE OR REPLACE FUNCTION public.rc_CleanEdge(toponame character varying, IN  iedge_id integer, IN tolerance FLOAT DEFAULT 0.01 )  
RETURNS BOOLEAN AS
$BODY$
	--@brief given a precision , for an edge in edge_data, snap the start/end point to node if it is within the correct distance
DECLARE 
r record;
result geometry; 
q text;
BEGIN

	--getting the end point
	q:= '  SELECT ed.edge_id, ed.start_node, ed.end_node, ed.geom ,
			n1.geom AS start_node_geom, n2.geom AS end_node_geom
			, ST_StartPoint(ed.geom) AS start_point, ST_EndPoint(ed.geom) AS end_point
			,ST_NPoints(ed.geom)-1 AS npoints
		FROM  ' || quote_ident(toponame)||'.edge_data AS ed
			INNER JOIN  ' || quote_ident(toponame)||'.node AS n1 ON (ed.start_node = n1.node_id)
			INNER JOIN  ' || quote_ident(toponame)||'.node AS n2 ON (ed.end_node = n2.node_id)
		WHERE ed.edge_id = $1 ;';

	EXECUTE q INTO r USING iedge_id; 
	
	result := r.geom; 
	IF ST_DWithin(r.start_point ,r.start_node_geom , tolerance) THEN result:= ST_SetPoint(result, 0, r.start_node_geom);
	END IF;
	IF ST_DWithin( r.end_point ,r.end_node_geom , tolerance) THEN result:= ST_SetPoint(result, r.npoints, r.end_node_geom);
	END IF;

	if ST_Equals(r.geom, result) = FALSE THEN
	UPDATE edge_data AS ed SET (geom)  =(result)
	WHERE ed.edge_id = iedge_id; 
	RETURN TRUE; 
	END IF; 
	RETURN FALSE; 
END
$BODY$
  LANGUAGE plpgsql VOLATILE ;
-- 
-- SELECT *
-- FROM rc_CleanEdge('bdtopo_topological', 2541);  



-- SELECT rc_CleanEdge('bdtopo_topological',edge_id)
-- FROM edge_data
-- 
-- SELECT ST_AsEwkt(geom)
-- FROm -- edge_data
-- 	 bdtopo.road
-- LIMIT 10
-- 
