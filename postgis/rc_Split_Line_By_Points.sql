---------------------------------------------
-- Remi-C Thales & IGN , Terra Mobilita Project, 2014
--
----------------------------------------------
--Splitting (multi)linestring with (multi) points without precision error.
--
--
-- This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--
-------------
--dependecies
--rc_DumpLines
--------------------------------------------


DROP FUNCTION IF EXISTS rc_split_Simple_line_by_Ordered_Curvilinear_Abscissa( GEOMETRY_DUMP,FLOAT[],FLOAT);
CREATE OR REPLACE FUNCTION rc_split_Simple_line_by_Ordered_Curvilinear_Abscissa(
	input_gdumpline GEOMETRY_DUMP
	,input_CurvAbs FLOAT[]
	,tolerance FLOAT
	)
  RETURNS SETOF geometry_dump AS
$BODY$
	--Splitting a simplelinsetring with ordered curvilinear absiss, taking into account a tolerance, returning a meaningfull path
	--@param : a simple linestring in a  geometry dump
	--@param : an array with ascending curvilinear absissa corresponding to the wanted cut points on the line
	--@param : this tolerance parameter gives the min distances under which 2 points are considered to be one
	--@return : a geometry dump with cut lines (at curvilinear absissa) and meaningfull path

	--WARNING : no check on inputs, it should already have been made.

	--pseudo code
				--taking care of precision on CurvAbs array
					--add 0 and 1 to the CurvAbs array if not already there
					--construct a new array removing too close CurvAbs accordig to tolerance parameter
				--cuting
					--for each curvabs, 
						--create  a new line  oing from array[i-1] to array[i] curv abs
				--take care of path 
				--return result
	DECLARE 
	res FLOAT[] ;
	i INT;
	j INT;
	temp_f FLOAT ;
	tolerance_in_CurvAbs FLOAT;
	srid int := ST_SRID((input_gdumpline).geom);
		BEGIN

		--taking care of precision on CurvAbs array
			--add 0 and 1 to the CurvAbs array if not already there
			IF(input_CurvAbs[1]!=0) 
			THEN
				SELECT array_prepend(0::float, input_CurvAbs) INTO input_CurvAbs ;
			END IF;
			IF(input_CurvAbs[array_length(input_CurvAbs,1)]!=1) THEN
				SELECT array_append( input_CurvAbs,1::float) INTO input_CurvAbs;
			END IF;

			
			--construct a new array removing too close CurvAbs according to tolerance parameter
				--transposing the tolerance into CurvAbs
				tolerance_in_CurvAbs := LEAST(1,tolerance/ST_Length((input_gdumpline).geom));
			--RAISE NOTICE 'array :% ,  tolerance_in_CurvAbs : %'  ,input_CurvAbs,tolerance_in_CurvAbs;
				--building the new array without values too close
					--adding 0 to result 
						res:= array_append(res,0::FLOAT);
						j:=1;
					--looping : adding values if they are not too close to a previous result or to 1 
					FOREACH temp_f IN ARRAY input_CurvAbs
						LOOP
							--RAISE NOTICE 'in the loop % % %',temp_f,res,j;
							IF ABS(temp_f-res[j])<tolerance_in_CurvAbs OR  ABS(1-temp_f)<tolerance_in_CurvAbs THEN --needing to skip the value before its too close to previous or to 1
								CONTINUE;
							ELSE --adding the value to result
								j:=j+1;
								res:= array_append(res,temp_f);
							END IF;
						END LOOP;
					--adding 1 to result
					res:= array_append(res,1::FLOAT);
					
				--RAISE NOTICE 'array filtered :%',res;	
			
		--cuting
			--for each curvabs, 
				--create  a new line  going from res[i-1] to res[i] curv abs

				FOR j IN 2..array_length(res,1) LOOP
					RETURN QUERY  SELECT ARRAY[j-1] ,ST_SetSRID( ST_LineSubstring((input_gdumpline).geom,res[j-1],res[j]) ,srid);
				END LOOP;
		--take care of path 
		--return result
		
			RETURN;
			
			--RETURN rc_DumpLines(input_line);
		END ;

--example :
--
$BODY$
 LANGUAGE plpgsql STRICT;

-- WITH toto AS (
--  SELECT rc_split_Simple_line_by_Ordered_Curvilinear_Abscissa(
-- 	input_gdumpline := ST_Dump(ST_GeomFromText('LINESTRING(0 0 , 10 10 ,  10 20)'))
-- 	,input_CurvAbs:= ARRAY[0.8,0.81,0.85,0.9,0.99, 1]
-- 	,tolerance:=0.4
-- 	) AS cutlines
-- 	)
-- 	SELECT (cutlines).path, ST_AsText((cutlines).geom)
-- 	FROM toto;


 

DROP FUNCTION IF EXISTS rc_split_line_by_points( GEOMETRY,GEOMETRY, FLOAT);
CREATE OR REPLACE FUNCTION rc_split_line_by_points(
	input_line GEOMETRY
	,input_points GEOMETRY
	,tolerance FLOAT DEFAULT 1
	)
  RETURNS SETOF geometry_dump AS
$BODY$
	--Splitting (multi)linestring with (multi) points , considering the points are o the line if they are closesr than "tolerance".
	--@param : a (multi)linestring we want to split
	--@param : a (multi) point we want to use to split the line
	--@param : the points are considered to be on the line if closest than this parameter to the line (euclidian distance), default to 1
	--@return : a geometry dump with cut lines along with path so there is no lose of ordering
DECLARE 
		BEGIN

			--pseudo code
				--break multilines into lines and multipoints into point
			RETURN QUERY
				WITH liness AS (
					SELECT  row_number() over() AS line_id, line
					FROM  rc_DumpLines(input_line) AS line
				)
				,pointss AS (
					SELECT point AS point, ST_SRID(input_points) AS srid
					FROM ST_DumpPoints(input_points)AS point
				)
				,curv_abses AS (--list all tuple (line, point) where point is close enough to line, and compute curv_absc for each couple, plus non cut lines
					(SELECT line_id,  line, ST_LineLocatePoint((line).geom,ST_SetSRID((point).geom,srid)) AS curv_abs
						FROM liness , pointss 
						WHERE ST_DWithin((line).geom,ST_SetSRID((point).geom,srid),tolerance)=TRUE
						ORDER BY curv_abs ASC)
					UNION -- adding the line which will not be split, but should be outputed without modification anyway.
					(SELECT line_id, line, 0::float as curv_abs 
					FROM liness)
				)
				,grouped_r AS (--group by line, order by curv_abs asc
					SELECT line_id, line, array_agg(curv_abses.curv_abs) AS CurvAbs
					FROM curv_abses
					GROUP BY line_id,line
				),
				cut_lines AS (
				--split line using the ordered curve abs
					SELECT line_id, (line).path AS lpath, rc_split_Simple_line_by_Ordered_Curvilinear_Abscissa(
						input_gdumpline:=line
						,input_CurvAbs:= CurvAbs
						,tolerance:=tolerance
						) AS cl
					FROM grouped_r
				)
				--fill path and return
				SELECT lpath || (cl).path AS path, (cl).geom AS geom
				FROM cut_lines;	
			RETURN;
		END ;

--example :
-- SELECT result.path , ST_AsText(result.geom)
-- FROM ST_GeomFromText('GEOMETRYCOLLECTION(MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),LINESTRING(789 578, 258 963, 654 789))') AS line
-- 		, ST_GeomFromText('multipoint (5.01 4.99, 15.05 10.04, 74 69, 24.2 24.1)') AS point
-- 		,rc_split_line_by_points(
-- 		input_line:=line
-- 		,input_points:=point
-- 		,tolerance:=4
-- 		) AS result;
--
$BODY$
 LANGUAGE plpgsql STRICT;

--  SELECT result.path , ST_AsText(result.geom)
-- FROM ST_GeomFromText('GEOMETRYCOLLECTION(MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),LINESTRING(789 578, 258 963, 654 789))',932011) AS line
-- 		, ST_GeomFromText('multipoint (5.01 4.99, 15.05 10.04, 74 69, 24.2 24.1)',932011) AS point
-- 		,rc_split_line_by_points(
-- 		input_line:=line
-- 		,input_points:=point
-- 		,tolerance:=4
-- 		) AS result;


--testing the function
-- 	SELECT result.path , ST_AsText(result.geom)
-- FROM ST_GeomFromText('GEOMETRYCOLLECTION(MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),LINESTRING(789 578, 258 963, 654 789))') AS line
-- 		, ST_GeomFromText('multipoint (5.01 4.99, 15.05 10.04, 74 69, 24.2 24.1)') AS point
-- 		,rc_split_line_by_points(
-- 		input_line:=line
-- 		,input_points:=point
-- 		,tolerance:=4
-- 		) AS result;



------------------------------
--remaining of dev
--for historical reasons
------------------------------

/*
--remaining of dev

--testing the breaking into pieces of multi and / or collection
	WITH the_geom AS (
	 SELECT *
	FROM ST_GeomFromText('MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58))') AS line
			, ST_GeomFromText('multipoint (5.01 4.99, 58 98 , 74 69)') AS point )
	,breaking_collection AS (
	SELECT rc_DumpLines(line) AS line, ST_DumpPoints(point)AS point
	FROM the_geom
	)
	SELECT 'the_line', line
	FROM breaking_collection
	UNION 
	SELECT 'the_point', point
	FROM breaking_collection;


--testing the listing of tuples
	WITH the_geom AS (
	 SELECT *
	FROM ST_GeomFromText('MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58))') AS line
			, ST_GeomFromText('multipoint (5.01 4.99, 15.05 10.04, 74 69)') AS point )
	,breaking_collection AS (
	SELECT rc_DumpLines(line) AS line, ST_DumpPoints(point)AS point
	FROM the_geom
	)
	SELECT  line, point, ST_Line_Locate_Point((line).geom,(point).geom) AS curv_abs
	FROM breaking_collection
	WHERE ST_DWithin((line).geom,(point).geom,0.1)=TRUE
	ORDER BY curv_abs ASC;

--testing the grouping of points per line 
	WITH the_geom AS (
	 SELECT *
	FROM ST_GeomFromText('GEOMETRYCOLLECTION(MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),LINESTRING(89 89, 789 689))') AS liness
			, ST_GeomFromText('multipoint (5.01 4.99, 15.05 10.04, 74 69, 24.2 24.1)') AS pointss )
	,liness AS (
		SELECT  row_number() over() AS line_id, line
		FROM the_geom, rc_DumpLines(the_geom.liness) AS line
	)
	,breaking_collection AS (
	SELECT liness.* ,  point
	FROM the_geom,liness ,ST_DumpPoints(pointss)AS point
	)
	,curv_abses AS (
	SELECT line_id,  line, point, ST_LineLocatePoint((line).geom,(point).geom) AS curv_abs
	FROM breaking_collection
	WHERE ST_DWithin((line).geom,(point).geom,0.1)=TRUE --NOTE : we want to keep 0,1 , we will deal with it after AND curv_abs!=0 AND curv_abs !=1 
	ORDER BY curv_abs ASC
	)
	,grouped_r AS (
	SELECT line_id, line, array_agg(point) AS dpoints, array_agg(curv_abses.curv_abs) AS CurvAbs
	FROM curv_abses
	GROUP BY line_id,line
	),
	cut_lines AS (
	SELECT line_id, (line).path AS lpath, rc_split_Simple_line_by_Ordered_Curvilinear_Abscissa(
		input_gdumpline:=line
		,input_CurvAbs:= CurvAbs
		,tolerance:=0.01
		) AS cl
	FROM grouped_r
	)
	SELECT line_id,lpath || (cl).path AS path, ST_AsText((cl).geom)
	FROM cut_lines;
	--ORDER BY line ASC, curv_abses.curv_abs ASC


--testing the full outer join

--testing the grouping of points per line 

*/
/*
	WITH the_geom AS (
	 SELECT *
	FROM ST_GeomFromText('GEOMETRYCOLLECTION(MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),MULTILINESTRING( (0 0 ,10 10 , 20 10 ),(23 23, 58 58)),LINESTRING(89 89, 789 689))',932011) AS liness
			, ST_GeomFromText('multipoint(5.01 4.99, 15.05 10.04, 74 69, 24.2 24.1)',932011) AS pointss )
	,liness AS (
		SELECT  row_number() over() AS line_id, line
		FROM the_geom, rc_DumpLines(the_geom.liness) AS line
	)
	,pointss AS (
	SELECT ST_DumpPoints(pointss)AS point, ST_SRID(pointss) AS srid
	FROM the_geom
	)
	,curv_abses AS (
	(SELECT line_id,  line, ST_LineLocatePoint((line).geom,ST_SetSRID((point).geom,srid)) AS curv_abs
	FROM liness , pointss 
	WHERE ST_DWithin((line).geom,ST_SetSRID((point).geom,srid),0.1)=TRUE --NOTE : we want to keep 0,1 , we will deal with it after AND curv_abs!=0 AND curv_abs !=1 
	ORDER BY curv_abs ASC)
		UNION
	(SELECT line_id, line, 0::float as curv_abs
	FROM liness)
	)
	,grouped_r AS (
	SELECT line_id, line, array_agg(curv_abses.curv_abs) AS CurvAbs
	FROM curv_abses
	GROUP BY line_id,line
	),
	cut_lines AS (
	SELECT line_id, (line).path AS lpath, rc_split_Simple_line_by_Ordered_Curvilinear_Abscissa(
		input_gdumpline:=line
		,input_CurvAbs:= CurvAbs
		,tolerance:=0.01
		) AS cl
	FROM grouped_r
	)
	SELECT line_id,lpath || (cl).path AS path, ST_AsText((cl).geom)
	FROM cut_lines;
	--ORDER BY line ASC, curv_abses.curv_abs ASC
*/
