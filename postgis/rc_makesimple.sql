---------------------------------------------
--Copyright Remi-C 02/2015
--
-- a thin hack to create simple (multi)line out of non simple (multi)line
--------------------------------------------




DROP FUNCTION IF EXISTS rc_MakeSimple(   IN i_geom GEOMETRY, OUT o_geom GEOMETRY );
CREATE OR REPLACE FUNCTION rc_MakeSimple(   IN i_geom GEOMETRY, OUT o_geom GEOMETRY 
	 ) AS 
	$BODY$
		--@brief : this function takes a line or multi linestring , and return a multilinestring where every linestring inside is simple
		DECLARE     
		BEGIN 	
		WITH dump AS (
			SELECT dmp.path, dmp.geom
			FROM st_dump(ST_Node(i_geom)) as dmp
		)
		SELECT ST_Multi(ST_Collect(geom ORDER BY path)) INTO o_geom 
		FROM dump;
	RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT;    

/*
--testing 
WITH dat AS (
	SELECT ST_GeomFromtext('LINESTRING(1 0,-24 186,2 311,-59 537,-116 618,-140 697,-34 978,-52 1150,-344 1348,-683 1812,-853 2004,-898 2090,-896 2130,-817 2222,-795 2270,-780 2530,-752 2655,-761 2908,-839 3153,-834 3195,-780 3301,-1184 3320,-780 3301,-699 3480,-711 3559,-645 3579,-587 3556,-547 3496,-472 3445,-242 3332,-229 3042,-138 2715,-111 2646,53 2453,98 2339,53 2453,-111 2646,-138 2715,-229 3042,-242 3332,-349 3375,-523 3477,-587 3556,-426 3632,-231 3678,-144 3724,249 3738,-118 3729,-231 3678,-426 3632,-580 3556,-645 3579,-711 3559,-830 3677,-1002 3783,-1156 3837,-1342 4012,-1496 4074,-1539 4137)') AS geom
)
SELECT --ST_IsSimple((ST_Dump(rc_MakeSimple(geom))).geom)
	ST_Astext(rc_MakeSimple(geom))
FROM dat ;  
 */