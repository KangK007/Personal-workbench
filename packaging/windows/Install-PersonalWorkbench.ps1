$ErrorActionPreference = 'Stop'

$sourceCandidates = @(
    (Join-Path $PSScriptRoot 'app'),
    (Join-Path (Split-Path -Parent $PSScriptRoot) 'app')
)
$source = $sourceCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if (-not $source) {
    throw 'The package is incomplete: app directory is missing.'
}
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs'
$installDirectory = Join-Path $installRoot 'PersonalWorkbench'
$executable = Join-Path $installDirectory 'personal_workbench.exe'

if (-not (Test-Path -LiteralPath (Join-Path $source 'personal_workbench.exe'))) {
    throw 'The package is incomplete: personal_workbench.exe is missing.'
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'emergency_recovery.ps1'))) {
    throw 'The package is incomplete: emergency_recovery.ps1 is missing.'
}

Get-Process -Name personal_workbench -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
for ($attempt = 1; $attempt -le 8; $attempt++) {
    try {
        Copy-Item -Path (Join-Path $source '*') -Destination $installDirectory -Recurse -Force
        break
    } catch {
        if ($attempt -eq 8) {
            throw
        }
        Start-Sleep -Milliseconds (250 * $attempt)
    }
}
Copy-Item -Path (Join-Path $PSScriptRoot 'emergency_recovery.ps1') -Destination $installDirectory -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'emergency_recovery.cmd') -Destination $installDirectory -Force

$shell = New-Object -ComObject WScript.Shell
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$chineseName = -join ([char[]](0x4E2A, 0x4EBA, 0x5DE5, 0x4F5C, 0x53F0))
$shortcutPaths = @(
    (Join-Path $startMenu 'Personal Workbench.lnk'),
    (Join-Path $startMenu ($chineseName + '.lnk')),
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
