$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
function Require-Text([string]$Path, [string]$Needle) {
    $full = Join-Path $root $Path
    if (-not (Test-Path $full)) { throw "Missing file: $Path" }
    $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($Needle)) { throw "Missing '$Needle' in $Path" }
    return $text
}

& (Join-Path $PSScriptRoot "check_phase10.ps1")
& (Join-Path $PSScriptRoot "check_battle_map.ps1")
$hudScene = Require-Text "scenes/ui/battle_hud.tscn" "PlayerStatusPanel"
foreach ($node in @("BossStatusPanel", "PoiseBar", "PoiseText", "RunInfoPanel", "SkillBar", "AnnouncementLayer", "DebugOverlay", "UltimateSlot", "VictoryPanel", "PausePanel", "ResumeButton")) {
    if (-not $hudScene.Contains($node)) { throw "BattleHUD node missing: $node" }
}
$hudScript = Require-Text "scripts/ui/battle_hud.gd" "experience_manager_path"
foreach ($token in @("skill_cooldown_changed", "ultimate_energy_changed", "_on_boss_poise_changed", "debug_toggle", "show_defeat", "ui_cancel", "GameManager.go_to_main_menu", "_pause_battle", "GameManager.set_paused")) {
    if (-not $hudScript.Contains($token)) { throw "BattleHUD binding missing: $token" }
}
$player = Require-Text "scripts/player/player_controller.gd" "player_died.emit(self)"
foreach ($token in @("_death_handled", "PlayerState.DEAD", "drop_down", "velocity = Vector2.ZERO")) {
    if (-not $player.Contains($token)) { throw "Player death/drop logic missing: $token" }
}
$boss = Require-Text "scripts/bosses/rift_colossus_controller.gd" "boss_defeated.emit(self)"
foreach ($token in @("WINDUP", "ACTIVE", "RECOVERY", "TRANSITION", "STAGGER", "boss_announcement", "boss_poise_changed", "max_poise", "_interrupt_into_stagger", "phase_thresholds: Array[float] = [0.60, 0.25]", "activate_boss", "engagement_range", "_target_is_in_engagement_range")) {
    if (-not $boss.Contains($token)) { throw "Boss flow missing: $token" }
}
$battle = Require-Text "scenes/battle/battle_scene.tscn" "BattleHUD"
foreach ($token in @("OverlayUI", "LevelUpPanel")) {
    if (-not $battle.Contains($token)) { throw "Battle overlay missing: $token" }
}
foreach ($legacyNode in @("BattlePlaceholderUI", "TopBar", "SkillHUD", "ReturnToMenuButton")) {
    if ($battle.Contains($legacyNode)) { throw "Legacy battle HUD node remains: $legacyNode" }
}
foreach ($platform_position in @("position = Vector2(670, 526)", "position = Vector2(980, 466)")) {
    if (-not $battle.Contains($platform_position)) { throw "Battle platform reachability setup missing: $platform_position" }
}
foreach ($token in @("VillageSilhouette", "Step1", "Step2", "Step3")) {
    if (-not $battle.Contains($token)) { throw "Battle graybox missing: $token" }
}
if ($battle.Contains("DodgeTestHazard")) { throw "Dodge test hazard is still in BattleScene." }
Require-Text "project.godot" "debug_toggle" | Out-Null
Require-Text "scripts/autoload/event_bus.gd" "battle_finished(success: bool)" | Out-Null
Require-Text "scripts/autoload/game_manager.gd" "func finish_battle(success: bool)" | Out-Null
Require-Text "scripts/ui/battle_scene.gd" "func _setup_phase10_completion()" | Out-Null
Require-Text "scripts/ui/battle_scene.gd" "wave_manager.stop_waves()" | Out-Null
Require-Text "scripts/ui/battle_scene.gd" "clear_active_enemies" | Out-Null
Require-Text "scripts/waves/wave_manager.gd" "func clear_active_enemies()" | Out-Null
Require-Text "scripts/waves/wave_manager.gd" "func _entry_target_x" | Out-Null
Require-Text "scripts/enemies/enemy_controller.gd" "func begin_entry" | Out-Null
Require-Text "scenes/battle/battle_scene.tscn" "BossEntrance" | Out-Null
Write-Host "Phase 10.5 static check passed."