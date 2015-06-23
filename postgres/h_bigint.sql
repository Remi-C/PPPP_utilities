
--found on internet : create a bigint hash out of a text

DROP FUNCTION IF EXISTS h_bigint(text) ; 
create or replace function h_bigint(text) returns bigint as $$
 select ('x'||substr(md5($1),1,16))::bit(64)::bigint;
$$ language sql;

DROP FUNCTION IF EXISTS h_int(text) ; 
create or replace function h_int(text) returns int as $$
 select ('x'||substr(md5($1),1,8))::bit(32)::int;
$$ language sql;