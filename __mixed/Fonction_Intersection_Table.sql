-- DROP FUNCTION Fonction_Intersection_Table(text,text,text,text,text) ;

/*fonction Sql imitant le comportement de clipping de OGR Spread : clip des objets sur une zone donnée (poinçonnage)
/ INPUTS:. nom_schema_source : nom du schema dans lequel se trouve les tables à clipper, par défaut 'gwgam'
/	 . nom_table_a_clipper : nom de la table à clipper dans le schema source
	 . nom_schema_sortie : nom du schema dans lequel mettre les resultats du clipping, par défaut 'gwgam_clipped'
/	 . nom_objet_clippeur : nom de la table qui va servir de zone_clippeuse (le poiçon) (on va regarder si cette géométrie contient les objets à clipper ) valeur par défaut : 'zone_graphic_paris_selection_wgs84_area'
/	 . identifiant_objet_clippeur : identifiant textuel de la géométrie sur laquel clipper placé dans la colonne 'name', vaut par défaut la valeur 'PORTE-SAINT-MARTIN_10ART'
/
/OUTPUT:. //crée une table de même nom que celle traitémais dans le schéma de sortie//*/
CREATE OR REPLACE FUNCTION Fonction_Intersection_Table(nom_schema_source text DEFAULT 'gwgam',
nom_table_a_clipper text DEFAULT 'espacevert_wgs84_area',
 nom_schema_sortie text DEFAULT 'gwgam_clipped', 
 nom_objet_clippeur text DEFAULT 'zone_graphic_paris_selection_wgs84_area',a
 identifiant_objet_clippeur text DEFAULT 'PORTE-SAINT-MARTIN_10ART') RETURNS SETOF record  AS
$$
DECLARE /*declaration des variables pour la suite*/
	geomColumnNameClippeuse text DEFAULT 'bloublou';
	geomColumnNameClippee text DEFAULT 'blabla';
BEGIN --debut de la fonction
	RAISE NOTICE 'début de la fonction Fonction_Intersection_Table( % , % , % , % , % )',$1,$2,$3,$4,$5;

	EXECUTE 'SELECT Fonction_GetGeomColumnName('''||nom_schema_source||''' , '''|| nom_objet_clippeur||''');' INTO geomColumnNameClippeuse; -- on recupere le nom de la colonne de géometrie
	EXECUTE 'SELECT Fonction_GetGeomColumnName('''||nom_schema_source||''' , '''|| nom_table_a_clipper||''');' INTO geomColumnNameClippee; -- on récupere le nom de la colonne de géometrie
	RAISE NOTICE 'nom de la colonne geometrie de % : %,   % : % ',nom_objet_clippeur,geomColumnNameClippeuse, nom_table_a_clipper, geomColumnNameClippee;
	
	EXECUTE ' DROP TABLE IF EXISTS ' || nom_schema_sortie || '.' || nom_table_a_clipper || ' ;  ';
	 --permet de supprimer la table résultat si elle existe déjà
	EXECUTE ' CREATE TABLE ' || nom_schema_sortie || '.' || nom_table_a_clipper || ' WITH OIDS AS
	WITH zone_clippeuse AS ( SELECT * '||--definition de la zone clippeuse, c est a dire du poinçon
		'FROM ' || nom_schema_source || '.' || nom_objet_clippeur ||
		' WHERE name ILIKE ' || quote_literal( '%' || identifiant_objet_clippeur || '%')||
		'),
	zone_clippee AS (SELECT * '||--definition de la zone qu on va découper
		'FROM ' || nom_schema_source || '.' || nom_table_a_clipper ||
		'),
	resultat_intersect AS(SELECT DISTINCT zone_clippee.* ' ||--on calcul tous les objets qui intersect (dedans ou a cheval) la zone clippeuse
		'FROM zone_clippee, zone_clippeuse
		WHERE ST_Intersects( zone_clippeuse.'||geomColumnNameClippeuse||',zone_clippee.'||geomColumnNameClippee||') = TRUE
		), 
	resultat_contains AS (SELECT DISTINCT zone_clippee.* ' || --on calcul tous les objets qui sont strictement à l interieur de la zone_clippeuse
		'FROM zone_clippee, zone_clippeuse
		WHERE ST_Contains(zone_clippeuse.'||geomColumnNameClippeuse||',zone_clippee.'||geomColumnNameClippee||') = TRUE
		),
	elements_frontiere AS ( SELECT DISTINCT toto.gid , toto.'||geomColumnNameClippee||' AS ' ||geomColumnNameClippee|| --elements de la zone_clipee qui intersect mais ne sont pas entierement dedans la zone clippeuse
		' FROM (SELECT DISTINCT * FROM resultat_intersect EXCEPT SELECT * FROM resultat_contains) AS toto
		),
	resultat_intersection AS (  SELECT DISTINCT elements_frontiere.gid, ST_Intersection(elements_frontiere.'||geomColumnNameClippee||',zone_clippeuse.'||geomColumnNameClippeuse||' ) AS intersection '||--on cacul l intersection sur le plus petit nombre d elements possibles car la fonction renvoi toujours une geometrie et est plus lente
		' FROM zone_clippeuse, elements_frontiere
		)
	SELECT resultat_intersect.* , COALESCE(resultat_intersection.intersection, resultat_intersect.'||geomColumnNameClippee||') AS newgeom '||--la geometrie finale est dans newgeom, coalesce permet de remplacer la géometrie classique par celle de l objet poinconné lorsqu il y a bien eu poinçonnage
	'FROM resultat_intersection
	RIGHT OUTER JOIN resultat_intersect ON resultat_intersection.gid = resultat_intersect.gid;';

	EXECUTE ' ALTER TABLE ' || nom_schema_sortie || '.' || nom_table_a_clipper || ' DROP COLUMN '||geomColumnNameClippee||' ; ' ;  --on détruit la colonne geom qui contient les anciennes géometries
	EXECUTE ' ALTER TABLE ' || nom_schema_sortie || '.' || nom_table_a_clipper || ' RENAME COLUMN newgeom TO '||geomColumnNameClippee||' ; ' ; --on renomme la colonne newgeom qui contient les géométries de l'intersection et les autres.


	RAISE NOTICE 'fin de la fonction ';

END/*fin du block begin*/;
$$ LANGUAGE plpgsql;



SELECT Fonction_Intersection_Table('gwgam','espacevert_wgs84_area','gwgam_clipped','zone_graphic_paris_selection_wgs84_area','PORTE-SAINT-MARTIN_10ART');
