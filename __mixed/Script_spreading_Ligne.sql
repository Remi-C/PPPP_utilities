/*
Rémi Cura 20 08 2012
THALES TRAINING AND SIMULATION
INTERNE

WARNING : prototype : non testé end ehors de quelques cas. Comportements à la frontière non garanti, cas pathologiques non examiné, no optimisé

Ce script permet de simuler le comportement de OGR SPread vis à vis des lignes dans les dossiers plani2spread
Les lignes sont découpées pour ne garder que la partie interne à la zone de selection, plus les derniers points avant le passage de frontière, afin de garder un visuel cohérent.

Le déroulement est le suivant : 
_on définie la zone spreadeuse, les lignes a spreade, on cree leurs decompositions en points, etc.
_On travaille sur les lignes qui franchissent la frontière : on les coupe au niveau de la frontiere de la zone spreadeuse, puis on réuni ces parties afin d'obtenir 
des lignes completes (ie avec en plus le point de l'intersection avec la frontiere).
On cree ensuite de nouvelles lignes qui sont les parties interieurs à la zone speradeuse des lignes qu on a coupé précédement, elles formeront la base du resultat.
On calcul ensuite les points qui sont avant/après les points sur la l'intersection avec la frontiere et on selectionne ceux qui sont à l'exterieur.
On ajoute ces points aux lignes du resultat, puis on enleve les points sur l'intersection avec la frontiere qu'on avait artificiellement introduit.
Enfin on ajour au resultat le reste des lignes qui étaient à l'interieur mais qui n'intersectaient pas la frontiere.

NOTE : la solution choisi est complexe, mais jsutifié dans le sens ou la fonction CoorodnnéesdunPoint2sonIndice() n'existe pas, et de plus il y a toujours al possibilité qu'une ligne n'ai aucuns points initialement à l'interieur de la zone mais que pourtant elle passe dedans. 
NOTE: les autres méthodes exploré  : utiliser ST_Intersection pour récuperer directement les parties ninterieur : abandonnée à cause du problème de l'index : comment trouver à quel index ajouter les points exterieurs
NOTE : utiliser ST_LineMerge sur ST_Intersection ou sur des ensemble points/lignes : abandonnée car problème de précision avec en sortie des multilignes au lieu de lignes


WARNING : plusieurs passage severement sous-optimaux, on peut gagner facilement bcp de performance en diminuant le nombre de calculs, voir dans les commentaires
*/



DROP TABLE IF EXISTS gwgam_spread.lignes_test ;  		--instructions permettant de creer une table et donc de visualiser le resultat dans QGIS
CREATE TABLE gwgam_spread.lignes_test WITH OIDS AS		--idem



WITH lignes_sources AS ( -- les ligne à spreader, définies par une table
	SELECT gid, (ST_Dump(geom)).geom AS geom
	FROM gwgam.passagepieton_wgs84_centerline
	WHERE geom IS NOT NULL --test supplémentaire en protection
),
zone_spreadeuse AS ( -- la zone spreadeuse
	SELECT zone.gid, (ST_Dump(zone.geom)).geom AS geom
	FROM gwgam.zone_graphic_paris_selection_wgs84_area AS zone
	WHERE name ILIKE '%PORTE-SAINT-MARTIN_10ART%'
),
ensemble_de_travail AS (  -- les lignes a spreader réduites à celles qui croisent la frontière : permet de diminuer le nombres de calcul
	SELECT lignes_sources.gid , (ST_Dump(lignes_sources.geom)).geom AS geom
	FROM lignes_sources, zone_spreadeuse
	WHERE 	ST_Crosses(lignes_sources.geom, zone_spreadeuse.geom) <> FALSE --on ne garde que les lign's qui croisent la frontiere

),
lignes_coupees AS (-- on va utiliser la fonction ST_Split pour couper les lignes avec la zone , on obtiendra ainsi une des bouts de lignes qui seront dedans ou dehors :
	SELECT DISTINCT  ensemble_de_travail.gid, (ST_Dump(ST_Split(ensemble_de_travail.geom,ST_Boundary( zone_spreadeuse.geom)))).geom AS geom
	FROM zone_spreadeuse, ensemble_de_travail
),
lignes_coupees_numerotees AS( --on numérote les lignes coupées car plusieurs lignes pourraient avoir le même GID (cas de multiple intersections pour une ligne)
	SELECT row_number() OVER (PARTITION BY 1+1 ) AS lignes_coupees_gid , lignes.* 
	FROM lignes_coupees AS lignes
),
liste_points_coupees AS ( -- on décompose les lignes coupees en points pour la suite des calculs
	SELECT DISTINCT lignes.lignes_coupees_gid, lignes.gid AS gid, (ST_DumpPoints(lignes.geom)).geom AS geom, (ST_DumpPoints(lignes.geom)).path AS path
	FROM lignes_coupees_numerotees AS lignes
),
lignes_completees AS (-- On reuni maintenant de reunir les parties coupées par ST_LineMerge, le but de l'opération est de récuperer des lignes simples identiques aux lignes sources mais avec le point de l'intersectiona vec la frontiere de la zone spreadeuse en plus
	SELECT lignes.gid, ST_LineMerge(ST_Union(lignes.geom)) AS geom
	FROM lignes_coupees AS lignes
	GROUP BY lignes.gid --essentiel, on essaye de limiter les cas
),
liste_points_completees AS ( -- liste des points constituants les lignes completées, utile pour la suite des calculs
	SELECT DISTINCT lignes.gid AS gid, (ST_DumpPoints(lignes.geom)).geom, (ST_DumpPoints(lignes.geom)).path
	FROM lignes_completees as lignes
),
liste_points AS ( --les points contenu dans les lignes qui nous interessent car elles intersectent la frontiere
	SELECT DISTINCT lignes.gid, (ST_DumpPoints( lignes.geom)).geom, (ST_DumpPoints( lignes.geom)).path --NOTE : choix d ecriture sous optimal : on appel deux fois la fonction Dump, on peut contourner facilement mais l'ecriture est plus longue
	FROM ensemble_de_travail AS lignes
),
points_sur_la_frontiere AS (--detection des points sur la frontiere des lignes completees, par difference avec les lignes originales 
--on transforme toutes les lignes en points et on fait la différence des 2 ensembles
	SELECT  DISTINCT intersection.gid AS gid, intersection.geom::geometry AS geom
	FROM 	
		(
			(	
				(SELECT points.gid AS gid, points.geom::Text AS geom --NOTE : subtilité importante : on fait la comparaison sur la representation texte de la geometrie et non sur la géometrie car sinon la comparaison se fait sur les bounding boxes, et des points proches risqueraient d'être confondu en raison de la limite de precision des bboxs
				FROM liste_points_completees AS points)	
			)
			EXCEPT
				(SELECT points.gid AS gid, points.geom::Text AS geom
				FROM liste_points AS points )	
		) AS intersection
),
points_sur_la_frontiere_avec_path AS( -- deuxième couche qui permet de rajouter le path du point sur la frontiere dans le linestring dont il est issu.
					--NOTE : on peut faire les 2 d'un coup en integrant le joint dans l'instruction précedante
	SELECT DISTINCT ON (geom)*
	FROM 
	(
		SELECT DISTINCT *
		FROM points_sur_la_frontiere
		LEFT OUTER JOIN liste_points_completees USING (gid, geom)
	) as jointure

),
lignes_coupees_dedans AS( -- on selection les lignes qu'on a coupé plus tôt et qui sont à l'interieur de la zone. Ceci va constituer la base de la solution
	SELECT lignes.*
	FROM lignes_coupees_numerotees AS lignes, zone_spreadeuse
	--WHERE 1=1
	--WHERE ST_Relate(ST_Scale(zone_spreadeuse.geom,10000000,10000000,0),ST_Scale(lignes.geom,10000000,10000000,0), '1********') = TRUE
	WHERE ST_Intersects(zone_spreadeuse.geom,St_Line_Interpolate_Point(lignes.geom,0.5 )) = TRUE --NOTE : WARNING TODO très mauvaise idéee en terme de performance 
	--: pas besoin de faire un test aussi compliqué qui demande bcp de calcul, on pourrait faire plus simple mais attention aux cas particuliers.
	--probleme : toutes les fonctions usels (Contains, Within, Relates, etc) ne marcheront pas car elles agissent sur les bbox qui sont d'une précision limitée
),
liste_points_coupees_dedans AS ( --on décompose les lignes coupées à l'interieur de la zone en points
	SELECT DISTINCT lignes.lignes_coupees_gid, lignes.gid AS gid, (ST_DumpPoints(lignes.geom)).geom AS geom, (ST_DumpPoints(lignes.geom)).path AS path
	FROM lignes_coupees_dedans AS lignes
),
tableau_correspondance AS( --tableau permettant de faire le lien entre les lignes completées et les lignes coupées à l'interieur de la zone, et notamment du path respectif du meme point sur la frontiere,  qui ovnt servir à faire la solution
	SELECT  frontiere.path AS completees_path, frontiere.gid, frontiere.geom, dedans.path AS dedans_path, dedans.lignes_coupees_gid
	FROM   points_sur_la_frontiere_avec_path AS frontiere LEFT OUTER JOIN liste_points_coupees_dedans AS dedans ON  frontiere.gid = dedans.gid AND frontiere.geom::Text = dedans.geom::Text 

),
points_p_a_ajouter AS(--on calcul le point situé avant les points sur la frontiere
	SELECT lignes_completees.gid AS gid, tableau_correspondance.lignes_coupees_gid,  ST_PointN(lignes_completees.geom, tableau_correspondance.completees_path[1]-1) AS geom, 'avant'::Text AS type_position
	FROM tableau_correspondance LEFT OUTER JOIN lignes_completees USING (gid) 

),
points_a_a_ajouter AS(--on calcul le point situé après les points sur la frontiere
	SELECT lignes_completees.gid AS gid, tableau_correspondance.lignes_coupees_gid,  ST_PointN(lignes_completees.geom, tableau_correspondance.completees_path[1]+1) AS geom, 'apres'::Text AS type_position
	FROM tableau_correspondance LEFT OUTER JOIN lignes_completees USING (gid) 
),
points_a_ajouter AS(--synthèse des deux liste de points a ajouter, on exclu les points qui sont à l'interieur de la zone, puisqu on veut ajouter le dernier poioint avant d entrer dans la zone
	SELECT points.*
	FROM 
	(	
		SELECT * FROM points_p_a_ajouter
		UNION DISTINCT
		SELECT * FROM points_a_a_ajouter
	) AS points, zone_spreadeuse
	WHERE 
		points.geom IS NOT NULL --on enleve les points nul du a une erreur d index
		AND
		ST_Contains(zone_spreadeuse.geom,points.geom) <> TRUE --on enleve les points qui sont a l interieur de la zone
),
lignes_coupees_dedans_avec_ajout_1 AS (--on ajoute les points avant la frontier a l index qui convient
	SELECT dedans.gid, dedans.lignes_coupees_gid, ST_AddPoint(dedans.geom, points.geom, 0 ) AS geom, points.type_position
	FROM lignes_coupees_dedans AS dedans, points_a_ajouter AS points
	WHERE points.lignes_coupees_gid = dedans.lignes_coupees_gid
	AND points.type_position = 'avant'
),
lignes_coupees_dedans_avec_ajout_2 AS (--on ajoute les points après la frontier a l index qui convient
	SELECT dedans.gid, dedans.lignes_coupees_gid, ST_AddPoint(dedans.geom, points.geom, -1 ) AS geom, points.type_position
	FROM lignes_coupees_dedans AS dedans, points_a_ajouter AS points
	WHERE points.lignes_coupees_gid = dedans.lignes_coupees_gid
	AND points.type_position = 'apres'
),
lignes_resultats_1 AS (--on fusionne les lignes modifiées avec celles auxquelle on n'a pas rajouté de points
	--prendre la ligne modifiée si elle existe, la normale sinon
	SELECT dedans.lignes_coupees_gid, dedans.gid, COALESCE(ajout_1.geom,dedans.geom) AS geom
	FROM lignes_coupees_dedans AS dedans LEFT OUTER JOIN lignes_coupees_dedans_avec_ajout_1 AS ajout_1 USING (lignes_coupees_gid)	
),
lignes_resultats_2 AS (--on fusionne les lignes modifiées pour le 2em type de points avec celles deja fusionnees
	--prendre la nouvelle ligne modifiée si elle existe, l'ancienne modifié sinon
	SELECT dedans.lignes_coupees_gid, dedans.gid, COALESCE(ajout_2.geom,dedans.geom) AS geom
	FROM lignes_resultats_1  AS dedans LEFT OUTER JOIN lignes_coupees_dedans_avec_ajout_2 AS ajout_2 USING (lignes_coupees_gid)	
),
liste_points_resultats_2 AS( --liste des points contenus dans les lignes du resultat
	SELECT DISTINCT lignes.lignes_coupees_gid, lignes.gid AS gid, (ST_DumpPoints(lignes.geom)).geom AS geom, (ST_DumpPoints(lignes.geom)).path AS path
	FROM lignes_resultats_2 AS lignes
),
points_a_supprimer AS (--on cherche maintenant les points (sur la frontiere) qu'on aurait artificiellement ajouté, sauf s'ils sont au début ou en bout de chaine (sécurité).
		--NOTE : le tableau de correspondance n est plus utilisable car ona  ajoute eds points, les indexs ont changes, il n'est pas mis à jour
	SELECT  DISTINCT l_r_2.lignes_coupees_gid, intersection.gid AS gid, intersection.geom::geometry AS geom, l_r_2.path
	FROM 	
		(
			(	
				(SELECT DISTINCT points.gid AS gid, points.geom::Text AS geom
				FROM  liste_points_resultats_2 AS points)	
			)
			EXCEPT
				(SELECT DISTINCT points.gid AS gid, points.geom::Text AS geom
				FROM liste_points AS points )	
		) AS intersection 
		LEFT OUTER JOIN liste_points_resultats_2 AS l_r_2 ON l_r_2.gid = intersection.gid AND l_r_2.geom::Text = intersection.geom --permet de rajouter le PATH et le lignes_coupees_gid
),
lignes_resultats_3  AS ( --on enleve maintenant les points (sur la frontiere) qu'on aurait artificiellement ajouté, sauf s'ils sont au début ou en bout de chaine (sécurité).
	SELECT l_r_2.lignes_coupees_gid, l_r_2.gid, ST_RemovePoint(l_r_2.geom, p_a_s.path[1]-1) AS geom--, l_r_2.geom AS testgeom
	FROM points_a_supprimer AS p_a_s, lignes_resultats_2 AS l_r_2 
	WHERE 	p_a_s.gid = l_r_2.gid 
		AND p_a_s.lignes_coupees_gid = l_r_2.lignes_coupees_gid 
		--AND p_a_s.path[0] <> ST_NPoints(l_r_2.geom) 
		--AND p_a_s.path[0] <> 1
),
lignes_interieur_strictement AS( --on cherche les lignes sitrctement a l interieur de la zone spreadeuse, et qui n'intersetent pas la frontiere
	SELECT lignes_sources.gid , (ST_Dump(lignes_sources.geom)).geom AS geom
	FROM lignes_sources, zone_spreadeuse
	WHERE ST_Intersects(lignes_sources.geom, zone_spreadeuse.geom) = TRUE
	EXCEPT DISTINCT --on enleve les lignes qui intersecte la frontiere et qu on a deja longuement traitees et ajoutes
	SELECT ensemble_de_travail.* FROM ensemble_de_travail
),
lignes_resultats_4 AS( -- on cree le resultat final : les lignes qui intersectent la frontieres auxquelles ont a ajouter le dernier points avant dentrer / sortir de la zone, PLUS les lignes à l'interieur de la zone strictement qu'on ne modifie pas.
	SELECT l_union.gid, l_union.geom 
	FROM
		(
		(SELECT l_r_3.gid, l_r_3.geom 
		FROM lignes_resultats_3 AS l_r_3)

		UNION DISTINCT
		(SELECT l_i_s.gid, l_i_s.geom 
		FROM lignes_interieur_strictement AS l_i_s)
	) AS l_union
)
--ligne de debug de visualisation, l identifiant unique evite lesbugs sur qgis, le st_astext sert uiquement au debug
SELECT DISTINCT resultat.*   --,row_number() OVER (ORDER BY resultat.geom ) AS newgid,  ST_AsText(resultat.geom) as textgeom
FROM  lignes_resultats_4  AS resultat
ORDER BY geom;

--SELECT UpdateGeometrySRID('gwgam_spread','lignes_cousues','geom',4326);


--SELECT DISTINCT row_number() OVER (ORDER BY resultat.geom) AS newgid, resultat.*
--FROM  points_par_except_distinct AS resultat;
