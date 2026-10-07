$ErrorActionPreference = 'Stop'

$installRoot = [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
$installDirectory = [System.IO.Path]::GetFullPath((Join-Path $installRoot 'PersonalWorkbench'))
$startMenu = [Environment]::GetFolderPath('Programs')
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcuts = @(
    (Join-Path $startMenu 'Personal Workbench.lnk'),
    (Join-Path $startMenu '个人工作台.lnk'),
    (Join-Path $desktop 'Personal Workbench.lnk')
)

if (-not $installDirectory.StartsWith($installRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The uninstall path validation failed.'
}

Get-Process personal_workbench -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($installDirectory, [System.StringComparison]::OrdinalIgnoreCase) } |
    Stop-Process

if (Test-Path -LiteralPath $installDirectory) {
    Remove-Item -LiteralPath $installDirectory -Recurse -Force
}
foreach ($shortcut in $shortcuts) {
    if (Test-Path -LiteralPath $shortcut) {
        Remove-Item -LiteralPath $shortcut -Force
    }
}

Remove-ItemProperty `
    -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
    -Name 'PersonalWorkbench' `
    -ErrorAction SilentlyContinue

Write-Host 'Personal Workbench was removed. Local app data and backups were preserved.'
