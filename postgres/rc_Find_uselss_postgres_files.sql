/*

DROP FUNCTION IF EXISTS find_useless_postgres_file(text);
CREATE OR REPLACE FUNCTION find_useless_postgres_file(    database_name text) 
	RETURNS TABLE(file_name text, file_relative_path text,file_abs_path text,size bigint) AS 
	$BODY$
		DECLARE     
			_useless record; 
		BEGIN  

			RETURN QUERY
	WITH s AS ( -- all files in the base postgres folder for a database
		SELECT oid As database_oid, _file_name AS file_name, substring(_file_name from '\d+' ) as base_name
		FROM pg_database  ,pg_ls_dir('./base/' || oid::text) AS _file_name
		WHERE datname = database_name
	)
	, all_filenode AS ( 
				SELECT relname, pg_relation_filenode(pg_class.oid) safe_filenode
				FROM pg_class
	)
	 , joined_with_catalog AS (
		SELECT database_oid, s.file_name
			, '/base/' || database_oid  || '/' || s.file_name as relative_file_path
			, c2.*
		FROM s
		LEFT JOIN pg_class c 
			ON s.file_name = c.relfilenode::text
		LEFT JOIN all_filenode c2 
					ON ( s.file_name = c2.safe_filenode::text OR  s.base_name = c2.safe_filenode::text)
			
		WHERE -- file_name ~ '^\d+$' AND
		 c.oid IS null AND safe_filenode IS NULL--file not used in catalog
			AND (  -- only keeping table-like files
				s.file_name ~ '^\d+$' 
				OR s.file_name ~ '^\d+.\d+$' 
				OR s.file_name ~ '^\d+_fsm$' 
				OR s.file_name ~ '^\d+_vm$')
	)	

	--, combined AS(
		SELECT
			 j.file_name ,
			 relative_file_path,
			current_setting('data_directory') || relative_file_path AS absolute_file_path
			,(pg_stat_file('.' ||  relative_file_path)).size as file_size
			--,database_oid, file_name 
		FROM joined_with_catalog as j
		ORDER BY file_name DESC ; 
		END ;  
	$BODY$
LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT; 



SELECT   delete_file( file_abs_path) 
	--, substring(file_name from '\d+' )
	-- pg_size_pretty(sum(size))
	 --*
FROM find_useless_postgres_file('test_pointcloud')
ORDER BY file_name ASC ;



COPY (
SELECT substring(file_name from '\d+' )
FROM find_useless_postgres_file('test_pointcloud')  

)
to '/tmp/potential_bad_files' 		

WITH d_name AS (
	SELECT datname FROM pg_database
	WHERE datistemplate = false
	AND datname != 'postgres'
)
SELECT -- pg_size_pretty(sum(size)) ,
	datname, 
	size, 
	delete_file( file_abs_path) 
FROM d_name, find_useless_postgres_file(datname) ;
 


SELECT    *
	-- ,  delete_file( file_abs_path) 
FROM find_useless_postgres_file('test_topology')
ORDER BY file_name ASC ;

 

 */
 