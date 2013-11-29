

/*
Remi Cura, 26/09/2012
Thales & Telecom
This function is designed to compute association rules usig R arules package on a postgres table
it returns the found rules
*/


DROP FUNCTION IF EXISTS odparis.rc_plr_arules(query_to_get_data text );
CREATE OR REPLACE FUNCTION odparis.rc_plr_arules(query_to_get_data text ) RETURNS text AS 
$$
	##printing inputs
	msg <- paste("inputs SQL query :  ", query_to_get_data);
	pg.thrownotice(msg);

	##preparing select statement to get the transaction value
	pg.thrownotice("copying input query");
	the_query <- query_to_get_data ;
	
	##executing select statement to get data
	transaction_table <- pg.spi.exec(the_query);
	pg.thrownotice(paste("input data retrieven via the sql querry : ",toString(transaction_table)));
	pg.thrownotice(paste("attributes of data retrieven via the sql querry : ",toString(attributes(transaction_table))));
	pg.thrownotice(paste("first line of data retrieven : ",toString(transaction_table[1,])));

	

	##some warning if the first column is not full of int :
	#note : we can't just check type because of limited size of int : a big int could be mapped to numeric
	#test_sample <- transaction_table[sample(1:(1+round(nrow(transaction_table)/100)), 1),1] ; #we take random sample in first column (1/100 of col size)
	#if( test_sample!= round(test_sample) ) pg.throwerror(paste("WARNING : first column of data of transaction MUST BE an int identigfier (gid)"));#if samples are not integer, throw error

	
	
	##beginninng of finding association rules
	#loading the right library
	pg.thrownotice("loading the arules library");
	#require(arules);
	#library("arules");
	pg.thrownotice(paste("arules library loaded : ",toString(require(arules))));

	####only temp test : working code in r gui


data_2 <- list(	c("DDB_GRM", "DDB_UNK", "SIG_PVPPAPI", "TRO_BOR", "ECL_LEL"), 
			c("TRO_BOR", "SIG_BRS", "SIG_PVPPAPI"), 
			c("BOR_PIV", "DDB_BAT", "DDB_UNK", "ECL_LEMB", "SIG_PVPPAPI", "TRO_BOR"), 
			c("BOR_PIV", "DDB_BAT", "DDB_UNK", "ECL_LEMB", "MOB_POU", "SIG_PVPPAPI", "TRO_BOR", "BOR_BVO"), 
			c("BOR_PIV", "DDB_BAT", "ECL_LEMB", "SIG_FEPP", "SIG_POF", "SIG_PVPPAPI", "TRO_BOR"), 
			c("SIG_PVPPAPI", "TRO_BOR", "BOR_PIV", "MOB_POU"), 
			c("BOR_PIV", "DDB_ACP", "DDB_BAT", "SIG_PVPPAPI", "TRO_BOR"), 
			c("DDB_BAT", "MOB_POU", "SIG_PVPPAPI", "TRO_BOR"), 
			c("BOR_PIV", "ECL_LEL", "SIG_BRS", "SIG_PVPPAPI", "TRO_BOR", "TRO_BTT"), 
			c("BAR_BP14", "BOR_E2V", "BOR_PIV", "DDB_UNK", "ECL_LEL", "SIG_BRS", "SIG_PVPPAPI", "TRO_BOR"))
names(data_2) <- c(866, 867, 1032, 1033, 1034, 2004, 2005, 2006, 2508, 2509)
data_2_trans <- as(data_2, "transactions")
pg.thrownotice(paste("the transaction variable label: ",toString(labels(data_2_trans))));
pg.thrownotice(paste("the transaction variable show: ",toString(attributes(data_2_trans))));
toto <- unclass(data_2_trans);
pg.thrownotice(paste("the transaction variable unclassed: : ",toString(str(data_2_trans))));
rules <- apriori(data_2_trans, parameter = list(support = 0.01, confidence = 0.6));
#pg.thrownotice(paste("the rules : ",toString(attributes(rules))));



	####
	


	transaction <- as(transaction_table[,2], "transactions");
	pg.thrownotice(paste("the transaxtion variable : ",toString(attributes(transactionInfo))));
	
	#creating a plot output 
	#now <- format(Sys.time(), "%Y_%m_%d %H-%M-%S-%OS2");
	#extracting the info to put it in files
	#the_info <- unlist(regmatches(query_to_get_data,regexec("'([^_]*_[^']*)'",query_to_get_data)))[2];
	
	#pg.thrownotice(paste(" now2 : ",now," the_info : ",the_info));
	#output_directory<-paste("../plr2/clusters_plot-",now,"__",the_info,".png",sep="");
	#pg.thrownotice(paste("creating a plot output in ",output_directory));
	#png(
	#	filename = output_directory,
	#	width = 1920,
	#	height = 1400,
	#	units= "px");
	#par("oma"=c(1,1,10,1));
	
	#plot( data_to_cluster[1:2], col=the_label , pch=20, main = paste(now,query_to_get_data,sep="	"));
	#dev.off();

	
	#create the return type : a data.frame with a column gid and a column cluster_label
	#pg.thrownotice("creating return result");
	#return(data.frame(transaction_table[1]));
	
	#return(TRUE);
	return rules;
	#return('TRUE');
$$ LANGUAGE 'plr' STRICT;

/*exemple of use case*/

SELECT odparis.rc_plr_arules(query_to_get_data := 'SELECT * FROM odparis_test.transaction_pedestrian ORDER BY transaction_id LIMIT 3;'  );
