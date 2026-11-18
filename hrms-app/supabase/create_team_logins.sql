-- =============================================================================
-- NYGENX HRMS: Create 9 Team Logins, Roles & Designations
-- (Safe version: No ON CONFLICT clauses, fully compatible with existing schemas)
-- Run this in Supabase Dashboard -> SQL Editor -> Run
-- =============================================================================

-- Enable required crypto extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1. Ensure Roles Table Exists & Seed Baseline Roles
-- -----------------------------------------------------------------------------
create table if not exists public.roles (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  created_at  timestamp with time zone default now()
);

insert into public.roles (name, description)
select 'Admin', 'Full system administrator access'
where not exists (select 1 from public.roles where lower(name) = 'admin');

insert into public.roles (name, description)
select 'HR', 'Human resources manager access'
where not exists (select 1 from public.roles where lower(name) = 'hr');

insert into public.roles (name, description)
select 'Manager', 'Team and project manager access'
where not exists (select 1 from public.roles where lower(name) = 'manager');

insert into public.roles (name, description)
select 'Employee', 'Standard employee portal access'
where not exists (select 1 from public.roles where lower(name) = 'employee');

-- -----------------------------------------------------------------------------
-- 2. Ensure Users Table Exists
-- -----------------------------------------------------------------------------
create table if not exists public.users (
  id          uuid primary key default gen_random_uuid(),
  auth_id     uuid,
  email       text not null,
  role_id     uuid references public.roles(id),
  employee_id uuid,
  status      text default 'Active',
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

-- -----------------------------------------------------------------------------
-- 3. Ensure Departments & Designations Exist
-- -----------------------------------------------------------------------------
create table if not exists public.departments (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  code        text,
  description text,
  created_at  timestamp with time zone default now()
);

insert into public.departments (name, code, description)
select 'Executive', 'EXEC', 'Executive Leadership & Direction'
where not exists (select 1 from public.departments where lower(name) = 'executive');

insert into public.departments (name, code, description)
select 'Human Resources', 'HR', 'HR Management & Recruitment'
where not exists (select 1 from public.departments where lower(name) = 'human resources');

insert into public.departments (name, code, description)
select 'Engineering', 'ENG', 'Software Engineering & IT'
where not exists (select 1 from public.departments where lower(name) = 'engineering');

insert into public.departments (name, code, description)
select 'Operations', 'OPS', 'Operations & Administration'
where not exists (select 1 from public.departments where lower(name) = 'operations');

create table if not exists public.designations (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  department_id uuid,
  title         text not null default '',
  created_at    timestamp with time zone default now()
);

-- Ensure title column exists (required by existing schema)
alter table public.designations add column if not exists title text;
alter table public.designations alter column title drop not null;
alter table public.designations alter column title set default '';
update public.designations set title = name where title is null;


insert into public.designations (name, title)
select 'CEO', 'CEO'
where not exists (select 1 from public.designations where lower(name) = 'ceo');

insert into public.designations (name, title)
select 'Admin', 'Admin'
where not exists (select 1 from public.designations where lower(name) = 'admin');

insert into public.designations (name, title)
select 'HR', 'HR'
where not exists (select 1 from public.designations where lower(name) = 'hr');

insert into public.designations (name, title)
select 'Manager', 'Manager'
where not exists (select 1 from public.designations where lower(name) = 'manager');

insert into public.designations (name, title)
select 'Software Engineer', 'Software Engineer'
where not exists (select 1 from public.designations where lower(name) = 'software engineer');

-- Ensure columns exist on employees
alter table public.employees add column if not exists user_id uuid;
alter table public.employees add column if not exists department_id uuid;
alter table public.employees add column if not exists designation_id uuid;
alter table public.employees add column if not exists phone text;

-- -----------------------------------------------------------------------------
-- 4. Provision All 9 Accounts (Using IF/ELSE, no ON CONFLICT constraints needed)
-- -----------------------------------------------------------------------------
do $$
declare
  account record;
  v_user_id uuid;
  v_emp_id uuid;
  v_role_id uuid;
  v_dept_id uuid;
  v_desig_id uuid;
begin
  for account in
    select * from (values
      ('manogna@nygenx.com',           'man@112233', 'Manogna',  'Reddy',     'CEO',               'Admin',    'Executive',        'NYG-CEO-001', '9000000010'),
      ('nygenx@nygenx.com',            'nyg@112233', 'Nygenx',   'Admin',     'Admin',             'Admin',    'Operations',       'NYG-ADM-002', '9000000011'),
      ('chaitanya@nygenx.com',         'cha@112233', 'Chaitanya','Kumar',     'Manager',           'Manager',  'Engineering',      'NYG-MGR-001', '9000000012'),
      ('hrinfo@nygenx.com',            'hri@112233', 'HR',       'Info',      'HR',                'HR',       'Human Resources',  'NYG-HR-002',  '9000000013'),
      ('sivaram.kasireddy@nygenx.com', 'siv@112233', 'Sivaram',  'Kasireddy', 'Software Engineer', 'Employee', 'Engineering',      'NYG-ENG-001', '9000000014'),
      ('krishna.pallapati@nygenx.com', 'kri@112233', 'Krishna',  'Pallapati', 'Software Engineer', 'Employee', 'Engineering',      'NYG-ENG-002', '9000000015'),
      ('ramu.mangali@nygenx.com',      'ram@112233', 'Ramu',     'Mangali',   'Software Engineer', 'Employee', 'Engineering',      'NYG-ENG-003', '9000000016'),
      ('suryani@nygenx.com',           'sur@112233', 'Suryani',  'Devi',      'Software Engineer', 'Employee', 'Engineering',      'NYG-ENG-004', '9000000017'),
      ('gokul@nygenx.com',             'gok@112233', 'Gokul',    'Nekkanti',  'Software Engineer', 'Employee', 'Engineering',      'NYG-ENG-005', '9000000018')
    ) as t(email, raw_pwd, first_name, last_name, designation, role_name, dept_name, emp_code, phone)
  loop
    -- Lookup Role ID
    select id into v_role_id from public.roles where lower(name) = lower(account.role_name) limit 1;
    -- Lookup Dept ID
    select id into v_dept_id from public.departments where lower(name) = lower(account.dept_name) limit 1;
    -- Lookup Desig ID
    select id into v_desig_id from public.designations where lower(name) = lower(account.designation) limit 1;

    -- 4.1 Upsert auth.users
    select id into v_user_id from auth.users where lower(email) = lower(account.email) limit 1;
    if v_user_id is null then
      v_user_id := gen_random_uuid();
      insert into auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change_token_new, email_change
      ) values (
        v_user_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated',
        lower(account.email),
        crypt(account.raw_pwd, gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('name', account.first_name || ' ' || account.last_name, 'role', account.role_name),
        '', '', '', ''
      );
    else
      update auth.users set
        encrypted_password = crypt(account.raw_pwd, gen_salt('bf')),
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        updated_at = now(),
        raw_user_meta_data = jsonb_build_object('name', account.first_name || ' ' || account.last_name, 'role', account.role_name)
      where id = v_user_id;
    end if;

    -- 4.2 Upsert auth.identities
    if not exists (select 1 from auth.identities where user_id = v_user_id) then
      insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
      values (
        gen_random_uuid(),
        v_user_id::text,
        v_user_id,
        jsonb_build_object('sub', v_user_id::text, 'email', lower(account.email), 'email_verified', true),
        'email', now(), now()
      );
    else
      update auth.identities set
        identity_data = jsonb_build_object('sub', v_user_id::text, 'email', lower(account.email), 'email_verified', true),
        updated_at = now()
      where user_id = v_user_id;
    end if;

    -- 4.3 Upsert employees
    select id into v_emp_id from public.employees where lower(email) = lower(account.email) limit 1;
    if v_emp_id is null then
      insert into public.employees (
        employee_code, first_name, last_name, email, phone,
        department_id, designation_id, status, employment_type, joining_date, branch, user_id
      ) values (
        account.emp_code, account.first_name, account.last_name, lower(account.email), account.phone,
        v_dept_id, v_desig_id, 'Active', 'Full-time', '2024-01-01', 'HQ', v_user_id
      ) returning id into v_emp_id;
    else
      update public.employees set
        first_name = account.first_name,
        last_name = account.last_name,
        phone = coalesce(phone, account.phone),
        department_id = coalesce(v_dept_id, department_id),
        designation_id = coalesce(v_desig_id, designation_id),
        user_id = v_user_id,
        status = 'Active'
      where id = v_emp_id;
    end if;

    -- 4.4 Upsert public.users
    if exists (select 1 from public.users where lower(email) = lower(account.email)) then
      update public.users set
        auth_id = v_user_id,
        role_id = v_role_id,
        employee_id = v_emp_id,
        status = 'Active',
        updated_at = now()
      where lower(email) = lower(account.email);
    else
      insert into public.users (
        auth_id, email, role_id, employee_id, status, created_at, updated_at
      ) values (
        v_user_id, lower(account.email), v_role_id, v_emp_id, 'Active', now(), now()
      );
    end if;

  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 5. Cross-link all user_id and employee_id
-- -----------------------------------------------------------------------------
update public.users u
set employee_id = e.id
from public.employees e
where lower(u.email) = lower(e.email);

update public.employees e
set user_id = u.auth_id
from public.users u
where lower(e.email) = lower(u.email);

-- -----------------------------------------------------------------------------
-- 6. Permissions & Row Level Security (RLS)
-- -----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;

alter table public.roles enable row level security;
alter table public.users enable row level security;
alter table public.employees enable row level security;
alter table public.departments enable row level security;
alter table public.designations enable row level security;

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

drop policy if exists "departments_select_all" on public.departments;
create policy "departments_select_all" on public.departments for select to authenticated, anon using (true);

drop policy if exists "designations_select_all" on public.designations;
create policy "designations_select_all" on public.designations for select to authenticated, anon using (true);

-- -----------------------------------------------------------------------------
-- 7. Verification: Return all 9 accounts and their assigned role & status
-- -----------------------------------------------------------------------------
select
  u.email,
  r.name as role,
  d.name as designation,
  dept.name as department,
  u.status
from public.users u
left join public.roles r on u.role_id = r.id
left join public.employees e on u.employee_id = e.id
left join public.designations d on e.designation_id = d.id
left join public.departments dept on e.department_id = dept.id
where u.email in (
  'manogna@nygenx.com',
  'nygenx@nygenx.com',
  'chaitanya@nygenx.com',
  'hrinfo@nygenx.com',
  'sivaram.kasireddy@nygenx.com',
  'krishna.pallapati@nygenx.com',
  'ramu.mangali@nygenx.com',
  'suryani@nygenx.com',
  'gokul@nygenx.com'
)
order by
  case r.name
    when 'Admin' then 1
    when 'HR' then 2
    when 'Manager' then 3
    else 4
  end;
