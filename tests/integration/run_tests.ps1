<#
    run_tests.ps1 - Build NSSM and run all Pester integration tests.

    Prerequisites:
    - Run as Administrator (SCM operations require elevation)
    - VS2019+ with MSBuild available (for building nssm)
    - PowerShell 5.1+ (uses inbox Pester 3.4 on Windows 10)

    Usage:
        powershell -ExecutionPolicy Bypass -File run_tests.ps1
        powershell -ExecutionPolicy Bypass -File run_tests.ps1 -SkipBuild
        powershell -ExecutionPolicy Bypass -File run_tests.ps1 -Tests "Lifecycle","ErrorHandling"
#>

[CmdletBinding()]
param(
    [switch]$SkipBuild,

    [string[]]$Tests,

    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerboseOutput) { "Continue" } else { "SilentlyContinue" }

# ---------------------------------------------------------------------------
# Check Administrator
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Error "Integration tests MUST be run as Administrator. SCM operations require elevation."
    exit 1
}
Write-Host "[INFO] Running as Administrator - OK" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$script:TestDir = $PSScriptRoot
$script:ProjectRoot = Resolve-Path (Join-Path $script:TestDir "..\..")
$script:CommonModule = Join-Path $script:TestDir "Common.ps1"

Write-Host "[INFO] Project root: $script:ProjectRoot"
Write-Host "[INFO] Test dir:     $script:TestDir"

# ---------------------------------------------------------------------------
# Load Pester (inbox on Windows 10, or whatever is available)
# ---------------------------------------------------------------------------
Import-Module Pester -ErrorAction Stop
$pesterVer = (Get-Module Pester).Version.ToString()
Write-Host "[INFO] Pester v$pesterVer loaded" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Build NSSM (unless skipped)
# ---------------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "[INFO] Building NSSM (Release x64) ..." -ForegroundColor Cyan

    # Try MSBuild
    $msbuildPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\*\MSBuild\Current\Bin\MSBuild.exe"
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\*\MSBuild\Current\Bin\MSBuild.exe"
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\*\MSBuild\Current\Bin\MSBuild.exe"
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\MSBuild\Current\Bin\MSBuild.exe"
    )

    $msbuild = $null
    foreach ($pattern in $msbuildPaths) {
        $found = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) {
            $msbuild = $found.FullName
            break
        }
    }

    if (-not $msbuild) {
        # Try vswhere
        $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswherePath) {
            $installPath = & $vswherePath -latest -property installationPath 2>$null
            if ($installPath) {
                $msbuild = Get-ChildItem "$installPath\MSBuild\*\Bin\MSBuild.exe" -ErrorAction SilentlyContinue |
                    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
            }
        }
    }

    if (-not $msbuild) {
        Write-Error "MSBuild not found. Install Visual Studio 2019+ or use -SkipBuild if nssm.exe is already built."
        exit 1
    }

    Write-Host "[INFO] Using MSBuild: $msbuild"

    # Try x64 first, fall back to Win32
    $buildSuccess = $false
    foreach ($platform in @("x64", "Win32")) {
        $vcxproj = Join-Path $script:ProjectRoot "nssm.vcxproj"
        if (-not (Test-Path $vcxproj)) {
            # Try solution file
            $sln = Get-ChildItem $script:ProjectRoot -Filter "nssm*.sln" | Select-Object -First 1
            if ($sln) { $vcxproj = $sln.FullName }
        }

        Write-Host "[INFO] Building Release|$platform ..."
        & $msbuild $vcxproj /p:Configuration=Release /p:Platform=$platform /v:minimal /nologo 2>&1
        if ($LASTEXITCODE -eq 0) {
            $buildSuccess = $true
            Write-Host "[INFO] Build succeeded for $platform" -ForegroundColor Green
            break
        }
        Write-Host "[WARN] Build failed for $platform, trying next..." -ForegroundColor Yellow
    }

    if (-not $buildSuccess) {
        Write-Error "Build failed for all platforms. Check build output above."
        exit 1
    }
} else {
    Write-Host "[INFO] Skipping build ( -SkipBuild )" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Verify nssm.exe exists
# ---------------------------------------------------------------------------
. $script:CommonModule
try {
    $nssmPath = Get-NssmPath
    Write-Host "[INFO] nssm.exe: $nssmPath" -ForegroundColor Green

    # Print version
    $ver = & $nssmPath version 2>&1
    Write-Host "[INFO] NSSM version: $ver"
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

# ---------------------------------------------------------------------------
# Run Pester tests
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Running NSSM Integration Tests" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Test paths
$testFiles = @(
    (Join-Path $script:TestDir "Lifecycle.Tests.ps1"),
    (Join-Path $script:TestDir "Parameters.Tests.ps1"),
    (Join-Path $script:TestDir "CrashRecovery.Tests.ps1"),
    (Join-Path $script:TestDir "ErrorHandling.Tests.ps1")
)

# Filter by specific test files if requested
if ($Tests) {
    $testFiles = $testFiles | Where-Object {
        $file = $_
        $Tests | ForEach-Object { $file -match $_ } | Where-Object { $_ }
    }
    if (-not $testFiles) {
        Write-Error "No test files matched the filter: $($Tests -join ', ')"
        exit 1
    }
}

# Validate test files exist
foreach ($f in $testFiles) {
    if (-not (Test-Path $f)) {
        Write-Error "Test file not found: $f"
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Run each test file in an isolated PowerShell process.
# Pester v3's Invoke-Pester -Script @(...) runs all files in the same
# runspace, causing Describe-context leakage and variable scope pollution
# between files. Isolating per-file prevents this entirely.
# ---------------------------------------------------------------------------

$totalPassed = 0
$totalFailed = 0
$totalCount = 0
$totalSkipped = 0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($testFile in $testFiles) {
    $fileName = [System.IO.Path]::GetFileName($testFile)
    Write-Host "  Running: $fileName ..." -ForegroundColor Cyan

    # Build the wrapper script that will run inside a child PowerShell process.
    # Uses -File instead of -Command to avoid all quoting/escaping nightmares.
    # The wrapper writes a structured "PESTER_RESULT:..." line to stdout.
    $wrapperPath = Join-Path $script:TestDir "_run_single_test.tmp.ps1"
    $wrapperContent = @"
Import-Module Pester -ErrorAction Stop
`$r = Invoke-Pester -Script '$($testFile.Replace("'", "''"))' -PassThru
Write-Output "PESTER_RESULT:`$(`$r.PassedCount)|`$(`$r.FailedCount)|`$(`$r.TotalCount)|`$(`$r.SkippedCount)"
"@
    Set-Content -LiteralPath $wrapperPath -Value $wrapperContent -Encoding UTF8

    try {
        $output = powershell -ExecutionPolicy Bypass -NoProfile -File $wrapperPath 2>&1

        # Display the Pester output (everything except our structured result line)
        $output | Where-Object { $_ -notmatch "^PESTER_RESULT:" } | ForEach-Object { Write-Host "  $_" }

        # Parse the structured result line from the child process
        $resultLine = $output | Where-Object { $_ -match "^PESTER_RESULT:" } | Select-Object -Last 1
        if ($resultLine -and $resultLine -match "^PESTER_RESULT:(\d+)\|(\d+)\|(\d+)\|(\d+)") {
            $passed = [int]$Matches[1]
            $failed = [int]$Matches[2]
            $count = [int]$Matches[3]
            $skipped = [int]$Matches[4]

            $totalPassed += $passed
            $totalFailed += $failed
            $totalCount += $count
            $totalSkipped += $skipped

            if ($failed -gt 0) {
                Write-Host "  FAILED: $fileName ($failed failure(s))" -ForegroundColor Red
            } else {
                Write-Host "  PASSED: $fileName ($passed passed)" -ForegroundColor Green
            }
        } else {
            Write-Host "  ERROR: Could not parse results from $fileName" -ForegroundColor Red
            $totalFailed++
            $totalCount++
        }
    }
    finally {
        Remove-Item $wrapperPath -ErrorAction SilentlyContinue
    }
    Write-Host ""
}

$stopwatch.Stop()

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Total:    $totalCount"
Write-Host "  Passed:   $totalPassed" -ForegroundColor Green
Write-Host "  Failed:   $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "Green" })
Write-Host "  Skipped:  $totalSkipped" -ForegroundColor Yellow
$duration = $stopwatch.Elapsed
Write-Host "  Duration: $($duration.ToString('hh\:mm\:ss\.fff'))"
Write-Host ""

if ($totalFailed -gt 0) {
    Write-Host "FAILED: $totalFailed test(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "ALL TESTS PASSED." -ForegroundColor Green
exit 0
