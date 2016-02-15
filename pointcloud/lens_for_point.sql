----------
-- Remi C, 2016, 
-- lens for point : create the infrastructure with a lens that shows the point of a point cloud inside.
---

-- creating the lens table (aka control)
/*
DROP TABLE IF EXISTS tmob_20140616.lens_for_points CASCADE; 
CREATE TABLE tmob_20140616.lens_for_points (
gid int  primary key CHECK (gid = 1)
,lens geometry(polygon,931008)
,max_nb_points int
,grid_cell_size float
,tolerancy_on_time_range float
,pass_number int
)  ; 

--inserting some default value in it
INSERT INTO tmob_20140616.lens_for_points VALUES
(1
,  ST_GeomFromtext('POLYGON((650894.58 6861287.92, 650898.08 6861287.92, 650898.08 6861292.87, 650894.58 6861292.87,650894.58 6861287.92))',931008)
,10000	
,0.05
,60
,1) 


--creating a materialised view to extract point within the lense


DROP MATERIALIZED VIEW IF EXISTS tmob_20140616.lens_points ; 
CREATE MATERIALIZED VIEW tmob_20140616.lens_points AS 

	WITH patchs AS (
		SELECT 	rp.gid, num_points, avg_time, geom
		FROM tmob_20140616.lens_for_points AS lens 
		, tmob_20140616.riegl_pcpatch_space_int_proxy AS rp
		WHERE ST_Intersects(lens.lens,rp.geom) = TRUE
	)
	, u_ranges AS (
		SELECT rc_numrange_disj_union(numrange((lower(avg_time)-tolerancy_on_time_range)::numeric,  (upper(avg_time)+tolerancy_on_time_range)::numeric) ORDER BY  avg_time ASC)  AS u_ranges
		FROM tmob_20140616.lens_for_points, patchs
	)
	,u_range AS (
		SELECT row_number() over(ORDER BY u_range ASC) AS u_id, u_range
		FROM u_ranges, unnest(u_ranges) as u_range
		ORDER BY u_range ASC
	)
	 ,selected_range AS (
		SELECT u_range.*
		FROM tmob_20140616.lens_for_points AS lens, u_range
		WHERE lens.pass_number = u_id
		LIMIT 1
	)
	SELECT (row_number() over())::int AS tid, pt::geometry(pointZ,931008) AS point  , PC_Get(point,'reflectance') as attributes
	FROM tmob_20140616.lens_for_points AS lens 
		,selected_range
		, patchs AS rp
		 ,tmob_20140616.riegl_pcpatch_space_int AS rps 
		 , rc_exploden_grid(patch, max_nb_points,grid_cell_size) as point
		 , CAST(point AS geometry) AS pt
	WHERE ST_Intersects(lens.lens,rp.geom) = TRUE
		AND rp.avg_time && selected_range.u_range
		AND rp.gid = rps.gid 
			AND ST_Intersects(lens.lens,pt) = TRUE;

 


*/
/*
-- creating trigger to automate refresh
 

	--editing triggers  
		CREATE OR REPLACE FUNCTION tmob_20140616.rc_refresh_lens_point(  )
		  RETURNS  TRIGGER  AS
		$BODY$ 
			--- @brief this trigger is designed to update the geometry of edges connected to a node.
            -- edge last/first point should be approprietly set to be the node 
           
			--we consider that by default a change of geom in node means no topological change
				DECLARE  
				BEGIN 
					REFRESH MATERIALIZED VIEW tmob_20140616.lens_points ;
					RETURN OLD ; 
				END ;
				$BODY$
		  LANGUAGE plpgsql VOLATILE;

		DROP TRIGGER IF EXISTS  tmob_20140616_rc_refresh_lens_point ON tmob_20140616.lens_for_points; 
		CREATE  TRIGGER tmob_20140616_rc_refresh_lens_point   AFTER  UPDATE 
		    ON tmob_20140616.lens_for_points
		 FOR EACH ROW  
		    EXECUTE PROCEDURE tmob_20140616.rc_refresh_lens_point(); 
*/