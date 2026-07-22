$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Require-Text([string]$relativePath, [string]$needle) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if (-not $text.Contains($needle)) { throw "Missing '$needle' in $relativePath" }
    return $text
}

& (Join-Path $PSScriptRoot "check_phase11.ps1")

foreach ($token in @("const SAVE_VERSION := 2", "func _normalize_save", "func _merge_defaults", "SaveManager found invalid save data", '"blade_storm": false', '"statistics"')) {
    Require-Text "scripts/autoload/save_manager.gd" $token | Out-Null
}
foreach ($token in @("SKILL_UNLOCK_DEFINITIONS", "func unlock_skill", "func purchase_talent", "func record_battle", "func get_statistics", "func get_master_volume_db", "func is_fullscreen", "total_crystals_earned")) {
    Require-Text "scripts/autoload/progression_manager.gd" $token | Out-Null
}
Require-Text "scripts/autoload/game_manager.gd" "ProgressionManager.record_battle" | Out-Null
Require-Text "scripts/skills/skill_manager.gd" "func _filter_locked_skills" | Out-Null
Require-Text "scripts/ui/battle_hud.gd" "slot.visible = true" | Out-Null
Require-Text "scripts/ui/battle_hud.gd" "_set_skill_slot_unavailable(slot)" | Out-Null
foreach ($token in @("GrowthButton", "SettingsButton", "GrowthPanel", "SettingsPanel", "VitalityButton", "CombatTrainingButton", "BladeStormButton", "MasterVolumeSlider", "FullscreenCheck")) {
    Require-Text "scenes/menus/main_menu.tscn" $token | Out-Null
}
foreach ($token in @("_show_growth", "_show_settings", "_on_talent_pressed", "_on_blade_storm_pressed", "_on_volume_drag_ended", "_on_fullscreen_toggled", "ui_cancel")) {
    Require-Text "scripts/ui/main_menu.gd" $token | Out-Null
}
Write-Host "Phase 12 static check passed."
