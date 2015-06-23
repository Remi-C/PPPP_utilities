


--founf on internet
CREATE OR REPLACE FUNCTION rc_random_string(INTEGER )
RETURNS text AS $$
	SELECT array_to_string(
		ARRAY(
			SELECT 
				substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' FROM (random()*36)::int + 1 FOR 1) 
				FROM generate_series(1,$1)
		)
	,'') 
	--exemple use case :
	--SELECT rc_random_string(10);
$$ LANGUAGE sql;