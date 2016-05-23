\set ECHO none

\i test/pgxntool/psql.sql

BEGIN;
\i sql/pgerror.sql

\d error_data
\df try

\echo # TRANSACTION INTENTIONALLY LEFT OPEN!

-- vi: expandtab sw=2 ts=2
