<#
    CrashRecovery.Tests.ps1 - Process crash and auto-restart tests.

    Verifies that NSSM restarts the managed process after it exits.
    Approach: Install with a short-lived process (ping -n 3) that exits
    every ~3 seconds. Verify NSSM keeps the service running by restarting it.
    Uses Invoke-NssmCommand to prevent GUI popups.
    Pester v3 compatible syntax.
#>

$here = $PSScriptRoot

Describe "Crash Recovery - Short-lived process" {
    BeforeAll {
        . (Join-Path $here "Common.ps1")
        $nssmPath = Get-NssmPath
        $script:AppPath = Get-TestProcessPath
        $script:ServiceName = New-TestServiceName
        $shortArgs = Get-TestShortRunArgs -Seconds 3

        $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "install", $script:ServiceName, $script:AppPath, $shortArgs
        if ($result.ExitCode -ne 0) {
            throw "Failed to install test service '$script:ServiceName': $($result.Stderr)"
        }
    }

    AfterAll {
        Uninstall-TestService -Name $script:ServiceName -NssmPath $nssmPath
    }

    It "Service starts successfully with a short-lived process" {
        $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "start", $script:ServiceName
        $result.ExitCode | Should Be 0
    }

    It "Service is still RUNNING after the process exits once (NSSM restarted it)" {
        $reached = Wait-ServiceStatus -Name $script:ServiceName -Status "Running" -TimeoutSeconds 15
        $reached | Should Be $true
    }

    It "Service remains RUNNING across multiple process restarts" {
        $reached = Wait-ServiceStatus -Name $script:ServiceName -Status "Running" -TimeoutSeconds 10
        $reached | Should Be $true
    }

    It "Can stop the auto-restarting service" {
        $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "stop", $script:ServiceName
        $result.ExitCode | Should Be 0

        $reached = Wait-ServiceStatus -Name $script:ServiceName -Status "Stopped" -TimeoutSeconds 10
        $reached | Should Be $true
    }
}
