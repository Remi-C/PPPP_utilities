---------------------------------------------
--Rémi Cura , 2015
----------------------------------------------
-- This script test the way to compute angle between 3 points and use it to test left or right
----------------------------------------------


------------------

-- testing the angle function

--create a matrix of random points, so to test the angle between 3 points
SET search_path TO test, rc_lib, public;


DROP TABLE IF EXISTS test_angle_3_points ;
CREATE TABLE  test_angle_3_points AS
	WITH series AS (
	    SELECT row_number() over() as gid,  s1+1/4 -random()/2.0 AS x , s2+1/4 -random()/2.0 AS y
	    FROM generate_series(1,10) AS s1, generate_series(1,10) AS s2
	)
	, points AS (
	    SELECT gid, ST_MakePoint(x+random()/2.0 , y+random()/2.0) AS p1
		, ST_MakePoint(x+random()/2.0 , y+random()/2.0) AS p2
		, ST_MakePoint(x+random()/2.0 , y+random()/2.0) AS p3
	    FROM series AS s
	)
	SELECT gid, line, point , az_line, az_point, az_line-az_point AS diff_angle, cu_angle < 180 AS is_left , cu_angle
		, (cu_angle <180 ) = (rc_angle>=180) as testing
		, rc_angle
		
	FROM points
	 , ST_MAkeline(p1,p2) AS line, ST_MAkeValid(p3) AS point
	 , round(degrees(ST_Azimuth(p2,p1))::numeric,1) AS az_line, round(degrees(ST_Azimuth(point,p2))::numeric,1)AS az_point
	 , round(CAST(  (az_line-az_point) + ((az_line-az_point)<0)::int*360 AS INT),3) AS cu_angle
	, round(degrees(rc_lib.rc_angle(  p1,p2,p3)),3) AS rc_angle;
-----------------------------------