DROP FUNCTION IF EXISTS public.rc_DumpSegments(line geometry ) ;
CREATE OR REPLACE FUNCTION public.rc_DumpSegments(_line geometry)
RETURNS SETOF geometry_dump
AS
$BODY$
--this function breaks a line/multiline/geomCollection into minimal segments and return the segment, along with the path
--There is no loss of information : operation can be reverted if there are no several layer of geometry collections
--the srid is transmitted.
DECLARE
_r record;
--_srid integer;
BEGIN

--_srid := ST_SRID(_line);

FOR _r in SELECT ST_Dump(ST_CollectionExtract (_line,2)) AS dp
LOOP
RETURN QUERY WITH line AS( 
SELECT --ST_GeomFromText('LINESTRING(12 1, 13 1, 14 2, 15 4)') AS line
(_r.dp).path AS gpath, (_r.dp).geom AS line 
),
dump AS(
SELECT gpath[1] AS gpath, (ST_DumpPoints(line)) as dp, ST_SRID(line) AS srid
FROM line
),
segments AS (
SELECT 
CASE WHEN gpath IS NULL THEN ARRAY[(dp).path[1]-1] ELSE ARRAY[gpath, (dp).path[1]-1] END AS path
,ST_SetSRID(ST_MakeLine( 
lag((dp).geom , 1, NULL) OVER (ORDER BY  (dp).path)
,(dp).geom
),srid) AS geom
FROM dump
)
SELECT path,geom
FROM segments 
WHERE geom  IS NOT NULL;
END LOOP;--loop if multi linestring
RETURN;
END;
$BODY$
 LANGUAGE plpgsql  IMMUTABLE STRICT;
///////////////////////////////////