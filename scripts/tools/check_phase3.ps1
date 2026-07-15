$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase2.ps1') | Write-Output

$requiredFiles = @(
  'scripts/combat/dodge_test_hazard.gd',
  'scenes/effects/dodge_test_hazard.tscn',
  'scenes/tools/phase3_validation_runner.tscn',
  'scripts/tools/phase3_validation_controller.gd'
)
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    Write-Error "Missing Phase 3 file: $file"
  }
}

$player = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/player/player_controller.gd'), [System.Text.Encoding]::UTF8)
$snippets = @('DODGE', 'perfect_dodge', 'dodge_cooldown', 'perfect_dodge_window', 'ultimate_energy_changed')
foreach ($snippet in $snippets) {
  if (-not $player.Contains($snippet)) {
    Write-Error "Player controller missing Phase 3 snippet: $snippet"
  }
}

# The Phase 3 test hazard remains a reusable test scene, but Phase 10.5 keeps it out of the live battle map.
$battle = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'), [System.Text.Encoding]::UTF8)
if ($battle.Contains('DodgeTestHazard')) {
  Write-Error "Battle scene must not include the retired dodge test hazard."
}

Write-Output 'Phase 3 file/config check passed.'