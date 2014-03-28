----------------
--Found on the net (no copyright)
--
--

--this function allows to create array of array.
--to use it, call it on array data, it will output array of array
CREATE AGGREGATE array_agg_custom(anyarray)
(
    SFUNC = array_cat,
    STYPE = anyarray
);
