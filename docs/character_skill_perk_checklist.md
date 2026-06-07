# Character Runtime Skill / Perk Integration Checklist

Current development target: Godot **디스크하츠 - 링피아**.

The original Python/Pygame PingFighter character skill and perk system is
frozen. Use Python-side sections in this checklist as legacy porting
references only: they are useful for behavior, timing, balance, UI text,
tooltip formatting, offer flows, and parity audits, but they are not default
edit targets. New character skill / perk implementation, bug fixes, UI, VFX,
audio, save/load, and runtime wiring belong under `godot/` unless the user
explicitly asks for a legacy Python source edit.

Single source of truth for the code locations and QA checkpoints that must be
touched when adding, removing, porting, or modifying a runtime character
perk, character-exclusive skill, unlock-style perk, or player-skill /
5-orb skill, including academy / NPC perk-offer and skill-swap flows.

Four-way role split:

| Document | Owns |
|---|---|
| **this file** | Every Godot runtime code location, legacy reference path, and verification checkpoint for character perks / skills |
| `CLAUDE.md` | Hidden-knowledge rules: icon-render traps, seven UI text paths, final-cooldown HUD rule, routing |
| `AGENTS.md` | Top-level Godot-first routing and shared runtime guardrails |
| `docs/item_runtime_checklist.md` | Item runtime only; use it when the change is item-driven rather than perk-driven |

Character perk / skill runtime does not belong in asset-generation skills.
Character perk / skill integration lives here, with `AGENTS.md` providing
the top-level Godot-first routing.

If this file and `CLAUDE.md` appear to overlap:

- **This file wins** for runtime code-location coverage and end-to-end
  verification.
- **`CLAUDE.md` wins** for the hidden-knowledge UI traps it calls out
  explicitly (`draw_skill_icon_mini()`, seven render paths, cooldown
  display consistency).

## How to use this file without reviving Python development

For current 디스크하츠 - 링피아 work, follow this route:

1. Start at Section 0.
2. Classify and wire through the Godot path:
   - registration / pool / runtime effect: Sections 1-2
   - active skill / 5-orb system: Section 3
   - Commando / Soldier permanent firearm: Section 3.3a plus
     Sections 4, 6, 7, and 9
   - icon, HUD, tooltip, modal UI: Section 4
   - effective level and cooldown display: Section 5
   - gameplay effect / VFX / audio / reward wiring: Section 6
   - persistence / reset lifecycle: Section 7
   - final integration map and smoke test: Sections 8-9
3. Treat Python names and old file anchors as parity vocabulary only. Do not
   edit Python/Pygame files unless the user explicitly asks for a legacy-source
   change.

Legacy Python reference surfaces are embedded mostly in Sections 2, 4, 6, 7,
and 8. When a bullet names `pingfighter.py`, `draw_skill_icon_mini()`,
`apply_runtime_skill_effect()`, `recalculate_skill_effects()`,
`resource_path()`, or Pygame font behavior, translate the intent to the
matching Godot catalog, owner module, renderer, tooltip helper, or resource
loader before implementing.

---

## 0. Pre-flight before touching code

Before adding ANY runtime character perk / skill, confirm:

- [ ] Character decided (`smasher`, `viper`, `soldier`, `optimus`, etc.)
- [ ] Feature type decided:
      general perk / scaling perk / unlock perk / 5-orb skill /
      active-skill enhancer
- [ ] Code id decided in `snake_case`
- [ ] Correct pool decided:
      `RUNTIME_SKILL_POOL` or the character-exclusive pool
- [ ] If this unlocks or adds an active skill:
      input, gauge cost, cooldown, icon, tooltip text, and swap behavior
      are all specified
- [ ] If this adds or modifies an active skill that can directly hit the
      ball or boss, absorb / destroy objects, or generate a sustained
      owned reward event, the skill-gold policy is specified:
      appropriate payout amount / cadence / bonus conditions, or an
      explicit no-gold exception
- [ ] If this adds or retunes player / boss knockback, decide whether it
      should reuse the shipped fire-event knockback baseline. Default:
      yes -- tune from the fire-event path (current reference: Viper
      `kick_enhance` guard knockback) rather than inventing an unrelated
      velocity / decay / hitstop system.
- [ ] If this is offered through an academy / NPC / downtown modal:
      visit scope, reroll policy, exhausted-after-success policy,
      ownership-vs-equipped filtering, and currency/AP sync target are
      all specified
- [ ] If this changes player-skill cooldowns:
      decide whether it affects only gameplay, or gameplay + all HUD
      readouts (default: both)
- [ ] If this is an active-skill enhancer / passive that modifies an
      existing orb skill, decide whether the target orb tooltip needs a
      dedicated runtime synergy / bonus-line summary. Default: yes when
      the effect is not already obvious from the normal cost / cooldown
      lines alone.
- [ ] Decide whether `transcendent_crown` / `sage_ring` should change
      the behavior at effective levels above the base cap
- [ ] If future perk-level buff sources can raise the effective level
      above `Lv.5` / `max_level` (for example `transcendent_crown`,
      `sage_ring`, ignition-style buffs, or future level-buff effects),
      decide whether the perk keeps gaining real numeric power above the
      base cap. Default: yes for invested passive / scaling perks;
      explicit hard caps are exceptions and must be documented.
- [ ] Decide whether the effect is boolean-only (`unlock_*` style) or
      scales with level

Every checklist below assumes these are already decided.

### 0.1. Default runtime assumptions for new character skill work

Unless the user explicitly overrides them, use these defaults:

- A new character perk request means **end-to-end runtime work**:
  registration, actual gameplay effect, UI / tooltip sync, save/load,
  reset, and verification.
- Character-exclusive perks should live in the matching character pool
  (`SMASHER_EXCLUSIVE_SKILLS`, `VIPER_EXCLUSIVE_SKILLS`, etc.) unless
  the perk is intentionally shared.
- Unlock-style perks that grant a player-skill / 5-orb skill should
  **auto-equip into the first free slot**. If no slot is free, they
  should use the existing swap dialog flow instead of silently failing.
- If a perk modifies an existing active skill's cost / damage / size /
  cooldown / duration, the **player-facing tooltip and HUD must reflect
  the final effective value** when that value is shown to the player.
- If a skill or buff gives the player a meaningful active duration,
  startup-hold timer, or other persistent timed window to track, default
  to the shared right-bottom horizontal timer-gauge stack. Match the
  shipped size / frame / spacing / stack behavior instead of inventing a
  one-off timer widget unless the user explicitly asks for a different
  HUD pattern. The lowest active timer bar owns stack index `0` and sits
  on the bottom baseline; additional simultaneously active timer bars
  stack upward only because lower active bars exist. Do not hardcode a
  nonzero stack index for a timer that may be the only active bar, or it
  will appear to float above the floor.
- If a perk modifies another active skill through runtime-only or
  otherwise hidden behavior (prep, duration, clone HP, super armor,
  combo scaling, projectile reach, etc.), assume the target orb tooltip
  needs a concise runtime synergy lane. Do not stop at the perk card or
  perk-detail text unless the user explicitly asks for static-only copy.
- Unless the user explicitly asks otherwise, new character perk / skill
  knockback should inherit the shipped fire-event knockback feel.
  Prefer tuning multipliers, timers, decay, or short hitstop / release
  behavior on top of the existing fire-event channels instead of adding
  a parallel knockback system.
- Unless the user explicitly asks otherwise, a new active skill with a
  clear owned reward moment should have an intentional skill-gold bonus
  policy. Default to a moderate payout consistent with comparable
  same-character skills; "no skill gold" should be an explicit design
  choice, not a silent omission.
- If a skill uses directional input and the game already supports both
  letter keys and arrow keys for that direction, treat them as
  equivalent by default in gameplay and UI. Do not ship a new
  directional skill that only listens to one key family unless the user
  explicitly asked for that restriction.
- If a skill is opened by another skill, hit-confirm, combo window,
  return motion, cancel, or other predecessor state, build a
  **predecessor trigger matrix** before coding. Do not accept "the skill
  works from one path" as enough. List every source that can open the
  window, what exact event opens it, what state allows the follow-up
  input, what consumes / expires it, and which focused smoke covers that
  row.
- If the perk is an invested runtime perk, assume it must be audited
  under `transcendent_crown` and `sage_ring`.
- Unless the user explicitly asks otherwise, a new invested passive /
  scaling perk that can receive effective-level bonuses should keep
  gaining real runtime stats above `Lv.5` / `max_level` when those
  bonuses raise its effective level. Treat hard caps as an explicit
  design exception, not as the silent default.
- If the perk is `max_level == 1` and is meant to stay boolean-only,
  verify that bonus items do **not** accidentally create bogus `Lv.2`
  gameplay expectations in UI text.
- Unless the user explicitly asks otherwise, **round transition resets
  runtime active state** for character skills. Active buffs, remaining
  duration, command buffers, charge state, temporary spawned entities,
  and transient FX should not silently carry into the next round.
- In the Godot port, any character skill / perk sound that loops or is
  driven by a `sync_*` method must be treated as part of round-transition
  runtime state. Add the matching `stop_*` method to
  `scripts/audio/gameplay_loop_audio_cleanup.gd`, and verify score
  event, scoreboard-active frames, serve wait, round restart, and game
  reset cannot leave the loop playing or immediately re-arm it from
  `battle_effects_update_controller.gd`.
- Apply the same cleanup rule to Lingpet / RefCounted skills and to any
  sustained or stop-capable urgent SFX channel, even if the stream is not
  flagged as a Godot loop. If the sound can still be playing when score,
  serve wait, round restart, stage transition, or game reset interrupts
  the effect, register its `stop_*` method in
  `scripts/audio/gameplay_loop_audio_cleanup.gd`; do not rely on
  `reset()` only clearing local flags, because lingpet host reset paths can
  run without audio / registry deps.
- By default, **cooldown-state reset and runtime-state reset are separate
  responsibilities**. A helper that clears cooldowns should not also
  terminate or preserve active runtime state unless that behavior is
  explicitly intended and documented.
- Cross-round carryover / pause-resume behavior is an exception, not the
  default. Only add it when the user or design explicitly wants that
  gameplay identity, and document the dedicated pause/resume path
  separately from the hard reset path.
- Commando `bowling_trap` is an explicit carryover exception: round reset
  preserves placed traps by normalizing them to `waiting`, while full
  reset / character-switch cleanup clears them.
- Viper `dual_glitch` is an explicit carryover exception: active clone
  presence survives normal round reset, serve-wait frames pause its remaining
  duration, and full reset / character-switch cleanup clears it through
  `preserve_dual_glitch = false`.
- In the Godot port, the orb-tooltip hover pause/resume exception is
  routed through `scripts/core/battle_scene_skill_tooltip_driver.gd`.
  Keep tooltip-driven cooldown pause/resume separate from character
  runtime-state reset and from `battle_scene_update_callbacks.gd` fanout.
- In the Godot port, the post-perk-choice ball resume-safety frame tick is
  routed through `scripts/core/battle_scene_runtime_perk_update_driver.gd`.
  Keep the actual freeze / recovery state in
  `scripts/characters/runtime_perk_state.gd`; the core driver is only the
  frame-callback bridge.
- Keep **round-transition reset** and **real stage-transition reset**
  separate. Stage-scoped ammo refills, rental / temporary cleanup, and
  "once per stage" reset rules belong on the actual stage-entry /
  stage-advance hook, not in a generic `reset_round()` path.

Do not stop for clarification on the items above unless the user's
request directly conflicts with one of these defaults.

---

## 1. Classify the work before wiring it

| Type | Meaning | Typical audit focus |
|---|---|---|
| General perk | Passive runtime bonus, no new active input | pool entry, level-up effect, UI text, effective level |
| Unlock perk | Grants an active skill or orb slot entry | unlock flow, auto-equip / swap, save/load, actual skill gating |
| 5-orb skill | Active skill shown in the left-side orb HUD | metadata row, icon, cooldown, tooltip, gauge cost, gameplay trigger |
| Permanent firearm | Commando / Soldier weapon unlocked into the firearm selector | weapon controller entry, ammo / cooldown, firearm HUD art, fire / impact / deployed VFX, audio routing, reset / stage policy |
| Active-skill enhancer | Perk that modifies another active skill | effect path, target-skill tooltip, cooldown / cost display, runtime synergy-line policy |
| Cooldown modifier | Perk or skill that changes player-skill cooldowns | final cooldown helper path, orb wedge, countdown text, tooltip |

Do not treat all of these as the same problem. The common bug pattern is
"registered in the perk pool, but not actually wired into the active
skill system."

---

## 2. Common runtime registration

Current Godot-first rule:
- Implement new character perk / skill runtime work under `godot/` by
  default.
- Python names in this section describe legacy PingFighter concepts to map
  during a port. In Godot, find the matching catalog, runtime state, owner
  module, HUD renderer, tooltip renderer, save/load state, and debug menu
  before editing.

### 2.1. Add the perk to the correct pool

- [ ] Add the entry to the correct current registry. In legacy Python this was:
      `RUNTIME_SKILL_POOL` or the matching character-exclusive pool
      such as `SMASHER_EXCLUSIVE_SKILLS`, `VIPER_EXCLUSIVE_SKILLS`,
      `SOLDIER_EXCLUSIVE_SKILLS`, or `OPTIMUS_EXCLUSIVE_SKILLS`.
- [ ] Provide the minimum fields used by existing runtime UI:
      `name`, `max_level`, `descriptions`, `detail`, `icon_color`,
      and `tree`.
- [ ] If the perk is character-specific, set
      `character_restriction` correctly.
- [ ] If the perk is unlock-style or otherwise special-cased, do NOT
      assume the pool entry alone is enough; continue through Sections
      3 through 7.

### 2.2. Register the actual effect

- [ ] The current runtime effect applier must handle the new id. In legacy
      Python this was `apply_runtime_skill_effect()`.
- [ ] If the effect needs special unlock / equip / give-item /
      immediate-apply behavior, implement it here rather than relying
      on the generic `runtime_skill_levels[id] += 1` fallback.
- [ ] The current recalculation / load-sync path must mirror any special
      behavior. In legacy Python this was `recalculate_skill_effects()`.
      that can be reached via debug level edits, load-time sync, or
      bonus-state recalculation.
- [ ] If the perk mutates globals or caches, add the needed `global`
      declarations in every mutating function.
- [ ] Apply the effect at the **stat consumption point**, not display
      time only.

### 2.3. Effective-level support

- [ ] If the perk can exceed its base cap because of
      `transcendent_crown`, `sage_ring`, or other perk-level buff
      sources, confirm
      `get_runtime_skill_level()` is the number the gameplay path reads.
- [ ] If a temporary effective-level buff source such as an ignition-
      style aura can toggle during live play, confirm every owner-cached
      consumer is resynced on both activation and expiry, not only
      pull-based helpers. In the Godot port this includes cached paddle
      size / scale, accessory-slot bonuses, active-item / mythic sync
      composition, skill cooldown config caches, collision context, and
      HUD readouts.
- [ ] For a passive / scaling perk, do **not** silently clamp gameplay
      math back to `min(max_level, effective_level)` unless an explicit
      design exception says the perk should hard-cap. The default policy
      is that effective levels above `Lv.5` keep increasing real
      numeric performance.
- [ ] If the displayed description must change at `Lv.6+`, add a
      pattern or special case to `get_runtime_skill_description()`.
- [ ] If the perk is intentionally boolean-only, verify the gameplay
      path still behaves as boolean-only even when the effective level
      becomes 2+ from bonus items.
- [ ] If the perk is intentionally hard-capped despite overflow levels,
      make that cap explicit in gameplay code, tooltip text, and
      checklist notes so players do not infer fake `Lv.6+` scaling.

---

## 3. Character-specific active skill / 5-orb systems

Only do this section when the change touches a character's active skill
HUD, unlock perk, or orb-slot system.

Current Godot-first rule:
- For current work, wire skill metadata, cooldown, unlock/equip state,
  tooltip, icon, activation, audio, VFX, save/load, and swap behavior through
  the Godot character owner modules and HUD renderers.
- Use Python function and registry names below as legacy reference names
  only when mapping old behavior into Godot.

### 3.1. If the perk grants a new active skill

- [ ] Add a metadata row to the character's orb-skill data list
      (`*_SKILL_ICONS_DATA`) with:
      `name`, `korean`, `cost`, `color`, `cooldown`, `key`,
      `description`, `how_to_use`, `motion_hint`, `effect_type`, and any
      extra flags the tooltip or renderer needs.
- [ ] `description` is 3 lines max and follows the orb-tooltip standard
      format (CLAUDE.md §"5-orb active-skill tooltip standard format"):
      effect + brief flavor / story + optional constraint, **no input
      key recap**, **no cooldown recap**. Perk-affected numbers
      (`extension_gear`-multiplied durations etc.) must be abstracted to
      `"일정 기간"` / `"일정 범위"`; fixed numbers stay literal.
- [ ] `how_to_use` is a single plain sentence with no `\n` (it feeds
      `font.render(f"▶ {how_to_use}")` paths in ESC perk status / TAB
      info, where newlines render as zero-width tofu). Do NOT use
      legacy magic-string sentinels like `"drive"` / `"power_smashing"`
      / `"warp_gate"` — those were only consumed by the old
      `_get_smasher_tooltip_height()` height switch, which now keys off
      `skill_name` instead.
- [ ] `motion_hint` is a single short line describing what the skill
      **looks like** in motion (visual / motion verb), rendered as a
      dim row under the input rows. Not a stat summary. Never bake in
      perk-affected numbers; prefer descriptive verbs even for fixed
      numbers (motion_hint is a glance, not a spec).
- [ ] If that metadata row introduces an `effect_type`, preview key, or
      other tooltip-preview dispatch value, confirm the orb-tooltip
      preview renderer already covers it or add the matching branch /
      shared mapping in the same task. Metadata-only registration is not
      enough if the tooltip family already shows an effect-preview box.
- [ ] Add the skill to the character's cooldown registry.
- [ ] Add the skill to activation-time / active-state registries if the
      HUD glow or activity effect depends on them.
- [ ] Add the skill to the character's unlocked-state registry.
- [ ] Add the skill to the character's equipped-skill list defaults or
      unlock flow as appropriate.
- [ ] Add the unlock map inside `apply_runtime_skill_effect()`.
- [ ] Mirror that unlock map inside `recalculate_skill_effects()`.
- [ ] Use the existing swap dialog when slots are full; do NOT silently
      drop the unlocked skill.
- [ ] If slot-full unlock flow can open a swap dialog, treat cancel as a
      true no-op. Do not dirty `runtime_skill_levels`, unlocked-state
      flags, ownership registries, or controller inventory until the
      swap actually succeeds.
- [ ] Save and restore both the unlocked-state dict and equipped-skill
      list.
- [ ] If the character participates in "hide unlock perks when slots
      are full" behavior, update `_CHARACTER_UNLOCK_PERKS`,
      `_are_character_skill_slots_full()`, and the real slot-full offer
      structure as one set. In the current repo that means the strict
      tutorial / fixed-offer path (`filter_full_slot_unlock_perks_strict()`)
      plus the normal runtime-offer helpers (`_weighted_perk_sample()`,
      `_active_perk_weight()`, `enforce_full_slot_perk_cap()`). Missing
      any one of these silently breaks slot-full perk filtering,
      weighted swap offers, or tutorial behavior.
- [ ] If swap cleanup removes a previously equipped active skill, derive
      the removed `perk_id` from the unlock map instead of assuming
      `perk_id == skill_id`. `double_marshal_kick -> phantom_kick` and
      `soldier_pistol_perk -> commando_pistol` are the canonical failure
      modes.
- [ ] If slot-full choice capping can remove sampled cards, apply the
      cap before instant fillers / gold-conversion append so the final
      card count is preserved.
- [ ] If the character has an acquired-skill list in
      `show_perk_status()` or a local `get_acquired_skills()` helper,
      include the character-exclusive skill pool there too. A skill can
      be fully wired in gameplay yet still disappear from the ESC perk
      status UI if this list is stale.
- [ ] Treat `*_SKILL_ICONS_DATA` as metadata, not as the source of
      truth for the visible orb lineup. Visible slot order should come
      from the equipped-skill list / slot model.
- [ ] If the design has permanent ownership, currently equipped skills,
      and temporary / rental holdings, keep them as separate canonical
      states and rebuild the live runtime list from them. Do not merge
      all three concepts into one mutable list and hope later code can
      infer the difference.
- [ ] When adding or moving a skill through one of the icon registries
      (`_SMASHER_ORB_ICON_REGISTRY`, `_VIPER_ORB_ICON_REGISTRY`,
      `_OPTIMUS_SKILL_ICON_REGISTRY`, `BLACKSMITH_SKILL_ICON_REGISTRY`,
      `_SOLDIER_ORB_ICON_REGISTRY`), explicitly set
      `slot_occupancy`, `cooldown_reduction_eligible`, and
      `cleanup_policy` on the registry entry. Use this matrix unless the
      design intentionally changes the runtime model:

      | Registry family | `slot_occupancy` | `cooldown_reduction_eligible` | `cleanup_policy` |
      |-----------------|------------------|-------------------------------|------------------|
      | Smasher active / unlock orbs | `active_orb` | `True` | `perk_id_lookup` |
      | Viper active / unlock orbs | `active_orb` | `True` | `perk_id_lookup` |
      | Optimus framed skill-card icons | `active_orb` | `False` | `perk_id_lookup` |
      | Baltor / Blacksmith active icons | `active_orb` | `True` | `perk_id_lookup` |
      | Soldier `supply_drop`, `emergency_supply` | `base_fixed` | `True` | `base_only` |
      | Soldier permanent firearm shared slots | `shared_slot` | `True` | `shared_swap` |
      | Soldier `commando_pistol` via `soldier_pistol_perk` | `passive_orb` | `True` | `perk_id_lookup` |

      `slot_occupancy` owns slot-full math, `cooldown_reduction_eligible`
      owns whether generic player-skill cooldown reduction should apply,
      and `cleanup_policy` records the only safe removal path. Soldier
      `shared_swap` skills must be cleaned up through the shared swap
      helper; normal active / unlock aliases need perk-id lookup through
      `_CHARACTER_UNLOCK_PERKS`; base skills are not cleanup candidates.
- [ ] For Soldier permanent firearms that are also shared-slot orb
      skills, sync the item instance cooldown through
      `_apply_soldier_firearm_cooldown_frames()` before calling
      `can_fire()` / `can_install()`. The orb HUD cooldown and the item
      instance cooldown must use the same final reduced value.
- [ ] For Soldier `cleanup_policy: "shared_swap"` removals, route cleanup
      through `_perform_skill_swap_cleanup("soldier", skill_name)` after
      the equipped-slot mutation. Do not only pop `runtime_skill_levels`
      by `skill_id`; the owning unlock perk, unlock flag, weapon
      ownership, and controller inventory must be cleared together.

### 3.1a. Combo / predecessor trigger matrix

Do this for any active skill that is not purely direct-cast. This covers
follow-up slashes, kick chains, hit-confirm windows, cancel windows,
return-motion handoffs, and skills whose tooltip says "after X" or
"within N seconds after hitting".

- [ ] Start from the Python reference, current Godot code, skill tooltip,
      perk-detail text, and any design note. Write down every
      predecessor source, not only the first one that already works.
- [ ] For each predecessor, record the exact opener event:
      cast start / projectile fire / ball hit / boss hit / object
      absorb / release burst / return phase / cancel phase / timeout.
- [ ] For each predecessor, record whether miss, blocked, guard, cancel,
      early return, death / round transition, or cooldown failure should
      leave the follow-up window closed.
- [ ] For each predecessor, record the required state at follow-up input:
      airborne, grounded, wall-dive active, return active, specific
      phase, held input, edge input, direction-neutral, cooldown-ready,
      gauge-ready, and target skill equipped.
- [ ] If the follow-up may start while the predecessor motion is still
      active, check input priority before the predecessor update consumes
      the edge. A motion update that returns early can silently block the
      follow-up even when the window flag is true.
- [ ] If the follow-up cancels or hands off from the predecessor, clear
      the predecessor's visual, audio, particle, freeze, aura, rope,
      projectile, and temporary runtime state intentionally. Do not leave
      ghost active flags that keep drawing, blocking input, or preserving
      stale collision state.
- [ ] For Godot ball-owning handoffs, audit the shared motion contract:
      any skill that returns `skip_ball_motion_step=true`, hides the ball,
      captures the ball, or temporarily returns `ball_vel = Vector2.ZERO`
      must return `skip_ball_motion_step=false` plus a real nonzero
      release velocity on every resume / release / final-fire / cancel
      path. Focused smoke coverage must prove the shared skip flag does
      not remain stuck after the handoff.
- [ ] For a ported **hit-cutscene freeze** — a cross-module flag that
      gates ball motion + boss AI + stage hazards (e.g.
      `viper_nerve_strike_freeze_active` for Venom Edge,
      `viper_dmk_freeze_active` for Marshal Kick wall-dive) — release the
      freeze at the SAME phase point as the Python original, not at the
      most convenient GDScript transition. The common parity is **hold the
      freeze through the return / recovery flight and clear it only when the
      actor LANDS** (Python: `_viper_ns_freeze_active = False` at the end of
      return Phase 2, with the explicit comment "프리즈는 착지 완료까지
      유지"). Clearing it on return-phase *entry* lets the ball/boss resume
      ~15 frames (~0.25s) early while the character is still flying back —
      a silent feel divergence that no runtime error surfaces. Reference
      fix: `viper_skill_nerve_strike_runtime.gd` `enter_return_phase()` must
      NOT set `nerve_strike_freeze_active = false`; the freeze is dropped by
      `reset_runtime()` at the end of `_update_return_phase()` (landing).
      The smoke must assert the freeze PERSISTS through the whole return
      flight (ball + boss held one frame before landing) and clears only
      after the final landing frame — a "return phase cleared the freeze"
      assertion bakes in the wrong behavior. Misses never arm the freeze, so
      leaving it untouched at phase entry is correct for the miss path too.
- [ ] Verify both window creation and window lifetime:
      duration value, pause / update path, active-motion exceptions,
      airborne / grounded expiry, and cleanup on cast / hit / reset.
- [ ] If the predecessor id, unlock perk id, and equipped orb skill id
      differ, check all aliases in the matrix. `double_marshal_kick ->
      phantom_kick` style ids are not optional coverage.
- [ ] Mirror the complete predecessor list in player-facing text:
      orb tooltip, non-orb tooltip `how_to_use`, perk card `detail`, and
      academy / NPC offer text if present.
- [ ] Add focused smoke coverage for every predecessor family. It is
      acceptable to group equivalent rows, but a direct-cast success test
      does not cover hit-confirm, return-motion handoff, or cancel
      handoff paths.
- [ ] For Godot ports, put the matrix coverage in the owning runtime
      smoke file or a narrowly named companion smoke. The test should
      assert the window flag opens, the follow-up input activates the
      intended skill, the old motion is consumed when applicable, and
      the target skill cooldown / gauge path is triggered.
- [ ] Keep a concrete example in mind: Viper Dark Blade is opened by
      Shadow Step hit, Air Blade follow-up timing, Marshal Kick hit,
      Phantom Kick hit, and Core Flip / Hwarang Kick hit. Testing only
      Air Blade proves Dark Blade exists, but not that the combo graph is
      complete.

### 3.2. Smasher Godot audit points

When the work is Smasher-specific, audit all of these current Godot anchors:

- [ ] `SMASHER_SKILL_ICONS_DATA`
- [ ] `_smasher_skill_cooldowns`
- [ ] `_smasher_skill_activation_times`
- [ ] `_smasher_skill_was_active`
- [ ] `_smasher_skill_unlocked`
- [ ] `_smasher_equipped_skills`
- [ ] `reset_smasher_skill_unlocks()`
- [ ] `reset_smasher_skill_cooldowns()`
- [ ] `equip_smasher_skill()`
- [ ] `swap_smasher_skill()`
- [ ] `unlock_smasher_skill()`
- [ ] `is_smasher_skill_unlocked()`
- [ ] `_show_smasher_skill_swap_dialog()` / themed swap flow
- [ ] `_draw_smasher_skill_tooltip()`
- [ ] Godot `smasher_ghost_shot_state.gd` motion ownership:
      performance teleports may set `skip_ball_motion_step=true`, but
      rise / chaos resume and the final fire must explicitly clear it.
      Keep or extend `godot/tests/smasher_ghost_shot_motion_skip_smoke.gd`
      when touching Ghost Shot, power-smash motion, or shared ball-update
      skip handling.
- [ ] save/load keys:
      `smasher_skill_unlocked`, `smasher_equipped_skills`

Important current behavior:

- `is_smasher_skill_unlocked()` effectively means
  **unlocked AND equipped**.
- Unlocking the perk without slot integration is not enough; the skill
  still will not fire if it is not in `_smasher_equipped_skills`.
- Existing Smasher skills such as Magnum Grip, Plasma, Recovery,
  Cleanse, and Ghost Shot each have separate gameplay trigger paths.
  A new skill must have its own real trigger/update path too.

### 3.3. Viper Godot audit points

When the work is Viper-specific, audit the equivalent registries:

- [ ] `VIPER_SKILL_ICONS_DATA`
- [ ] `_viper_skill_unlocked`
- [ ] `_viper_equipped_skills`
- [ ] `_viper_skill_cooldowns`
- [ ] `_viper_skill_activation_times`
- [ ] `_viper_skill_was_active`
- [ ] `unlock_viper_skill()`
- [ ] `equip_viper_skill()`
- [ ] `swap_viper_skill()`
- [ ] `_show_viper_skill_swap_dialog()`

If another character uses a different active-skill model, follow that
character's existing pattern rather than forcing the Smasher/Viper
5-orb model where it does not belong.

### 3.3a. Commando / Soldier permanent firearm production pipeline

Use this section for any new or substantially rebuilt Commando / Soldier
firearm (`pistol`, `commando_pistol`, `ak47`, `bazooka`, `net_gun`,
`fire_support`, `bowling_trap`, `suicide_drone`, or future entries). A
firearm is not complete when the orb unlock exists; it needs the weapon
controller, runtime, HUD card, VFX, audio, and lifecycle route together.

- [ ] Register the weapon in the current Godot firearm owner stack:
      `commando_skill_config.gd`, `commando_weapon_controller.gd`, the
      runtime input / effect owner (`commando_firearm_runtime.gd` or the
      focused module if split), and any save / load or rental / temporary
      grant path. Keep Python firearm names as parity vocabulary only.
- [ ] Define ammo, magazine / charge count, cooldown, control-lock /
      windup, stage refill, rental depletion, and swap behavior in one
      canonical controller path. If academy / NPC / perk-pickup grants
      can unlock the same firearm, they must call the same per-instance
      initializer so ammo, active flag, equipped flag, and cooldown table
      cannot diverge.
- [ ] If the user asks to draw or remake the firearm UI art, create a
      real bitmap first. Default shape: static firearm-HUD picture via
      imagegen, not a skill-orb icon and not a procedural-only fallback.
      Copy the accepted PNG into the Godot asset tree, preserve alpha,
      verify transparent corners / alpha bbox, and add it to the firearm
      HUD resource path before any procedural branch can win.
- [ ] For firearm HUD motion, ship sheet-first. Use AutoSprite for final
      fire / recoil / install / deploy / capture / launch UI sheets,
      normally `4x4`, 16 frames, with explicit grid constants, frame
      count, draw-scale compensation, and cached source-region slicing in
      `commando_firearm_selector_renderer.gd` or the focused HUD owner.
      Static-rest / animated-active state must be intentional.
- [ ] If the firearm creates a visible deployed object, projectile, field,
      capture, launch, detonation, or lingering impact, create / wire the
      playfield visual separately from the HUD card art. Use imagegen for
      accepted still props and AutoSprite for final animated sheets. Keep
      source and runtime PNGs versioned, record grid / frame interval /
      postprocess scale, and verify no runtime frame edge-touches.
- [ ] Add all generated assets to a manifest near the asset family:
      generator, prompt summary, source path, runtime path, atlas path
      when present, AutoSprite asset / job / spritesheet ids, grid,
      frame count, SHA256, transparent-corner QA, edge-touch QA, and any
      per-cell scale / alpha cleanup. Generation alone is not runtime
      integration.
- [ ] Route audio through `commando_firearm_audio_resolver.gd` and
      `game_audio.gd` with phase-specific names: install / ready / fire,
      capture / snap, launch, flight loop, impact / explosion, and
      cancel / cleanup where applicable. Do not reuse a long
      capture-launch sequence as a later boss-hit or guard-impact cue;
      otherwise the audible sequence can replay after the real launch.
- [ ] If any firearm audio loops or is driven by a `sync_*` method, add
      the stop method to `gameplay_loop_audio_cleanup.gd` and verify
      score event, scoreboard, serve wait, round restart, and game reset
      cannot leave it playing or re-arm it.
- [ ] Wire runtime result ownership completely: `update_input()` /
      `update_effects()`, actor draw context, battle effects result
      applier, ball ownership (`ball_pos`, `ball_vel`,
      `skip_ball_motion_step`), boss damage / status, and special-gauge
      or skill-gold results. A deployed firearm that captures or holds
      the ball must clear motion-skip on every release / cancel / reset
      exit path.
- [ ] For boss knockback / stun caused by a firearm, default to the
      shipped fire-event knockback feel: high initial velocity, decay,
      finite motion window, and status-source cleanup. Do not add a
      constant-speed shove unless that is an explicit design exception.
- [ ] Decide the lifecycle policy explicitly. Default firearm active
      state clears on round transition; cross-round carryover is an
      exception and must document the normalized carryover state plus the
      separate hard-reset / character-switch cleanup route.
- [ ] Add focused smoke coverage for every surface touched: firearm
      controller ammo / cooldown, HUD selector state and asset prewarm,
      runtime VFX / ball lifecycle, audio resolver / routing, boss-hit
      handoff when relevant, round / stage reset behavior, and generated
      PNG alpha / edge QA. After any `.gd` edit, still run the repo-local
      headless load check and warning scan.

### 3.4. Academy / NPC offer flows for unlock-style perks

Only do this section when the perk or skill can be acquired through an
downtown / academy / NPC interaction instead of the standard perk cards.

- [ ] Define the offer pool in terms of **unowned / never unlocked**
      skills, not merely "currently unequipped" skills.
- [ ] If the same visit should keep one rolled offer, cache the offered
      perk for the visit.
- [ ] If the same visit should stop after one success, cache a separate
      consumed / exhausted flag; caching the offer alone is not enough.
- [ ] Define the reset boundary explicitly:
      close dialog only / same building visit / building re-entry /
      next stage / next run.
- [ ] If the flow spends gold or another resource from a helper module,
      resync the final value back to the shared manager / player state
      after the modal closes.
- [ ] If the flow launches a swap dialog when slots are full, verify the
      same visit cannot open a second free swap after a successful one
      unless the design explicitly wants multiple swaps.
- [ ] If a parent confirm dialog opens a child perk / skill modal, make
      sure the parent UI is fully closed and the interior is redrawn
      before the child modal snapshots the background.
- [ ] If the perk unlocks a permanent consumable-backed resource
      (ammo, magazine, charge pool, drone count, activation-timer, or
      any per-instance field that lives on a singleton weapon / effect
      instance), confirm the academy / NPC purchase and swap paths run
      the **same per-instance initializer** as the in-game perk-pickup
      path. It is a common failure mode to have `unlock_*_skill()`,
      `equip_*_skill()`, and `*_controller.unlock_permanent_weapon()`
      set ownership flags on the academy path while the per-instance
      `reload()` / `equip()` / ammo-global reset / cooldown-table
      refresh only runs inside the perk-pool path. When this split
      exists, extract the instance init into a shared helper (e.g.
      `_initialize_permanent_soldier_firearm_instance`) and call it
      from every acquisition path so an academy-acquired unlock does
      not enter the next match with ammo 0 or a stale cooldown.

---

## 4. Icon rendering, HUD, and tooltip audits

### 4.1. Generic perk icon rendering

Current Godot-first rule:
- Current icon rendering belongs in Godot HUD / perk icon renderers such as
  `runtime_perk_icon_renderer.gd` and the relevant skill-orb renderers.
- Legacy Python names in this section (`draw_skill_icon_mini()`,
  `_MINI_SKILL_ICON_REGISTRY`, etc.) are reference surfaces for parity and
  alias auditing, not default edit targets.

- [ ] Add a `_MINI_SKILL_ICON_REGISTRY` entry when the icon can reuse an
      existing PNG / orb-symbol path; otherwise add the bespoke
      `draw_skill_icon_mini()` branch.
- [ ] For Smasher / Viper orb-backed skills, keep the runtime skill id in
      the character orb registry (`_SMASHER_ORB_ICON_REGISTRY`,
      `_VIPER_ORB_ICON_REGISTRY`) and point both the runtime mini icon
      and any unlock / alias mini icon at that shared entry. The unlock
      entry should add only the unlock badge policy.
- [ ] For Commando / Soldier orb-backed skills, keep the runtime skill id
      in `_SOLDIER_ORB_ICON_REGISTRY`, then point runtime mini icons and
      unlock / perk aliases through `_CHARACTER_UNLOCK_PERKS["soldier"]`.
      If the runtime HUD path is Soldier-specific procedural art instead
      of the shared orb renderer, mark the registry entry with
      `symbol_renderer: "soldier"` so the mini path reuses the correct
      Soldier renderer instead of the generic shared symbol renderer.
- [ ] For Optimus framed skill-card icons, keep the skill id in
      `_OPTIMUS_SKILL_ICON_REGISTRY` and let `draw_optimus_skill_icon()`
      dispatch through that registry before falling back to the legacy
      procedural branch.
- [ ] For Baltor / Blacksmith active icons that intentionally render
      through the bespoke HUD path, keep the skill id in
      `BLACKSMITH_SKILL_ICON_REGISTRY` with
      `family: "blacksmith_bespoke"` so coverage can distinguish the
      intentional exception from a missing shared renderer.
- [ ] If both the registry entry and bespoke branch are missing, the UI
      falls back to the first letter of the skill name, which is a
      broken-icon state.
- [ ] Audit every live id that can reference the icon:
      perk-pool id, unlock id, runtime skill id, and any legacy alias.
      If perk choice uses one name and the live HUD uses another, both
      must land in an intentional bespoke branch.
- [ ] For unlock-style active skills, verify the `unlock_*` perk id and
      the equipped orb skill id render the same accepted motif
      intentionally. If the orb uses a PNG, the unlock card / academy
      offer / NPC offer path should usually use that same PNG plus the
      established unlock badge rather than an older procedural drawing.
- [ ] Do NOT stop at a placeholder symbol or minimal debug shape.
      Draw a bespoke polished icon that matches the existing in-game
      icon language: readable silhouette, layered highlights, clean
      outline, and enough internal structure to look intentional at the
      actual UI size.
- [ ] Match the repo's existing pixel / drawn-icon quality bar rather
      than introducing a flat generic glyph. "Works" is not enough; the
      icon should look shippable beside existing perks.
- [ ] Check perceived subject fill in the smallest real UI box that uses
      this icon. A branch can exist and still fail QA if the motif is
      technically present but reads materially smaller than neighboring
      icons.
- [ ] If multiple callsites pass different `scale_multiplier` values or
      box sizes into `draw_skill_icon_mini()`, test them all. Passing in
      the large choice card does not guarantee the 32 px perk grid,
      academy offer, or status-panel version is readable.
- [ ] If the accepted icon came from imagegen or another generated PNG,
      copy it into the repo asset tree and wire a PNG-first loader/cache
      path. The live branch must attempt the PNG before any procedural
      fallback or special-case early return.
- [ ] For large PNG-backed perk / skill icons, cache the decoded source
      image separately from scaled `(size, active)` outputs. Animated
      choice cards and hover / selection scale changes must not reload
      the 512px+ / 1254px+ PNG from disk for every new draw size. Size the
      source cache for the real number of icons that can be visible in a
      perk grid / academy offer panel; a cache smaller than the simultaneous
      draw set can still thrash every frame.
- [ ] For one-shot / instant-trigger runtime perks (`instant_*` ids or
      similar immediate reward effects), default the visual to an
      8-frame horizontal PNG sheet unless the user explicitly requests a
      static icon only. Keep the static PNG as the identity anchor and
      fallback, wire sheet-first -> static PNG -> procedural fallback,
      cache source frames plus scaled `(size, active, frame)` surfaces,
      and validate alpha corners, alpha bbox, `Lv.1` / `Lv.5` small-cell
      labels, Godot resource import/load, and the focused Godot smoke or
      visible UI review for the touched renderer.
- [ ] Clamp PNG-backed perk icons in small-grid UIs so they preserve
      readability without hiding UI labels. A slight intentional bleed
      like existing energetic icons is acceptable, but the icon must not
      cover the bottom level text such as `Lv.5`, and the player must be
      able to read the level at the smallest real box size.
- [ ] In the TAB character-info perk tab (`draw_character_info_panel()`),
      compare the rendered small-cell result against the current
      `dash_module_control` / `모듈제어` icon. Treat that as the preferred
      size feel: not tiny, not oversized, and never covering the bottom
      level label such as `Lv.1` or `Lv.5`.
- [ ] Before creating or replacing a runtime perk icon, classify the
      visual family: character-exclusive active-skill / unlock perk,
      character passive / enhancer skill perk, or basic shared perk.
      Character-exclusive active and passive/enhancer skill perks should
      keep the established round / orb-style language; basic shared perks
      may use freer object / symbol silhouettes. The family choice does
      not override the TAB `dash_module_control` / `모듈제어` small-cell
      size reference.
- [ ] Treat the `CLAUDE.md` "Perk Icon Rendering" section as a
      companion invariant while doing this work.

### 4.2. Polished orb-HUD icon rendering

- [ ] If the skill appears in the left-side orb HUD, add or audit the
      `_draw_skill_icon_symbol()` branch too.
- [ ] Do not assume `draw_skill_icon_mini()` alone gives a polished orb
      icon even though it prevents total fallback breakage.
- [ ] Audit `_draw_skill_icon_symbol()` under the actual equipped-skill /
      orb-metadata ids, not only the perk acquisition id.
- [ ] If the HUD uses a different name from the unlock perk or perk-pool
      entry, cover both names explicitly or normalize the dispatch path
      before sign-off.
- [ ] If a PNG-backed orb replaces a procedural symbol, trace the
      matching unlock map (`perk_id -> skill_id`) and update the generic
      mini-icon path for the perk id in the same task. Do not leave the
      5-orb HUD on the new PNG while the perk-card path still renders
      stale art.
- [ ] The orb icon should feel like a premium HUD symbol, not a scaled
      copy of a rough menu icon. Keep it bold, centered, and instantly
      readable at small size.
- [ ] Judge the orb by the visible main subject, not by total effect
      area. Rings, glows, ghost layers, and particle dots do not count
      as acceptable size if the central motif still reads tiny.
- [ ] If the orb uses an on-disk PNG, verify the source alpha before
      sign-off: transparent corners must stay alpha 0, the visible alpha
      bounds should leave a few pixels of breathing room, and no baked
      square / black halo / rough outer ring should survive into the
      smallest HUD orb.
- [ ] Do not blindly reuse the procedural-symbol draw size for a PNG orb.
      If the PNG already includes its own circular rim, glow, or frame,
      extra `size + N` scaling can press that rim into the live HUD frame
      and make the edge look dirty. Judge the final draw size in the real
      orb slot beside neighboring shipped icons.
- [ ] When dimming inactive / cooldown PNG orbs, preserve the source alpha.
      Prefer an RGB-multiply style dim over filling or blending the whole
      `SRCALPHA` canvas in a way that can re-light transparent corners.
- [ ] If the orb icon has animated motion, audit its behavior by state
      instead of using one always-on loop for everything.
- [ ] Default expectation:
      cooldown / unusable = visually still or subdued,
      ready = normal motion / sparkle allowed,
      actively running = stronger or faster motion only if that helps
      the player immediately read "this skill is live right now."
- [ ] Strong default for new animated orb skills:
      idle / cooldown / low-gauge = static pose,
      ready = animation starts,
      active = animation can intensify.
- [ ] If a static pose exists, prefer a deliberate "rest" frame or
      `phase = 0` style hold over leaving the orb in constant ambient
      motion before the skill is actually ready.
- [ ] Cooldown or low-gauge states should not look falsely "ready" just
      because the icon keeps spinning or sparkling all the time.
- [ ] If the skill owns a player-visible active duration, startup-hold,
      or timed persistence window, add or audit the shared right-bottom
      horizontal timer-gauge entry instead of inventing a bespoke timer
      widget.
- [ ] Match the existing duration-bar family: horizontal layout, shared
      stack behavior, same visual weight, and the real effective
      duration value that gameplay uses.
- [ ] Verify the timed bar is removed on every teardown path that ends
      the real runtime state: timeout, cancel, round reset, stage
      transition, death, and main-menu return as applicable.

### 4.3. Orb tooltip rendering

Current Godot-first rule:
- For current work, update the Godot skill-orb tooltip renderer and any
  character-specific tooltip data source. Legacy Python tooltip function
  names below are reference names for parity and layout traps only.

- [ ] Audit the character-specific orb tooltip renderer
      (`_draw_smasher_skill_tooltip()` and similar paths).
- [ ] Match the existing active-skill tooltip structure instead of
      inventing a new layout. The default format is:
      Korean skill name in the header, `ACTIVE` tag, gauge-cost line,
      cooldown line, main description body, and the standard control
      hint block (CLAUDE.md §"5-orb active-skill tooltip standard
      format"): structured input rows from
      `_get_<character>_control_hint_rows()` followed by `motion_hint`
      rendered as a dim row.
- [ ] Verify the control hint block follows the standard contract:
      - Last input row ends with `("accent", "발동")` or an
        activation-word-folded accent (`"홀드 후 손 떼면 발동"`,
        `"좌회전 발동"`, etc.). Skip only when an alt-input row already
        carries the activation word.
      - Pure-prose dim rows describing outcome are NOT allowed inside
        `_get_<character>_control_hint_rows()`. Move them to
        `motion_hint` on the skill metadata row.
      - When the trigger context is too long for one row at the
        tooltip's usable width (~260px for viper/smasher), split into
        a text-only row 1 + keys-bearing row 2 with a connector word
        like `"사용 후"` / `"착지 전"` / `"타격 후"`.
- [ ] Pass `motion_hint` through the layout function:
      `_get_<character>_tooltip_control_layout(skill_name, how_to_use,
      motion_hint, font, max_width)`. Reading `motion_hint` from
      `skill_data.get("motion_hint", "")` is mandatory; the orb
      tooltip otherwise drops the dim glance line silently.
- [ ] If this tooltip family ships an effect-preview panel, treat it as
      required content, not decorative chrome. A new skill or new
      `effect_type` / preview key must render a meaningful preview scene
      there instead of leaving an empty framed box.
- [ ] Contain the preview scene to the preview panel itself. Use a
      panel-local clip / subsurface or equivalent so slashes, halos,
      particles, clone ghosts, and other animated elements cannot paint
      outside the framed effect-preview box and leak into description
      text, synergy lines, or control-hint UI.
- [ ] If the skill supports both letter keys and arrow keys, show both
      mappings in the `how_to_use` / control-hint block using the same
      existing visual style instead of documenting only one key family.
- [ ] Reuse the established tone and formatting of existing skill
      tooltips: concise action-first wording, same field order, same
      color emphasis, and no one-off sentence style that reads like a
      different UI system.
- [ ] When choosing between reusing an existing preview scene and adding
      a dedicated branch, match semantics and visual class. If nearby
      shipped previews are scene-based (character silhouette + cue +
      result), do not downgrade the new skill to a generic placeholder
      just because a box is present.
- [ ] If the preview scene includes a rendered character body, compare
      its visible body class against neighboring shipped previews in the
      same tooltip family. Do not let one character consume
      disproportionately more of the preview box just because its pose
      cache or fit box ended up larger.
- [ ] If the skill's player-facing numbers change with effective level,
      cooldown reduction, or another perk, make sure the orb tooltip
      line does not stay stale on the original metadata string.
- [ ] If a passive / enhancer perk changes this skill through runtime-
      only or otherwise hidden behavior, expose that in the target orb
      tooltip with concise synergy text instead of assuming the player
      will remember the perk description mid-run.
- [ ] If one enhancer already uses a dedicated bonus-line / synergy lane
      for this character, route new enhancers through the same shared
      helper / renderer instead of making only one perk appear in the
      orb tooltip.
- [ ] If multiple enhancers can affect the same skill, define and audit
      the shared line budget / priority rule explicitly so the tooltip
      remains readable when more than one perk is invested.
- [ ] Before appending a new synergy / bonus line to a shared-budget
      tooltip, measure the **wrapped-line count of every existing line
      at the fully invested state**. A single existing line can wrap to
      N visual lines and consume N slots of the budget by itself, which
      silently drops the appended line (Viper `검기 증폭` Lv.5
      `공 유도` append regression is the canonical failure mode). If the
      budget is saturated, prefer folding the new info into the existing
      line from the same perk family, or raise / compress the shared
      budget deliberately.
- [ ] Verify the invested-state bonus lines by **rendering** the
      max-invested tooltip and confirming every intended line is
      actually visible. "The bonus-line list contains it" is not proof
      that the player sees it.
- [ ] If the tooltip description contains `\n`, render it through the
      shared wrapped-tooltip helper. In legacy Python this was
      `_get_wrapped_tooltip_lines()` in `pingfighter.py`.
      Do not write a new `for char in description:` char-wrap loop --
      raw char iteration silently swallows `\n` on both `pygame.font`
      and `pygame.freetype`, flattening multi-sentence descriptions
      into one flowing line that wraps at the wrong spot.
- [ ] If bonus-line / synergy text changes the tooltip's vertical
      content height, recalculate the tooltip height / section anchors
      from the real rendered content instead of leaving a stale fixed
      layout.
- [ ] In the invested state, verify the `how_to_use` / control-hint
      block, lower description lines, and effect-preview panel still
      have clean separation. No overlap, clipping, or text-hidden-
      behind-preview regression.
- [ ] If the effect preview uses a procedurally drawn character, prefer
      cached neutral preview poses / surfaces over rebuilding the full
      character every hover frame, and verify the preview does not pick
      up live combat-only slash / hit / kick timer state by accident.
- [ ] If the orb tooltip is intentionally static flavor text, confirm
      that any changing numeric values are shown somewhere else
      consistently.

### 4.4. Perk / skill UI text audit

Run the full `CLAUDE.md` text audit for every new perk / skill:

Godot-first note:
- For current work, map each legacy Python UI path below to the relevant
  Godot overlay, card, HUD, tooltip, academy/NPC, victory, and debug-menu
  renderer. Do not edit Python UI paths unless explicitly asked.

- [ ] Perk choice card: `show_runtime_skill_choices()`
- [ ] Stage clear perk choice: `show_stage_clear_choices()`
- [ ] Stage clear overlay: `draw_stage_choice_overlay()`
- [ ] Perk status screen: `show_perk_status()` / `draw_level_gauge()`
- [ ] TAB character info panel: `draw_character_info_panel()`
- [ ] Tooltip paths: `draw_tooltip()` / `draw_skill_tooltip_mini()`
- [ ] Victory-screen tooltip: `show_victory_screen()`

Also audit any acquired-skill list drawers that build their own skill
data objects. If one path still reads from raw `descriptions[base_level]`
or stale metadata while another uses `get_runtime_skill_description()`,
the UI is not fully integrated.

- [ ] Treat TAB character-info perk hovers and other grid-hover tooltip
      paths as separate placement systems, not just copies of orb
      tooltips. Audit their own anchor / clamp logic explicitly.
- [ ] In `draw_character_info_panel()` and similar grid views, verify
      long perk descriptions stay readable on first-row, last-row,
      left-edge, and right-edge cells. The tooltip should flip / clamp
      instead of clipping against the panel top, panel sides, or screen
      edge.

### 4.5. Modal UI rendering / input audit

Use this when the perk or skill introduces a new popup, academy screen,
NPC choice window, or other perk-adjacent modal.

Godot-first note:
- For current work, modal ownership belongs in the Godot UI / overlay /
  modal-gate modules. Legacy `resource_path()` and font-render notes below
  are Python reference traps; in Godot, verify `res://` font/resource paths
  and scene-tree-safe modal lifecycle.

- [ ] Verify the actual font path exists in the repo and resolves through
      the current runtime resource path (`res://` in Godot; legacy Python
      used `resource_path()`).
- [ ] Do not rely on a silent `font.render()` failure path; if the font
      load fails, the UI must still remain visibly debuggable.
- [ ] Check text visibility in-game, not just compile success.
- [ ] Audit both mouse and keyboard flows for confirm / cancel / ESC.
- [ ] Confirm one-shot menu-open flags are cleared after consume,
      cancel, outside-click close, and ESC close.
- [ ] If the modal opens on top of another dialog, verify the background
      snapshot is taken after the launcher dialog is gone so old text
      does not remain as a ghosted layer.
- [ ] If a runtime perk choice can open during an item acquisition
      cinematic, treasure effect, or other blocking reward reveal, verify
      the perk modal has input priority while it is visible. The older
      reveal may be paused by the modal gate, so letting it consume click /
      confirm first can deadlock both flows.
- [ ] For panel / modal grid hover tooltips, position from the hovered
      cell / rect and audit panel-aware clamping. Top-row entries must
      be able to open below, and edge entries must stay fully visible.

### 4.6. Tooltip writing style

- [ ] Write the tooltip in the same house style as nearby existing
      perks / skills for that character.
- [ ] Keep the first line player-meaningful immediately:
      what it unlocks, what it changes, or when it triggers.
- [ ] If the skill is an unlock perk, make the tooltip clearly separate
      "perk acquired" from "actual active skill behavior" so the player
      understands what the new orb does.
- [ ] If the perk modifies another active skill, mention the target
      skill name explicitly instead of assuming the player will infer it.
- [ ] For runtime synergy / bonus lines on a target orb tooltip, keep
      the wording short, number-forward, and combat-meaningful. Do not
      dump the full perk-card paragraph into the orb tooltip.
- [ ] Avoid dumping raw implementation jargon into the tooltip unless
      the surrounding UI already uses that term.

---

## 5. Effective level, `transcendent_crown`, `sage_ring`, other perk-level buffs, and `Lv.5+`

This is the most common "looks right in one place, wrong in three other
places" bug category.

Current Godot-first rule:
- For current work, effective-level math must flow through the Godot
  runtime perk / item / character owner helpers that gameplay actually
  consumes. Legacy helper names below are reference concepts.

- [ ] Confirm whether the perk is supposed to scale from effective level
      (legacy Python: `get_runtime_skill_level()`) or from base invested
      level only.
- [ ] If the perk is supposed to scale, make sure the **gameplay path**
      reads the effective level too, not just the UI.
- [ ] For new invested passive / scaling perks, the default is that
      effective levels above `Lv.5` keep increasing real numeric power.
      Do not ship a silent overflow clamp unless the design explicitly
      calls for a hard cap.
- [ ] If the perk is NOT supposed to scale even when effective level
      rises because of `transcendent_crown`, `sage_ring`, or another
      perk-level buff source, make the UI wording reflect that clearly.
- [ ] If the perk can exceed `max_level` in a player-visible way, add
      a dynamic description path for `Lv.6+` or the relevant overflow
      range. In legacy Python this was `get_runtime_skill_description()`.
- [ ] If the perk modifies another active skill's numbers, audit the
  target skill's tooltip and HUD too.
- [ ] If the perk modifies another active skill through hidden runtime
  behavior rather than a plainly visible metadata number, audit the
  target skill's runtime synergy / bonus-line text too.
- [ ] For a multi-effect active-skill enhancer that has both an unlock
      threshold and scaling chance / overflow behavior (for example
      Viper `blade_amp`: `Lv.1-2` no homing, `Lv.3+` fixed homing plus
      scaling follow-up blade chance), verify `Lv.1-2`, `Lv.3`, `Lv.5`,
      and `Lv.6+` gameplay, description text, target orb tooltip bonus
      lines, proc gating, and recursive-spawn prevention together.

### 5.1. Cooldown-display rule

If the change affects player-skill cooldowns:

- [ ] Use the final effective cooldown helper path. Legacy Python names:
      (`_get_effective_player_skill_cooldown_seconds()` /
      `_get_effective_player_skill_cooldown_ms()`).
- [ ] If you are moving a character or a newly unlocked skill into the
      5-orb system, make sure it also enters the same cooldown-
      reduction scope as that character's other orb skills.
- [ ] Verify orb countdown text uses the same final value.
- [ ] Verify cooldown wedge timing uses the same final value.
- [ ] Verify tooltip cooldown text uses the same final value.
- [ ] Do not leave gameplay on reduced cooldown while the UI still
      displays raw `skill_data["cooldown"]`.

### 5.2. Unlock-only perks with bonus items

Unlock perks (`unlock_*`) are easy to misread under bonus items:

- [ ] If the perk is meant to stay "ACTIVE" and not become a stronger
      version at effective level 2+, confirm all UI paths still read as
      a boolean unlock rather than an upgradable numeric perk.
- [ ] If the perk *is* meant to gain extra strength from bonus items,
      that must be implemented explicitly in both gameplay and text.

---

## 6. Actual gameplay effect wiring

The perk is not done when it appears in the choice UI. It is done when
the gameplay event actually uses it.

Current Godot-first rule:
- For current work, wire the real trigger, resource gates, cooldowns,
  effect state, audio, VFX, reward, cleanup, and save/load behavior through
  the Godot character owner module and shared battle drivers.
- Python/Pygame references in this section are timing and parity references
  only.

- [ ] Find the real trigger path:
      input poll / charge path / collision path / passive stat read /
      spawn hook / hit-confirm hook.
- [ ] If the trigger is a combo / follow-up window, complete Section
      3.1a's predecessor trigger matrix before declaring the effect
      wired. Do not stop after the easiest source path works.
- [ ] If the trigger is directional input, wire the equivalent
      directional key families into the same command path by default
      (for example `A/W/D` and `LEFT/UP/RIGHT`) unless the design
      explicitly restricts it.
- [ ] Gate the skill with the correct unlock-and-equip predicate.
- [ ] Gate the skill with the correct cooldown predicate.
- [ ] Gate the skill with the correct gauge / resource predicate.
- [ ] Apply the real effect:
      projectile, buff, cleanse, pull, shield, spawn, damage mod, etc.
- [ ] If the effect applies damage, stun, slow, confusion, knockback, or
      another gameplay result through a circular / elliptical / explosion
      / aura radius, write down the intended **hit primitive** before
      coding: boss / player center-point distance, full rect overlap,
      closest-point circle-vs-rect overlap, projectile body contact, or
      field occupancy. Do not reuse a visual-overlap helper by default.
      The visual blast / glow radius and the gameplay status radius may
      share a number while still using different hit semantics.
- [ ] For boss / player CC copied from legacy Python, check whether the
      source used `get_center_pos(BOSS)`, `BOSS.centerx`, or another
      center-point distance. If so, the Godot port should test the live
      hitbox center against the radius, not `circle_intersects_rect()` or
      a rect-edge overlap. Add an edge-only regression case where the
      rectangle edge is inside the visual radius but the center is outside.
- [ ] For every radial status / damage effect, focused smoke coverage
      should include at least: center inside radius, fully outside radius,
      and edge-only overlap with center outside radius. If the effect has
      separate target-reached, wall-impact, manual-detonation, lingering
      field, or round-cleanup paths, cover each path that can apply the
      gameplay result.
- [ ] If the effect applies knockback, wire it through the real
      fire-event knockback consumption path or a thin wrapper over it.
      Avoid display-only nudges, unrelated one-off velocity globals, or
      a second decay system unless the design explicitly calls for a
      different gameplay identity.
- [ ] Start and end the cooldown in the same character-specific system
      as the existing skills.
- [ ] If the skill starts or syncs looped audio, or starts a sustained /
      stop-capable urgent SFX channel, wire both the ordinary lifecycle
      stop and the Godot round-boundary stop. The sound must stop on
      effect expiry / cancel / reset, and its `stop_*` method must be
      registered in `scripts/audio/gameplay_loop_audio_cleanup.gd` so
      scoreboards, serve wait, round restart, and game reset cannot leave
      stale sound alive.
- [ ] If that loop is synced from `battle_effects_update_controller.gd`
      or another effect update path that still runs while the scoreboard
      is visible, gate the sync or pass muted audio deps during round
      boundaries. A one-shot stop at score time is insufficient if the
      active state can immediately sync the loop back on.
- [ ] If the skill has a player-visible active duration, startup-hold,
      or timed persistence window, wire the shared right-bottom
      horizontal timer bar to the same runtime state transitions and the
      same effective duration source that owns the real effect.
- [ ] For that timer bar, verify the bottom-most active entry uses stack
      index `0` / the bottom baseline, and that extra active timers stack
      upward dynamically. A lone duration bar must not reserve a higher
      slot or appear suspended above the bottom HUD.
- [ ] If the skill owns a hit / absorb / consume reward moment, wire any
      skill-specific gold bonus at that real event path instead of at
      mere cast start or windup start.
- [ ] If the skill can be activated while a predecessor motion is still
      active, verify the input-edge check runs before that predecessor's
      update path returns, and verify the predecessor state is cancelled
      or handed off cleanly.
- [ ] If the skill throws a tracking / boomerang / recall projectile,
      audit the obvious-miss branch too. Once the projectile has
      clearly passed above / beside the target and the cast is no
      longer realistically hittable, abort outbound promptly and
      transition into the intended return / cleanup path instead of
      lingering at the apex on stale homing.
- [ ] If the skill renders a procedural homing / curved fan, wave, slash,
      or similar projectile VFX, verify the visual geometry curves too.
      Do not rely on changing only the projectile X position or only
      shifting point centers while every cross-section stays horizontal.
      The body / tail / head should follow the intended curve, and each
      slice or arc cross-section should rotate along the curve tangent.
- [ ] If homing / curve behavior is unlocked by an enhancer level or
      other runtime condition, gate both the real projectile steering and
      the visual aim / bend path through that same condition. The
      uninvested base skill should remain straight in movement and in
      rendered body posture.
- [ ] For curved fan / wave / slash helpers, add or update a focused
      geometry invariant test when feasible. Example: for a rightward
      bend, the right arc corner should move lower on screen, the left
      arc corner should move higher, and the visible Y delta should be
      large enough to prevent a "vertical projectile sliding sideways"
      read. Audit player, clone, replica, and remote/online render paths
      that may duplicate the same VFX.
- [ ] If the skill uses a detached Godot FX host (`Node2D`, `ColorRect`,
      `GPUParticles2D`, shader quad, sprite host, or similar) instead of
      direct playfield `canvas.draw_*()` calls, route layout explicitly.
      Direct playfield draws are already under the 760x750 playfield
      transform, but detached hosts need viewport-space coordinates:
      `game_offset + (playfield_pos + shake_offset) * render_scale`, and
      host sizes must also multiply by `render_scale`. Keep a direct
      canvas fallback correct until a deferred-added host is inside the
      tree. Live-check a scaled/windowed layout so top-left `0,0` leaks
      are caught.
- [ ] For detached character-skill FX hosts, asset prewarm is not enough.
      Texture / shader / material readiness must be paired with a staged
      runtime-node prewarm path (`prewarm_runtime_nodes()` or
      `prewarm_runtime_nodes_step(owner)`) that creates the hidden host and
      child layers before the first visible skill frame. Avoid first-use
      `call_deferred("add_child")` host creation when the same frame can also
      draw a procedural canvas fallback. Add or update smoke coverage that
      proves the host prewarm leaves the host hidden / inactive and that boot
      prewarm calls the runtime-node hook for the selected character.
- [ ] For detached character-skill FX hosts, do not rely on a final
      inactive draw to hide the node. The battle effect draw fanout skips
      skills once `has_visible_effects()` is false, so `reset_round()`,
      score / serve-wait cancellation, full reset, character swap, and
      skill cancel paths must directly call the owner's host hide /
      teardown helper. Add or update a focused smoke test that activates
      the host, crosses a round boundary immediately, and verifies the host
      is inactive plus any windup / flight / impact / loop audio is stopped.
- [ ] For Godot character-skill VFX ports, do not stop at a direct copy of
      the Python / Pygame procedural draw path. Preserve the original phase
      timing and gameplay state, then remaster the visible effect through
      texture pieces or sprite sheets, `ShaderMaterial`, `GPUParticles2D`,
      and `Tween` or `AnimationPlayer` unless the effect is intentionally
      tiny or only a fallback accent. Drive all visual layers from the same
      skill phase clock so windup / release / hit / linger / cleanup stay
      synced with audio, cooldown, hitstop, and HUD timers.
- [ ] Use the Godot-wide **modular VFX layering** pattern for substantial
      character-skill effects: texture fragments + runtime composition +
      shader uniform presets. Record the layer stack (backplate / glyph /
      projectile / trail / impact / residue / particles), z-order, blend
      mode, phase ownership, and normal-vs-boosted uniform values near the
      FX host or in the owning module notes.
- [ ] Before generating a new animation sheet for a subtle motion variant,
      check whether the accepted texture can be animated by shader uniform
      tuning instead: UV displacement, `lateral_strength` / tangent-side
      displacement for writhing lightning, cracks, roots, ropes, streams,
      and branching energy, noise flicker, flow bands, chromatic
      aberration, breath alpha, rim pulse, dissolve, or color ramp swaps.
      Prefer a reusable shader family plus per-skill uniforms when it
      preserves the intended read.
- [ ] If a character-skill VFX still ships as direct `canvas.draw_*()` only,
      document the exception in the handoff and identify whether it is a
      temporary parity scaffold, a deterministic geometry helper, or an
      intentionally low-cost final effect.
- [ ] Size the gold payout against comparable existing skills for the
      same character unless the design explicitly calls for unusually
      high / low reward or no reward.
- [ ] Audit the generic rally-gold path and any character-local
      duplicate-prevention flags so the same skill event cannot pay
      twice through primary + fallback hit logic.
- [ ] If the effect spawns persistent entities, clear them on reset and
      state transitions.
- [ ] If the skill captures, hides, teleports, or manually advances the
      ball in Godot, treat `skip_ball_motion_step` as owned runtime state,
      not a one-frame visual hint. Every exit path must clear the flag
      before normal ball motion resumes, including natural expiry,
      hit-release, final shot, round cancel, serve-wait cancel, and full
      reset. Add or update a focused smoke that starts with the flag true
      or observes it become true, then verifies it returns false with a
      real resumed velocity.
- [ ] If a character skill uses the ball-update collision path to advance
      its own projectile / wind-up / return timer while player movement is
      locked, verify it still ticks or intentionally cancels when another
      owner has set `skip_ball_motion_step=true` (Stage 5 Hongryun inferno,
      Poseidon capture, Stage 4 meditation, etc.). Do not let a shared ball
      motion skip starve a player-control lock until the boss / item owner
      releases the ball.
- [ ] If the skill changes legal player movement bounds, mirrored paddle
      collision, `player_pos.x`, or player paddle size / scale, audit the
      full Godot owner-sync chain. Movement and the skill module are not
      enough: active-item sync, runtime-perk sync, mythic/passive equipment
      sync, match-flow mergeback, draw context, and collision context can
      all rewrite or consume the same coordinates. Smasher `warp_gate`
      intentionally permits offscreen left / right wall-riding while
      active; every paddle-size or position sync must preserve those bounds
      instead of falling back to a plain `0..FIELD_WIDTH - paddle_width`
      clamp. Extend `godot/tests/warp_gate_port_smoke.gd` or the focused
      equivalent whenever this contract is touched.
- [ ] If the skill renders runtime clones, afterimages, low-HP variants,
      or other copied sprite / paddle surfaces with additive tint /
      noise / scanline / fade layers, clip every overlay to the visible
      silhouette of the source surface. Do not let transparent canvas
      receive the overlay, or a rectangular box can appear around the
      sprite in gameplay.
- [ ] If the perk modifies an existing active skill rather than adding a
      new one, test both the source perk and the target skill flow.

For Smasher-style work, a good question is:
"After I take the unlock perk, what exact input path now does something
new that was impossible before?"

If the answer is unclear, the runtime wiring is incomplete.

---

## 7. Persistence and lifecycle

Current Godot-first rule:
- Current persistence and lifecycle work belongs in Godot save/load state,
  character runtime state, round cleanup, stage-transition cleanup, and
  reset/menu-return paths.
- Legacy Python names below describe old gate predicates and timing traps to
  preserve during a port.

- [ ] Reset on new run / main menu return.
- [ ] Reset runtime active state on round transition by default unless an
      explicit exception was requested and documented.
- [ ] Reset temporary command buffers / input-history state on round
      transition.
- [ ] Reset charge / hold / spawned transient-entity state on round
      transition unless the design explicitly preserves it.
- [ ] Reset cooldown state.
- [ ] Reset temporary activation / glow / spawn state.
- [ ] Keep cooldown-reset helpers separate from full runtime-state reset
      helpers. Do not hide active-buff teardown inside a "cooldown reset"
      utility.
- [ ] If a skill, weapon, or state is "once per stage," save and
      restore a dedicated used-this-stage flag. Cooldown alone is not
      enough to preserve the contract across save/load.
- [ ] If a temporary / rental state should expire on the next stage
      only, clear it on the real stage-transition hook rather than on
      `reset_round()`.
- [ ] Save the unlocked-state dict if the character uses one.
- [ ] Save the equipped-skill list if the character uses one.
- [ ] Restore both on load.
- [ ] If the runtime uses a derived live list (for example equipped +
      temporary merged into one controller list), restore the canonical
      state first and rebuild the derived live list after load.
- [ ] Keep backward-compatibility behavior for older saves where
      unlocked skills may need to auto-equip on first load.
- [ ] If older saves used one combined list for ownership / equipped /
      temporary state, add an explicit migration rule that preserves the
      player's holdings instead of dropping ambiguous entries.
- [ ] If the effect depends on currently equipped items or transformed
      states, verify post-load resync still lands in the right state.
- [ ] If a debug or editor path can directly change levels,
      the current recalculation / resync path must keep the runtime
      consistent. In legacy Python this was `recalculate_skill_effects()`.
- [ ] If the perk / skill is a **character-transformation** that flips
      any character-gate predicate (for example anything routed through
      `is_odins_eye_transformed()`, `is_yachaman_transformed()`, or
      `_viper_original_skills_blocked`), the transform finalize frame
      must force the paddle to land. A Viper who is mid-jetpack when
      the gate flips will otherwise walk in mid-air because the
      legacy Python jetpack update block at `pingfighter.py:~83498` was
      gated off
      after finalize and `_viper_jetpack_offset_y` stays negative. On
      the exact finalize frame, run the current Godot equivalent of
      `_reset_viper_jetpack_state()` (Viper only) followed by the current
      paddle/equipment resync path.
      Full checklist (finalize-edge detection, ball-reposition
      ordering, reverse-path handling, current in-repo callsites)
      lives in `docs/item_runtime_checklist.md` §7. Character-
      transformation items today drive this rule; a future transform-
      style character skill must follow the same pattern.

---

## 8. Godot integration points and legacy Python reference audit

Use this as the scan list before shipping. For current work, map every
legacy Python anchor to the relevant Godot catalog, owner module, renderer,
save/load state, and smoke test before deciding the feature is complete.

| # | File / anchor | Purpose |
|---|---|---|
| 1 | `runtime_skill_levels` | Canonical invested runtime levels |
| 2 | `RUNTIME_SKILL_POOL` | Shared perk registry |
| 3 | `SMASHER_EXCLUSIVE_SKILLS` / other character pools | Character-specific registry |
| 4 | `get_runtime_skill_level()` | Effective level with bonus items |
| 5 | `get_runtime_skill_description()` | Dynamic `Lv.6+` and overflow text |
| 6 | `apply_runtime_skill_effect()` | Actual acquire / unlock / level-up behavior |
| 7 | `recalculate_skill_effects()` | Debug / load / bonus-state resync |
| 8 | `_MINI_SKILL_ICON_REGISTRY` / `draw_skill_icon_mini()` | Generic perk icon rendering |
| 9 | `_draw_skill_icon_symbol()` | Polished orb-HUD symbol |
| 10 | `show_runtime_skill_choices()` | Runtime choice card |
| 11 | `draw_stage_choice_overlay()` | Stage-clear overlay text |
| 12 | `show_stage_clear_choices()` | Stage-clear choice UI |
| 13 | `show_perk_status()` / `draw_level_gauge()` | ESC perk-status level display |
| 14 | `draw_character_info_panel()` | TAB panel |
| 15 | `draw_tooltip()` / `draw_skill_tooltip_mini()` | Generic tooltip text |
| 16 | `show_victory_screen()` | Victory tooltip path |
| 17 | Character `*_SKILL_ICONS_DATA` | Orb metadata and tooltip text |
| 18 | Character cooldown / unlocked / equipped registries | Orb runtime state |
| 19 | Character-specific orb tooltip renderer | Active-skill tooltip sync |
| 20 | Save/load keys in `save_data` | Persistence |
| 21 | Character reset functions | New-run cleanup |
| 22 | Actual gameplay trigger / update functions | Real effect path |
| 23 | `draw_skill_icon_mini()` callsites with custom `scale_multiplier` / box size | Small-box readability and alias-path audit |
| 24 | Skill-owned `add_ingame_gold()` / local duplicate-prevention path | Intentional skill reward and no double-pay against rally gold |
| 25 | `_CHARACTER_UNLOCK_PERKS`, `_are_character_skill_slots_full()`, `filter_full_slot_unlock_perks_strict()`, `_weighted_perk_sample()`, `_active_perk_weight()`, `enforce_full_slot_perk_cap()` | Full-slot filtering, weighted active-perk offers, tutorial-vs-runtime split, and card-count preservation |
| 26 | `perk_id -> skill_id` icon alias pairs (`unlock_*` id plus equipped orb id) | Same accepted motif in perk-choice / academy / NPC / swap-card path and 5-orb HUD path |
| 27 | Godot `runtime_perk_icon_renderer.gd` `UNLOCK_ALIASES` / `COMMANDO_UNLOCK_BADGE_IDS` | Godot perk-card alias to real skill-orb PNG path plus unlock-badge policy |
| 28 | Godot firearm owner stack: `commando_skill_config.gd`, `commando_weapon_controller.gd`, `commando_firearm_runtime.gd`, `commando_firearm_selector_renderer.gd`, `commando_firearm_audio_resolver.gd`, generated firearm asset manifest | Permanent firearm controller, HUD art / AutoSprite sheets, audio phase routing, lifecycle, and smoke-test ownership |

If you added a new hardcoded list not present here, add it to this table
in the same PR.

---

## 9. Smoke test before shipping

For every new character perk / skill, run this manual QA pass:

Godot-first note:
- For current work, include the repo-local Godot load check and warning scan
  after `.gd` edits, plus a focused smoke or visible review for the touched
  character / HUD / tooltip / VFX path.
- Python-specific call names in this list are legacy behavior references
  unless the user explicitly requested original PingFighter source work.

1. The perk appears only for the correct character and in the correct
   choice pool.
2. Taking the perk updates the correct runtime state:
   level-up, unlock flag, or both.
3. For an unlock perk, the new skill lands in the remaining orb slot;
   if slots are full, the swap dialog appears and the chosen result
   persists.
4. If the character uses slot-full unlock filtering, full-slot state
   suppresses the unlock perk or routes through the intended swap flow
   instead of quietly leaking into the normal perk-choice pool.
5. The perk / skill icon renders correctly in every relevant UI path;
   no first-letter fallback icon appears, no alias path lands in the
   wrong bespoke branch, and the main motif does not read materially
   smaller than adjacent shipped icons in the smallest relevant box.
   In the TAB character-info perk tab, the `dash_module_control` /
   `모듈제어` icon is the preferred small-cell size reference: polished
   and present, but not covering the bottom `Lv.1` / level label.
   For unlock-style active skills, verify both the `unlock_*` card /
   offer path and the equipped orb skill path. If the orb was converted
   to a PNG, the unlock card should not silently remain on old
   procedural art.
   In the Godot port, if the Python orb loader uses a PNG crop / zoom /
   circular-mask path such as `crop_outer_frame`, mirror that runtime
   normalization instead of drawing the oversized source texture
   directly into the slot.
6. If the orb icon is animated, cooldown / unusable / ready / active
   states are visually distinct and do not misread as "always active."
7. If the design uses a static-rest / ready-animate pattern, the orb is
   truly still before readiness and starts animating exactly when the
   skill becomes ready.
8. TAB / ESC / stage-clear / victory / tooltip text all show the same
   intended name and description, using the existing tooltip format for
   that UI path instead of a one-off layout or wording style.
9. In TAB character info and any other grid-based perk panel, first-row
   and edge-column hover tooltips with long descriptions remain fully
   readable and do not clip against the panel top or side edges.
10. With `transcendent_crown`, `sage_ring`, and/or any other intended
    perk-level bonus source equipped:
    the effective level changes where intended, the description changes
    where intended, and the real gameplay effect follows the same rule.
    For scaling perks, verify overflow effective levels above `Lv.5`
    still change the real numbers unless an explicit hard-cap exception
    was documented.
11. If the perk is boolean-only, bonus items do not create fake
    `Lv.2+` expectations in UI or gameplay.
12. The actual input / trigger fires the real effect in gameplay.
    For combo-window skills, this means every predecessor family in the
    trigger matrix opens the same intended follow-up or is explicitly
    documented as excluded.
13. If the skill uses procedural homing / curved fan, wave, slash, or
    similar VFX, the live render reads as a real curve rather than a
    vertical projectile sliding sideways. Check the body / tail / head
    curve and the rotated cross-section behavior in every affected path
    (player, clone, replica, and remote/online renderers when present).
14. If the skill uses a detached Godot GPU / node FX host, the live
    render appears at the intended playfield position in a layout where
    `game_offset` / `render_scale` are non-identity. It must not appear
    at the viewport top-left, stay one frame behind at `0,0`, or use an
    unscaled size relative to the playfield.
    Also confirm the host's texture / shader asset prewarm and runtime
    node prewarm are both wired before the first visible frame. The first
    live `sync_*_fx()` call should not both create a deferred host and
    run the expensive canvas fallback because the host is not yet inside
    the scene tree.
15. If the perk / skill changes knockback, live-check that direction,
    decay, wall behavior, and any short hitstop / release feel match the
    intended fire-event baseline or the explicitly documented
    exception.
16. If the skill uses directional input, both supported key families
    (for example `WASD` and arrow keys) trigger the same intended
    command path and match the tooltip hint.
    If the skill is a follow-up entered during another active motion,
    include at least one smoke that proves the handoff input is not
    swallowed by the predecessor update.
17. Gauge cost, cooldown start, cooldown end, orb wedge, orb countdown
    text, and tooltip cooldown line all agree with each other.
18. If the skill owns a player-visible active duration, startup-hold, or
    timed persistence window, the shared right-bottom horizontal timer
    bar appears, uses the real effective duration, stacks sanely with
    other active bars, and clears on timeout / cancel / reset /
    menu-return paths that end the real runtime state.
19. If the perk is an active-skill enhancer, the affected target orb
    tooltip shows the intended runtime synergy text with live effective
    values, and the same helper / bonus-line lane still behaves sanely
    when multiple enhancers compete for limited space. Verify that
    every intended bonus line is actually **rendered on screen** at
    the fully invested state, not merely present in the bonus-line
    list. Shared-budget tooltips silently drop extra lines once a
    single wrapped line saturates the budget.
    For multi-effect enhancers with `Lv.3+` unlock behavior plus
    scaling / overflow chance behavior, also verify the target orb
    tooltip and gameplay hit path at the disabled, unlock, max-invested,
    and overflow states.
20. If that tooltip gained bonus-line / synergy text, the invested-state
    layout still keeps the control hint and effect-preview section fully
    readable with no overlap or clipping. Multi-sentence description
    text (containing `\n`) must also render as real line breaks rather
    than one flattened paragraph; confirm by rendering the tooltip, not
    only by reading the source string.
21. If the skill owns a gold reward, the payout amount / tick cadence /
    object bonus matches the design intent, and the same event does not
    also pay generic rally gold or a fallback reward path on top.
22. Save the game, load it, and confirm unlocked / equipped state
    remains correct.
23. If the design includes stage-only temporary / rental state or a
    once-per-stage skill, save and load within the same stage and
    confirm both the temporary state and the used-this-stage flag are
    preserved correctly.
24. If the orb tooltip family includes an effect-preview panel, every
    affected active skill shows a populated preview scene there. New
    `effect_type` / preview keys do not leave an empty box, the scene
    stays clipped to the preview panel instead of bleeding into nearby
    tooltip sections, and the new preview still matches the quality /
    readability bar of neighboring shipped skills.
25. If those preview scenes include rendered character bodies, compare
    them against the nearest shipped reference in the same tooltip
    family and confirm one character does not read a full size class
    larger than peers unless that difference is intentional.
26. Cross a real stage boundary and confirm stage-only cleanup / refill
    rules happen there and not on ordinary round resets.
27. Die mid-run or return to the main menu, then confirm the character
    starts fresh with the correct reset state.
28. Cross a round boundary and confirm runtime active state follows the
    intended policy: default = ends on round transition, exception =
    explicitly documented carryover / pause-resume only.
    If the skill owns looped audio or a sustained / stop-capable urgent
    SFX channel, force the score while the sound is active and confirm it
    stays silent through scoreboard, serve wait, round restart, and game
    reset.
29. If the skill uses runtime clones / afterimages / damaged-state
    sprite copies, check the weakest / faded / critical state in live
    gameplay and verify transparent margins stay invisible. No full
    rectangular tint / noise / scanline box should appear around the
    sprite.
30. If a debug or direct-level-edit path exists for the perk, confirm
    `recalculate_skill_effects()` restores a consistent runtime state.
31. If the perk / skill is obtained through an academy / NPC modal,
    confirm the text actually renders in-game with the intended font and
    does not appear blank or nearly invisible.
32. For academy / NPC offer flows, confirm same-visit reroll,
    repurchase, and reswap behavior matches the design:
    cached if intended, exhausted after success if intended, reset only
    at the intended visit boundary.
33. For nested confirm -> offer flows, confirm the opened modal does not
    keep the previous dialog as a dim background ghost.
34. If the modal changes gold / AP / other visit currency, confirm the
    spent or granted amount persists correctly after closing the modal
    and after leaving the building.

Special QA for slot-full unlock / swap offer flows:

- [ ] Canceling the swap dialog leaves ownership, unlock flags,
      `runtime_skill_levels`, and controller / inventory state unchanged.
- [ ] Tutorial / fixed-choice flows still use strict full-slot
      suppression if that is the design, while normal random perk offers
      use the intended weighted / capped swap-offer path.
- [ ] If a full-slot cap trims sampled actives, the refill path restores
      the intended final card count before gold-conversion is appended.
- [ ] If AI / autoplay can resolve or cancel the offer, failure / cancel
      preserves the pending-choice count and matches manual semantics.

Any failure = back to the checklist.
