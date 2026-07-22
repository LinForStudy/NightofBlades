$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Read-RequiredFile([string]$relativePath) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing file: $relativePath" }
    return [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
}

function Require-Token([string]$text, [string]$token, [string]$context) {
    if (-not $text.Contains($token)) { throw "Missing '$token' in $context" }
}

$battleScene = Read-RequiredFile "scenes/battle/battle_scene.tscn"
$battleScript = Read-RequiredFile "scripts/ui/battle_scene.gd"
$cardScene = Read-RequiredFile "scenes/ui/upgrade_choice_card.tscn"
$cardScript = Read-RequiredFile "scripts/ui/upgrade_choice_card.gd"
$titleToken = 'text = "' + (-join @([char]0x7B49, [char]0x7EA7, [char]0x63D0, [char]0x5347, ' ', [char]0x00B7, ' ', [char]0x9009, [char]0x62E9, [char]0x4E00, [char]0x9879, [char]0x5F3A, [char]0x5316)) + '"'
$subtitleToken = 'text = "' + (-join @([char]0x4ECE, [char]0x4E09, [char]0x9879, [char]0x80FD, [char]0x529B, [char]0x4E2D, [char]0x9009, [char]0x62E9, [char]0x4E00, [char]0x9879, [char]0xFF0C, [char]0x7EE7, [char]0x7EED, [char]0x5B88, [char]0x591C)) + '"'

foreach ($token in @(
    'path="res://scenes/ui/upgrade_choice_card.tscn"',
    'World" type="Node2D" parent="."',
    'Managers" type="Node" parent="."',
    'process_mode = 1',
    '[node name="LevelUpDimmer" type="ColorRect"',
    'offset_left = -430.0',
    'offset_top = -230.0',
    'offset_right = 430.0',
    'offset_bottom = 230.0',
    $titleToken,
    $subtitleToken,
    'instance=ExtResource("43_upgrade_card")',
    '[node name="UpgradeButton1"',
    '[node name="UpgradeButton2"',
    '[node name="UpgradeButton3"'
)) {
    Require-Token $battleScene $token "scenes/battle/battle_scene.tscn"
}

foreach ($token in @(
    '[node name="UpgradeChoiceCard" type="Button"]',
    'custom_minimum_size = Vector2(244, 286)',
    'texture_filter = 1',
    'unique_name_in_owner = true',
    '[node name="CategoryLabel"',
    '[node name="ShortcutLabel"',
    '[node name="UpgradeIcon"',
    '[node name="NameLabel"',
    '[node name="LevelLabel"',
    '[node name="StatChangeLabel"',
    '[node name="DescriptionLabel"'
)) {
    Require-Token $cardScene $token "scenes/ui/upgrade_choice_card.tscn"
}

foreach ($forbidden in @('ShaderMaterial', 'corner_radius_', 'texture_filter = 2')) {
    if ($cardScene.Contains($forbidden) -or $battleScene.Contains($forbidden)) {
        throw "Upgrade choice UI violates pixel/static rendering constraint: $forbidden"
    }
}

foreach ($token in @(
    'func present_upgrade',
    'upgrade is SkillUpgradeData',
    'skill_id',
    'effect_key',
    'FIRE_SLASH_ICON',
    'LIGHTNING_DASH_ICON',
    'BLADE_STORM_ICON',
    'RELIC_ICON',
    'ULTIMATE_ICON',
    'CanvasItem.TEXTURE_FILTER_NEAREST'
)) {
    Require-Token $cardScript $token "scripts/ui/upgrade_choice_card.gd"
}

foreach ($forbidden in @('Input.', 'choose_upgrade(', 'apply_upgrade(', 'get_tree().paused')) {
    if ($cardScript.Contains($forbidden)) {
        throw "UpgradeChoiceCard must remain display-only; found forbidden token: $forbidden"
    }
}

foreach ($token in @(
    '@onready var level_up_dimmer: ColorRect = %LevelUpDimmer',
    '@onready var upgrade_subtitle: Label = %UpgradeSubtitle',
    'KEY_1',
    'KEY_2',
    'KEY_3',
    'upgrade_buttons[index].pressed.connect(_on_upgrade_button_pressed.bind(index))',
    'experience_manager.level_up_choices_ready.connect(_on_level_up_choices_ready)',
    'experience_manager.level_up_finished.connect(_on_level_up_finished)',
    'button.call("present_upgrade"',
    '_get_upgrade_stack(upgrade)',
    '_get_upgrade_max(upgrade)',
    'experience_manager.choose_upgrade(index)'
)) {
    Require-Token $battleScript $token "scripts/ui/battle_scene.gd"
}

foreach ($legacy in @(
    'button.text = "[%s] %s\n%s\n%s/%s"',
    'text = "Upgrade 1"',
    'text = "Upgrade 2"',
    'text = "Upgrade 3"',
    'Skill evolution upgrade.'
)) {
    if ($battleScene.Contains($legacy) -or $battleScript.Contains($legacy) -or $cardScene.Contains($legacy) -or $cardScript.Contains($legacy)) {
        throw "Legacy or unsupported upgrade UI content remains: $legacy"
    }
}

$englishPlaceholder = Get-ChildItem -LiteralPath (Join-Path $root 'resources\skill_upgrades') -Filter '*.tres' -File |
    Where-Object { [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8).Contains('Skill evolution upgrade.') }
if ($englishPlaceholder) { throw "English skill-upgrade placeholder remains in resources." }

Write-Host "Upgrade choice UI static check passed."
