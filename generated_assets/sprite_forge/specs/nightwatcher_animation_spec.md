# Night Watcher Batch B Animation Specification

## Shared Contract

- Visible character height: about 64px.
- Frame canvas: 96x96px.
- Default facing: right.
- Grounded actions use a shared feet anchor at `(48, 82)` in each frame.
- Background: transparent alpha after processing; no magenta residue.
- No baked contact shadow under the feet. Godot owns contact shadows.
- Character body, sword arc, hit impact, projectile, dust, and other detached FX are separate assets.
- Weapons may exceed the body silhouette but must remain inside the owning 96x96 frame.
- A raw request contains one action only. Do not mix actions in a sheet.

## Naming

`nightwatcher_<action>_raw.png` -> `nightwatcher_<action>_transparent.png` -> `frames/nightwatcher_<action>_<zero-padded-index>.png`.

Raw requests use a horizontal strip only when Batch B explicitly requires it. Each strip has `frame_width * frame_count` by `96` source pixels. Processed output is rejected when alpha reaches a frame edge, the four feet anchors drift by more than one pixel, or visible height is outside 48-72px for grounded actions.

## Action Queue

| Action | Frames | Layout | Loop | Notes |
| --- | ---: | --- | --- | --- |
| idle | 4 | strip_1x4 | loop | subtle breathing, cape sway, sword micro-motion |
| run | 8 | strip_1x8 | loop | grounded, same scale profile |
| jump_start | 2 | strip_1x2 | once | airborne, no grounded anchor requirement after takeoff |
| jump_loop | 2 | strip_1x2 | loop | airborne |
| fall | 2 | strip_1x2 | loop | airborne |
| land | 2 | strip_1x2 | once | grounded anchor resumes |
| dodge | 6 | strip_1x6 | once | no detached afterimage |
| hurt | 3 | strip_1x3 | once | grounded anchor |
| death | 8 | strip_1x8 | once | final frame may lie down inside its own frame |
| attack_1 | 6 | strip_1x6 | once | body and close weapon only; sword arc separate |
| attack_2 | 7 | strip_1x7 | once | body and close weapon only; sword arc separate |
| attack_3 | 8 | strip_1x8 | once | body and close weapon only; sword arc separate |
| air_attack | 6 | strip_1x6 | once | airborne |
| charge_start | 5 | strip_1x5 | once | body only, no aura |
| charge_release | 7 | strip_1x7 | once | body only, release FX separate |

## Generation Gate

1. Run one minimal service health check before a formal request.
2. On a network failure, retry at most twice with increasing delay: 15 seconds, then 45 seconds.
3. Record every failure in `logs/generation_failures.json` and stop the current asset after the final failure.
4. A successful request for `nightwatcher_idle` must pass transparency, sheet size, alpha-edge, anchor, silhouette-height, and GIF preview checks before any later action is requested.