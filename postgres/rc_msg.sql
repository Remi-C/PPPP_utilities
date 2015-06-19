---------------------------------------------
--Copyright Remi-C Thales & IGN , Terra Mobilita Project, 2014
--
---------------------------------------------- 
--  2 functions usefull to debug complex query, allow to print the content of a variable
--the choice between vloatile and immutable allow to choose wether the function is called on time or several
--------------------------------------------
		 
DROP FUNCTION IF EXISTS rc_msg_vol(text);
CREATE OR REPLACE FUNCTION rc_msg_vol(   
		 i_text TEXT 
	 ) RETURNS VOID AS 
	$BODY$
		DECLARE     
		BEGIN 
		--@brief this function print a message and the associated time
		--@return nothing

			RAISE NOTICE  '%: %',clock_timestamp(), i_text; 
			RETURN ;
		END ;  
	$BODY$
LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT; 


DROP FUNCTION IF EXISTS rc_msg_immutable(text);
CREATE OR REPLACE FUNCTION rc_msg_immutable(   
		 i_text TEXT 
	 ) RETURNS VOID AS 
	$BODY$
		DECLARE     
		BEGIN 
		--@brief this function print a message and the associated time
		--@return nothing

			RAISE NOTICE  '%: %',clock_timestamp(), i_text; 
			RETURN ;
		END ;  
	$BODY$
LANGUAGE plpgsql IMMUTABLE  CALLED ON NULL INPUT; 
 