---------------------------------------------
--Copyright Remi-C  2014
--
-- writting files with python
--This script expects a postgres >= 9.3, Postgis >= 2.0.2 , pointcloud
--------------------------------------------
--SET search_path to rc_lib, public;  

 
DROP FUNCTION IF EXISTS round(  double precision, int) ;
CREATE OR REPLACE FUNCTION round( i double precision, d int) RETURNS double precision AS
$BODY$
	--@brief : returns rouding, with automatic numeric casting
		DECLARE  
		BEGIN   
			RETURN round(i::numeric,d::int) ; 
		END ; 
$BODY$
 LANGUAGE plpgsql IMMUTABLE STRICT;

 

	DROP FUNCTION IF EXISTS rc_round(in val anyelement , IN round_step anyelement, out o_val DOUBLE PRECISION) ;
	CREATE OR REPLACE FUNCTION rc_round(in val anyelement , IN round_step anyelement, out o_val double precision) AS
	$BODY$
			--@brief : this function round the input value to the nearest value multiple of round_step
		DECLARE			 
		BEGIN 

		o_val := (round(val::numeric/round_step::numeric)*round_step::numeric)::double precision;
		RETURN ;
		END;
	$BODY$
	 LANGUAGE plpgsql IMMUTABLE STRICT;