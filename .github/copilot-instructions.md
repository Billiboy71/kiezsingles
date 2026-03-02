\# ============================================================================

\# File: C:\\laragon\\www\\kiezsingles\\.github\\copilot-instructions.md

\# Purpose: High-priority agent instructions for VS Agent / Copilot-style tools

\# Created: 02-03-2026 (Europe/Berlin)

\# Version: 0.1

\# ============================================================================



This repository has strict governance rules.



You MUST read and follow:



\- `AGENTS.md` (primary agent entry point)

\- `codex-rules.md` (binding detailed rulebook)



Non-negotiable principles:



1\) Deterministic changes only.

2\) No silent side effects.

3\) Do not modify files that were not explicitly approved.

4\) No refactoring, formatting, cleanup, or structural changes unless explicitly approved.

5\) Security and access control are server-side only (Single Source of Truth).

6\) Superadmin must never be blocked by hard role checks.

7\) At least one superadmin must always exist (fail-safe).



When a task appears to require changes in multiple files:

STOP and request explicit approval listing all affected files.



When modifying a file:

\- Preserve or add a header.

\- Update only one `Changed:` line.

\- Use format: DD-MM-YYYY HH:MM (Europe/Berlin).

\- Increase Version by +0.1.

\- Do not perform cosmetic edits.



If unsure where logic belongs:

Search for the central SSOT file first (middleware, bootstrap/app.php, admin router, security services).

Do not invent parallel logic.

