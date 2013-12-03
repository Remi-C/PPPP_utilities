---------------------------------------------
--Copyright Remi-C Thales IGN 29/11/2013
--
--a function to convert a multipoint into a linestring, following the mutlipoint order
--------------------------------------------








DROP FUNCTION IF EXISTS public.rc_MultiPointTOLine( multipoint geometry);
		CREATE OR REPLACE FUNCTION public.rc_MultiPointTOLine( multipoint geometry  )
	RETURNS geometry  AS  
		$BODY$
			--this function sew together points from multipoint in the multipoint order to form a line
			----
			--@input :	"multipoint" 			: the line on which the result would be (except if it is too far)
			--@output :	"geometry"		: a line formed by segs from point to point in multipoint order.

			DECLARE
			_result geometry;
			BEGIN
				WITH dump AS (
					SELECT 1 as id, the_dump.path, the_dump.geom 
					FROM  ST_DumpPoints(ST_CollectionExtract(multipoint,1)) the_dump
				)
				SELECT ST_MakeLine(d.geom ORDER BY d.path ASc) AS l INTO _result
					FROM dump AS d
					GROUP BY d.id ;
			 _result := ST_SetSRID(_result, ST_SRID(multipoint) ) ;
			RETURN _result;
			END;
		$BODY$
		  LANGUAGE plpgsql  IMMUTABLE STRICT;

		---- test of the function
		SELECT ST_AsText( rc_MultiPointTOLine( point) )
		 FROM ST_GeomFromText('MULTIPOINT(1601.21138045673 21494.9000674227,1601.3 21494.4,1602.31065385555 21488.8919364873)') AS point

		 
		 