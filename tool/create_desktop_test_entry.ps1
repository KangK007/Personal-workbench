param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'release',
    [string]$ShortcutName = 'PersonalWorkbench-Windows-Test.lnk'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Configuration = $Configuration.ToLowerInvariant()

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$runnerScript = Join-Path $projectRoot 'tool\run_windows_test.ps1'
$desktopPath = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktopPath)) {
    throw 'Unable to resolve the current Windows Desktop folder.'
}

$shortcutPath = Join-Path $desktopPath $ShortcutName
$powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
$configurationDirectory = switch ($Configuration) {
    'debug' { 'Debug' }
    'profile' { 'Profile' }
    'release' { 'Release' }
}
$executable = Join-Path $projectRoot (
    "build\windows\x64\runner\$configurationDirectory\personal_workbench.exe"
)

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershellPath
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runnerScript`" -Configuration $Configuration"
$shortcut.WorkingDirectory = $projectRoot
$shortcut.Description = 'Build and launch the Personal Workbench Windows isolated test environment'
if (Test-Path -LiteralPath $executable) {
    $shortcut.IconLocation = "$executable,0"
}
$shortcut.Save()

Write-Output "Desktop test entry created: $shortcutPath"

