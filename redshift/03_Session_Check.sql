-- Session list IP wise 

SELECT 
	i.remotehost
	,i.username
	,i.eventcount AS connects
	,d.eventcount AS disconnects
FROM 
	( 
	SELECT 
		remotehost
		,username
		,COUNT(*) AS eventcount
	FROM 
		stl_connection_log
     WHERE event = 'initiating session'
	GROUP BY remotehost, username
	) AS i
LEFT OUTER JOIN 
	( 
	SELECT 
		remotehost
		,username
		,COUNT(*) AS eventcount
	FROM 
		stl_connection_log
	WHERE event = 'disconnecting session'
     GROUP BY remotehost, username
     ) AS d 
     	ON i.remotehost = d.remotehost 
     	AND i.username = d.username
ORDER BY i.eventcount - COALESCE(d.eventcount, 0) DESC;SELECT 
	i.remotehost
	,i.username
	,i.eventcount AS connects
	,d.eventcount AS disconnects
FROM 
	( 
	SELECT 
		remotehost
		,username
		,COUNT(*) AS eventcount
	FROM 
		stl_connection_log
     WHERE event = 'initiating session'
	GROUP BY remotehost, username
	) AS i
LEFT OUTER JOIN 
	( 
	SELECT 
		remotehost
		,username
		,COUNT(*) AS eventcount
	FROM 
		stl_connection_log
	WHERE event = 'disconnecting session'
     GROUP BY remotehost, username
     ) AS d 
     	ON i.remotehost = d.remotehost 
     	AND i.username = d.username
ORDER BY i.eventcount - COALESCE(d.eventcount, 0) DESC;

-- --------------------------------------------------------------

-- OPEN CONNECTION LIST 

SELECT
	CASE WHEN disc.recordtime IS NULL THEN 'Y' ELSE 'N' END AS connected
	,init.recordtime AS conn_recordtime
	,disc.recordtime AS disconn_recordtime
	,init.pid AS pid
	,init.remotehost
	,init.remoteport
	,init.username AS username
	,disc.duration AS conn_duration
FROM 
	(SELECT event, recordtime, remotehost, remoteport, pid, username FROM stl_connection_log WHERE event = 'initiating session') AS init
LEFT OUTER JOIN
	(SELECT event, recordtime, remotehost, remoteport, pid, username, duration FROM stl_connection_log WHERE event = 'disconnecting session') AS disc
		ON init.pid = disc.pid
		AND init.remotehost = disc.remotehost
		AND init.remoteport = disc.remoteport
;

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

-- select pg_terminate_backend(1627);  *  *  * 


-- Check the Queries for those specific PID. 
select * 
from stl_query 
where pid in (29363,29160)
order by starttime; 

select *
from stv_recents 
where pid in (29363,29160);
