# Odin's Eye Dark Swamp Slice Plan

> Status: design contract for the next Godot port slice.
> Target: `godot/` only. Python files are reference anchors, not edit targets.
> Read with `docs/odins_eye_port_plan.md`, `docs/item_runtime_checklist.md`,
> `docs/godot_port_checklist.md`, and `docs/skill_vfx_workflow.md`.

## Goal

Port Odin's Eye post-revival transformed active skill, **어둠의 늪**, into the
Godot runtime without folding the whole remaining Odin backlog into one patch.

The current Godot Odin port has the revival / penalty core, death cinematic
state, and skill-lock plumbing, but it does not yet own Dark Swamp state,
input, spike hazards, HUD, or audio. This document splits that missing feature
into shippable slices.

## Python Parity Anchors

- State and constants: `legendary_items.py:6791-6814`
- Enable after revival finalize: `legendary_items.py:10203`,
  `pingfighter.py:188915`
- Use gate and activation: `legendary_items.py:10216-10273`,
  `pingfighter.py:186555-186568`
- Update and spike spawn: `legendary_items.py:10277-10422`
- Spike draw reference: `legendary_items.py:10518-10833`
- Fragment update / draw reference: `legendary_items.py:10835-10878`
- Ball and boss collisions: `legendary_items.py:10955-11087`,
  `pingfighter.py:189092-189142`
- Skill orb / tooltip reference: `legendary_items.py:11174-11220`,
  `pingfighter.py:12495-12600`, `pingfighter.py:12888-12940`

## Owner Boundary

Recommended new owner:

- `godot/scripts/items/odins_eye_dark_swamp_state.gd`
  - Owns enabled flag, cooldown, activation, spike list, phase timers,
    fragments, collision helpers, and `has_runtime_update_work()`.
  - Exposes pure-ish helpers that can be smoked without the full battle scene.
- `godot/scripts/items/mythic_item_odins_eye_runtime.gd`
  - Owns lifecycle wiring to the broader Odin state.
  - Enables Dark Swamp only on the revival-finalize edge.
  - Reads input, consumes gauge, forwards update and collision hooks.
  - Clears active hazards on round / score / reset boundaries.
- `godot/scripts/items/mythic_item_runtime.gd`
  - Adds thin public methods only when another owner needs a stable facade.
- `godot/scripts/items/mythic_item_update_gate.gd`
  - Includes Dark Swamp cooldown, active spikes, particles, and fragments in
    the mythic update work gate.
- `godot/scripts/items/mythic_item_owner_syncer.gd` plus
  `BattleSceneState.DEFAULT_VALUES`
  - Syncs renderer-facing fields only after the state schema is declared.
- `godot/scripts/hud/odins_eye_skill_pillar_renderer.gd`
  - Later HUD slice. Mirrors the Horn Strawberry override pattern in
    `stage1_pillar_ui_renderer.gd`, but uses Odin-specific metadata.

Avoid growing `scenes/main.gd` or `odins_eye_state.gd` into a spike monolith.
`odins_eye_state.gd` should remain the revival / penalty / cinematic state
owner, with Dark Swamp split into its own item sub-state.

## Slice 3A: Runtime Core

Scope:

- Add `odins_eye_dark_swamp_state.gd`.
- Enable the skill after revival finalize, not when revival starts.
- Add activation gating and cooldown / spike spawning.
- Do not ship ball or boss collision yet except as inert collision helper data.
- Do not ship final VFX. A deterministic debug-friendly state list is enough.

Parity constants:

| Field | Value |
|---|---:|
| gauge cost | 100 |
| cooldown | 120 frames |
| max spikes | 12 |
| spike spawn interval | 8 frames |
| wave progress step | 0.025 / frame |
| rise / hold / fall | 10 / 35 / 15 frames |
| dissolve | 15 frames |
| spike width | 6-10 |
| spike height | 38-63 |
| sub crystals | 2-4 |
| x spread | alternating 25px lanes plus -10..10 jitter |
| x clamp | 100..660 in legacy game coords |

Activation contract:

- Can activate only when Odin is equipped, transformed, Dark Swamp enabled,
  not reviving, not in death animation, not already active, cooldown is zero,
  and current special gauge is at least 100.
- Consumes exactly 100 gauge once on the activation edge.
- Starts path from player `(x, y - 30)` to boss `(x, y + 30)`.
- Starts cooldown immediately at 120 frames.
- Spawns the first spike through the same interval path as later spikes unless
  a visible feel pass intentionally changes the first-spike timing.

Input warning:

- Python uses left mouse click while transformed.
- The Godot transformed skill must not accidentally read the character-skill
  lock proxy if that proxy clears mouse / action input. Read the raw post-modal
  input edge, or add an explicit transformed-item click edge to the input
  snapshot before the character-skill proxy strips normal skill controls.
- Do not route Dark Swamp through the normal active-item slot controller.

Lifecycle:

- `reset_round()` / serve-boundary cleanup must remove active spikes,
  fragments, smoke, and sparkle state so no hazard survives into the next
  rally.
- `clear_after_victory()`, `clear_after_death()`, `on_stage_advance()`, and
  full reset must also disable Dark Swamp and clear cooldown.
- `dark_swamp_enabled` follows Odin's transformed penalty form. It should not
  be independently true after the Odin penalty has been cleared.

3A smoke:

- `odins_eye_dark_swamp_activation_smoke.gd`
  - Before revival finalize: activation fails and gauge is unchanged.
  - After revival finalize: activation succeeds, gauge drops by 100, cooldown
    becomes 120, and the path endpoints match player/boss inputs.
  - Insufficient gauge, cooldown, death animation, and already-active states
    all fail without consuming gauge.
  - Over enough update frames, exactly 12 spikes are spawned, phase timers
    advance, and `has_runtime_update_work()` stays true until cooldown and
    transient spike state are gone.
  - Reverse check: disabling the finalize-only enable or gauge gate must turn
    at least one case RED.

## Slice 3B: Gameplay Collision

Scope:

- Wire spike collision into the Godot ball / boss update order.
- Preserve px/frame velocity semantics.
- Route boss stun / knockback through the current shared status or boss motion
  owner instead of adding ad-hoc globals.

Ball parity:

- Ignore spikes already hit by the ball.
- Only `rising` and `hold` phases collide.
- Height threshold: 10px.
- Collision rect: `x - width - 5`, `y - height`, `width * 2 + 10`, `height`.
- If current speed is greater than 3:
  - Minimum speed before boost is 10.
  - Hit offset = `(ball_center_x - spike_x) / (width + 2.5)`, clamped -1..1.
  - Output angle is within +/-45 degrees.
  - Speed boost is random 1.4..1.7.
  - New vector points upward toward the boss.
- If current speed is 3 or lower:
  - Fallback impulse is x = +/-5 by side, y = -12.
- The spike dissolves and spawns fragments after one hit.
- Hit audio parity uses `odinattack.wav` volume 0.6.

Boss parity:

- Ignore spikes already hit by the boss.
- Only `rising` and `hold` phases collide.
- Height threshold: 20px.
- Tip rect: `x - width - 3`, `y - height - 5`, `width * 2 + 6`, `15`.
- Knockback direction is away from the spike.
- Knockback power is 25, legacy knockback timer is 24 frames, stun is 60 frames.
- The spike dissolves and spawns fragments after one hit.
- Hit audio parity uses `odinattack.wav` volume 0.7.

Collision integration checks:

- Decide whether collision is called from the mythic item updater, the ball
  update driver, or a shared active-item collision pass. Record the ordering
  next to the callsite.
- If the collision can modify boss movement after boss AI has already moved,
  publish the status/knockback payload to the boss owner so dash and knockback
  paths do not cross through it in the same frame.
- Do not use physics-side direct `queue_redraw()`. Route visible refresh through
  the battle redraw request path if needed.

3B smoke:

- `odins_eye_dark_swamp_collision_smoke.gd`
  - A fast ball overlapping a rising spike receives an upward boosted vector,
    the spike dissolves, and the same spike cannot hit twice.
  - A slow ball overlapping a rising spike receives the fallback impulse.
  - A boss tip overlap applies 60 frames of stun plus 25-power knockback through
    the chosen shared owner, dissolves the spike, and cannot double-hit.
  - Reverse checks should fail if phase gates or one-hit flags are removed.

## Slice 3C: Presentation, HUD, Audio

Scope:

- Ship the visible Godot-native version after 3A and 3B behavior is sealed.
- Add the transformed Odin skill orb, tooltip copy, and effect preview.
- Add audio through the Godot audio owner.

HUD contract:

- Renderer shows one transformed skill orb: `어둠의 늪`.
- It displays cost 100, cooldown 2.0s, ready/active/cooldown state, and a
  filled/disabled visual tied to current gauge.
- Tooltip path must not be empty: add a Dark Swamp preview branch to the shared
  skill effect preview renderer or a dedicated Odin preview renderer.
- Renderer override should follow the Horn Strawberry pattern, but must not
  overwrite normal character skill HUD outside the Odin transformed state.

Audio contract:

- Existing files found in the repo: `sounds/odinattack.wav`,
  `sounds/odinshadow.wav`, `sounds/odinchange.wav`, `sounds/odinspirit.wav`,
  `sounds/odindeath.wav`.
- Python references `sounds/lurker_attack.wav`, but this file was not found in
  the current repo scan. Before implementation, either restore/import it or
  document a deliberate substitute cue.
- Spike spawn uses `odinspirit.wav` volume 0.5 in Python.
- Ball and boss hits use `odinattack.wav` volumes 0.6 and 0.7.
- Any looped or synced audio must be added to the gameplay-loop cleanup owner.
  The current known Odin cues are one-shots unless the presentation slice
  intentionally introduces a loop.

VFX contract:

- Use Python draw code as timing and silhouette reference, not as final Godot
  architecture.
- Default to modular VFX layering: spike texture pieces or sprites, shader
  tint/dissolve, particle smoke/sparkle/fragments, and a single authoritative
  phase clock.
- If a direct `canvas.draw_*()` spike fallback ships, document why the effect is
  intentionally cheap and guard animated polygons against degenerate geometry.
- Detached hosts must be explicitly cleaned up on score, serve wait, round
  restart, death, victory, stage advance, and main menu reset.
- No runtime image slicing, alpha scans, or texture creation in `_draw()` or
  the first visible battle frame.

3C verification:

- Focused HUD smoke or renderer smoke for ready, insufficient gauge, cooldown,
  and transformed/not-transformed visibility.
- Tooltip preview smoke or visual check proving the preview panel is populated
  and clipped.
- Live scaled/windowed visual check for playfield alignment and no pillar /
  letterbox leaks.
- `run_headless_load_check.ps1` and `run_warning_scan.ps1` after `.gd` edits.

## Deferred After Core Dark Swamp

- Legacy Nemesis Ocean interceptor / missile collision at
  `pingfighter.py:189143-189197`. Godot stage mapping differs: current Godot
  code stage 5 is Hongryun, not legacy Nemesis. Do not port this blindly.
- Legacy Stage 7 tetromino collision at `pingfighter.py:189198-189225`. It
  belongs with the Stage 7 owner contract.
- Full Odin transformed sprite work.
- Larger death / revival cinematic renderer polish beyond the existing state
  machine.
- Immediate-fire revival restart divergence.

## Sign-off Bar Per Slice

- Focused smoke passes.
- Reverse verification has been performed for the critical gate touched by the
  slice.
- No Godot warning scan regressions after `.gd` edits.
- Headless load check passes after `.gd`, scene, asset, or import changes.
- Remaining parity gaps are named as deferred, not implied complete.
