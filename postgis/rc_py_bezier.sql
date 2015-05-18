---------------------------------------------
--Copyright Remi-C Thales IGN 05/2015
-- 
--this function construct a Bezier curve linking 2 segments
--------------------------------------------

DROP FUNCTION IF EXISTS rc_bezier_from_seg(seg_points geometry, centre_of_intersection geometry, parallel_threshold float, nb_segs int);
CREATE OR REPLACE FUNCTION rc_bezier_from_seg(seg_points geometry,centre_of_intersection geometry, parallel_threshold float, nb_segs int, OUT bezier geometry, OUT pc geometry)
  AS
$BODY$
#this function takes 2 segments, and build a Bezier curve to join the segments
import sys
sys.path.insert(0, '/media/sf_E_RemiCura/PROJETS/PPPP_utilities/postgis')
#sys.path.insert(0, '/media/sf_perso_PROJETS/PPPP_utilities/postgis')
#sys.path.insert(0, '/home/remi')
import rc_py_generate_bezier_curve as rc

reload(rc)
plpy.notice('seg_points : ' + seg_points +' centre_of_intersection ' +centre_of_intersection ) 
tempo = rc.bezier_curve(seg_points, centre_of_intersection, parallel_threshold, nb_segs, in_server=True)
if len(tempo)!=2:
	plpy.notice(tempo)
bezier, pc = tempo

return (bezier,pc)

$BODY$
LANGUAGE plpythonu STABLE STRICT;

SELECT *--, st_astext(bezier), st_astext(pc) 
FROM ST_GeomFromText('MULTIPOINT(0 2,0 1,1 0 ,2 0)') as geom 
	,ST_GeomFromText('POINT(0.5 0.5)') as geom2
	,rc_bezier_from_seg(geom,geom2, 0.85, 10);


UPDATE street_amp.visu_result_lane
SET edge_id = edge_id 
WHERE edge_id = 7323 AND lane_ordinality = 2 ;

/*
--SELECT ST_AsText('0102000020AB380E00050000002087BFAEF863B0406DC671653C36D7404801221EC464B04091F0279C9836D740205F1D550767B04036D1756E3137D740BACB32586D6AB04014B3123B1937D740EE316666E66AB0406F0960660637D740')
--SELECT ST_GeomFromText('LINESTRING(4195.97141644525 23768.9436916769
,4196.76608479053 23770.3845310067
,4199.02864249775 23772.772366957
,41200.02864249775 23771.772366957
,4202.4271270511 23772.3942305325
,4202.89999998778 23772.0999984829)')
*/