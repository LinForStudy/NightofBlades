$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
}

Add-Type -AssemblyName System.Drawing
foreach ($relativePath in @(
    "generated_assets/sprite_forge/fx/player/slash_arc/accepted/nightwatcher_slash_arc_transparent.png",
    "generated_assets/sprite_forge/fx/player/hit_spark/accepted/nightwatcher_hit_spark_transparent.png"
)) {
    $image = [System.Drawing.Image]::FromFile((Join-Path $root $relativePath))
    try {
        if ($image.Width -ne 384 -or $image.Height -ne 96) {
            throw "Invalid runtime FX strip size for $relativePath`: $($image.Width)x$($image.Height), expected 384x96"
        }
    }
    finally {
        $image.Dispose()
    }
}

Require-Text "scripts/player/player_controller.gd" "func _update_attack_arc(_is_visible: bool)"
Require-Text "scripts/player/player_controller.gd" "attack_arc.visible = false"
Require-Text "scripts/player/player_controller.gd" "player_visual.modulate = Color(1.0, 0.38, 0.38, 1.0)"
Require-Text "scripts/player/player_visual.gd" "sprite.vframes = 1"
Require-Text "scenes/player/player.tscn" "position = Vector2(0, -44)"

$controller = [System.IO.File]::ReadAllText((Join-Path $root "scripts/player/player_controller.gd"), [System.Text.Encoding]::UTF8)
foreach ($forbidden in @("attack_arc.visible = is_visible", "hit_flash.visible = true")) {
    if ($controller.Contains($forbidden)) { throw "Legacy player color block is still activated: $forbidden" }
}

Write-Host "Player attack visual contract passed."