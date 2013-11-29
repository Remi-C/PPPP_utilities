

-- DROP FUNCTION Fonction_Spreading_Lines(text,text,text,text,text) ;

/* fonction Sql imitant le comportement de spreading de OGR Spread vis à vis des lgines:
/on découpe les lignes à l'interieur d'une zone et on leur ajoute le denier opoint avant le découpage a l'exterieur.
/ INPUTS:. nom_schema_source : nom du schema dans lequel se trouve les tables à clipper, par défaut 'gwgam'
/	 . nom_table_a_clipper : nom de la table à clipper dans le schema source
	 . nom_schema_sortie : nom du schema dans lequel mettre les resultats du clipping, par défaut 'gwgam_clipped'
/	 . nom_objet_clippeur : nom de la table qui va servir de zone_clippeuse (le poiçon) (on va regarder si cette géométrie contient les objets à clipper ) valeur par défaut : 'zone_graphic_paris_selection_wgs84_area'
/	 . identifiant_objet_clippeur : identifiant textuel de la géométrie sur laquel clipper placé dans la colonne 'name', vaut par défaut la valeur 'PORTE-SAINT-MARTIN_10ART'
/OUTPUT:. //crée une table de même nom que celle traitée mais dans le schéma de sortie// */
CREATE OR REPLACE FUNCTION Fonction_Spreading_Lines(nom_schema_source text DEFAULT 'gwgam',
nom_table_a_spreader text DEFAULT 'espacevert_wgs84_area',
 nom_schema_sortie text DEFAULT 'gwgam_spread', 
 nom_table_spreadeuse text DEFAULT 'zone_graphic_paris_selection_wgs84_area',
 identifiant_table_spreadeuse text DEFAULT 'PORTE-SAINT-MARTIN_10ART') RETURNS SETOF record  AS
$$
DECLARE /*declaration des variables pour la suite*/
	geomColumnNameSpreadeuse text DEFAULT 'bloublou';
	geomColumnNameSpreadee text DEFAULT 'blabla';
	
BEGIN --debut de la fonction
	RAISE NOTICE 'début de la fonction Fonction_Intersection_Table( % , % , % , % , % )',$1,$2,$3,$4,$5;

	EXECUTE 'SELECT Fonction_GetGeomColumnName('''||nom_schema_source||''' , '''|| nom_table_spreadeuse||''');' INTO geomColumnNameSpreadeuse; -- on recupere le nom de la colonne de géometrie
	EXECUTE 'SELECT Fonction_GetGeomColumnName('''||nom_schema_source||''' , '''|| nom_table_a_spreader||''');' INTO geomColumnNameSpreadee; -- on récupere le nom de la colonne de géometrie
	RAISE NOTICE 'nom de la colonne geometrie de % : %,   % : % ',nom_table_spreadeuse,geomColumnNameSpreadeuse, nom_table_a_spreader, geomColumnNameSpreadee;
	
	EXECUTE ' DROP TABLE IF EXISTS ' || nom_schema_sortie || '.' || nom_table_a_spreader || ' ;  ';
	 --permet de supprimer la table résultat si elle existe déjà

	
	--EXECUTE ' CREATE TABLE ' || nom_schema_sortie || '.' || nom_table_a_spreader || ' WITH OIDS AS
	

	RAISE NOTICE 'fin de la fonction Fonction_Intersection_Table( % , % , % , % , % )',$1,$2,$3,$4,$5;

END/*fin du block begin*/;
$$ LANGUAGE plpgsql;



SELECT Fonction_Spreading_Lines('gwgam','espacevert_wgs84_area','gwgam_spread','zone_graphic_paris_selection_wgs84_area','PORTE-SAINT-MARTIN_10ART');
