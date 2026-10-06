<#
    Deploy the freshly built service payload into the two INSTALLER MEDIA trees
    only -- C:\installs\dbdome_setup and C:\installs\dbdome_update. This is
    deploy_all_three.ps1's non-live path for exactly those two targets; it does
    NOT touch the live C:\ProgramData\DBDOME service (that box's swap is a
    separate, deliberate action).

    Matches the project recipe: back up the prior exes and _internal (.bak_<ts>),
    robocopy the new _internal, copy the two exes. It additionally PRESERVES each
    media's own _internal\.env across the swap (the spec bundles the dev .env
    into _internal; see the dbdome-dev-env-bundled-in-internal note), so a deploy
    can never stamp dev credentials into shippable media.
#>
$ErrorActionPreference = 'Stop'
$src = 'C:\dev\dbdome_dbanalytics_service\dist_rd\dbdome_dbanalytics'
$ts  = Get-Date -Format 'yyyyMMdd_HHmmss'

foreach ($p in 'dbdome_service.exe','dbdome_dbanalytics.exe','_internal') {
    if (-not (Test-Path "$src\$p")) { throw "build missing: $src\$p" }
}

function Deploy-Media([string]$bin) {
    Write-Host "==== $bin ====" -ForegroundColor Cyan
    if (-not (Test-Path $bin)) { throw "target missing: $bin" }

    # remember this media's own bundled _internal\.env so we can put it back
    $savedEnv = $null
    if (Test-Path "$bin\_internal\.env") {
        $savedEnv = Get-Content -Raw -LiteralPath "$bin\_internal\.env"
        Write-Host "  saved existing _internal\.env ($($savedEnv.Length) bytes)"
    }

    foreach ($e in 'dbdome_service.exe','dbdome_dbanalytics.exe') {
        if (Test-Path "$bin\$e") { Copy-Item "$bin\$e" "$bin\$e.bak_$ts" -Force }
    }
    if (Test-Path "$bin\_internal") { Rename-Item "$bin\_internal" "_internal.bak_$ts" }

    Write-Host "  robocopy _internal (~454 MB) ..."
    robocopy "$src\_internal" "$bin\_internal" /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) for $bin -- restore _internal.bak_$ts" }
    $global:LASTEXITCODE = 0

    if ($null -ne $savedEnv) {
        Set-Content -LiteralPath "$bin\_internal\.env" -Value $savedEnv -NoNewline -Encoding utf8
        Write-Host "  restored this media's own _internal\.env"
    }

    Copy-Item "$src\dbdome_service.exe"     "$bin\dbdome_service.exe"     -Force
    Copy-Item "$src\dbdome_dbanalytics.exe" "$bin\dbdome_dbanalytics.exe" -Force
    Write-Host "  DONE" -ForegroundColor Green
}

Deploy-Media 'C:\installs\dbdome_update\dbdome\bin'
Deploy-Media 'C:\installs\dbdome_setup\dbdome\bin'
Write-Host "==== BOTH MEDIA DEPLOYED (backup suffix bak_$ts) ====" -ForegroundColor Green
$global:LASTEXITCODE = 0
exit 0
