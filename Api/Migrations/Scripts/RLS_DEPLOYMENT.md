# Turning on row-level security

How to move the API from "policies exist but nothing enforces them" to "Postgres refuses the
rows". Written for whoever is at the server over RDP.

The whole switch is one line of config. Everything before it is preparation that changes
nothing, and everything after it is checking. Budget about 30 minutes, and do it when nobody
is using the system — not during a class or a demo.

## What you are switching

The API connects as `dbtc_app`, which **owns** the tables. Postgres exempts a table's owner
from that table's own policies, and this project deliberately does not use `FORCE ROW LEVEL
SECURITY`. So the policies are already in the database doing nothing.

Enforcement starts when the connection string names `dbtc_api` instead — a role that owns
nothing and therefore gets no exemption.

That also means **the rollback is changing that one line back**. No migration, no redeploy.

## Before you start

- A backup you have actually verified:
  `pg_dump -h localhost -U dbtc_app -d dbtc_sis -F c -f rls-pre.dump`
  then `pg_restore --list rls-pre.dump` and check you get roughly 200 entries and 27
  `TABLE DATA` lines. A truncated dump looks like a perfectly good file.
- The `postgres` superuser password. Step 2 needs it; `dbtc_app` cannot do that step.
- Everyone signed out. Sessions survive the pool recycle, but a request in flight during the
  switch can fail once.

## Step 1 — Deploy the code and apply the migration

The migration (`20261122061031_AddRowLevelSecurity`) only creates policies. Applying it
changes nothing observable, because `dbtc_app` is exempt. It is safe to do ahead of time.

Deploy the API the usual way, then apply migrations as `dbtc_app`:

```powershell
cd C:\dbtc\capstone\Api
dotnet ef database update --connection "Host=localhost;Database=dbtc_sis;Username=dbtc_app;Password=<dbtc_app password>"
```

Confirm the policies landed — expect **26** and **51**:

```powershell
psql -U dbtc_app -d dbtc_sis -c "SELECT count(*) FROM pg_tables WHERE schemaname='public' AND rowsecurity"
psql -U dbtc_app -d dbtc_sis -c "SELECT count(*) FROM pg_policies WHERE schemaname='public'"
```

The only table without RLS should be `__EFMigrationsHistory`.

## Step 2 — Create the runtime role

As the **postgres superuser**, not `dbtc_app` — creating a role needs `CREATEROLE`, which
`dbtc_app` does not have and should not be given.

```powershell
psql -U postgres -d dbtc_sis -f C:\dbtc\capstone\Api\Migrations\Scripts\rls_03_runtime_role.sql
psql -U postgres -d dbtc_sis -c "\password dbtc_api"
```

Use `\password`, which prompts without echoing. Do **not** put the password in
`ALTER ROLE ... PASSWORD '...'` on the command line: this VM is shared with another group
under the same `Administrator` login, and `ConsoleHost_history.txt` is readable by both.

The script refuses to finish if `dbtc_api` ends up with `SUPERUSER` or `BYPASSRLS`, either of
which would make every policy silently inert.

## Step 3 — Prove the policies actually bite

This is the step not to skip. RLS fails quietly: misconfigure it and every query still
returns everything, with no error to notice.

```powershell
psql -U postgres -d dbtc_sis -f C:\dbtc\capstone\Api\Migrations\Scripts\rls_04_verify.sql
```

It runs 20 assertions inside a transaction it rolls back, so it is safe against the live
database with real student records in it. Success prints one line:

```
NOTICE:  RLS verification passed.
```

Anything else — any line starting `RLS FAILED` — means **stop**. Do not continue to step 4.
The message names the assertion that failed.

## Step 3b — The two scripts that are not in the migration

`rls_02_policies.sql` is the whole policy set, but two groups of policies were added after the
first switch-on and are also kept as small scripts, so a live database can be brought forward
without re-running everything. **Both are idempotent and both are needed before anyone enrolls.**

```powershell
psql -U dbtc_app -d dbtc_sis -f C:\dbtc\capstone\Api\Migrations\Scripts\rls_05_public_enrollment.sql
psql -U dbtc_app -d dbtc_sis -f C:\dbtc\capstone\Api\Migrations\Scripts\rls_06_reenrollment.sql
```

- **rls_05** lets a stranger with no account submit the public application form (role -2).
  Without it the Enroll button on the sign-in page fails at the moment of submitting.
- **rls_06** lets a signed-in old student send their own re-enrollment (role 5). Without it
  re-enrollment is broken: the submission writes four tables, all of which were staff-only, so
  Postgres refuses the first insert and nothing is saved.

**Neither failure can be seen while the enrollment window is shut**, because the window is
checked before anything is written — and no test can see them either, since the suites either
have no policies at all or connect as the table owner, which Postgres exempts. So confirm them
by hand, as the API's own role:

```powershell
psql -U dbtc_app -d dbtc_sis -c "SELECT policyname FROM pg_policies WHERE policyname LIKE '%public_insert' OR policyname LIKE '%student_insert' ORDER BY policyname"
```

Expect five: one `EnrollmentResponses_public_insert` and four `..._student_insert`
(`Contacts`, `EnrollmentApplications`, `EnrollmentForms`, `EnrollmentResponses`). Anything
missing means that path is still refused.

## Step 4 — The switch

Edit `appsettings.Production.json` and change `Username` and `Password` in
`ConnectionStrings:DefaultConnection` from `dbtc_app` to `dbtc_api`. Leave everything else
alone. Use the JSON-object method, not Notepad and not a regex — see the note at the end.

```powershell
$pp = 'C:\dbtc\api\appsettings.Production.json'
Copy-Item $pp "$pp.bak-before-rls"
$j = Get-Content $pp -Raw | ConvertFrom-Json
$j.ConnectionStrings.DefaultConnection = 'Host=localhost;Database=dbtc_sis;Username=dbtc_api;Password=<the password from step 2>'
$j | ConvertTo-Json -Depth 10 | Set-Content $pp -Encoding UTF8
(Get-Content $pp -Raw | ConvertFrom-Json).PSObject.Properties.Name
Restart-WebAppPool -Name 'DbtcApi'
```

That last listing should still print `ConnectionStrings`, `Firebase`, `Webhook`, `Cors`. If a
section is missing, restore `.bak-before-rls` and try again.

## Step 5 — Smoke test, in this order

1. **The API is alive**: `https://app1.13-238-43-68.sslip.io/api/curricula` returns **401**,
   not 500. A 500 here means the connection string is wrong or `dbtc_api` lacks a grant —
   check `C:\dbtc\api\logs\`.
2. **Sign in as a student** on app5. If sign-in itself fails, the bootstrap policy on `Users`
   is the thing to look at: resolving a token into a user is a query that RLS applies to.
3. **A student sees their own grades, and only those.**
4. **Sign in as the registrar** on app2 and open a few students. Staff should see everything
   they saw before.
5. **A teacher** on app4 sees their own classes and can save a grade.
6. **Re-enrollment** for a student who has a hold — they should still be told about the hold.
   This one is specifically worth checking: before the fix in this commit, the hold was
   invisible to the student's own session and they would have been let through.

## If something is wrong

Change `Username`/`Password` back to `dbtc_app` and recycle the pool:

```powershell
$j = Get-Content $pp -Raw | ConvertFrom-Json
$j.ConnectionStrings.DefaultConnection = 'Host=localhost;Database=dbtc_sis;Username=dbtc_app;Password=<dbtc_app password>'
$j | ConvertTo-Json -Depth 10 | Set-Content $pp -Encoding UTF8
Restart-WebAppPool -Name 'DbtcApi'
```

RLS is inert again within seconds. The policies stay in the database, so you can fix the
policy and switch back without redeploying anything.

**Expect the failure to look like missing data, not an error.** A policy that is too narrow
shows up as an empty list, a blank page, or a count of zero — not an exception. If a page
that worked yesterday is suddenly empty for one role, suspect the policy for that table
before you suspect the UI.

To see what a given user can actually read, impersonate them in psql:

```sql
SET ROLE dbtc_api;
SELECT set_config('app.user_id', '<their UserID>', false),
       set_config('app.role', '5', false),          -- 1 Admin 2 Registrar 3 Teacher
       set_config('app.firebase_uid', '', false),   -- 4 Program Head 5 Student 6 College Head
       set_config('app.email', '', false);
SELECT count(*) FROM "Grades";
RESET ROLE;
```

## After a future migration adds a table

New tables arrive with **no policy and RLS disabled**, which means `dbtc_api` reads them
freely — the new table is simply unprotected, not broken. `ALTER DEFAULT PRIVILEGES` in
`rls_03` already handles the grants, so nothing fails; it just is not covered.

Add a policy to `rls_02_policies.sql`, put the same SQL in that migration, and re-run
`rls_04_verify.sql`.

## Notes

- **`appsettings.Production.json` overrides `appsettings.json`** and is not in the repo. The
  repo's values are inert on this server. Change this file, not the one in git.
- **Editing it**: Notepad can silently fail to save, and a regex replace of a block breaks
  when it is the file's last section. Read it with `ConvertFrom-Json`, assign the property,
  write it back with `ConvertTo-Json -Depth 10`. It reformats the whitespace and keeps every
  value.
- **Paste PowerShell `if`/`else` as one line.** Split across lines in the RDP console it runs
  the `if`, then errors on an orphaned `else`.
- **What this does not protect against.** The other capstone group shares this VM under the
  same `Administrator` login. They can read this config file, take the `dbtc_api` credentials,
  connect directly and set `app.user_id` to anything. RLS is a backstop against bugs in our
  own code, not isolation from a co-tenant with the same administrator rights.
