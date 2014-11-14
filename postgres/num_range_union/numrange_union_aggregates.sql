------------------------------
--Remi-C. 11/2014
--Thales IGN
-----------------------------
-- Disjoint Union of range
-----------------------------
--
--This project aims to perform a very simple mathematical task :
--given a number of ranges, perform the union of it :
--
--Union([1,3],[1,2],[3,6],[9,11],[13,15],[14,16]) = [1,6]U[9,11]U[13,16] 
---------------------------------------------------
--The implementation is done using aggregates:
--with an ordered set of range, aggregates
--  at each new range, if it intersects, update current range
--	else , store the current range in the list of range, use new range as new current range
---------------------------------------------------


DROP SCHEMA IF EXISTS test_aggregates CASCADE; 
create schema if not exists test_aggregates;
set search_path to  public; 


DROP TYPE IF EXISTS rc_num_range_accum_type CASCADE;
CREATE TYPE rc_num_range_accum_type AS
    ( current_numrange numrange ,accum_numrange numrange[] ) ;


SELECT (numrange(1,2) , ARRAY[numrange(2,3),numrange(3,4)] )::rc_num_range_accum_type ;


 
 
DROP FUNCTION IF EXISTS rc_sfunc_numrange_union(  rc_num_range_accum_type ,   numrange) CASCADE;
	CREATE OR REPLACE FUNCTION rc_sfunc_numrange_union(internal_state rc_num_range_accum_type ,  next_data_values numrange, OUT next_internal_state rc_num_range_accum_type)  
	AS $$ 
	DECLARE 
	BEGIN 
		next_internal_state := internal_state ; 

		IF internal_state IS NULL THEN 
			next_internal_state.current_numrange := next_data_values ;
			RETURN ; 
		END IF ;
		if internal_state.current_numrange && next_data_values -- AND upper(internal_state.current_numrange) < upper(next_data_values) 
		THEN -- we have to update the current num_range
			IF internal_state.current_numrange @> next_data_values --next_data_value is contained inside current_numrange, do nothing
			THEN 
			ELSE --next_data_values is higher, need to update
			next_internal_state.current_numrange = numrange(lower(next_internal_state.current_numrange), upper(next_data_values) )  ;
			END IF; 
		ELSE --disjoint, we need to add the numrange to the accumulated numranges and start from this new range
			next_internal_state.accum_numrange := array_append(next_internal_state.accum_numrange , internal_state.current_numrange) ;
			next_internal_state.current_numrange := next_data_values; 
		END IF;  
	RETURN;
	END;
	$$ LANGUAGE plpgsql;


	
DROP FUNCTION IF EXISTS rc_ffunc_numrange_union(  rc_num_range_accum_type  ) CASCADE;
	CREATE OR REPLACE FUNCTION rc_ffunc_numrange_union( internal_state rc_num_range_accum_type , OUT numrange_union numrange[])  
	AS $$ 
	DECLARE 
	BEGIN 
		numrange_union := array_append(internal_state.accum_numrange , internal_state.current_numrange) ; 
	RETURN;
	END;
	$$ LANGUAGE plpgsql;


WITH current_state AS (
	SELECT  (numrange(5,8) , ARRAY[numrange(1,2),numrange(3,4)] )::rc_num_range_accum_type as current_state
)
SELECT f.*
FROM current_state, rc_sfunc_numrange_union(current_state , numrange(9,10)) AS f;


DROP AGGREGATE IF EXISTS rc_numrange_disj_union(numrange) ;
CREATE AGGREGATE rc_numrange_disj_union ( numrange ) (
    SFUNC = rc_sfunc_numrange_union ,
    STYPE = rc_num_range_accum_type ,
    FINALFUNC  = rc_ffunc_numrange_union
);



WITH idata AS (
	SELECT numrange(1,5) as trange
	UNION ALL SELECT numrange(2,4)
	UNION ALL SELECT numrange(3,6)
	UNION ALL SELECT numrange(4,5)
	UNION ALL SELECT numrange(7,8)
	UNION ALL SELECT numrange(9,12)
	UNION ALL SELECT numrange(10,14)
)
SELECT rc_numrange_disj_union(trange) 
FROM idata
 