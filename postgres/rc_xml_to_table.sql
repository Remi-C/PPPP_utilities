
DROP FUNCTION IF EXISTS rc_xml_to_table(input_xml xml,table_name text, schema_name TEXT);
CREATE OR REPLACE FUNCTION  rc_xml_to_table(input_xml xml, table_name text, schema_name TEXT DEFAULT 'public')
  RETURNS boolean AS
$$
		--@param the input xml we want to convert to a table
		--@param name of the output table where to write result (existing table wil be deleted)
		--@param name of the schema for the ouput table, it is 'public' by default
		--@return : always return true except when problem with sql. Create a table with a conversion of xml to table.


		-------
		--Note : this function "flatten" a xml tree into a table.
		--the principle is simple, for each node of the xml tree, add one line per parameter, and one line per children node, keeping an id.
		--this guarantee that the xml tree could be reconstructed from the result table (no information loss)
		--sadly the table massively duplicates information, but this is mandatory
		--
		--dependencies : rc_unnest_with_ordinality
		--
	DECLARE 
	_sql text;
	_stop_statement TEXT;
	_iteration INT :=1;
	_depth_pattern text;
	_stop boolean;
	_eoq TEXT;
	_j int;
	_column_names TEXT;
	BEGIN
		
		--creating the beginning of the querry
			_sql :=  '
			DROP TABLE IF EXISTS '|| quote_ident(schema_name) ||'.'|| quote_ident(table_name)  ||' ;
			CREATE TABLE '|| quote_ident(schema_name) ||'.'|| quote_ident(table_name)  ||'  AS
		WITH L0 AS (
			SELECT
				(L0_xml_r).ordinality AS L0_id, L0_xml_r.value AS L0_xml ,( xpath(''name(/*)'',L0_xml_r.value))[1] AS L0_name 
				, CASE WHEN xpath_exists(''/*/@*'',L0_xml_r.value) THEN  (rc_unnest_with_ordinality(xpath(''/*/@*'',L0_xml_r.value))).ordinality  ELSE NULL END as L0_attributes_id
				, CASE WHEN xpath_exists(''/*/@*'',L0_xml_r.value) THEN (rc_unnest_with_ordinality(xpath(''/*/@*'',L0_xml_r.value))).value ELSE NULL END as L0_attributes
			FROM  rc_unnest_with_ordinality(xpath(''/*'',$1)) as L0_xml_r)
		,L0_b AS (
			SELECT L0.* 
				,CASE WHEN xpath_exists(''/*/@*'',L0_xml) THEN  ( xpath(''name(/*/@*['' || L0_attributes_id||''])'',L0_xml))[1] ELSE NULL END AS L0_attributes_name
			FROM L0)';

				
		--we stop when _stop_statement is false
		_depth_pattern := repeat('/*',_iteration);
		_stop_statement := 'SELECT  xpath_exists('|| quote_literal(_depth_pattern) ||',$1) as u1';
		--RAISE NOTICE '%',_stop_statement;
		EXECUTE _stop_statement INTO _stop USING input_xml;
		--RAISE NOTICE '%', _stop;
		IF _stop = FALSE THEN RAISE WARNING 'the provided xml is not deep enough (not even 1-level deep)';RETURN FALSE; END IF;
		_column_names := 'L0_id, L0_name,L0_attributes_id,L0_attributes,L0_attributes_name';
		
		--loop while we havn't reached the bottom of the tree
		<<going_deeper>>
		LOOP
			
			
			_depth_pattern := repeat('/*',_iteration);
			_sql := _sql|| '

			,L'||_iteration||'_a AS (
				SELECT '||_column_names ||'  
					, CASE WHEN xpath_exists(''/*/*'',L'||_iteration-1||'_xml) THEN (rc_unnest_with_ordinality(xpath(''/*/*'',L'||_iteration-1||'_xml))).value ELSE  NULL END as L'||_iteration||'_xml 
					, CASE WHEN xpath_exists(''/*/*'',L'||_iteration-1||'_xml) THEN (rc_unnest_with_ordinality(xpath(''/*/*'',L'||_iteration-1||'_xml))).ordinality ELSE  NULL END as L'||_iteration||'_id
				FROM L'||_iteration-1||'_b)
				
			,L'||_iteration||'_ab AS (
				SELECT '||_column_names ||' 
					,L'||_iteration||'_xml , L'||_iteration||'_id
					,( xpath(''name(/*)'',L'||_iteration||'_xml))[1] AS L'||_iteration||'_name 
					, CASE WHEN xpath_exists(''/*/@*'',L'||_iteration||'_xml) 
						THEN  (rc_unnest_with_ordinality(xpath(''/*/@*'',L'||_iteration||'_xml))).ordinality  
						ELSE NULL END as L'||_iteration||'_attributes_id
					, CASE WHEN xpath_exists(''/*/@*'',L'||_iteration||'_xml) 
						THEN (rc_unnest_with_ordinality(xpath(''/*/@*'',L'||_iteration||'_xml))).value 
						ELSE NULL END as L'||_iteration||'_attributes
				FROM L'||_iteration||'_a)
				
			,L'||_iteration||'_b AS(
				SELECT '||_column_names ||'
					, L'||_iteration||'_id
					, L'||_iteration||'_name
					, L'||_iteration||'_attributes_id
					, L'||_iteration||'_attributes
					,  L'||_iteration||'_xml 
					,CASE WHEN xpath_exists(''/*/@*'',L'||_iteration||'_xml) 
						THEN  ( xpath(''name(/*/@*['' || L'||_iteration||'_attributes_id||''])'',L'||_iteration||'_xml))[1] 
						ELSE NULL END AS L'||_iteration||'_attributes_name
				FROM L'||_iteration||'_ab)';

			--RAISE NOTICE '%',_sql;
			--EXIT going_deeper;

			_column_names := _column_names ||', L'||_iteration||'_id, L'||_iteration||'_name, L'||_iteration||'_attributes_id, L'||_iteration||'_attributes, L'||_iteration||'_attributes_name';
			_iteration:=_iteration+1;
			_depth_pattern := repeat('/*',_iteration+1);
			_stop_statement := 'SELECT  xpath_exists('|| quote_literal(_depth_pattern) ||',$1) as u1';
			--RAISE NOTICE '%',_stop_statement;
			EXECUTE _stop_statement INTO _stop USING input_xml;
			IF _stop = FALSE THEN EXIT going_deeper; END IF;
		END LOOP;

		--adding the end of the query
			--ne garder que les colonnes interessantes, c est a dire les L*_id, l*_name, L*_attributes_id, L*_attributes_name, L*_attributes , pour i de 1 a la fin de la boucle
			--loop on all depth level
			
			_eoq := '
			SELECT ';
			FOR _j IN 0.._iteration-1
			LOOP
				--raise notice 'loop %',_j;
				_eoq := _eoq ||' L' || _j||'_id , L' || _j||'_name, L' || _j||'_attributes_id, L' || _j||'_attributes_name, L' || _j||'_attributes  ';
				IF _j != _iteration-1 THEN _eoq := _eoq || ','; END IF;
			END LOOP;
			_eoq := _eoq ||' 
			FROM  L'||_iteration-1||'_b;';

			_sql := _sql || _eoq;
				--raise notice 'oeq %',_eoq;
			RAISE NOTICE '%',_sql;

		--executing the qerry
		EXECUTE _sql  USING input_xml;

	RETURN TRUE;
	END
	--example :
	--SELECT rc_xml_to_table(xml_,'output_table' ,'public')
	--FROM road_mark
$$
LANGUAGE plpgsql VOLATILE; 

