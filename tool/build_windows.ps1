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
$buildCacheRoot = Join-Path $env:LOCALAPPDATA "PersonalWorkbenchBuild\$projectKey"
$sourceCopy = Join-Path $buildCacheRoot 'source-copy'
$resolvedCacheBase = [System.IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchBuild')
).TrimEnd('\')
$resolvedSourceCopy = [System.IO.Path]::GetFullPath($sourceCopy)
if (-not $resolvedSourceCopy.StartsWith(
        "$resolvedCacheBase\",
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'The ASCII build source path validation failed.'
}
New-Item -ItemType Directory -Force -Path $sourceCopy | Out-Null

& robocopy.exe $projectRoot $sourceCopy /MIR /R:2 /W:1 /NP /NFL /NDL /NJH /NJS `
    /XD .dart_tool build dist .git .idea `
    /XF .git | Out-Null
$sourceCopyExitCode = $LASTEXITCODE
if ($sourceCopyExitCode -ge 8) {
    throw "Source staging failed with robocopy exit code $sourceCopyExitCode"
}

Push-Location -LiteralPath $sourceCopy
try {
    if ($Clean.IsPresent) {
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
$stagedBuild = Join-Path $sourceCopy 'build\windows\x64'
$projectBuild = Join-Path $projectRoot 'build\windows\x64'
New-Item -ItemType Directory -Force -Path $projectBuild | Out-Null
& robocopy.exe $stagedBuild $projectBuild /MIR /R:2 /W:1 /NP /NFL /NDL /NJH /NJS |
    Out-Null
$artifactCopyExitCode = $LASTEXITCODE
if ($artifactCopyExitCode -ge 8) {
    throw "Windows artifact copy failed with robocopy exit code $artifactCopyExitCode"
}

$executable = Join-Path $projectBuild (
    "runner\$configurationDirectory\personal_workbench.exe"
)
if (-not (Test-Path -LiteralPath $executable)) {
    throw "Build completed without the expected executable: $executable"
}

$shortcutScript = Join-Path $projectRoot 'tool\update_all_shortcuts.ps1'
& $shortcutScript -TargetPath $executable

Write-Output "Windows build completed: $executable"

# Robocopy uses 0-7 for successful copies; do not leak those values to callers.
$global:LASTEXITCODE = 0
