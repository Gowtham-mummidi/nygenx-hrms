# Supabase & HRMS Setup – Full Step‑by‑Step Guide

## 1️⃣ Install the Supabase CLI (once)
```powershell
# Open PowerShell **as Administrator**
npm i -g supabase
# Verify installation
supabase --version
```
If you get a permission error, re‑run the prompt as Administrator or add `--force`.

---
## 2️⃣ Run the SQL script to create the database schema
1. Open **Supabase Dashboard** → **SQL Editor** → **New query**.
2. Copy the entire block below (including the `create extension` line) and paste it into the editor.
3. Click **Run**.
4. Verify that the new tables appear under **Database → Tables**.

```sql
-- -------------------------------------------------
-- Supabase schema for NYGENX HRMS
-- -------------------------------------------------

-- Enable the UUID extension (required for default ids)
create extension if not exists "uuid-ossp";

-- Employees (core employee data)
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

create table public.departments (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null unique,
  description text,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

create table public.designations (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null unique,
  level       integer,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

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
  document_proof_url     text,
  status                 text default 'pending',
  verified_by            text,
  verified_at            timestamp with time zone,
  rejection_reason       text,
  admin_note             text,
  submitted_at           timestamp with time zone default now(),
  updated_at             timestamp with time zone default now()
);

create table public.emails (
  id            uuid primary key default uuid_generate_v4(),
  to_address    text not null,
  subject       text,
  body          text,
  sent_at       timestamp with time zone default now(),
  status        text default 'sent',
  attachment_url text
);

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

create table public.complaints (
  id          uuid primary key default uuid_generate_v4(),
  employee_id uuid not null references public.employees(id),
  subject     text not null,
  description text,
  status      text default 'new',
  filed_at    timestamp with time zone default now(),
  resolved_at timestamp with time zone
);

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

create table public.assets (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  type        text,
  url         text not null,
  uploaded_by uuid references public.employees(id),
  uploaded_at timestamp with time zone default now()
);

-- Supabase Auth automatically creates `auth.users`; no need to define it.

-- -------------------------------------------------
--  Storage buckets (create via UI)
-- -------------------------------------------------
-- After the script runs, go to **Storage → Buckets** and create:
--   employee-docs
--   bank-proofs
--   asset-uploads
-- Ensure each bucket is **private** (Public = off).

-- -------------------------------------------------
--  Optional: enable Row Level Security (RLS) if you need policies
-- -------------------------------------------------
-- Example for the employees table:
--   alter table public.employees enable row level security;
--   create policy "employees_self" on public.employees
--     using (auth.uid() = (select id from auth.users where email = employees.email));
```

---
## 3️⃣ Create the required storage buckets (via UI)
1. In the Supabase Dashboard, go to **Storage → Buckets**.
2. Click **New bucket** three times and name them exactly:
   * `employee-docs`
   * `bank-proofs`
   * `asset-uploads`
3. Leave **Public** unchecked so the buckets are private (only authenticated users can read/write).

---
## 4️⃣ Run the batch script to automate the CLI steps (optional but convenient)
1. Open **PowerShell** and navigate to the folder that contains the script:
   ```powershell
   cd "C:\Users\Madhu\Downloads\HRMS_app-main\HRMS_app-main\hrms-app"
   ```
2. Execute the script:
   ```powershell
   .\setup_supabase.bat
   ```
   The script will:
   * Open a browser for you to **log in** to Supabase.
   * **Link** the local project to your Supabase project (reference `dde23b6e`).
   * **Push** the migration (same tables created by the SQL script above). If you already ran the SQL manually, this step will be a no‑op.
   * **Create** the three storage buckets (if they don’t already exist).
   * Show a reminder to enable email confirmations.
3. When the script finishes, follow the reminder to enable email verification (see step 5).

---
## 5️⃣ Enable **Email confirmations** (to block dummy accounts)
1. Open your Supabase project URL, e.g. `https://dde23b6e.supabase.co/`.
2. In the left sidebar choose **Authentication → Settings**.
3. Scroll to **Email confirmations** and toggle it **ON**.
4. Click **Save** at the bottom.

Now any user that registers must click the verification link sent to their inbox before they can log in.

---
## 6️⃣ Start (or restart) the Vite dev server
```powershell
cd "C:\Users\Madhu\Downloads\HRMS_app-main\HRMS_app-main\hrms-app"
npx vite --host 0.0.0.0 --port 5174
```
The server will print something like:
```
VITE v5.4.21  ready in xxx ms
➜  Local:   http://localhost:5174/
```
Open that URL in a browser.

---
## 7️⃣ Verify the end‑to‑end flow
| Action | What to check |
|--------|----------------|
| **Register** a new user | Use a real email address. After you submit the form, check your inbox for the verification email, click the link, and then log in. |
| **Login** works only after verification | Try to log in with an unverified address – you should see an error. After verification, login succeeds. |
| **Create an employee** | Fill the *Add Employee* form. Then go to Supabase → **Database → Tables → employees** and see the new row. |
| **Upload a bank‑detail document** | Navigate to the Bank Details page, fill the required fields and upload a file. In Supabase → **Storage → Buckets → bank-proofs** you should see the uploaded file. |
| **Other modules** (attendance, projects, complaints, etc.) | Perform a few create/read/update actions and verify the corresponding tables (`attendance`, `projects`, `complaints`, …) contain the data. |

If anything fails, copy the error message from the browser console or the Supabase logs and share it with me – I’ll help you debug.

---
## 8️⃣ (Optional) Add the same email‑format validation to the **sign‑up** form
If you want the sign‑up page to reject malformed emails before they hit Supabase, add the following snippet (very similar to the login page) inside the submit handler of `src/features/auth/signup-page.tsx`:
```tsx
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
if (!emailRegex.test(cleanEmail)) {
  setError('Please enter a valid email address');
  setSubmitting(false);
  return;
}
```
Replace `cleanEmail` with the trimmed email value you already have.

---
# 🎉 You’re all set!
Follow the steps in order, and your HRMS application will be fully connected to the new Supabase backend, with real‑email authentication enforced and all required tables/buckets in place.

If you hit any roadblock, just paste the exact error output here and I’ll help you fix it.

