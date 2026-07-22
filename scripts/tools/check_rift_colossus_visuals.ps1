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
    @{ Path = "generated_assets/sprite_forge/bosses/rift_colossus/idle/accepted/rift_colossus_idle_transparent.png"; Width = 576; Height = 576 },
    @{ Path = "generated_assets/sprite_forge/bosses/rift_colossus/slam/accepted/rift_colossus_slam_transparent.png"; Width = 384; Height = 384 },
    @{ Path = "generated_assets/sprite_forge/bosses/rift_colossus/shockwave/accepted/rift_colossus_shockwave_transparent.png"; Width = 384; Height = 384 }
)
foreach ($contract in $contracts) {
    $fullPath = Join-Path $root $contract.Path
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing runtime sprite: $($contract.Path)" }
    $image = [System.Drawing.Image]::FromFile($fullPath)
    try {
        if ($image.Width -ne $contract.Width -or $image.Height -ne $contract.Height) {
            throw "Invalid Boss runtime sprite size: $($contract.Path) is $($image.Width)x$($image.Height)"
        }
    }
    finally {
        $image.Dispose()
    }
}

foreach ($token in @(
    'script = ExtResource("5_visual")',
    'idle_sheet = ExtResource("6_idle")',
    'slam_sheet = ExtResource("7_slam")',
    'shockwave_sheet = ExtResource("8_shockwave")',
    'texture_filter = 1',
    'position = Vector2(0, -82)',
    'visible = false'
)) {
    Require-Text "scenes/bosses/rift_colossus.tscn" $token
}
foreach ($token in @(
    'func play_idle() -> void:',
    'func play_attack(_tag: StringName, direction: int) -> void:',
    'func trigger_attack_fx(_tag: StringName, direction: int) -> void:',
    'body.hframes = 3',
    'body.vframes = 3',
    'attack_fx.hframes = 2',
    'attack_fx.vframes = 2'
)) {
    Require-Text "scripts/bosses/rift_colossus_visual.gd" $token
}
foreach ($token in @(
    'visual.play_attack(StringName(_current_attack["tag"]), _facing_to_target())',
    'visual.trigger_attack_fx(StringName(_current_attack["tag"]), _facing_to_target())',
    'warning_area.visible = false',
    'attack_hitbox.activate(self'
)) {
    Require-Text "scripts/bosses/rift_colossus_controller.gd" $token
}

$sceneText = [System.IO.File]::ReadAllText((Join-Path $root "scenes/bosses/rift_colossus.tscn"), [System.Text.Encoding]::UTF8)
foreach ($forbidden in @("/raw-sheet", "/sheet-transparent.png", "/review/")) {
    if ($sceneText.Contains($forbidden)) { throw "Boss scene references non-runtime asset token: $forbidden" }
}

Write-Host "Rift Colossus visual and attack FX contract passed."