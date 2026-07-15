$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase0.ps1') | Write-Output

$requiredFiles = @(
  'scenes/player/player.tscn',
  'scripts/player/player_controller.gd',
  'scripts/core/camera_follow_2d.gd'
)

$missing = @()
foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $file))) {
    $missing += $file
  }
}

if ($missing.Count -gt 0) {
  Write-Error "Missing Phase 1 files: $($missing -join ', ')"
}

$battle = [System.IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'), [System.Text.Encoding]::UTF8)
$requiredSnippets = @(
  'res://scenes/player/player.tscn',
  'res://scripts/core/camera_follow_2d.gd',
  '[node name="Ground" type="StaticBody2D"',
  '[node name="Player" parent="World/EntityRoot" instance=ExtResource("2_player")]'
)

$missingSnippets = @()
foreach ($snippet in $requiredSnippets) {
  if (-not $battle.Contains($snippet)) {
    $missingSnippets += $snippet
  }
}

if ($missingSnippets.Count -gt 0) {
  Write-Error "Battle scene is missing Phase 1 snippets: $($missingSnippets -join ', ')"
}

Write-Output 'Phase 1 file/config check passed.'