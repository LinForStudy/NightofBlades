$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase7.ps1') | Write-Output

$requiredFiles = @(
  'scripts/resources/skill_upgrade_data.gd',
  'scripts/skills/skill_manager.gd',
  'scripts/skills/skill_effect.gd',
  'scripts/tools/check_phase8.ps1'
)
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { Write-Error "Missing Phase 8 file: $file" }
}

$upgradeFiles = Get-ChildItem -LiteralPath (Join-Path $root 'resources/skill_upgrades') -Filter '*.tres'
if ($upgradeFiles.Count -lt 21) { Write-Error "Phase 8 requires 21 skill upgrade resources; found $($upgradeFiles.Count)." }

$manager = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/skills/skill_manager.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('get_available_skill_upgrades', 'is_skill_upgrade_available', 'apply_skill_upgrade', 'branch_id', 'target_level', 'extra_tags', 'cooldown_multiplier')) {
  if (-not $manager.Contains($snippet)) { Write-Error "SkillManager missing Phase 8 behavior: $snippet" }
}

$upgradeManager = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/progression/upgrade_manager.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('SkillUpgradeData', 'skill_manager_path', 'get_available_skill_upgrades', 'apply_skill_upgrade', 'get_max_progress')) {
  if (-not $upgradeManager.Contains($snippet)) { Write-Error "UpgradeManager missing Phase 8 behavior: $snippet" }
}

$playerScene = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/player/player.tscn'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('skill_upgrades = Array[Resource]', 'fire_slash_explosive_lv3.tres', 'fire_slash_giant_lv3.tres', 'lightning_dash_chain_lv3.tres', 'lightning_dash_afterimage_lv3.tres', 'blade_storm_pull_lv3.tres', 'blade_storm_barrage_lv3.tres')) {
  if (-not $playerScene.Contains($snippet)) { Write-Error "Player scene missing Phase 8 upgrade: $snippet" }
}

$battle = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('skill_manager_path')) {
  if (-not $battle.Contains($snippet)) { Write-Error "Battle scene missing Phase 8 setup: $snippet" }
}

foreach ($skillId in @('fire_slash', 'lightning_dash', 'blade_storm')) {
  $skillUpgrades = @($upgradeFiles | Where-Object { ([System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)).Contains("skill_id = &`"$skillId`"") })
  if ($skillUpgrades.Count -lt 7) { Write-Error "Skill $skillId is missing its full evolution path." }
}

Write-Output 'Phase 8 file/config check passed.'