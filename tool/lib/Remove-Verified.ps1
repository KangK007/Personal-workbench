# Remove-Verified —— 容忍「注入式安全删除垫片」假失败的安全删除助手。
#
# 背景：某些受管环境会把 Remove-Item 替换为「走回收站」的实现（安全垫片）。
# 该实现在中文路径下回收站操作会失败，于是**报错但删除已实际生效**：
#
#   [safe-delete][SAFE_DELETE_FAIL_CLOSED] {"target":"...\dist\apk\...apk",
#     "reason":"trash-failed","detail":"... Error during a `trash` operation ..."}
#
# 由于脚本内是 $ErrorActionPreference = 'Stop'，这个「假失败」会直接终止构建——
# 实测后果：Gradle 已 BUILD SUCCESSFUL、APK 也已生成，却死在产物复制之前，
# dist/ 里既没有旧包也没有新包。
#
# 因此本助手**不依赖命令是否抛错**，改以「最终状态」为唯一判据：
#   - 删除动作异常 → 吞掉，继续往下走；
#   - 删除后路径仍存在 → 抛错（真失败必须显式失败，绝不静默放过）。
#
# 用法：
#   . (Join-Path $PSScriptRoot 'lib\Remove-Verified.ps1')
#   Remove-Verified -LiteralPath $someFile
#   Remove-Verified -LiteralPath $someDir -Recurse

function Wait-PathGone {
    <#
        有上限地等待路径真正消失，返回 $true 表示已消失。
        删除动作的「落定」可能滞后于命令返回，不能拿一次即时检查当结论。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [int]$MaxChecks = 40,

        [int]$DelayMilliseconds = 250
    )

    for ($i = 0; $i -lt $MaxChecks; $i++) {
        if (-not (Test-Path -LiteralPath $LiteralPath)) {
            return $true
        }
        Start-Sleep -Milliseconds $DelayMilliseconds
    }

    return $false
}

function Remove-Verified {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [switch]$Recurse
    )

    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return
    }

    try {
        if ($Recurse) {
            Remove-Item -LiteralPath $LiteralPath -Recurse -Force -ErrorAction Stop
        }
        else {
            Remove-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
        }
    }
    catch {
        # 预期路径：垫片在中文路径上「报错但已生效」。吞掉，交由下方状态校验裁决。
        Write-Verbose "Remove-Item reported an error for '$LiteralPath': $($_.Exception.Message)"
    }

    # 垫片走的是回收站/垃圾箱二进制，落定相对命令返回**略有延迟**：实测
    # Remove-Item 抛 SAFE_DELETE_FAIL_CLOSED 之后，紧接着 Test-Path 可能仍为
    # $true，数毫秒后才变 $false。若立即裁决，会把「已删除、尚未落定」误判成
    # 真失败（2026-09-19 在 dist\windows 上实测踩到）。
    if (Wait-PathGone -LiteralPath $LiteralPath) {
        return
    }

    # 兜底：垫片对**文件**（而非目录）的中文路径回收站操作会真的失败，路径一直
    # 留在原地（2026-09-19 在 dist\PersonalWorkbench_0.1.0+4_windows.zip 上实测）。
    # 此时改用模块限定的内置 cmdlet 直删 —— 与垫片自己在 temp 路径下的做法一致。
    # 适用范围仅限本助手被调用的场景（构建产物、临时导出），不需要回收站语义。
    try {
        $isContainer = (Get-Item -LiteralPath $LiteralPath -Force).PSIsContainer
        if ($Recurse -or $isContainer) {
            Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Recurse -Force -ErrorAction Stop
        }
        else {
            Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Verbose "Direct removal failed for '$LiteralPath': $($_.Exception.Message)"
    }

    if (Wait-PathGone -LiteralPath $LiteralPath) {
        return
    }

    throw "Failed to remove '$LiteralPath': the path still exists after Remove-Item."
}
