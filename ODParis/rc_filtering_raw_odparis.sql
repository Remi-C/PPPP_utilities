/*
Rémi Cura
THALES-TELECOM Terra Mobilita Project
29/08/2012

this script filters raw OpenData Paris data into more wokable data :
Each operation is explained
See documentation for more precisions

WARNING : depend on :

rc_random_string(INTEGER )
rc_change_all_libelle_info_length_in_a_schema(schema_name text)
 rc_add_prefix_to_info_column(text,text[],text[])


/////Operations order////

 -----------
| READ THIS |
 -----------
there are control if to skip some of the treatement, turn theim to true
(beginning of the script, declaration part)
 
1. Delete useless table
	_delete table 'arbres-remarquables'

2. Rename tables
	_'divers' => 'poteau'
	_'emplct_col' => collecte_de_verre
	_'environnement' => 'mobilier_urbain'
	_'arbre' => 'arbre'
	_'nbati' => 'volume_non_bati'
	_'murclotures' => 'mur_de_cloture'
	_'sanisettes' => 'sanisette'
	_'transports' => 'transport_public'
	_'vol_bati' => 'volume_bati'

3. Editing of complexe table
	_'arbre'
		_create this columns : 
			'gid' : from 'gid'
			'info' : from 'libelle', with short identifiers being defined as : 
				grille fonte/acier ajourÃ©e => ARB_GFA
				Terre sable => ARB_TS
				StabilisÃ© => ARB_ST
				Terre vÃ©gÃ©tale => ARB_TV
				Pavage => ARB_PA
				grille fonte/acier pleine => ARB_GFP
				Asphalte - Bitume => ARB_AB
				pavage provisoire => ARB_PP
				pavage granit => ARB_PG
				dalle granit => ARB_DG
				grille galvanisÃ©e => ARB_GG
				dalle gravillons => ARB_DG
				NULL => ARB_UNK
				__any other__ => literaly lib_etat_c (default case)
			'libelle' : from 'lib_etat_c'
			'environnement' : from 'lib_type_e'
			'genre' : from a concatenation of 'genre_fran', 'genre_lati', 'variete' with ';' separation character and thevalue 'unknown' when no information provided.
			'circonference' : from 'circonfere', but divided by 100 to have it in meters, and the 0 values are replaced by -1
			'hauteur' : from 'hauteur_m', again 0 values are replaced by -1
			'geom' : from 'geom'

	_'collecte_de_verre'
		_create this columns : 
			'gid' : from 'gid'
			'info' : from 'libelle', with short identifiers being defined as :
				NULL => COL_UNK
				Angle => COL_A
				Face => COL_F
				Terre plein central => COL_TPC
				Placette => COL_TPLC
				Sur stabilisé => COL_SS
				__any other__ => literaly lib_etat_c (default case)
			'libelle' : from lb_comp
			'geom' : from geom

	_jardin
		_create this columns : 
			'gid' : from 'gid'
			'info' : from libelle, with short identifiers being defined as :
				Square => JAR_SQ
				Jardin => JAR_JA
				Talus => JAR_TAL
				Murs végétalisés => JAR_MV
				Jardinet => JAR_JET
				Espace Vert => JAR_EV
				Promenade => JAR_PRO
				Jardin Partagé => JAR_JP
				Parc => JAR_PAR
				Jardinière => JAR_JRE
				Jardin d'immeubles => JAR_JI
				Esplanade => JAR_ESP
				Mail => JAR_MAI
				Terrain de boules => JAR_TB
				Pelouse => JAR_PEL
				Décoration => JAR_DEC
				Arboretum => JAR_ARB
				Plate_bande => JAR_PB
				NULL => JAR_UNK
			'libelle' : from 'denom'
			'surface_bati' : from 's_batie'
			'geom' : from 'geom'

	_mur_de_cloture
		_create this columns : 
			'gid' : from 'gid'
			'info' : from libelle, with short identifiers being defined as :
				X => MCL_X where X is an integer (currently 0, 2, 3, 6, 7, 9)
				NULL => MCL_UNK
			'libelle' : from 'igds_color'
			'geom' : from 'geom'
	_volume_non_bati
		_create this columns : 
			'gid' : from 'gid'
			'info' : from 'l_nat_nb', with short identifiers being defined as :
				NULL => VNB_UNK
				c_nat_nb=X => VB_X where X is a category :  (currently S, P, C, D for Sol, Voie privée, En chantier, Dalle)
			'libelle' : from 'l_nat_nb'
			'source' : from 'l_src',
			'surface' : from 'm2'

	_volume_bati
		_create this columns : 
			'gid' : from 'gid'
			'info' : from 'l_nat_nb', with short identifiers being defined as :
				NULL => VB_UNK
				Sol => VB_S
				Voie privée => VB_P
				En chantier => VB_C
				Dalle => VB_D
				* = any other value => VB_*
			'libelle' : from 'l_plan_h_i'
			'source' : from 'l_src',
			'surface' : from 'm2',
			'nombre_etage' : from 'h_et_max'
			'geom' : from 'geom'

4. Dealing with null and 'Objet sans identification particulière pour ce niveau' values

	_assainissement:
		This table is usual. Only problem : info contains nul values when libelle contains 'Objet sans identif...'  :3k rows
		_set info to 'ASS_UNK' when libelle is 'Objet sans identi...'
			info : NULL => 'ASS_UNK'
		_delete rows where info = 3 (4 rows over several k)
		

	_barriere :
		This table is abnormal because for info= 3 or 6, libelle is empty (NULL) (very few number of rows : 18/13000)
		_delete rows where info = 3 or 6

	_bati :
		This table is usual. Only problem : info contains nul vlaue when libelle contains 'Objet sans identif...' : 16 rows
		_set info to 'BAT_UNK' when libelle is 'Objet sans identi...'

	_borne : 
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'BOR_UNK'

	_detail_de_bati
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'DDB_UNK'

	_poteau
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'POT_UNK'

	_eau
		this table has problems : 
		for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'  => 
		_replace NULL by 'EAU_UNK'
		_there are NULL value in libelle : when libelle is null, put the info value
			_currently : case for EAUE and REGBIN

	eclairage_public
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'ECL_UNK'

	_electricite
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'ELC_UNK'

	collecte_de_verre : nothing to do

	
	_Mobilier_urbain
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'MOB_UNK'
		_currently : no case

	_indicateur
		this table has a probleme : there is 2 rows where info is null, this are useless, we delete it.
		_delete rows where info is NULL
		_currently : concerns 2 rows

	jardin, mur_de_cloture, volume_non_bati, relief_naturel : nothing to do

	_sanisette
		this table has problemes because the libelle is identical for info = WCH and WCH2.
		_add ' 2' at the end of libelle where info = WCH2
	
	_signalisation
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'SIG_UNK'

	_stationnement
		this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
		_we change the null value in info to 'STA_UNK'

	tansport_public : nothing to do

	_trottoir
		this table has serious problems : 
		many libelle are NULL where info contains something, we copy info contents into libelle
		_copy info contents into libelle when libelle is null
		there are 5 rows over 110 k where info = 2 or 3 , we delete theim
		_delete rows xhere info = 2 or 3
		in the niveau column, many null values, we replace theim by 'unknown'
		_replace NULL values in niveau by unknown

	volumne_bati : nothing to do 	

5. Changing the data type of 'libelle' and 'info'
	Change the dataype from 'varchar(X)' to 'text'
		suppres max length and avoid a length check.

6. Fusinning tables with close contents
	_'bati' with 'detail_de_bati'
	-- fusionning bati to detail_de_bati
				--adding a 'niveau' collumn to detail de bati, with default value __unknown__
				--adding all the bati rows to detail_de_bati and changing theire gid  : gid <- gid + max_gid of detail_de_bati. This way gid order is preserved (in case it holds some hidden organisation information)
				--deleting the former 'bati' table
	_'poteau' with 'borne'
	--fusionning poteau to borne
				--we add all poteau at the end of borne, changing poteau gid : gid <- gid + max_gid_of_borne to ensure preservation of order and uniqueness of gid.
				--deleting the former 'poteau' table

7. Changing info nomenclatura to add the table name as a prefixe except to info already prefixed (like BOR_UNK or DDB_UNK)
	--prefixing the info value by the info id of the table
		--only for info that is not already prefixed
	NOTE : currently table name and corresponfing prefix is given by hand, but it should be gathered in a table 


8. Creating Binary Tree indexes on the info columns
	--this part try to create btree indexes on all tables in schema which have an info column
		--btree indexes grandly speed up queries on info

9. Creating Rectangle Tree indexes on the geom info
	--this part tries to create gist index (geometric index) on the geometry columns table
		--gist indexes speed up greatly neirest neighbour search and other spatial queries.

10. Clustering physically the tables based on the index on info.
	--this part cluster phisically the table on disk to be organized following the info index.
		--this will speed up queries based on info.



WARNING :prototype only, not properly tested and/or proofed
*/

DROP FUNCTION IF EXISTS rc_filtering_raw_odparis(text,boolean[]);
CREATE OR REPLACE FUNCTION rc_filtering_raw_odparis(schema_name text,controle_d_execution boolean[] ) RETURNS boolean AS
$$
DECLARE
	schema_name text = $1;
	query text :='titi';
	table_name text := 'toto.toto';
	table_name_qualified text :='schema.table_name';
	table_name_random text := 'efpern';
	temp_boolean boolean := FALSE ;

	/************************/
	--execution control, set to true to execute
	deleting_table boolean 		:= controle_d_execution[1];   	--	delete useless table , safe to execute in any cases
	renaming boolean 		:= controle_d_execution[2];   	--	rename tables, safe to execute in anay cases
	editing boolean 		:= controle_d_execution[3];   	--	edit some complicated tables : won't work if tables don't have the right structure
	null_value boolean 		:= controle_d_execution[4];   	--	deal with null and unknown values, safe to execute in any case
	change_type boolean 		:= controle_d_execution[5];   	--	change the type of libeel and info column to text, safe to execute in any case
	fusionning boolean 		:= controle_d_execution[6];   	--	fusion some tables, not safe to execute in any cases : need tables to fuse
	prefixing boolean 		:= controle_d_execution[7];   	--	prefixing tables, safe to execute in any case, WARNINGc : takes  along time
	creating_info_indexes boolean  	:= controle_d_execution[8];   	--	creating indexes on info column , safe in any case, may be long
	creating_gist_indexes boolean	:= controle_d_execution[9];   	--	creating indexes on geom column, safe in any case, may be long
	clustering_on_info boolean	:= controle_d_execution[10];   	--	clustering tables using info index, safe, may be very long
	
	/************************/
	
BEGIN
	BEGIN
	--remove all in given schema
	--SELECT rc_delete_all_from_a_schema(quote_literal(schema_name));

	--copy all data from schema 'odparis' to target schema
	--SELECT rc_copy_all_from_a_schema_to_another(''odparis'',quote_literal(schema_name));
	--COMIT; record changes

	
	END;


	IF(TRUE= deleting_table)
		THEN
		RAISE NOTICE '	___begining of deleting_tables___';
		BEGIN --delete table arbres_remarquables if exists : this table contains only 60 trees, and the information is redundant with trees in 'arbres'
			EXECUTE 'DROP TABLE IF EXISTS ' || schema_name || '.arbres_remarquables ;' ; --delete the 'arbres_ermarquables' table
		 
		END;
	END IF;
	
	IF(TRUE = renaming )--skipping renaming
	THEN
	
		RAISE NOTICE '	___begining of renaming___';
		BEGIN --rename tables with confusing name
			BEGIN
			--renaming divers to poteau
			table_name := 	schema_name ||'.'|| quote_ident('divers') ; --name of the table to rename
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean; --chekc if this tbale exists
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('poteau'); --renaming the table
			END IF;
			END;

			BEGIN
			--renaming emplct_col to collecte_de_verre
			table_name := 	schema_name ||'.'|| quote_ident('emplct_col') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('collecte_de_verre');
				END IF;
			END;
			
			BEGIN
			--renaming environnement to mobilier_urbain
			table_name := 	schema_name ||'.'|| quote_ident('environnement') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('mobilier_urbain');
				END IF;
			END;

			BEGIN
			--renaming arbres to arbre
			table_name := 	schema_name ||'.'|| quote_ident('arbres') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('arbre');
				END IF;
			END;

			BEGIN
			--renaming nbati to volume_non_bati
			table_name := 	schema_name ||'.'|| quote_ident('nbati') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('volume_non_bati');
				END IF;
			END;

			BEGIN
			--renaming murclotures to mur_de_cloture
			table_name := 	schema_name ||'.'|| quote_ident('murclotures') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('mur_de_cloture');
				END IF;
			END;

			BEGIN
			--renaming sanisettes to sanisette
			table_name := 	schema_name ||'.'|| quote_ident('sanisettes') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('sanisette');
				END IF;
			END;

			BEGIN
			--renaming transports to transport_public
			table_name := 	schema_name ||'.'|| quote_ident('transports') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('transport_public');
				END IF;	
			END;	

			BEGIN
			--renaming vol_bati to volume_bati
			table_name := 	schema_name ||'.'|| quote_ident('vol_bati') ;
			EXECUTE 'SELECT rc_table_exists('|| quote_literal(table_name) ||');' INTO temp_boolean;
				IF temp_boolean = TRUE	
					THEN 
						EXECUTE 'ALTER TABLE '|| table_name || '  RENAME TO '|| quote_ident('volume_bati');
				END IF;	
			END;
			
		 
		END;--end of the table renaming
	END IF;--if to skip renamming

	IF(TRUE = editing)
	THEN 
		RAISE NOTICE '	___begining of editing_tables___';
		BEGIN --editing of table
			BEGIN--editing of arbres :keeps only a few columns, rename it, change content 

			table_name := quote_ident('arbre') ;
			table_name_qualified := schema_name ||'.'|| table_name ; 
			table_name_random := table_name_qualified || '_temp_' || rc_random_string(15);--make sur that the temporary table doesn't already exists by using a quite random name
			query := 'DROP TABLE IF EXISTS '|| table_name_random ||';
			CREATE TABLE '|| table_name_random ||' AS 
				SELECT 
					gid AS gid,  
					CASE --create a new info column based on libelle column
						--create an info ''ARB_GFA'' for ''grille fonte/acier ajouré''
						WHEN (lib_etat_c ~* ''grille\sfonte/acier\sajour.*'')    		
						/*--NOTE : posix regexp, not case sensitive, info are considered in order of statistical importance*/
						THEN ''ARB_GFA''
						--create an info ''ARB_TS'' for ''Terre sable''
						WHEN (lib_etat_c ~* ''Terre\ssable.*'')
						THEN ''ARB_TS''
						--create an info ''ARB_ST'' for ''Stabilisé''
						WHEN (lib_etat_c ~* ''Stabilis.*'')
						THEN ''ARB_ST''
						--create an info ''ARB_TV'' for ''Terre végétale''
						WHEN (lib_etat_c ~* ''Terre\sv.g.tale.*'')
						THEN ''ARB_TV''
						--create an info ''ARB_PV'' for ''Pavage''
						WHEN (lib_etat_c ~* ''Pavage$'')
						THEN ''ARB_PV''
						--create an info ''ARB_GFP'' for ''grille fonte/acier pleine''
						WHEN (lib_etat_c ~* ''grille\sfonte/acier\spleine.*'')
						THEN ''ARB_GFP''
						--create an info ''ARB_AB'' for ''Asphalte - Bitume''
						WHEN (lib_etat_c ~* ''Asphalte.*Bitume.*'')
						THEN ''ARB_AB''
						--create an info ''ARB_PP'' for ''pavage provisoire''
						WHEN (lib_etat_c ~* ''pavage\sprovisoire.*'')
						THEN ''ARB_PP''
						--create an info ''ARB_PG'' for ''pavage granit''
						WHEN (lib_etat_c ~* ''pavage\sgranit.*'')
						THEN ''ARB_PG''
						--create an info ''ARB_DGN'' for ''dalle granit''
						WHEN (lib_etat_c ~* ''dalle\sgranit'')
						THEN ''ARB_DGN''
						--create an info ''ARB_GG'' for ''grille galvanisée''
						WHEN (lib_etat_c ~* ''grille\sgalvanis.e.*'')
						THEN ''ARB_GG''
						--create an info ''ARB_DGV'' for ''dalle gravillons''
						WHEN (lib_etat_c ~* ''dalle\sgravillons'')
						THEN ''ARB_DGV''
						WHEN lib_etat_c IS NULL
						THEN ''ARB_NULL''
						WHEN TRUE --default case
						THEN lib_etat_c
					END AS info,
					CASE
						WHEN lib_etat_c IS NULL
						THEN ''ARB_NULL''
						ELSE lib_etat_c
					END  AS libelle, 
					lib_type_e AS environnement, 
					 COALESCE(genre_fran,''unknown'') ||'';'' || COALESCE(genre_lati,''unknown'') || '';'' || COALESCE(variete,''unknown'') AS genre, 
					CASE WHEN circonfere <= 0 
						THEN -1 
						ELSE circonfere / 100
					END AS circonference,  
					CASE WHEN hauteur_m <=0 
						THEN -1 
						ELSE hauteur_m
					END AS hauteur,
					geom AS geom
				FROM '||table_name_qualified||' ;
			
				DROP TABLE IF EXISTS '|| table_name_qualified ||';
				ALTER TABLE ' || table_name_random ||' RENAME TO '||table_name||';
			';
			EXECUTE query ;
			
			END;--end of the edition of table ___arbre___



			BEGIN -- edition of 'collecte_de_verre' table
			
			table_name := quote_ident('collecte_de_verre') ;
			table_name_qualified := schema_name ||'.'|| table_name ; --
			table_name_random := table_name_qualified || '_temp_' || rc_random_string(15);--make sur that the temporary table doesn't already exists by using a quite random name
		
			RAISE NOTICE 'table_name_randomù :%',table_name_random;

			query := 'DROP TABLE IF EXISTS '|| table_name_random ||';
			CREATE TABLE '|| table_name_random ||' WITH OIDS AS 
				SELECT 
					gid AS gid,  
					CASE --create a new info column based on libelle column
						--create an info ''COL_NULL'' for NULL value
						WHEN lb_comp IS NULL				--NOTE : posix regexp, not case sensitive, info are considered in order of statistical importance
						THEN ''COL_NULL''
						--create an info ''COL_A'' for ''Angle''
						WHEN (lb_comp ~* ''Angle.*'')    		
						THEN ''COL_A''
						--create an info ''COL_F'' for ''Face''
						WHEN (lb_comp ~* ''Face.*'')    		
						THEN ''COL_F''
						--create an info ''COL_TPC'' for ''Terre plein central''
						WHEN (lb_comp ~* ''Terre\splein\scentral.*'')    		
						THEN ''COL_TPC''
						--create an info ''COL_TP'' for ''Terre plein''
						WHEN (lb_comp ~* ''Terre\splein.*'')    		
						THEN ''COL_TP''
						--create an info ''COL_PLC'' for ''Placette''
						WHEN (lb_comp ~* ''Placette*'')    		
						THEN ''COL_PLC''
						--create an info ''COL_SS'' for ''Sur stabilisé''
						WHEN (lb_comp ~* ''Sur\sstabilis.*'')    		
						THEN ''COL_SS''
						WHEN TRUE --default case
						THEN lb_comp
					END AS info,
					lb_comp AS libelle, 
					geom AS geom
				FROM '||table_name_qualified||' ;
			
				DROP TABLE IF EXISTS '|| table_name_qualified ||';
				ALTER TABLE ' || table_name_random ||' RENAME TO '||table_name||' ;
			';
			--RAISE NOTICE 'query :%',query;
			EXECUTE query ;
			END; --end of edition of 'collecte_de_verre' table


			BEGIN --edition of 'jardin' table 

			table_name := quote_ident('jardin') ;
			table_name_qualified := schema_name ||'.'|| table_name ; --
			table_name_random := table_name_qualified || '_temp_' || rc_random_string(15);--make sur that the temporary table doesn't already exists by using a quite random name
		
			RAISE NOTICE 'table_name_random :%',table_name_random;

			query := 'DROP TABLE IF EXISTS '|| table_name_random ||';
			CREATE TABLE '|| table_name_random ||' WITH OIDS AS 
				SELECT 
					gid AS gid,  
					CASE --create a new info column based on libelle column
						--create an info ''JAR_UNK'' for NULL value
						WHEN denom IS NULL				--NOTE : posix regexp, not case sensitive, info are considered in order of statistical importance
						THEN ''JAR_UNK''
						--create an info ''JAR_SQ'' for ''Square'' value
						WHEN (denom ~* ''Square.*'')    		
						THEN ''JAR_SQ''
						--create an info ''JAR_JA'' for ''Jardin'' value
						WHEN (denom ~* ''Jardin$'')    		
						THEN ''JAR_JA''
						--create an info ''JAR_TAL'' for ''Talus'' value
						WHEN (denom ~* ''Talus.*'')    		
						THEN ''JAR_TAL''
						--create an info ''JAR_MV'' for ''Murs vgtaliss'' value
						WHEN (denom ~* ''Murs\sv.g.talis.s.*'')    		
						THEN ''JAR_MV''
						--create an info ''JAR_JET'' for ''Jardinet'' value
						WHEN (denom ~* ''Jardinet.*'')    		
						THEN ''JAR_JET''
						--create an info ''JAR_EV'' for ''Espace Vert'' value
						WHEN (denom ~* ''Espace\sVert.*'')    		
						THEN ''JAR_EV''
						--create an info ''JAR_PRO'' for ''Promenade'' value
						WHEN (denom ~* ''Promenade.*'')    		
						THEN ''JAR_PRO''
						--create an info ''JAR_JP'' for ''Jardin Partag'' value
						WHEN (denom ~* ''Jardin\sPartag.*'')    		
						THEN ''JAR_JP''
						--create an info ''JAR_PAR'' for ''Parc'' value
						WHEN (denom ~* ''Parc.*'')    		
						THEN ''JAR_PAR''
						--create an info ''JAR_JRE'' for ''Jardinire'' value
						WHEN (denom ~* ''Jardini.re.*'')    		
						THEN ''JAR_JRE''
						--create an info ''JAR_JI'' for ''Jardin d immeubles'' value
						WHEN (denom ~* ''Jardin\sd.immeubles.*'')    		
						THEN ''JAR_JI''
						--create an info ''JAR_ESP'' for ''Esplanade'' value
						WHEN (denom ~* ''Esplanade.*'')    		
						THEN ''JAR_ESP''
						--create an info ''JAR_MAI'' for ''Mail'' value
						WHEN (denom ~* ''Mail.*'')    		
						THEN ''JAR_MAI''
						--create an info ''JAR_TB'' for ''Terrain de boules'' value
						WHEN (denom ~* ''Terrain\sde\sboules.*'')    		
						THEN ''JAR_TB''
						--create an info ''JAR_PEL'' for ''Pelouse'' value
						WHEN (denom ~* ''Pelouse.*'')    		
						THEN ''JAR_PEL''
						--create an info ''JAR_DEC'' for ''Dcoration'' value
						WHEN (denom ~* ''D.coration.*'')    		
						THEN ''JAR_DEC''
						--create an info ''JAR_PB'' for ''Plate-bande'' value
						WHEN (denom ~* ''Plate.bande.*'')    		
						THEN ''JAR_PB''
						--create an info ''JAR_ARB'' for ''Arboretum'' value
						WHEN (denom ~* ''Arboretum.*'')    		
						THEN ''JAR_ARB''
						WHEN denom IS NULL
						THEN ''JAR_UNK''	
					END AS info,
					denom AS libelle, 
					CASE 
						WHEN s_batie >= 0 
						THEN s_batie
						ELSE ''0''
					END AS surface_bati, 
					geom AS geom
					
				FROM '||table_name_qualified||' ;
			
				DROP TABLE IF EXISTS '|| table_name_qualified ||';
				ALTER TABLE ' || table_name_random ||' RENAME TO '||table_name||' ;
			';
			--RAISE NOTICE 'query :%',query;
			EXECUTE query ;
			END;--end of edition of 'jardin' table

			
			BEGIN --edition of 'mur_de_cloture' table
			
			table_name := quote_ident('mur_de_cloture') ;
			table_name_qualified := schema_name ||'.'|| table_name ; --
			table_name_random := table_name_qualified || '_temp_' || rc_random_string(15);--make sur that the temporary table doesn't already exists by using a quite random name
		
			RAISE NOTICE 'table_name_random :%',table_name_random;

			query := 'DROP TABLE IF EXISTS '|| table_name_random ||';
			CREATE TABLE '|| table_name_random ||' WITH OIDS AS 
				SELECT 
					gid AS gid,  
					CASE --create a new info column based on libelle column
						--create an info ''MCL_UNK'' for NULL value
						WHEN igds_color IS NULL				--NOTE : posix regexp, not case sensitive, info are considered in order of statistical importance
						THEN ''MCL_UNK''
						--create an info ''MCL_X'' for ''X'' value
						WHEN igds_color IS NOT NULL
						THEN ''MCL_'' || igds_color::Text
						
					END AS info,
					igds_color::Text AS libelle, 
					geom AS geom
				FROM '||table_name_qualified||' ;
			
				DROP TABLE IF EXISTS '|| table_name_qualified ||';
				ALTER TABLE ' || table_name_random ||' RENAME TO '||table_name||' ;
			';
			--RAISE NOTICE 'query :%',query;
			EXECUTE query ;
			END; --end of edition of 'mur_de_cloture

			BEGIN -- edition of the 'volume_non_bati' table

			table_name := quote_ident('volume_non_bati') ;
			table_name_qualified := schema_name ||'.'|| table_name ; --
			table_name_random := table_name_qualified || '_temp_' || rc_random_string(15);--make sur that the temporary table doesn't already exists by using a quite random name
		
			RAISE NOTICE 'table_name_random :%',table_name_random;

			query := 'DROP TABLE IF EXISTS '|| table_name_random ||';
			CREATE TABLE '|| table_name_random ||' WITH OIDS AS 
				SELECT 
					gid AS gid,
					CASE 
						WHEN c_nat_nb IS NULL
						THEN ''VNB_UNK''
						ELSE ''VNB_''|| c_nat_nb 
					END AS info,
					l_nat_nb AS libelle,
					l_src AS source,
					m2 AS surface,
					geom AS geom
				FROM '||table_name_qualified||' ;
			
				DROP TABLE IF EXISTS '|| table_name_qualified ||';
				ALTER TABLE ' || table_name_random ||' RENAME TO '||table_name||' ;
			';
			--RAISE NOTICE 'query :%',query;
			EXECUTE query ;
			END;--end of edition of 'volume_non_bati' table


			BEGIN--edition of the 'volume_bati' table
			
			
			table_name := quote_ident('volume_bati') ;
			table_name_qualified := schema_name ||'.'|| table_name ; --
			table_name_random := table_name_qualified || '_temp_' || rc_random_string(15);--make sur that the temporary table doesn't already exists by using a quite random name
		
			RAISE NOTICE 'table_name_random :%',table_name_random;

			query := 'DROP TABLE IF EXISTS '|| table_name_random ||';
			CREATE TABLE '|| table_name_random ||' WITH OIDS AS 
				SELECT 	
					gid AS gid,
					CASE
						--create an info ''VB_4A8'' for ''Bâti de 4 à 8 étages''
						WHEN l_plan_h_i ~* ''B.ti\sde\s4\s.\s8\s.tages.*''
						THEN ''VB_4A8''
						--create an info ''VB_0RDC'' for ''Bâti à rez-de-chaussée''
						WHEN l_plan_h_i ~* ''B.ti\s.\srez.de.chauss.e.*''
						THEN ''VB_0RDC''
						--create an info ''VB_1A3'' for ''Bâti de 1 à 3 étages''
						WHEN l_plan_h_i ~* ''B.ti\sde\s1\s.\s3\s.tages.*''
						THEN ''VB_1A3''
						--create an info ''VB_9A12'' for ''Bâti de 9 à 12 étages''
						WHEN l_plan_h_i ~* ''B.ti\sde\s9\s.\s12\s.tages.*''
						THEN ''VB_9A12''
						--create an info ''VB_13P'' for ''Bâti de 13 étages et plus''
						WHEN l_plan_h_i ~* ''B.ti\sde\s13\s.tages\set\splus.*''
						THEN ''VB_13P''
						--create an info ''VB_UNK'' for NULL
						WHEN l_plan_h_i IS NULL
						THEN ''VB_UNK''
						--create an info copy_from_l_plan_h_i for other values
						WHEN 1=1
						THEN l_plan_h_i
					END AS info,
					l_plan_h_i AS libelle,
					l_nat_b AS type_de_bati,
					l_src AS source,
					m2 AS surface,
					h_et_max AS nombre_etage,
					geom AS geom
				FROM '||table_name_qualified||' ;
			
				DROP TABLE IF EXISTS '|| table_name_qualified ||';
				ALTER TABLE ' || table_name_random ||' RENAME TO '||table_name||' ;
			';
			--RAISE NOTICE 'query :%',query;
			EXECUTE query ;
			
			END;--end of the edition of 'volume_bati' table
		
		 
		END;--end of the table edition
	END IF; -- if to skip table editing

	IF(TRUE = null_value) --skipping null value dealing
	THEN
	
		RAISE NOTICE '	___begining of null values___';
		BEGIN --dealing with null and 'Objet sans identification' valors

			BEGIN -- table 'assainissement' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has problems : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL valeu in 'info'
				--we change the null value in info to ASS_UNK
				--also : 4 rows have 3 for info : delete theim
				RAISE NOTICE '		___null values of assainissement___';
				query := 
				' UPDATE '||quote_ident(schema_name)||'.assainissement SET info = ''ASS_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ' ||
				' DELETE FROM '||quote_ident(schema_name)||'.assainissement WHERE info = ''3'' ;' ;
				EXECUTE query;
			END; --end of edition of 'assainissement'

			BEGIN -- table 'barriere' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
		
				--This table is abnormal because for info= 3 or 6, libelle is empty (NULL) (very few number of rows : 18/13000)
				--_delete rows where info = 3 or 6
				RAISE NOTICE '		___null values of barriere___';
				query := ' DELETE FROM '||quote_ident(schema_name)||'.barriere WHERE info = ''6'' OR info = ''3'' ;' ;
				EXECUTE query;
			END;--end of edition of 'barriere'

			BEGIN -- table 'bati' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'BAT_UNK'
				--no null valuu in column 'niveau'
				RAISE NOTICE '		___null values of bati___';
				query := ' UPDATE '||quote_ident(schema_name)||'.bati SET info = ''BAT_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ';
				EXECUTE query;
			END;--end of edition of 'bati'

			BEGIN -- table 'borne' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'BOR_UNK'
				RAISE NOTICE '		___null values of borne___';
				query := ' UPDATE '||quote_ident(schema_name)||'.borne SET info = ''BOR_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ';
				EXECUTE query;
			END;--end of edition of 'borne'

			BEGIN -- table 'detail_de_bati' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'DDB_UNK'
				RAISE NOTICE '		___null values of detail_de_bati___';
				query := ' UPDATE '||quote_ident(schema_name)||'.detail_de_bati SET info = ''DDB_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ';
				EXECUTE query;
			END;--end of edition of 'edtail_de_bati'

			BEGIN -- table 'poteau' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'POT_UNK'
				RAISE NOTICE '		___null values of poteau___';
				query := ' UPDATE '||quote_ident(schema_name)||'.poteau SET info = ''POT_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ';
				EXECUTE query;
			END;--end of edition of 'poteau'

			BEGIN -- table 'eau' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has problems : 
					--for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'  => replace NUL by 'EAU_UNK'
					--there are NULL value in libelle : when libelle is null, put the info value (currently : case for EAUE and REGBIN
					--no case currently
				RAISE NOTICE '		___null values of eau___';
				query := 
					' UPDATE '||quote_ident(schema_name)||'.eau SET info = ''EAU_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; '||
					' UPDATE '||quote_ident(schema_name)||'.eau SET libelle = info WHERE libelle IS NULL ; ';
				EXECUTE query;
			END;--end of edition of 'eau'

			BEGIN -- table 'eclairage_public' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'ECL_UNK'
				RAISE NOTICE '		___null values of eclairage___';
				query := 
					' UPDATE '||quote_ident(schema_name)||'.eclairage_public SET info = ''ECL_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ' ;
				EXECUTE query;
			END;--end of edition of 'eclairage_public'

			BEGIN -- table 'electricite' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'ELC_UNK'
				--no case currently
				RAISE NOTICE '		___null values of electricite___';
				query := 
					' UPDATE '||quote_ident(schema_name)||'.electricite SET info = ''ELC_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ' ;
				EXECUTE query;
			END;--end of edition of 'electricite'

			BEGIN -- table 'collecte_de_verre' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has problems : 
					--whe change the null values in libelle by copying the content if info
					--we change the null value in info to 'COL_NULL'
					--no case currently
				RAISE NOTICE '		___null values of collecte_de_verre___';
				query := 
					' UPDATE '||quote_ident(schema_name)||'.collecte_de_verre SET libelle = info WHERE libelle IS NULL ; ' ;
				EXECUTE query;
			END;--end of edition of 'collecte_de_verre'

			BEGIN -- table 'mobilier_urbain' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'MOB_UNK'
				--no case currently
				RAISE NOTICE '		___null values of mobilier_urbain___';
				query := ' UPDATE '||quote_ident(schema_name)||'.mobilier_urbain SET info = ''MOB_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ' ;
				EXECUTE query;
			END;--end of edition of 'mobilier_urbain'

			BEGIN -- table 'indicateur' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has a probleme : there is 2 rows where info is null, this are useless, we delete it.
				RAISE NOTICE '		___null values of indicateur___';
				query := 'DELETE FROM '||quote_ident(schema_name)||'.indicateur WHERE info IS NULL ; ' ;
				EXECUTE query;
			END;--end of edition of 'indicateur'

			--jardin, mur_de_cloture, volume_non_bati, relief_naturel, sanisette : nothing to do

			BEGIN -- table 'sanisette' :  
				--this table has a problem : same libelle description for 2 different info WCH and WCH2
				--change the libelle value to ad' 2' at the end for info = WCH2
				RAISE NOTICE '		___null values of sanisette___';
				query :=

					' UPDATE '||quote_ident(schema_name)||'.sanisette SET libelle = libelle::TEXT || '' 2'' WHERE info = ''WCH2''; ' ;
				EXECUTE query;
			END;--end of edition of 'sanisette'
		
			BEGIN -- table 'signalisation' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'SIG_UNK'
				RAISE NOTICE '		___null values of signalisation___';
				query := 
					' UPDATE '||quote_ident(schema_name)||'.signalisation SET info = ''SIG_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ' ;
				EXECUTE query;
			END;--end of edition of 'signalisation'

			BEGIN -- table 'stationnement' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has no problem : for each 'Objet sans identification particulière pour ce niveau'  in 'libelle' there is a NULL value in 'info'
				--we change the null value in info to 'STA_UNK'
				RAISE NOTICE '		___null values of stationnement___';
				query := 
					' UPDATE '||quote_ident(schema_name)||'.stationnement SET info = ''STA_UNK'' WHERE libelle ~* ''.*Objet\ssans\sidentification\sparticuli.re.*'' ; ' ;
				EXECUTE query;
			END;--end of edition of 'stationnement'
			
			--tansport_public : nothing to do
			BEGIN -- table 'trottoir' : dealing with null and 'Objet sans identification particulière pour ce niveau' 
				--this table has serious problems : 
					--_many libelle are NULL where info contains something, we copy info contents into libelle
					--_there are 5 rows over 110 k where info = 2 or 3 , we delete theim
					--_in the niveau column, many null values, we replace theim by 'unknown'
					RAISE NOTICE '		___null values of trottoir___';
				query := 
					' DELETE FROM '||quote_ident(schema_name)||'.trottoir WHERE info ILIKE ''2'' OR info ILIKE ''3'' ; ' ||
					' UPDATE '||quote_ident(schema_name)||'.trottoir SET libelle = info WHERE libelle IS NULL ; ' ||
					' UPDATE '||quote_ident(schema_name)||'.trottoir SET niveau = ''unknown''  WHERE niveau IS NULL ;' ;
				EXECUTE query;
			END;--end of edition of 'trottoir'
			--volumne_bati : nothing to do 
		 
		END;--end of operations about null and 'objet sans identification...'

	END IF;--end of skipping dealing with null values


	IF(TRUE = change_type)
	THEN
		RAISE NOTICE '	___begining of changing column type___';
		BEGIN--change data type of info and libelle column to text : (cancel the max length)
			PERFORM rc_change_all_libelle_info_length_in_a_schema(schema_name);
		 
		END;--end of change of data type
	END IF;

	IF(TRUE = fusionning)--skipping fusions
	THEN
		RAISE NOTICE '	___begining of fusion___';
		BEGIN--fusionning tables with close content

			BEGIN -- fusionning bati to detail_de_bati
					--adding a 'niveau' collumn to detail de bati, with default value __unknown__
					--adding all the bati rows to detail_de_bati and changing theire gid  : gid <- gid + max_gid of detail_de_bati. This way gid order is preserved (in case it holds some hidden organisation information)
				RAISE NOTICE '		___fusion of bati___';
				query := '
				ALTER TABLE '||quote_ident(schema_name)||'.detail_de_bati ADD COLUMN niveau text DEFAULT ''unknown'' ;' ;
				EXECUTE query;

				query := '
				
				WITH max_gid AS( --compute the maw value of gid in detail_de_bati
					SELECT max(gid) AS m_g
					FROM '||quote_ident(schema_name)||'.detail_de_bati
				)
				INSERT INTO '||quote_ident(schema_name)||'.detail_de_bati ( gid, info, libelle, niveau, geom ) 
					SELECT gid+max_gid.m_g,info, libelle, niveau, geom 
					FROM '||quote_ident(schema_name)||'.bati, max_gid 
					ORDER BY gid ASC;
				--insert bati at the end of detail_de_bati and change the gid to ensure uniqueness and order preservation
				DROP TABLE '||quote_ident(schema_name)||'.bati;
				' ;
				RAISE NOTICE 'fusionning bati to detail_de_bati';
				EXECUTE query;
			END;--end of fusionning bati to detail_de_bati

			BEGIN --fusionning poteau to borne
					--we add all poteau at the end of borne, changing poteau gid : gid <- gid + max_gid_of_borne to ensure preservation of order and uniqueness of gid.
					
				RAISE NOTICE '		___fusion of poteau___';
				query := '
				WITH max_gid AS(
					SELECT max(gid) AS m_g
					FROM '||quote_ident(schema_name)||'.borne)
				INSERT INTO '||quote_ident(schema_name)||'.borne ( gid, info, libelle, geom ) 
					SELECT gid+max_gid.m_g,info, libelle, geom 
					FROM '||quote_ident(schema_name)||'.poteau, max_gid 
					ORDER BY gid ASC ;
				DROP TABLE '||quote_ident(schema_name)||'.poteau;
				' ;
				RAISE NOTICE 'fusionning poteau to borne';
				EXECUTE query;
			END;--end of fusionning poteau to borne
		 	
		END;

	END IF;--end of skipping fusions



	IF(TRUE = prefixing)--skipping of prefixing
		THEN 
		
		RAISE NOTICE '	___begining of prefixing___';
		BEGIN --prefixing the info value by the info id of the table
			--only for info that is not already prefixed
			--loop on all the table with an info column in the schema

			
			PERFORM rc_add_prefix_to_info_column( --will add prefixes if needed
				quote_ident(schema_name),
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
					'VNB']);--'volume_non_bati']
		 
		END; --end of prefixing
	END IF; --skpping of prefixing
	
	if(TRUE = creating_info_indexes)
		THEN
		BEGIN
		--this part try to create btree indexes on all tables in schema which have an info column
		--btree indexes grandly speed up queries on info
		RAISE NOTICE '	___begining of creating_info_indexes___';
		query := 'SELECT rc_create_index_on_all_info_column_in_schema('|| quote_literal(schema_name) ||');'; 
		EXECUTE query; 
		END;
	END IF;
	if(TRUE = creating_gist_indexes)
		THEN
		BEGIN
		--this part tries to create gist index (geometric index) on the geometry columns table
		--gist indexes speed up greatly neirest neighbour search and other spatial queries.
		RAISE NOTICE '	___begining of creating_gist_indexes___';
		query := 'SELECT rc_create_index_on_all_geom_column_in_schema('|| quote_literal(schema_name) ||');'; 
		EXECUTE query; 
		END;
	END IF;
	if(TRUE = clustering_on_info)
		THEN
		BEGIN
		--this part cluster phisically the table on disk to be organized following the info index.
		--this will speed up queries based on info.
		RAISE NOTICE '	___begining of clustering on info___';
		query := ' SELECT rc_cluster_on_all_info_column_in_schema('|| quote_literal(schema_name) ||');'; 
		EXECUTE query; 	
		END;
	END IF;

RETURN TRUE;
END;
$$LANGUAGE plpgsql;

/*exemple of use*/
--SELECT rc_delete_all_from_a_schema('odparis_reworked'::Text);
--SELECT rc_copy_all_from_a_schema_to_another('odparis','odparis_reworked');
--SELECT rc_filtering_raw_odparis('odparis_reworked'::Text);
--SELECT * FROM rc_gather_all_info_libelle_columns('odparis_reworked'::Text); 


/*exemple of use, each part of the function is executed ina  differnet begin end, this way all operations are not stored in memory during the execution of the function*/

BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked',ARRAY[TRUE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,TRUE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, TRUE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, FALSE,TRUE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, FALSE,FALSE, TRUE,FALSE, FALSE,FALSE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, FALSE,FALSE, FALSE,TRUE, FALSE,FALSE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, TRUE,FALSE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,TRUE, FALSE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, TRUE,FALSE]);
COMMIT;
END;
BEGIN;
	SELECT rc_filtering_raw_odparis('odparis_reworked'::Text,ARRAY[FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,FALSE, FALSE,TRUE]);
COMMIT;
END;



CREATE OR REPLACE FUNCTION rc_random_string(INTEGER )
RETURNS text AS $$
	SELECT array_to_string(
		ARRAY(
			SELECT 
				substring('ABCEFHJKLMNPRTWXY3478' FROM (random()*21)::int + 1 FOR 1) 
				FROM generate_series(1,$1)
		)
	,'')
$$ LANGUAGE sql;
--exemple use case :
--SELECT rc_random_string(10);
