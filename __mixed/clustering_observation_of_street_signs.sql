

---------------------------------------------------------------
---Rémi-C Thales-IGN 6/08/2013
---
---#A simple algorithm for solving The ░▒▓line of Sight Problem▓▒░ #
---
--
--this sql commands are not supposed to be run in a row but more command by command while controlling the result
------------------------------------------------------------------


--------
--##Description of the problem##
-- - The problem is as follow : Ina  3D space, we have a number of observations, each observation being that an immobile object has been seen form a given point. An observation can be a mistake. There are many object, we suppose there are identical except there localisation
-- - many observation can be mad eform the same point, but observation can't see trough an object.
-- - Given the observation, we want to find the number of object and the position of each objects
--
-- - There is room for mistake with a simple model :  border are crisp, but observation are considered +- an error possibility
-- - this algorithm could be quite easily converted to fuzzyness by adding a weighted mesure of fuzzyness and taking it into account as weight during the algorithm.
-- -
--
-- - A real life example of line of sight problem :
--	We work on images acquired by cameras mounted on a vehicule (street images).
--	We use an image detector to detect street signs
--	
--
-- 
--##How does the script works?##
/*
	--Hypothèse de Bahman :
		1m<=distance véhicule panneau <= 80m,
		précision observations 10cm (plutôt 20cm dans les vraies données à mon avis).
		De plus un panneau 3D ne peut être placé de façon fiable qu'avec 3 observations (2 théorique, 3 à cause de l'incertitude).
		une observation ne peut détecter au plus qu'un panneau (les panneaux sont opaques)
	A partir de la je fais une résolution géométrique puis un bricolage "combinatoire"

	Partie géométrique :
		pour toutes les observations (OG : 693)
			IE segments 3D de 80 m de long fourni par Bahman sous la forme de point début, point fin
		(_calculer les composantes connexes pour lancer l'algo sur chaque composante connexe)
			(je fais le calcul mais je ne lance pas sur chaque c-connexe car mon code n'est pas automatisé proprement)
			(OG : 100 à 300ms, de 10aine a 100aine de c-connexe)
		(_les couper selon le bati ) (OG bati : 30k géométries , 1.5sec)
			(pour l'instant : enlevé car une fonction postgis diminue la précision en Z)
		_calculer les auo-intersection à 10cm près (  le segment minimal reliant un couples d'observations dont la distance minimale est inférieur ou égal à 10cm)
			: la combinatoire est violente mais il y a les indexes (OG : 7k intersections, 35 sec)
		_ne garder que les auto-intersections qui possèdent au moins 2 autres auto-intersections dans un voisinage de 10cm :
			combinatoire encore pire (OG : 13sec 120k pour les possibilités, 80 sec 6.5k pour le résultat filtré)
			Ces auto-intersections sont en fait les lieux de probabilités de présence de panneaux 3D.Ce sont des cluster potentiels. Pour la suite je parle de "cluster", le mot est interchangeable avec "panneaux 3D".

	Partie "combinatoire"
		On a bcp de panneaux 3D potentiels (6.5k), on veut une technique pour les regrouper sans altérer l'info spatiale (typiquement : ne pas fusionner deux panneaux proches).
		l'algo est le suivant
		_Pour tous les clusters potentiels : trier par nombre de cluster potentiels à moins de 10cm descendant.
		_construire des clusters candidats en prenant au fur et à mesure les clusters les plus peuplé des clusters potentiels et en enlevant ceux qui sont inclus dans les clusters candidats.
			(note : c'est une sorte d'algo de graphe qui revient à trouver les nœuds très connecté et à les remplacer par un aglomerat de eux et leur voisinage immediat.
			(OG : 3 sec, 126 cluster candidats)
			On se retrouve avec 126 clusters candidats qui sont déjà pas mal.
		_pour chaque observation : choisir au max un cluster candidat, avec comme critère de prendre celui qui a le plus de support (où il y a bcp d'intersections autour de lui), avec un support >=2, et à plus d'un mètre de la position de la photo
			Cela revient à dire qu'une obs ne peut participer qu'à un panneaux 3D.
		_réunir les clusters candidats choisi  :ce sont les clusters proposés, il s'agit de la position des panneaux 3D que l'algo propose.
*/
--
--------

--Travail sur les données de Bahman

	--CREATE SCHEMA
	CREATE SCHEMA reco_panneaux;

	--pratique
	SET search_path TO reco_panneaux,public;
	--creation de la table
	DROP TABLE IF EXISTS segments;
	CREATE TABLE segments (
		gid text,
		x1 numeric,
		y1 numeric,
		z1 numeric,
		x2 numeric,
		y2 numeric,
		z2 numeric
	);

	--import es données
	COPY segments FROM '/media/sf_PC_in_DB/poc_pc_in_db/segments.seg2D'
	WITH CSV DeLIMITER '	';

	--visu
	SELECT *
	FROM segments;

	--suppression des colonnes
	ALTER TABLE segments DROP COLUMN IF EXISTS point1;
	ALTER TABLE segments DROP COLUMN IF EXISTS point2;
	ALTER TABLE segments DROP COLUMN IF EXISTS segment;
	ALTER TABLE segments DROP COLUMN IF EXISTS rec;
	ALTER TABLE segments DROP COLUMN IF EXISTS id;

	--ajout des colonnes
	ALTER TABLE segments ADD COLUMN point1 geometry(PointZ,931008);
	ALTER TABLE segments ADD COLUMN point2 geometry(PointZ,931008);
	ALTER TABLE segments ADD COLUMN segment geometry(LineStringZ,931008);
	ALTER TABLE segments ADD COLUMN rec geometry(PolygonZ,931008);
	ALTER TABLE segments ADD COLUMN id SERIAL;

	--peuplement des colonnes
	UPDATE segments SET point1=ST_SetSRID(ST_MakePoint(x1,y1,z1),931008);
	UPDATE segments SET point2=ST_SetSRID(ST_MakePoint(x2,y2,z2),931008);
	UPDATE segments SET segment=ST_SetSRID(ST_MakeLine(point1,point2),931008);

	--UPDATE segments SET rec=ST_Buffer(segment, 0.20,4);--pire des cas : 0.10m


	--ajout des indexs
	CREATE INDEX segment_point1_nd_index  ON segments USING GIST (point1 gist_geometry_ops_nd);
	CREATE INDEX segment_point2_nd_index  ON segments USING GIST (point2 gist_geometry_ops_nd);
	CREATE INDEX segment_segment_nd_index  ON segments USING GIST (segment gist_geometry_ops_nd);

	--nettoyage
	VACUUM ANALYZE segments;

	--self intersection en 3D, à 10 cm pres. : 14682
	SELECT t1.gid, t2.gid
	FROM segments as t1, segments as t2
	WHERE t1.gid!=t2.gid
		ANd 
		ST_3DDWithin(t1.segment, t2.segment, 0.2)=TRUE;


		

	-------WARNING-------Actuellement la commaned sql suivante introduie une erreur, NE PAS UTILISER, utiliser la commande au dessus à la place------------------------
	--On va couper les lignes en utilisant le bati de la BD topo, en gardant seulement le bout de lign qui contient le point1
	--on coupe seulement les lignes qui intersectent le bati, les autres ne sont pas modifiées
		--on les filtres sur leur taille et la présence du point de début (on veut eviter le test st_crosses qui est très long à calculer)
		/*
		DROP TABLE IF EXISTS lignes_coupees_filtrees; --temps de calcul : 3.5sec
		CREATE TABLE lignes_coupees_filtrees AS (
		WITH lignes_coupees AS ( --le resultat est toutes les segments issues du coupage, on va les filtrer pour n'en garder qu'un par identifiant
		SELECT gid, geom as geom
		 FROM(	
			 SELECT segments.gid AS gid, (ST_Dump(ST_Split(segment,ST_ExteriorRing((ST_Dump(geom)).geom)))).geom AS geom
			FROM reco_panneaux.segments, bdtopo.bati_tous as b_i
			WHERE ST_Crosses(segment,b_i.geom)=TRUE
			)as toto
		),
		lignes_coupees_filtrees AS (
			SELECT DISTINCT ON (l_c.gid) l_c.gid AS gid, l_c.geom AS geom--, SUBSTRING(l_c.gid FROM '.{9}$') AS id --filtrage pour garder une seule ligne par gid : en l'occurence, la plus courte
			FROM lignes_coupees AS l_c, segments
			WHERE ST_Intersects(ST_Force_2D(l_c.geom),ST_Force_2D(point1))=TRUE --filtrage pour garder la ligne qui contient le point de départ de l'observation
			ORDER BY l_c.gid ASC,ST_Length(geom) ASC
			),
		lignes_non_incluses AS (--on recupere les lignes orrignels qui n'ont pas été modifiées : note : on pourrait uassi le fair eavec un except sur gid dans sub querry, mais il faudrait faire un left join après, pas sur que ça vaille le coup
			SELECT gid, segment AS geom
			FROM reco_panneaux.segments AS s
			WHERE gid NOT IN (
				SELECT gid FROM lignes_coupees_filtrees)
		)--maintenant on réuni les lignes incluses et non incluse en faisant un union
			--technique avec le union note : il y aura des duplicats si la partition entre lignes_non_inlcuses et lignes_coupees_filtrees n'est pas strict
		SELECT *
		FROM (
			SELECT *
			FROM lignes_non_incluses
			UNION 
			SELECT * 
			FROM lignes_coupees_filtrees 
			) AS the_union
		);
		*/
	----
	--On dispose maintenant des observations réduites grâce aux intersections sur le bati
	--On va calculer les points d'intersections 2 à 2 en 3D puis les fusionners.
	--On calcul les segments 3D les plus courts entre les segmentsrd filtrer pour enlever le bati, mais on dirait qu'une des fonctions utilisées pour ce faire introduit une erreur de précision.
		-- du coup, cette definition de la table ne tient pas compte du bati
		--note : on peut rajouter un petit etage pour permettre de supprimer les duplicats
		--en effet dans notre cas (gid1,gid2) = (gid2,gid1) . Le workaround est d'ecrire les doublets en ordonnant les valeurs interne (pettit, grand), et ensuite de filtrer par un distinct sur le doublet
			DROP TABLE IF EXISTS lignes_intersection; --sans distinct : 13880 lignes en 68 sec|| avec distinct :6940lignes , 41sec
			CREATE TABLE lignes_intersection AS (
				WITH liste_intersection AS (-- il s'agit des couples de lignes qui s'intersectent à 10cm près.
					SELECT DISTINCT ON (least(t1.id,t2.id),greatest(t1.id,t2.id) ) t1.gid AS gid1, t1.segment AS geom1, t2.gid AS gid2, t2.segment AS geom2
					FROM segments as t1, segments as t2
					WHERE t1.gid!=t2.gid
						AND
					ST_3DDWithin(t1.segment, t2.segment, 0.10)=TRUE
				),
				segments_pas_au_debut AS(
				SELECT row_number() over () AS gid, li.gid1 , li.gid2, ST_3DShortestLine(li.geom1,li.geom2) as geom
				FROM liste_intersection AS li
				)
				SELECT DISTINCT ON (gid) spad.*
				FROM segments_pas_au_debut AS spad, segments AS s
				WHERE ST_3DDWithin(spad.geom,s.point1,1.0)=FALSE --on ajoute une condition pour que les intersections ne soient pas a moins d'un metre du début de l'observation.
			);

		----
		CREATE INDEX lignes_intersection_geom_nd_index  ON lignes_intersection USING GIST (geom gist_geometry_ops_nd);
		VACUUM ANALYZE lignes_intersection;

	
	--On va maintenant filtrer les lignes d'intersection a 10 cm près celon la  condition suivante :
		--pour tout les lignes d'intersection, ne garder que ceux qui sotnt ) moins de 10 cm de 2 autres lignes d'intersection (soit meme exclu)
	--***	--------OU : executer une seule des deux requetes suivante, la deuxieme par defaut--------------------
			--requete sql : pour toutes les lignes, utiliser ST_DWithin10cm pour trouver les paires de lignes_intersections ,6900 resultats (note : calcul sur 10 000 * 10 000 =  100 000 000)
			/*
			DROP TABLE IF EXISTS intersection_entre_ligne_intersection ;
			CREATE TABLE intersection_entre_ligne_intersection AS (
				SELECT DISTINCT ON (gid1,gid2) li1.gid as gid1, li2.gid as gid2 , li1.geom as geom1 , li2.geom as geom2
				FROM lignes_intersection AS li1, lignes_intersection AS li2
				WHERE ST_3DDWithin(li1.geom,li2.geom,0.1)=TRUE
			)*/

			--deuxieme option
			--note : on essaye de fair el intersection entre les lignes d intersection et les segments orignaux pour gagner en combinatoire
			--plutot que de faire entre les lignes d intersection et les lignes d intersection
			DROP TABLE IF EXISTS intersection_entre_ligne_intersection ;
			CREATE TABLE intersection_entre_ligne_intersection AS (
				SELECT DISTINCT ON (gid1,gid2) li1.gid as gid1, li2.id as gid2 , li1.geom as geom1 , ST_3DShortestLine(li2.segment,li1.geom) as geom2
				FROM lignes_intersection AS li1, segments AS li2
				WHERE ST_3DDWithin(li1.geom,li2.segment,0.1)=TRUE
			);


		VACUUM ANALYZE intersection_entre_ligne_intersection;
		--observation du resultat 
		SELECT * 
		FROM intersection_entre_ligne_intersection
		ORDER BY gid1 ASC
		LIMIT 100;

		--requete sql : pour toutes les lignes, utiliser ST_DWithin10cm pour trouver les paires de lignes_intersections , grouper par gid, garder quand la taille du gid est > 3.
		DROP TABLE IF EXISTS lignes_intersection_regroupees_filtrees;
		CREATE TABLE lignes_intersection_regroupees_filtrees AS (
			WITH lignes_intersection_regroupees AS ( 
				SELECT gid1 AS gid1, array_agg(gid2) as gid2arr, rc_ST_3DCentroid(ST_Union(geom2)) AS geom
				FROM intersection_entre_ligne_intersection
				GROUP BY gid1
			)
			SELECT  *
			FROM lignes_intersection_regroupees AS lir
			WHERE array_length(gid2arr,1)>=3
			ORDER BY array_length(gid2arr,1) DESC
		);

		--verif de la table
		SELECT * 
		FROM lignes_intersection_regroupees_filtrees
		ORDER BY array_length(gid2arr,1) DESC
		LIMIT 100

	--On va maintenant faire une forme de clustering :
		--pour toutes les lignes de type gid1, array_agg gid2 , qui represente l'ensemble des lignes à moins de 10cm de la ligne de gid1
		--trier par longueur de gid2arr decroissant.
		--mettre dans la table de résultat la ^remiere ligne.
		--supprimer toutes les lignes de la table dont le tableau contient plus de 3 points en commun avec les tableaux de la tbale de resultat
		--iterer jusqu'a ce que le tableau initial soit vide.

		----
		--creation de la table de résultat
		DROP TABLE IF EXISTS resultat_clustering;
		CREATE TABLE resultat_clustering AS ( SELECT * FROM lignes_intersection_regroupees_filtrees LIMIT 0);

			
		----
		--Version plpgsql :
		CREATE OR REPLACE FUNCTION rc_cluster(data_table text, result_table text,
                                 OUT result boolean)
		AS $$
		--this function tries to cluster an input data with architecture |gid1| array_agg(gid2)| with the following algorithm :
			--order lines in data table by array length, and write the row into result
			--loop (while there are rows in data_table)
				--order lines in data table by array length, and write the row into result
				--delete row from data table where there are at least 3 elements in array that are in at least one array in result
		BEGIN
			WHILE (SELECT count(*) FROM lignes_intersection_regroupees_filtrees) !=0
				LOOP 
					--cheking : where are we?
						RAISE NOTICE 'number of data_row remainng to process : %',(SELECT count(*)
							FROM lignes_intersection_regroupees_filtrees);
						RAISE NOTICE 'number of rows in result : %',(SELECT count(*)
							FROM resultat_clustering);
					
					--inserting first row into results
					INSERT INTO  resultat_clustering (
						SELECT * 
						FROM lignes_intersection_regroupees_filtrees
						ORDER BY array_length(gid2arr,1) DESC
						LIMIT 1);
					--deleting any row from data that share more than 3 values in array with any array in result
					DELETE FROM lignes_intersection_regroupees_filtrees as lirf USING resultat_clustering as rc
						WHERE lirf.gid2arr && rc.gid2arr AND array_length((lirf.gid2arr::int[] & rc.gid2arr::int[]),1)>=3;
				
				END LOOP;	
		  
		END;
		$$ LANGUAGE plpgsql;
		
		--trying the function :
		SELECT rc_cluster('lignes_intersection_regroupees_filtrees', 'resultat_clustering'); --80sec : s'accelere fortement au fur et à mesure


		--On obtient encore un trop grand nombre de clusters, mais on a l'assurance que tous les panneaux 3D potentiels sont dans les 10 cm d'un de ces clusters.
		--On a dans les 350 candidats

	--On cherche à réduire le nombre de candidats.
	--pour cela, on va affecter pour chaque observation un cluster candidat ou 0, en choisissant celui qui a le plus de support, et le plus près si égalité

		--pour chaque observation : trouver les cluster a moins de 10 cm, ajouter celui qui a le plus d'observations (gid2arr)
		--Note : on ne garde qu'une seule version du cluster (pas de duplicat)
		DROP TABLE IF EXISTS un_cluster_par_observation;
		CREATE TABLE un_cluster_par_observation AS 
			WITH clusters AS (
				SELECT DISTINCT ON (s.gid ) s.gid, s.segment,rc.gid1, rc.geom as geom
				FROM segments AS s, resultat_clustering AS rc
				WHERE ST_3DDWithin(s.segment,rc.geom,0.3)=TRUE
				AND ST_3DDWithin(s.point1,rc.geom,1)=FALSE
				ORDER BY s.gid ASC, array_length(rc.gid2arr,1) DESC
			),
			clusters_groupes AS (
				SELECT DISTINCT ON (geom) row_number() over() AS gid, geom as geom, count(*) AS nbr_observation 
				FROM clusters as c
				GROUP BY c.geom
			)
			SELECT gid, geom, nbr_observation
			FROM clusters_groupes as c
			WHERE nbr_observation >= 2
			;
			
			--affichage des résultats
		SELECT count(*) nombre_de_clusters, sum(nbr_observation) AS observations_utilisees, (SELECT count(*) FROM segments) AS observations_totales
		FROM un_cluster_par_observation;

	--Fin de l'algorithme, le résultat est dans la table 'un_cluster_par_observation'




	---
	--On importe maitnenant la vérité terrain :
	--il s'agitr d'un fichier xml avec balise, on s'interesse a la ligne centre qui désigne en fait le coin en bas à gauche
	--On va utiliser des expressions régulières pour extraire 


	
	--On redéfini une fonction pour calculer le pseudo centroid en 3D : pour toute geom, caster vers des points, calculer la moyenne en X, Y , Z de ces points.
		--redifining a centroid function for 3D : rc_ST_3DCentroid

		----
		--Version plpgsql :
		CREATE OR REPLACE FUNCTION rc_ST_3DCentroid(geom geometry) RETURNS geometry
		AS $$
		--This function is a very dirty workaround to imitate a st_centroid_like function behaving correctly in 3D
		--WARNING  : this is very simplified version : everything is converted to point and then an average is computed for x, y z .
		DECLARE 
		BEGIN
			--getting the srid of the input geoemtry
			
			RETURN (WITH points_in_geom AS (
				SELECT (ST_DumpPoints(geom)).geom AS geom, ST_SRID(geom) as srid	
			)
			SELECT ST_SetSRID(ST_MakePoint(avg(ST_X(p.geom)),avg(ST_Y(p.geom)),avg(ST_Z(p.geom))),min(srid)) AS geom
			FROM points_in_geom AS p)
			;
		END;
		$$ LANGUAGE plpgsql;
		
		--trying the function :
		SELECT rc_ST_3DCentroid(ST_Union(s.segment)) --80sec : s'accelere fortement au fur et à mesure
		FROM segments As s;





--------------
---------
-----Bonus :
-----Pour accélérer l'algorithme et permettre la parallelisation, on essaye de découper les observations en composante connexe, c'est à dire en ensemble d'observation qui s'intersectent.
-----De cette façon, on peut faire les calculs sur des parties indépendantes.
-----Cela revient à trouver les composantes connexes
-----
-----On propose un algo en BDD pour le faire de façon efficace
---------
--------------


------------Finding connected components : algorithme description
--------Notes
--We suppose we have a table describing (2 ways, non duplicated, (min,max) ordered) connections between observations :  (gid1, gid2) (equivalent to (gid2,gid1) ) WARNING : this table is going to be emptyed during the process
--We suppose we have a result table type gid[] to store the c_components
--We will heavily use postgres int[] fucntionnality, thus it could be good to use idexes on that
--	Also, we need to have it installed !
--
--------Algorithme
--loop on adjacency table (while there is a line)
--	get first line of adjacency table
--	get all lines sharing at least one id with first line (1 search in adjacency)
--	make a list of distinct id out of that.
--	create a c_component
	--delete all row used
--	select all lines sharing at least one value with new c_component (1 search in adjacency)
--	update the new c_component and write it to result table
--	delete all lines used
----

	-- adding the extension to work with int[]
	CREATE EXTENSION intarray;

	--creating the adjacency table :
		--deleting creaitng table
		DROP TABLE IF EXISTS adjacencies;
		CREATE TABLE adjacencies AS (
			SELECT DISTINCT ON (least(t1.id, t2.id), greatest(t1.id, t2.id) ) ARRAY[least(t1.id::int, t2.id::int), greatest(t1.id::int, t2.id::int)] AS adj --trick to ensure that we first have the lowest value, then the highest
			FROM segments as t1, segments as t2
			WHERE t1.id!=t2.id
				ANd 
				ST_3DDWithin(t1.segment, t2.segment, 0.2)=TRUE
			);
		--adding id column
			ALTER TABLE adjacencies DROP COLUMN IF EXISTS id;
			ALTER TABLE adjacencies ADD COLUMN id SERIAL;
		--adding index
		CREATE INDEX adjacencies_adj_gin_intarray ON adjacencies USING GIN (adj gin__int_ops);
		

	--ajout des colonnes


	--creating the result table
		--deleting/creating table
		DROP TABLE IF EXISTS c_components;
		CREATE TABLE c_components (
			id SERIAL,
			cli int[]
			);
		--adding indexes
		CREATE INDEX c_components_c_component_gin_intarray ON c_components USING GIN (cli gin__int_ops);

	--checking tables
		--checking adj
			SELECT * --7341
			FROM adjacencies
			LIMIT 100;
			SELECT *
			FROM c_components
			LIMIT 100;
	--update of stats
	VACUUM ANALYZE adjacencies;
	VACUUM ANALYZE c_components;


	--launchin algorihtm
	SELECT rc_find_c_components('toto','toto');



		--c_component_contructing_function
		DROP FUNCTION IF EXISTS rc_find_c_components(text,text);
		CREATE OR REPLACE FUNCTION rc_find_c_components(data_table text, result_table text) RETURNS boolean AS $$
		--this function comput the c_component (connected components), given an adjacency table (WILL BE EMPTYED) and a result table
		--note : it depends ont intarray EXTENSION
		DECLARE
		number_new_member int :=0;
		number_new_new_member int :=0;
		BEGIN
			--loop on adjacency table
			WHILE (SELECT count(*) FROM adjacencies) !=0
		

			LOOP  --loop until we have processed all the lines in adjacency table
			--cheking : where are we?
				--RAISE NOTICE 'number of adj remainng to process : %',(SELECT count(*)
				--	FROM adjacencies);
				--RAISE NOTICE 'number of c_component in result : %',(SELECT count(*)
				--	FROM c_components);


				--create a c_component from first line, automatically with 2 new members
				--index_new_member = 1
				--loop on new members
					--index_new_new_member = rc_find_new_c_component_members (index_new_member)
					--stop if nindex_new_member == index_new_new_member
					--index_new_member = index_new_new_member
				--loop --on new members : 
			-----------------------
				--create a c_component from first line, automatically with 2 new members
				WITH first_line AS(--get the first adjacencies line
							WITH foo AS (
							SELECT *
							FROM adjacencies
							LIMIT 1)
							DELETE FROM adjacencies USING foo WHERE foo.id = adjacencies.id 
							RETURNING foo.*
						),--creating the new c_component
						the_c_component AS(
							SELECT ARRAY[least(fl.adj[1],fl.adj[2]),greatest(fl.adj[1],fl.adj[2])]::int[] AS cli
							FROM first_line AS fl
						)--inserting into c_component
						INSERT INTO c_components (cli) SELECT * FROM the_c_component
						;
				number_new_member := 2; 
				--loop on new members
				LOOP
					--index_new_new_member = rc_find_new_c_component_members (index_new_member)
					number_new_new_member := rc_find_new_c_component_members(number_new_member);

					--test for end of loop : see if the c_component is completed,  : there is no more addings
					 EXIT WHEN number_new_member = 0;
					 number_new_member := number_new_new_member;
				END LOOP; --on new members
				

			END LOOP; --loop on all lines in adjacency table
			RETURN TRUE;	
		END;
		$$ LANGUAGE plpgsql;


		DROP FUNCTION IF EXISTS rc_find_new_c_component_members( int );
		CREATE OR REPLACE FUNCTION rc_find_new_c_component_members(number_of_old_member int ) RETURNS int AS $$
                -- given an input index to a int[],works on int[input,end], looks into adjacency table and return an output index to int[] with deduped ordered node in adjacency table which are linked to the given input (that is, where ther is at least a tuple (input_k, output_l) or reverse in adjacecny table)
                --remove used adjacency lines from the table
		--
		--note : used by the function rc_find_c_components;  
		--it depends ont intarray EXTENSION
		DECLARE 
		number_of_new_members int :=0;
		BEGIN
			--What does the function : 
			--get the int[] correpsonding to old_member, 
			--find which member are connected to old member
			--delete used adjacency lines
			--return the number of new member
			--
			--	 
					--cheking : where are we?
						--RAISE NOTICE 'trying to complete c_component Number % based on % number_of_old_member',(SELECT count(*)
						--	FROM c_components),number_of_old_member ;
						--RAISE NOTICE 'the number we want to find connected member to are %',(
							--	WITH new_c_component AS(
							--		SELECT c.id, c.cli /*index_of_old_members*/ 
							--		FROM c_components AS c
							--		ORDER BY id DESC
							--		LIMIT 1
							--	)
							--	SELECT c.cli[array_upper(cli,1)-number_of_old_member+1:array_upper(cli,1)] /*index_of_old_members*/ 
							--	FROM new_c_component AS c);


								
					--getting the int[corresponding to new member]
						WITH new_c_component AS(
								SELECT c.id, c.cli /*index_of_old_members*/ 
								FROM c_components AS c
								ORDER BY id DESC
								LIMIT 1
								), 
							new_member AS (
								SELECT c.id, c.cli[array_upper(cli,1)-number_of_old_member+1:array_upper(cli,1)] /*index_of_old_members*/ 
								FROM new_c_component AS c
							),
							adj_to_add AS (
								WITH foo3 AS (
									SELECT DISTINCT ON (adja.id) adja.* 
									FROM new_member as nc, adjacencies AS adja
									WHERE adja.adj && nc.cli
									) 
								DELETE FROM adjacencies USING foo3 WHERE foo3.id = adjacencies.id
								RETURNING foo3.*
								),
							-- extract a list of unique id out of this
							list_of_adj AS (--extract list
								SELECT unnest(adj) as id
								FROM adj_to_add AS ata),
							unique_list_of_adj AS (--uniqueness
							SELECT DISTINCT ON (id) id 
							FROM list_of_adj),
							--new id that could be merged into c_component, but style there may be duplicate with c_component
							new_id_candidat aS (
								SELECT array_agg(id ORDER BY ula.id ASC) AS ids--new array with new id
								FROM unique_list_of_adj AS ula),
							--calculating part of new_id which is not in the c_component
							new_id_to_add AS (
								SELECT nc.id AS id,  nic.ids - nc.cli AS cli 
								FROM new_id_candidat AS nic, new_c_component AS nc
							)--adding new id to c_component
							--note : we add the new id to the end of c_component, and we make sure that there is no duplicate
							UPDATE c_components AS cl SET cli = CASE WHEN nit.cli IS NULL THEN cl.cli ELSE cl.cli + ( nit.cli -cl.cli) END
							FROM new_id_to_add AS nit, new_c_component AS nc
							WHERE cl.id= nit.id
							RETURNING CASE WHEN ( # nit.cli ) !=0 AND ( # nit.cli )IS NOT NULL THEN ( # nit.cli )
								ELSE 0 END 
							INTO number_of_new_members ;

						--checking :
						--RAISE NOTICE 'we have found % new connected members which are %',number_of_new_members,(
							--	WITH new_c_component AS(
							--		SELECT c.id, c.cli /*index_of_old_members*/ 
							--		FROM c_components AS c
							--		ORDER BY id DESC
							--		LIMIT 1
							--	)
							--	SELECT c.cli[array_upper(cli,1)-number_of_new_members+1:array_upper(cli,1)] /*index_of_old_members*/ 
							--	FROM new_c_component AS c);
							--returns ne number of new member found,
							RETURN number_of_new_members;
													
		END;
		$$ LANGUAGE plpgsql;
		


	-----
	--Generating geometry to visualyze c_components	
	--we want a table with : | c_component id | segments id | geometry
	DROP TABLE IF EXISTS c_component_visualization;
	CREATE TABLE c_component_visualization AS (
		WITH unnested_c_component AS (
			SELECT  c.id AS c_component_id, unnest(cli)AS segments_id
			FROM c_components AS c, segments AS s
		)
		SELECT DISTINCT ON (c.segments_id)  c.*, s.segment AS geom
		FROM unnested_c_component AS c, segments AS s
		WHERE segments_id = s.id
	);
	--ORDER BY c.c_component_id ASC
	

	
		--how does it look?
		SELECT *
		FROM c_components
		ORDER BY id ASC
		--test on result :
		SELECT cl1.id,cl2.id, (cl1.cli & cl2.cli) 
		FROM c_components as cl1, c_components as cl2
		WHERE cl1.id != cl2.id
		AND cl1.cli && cl2.cli = TRUE
		ORDER BY cl1.id ASC, cl2.id ASC
		

--------------------------------
-------------
--------
----Recreating postgis st_cut bug with Z geoemtries
-------
--We have eveidences that st_cut() doesn't work well with geometry, we try to provide a test environnment to showcase this ptoblem.
--
--------------
-------------------------------

		--the faulty sql command : 
		DROP TABLE IF EXISTS lignes_coupees_par_bati; --temps de calcul : 3.5sec
		CREATE TABLE lignes_coupees_par_bati AS (
			WITH lignes_coupees AS ( --le resultat est toutes les segments issues du coupage, on va les filtrer pour n'en garder qu'un par identifiant
			SELECT id, gid, new_geom, old_geom
			 FROM(	
				 SELECT segments.id, segments.gid AS gid, (ST_Dump(ST_Split(segment,ST_ExteriorRing((ST_Dump(geom)).geom)))).geom AS new_geom, segment AS old_geom
				FROM reco_panneaux.segments, bdtopo.bati_tous as b_i
				WHERE ST_Crosses(segment,b_i.geom)=TRUE
				)as toto
		),
		lignes_coupees_filtrees AS (
			SELECT DISTINCT ON (l_c.gid) l_c.id, l_c.gid AS gid, l_c.new_geom, l_c.old_geom--, SUBSTRING(l_c.gid FROM '.{9}$') AS id --filtrage pour garder une seule ligne par gid : en l'occurence, la plus courte
			FROM lignes_coupees AS l_c, segments
			WHERE ST_Intersects(ST_Force_2D(l_c.new_geom),ST_Force_2D(point1))=TRUE --filtrage pour garder la ligne qui contient le point de départ de l'observation
			ORDER BY l_c.gid ASC,ST_Length(new_geom) ASC
			)
		SELECT ST_3DLongestLine(new_geom, old_geom)
		FROM lignes_coupees_filtrees
		) ; 



		--new functions to try to get this damn geometry :
		--ST_Difference
		--ST_EndPoint
		--ST_GeometryN
		--ST_InterpolatePoint
		--ST_Line_Interpolate_Point
		--ST_Line_Substring

		--we are going to get the same semgent unmodified and compute the longuest line between the two.
		

		

		DROP TABLE IF EXISTS lignes_intersection;
			CREATE TABLE lignes_intersection AS (
				WITH liste_intersection AS (-- il s'agit des couples de lignes qui s'intersectent à 10cm près.
					SELECT t1.gid AS gid1, t1.geom AS geom1, t2.gid AS gid2, t2.geom AS geom2
					FROM lignes_coupees_filtrees as t1, lignes_coupees_filtrees as t2
					WHERE t1.gid!=t2.gid
						AND
					ST_3DDWithin(t1.geom, t2.geom, 0.10)=TRUE
				)
				SELECT row_number() over () AS gid, li.gid1 , li.gid2, ST_3DShortestLine(li.geom1,li.geom2) as geom
				FROM liste_intersection AS li
			);

-----------------------------------


		

	--test pour couper les lignes en 3D : problem, les lignes ne sont coupee qu une seule fois, ce qui est incorrect.
	--soit appliquer de façon recursive, soit regrouper les ilots en un seul truc.000
	WITH lignes_coupees AS (
		SELECT gid, geom as geom 
		FROM
		(	 SELECT segments.gid AS gid, (
				ST_Dump(
					ST_Split(
						segment,ST_ExteriorRing(
							(ST_Dump(geom)).geom
							)
						)
					)
				).geom AS geom
			FROM reco_panneaux.segments, bdtopo.bati_indifferencie as b_i
			WHERE ST_Intersects(segments.segment,b_i.geom)=TRUE
		)as toto
	)
	SELECT l_c.gid, l_c.geom
	FROM lignes_coupees as l_c, segments as p
	WHERE ST_Intersects(l_c.geom, p.point1)=TRUE


		--debug : verif sur qgis:
		WITH lignes_coupees AS (
		SELECT gid, geom as geom 
			FROM
			(	 SELECT segments.gid AS gid, (
					ST_Dump(
						ST_Split(
							segment,ST_ExteriorRing(
								(ST_Dump(geom)).geom
								)
							)
						)
					).geom AS geom
				FROM reco_panneaux.segments, bdtopo.bati_indifferencie as b_i
				WHERE ST_Intersects(segments.segment,b_i.geom)=TRUE
			)as toto
		),
		toto AS (
			SELECT l_c.gid, l_c.geom
			FROM lignes_coupees as l_c, reco_panneaux.segments as p
			WHERE ST_Intersects(l_c.geom, p.point1)=TRUE)
		SELECT DISTINCT ON (gid) row_number() over () AS gid, toto.geom AS geom
		FROM toto

--afficher le ocntenu de la table

--ajouter une colonne point1, une colone point2, une colonne ligne, une colonne rectangle

--


DROP TABLE IF EXISTS temp_intersection;
CREATE TABLE temp_intersection AS (
	WITH lignes_coupees AS (SELECT gid, geom as geom
		 FROM(	
			 SELECT segments.gid AS gid, (ST_Dump(ST_Split(segment,ST_ExteriorRing((ST_Dump(geom)).geom)))).geom AS geom
			FROM reco_panneaux.segments, bdtopo.bati_indifferencie as b_i
			WHERE ST_Crosses(segment,b_i.geom)=TRUE
			)as toto
		),
	titi AS (
		SELECT l_c.gid, l_c.geom
		FROM lignes_coupees as l_c, reco_panneaux.segments as p,bdtopo.bati_indifferencie as b_i
		WHERE ST_Intersects(l_c.geom, p.point1)=TRUE
		AND
		ST_Crosses(l_c.geom,b_i.geom)=FALSE
	)
	SELECT DISTINCT ON (titi.gid) row_number() over () AS gid, titi.geom AS geom
	FROM titi--, bdtopo.bati_indifferencie as b_i
	--WHERE ST_Crosses(titi.geom,b_i.geom)=FALSE
)

VACUUM ANALYZE temp_intersection

SELECT DISTINCT t_i.gid, t_i.geom
FROM temp_intersection as t_i, bdtopo.bati_indifferencie as b_i


set enable_seqscan=false;



SELECT DISTINCT ON(t_i.gid) t_i.gid, ST_AsText(t_i.geom)
FROm temp_intersection as t_i, bdtopo.bati_indifferencie as b_i
WHERE ST_Overlaps(t_i.geom,b_i.geom)=FALSE AND ST_Intersects(t_i.geom,b_i.geom)=TRUE


set enable_seqscan=true;

SELECT b_i.geom
FROM temp_intersection as t_i, bdtopo.bati_indifferencie as b_i
WHERE ST_Intersects(t_i.geom,b_i.geom)=FALSE






set enable_seqscan=true;
CREATE TABLE temp_intersection AS (
	WITH lignes_coupees AS (
		SELECT gid, geom as geom
		 FROM(	
			 SELECT segments.gid AS gid, (ST_Dump(ST_Split(segment,ST_ExteriorRing((ST_Dump(geom)).geom)))).geom AS geom
			FROM reco_panneaux.segments, bdtopo.bati_indifferencie as b_i
			WHERE ST_Crosses(segment,b_i.geom)=TRUE
			)as toto
		),
	titi AS (
		SELECT DISTINCT ON (l_c.gid) l_c.gid, l_c.geom
		FROM lignes_coupees as l_c, reco_panneaux.segments as p,bdtopo.bati_indifferencie as b_i
		WHERE ST_Intersects(l_c.geom, p.point1)=TRUE
		AND
		ST_Crosses(l_c.geom,b_i.geom)=FALSE
	)
	SELECT titi.gid, titi.geom AS geom
	FROM titi--, bdtopo.bati_indifferencie as b_i
	--WHERE ST_Crosses(titi.geom,b_i.geom)=FALSE
)

CREATE TABLE temp_intersection AS (
WITH lignes_coupees AS (
		SELECT gid, geom as geom
		 FROM(	
			 SELECT segments.gid AS gid, (ST_Dump(ST_Split(segment,ST_ExteriorRing((ST_Dump(geom)).geom)))).geom AS geom
			FROM reco_panneaux.segments, bdtopo.bati_indifferencie as b_i
			WHERE ST_Crosses(segment,b_i.geom)=TRUE
			)as toto
		)
	SELECT  row_number() over () AS gid, l_c.gid as old_gid, l_c.geom
	FROM lignes_coupees AS l_c
)

set enable_seqscan=true;


DROP TABLE IF EXISTS temp_intersection_2;
CREATE TABLE temp_intersection_2 AS (
	SELECT t_i.gid , t_i.geom  
FROM temp_intersection as t_i, segments
WHERE ST_Intersects(ST_Force_2D(t_i.geom),ST_Force_2D(point1))=TRUE
	AND t_i.gid NOT IN (
	    WITH intersected_bati_indifferencie AS(
	SELECT DISTINCT ON (b_i.gid) b_i.gid, b_i.geom
	FROM bdtopo.bati_indifferencie as b_i, segments
	WHERE ST_Intersects(segments.segment,b_i.geom)=TRUE
	)
	SELECT t_i.gid
	FROM temp_intersection as t_i, intersected_bati_indifferencie as i_b_i
	WHERE ST_Intersects(ST_Force_2D(t_i.geom),ST_Buffer(ST_Force_2D(i_b_i.geom),-0.1))=true
)
)

--10k lignes
--cette version filtre les segment decoupés en bout multiple en en gardant un seul par gid, celui qui contient le point de départ et qui est le plus court
DROP TABLE IF EXISTS temp_intersection_2;
CREATE TABLE temp_intersection_2 AS (
	SELECT DISTINCT ON (t_i.old_gid) t_i.old_gid AS gid, t_i.geom AS geom
FROM temp_intersection as t_i, segments
WHERE ST_Intersects(ST_Force_2D(t_i.geom),ST_Force_2D(point1))=TRUE
ORDER BY t_i.old_gid ASC,ST_Length(geom) ASC
)

SELECT DISTINCT ON (customer)
       id, customer, total
FROM   purchases
ORDER  BY customer, total DESC, id
