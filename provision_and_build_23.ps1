<#
.SYNOPSIS
    Provision Python 3.14 + the build venv on 181.214.214.23, then build.

.DESCRIPTION
    Written for the case where 181.214.214.23 cannot be reached from the dev box
    (ports 22 and 445 are dropped; only 3389 answers), so the build has to be
    driven locally on .23 instead of remotely.

    Run this ON 181.214.214.23, in an ELEVATED PowerShell, after the repo has
    been copied to C:\dev\dbdome_dbanalytics_service.

    Why 3.14 and not the 3.12 already installed there: build.ps1 requires
    C:\apps\venv314 and aborts without it. A bare interpreter without reportlab
    et al produces a ~18 MB bundle that builds fine and then dies at runtime on
    `import reportlab` - which is what the >= 30 MB assertion in build.ps1 exists
    to catch.

.PARAMETER BuildNo
    Passed through to build.ps1. Omit to be prompted there.

.PARAMETER SkipInstallers
    Build only the service, not the two installers.
#>
[CmdletBinding()]
param(
    [int]    $BuildNo,
    [string] $Notes = 'Rebuilt on 181.214.214.23',
    [switch] $SkipInstallers
)

$ErrorActionPreference = 'Stop'

$Repo    = 'C:\dev\dbdome_dbanalytics_service'
$VenvDir = 'C:\apps\venv314'
$Py314   = 'C:\Program Files\Python314\python.exe'
$Reqs    = Join-Path $Repo 'requirements-venv314.txt'

function Say($m, $c = 'Cyan') { Write-Host "`n== $m" -ForegroundColor $c }

if (-not (New-Object Security.Principal.WindowsPrincipal(
            [Security.Principal.WindowsIdentity]::GetCurrent())
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this elevated - winget --scope machine and C:\apps both need it."
}
if (-not (Test-Path $Repo))  { throw "repo not found at $Repo - copy it over first" }
if (-not (Test-Path $Reqs))  { throw "$Reqs missing - it ships with the repo copy" }

# ---------------------------------------------------------------- python 3.14
Say 'Python 3.14'
if (Test-Path $Py314) {
    Write-Host "   already installed: $(& $Py314 -c 'import sys;print(sys.version.split()[0])')"
} else {
    Write-Host '   installing via winget (machine scope)...'
    winget install Python.Python.3.14 --scope machine `
        --accept-source-agreements --accept-package-agreements
    if (-not (Test-Path $Py314)) { throw "winget finished but $Py314 is absent" }
    Write-Host "   installed: $(& $Py314 -c 'import sys;print(sys.version.split()[0])')"
}

# ---------------------------------------------------------------- venv
Say 'Build venv'
if (Test-Path "$VenvDir\Scripts\python.exe") {
    Write-Host "   reusing $VenvDir"
} else {
    & $Py314 -m venv $VenvDir
    if (-not (Test-Path "$VenvDir\Scripts\python.exe")) { throw "venv creation failed at $VenvDir" }
    Write-Host "   created $VenvDir"
}
$VenvPy = "$VenvDir\Scripts\python.exe"

# ---------------------------------------------------------------- packages
# Pinned export of the dev box's working venv (202 packages, Python 3.14.5).
# The repo has no requirements.txt of its own - this file is the only record of
# the build environment, so keep it in step when the dev venv changes.
Say 'Packages'
& $VenvPy -m pip install --upgrade pip
& $VenvPy -m pip install -r $Reqs
if ($LASTEXITCODE -ne 0) { throw "pip install failed ($LASTEXITCODE)" }

Say 'Verifying the imports that the 30 MB assertion is really about'
$probe = 'import reportlab, matplotlib, scipy, pandas, numpy, psycopg2, pyodbc; print("  imports OK")'
& $VenvPy -c $probe
if ($LASTEXITCODE -ne 0) { throw 'a required package is missing from the venv - build would produce a broken bundle' }

# ---------------------------------------------------------------- build
Say 'Build'
Push-Location $Repo
try {
    $args = @{}
    if ($PSBoundParameters.ContainsKey('BuildNo')) { $args.BuildNo = $BuildNo }
    if ($Notes)                                    { $args.Notes   = $Notes }
    if ($SkipInstallers)                           { $args.SkipInstallers = $true }
    & "$Repo\build.ps1" @args
} finally { Pop-Location }

Say 'Result' 'Green'
Get-ChildItem "$Repo\dist_rd" -Recurse -Filter *.exe -ErrorAction SilentlyContinue |
    Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }, LastWriteTime |
    Format-Table -AutoSize
Write-Host '   Any exe under 30 MB means the venv was incomplete - do not ship it.' -ForegroundColor Yellow
