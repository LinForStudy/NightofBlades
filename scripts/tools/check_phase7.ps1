$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase6.ps1') | Write-Output

$requiredFiles = @(
  'scripts/resources/skill_data.gd',
  'scripts/skills/skill_cooldown_component.gd',
  'scripts/skills/skill_effect.gd',
  'scripts/skills/skill_manager.gd',
  'scripts/skills/fire_slash.gd',
  'scripts/skills/lightning_dash.gd',
  'scripts/skills/blade_storm.gd',
  'scenes/skills/fire_slash.tscn',
  'scenes/skills/lightning_dash.tscn',
  'scenes/skills/blade_storm.tscn',
  'resources/skills/fire_slash.tres',
  'resources/skills/lightning_dash.tres',
  'resources/skills/blade_storm.tres',
  'scripts/tools/check_phase7.ps1'
)
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    Write-Error "Missing Phase 7 file: $file"
  }
}

$skillData = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/resources/skill_data.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('skill_id', 'skill_scene', 'base_cooldown', 'base_damage', 'max_level', 'tags')) {
  if (-not $skillData.Contains($snippet)) {
    Write-Error "SkillData missing required field: $snippet"
  }
}

$skillManager = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/skills/skill_manager.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('skills: Array[Resource]', 'input_actions', 'try_cast', 'SkillCooldownComponent', 'skill_cooldown_changed', 'scene.instantiate')) {
  if (-not $skillManager.Contains($snippet)) {
    Write-Error "SkillManager missing Phase 7 behavior: $snippet"
  }
}

$cooldowns = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/skills/skill_cooldown_component.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('start_cooldown', 'is_ready', 'cooldown_changed', '_physics_process')) {
  if (-not $cooldowns.Contains($snippet)) {
    Write-Error "Cooldown component missing Phase 7 behavior: $snippet"
  }
}

$playerScene = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/player/player.tscn'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('SkillManager', 'SkillCooldownComponent', 'fire_slash.tres', 'lightning_dash.tres', 'blade_storm.tres', 'size = Vector2(116, 104)', 'position = Vector2(70, -54)')) {
  if (-not $playerScene.Contains($snippet)) {
    Write-Error "Player scene missing Phase 7 setup: $snippet"
  }
}

$player = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/player/player_controller.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('can_cast_active_skill', 'perform_skill_dash', 'world_bounds := Rect2(18.0, -80.0, 2364.0, 728.0)', '_clamp_to_world_bounds')) {
  if (-not $player.Contains($snippet)) {
    Write-Error "PlayerController missing generic active skill interface: $snippet"
  }
}
if ($player.Contains('fire_slash') -or $player.Contains('lightning_dash') -or $player.Contains('blade_storm')) {
  Write-Error 'PlayerController must not branch on individual active skill names.'
}

$hud = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/ui/battle_hud.tscn'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('SkillBar', 'SkillSlot1', 'SkillSlot2', 'SkillSlot3', '[U]', '[I]', '[O]')) {
  if (-not $hud.Contains($snippet)) {
    Write-Error "BattleHUD missing Phase 7 snippet: $snippet"
  }
}

$hudScript = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/ui/battle_hud.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('skill_cooldown_changed', '_on_skill_cooldown_changed', 'get_skill_data')) {
  if (-not $hudScript.Contains($snippet)) {
    Write-Error "BattleHUD script missing Phase 7 behavior: $snippet"
  }
}

foreach ($skillFile in Get-ChildItem -LiteralPath (Join-Path $root 'resources/skills') -Filter '*.tres' | Where-Object { $_.Name -ne 'skyfall_slash.tres' }) {
  $skill = [System.IO.File]::ReadAllText($skillFile.FullName, [System.Text.Encoding]::UTF8)
  foreach ($snippet in @('skill_id', 'skill_scene', 'base_cooldown', 'base_damage')) {
    if (-not $skill.Contains($snippet)) {
      Write-Error "Skill resource $($skillFile.Name) missing $snippet"
    }
  }
}

Write-Output 'Phase 7 file/config check passed.'