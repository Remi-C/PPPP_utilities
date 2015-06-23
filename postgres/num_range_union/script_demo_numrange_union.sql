/* *******************************
*Rém C. 06/09/2013
*Thales IGN
*********************************
*Union of time range project
*********************************
*
*This project aims to perform a very simple mathematical task :
*given a number of time ranges, perform the union of it :
*
*Union([1,3],[1,2],[3,6],[9,11],[13,15],[14,16]) = [1,6]U[9,11]U[13,16] 
*
*****************
*The implementation is
* - Create a test table containg time range
* - ordering the test table
* - create a function that iteratively merge (or not) the considered interval with the one before (on sorted interval)
* - create a function that decides if 2 interval should be merged
* - lauch function
*
******************************** */


/*
--__Creating test environnement__

	--Create a test schema for the demo
	CREATE SCHEMA union_intervalles;

	--setting path to avoid préfixing table
	SET search_path TO union_intervalles,public;
	
	--Create table with test data
	DROP TABLE IF EXISTS test_data;
	CREATE TABLE test_data
		( trange numrange );

	--adding some intervals into test table
	INSERT INTO test_data VALUES
 		 ('empty'::numrange),
 		 ('[1,7]'::numrange),
 		 ('[3,4]'::numrange),
 		 ('[5,8]'::numrange),
 		 ('[9,11]'::numrange),
 		 ('[11.5,12.5]'::numrange),
 		 ('[13,15]'::numrange),
 		 ('[14,16]'::numrange),
 		 ('[15,18]'::numrange),
 		 ('[19,22]'::numrange);

	--checking test table content and ordering
	SELECT *
	FROM test_data
	ORDER BY trange ASC;
	

-----------------
-----------------
-----------------
----------------
----------------
--temp test : trying to use as an argument of a function the name of a cte in the query

WITH first_query AS ( SELECT *
	FROM test_data
	ORDER BY trange ASC
)
SELECT *
FROM my_function('first_query'::regclass) f(trange numrange) ;
*/

	DROP FUNCTION IF EXISTS rc_interval_union(data_table regclass) ;
	CREATE OR REPLACE FUNCTION rc_test(data_table regclass) RETURNS setof record
	AS $$
	--test function : to delete
	DECLARE
	the_row record;
	BEGIN
		--read lignes from given table
		FOR the_row in EXECUTE 'SELECT * FROM '||data_table||'ORDER BY trange ASC LIMIT 5 ;'
		LOOP
			RETURN NEXT the_row; -- return current row of SELECT
		END LOOP;
	RETURN;
	END;
	$$ LANGUAGE plpgsql;

 


-----
--Changin approache :
--doing it iteratively :
--

--script of function : ordering the table of interval by aascending :
	--for each line : if it overlaps previous : update previous and delete it, if not, next line.
	 


	DROP FUNCTION IF EXISTS rc_interval_union(data_table text, function_name_for_intersect_decision text,text) ;
	CREATE OR REPLACE FUNCTION rc_interval_union(data_table text, function_name_for_intersect_decision text, function_name_for_merging text) RETURNS boolean
	AS $$
	--this function compute union of intevals, the result being a disjoint union of inteval.
		--this function expects a table with a column "trange" to work on.
		--The algorithm is as follow :
			--fo each line, take following line , if th 2 intersects, line and delete following line, else do nothing.

		--the plpgsql is tricky as we cannot have only one cursor as an updatable cant go backward. SO we use 2 cursors on the same result, on for updating/deleting, one for getting next row value.
	DECLARE
		current_row record;
		next_row record;
		iteration_number integer :=0;
		change_cursor refcursor := 'change_cursor'; --this cursor is used to update/delete row
		read_cursor refcursor := 'read_cursor'; -- this cursor us used to read row (the row next to change_cursor row)
		are_intersecting boolean := false;
	BEGIN

		OPEN change_cursor FOR EXECUTE 'SELECT trange FROM '|| quote_ident(data_table)||' ORDER BY trange ASC FOR UPDATE' ;
		OPEN read_cursor SCROLL FOR EXECUTE 'SELECT trange FROM '|| quote_ident(data_table)||' ORDER BY trange ASC' ;
		
		
			FETCH NEXT FROM change_cursor INTO current_row; --getting current row
			FETCH RELATIVE 2 FROM read_cursor INTO next_row; --getting the 2nd row

			RAISE NOTICE 'beginning values : % %',current_row,next_row;

			
		WHILE ( FOUND != FALSE AND (iteration_number<20) AND next_row IS NOT NULL)
			LOOP 
				iteration_number:=iteration_number+1;
				--cheking : where are we?
					RAISE NOTICE 'number of iteration %',iteration_number;
				
				----
				-- if function_name_for_intersect_decision(c_row,n_row) = TRUE, delete nrow, update crow
					EXECUTE  'SELECT ' || quote_ident(function_name_for_intersect_decision) || '($1,$2) ;' USING current_row.trange, next_row.trange INTO are_intersecting; 	
					IF (are_intersecting = TRUE )--trying for intersection
					THEN --case when current and next row do intersect
						RAISE NOTICE 'Intersection :  % and % overlap, merging it',current_row,next_row;

						--delete current row in change_cursor
						EXECUTE 'DELETE FROM  '|| quote_ident(data_table)|| '  WHERE CURRENT OF '||quote_ident(change_cursor::text)||';';
						--moving forward 1 to update the row with merged interval
						
						EXECUTE 'UPDATE ' || quote_ident(data_table)|| ' SET trange = $1  WHERE CURRENT OF ' ||quote_ident(change_cursor::text)||' '  USING current_row.trange+next_row.trange ; --updating


						MOVE NEXT FROM change_cursor;
						current_row.trange := current_row.trange + next_row.trange;
						FETCH NEXT FROM read_cursor INTO next_row;
						--ready for another loop
					ELSE
						RAISE NOTICE ' % and % don t overlap, doing nothing',current_row,next_row;
						FETCH NEXT FROM change_cursor INTO current_row; --getting current row
						FETCH NEXT FROM read_cursor INTO next_row; --getting the 2nd row
					END IF;
					RAISE NOTICE 'end of loop %, rows : % and %',iteration_number,current_row,next_row;
			END LOOP;	
	  RETURN TRUE;
	END;
	$$ LANGUAGE plpgsql;
		
		--trying the function :
/*	SELECT * FROM rc_interval_union('test_data'::text,'rc_interval_overlap'::text,'toto');
 
	SELECT *
	FROM test_data
	ORDER BY trange ASC;
*/

DROP FUNCTION IF EXISTS rc_interval_overlap(trange1 numrange, trange2 numrange , tolerancy numeric) ;
	CREATE OR REPLACE FUNCTION rc_interval_overlap(trange1 numrange, trange2 numrange, tolerancy numeric DEFAULT 0) RETURNS boolean
	AS $$
	--this function decides if 2 interval should be merged or not
	--you can customize this to allow for small distances, etc etc.
	--Warning : take care of 'empty' case
	--default : same as operator &&
	DECLARE
	 tr_1 numrange;
	 tr_2 numrange;
	BEGIN
	 tr_1 = numrange(lower(trange1)-tolerancy,  upper(trange1)+tolerancy);
	 tr_2 = numrange(lower(trange2)-tolerancy,  upper(trange2)+tolerancy);
	  RETURN tr_1 && tr_2; 
	END;
	$$ LANGUAGE plpgsql;
		
		--trying the function :
	--SELECT * FROM rc_interval_overlap(numrange(1,2), numrange(1.9,5))



DROP FUNCTION IF EXISTS rc_compute_interval_union(data_table_curs refcursor,column_name text, function_name_for_intersect_decision text, text) ;
	CREATE OR REPLACE FUNCTION rc_compute_interval_union(data_table_curs refcursor, column_name text, function_name_for_intersect_decision text, function_name_for_union text) RETURNS setof record
	AS $$
	--this function compute union (mathematically speaking) of intervals, the result being a disjoint union of inteval (postgres speaking).
		--this function expects as input a table with a column containing data. THE COLUMN MUST BE NAMED "trange"
		--the data supplied must be compatible with function_name_for_intersect_decision and function_name_for_intersect_decision
		--the output is a table containing the unioned interval (one intervalle per line)

		--the algorithm is :
			--work sequentially on ordered intervals ASC
			--loop
				--if current row and next row intersect, update union_result
					--else write union_value in result and put it to next_row
				-- go to next row
			-- write union_result in result
			--return result
	DECLARE
		current_row record;
		next_row record;
		union_result record;
		iteration_number integer :=0;
		are_intersecting boolean := false;
	BEGIN
			FETCH NEXT FROM data_table_curs INTO current_row; --getting current row
			FETCH NEXT FROM data_table_curs INTO next_row; --getting the 2nd row
			union_result := current_row;
			--RAISE NOTICE 'beginning values :c_r % n_r % u_r %',current_row,next_row,union_result;

		WHILE ( FOUND != FALSE AND next_row IS NOT NULL) --working till there is work to do
			LOOP 
				iteration_number:=iteration_number+1;
				
				EXECUTE  'SELECT ' || quote_ident(function_name_for_intersect_decision) || '($1,$2) ;' USING union_result.trange, next_row.trange INTO are_intersecting;
				--if current row and next row intersect, update union_result
				IF (are_intersecting = TRUE )--trying for intersection
				THEN --case when union result and next row do intersect
					--RAISE NOTICE 'intersecting,  values :c_r % n_r % u_r %',current_row,next_row,union_result;
					--RAISE NOTICE 'Intersection :  % and % overlap, merging it',union_result,next_row;
					union_result.trange := union_result.trange + next_row.trange;	
				--else write union_value in result and put it to null
				ELSE
					--RAISE NOTICE 'not intersecting :c_r % n_r % u_r %',current_row,next_row,union_result;
					--write union result in result
					--RAISE NOTICE 'writing  u_r %',union_result;
					RETURN NEXT union_result;
					
					--put it to null
					union_result := next_row;
				END IF;

				--go to next row
				current_row := next_row;
				FETCH NEXT FROM data_table_curs INTO next_row; 
				
				--RAISE NOTICE 'end of loop % : c_r % n_r % u_r %',iteration_number,current_row,next_row,union_result;
			END LOOP;
	RETURN NEXT union_result;
	RETURN;
	END;
	$$ LANGUAGE plpgsql;


		
	--trying the function :
	--SELECT * FROM rc_interval_overlap(numrange(1,2), numrange(1.9,5))
	
/*
	BEGIN;
	DECLARE cursor_on_asc_range CURSOR FOR 
		SELECT trange
		FROM test_data
		ORDER BY trange ASC;
	
	SELECT * FROM  rc_compute_interval_union('cursor_on_asc_range'::refcursor,'trange'::text, 'rc_interval_overlap'::text,'toto'::text) f(trange numrange) ;
	CLOSE cursor_on_asc_range;
	END;
*/



DROP FUNCTION IF EXISTS rc_compute_interval_union_simplified(data_table_curs refcursor,column_name text, function_name_for_intersect_decision text, text) ;
	CREATE OR REPLACE FUNCTION rc_compute_interval_union_simplified(data_table_curs refcursor, column_name text, function_name_for_intersect_decision text, function_name_for_union text) RETURNS setof record
	AS $$
	--this function compute union (mathematically speaking) of intervals, the result being a disjoint union of inteval (postgres speaking).
		--this function expects as input a table with a column containing data.
		--the data supplied must be compatible with function_name_for_intersect_decision and function_name_for_intersect_decision
		--the output is a table containing the unioned interval (one intervalle per line)

		--the algorithm is :
			--work sequentially on ordered intervals ASC
			--loop
				--if current row and next row intersect, update union_result
					--else write union_value in result and put it to next_row
				-- go to next row
			-- write union_result in result
			--return result
	DECLARE
		current_row record;
		next_row record;
		union_result record;
		iteration_number integer :=0;
		are_intersecting boolean := false;
	BEGIN
			FETCH NEXT FROM data_table_curs INTO current_row; --getting current row
			FETCH NEXT FROM data_table_curs INTO next_row; --getting the 2nd row
			union_result := current_row;
			--RAISE NOTICE 'beginning values :c_r % n_r % u_r %',current_row,next_row,union_result;

		WHILE ( FOUND != FALSE AND next_row IS NOT NULL) --working till there is work to do
			LOOP 
				--iteration_number:=iteration_number+1;
				
				EXECUTE  'SELECT ' || quote_ident(function_name_for_intersect_decision) || '('||quote_literal(union_result)||'.trange ,'||quote_literal(next_row)||'.trange ) ;'; --USING union_result, next_row INTO are_intersecting;
				--if current row and next row intersect, update union_result
				IF (are_intersecting = TRUE )--trying for intersection
				THEN --case when SEASRunion result and next row do intersect
					--RAISE NOTICE 'intersecting,  values :c_r % n_r % u_r %',current_row,next_row,union_result;
					--RAISE NOTICE 'Intersection :  % and % overlap, merging it',union_result,next_row;
					union_result.column_name := union_result.column_name + next_row.column_name;
					
				--else write union_value in result and put it to null
				ELSE
					--RAISE NOTICE 'not intersecting :c_r % n_r % u_r %',current_row,next_row,union_result;
					--write union result in result
					--RAISE NOTICE 'writing  u_r %',union_result;
					RETURN NEXT union_result;
					
					--put it to null
					union_result := next_row;
				END IF;

				--go to next row
				current_row := next_row;
				FETCH NEXT FROM data_table_curs INTO next_row; 
				
				--RAISE NOTICE 'end of loop % : c_r % n_r % u_r %',iteration_number,current_row,next_row,union_result;
			END LOOP;
	RETURN NEXT union_result;
	RETURN;
	END;
	$$ LANGUAGE plpgsql;
/*
	
	BEGIN;
	DECLARE cursor_on_asc_range CURSOR FOR  
		SELECT numrange(lower(trange)-1,  upper(trange)+1) AS trange
		FROM tmob_20140616.riegl_pcpatch_space
			,rc_compute_range_for_a_patch(patch  , 'gps_time') as trange
		WHERE ST_Intersects(patch::geometry, ST_Transform(ST_GeomFromText('POLYGON((651473 6861179,651465 6861181,651463 6861189,651465 6861197,651473 6861199,651480 6861197,651483 6861189,651480 6861181,651473 6861179))',931008),932012)) = TRUE  
		 ORDER BY trange ASC  ;
		 
	
	SELECT row_number() over() as frange_id,  * FROM  rc_compute_interval_union('cursor_on_asc_range'::refcursor , 'trange'::text ,  'rc_interval_overlap'::text , 'toto'::text) f(trange numrange)  ORDER BY trange ASC;
	CLOSE cursor_on_asc_range;
	END;
*/





DROP FUNCTION IF EXISTS rc_compute_interval_union(data_table_curs refcursor) ;
    CREATE OR REPLACE FUNCTION rc_compute_interval_union(data_table_curs refcursor) RETURNS setof record
    AS $$
    --dummy function with cursor


    DECLARE
        current_row record;
        next_row record;
        union_result record;

        iteration_number integer :=0;

        are_intersecting boolean := false;
    BEGIN
            FETCH NEXT FROM data_table_curs INTO current_row; --getting current row
            FETCH NEXT FROM data_table_curs INTO next_row; --getting the 2nd row
            union_result := current_row;
            RAISE NOTICE 'beginning values :c_r % n_r % u_r %',current_row,next_row,union_result;
            RETURN NEXT union_result;
             union_result := next_row;
               RETURN NEXT union_result;


                
            current_row := next_row;
             FETCH NEXT FROM data_table_curs INTO next_row;
                   
            RAISE NOTICE 'end of loop % : c_r % n_r % u_r %',iteration_number,current_row,next_row,union_result;
    RETURN;

    END;
    $$ LANGUAGE plpgsql;

    /*
BEGIN;
	DECLARE cursor_on_asc_range CURSOR WITH HOLD FOR 
		SELECT trange
		FROM test_data
		ORDER BY trange ASC;
	
	SELECT * FROM  rc_compute_interval_union('cursor_on_asc_range'::refcursor) f(trange numrange) ;
	CLOSE cursor_on_asc_range;
	END;
*/
