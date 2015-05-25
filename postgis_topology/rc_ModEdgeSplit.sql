
----------
-- Rémi-C , IGN THALES
--02/2015
-- changing st_modedgesplit ot take into account precision

DROP FUNCTion if exists topology.rc_modedgesplit(atopology character varying, anedge integer,  apoint geometry, anode_id int ) ;
CREATE OR REPLACE FUNCTION topology.rc_modedgesplit(atopology character varying, anedge integer, apoint geometry, anode_id int DEFAULT NULL)
  RETURNS integer AS
$BODY$
DECLARE
  oldedge RECORD;
  rec RECORD;
  tmp integer;
  topoid integer;
  nodeid integer;
  nodepos float8;
  newedgeid integer;
  newedge1 geometry;
  newedge2 geometry;
  query text;
  ok BOOL;
  topology_precision float := 0 ;  
BEGIN
	--filling topology_precision
	SELECT precision into topology_precision
		FROM topology.topology
		WHERE name = atopology  ; 
  --
  -- All args required
  -- 
  IF atopology IS NULL OR anedge IS NULL OR apoint IS NULL THEN
    RAISE EXCEPTION
     'SQL/MM Spatial exception - null argument';
  END IF;

  -- Get topology id
  BEGIN
    SELECT id FROM topology.topology
      INTO STRICT topoid WHERE name = atopology;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'SQL/MM Spatial exception - invalid topology name';
  END;

  --
  -- Check node existance
  -- 
  ok = false;
  FOR oldedge IN EXECUTE 'SELECT * FROM '
    || quote_ident(atopology) || '.edge_data ' ||
    ' WHERE edge_id =  ' || anedge
  LOOP
    ok = true;
  END LOOP;
  IF NOT ok THEN
    RAISE EXCEPTION
      'SQL/MM Spatial exception - non-existent edge';
  END IF;

  --
  -- Check that given point is Within(anedge.geom)
  -- 
  IF ST_DWithin(apoint, oldedge.geom,topology_precision) = FALSE THEN
    RAISE EXCEPTION
      'SQL/MM Spatial exception - point not on edge (with % precision)',topology_precision;
  END IF;

  --
  -- Check if a coincident node already exists
  --
  FOR rec IN EXECUTE 'SELECT node_id FROM '
    || quote_ident(atopology) || '.node 
    WHERE  ST_DWithin(node.geom, $1, $2) = TRUE
    AND node_id != anode_id'
    USING apoint, topology_precision, anode_id 
  LOOP
    RAISE EXCEPTION
     'SQL/MM Spatial exception - coincident node (with % precision)', topology_precision;
  END LOOP;

  --
  -- Get new node id
  --
  FOR rec IN EXECUTE 'SELECT nextval(''' ||
    atopology || '.node_node_id_seq'')'
  LOOP
    nodeid = rec.nextval;
  END LOOP;

  --RAISE NOTICE 'Next node id = % ', nodeid;



  --
  -- Compute new edge
  --
  SELECT ST_Collect(dmp.geom) into newedge2 
  FROM rc_split_line_by_points(oldedge.geom, apoint,topology_precision ) as dmp;  
  newedge1 := ST_GeometryN(newedge2, 1);
  newedge2 := ST_GeometryN(newedge2, 2);

  --
  -- Add the new node 
  --
  EXECUTE 'INSERT INTO ' || quote_ident(atopology)
    || '.node(node_id, geom) VALUES($1, $2)'
    USING nodeid,ST_EndPoint(newedge1);

  --
  -- Get ids for the new edge
  --
  FOR rec IN EXECUTE 'SELECT nextval(''' ||
    atopology || '.edge_data_edge_id_seq'')'
  LOOP
    newedgeid = rec.nextval;
  END LOOP;


  --
  -- Insert the new edge
  --
  EXECUTE 'INSERT INTO ' || quote_ident(atopology)
    || '.edge '
    || '(edge_id, start_node, end_node,'
    || 'next_left_edge, next_right_edge,'
    || 'left_face, right_face, geom) '
    || 'VALUES('
    || newedgeid
    || ',' || nodeid
    || ',' || oldedge.end_node
    || ',' || COALESCE(                      -- next_left_edge
                NULLIF(
                  oldedge.next_left_edge,
                  -anedge
                ),
                -newedgeid
              )
    || ',' || -anedge                        -- next_right_edge
    || ',' || oldedge.left_face              -- left_face
    || ',' || oldedge.right_face             -- right_face
    || ',$1)' --geom
    USING newedge2;

  --
  -- Update the old edge
  --
  EXECUTE 'UPDATE ' || quote_ident(atopology)
    || '.edge_data SET geom = $1, next_left_edge = $2, ' 
    || 'abs_next_left_edge = $2, end_node = $3 WHERE edge_id = $4'
    USING newedge1, newedgeid, nodeid, anedge;


  --
  -- Update all next edge references to match new layout
  --

  EXECUTE 'UPDATE ' || quote_ident(atopology)
    || '.edge_data SET next_right_edge = '
    || -newedgeid 
    || ','
    || ' abs_next_right_edge = ' || newedgeid
    || ' WHERE edge_id != ' || newedgeid
    || ' AND next_right_edge = ' || -anedge;

  EXECUTE 'UPDATE ' || quote_ident(atopology)
    || '.edge_data SET '
    || ' next_left_edge = ' || -newedgeid
    || ','
    || ' abs_next_left_edge = ' || newedgeid
    || ' WHERE edge_id != ' || newedgeid
    || ' AND next_left_edge = ' || -anedge;

  --
  -- Update references in the Relation table.
  -- We only take into considerations non-hierarchical
  -- TopoGeometry here, for obvious reasons.
  --
  FOR rec IN EXECUTE 'SELECT r.* FROM '
    || quote_ident(atopology)
    || '.relation r, topology.layer l '
    || ' WHERE '
    || ' l.topology_id = ' || topoid
    || ' AND l.level = 0 '
    || ' AND l.layer_id = r.layer_id '
    || ' AND abs(r.element_id) = ' || anedge
    || ' AND r.element_type = 2'
  LOOP
    --RAISE NOTICE 'TopoGeometry % in layer % contains the edge being split (%) - updating to add new edge %', rec.topogeo_id, rec.layer_id, anedge, newedgeid;

    -- Add new reference to edge1
    IF rec.element_id < 0 THEN
      tmp = -newedgeid;
    ELSE
      tmp = newedgeid;
    END IF;
    query = 'INSERT INTO ' || quote_ident(atopology)
      || '.relation '
      || ' VALUES( '
      || rec.topogeo_id
      || ','
      || rec.layer_id
      || ','
      || tmp
      || ','
      || rec.element_type
      || ')';

    --RAISE NOTICE '%', query;
    EXECUTE query;
  END LOOP;

  --RAISE NOTICE 'Edge % split in edges % and % by node %',
  --  anedge, anedge, newedgeid, nodeid;

  RETURN nodeid; 
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION topology.st_modedgesplit(character varying, integer, geometry)
  OWNER TO postgres;
COMMENT ON FUNCTION topology.st_modedgesplit(character varying, integer, geometry) IS 'args: atopology, anedge, apoint - Split an edge by creating a new node along an existing edge, modifying the original edge and adding a new edge.';
