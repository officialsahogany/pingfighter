# Dual Glitch Clone HP / Durability Port Reference

Current product: Godot **환격전**. The English title is undecided; legacy names
in this port reference are compatibility/provenance identifiers.

Third-iteration extension of `dual_glitch` inside the `사독` family.
Gives each `dual_glitch` clone a finite HP pool so that a focused boss
can actually eliminate clones instead of watching them run out the
15-second active window untouched.

This is the **defensive axis** companion to the offensive clone
replication system. Clone replication scales output breadth; HP /
durability scales how long that output can keep firing.

Companion references:

- `docs/dual_glitch_clone_replication_handoff.md`
  clone replication spec (offensive axis)
- `docs/four_poisons_handoff.md`
  parent family-perk spec
- `docs/character_skill_perk_checklist.md`
  Character runtime perk / skill integration source of truth
- `CLAUDE.md`
  hidden-knowledge rules

The original anchors below were captured from the frozen Python/Pygame
PingFighter runtime. Treat them as parity references only. For current work,
map them to the Godot Viper / skill / clone owner modules and do not edit
`pingfighter.py` unless the user explicitly asks for original source work.

Legacy Python code anchors (snapshot; audit Godot owners before
implementation):

- `_viper_dual_glitch_state`, `_viper_dual_glitch_clones` near
  `pingfighter.py:5097+`
- `_teardown_dual_glitch_runtime_state()` near `pingfighter.py:5778`
- `_update_viper_dual_glitch_runtime()` near `pingfighter.py:5899`
- `_start_viper_dual_glitch()` near `pingfighter.py:5858`
- Viper clone <-> ball collision / rally-gold resolution path
  (existing baseline behavior this doc extends)
- `get_runtime_skill_level("four_poisons")` for effective-level read

---

## 1. Goals / Non-goals

### 1.1. Goals

- Balance `dual_glitch` by making clones destroyable via ball contact
- Create a meaningful defensive investment path on `사독` Lv.3 and Lv.5
- Preserve existing rally-bounce / rally-gold behavior while clones are
  alive
- Turn clone durability into a visible, readable combat element for
  both the player and the boss-side observer

### 1.2. Non-goals

- Not a redesign of the clone spawn / render / teardown pipeline
- Not coupled to offensive clone replication (separate doc owns that)
- Not a new perk — this is an inherent `dual_glitch` + `사독` rule
- Does not change `dual_glitch` gauge cost, base cooldown, or base
  15-second duration

---

## 2. HP Curve

HP is per clone. Each clone tracks its own counter at spawn time.

| 사독 Lv | Clone HP |
|---|---:|
| 0 | 2 |
| 1 | 2 |
| 2 | 2 |
| 3 | 3 |
| 4 | 3 |
| 5 | 4 |

Breakpoints:

- Lv.3 is a defensive breakpoint (2 -> 3 HP), aligned with the existing
  `사독` Lv.3 super-armor + cooldown reduction milestone
- Lv.5 is the final defensive breakpoint (3 -> 4 HP), paired with the
  Lv.5 clone replication offensive unlock
- Lv.4 is intentionally a "cooldown-only" tier for HP purposes — the
  HP curve stays flat to keep Lv.5 as the true capstone

HP source-of-truth rule:

- HP is assigned **at clone spawn** from current effective `사독` level
- Do not re-evaluate HP mid-life if effective level changes
  (for example, when Ignition Aura ends during an active window).
  Clones stay fragile or durable based on the level at spawn. This
  keeps per-cast HP expectations stable.

---

## 3. Visual States

Three-stage visual model. The same rule applies regardless of HP pool
size (2, 3, or 4).

- **HP > 1**: full opacity, healthy clone
- **HP == 1**: translucent / faded state with a purple / magenta
  ghosted tint (Viper perk theme)
- **HP == 0**: short evaporation animation — steam burst over ~0.2s,
  then the clone entity is removed from the game
- **Timer-out end**: if `dual_glitch` expires naturally while a clone is
  still alive, the clone should not use the HP-0 steam burst. Use a
  separate mirage / molecular glitch-dispel fade: RGB split, horizontal
  scanline shear, small pixel-block breakup, and upward / outward purple /
  magenta particle drift during the normal `fade` window

Transition rules:

- Transition to "faded" happens on the exact hit that leaves 1 HP
  (e.g., 2 -> 1, or 3 -> 2 -> 1, or 4 -> 3 -> 2 -> 1)
  Only the step into 1 HP triggers the visual change — no gradual fade
- Transition to "evaporating" happens the instant HP reaches 0
- Natural duration timeout transitions alive clones into the dedicated
  glitch-dispel fade, not the HP-0 steam animation
- During evaporation, clone collision is OFF (no more ball bounces)
- Evaporation animation is cosmetic — runtime state cleanup happens on
  animation **start**, not end, so nothing can reference a half-dead
  clone

---

## 4. Collision & HP Decrement Order

Exact per-frame rule when a ball hits a clone:

1. Ball bounces off the clone as if it were a paddle
   (existing baseline behavior — preserved)
2. Rally gold is awarded to the player
   (existing baseline behavior — preserved)
3. Clone HP is decremented by 1
4. If HP reached 0, flip the clone to "evaporating" state for the next
   frame. Collision is OFF on subsequent frames until the clone is
   removed.

Rationale:

- Bounce-first preserves the current feel — the player doesn't lose
  rally gold just because a clone was about to die
- HP decrement after bounce means a dying clone pays out on its final
  bounce but can't take any more hits
- State flip is deferred one frame so the current frame's bounce math
  and rally gold path don't need to re-read clone state

---

## 5. Clone Destruction & Active Termination

When all active clones reach HP 0 inside a `dual_glitch` active window:

- `_viper_dual_glitch_state` transitions from `active` to `fade`
  immediately (early termination), skipping any remaining duration
- Cooldown is charged normally — the skill "spent" its cycle even
  though the 15s window ended early
- Visual: the fade animation plays the same as a natural duration
  expiry; the player should not see a hard cut

Rationale:

- "Cleared by the boss" is a legitimate way to end the window
- Making cooldown still trigger avoids a cheap re-cast loop after
  getting clones wiped
- The `fade` state transition keeps existing teardown code paths intact

---

## 6. Interaction with Clone Replication

Replication behavior is unchanged in principle. The only interaction
this HP doc adds:

- At skill cast time, the replication count equals the number of
  clones with `HP > 0` at that instant
- If a clone is already in mid-evaporation (HP == 0) at cast time, it
  does NOT contribute a replicated projectile — it is already OFF for
  collision and should be OFF for replication too
- Clone HP is not consumed or otherwise affected by firing replicated
  projectiles — HP only decrements on ball contact

A clone that was alive at cast and evaporates after firing its
replicated projectile does not cancel that in-flight projectile. The
cast has already resolved its spawns.

---

## 7. Implementation Plan

### 7.1. Per-clone HP state

Extend each entry in `_viper_dual_glitch_clones` with:

- an `hp` integer field
- optionally an `evaporation_started_ms` timestamp for the death
  animation timeline
- a `collision_enabled` boolean (or equivalent gating) that flips OFF
  the instant HP hits 0

### 7.2. HP assignment at spawn

At clone spawn time, read effective `사독` level via
`get_runtime_skill_level("four_poisons")` and map to HP:

- 0-2 -> 2
- 3-4 -> 3
- 5+ -> 4

Keep this mapping in a dedicated helper so future balance passes only
touch one place.

### 7.3. Ball -> clone hit path

Extend the existing clone rect hit resolution:

- Run the current bounce + rally gold logic unchanged
- Decrement clone HP after the bounce
- If HP reaches 0, flip `collision_enabled` to False and record the
  evaporation start time

### 7.4. Active termination

In `_update_viper_dual_glitch_runtime()`:

- After the per-frame update, check if any clone still has `HP > 0`
- If no live clones remain, transition state from `active` to `fade`
  on the next tick
- Cooldown progression is untouched — it was already running

### 7.5. Teardown

`_teardown_dual_glitch_runtime_state()` already zeros out clone state.
Verify:

- `hp` fields are cleared
- `evaporation_started_ms` timers are cleared
- any new bookkeeping is cleared alongside existing state
- pending replicated projectiles that were spawned before teardown are
  not affected by teardown (they live on their own)

### 7.6. Rendering

- `HP > 1` clones render with existing sprite / opacity
- `HP == 1` clones render with translucent purple / magenta tint
- `HP == 0` clones render a short steam-burst evaporation animation,
  then are removed

---

## 8. QA Checklist

### 8.1. HP curve QA

- Raw `사독` Lv.0-2: 2 hits destroys a clone
- Raw `사독` Lv.3-4: 3 hits destroys a clone
- Raw `사독` Lv.5: 4 hits destroys a clone
- Raw Lv.2 + active Ignition Aura (effective Lv.4): clone spawned
  during aura has 3 HP; clone spawned after aura ends has 2 HP
- HP is snapshotted at spawn — a Lv.3 clone that existed before Aura
  ends does not lose a HP point when Aura expires

### 8.2. Visual state QA

- Transition to faded happens exactly on the hit that leaves 1 HP
- Transition to evaporating happens exactly on the fatal hit
- No clone renders at an opacity between faded and full — states are
  discrete
- Evaporation animation plays and completes cleanly; clone disappears
  after animation

### 8.3. Collision / gold QA

- Fatal hit still pays rally gold (bounce before HP--)
- After HP == 0, further ball-clone overlaps do nothing — the ball
  passes through or bounces off nothing
- HP is not affected by friendly fire, Viper's own projectiles, or
  any non-ball contact
- Clones cannot be destroyed by projectiles from other skills

### 8.4. Termination QA

- When all clones reach HP 0 mid-active, `dual_glitch` transitions to
  `fade` on the next tick
- Cooldown is charged the same as a natural 15s completion
- Player cannot re-cast `dual_glitch` until the normal cooldown
  elapses
- Fade animation plays as usual — no hard cut

### 8.5. Replication interaction QA

- At cast time, only clones with HP > 0 fire replicated projectiles
- A clone with HP == 0 at cast time contributes zero replicated
  projectiles, even if its evaporation animation is still playing
- A clone that evaporates AFTER firing its replicated projectile does
  not cancel that in-flight projectile
- Zero live clones = zero replicated projectiles, even at `사독` Lv.5

### 8.6. Edge cases

- Clone spawn during Ignition Aura: HP derived from aura-boosted
  effective level at spawn instant
- Player transform (Horn Strawberry / Yachaman Soul / Odin's Eye):
  `_teardown_dual_glitch_runtime_state()` runs and HP state clears
  cleanly; no zombie clones
- Round end / death: HP state clears with the rest of the runtime
  state
- Save / load: clone HP state is ephemeral — not persisted. Clones
  do not survive save reloads today, so this remains a non-issue.
  Confirm no new save key is introduced.

---

## 9. Recommended Implementation Order

1. Per-clone `hp` field + spawn HP assignment (no visual changes)
2. Ball -> clone hit HP decrement path (still no visual changes)
3. Visual states: faded tint on HP == 1
4. Evaporation animation on HP == 0 + collision disable
5. Active termination when no live clones remain
6. Full QA pass: collision order, gold payout, termination,
   replication interaction
7. Ship

Keep HP work and replication work in separate commits / PR stacks —
they live on different balance axes (defensive vs offensive) and
should be tunable independently.

---

End of handoff.
