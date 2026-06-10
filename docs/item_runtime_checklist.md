# Item Runtime Integration Checklist

Current development target: Godot **디스크하츠 - 링피아**.

The original Python/Pygame PingFighter item system is frozen. Use the
Python-side sections in this checklist as legacy porting references only:
they are useful for behavior, timing, balance, acquisition routes, text, and
parity audits, but they are not default edit targets. New item implementation,
bug fixes, UI, VFX, audio, save/load, and runtime wiring belong under
`godot/` unless the user explicitly asks for a legacy Python source edit.

Single source of truth for the code locations and QA surfaces that must be
touched when adding, removing, porting, or modifying an item (active /
passive / legendary / mythic). Godot-specific sections describe current
implementation requirements; Python-specific sections describe legacy
reference paths to inspect during a port.

Three-way role split:

| Document | Owns |
|---|---|
| `.claude/skills/item-generation/` | Item icon and equip visual generation (prompts, mood, QA) |
| **this file** | Every Godot runtime location and legacy reference path that must be audited to make the item work |
| `CLAUDE.md` | Thin routing rule pointing at both of the above |

Runtime integration does not belong in asset-generation skills. Item runtime
lives here, with `AGENTS.md` providing the top-level Godot-first routing.

If this file and the item-generation skill conflict, **this file wins
for runtime behavior** (registration, routing, reset, rolls, polish,
enhancement). The skill wins for visual asset decisions.

## How to use this file without reviving Python development

For current 디스크하츠 - 링피아 work, follow this route:

1. Start at Section 0.
2. Use the Godot integration section for the item family:
   - active item: Section 1.7
   - passive item: Sections 2.3-2.7 plus the current Godot owner module
   - legendary / mythic item: Sections 3.5-3.8 plus the current Godot owner
   - unknown-item / acquisition flow: Section 4
   - reset lifecycle: Section 5
   - transformation / revival item: Section 7
   - absorb / consume item: Section 7B
   - verification: Section 8
3. Read legacy Python sections only to recover parity behavior, acquisition
   routes, names, timing, or old failure patterns. They are not edit targets.

Legacy Python reference sections in this file:

| Area | Reference-only sections |
|---|---|
| Active items | 1.1-1.6 |
| Passive items | 2.1-2.2, 2.8-2.9 |
| Legendary / mythic items | 3.1-3.4 |
| Hardcoded old integration map | 6 |
| Transformation finalize callsites | 7.4 |

---

## 0. Pre-flight before touching code

Implementation trap to keep in mind for the whole document:
- `owned / obtained` and `equipped / active` are different concepts.
  A reset / respawn / one-time-gacha gate must read an ownership signal,
  not the current equipped state.

Before adding ANY new item, confirm:

- [ ] Item type decided (active / passive / legendary / mythic)
- [ ] Item icon asset exists on disk (see item-generation skill §8)
- [ ] If passive and visually attaches to character: equip visual asset
      exists AND attach point known
- [ ] If legendary / mythic: theme background hue picked, signature
      particle theme picked, polish and enhancement applicability
      decided
- [ ] Item name in snake_case, consistent across every list below
- [ ] If the item is sellable, its economy tier is chosen:
      inventory `sell_price` and shop `base_price` benchmarked against
      comparable items

Every checklist in this document assumes these are already done.

### 0.1. Default runtime assumptions for new item work

Unless the user explicitly overrides them, use these defaults:

- Item code name: `snake_case`
- Unlock state: enabled by default in `unlocked_items`
- Duplicate policy:
  ordinary active / passive items do NOT allow duplicate farming
- Duplicate policy must be verified per acquisition path. Field spawn,
  Pandora / treasure routes, shop / crane, and stage-clear gacha can
  intentionally diverge.
- Passive acquisition behavior:
  if the matching body-part slot is empty, auto-equip on acquire
- Item scope:
  a "new item" request includes runtime registration across normal
  acquisition paths, UI, developer mode, reset flow, and verification
- Visual scope:
  unless the user explicitly says runtime-only, create the matching
  icon / equip visual as part of the task
- "Skill cooldown reduction":
  default to player skill-system cooldowns only; do NOT include
  active-item cooldowns unless explicitly requested
- "Skill cooldown reduction" means the cooldowns of the **left-side
  5-orb player skill system** for **all five playable characters**
  (Smasher, Viper, Soldier / Commando, Blacksmith / Baltor, Optimus).
- Include both default skills and perk-unlocked skills in that system.
- Do **not** treat active-item cooldowns as part of this category
  unless the user explicitly requests item / active cooldown reduction.
- Verify the reduction is wired into every character cooldown path,
  including any character that uses a different cooldown structure
  (for example, Optimus-style until-timestamp assignment).
- Time-bound item effects that need player-facing duration feedback
  should use the shipped right-bottom horizontal timer-gauge behavior:
  the bottom-most active timer is stack index `0` on the bottom baseline,
  and additional active timers stack upward only when lower timer bars
  are actually active. Do not hardcode a nonzero stack index for a timer
  that can appear alone.

Do not stop for clarification on the items above unless the user's
request directly conflicts with one of these defaults.

### 0.1A. Godot item VFX remaster policy

For Godot ports, visible item effects follow the same remaster default as
character skills. This applies to active items, passive items, legendary
items, mythic items, and any item-tree / downtown effect that changes item
presentation.

Python / Pygame item code is the timing and gameplay reference. Preserve
pickup, equip, use, windup, deploy, impact, proc, absorb, duration,
expire, cancel, reset, cooldown, audio, hitstop, shake, and cleanup
timing. Do not treat old procedural `draw_*` calls or per-frame particle
arrays as the final Godot VFX architecture unless the effect is
intentionally tiny or only a fallback accent.

Default Godot item VFX stack:

- [ ] Substantial item effects use **modular VFX layering** by default:
      texture fragments + runtime composition + shader uniform presets.
      Record the layer stack, z-order, blend mode, owning phase, fallback,
      and normal / boosted uniform values near the item FX host or owner.
- [ ] Texture pieces or sprite sheets define the readable identity:
      thrown item trail, impact stamp, shield rim, aura core, field mask,
      mythic motif, absorb strand, debris, smoke, or proc iconography.
- [ ] `ShaderMaterial` drives living motion: glow, dissolve, refraction,
      UV flow, color ramp, rim pulse, distortion, noise, or scan effects.
- [ ] Prefer reusable shader families with per-item uniform tuning over
      duplicate one-off shaders or extra near-identical frames. Common
      lanes include `elapsed`, `alpha` / `intensity`, flow speed,
      pulse speed, distortion strength, `lateral_strength` / tangent-side
      displacement for writhing lightning, cracks, vines, ropes, streams,
      and branching energy, jitter strength, chromatic strength, breath
      amplitude, color ramp / tint colors, and rarity / mythic / boosted
      multipliers.
- [ ] `GPUParticles2D` provides density and variation: sparks, motes,
      embers, dust, debris, smoke, energy flecks, absorption streams, or
      persistent field particles.
- [ ] `Tween` handles one-shot scale / alpha / snap / pulse timing.
      Use `AnimationPlayer` when the effect has repeatable multi-node or
      hand-keyed choreography.
- [ ] Shader parameters, particle emission, sprite frames, tweens /
      animations, fallback visibility, audio, hitstop, shake, HUD timer,
      and gameplay state must read one authoritative item phase clock.
- [ ] Keep direct `canvas.draw_*()` only for cheap fallback shapes, debug
      overlays, deterministic geometry helpers, or temporary parity
      scaffolding. If direct-draw is the final shipped item effect,
      document why the full remaster stack is intentionally unnecessary.

Item-specific remaster checks:

- [ ] Active item: use / windup / deploy / projectile / field / impact /
      expire visuals appear before the active slot consumes invisibly.
- [ ] Passive item: equip-gated visual effects turn on only while the item
      is equipped and turn off immediately on unequip, death, reset, or
      main-menu return.
- [ ] Legendary / mythic item: acquisition reveal, equipment / slot icon,
      passive theme particles, proc effects, and any large showcase
      presentation share the same motif and do not rely on the icon PNG
      pretending to be runtime particles.
- [ ] Absorb / neutralize item: the remastered absorb visual kills or
      hides the source runtime effect first, then plays the item cinematic;
      it must not layer prettily on top of a still-active hazard.
- [ ] Detached Godot item FX hosts (`Node2D`, `Sprite2D`, shader quad,
      `ColorRect`, `GPUParticles2D`) use explicit viewport-space layout:
      `game_offset + (playfield_pos + shake_offset) * render_scale`, with
      sizes multiplied by `render_scale`.
- [ ] Playfield-space item VFX that are drawn directly through
      `canvas.draw_*()` still need geometry bounds checks. The transformed
      playfield pass does not automatically clip oversized circles,
      ellipses, shockwaves, trails, particles, or sprite quads to
      `0..FIELD_WIDTH` / `0..FIELD_HEIGHT`; anything outside those bounds can
      visibly spill onto the pillar background. Clamp or otherwise constrain
      the final visible effect center using the effect's real visual
      footprint, not only the projectile / gameplay collision point.
- [ ] Detached Godot item FX hosts have an owner-level round / cancel /
      reset cleanup path. Do not rely on the item draw path to run once
      more after `has_visible_effects()` becomes false; scoreboards,
      serve-wait, reset, unequip, item swap, and main-menu return can skip
      the renderer while a previously attached host remains visible. Add or
      update a focused smoke test that hides / tears down the host and stops
      any phase or loop audio at the boundary.
- [ ] Generated VFX PNGs are versioned in the Godot asset tree, loaded
      through `res://` / shared resource helpers, sliced and cached outside
      per-frame draw/update, and verified for transparent corners /
      non-edge alpha bounds.

Before sign-off on any Godot item VFX:

- [ ] List which layers shipped: texture / sprite sheet, shader,
      `GPUParticles2D`, `Tween` or `AnimationPlayer`.
- [ ] Name the modular layer stack and shader uniform preset(s). If an
      item introduced a reusable shader trick, note the intended future
      reuse path for related active, passive, legendary, or mythic VFX.
- [ ] Document any direct-draw-only exception as a deliberate fallback or
      remaining visual scope risk.
- [ ] Live-check a scaled/windowed layout so node-hosted item effects do
      not appear at top-left or drift from the playfield.
- [ ] For throwable / deployable / projectile items, test at least one
      left-edge and one right-edge case when the effect has a visual radius,
      horizontal radius, ellipse width, shockwave, particle burst, or trail
      larger than the projectile icon. Verify both the queued target and the
      final impact / field / flash / explosion center keep the full visual
      footprint inside the playfield, including after aim error, wall bounce,
      homing, knockback nudges, and range / size bonuses such as Commando Arm.
- [ ] Verify pickup / use / equip / proc / impact / expire / cancel /
      reset audio and visual cleanup against the Python reference.
- [ ] Run the repo-local Godot headless load check after Godot code or
      asset import changes.

### 0.2. Recurring Integration Traps

These are the bugs most likely to survive a "looks registered" pass:

- `owned / obtained` and `equipped / active` are different concepts.
  `[item_name]_obtained` should mean ownership / first acquire /
  respawn-gating, not "currently equipped".
- `sync_equipped_passive_effects()` should drive live effect state only.
  Do not let per-frame equip sync flip ownership flags back to `False`
  on unequip, or field respawn / one-time gacha rules will silently
  break.
- **Runtime-skill-driven item behavior must share one canonical helper
  path end-to-end.** If item gameplay depends on academy / downtown /
  item-tree runtime skills or temporary effective-level bonuses, do not
  let gameplay read raw `runtime_skill_levels.get()` while tooltip /
  description / other consumers read `get_runtime_skill_level()`,
  `get_runtime_skill_bonus()`, or a shared `get_effective_*` helper.
  Decide whether the behavior is base-level-only or effective-level-
  aware, then make every consumer read the same source.
- **Per-level constants for item runtime skill scaling should not be
  hand-copied into multiple consumers.** If a perk is defined as
  `+30% / level`, `+3% / level`, or similar, prefer the shared runtime
  helper / source table over ad-hoc numbers inside item-effect modules.
  This avoids "tooltip says 30%, runtime uses 25%" drift.
- **If one runtime perk changes multiple item-facing values, audit the
  `Lv.6+` dynamic description path too.** When
  `get_runtime_skill_description()` falls back to pattern / special-case
  generation above the base cap, confirm every scaling lane is still
  rendered (for example rarity bonus + passive-share bonus), not only
  the first effect.
- Duplicate policy is path-specific. Field drops, Pandora / treasure
  routes, shop / crane, and stage-clear gacha can intentionally diverge.
  Verify the real path-specific gate instead of summarizing an item as
  simply "duplicate-allowed" or "one-time".
- Stage-clear gacha is a separate candidate builder from `gacha.py`
  metadata. If an item should be one-time there, the gate must read an
  ownership signal, not the current equipped state.
- Special reward paths are independent. Nemesis chest pools, treasure-
  hunt legendary pools, the stage-clear gacha candidate builder,
  `gacha.py` item metadata / display sets, crane prize generation, and
  crane reward routing must each be audited separately.
- **Character-exclusive items must be filtered per acquisition path.**
  `items.py::spawn_random_item()` (field drop) is not the only gate.
  When an item is restricted to a specific character (e.g. Blacksmith-
  only, Viper-only), each independent spawn path must add its own
  filter: `gacha.py::init_gacha()` (`BLACKSMITH_ONLY_ITEMS` /
  `VIPER_ONLY_ITEMS` sets), `downtown/building_interior.py::_init_crane_prizes()`
  (conditional `passive_items.append(...)` gated by `is_blacksmith` /
  `is_viper`), and the Pandora Legacy v2 selection in
  `legendary_items.py::_generate_selection_choices_v2()`
  (`PANDORA_BLACKSMITH_ONLY_ACTIVE_NAMES` for actives /
  `PANDORA_VIPER_ONLY_PASSIVE_NAMES` for passives — add a new set and
  matching `_cur_char` branch per new restriction). Adding only the
  field-drop filter leaves the other-character player able to pull the
  item from the downtown gacha, the crane game, or Pandora's Legacy.
- When touching legendary / mythic equip sync, do not blindly copy an
  existing `sync_bool()` pattern into `[item_name]_obtained` without
  checking whether the repo path is actually modeling ownership or only
  current equipped state.
- If an item grants stun / knockback / CC immunity, block, or negate-on-
  proc behavior, decide explicitly whether it should apply to hostile
  gameplay CC only or also to self-recoil / paddle-hit feedback /
  scripted reposition. Default: **hostile gameplay CC only**.
- If the immunity / negate logic is wired into a shared helper, audit
  every caller of that helper before sign-off. If some callers are
  self-inflicted recoil, normal ball-hit feedback, or other non-hostile
  motion, add an explicit opt-out flag or a separate wrapper instead of
  assuming every caller is a valid proc source.
- If a new protection / immunity item wants to reuse an existing helper,
  do NOT widen a location / visual / environment helper by OR-ing the
  item state into it. Keep geometry / FX helpers semantically narrow and
  add a dedicated gameplay helper for the new immunity scope instead, or
  unrelated weather / event / visual callers can silently inherit the
  item effect.
- If a time-bound protection / immunity item reuses an existing shield,
  parry, timer, or HUD/VFX helper, pass the item's real effective
  duration source through that helper. Do not hardcode the base duration
  when caffeine, academy bonuses, item-tree bonuses, polish/enhancement,
  or future effective-duration modifiers can make `remaining_time` exceed
  the nominal default. Also guard reused fade/ratio math so
  `total_duration >= remaining_time` before applying fractional powers or
  alpha curves.
- If a time-bound item draws a timer-type gauge bar, verify the visible
  HUD placement as part of the runtime check: one active bar sits on the
  bottom baseline, and multiple active bars use the shared active-timer
  stack to move upward. A fixed high stack slot is not acceptable for a
  bar that may be the only active timer.
- In the Godot port, any active / passive / mythic item path that syncs
  `player_pos.x`, `player_paddle_width`, `player_paddle_height`, or paddle
  scale must preserve character-skill movement contracts. Do not use a
  plain `0..FIELD_WIDTH - paddle_width` clamp when Smasher `warp_gate` is
  active; it intentionally allows left / right offscreen wall-riding.
  Audit sibling sync writers too (`active_item_runtime`,
  `runtime_perk_state`, `mythic_item_runtime`, movement/dash mergeback) and
  extend `godot/tests/warp_gate_port_smoke.gd` or the focused equivalent
  before sign-off. Fixing only the item module that first exposed the bug
  is not enough if another per-frame sync can re-clamp the same coordinate.
- If one incoming gameplay event can apply both knockback and stun,
  verify the item's spend / proc model intentionally consumes once or
  twice. Do not let one hostile hit silently double-spend gauge /
  charges unless the design explicitly says so.
- **Electric-type stun is not just a blue overlay.** If an item ports or
  adds an electric stun (for example Ragnarok Hammer borrowing
  "God's Judgment: Lightning Fury" behavior), verify the full package:
  the normal boss stun sprite-sheet motion is selected, ordinary stun
  stars are suppressed only if the electric overlay replaces them, the
  original electric overlay / shock-loop sound is used, and the boss AI
  keeps the intended tiny previous-direction drift while stunned.
  Normal stun freezes in place; electric stun is allowed to slide
  slightly in the last movement direction.
- **Godot item impact shake must survive common paddle-hit feedback.**
  A strong item impact can be applied first and then silently overwritten
  later in the same collision by generic rally feedback if that path
  calls `set_screen_shake()`. Common / baseline feedback should merge
  with `max_screen_shake()` when stronger item, skill, or stage impact
  shake may already be active. Also verify the draw path applies the
  shake offset to the whole transformed playfield, not only to a few
  individual VFX positions, or the player will not perceive it as screen
  shake.
- **Paddle-hit gauge / state changes must be wired into BOTH collision
  paths.** `handle_player()` runs a main paddle-ball collision block,
  and `handle_ball()` runs a backup collision block (gated by
  `player_collision_handled == False and player_collision_cooldown <= 0`)
  that fires whenever `handle_player` missed the hit (e.g. fast ball
  sub-stepping, paddle moved mid-frame by an auto-tracking effect like
  AI pill). If an active / passive item changes gauge, consumes a
  charge, toggles a timed state, or sets a cooldown on paddle hit, the
  same logic must live in the `handle_ball` backup block too — otherwise
  the effect silently no-ops whenever the backup path is the one that
  actually catches the collision. AI pill's `-90` gauge drain is the
  canonical failure mode: the decrement was only in `handle_player`, so
  any frame where the backup caught the collision left the gauge
  untouched and AI pill effectively never timed out from blocks. Also
  set `player_collision_cooldown = PLAYER_COLLISION_COOLDOWN_FRAMES` on
  the backup-path branch when the existing gauge-charge block is
  skipped, or the same collision re-fires next frame.
- **Fixed-effect (non roll-based) legendary globals must NOT live in
  `_reset_roll_bonuses_to_default()`.** That reset is followed by
  `apply_roll_bonuses_from_equipped()` re-populating per-item roll
  values from the equipped item list. `apply_roll_bonuses_from_equipped()`
  has NO legendary-item branches — only the legendary loop inside
  `sync_equipped_passive_effects()` knows how to restore cape / crown /
  mask flag globals. If a fixed-effect global (e.g. `heavenly_cape_slot_bonus`,
  a future ± 1 slot mythic) gets added to `_reset_roll_bonuses_to_default()`,
  any re-entry into `apply_roll_bonuses_from_equipped()` after the
  sync's legendary loop has already set it (triggered by
  `recalculate_transcendent_crown_effects()` when `item_polish > 0`,
  or by direct calls from `apply_runtime_skill_effect` / passive
  unequip paths) will silently drop the global to 0 and never restore
  it. The canonical failure mode is Heavenly Cape (`heavenly_cape_slot_bonus`)
  disappearing whenever the player also has Transcendent Crown + item_polish
  perk — the 6th orb slot simply never renders. Rule: the sync's
  legendary loop (equipped branch sets value, `else:` branch resets to
  0 via `HeavenlyCape.deactivate()` / explicit global assignment) must
  be the sole authority for these globals; keep them out of
  `_reset_roll_bonuses_to_default()` entirely. Applies to any future
  legendary / mythic with a fixed on-equip effect expressed as a module
  global (slot count, flat damage, fixed resist %, etc.).
- **If an item changes character skill-slot count, audit every affected
  character's max-slot helper, HUD renderer, and "slots full" gate
  together.** Do not stop after wiring the shared global or one
  character's orb UI. A slot-expansion item such as Heavenly Cape can
  look correct for Smasher / Viper while Soldier still stays hard-capped
  at 5 if one path keeps reading a base constant in `_draw_*_skill_icons()`,
  `_get_character_max_skill_slots()`, or `is_*_skill_slots_full()`.
  Sign-off rule: the same effective slot count must drive render,
  equip / unlock gates, and overflow cleanup / unequip safety paths for
  every supported character. In the Godot port, generated skill-cluster
  HUD frames are character- and slot-count-specific too: choose the
  cluster frame texture from the same effective max-slot snapshot and
  slot-angle tuple (`base_angle`, `angle_step`) that drive orb positions,
  and make the underlay renderer reject a generated frame whose declared
  slot count does not match the live positions.
- **Godot equipment slot keys must match the rendered UI slot keys.**
  A semantic catalog slot is not enough if `character_info_overlay.gd`
  renders a different key. The canonical failure mode is Heavenly Cape:
  catalog / design said `back`, but the Godot equipment panel's visible
  "등" slot used `belt2`, so the item was equipped and its effects
  applied while the slot box looked empty. When adding a Godot passive /
  mythic equipment item, either register the catalog slot with the
  rendered key or canonicalize aliases before writing
  `owner.equipment_slots`, `owner.passive_item_slots`, and
  `_equipped_slot`. Smoke tests should assert the item appears in the
  exact rendered slot key, not only that `equipped == true`.
- **Runtime reads that must NOT miss a frame should bypass
  `item_effects/*` module globals and query the equipped item
  directly.** `sync_equipped_passive_effects()` calls
  `apply_roll_bonuses_from_equipped()` which first runs
  `_reset_roll_bonuses_to_default()` — that reset wipes per-item effect
  module state (e.g. `neural_helmet._gauge_reduction` / `_spawn_bonus_pct`)
  back to zero, then re-populates it by iterating equipped items. Any
  consumer that reads the effect module between the reset and the
  re-populate step sees a zeroed value, which appears in-game as a
  flaky "the effect only sometimes applies." The canonical failure mode
  is `neural_helmet`'s AI-pill spawn multiplier — originally
  `items.spawn_random_item()` called
  `neural_helmet.get_aipill_spawn_multiplier()` and would intermittently
  read `1.0` because spawn ticks lined up with the zeroed window. Fix:
  for frame-timing-sensitive reads (field spawn weight changes,
  per-hit stat changes, per-proc multipliers), look up the equipped
  item in `pingfighter.passive_item_list` — filtered by
  `item.get("_equipped_slot")` truthiness — and call
  `pingfighter._get_roll_value(item, key)` directly. That helper
  already composites polish + enhancement into a final value, so there
  is no double-application risk. Fall back to the effect module only
  when the equipped item is not present. The direction-key cancel path
  for `neural_helmet` was retrofitted the same way after the spawn
  fix — if a user-facing feature of the item is "time-sensitive",
  assume the module-global read path will eventually fail and wire it
  directly against `passive_item_list` from the start.
- **Item icon resolution has multiple override sites, not one.** The
  same `item_name` can be resolved through several distinct resolver
  functions — each with its own hardcoded procedural branches. If a
  single site is left unfixed, the new PNG silently loses in that one
  UI context even though every other UI shows the correct asset. Known
  resolver sites in the current repo:
  1. `items.py` `icon_files` loop (around line 1060) — early-return
     branches that install a procedural surface into `ITEM_ICONS`
     BEFORE the normal PNG-load path runs (the `vitamin_pill`
     override was this pattern).
  2. `pingfighter.py` `get_icon_safe()` (around line 159252) — used
     by the developer-mode active-item grid; has item-name-specific
     procedural branches that early-return before the
     `globals().get(icon_var_name)` fallback (the `flare` dev-mode
     bug was this pattern).
  3. `pingfighter.py` `get_item_icon()` (around line 161900) — used
     by many HUD / preview paths; has a long chain of
     `if item_name == "..."` procedural branches below its initial
     `_PNG_PRIORITY_ITEMS` priority check (the `banana` dev-mode bug
     was this pattern).
  4. Per-item module globals loaded at import time from disk (for
     example `flare_icon = pygame.image.load("items/flare.png")` at
     module init). Fine on their own, but become wrong when one of
     the resolver functions above short-circuits before reaching
     them.
  After regenerating an icon PNG, audit ALL FOUR sites. The cheap
  prevention is: add the `item_name` to `_PNG_PRIORITY_ITEMS` (the
  early-exit set at the top of `get_item_icon()`) and remove any
  per-item hardcoded branch inside `get_icon_safe()` whose new PNG
  should supersede procedural art. Do not assume "I checked `items.py`,
  so I'm done" — the same `item_name` passes through multiple
  resolvers in different UIs.
- **`_PNG_PRIORITY_ITEMS` alone is not enough — it is a two-stage gate.**
  The priority branch in `get_item_icon()` returns `items.ITEM_ICONS[name]`,
  so that dict must already contain the PNG. If you add the name to
  `_PNG_PRIORITY_ITEMS` but forget to register the PNG filename in
  `items.py` `load_item_icons()`'s `icon_files` dict (around line 1060),
  the priority branch reads `None`, falls through, and the hardcoded
  procedural branch in `get_item_icon()` still wins. Visible symptom:
  "I replaced items/foo.png on disk and added foo to the allowlist but
  in-game still shows the old procedural icon." The fix is **both** ends
  together:
  1. Register `"foo": "foo.png"` in `icon_files` so `ITEM_ICONS["foo"]`
     is populated on startup.
  2. Register `"foo"` in `_PNG_PRIORITY_ITEMS` so `get_item_icon("foo")`
     reads that value before the procedural chain.
  Historical miss: `venom_mist_gauntlet` had a procedural branch and a
  PNG file on disk but neither registration site, so the procedural
  icon always rendered even after the PNG was overwritten.
- **State-dependent icon variants need three things wired together, and
  downstream scale caches MUST be keyed on the icon surface identity.**
  Some items render one icon by default and a different icon while
  another item is equipped — the canonical case is `boomerang` swapping
  to `boomerang_metal` while `reinforced_boomerang_gauntlet` is on. That
  feature only works end-to-end when all three of these exist:
  1. **Pickup-time selection** in `store_active_item()` — pick the
     right variant icon at insertion based on current equipment state,
     so first pickup already lands on the correct image.
  2. **Equip hot-swap** in `sync_equipped_passive_effects()` — when
     equipment changes mid-run, iterate `active_item_slot` AND
     `arena_top_active_item_slot` and rewrite `item["icon"]` on every
     affected active item. (The current block in `pingfighter.py`
     around the `_boom_icon_key` branch is the reference pattern.)
  3. **Identity-keyed downstream caches** — both HUD render paths
     scale-cache the rendered icon. If either cache key is name-only,
     the hot-swap silently produces no visible change because the
     pre-swap scaled surface is returned forever. Known render caches
     to audit:
     - `pillar_background.py` `_get_scaled_icon()` and
       `_get_padded_slot_icon()` — used by the bottom pillar hot-bar
       (`draw_left_pillar_ui`). Key must include `id(icon)`.
     - `pingfighter.py` `draw_active_row()` — used by the
       character-info panel ACTIVE row, wraps `get_cached_scale()` with
       a cache key that must include `id(icon)`.
  Report this work done only after verifying in-game that the swap
  shows in both the hot-bar and the character-info ACTIVE row when the
  dependent passive is equipped AND when it is un-equipped mid-run.
  A new state-dependent variant pair (not just wood/metal boomerang)
  can reintroduce this failure — the surface identity rule in the
  scale-cache keys is what seals the whole pattern.
- **Throwable active items are consumed at key press, not at projectile
  spawn — preserve them if the round ends during the windup.** Items
  such as grenade, molotov, flare, dynamite, banana, soap, and boomerang
  flip a `{item}_throwing = True` + `{item}_throw_timer` pair in
  `activate_{item}()` and only create their projectile 0.4–0.6 s later
  when the timer hits 0. The active-item consumption path in
  `pingfighter.py` (the main `del active_item_slot[target_index]` block,
  the `_player_ai_try_use_active_item()` path, and the character-info
  `try_use_active_item_from_info()` path) deletes the item from the
  slot at activation time, so a ball that leaves the field during the
  windup silently drops the item AND its effect. Fix / invariant: the
  consumption path stashes a `_pending_throw_item_backup = {"item":
  item.copy(), "index": target_index}` when `_is_any_throw_windup_active()`
  is true, the 7 throw-completion branches in the player-movement block
  clear the backup once `throw_{item}()` actually runs, and
  `_restore_pending_throw_item_on_round_end()` — called from both
  `go_to_next_round()` and `reset_round()` — re-inserts the item into
  `active_item_slot` when any throwing flag is still set. When adding a
  new throwable active item or a new consumption path, wire the same
  save / clear / restore hooks. Alchemy-recycle already keeps the item
  in the slot, so the backup save is gated on `not recycle_triggered`.
- **Godot active-item ports must classify the Python activation shape
  before using a generic controller.** Do not infer "throwable" from
  broad metadata sets such as `throwing_items` alone. For each active
  item, read the Python reference activation function and classify it
  as one of: instant consumable, delayed thrown projectile, direct
  deploy / persistent world object, placed object with arming, or
  sustained timed field. Then make the Godot route match that shape
  intentionally. The canonical failure mode is `spider_mine`: Python
  `activate_spider_mine()` directly appends to `spider_mines`, but the
  Godot port briefly routed it through `pending_throws`, so the active
  slot consumed the item before the correct world-object lifecycle was
  visible.
- **Godot active-item sign-off must trace the full state-to-render
  chain.** For every new or modified Godot active item, verify:
  `active_item_catalog.gd` metadata -> `active_item_effect_router.gd`
  dispatch -> owning controller activation -> state array / timer
  mutation before returning `true` to the slot-use path -> update /
  collision / cleanup path -> public getter -> `active_item_runtime.gd`
  draw fanout -> renderer draw call -> audio use / windup / release /
  impact / loop / expire cues. If a controller exposes `get_*()` state
  and a renderer has `_draw_*()` for it, the main draw sequence must
  call that draw function. Missing the last link makes the slot consume
  the item while the gameplay object appears to vanish.
- **Godot active-item loop audio must be round-boundary safe.** If an
  active item starts or syncs a looped sound, wire a direct stop path in
  the item controller and add the stop method to
  `scripts/audio/gameplay_loop_audio_cleanup.gd`. Scoreboards pause
  active-item updates, so natural update cleanup is not enough: score
  event, scoreboard, serve wait, round restart, ball reset, and full game
  reset must all leave the loop silent. The canonical failure mode is a
  thrown boomerang or walking spider mine scoring while its loop is still
  active.
- **Godot active-item renderer optimizations must preserve UV and
  transform contracts.** If a change touches shared item icon helpers,
  `draw_set_transform`, textured `draw_polygon()`,
  `draw_texture_rect_region()`, sprite-sheet slicing, or projectile /
  deployed-object render fanout, compare the helper against at least one
  known-good sibling renderer before sign-off. `draw_texture_rect_region()`
  consumes pixel source rects; textured `draw_polygon()` must use the UV
  convention expected by the surrounding code, usually normalized `0..1`
  coordinates derived from the texture size. A bad shared UV helper can
  make one item look cropped and another item disappear while all
  `--check-only` tests still pass.
- **Godot active-item visual sign-off is not headless-only.** For every
  shared renderer helper optimization, live-check or screenshot-review at
  least two affected item families: one full-texture icon item (for
  example `molotov`, `spider_mine`, `boomerang`, or `banana`) and one
  sprite-sheet / region item when that path was touched. Confirm the icon
  subject is centered, not clipped, not invisible, and still visible
  through throw, wall / ground deploy, warning, impact, and cleanup states
  that use the helper.
- **Godot item VFX ports should not stop at copied procedural drawing.**
  For active, passive, legendary, and mythic item effects, run Section
  0.1A before sign-off. The Python implementation supplies timing and
  behavior; the final Godot effect should normally be texture / shader /
  `GPUParticles2D` / `Tween` or `AnimationPlayer` based, with direct
  `canvas.draw_*()` used only as fallback, deterministic geometry, or a
  documented low-cost exception.

---

## 1. New active item — checklist

Active items go into the active slot (5-orb cooldown UI). They are
consumed on use.

Current Godot-first rule:
- Implement new active-item runtime work under `godot/` by default.
- Use Sections 1.1–1.6 only as legacy Python reference surfaces when
  porting behavior from the frozen PingFighter codebase.
- For the actual Godot integration path, start with Section 1.7.

### 1.1. Legacy Python reference — `items.py`

- [ ] Add entry to `ITEM_TYPES` array (search `ITEM_TYPES = [` near
      line 1236) with `name`, `color`, `effect`, `icon`, `chance`,
      `duration` (if time-bound), `unlock_condition`.
- [ ] Add `"[item_name]": True` to `unlocked_items` dict (near line
      2048). Default state is required; omitting it breaks gacha /
      shop unlocks.
- [ ] Register drop rate inside `spawn_random_item()` (near line
      2314) if the item can spawn on the field.
- [ ] If the item must not spawn twice in the same run, add the dedup
      block in `spawn_random_item()` (pattern: existing duplicates
      near line 2477).

### 1.2. Legacy Python reference — `pingfighter.py`

- [ ] `store_active_item()` (near line 89587) — confirm the item is
      NOT in the passive-filter list at line 89600 (that list blocks
      passive names from reaching the active slot; active items must
      pass through).
- [ ] `show_item_obtained_effect()` (near line 96507) — verify the
      acquisition animation triggers. Most active items use the
      existing branch without per-item code.
- [ ] Add the item to the **primary developer mode `all_items` list**
      (near line 143285) with `"type": "active"` and an icon fetch via
      `get_icon_safe()` or `get_item_icon()`. Missing here means the
      dev mode 2-key menu cannot spawn the item for testing. The
      secondary character/item manager builds from `items.ITEM_TYPES`;
      do not add a second copied list there.
- [ ] If the active item has visible use / windup / projectile / deploy /
      field / impact / expire VFX in the Godot port, run Section 0.1A.
      Do not ship a direct copy of the Python procedural draw path as the
      final effect unless the exception is documented.

### 1.3. Legacy Python reference — `gacha.py`

- [ ] If the item should appear in gacha pulls, confirm it is present
      in the active-item pool construction near line 213 (the
      `gacha_available_items_template` is populated from the
      `available_items` parameter — check the caller passes the new
      item name).

### 1.4. Legacy Python reference — shop / crane

- [ ] `downtown/building_interior.py` — add the item to the hardcoded
      active-items list (near line 3823) to make it sellable in the
      shop and drawable in the crane capsule pool.
- [ ] Crane game capsule generation (same file, near line 3917) —
      confirm the new item is eligible if intended.

### 1.5. Legacy Python reference — `unknown_item` path

- [ ] If the item is intended to be a possible resolution of an
      `unknown_item` pickup, wire it into the resolve table used at
      that pickup site. The placeholder asset is `items/unknown_item.png`
      (already on disk — do NOT overwrite). If the resolve table does
      not already exist for this flow, this is a new feature decision
      and belongs in a design pass before this checklist.

### 1.6. Legacy Python reference — reset on death / main menu return

- [ ] If the active item owns additional run-scoped module / global /
      singleton state (timer, aura flag, immunity flag, helper object,
      looped sound, etc.), audit every real teardown boundary, not only
      `reset_runtime_items()`: death / game over, main-menu return,
      stage advance, surrender / abandon, and any other session-end path
      that already deactivates comparable timed actives.
- [ ] Confirm the item is cleared by `item_state_manager.reset_runtime_items()`
      (near line 10). The default reset wipes `active_items` without
      per-item code, so in most cases no change is needed. Verify by
      spawning the item in a run, dying, and returning to main menu —
      the active slot must be empty.

### 1.7. Godot active-item integration

- [ ] Classify the Python behavior from the real activation / update /
      draw functions before choosing a Godot owner. Do not rely on a
      broad item category list when deciding whether the Godot item
      belongs in `pending_throws`, a direct deployed-object array, a
      consumable-effect controller, or a timed field controller.
- [ ] Audit the complete Godot route: `active_item_catalog.gd` effect id,
      `active_item_effect_router.gd` dispatch, the owning controller's
      `activate_*()` return value, slot consumption behavior in
      `active_item_slot_controller.gd`, update/reset ownership, exposed
      getters, `active_item_runtime.gd` draw fanout, renderer call, and
      `game_audio.gd` cues.
- [ ] **Ball-interacting deployables must decide their `BallMotionStepper`
      ordering against `check_paddles()` explicitly — and ordering alone is
      not enough.** The player paddle hitbox band is `player_pos.y ±
      hitbox_padding + paddle height` (~y 695..760 at runtime), so any
      floor-band object checked AFTER `check_paddles` is unreachable while
      the player x-overlaps it. Worse, even when the object's check runs
      FIRST, sub-stepping (max 12 px) means the paddle still wins whenever
      the object's collision band top sits below the paddle hitbox top —
      the ball hits a paddle-only overlap window earlier. Decide the intent
      per object: a pure missed-ball blocker (brick wall) may let the
      paddle pre-empt; an object that must visibly proc while the player
      stands on it (trampoline) needs BOTH its check placed before
      `check_paddles` in `ball_motion_stepper.gd` AND its collision band
      top above the paddle hitbox top
      (`active_item_trampoline_runtime.TRAMPOLINE_MAT_TOP_Y` is the
      reference). The smoke must drive the full `BallMotionStepper.step()`
      path with `player_pos` / `player_paddle_size` / `hitbox_padding` plus
      the object's collision context and assert the returned event BOTH
      with the player x-overlapping the object and away from it
      (`active_item_trampoline_smoke._verify_stepper_full_path_collision_priority`
      is the reference). A detector-only unit test cannot catch this
      priority regression.
- [ ] **The F2 debug spawn menu is NOT catalog-driven — add the item to
      `active_item_debug_spawn_menu.gd::DEBUG_ENTRY_ORDER` by hand.** The
      menu calls `item_catalog.build_item_by_name()` per cell, which makes
      it LOOK catalog-enumerated, but the visible grid entries come from
      its own hardcoded `DEBUG_ENTRY_ORDER` list — the Godot reincarnation
      of the legacy Python dev-mode `all_items` trap in §1.2. Membership
      in `FIELD_SPAWN_ORDER` does not surface the item there. Cell icons
      resolve generically from the catalog `icon_path`, so only the list
      entry is needed. Seal it with a smoke assert that
      `DEBUG_ENTRY_ORDER.has("<item_name>")`
      (`active_item_trampoline_smoke.gd` is the reference). Intentional
      exclusions (e.g. `lingpet_generated_only` milk_bottle,
      `supply_drop_only` ammo_box / doping_potion) should stay out and be
      noted as deliberate.
- [ ] For any active-item loop sound, add / verify all links:
      `play_*_loop` or `sync_*_loop` in `game_audio.gd`, direct
      item-controller stop when the last runtime object is gone,
      `active_item_runtime.reset()` cleanup if applicable, and the
      `stop_*` method in `scripts/audio/gameplay_loop_audio_cleanup.gd`.
      A score while the item is mid-flight / walking / ticking must not
      leave audio alive into the scoreboard or next serve.
- [ ] If activation returns `true` and the item is consumable, confirm
      that at least one intended runtime state mutation has already
      happened, or a documented pending-windup backup path exists. Do
      not consume an item on a route that only schedules an unrendered
      placeholder.
- [ ] For every item-specific runtime list (`grenades`, `spider_mines`,
      `placed_dynamites`, `*_particles`, `*_zones`, etc.), confirm all
      four links exist together: reset clears it, update mutates it,
      a getter exposes it, and the active-item renderer draws it from
      the main draw sequence.
- [ ] If the item change touched a common draw helper, texture-region
      helper, transform helper, or renderer-level optimization, compare
      the new helper with the existing field / actor / stage renderer
      pattern and then visually check every affected active-item family,
      not just the item named in the request. In particular, verify
      `molotov` throw icon visibility and `spider_mine` face / body crop
      after any `_draw_rotated_texture_region()`-style change.
- [ ] Manual Godot check: use the item from a real active slot and from
      the debug grant path when available. The HUD slot may disappear
      only when the item is intentionally consumed, and the world object
      / projectile / field must remain visible through its full lifecycle
      until impact, expiry, or reset cleanup.
- [ ] If the item has loop audio, include a focused smoke or manual check
      that scores the round while the loop is active, waits through the
      scoreboard / serve-wait transition, then confirms the loop does not
      restart unless a new item activation explicitly starts it.
- [ ] **Active-item cooldown anchors must reset on stage transition.**
      `active_item_slot_controller.gd` keeps a global `last_item_use_msec`
      anchor and inherits it into newly-acquired items' per-item
      `last_use_msec` (both `append_item_data` and `store_active_item`).
      `match_reset_controller.reset_for_stage_transition` intentionally
      skips `_reset_item_runtimes`, so the global anchor leaks across the
      stage boundary. Wall-clock time (`Time.get_ticks_msec()`) keeps
      ticking through the result screen, but if the player used an active
      item in the rally that won the stage and the result screen + stage
      transition completes in less than the active-item cooldown (default
      10s, ~9.1s after the standard perk reduction), the next round starts
      with **all** active slots blocked because the global cooldown check
      `now - last_item_use_msec < cooldown_msec` still fails. The newly-
      acquired stage-clear reward inherits the same stale anchor as its
      per-item `last_use_msec`, so it is also blocked. The symptom is "1/2/3/4
      keys do nothing on the next round" until the cooldown lapses on its
      own — players often perceive a later field pickup as the fix because
      by then time has elapsed. Fix: `battle_scene_match_flow_driver.gd::
      reset_for_stage_transition` calls
      `slot_controller.reset_cooldowns_for_stage_transition(...)` after
      `apply_reset_result`, which rewinds the global anchor to `-1000000`
      and clears every slot's per-item `last_use_msec` / `last_use`. Slot
      data itself (name, cooldown_msec, rolls, etc.) is preserved.
      Regression smoke: `active_item_slot_controller_cooldown_stage_transition_smoke.gd`.
      Any future stage-transition reset path that wants to keep current
      progression must call the same cooldown-reset helper, or it will
      regress this trap.

---

## 2. New passive item — checklist

Passive items equip to a body-part slot (머리 / 상의 / 팔 / 벨트 / 무릎 /
신발 / 등 / 장신구) and apply effects while equipped.

Current Godot-first rule:
- Implement new passive-item runtime work under `godot/` by default.
- Use Python file sections below only to understand legacy acquisition,
  equip, roll, polish, enhancement, and reset behavior during a port.
- Mirror the same ownership-vs-equipped distinction in Godot, but do not
  edit legacy Python files unless the user explicitly asks.

Bug pattern history: a new passive drops on the field but never lands
in the inventory, drops infinitely, or gets routed to an active slot.
Missing any one of the items below causes a silent failure.

Ownership rule for every passive item in this section:
- `[item_name]_obtained` is an ownership / first-acquire /
  respawn-gating flag only.
- Do NOT reuse `[item_name]_obtained` to mean "currently equipped" or
  "effect currently active".
- If an item needs a live equip-state signal, use a separate equipped /
  active flag or the equipped-item list inside
  `sync_equipped_passive_effects()`.

### 2.1. Legacy Python reference — `items.py`

- [ ] `ITEM_TYPES` array (near line 1236) — add with `body_part`,
      `chance`, `unlock_condition`.
- [ ] `unlocked_items` dict (near line 2048) — `"[item_name]": True`.
- [ ] Module-level `[item_name]_obtained` flag (alongside existing
      flags near lines 1991–2042, e.g. `speedboots_obtained = False`).
- [ ] `update_items()` (near line 2741) — add to the passive routing
      branch. Omission causes the item to be treated as active on
      pickup.
- [ ] `spawn_random_item()` (near line 2314) — add the name to the
      `passive_names` set (near line 2510) so drop-weight math
      counts it as passive.
- [ ] `spawn_random_item()` dedup block — add the check
      `if item["name"] == "[item_name]" and [item_name]_obtained: ...`
      so the item stops spawning after the first acquire (unless
      duplicates are allowed; see 2.2).
- [ ] `PASSIVE_DUPLICATE_ALLOWED` set (near line 2143) — add the name
      ONLY if duplicate farming is intended (e.g. `gold_digger`,
      `sage_ring`).

### 2.2. Legacy Python reference — `pingfighter.py`

- [ ] `store_active_item()` (near line 89587) — add the name to the
      passive-filter list at line 89600. Omission routes the passive
      to the active slot on pickup.
- [ ] `store_passive_item()` (near line 90045) — add the
      `elif item_data["name"] == "[item_name]":` branch and set
      `item_data["type"] = "passive"`, call `ensure_passive_rolls()`
      and `apply_roll_bonuses_from_item()`, then `show_item_obtained_effect()`.
- [ ] **If the item is in `PASSIVE_DUPLICATE_ALLOWED`: never set
      `skip_append = True`.** See §2.3.
- [ ] **Body-part slot is not enough — confirm auto-equip into empty
      slot.** `store_passive_item()` must, after appending, check
      whether the player has a free body-part slot of the matching
      body-part family (`PASSIVE_SLOT_ORDER` at line 143151 maps
      each body part to the item names that live there) and
      auto-equip the item there if so. Items that only land in the
      inventory and never auto-equip look broken to the player.
- [ ] `sync_equipped_passive_effects()` (near line 33362) — if the
      passive has roll options, polish-perk scaling, or an
      enhancement bonus, add the sync block (see §2.4 and §4.3).
- [ ] Passive effects must be equip-gated. Owning the item in passive
      inventory is not enough; the live gameplay effect should turn on
      only while the item is actually equipped, and unequipping it must
      disable the effect immediately.
- [ ] **`PASSIVE_SLOT_ORDER` list** (near line 143151) — add the new
      item name to the body-part slot it belongs to. Omission hides
      the item from the body-part equip UI.
- [ ] **Primary developer-mode hardcoded `all_items` list** (near line
      143285) — this is a SEPARATE hardcoded list from
      `PASSIVE_SLOT_ORDER`. It instantiates the actual item
      dictionaries that the developer-mode 2-key menu displays.
      **You must update both.** Omission hides the item from the dev
      mode menu. The secondary character/item manager is generated
      from `items.ITEM_TYPES` and `items.is_passive_inventory_item()`,
      so do not maintain a second copied `all_items` block for it.
- [ ] `get_item_name_korean()` and `get_item_description()` - add the
      new item so inventory, shop, tooltip, and developer-mode UIs
      do not show raw snake_case or fallback text.
- [ ] Online / multiplayer passive classification - update the shared
      `items.py` passive classification source instead of adding a
      local synced list in `pingfighter.py`. Normal passive drops belong
      in `PASSIVE_DROP_ITEM_NAMES`; passive legendaries / mythics belong
      in `LEGENDARY_PASSIVE_ITEM_NAMES`. The online client pickup path
      must route through `items.is_passive_inventory_item()`. Omission
      can misclassify the passive as an active item in synced state.
- [ ] If the passive item has a visible equip aura, proc burst, shield,
      transform, field, attached VFX, absorb, or persistent theme effect
      in the Godot port, run Section 0.1A. Its visual active state must
      be equip-gated by the same state as the real gameplay effect.

Equip-state rule for this section:
- `sync_equipped_passive_effects()` may toggle live effect state,
  globals, manager instances, or separate `equipped` / `active`
  flags.
- It must NOT redefine `[item_name]_obtained` to mean
  "currently equipped".
- If unequip can flip `[item_name]_obtained` back to `False`, field
  respawn and gacha one-time gating will silently break.

### 2.3. `PASSIVE_DUPLICATE_ALLOWED` — `skip_append` is forbidden

For items in `PASSIVE_DUPLICATE_ALLOWED` (e.g. `gold_digger`,
`sage_ring`, every legendary / mythic):

```python
# WRONG: duplicate acquire silently skips inventory append
elif item_data["name"] == "gold_digger":
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        # activate / equip ...
    else:
        print("already owned")
        skip_append = True   # BUG: second acquire never appears in inventory

# RIGHT: first-acquire activates, every acquire runs rolls and falls
# through to append
elif item_data["name"] == "gold_digger":
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        from item_effects.gold_digger import activate_gold_digger, equip_gold_digger
        activate_gold_digger()
        equip_gold_digger()
    item_data["type"] = "passive"
    ensure_passive_rolls(item_data)
    apply_roll_bonuses_from_item(item_data)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
    # no skip_append; function-end handles inventory append
```

Rules:

1. Items in `PASSIVE_DUPLICATE_ALLOWED` never set `skip_append = True`.
2. Only the first acquire sets `[item_name]_obtained` and runs the
   activate / equip branch.
3. `ensure_passive_rolls()` + `apply_roll_bonuses_from_item()` run on
   **every** acquire (duplicates roll-farm by design).
4. Inventory append happens automatically at the end of
   `store_passive_item()` when `skip_append` is False.
5. Duplicate / one-time gating must read the ownership signal, not the
   current equip state. "Unequipped" must never be interpreted as
   "never acquired".

### 2.4. Roll options

- [ ] If the item has randomly-rolled stats (roll options), define
      them in `ensure_passive_rolls()` / `apply_roll_bonuses_from_item()`
      so every acquire produces a rolled copy.
- [ ] If the item also has a fixed option / guaranteed stat line,
      render it in the option tooltip with the same plain style used by
      `dashholder`. Do **not** append a separate `(고정)` marker just
      because the value is fixed.
- [ ] Confirm the rolled numbers actually land in-game (spawn the
      item, read the roll from the item card, compare with the stat
      the code reads from the equipped item).
- [ ] If you change an existing passive roll range, sync **every**
      fallback/default path too, not just `PASSIVE_OPTION_RANGES`:
      module-level default globals, `_reset_roll_bonuses_to_default()`,
      and any per-item effect-module default/reset value that can be
      used when `rolled_options` are absent (legacy saves, pre-roll
      fallback paths, reset/reactivation flows). Confirm no fallback
      value remains outside the new min/max.
- [ ] If the item changes **player-skill cooldowns**, verify the
      left-side 5-orb HUD uses the same final effective cooldown in
      all display paths too: orb countdown text, cooldown wedge
      timing, and tooltip `쿨타임` text. Do not leave display code on
      raw `skill_data["cooldown"]` while gameplay uses a reduced
      value.
- [ ] If the item or downtown / item-tree perk changes item spawn odds,
      passive-vs-active share, timed duration, or similar runtime math,
      compare the player-facing number with the stat-consumption path at
      both a normal invested state and an effective `Lv.6+` state when
      applicable. Confirm every consumer uses the same level basis and
      the same per-level constant.

### 2.5. Polish perk

- [ ] If the item is affected by the polish perk, apply polish inside
      the item's stat-read path. Confirm the polish perk's increased
      numbers actually apply in-game at the point the stat is
      consumed — not only at display time.

### 2.6. Enhancement bonus

- [ ] If the item can be enhanced, the enhancement bonus must apply
      inside the same stat-read path. Sync the equipped item's
      `enhancement_bonus_pct` into whatever runtime object holds the
      active stat (pattern in `sync_equipped_passive_effects()` near
      line 33532 for `slot_add`).

### 2.7. Equip visual

- [ ] If the passive has a character equip visual (overlay on the
      player paddle / skin), call `apply_item_to_skin()` from
      `entities/body_parts/item_parts_registry.py` on equip (pattern
      near line 34088, and per-item hooks at lines 90166–90752).
- [ ] Add the item name to `VISUAL_ITEM_NAMES` in
      `entities/body_parts/item_parts_registry.py` (imported in
      `pingfighter.py` near line 39075) so the equip-visual pass picks
      it up.
- [ ] Add the item to `ITEM_SLOT_MAP` in
      `entities/body_parts/item_parts_registry.py`. This visual slot
      map is separate from the gameplay equip-family map
      (`ITEM_SLOT_BASE_MAP` / `PASSIVE_SLOT_ORDER`).
- [ ] **Do not assume the gameplay slot and the visual slot are the
      same thing.** If the item can visually coexist with another
      family (for example `top + belt`), do NOT reuse a single
      `CharacterSkin.parts` slot unless overwrite is explicitly
      intended.
- [ ] If coexistence would collide on an existing visual slot, add a
      dedicated visual slot in `entities/player_skeleton.py`
      (`SLOT_*`, `ORDER_*`), move the relevant body-part classes to
      that slot, and update `remove_item_from_skin()` default-slot
      handling (`DEFAULT_PARTS`) accordingly.
- [ ] On unequip, call `remove_item_from_skin()` so the overlay is
      cleared.
- [ ] Run at least one **coexistence visual QA pair** if the item
      shares silhouette space with a neighboring family
      (examples: `technical_vest + timer_belt`,
      `bulkup + megingjord`).

### 2.8. Legacy Python reference — gacha / shop / crane / treasure hunt

- [ ] `gacha.py` (near line 213) — confirm the item is included in
      the passive-item pool (`PASSIVE_ITEM_NAMES` set around line 225)
      if intended.
- [ ] Treat each special reward path as separate. `gacha.py` metadata,
      the stage-clear gacha builder in `pingfighter.py`, Nemesis chest,
      treasure-hunt pools, crane capsule generation, and crane payout
      do not auto-sync with one another.
- [ ] **Stage-clear gacha candidate builder** - confirm the actual
      `available_items.append(...)` path in `pingfighter.py` adds the
      item too. `gacha.py` metadata alone is not sufficient.
- [ ] If a route can award both active and passive items, audit the
      grant function as well as the candidate pool. A passive mythic can
      still fail if the reward path routes it through
      `store_active_item()`.
- [ ] If duplicate farming is intended, verify whether the
      stage-clear gacha path should also repeat after first obtain.
      Many items intentionally allow field duplicates while remaining
      one-time in stage-clear gacha. Report this per-path behavior
      accurately.
- [ ] Economy parity — if the item can be bought or sold, set a
      sensible `sell_price` in the item data and benchmark it against
      comparable passives instead of leaving a placeholder number.
- [ ] `downtown/building_interior.py` — add to the hardcoded
      passive-items list (near line 3859) with an appropriate
      `base_price` so the shop sells it and the crane capsule pool
      includes it.
- [ ] `downtown/constants.py` — if the item is tagged as a shop
      category, confirm any category set (there is a `LEGENDARY_ITEM_NAMES`
      at line 552; non-legendary passives usually don't need an entry
      here, but re-check the file for any item-category set).
- [ ] Treasure hunt / 보물탐색 — the `downtown_treasure_map` perk
      (references in `pingfighter.py` near lines 15255, 15555, 19240,
      52392) drives three distinct paths and the first two are gated
      by set membership:
      1. Field spawn uses 3-group shares (active / passive / mythic)
         defined in `items.py`. A new **mythic** item MUST be listed
         in the `mythic_names` set inside `spawn_random_item()` (also
         `MYTHIC_BASE_SHARE` / `MYTHIC_MAX_SHARE` / `MIN_ACTIVE_SHARE`
         tune the per-level share curve). A new **non-mythic passive**
         only needs the normal passive registration — mythic items
         that accidentally land only in `passive_names` will fall into
         the 40+ normal-passive pool and get silently diluted.
      2. Passive drop share bonus (`0.03 * treasure_map_level` target_p
         bonus) covers the normal-passive group, not mythics.
      3. Active skill (보물탐색) legendary pool — confirm the item is
         in `determine_treasure_hunt_result()`'s legendary list if it
         should be drawable that way.
      Confirm the new item is rolled through the intended path.

### 2.9. Legacy Python reference — reset on death / main menu return

- [ ] `item_state_manager.reset_runtime_items()` (near line 10) must
      clear `passive_items`, reset `[item_name]_obtained` flags, and
      unequip any per-item runtime state.
- [ ] If the item modifies a global (e.g. a buff multiplier held in
      `pingfighter.py`), reset that global too.
- [ ] Equip visuals must be cleared on reset so the player paddle
      starts fresh in the next run.

---

## 3. New legendary / mythic item — checklist

Legendary items are always passive and always use the full legendary
frame stack for their icon.

Current Godot-first rule:
- Implement legendary / mythic item runtime work under `godot/` by default.
- Use Python file sections below as legacy reference for classification,
  acquisition gates, duplicate policy, roll/polish/enhancement behavior,
  and special reward routes.
- Active mythics must stay on their intended Godot active path; do not
  force them through passive-only legacy rules.

Passive legendary / passive mythic: do §2 (passive checklist) first.
Then everything below.

Most mythics in the repo are passive, but active mythics can exist
(example: `elixir_of_mastery`). Treat the shorthand above like this:

- Passive legendary / passive mythic: do Section 2 first, then
  everything below.
- Active mythic: do Section 1 first, then the route-audit bullets in
  Section 3.5 below. Do not blindly copy passive-only legendary rules
  into the active path.

### 3.1. Legacy Python reference — `legendary_items.py`

- [ ] `class [ItemName](LegendaryItem):` definition (pattern near
      line 585 and later; existing classes are instantiated in
      `LegendaryItemManager._init_legendary_items()` near line 13035).
- [ ] `LEGENDARY_ROLL_OPTIONS` dict (near line 70) — add roll option
      list with `key`, `label`, `min`, `max`, `unit`, `default`, and
      optionally `step` and `reverse`.
- [ ] `LegendaryItemManager._init_legendary_items()` (near line
      13035) — instantiate the new class so it lands in the
      legendary registry.
- [ ] Roll-value reader uses `get_legendary_roll_value(item_name,
      option_key, apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)`
      (signature near line 116). `apply_polish=True` is required for
      the polish perk to apply; `enhancement_bonus_pct` is required
      for the enhancement buff to apply.
- [ ] **Pandora routing decision.** Audit the Pandora Legacy lists in
      `legendary_items.py` on purpose. Passive legendary / passive
      mythic names that must not enter Pandora's active roulette belong
      in the passive / mythic exclusion sets. Active mythics are the
      exception: keep them on the intended active path instead of
      blindly forcing them into the passive exclusion set.

Legendary sync warning for the next section:
- If an existing `sync_bool()` path is reused here, verify it is not
  collapsing `ever acquired / respawn-gating` into `currently equipped /
  effect active`.
- Reset / main-menu-return should clear ownership flags; per-frame equip
  sync should drive only the live equipped state.

### 3.2. Legacy Python reference — `pingfighter.py`

- [ ] `get_item_icon()` — add the name to the legendary-name list so
      the HUD icon pipeline knows to render the full frame stack;
      otherwise the icon shows `?`.
- [ ] Legendary obtained-flag sync — add the `sync_bool()` call (the
      existing pattern for `ragnarok_hammer_obtained` etc.) so
      re-entry / reset clears the flag.
- [ ] `store_active_item()` passive-filter — the passive-filter
      list near line 89600 MUST include every passive legendary or
      passive mythic name. Active mythics are the exception and must
      stay on the intended active path.
- [ ] `store_passive_item()` — passive legendary / passive mythic
      duplicates are allowed; never set `skip_append = True` in that
      branch. See §2.3.
- [ ] `sync_equipped_passive_effects()` (near line 33362) — for
      passive legendary / passive mythic items, add
      on-equip / on-unequip blocks that:
      - On equip: read `enhancement_bonus_pct` from the equipped item
        dict and write it into the legendary-manager instance so
        stat reads pick it up.
      - On unequip: reset `enhancement_bonus_pct = 0`.
      - If roll options drive perk-like behavior (e.g. `sage_ring`
        penalty), also sync those (pattern near lines 33510–33526).

Passive-route note for the three bullets above:
- They apply to passive legendary / passive mythic items.
- Active mythics are the exception: keep them on the active path, do
  not add them to the passive filter, and do not force them through
  passive inventory / equip sync logic.

- [ ] If the legendary / mythic effect hooks into shared CC helpers
      (`apply_knockback_resist()`, `try_apply_player_stun()`, or
      equivalent), audit all callers and exclude non-hostile self-
      recoil paths such as normal paddle-hit recoil, self-fireball
      recoil, scripted transform recoil, or character self-stun /
      recoil. A defensive proc that is meant to block enemy CC must not
      trigger from ordinary ball-control feedback unless the design says
      so.

### 3.3. Legacy Python reference — `items.py`

- [ ] `spawn_random_item()` `legendary_names` set (near line 2493) —
      add every passive legendary / passive mythic name so field spawn
      weighting treats it as legendary.

Passive-only note:
- Add passive legendary / passive mythic names to the `legendary_names`
  field-weighting list in `items.py`.
- Active mythics stay on the intended active-item path unless design
  explicitly says otherwise.

### 3.4. Legacy Python reference — `downtown/`

- [ ] `downtown/constants.py` `LEGENDARY_ITEM_NAMES` (near line 552) —
      add the name.
- [ ] `downtown/building_interior.py` — add to the legendary list
      embedded in the shop passive list (near line 3859) so the shop
      sells the new legendary.

Shop note:
- Downtown legendary shop lists are passive-only. Do not force active
  mythics into the passive shop path unless the shop design changes.

### 3.5. Godot gacha / crane / special reward routes

- [ ] `gacha.py` item classification / display sets - add the item to
      the correct legendary / passive / active metadata so the gacha can
      classify and render it properly.
- [ ] **Stage-clear gacha candidate builder** - confirm the actual
      candidate list in `pingfighter.py` adds the item too. `gacha.py`
      metadata alone is not sufficient.
- [ ] If stage-clear gacha should be one-time, gate it with ownership /
      obtained state, not current equipped-state sync booleans.
- [ ] **Nemesis chest** - audit its legendary / mythic candidate pool
      separately. Do not assume field-spawn or gacha lists feed it
      automatically.
- [ ] **Treasure hunt legendary pool** - audit the treasure-hunt
      candidate list separately from field weighting. If the mythic is
      active, also verify the reward-grant branch sends it through the
      intended active path instead of passive storage.
- [ ] **Crane spawn pool** - audit the crane capsule rarity lists
      separately from shop passive lists. A passive legendary / mythic
      can be sellable in shop yet still be missing from crane.
- [ ] **Crane reward routing** - audit the payout classifier separately
      from the spawn pool. Passive legendary / mythic names must land in
      `store_passive_item()`, while active mythics must land in the
      intended active grant path.
- [ ] If an active mythic should appear in crane or another active-
      rarity route, add an explicit legendary-active bucket / roll path.
      Do not assume the common / epic active tables can ever surface it.

### 3.6. Godot icon asset

- [ ] Legendary frame stack baked into the PNG(s) per
      `LEGENDARY_ITEM_TEMPLATE.md` in the repo root.
- [ ] Godot mythic equipment / slot icons are animated sheet-first, not
      static-only, unless the design explicitly says the mythic is a
      deliberately still icon. The catalog entry should expose sheet
      metadata such as `icon_sheet_path`, frame count, and frame timing;
      a static PNG may remain only as fallback.
- [ ] Godot mythic icons must fill their slot box by perceived subject
      size, matching the Megingjord belt presentation. Audit source
      inset / slot-fill metadata and the smallest real equipment or HUD
      slot where the icon appears. A mythic icon that looks centered but
      tiny inside the box is not done.
- [ ] Developer-mode legendary tab auto-discovers unlocked legendary
      items from the `LegendaryItemManager` registry (pingfighter.py
      near line 143363, filtered by `item.unlocked` and excluding
      `empty` / `empty1` / `empty2`). Adding the new legendary to the
      manager (§3.1 step 3) is enough — the dev mode grid picks it
      up automatically.
- [ ] Do NOT overwrite `empty_legendary*` assets / names — these are
      blank placeholders used by the developer-mode grid layout.

### 3.7. Godot theme particle / runtime effects

- [ ] The icon PNG does NOT animate particles; the runtime effects
      manager spawns them. Pick the particle theme per the
      item-generation skill §6.3, and wire the spawn hook into
      whatever runtime code already drives particle emission for
      similar legendary items (thor hammer blue sparks, hermes cyan
      streaks, poseidon teal droplets, etc.).
- [ ] Every legendary / mythic must have a theme-consistent particle
      hook. An icon on a legendary frame with no particle theme
      reads as incomplete.
- [ ] For Godot legendary / mythic VFX, run Section 0.1A. Acquisition
      reveal, passive/proc particles, transform/showcase effects, and
      equipment-slot icon animation should feel like one item identity,
      not separate fallback drawings.
- [ ] Active mythics are not exempt from the VFX rule. If the mythic
      grants an active use / projectile / field / impact effect, apply
      the active-item VFX checks as well as the legendary / mythic theme
      checks.

### 3.8. Godot duplicate acquire flow (farming rolls)

- [ ] First acquire: set `obtained = True`, register with the
      legendary manager, play the acquisition animation.
- [ ] Every acquire (first and later): `item_data["type"] = "legendary"`,
      call `ensure_passive_rolls()` and
      `apply_roll_bonuses_from_item()`, fall through to inventory
      append. **No `skip_append = True`.** See §2.3.

---

## 4. Godot `unknown_item` and acquisition animation

Godot-first note:
- For current work, wire unknown-item resolution and acquisition animation
  through the Godot item catalog / effect owner / HUD or reveal renderer.
- Python references below are useful to compare legacy behavior only.

### 4.1. `unknown_item` resolution

- `items/unknown_item.png` is the placeholder icon for an item that
  has not resolved yet. Do NOT overwrite this file.
- A new item may be wired in as a possible resolution of an
  `unknown_item` pickup if the design calls for it. The resolve
  pipeline is the place to do this — not the icon itself.
- After `unknown_item` resolves, the resolved item must go through
  the normal acquisition animation, exactly like a direct pickup.

### 4.2. Godot acquisition animation parity

- Every Godot item pickup must route through the shared acquisition /
  reveal renderer. Legacy Python used `show_item_obtained_effect()`
  (pingfighter.py near line 96507) for active, passive, and legendary
  items; preserve that single-entry behavior in the Godot owner instead
  of branching to a custom one-off animation for a new item.
- If the item is resolved from `unknown_item`, call the same function
  after the resolve so the animation looks identical to a direct
  pickup.
- If an item acquisition cinematic can overlap with a runtime perk choice
  or starpoint pickup, verify modal input priority. A paused acquisition
  cinematic must not consume click / confirm events before the visible
  perk-choice modal receives them, or both systems can remain active while
  neither can progress. Lock the overlap with a focused Godot smoke.

---

## 5. Godot reset lifecycle (death / main menu return)

Godot-first note:
- Current item reset lifecycle belongs in Godot owner modules, shared item
  runtime state, round cleanup, score / serve-wait cleanup, and game-reset
  paths.
- Python globals and manager functions below are legacy reference points.

Every run-scoped state must be cleared on death or return to main
menu. Missing a reset causes state to leak into the next run.

- [ ] `item_state_manager.reset_runtime_items()` (near line 10)
      clears `active_items`, `passive_items`, and resets
      `max_item_slots` to 3. Verify the new item is cleared.
- [ ] All `[item_name]_obtained` flags in `items.py` must be reset.
      Use an ownership-reset path or an explicit reset in the
      main-menu-return flow. Do NOT rely on per-frame equip sync to
      clear ownership flags.
- [ ] Equip-visual overlays must be removed from the player skin on
      reset — otherwise the next run starts with stale character
      visuals.
- [ ] Roll-option values, polish-perk scaling, and enhancement
      buffs are derived from the equipped item dict, so they reset
      automatically when the inventory clears. Confirm by spawning
      the item, dying, and checking the next run has baseline stats.

---

## 6. Legacy Python hardcoded integration points audit — easy to miss

This table is a frozen PingFighter reference map. Use it to understand what
legacy behavior depended on during a port, not as a default edit list for
디스크하츠 - 링피아. For current work, map each row to the relevant Godot
catalog, router, owner module, renderer, save/load state, and debug menu.

The table below lists every hardcoded item list we know about. When
adding a new item, cross-check EACH line. Missing one is the typical
silent failure mode.

| # | File / anchor | Purpose |
|---|---|---|
| 1 | `items.py` `ITEM_TYPES` (~1236) | Master registry |
| 2 | `items.py` `unlocked_items` (~2048) | Unlock flag default |
| 3 | `items.py` `[name]_obtained` module flags (~1991–2042) | Per-item first-acquire flag |
| 4 | `items.py` `update_items()` passive branch (~2741) | Passive routing |
| 5 | `items.py` `spawn_random_item()` `passive_names` (~2510) | Passive drop weighting |
| 6 | `items.py` `spawn_random_item()` `legendary_names` (~2493) | Legendary drop weighting |
| 7 | `items.py` `spawn_random_item()` dedup block (~2477) | Stop respawning already-obtained items |
| 8 | `items.py` `PASSIVE_DUPLICATE_ALLOWED` set (~2143) | Allow farming duplicates |
| 9 | `pingfighter.py` `store_active_item()` passive-filter (~89600) | Keep passives / legendaries out of active slot |
| 10 | `pingfighter.py` `store_passive_item()` elif chain (~90081–90752) | Per-item equip / activate branch |
| 11 | `pingfighter.py` `sync_equipped_passive_effects()` (~33362) | Roll / polish / enhancement sync on equip |
| 12 | `pingfighter.py` `show_item_obtained_effect()` (~96507) | Acquisition animation |
| 13 | `pingfighter.py` `PASSIVE_SLOT_ORDER` (~143151) | Body-part slot mapping |
| 14 | `pingfighter.py` primary developer-mode `all_items` (~143285) | Dev mode 2-key menu item list (SEPARATE from `PASSIVE_SLOT_ORDER`; secondary character/item manager is `ITEM_TYPES`-generated) |
| 15 | `pingfighter.py` equip-visual dispatch (~34088–34092) | `_VISUAL_ITEM_NAMES` pass on the player skin |
| 16 | `pingfighter.py` `get_item_icon()` legendary name list | HUD icon render for legendaries |
| 17 | `pingfighter.py` legendary `sync_bool()` calls | Legendary obtained-flag reset |
| 18 | `legendary_items.py` class definition | Legendary implementation |
| 19 | `legendary_items.py` `LEGENDARY_ROLL_OPTIONS` (~70) | Roll options |
| 20 | `legendary_items.py` `LegendaryItemManager._init_legendary_items()` (~13035) | Instance registration |
| 21 | `legendary_items.py` Pandora `passive_names` (~11623) | Exclude passive / legendary from Pandora's active roulette |
| 22 | `legendary_items.py` `get_legendary_roll_value()` (~116) kwargs | `apply_polish=True` + `enhancement_bonus_pct` |
| 23 | `entities/body_parts/item_parts_registry.py` `VISUAL_ITEM_NAMES` | Equip-visual whitelist |
| 24 | `gacha.py` active pool | Gacha sellable actives |
| 25 | `gacha.py` passive pool (`PASSIVE_ITEM_NAMES`, ~225) | Gacha sellable passives |
| 26 | `gacha.py` legendary pool (~328) | Gacha sellable legendaries |
| 27 | `pingfighter.py` stage-clear gacha candidate builder (`available_items.append(...)`) | Actual post-stage reward candidates and one-time gating |
| 28 | `downtown/building_interior.py` shop active list (~3823) | Shop actives |
| 29 | `downtown/building_interior.py` shop passive / legendary list (~3859) | Shop passives + legendaries |
| 30 | `downtown/building_interior.py` crane capsule pool (~3917) | Crane game items |
| 31 | `downtown/constants.py` `LEGENDARY_ITEM_NAMES` (~552) | Shop legendary tag |
| 32 | `item_state_manager.reset_runtime_items()` (~10) | Reset on death / main menu return |

Use this table as the scan list before shipping a new item. If you
added a hardcoded list not present here, add it to this table in the
same PR.

---

## 7. Character-transformation / revival items — extra checklist

Godot-first note:
- For current work, transformation / revival items must release or restore
  Godot character runtime owners, skill-orb metadata, animation state, FX
  hosts, audio loops, and reset paths.
- Python callsites in this section are legacy reference examples for timing
  and edge detection only.

Use this whenever the item replaces or gates the player's character
kit on activation. Current cases in the repo:

- **Yachaman Soul** — passive, revival on score loss, transforms
  into Yachaman form.
- **Odin's Eye** — legendary, revival on score loss, transforms into
  Odin-empowered form.
- **Horn Strawberry Mask** — passive, gauge-triggered transform into
  Strawberry form. Auto-fires the moment `special_gauge` reaches the
  500 cost (no command input). Stage-once gating still flows through
  `_used_this_stage`, and the `TRANSFORM_EVENT -> TRANSFORMED` finalize
  edge is unchanged. `try_transform()` now also gates on
  `state == IDLE`, so the per-frame call is safe even mid-transform.

Shared failure mode: the transform gates the original character's
skill-update block off, so any in-air Viper state that depended on
the jetpack update no longer progresses. Concretely,
`_viper_jetpack_offset_y` stays negative while the block that writes
`PLAYER.bottom = baseline + offset` at
`pingfighter.py:~83498` no longer runs, so a Viper who was
mid-jetpack at transform time ends up walking in mid-air as the new
form. The bug repeats across every character transform until the
landing step below is added.

### 7.1. Detect the exact finalize frame

Each transform has a different finalize edge. Find and pick the
right one for the new item:

- [ ] **Revival-with-animation transforms** (Yachaman Soul, Odin's
      Eye): the animation-done branch inside the per-frame
      animation-update block. Examples:
      `if animation_complete:` after
      `odins_eye.update_revival_animation()`, and
      `if anim_done:` after `item_effects.yachaman_soul.update_animation()`.
- [ ] **Gauge-triggered transforms** (Horn Strawberry Mask):
      the `TRANSFORM_EVENT -> TRANSFORMED` state edge, detected
      inside `update_horn_strawberry_transform()` by saving
      `was_transformed = ts.is_transformed` before `ts.update(dt)`
      and testing `ts.is_transformed and not was_transformed` right
      after. Do NOT key the fix off `is_event_playing` — the event
      phase ends BEFORE `is_transformed` flips. The trigger itself
      is now `try_transform()` called every frame; it is gated by
      `_used_this_stage` and `state == IDLE` so the per-frame call
      is a safe no-op once a transform is already in progress.
- [ ] **Any new transform pattern**: identify the single frame on
      which the character gates (`is_*_transformed()` /
      `_viper_original_skills_blocked`) flip from False to True,
      and fix at that frame. Do not assume the cinematic start is
      the right frame — the gating often flips only at the END.

### 7.2. On finalize — force the paddle to land

- [ ] If `selected_character_type == "viper"`, call
      `_reset_viper_jetpack_state()` to clear `_viper_jetpack_active`,
      `_viper_jetpack_offset_y`, `_viper_jetpack_hold_timer`,
      `_viper_jetpack_overheat`, `_viper_jetpack_particles`, and the
      looped `_viper_jetpack_snd_channel`. This is a no-op if the
      player was on the floor.
- [ ] Immediately after, call `apply_equipment_paddle_modifiers()`
      so `PLAYER.bottom` snaps to the floor baseline using the
      transformed form's effective scale. That function already
      reads `yachaman_active` for the 0.7x multiplier; the current
      reset pattern relies on this single call instead of hand-
      recomputing the baseline.
- [ ] If the transform also repositions the ball (for example
      `BALL.centery = PLAYER.top - 20` after revival), run the
      landing reset BEFORE the ball reposition. Otherwise the ball
      is placed above the frozen-in-air paddle.
- [ ] Do NOT call the fix every frame while transformed — call it
      exactly once on the finalize edge. Calling it per frame can
      override legitimate in-transform movement systems (for
      example Yachaman's bomb-spin dash applies `PLAYER.x +=`).

#### 7.2.1. Godot round-reset `player_y` must be the floor baseline, not live `player_pos.y`

In the Godot port the finalize landing is achieved by **reusing
`reset_ball`** (`battle_scene_ball_update_driver.reset_ball` →
`ball_round_cleanup.reset_for_ball_reset` →
`actor_cleanup.reset_actor_round_state` → `viper_jetpack_state.reset_round()`
clears `offset_y`, and `ball_round_controller` writes `player_pos.y =
config.player_y`). For this to actually LAND the paddle,
`ball_update_context.build_reset_config` must derive `player_y` from the
**floor baseline** (`field height − player_paddle_height`), **NOT** from the
live (possibly airborne) `player_pos.y`.

- The "read live `player_pos.y` into the reset config" form is a **latent
  float trap**: a Viper that revives mid-jetpack keeps its airborne y across
  the reset even after `offset_y` is cleared.
- **Why it normally hides:** in ordinary play the per-frame paddle-position
  writer (Viper jetpack `update()` → `next_pos.y = floor + offset_y`)
  re-corrects `player_pos.y` to the floor on the next frame, masking the bug.
  A transform/penalty that **gates that writer off** (`is_*_skills_locked` /
  `is_*_transformed`) removes the corrector, so the preserved airborne y
  survives and the paddle floats — this is the §7.2 family ("the corrector
  is gated off").
- **Rule:** any round-reset config that feeds paddle Y must source it from the
  baseline, and any new airborne mechanic (jetpack, dash-lift, hover) must
  verify a finalize/reset while airborne lands the paddle.
- Reference fix: `ball_update_context.build_reset_config` deriving
  `player_y = height − player_paddle_height`. Reference smoke (real
  `reset_ball` + `ViperJetpackState`, asserts `offset_y==0` and
  `player_pos.y == floor`): `odins_eye_finalize_paddle_land_smoke.gd`.

### 7.3. Reverse / detransform paths

- [ ] If the transform is reversible (for example Yachaman's
      `on_defeat_in_yachaman()` clears `yachaman_active`), confirm
      the reverse path does NOT need to restore a stale jetpack
      offset. Because §7.2 resets the jetpack to 0 on entry, the
      reverse path can trust that the offset is already neutral and
      can let the normal Viper jetpack block resume from zero on
      the next frame.
- [ ] If the reverse path has its own reset frame (for example a
      round boundary or a detransform animation-complete edge),
      confirm it does NOT re-introduce a stale offset by copying an
      older cached value. Read the offset fresh from its live
      global, not from a snapshot taken before the transform.

### 7.4. Legacy Python finalize-detect callsites

| Item | Finalize-detect location | Fix location |
|---|---|---|
| Yachaman Soul | `pingfighter.py` `if anim_done:` branch inside the `if yachaman_revival_anim_active:` block | same branch |
| Odin's Eye | `pingfighter.py` `if animation_complete:` branch after `odins_eye.update_revival_animation()` | same branch |
| Horn Strawberry Mask | `pingfighter.py` `update_horn_strawberry_transform()` — the `was_transformed` / `ts.is_transformed` edge right after `ts.update(dt)` | same edge |

If you add a new character-transformation item, add a row here in
the same PR with the finalize-detect location.

### 7.5. Transformed skill-orb tooltip previews

- [ ] If the transform exposes a temporary skill-orb kit, audit the
      tooltip path too. Do not stop at gameplay wiring.
- [ ] If the transformed skill tooltip shows an `이펙트 미리보기`
      panel, every new `effect_type` used by that transform must have
      a matching branch in `_draw_skill_effect_preview()`. Do NOT ship
      a transformed skill with a preview box that stays empty.
- [ ] The preview scene must stay panel-local: use the shared clipped
      preview path so particles / trails / blasts cannot leak outside
      the preview box and cover tooltip text.
- [ ] Treat transformed-item preview scenes like character-skill
      previews for quality parity. A placeholder circle or generic
      particle cloud is not enough if the tooltip is supposed to show
      a recognizable charge / barrier / throw / summon scene.

### 7.6. Cross-reference

Character-transformation perks / skills (as opposed to items) that
flip the same character-gate predicates should also follow this
rule. See `docs/character_skill_perk_checklist.md` §7 (Persistence
and lifecycle) for the cross-link.

### 7.7. Chained revival transforms must release the prior form

When more than one revival transform can be equipped at the same
time (currently Yachaman Soul + Odin's Eye, where Odin's Eye revival
is rolled first and Yachaman is rolled after), the order-of-check
means Odin's Eye can take over while a Yachaman transform is still
active. The shared failure mode: Odin's Eye's revival-success path
returns before the Yachaman block runs, so `yachaman_active` and
bomb-spin visuals are never cleared. When the Odin's Eye form then
dies, only `odins_eye.reset_for_new_round()` fires in the
death-animation-complete block, leaving `yachaman_active=True`.
The next round renders the player as Yachaman again, and it takes
an additional death (as the lingering Yachaman) to finally clear
the transform via `on_defeat_in_yachaman()`.

Checklist for any revival transform that can be chained behind
another revival transform:

- [ ] **On successful takeover**, clear the prior transform's
      active flag AND its visual state (for Yachaman:
      `yachaman_active = False` and `reset_bomb_spin()`), inline
      immediately after the new transform's `start_*_animation()`
      call and BEFORE the `return`. Do NOT rely on the prior
      transform's `reset_for_new_round()` to run on this path — it
      is skipped because the revival block returns early.
- [ ] **In the terminal revival's death-animation-complete block**,
      also call the prior transform's `reset_for_new_round()`
      (e.g. `item_effects.yachaman_soul.reset_for_new_round()`)
      alongside `terminal_item.reset_for_new_round()`. This ensures
      `*_used_this_round` flags are cleanly re-initialized for the
      next round, matching the regular-defeat cleanup that normally
      runs at the end of the loss handler but is skipped on the
      death-anim path.
- [ ] Audit BOTH the regular-mode and deuce-mode revival branches —
      they are duplicated blocks. A fix in only one leaves the bug
      alive in the other.
- [ ] Do NOT reset the prior transform's `*_used_this_round` flag
      at takeover time. Keeping it True preserves the semantic that
      the prior revival has been consumed within the current life;
      round-transition code will reset it cleanly later.

If a new revival transform is added, update the
"chained-revival takeover" matrix below in the same PR:

| Prior form | Terminal form | Takeover clear site | Death-anim cleanup site |
|---|---|---|---|
| Yachaman Soul | Odin's Eye | `pingfighter.py` Odin's Eye revival-success branch (regular + deuce) — inline after `odins_eye.start_revival_animation()` | `pingfighter.py` Odin's Eye death-animation `if death_anim_complete:` branch, alongside `odins_eye.reset_for_new_round()` |

### 7.8. Command-triggered transforms — round / stage / menu boundary policy matrix

Command-triggered transforms (Horn Strawberry Mask `A→D→A→D→A→D` is the
current Godot reference; future Yachaman / Odin's Eye Godot ports will
share the same architecture) need an **explicit five-way boundary
policy** because the original Python code does NOT define one in any
single `reset_*` callsite. Python's `reset_round()` does not directly
touch the transform singleton, and `reset_stage_transform()` only
clears `_used_this_stage`. So the Godot port owns the policy decision,
and the policy must be locked in a smoke test rather than re-derived
from Python.

Per [[feedback_default_target_godot]] "포팅 예외" clause: this is one
of the cases where Python is "구현 타겟 아님 / 1차 참고 기준 / 의도적
분기는 기록" applies — record the boundary decision in code comments
AND a dedicated round-boundary smoke.

Required boundary matrix for any command-triggered transform item:

| Boundary event | Transform / cinematic state | Active-skill state | Lingering field / paint / projectiles | `used_this_stage` flag |
|---|---|---|---|---|
| `score_event` (point just lost / won) | KEEP — do not interrupt mid-event | KEEP | KEEP | KEEP |
| `serve_wait` → `on_round_start` (ball reset for next rally) | KEEP; TRANSFORM_EVENT / TRANSFORMED / DETRANSFORM_EVENT continue from remaining timers | KEEP active arming and skill cooldowns | KEEP detached lingerers (field barriers, paint splatters, in-flight bombs) | KEEP — same-stage transform stays spent |
| `round_restart` (deuce reset / debug restart) | KEEP | KEEP | KEEP | KEEP |
| `stage_advance` (next stage begins) | CLEAR | CLEAR | CLEAR all lingerers | CLEAR — next stage's transform is unlocked |
| `main_menu_reset` / `game_reset` | CLEAR | CLEAR | CLEAR | CLEAR |

Implementation contract:

- [ ] State machine MUST expose at least three named reset methods:
      `reset_round()` (keep `used_this_stage` and preserve the active
      transform kit across the next serve), `on_stage_advance()` (clear
      `used_this_stage` AND all lingerers), and `reset_all()` (full
      clear including `used_this_stage`).
- [ ] Mythic runtime MUST expose a parallel triplet that also tears
      down per-skill detached state with the right preservation policy.
      Horn Strawberry's round boundary is intentionally no-op for the
      transformed kit; `_reset_detransform_skill_state()` is only for
      natural transform expiry / detransform cleanup, and
      `_reset_all_skill_state()` is for stage / menu boundary.
- [ ] `score_event` MUST NOT call `reset_round()` directly — it
      should let scoreboard → serve_wait → ball reset →
      `on_round_start` carry the transform into the round-start
      boundary. A score handler that calls `reset_round()` directly
      will tear down a mid-cinematic transform before the player
      sees the result screen.
- [ ] `on_round_start` MUST be the single round-boundary entry point.
      Group it next to other round-start hooks (e.g.
      `adversity_armor_runtime.on_round_start`) for discoverability.
- [ ] A `*_round_boundary_smoke.gd` MUST lock all five boundaries
      with `_expect` assertions. Reference:
      `godot/tests/horn_strawberry_round_boundary_smoke.gd`. The
      smoke must cover both TRANSFORM_EVENT and TRANSFORMED loss
      paths separately, because both states must survive the serve
      boundary with owner-sync flags intact.
- [ ] The "preserve transform + lingerers across round" decision MUST be
      documented inline at the `reset_round()` callsite as an
      intentional divergence (e.g.
      `# Round boundaries keep the command transform alive; stage
      advance and full reset still clear transform + lingerers.`).
      Future Yachaman / Odin's Eye ports must inherit or explicitly
      override this comment.

Cross-link: revival transforms (Yachaman Soul, Odin's Eye when
ported) follow §7.7 chained-revival rules ON TOP OF this boundary
matrix — `_used_this_stage` semantics still apply per revival, and
the boundary matrix decides when detached lingerers (revival auras,
sustained transform VFX) are released.

---

## 7B. Items that absorb / consume an external runtime effect

Godot-first note:
- For current work, kill the consumed source through the Godot owner module
  on the same frame the absorb cinematic begins, then verify the detached FX
  host / loop audio / persistent terrain cleanup path directly.
- Python examples below describe the reference failure pattern.

When a passive or legendary item is described as "absorbing", "stealing",
"consuming", or "neutralizing" some other live runtime effect — weather
events, boss skills, hazards, projectiles, terrain, or another item's
particles — the absorb cinematic must KILL the underlying source state
on the same frame the cinematic starts, not at the end. Otherwise the
real effect keeps running underneath the absorb visual and the player
sees both effects simultaneously, making the absorb look like a parallel
fake decoration.

Canonical failure case: Baal's Boots (`item_effects/baal_boots.py`).
The first cut of `_begin_absorb()` only kicked off `_spawn_absorb_particles`
and deferred `_end_weather_event()` to `_finish_absorb()`. During the
3-second cinematic the real rain / fire / sand stayed on screen
underneath the absorb stream. Fix: `_end_weather_event()` (and any
sand-wall dissolve) must happen at `_begin_absorb()` AFTER harvesting
particle positions, BEFORE returning.

Required pattern for any future absorb / consume item:

1. **Capture the real effect's per-particle visual identity first** —
   walk the source's live particle / projectile / terrain lists and
   record `(x, y, size, color)` into the absorb stream so the sucked-in
   particles read as the actual effect being lifted off the arena, not
   freshly randomized fakes that happen to share the theme color.
2. **Immediately call the source's "force end" path** in the same
   function — for weather that is `weather_event.force_end_weather_event()`
   plus an explicit `.clear()` on every per-type particle source list
   that doesn't auto-wipe behind the active gate. For boss skills, that
   means the same reset call the boss-end / score-loss handler uses
   (also see `CLAUDE.md` boss-skill cleanup invariant).
3. **Persistent terrain (sand walls, ice patches, dirt mounds) must
   be zeroed on the same frame too.** A dust / ember stream rising off
   a still-standing wall reads as the absorb being a parallel effect.
   Provide a `_dissolve_*` helper that walks the terrain object and
   sets its depth / amount fields to zero with `_dirty = True`, then
   call it from the begin path.
4. **Finish path is defensive only.** `_finish_absorb()` may re-call
   the same source-end helpers as a safety net for the case where
   another system re-armed the effect during the cinematic, but it
   must NOT be the only place the kill happens.
5. **Audit `reset_round_effects()` and reset-on-death so the absorb
   item can re-arm cleanly next round.** The item's own `pending`,
   `cinematic_active`, `round_effect_active`, and theme-particle lists
   must reset; the underlying source (weather / boss skill state)
   resets through its own normal lifecycle and should not be touched
   from the absorb item's reset path.

Smoke-test pattern (headless): force-start the consumed effect, prepop
the source's particle list, call `_begin_absorb(type)`, then assert:

- Source `is_active()` returns `False`
- Source's per-type particle list is empty
- The absorb stream's particle count > 0
- Persistent terrain (if any) has zeroed depth fields

`.tmp/baal_boots_v2/test_absorb_kills_weather.py` and
`.tmp/baal_boots_v2/test_sand_dissolve.py` are working references for
this pattern.

---

## 8. Smoke test before shipping

Godot-first note:
- For current work, run the repo-local Godot load check and warning scan
  after `.gd` edits, plus focused Godot smoke or visible review for the
  touched item family.
- Python-specific checks in this list are legacy behavior references unless
  the user explicitly requested original PingFighter source work.

For every new item, run this manual QA pass:

1. Developer mode (press `2` on main menu) — the item appears in its
   correct tab (active / passive / legendary) with the right icon.
2. Spawn the item directly via developer mode — acquisition animation
   fires; inventory / character-info UI shows the item in the correct
   slot with the correct icon, name, and description.
3. Field drop — the item spawns on the field at the expected rate,
   pickup animation fires, inventory state matches dev-mode pickup.
4. For passive: the item auto-equips into the correct body-part slot
   if that slot is empty; stat change is visible in-game; unequipping
   the item removes the effect again.
5. For passive with equip visual: the character paddle shows the
   equip overlay after pickup.
6. For duplicate-allowed passive / legendary: second pickup appears
   in inventory with a new roll; does not silently disappear.
7. Roll options / polish perk / enhancement buff — confirm the
   displayed number matches the number the engine reads at the stat
   consumption point (not only at display time).
8. Gacha pull — the item can be rolled.
9. Shop — the item is purchasable at the intended peer-tier price.
10. Crane — the item can be caught.
11. Treasure hunt perk — the item's drop rate responds to
    `downtown_treasure_map` level.
- Additional multi-effect perk check:
    verify the `Lv.6+` description / tooltip still lists every effect
    lane and matches live gameplay values.
12. Die mid-run or return to main menu — the item is cleared from
    inventory; next run starts fresh; `[item_name]_obtained` is
    reset; equip-visual overlay is removed.
13. For legendary — confirm it does NOT appear in Pandora Legacy's
    active-item roulette (it should be in the `passive_names`
    exclusion set in `legendary_items.py`).

14. If the item transforms the player and exposes temporary skill
    orbs: hover every transformed skill tooltip and confirm the
    preview panel is populated, clipped to the panel, and semantically
    matches the real skill.

15. For Godot item VFX: confirm active, passive, legendary, and mythic
    item effects follow Section 0.1A or have a documented exception.
    Live-check at least one use / equip / proc / impact / expire or
    reset path in a scaled/windowed layout, and verify audio / hitstop /
    shake / cleanup timing stays synced with the Python reference.

CC-immunity addendum:
- If the item has CC immunity / block / negate behavior, hit a normal
  ball with the paddle several times and confirm **no** proc, gauge
  spend, sound, or VFX occurs from ordinary self-recoil / paddle-hit
  feedback unless that behavior is explicitly intended.
- Trigger a real hostile stun / knockback source and confirm the proc,
  gauge spend, sound, and VFX happen at the real gameplay hook.
- If one hostile source applies both stun and knockback together,
  confirm the intended single-vs-double spend behavior explicitly.
- If the immunity is whitelist-based rather than universal, test both
  sides in live play: confirm at least one intended hostile source is
  blocked and at least one explicitly excluded source (weather / event
  hazard, non-boss environment effect, ordinary ball path, etc.) still
  behaves normally.

Any failure = back to the checklist.
