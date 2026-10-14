function Test-LocalAuthenticodeSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedThumbprint
    )

    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    $certificate = $signature.SignerCertificate
    if (-not $certificate -or
        $certificate.Thumbprint.Replace(' ', '').ToUpperInvariant() -ne
            $ExpectedThumbprint.Replace(' ', '').ToUpperInvariant()) {
        return $false
    }
    if ($signature.Status -eq 'Valid') {
        return $true
    }
    if ($signature.Status -ne 'UnknownError' -or
        $certificate.Subject -ne $certificate.Issuer) {
        return $false
    }

    # A locally self-signed release has no public CA. Accept only that single
    # trust-chain error; Get-AuthenticodeSignature still rejects a changed PE
    # or script as HashMismatch. Never accept expired or otherwise invalid keys.
    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    try {
        $chain.ChainPolicy.RevocationMode =
            [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
        $null = $chain.Build($certificate)
        $statuses = @($chain.ChainStatus | ForEach-Object { $_.Status })
        return $statuses.Count -eq 1 -and
            $statuses[0] -eq
                [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::UntrustedRoot
    } finally {
        $chain.Dispose()
    }
}
