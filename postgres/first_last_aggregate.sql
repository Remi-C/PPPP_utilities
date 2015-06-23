
--code found on postgres wiki
--note that there is a faster c version
--here : https://wiki.postgresql.org/wiki/First/last_%28aggregate%29
--note : the sql version is slow! 

-- Create a function that always returns the first non-NULL item
DROP FUNCTION IF EXISTS first_agg ( anyelement, anyelement ) ;
CREATE OR REPLACE FUNCTION first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE sql IMMUTABLE STRICT AS $$
        SELECT $1;
$$;
 
-- And then wrap an aggregate around it
DROP AGGREGATE IF EXISTS first(anyelement) ;
CREATE  AGGREGATE first (
        sfunc    = first_agg,
        basetype = anyelement,
        stype    = anyelement
);
 
-- Create a function that always returns the last non-NULL item
DROP FUNCTION IF EXISTS last_agg ( anyelement, anyelement ) ; 
CREATE OR REPLACE FUNCTION last_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE sql IMMUTABLE STRICT AS $$
        SELECT $2;
$$;
 
-- And then wrap an aggregate around it
DROP AGGREGATE IF EXISTS last(anyelement) ;
CREATE AGGREGATE last (
        sfunc    = last_agg,
        basetype = anyelement,
        stype    = anyelement
);
