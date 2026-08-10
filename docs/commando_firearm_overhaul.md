# Commando Firearm Overhaul Port Reference

Current product: Godot **환격전**. The English title is undecided; legacy names
in this port reference are compatibility/provenance identifiers.

This document preserves the agreed design for the `soldier` / Commando
firearm-system rework. The original anchors below were captured from
`pingfighter.py`; treat them as frozen Python/Pygame PingFighter parity
references. New runtime work belongs under `godot/` unless the user
explicitly asks for original PingFighter source changes.

When using this document now, map each legacy anchor to the current Godot
Commando owner module, firearm runtime, renderer, audio owner, tooltip path,
save/load state, and smoke test before implementing.

Companion references:

- `docs/character_skill_perk_checklist.md`
  Character runtime perk / skill integration source of truth
- `CLAUDE.md`
  hidden-knowledge rules for perk icon rendering, seven UI text paths,
  and final-cooldown HUD consistency
- `AGENTS.md`
  not the owner of this runtime skill work unless boss-sprite runtime is
  also touched

Legacy Python code anchors in `pingfighter.py` (snapshot used for this
spec; audit current Godot owners before implementation):

- `SOLDIER_SKILL_ICONS_DATA` near `pingfighter.py:12469`
- `_draw_soldier_skill_icons()` near `pingfighter.py:12715`
- `soldier_weapon_unlocks` / `grant_soldier_weapon_degraded()` near
  `pingfighter.py:20129` / `20162`
- `_CHARACTER_UNLOCK_PERKS` / `filter_full_slot_unlock_perks()` near
  `pingfighter.py:22092` / `22136`
- `show_perk_status()` local `get_acquired_skills()` near
  `pingfighter.py:29279`
- `activate_supply_drop_item()` near `pingfighter.py:63716`
- `soldier_controller = SoldierWeaponController()` near
  `pingfighter.py:64981`
- `check_weapon_degradation()` near `pingfighter.py:65006`
- `trigger_soldier_emergency_supply()` near `pingfighter.py:65320`
- `save_game_progress()` / `apply_loaded_progress()` /
  `apply_pending_ammo_restore()` near
  `pingfighter.py:95893` / `96160` / `96484`
- stage-clear increment `current_stage += 1` near `pingfighter.py:176174`
- stage-start path where `current_stage = stage_num`,
  `reset_soldier_skill_cooldowns()`, and `reset_round(is_stage_start=True)`
  run near `pingfighter.py:177035+`

---

## 1. Goals / Non-goals

### 1.1. Goals

- Convert the four Commando-exclusive unlock firearms into true
  character-skill / orb skills:
  `net_gun`, `fire_support`, `bowling_trap`, `suicide_drone`
- Keep `supply_drop` and `emergency_supply` as the two base Commando
  orb skills
- Make permanently unlocked Commando firearms survive across stages and
  appear in the 5-orb HUD
- Replace the old "degraded / obsolete" concept with a clear
  "rental" concept for supply-drop firearms
- Make supply-drop firearms stage-local, non-persistent, and never part
  of the 5-orb permanent skill budget
- Remove the current firearm-drop probability penalty that becomes too
  harsh once the player holds multiple firearms

### 1.2. Non-goals

- This document does not redesign boss sprites, item icon generation, or
  unrelated item-runtime systems
- This pass does not require a generic rewrite of every firearm system in
  the game
- `pistol` remains outside the 5-orb HUD
- Rental firearms remain outside the 5-orb HUD
- Unless explicitly changed in a later task, the first-pass 5-orb
  permanent-firearm conversion applies to the four Commando-exclusive
  unlock firearms listed above
- Existing non-perk firearm paths such as `bazooka` / `ak47` are not the
  identity anchor of this redesign and should not silently dictate the
  new orb model

---

## 2. Data Model

### 2.1. Canonical runtime state

The new model must keep three concepts separate:

1. Permanent ownership:
   firearms the run has permanently unlocked via Commando perk choices
2. Permanent equipped-orb set:
   up to three permanent firearms currently occupying Commando orb slots
3. Rental holdings:
   temporary firearms obtained from `supply_drop`, removed on the next
   real stage transition

`soldier_controller.weapons` must become a **derived runtime list**, not
the sole source of truth.

Required rule:

- Do not let `soldier_controller.weapons` remain the only authoritative
  model for ownership, equip state, and rental state at the same time

Recommended runtime shape:

```python
soldier_permanent_owned_weapons: set[str]
_soldier_equipped_skills: list[str]   # includes base 2 + up to 3 permanent firearms
soldier_rental_weapons: dict[str, dict]
```

Derived runtime list:

```python
soldier_controller.weapons = ["pistol"] + equipped_permanent_firearms + rental_firearms
```

Where:

- `equipped_permanent_firearms` is the orb-equipped subset of the owned
  permanent firearms
- `rental_firearms` is the current-stage temporary list only

### 2.2. Locked base orb slots

The first two Commando orb slots are fixed:

1. `supply_drop`
2. `emergency_supply`

Only the final three orb slots are swappable shared slots.

This means:

- `supply_drop` and `emergency_supply` are not removable during the
  permanent-firearm / passive swap dialog
- shared slots 3-5 are occupied by the combined pool of
  `net_gun`, `fire_support`, `bowling_trap`, `suicide_drone`, and
  `soldier_pistol_perk`
- when the three shared slots are already full, both firearm unlock
  perks and `soldier_pistol_perk` must be filtered out of the normal
  perk-choice pool

### 2.3. Runtime-derived controller rebuild rule

Whenever permanent equip state or rental state changes:

- rebuild `soldier_controller.weapons`
- preserve the currently selected weapon if it still exists
- otherwise fall back to `"pistol"`

Do not attempt to infer permanent vs rental only from the current order
inside `soldier_controller.weapons`.

---

## 3. 5-Orb / HUD Rules

### 3.1. Slot budget

Commando orb budget is exactly five slots:

- base slot 1: `supply_drop`
- base slot 2: `emergency_supply`
- shared slot 3-5: permanent Commando firearms plus
  `soldier_pistol_perk`

The permanent-firearm unlock pool is:

- `net_gun`
- `fire_support`
- `bowling_trap`
- `suicide_drone`

If the player owns `soldier_pistol_perk`, it consumes one of the three
shared slots. This means Commando can show either:

- three permanent firearms and no pistol perk, or
- pistol perk plus up to two permanent firearms

### 3.2. Required new soldier-side slot plumbing

Commando needs a real equipped/unlocked orb-skill model, parallel to the
existing Smasher/Viper pattern.

Required soldier-side additions:

- `_soldier_skill_unlocked`
- `_soldier_equipped_skills`
- `SOLDIER_MAX_SKILL_SLOTS = 5`
- `is_soldier_skill_slots_full()`
- `get_soldier_equipped_skills()`
- `equip_soldier_skill()`
- `swap_soldier_skill()`
- `unlock_soldier_skill()`
- `_show_soldier_skill_swap_dialog()`

Use the existing themed swap-dialog pattern rather than inventing a
parallel UI.

### 3.3. Unlock-perk filtering

Commando must participate in the same "hide unlock perks when skill
slots are full" behavior used by Smasher and Viper.

Required changes:

- add a `soldier` branch to `_CHARACTER_UNLOCK_PERKS`
- add `soldier` support to `_are_character_skill_slots_full()`
- make `filter_full_slot_unlock_perks()` hide Commando unlock perks when
  the three shared Commando slots are already full

The runtime meaning is:

- slot fullness is counted from shared-slot occupancy, not only from the
  number of equipped permanent firearms
- if Commando already has three shared-slot skills equipped, the next
  firearm unlock perk or `soldier_pistol_perk` must not appear on the
  normal perk choice screen

### 3.4. `SOLDIER_SKILL_ICONS_DATA` ownership change

`SOLDIER_SKILL_ICONS_DATA` must become metadata, not visible-order truth.

After the refactor:

- the table can contain metadata rows for all Commando orb-capable skills
- the actually visible orb lineup must be driven by
  `_soldier_equipped_skills`, not by `len(SOLDIER_SKILL_ICONS_DATA)`
- `_soldier_equipped_skills[0]` and `[1]` are reserved for the fixed base
  slots `supply_drop` and `emergency_supply`
- `_soldier_equipped_skills[2:5]` is the only swappable shared-slot orb
  slice and can include `soldier_pistol_perk`

`_draw_soldier_skill_icons()` must stop assuming "every entry in
`SOLDIER_SKILL_ICONS_DATA` is visible."

### 3.5. Orb behavior by skill type

Base skills:

- `supply_drop`:
  normal orb skill, existing gauge + cooldown behavior
- `emergency_supply`:
  normal cooldown-based base skill with a 120-second tunable base
  cooldown; it can be reused in the same stage after cooldown recovery

Permanent firearm orb skills:

- each permanent firearm uses ammo as stage budget
- each shot also starts its own short cooldown wedge
- cooldown durations must live in a dedicated tunable constant block such
  as `PERMANENT_FIREARM_COOLDOWNS = {...}` rather than being scattered
  inline through activation code or HUD code
- if ammo reaches zero, the orb remains disabled until the next real
  stage start

Cooldown-scope rule:

- Commando permanent-firearm orb cooldowns are inside the same cooldown-
  reduction scope used by the other 5-orb characters
- `transcendent_crown`, `sage_ring`, and any generic cooldown-reduction
  perk / effect that applies to character orb skills must also apply to
  Commando permanent-firearm orb cooldowns
- orb wedge fill, remaining-time text, and tooltip cooldown text must
  all read the same final effective cooldown value after reductions
- do not pipe a raw cooldown constant directly into HUD rendering while
  gameplay uses a different reduced value

Rental firearms:

- never occupy an orb slot
- never consume one of the three permanent-firearm orb slots
- must display in a separate Commando HUD area as temporary rentals,
  with a visible `"대여"` badge or equivalent marker

- if rental ammo reaches zero mid-stage, the rental must be removed
  immediately from the rental inventory / HUD instead of waiting for the
  next stage transition

### 3.6. Icon/UI audit requirements

This overhaul must explicitly audit:

- `draw_skill_icon_mini()`
- `_draw_skill_icon_symbol()`
- Commando orb tooltip rendering path
- all seven perk / skill text render paths from `CLAUDE.md`

New / changed Commando skill ids that require icon / HUD audit:

- `supply_drop`
- `emergency_supply`
- `net_gun`
- `fire_support`
- `bowling_trap`
- `suicide_drone`
- their related unlock-perk ids

### 3.7. ESC / TAB / victory acquired-skill lists

`show_perk_status()` currently builds acquired-skill lists without
including `SOLDIER_EXCLUSIVE_SKILLS`.

This overhaul must fix that as part of the base integration work.

Required rule:

- Commando-exclusive perks and unlocks must appear anywhere the other
  character-specific perk pools already appear

### 3.8. `soldier_pistol_perk` as a slot passive

`soldier_pistol_perk` is a Commando shared-slot passive, not a separate
out-of-band perk anymore.

Required runtime meaning:

- it occupies one of Commando's three shared slots
- it keeps its current passive behavior: base weapon changes from
  slingshot to pistol
- it has no gauge cost, no cooldown, and no active trigger
- it still needs full orb-icon / tooltip / perk-card support like the
  other Commando slot skills

---

## 4. Supply-Drop Rules

### 4.1. Acquisition split

Permanent vs rental acquisition paths must be hard-separated.

Permanent firearms:

- acquired only through Commando unlock perks
- permanently owned for the run
- eligible for the three permanent firearm orb slots

Rental firearms:

- acquired only through `supply_drop`
- stage-local only
- never treated as permanent orb skills

### 4.2. Supply-drop firearm pool

Remove the current firearm drop-probability penalty:

- delete the `owned_firearm_count` / `firearm_penalty` weighting rule

New firearm pool rule:

- supply drop may roll firearms that the player does not currently hold
- a firearm already permanently owned must not be offered again as a
  rental duplicate
- a firearm already currently rented must not be offered again as a
  rental duplicate

For the first pass, the firearm pool can continue to include legacy
firearm entries already present in the supply-drop table, but the new
permanent-orb model only applies to the four Commando-exclusive unlock
firearms unless a later task expands that scope explicitly.

### 4.3. New rental activation path

Do not keep using the current generic `activate_supply_drop_item()` path
for Commando firearm rentals unchanged.

Required runtime split:

- normal non-firearm items: existing path
- firearm rentals: dedicated rental-acquire path such as
  `activate_supply_drop_rental()`

Rental-acquire behavior must:

- add the firearm as a rental entry
- set `kind = "rental"`
- set `acquired_stage = current_stage`
- initialize ammo/runtime state
- rebuild the derived controller list
- mark the HUD as rental, not permanent

### 4.4. Rental reload policy

The reworked rental model replaces the old degraded model.

Default rule for this overhaul:

- any path that previously refused to reload / refresh degraded Commando
  weapons should continue to refuse rentals unless explicitly redesigned

This keeps rentals meaningfully temporary and prevents a silent
"pseudo-permanent" path through support systems.

Audit at minimum:

- `emergency_supply`
- `ammo_box`
- any weapon-specific reload helper that previously checked
  `soldier_controller.degraded`

---

## 5. Stage-Transition Rules

### 5.1. True stage transition only

Rental cleanup and full firearm refill belong on the **real stage
transition path**, not on score-round reset.

Required rule:

- do not place rental cleanup or stage refill logic inside
  `reset_round()`

Use the actual stage-transition path:

- stage clear where `current_stage += 1`
- stage start path where `current_stage = stage_num`,
  `reset_soldier_skill_cooldowns()`, and
  `reset_round(is_stage_start=True)` run

### 5.2. Stage-start actions

At the next real stage start, do all of the following in one coherent
stage-entry pass:

1. remove any rental firearm whose `acquired_stage < current_stage`
2. refill all permanent Commando firearms to their stage-start ammo
   state
3. clear Commando down-tap / toast transient state
4. rebuild the derived `soldier_controller.weapons` list

Recommended order:

- cleanup rentals first
- then refill permanent firearms
- then restore selection / rebuild HUD state

### 5.3. Ammo restore at stage start

Stage-start refill must not be limited to `pistol` only.

Required runtime meaning of "ammo refills every stage":

- `pistol` refills at stage start as it already does
- each permanent Commando firearm refills at stage start
- rentals are removed instead of refilled

This must be handled on the stage-start path, not only in save/load
restore helpers.

---

## 6. `emergency_supply` Redefinition

### 6.1. New identity

`emergency_supply` is no longer a degraded-weapon recovery system.

New definition:

- base Commando orb skill
- 120-second cooldown-based refill skill
- targets the **currently selected permanent Commando firearm only**
- fully refills that firearm's ammo
- does not affect rentals
- does not affect `pistol`
- cooldown state survives save/load through remaining-time restoration

### 6.2. Valid-use conditions

The skill should only consume gauge / stage-use when all of the
following are true:

- the player is Commando
- the current selected weapon is one of the permanent Commando orb
  firearms
- that firearm is currently equipped / active in the permanent model
- the firearm is not rental
- the firearm is not already at full ammo
- `emergency_supply` itself is not currently on cooldown

Invalid cases should fail cleanly without spending gauge or starting the
cooldown.

### 6.3. HUD state

Required UI meaning:

- before use:
  available if gauge and target conditions are satisfied
- after use:
  disabled until its cooldown finishes
- tooltip / orb wedge / right-side crate UI all show the same effective
  cooldown after cooldown-reduction effects
- save/load restores the remaining cooldown instead of a stage-use flag

### 6.4. Input path

Unless explicitly changed in a later task, keep the existing Commando
double-tap-down input path as the activation input.

The refactor should change what the skill does, not silently redesign
the player input without a separate decision.

---

## 7. Save / Load and Backward Compatibility

### 7.1. New persistence requirements

The save data must preserve:

- permanent owned firearms
- permanent equipped-orb firearm set
- rental firearm entries
- rental `acquired_stage`
- current selected weapon if still valid
- per-weapon ammo states
- Commando emergency-supply stage-use flag

### 7.2. Rental persistence rule

Rentals must survive save/load **within the same stage**.

Required meaning:

- if the player saves mid-stage with a rental firearm, loading that save
  in the same stage restores the rental firearm
- the rental is only removed when the game actually advances to a later
  stage number

### 7.3. Legacy save migration

Old saves may contain only the current coarse weapon list.

Required migration rule:

- if legacy `soldier_weapons["weapons"]` is just `list[str]`, do not
  drop or delete those weapons during migration because the old format
  cannot reliably infer permanent vs rental origin

Safe migration bias:

- preserve legacy non-pistol weapons rather than risking player weapon
  loss on first post-patch load
- if a legacy save implicitly has both three firearm slots and
  `soldier_pistol_perk`, normalize the shared-slot layout to the new
  three-slot budget on load
- legacy `emergency_supply_used` may be read for compatibility, but it
  must not be restored as authoritative runtime state anymore

At minimum:

- classify legacy data into a migration-safe preserved state
- rebuild the new runtime model from that preserved data
- do not let first-load migration silently remove ambiguous firearms

### 7.4. Old degradation fields

Legacy save fields such as:

- `reload_counts`
- `degradation_thresholds`
- `degraded`

must not remain authoritative after the rental-system conversion.

Migration may read them for compatibility if needed, but the new runtime
must use explicit rental/permanent state instead of reviving the old
degradation model as hidden legacy state.

---

## 8. UI Text Replacement Scope

### 8.1. Terminology change

Replace the old Commando "degraded / obsolete" concept with "rental."

Required user-facing meaning:

- permanent Commando firearms do not become degraded
- supply-drop firearms are marked as rentals and disappear on the next
  real stage transition

### 8.2. Required audit targets

At minimum, audit and update:

- Commando unlock-perk `detail` text
- Commando logs / debug text
- Commando weapon HUD warning label
- Commando reload / support failure text
- `localization/ko.json`
- `localization/en.json`
- `localization/ja.json`
- `localization/zh.json`

Known current anchors include strings such as:

- perk detail lines that currently say `"노후화 상태로 지급"`
- weapon-HUD warning label `"노후화"`
- refusal strings for support systems that mention degraded weapons
- `localization/ko.json` ammo-box description that explicitly says
  `"노후화된 화기류"`

### 8.3. Rental badge requirement

Rentals must be visually distinguishable from permanent firearms.

Required rule:

- rental firearms need a visible `"대여"` badge, tag, or equivalent HUD
  marker in their separate Commando rental area
- do not reuse the old degraded triangle warning as the only signifier

---

## 9. Verification Checklist

Before calling the overhaul done, verify all of the following.

### 9.1. Runtime structure

- [ ] `soldier_controller.weapons` is derived from separate permanent /
      equipped / rental state, not the only source of truth
- [ ] base Commando orb slots stay locked as
      `supply_drop` + `emergency_supply`
- [ ] Commando shared-slot skills cap at three
- [ ] `soldier_pistol_perk` consumes one shared slot when owned

### 9.2. Perk / orb integration

- [ ] Commando has real equipped/unlocked orb state comparable to the
      existing character skill systems
- [ ] `_CHARACTER_UNLOCK_PERKS` includes the Commando unlock mapping
- [ ] `filter_full_slot_unlock_perks()` hides Commando unlock perks when
      the shared Commando slots are full
- [ ] `draw_skill_icon_mini()` is audited for all Commando skill ids
- [ ] `_draw_skill_icon_symbol()` is audited for all Commando orb ids
- [ ] Commando orb tooltip text follows the established active-skill
      format
- [ ] Commando entries appear in ESC perk status, TAB character info,
      and victory / tooltip paths

### 9.3. Supply drop / rental behavior

- [ ] supply-drop firearm probability penalty is removed
- [ ] supply-drop firearms use rental acquisition path, not permanent
      unlock path
- [ ] permanently owned firearms do not re-drop as rentals
- [ ] currently rented firearms do not duplicate-drop
- [ ] rentals never appear in the 5-orb HUD
- [ ] rentals do appear in a separate rental HUD area with a visible
      rental tag
- [ ] depleted rentals disappear immediately when ammo reaches zero

### 9.4. Stage transition

- [ ] rentals survive same-stage save/load
- [ ] rentals disappear on the next real stage transition
- [ ] permanent firearms refill on stage start
- [ ] stage-start refill / rental cleanup does not run on ordinary
      score-round reset

### 9.5. `emergency_supply`

- [ ] `emergency_supply` only refills the currently selected permanent
      Commando firearm
- [ ] it does not refill `pistol`
- [ ] it does not refill rentals
- [ ] it fails cleanly if the current weapon is invalid or already full
- [ ] it uses a cooldown instead of a once-per-stage flag
- [ ] cooldown state survives save/load
- [ ] the right-side Commando crate UI reflects cooldown / remaining
      time instead of `x1`

### 9.6. Text / migration / compatibility

- [ ] permanent Commando paths no longer rely on degraded-state logic
- [ ] rental-state terminology fully replaces degraded terminology in
      user-facing text
- [ ] old save data migrates without silently deleting legacy firearms
- [ ] old degradation save fields no longer define live runtime behavior

### 9.7. Mandatory live sanity checks

- [ ] unlock one permanent Commando firearm and confirm it appears in
      the orb HUD
- [ ] unlock a fourth permanent Commando firearm and confirm swap dialog
      appears
- [ ] acquire a firearm from `supply_drop` and confirm it is marked as
      rental, outside the orb HUD, and removed next stage
- [ ] save and load in the same stage with a rental firearm and confirm
      it persists
- [ ] save and load after using `emergency_supply` in the same stage and
      confirm the once-per-stage lock remains
- [ ] advance to the next stage and confirm rentals are gone while
      permanent firearms refill

### 9.8. Firearm hit geometry / radial CC

- [ ] For explosive / radial firearms (`bazooka`, `fire_support`,
      `suicide_drone`, and any future explosive rental / permanent
      firearm), compare the live Godot hit primitive against the Python
      reference before signing off. Python bazooka, grenade-style fire
      support, and suicide drone boss CC use boss-center distance for the
      stun / knockback result; Godot must not promote a visual
      circle-vs-rect edge touch into a boss status hit.
- [ ] Keep projectile-body collision, net / trap capture geometry, and
      visual explosion overlap separate from status-result geometry. A
      helper such as `circle_intersects_rect()` is valid for physical
      overlap and some hazards, but center-distance effects should use a
      center helper such as `circle_contains_rect_center()`.
- [ ] Add focused smoke coverage for each result-applying radial path:
      target-reached explosion, wall impact, support-bomb target Y,
      manual drone detonation, ball / boss-contact detonation, and any
      future cleanup-triggered detonation. Include center-hit, full-miss,
      and edge-only cases where the boss rect edge is inside the visual
      radius while the boss center is outside.

---

## Implementation Notes

- Follow `docs/character_skill_perk_checklist.md` for the full runtime
  integration pass; this document only freezes the Commando-specific
  system decisions
- Follow `CLAUDE.md` for icon / tooltip / cooldown-display invariants
- Do not treat this document as permission to route character skill
  runtime work through `AGENTS.md`; `AGENTS.md` remains out of scope for
  this feature unless boss-sprite runtime is also changed
