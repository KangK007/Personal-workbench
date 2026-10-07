[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Archive,
    [Parameter(Mandatory = $true)]
    [string]$Thumbprint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$normalizedThumbprint = $Thumbprint.Replace(' ', '').ToUpperInvariant()
$certificate = Get-ChildItem "Cert:\CurrentUser\My\$normalizedThumbprint" -ErrorAction SilentlyContinue
if (-not $certificate -or -not $certificate.HasPrivateKey) {
    throw "Windows signing certificate with thumbprint $normalizedThumbprint was not found in the current user's certificate store."
}
if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
    throw "Cannot sign missing archive: $Archive"
}

$pkcsAssemblyPath = Join-Path $PSHOME 'System.Security.Cryptography.Pkcs.dll'
if (Test-Path -LiteralPath $pkcsAssemblyPath -PathType Leaf) {
    Add-Type -Path $pkcsAssemblyPath
} else {
    Add-Type -AssemblyName System.Security.Cryptography.Pkcs
}

$archiveContent = [System.IO.File]::ReadAllBytes($Archive)
$contentInfo = [System.Security.Cryptography.Pkcs.ContentInfo]::new($archiveContent)
$signedCms = [System.Security.Cryptography.Pkcs.SignedCms]::new($contentInfo, $true)
$cmsSigner = [System.Security.Cryptography.Pkcs.CmsSigner]::new($certificate)
$cmsSigner.DigestAlgorithm = [System.Security.Cryptography.Oid]::new('2.16.840.1.101.3.4.2.1')
$signedCms.ComputeSignature($cmsSigner)
$archiveSignature = "$Archive.p7s"
[System.IO.File]::WriteAllBytes($archiveSignature, $signedCms.Encode())

$verifiedCms = [System.Security.Cryptography.Pkcs.SignedCms]::new($contentInfo, $true)
$verifiedCms.Decode([System.IO.File]::ReadAllBytes($archiveSignature))
$verifiedCms.CheckSignature($true)
$archiveSignerThumbprint = $verifiedCms.SignerInfos[0].Certificate.Thumbprint.Replace(' ', '').ToUpperInvariant()
if ($verifiedCms.SignerInfos.Count -ne 1 -or $archiveSignerThumbprint -ne $normalizedThumbprint) {
    throw "Windows package CMS signature verification failed: $archiveSignature"
}

Write-Output "Windows package archive signed: $archiveSignature [$archiveSignerThumbprint]"
