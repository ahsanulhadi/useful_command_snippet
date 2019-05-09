-- Last Analyze status:
select * 
from svl_statementtext s 
where s.text like 'padb_fetch_sample%' 
AND s.text not like '%volt%' 
and trunc(starttime) = trunc(getdate())
order by starttime desc;


-- =============================================================================
-- Check for UNSORTED ROWS. for which we need to run VACUUM. 
-- =============================================================================
/*
DATA SKEW: Key Distribution Style and Skew ->>

Skew is a critical factor related to a distribution style of KEY. Skew measures the ratio between the fewest and greatest number of rows on a compute node in the cluster. A high skew indicates that you have many more rows on one (or more) of the compute nodes compared to the other nodes. Skew results in performance hotspots and negates the benefits of distributing data for node-local joins. Check your assumptions with skew; sometimes you think a column provides good distribution but in reality it does not. A common occurrence is when you don’t realize that a column is nullable, resulting in rows with null placed on one compute node. If no column provides relatively even data distribution using a KEY distribution style, then choose a style of EVEN. For examples of checking skew, see the tuning reference below.

If you need to use a style of EVEN for some of your tables, then try to form your queries to join these tables as late as possible. This results in a smaller data set, when you apply the join to the evenly distributed table, and improves performance. 

*/

SELECT 
              TRIM(pgdb.datname) AS dbase_name, 
			  TRIM(pgn.nspname) as schemaname, 
			  TRIM(a.name) AS tablename, 
			  id AS tbl_oid, 
			  b.mbytes AS megabytes,  -- (No of Blocks allocated * 1MB)
			  a.rows AS rowcount, -- total table rows. 
			  a.unsorted_rows AS unsorted_rowcount, -- total unsorted rows. 
              CASE WHEN a.rows = 0 then 0 ELSE ROUND((a.unsorted_rows::FLOAT / a.rows::FLOAT) * 100, 5) END AS pct_unsorted,
              CASE WHEN a.rows = 0 THEN 'n/a'
                     WHEN (a.unsorted_rows::FLOAT / a.rows::FLOAT) * 100 >= 20 THEN 'VACUUM recommended'
                     ELSE 'n/a'
              END AS recommendation
FROM ( SELECT db_id, id, name, SUM(rows) AS rows, SUM(rows)-SUM(sorted_rows) AS unsorted_rows 
       FROM stv_tbl_perm -- contains information about the permanent tables including temporary tables created by a user for the current session.
       GROUP BY db_id, id, name
       ) AS a 
INNER JOIN pg_class AS pgc -- 'pg_class' catalogs tables and most everything else that has columns or is otherwise similar to a table. This includes indexes (but see also pg_index), sequences, views, composite types, and some kinds of special relation;
              ON pgc.oid = a.id
INNER JOIN pg_namespace AS pgn -- 'pg_namespace' stores namespaces which is the structure underlying SQL schemas. each namespace can have separate collection of relations, types, etc. without name conflicts.
              ON pgn.oid = pgc.relnamespace
INNER JOIN pg_database AS pgdb -- The catalog pg_database stores information about the available databases.
              ON pgdb.oid = a.db_id
LEFT OUTER JOIN (SELECT tbl, COUNT(*) AS mbytes -- No of Blocks allocated. 
       FROM stv_blocklist  -- STV_BLOCKLIST contains the number of 1 MB disk blocks that are used by each slice, table, or column in a database.
       GROUP BY tbl
       ) AS b ON a.id=b.tbl
WHERE a.rows <> 0 AND (a.unsorted_rows::FLOAT / a.rows::FLOAT) * 100 >= 20       
AND (TRIM(a.name) not like 'drop%' AND TRIM(a.name) not like '%_v1au' AND TRIM(a.name) not like 'tmp%')   
AND TRIM(pgn.nspname) in ('staging', 'model')                 
ORDER BY 1,3,2; 

-- =============================================================================

select 'VACUUM FULL ' ||schemaname||'.'||tablename||';'
from (SELECT
		TRIM(pgdb.datname) AS dbase_name
		,TRIM(pgn.nspname) as schemaname
		,TRIM(a.name) AS tablename
		,id AS tbl_oid
		,b.mbytes AS megabytes
		,a.rows AS rowcount
		,a.unsorted_rows AS unsorted_rowcount
		,CASE WHEN a.rows = 0 then 0
			ELSE ROUND((a.unsorted_rows::FLOAT / a.rows::FLOAT) * 100, 5)
		END AS pct_unsorted
		,CASE WHEN a.rows = 0 THEN 'n/a'
			WHEN (a.unsorted_rows::FLOAT / a.rows::FLOAT) * 100 >= 20 THEN 'VACUUM recommended'
			ELSE 'n/a'
		END AS recommendation
FROM
       (
       SELECT
              db_id
              ,id
              ,name
              ,SUM(rows) AS rows
              ,SUM(rows)-SUM(sorted_rows) AS unsorted_rows 
       FROM stv_tbl_perm
       GROUP BY db_id, id, name
       ) AS a 
INNER JOIN
       pg_class AS pgc 
              ON pgc.oid = a.id
INNER JOIN
       pg_namespace AS pgn 
              ON pgn.oid = pgc.relnamespace
INNER JOIN
       pg_database AS pgdb 
              ON pgdb.oid = a.db_id
LEFT OUTER JOIN
       (
       SELECT
              tbl
              ,COUNT(*) AS mbytes 
       FROM stv_blocklist 
       GROUP BY tbl
       ) AS b 
              ON a.id=b.tbl
WHERE pgn.nspname in ('model','staging')      
AND (TRIM(a.name) not like 'drop%' and TRIM(a.name) not like '%_v1au' and TRIM(a.name) not like 'tmp%')        
ORDER BY 1,3,2)
where recommendation like 'VA%'

-- ==============================================================================
-- RE INDEX. 
-- ==============================================================================
/*
The query engine is able to use sort order to efficiently select which data blocks need to be scanned to process a query. For an interleaved sort, Amazon Redshift analyzes the sort key column values to determine the optimal sort order. If the distribution of key values changes, or skews, as rows are added, the sort strategy will no longer be optimal, and the performance benefit of sorting will degrade. To reanalyze the sort key distribution you can run a VACUUM REINDEX. The reindex operation is time consuming, so to decide whether a table will benefit from a reindex, query the SVV_INTERLEAVED_COLUMNS view.
*/
-- To identify tables that might need to be reindexed, execute the following query.

select ic.tbl as tbl_id, 
tbl.name as table_name, 
ic.col,  -- Zero-based index for the column. 
ic.interleaved_skew, -- Ratio that indicates of the amount of skew present in the interleaved sort key columns for a table. A value of 1.00 indicates no skew, and larger values indicate more skew. 
-- Tables with a large skew should be reindexed with the VACUUM REINDEX command.
ic.last_reindex -- Time when the last VACUUM REINDEX was run for the specified table. This value is NULL if a table has never been reindexed using VACUUM REINDEX. 
from svv_interleaved_columns as ic, stv_tbl_perm as tbl 
where ic.tbl = tbl.id
and ic.interleaved_skew is not null
and ic.interleaved_skew <> 1.00
order by ic.interleaved_skew desc;

-- Vaccuum info: 
http://docs.aws.amazon.com/redshift/latest/dg/vacuum-managing-vacuum-times.html

-- Use Time Series Tables: 
http://docs.aws.amazon.com/redshift/latest/dg/vacuum-time-series-tables.html


-- ------------------------------------------------------------------------------------
-- The view returns one row per table per vacuum transaction. The view records the elapsed time of the operation, the number of sort partitions created, 
-- the number of merge increments required, and deltas in row and block counts before and after the operation was performed.
-- ---------------------------------------------------------------------------------
select table_name -- Name of the vacuumed table.
, xid	-- Transaction ID of the VACUUM operation.
, sort_partitions	-- Number of sorted partitions created during the sort phase of the vacuum operation.
, merge_increments -- Number of merge increments required to complete the merge phase of the vacuum operation.
, elapsed_time -- Elapsed run time of the vacuum operation (in microseconds).
, row_delta -- Difference in the total number of table rows before and after the vacuum.
, sortedrow_delta	-- Difference in the number of sorted table rows before and after the vacuum.
, block_delta	-- Difference in block count for the table before and after the vacuum.
, max_merge_partitions -- This column is used for performance analysis and represents the maximum number of partitions that vacuum can process for the table per merge phase iteration. 
-- (Vacuum sorts the unsorted region into one or more sorted partitions. Depending on the number of columns in the table and the current Amazon Redshift configuration, the merge phase can process a maximum number of partitions in a single merge iteration. 
-- The merge phase will still work if the number of sorted partitions exceeds the maximum number of merge partitions, but more merge iterations will be required.)
from SVV_VACUUM_SUMMARY;


select tbl.table_id, tbl.schemaname, tbl.tableName, vc.status, vc.rows, vc.sortedrows, vc.blocks, vc.max_merge_partitions, vc.eventtime 
from (select a.table_id, a.schema schemaname, a.table as tablename from SVV_TABLE_INFO a) tbl, STL_VACUUM vc
where tbl.table_id = vc.table_id
order by eventtime desc, schemaname, tablename asc
-- ==============================================================================
-- TABLE COPY OPTIONS 
-- ==============================================================================
/* You can perform a deep copy instead of a vacuum. The following example uses CREATE TABLE LIKE to perform a deep copy.

-- ----------------
create table likecalendardays (like calendardays);
insert into likecalendardays (select * from calendardays);
drop table calendardays;
alter table likecalendardays rename to calendardays;
-- ----------------
Performing a deep copy using CREATE TABLE AS (CTAS) is faster than using CREATE TABLE LIKE, but CTAS does not preserve the sort key, encoding, distkey, and notnull attributes of the parent table. For a comparison of different deep copy methods,
http://docs.aws.amazon.com/redshift/latest/dg/performing-a-deep-copy.html
*/

-- ==============================================================================
-- VACCUUM  
-- ==============================================================================
http://docs.aws.amazon.com/redshift/latest/dg/t_Reclaiming_storage_space202.html
http://docs.aws.amazon.com/redshift/latest/dg/r_VACUUM_command.html

-- Examples:
-- Reclaim space and resort rows in the SALES table.
vacuum sales;

-- Resort rows in the SALES table.
vacuum sort only sales;

-- Reclaim space in the SALES table.
vacuum delete only sales;

-- Reindex and then vacuum the LISTING table.
vacuum reindex listing;

-- Deciding whther to REINDEX.
http://docs.aws.amazon.com/redshift/latest/dg/r_vacuum-decide-whether-to-reindex.html
(see below) 


-- --------------------------------------------------------------------------------------
-- This view returns an estimate of how much time it will take to complete a vacuum operation that is currently in progress. 
-- ---------------------------------------------------------------------------------------
select table_name  -- Name of the table currently being vacuumed, or the table that was last vacuumed if no operation is in progress.
, status -- Description of the current activity being done as part of the vacuum operation (initialize, sort, or merge, for example).
, time_remaining_estimate -- Estimated time left for the current vacuum operation to complete, in minutes and seconds: 5m 10s, for example. An estimated time is not returned until the vacuum completes its first sort operation. 
-- If no vacuum is in progress, the last vacuum that was executed is displayed with Completed in the STATUS column and an empty TIME_REMAINING_ESTIMATE column. The estimate typically becomes more accurate as the vacuum progresses.
from SVV_VACUUM_PROGRESS;  


-- ==============================================================================
-- ANALYZE TABLE 
-- ==============================================================================


-- Examples: 
-- Analyze all of the tables in the TICKIT database and return progress information:
analyze verbose;

-- To Analyze table with column mentioned. 
analyze listing(listid, totalprice, listtime);

-- Analyze the LISTING table only:
analyze listing;

-- ==============================================================================
-- ANALYZE COMPRESSION
-- ==============================================================================
-- Perform compression analysis and produce a report with the suggested column encoding schemes for the tables analyzed.
http://docs.aws.amazon.com/redshift/latest/dg/r_ANALYZE_COMPRESSION.html

ANALYZE COMPRESSION 
[ [ table_name ]
[ ( column_name [, ...] ) ] ] 
[COMPROWS numrows]



/**********************************************************************************************
Purpose: View to get vacuum details like table name, Schema Name, Deleted Rows , processing time.
This view could be used to identify tables that are frequently deleted/ updated. 
History:
2015-07-01 srinikri Created
**********************************************************************************************/ 
CREATE OR REPLACE VIEW admin.v_get_vacuum_details
AS 
SELECT vac_start.userid,
       vac_start.xid,
       vac_start.table_id,
       tab.schema_name AS schema_name,
       tab.table_name AS table_name,
       vac_start.status start_status,
       vac_start. "rows" start_rows,
       vac_start. "blocks" start_blocks,
       vac_start. "eventtime" start_time,
	--vac_end.userid,
	--vac_end.xid,
	--vac_end.table_id,
       vac_end.status end_status,
       vac_end. "rows" end_rows,
       vac_end. "blocks" end_blocks,
       vac_end. "eventtime" end_time,
       (vac_start. "rows" - vac_end. "rows") AS rows_deleted,
       (vac_start. "blocks" - vac_end. "blocks") AS blocks_deleted_added,
       datediff(seconds,vac_start. "eventtime",vac_end. "eventtime") AS processing_seconds
FROM stl_vacuum vac_start
 LEFT JOIN stl_vacuum vac_end
    ON vac_start.userid = vac_end.userid
   AND vac_start.table_id = vac_end.table_id
   AND vac_start.xid = vac_end.xid
   AND vac_start.status = 'Started'
   AND vac_end.status = 'Finished'

  JOIN (SELECT DISTINCT TRIM(pgn.nspname) AS schema_name,
               name AS table_name,
               tbl.id AS table_id
        FROM stv_tbl_perm tbl
          JOIN pg_class pgc ON pgc.oid = tbl.id
          JOIN pg_namespace pgn ON pgn.oid = pgc.relnamespace) tab ON tab.table_id = vac_start.table_id
ORDER BY rows_deleted DESC;


-- --------------------------------------------------------------------------------------------------------------------------

