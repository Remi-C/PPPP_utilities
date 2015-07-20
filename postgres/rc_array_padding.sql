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


DROP FUNCTION IF EXISTS rc_array_allsamevalue(IN iarray anyarray, OUT allsamevalue boolean) ; 
CREATE OR REPLACE FUNCTION  rc_array_allsamevalue(IN iarray anyarray, OUT allsamevalue boolean)
  RETURNS boolean AS
$BODY$
 --given an array, return true if all values of the array are equal
		DECLARE    
		BEGIN 
 
			SELECT count(*)=1 INTO allsamevalue
			FROM (
			SELECT 1
			FROM unnest(iarray) AS ar
			GROUP BY ar
			) as sub ; 
			 
		RETURN; 
		END ;  
		$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100; 