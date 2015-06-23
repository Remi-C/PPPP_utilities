-----------------------------
--Rémi C
--02/2015
---------------------------------------
--this function compute median of a column (found on pavel stehul website)

DROP FUNCTION IF EXISTS rc_median(anyarray) ; 
create or replace function rc_median(anyarray) 
returns double precision as $$
/** @brief this function compute the median of a column
*/
  select ($1[array_upper($1,1)/2+1]::double precision + $1[(array_upper($1,1)+1) / 2]::double precision) / 2.0; 
$$ language sql immutable strict;

