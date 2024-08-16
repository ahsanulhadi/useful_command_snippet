-- ===========================
-- LOCKS
-- ===========================

-- -------------
-- Method: 1
-- https://pitstop.manageengine.com/portal/en/kb/articles/how-to-find-the-mssql-lock-on-the-database-directly

/* open the query editor for target DB and exec the below. It will show the list of database query process which is currently in execution that causes the database table locks and the query which block the subsequent operation process can be identified by viewing the BlkBy (Blocked by)
*/

sp_who2

/*
And to identify the exact query which causes the locking, we need to execute dbcc inputbuffer (specify the query id identified in the BlkBy column).
*/
dbcc inputbuffer(blkBy)

-- -------------
-- Method: 2
-- Ref: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-locks-transact-sql?view=sql-server-2016&redirectedfrom=MSDN

/*
The following query displays lock information. The value for <dbid> should be replaced with the database_id from sys.databases
*/
SELECT resource_type, resource_associated_entity_id,
    request_status, request_mode,request_session_id,
    resource_description
FROM sys.dm_tran_locks
WHERE resource_database_id = <dbid>;

/*
The following query returns object information by using resource_associated_entity_id from the previous query. This query must be executed while you are connected to the database that contains the object.
*/
SELECT object_name(object_id), *
FROM sys.partitions
WHERE hobt_id=<resource_associated_entity_id> ;

/* The following query shows blocking information. */
SELECT
    t1.resource_type,
    t1.resource_database_id,
    t1.resource_associated_entity_id,
    t1.request_mode,
    t1.request_session_id,
    t2.blocking_session_id
FROM sys.dm_tran_locks as t1
INNER JOIN sys.dm_os_waiting_tasks as t2 ON t1.lock_owner_address = t2.resource_address;



-- -------------
-- Method: 3
-- Ref: https://stackoverflow.com/questions/694581/how-to-check-which-locks-are-held-on-a-table

-- List all Locks of the Current Database
SELECT TL.resource_type AS ResType
      ,TL.resource_description AS ResDescr
      ,TL.request_mode AS ReqMode
      ,TL.request_type AS ReqType
      ,TL.request_status AS ReqStatus
      ,TL.request_owner_type AS ReqOwnerType
      ,TAT.[name] AS TransName
      ,TAT.transaction_begin_time AS TransBegin
      ,DATEDIFF(ss, TAT.transaction_begin_time, GETDATE()) AS TransDura
      ,ES.session_id AS S_Id
      ,ES.login_name AS LoginName
      ,COALESCE(OBJ.name, PAROBJ.name) AS ObjectName
      ,PARIDX.name AS IndexName
      ,ES.host_name AS HostName
      ,ES.program_name AS ProgramName
FROM sys.dm_tran_locks AS TL
     INNER JOIN sys.dm_exec_sessions AS ES
         ON TL.request_session_id = ES.session_id
     LEFT JOIN sys.dm_tran_active_transactions AS TAT
         ON TL.request_owner_id = TAT.transaction_id
            AND TL.request_owner_type = 'TRANSACTION'
     LEFT JOIN sys.objects AS OBJ
         ON TL.resource_associated_entity_id = OBJ.object_id
            AND TL.resource_type = 'OBJECT'
     LEFT JOIN sys.partitions AS PAR
         ON TL.resource_associated_entity_id = PAR.hobt_id
            AND TL.resource_type IN ('PAGE', 'KEY', 'RID', 'HOBT')
     LEFT JOIN sys.objects AS PAROBJ
         ON PAR.object_id = PAROBJ.object_id
     LEFT JOIN sys.indexes AS PARIDX
         ON PAR.object_id = PARIDX.object_id
            AND PAR.index_id = PARIDX.index_id
WHERE TL.resource_database_id  = DB_ID()
      AND ES.session_id <> @@Spid -- Exclude "my" session
      -- optional filter
      AND TL.request_mode <> 'S' -- Exclude simple shared locks
ORDER BY TL.resource_type
        ,TL.request_mode
        ,TL.request_type
        ,TL.request_status
        ,ObjectName
        ,ES.login_name;



--TSQL commands
SELECT
       db_name(rsc_dbid) AS 'DATABASE_NAME',
       case rsc_type when 1 then 'null'
                             when 2 then 'DATABASE'
                             WHEN 3 THEN 'FILE'
                             WHEN 4 THEN 'INDEX'
                             WHEN 5 THEN 'TABLE'
                             WHEN 6 THEN 'PAGE'
                             WHEN 7 THEN 'KEY'
                             WHEN 8 THEN 'EXTEND'
                             WHEN 9 THEN 'RID ( ROW ID)'
                             WHEN 10 THEN 'APPLICATION' end  AS 'REQUEST_TYPE',

       CASE req_ownertype WHEN 1 THEN 'TRANSACTION'
                                     WHEN 2 THEN 'CURSOR'
                                     WHEN 3 THEN 'SESSION'
                                     WHEN 4 THEN 'ExSESSION' END AS 'REQUEST_OWNERTYPE',

       OBJECT_NAME(rsc_objid ,rsc_dbid) AS 'OBJECT_NAME',
       PROCESS.HOSTNAME ,
       PROCESS.program_name ,
       PROCESS.nt_domain ,
       PROCESS.nt_username ,
       PROCESS.program_name ,
       SQLTEXT.text
FROM sys.syslockinfo LOCK JOIN
     sys.sysprocesses PROCESS
  ON LOCK.req_spid = PROCESS.spid
CROSS APPLY sys.dm_exec_sql_text(PROCESS.SQL_HANDLE) SQLTEXT
where 1=1
and db_name(rsc_dbid) = db_name()



--Lock on a specific object
SELECT *
FROM sys.dm_tran_locks
WHERE resource_database_id = DB_ID()
AND resource_associated_entity_id = object_id('Specific Table');

-- Find Blockling Sql and Wait Sql

SELECT
    t1.resource_type ,
    DB_NAME( resource_database_id) AS dat_name ,
    t1.resource_associated_entity_id,
    t1.request_mode,
    t1.request_session_id,
    t2.wait_duration_ms,
    ( SELECT TEXT FROM sys.dm_exec_requests r CROSS apply sys.dm_exec_sql_text ( r.sql_handle ) WHERE r.session_id = t1.request_session_id ) AS wait_sql,
    t2.blocking_session_id,
    ( SELECT TEXT FROM sys.sysprocesses p CROSS apply sys.dm_exec_sql_text ( p.sql_handle ) WHERE p.spid = t2.blocking_session_id ) AS blocking_sql
FROM
    sys.dm_tran_locks t1,
    sys.dm_os_waiting_tasks t2
WHERE
    t1.lock_owner_address = t2.resource_address

-- ===========================
-- INDEX
-- ===========================

/*
Set the thresholds for a rebuild/reorganise
(say over 50% fragmentation for a reorganise, over 80% for a rebuild)
If you want to automate then here is a Script:
https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html
*/


-- Find Index Fragmentation status using the T-SQL statement
-- Ref: https://www.sqlshack.com/how-to-identify-and-resolve-sql-server-index-fragmentation/

SELECT S.name as 'Schema',
		T.name as 'Table',
		I.name as 'Index',
		DDIPS.avg_fragmentation_in_percent,
		DDIPS.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS DDIPS
INNER JOIN sys.tables T ON T.object_id = DDIPS.object_id
INNER JOIN sys.schemas S ON T.schema_id = S.schema_id
INNER JOIN sys.indexes I ON I.object_id = DDIPS.object_id AND DDIPS.index_id = I.index_id
WHERE DDIPS.database_id = DB_ID()
	AND I.name is not null
	AND DDIPS.avg_fragmentation_in_percent > 0
ORDER BY DDIPS.avg_fragmentation_in_percent desc;

/* If Fragmentation % is very high then we will have to Rebuild the Index.
Before rebuilding the index, let’s take the current allotment of pages for the index of the your database, table and  index.

SELECT
	OBJECT_NAME(IX.object_id) as db_name,
	si.name,
	extent_page_id,
	allocated_page_page_id,
	previous_page_page_id,
	next_page_page_id
FROM sys.dm_db_database_page_allocations(DB_ID('DatabaseName'),
	 OBJECT_ID('dbo.TableName'),NULL, NULL, 'DETAILED') IX
INNER JOIN sys.indexes si ON IX.object_id = si.object_id AND IX.index_id = si.index_id
WHERE si.name = 'YourIndexName'
ORDER BY allocated_page_page_id