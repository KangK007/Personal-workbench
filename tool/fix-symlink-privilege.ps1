#requires -Version 5.1
<#
    授予本机 Users 组「创建符号链接」权限（SeCreateSymbolicLinkPrivilege）

    ── 为什么需要 ───────────────────────────────────────────────────────
    Flutter 的 Windows 构建必须在
        windows\flutter\ephemeral\.plugin_symlinks\
    下为每个插件创建符号链接。本机已开启开发者模式
    （HKLM\...\AppModelUnlock\AllowDevelopmentWithoutDevLicense = 1），
    但该权限并未出现在登录令牌里（whoami /priv 查无此权限），于是构建报
        PathNotFoundException ... errno = 2
    开发者模式的本质就是「给用户创建符号链接的权利」，本脚本把这件本该
    自动生效的事显式做掉。

    ── 做了什么 ─────────────────────────────────────────────────────────
    用 secedit 导出「本地策略 → 用户权限分配」，只在
    SeCreateSymbolicLinkPrivilege 这一行追加 BUILTIN\Users（*S-1-5-32-545），
    然后导回。**只改这一行**，其余权限项原样保留（/areas USER_RIGHTS）。

    ── 用法（必须以管理员身份运行）──────────────────────────────────────
        powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\fix-symlink-privilege.ps1
    撤销：
        powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\fix-symlink-privilege.ps1 -Rollback
    保留临时文件（排查用）：
        在任一命令后追加 -KeepArtifacts

    ── 已知情况：zh-CN 系统上 secedit /configure 必然返回退出码 1 ────────
    本机安全策略里存在本地化伪账户名（例如「受限服务\所有受限服务」）。
    secedit 导出时会写成这样的名字，导回时无法把它映射回 SID，于是记录
        错误 1332: 账户名与安全标识间无任何映射完成。
        用户权限配置已完成，但有一个或多个错误。
    并让退出码变成 1 —— 即使 SeCreateSymbolicLinkPrivilege 已经成功写入。

    因此本脚本**不用退出码判断成败**，而是在导回后重新导出策略，直接检查
    SeCreateSymbolicLinkPrivilege 这一行是否含 *S-1-5-32-545。退出码非 0 但
    复核通过时，只打印提示与日志错误行，不再抛异常。

    ── 生效时机 ─────────────────────────────────────────────────────────
    用户权限是在「登录」时装入访问令牌的，改完需要 **重启或注销重登** 才生效。
    本脚本会重新导出策略自行复核，但不会自动重启。
#>
[CmdletBinding()]
param(
    [switch]$Rollback,
    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'
$script:keepTmp = [bool]$KeepArtifacts

$PrivName  = 'SeCreateSymbolicLinkPrivilege'
$UsersSid  = '*S-1-5-32-545'   # BUILTIN\Users
$AdminsSid = '*S-1-5-32-544'   # BUILTIN\Administrators

function Write-Section([string]$Title) {
    Write-Output ''
    Write-Output ('=' * 68)
    Write-Output $Title
    Write-Output ('=' * 68)
}

# 读取 scesrv.log 中「本次运行」的错误行。
# 用途：把「与本任务无关的既有报错」和「真正的失败」区分开 —— zh-CN 系统上
# secedit 导出的 inf 含本地化伪账户名（如「受限服务\所有受限服务」），导回时
# 必然报错误 1332 并让退出码非 0，但它并不影响其它条目的落库。
function Get-SeceditLogError {
    $logPath = Join-Path $env:windir 'security\logs\scesrv.log'
    if (-not (Test-Path -LiteralPath $logPath)) { return @('<未找到 scesrv.log>') }

    $text = $null
    try { $text = [System.IO.File]::ReadAllText($logPath, [System.Text.Encoding]::Unicode) } catch { }
    if (-not $text -or $text.IndexOf([char]0) -ge 0) {
        # Unicode 解出来带 NUL 说明其实是 ANSI，退回默认编码再读一次
        try { $text = [System.IO.File]::ReadAllText($logPath, [System.Text.Encoding]::Default) }
        catch { return @("<无法读取 $logPath>") }
    }

    $arr = @($text -split "`r?`n" | Where-Object { $_ -ne '' })
    if ($arr.Count -eq 0) { return @('<scesrv.log 为空>') }

    $start = 0
    for ($i = $arr.Count - 1; $i -ge 0; $i--) {
        if ($arr[$i] -match '配置引擎初始化成功|engine was initialized') { $start = $i; break }
    }
    $slice = @($arr[$start..($arr.Count - 1)])
    $errs  = @($slice | Where-Object { $_ -match '错误|失败|Error|Failed' })
    if ($errs.Count -eq 0) { return @('<本次运行未记录错误行>') }
    return $errs
}

# ── 前置检查：必须是管理员 ──────────────────────────────────────────────
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output 'ERROR: 需要管理员权限。'
    Write-Output "       当前用户: $($identity.Name)  (未提权)"
    Write-Output '       请以「管理员身份」打开 PowerShell 后重新运行。'
    exit 1
}

$tmpDir = Join-Path $env:TEMP ('pwb-secpol-' + [guid]::NewGuid().ToString('N'))
$inf    = Join-Path $tmpDir 'secpol.inf'
$sdb    = Join-Path $tmpDir 'secpol.sdb'

try {
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

    # ── 1. 导出当前用户权限分配 ─────────────────────────────────────────
    Write-Section "1 / 4  导出当前策略 -> $inf"
    & secedit.exe /export /cfg $inf /areas USER_RIGHTS | Out-Null
    if (-not (Test-Path -LiteralPath $inf)) { throw "secedit /export 失败，未生成 $inf" }
    Write-Output "导出成功（$((Get-Item -LiteralPath $inf).Length) 字节）"

    # secedit 导出的是 UTF-16LE；按 Unicode 读取，保留原编码写回
    $lines = [System.IO.File]::ReadAllLines($inf, [System.Text.Encoding]::Unicode)

    # ── 2. 定位并修改目标行 ─────────────────────────────────────────────
    Write-Section '2 / 4  修改权限分配'
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ("^\s*" + $PrivName + "\s*=")) { $idx = $i; break }
    }

    if ($idx -lt 0) {
        # 该行不存在（少见）：在 [Privilege Rights] 段末尾新建
        $secIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*\[Privilege Rights\]\s*$') { $secIdx = $i; break }
        }
        if ($secIdx -lt 0) { throw '导出的 inf 中没有 [Privilege Rights] 段，已中止。' }

        $insertAt = $lines.Count
        for ($i = $secIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*\[') { $insertAt = $i; break }
        }
        $newLines = New-Object 'System.Collections.Generic.List[string]'
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -eq $insertAt) { $newLines.Add("$PrivName = $AdminsSid") }
            $newLines.Add($lines[$i])
        }
        $lines = $newLines.ToArray()
        $idx = $insertAt
        Write-Output "该权限行原本不存在，已在 [Privilege Rights] 段新建（默认 $AdminsSid）"
    }

    $beforeLine = $lines[$idx].Trim()
    Write-Output "修改前: $beforeLine"

    $value = ($lines[$idx] -split '=', 2)[1].Trim()
    $sids  = @()
    if ($value) {
        $sids = $value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    if ($Rollback) {
        $sids = @($sids | Where-Object { $_ -ne $UsersSid })
        Write-Output "操作: 撤销 —— 从该权限中移除 $UsersSid"
    } else {
        if ($sids -notcontains $UsersSid) {
            $sids += $UsersSid
            Write-Output "操作: 追加 $UsersSid"
        } else {
            Write-Output "操作: $UsersSid 已存在，无需改动（脚本幂等）"
        }
    }

    $lines[$idx] = "$PrivName = " + ($sids -join ',')
    $afterLine = $lines[$idx].Trim()
    Write-Output "修改后: $afterLine"

    $applyExit = 0

    if ($beforeLine -eq $afterLine) {
        Write-Output ''
        Write-Output '策略无需变更，跳过导回步骤。'
    } else {
        # ── 3. 写回并用 secedit 应用 ────────────────────────────────────
        Write-Section '3 / 4  应用策略'
        [System.IO.File]::WriteAllLines($inf, $lines, [System.Text.Encoding]::Unicode)
        Write-Output "已写回 inf（Unicode）：$inf"

        $apply     = & secedit.exe /configure /db $sdb /cfg $inf /areas USER_RIGHTS 2>&1
        $applyExit = $LASTEXITCODE
        $apply | Out-String | Write-Output
        Write-Output "secedit /configure 退出码: $applyExit"
    }

    # ── 4. 复核：重新导出并检查（这是**唯一**的成功判据）────────────────
    # 本机是 zh-CN 系统，secedit 导出的 inf 里含本地化伪账户名
    # （如「受限服务\所有受限服务」），导回时必然报错误 1332 并让退出码变成 1，
    # 但那一条与 SeCreateSymbolicLinkPrivilege 无关。因此判据必须是
    # 「重新导出后目标权限行是否含 Users」，而不是退出码。
    Write-Section '4 / 4  复核（重新导出并检查）'
    $verifyInf = Join-Path $tmpDir 'verify.inf'
    & secedit.exe /export /cfg $verifyInf /areas USER_RIGHTS | Out-Null

    $effective = $false
    if (-not (Test-Path -LiteralPath $verifyInf)) {
        Write-Output 'ERROR: 复核用的导出未生成，无法确认结果。'
    } else {
        $verifyLines = [System.IO.File]::ReadAllLines($verifyInf, [System.Text.Encoding]::Unicode)
        $hit = @($verifyLines | Where-Object { $_ -match ("^\s*" + $PrivName + "\s*=") } | Select-Object -First 1)
        if (-not $hit) {
            Write-Output 'WARNING: 复核时未找到该权限行，请人工确认。'
        } else {
            Write-Output "落库结果: $($hit.Trim())"
            $hasUsers  = [bool]($hit -match [regex]::Escape($UsersSid))
            $effective = if ($Rollback) { -not $hasUsers } else { $hasUsers }
            if ($Rollback) {
                Write-Output $(if ($hasUsers) { 'WARNING: Users 仍在权限中，撤销可能未成功。' }
                               else        { 'OK: Users 已从该权限中移除。' })
            } else {
                Write-Output $(if ($hasUsers) { 'OK: Users 已获得「创建符号链接」权限。' }
                               else        { 'ERROR: 未检测到 Users。' })
            }
        }
    }

    if (-not $effective) {
        $script:keepTmp = $true
        Write-Output ''
        Write-Output 'secedit 日志中的错误行：'
        Get-SeceditLogError | ForEach-Object { Write-Output "  | $_" }
        $reason = if ($applyExit -ne 0) { "secedit /configure 退出码 $applyExit" } else { '复核未通过' }
        throw "策略未生效（$reason）。临时文件保留在 $tmpDir，请一并反馈该目录。"
    }

    if ($applyExit -ne 0) {
        Write-Output ''
        Write-Output "提示: secedit /configure 退出码为 $applyExit，但目标权限已按预期落库。"
        Write-Output '      非 0 退出码来自本机既有的本地化条目（zh-CN 已知问题），与本任务无关：'
        Get-SeceditLogError | ForEach-Object { Write-Output "  | $_" }
    }

    Write-Output ''
    Write-Output '──────────────────────────────────────────────────────────────────'
    Write-Output '生效时机：用户权限在登录时装入访问令牌，本脚本不会自动重启。'
    Write-Output '请【重启计算机】或【注销后重新登录】，之后用下面命令验证：'
    Write-Output ''
    Write-Output "    whoami /priv | findstr /i Symbolic"
    Write-Output ''
    Write-Output '出现 SeCreateSymbolicLinkPrivilege 即已生效。'
    Write-Output '──────────────────────────────────────────────────────────────────'
}
finally {
    if (Test-Path -LiteralPath $tmpDir) {
        if ($script:keepTmp) {
            Write-Output ''
            Write-Output "临时文件已保留：$tmpDir"
        } else {
            Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
