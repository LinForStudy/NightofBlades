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
    $relativePath = "generated_assets/sprite_forge/enemies/rift_bomber/$($contract.Action)/accepted/rift_bomber_$($contract.Action)_transparent.png"
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing runtime sprite: $relativePath" }
    $image = [System.Drawing.Image]::FromFile($fullPath)
    try {
        if ($image.Width -ne $contract.Width -or $image.Height -ne $contract.Height) {
            throw "Invalid bomber $($contract.Action) strip: $($image.Width)x$($image.Height), expected $($contract.Width)x$($contract.Height)"
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
    'collision_layer = 2',
    'collision_mask = 1',
    '[node name="EnemyVisual" type="Node2D" parent="."]',
    '[node name="Body" type="Sprite2D" parent="EnemyVisual"]',
    '[sub_resource type="CircleShape2D" id="CircleShape2D_explosion"]',
    'radius = 90.0',
    'shape = SubResource("CircleShape2D_explosion")',
    'script = ExtResource("12_warning")',
    'scale = Vector2(1, 0.34)',
    'visual_scale = 1.45',
    'position = Vector2(0, -20)',
    '[node name="ContactShadow" type="Polygon2D" parent="."]',
    'visible = false'
)) {
    Require-Text "scenes/enemies/bomber.tscn" $token
}

Require-Text "scripts/combat/hitbox_component.gd" "func activate_radial"
Require-Text "scripts/enemies/enemy_controller.gd" 'attack_hitbox.call("activate_radial"'
Require-Text "scripts/enemies/enemy_controller.gd" '_state_timer = maxf(_data_aim_time(), 0.1)'

$sceneText = [System.IO.File]::ReadAllText((Join-Path $root "scenes/enemies/bomber.tscn"), [System.Text.Encoding]::UTF8)
foreach ($forbidden in @("/review/", "_raw.png", "sheet-transparent.png")) {
    if ($sceneText.Contains($forbidden)) { throw "Bomber scene references production-only asset token: $forbidden" }
}

Write-Host "Rift bomber runtime contract passed."
