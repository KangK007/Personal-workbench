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

# $LASTEXITCODE 只由**原生命令**设置，并且会**从调用方会话继承**：子脚本自己不
# 归零，调用方拿到的就还是它进来时的那个值。本脚本成功路径的收尾全是 cmdlet
# （Copy-Item / Compress-Archive / 安全删除助手都不碰该变量），于是一次**成功的**
# 打包可能对外报出非零退出码 —— 2026-09-20 实测：直接调用返回 -1，而 dist/ 其实
# 已正确刷新、$? 为 True，调用方据此判成败会把成功当失败。
# 真实失败一律由 throw 终止、走不到这一行，故此处归零是安全的。
# 与 build_windows.ps1 末尾同一处理（那里防的是 robocopy 的 0-7 泄漏）。
$global:LASTEXITCODE = 0
