$ErrorActionPreference = 'Stop'

$sourceCandidates = @(
    (Join-Path $PSScriptRoot 'app'),
    (Join-Path (Split-Path -Parent $PSScriptRoot) 'app')
)
$source = $sourceCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if (-not $source) {
    throw 'The package is incomplete: app directory is missing.'
}
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs'
$installDirectory = Join-Path $installRoot 'PersonalWorkbench'
$executable = Join-Path $installDirectory 'personal_workbench.exe'

if (-not (Test-Path -LiteralPath (Join-Path $source 'personal_workbench.exe'))) {
    throw 'The package is incomplete: personal_workbench.exe is missing.'
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'emergency_recovery.ps1'))) {
    throw 'The package is incomplete: emergency_recovery.ps1 is missing.'
}

Get-Process -Name personal_workbench -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
for ($attempt = 1; $attempt -le 8; $attempt++) {
    try {
        Copy-Item -Path (Join-Path $source '*') -Destination $installDirectory -Recurse -Force
        break
    } catch {
        if ($attempt -eq 8) {
            throw
        }
        Start-Sleep -Milliseconds (250 * $attempt)
    }
}
Copy-Item -Path (Join-Path $PSScriptRoot 'emergency_recovery.ps1') -Destination $installDirectory -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'emergency_recovery.cmd') -Destination $installDirectory -Force

$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = [Environment]::GetFolderPath('Programs')
if ([string]::IsNullOrWhiteSpace($desktop)) {
    throw 'Unable to resolve the current Windows Desktop folder.'
}
if ([string]::IsNullOrWhiteSpace($startMenu)) {
    throw 'Unable to resolve the Start Menu Programs folder.'
}
New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
$chineseName = -join ([char[]](0x4E2A, 0x4EBA, 0x5DE5, 0x4F5C, 0x53F0))
$shortcutPaths = @(
    (Join-Path $startMenu 'Personal Workbench.lnk'),
    (Join-Path $startMenu ($chineseName + '.lnk')),
    (Join-Path $desktop 'Personal Workbench.lnk')
)

# Install-time shortcut write, with the same bounded retry as
# tool\update_all_shortcuts.ps1. This file ships standalone inside the
# distribution, so it cannot dot-source the tool library -- the loop is
# duplicated on purpose.
#
# Why: Explorer holds a .lnk open for a moment while it re-reads the icon and
# re-renders the shell item, which happens right after the target executable is
# replaced by this very script. Save() then fails with "cannot save shortcut" /
# access-denied. The lock is transient, so retry instead of failing the install.
function Set-PersonalWorkbenchShortcut {
    param([string]$Path)

    $attempts = 5
    $lastMessage = 'unknown error'
    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        try {
            # Fresh object per attempt: a failed Save() can leave the previous
            # shortcut instance in an unusable state.
            $shortcut = $shell.CreateShortcut($Path)
            $shortcut.TargetPath = $executable
            $shortcut.WorkingDirectory = $installDirectory
            $shortcut.IconLocation = "$executable,0"
            $shortcut.Description = 'Launch the latest Personal Workbench Windows build'
            $shortcut.Save()
            return
        } catch {
            $lastMessage = $_.Exception.Message
            if ($attempt -lt $attempts) {
                $delayMs = [int](250 * [Math]::Pow(2, $attempt - 1))
                Write-Warning "Retrying shortcut write $attempt/$attempts for '$Path': $lastMessage"
                Start-Sleep -Milliseconds $delayMs
            }
        }
    }
    throw "Failed to write shortcut '$Path' after $attempts attempts: $lastMessage"
}

foreach ($shortcutPath in $shortcutPaths) {
    Set-PersonalWorkbenchShortcut -Path $shortcutPath
}

Write-Host "Personal Workbench was installed to: $installDirectory"
Start-Process -FilePath $executable -WorkingDirectory $installDirectory
