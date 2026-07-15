$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$requiredFiles = @(
  'project.godot',
  'scenes/bootstrap/bootstrap.tscn',
  'scenes/menus/main_menu.tscn',
  'scenes/battle/battle_scene.tscn',
  'scripts/autoload/game_manager.gd',
  'scripts/autoload/event_bus.gd',
  'scripts/autoload/save_manager.gd',
  'scripts/autoload/audio_manager.gd',
  'scripts/autoload/object_pool_manager.gd',
  'scripts/core/bootstrap.gd',
  'scripts/ui/main_menu.gd',
  'scripts/ui/battle_scene.gd',
  'generated_assets/sprite_forge/manifests/asset_manifest.json'
)

$missing = @()
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    $missing += $file
  }
}

if ($missing.Count -gt 0) {
  Write-Error "Missing Phase 0 files: $($missing -join ', ')"
}

$project = [System.IO.File]::ReadAllText((Join-Path $root 'project.godot'), [System.Text.Encoding]::UTF8)
$requiredActions = @('move_left','move_right','move_up','move_down','jump','drop_down','attack','dodge','skill_1','skill_2','skill_3','ultimate','interact','pause','ui_confirm','ui_cancel')
$missingActions = @()
foreach ($action in $requiredActions) {
  if ($project -notmatch "(?m)^$([regex]::Escape($action))=\{") {
    $missingActions += $action
  }
}

if ($missingActions.Count -gt 0) {
  Write-Error "Missing input actions: $($missingActions -join ', ')"
}

Write-Output 'Phase 0 file/config check passed.'