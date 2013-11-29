/*fonction Sql imitant le comportement de clipping de OGR Spread : clip des objets sur une zone donnée
/ INPUTS:. nom_schema_source : nom du schema dans lequel se trouve les tables à clipper, par défaut 'gwgam'
/	 . nom_schema_sortie : nom du schema dans lequel mettre les resultats du clipping, par défaut 'gwgam_clipped'
/	 . identifiant_objets_a_clipper : identifiant textuel plac édans la colonne 'traitement' qui permet de reconnaitre les objets à clipper, par défaut vaut 'plani2clip'
/	 . nom_objet_clippeur : nom de la table qui va servir de clippeur (on va regarder sir cette géométrie contient les objet à clipper ) valeur par défaut : 'zone_graphic_paris_selection_wgs84_area'
/	 . identifiant_objet_clippeur : identifiant textuel de la géométrie sur laquel clipper placé dans la colonne 'name', vaut par défaut la valeur 'PORTE-SAINT-MARTIN_10ART'
/
/OUTPUT:. //crée des tables aux noms identiques à ceux traité dans le schéma de sortie//
/ */

-- DROP FUNCTION Fonction_Intersection(text,text,text,text,text) ;

CREATE OR REPLACE FUNCTION Fonction_Intersection(nom_schema_source text DEFAULT 'gwgam',
 nom_schema_sortie text DEFAULT 'gwgam_clipped', 
 identifiant_objet_a_clipper text DEFAULT 'plani2clip', 
 nom_objet_clippeur text DEFAULT 'zone_graphic_paris_selection_wgs84_area',
 identifiant_objet_clippeur text DEFAULT 'PORTE-SAINT-MARTIN_10ART') RETURNS SETOF record  AS
$$
DECLARE /*declaration des variables pour la suite*/
	row record;
	est_a_clipper boolean DEFAULT false;
BEGIN
	RAISE NOTICE 'début de la boucle';
	FOR row IN /*toutes les tables listées dans geometry_columns qui appartiennent au bon schéma*/
		SELECT *
		FROM geometry_columns
		WHERE f_table_schema = nom_schema_source 
			AND f_table_name <> 'raster_columns' --on enleve une colonne propriété de PostGIS
	LOOP/*boucle sur toutes les tables contenant une géométrie et dans le schéma défini*/
		EXECUTE 'SELECT EXISTS (SELECT 1 FROM ' /*on selectionne celles contenant l'identifiant objet_a_clipper*/
		|| nom_schema_source
		|| '.'
		|| row.f_table_name
		|| ' WHERE '
		|| ' traitement = '
		|| quote_literal(identifiant_objet_a_clipper)
		||' LIMIT 1) '
		|| ';'
		INTO est_a_clipper; 
		IF est_a_clipper = TRUE THEN --cas où on doit clipper 
			EXECUTE  'SELECT Fonction_Intersection_Table(' 
			|| quote_literal(nom_schema_source) 
			|| ',' || quote_literal(row.f_table_name )
			|| ',' || quote_literal(nom_schema_sortie )
			|| ',' || quote_literal(nom_objet_clippeur )
			|| ',' || quote_literal(identifiant_objet_clippeur )
			|| '); ';

			
		ELSE /*cas où on ne doit pas clipper la table*/
			NULL; --on ne fait rien
		END IF; /*fin du if sur le fait que la table soit à clipper*/
		
		RAISE NOTICE 'fin intersection avec table %', row.f_table_name;
		
	END LOOP;

END/*fin du block begin*/;
$$ LANGUAGE plpgsql;



SELECT Fonction_Intersection('gwgam',
'gwgam_clipped', 
 'plani2clip', 
 'zone_graphic_paris_selection_wgs84_area',
 'PORTE-SAINT-MARTIN_10ART');
