---------------------------------------------
--Copyright Remi-C Thales IGN 13/09/2013
--
--
--S aimple wrapper around st_split
-- 
--------------------------------------------

--___ rc_Split_multi(input_geom geometry ,blade geometry)___
	
		--creating a simple wrapper around ST_Split to allow splitting line by multipoints
		DROP FUNCTION IF EXISTS rc_Split_multi(input_geom geometry ,blade geometry, tolerance double precision ) CASCADE;
		CREATE FUNCTION rc_Split_multi(input_geom geometry ,blade geometry, tolerance double precision )
		  RETURNS geometry AS
		$BODY$
		--this function is a wrapper around the function ST_Split to allow splitting mutli_lines with multi_points
		--
		    DECLARE
			result geometry;
			simple_blade geometry;
			blade_geometry_type text := GeometryType(blade); geom_geometry_type text := GeometryType(input_geom);
			blade_coded_type SMALLINT; geom_coded_type SMALLINT;
			srid_blade INT := ST_SRID(blade);
			srid_input_geom INT := ST_SRID(input_geom);
			
		    BEGIN

			--finding type of input : mixed type are not allowed
			--if type is not multi, simply splitting and returning result

				IF blade_geometry_type NOT ILIKE 'MULTI%' THEN
					--RAISE NOTICE 'input geom is simple, doing regular split';
					RETURN ST_Split(input_geom,blade);
				ELSIF blade_geometry_type ILIKE '%POINT' THEN
					blade_coded_type:= 1;
				ELSIF blade_geometry_type ILIKE '%LINESTRING' THEN
					blade_coded_type:= 2;
				ELSIF blade_geometry_type ILIKE '%POLYGON' THEN
					blade_coded_type:= 3;
				ELSE
					RAISE NOTICE 'mutliple input geometry types for the blade : should be homogenous ';
					RETURN NULL;
				END IF;

				IF geom_geometry_type ILIKE '%POINT' THEN
					geom_coded_type:= 1;
				ELSIF geom_geometry_type ILIKE '%LINESTRING' THEN
					geom_coded_type:= 2;
				ELSIF geom_geometry_type ILIKE '%POLYGON' THEN
					geom_coded_type:= 3;
				ELSE
					RAISE NOTICE 'mutliple input geometry types for the geom: should be homogenous ';
					RETURN NULL;
				END IF;

			result := input_geom;			
			--Loop on all the geometry in the blade
			FOR simple_blade IN SELECT  ST_SetSRID( (ST_Dump(ST_CollectionExtract(blade, blade_coded_type))).geom , srid_blade) 
			LOOP
					result:= ST_SetSRID(ST_CollectionExtract(ST_Split(ST_CollectionExtract(result,geom_coded_type),simple_blade),geom_coded_type), srid_input_geom);
			END LOOP;
			RETURN result;
		    END;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

        
/*
		--Testing the function
		SELECT ST_AsText(rc_Split_multi( geom,blade ,0.001))
		FROM (
				SELECT 
					--ST_GeomFromText('Multilinestring((-3 0, 3 0),(-1 0,1 0))') AS geom,
					--ST_GeomFromText('MULTIPOINT((-0.5 0),(0.5 0))') AS blade
					--ST_GeomFromText('POINT(-0.5 0)') AS blade
					--ST_GeomFromText('MULTILINESTRING((0 1, 0 -1),(0 2,0 -2))') AS blade
					--ST_GeomFromText('MULTIPOLYGON(((0 1,0 -1 ,1 -1,0 1)),((0 2,0 -2,1 -2,0 2)))') AS blade
				ST_GeomFromtext('MULTIPOINT(621.254 1483.268,628.529 1488.133)' ) AS blade
				,ST_GeomFromtext('LINESTRING(655.1 1505.9,605.3 1472.6)') AS geom
			) AS toto ; 
            
*/
