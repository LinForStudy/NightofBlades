$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
    return $text
}

function Require-JoypadBinding([string]$action) {
    $project = Require-Text "project.godot" "$action={"
    $pattern = "(?s)" + [regex]::Escape($action) + "={.*?InputEventJoypad.*?
}"
    if (-not [regex]::IsMatch($project, $pattern)) {
        throw "Missing joypad binding for input action: $action"
    }
}

& (Join-Path $PSScriptRoot "check_phase12.ps1")

$projectText = Require-Text "project.godot" "window/size/viewport_width=1280"
foreach ($token in @('window/size/viewport_height=720', 'window/stretch/mode="canvas_items"', 'renderer/rendering_method="gl_compatibility"', 'renderer/rendering_method.mobile="gl_compatibility"')) {
    if (-not $projectText.Contains($token)) { throw "Missing release display configuration: $token" }
}
foreach ($action in @("move_left", "move_right", "jump", "attack", "charge_attack", "dodge", "skill_1", "skill_2", "skill_3", "ultimate", "pause")) {
    Require-JoypadBinding $action
}
Require-Text "scripts/autoload/object_pool_manager.gd" "func recycle_object" | Out-Null
Require-Text "scripts/waves/wave_manager.gd" "ObjectPoolManager.recycle_object" | Out-Null
Require-Text "docs/phase13_release_checklist.md" "Godot --headless --path" | Out-Null
Require-Text "scenes/tools/battle_hud_runtime_validation_runner.tscn" "battle_hud_runtime_validation_runner.gd" | Out-Null
Require-Text "scripts/tools/battle_hud_runtime_validation_runner.gd" "BattleHudRuntimeValidationController" | Out-Null
Require-Text "scripts/tools/battle_hud_runtime_validation.gd" "Battle HUD runtime validation passed" | Out-Null

$referenceFiles = Get-ChildItem -LiteralPath (Join-Path $root "scenes"), (Join-Path $root "scripts"), (Join-Path $root "resources") -Recurse -File -Include *.gd,*.tscn,*.tres | Where-Object { $_.FullName -notmatch "\\scripts\\tools\\" }
foreach ($referenceFile in $referenceFiles) {
    $content = [System.IO.File]::ReadAllText($referenceFile.FullName, [System.Text.Encoding]::UTF8)
    foreach ($match in [regex]::Matches($content, 'res://[A-Za-z0-9_./-]+')) {
        $relativePath = $match.Value.Substring(6)
        if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath))) {
            throw "Broken res:// reference in $($referenceFile.FullName): $($match.Value)"
        }
    }
}

$manifestPath = Join-Path $root "generated_assets\sprite_forge\manifests\asset_manifest.json"
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
foreach ($asset in $manifest.assets) {
    if ($asset.status -ne "accepted" -or -not $asset.game_path) {
        continue
    }
    $relativePath = ([string]$asset.game_path).Substring(6)
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath))) {
        throw "Accepted asset missing from game path: $($asset.id) -> $($asset.game_path)"
    }
}
Write-Host "Phase 13 release-preflight check passed."