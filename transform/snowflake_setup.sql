-- ============================================================================
-- One-time (idempotent) Snowflake bootstrap for the albion_transform project.
-- Account: tojgonb-sf03144 (org tojgonb, account sf03144)
-- Run as a role that can create warehouses/databases/roles (e.g. SYSADMIN +
-- SECURITYADMIN, or ACCOUNTADMIN):
--   snowsql -a tojgonb-sf03144 -u <user> -f snowflake_setup.sql
-- Every statement is CREATE ... IF NOT EXISTS / OR REPLACE-free, so re-running
-- is safe and never destroys data.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Warehouse: smallest size, aggressive auto-suspend to keep cost near zero.
-- ---------------------------------------------------------------------------
create warehouse if not exists transform_wh
    warehouse_size = xsmall
    auto_suspend = 60
    auto_resume = true
    initially_suspended = true
    comment = 'dbt transform warehouse for albion-insurance-data-estate';

-- ---------------------------------------------------------------------------
-- Databases and schemas.
--   RAW.SOURCE       raw source-table seeds (data/01_source_tables)
--   GOLDEN.BASELINE  immutable "before" baselines (data/02_*, data/03_*)
--   GOLDEN.STAGING   rebuilt staging models   (sessions A/C/D)
--   GOLDEN.DOMAINS   domain models
--   GOLDEN.MARTS     analytics / data products (session B)
-- ---------------------------------------------------------------------------
create database if not exists raw
    comment = 'Raw source tables seeded from data/01_source_tables';
create schema if not exists raw.source;

create database if not exists golden
    comment = 'Golden baselines + rebuilt dbt models for parity validation';
create schema if not exists golden.baseline
    comment = 'Immutable before-migration baselines. Never rebuilt by models.';
create schema if not exists golden.staging;
create schema if not exists golden.domains;
create schema if not exists golden.marts;

-- ---------------------------------------------------------------------------
-- Role: TRANSFORMER — scoped grants only (no account-level privileges).
-- ---------------------------------------------------------------------------
create role if not exists transformer
    comment = 'dbt build role for the albion_transform project';

grant usage on warehouse transform_wh to role transformer;
grant operate on warehouse transform_wh to role transformer;

grant usage on database raw to role transformer;
grant usage, create table, create view on schema raw.source to role transformer;
grant all privileges on all tables in schema raw.source to role transformer;
grant all privileges on future tables in schema raw.source to role transformer;

grant usage, create schema on database golden to role transformer;
grant usage, create table, create view on all schemas in database golden to role transformer;
grant usage, create table, create view on future schemas in database golden to role transformer;
grant all privileges on all tables in database golden to role transformer;
grant all privileges on future tables in database golden to role transformer;
grant all privileges on all views in database golden to role transformer;
grant all privileges on future views in database golden to role transformer;

-- Grant the role to whoever runs this script so dbt can use it immediately.
set setup_user = (select current_user());
grant role transformer to user identifier($setup_user);
