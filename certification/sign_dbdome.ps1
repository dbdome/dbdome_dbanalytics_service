# =============================================================================
# sign_dbdome.ps1  — RUN AS ADMINISTRATOR (or any account that can write the exes)
# Authenticode-signs all DBDOME-authored exes with dbdome_cert.pfx (SHA-256 +
# RFC3161 timestamp). Run this AFTER every build / before packaging & shipping.
#
# Only sign binaries YOU produce. grafana.exe / nssm.exe are third-party and are
# already signed by their vendors — do NOT re-sign them.
# =============================================================================
$ErrorActionPreference = 'Stop'

$PFX  = 'C:\dev\dbdome_dbanalytics_service\certification\dbdome_cert.pfx'
$PASS = 'Yd2243796Anz!!'
$TS   = 'http://timestamp.digicert.com'

# Locate the newest signtool.exe (x64) in the Windows SDK.
$signtool = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe' -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $signtool) { throw "signtool.exe not found — install the Windows 10/11 SDK." }
Write-Host "signtool: $signtool"

# Sign the BUILD + PACKAGE copies (not the live C:\ProgramData\DBDOME\bin exes,
# which are locked while the service runs). The live install receives signed exes
# when you redeploy this signed dist_rd (deploy_redeploy.ps1). To sign the live
# bin directly you'd first Stop-Service DBDOME_web,DBDOME_scheduler.
$targets = @(
  # fresh build (deploy this to live -> live becomes signed)
  'C:\dev\dbdome_dbanalytics_service\dist_rd\dbdome_dbanalytics\dbdome_service.exe'
  'C:\dev\dbdome_dbanalytics_service\dist_rd\dbdome_dbanalytics\dbdome_dbanalytics.exe'
  # update package payload
  'C:\installs\dbdome_update\dbdome\bin\dbdome_service.exe'
  'C:\installs\dbdome_update\dbdome\bin\dbdome_dbanalytics.exe'
  # setup package payload
  'C:\installs\dbdome_setup\dbdome\bin\dbdome_service.exe'
  'C:\installs\dbdome_setup\dbdome\bin\dbdome_dbanalytics.exe'
  # the installer executables themselves
  'C:\installs\dbdome_setup\dbdome_setup.exe'
  'C:\installs\dbdome_update\dbdome_update.exe'
)

$ok = 0; $skip = 0; $fail = 0
foreach ($f in $targets) {
  if (-not (Test-Path $f)) { Write-Host "  SKIP (missing): $f" -ForegroundColor DarkGray; $skip++; continue }
  & $signtool sign /f $PFX /p $PASS /tr $TS /td SHA256 /fd SHA256 $f
  if ($LASTEXITCODE -eq 0) { Write-Host "  SIGNED: $f" -ForegroundColor Green; $ok++ }
  else                     { Write-Host "  FAILED ($LASTEXITCODE): $f" -ForegroundColor Red; $fail++ }
}
Write-Host ""
Write-Host "signed=$ok  skipped=$skip  failed=$fail" -ForegroundColor Cyan

# Verify one as a sanity check (optional)
if ($ok -gt 0) {
  $first = $targets | Where-Object { Test-Path $_ } | Select-Object -First 1
  Write-Host "`n== verify $first =="
  & $signtool verify /pa /v $first
}
