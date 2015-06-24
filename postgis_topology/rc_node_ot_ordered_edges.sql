-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
-- a new function for topology that retunrs all the incoming/outcomming edge of a node in a clockwise order
--also new test on using the search path to avoid creating querry as text.
------------------------------

DROP FUNCTION IF EXISTS rc_node_to_ordered_edges(atopology character varying , input_node_id int  );
CREATE OR REPLACE FUNCTION rc_node_to_ordered_edges( atopology character varying, input_node_id int ) 
		 RETURNS TABLE ( ordinality int,   signed_edge_id int)
 AS 
	$BODY$
 
		--@brief this function takes a node id and returns all the edge coming/getting out of this node, in the clockwise order
		--@param the name of the schema where are the topology table like node and edge_data.
		--@param the id of the node in the topology 
		--@returns : signed edge id along with the order
		DECLARE
		_old_search_path text;
		BEGIN 
			--saving the search path :
			EXECUTE 'SHOW search_path' INTO _old_search_path;
			 
			--setting the search path to a new value to avoid prefixing all table name
			EXECUTE 'SET search_path TO ' || atopology|| ' , topology,public; ';

			 
			--too painfull to develop !
			--get all edge id corresponding to this node, along with next/previous edge and direction

			 
			RETURN QUERY WITH RECURSIVE edgering AS ( 
					SELECT  *
					FROM (
						SELECT *
						FROM (
							SELECT DISTINCT 1*ed.edge_id AS _signed_edge_id ,  edge_id, next_left_edge, next_right_edge 
							FROM edge_data AS ed
							WHERE ed.start_node =  input_node_id
							UNION ALL
							SELECT DISTINCT -1*ed.edge_id AS _signed_edge_id, edge_id, next_left_edge, next_right_edge 
							FROM edge_data AS ed
							WHERE ed.end_node  =  input_node_id 
							) as sub_sub 
							ORDER BY edge_id ASC
							LIMIT 1
						) AS sub 
					UNION 
					SELECT 
						CASE WHEN p._signed_edge_id > 0 
							THEN p.next_right_edge 
							 ELSE p.next_left_edge END
						, e.edge_id, e.next_left_edge, e.next_right_edge 
						 FROM  edge_data e, edgering p 
						 WHERE e.edge_id =  
							CASE WHEN p._signed_edge_id > 0 
								THEN abs(p.next_right_edge) 
								ELSE abs(p.next_left_edge) 
							END ) 
				SELECT (row_number() over())::int  AS ordinality , _signed_edge_id::int  AS signed_edge_id
				FROM edgering;

		 
			--reseting the serach path to original value
			EXECUTE 'SET search_path TO ' || _old_search_path  ; 
			return ;
		END ; 
		$BODY$
  LANGUAGE plpgsql VOLATILE;

 -- SELECT *
 -- FROM rc_node_to_ordered_edges('bdtopo_topological', 11000  );