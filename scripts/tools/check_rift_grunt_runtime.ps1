$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
}

Add-Type -AssemblyName System.Drawing
$contracts = @(
    @{ Action = "idle"; Width = 384; Height = 96 },
    @{ Action = "move"; Width = 384; Height = 96 },
    @{ Action = "attack"; Width = 384; Height = 96 },
    @{ Action = "hurt"; Width = 192; Height = 96 },
    @{ Action = "death"; Width = 576; Height = 96 }
)
foreach ($contract in $contracts) {
    $relativePath = "generated_assets/sprite_forge/enemies/rift_grunt/$($contract.Action)/accepted/rift_grunt_$($contract.Action)_transparent.png"
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing runtime sprite: $relativePath" }
    $image = [System.Drawing.Image]::FromFile($fullPath)
    try {
        if ($image.Width -ne $contract.Width -or $image.Height -ne $contract.Height) {
            throw "Invalid $($contract.Action) runtime strip size: $($image.Width)x$($image.Height), expected $($contract.Width)x$($contract.Height)"
        }
    }
    finally {
        $image.Dispose()
    }
}

foreach ($token in @(
    'idle_sheet = ExtResource("7_idle")',
    'move_sheet = ExtResource("8_move")',
    'attack_sheet = ExtResource("9_attack")',
    'hurt_sheet = ExtResource("10_hurt")',
    'death_sheet = ExtResource("11_death")',
    "position = Vector2(0, -29)"
)) {
    Require-Text "scenes/enemies/rift_grunt.tscn" $token
}
Require-Text "scripts/enemies/enemy_visual.gd" "func play_attack(_enemy: Node = null)"
Require-Text "scripts/enemies/enemy_visual.gd" "body.hframes = _frames"
Require-Text "scripts/enemies/enemy_visual.gd" "body.vframes = 1"
Require-Text "scripts/enemies/enemy_visual.gd" "body.frame = clampi(_frame, 0, _frames - 1)"
Require-Text "scripts/player/player_controller.gd" "var _attack_feedback_sent := false"
Require-Text "scripts/player/player_controller.gd" "if not _attack_feedback_sent and battle != null"
Require-Text "scripts/progression/experience_manager.gd" 'call_deferred("_attach_experience_orb"'
Require-Text "scripts/progression/experience_orb.gd" 'set_deferred("monitoring", false)'

$sceneText = [System.IO.File]::ReadAllText((Join-Path $root "scenes/enemies/rift_grunt.tscn"), [System.Text.Encoding]::UTF8)
foreach ($forbidden in @("/review/", "_raw.png", "sheet-transparent.png")) {
    if ($sceneText.Contains($forbidden)) { throw "RiftGrunt scene references production-only asset token: $forbidden" }
}

Write-Host "Rift grunt runtime/performance contract passed."