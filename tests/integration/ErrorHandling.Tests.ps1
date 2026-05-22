<#
    ErrorHandling.Tests.ps1 - Error case tests.

    Tests invalid arguments, nonexistent services, and edge cases.
    NOTE: Uses Invoke-NssmCommand to prevent GUI popups.
    Commands that trigger GUI (no args, invalid command) are excluded.
    Pester v3 compatible syntax.
#>

$here = $PSScriptRoot

Describe "Error Handling" {
    BeforeAll {
        . (Join-Path $here "Common.ps1")
        $nssmPath = Get-NssmPath
        $script:NonexistentService = "nssm_nonexistent_$(Get-Random)"
    }

    Context "Version" {
        It "nssm version prints version info and exits 0" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "version"
            $result.ExitCode | Should Be 0
            $result.Stdout | Should Not BeNullOrEmpty
        }
    }

    Context "Nonexistent service operations" {
        It "start nonexistent service returns non-zero exit code" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "start", $script:NonexistentService
            $result.ExitCode | Should Not Be 0
            $result.Stderr | Should Not BeNullOrEmpty
        }

        It "stop nonexistent service returns non-zero exit code" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "stop", $script:NonexistentService
            $result.ExitCode | Should Not Be 0
            $result.Stderr | Should Not BeNullOrEmpty
        }

        It "remove nonexistent service returns non-zero exit code" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "remove", $script:NonexistentService, "confirm"
            $result.ExitCode | Should Not Be 0
            $result.Stderr | Should Not BeNullOrEmpty
        }

        It "status nonexistent service returns non-zero exit code" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "status", $script:NonexistentService
            $result.ExitCode | Should Not Be 0
            $result.Stderr | Should Not BeNullOrEmpty
        }

        It "statuscode nonexistent service outputs error" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "statuscode", $script:NonexistentService
            ($result.ExitCode -ne 0 -or $result.Stderr -ne "") | Should Be $true
        }

        It "get parameter from nonexistent service returns non-zero exit code" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:NonexistentService, "AppDirectory"
            $result.ExitCode | Should Not Be 0
            $result.Stderr | Should Not BeNullOrEmpty
        }

        It "set parameter on nonexistent service returns non-zero exit code" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:NonexistentService, "AppDirectory", "C:\temp"
            $result.ExitCode | Should Not Be 0
            $result.Stderr | Should Not BeNullOrEmpty
        }
    }

    Context "Duplicate install" {
        BeforeAll {
            $script:TestService = New-TestServiceName
        }

        AfterAll {
            Uninstall-TestService -Name $script:TestService -NssmPath $nssmPath
        }

        It "Installing duplicate service name returns non-zero" {
            $appPath = Get-TestProcessPath
            $appArgs = Get-TestLongRunArgs

            $result1 = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "install", $script:TestService, $appPath, $appArgs
            $result1.ExitCode | Should Be 0

            $result2 = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "install", $script:TestService, $appPath, $appArgs
            $result2.ExitCode | Should Not Be 0
        }
    }
}
