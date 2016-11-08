

		--settings to help test
		--SET search_path TO demo_zone_test,bdtopo,bdtopo_bati,bdtopo_reseau_route,topology,public;
		--SET postgis.backend = 'sfcgal';


		----
		--@TODO
		----
		--3D input / behavior : 
		--	_result in 3D
		--	_3D input safely outputing 2D output?
		-- SET search_path to rc_lib , public;  

		
		DROP FUNCTION IF EXISTS rc_compute_arc(p1 geometry, p2 geometry, p3 geometry, max_radius double precision, tolerance double precision, allow_full_circle BOOLEAN  );
		CREATE FUNCTION rc_compute_arc(p1 geometry, p2 geometry, p3 geometry,max_radius double precision,  tolerance double precision default 0.00000001, allow_full_circle BOOLEAN DEFAULT TRUE )
			RETURNS geometry AS
		$BODY$
		--note : depends on public.rc_MakeArc()
		--this function return the curve (arc of a circle), between point1 and point2 with p3 being the center
		--checking input
				--point1 and point2 must be type point and non empty 
				--max_radius should be positive, 0 is allowed and means 'always returns a line'
				--tolerance should be positive, O means no tolerance (excat computation)
				--	it is defined as the smallest possible distance between 2 points. 
		--degenerate cases
			--|P1P2|<tolerance
				--YES:
					-- |P3P1| and |P3P2| > tolerance
						--allow_full_circle = YES
							-- YES : return full circle 
							--NO : WARN, return NULL
						--allow_full_circle = NO
							--return a line between P1 and P2
				--NO : 
					-- |P1P3| or |P2P3| > max_radius
						-- YES : return line 
						-- NO : 
							--|P1P3| - |P2P3| < tolerance
								-- YES
									-- return curve
								-- NO
									-- warn, return line

		    DECLARE
			result geometry;
			t int;
			x_n double precision;
			y_n double precision;
			abs_n double precision;
		    BEGIN
			--checking input
				--point1 and point2 must be type point and non empty 
				IF  ST_IsEmpty( p1 )= true  OR   ST_IsEmpty(p2) = TRUE  THEN 
					IF ST_IsEmpty( p3)= false then 
					RAISE NOTICE 'wrong input for arc computation P1 or P2 is empty'; RETURN NULL;
					else 
					RAISE NOTICE 'wrong input for arc computation P1 or P2 is empty AND P3 is empty, P3 can be empty only if P1 and p2 are defined'; RETURN NULL;
					end if;
				ELSE --P1 P2 are acceptable, set p3 to p1 (for following computation, this will makes a line if no tolerance issues)
					IF ST_IsEmpty( p3)= TRUE THEN
					p3 := p1;
					raise notice 'p3 as text : % ',ST_AsText(p3);
					END IF;
				END IF;
				--max_radius should be positive, 0 is allowed and means 'always returns a line'
				IF  max_radius <0 IS true  THEN 
					RAISE NOTICE 'wrong input for arc computation max_radius should be positiv : it is the maximum possible radius of output, iif radius is above line_limt, a line is returned (and not an arc)'; RETURN NULL; 
				END IF;
				--tolerance should be positive, O means no tolerance (exact computation)
				IF  tolerance <0 IS true  THEN 
					RAISE NOTICE 'wrong input for arc computation : tolerance should be positive : this value is used to make test with a given precision . We set it to 0'; 
					tolerance := 0;
					--RETURN NULL; 
				END IF;
				


			-- preparing variable fo tests
				--P1P2
				--P3P1
				--P3P2
			-- degenerate cases
				--RAISE NOTICE ' |P1P2|<tolerance : % ',ST_DWithin(p1,p2,tolerance)= TRUE ;
				--|P1P2|<tolerance
				IF ST_DWithin(p1,p2,tolerance)= TRUE
				THEN
				--YES:
					IF allow_full_circle = TRUE THEN
						IF ST_DWithin(p1,p3,tolerance)  OR ST_DWithin(p2,p3,tolerance) THEN
						-- |P3P1| OR |P3P2| < tolerance
							--YES : WARN, return NULL
							RAISE NOTICE 'wrong input for arc computation : p1,p2 and p3 are almost identical (up to "tolerance"), returning null'; RETURN NULL;
						ELSE 
							-- NO : return full circle : that is circle passing by p1/p2 and by the symmetric point of p1/p2 by p3
								--note : 
							RETURN rc_lib.rc_MakeArc(
								p1,
								ST_Affine(p3, 1,0,0, 0,1,0, 0,0,1, ST_X(p3)-ST_X(p1) ,ST_Y(p3)-ST_Y(p1),0),
								p2
								);
						END IF;	
					ELSE --no full circle : return the line 
						RETURN ST_MakeLine(p1,p2);
					END IF; 
				ELSE
				--NO : 
					--RAISE NOTICE ' |P1P3| AND |P2P3| < max_radius %',ST_DWIthin(p1,p3,max_radius)=TRUE AND ST_DWIthin(p2,p3,max_radius)=TRUE ;
					IF ST_DWIthin(p1,p3,max_radius)=TRUE AND ST_DWIthin(p2,p3,max_radius)=TRUE 
					THEN-- |P1P3| AND |P2P3| < max_radius
							-- YES : 
						--RAISE NOTICE '|P1P3| - |P2P3| < tolerance : "%" ', 10000*abs(ST_Distance(p1,p3) - ST_Distance(p2,p3))  ;
						IF abs(ST_Distance(p1,p3) - ST_Distance(p2,p3)) <= tolerance 
						THEN --|P1P3| - |P2P3| < tolerance
							-- YES
								--note : compute mid point position
								
									--
							x_n := ST_X(p1)+ST_X(p2)-2*ST_X(p3);
							y_n := ST_Y(p1)+ST_Y(p2)-2*ST_Y(p3);
							abs_n:=sqrt(x_n^2+y_n^2);
							RETURN  rc_lib.rc_MakeArc(
								p1,
								ST_Affine(
									p3,
									1,0,0, 0,1,0 ,0,0,1 ,
									ST_Distance(p1,p3)*x_n / abs_n,
									ST_Distance(p1,p3)*y_n / abs_n,
									0
									),
								p2
								);
						ELSE 
							-- NO
								RAISE NOTICE 'wrong input for arc computation : the center is not at same distance (+- tolerance) from p1 and p2, outputting a line ';
								RETURN ST_MakeLine(p1,p2);
								-- warn, return line
						END IF;														--|P1P3| - |P2P3| < tolerance
					ELSE
						-- NO : return line 
						RETURN ST_MakeLine(p1,p2);
					END IF; 														-- |P1P3| AND |P2P3| < max_radius
				END IF; 														--|P1P2|<tolerance

				
			RETURN NULL ;
			END 
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;
		----
		--Testing the function
/*		
		SELECT ST_AsText(St_CurveToLine(public.rc_compute_arc(
			'point(0 10)'::geometry, --point1 geom, 
			'point(10 0)'::geometry, --point2 geom, 
			'point(0 0)'::geometry, --center geom, 
			100, --max_radius double precision
			0.0001 --tolerance double precision
			),8));
	

		--testing input
			---
			--@TODO
			-- what if imput is 3D
			
			--P1 P2 P3 : dealing with enptyness 
				--should return NULL and a message warning about emptyness
				--SELECT public.rc_compute_arc( 'point(0 10)'::geometry, 'point(10 0)'::geometry, 'POINT empty '::geometry,  100,  0.0001 );	
				SELECT public.rc_compute_arc('point empty'::geometry,'point(10 0)'::geometry, 'point(0 0) '::geometry, 100, 0.0001);
				SELECT public.rc_compute_arc('point (0 10)'::geometry,'point empty'::geometry,'point(0 0)'::geometry,100,0.0001);
				SELECT public.rc_compute_arc('point empty'::geometry,'point empty'::geometry,'point empty'::geometry,100,0.0001);
				SELECT public.rc_compute_arc('point empty'::geometry, 'point empty'::geometry, 'point(0 0) '::geometry, 100, 0.0001);

				SELECT public.rc_compute_arc('point empty'::geometry,'point(10 0)'::geometry, 'point empty'::geometry, 100, 0.0001);
				SELECT public.rc_compute_arc('point (0 10)'::geometry,'point empty'::geometry,'point empty'::geometry,100,0.0001);
				SELECT public.rc_compute_arc('point (0 10)'::geometry,'point(10 0)'::geometry, 'point empty '::geometry, 100, 0.0001);

			-- max_radius : neg, 0, positiv
				SELECT public.rc_compute_arc( 'point(0 10)'::geometry,'point(10 0)'::geometry, 'point(0 0)'::geometry,  -100.001,  0.0001 );	
				SELECT ST_AsText(public.rc_compute_arc( 'point(0 10)'::geometry,'point(10 0)'::geometry, 'point(0 0)'::geometry,  0.000,  0.0001 ));
				
			-- tolerance : neg, 0, default
				SELECT ST_AsText(public.rc_compute_arc( 'point(0 10)'::geometry,'point(10 0)'::geometry, 'point(0 0)'::geometry,  100.001,  -100.001 ));
				SELECT ST_AsText(public.rc_compute_arc( 'point(0 10)'::geometry,'point(10 0)'::geometry, 'point(0 0)'::geometry,  100.001,  0 ));
				SELECT public.rc_compute_arc( 'point(0 10.00000001)'::geometry,'point(0 10.00000002)'::geometry, 'point(0 0)'::geometry,  100.001 );

		--degenerate cases
			--|P1P2|<tolerance
				--YES:
					-- |P3P1| and |P3P2| > tolerance
						-- YES : return full circle
							SELECT ST_AsText(ST_CurveToLine(public.rc_compute_arc( 'point(1 10)'::geometry,'point(-1 10)'::geometry, 'point(0 0)'::geometry,  100.001,  3),2));
						--NO : WARN, return NULL
							SELECT public.rc_compute_arc( 'point(1 10)'::geometry,'point(-1 10)'::geometry, 'point(0 0)'::geometry,  100.001,  11);
				--NO : 
					-- |P1P3| or |P2P3| > max_radius
						-- YES : return line 
							SELECT ST_AsText(public.rc_compute_arc( 'point(2 10)'::geometry,'point(-2 10)'::geometry, 'point(0 0)'::geometry,  12,  40));
							SELECT ST_AsText(public.rc_compute_arc( 'point(2 10)'::geometry,'point(-2 14)'::geometry, 'point(0 0)'::geometry,  12,  8));
							SELECT ST_AsText(public.rc_compute_arc( 'point(10 2)'::geometry,'point(10 -2)'::geometry, 'point(0 0)'::geometry,  10,  1));

						-- NO : 
							--|P1P3| - |P2P3| < tolerance --ie : P1 P2 t egal distance to P3
								-- YES
									-- return curve
										SELECT public.rc_compute_arc( 'point(2 10)'::geometry,'point(-2 10)'::geometry, 'point(0 0)'::geometry,  100,  0.0001);
								-- NO
									-- warn, return line
										SELECT public.rc_compute_arc( 'point(3 10)'::geometry,'point(-2 10)'::geometry, 'point(0 0)'::geometry,  12,  0.0001);
										


*/

	DROP FUNCTION IF EXISTS rc_MakeArc(p1 geometry, p2 geometry, p3 geometry);
		CREATE FUNCTION rc_MakeArc(p1 geometry, p2 geometry, p3 geometry)
			RETURNS geometry AS
		$BODY$
			--this function create a curve geometry based on input 3 points. Points are supposed to be in the natural order along the curve
			--about order:
			--the arc is oriented and goes from p1 to p3 passing by p2
			--if describing a complete circle, p1 and P3 have to be identical, and p2 is considered to be on the same diameter than P1 and P3 but on the other side of the circle.
			DECLARE 
			result geometry := NULL;
			t text;
			query text;
			srid integer;
			BEGIN

				--getting srid of input if any
				srid :=  COALESCE(GREATEST(ST_SRID(p1),ST_SRID(p2),ST_SRID(p3)) ,0);
				--the trick is  to create first a linestring, then to change the WKB reprensentation, going from 2 to 8 to change from line string to circularstring
				RETURN 
					ST_SetSRID(
						geometry(  
								set_byte(
									ST_AsBinary(
										ST_MakeLine(ARRAY[p1,p2,p3])
									)::bytea
								,1,8)
							)
						,srid
						);
			END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;



/*		----
		SELECT 1, ST_AsText(
			ST_CurveToLine(public.rc_MakeArc(
			'point(0 1)'::geometry,--p1 geometry
			'point(0.7 0.7)'::geometry,-- p2 geometry
			'point(1 0)'::geometry -- p3 geometry
			),
			4));

		
		SELECT 1, ST_AsText(
			ST_CurveToLine(public.rc_MakeArc(
			'point(1 0)'::geometry,--p1 geometry
			'point(-1 0)'::geometry,-- p2 geometry
			'point(1 0 )'::geometry -- p3 geometry
			),
			2));


		SELECT ST_AsBinary(ST_GeomFromtext( 'CIRCULARSTRING(0 1 , 1 1, 2 1)'))::bytea;
		SELECT ST_GeomFromtext( 'multipoint(0 1 , 1 1, 2 1)');
*/
