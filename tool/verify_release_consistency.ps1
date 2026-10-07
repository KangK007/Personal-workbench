[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$RequireInstalled,
    [switch]$CleanStaleArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

$pubspec = Join-Path $ProjectRoot 'pubspec.yaml'
$versionLine = Get-Content -LiteralPath $pubspec |
    Where-Object { $_ -match '^version:\s*(\S+)' } |
    Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s*(\S+)') {
    throw 'Unable to read the canonical version from pubspec.yaml.'
}
$version = $Matches[1]
$parts = $version -split '\+', 2
$versionName = $parts[0]
$versionCode = if ($parts.Count -eq 2) { $parts[1] } else { '1' }

$installDirectory = Join-Path $env:LOCALAPPDATA 'Programs\PersonalWorkbench'
$installedExe = Join-Path $installDirectory 'personal_workbench.exe'
$shell = New-Object -ComObject WScript.Shell

function Assert-ShortcutTarget([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required shortcut: $Path"
    }
    $shortcut = $shell.CreateShortcut($Path)
    $actual = [System.IO.Path]::GetFullPath($shortcut.TargetPath)
    $expected = [System.IO.Path]::GetFullPath($installedExe)
    if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Shortcut points to '$actual' instead of '$expected': $Path"
    }
}

if ($RequireInstalled -or (Test-Path -LiteralPath $installedExe -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) {
        throw "Installed executable is missing: $installedExe"
    }
    $fileVersion = (Get-Item -LiteralPath $installedExe).VersionInfo.ProductVersion
    if ($fileVersion -and -not $fileVersion.StartsWith($versionName, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Installed executable version '$fileVersion' does not match canonical version '$versionName'."
    }

    $desktop = [Environment]::GetFolderPath('Desktop')
    $startMenu = [Environment]::GetFolderPath('Programs')
    $chineseName = -join ([char[]](0x4E2A, 0x4EBA, 0x5DE5, 0x4F5C, 0x53F0))
    Assert-ShortcutTarget (Join-Path $desktop 'Personal Workbench.lnk')
    Assert-ShortcutTarget (Join-Path $startMenu 'Personal Workbench.lnk')
    Assert-ShortcutTarget (Join-Path $startMenu ($chineseName + '.lnk'))

    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $startup = (Get-ItemProperty -Path $runKey -Name PersonalWorkbench -ErrorAction SilentlyContinue).PersonalWorkbench
    if ($startup) {
        $startupTarget = [regex]::Match($startup, '^\s*"([^"]+)"|^\s*(\S+)').Groups | Where-Object { $_.Value -and $_.Name -in '1','2' } | Select-Object -First 1
        $startupPath = if ($startupTarget) { $startupTarget.Value } else { $startup }
        if (-not ([System.IO.Path]::GetFullPath($startupPath)).Equals([System.IO.Path]::GetFullPath($installedExe), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Startup entry points to '$startupPath' instead of '$installedExe'."
        }
    }
}

$dist = Join-Path $ProjectRoot 'dist'
$currentArtifactPrefixes = @(
    "PersonalWorkbench_${versionName}_${versionCode}",
    "PersonalWorkbench_${versionName}+${versionCode}"
)
$stale = Get-ChildItem -LiteralPath $dist -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $artifactName = $_.Name
        $artifactName -match '^PersonalWorkbench_.*\.(zip|apk)$' -and
        -not ($currentArtifactPrefixes | Where-Object {
            $artifactName.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase)
        })
    }
if ($stale) {
    if ($CleanStaleArtifacts) {
        foreach ($artifact in $stale) {
            Remove-Item -LiteralPath $artifact.FullName -Force
            Write-Output "Removed stale artifact: $($artifact.Name)"
            $detachedSignature = "$($artifact.FullName).p7s"
            if (Test-Path -LiteralPath $detachedSignature -PathType Leaf) {
                Remove-Item -LiteralPath $detachedSignature -Force
                Write-Output "Removed stale artifact signature: $([System.IO.Path]::GetFileName($detachedSignature))"
            }
        }
    } else {
        throw "Stale release artifacts found: $($stale.Name -join ', ')"
    }
}

Write-Output "Release consistency verified: $version"
