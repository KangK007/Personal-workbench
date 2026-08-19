[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$executable = Join-Path $PSScriptRoot 'personal_workbench.exe'
if (-not (Test-Path -LiteralPath $executable)) {
    throw "Personal Workbench executable not found beside this recovery script: $executable"
}

$arguments = '--restriction-hosts-clear'
$process = Start-Process -FilePath $executable -ArgumentList $arguments -Verb RunAs -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "The managed hosts block could not be cleared. Exit code: $($process.ExitCode)"
}

Write-Host 'The Personal Workbench managed hosts block was cleared.'
