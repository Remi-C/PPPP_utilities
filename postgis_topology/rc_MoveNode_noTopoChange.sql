-------------------------------
-- Remi-C , Thales IGN, 2014
-- 
--this function moves a node in a topo schema (along with edges connected to this node)
-- providing that this move won't change the topology
------------------------------




  
DROP FUNCTION IF EXISTS topology.rc_MoveNode_noTopoChange(varchar, int, geometry,   edge_ids int[] ); 
CREATE OR REPLACE FUNCTION topology.rc_MoveNode_noTopoChange( IN atopology  varchar ,INOUT node_id INT , IN new_node_geom geometry 
,  edge_ids int[] DEFAULT NULL)AS
$BODY$
		--@brief this function moves a node and update all connected edges geometry accordingly.
		-- WARNING : the node change shouldn't change topology
		DECLARE 
			_topology_precision float := 0 ; 
			_face_id int := NULL;  
			_nb_connected_edges int := 0 ; 
		BEGIN 
			SELECT precision into _topology_precision
			FROM topology.topology
			WHERE name = atopology  ;   

			--is this node isolated? 
			SELECT count(*) INTO _nb_connected_edges FROM (SELECT 1 FROM GetNodeEdges(atopology, node_id) ) AS sub ;

			IF _nb_connected_edges = 0 THEN
				--the node is isolated, find the new containing face
				_face_id :=  topology.getfacebypoint(atopology , new_node_geom,  _topology_precision )  ; 
				_face_id := COALESCE(_face_id, 0); 
			ELSE 
				_face_id := NULL ;
			END IF ; 
			
			--moving the node
			EXECUTE format('UPDATE %I.node AS n SET (containing_face,geom) = ($2,$3) WHERE n.node_id = $1 ',atopology) USING node_id, _face_id, new_node_geom ; 
			
			--updating the edges 
			PERFORM topology.rc_MoveNonIsoNode_edges(atopology, node_id, new_node_geom,edge_ids, _topology_precision) ; 
			return; 
		END ;
	$BODY$
LANGUAGE plpgsql VOLATILE;
--SELECT rc_MoveNonIsoNode()

--SELECT rc_MoveNonIsoNode_edges('bdtopo_topological',12646, ST_SetSRID(ST_MakePoint(1452.36,25334.02,0),932011));




  
DROP FUNCTION IF EXISTS topology.rc_MoveNonIsoNode_edges(varchar, int, geometry(point) , edge_ids int[],  float); 
CREATE OR REPLACE FUNCTION topology.rc_MoveNonIsoNode_edges( IN atopology  varchar 
	,INOUT node_id INT , IN new_node_geom geometry(point),edge_ids int[] DEFAULT NULL, topology_precision FLOAT default 0.0
	)
  RETURNS int AS
$BODY$
		--@brief this function udpate all the edges of a node we want to move . Such node move must not change topology !
		--@WARNING: there is no check about new edge geom, or preservation of correct topology.
		DECLARE  
			_is_invalid_change boolean := FALSE ; 
			_q text ; 
		BEGIN  
			--update the outgoing edges by setting the first point of their geom
			--check in the same time that proposed update doesn't break topology by cnaging edge_geom
			 _q :=  
				'
				WITH the_update AS ( 
					UPDATE %1$I.edge_data AS ed 
						SET geom = CASE 
							WHEN ed.start_node = %4$s  
							THEN ST_SetPoint(ed.geom, 0 , %3$L) 
							ELSE  ST_SetPoint(ed.geom, ST_Npoints(ed.geom)-1 , %3$L) END 
						WHERE ' ; 
						IF edge_ids IS NULL THEN 
							_q := _q ||' ed.start_node = %4$s OR ed.end_node = %4$s' ;
						ELSE _q := _q ||' ed.edge_id = ANY (''%5$s''::int[]) ' ;
						END IF ; 
						_q := _q ||
						'RETURNING edge_id, geom  
				)
				,checking_crossing_within_new_edges AS(
					SELECT 1
					FROM the_update AS u1, the_update AS u2 WHERE u1.edge_id < u2.edge_id 
						AND ST_Crosses(u1.geom, u2.geom) 
							--safeguard against geos precision issues
							AND  (ST_Area( ST_Intersection(ST_Buffer(u1.geom,%2$s),ST_Buffer(u2.geom,%2$s)))
								> 3* 3.14*  %2$s  *  %2$s   OR %2$s <= 0 )
				)
				, new_are_crossing AS (
					SELECT count(*) != 0 AS are_some_edge_crossing_new
					FROM checking_crossing_within_new_edges
				)
				, are_new_edge_invalid AS (
					SELECT count(*) !=0 as are_the_new_edge_invalid
					FROM the_update
					WHERE ST_IsValid(geom) = False OR ST_IsSimple(geom) = False
				)
				, checking_crossing_with_other_edges AS( -- we have to remove the updated edge from the checking
					SELECT 1
					FROM the_update AS u1, %1$I.edge_data u2  
					WHERE u1.edge_id != u2.edge_id 
						AND ST_Crosses(u1.geom, u2.geom) 
						AND NOT EXISTS (SELECT 1 FROM the_update as u3 WHERE u3.edge_id = u2.edge_id)
				)
				, old_are_crossing AS (
					SELECT count(*) != 0 AS are_some_edge_crossing_others
					FROM checking_crossing_with_other_edges
				)
				SELECT are_some_edge_crossing_new OR are_the_new_edge_invalid OR are_some_edge_crossing_others
				FROM new_are_crossing, are_new_edge_invalid,old_are_crossing ;
				' ;
				_q := format(_q
				,atopology, topology_precision,new_node_geom, node_id, edge_ids ) ; 
				--raise EXCEPTION'%',_q ;

				EXECUTE _q INTO _is_invalid_change   ;
				
			--update the incoming edge by setting the last point of their geom 

			IF _is_invalid_change = TRUE THEN
				RAISE EXCEPTION 'ERROR : you tried to move a node, which resulted in edges having a bad geometry (invalid or crossing each other or crossing other edge)';
			END IF ; 
			return; 
		END ;
	$BODY$
LANGUAGE plpgsql VOLATILE;
--SELECT rc_MoveNonIsoNode()

--SELECT rc_MoveNonIsoNode_edges('bdtopo_topological',12646, ST_SetSRID(ST_MakePoint(1452.36,25334.02,0),932011));



  

