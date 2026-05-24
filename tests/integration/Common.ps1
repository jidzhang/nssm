<#
    Common.ps1 - Shared helper functions for NSSM integration tests.

    Provides path resolution, service name generation, and cleanup utilities.
    All functions are exported via Export-ModuleMember.
#>

$script:ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Get-NssmPath {
    <#
        .SYNOPSIS
        Returns the path to nssm.exe for a given platform.

        .PARAMETER Platform
        "win32" or "win64". If omitted, reads $env:NSSM_TEST_PLATFORM.
        If still unset, tries win32 first, then win64.
    #>
    param(
        [string]$Platform = $env:NSSM_TEST_PLATFORM
    )

    if ($Platform -eq "win32") {
        $candidates = @(
            (Join-Path $script:ProjectRoot "out\Release\win32\nssm.exe")
            (Join-Path $script:ProjectRoot "out\Debug\win32\nssm.exe")
        )
    } elseif ($Platform -eq "win64") {
        $candidates = @(
            (Join-Path $script:ProjectRoot "out\Release\win64\nssm64.exe")
            (Join-Path $script:ProjectRoot "out\Release\win64\nssm.exe")
            (Join-Path $script:ProjectRoot "out\Debug\win64\nssm.exe")
        )
    } else {
        $candidates = @(
            (Join-Path $script:ProjectRoot "out\Release\win32\nssm.exe")
            (Join-Path $script:ProjectRoot "out\Debug\win32\nssm.exe")
            (Join-Path $script:ProjectRoot "out\Release\win64\nssm64.exe")
            (Join-Path $script:ProjectRoot "out\Release\win64\nssm.exe")
            (Join-Path $script:ProjectRoot "out\Debug\win64\nssm.exe")
        )
    }
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return (Resolve-Path $path).Path
        }
    }
    throw "nssm.exe not found for platform '$Platform'. Build the project first."
}

function New-TestServiceName {
    <#
        .SYNOPSIS
        Generates a unique service name like "nssm_test_abc12345".
    #>
    $suffix = -join ((48..57) + (97..102) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
    return "nssm_test_$suffix"
}

function Get-TestProcessPath {
    <#
        .SYNOPSIS
        Returns a suitable long-running executable path for service tests.
        Uses ping.exe directly (not cmd.exe) to avoid quoting issues in Session 0.
    #>
    return "$env:SystemRoot\System32\ping.exe"
}

function Get-TestLongRunArgs {
    <#
        .SYNOPSIS
        Returns arguments for a long-running process (ping forever).
    #>
    return "-t 127.0.0.1"
}

function Get-TestShortRunArgs {
    <#
        .SYNOPSIS
        Returns arguments for a process that exits after ~N seconds.
        Default is 3 seconds.
    #>
    param(
        [int]$Seconds = 3
    )
    return "-n $Seconds 127.0.0.1"
}

function Uninstall-TestService {
    <#
        .SYNOPSIS
        Force-removes a service, ignoring all errors.
        Stops the service first, then removes it, and waits for cleanup.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$NssmPath = (Get-NssmPath)
    )

    $ErrorActionPreference = "SilentlyContinue"

    # Try to stop the service
    & $NssmPath stop $Name 2>$null | Out-Null
    Start-Sleep -Milliseconds 500

    # Try SCM stop as fallback
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Stopped') {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    } catch { }

    # Try nssm remove
    & $NssmPath remove $Name confirm 2>$null | Out-Null
    Start-Sleep -Milliseconds 500

    # Try SCM delete as fallback
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($svc) {
            & sc.exe delete $Name 2>$null | Out-Null
            Start-Sleep -Milliseconds 500
        }
    } catch { }

    # Wait for service to fully disappear (up to 5 seconds)
    $attempts = 0
    while ($attempts -lt 10) {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $svc) { break }
        Start-Sleep -Milliseconds 500
        $attempts++
    }

    $ErrorActionPreference = "Stop"
}

function Test-ServiceExists {
    <#
        .SYNOPSIS
        Returns $true if the named service exists in SCM.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return ($null -ne $svc)
}

function Wait-ServiceStatus {
    <#
        .SYNOPSIS
        Waits for a service to reach the specified status.
        Returns $true if the status was reached within the timeout.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [int]$TimeoutSeconds = 10
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status.ToString() -eq $Status) {
                return $true
            }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Invoke-NssmCommand {
    <#
        .SYNOPSIS
        Runs nssm.exe safely, capturing stdout/stderr without GUI popups.
        Returns a hashtable with ExitCode, Stdout, Stderr.

        Uses Start-Process with -WindowStyle Hidden to prevent NSSM from
        displaying GUI dialogs (e.g., help window, error popups).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$NssmPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $tag = [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tmpDir = [System.IO.Path]::GetTempPath()
    $outFile = Join-Path $tmpDir "nssm_test_stdout_$tag.txt"
    $errFile = Join-Path $tmpDir "nssm_test_stderr_$tag.txt"

    try {
        $p = Start-Process -FilePath $NssmPath -ArgumentList $Arguments `
            -Wait -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
            -ErrorAction Stop

        $stdout = ""
        $stderr = ""
        if (Test-Path $outFile) {
            $raw = Get-Content $outFile -Raw
            if ($raw) { $stdout = $raw.Trim() }
        }
        if (Test-Path $errFile) {
            $raw = Get-Content $errFile -Raw
            if ($raw) { $stderr = $raw.Trim() }
        }

        return @{
            ExitCode = $p.ExitCode
            Stdout   = $stdout
            Stderr   = $stderr
        }
    }
    finally {
        if (Test-Path $outFile) { Remove-Item $outFile -ErrorAction SilentlyContinue }
        if (Test-Path $errFile) { Remove-Item $errFile -ErrorAction SilentlyContinue }
    }
}

# Functions are available to callers via dot-sourcing (. Common.ps1)
# No Export-ModuleMember needed — dot-sourcing puts all functions in caller scope.
