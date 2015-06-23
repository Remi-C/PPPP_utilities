-------------------------------------
-- Remi-C 
--this function was found on the postgresql wiki !

DROP FUNCTION IF EXISTS array_reverse(anyarray) ; 
CREATE OR REPLACE FUNCTION array_reverse(anyarray) RETURNS anyarray AS $$ --@brief : return the array in the reverse order
SELECT ARRAY(
    SELECT $1[i]
    FROM generate_subscripts($1,1) AS s(i)
    ORDER BY i DESC
);
$$ LANGUAGE 'sql' STRICT IMMUTABLE;

--test : 
-- SELECT array_reverse(ARRAY[1,2,3]);