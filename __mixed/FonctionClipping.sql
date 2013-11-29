
/*fonction Sql imitant le comportement de clipping de OGR Spread : clip des objets sur une zone donnée
/ INPUTS:. nom_schema_source : nom du schema dans lequel se trouve les tables à clipper, par défaut 'gwgam'
/	 . nom_schema_sortie : nom du schema dans lequel mettre les resultats du clipping, par défaut 'gwgam_clipped'
/	 . identifiant_objets_a_clipper : identifiant textuel plac édans la colonne 'traitement' qui permet de reconnaitre les objets à clipper, par défaut vaut 'plani2clip'
/	 . nom_objet_clippeur : nom de la table qui va servir de clippeur (on va regarder sir cette géométrie contient les objet à clipper ) valeur par défaut : 'zone_graphic_paris_selection_wgs84_area'
/	 . identifiant_objet_clippeur : identifiant textuel de la géométrie sur laquel clipper placé dans la colonne 'name', vaut par défaut la valeur 'PORTE-SAINT-MARTIN_10ART'
/
/OUTPUT:. //crée des tables aux noms identiques à ceux traité dans le schéma de sortie//
/ */

-- DROP FUNCTION FonctionClipping(text,text,text,text) ;

CREATE OR REPLACE FUNCTION FonctionClipping(nom_schema_source text DEFAULT 'gwgam',
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
	FOR row IN SELECT tablename FROM pg_tables WHERE schemaname = nom_schema_source AND tablename<>'spatial_ref_sys' /*exclusion d'une table crée et maintenu par PostGIS*/
	LOOP/*boucle sur toutes les tables*/
		EXECUTE 'SELECT EXISTS (SELECT 1 FROM ' /*on selectionne celles contenant l'identifiant_objet_a_clipper*/
		|| nom_schema_source
		|| '.'
		|| row.tablename
		|| ' WHERE '
		|| ' traitement = '
		|| quote_literal(identifiant_objet_a_clipper)
		||' LIMIT 1) '
		|| ';'
		INTO est_a_clipper;
		IF est_a_clipper = TRUE THEN
			/*on clip la table : on récupere les objets qui sont à l'interieur de la zone et on les mets dans une nouvelle table dans le schéma spécifié*/
			EXECUTE 'DROP TABLE IF EXISTS '--destruction d'une eventuelle table de résultat dans le schema de sortie
			|| nom_schema_sortie
			|| '.'
			|| row.tablename 
			|| ';'
			|| ' CREATE TABLE ' -- creation d'une table de meme nom dans le schema de sortie avec els resultats du clipping
			|| nom_schema_sortie
			|| '.'
			|| row.tablename 
			|| ' AS '
			||'( SELECT DISTINCT table_a_clipper.* FROM '  /*on selectionne celles contenant l'identifiant_objet_a_clipper*/
			|| nom_schema_source 
			|| '.'
			|| row.tablename 
			|| ' AS table_a_clipper, ' --definition avec bon schema de la table_a_clipper
			|| nom_schema_source
			|| '.'
			|| nom_objet_clippeur
			|| ' AS table_clippeuse' --definition avec bon schema de la table_clippeuse
			|| ' WHERE '
			|| 'table_a_clipper.traitement = '
			|| quote_literal(identifiant_objet_a_clipper) --on vérifie pour chaque ligne que l'objet est a clipper
			||' AND '
			|| 'table_clippeuse.name ILIKE ' 
			|| quote_literal('%' || identifiant_objet_clippeur || '%') --on ne clip que sur les objets de la table_clippeuse qui on pour identifiant identifiant_objet_clippeur
			|| ' AND ST_Contains( table_clippeuse.geom, table_a_clipper.geom ) = TRUE) ; ' ; --on effectue le clipping a proprement parlé. NOTE : attention aux comportements à la frontière
		ELSE /*cas où on ne doit pas clipper la table*/
			NULL; --on ne fait rien
		END IF; /*fin du if sur le fait que la table soit à clipper*/
		
		RAISE NOTICE 'la table 	◄┘%┌■		contient  % : 	▀%▀',row.tablename::text,identifiant_objet_a_clipper,est_a_clipper;
		
	END LOOP;

END/*fin du block begin*/;
$$ LANGUAGE plpgsql;



SELECT FonctionClipping();
