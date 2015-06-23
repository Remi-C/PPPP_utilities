----------------------------
--Remi-C 02/2015
--IGN THALES
----------------------------
--finding next value of sequence :
-- WARNING : USELESS, there is alreadya builtin function to do that
---------------------------- 

			

DROP FUNCTION IF EXISTS rc_FindNextValue(topology_name text , table_name text, column_name text )  ;
CREATE OR REPLACE FUNCTION rc_FindNextValue(topology_name text , table_name text, column_name text) 
ReTURNS INT  AS
$BODY$  
	/** @brief this function return the next value of a sequence 
	*/ 
	DECLARE 
		_q text ;
		_seq_text TEXT ; 
		_next_val INT; 
	BEGIN   
		
		_q := format('
			SELECT  column_default 
			FROM  information_schema.columns 
			WHERE table_schema = %s
				AND table_name=%s
				AND column_name =%s;',quote_literal(topology_name),quote_literal(table_name),quote_literal(column_name) ) ; 
		
		EXECUTE _q INTO _seq_text ; 
		

		IF _seq_text IS NULL THEN 
			RAISE EXCEPTION 'could nt find the sequence, probably wrong input  : topology_name % , table_name %, column_name %',topology_name , table_name , column_name ;
		END IF ; 
		
		_q := 'SELECT '||_seq_text ;  
		EXECUTE _q INTO _next_val ; 
		RETURN _next_val ; 
	END ;
	$BODY$
  LANGUAGE plpgsql VOLATILE;

 -- SELECT *
--  FROM rc_FindNextValue('bdtopo_topological', 'node', 'node_id') ;