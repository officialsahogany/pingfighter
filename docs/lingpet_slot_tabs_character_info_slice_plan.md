# Lingpet Slot Tabs (Character-Info Panel) — Slice Plan

Status: **IMPLEMENTED (Claude-wired, 2026-06-26).** All 8 touch points below are
done; sealed by `godot/tests/character_info_lingpet_slot_tabs_smoke.gd`
(snapshot order/active/sentinel/pair/fallback + real click→switch + schema +
input wiring), reverse-verified, and regression-checked against
`character_info_live_stats_smoke`, `character_info_overlay_prewarm_smoke`, and
`lingpet_battle_slot_hud_removed_smoke`. Remaining: live windowed pixel QA with
2+ owned lingpets. Original intent: design note for user-wired GDScript; the user
then asked Claude to wire it directly.

## 0. Goal / chosen behavior

In the TAB character-info overlay's **lingpet panel**, draw up to **3 tabs** to
the **right of the "링펫" header**, one per acquired lingpet, in **acquisition
order** (slot 0 = first acquired). Clicking a tab:

1. **Switches the active companion** to that lingpet (real swap, same as the
   in-battle `KEY_L` cycle — `lingpet_egg_runtime.switch_lingpet_slot`), AND
2. **Refreshes the panel** so it shows the now-active lingpet's full info.

The active tab is visually highlighted; the panel body below keeps showing the
active lingpet (unchanged drawing path). This is the chosen "활성 교체 + 정보
표시" behavior.

Default assumptions (state them, no need to re-ask):
- Tab label = lingpet display name (`LingpetCatalog.get_display_name`), fit /
  truncated to tab width via the existing `_fit_text_to_width` helper.
- Order = the battle-slot array order (`lingpet_slots`), which is already
  acquisition order (`lingpet_collection_state._assign_pet_to_first_empty_slot`
  fills first-empty in acquisition order).
- Up to 3 tabs. Empty slots render as **dim, non-clickable placeholders** so the
  3-slot capacity reads, OR are omitted — pick during wiring; recommend dim
  placeholders for "최대 3개까지" clarity. Switching to an empty slot is always a
  no-op (`switch_lingpet_slot` returns false for an empty slot).

## 1. Data — extend the lingpet panel snapshot

File: `godot/scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd`
(`build_panel_snapshot`, re-exported by
`character_info_overlay_lingpet_presenter.build_panel_snapshot` at presenter
line 793 — edit the **builder**).

Add a `slot_tabs` array to the returned snapshot (for the `companion` state at
minimum; harmless to include for `none`/`egg` too — it will just be empty there):

```
"slot_tabs": [ {"slot_index": int, "pet_id": String, "name": String, "active": bool}, ... ]
```

Build it from owner fields (read via the passed `safe_owner_get`):
- slots: `safe_owner_get(owner, "lingpet_slots", [])` then fall back to
  `"ringpet_slots"` (mirror the `lingpet_*` → `ringpet_*` pair fallback used
  everywhere else in this builder).
- active index: `safe_owner_get(owner, "lingpet_active_slot_index", -1)` then
  `"ringpet_active_slot_index"`.
- name per occupied slot: reuse the file's existing `_get_display_name(pet_id)`.
- Only emit a tab entry for **occupied** slots (`pet_id != ""`); the presenter
  decides whether to also draw dim empties up to 3.

### Traps (data)
- **Owner-Field Schema Trap.** `lingpet_slots` (default `[]`) and
  `lingpet_active_slot_index` (default `-1`) are already declared in
  `battle_scene_state.gd` `DEFAULT_VALUES` (lines 228 / 234), so the
  schema-gated owner read works. Do NOT add a new owner key for this; the data
  is already mirrored by `lingpet_collection_state._sync_owner_slots`.
- **`-1` active-index sentinel.** `lingpet_active_slot_index` defaults to `-1`
  ("never synced"). Resolve the active tab the same way
  `lingpet_collection_state.get_active_slot_index_from_owner` /
  `find_active_slot_pet_id` do: if the synced index `>= 0` use it; else pick the
  slot whose `pet_id == snapshot.pet_id` (the active companion); else the first
  occupied slot. Never force slot 0 on a `-1`.
- **Empty `lingpet_slots` fallback.** If the mirror array is empty but
  `snapshot.pet_id != ""` (companion present, slots not yet synced), emit a
  single tab for the active pet so the header never shows zero tabs while a
  companion is on field.

## 2. Draw — header tabs in the lingpet panel

File: `godot/scripts/hud/character_info_overlay_lingpet_presenter.gd`
(`draw_panel`, lines 79-91; the "링펫" header is drawn at line 84).

- Add a new out-param rect array `slot_tab_rects: Array` to `draw_panel`
  (alongside `skill_icon_rects` / `unlock_card_rects` / `ring_core_rects`), and
  `slot_tab_rects.clear()` at the top next to the other `.clear()` calls
  (lines 80-82).
- After the `_draw_text_xy(... "링펫" ...)` header call (line 84), measure the
  header text width (`_text_size` / the font), then lay out up to 3 tabs to its
  right within `rect` (header band ≈ `rect.position.y + 8 .. +28`). For each
  tab in `snapshot.slot_tabs`:
  - draw a small pill/box (active = filled/`accent_blue`; inactive = `slot_fill`;
    empty placeholder = dim `empty_text_color`),
  - draw the fit-truncated name (`_fit_text_to_width`),
  - append `{"rect": Rect2, "slot_index": int, "pet_id": String}` to
    `slot_tab_rects` (only for **occupied** tabs — empty placeholders get no
    clickable rect).

### Traps (draw)
- Tabs live in the **header band** (right of "링펫", above `content_rect` which
  starts at `rect.position.y + 36`, line 85) — they do NOT overlap the body, so
  no content reflow is needed. Do not push `content_rect` down.
- **Width fit.** The panel can be narrow (`content_rect` compact threshold is
  260px, line 148). Compute available width = `rect.end.x - (header_end_x +
  gap)`; size the 3 tabs to fit and fit-truncate names. If even truncated tabs
  don't fit on the header row at the smallest real panel width, fall back to a
  shorter token (e.g. slot number or 1-2 char name) rather than overflowing the
  panel border.
- Mirror the existing rect-append shape: `unlock_card_rects` stores dicts
  (`{"rect", "pet_id", ...}`, presenter line 291); `ring_core_rects` stores bare
  `Rect2` (line 970). Use the **dict** shape for `slot_tab_rects` (you need
  `slot_index`).

### Wiring the new rect array through the draw chain
File: `godot/scripts/hud/character_info_overlay_frame_presenter.gd`
- `_draw_sections` (line 101) and the `draw_panel(...)` call (line 133) thread
  `lingpet_skill_icon_rects` / `lingpet_unlock_card_rects` /
  `lingpet_ring_core_rects`. Add `lingpet_slot_tab_rects` the same way (add the
  param to the `_draw_sections`/caller signatures and pass it into `draw_panel`).
File: `godot/scripts/hud/character_info_overlay_state.gd`
- Declare `var _last_lingpet_slot_tab_rects: Array = []` next to
  `_last_lingpet_unlock_card_rects` (line 119) / `_last_lingpet_ring_core_rects`
  (line 120), and pass it as the array the frame presenter fills (mirror how
  `_last_lingpet_unlock_card_rects` reaches `_draw_sections`).

## 3. Click — switch the active companion

File: `godot/scripts/hud/character_info_overlay_support.gd`
Add a handler mirroring `_try_handle_lingpet_unlock_pick_click` (line 146):

```
func _try_handle_lingpet_slot_tab_click(mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
    for raw_entry in _last_lingpet_slot_tab_rects:
        if not (raw_entry is Dictionary): continue
        var entry: Dictionary = raw_entry
        var rect_value: Variant = entry.get("rect", Rect2())
        if not (rect_value is Rect2): continue
        if not (rect_value as Rect2).has_point(mouse_pos): continue
        var runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "lingpet_egg_runtime")
        if runtime == null or not runtime.has_method("switch_lingpet_slot"): return false
        return bool(runtime.switch_lingpet_slot(int(entry.get("slot_index", -1)), owner, registry))
    return false
```

File: `godot/scripts/hud/character_info_overlay_input_handler.gd`
In `_handle_mouse_button` left-click branch (lines 41-47), call the new handler
(put it first, before `_try_handle_lingpet_unlock_pick_click`):

```
if bool(target.call("_try_handle_lingpet_slot_tab_click", mouse_event.position, owner, registry)):
    target.call("_reset_hover_and_request_redraw", true)
    return true
```

### Traps (click)
- **Do NOT touch `battle_scene_input_controller.gd`, and do NOT re-create
  `lingpet_battle_slot_hud.gd` or any `get_slot_index_at_position`.** The
  in-battle slot HUD + its click hit-areas were deliberately removed and are
  sealed by `lingpet_battle_slot_hud_removed_smoke.gd` (asserts no
  `get_slot_index_at_position` / no `lingpet_battle_slot_hud.gd` in battle
  input/renderer, and that battle-screen slot clicks do not switch). This new
  UI lives ONLY in the **character-info overlay** surface — a different input
  path — so it does not violate that seal. Keep it that way.
- `switch_lingpet_slot` already no-ops correctly: returns false for an empty
  slot, and for the already-active slot it returns true but stays on the same
  pet (presenter lines 808-816). On a false return, the handler returns false →
  the click is not consumed and no redraw is forced (matches the unlock-pick
  semantics). Only request redraw on a true switch.
- The overlay is the read path; `switch_lingpet_slot(slot_index, owner,
  registry)` mutates runtime + owner. Confirm the overlay actually has a live
  `registry` here (the unlock-pick path already calls `commit_unlock_pick` with
  `owner, registry`, so the plumbing exists).

## 4. Hover tooltip (optional, do last)

Optional consistency: give each tab a hover tooltip (name + "동행 중"/"교체").
If added, register a hover signature in
`character_info_overlay_hover_geometry.gd` mirroring the `lingpet_ring_core`
signature (lines 106 / 132 / 167 / 193), and route any new label string through
`LanguageSettings.translate_text`. Skip for the first cut if time-boxed.

## 5. Smoke spec (required; reverse-verify)

Add `godot/tests/character_info_lingpet_slot_tabs_smoke.gd` (or extend an
existing overlay smoke). Assert OUTCOMES, not just presence:

1. **Snapshot order + active flag.** Given an owner with
   `lingpet_slots = ["maribo","lunabi",""]` and `lingpet_active_slot_index = 1`,
   `build_panel_snapshot(...).slot_tabs` has 2 entries in order
   `[maribo(slot0,active=false), lunabi(slot1,active=true)]` with correct
   display names. Then set `lingpet_active_slot_index = -1` and assert the active
   flag falls back to the slot whose `pet_id == snapshot.pet_id` (NOT slot 0).
   Add the `ringpet_slots` / `ringpet_active_slot_index` pair-fallback case.
2. **Click → switch.** With `_last_lingpet_slot_tab_rects` populated (drive
   `draw_panel` or seed the array), a click inside slot 1's rect calls
   `runtime.switch_lingpet_slot(1, owner, registry)` (use a fake runtime that
   records the call, like `FakeRuntime.switch_lingpet_slot` in
   `lingpet_battle_slot_hud_removed_smoke.gd`). A click on an empty slot's area
   does NOT call switch (no rect appended). Reverse-verify: removing the
   input-handler wiring makes the click assertion FAIL.
3. **No-op semantics.** A click on the already-active tab where
   `switch_lingpet_slot` returns true-but-same does not crash and the active
   pet is unchanged; a false return does not consume the click.
4. **Seal the battle-HUD boundary stays intact.** A string assert that
   `battle_scene_input_controller.gd` still contains no `get_slot_index_at_position`
   (so the new feature didn't leak into battle input) — or just rely on the
   existing `lingpet_battle_slot_hud_removed_smoke.gd` continuing to pass.

### Traps (smoke)
- **Owner-Field Schema Trap.** Use a **schema-gated** owner (one that routes
  `set`/`get` through `BattleSceneState`, like the real `battle_scene_shell`),
  NOT a plain dict fake that stores any key, so `lingpet_slots` /
  `lingpet_active_slot_index` reads behave like production. A permissive dict
  fake would pass even if the keys were undeclared.
- Drive the **real** `switch_lingpet_slot` path in at least one case (not only a
  recording fake) so the outcome (active flag moves) is exercised end to end, or
  assert the active flag flips in the rebuilt snapshot after a real switch.
- Run via `godot/tools/run_smoke_tests.ps1 -Tests "res://tests/<name>.gd"`;
  reverse-verify each new assertion FAILS with the corresponding wiring removed
  (in-place edit toggle, never git reset).

## 6. Localization

Tab labels are lingpet display names from `LingpetCatalog.get_display_name`,
already localized. The "링펫" header is a pre-existing Korean literal — leave it.
The only new user-facing strings would be optional tooltip copy (§4) — route
those through `LanguageSettings` and add to the i18n maps + coverage smoke if
introduced.

## 7. File touch list (summary)

| File | Change |
|---|---|
| `character_info_overlay_lingpet_snapshot_builder.gd` | add `slot_tabs` to snapshot (order + active + names; sentinel + pair fallbacks) |
| `character_info_overlay_lingpet_presenter.gd` | `draw_panel`: new `slot_tab_rects` out-param + `.clear()`; draw header tabs after line 84 |
| `character_info_overlay_frame_presenter.gd` | thread `lingpet_slot_tab_rects` through `_draw_sections` → `draw_panel` |
| `character_info_overlay_state.gd` | declare `_last_lingpet_slot_tab_rects` |
| `character_info_overlay_support.gd` | add `_try_handle_lingpet_slot_tab_click` (mirror unlock-pick) |
| `character_info_overlay_input_handler.gd` | call the new handler in the left-click branch |
| `character_info_overlay_hover_geometry.gd` | (optional) tab hover signature |
| `godot/tests/character_info_lingpet_slot_tabs_smoke.gd` | new smoke (see §5) |

## 8. Out of scope / open

- Acquiring lingpets beyond the current paths (egg item / plaza) — unchanged.
  This slice only surfaces + swaps what the player already owns.
- The active item (`lingpet_egg`) only deploys at `STATE_NONE`; it does not fill
  empty slots up to 3 (that is a separate design question, not part of this UI
  slice). Flag for the design owner if "egg fills a 2nd/3rd slot" is desired.
- Empty-slot visual (dim placeholder vs omit) — wiring-time choice; recommend
  dim placeholders to convey the 3-slot capacity.
```
