-------------------------------
-- Remi-C , Thales IGN, 2014
--
--
--an example of PLR function to plot an histogram
------------------------------


--CREATE EXTENSION IF NOT EXISTS PLR;


DROP FUNCTION IF EXISTS  rc_plot_histo_basic(); 
CREATE OR REPLACE FUNCTION rc_plot_histo_basic() RETURNS text AS
$$
	##this is an example, it should be customised
da_str <- pg.spi.exec ('select radius::numeric AS radius from buffer_variable.temp_visu_max_circle  WHERE radius <7 ORDER BY radius ASC  ');  ##import data
msg <- paste('hello : here is the data type : ', class(da_str) , head(da_str), da_str[,1]); 
#pg.thrownotice(msg)

pdf('/tmp/myplot4.pdf'); 		##one can export it as png also
#hist <- hist(x= da_str[,1],breaks=30); --for histogramm
hist <- ecdf(da_str[,1]); 		##for cumulativ histogram
plot(hist ,freq=TRUE,  main = paste("Histogram of maximum turning radius")  );
dev.off();
#print('done');
$$
LANGUAGE plr;

SELECT rc_plot_histo_basic() ;

