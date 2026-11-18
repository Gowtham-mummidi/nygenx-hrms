@echo off
rem -------------------------------------------------
rem  Supabase setup for NYGENX HRMS
rem  1. Log in to Supabase
rem  2. Link to your project (reference: dde23b6e)
rem  3. Push the DB schema migration
rem  4. Create required storage buckets
rem  5. Reminder to enable email verification
rem -------------------------------------------------

rem ---- Verify CLI is installed --------------------------------
where supabase >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Supabase CLI not found.
    echo Install it first: npm i -g supabase
    exit /b 1
)

rem ---- Log in -------------------------------------------------
echo.
echo [INFO] Opening browser for Supabase login...
supabase login
if %errorlevel% neq 0 (
    echo [ERROR] Login failed.
    exit /b 1
)

rem ---- Link project --------------------------------------------
set PROJECT_REF=dde23b6e
echo.
echo [INFO] Linking to project %PROJECT_REF% ...
supabase link --project-ref %PROJECT_REF%
if %errorlevel% neq 0 (
    echo [ERROR] Link failed.
    exit /b 1
)

rem ---- Push migration -------------------------------------------
echo.
echo [INFO] Applying DB schema...
supabase db push
if %errorlevel% neq 0 (
    echo [ERROR] DB push failed.
    exit /b 1
)

rem ---- Create storage buckets ------------------------------------
echo.
echo [INFO] Creating storage buckets...
supabase storage bucket create employee-docs --public false
supabase storage bucket create bank-proofs   --public false
supabase storage bucket create asset-uploads --public false
if %errorlevel% neq 0 (
    echo [ERROR] Bucket creation failed.
    exit /b 1
)

rem ---- Reminder for email verification ---------------------------
echo.
echo [NOTE] Enable Email confirmations in the Supabase dashboard:
echo   1. Open https://%PROJECT_REF%.supabase.co/
echo   2. Go to Authentication → Settings
echo   3. Turn ON “Email confirmations” and SAVE.
echo.
echo -------------------------------------------------
echo All Supabase setup steps are done.
echo Restart the dev server (if stopped) and browse:
echo   http://localhost:5174/
echo -------------------------------------------------
pause
