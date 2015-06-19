---------------------------------------------
-- Remi-C Thales & IGN , Terra Mobilita Project, 2015 
----------------------------------------------
-- This script tries to output correct .obj geometries
-- This script expects a postgres >= 9.2.3, Postgis >= 2.0.2, postgis topology enabled
--
------------- 

/*
with i_geom AS (
	SELECT  o_closing as geom --, r.*
	FROM generalisation.transformed_points_closing_reconstructed --, rc_geom_to_obj(o_closing,3,'plan_'||qgisid) as  r
	WHERE qgisid =17
)
SELECT ST_AddPoint(geom,  ST_StartPoint(geom),-1)
FROM i_geom ; 
*/

DROP FUNCTION IF EXISTS rc_geom_to_obj(geom geometry, digits int, object_name text) ;
CREATE OR REPLACE FUNCTION rc_geom_to_obj(geom geometry, digits int, object_name text) 
returns table(ordinality int, line text)
AS $$
-- @brief : this compute precision and recal and comrpession
DECLARE
BEGIN    
	RETURN QUERY 
	  WITH triangulated AS (
		SELECT  poly 
		FROM  st_tesselate(geom) as poly
	 )
	 , prepared_values AS (
		 SELECT dmp.path,row_number() over() as id,  st_astext(dmp.geom), ST_X(g) AS x, st_Y(g) AS y,round(st_z(g)::numeric, digits ) AS Z
		 FROM triangulated, ST_DumpPoints(poly) as dmp, ST_SnapToGrid(dmp.geom , 10^(-digits)) AS g
		WHERE path[3]%4!=0 
		ORDER BY id ASC
	)
	, number_of_triangles_to_export AS(
		SELECT max(id/3)::int as t_to_export
		FROM prepared_values
	) 
		SELECT 1 as ordinality,  'o '||object_name
		UNION ALL
		SELECT id::int+1 as ordinality, 'v '|| x||' '||y||' '||z
		FROM prepared_values
		UNION ALL
		SELECT m+s+3 as ordinality, 'f '||(-1*(s*3+1)) ||' '|| (-1*(s*3+2) )|| ' ' ||(-1*(s*3+3) )
		FROM number_of_triangles_to_export , (select max(id)::int as m from prepared_values) AS m_id, generate_series(0,t_to_export-1) as s   ;
	
RETURN ;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT ;

/*
SELECT   r.*
FROM generalisation.transformed_points_closing_reconstructed 
	, rc_geom_to_obj(o_closing,3,'plan_' ) as  r
WHERE qgisid =17 ; 


COPY (
	WITh grouped AS (
		--SELECT 1 as qgisid , ST_Collect(ring.geom) as o_closing
			--, st_astext(ring.geom)
		SELECT qgisid,  cleaned_poly   
		FROM generalisation.transformed_points_closing_reconstructed  
			,ST_Dump(o_closing ) as dmp 
			,ST_SetPoint(dmp.geom, ST_NumpOints(dmp.geom)-1,ST_StartPoint(dmp.geom)) as closed_line
			, ST_MakeValid(st_makePolygon(closed_line)) as validated_poly 
			, st_dump(validated_poly) as dmpv
			, ST_MakePolygon(st_exteriorRing(dmpv.geom))  as cleaned_poly 
		--WHERE qgisid < 10
	)
	 , to_output AS (
		SELECT qgisid,   r.*
		FROM grouped, rc_geom_to_obj(cleaned_poly,3,'plan_'||qgisid) as  r 
	)
	SELECT line
	FROM to_output 
	ORDER BY qgisid, ordinality
)
TO '/tmp/export4.obj'


SELECT   ST_Astext(ST_Tesselate(cleaned_poly))
FROM generalisation.transformed_points_closing_reconstructed 
	, ST_Dump(o_closing ) as dmp 
	,ST_SetPoint(dmp.geom, ST_NumpOints(dmp.geom)-1,ST_StartPoint(dmp.geom)) as closed_line
	, ST_MakeValid(st_makePolygon(closed_line)) as validated_poly 
	, st_dump(validated_poly) as dmpv
	, ST_MakePolygon(st_exteriorRing(dmpv.geom))  as cleaned_poly 

 
COPY (
	WITh grouped AS (
		--SELECT 1 as qgisid, ST_Collect(o_closing) as o_closing
		SELECT 1 as qgisid, ST_Collect(o_closing) as o_closing
		FROM generalisation.transformed_points_closing_reconstructed 
		--WHERE qgisid < 4
	)
	, triangulated AS (
		SELECT dmp.path[1] as poly_id , poly 
		FROM grouped
			, ST_Dump(o_closing ) as dmp 
			,ST_SetPoint(dmp.geom, ST_NumpOints(dmp.geom)-1,ST_StartPoint(dmp.geom)) as closed_line
			, ST_MakeValid(st_makePolygon(closed_line)) as validated_poly 
			, st_dump(validated_poly) as dmpv
			, ST_MakePolygon(st_exteriorRing(dmpv.geom))  as cleaned_poly 
			, st_tesselate(cleaned_poly) as poly
	) 
	, prepared_values AS (
		 SELECT  dmp.path,row_number() over() as id,  st_astext(dmp.geom), ST_X(g) AS x, st_Y(g) AS y, st_z(g) AS Z
		 FROM triangulated, ST_DumpPoints(poly) as dmp, ST_SnapToGrid(dmp.geom , 10^(-3)) AS g
		-- WHERE path[1] != forbiden_points
		WHERE path[3]%4!=0 --remove the redudundant 4th point
		ORDER BY id ASC
	)
	, number_of_triangles_to_export AS(
		SELECT max(id/3)::int as t_to_export
		FROM prepared_values
	) 
	,to_write AS (
		SELECT 1 as ordinality,  'o '||'titi' as tow
		UNION ALL
		(SELECT id+1 as ordinality, 'v '|| x||' '||y||' '||z
		FROM prepared_values
		ORDER BY id)
		UNION ALL
		SELECT m_id.m+s+3 as ordinality, 'f '||s*3+1 ||' '|| s*3+2 || ' ' ||s*3+3 
		FROM number_of_triangles_to_export , (SELECT max(id) AS m FROM prepared_values ) as m_id, generate_series(0,t_to_export-1) as s  
	)
	SELECT tow
	FROM to_write 
	ORDER BY ordinality ASC
		)TO '/tmp/export2.obj'
 
 */