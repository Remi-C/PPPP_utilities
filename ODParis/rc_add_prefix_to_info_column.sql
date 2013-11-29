
/*
Rémi Cura
Thales Service& Telecom Paristech
Confidential

This function update all the info column by adding a given prefix if this prefix is not already present.

WARNING : prototype : non tested or proofed.

*/




DROP FUNCTION IF EXISTS rc_add_prefix_to_info_column(text,text,text);--remove the function before re-creating it : act as a security versus function-type change

CREATE OR REPLACE FUNCTION rc_add_prefix_to_info_column(schema_name text, table_name text, prefix text ) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	BEGIN --beiginnig of potential exception throwing block
		the_query := '
		WITH info_prefixed AS(
			SELECT 
				'''|| prefix  ||'_'' || info AS i_p,
				gid AS gid_prefixed
			FROM '||quote_ident(schema_name)||'.'||quote_ident(table_name)||'
			WHERE info !~* '''|| prefix  ||'_.*''
		)
		UPDATE '||quote_ident(schema_name)||'.'||quote_ident(table_name)||'
			SET info = info_prefixed.i_p 
			FROM info_prefixed 
			WHERE gid = info_prefixed.gid_prefixed
		; ';
		EXECUTE the_query ;
	EXCEPTION 
		WHEN undefined_table
		THEN RAISE NOTICE 'this table %.% doesn''t exist, skipping prefixing',schema_name,table_name;
		WHEN undefined_column
		THEN RAISE NOTICE 'this table %.% has no __info__ column, skipping prefixing',schema_name,table_name;
		WHEN duplicate_column OR ambiguous_column
		THEN 
			RAISE NOTICE 'this table %.% has an amiguous column __info__ or to many of theim, skipping prefixing',schema_name,table_name;
	END;
	
	/*END LOOP;*/
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
--SELECT rc_add_prefix_to_info_column('odparis_test'::Text,'assainissement','ASS');




DROP FUNCTION IF EXISTS rc_add_prefix_to_info_column(text,text[],text[]);--remove the function before re-creating it : act as a security versus function-type change
CREATE OR REPLACE FUNCTION rc_add_prefix_to_info_column(schema_name text, table_name text[], prefix text[]) RETURNS boolean
AS $$
DECLARE
    row record;
    result boolean;
    the_query text;
BEGIN
	FOR i IN 1..array_upper(table_name,1)
	LOOP
		RAISE NOTICE ' 			___prefixing table  %.% ',schema_name,table_name[i];
		EXECUTE 'SELECT rc_add_prefix_to_info_column('||quote_literal(schema_name::TEXT)||','||quote_literal(table_name[i])||','||quote_literal(prefix[i])||');' ; 
		
	END LOOP; 
	/*END LOOP;*/
	RETURN TRUE;
END;
$$LANGUAGE plpgsql; 

/*exemple use-case :*/
SELECT rc_add_prefix_to_info_column('odparis_test',ARRAY['assainissement','eau'],ARRAY['ASS','EAU']);
/*
SELECT rc_add_prefix_to_info_column(
			'odparis_reworked',
			ARRAY[
				'assainissement',
				'barriere',
				--'bati',--removed : fusionned with detail_de_bati 
				'borne',
				'collecte_de_verre',
				'detail_de_bati',
				'eau',
				'eclairage_public',
				'electricite',
				'indicateur',
				'jardin',
				'mobilier_urbain',
				'mur_de_cloture',
				--'poteau', --removed : fusionned with borne
				'relief_naturel',
				'sanisette',
				'signalisation',
				'stationnement',
				'transport_public',
				'trottoir',
				'volume_bati',
				'volume_non_bati'],
			ARRAY[
				'ASS',--'assainissement',
				'BAR',--'barriere',
				-- 'BAT',--'bati', --removed : fusionned with detail_de_bati 
				'BOR',--'borne',
				'COL',--'collecte_de_verre',
				'DDB',--'detail_de_bati',
				'EAU',--'eau',
				'ECL',--'eclairage_public',
				'ELC',--'electricite',
				'IND',--'indicateur',
				'JAR',--'jardin',
				'MOB',--'mobilier_urbain',
				'MDC',--''mur_de_cloture',
				-- 'POT',--'poteau',--removed : fusionned with borne
				'REL',--'relief_naturel',
				'SAN',--'sanisette',
				'SIG',--'signalisation',
				'STA',--'stationnement',
				'TRA',--'transport_public',
				'TRO',--'trottoir',
				'VB',--'volume_bati',
				'VNB'])--'volume_non_bati']

*/

