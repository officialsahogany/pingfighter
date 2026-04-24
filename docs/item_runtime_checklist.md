# Item Runtime Integration Checklist

Single source of truth for the code locations that must be touched
when adding, removing, or modifying an item (active / passive /
legendary / mythic) in PingFighter.

Three-way role split:

| Document | Owns |
|---|---|
| `.claude/skills/item-generation/` | Item icon and equip visual generation (prompts, mood, QA) |
| **this file** | Every code location that must be touched to make the item work at runtime |
| `CLAUDE.md` | Thin routing rule pointing at both of the above |

Runtime integration does NOT belong in `AGENTS.md` for item work -
`AGENTS.md` is the source of truth for boss-sprite runtime wiring only.
Item runtime lives here.

If this file and the item-generation skill conflict, **this file wins
for runtime behavior** (registration, routing, reset, rolls, polish,
enhancement). The skill wins for visual asset decisions.

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

Do not stop for clarification on the items above unless the user's
request directly conflicts with one of these defaults.

### 0.2. Recurring Integration Traps

These are the bugs most likely to survive a "looks registered" pass:

- `owned / obtained` and `equipped / active` are different concepts.
  `[item_name]_obtained` should mean ownership / first acquire /
  respawn-gating, not "currently equipped".
- `sync_equipped_passive_effects()` should drive live effect state only.
  Do not let per-frame equip sync flip ownership flags back to `False`
  on unequip, or field respawn / one-time gacha rules will silently
  break.
- Duplicate policy is path-specific. Field drops, Pandora / treasure
  routes, shop / crane, and stage-clear gacha can intentionally diverge.
  Verify the real path-specific gate instead of summarizing an item as
  simply "duplicate-allowed" or "one-time".
- Stage-clear gacha is a separate candidate builder from `gacha.py`
  metadata. If an item should be one-time there, the gate must read an
  ownership signal, not the current equipped state.
- When touching legendary / mythic equip sync, do not blindly copy an
  existing `sync_bool()` pattern into `[item_name]_obtained` without
  checking whether the repo path is actually modeling ownership or only
  current equipped state.

---

## 1. New active item — checklist

Active items go into the active slot (5-orb cooldown UI). They are
consumed on use.

### 1.1. `items.py`

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

### 1.2. `pingfighter.py`

- [ ] `store_active_item()` (near line 89587) — confirm the item is
      NOT in the passive-filter list at line 89600 (that list blocks
      passive names from reaching the active slot; active items must
      pass through).
- [ ] `show_item_obtained_effect()` (near line 96507) — verify the
      acquisition animation triggers. Most active items use the
      existing branch without per-item code.
- [ ] Add the item to the **developer mode `all_items` list** (near
      line 143285) with `"type": "active"` and an icon fetch via
      `get_icon_safe()` or `get_item_icon()`. Missing here means the
      dev mode 2-key menu cannot spawn the item for testing. The
      secondary character/item manager builds from `items.ITEM_TYPES`;
      do not add a second copied list there.

### 1.3. `gacha.py`

- [ ] If the item should appear in gacha pulls, confirm it is present
      in the active-item pool construction near line 213 (the
      `gacha_available_items_template` is populated from the
      `available_items` parameter — check the caller passes the new
      item name).

### 1.4. Shop / crane

- [ ] `downtown/building_interior.py` — add the item to the hardcoded
      active-items list (near line 3823) to make it sellable in the
      shop and drawable in the crane capsule pool.
- [ ] Crane game capsule generation (same file, near line 3917) —
      confirm the new item is eligible if intended.

### 1.5. `unknown_item` path

- [ ] If the item is intended to be a possible resolution of an
      `unknown_item` pickup, wire it into the resolve table used at
      that pickup site. The placeholder asset is `items/unknown_item.png`
      (already on disk — do NOT overwrite). If the resolve table does
      not already exist for this flow, this is a new feature decision
      and belongs in a design pass before this checklist.

### 1.6. Reset on death / main menu return

- [ ] Confirm the item is cleared by `item_state_manager.reset_runtime_items()`
      (near line 10). The default reset wipes `active_items` without
      per-item code, so in most cases no change is needed. Verify by
      spawning the item in a run, dying, and returning to main menu —
      the active slot must be empty.

---

## 2. New passive item — checklist

Passive items equip to a body-part slot (머리 / 상의 / 팔 / 벨트 / 무릎 /
신발 / 등 / 장신구) and apply effects while equipped.

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

### 2.1. `items.py`

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

### 2.2. `pingfighter.py`

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
- [ ] **Developer-mode hardcoded `all_items` list** (near line
      143285) — this is a SEPARATE hardcoded list from
      `PASSIVE_SLOT_ORDER`. It instantiates the actual item
      dictionaries that the developer-mode 2-key menu displays.
      **You must update both.** Omission hides the item from the dev
      mode menu. The secondary character/item manager is generated
      from `items.ITEM_TYPES` and `items.is_passive_inventory_item()`,
      so do not maintain a second copied `all_items` block for it.
- [ ] `get_item_name_korean()` and `get_item_description()` ??add the
      new item so inventory, shop, tooltip, and developer-mode UIs
      do not show raw snake_case or fallback text.
- [ ] Online / multiplayer passive classification ??update the shared
      `items.py` passive classification source instead of adding a
      local synced list in `pingfighter.py`. Normal passive drops belong
      in `PASSIVE_DROP_ITEM_NAMES`; passive legendaries / mythics belong
      in `LEGENDARY_PASSIVE_ITEM_NAMES`. The online client pickup path
      must route through `items.is_passive_inventory_item()`. Omission
      can misclassify the passive as an active item in synced state.

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

### 2.8. Gacha / shop / crane / treasure hunt

- [ ] `gacha.py` (near line 213) — confirm the item is included in
      the passive-item pool (`PASSIVE_ITEM_NAMES` set around line 225)
      if intended.
- [ ] **Stage-clear gacha candidate builder** ??confirm the actual
      `available_items.append(...)` path in `pingfighter.py` adds the
      item too. `gacha.py` metadata alone is not sufficient.
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
      52392) multiplies legendary spawn and passive drop weight
      (`0.03 * treasure_map_level` in `items.py` near line 2539).
      Confirm the new passive can be rolled through this path.

### 2.9. Reset on death / main menu return

- [ ] `item_state_manager.reset_runtime_items()` (near line 10) must
      clear `passive_items`, reset `[item_name]_obtained` flags, and
      unequip any per-item runtime state.
- [ ] If the item modifies a global (e.g. a buff multiplier held in
      `pingfighter.py`), reset that global too.
- [ ] Equip visuals must be cleared on reset so the player paddle
      starts fresh in the next run.

---

## 3. New legendary / mythic item — checklist

Legendary items are always passive, always allow duplicates, and
always use the full legendary frame stack for their icon.

Do §2 (passive checklist) first. Then everything below.

### 3.1. `legendary_items.py`

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
- [ ] **Pandora exclusion list.** `legendary_items.py` near line 11623
      holds `passive_names = { ... }` inside Pandora Legacy's active
      roulette. **Add the new legendary name to this set.** Omission
      means Pandora can randomly spawn the new legendary as an
      "active" item, which then misroutes on pickup.

Legendary sync warning for the next section:
- If an existing `sync_bool()` path is reused here, verify it is not
  collapsing `ever acquired / respawn-gating` into `currently equipped /
  effect active`.
- Reset / main-menu-return should clear ownership flags; per-frame equip
  sync should drive only the live equipped state.

### 3.2. `pingfighter.py`

- [ ] `get_item_icon()` — add the name to the legendary-name list so
      the HUD icon pipeline knows to render the full frame stack;
      otherwise the icon shows `?`.
- [ ] Legendary obtained-flag sync — add the `sync_bool()` call (the
      existing pattern for `ragnarok_hammer_obtained` etc.) so
      re-entry / reset clears the flag.
- [ ] `store_active_item()` legendary filter — the passive-filter
      list near line 89600 MUST include the new legendary name
      (legendaries are passive, never active).
- [ ] `store_passive_item()` — legendary duplicates are allowed;
      never set `skip_append = True` in the legendary branch. See
      §2.3.
- [ ] `sync_equipped_passive_effects()` (near line 33362) — add
      on-equip / on-unequip blocks that:
      - On equip: read `enhancement_bonus_pct` from the equipped item
        dict and write it into the legendary-manager instance so
        stat reads pick it up.
      - On unequip: reset `enhancement_bonus_pct = 0`.
      - If roll options drive perk-like behavior (e.g. `sage_ring`
        penalty), also sync those (pattern near lines 33510–33526).

### 3.3. `items.py`

- [ ] `spawn_random_item()` `legendary_names` set (near line 2493) —
      add the name so field spawn weighting treats it as legendary.

### 3.4. `downtown/`

- [ ] `downtown/constants.py` `LEGENDARY_ITEM_NAMES` (near line 552) —
      add the name.
- [ ] `downtown/building_interior.py` — add to the legendary list
      embedded in the shop passive list (near line 3859) so the shop
      sells the new legendary.

### 3.5. `gacha.py`

- [ ] Legendary gacha pool (near line 328) — add the name so the
      gacha can roll it.

### 3.6. Icon asset

- [ ] Legendary frame stack baked into the PNG(s) per
      `LEGENDARY_ITEM_TEMPLATE.md` in the repo root.
- [ ] Developer-mode legendary tab auto-discovers unlocked legendary
      items from the `LegendaryItemManager` registry (pingfighter.py
      near line 143363, filtered by `item.unlocked` and excluding
      `empty` / `empty1` / `empty2`). Adding the new legendary to the
      manager (§3.1 step 3) is enough — the dev mode grid picks it
      up automatically.
- [ ] Do NOT overwrite `empty_legendary*` assets / names — these are
      blank placeholders used by the developer-mode grid layout.

### 3.7. Theme particle (runtime effects)

- [ ] The icon PNG does NOT animate particles; the runtime effects
      manager spawns them. Pick the particle theme per the
      item-generation skill §6.3, and wire the spawn hook into
      whatever runtime code already drives particle emission for
      similar legendary items (thor hammer blue sparks, hermes cyan
      streaks, poseidon teal droplets, etc.).
- [ ] Every legendary / mythic must have a theme-consistent particle
      hook. An icon on a legendary frame with no particle theme
      reads as incomplete.

### 3.8. Duplicate acquire flow (farming rolls)

- [ ] First acquire: set `obtained = True`, register with the
      legendary manager, play the acquisition animation.
- [ ] Every acquire (first and later): `item_data["type"] = "legendary"`,
      call `ensure_passive_rolls()` and
      `apply_roll_bonuses_from_item()`, fall through to inventory
      append. **No `skip_append = True`.** See §2.3.

---

## 4. `unknown_item` and acquisition animation

### 4.1. `unknown_item` resolution

- `items/unknown_item.png` is the placeholder icon for an item that
  has not resolved yet. Do NOT overwrite this file.
- A new item may be wired in as a possible resolution of an
  `unknown_item` pickup if the design calls for it. The resolve
  pipeline is the place to do this — not the icon itself.
- After `unknown_item` resolves, the resolved item must go through
  the normal acquisition animation, exactly like a direct pickup.

### 4.2. Acquisition animation parity

- Every item pickup must call `show_item_obtained_effect()`
  (pingfighter.py near line 96507). Active, passive, and legendary
  items all use the same entry point — do NOT branch to a custom
  animation for a new item.
- If the item is resolved from `unknown_item`, call the same function
  after the resolve so the animation looks identical to a direct
  pickup.

---

## 5. Reset lifecycle (death / main menu return)

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

## 6. Hardcoded integration points audit — easy to miss

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
| 14 | `pingfighter.py` developer-mode `all_items` (~143285) | Dev mode 2-key menu item list (SEPARATE from `PASSIVE_SLOT_ORDER`) |
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

Use this whenever the item replaces or gates the player's character
kit on activation. Current cases in the repo:

- **Yachaman Soul** — passive, revival on score loss, transforms
  into Yachaman form.
- **Odin's Eye** — legendary, revival on score loss, transforms into
  Odin-empowered form.
- **Horn Strawberry Mask** — passive, command-triggered (`A→D→A→D→A→D`)
  transform into Strawberry form.

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
- [ ] **Command-triggered transforms** (Horn Strawberry Mask):
      the `TRANSFORM_EVENT -> TRANSFORMED` state edge, detected
      inside `update_horn_strawberry_transform()` by saving
      `was_transformed = ts.is_transformed` before `ts.update(dt)`
      and testing `ts.is_transformed and not was_transformed` right
      after. Do NOT key the fix off `is_event_playing` — the event
      phase ends BEFORE `is_transformed` flips.
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

### 7.4. Finalize-detect callsites in the current repo

| Item | Finalize-detect location | Fix location |
|---|---|---|
| Yachaman Soul | `pingfighter.py` `if anim_done:` branch inside the `if yachaman_revival_anim_active:` block | same branch |
| Odin's Eye | `pingfighter.py` `if animation_complete:` branch after `odins_eye.update_revival_animation()` | same branch |
| Horn Strawberry Mask | `pingfighter.py` `update_horn_strawberry_transform()` — the `was_transformed` / `ts.is_transformed` edge right after `ts.update(dt)` | same edge |

If you add a new character-transformation item, add a row here in
the same PR with the finalize-detect location.

### 7.5. Cross-reference

Character-transformation perks / skills (as opposed to items) that
flip the same character-gate predicates should also follow this
rule. See `docs/character_skill_perk_checklist.md` §7 (Persistence
and lifecycle) for the cross-link.

---

## 8. Smoke test before shipping

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
12. Die mid-run or return to main menu — the item is cleared from
    inventory; next run starts fresh; `[item_name]_obtained` is
    reset; equip-visual overlay is removed.
13. For legendary — confirm it does NOT appear in Pandora Legacy's
    active-item roulette (it should be in the `passive_names`
    exclusion set in `legendary_items.py`).

Any failure = back to the checklist.
