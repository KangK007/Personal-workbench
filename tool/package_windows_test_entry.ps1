param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'release',
    [switch]$SkipBuild,
    [switch]$UseCurrentDatabase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Configuration = $Configuration.ToLowerInvariant()

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$buildScript = Join-Path $projectRoot 'tool\build_windows.ps1'
$configurationDirectory = switch ($Configuration) {
    'debug' { 'Debug' }
    'profile' { 'Profile' }
    'release' { 'Release' }
}
$releaseRoot = Join-Path $projectRoot (
    "build\windows\x64\runner\$configurationDirectory"
)
$sourceExecutable = Join-Path $releaseRoot 'personal_workbench.exe'
$packageRoot = Join-Path $projectRoot 'build\desktop_test_entry'

$databasePath = $null
if (-not $UseCurrentDatabase.IsPresent) {
    $testDataRoot = Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchDesktopTest'
    New-Item -ItemType Directory -Force -Path $testDataRoot | Out-Null
    $databasePath = Join-Path $testDataRoot 'workbench_test.db'
}

if (-not $SkipBuild.IsPresent) {
    $buildArguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $buildScript,
        '-Configuration', $Configuration
    )
    if ($null -ne $databasePath) {
        $buildArguments += @('-DatabasePath', $databasePath)
    }
    & powershell.exe @buildArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Windows test build failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path -LiteralPath $sourceExecutable)) {
    throw "Windows build executable not found: $sourceExecutable"
}

$runningPackageProcesses = @(
    Get-Process personal_workbench -ErrorAction SilentlyContinue |
        Where-Object {
            $processPath = $_.Path
            $null -ne $processPath -and $processPath.StartsWith(
                $packageRoot,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        }
)
if ($runningPackageProcesses.Count -gt 0) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $packageRoot = Join-Path $projectRoot "build\desktop_test_entry_$timestamp"
    Write-Warning 'The current software test entry is running; packaging to a versioned directory instead.'
}
$packageExecutable = Join-Path $packageRoot 'personal_workbench.exe'

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
Get-ChildItem -LiteralPath $releaseRoot -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $packageRoot -Recurse -Force
}

if (-not (Test-Path -LiteralPath $packageExecutable)) {
    throw "Packaged executable not found: $packageExecutable"
}

Copy-Item -LiteralPath (Join-Path $projectRoot 'packaging\windows\emergency_recovery.ps1') -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'packaging\windows\emergency_recovery.cmd') -Destination $packageRoot -Force

Write-Output "Windows software test entry: $packageExecutable"
if ($null -ne $databasePath) {
    Write-Output "Test database: $databasePath"
}

