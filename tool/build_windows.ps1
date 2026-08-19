[CmdletBinding()]
param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'release',
    [switch]$Clean,
    [string]$DatabasePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Configuration = $Configuration.ToLowerInvariant()

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($projectRoot)
    $digest = $sha256.ComputeHash($pathBytes)
} finally {
    $sha256.Dispose()
}
$projectKey = -join ($digest[0..5] | ForEach-Object { $_.ToString('x2') })
$aliasRoot = Join-Path $env:LOCALAPPDATA "PersonalWorkbenchBuild\$projectKey"
$sourceLink = Join-Path $aliasRoot 'source'

New-Item -ItemType Directory -Force -Path $aliasRoot | Out-Null
if (Test-Path -LiteralPath $sourceLink) {
    $link = Get-Item -LiteralPath $sourceLink -Force
    $target = (Resolve-Path -LiteralPath $link.Target).Path
    if ($link.LinkType -ne 'Junction' -or
        -not [string]::Equals(
            $target,
            $projectRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Build alias already exists but points elsewhere: $sourceLink"
    }
} else {
    New-Item -ItemType Junction -Path $sourceLink -Target $projectRoot |
        Out-Null
}

$cmakeCache = Join-Path $projectRoot 'build\windows\x64\CMakeCache.txt'
$aliasForCmake = $sourceLink.Replace('\', '/')
$needsClean = $Clean.IsPresent
if (Test-Path -LiteralPath $cmakeCache) {
    $cacheContents = Get-Content -Raw -LiteralPath $cmakeCache
    $needsClean = $needsClean -or -not $cacheContents.Contains($aliasForCmake)
}

Push-Location -LiteralPath $sourceLink
try {
    if ($needsClean) {
        & flutter clean
        if ($LASTEXITCODE -ne 0) {
            throw "flutter clean failed with exit code $LASTEXITCODE"
        }
    }

    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE"
    }

    $buildArguments = @('build', 'windows', "--$Configuration", '--no-pub')
    if (-not [string]::IsNullOrWhiteSpace($DatabasePath)) {
        $buildArguments += "--dart-define=WORKBENCH_DATABASE_PATH=$DatabasePath"
    }
    & flutter @buildArguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build windows failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$configurationDirectory = switch ($Configuration) {
    'debug' { 'Debug' }
    'profile' { 'Profile' }
    'release' { 'Release' }
}
$executable = Join-Path $projectRoot (
    "build\windows\x64\runner\$configurationDirectory\personal_workbench.exe"
)
if (-not (Test-Path -LiteralPath $executable)) {
    throw "Build completed without the expected executable: $executable"
}

$shortcutScript = Join-Path $projectRoot 'tool\update_desktop_shortcut.ps1'
& $shortcutScript -TargetPath $executable

Write-Output "Windows build completed: $executable"
