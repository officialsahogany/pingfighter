# Character Select Preview VFX Handoff

This is the implementation handoff for upgrading the character select
LivePreview background behind the upper-body / full-frame Live2D art. It follows
`docs/skill_vfx_workflow.md` and the existing `Control`-local UI coordinate
rules.

## Goal & Constraints

Goal: make the character select preview read like a living cyber / character
identity stage instead of a mostly immediate-draw backdrop, while preserving
face, body silhouette, weapon, and UI readability.

Hard constraints:

- The character art remains the visual priority. Background light must not cover
  the face, weapon, hands, or readable torso silhouette.
- The VFX is a `LivePreview`-local UI effect, not a battle playfield effect.
- Use the owning `Control` local rect and stay inside `LivePreview` clipping.
- Keep the current card / info / button layout untouched.
- Do not apply battle `game_offset` / `render_scale` positioning.
- Avoid a one-off inline shader pile. Use a reusable UI shader family or an
  existing shared family when it fits cleanly.

## Owner & Coordinate Space

Primary owner:

- `godot/scripts/ui/character_live_preview.gd`

Preferred new module:

- `godot/scripts/ui/character_select_preview_vfx_host.gd`

Integration model:

- `character_live_preview.gd` creates or owns the VFX host as a child of the
  `LivePreview` Control.
- The VFX host is sized to `Rect2(Vector2.ZERO, size)` and uses local
  coordinates.
- Because the character art is also drawn by the parent `LivePreview` `_draw()`,
  backdrop texture pieces that must stay behind the character are drawn once in
  `character_live_preview.gd::_draw_preview_vfx_texture_backdrop()`. Do not add
  duplicate host `TextureRect` layers for the same backplate / mandala / slit /
  floor-ring textures unless the parent draw order is refactored too.
- `LivePreview` already has `clip_contents = true` in
  `godot/scenes/character_select.tscn`, so all new backdrop layers should remain
  clipped to that panel.
- `character_select_screen.gd` should stay orchestration-only: selected
  character, hover state, and confirm phase can be forwarded to `LivePreview`,
  but persistent art/background logic should not be added there.

Current relevant paths:

- `godot/scenes/character_select.tscn`
- `godot/scripts/ui/character_select_screen.gd`
- `godot/scripts/ui/character_live_preview.gd`
- `godot/scripts/ui/character_select_prewarm.gd`
- `godot/scripts/ui/character_select_confirm_flash_overlay.gd`
- `godot/scripts/ui/character_select_data.gd`

## Layer Recipe

Use a 4-layer modular VFX stack plus one reactive flash path. The layer count is
intentional because this screen shows only one large preview at a time.

| Layer | Role | Asset | Blend | Motion |
|---|---|---|---|---|
| Deep backplate | depth and stage mood | shared hex / data grid PNG | MIX | slow parallax drift, low alpha breath |
| Identity mandala | character motif behind art | per-character circuit / mandala PNG | ADD | slow rotation / UV drift / chroma |
| Particle motes | life and density | shared 64x64 mote PNG | ADD | `GPUParticles2D`, slow upward float |
| Floor ring / light slit | rhythm and highlight | shared ring + slit PNGs | ADD | hover pulse, confirm scale burst |
| Reactive flash | selection impact | shader or gradient layer | ADD | short confirm envelope, shared with confirm phase |

Draw order must keep the character art above backplate / mandala / motes and
below foreground frame / nameplate. The floor ring can visually sit around the
feet but must not obscure the lower body.

Current implementation split:

- Parent direct draw owns the large behind-character texture pieces, procedural
  data motes, and scan sweep.
- `character_select_preview_vfx_host.gd` owns persistent UI-host lifecycle,
  clipped particle / confirm envelopes, palette state, and shared asset path /
  material prewarm helpers. It intentionally reports zero backdrop texture
  layers to avoid double-rendering the same art.

## Per-Character Palette & Motif

Use the current `character_select_data.gd` IDs. Colors should be initialized
from the existing `card_color` / `glow_color` values where possible, then tuned
through VFX presets.

| Character ID | Runtime | Display role | Primary | Accent | Motif |
|---|---|---|---|---|---|
| `ufo_player` | `smasher` | Mika / Smasher | cyan | white | hex grid, round disk, paddle arcs |
| `soldier` | `soldier` | Rena / Commando | olive green | brass gold | tactical HUD, sight lines, ammo ticks |
| `viper` | `viper` | Serin / Viper | violet | red-pink | slash trails, cracked mirror shards |
| `blacksmith` | `blacksmith` | Kohaku / Baltor | forge orange | warm gold | hammer impact rings, anvil engrave lines |
| `optimus` | `optimus` | Io / Optimus | cool blue-violet | gold-white | clock dial, gear teeth, time ticks |

The common structure should stay consistent across characters; the motif PNG and
shader preset provide identity.

## Palette / Material Helper Plan

Current file:

- `godot/scripts/ui/character_select_vfx_material.gd`

Policy:

- Provide reusable palette values for `ufo_player`, `soldier`, `viper`,
  `blacksmith`, and `optimus`.
- Provide the additive `CanvasItemMaterial` used by the host-owned
  `GPUParticles2D` and confirm tint.
- Do not prewarm or keep shader code without a live consumer. The old
  host-owned TextureRect shader path was removed when parent `_draw()` became
  the single backdrop texture path.
- If a future refactor moves backdrop texture pieces out of parent `_draw()`,
  add a new shader/material consumer and focused tests at the same time.
- Long-term cleanup target: the existing inline shaders in
  `character_select_confirm_flash_overlay.gd` can be moved into a shared UI
  shader family when there is an actual consumer.

## Lifecycle Contract

VFX host behavior:

- Build runtime child layers once when `LivePreview` is ready or on first
  character assignment. These host-owned layers must not duplicate the
  parent-drawn backdrop textures.
- Default to `set_process(false)` when no animated layer needs host-owned
  timing. If the host owns particle or shader time, enable process only while
  visible and disable it in cleanup.
- Expose narrow sync methods such as:
  - `set_character(character: Dictionary)`;
  - `set_hover_amount(amount: float)`;
  - `play_confirm(config: Dictionary = {})`;
  - `set_active(active: bool)`;
  - `clear_runtime_state()`.
- On character switch, update palette / particle state immediately, let
  `character_live_preview.gd` update the direct-drawn motif texture, stop any
  stale confirm burst, and avoid lingering old-character particles.
- On `_exit_tree()` / `clear_runtime_state()`, set particle `emitting = false`,
  stop tweens, null loaded material references where needed, hide the host, and
  queue-free runtime-only child nodes if they are not scene-owned.

Screen owner responsibilities:

- `character_select_screen.gd` may pass hover and confirm state to `preview` if
  `LivePreview` exposes methods, but it should not own the persistent visual
  layers.
- Existing confirm flash overlay remains the fullscreen / transition flash
  owner. The preview VFX confirm burst should sync with it, not replace it.

## Prewarm Additions

Update `character_select_prewarm.gd` so character-select loading can include:

- shared deep backplate texture;
- shared particle mote texture;
- shared floor ring texture;
- shared light slit texture;
- per-character mandala textures;
- `character_select_vfx_material.gd` palette / additive material helper;
- any runtime particle texture dependencies.

Do not depend only on first visible `LivePreview` setup for heavy work. The
first character-select frame should not create a large texture / shader hitch.

## Texture Piece Specs

Proposed asset root:

- `godot/assets/ui/character_select_vfx/`

Suggested files:

| File | Size | Purpose | Alpha / margin rule |
|---|---:|---|---|
| `character_select_deep_backplate.png` | 1024x1024 | dark gradient plus large hex / data grid | radial mask, transparent corners |
| `character_select_particle_mote.png` | 64x64 | soft data mote / glow dot | at least 4 px transparent edge |
| `character_select_floor_ring.png` | 1024x256 | perspective floor energy ring | enough top / bottom empty margin |
| `character_select_light_slit.png` | 512x1024 | vertical / diagonal light slit | side margins, no baked box |
| `character_select_mandala_ufo_player.png` | 1024x1024 | Smasher identity circuit | radial mask, center low opacity |
| `character_select_mandala_soldier.png` | 1024x1024 | Commando tactical motif | radial mask, center low opacity |
| `character_select_mandala_viper.png` | 1024x1024 | Viper slash / shard motif | radial mask, center low opacity |
| `character_select_mandala_blacksmith.png` | 1024x1024 | Baltor forge / anvil motif | radial mask, center low opacity |
| `character_select_mandala_optimus.png` | 1024x1024 | Optimus clock / gear motif | radial mask, center low opacity |

Generation note: these are still PNG pieces, not animated sprite sheets. They
can be made with Codex imagegen or the current image pipeline. Verify alpha
edges before integration.

## Reactive State Definitions

| State | Trigger | Expected VFX response |
|---|---|---|
| Idle | selected character, no preview hover | baseline backplate / mandala, low emission motes, slow ring breath |
| Preview hover | mouse over `LivePreview` | mandala intensity 1.25x, particles 1.5x, ring brightness 1.4x |
| Card hover | mouse over card but not preview | optional low-intensity preset preview, no heavy burst |
| Pre-confirm | confirm intro begins | ring scale 1.10-1.15, brief motif focus pulse |
| Confirm | existing confirm flash starts | preview burst, particles one-shot, optional 0.3 s white / accent impulse |

Confirm timing should use the same phase clock or event trigger as the existing
confirm intro / flash path. Do not create an unsynchronized local-only confirm
timer that can outlive scene transition.

## Existing Module Touchpoints

`character_live_preview.gd`:

- Owns the preview-local backdrop, art draw, scanlines, nameplate, and interaction
  overlay.
- Owns the single draw path for backplate / mandala / light-slit / floor-ring
  textures through `_draw_preview_vfx_texture_backdrop()`, because these pieces
  must sit between the base panel background and the character art.
- Creates the VFX host for clipped particle / confirm lifecycle, but the host
  should not duplicate the same backdrop texture pieces.

`character_select_screen.gd`:

- Already resolves `LivePreview` in `_ready()`.
- Already syncs selected character through `_sync_preview()`.
- Already calls `preview.set_interaction_state()` for preview hover.
- Should pass confirm events only through a narrow preview method if needed.

`character_select_confirm_flash_overlay.gd`:

- Owns the fullscreen confirm exit flash.
- Keep it separate for the first pass; optionally migrate its inline shaders to
  the new UI shader family later.

`character_select_prewarm.gd`:

- Add VFX texture and material jobs here.
- Keep duplicate path filtering.

## Test Plan

Focused smoke tests:

- `character_select_preview_vfx_host_lifecycle_smoke.gd`
  - create `CharacterLivePreview`;
  - set each character ID;
  - hover on/off;
  - call `clear_runtime_state()`;
  - verify host hidden or inactive and particles stopped.
- `character_select_preview_vfx_host_clip_smoke.gd`
  - verify host rect equals `LivePreview` local rect;
  - verify host confirm / particle state stays inside the preview Control;
  - verify the host does not duplicate parent-drawn backdrop texture layers;
  - verify no battle `game_offset` / `render_scale` formula is used.
- Update existing character select smoke coverage if screen-level hover /
  confirm methods are added.

Baseline verification after code changes:

- From `godot/`, run `.\tools\run_headless_load_check.ps1`.
- From `godot/`, run `.\tools\run_warning_scan.ps1` after `.gd` edits.
- Run focused smoke tests through the repo wrapper when added.

Live visual check:

- Windowed 1280x720.
- Hover `ufo_player`, `soldier`, `viper`, `blacksmith`, and `optimus`.
- Confirm once.
- Check alpha edges, clipped bounds, character face readability, floor ring
  alignment, and no stale particles after leaving the screen.

## Acceptance Criteria

- New VFX appears only inside the `LivePreview` panel.
- Character art remains readable in idle, hover, and confirm states.
- Character identity changes by preset / motif without changing the whole
  implementation per character.
- Shader code is reusable through a family / preset structure.
- Particles and tweens stop on character switch, back navigation, confirm scene
  transition, and `_exit_tree()`.
- Prewarm includes the new assets and avoids first-entry hitch from resource
  creation.
- Tests cover lifecycle and coordinate / clip invariants.
- Final handoff lists asset paths, shader preset names, particle layers, cleanup
  paths, and commands run.
