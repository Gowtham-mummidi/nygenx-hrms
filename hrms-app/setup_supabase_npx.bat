@echo off
rem =========================================================
rem  Supabase setup for NYGENX HRMS - using npx (no global install)
rem  1. Log in to Supabase (opens a browser)
rem  2. Link the local project to your Supabase project (ref: dde23b6e)
rem  3. Push the DB schema (creates all tables)
rem  4. Create the three storage buckets
rem  5. Reminder to enable Email confirmations
rem =========================================================

rem ---- 1 Log in -------------------------------------------------
echo.
echo [INFO] Opening browser for Supabase login...
npx supabase login
if %errorlevel% neq 0 (
    echo [ERROR] Supabase login failed.
    pause
    exit /b 1
)

rem ---- 2 Link project -------------------------------------------
set "PROJECT_REF=dde23b6e"
echo.
echo [INFO] Linking to project %PROJECT_REF% ...
npx supabase link --project-ref %PROJECT_REF%
if %errorlevel% neq 0 (
    echo [ERROR] Project linking failed.
    pause
    exit /b 1
)

rem ---- 3 Push migration (creates tables) -----------------------
echo.
echo [INFO] Applying DB schema (run migration)...
npx supabase db push
if %errorlevel% neq 0 (
    echo [ERROR] DB migration failed.
    pause
    exit /b 1
)

rem ---- 4 Create storage buckets ----------------------------------
echo.
echo [INFO] Creating storage buckets...
npx supabase storage bucket create employee-docs --public false
if %errorlevel% neq 0 (
    echo [WARN] Bucket employee-docs may already exist or creation failed.
)
npx supabase storage bucket create bank-proofs --public false
if %errorlevel% neq 0 (
    echo [WARN] Bucket bank-proofs may already exist or creation failed.
)
npx supabase storage bucket create asset-uploads --public false
if %errorlevel% neq 0 (
    echo [WARN] Bucket asset-uploads may already exist or creation failed.
)

rem ---- 5 Reminder - enable Email confirmations -----------------
echo.
echo [NOTE] --------------------------------------------------------
echo To prevent dummy accounts, enable Email confirmations:
echo   1. Open https://%PROJECT_REF%.supabase.co/
echo   2. Go to Authentication - Settings
echo   3. Turn ON "Email confirmations" and click Save.
echo ---------------------------------------------------------------
echo.
echo All Supabase setup steps are finished.
echo You can now start the HRMS dev server:
echo   cd "%~dp0"
echo   npx vite --host 0.0.0.0 --port 5174
pause

