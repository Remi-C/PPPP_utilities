---------------------------------------------
--Copyright Remi-C Thales IGN 04/2015
-- 
--overide of classical function, precision error safe
--------------------------------------------
--SET search_path TO street_amp, bdtopo_topological,  bdtopo,topology, public ;


-- Function: topology.st_getfacegeometry(character varying, integer)

-- DROP FUNCTION rt_getfacegeometry(character varying, integer);
CREATE OR REPLACE FUNCTION rc_getfacegeometry(toponame character varying, aface integer)
  RETURNS geometry AS
$BODY$
DECLARE
  rec RECORD;
  sql TEXT;
  face_surface GEOMETRY ;
BEGIN
	--RAISE NOTICE '%',aface;
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
			SELECT edge_id ,abs_next_left_edge AS next_edge_id , St_SnapToGrid(geom,0.001) AS geom
				, left_face, right_face --only keeping it for final removing of isolated edges
			FROM ' || quote_ident(toponame)||'.edge_data
			WHERE left_face = $1 	 AND right_face != $1
		UNION  ALL --we have to invert the edges that are in the other direction ,so as everyone is turning in the same direction (counter clockwise)
			SELECT edge_id ,abs_next_right_edge AS next_edge_id , St_SnapToGrid(ST_Reverse(geom),0.001) AS geom 
				, left_face, right_face --only keeping it for final removing of isolated edges
			FROM ' || quote_ident(toponame)||'.edge_data
			WHERE right_face = $1
			)
		,getting_context AS (
			SELECT o.edge_id , o.next_edge_id ,o.geom AS geom1,  e1.geom AS geom2    
			FROM n_edge AS o
				INNER JOIN n_edge AS e1 ON (e1.edge_id = o.next_edge_id ) 
		--	WHERE  e1.left_face != e1.right_face --we don t use the isolated edges, because it will have no impact on the polygon
		) 
		SELECT   --we snap the beggining of each next line to the end of each edge_id line, then make a big line respecting order out of it, then make a polygon
			ST_AsText(
				ST_BuildArea( --taking the line to make a polygon with it
					ST_Collect( --merging the multiline into one continuous line,  __respecting the order__ , the order is paramount 
							ST_AddPoint(--setting the first point of next_line to be the same as last point from line
								geom2
								, ST_PointN(
									geom1
									, ST_NPoints(geom1)
									) 
								,0
								) 
							 )
						)
					)  AS geom
		FROM getting_context 
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
  LANGUAGE plpgsql STABLE ;
/*
	SELECT face_id,  st_astext(mbr), st_astext(face_surface),ST_Astext(rc_face_surface) 
	FROM face, st_getfacegeometry('bdtopo_topological', face_id) face_surface
		, rc_getfacegeometry('bdtopo_topological', face_id) rc_face_surface
	WHERE ( face_surface IS NULL OR rc_face_surface IS NULL )
		AND face_id != 0 

	WITH edges AS (
		SELECT face_id
		FROM face
		WHERE face_id !=0
		ORDER BY face_id ASC 
		LIMIT 5000 
		OFFSET 1000
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



SELECT face_id, rc_getfacegeometry('bdtopo_topological', face_id)
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
		WHERE left_face = 1062 AND right_face != 1062 
	UNION  ALL --we have to invert the edges that are in the other direction ,so as everyone is turning in the same direction (counter clockwise)
		SELECT edge_id ,abs_next_right_edge AS next_edge_id , ST_Reverse(geom) AS geom 
			, left_face, right_face --only keeping it for final removing of isolated edges
		FROM edge_data
		WHERE right_face = 1062 
		)
	,getting_context AS (
		SELECT o.edge_id , o.next_edge_id ,o.geom AS geom1,  e1.geom AS geom2    
		FROM n_edge AS o
			INNER JOIN n_edge AS e1 ON (e1.edge_id = o.next_edge_id ) 
	--	WHERE  e1.left_face != e1.right_face --we don't use the isolated edges, because it will have no impact on the polygon
	) 
	SELECT   --we snap the beggining of each next line to the end of each edge_id line, then make a big line respecting order out of it, then make a polygon
		ST_AsText(
			ST_BuildArea( --taking the line to make a polygon with it
				ST_Collect( --merging the multiline into one continuous line,  __respecting the order__ , the order is paramount 
						ST_AddPoint(--setting the first point of next_line to be the same as last point from line
							geom2
							, ST_PointN(
								geom1
								, ST_NPoints(geom1)
								) 
							,0
							) 
						 )
					)
				)  AS geom
	FROM getting_context 
	 
		
SELECT  rc_getfacegeometry('bdtopo_topological', face_id)
	-- st_getfacegeometry('bdtopo_topological', face_id)
FROM face 
LIMIT 1000


	 SELECT ST_Astext(rc_getfacegeometry('bdtopo_topological', 735))
	 SELECT ST_Astext(st_getfacegeometry('bdtopo_topological', 735))
*/ 