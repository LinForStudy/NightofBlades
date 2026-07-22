# Phase 13 Release Checklist

This project has a 1280x720 landscape presentation, GL Compatibility rendering, enemy pooling, and keyboard plus standard gamepad bindings. The automated preflight is:

~~~powershell
./scripts/tools/check_phase13.ps1
~~~

The focused Battle HUD runtime smoke uses real input events and validates U/I/O cooldowns, L energy gating, low-health feedback, pause/resume, button signal bindings, and the 1280x720 dock layout:

~~~powershell
Godot --headless --path "<project root>" res://scenes/tools/battle_hud_runtime_validation_runner.tscn
~~~

## Windows

1. Install a Godot editor and export templates that exactly match the project version.
2. In Project > Export, create a Windows Desktop preset and export to artifacts/windows/NightOfBlades.exe.
3. Keep PCK embedding disabled unless distribution requirements explicitly need it; unsigned embedded executables can attract antivirus false positives.
4. Launch the exported .exe outside the project directory. Complete one full battle, return to menu, restart, and confirm settings and meta progression persist.

The editor can automate a verified release build after the preset and templates are available:

~~~powershell
Godot --headless --path "<project root>" --export-release "Windows Desktop" "artifacts/windows/NightOfBlades.exe"
~~~

## Android landscape trial

1. Install the Android SDK, JDK, and Godot Android export templates, then set their paths in the Godot editor.
2. Add an Android preset in Project > Export. Keep release keystore credentials outside version control.
3. Export a debug APK to artifacts/android/NightOfBlades-debug.apk, install it on a landscape-capable Android device, and verify the 1280x720 canvas is not cropped.
4. Validate an attached controller: left stick moves; A jumps; X attacks; Y charges; right shoulder dodges; D-pad uses skills; left shoulder uses ultimate; Start pauses.

Touch controls are intentionally not introduced in this phase; the Android target is an initial landscape/controller compatibility check rather than a touch-first release.

## Performance and acceptance run

- Run a 10-minute battle on the target Windows machine and record average FPS, lowest sustained FPS, memory usage, and any console errors.
- Repeat a short battle on Android, then background/foreground the app once and confirm no blocking error.
- Exercise pause, defeat, victory, restart, return to menu, save recovery, and all three skill slots.
- Do not ship until the exported build completes these checks without blocking errors.

The export_presets.cfg file remains ignored because local Android SDK/keystore details and per-machine export paths should not be committed without a deliberate release configuration review.