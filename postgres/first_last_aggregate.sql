
--code found on postgres wiki
--note that there is a faster c version
--here : https://wiki.postgresql.org/wiki/First/last_%28aggregate%29
--note : the sql version is slow! 

-- Create a function that always returns the first non-NULL item
CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE sql IMMUTABLE STRICT AS $$
        SELECT $1;
$$;
 
-- And then wrap an aggregate around it
CREATE AGGREGATE public.first (
        sfunc    = public.first_agg,
        basetype = anyelement,
        stype    = anyelement
);
 
-- Create a function that always returns the last non-NULL item
CREATE OR REPLACE FUNCTION public.last_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE sql IMMUTABLE STRICT AS $$
        SELECT $2;
$$;
 
-- And then wrap an aggregate around it
CREATE AGGREGATE public.last (
        sfunc    = public.last_agg,
        basetype = anyelement,
        stype    = anyelement
);




--test of perf
	/*DROP TABLE IF EXISTS toto_perf_agg;
	CREATE TABLE toto_perf_agg AS 
	with the_data AS (
	SELECT s::int/100 as s,  random()   as rand 
	FROM generate_series(1,100000) AS s
	)
	SELECT s 
		 , public.first(rand)
		--,max(rand)
	FROM the_data 
	GROUP BY s ;
	*/
	