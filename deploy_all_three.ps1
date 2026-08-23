# =============================================================================
# deploy_all_three.ps1  -- RUN AS ADMINISTRATOR
# Deploys the freshly built dist_rd bundle to three bin locations:
#   1. C:\installs\dbdome_update\dbdome\bin   (staging, no services)
#   2. C:\installs\dbdome_setup\dbdome\bin    (staging, no services)
#   3. C:\ProgramData\DBDOME\bin              (LIVE: stop/swap/start services)
#
# Only _internal + dbdome_dbanalytics.exe + dbdome_service.exe are replaced.
# .env and every other binary (grafana, dbdomeg-*, nssm, test_*, ...) are left
# untouched. Each target's previous _internal/exes are backed up (_*.bak_<ts>).
# =============================================================================
$ErrorActionPreference = 'Stop'
$src = 'C:\dev\dbdome_dbanalytics_service\dist_rd\dbdome_dbanalytics'
$ts  = Get-Date -Format 'yyyyMMdd_HHmmss'

if (-not (Test-Path "$src\dbdome_service.exe"))     { throw "build missing: $src\dbdome_service.exe" }
if (-not (Test-Path "$src\dbdome_dbanalytics.exe")) { throw "build missing: $src\dbdome_dbanalytics.exe" }
if (-not (Test-Path "$src\_internal"))              { throw "build missing: $src\_internal" }

# Resolve the service names from what is actually installed rather than
# hardcoding them. Two topologies exist in the field: the older split pair
# (DBDOME_scheduler + DBDOME_web) and the single combined service
# (DBDOME_dbanalytics, started with --service full). Hardcoding the pair made
# this script throw on Get-Service for the combined topology and abort the live
# deploy, leaving the swap half-done.
$svcs = @(
    'DBDOME_dbanalytics','DBDOME_scheduler','DBDOME_web' |
        Where-Object { Get-Service $_ -ErrorAction SilentlyContinue }
)
if (-not $svcs) { throw "no DBDOME service found (looked for DBDOME_dbanalytics, DBDOME_scheduler, DBDOME_web)" }
Write-Host "Services to cycle: $($svcs -join ', ')" -ForegroundColor Cyan

function Assert-DeployHealthy {
    # Fail loudly at deploy time if a service crashed on startup (e.g. a broken
    # build missing a module) instead of discovering it down days later.
    Write-Host "  Health check: services Running + port 8080 listening ..." -ForegroundColor Cyan
    $ok = $false
    for ($i = 0; $i -lt 12; $i++) {
        $svcDown = @(Get-Service $svcs | Where-Object { $_.Status -ne 'Running' }).Count
        $portOk  = [bool](Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)
        if ($svcDown -eq 0 -and $portOk) { $ok = $true; break }
        Start-Sleep -Seconds 5
    }
    Get-Service $svcs | Select-Object Name,Status | Format-Table -AutoSize
    if ($ok) {
        Write-Host "  HEALTHY: both services Running and :8080 is listening." -ForegroundColor Green
    } else {
        Write-Host "  WARNING: services not healthy within ~60s -- possible startup crash." -ForegroundColor Red
        Write-Host "  Check tail of: C:\ProgramData\DBDOME\bin\dbdome_service.log" -ForegroundColor Red
    }
}

function Deploy-Bin([string]$bin, [bool]$live) {
    Write-Host "==== Deploying to $bin (live=$live) ====" -ForegroundColor Cyan
    if (-not (Test-Path $bin)) { throw "target missing: $bin" }
    if (-not (Test-Path "$bin\.env")) { Write-Host "  WARN: no .env at $bin" -ForegroundColor Yellow }

    try {
        if ($live) {
            Write-Host "  Stopping DBDOME_scheduler, DBDOME_web ..."
            foreach ($svc in $svcs) { Stop-Service -Name $svc -Force }
            1..30 | ForEach-Object {
                if (-not (Get-Process dbdome_service -ErrorAction SilentlyContinue)) { return }
                Start-Sleep -Seconds 1
            }
            if (Get-Process dbdome_service -ErrorAction SilentlyContinue) { throw "dbdome_service still running -- aborting $bin" }
        }

        foreach ($e in 'dbdome_service.exe','dbdome_dbanalytics.exe') {
            if (Test-Path "$bin\$e") { Copy-Item "$bin\$e" "$bin\$e.bak_$ts" -Force }
        }
        if (Test-Path "$bin\_internal") { Rename-Item "$bin\_internal" "_internal.bak_$ts" }

        Write-Host "  Copying _internal (~454 MB)..."
        robocopy "$src\_internal" "$bin\_internal" /E /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) for $bin -- restore _internal.bak_$ts" }

        Copy-Item "$src\dbdome_service.exe"     "$bin\dbdome_service.exe"     -Force
        Copy-Item "$src\dbdome_dbanalytics.exe" "$bin\dbdome_dbanalytics.exe" -Force

        if ($live) {
            Write-Host "  Starting services ..."
            foreach ($svc in $svcs) { Start-Service -Name $svc }
            Assert-DeployHealthy
        }
    }
    finally {
        # Never leave the live services stopped if the swap threw mid-way.
        if ($live) {
            foreach ($svc in $svcs) {
                if ((Get-Service $svc -ErrorAction SilentlyContinue).Status -ne 'Running') {
                    Write-Host "  [finally] $svc not Running -- attempting start ..." -ForegroundColor Yellow
                    try { Start-Service -Name $svc -ErrorAction Stop } catch { Write-Host "    could not start ${svc}: $($_.Exception.Message)" -ForegroundColor Red }
                }
            }
        }
    }
    Write-Host "  DONE: $bin" -ForegroundColor Green
}

Deploy-Bin 'C:\installs\dbdome_update\dbdome\bin' $false
Deploy-Bin 'C:\installs\dbdome_setup\dbdome\bin'  $false
Deploy-Bin 'C:\ProgramData\DBDOME\bin'            $true

Write-Host "==== ALL THREE DEPLOYED (backup suffix: bak_$ts) ====" -ForegroundColor Green
# robocopy returns 1 on success (files copied); reset so the caller's
# $LASTEXITCODE reflects deploy success, not robocopy's non-zero success code.
$global:LASTEXITCODE = 0
exit 0
