-- =================================
-- Tools:
-- =================================

Plan visualise - http://tatiyants.com/pev/#/plans/new
Log analse tool - https://github.com/darold/pgbadger
Check diff with pg tune - https://pgtune.leopard.in.ua/#/
Explain plan visualiser: https://explain.dalibo.com/
DB monitoring tool: https://pgcluu.darold.net/

https://pganalyze.com/



-- =================================
-- Links, Tutorials:
-- =================================

-- DBA Scripts 
https://github.com/Azmodey/pg_dba_scripts
https://www.dbrnd.com/postgresql-dba-scripts/
https://www.percona.com/blog/2020/03/31/useful-queries-for-postgresql-index-maintenance/
https://www.compose.com/articles/simple-index-checking-for-postgres/
https://gist.github.com/marr75/6b1f87a3856b607b4893

-- Cache Hit Ratio
https://gist.github.com/mattsoldo/3853455
https://stackoverflow.com/questions/46529023/postgresql-performance-index-page-hits
https://www.craigkerstiens.com/2012/10/01/understanding-postgres-performance/#:~:text=You%20can%20find%20your%20cache,for%20Heroku%20Postgres%20is%2099.99%25.

-- Index fragmantention/ Bloat: 
https://dba.stackexchange.com/questions/273556/how-do-we-select-fragmented-indexes-from-postgresql
https://stackoverflow.com/questions/52444912/how-to-find-out-fragmented-indexes-and-defragment-them-in-postgresql
https://medium.com/compass-true-north/dealing-with-significant-postgres-database-bloat-what-are-your-options-a6c1814a03a5


-- Optimization WHERE IN clause has too many values 
https://stackoverflow.com/questions/64785993/postgresql-in-clause-optimization-for-more-than-3000-values
https://dba.stackexchange.com/questions/232887/where-in-query-to-very-large-table-is-slow
https://dba.stackexchange.com/questions/91247/optimizing-a-postgres-query-with-a-large-in
https://stackoverflow.com/questions/64785993/postgresql-in-clause-optimization-for-more-than-3000-values
https://www.datadoghq.com/blog/100x-faster-postgres-performance-by-changing-1-line/


-- Explain Plan
https://www.pgmustard.com/docs/explain * *
https://thoughtbot.com/blog/reading-an-explain-analyze-query-plan


-- Get all SQL Statement history
https://www.postgresql.org/docs/12/pgstatstatements.html

-- Find / Stop Running queries: 
https://adamj.eu/tech/2022/06/20/how-to-find-and-stop-running-queries-on-postgresql/

-- Vacuum / analyse / reindex: 
https://confluence.atlassian.com/kb/optimize-and-improve-postgresql-performance-with-vacuum-analyze-and-reindex-885239781.html

-- Performance 
https://www.postgresql.org/docs/12/performance-tips.html  * * *

-- QUERY PLANNING:
https://www.postgresql.org/docs/12/runtime-config-query.html
https://heap.io/blog/when-the-postgres-planner-is-not-very-smart


-- PLANNER STAT:
https://www.postgresql.org/docs/12/planner-stats.html

-- TUNING POSTGRES SERVER: 
https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server

-- LIKE query optimize
https://dba.stackexchange.com/questions/53811/why-would-you-index-text-pattern-ops-on-a-text-column
https://dba.stackexchange.com/questions/172880/index-with-ops-for-like-and-queries
https://www.postgresql.org/docs/12/indexes-opclass.html

-- TUNE AUTOVACUUM
https://www.percona.com/blog/2018/08/10/tuning-autovacuum-in-postgresql-and-autovacuum-internals/
https://www.postgresql.org/docs/current/runtime-config-autovacuum.html
https://dba.stackexchange.com/questions/232119/postgres-autovacuum-on-several-big-tables
https://dba.stackexchange.com/questions/176644/postgresql-does-autovacuum-impact-query-performance-does-it-apply-locks-which
https://dba.stackexchange.com/questions/48909/how-to-make-postgres-autovacuum-not-impact-performance * 
https://stackoverflow.com/questions/54831212/postgresql-autovacuum-causing-significant-performance-degradation#:~:text=Storage%20usage%20increases%20by%20~1GB,near%20zero%20to%20~50%2Fsecond
https://www.postgresql.org/docs/12/runtime-config-autovacuum.html * 

-- Understanding Cache
https://madusudanan.com/blog/understanding-postgres-caching-in-depth/

-- SHARED BUFFER
https://www.postgresql.org/docs/current/runtime-config-resource.html#GUC-SHARED-BUFFERS


-- =================================
-- Links, Tutorials: Misc 
-- =================================

http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.html 
http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#d0e99805 
http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html#CHAP_BestPractices.PostgreSQL * * * 
https://www.postgresql.org/docs/current/static/routine-vacuuming.html#AUTOVACUUM 
http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_LogAccess.Concepts.PostgreSQL.html 
http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html * * * 
http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Procedural.Importing.html * * * * 
http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html 
https://www.postgresql.org/docs/9.1/static/functions-info.html * * *

Index:
https://www.compose.com/articles/indexing-for-full-text-search-in-postgresql/ 
http://rachbelaid.com/postgres-full-text-search-is-good-enough/ 
https://blog.lateral.io/2015/05/full-text-search-in-milliseconds-with-postgresql/ 
https://blog.codeship.com/unleash-the-power-of-storing-json-in-postgres/

Table Inheritence:
http://stackoverflow.com/questions/3074535/when-to-use-inherited-tables-in-postgresql

Queue Depth:
http://searchsolidstatestorage.techtarget.com/definition/queue-depth

Authentication:
http://stackoverflow.com/questions/4328679/how-to-configure-postgresql-so-it-accepts-loginpassword-auth 
http://www.postgresql.org/docs/9.1/static/auth-methods.html

Sql Tricks:
http://postgres.cz/wiki/PostgreSQL_SQL_Tricks