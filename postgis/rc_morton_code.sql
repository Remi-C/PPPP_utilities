---------------------------
-- Remi C Thales IGN 2016
-- computing Morton code for a point
----------------------------


DROP FUNCTION IF EXISTS rc_inverse_interleaving( X int, Y int,n_bit int);
CREATE OR REPLACE FUNCTION rc_inverse_interleaving( X int, Y int,  n_bit int, OUT interleaved text,OUT r_interleaved text ) 
AS
$BODY$
--  use X Y, interleave the bits , revert it
-- nbit xcan be computed like this : GREATEST(ceiling(ln(X)/ln(2))+1,ceiling(ln(Y)/ln(2))+1)
DECLARE   
	_x_b text ;
	_y_b text ;
	_x_a text[] ;
	_y_a text[];
	_q text;  
	_inter text[] ;
BEGIN 
	--converting both coordinates to bit
	_q :=  format('SELECT $1::bit(%s)::text,$2::bit(%s)::text',n_bit,n_bit) ; 
	EXECUTE _q INTO _x_b, _y_b USING X,Y; 

	_x_a := string_to_array(_x_b,NULL) ; 
	_y_a := string_to_array(_y_b,NULL) ; 

	--RAISE NOTICE '% % ', _x_a, _y_a ;  
	
	FOR _i in 1 .. n_bit LOOP
		IF _inter IS NULL THEN
			_inter :=  ARRAY[_x_a[_i]] || _y_a[_i]  ;
		ELSE
			_inter :=  _inter ||_x_a[_i] || _y_a[_i]  ; 
		END IF ;  
	END LOOP ; 
	interleaved := array_to_string(_inter,'') ;  
	r_interleaved := reverse(interleaved) 
	 RETURN ; 
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE;
 
  SELECT f.*
  FROM  rc_inverse_interleaving(12,11,5) AS f