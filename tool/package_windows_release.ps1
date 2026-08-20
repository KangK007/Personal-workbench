[CmdletBinding()]
param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'release',
    [switch]$SkipBuild,
    [switch]$Install
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

if (-not $SkipBuild.IsPresent) {
    & powershell.exe @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $buildScript,
        '-Configuration', $Configuration
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Windows $Configuration build failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path -LiteralPath $sourceExecutable -PathType Leaf)) {
    throw "Windows build executable not found: $sourceExecutable"
}

$versionLine = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') |
    Where-Object { $_ -match '^version:\s*(\S+)' } |
    Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s*(\S+)') {
    throw 'The application version could not be read from pubspec.yaml.'
}
$version = $Matches[1]

$distributionRoot = Join-Path $projectRoot 'dist\windows'
$packageApp = Join-Path $distributionRoot 'app'
$archive = Join-Path $projectRoot "dist\PersonalWorkbench_$version`_windows.zip"

$resolvedDistributionRoot = [System.IO.Path]::GetFullPath($distributionRoot).TrimEnd('\')
$resolvedProjectRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
if (-not $resolvedDistributionRoot.StartsWith(
        "$resolvedProjectRoot\dist\",
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'The Windows distribution path validation failed.'
}

if (Test-Path -LiteralPath $distributionRoot) {
    Remove-Item -LiteralPath $distributionRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageApp | Out-Null
Get-ChildItem -LiteralPath $releaseRoot -Force |
    Copy-Item -Destination $packageApp -Recurse -Force

$packagingSource = Join-Path $projectRoot 'packaging\windows'
Get-ChildItem -LiteralPath $packagingSource -File |
    Copy-Item -Destination $distributionRoot -Force

if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $distributionRoot '*') -DestinationPath $archive -CompressionLevel Optimal

if ($Install.IsPresent) {
    $installer = Join-Path $distributionRoot 'Install-PersonalWorkbench.ps1'
    & powershell.exe @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $installer
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Windows installation failed with exit code $LASTEXITCODE"
    }
}

Write-Output "Windows distribution directory: $distributionRoot"
Write-Output "Windows installer archive: $archive"
