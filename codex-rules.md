# ============================================================================
# File: C:\laragon\www\kiezsingles\codex-rules.md
# Purpose: Verbindliche Projektregeln für Codex (KiezSingles)
# Created: 24-02-2026 (Europe/Berlin)
# Changed: 24-02-2026 14:40 (Europe/Berlin)
# Version: 1.3
# ============================================================================

# GRUNDPRINZIP

Deterministische, kontrollierte Änderungen.
Keine stillen Nebenwirkungen.
Server ist immer die maßgebliche Instanz (Single Source of Truth).

# ---------------------------------------------------------------------------
# BEGRIFFSDEFINITIONEN (VERBINDLICH)
# ---------------------------------------------------------------------------

## Rollen
- superadmin
- admin
- moderator
- user

## Sections / Module (Admin)
- overview
- maintenance
- debug
- moderation
- tickets
- weitere Module nur über zentrale Registry

## Globale Gates
- maintenanceEnabled (serverseitig)
- sectionAccess[section] (serverseitig)
- debugFeaturesEnabled (optional, serverseitig)

# ---------------------------------------------------------------------------
# ARBEITSWEISE
# ---------------------------------------------------------------------------

1. Feature oder Problem fachlich analysieren.
2. Betroffene Datei(en) selbst ermitteln.
3. Vor Änderungen:
   - Vollständige Dateipfade nennen.
   - Anzahl der betroffenen Dateien klar angeben.
4. Änderungen nur in explizit freigegebenen Dateien durchführen.
5. Keine weiteren Dateien ohne ausdrückliche Freigabe anfassen.

# ---------------------------------------------------------------------------
# BULK-UMBAU (OHNE ZWISCHENREVIEW)
# ---------------------------------------------------------------------------

Wenn ein Umbau/Änderung viele Dateien betrifft und der User kein manuelles Review pro Datei leisten kann,
gilt optional folgender Modus:

- Keine Datei einzeln zur Bestätigung anfordern.
- Keine Zwischenstände ausgeben.
- Keine vollständigen Datei-Outputs zur manuellen Prüfung liefern.
- Änderungen vollständig und projektweit konsistent durchführen.
- Am Ende nur eine kompakte Änderungsübersicht ausgeben:
  - Liste der geänderten Dateien
  - Kurze Beschreibung pro Datei (1–2 Sätze)
- Danach testet der User; Fixes/Reverts erfolgen erst bei Rückmeldung.

# ---------------------------------------------------------------------------
# ÄNDERUNGSREGELN
# ---------------------------------------------------------------------------

- Standard: Nur minimal notwendige Datei(en) ändern.
- Keine stillen Nebenänderungen.
- Keine Strukturumbauten ohne vorherige Zustimmung.
- Kein automatisches Refactoring.
- Refactoring nur:
  - Begründet vorschlagen.
  - Erst nach expliziter Freigabe umsetzen.
- Optimierungen:
  - Dürfen vorgeschlagen werden.
  - Umsetzung nur nach Freigabe.

# ---------------------------------------------------------------------------
# CODE-AUSGABE
# ---------------------------------------------------------------------------

- Immer vollständigen Dateipfad nennen.
- 🟢 bestehende Datei / 🔴 NEUE DATEI kennzeichnen.
- Entweder komplette Datei 1:1 ersetzbar oder kein Code.
- Keine Snippets (außer ausdrücklich verlangt).
- Header beibehalten oder neu anlegen.
- Bei Änderungen:
  - Nur eine `Changed:`-Zeile aktualisieren.
  - Format: DD-MM-YYYY HH:MM (Europe/Berlin).
  - Version +0.1.
- Keine kosmetischen Änderungen (Whitespace, Formatierung, Imports sortieren etc.).

# ---------------------------------------------------------------------------
# SECURITY & ACCESS ARCHITEKTUR
# ---------------------------------------------------------------------------

- Sicherheitsrelevante Logik ausschließlich serverseitig.
- UI-Sichtbarkeit ersetzt niemals Berechtigungsprüfung.
- Rollen- und Section-Zugriffe ausschließlich über:
  - Middleware
  - oder zentrale Access-Klasse (Single Source of Truth).
- Keine verteilten Role-Checks in einzelnen Route-Dateien.
- Superadmin:
  - Darf nicht durch harte Role-Checks blockiert werden.
  - Muss über zentrale Logik vollen Zugriff erhalten.
- Failsafe:
  - Mindestens 1 Superadmin muss immer existieren.
  - Letzter Superadmin darf nicht gelöscht oder entzogen werden.
- Defaults ausschließlich serverseitig setzen.
- Keine Business-Logik oder DB-Queries in Blade-Views.

# ---------------------------------------------------------------------------
# ACCESS-MATRIX (VERBINDLICH)
# ---------------------------------------------------------------------------

## Admin-Debug (/admin/debug)

superadmin:
- immer erlaubt (sichtbar + erreichbar)

admin / moderator:
- erlaubt nur wenn:
  1) maintenanceEnabled == true
  2) sectionAccess['debug'] == true

user:
- niemals erlaubt

WICHTIG:
- Sichtbarkeit (Navigation/Badge) darf nur erfolgen,
  wenn Zugriff serverseitig erlaubt ist.
- Keine clientseitige Logik darf Debug sichtbar machen,
  wenn Server es verbietet.

## Admin-Module allgemein

Ein Admin-Modul ist nur zugänglich wenn:
- superadmin → immer
- andere Rollen → sectionAccess[modul] == true

Debug hat zusätzlich das maintenanceEnabled-Gate.

# ---------------------------------------------------------------------------
# DEBUG-TRENNUNG (VERBINDLICH)
# ---------------------------------------------------------------------------

Es existieren zwei unterschiedliche Debug-Konzepte:

## 1) Admin-Debug
- Route: routes/web/admin/debug.php
- Unterliegt Access-Matrix
- Teil der Admin-UI

## 2) System-/Infra-Debug
- Route: routes/web/debug_system.php
- Kein Bestandteil der Admin-Navigation
- Darf niemals über Admin-Badges oder Section-Access gesteuert werden
- Dient Diagnose bei Admin-Ausfall
- Separate serverseitige Zugriffskontrolle

Diese Konzepte dürfen nicht vermischt werden.

# ---------------------------------------------------------------------------
# BREAK-GLASS / GLASFUGE (VERBINDLICH)
# ---------------------------------------------------------------------------

Es existiert ein serverseitiger Notfallzugang (Break-Glass / Glasfuge).

Zweck:
- Notfallzugriff bei fehlerhafter Rollen-/Section-Konfiguration
- Notfallzugriff bei Maintenance-Deadlock
- Notfallzugriff bei Settings- oder DB-Problemen

Regeln:

- Break-Glass ist kein normales Admin-Feature.
- Break-Glass ist kein Ersatz für die Access-Matrix.
- Break-Glass darf niemals über UI-Sichtbarkeit gesteuert werden.
- Break-Glass darf niemals durch JavaScript aktiviert werden.
- Break-Glass darf nicht in normale Section-Logik integriert werden.
- Break-Glass darf nur serverseitig implementiert sein.
- Break-Glass darf ausschließlich für superadmin gelten.
- Break-Glass muss auditierbar sein.
- Break-Glass darf nicht durch Refactoring “vereinfacht” oder “zusammengelegt” werden.

Break-Glass und System-Debug sind getrennte Konzepte.

# ---------------------------------------------------------------------------
# SINGLE SOURCE OF TRUTH (SSOT)
# ---------------------------------------------------------------------------

Zugriffskontrolle:
- Middleware oder zentrale Access-Klasse

UI-Sichtbarkeit:
- Muss auf denselben serverseitigen Flags basieren
- Keine zweite Entscheidungslogik im Blade
- Keine zweite Entscheidungslogik im JavaScript

Polling:
- status.php liefert nur serverseitige Wahrheit
- JavaScript rendert nur
- JavaScript entscheidet niemals eigenständig über Zugriff

# ---------------------------------------------------------------------------
# STATUS-CONTRACT (VERBINDLICH)
# ---------------------------------------------------------------------------

routes/web/admin/status.php darf nur serverseitig berechnete,
finale Flags liefern.

Beispielstruktur:

- maintenance_enabled: bool
- debug_allowed: bool (bereits final berechnet!)
- sections_allowed: { section: bool }

Client darf debug_allowed nicht reinterpretieren.

# ---------------------------------------------------------------------------
# LARAVEL-SPEZIFISCH
# ---------------------------------------------------------------------------

- Events nur mit expliziten Listenern.
- Registrierung im EventServiceProvider.
- Middleware-Registrierung gemäß Projektstruktur (Laravel 12: bootstrap/app.php).
- Keine Logik-Verschiebung von Controller in Blade.
- Keine stillen Änderungen an Guards oder Auth-Konfiguration.

# ---------------------------------------------------------------------------
# FAILSAFE & SYSTEMSTABILITÄT
# ---------------------------------------------------------------------------

- FileSafe-Mechanismen dürfen nicht umgangen werden.
- Bei DB-Down-Szenarien:
  - Keine zusätzlichen Fehlerquellen einbauen.
  - Keine direkte DB-Logik in Views oder Layouts.
- Keine Änderungen, die Audit-Tool-Determinismus brechen.
- Keine stillen Änderungen an Log-Rotation oder Audit-Checks.

# ---------------------------------------------------------------------------
# CSS / JS / BLADE
# ---------------------------------------------------------------------------

- Inline-Scripts vermeiden.
- Inline-Styles vermeiden.
- Admin-JS zentralisieren (z. B. resources/js/admin.js).
- Keine sicherheitsrelevante Logik in JavaScript.
- Blade dient nur zur Darstellung, nicht zur Geschäftslogik.

# ---------------------------------------------------------------------------
# IMPACT-HINWEIS (PFLICHT)
# ---------------------------------------------------------------------------

Vor Umsetzung größerer Änderungen muss angegeben werden:

- Welche Bereiche potenziell betroffen sind.
- Ob Middleware, Audit-Tool oder Rollenlogik beeinflusst werden könnten.
- Ob Wartungs-/Debug-Mechanismen betroffen sind.