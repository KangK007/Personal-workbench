[CmdletBinding()]
param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'debug',
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Configuration = $Configuration.ToLowerInvariant()

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ($Configuration -eq 'release') {
    $keyPropertiesPath = Join-Path $projectRoot 'android\key.properties'
    if (-not (Test-Path -LiteralPath $keyPropertiesPath -PathType Leaf)) {
        throw 'Android Release requires android\key.properties and a private release keystore. The file and keystore are ignored by Git.'
    }
}
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($projectRoot)
    $digest = $sha256.ComputeHash($pathBytes)
} finally {
    $sha256.Dispose()
}
$projectKey = -join ($digest[0..5] | ForEach-Object { $_.ToString('x2') })
$buildBase = Join-Path $env:SystemDrive 'Temp\PersonalWorkbenchBuild'
$aliasRoot = Join-Path $buildBase $projectKey
$buildSource = Join-Path $aliasRoot 'source'
$buildTemp = Join-Path $aliasRoot 'temp'
$buildBasePath = [System.IO.Path]::GetFullPath($buildBase).TrimEnd('\') + '\'
$buildSourcePath = [System.IO.Path]::GetFullPath($buildSource)
if (-not $buildSourcePath.StartsWith(
        $buildBasePath,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Build source is outside the managed temporary directory: $buildSource"
}

New-Item -ItemType Directory -Force -Path $aliasRoot, $buildTemp | Out-Null

# Java 21 uses a local IPC pipe while Gradle starts its single-use daemon.
# Keep that pipe in the short, local build directory instead of the host temp path.
$env:TEMP = $buildTemp
$env:TMP = $buildTemp

if (Test-Path -LiteralPath $buildSource) {
    $existingBuildSource = Get-Item -LiteralPath $buildSource -Force
    if ($existingBuildSource.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to replace a linked build source directory: $buildSource"
    }
    Remove-Item -LiteralPath $buildSource -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $buildSource | Out-Null

$copyArguments = @(
    $projectRoot,
    $buildSource,
    '/E',
    '/XD', '.git', '.dart_tool', 'build', 'dist', 'coverage',
    '.idea', '.vscode',
    (Join-Path $projectRoot 'raw'),
    (Join-Path $projectRoot 'data'),
    (Join-Path $projectRoot 'original'),
    (Join-Path $projectRoot 'experiment'),
    (Join-Path $projectRoot 'measurements'),
    '/XF', 'flutter_*.log',
    '/NFL', '/NDL', '/NJH', '/NJS', '/NP'
)
& robocopy @copyArguments | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "Source copy failed with robocopy exit code $LASTEXITCODE"
}

$javaCandidates = @(
    $env:JAVA_HOME,
    'C:\Program Files\Android\Android Studio\jbr'
)
$javaHome = $javaCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin\java.exe')) } |
    Select-Object -First 1
if (-not $javaHome) {
    throw 'A JDK was not found. Set JAVA_HOME or install Android Studio.'
}
$env:JAVA_HOME = (Resolve-Path -LiteralPath $javaHome).Path
$env:PERSONAL_WORKBENCH_BUILD_ROOT = Join-Path $aliasRoot 'build'
$env:PERSONAL_WORKBENCH_SOURCE_ROOT = $buildSource

$gradleCacheRoot = Join-Path $env:USERPROFILE '.gradle\wrapper\dists\gradle-8.14-bin'
$gradle = Get-ChildItem -LiteralPath $gradleCacheRoot -Filter 'gradle.bat' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\gradle-8\.14\\bin\\gradle\.bat$' } |
    Select-Object -First 1
if (-not $gradle) {
    throw "Cached Gradle 8.14 was not found below $gradleCacheRoot. Run the build once with network access to populate the cache."
}

$gradleTask = switch ($Configuration) {
    'debug' { 'assembleDebug' }
    'profile' { 'assembleProfile' }
    'release' { 'assembleRelease' }
}

Push-Location -LiteralPath $buildSource
try {
    if ($Clean.IsPresent) {
        & flutter clean
        if ($LASTEXITCODE -ne 0) {
            throw "flutter clean failed with exit code $LASTEXITCODE"
        }
    }

    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE"
    }

    $dependencies = dart pub deps --json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "dart pub deps failed with exit code $LASTEXITCODE"
    }
    $rootPackage = $dependencies.packages |
        Where-Object { $_.name -eq $dependencies.root } |
        Select-Object -First 1
    if (-not $rootPackage) {
        throw 'The root package version could not be read from dart pub deps.'
    }
    $versionParts = $rootPackage.version -split '\+', 2
    $versionName = $versionParts[0]
    $versionCode = if ($versionParts.Count -eq 2) { $versionParts[1] } else { '1' }
    if ($versionCode -notmatch '^\d+$' -or [int64]$versionCode -lt 1) {
        throw "Android build number must be a positive integer: $versionCode"
    }

    $localPropertiesPath = Join-Path $buildSource 'android\local.properties'
    $localProperties = ConvertFrom-StringData (
        Get-Content -Raw -LiteralPath $localPropertiesPath
    )
    $localProperties['flutter.buildMode'] = $Configuration
    $localProperties['flutter.versionName'] = $versionName
    $localProperties['flutter.versionCode'] = $versionCode
    $localPropertyLines = $localProperties.GetEnumerator() |
        Sort-Object Key |
        ForEach-Object {
            $escapedValue = ([string]$_.Value).Replace('\', '\\')
            "$($_.Key)=$escapedValue"
        }
    [System.IO.File]::WriteAllLines(
        $localPropertiesPath,
        $localPropertyLines,
        [System.Text.UTF8Encoding]::new($false)
    )

    Push-Location -LiteralPath (Join-Path $buildSource 'android')
    try {
        & $gradle.FullName $gradleTask '--offline' '--no-daemon' '--stacktrace'
        if ($LASTEXITCODE -ne 0) {
            throw "Gradle $gradleTask failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}

$apkName = "app-$Configuration.apk"
$artifact = Join-Path $env:PERSONAL_WORKBENCH_BUILD_ROOT "app\outputs\flutter-apk\$apkName"
if (-not (Test-Path -LiteralPath $artifact)) {
    throw "Build completed without the expected APK: $artifact"
}

if ($Configuration -eq 'release') {
    $sdkRoot = [string]$localProperties['sdk.dir']
    $buildToolsRoot = Join-Path $sdkRoot 'build-tools'
    $apksigner = Get-ChildItem -LiteralPath $buildToolsRoot -Filter 'apksigner.bat' -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $apksigner) {
        throw "apksigner was not found below $buildToolsRoot."
    }
    & $apksigner.FullName verify --verbose --print-certs $artifact
    if ($LASTEXITCODE -ne 0) {
        throw "Android Release signature verification failed with exit code $LASTEXITCODE"
    }
}

$destinationDirectory = Join-Path $projectRoot 'build\app\outputs\flutter-apk'
New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
$destination = Join-Path $destinationDirectory $apkName
Copy-Item -LiteralPath $artifact -Destination $destination -Force

$distributionDirectory = Join-Path $projectRoot 'dist\apk'
New-Item -ItemType Directory -Force -Path $distributionDirectory | Out-Null
$distributionName = "PersonalWorkbench_$versionName`_$versionCode`_$Configuration.apk"
$distribution = Join-Path $distributionDirectory $distributionName
Get-ChildItem -LiteralPath $distributionDirectory -Filter "PersonalWorkbench_*_$Configuration.apk" -File |
    Remove-Item -Force
Copy-Item -LiteralPath $artifact -Destination $distribution -Force

Write-Output "Android build completed: $destination"
Write-Output "Android distribution APK: $distribution"
