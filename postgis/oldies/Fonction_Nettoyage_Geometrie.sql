

DROP FUNCTION Fonction_Nettoyage_Geometrie(text) ;


/*fonction Sql permettant de nettoyer la géométrie de toutes les tables d'un schéma
/ INPUTS:. nom_schema_source : nom du schema dans lequel se trouve les tables à nettoyer, par défaut 'gwgam'
/OUTPUT:. //modifie les tables sources en corrigeant les géométries erronées sans provoquer d'erreurs de typage//*/
CREATE OR REPLACE FUNCTION Fonction_Nettoyage_Geometrie(
text DEFAULT 'gwgam_clipped')
RETURNS SETOF record  AS
$$
DECLARE /*declaration des variables pour la suite*/
	row record;
	nom_schema_source ALIAS FOR $1;
	msg_temp text;
BEGIN
	RAISE NOTICE 'début de la fonction Fonction_Nettoyage_Geométrie';
	RAISE NOTICE 'valeur des entrées : %   ',$1;
	
	FOR row IN /*toutes les tables listées dans geometry_columns qui appartiennent au bon schéma*/
		SELECT *
		FROM geometry_columns
		WHERE f_table_schema = nom_schema_source 
			AND f_table_name <> 'raster_columns' --on enleve la colonne prorpiétaire de PostGIS
	LOOP/*boucle sur les noms des tables trouvées*/
		EXECUTE 'SELECT Fonction_Nettoyage_Geometrie_Table( '|| quote_literal( nom_schema_source ) || ',' || quote_literal(row.f_table_name ) || ');'; --on nettoye les tables une par une
	END LOOP;
END;/*fin du block begin*/
$$ LANGUAGE plpgsql;




/*fonction permettant de faire une boucle sur les tables à nettoyer */
SELECT Fonction_Nettoyage_Geometrie('gwgam_clipped'::Text);
