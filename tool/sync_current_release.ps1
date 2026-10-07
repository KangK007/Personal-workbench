[CmdletBinding()]
param(
    [switch]$BuildWindows,
    [switch]$Install
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$versionLine = Get-Content (Join-Path $projectRoot 'pubspec.yaml') |
    Where-Object { $_ -match '^version:\s*(\S+)' } | Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s*(\S+)') { throw 'Cannot read pubspec version.' }
$version = $Matches[1]

if ($BuildWindows) {
    $packageArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',
        (Join-Path $projectRoot 'tool\package_windows_release.ps1'))
    if ($Install) { $packageArgs += '-Install' }
    & powershell.exe @packageArgs
    if ($LASTEXITCODE -ne 0) { throw "Windows package failed: $LASTEXITCODE" }
} else {
    $installedExe = Join-Path $env:LOCALAPPDATA 'Programs\PersonalWorkbench\personal_workbench.exe'
    if (Test-Path -LiteralPath $installedExe -PathType Leaf) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tool\update_all_shortcuts.ps1') -TargetPath $installedExe
        if ($LASTEXITCODE -ne 0) { throw "Shortcut synchronization failed: $LASTEXITCODE" }
    }
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tool\verify_release_consistency.ps1') -CleanStaleArtifacts
if ($LASTEXITCODE -ne 0) { throw 'Release consistency verification failed.' }
Write-Output "Current release synchronized: $version"
