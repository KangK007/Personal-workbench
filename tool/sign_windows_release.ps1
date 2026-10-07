[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,
    [string]$Thumbprint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$statePath = Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchSigning\signing-state.json'
if ([string]::IsNullOrWhiteSpace($Thumbprint)) {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        throw 'Windows signing is not configured. Run tool\setup_local_signing.ps1 first or pass -Thumbprint.'
    }
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    $Thumbprint = [string]$state.windowsThumbprint
}

$normalizedThumbprint = $Thumbprint.Replace(' ', '').ToUpperInvariant()
$certificate = Get-ChildItem "Cert:\CurrentUser\My\$normalizedThumbprint" -ErrorAction SilentlyContinue
if (-not $certificate -or -not $certificate.HasPrivateKey) {
    throw "Windows signing certificate with thumbprint $normalizedThumbprint was not found in the current user's certificate store."
}

foreach ($target in $Path) {
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Cannot sign missing file: $target"
    }
    $resolved = (Resolve-Path -LiteralPath $target).Path
    $result = Set-AuthenticodeSignature -FilePath $resolved -Certificate $certificate
    $signature = Get-AuthenticodeSignature -FilePath $resolved
    if (-not $signature.SignerCertificate -or
        $signature.SignerCertificate.Thumbprint.Replace(' ', '').ToUpperInvariant() -ne $normalizedThumbprint) {
        throw "Authenticode signing verification failed: $resolved (status: $($signature.Status))"
    }
    Write-Output "Signed: $resolved [$($signature.Status)]"
}

$global:LASTEXITCODE = 0
