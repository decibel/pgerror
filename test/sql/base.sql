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

CREATE TEMP TABLE test_bad(
  must_be_true boolean CHECK(must_be_true)
);
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
-- TODO: test using raise() to verify all values work
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
  , ('INSERT INTO test_bad VALUES(false)', 'CHECK constraint error'
    , '23514'
    , 'new row for relation "test_bad" violates check constraint "test_bad_must_be_true_check"'
    , ''
    , 'Failing row contains (f).'
    , E'SQL statement "INSERT INTO test_bad VALUES(false)"\nPL/pgSQL function try(text) line 3 at EXECUTE statement'
    , (SELECT nspname FROM pg_namespace WHERE oid = pg_my_temp_schema())
    , 'test_bad'
    , ''
    , 'test_bad_must_be_true_check'
    , ''
  )
;

SELECT plan(
  0
  + 2 -- try_into()
  + 4 -- error_data()
  + 1 -- simple raise
  + 2 * (SELECT count(*)::int FROM good)
  + 11 * (SELECT count(*)::int FROM bad)
);

SELECT is(
  (try_into('SELECT 1', 0::int)).result
  , 1
  , $$try_into('SELECT 1', 0::int)$$
);
SELECT is(
  (try_into('VALUES(1),(2)', NULL::int, strict := true)).error
  , error_data(
    'P0003'
    , 'query returned more than one row'
    , context := 'PL/pgSQL function try_into(text,anyelement,boolean) line 4 at EXECUTE statement'
  )
  , 'try_into() with strict = true'
);

SELECT is(
  error_data()
  , row(
    ''
    , ''
    , ''
    , ''
    , ''
    , ''
    , ''
    , ''
    , ''
    , ''
  )::error_data
  , 'Verify error_data() defaults'
);

SELECT is(
  error_data(
    sqlstate := 'sqlstate_1'
    , message := 'message_1'
    , hint := 'hint_1'
    , detail := 'detail_1'
    , context := 'context_1'
    , schema_name := 'schema_name_1'
    , table_name := 'table_name_1'
    , column_name := 'column_name_1'
    , constraint_name := 'constraint_name_1'
    , type_name := 'type_name_1'
  )
  , row(
    'sqlstate_1'
    , 'message_1'
    , 'hint_1'
    , 'detail_1'
    , 'context_1'
    , 'schema_name_1'
    , 'table_name_1'
    , 'column_name_1'
    , 'constraint_name_1'
    , 'type_name_1'
  )::error_data
  , 'Verify error_data()'
);
SELECT is(
  error_data(
    sqlstate := 'sqlstate_2'
    , message := 'message_2'
    , hint := 'hint_2'
    , detail := 'detail_2'
    , context := 'context_2'
    , schema_name := 'schema_name_2'
    , table_name := 'table_name_2'
    , column_name := 'column_name_2'
    , constraint_name := 'constraint_name_2'
    , type_name := 'type_name_2'
  )
  , row(
    'sqlstate_2'
    , 'message_2'
    , 'hint_2'
    , 'detail_2'
    , 'context_2'
    , 'schema_name_2'
    , 'table_name_2'
    , 'column_name_2'
    , 'constraint_name_2'
    , 'type_name_2'
  )::error_data
  , 'Verify error_data()'
);

SELECT throws_ok(
  $$SELECT raise(
    'message_1', 'EXCEPTION'
    , sqlstate := 'sqlstate_1'
    , hint := 'hint_1'
    , detail := 'detail_1'
    , schema_name := 'schema_name_1'
    , table_name := 'table_name_1'
    , column_name := 'column_name_1'
    , constraint_name := 'constraint_name_1'
    , type_name := 'type_name_1'
  )
  $$
  , '42601'
  , $$invalid SQLSTATE code at or near "'sqlstate_1'"$$
  , 'Check invalid sql state'
);

SELECT throws_ok(
  $$SELECT raise(
    'message_1', 'EXCEPTION'
    , hint := 'hint_1'
    , detail := 'detail_1'
    , schema_name := 'schema_name_1'
    , table_name := 'table_name_1'
    , column_name := 'column_name_1'
    , constraint_name := 'constraint_name_1'
    , type_name := 'type_name_1'
  )
  $$
  , 'P0001'
  , $$message_1$$
  , 'Check simple raise()'
);

-- TODO: full suite of raise() tests

SELECT is(
      row_count
      , NULL
      , description || ' check value of row_count'
    )
    || E'\n' || is((error).sqlstate, bad.sqlstate, description || ' check sqlstate')
    || E'\n' || is((error).message, bad.message, description || ' check message')
    || E'\n' || is((error).hint, bad.hint, description || ' check hint')
    || E'\n' || is((error).detail, bad.detail, description || ' check detail')
    || E'\n' || is('"' || (error).context || '"', '"' || bad.context || '"', description || ' check context')
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
