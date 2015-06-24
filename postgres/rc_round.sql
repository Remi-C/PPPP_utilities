---------------------------------------------
--Copyright Remi-C  2014
--
-- writting files with python
--This script expects a postgres >= 9.3, Postgis >= 2.0.2 , pointcloud
--------------------------------------------


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