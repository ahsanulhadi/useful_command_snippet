http://docs.aws.amazon.com/redshift/latest/dg/query-plan-summary-map.html

select * from pg_group;  -- Check the created groups.
select * from pg_user; --  Check the created Users.
select * from wlm_queue_state_vw;
select * from wlm_query_state_vw;

-- IS THERE ANY DISK BASED QUERY ?? 
select a.*, b.*
from svl_query_summary a, (select query, trim(querytxt) as sqlquery from stl_query order by query desc limit 5) b
where a.query = b.query
and is_diskbased = 't'

-- ###############################################################
-- check query history for full text.
select * from STL_QUERY where query = 4745101
-- Get details 
SELECT 
	segment
	, step
	, slice
	, elapsed_time 
	, label
	, rows
	, bytes
	, CASE when is_diskbased = 't' then 'ALERT' else '' END as is_diskbased
	, workmem
	, is_rrscan
	, is_delayed_scan
	, rows_pre_filter
FROM 	svl_query_report 
WHERE 	query=4745101 
AND 	slice = 0
ORDER BY segment, step, slice;

-- broadcats info 

select query, slice, step, rows, (bytes/(1024*1024)) as MBytes, packets, datediff(seconds, starttime, endtime)
from stl_bcast
where query = query=4745101 and packets>0 and datediff(seconds, starttime, endtime)>0
order by slice, step;


-- ###############################################################
/**********************************************************************************************
Purpose: Return instances of table filter for all or a given table in the past 7 days

Columns:
table:		Table Name
filter:		Text of the filter from explain plan
secs:		Number of seconds spend scaning the table
num:		Number of times that filter occured
query:		Latest query id of a query that used that filter on that table

Notes:
Use the perm_table_name fileter to narrow the results


History:
2015-02-09 ericfe created
**********************************************************************************************/
SELECT a.table, a.filter, a.secs, (a.secs/60) as mins, a.num, a.query, 
'--', b.userid, b.label, b.database, b.querytxt, b.starttime, b.endtime 
FROM (select trim(s.perm_Table_name) as table , 
substring(trim(info),1,180) as filter, 
sum(datediff(seconds,starttime,
case when starttime > endtime then starttime else endtime end)) as secs, 
count(distinct i.query) as num, 
max(i.query) as query
from stl_explain p
join stl_plan_info i on ( i.userid=p.userid and i.query=p.query and i.nodeid=p.nodeid )
join stl_scan s on (s.userid=i.userid and s.query=i.query and s.segment=i.segment and s.step=i.step)
where s.starttime > dateadd(day, -7, current_Date)
and s.perm_table_name not like 'Internal Worktable%'
and p.info <> ''
and s.perm_table_name not like 'qry%' -- choose table(s) to look for
group by 1,2 ) a 
INNER JOIN STL_QUERY b on a.query = b.query
order by a.secs desc

SELECT a.table, a.filter, a.secs, (a.secs/60) as mins, a.query, 
'--', b.userid, b.label, b.database, b.querytxt, b.starttime, b.endtime 
FROM (select trim(s.perm_Table_name) as table , 
              substring(trim(info),1,180) as filter, 
              datediff(seconds,starttime, case when starttime > endtime then starttime else endtime end) as secs, 
              i.query as query
              from stl_explain p
              join stl_plan_info i on ( i.userid=p.userid and i.query=p.query and i.nodeid=p.nodeid )
              join stl_scan s on (s.userid=i.userid and s.query=i.query and s.segment=i.segment and s.step=i.step)
              where s.starttime > dateadd(day, -7, current_Date)
              and s.perm_table_name not like 'Internal Worktable%'
              and p.info <> ''
              and s.perm_table_name = 'performance' ) a  -- choose table(s) to look for
INNER JOIN STL_QUERY b on a.query = b.query
order by a.secs desc;


-- ===================================
-- Current Query locks. 
-- ===================================
-- Show user name, pid, table name, lock type etc.  
SELECT  table_id, last_update, lock_owner, lock_owner_pid, lock_status, tbl.name, 
qry.userid, qry.user_name, qry.starttime, (qry.duration/1000000) as duration_sec, qry.query, qry.status, qry.db_name   
FROM stv_locks  lk
inner join (select id, name, sum(rows) as num_rows
            from stv_tbl_perm 
            group by id, name) tbl  ON lk.table_id = tbl.id
inner join (select pid, userid, user_name, starttime, duration, query, status, db_name 
            from stv_recents where status <> 'Done') qry   ON qry.pid = lk.lock_owner_pid 
order by last_update desc;
 
-- Display information to identify and resolve lock conflicts with database tables. A lock conflict can occur when two or more users are loading, inserting, deleting, or updating data rows in the same table at the same time. 
-- Every time a lock conflict occurs, Amazon Redshift writes a data row to the STL_TR_CONFLICT system table.
select * 
from stl_tr_conflict 
order by xact_start_ts desc;

 
-- ===================================
-- QUERY RELATED views.  
-- ===================================

--  useful for getting an overall view of the queues and how many queries are being processed in each queue. to monitor what happens to queues after you change the WLM configuration. 
create view WLM_QUEUE_STATE_VW 
as
select (config.service_class-5) as queue -- The number associated with the row that represents a queue. Queue number determines the order of the queues in the database.
  , trim (class.condition) as description -- A value that describes whether the queue is available only to certain user groups, to certain query groups, or all types of queries.
  , config.num_query_tasks as slots -- The number of slots allocated to the queue. Slots are units of memory and CPU that are used to process queries.
  , config.query_working_mem as mem -- The amount of memory allocated to the queue.
  , config.max_execution_time as max_time -- The amount of time a query is allowed to run before it is terminated.
  , config.user_group_wild_card as "user_*" -- A value that indicates whether wildcard characters are allowed in the WLM configuration to specify user groups.
  , config.query_group_wild_card as "query_*" -- A value that indicates whether wildcard characters are allowed in the WLM configuration to specify query groups.
  , state.num_queued_queries queued -- The number of queries that are waiting in the queue to be processed.
  , state.num_executing_queries executing -- The number of queries that are currently executing.
  , state.num_executed_queries executed -- The number of queries that have executed.
from
  STV_WLM_CLASSIFICATION_CONFIG class,
  STV_WLM_SERVICE_CLASS_CONFIG config,
  STV_WLM_SERVICE_CLASS_STATE state
where
  class.action_service_class = config.service_class 
  and class.action_service_class = state.service_class 
  and config.service_class > 4
order by config.service_class;

	 
--   useful for getting a more detailed view of the individual queries that are currently running. to monitor the queries that are running. The following table describes the data that the WLM_QUERY_STATE_VW view returns.

create view WLM_QUERY_STATE_VW 
as
select query, -- The query ID.
(service_class-5) as queue, -- The queue number. 
slot_count, -- The number of slots allocated to the query.
trim(wlm_start_time) as start_time, -- The time that the query started.
trim(state) as state, -- The state of the query, such as executing.
trim(queue_time) as queue_time, -- The number of microseconds that the query has spent in the queue.
trim(exec_time) as exec_time -- The number of microseconds that the query has been executing.
from stv_wlm_query_state;


select * from wlm_queue_state_vw;
select * from wlm_query_state_vw;

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

-- # list all running processes:
select * 
from stv_recents 
where status = 'Running';

-- =========================================================================
-- # Query log
select query, starttime , substring from svl_qlog where substring like '%part%' order by starttime desc limit 50;

-- # command history
select * from stl_ddltext where text like '%ox_data_summary_hourly_depot%' limit 10;
-- =========================================================================

/*
identifies the top 50 most time-consuming statements that have been executed in the last 7 days. 
You can use the results to identify queries that are taking unusually long, and also to identify queries that are run frequently (those that appear more than once in the result set). 
These queries are frequently good candidates for tuning to improve system performance.
This query also provides a count of the alert events associated with each query identified. These alerts provide details that you can use to improve the query’s performance.
*/
select trim(database) as db, 
count(query) as n_qry, 
max(substring (qrytext,1,80)) as qrytext, 
min(run_minutes) as "min" , 
max(run_minutes) as "max", 
avg(run_minutes) as "avg", 
sum(run_minutes) as total,  
max(query) as max_query_id, 
max(starttime)::date as last_run, 
sum(alerts) as alerts, aborted
from (select userid, label, stl_query.query, 
        trim(database) as database, 
        trim(querytxt) as qrytext, 
        md5(trim(querytxt)) as qry_md5, 
        starttime, endtime, 
        (datediff(seconds, starttime,endtime)::numeric(12,2))/60 as run_minutes,     
        alrt.num_events as alerts, aborted 
        from stl_query 
        left outer join (select query, 1 as num_events 
                          from stl_alert_event_log group by query ) as alrt 
        on alrt.query = stl_query.query
        where userid <> 1 and starttime >=  dateadd(day, -7, current_date)  -- Last 7 days 
        ) 
group by database, label, qry_md5, aborted
order by total desc limit 50;




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
select userid, query,xid, pid, starttime, endtime, elapsed,aborted, label, substring from SVL_QLOG;

-- or



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
