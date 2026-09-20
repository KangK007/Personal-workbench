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

# Number of Save() attempts per shortcut.
#
# Why retry: Explorer keeps the .lnk open for a moment while it re-reads the
# icon and re-renders the shell item -- most likely right after the target
# executable's icon resource itself changed. While that handle is open, Save()
# fails with "cannot save shortcut" / access-denied. The lock is *transient*
# (observed to clear within a second or two), so the correct response is a
# bounded retry, not an immediate hard failure.
#
# Observed 2026-09-20: build_windows.ps1 had already printed "Built ...exe"
# when this exact step threw, and because the desktop entry is -Required the
# exception bubbled out of the build script -> exit code 1 -> the release
# packaging script treated the whole build as failed and published nothing at
# all, even though the artifacts were complete and valid. Rerunning this script
# by hand then succeeded on the first attempt.
$saveAttempts = 5

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

    # Set-StrictMode is on: initialise before the loop closed over it.
    $lastMessage = 'unknown error'
    for ($attempt = 1; $attempt -le $saveAttempts; $attempt++) {
        try {
            # A fresh object per attempt: a failed Save() can leave the
            # previous shortcut instance in an unusable state.
            $shortcut = $shell.CreateShortcut($Path)
            $shortcut.TargetPath = $target
            $shortcut.WorkingDirectory = $workingDirectory
            $shortcut.IconLocation = "$target,0"
            $shortcut.Description = 'Launch the latest Personal Workbench Windows build'
            $shortcut.Save()
            Write-Output "Shortcut updated: $Path -> $target"
            return
        } catch {
            $lastMessage = $_.Exception.Message
            if ($attempt -ge $saveAttempts) {
                break
            }
            # Exponential backoff, 250/500/1000/2000 ms (~3.75 s total):
            # long enough for a shell icon-cache refresh to release the handle,
            # short enough not to stall a build.
            $delayMs = [int](250 * [Math]::Pow(2, $attempt - 1))
            Write-Output (
                "RETRY $attempt/$saveAttempts for $Path (transient lock?): $lastMessage"
            )
            Start-Sleep -Milliseconds $delayMs
        }
    }

    $failure = "Failed to update shortcut '$Path' after $saveAttempts attempts: $lastMessage"
    if ($Required) {
        throw $failure
    }
    # An optional protected Start Menu entry must not block the desktop link.
    Write-Output "WARN: $failure"
}

Update-Shortcut -Path (Join-Path $desktop $ShortcutName) -Required
Update-Shortcut -Path (Join-Path $startMenu 'Personal Workbench.lnk')
Update-Shortcut -Path (Join-Path $startMenu ($chineseName + '.lnk'))

Write-Output 'All software entry points updated.'
