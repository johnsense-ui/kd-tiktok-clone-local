# 推到 GitHub → 跑 Actions（macOS runner 编译）→ 把未签名 ipa 拉回 dist\
# 用法：右键「使用 PowerShell 运行」，或 cd 进来后 .\push_and_build.ps1

$ErrorActionPreference = 'Stop'

# ============ 配置 ============
$RepoRoot  = 'F:\新建文件夹\TiktokClone'
$RepoName  = 'kd-tiktok-clone-local'
$DistDir   = 'F:\新建文件夹\dist'
$Workflow  = 'build-ipa.yml'
$Public    = $true      # true = 公开仓库（Actions 免费不限时）；false = 私有（macOS 有 10 倍计费）
$GhVersion = '2.62.0'
# ==============================

Set-Location $RepoRoot
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

function Step($n, $t) { Write-Host "`n[$n] $t" -ForegroundColor Cyan }

# ---------- 1. gh ----------
Step '1/6' '检查 gh CLI'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host '  没装，正在下载...' -ForegroundColor Yellow
    $tmp = Join-Path $env:TEMP 'ghcli'
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'gh.zip'
    $url = "https://gh-proxy.com/https://github.com/cli/cli/releases/download/v$GhVersion/gh_${GhVersion}_windows_amd64.zip"
    curl.exe -L --max-time 600 -o $zip $url
    if (-not (Test-Path $zip)) { throw "gh 下载失败：$url" }
    Expand-Archive $zip -DestinationPath $tmp -Force
    $bin = Get-ChildItem $tmp -Recurse -Filter gh.exe | Select-Object -First 1
    $env:Path = "$(Split-Path $bin.FullName);$env:Path"
    Write-Host "  gh: $($bin.FullName)" -ForegroundColor Green
}
gh --version | Select-Object -First 1

# ---------- 2. 登录 ----------
Step '2/6' 'GitHub 登录（只需一次，浏览器里点授权）'
gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    gh auth login -h github.com -p https -w
    if ($LASTEXITCODE -ne 0) { throw '登录没完成' }
}
$me = gh api user --jq .login
Write-Host "  账号：$me" -ForegroundColor Green

# ---------- 3. 提交 ----------
Step '3/6' '提交本地改动'
if (-not (Test-Path "$RepoRoot\.git")) { git init | Out-Null }
git add -A
git -c user.name="dzc" -c user.email="dzc@local" commit -m "接本地视频库：/api/videos + /api/stream，移除 Firebase，加 CI 出包" 2>$null
git branch -M main
Write-Host ("  改动文件：" + (git status --porcelain).Count) -ForegroundColor Green

# ---------- 4. 建仓推送 ----------
Step '4/6' "建仓库 $me/$RepoName 并推送"
git remote remove origin 2>$null
$exists = $null
gh repo view "$me/$RepoName" --json name 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $exists = $true }

if ($exists) {
    Write-Host '  仓库已存在，直接覆盖推送' -ForegroundColor Yellow
    git remote add origin "https://github.com/$me/$RepoName.git"
    git push -u origin main --force
} else {
    $vis = if ($Public) { '--public' } else { '--private' }
    gh repo create $RepoName $vis --source . --remote origin --push
}
if ($LASTEXITCODE -ne 0) { throw '推送失败' }

# ---------- 5. 触发 ----------
Step '5/6' '触发 Actions（编译 10~25 分钟）'
gh workflow run $Workflow --ref main
Start-Sleep -Seconds 8
$run = gh run list --workflow=$Workflow --limit 1 --json databaseId --jq '.[0].databaseId'
if (-not $run) { throw '没拿到 run id，去 Actions 页面点一次 Run workflow' }
Write-Host "  run: https://github.com/$me/$RepoName/actions/runs/$run" -ForegroundColor Yellow

gh run watch $run --exit-status
$ok = ($LASTEXITCODE -eq 0)

# ---------- 6. 取产物 ----------
if ($ok) {
    Step '6/6' '下载 ipa'
    $out = Join-Path $env:TEMP "gh-run-$run"
    Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
    gh run download $run -D $out
    $ipa = Get-ChildItem $out -Recurse -Filter *.ipa | Select-Object -First 1
    if (-not $ipa) { throw '没找到 ipa' }
    $final = Join-Path $DistDir 'KD-Tiktok-Clone-unsigned.ipa'
    Copy-Item $ipa.FullName $final -Force
    Write-Host "`n完成：$final" -ForegroundColor Green
    Write-Host ("大小：{0:N1} MB" -f ((Get-Item $final).Length / 1MB)) -ForegroundColor Green
    Write-Host "`n装法：Sideloadly 选这个 ipa → 免费 Apple ID → Start → 手机 设置-通用-VPN与设备管理 信任证书" -ForegroundColor Green
    Start-Process explorer.exe -ArgumentList "/select,`"$final`""
} else {
    Step '!' '编译失败'
    Write-Host '  最后 60 行日志：' -ForegroundColor Red
    gh run view $run --log-failed 2>$null | Select-Object -Last 60
    Write-Host "`n  完整日志：https://github.com/$me/$RepoName/actions/runs/$run" -ForegroundColor Yellow
    Write-Host '  把红色报错发我，我按 Xcode 的报错改代码。' -ForegroundColor Yellow
}
