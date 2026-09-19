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

# 安全删除助手：垫片环境下 Remove-Item 会「报错但已生效」，
# 故删除一律走状态校验式助手，避免构建死在产物复制之前。
. (Join-Path $PSScriptRoot 'lib\Remove-Verified.ps1')

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

Remove-Verified -LiteralPath $distributionRoot -Recurse
New-Item -ItemType Directory -Force -Path $packageApp | Out-Null
Get-ChildItem -LiteralPath $releaseRoot -Force |
    Copy-Item -Destination $packageApp -Recurse -Force

$packagingSource = Join-Path $projectRoot 'packaging\windows'
Get-ChildItem -LiteralPath $packagingSource -File |
    Copy-Item -Destination $distributionRoot -Force

Remove-Verified -LiteralPath $archive
Compress-Archive -Path (Join-Path $distributionRoot '*') -DestinationPath $archive -CompressionLevel Optimal

# 清理历史版本 zip：新版本名与旧版本名不同，仅按当前版本名删除会漏掉旧包，
# 导致 dist\ 里同时堆着多个版本的 Windows 安装包。与 build_android.ps1 的
# 「按同一形态模式清理」保持一致。
# 放在 Compress-Archive **之后**：重建若中途失败，旧的可用安装包仍然保留。
$distRoot = Join-Path $projectRoot 'dist'
$staleArchives = @(
    Get-ChildItem -LiteralPath $distRoot -Filter 'PersonalWorkbench_*_windows.zip' -File |
        Where-Object { $_.Name -ne [System.IO.Path]::GetFileName($archive) }
)
foreach ($staleArchive in $staleArchives) {
    Write-Output "Removing stale archive: $($staleArchive.Name)"
    Remove-Verified -LiteralPath $staleArchive.FullName
}

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
