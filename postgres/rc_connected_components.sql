------------------------------------
--Remi -C Thales/IGN
--10/2014
--Connected components
------------------------------------
--function to compute connected components efficiently in postgres
--need extension intarr

--SET search_path to temp_demo_mathieu, public;


-- adding the extension to work with int[]
--CREATE EXTENSION IF NOT EXISTS intarray;

/*
--creating synthetic data : 
SET SEED TO 0.08;
DROP TABLE IF  EXISTS adjacencies;
CREATE TABLE adjacencies AS 
	WITH adj  AS (
		SELECT s AS gid1, ARRAY[(round(random()*10000 ))::int  , (round(random()*10000 ))::int] AS gid2
		FROM generate_series(1,10000) AS s 
	)
	--,filtered_adj AS (
	SELECT DISTINCT ON (LEAST(gid2[1],gid2[2]),GREATEST(gid2[1],gid2[2]) ) 
		gid1 AS id
		, ARRAY[LEAST(gid2[1],gid2[2]),GREATEST(gid2[1],gid2[2])] AS adj
		, LEAST(gid2[1],gid2[2]) AS ccid
	FROM adj
	WHERE gid2[1] != gid2[2]  ;
 
--adding index
CREATE INDEX  ON adjacencies (id);
CREATE INDEX  ON adjacencies (adj);
CREATE INDEX  ON adjacencies (ccid);
CREATE INDEX  ON adjacencies USING GIN (adj gin__int_ops);

--what does it looks like?
SELECT *
FROM adjacencies
ORDER BY id ASC, adj[1],adj[2] ;


 
--creating the result table
	--deleting/creating table
	DROP TABLE IF EXISTS c_components;
	CREATE TABLE c_components (
		id SERIAL,
		cli int[]
		);
	--adding indexes
	CREATE INDEX  ON c_components (id);
	--CREATE INDEX  ON c_components (cli);
	--unsafe with really big arrays
	 CREATE INDEX c_components_c_component_gin_intarray ON c_components USING GIN (cli gin__int_ops);


--custom algo, loop on all edge, removes edge one by one, construct ccomponents
 	SELECT  rc_find_c_components('adjacencies','c_components');
	--few sec for 10 000 edges

	--union_merge algo : try to assign a components_id to each edge, propagate it by taking the min in neighboorhood
	SELECT rc_ccomponents();
	--

--checking the result :
SELECT * 
FROM c_components
*/
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
-- 		RAISE NOTICE 'number of adj remainng to process : %',(SELECT count(*)
-- 			FROM adjacencies);
-- 		RAISE NOTICE 'number of c_component in result : %',(SELECT count(*)
-- 			FROM c_components);


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



--------------trying the union_merge algorithm. 
--shorter to write ,complexity may not be so good



DROP FUNCTION IF EXISTS rc_ccomponents_update_edge( n_edge int[2], n_ccid int );
CREATE OR REPLACE FUNCTION  rc_ccomponents_update_edge( n_edge int[2], n_ccid int, OUT updated_ccid INT )   AS $$
--note : need extesnion intarr

DECLARE  
BEGIN  
	SELECT COALESCE(LEAST(n_ccid,min(a.ccid)),n_ccid) INTO updated_ccid
	FROM adjacencies AS a
	WHERE a.adj && n_edge AND a.ccid !=n_ccid ; 
	RETURN;
END;
$$ LANGUAGE plpgsql;

/*
SELECT * , rc_ccomponents_update_edge(adj,ccid)
FROM adjacencies 
ORDER BY  adj[1],adj[2] ;
*/

DROP FUNCTION IF EXISTS rc_ccomponents_update_table( OUT modified_ccid INT   );
CREATE OR REPLACE FUNCTION  rc_ccomponents_update_table(OUT modified_ccid INT   ) AS $$
--note : need extesnion intarr

DECLARE  
BEGIN    

	--new array, group by ccid

	--for every line, intersect with new arrays, take the min of ccid of the array that intersects  

	With temp_cc AS (
	SELECT  array_agg(adj ORDER BY adj ASC) as adjs, ccid
	FROM (
		SELECT  adj[1], ccid
		FROM adjacencies
		UNION
		SELECT adj[2], ccid
		FROM adjacencies
		) AS sub
		GROUP BY ccid
	)
	,up aS (
		SELECT a.adj, a.ccid, min(temp_cc.ccid) as u_ccid
		FROM adjacencies as a
			INNER JOIN temp_cc ON ( a.adj && temp_cc.adjs  AND temp_cc.ccid < a.ccid  )
		GROUP BY  a.id, a.adj ,a.ccid 
	)
	,upd AS (
		UPDATE adjacencies  AS a SET ccid = u_ccid 
		FROM up
		WHERE up.adj = a.adj AND  up.u_ccid != a.ccid
		RETURNING 1 
	)
	SELECT count(*) INTO modified_ccid 
	FROM upd; 
	 RETURN ;
END;
$$ LANGUAGE plpgsql;

/* 
SELECT rc_ccomponents_update_table();



		
SELECT COALESCE(LEAST(4,min(a.ccid)),4) INTO updated_ccid
	FROM adjacencies AS a
	WHERE a.adj && ARRAY[4,19] AND a.ccid !=4;  

*/

DROP FUNCTION IF EXISTS rc_ccomponents(  );
CREATE OR REPLACE FUNCTION  rc_ccomponents(OUT max_clique_size INT  )   AS $$
--note : need extesnion intarr

DECLARE
 i int=0;  
BEGIN    
	WHILE rc_ccomponents_update_table()!=0  
	LOOP 
	i = i+1;
	--RAISE NOTICE 'loop i :%',i;
	END LOOP;
	max_clique_size = i; 
	RETURN ; 
END;
$$ LANGUAGE plpgsql;

/*
SELECT *  
FROM adjacencies 
ORDER BY  adj[1],adj[2];

SELECT rc_ccomponents();
--10 000 : 

SELECT * 
FROM adjacencies 
ORDER BY  adj[1],adj[2];
*/


----------profiling & timing :
--SELECT pg_stat_reset();
/*
SELECT funcname,calls, total_time/1000.0 AS total_time, self_time/1000.0 AS self_time, sum(self_time/1000.0) OVER (order by self_time DESC) As cum_self_time
FROM pg_stat_user_functions
ORDER BY  -- total_time DESC  ,
	self_time DESC;  
*/


--the python way !
--CREATE EXTENSION IF NOT EXISTS plpythonu;

DROP FUNCTION IF EXISTS rc_py_ccomponents ( INT[], INT[] );
CREATE FUNCTION rc_py_ccomponents ( 
 node1 INT[], node2 INT[] 
	) 
RETURNS TABLE( node int, ccomponents INT )   
AS $$
"""
Tis function takes pairs of nodes of a network as input. 
one pair is an edge of the graph
we want to find the connected components

require networkx
"""
#importing needed modules
import numpy as np ;
import plpy ;
import networkx as nx;  

#converting the 1D array to numpy array
n1 = np.array(node1) ; 
n2 = np.array(node2) ;  

edge = np.column_stack( (n1,n2) );
  
G=nx.Graph() 
G.add_edges_from(edge)
#nx.draw(G)
cc = sorted(nx.connected_components(G), key = len, reverse=True) ; 
result = list() ;  
for idx, val in enumerate(cc): 
    for n_val in val:
        result.append((n_val, idx)) ;

return result ; 
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 

/*
WITH input_transform AS (
	SELECT array_agg(adj[1] ORDER BY id ASC) as node1, array_agg(adj[2] ORDER BY id ASC)  as node2
	FROM adjacencies  
)
SELECT f.*
FROM input_transform, rc_py_ccomponents(node1,node2) as f ;
*/
