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

    # 预建插件符号链接。本机调用 CreateSymbolicLink 时，链接会被正确建好，
    # 但调用方收到 ERROR_FILE_NOT_FOUND(2) 的假错误，flutter_tools 据此中止构建。
    # flutter_tools 的逻辑是「链接已存在就跳过」，故在此先行备好。
    # 完整成因与验证过程见 tool\prelink_plugin_symlinks.dart 顶部注释。
    $dartExecutable = $null
    $flutterCommand = Get-Command -Name 'flutter' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $flutterCommand -and $flutterCommand.Source) {
        $dartCandidate = Join-Path (Split-Path -Parent $flutterCommand.Source) 'cache\dart-sdk\bin\dart.exe'
        if (Test-Path -LiteralPath $dartCandidate -PathType Leaf) {
            $dartExecutable = $dartCandidate
        }
    }
    if (-not $dartExecutable) {
        $dartCommand = Get-Command -Name 'dart' -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $dartCommand -and $dartCommand.Source) {
            $dartExecutable = $dartCommand.Source
        }
    }
    if (-not $dartExecutable) {
        throw 'dart executable not found; cannot pre-create plugin symlinks.'
    }

    & $dartExecutable (Join-Path $PSScriptRoot 'prelink_plugin_symlinks.dart') $sourceCopy
    if ($LASTEXITCODE -ne 0) {
        throw "Plugin symlink pre-creation failed with exit code $LASTEXITCODE"
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

# 刷新软件入口（桌面 + 开始菜单）。
#
# 这一步**不得**让构建失败。原因：package_windows_release.ps1 只看本脚本的进程
# 退出码，此处一旦抛错，整个 `dist\` 就不发布 —— 而产物其实已经构建成功了
# （「进程退出码 1」与「构建失败」并不等价）。2026-09-20 实测踩到：`√ Built …exe`
# 已经打印，却因桌面 .lnk 被 Explorer 瞬时占用而整包不发，事后手动重跑即成。
#
# 降级为警告的另一个依据：这一步只是把入口**临时**指向产物目录，最终由
# Install-PersonalWorkbench.ps1 把三个入口收敛到稳定安装目录。所以这里失败
# 不会把用户引向坏路径。
# update_all_shortcuts.ps1 内部已自带重试，能走到这里说明是持续性失败。
$shortcutScript = Join-Path $projectRoot 'tool\update_all_shortcuts.ps1'
$shortcutRefreshOk = $true
try {
    & $shortcutScript -TargetPath $executable
} catch {
    $shortcutRefreshOk = $false
    Write-Warning (
        'Shortcut refresh failed (non-fatal: the build itself succeeded): ' +
        $_.Exception.Message
    )
}

Write-Output "Windows build completed: $executable"
if ($shortcutRefreshOk) {
    Write-Output 'Software entry points refreshed: desktop + start menu.'
} else {
    Write-Output (
        'NOTE: software entry points were NOT refreshed. The build output and the ' +
        'distribution archive are still valid; rerun ' +
        "& '$shortcutScript' -TargetPath '$executable' to fix the shortcuts."
    )
}

# Robocopy uses 0-7 for successful copies; do not leak those values to callers.
$global:LASTEXITCODE = 0
