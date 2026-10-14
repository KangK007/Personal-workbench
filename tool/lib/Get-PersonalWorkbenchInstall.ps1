function Get-PersonalWorkbenchInstall {
    $innoKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{F2B0B029-083A-45C6-AB24-8F203AE46440}_is1'
    if (Test-Path -LiteralPath $innoKey) {
        $location = [string](Get-ItemProperty -LiteralPath $innoKey).InstallLocation
        if ([string]::IsNullOrWhiteSpace($location)) {
            throw 'The Personal Workbench installer registration has no InstallLocation.'
        }
        return [pscustomobject]@{
            ManagedByInstaller = $true
            Executable = Join-Path $location 'personal_workbench.exe'
        }
    }

    return [pscustomobject]@{
        ManagedByInstaller = $false
        Executable = Join-Path $env:LOCALAPPDATA 'Programs\PersonalWorkbench\personal_workbench.exe'
    }
}
