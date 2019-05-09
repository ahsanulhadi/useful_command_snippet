-- Generate all VIEWS. 

SELECT 
-- n.nspname AS schemaname,
-- c.relname AS viewname,
	'\n' + '--DROP VIEW ' + n.nspname + '.' + c.relname + ';\n\nCREATE OR REPLACE VIEW ' + n.nspname + '.' + c.relname + ' AS\n' + COALESCE(pg_get_viewdef(c.oid, TRUE), '') AS ddl
FROM 
	pg_catalog.pg_class AS c
INNER JOIN
	pg_catalog.pg_namespace AS n
		ON c.relnamespace = n.oid
WHERE relkind = 'v'
AND n.nspname in ('model','staging');