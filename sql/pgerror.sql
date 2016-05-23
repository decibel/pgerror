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

-- vi: expandtab ts=2 sw=2
