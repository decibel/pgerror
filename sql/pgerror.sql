CREATE TYPE error_data AS(
  sqlstate            text
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
CREATE FUNCTION error_data(
  sqlstate            text = ''
  , message           text = ''
  , hint              text = ''
  , detail            text = ''
  , context           text = ''
  , schema_name       text = ''
  , table_name        text = ''
  , column_name       text = ''
  , constraint_name   text = ''
  , type_name         text = ''
) RETURNS error_data LANGUAGE sql IMMUTABLE AS $$
SELECT row(
  sqlstate
  , message
  , hint
  , detail
  , context
  , schema_name
  , table_name
  , column_name
  , constraint_name
  , type_name
)::error_data
$$;

-- Note that context is intentionally ommitted
CREATE OR REPLACE FUNCTION raise(
  message             text
  , level             text = 'EXCEPTION'
  , sqlstate          text = NULL
  , hint              text = NULL
  , detail            text = NULL
  , schema_name       text = NULL
  , table_name        text = NULL
  , column_name       text = NULL
  , constraint_name   text = NULL
  , type_name         text = NULL
) RETURNS void LANGUAGE plpgsql AS $body$
DECLARE
  -- Default to the same thing plpgsql RAISE without a SQLSTATE does
  c_sqlstate CONSTANT text := coalesce(nullif(sqlstate,''), 'P0001');
/*
  c_message CONSTANT text := coalesce(message, '<NULL>');
  c_hint CONSTANT text := coalesce(hint, '<NULL>');
  c_detail CONSTANT text := coalesce(detail, '<NULL>');
  c_schema_name CONSTANT text := coalesce(schema_name, '<NULL>');
  c_table_name CONSTANT text := coalesce(table_name, '<NULL>');
  c_column_name CONSTANT text := coalesce(column_name, '<NULL>');
  c_constraint CONSTANT text := coalesce(constraint, '<NULL>');
  c_datatype CONSTANT text := coalesce(datatype, '<NULL>');
*/
  sql text;
  conds text[];
BEGIN
  sql = $sql$CREATE OR REPLACE FUNCTION pg_temp.raise_error_internal() RETURNS void LANGUAGE plpgsql AS $raise_function$
BEGIN
  RAISE $sql$ || level;
  IF sqlstate IS NOT NULL THEN
    sql := sql || format(' SQLSTATE %L', sqlstate);
  END IF;

  IF nullif(message, '') IS NOT NULL THEN
    conds := conds || array[format('MESSAGE = %L', message)];
  END IF;
  IF nullif(hint, '') IS NOT NULL THEN
    conds := conds || array[format('HINT = %L', hint)];
  END IF;
  IF nullif(detail, '') IS NOT NULL THEN
    conds := conds || array[format('DETAIL = %L', detail)];
  END IF;
  IF nullif(schema_name, '') IS NOT NULL THEN
    conds := conds || array[format('SCHEMA = %L', schema_name)];
  END IF;
  IF nullif(table_name, '') IS NOT NULL THEN
    conds := conds || array[format('TABLE = %L', table_name)];
  END IF;
  IF nullif(column_name, '') IS NOT NULL THEN
    conds := conds || array[format('COLUMN = %L', column_name)];
  END IF;
  IF nullif(constraint_name, '') IS NOT NULL THEN
    conds := conds || array[format('CONSTRAINT = %L', constraint_name)];
  END IF;
  IF nullif(type_name, '') IS NOT NULL THEN
    conds := conds || array[format('DATATYPE = %L', type_name)];
  END IF;

  IF conds IS NOT NULL THEN
    sql := sql || E'\n    USING\n' || array_to_string(conds, E'\n    , ');
  END IF;
  sql := sql || $$
  ;
END$raise_function$;$$;
  EXECUTE sql;
  -- Wrap the call in a handler to remove the temp function from the context stack
  BEGIN
    PERFORM pg_temp.raise_error_internal();
  EXCEPTION WHEN OTHERS
      OR QUERY_CANCELED
      -- 9.5+ only OR ASSERT_FAILURE
      THEN
    RAISE;
  END;
END
$body$;
CREATE OR REPLACE FUNCTION raise(
  error               error_data
  , level             text = 'EXCEPTION'
) RETURNS void LANGUAGE sql AS $$
SELECT raise(
  error.message
  , level
  , error.sqlstate
  , error.hint
  , error.detail
  , error.schema_name
  , error.table_name
  , error.column_name
  , error.constraint_name
  , error.type_name
);
$$;

CREATE OR REPLACE FUNCTION try(
  code text
  , OUT row_count int
  , OUT error error_data
) RETURNS record LANGUAGE plpgsql AS $body$
BEGIN
  EXECUTE code;
  -- NOTE: FOUND dosent' work with EXECUTE
  GET DIAGNOSTICS try.row_count = ROW_COUNT;
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS
    error.sqlstate = RETURNED_SQLSTATE
    , error.message = MESSAGE_TEXT
    , error.detail = PG_EXCEPTION_DETAIL
    , error.hint = PG_EXCEPTION_HINT
    , error.context = PG_EXCEPTION_CONTEXT
    , error.column_name = COLUMN_NAME
    , error.constraint_name = CONSTRAINT_NAME
    , error.type_name = PG_DATATYPE_NAME
    , error.table_name = TABLE_NAME
    , error.schema_name = SCHEMA_NAME
  ;
END
$body$;

CREATE OR REPLACE FUNCTION try_cursor(
  query text
  , cursor_name text DEFAULT NULL
  , OUT result refcursor
  , OUT error error_data
) RETURNS record LANGUAGE plpgsql AS $body$
BEGIN
  IF cursor_name IS NOT NULL THEN
    result := cursor_name;
  END IF;
  OPEN result FOR EXECUTE query;
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS
    error.sqlstate = RETURNED_SQLSTATE
    , error.message = MESSAGE_TEXT
    , error.detail = PG_EXCEPTION_DETAIL
    , error.hint = PG_EXCEPTION_HINT
    , error.context = PG_EXCEPTION_CONTEXT
    , error.column_name = COLUMN_NAME
    , error.constraint_name = CONSTRAINT_NAME
    , error.type_name = PG_DATATYPE_NAME
    , error.table_name = TABLE_NAME
    , error.schema_name = SCHEMA_NAME
  ;
END
$body$;

CREATE OR REPLACE FUNCTION try_into(
  code text
  , INOUT result anyelement
  , strict boolean DEFAULT false
  , OUT error error_data
) RETURNS record LANGUAGE plpgsql AS $body$
BEGIN
  IF strict IS TRUE THEN
    EXECUTE code INTO STRICT result;
  ELSE
    EXECUTE code INTO result;
  END IF;
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS
    error.sqlstate = RETURNED_SQLSTATE
    , error.message = MESSAGE_TEXT
    , error.detail = PG_EXCEPTION_DETAIL
    , error.hint = PG_EXCEPTION_HINT
    , error.context = PG_EXCEPTION_CONTEXT
    , error.column_name = COLUMN_NAME
    , error.constraint_name = CONSTRAINT_NAME
    , error.type_name = PG_DATATYPE_NAME
    , error.table_name = TABLE_NAME
    , error.schema_name = SCHEMA_NAME
  ;
END
$body$;

-- vi: expandtab ts=2 sw=2
