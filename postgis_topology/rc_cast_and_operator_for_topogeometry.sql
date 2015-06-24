---------------------------------------------
--Copyright Remi-C Thales IGN 23/10/2013
--
--
--add on to postgis_topology
--
--
--This script expects postgis topology enabled
--
--
--adding 2 base function to postgis_topology
--------------------------------------------

/* --Custom Version
		--creating the egal operator for topology.topogeometry type
		DROP FUNCTION IF EXISTS  rc_topogeometry_egal(tg1 topogeometry,tg2 topogeometry) CASCADE;
		CREATE FUNCTION  rc_topogeometry_egal(tg1 topogeometry,tg2 topogeometry)
		    RETURNS boolean AS
		    $BODY$
				-- This function returns true if every field of topogeom1 are egal to topogeom2 (int = meaning) in the same order, false else.
				--returns null if any field is NULL, whatever the others.
				DECLARE
				BEGIN
				--	RETURN 
					--	(tg1).topology_id=(tg2).topology_id 
					--	AND (tg1).layer_id=(tg2).layer_id 
					--	AND (tg1).id=(tg2).id 
					--	AND (tg1).type=(tg2).type;
					RETURN tg1::int[]=tg2::int[];
				END;
		    $BODY$
		LANGUAGE plpgsql IMMUTABLE;

		CREATE OPERATOR == (
		    leftarg = topogeometry,
		    rightarg = topogeometry,
		    procedure = rc_topogeometry_egal,
		    commutator = ==
		);


		--
		--creating a cast from topology.topogeom to int[]
		DROP FUNCTION IF EXISTS rc_topogeometry_CastToIntArr(tg1 topology.topogeometry) CASCADE;
		CREATE FUNCTION  rc_topogeometry_CastToIntArr(tg1 topology.topogeometry)
		    RETURNS int[] AS
		    $BODY$
				-- This function rast a topology.topogeom into an int[]
				DECLARE
				BEGIN
					RETURN ARRAY[(tg1).topology_id, (tg1).layer_id,(tg1).id,(tg1).type];
				END;
		    $BODY$
				LANGUAGE plpgsql IMMUTABLE;

			SELECT  rc_topogeometry_CastToIntArr((NULL,2,3,4)::topology.topogeometry);
			
		CREATE CAST (topogeometry AS int[])
		    WITH FUNCTION  rc_topogeometry_CastToIntArr(topology.topogeometry)
		    AS IMPLICIT ;

		SELECT (1,2,3,4)::topogeometry::int[];
		
*/

/*--public version
		  -- _first a cast from topogeometry to int[]

		--creating a cast from topology.topogeom to int[]
		DROP FUNCTION IF EXISTS  topology.topogeometry_CastToIntArr(tg1 topology.topogeometry);
		CREATE FUNCTION topology.topogeometry_CastToIntArr(tg1 topology.topogeometry)
		    RETURNS int[] AS
		    $BODY$
				-- This function rast a topology.topogeom into an int[]
				DECLARE
				BEGIN
					RETURN ARRAY[(tg1).topology_id, (tg1).layer_id,(tg1).id,(tg1).type];
				END;
		    $BODY$
				LANGUAGE plpgsql IMMUTABLE;

			SELECT  topology.topogeometry_CastToIntArr((NULL,2,3,4)::topology.topogeometry);
			
		CREATE CAST (topology.topogeometry AS int[])
		    WITH FUNCTION  topology.topogeometry_CastToIntArr(topology.topogeometry)
		    AS IMPLICIT ;

		SELECT (1,2,3,4)::topogeometry::int[];
		    
		--_second an = operator for topogeometry

		--creating the egal operator for topology.topogeometry type
		DROP FUNCTION IF EXISTS  topology.topogeometry_egal(tg1 topology.topogeometry,tg2 topology.topogeometry) CASCADE;
		CREATE FUNCTION topology.topogeometry_egal(tg1 topology.topogeometry,tg2 topology.topogeometry)
		    RETURNS boolean AS
		    $BODY$
				-- This function returns true if every field of topogeom1 are egal to topogeom2 (int = meaning) in the same order, false else.
				--returns null if any field is NULL, whatever the others.
				DECLARE
				BEGIN
				--	RETURN 
					--	(tg1).topology_id=(tg2).topology_id 
					--	AND (tg1).layer_id=(tg2).layer_id 
					--	AND (tg1).id=(tg2).id 
					--	AND (tg1).type=(tg2).type;
					RETURN tg1::int[]=tg2::int[];
				END;
		    $BODY$
		LANGUAGE plpgsql IMMUTABLE;

		CREATE OPERATOR = (
		    leftarg = topology.topogeometry,
		    rightarg = topology.topogeometry,
		    procedure = topology.topogeometry_egal,
		    commutator = =
		);
   */