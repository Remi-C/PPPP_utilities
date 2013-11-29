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