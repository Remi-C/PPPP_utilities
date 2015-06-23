-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--detecting arcs in linestring 
------------------------------


DROP FUNCTION IF EXISTS rc_lineToCurve(igeom geometry, precision_center FLOAT ,min_support_points INT);
CREATE OR REPLACE FUNCTION rc_lineToCurve(igeom geometry, precision_center FLOAT ,min_support_points INT DEFAULT 3)
RETURNS SETOF geometry AS
$BODY$
		--NOTE : replace by appropriate plr or c function (or python) 
		-- @param : the input geometry:  a line where we want to detect the curves
		-- @param :  we deal with non exact computing, the tolerance is then usefull .Expressed in unit of map
		-- @param :  minimal number of points suporting a circle to consider it an arc, default to 3
		--@return : a geoemtry collection with line and arcs
		DECLARE   
			_q TEXT;
		BEGIN 	 
			
			 _q:=format(' WITH the_geom AS (
					SELECT ''%s''::geometry AS geom ,%s AS precision_center,%s AS min_support_points
				  )',igeom, precision_center,min_support_points );  
				   _q:= _q||
					' ,the_dmp AS ( --dumping the points , preserving the order into path
					SELECT the_geom.geom AS total_geom, dmp.* ,precision_center,min_support_points
					FROM the_geom,ST_DumpPoints(geom) AS dmp
					)
					,geom_array AS ( --simply an array of all the point ordered according to path. 
						--non optimal, but make it simpler to write the last part
						SELECT array_agg(geom ORDER BY path ASC) AS geom_a
							,min(precision_center) AS precision_center,min(min_support_points) AS min_support_points
						FROM the_dmp
					)
					,hough_t AS ( --for each triplet of point, find what kind of circle passes trough all 3 points
					SELECT path, geom, rc_circular_hough_transform (ST_Collect(ARRAY[geom,lead(geom,1) OVER(),lead(geom,2) OVER() ])   ,precision_center)as c
						,precision_center,min_support_points
					FROM the_dmp
					)
					,rounded AS (--rounding the detected radius of circle acording to user defined parameter
					SELECT *, ST_X(c) AS cx , ST_Y(c) AS cy , (ST_M(c)/precision_center)::int*precision_center AS cr  
					FROM hough_t 
					)
					 ,grouped AS(  --collapsing the list of point into parts with same arc or no arc hypothesis
						SELECT min(path)  ,max(path)
							, array_agg( path[1] ORDER BY path ASC) as paths
							, array_agg(geom ORDER BY path ASC) as geoms 
							,count(*)  as n_point_support
							, avg(cx) as cx,avg(cy) as cy,avg(cr) as cr
						FROM rounded 
						--WHERE cx IS NOT NULL AND cy IS NOT NULL AND cr IS NOT NULL and cr!=0
						GROUP BY ST_SnapToGrid(c ,precision_center) ,cr
						ORDER  BY min
					)
					,u_geom AS ( --making line or arc according to the group made
					SELECT min, max, paths, geoms, n_point_support, cx,cy,cr
						, CASE WHEN n_point_support <min_support_points --simple line or point alone : take all the points, plus the previous plus the next
							THEN ST_MakeLine(geom_a[min[1]-1:max[1]+1])
							ELSE rc_makearc(geoms[1],geoms[2],geoms[array_length(geoms, 1)])
							END AS u_geom
					FROM grouped, geom_array
					)--make a single geometry collection from the previous stuff, preserving order
					SELECT ST_Collect(array_agg(u_geom  ORDER BY paths ASC) ) AS geom 
					FROM u_geom  ;
					';
					
					
			RAISE NOTICE '%',_q;
			RETURN QUERY  EXECUTE _q ;
			RETURN ;
			
		END ;
			 
		$BODY$
  LANGUAGE plpgsql VOLATILE;



DROP FUNCTION IF EXISTS rc_DetectCurveInLine(igeom geometry, _precision_center FLOAT ,_min_support_points INT, max_radius DOUBLE PRECISION );
CREATE OR REPLACE FUNCTION rc_DetectCurveInLine(igeom geometry, _precision_center FLOAT ,_min_support_points INT DEFAULT 3, max_radius DOUBLE PRECISION DEFAULT 2147483646 )
RETURNS TABLE(supporting_points geometry, arc_center geometry, arc_radius double precision, number_of_support int) AS
$BODY$
		--NOTE : replace by appropriate plr or c function (or python) 
		-- @param : the input geometry:  a line where we want to detect the curves
		-- @param :  we deal with non exact computing, the tolerance is then usefull .Expressed in unit of map
		-- @param :  minimal number of points suporting a circle to consider it an arc, default to 3
		--@return : a table : one column with multipoint supporting the arc, the other column with arc center, , the other column with arc radius,, , the other column with number of poitns supporting this arc
		DECLARE   
			_q TEXT;
			_max_int float := 2147483647; 
		BEGIN 	 
			
			RETURN QUERY 
				WITH the_geom AS (
					SELECT igeom AS geom ,CASE WHEN _precision_center>0 THEN _precision_center ELSE 0.00001 END AS precision_center,_min_support_points AS min_support_points
				  )
				  ,the_dmp AS ( --dumping the points , preserving the order into path
					SELECT -- the_geom.geom AS total_geom,
						dmp.* 
					--,ST_AsText(dmp.geom)
					FROM the_geom,ST_DumpPoints(geom) AS dmp
					)
					,geom_array AS ( --simply an array of all the point ordered according to path. 
						--non optimal, but make it simpler to write the last part
						SELECT array_agg(geom ORDER BY path ASC) AS geom_a
							
						FROM the_dmp
					)
					,hough_t AS ( --for each triplet of point, find what kind of circle passes trough all 3 points
						SELECT path, td.geom
							,ST_Astext(ST_Collect(ARRAY[td.geom,lead(td.geom,1) OVER(),lead(td.geom,2) OVER() ]) )
							, rc_circular_hough_transform (ST_Collect(ARRAY[td.geom,lead(td.geom,1) OVER(),lead(td.geom,2) OVER() ])   ,tg.precision_center)as c 
						FROM the_dmp As td, the_geom as tg
					)
					,proper_hough AS (
						SELECT path, h.geom , (c).center AS c,(c).radius as radius 
						FROM hough_t AS h, the_geom AS tg
						WHERE (c).radius IS NOT NULL AND (c).radius < max_radius AND (c).radius >0 AND (c).radius / tg.precision_center <_max_int
					)
					 ,rounded AS (--rounding the detected radius of circle acording to user defined parameter
					SELECT ph.*, ST_X(c) AS cx , ST_Y(c) AS cy 
						, CASE WHEN precision_center   <= 0 THEN  radius ELSE (radius/tg.precision_center)::int*tg.precision_center END AS cr
						--,st_astext(c)
					FROM proper_hough AS ph, the_geom AS tg
					)
					 ,grouped AS(  --collapsing the list of point into parts with same arc or no arc hypothesis
						SELECT min(path)  ,max(path)
							, array_agg( path[1] ORDER BY path ASC) as paths
							, array_agg(r.geom ORDER BY path ASC) as geoms 
							,count(*)  as n_point_support
							, avg(cx) as cx,avg(cy) as cy,avg(cr) as cr
						FROM rounded AS r, the_geom AS tg
						--WHERE cx IS NOT NULL AND cy IS NOT NULL AND cr IS NOT NULL and cr!=0
						GROUP BY ST_SnapToGrid(c ,tg.precision_center) ,cr
						ORDER  BY min
					)
					,u_geom AS ( --making line or arc according to the group made
						SELECT 
							min, max, paths, geoms, n_point_support
							, cx,cy,cr 
							--,  -- rc_makearc(geoms[1],geoms[2],geoms[array_length(geoms, 1)]) AS u_geom
							,ST_Collect(geoms) AS u_geom
						FROM grouped, geom_array, the_geom AS tg
						WHERE n_point_support >tg.min_support_points-2 --translating becaus we implicitly working on triplet of points
						AND cr IS NOT NULL
					)  --dress the output properly to match function return type 
					SELECT u_geom  AS supporting_points 
						,ST_SetSRID(ST_MAkePoint(cx,cy) ,ST_SRID(u_geom)) AS  arc_center 
						, cr AS arc_radius 
						, n_point_support::int +2 AS number_of_support 
						--,st_astext(u_geom)
						--,st_astext(ST_SetSRID(ST_MAkePoint(cx,cy) ,ST_SRID(u_geom)) ) 
					FROM u_geom  ; 
	
					
		 
			RETURN; 
		END ;
			 
		$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT;

	
/*
  WITH the_geom AS (
		SELECT ST_GeomFromtext('LINESTRING(59.3284793654691 -92.3066129775187,59.3592265283412 -92.1166343765165,59.4062661708734 -91.7724450185337,59.4448158296321 -91.4272016754727,59.4748521246101 -91.081113734189,59.4963568390758 -90.7343910937775,59.5093169306213 -90.3872440382732,59.5137245390724 -90.0398831091144,59.5095769912558 -89.6925189774527,59.4968768026205 -89.3453623163803,59.475631675712 -88.9986236731623,59.4458544955006 -88.6525133415382,59.4075633215676 -88.3072412341836,59.3607813771512 -87.9630167553987,59.3055370350627 -87.6200486741064,59.2418638004783 -87.2785449972362,59.1698002906185 -86.938712843571,59.0893902113273 -86.6007583181293,59.0006823305648 -86.2648863871663, 10 10, 11 11 , 34 54, 58.90373044883 -85.9313007538632,58.7985933665314 -85.6002037347826,58.6853348483249 -85.2717961371669,58.5640235844411 -84.9462771371482,58.4347331490259 -84.6238441589524,58.2975419555174 -84.3046927551611,58.1525332090901 -83.9890164881125,57.9997948561906 -83.6770068125063,57.8394195312001 -83.3688529592899,57.671504500251 -83.0647418208888,57.4961516022374 -82.7648578378612,57.3134671870504 -82.4693828870352,57.1235620510763 -82.1784961712005,56.9265513700025 -81.8923741104274,56.7225546289621 -81.6111902350664,56.5116955500683 -81.3351150805047,56.2941020173779 -81.0643160837384,56.0699059993316 -80.798957481824,55.8392434687138 -80.5392002122675,55.6022543201907 -80.2852018154218,55.3590822854606 -80.0371163389351,55.1098748460862 -79.7950942443265)')AS geom
		,0.01 AS precision_center
		, 3 AS min_support_points
	  ) 

	  
	  --SELECT result.* , st_astext(result.supporting_points)
	-- FROM the_geom, rc_DetectCurveInLine( geom, precision_center   ,min_support_points  ) as result;
 */
 
   

DROP FUNCTION IF EXISTS rc_circular_hough_transform ( igeom GEOMETRY , the_precision FLOAT,OUT  center  GEOMETRY, OUT radius double precision  );
CREATE OR REPLACE FUNCTION rc_circular_hough_transform( igeom GEOMETRY ,  the_precision FLOAT,OUT  center GEOMETRY, OUT radius double precision )
 AS 
	$BODY$
		--NOTE : replace by appropriate plr or c function (or python) 
		-- @param : the input geometry:  a multi point with 3 points 
		-- @param :  we deal with non exact computing, hence the precision is a safeguard.  
		-- @return :  a point with the data AS a radius
		DECLARE 
		P1 geometry  = ST_GeometryN(igeom,1);
		P2 geometry  = ST_GeometryN(igeom,2);
		P3 geometry  = ST_GeometryN(igeom,3); 
		PX float;
		PY float;
		PR float;
		expx FLOAT[];
		expy FLOAT[];
		den  FLOAT[];
		tgeom geometry; 
		tx double precision;
		ty double precision ;
		BEGIN 	

			--given 3 points, compute the circle that passes trough the 3 points.
			--translating ot improve robustness against numerical errors :
			WITH the_geom AS (
				SELECT igeom as geom
			)
			,avg AS (
				SELECT avg(ST_X(dmp.geom)) AS avgx, avg(ST_y(dmp.geom)) as avgy
				FROM the_geom, ST_Dump(geom) AS dmp
			)
			SELECT ST_Translate(geom, -avgx, -avgy) , avgx , avgy  INTO tgeom ,tx ,ty 
			FROM  the_geom as tg , avg ;

			P1 := ST_GeometryN(tgeom,1);
			P2 := ST_GeometryN(tgeom,2);
			P3 := ST_GeometryN(tgeom,3); 
			
			
			--first check that this is not degenerate
			 IF ST_DWIthin(P1,P2, the_precision) OR  ST_DWIthin(P2,P3, the_precision) OR ST_DWIthin(P1,P3, the_precision)
			 THEN 
			 	--RAISE NOTICE '  3 points form a degenerate case : P1 :%,P2 : %, P3 : % ', ST_AsText(P1), ST_AsText(P2),ST_AsText(P3);
			 	center := NULL; radius := NULL;
			 	RETURN   ;
			 END IF;

			den:=ARRAY[ST_X(P1),ST_X(P2),ST_X(P3)  , ST_Y(P1),ST_Y(P2),ST_Y(P3)  ,1,1,1];
			
			expx:= ARRAY[  ST_X(P1)^2+ST_Y(P1)^2 , ST_X(P2)^2+ST_Y(P2)^2,  ST_X(P3)^2+ST_Y(P3)^2 ,              ST_Y(P1),ST_Y(P2),ST_Y(P3) ,       1,1,1  ];
			expy:= ARRAY[  ST_X(P1),ST_X(P2),ST_X(P3)                  , ST_X(P1)^2+ST_Y(P1)^2 , ST_X(P2)^2+ST_Y(P2)^2,  ST_X(P3)^2+ST_Y(P3)^2 ,       1,1,1  ];

			IF rc_determinant3x3(den) = 0 THEN
				center := NULL; radius := NULL;
				RETURN;
			END IF; 
			
			PX:= rc_determinant3x3(expx)/(2*rc_determinant3x3(den));
			PY:= rc_determinant3x3(expy)/(2*rc_determinant3x3(den));

			PR :=    sqrt((ST_X(P1)-PX)^2+(ST_Y(P1)-PY)^2);

			center := ST_SetSRID(ST_Translate(ST_MakePoint (PX,PY),tx,ty), ST_SRID(igeom)); radius := PR;
			RETURN;
			
		END ;
			 
		$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT;

/*
	SELECT *, st_astext(center)
	from rc_circular_hough_transform ( ST_GeomFromText('MULTIPOINT( 600.96012  527.12384, 601.2188  527.42177, 601.52278  527.67323)'),0.1)
 
  WITH the_geom AS (
	SELECT ST_GeomFromtext('MULTIPOINT(0 3 , 2 2 , 3 0)')AS geom
  )
  SELECT ST_Astext(rc_circular_hough_transform(geom,0.01 ))
  FROM the_geom;
*/


DROP FUNCTION IF EXISTS rc_determinant3x3 ( c  anyarray  );
CREATE OR REPLACE FUNCTION rc_determinant3x3 ( c anyarray  ) 
  RETURNS anyelement AS 
	$BODY$ 
		-- @param : the input array with the 9 coefficient, in column order 
		-- @return :  the determinant of the array
		--note : replace by appropriate plr or c function !
		DECLARE 
		BEGIN 	 
			RETURN c[1]*c[5]*c[9] + c[4]*c[8]*c[3]+c[7]*c[2]*c[6] -c[1]*c[6]*c[8]- c[2]*c[4]*c[9]-c[3]*c[5]*c[7]; 
		END ;
			 
		$BODY$
  LANGUAGE plpgsql VOLATILE;


