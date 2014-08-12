
--found on internet : create a bigint has out of a text

create or replace function h_bigint(text) returns bigint as $$
 select ('x'||substr(md5($1),1,16))::bit(64)::bigint;
$$ language sql;


create or replace function h_int(text) returns int as $$
 select ('x'||substr(md5($1),1,8))::bit(32)::int;
$$ language sql;