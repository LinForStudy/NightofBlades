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

Require-Text $battle 'size = Vector2(8160, 72)' 'ground does not cover the continuous 7680px battle field.'
Require-Text $battle 'position = Vector2(4000, 684)' 'continuous ground top is not fixed at y=648.'
Require-Text $battle 'position = Vector2(360, 648)' 'player spawn is not aligned to the ground top.'
Require-Text $battle 'collision_layer = 1' 'ground collision layer is missing.'
foreach ($position in @('position = Vector2(380, 628)', 'position = Vector2(460, 598)', 'position = Vector2(540, 568)', 'position = Vector2(670, 526)', 'position = Vector2(980, 466)', 'position = Vector2(1360, 608)')) {
    Require-Text $battle $position "route position missing: $position"
}
foreach ($nodePath in @('World/LevelRoot/PlatformLeft', 'World/LevelRoot/PlatformRight', 'World/LevelRoot/BufferPlatform', 'World/LevelRoot/Step1', 'World/LevelRoot/Step2', 'World/LevelRoot/Step3')) {
    $nodeName = $nodePath.Split('/')[-1]
    Require-Text $battle ('[node name="{0}"' -f $nodeName) "one-way route node missing: $nodePath"
}
if (([regex]::Matches($battle, 'collision_layer = 2')).Count -lt 6) { throw 'Battle map check failed: route platforms are not all on collision layer 2.' }
if (([regex]::Matches($battle, 'one_way_collision = true')).Count -lt 6) { throw 'Battle map check failed: route platforms are not all one-way.' }
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

foreach ($spawn in @('position = Vector2(7600, 648)', 'position = Vector2(7600, 260)', 'position = Vector2(7600, 420)')) {
    Require-Text $battle $spawn "right-side spawn marker missing: $spawn"
}
foreach ($nodeName in @('Right', 'AirRightHigh', 'AirRightLow')) {
    Require-Text $battle ('[node name="{0}"' -f $nodeName) "right-side spawn marker missing: $nodeName"
}
foreach ($enemyName in @('RiftGrunt', 'Archer', 'Bomber', 'FlyingEye')) {
    if ($battle.Contains(('[node name="{0}" parent="World/EntityRoot"' -f $enemyName))) { throw "Battle map check failed: static sample enemy remains: $enemyName" }
}
Require-Text $battle 'world_top = -180.0' 'camera vertical boundary is not expanded.'
Require-Text $battle 'world_bottom = 900.0' 'camera vertical boundary is not expanded.'
Require-Text $battle 'world_right = 7680.0' 'camera does not cover the continuous battle field.'
Require-Text $battle 'world_bounds = Rect2(18, -80, 7622, 728)' 'player bounds do not cover the continuous battle field.'
foreach ($chunk in @('SkyFarChunk2', 'SkyFarChunk3', 'GroundVisualChunk2', 'GroundVisualChunk3', 'RiftLampBossGate', 'TornBannerBossGate')) { Require-Text $battle $chunk "continuous-map visual hook missing: $chunk" }
if (([regex]::Matches($battle, 'position = Vector2\(3840, 360\)')).Count -ne 5) { throw 'Battle map check failed: second 2560px parallax segment is not aligned.' }
if (([regex]::Matches($battle, 'position = Vector2\(6400, 360\)')).Count -ne 5) { throw 'Battle map check failed: third 2560px parallax segment is not aligned.' }
foreach ($groundCenter in @('position = Vector2(-2640, 0)', 'position = Vector2(80, 0)', 'position = Vector2(2800, 0)')) { Require-Text $battle $groundCenter "2720px ground segment alignment missing: $groundCenter" }
Require-Text $battle 'position = Vector2(6600, 570)' 'boss entrance is not in the final map segment.'
Require-Text $battle 'position = Vector2(7000, 648)' 'boss is not positioned beyond the unlocked entrance.'
Require-Text $battle 'final_boss_time = 0.0' 'timed boss trigger is still enabled.'

$waveManager = Read-ProjectText 'scripts/waves/wave_manager.gd'
Require-Text $waveManager 'func _right_side_spawn_candidates' 'wave spawns are not filtered to the right side.'
Require-Text $waveManager 'str(child.name).contains("Right")' 'wave spawn filter does not select only right-side markers.'
Require-Text $waveManager 'right_spawn_distance := 920.0' 'right-side spawn distance is missing.'
Require-Text $waveManager 'right_entry_distance := 620.0' 'right-side entry target distance is missing.'
Require-Text $waveManager 'minf(_player.global_position.x + right_spawn_distance, marker_position.x)' 'right-side spawn can leave the playable ground near the map edge.'
Require-Text $waveManager 'minf(_player.global_position.x + right_entry_distance, spawn_x)' 'entry target can cross the spawn boundary.'
Require-Text $waveManager '_player.global_position.x + right_spawn_distance' 'spawns do not advance with the player.'
if ($waveManager.Contains('candidates.sort_custom')) { throw 'Battle map check failed: wave spawns still select the nearest side.' }
$battleScript = Read-ProjectText 'scripts/ui/battle_scene.gd'
Require-Text $battleScript 'const BOSS_UNLOCK_LEVEL := 8' 'boss unlock level is not configured.'
Require-Text $battleScript 'const BOSS_APPROACH_DISTANCE := 1400.0' 'boss approach distance is not configured.'
Require-Text $battleScript 'func _position_boss_gate' 'boss gate is not positioned after level unlock.'
Require-Text $battleScript 'BOSS_ARENA_MAX_ENTRANCE_X' 'boss gate has no final-stage position limit.'
Require-Text $battleScript '_on_experience_changed_for_boss' 'boss unlock is not connected to experience progression.'
Require-Text $battleScript '_boss_entrance_armed' 'boss entrance is not gated by level progression.'
Require-Text $battleScript '_player_has_reached_boss_gate' 'boss encounter has no fallback when the player reaches the arena before unlocking it.'
Require-Text $battle '[connection signal="body_entered" from="World/BossEntrance" to="." method="_on_boss_entrance_body_entered"]' 'boss entrance signal is not connected.'

foreach ($nodeName in @('BridgePlatformLow', 'BridgePlatformHigh', 'BridgePlatformExit', 'RiftStep', 'RiftPlatformMid', 'RiftPlatformHigh', 'RiftPlatformExit')) {
    Require-Text $battle ('[node name="{0}" type="StaticBody2D" parent="World/LevelRoot"]' -f $nodeName) "regional platform missing: $nodeName"
}
foreach ($position in @('position = Vector2(2140, 590)', 'position = Vector2(2450, 535)', 'position = Vector2(2800, 570)', 'position = Vector2(3740, 610)', 'position = Vector2(4050, 560)', 'position = Vector2(4380, 500)', 'position = Vector2(4740, 570)')) {
    Require-Text $battle $position "regional platform position missing: $position"
}
if (([regex]::Matches($battle, 'collision_layer = 2')).Count -lt 13) { throw 'Battle map check failed: regional one-way platforms are incomplete.' }
if (([regex]::Matches($battle, 'one_way_collision = true')).Count -lt 13) { throw 'Battle map check failed: regional platforms are not all one-way.' }
foreach ($nodeName in @('BrokenBridge', 'RiftInvasion', 'ColossusCourtyard')) {
    Require-Text $battle ('[node name="{0}" type="Area2D" parent="World/RegionGates"]' -f $nodeName) "region gate missing: $nodeName"
}
foreach ($connection in @('World/RegionGates/BrokenBridge', 'World/RegionGates/RiftInvasion', 'World/RegionGates/ColossusCourtyard')) {
    Require-Text $battle $connection "region gate signal missing: $connection"
}
foreach ($landmark in @('BrokenFenceBridge', 'TornBannerBridge', 'RiftLampWest', 'RiftLampCenter', 'RiftLampEast', 'ColossusLampWest', 'ColossusBannerWest')) {
    Require-Text $battle $landmark "regional landmark missing: $landmark"
}
foreach ($tint in @('modulate = Color(0.82, 0.84, 0.98, 1)', 'modulate = Color(0.64, 0.56, 0.82, 1)', 'modulate = Color(0.68, 0.52, 0.86, 0.48)')) {
    Require-Text $battle $tint "regional background tint missing: $tint"
}
Require-Text $waveManager 'func set_stage_wave_index(stage_index: int) -> void:' 'wave manager has no region progression API.'
Require-Text $waveManager '_stage_wave_index' 'wave manager does not retain current region wave.'
Require-Text $battleScript 'const REGION_DATA' 'battle scene has no region progression data.'
Require-Text $battleScript 'func _on_region_gate_body_entered' 'region gates are not handled by battle scene.'
Require-Text $battleScript 'wave_manager.set_stage_wave_index' 'region entry does not update wave selection.'
foreach ($regionToken in @('&"village_gate"', '&"broken_bridge"', '&"rift_invasion"', '&"colossus_courtyard"')) { Require-Text $battleScript $regionToken "region data missing: $regionToken" }
$waveContracts = @(
    @{ Path = 'resources/waves/phase5_demo_wave.tres'; Token = 'enemy_weights = Array[int]([82, 10, 5, 3])' },
    @{ Path = 'resources/waves/survival_wave_02.tres'; Token = 'enemy_weights = Array[int]([42, 32, 14, 12])' },
    @{ Path = 'resources/waves/survival_wave_03.tres'; Token = 'enemy_weights = Array[int]([30, 30, 22, 18])' },
    @{ Path = 'resources/waves/survival_wave_05.tres'; Token = 'max_alive = 20' }
)
foreach ($contract in $waveContracts) { Require-Text (Read-ProjectText $contract.Path) $contract.Token "regional wave contract missing: $($contract.Path)" }
Write-Host ('Battle map check passed. Theoretical jump height: {0:N1}px; maximum route rise: 60px.' -f $jumpHeight)
