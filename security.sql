-- =============================================================
-- security.sql  —  Role-Based Access Control (RBAC)
-- EAS 550 | Vaishak Muralidharan
-- Spotify Music Trends Analysis
-- =============================================================
-- Run this script AFTER schema.sql and after data is loaded.
-- Execute as the database owner / superuser.
-- =============================================================


-- -------------------------------------------------------------
-- ROLE 1: analyst
-- Read-only access — for dashboard queries, data exploration,
-- and reporting. Cannot modify any data.
-- -------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'analyst') THEN
    CREATE ROLE analyst;
  END IF;
END $$;

-- Grant connection to the database
GRANT CONNECT ON DATABASE postgres TO analyst;

-- Grant usage on the public schema
GRANT USAGE ON SCHEMA public TO analyst;

-- SELECT only on all current tables
GRANT SELECT ON
    genres,
    artists,
    albums,
    tracks,
    audio_features,
    track_artists
TO analyst;

-- Also apply SELECT to any future tables created in this schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO analyst;


-- -------------------------------------------------------------
-- ROLE 2: app_user
-- Read + write access — for the backend application that powers
-- the interactive dashboard (e.g. adding user playlists,
-- saving filters, logging events in future phases).
-- -------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user;
  END IF;
END $$;

GRANT CONNECT ON DATABASE postgres TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;

-- SELECT, INSERT, UPDATE on all tables
GRANT SELECT, INSERT, UPDATE ON
    genres,
    artists,
    albums,
    tracks,
    audio_features,
    track_artists
TO app_user;

-- Allow sequences (needed for SERIAL primary key inserts)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Apply to future tables too
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO app_user;


-- -------------------------------------------------------------
-- NOTE: To create actual login users and assign roles:
--
--   CREATE USER dashboard_reader WITH PASSWORD 'strongpassword';
--   GRANT analyst TO dashboard_reader;
--
--   CREATE USER backend_app WITH PASSWORD 'strongpassword';
--   GRANT app_user TO backend_app;
-- -------------------------------------------------------------
