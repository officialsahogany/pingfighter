# Plaza Shop Overhaul — Codex GOAL Execution Plan

Single self-contained brief for an autonomous Codex **GOAL** run. Companion to
`docs/plaza_port_plan.md` §0.10/§0.11 and `docs/plaza_6building_interior_recipes.md`.
Generation (imagegen/AutoSprite) + GDScript wiring + smokes = **Codex**.
Final review (pixel + code + adversarial smoke gate) = **Claude only**.

Grounded by a 5-area research pass (2026-06-17): original PingFighter shop UI,
economy, current Godot state, AutoSprite runtime, art layering. All file:line
refs below are verified.

---

## 0. Goal statement
Overhaul the plaza SHOP interior (currently v1: room backdrop + NPC + 3 pedestal
objects + confirm panel, committed e26ca5bf4) to the reference cyberpunk VR
junk-shop look + interaction:
1. The table reads as a **cloth/바닥보 spread with a glowing arcane circle**, with
   money bundles + items **strewn** across it (not a clean pedestal counter).
2. Strewn money/items: **hover = soft glow; click = that item ANIMATES** (AutoSprite
   spritesheet).
3. After the click-animate, an **original-PingFighter-style trade UI**: LEFT =
   player inventory (sell), RIGHT = shop inventory (buy).

GOAL = complete all three end-to-end, phased so each phase is independently
valuable + committable (the godot-wip branch HEAD advances via external commits —
commit each phase when gated; do NOT accumulate one giant uncommitted blob).

---

## 1. Locked decisions (do NOT re-litigate; Claude-authored)
- **D1 — Inventory model = PASSIVE/LEGENDARY via `mythic_item_runtime`** (original
  parity; the original LEFT panel = `passive_item_list`). The runtime ALREADY
  exists: BUY = `mythic_item_runtime.acquire_item(name, owner, registry, overrides,
  auto_equip=false, sound)`; SELL = `discard_inventory_item(index, owner, registry)`;
  LEFT panel source = `mythic_item_runtime.inventory_items` (via
  `get_inventory_item(index)` / `get_inventory_item_counts()`); ownership uniformity
  is handled by acquire_item (do NOT hand-set per-legendary `*_obtained` flags — the
  original `_buy_shop_item` omits some; acquire_item is the correct uniform path).
  This is NOT a from-scratch runtime build — it is a binding to existing infra.
  *(The active-item v1 path stays as-is for now; the new trade UI is passive/legendary.)*
- **D2 — Pricing = port the legacy table** into a NEW `godot/scripts/plaza/plaza_shop_pricing.gd`.
  BUY = `base_price + quality_roll_bonus` (passive tier mult 1.0/1.35/1.6/1.9 + roll
  range .08/.10/.12/.15; legendary mult 0.85→1.25 by roll percentile). SELL =
  **30%** of full value (× enhancement +20%/level), × (1+bargain). `gold_bar` fixed
  2000G via existing `GOLD_BAR_SELL_PRICE`. Source tables: `building_interior.py:3156-3206`
  (33 passive + 12 legendary base_price) + `:9022-9077` (_get_item_base_price) +
  `:9157-9202` (_get_quality_and_roll_bonus). **Restrict the shop pool to items the
  Godot battle runtime actually implements** (intersect the legacy list with
  `mythic_item_catalog` FIELD_SPAWN_ORDER) — do not sell unimplemented items.
- **D3 — Shop stock roll**: on shop OPEN, roll 5–12 items (95% passive dup-allowed /
  5% legendary unique-in-stock) from `mythic_item_catalog` via `build_item_by_name`
  + `build_random_rolls` + `sync_roll_fields` + `passive_item_quality.assign_item_prefix`.
  Re-roll on each plaza ENTRY (not per visit-within-a-session). Sold-back items
  re-list in shop stock at full value (original behavior).
- **D4 — AP policy = keep per-VISIT AP** (plaza is intentionally AP/열쇠-gated; this
  diverges from original free-trade by design). Entering/first-trade consumes 1 AP
  once via the existing `_active_menu_visit_ap_consumed` gate; **all buy/sell within
  the visit are FREE** (matches original free-within-trade + plaza AP-gate). Wallet =
  `plaza_save_store.perform_shop_wallet_transaction('purchase'|'sale', amount,
  consume_ap)` per transaction, AP only on the first.
- **D5 — "오늘의 특가" + "매일 00:00 갱신" = FLAVOR, not a real clock feature.** The
  original has NO daily refresh and the reference's 코어 데이터 결정/체력 회복 캡슐 are
  fictional. Implement: 2 **featured "특가" pedestals** = 2 of the rolled shop items at
  a flat discount (e.g. −20%), re-chosen on each stock roll; the "매일 00:00 갱신"
  string is decorative copy only (no wall clock). Featured product click = quick-buy
  confirm for that discounted item.
- **D6 — Interaction flow**: strewn item click → it animates (AutoSprite, ~0.6s
  one-shot flourish) → **then open the LEFT/RIGHT trade UI**. Featured pedestal click
  → animate → quick-buy confirm (small panel) for that specific 특가 item. ESC in
  trade UI → back to cloth scene; ESC/나가기 in cloth scene → exit shop (existing
  plaza warp exit). Trade UI is a 620×420 modal over a dim overlay (0,0,0,180).
- **D7 — Art = REGENERATE the room backdrop (v2) as a Hearthstone-like TOP-VIEW board.**
  Do NOT reuse v1 (it bakes an industrial front-facing room / pedestal counter — wrong
  camera model). v2 must read as a high-oblique tabletop/cloth board filling the
  760×750 canvas: cloth/바닥보 + central arcane circle + strewn junk around the edges +
  2 empty featured-product pads in the lower table + far-wall CRT / neon cat / BUY
  terminal clutter at the top edge. Runtime UI text/buttons/prices remain drawn by
  Godot. Interactive strewn items remain separate sprites where precise hover/click
  hit targets are needed.

---

## 2. Phases (GOAL executes in order; commit each after Claude gate)

### Phase A — Art assets (generation = Codex)
- **A1 Room v2 backdrop** (`imagegen`, opaque, 1:1 source):
  `plaza_stage1_interior_shop_room_topview_imagegen_v2.png`. Prompt target: cyberpunk
  VR junk-shop, **high-oblique top-view board-game / Hearthstone-like tabletop**,
  cloth/fabric mat (바닥보) filling the screen with a central arcane circle, strewn
  coins/gears/gadgets/cables around the board edges, 2 EMPTY featured-product pads in
  the lower half, far-wall clutter only along the top edge (CRT/cables/pink neon
  cat-face/BUY terminal/shelves), purple-magenta neon + cyan glow + warm-amber rim.
  STRICT EXCLUSIONS: no readable UI text/numbers, no hand cursor, no watermark, no
  border. Keep top-left, top-right, bottom-left, bottom-right legible for Godot overlay.
- **A2 Strewn item sprites** (6–9, 512² transparent, `#00ff00` chroma → `chroma_key.py`,
  generous glow margin no edge-touch): money_bundle, coin_pile, gear, wrench_tool,
  circuit_gadget, data_cube (+ optional vial, scrap_chip). Static base art.
- **A3 Click-animate sheets** (AutoSprite MCP per `/sprite-generation`, REQUIRED source —
  not Gemini/FLUX): per strewn item, `animate_asset(isLooping=true, frameSize=512,
  maxFrames~25, turbo)` → `<item>_anim_sheet.png` + **record per-asset (cols,rows,
  frame_count) in a sibling `_manifest.json`** (atlas-grid-authority trap). ~80–128px
  effective cell on screen (bound VRAM).
- **A4 Featured product sprites** (2, 512² transparent floating) — reuse/regen the
  existing capsule/crystal style.
- Paths: `godot/assets/ui/plaza/interior/`. **Every PNG: run import pass, commit
  `.png.import` + verify `.godot/imported/*.ctex`** (export-drop trap; headless-load
  passing ≠ proof).
- **Gate A (Claude)**: pixel — v2 reads as cloth+arcane-circle (not industrial bench),
  strewn sprites clean transparent cutouts w/ margin, AutoSprite sheets animate
  (mid/late frames), no chroma fringe.

### Phase B — Cloth + strewn interactive layer (wiring = Codex)
- Swap room loader path → v2 (`INTERIOR_ROOM_TEXTURE_PATHS["shop"]`), reuse cover-fit
  draw (`plaza_interior_view.gd:212-231`) + `load_imported_texture`.
- **Restructure the object model**: the current 3-pedestal model (`_build_object_specs`/
  `_get_default_object_rects`/`_get_object_kind`/`_draw_object` 3-rect row + confirm
  micro-panel) → a **strewn-item array** (N items at authored Rect2 scatter positions on
  the cloth) + the 2 featured pedestals. Strewn items draw their static icon directly on
  the cloth (NO runtime pedestal — avoid dual-pedestal; only featured use the baked
  pedestals). Reuse hit-test `_get_object_at_game_pos` (rect.grow + reverse-iterate) +
  hover lerp glow (`_draw_object:353-377`).
- **Click-animate = clone `lingpet_companion_click_reaction_state.gd`** (RefCounted:
  grid consts per-item from manifest, timer/frame/alpha lifecycle, `draw_texture_rect_region`
  slice, start/advance/reset). One active-animating-item state + clicked id (mirror
  companion walk→reaction swap). Drive `advance()` from the view's process tick (freeze
  if tick skipped). On click: start animation; on completion (~0.6s) → open trade UI (D6).
- **Prewarm** all strewn static icons + anim sheets via `PlazaAssetLoader.
  get_prewarm_texture_paths` (cached-peek-then-ensure; NEVER lazy-load in draw/process —
  hot-path trap).
- **Gate B (Claude)**: pixel — hover softly glows the strewn item; click plays its
  AutoSprite animation; cloth+arcane-circle reads; no dual pedestals. State smoke alone
  insufficient — windowed screenshot required.

### Phase C — Shop pricing + inventory model (Codex)
- New `plaza_shop_pricing.gd` (port D2 tables/formulas). New shop-inventory roller
  (D3) producing a `shop_inventory: Array[Dictionary]` of catalog items w/ rolls +
  computed price + 특가 discount flags.
- Bind to `mythic_item_runtime` (D1) for the real owned-item model.
- **Smoke**: price-table parity (sample items match legacy base_price), roll count
  5–12, legendary unique-in-stock, sell=30% (+gold_bar fixed 2000), pool ⊆ implemented
  catalog. Reverse-verify the price math (a wrong multiplier fails).

### Phase D — LEFT/RIGHT trade UI (Codex)
- Port `_draw_shop_trade_ui` (`building_interior.py:8185`) **verbatim geometry** (760×750
  = 1:1): modal 620×420 at (70,165); dim overlay (0,0,0,180); LEFT panel (90,215,280,320)
  cyan "내 인벤토리 (판매)" = `mythic_item_runtime.inventory_items`; RIGHT panel (390,215,
  280,320) gold "상점 물품 (구매)" = `shop_inventory`; 5-col 42px cells / 6px gap / 4px
  icon inset; per-panel scroll (wheel + scrollbar at panel_w−12); rich hover tooltip
  (quality-colored name + slot label + price line w/ discount + wrapped desc + roll
  options); equipped 'E' badge + yes/no confirm before selling equipped.
- Interaction: **right-click = instant buy/sell**; left-drag across panels = buy/sell,
  within = reorder; ESC/outside = close. Drag-ghost + gold-float anim + trade sound.
  (Per-item icon load+cache path keyed by `get_icon_path`; source-cache separate from
  scaled output; `load_imported_texture`.)
- BUY = pricing+wallet purchase → `acquire_item`; SELL = wallet sale → `discard_inventory_item`
  + re-list in shop_inventory. Atomic (validate→pay→grant, rollback on fail); AP per D4.
- Palette verbatim: BG_DARK(22,26,40), PANEL_BG(30,36,54), BORDER_CYAN left,
  BORDER_GOLD right, CELL_HOVER(150,200,255).
- **Smoke**: open/close, buy debits gold + adds to inventory, sell credits gold +
  removes, equipped-sell confirm, scroll, AP once-per-visit, schema-gated owner (not
  plain FakeOwner — Owner-Field Schema Trap). Localized strings present + no
  "PingFighter/핑파이터".

### Phase E — Wiring / flow (Codex)
- Entry flow per D6 (strewn click→animate→trade UI; featured→animate→quick-buy).
  `_build_interior_view_data` extended to pass owner inventory snapshot
  (`mythic_item_runtime.inventory_items`) + shop_inventory. Action callback extended
  beyond single action_index to carry per-item buy/sell ops + hover/scroll state.
- ESC/exit layering: trade UI ESC → cloth; cloth ESC/나가기 → existing plaza warp exit.
- **Smoke**: full flow (enter → strewn click → animate flag → trade UI open → buy →
  gold/inventory change → ESC → cloth → exit).

### Phase F — Integration gate (Claude final 검수)
See §4 acceptance.

---

## 3. Consolidated traps (Codex MUST heed — from research + repo memory)
1. **No passive grant runtime "gap" is a non-issue**: use `mythic_item_runtime`
   (acquire/discard/inventory_items) — it exists; do NOT hand-roll a new inventory or
   hand-set legendary `*_obtained` flags.
2. **Owner-Field Schema Trap**: `owner.set()` only persists keys in
   `BattleSceneState.DEFAULT_VALUES`. Any NEW synced key silently no-ops. Test with a
   schema-gated owner (delegating to BattleSceneState), NOT a plain-dict FakeOwner
   (current `plaza_shop_menu_smoke` FakeOwner only declares active_item_slots).
3. **Atlas grid authority**: runtime hardcodes (cols,rows,frame_count) consts; it does
   NOT read the manifest. Each AutoSprite sheet declares its own const matched to its
   grid — wrong grid slices silently (no error), caught only by zoom-render QA.
4. **load_imported_texture (NOT raw load_texture)** for every PNG (room v2 + strewn +
   sheets + icons); raw decodes full-size + ignores size_limit → hitch/VRAM.
5. **.import sidecar + .ctex committed** for every new PNG (export-drop; headless-load
   passing ≠ proof — run import pass, verify ctex).
6. **Hot-Path Lazy Init Trap**: prewarm all room/strewn/sheet/icon textures at
   configure/update_state; never load in `_draw`/`_process`. Use cached-peek-then-ensure.
7. **Dual-pedestal**: strewn items draw directly on cloth (no runtime pedestal); only
   featured use baked pedestals.
8. **Unit trap**: `plaza_gold` is GOLD units; shop prices (750–4560) assume gold scale.
   Never wire result-screen ★ placeholders / STARPOINT into prices.
9. **AP**: route all trades through the per-visit gate (`_active_menu_visit_ap_consumed`);
   never lose an item with no payout (AP-check + validate before grant/remove).
10. **Localization + rebrand**: all new copy (panel titles, sell/buy hints, 특가, refresh
    notice) in `language_settings_data.gd` for all locales. The player-facing
    product label is **환격전**; do not reintroduce PingFighter/핑파이터 or an
    earlier Korean product label.
11. **Relight re-QA**: v2 cloth is brighter/different than v1 — re-tint any dark glow/
    shadow/contact-shadow overlays drawn over it as shadows OF the lit cloth, not neutral
    black.
12. **Coordinate space**: interior view is a self-contained Control, GAME_SIZE 760×750,
    `_to_game_pos = local/scale` (single factor, no game_offset). Letterbox clip trap does
    NOT apply here. Click localized via `_localize_interior_event`.
13. **Modal input/redraw**: the 620×420 trade UI must dim+capture input and redraw the
    cloth behind it (overlay 0,0,0,180); the current micro-panel does not dim — add a real
    modal layer in handle_input/_draw.

---

## 4. Acceptance criteria (Claude final 검수 — windowed pixel + code + adversarial smoke)
- **Pixel** (real interior, windowed, 760×750 screenshot): cloth/바닥보 + central arcane
  circle reads; strewn money/items scattered on cloth; hover softly glows the item;
  click plays its AutoSprite animation; trade UI opens with LEFT=player inv / RIGHT=shop
  inv, real icons (not blank cells) + readable tooltips; featured 특가 pedestals read;
  NPC-left + title + gold + 나가기 + refresh-notice legible; no chroma fringe; lighting
  coherent.
- **Economy**: buy debits gold + item lands in `mythic_item_runtime.inventory_items`;
  sell credits 30% + item leaves inventory + re-lists in shop; gold_bar fixed 2000;
  prices match the ported legacy table; AP once-per-visit; not-enough-gold rejects cleanly.
- **Code/smoke** (all GREEN, Claude re-runs — don't trust report): per-phase smokes +
  integration smoke; `.import`/`.ctex` present; `load_imported_texture`; atlas grid consts
  match sheets; warning scan 0; headless load; git diff --check; corruption scan.
  **Reverse-verify** the load-bearing seals (price math, buy/sell inventory deltas, AP
  once-per-visit) — prove each fails on the buggy code via in-place toggle (revert clean,
  verify with git diff — NEVER git reset/checkout/stash; see workflow-mutating-verify trap).
- **Commit hygiene**: each phase scoped to plaza-shop files only (no lingpet/F7/Onimaru/
  audio leak); commit per gated phase (moving-HEAD branch).

---

## 5. Reuse map (exact clone/extend targets)
- Trade UI geometry/colors/interaction: `downtown/building_interior.py:8185-8516`
  (_draw_shop_trade_ui), `:5328-5500` (buy/sell/drag), `:8517-8696` (tooltip),
  `:3139-3289` (_init_shop_inventory), `:9022-9202` (pricing).
- Click-animate state: `godot/scripts/lingpet/lingpet_companion_click_reaction_state.gd`
  (clone) + wiring `lingpet_egg_runtime.gd:2653-2669/192/305-333` + prewarm `:2087-2111`.
- Sheet slice helper: `plaza_scene.gd:771 _get_sheet_frame_rect` (grid params).
- Inventory runtime: `mythic_item_runtime.gd` acquire_item/discard_inventory_item/
  get_inventory_item; `mythic_item_catalog` build_item_by_name/build_random_rolls;
  `passive_item_quality.gd` assign_item_prefix; `GOLD_BAR_SELL_PRICE` (mythic_item_stat_bonus_runtime.gd:11).
- Wallet/AP: `plaza_save_store.perform_shop_wallet_transaction` + `plaza_scene.gd:2074-2092`
  per-visit gate.
- Interior view seams: `plaza_interior_view.gd` (object specs/hover/hit-test/draw,
  `_draw_room_backdrop_texture`), `plaza_scene.gd:1843-1905` (_open_interior_view/
  _build_interior_view_data/_trigger_interior_action).
- Asset loader: `plaza_asset_loader.gd` INTERIOR_ROOM/OBJECT_TEXTURE_PATHS +
  load_imported_texture + get_prewarm_texture_paths.

## 6. Asset deliverables
- 1× room v2 backdrop (+.import) — cloth + arcane circle + 2 featured pedestals.
- 6–9× strewn item static 512² (+.import each).
- 6–9× strewn item AutoSprite `_anim_sheet.png` (+.import + _manifest.json grid each).
- 2× featured product 512² floating (+.import).
- Per-item icon textures for the trade-UI grid (reuse `mythic_item_catalog get_icon_path`
  PNGs; ensure loaded+cached, not re-decoded per frame).
