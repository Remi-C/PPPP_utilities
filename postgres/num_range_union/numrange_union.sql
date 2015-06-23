
/*
create temp table data (i int, val char);

insert into data (val, i)
values
('A',1),
('A',2),
('A',3),
('B',4),
('C',5),
('A',6),
('D',7),
('A',8),
('A',9),
('D',10),
('D',11),
('B',12),
('C',13),
('C',14)
;

with x
as
(
  select i,
         row_number() over () as xxx,
         val,
         row_number() over (partition by val order by i asc)
           - row_number() over () as d
  from data
  order by i
)
select val,
       count(*)
from x
group by d,
         val
order by min(i)

*/