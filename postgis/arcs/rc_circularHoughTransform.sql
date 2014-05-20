





DROP FUNCTION IF EXISTS rc_lineToCurve(igeom geometry, precision_center FLOAT ,min_support_points INT);
CREATE OR REPLACE FUNCTION rc_lineToCurve(igeom geometry, precision_center FLOAT ,min_support_points INT)
RETURNS SETOF geometry AS
$BODY$
		--NOTE : replace by appropriate plr or c function (or python) 
		-- @param : the input geometry:  a line where we want to detect the curves
		-- @param :  we deal with non exact computing, the tolerance is then usefull . Expressed as the % of vairation of radius we allow
		-- @param :  we deal with non exact computing, the cneter of circle is of precision limited (snapped ot grid) 
		DECLARE  
			r record;
			P1 geometry := NULL;
			P2 geometry := NULL;
			P3 geometry := NULL;
			c_t geometry; 
			_q TEXT;
		BEGIN 	
			--break the line into ordered points
			--for each triplet of points, find the associated circle and radius, approximated to tolerance

			
			 _q:=format(' WITH the_geom AS (
					SELECT ''%s''::geometry AS geom ,%s AS precision_center,%s AS min_support_points
				  )',igeom, precision_center,min_support_points );  
				   _q:= _q||
					' ,the_dmp AS (
					SELECT the_geom.geom AS total_geom, dmp.* ,precision_center,min_support_points
					FROM the_geom,ST_DumpPoints(geom) AS dmp
					)
					,geom_array AS (
						SELECT array_agg(geom ORDER BY path ASC) AS geom_a
							,min(precision_center) AS precision_center,min(min_support_points) AS min_support_points
						FROM the_dmp
					)
					,hough_t AS (
					SELECT path, geom, rc_circular_hough_transform (ST_Collect(ARRAY[geom,lead(geom,1) OVER(),lead(geom,2) OVER() ])   ,precision_center)as c
						,precision_center,min_support_points
					FROM the_dmp
					)
					,rounded AS (
					SELECT *, ST_X(c) AS cx , ST_Y(c) AS cy , (ST_M(c)/precision_center)::int*precision_center AS cr 
						 
					FROM hough_t 
					)
					 ,grouped AS(
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
					,u_geom AS (
					SELECT min, max, paths, geoms, n_point_support, cx,cy,cr
						, CASE WHEN n_point_support <min_support_points --simple line or point alone : take all the points, plus the previous plus the next
							THEN ST_MakeLine(geom_a[min[1]-1:max[1]+1])
							ELSE rc_makearc(geoms[1],geoms[2],geoms[array_length(geoms, 1)])
							END AS u_geom
					FROM grouped, geom_array
					)
					SELECT ST_Collect(array_agg(u_geom  ORDER BY paths ASC) ) AS geom 
					FROM u_geom  ;
					';
					
					
			RAISE NOTICE '%',_q;
			RETURN QUERY  EXECUTE _q ;
			RETURN ;
			
		END ;
			 
		$BODY$
  LANGUAGE plpgsql VOLATILE;

	

  WITH the_geom AS (
		SELECT ST_GeomFromtext('LINESTRING(59.3284793654691 -92.3066129775187,59.3592265283412 -92.1166343765165,59.4062661708734 -91.7724450185337,59.4448158296321 -91.4272016754727,59.4748521246101 -91.081113734189,59.4963568390758 -90.7343910937775,59.5093169306213 -90.3872440382732,59.5137245390724 -90.0398831091144,59.5095769912558 -89.6925189774527,59.4968768026205 -89.3453623163803,59.475631675712 -88.9986236731623,59.4458544955006 -88.6525133415382,59.4075633215676 -88.3072412341836,59.3607813771512 -87.9630167553987,59.3055370350627 -87.6200486741064,59.2418638004783 -87.2785449972362,59.1698002906185 -86.938712843571,59.0893902113273 -86.6007583181293,59.0006823305648 -86.2648863871663,58.90373044883 -85.9313007538632,58.7985933665314 -85.6002037347826,58.6853348483249 -85.2717961371669,58.5640235844411 -84.9462771371482,58.4347331490259 -84.6238441589524,58.2975419555174 -84.3046927551611,58.1525332090901 -83.9890164881125,57.9997948561906 -83.6770068125063,57.8394195312001 -83.3688529592899,57.671504500251 -83.0647418208888,57.4961516022374 -82.7648578378612,57.3134671870504 -82.4693828870352,57.1235620510763 -82.1784961712005,56.9265513700025 -81.8923741104274,56.7225546289621 -81.6111902350664,56.5116955500683 -81.3351150805047,56.2941020173779 -81.0643160837384,56.0699059993316 -80.798957481824,55.8392434687138 -80.5392002122675,55.6022543201907 -80.2852018154218,55.3590822854606 -80.0371163389351,55.1098748460862 -79.7950942443265)')AS geom
		,0.1 AS precision_center, 3 AS min_support_points
	  )
	  SELECT result.*, ST_AsText(result)
	  FROM the_geom, rc_lineToCurve(geom, precision_center   ,min_support_points  ) as result;
 


  


DROP FUNCTION IF EXISTS rc_circular_hough_transform ( igeom GEOMETRY , the_precision FLOAT  );
CREATE OR REPLACE FUNCTION rc_circular_hough_transform( igeom GEOMETRY ,  the_precision FLOAT )
  RETURNS GEOMETRY AS 
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
		
		BEGIN 	

			--given 3 points, compute the circle that passes trough the 3 points.
			--first check that this is not degenerate
			IF ST_DWIthin(P1,P2, the_precision) OR  ST_DWIthin(P2,P3, the_precision) OR ST_DWIthin(P1,P3, the_precision)
			THEN 
				RAISE WARNING 'error: 3 points form a degenerate case : P1 :%,P2 : %, P3 : % ', ST_AsText(P1), ST_AsText(P2),ST_AsText(P3);
				RETURN NULL;
			END IF;

			den:=ARRAY[ST_X(P1),ST_X(P2),ST_X(P3)  , ST_Y(P1),ST_Y(P2),ST_Y(P3)  ,1,1,1];
			
			expx:= ARRAY[  ST_X(P1)^2+ST_Y(P1)^2 , ST_X(P2)^2+ST_Y(P2)^2,  ST_X(P3)^2+ST_Y(P3)^2 ,              ST_Y(P1),ST_Y(P2),ST_Y(P3) ,       1,1,1  ];
			expy:= ARRAY[  ST_X(P1),ST_X(P2),ST_X(P3)                  , ST_X(P1)^2+ST_Y(P1)^2 , ST_X(P2)^2+ST_Y(P2)^2,  ST_X(P3)^2+ST_Y(P3)^2 ,       1,1,1  ];

			PX:= rc_determinant3x3(expx)/(2*rc_determinant3x3(den));
			PY:= rc_determinant3x3(expy)/(2*rc_determinant3x3(den));

			PR :=    sqrt((ST_X(P1)-PX)^2+(ST_Y(P1)-PY)^2);
			
			RETURN   ST_MakePointM(PX,PY,PR);
			
		END ;
			 
		$BODY$
  LANGUAGE plpgsql VOLATILE;



  WITH the_geom AS (
	SELECT ST_GeomFromtext('MULTIPOINT(0 3 , 2 2 , 3 0)')AS geom
  )
  SELECT ST_Astext(rc_circular_hough_transform(geom,0.01 ))
  FROM the_geom;

 


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

  
