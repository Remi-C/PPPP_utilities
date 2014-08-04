-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--
--variable radius buffer
------------------------------


DROP FUNCTION IF EXISTS public.rc_variableBuffer(i_geom geometry,signe int, TEXT );
		CREATE FUNCTION public.rc_variableBuffer(i_geom geometry ,signe int,style TEXT DEFAULT '', OUT buffered_geom geometry)
			RETURNS geometry AS
		$BODY$
			--@brief this function computes a variable buffer given a geometry and a raidus in M dimension of each point
			--@parameter : the geometry to be buffered, each point must have a M coordinate indicating the radius
			--@parameter : the signe determinate if this is dilatation or erosion. + 1 = dilation, -1 = erosion
			--@parameter : stlyle : same kind of style that the buffer function. Only endcap=flat allowed. 
			--@return a geometry resulting of a varibale buffer on each point, plus interpolated buffer for line between points
			--@WARNING : only dilatation , doesn't do erosion
			--@WARNING : very naive implementation.
			--Idea from Mathieu B.
			DECLARE  
			 segs geometry;
			 q text; 
			style_ar text[];
			_endcap text;
			i INT;
			BEGIN

			--trying to figgure what 's in the string arg :
			IF style IS NOT NULL AND style !='' THEN
				style_ar :=   regexp_split_to_array(regexp_replace(style,'\\s+',''),'[,=]'); --removing whitespace, cutting by = and ,
				FOR i in 1 .. (array_length(style_ar ,1)-1)  BY 2
					LOOP
					IF style_ar[i] ILIKE 'endcap' THEN _endcap :=  style_ar[i+1]; END IF;
					END LOOP; 
			END IF ; 
			
				q:='WITH the_geom AS (
					SELECT $1 AS geom
				), dump AS (
					SELECT DISTINCT dmp.*
					FROM   the_geom AS tg, rc_DumpSegments(tg.geom ) AS dmp
				)
				,trapezoid AS (
				SELECT ST_SetSRID(rc_py_seg_to_trapezoid(ST_Force2D(geom), ST_M(ST_StartPoint(geom)),ST_M(ST_EndPoint(geom))),ST_SRID(geom)  )AS geom
				FROM dump
				)
				,pts_and_radius AS (
				SELECT (ST_DumpPoints(tg.geom)).geom  
				FROM the_geom AS tg
				)
				,buf_pts AS (
				SELECT ST_Buffer(geom,ST_M(geom)) AS geom
				FROM pts_and_radius
				)
				,all_geom AS (
					SELECT ST_Union(geom) as geom
					FROM (

					'; 
				IF _endcap NOT ILIKE 'flat' THEN --we don't need flat end , so we put to result the buffered points
					q:=q||'
						SELECT geom
						FROM buf_pts
						UNION ALL 
					' ; END IF ;
				q:=q||
					'
						SELECT geom
						FROM trapezoid';
					
				IF signe >= 0 THEN 
					q:= q ||'
						UNION ALL
						SELECT geom
						FROM the_geom
						) as sub
					)
					--,unioned_geom AS (
					SELECT ST_CollectionExtract( geom ,3) AS geom --INTO buffered_geom
					--SELECT ST_Difference(tg.geom, ug.geom) AS geom --case whendoing a erosion 
					FROM all_geom;';
				ELSE
					q:= q||'
						)AS sub
					)
					SELECT ST_Difference(tg.geom, ag.geom ) AS geom
					FROM the_geom AS tg, all_geom AS ag;';
				END IF;
				--RAISE EXCEPTION '%',q ;
				EXECUTE q INTO buffered_geom USING i_geom,signe ;
			return  ;
			END ;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE;

	---testing
	SELECT ST_AsText(rc_variableBuffer(geom ,+1,'endcap=flat,quadseg=12'))
	FROM ST_GeomFromtext('LINESTRINGM(0 0 1, 10 0 2, 20 20 3 )') AS geom;

	SELECT ST_AsText(rc_variableBuffer(geom ,-1))
	FROM ST_GeomFromtext('POLYGONM((0 0 1, 10 0 2, 10 10 3, 0 0 1 ))') AS geom;


	

/*
	with the_geom AS (
	SELECT ST_GeomFromtext('LINESTRING(0 0 , 10 0 , 20 20, 20 5, 5 10 )') AS geom, ARRAY[1,2,3,4,5] AS radiuses
	)
	,dump AS (
		SELECT DISTINCT radiuses,row_number() over() AS id,  dmp.*
		FROM the_geom as g, rc_DumpSegments(geom ) AS dmp
	)
	,trapezoid AS (
	SELECT rc_py_seg_to_trapezoid(geom, radiuses[id],radiuses[id+1]) AS geom
	FROM dump
	)
	,pts_and_radius AS (
	SELECT (ST_DumpPoints(geom)).geom, unnest(radiuses) AS radius
	FROM the_geom
	)
	,buf_pts AS (
	SELECT ST_Buffer(geom,radius) AS geom
	FROM pts_and_radius
	)
	,all_geom AS (
	SELECT geom
	FROM buf_pts
	UNION ALL 
	SELECT geom
	FROM trapezoid
	)
	,unioned_geom AS (
	SELECT ST_union(geom) AS geom
	FROM all_geom
	)
	,result AS (
	
		--SELECT ST_Difference(tg.geom, ug.geom) AS geom --case whendoing a erosion
		SELECT ST_Union(tg.geom, ug.geom) AS geom --case whendoing a dilatation
		FROM the_geom AS tg, unioned_geom AS ug
	)
	SELECT ST_Astext(geom)
	FROM result ;


	 
	--SELECT St_AsText(ST_Union(geom, ST_Translate(geom, 5 ,-6 )))
	--FROM ST_GeomFromtext('LINESTRING M (0 0 1, 10 0 2, 20 20 3, 20 5 4, 5 10 5)') AS geom ;

 */
 