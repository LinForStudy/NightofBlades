$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
}

Require-Text "scripts/ui/battle_hud.gd" "MobileControls"
Require-Text 'scripts/ui/battle_hud.gd' 'OS.has_feature("mobile")'
Require-Text "scripts/ui/mobile_controls.gd" "Input.parse_input_event(event)"
Require-Text "scripts/ui/mobile_controls.gd" "func _dispatch_action"
foreach ($action in @('move_left', 'move_right', 'jump', 'attack', 'dodge', 'skill_1', 'skill_2', 'skill_3', 'ultimate')) {
    Require-Text "scripts/ui/mobile_controls.gd" ('&"' + $action + '"')
}
Require-Text "scripts/ui/battle_scene.gd" "Tap an upgrade card to continue"
Write-Host "Mobile controls static check passed."