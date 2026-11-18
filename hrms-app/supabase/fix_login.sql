

-- =============================================================================
-- NYGENX HRMS: Complete Authentication & Database Fix Script
-- Run this entire script in Supabase Dashboard -> SQL Editor -> Run
-- =============================================================================

-- Enable required crypto extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1. Create or Update Auth Users (Logins & Passwords)
-- -----------------------------------------------------------------------------
do $$
declare
  admin_uid uuid;
  hr_uid    uuid;
  emp_uid   uuid;
begin
  -- 1.1 Admin User: admin@nygenx.com
  select id into admin_uid from auth.users where email = 'admin@nygenx.com' limit 1;
  if admin_uid is null then
    admin_uid := '00000000-0000-0000-0000-000000000001'::uuid;
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      admin_uid,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      'admin@nygenx.com',
      crypt('Admin@Nygenx2024', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"name":"System Admin","role":"Admin"}',
      '', '', '', ''
    );
  else
    update auth.users set
      encrypted_password = crypt('Admin@Nygenx2024', gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      updated_at = now(),
      raw_user_meta_data = '{"name":"System Admin","role":"Admin"}'
    where id = admin_uid;
  end if;

  insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
  values (
    gen_random_uuid(), admin_uid::text, admin_uid,
    jsonb_build_object('sub', admin_uid::text, 'email', 'admin@nygenx.com', 'email_verified', true),
    'email', now(), now()
  ) on conflict (provider_id, provider) do nothing;

  -- 1.2 HR User: hr@nygenx.com
  select id into hr_uid from auth.users where email = 'hr@nygenx.com' limit 1;
  if hr_uid is null then
    hr_uid := '00000000-0000-0000-0000-000000000010'::uuid;
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      hr_uid,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      'hr@nygenx.com',
      crypt('Hr@Nygenx2024', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"name":"HR Manager","role":"HR"}',
      '', '', '', ''
    );
  else
    update auth.users set
      encrypted_password = crypt('Hr@Nygenx2024', gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      updated_at = now(),
      raw_user_meta_data = '{"name":"HR Manager","role":"HR"}'
    where id = hr_uid;
  end if;

  insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
  values (
    gen_random_uuid(), hr_uid::text, hr_uid,
    jsonb_build_object('sub', hr_uid::text, 'email', 'hr@nygenx.com', 'email_verified', true),
    'email', now(), now()
  ) on conflict (provider_id, provider) do nothing;

  -- 1.3 Employee User: employee@nygenx.com
  select id into emp_uid from auth.users where email = 'employee@nygenx.com' limit 1;
  if emp_uid is null then
    emp_uid := '00000000-0000-0000-0000-000000000020'::uuid;
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      emp_uid,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      'employee@nygenx.com',
      crypt('Employee@Nygenx2024', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"name":"John Employee","role":"Employee"}',
      '', '', '', ''
    );
  else
    update auth.users set
      encrypted_password = crypt('Employee@Nygenx2024', gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      updated_at = now(),
      raw_user_meta_data = '{"name":"John Employee","role":"Employee"}'
    where id = emp_uid;
  end if;

  insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
  values (
    gen_random_uuid(), emp_uid::text, emp_uid,
    jsonb_build_object('sub', emp_uid::text, 'email', 'employee@nygenx.com', 'email_verified', true),
    'email', now(), now()
  ) on conflict (provider_id, provider) do nothing;

end $$;

-- -----------------------------------------------------------------------------
-- 2. Create Roles Table & Insert Roles
-- -----------------------------------------------------------------------------
create table if not exists public.roles (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  created_at  timestamp with time zone default now()
);

insert into public.roles (name, description) values
  ('Admin',    'Full system access'),
  ('HR',       'HR management access'),
  ('Manager',  'Team management access'),
  ('Employee', 'Standard employee access')
on conflict (name) do nothing;

-- -----------------------------------------------------------------------------
-- 3. Create Users Table (Profile Table)
-- -----------------------------------------------------------------------------
create table if not exists public.users (
  id          uuid primary key default gen_random_uuid(),
  auth_id     uuid unique,
  email       text not null unique,
  role_id     uuid references public.roles(id),
  employee_id uuid,
  status      text default 'Active',
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

-- Ensure employees table has user_id
alter table public.employees add column if not exists user_id uuid;

-- Ensure departments & designations have expected columns
alter table public.departments add column if not exists code text;
alter table public.departments add column if not exists head_id uuid;
alter table public.designations add column if not exists name text;
alter table public.designations add column if not exists department_id uuid;

-- -----------------------------------------------------------------------------
-- 4. Insert Employee Records
-- -----------------------------------------------------------------------------
insert into public.employees (
  employee_code, first_name, last_name, email, phone,
  joining_date, employment_type, status, branch
)
values (
  'NYG-ADM-001', 'System', 'Admin', 'admin@nygenx.com', '9876543210',
  '2024-01-01', 'Full-time', 'Active', 'HQ'
) on conflict (email) do update set status = 'Active';

insert into public.employees (
  employee_code, first_name, last_name, email, phone,
  joining_date, employment_type, status, branch
)
values (
  'NYG-HR-001', 'HR', 'Manager', 'hr@nygenx.com', '9876543211',
  '2024-01-01', 'Full-time', 'Active', 'HQ'
) on conflict (email) do update set status = 'Active';

insert into public.employees (
  employee_code, first_name, last_name, email, phone,
  joining_date, employment_type, status, branch
)
values (
  'NYG-EMP-001', 'John', 'Employee', 'employee@nygenx.com', '9876543212',
  '2024-01-01', 'Full-time', 'Active', 'HQ'
) on conflict (email) do update set status = 'Active';

-- -----------------------------------------------------------------------------
-- 5. Link Auth Users, Roles & Employees
-- -----------------------------------------------------------------------------
do $$
declare
  admin_r_id uuid;
  hr_r_id    uuid;
  emp_r_id   uuid;
  a_uid      uuid;
  h_uid      uuid;
  e_uid      uuid;
begin
  select id into admin_r_id from public.roles where name = 'Admin';
  select id into hr_r_id    from public.roles where name = 'HR';
  select id into emp_r_id   from public.roles where name = 'Employee';

  select id into a_uid from auth.users where email = 'admin@nygenx.com' limit 1;
  select id into h_uid from auth.users where email = 'hr@nygenx.com' limit 1;
  select id into e_uid from auth.users where email = 'employee@nygenx.com' limit 1;

  if a_uid is not null then
    insert into public.users (auth_id, email, role_id, status)
    values (a_uid, 'admin@nygenx.com', admin_r_id, 'Active')
    on conflict (email) do update set auth_id = a_uid, role_id = admin_r_id, status = 'Active';
  end if;

  if h_uid is not null then
    insert into public.users (auth_id, email, role_id, status)
    values (h_uid, 'hr@nygenx.com', hr_r_id, 'Active')
    on conflict (email) do update set auth_id = h_uid, role_id = hr_r_id, status = 'Active';
  end if;

  if e_uid is not null then
    insert into public.users (auth_id, email, role_id, status)
    values (e_uid, 'employee@nygenx.com', emp_r_id, 'Active')
    on conflict (email) do update set auth_id = e_uid, role_id = emp_r_id, status = 'Active';
  end if;
end $$;

-- Cross-link employee_id in users & user_id in employees
update public.users u
set employee_id = e.id
from public.employees e
where u.email = e.email
and (u.employee_id is null or u.employee_id != e.id);

update public.employees e
set user_id = u.auth_id
from public.users u
where e.email = u.email
and (e.user_id is null or e.user_id != u.auth_id);

-- -----------------------------------------------------------------------------
-- 6. Permissions & Row Level Security (RLS)
-- -----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;

alter table public.roles enable row level security;
alter table public.users enable row level security;
alter table public.employees enable row level security;

drop policy if exists "roles_select_all" on public.roles;
create policy "roles_select_all" on public.roles for select to authenticated, anon using (true);

drop policy if exists "users_select_all" on public.users;
create policy "users_select_all" on public.users for select to authenticated, anon using (true);

drop policy if exists "users_all" on public.users;
create policy "users_all" on public.users for all to authenticated, anon using (true) with check (true);

drop policy if exists "employees_select_all" on public.employees;
create policy "employees_select_all" on public.employees for select to authenticated, anon using (true);

drop policy if exists "employees_all" on public.employees;
create policy "employees_all" on public.employees for all to authenticated, anon using (true) with check (true);

-- -----------------------------------------------------------------------------
-- 7. Verification: Confirm everything is created
-- -----------------------------------------------------------------------------
select 'auth.users' as table_name, count(*) as count from auth.users where email in ('admin@nygenx.com', 'hr@nygenx.com', 'employee@nygenx.com')
union all
select 'public.roles', count(*) from public.roles
union all
select 'public.users', count(*) from public.users where email in ('admin@nygenx.com', 'hr@nygenx.com', 'employee@nygenx.com')
union all
select 'public.employees', count(*) from public.employees where email in ('admin@nygenx.com', 'hr@nygenx.com', 'employee@nygenx.com');
