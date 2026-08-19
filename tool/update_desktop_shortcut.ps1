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

$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop)) {
    throw 'Unable to resolve the current Windows Desktop folder.'
}

$shortcutPath = Join-Path $desktop $ShortcutName
$workingDirectory = Split-Path -Parent $target
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.WorkingDirectory = $workingDirectory
$shortcut.IconLocation = "$target,0"
$shortcut.Description = 'Launch the latest Personal Workbench Windows build'
$shortcut.Save()

Write-Output "Desktop shortcut updated: $shortcutPath -> $target"
