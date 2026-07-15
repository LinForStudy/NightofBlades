$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase5.ps1') | Write-Output

$requiredFiles = @(
  'scripts/resources/upgrade_data.gd',
  'scripts/progression/experience_manager.gd',
  'scripts/progression/upgrade_manager.gd',
  'scripts/progression/experience_orb.gd',
  'scenes/pickups/experience_orb.tscn',
  'scripts/tools/check_phase6.ps1'
)
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    Write-Error "Missing Phase 6 file: $file"
  }
}

$upgradeFiles = Get-ChildItem -LiteralPath (Join-Path $root 'resources/upgrades') -Filter '*.tres' | Where-Object { $_.Name -ne '.gitkeep' }
if ($upgradeFiles.Count -lt 8) {
  Write-Error "Phase 6 requires at least 8 passive upgrade resources; found $($upgradeFiles.Count)."
}

$battle = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @(
  'ExperienceManager',
  'UpgradeManager',
  'ExperienceOrbRoot',
  'LevelUpPanel',
  'UpgradeButton1',
  'sharp_blade.tres',
  'relentless.tres'
)) {
  if (-not $battle.Contains($snippet)) {
    Write-Error "Battle scene missing Phase 6 snippet: $snippet"
  }
}

$battleScript = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/ui/battle_scene.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('_on_level_up_choices_ready', 'KEY_1', 'KEY_2', 'KEY_3')) {
  if (-not $battleScript.Contains($snippet)) {
    Write-Error "BattleScene missing upgrade selection input: $snippet"
  }
}
$hud = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/ui/battle_hud.tscn'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('ExperienceBar', 'ExperienceText', 'LevelLabel')) {
  if (-not $hud.Contains($snippet)) {
    Write-Error "BattleHUD missing Phase 6 snippet: $snippet"
  }
}

$experienceManager = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/progression/experience_manager.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('spawn_experience_orb', 'add_experience', 'pending_level_ups', 'choose_upgrade', 'level_up_choices_ready')) {
  if (-not $experienceManager.Contains($snippet)) {
    Write-Error "ExperienceManager missing Phase 6 snippet: $snippet"
  }
}

$upgradeManager = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/progression/upgrade_manager.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('get_upgrade_choices', 'apply_upgrade', 'max_stacks', 'weight', 'apply_passive_upgrade')) {
  if (-not $upgradeManager.Contains($snippet)) {
    Write-Error "UpgradeManager missing Phase 6 snippet: $snippet"
  }
}

$player = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/player/player_controller.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('apply_passive_upgrade', 'attack_damage_multiplier', 'critical_chance', 'ultimate_gain_multiplier', 'max_health_bonus')) {
  if (-not $player.Contains($snippet)) {
    Write-Error "PlayerController missing Phase 6 snippet: $snippet"
  }
}

$enemyData = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/resources/enemy_data.gd'), [System.Text.Encoding]::UTF8)
if (-not $enemyData.Contains('experience_value')) {
  Write-Error 'EnemyData missing experience_value.'
}
foreach ($enemyFile in Get-ChildItem -LiteralPath (Join-Path $root 'resources/enemies') -Filter '*.tres') {
  $enemyText = [System.IO.File]::ReadAllText($enemyFile.FullName, [System.Text.Encoding]::UTF8)
  if (-not $enemyText.Contains('experience_value')) {
    Write-Error "Enemy resource missing experience_value: $($enemyFile.Name)"
  }
}

Write-Output 'Phase 6 file/config check passed.'