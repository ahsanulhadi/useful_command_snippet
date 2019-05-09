-- ################################################################
-- Document Title:  REDSHIFT DBA QUERIES
-- Prepared By:		AHSANUL HADI | Email: ahsanulh@ticketek.com.au
-- Create Date:		OCT 13, 2015 
-- Contents: 		List of Views, Tables, queries that is required for Database administration/monitoring activity. 
-- ----------------------------------------------------------------
-- Comment:			
-- (1) These are listed under 'Title's like ' Session related views'. So when you add anything, try to put it under appropriate 'Title' or add a relevant new 'title'.					 
-- (2) Relevant notes (from RedShift documentation) are also added. 
-- (3) AWS Redshift provided Admin views/Scripts can be found here: https://github.com/awslabs/amazon-redshift-utils/tree/master/src
-- (4) 
-- (5) 
-- (6) 
-- 
-- ################################################################ 

-- ==========================================================
-- DB PERFORMANCE VIEWS. 
-- ==========================================================


-- ADMIN SQL Views:
https://github.com/awslabs/amazon-redshift-utils/tree/master/src/AdminViews

-- ADMIN Scripts: 
https://github.com/awslabs/amazon-redshift-utils/tree/master/src/AdminScripts


/* --- SYSTEM TABLES FOR DB management ----------------------
-- http://docs.aws.amazon.com/redshift/latest/dg/c_intro_system_views.html

(1) STL Tables for LOGGING. 
All STL view list: http://docs.aws.amazon.com/redshift/latest/dg/c_intro_STL_tables.html
STL log tables only retain approximately two to five days of log history, depending on log usage and available disk space. If you want to retain the log data, you will need to periodically copy it to other tables or unload it to Amazon S3.

(2) STV tables for SNAPSHOT Data. 
All STV views: http://docs.aws.amazon.com/redshift/latest/dg/c_intro_STV_tables.html
STV tables are virtual tables that contain snapshots of the current system data. They are based on transient in-memory data and are not persisted to disk-based logs or regular tables. 

(3) SYSTEM VIEWS:
System views contain a subset of data found in several of the STL and STV system tables. Systems views have an SVV or SVL prefix. System views that contain any reference to a transient STV table are called SVV views. Views containing only references to STL tables are called SVL views. System tables and views do not use the same consistency model as regular tables. It is important to be aware of this issue when querying them, especially for STV tables and SVV views. System views that contain any reference to a transient STV table are called SVV views. 

(4) SYSTEM CATALOG Tables: (pg_*)
The system catalog tables store schema metadata, such as information about tables and columns. System catalog tables have a PG prefix.
select distinct(tablename) from pg_table_def where schemaname = 'public';   -- list of tables.
select * from pg_user;  -- list of DB Users.


>> Check KEY DESIGN ISSUES below. 
*/

-- ===================================
-- TABLE, DISK SPACE, MEMORY  etc ..   
-- ===================================

-- Shows summary information for tables in the database. The view filters system tables and shows only user-defined tables. Used to diagnose and address table design issues that can influence query performance, including issues with compression encoding, distribution keys, sort style, data distribution skew, table size, and statistics.
-- It summarizes information from the STV_BLOCKLIST, STV_PARTITIONS, STV_TBL_PERM, and STV_SLICES system tables and from the PG_DATABASE, PG_ATTRIBUTE, PG_CLASS, PG_NAMESPACE, and PG_TYPE catalog tables.
select * from svv_table_info; 

-- Show Table's DIST STYLE, Dist Key, Sort Keys. Dist Style: [0=Even, 1=Key, 8=All]
SELECT  pc.relname as TableName, DECODE(pc.reldiststyle,'0','EVEN','1','KEY','8','ALL',NULL) as DistStyle,    -- 15
pt.tablename, pt.column, pt.encoding, pt.distkey, pt.sortkey,   --10
Decode(pt.distkey, True, '<<<', NULL) as Flag
FROM    pg_class pc
LEFT OUTER JOIN (select * from pg_table_def  where schemaname = 'public') as pt ON pc.relname = pt.tablename
WHERE pt.schemaname = 'public'
Order by pt.tablename asc, distkey desc, sortkey desc;

/* Note: Order of the column in the sort key. 
If the table uses a COMPOUND SORT KEY, then all columns that are part of the sort key have a POSITIVE value that indicates the position of the column in the sort key. 
If the table uses an INTERLEAVED SORT KEY, then all each column that is part of the sort key has a value that is alternately positive or negative, where the absolute value indicates 
the position of the column in the sort key. If 0, the column is not part of a sort key. */ 


-- Monitor per-table usage. Can't load more data in a full cluster. << Each block is 1 MB >> 
-- source: http://engineering.monetate.com/2014/06/02/increase-the-performance-of-your-redshift-queries/
SELECT bl.tbl -- table_id
, p.name -- table name 
, count(*) as "Blocks"
FROM stv_blocklist bl
JOIN stv_tbl_perm p ON p.id = bl.tbl AND p.slice = bl.slice
GROUP BY bl.tbl, p.name
ORDER BY count(*) DESC;


/* 
The STV_TBL_PERM table contains information about the permanent tables in Amazon Redshift, including temporary tables created by a user for the current session. 
STV_TBL_PERM contains information for all tables in all databases.  
*/

-- The following query shows whether or not table data is actually distributed over all slices:
select trim(name) as table, 
stv_blocklist.slice,  -- Node Slice
stv_tbl_perm.rows -- 
from stv_blocklist,stv_tbl_perm
where stv_blocklist.tbl=stv_tbl_perm.id
and stv_tbl_perm.slice=stv_blocklist.slice
and stv_blocklist.id > 10000 and name not like '%#m%'
and name not like 'systable%'
group by name, stv_blocklist.slice, stv_tbl_perm.rows
order by name, slice asc;

-- A large, unsorted region can kill performance even if your queries are otherwise well optimized. Monitor your unsorted rows with. This will identify tables that could use a vacuum.

SELECT btrim(pg_namespace.nspname::character varying::text) AS schema_name, 
btrim(p.name::character varying::text) AS table_name, 
sum(p."rows") AS "rows", 
sum(p.sorted_rows) AS sorted_rows, 
sum(p."rows") - sum(p.sorted_rows) AS unsorted_rows,
    CASE
        WHEN sum(p."rows") <> 0 THEN 1.0::double precision - sum(p.sorted_rows)::double precision / sum(p."rows")::double precision
    ELSE NULL::double precision
    END AS unsorted_ratio
FROM stv_tbl_perm p
JOIN pg_database d ON d.oid = p.db_id::oid
JOIN pg_class ON pg_class.oid = p.id::oid
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE d.datname = 'warehouse'::name AND p.id > 0
GROUP BY btrim(pg_namespace.nspname::character varying::text), btrim(p.name::character varying::text)
ORDER BY sum(p."rows") - sum(p.sorted_rows) DESC, sum(p.sorted_rows) DESC;

-- --------------------------------------------------------------------------------------------------------------------------
-- Check for UNSORTED ROWS. for which we need to run VACUUM. 

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
ORDER BY 1,3,2; 


-- Get all TABLE details (source: AWS)
-- List of Tables. (Schema Wise), distkeys, sortkeys etc.  
SELECT * FROM pg_table_def;  -- Better info in SVV_TABLE_INFO.

-- To view a list of all schemas, query the PG_NAMESPACE system catalog table:
select * from pg_namespace;

-- List of ALL Tables. 
SELECT *
FROM information_schema.tables
LIMIT 10;

select *
from information_schema.tables
where table_schema = 'public'
order by table_name;

-- Get Column Descriptions 
select *
from information_schema.columns
where table_schema = 'public'
order by table_name, ordinal_position;

-- Get definition for a table.
SELECT *    
FROM pg_table_def    
WHERE tablename = 'sales';    

-- Get Table Priviledge data
Select *
from information_schema.table_privileges
-- where table_schema = 'public';

-- Get Column Access Privileges. 
select * 
from information_schema.column_privileges
--where table_schema = 'public'
order by table_name, column_name;


-- -------------------------------------------
-- Table wise SPACE USAGE. 

SELECT 
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
       FROM stv_tbl_perm -- contains information about the permanent tables including temporary tables created by a user for the current session.
       GROUP BY db_id, id, name
       ) AS a 
INNER JOIN
       pg_class AS pgc -- 'pg_class' catalogs tables and most everything else that has columns or is otherwise similar to a table. This includes indexes (but see also pg_index), sequences, views, composite types, and some kinds of special relation;
              ON pgc.oid = a.id
INNER JOIN
       pg_namespace AS pgn -- 'pg_namespace' stores namespaces which is the structure underlying SQL schemas. each namespace can have separate collection of relations, types, etc. without name conflicts.
              ON pgn.oid = pgc.relnamespace
INNER JOIN
       pg_database AS pgdb -- The catalog pg_database stores information about the available databases.
              ON pgdb.oid = a.db_id
LEFT OUTER JOIN
       (
       SELECT
              tbl
              ,COUNT(*) AS mbytes -- No of Blocks allocated. 
       FROM stv_blocklist  -- STV_BLOCKLIST contains the number of 1 MB disk blocks that are used by each slice, table, or column in a database.
       GROUP BY tbl
       ) AS b 
              ON a.id=b.tbl
ORDER BY 1,3,2;
-- -------------------------------------------

       



-- ===================================
-- 'LEADER node' only functions.
-- ===================================
SELECT current_schema();

SELECT * 
FROM pg_table_def
WHERE schemaname = current_schema();

SELECT current_schema(), userid -- This function will not be supported on Worked Nodes. 
FROM users;





-- ===================================
-- SESSION RELATED.  
-- ===================================

-- Use the STV_SESSIONS table to view information about the active user sessions for Amazon Redshift. STL_SESSIONS contains session history, where STV_SESSIONS contains the current active sessions.
select process as pid, user_name, db_name, starttime from STV_SESSIONS
Select *  from STL_SESSIONS order by starttime desc;

-- Show connected and Disconnected SESSION.   
SELECT
	CASE WHEN disc.recordtime IS NULL THEN 'Y' ELSE 'N' END AS connected
	,init.recordtime AS conn_recordtime
	,disc.recordtime AS disconn_recordtime
	,init.pid AS pid
	,init.remotehost
	,init.remoteport
	,init.username AS username
	,init.dbname  
--	,(disc.duration/1000000) AS conn_duration_Sec
  ,CASE WHEN disc.duration IS NULL THEN disc.duration ELSE (disc.duration/1000000) END AS conn_duration_Sec   
FROM 
	(SELECT event, recordtime, remotehost, remoteport, pid, dbname, username FROM stl_connection_log WHERE event = 'initiating session') AS init -- SELECT ALL initiating session. 
LEFT OUTER JOIN
	(SELECT event, recordtime, remotehost, remoteport, pid, duration FROM stl_connection_log WHERE event = 'disconnecting session') AS disc
		ON init.pid = disc.pid
		AND init.remotehost = disc.remotehost
		AND init.remoteport = disc.remoteport		
WHERE disc.recordtime IS NULL		
ORDER BY init.recordtime DESC;

-- -------- TERMINATE/ CANCEL Sessions/Queries ---------------------------

-- Terminate idle sessions and free up the connections. You can terminate a session owned by your user. A superuser can terminate any session. 
-- If queries in multiple sessions hold locks on the same table, you can use PG_TERMINATE_BACKEND to terminate one of the sessions, which forces any currently running transactions in the terminated session to release all locks and roll back the transaction. Query the STV_LOCKS system table to view currently held locks.
SELECT pg_terminate_backend( pid )   -- pid is INTEGER value.  example: select pg_terminate_backend(7723); 

-- If a query is not in a transaction block (BEGIN … END), you can cancel the query by using the CANCEL command or the PG_CANCEL_BACKEND function.
-- syntax: CANCEL <process_ID> 'message' (optional msg that displays when the query is cancelled. If you do not specify a message, Redshift displays the default message. Must enclose the message in single quotes.
CANCEL 802;  -- output: ERROR:  Query (168) cancelled on user's request, where 168 is the query ID (not the process ID used to cancel the query).
CANCEL 802 'Long-running query'; -- output: ERROR:  Long-running query
select pg_cancel_backend(802); 

-- If PG_TERMINATE_BACKEND fails to terminate a session with a problematic statement (generally indicated by the statement being in STV_FLIGHT and PG_LOCKS but not making progress), make sure that a client tool is not using savepoints.

-- ---------------------------------------------


-- ===================================
-- QUERY RELATED views.  
-- ===================================

-- ============= WHO ARE CONNECTED ================================================
-- How many connections are there for each USER, RemoteHost wise and DB name wise. 
SELECT init.username AS username
	,init.remotehost
	,init.dbname  	
  ,count(*) as No_of_Connected
FROM 
	(SELECT event, recordtime, remotehost, remoteport, pid, dbname, username FROM stl_connection_log WHERE event = 'initiating session') AS init -- SELECT ALL initiating session. 
LEFT OUTER JOIN
	(SELECT event, recordtime, remotehost, remoteport, pid, duration FROM stl_connection_log WHERE event = 'disconnecting session') AS disc
		ON init.pid = disc.pid
		AND init.remotehost = disc.remotehost
		AND init.remoteport = disc.remoteport		
WHERE disc.recordtime IS NULL		 -- still connected
GROUP BY init.username, init.remotehost, init.dbname
ORDER BY init.username, init.remotehost, init.dbname ASC; 
-- my IP: 10.2.66.138

-- List of ALL users who are CONNECTED NOW. 
SELECT init.pid AS pid
  ,init.username AS username
	,init.remotehost
	,init.remoteport
	,init.dbname  	
	,init.recordtime AS conn_recordtime
	,disc.recordtime AS disconn_recordtime
  ,CASE WHEN disc.duration IS NULL THEN DATEDIFF('sec',init.recordtime, SYSDATE) ELSE (disc.duration/1000000) END AS conn_duration_Sec   	
  ,CASE WHEN disc.recordtime IS NULL THEN 'Y' ELSE 'N' END AS connected
--	,(disc.duration/1000000) AS conn_duration_Sec
FROM 
	(SELECT event, recordtime, remotehost, remoteport, pid, dbname, username FROM stl_connection_log WHERE event = 'initiating session') AS init -- SELECT ALL initiating session. 
LEFT OUTER JOIN
	(SELECT event, recordtime, remotehost, remoteport, pid, duration FROM stl_connection_log WHERE event = 'disconnecting session') AS disc
		ON init.pid = disc.pid
		AND init.remotehost = disc.remotehost
		AND init.remoteport = disc.remoteport		
WHERE disc.recordtime IS NULL -- means these are still CONNECTED.
-- AND 	init.remotehost = '10.2.66.138'	 -- trace IP wise
order by init.recordtime  desc; 
-- ORDER BY init.username, init.remotehost, init.recordtime ASC; 

-- Check the Queries for those specific PID. 
select * 
from stl_query 
where pid in (29363,29160)
order by starttime; 

select *
from stv_recents 
where pid in (29363,29160);


-- =====================================================================
-- Records all errors that occur while running queries.
select * from stl_error;

-- Get the process IDs for all currently running queries.
-- http://docs.aws.amazon.com/redshift/latest/dg/r_STV_RECENTS.html
select pid, starttime, duration,
trim(user_name) as user,
trim (query) as querytxt
from stv_recents
where status = 'Running';

-- Use the STV_INFLIGHT table to determine what queries are currently running on the database.
SELECT * FROM stv_inflight;

-- --------------------------------------------------------------------------------------------------------------------------
-- The AWS Redshift console does a pretty good job of showing queries running but doesn’t give a lot of detail into status. List queries currently executing with.
-- This shows the different stages of execution per query:

SELECT stv_exec_state.query, stv_exec_state.segment, 
stv_exec_state.step, 
"max"(stv_exec_state."label"::character varying::text) AS "label", 
"max"(stv_exec_state.is_diskbased::character varying::text) AS is_diskbased, 
sum(stv_exec_state.workmem) AS workmem, 
sum(stv_exec_state."rows") AS "rows", 
sum(stv_exec_state.bytes) AS bytes
FROM stv_exec_state
GROUP BY stv_exec_state.query, stv_exec_state.segment, stv_exec_state.step
ORDER BY stv_exec_state.query, stv_exec_state.segment, stv_exec_state.step;


/*
The STL_QUERY and STL_QUERYTEXT tables only contain information about queries, not other utility and DDL commands. 
For a listing and information on all statements executed by Amazon Redshift, you can also query the STL_DDLTEXT and STL_UTILITYTEXT tables. For a complete listing of all statements executed by Amazon Redshift, you can query the SVL_STATEMENTTEXT view.
*/

-- ALL QUERY Data 
select * from stl_query limit 10;
select * from STL_QUERYTEXT limit 10;
select * from STL_DDLTEXT limit 10;

-- Show five most RECENT QUERIES.
select query, trim(querytxt) as sqlquery
from stl_query
order by query desc 
limit 5;
-- or
select * from SVL_QLOG;


-- TIME ELAPSED in descending order for queries that ran with DATE RANGE. 
select query, datediff(seconds, starttime, endtime), trim(querytxt) as sqlquery
from stl_query
where starttime >= '2015-10-13 00:00' and endtime < '2015-10-13 23:59'
order by date_diff desc
limit 20;

--------- OPTIMIZE ------------ 
/* stl_alert_event_log: 
Records an alert when the query optimizer identifies conditions that might indicate performance issues. Use this to identify opportunities to improve query performance.
A query consists of multiple segments, and each segment consists of one or more steps. STL_ALERT_EVENT_LOG is user visible.
*/ 

SELECT userid, query 
, slice -- Number that identifies the slice where the query was running. 
, segment  -- Number that identifies the query segment.
, step  -- Query step that executed.
, pid  -- Process ID associated with the statement and slice. The same query might have multiple PIDs if it executes on multiple slices.
, xid  -- Transaction ID associated with the statement.
, event  -- 
, solution  -- Recommended solution.
, event_time   -- 
from stl_alert_event_log 
order by event_time DESC, query, segment ASC;

select *
from stl_alert_event_log
limit 20;

-- Fetch Query also   * * *
SELECT sq.userid, sq.query, sq.pid, sq.database, sq.querytxt, sq.starttime, sq.endtime,
ev.slice, ev.segment, ev.step, ev.pid, ev.xid, ev.event, ev.solution, ev.event_time
FROM stl_query as sq
INNER JOIN stl_alert_event_log as ev
ON sq.userid = ev.userid 
AND sq.query = ev.query
WHERE to_char(sq.starttime,'YYYY-MM-DD') = (current_date - 1)
ORDER BY ev.event_time desc

/* STL_ALERT_EVENT_LOG records the following alerts:

Missing Statistics: Run ANALYZE following data loads or significant updates and use STATUPDATE with COPY operations. For more information, see: http://docs.aws.amazon.com/redshift/latest/dg/c_designing-queries-best-practices.html

Nested Loop: Nested loop is usually a Cartesian product. Evaluate query to ensure that all participating tables are joined efficiently.

Very Selective Filter: The ratio of rows returned to rows scanned is less than 0.05. Rows scanned is the value of rows_pre_user_filter and rows returned is the value of rows in the STL_SCAN system table. 
Indicates that the query is scanning an unusually large number of rows to determine the result set. This can be caused by missing or incorrect sort keys. For more information, see: http://docs.aws.amazon.com/redshift/latest/dg/t_Sorting_data.html

Excessive Ghost Rows: A scan skipped a relatively large number of rows that are marked as deleted but not vacuumed, or rows that have been inserted but not committed. For more information, see: http://docs.aws.amazon.com/redshift/latest/dg/t_Reclaiming_storage_space202.html

Large Distribution: More than 1,000,000 rows were redistributed for hash join or aggregation. For more information, see: http://docs.aws.amazon.com/redshift/latest/dg/t_Distributing_data.html

Large Broadcast: More than 1,000,000 rows were broadcast for hash join. For more information, see: http://docs.aws.amazon.com/redshift/latest/dg/t_Distributing_data.html

Serial Execution: A DS_DIST_ALL_INNER redistribution style was indicated in the query plan, which forces serial execution because the entire inner table was redistributed to a single node. For more information, see Choosing a Data Distribution Style.
*/


--------------------------------

/*
svl_query_summary: To find general information about the execution of a query. It contains a subset of data from the SVL_QUERY_REPORT view. 
It only contains information about queries executed by Amazon Redshift, not other utility and DDL commands. 
For a complete listing and information on all statements executed by Amazon Redshift, including DDL and utility commands, you can query the SVL_STATEMENTTEXT view.
*/

select userid -- ID of user who generated entry.
, query -- Query ID. Can be used to join various other system tables and views.
, stm -- Stream: A set of concurrent segments in a query. A query has one or more streams.
, seg -- Segment number. A query consists of multiple segments, and each segment consists of one or more steps. Query segments can run in parallel. Each segment runs in a single process.
, step -- Query step that executed.
, maxtime -- Maximum amount of time for the step to execute (in microseconds).
, avgtime -- Average time for the step to execute (in microseconds).
, rows -- Number of data rows involved in the query step.
, bytes -- Number of data bytes involved in the query step.
, rate_row -- Query execution rate per row.
, rate_byte -- Query execution rate per byte.
, label -- Step label, which consists of a query step name and, when applicable, table ID and table name. 3-digit table IDs refer to scans of transient tables. tbl=0, sually refers to a scan of a constant value.
, is_diskbased -- Whether this step of the query was executed as a disk-based operation on any node in the cluster: true (t) or false (f). Only certain steps, such as hash, sort, and aggregate steps, can go to disk. Many types of steps are always executed in memory.
, workmem -- Amount of working memory (in bytes) assigned to the query step.
, is_rrscan -- If true (t), indicates that range-restricted scan was used on the step. Default is false (f).
, is_delayed_scan -- If true (t), indicates that delayed scan was used on the step. Default is false (f).
, rows_pre_filter -- For scans of permanent tables, the total number of rows emitted before filtering rows marked for deletion (ghost rows).
from svl_query_summary 
where userid > 1
and query = 2335
order by stm, seg, step asc;   -- (Will show user's data with Priviledge. Not 'Super User's data.)  
 

-- --------- LOCKS -----------------
-- Query the STV_LOCKS system table to view currently held LOCKS.
select * from STV_LOCKS; 

-- ---------------------------------
-- Displays the EXPLAIN plan for a query that has been submitted for execution.
select query, nodeid, parentid, plannode -- substring(plannode from 1 for 30),
info -- substring(info from 1 for 20) 
from stl_explain
where query=9
order by 1,2 desc;  -- when ordered in DESC, the order of the nodes is reversed to show the actual order of execution:

-- The following query retrieves the query IDs for any QUERY PLANS that contain a WINDOW function:
select query, trim(plannode) from stl_explain where plannode like '%Window%';

-- Check for EXPLAIN plans which flagged "missing statistics" .. 
SELECT substring(trim(plannode),1,100) AS plannode  -- The node text from the EXPLAIN output. Plan nodes that refer to execution on compute nodes are prefixed with XN in the EXPLAIN output.
       ,COUNT(*)
FROM stl_explain
WHERE plannode LIKE '%missing statistics%'
GROUP BY plannode
ORDER BY 2 DESC;

