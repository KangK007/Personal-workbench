[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$hooks = Join-Path $root '.githooks'
New-Item -ItemType Directory -Force -Path $hooks | Out-Null
git -C $root config core.hooksPath .githooks
Write-Output 'Git hooks configured: .githooks'
