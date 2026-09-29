-- Minimal stand-in for the parts of Supabase the migration relies on, so the
-- schema can be tested on a plain PostgreSQL. Never run this on Supabase.
-- Roles are shared by every database on the server, so create them once.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
  -- PostgREST logs in as this role and switches to anon/authenticated.
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit;
  end if;
  grant anon, authenticated, service_role to authenticator;
end $$;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  phone text,
  email text,
  raw_user_meta_data jsonb not null default '{}'
);

-- Supabase reads the signed-in user from the request's JWT claims (same
-- definition as Supabase's own).
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

-- New Supabase projects may not expose new tables to the app automatically,
-- so the migrations grant access explicitly. Only schema usage is given
-- here, to match that stricter setup.
grant usage on schema public to anon, authenticated, service_role;
