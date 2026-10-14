$distributionRoot = Join-Path $PSScriptRoot '..\dist\windows'
$statePath = Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchSigning\signing-state.json'
$expectedThumbprint = (Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json).windowsThumbprint
. (Join-Path $PSScriptRoot '..\tool\lib\Test-LocalAuthenticode.ps1')
Add-Type -AssemblyName System.Security
$signableExtensions = @('.exe', '.dll', '.ps1')
$signableFiles = @(
    Get-ChildItem -LiteralPath $distributionRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $signableExtensions -contains $_.Extension.ToLowerInvariant() }
)
$distributionArchives = @(
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\dist') -Filter 'PersonalWorkbench_*_windows.zip' -File -ErrorAction SilentlyContinue
)

Describe 'Windows release package Authenticode signatures' {
    It 'contains signable release files' {
        $signableFiles.Count | Should BeGreaterThan 0
    }

    It 'signs every executable, library, and PowerShell installer with the stable Windows certificate' {
        $invalidFiles = @(
            foreach ($file in $signableFiles) {
                $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
                $actualThumbprint = if ($signature.SignerCertificate) {
                    $signature.SignerCertificate.Thumbprint.Replace(' ', '').ToUpperInvariant()
                } else {
                    ''
                }
                if (-not (Test-LocalAuthenticodeSignature -Path $file.FullName -ExpectedThumbprint $expectedThumbprint)) {
                    '{0}: status={1}, thumbprint={2}' -f $file.FullName, $signature.Status, $actualThumbprint
                }
            }
        )

        $invalidFiles | Should BeNullOrEmpty
    }

    It 'rejects a signed library after its bytes change' {
        $source = $signableFiles | Where-Object { $_.Extension -eq '.dll' } | Select-Object -First 1
        $copy = Join-Path $TestDrive 'changed.dll'
        Copy-Item -LiteralPath $source.FullName -Destination $copy
        $bytes = [System.IO.File]::ReadAllBytes($copy)
        $bytes[128] = $bytes[128] -bxor 1
        [System.IO.File]::WriteAllBytes($copy, $bytes)
        (Test-LocalAuthenticodeSignature -Path $copy -ExpectedThumbprint $expectedThumbprint) | Should Be $false
    }

    It 'provides a detached CMS signature for the complete Windows ZIP package' {
        $distributionArchives.Count | Should Be 1
        if ($distributionArchives.Count -eq 1) {
            $archive = $distributionArchives[0]
            $signaturePath = "$($archive.FullName).p7s"
            (Test-Path -LiteralPath $signaturePath -PathType Leaf) | Should Be $true

            if (Test-Path -LiteralPath $signaturePath -PathType Leaf) {
                $contentInfo = [System.Security.Cryptography.Pkcs.ContentInfo]::new(
                    [System.IO.File]::ReadAllBytes($archive.FullName)
                )
                $cms = [System.Security.Cryptography.Pkcs.SignedCms]::new($contentInfo, $true)
                $cms.Decode([System.IO.File]::ReadAllBytes($signaturePath))
                $cms.CheckSignature($true)
                $cms.SignerInfos.Count | Should Be 1
                $cms.SignerInfos[0].Certificate.Thumbprint.ToUpperInvariant() | Should Be $expectedThumbprint.ToUpperInvariant()
            }
        }
    }
}
