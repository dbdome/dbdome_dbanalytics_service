# =============================================================================
# deploy_redeploy.ps1  -- RUN AS ADMINISTRATOR
# Deploys the freshly built DBDOME bundle (with the sensitive-list injection
# hook + 6130-6170 migrations) to C:\ProgramData\DBDOME\bin.
#
# Safe: backs up the current exes and _internal first (rollback below), and
# never touches the live bin\.env (top-level), which holds the real keys.
# =============================================================================
param(
    # Services to stop for the file swap but deliberately NOT restart afterwards.
    # A service holding a lock still has to come down or the swap fails; this is
    # about what comes back UP. Anything listed here is also excluded from the
    # health check, which would otherwise always warn about it.
    [string[]]$LeaveStopped = @()
)

$ErrorActionPreference = 'Stop'
$src = 'C:\dev\dbdome_dbanalytics_service\dist_rd\dbdome_dbanalytics'
$bin = 'C:\ProgramData\DBDOME\bin'
$ts  = Get-Date -Format 'yyyyMMdd_HHmmss'

# sanity
if (-not (Test-Path "$src\dbdome_service.exe")) { throw "new build not found at $src" }
if (-not (Test-Path "$bin\.env"))               { throw "live $bin\.env missing -- aborting" }

# DISCOVERED, not hardcoded. The service layout differs per box: this dev box was
# consolidated to a single DBDOME_dbanalytics (--service full), while 213 still runs
# the split pair. The old hardcoded 'DBDOME_scheduler','DBDOME_web' aborted the whole
# deploy here on its first Stop-Service, because $ErrorActionPreference='Stop' turns a
# missing service into a terminating error -- before anything was backed up.
# Grafana and Ollama are deliberately NOT touched: they serve other things and do not
# hold a lock on the files being swapped.
$svcs = @(Get-Service -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -in @('DBDOME_scheduler','DBDOME_web','DBDOME_dbanalytics') } |
          Select-Object -ExpandProperty Name)
if (-not $svcs) { throw "no DBDOME service found (looked for DBDOME_scheduler / DBDOME_web / DBDOME_dbanalytics)" }
Write-Host "Services this box actually has: $($svcs -join ', ')" -ForegroundColor Cyan

# Stopped for the swap, restarted afterwards. $LeaveStopped members are stopped but
# not brought back up, and are excluded from the health check.
$startSvcs = @($svcs | Where-Object { $LeaveStopped -notcontains $_ })
if ($LeaveStopped) {
    Write-Host "Will NOT restart: $($LeaveStopped -join ', ')" -ForegroundColor Yellow
}
if (-not $startSvcs) {
    Write-Host "Nothing will be restarted - every discovered service is in -LeaveStopped." -ForegroundColor Yellow
}

function Assert-DeployHealthy {
    # Fail loudly at deploy time if a service crashed on startup (e.g. a broken
    # build missing a module) instead of discovering it down days later.
    Write-Host "== Health check: services Running + port 8080 listening ==" -ForegroundColor Cyan
    $ok = $false
    for ($i = 0; $i -lt 12; $i++) {
        $svcDown = @(Get-Service $startSvcs | Where-Object { $_.Status -ne 'Running' }).Count
        $portOk  = [bool](Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)
        if ($svcDown -eq 0 -and $portOk) { $ok = $true; break }
        Start-Sleep -Seconds 5
    }
    Get-Service $svcs | Select-Object Name,Status | Format-Table -AutoSize   # show ALL, including the intentionally-stopped
    if ($ok) {
        Write-Host "  HEALTHY: every service that should be Running is, and :8080 is listening." -ForegroundColor Green
    } else {
        Write-Host "  WARNING: services did not become healthy within ~60s." -ForegroundColor Red
        Write-Host "  A service may have crashed on startup (broken build / missing module)." -ForegroundColor Red
        Write-Host "  Check the tail of: $bin\dbdome_service.log" -ForegroundColor Red
    }
}

try {
    Write-Host "== Stopping services ==" -ForegroundColor Cyan
    foreach ($svc in $svcs) { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue }

    # wait for the exe to release file locks
    Write-Host "== Waiting for dbdome_service processes to exit ==" -ForegroundColor Cyan
    1..30 | ForEach-Object {
        if (-not (Get-Process dbdome_service -ErrorAction SilentlyContinue)) { return }
        Start-Sleep -Seconds 1
    }
    if (Get-Process dbdome_service -ErrorAction SilentlyContinue) { throw "dbdome_service still running -- aborting before file swap" }

    Write-Host "== Backing up current bin (rollback: _internal.bak_$ts, *.bak_$ts) ==" -ForegroundColor Cyan
    Copy-Item "$bin\dbdome_service.exe"     "$bin\dbdome_service.exe.bak_$ts"     -Force
    Copy-Item "$bin\dbdome_dbanalytics.exe" "$bin\dbdome_dbanalytics.exe.bak_$ts" -Force
    if (Test-Path "$bin\_internal") { Rename-Item "$bin\_internal" "_internal.bak_$ts" }

    Write-Host "== Copying new _internal (454 MB, ~1-2 min) ==" -ForegroundColor Cyan
    # robocopy: /E subdirs, /NFL/NDL quiet; exit codes 0-7 are success
    robocopy "$src\_internal" "$bin\_internal" /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) -- restore _internal.bak_$ts" }

    Write-Host "== Copying new exes ==" -ForegroundColor Cyan
    Copy-Item "$src\dbdome_service.exe"     "$bin\dbdome_service.exe"     -Force
    Copy-Item "$src\dbdome_dbanalytics.exe" "$bin\dbdome_dbanalytics.exe" -Force

    Write-Host "== Starting services ==" -ForegroundColor Cyan
    foreach ($svc in $startSvcs) { Start-Service -Name $svc }
    Assert-DeployHealthy
}
finally {
    # Guarantee services are never left stopped by an aborted deploy: if the
    # swap threw after we stopped them, still bring them back up.
    foreach ($svc in $startSvcs) {
        if ((Get-Service $svc -ErrorAction SilentlyContinue).Status -ne 'Running') {
            Write-Host "== [finally] $svc not Running -- attempting start ==" -ForegroundColor Yellow
            try { Start-Service -Name $svc -ErrorAction Stop } catch { Write-Host "  could not start ${svc}: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
}

Write-Host "== DONE. New service exe: ==" -ForegroundColor Green
(Get-Item "$bin\dbdome_service.exe").LastWriteTime

Write-Host ""
Write-Host "ROLLBACK (if needed):" -ForegroundColor Yellow
Write-Host "  Stop-Service $($svcs -join ',') -Force"
Write-Host "  Remove-Item '$bin\_internal' -Recurse -Force"
Write-Host "  Rename-Item '$bin\_internal.bak_$ts' '_internal'"
Write-Host "  Copy-Item '$bin\dbdome_service.exe.bak_$ts' '$bin\dbdome_service.exe' -Force"
Write-Host "  Copy-Item '$bin\dbdome_dbanalytics.exe.bak_$ts' '$bin\dbdome_dbanalytics.exe' -Force"
Write-Host "  Start-Service $($svcs -join ',')"
