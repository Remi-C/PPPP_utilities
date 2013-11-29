



--piste de fonction a tester
--Convex Enveloppe : risque d etre trop generique
--cioncav : une bonne idée,a  verifier
--buffer: regler la taille en fonction des symboels
--on pourrait tous simplement garder uniquement la surface apres le buffer
--pour calculer la surface : area


/*petite maquette sur l'analyse des diéfférents symboles dans ue couche par descripteur= surface*/
--dropping table if it previously existed
DROP TABLE IF EXISTS odparis_test.indicateur_test_descriptor;

--creating a table which contains original data plsu two kind of surfaces calculated which will be used as descriptors
CREATE TABLE odparis_test.indicateur_test_descriptor WITH OIDS
AS
WITH toto AS (
	SELECT gid, info, libelle, geom AS geom,ST_CollectionExtract(ST_Buffer(geom,0.01),3) AS newgeom_Buff_001, ST_CollectionExtract(ST_ConcaveHull(ST_Buffer(geom,0.01),0.99),3) AS newgeom_ConcHull_99_Buff_001
	FROM odparis_test.indicateur
),
tata AS (
	SELECT gid, info, libelle, geom, newgeom_Buff_001 AS surface, newgeom_ConcHull_99_Buff_001 AS concsurface
	FROM toto
)
SELECT gid, info, libelle, geom, surface, ST_Area(surface) AS area_surface, concsurface, ST_Area(concsurface) AS area_concsurface
FROM tata
;

--setting the geometry type
--ALTER TABLE odparis_test.indicateur_test_descriptor ALTER COLUMN surface SET DATA TYPE geometry(Polygon);
--setting the geometry type
--ALTER TABLE odparis_test.indicateur_test_descriptor ALTER COLUMN concsurface SET DATA TYPE geometry(Polygon);



WITH couche_base AS (
	SELECT gid, newgeom , ST_Area(newgeom) AS area, info
	FROM odparis_test.indicateur_test_descriptor
),
couche_2 AS (
	SELECT * 
	FROM couche_base
	ORDER BY info ASC, AREA ASC
),
analyse_stat AS (
	SELECT variance(area),avg(area), min(area), max(area) --, info
	FROM couche_2
)
SELECT *
FROM analyse_stat
--GROUP BY info





