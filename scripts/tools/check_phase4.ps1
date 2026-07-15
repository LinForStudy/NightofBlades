$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase3.ps1') | Write-Output

$requiredFiles = @(
  'scripts/resources/enemy_data.gd',
  'scripts/enemies/enemy_controller.gd',
  'scripts/enemies/enemy_projectile.gd',
  'scenes/enemies/rift_grunt.tscn',
  'scenes/enemies/archer.tscn',
  'scenes/enemies/bomber.tscn',
  'scenes/enemies/flying_eye.tscn',
  'resources/enemies/rift_grunt.tres',
  'resources/enemies/archer.tres',
  'resources/enemies/bomber.tres',
  'resources/enemies/flying_eye.tres',
  'scenes/tools/phase4_validation_runner.tscn',
  'scripts/tools/phase4_validation_controller.gd'
)
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    Write-Error "Missing Phase 4 file: $file"
  }
}

$wave = [System.IO.File]::ReadAllText((Join-Path $root 'resources/waves/phase5_demo_wave.tres'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('rift_grunt.tscn', 'archer.tscn', 'bomber.tscn', 'flying_eye.tscn')) {
  if (-not $wave.Contains($snippet)) {
    Write-Error "Demo wave missing Phase 4 enemy scene: $snippet"
  }
}

$battle = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'), [System.Text.Encoding]::UTF8)
foreach ($enemyName in @('RiftGrunt', 'Archer', 'Bomber', 'FlyingEye')) {
  if ($battle.Contains(('[node name="{0}" parent="World/EntityRoot"' -f $enemyName))) {
    Write-Error "Battle scene still contains a static sample enemy: $enemyName"
  }
}

$controller = [System.IO.File]::ReadAllText((Join-Path $root 'scripts/enemies/enemy_controller.gd'), [System.Text.Encoding]::UTF8)
foreach ($snippet in @('Behavior { MELEE, ARCHER, BOMBER, FLYING }', '_process_archer', '_process_bomber', '_process_flying', '_start_melee_windup', '_execute_melee_attack', 'enemy_died')) {
  if (-not $controller.Contains($snippet)) {
    Write-Error "EnemyController missing Phase 4 snippet: $snippet"
  }
}

Write-Output 'Phase 4 file/config check passed.'