
SET search_path TO street_amp, bdtopo_topological,  bdtopo,topology, public ;


-- Function: topology.st_getfacegeometry(character varying, integer)

-- DROP FUNCTION topology.st_getfacegeometry(character varying, integer);

CREATE OR REPLACE FUNCTION public.rc_getfacegeometry(toponame character varying, aface integer)
  RETURNS geometry AS
$BODY$
DECLARE
  rec RECORD;
  sql TEXT;
  face_surface GEOMETRY ;
BEGIN
	RAISE NOTICE '%',aface;
  --
  -- toponame and aface are required
  -- 
  IF toponame IS NULL OR aface IS NULL THEN
    RAISE EXCEPTION 'SQL/MM Spatial exception - null argument';
  END IF;

  IF NOT EXISTS(SELECT name FROM topology.topology WHERE name = toponame)  THEN
    RAISE EXCEPTION 'SQL/MM Spatial exception - invalid topology name';
  END IF;

  IF aface = 0 THEN
    RAISE EXCEPTION
      'SQL/MM Spatial exception - universal face has no geometry';
  END IF;

  BEGIN

    -- No such face
    sql := 'SELECT NOT EXISTS (SELECT 1 from ' || quote_ident(toponame)
      || '.face WHERE face_id = ' || aface
      || ') as none';
    EXECUTE sql INTO rec;
    IF rec.none THEN
      RAISE EXCEPTION 'SQL/MM Spatial exception - non-existent face.';
    END IF;

    --
    -- Construct face 
    --  
	sql :=
	'WITH n_edge AS ( --getting all the edges that are at the border of the face
			SELECT edge_id ,abs_next_left_edge AS next_edge_id , geom
				, left_face, right_face --only keeping it for final removing of isolated edges
			FROM ' || quote_ident(toponame)||'.edge_data
			WHERE edge_id != abs_next_left_edge --we avoid the (K,K) row because we would loop inifnitly in it
				AND left_face = $1 	 AND right_face != $1
		UNION ALL
			--we have to invert the edges that are in the other direction ,so as everyone is turning in the same direction (counter clockwise)
			SELECT edge_id ,abs_next_right_edge AS next_edge_id , ST_Reverse(geom) AS geom
				,right_face, left_face --only keeping it for final removing of isolated edges
			FROM ' || quote_ident(toponame)||'.edge_data
			WHERE edge_id != abs_next_right_edge --we avoid the (K,K) row because we would loop inifnitly in it
				AND right_face = $1  
		UNION ALL
			--we have to invert the edges that are in the other direction ,so as everyone is turning in the same direction (counter clockwise)
			SELECT DISTINCT ON (edge_id ) edge_id 
				, CASE WHEN edge_id = abs_next_right_edge THEN  abs_next_left_edge
						ELSE  abs_next_left_edge  END  AS next_edge_id 
					, geom --ST_AddPoint(ST_AddPoint(geom,ST_EndPoint(geom),-1),ST_StartPoint(geom),-1) AS geom --adding the first point to the end of the geom
				, left_face, right_face --only keeping it for final removing of isolated edges
			FROM edge_data
			WHERE (right_face = $1 OR left_face = $1)
				AND (abs_next_right_edge != edge_id OR abs_next_left_edge = edge_id ) 
	) 
	,ordering AS (--we get an iteration column that gives the order for looping trough stuff. This way we know that the linestring are going to be put into the correct order
		--note : it is possible to not compute if using buildarea with collected (unordered) edges. However BuildArea can t use the index that this ordering is using ! 
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
					AND  c.iteration = iteration  
					)
			)
			SELECT * FROM chain 
			WHERE iteration !=1
			) AS sub
	)
	,getting_context AS (
		 SELECT o.edge_id , o.next_edge_id , e1.geom AS geom1 -- , e2.geom AS geom2
			,  iteration AS ordinality
			
		FROM ordering AS o
			INNER JOIN n_edge AS e1 ON (e1.edge_id = o.edge_id ) 
		WHERE  e1.left_face != e1.right_face --we don t use the isolated edges, because it will have no impact on the polygon
	)
	,rebuilding_order AS (--we have to recompute next_edge because some edges may be filtered out because they won t participate 
		SELECT edge_id
			,geom1
			,COALESCE(lead(geom1 , 1, NULL) OVER ordinality_window, first_value(geom1) OVER ordinality_window ) AS geom2
			,ordinality 
		FROM getting_context
		WINDOW ordinality_window AS (ORDER BY ordinality ASC)
		 
	) 
	 --we snap the beggining of each next line to the end of each edge_id line, then make a big line respecting order out of it, then make a polygon
		SELECT  ST_MakePolygon( --taking the line to make a polygon with it
					ST_MakeLine( --merging the multiline into one continuous line
						  --grouping the line into one __respecting the order__ , the order is paramount
							ST_AddPoint(--setting the first point of next_line to be the same as last point from line
								geom2 
								, ST_PointN(
									geom1
									, ST_NPoints(geom1)
									)
								,0) 
								
							ORDER BY ordinality ASC) 
					)  AS geom
		FROM rebuilding_order
		LIMIT 1-- this is not necessary but it is to be sure
		;';  
	EXECUTE sql INTO face_surface USING aface; --there will be only one output!

	  EXCEPTION
	    WHEN INVALID_SCHEMA_NAME THEN
	      RAISE EXCEPTION 'SQL/MM Spatial exception - invalid topology name';
	    WHEN UNDEFINED_TABLE THEN
	      RAISE EXCEPTION 'corrupted topology "%"', toponame;
	  END;

	return face_surface ;
  RETURN NULL;
END
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
ALTER FUNCTION public.rc_getfacegeometry(character varying, integer)
  OWNER TO postgres;
COMMENT ON FUNCTION public.rc_getfacegeometry(character varying, integer) IS 'args: atopology, aface - Returns the polygon in the given topology with the specified face id.';




 

	WITH edges AS (
		SELECT face_id
		FROM face
		WHERE face_id !=0
		ORDER BY face_id ASC 
		LIMIT 500 
		OFFSET 0
	)
	,rc AS (
		SELECT rc_getfacegeometry('bdtopo_topological', face_id)
		FROM edges
	)
-- 	,st AS (
-- 		SELECT st_getfacegeometry('bdtopo_topological', face_id)
-- 		FROM edges
-- 	)
	SELECT (SELECT count(*) FROM rc)  
		--(SELECT count(*) FROM st)



SELECT  rc_getfacegeometry('bdtopo_topological', face_id)
	 ,st_getfacegeometry('bdtopo_topological', face_id)
FROM face
WHERE face_id != 0
LIMIT 100

SELECT *
FROM edge_data
WHERE right_face = 179 OR left_face = 179


WITH n_edge AS ( --getting all the edges that are at the border of the face
	SELECT edge_id ,abs_next_left_edge AS next_edge_id , geom
		, left_face, right_face --only keeping it for final removing of isolated edges
	FROM edge_data
	WHERE left_face = 179 AND right_face != 179
		AND abs_next_left_edge != edge_id --avoiding the (K,K) edge, becauses it causes the recursive cte to run infinitively
	UNION ALL
	--we have to invert the edges that are in the other direction ,so as everyone is turning in the same direction (counter clockwise)
	SELECT edge_id ,abs_next_right_edge AS next_edge_id , ST_Reverse(geom) AS geom 
		, left_face, right_face --only keeping it for final removing of isolated edges
	FROM edge_data
	WHERE right_face = 179 
		AND abs_next_right_edge != edge_id --avoiding the (K,K) edge, becauses it causes the recursive cte to run infinitively

	UNION ALL
	--we have to invert the edges that are in the other direction ,so as everyone is turning in the same direction (counter clockwise)
	SELECT DISTINCT ON (edge_id ) edge_id
		, CASE WHEN edge_id = abs_next_right_edge THEN  abs_next_left_edge
				ELSE  abs_next_left_edge  END  AS next_edge_id 
			, ST_AddPoint(ST_AddPoint(geom,ST_EndPoint(geom),-1),ST_StartPoint(geom),-1) AS geom --adding the first point to the end of the geom
		, left_face, right_face --only keeping it for final removing of isolated edges
	FROM edge_data
	WHERE (right_face = 179 OR left_face =179)
		AND (abs_next_right_edge != edge_id OR abs_next_left_edge = edge_id ) 
	) 
	-- SELECT edge_id, next_edge_id--, ST_AsText(ST_Collect(geom))
-- 	FROM n_edge
-- 	ORDER BY edge_id ASC
	,ordering AS (--we get an iteration column that gives the order for looping trough stuff. This way we know that the linestring are going to be putted into the correct order
		--note : it is possible to not compute if using buildarea with collected (unordered) edges.
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
	) 
	,getting_context AS (
		 SELECT o.edge_id , o.next_edge_id , e1.geom AS geom1 -- , e2.geom AS geom2
			,  iteration AS ordinality
			
		FROM ordering AS o
			INNER JOIN n_edge AS e1 ON (e1.edge_id = o.edge_id ) 
	--	WHERE  e1.left_face != e1.right_face --we don't use the isolated edges, because it will have no impact on the polygon
	)
	,rebuilding_order AS (--we have to recompute next_edge because some edges may be filtered out because they won't participate 
		SELECT edge_id
			,geom1
			,COALESCE(lead(geom1 , 1, NULL) OVER ordinality_window, first_value(geom1) OVER ordinality_window ) AS geom2
			,ordinality 
		FROM getting_context
		WINDOW ordinality_window AS (ORDER BY ordinality ASC)
		 
	) 
	SELECT   --we snap the beggining of each next line to the end of each edge_id line, then make a big line respecting order out of it, then make a polygon
		ST_AsText(
			ST_MakePolygon( --taking the line to make a polygon with it
				ST_MakeLine( --merging the multiline into one continuous line,  __respecting the order__ , the order is paramount
					 
						ST_AddPoint(--setting the first point of next_line to be the same as last point from line
							geom2
							, ST_PointN(
								geom1
								, ST_NPoints(geom1)
								) 
							,0
							) 
						ORDER BY ordinality ASC)
					)
				)  AS geom
	FROM rebuilding_order 
	
		
SELECT  rc_getfacegeometry('bdtopo_topological', face_id)
	-- st_getfacegeometry('bdtopo_topological', face_id)
FROM face 
LIMIT 1000


	 SELECT ST_Astext(rc_getfacegeometry('bdtopo_topological', 735))
	 SELECT ST_Astext(st_getfacegeometry('bdtopo_topological', 735))
	 