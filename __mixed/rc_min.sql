/*
Remi Cura
Thales Internal
A function returning the min between two anyelements
WARNING : the '<' operator must be defined for the element
*/
DROP FUNCTION IF EXISTS rc_min(anyelement,anyelement);
CREATE OR REPLACE FUNCTION rc_min(anyelement , anyelement ) RETURNS anyelement AS 
$$
    SELECT 
	CASE WHEN $1 < $2 
		THEN $1 
		ELSE $2 
	END
$$ LANGUAGE SQL STRICT;