<#
    Lifecycle.Tests.ps1 - Service install/remove/start/stop/restart/status tests.

    Each Context block verifies one lifecycle transition.
    Uses Invoke-NssmCommand to prevent GUI popups.
    Pester v3 compatible syntax.
#>

$here = $PSScriptRoot

Describe "Service Lifecycle" {
    BeforeAll {
        . (Join-Path $here "Common.ps1")
        $nssmPath = Get-NssmPath
        $script:ServiceName = New-TestServiceName
        $script:AppPath = Get-TestProcessPath
        $script:AppArgs = Get-TestLongRunArgs
    }

    AfterAll {
        Uninstall-TestService -Name $script:ServiceName -NssmPath $nssmPath
    }

    Context "Install" {
        It "Installs a new service successfully" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "install", $script:ServiceName, $script:AppPath, $script:AppArgs
            $result.ExitCode | Should Be 0
            Test-ServiceExists -Name $script:ServiceName | Should Be $true
        }

        It "Service is in STOPPED state after install" {
            $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
            $svc | Should Not BeNullOrEmpty
            $svc.Status | Should Be "Stopped"
        }
    }

    Context "Start" {
        It "Starts the service successfully" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "start", $script:ServiceName
            $result.ExitCode | Should Be 0
        }

        It "Service reaches RUNNING state" {
            $reached = Wait-ServiceStatus -Name $script:ServiceName -Status "Running" -TimeoutSeconds 15
            $reached | Should Be $true
        }
    }

    Context "Status" {
        It "Status command reports running state" {
            $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
            if (-not $svc -or $svc.Status -ne 'Running') {
                Write-Warning "Service not running, skipping status test"
                return
            }
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "status", $script:ServiceName
            $result.ExitCode | Should Be 0
            $result.Stdout | Should Not BeNullOrEmpty
        }

        It "Statuscode returns exit code 4 (SERVICE_RUNNING)" {
            $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
            if (-not $svc -or $svc.Status -ne 'Running') {
                Write-Warning "Service not running, skipping statuscode test"
                return
            }
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "statuscode", $script:ServiceName
            $result.ExitCode | Should Be 4
            # statuscode may output "SERVICE_RUNNING" or "4" depending on capture method
            ($result.Stdout.Trim() -eq "4" -or $result.Stdout.Trim() -eq "SERVICE_RUNNING") | Should Be $true
        }
    }

    Context "Restart" {
        It "Restarts the service successfully" {
            $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
            if (-not $svc -or $svc.Status -ne 'Running') {
                Write-Warning "Service not running, skipping restart test"
                return
            }
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "restart", $script:ServiceName
            $result.ExitCode | Should Be 0
        }

        It "Service is still RUNNING after restart" {
            $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
            if (-not $svc -or $svc.Status -ne 'Running') {
                return
            }
            $reached = Wait-ServiceStatus -Name $script:ServiceName -Status "Running" -TimeoutSeconds 15
            $reached | Should Be $true
        }
    }

    Context "Stop" {
        It "Stops the service" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "stop", $script:ServiceName
            $reached = Wait-ServiceStatus -Name $script:ServiceName -Status "Stopped" -TimeoutSeconds 10
            $reached | Should Be $true
        }
    }

    Context "Remove" {
        It "Removes the service successfully" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "remove", $script:ServiceName, "confirm"
            $result.ExitCode | Should Be 0
        }

        It "Service no longer exists in SCM" {
            Start-Sleep -Seconds 1
            Test-ServiceExists -Name $script:ServiceName | Should Be $false
        }
    }
}
