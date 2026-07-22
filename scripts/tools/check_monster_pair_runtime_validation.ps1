$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

$requiredFiles = @(
    "scripts/tools/monster_pair_runtime_validation.gd",
    "scenes/tools/monster_pair_runtime_validation_runner.tscn",
    "scenes/enemies/bomber.tscn",
    "scenes/enemies/flying_eye.tscn",
    "scenes/enemies/flying_eye_projectile.tscn"
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath))) {
        throw "Missing monster pair runtime validation file: $relativePath"
    }
}

$runner = [System.IO.File]::ReadAllText((Join-Path $root "scripts/tools/monster_pair_runtime_validation.gd"), [System.Text.Encoding]::UTF8)
foreach ($token in @(
    "res://scenes/enemies/bomber.tscn",
    "res://scenes/enemies/flying_eye.tscn",
    "res://scenes/enemies/flying_eye_projectile.tscn",
    "EnemyState.WINDUP",
    "CircleShape2D",
    "EnemyState.AIM",
    "World/ProjectileRoot",
    "EnemyState.RETREAT",
    "attack_light"
)) {
    if (-not $runner.Contains($token)) {
        throw "Monster pair runtime validation missing token: $token"
    }
}

Write-Host "Bomber/FlyingEye runtime validation harness check passed."
Write-Host "Run with: godot --headless --path `"$root`" res://scenes/tools/monster_pair_runtime_validation_runner.tscn"
