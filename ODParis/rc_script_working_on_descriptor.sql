

/*working on symbol descriptors*/
--creating a test table 
--SELECT public.rc_copy_table_from_a_schema_to_another('odparis_reworked','odparis_test','indicateur');

--showing some information about test table
--SELECT * FROM rc_gather_info_libelle_columns('odparis_test','indicateur');


--gathering geom to point (in a postgres type)

WITH points AS (
	SELECT (ST_DumpPoints((ST_Dump(geom)).geom)).geom AS geom, gid
	FROM odparis_test.indicateur
	ORDER BY gid ASC
	LIMIT 100
),
tableau_de_points AS (
	SELECT array_agg( POINT(ST_X(geom),ST_Y(geom))) AS tableau_geom , gid
	--array_agg(geom)
	FROM points
	GROUP BY gid
	ORDER BY gid
),
--SELECT *
--FROM tableau_de_points



fft_complex AS (
	SELECT pgnumerics.fft_complex(tableau_geom,TRUE) AS f_c,gid
	FROM tableau_de_points
),
result_fft AS (
	SELECT fft_complex.*, array_length(f_c,1) AS length
	FROM fft_complex
)
SELECT *
FROM result_fft
--calculating fft on a percent of geom
/*end*/


/*manipulating geom data to convert from line to array of points*/
WITH points AS (
	SELECT (ST_DumpPoints((ST_Dump(geom)).geom)).geom AS geom, gid
	FROM odparis_test.indicateur
	ORDER BY gid ASC
	LIMIT 100
),
tableau_de_points AS (
	SELECT ARRAY[ST_X(geom)::numeric,ST_Y(geom)::numeric] AS tableau_geom , gid
	--array_agg(geom)
	FROM points
	--GROUP BY gid
	--ORDER BY gid
)
SELECT array_agg(tableau_geom::numeric[])::numeric[][] AS t_g, gid
FROM tableau_de_points
GROUP BY gid



/*this fucntion is just for test purpose and output a bidimensionnal numeric array*/
DROP FUNCTION IF EXISTS odparis.rc_plr_dummy_array();
CREATE OR REPLACE FUNCTION odparis.rc_plr_dummy_array() RETURNS numeric[][]  AS 
$$
	return(array(1:10,c(4,2)) )
$$ LANGUAGE 'plr' STRICT;

SELECT odparis.rc_plr_dummy_array();


/*this is a PLR function which computes fft for a fixed length(zero padding) and returns the resulting points*/
--R function prototype :
--input : numeric[][], length_wanted int,output : numeric[][]
--body : compute FFT to a fixed length (zero padding at the end if necessary)
DROP FUNCTION IF EXISTS odparis.rc_plr_fft_on_array(numeric[][],integer, numeric[][]);
CREATE OR REPLACE FUNCTION odparis.rc_plr_fft_on_array(IN points_to_compute numeric[][], IN output_length integer, IN fft_points numeric[][]) RETURNS numeric[][]  AS 
$$
	msg <- paste("inputs : points_to_compute,  output_length, fft_points", points_to_compute, output_length,fft_points)
	pg.thrownotice(msg)
       return(points_to_compute)
$$ LANGUAGE 'plr' STRICT;


WITH toto AS (
SELECT rc_plr_fft_on_array AS fft
FROM odparis.rc_plr_fft_on_array(ARRAY[ARRAY[1,2,3],ARRAY[1,2,3]], 5,ARRAY[ARRAY[1,2,3],ARRAY[1,2,3]] )
)
SELECT toto
FROM toto

WITH titi AS (
SELECT odparis.rc_plr_fft_on_array(odparis.rc_plr_dummy_array(), 5,odparis.rc_plr_dummy_array() ) AS toto
)
SELECT toto FROM titi









    