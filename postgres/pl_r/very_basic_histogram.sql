
CREATE EXTENSION IF NOT EXISTS PLR;

DROP FUNCTION IF EXISTS  rc_plot_histo_basic(); 
CREATE OR REPLACE FUNCTION rc_plot_histo_basic() RETURNS text AS
$$
da_str <- pg.spi.exec ('select radius::numeric AS radius from buffer_variable.temp_visu_max_circle  WHERE radius <7 ORDER BY radius ASC  '); 
msg <- paste('hello : here is the data type : ', class(da_str) , head(da_str), da_str[,1]);
pg.thrownotice(msg)

pdf('/tmp/myplot4.pdf');
#hist <- hist(x= da_str[,1],breaks=30);
hist <- ecdf(da_str[,1]);
plot(hist ,freq=TRUE,  main = paste("Histogram of maximum turning radius")  );
dev.off();
print('done');
$$
LANGUAGE plr;

SELECT rc_plot_histo_basic() ;

