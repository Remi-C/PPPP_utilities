---------------------------------------------
--Copyright Remi-C Thales IGN 25/04/2015
-- 
--find common face between 2 edge_id
--------------------------------------------



DROP FUNCTION IF EXISTS public.rc_find_common_face(e1 int,e2 int,topo_name text ) ; 
CREATE OR REPLACE FUNCTION public.rc_find_common_face(e1 int,e2 int,topo_name text,  OUT face geometry) AS
$BODY$
--this function takes 2 edge id and returns the common face
DECLARE  
	_q text  ;
BEGIN 
	_q := format('
		SELECT ST_GetFaceGeometry(''%1$I'', face_id) 
		FROM (
		SELECT  face_id, count(*) over(partition by face_id) as c
		FROM  (
			SELECT left_face as face_id
			FROM %1$s.edge_data
			WHERE edge_id IN ($1,$2)
			UNION ALL
			SELECT right_face
			FROM %1$s.edge_data
			WHERE edge_id IN ($1,$2)
		) as sub 
		) as subsub
		WHERE c >=2
		AND face_id != 0 
		LIMIT 1
	', topo_name  ) ; 

	EXECUTE _q INTO face USING e1,e2 ;
	
	RETURN;
END;
$BODY$
LANGUAGE plpgsql VOLATILE STRICT;

SELECT ST_AsText(public.rc_find_common_face( 2523,2528,'bdtopo_topological'))

