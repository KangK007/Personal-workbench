[CmdletBinding()]
param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'debug',
    [ValidateSet('universal', 'split', 'arm64', 'arm', 'x64')]
    [string]$AbiMode = 'universal',
    [switch]$Clean,
    [switch]$Online
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Configuration = $Configuration.ToLowerInvariant()

# 安全删除助手：垫片环境下 Remove-Item 会「报错但已生效」，
# 故删除一律走状态校验式助手，避免构建死在产物复制之前。
. (Join-Path $PSScriptRoot 'lib\Remove-Verified.ps1')

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
$buildMutex = [System.Threading.Mutex]::new($false, "Local\PersonalWorkbenchBuild-$projectKey")
$mutexAcquired = $false
try {
    $mutexAcquired = $buildMutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    # The previous build exited unexpectedly; ownership was released by Windows.
    $mutexAcquired = $true
}
if (-not $mutexAcquired) {
    $buildMutex.Dispose()
    throw 'Another Personal Workbench build is already running for this checkout. Wait for it to finish and retry.'
}
try {
$aliasRoot = Join-Path $env:LOCALAPPDATA "PersonalWorkbenchBuild\$projectKey"
$sourceCopy = Join-Path $aliasRoot 'source-copy'
New-Item -ItemType Directory -Force -Path $aliasRoot | Out-Null
$resolvedCacheBase = [System.IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA 'PersonalWorkbenchBuild')
).TrimEnd('\')
$resolvedSourceCopy = [System.IO.Path]::GetFullPath($sourceCopy)
if (-not $resolvedSourceCopy.StartsWith(
        "$resolvedCacheBase\",
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'The ASCII build source path validation failed.'
}
if (Test-Path -LiteralPath $sourceCopy) {
    $existingSourceCopy = Get-Item -LiteralPath $sourceCopy -Force
    if ($existingSourceCopy.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to replace a linked build source directory: $sourceCopy"
    }
    [System.IO.Directory]::Delete("\\?\$resolvedSourceCopy", $true)
}
New-Item -ItemType Directory -Force -Path $sourceCopy | Out-Null

$copyArguments = @(
    $projectRoot,
    $sourceCopy,
    '/E', '/R:2', '/W:1',
    '/XD', '.git', '.dart_tool', 'build', 'dist', 'coverage',
    '.idea', '.vscode',
    (Join-Path $projectRoot 'windows\flutter\ephemeral'),
    (Join-Path $projectRoot 'android\.gradle'),
    (Join-Path $projectRoot 'raw'),
    (Join-Path $projectRoot 'data'),
    (Join-Path $projectRoot 'original'),
    (Join-Path $projectRoot 'experiment'),
    (Join-Path $projectRoot 'measurements'),
    '/XF', '.git', 'flutter_*.log',
    '/NFL', '/NDL', '/NJH', '/NJS', '/NP'
)
& robocopy.exe @copyArguments | Out-Null
$sourceCopyExitCode = $LASTEXITCODE
if ($sourceCopyExitCode -ge 8) {
    throw "Source staging failed with robocopy exit code $sourceCopyExitCode"
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
$env:PERSONAL_WORKBENCH_SOURCE_ROOT = $sourceCopy

$gradleUserHome = if ([string]::IsNullOrWhiteSpace($env:GRADLE_USER_HOME)) {
    Join-Path $env:USERPROFILE '.gradle'
} else {
    $env:GRADLE_USER_HOME
}
$env:GRADLE_USER_HOME = $gradleUserHome
$gradleCacheRoot = Join-Path $gradleUserHome 'wrapper\dists\gradle-8.14-bin'
$gradle = Get-ChildItem -LiteralPath $gradleCacheRoot -Filter 'gradle.bat' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\gradle-8\.14\\bin\\gradle\.bat$' } |
    Select-Object -First 1
if (-not $gradle -and $Online.IsPresent) {
    Push-Location -LiteralPath (Join-Path $sourceCopy 'android')
    try {
        $env:GRADLE_USER_HOME = $gradleUserHome
        & .\gradlew.bat --version
        if ($LASTEXITCODE -ne 0) {
            throw "Gradle Wrapper bootstrap failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
    $gradle = Get-ChildItem -LiteralPath $gradleCacheRoot -Filter 'gradle.bat' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\gradle-8\.14\\bin\\gradle\.bat$' } |
        Select-Object -First 1
}
if (-not $gradle) {
    throw "Cached Gradle 8.14 was not found below $gradleCacheRoot. Rerun with -Online to download it."
}

$gradleTask = switch ($Configuration) {
    'debug' { 'assembleDebug' }
    'profile' { 'assembleProfile' }
    'release' { 'assembleRelease' }
}

# universal: 单一 APK 包含全部 ABI（默认，兼容旧行为）。
# split:     按 arm64-v8a / armeabi-v7a / x86_64 分别产出 APK。
# arm64/arm/x64: 只构建单一 ABI 的 APK（体积最小，适合个人侧载）。
$abiTargets = @(
    switch ($AbiMode) {
        'universal' { @() }
        'split' { @('arm64', 'arm', 'x64') }
        'arm64' { @('arm64') }
        'arm' { @('arm') }
        'x64' { @('x64') }
    }
)
$abiSuffixes = @{
    'arm64' = 'arm64-v8a'
    'arm' = 'armeabi-v7a'
    'x64' = 'x86_64'
}

Push-Location -LiteralPath $sourceCopy
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

    $localPropertiesPath = Join-Path $sourceCopy 'android\local.properties'
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

    $builtApks = @()
    $buildTargets = if ($abiTargets.Count -eq 0) { @('') } else { $abiTargets }

    Push-Location -LiteralPath (Join-Path $sourceCopy 'android')
    try {
        $shortTemp = Join-Path $env:SystemDrive "PWBTemp\$projectKey"
        New-Item -ItemType Directory -Force -Path $shortTemp | Out-Null
        $previousTemp = $env:TEMP
        $previousTmp = $env:TMP
        try {
            $env:TEMP = $shortTemp
            $env:TMP = $shortTemp
            foreach ($abi in $buildTargets) {
                $gradleArguments = @($gradleTask, '--no-daemon', '--stacktrace')
                if (-not $Online.IsPresent) {
                    $gradleArguments += '--offline'
                }
                $mirrorInitScript = Join-Path $sourceCopy 'tool\gradle_plugin_mirror.init.gradle'
                if (Test-Path -LiteralPath $mirrorInitScript -PathType Leaf) {
                    $gradleArguments += @('--init-script', $mirrorInitScript)
                }
                if ($abi) {
                    $gradleArguments += "-Ptarget-platform=android-$abi"
                }
                & $gradle.FullName @gradleArguments
                $gradleExitCode = $LASTEXITCODE
                if ($gradleExitCode -ne 0) {
                    throw "Gradle $gradleTask failed for $abi with exit code $gradleExitCode"
                }
                $apkName = "app-$Configuration.apk"
                $artifact = Join-Path $env:PERSONAL_WORKBENCH_BUILD_ROOT "app\outputs\flutter-apk\$apkName"
                if (-not (Test-Path -LiteralPath $artifact)) {
                    throw "Build completed without the expected APK: $artifact"
                }
                # 多 ABI 循环构建时，每次构建都会覆盖同名产物，先复制到暂存目录
                $stagedName = if ($abi) {
                    "app-$abi-$Configuration.apk"
                } else {
                    $apkName
                }
                $stagedArtifact = Join-Path $env:PERSONAL_WORKBENCH_BUILD_ROOT "app\outputs\flutter-apk\$stagedName"
                if ($abi) {
                    Copy-Item -LiteralPath $artifact -Destination $stagedArtifact -Force
                }
                $builtApks += [PSCustomObject]@{
                    Path = if ($abi) { $stagedArtifact } else { $artifact }
                    Abi = $abi
                }
            }
        } finally {
            [Environment]::SetEnvironmentVariable('TEMP', $previousTemp, 'Process')
            [Environment]::SetEnvironmentVariable('TMP', $previousTmp, 'Process')
        }
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}

if ($builtApks.Count -eq 0) {
    throw 'No APK was produced by the build.'
}

$destinationDirectory = Join-Path $projectRoot 'build\app\outputs\flutter-apk'
New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
$distributionDirectory = Join-Path $projectRoot 'dist\apk'
New-Item -ItemType Directory -Force -Path $distributionDirectory | Out-Null

foreach ($built in $builtApks) {
    if ($Configuration -eq 'release') {
        $sdkRoot = [string]$localProperties['sdk.dir']
        $buildToolsRoot = Join-Path $sdkRoot 'build-tools'
        $apksigner = Get-ChildItem -LiteralPath $buildToolsRoot -Filter 'apksigner.bat' -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if (-not $apksigner) {
            throw "apksigner was not found below $buildToolsRoot."
        }
        & $apksigner.FullName verify --verbose --print-certs $built.Path
        if ($LASTEXITCODE -ne 0) {
            throw "Android Release signature verification failed with exit code $LASTEXITCODE"
        }
    }

    $abiSuffix = if ($built.Abi) { $abiSuffixes[$built.Abi] } else { '' }
    $outputName = if ($abiSuffix) {
        "app-$abiSuffix-$Configuration.apk"
    } else {
        "app-$Configuration.apk"
    }
    $destination = Join-Path $destinationDirectory $outputName
    Copy-Item -LiteralPath $built.Path -Destination $destination -Force

    $distributionBase = "PersonalWorkbench_${versionName}_${versionCode}_$Configuration"
    $distributionName = if ($abiSuffix) {
        "$distributionBase-$abiSuffix.apk"
    } else {
        "$distributionBase.apk"
    }
    $distribution = Join-Path $distributionDirectory $distributionName
    # 只清理同一形态（universal 或同名 ABI 分片）的旧版本文件，
    # 不同 ABI 形态的产物互不影响。
    $distributionPattern = if ($abiSuffix) {
        "PersonalWorkbench_*_${Configuration}-${abiSuffix}.apk"
    } else {
        "PersonalWorkbench_*_${Configuration}.apk"
    }
    # 先显式收集待清理的旧产物再逐个删除：零匹配时必须完全不调用
    # Remove-Item。管道形式在正常的 PowerShell 下因「空管道不执行命令」
    # 而安全，但在注入式安全删除垫片（把 Remove-Item 换成回收站实现）
    # 的环境下，垫片仍会进入 end 块并以「缺失路径操作数」报错。
    $staleDistributions = @(
        Get-ChildItem -LiteralPath $distributionDirectory -Filter $distributionPattern -File |
            Where-Object { $_.Name -ne $distributionName }
    )
    foreach ($staleDistribution in $staleDistributions) {
        Remove-Verified -LiteralPath $staleDistribution.FullName
    }
    Copy-Item -LiteralPath $built.Path -Destination $distribution -Force
    Write-Output "Android build completed: $destination"
    Write-Output "Android distribution APK: $distribution"
}

# $LASTEXITCODE 只由**原生命令**设置，并且会**从调用方会话继承**：子脚本自己不
# 归零，调用方拿到的就还是它进来时的那个值。本脚本成功路径的收尾全是 cmdlet
# （Copy-Item / 安全删除助手都不碰该变量），于是一次**成功的**构建可能对外报出
# 非零退出码，调用方据此判成败会把成功当失败。
# 真实失败一律由 throw 终止、走不到这一行，故此处归零是安全的。
# 与 build_windows.ps1 末尾同一处理（那里防的是 robocopy 的 0-7 泄漏）。
$global:LASTEXITCODE = 0
} finally {
    $buildMutex.ReleaseMutex()
    $buildMutex.Dispose()
}
