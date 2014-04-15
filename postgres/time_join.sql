-----------------------------------------
--Remi-C, 14/04/2014
--
--A framewok to do time join :
--
--given a table A with a time column , and a table B with observations at different time moment,
--how to efficiently find , for every moment of B, the closest lower time and closest upper time of A .
--
--The approaches tested are direct (find the closest), semi direct (find one closest and infer the other), and range based (create range based on A, then find in which range oges an observation )
--
--the way to go seems to be with range
-----------------------------------------

--creating test data
	--intoducing usefull function to fill with random text
	    CREATE OR REPLACE FUNCTION rc_random_string(INTEGER )
	    RETURNS text AS $$
	    SELECT array_to_string(
	    ARRAY(
	    SELECT
	    substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' FROM (random()*36)::int + 1 FOR 1)
	    FROM generate_series(1,$1)
	    )
	    ,'')
	    $$ LANGUAGE sql;


	--creating tables
	    DROP TABLE IF EXISTS a;
	    DROP TABLE IF EXISTS b;

	    create table a(gid int, t numeric, r numrange, data text);
	    create table b(gid int, t numeric, data text);
	    CREATE INDEX ON a (t);
	    CREATE INDEX ON b (t); 

		CREATE INDEX ON a (gid);
	    CREATE INDEX ON b (gid); 
		--CREATE INDEX ON a USING spgist (r);
		CREATE INDEX ON a (r);

	--filling tables with random data
	    WITH the_serie AS (
		SELECT s AS gid,  s+random()/2-0.5 AS s, rc_random_string(100) aS data
		FROM generate_series(1,100000) AS s
	    )
	    insert into a (gid, t,r, data) SELECT gid, s, numrange((lag(s,1) over(ORDER BY the_serie.gid aSC))::numeric  ,s::numeric) , data
	    FROM the_serie;
	    --ORDER BY the_serie.gid ASC;
	    

	    WITH the_serie AS (
		SELECT  s as gid, s+(random()-0.5)*2 AS s, rc_random_string(100) aS data
		FROM generate_series(1,100000) AS s 
	    )
	    insert into b (gid, t, data) SELECT gid,s, data
	    FROM the_serie;

	-- som indexes areinvolved, so be sure that stats are up to date
		ANALYZE a;
		ANALYZE b;

--testing different options

	--computing join with range

		--slow : 80 sec
		DROP TABLE IF EXISTS t;
		CREATE TABLE t AS
			SELECT b.* 
			FROM b LEFT JOIN a ON (b.t <@ a.r)
			ORDER BY gid ASC
			LIMIT 30;

		--slow: 80 sec
		DROP TABLE IF EXISTS t;
		CREATE TABLE t AS
			SELECT b.* 
			FROM a,b 
			WHERE b.t <@a.r;

		--fast : 3sec
		DROP TABLE IF EXISTS t;
		CREATE TABLE t AS
			SELECT b.* , a.data as d2
			FROM a,b 
			WHERE b.t BETWEEN lower(a.r) AND upper(a.r);

	--direct approach

		--fast : 8 sec
		DROP TABLE IF EXISTS t;
		CREATE TABLE t AS
		    select a.t As a_t, b.t as b_t

		    from (
		      select t, least( least(t, mint), least(t, maxt)) as t2 from (
			select t,
			 (select t from a where a.t >= b.t order by a.t limit 1) as mint,
			 (select t from a where a.t < b.t order by a.t desc limit 1) as maxt
		      from b
		      ) as tmp
		    ) as tmp2
		    inner join a on (tmp2.t2 = a.t)
		    inner join b on (tmp2.t = b.t);


	--direct computation of range like data 
		-- slow
		--DROP TABLE IF EXISTS t;
		--CREATE TABLE t AS
		WITH a_lag AS (
			SELECT a.t, a.data, lag(a.t) OVER (ROWS BETWEEN 1 PRECEDING  AND CURRENT ROW) AS bef
			FROM a
			ORDER BY t ASC 
			)
		SELECT a_lag.*, b.*
		FROM a_lag, b
		WHERE b.t BETWEEN bef AND a_lag.t
		LIMIT 10;


	--direct trying to optimize
		 --find upper (lower value) from a to b, then join using the fact that the lower(upper value) is next in gid order
		DROP TABLE IF EXISTS t;
		CREATE TABLE t AS
		SELECT lower_b_a.gid AS gid_b, lower_b_a.t AS t_b --, lower_b_a.data AS data_b
			, lower_b_a.gid_l_b AS gid_a_lower--, a1.t AS t_a_lower, a1.data AS data_a_lower 
			, lower_b_a.gid_l_b -1 AS gid_a_upper --, a2.t AS t_a_upper, a2.data AS data_a_upper
		FROM	 (
				SELECT b.gid, b.t 
					, (SELECT  gid  FROM a WHERE a.t>=b.t order by a.t ASC LIMIT 1  ) AS gid_l_b
				FROM b) as lower_b_a
			LEFT OUTER JOIN a AS a1 ON (a1.gid = gid_l_b) LEFT OUTER JOIN a AS a2 ON  (a2.gid = gid_l_b-1);


 --example using range and interpolation 
	DROP TABLE IF EXISTS t;
		CREATE TABLE t AS
			SELECT b.gid AS gid_b, b.t as t_b, a.gid aS gid_a, a.r AS range_a, interpolated_weight.* 
			FROM a,b ,range_interpolate(a.r,b.t) AS interpolated_weight
			WHERE b.t BETWEEN lower(a.r) AND upper(a.r)
			LIMIT 10;
