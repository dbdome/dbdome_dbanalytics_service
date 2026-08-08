<#
.SYNOPSIS
    Versioned build of the DBDOME service and, in lockstep, the two installers.

.DESCRIPTION
    The one entry point for producing a shippable DBDOME build. It asks for the
    build number (pre-filling last+1 from config.app_version), stamps it into
    the binaries, builds, and records the build in the version table.

    Version format is 2.01.<Build_No>: MAJOR/MINOR come from utils/version.py
    and change only on a product decision; Build_No is what you type here.

    Steps:
      1. read the last build from config.app_version, prompt for Build_No + notes
      2. write utils/version_build.json  (bundled into the exe by the spec)
      3. PyInstaller -> dist_rd  (service: dbdome_dbanalytics + dbdome_service)
      4. PyInstaller -> the setup and update installers, both reading the same stamp
      5. sign the two installers, if signtool + the dbdome cert are available
      6. record the build in config.app_version for all three components

    Deployment is deliberately NOT part of this: build here, then run the
    deploy step so a build can be inspected before it reaches a bin.

.PARAMETER BuildNo
    Skip the prompt and use this number (for scripted/CI runs).

.PARAMETER Notes
    Skip the notes prompt.

.PARAMETER SkipInstallers
    Build only the service.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -BuildNo 44 -Notes "LDAP transport diagnosis"
#>
[CmdletBinding()]
param(
    [int]    $BuildNo,
    [string] $Notes,
    [switch] $SkipInstallers,
    [switch] $SkipService
)

$ErrorActionPreference = 'Stop'
$RepoRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python     = 'C:\apps\venv314\Scripts\python.exe'   # MUST be this venv - see below
$SetupRepo  = 'C:\dev\dbdome_setup'
$UpdateRepo = 'C:\dev\dbdome_update'
$StampFile  = Join-Path $RepoRoot 'utils\version_build.json'

# The bare Python 3.14 install is missing reportlab/matplotlib/scipy and yields a
# broken ~18 MB bundle that dies at runtime on `import reportlab`. A good build
# is ~39 MB per exe.
if (-not (Test-Path $Python)) { throw "build venv not found: $Python" }

function Invoke-Native {
    <# Run a native exe and return its exit code, capturing both streams to a log.

       NOT `& exe ... 2>&1 | Out-File`: in Windows PowerShell 5.1 that wraps every
       stderr line in a NativeCommandError, which under $ErrorActionPreference='Stop'
       kills the build on nothing worse than a deprecation notice. PyInstaller
       prints one of those ("running as admin is not necessary") on every
       elevated run. Start-Process keeps the streams as plain text. #>
    param([string]$FilePath, [string[]]$Arguments, [string]$Log, [string]$WorkDir)

    $err = "$Log.err"
    $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $WorkDir `
                       -NoNewWindow -Wait -PassThru `
                       -RedirectStandardOutput $Log -RedirectStandardError $err
    if (Test-Path $err) {
        Get-Content $err | Add-Content -Path $Log
        Remove-Item $err -Force
    }
    return $p.ExitCode
}

function Get-DbVersionInfo {
    <# Ask the DB for the last build. Returns $null when the DB is unreachable
       (a fresh dev box), so the build can still proceed. #>
    $q = @'
import sys
sys.path.insert(0, r"{0}")
import json
try:
    import psycopg2
    from utils.config_dotenv import get_connection_string
    with psycopg2.connect(get_connection_string()) as c:
        with c.cursor() as cur:
            cur.execute("SELECT config.next_build_no('service')")
            nxt = cur.fetchone()[0]
            cur.execute("SELECT version, to_char(built_at,'YYYY-MM-DD HH24:MI'), coalesce(notes,'') "
                        "FROM config.app_version WHERE component='service' AND is_current")
            row = cur.fetchone()
    print(json.dumps({{"next": nxt, "last": row[0] if row else None,
                       "at": row[1] if row else None, "notes": row[2] if row else None}}))
except Exception as e:
    print(json.dumps({{"error": str(e)}}))
'@ -f $RepoRoot
    $tmp = Join-Path $env:TEMP "dbdome_ver_probe.py"
    Set-Content -Path $tmp -Value $q -Encoding utf8
    try { $out = & $Python $tmp 2>$null } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    if (-not $out) { return $null }
    try { return $out | ConvertFrom-Json } catch { return $null }
}

Write-Host "`n=== DBDOME versioned build ===" -ForegroundColor Cyan

$info = Get-DbVersionInfo
$next = 1
if ($info -and -not $info.error) {
    if ($info.last) { Write-Host ("  Last build: {0}  ({1})" -f $info.last, $info.at) }
    if ($info.notes) { Write-Host ("              {0}" -f $info.notes) -ForegroundColor DarkGray }
    $next = [int]$info.next
} elseif ($info -and $info.error) {
    Write-Host "  (version table unreachable: $($info.error))" -ForegroundColor Yellow
    Write-Host "  (7440_app_version.sql may not be applied yet)" -ForegroundColor Yellow
}

if (-not $PSBoundParameters.ContainsKey('BuildNo')) {
    $ans = Read-Host ("  Build_No [{0:D3}]" -f $next)
    if ([string]::IsNullOrWhiteSpace($ans)) { $BuildNo = $next }
    elseif ($ans -match '^\d+$')            { $BuildNo = [int]$ans }
    else { throw "Build_No must be a number, got '$ans'" }
}
if (-not $PSBoundParameters.ContainsKey('Notes')) {
    $Notes = Read-Host "  Notes    "
}

# MAJOR/MINOR are owned by utils/version.py - never duplicated here.
$major = (& $Python -c "import sys;sys.path.insert(0,r'$RepoRoot');from utils import version;print(version.VERSION_MAJOR)").Trim()
$minor = (& $Python -c "import sys;sys.path.insert(0,r'$RepoRoot');from utils import version;print(version.VERSION_MINOR)").Trim()
$versionString = "{0}.{1:D2}.{2:D3}" -f [int]$major, [int]$minor, $BuildNo

Write-Host "`n  -> building $versionString" -ForegroundColor Green

# ---------------------------------------------------------------- stamp
# Written WITHOUT a BOM: Set-Content -Encoding utf8 on PS 5.1 emits EF BB BF, and
# json.load() rejects that outright - which silently degraded stamped builds to
# 000. utils/version.py reads utf-8-sig defensively, but do not create the problem.
$stampJson = @{
    build_no = $BuildNo
    version  = $versionString
    built_by = $env:USERNAME
    built_at = (Get-Date).ToString('s')
    notes    = $Notes
} | ConvertTo-Json
[IO.File]::WriteAllText($StampFile, $stampJson, (New-Object Text.UTF8Encoding($false)))
Write-Host "  stamp: $StampFile"

# ---------------------------------------------------------------- service
if ($SkipService) { Write-Host "`n[1/3] service - skipped" -ForegroundColor DarkGray }
else {
Write-Host "`n[1/3] service (PyInstaller, ~8 min)" -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    $log = Join-Path $RepoRoot "build_rd_$versionString.log"
    $rc = Invoke-Native -FilePath $Python -WorkDir $RepoRoot -Log $log -Arguments @(
        '-m', 'PyInstaller', '--clean', '--noconfirm',
        '--distpath', 'dist_rd', '--workpath', 'build_rd', 'DBDOME_dbanalytics.spec')
    if ($rc -ne 0) { throw "service build failed (exit $rc), see $log" }
    foreach ($e in @('dbdome_dbanalytics.exe', 'dbdome_service.exe')) {
        $f = Get-Item (Join-Path $RepoRoot "dist_rd\dbdome_dbanalytics\$e")
        $mb = [math]::Round($f.Length / 1MB, 1)
        if ($mb -lt 30) { throw "$e is only $mb MB - wrong venv (missing reportlab et al)" }
        Write-Host ("      {0}  {1} MB" -f $e, $mb)
    }
} finally { Pop-Location }
}

# ---------------------------------------------------------------- installers
if (-not $SkipInstallers) {
    foreach ($pair in @(@{Repo = $SetupRepo; Spec = 'setup.spec'; Name = 'dbdome_setup' },
                        @{Repo = $UpdateRepo; Spec = 'update.spec'; Name = 'dbdome_update' })) {
        Write-Host "`n[2/3] $($pair.Name)" -ForegroundColor Cyan
        if (-not (Test-Path $pair.Repo)) { Write-Host "      missing $($pair.Repo) - skipped" -ForegroundColor Yellow; continue }
        # the installers read the same stamp, so all three report one version
        Copy-Item $StampFile (Join-Path $pair.Repo 'version_build.json') -Force
        Push-Location $pair.Repo
        try {
            $ilog = Join-Path $pair.Repo "build_$versionString.log"
            $rc = Invoke-Native -FilePath $Python -WorkDir $pair.Repo -Log $ilog `
                    -Arguments @('-m', 'PyInstaller', '--clean', '--noconfirm', $pair.Spec)
            if ($rc -ne 0) { throw "$($pair.Name) build failed (exit $rc), see $ilog" }
            $exe = Join-Path $pair.Repo "dist\$($pair.Name).exe"
            Write-Host ("      {0}  {1} MB" -f (Split-Path $exe -Leaf), [math]::Round((Get-Item $exe).Length / 1MB, 1))
        } finally { Pop-Location }
    }

    # ------------------------------------------------------------ sign
    # Signing uses the dbdome PFX. The password is read from the environment on
    # purpose - this script is in git, and the password must not be.
    #   $env:DBDOME_CERT_PASSWORD = '...'     (set it once per shell)
    #   $env:DBDOME_CERT_PFX      = '...'     (optional, overrides the default)
    $signTool = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Filter signtool.exe -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like '*x64*' } | Sort-Object FullName -Descending | Select-Object -First 1
    $pfx = if ($env:DBDOME_CERT_PFX) { $env:DBDOME_CERT_PFX }
           else { Join-Path $RepoRoot 'certification\dbdome_cert.pfx' }
    $pfxPw = $env:DBDOME_CERT_PASSWORD

    if (-not $signTool) {
        Write-Host "      signtool.exe not found - installers left UNSIGNED" -ForegroundColor Yellow
    } elseif (-not (Test-Path $pfx)) {
        Write-Host "      $pfx not found - installers left UNSIGNED" -ForegroundColor Yellow
    } elseif (-not $pfxPw) {
        Write-Host "      DBDOME_CERT_PASSWORD not set - installers left UNSIGNED" -ForegroundColor Yellow
        Write-Host '      set it with:  $env:DBDOME_CERT_PASSWORD = "..."' -ForegroundColor Yellow
    } else {
        foreach ($exe in @("$SetupRepo\dist\dbdome_setup.exe", "$UpdateRepo\dist\dbdome_update.exe")) {
            if (-not (Test-Path $exe)) { continue }
            $slog = Join-Path $env:TEMP "dbdome_signtool.log"
            $rc = Invoke-Native -FilePath $signTool.FullName -WorkDir $env:TEMP -Log $slog -Arguments @(
                'sign', '/f', $pfx, '/p', $pfxPw,
                '/tr', 'http://timestamp.digicert.com', '/td', 'SHA256', '/fd', 'SHA256', $exe)
            $st = (Get-AuthenticodeSignature $exe).Status
            Write-Host ("      signed {0}: exit={1} status={2}" -f (Split-Path $exe -Leaf), $rc, $st)
        }
        Remove-Item (Join-Path $env:TEMP "dbdome_signtool.log") -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------- record
Write-Host "`n[3/3] recording $versionString in config.app_version" -ForegroundColor Cyan
$components = @()
if (-not $SkipService)    { $components += 'service' }
if (-not $SkipInstallers) { $components += 'setup', 'update' }
$compLiteral = '[' + (($components | ForEach-Object { "'$_'" }) -join ',') + ']'
$rec = @"
import sys
sys.path.insert(0, r"$RepoRoot")
import psycopg2
from utils.config_dotenv import get_connection_string
try:
    with psycopg2.connect(get_connection_string()) as c:
        with c.cursor() as cur:
            for comp in ${compLiteral}:
                cur.execute("SELECT config.set_version(%s,%s,%s,%s,%s,%s)",
                            ($major, $minor, $BuildNo, r"$env:USERNAME", r"$Notes", comp))
                print("   registered", cur.fetchone()[0], comp)
except Exception as e:
    print("   could not record in config.app_version:", e)
"@
$tmp = Join-Path $env:TEMP "dbdome_ver_record.py"
Set-Content -Path $tmp -Value $rec -Encoding utf8
try { & $Python $tmp } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== $versionString built ===" -ForegroundColor Green
Write-Host "  service   : $RepoRoot\dist_rd\dbdome_dbanalytics\"
if (-not $SkipInstallers) {
    Write-Host "  installers: $SetupRepo\dist\, $UpdateRepo\dist\"
}
Write-Host "  next      : deploy to the bins, refresh the media, rebuild the ISOs`n"
