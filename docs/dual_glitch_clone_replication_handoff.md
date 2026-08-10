# Dual Glitch Clone Skill Replication Port Reference

Current product: Godot **환격전**. The English title is undecided; legacy names
in this port reference are compatibility/provenance identifiers.

Second-iteration expansion of `four_poisons` (`사독`). Upgrades Lv.5
from a pure numeric capstone to a gameplay breakpoint by letting
`dual_glitch` clones replicate a narrow whitelist of Viper projectile /
strike skills while the clone is in its active phase.

This doc assumes the first pass of `사독` has already landed or is being
mapped from `docs/four_poisons_handoff.md`.

Companion references:

- `docs/four_poisons_handoff.md`
  parent family-perk spec
- `docs/character_skill_perk_checklist.md`
  Character runtime perk / skill integration source of truth
- `docs/character_skill_perk_checklist.md`
  reward/double-pay, hit-primitive, and cooldown HUD-sync owner rules

The original anchors below were captured from the frozen Python/Pygame
PingFighter runtime. Treat them as parity references only. For current work,
map them to the Godot Viper / skill / clone owner modules and do not edit
`pingfighter.py` unless the user explicitly asks for original source work.

Legacy Python code anchors (snapshot; audit Godot owners before
implementation):

- `_viper_dual_glitch_state`, `_viper_dual_glitch_clones` near
  `pingfighter.py:5097+`
- `_teardown_dual_glitch_runtime_state()` near `pingfighter.py:5778`
- `_start_viper_dual_glitch()` / `_update_viper_dual_glitch_runtime()`
  near `pingfighter.py:5858` / `5899`
- Viper `blade_rush` / `dark_blade` / `dive_strike` cast paths
- `_is_four_poisons_super_armor_active()` (first-pass helper pattern
  the new gate helper should mirror)
- `get_runtime_skill_level()` at `pingfighter.py:20347`
  (effective level source, includes Ignition Aura, Transcendent Crown,
  Sage Ring)

---

## 1. Goals / Non-goals

### 1.1. Goals

- Make `사독` Lv.5 feel like a true capstone, not just "-20% cooldown"
- Add a narrow, visually legible "burst window" to `dual_glitch`
- Preserve the current `dual_glitch` identity (passive presence + rally
  pressure) at Lv.0-4 — clone replication is an opt-in late-game bonus
- Strictly cap the power ceiling:
  clones expand spatial coverage and visual fanfare,
  not raw output

### 1.2. Non-goals

- Not a full "mirror image" system — clones do not duplicate every
  Viper skill
- Not a gauge / cooldown multiplier — clones do not consume resources
- Not an economy multiplier — clones do not generate extra gold rewards
- Not a stacking power amp — strong effects apply once per cast even
  when several clones also fire
- Not a redesign of `dual_glitch` baseline behavior — the skill still
  starts up, spawns, actives, and fades the same way

---

## 2. Unlock Condition

Clone replication activates exactly when both are true:

- `get_runtime_skill_level("four_poisons") >= 5`
  (effective level — includes Ignition Aura, Transcendent Crown, Sage
  Ring, and any other active perk-level booster)
- `_viper_dual_glitch_state == "active"`
  (not `idle`, not `startup`, not `spawn`, not `fade`)

Rationale:

- Gating on effective level matches the `사독` Lv.3 super-armor
  decision: advanced synergy with Ignition Aura is intentional.
  Raw `사독` Lv.3 + Ignition Aura = effective Lv.5 during the aura
  window, granting a temporary replication window.
- Gating on `state == "active"` ensures the clone is a legible collision
  combatant before it can cast. Startup / spawn / fade windows are
  inactive by design so clone replication cannot fire from a clone that
  is still materializing or dissolving.

---

## 3. Replication Scope

### 3.1. Replicated skills (4 skills)

- `blade_rush` / 에어 블레이드
- `dark_blade` / 다크 블레이드
- `dive_strike` / EMP 스트라이크

- `nerve_strike` / clone-side venom slash
These are all skills that can be mirrored from the clone's current
position without expanding the replication whitelist into Viper's full
body-combo kit.

### 3.2. `nerve_strike` implementation note

- `nerve_strike` / 베놈 엣지

Primary `nerve_strike` keeps its full player-body teleport / freeze-cut
identity. Clone replication does **not** move the clone body behind the
boss. Instead:

- the player still performs the real boss-flank dash
- each living clone fires a delayed venom slash from its own position
- the clone slash lightly tracks the boss during travel and resolves as
  a ranged venom cut on arrival

This preserves clone lane coverage and avoids yanking collision-capable
clones off the board just to replay a body-teleport animation.

### 3.3. Permanent exclusions

- Kick family:
  `marshal_kick`, `phantom_kick`, `core_flip`
  Kicks are the core Viper body combo identity; duplicating them
  dilutes the original skill's feel and breaks combo readability.
- `shadow_step`
  A clone-side blink destination is ambiguous; mobility skills should
  not be doubled.
- `chaos_spear`
  Lockdown field is too strong to duplicate; two concurrent lock zones
  break the skill's balance point.
- `ignition_aura`
  The ultimate buff perk; duplicating the buff field breaks the
  "one meta stack per caster" invariant and cascades power.

---

## 4. Non-Negotiable Guards

These are hard design rules. Do not relax any of them without an
explicit second-round design pass.

### 4.1. Resource guards

- **No extra gauge cost.**
  Clone cast piggybacks on the player's single cast.
- **No extra cooldown.**
  Clone cast does not extend the skill's cooldown. The skill triggers
  cooldown once from the player cast.
- **No extra gold.**
  Clone-originated hits do not generate rally gold, skill gold, or any
  other gold reward. Only the primary caster's hits pay gold.
  Cross-reference `character_skill_perk_checklist.md` §6 and its
  smoke-test matrix for the no-double-pay contract.

### 4.2. Effect guards — strong effects apply once per cast

Even though a clone fires an identical projectile, gameplay-meaningful
effects do not stack per clone. A "cast" is the player's original
triggering event; all clone projectiles belong to the same cast.

- **Damage / attack speed / hit counts**
  Clone hit does not add a separate damage instance once the cast's
  primary hit has landed.
- **CC effects**
  Venom confusion duration, EMP sleep duration, etc. are fixed per cast,
  not per clone.
- **Skill-proc hooks**
  shadow-backstep trigger, jetpack reset, core-flip window, dark-blade
  empowerment-window consume: fire once per cast, not per clone hit.

### 4.3. Consequence

Clones increase the **spatial coverage** and **visual fanfare** of a
skill. They do not increase its raw output.

---

## 5. Per-Skill Replication Behavior

### 5.1. `blade_rush` (에어 블레이드)

- Each active clone fires one additional blade from its own position
- Projectile vector matches the primary cast's vector
- Blade speed, damage-per-hit, and lifetime are unchanged
- Strong-effect guard:
  if both the primary blade and a clone blade land in overlapping
  frames, damage resolves once for the cast

### 5.2. `dark_blade` (다크 블레이드)

- Same structure as `blade_rush` — each clone fires one additional
  dark blade
- Range and width scaling inherited from `dark_blade`'s base spec
  applies to clone-fired blades identically
- Dark-blade empowerment window consume rule:
  the window is consumed once per cast, not per clone hit

### 5.3. `dive_strike` (EMP 스트라이크)

EMP differs from `blade_rush` / `dark_blade` on two axes: dives all
land at the floor Y (simultaneous same-Y landings add no spatial
coverage), and dives produce a single impact moment (not a projectile
that travels). To make clone replication meaningful for EMP, the
dives are **staggered in time** and effects are allowed to **refresh**
per clone hit.

Order and timing:

- t=0.0s: player dives at the player's current X (center)
- t=`+STAGGER` (1 × STAGGER): left clone dives from its snapshot X
- t=`+2×STAGGER` (2 × STAGGER): right clone dives from its snapshot X

Default `STAGGER` = 200 ms, so the full sequence spans 0.4s.

Pre-dive charge telegraph:

- ~0.1s before a clone's dive, draw a short "charging glitch" tell
  (pixel shear + micro RGB split) on that clone so the player can
  anticipate each dive in the sequence

Effect guard for EMP (exception to the §4.2 general rule):

- Each dive that lands a hit applies its CC / boost **as a refresh**,
  not as an additive stack
- Sleep: `boss_sleep_end_time_ms = max(existing_end, now_ms + base_ms)`
- Ball boost: subsequent hits **reset** ball velocity to the boosted
  baseline — they do not re-accelerate on top of a boosted velocity
- Effect is `max()`-style refresh so stacked hits never exceed the
  single-hit max effect magnitude, only the remaining-duration window

Why EMP is a §4.2 exception:

- Without refresh, clone dives at the floor + simultaneous landing add
  no practical value because all three impacts resolve as the same
  "floor shockwave at one Y" in the same frame
- With stagger + refresh, EMP gains two legitimate value axes:
  temporal re-hit chances (0.4s window) and up to ~33% longer effective
  sleep in best-case all-three-hit cases
- The refresh ceiling (`base_ms` max, never accumulating) keeps the
  power bump subtle rather than transformative

### 5.4. `nerve_strike` (베놈 엣지)

`nerve_strike` is an assassin-style body skill for the player, so clone
replication uses a proxy attack instead of teleporting the clone body.

Order and timing:

- t=0.0s: player performs the normal boss-flank dash / slash
- t=`+STAGGER` (1 x STAGGER): left clone fires a venom slash
- t=`+2xSTAGGER` (2 x STAGGER): right clone fires a venom slash

Default `STAGGER` = 200 ms, matching the EMP stagger rhythm.

Clone-side implementation:

- the clone stays in place
- a short glitch tell appears on the clone before launch
- the slash travels from the clone toward the boss with light tracking
- on arrival it produces clone-only slash visuals and can resolve the
  cast's confusion if the primary hit did not already do so

Effect guard:

- Venom confusion remains **once per cast**
- player hit or the first successful clone hit can apply confusion
- later clone hits from the same `cast_id` are visual only
- clone hits do not grant gold, do not spawn extra freeze-cut scenes,
  and do not move the actual clone body off-lane

---

## 6. Implementation Plan

### 6.1. Gate helper

Add:

- `_is_dual_glitch_clone_replication_active()`

Behavior:

- returns `True` iff
  `get_runtime_skill_level("four_poisons") >= 5` AND
  `_viper_dual_glitch_state == "active"`

Use this helper from every replicated-skill cast path. Do not inline
the condition.

### 6.2. Per-skill cast hook

For each of `blade_rush`, `dark_blade`, `dive_strike`, `nerve_strike`:

- At the moment the primary cast spawns its projectile / effect, also
  spawn one additional instance per active clone in
  `_viper_dual_glitch_clones`
- Tag clone-originated projectiles with a source marker so effect
  guards (§4.2) can resolve correctly
  (recommended:
  `source = "dual_glitch_clone"` plus a shared `cast_id`)
- Position the clone spawn at the clone's current rect; vector / angle
  mirrors the primary cast

### 6.3. Effect guards implementation

Introduce a per-cast id so that:

- Damage ticks, CC applications, and skill-proc hooks check whether
  this `cast_id` has already resolved its effect
- First hit from any source (primary or clone) belonging to a cast
  registers the effect
- Subsequent hits from the same `cast_id` still produce hit visuals
  and sound but do not re-apply damage / CC / proc

### 6.4. Teardown

`_teardown_dual_glitch_runtime_state()` already cleans up clone state.
Verify no leaked `cast_id` trackers linger after teardown, and that no
in-flight clone projectile references a clone rect that has been
cleared.

### 6.5. Save / load

- `runtime_skill_levels["four_poisons"]` is already save-persisted by
  the first pass
- Clone replication is derived at runtime, so no new save keys are
  required
- If any `cast_id` bookkeeping uses a monotonically increasing counter,
  reset the counter on new game / main-menu return

---

## 7. Visual / Feedback

- Clone-originated projectiles should read as clearly belonging to the
  clone (color tint, translucency, or size bias) so the player can
  distinguish primary from clone fire
- Do not add extra camera shake or hit stop for clone hits — duplicated
  impact feel would effectively stack the cast and violate §4.2
- No new HUD toggle / meter. Clone replication is not a separate
  player-facing perk

---

## 8. QA Checklist

### 8.1. Gate QA

- Clone replication does not fire at raw `사독` Lv.0-4 without aura
- Clone replication fires at raw `사독` Lv.5
  (effective >= 5 is permanent)
- Clone replication fires at raw `사독` Lv.3 + active Ignition Aura
  (effective 5 during the aura window)
- Clone replication stops when Ignition Aura ends and effective level
  drops back below 5
- Clone replication does not fire during `dual_glitch` startup, spawn,
  or fade windows — only during the `active` state

### 8.2. Replicated skill QA

- `blade_rush`:
  player + N clones = `N+1` blades on screen with correct vectors
- `dark_blade`:
  clone blades respect the dark-blade empowerment window
  (no double-consume of the window per cast)
- `dive_strike`:
  clone dives impact visually but do not extend boss sleep duration
  beyond the primary cast's airtime-derived value
- `nerve_strike`:
  clone venom slashes launch in left/right stagger order and can cover a
  primary miss without paying extra gold or starting duplicate
  freeze-cut scenes

### 8.3. Resource guard QA

- Player gauge consumption is the same whether 0 clones or N clones
  are active
- Primary skill cooldown is unchanged by clone replication
- No extra gold is awarded from clone hits
  (rally gold, skill gold, or any other source)

### 8.4. Effect guard QA

- Damage dealt per cast does not scale with clone count
- Venom confusion / EMP sleep duration is fixed per cast, not per clone
- Skill-proc hooks (shadow backstep, jetpack reset, core flip window,
  dark-blade window consume) fire once per cast

### 8.5. Exclusion QA

- `marshal_kick` / `phantom_kick` / `core_flip` are not replicated
- `shadow_step` is not replicated
- `chaos_spear` is not replicated (no clone blackholes)
- `ignition_aura` is not replicated (no duplicated aura field)

### 8.6. Edge cases

- `dual_glitch` teardown during a primary cast's mid-flight projectile
  leaves no orphaned clone projectiles
- Player transform (Horn Strawberry / Yachaman Soul / Odin's Eye)
  during active replication cleanly disables clone replication for the
  duration of the transform
- Round end / death resets replication state cleanly
- Save / load during active replication is benign — no persistent state
  to lose

---

## 9. Recommended Implementation Order

1. Gate helper `_is_dual_glitch_clone_replication_active()`
2. Effect-guard infrastructure (per-cast id system)
3. `blade_rush` replication (simplest projectile)
4. `dark_blade` replication
5. `dive_strike` replication
6. `nerve_strike` replication
7. Full QA pass
8. Ship

Each replicated skill exercises its own slice of the effect-guard
surface; isolating them makes bugs bisectable even when the final
capstone supports all four skills.

---

## 10. Related: Clone HP / Durability System

Defensive-axis companion. Clone replication is offensive; clone
durability governs how long clones survive to keep firing replicated
projectiles. Both are `dual_glitch` extensions but live on different
balance axes, so they are specified and tuned independently.

Key interaction this doc acknowledges but does not own:

- At skill cast time, the replication count equals the number of
  clones with `HP > 0` at that instant
- A clone in mid-evaporation animation does NOT count as a replication
  source
- Zero live clones = zero replicated projectiles, even at `사독` Lv.5

Full HP curve, visual states (healthy / wounded / evaporating),
collision + HP decrement order, active-termination rules, and QA live
in:

- `docs/dual_glitch_clone_hp_handoff.md`

---

End of handoff.
