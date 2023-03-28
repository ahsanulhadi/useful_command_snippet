-- ======================================
-- DATABASE
-- ======================================

# List of Databases 
SELECT *
FROM  pg_database
WHERE datistemplate is false;

# Check Database Size 
SELECT pg_size_pretty ( pg_database_size ('database_name') );
SELECT pg_database_size('__db_name__');
SELECT pg_size_pretty(pg_database_size('__db_name__'));

-- Find size of all Databases.
select datname, pg_size_pretty(pg_database_size(datname))
from pg_database
order by pg_database_size(datname) desc;




# Logout/Terminate All other DB connections:
SELECT *
FROM pg_stat_activity
ORDER BY query_start DESC;  -- All sessions.

SELECT pg_terminate_backend(pid)
FROM  pg_stat_activity
WHERE pid <> pg_backend_pid();   -- Kill other sessions.
-- WHERE usename = '__user_name__' AND query LIKE '%__query_pattern__%';
--- Kill specific session



-- =============================================
-- USERS  
-- =============================================

-- all database users
select * from pg_user;

-- =============================================
-- TABLE & INDEX  
-- =============================================

-- all tables and their size, with/without indexes
-- Find size of tables and indexes:
SELECT pg_size_pretty(pg_relation_size('public.table_name')); -- This value exclude indexes and some auxiliary data.

SELECT pg_size_pretty(pg_total_relation_size(‘users’)); -- If you want to include then use pg_total_relation_size.

SELECT relname, relpages FROM pg_class ORDER BY relpages DESC limit 1; -- find the largest table in the postgreSQL database.

# List all tables and indexes:

--  Create a View for this.
SELECT schemaname AS schema_name,
       relname AS table_name,
       pg_size_pretty(pg_relation_size (schemaname || '.' || relname))
AS size
FROM (SELECT schemaname,
             relname,
             'table' AS TYPE
      FROM pg_stat_user_tables
      UNION ALL
      SELECT schemaname,
relname,
             'index' AS TYPE
      FROM pg_stat_user_indexes) x;




# Top 10 biggest tables ( including indexes)
SELECT
       schemaname,
       tablename,
       pg_size_pretty( pg_total_relation_size(schemaname || '.' || tablename)) relsize,
       pg_total_relation_size(schemaname || '.' || tablename) relsizeinbytes
FROM
       pg_tables
ORDER BY
       4 DESC
LIMIT + 10;


# check the top 10 biggest indexes
SELECT
       schemaname,
       tablename,
       indexname,
       pg_size_pretty(pg_relation_size(schemaname || '.' || indexname)) idxsize,
       pg_relation_size(schemaname || '.' || indexname) indexsizeinbytes
FROM
       pg_indexes
ORDER BY
       5 DESC
LIMIT + 10;


-- List of all Constraints and related info:
-- Check > information_schema.constraint_column_usage
-- Check > information_schema.key_column_usage
SELECT *
FROM information_schema.table_constraints
WHERE table_schema = '__schema_name__'
AND constraint_type = 'CHECK';


#  Get all Comments (Table, Columns):

SELECT a.table_name,
       a.objsubid,
       b.column_name,
       a.description
FROM (SELECT nspname AS table_schema,
             relname AS table_name,
             objsubid,
             description
      FROM pg_description
        JOIN pg_class ON pg_description.objoid = pg_class.oid
        JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
      WHERE nspname = '__schema_name__') AS a
  LEFT JOIN (SELECT c.table_schema,
                    c.table_name,
                    c.ordinal_position,
                    c.column_name,
                    pgd.description
             FROM pg_catalog.pg_statio_all_tables AS st
               INNER JOIN pg_catalog.pg_description AS pgd ON
(pgd.objoid = st.relid)
               INNER JOIN information_schema.columns AS c
                       ON (pgd.objsubid = c.ordinal_position
                      AND c.table_schema = st.schemaname
                      AND c.table_name = st.relname)
             WHERE c.table_schema = '__schema_name__') AS b
         ON a.table_name = b.table_name
        AND a.objsubid = b.ordinal_position
ORDER BY a.table_name,
a.objsubid;



-- =============================================
-- QUERY STAT 
-- =============================================

/*
-- Explain plan 
Sometimes it shows less time because:
1) The Total runtime shown by EXPLAIN ANALYZE includes executor start-up and shut-down time, as well as the time to run any triggers 
that are fired, but it does not include parsing, rewriting, or planning time.
2)Since no output rows are delivered to the client, network transmission costs and I/O conversion costs are not included.
Warning!

The measurement overhead added by EXPLAIN ANALYZE can be significant, especially on machines with slow gettimeofday() operating-system calls.
 So, it's advisable to use EXPLAIN (ANALYZE TRUE, TIMING FALSE).

-- Explain-plan-Buffer calculation:
https://postgres.ai/blog/20220106-explain-analyze-needs-buffers-to-improve-the-postgres-query-optimization-process

Each buffer is normally 8 KiB, so it gives us 8 * 54173 / 1024 = ~423 MiB of data. 
Quite a lot to read just 1000 rows in a two-column table.
*/

SELECT
FROM
       pg_stat_activity
WHERE
       current_query != '<IDLE>'
       AND current_query NOT ILIKE '%pg_stat_activity%'
ORDER BY
       query_start DESC;

SELECT pid, age(clock_timestamp(), query_start), usename, query 
FROM pg_stat_activity 
WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%' 
ORDER BY query_start desc;

select * from pg_stat_activity where current_query not like '<%';



-- a current snapshot alternative to slow query log
-- Requires PostgreSQL 9.6+ (see postgres_queries_slow_pre96.sql and postgres_queries_slow_pre92.sql)
-- Tested on PostgreSQL 9.6+, 10x, 11.x, 12.x, 13.0

SELECT
  now() - query_start as "runtime",
  username,
  datname,
  state,
  query
FROM
  pg_stat_activity
WHERE
  -- can't use 'runtime' here
  now() - query_start > '30 seconds'::interval
ORDER BY
  runtime DESC;

-- Find Long Running queries
-- To prevent long running transactions from blocking vacuuming, you can terminate them by running pg_terminate_backend() on their PIDs.

SELECT pid, datname, usename, state, backend_xmin
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC;

-- =============================================
-- TABLE BLOAT
-- =============================================
-- Ref: https://medium.com/compass-true-north/dealing-with-significant-postgres-database-bloat-what-are-your-options-a6c1814a03a5
-- When a database table is suffering from bloat, query performance will suffer dramatically.
-- When a table is bloated, Postgres’s ANALYZE tool calculates poor/inaccurate information that the query planner uses. 
-- when you have table bloat in the 5+ range for a large table (10–100+ GB), the regular VACUUM ANALYZE VERBOSE table_name_here; command is going to take a prohibitively long time (think 4+ days, or even longer).

# Find all tables and when they were last vacuumed/analyzed, either manually or automatically
SELECT relname, 
       last_vacuum, 
       last_autovacuum, 
       last_analyze, 
       last_autoanalyze 
FROM   pg_stat_all_tables 
WHERE  schemaname = 'public' 
ORDER  BY last_vacuum DESC;


# Find any running processes that are doing autovacuum and which tables they're working on
SELECT   pid, 
         Age(query_start, Clock_timestamp()), 
         usename, 
         query 
FROM     pg_stat_activity 
WHERE    query != '<IDLE>' 
AND      query ilike '%vacuum%' 
ORDER BY query_start ASC;


# Find table/index sizes for all tables in a schema
SELECT *, 
       Pg_size_pretty(total_bytes) AS total, 
       Pg_size_pretty(index_bytes) AS INDEX, 
       Pg_size_pretty(toast_bytes) AS toast, 
       Pg_size_pretty(table_bytes) AS TABLE 
FROM   (SELECT *, 
               total_bytes - index_bytes - Coalesce(toast_bytes, 0) AS 
               table_bytes 
        FROM   (SELECT c.oid, 
                       nspname                               AS table_schema, 
                       relname                               AS TABLE_NAME, 
                       c.reltuples                           AS row_estimate, 
                       Pg_total_relation_size(c.oid)         AS total_bytes, 
                       Pg_indexes_size(c.oid)                AS index_bytes, 
                       Pg_total_relation_size(reltoastrelid) AS toast_bytes 
                FROM   pg_class c 
                       LEFT JOIN pg_namespace n 
                              ON n.oid = c.relnamespace 
                WHERE  relkind = 'r') a 
        WHERE  table_schema = 'public' 
        ORDER  BY total_bytes DESC) a; 

-- =============================================
-- PERFORMANCE STATS
-- =============================================

-- cache hit rates (should not be less than 0.99)
SELECT sum(heap_blks_read) as heap_read, sum(heap_blks_hit)  as heap_hit, (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) as ratio
FROM pg_statio_user_tables;

/* The pg_statio_all_tables view will contain one row for each table in the current database (including TOAST tables), showing statistics about I/O on that specific table.  */

select 
relname as table_name
, (heap_blks_hit - heap_blks_read) / heap_blks_hit as ratio

, heap_blks_read /* Number of disk blocks read from this table */
, heap_blks_hit /* Number of buffer hits in this table */
, idx_blks_read /* Number of disk blocks read from all indexes on this table */
, idx_blks_hit  /* Number of buffer hits in all indexes on this table */
, toast_blks_read /* Number of disk blocks read from this table's TOAST table (if any) */
, toast_blks_hit /* Number of buffer hits in this table's TOAST table (if any) */
, tidx_blks_read /* Number of disk blocks read from this table's TOAST table indexes (if any) */
, tidx_blks_hit /* Number of buffer hits in this table's TOAST table indexes (if any) */ 
FROM pg_statio_user_tables
where schemaname = 'public'
and heap_blks_hit <> 0 
order by table_name
;


-- table index usage rates (should not be less than 0.99)
SELECT relname
, 100 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used
, n_live_tup rows_in_table
FROM pg_stat_user_tables 
WHERE seq_scan + idx_scan > 0
ORDER BY n_live_tup DESC;

# Find out whether a table is too fragmented (Table Bloat) or not:
-- Check how many OS pages are allocated to the table. (works on Greenplum)
ANALYZE <table-name>;
SELECT relname,relpages,reltuples
  FROM pg_class
 WHERE relname = <table-name>;
-- Try running a vacuum full on the table and see if that make a
difference.
VACUUM <table-name>;
REINDEX <table-name>;
ANALYZE <table-name>;



-- Calculate DISK HIT / RATIO 


-- perform a "select pg_stat_reset();" when you want to reset counter statistics
/* Ref: https://dba.stackexchange.com/questions/10946/how-to-calculate-cache-misses-for-postgresql
 * The "disk hits" value means that the tuple was not found in the database's sharedbuffers. 
 * But it doesn't necessarily mean that db went to disk to get the tuple. Sometimes it can get you a good clue, specially when you have a dedicated server, 
 * where almost entire memory is reserved to the sharedbuffers. In that case, if you have a high "disk hits" percentage, that surely means it's time to upgrade memory. 
 * In the cases you have a shared server (and you can't "reserve" almost entire memory to sharedbuffers), and you have high "disk hits" percentage, 
 * it means the database is "racing" against the others process by the memory use, and depending of the memory use (by the other processes), 
 * it probably is going to the disk to get tuples. So, in one case or the other, you have to avoid high "disk hits" percentages.
 */

with all_tables as (
    SELECT  *
    FROM    (
        SELECT  'all'::text as table_name, 
            sum( (coalesce(heap_blks_read,0) + coalesce(idx_blks_read,0) + coalesce(toast_blks_read,0) + coalesce(tidx_blks_read,0)) ) as from_disk, 
            sum( (coalesce(heap_blks_hit,0)  + coalesce(idx_blks_hit,0)  + coalesce(toast_blks_hit,0)  + coalesce(tidx_blks_hit,0))  ) as from_cache    
        FROM    pg_statio_USER_tables -- pg_statio_all_tables  --> change to pg_statio_USER_tables if you want to check only user tables (excluding postgres's own tables)
        WHERE schemaname = 'public'
        ) a
    WHERE   (from_disk + from_cache) > 0 -- discard tables without hits
),
tables as 
(
    SELECT  *
    FROM    (
        SELECT  relname as table_name, 
            ( (coalesce(heap_blks_read,0) + coalesce(idx_blks_read,0) + coalesce(toast_blks_read,0) + coalesce(tidx_blks_read,0)) ) as from_disk, 
            ( (coalesce(heap_blks_hit,0)  + coalesce(idx_blks_hit,0)  + coalesce(toast_blks_hit,0)  + coalesce(tidx_blks_hit,0))  ) as from_cache    
        FROM    pg_statio_USER_tables -- pg_statio_all_tables --> change to pg_statio_USER_tables if you want to check only user tables (excluding postgres's own tables)
        WHERE schemaname = 'public'
        ) a
    WHERE   (from_disk + from_cache) > 0 -- discard tables without hits
)
SELECT  table_name as "table name",
    from_disk as "disk hits",
    round((from_disk::numeric / (from_disk + from_cache)::numeric)*100.0,2) as "% disk hits",
    round((from_cache::numeric / (from_disk + from_cache)::numeric)*100.0,2) as "% cache hits",
    (from_disk + from_cache) as "total hits"
FROM    (SELECT * FROM all_tables UNION ALL SELECT * FROM tables) a
ORDER   BY (case when table_name = 'all' then 0 else 1 end), from_disk desc
;


-- =============================================
-- OBJECT DEPENDENCY   
-- =============================================

-- Ref: 
-- https://www.postgresql.org/docs/9.1/static/catalog-pg-depend.html 
-- https://wiki.postgresql.org/wiki/Pg_depend_display

# Get list of Dependant Objects (Without list of columns but with aggregated number of columns that are used):

SELECT dependent_ns.nspname  AS dependent_schema,
       dependent_view.relname  AS dependent_view,
       source_ns.nspname   AS source_schema,
       source_table.relname  AS source_table,
       COUNT(pg_attribute.attname) AS Num_of_dependent_cols
       FROM pg_depend
  JOIN pg_rewrite
  JOIN pg_class AS dependent_view
dependent_view.oid
  JOIN pg_class AS source_table
source_table.oid
  JOIN pg_attribute
pg_attribute.attrelid  AND pg_depend.refobjsubid = pg_attribute.attnum)
  JOIN pg_namespace dependent_ns    ON dependent_ns.oid =
dependent_view.relnamespace
  JOIN pg_namespace source_ns       ON source_ns.oid =
source_table.relnamespace
WHERE source_ns.nspname = 'sor_cc_pi'
AND   dependent_ns.nspname <> 'iagdev' /* Exclude this Test Schema */
AND   source_table.relname = 'abx_di_managedarea'
AND   pg_attribute.attnum > 0
--AND pg_attribute.attname = 'my_column'
GROUP BY dependent_ns.nspname,
         dependent_view.relname,
         source_ns.nspname,
         source_table.relname
ORDER BY 1, 2;


# Get list of Dependant Objects (With list of columns):

SELECT dependent_ns.nspname  AS dependent_schema,
       dependent_view.relname  AS dependent_view,
       source_ns.nspname   AS source_schema,
       source_table.relname  AS source_table,
       pg_attribute.attname  AS column_name
FROM pg_depend
  JOIN pg_rewrite      ON pg_depend.objid = pg_rewrite.oid
  JOIN pg_class AS dependent_view  ON pg_rewrite.ev_class =
dependent_view.oid
  JOIN pg_class AS source_table  ON pg_depend.refobjid =
source_table.oid
  JOIN pg_attribute ON (pg_depend.refobjid = pg_attribute.attrelid AND
pg_depend.refobjsubid = pg_attribute.attnum)
  JOIN pg_namespace dependent_ns  ON dependent_ns.oid =
dependent_view.relnamespace
  JOIN pg_namespace source_ns   ON source_ns.oid =
source_table.relnamespace
WHERE source_ns.nspname = 'sor_cc_pi'
AND   source_table.relname = 'abx_di_managedarea'
AND   pg_attribute.attnum > 0
--AND pg_attribute.attname = 'my_column'
ORDER BY 1, 2;


-- ========================================
-- Get Table STAT 
-- ========================================

WITH vars (schemaname, tablename) as (
    VALUES ('public', null)
), 
cte_pg_stat as (
    SELECT relname
        , seq_scan      /* Number of sequential scans initiated on this table */ 
        , seq_tup_read  /* Number of live rows fetched by sequential scans */ 
        , idx_scan      /* Number of index scans initiated on this table */ 
        , idx_tup_fetch /* Number of live rows fetched by index scans */ 
        , n_tup_ins     /* Number of rows inserted */
        , n_tup_upd     /* Number of rows updated (includes HOT updated rows) */
        , n_tup_del     /* Number of rows deleted */
        , n_tup_hot_upd /* Number of rows HOT updated (i.e., WITH no separate index update required) */
        , n_live_tup    /* Estimated number of live rows */
        , n_dead_tup    /* Estimated number of dead rows */
        , n_mod_since_analyze /* Estimated number of rows modified since this table was last analyzed */ 
        -- , n_ins_since_vacuum /* Estimated number of rows inserted since this table was last vacuumed (not in postgres 12 )*/
        , last_vacuum       /* Last time at which this table was manually vacuumed (not counting VACUUM FULL) */
        , last_autovacuum   /* Last time at which this table was vacuumed by the autovacuum daemon */
        , last_analyze      /* Last time at which this table was manually analyzed */
        , last_autoanalyze /* Last time at which this table was analyzed by the autovacuum daemon */ 
    FROM pg_stat_all_tables as psat, vars 
    WHERE psat.schemaname = vars.schemaname
),
cte_tbl as (
    SELECT table_name
        , pg_table_size(quote_ident(table_name)) as diskspace_excl_idx /* Disk space used by the specified table, excluding indexes (but including TOAST, free space map, and visibility map) */ 
        , pg_total_relation_size(quote_ident(table_name)) as diskspace_incl_idx /* Total disk space used by the specified table, including all indexes and TOAST data */
        , pg_relation_size(quote_ident(table_name)) as relation_size /* Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index */ 

    FROM information_schema.tables, vars 
    WHERE table_schema = vars.schemaname
)
SELECT 
    ct.table_name
    , pg_size_pretty(ct.diskspace_excl_idx) as diskspace_excl_idx
    , pg_size_pretty(ct.diskspace_incl_idx) as diskspace_incl_idx
    , pg_size_pretty(ct.relation_size) as relation_size
    , cps.*
FROM cte_tbl as ct LEFT JOIN cte_pg_stat as cps ON  ct.table_name = cps.relname
ORDER BY ct.relation_size desc
;

-- ========================================
-- BLOAT ESTIMATION 
-- ========================================

-- https://github.com/ioguix/pgsql-bloat-estimation

/* WARNING: executed with a non-superuser role, the query inspect only tables and materialized view (9.3+) you are granted to read.
* This query is compatible with PostgreSQL 9.0 and more
*/
SELECT current_database(), schemaname, tblname, bs*tblpages AS real_size,
  (tblpages-est_tblpages)*bs AS extra_size,
  CASE WHEN tblpages > 0 AND tblpages - est_tblpages > 0
    THEN 100 * (tblpages - est_tblpages)/tblpages::float
    ELSE 0
  END AS extra_pct, fillfactor,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN (tblpages-est_tblpages_ff)*bs
    ELSE 0
  END AS bloat_size,
  CASE WHEN tblpages > 0 AND tblpages - est_tblpages_ff > 0
    THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float
    ELSE 0
  END AS bloat_pct, is_na
  -- , tpl_hdr_size, tpl_data_size, (pst).free_percent + (pst).dead_tuple_percent AS real_frag -- (DEBUG INFO)
FROM (
  SELECT ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
    ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
    tblpages, fillfactor, bs, tblid, schemaname, tblname, heappages, toastpages, is_na
    -- , tpl_hdr_size, tpl_data_size, pgstattuple(tblid) AS pst -- (DEBUG INFO)
  FROM (
    SELECT
      ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
        - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
        - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
      ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
      toastpages, reltuples, toasttuples, bs, page_hdr, tblid, schemaname, tblname, fillfactor, is_na
      -- , tpl_hdr_size, tpl_data_size
    FROM (
      SELECT
        tbl.oid AS tblid, ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
        tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
        coalesce(toast.reltuples, 0) AS toasttuples,
        coalesce(substring(
          array_to_string(tbl.reloptions, ' ')
          FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
        current_setting('block_size')::numeric AS bs,
        CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
        24 AS page_hdr,
        23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
           + CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END AS tpl_hdr_size,
        sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size,
        bool_or(att.atttypid = 'pg_catalog.name'::regtype)
          OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
      FROM pg_attribute AS att
        JOIN pg_class AS tbl ON att.attrelid = tbl.oid
        JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
        LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
          AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
        LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
      WHERE NOT att.attisdropped
        AND tbl.relkind in ('r','m')
      GROUP BY 1,2,3,4,5,6,7,8,9,10
      ORDER BY 2,3
    ) AS s
  ) AS s2
) AS s3
-- WHERE NOT is_na
--   AND tblpages*((pst).free_percent + (pst).dead_tuple_percent)::float4/100 >= 1
ORDER BY schemaname, tblname;
