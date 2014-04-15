---------------------------------
--Remi-C , 14/04/2014
--
--Some tools for range
--
--
----------------------------------

--a function to interpolate (and extrapolate) a value relative ot a range
	

	DROP FUNCTION IF EXISTS range_interpolate(nr anyrange,obs anyelement) ;
	CREATE OR REPLACE FUNCTION range_interpolate(nr anyrange,obs anyelement) 
		RETURNS TABLE(lower_weight NUMERIC,upper_weight NUMERIC)
	AS $$
		--@param a range 
		--@param an observation (value) of the same type as the range
		--@return the weight to apply to lower bound and upper bound of range to get the value. 

		--exceptions : -inf or +inf : weight of the bound is 0, the other 1. 
		--exceptions : range = a point : returns weight of 0.5 for each bound (they are identical but the asociated data may not be)
		SELECT 
		CASE 	WHEN upper(nr)=lower(nr) THEN ROW(0.5,0.5)
			--WHEN obs=lower(nr) AND obs=upper(nr) THEN ARRAY[0.5,0.5]
			--THEN (obs-lower(nr))/ra, (upper(nr)-obs)/ra
			WHEN lower_inf(nr)=TRUE OR lower(nr) IS NULL THEN ROW(0,1)
			WHEN upper_inf(nr)=TRUE OR upper(nr) IS NULL THEN ROW(1,0)
			ELSE ROW( (upper(nr)-obs)/(upper(nr)-lower(nr)),(obs-lower(nr))/(upper(nr)-lower(nr)))
			END
		
		--testing :
		--SELECT * FROM range_interpolate(numrange(1,10) ,  round(10,2))
	$$
	LANGUAGE SQL
	IMMUTABLE
	RETURNS NULL ON NULL INPUT;
 

	