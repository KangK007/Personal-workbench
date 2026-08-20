[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,
    [string]$ShortcutName = 'Personal Workbench.lnk'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "The shortcut target is not a file: $target"
}

# Chinese app name 'Ge Ren Gong Zuo Tai' built from code points to keep
# this script ASCII-safe (no encoding corruption on non-ASCII paths).
$chineseName = -join ([char[]](0x4E2A, 0x4EBA, 0x5DE5, 0x4F5C, 0x53F0))

# Resolve entry-point directories with GetFolderPath (same reliable API that
# resolves Desktop; do not rely on $env:APPDATA which may be unset in some
# automation sessions).
$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop)) {
    throw 'Unable to resolve the current Windows Desktop folder.'
}
$startMenu = [Environment]::GetFolderPath('Programs')
if ([string]::IsNullOrWhiteSpace($startMenu)) {
    throw 'Unable to resolve the Start Menu Programs folder.'
}
if (-not (Test-Path -LiteralPath $startMenu -PathType Container)) {
    throw "Start Menu Programs folder not found: $startMenu"
}

$workingDirectory = Split-Path -Parent $target
$shell = New-Object -ComObject WScript.Shell

function Update-Shortcut {
    param(
        [string]$Path,
        [switch]$Required
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        if ($Required) {
            throw "Required shortcut parent not found: $parent"
        }
        Write-Output "SKIP (parent missing): $Path"
        return
    }
    try {
        $shortcut = $shell.CreateShortcut($Path)
        $shortcut.TargetPath = $target
        $shortcut.WorkingDirectory = $workingDirectory
        $shortcut.IconLocation = "$target,0"
        $shortcut.Description = 'Launch the latest Personal Workbench Windows build'
        $shortcut.Save()
        Write-Output "Shortcut updated: $Path -> $target"
    } catch {
        if ($Required) {
            throw "Failed to update required shortcut $Path : $($_.Exception.Message)"
        }
        # An optional protected Start Menu entry must not block the desktop link.
        Write-Output "WARN: failed to update $Path : $($_.Exception.Message)"
    }
}

Update-Shortcut -Path (Join-Path $desktop $ShortcutName) -Required
Update-Shortcut -Path (Join-Path $startMenu 'Personal Workbench.lnk')
Update-Shortcut -Path (Join-Path $startMenu ($chineseName + '.lnk'))

Write-Output 'All software entry points updated.'
