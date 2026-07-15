$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase1.ps1') | Write-Output

$requiredFiles = @(
  'scripts/combat/damage_context.gd',
  'scripts/combat/health_component.gd',
  'scripts/combat/hurtbox_component.gd',
  'scripts/combat/hitbox_component.gd',

  'scripts/ui/damage_number.gd',

  'scenes/ui/damage_number.tscn',
  'scenes/tools/phase2_validation_runner.tscn',
  'scripts/tools/phase2_validation_controller.gd'
)

$missing = @()
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    $missing += $file
  }
}
if ($missing.Count -gt 0) {
  Write-Error "Missing Phase 2 files: $($missing -join ', ')"
}

$battle = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'), [System.Text.Encoding]::UTF8)
$snippets = @('EffectRoot', 'EntityRoot', 'Player')
foreach ($snippet in $snippets) {
  if (-not $battle.Contains($snippet)) {
    Write-Error "Battle scene missing Phase 2 snippet: $snippet"
  }
}

Write-Output 'Phase 2 file/config check passed.'