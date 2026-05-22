<#
    Parameters.Tests.ps1 - Set/get/reset parameter tests on an installed (stopped) service.
    Uses Invoke-NssmCommand to prevent GUI popups.
    Pester v3 compatible syntax.
#>

$here = $PSScriptRoot

Describe "Service Parameters" {
    BeforeAll {
        . (Join-Path $here "Common.ps1")
        $nssmPath = Get-NssmPath
        $script:ServiceName = New-TestServiceName
        $script:AppPath = Get-TestProcessPath
        $script:AppArgs = Get-TestLongRunArgs

        $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "install", $script:ServiceName, $script:AppPath, $script:AppArgs
        if ($result.ExitCode -ne 0) {
            throw "Failed to install test service '$script:ServiceName': $($result.Stderr)"
        }
    }

    AfterAll {
        Uninstall-TestService -Name $script:ServiceName -NssmPath $nssmPath
    }

    Context "AppDirectory" {
        It "Sets AppDirectory to a temp path" {
            $tempPath = [System.IO.Path]::GetTempPath().TrimEnd('\')
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppDirectory", $tempPath
            $result.ExitCode | Should Be 0
        }

        It "Gets AppDirectory and returns the correct value" {
            $tempPath = [System.IO.Path]::GetTempPath().TrimEnd('\')
            Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppDirectory", $tempPath | Out-Null
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:ServiceName, "AppDirectory"
            $result.ExitCode | Should Be 0
            $result.Stdout | Should Not BeNullOrEmpty
            $result.Stdout.TrimEnd('\') | Should Be $tempPath
        }
    }

    Context "AppPriority" {
        It "Sets AppPriority to IDLE_PRIORITY_CLASS" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppPriority", "IDLE_PRIORITY_CLASS"
            $result.ExitCode | Should Be 0
        }

        It "Gets AppPriority and returns the correct value" {
            Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppPriority", "IDLE_PRIORITY_CLASS" | Out-Null
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:ServiceName, "AppPriority"
            $result.ExitCode | Should Be 0
            $result.Stdout.Trim() | Should Be "IDLE_PRIORITY_CLASS"
        }
    }

    Context "AppRestartDelay" {
        It "Sets AppRestartDelay to 15000" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppRestartDelay", "15000"
            $result.ExitCode | Should Be 0
        }

        It "Gets AppRestartDelay and returns the correct value" {
            Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppRestartDelay", "15000" | Out-Null
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:ServiceName, "AppRestartDelay"
            $result.ExitCode | Should Be 0
            $result.Stdout.Trim() | Should Be "15000"
        }
    }

    Context "AppStdout" {
        It "Sets AppStdout to a log file path" {
            $logPath = Join-Path $env:TEMP "nssm_test_stdout.log"
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppStdout", $logPath
            $result.ExitCode | Should Be 0
        }

        It "Gets AppStdout and returns the correct value" {
            $logPath = Join-Path $env:TEMP "nssm_test_stdout.log"
            Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppStdout", $logPath | Out-Null
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:ServiceName, "AppStdout"
            $result.ExitCode | Should Be 0
            $result.Stdout.Trim() | Should Be $logPath
        }
    }

    Context "AppExit" {
        It "Sets exit action for default exit code" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppExit", "Default", "Ignore"
            $result.ExitCode | Should Be 0
        }

        It "Gets exit action for default exit code" {
            Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppExit", "Default", "Ignore" | Out-Null
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:ServiceName, "AppExit", "Default"
            $result.ExitCode | Should Be 0
            $result.Stdout.Trim() | Should Be "Ignore"
        }
    }

    Context "Reset" {
        It "Resets a parameter to default" {
            Invoke-NssmCommand -NssmPath $nssmPath -Arguments "set", $script:ServiceName, "AppRestartDelay", "99999" | Out-Null
            $getResult = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:ServiceName, "AppRestartDelay"
            $getResult.Stdout.Trim() | Should Be "99999"

            $resetResult = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "reset", $script:ServiceName, "AppRestartDelay"
            $resetResult.ExitCode | Should Be 0

            $afterResult = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "get", $script:ServiceName, "AppRestartDelay"
            $afterResult.Stdout.Trim() | Should Not Be "99999"
        }
    }

    Context "Dump" {
        It "Dumps all parameters without error" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "dump", $script:ServiceName
            $result.ExitCode | Should Be 0
            $result.Stdout | Should Not BeNullOrEmpty
        }

        It "Dump output contains expected parameter names" {
            $result = Invoke-NssmCommand -NssmPath $nssmPath -Arguments "dump", $script:ServiceName
            $result.Stdout | Should Match "set"
        }
    }
}
