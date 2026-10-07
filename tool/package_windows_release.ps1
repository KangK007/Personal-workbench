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

if ($Configuration -eq 'release') {
    $signingScript = Join-Path $projectRoot 'tool\sign_windows_release.ps1'
    & powershell.exe @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $signingScript,
        '-Path', $sourceExecutable
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Windows Release Authenticode signing failed with exit code $LASTEXITCODE"
    }
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

if ($Configuration -eq 'release') {
    $signingScript = Join-Path $projectRoot 'tool\sign_windows_release.ps1'
    $signedPackageFiles = @(
        Get-ChildItem -LiteralPath $packageApp -Recurse -File |
            Where-Object { $_.Extension -in '.exe', '.dll' } |
            ForEach-Object { $_.FullName }
        Get-ChildItem -LiteralPath $distributionRoot -Recurse -File -Filter '*.ps1' |
            ForEach-Object { $_.FullName }
    )
    if ($signedPackageFiles.Count -eq 0) {
        throw 'No Authenticode-signable Windows release files were found.'
    }
    # Invoke the script in-process so its string[] parameter receives the
    # complete file list as one array (child powershell.exe treats repeated
    # -Path switches as duplicate parameter binding).
    & $signingScript -Path $signedPackageFiles
    if ($LASTEXITCODE -ne 0) {
        throw "Windows distribution Authenticode signing failed with exit code $LASTEXITCODE"
    }

    $signingStatePath = Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchSigning\signing-state.json'
    $expectedThumbprint = ([string](Get-Content -Raw -LiteralPath $signingStatePath | ConvertFrom-Json).windowsThumbprint).Replace(' ', '').ToUpperInvariant()
    foreach ($signedFile in $signedPackageFiles) {
        $signature = Get-AuthenticodeSignature -LiteralPath $signedFile
        $actualThumbprint = if ($signature.SignerCertificate) {
            $signature.SignerCertificate.Thumbprint.Replace(' ', '').ToUpperInvariant()
        } else {
            ''
        }
        if ($signature.Status -ne 'Valid' -or $actualThumbprint -ne $expectedThumbprint) {
            throw "Windows distribution signature verification failed: $signedFile (status: $($signature.Status), thumbprint: $actualThumbprint)"
        }
    }
}

Remove-Verified -LiteralPath $archive
Compress-Archive -Path (Join-Path $distributionRoot '*') -DestinationPath $archive -CompressionLevel Optimal

if ($Configuration -eq 'release') {
    $signingStatePath = Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchSigning\signing-state.json'
    $signingState = Get-Content -Raw -LiteralPath $signingStatePath | ConvertFrom-Json
    $certificate = Get-ChildItem "Cert:\CurrentUser\My\$($signingState.windowsThumbprint)" -ErrorAction SilentlyContinue
    if (-not $certificate -or -not $certificate.HasPrivateKey) {
        throw 'Windows release certificate with a private key is required to sign the package archive.'
    }
    $archiveSigningScript = Join-Path $projectRoot 'tool\sign_windows_archive.ps1'
    $pwsh = Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $pwsh) {
        throw 'PowerShell 7 (pwsh.exe) is required to create the detached CMS archive signature.'
    }
    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $archiveSigningScript `
        -Archive $archive -Thumbprint $signingState.windowsThumbprint
    if ($LASTEXITCODE -ne 0) {
        throw "Windows package CMS signing failed with exit code $LASTEXITCODE"
    }
}

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
    $staleSignature = "$($staleArchive.FullName).p7s"
    if (Test-Path -LiteralPath $staleSignature -PathType Leaf) {
        Remove-Verified -LiteralPath $staleSignature
    }
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
} else {
    $installedExecutable = Join-Path $env:LOCALAPPDATA 'Programs\PersonalWorkbench\personal_workbench.exe'
    if (Test-Path -LiteralPath $installedExecutable -PathType Leaf) {
        & (Join-Path $projectRoot 'tool\update_all_shortcuts.ps1') -TargetPath $installedExecutable
        if ($LASTEXITCODE -ne 0) {
            throw "Restoring installed Windows shortcuts failed with exit code $LASTEXITCODE"
        }
    }
}

$consistencyArguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $projectRoot 'tool\verify_release_consistency.ps1'),
    '-CleanStaleArtifacts'
)
if ($Install.IsPresent) {
    $consistencyArguments += '-RequireInstalled'
}
& powershell.exe @consistencyArguments
if ($LASTEXITCODE -ne 0) {
    throw 'Release consistency verification failed.'
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
