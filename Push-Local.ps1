<#
.SYNOPSIS
    本地提交并推送，自动探测本地代理。

.DESCRIPTION
    个人便捷脚本，不入库（已在 .gitignore 中忽略）。

    受限网络下推送 GitHub 常见两种失败：
      1. schannel 报 SEC_E_NO_CREDENTIALS —— 凭据管理器取不到证书
      2. OpenSSL 报 unexpected eof       —— TLS 握手中途被重置

    本脚本对应处理：
      - 凭据改用 `gh auth token`，绕开 Git Credential Manager
      - TLS 后端改用 openssl，绕开 schannel
      - 推送优先走本地代理，失败自动回退直连

.PARAMETER Message
    提交信息。省略时按仓库习惯生成一条默认信息。

.PARAMETER Proxy
    显式指定代理地址，例如 http://127.0.0.1:7890。省略时自动探测。

.PARAMETER NoProxy
    不探测代理，直连。

.PARAMETER DryRun
    只打印计划执行的命令，不提交、不推送。

.EXAMPLE
    pwsh -File .\Push-Local.ps1 -Message "许可：仓库改用 MIT License"

.EXAMPLE
    pwsh -File .\Push-Local.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$Message,

    [string]$Proxy,

    [switch]$NoProxy,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProxyCandidatePorts = @(7890, 7891, 10809, 10808, 8080, 7897)

function Write-Step {
    param([string]$Text)
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Note {
    param([string]$Text)
    Write-Host "    $Text" -ForegroundColor DarkGray
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFail
    )

    $output = & git @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFail) {
        throw "git $($Arguments -join ' ') 失败（exit $code）：`n$($output -join "`n")"
    }

    [pscustomobject]@{
        Code   = $code
        Output = @($output | ForEach-Object { $_.ToString() })
    }
}

function Test-ProxyPort {
    param([Parameter(Mandatory)][int]$Port)

    $client = [Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync('127.0.0.1', $Port)
        return $task.Wait(300) -and $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Find-LocalProxy {
    foreach ($port in $script:ProxyCandidatePorts) {
        if (Test-ProxyPort -Port $port) {
            return "http://127.0.0.1:$port"
        }
    }
    return $null
}

function Get-ProxyConfigArguments {
    param([string]$ProxyUrl)

    if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
        return @()
    }
    return @("-c", "http.proxy=$ProxyUrl", "-c", "https.proxy=$ProxyUrl")
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "需要 PowerShell 7 或更高版本，当前为 $($PSVersionTable.PSVersion)。"
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw '找不到 git，请先安装并加入 PATH。'
    }

    $rootResult = Invoke-Git -Arguments @('rev-parse', '--show-toplevel') -AllowFail
    if ($rootResult.Code -ne 0) {
        throw '当前目录不在 Git 仓库中。'
    }
    $repoRoot = $rootResult.Output[0]

    $branchResult = Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
    $branch = $branchResult.Output[0]
    if ($branch -eq 'HEAD') {
        throw '当前处于分离头指针状态，请先切换到分支。'
    }

    Write-Step "仓库 $repoRoot"
    Write-Note "分支 $branch"

    # 凭据：优先 gh token，避免 Git Credential Manager 的 schannel 失败
    if (-not $env:GH_TOKEN -and (Get-Command gh -ErrorAction SilentlyContinue)) {
        $tokenResult = & gh auth token 2>&1
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($tokenResult -join ''))) {
            $env:GH_TOKEN = ($tokenResult -join '').Trim()
            Write-Note '凭据：gh auth token'
        }
        else {
            Write-Note '凭据：gh 未登录，回退到系统凭据管理器'
        }
    }

    # 代理
    $proxyUrl = $null
    if (-not $NoProxy) {
        if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
            $proxyUrl = $Proxy
            Write-Note "代理：$proxyUrl（显式指定）"
        }
        else {
            $proxyUrl = Find-LocalProxy
            if ($null -eq $proxyUrl) {
                Write-Note '代理：未探测到本地代理，将直连'
            }
            else {
                Write-Note "代理：$proxyUrl（自动探测）"
            }
        }
    }
    else {
        Write-Note '代理：已禁用（-NoProxy）'
    }

    # 提交
    $statusResult = Invoke-Git -Arguments @('status', '--porcelain')
    $pending = @($statusResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($pending.Count -eq 0) {
        Write-Step '工作树无改动，跳过提交'
    }
    else {
        Write-Step "待提交 $($pending.Count) 项"
        $pending | ForEach-Object { Write-Note $_ }

        if ([string]::IsNullOrWhiteSpace($Message)) {
            $Message = '更新：同步本地改动（{0}）' -f (Get-Date -Format 'yyyy-MM-dd HH:mm')
        }
        Write-Note "提交信息：$Message"

        if ($DryRun) {
            Write-Note '[DryRun] git add -A'
            Write-Note "[DryRun] git commit -m `"$Message`""
        }
        else {
            [void](Invoke-Git -Arguments @('add', '-A'))
            $commitResult = Invoke-Git -Arguments @('commit', '-m', $Message) -AllowFail
            if ($commitResult.Code -ne 0) {
                throw "提交失败：`n$($commitResult.Output -join "`n")"
            }
            Write-Note $commitResult.Output[0]
        }
    }

    # 是否需要推送
    $aheadResult = Invoke-Git -Arguments @('rev-list', '--count', '@{u}..HEAD') -AllowFail
    $needsPush = $true
    if ($aheadResult.Code -eq 0) {
        $needsPush = [int]$aheadResult.Output[0] -gt 0
    }

    if (-not $needsPush -and $pending.Count -eq 0) {
        Write-Step '已与远端一致，无需推送'
        exit 0
    }

    $pushArguments = @(
        '-c', 'http.sslBackend=openssl',
        '-c', 'credential.helper=!gh auth git-credential'
    )

    if ($DryRun) {
        Write-Note "[DryRun] git $(Get-ProxyConfigArguments $proxyUrl) $($pushArguments -join ' ') push origin $branch"
        Write-Step '预演结束'
        exit 0
    }

    Write-Step '推送'

    $targets = [Collections.Generic.List[string]]::new()
    $targets.Add([string]$proxyUrl)
    if ($null -ne $proxyUrl) {
        $targets.Add($null)   # 代理失败后回退直连
    }

    $pushed = $false
    $lastError = $null
    $attemptCount = 0
    foreach ($target in $targets) {
        $attemptCount++
        $label = if ([string]::IsNullOrEmpty($target)) { '直连' } else { $target }
        $arguments = @(Get-ProxyConfigArguments $target) + $pushArguments + @('push', 'origin', $branch)

        $result = Invoke-Git -Arguments $arguments -AllowFail
        if ($result.Code -eq 0) {
            Write-Note "[$label] 成功"
            $result.Output | Where-Object { $_ } | ForEach-Object { Write-Note $_ }
            $pushed = $true
            break
        }

        $lastError = $result.Output -join "`n"
        Write-Note "[$label] 失败：$($result.Output | Select-Object -First 1)"
    }

    if (-not $pushed) {
        throw "推送失败，已尝试 $attemptCount 种方式。`n$lastError"
    }

    Write-Step '完成'
    $final = Invoke-Git -Arguments @('status', '-sb')
    $final.Output | Select-Object -First 1 | ForEach-Object { Write-Note $_ }
}
catch {
    Write-Host "`n[错误] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
