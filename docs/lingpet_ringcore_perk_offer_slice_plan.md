# Lingpet Ring-Core / Affinity-Chip Perk-Offer Slice Plan

Design note for human + Codex wiring. Do NOT treat the snippets below as
final GDScript — they are intent anchors. Wiring is the human's job;
adversarial review is Claude's.

## Goal

- **REQ1:** Make the `lingpet_ring_core_upgrade` perk card appear EARLY and
  reliably while the run ring-core tier is low, then taper the boost to zero
  as tier rises (no boost at MAX). Today it is one undifferentiated card in a
  ~36-card pool truncated to 3, so it surfaces at ~1/12 (~8%) per perk screen.
- **REQ2:** Gate the `lingpet_affinity_chip` card behind run ring-core
  tier >= 1, so the chip is only offered once the player has a ring core
  THIS run (either via the tutorial grant, a perk pick, or the gold shop).

Both features must be deterministic enough to seal in smokes and must read
the same run-scoped tier signal the ring-core card already uses.

## Verified facts (from system map + direct code read)

- `get_choices` (runtime_perk_catalog.gd:741-789) builds ONE pool
  (COMMON + character + chip + ring-core + instants), applies
  `_filter_lingpet_owned_gate`, **`shuffle()`**, then truncates to
  `target_choice_count`. `convert_to_gold` is appended AFTER truncation
  (a guaranteed extra slot — it does NOT consume one of the 3).
- Real gameplay passes `target=3` (`BASE_CHOICE_COUNT`, runtime_perk_state.gd:222).
  Early smasher pool ≈ 36 cards ⇒ a single card survives truncate-to-3 at
  3/36 ≈ 8.3%. This is why both lingpet cards "appear rarely".
- The chip card is built ONLY in `_append_lingpet_affinity_chip_choice`
  (877-894); the ring-core card ONLY in
  `_append_lingpet_ring_core_upgrade_choice` (897-910). Both already read
  run-scoped tier via `_get_lingpet_runtime(registry).get_run_ring_core_tier()`.
- Run tier is per-run state (`lingpet_affinity_state._run_ring_core_tier`,
  clamped 0..`MAX_RING_CORE_TIER`=6), reset per run. `set_run_ring_core_tier`
  exists for fixtures (state.gd:211).
- The TWO live `get_choices` consumers are the in-run perk modal
  (`runtime_perk_state.open_next_choice`) and the plaza academy preview
  (`plaza_academy_transactions._get_lesson_choices`). Both thread
  `owner`/`registry` ⇒ both go through `_append_*`. The gold shop
  (`plaza_lingpet_store_transactions`) has its OWN ring-core path and NO
  chip path — not a chip offer surface.
- **F4 debug bypass is latent-only:** `debug_set_perk_level` can write a raw
  level for an arbitrary id, but the chip is NOT in `get_debug_perk_entries`
  (835-850 appends ring-core only), so no debug card emits the chip today.
- **RUN-SCOPED RESET IS THE REAL DRIVER:** ring core is run-scoped and resets
  every run, so **every run starts at tier 0** and you re-climb the ladder
  in-run. The tier-0 reserve is therefore the primary lever for "appears early
  each run", and the tier-1/2 reserves keep the boost alive while you establish
  your core within a run.
- **TUTORIAL PRE-GRANT (verified, ONE-TIME wrinkle):** `lingpet_tutorial_
  bootstrap.grant_standard_ring_core_if_needed` sets run tier = 1
  (`STANDARD_RING_CORE_TIER`) ONLY for the player's first-ever lingpet hatch
  (owns ZERO pets + hatch context junior league + smasher), called from
  `lingpet_egg_runtime._spawn_egg` (1474). After that hatch you own a pet, so
  the grant never fires again. ⇒ the first lingpet ends up at tier 1 mid-run-1;
  REQ2's chip gate opens immediately for that one run (intended — the tutorial
  IS its first core). This is a one-time case, NOT the reason the tier-1 reserve
  exists (run-scoped reset is).
- `_filter_lingpet_owned_gate` is id-based and tier-AGNOSTIC by contract,
  sealed by `runtime_perk_lingpet_owned_gate_smoke`. It strips both ids when
  no pet is owned. The new tier logic must NOT live here.
- Every existing lingpet smoke calls `get_choices` with `target=200`, so
  truncation never bites and the rare-appearance reality is currently
  untested.

## REQ1 mechanism — tier-tapered force-include reservation

**Mechanism: a deterministic reserved-slot pull-to-front, driven by an
explicit per-tier reserve table.** A probability/weight bump is
non-deterministic under shuffle→truncate and cannot be sealed; a hard
reservation can.

### Constants (add near `BASE_CHOICE_COUNT` / `LINGPET_GATED_CHOICE_IDS`)

```
# Index = run ring-core tier (0..MAX_RING_CORE_TIER=6).
# Value = guaranteed reserved slots for the ring-core card in the truncated set.
# Decays to 0 as tier rises; 0 = competes normally at the old ~8%.
const LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER: Array[int] = [1, 1, 1, 0, 0, 0, 0]
const _RING_CORE_PRIORITY_KEY := "lingpet_ring_core_reserve_priority"
```

Recommended default `[1, 1, 1, 0, 0, 0, 0]` (reserve 1 slot at tiers 0/1/2,
normal competition at tier 3+). **Why non-zero past tier 0:** ring core is
RUN-SCOPED — every run starts at tier 0 and you re-climb the ladder in-run, so
the tier-1/2 reserves keep the boost alive while you establish your core EARLY
EACH RUN (not just on perk-screen one). The one-time tutorial hatch also seeds
tier 1 mid-run-1, so a `[1,0,...]` table would drop even that player to baseline
right after their first core. See Open Balance Decision for alternatives. Hard
cap each reserve value at 1 so the boost can never starve the other two
competitive slots.

### Function edits

1. In `_append_lingpet_ring_core_upgrade_choice` (897-910): after building the
   card and before `output.append(...)`, tag it
   `card[_RING_CORE_PRIORITY_KEY] = LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER[current_tier]`
   (`current_tier` is already clamped 0..max here). The card is only appended
   when `current_tier < max_tier`, so the MAX-tier row is never reached and
   the boost is naturally dead at max.

2. In `get_choices`, **after `_filter_lingpet_owned_gate(choices, owner)`**
   (so a no-pet player can never reserve a card) and **before `shuffle()`**:
   - Partition `choices` into `reserved` (entries whose
     `_RING_CORE_PRIORITY_KEY` value > 0) and `rest`.
   - `rest.shuffle()`.
   - Rebuild `choices = reserved + rest` (MOVE-to-front, do NOT duplicate the
     card — it already exists once in the pool).
   - Keep the existing truncate-to-`target` loop unchanged; the reserved card
     is now at the front so it survives.
   - **`erase()` the `_RING_CORE_PRIORITY_KEY` from each surviving card**
     before return so the helper key never leaks into the downstream payload.

   Because only the ring-core card carries the key (and reserve is capped at
   1), `reserved` holds at most one entry; the other two of three slots stay a
   uniform shuffle of `rest`. The `convert_to_gold` append after truncation is
   untouched.

### How it survives shuffle/truncate

Pre-pending the reserved card before the (now `rest`-only) shuffle guarantees
it occupies array index 0 when the truncate loop takes the first `target`
entries. No RNG governs its survival at tiers 0–2.

### Deterministic test seam

The reserve table itself IS the seam — no injectable RNG needed. A
`target=3` early-run call is a hard guarantee for reserved tiers; the
counter-case asserts the table value reads 0 at the taper-end tier, never a
shuffle outcome.

## REQ2 gate — chip requires run ring-core tier >= 1

**Single predicate, single function. Put it in
`_append_lingpet_affinity_chip_choice` (877-894), NOT in
`_filter_lingpet_owned_gate`** (that filter is tier-agnostic by contract and
takes no runtime handle; making it tier-aware would over-couple and risk the
owned/academy semantics it already seals).

### Constant

```
const LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER := 1
```

### Predicate (after the existing owned check at 878-879, before building the card)

```
var runtime: Object = _get_lingpet_runtime(registry)
if runtime == null or not runtime.has_method("get_run_ring_core_tier"):
    return
if int(runtime.get_run_ring_core_tier()) < LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER:
    return
# existing chip_count < MAX_ENHANCEMENT_CHIPS cap stays below this
```

This enforces the gate identically for the in-run modal and the plaza academy
(both flow through `_append_*`). The tutorial run starts at tier 1, so the
first-lingpet player sees the chip immediately — this is intended (the tutorial
grant IS the player's first ring core; the gate distinguishes by run tier, not
by acquisition source).

**F4 debug caveat (out of scope, document only):** if the chip is ever added
to `get_debug_perk_entries`, its `debug_set_perk_level` apply must be routed
through `apply_choice` / `add_enhancement_chip` (mirroring the ring-core
special-case at runtime_perk_state.gd:1525) so both the chip-state write and
this tier gate run. Today no debug card emits the chip, so the hole is latent.

## Smoke seals

### `runtime_perk_lingpet_affinity_chip_smoke.gd`

- **FLIP** `_verify_chip_card_gate_and_cap` (~L70): the fresh runtime is run
  tier 0, so the owned owner now expects the chip card **ABSENT**. Then add
  `runtime._affinity_state.set_run_ring_core_tier(1)` and re-assert the card
  **PRESENT** (proves the gate opens, not just that it closes). The dependent
  level/cap asserts (71-83) only hold while the card is visible, so they need
  the same tier-1 bump.
  - *Reverse-verify:* in-place edit `LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER`
    to `0` (or change the guard to `< 0`); the tier-0 ABSENT assert must fail.
- **BUMP** `_verify_chip_pick_updates_affinity_state_only` (86-97): add
  `set_run_ring_core_tier(1)` before `get_choices`, or it returns empty.
- **UNAFFECTED:** `_verify_runtime_multiplier_and_reset_boundary` (100-117)
  drives `add_enhancement_chip` directly (no `get_choices`) — leave as-is.
- **NEW** `_verify_chip_requires_ring_core_tier`: owned + tier 0 → absent;
  owned + tier 1 → present; not-owned + tier 1 → absent (owned gate still
  wins, tier-agnostically).
  - *Reverse-verify:* delete the `< MIN_RING_CORE_TIER` guard; the tier-0
    ABSENT case must fail.

### `runtime_perk_lingpet_ring_core_upgrade_smoke.gd`

- **NEW** `_verify_ring_core_force_included_early` at **`target=3`**
  (`BASE_CHOICE_COUNT`, NOT 200): owned lingpet, empty `runtime_levels`, run
  tier 0 → ring-core id present. Loop the call ~20× and assert present EVERY
  time (proves determinism, not luck).
  - *Reverse-verify:* edit the tier-0 reserve entry to `0`
    (`[0, 1, 1, 0, ...]`); the early case must become flaky/absent across the
    loop.
- **NEW counter-case** at the taper-end tier (`set_run_ring_core_tier(3)`),
  `target=3`: assert the ring-core card is **not force-reserved** by asserting
  the **reserve-table lookup reads 0** for that tier — assert via the table
  value / absence of the priority tag, NEVER via a shuffle outcome (that path
  is legitimately probabilistic).
- **KEEP** the existing `target=200` presence asserts as a regression that the
  card still builds — but they prove nothing about the boost; the boost is
  sealed ONLY at `target=3`.

### `runtime_perk_lingpet_owned_gate_smoke.gd`

- **UNCHANGED.** Still asserts `_filter_lingpet_owned_gate` strips BOTH ids
  with no pet and keeps them when owned. Add a one-line comment that this
  filter stays tier-agnostic and the new tier logic lives in the `_append_*`
  helpers, not here.

## Traps

- **Run-scoped tier is the real driver; tutorial grant is a one-time wrinkle
  (VERIFIED).** Ring core resets every run, so EVERY run starts at tier 0 and
  the tier-0 reserve is the primary lever. The only exception is the player's
  first-ever lingpet hatch (junior+smasher+owns-zero-pets), which seeds tier 1
  mid-run-1 — so REQ1 should keep a non-zero tier-1 reserve (else that one run
  drops to baseline right after its first core) and REQ2's gate opens for it
  immediately (intended). Do NOT special-case tutorial-vs-gold acquisition —
  read `get_run_ring_core_tier()` only.
- **Move-to-front, not duplicate-insert.** The ring-core card already exists
  once in the pool. The partition must reorder, not append a second copy, or
  the card double-shows.
- **Reserve cap = 1.** Never reserve more than one slot or the boost starves
  the other two competitive slots in a 3-card screen.
- **Run after the owned-gate.** Reservation must execute after
  `_filter_lingpet_owned_gate` so a no-pet player can never get a reserved
  lingpet card.
- **Erase the priority key.** `_RING_CORE_PRIORITY_KEY` must be removed from
  surviving cards before return or it pollutes the downstream payload (and per
  the `field_payload set() guard` memory, stray keys can be silently dropped /
  misread downstream).
- **target=200 blindness.** Existing presence asserts at 200 never exercise
  truncation; the boost is structurally untestable there. The new boost asserts
  are vacuous unless they use `target=3`.
- **No softlock.** Chip + tier reset per run; at tier 0 ring-core is
  force-reserved (and the gold shop offers it independently), so tier 1 is
  always reachable ⇒ the chip is never permanently locked.
- **i18n.** No new player-facing copy. Both cards reuse existing
  `LINGPET_AFFINITY_CHIP_PERK` / `_build_lingpet_ring_core_upgrade_data`
  localized strings. Do NOT invent a "requires ring core" locked-card tooltip
  unless the human explicitly asks — silent omission is felt-cleaner than a
  teasing locked card (and avoids a new localization surface).

## Touched files

- `godot/scripts/characters/runtime_perk_catalog.gd`
  - new constants (`LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER`,
    `_RING_CORE_PRIORITY_KEY`, `LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER`)
  - `_append_lingpet_ring_core_upgrade_choice` (tag priority)
  - `_append_lingpet_affinity_chip_choice` (tier gate)
  - `get_choices` (pre-shuffle partition + key erase)
- `godot/tests/runtime_perk_lingpet_affinity_chip_smoke.gd`
- `godot/tests/runtime_perk_lingpet_ring_core_upgrade_smoke.gd`
- `godot/tests/runtime_perk_lingpet_owned_gate_smoke.gd` (comment only)

## Tuning levers

- `LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER` — the entire early-boost curve.
  Index by tier; raise/lower individual entries (each capped at 1) to set how
  many tiers stay force-reserved and where the taper ends.
- `LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER` — the chip-unlock threshold
  (default 1). Raising it to 2 would gate the chip behind a SECOND ring core.

## Open balance decision (human picks ONE)

How aggressive is the early ring-core boost — i.e. how far up the tier ladder
does the force-include persist? All options keep the gate at tier-1 for the
chip; this only tunes `LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER`.

- **Option A — gentle (`[1, 1, 0, 0, 0, 0, 0]`):** guaranteed at tier 0 (every
  run's fresh start) and tier 1, normal competition at tier 2+. Lightest-touch;
  each run gets a guaranteed early ring-core offer or two, then it's back to
  ~8% once you've climbed past tier 1.
- **Option B — RECOMMENDED (`[1, 1, 1, 0, 0, 0, 0]`):** guaranteed through
  tier 2, normal at tier 3+. Reads as "always early for your first few cores,
  then it tapers" — matches the felt goal best and survives the tutorial's
  tier-1 start without leaving the early run feeling baseline.
- **Option C — strong (`[1, 1, 1, 1, 0, 0, 0]`):** guaranteed through tier 3
  (half the ladder). Most generous; risk is the ring-core card crowding one of
  three slots on too many consecutive screens, making the early perk pool feel
  repetitive.

**CHOSEN: Option B** (`[1, 1, 1, 0, 0, 0, 0]`) — user decision 2026-06-27.
Wire this exact array. It guarantees a clear early-game ring-core presence each
run (every run starts at tier 0 because the core is run-scoped) and tapers to
zero before MAX so late-run screens see the card at normal odds.

---

## REQ3 — spacing cooldown between forced ring-core offers (2026-07-01)

**User decision (this session):** keep t1's immediate force-include, but stop
t2/t3 from being force-offered on the *back-to-back* screens right after each
pick (report: "t1 링코어가 바로 나타나는건 좋은데 t2, t3 까지 너무 바로바로
나타남"). Chosen mechanism: **간격 두고 재보장 (spacing cooldown)** — after ANY
ring-core tier RAISE, suppress the force-include for the next `N` *presented*
perk screens, then resume the force-include for the current tier's card.

The reserve table `LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER = [1,1,1,0,0,0,0]` is
**UNCHANGED** — it still decides which tiers are *eligible* to be force-reserved;
the cooldown decides *when* within eligibility.

### Root of the "너무 바로바로" feel

With reserve `[1,1,1,...]`, the ring-core UPGRADE card is force-pulled to the
front (survives `shuffle→truncate-to-3`) on **every** perk screen while tier ∈
{0,1,2}. So: pick T1 → next screen guarantees T2 → pick → next screen guarantees
T3. Three consecutive guaranteed climbs. The force-include is binary today
(guaranteed vs ~8%), with no spacing in between. REQ3 adds the spacing without
touching the eligibility table.

### Combined force-include rule

Force-reserve the ring-core card **iff**:
`LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER[tier] > 0  AND  ring_core_offer_cooldown == 0`

- Fresh run: tier 0, cooldown 0 → T1 forced immediately (t1 stays instant). ✓
- Pick T1 → tier 1, cooldown = N → next N presented screens: T2 competes at the
  normal ~8%, NOT forced. Cooldown hits 0 → T2 force-reserved again.
- Pick T2 → tier 2, cooldown = N → same spacing before T3.
- Pick T3 → tier 3, reserve[3] = 0 → normal ~8% forever (unchanged).

**Tier 0 is structurally immune to the gate:** the cooldown is only ever set on a
tier RAISE (which lands tier ≥ 1), so at tier 0 the cooldown is always 0. No
special-case for "keep t1 instant" is needed — it falls out of the invariant.

### State owner — single chokepoint (verified)

All three upgrade sources funnel through
`LingpetAffinityState.upgrade_run_ring_core_tier()` (state.gd:276):

- **perk:** `runtime_perk_state._apply_lingpet_ring_core_upgrade` (1930) →
  `egg_runtime.upgrade_run_ring_core_tier` (2330) →
  `_affinity_run_upgrade_controller.upgrade_run_ring_core_tier` (24) →
  **`affinity_state.upgrade_run_ring_core_tier` (276)**
- **plaza gold shop:** `plaza_lingpet_store_transactions` →
  `egg_runtime.upgrade_run_ring_core_tier` → … → same state method
- **tutorial:** `lingpet_tutorial_bootstrap.grant_standard_ring_core_if_needed`
  (8) → **`affinity_state.upgrade_run_ring_core_tier(STANDARD_RING_CORE_TIER)`
  (15)**

⇒ **Set the cooldown INSIDE `LingpetAffinityState.upgrade_run_ring_core_tier()`**
on a successful raise. One write covers perk + plaza + tutorial. Setting it only
in `runtime_perk_state` would miss the plaza and tutorial raises. (Tutorial note:
the first-ever hatch grants T1 *and* arms the cooldown, so run-1's T2 also gets
the N-screen spacing — intended; the tutorial player is already ahead at T1.)

### Backbone edits (additive; absent → no-op = pre-REQ3 behavior)

**`godot/scripts/lingpet/lingpet_affinity_state.gd`**
- const near top: `const RING_CORE_OFFER_COOLDOWN_SCREENS := 3` (THE lever).
- field beside `_run_ring_core_tier` (164):
  `var _ring_core_offer_cooldown_screens := 0`.
- `reset_all()` (170): `_ring_core_offer_cooldown_screens = 0`.
- `export_run_state()` (190): add
  `"ring_core_offer_cooldown_screens": _ring_core_offer_cooldown_screens`.
- `import_run_state()` (204):
  `_ring_core_offer_cooldown_screens = maxi(0, int(data.get("ring_core_offer_cooldown_screens", 0)))`.
- `upgrade_run_ring_core_tier()` (276): on success (after
  `_run_ring_core_tier = next_tier`, before `return true`):
  `_ring_core_offer_cooldown_screens = RING_CORE_OFFER_COOLDOWN_SCREENS`.
- new `get_ring_core_offer_cooldown_screens() -> int` → `maxi(0, _ring_core_offer_cooldown_screens)`.
- new `tick_ring_core_offer_cooldown() -> void` → `if _ring_core_offer_cooldown_screens > 0: _ring_core_offer_cooldown_screens -= 1`.

**`godot/scripts/lingpet/lingpet_egg_runtime.gd`**
- beside `get_run_ring_core_tier()` (2366), add two pass-throughs to
  `_affinity_state`: `get_ring_core_offer_cooldown_screens()` and
  `tick_ring_core_offer_cooldown()`.

**`godot/scripts/characters/runtime_perk_catalog.gd`**
- `_append_lingpet_ring_core_upgrade_choice` (925), change the tag at 938 to:
  `if _get_lingpet_ring_core_early_reserve_count(current_tier) > 0 and _get_lingpet_ring_core_offer_cooldown(registry) <= 0:`
- add helper `_get_lingpet_ring_core_offer_cooldown(registry) -> int`, mirroring
  `_get_lingpet_run_ring_core_tier(registry)` (1079): resolve egg_runtime, return
  `get_ring_core_offer_cooldown_screens()`, else **0 (fail-open to "no cooldown"**
  = current behavior, so a missing runtime can never *over*-suppress).

**`godot/scripts/characters/runtime_perk_state.gd`**
- `open_next_choice`: tick the cooldown **once per *presented* modal screen**, at
  the confirmed-presentation point (after `choice_active = true`, ~247) — PAST the
  empty-`current_choices` recurse return (234), so an empty/recursing screen never
  ticks and a presented screen ticks exactly once. Add a private helper that
  resolves egg_runtime via `_get_instance(registry, "lingpet_egg_runtime")` (the
  same resolver used at 1934) and calls `tick_ring_core_offer_cooldown()`.
- **Do NOT tick inside `catalog.get_choices`** — the plaza academy preview
  (`plaza_academy_transactions._get_lesson_choices`) shares `get_choices` and must
  READ the cooldown (display parity) but must NOT consume a screen.

### Read-vs-tick ordering (check-then-decrement)

`get_choices` reads the cooldown for THIS screen's force-include decision (224);
the tick fires after presentation (~247). So the screen right after an upgrade
sees the full cooldown (not forced) and then decrements → exactly `N` breathing
screens, then forced.

### Smoke seals

**`runtime_perk_lingpet_ring_core_upgrade_smoke.gd`**
- KEEP `_verify_ring_core_force_included_early` (tier 0, cooldown 0, target=3, 20×
  → present every time). ADD a tier-1-with-cooldown-0 positive (tick the cooldown
  to 0 first) → also present every time (force survives shuffle; proves the gate
  REOPENS after the cooldown drains).
- NEW negative `_verify_cooldown_suppresses_force_include_after_upgrade`: drive the
  REAL run-state — `runtime.upgrade_run_ring_core_tier(1)` (arms cooldown = N).
  Assert the STATE seal `runtime.get_ring_core_offer_cooldown_screens() == N > 0`,
  AND assert the card LOST its guaranteed slot at target=3 (NOT present in all 20
  calls — it fell back to ~8% competition). **Reverse-verify:** delete the
  `and … <= 0` clause in the tag condition → the "not present every time" assert
  must FAIL (card forced again). Seal the negative via the state condition +
  loss-of-guarantee, NEVER a single shuffle outcome.

**`lingpet_affinity_state_smoke.gd`**
- `upgrade_run_ring_core_tier` sets cooldown == `RING_CORE_OFFER_COOLDOWN_SCREENS`.
- `tick_ring_core_offer_cooldown` decrements by 1, floors at 0.
- `reset_all()` → cooldown 0.

**`lingpet_affinity_run_state_save_restore_smoke.gd` (§9-trap seal)**
- upgrade (cooldown armed) → `export_run_state` → `reset` → `import_run_state` →
  cooldown restored. **Reverse-verify:** strip `ring_core_offer_cooldown_screens`
  from the exported dict → not restored (mirrors the existing affinity-run-state
  reverse-verify in this smoke).

### Traps
- **Single chokepoint.** Arm the cooldown in
  `LingpetAffinityState.upgrade_run_ring_core_tier`, not per-caller. Perk/plaza/
  tutorial all pass through it; a per-caller set misses two.
- **Modal-only tick.** Tick in `open_next_choice` (real screen), never in
  `get_choices` (academy preview shares it and must not consume a screen).
- **Recursion double-tick.** Place the tick past the empty-choices recurse return
  (234) so an empty/recursing screen ticks 0×, a presented screen ticks 1×.
- **§9 export/import.** New run-scope field → MUST be in export/import, or a
  plaza-egg-purchase rollback / in-run save-restore silently drops the cooldown and
  re-forces t2/t3 on restore (the §9 generalization rule).
- **No owner key.** Cooldown is read via an egg_runtime method (like the tier), NOT
  `owner.set(...)`, so the Owner-Field Schema Trap / `DEFAULT_VALUES` does not apply
  — do NOT add an owner key.
- **Fail-open read.** A missing egg_runtime → cooldown read returns 0 (no
  suppression) → degrades to pre-REQ3 behavior, never to permanent suppression /
  softlock.
- **Tier-0 immunity is structural.** Cooldown is only armed on a tier raise (≥1),
  so tier 0 keeps cooldown 0 and T1 is never delayed. Do not special-case it.

### Tuning lever
- `RING_CORE_OFFER_COOLDOWN_SCREENS` (default **3**) — the entire spacing feel.
  Higher = more breathing room between forced t1→t2→t3 offers (risk: t3 harder to
  reach within a run); lower = tighter spacing. This is the ONLY new number; decide
  the final value by live felt-QA, exactly like the reserve table.

**Wiring split:** GDScript wiring + smokes = user/Codex per
[[feedback-design-slice-review-division]]; Claude does the adversarial diff review
after (grounded on this REQ3 spec).
