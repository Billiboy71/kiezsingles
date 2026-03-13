# ============================================================================
# File: C:\laragon\www\kiezsingles\AGENTS.md
# Purpose: Entry-point instructions for AI agents (Codex/VS Agent) – KiezSingles SSOT + change rules
# Created: 02-03-2026 (Europe/Berlin)
# Changed: 09-03-2026 16:31 (Europe/Berlin)
# Version: 0.2
# ============================================================================

## 0) Read this first (priority)

This file is the short, high-priority entry point for AI agents.

Detailed rules live in: `C:\laragon\www\kiezsingles\codex-rules.md` (must be followed).

## 1) Non-negotiable change governance

- Work deterministically. No silent side effects.
- Change only explicitly approved files. Never touch additional files.
- Output rules (for chat-based work): either full file 1:1 replaceable, or no code. No snippets unless explicitly requested.
- No refactoring, no formatting, no "cleanup", no import sorting, no whitespace-only edits.
- Security/access is server-side only. UI visibility is never a permission check.

## 2) Header policy (mandatory)

For any file you modify:

- Keep or add a file header at top.
- Update only one line: `Changed: DD-MM-YYYY HH:MM (Europe/Berlin)` using the current local time.
- Increment `Version` by +0.1.
- Do not touch other header fields unless creating a new file.

## 3) Laravel 12 project specifics (SSOT)

- Middleware alias/registration: `C:\laragon\www\kiezsingles\bootstrap\app.php` (Laravel 12 has no `app/Http/Kernel.php`).
- Events: only with explicit listeners, registered in `EventServiceProvider`.

## 3.1) Database migrations (mandatory safety rules)

All database migrations must work both on:

- existing development databases (MySQL)
- fresh migrations used by automated tests (`php artisan test`, SQLite `:memory:`)

Rules:

- Migrations must run successfully on a completely empty database.
- `php artisan test` must never fail because of migrations.
- Avoid MySQL-specific SQL (`ALTER TABLE ... CHANGE ...`) when Laravel Schema Builder provides an equivalent.
- Before altering schema elements always verify existence:

  - `Schema::hasTable()`
  - `Schema::hasColumn()`

- When removing columns:

  1. remove dependent indexes / foreign keys first
  2. then perform `dropColumn`.

- Do not create parallel historical migrations that perform the same schema transition in different ways.

- Historical migrations must not be deleted.
  If necessary they must be guarded or neutralized to remain compatible with fresh migrations.

- Migrations must be written so that both
  - incremental migration on existing databases
  - full migration from scratch
  produce the same final schema.

## 4) Access control SSOT (never duplicate logic)

- Roles: superadmin, admin, moderator, user.
- Access checks must be centralized:

  - Middleware and/or a single SSOT access class.

- Do not add role checks scattered across route files or Blade views.
- Superadmin must not be blocked by hard role checks.
- Fail-safe: at least 1 superadmin must always exist; last superadmin cannot be deleted or demoted.

## 5) Routing SSOT

- Admin router entry: `C:\laragon\www\kiezsingles\routes\web\admin.php`
- Admin modules live under: `C:\laragon\www\kiezsingles\routes\web\admin\*`
- Do not add duplicated guards inside leaf route files; guards belong in the central admin router/middleware.

## 6) UI / CSS SSOT

- No business logic or DB queries in Blade views.
- Avoid inline scripts/styles; prefer central assets:

  - App assets: `resources/css/app.css`, `resources/js/app.js`
  - Admin assets (if present): `resources/css/admin.css`, `resources/js/admin.js`

- UI visibility must reflect server-side truth (no client-only permission decisions).

## 7) Security module conventions

- Security logging via `App\Services\Security\SecurityEventLogger`.
- IP/Identity bans must be enforced server-side and logged.
- Defaults are server-side only.

## 8) Operating mode guidance for agents

- Prefer single-file changes when requested. If more than one file would be needed: STOP and ask for explicit approval/list of files.
- When uncertain where the SSOT is: search for the central file listed above; do not invent parallel logic.

## 9) Reference (binding)

Primary detailed rulebook: `codex-rules.md` (binding).

If any instruction conflicts: `codex-rules.md` wins.