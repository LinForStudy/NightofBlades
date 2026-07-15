$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase9.ps1') | Write-Output
foreach($f in @('scripts/bosses/rift_colossus_controller.gd','scenes/bosses/rift_colossus.tscn')){if(-not(Test-Path (Join-Path $root $f))){Write-Error "Missing Phase 10 file: $f"}}
$b=[IO.File]::ReadAllText((Join-Path $root 'scenes/battle/battle_scene.tscn'));foreach($t in @('RiftColossus','23_boss')){if(-not $b.Contains($t)){Write-Error "Missing boss scene setup: $t"}}
$hud=[IO.File]::ReadAllText((Join-Path $root 'scenes/ui/battle_hud.tscn'));if(-not $hud.Contains('BossHealthBar')){Write-Error 'Missing boss HUD binding.'}
$c=[IO.File]::ReadAllText((Join-Path $root 'scripts/bosses/rift_colossus_controller.gd'));foreach($t in @('boss_phase_changed','boss_slam','boss_shockwave','boss_charge')){if(-not $c.Contains($t)){Write-Error "Missing boss behavior: $t"}}
Write-Output 'Phase 10 file/config check passed.'