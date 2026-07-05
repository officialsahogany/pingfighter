# Lingpet Egg — Always-Hatch + Overflow Replace/Release — Slice Plan

Status: design note for user-wired GDScript + Claude adversarial review.
This doc = backbone + the one open architecture decision + traps + smoke spec.

## 0. Confirmed spec (2026-06-26)

- **Total lingpet cap = 3** (new hard rule; today only `MAX_BATTLE_SLOTS = 3`
  caps battle slots while `owned_pet_ids` is unbounded).
- **The `lingpet_egg` active item is ALWAYS usable** — even with 3 owned. Remove
  the `STATE_NONE`-only gate.
- **Owned < 3:** egg deploys → ball-hit hatch → acquire cut-in → **auto-join** the
  next empty slot (becomes active). No modal. (current behavior, minus the gate)
- **Owned == 3 (full):** egg deploys → hatch → acquire cut-in → **after the player
  dismisses the cut-in** ("클릭 라이브2D 감상 이후"), a **choice modal** appears:
  - **교체 (replace):** pick one of the 3 → that pet is **permanently released**
    (removed from `owned_pet_ids` + battle slots); the new pet takes that slot and
    becomes active.
  - **방생 (release):** the **newly-hatched** pet is discarded; the existing 3 are
    unchanged.
- The modal appears AFTER the cut-in dismiss completes, and pauses gameplay like
  the cut-in does.

## 1. THE OPEN ARCHITECTURE DECISION (decide before wiring)

`lingpet_egg_runtime._state` is a single enum (`NONE`/`EGG`/`COMPANION`). Today the
egg requires `STATE_NONE` precisely because a field egg (`STATE_EGG`) cannot
coexist with an active companion (`STATE_COMPANION`). Allowing the egg while a
companion is active forces one of two models — **pick one:**

### Option S — Suspend (plaza-style, smaller)
Egg deploy overwrites `_state` → `STATE_EGG`, saving the active companion's skill
state first (exactly what `spawn_plaza_resonance_egg` already does:
`_save_current_companion_skill_state()` → `_state = STATE_EGG`, lines ~694-697).
While the egg incubates the player has **no active companion**. On hatch → new pet
becomes the companion (cut-in). On **방생**, re-adopt the suspended pet
(`_adopt_owned_pet`).
- Pros: reuses the plaza mechanic; single state machine; least new code.
- Cons: using the egg temporarily removes your current companion's help until you
  hit the egg 3× and resolve the choice; 방생 must restore the prior active pet
  (save `pet_id` + skill state at deploy).

### Option P — Parallel pending-acquire (better feel, larger)
The active companion keeps playing. The acquisition egg is tracked in a NEW
sub-state independent of `_state` (e.g. `_pending_acquire_egg_state` +
`_pending_acquire_pet_id`), with its own field render + ball-hit detection. On
hatch → cut-in for the new pet → (auto-join or modal). The active companion is
never disturbed; 방생 just drops the pending pet.
- Pros: best UX — you don't lose your companion while incubating.
- Cons: a second egg-state machine (spawn/render/collision/hatch) running beside
  the companion; more surface area and more smokes.

**Recommendation:** Option P for feel if this is a marquee mechanic; Option S if
we want it shipped small and are OK with the "companion suspended while
incubating" cost. The rest of this plan is written to apply to EITHER, calling
out the few spots that differ.

## 2. Backbone by area

### 2a. Cap + collection ops — `lingpet_collection_state.gd`
- Add `const MAX_OWNED := 3` (or reuse `MAX_BATTLE_SLOTS`). Add helpers:
  - `owned_count() -> int` and `is_full() -> bool` (owned_pet_ids size, owner-aware
    via `get_owned_pet_ids_from_owner`).
  - `release_pet(owner, pet_id)` — remove from `owned_pet_ids`, clear from
    `battle_slot_pet_ids`, clear from owner mirrors (OWNER_ARRAY_KEYS,
    OWNER_COLLECTION_KEYS), fix `active_slot_index` if it pointed at the cleared
    slot, then `_sync_owner_slots`. (No release path exists today — this is new.)
  - `replace_slot(owner, slot_index, new_pet_id)` — release the pet currently in
    `slot_index`, then place `new_pet_id` there and make it active.
- Trap: `add_pet` currently appends unbounded. With the cap, the FULL-case hatch
  must NOT call `add_pet`/`ensure_pet_active_slot` until the player chooses 교체;
  on 방생 it must never be added.

### 2b. Egg gate — `lingpet_egg_runtime.gd`
- `deploy_egg_from_item` (line 358): drop `_state != STATE_NONE`. Allow deploy
  whenever the item fires.
  - Option S: if `_state == STATE_COMPANION`, save companion skill state + record
    the suspended `pet_id`, then go to `STATE_EGG` (mirror plaza lines 694-697).
  - Option P: leave `_state` alone; arm `_pending_acquire_*` instead.
- `can_offer_egg_item` (line 343): change `_state != STATE_NONE` → "always offer in
  non-junior league" (the egg is now always usable). Keep the junior exclusion and
  the `_owner_has_lingpet_egg_in_slots` dedup. NOTE: the field-spawn pool
  (`_should_skip_lingpet_egg_spawn`) and pickup gate
  (`_is_lingpet_egg_pickup_redundant`) both consume `can_offer_egg_item`, so they
  update for free — but re-audit: a player at 3-owned should STILL be offered the
  egg now (that's the point), so the "redundant" dedup must only block a 2nd egg
  while one is already HELD/incubating, not while a companion exists.

### 2c. Hatch branch — `lingpet_egg_runtime._resolve_ball_hit` (line 1254)
The hatched branch (1259-1271) currently always: `STATE_COMPANION` + apply loadout
+ **affinity HATCH grant** + `_start_acquire_cutin` + `ensure_pet_active_slot`.
Split by cap:
- **owned < 3:** keep current behavior (auto-join).
- **owned == 3 (overflow):** hatch into a **pending** acquisition:
  - play the cut-in for the new pet (so the player sees it), BUT
  - do NOT `ensure_pet_active_slot` and do NOT grant affinity HATCH yet, and
  - set a flag `_pending_overflow_choice = true` so the post-cut-in step opens the
    modal instead of returning to play.
- Trap (affinity): the `SOURCE_HATCH` affinity grant (line 1262) must fire only
  when the pet is actually KEPT (auto-join, or 교체 commit) — never for a 방생'd
  pet. Move/guard it accordingly.

### 2d. Post-cut-in → modal trigger
The cut-in lifecycle is: `is_acquire_cutin_active()` (paused) → `advance_acquire_cutin`
→ `is_acquire_cutin_awaiting_dismiss()` → `begin_acquire_cutin_dismiss()` →
`is_acquire_cutin_dismissing()` → done. Drivers:
- pause gate: `battle_scene_modal_gate_controller.gd:95,137`
- frame pump: `battle_scene_frame_controller.gd:52-58`
- dismiss input: `battle_scene_overlay_input_controller.gd:53-59`
- render: `lingpet_acquire_cutin_overlay_host.gd`

Add the overflow choice modal as a SECOND gated overlay that mirrors this exact
pattern. When `_pending_overflow_choice` is set and the cut-in finishes its
dismiss, transition into `_overflow_choice_active = true` instead of un-pausing:
- New runtime API on `lingpet_egg_runtime`: `is_overflow_choice_active()`,
  `get_overflow_choice_snapshot()` (the new pet + the 3 current pets for the
  modal), `commit_overflow_replace(slot_index, owner, registry)`,
  `commit_overflow_release(owner, registry)`.
- Pause: extend `battle_scene_modal_gate_controller` to also gate on
  `is_overflow_choice_active` (a new `_module_bool` line next to the cut-in one).
- Input: a new overlay/input handler that maps clicks/keys to
  `commit_overflow_replace` / `commit_overflow_release` (model on the cut-in
  dismiss input in `battle_scene_overlay_input_controller`, and/or a clickable
  overlay like the character-info handlers).
- Render: a new overlay host (mirror `lingpet_acquire_cutin_overlay_host`) drawing
  the new pet + 3 existing portraits + "교체"/"방생" affordances. Asset/art via the
  imagegen pipeline if portraits/frames are needed; reuse existing lingpet portrait
  textures where possible.

### 2e. Commit operations — `lingpet_egg_runtime`
- `commit_overflow_replace(slot_index, owner, registry)`:
  `_collection_state.replace_slot(owner, slot_index, new_pet_id)` (releases the old
  pet), grant the deferred `SOURCE_HATCH` affinity for the new pet, finalize
  `STATE_COMPANION` on the new pet, clear `_pending_overflow_choice` /
  `_overflow_choice_active`, `_sync_owner`.
- `commit_overflow_release(owner, registry)`: discard the new pet (no add, no
  affinity);
  - Option S: re-adopt the suspended prior companion (`_adopt_owned_pet`).
  - Option P: just drop `_pending_acquire_*`; the active companion already stands.
  Clear the flags, `_sync_owner`.

## 3. Traps (must address)

1. **Single-`_state` conflict** — the whole reason for §1. Do not naively allow
   `STATE_EGG` while a companion is active without picking Option S or P.
2. **Existing egg smokes assume `STATE_NONE`-only** and WILL break:
   - `lingpet_egg_runtime_smoke._verify_pro_league_egg_item_deploy` asserts a 2nd
     deploy while one is present is a no-op — that contract is changing. Update it.
   - `item_field_spawn_pool_smoke._verify_lingpet_egg_active_gate` + the two-eggs
     store case assume offer flips off once deployed — re-spec for the new rule.
   - Update `docs/item_runtime_checklist.md` §1.7 (the lingpet_egg reference block,
     lines ~897-942) which documents the `STATE_NONE` gate as the contract.
3. **Affinity HATCH double/oversgrant** — `SOURCE_HATCH` (line 1262) must fire
   exactly once and only for a KEPT pet (auto-join or 교체), never for 방생, never
   twice if the modal is re-entered.
4. **Modal gate / pause** — the overflow modal must pause via
   `battle_scene_modal_gate_controller` AND be pumped while paused (the cut-in uses
   the ungated idle pump in `battle_scene_frame_controller`). A modal that pauses
   but isn't pumped/inputtable = softlock. Mirror the cut-in's three drivers.
5. **Round/battle reset & save-load mid-pending** — if a round ends or the battle
   is saved while `_pending_overflow_choice`/`_overflow_choice_active` is set,
   define a deterministic resolution (recommend: treat an unresolved pending as
   방생 on any reset, and never persist the pending state). `reset_round` (1177),
   `_clear_lingpet_field_state` (1204), and the save snapshot must clear it.
6. **Owner-Field Schema Trap** — any new owner-synced key (e.g. a pending-acquire
   mirror) must be declared in `battle_scene_state.gd` `DEFAULT_VALUES` or the sync
   silently no-ops. Prefer keeping pending state runtime-only (not owner-synced) to
   avoid this.
7. **Slot-tab UI interaction** — the new 3-tab selector
   (`character_info_overlay_lingpet_*`, just shipped) reads `lingpet_slots`. A
   `replace_slot`/`release_pet` must keep `lingpet_slots` + `lingpet_active_slot_index`
   correct so the tabs reflect the post-replace roster immediately.
8. **`no_recycle` still holds** — the egg keeps `no_recycle: true`; even though it's
   now usable while owning pets, a successful deploy still consumes it (no dead
   slot). Re-confirm with a smoke that a recycle proc does not keep the egg.
9. **Plaza path parity** — `spawn_plaza_resonance_egg` already overwrites a
   companion. Decide whether plaza purchases ALSO route through the new
   cap/replace-release flow when full, or keep their current overwrite behavior.
   (Recommend: unify on the same overflow modal so both acquisition paths obey the
   3-cap consistently.)

## 4. Smoke spec

New `godot/tests/lingpet_egg_overflow_choice_smoke.gd` (+ update the existing egg
smokes per Trap 2). Assert OUTCOMES:
- Deploy now succeeds while a companion is active (Option S: state → egg + prior
  pet saved; Option P: pending armed + companion intact).
- Owned < 3: hatch auto-joins the next empty slot, becomes active, affinity HATCH
  granted once, NO modal (`is_overflow_choice_active()` false).
- Owned == 3: hatch sets `is_overflow_choice_active()` true AFTER cut-in dismiss;
  `commit_overflow_replace(slot)` releases the chosen old pet (owned_count stays 3,
  old pet gone, new pet active + in that slot, affinity granted once);
  `commit_overflow_release()` discards the new pet (owned unchanged, NO affinity,
  Option S restores the prior companion).
- Cap invariant: `owned_count()` never exceeds 3 on any path.
- Reset/save trap: an unresolved pending → 방생 on `reset_round` / round snapshot;
  pending never persisted.
- `no_recycle` still consumes the egg under a forced recycle proc.
- Reverse-verify each new assertion FAILS with the corresponding guard removed
  (in-place edit toggle, never git reset).
- Use a schema-gated owner where owner reads matter (Owner-Field Schema Trap).

## 5. File touch list (summary)

| File | Change |
|---|---|
| `lingpet_collection_state.gd` | cap (3), `owned_count`/`is_full`, `release_pet`, `replace_slot` |
| `lingpet_egg_runtime.gd` | drop STATE_NONE gate; deploy-while-companion (S or P); hatch overflow branch; pending flags; `is_overflow_choice_active` + snapshot + `commit_overflow_replace/release`; reset/save clears pending; guard affinity HATCH |
| `battle_scene_modal_gate_controller.gd` | gate pause on `is_overflow_choice_active` |
| `battle_scene_frame_controller.gd` | pump the modal while paused (mirror cut-in pump) |
| `battle_scene_overlay_input_controller.gd` (or new handler) | route input → commit_overflow_replace/release |
| new overlay host (mirror `lingpet_acquire_cutin_overlay_host.gd`) | draw new pet + 3 current + 교체/방생 affordances |
| `battle_scene_state.gd` | only if a pending key must be owner-synced (prefer not) |
| `docs/item_runtime_checklist.md` §1.7 | re-spec the egg gate contract |
| existing egg/field-spawn smokes | update STATE_NONE-only assertions |
| new `lingpet_egg_overflow_choice_smoke.gd` | seal the flow (see §4) |

## 6. Open items to confirm at plan review

- **§1 architecture: Option S vs Option P.** (the one blocking decision)
- Modal visuals: reuse lingpet portraits + a simple framed chooser, or new imagegen
  art? (art request routes through the item/ui skills if new).
- Plaza parity (Trap 9): unify plaza purchase onto the same 3-cap overflow flow, or
  leave plaza's current overwrite-on-companion behavior as-is?
- Junior league: junior auto-presents its lingpet and never offers the egg item —
  confirm the cap/overflow flow is Pro/Mythic-only (egg item path), and that
  junior's auto-spawn is unaffected.
