$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
}

& (Join-Path $PSScriptRoot "check_phase10_5.ps1")
& (Join-Path $PSScriptRoot "check_rift_grunt_runtime.ps1")
& (Join-Path $PSScriptRoot "check_rift_archer_runtime.ps1")
& (Join-Path $PSScriptRoot "check_rift_bomber_runtime.ps1")
& (Join-Path $PSScriptRoot "check_flying_eye_runtime.ps1")
& (Join-Path $PSScriptRoot "check_monster_pair_runtime_validation.ps1")
& (Join-Path $PSScriptRoot "check_player_attack_visuals.ps1")
& (Join-Path $PSScriptRoot "check_skill_visuals.ps1")
foreach ($token in @("func start_new_game()", "func restart_battle()", "func go_to_main_menu()", "func finish_battle(success: bool)", "func _reset_runtime_state()", "Engine.time_scale = 1.0", "GameState.RESULT")) {
    Require-Text "scripts/autoload/game_manager.gd" $token
}
Require-Text "scripts/ui/battle_hud.gd" "GameManager.restart_battle()"
foreach ($token in @("DefeatRestartButton", "DefeatMenuButton", "VictoryRestartButton", "VictoryMenuButton")) {
    Require-Text "scenes/ui/battle_hud.tscn" $token
}
Require-Text "scripts/ui/battle_scene.gd" "GameManager.set_battle_result_stats"
Require-Text "scripts/ui/battle_scene.gd" "battle_hud.set_run_stats"
Require-Text "scripts/ui/battle_hud.gd" "func set_run_stats"
Require-Text "scenes/menus/main_menu.tscn" "[node name=""Subtitle"""
Require-Text "scenes/bootstrap/bootstrap.tscn" "res://scripts/core/bootstrap.gd"
Require-Text "scripts/core/bootstrap.gd" "GameManager.go_to_main_menu()"
foreach ($token in @("CharacterSelectPanel", "EnterBattleButton", "CharacterBackButton")) {
    Require-Text "scenes/menus/main_menu.tscn" $token
}
foreach ($token in @("_on_enter_battle_pressed", "_show_main_menu", "ui_cancel")) {
    Require-Text "scripts/ui/main_menu.gd" $token
}
Write-Host "Phase 11 static check passed."