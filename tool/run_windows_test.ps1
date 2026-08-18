param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'release',
    [switch]$SkipBuild,
    [switch]$UseCurrentDatabase,
    [switch]$Wait
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
$executable = Join-Path $projectRoot (
    "build\windows\x64\runner\$configurationDirectory\personal_workbench.exe"
)

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

if (-not (Test-Path -LiteralPath $executable)) {
    throw "Windows test executable not found: $executable"
}

if ($SkipBuild.IsPresent -and $null -ne $databasePath) {
    Write-Warning 'SkipBuild assumes the existing executable was compiled with the same isolated test database.'
}

Write-Output "Windows test entry: $executable"
if ($null -ne $databasePath) {
    Write-Output "Test database: $databasePath"
}

if ($Wait.IsPresent) {
    & $executable
} else {
    Start-Process -FilePath $executable -WorkingDirectory (Split-Path -Parent $executable) | Out-Null
}

