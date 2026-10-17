[CmdletBinding()]
param(
    [switch]$SkipPackage,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Test-LocalAuthenticode.ps1')

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$versionText = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'pubspec.yaml')
if ($versionText -notmatch '(?m)^version:\s*([^\s]+)') {
    throw 'The application version could not be read from pubspec.yaml.'
}
$version = $Matches[1]
$distRoot = Join-Path $projectRoot 'dist'
$stagedApp = Join-Path $distRoot 'windows\app\personal_workbench.exe'
$setupPath = Join-Path $distRoot "PersonalWorkbench_$version`_windows_setup.exe"
$setupScript = Join-Path $projectRoot 'packaging\windows\PersonalWorkbench.iss'

if (-not $SkipPackage.IsPresent) {
    $packageArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $PSScriptRoot 'package_windows_release.ps1'),
        '-Configuration', 'release'
    )
    if ($SkipBuild.IsPresent) {
        $packageArguments += '-SkipBuild'
    }
    & powershell.exe @packageArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Windows release staging failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path -LiteralPath $stagedApp -PathType Leaf)) {
    throw "The staged Windows Release app is missing: $stagedApp"
}
$stagedVersion = (Get-Item -LiteralPath $stagedApp).VersionInfo.ProductVersion
$versionName = ($version -split '\+', 2)[0]
if (-not $stagedVersion.StartsWith($versionName, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "The staged Windows Release version is $stagedVersion, expected a version starting with $versionName. Rebuild the package."
}

$signingStatePath = Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchSigning\signing-state.json'
if (-not (Test-Path -LiteralPath $signingStatePath -PathType Leaf)) {
    throw 'Windows local signing state is missing. Run tool\setup_local_signing.ps1 -WindowsOnly.'
}
$thumbprint = ([string](Get-Content -Raw -LiteralPath $signingStatePath | ConvertFrom-Json).windowsThumbprint).Replace(' ', '').ToUpperInvariant()
if (-not (Test-LocalAuthenticodeSignature -Path $stagedApp -ExpectedThumbprint $thumbprint)) {
    throw 'The staged Windows Release executable has an invalid signature.'
}

$compilerCandidates = @(
    $env:INNO_SETUP_ISCC,
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$compiler = $compilerCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $compiler) {
    throw 'Inno Setup ISCC.exe was not found. Install Inno Setup 6/7 or set INNO_SETUP_ISCC.'
}

& $compiler "/DAppVersion=$version" $setupScript
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    throw "The installer was not created: $setupPath"
}

& (Join-Path $PSScriptRoot 'sign_windows_release.ps1') -Path $setupPath -Thumbprint $thumbprint
if (-not (Test-LocalAuthenticodeSignature -Path $setupPath -ExpectedThumbprint $thumbprint)) {
    throw 'The compiled installer has an invalid signature.'
}

$hash = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash
$checksumPath = "$setupPath.sha256"
"$hash *$([System.IO.Path]::GetFileName($setupPath))" |
    Set-Content -LiteralPath $checksumPath -Encoding ASCII
$distPath = [System.IO.Path]::GetFullPath($distRoot).TrimEnd('\')
$projectPath = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
if (-not $distPath.Equals((Join-Path $projectPath 'dist'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The Windows installer output path validation failed.'
}
Get-ChildItem -LiteralPath $distPath -Filter 'PersonalWorkbench_*_windows_setup.exe' -File |
    Where-Object { $_.FullName -ne $setupPath } |
    ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force
        Write-Output "Removed stale Windows installer: $($_.Name)"
    }
Write-Output "Windows setup installer: $setupPath"
Write-Output "SHA-256: $hash"
Write-Output "SHA-256 checksum file: $checksumPath"
$global:LASTEXITCODE = 0
