---------------------------------------------
--Copyright Remi-C Thales IGN 13/09/2013
--
--
--Using postgis topology module to create topological surfaces for road,sidewalk, etc, ona small test zone
--
--
--This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--we work on table "route", which contains all the road network in Ile De France and many attributes. It is provided by IGN
--------------------------------------------




-- __Setting work env__
		--setting path to avoid préfixing table
		SET search_path TO demo_zone_test,bdtopo,bdtopo_bati,bdtopo_reseau_route,topology,public;


		
	-- ___ computing min turning radius ___
		--for this, we exploit the fact that vehicles have a normalized tunring radius : any vehicle should be able to turn between to circles of radius 5.3 and 12.5 meters
-- 		drop table if exists rayon_virage;
-- 		create table rayon_virage 
-- 		( gid serial NOT NULL,
-- 			  id text,
-- 			  geom geometry(polygon,931008),
-- 			  CONSTRAINT rayon_virage_pkey PRIMARY KEY (gid));
-- 		INSERT INTO rayon_virage (geom) SELECT rc_symdif(
-- 			rc_Dilate(ST_GeomFromText('POINT(650904.7 6860902.1)'),5.3/2,buffer_option:='quad_segs=8')
-- 			,rc_Dilate(ST_GeomFromText('POINT(650904.7 6860902.1)'),12.5/2,buffer_option:='quad_segs=8')
-- 			);
-- 			 


			--function computing the arc of circle corresponding to two segments
			--vacuum analyse;
			DROP FUNCTION IF EXISTS public.rc_arc_between_segments(seg1 geometry, seg2 geometry, circle_radius float,min_angle double precision);
			CREATE FUNCTION public.rc_arc_between_segments(seg1 geometry, seg2 geometry, circle_radius float,min_angle double precision DEFAULT 25)
			  RETURNS geometry AS
			$BODY$
			--this function compute the smallest arc of circle of a given radius between two segments where the segment have one point in common.
			--
			--the two segements have to touch at 1 extremity 
			--if the two segemnt are almost colinear (+- the min_angle parameter), we consider they are colinear and return accordingly

			--pseudo code of the function
			--	dealing with incompatible outputs
			--		min_angle
			--		circle_radius, disjoint, intersection not point, intersection not at begining/end,segs too short,
			
			DECLARE
			intersection geometry;
			error_text text;
			seg1_numpoints int := ST_NPoints(seg1); seg2_numpoints int := ST_NPoints(seg2);
			s1_fp int; s2_fp int; --the index number of the point of intersection in the seg1/seg2
			joining_seg1 geometry; joining_seg2 geometry;
			temp_seg geometry[2];
			V1 double precision[2]; V2 double precision[2];
			dot_product double precision; cos2 double precision; calc double precision;
			temp_points geometry[3];
			geom_length float[2];

			BEGIN

				--computing the intersection of the two input segments for testing degenerate case purpose
				intersection:= ST_Intersection(seg1,seg2);
				
				--dealing with incompatible inputs
					--check if angle is good :
					IF min_angle <0 OR min_angle >90
					THEN 
						RAISE NOTICE 'wrong value for min_angle parameter : it should be between 0 and 90 degrees, current value :% ',min_angle;
						RETURN NULL;
					END IF;
					--check if radius is strictly positive
					IF circle_radius <=0
					THEN
						RAISE NOTICE 'wrong value for parameter circle_radius : % . It should be strictly above 0',circle_radius;
						RETURN NULL;
					END IF; 
				
					--the two segments are disjoint : computing is impossible, warning and stopping
					IF ST_IsEmpty(intersection)=TRUE 
					THEN	--note : also true if both segment are empty
						--note : also true if one segment is empty and not the other
						RAISE NOTICE 'the two segments are disjoint, stopping ';
						RETURN NULL;
					END IF;

					--geometry intersection is not a point : 
					error_text:=GeometryType(intersection);
					if  error_text !='POINT'
					THEN
						RAISE NOTICE 'the two segment intersection is not a simple point : % , stopping',error_text;
						RETURN NULL;
					END IF;

					--check if input as at least 2 points
					IF (seg1_numpoints>=2 AND seg2_numpoints >=2) = FALSE
					then
						RAISE NOTICE 'one or both of the input are simple points : stopping : seg1:% seg2:%',ST_AsText(seg1),ST_AsText(seg2);
						RETURN NULL;
					end IF;
					
					--computing if the intersection point is not at the end /beggining of the 2 segments
					error_text := 
					(intersection =ST_StartPoint(seg1) 
						OR intersection = ST_EndPoint(seg1))
						AND (
					intersection =ST_StartPoint(seg2) 
						OR intersection = ST_EndPoint(seg2)
					);
					IF error_text != 't'
					THEN 
						RAISE NOTICE 'the common point is at the end/beginning of both segments, % : stopping',error_text;
						RETURN NULL;
					END IF;

					---@TODO
					--checking if the length of seg1 and seg2 is sufficent to give a result
						--note on behaviour :
						--if only one segment is of sufficient length, we elongate the short segment and make the computing
						--if both the segments are too short : we give a warning and output  3 extremities of the segment.

						--computing length
						geom_length[1] = ST_Length(seg1);
						geom_length[2] = ST_Length(seg2);

						--checking if both length are under circle radius
						IF geom_length[1]<= circle_radius AND geom_length[2]<=circle_radius
						THEN --we stop computation and output extremities
							temp_points[1]:= 
							ST_LineMerge( 
								ST_UnaryUnion(
									ST_Collect(
										ST_MakeLine(
											ST_StartPoint(seg1)
											,ST_EndPoint(seg1)
											)
										,ST_MakeLine(
											ST_StartPoint(seg2)
											,ST_EndPoint(seg2)
											)
										) 
									)
								);
							RAISE NOTICE 'Warning : input segs are too short (seg1:%; seg2:%) , output is just 3 extremities:%',geom_length[1],geom_length[2],ST_AsText(temp_points[1]);
							RETURN temp_points[1];

						ELSIF geom_length[1]<= circle_radius AND geom_length[2]>circle_radius OR geom_length[2]<= circle_radius AND geom_length[1]>circle_radius THEN --case when on segment is shorter than circle_radius, and the other is lengthier than it.

							IF(geom_length[1]<geom_length[2]) THEN
								temp_seg[1]:=seg1;temp_seg[2]:=seg2;
							ELSE 
								temp_seg[1]:=seg2;temp_seg[2]:=seg1;
							END IF;
							
							RAISE NOTICE 'shorter segment is in tep_seg[1], lengthier in temp_seg[2]';

							--we have to find the point on temp_seg2 which is at circle radius of the intersection
							

						
						END IF;
						
						--checking if only one of the input seg is shorter than circle_radius
						---@TODO
						--if seg1 too short : return a point at cirlce_radius on segment2, and extremities of segment1 
						--if seg2 is too short : same for seg2

					
				------------
				--everything should be okay : from now every input should give a result.
				------------
				
				--isolating the the two joining parts of the segments , ie the two end/beginning point which intersect
					

					--if the common point is first from seg1, joining seg1 is line(1,2) else joining seg1 is line (N,N-1)
					--same for seg2

					IF(ST_StartPoint(seg1) = intersection)
					THEN
						joining_seg1 := ST_MakeLine(ST_StartPoint(seg1),ST_PointN(seg1,2));
						s1_fp := 1 ;
					ELSE
						joining_seg1 := ST_MakeLine(ST_EndPoint(seg1),ST_PointN(seg1,seg1_numpoints-1));
						s1_fp := seg1_numpoints ;
					END IF;

					IF(ST_StartPoint(seg2) = intersection)
					THEN
						joining_seg2 := ST_MakeLine(ST_StartPoint(seg2),ST_PointN(seg2,2));
						s2_fp := 1 ;
					ELSE
						joining_seg2 := ST_MakeLine(ST_EndPoint(seg2),ST_PointN(seg2,seg2_numpoints-1));
						s2_fp := seg2_numpoints ;
					END IF;

					------------------
					--now we work on joining_seg1 and joining_seg2.

					RAISE NOTICE 'npoint1 : %, npoint2 : % ',seg1_numpoints,seg2_numpoints;
					RAISE NOTICE 'joining_seg1:,joining_seg2
					% ,
					%',ST_AsText(joining_seg1),ST_AsText(joining_seg2);


				--we compute the angle between 2 incoming segs
				--dealing with degenerate case :
					--case when segments form a straight line : ie the angle between the two joingin parts of the segments are colinear or almost colinear:
					--computing smallest angle between the two joining parts of segments

					--computing the 2 vectors 
						--V1 = (Xp1-Xp2,Yp1-Yp2)
						--V2 = (Xp1-Xp2,Yp1-Yp2)

						--V1[1]:= ; V1[2]:=;
						V1[1]:=ST_X(ST_StartPoint(joining_seg1))-ST_X(ST_EndPoint(joining_seg1));
						V1[2]:=ST_Y(ST_StartPoint(joining_seg1))-ST_Y(ST_EndPoint(joining_seg1));
						calc:= sqrt(power(V1[1],2)+power(V1[2],2));
						V1[1]:=V1[1]/calc;
						V1[2]:=V1[2]/calc;

						
						V2[1]:=ST_X(ST_StartPoint(joining_seg2))-ST_X(ST_EndPoint(joining_seg2));
						V2[2]:=ST_Y(ST_StartPoint(joining_seg2))-ST_Y(ST_EndPoint(joining_seg2));
						calc:= sqrt(power(V2[1],2)+power(V2[2],2));
						V2[1]:=V2[1]/calc;
						V2[2]:=V2[2]/calc;

						RAISE NOTICE 'V1:% , V2:% ',V1,V2;

					--computing dot product : 
						dot_product := V1[1]*V2[1]+V1[2]*V2[2];
						RAISE NOTICE 'dot_product : % ',dot_product;	
					--computing cos(alpha)²
					cos2 := (dot_product);

					RAISE NOTICE 'cos2 : % , cos(155):%, cos(25):%, ',cos2,cos(radians(180-min_angle)),cos(radians(min_angle));
					--computing cross product of 2 normalized vector, it is between 0 (90°) and 1 (0 or 180°)
					--(a1*b1 + a2*b2 )/(length(v1)+length(v2)) : = cos(alpha)


					
					
					--checking if angle is within admissible possibilities
					IF cos2::numeric <@ numrange(cos(radians(min_angle))::numeric,1::numeric)
						OR  
					cos2::numeric <@ numrange(-1::numeric,-cos(radians(min_angle))::numeric) 
					THEN
						RAISE NOTICE 'angle is too flat (% degrees), we consider it flat.
						Value not flat : between % and % (resp -) 
						Output is then a linestring with points on each segment at radius of the intersection, plus the intersection ',degrees(acos(cos2)),min_angle,180-min_angle;

						--we want to return a linestring with extremities on both segments joining_seg1 at circle_radius distance of of intersection, plus intersection point between it.

						--we want to find the points on seg1 and seg2 which are at circle_radius distance of the intersection point
						--compute total length of seg1
							calc := geom_length[1];
							IF s1_fp =1 
							THEN --case when the intersection point is at the beginning of the linestring
								temp_points[1] := ST_Line_Interpolate_Point(seg1, circle_radius/calc);
							ELSE--intersection is at the end
								temp_points[1] := ST_Line_Interpolate_Point(seg1, 1-circle_radius/calc);
							END IF;

							calc := geom_length[2];
							IF s2_fp =1 
							THEN --case when the intersection point is at the beginning of the linestring
								temp_points[3] := ST_Line_Interpolate_Point(seg2, circle_radius/calc);
							ELSE--intersection is at the end
								temp_points[3] := ST_Line_Interpolate_Point(seg2, 1-circle_radius/calc);
							END IF;

							temp_points[2]:=intersection;

							RAISE NOTICE 'new line : %',ST_AsText(ST_MakeLine(temp_points));

						RETURN ST_MakeLine(temp_points);
					END IF ;
					--RAISE NOTICE 'angle is too flat (% degrees), we consider it flat',degrees(acos(cos2));
					

				

				RETURN ST_GeomFromtext('POINT(0 0)');
			END;
			$BODY$
			LANGUAGE plpgsql VOLATILE;
			--test
				--getting_geometry of 2 segments from road_d

				WITH input_seg1 AS (
					SELECT id, gid, ST_GeometryN(geom,1) AS geom 
					--ST_GeomFromText('LINESTRING(650834.5 6860990.6 ,650835.6 6860995.2 ,650840.3 6861006.3)') AS geom
					--ST_GeomFromText('LINESTRING EMPTY') AS geom
					--ST_GeomFromText('POINT(650840.3 6861006.3)') AS geom
					---LINESTRING ZM (650834.5 6860990.6 42.1 0,650835.6 6860995.2 42.1 0,650840.3 6861006.3 42.1 0)
					from route_d
					WHERE gid_topo = 13
				),
				 input_seg2 AS (
					SELECT id, gid, ST_GeometryN(geom,1) AS geom 
					--ST_GeomFromText('LINESTRING(650703.8 6860951.2 ,650747.1 6860969.2 ,650787.8 6860980.2 ,650834.5 6860990.6 )') AS geom
					--ST_GeomFromText('POINT(650840.3 6861006.3)') AS geom
					--ST_GeomFromText('LINESTRING EMPTY') AS geom
					---LINESTRING ZM (650703.8 6860951.2 43 0,650747.1 6860969.2 43.4 0,650787.8 6860980.2 43.5 0,650834.5 6860990.6 42.1 0)
					from route_d
					WHERE gid_topo =37
				)
				--SELECT ST_AsText(i1.geom),ST_AsText(i2.geom)
				--from input_seg1 AS i1, input_seg2 AS i2
				
				SELECT ST_AsText(rc_arc_between_segments(
					i1.geom  --segment1 geometry
					,i2.geom --segment2 geometry
					, 10 --circle_radius float
					, 80 --min_angle double 
					))
				from input_seg1 AS i1, input_seg2 AS i2;




				