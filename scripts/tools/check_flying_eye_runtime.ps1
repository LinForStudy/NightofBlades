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
    $relativePath = "generated_assets/sprite_forge/enemies/flying_eye/$($contract.Action)/accepted/flying_eye_$($contract.Action)_transparent.png"
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing runtime sprite: $relativePath" }
    $image = [System.Drawing.Image]::FromFile($fullPath)
    try {
        if ($image.Width -ne $contract.Width -or $image.Height -ne $contract.Height) {
            throw "Invalid flying-eye $($contract.Action) strip: $($image.Width)x$($image.Height), expected $($contract.Width)x$($contract.Height)"
        }
    }
    finally {
        $image.Dispose()
    }
}

$projectilePath = "generated_assets/sprite_forge/enemies/flying_eye/projectile/accepted/flying_eye_projectile_transparent.png"
$projectileImage = [System.Drawing.Image]::FromFile((Join-Path $root $projectilePath))
try {
    if ($projectileImage.Width -ne 256 -or $projectileImage.Height -ne 64) {
        throw "Invalid flying-eye projectile strip: $($projectileImage.Width)x$($projectileImage.Height), expected 256x64"
    }
}
finally {
    $projectileImage.Dispose()
}

foreach ($token in @(
    'idle_sheet = ExtResource("7_idle")',
    'move_sheet = ExtResource("8_move")',
    'attack_sheet = ExtResource("9_attack")',
    'hurt_sheet = ExtResource("10_hurt")',
    'death_sheet = ExtResource("11_death")',
    'collision_layer = 2',
    'collision_mask = 1',
    'projectile_scene = ExtResource("12_projectile")',
    '[node name="EnemyVisual" type="Node2D" parent="."]',
    '[node name="Body" type="Sprite2D" parent="EnemyVisual"]',
    'script = ExtResource("13_warning")',
    'visible = false'
)) {
    Require-Text "scenes/enemies/flying_eye.tscn" $token
}

foreach ($token in @(
    'speed = 180.0',
    'animation_frames = 4',
    'texture = ExtResource("2_orb")',
    'texture_filter = 1'
)) {
    Require-Text "scenes/enemies/flying_eye_projectile.tscn" $token
}
foreach ($token in @(
    'func _process_flying',
    'desired_velocity.limit_length(maximum_speed)',
    '_state_timer = maxf(_data_aim_time(), 0.2)',
    'func _start_flying_recoil',
    'func _is_player_melee_context',
    'projectile_scene if projectile_scene != null'
)) {
    Require-Text "scripts/enemies/enemy_controller.gd" $token
}
Require-Text "scripts/enemies/enemy_projectile.gd" "animation_frames"
Require-Text "scripts/enemies/enemy_projectile.gd" "func _process_animation"

$sceneText = [System.IO.File]::ReadAllText((Join-Path $root "scenes/enemies/flying_eye.tscn"), [System.Text.Encoding]::UTF8)
foreach ($forbidden in @("/review/", "_raw.png", "sheet-transparent.png")) {
    if ($sceneText.Contains($forbidden)) { throw "FlyingEye scene references production-only asset token: $forbidden" }
}

Write-Host "Flying eye runtime contract passed."
