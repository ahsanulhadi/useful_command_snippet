

-- =================================
-- PSQL commands:
-- =================================

-- Connect to Database:
$ psql -d DB_NAME -h localhost -U USER_NAME

-- Import data into table from a TSV file:
psql> COPY area FROM ‘/Users/ahsanul.hadi/Documents/Work/db/file_dir’ WITH DELIMITER E’\t’;
psql> COPY area FROM ‘/Users/ahsanul.hadi/Documents/Work/db/file_dir’ WITH DELIMITER E’\t’ NULL AS ;

-- Pass a sql command:
$ psql -d DB_NAME -h localhost -U USER_NAME -t -A -c "select count(1) from musicbrainz.area";

-- Run sql from a File. -W will prompt for a password.
$ psql -d DB_NAME -h localhost -U User_name -W -f /Users/ahsanul.hadi/Documents/Work/Database/my_queries.sql

-- Drop Database:
dropdb -h DB_HOST_NAME -U User_name -e -i <database_name>


-- Commands:
$ psql -l # List all databases and exits. $ psql --version # List the version
psql> \c -- DBNAME - USER - HOST -PORT    -- connects to another database.

\l+ # List of all databases.
\d # List of all tables, views .
\d+ <Table name>q # Describe Table.
SHOW search_path; # show current search_path or \g
SET search_path to "__schema_name__"; # Set new search_path.


\dt+ <Table name> # Show table details like: size, owner, type, comment
\d+  <table name> # Shows all column name, storage and column comments. 

\dt  # List of all tables.
\dn  # List of Schemas
\dv  # List of Views.

\di  # List of all Indexes. 
\dg  # List of Roles. / Users OR \du 
\dp  # List of Access Privileges.
\db  # List of Tablespaces 
\dz  # List of installed extensions.
\ds  # List of Sequences.
\df  # List of Functions.


\z  # Access privilege
\a  # Align output.
\f  # Field separator
\h  # Help


psql=> \connect nettwerk
psql=> \conninfo # Show current connection info. or \c
psql=> select version(); # Show version info.
psql=> select current_database(); # Show currently connected DB.



PGCLI:
-- for Ubuntu.
-- http://pgcli.com/install

$ which pip  # check whether exists or not ?
$ sudo su  # switch to Root user.
$ apt-get update # update package list.
$ apt-get install python-pip
$ apt-get install libpq-dev python-dev
$ pip install pgcli


# REGEX 
Use Regexp (Regular Expression):
https://www.postgresql.org/docs/9.3/static/functions-matching.html http://blog.lerner.co.il/regexps-in-postgresql/
-- example.

SELECT col_name,
       REGEXP_REPLACE(col_name,E '[\\n\\r\\u2028]+',' ','g') AS
col_name_new, --- replace 'new lines'
       counts,
       (SELECT COUNT(*) FROM REGEXP_MATCHES(col_name,'\|','g')) AS
num_of_bar-- then we need to find the 'BAR' separated values.
       FROM (SELECT UPPER(TRIM(col_name)) AS col_name,
                    COUNT(1) AS counts
             FROM public.table1
             WHERE col_name IS NOT NULL
             GROUP BY UPPER(TRIM(col_name))) AS t
ORDER BY col_name;


-- ==================================
-- BACKUP & RESTORE
-- ==================================


-- Take FULL BACKUP of source database.
$ pg_dump -h [host_name] -d [database_name] -U [user_name] -n
[schema_name] -C -c --if-exists --no-privileges --no-owner
--no-tablespaces > /Users/backup/Full_data_dump.sql
-- Drop the schema from the target database
$ psql -h [host_name] -d [database_name]  -U [user_name] -c 'DROP SCHEMA
[schema_name] CASCADE';
-- IMPORT the schema data in your target database.
$ PGOPTIONS='--client-min-messages=warning' psql -h [host_name] -d
[database_name]  -U [user_name] -v ON_ERROR_STOP=ON -X -q
--single-transaction -f /Users/backup/Full_data_dump.sql


-- Export in CSV format
SELECT '\COPY ' || tablename || ' TO ''/Users/backup/' || tablename ||
'.csv'' WITH (FORMAT CSV, HEADER);' as cmd
FROM pg_tables
WHERE schemaname = 'table_name'
ORDER BY tablename asc;
-- EXPORT Data for a schema and excluding the Metadata tables. Also
disable triggers.
pg_dump -h [host_name] -d [database_name] -U [user_name] -n
[schema_name] -T [table_name] -T [table_name] -a --disable-triggers
--no-privileges --no-owner > /Users/backup/data_only_export.sql
-- EXPORT Database structure for a schema Only.
pg_dump -h [host_name] -d [database_name] -U [user_name] -n
[schema_name] -C -c -s --if-exists  --no-privileges --no-owner
--no-tablespaces > /Users/backup/schema_only_export.sql


# Parallel pg_dump job:

$ time pg_dump -h [host_name] -d [database_name] -U [user_name] -w -n
[schema_name] -O -Fd -j 6 -f /Users/backup


-