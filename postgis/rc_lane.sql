---------------------------------------------
--Copyright Remi-C Thales & IGN , Terra Mobilita Project, 2014
--
----------------------------------------------
-- generating lanes on a road axis
--
--
-- This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--
-- we work on table "route", which contains all the road network in Ile De France and many attributes. It is provided by IGN
--
-------------------------------------------- 

/*

	DROP FUNCTION IF EXISTS public.rc_createLane(chaussee_geom geometry, chaussee_axis geometry, lane_number integer,lane_width float,snapping_precison float,buffer_opt text);
	CREATE OR REPLACE FUNCTION public.rc_createLane(
		chaussee_geom geometry
		, chaussee_axis geometry
		, lane_number integer
		,lane_width float
		,snapping_precison float
		,buffer_opt text)
	  RETURNS TABLE (lane geometry, lane_position integer) AS
	$BODY$
	--this function creates lane geometry based on the chausse geometry and the number of lane to create.
	--Hypothesis are that lane are "symmetric" and of same size, and that lanes form a spatial arrangemnt of chaussee
	--we add snâpping to avoid numerical errors
	DECLARE 
	Vi geometry;
	Vinit geometry;
	i_init integer = lane_number%2; 
	i integer = i_init;
	Di geometry;
	Di_2 geometry;
	BEGIN 	
		
		IF ST_IsValid(chaussee_geom) = FALSE
		THEN	--bad news : we cannot work with bad geometry, issuing warning
			RAISE NOTICE 'You have given a wrong geometry, please see above message for correction';
			lane := NULL; lane_position := NULL;
			RETURN NEXT ;
			RETURN ;
		END IF;
		
		IF lane_number <1 
		THEN--there is a mistake in lane number, doing nothing and warning
			RAISE NOTICE 'mistake in number of wanted lane, you said (%), it should be an integer >= 1',lane_number;
			lane := NULL; lane_position := NULL;
			RETURN NEXT ;
			RETURN ;
		ELSIF lane_number=1
		THEN	--easy : lane is chausse, outputting input
			--RAISE NOTICE ' only one lane to make, so no lane to make ! ';
			lane := chaussee_geom; lane_position := lane_number;
			RETURN NEXT ;
			RETURN ;
		END IF;

		----
		--@TODO
		--adding check on lane_width 

			--public.rc_Dilate(geom geometry,radius int,buffer_option:=buffer_opt)
			--c_SymDif(geomA geometry,geomB geometry)
			
		IF lane_number %2 = 1
		THEN --odd case
				-- D1 is a lane : creating this lane
				-- Di-2 <- Buffer (Axe_road, lane_width/2)
				-- L1 <- Di-2
			Di_2 := rc_Dilate(chaussee_axis, lane_width/2,buffer_option:=buffer_opt);
			lane := Di_2; lane_position := 1;
			RETURN NEXT ;

		ELSIF lane_number %2 =0 --this check is not required
		THEN
			-- D0 is the axis 
			-- Di-2 <- Axe_road
			Di_2 :=chaussee_axis ; --rc_Dilate(chaussee_axis, (i_init*lane_width)/2,buffer_option:=buffer_opt);
			
		END IF;

		--trying to unificate things
		FOR i IN (i_init+2)..lane_number BY 2 
		LOOP --looping on the number of lane to make, starting at L2 or L3, because L0 (line) or L1 (a lane) are made at initiation
			--
			--Di<--buffer(Di-2)
			--Li <-- Split(Di by Di-2)
			--Di <-- Di-2
			--RAISE NOTICE 'working on the making of lanes % ',i;

			Di := rc_Dilate(chaussee_axis, lane_width * ( i::float/2)::float,buffer_option:=buffer_opt);
			--lane := rc_SymDif(Di,ST_Snap(Di_2,Di,snapping_precison)) ; lane_position := i;
			lane := rc_SymDif(Di,Di_2) ; lane_position := i;
			----
			--Workaround of bug of symdiff : we have to use ST_Split(geometry input, geometry blade) if Di_2 is a line or multiline
			IF ST_GeometryType(Di_2) ILIKE  '%LineString'
			THEN
				--RAISE NOTICE 'DI_2 is of geometry type :(%) ',ST_GeometryType(Di_2) ;

				SELECT ST_Collect(geom) INTO lane FROM ST_Dump(ST_Split(Di,ST_Snap(Di_2,Di,snapping_precison)));
				
			END IF;
			
				-- RAISE NOTICE 'here is the geom used to symdiff : 
-- 					Inte:%
-- 					Diff:%
-- 					Lane:%
-- 					Di : %
-- 					Di_2 : %',ST_AsText(ST_Intersection(Di,Di_2)),ST_AsText(ST_Difference(Di, Di_2)),St_AsText(lane),ST_AsText(Di), ST_AsText(Di_2);
				Di_2 := Di;
				
			RETURN NEXT ; 
		END LOOP;	
		END; -- required for plpgsql
		$BODY$
	  LANGUAGE plpgsql VOLATILE;



	DROP FUNCTION IF EXISTS public.rc_cleanLane(chaussee_geom geometry, chaussee_axis geometry, lane_number integer,lane_width float,snapping_precison float,buffer_opt text );
	CREATE OR REPLACE FUNCTION public.rc_cleanLane(
		chaussee_geom geometry
		, chaussee_axis geometry
		, lane_number integer
		,lane_width float
		,snapping_precison float
		,buffer_opt text 
		)
		returnS table  ( lane geometry  , lane_position integer ,lane_ordinality INTEGER) 
	  AS
		$BODY$
		--@brief this functioclean the surfaces created by createlane to remove small lanes and create an ordinality
		DECLARE  
		BEGIN 	

			RETURN QUERY
			SELECT DISTINCT ON (lane_position, lane_ordinality) dmp.geom AS lane, f.lane_position, (row_number()over(partition by f.lane_position ORDER BY dmp.path ASC))::int AS lane_ordinality
			FROM rc_createLane(chaussee_geom  , chaussee_axis , lane_number ,lane_width ,snapping_precison ,buffer_opt  ) AS f
				,st_dump(f.lane) AS dmp 
			WHERE ST_Area(dmp.geom)>0.1 ;
		 
		END; -- required for plpgsql
		$BODY$
	LANGUAGE plpgsql VOLATILE;


	DROP FUNCTION IF EXISTS public.rc_groupLane(chaussee_geom geometry, chaussee_axis geometry, lane_number integer,lane_width float,snapping_precison float,buffer_opt text,OUT lane geometry(multipolygon)
		,OUT lane_position integer[]);
	CREATE OR REPLACE FUNCTION public.rc_groupLane(
		chaussee_geom geometry
		, chaussee_axis geometry
		, lane_number integer
		,lane_width float
		,snapping_precison float
		,buffer_opt text
		,OUT lanes geometry(multipolygon)
		,OUT lane_positions integer[]
		)
	  AS
		$BODY$
		--this functionregroup the lanes created into one row
		DECLARE  
		BEGIN 	
			SELECT ST_CollectionExtract(ST_Collect(lane),3), array_agg(lane_position) INTO lanes, lane_positions
			FROM rc_createLane(chaussee_geom  , chaussee_axis , lane_number ,lane_width ,snapping_precison ,buffer_opt  )
			GROUP BY TRUE ; 
		 
		END; -- required for plpgsql
		$BODY$
	LANGUAGE plpgsql VOLATILE;
 

	 DROP FUNCTION IF EXISTS public.rc_Dilate(geometry, float, text ,int);
	CREATE OR REPLACE FUNCTION public.rc_Dilate(geom geometry,radius float, buffer_option text DEFAULT 'quad_segs=4',srid int DEFAULT 931008)
	  RETURNS geometry AS
	$BODY$
	--this function is a wrapper around ST_Buffer 
	-- st_buffersyntax  quad_segs=#,endcap=round|flat|square,join=round|mitre|bevel,mitre_limit=#.# 
	DECLARE
	BEGIN
		IF srid = 931008 THEN 
			RETURN ST_Buffer(geom,radius ,buffer_option) ;
		ELSE 
			RETURN ST_SetSRID(ST_Buffer(geom,radius ,buffer_option),srid);
		END IF;
	END;
	$BODY$
	LANGUAGE plpgsql VOLATILE;
	----test
	--SELECT ST_AsText(rc_Dilate(ST_GeomFromText('LINESTRING(650814.2 6861324.8 ,650807.6 6861313)'),9))
		DROP TABLE IF EXISTS public.test_dilate;
		CREATE TABLE public.test_dilate AS
		SELECT 1 AS id, 
			public.rc_Dilate(
				ST_GeomFromText('LINESTRING(650814.2 6861324.8 ,650807.6 6861313,650750.3 6861219.1 )'),
				9);



	DROP FUNCTION IF EXISTS public.rc_SymDif(geometry, geometry);
	CREATE OR REPLACE FUNCTION public.rc_SymDif(geomA geometry,geomB geometry)
	  RETURNS geometry AS
	$BODY$
	--this function is a wrapper around ST_SymDifference(geometry geomA, geometry geomB);
	DECLARE
	BEGIN
		RETURN ST_SymDifference(geomA,geomB);
	END;
	$BODY$
	LANGUAGE plpgsql VOLATILE; 
	----test
	--
	DROP TABLE IF EXISTS public.test_symdif;
	CREATE TABLE public.test_symdif AS
	SELECT 1 AS id,  rc_SymDif(rc_Dilate(ST_GeomFromText('LINESTRING(650814.2 6861324.8 ,650807.6 6861313,650750.3 6861219.1 )'),9) ,public.rc_Dilate(ST_GeomFromText('LINESTRING(650814.2 6861324.8 ,650807.6 6861313,650750.3 6861219.1 )'),5)) AS geom;



*/









	
	DROP FUNCTION IF EXISTS public.rc_generate_lane_marking(  road_axis geometry(LINESTRING), lane_number integer,lane_width float );
	CREATE OR REPLACE FUNCTION public.rc_generate_lane_marking(
		road_axis geometry(LINESTRING), lane_number integer,lane_width float)
	  RETURNS TABLE (lane_separator geometry,  lane_position integer,  lane_side TEXT, lane_center_axe GEOMETRY(linestring)) AS
	$BODY$
	--this function compute the markings separating the lane as well as lane center axe
	--Hypothesis are that lane are "symmetric" and of same size, and that lanes form a spatial arrangemnt of chaussee 
	DECLARE  
	i_init integer = lane_number%2; 
	i integer = i_init; 
	temp_left_axis geometry(linestring);
	temp_right_axis geometry(linestring);
	temp_left_separator geometry(linestring);
	temp_right_separator geometry(linestring); 
	BEGIN 	

		
		IF lane_number <1 
		THEN--there is a mistake in lane number, doing nothing and warning
			RAISE NOTICE 'mistake in number of wanted lane, you said (%), it should be an integer >= 1',lane_number; 
			RETURN ;
		ELSIF lane_number=1
		THEN	--easy : nothing to do 
			--RAISE NOTICE ' only one lane to make, so no lane to make ! ';
			lane_separator := NULL; lane_position := 1;lane_side := 'center' ;lane_center_axe := road_axis ;
			RETURN NEXT ;
			RETURN ;
		ELSIF lane_number = 2
		THEN 
			lane_separator := road_axis; lane_position := 2;lane_side := 'left' ;lane_center_axe := ST_OffsetCurve(road_axis,lane_width/2) ;
			RETURN NEXT ;
			lane_separator := road_axis; lane_position := 2;lane_side := 'right' ;lane_center_axe := ST_OffsetCurve(road_axis,-lane_width/2) ;
			RETURN NEXT ;
			RETURN;
		END IF;
 
 
		 
		IF lane_number %2 = 1
		THEN --odd case
				-- D1 is a lane : creating this lane
				-- Di-2 <- Buffer (Axe_road, lane_width/2)
				-- L1 <- Di-2
			temp_left_axis:= road_axis;
			temp_right_axis:=ST_Reverse(road_axis);
			temp_left_separator := ST_OffsetCurve(road_axis,lane_width/2) ;
			temp_right_separator := ST_OffsetCurve(road_axis ,-lane_width/2) ;

			lane_separator := NULL; lane_position := 1;lane_side := 'center' ;lane_center_axe := temp_left_axis  ; 
			RETURN NEXT;
			temp_left_axis := ST_OffsetCurve(temp_left_axis, lane_width); 
			temp_right_axis := ST_OffsetCurve(temp_right_axis,lane_width );
		ELSIF lane_number %2 =0 --this check is not required
		THEN
			temp_left_axis :=  ST_OffsetCurve(road_axis,lane_width/2) ;
			temp_right_axis :=  ST_OffsetCurve( road_axis ,-lane_width/2) ; 
			temp_left_separator :=road_axis;
			temp_right_separator := ST_Reverse(road_axis);

			
				--lane_separator:= temp_left_separator ; lane_position:=  2;  lane_side := 'left' ;lane_center_axe:= temp_left_axis  ; RETURN NEXT ;
				--lane_separator:= temp_right_separator ; lane_position:=  2;  lane_side := 'right' ;lane_center_axe:= temp_right_axis  ; RETURN NEXT ;
				  
		END IF;

		-- --trying to unificate things
		FOR i IN (i_init+2)..lane_number  BY 2 
		LOOP --looping on the number of lane to make, starting at L2 or L3, because L0 (line) or L1 (a lane) are made at initiation
			RAISE NOTICE 'i : %',i;
			
			
			
			lane_separator:=temp_left_separator   ; lane_position:= i ;  lane_side:= 'left'  ;    lane_center_axe:= temp_left_axis    ;
			RETURN NEXT ;
			 
			lane_separator:=temp_right_separator  ;  lane_position:= i  ;   lane_side:= 'right' ;   lane_center_axe:= temp_right_axis    ;
			RETURN NEXT ;
			 
			temp_left_axis := ST_OffsetCurve(temp_left_axis, lane_width); --((i%2)*2-1)*lane_width) ;
			temp_left_separator := ST_OffsetCurve(  temp_left_separator  , lane_width) ; --  ((i%2)*2-1) * lane_width) ; 
			temp_right_axis := ST_OffsetCurve(temp_right_axis,lane_width ); --(((i%2)=1)::int*2-1)*lane_width) ;
			temp_right_separator := ST_OffsetCurve(temp_right_separator,lane_width) ; --(((i%2)=1)::int*2-1)*lane_width) ;
		END LOOP;	
		RETURN;	 
		END; -- required for plpgsql
		$BODY$
	  LANGUAGE plpgsql IMMUTABLE STRICT;
	
	DROP TABLE IF EXISTS public.temp_test_lane; 
	CREATE TABLE  public.temp_test_lane AS 
	SELECT  row_number() over() as gid, lane_separator  as lane_separator , lane_position, lane_side,  lane_center_axe  as lane_center_axe
	FROM  public.rc_generate_lane_marking(
			road_axis:= ST_GeomFromText('Linestring(0 0, 10 0 , 20  0)')
			, lane_number:=4
			,lane_width:=2.2)
	


			