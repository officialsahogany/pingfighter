# Four Poisons Port Reference

Current product: Godot **환격전**. The English title is undecided; legacy names
in this port reference are compatibility/provenance identifiers.

This document preserves the agreed design for the Viper family-perk
`four_poisons` (`사독`). The original anchors below were captured from
`pingfighter.py`; treat them as frozen Python/Pygame PingFighter parity
references. New runtime work belongs under `godot/` unless the user
explicitly asks for original PingFighter source changes.

When using this document now, first map each legacy Python anchor to the
current Godot owner module, catalog, renderer, audio owner, tooltip path,
and smoke test. Do not execute the implementation directly against
`pingfighter.py`.

Companion references:

- `docs/character_skill_perk_checklist.md`
  Character runtime perk / skill integration source of truth
- `CLAUDE.md`
  hidden-knowledge rules for perk icon rendering, seven UI text paths,
  alias audits, and swap / cancel semantics
- `AGENTS.md`
  routing rules; not the owner of this runtime skill work unless boss
  sprites are also touched

Legacy Python code anchors in `pingfighter.py` (snapshot used for this
spec; audit current Godot owners before implementation):

- `get_runtime_skill_level()` near `pingfighter.py:20347`
- `get_runtime_skill_description()` near `pingfighter.py:20371`
- `VIPER_EXCLUSIVE_SKILLS` near `pingfighter.py:21183`
- Viper unlock perks `unlock_dive_strike`, `unlock_chaos_spear`,
  `unlock_dual_glitch`, `unlock_ignition_aura` near
  `pingfighter.py:21195+`
- `_draw_skill_icon_symbol()` near `pingfighter.py:8533`
- `draw_skill_icon_mini()` near `pingfighter.py:25151`
- `apply_runtime_skill_effect()` near `pingfighter.py:23786`
- `recalculate_skill_effects()` near `pingfighter.py:24004`
- Viper skill metadata entries for `dive_strike`, `chaos_spear`,
  `dual_glitch`, `ignition_aura` near `pingfighter.py:4886-4935`
- Chaos Spear state / cancel globals near `pingfighter.py:5060-5079`
- Dual Glitch state globals near `pingfighter.py:5097-5101`
- `_teardown_dual_glitch_runtime_state()` near `pingfighter.py:5778`
- `_start_viper_dual_glitch()` / `_update_viper_dual_glitch_runtime()`
  near `pingfighter.py:5858` / `5899`
- `_start_viper_chaos_spear()` / `_cancel_viper_chaos_spear()` near
  `pingfighter.py:6602` / `6658`
- Ignition Aura runtime note saying `get_runtime_skill_level()` applies
  the +2 bonus near `pingfighter.py:91335-91338`

---

## 1. Goals / Non-goals

### 1.1. Goals

- Add a new Viper family perk:
  `four_poisons` / `사독`
- Make it a general passive perk, not an active-perk / unlock-perk
- Support four Viper skills:
  `dive_strike`, `nerve_strike`, `chaos_spear`, `dual_glitch`
- Define `사독` as a hybrid family perk:
  - tempo / startup axis:
    `EMP 스트라이크`, `카오스 스피어`
  - duration / pressure axis:
    `베놈 엣지`, `듀얼 글리치`
  - shared axis from Lv.3:
    cooldown reduction + startup super armor
- Normalize the baseline cancel rule so the three startup-type Viper
  skills all behave the same before `사독` mitigation:
  `EMP 스트라이크`, `카오스 스피어`, `듀얼 글리치`

### 1.2. Non-goals

- This pass does not add the previously discussed economy bonus
  (`dual_glitch` rally-gold bonus / Chaos Spear gold doubling)
- This pass does not redesign Viper sprites or unrelated item systems
- This pass does not convert `four_poisons` into an active-skill perk or
  add it to active-perk weighted sampling
- This pass does not add a new academy-only teaching flow; it is a
  normal passive perk in the Viper perk pool

---

## 2. Final Perk Spec

### 2.1. Identity

- Perk id: `four_poisons`
- Display name: `사독`
- Character: `viper`
- Max level: `5`
- Pool classification: general passive perk
- Theme color: Viper purple / magenta family

### 2.2. Target skills

- `dive_strike` / EMP 스트라이크
- `nerve_strike` / 베놈 엣지
- `chaos_spear` / 카오스 스피어
- `dual_glitch` / 듀얼 글리치

### 2.3. Final level table

| Lv | EMP startup | EMP sleep | Venom confusion | Chaos startup | Dual Glitch duration | Sub-effect |
|---|---:|---:|---:|---:|---:|---|
| 1 | -8% | +5% | +10% | -8% | +7% | - |
| 2 | -16% | +10% | +20% | -16% | +14% | - |
| 3 | -25% | +15% | +30% | -25% | +20% | 4 skills cooldown -10% + startup super armor |
| 4 | -33% | +20% | +40% | -33% | +27% | 4 skills cooldown -15% + startup super armor |
| 5 | -40% | +25% | +55% | -40% | +33% | 4 skills cooldown -20% + startup super armor |

Interpretation:

- `EMP 스트라이크` is already strong on sleep, so its main buff axis is
  faster startup; sleep extension is intentionally modest
- `카오스 스피어` keeps its strong lockdown identity and is buffed via
  faster startup, not longer lockdown
- `베놈 엣지` remains the longest-duration crowd-control axis in this
  family
- `듀얼 글리치` is the long-pressure / presence axis

### 2.4. Perk-pool gating

- `four_poisons` is included in the normal Viper perk pool only when at
  least one skill in `_FOUR_POISONS_AFFECTED_SKILLS` is currently
  unlocked in `_viper_skill_unlocked`
- The gate is intentionally based on the **current build / current
  unlock state**, not on a separate durable ownership concept
- Rationale:
  `four_poisons` is a pure modifier perk and has no baseline effect when
  none of its four target skills are currently unlocked, so surfacing it
  with zero active targets is treated as a dead offer
- Implementation location:
  keep this gate in the normal Viper perk-pool filtering path alongside
  other character-specific pool filters such as Smasher
  `extension_gear`
- Out-of-scope TODO:
  durable ownership semantics vs. current unlock-state semantics for
  Viper unlock-style skills are a separate cleanup task and are **not**
  changed by this spec

---

## 3. Baseline Cancel Rule + Super Armor

### 3.1. Stage 1 baseline rule (independent of `사독`)

While in startup / windup:

- `카오스 스피어`: already cancelable on ball contact; keep this
- `EMP 스트라이크`: make cancelable on ball contact
- `듀얼 글리치`: make cancelable on ball contact

Use Chaos Spear as the reference behavior for:

- cancel timing
- visual cancel feedback
- cost / cooldown handling policy

Implementation note:

- Before copying the behavior, inspect the existing Chaos Spear cancel
  path and match its real semantics exactly
- Do not silently invent a different refund / no-refund policy for EMP
  or Dual Glitch

### 3.2. Stage 2 `사독` mitigation

If effective `four_poisons` level is `>= 3`:

- `EMP 스트라이크`, `카오스 스피어`, and `듀얼 글리치` startup no
  longer breaks on ball contact

Super armor definition:

- startup cancel immunity only
- scoring / damage outcome still happens normally
- this is not invulnerability

In plain terms:

- ball contact can still concede the point
- but the startup is not canceled and the skill still resolves

---

## 4. Effective-Level Rule

Use the effective perk level, not the raw invested level.

Current in-repo comment near `pingfighter.py:91335-91338` says:

- Ignition Aura sets `_viper_ignition_aura_active = True`
- `get_runtime_skill_level()` then adds the +2 bonus under the same rule
  family as `transcendent_crown` / `sage_ring`

Implementation rule:

- use `get_runtime_skill_level("four_poisons") >= 3`
  for the startup-super-armor gate

Guardrail:

- do not read `runtime_skill_levels["four_poisons"]` directly for the
  super-armor decision
- if a targeted path cannot conveniently call `get_runtime_skill_level()`,
  add a small helper such as `_is_four_poisons_super_armor_active()`
  that centralizes the effective-level check

Expected synergy:

- `사독` Lv.1 or Lv.2 + active Ignition Aura should temporarily cross
  the `>= 3` threshold and gain startup super armor

---

## 5. Cooldown Stacking Policy

`four_poisons` cooldown reduction stacks additively with existing bonus
sources such as:

- `transcendent_crown`
- `sage_ring`

Examples:

- `사독` Lv.3 = `-10%`
- `사독` Lv.5 = `-20%`
- if another source grants `-10%`, total becomes `-30%`

Do not change this to multiplicative stacking in this pass.

---

## 6. Runtime Implementation Plan

### 6.1. Registry / perk-definition work

- Add `four_poisons` to `VIPER_EXCLUSIVE_SKILLS`
- Mark it as a normal Viper passive perk, not an unlock-style active perk
- Add description / detail text for Lv.1-5 behavior

### 6.2. Effect application work

- Handle `four_poisons` in `apply_runtime_skill_effect()`
- Mirror behavior in `recalculate_skill_effects()`
- Make sure all gameplay reads use effective level where appropriate

### 6.3. Skill-specific runtime hooks

- EMP:
  - startup duration reduction
  - sleep duration multiplier
  - startup cancel on ball contact unless super armor is active
- Venom:
  - confusion duration multiplier
- Chaos Spear:
  - startup duration reduction
  - existing cancel path becomes the shared reference path
  - startup cancel immunity at effective level >= 3
- Dual Glitch:
  - active duration multiplier
  - startup cancel on ball contact unless super armor is active
  - teardown should use `_teardown_dual_glitch_runtime_state()`

### 6.4. Shared helper work

Recommended helper:

- `_is_four_poisons_super_armor_active()`

Behavior:

- returns `get_runtime_skill_level("four_poisons") >= 3`

Optional second helper if needed:

- a small cooldown-adjust helper used by all four affected Viper skills

---

## 7. UI / Text / Icon Integration

Follow the repo's character-perk checklist and CLAUDE hidden-knowledge
rules for seven-path UI sync.

Required:

- `draw_skill_icon_mini()` branch for `four_poisons`
- `_draw_skill_icon_symbol()` branch if the perk appears in orb-adjacent
  or small symbolic UI
- runtime perk-choice card
- ESC perk-status panel
- TAB character info panel
- tooltip path(s)
- victory / summary path if it lists perk text
- any stage-clear / academy / status-preview path that renders Viper
  perk text or icons

Quality rule:

- audit the actual runtime ids and alias routes
- do not leave a fallback first-letter icon in any small-box UI

---

## 8. QA Checklist

### 8.1. Baseline cancel QA

- Without `사독`, Chaos Spear startup still cancels on ball contact
- Without `사독`, EMP startup now cancels on ball contact
- Without `사독`, Dual Glitch startup now cancels on ball contact
- EMP and Dual Glitch use the same cancel-policy family as Chaos Spear
  for visual feedback and cost / cooldown semantics

### 8.2. `사독` level QA

- Each level applies the intended startup / duration / cooldown changes
- Lv.3 is the first level that grants startup super armor
- Lv.1-2 do not grant startup super armor without effective-level boosts

### 8.3. Ignition Aura synergy QA

- `사독` Lv.1 + Ignition Aura:
  effective level crosses 3 and startup super armor turns on
- `사독` Lv.2 + Ignition Aura:
  effective level crosses 3 and startup super armor turns on
- When Ignition Aura expires, startup super armor is removed correctly

### 8.4. Super armor semantics QA

- With super armor active, ball contact does not cancel startup
- With super armor active, scoring still happens normally
- No hidden invulnerability is introduced

### 8.5. Reset / edge-case QA

- round end during startup does not leave stale Viper startup state
- death / main-menu return resets all affected states cleanly
- load / recalc / debug level edits restore a consistent runtime state
- Dual Glitch clone teardown leaves no ghost collisions or visuals
- Chaos Spear cancel flash / state reset still behaves correctly

### 8.6. UI QA

- `사독` icon renders correctly in every relevant UI path
- name / description text is synchronized across all live text surfaces
- no alias path falls back to a broken icon or wrong description

---

## 9. Recommended Implementation Order

1. Stage 1:
   baseline startup-cancel parity for EMP / Chaos / Dual Glitch
2. Verify cancel semantics and reset behavior
3. Stage 2:
   add `four_poisons` perk registry, scaling hooks, cooldown hooks, and
   startup super armor
4. Verify Ignition Aura effective-level synergy
5. Finish UI / icon / tooltip sync and manual QA

This order is intentional:

- it isolates the baseline cancel-rule change from the perk itself
- it makes regressions easier to bisect
- it avoids shipping `사독` before the underlying startup-rule family is
  consistent

---

## 10. Future Extension: Lv.5 Clone Skill Replication

Deferred to a second-iteration PR. Upgrades `사독` Lv.5 from a pure
numeric capstone to a gameplay breakpoint by letting `dual_glitch`
clones replicate a narrow whitelist of Viper projectile / strike skills
while the clone is in its active phase.

Quick scope summary:

- Unlock condition:
  effective `four_poisons` level `>= 5` AND
  `_viper_dual_glitch_state == "active"`
- First-pass replicated skills:
  `blade_rush` / `dark_blade` / `dive_strike` / `nerve_strike`
- Permanent exclusions:
  kick family (`marshal_kick`, `phantom_kick`, `core_flip`),
  `shadow_step`, `chaos_spear`, `ignition_aura`
- Non-negotiable guards:
  no extra gauge cost, no extra cooldown, no extra gold payout,
  strong hit / CC / damage / attack-speed effects apply once per cast
  (clones expand spatial coverage, not raw output)

Full design spec, per-skill replication behavior, guards rationale,
and QA checklist live in:

- `docs/dual_glitch_clone_replication_handoff.md`

---

End of handoff.
