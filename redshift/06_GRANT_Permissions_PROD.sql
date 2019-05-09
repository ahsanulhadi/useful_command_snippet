/*

-- DONE -----------------
CREATE GROUP admin;
CREATE GROUP dbuser;
CREATE GROUP application;
CREATE GROUP reporting;

select * from pg_group;  -- Check the created groups.
select * from pg_user; --  Check the created Users.
*/

-- Create an Admin User to monitor. 
CREATE USER ahsanulh with password 'Ahsanulh123' in group admin;


/* Notes: 
(1) PUBLIC (group): Grants the specified privileges to all users, including users created later. PUBLIC represents a group that always includes all users. An individual user's privileges consist of the sum of privileges granted to PUBLIC, privileges granted to any groups that the user belongs to, and any privileges granted to the user individually.
*/
-- Total groups: reporting, application, dbuser, admin

-- ===================== for PUBLIC (ALL users) =================================================
GRANT ALL ON ALL TABLES IN SCHEMA public  TO PUBLIC; -- included: reporting, application,dbuser; | --  SELECT | INSERT | UPDATE | DELETE | REFERENCES 

/* Note: CREATE allows users to create objects within a schema. To rename an object, the user must have the CREATE privilege and own the object to be renamed.
Grants USAGE privilege on a specific schema, which makes objects in that schema accessible to users. By default, all users have CREATE and USAGE privileges on the PUBLIC schema. */
GRANT ALL ON SCHEMA public TO PUBLIC;   -- { CREATE | USAGE }

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC; -- [ FUNCTION ] function_name

-- The USAGE ON LANGUAGE privilege is required to create UDFs by executing the CREATE FUNCTION command. UDFs and libraries are implemented in the Python language, so language_name must be plpythonu.
GRANT USAGE ON LANGUAGE plpythonu TO PUBLIC;

-- ===================== Group: Admin =====================================================
GRANT ALL ON ALL TABLES IN SCHEMA information_schema,pg_catalog,pg_internal,public,staging,model TO GROUP admin;  --  SELECT | INSERT | UPDATE | DELETE | REFERENCES 

-- CREATE (For databases) allows users to create schemas within the database. 
-- TEMP: By default, users are granted permission to create temporary tables by their automatic membership in the PUBLIC group.
GRANT ALL ON DATABASE ticketekau TO GROUP admin; -- { { CREATE | TEMPORARY | TEMP } --  ONLY FOR ADMIN group. 

GRANT ALL ON SCHEMA public,staging,model TO GROUP admin; -- { CREATE | USAGE }
GRANT USAGE ON SCHEMA information_schema,pg_catalog,pg_internal TO GROUP admin; -- { CREATE | USAGE }

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA information_schema,pg_catalog,pg_internal,public,staging,model TO GROUP admin;
GRANT USAGE ON LANGUAGE plpythonu TO GROUP admin;

-- ===================== Group: Reporting =================================================
GRANT ALL ON ALL TABLES IN SCHEMA public  TO GROUP reporting; -- explicitly mentioning.   --  SELECT | INSERT | UPDATE | DELETE | REFERENCES 
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema,pg_catalog,pg_internal,staging,model TO GROUP reporting; -- only SELECT 

GRANT ALL ON SCHEMA public TO GROUP reporting; -- { CREATE | USAGE }
GRANT USAGE ON SCHEMA information_schema,pg_catalog,pg_internal,staging,model TO GROUP reporting; -- No need to create objects in these schemas. Only use.

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA information_schema,pg_catalog,pg_internal,public,staging,model TO GROUP reporting;
GRANT USAGE ON LANGUAGE plpythonu TO GROUP reporting;

