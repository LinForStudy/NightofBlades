$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
}

Add-Type -AssemblyName System.Drawing
foreach ($action in @("idle", "move", "attack")) {
    $relativeSprite = "generated_assets/sprite_forge/enemies/rift_archer/$action/accepted/rift_archer_$($action)_transparent.png"
    $fullSprite = Join-Path $root $relativeSprite
    if (-not (Test-Path -LiteralPath $fullSprite)) { throw "Missing runtime sprite: $relativeSprite" }
    $image = [System.Drawing.Image]::FromFile($fullSprite)
    try {
        if ($image.Width -ne 384 -or $image.Height -ne 96) {
            throw "Invalid archer $action runtime strip size: $($image.Width)x$($image.Height), expected 384x96"
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
    'position = Vector2(0, -29)',
    'visible = false'
)) {
    Require-Text "scenes/enemies/archer.tscn" $token
}
$sceneText = [System.IO.File]::ReadAllText((Join-Path $root "scenes/enemies/archer.tscn"), [System.Text.Encoding]::UTF8)
foreach ($forbidden in @("/review/", "_raw.png", "sheet-transparent.png")) {
    if ($sceneText.Contains($forbidden)) { throw "Archer scene references production-only asset token: $forbidden" }
}

Write-Host "Rift archer runtime contract passed."