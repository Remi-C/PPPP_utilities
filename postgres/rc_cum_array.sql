---------------------------------------------
--Copyright Remi-C  11/2014
-- 
--Simply summing the values in an array
--------------------------------------------
	
DROP FUNCTION IF EXISTS rc_ArraySum( arr ANYARRAY, int);
		CREATE OR REPLACE FUNCTION rc_ArraySum( arr ANYARRAY,last_element int, OUT sum anyelement)
		 
		 AS
		$BODY$  
		DECLARE
		BEGIN

			SELECT COALESCE(sum(val.value ORDER BY val.ordinality),0) into sum
			from rc_unnest_with_ordinality(arr) as val
			WHERE val.ordinality <= last_element ;
			
		return;
		END;
		$BODY$
		LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT ;

--		SELECT rc_ArraySum(ARRAY[1,2,3,4],0 )