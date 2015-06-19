---------------------------------------------------------------------
--Rémi Cura 
--THALES and Telecom Paristech
--24/01/2013
--
--This function create an index for all info column in schema
-- WARNING : prototype : non tested or proofed.
----------------------------------------------------------------------
 





--fonction Sql permettant de récuperer le nom de la colonne contenant la géométrie d'une table
--INPUTS:. nom_schema_source : nom du schema dans lequel se trouve la table dont on veut récuperer le nom de geometrie
--	 . nom_table_source : nom de la table contenant la colonne géometrie dont on veut le nom
--OUTPUT:. 
--	 . geomColumnName : nom de la colonne contenant la géométrie
-- */

-- DROP FUNCTION Fonction_GetGeomColumnName(text,text) ;

CREATE OR REPLACE FUNCTION Fonction_GetGeomColumnName(nom_schema_source text DEFAULT 'public',
nom_table_source text DEFAULT '') 
RETURNS text AS
$$
DECLARE --declaration des variables pour la suite 
geomColumnName text DEFAULT 'bloublou';
BEGIN --debut de la fonction
	RAISE NOTICE 'début de la fonction Fonction_GetGeomColumnName( % , % )',nom_schema_source,nom_table_source ;

	EXECUTE '
		SELECT f_geometry_column
		FROM geometry_columns
		WHERE f_table_schema = '|| quote_literal(nom_schema_source) || '
		AND f_table_name ILIKE ' || quote_literal('%'|| nom_table_source ||'%') || '
		LIMIT 1;
	' INTO geomColumnName; 
	
	
	RAISE NOTICE 'fin de la fonction Fonction_GetGeomColumnName( % , % ), sortie : % ',nom_schema_source,nom_table_source ,geomColumnName;
RETURN geomColumnName;
END --fin du block begin ;
$$ LANGUAGE plpgsql;



--SELECT Fonction_GetGeomColumnName('gwgam'::Text,'espacevert_wgs84_area'::Text);