$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Read-RequiredFile([string]$relativePath) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    return [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
}

function Require-Token([string]$text, [string]$token, [string]$context) {
    if (-not $text.Contains($token)) { throw "Missing '$token' in $context" }
}

$hudScene = Read-RequiredFile "scenes/ui/battle_hud.tscn"
$hudScript = Read-RequiredFile "scripts/ui/battle_hud.gd"
$pickupScene = Read-RequiredFile "scenes/ui/world/equipment_pickup_prompt.tscn"
$pickupScript = Read-RequiredFile "scripts/ui/equipment_pickup_prompt.gd"
$battleScene = Read-RequiredFile "scenes/battle/battle_scene.tscn"

foreach ($token in @(
    'offset_left = 20.0',
    'offset_top = 20.0',
    'offset_right = 320.0',
    'offset_bottom = 108.0',
    'offset_left = -170.0',
    'offset_right = -20.0',
    'offset_bottom = 144.0',
    'offset_left = -215.0',
    'offset_top = -104.0',
    'offset_right = 215.0',
    'offset_bottom = -14.0',
    'custom_minimum_size = Vector2(64, 64)',
    'custom_minimum_size = Vector2(76, 76)',
    ('text = "' + [char]0x5371 + [char]0x9669 + ' I"'),
    'texture_filter = 1',
    'UltimateIconTexture',
    'LowHealthFrame'
)) {
    Require-Token $hudScene $token "scenes/ui/battle_hud.tscn"
}

foreach ($legacy in @('PlaceholderIcon', 'Danger I', 'text = "//"', 'text = ">>"', 'text = "[]"', 'text = "X"', ('text = "' + [char]0x5C31 + [char]0x7EEA + '"'))) {
    if ($hudScene.Contains($legacy)) { throw "Legacy HUD placeholder remains: $legacy" }
}

foreach ($token in @(
    'health.health_changed.connect(_on_player_health_changed)',
    '_player.ultimate_energy_changed.connect(_on_ultimate_energy_changed)',
    '_skill_manager.skill_cooldown_changed.connect(_on_skill_cooldown_changed)',
    '_skill_manager.skill_upgrade_applied.connect(_on_skill_upgrade_applied)',
    '_experience_manager.experience_changed.connect(_on_experience_changed)',
    'func _set_skill_slot_cooldown_visual',
    'func _update_low_health_pulse',
    'func _update_ultimate_ready_glow'
)) {
    Require-Token $hudScript $token "scripts/ui/battle_hud.gd"
}

Add-Type -AssemblyName System.Drawing
foreach ($icon in @(
    'icon_skill_fire_slash.png',
    'icon_skill_lightning_dash.png',
    'icon_skill_blade_storm.png',
    'icon_ultimate_rift_eye.png',
    'icon_stat_time.png',
    'icon_stat_kills.png',
    'icon_stat_combo.png',
    'icon_stat_danger.png',
    'icon_equipment_relic.png'
)) {
    $matches = Get-ChildItem -LiteralPath (Join-Path $root 'assets\ui\hud') -Recurse -File -Filter $icon
    if ($matches.Count -ne 1) { throw "Expected one runtime HUD icon named $icon, found $($matches.Count)" }
    $image = [System.Drawing.Image]::FromFile($matches[0].FullName)
    try {
        if ($image.Width -ne 40 -or $image.Height -ne 40) {
            throw "HUD icon must be 40x40: $icon is $($image.Width)x$($image.Height)"
        }
    }
    finally {
        $image.Dispose()
    }
    $importText = [System.IO.File]::ReadAllText($matches[0].FullName + '.import', [System.Text.Encoding]::UTF8)
    Require-Token $importText 'mipmaps/generate=false' "$icon import settings"
}
Require-Token $pickupScene '[node name="EquipmentPickupPrompt" type="Node2D"]' "equipment pickup prompt scene"
Require-Token $pickupScene ('text = "[E] ' + [char]0x62FE + [char]0x53D6 + '"') "equipment pickup prompt scene"
Require-Token $pickupScript 'func set_item_display' "equipment pickup prompt script"
Require-Token $pickupScript 'func set_pickup_active' "equipment pickup prompt script"
foreach ($forbidden in @('Area2D', 'CollisionShape2D', 'Input.', '_input(', '_unhandled_input(')) {
    if ($pickupScene.Contains($forbidden) -or $pickupScript.Contains($forbidden)) {
        throw "Equipment prompt must remain display-only; found forbidden token: $forbidden"
    }
}

Require-Token $battleScene '[node name="CanvasLayer" type="CanvasLayer" parent="."]' "BattleScene"
Require-Token $battleScene 'path="res://scenes/ui/battle_hud.tscn"' "BattleScene HUD resource"

Write-Host "Battle HUD visual/static check passed."