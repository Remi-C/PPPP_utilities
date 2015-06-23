---------------------------------------------
--Copyright Remi-C Thales IGN 5/11/2013
--
--
--function to decompose a number into prime factors
--
--we want to avoid precision issues and int limit, thus using numeric type
--------------------------------------------
-----Script abstract
----------------------------
--	
--	We use a recursive CTE to compute factors, then regroup using arreay agg. Simultaneously, we compute the product of factor to check if this is really equal to input number.
--
--rc_PrimeFactor(a_number numeric, OUT prime_factors numeric[])
--
------dependencies---------
--
--numeric_product_agg(numeric) 
------------------------------------------
	



DROP AGGREGATE IF EXISTS numeric_product_agg(numeric) CASCADE;
CREATE AGGREGATE numeric_product_agg(numeric)
(
   sfunc = numeric_mul,
   stype = numeric,
   INITCOND=1

);

	------------------------------------------------------------------------------
	--------rc_maxArray(an_array anyarray, OUT result anyelement);-----
	--
	--	Utility function : compute the max of all elements in an array
	--
	DROP FUNCTION IF EXISTS rc_maxArray(an_array anyarray, OUT result anyelement);
		CREATE OR REPLACE FUNCTION rc_maxArray(an_array anyarray, OUT result anyelement)
		AS
		$BODY$
			--this function output the max of an array
			--thus, we suppose that max is avalaibable for what is inside the array
			
			DECLARE
			
			BEGIN
				SELECT into result 
					max(x)
				FROM unnest(an_array) AS x
				LIMIT 1;
				RETURN ;
			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;

		 -- SELECT rc_maxArray( ARRAY[1.4,2,3,2,1]);



		---------------------------------------------------------
		--Function computing prime factors
		---------------------------------------------------------
		--	adapted from BRUCE MOMJIAN, 2012, Programming the SQL Way with Common Table Expressions
		--
		--
		--
		DROP FUNCTION IF EXISTS rc_PrimeFactor(a_number numeric, OUT prime_factors numeric[]);
		CREATE OR REPLACE FUNCTION rc_PrimeFactor(a_number numeric, OUT prime_factors numeric[])
		AS
		$BODY$
			--this function output the prime factors of the given number, by ascending order, a prmie factor being outputted n times if needed.
			
			DECLARE
			_q text;
			BEGIN

				--note : subotpimal : maybe could try not to cast to text?
				_q:= format('
				WITH RECURSIVE source (counter, factor, is_factor) AS (
						SELECT 2::numeric, %s ::numeric, false
					UNION ALL
						SELECT
							CASE
								WHEN factor %% counter = 0 THEN counter
								-- is ’factor’ prime?
								WHEN counter * counter > factor THEN factor
								-- now only odd numbers
								WHEN counter = 2 THEN 3
								ELSE counter + 2
								END,
							CASE
								WHEN factor %% counter = 0 THEN factor / counter
								ELSE factor
								END,
							CASE
								WHEN factor %% counter = 0 THEN true
								ELSE false
								END
						FROM source
						WHERE factor <> 1
						--AND factor <10
				),
				result AS 
				(
					SELECT *
					FROM source 
					WHERE is_factor=TRUE
				),
				product aS (
					SELECT numeric_product_agg(counter) AS prod
					FROM result
				),
				counter_array AS
				(
					SELECT array_agg(r.counter)
					FROM  result r 
				)
				SELECT ca.* AS prime_factors
				FROM counter_array AS ca, product
				--WHERE prod = %s'
				,a_number,a_number);

				--RAISE NOTICE '%',_q;
				EXECUTE _q INTO prime_factors;
				
			RETURN;
			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;

		 -- SELECT rc_PrimeFactor(100);
		 -- SELECT rc_PrimeFactor(69851254266875212);--worst case test : 81 sec
		 -- SELECT rc_PrimeFactor(10203040506070809);--worst case test : 0.360ms
	

DROP FUNCTION IF EXISTS rc_PrimeFactorOnlyIn(a_number numeric, only_allowed_factors NUMERIC[], OUT prime_factors numeric[]);
		CREATE OR REPLACE FUNCTION rc_PrimeFactorOnlyIn(a_number numeric, only_allowed_factors NUMERIC[], OUT prime_factors numeric[])
		AS
		$BODY$
			--this function output the prime factors of the given number, by ascending order, a prmie factor being outputted n times if needed.
			
			DECLARE
			_q text;
			BEGIN

				--note : subotpimal : maybe could try not to cast to text?
				_q:= format('
				WITH RECURSIVE source (counter, factor, is_factor) AS (
						SELECT 2::numeric, %s ::numeric, false
					UNION ALL
						SELECT
							CASE
								WHEN factor %% counter = 0 THEN counter
								-- is ’factor’ prime?
								WHEN counter * counter > factor THEN factor
								-- now only odd numbers
								WHEN counter = 2 THEN 3
								ELSE counter + 2
								END,
							CASE
								WHEN factor %% counter = 0 THEN factor / counter
								ELSE factor
								END,
							CASE
								WHEN factor %% counter = 0 THEN true
								ELSE false
								END
						FROM source
						WHERE factor <> 1
						AND counter <= %s
				),
				result AS 
				(
					SELECT *
					FROM source 
					WHERE is_factor=TRUE
					AND counter = ANY (''%s''::numeric[])
				),
				product aS (
					SELECT numeric_product_agg(counter) AS prod
					FROM result
				),
				counter_array AS
				(
					SELECT array_agg(r.counter)
					FROM  result r 
				)
				SELECT ca.* AS prime_factors
				FROM counter_array AS ca, product
				--WHERE prod = %s'
				,a_number,rc_maxArray(only_allowed_factors),only_allowed_factors,a_number);

				--RAISE NOTICE '%',_q;
				EXECUTE _q INTO prime_factors;
				
			RETURN;
			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;

--		  SELECT rc_PrimeFactorOnlyIn(489611463161790210, ARRAY[2,5, 3,7,6765]);



	------------------------------------------------------------------------------
	--------rc_intersect_rounding_rules(array_of_factor_2_and_5 anyarray, OUT dividing_factor numeric);-----
	--
	--	This function reverse engineer the behavior of st_intersects regarding a point on a line
	--	If slope of line is an integer, spacing of point considered to be on the line by st_intersects follows the prime factorization of slope
	--	
	--	If a is slope of line, an integer , factorized into prime factors, the rules are:
	--		* only 2 and 5 prime factors have an effect on spacing
	--		* max 3 factor of each are allowed
	DROP FUNCTION IF EXISTS rc_intersect_rounding_rules(array_of_factor_2_and_5 anyarray, max_repetition int,  OUT dividing_factor numeric);
		CREATE OR REPLACE FUNCTION rc_intersect_rounding_rules(array_of_factor_2_and_5 anyarray, max_repetition int, OUT dividing_factor numeric)
		AS
		$BODY$
			--this function reverse engineers the behavior of ST_intersect of a line and a point regarding the slope of the line
			--, keep only 2 and 5 prime factor, and max max_repetition of each
			DECLARE
			_r record;
			
			BEGIN
				--getting prime factors (only 2 and 5) of the input array
				dividing_factor:=1;
					For _r IN 
						SELECT 
							f , f_count
						FROM 
							(SELECT f, count(*)  AS f_count
							FROM unnest(array_of_factor_2_and_5) f
							WHERE f = ANY (ARRAY[2,5])
							GROUP BY f
							ORDER BY f ASC ) as foo
					LOOP
						
						dividing_factor:=dividing_factor*pow(_r.f , LEAST(_r.f_count::int, max_repetition));
						--RAISE NOTICE 'in loop : dividing_factor: "%", _r.f :"%", _r.r_count : "%" ',dividing_factor,_r.f, _r.f_count;
					END LOOP;

					--RAISE NOTICE '_r : %, (_r[1]).f % (_r[1]).f_number %',_r,(_r).f,(_r).f_number;
					
				RETURN ;
			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;

/*		  SELECT rc_intersect_rounding_rules(array_of_factor_2_and_5:=ARRAY[2,2,5,5,5],max_repetition:=3);
	
	SELECT 
		f , f_count
	FROM 
		(SELECT f, count(*)  AS f_count
		FROM unnest(ARRAY[2,2,3,5,2,1]) f
		WHERE f = ANY (ARRAY[2,5])
		GROUP BY f
		ORDER BY f ASC ) as foo;
*/
/*
--sand box zone
WITH RECURSIVE source (counter, factor, is_factor) AS (
						SELECT 2::numeric, 300 ::numeric, false
					UNION ALL
						SELECT
							CASE
								WHEN factor % counter = 0 THEN counter
								-- is ’factor’ prime?
								WHEN counter * counter > factor THEN factor
								-- now only odd numbers
								WHEN counter = 2 THEN 3
								ELSE counter + 2
								END,
							CASE
								WHEN factor % counter = 0 THEN factor / counter
								ELSE factor
								END,
							CASE
								WHEN factor % counter = 0 THEN true
								ELSE false
								END
						FROM source
						WHERE factor <> 1
						AND counter <10
				)
				,result AS 
				(
					SELECT *
					FROM source 
					WHERE is_factor=TRUE
				),
				product aS (
					SELECT numeric_product_agg(counter) AS prod
					FROM result
				),
				counter_array AS
				(
					SELECT array_agg(r.counter)
					FROM  result r 
					WHERE r.counter = ANY (ARRAY[2,5])
				)
				SELECT ca.* AS prime_factors
				FROM counter_array AS ca, product
				--WHERE prod = 100
		*/

