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
New-Item -ItemType Directory -Force -Path $buildCacheRoot | Out-Null
if (Test-Path -LiteralPath $sourceCopy) {
    $existingSourceCopy = Get-Item -LiteralPath $sourceCopy -Force
    if ($existingSourceCopy.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to replace a linked build source directory: $sourceCopy"
    }
    [System.IO.Directory]::Delete("\\?\$resolvedSourceCopy", $true)
}
New-Item -ItemType Directory -Force -Path $sourceCopy | Out-Null

$copyArguments = @(
    $projectRoot,
    $sourceCopy,
    '/E', '/R:2', '/W:1',
    '/XD', '.git', '.dart_tool', 'build', 'dist', 'coverage',
    '.idea', '.vscode',
    (Join-Path $projectRoot 'windows\flutter\ephemeral'),
    (Join-Path $projectRoot 'raw'),
    (Join-Path $projectRoot 'data'),
    (Join-Path $projectRoot 'original'),
    (Join-Path $projectRoot 'experiment'),
    (Join-Path $projectRoot 'measurements'),
    '/XF', '.git', 'flutter_*.log',
    '/NFL', '/NDL', '/NJH', '/NJS', '/NP'
)
& robocopy.exe @copyArguments | Out-Null
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
    if ($artifactCopyExitCode -band 8) {
        $locked = Get-Process -Name 'personal_workbench' -ErrorAction SilentlyContinue
        if ($locked) {
            throw "Windows artifact copy failed (robocopy exit $artifactCopyExitCode): " +
                'personal_workbench.exe is still running and locks the build output. ' +
                'Close the running instance (or Stop-Process -Name personal_workbench) and rerun.'
        }
    }
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
