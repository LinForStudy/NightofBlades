# Night of Blades Agent Notes

- This is a Godot 4.x 2D side-scrolling pixel action Roguelite project.
- Work one phase at a time. Current implemented baseline is Phase 13 release preparation: controller input, release preflight, and device/export validation checklist. Actual exports still require a local Godot editor and templates.
- Do not add bosses, formal art assets, or generated sprite batches without a new explicit instruction.
- Existing design documents are preserved in `裂隙守夜人_docs/`; `docs/` is reserved for Godot-project-local notes and indexes.
- Use `scripts/tools/check_phase13.ps1` for the current lightweight file/config check. Godot validation should be short smoke only when explicitly needed; screenshots, recordings, complex AI/wave feel, and skill evolution feel are verified by manual playtesting.
