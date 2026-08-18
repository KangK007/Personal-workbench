$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $packageRoot 'app'
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs'
$installDirectory = Join-Path $installRoot 'PersonalWorkbench'
$executable = Join-Path $installDirectory 'personal_workbench.exe'

if (-not (Test-Path -LiteralPath (Join-Path $source 'personal_workbench.exe'))) {
    throw 'The package is incomplete: personal_workbench.exe is missing.'
}

New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $installDirectory -Recurse -Force

$shell = New-Object -ComObject WScript.Shell
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$shortcut = $shell.CreateShortcut((Join-Path $startMenu 'Personal Workbench.lnk'))
$shortcut.TargetPath = $executable
$shortcut.WorkingDirectory = $installDirectory
$shortcut.IconLocation = "$executable,0"
$shortcut.Save()

Write-Host "Personal Workbench was installed to: $installDirectory"
Start-Process -FilePath $executable -WorkingDirectory $installDirectory

