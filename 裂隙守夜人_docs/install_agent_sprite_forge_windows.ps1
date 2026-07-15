$ErrorActionPreference = "Stop"

$repoDir = Join-Path $env:USERPROFILE "agent-sprite-forge"
$skillsDir = Join-Path $env:USERPROFILE ".codex\skills"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "未检测到 Git，请先安装 Git for Windows。"
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "未检测到 Python，请先安装 Python 3。"
}

if (Test-Path $repoDir) {
    Write-Host "更新已有 agent-sprite-forge..."
    git -C $repoDir pull
} else {
    Write-Host "克隆 agent-sprite-forge..."
    git clone https://github.com/0x0funky/agent-sprite-forge.git $repoDir
}

Write-Host "安装 Python 依赖..."
python -m pip install -r (Join-Path $repoDir "requirements.txt")

Write-Host "复制 Codex skills..."
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $repoDir "skills\*") $skillsDir

$required = @(
    (Join-Path $skillsDir "generate2dsprite\SKILL.md"),
    (Join-Path $skillsDir "generate2dmap\SKILL.md")
)

foreach ($path in $required) {
    if (-not (Test-Path $path)) {
        throw "安装校验失败，缺少：$path"
    }
}

Write-Host "安装完成。请关闭当前 Codex 会话并新建会话，以重新加载技能。"
