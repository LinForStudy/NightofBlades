$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
function Read-ProjectText([string]$relativePath) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    return [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
}
function Require-Text([string]$text, [string]$needle, [string]$description) {
    if (-not $text.Contains($needle)) { throw "Battle map check failed: $description" }
}

$battle = Read-ProjectText 'scenes/battle/battle_scene.tscn'
$playerScene = Read-ProjectText 'scenes/player/player.tscn'
$playerScript = Read-ProjectText 'scripts/player/player_controller.gd'

$jumpMatch = [regex]::Match($playerScript, '@export var jump_velocity := (-?\d+(?:\.\d+)?)')
$gravityMatch = [regex]::Match($playerScript, '@export var gravity := (\d+(?:\.\d+)?)')
if (-not $jumpMatch.Success -or -not $gravityMatch.Success) { throw 'Battle map check failed: player jump parameters are missing.' }
$jumpVelocity = [math]::Abs([double]$jumpMatch.Groups[1].Value)
$gravity = [double]$gravityMatch.Groups[1].Value
$jumpHeight = ($jumpVelocity * $jumpVelocity) / (2.0 * $gravity)
if ($jumpHeight -lt 60.0) { throw ("Battle map check failed: theoretical jump height {0:N1}px is below the 60px route limit." -f $jumpHeight) }

Require-Text $battle 'size = Vector2(2720, 72)' 'ground does not extend beyond the 2400px battle field.'
Require-Text $battle 'position = Vector2(1200, 684)' 'ground top is not fixed at y=648.'
Require-Text $battle 'position = Vector2(360, 648)' 'player spawn is not aligned to the ground top.'
Require-Text $battle 'collision_layer = 1' 'ground collision layer is missing.'
foreach ($position in @('position = Vector2(380, 628)', 'position = Vector2(460, 598)', 'position = Vector2(540, 568)', 'position = Vector2(670, 526)', 'position = Vector2(980, 466)')) {
    Require-Text $battle $position "route position missing: $position"
}
foreach ($nodePath in @('World/LevelRoot/PlatformLeft', 'World/LevelRoot/PlatformRight', 'World/LevelRoot/Step1', 'World/LevelRoot/Step2', 'World/LevelRoot/Step3')) {
    $nodeName = $nodePath.Split('/')[-1]
    Require-Text $battle ('[node name="{0}"' -f $nodeName) "one-way route node missing: $nodePath"
}
if (([regex]::Matches($battle, 'collision_layer = 2')).Count -lt 5) { throw 'Battle map check failed: route platforms are not all on collision layer 2.' }
if (([regex]::Matches($battle, 'one_way_collision = true')).Count -lt 5) { throw 'Battle map check failed: route platforms are not all one-way.' }
Require-Text $playerScene 'collision_mask = 3' 'player does not detect both ground and one-way platform layers.'
Require-Text $playerScript 'set_collision_mask_value(2, false)' 'drop-down does not ignore only the one-way platform layer.'
Require-Text $playerScript 'set_collision_mask_value(2, true)' 'drop-down does not restore the one-way platform layer.'

$routeTops = @(648.0, 618.0, 588.0, 558.0, 514.0, 454.0)
for ($index = 1; $index -lt $routeTops.Count; $index++) {
    $rise = $routeTops[$index - 1] - $routeTops[$index]
    if ($rise -gt 60.0) { throw "Battle map check failed: route rise $rise px exceeds 60px." }
}
$routeRanges = @(@(332.0, 428.0), @(412.0, 508.0), @(492.0, 588.0), @(540.0, 800.0), @(800.0, 1160.0))
for ($index = 1; $index -lt $routeRanges.Count; $index++) {
    if ($routeRanges[$index - 1][1] -lt $routeRanges[$index][0]) { throw "Battle map check failed: route segments $index and $($index + 1) do not connect horizontally." }
}

foreach ($spawn in @('position = Vector2(-80, 648)', 'position = Vector2(2480, 648)', 'position = Vector2(-80, 260)', 'position = Vector2(2480, 260)')) {
    Require-Text $battle $spawn "screen-edge spawn marker missing: $spawn"
}
foreach ($enemyName in @('RiftGrunt', 'Archer', 'Bomber', 'FlyingEye')) {
    if ($battle.Contains(('[node name="{0}" parent="World/EntityRoot"' -f $enemyName))) { throw "Battle map check failed: static sample enemy remains: $enemyName" }
}
Require-Text $battle 'world_top = -180.0' 'camera vertical boundary is not expanded.'
Require-Text $battle 'world_bottom = 900.0' 'camera vertical boundary is not expanded.'
Write-Host ('Battle map check passed. Theoretical jump height: {0:N1}px; maximum route rise: 60px.' -f $jumpHeight)
