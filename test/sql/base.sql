\set ECHO none

\i test/pgxntool/setup.sql

CREATE TEMP TABLE good(
  seq serial
  , code text
  , description text
  , _row_count int
);
INSERT INTO good(code, description, _row_count) VALUES
  ('INSERT INTO test SELECT generate_series(1,42)', 'INSERT', 42)
  , ('SELECT count(*) FROM test', 'SELECT', 1)
  , ('SELECT * FROM test', 'SELECT', 42)
  , ('UPDATE test SET i = -i WHERE i <= 10', 'UPDATE 10 rows', 10)
  , ('UPDATE test SET i = -i WHERE i = 0', 'UPDATE no rows', 0)
;

CREATE TEMP TABLE bad(
  code text
  , description text
  , sqlstate          text
  , message           text
  , hint              text
  , detail            text
  , context           text
  , schema_name       text
  , table_name        text
  , column_name       text
  , constraint_name   text
  , type_name         text
);
INSERT INTO bad VALUES
  ('bogus', 'syntax error'
    , '42601'
    , 'syntax error at or near "bogus"'
    , ''
    , ''
    , 'PL/pgSQL function try(text) line 3 at EXECUTE statement'
    , ''
    , ''
    , ''
    , ''
    , ''
  )
;

SELECT plan(
  2 * (SELECT count(*)::int FROM good)
  + 11 * (SELECT count(*)::int FROM bad)
);

-- TODO: test other return values
SELECT is(
      row_count
      , NULL
      , description || ' check value of row_count'
    )
    || E'\n' || is((error).sqlstate, bad.sqlstate, description || ' check sqlstate')
    || E'\n' || is((error).message, bad.message, description || ' check message')
    || E'\n' || is((error).hint, bad.hint, description || ' check hint')
    || E'\n' || is((error).detail, bad.detail, description || ' check detail')
    || E'\n' || is((error).context, bad.context, description || ' check context')
    || E'\n' || is((error).schema_name, bad.schema_name, description || ' check schema_name')
    || E'\n' || is((error).table_name, bad.table_name, description || ' check table_name')
    || E'\n' || is((error).column_name, bad.column_name, description || ' check column_name')
    || E'\n' || is((error).constraint_name, bad.constraint_name, description || ' check constraint_name')
    || E'\n' || is((error).type_name, bad.type_name, description || ' check type_name')
  FROM bad, try(code)
;

CREATE TEMP TABLE test(
  i int
);

SELECT  is(
      row_count
      , _row_count
      , description || ' check value of row_count'
    )
    || E'\n' || is(
      error
      , NULL
      , description || ' error is null'
    )
  FROM good, try(code)
  ORDER BY seq
;

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
