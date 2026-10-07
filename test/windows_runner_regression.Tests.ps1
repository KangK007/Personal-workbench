$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$debugExecutable = Join-Path $projectRoot 'build\windows\x64\runner\Debug\personal_workbench.exe'
$uninstallScript = Join-Path $projectRoot 'packaging\windows\Uninstall-PersonalWorkbench.ps1'

Describe 'Windows runner worker dispatch' {
    It 'executes the hosts worker while the desktop UI already owns the mutex' {
        if (-not (Test-Path -LiteralPath $debugExecutable -PathType Leaf)) {
            throw "Build the Windows Debug executable first: $debugExecutable"
        }

        $installedExecutable = Join-Path $env:LOCALAPPDATA 'Programs\PersonalWorkbench\personal_workbench.exe'
        $startedGui = $false
        $guiProcessesBefore = @(
            Get-Process -Name personal_workbench -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.MainWindowHandle -ne 0 -and $_.Path -and
                    ($_.Path.Equals($debugExecutable, [System.StringComparison]::OrdinalIgnoreCase) -or
                        $_.Path.Equals($installedExecutable, [System.StringComparison]::OrdinalIgnoreCase))
                }
        )
        $gui = $guiProcessesBefore |
            Where-Object { $_.Path.Equals($debugExecutable, [System.StringComparison]::OrdinalIgnoreCase) } |
            Select-Object -First 1
        if (-not $gui) {
            $installedGui = $guiProcessesBefore |
                Where-Object { $_.Path.Equals($installedExecutable, [System.StringComparison]::OrdinalIgnoreCase) } |
                Select-Object -First 1
            if ($installedGui) {
                # The installed and Debug binaries use the same per-session
                # mutex. Reuse the verified installed window as mutex owner;
                # only invoke the worker command from the newly built Debug exe.
                $gui = $installedGui
            } else {
                $gui = Start-Process -FilePath $debugExecutable -WorkingDirectory (Split-Path $debugExecutable) -PassThru
                $startedGui = $true
                Start-Sleep -Seconds 2
            }
        }
        $runningGui = Get-Process -Id $gui.Id -ErrorAction SilentlyContinue
        if (-not $runningGui -or $runningGui.MainWindowHandle -eq 0 -or
            -not ($runningGui.Path.Equals($debugExecutable, [System.StringComparison]::OrdinalIgnoreCase) -or
                $runningGui.Path.Equals($installedExecutable, [System.StringComparison]::OrdinalIgnoreCase))) {
            throw "No verified desktop window remained as the mutex owner for the worker test (PID $($gui.Id), path '$($gui.Path)', started by test: $startedGui)."
        }

        $missingFile = Join-Path ([System.IO.Path]::GetTempPath()) (
            'personal-workbench-missing-' + [Guid]::NewGuid().ToString('N') + '.txt'
        )
        try {
            $worker = Start-Process -FilePath $debugExecutable `
                -ArgumentList @('--restriction-hosts-apply', ('"{0}"' -f $missingFile)) `
                -WorkingDirectory (Split-Path $debugExecutable) -Wait -PassThru

            # A missing domain file is a deterministic worker failure. Exit 0
            # means the single-instance guard swallowed the worker command.
            $worker.ExitCode | Should Not Be 0
        } finally {
            if ($startedGui -and $gui -and -not $gui.HasExited) {
                Stop-Process -Id $gui.Id -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Windows uninstall cleanup' {
    $source = Get-Content -Raw -LiteralPath $uninstallScript

    It 'removes the installer-owned startup registry value' {
        $source | Should Match "Remove-ItemProperty[\s\S]*?HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run[\s\S]*?-Name 'PersonalWorkbench'"
    }

    It 'removes the localized Start Menu shortcut created by the installer' {
        [regex]::IsMatch($source, '\$startMenu = \[Environment\]::GetFolderPath\(''Programs''\)') | Should Be $true
        $uninstallSource = [System.IO.File]::ReadAllText($uninstallScript)
        ([regex]::Matches($uninstallSource, 'Join-Path \$startMenu')).Count | Should Be 2
    }

    It 'removes the English Start Menu shortcut from the installer Programs Known Folder' {
        [regex]::IsMatch($source, '\$startMenu = \[Environment\]::GetFolderPath\(''Programs''\)') | Should Be $true
        [regex]::IsMatch($source, 'Join-Path \$startMenu ''Personal Workbench\.lnk''') | Should Be $true
    }
}
