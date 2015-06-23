-----------------------------
--Rémi C
--12/2014 
--
-- a dirty function to padd array (adding 0), if necessary
---------------------------------------


	--creating function
DROP FUNCTION IF EXISTS rc_array_padding(iarr anyarray ,  start_indice int, final_arr_length int , OUT oarr anyarray) ; 
CREATE OR REPLACE FUNCTION  rc_array_padding(iarr anyarray , start_indice int, final_arr_length int ,  OUT oarr anyarray)
AS $$ 
-- @brief : this function takes an array and fill it with 0 to reach desired size
DECLARE 
	i int  ;
	last_indice int := LEAST(array_length(iarr,1),final_arr_length );
BEGIN
	oarr := array_fill(0, ARRAY[final_arr_length  ]);

	for i in 1..final_arr_length 
		LOOP
			oarr[i] := COALESCE(iarr[i+start_indice-1],0) ; 
		END LOOP; 
RETURN ; 
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT ;