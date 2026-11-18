-- 20231111_init.sql: Supabase schema for NYGENX HRMS
-- Run this via Supabase SQL editor or `supabase db push`

-- Enable uuid extension
create extension if not exists "uuid-ossp";

-- Employees table (core employee data)
create table public.employees (
  id                uuid    primary key default uuid_generate_v4(),
  employee_code     text    unique,
  first_name        text    not null,
  last_name         text    not null,
  email             text    not null unique,
  phone             text    not null unique,
  gender            text,
  date_of_birth     date,
  address           text,
  city              text,
  state             text,
  country           text,
  postal_code       text,
  emergency_contact text,
  emergency_contact_name text,
  emergency_contact_relation text,
  emergency_contact_phone text,
  guardian_name     text,
  guardian_relation text,
  guardian_phone    text,
  current_address   text,
  current_city      text,
  current_state     text,
  current_country   text,
  current_postal_code text,
  permanent_address text,
  permanent_city    text,
  permanent_state   text,
  permanent_country text,
  permanent_postal_code text,
  marital_status    text,
  blood_group       text,
  joining_date      date    not null,
  employment_type   text    default 'Full-time',
  department_id     uuid    references public.departments(id),
  designation_id    uuid    references public.designations(id),
  manager_id        uuid    references public.employees(id),
  status            text    default 'Active',
  branch            text    default 'HQ',
  basic_salary      numeric,
  hra               numeric,
  allowances        numeric,
  bonus             numeric,
  created_at        timestamp with time zone default now(),
  updated_at        timestamp with time zone default now()
);

-- Departments
create table public.departments (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null unique,
  description text,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

-- Designations
create table public.designations (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null unique,
  level       integer,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

-- Attendance
create table public.attendance (
  id          uuid primary key default uuid_generate_v4(),
  employee_id uuid not null references public.employees(id),
  date        date not null,
  status      text not null,
  check_in    timestamp with time zone,
  check_out   timestamp with time zone,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

-- Bank details (used by bankDetails API)
create table public.employee_bank_details (
  id                     uuid primary key default uuid_generate_v4(),
  employee_id            uuid not null references public.employees(id),
  employee_code          text,
  employee_name          text,
  employee_email         text,
  phone                  text,
  department             text,
  designation            text,
  bank_name              text,
  account_holder_name    text,
  account_number         text,
  ifsc_code              text,
  branch_name            text,
  account_type           text,
  upi_id                 text,
  pan_number             text,
  document_proof_name    text,
  document_proof_type    text,
  document_proof_url      text,
  status                 text default 'pending',
  verified_by            text,
  verified_at            timestamp with time zone,
  rejection_reason       text,
  admin_note             text,
  submitted_at           timestamp with time zone default now(),
  updated_at             timestamp with time zone default now()
);

-- Emails (outbound logs)
create table public.emails (
  id            uuid primary key default uuid_generate_v4(),
  to_address    text not null,
  subject       text,
  body          text,
  sent_at       timestamp with time zone default now(),
  status        text default 'sent',
  attachment_url text
);

-- Projects and members
create table public.projects (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  description text,
  start_date  date,
  end_date    date,
  status      text,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

create table public.project_members (
  id          uuid primary key default uuid_generate_v4(),
  project_id  uuid not null references public.projects(id),
  employee_id uuid not null references public.employees(id),
  role        text,
  joined_at   timestamp with time zone default now()
);

-- Service requests
create table public.service_requests (
  id          uuid primary key default uuid_generate_v4(),
  employee_id uuid not null references public.employees(id),
  title       text not null,
  description text,
  status      text default 'open',
  priority    text,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

-- Complaints
create table public.complaints (
  id          uuid primary key default uuid_generate_v4(),
  employee_id uuid not null references public.employees(id),
  subject     text not null,
  description text,
  status      text default 'new',
  filed_at    timestamp with time zone default now(),
  resolved_at timestamp with time zone
);

-- Performance assessments
create table public.performance_assessments (
  id                uuid primary key default uuid_generate_v4(),
  employee_id       uuid not null references public.employees(id),
  period_start      date not null,
  period_end        date not null,
  rating            integer,
  comments          text,
  created_at        timestamp with time zone default now(),
  updated_at        timestamp with time zone default now()
);

-- Generic assets (files stored in Supabase Storage)
create table public.assets (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  type        text,
  url         text not null,
  uploaded_by uuid references public.employees(id),
  uploaded_at timestamp with time zone default now()
);

-- Note: Supabase Auth automatically provides the `auth.users` table.

-- Storage buckets (create via UI or API)
-- Recommended bucket names:
--   employee-docs, bank-proofs, asset-uploads

