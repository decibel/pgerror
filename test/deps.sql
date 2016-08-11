-- Note: pgTap is loaded by setup.sql

-- Assume that if things work in a specific schema that they'll work outside that schema
CREATE SCHEMA error_schema;
CREATE EXTENSION pgerror WITH SCHEMA error_schema;

-- Add any test dependency statements here

