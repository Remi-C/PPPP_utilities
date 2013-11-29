---------------------------------------------
--Copyright Remi-C Thales IGN 22/10/2013
--
--
--Compilation of utility postgres function found over the internet
--
--
--	*adding a column if not exist*
--------------------------------------------







--http://stackoverflow.com/questions/12597465/how-to-add-column-if-not-exists-on-postgresql
DROP FUNCTION IF EXISTS public.rc_AddColIfNotExist(   _tbl regclass, _col  text, _type regtype, OUT success bool);
CREATE OR REPLACE function public.rc_AddColIfNotExist(
   _tbl regclass, _col  text, _type regtype, OUT success bool)
    LANGUAGE plpgsql AS
$func$
	BEGIN

		IF EXISTS (
		   SELECT 1 FROM pg_attribute
		   WHERE  attrelid = _tbl
		   AND    attname = _col
		   AND    NOT attisdropped) THEN
		   success := FALSE;

		ELSE
		   EXECUTE format('ALTER TABLE %s ADD COLUMN %I %s', _tbl, _col, _type);
		   success := TRUE;
		END IF;

	END
$func$;

SELECT public.rc_AddColIfNotExist( 'public.kat', 'pfad1', 'int');