\set ECHO none

\i test/pgxntool/setup.sql

CREATE TEMP VIEW named_cursors AS SELECT * FROM pg_cursors WHERE name NOT LIKE '<unnamed portal %>';

CREATE TEMP TABLE test_table(
  s serial
  , i int
  , t text
);
INSERT INTO test_table(i,t) SELECT ser, ser::text FROM generate_series(10,1,-1) ser;

CREATE TEMP TABLE good(
  seq serial
  , code text
  , description text
);
INSERT INTO good(code, description) VALUES
  ('SELECT * FROM test_table ORDER BY i', 'ORDER BY i')
  , ('SELECT * FROM test_table ORDER BY s', 'ORDER BY s')
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
    , 'PL/pgSQL function try_cursor(text,text) line 6 at OPEN'
    , ''
    , ''
    , ''
    , ''
    , ''
  )
  -- TODO: Replace this with a function that raises specific items in the fields
  , ('SELECT * FROM pg_temp.non_existent_table', 'non existent table'
    , '42P01'
    , 'relation "pg_temp.non_existent_table" does not exist'
    , ''
    , ''
    , 'PL/pgSQL function try_cursor(text,text) line 6 at OPEN'
    , ''
    , ''
    , ''
    , ''
    , ''
  )
;

SELECT plan(
  0
  + 1 -- Verify no named cursors
  -- Unnamed bad
  + 11 * (SELECT count(*)::int FROM bad)
  -- Unnamed good
  + 2 * (SELECT count(*)::int FROM good)
  -- Named bad
  + 1 + 11 * (SELECT count(*)::int FROM bad)
  -- Named good
  + 1 + 2 * (SELECT count(*)::int FROM good)
);

SELECT is_empty(
  $$SELECT * FROM named_cursors$$
  , 'Verify there are no named cursors'
);


-- TODO: test other return values
SELECT ok(
      result IS NULL
      , description || ' result is NULL'
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
  FROM bad, try_cursor(code)
;

/*
 * Unnamed good
 */
SELECT results_eq(
      result
      , code
      , description || ' check results'
    )
    || E'\n' || is(
      error
      , NULL
      , description || ' error is null'
    )
  FROM good, try_cursor(code)
  ORDER BY seq
;

/*
 * Named bad
 */
SELECT ok(
      result IS NOT NULL
      , 'cursor named ' || description || ' result is NOT NULL'
    )
    || E'\n' || is((error).sqlstate, bad.sqlstate, 'cursor named ' || description || ' check sqlstate')
    || E'\n' || is((error).message, bad.message, 'cursor named ' || description || ' check message')
    || E'\n' || is((error).hint, bad.hint, 'cursor named ' || description || ' check hint')
    || E'\n' || is((error).detail, bad.detail, 'cursor named ' || description || ' check detail')
    || E'\n' || is((error).context, bad.context, 'cursor named ' || description || ' check context')
    || E'\n' || is((error).schema_name, bad.schema_name, 'cursor named ' || description || ' check schema_name')
    || E'\n' || is((error).table_name, bad.table_name, 'cursor named ' || description || ' check table_name')
    || E'\n' || is((error).column_name, bad.column_name, 'cursor named ' || description || ' check column_name')
    || E'\n' || is((error).constraint_name, bad.constraint_name, 'cursor named ' || description || ' check constraint_name')
    || E'\n' || is((error).type_name, bad.type_name, 'cursor named ' || description || ' check type_name')
  FROM bad, try_cursor(code, description)
;

SELECT is_empty(
  $$SELECT * FROM named_cursors$$
  , 'Verify there are no named cursors'
);

/*
 * Named good
 */
SELECT is(
        (try_cursor(code, description)).error
        , NULL
        , 'Good named cursor returns NULL error result'
      )
  FROM good
  ORDER BY seq
;

SELECT set_eq(
  $$SELECT name, statement FROM named_cursors$$
  , $$SELECT description, code FROM good$$
  , 'Verify named cursors exist'
);

SELECT results_eq(
      description::refcursor -- Now the name of a named cursor
      , code
      , 'named cursor ' || description || ' check results'
    )
  FROM good
  ORDER BY seq
;

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
