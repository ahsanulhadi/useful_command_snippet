

-- DATE FORMATING:
http://docs.aws.amazon.com/redshift/latest/dg/r_FORMAT_strings.html
http://docs.aws.amazon.com/redshift/latest/dg/r_DATEFORMAT_and_TIMEFORMAT_strings.html

-- ===================================
-- DATE 
-- ===================================

select current_date;  -- output: 2015-10-13
select timeofday(); -- output : Thu Sep 19 22:53:50.333525 2013 UTC
where starttime >= '2015-10-13 00:00' and endtime < '2015-10-13 23:59'  -- Date Range query


-- ===================================
-- WINDOW Functions 
-- ===================================

-- Rows = This clause specifies the rows in the current window or partition that the value in the current row is to be combined with. 
-- It uses arguments that specify row position, which can be before or after the current row. 

-- UNBOUNDED PRECEDING indicates that the window starts at the first row of the partition; offset PRECEDING indicates that the window starts a number of rows equivalent 
-- to the value of offset before the current row. UNBOUNDED PRECEDING is the default.
select salesid, qtysold,
count(*) OVER (order by salesid rows unbounded preceding) as count
from sales
order by salesid;

-- =======================================
-- LIKE, ILIKE (not case sensitive), 
-- =======================================
SELECT userid, firstname, city, state
FROM users
WHERE city = 'Omaha'
UNION
SELECT userid, firstname, city, state
FROM users
WHERE state = 'AB' AND firstname ILIKE 'ap%'
EXCEPT
SELECT userid, firstname, city, state
FROM users
WHERE firstname NOT LIKE 'E%'

-- ===================================
-- Aggregate Functions 
-- ===================================

-- LISTAGG: for each group, listagg order the row. 
SELECT sellerid, listagg(salesid, ',') 
WITHIN GROUP (order by salesid desc) as salesid
FROM Sales
WHERE saletime between '2008-01-01 00:00:00' and '2008-01-15 00:00:00' 
group by sellerid
order by sellerid;


-- STDDEV_SAMP = Square Root of the sample variance of the same set of values
-- STDDEV_POP =  

/*
The following query returns the average of the values in the VENUESEATS column of the VENUE table, followed by the sample standard deviation and 
population standard deviation of the same set of values. VENUESEATS is an INTEGER column. The scale of the result is reduced to 2 digits.
*/

SELECT avg(venueseats),
CAST(stddev_samp(venueseats) AS dec(14,2)) stddevsamp,
CAST(stddev_pop(venueseats) AS dec(14,2)) stddevpop
FROM venue;



-- Min, Max function
SELECT min(saletime), max(saletime)
FROM sales 
WHERE saletime between '2008-01-01 00:00:00' and '2008-02-01 00:00:00' 

-- Split part function. 
SELECT listtime,
split_part(listtime,'-',1) as Year,
split_part(listtime,'-',2) as Month,
split_part(split_part(listtime,'-',3),' ',1) as Day
FROM listing
LIMIT 5;

-- Find total sales on a given calendar date.
SELECT sum(qtysold) 
FROM   sales, date 
WHERE  sales.dateid = date.dateid 
AND    caldate = '2008-01-05';

-- Find top 10 buyers by quantity.
SELECT firstname, lastname, total_quantity 
FROM   (SELECT buyerid, sum(qtysold) total_quantity
        FROM  sales
        GROUP BY buyerid
        ORDER BY total_quantity desc limit 10) Q, users
WHERE Q.buyerid = userid
ORDER BY Q.total_quantity desc;

-- Find events in the 99.9 percentile in terms of all time gross sales.
SELECT eventname, total_price 
FROM  (SELECT eventid, total_price, ntile(1000) over(order by total_price desc) as percentile 
       FROM (SELECT eventid, sum(pricepaid) total_price
             FROM   sales
             GROUP BY eventid)) Q, event E
       WHERE Q.eventid = E.eventid
       AND percentile = 1
ORDER BY total_price desc;


SELECT eventid, totalPrice, percent_rank() OVER (partition by eventid, totalprice)
FROM (select   eventid, sum(pricepaid) totalPrice 
from      sales
group by  eventid)

-- ================================================================
-- JOINS
-- ================================================================

-- LEFT OUTER JOIN 
SELECT a.userid, a.firstname, a.likesports,
       b.userid, b.firstname, b.likerock
FROM (select u1.userid, u1.firstname, u1.likesports from users u1 where u1.likesports IS TRUE) A  -- Will bring all from 'Table-A'
LEFT OUTER JOIN (select u2.userid, u2.firstname, u2.likerock from users u2 where u2.likerock IS TRUE) B ON a.userid = b.userid
ORDER BY a.userid;

-- LEFT OUTER JOIN  (Oracle style)
SELECT a.userid, a.firstname, a.likesports,
       b.userid, b.firstname, b.likerock
FROM (select u1.userid, u1.firstname, u1.likesports from users u1 where u1.likesports IS TRUE) A, 
(select u2.userid, u2.firstname, u2.likerock from users u2 where u2.likerock IS TRUE) B 
WHERE a.userid = b.userid (+) -- Will bring all from 'Table-A'. Put (+) on the side where not all data will be there. 
ORDER BY a.userid;


-- Complex Join example: 
EXPLAIN SELECT a.userid, a.firstname, a.likesports
       ,b.userid, b.firstname, b.likerock
       ,c.userid, c.firstname, c.likejazz
FROM (select u1.userid, u1.firstname, u1.likesports from users u1 where u1.likesports IS TRUE) A  -- Will bring all from 'Table-A'
LEFT OUTER JOIN (select u2.userid, u2.firstname, u2.likerock from users u2 where u2.likerock IS TRUE) B ON a.userid = b.userid
LEFT OUTER JOIN (select u3.userid, u3.firstname, u3.likejazz from users u3 where u3.likejazz IS TRUE) C ON b.userid = c.userid 
-- Will also bring all from 'Table-C'. In this case 'table C' has priority and All rows from 'table C' will be brought but not from 'table-A'/'B'
ORDER BY a.userid;


-- ============================================================================================

