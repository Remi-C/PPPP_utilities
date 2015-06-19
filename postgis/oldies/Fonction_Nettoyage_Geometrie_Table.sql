
--DROP FUNCTION Fonction_Nettoyage_Geometrie_Table(text,text); --nettoyage au cas ou une fonction du même nom existerait

/*fonction Sql permettant de nettoyer la géométrie d'une table sans provoquer d'erreur de type
/ INPUTS:. 'nom_schema' , nom du shcema dans lequel est la table
	 . 'nom_table' , nom de la table source
/OUTPUT:. //modifie la table source en corrigeant les géométries erronées en utilisant des types compatibles./
/WARNING : comportement non testé avec des types complexes (curves, 3D, etc)
*/
CREATE OR REPLACE FUNCTION Fonction_Nettoyage_Geometrie_Table(nom_schema text DEFAULT 'gwgam_clipped' ,
nom_table text DEFAULT 'gwgam_clipped.apurheuristiquebloc_wgs84_area' )
RETURNS SETOF record  AS
$$
DECLARE /*declaration des variables pour la suite*/
geomColumnName text DEFAULT '';
BEGIN
/*NOTE : il faudrait aller chercher le nom de la colonne de geometrie des deux tables pour bien faire , cii on suppose qu elles s appellent 'geom' toutes les 2*/
	RAISE NOTICE 'début de la fonction Fonction_Nettoyage_Geométrie_Table ( % , % ) ',$1,$2;

	EXECUTE 'SELECT Fonction_GetGeomColumnName('''||nom_schema||''' , '''||nom_table||''');' INTO geomColumnName;
	
	EXECUTE 'WITH a_nettoyer AS (SELECT DISTINCT *
		FROM  ' || nom_schema|| '.'|| nom_table || ' ),
		geom_nettoyee AS ( SELECT DISTINCT a_nettoyer.gid, ST_MakeValid( a_nettoyer.'|| geomColumnName ||') AS geom
		FROM a_nettoyer
		WHERE ST_IsValid(geom) <> TRUE
		),
		geom_nettoyee_typee AS (SELECT DISTINCT geom_nettoyee.gid,
			CASE --on elimine les problèmes possibles de conflit de typage
				WHEN GeometryType(a_nettoyer.geom) ILIKE GeometryType(geom_nettoyee.geom) --pas de conflit de typage
				THEN geom_nettoyee.geom  --cas normal
				ELSE--cas de conflit de typage
					 CASE 
						WHEN GeometryType(a_nettoyer.geom) NOT ILIKE ''GEOMETRYCOLLECTION'' -- la geometry source n est pas une collection on force le typage
						THEN ST_CollectionExtract(geom_nettoyee.geom,St_Dimension(a_nettoyer.geom)+1) -- on convertie le type de géometrie obtenue comme identique à celui de la géométrie source
						ELSE ST_Force_Collection(geom_nettoyee.geom) --la geometrei source est une collection, on transforme le resultat en geometrie collection
					 END	
			END
			AS geom
			FROM a_nettoyer, geom_nettoyee 
			WHERE a_nettoyer.gid = geom_nettoyee .gid
		) 
		UPDATE ' || nom_schema || '.'|| nom_table || ' AS a_nettoyer SET geom = geom_nettoyee_typee.geom
		FROM geom_nettoyee_typee
		WHERE geom_nettoyee_typee.gid = a_nettoyer.gid ;' 
	; 
END/*fin du block begin*/;
$$ LANGUAGE plpgsql;

SELECT Fonction_Nettoyage_Geometrie_Table('gwgam'::Text, 'apurheuristiquebloc_wgs84_area'::Text);
