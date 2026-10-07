[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$signingRoot = Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchSigning'
$androidRoot = Join-Path $signingRoot 'android'
$androidKeystore = Join-Path $androidRoot 'personal-workbench-release.jks'
$windowsPfx = Join-Path $signingRoot 'personal-workbench-windows-code-signing.pfx'
$statePath = Join-Path $signingRoot 'signing-state.json'
$keyPropertiesPath = Join-Path $projectRoot 'android\key.properties'

New-Item -ItemType Directory -Force -Path $androidRoot | Out-Null

function New-RandomHex([int]$ByteCount = 32) {
    $bytes = New-Object byte[] $ByteCount
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    } finally {
        $generator.Dispose()
    }
    return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
}

function Protect-File([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $item = Get-Item -LiteralPath $Path -Force
        $item.IsReadOnly = $true
    }
}

function Enable-PrivateFileWrite([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        (Get-Item -LiteralPath $Path -Force).IsReadOnly = $false
    }
}

function Protect-PrivatePath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $item = Get-Item -LiteralPath $Path -Force
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $arguments = @(
        $Path,
        '/inheritance:r',
        '/grant:r', "$identity`:F",
        '/grant:r', '*S-1-5-18:F',
        '/grant:r', '*S-1-5-32-544:F'
    )
    if ($item.PSIsContainer) {
        $arguments += '/T'
    }
    & icacls.exe @arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to protect signing path ACL: $Path (icacls exit code $LASTEXITCODE)"
    }
}

$state = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
}

if ($Force -or -not (Test-Path -LiteralPath $androidKeystore -PathType Leaf)) {
    $keytool = (Get-Command keytool -CommandType Application -ErrorAction Stop).Source
    $storePassword = New-RandomHex
    # JDK 21 defaults to PKCS12. PKCS12 key entries use the store password
    # for private-key protection; a separate key password causes Gradle's
    # release packager to fail with UnrecoverableKeyException.
    $keyPassword = $storePassword
    & $keytool -genkeypair -noprompt -v `
        -keystore $androidKeystore `
        -storepass $storePassword `
        -keypass $keyPassword `
        -alias personal-workbench `
        -keyalg RSA `
        -keysize 4096 `
        -validity 10000 `
        -dname 'CN=Personal Workbench Android Release, OU=Personal Workbench, O=Personal Workbench, C=CN' `
        -ext 'KeyUsage=digitalSignature' `
        -ext 'ExtendedKeyUsage=codeSigning' | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Android release keystore generation failed with exit code $LASTEXITCODE"
    }

    Enable-PrivateFileWrite $keyPropertiesPath
    $propertyLines = @(
        "storeFile=$($androidKeystore.Replace('\', '/'))",
        "storePassword=$storePassword",
        'keyAlias=personal-workbench',
        "keyPassword=$keyPassword"
    )
    [System.IO.File]::WriteAllLines(
        $keyPropertiesPath,
        $propertyLines,
        [System.Text.UTF8Encoding]::new($false)
    )
    Protect-File $keyPropertiesPath
} elseif (-not (Test-Path -LiteralPath $keyPropertiesPath -PathType Leaf)) {
    throw "Android keystore exists but android/key.properties is missing. Recreate it from the protected local backup or rerun with -Force."
} else {
    # Repair older local setup state created with a separate key password.
    # The keystore is retained, so its certificate/fingerprint remains stable.
    $existingProperties = ConvertFrom-StringData (Get-Content -Raw -LiteralPath $keyPropertiesPath)
    if ($existingProperties.storePassword -and $existingProperties.keyPassword -ne $existingProperties.storePassword) {
        Enable-PrivateFileWrite $keyPropertiesPath
        $repairedLines = @(
            "storeFile=$($existingProperties.storeFile)",
            "storePassword=$($existingProperties.storePassword)",
            "keyAlias=$($existingProperties.keyAlias)",
            "keyPassword=$($existingProperties.storePassword)"
        )
        [System.IO.File]::WriteAllLines(
            $keyPropertiesPath,
            $repairedLines,
            [System.Text.UTF8Encoding]::new($false)
        )
        Protect-File $keyPropertiesPath
        Write-Output 'Repaired Android PKCS12 key password to match the store password.'
    }
}

if ($Force -or -not $state -or -not $state.windowsThumbprint) {
    $certificate = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject 'CN=Personal Workbench Local Code Signing' `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -KeyAlgorithm RSA `
        -KeyLength 3072 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears(10)
    if (-not $certificate) {
        throw 'Windows code-signing certificate generation failed.'
    }

    $windowsPassword = New-RandomHex
    $securePassword = ConvertTo-SecureString $windowsPassword -AsPlainText -Force
    Enable-PrivateFileWrite $windowsPfx
    if (Test-Path -LiteralPath $windowsPfx -PathType Leaf) {
        Remove-Item -LiteralPath $windowsPfx -Force
    }
    Export-PfxCertificate -Cert $certificate -FilePath $windowsPfx -Password $securePassword | Out-Null

    $state = [ordered]@{
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        androidKeystore = $androidKeystore
        windowsPfx = $windowsPfx
        windowsThumbprint = $certificate.Thumbprint
    }
    Enable-PrivateFileWrite $statePath
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    Protect-File $statePath
    Protect-File $windowsPfx
} else {
    $certificate = Get-ChildItem "Cert:\CurrentUser\My\$($state.windowsThumbprint)" -ErrorAction SilentlyContinue
    if (-not $certificate -or -not $certificate.HasPrivateKey) {
        throw "The configured Windows signing certificate is missing from the current user's certificate store: $($state.windowsThumbprint)"
    }
}

foreach ($privatePath in @(
    $signingRoot,
    $androidRoot,
    $androidKeystore,
    $windowsPfx,
    $statePath,
    $keyPropertiesPath
)) {
    Protect-PrivatePath $privatePath
}

Write-Output "Android signing configured: $keyPropertiesPath"
Write-Output "Windows signing certificate: $($state.windowsThumbprint)"
Write-Output "Private signing material is stored under: $signingRoot"
