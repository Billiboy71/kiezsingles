# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\ks-role-db-check.ps1
# Purpose: DB-side role/account diagnostics for RoleSmokeTest preparation
# Created: 12-03-2026 21:05 (Europe/Berlin)
# Changed: 12-03-2026 21:43 (Europe/Berlin)
# Version: 0.2
# =============================================================================

[CmdletBinding()]
param(
    [string]$ProjectRoot = "C:\laragon\www\kiezsingles",
    [string[]]$Emails = @(
        "steffen.stephan@icloud.com",
        "admin@web.de",
        "moderator@web.de"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
try { [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false) } catch { }

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Title
    Write-Host ("=" * 78)
}

function ConvertTo-QuotedArgWindows([string]$s) {
    if ($null -eq $s) { return '""' }

    $t = "" + $s
    if ($t -eq "") { return '""' }

    if ($t -match '[\s"]') {
        $t = $t -replace '(\\*)"', '$1$1\"'
        $t = $t -replace '(\\+)$', '$1$1'
        return '"' + $t + '"'
    }

    return $t
}

function Invoke-ProcessToFiles(
    [string]$File,
    [string[]]$ArgumentList,
    [int]$TimeoutSeconds = 120,
    [string]$WorkingDirectory = ""
) {
    $stdout = ""
    $stderr = ""

    try {
        if ($null -eq $ArgumentList) { $ArgumentList = @() }
        $ArgumentList = @($ArgumentList | Where-Object { $_ -ne $null })

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = ("" + $File)

        $quotedArgs = @()
        foreach ($a in $ArgumentList) {
            $quotedArgs += (ConvertTo-QuotedArgWindows ("" + $a))
        }
        $psi.Arguments = ($quotedArgs -join " ")

        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        if ($WorkingDirectory -and ($WorkingDirectory.Trim() -ne "")) {
            $psi.WorkingDirectory = $WorkingDirectory
        }

        try { $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
        try { $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8 } catch { }

        $p = [System.Diagnostics.Process]::new()
        $p.StartInfo = $psi

        $null = $p.Start()

        try {
            $p.StandardInput.Write("")
            $p.StandardInput.Close()
        } catch { }

        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()

        $exited = $p.WaitForExit($TimeoutSeconds * 1000)

        if (-not $exited) {
            try { $p.Kill($true) } catch { }

            try { $stdout = $outTask.GetAwaiter().GetResult() } catch { $stdout = "" }
            try { $stderr = $errTask.GetAwaiter().GetResult() } catch { $stderr = "" }

            $argString = ($ArgumentList -join " ")
            return [pscustomobject]@{
                ExitCode = -1
                StdOut   = $stdout
                StdErr   = ("TIMEOUT after {0}s while running: {1} {2}" -f $TimeoutSeconds, $File, $argString) + "`n" + $stderr
            }
        }

        try { $p.WaitForExit() } catch { }

        try { $stdout = $outTask.GetAwaiter().GetResult() } catch { $stdout = "" }
        try { $stderr = $errTask.GetAwaiter().GetResult() } catch { $stderr = "" }

        $exitCode = 0
        try { $exitCode = [int]$p.ExitCode } catch { $exitCode = 0 }

        return [pscustomobject]@{
            ExitCode = [int]$exitCode
            StdOut   = $stdout
            StdErr   = $stderr
        }
    } catch {
        $msg = ""
        try { $msg = $_.Exception.Message } catch { $msg = "unknown_error" }

        return [pscustomobject]@{
            ExitCode = 2
            StdOut   = ""
            StdErr   = ("PROCESS RUNNER ERROR: " + $msg)
        }
    }
}

function Resolve-PHPExePath {
    try {
        $exe = $null

        try {
            $paths = ("" + $env:PATH).Split(";") | Where-Object { $_ -and ("" + $_).Trim() -ne "" }
            foreach ($p in $paths) {
                $candidate = Join-Path ($p.Trim()) "php.exe"
                if (Test-Path -LiteralPath $candidate) {
                    $exe = $candidate
                    break
                }
            }
        } catch { }

        if ($exe -and (("" + $exe).Trim() -ne "")) {
            return ("" + $exe).Trim()
        }

        try {
            $phpApp = Get-Command php -All -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandType -eq "Application" } |
                Select-Object -First 1

            if ($phpApp -and $phpApp.Source -and ("" + $phpApp.Source).Trim() -ne "") {
                return ("" + $phpApp.Source).Trim()
            }
        } catch { }

        return "php"
    } catch {
        return "php"
    }
}

function Invoke-PHPArtisan([string]$Root, [string[]]$ArgumentList, [int]$TimeoutSeconds = 120) {
    $php = Resolve-PHPExePath
    $artisan = Join-Path $Root "artisan"

    if (-not (Test-Path -LiteralPath $artisan -PathType Leaf)) {
        throw "artisan not found: $artisan"
    }

    if ($null -eq $ArgumentList) { $ArgumentList = @() }

    $cmdArgs = @()
    $cmdArgs += $artisan
    $cmdArgs += $ArgumentList
    $cmdArgs = @($cmdArgs | Where-Object { $_ -ne $null })

    return Invoke-ProcessToFiles -File $php -ArgumentList $cmdArgs -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $Root
}

function ConvertTo-NormalizedEmailArray([string[]]$InputEmails) {
    $out = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    foreach ($raw in @($InputEmails)) {
        if ($null -eq $raw) { continue }

        $parts = @()
        $s = ("" + $raw).Trim()
        if ($s -eq "") { continue }

        if ($s -match ",") {
            try { $parts = @($s -split ",") } catch { $parts = @($s) }
        } else {
            $parts = @($s)
        }

        foreach ($part in @($parts)) {
            $email = ("" + $part).Trim()
            $email = $email.Trim('"').Trim("'")
            if ($email -eq "") { continue }
            if ($seen.ContainsKey($email.ToLowerInvariant())) { continue }
            $seen[$email.ToLowerInvariant()] = $true
            $out.Add($email) | Out-Null
        }
    }

    return @($out.ToArray())
}

function ConvertTo-PhpSingleQuotedString([string]$Value) {
    $s = "" + $Value
    $s = $s -replace '\\', '\\\\'
    $s = $s -replace "'", "\\'"
    return ("'" + $s + "'")
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "ProjectRoot not found: $ProjectRoot"
}

$artisanPath = Join-Path $ProjectRoot "artisan"
if (-not (Test-Path -LiteralPath $artisanPath -PathType Leaf)) {
    throw "Laravel artisan not found: $artisanPath"
}

$emailsClean = @(ConvertTo-NormalizedEmailArray -InputEmails $Emails)
if ($emailsClean.Count -le 0) {
    throw "No emails provided."
}

Write-Section "KiezSingles Role/DB Check"
Write-Host ("ProjectRoot: " + $ProjectRoot)
Write-Host ("Emails:      " + (($emailsClean | ForEach-Object { "" + $_ }) -join ", "))

$phpEmailsArray = "array(" + (($emailsClean | ForEach-Object { ConvertTo-PhpSingleQuotedString $_ }) -join ", ") + ")"

$phpCode = @"
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

`$emails = $phpEmailsArray;

function ks_cols(`$table) {
    try {
        if (!Schema::hasTable(`$table)) { return []; }
        return Schema::getColumnListing(`$table);
    } catch (Throwable `$e) {
        return [];
    }
}

function ks_pick(`$row, `$cols) {
    `$out = [];
    if (!`$row) { return `$out; }
    foreach (`$cols as `$c) {
        if (is_object(`$row) && property_exists(`$row, `$c)) {
            `$out[`$c] = `$row->`$c;
        }
    }
    return `$out;
}

`$result = [
    'db_default' => config('database.default'),
    'tables' => [],
    'users' => [],
    'roles' => [],
];

`$candidateTables = [
    'users',
    'roles',
    'role_user',
    'user_roles',
    'model_has_roles',
    'permissions',
    'role_has_permissions',
];

foreach (`$candidateTables as `$t) {
    `$result['tables'][`$t] = [
        'exists' => Schema::hasTable(`$t),
        'columns' => ks_cols(`$t),
    ];
}

`$userColsWanted = [
    'id',
    'public_id',
    'name',
    'email',
    'username',
    'email_verified_at',
    'is_active',
    'is_blocked',
    'blocked_at',
    'status',
    'deleted_at',
    'is_protected_admin',
    'is_frozen',
    'banned_at',
    'moderator_sections',
    'created_at',
    'updated_at',
];

if (Schema::hasTable('users')) {
    foreach (`$emails as `$email) {
        `$row = DB::table('users')->where('email', `$email)->first();
        `$result['users'][`$email] = [
            'found' => !!`$row,
            'data' => ks_pick(`$row, `$userColsWanted),
        ];
    }
}

if (Schema::hasTable('roles') && Schema::hasTable('role_user') && Schema::hasTable('users')) {
    foreach (`$emails as `$email) {
        `$user = DB::table('users')->where('email', `$email)->first();

        `$roles = [];
        if (`$user && property_exists(`$user, 'id')) {
            try {
                `$roles = DB::table('role_user')
                    ->join('roles', 'roles.id', '=', 'role_user.role_id')
                    ->where('role_user.user_id', `$user->id)
                    ->select('roles.id', 'roles.name')
                    ->get()
                    ->map(function (`$r) { return ['id' => `$r->id, 'name' => `$r->name]; })
                    ->values()
                    ->all();
            } catch (Throwable `$e) {
                `$roles = ['_error' => `$e->getMessage()];
            }
        }

        `$result['roles'][`$email]['roles_role_user'] = `$roles;
    }
}

if (Schema::hasTable('roles') && Schema::hasTable('user_roles') && Schema::hasTable('users')) {
    foreach (`$emails as `$email) {
        `$user = DB::table('users')->where('email', `$email)->first();

        `$roles = [];
        if (`$user && property_exists(`$user, 'id')) {
            try {
                `$roles = DB::table('user_roles')
                    ->join('roles', 'roles.id', '=', 'user_roles.role_id')
                    ->where('user_roles.user_id', `$user->id)
                    ->select('roles.id', 'roles.name')
                    ->get()
                    ->map(function (`$r) { return ['id' => `$r->id, 'name' => `$r->name]; })
                    ->values()
                    ->all();
            } catch (Throwable `$e) {
                `$roles = ['_error' => `$e->getMessage()];
            }
        }

        `$result['roles'][`$email]['roles_user_roles'] = `$roles;
    }
}

if (Schema::hasTable('roles') && Schema::hasTable('model_has_roles') && Schema::hasTable('users')) {
    foreach (`$emails as `$email) {
        `$user = DB::table('users')->where('email', `$email)->first();

        `$roles = [];
        if (`$user && property_exists(`$user, 'id')) {
            try {
                `$roles = DB::table('model_has_roles')
                    ->join('roles', 'roles.id', '=', 'model_has_roles.role_id')
                    ->where('model_has_roles.model_id', `$user->id)
                    ->select('roles.id', 'roles.name', 'model_has_roles.model_type')
                    ->get()
                    ->map(function (`$r) {
                        return [
                            'id' => `$r->id,
                            'name' => `$r->name,
                            'model_type' => `$r->model_type,
                        ];
                    })
                    ->values()
                    ->all();
            } catch (Throwable `$e) {
                `$roles = ['_error' => `$e->getMessage()];
            }
        }

        `$result['roles'][`$email]['roles_model_has_roles'] = `$roles;
    }
}

echo json_encode(`$result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
"@

Write-Section "Running artisan tinker DB diagnostic"

$proc = Invoke-PHPArtisan -Root $ProjectRoot -ArgumentList @("tinker", "--execute=$phpCode") -TimeoutSeconds 180

if ($proc.StdErr -and $proc.StdErr.Trim() -ne "") {
    Write-Section "STDERR"
    Write-Host $proc.StdErr.Trim()
}

if ($proc.StdOut -and $proc.StdOut.Trim() -ne "") {
    Write-Section "DB Result"
    Write-Host $proc.StdOut.Trim()
} else {
    Write-Section "DB Result"
    Write-Host "(no stdout)"
}

Write-Section "Exit"
Write-Host ("ExitCode: " + $proc.ExitCode)

exit $proc.ExitCode