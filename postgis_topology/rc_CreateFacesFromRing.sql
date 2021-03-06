﻿
----------------------
-- Remi-C THALES IGN
--05/2015
----------------------
-- postgis topology function
----------------------
-- a ring (signed edges), creates a face bounding it, and add it to my_topo.face
	
	DROP FUNCTION IF EXISTS rc_CreateFaceFromRing(topology_name TEXT, signed_edges_of_ring INT[] ) ;
	CREATE OR REPLACE FUNCTION rc_CreateFaceFromRing(topology_name TEXT, signed_edges_of_ring INT[]  , OUT face_id  INT)
	AS $BODY$   
		/** @brief given a ring, creates a face bounding it, and add it to my_topo.face
		@return return the face_id of the inserted face
		*/
		DECLARE 
		BEGIN
		
		EXECUTE format('
		 WITH rings AS ( -- unnesting the list of edges to update
			SELECT DISTINCT ON (edge_id) abs(s_edges) AS edge_id, ed.geom AS edge_geom
			FROM   unnest ( $1)  AS s_edges
				LEFT OUTER JOIN %1$I.edge_data AS ed ON (ed.edge_id =abs(s_edges)  )
			ORDER BY edge_id
		)  
		 , new_face_mbr AS ( --computing the bbox of new face
			SELECT  ST_Envelope(ST_Collect(edge_geom) ) as mbr 
			FROM rings AS le  
		)
		--, new_faces as ( --inserting new faces  into face table
			INSERT INTO %1$I.face ( mbr) 
			SELECT pf.mbr
			FROM new_face_mbr AS pf  
			RETURNING face_id  ;',topology_name)  INTO face_id  USING signed_edges_of_ring ; 
 
		RETURN ;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE STRICT; 

	DROP FUNCTION IF EXISTS rc_UpdateFaceMBRFromRing(topology_name TEXT, signed_edges_of_ring INT[] , face_id int) ;
	CREATE OR REPLACE FUNCTION  rc_UpdateFaceMBRFromRing(topology_name TEXT, signed_edges_of_ring INT[]  , INOUT face_id  INT)
	AS $BODY$   
		/** @brief given a ring, update the boudnign box of the face
		@return return the face_id of the updated face
		*/
		DECLARE 
		BEGIN
		
		EXECUTE format('
		 WITH rings AS ( -- unnesting the list of edges to update
			SELECT DISTINCT ON (edge_id) abs(s_edges) AS edge_id, ed.geom AS edge_geom
			FROM   unnest ( $1)  AS s_edges
				LEFT OUTER JOIN %1$I.edge_data AS ed ON (ed.edge_id =abs(s_edges)  )
			ORDER BY edge_id
		)  
		 , new_face_mbr AS ( --computing the bbox of new face
			SELECT  ST_Envelope(ST_Collect(edge_geom) ) as mbr 
			FROM rings AS le  
		)
		--, new_faces as ( --inserting new faces  into face table
			UPDATE %1$I.face  
			SET mbr =  pf.mbr
			FROM new_face_mbr AS pf  
			WHERE face_id != 0 
			AND face_id  = $2
			RETURNING face_id  ;',topology_name)  INTO face_id  USING signed_edges_of_ring,  face_id; 
 
		RETURN ;
		END ;
	$BODY$
	LANGUAGE plpgsql VOLATILE STRICT; 

	
