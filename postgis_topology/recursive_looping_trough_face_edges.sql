-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
-- here is an example of how to loop trough all the edges that are the border of a face. It is fast.
------------------------------

WITH n_edge AS ( --getting all the edges that are at the border of the face
	SELECT edge_id ,abs_next_left_edge AS next_edge_id , geom
	FROM edge_data
	WHERE left_face = 308 	
	UNION ALL
	--we have to invert the edges that are in the other direction ,so as everyone is turning in the same direction (counter clockwise)
	SELECT edge_id ,abs_next_right_edge AS next_edge_id , ST_Reverse(geom) AS geom
	FROM edge_data
	WHERE right_face = 308  
	) 
	,ordering AS (--we get an iteration column that gives the order for looping trough stuff. This way we know that the next line is going to 
		SELECT * 
		FROm (
			WITH RECURSIVE chain(edge_id, next_edge_id, iteration,goal) AS (
			  (SELECT NULL::INT,  min,1 , min
			  FROM (SELECT min(edge_id)::int AS min FROM n_edge) AS the_min
			    )
			  UNION ALL
			(  SELECT c.next_edge_id, t.next_edge_id, c.iteration+1, c.goal
			  FROM chain c  
			 INNER JOIN n_edge AS  t ON (c.next_edge_id = t.edge_id)
				--WHERE c.iteration = iteration AND  
				WHERE  --c.iteration <100 AND 
				--WHERE c.next_edge_id !=2618 AND iteration!=1 
					c.next_edge_id != c.goal  OR c.edge_id IS NULL
					AND  c.iteration = iteration )
			)
			SELECT * FROM chain 
			WHERE iteration !=1
			) AS sub