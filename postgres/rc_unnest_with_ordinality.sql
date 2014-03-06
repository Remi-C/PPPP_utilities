

CREATE OR REPLACE FUNCTION rc_unnest_with_ordinality(anyarray, OUT value
anyelement, OUT ordinality integer)
  RETURNS SETOF record AS
$$
--@param an array to unnest
--@return : a set of [element,element ordinalty]


--note : found on internet 
--this function allow to reliabily use the unnest to always unnest in the same order 

SELECT $1[i] AS ordinality, i AS array FROM
    generate_series(array_lower($1,1),
                    array_upper($1,1)) i;
$$
LANGUAGE sql IMMUTABLE; 