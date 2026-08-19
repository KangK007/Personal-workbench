$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $packageRoot 'app'
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs'
$installDirectory = Join-Path $installRoot 'PersonalWorkbench'
$executable = Join-Path $installDirectory 'personal_workbench.exe'

if (-not (Test-Path -LiteralPath (Join-Path $source 'personal_workbench.exe'))) {
    throw 'The package is incomplete: personal_workbench.exe is missing.'
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'emergency_recovery.ps1'))) {
    throw 'The package is incomplete: emergency_recovery.ps1 is missing.'
}

New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $installDirectory -Recurse -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'emergency_recovery.ps1') -Destination $installDirectory -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'emergency_recovery.cmd') -Destination $installDirectory -Force

$shell = New-Object -ComObject WScript.Shell
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$shortcutPaths = @(
    (Join-Path $startMenu 'Personal Workbench.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Personal Workbench.lnk')
)
foreach ($shortcutPath in $shortcutPaths) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $executable
    $shortcut.WorkingDirectory = $installDirectory
    $shortcut.IconLocation = "$executable,0"
    $shortcut.Description = 'Launch the latest Personal Workbench Windows build'
    $shortcut.Save()
}

Write-Host "Personal Workbench was installed to: $installDirectory"
Start-Process -FilePath $executable -WorkingDirectory $installDirectory
