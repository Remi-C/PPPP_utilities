/*
*Rémi Cura, 10/09/2012
*Thales T&S & Telecom ParisTech
*Confidential
*
*This PL/R function will compute a clustering based on the given table and column name
*Use nnclust, a r clustering package
*NOTE: ALL FUNCTIONS UNSAFE TO USE IF NOT ON WHOLE TABLE EXCEPT LAST ONE
*/


--R function prototype :
--input : numeric[][], length_wanted int,output : numeric[][]
--body : compute FFT to a fixed length (zero padding at the end if necessary)

DROP FUNCTION IF EXISTS odparis.rc_plr_cluster_using_nnclust(schema_name text,table_name text,column_name text, the_threshold numeric, the_fill numeric, the_giveup numeric );
CREATE OR REPLACE FUNCTION odparis.rc_plr_cluster_using_nnclust(schema_name text,table_name text,column_name text, the_threshold numeric, the_fill numeric, the_giveup numeric ) RETURNS setof record AS 
$$
	##printing inputs
	pg.thrownotice("WARNING : not safe to use if used on only a part of a table, odparis.rc_plr_cluster_using_nnclust_on_info");
	msg <- paste("inputs table : ", schema_name,".",table_name,".",column_name);
	pg.thrownotice(msg);

	##preparing select statement to get the values to cluster
	the_query <- paste("SELECT ",column_name,"::numeric FROM ", schema_name,".",table_name, " ORDER BY gid ASC ;",sep="");
	
	msg <- paste(" query to get data : ",the_query);
	#pg.thrownotice(msg);

	##executing select statement to get data
	#data_to_cluster <- data.frame( pg.spi.exec(the_query));
	#pg.spi.exec(the_query);
	data_to_cluster <- as.vector(pg.spi.exec(the_query));
	#pg.thrownotice(data_to_cluster);

	number_of_data <- dim(data_to_cluster)[1];

	##beginninng of data clustering 
	#loading the right library
	pg.thrownotice("loading the right library");
	require(nnclust);
	
	#giving the right shape to data
	pg.thrownotice("giving the right shape to data");
	data_to_cluster_2<-array(as.vector(data_to_cluster$area_concsurface),dim = c(number_of_data,1));

	pg.thrownotice(class(data_to_cluster$area_concsurface));
	
	#computing clustering
	pg.thrownotice("computing clustering");
	clustering <- nncluster(data_to_cluster_2 , threshold = the_threshold , fill = the_fill, give.up = the_giveup, verbose=TRUE , start=NULL);

	#getting cluster label for each symbol : an array with the cluster name, same order as data input in symbol_descriptor
	pg.thrownotice("getting cluster label");
	label<-clusterMember(clustering);

	#ploting the result of the clustering, each cluster has a different color, pch=20 set that we use point as plotting symbols
	#pg.thrownotice("plotting the data");
	#pg.thrownotice(dev.cur());
	#plot(data_to_cluster_2, col=label, pch=20);
	#dev.off();
	#WARNING : I CAN'T MAKE PLOTTING WORK ON A WINDOWS POSTGRES SERVER


	png("../plr2/supertestdelamortquitue.jpg")
	plot(data_to_cluster_2, col=label, pch=20);
	dev.off()
	
	#create the return type : a data.frame with a column gid and a column cluster_label
	pg.thrownotice("creating return result");
	result = data.frame(gid=c(1:number_of_data),cluster_label=label);
	return(result);
	
	
	#return(TRUE);
	#return data_to_cluster;
$$ LANGUAGE 'plr' STRICT;

/*
--Exemple use case
--creating an appropriate data table
	--dropping table if it previously existed
	DROP TABLE IF EXISTS odparis_test.indicateur_test_descriptor;

	--creating a table which contains original data plus two kind of surfaces calculated which will be used as descriptors
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
	SELECT gid, info, libelle, geom, surface, ST_Area(surface) AS area_surface, concsurface, ST_Area(concsurface) AS area_concsurface, 0::BigInt AS cluster_id
	FROM tata

	--checking 100 first value of the created table
	SELECT *
	FROM odparis_test.indicateur_test_descriptor
	LIMIT 100;


--launching clustering
	--launching clustering function
	--updating the cluster number with clustering result
	
	--exemple of clusters computing--	
	--SELECT * FROM odparis.rc_plr_cluster_using_nnclust('odparis_test','indicateur_test_descriptor','area_concsurface') AS t(gid integer,cluster_label numeric);

--updating the table with cluster result :
	UPDATE odparis_test.indicateur_test_descriptor AS table_to_update
		SET cluster_id = cluster_label 
		FROM odparis.rc_plr_cluster_using_nnclust('odparis_test','indicateur_test_descriptor','area_concsurface',0.0001,1,0) 
			AS t(gid integer,cluster_label numeric) 
		WHERE t.gid = table_to_update.gid

*/


/*
*A bit different plr f=unction thats does the cluster but use a given inpu as a query to get data for clustering
*WARNING : geom is supposed to be ordered with gid ASC
*/

DROP FUNCTION IF EXISTS odparis.rc_plr_cluster_using_nnclust(query_to_get_data text, the_threshold numeric, the_fill numeric, the_giveup numeric );
CREATE OR REPLACE FUNCTION odparis.rc_plr_cluster_using_nnclust(query_to_get_data text, the_threshold numeric, the_fill numeric, the_giveup numeric ) RETURNS setof record AS 
$$
	
	pg.thrownotice("WARNING : not safe to use if used on only a part of a table, use odparis.rc_plr_cluster_using_nnclust_on_info");
	##printing inputs
	msg <- paste("inputs SQL query :  ", query_to_get_data);
	pg.thrownotice(msg);

	##preparing select statement to get the values to cluster
	the_query <- query_to_get_data ;
	
	msg <- paste(" query to get data : ",the_query);
	#pg.thrownotice(msg);

	##executing select statement to get data
	#data_to_cluster <- data.frame( pg.spi.exec(the_query));
	#pg.spi.exec(the_query);
	data_to_cluster <- pg.spi.exec(the_query);
	#pg.thrownotice(data_to_cluster);

	number_of_data <- dim(data_to_cluster)[1];

	##beginninng of data clustering 
	#loading the right library
	pg.thrownotice("loading the right library");
	require(nnclust);
	
	#giving the right shape to data
	pg.thrownotice("giving the right shape to data");
	data_to_cluster_2<-array(as.vector(data_to_cluster$area_concsurface),dim = c(number_of_data,1));

	pg.thrownotice(class(data_to_cluster$area_concsurface));
	
	#computing clustering
	pg.thrownotice("computing clustering");
	clustering <- nncluster(data_to_cluster_2 , threshold = the_threshold , fill = the_fill, give.up = the_giveup, verbose=TRUE , start=NULL);

	#getting cluster label for each symbol : an array with the cluster name, same order as data input in symbol_descriptor
	pg.thrownotice("getting cluster label");
	label<-clusterMember(clustering);

	#ploting the result of the clustering, each cluster has a different color, pch=20 set that we use point as plotting symbols
	#pg.thrownotice("plotting the data");
	#pg.thrownotice(dev.cur());
	#plot(data_to_cluster_2, col=label, pch=20);
	#dev.off();
	#WARNING : I CAN'T MAKE PLOTTING WORK ON A WINDOWS POSTGRES SERVER


	pdf("../plr2/supertestdelamortquitue.pdf")
	plot(data_to_cluster_2, col=label, pch=20);
	dev.off()
	
	#create the return type : a data.frame with a column gid and a column cluster_label
	pg.thrownotice("creating return result");
	result = data.frame(gid=c(1:number_of_data),cluster_label=label);
	return(result);
	
	
	#return(TRUE);
	#return data_to_cluster;
$$ LANGUAGE 'plr' STRICT;

--exemple of use case :
/*
SELECT *
FROM odparis.rc_plr_cluster_using_nnclust(
	'
	SELECT area_surface, area_concsurface
	FROM odparis_test.indicateur
	--WHERE info = ''IND_CIM''
	ORDER BY gid ASC;
	'::text
, 0.0001, 1, 0) AS t(gid integer,cluster_label numeric) 
*/


/*
*Yet another version very different : require gid as first column input, then other column are considered as descriptors
*compute the clusters and output tuple of (gid,cluster_id)
*WARNING : geom is supposed to be ordered with gid ASC
*/

DROP FUNCTION IF EXISTS odparis.rc_plr_cluster_using_nnclust_on_info(query_to_get_data text, the_threshold numeric, the_fill numeric, the_giveup numeric );
CREATE OR REPLACE FUNCTION odparis.rc_plr_cluster_using_nnclust_on_info(query_to_get_data text, the_threshold numeric, the_fill numeric, the_giveup numeric ) RETURNS setof record AS 
$$
	##printing inputs
	msg <- paste("inputs SQL query :  ", query_to_get_data);
	pg.thrownotice(msg);

	##preparing select statement to get the values to cluster
	the_query <- query_to_get_data ;

	##executing select statement to get data
	data_to_cluster <-  pg.spi.factor(pg.spi.exec(the_query));

	##some warning if the first column is not full of int :
	#note : we can't just check type because of limited size of int : a big int could be mapped to numeric
	test_sample <- data_to_cluster[sample(1:(1+round(nrow(data_to_cluster)/100)), 1),1] ; #we take random sample in first column (1/100 of col size)
	if( test_sample!= round(test_sample) ) pg.throwerror(paste("WARNING : first column of data to cluster MUST BE an int identigfier (gid)"));#if samples are not integer, throw error

	##special cas : when only 1 sample : nncluster bugs 
	if(nrow(data_to_cluster)<=1) return(data.frame(data_to_cluster[1],0));
	
	##beginninng of data clustering 
	#loading the right library
	pg.thrownotice("loading the right library");
	require(nnclust);
	
	#computing clustering
	pg.thrownotice("computing clustering");
	clustering <- nncluster( #function to compute clustering, result are hold in clustering which is a dataframe
		data.matrix(data_to_cluster[2:(ncol(data_to_cluster)*1)]), ##data on which do the clustering : all input data except gid column (first one), all put in a matrix form
		threshold = the_threshold , 
		fill = the_fill, 
		give.up = the_giveup, 
		verbose=TRUE ,
		maxclust = 20, 
		start=NULL);

	#creating a plot output 
	#timestamp <- toString(pg.spi.factor(pg.spi.exec("SELECT CURRENT_TIMESTAMP(1) AS timestamp"))[1,1] );

	now <- format(Sys.time(), "%Y_%m_%d %H-%M-%S-%OS2");
	#extracting the info to put it in files
	the_info <- unlist(regmatches(query_to_get_data,regexec("'([^_]*_[^']*)'",query_to_get_data)))[2];
	
	#pg.thrownotice(paste(" now2 : ",now," the_info : ",the_info));
	output_directory<-paste("../plr2/clusters_plot-",now,"__",the_info,".png",sep="");
	pg.thrownotice(paste("creating a plot output in ",output_directory));
	png(
		filename = output_directory,
		width = 1920,
		height = 1400,
		units= "px");
	par("oma"=c(1,1,10,1));

	x<-0;
	if (is.na(clusterMember(clustering, outlier = FALSE))==TRUE) 
			{x<- x+1;
			the_label <- x;} 
		else {
			the_label <- clusterMember(clustering, outlier = FALSE)};

	#pg.thrownotice(toString(the_label));
	
	plot( data_to_cluster[1:2], col=the_label , pch=20, main = paste(now,query_to_get_data,sep="	"));
	dev.off();

	
	#create the return type : a data.frame with a column gid and a column cluster_label
	pg.thrownotice("creating return result");
	return(data.frame(data_to_cluster[1],clusterMember(clustering, outlier = FALSE)));
	
	#return(TRUE);
	#return data_to_cluster;
$$ LANGUAGE 'plr' STRICT;

--exemple of use case :

SELECT *
FROM odparis.rc_plr_cluster_using_nnclust_on_info(
	'
	SELECT gid AS gid, area_surface AS area_surface, area_concsurface AS area_concsurface
	FROM odparis_reworked.jardin
	WHERE info = ''JAR_EV''
	--ORDER BY gid ASC;'::text
, 0.0001, 1, 0) AS t(gid bigint, cluster_id bigint)

