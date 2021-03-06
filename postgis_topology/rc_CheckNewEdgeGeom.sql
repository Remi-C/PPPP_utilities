﻿----------------------
-- Remi-C THALES IGN
--02/2015
----------------------
-- postgis topology function
----------------------
-- given a linestring geom, 2 nodes and a precision,  check that it doesn't cross any edge and is not dwithin nodes except those provided


DROP FUNCTION IF EXISTS rc_CheckNewEdgeGeom( text ,  geometry,  int,  int,  int,  float ) ;
CREATE OR REPLACE FUNCTION rc_CheckNewEdgeGeom(topology_name text , edge_geom geometry, edge_id int, start_node_id int, end_node_id int, tolerance float ) returnS VOID AS
$BODY$  
	/**
	@brief given a linestring geom, 2 nodes and a precision,  check that the linestring doesn't cross any edge and is not dwithin nodes except those provided
	*/ 
	DECLARE       
		_first_node record;  
		_second_node record; 
		_e_geom geometry ;
		_e_id int[];
		_edge_id int:= edge_id ;
		_q text ; 
	BEGIN     	  
		-- check that the proposed geometry is simple
		IF ST_IsSImple(edge_geom) = FALSE OR ST_IsValid(edge_geom) = FALSE THEN
			RAISE EXCEPTION 'ERROR : the given edge % is not valid or self intersect (not simple)\n',edge_id ;
		END IF; 
		-- check that new geom doesn't cross any edge (except OLD self)

		_q := format('
		SELECT array_agg(ed.edge_id ORDER BY ed.edge_id ASC) 
		FROM %I.edge_data as ed 
		WHERE ST_Crosses($1,geom) = TRUE
			AND ed.edge_id != $2 ;
		' ,topology_name); 
		EXECUTE _q INTO _e_id  USING  edge_geom, _edge_id;

		if _e_id iS NOT NULL THEN
			RAISE EXCEPTION 'ERROR : the given edge % cross other edges : % ',edge_id, _e_id; 
		END IF; 

		--check that new edge geom is not too close to node 
		_q := format('
		SELECT array_agg(n.node_id ORDER BY n.node_id ASC ) 
		FROM %I.node as n 
		WHERE ST_DWithin($1,n.geom,$4) = TRUE
			AND n.node_id <> $2
			AND n.node_id <> $3;  ',topology_name);  
			EXECUTE _q INTO _e_id USING edge_geom,start_node_id, end_node_id,tolerance ; 
		
		if _e_id iS NOT NULL THEN
			RAISE EXCEPTION 'ERROR : the given edge % is to close to other existing node : % ',edge_id, _e_id; 
		END IF; 
		
		RETURN  ;
	END ;
	$BODY$
LANGUAGE plpgsql VOLATILE; 
/* 
SELECT rc_lib.rc_CheckNewEdgeGeom('bdtopo_topological'::text
	, ST_SetSRID(ST_MakeLine(ST_MakePoint(5983.5,22331.1), ST_MakePoint(6037.9,22309.9)),932011)
	,-1::int
	,-1::int
	,-1::int
	,0.1::float
	) ; 
 */