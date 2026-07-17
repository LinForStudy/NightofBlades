$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
}

$skillScenes = @(
    "scenes/skills/fire_slash.tscn",
    "scenes/skills/lightning_dash.tscn",
    "scenes/skills/blade_storm.tscn",
    "scenes/skills/skyfall_slash.tscn"
)

foreach ($scene in $skillScenes) {
    $text = [System.IO.File]::ReadAllText((Join-Path $root $scene), [System.Text.Encoding]::UTF8)
    if ($text.Contains('type="ColorRect"')) { throw "Runtime skill scene still uses ColorRect placeholder: $scene" }
    Require-Text $scene 'type="Sprite2D"'
    Require-Text $scene 'res://scripts/skills/skill_visual_sprite.gd'
    Require-Text $scene 'hframes = 4'
}

Require-Text "scenes/skills/fire_slash.tscn" "nightwatcher_slash_arc_transparent.png"
Require-Text "scenes/skills/lightning_dash.tscn" "nightwatcher_slash_arc_transparent.png"
Require-Text "scenes/skills/blade_storm.tscn" "nightwatcher_slash_arc_transparent.png"
Require-Text "scenes/skills/skyfall_slash.tscn" "nightwatcher_hit_spark_transparent.png"
Require-Text "scripts/skills/skill_visual_sprite.gd" "extends Sprite2D"

Write-Host "Skill visual contract passed."