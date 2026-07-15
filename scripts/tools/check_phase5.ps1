$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase4.ps1') | Write-Output

$requiredFiles = @(
  'scripts/resources/wave_data.gd',
  'scripts/waves/wave_manager.gd',
  'resources/waves/phase5_demo_wave.tres',
  'scenes/tools/phase5_validation_runner.tscn',
  'scripts/tools/phase5_validation_controller.gd'
)
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    Write-Error "Missing Phase 5 file: $file"
  }
}

$battle = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @(
  'WaveManager',
  'phase5_demo_wave.tres',
  'SpawnPoints',
  'enemy_root_path = NodePath("../../World/EntityRoot")',
  'player_path = NodePath("../../World/EntityRoot/Player")',
  'ground_spawn_points_path = NodePath("../../World/SpawnPoints/Ground")',
  'air_spawn_points_path = NodePath("../../World/SpawnPoints/Air")'
)) {
  if (-not $battle.Contains($snippet)) {
    Write-Error "Battle scene missing Phase 5 snippet: $snippet"
  }
}

$manager = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/waves/wave_manager.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('force_spawn_once', 'ObjectPoolManager.register_pool', 'ObjectPoolManager.recycle_object', 'max_alive', '_choose_spawn_position')) {
  if (-not $manager.Contains($snippet)) {
    Write-Error "WaveManager missing Phase 5 snippet: $snippet"
  }
}

Write-Output 'Phase 5 file/config check passed.'