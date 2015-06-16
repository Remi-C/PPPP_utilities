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
sys.path.insert(0, '/home/remi/PPPP_utilities/postgis')
import rc_py_generate_bezier_curve as rc

#reload(rc)
#plpy.notice('seg_points : ' + seg_points +' centre_of_intersection ' +centre_of_intersection ) 
tempo = rc.bezier_curve(seg_points, centre_of_intersection, parallel_threshold, nb_segs, in_server=True)
if len(tempo)!=2:
	plpy.notice(tempo)
bezier, pc = tempo

return (bezier,pc)
$BODY$
LANGUAGE plpythonu STABLE STRICT; 