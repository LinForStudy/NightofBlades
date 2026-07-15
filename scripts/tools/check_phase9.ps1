$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/tools/check_phase8.ps1') | Write-Output
foreach ($file in @('scripts/resources/ultimate_data.gd','scripts/player/ultimate_controller.gd','scripts/skills/skyfall_slash.gd','scenes/skills/skyfall_slash.tscn','resources/skills/skyfall_slash.tres','scripts/tools/check_phase9.ps1')) { if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { Write-Error "Missing Phase 9 file: $file" } }
$player=[System.IO.File]::ReadAllText((Join-Path $root 'scripts/player/player_controller.gd'),[System.Text.Encoding]::UTF8)
foreach($token in @('consume_ultimate_energy','set_ultimate_invincible','ultimate_energy_changed','_on_health_damaged','_on_health_depleted','_process_hurt')){if(-not $player.Contains($token)){Write-Error "Player missing ultimate interface: $token"}}
$scene=[System.IO.File]::ReadAllText((Join-Path $root 'scenes/player/player.tscn'),[System.Text.Encoding]::UTF8)
foreach($token in @('UltimateController','skyfall_slash.tres')){if(-not $scene.Contains($token)){Write-Error "Player scene missing ultimate: $token"}}
$hud=[System.IO.File]::ReadAllText((Join-Path $root 'scenes/ui/battle_hud.tscn'),[System.Text.Encoding]::UTF8)
foreach($token in @('UltimateSlot','UltimateEnergyBar','HealthBar','HealthText')){if(-not $hud.Contains($token)){Write-Error "BattleHUD missing ultimate HUD: $token"}}
Write-Output 'Phase 9 file/config check passed.'