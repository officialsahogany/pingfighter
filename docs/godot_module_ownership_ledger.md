# Godot Module Ownership Ledger

Current implementation target: Godot **환격전**.

This ledger was split out of `docs/godot_port_architecture.md` to keep the
architecture guide readable. It records module ownership, split history, and
current port status so future work can resume without re-discovering every
owner.

Read this as a ledger, not a rulebook:
- Module entries describe who owns a behavior today and what was ported.
- Older `Python-parity`, `legacy`, or `current` wording records why the module
  exists or what behavior it matched at the time.
- New implementation detail belongs in the focused architecture, port, item,
  character, performance, or other owner checklist; cross-cutting incidents use
  a stable GRT entry. Root files keep only concise routing and non-negotiable
  safety contracts.

---

## Module Ownership Ledger / Cumulative Port Log

This section is intentionally long; use search to find the nearest owner.

- `scripts/plaza/`
  Owns the first Godot plaza shell for 환격전:
  stage-theme fallback, accepted plaza floor/building asset loading and
  prewarm, fixed 2400x1500 outer map-world state projected through the plaza
  root render rect, unchanged 760x750 interior/trade projection, S4.5 parallax
  layers, S1 sidewalk/VR-strata ground strip reuse, player X-walk/X-camera
  state, per-instance CPU emissive flicker, S5 building menu shells, S6a
  `plaza_save_store.gd` persistent gold/AP ledger, S6b-1 bank deposit/withdraw/
  stage-interest transactions, S6b-2 `plaza_shop_transactions.gd` mixed
  passive/active shop buy/sell/reorder transactions, S6b-3
  `plaza_blacksmith_transactions.gd`
  active-slot enhancement attempts, S6b-4 `plaza_gacha_transactions.gd`
  active-item capsule pulls, S6b-5 `plaza_lingpet_store_transactions.gd`
  resonance-egg purchases that call `lingpet_egg_runtime` without directly
  mutating lingpet ownership, and the EXIT-zone callback surface.
  R1 intentionally promoted the outer `MAP_SIZE` from 1900x750 to 2400x1500:
  the EXIT zone moved from x=1750 to x=2250 and the one-axis camera right clamp
  from 1140 to 1640. The save-owned `stage_map_seeds` values are not rewritten;
  because the current one-axis position applicator consumes world width, an
  existing preserved seed receives one accepted coordinate-layout shift at the
  update boundary and is deterministic again under the fixed 2400 input. The
  production 60Hz normal-input route measured and accepted 533 frames / 8.883s
  to the new exit versus 408 frames / 6.800s at the legacy threshold.
  `stage_clear_result_screen.gd` only routes into `scenes/plaza.tscn` after
  rewards are granted, delegates plaza scene spawn / prewarm / forwarding to
  the result-screen plaza scene helper, delegates volatile `runtime_perk_gold`
  transfer and one-shot stage-clear AP application to the result-screen plaza
  progress helper, and delays the existing next-stage reset callback until the
  plaza exits; plaza-local movement, interaction, and save-ledger state stay
  under `scripts/plaza/`.
- `scripts/plaza/plaza_transaction_message_formatter.gd`
  Owns player-facing success and failure copy for bank, shop, gacha, Lingpet
  Store, blacksmith, academy, and tavern transaction summaries, including shop
  item-name localization. `plaza_scene.gd` retains only compatibility facades
  that delegate each facility summary to this formatter.
- `scripts/plaza/plaza_transition_state.gd`
  Owns building enter/return and plaza arrival/exit warp phase, timer, target,
  actor-anchor snapshots, clamped progress, and actor fade/lift envelopes.
  `plaza_scene.gd` retains transition orchestration only: opening a completed
  building target, syncing the warp FX host, and firing the exit callback.
- `scripts/plaza/plaza_building_menu_session_state.gd`
  Owns the active building-menu identity, title/subtitle/actions, last feedback
  message, and per-visit AP-consumed state. The scene reads this owner for
  presentation/input and must route state changes through its methods.
- `scripts/plaza/plaza_transaction_summary_store.gd`
  Owns deep-copied last-transaction summaries for all seven plaza facilities
  and the close-vs-new-visit clearing policy. `plaza_scene.gd` applies every
  facility result through one finalizer that records the summary, commits the
  menu visit AP edge, refreshes the save snapshot, and queues presentation.
- `scripts/plaza/plaza_building_menu_catalog.gd`
  Owns the seven building-menu title/subtitle/default-action specs and NPC
  display names. The scene may override runtime-dependent action lists, but it
  must obtain the base open-state projection and NPC names from this catalog.
- `scripts/plaza/plaza_minimap_projection.gd` and `plaza_minimap_renderer.gd`
  Own minimap geometry/state projection and all panel, track, marker, badge,
  and facility-emblem draw calls. `plaza_scene.gd` retains only live input
  assembly, a one-line draw facade, and a color compatibility facade used by
  building-menu accents.
- `scripts/plaza/plaza_actor_visual_projection.gd`, `plaza_actor_renderer.gd`,
  and `plaza_building_renderer.gd`
  Own plaza actor walking/facing/frame projection, Lingpet follow/draw geometry,
  player/Lingpet sprite and contact-shadow rendering, and building world-rect,
  culling, flicker, shadow, retained base/sign/window children, and layer-owned
  MIX/ADD materials. The building immediate draw API remains compatibility-only.
- `scripts/plaza/plaza_map_world_host.gd`
  Owns the active outer plaza's opaque fill, background-renderer call, retained
  building-child lifecycle, relative negative-z placement, and fail-closed
  visibility. `plaza_scene.gd` owns host attachment, one-tick-per-owner-frame
  sync with `render_size = plaza_scene.size`, and synchronous cleanup through
  the actual interior, plaza-exit, scene-handler free, and tree-exit routes.
  The completed R1 bridge still uses the outer scene's `GAME_SIZE = 760x750`
  side-scroll fit rather than the future full-map safe-rect fit. At 2020x1246
  the 360-unit bank is about 598px high, so its 512px texture's ~1.17x upscale
  remains an explicit Vulkan sharpness gate for this bridge.
- `scripts/plaza/plaza_asset_loader.gd`
  Owns the active Hwangyeok building manifest set, fixed 2400x1500 map-world
  size, seed-deterministic building specs, shared glow/minimap color source, and
  resource state for the 21 retained 512x512 layer textures. Production prewarm
  delegates from `plaza_scene.gd` through the map-world host and building
  renderer before reporting complete. The current position applicator remains
  one-axis and uses the fixed 2400 width in its cache key and spacing input;
  viewport-derived sizes must never enter that cache. Candidate-only R2 owners
  below do not replace this production contract until an atomic activation.
- `scripts/plaza/plaza_map_projection.gd` and
  `plaza_map_layout_generator.gd`
  Own the production-disconnected R2-A/P1 candidate: pure fixed-world/safe-rect
  projection plus deterministic road topology, plots, building assignment,
  semantic decoration, blocked/walkable/portal geometry, labels, validation, and
  the canonical layout fingerprint. Structural QA is GREEN for 56 building
  subsets x seeds 5/6/7 (168 rosters), including mutation counterproofs. They do
  not yet own the live `plaza_scene.gd` projection or position application. The
  generator's `skeleton`/`plots`/`assignment`/`decor` RNG streams are its future
  small-owner split seams; a split must preserve phase salts, fingerprint,
  168-roster outputs, and RED counterproofs rather than merely reduce its current
  2,745-line file size.
- `scripts/plaza/plaza_map_navigation.gd` and
  `plaza_map_minimap_projection_2d.gd`
  Own candidate-only R2-B full-actor walkability/swept movement, portal routing,
  mutation-detecting bound-geometry digest, and exact two-axis minimap projection from the
  shared layout. Their hardened focused gate is GREEN; the existing
  `plaza_minimap_projection.gd` remains the production owner. Production
  activation additionally requires steady-p95 measurement and moving the current
  per-move whole-geometry SHA plus `Geometry2D` clipping off the hot path into a
  bind-once immutable compiled owner and fast occupancy query under
  [GRT-032](godot_runtime_traps.md#grt-032).
- `scripts/plaza/plaza_r2_map_world_candidate_host.gd`
  Owns the production-disconnected R2-B retained candidate: strict preflight,
  caller-isolated compiled road draw records, direct building/actor Y-sort
  siblings, and relative zero-z child-layer restoration. Focused state,
  adversarial mutation, and 2020x1246 Forward Mobile A/B/C Vulkan Y-sort gates
  are GREEN. Its actual-tree recovery also rebinds Base=MIX, Sign/Window=ADD,
  clears Probe/Body materials, disables parent-material inheritance, and restores
  parent/child modulation, show-behind, and visibility after an in-place RED
  mutation; the independent audit reports CRITICAL 0 / HIGH 0. Code-drawn
  road/plot surfaces and workspace-only semantic
  decor are not final art, and no candidate owner may be called from production
  until the later atomic activation. The host's single actor item is player-only
  proof: R2-C must add the active Guardian Spirit as a direct sibling under the
  same sort root and replace the live fixed-`GROUND_Y`/linear-follow path with
  blocker-aware 2D navigation. Under
  [GRT-013](godot_runtime_traps.md#grt-013)'s 2D form, ground/patrol scripted
  reposition projects the full-body destination onto the compiled walkable union
  and may change Y for a cross-lane recall; teleport endpoints and every tracked
  sample stay walkable/outside blockers. Flight companions alone retain free Y.
- **R3 production ownership supersedes the candidate-status wording above.**
  Commit `b85847e4e` atomically connected the R3 exterior; the R1 host and R2
  hosts remain compatibility/regression owners and are not quiet production
  fallbacks.
- `scripts/plaza/plaza_map_road_skeleton_r3.gd` and
  `plaza_r3_environment_layout_compiler.gd`
  Own the production road-first layout authority and approved environment draw
  plan: central walkable hub, canonical road bases/junction bindings, integrated
  plot/access geometry, pads, ground, tiered roads, turn courts, and semantic
  decor. They preserve the selected-building/RNG meaning while owning R3 world
  coordinates.
- `scripts/plaza/plaza_r3_navigation_binding.gd`,
  `plaza_map_navigation_compiled.gd`, and `plaza_map_guardian_locomotion.gd`
  Own production binding validation, immutable allocation-bounded full-body
  movement, portal occupancy, and ground/patrol Guardian swept locomotion and
  recall projection. Compiled navigation is directly constructed from one
  validated state; a static factory that returns a newly created RefCounted is
  forbidden by the R3-E zero-ref exit seal.
- `scripts/plaza/plaza_r3_exterior_retained_host.gd`,
  `plaza_r3_minimap_projection.gd`, `plaza_r3_minimap_canvas.gd`, and
  `plaza_r3_exterior_runtime_candidate.gd`
  Own the production retained environment/building/actor tree, direct-sibling
  Y-sort, player/Guardian contact shadows, two-axis camera, minimap, portal hit,
  and measured owner cadence. The `candidate` filename is retained for
  compatibility and no longer describes connection status.
- `scripts/plaza/plaza_r3_lifecycle_prewarm_candidate.gd` and
  `plaza_r3_production_entry_host.gd`
  Own the production stage/seed compiled-cache lifecycle, resource/GPU prewarm,
  interior hide/return, teardown, opaque progress UI, finite stalled-prewarm
  failure, and one-shot R1-to-R3 reveal boundary. Their compatibility filenames
  do not authorize a fallback to R1.
- `scripts/plaza/plaza_scene.gd`
  Retains plaza reward, interior/economy, exit, and input orchestration while
  delegating the exterior map to the R3 production owners. It must not recreate
  road, navigation, minimap, retained-render, or prewarm policy inline.
- `scripts/plaza/plaza_background_projection.gd` and
  `plaza_background_renderer.gd`
  Own plaza parallax/tile/flicker/VR-strata projection plus the complete sky,
  far-sky fallback, midground wall, ground strip, emissive decoration,
  underground, and exit-zone draw recipe. The active map-world host invokes the
  recipe using the state and shared frame tick supplied by `plaza_scene.gd`.
- `scripts/plaza/plaza_flow_gate_policy.gd` and `plaza_world_geometry.gd`
  Own plaza update/input priority plus street-blocking policy, and pure fitted-
  canvas/player/camera/coordinate/building-hit geometry, respectively.
  `plaza_scene.gd` dispatches the selected flow and supplies live state through
  narrow geometry facades without retaining parallel condition chains or math.
- `scripts/plaza/plaza_status_snapshot_builder.gd`
  Owns the complete public Plaza status dictionary, including nested overlay/
  interior snapshots, transition/menu state, facility summaries, runtime-perk
  choice metadata, progression counters, minimap state, and scene geometry.
  `plaza_scene.gd::get_status()` is a narrow compatibility facade that supplies
  one required-key live context assembled by direct field/method references.
  The builder validates that context and must not reflect scene-private names
  through string `get()` / `callv()` lookups.
- `scripts/plaza/plaza_interior_view.gd`
  Is the sole visible building-interior menu and input owner. `plaza_scene.gd`
  opens, synchronizes, recovers, and frees exactly one view while retaining
  transaction orchestration; the unreachable scene-local menu/NPC renderer and
  keyboard/mouse fallback were removed.
- `scripts/plaza/plaza_interior_object_hover_state.gd`,
  `plaza_interior_object_selection_state.gd`, and
  `plaza_shop_click_animation_state.gd`
  Own interior object and click-animation state without mirrored fields in
  `plaza_interior_view.gd`. The shop-click owner deep-copies the pending object
  spec, transfers it atomically to a one-shot completed slot, and clears both on
  reset so the view never mirrors or reconstructs the completion payload.
- `scripts/plaza/plaza_trade_interaction_controller.gd`
  Owns the live trade hover/scroll/drag/sale-confirm states and composes
  `plaza_trade_drop_decision.gd` plus `plaza_trade_action_dispatcher.gd` for
  click, cross-panel trade, same-panel reorder, equipped-sale confirmation,
  cancel, and callback dispatch. The view supplies coordinates/current
  inventories and handles redraw/reclamp only. `plaza_trade_item_icon_cache.gd`
  owns texture caching, and
  `plaza_trade_item_presentation.gd` owns shared item projection/formatting.
- `scripts/plaza/plaza_interior_view_data.gd` and `plaza_interior_layout.gd`
  Own copied/normalized interior payload state and pure interior/trade geometry,
  respectively. `plaza_interior_view.gd` consumes the typed data owner and
  delegates cell draw geometry, hit tests, drop indexes, and object specs to the
  layout owner without retaining mutable payload mirrors or literal grid math.
- `scripts/plaza/plaza_shop_strewn_visual_spec.gd`
  Owns interior strewn-item texture sizes, semantic colors, animation metadata,
  and sprite-sheet frame projection. `plaza_interior_view.gd` keeps only thin
  query facades and the actual draw calls.
- `scripts/plaza/plaza_interior_chrome_projection.gd` and
  `plaza_interior_chrome_renderer.gd`
  Own non-trade title/gold/exit, normal/top-view NPC, shopkeeper speech-bubble,
  and selected-object panel snapshots plus their concrete `CanvasItem` drawing.
  The view supplies live texture/data inputs and preserves layer order without
  retaining the prior per-surface draw helpers.
- `scripts/plaza/plaza_interior_room_renderer.gd`
  Owns backdrop cover-cropping and the full procedural room fallback including
  bands, floor, building-specific neon text, wall props, floor clutter, and the
  no-backdrop table/clutter layer. `plaza_interior_view.gd` supplies live inputs
  through one draw call and retains no parallel room draw helpers or sign map.
- `scripts/plaza/plaza_interior_object_renderer.gd`,
  `plaza_coin_trade_aura_renderer.gd`, and
  `plaza_shop_click_fx_renderer.gd`
  Own standard/featured/strewn object drawing, texture and procedural fallbacks,
  coin aura/burst material drawing with caller-material restoration, and click
  ring/sparkle/sprite-sheet frames. The view retains live interaction clocks,
  texture resolution, and action/trade orchestration only.
- `scripts/plaza/plaza_interior_input_policy.gd`
  Owns semantic key/mouse classification and priority across trade confirmation,
  trade UI, object panels, shortcuts, hover, click, scroll, and drag. The live
  view supplies coordinate containment and executes the returned action.
- `scripts/plaza/plaza_coin_trade_fx_state.gd`
  Owns coin-trade pulse/burst scalar state, particle defaults/snapshots,
  visibility gating, aura layer projection, and deterministic envelope reset.
- `scripts/plaza/plaza_coin_trade_fx_runtime_host.gd`
  Owns coin-trade asset prewarm, additive/Writhe material caches, the sparkle
  `GPUParticles2D` and process material, pulse/burst Tweens, controller-driven
  particle sync, and idempotent tree-exit teardown. `plaza_interior_view.gd`
  supplies live hover/flare inputs and consumes the host's draw resources.
- `scripts/plaza/plaza_trade_ui_projection.gd`
  Owns scaled trade-modal/panel/cell/scrollbar geometry, tooltip placement and
  copy projection, drag ghost, feedback, and sale-confirm snapshots. It composes
  `plaza_trade_item_presentation.gd` for color, equipped state, prices, names,
  descriptions, rolls, and formatted gold.
- `scripts/plaza/plaza_trade_ui_presenter.gd`,
  `plaza_trade_ui_renderer.gd`, and `plaza_interior_draw_primitives.gd`
  The presenter owns live trade snapshot assembly, fixed layer order, tooltip
  coordinate conversion, and confirmation suppression of tooltip/drag layers.
  Concrete trade `CanvasItem` drawing and shared interior shadow-text,
  wrapping, and button primitives remain with the renderer and primitive owner,
  respectively. The renderer consumes the typed item-icon cache directly;
  `plaza_interior_view.gd` supplies live inputs through one presenter call.
- `scripts/plaza/plaza_shop_inventory_state.gd`,
  `plaza_shop_transactions.gd`, and `plaza_shop_trade_summary.gd`
  Own mutable shop stock, purchase/sale/reorder transaction policy, and summary
  construction respectively. The transaction owner routes passive versus
  active grants, commits wallet/AP changes, rolls provisional grants back when
  payment fails, relists successful sales, and syncs reordered player inventory.
  `plaza_scene.gd` retains the building/action gate, visit-AP input, trade audio,
  shared facility finalization, menu refresh, and copied snapshot exposure.
- `scripts/characters/blacksmith_thor_shield_state.gd`
  Owns Kohaku / Baltor's first Godot combat slice for Thor Shield:
  shield open / retract timers, swing timing, movement slowdown, shield
  durability, shield ball-collision context, shield-hit gauge reward, and
  procedural shield draw fallback. `blacksmith_player_controller.gd` wraps
  the shared paddle movement controller and routes blacksmith input through
  this state; `blacksmith_input_reader.gd`, `blacksmith_skill_state.gd`, and
  `blacksmith_skill_config.gd` provide the runtime ID and compatibility
  surface until the redesigned construction skill kit is implemented.
- `scripts/core/match_score_state.gd`
  Owns match score rules: player/boss score, deuce state, deuce target
  progression, normal win-goal checks, score-result snapshots for the
  scoreboard, and next-serve ownership after a scoring event. Scoreboard
  triggering and full-game reset side effects are orchestrated by
  `match_flow_controller.gd` through the scene-facing match-flow driver.
- `scripts/core/round_flow_state.gd`
  Owns round-flow timing state: serve delay, serve wait timer, current
  serving side, and round-start timestamp for active-item lockouts. The
  scoreboard-to-serve handoff resets the serve wait timer so the serve-flow
  controller can apply player / boss auto-serve delays from zero. It also
  exposes a narrow stage-intro pause / resume pair for the opening ball-spawn
  animation so that intro modules can block serve advancement without owning
  serve release logic.
  Ball placement, ball velocity construction, and serve/reset orchestration
  are owned by `ball_round_controller.gd` and applied through
  `battle_scene_ball_update_driver.gd`; scoring side effects flow through
  `match_flow_controller.gd`.
- `scripts/items/active_item_runtime.gd`
  Owns active-item orchestration for the first Godot runtime slice:
  controller / renderer fanout, slot-use callbacks, F2 debug inventory
  callbacks after the menu selects an item, actor draw context, boss-AI context, and
  player-control lock exposure for throwable windups and Brick installation.
  It also merges active-item ball collision context for Holy Barrier /
  Brick Wall field blockers. Field pickup storage and passive/mythic
  acquisition routing are delegated to `active_item_pickup_router.gd`.
  Smartphone automatic active-item use is delegated to
  `active_item_smartphone_auto_use.gd`, and round-end restoration for
  throwable items consumed during windup is delegated to
  `active_item_pending_throw_recovery.gd`. Per-frame active-item update
  sequencing is delegated to `active_item_runtime_update_driver.gd`.
  Slot-use callback wiring, Smartphone auto-use entry points, Pandora
  Box / Dimension Gate special-use activation, and pending throwable
  backup / restore hooks are delegated to `active_item_runtime_use_facade.gd`.
  Reset fanout and starting active-slot construction are delegated to
  `active_item_runtime_lifecycle_facade.gd`.
  F2 debug spawn-menu input / drawing and debug inventory command routing
  are delegated to `active_item_runtime_debug_facade.gd`. Scene-facing
  draw / AI / ball-collision contexts and active-item collision
  interactions are delegated to `active_item_runtime_context_facade.gd`.
  Broader item
  pools beyond those currently ported items are still future item-domain
  work.
- `scripts/items/active_item_runtime_context_facade.gd`
  Owns active-item runtime scene-facing context assembly and interaction
  routing: throwable + AI Pill actor draw context, throwable +
  Stopwatch boss-AI context, Holy Barrier / Brick Wall / Stopwatch ball
  collision context merging, paddle and speed query forwarding, Magnet
  Field pull time-freeze gating, Holy Barrier hit notification, and Brick
  Wall hit routing. `active_item_runtime.gd` keeps the public scene-facing
  APIs and forwards them here.
- `scripts/status/status_effect_state.gd`
  Owns the shared Godot status-effect runtime for player / boss `slow`,
  `stun`, `confusion`, `reverse`, and player `burn`. New gameplay sources should apply
  these through `apply_status()` so boss AI, actor draw context, player
  speed multipliers, cleanse, and reverse-input hooks receive one canonical
  state. During migration it also emits the legacy active-item / Stage 3
  / Stage 4 context keys that existing renderers and AI branches already consume.
- `scripts/status/boss_slow_tiers.gd`
  Owns the standard Godot boss slow strength constants for new slow sources:
  weak 0.70, medium 0.55, and strong 0.40 as direct movement multipliers.
  `status_effect_state.gd` still owns stacking, duration, source cleanup, and
  context export.
- `scripts/items/active_item_runtime_update_driver.gd`
  Owns active-item runtime per-frame sequencing: effect update, stopwatch
  time-freeze gating for field / throw updates, field pickup callback
  wiring, boomerang return callback binding, pending throw backup cleanup,
  slot input update, and final owner paddle-state sync. `active_item_runtime.gd`
  keeps the public `update()` API and passes its existing callbacks into
  this driver.
- `scripts/items/active_item_runtime_debug_facade.gd`
  Owns active-item runtime debug-menu orchestration: F2 menu open / close
  state forwarding, click / wheel input result application, debug item
  grant / remove / fill commands, count-badge data, and debug menu draw
  handoff. `active_item_runtime.gd` keeps the public debug APIs and passes
  its existing debug menu, inventory, catalog, slot, and effect
  dependencies through this facade.
- `scripts/items/active_item_runtime_use_facade.gd`
  Owns the active-item runtime use surface: public slot use, Smartphone
  auto-use callback wiring, Pandora Box / Dimension Gate special-use
  activation and audio, pending throwable backup / round-end restore, and
  effect-router dispatch. `active_item_runtime.gd` keeps the public use
  APIs and private callback names for existing controller callbacks.
- `scripts/items/active_item_runtime_lifecycle_facade.gd`
  Owns active-item runtime lifecycle fanout: runtime reset of slot, field,
  throw, effect, debug-menu, and pending-throw recovery state plus
  starting active-slot construction. `active_item_runtime.gd` keeps
  `_init()`, `reset()`, and `build_starting_slots()` as the stable public
  surface.
- `scripts/hud/horizontal_timer_gauge_stack.gd`
  Owns the shared right-bottom horizontal timer-bar stack order for ported
  active-item and character-skill duration gauges. Timed effects claim a
  key while drawing so older active bars stay lower and newer bars stack
  upward instead of skill and item modules hardcoding overlapping rows.
- `scripts/lingpet/lingpet_catalog.gd`
  Owns Ringpet identity metadata and hatch-pool selection: pet ids,
  Korean display names, hatch weights, unlock conditions, required hatch
  hits, baseline companion stats, active-skill / passive-skill pool metadata,
  loadout skill-id normalization, and effect text.
  As of 2026-06-04, passive-skill metadata is a shared Ringpet-wide pool
  (`COMMON_PASSIVE_SKILL_POOL`) with Lv.1-Lv.5 values. Temporary scaffold
  passives were removed; the current pool intentionally keeps only the
  approved `lingpet_resonance_boost` / 공명 증폭,
  `lingpet_afterglow_leak` / 잔광 유출, and
  `lingpet_tailwind_steps` / 순풍 발산 passives. Pet-specific legacy
  gauge-bonus passive ids normalize into Resonance Boost for save
  compatibility.
  `lingpet_egg_runtime.gd`, character-info UI, save reset code, and
  rail-card helpers should read future Ringpet identity data from this
  catalog instead of adding new hardcoded pet ids locally.
  The `*_from_entries()` hatch helpers are the focused multi-candidate
  smoke seam for future Ringpets: add the live catalog entry, then verify
  eligibility, ownership exclusion, and weighted selection before exposing
  the new pet in play.
  `validate_catalog(true)` is the release guard for live Ringpet entries:
  required stats, egg / companion / cut-in visual paths, active-skill card
  art, and effect text must be complete before a new pet can ship.
- `scripts/lingpet/lingpet_visual_texture_cache.gd`
  Owns Ringpet catalog visual texture loading and prewarm: it resolves
  `pet_id + visual_key` through `lingpet_catalog.gd`, loads the PNG through
  `ProjectResourceLoader`, caches successful textures, and falls back to the
  caller-provided texture when a path is empty or fails. Future Ringpet art
  should add catalog `visuals` paths and reuse this cache instead of adding
  more per-pet texture dictionaries to `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_current_profile.gd`
  Owns the currently selected Ringpet profile view: normalized pet id,
  display name, hatch-hit requirement, stats, selected active-skill metadata,
  selected passive-skill metadata, active / passive slot id-level arrays,
  active / passive effective-level projection, effect text, hit footprint
  helpers, and selected-pet visual prewarm / texture lookup
  through `lingpet_visual_texture_cache.gd`. `lingpet_egg_runtime.gd` should
  update this helper when the active pet id changes instead of querying
  `lingpet_catalog.gd` directly, and should not keep unused display-name /
  skill-pool / player-speed / hit-footprint / visual-texture / passive-skill /
  motion-style / gauge-bonus / required-hit / generic-stat / hit-gauge-gain /
  normalized-pet-id pass-through wrappers after the profile owns those views.
  Runtime affinity APIs should resolve public pet-id fallbacks through this
  profile helper at the call site instead of reintroducing local
  `_resolve_affinity_pet_id` / `_get_active_affinity_pet_id` wrappers.
- `scripts/lingpet/lingpet_profile_runtime_surface.gd`
  Owns guarded runtime-facing reads from `lingpet_current_profile.gd` for the
  egg runtime: hatch-hit requirement, companion catch footprint, hit-gauge gain,
  gauge / player-speed bonuses, current passive skill, passive skill list /
  id lookup, motion style, and active / passive skill pool surfaces. It also
  owns derived player-hit gauge gain, player-speed multiplier, and
  character-info stat-source rows, including additive multi-passive accumulation
  and per-step gauge flooring. It does
  not own catalog lookup, selected-pet projection, or visual texture cache invalidation; those stay in
  `lingpet_current_profile.gd`. `lingpet_egg_runtime.gd` should ask this
  surface for repeated companion stat / passive / pool payloads and derived
  player-stat projection instead of scattering current-profile method guards,
  rebuilding profile stat bundles, or assembling stat rows inline. Regression
  guard: `tests/lingpet_profile_runtime_surface_smoke.gd`.
- `scripts/lingpet/lingpet_ring_core_rules.gd`
  Owns the shared Ringpet ring-core cap scale: maximum affinity level,
  maximum run ring-core tier, and tier-to-affinity-cap conversion. Runtime
  grant, store-compatibility, and UI projection code should call this helper
  instead of retyping cap constants.
- `scripts/lingpet/lingpet_affinity_state.gd`
  Owns run-local Ringpet affinity progression state: source gain tables, per-pet
  level / point totals, battle caps, this-run chips / feed bonus / ring-core
  tier, second-unlock roll state, hatch stat-roll fields, and run-state export /
  import. It also owns raw per-pet satiety/exhaustion values, drain/recovery
  mutation, wake/telegraph state, and the value-to-speed curve; cross-owner
  league/passive runtime policy lives in `lingpet_satiety_runtime_state.gd`.
  The current second unlock gate is first active + passive effective
  level sum >= 5, followed by the deterministic 30% roll-per-level path; fixed
  Lv.22 / Lv.25 unlock-card wording should not be reintroduced.
- `scripts/lingpet/lingpet_satiety_runtime_state.gd`
  Owns the current league-exemption latch, active/bench affinity-state call
  sequence, passive drain-reduction aggregation and 60% cap, exhaustion
  enablement, KO/speed/ratio projection, and combined change signal. It borrows
  owner/collection/profile projections only for each call; EggRuntime keeps the
  public APIs and labelled hot-tick ordering.
- `scripts/lingpet/lingpet_duration_state.gd`
  Owns the run-shared Guardian Spirit uptime pool for the §9-3 Slice 1
  transition: pool roll range, per-second drain, rest-recovery ratio,
  resummon-lock threshold, epsilon-snapped value rails, and the
  `duration_pool` save keys. It intentionally retains satiety-shaped facade
  methods (pet-id / bench-slot arguments no longer select separate batteries)
  while legacy per-pet satiety save keys stay migration inputs only;
  `lingpet_affinity_state.gd` keeps the public API.
- `scripts/lingpet/lingpet_enhancement_buff_store.gd`
  Owns the per-pet Guardian enhancement hatch-roll `reward_counts` schema and
  its static helpers: reward types (active / passive / second unlocks, skill
  bonuses, capped mobility / defense / gauge stacks), empty / normalize /
  snapshot / sanitize helpers, and reward signatures. Run-global
  duration-increase enhancements are reserved for the shared duration owner
  and must never persist in this per-pet store; `lingpet_affinity_state.gd`
  and `lingpet_current_profile.gd` preload it.
- `scripts/lingpet/lingpet_affinity_store.gd`
  Owns Ringpet affinity save compatibility for the v5 meta-only contract. It
  normalizes the persisted affinity section to schema metadata, intentionally
  ignores legacy best-level / bond-point / ring-core payloads, and must not
  resurrect run-local affinity progress from save data.
- `scripts/lingpet/lingpet_affinity_income_tracker.gd`
  Owns per-battle Ringpet affinity income accounting: totals by source and pet,
  level-up counts, optional debug logging, BattlePerf counter forwarding, and
  reset-on-battle lifecycle. Grant controllers should record through this
  tracker instead of scattering per-source counters.
- `scripts/lingpet/lingpet_decoder.gd`
  Owns pure Ringpet language decoder math: decoder level clamping, 20% reveal
  increments, token-tier reveal, hidden glyph segments, decoded Korean key
  segments, and emotion-token visibility. It should stay catalog- and UI-agnostic.
- `scripts/lingpet/lingpet_language_catalog.gd`
  Owns the static Ringpet language line catalog: line ids, speaker / emotion
  metadata, glyph text, token tiers, generic emotion buckets, and random generic
  line selection. New lines should be added here with matching localization keys,
  not hardcoded in UI renderers.
- `scripts/lingpet/lingpet_language_rich_text.gd`
  Owns Ringpet language rich-text presentation helpers: decoder-run conversion,
  Lingpet/body font loading and prewarm, run colors / font selection, label
  application, and plain-text extraction. It does not choose catalog lines or
  mutate decoder progress.
- `scripts/lingpet/lingpet_skill_dispatcher.gd`
  Owns active Ringpet skill-id to runtime-kind routing, supported-kind checks,
  shared-module detection, and exclusive resource-class policy for dual active
  loadouts. New active skills should register their runtime kind in the catalog
  and keep any legacy id fallback here until old saves no longer need it.
- `scripts/lingpet/lingpet_debug_stat_override_state.gd`
  Owns F7 Ringpet debug stat override state and policy: defense-rate override
  clamp / clear, appearance-rate override clamp / clear, move-speed multiplier
  clamp / clear, patrol-only defense visibility, flight-only appearance
  visibility, profile stat lookup for patrol speed / defense / appearance, and
  ungated move-speed multiplication. `lingpet_egg_runtime.gd` keeps the public
  debug setter / getter API used by the picker and character info smokes while
  delegating the actual override state and profile-aware stat resolution.
  Private `_get_current_patrol_speed`, `_get_current_defense_rate`, and
  `_get_current_appearance_rate` runtime wrappers should not be reintroduced.
- `scripts/lingpet/lingpet_affinity_feedback_state.gd`
  Owns Ringpet affinity level-up and point-gain feedback state: level-up flash
  timers, title / heart-tint state, point-popup coalescing, expiry, snapshot
  payloads, and renderer-facing point-popup configs. Stored and draw-facing
  popup payload dictionaries are delegated to
  `lingpet_affinity_feedback_payload_factory.gd`.
- `scripts/lingpet/lingpet_affinity_feedback_payload_factory.gd`
  Owns pure Ringpet affinity feedback popup payload construction for stored
  point-gain popups and renderer-facing ratio payloads. The feedback state
  module should keep timers, coalescing, cap enforcement, labels, and snapshot
  fanout.
- `scripts/lingpet/lingpet_affinity_context_coordinator.gd`
  Owns Ringpet affinity reward-context composition and current-profile
  projection: per-pet run-local reward seeds, inactive-pet motion-style lookup,
  stored-vs-explicit loadout base levels, this-run ring-core cap clamping,
  `configure_reward_context()` writes, test seed injection, and affinity level /
  cumulative-reward sync into `lingpet_current_profile.gd`, plus level-gain
  current-profile projection and loadout / owner-sync cache invalidation.
  `lingpet_egg_runtime.gd` should call `configure()` / `sync_current_profile()`
  directly for reward-context, pet-id, loadout, and level-gain projection
  points instead of reintroducing private reward-context, current-profile
  affinity sync, or level-gain callback wrappers.
- `scripts/lingpet/lingpet_current_pet_transition.gd`
  Owns the current-pet id transition fanout: setting the current profile's pet
  id, projecting affinity state into that profile, clearing skip-unlock
  reconcile when the pet changes, resetting distance-roll / affinity-feedback
  transient / click-reaction prewarm / acquire-cutin prewarm state, invalidating
  loadout and snapshot caches, and syncing the visible affinity feedback level.
  `lingpet_egg_runtime.gd` keeps `_pet_id` storage and the current wrapper while
  migration is ongoing, but should not re-inline the transition side effects.
- `scripts/lingpet/lingpet_affinity_grant_controller.gd`
  Owns the configured Ringpet affinity grant lifecycle: point-state mutation,
  income / BattlePerf recording, current-companion point popup dispatch,
  level-gain callback ordering, next-reward label resolution, level-up feedback,
  post-feedback audio dispatch, and the latest grant/request result exposed for
  focused tests. `lingpet_egg_runtime.gd` keeps reward-context configuration
  plus the profile-sync / loadout-cache compatibility callback and should not
  reintroduce a raw latest-affinity-result dictionary.
- `scripts/lingpet/lingpet_affinity_hit_tag_resolver.gd`
  Owns Ringpet ball-hit affinity tag capture / merge policy: defense-intercept
  and ring-dash block tags, null-safe state capture, OR-style merge semantics,
  and shared defense-tag detection for guard feedback. `lingpet_egg_runtime.gd`
  should call resolver-owned capture, merge, and defense-tag detection directly
  from the labelled companion-hit phase boundaries instead of reintroducing
  single-use capture, merge, or guard-label predicate wrappers.
- `scripts/lingpet/lingpet_affinity_run_upgrade_controller.gd`
  Owns Ringpet run-scope upgrade result application and payloads for affinity
  enhancement chips and run Ring Core tier upgrades: cap reporting, live
  multiplier / cap reads, accepted flags, and refund-safe blocked reasons.
  `lingpet_egg_runtime.gd` keeps the public perk / plaza API wrappers.
- `scripts/lingpet/lingpet_affinity_battle_lifecycle.gd`
  Owns Ringpet affinity battle lifecycle policy: score-event affinity grants
  (player-scored round commit, player victory payout), match-finish pending
  bond settlement / defeat discard, last-settlement test surface, and new-battle
  income-log / battle-cap reset. `lingpet_egg_runtime.gd` keeps the public
  score-event and battle-reset APIs and delegates through the shared affinity
  point-grant chokepoint.
- `scripts/lingpet/lingpet_affinity_owner_surface.gd`
  Owns affinity runtime / owner projection: level, points, next requirement /
  reward label, this-run ring-core tier, enhancement chips, v5 zeroed bond
  compatibility fields, `lingpet_*` / `ringpet_*` pair publication, owner-id
  cache rebasing, stable-key skip decisions, reward-signature invalidation, and
  the existing focused build-count instrumentation. `lingpet_egg_runtime.gd`
  keeps the public snapshot API and compatibility counter wrappers.
- `scripts/lingpet/lingpet_hatch_stat_roll_state.gd`
  Owns one-time hatch stat-roll application for randomized Ringpet loadouts:
  pet-id normalization, already-set blocking, randomized mobility / defense
  headstarts, the patrol-only defense headstart gate, and item-egg hatch
  loadout/stat headstart coordination via unsynced loadout storage plus the
  owner-loadout sync invalidation required after those unsynced item-egg writes.
  `lingpet_egg_runtime.gd` calls this helper when a newly randomized hatch
  loadout needs its first headstart roll or an absorbed / overflow item egg
  needs hatch traits; inline hatch-roll policy wrappers or item-egg loadout-sync
  invalidation should not be reintroduced.
- `scripts/lingpet/lingpet_feed_controller.gd`
  Owns the Ringpet feed request lifecycle: missing / busy / run-cap / level-cap
  rejection, bowl placement near the player, pending pet and registry context,
  feed-bowl approach / eating delegation, completion handoff, snapshot / draw /
  position-override forwarding, and reset cleanup. `lingpet_egg_runtime.gd`
  keeps the public `feed_lingpet()` API, advances this controller directly from
  the companion update, and applies completed feeds through the shared affinity
  point-grant chokepoint; single-use feed advance or feed reset wrappers should
  not be reintroduced.
- `scripts/lingpet/lingpet_plaza_resonance_egg_summary_builder.gd`
  Owns plaza Resonance Egg offer / spawn summary payload construction:
  handled / changed flags, `can_spawn` reasons, current runtime state,
  hatch-hit progress fields, and reason priority for missing owner, active egg,
  no hatch candidates, and ok offers. `lingpet_egg_runtime.gd` keeps the actual
  spawn state transition and collection sync.
- `scripts/lingpet/lingpet_overflow_release_plan.gd`
  Owns overflow release action planning after the modal release choice:
  consuming the captured release context, distinguishing incubator item-egg
  release from main egg overflow release, checking whether a suspended
  companion can be restored from the collection, and returning sync / restore /
  clear-pending actions. `lingpet_egg_runtime.gd` executes the returned action
  and should not re-interpret `from_item_egg` or suspended-companion release
  context inline.
- `scripts/lingpet/lingpet_overflow_replace_plan.gd`
  Owns overflow replace action planning after the modal replace choice:
  validating active pending overflow state, distinguishing incubator item-egg
  replace from main egg overflow replace, committing the main collection
  `replace_slot()` call, and returning the old / pending pet ids plus item-egg
  or main-commit action. `lingpet_egg_runtime.gd` executes the returned action
  and should not re-interpret item-egg source state or call collection
  replacement inline for normal overflow replacement.
- `scripts/lingpet/lingpet_overflow_guardian_snapshot_builder.gd`
  Owns current-versus-replacement Guardian comparison snapshots: catalog stats,
  current effective-profile levels, rolled replacement levels, active/passive
  skill entries, exact empty-slot fidelity, pending-roll flags, and deep-copy
  caches. `lingpet_egg_runtime.gd` keeps the public base-snapshot facade and
  invalidates replacement projection after rolling a preview loadout; it must
  not regain direct `LingpetCatalog` access or comparison cache/profile fields.
  Regression guard:
  `tests/lingpet_overflow_guardian_snapshot_builder_owner_smoke.gd`.
- `scripts/lingpet/lingpet_rail_card_surface_builder.gd`
  Owns the narrow Guardian rail-card surface: same-frame and static-card caches,
  two-slot metadata, live skill-state and focused skill-runtime snapshot merges,
  empty-slot defaults, interaction-permit projection, and build counters. The
  static key includes permit model/availability/active state so mount toggles
  rebuild correctly. `lingpet_egg_runtime.gd` retains only public forwarding,
  full-snapshot reuse of the permit projection, and cache invalidation.
  Regression guard: `tests/lingpet_rail_card_surface_builder_owner_smoke.gd`,
  mount-saddle, shared rail-card, permit-branch, and snapshot-sync smokes.
- `scripts/lingpet/lingpet_perf_probe.gd`
  Owns Ringpet runtime BattlePerf logger lookup and sample forwarding:
  registry `battle_perf_logger` lookup, draw-context logger lookup, guarded
  `begin_sample()` / `finish_sample()` calls, and null / invalid-object
  fallbacks. `lingpet_egg_runtime.gd` keeps only the labelled phase boundaries
  so the physics / draw label set remains visible in the hot path.
- `scripts/lingpet/lingpet_egg_field_state.gd`
  Owns Ringpet floor-egg field behavior: spawn position near the player paddle,
  player-contact nudge / wobble, egg ball-hit overlap state, player-serve
  bounce-without-crack semantics, paddle-style ball reflection, hit cooldown,
  hatch-hit counting, hatch-flash timer lifecycle, and egg snapshot fields.
  `lingpet_egg_runtime.gd` keeps the state transition into companion mode and
  the hatch / cut-in trigger points, but should not reintroduce a raw
  `_hatch_flash_timer` field.
- `scripts/lingpet/lingpet_egg_field_renderer.gd`
  Owns Ringpet floor-egg rendering: intact / cracked egg texture placement,
  intact / cracked visual-key selection, glow, crack light leakage, hatch flash
  rings, profile-backed egg texture resolution for incubator item eggs, and
  deterministic shell-shard burst geometry. `lingpet_egg_runtime.gd` asks this
  renderer for the main egg visual key, delegates item-egg profile drawing to
  the renderer, and calls the renderer directly for egg / hatch-flash draws;
  egg / hatch draw math, crack-stage key choice, and single-use draw wrappers
  such as `_draw_item_egg` should stay out of the runtime.
- `scripts/lingpet/lingpet_effect_text_resolver.gd`
  Owns owner-facing Ringpet effect-text selection: unidentified-egg hit-count
  copy for floor eggs, current-profile catalog copy for companions, and empty
  text for hidden states. `lingpet_egg_runtime.gd` calls this resolver directly
  from owner sync instead of keeping single-use text-selection wrappers or
  inline Korean copy.
- `scripts/lingpet/lingpet_companion_skill_state.gd`
  Owns Ringpet active-skill shared state: cooldown countdown, wind-up timing,
  launch origin, flash timer / ratio, trigger count, and snapshot payload
  fields. Pet-specific skill modules should own their projectile / field /
  status behavior, while `lingpet_egg_runtime.gd` uses this state controller
  for the common cast lifecycle.
- `scripts/lingpet/lingpet_companion_skill_persistence.gd`
  Owns Ringpet companion active-skill persistence across pet switches: per-pet
  stored skill-state snapshots, legacy flat snapshot migration into slot 0,
  inactive-pet cooldown ticking, shared trigger-count synchronization across
  active slots, clamped skill-state slot lookup, windup reset fanout, skill
  runtime host full-vs-round transient reset routing, per-stage persistent
  deployment wipe detection, and launch trigger recording.
  `lingpet_egg_runtime.gd` calls this owner directly from the frame-advance and
  launch paths; dead advance / snapshot / slot-key wrapper names, raw stored
  dictionary aliases, single-use windup predicate wrappers, cancel / reset
  pass-through wrappers, private skill-state slot accessor wrappers, skill
  runtime transient-reset wrappers, per-stage deployment reset wrappers,
  trigger-count sync wrappers, and launch-record wrappers should not be
  reintroduced.
- `scripts/lingpet/lingpet_active_skill_slot_resolver.gd`
  Owns Ringpet companion active-skill slot resolution: second-active unlock
  gating, public/private slot-id compatibility, host module-sharing collapse of
  slot 1, runtime active-skill id list assembly, and second-slot active-skill /
  windup metadata surfaces.
  `lingpet_companion_skill_controller.gd` calls the skill-runtime surface for
  hot-loop slot count, active-id lists, active skill dictionaries, and per-slot
  windup seconds; the egg runtime may still query those surfaces for snapshots,
  owner sync, launch payloads, motion, and drawing. Private pass-through
  wrappers, inline slot-count conflict logic, and unused second-slot wrappers
  should stay out of the runtime.
- `scripts/lingpet/lingpet_companion_skill_controller.gd`
  Owns Ringpet companion active-skill arm / launch decisions: supported
  runtime id guard, full active-slot iteration, lazy ball-context reads, effect
  idle-skip gating/counters, per-slot context assembly, host update, wind-up
  completion, ready-to-arm checks,
  cross-slot arm-gate mediation through `lingpet_companion_skill_arm_gate.gd`,
  skill prewarm before cast wind-up, launch completion, cooldown / flash commit,
  launch feedback, strike-request forwarding, and final active-skill position
  ownership. `lingpet_egg_runtime.gd` keeps only the narrow update hook, current
  dependency surface, public performance-counter facades, companion-position /
  launch-origin application callbacks, and final position writeback. It should
  not keep separate arm-gate, effect-gate, or context-builder instances. Stable
  controller dependencies are configured once; the hot hook must not regress to
  per-tick dependency/result dictionaries or lambda construction.
- `scripts/lingpet/lingpet_companion_skill_arm_gate.gd`
  Owns Ringpet companion active-skill arm mediation between active slots:
  exclusive-resource intersection checks, peer windup holds, active launch-block
  holds, and companion position-override holds. Focused smokes should call this
  owner directly for arm-gate assertions; `lingpet_companion_skill_controller.gd`
  embeds it for runtime arm decisions. `lingpet_egg_runtime.gd` should not keep
  private arm-gate pass-through wrappers, a separate arm-gate instance, or
  re-list the cross-slot resource-hold logic inline.
- `scripts/lingpet/lingpet_companion_skill_visual_resolver.gd`
  Owns Ringpet companion active-skill visual ownership resolution: active
  position-override owner selection, body-skill id fallback, active visual slot
  priority for windups / cast-pose progress, and legacy host fallback queries.
  `lingpet_skill_runtime_surface.gd` is the egg runtime's public surface for
  active position-owner queries / predicates and body-skill id assembly; the
  egg runtime should not reassemble active ids for this resolver inline or
  reintroduce single-use position-override, active-owner, active-override, or
  body-skill-id pass-through wrappers.
- `scripts/lingpet/lingpet_companion_body_presence_resolver.gd`
  Owns Ringpet companion body presence decisions: hit availability, draw
  visibility, ring-dash hidden priority, override-source presence gates, and
  front-pass bind-sheet body gates, plus draw motion-speed ratio selection for
  active-skill / feed / starlight override sources, patrol real-movement
  cadence, sortie-flight hover flap floors, runtime / draw-surface source
  assembly for that cadence, draw-surface visibility source assembly, and
  click-affinity / click-reaction visibility gating, and body-hit availability
  source assembly.
  `lingpet_egg_runtime.gd` calls this resolver directly for hit availability,
  draw visibility, front-pass body gates, click-affinity / click-reaction
  visibility, and draw-motion cadence decisions;
  body-presence pass-through wrappers, private draw-motion speed-ratio helpers,
  or inline source assembly for walk-frame / draw-context cadence, visibility,
  click-affinity / click-reaction, or body-hit availability should not be
  reintroduced.
- `scripts/lingpet/lingpet_companion_runtime_resetter.gd`
  Owns full companion runtime reset fanout: sprite animator, distance-roll,
  body-hit, passive residue / dash / ghost / starlight / feed cleanup, skill
  state reset, optional defense reset, and skill runtime transient cleanup. It
  also owns egg-wait transition cleanup/prewarm fanout for automatic eggs,
  plaza resonance eggs, and first-acquisition item eggs: field-egg spawn,
  companion position reset surface, modal transition reset, none-owner sync
  reset, and current-visual prewarm. It also owns hatch reveal transition
  surfaces for regular hatches and overflow hatch commits: egg-position capture,
  egg contact-motion reset, hatch flash trigger, optional acquisition cut-in
  start/audio, and current-visual prewarm. It also owns companion activation
  fanout after debug grants, slot switches, and owned-pet adoption: optional
  hatch-complete marking, companion position reset surface, runtime reset,
  current skill-state restore, switch / acquire-cutin reset options, current
  visual prewarm, and active collection slot publication. It also owns
  clear-pending / none-return cleanup fanout: main egg reset, coexisting item-egg
  lifecycle cleanup, companion position reset surface, runtime reset, modal
  transition reset, and current-visual prewarm. It also owns save/restore field
  cleanup fanout that clears visible field remnants without wiping stored skill
  state: main egg reset, companion position reset surface, passive / dash /
  ghost / starlight / feed cleanup, overflow choice reset, and coexisting
  item-egg lifecycle cleanup.
  `lingpet_egg_runtime.gd` keeps the call-site wrapper while migration is
  ongoing, but should not re-inline the full reset list, egg-wait
  reset/prewarm list, hatch reveal flash/cutin/prewarm list, companion
  activation restore/prewarm/active-slot list, clear-pending none-return cleanup
  list, save/restore field cleanup list, or direct skill runtime transient reset
  call.
- `scripts/lingpet/lingpet_round_resetter.gd`
  Owns round-boundary Lingpet reset fanout after any pending overflow release:
  skill runtime round-scope transient reset, affinity round caps, affinity
  feedback round transients, companion defense reset, switch transition reset,
  companion skill round transients, body-hit / passive / VFX / starlight / feed
  cleanup. `lingpet_egg_runtime.gd` keeps the public `reset_round()` entry and
  pending-overflow release routing, but should not re-inline the round reset
  list.
- `scripts/lingpet/lingpet_companion_distance_roll_state.gd`
  Owns Ringpet companion distance-roll visual state: roll angle, angular
  velocity, signed path-distance conversion for horizontal / vertical travel,
  actual drawn-position movement ratio, coast deceleration, radius / velocity
  fallback config, reset behavior, and draw-angle shaping.
  `lingpet_egg_runtime.gd` advances distance-roll state directly from the
  draw-animation measurement path and asks it directly for draw angle and the
  real-movement override ratio; dead movement / config / draw-angle wrappers
  or raw runtime draw-position transients should not be reintroduced.
- `scripts/lingpet/lingpet_companion_skill_effect_update_gate.gd`
  Owns Ringpet companion active-skill effect update gating: cooldown / inactive
  ball idle-skip decisions, visible-effect and windup guards, and the focused
  runtime-update / idle-skip counters used by performance smokes.
  `lingpet_companion_skill_controller.gd` composes this gate inside its full
  active-slot tick. `lingpet_egg_runtime.gd` keeps the narrow
  `_update_companion_skill_effects` hook and public counter wrappers through the
  controller, but should not reintroduce the gate instance, skip policy, or
  counter fields inline.
- `scripts/lingpet/lingpet_companion_skill_update_context_builder.gd`
  Owns Ringpet companion active-skill update-context assembly for the shared
  controller: battle state / owner / registry / ball motion, switch-transition
  and companion visibility flags, companion geometry, active-skill effective
  level fallback, and Wild Roar-style flattened numeric context fields.
  `lingpet_companion_skill_controller.gd` owns the hot slot loop and passes
  current values into this builder instead of re-listing controller dictionary
  keys inline. The egg runtime supplies only tick-level state and dependencies.
- `scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd`
  Owns Ringpet companion active-skill launch payload assembly: companion
  identity / geometry fields, registry forwarding, effective active-skill id /
  level fallback, and the shared numeric option defaults consumed by concrete
  skill runtimes. `lingpet_egg_runtime.gd` should pass current launch context
  into this builder instead of re-listing every skill-specific payload key.
- `scripts/lingpet/lingpet_companion_motion_state.gd`
  Owns Ringpet companion shared motion state: player-height patrol lane,
  stop-and-go randomized movement, shared position/direction/seed state,
  save / restore patrol snapshot keys, free/sortie flight, plus sortie-flight
  loiter resume after temporary Ring Dash position override release,
  patrol-dir based first-frame facing resolution, and dx-based facing
  resolution for visible companion travel. It retains the established defense
  properties/methods as compatibility facades. `lingpet_egg_runtime.gd` keeps
  hatch / body-hit orchestration and delegates companion movement decisions
  here; single-use companion defense reset, ring-dash resume, patrol-dir facing,
  or dx-facing wrappers should not be reintroduced.
- `scripts/lingpet/lingpet_companion_motion_coordinator.gd`
  Owns the cross-feature companion position-priority tick: mount, active-skill
  position owner, Ring Dash, Starlight Tracking, then ordinary motion. It also
  owns the canonical live companion position/facing projection, mount-time
  defense/click-reaction retirement, Ring Dash release/resume feedback, and
  final patrol-state synchronization. Stable dependency objects and a weak
  facade reference are configured once; the owner must not retain facade-bound
  Callables, and the physics tick must not rebuild a dependency/result
  dictionary or callback. `lingpet_egg_runtime.gd::_update_companion_motion()`
  remains a narrow compatibility delegation and exposes owner-backed position
  and facing properties for existing save/test/public integration surfaces.
- `scripts/lingpet/lingpet_companion_defense_state.gd`
  Owns predictive-ground-guard mutable state, player-blockable/local-zone
  eligibility, shared-seed roll cadence, re-anchored landing prediction, eased
  chase/arrival motion, actual step-speed output, and guard-aura ramp. It
  receives the motion host only for the active tick and does not retain it or
  allocate per-tick result containers.
- `scripts/lingpet/lingpet_companion_sprite_animator.gd`
  Owns Ringpet companion sprite animation math: walk / idle frame selection,
  cast wind-up frame mapping, strike playback state, strike entry-frame mapping,
  source-rect slicing, draw-size offsets, and sheet geometry.
  `lingpet_companion_renderer.gd` uses this animator for draw rects, while
  future companion sheets should extend this animator instead of adding more
  frame math to the runtime.
- `scripts/lingpet/lingpet_companion_strike_anticipator.gd`
  Owns Ringpet companion visual strike anticipation: ball-active / descending
  checks, body-hit suppression mediation for active skill body owners, contact
  time prediction, current catalog hit-footprint inputs, horizontal
  future-position tolerance, latch reset, and animator strike start. The real
  bounce / gauge reward remains in `lingpet_companion_body_hit_state.gd`; this
  helper is visual timing only, and the runtime should not reintroduce a
  private strike-arm wrapper.
- `scripts/lingpet/lingpet_companion_draw_context_builder.gd`
  Owns Ringpet companion renderer config assembly: hit / gauge / skill flash
  ratios, switch-transition ratio and trigger counts, cast-vs-strike priority,
  patrol / wind-up timing fields, and current-profile walk / strike / cast
  texture resolution. `lingpet_companion_renderer.gd` should receive a finished
  config dictionary instead of making runtime-state decisions itself.
- `scripts/lingpet/lingpet_companion_renderer.gd`
  Owns Ringpet companion draw presentation: idle bob / glow, walk / strike /
  cast sprite blitting, hit flash rings, skill flash rings, and direct-hit
  gauge burst rays, affinity feedback burst / popup drawing, and soft-glow
  texture prewarm. `lingpet_egg_runtime.gd` supplies current textures and
  transient state, but companion draw math should stay in this renderer and
  single-use affinity-feedback draw wrappers should not be reintroduced.
- `scripts/lingpet/lingpet_current_visual_prewarm_coordinator.gd`
  Owns selected Ringpet visual prewarm fanout at runtime transition points:
  current-profile catalog visual prewarm, companion renderer soft-glow prewarm,
  and companion click-reaction sheet queueing when the selected pet is active.
  `lingpet_egg_runtime.gd` should call this coordinator directly from adopt /
  hatch / restore / clear transition points instead of keeping a private
  `_prewarm_current_visuals` wrapper or scattering the click-reaction queue
  policy inline.
- `scripts/lingpet/lingpet_companion_body_hit_state.gd`
  Owns Ringpet companion body-contact behavior: wide catch-box overlap state,
  contact cooldown, last contact position, player-paddle-style ball reflection,
  boss ball-control release hooks, paddle-hit audio, body-hit gauge gain, and
  hit / gauge flash snapshot fields. Future Ringpets with different body-hit
  rules should extend this helper instead of adding more collision math to
  `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_companion_player_block_resolver.gd`
  Owns the Ringpet companion hit player-priority reach check: null / missing
  player guards, player paddle width, ball-radius expansion, and inclusive
  horizontal reach bounds. `lingpet_egg_runtime.gd` calls this resolver directly
  when suppressing companion body hits that the player can take; single-use
  player-block predicate wrappers should not be reintroduced.
- `scripts/lingpet/lingpet_companion_player_runtime_resolver.gd`
  Owns cached-only cross-character runtime arbitration consumed by companion
  motion and body hits: Smasher Overdrive active/armed right-click ownership,
  Viper command-armability, active Smasher dash snapshot projection, and Viper
  player-guard availability. It never calls `get_instance()` from the physics
  tick. The egg-runtime compatibility wrappers and motion coordinator delegate
  here instead of retaining facade-bound Callables. Regression guard:
  `tests/lingpet_companion_player_runtime_resolver_smoke.gd`,
  `tests/lingpet_companion_motion_coordinator_refactor_smoke.gd`, Wall Leap
  mount arbitration, Ring Dash, body-hit, and egg-runtime smokes.
- `scripts/lingpet/lingpet_afterglow_leak_state.gd`
  Owns the shared Ringpet passive `lingpet_afterglow_leak` / 잔광 유출:
  companion-hit residue spawning, residue lifetime / seep-away cleanup,
  player-paddle proximity absorption, fast gauge tick grants, floor-splat and
  CPU droplet-particle simulation, gauge feedback calls, and debug / UI snapshot
  fields. The visual envelope is decorative only and never gates the absorb
  gameplay; stateless composition receives explicit scalars plus borrowed
  residue/particle arrays through `lingpet_afterglow_leak_renderer.gd`.
  `lingpet_egg_runtime.gd` should only call spawn / advance / draw / reset and
  should not inline residue math. Residue, floor-splat, and particle payload
  dictionaries are delegated to `lingpet_afterglow_leak_payload_factory.gd`.
- `scripts/lingpet/lingpet_afterglow_leak_renderer.gd`
  Owns Afterglow Leak texture prewarm, emission/absorb flashes, luminous pool,
  splat/tongue/caustic layers, all four particle presentations, and pure pool
  projection. It owns no residue/absorption/gauge lifecycle, floor deposits,
  payload generation/advancement, RNG, feedback, snapshot state, wall clock, or
  retained live collection.
- `scripts/lingpet/lingpet_afterglow_leak_payload_factory.gd`
  Owns pure Afterglow Leak payload construction for residue state dictionaries,
  landed floor splats, and droplet / absorb-wisp particle entries. The state
  module keeps absorption math, per-frame simulation, and gauge feedback; the
  focused renderer owns texture prewarm and drawing.
- `scripts/effects/afterglow_fluid_texture_cache.gd`
  Static lazy luminance-texture cache for the 잔광 유출 fluid VFX (glow / body /
  caustic / rim / droplet / vertical-rivulet streak), white-baked with alpha
  luminance and tinted to the green-gold "공명 유체" palette at draw time. Same
  immediate-draw, no-fragment-shader pattern as `hydro_puddle_texture_cache.gd`
  (the shared battle shell draws in one painter-order `_draw()`, so flowing
  light is faked via caustic-scroll + layered blits, not a GPU shader pass).
- `scripts/lingpet/lingpet_companion_switch_state.gd`
  Owns Ringpet companion switch-transition state: transition timer, source /
  target pet ids, trigger count, ratio calculation, reset, and snapshot fields
  consumed by the companion renderer. Battle HUD visibility and input routing
  should not reintroduce these transient VFX fields into `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_save_restore_planner.gd`
  Owns Ringpet save-restore target decisions: snapshot-owned ids, battle slot
  ids, active slot, active pet id, legacy egg reset semantics, and the final
  companion / fresh-egg / none restore plan. `lingpet_egg_runtime.gd` should
  apply the returned plan to runtime state, not re-interpret save payloads
  inline.
- `scripts/lingpet/lingpet_save_restore_applier.gd`
  Owns Ringpet save-restore application choreography after the planner chooses
  a target: reset-before-restore, empty-snapshot owner sync, loadout handoff,
  companion restore hooks (loadout, hatched egg, companion position / patrol),
  companion-position Vector2 coercion through `lingpet_runtime_vector_resolver`,
  legacy save-state alias normalization, fresh-egg spawn, none-state clear,
  final owner sync shape, and restore result payload. `lingpet_egg_runtime.gd`
  keeps the public save / restore APIs and explicitly passes the remaining
  runtime-owned field-clear / patrol-restore callbacks; the applier should not
  dynamically probe those private hook names.
- `scripts/lingpet/lingpet_loadout_state.gd`
  Owns Ringpet acquisition loadouts: per-pet selected active-skill id,
  selected active/passive Lv.1-Lv.5 values, selected passive-skill id,
  passive slot unlock count, `lingpet_loadouts` / `ringpet_loadouts` owner-key
  compatibility, legacy missing-loadout defaults, first-acquisition random
  shared-passive selection, current runtime apply-cache key, owner-sync
  loadout-snapshot key, snapshot-sync cache invalidation fanout, and
  debug-forced unlock-reconcile skip latch, explicit set-loadout + cache
  invalidation fanout for debug / fixture loadouts, and forget-loadout + cache
  invalidation fanout for released / replaced pets. Runtime release / replace
  paths should call this owner directly when forgetting a removed pet's loadout
  so runtime + snapshot caches are invalidated only when it reports an actual
  deletion.
  `lingpet_egg_runtime.gd` should call this owner for loadout cache
  invalidation instead of keeping a private `_invalidate_current_loadout_cache`
  wrapper. Future Ringpet skill rerolls, choice tickets, growth-driven loadout
  changes, or loadout sync throttles should update this helper instead of
  adding more selected-skill dictionaries or cache-key latches to
  `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_loadout_cache_key_builder.gd`
  Owns Ringpet selected-loadout cache key construction: active / passive skill
  id-level slot signatures, active / passive slot-count fields, empty-id
  filtering, malformed level fallback handling, and affinity reward-signature
  inclusion. Current-loadout application calls this builder through
  `lingpet_current_loadout_applier.gd`; `lingpet_egg_runtime.gd` should not own
  selected-loadout cache-key construction directly.
- `scripts/lingpet/lingpet_current_loadout_applier.gd`
  Owns current-pet loadout application fanout: empty-pet profile/loadout reset,
  skip-unlock reconcile clearing for empty state, unlock-to-loadout
  reconciliation, ensure-vs-read loadout selection, first hatch stat-roll
  delegation, affinity reward-context refresh, selected-loadout cache-key
  comparison / mark, current-profile loadout and affinity projection, and
  active-skill runtime prewarm after a loadout becomes active.
  `lingpet_egg_runtime.gd` keeps the call sites and current pet id, but should
  not re-inline current-loadout apply/cache/prewarm fanout.
- `scripts/lingpet/lingpet_unlock_loadout_reconciler.gd`
  Owns affinity-reward-to-loadout reconciliation: active / passive unlock
  candidate construction, deterministic secondary candidate ordering,
  automatic run-state choice resolution, duplicate and shared-runtime-module
  rejection, existing skill-level preservation, and final two-slot loadout
  writes, including runtime cache invalidation after an actual loadout change.
  Focused unlock smokes should call this owner directly for candidate caps,
  loadout-match checks, work-gate checks, and runtime reconcile idempotence;
  `lingpet_egg_runtime.gd` should call this owner directly instead of keeping a
  private reconcile wrapper. Private test pass-through wrappers, single-use
  work-gate wrappers, and v4 persisted unlock-choice store wrappers should not
  be reintroduced.
- `scripts/lingpet/lingpet_collection_state.gd`
  Owns Ringpet owned-collection state and owner-key compatibility: save
  `owned_pet_ids`, `lingpet_owned_pet_ids` / `owned_lingpet_ids` /
  `owned_ringpet_ids`, collection dictionaries, first-owned companion adoption,
  active battle-slot placement for owned pets, catalog-backed hatch candidate
  selection, Junior auto-present league checks, and egg-spawn availability
  checks. Future Ringpet acquisition routes should update this helper instead
  of adding more collection key scans to `lingpet_egg_runtime.gd`, and unused
  first-owned, owned-pet marking, hatch-selection, hatch-availability,
  auto-present, or active-slot pass-through wrappers should not be reintroduced
  in the runtime.
- `scripts/lingpet/lingpet_none_owner_sync_state.gd`
  Owns STATE_NONE update policy and the owner-sync one-shot gate used by Pro /
  Mythic fresh battles and Junior no-candidate idle frames: auto-present league
  branching, owned-pet adoption, automatic egg spawning, and single none
  snapshot publishing. `lingpet_egg_runtime.gd` should delegate the STATE_NONE
  update branch to this owner and reset it when leaving or fully clearing the
  field, instead of keeping a raw `_has_synced_none` latch or private
  `_update_none_state` wrapper.
- `scripts/lingpet/lingpet_overflow_choice_state.gd`
  Owns Ringpet overflow replacement-modal state: pending vs active flags,
  pending pet id, suspended companion id for main-egg overflow restore, and the
  coexist-incubator item-egg source flag. It also owns overflow-modal snapshot
  payload assembly (`pending_display_name`, slot entries, active slot marker)
  with display-name lookups supplied by `lingpet_collection_state.gd`, plus the
  capture-before-reset commit / release context used by replace and discard
  flows, and acquire-cutin-close routing that marks item-egg absorbs ready
  before activating a pending main overflow modal.
  `lingpet_egg_runtime.gd` keeps the public modal snapshot / commit APIs and
  hatch orchestration, but gates egg offers, deploys, plaza spawns, and round
  reset through this state owner, and calls it directly for item-egg overflow
  setup, instead of keeping raw
  `_pending_overflow_choice` / `_overflow_choice_active` fields,
  inline display-payload assembly, direct state-field reads, or a
  `_clear_overflow_choice_state` / item-egg setup wrapper / private
  acquire-cutin completion router.
- `scripts/lingpet/lingpet_item_egg_lifecycle_state.gd`
  Owns the coexisting item-egg lifecycle state used when `lingpet_egg` is
  deployed while a companion is already active: active egg pet id, incubation
  blocking checks, item-egg tick-to-reveal transition, reveal-to-absorb waiting /
  ready flags, absorb pet id, absorb origin capture, the dedicated incubator-egg
  current profile used for required-hit / egg-visual / cut-in reads, and full
  coexisting item-egg cleanup across lifecycle state, field egg state, absorb
  VFX, and reveal display identity.
  `lingpet_egg_runtime.gd` keeps the acquire cut-in start, absorb VFX,
  hatch trait / affinity follow-up, and owner sync choreography, but should not
  reintroduce raw `_item_egg_active`, `_item_egg_pet_id`,
  `_item_egg_awaiting_absorb`, `_item_egg_absorb_ready`,
  `_item_egg_absorb_pet_id`, `_item_egg_absorb_origin`, `_item_egg_profile`,
  private `_advance_item_egg` / `_on_item_egg_hatched` wrappers, or a private
  `_clear_item_egg_state` wrapper.
- `scripts/lingpet/lingpet_item_egg_absorb_router.gd`
  Owns the coexisting item-egg absorb registration route after the reveal
  cut-in closes: owner collection sync, free-slot registration that preserves
  the active companion slot, and roster-full handoff into item-egg overflow
  replacement choice. It also owns the item-egg overflow replace slot commit
  routing: collection slot replacement, old/new pet result payload, active
  companion replacement detection, and active-companion slot preservation when
  the chosen replaced slot is not the current companion.
  `lingpet_egg_runtime.gd` keeps absorb VFX triggering, hatch trait rolls,
  affinity grants, and owner sync choreography, but should not reintroduce
  item-egg absorb-time collection full checks, free-slot registration calls, or
  item-egg overflow setup / replace-slot routing inline.
- `scripts/lingpet/lingpet_tutorial_bootstrap.gd`
  Owns the Junior Mika first-Ringpet tutorial bootstrap: first-egg eligibility
  checks, the shipped standard run ring-core tier, and run-state-only tier
  upgrade before the automatic egg spawns. `lingpet_egg_runtime.gd` should call
  this helper from the automatic egg-spawn transition instead of keeping
  tutorial eligibility / grant policy helpers locally.
- `scripts/lingpet/lingpet_acquire_cutin_state.gd`
  Owns Ringpet acquisition cut-in timing state: reveal progress, hold-until-
  dismiss semantics, click-triggered exit-action progress, hard reset, and
  auto-close when the exit action completes, plus reveal-only display pet id
  overrides for incubator item-egg cut-ins. `lingpet_egg_runtime.gd` keeps the
  public modal / input / overlay API and delegates timing / display identity
  here so future Ringpet reveal variants do not add more cut-in clocks or raw
  display-id fields to the runtime. Call sites should resolve display identity
  through `get_display_pet_id()` / `has_display_override()` instead of
  reintroducing `_acquire_cutin_pet_id` or private `_get_cutin_pet_id` /
  `_get_cutin_profile` wrappers. Hatch / debug / item-egg reveal start sites
  should call `_acquire_cutin_state.start()` (passing an override pet id only
  for item-egg reveal) and the audio dispatcher at the event site instead of
  reintroducing a single-use `_start_acquire_cutin` wrapper.
- `scripts/lingpet/lingpet_acquire_cutin_overlay_host_resolver.gd`
  Owns Ringpet acquisition cut-in overlay host registry lookup: the shared
  `lingpet_acquire_cutin_overlay_host` key, cached-instance priority, normal
  instance fallback, object/null guard, and optional animated cut-in readiness
  query fallback. `lingpet_egg_runtime.gd` calls this resolver directly from
  the reveal gate and egg-phase asset prewarm path instead of keeping narrow
  pass-through wrappers.
- `scripts/lingpet/lingpet_acquire_cutin_asset_prewarm_state.gd`
  Owns Ringpet acquisition cut-in asset prewarm completion state: completed
  pet id bookkeeping, empty-pet no-op handling, registry overlay-host
  resolution, host capability guard, host prewarm ticking, and short-circuiting
  already-cached pets. `lingpet_egg_runtime.gd` should call this helper
  directly from main-egg, cut-in advance, and incubator-egg prewarm points
  instead of reintroducing private `_prewarm_acquire_cutin_assets_step` or
  `_prewarm_item_egg_cutin_assets_step` wrappers.
- `scripts/lingpet/lingpet_companion_click_reaction_state.gd`
  Owns in-battle companion click-reaction behavior: tap-zone math, focused
  click-reaction sheet prewarm keys, cached-first ready-texture lookup,
  98-frame popup timing / alpha, and sheet frame drawing.
  `lingpet_egg_runtime.gd` keeps only the playfield click API and should ask
  this owner for texture readiness instead of keeping private readiness wrappers
  or re-listing the runtime visual key lookup.
- `scripts/lingpet/lingpet_companion_click_reaction_draw_size_resolver.gd`
  Owns in-battle companion click-reaction draw-size resolution: per-pet
  `click_reaction_draw_size` override priority, `companion_walk_draw_size`
  fallback, and sprite-default fallback for missing / non-positive values.
  `lingpet_egg_runtime.gd` calls this resolver directly from the body draw path
  when the click-reaction sheet is visible.
- `scripts/lingpet/lingpet_companion_click_reaction_visual_prewarm_state.gd`
  Owns in-battle companion click-reaction visual prewarm bookkeeping: current
  queued pet id, completed pet id, companion-state gating, short-circuiting for
  already-cached pets, and threaded prewarm step iteration across the focused
  click-reaction visual keys. `lingpet_egg_runtime.gd` schedules and ticks this
  state directly from visual prewarm / companion-update paths; single-use queue
  or step wrappers should not be reintroduced.
- `scripts/lingpet/lingpet_ghost_blink_vfx.gd`
  Owns Rabi free-flight companion appear / vanish blink VFX: deterministic
  soft-glow prewarm, pop / implode timers, bounded wisp particles, immediate
  draw ordering, free-flight visibility edge tracking, and reset cleanup.
  `lingpet_egg_runtime.gd` should only sync visibility, advance, draw, and
  reset this helper; raw `_prev_ghost_visible` state or single-use trigger-edge
  wrappers should not be reintroduced.
- `scripts/lingpet/lingpet_runtime_vector_resolver.gd`
  Owns small Ringpet runtime Vector2 resolution helpers: Variant-to-Vector2
  fallback coercion, owner-backed player paddle position / size reads, and
  Starlight Tracking pickup delivery-center / item-egg absorb-target
  calculation. `lingpet_egg_runtime.gd` and `lingpet_save_restore_applier.gd`
  call the resolver directly anywhere they need those fallback semantics for
  position overrides, save-restore companion position, pickup delivery, or
  player-centered absorb VFX targets.
- `scripts/lingpet/lingpet_audio_dispatcher.gd`
  Owns Ringpet runtime GameAudio dispatch for runtime-owned SFX hooks:
  acquisition cut-in, ring dash, companion click-reaction voice, and
  acquisition-click backing. It centralizes guarded `game_audio` registry
  lookup and method invocation, while `lingpet_egg_runtime.gd` keeps the
  event-timing branches that decide when each cue should fire and calls the
  dispatcher directly; single-use audio play wrappers should not be
  reintroduced.
- `scripts/lingpet/lingpet_runtime_snapshot_builder.gd`
  Owns Ringpet runtime data projection: live snapshot assembly, save snapshot
  assembly, selected loadout / passive-skill projection, and owner
  compatibility key sync plus sync-cache invalidation for both `lingpet_*` and
  `ringpet_*` consumers. `lingpet_egg_runtime.gd` supplies current state /
  catalog stats / helper modules, but UI, HUD, and save-facing payload shapes
  should stay centralized here.
- `scripts/lingpet/lingpet_mount_state.gd`
  Owns the Onimaru mount lifecycle: debounced bare-right-click toggle,
  S/down chord exclusion, proximity acceptance, forced dismount, hop/drop and
  gait/breath clocks, rider lift, and the mounted companion X override. The
  egg runtime retains companion update ordering, active-skill position
  precedence, body-defense suppression, draw-context export, and round/reset
  calls into this owner.
- `scripts/lingpet/lingpet_acquisition_lifecycle_coordinator.gd`
  Owns the shell-break-to-acquisition sequence across focused state owners:
  pending regular/overflow branch, break advancement, hatch flash and burst
  hold, deferred commit, per-pet cut-in prewarm/readiness, reveal/dismiss
  timing, acquisition/click audio, and post-close overflow resolution. It keeps
  only a `WeakRef` back to `lingpet_egg_runtime.gd` for the remaining hatch
  commit, snapshot invalidation, and immediate owner-sync side effects. The egg
  runtime retains public compatibility methods and current-pet context; it
  should not regain raw pending-kind/burst timers or inline lifecycle ordering.
  Regression guard:
  `tests/lingpet_acquisition_lifecycle_coordinator_owner_smoke.gd`, egg-runtime,
  main-overflow, item-egg, prewarm/resolver, ungated-idle, and performance
  smokes.
- `scripts/lingpet/lingpet_egg_runtime.gd`
  Owns the first Ringpet runtime slice: catalog-backed Junior League +
  Mika eligibility, hidden egg identity selection, owner-state sync for the
  character information panel via `lingpet_runtime_snapshot_builder.gd`,
  selected-loadout application via `lingpet_loadout_state.gd`,
  selected passive-skill player-hit gauge gain,
  owned-collection sync plus save-snapshot export / restore, hatch-entry facade,
  player-height independent companion draw,
  post-hatch Maribo body ball-contact soft bounce with internal cooldown,
  Ringpet common body-contact gauge gain, generic companion skill cooldown /
  wind-up / launch handoff into `lingpet_skill_runtime_host.gd`, and the shared
  boss-skill rail Ringpet card surface. It exposes the acquisition cut-in API
  for modal / input / overlay controllers, while cross-owner reveal/dismiss and
  shell-break ordering live in `lingpet_acquisition_lifecycle_coordinator.gd`
  and raw timing state lives in `lingpet_acquire_cutin_state.gd`; companion click-reaction
  tap-zone / draw / timing state lives in `lingpet_companion_click_reaction_state.gd`.
  Satiety storage remains in `lingpet_affinity_state.gd`, while league/passive
  progression and exhaustion policy live in `lingpet_satiety_runtime_state.gd`;
  the runtime retains the public facade and combat/snapshot call sites.
  The old v4 persisted-affinity store headstart path is removed from this
  runtime; v5 affinity is run-state only. `set_affinity_store_for_tests()`
  remains as a public no-op compatibility hook so tests can prove injected
  legacy store residue cannot affect battle affinity, ring-core cap, or
  owner-surface sync.
- `scripts/lingpet/lingpet_skill_runtime_host.gd`
  Owns Ringpet active-skill module dispatch: skill-kind lookup, skill-specific
  prewarm / batch prewarm, update / draw / visible-effect checks, launch
  blocking, launch calls, public launch-feedback and companion-surface facades,
  cross-slot position-owner payload priority, and skill snapshot merge.
  Immediate cue selection delegates to `lingpet_skill_launch_feedback_router.gd`;
  launch-origin/position/body/strike/cast-pose policy delegates to
  `lingpet_skill_companion_surface_router.gd`. Future Ringpet active skills
  should add a focused skill
  module plus a dispatcher / host branch here instead of adding concrete
  projectile or field behavior to `lingpet_egg_runtime.gd`; callers should
  pass surface-built active skill id lists to `prewarm_many()` instead of
  reintroducing a private `_prewarm_current_skill_runtime` wrapper or an inline
  prewarm loop.
- `scripts/lingpet/lingpet_skill_launch_feedback_router.gd`
  Owns immediate Ringpet active-skill launch cue routing: skill-kind-to-cue
  mapping, dedicated-cue fallback order, Dragon Breath/Wing boolean volume
  arguments, deliberately silent host branches, and cached-before-instance
  `game_audio` lookup. It does not own skill launch success, lifecycle,
  delayed fire/hit/outro cues, concrete skill state, drawing, or snapshots;
  `lingpet_skill_runtime_host.gd` retains the public trigger facade.
- `scripts/lingpet/lingpet_skill_companion_surface_router.gd`
  Owns allocation-free companion-facing active-skill policy: launch-origin
  offsets, position-override eligibility/forwarding for existing modules,
  body-hit/body-draw suppression, Headbutt strike-request consumption,
  cast-pose progress, and supported-runtime windup visibility. It does not own
  module construction/lifetime, slot iteration, cross-slot owner payloads,
  concrete skill state, drawing, or launch success; the runtime host retains
  those public integration boundaries.
- `scripts/lingpet/lingpet_skill_runtime_surface.gd`
  Owns Ringpet skill-runtime host public surface guards for the egg runtime:
  companion-state-gated boss-AI context, companion-state-gated ball-collision
  context, bind-sheet front-pass state checks, companion body hit/draw
  suppression checks, companion strike-request consumption, Variant-to-
  Dictionary coercion, active slot-count assembly, active skill id list
  assembly, per-slot active-skill update / snapshot / owner-sync surface
  assembly including profile active-skill level fallbacks, active
  position-owner query / predicate assembly, companion draw
  visual-skill surface assembly, companion body-skill id assembly, and Bone
  Barrier hit notification forwarding.
  `lingpet_egg_runtime.gd` keeps only public API names consumed by battle
  context builders and ball event processors, and should call this surface
  directly for private draw-suppression, hit-suppression, strike-request, and
  active-skill slot-count / id / surface / level-fallback / active-position
  decisions;
  single-use body-suppression predicate wrappers or duplicated active-skill
  slot-count / id / update / snapshot / owner-sync / draw-surface /
  active-position / body-skill id prep should not be reintroduced.
- `scripts/lingpet/lingpet_ghost_summon_skill.gd`
  Owns Rabi's `rabi_ghost_summon` / Ghost Summon active runtime: two
  Banshee-style ghost paddles, ball-eat capture, hidden-ball hold, teleport
  targeting/release, catch / release counters, update-side particle/gameplay
  RNG, start / outro cue routing, render fanout, and `ghost_summon_*` snapshot
  keys.
  `lingpet_skill_runtime_host.gd` dispatches this by the `ghost_summon`
  runtime kind while keeping the shared Ringpet lifecycle in
  `lingpet_egg_runtime.gd`. Ghost state, dying-ghost, normal particle, and
  teleport particle payload dictionaries are delegated to
  `lingpet_ghost_summon_payload_factory.gd`.
- `scripts/lingpet/lingpet_ghost_summon_payload_factory.gd`
  Owns pure Rabi / Nekuring Ghost Summon payload construction for spawned
  ghost state, dying ghost fade-outs, launch / death particles, and teleport
  particles. `lingpet_ghost_summon_skill.gd` should keep capture timing,
  teleport targeting, ball ownership, audio cues, and render delegation.
- `scripts/lingpet/lingpet_ghost_summon_renderer.gd`
  Owns stateless Ghost Summon normal/teleport particles, launch flash, all ghost
  presentation states, procedural glyph/shadow recipes, and deterministic dying-
  spark projection. It borrows live typed arrays and owns no gameplay state, RNG
  stream, wall clock, audio, ball ownership, collision, or retained payload.
- `scripts/lingpet/lingpet_soul_clone_skill.gd`
  Owns Rabi's `rabi_soul_clone` / 영혼분신 active runtime: level-scaled clone
  count/duration, lower-player-side free-flight target RNG and movement, mini-
  paddle ball reflection without extra gauge gain, spirit-particle spawning and
  simulation, lifecycle, and `soul_clone_*` snapshot keys. It delegates render
  resources/composition to `lingpet_soul_clone_renderer.gd` with one sampled
  visual-clock value and borrowed clone/particle arrays.
- `scripts/lingpet/lingpet_soul_clone_renderer.gd`
  Owns Rabi Soul Clone's imported companion-texture cache and stateless spirit-
  particle, aura, afterimage, animator-region, horizontal-flip, and fallback
  drawing. It owns no RNG, movement, collision/reflection, particle simulation,
  lifecycle, audio, wall-clock read, snapshot state, or retained live arrays.
- `scripts/lingpet/lingpet_soul_clone_payload_factory.gd`
  Owns pure Rabi Soul Clone particle payload construction for ambient wisps,
  vanish bursts, and ball-hit bursts. `lingpet_soul_clone_skill.gd` should keep
  clone movement, ball reflection, particle simulation, and lifecycle; texture
  loading and drawing belong to `lingpet_soul_clone_renderer.gd`.
- `scripts/lingpet/lingpet_hydro_sphere_skill.gd`
  Owns Maribo Hydro Sphere's skill-specific runtime: projectile travel,
  opponent-wall impact, horizontal elliptical puddle, slow status refresh,
  splash / ambient droplet particle lifecycle, and Hydro Sphere snapshot keys.
  `lingpet_skill_runtime_host.gd` calls this module instead of letting
  `lingpet_egg_runtime.gd` grow Maribo-specific projectile / puddle code inline.
  Droplet particle payloads and slow-status data payloads are delegated to
  `lingpet_hydro_sphere_payload_factory.gd`; stateless presentation receives
  explicit scalars plus borrowed trail/particle arrays through
  `lingpet_hydro_sphere_renderer.gd`.
- `scripts/lingpet/lingpet_hydro_sphere_renderer.gd`
  Owns Hydro Sphere's procedural water-texture prewarm, puddle/caustic/foam,
  droplet, wall-splash, projectile/trail CanvasItem recipes, and pure validated
  puddle projection. It owns no projectile/puddle/particle lifecycle, wall or
  boss collision policy, slow status, payload generation, snapshot state, wall
  clock, RNG, or retained live collection.
- `scripts/lingpet/lingpet_hydro_sphere_payload_factory.gd`
  Owns pure Maribo Hydro Sphere payload construction for splash droplets,
  ambient puddle droplets, base particle dictionaries, and the boss slow
  status data payload.
- `scripts/lingpet/lingpet_moon_orbit_payload_factory.gd`
  Owns pure Draft Bat / Orbi Moon Orbit payload construction for burst
  particles, ambient orbit-field particles, base particle dictionaries, and
  the boss slow status data payload. `lingpet_moon_orbit_skill.gd` should
  keep projectile travel, field timing, overlap checks, status publication,
  and particle simulation; drawing belongs to `lingpet_moon_orbit_renderer.gd`.
- `scripts/lingpet/lingpet_bubble_trap_skill.gd`
  Owns Maribo Bubble Trap's skill-specific runtime: level-scaled forward bubble
  projectile travel (speed by level), independent 50% extra-shot rolls (up to
  1/2/3 extra bubbles by level), boss-paddle collision capture with a
  level-scaled 2.0-4.0-second bubble movement lock, a lead-only ball-immune
  rainbow giant bubble (Lv.3+ 20%, 2.0x / 2.5x size),
  shared boss-stun refresh, ball-contact / expiry popping, burst-particle
  simulation, reused hydro-water feedback, explicit visual clock, and Bubble
  Trap snapshot keys. `lingpet_skill_runtime_host.gd` dispatches this module by the
  `bubble_trap` runtime kind so `lingpet_egg_runtime.gd` stays limited to the
  common companion wind-up / launch lifecycle. Projectile dictionaries, burst
  particle payloads, and stun-status data are delegated to
  `lingpet_bubble_trap_payload_factory.gd`.
- `scripts/lingpet/lingpet_bubble_trap_renderer.gd`
  Owns stateless Maribo Bubble Trap capture-bubble, projectile/trail, rainbow
  shimmer, burst, deterministic inner-bubble, and particle CanvasItem recipes.
  It borrows the live projectile and particle arrays and consumes the skill's
  explicit visual clock; it must not own gameplay collision/status/audio,
  payload spawning, an RNG stream, wall-clock reads, or retained render state.
- `scripts/lingpet/lingpet_bubble_trap_payload_factory.gd`
  Owns pure Maribo Bubble Trap payload construction for launched bubble
  projectiles, burst particles, base particle dictionaries, and shared boss
  stun status data.
- `scripts/lingpet/lingpet_bomb_surprise_payload_factory.gd`
  Owns pure Volty Bomb Surprise payload construction for boss / player stun
  status data, clamped explosion particle dictionaries, and strong-vs-weak
  explosion particle scatter. `lingpet_bomb_surprise_skill.gd` should keep
  attachment state, fuse timing, detonation targeting, audio, screen shake,
  knockback application, and rendering.
- `scripts/lingpet/lingpet_dragon_wing_payload_factory.gd`
  Owns pure Farukiras / Red Dragon Dragon Wing payload construction for the
  flying-dragon state dictionary, warm wind-particle streaks, ball-swirl trail
  entries, and dragon trail entries. `lingpet_dragon_wing_skill.gd` should
  keep the vortex steering, bounded ball-speed policy, collision, audio,
  payload lifecycle, and render delegation.
- `scripts/lingpet/lingpet_doll_curse_payload_factory.gd`
  Owns pure Koyora Doll Curse payload construction for initial marionette doll
  dictionaries, the boss-confusion status data payload, and wooden-doll
  destroy particles. `lingpet_doll_curse_skill.gd` should keep phase timing,
  beam sweep / homing logic, boss-contact checks, ball bounce behavior,
  source-scoped status clear, audio, and render delegation.
- `scripts/lingpet/lingpet_puppet_grab_skill.gd`
  Owns Koyora Puppet Control's runtime: snapshot lock-on, MISS / retry
  sequencing, boss-position ownership, pull / kiss / return timing, companion
  cast-pose override, ball-cut geometry, deterministic cut-fray payloads,
  audio edges, render fanout, and `puppet_grab_*` snapshot keys. Kiss heart and
  sparkle payload dictionaries are delegated to the payload factory; all
  CanvasItem recipes are delegated to the renderer.
- `scripts/lingpet/lingpet_puppet_grab_renderer.gd`
  Owns stateless Koyora Puppet Control rendering: live/retracting/cut strings,
  elastic fray, hand, CHU/CUT/MISS copy, sparkles, hearts, and deterministic
  animation-clock/shot-count tension lines. It borrows existing collections
  and owns no gameplay state, RNG, wall clock, audio, collision, or boss policy.
- `scripts/lingpet/lingpet_puppet_grab_payload_factory.gd`
  Owns pure Koyora Puppet Control heart and sparkle payload construction.
  `lingpet_puppet_grab_skill.gd` should keep boss ownership, phase transitions,
  retry gates, audio, and render delegation.
- `scripts/lingpet/lingpet_thunder_orb_payload_factory.gd`
  Owns pure Lumion Thunder Orb payload construction for floating orb energy
  motes, large / small explosion particles, clamped base particle dictionaries,
  and the shared electric-stun status data. `lingpet_thunder_orb_skill.gd`
  should keep projectile travel / deceleration, explosion timing, boss-center
  hit geometry, electric-loop lifecycle, source-scoped status clear, and render
  delegation.
- `scripts/lingpet/lingpet_dragon_breath_payload_factory.gd`
  Owns pure Red Dragon Dragon Breath payload construction for breath embers,
  lingering fire-zone dictionaries, zone flame dictionaries, boss slow status
  data, and molotov-renderer conversion payloads. `lingpet_dragon_breath_skill.gd`
  should keep companion-origin tracking, heat-cone ball reflection, fire-zone
  lifetime / boss push logic, molotov host lifecycle, audio, and render
  delegation.
- `scripts/lingpet/lingpet_moon_orbit_skill.gd`
  Owns Draft Bat / Orbi Moon Orbit runtime: projectile travel to the opponent
  wall, orbit-field placement and duration, boss-overlap slow refresh, burst /
  ambient particle lifecycle, and `moon_orbit_*` snapshot keys. It delegates
  stateless composition with explicit gameplay scalars and borrowed trail/
  particle arrays to `lingpet_moon_orbit_renderer.gd`.
- `scripts/lingpet/lingpet_moon_orbit_renderer.gd`
  Owns stateless Moon Orbit field fill/outlines/crescents, both particle kinds,
  wall-impact burst, projectile core/glow/trail, and validated ellipse points.
  It owns no wall/field/status/collision/particle lifecycle, payload generation,
  wall-clock read, snapshot state, or retained live collections.
- `scripts/lingpet/lingpet_bomb_surprise_skill.gd`
  Owns Volty Bomb Surprise runtime: companion flight to the ball, fuse timing,
  ball / top / bottom detonation routing, boss / player stun and knockback,
  fuse audio cleanup, explosion VFX, companion position override, and
  `bomb_surprise_*` snapshot keys.
- `scripts/lingpet/lingpet_dragon_wing_skill.gd`
  Owns Farukiras / Red Dragon Dragon Wing runtime: wind-field duration,
  ball-vortex steering and speed bounds, gameplay wind/particle RNG, live
  particle/trail advancement, flying-dragon motion/collision boost, hit audio,
  render fanout, and `dragon_wing_*` snapshot keys.
- `scripts/lingpet/lingpet_dragon_wing_renderer.gd`
  Owns stateless warm wind streaks, runtime-clocked vortex, borrowed ball/dragon
  trails, flying-dragon sheet/fallback, directional hit flash, additive material,
  and render-resource prewarm. It retains no gameplay state, wall clock, RNG
  stream, audio, collision, or payload collection.
- `scripts/lingpet/lingpet_doll_curse_skill.gd`
  Owns Koyora Doll Curse runtime: marionette phase/movement timing, beam sweep
  and homing gameplay rolls, hit-cone and per-doll boss-contact geometry,
  boss-confusion apply / clear, ball bounce, destroy-particle lifecycle,
  companion cast-pose override, audio, doll-sheet prewarm, render fanout, and
  `doll_curse_*` snapshot keys. CanvasItem recipes and compatibility render
  projections delegate to the focused renderer.
- `scripts/lingpet/lingpet_doll_curse_renderer.gd`
  Owns stateless Koyora Doll Curse marionette rigging, beam layers/accents,
  sheet-frame and procedural-fallback dolls, destroy debris, hit flash, and
  beam-debug projection. It borrows the live typed arrays and owns no gameplay
  state, RNG, wall clock, texture loading, audio, collision, status, or retained
  payload.
- `scripts/lingpet/lingpet_thunder_orb_skill.gd`
  Owns Lumion Thunder Orb runtime: decelerating orb travel, main blast radius /
  stun duration, Lv.3+ mini-spark chain, electric-loop lifecycle cleanup,
  source-scoped boss electric stun, update-side particle simulation RNG, render
  fanout, and `thunder_orb_*` snapshot keys.
- `scripts/lingpet/lingpet_thunder_orb_renderer.gd`
  Owns stateless Lumion Thunder Orb trail/energy-mote, orb/crackle, explosion,
  explosion-particle, and mini-spark drawing plus deterministic redraw-only
  crackle projection. It borrows live payload arrays and owns no gameplay state,
  wall clock, RNG stream, audio, collision, status, or retained collection.
- `scripts/lingpet/lingpet_dragon_breath_skill.gd`
  Owns Red Dragon Dragon Breath runtime: companion-origin breath cone tracking,
  heat-cone ball reflection, lingering fire-zone spawn / lifetime, boss slow /
  push refresh, gameplay reflection RNG, molotov-renderer payload conversion /
  host lifecycle, breath audio, materials/prewarm, and `dragon_breath_*`
  snapshot keys. It delegates CanvasItem recipes to the focused renderer and
  passes runtime `_elapsed` to both render paths.
- `scripts/lingpet/lingpet_dragon_breath_renderer.gd`
  Owns stateless Red Dragon Dragon Breath jet, additive muzzle, ember/tongue
  particles, deterministic rare motes, and hit-flash composition. It borrows
  the live typed particle array and owns no gameplay state, RNG, wall clock,
  audio, collision, status, or retained payload.
- `scripts/lingpet/lingpet_dragon_breath_texture_cache.gd`
  Owns procedural Dragon Breath texture cache and staged prewarm for flame
  tongues and embers. Runtime draw code should reuse this cache instead of
  creating `ImageTexture` resources in hot paths.
- `scripts/lingpet/lingpet_bone_barrier_payload_factory.gd`
  Owns pure Nekuring Bone Barrier payload construction for barrier dictionaries,
  build particles, hit particles, and bone fragments.
- `scripts/lingpet/lingpet_bone_barrier_skill.gd`
  Owns Nekuring Bone Barrier runtime: level-scaled barrier width, bonus-barrier
  rolls, install / build timing, round-persistent barriers, ball-collision
  context, shatter/particle simulation, audio feedback, and `bone_barrier_*`
  snapshot keys. Stateless drawing is delegated to
  `lingpet_bone_barrier_renderer.gd` with three borrowed live arrays.
- `scripts/lingpet/lingpet_bone_barrier_renderer.gd`
  Owns stateless Nekuring Bone Barrier assembly bones, completed ivory/joint/
  spike/poison-wisp surface, shatter shockwave/fragments, particles, bone-
  segment recipe, and palette. It consumes explicit build/death durations plus
  borrowed barrier/dying/particle arrays; it must not own placement/bonus RNG,
  build/break simulation, collision/reflect/audio/round policy, or retained
  payload collections.
- `scripts/lingpet/lingpet_skeleton_archer_payload_factory.gd`
  Owns pure Nekuring Skeleton Archer payload construction for archer summon
  dictionaries, arrows, summon / hit particles, and dying archer fragments.
- `scripts/lingpet/lingpet_skeleton_archer_skill.gd`
  Owns Nekuring Skeleton Archer runtime: summon caps, patrol / aim / fire timing,
  golden and bonus-summon rolls, arrow hit geometry, boss knockback / stun
  status, archer destruction, collection lifecycle, render delegation, and
  `skeleton_archer_*` snapshot keys. It lends the four typed runtime
  collections and explicit timing scalars without copying.
- `scripts/lingpet/lingpet_skeleton_archer_renderer.gd`
  Owns stateless Nekuring Skeleton Archer rendering in particles / dying / live
  / arrows order: normal and golden spirit bodies, emerge layers, bow and aim
  poses, soul motes, death fragments, trails, and arrow composition. It owns no
  gameplay state, RNG, wall clock, audio, status, collision, or retained
  collection.
- `scripts/lingpet/lingpet_milk_shot_payload_factory.gd`
  Owns pure Milkring Milk Shot payload construction for projectile dictionaries,
  boss-stun status data, hit particles, and muzzle splashes.
- `scripts/lingpet/lingpet_milk_shot_skill.gd`
  Owns Milkring Milk Shot runtime: normal and mega firing modes, level-scaled
  shot count / duration / stun / knockback, projectile deceleration, hit
  geometry, muzzle / hit VFX, and `milk_shot_*` snapshot keys.
- `scripts/lingpet/lingpet_milk_production_skill.gd`
  Owns Milkring Milk Production runtime: production timer, level-scaled milk
  bottle paddle multiplier, Lv.3+ cheese roll and item selection, active-item
  field spawn handoff, production gauge / spawn flash drawing, and
  `milk_production_*` snapshot keys.
- `scripts/lingpet/lingpet_headbutt_skill.gd`
  Owns Lunabi Headbutt runtime: arm gate, homing dash, moving-target miss rolls,
  combo repeats, mega charge / stun / knockback upgrades, ground-slam variant,
  companion position override, audio/shake/status side effects, render fanout,
  and `headbutt_*` snapshot keys. Stateless procedural recipes are delegated to
  `lingpet_headbutt_renderer.gd` with explicit clocks/scalars and a borrowed
  trail array.
- `scripts/lingpet/lingpet_headbutt_renderer.gd`
  Owns stateless Lunabi/Onimaru Headbutt rendering: Mega charge, normal/fire
  dash, ordered ground cracks/slam/generic hit/Mega/sparks, miss impact/text,
  and self-stun stars. It consumes runtime-owned clocks and distinct shaken
  draw versus unshaken deterministic-seed positions; it owns no mutable
  gameplay state, RNG, wall clock, audio, status, or collision policy.
- `scripts/lingpet/lingpet_solar_bolt_skill.gd`
  Owns Lumion Solar Bolt runtime: defensive ball-reflect arm gate, first strike,
  refire chance / delayed refires, ball speed lock / rebound direction, strike-
  time lightning-path and spark payload generation, effect/particle lifecycle,
  explicit visual clock, audio/feedback, and `solar_bolt_*` snapshot keys.
- `scripts/lingpet/lingpet_solar_bolt_renderer.gd`
  Owns stateless Lumion Solar Bolt screen-flash, layered bolt/branch/fork,
  explosion flash/core/ring/arc, and spark CanvasItem recipes. It borrows live
  effect/particle arrays and consumes runtime elapsed plus effect seed for the
  original 85% flicker; it must not own arm/refire/collision/audio policy,
  strike-time path RNG, wall-clock reads, or retained render state.
- `scripts/lingpet/lingpet_gravity_accel_skill.gd`
  Owns Orosha Gravity Accel runtime: level-scaled duration and gravity strength,
  upward ball pull with speed caps, ambient field particles, distortion-line
  drawing, and `gravity_accel_*` snapshot keys.
- `scripts/lingpet/lingpet_dwarf_magic_skill.gd`
  Owns Dwarf Magic runtime: homing projectile, hit / miss tracking, boss shrink
  and restore phases, boss slow context keys, owner-state sync, dust / projectile
  VFX, and `dwarf_magic_*` snapshot keys.
- `scripts/lingpet/lingpet_sand_prison_skill.gd`
  Owns Rahoset Sand Prison runtime: cage creation / miss / imprison / dissolve
  phases, retry and cage-width rolls, boss clamp owner fields, ambient/body
  particle simulation, companion cast-pose override, audio hooks, explicit
  visual clock, and `sand_prison_*` snapshot keys. Stateless CanvasItem recipes
  are delegated to `lingpet_sand_prison_renderer.gd` with live borrowed arrays.
- `scripts/lingpet/lingpet_sand_prison_renderer.gd`
  Owns stateless Rahoset Sand Prison cage walls/floor/corners, deterministic
  wall-grain/glow/decor bars, ambient/body-particle, and MISS-text CanvasItem
  recipes. It consumes runtime phase clocks, cage geometry, wash direction,
  and borrowed live particle arrays; it must not own phase/retry/clamp/audio
  policy, particle simulation RNG, wall-clock reads, or retained render state.
- `scripts/lingpet/lingpet_star_coil_skill.gd`
  Owns Orosha Star Coil runtime: wall roll / climb / lunge / bind / cross /
  descend phases, boss slow / dash-block / cooldown-freeze effects, boss and
  companion position ownership, movement/bind audio, deterministic spark
  payload generation/advancement, and `star_coil_*` snapshot keys. Stateless
  drawing is delegated to `lingpet_star_coil_renderer.gd` with borrowed arrays.
- `scripts/lingpet/lingpet_star_coil_renderer.gd`
  Owns stateless Orosha Star Coil motion-trail, spark glow/regular-star/core,
  and safe alternating-radius polygon CanvasItem recipes. It consumes explicit
  trail visibility plus borrowed live trail/spark arrays; it must not own phase,
  movement, boss status, audio, RNG, or retained payload collections.
- `scripts/lingpet/lingpet_wild_roar_skill.gd`
  Owns Monkeyring Wild Roar runtime: proximity arm gate, roar radius and ball
  boost scaling, trigger/reflection RNG, reflected-ball launch, one-hit speed
  restoration, spark/impact payload spawning and simulation, feedback, owner
  cleanup, companion cast-pose override, and `wild_roar_*` snapshot keys. It
  delegates stateless composition with explicit scalars and a borrowed particle
  array to `lingpet_wild_roar_renderer.gd`.
- `scripts/lingpet/lingpet_wild_roar_renderer.gd`
  Owns stateless Wild Roar full-canvas flash, growing disc, delayed gold/cyan
  rings, rotating spokes, particle circles, reflected-ball glow/streak, and pure
  ring projection. It owns no RNG, arm/reflection/boost/owner state, payload
  simulation, feedback, snapshot state, wall clock, or retained particle array.
- `scripts/lingpet/lingpet_ring_dash_state.gd`
  Owns Ring Dash / Linkport passive state: emergency guard target prediction,
  once-per-descent roll gating, cooldown, companion position override, short
  visual-hide delay, and `ring_dash_*` snapshot keys.
- `scripts/lingpet/lingpet_ring_dash_vfx.gd`
  Owns Ring Dash / Linkport passive VFX drawing and transient visual payloads.
  Companion runtime should keep trigger policy in `lingpet_ring_dash_state.gd`
  and route only visible burst / trail presentation here.
- `scripts/lingpet/lingpet_starlight_tracking_state.gd`
  Owns Starlight Tracking passive state: drop-token claim rolls, flying and
  ground-pet pickup / delivery phases, companion position override, carried-drop
  metadata sync, round reset, and `starlight_tracking_*` snapshot keys.
- `scripts/lingpet/lingpet_feed_bowl_state.gd`
  Owns the feed-bowl companion sub-state: bowl arm position, approach and eating
  phases, ground-pet tracking, companion position override, bowl drawing,
  completion count, and round / full reset behavior.
- `scripts/lingpet/lingpet_item_egg_absorb_vfx.gd`
  Owns the item-egg absorb visual: origin-to-target burst timing, code-square /
  mote motion, glow texture prewarm, draw lifecycle, and reset semantics used by
  the item-egg absorb router.
- `scripts/lingpet/lingpet_save_store.gd`
  Owns the Ringpet save-file route: loading / saving the runtime snapshot
  from `user://lingpet_save.cfg`, restoring it during battle bootstrap,
  and clearing egg / companion run-state snapshots so Ringpet eggs restart
  fresh on game re-entry instead of carrying a previous roguelike run.
  Default reset data comes from `lingpet_catalog.gd`.
- `scripts/items/mythic_item_catalog.gd` and
  `scripts/items/mythic_item_runtime.gd`
  Own the first mythic/passive equipment slice in the Godot port. The
  static mythic item ids, base field/gauge values, shared helper context
  dictionaries, and Ragnarok / Poseidon / Baal / field-effect constant
  bundles are owned by `scripts/items/mythic_item_runtime_constants.gd` so
  `mythic_item_runtime.gd` can stay focused on facade state and delegation.
  The
  current shipped equipment includes Speed Boots, Speed Gear, Danger Sensor Belt,
  Revival Charm, Spike Boots,
  Dowsing Pendulum, Backpack (`slot_add`), Charge Bag (`chargebag`),
  Battery Pack (`battery`), Repairman Hammer (`master`), Cooling Ball
  (`cooltime`), Timer Belt (`timer_belt`), Fuel Pouch (`fuel_pouch`),
  Kick Charger (`knee_pads`), Soul Burst (`soul_burst`), Bulk-Up Suit (`bulkup`),
  Dash Gear (`dashgear`), Dash Holder (`dashholder`), Gravity Belt
  (`gravitybelt`), Gold Bar
  (`gold_bar`), Reinforced Boomerang
  Gauntlet (`reinforced_boomerang_gauntlet`), Commando Arm
  (`commando_arm`), Rainbow Fur Glove, Adversity Armor, Shrapnel Armor,
  Megingjord, Ragnarok Hammer, Poseidon's Trident,
  Heavenly Cape, Baal's Boots, and Pandora's Legacy:
  body-part slot metadata,
  owned-vs-equipped passive inventory state, debug acquire/equip/toggle
  state, acquire/equip/unequip/toggle/discard orchestration delegated to
  `scripts/items/mythic_item_equipment_facade.gd`, per-frame mythic update
  work detection and light/full owner-sync selection delegated to
  `scripts/items/mythic_item_update_gate.gd`, Danger Sensor Belt /
  Smartphone auto-defense timing constants, threshold constants, and trigger
  logic delegated to `scripts/items/mythic_item_auto_defense_runtime.gd`,
  Venom Mist Gauntlet field constants, equipped / count / roll queries,
  poison / mist field / particle / boss-gauge drain logic delegated to
  `scripts/items/mythic_item_venom_mist_runtime.gd`, Rainbow Fur Glove
  equipped / roll queries, proc constants, player-skill cooldown reduction,
  and aura particle lifecycle delegated to
  `scripts/items/mythic_item_rainbow_fur_glove_runtime.gd`, Adversity
  Armor equipped / active / roll queries, constants, next-round shield /
  serve-speed boost / barrier particle lifecycle delegated to
  `scripts/items/mythic_item_adversity_armor_runtime.gd`,
  Shrapnel Armor equipped / roll queries, constants, player-hit proc /
  gauge spend / shard projectile / dust / boss stun-knockback lifecycle delegated to
  `scripts/items/mythic_item_shrapnel_armor_runtime.gd`, Ragnarok Hammer
  player-hit trigger / stun-ball rally state / boss-hit stun-knockback /
  shock-loop audio / spark lifecycle delegated to
  `scripts/items/mythic_item_ragnarok_runtime.gd`, Soul Burst equipped /
  roll queries, constants, gauge spend / zero-token dash replacement / dash VFX lifecycle delegated to
  `scripts/items/mythic_item_soul_burst_runtime.gd`, Kick Charger constants,
  half-dash equipped / charge-roll queries plus player-hit gauge charging /
  flash particle lifecycle delegated to
  `scripts/items/mythic_item_knee_pads_runtime.gd`, Speed Gear / Gold Bar
  constants, Speed Boots / Speed Gear / Gravity Belt / Bulk-Up Suit /
  Gold Bar / Dash Gear / Dash Holder stat-query and movement / paddle /
  dash-token composition delegated to
  `scripts/items/mythic_item_stat_bonus_runtime.gd`, equipped-roll reads,
  item-roll value reads, owned/equipped counts, and Commando Arm roll item-id
  / stack-cap query ownership delegated to
  `scripts/items/mythic_item_roll_query.gd` with focused item helpers calling
  that owner directly instead of private runtime roll-query bridge methods,
  Poseidon's Trident equipped / roll queries, dash trigger, vortex / capture /
  water-trail / charge-flash particle lifecycle, ball reflection, and boss-hit cleanup delegated to
  `scripts/items/mythic_item_poseidon_runtime.gd`, Baal's Boots weather
  arming / absorb cinematic / round effect activation / projectile and boss
  debuff lifecycle delegated to
  `scripts/items/mythic_item_baal_boots_runtime.gd`, Celestial Armor constants,
  trigger chance / gauge spend / paired-proc immunity / wave-start lifecycle delegated
  to `scripts/items/mythic_item_celestial_armor_runtime.gd`,
  Hermes Shoes constants, equipped query / speed multiplier /
  movement-trail update / clear lifecycle delegated to
  `scripts/items/mythic_item_hermes_shoes_runtime.gd`,
  Heavenly Cape skill-cooldown reduction, sixth skill-slot bonus, and
  player-skill cooldown / max-slot composition delegated to
  `scripts/items/mythic_item_heavenly_cape_runtime.gd`,
  Megingjord activation effect reset, active query, start/audio/redraw
  fanout, particle / bolt construction, elapsed timing, and draw forwarding
  delegated to `scripts/items/mythic_item_activation_effect_runtime.gd`,
  per-frame mythic update sequencing, idle update branch, modal/transient
  update fanout, and post-update sync handoff delegated to
  `scripts/items/mythic_item_update_runtime.gd`,
  full-runtime reset and round-reset sequencing delegated to
  `scripts/items/mythic_item_lifecycle_runtime.gd`, with that lifecycle
  helper and equipment / debug helpers receiving Baal's Boots constants and
  calling item clear / arm owners directly instead of private `_clear_*` /
  `_try_arm_*` runtime bridge methods,
  Revival Charm equipped / available / used checks, match-loss trigger,
  consumed-state spawn exclusion, activation effect draw/update, and clear
  lifecycle delegated to `scripts/items/mythic_item_revival_runtime.gd`,
  Dowsing Pendulum / Dowsing Goggles equipped checks, attraction range /
  context, bonus-card chance, and trigger/reset lifecycle delegated to
  `scripts/items/mythic_item_dowsing_runtime.gd`, Spike Boots dash recovery /
  recharge reductions and Bulletproof Hat / Spiked Helmet player stun /
  knockback resistance queries delegated to
  `scripts/items/mythic_item_defense_gear_runtime.gd`,
  Backpack active-item slot capacity bonuses, Charge Bag wall-bounce gauge
  gain application, and Battery Pack stage-transition gauge preservation
  delegated to `scripts/items/mythic_item_capacity_gauge_runtime.gd`,
  Fuel Pouch max-special-gauge bonuses, Bluetooth Ring paddle-hit gauge
  multiplier, Star Detector bonus starpoint drop chance, Gold Digger
  gauge/gold multipliers, and Lucky Coin double-spawn chance delegated to
  `scripts/items/mythic_item_resource_bonus_runtime.gd`,
  Reinforced Boomerang Gauntlet boomerang launch / homing / spawn /
  knockback / stun bonuses and Commando Arm throw speed / windup / range /
  smoke-duration bonuses delegated to
  `scripts/items/mythic_item_throw_bonus_runtime.gd`,
  Repairman Hammer Brick Wall length / active-item cooldown / wall-spawn
  weighting bonuses, Cooling Ball active-item cooldown reduction, and Timer
  Belt player-skill cooldown reduction delegated to
  `scripts/items/mythic_item_cooldown_gear_runtime.gd`,
  Sage Ring item perk-level / speed / body penalties, Sacred Laurel leaf
  bonus/context, and Transcendent Crown item perk-level bonus/context
  delegated to `scripts/items/mythic_item_progression_bonus_runtime.gd`,
  Smartphone equipped/count state, Smartphone cooldown clear, Neural Helmet
  AI Pill gauge/spawn modifiers, and direction-key AI Pill cancel query
  delegated to `scripts/items/mythic_item_ai_assist_runtime.gd`,
  field-effect visibility gating for draw fanout delegated to
  `scripts/items/mythic_item_field_effect_visibility.gd`,
  per-instance
  roll-option generation / preservation, runtime
  equipment-slot sync, Speed Boots player movement-speed bonuses,
  Speed Gear player direction-change turn-deceleration bonuses,
  Danger Sensor Belt equipped/enabled/cooldown/context state, incoming-ball
  danger prediction, no-cost / no-recovery automatic dash, rolled auto-dash
  cooldown, cooldown HUD orb, and Poseidon Trident sensor-dash trigger,
  Revival Charm one-time match-loss prevention and consumed-state spawn exclusion,
  Spike Boots dash recovery / recharge reduction,
  Dowsing field-item attraction, Backpack active-item
  slot-capacity bonuses, Charge Bag wall-bounce gauge bonuses,
  Battery Pack stage-transition gauge preservation,
  Repairman Hammer Brick Wall length, active-item cooldown, and Brick field-spawn weighting bonuses,
  Cooling Ball active-item cooldown reduction,
  Timer Belt player skill cooldown reduction,
  Fuel Pouch max-special-gauge bonuses,
  Kick Charger half-dash player-hit gauge charging,
  Bulk-Up Suit player paddle size bonuses,
  Dash Gear dash-distance and Boost Charging chance bonuses,
  Dash Holder dash-token capacity bonuses,
  Gravity Belt instant player movement handoff through the shared control
  config and `player_movement_state.gd`,
  Gold Bar owned-state sale value, duplicate farming count, and
  Python-parity carried-item movement-speed penalty,
  Reinforced Boomerang Gauntlet boomerang launch / homing / spawn-roll
  bonuses and fixed knockback / stun bonuses,
  Commando Arm duplicate arm-slot stacking, throwable windup reduction,
  Python-parity fixed generic throw-speed boosts, rolled boomerang
  throw-speed boosts, grenade / flare / molotov range boosts, and smoke /
  tear-gas duration boosts, Megingjord activation feedback, and Ragnarok Hammer
  gauge-spend stun-ball / boss knockback-stun feedback with Lightning
  Fury-style electric-stun overlay, normal stun-sheet motion, shock loop,
  screen shake, and slight previous-direction drift while stunned, plus
  Poseidon's Trident dash-recovery water-vortex trigger, gauge/cooldown/
  vortex-size rolls, wave sound, water-trail ball overlay, and upward
  reflection for boss-hit balls entering the vortex, Hermes Shoes speed
  multiplier and short movement-trail / wing-flap visual state, Heavenly
  Cape player-skill cooldown reduction and sixth skill-orb slot expansion,
  and
  Celestial Armor stun immunity: trigger chance, gauge spend, paired-proc
  guard, rainbow wave VFX state, blocked-source diagnostics, and player /
  context gauge mutation,
  Baal's Boots weather-event absorption: delayed trigger, same-frame source
  weather force-end, sand-terrain zeroing before rebuild, gauge recovery,
  absorbed wind speed boost, fire/ice ball marks, and rain/hail projectile
  boss debuffs, and Pandora's Legacy round-win trigger chance, 3-card
  selection generation, active-overflow / passive / mythic reward routing,
  and modal pause/draw/input state. Pandora's Legacy queues from
  `match_score_event_controller.gd`, opens after scoreboard reset /
  serve-prepare through `match_scoreboard_flow_controller.gd`, and is
  surfaced by the battle input, overlay, modal-gate, and item-update
  drivers. Pandora's Legacy equipped / active checks, trigger and quality
  roll reads, round-win queueing, choice generation, selection start /
  confirm / cancel flow, grant routing, timer advancement, and selection
  input handling are delegated to
  `scripts/items/mythic_item_pandora_legacy_runtime.gd`; pending choices,
  active selection state, selected card index, fade timer, and last trigger
  diagnostics are delegated to
  `scripts/items/pandora_legacy_selection_state.gd`; selection overlay
  backdrop, title / hint text, card layout, badge / icon / title drawing,
  selected-card marker, raw-first icon loading, and local icon texture cache
  reads are delegated to
  `scripts/items/mythic_item_pandora_selection_renderer.gd`; Foul
  Whistle constants, equipped / active checks, negate chance math, trigger,
  delayed reset consumption, effect-active query, clear, and update flow are
  delegated to `scripts/items/mythic_item_foul_whistle_runtime.gd`, while
  its animation frame, delayed reset readiness, pending round reset flag,
  and last loss-type diagnostics are delegated to
  `scripts/items/foul_whistle_state.gd`; Revival Charm used-state,
  activation effect timer, and last loss-type diagnostics are delegated to
  `scripts/items/revival_state.gd`; the
  Celestial Armor wave timer, paired-proc window, and last blocked-source
  state are delegated to `scripts/items/celestial_armor_state.gd`; the
  Hermes Shoes player-center, size, last movement delta, wing phase, and
  trail list are delegated to `scripts/items/hermes_shoes_state.gd`; the
  Baal's Boots pending weather, absorb cinematic, round weather effect,
  absorb center, sand absorbed total, and one-shot gauge grant state are
  delegated to `scripts/items/baal_boots_weather_state.gd`; the
  Baal's Boots absorb particle, aura particle, and projectile arrays plus
  their spawn / lifetime update helpers are delegated to
  `scripts/items/baal_boots_effect_state.gd`; Baal's Boots current
  CanvasItem fallback drawing for the absorb rings, round aura, particles,
  projectiles, and absorb label is delegated to
  `scripts/items/baal_boots_effect_renderer.gd`; the
  Baal's Boots ball mark plus boss slow / knockback combat timers are
  delegated to `scripts/items/baal_boots_combat_state.gd`; the
  active / passive / mythic candidate-pool filtering is delegated to
  `scripts/items/pandora_legacy_pool_builder.gd`; the weighted 3-card
  reward selection and choice normalization are delegated to
  `scripts/items/pandora_legacy_choice_builder.gd`; selected-card active
  slot overflow and passive / mythic acquisition routing are delegated to
  `scripts/items/pandora_legacy_grant_router.gd`; extra Megingjord runtime
  perk-choice roll handling, Python-parity `common_refresh` exclusion,
  max-two chain activation limit, extra-pick chance reads, and new-batch
  Dowsing trigger cleanup are delegated to
  `scripts/items/mythic_item_perk_choice_runtime.gd`; owned-item name
  queries, public/debug inventory item read/count snapshots, debug-menu
  toggle/add routing, roll-editor inventory ensure routing, and one-time
  passive / used-Revival field-spawn skip rules are delegated to
  `scripts/items/mythic_item_ownership_runtime.gd`; F3 passive / mythic
  management-menu prewarm / toggle / input / draw integration is delegated
  to `scripts/items/mythic_item_debug_management_facade.gd`; mythic pause
  aggregation across Baal Boots, acquisition cinematic, Pandora selection,
  and Horn Strawberry transformation is delegated to
  `scripts/items/mythic_item_pause_gate.gd`; the
  field-effect renderer now owns the Baal / Foul Whistle / Revival / Sensor
  draw fanout directly instead of bouncing through thin runtime `_draw_*`
  wrappers;
  `scripts/items/mythic_item_aura_field_renderer.gd` owns Celestial Armor
  wave-arc/shard drawing, Venom Mist fog/field-particle drawing, and Rainbow
  Fur Glove aura ring/ray/particle drawing while the shared field renderer
  passes runtime state and public render budgets through;
  `scripts/items/mythic_item_armor_field_renderer.gd` owns Adversity Armor
  barrier/timer/particle drawing and Shrapnel Armor flash, shard, trail,
  dust, and boss-impact drawing while the shared field renderer passes
  runtime state and public render budgets through;
  `scripts/items/mythic_item_hermes_field_renderer.gd` owns Hermes Shoes FX
  host lookup/creation, deferred attachment, canvas caching, screen-space
  playfield layout calculation, and `sync_state` forwarding while the shared
  field renderer passes runtime state and perf labeling through. The host
  owns the additive underglow, screen-space GPU sparkle particles, cached
  wake sprites, render-scale application, and explicit teardown/debug status;
  `scripts/items/mythic_item_horn_strawberry_field_renderer.gd` owns Horn
  Strawberry transform cinematic visibility/draw plus stem, field-barrier,
  horn-charge, bomb, explosion, and paint draw helpers while the shared field
  renderer passes runtime contexts and public render budgets through.
  `scripts/items/horn_strawberry_paddle_renderer.gd` owns the transformed
  strawberry player body / movement / eating / hold animation rendered through
  the Stage 1 player actor path and transform cinematic landing phase.
  `scripts/items/horn_strawberry_timer_gauge_renderer.gd` owns the timed
  transform duration gauge on the shared right-bottom timer stack;
  `scripts/items/mythic_item_momentum_field_renderer.gd` owns Knee Pads flash
  ring/ray/particle drawing and Soul Burst wind-trail, shockwave, ellipse-arc,
  and dash-particle drawing while the shared field renderer passes runtime
  state and public render budgets through;
  `scripts/items/mythic_item_ragnarok_field_renderer.gd` owns Ragnarok
  impact-ring, electric-stun overlay, stun-aura, and spark drawing while
  `mythic_item_field_effect_renderer.gd` keeps the runtime-state fanout and
  public render-budget status; `scripts/items/mythic_item_poseidon_field_renderer.gd`
  owns Poseidon trail / vortex-particle / explosion draw sequencing while the
  shared field renderer passes runtime state and public render budgets through;
  Foul Whistle, Revival, and Sensor field-effect branches are also invoked
  directly by the field renderer from runtime state and compact draw
  constants;
  helper initialization order, helper script-path lookup, and helper
  construction are delegated to
  `scripts/items/mythic_item_helper_registry.gd`;
  Megingjord activation effect duration, particle / bolt counts, default
  start / draw / build contracts are delegated to
  `scripts/items/mythic_item_activation_effect_runtime.gd`;
  snapshot item-id / radius / gauge defaults are delegated to
  `scripts/items/mythic_item_snapshot_builder.gd`;
  Pandora Legacy active-item Korean names, 3-card count, card rect/index
  routing, and selection overlay draw fanout are delegated to
  `scripts/items/mythic_item_pandora_legacy_runtime.gd`; Pandora selection
  input, owner-redraw, and clear/reset call sites now invoke that helper
  directly instead of bouncing through private runtime bridge methods;
  the mythic runtime
  keeps the public scene-facing API plus draw and input orchestration, with
  unused private helper re-export methods removed after the focused helper
  split work.
  Item Polish (`item_polish`) roll scaling is centralized in this runtime's
  shared roll-value helper: normal options multiply, reverse options divide,
  enhancement bonuses stack with the Polish multiplier, Sage Ring effective
  levels resync the cached runtime-perk state, and `slot_add_count` remains
  the Python-parity enhancement-only exception.
  `mythic_item_catalog.gd` also owns the currently ported passive/mythic
  field-spawn metadata for Speed Boots, Speed Gear, Danger Sensor Belt, Revival Charm, Spike Boots, Dowsing Pendulum,
  Backpack, Charge Bag, Battery Pack, Repairman Hammer, Cooling Ball,
  Timer Belt, Fuel Pouch, Kick Charger, Bulk-Up Suit, Dash Gear, Dash
  Holder, Gravity Belt, Gold Bar, Reinforced Boomerang Gauntlet, Commando Arm, Megingjord,
  Ragnarok Hammer, Poseidon's Trident, Heavenly Cape, Baal's Boots,
  and Pandora's Legacy.
  `scripts/items/mythic_item_catalog_presentation.gd` owns
  display-name lookup, quality-prefix formatting, and quality color lookup
  behind the public catalog API. `scripts/items/mythic_item_catalog_fixed_options.gd`
  owns all fixed-option source arrays and item-name fixed-option lookup behind
  the public catalog API. `scripts/items/mythic_item_catalog_icon_metadata.gd`
  owns catalog icon path lookup plus the shared 32-frame mythic animated icon
  metadata used by mythic catalog item builders, including sheet path, frame
  count / cadence, source inset, fill-slot, and slot-padding fields behind the
  public item-data dictionaries. `mythic_item_catalog.gd` preserves the public
  Commando Arm and Reinforced Boomerang Gauntlet icon-path aliases, but item
  builders should call that helper instead of duplicating icon-path literals or
  the `"icon_sheet_path"` / `"icon_frame_count"` field cluster.
  `scripts/items/mythic_item_catalog_base_metadata.gd` owns common item-data
  base-field hydration for selected static/no-roll builders, including
  `"name"`, `"type"`, `"rarity"`, `"effect"`, `"slot"`, `"icon_path"`, and
  `"chance"`, plus empty roll-field hydration and optional fixed-option
  hydration for static builders, and default roll / roll-option /
  rolled-option hydration for selected rolled builders behind the public
  item-data dictionaries. `mythic_item_catalog_build_router.gd` composes that
  base metadata helper with the icon metadata helper through
  `_with_mythic_icon_item(...)` for 32-frame mythic icon-sheet builders.
  `scripts/items/mythic_item_catalog_build_router.gd`
  owns item-name to builder dispatch and item dictionary construction behind
  the public `build_item_by_name()` catalog API.
  `scripts/items/mythic_item_catalog_lists.gd`
  owns the passive / mythic field-spawn order source plus debug item and
  field-spawn item list construction behind the public catalog API;
  debug item construction reuses `FIELD_SPAWN_ORDER` so there is one catalog
  order source for HUD prewarm, pickup, reward, field-spawn, and debug paths.
  `scripts/items/mythic_item_catalog_spawn_metadata.gd` owns item-name field
  spawn chance lookup behind the public catalog item-data dictionaries.
  `mythic_item_catalog.gd` item builders should call `get_field_chance()`
  instead of duplicating `*_FIELD_CHANCE` constants inline.
  `scripts/items/mythic_item_catalog_roll_definitions.gd` owns the catalog
  roll-option source arrays and item-name roll-option lookup table behind the
  public catalog API. `scripts/items/mythic_item_catalog_rolls.gd` owns roll
  defaults, random roll generation, rolled-option decoration, roll-field
  synchronization, default roll lookup, and passive quality prefix assignment
  while delegating option lookup to the definition owner. Catalog item builders
  should hydrate `"roll_options"` through `get_roll_options(item_name)` instead
  of duplicating `*_ROLL_OPTIONS` arrays directly.
  Broader mythic shop/gacha routing remains future item-domain work.
- `scripts/items/mythic_item_acquisition_cinematic_runtime.gd`
  Owns mythic-item acquisition cinematic orchestration: v2 cinematic script
  cache / prewarm, hidden Node2D host creation and reuse, start eligibility,
  target player-center resolution, active/input/snapshot/update forwarding,
  and reset cleanup. `mythic_item_runtime.gd` keeps the public cinematic API
  while delegating implementation here.
- `scripts/items/mythic_item_acquisition_cinematic_v2.gd`
  Owns the spawned mythic-item acquisition cinematic presentation in the
  Godot port: Python-parity light-beam buildup, burst / white-fade reveal,
  click or confirm-key handoff, icon absorption into the player paddle,
  pause-state exposure through `mythic_item_runtime.should_pause_game()`,
  and legendary acquisition audio cue routing.
- `scripts/items/treasure_hunt_runtime.gd`
  Owns the Godot runtime slice for the instant `instant_treasure_hunt`
  perk: reward rolling, `downtown_treasure_map` effective-level chance
  bonuses, owned-one-time filtering, phase timing, mining-hit/result audio,
  localized result feedback, and mythic/perk/passive/starpoint grant routing.
  It grants from the currently ported mythic lane through `mythic_item_runtime`
  and uses the ported passive item catalog for the 60% passive reward lane.
  Its draw facade samples time/progress once and lends the live result payload.
- `scripts/items/treasure_hunt_renderer.gd`
  Owns Treasure Hunt presentation resources and deterministic CanvasItem
  recipes: mining-sheet prewarm, item/perk icon caches, cave wash, mining actor
  or fallback, progress bar, reward/empty result, glow, symbol, and text. It
  receives explicit timing/result inputs and owns no reward mutation or RNG.
- `scripts/items/active_item_catalog.gd`
  Owns the currently ported active-item metadata: `gauge_charge` / Energy
    Drink, `vitamin_pill` / Vitamin Drink, `strange_vial` / 기묘한 약병, `aipill` / AI Pill, `grenade`, `flare`, `tear_gas` / 최루탄, `dynamite`, `molotov`, `long_boost` / Giant Potion,
  `regeneration_potion` / Regeneration Potion, `stopwatch` / Stopwatch,
  `magnet_field` / Magnet Field, `holy_barrier` / Holy Barrier,
  `wall` / Brick, `boomerang`, `banana`, and `soap`
  definitions, icon paths, cooldown / gauge constants, field-spawn order,
  active-only random spawn fallback, and display-name fallback. The runtime asks
  this catalog for item data instead of rebuilding definitions locally.
- `scripts/items/active_item_field_spawn_pool.gd`
  Owns field-drop candidate construction and weighting across the active
  catalog plus passive/mythic field-spawn catalog: passive spawn chance
  adjustments, one-time passive exclusions, Viper-only field candidate
  filtering, group-scaled active/passive/mythic target shares, Treasure
  Map field-spawn bonuses, weighted selection, candidate-name reporting,
  and Lucky Coin bonus-spawn item selection.
- `scripts/items/active_item_field_spawn_portals.gd`
  Owns field-spawn portal state and pending release timing: normal
  item-spawn portal entries, Lucky Coin bonus portal entries, pending
  field-item release queues, `instant_dimension_gate` sustained center
  portal phase transitions, dimension-gate spawn cadence, blocked-state
  cleanup, and portal expiry culling.
- `scripts/items/active_item_field_item_motion.gd`
  Owns field-item geometry and motion: random field-item positions,
  Lucky Coin bonus offsets, spawned field-item dictionaries, first-frame
  spawn-skip handling, wall bounce / max-bounce culling, spin and spawn
  spark timers, paddle collision rect construction, Dowsing Pendulum
  attraction, player paddle rect reads, and boomerang-style near-item
  collection.
- `scripts/items/active_item_field_pickup_flow.gd`
  Owns field-item pickup flow after motion advances: paddle collision
  checks, active-slot array reads, successful-store writeback to the
  battle owner, pickup-feedback callback dispatch, survivor list rebuilds,
  and boomerang-style near-item collection result normalization.
- `scripts/items/active_item_field_spawn_scheduler.gd`
  Owns regular field-spawn timing and blocking: spawn-delay rolls,
  last-spawn timestamps, runtime perk spawn-delay overrides, tutorial /
  stage-50 and arena-mode spawn blocking, busy-state gating when field
  items or portals are already visible, and timer refreshes after debug
  spawns or Dimension Gate activation.
- `scripts/items/active_item_field_spawn_queue.gd`
  Owns field-spawn queue assembly: normal delayed portal spawns,
  Dimension Gate center spawns, Lucky Coin bonus field-item construction,
  bonus portal insertion, legacy owner-vs-registry argument normalization,
  and Lucky Coin bonus audio dispatch.
- `scripts/items/active_item_slot_controller.gd`
  Owns active-item slot use orchestration: starter active-slot construction,
  number-key edge input for visible slots, mobile HUD-slot touch activation,
  consumable slot removal, `item_recycle` / Alchemy consume-preservation
  rolls and notice timers, selected-slot HUD sync, and field-pickup storage
  with active-effect store gating. It retains the legacy cooldown fields and
  methods as forwarding facades. Recycled consumables keep their slot, skip
  pending throw backup creation, still apply active-item use gauge bonuses,
  and route Alchemy feedback through `game_audio.play_alchemy`.
- `scripts/items/active_item_slot_cooldown_state.gd`
  Owns active-slot cooldown timing state and policy: the shared use anchor,
  modal-pause anchor shifting, inherited timestamps for newly stored items,
  shared/per-item readiness checks, manual-use timestamp fanout, and
  stage-transition cooldown clearing with deep-copied slot preservation.
  Cooldown-ignoring automatic uses remain neutral because the slot controller
  calls its start/fanout methods only for manual global-cooldown uses.
- `scripts/items/active_item_smartphone_auto_use.gd`
  Owns Smartphone's active-item auto-use orchestration: low-gauge recovery
  priority (`life_elixir` before `gauge_charge`), bottom-loss defense
  priority (`stopwatch` before `holy_barrier`), cooldown-ignoring slot use,
  and the forced-upward Stopwatch recovery adjustment.
- `scripts/items/active_item_pending_throw_recovery.gd`
  Owns consumed-throwable recovery for round transitions: backing up
  throwable active items after a successful windup activation, clearing
  stale backups once a windup releases, canceling pending throw windups on
  round end, restoring the consumed item without spent-use timestamps, and
  restoring the previous global active-item cooldown timestamp.
- `scripts/items/active_item_field_spawn_controller.gd`
  Owns field-drop state for currently ported active/passive/mythic items:
  spawn scheduling delegated to `active_item_field_spawn_scheduler.gd`,
  item selection delegated to `active_item_field_spawn_pool.gd`, portal / pending-release
  state delegated to `active_item_field_spawn_portals.gd`, field-item
  motion / Dowsing attraction / near-item collection delegated to
  `active_item_field_item_motion.gd`, spawn queue assembly delegated to
  `active_item_field_spawn_queue.gd`, pickup collision and slot writeback
  delegated to `active_item_field_pickup_flow.gd`, dimension-gate spawn
  requests, and debug-spawn injection. It calls back into the runtime only
  for slot storage rules and pickup feedback.
- `scripts/items/active_item_pickup_feedback.gd`
  Owns field-pickup presentation handoff: pickup display-name fallback,
  pickup color extraction, and routing picked field-item data into the
  effect controller's acquisition popup / particles.
- `scripts/items/active_item_pickup_router.gd`
  Owns field pickup storage routing shared by the active-item runtime and
  boomerang return handler: active items go through the active-slot
  controller with effect store gates, while passive / mythic / legendary
  field items route into `mythic_item_runtime.acquire_item()` with roll
  overrides preserved. Mythic / legendary field pickups now suppress the
  small pickup popup and hand the acquired item into
  `mythic_item_acquisition_cinematic.gd` instead. It also provides the
  pickup-feedback handoff used by the runtime callback.
- `scripts/items/active_item_effect_router.gd`
  Owns active item use-effect routing: item `name` / `effect` id matching
  and dispatch to either the throwable controller or the consumable effect
  controller. The runtime keeps only the slot-use callback.
- `scripts/items/active_item_boomerang_return_handler.gd`
  Owns boomerang return resolution after a thrown boomerang reaches the
  player: active-slot insertion or passive/mythic inventory routing for
  collected field items via `active_item_pickup_router.gd`, pickup feedback
  fanout, and returning the consumed boomerang item to the active-item
  slots.
- `scripts/items/active_item_field_renderer.gd`
  Owns active field-item rendering: item-spawn portal sprite / fallback
  drawing including 차원개방's sustained opening / holding / closing portal
  phases and rainbow center effect, animated unknown field-icon drawing,
  field-item glow, and spawn electric-spark effects. It keeps the portal
  and unknown-item texture caches outside the active-item runtime.
- `scripts/items/active_item_runtime_render_facade.gd`
  Owns active-item draw-call assembly for the runtime facade: visible
  field-item renderer dispatch, throwable renderer dispatch, field-effect
  renderer dispatch, pickup-effect draw gating, shake-offset propagation,
  and shared horizontal timer-gauge stack lookup. `active_item_runtime.gd`
  keeps the public draw methods but delegates their implementation here.
- `scripts/items/active_item_throw_controller.gd`
  Owns active projectile / deployed-object item state: grenade / flare /
  dynamite / molotov / boomerang / banana / soap thrown lifecycles plus
  spider-mine direct deploy / crawl / embed / explosion state. It owns
  the public activation API, player-control lock state,
  remaining projectile travel, dynamite placement / fuse / explosion timers,
  molotov fire-zone slow / push timers, boomerang return collection,
  banana landing / forced slip, soap landing / slip timers, spider-mine
  slow timers, grenade explosion zones, flare flash zones, boss stun /
  knockback / confusion / slip timers, actor draw context, and boss-AI
  context. It also owns the cross-throw Commando Arm read hooks that keep
  pending windups, generic / boomerang throw speed, grenade / flare /
  molotov range, and smoke duration bonuses centralized in
  `mythic_item_runtime.gd`.
- `scripts/items/active_item_throw_reset.gd`
  Owns throw-controller reset lifecycle cleanup: dynamite fuse stop
  dispatch, projectile / deployed-object / particle / zone array clears,
  and boss-affecting throwable timer resets. The throw controller keeps
  the public `reset()` API and delegates the internal cleanup sequence
  here.
- `scripts/items/active_item_throw_activation.gd`
  Owns common throwable activation setup: legacy throw start-position
  reads, boss-position reads, pending-throw dictionary construction,
  release timestamp assignment, extra pending-field copying, round-start
  lockout checks, active-windup blocking, item-specific target selection,
  throw-before audio, optional active-item audio, and spider-mine direct
  activation dispatch. Commando Arm windup reduction is applied here only
  for Python-matching throwable names; tear gas keeps its smoke-grenade
  activation timing while receiving only the smoke-duration bonus later.
  The throw controller keeps the public `activate_*` APIs and delegates
  their lifecycle setup here.
- `scripts/items/active_item_throw_grenade_flare.gd`
  Owns grenade / flare projectile construction and flight updates:
  legacy player-centered start positions, aim jitter, throw audio,
  wall bounce / top-edge arrival, trail trimming, projectile removal,
  grenade explosion zones, flare flash zones, grenade-channel boss stun /
  knockback decay, flare confusion decay, stage2 speed-defense status
  clearing, Commando Arm speed / first-frame launch / radius bonuses, and
  impact feedback / audio. The throw controller keeps
  authoritative arrays / timers and compatibility wrappers for the old
  private grenade / flare methods.
- `scripts/items/active_item_throw_tear_gas.gd`
  Owns tear-gas projectile construction, flight updates, armed emission,
  smoke-zone creation, smoke particle lifecycle, zone expansion / opacity,
  boss-in-gas detection, Commando Arm smoke-duration bonuses without range
  or windup changes, and boss skill-cooldown pause latch decay. The throw
  controller keeps authoritative arrays / timers and compatibility wrappers
  for the old private tear-gas methods.
- `scripts/items/active_item_throw_dynamite.gd`
  Owns dynamite projectile construction, landing placement, fuse audio
  start / stop cleanup, placed-dynamite nudge / wobble / countdown,
  explosion creation, explosion particle lifecycle, screen shake / audio,
  and dynamite boss stun / knockback application. The throw controller
  keeps authoritative arrays / timers and compatibility wrappers for the
  old private dynamite methods.
- `scripts/items/active_item_throw_molotov.gd`
  Owns molotov projectile construction, flight / wall bounce updates,
  fire-zone creation, flame spawn / animation lifecycle, boss-in-fire
  detection, continuous fire-zone crossing obstruction between feedback
  ticks, periodic boss pushback / shake feedback, Commando Arm speed /
  first-frame launch / fire-size bonuses, first-update push-timer seeding,
  and molotov impact / push feedback. The throw controller keeps
  authoritative arrays / timers and
  compatibility wrappers for the old private molotov methods.
- `scripts/items/active_item_throw_boomerang.gd`
  Owns boomerang gauntlet launch context, projectile construction,
  outgoing / returning flight state, Commando Arm rolled launch-speed
  stacking, boss-hit stun / knockback, returning item pickup, return
  callback dispatch, break / return audio, trail points, break particles,
  and particle lifecycle. The throw controller
  keeps authoritative arrays / timers and compatibility wrappers for the
  old private boomerang methods.
- `scripts/items/active_item_throw_banana.gd`
  Owns banana projectile construction, flight / wall bounce updates,
  landing creation, landed-banana timer / boss collision checks, forced
  boss-slip latch, banana burst-particle lifecycle, and slip decay. The
  throw controller keeps authoritative arrays / timers and compatibility
  wrappers for the old private banana methods.
- `scripts/items/active_item_throw_soap.gd`
  Owns soap projectile construction, flight / wall bounce updates,
  landing creation / landing audio, landed-soap timer / boss collision
  checks, soap debuff latch, burst-particle lifecycle, foam-trail
  lifecycle, and debuff decay. The throw controller keeps authoritative
  arrays / timers and compatibility wrappers for the old private soap
  methods.
- `scripts/items/active_item_throw_spider_mine.gd`
  Owns spider-mine direct deployment, floor / wall / embedding / armed /
  exploding state progression, setup and walk-loop audio routing,
  explosion feedback, boss stun / knockback / slow application,
  explosion-particle lifecycle, and slow timer decay. The throw
  controller keeps authoritative arrays / timers and compatibility
  wrappers for the old private spider-mine methods.
- `scripts/items/active_item_throw_query.gd`
  Owns read-only query assembly for active throwable state: throw windup
  visibility, visible-effect array checks, actor draw-context dictionaries,
  boss-AI context dictionaries, banana slip-speed calculation, molotov
  boss-fire detection, and tear-gas boss cooldown pause reporting. The
  throw controller keeps authoritative timers and projectile arrays, but
  delegates these context reads here.
- `scripts/items/active_item_throw_windup.gd`
  Owns common pending-throw windup queue mechanics: release-time checks,
  survivor queue rebuilds, item-name release dispatch through callback
  maps, windup progress calculation, and throw-pose angle interpolation.
  The throw controller still owns the public/private item-specific release
  handlers that spawn projectile state and keeps a compatibility wrapper
  for old private windup release calls.
- `scripts/items/active_item_throw_renderer.gd`
  Owns the active throw render facade: public draw signature, draw-order and
  perf labels, generic windup pose / throw-icon lookup, throw-icon texture
  caches, Tear Gas renderer fallback constants, and compatibility wrappers /
  texture aliases for Spider Mine sheet smoke tests.
  `scripts/items/active_item_throw_grenade_renderer.gd` owns Grenade
  projectile sprites / trail drawing, explosion-zone delegation through the
  shared `GrenadeExplosionDrawer`, fallback grenade dot drawing, icon texture
  loading, and Grenade asset prewarm. `GrenadeExplosionDrawer` also owns the
  fire-support airstrike explosion style layered from cached impact flare /
  shockwave textures while keeping normal item Grenade explosions on the
  lower-cost draw budget.
  `scripts/items/active_item_throw_flare_renderer.gd` owns Flare projectile
  sprites / trail drawing, arrived countdown blink, flare flash / confuse
  zone drawing, flash / glow render budgets, fallback flare dot drawing,
  icon texture loading, and Flare asset prewarm.
  `scripts/items/active_item_throw_tear_gas_renderer.gd` owns Tear Gas
  projectile sprites / arming countdowns, smoke-zone haze, shared particle
  draw budget, cached puff texture generation, smoke tone / seed helpers,
  fallback canister drawing, and Tear Gas asset prewarm.
  `scripts/items/active_item_throw_molotov_renderer.gd` owns Molotov
  projectile sprites / hot-core trails, fire-zone host pool syncing,
  playfield-to-screen projection for detached FX hosts, fallback flame
  ellipses, per-flame ember draws, fallback bottle drawing, icon texture
  loading, and Molotov asset prewarm.
  `scripts/items/active_item_throw_dynamite_renderer.gd` owns Dynamite
  projectile trails / sprites, placed Dynamite countdown badges, warning
  pulses, fuse flames, explosion shockwaves, smoke clouds, sparks, fire
  particles, fallback bundle drawing, and Dynamite asset prewarm.
  `scripts/items/active_item_throw_boomerang_renderer.gd` owns normal and
  metal Boomerang projectile texture draws, return / gauntlet aura rings,
  trail glow, break particles, fallback Boomerang shape, and Boomerang asset
  prewarm. `scripts/items/active_item_throw_spider_mine_renderer.gd` owns
  Spider Mine icon and 4x4 sheet prewarm, state-to-sheet / frame selection,
  wall-angle sheet / fallback rotation, spawn / crawl / armed body drawing,
  leg fallback, armed beacon pulses, explosion drawing, break particles, and
  windup fallback drawing.
  `scripts/items/active_item_throw_slip_renderer.gd` owns Banana
  and Soap projectile sprites, landed banana warnings, landed soap puddles,
  banana / soap particles, foam trails, fallback slip shapes, and the slip
  trail-thinning helper. The runtime passes through the throw controller's
  exposed state arrays.
- `scripts/items/active_item_effect_controller.gd`
  Owns active consumable effect state that is not a thrown projectile:
  Energy Drink / Life Elixir gauge application side effects,
  AI Pill auto-guard / input block / guard
  gauge drain, Giant Potion / Vitamin Pill / Strange Vial activation and
  paddle-scale owner sync, Regeneration Potion activation, Stopwatch
  activation, Magnet Field activation feedback,
  boss-returned ball pull vector correction,
  Holy Barrier duration / bottom-wall collision context,
  Brick installation windup / movement lock / persistent wall hit state /
  crack and destruction particles,
  pickup acquisition popup particles, and store gating for currently active
  duration effects. Timer / render / collision context dictionaries are
  delegated to `active_item_effect_context_builder.gd`, with the
  controller-facing read/query facade delegated to
  `active_item_effect_query.gd`. Per-frame effect update sequencing is
  delegated to `active_item_effect_update_driver.gd`. Runtime state
  snapshot application is delegated to `active_item_effect_state_applier.gd`.
  Active item activation / application entrypoints are delegated through
  `active_item_effect_action_facade.gd`, which preserves the controller's
  public API while forwarding to focused action helpers.
  Active item interaction commands are delegated through
  `active_item_effect_interaction_facade.gd`: Magnet Field boss-return pull,
  Holy Barrier hit bursts, Brick Wall hit resolution, AI Pill player-control
  / guard-drain / Neural Helmet cancel, and forced Stopwatch recovery.
  Player paddle size
  / owner-position synchronization is delegated to
  `active_item_paddle_sync.gd` so active item scaling preserves shared
  movement contracts such as Warp Gate wall-riding bounds. Read-only store
  gating, field-effect presence, speed multiplier, and simple active-state
  queries are delegated to `active_item_effect_status.gd`. Boss-returned
  ball pull vector correction for Magnet Field is delegated to
  `active_item_magnet_field_pull.gd`. Magnet Field activation application,
  player-center snapshotting, and activation feedback / audio routing are
  delegated to `active_item_magnet_field_actions.gd`. AI Pill activation
  application, guard-drain state application, control delegation, and
  related feedback / audio routing are delegated to
  `active_item_aipill_actions.gd`. AI Pill
  auto-control and guard-drain calculations are delegated to
  `active_item_aipill_behavior.gd`. AI Pill active / phase / flash /
  cleanup state and per-frame owner-gauge reads / state application are
  delegated to `active_item_aipill_runtime.gd`. Brick Wall
  placement geometry is delegated to `active_item_brick_wall_geometry.gd`,
  Brick Wall activation application, install-particle spawn, and
  activation feedback / audio routing are delegated to
  `active_item_brick_wall_actions.gd`. Brick Wall installation windup
  state is delegated to
  `active_item_brick_wall_installation.gd`, including completed-wall
  application,
  Brick Wall hit / crack / destroy resolution is delegated to
  `active_item_brick_wall_hit_resolver.gd`, and hit application is delegated
  to `active_item_brick_wall_hit_runtime.gd`. Brick Wall install / hit /
  destruction particle creation and particle lifecycle math are delegated
  to `active_item_brick_wall_particles.gd`; shared transient visual update
  sequencing is delegated to `active_item_transient_effect_updater.gd`.
  Stopwatch recovery speed-ramp
  and resume-velocity calculations are delegated to
  `active_item_stopwatch_recovery.gd`. Shared player paddle center / anchor
  reads are delegated to `active_item_player_center_reader.gd`.
  Regeneration Potion burst rings / particles and their visual lifecycle
  are delegated to `active_item_regeneration_potion_effect.gd`. Pickup
  acquisition popup state and balloon-pop particles are delegated to
  `active_item_pickup_effect_state.gd`. Pickup popup trigger application
  and pickup audio routing are delegated to
  `active_item_pickup_actions.gd`. Holy Barrier duration, glow phase,
  and lifecycle cleanup plus per-frame state application are delegated to
  `active_item_holy_barrier_runtime.gd`. Geumgang Barrier idle / hit particles
  and particle fade are delegated to `active_item_holy_barrier_particles.gd`.
  Geumgang Barrier activation application and activation feedback / audio
  routing are delegated to `active_item_holy_barrier_actions.gd`.
  Magnet Field duration, phase, lifecycle cleanup, and particle-clear
  requests and per-frame state application are delegated to
  `active_item_magnet_field_runtime.gd`.
  Runtime-skill-driven timed active-item duration scaling, currently
  Caffeine (`item_caffeine`) plus future academy-style duration sources,
  is centralized in `active_item_duration_bonus.gd` and consumed only at
  activation/start-state boundaries so timer gauges and effect cleanup use
  the same effective duration.
  Giant Potion / Vitamin Pill / Strange Vial activation application,
  owner paddle sync, and activation feedback/audio routing are delegated
  to `active_item_timed_paddle_activation.gd`.
  Giant Potion / Vitamin Pill / Strange Vial timer, phase, flash,
  transition scale state, and per-frame update application are delegated
  to `active_item_timed_paddle_effects.gd`.
  Life Elixir player-centered burst particles are delegated to
  `active_item_life_elixir_particles.gd`. Energy Drink / Life Elixir gauge
  gain, effective max, and Gold Digger bonus calculations are delegated to
  `active_item_gauge_runtime.gd`. Energy Drink / Life Elixir owner gauge
  mutation, activation feedback / audio, and Life Elixir burst application
  are delegated to `active_item_gauge_actions.gd`. Shared active-item
  audio and feedback cue dispatch is delegated to
  `active_item_effect_feedback.gd`.
  Regeneration Potion activation application, player-anchor visual spawn,
  and activation feedback / audio routing are delegated to
  `active_item_regeneration_potion_actions.gd`.
  Regeneration Potion cooldown resets, dash-token refill, and orb-HUD dash
  token sync are delegated to `active_item_regeneration_potion_runtime.gd`.
  Stopwatch activation application, state snapshot application, and
  activation feedback / audio routing are delegated to
  `active_item_stopwatch_actions.gd`.
  Stopwatch safe-distance activation checks, perk resume-velocity
  consumption, freeze / recovery lifecycle state, and owner-side-effect
  action requests plus per-frame update application are delegated to
  `active_item_stopwatch_runtime.gd`.
  Stopwatch owner-side effect application for freeze velocity writes,
  recovery velocity restoration, and periodic collision-cooldown resets is
  delegated to `active_item_stopwatch_owner_effects.gd`.
  Full active-effect reset application is delegated to
  `active_item_effect_reset.gd`, which clears transient effect containers
  and consumes focused clear-state snapshots where available so reset
  cleanup follows the same ownership boundaries as activation and
  per-frame updates.
- `scripts/items/active_item_effect_reset.gd`
  Owns full active-effect reset application: clearing transient particle /
  effect containers and applying focused runtime clear snapshots for AI
  Pill, timed paddle effects, Stopwatch, Magnet Field, Holy Barrier, and
  Brick Wall installation.
- `scripts/items/active_item_effect_update_driver.gd`
  Owns active-effect per-frame update sequencing: AI Pill, Stopwatch,
  Magnet Field, timed paddle effects, owner paddle sync, Holy Barrier,
  Brick Wall installation, and transient visual containers. Focused helper
  modules still own the state math and side-effect application.
- `scripts/items/active_item_effect_query.gd`
  Owns active-effect read/query facade behavior: store-gating flags,
  field-effect presence, paddle scale / speed multiplier reads, renderer /
  timer / collision context dictionaries, and simple active-state queries.
  It preserves the effect controller's public API while keeping read-only
  aggregation out of the controller body.
- `scripts/items/active_item_effect_action_facade.gd`
  Owns controller-facing active-item action entrypoints: Energy Drink /
  Life Elixir, timed paddle activations, AI Pill activation, Regeneration
  Potion, Stopwatch, Magnet Field, Holy Barrier, Brick Wall activation,
  and pickup popup triggers. It keeps the controller API stable while
  forwarding to the existing focused action helpers.
- `scripts/items/active_item_effect_interaction_facade.gd`
  Owns active-effect interaction commands called by ball / character /
  runtime systems: Magnet Field pull, Holy Barrier hit particles, Brick
  Wall hit resolution, AI Pill player-control and guard-drain commands,
  Neural Helmet direction cancel, and forced Stopwatch recovery. It keeps
  these command entrypoints out of the controller body while preserving
  existing public method names.
- `scripts/items/active_item_effect_state_applier.gd`
  Owns active-effect state snapshot application: unpacking helper-produced
  dictionaries into the effect controller's AI Pill, timed paddle,
  Stopwatch, Magnet Field, Holy Barrier, and Brick Wall installation
  fields, including clear-particle flags. It does not choose gameplay
  transitions; those remain in the focused runtime helpers.
- `scripts/items/active_item_aipill_behavior.gd`
  Owns AI Pill's pure behavior calculations: boosted automatic paddle
  tracking toward the ball, non-Optimus guard gauge drain, Optimus
  no-drain handling, and side-effect requests for flash / feedback /
  state cleanup.
- `scripts/items/active_item_aipill_actions.gd`
  Owns AI Pill action application: activation state application,
  activation feedback / audio dispatch, player-control delegation through
  the behavior helper, and guard-drain result application including flash,
  feedback, and depleted-state cleanup. Pure movement / drain math remains
  in `active_item_aipill_behavior.gd`; lifecycle snapshots remain in
  `active_item_aipill_runtime.gd`.
- `scripts/items/active_item_aipill_runtime.gd`
  Owns AI Pill runtime lifecycle state: activation snapshots, phase
  advance, flash timer ticking, guard-hit flash reset, owner-missing /
  gauge-empty cleanup, inactive reset, and per-frame owner-gauge read /
  state application. Auto-control and guard-drain math remain in
  `active_item_aipill_behavior.gd`; activation / guard application stays
  in `active_item_aipill_actions.gd`.
- `scripts/items/active_item_brick_wall_geometry.gd`
  Owns Brick Wall placement geometry: paddle-centered install rects,
  mythic-adjusted wall width, edge clamping, bottom placement, and
  install-gauge anchor calculation.
- `scripts/items/active_item_brick_wall_actions.gd`
  Owns Brick Wall activation application: active / owner guard checks,
  mythic-aware geometry lookup, installation snapshot consumption,
  install-particle spawning, and activation feedback / audio cue dispatch.
  Windup lifecycle decisions remain in
  `active_item_brick_wall_installation.gd`.
- `scripts/items/active_item_brick_wall_installation.gd`
  Owns Brick Wall installation state transitions: pending wall snapshots,
  install timer start / ticking, install-only gauge-center retention,
  completed-wall snapshots, pending-state cleanup after the windup,
  completed-wall list application, install-complete particle dispatch, and
  full-reset installation clear snapshots.
  Geometry, particle construction, activation audio, and activation
  feedback remain in the focused geometry / particle / action helpers.
- `scripts/items/active_item_brick_wall_hit_resolver.gd`
  Owns Brick Wall hit-state resolution: index validation, hit-count
  increment, crack-level update, destroy-threshold checks, and wall-rect /
  updated-wall snapshots consumed by the hit runtime helper.
- `scripts/items/active_item_brick_wall_hit_runtime.gd`
  Owns Brick Wall hit application: applying resolver snapshots to the
  active wall list, removing destroyed walls, preserving invalid-hit
  no-op behavior, and routing hit dust / destruction fragments through
  the shared Brick Wall particle helper.
- `scripts/items/active_item_brick_wall_particles.gd`
  Owns Brick Wall visual particle state helpers: install dust,
  install-complete dust, hit dust, destruction fragments, cap enforcement,
  lifetime compaction, gravity / drag updates, and fragment rotation.
  Individual particle payload dictionaries are delegated to
  `active_item_brick_wall_particle_payload_factory.gd`.
- `scripts/items/active_item_brick_wall_particle_payload_factory.gd`
  Owns pure Brick Wall particle payload construction for install dust,
  install-complete dust, hit dust, and destruction brick fragments, including
  the legacy jitter ranges and fragment palette.
- `scripts/items/active_item_stopwatch_recovery.gd`
  Owns Stopwatch's pure recovery calculations: remaining-frame-to-speed
  ratio, minimum resume speed, current-direction preference, original
  velocity fallback, and side-effect-free resume velocity snapshots.
- `scripts/items/active_item_stopwatch_runtime.gd`
  Owns Stopwatch activation runtime work: near-player safety rejection,
  runtime-perk resume velocity consumption, initial freeze-state snapshot,
  ball velocity zeroing, player / boss collision-cooldown reset, freeze
  timer ticking, recovery-window handoff, clock / flash ticking, full
  cleanup snapshots, side-effect request flags consumed by focused
  helpers, and per-frame state / owner-side-effect application. Activation
  state application, feedback, and audio are handled by
  `active_item_stopwatch_actions.gd`. Recovery speed math remains in
  `active_item_stopwatch_recovery.gd`; audio and feedback are dispatched by
  the shared feedback helper.
- `scripts/items/active_item_stopwatch_actions.gd`
  Owns Stopwatch activation application: active-state guard, player-center
  read for activation safety, runtime activation snapshot consumption,
  state snapshot application, and activation feedback / audio cue dispatch.
  Freeze / recovery lifecycle decisions remain in
  `active_item_stopwatch_runtime.gd`.
- `scripts/items/active_item_stopwatch_owner_effects.gd`
  Owns Stopwatch owner-side update action application after the runtime
  helper has produced side-effect flags: freeze ball-velocity writes,
  recovery velocity ramp / final restore writes, periodic player / boss
  collision-cooldown resets, stored recovery-velocity upward coercion, and
  recovery speed-ratio delegation. State decisions remain in
  `active_item_stopwatch_runtime.gd`.
- `scripts/items/active_item_player_center_reader.gd`
  Owns active consumable player geometry reads: fallback bottom-aligned
  paddle position, clamped paddle size, center anchors, and non-center
  effect anchors shared by Stopwatch, Magnet Field, Vitamin Pill, Strange
  Vial, Regeneration Potion, and Life Elixir effects.
- `scripts/items/active_item_transient_effect_updater.gd`
  Owns per-frame update sequencing for transient active-item presentation
  containers: loose Brick Wall particles, Regeneration Potion burst
  particles / rings, and pickup popup / balloon-pop particles. Individual
  effect helpers still own their own lifecycle math.
- `scripts/items/active_item_regeneration_potion_effect.gd`
  Owns Regeneration Potion's visual burst state: recovery ring spawning,
  golden particle spawning, particle drift / slowdown / gravity, lifetime
  compaction, and ring expiration. Ring and particle payload dictionaries
  are delegated to `active_item_regeneration_potion_payload_factory.gd`.
  Non-visual reset work is handled by
  `active_item_regeneration_potion_runtime.gd`; activation-side spawning,
  audio, and feedback are handled by
  `active_item_regeneration_potion_actions.gd`.
- `scripts/items/active_item_regeneration_potion_payload_factory.gd`
  Owns pure Regeneration Potion ring and particle payload construction,
  including radial spawn range, velocity range, lifetime defaults, and
  gold particle palette.
- `scripts/items/active_item_regeneration_potion_actions.gd`
  Owns Regeneration Potion's activation application: invoking the
  non-visual runtime reset helper, deriving the player effect anchor,
  spawning the visual burst, and dispatching the activation feedback /
  audio cues through the shared feedback helper.
- `scripts/items/active_item_regeneration_potion_runtime.gd`
  Owns Regeneration Potion's non-visual runtime reset work: Smasher and
  Viper skill cooldown reset, Smasher Drive input cooldown reset, Smasher
  dash-token refill, and orb-HUD dash-token synchronization. Visual burst,
  audio, and feedback application stays in
  `active_item_regeneration_potion_actions.gd`.
- `scripts/items/active_item_pickup_effect_state.gd`
  Owns active-item pickup presentation state: item-data snapshot,
  display-name popup timer, HUD-target easing, fade alpha, balloon-pop
  particle spawning, particle movement, and lifetime compaction. Pickup
  effect and balloon-pop particle payload dictionaries are delegated to
  `active_item_pickup_effect_payload_factory.gd`. Trigger application and
  pickup audio remain in `active_item_pickup_actions.gd`.
- `scripts/items/active_item_pickup_effect_payload_factory.gd`
  Owns pure active-item pickup effect payload construction: popup item-data
  snapshots, optional use-hint text, and balloon-pop particle velocity /
  radius / lifetime / tint ranges.
- `scripts/items/active_item_pickup_actions.gd`
  Owns active-item pickup trigger application: applying the pickup popup
  snapshot to the effect controller, preserving balloon-pop particles, and
  dispatching the item-get audio cue. Popup lifecycle math remains in
  `active_item_pickup_effect_state.gd`.
- `scripts/items/active_item_magnet_field_particles.gd`
  Owns Magnet Field particle presentation state: spawn interval
  accumulation, paddle-centered particle spawning, color selection,
  alpha fade, position updates, lifetime compaction, and cap enforcement.
  Magnet Field duration / phase state and ball-pull gameplay remain in the
  runtime and pull helpers.
- `scripts/items/active_item_hologram_disk_runtime.gd`
  **SUPERSEDED / DELETED (2026-07-29).** The Hologram Disk active item was
  removed and this module no longer exists. The decoy deception mechanic now
  lives in the Smasher form 허공환영 (`void_phantom`) — see
  "2026-07-29 — 허공환영 (Void Phantom) Smasher form" below for the current
  owners. The description that follows is kept only as provenance for the
  contracts that survived the move (decoy kinematics in center-coordinate
  convention, the prediction-model substitution, the cache-only deception
  peek); the item-side lifecycle, duration ticking, and timer gauge described
  here are gone.
  Owns Hologram Disk runtime lifecycle and deception logic: activation /
  clear state snapshots, effects-path duration ticking with atomic
  expiry cleanup, ball-path decoy spawning on the descent-to-ascent edge
  (player-side lower-half gate), per-ascent single deception roll with
  edge + roll-locked double guards, decoy kinematics in center-coordinate
  convention (wall reflection at radius margins, boss-band glitch-pop
  death), pop-particle spawning, and the cache-only deception peek the
  boss AI context builder consumes. Rendering stays in
  `active_item_effect_renderer.gd` (energy-ball layer mirror at reduced
  alpha); timer gauge in `active_item_timer_gauge_renderer.gd`; the
  ball_pos/ball_vel substitution choke point in
  `battle_update_boss_ai_context_builder.gd`. Deception frames additionally
  substitute the prediction-model contract: impact-boost neutralization
  (decoys fly at raw velocity), hologram-only prediction wall bounds
  (`prediction_play_left/right` at the visual margin), and the
  reflected-velocity opt-in flag (`prediction_reflect_velocity`) that
  `boss_ai_prediction_state.gd` consumes.
- `scripts/items/active_item_magnet_field_runtime.gd`
  Owns Magnet Field runtime lifecycle state: activation snapshots,
  duration ticking, phase advance, inactive tick reset, owner-null /
  expiry cleanup, and particle-clear requests. It also applies per-frame
  state snapshots and writes the delegated particle-accumulator result
  after active particle updates. Particle presentation remains in
  `active_item_magnet_field_particles.gd`; activation application,
  feedback, and audio remain in
  `active_item_magnet_field_actions.gd`; boss-returned ball pull remains
  in `active_item_magnet_field_pull.gd`.
- `scripts/items/active_item_magnet_field_actions.gd`
  Owns Magnet Field activation application: active / owner guard checks,
  player-center snapshot reads, runtime activation snapshot consumption,
  state application, and activation feedback / audio cue dispatch.
- `scripts/items/active_item_holy_barrier_particles.gd`
  Owns Holy Barrier particle presentation state: idle particle interval
  accumulation, bottom-wall idle sparkle spawning, hit burst spawning,
  alpha fade, position updates, and lifetime compaction. Holy Barrier
  duration / glow state, collision context, audio, and feedback remain in
  the runtime helper, context builder, and focused action helper.
- `scripts/items/active_item_holy_barrier_runtime.gd`
  Owns Holy Barrier runtime lifecycle state: activation snapshots,
  duration ticking, glow phase advance, inactive tick reset, expiry
  cleanup, full-reset clear snapshots, idle-particle advance requests, and
  inactive particle-fade requests. It also applies per-frame state
  snapshots and writes the delegated particle-accumulator result after idle
  particle updates. Particle presentation remains in
  `active_item_holy_barrier_particles.gd`; activation state application,
  feedback, and audio remain in `active_item_holy_barrier_actions.gd`;
  collision context stays in the context builder / effect controller.
- `scripts/items/active_item_holy_barrier_actions.gd`
  Owns Holy Barrier activation application: runtime activation snapshot
  consumption, state application, and activation feedback / audio cue
  dispatch. Duration / glow lifecycle decisions remain in
  `active_item_holy_barrier_runtime.gd`.
- `scripts/items/active_item_timed_paddle_effects.gd`
  Owns pure timed paddle-effect state transitions for Giant Potion,
  Vitamin Pill, and Strange Vial: start snapshots, duration ticking,
  grow / shrink easing, phase / flash counters, Strange Vial effect
  targets, and default render-anchor cleanup. It also owns clear snapshots
  for Giant Potion / Vitamin Pill / Strange Vial reset state and applies
  per-frame update snapshots through the shared state applier. Activation
  application remains in `active_item_timed_paddle_activation.gd`.
- `scripts/items/active_item_timed_paddle_activation.gd`
  Owns timed paddle-item activation application for Giant Potion,
  Vitamin Pill, and Strange Vial: active-gate checks, state-applier calls,
  Strange Vial restart cleanup, owner paddle synchronization through the
  shared paddle-sync helper, and activation feedback/audio dispatch
  through the shared feedback helper. Per-frame duration / transition
  math remains in `active_item_timed_paddle_effects.gd`.
- `scripts/items/active_item_life_elixir_particles.gd`
  Owns Life Elixir's player-centered burst particle generation: reference
  particle count, center handoff, and factory fanout. Individual burst
  particle payload dictionaries are delegated to
  `active_item_life_elixir_particle_payload_factory.gd`. Gauge gain,
  audio, feedback, and burst application remain in
  `active_item_gauge_actions.gd`; shared pickup-particle lifecycle updates
  remain in the pickup effect helper.
- `scripts/items/active_item_life_elixir_particle_payload_factory.gd`
  Owns pure Life Elixir burst particle payload construction, including
  radial index spread, center jitter, burst velocity, draw radius,
  lifetime, and rainbow color sequence.
- `scripts/items/active_item_gauge_runtime.gd`
  Owns Energy Drink / Life Elixir gauge math: item-data gain defaults,
  Life Elixir full-gauge defaults, owner effective max clamping, Gold
  Digger gauge bonus delegation, final gauge snapshots, and capped actual
  gain reporting. Owner mutation, audio, feedback, and Life Elixir burst
  application remain in `active_item_gauge_actions.gd`.
- `scripts/items/active_item_gauge_actions.gd`
  Owns Energy Drink / Life Elixir gauge application: owner gauge mutation
  from runtime snapshots, shared activation feedback / audio dispatch, and
  Life Elixir player-centered burst spawning through the visual helper.
  Gauge math remains in `active_item_gauge_runtime.gd`.
- `scripts/items/active_item_effect_feedback.gd`
  Owns shared active-item side-effect dispatch for registry-backed
  feedback and audio calls: gauge flash, dash flash, screen shake,
  first-available audio fallback, and multi-cue audio playback. Gameplay
  state transitions remain in the effect controller and focused helpers.
- `scripts/items/active_item_magnet_field_particles.gd`
  Owns Magnet Field particle cadence and lifecycle updates: spawn
  accumulator consumption, cap enforcement, fade compaction, and position
  integration. Individual particle payload dictionaries are delegated to
  `active_item_magnet_field_particle_payload_factory.gd`.
- `scripts/items/active_item_magnet_field_particle_payload_factory.gd`
  Owns pure Magnet Field particle payload construction, including the
  orbit spawn range, upward velocity range, initial alpha, radius range,
  and four-color palette.
- `scripts/items/active_item_holy_barrier_particles.gd`
  Owns Holy Barrier idle / hit particle cadence and lifecycle updates:
  barrier-line spawn timing, inactive fade compaction, and position
  integration. Individual hit / idle particle payload dictionaries are
  delegated to `active_item_holy_barrier_particle_payload_factory.gd`.
- `scripts/items/active_item_holy_barrier_particle_payload_factory.gd`
  Owns pure Holy Barrier particle payload construction, including hit
  burst jitter, idle barrier-line jitter, velocity ranges, alpha defaults,
  and the idle shimmer palette.
- `scripts/items/active_item_effect_context_builder.gd`
  Owns active consumable effect context snapshots consumed by item
  rendering, HUD timers, ball collision, and boss-returned ball processing:
  Giant Potion / Vitamin Pill / Strange Vial timer contexts, AI Pill /
  Stopwatch / Magnet Field / Holy Barrier render contexts, Holy Barrier
  collision context, Brick wall context, and Stopwatch ball-freeze /
  recovery context.
- `scripts/items/active_item_dash_boost_particles.gd`
  Owns Dash Boost idle particle cadence and lifecycle updates: fallback
  player-center selection, spawn accumulator consumption, fade compaction,
  radius shrink, and position integration. Individual idle particle payload
  dictionaries are delegated to
  `active_item_dash_boost_particle_payload_factory.gd`.
- `scripts/items/active_item_dash_boost_particle_payload_factory.gd`
  Owns pure Dash Boost idle particle payload construction, including the
  shipped jitter ranges, velocity ranges, alpha / shrink defaults, and
  four-color palette.
- `scripts/items/active_item_paddle_sync.gd`
  Owns active-item paddle scale composition and owner sync: runtime paddle
  scale, mythic paddle scale, active consumable scale, bottom alignment,
  and Warp Gate-aware X clamping for item-driven paddle resize writes.
- `scripts/items/active_item_effect_status.gd`
  Owns active consumable effect status queries that do not mutate runtime
  state: active-item duplicate store gates, AI Pill global store blocking,
  field-effect presence checks, player speed multiplier composition, and
  simple active / time-freeze booleans exposed through the controller.
- `scripts/items/active_item_magnet_field_pull.gd`
  Owns Magnet Field's boss-returned ball vector correction: last-hit
  filtering, radius checks, player-center fallback, pull blending, and
  speed-preserving velocity output for the ball motion pipeline.
- `scripts/items/active_item_effect_renderer.gd`
  Owns active consumable effect rendering: pickup acquisition popup,
  pickup particles, Regeneration Potion rings / particles, Giant Potion
  field pulses, Stopwatch flash / clock overlay, Magnet Field rings /
  pull lines / particles, Geumgang Barrier and Chukjibu draw delegation,
  Vitamin Pill / Strange Vial field VFX, HUD-visual pickup icon
  lookup, pickup text sizing caches, and field-effect draw ordering. The
  runtime passes through the effect controller's exposed state arrays and
  timer context; timer bars are delegated below.
- `scripts/items/active_item_geumgang_barrier_renderer.gd`
  Owns Geumgang Barrier field presentation and asset prewarm: the layered
  gold / oxblood ritual band, braided knots, repeated Vajra Lotus seals,
  ambient petals, and Vajra-spoke impact response. Gameplay collision,
  duration, and cleanup remain in the existing Holy Barrier runtime owners.
- `scripts/items/active_item_chukjibu_renderer.gd`
  Owns Chukjibu field presentation and asset prewarm: the generated folded-road
  seal, symmetric gold/cyan ground folds, and cyan-white afterimage streaks.
  Gameplay duration and dash modifiers remain in the existing `dash_boost`
  runtime owners for save and routing compatibility.
- `scripts/items/active_item_brick_wall_effect_renderer.gd`
  Owns Brick Wall field visuals: installed wall variant sheet loading,
  crack path / chip drawing, install gauge, hammer cue, dust and fragment
  particles, and Brick Wall asset prewarm. `active_item_effect_renderer.gd`
  keeps compatibility wrappers for cache smoke tests while delegating live
  Brick Wall field drawing here.
- `scripts/items/active_item_timer_gauge_renderer.gd`
  Owns active-item duration gauge rendering for Magnet Field, Holy Barrier,
  Dash Boost, Vitamin Pill, Strange Vial, and Long Boost: right-bottom timer
  stack positioning, bar frame / fill / warning pulse drawing, duration icon
  texture loading and prewarm, and the Magnet Field icon fallback.
  `active_item_effect_renderer.gd` keeps compatibility icon wrappers and
  timer-stack claim orchestration while delegating gauge drawing here.
- `scripts/items/active_item_debug_spawn_menu.gd`
  Owns the F2 active-item debug spawn menu: open / close state, panel and
  row geometry, item entries, icon loading for menu rows, hover rendering,
  and click result mapping. The runtime consumes the selected item name
  through `active_item_debug_inventory.gd`.
- `scripts/items/active_item_debug_inventory.gd`
  Owns F2/debug active-item inventory mutation: selected-menu quantity
  adjustments, direct debug grants, removals by item or effect id, count
  badges, fill helpers used by banana-delivery perks, active-slot capacity
  checks, selected-slot HUD sync, and active-effect store gates.
- `scripts/core/serve_flow_controller.gd`
  Owns serve-wait input and auto-fire timing: Space / left-click player
  serve release, normal player auto-serve delay, tutorial manual-serve
  preservation, and boss auto-serve delay. Boss auto-serve delay keeps a
  weighted mix of instant, quick, medium, and long waits so the boss AI's
  serve-feint movement has room to vary without owning release timing. The
  battle frame flow delegates
  waiting-serve decisions here instead of treating every serve as the same
  one-second auto-fire path.
- `scripts/core/match_flow_controller.gd`
  Owns score-event and scoreboard-flow orchestration: scoring-side
  handoff to `match_score_event_controller.gd`, scoreboard start / finish
  actions through `match_scoreboard_flow_controller.gd`, round-restart
  handoff through `match_round_restart_controller.gd`, and reset handoff.
  Full-game reset fanout is delegated to `match_reset_controller.gd`.
  Ball reset is delegated back through the ball round controller, while
  `battle_scene_match_flow_driver.gd` and
  `battle_scene_ball_snapshot_applier.gd` apply returned owner fields.
  The subcontrollers are registered in the core module catalog and are
  passed through match-flow deps when available; direct unit callers can
  still use the controller's internal fallback instances.
- `scripts/core/match_score_event_controller.gd`
  Owns score-event fanout below match flow: scoring-side handoff to match
  score state, stage-background score reactions, next-server sync,
  scoreboard start / no-scoreboard ball reset fallback, scoreboard wait,
  result-pose texture prewarm queuing, and score-event audio cleanup /
  round-set sound. The texture prewarm path is queued instead of started
  synchronously so the scoreboard can draw before threaded load requests
  begin. Registered as `match_score_event_controller`.
- `scripts/core/match_scoreboard_flow_controller.gd`
  Owns scoreboard-progress result handling below match flow: scoreboard
  timer update, player-win stage-clear result-screen handoff before
  reset-game dispatch, start-serve ball reset, and round-flow serve
  preparation after scoreboard overlay completion.
  Registered as `match_scoreboard_flow_controller`.
- `scripts/core/defeat_settlement_screen.gd`
  Owns the defeat summary snapshot and draw/input lifecycle, including the
  current Stage 1 boss display name resolved from `stage1_boss_variant`.
  Stage 1 identity never falls back to the separate `stage_boss_variant`
  compatibility key. Registered as `defeat_settlement_screen`.
- `scripts/core/stage_clear_result_screen.gd`
  Owns the public battle-flow facade for the stage-clear result screen shown
  after a player match win: show / reset / update / input / draw / status /
  prewarm entry points plus the small active score and pending scene state
  that those adapters expose. Focused handlers now own show-state assembly,
  result-scene spawn / prewarm, update fanout, input fanout, finish flow,
  immediate reward followup, plaza entry / progress, status assembly, and
  reset-state mutation.
  Registered as `stage_clear_result_screen`.
- `scripts/core/stage_clear_result_handler_registry.gd`
  Owns construction of the stage-clear result screen's helper set and injects
  the stable `screen.get("_...")` service names into
  `stage_clear_result_screen.gd`'s `_services` map. The screen keeps dynamic
  `_get` / `_set` access for sibling result-screen adapters, but no longer
  declares, preloads, or instantiates each helper field directly.
- `scripts/core/stage_clear_result_runtime_context_handler.gd`
  Owns the public result-screen runtime-context facade: score snapshot,
  current-stage, selected-character, victory-character, registry instance, and
  stage-result reset wrapper methods used by show / prewarm / spawn / plaza
  flows. Concrete score fallback reads, owner stage / character normalization,
  guarded registry lookup, and Stage 4 / 5 / 6 result-reset routing are
  delegated to `stage_clear_result_runtime_context_data.gd`.
- `scripts/core/stage_clear_result_runtime_context_data.gd`
  Owns stateless result-screen runtime-context extraction and result-reset
  routing: match-score snapshot priority, scoreboard fallback score reads,
  owner current-stage clamping, `PlayerCharacterRuntime` normalization and
  victory-result character mapping, guarded registry lookup, Stage 4 Ponk
  result reset, Stage 5 Hongryun state / fire-machine / actor FX reset, and
  Stage 6 Tetriser result reset.
- `scripts/core/stage_clear_result_show_flow_handler.gd`
  Owns the public result-screen show-flow surface: show-state wrapper method,
  screen-backed show adapter, player-win result propagation, and delegation to
  screen-backed apply / spawn wiring. Player-win gating, score / current-stage
  snapshot reads, show-time stage reset, reward / plaza / starpoint reset
  ordering, pending reset / exit callback storage, pending owner / registry
  storage, stage reward snapshot assembly, active flag setting, and
  spawn-pending flag setting are delegated to
  `stage_clear_result_show_state_data.gd`. Screen-backed context extraction,
  show-state apply dispatch, and show-spawn callback wiring are delegated to
  `stage_clear_result_show_screen_data.gd`.
- `scripts/core/stage_clear_result_show_state_data.gd`
  Owns stateless result-screen show-state assembly: player-win gating, score /
  current-stage snapshot reads through the runtime context handler, show-time
  stage reset, reward / plaza / starpoint reset ordering, pending reset / exit
  callback storage, pending owner / registry storage, stage reward snapshot
  assembly through the stage snapshot builder, active flag setting, and
  spawn-pending flag setting.
- `scripts/core/stage_clear_result_show_screen_data.gd`
  Owns stateless screen-backed show-flow adapter work: reading stage-start
  snapshots, scene nodes, runtime context, stage snapshot builder, resettable
  handlers, screen-state handler, and scene-spawn flow handler from the result
  screen; routing show-state schema assembly through
  `stage_clear_result_show_flow_handler.gd`; applying show state; starting the
  show-time scene-spawn flow; and applying returned spawn state.
- `scripts/core/stage_clear_result_prewarm_flow_handler.gd`
  Owns the public result-screen prewarm flow surface and status storage:
  blocking prewarm loops, scene-shell / staged asset-prewarm wrapper methods,
  cached status updates, cached status reads, and explicit status clearing.
  Scene-shell prewarm call normalization, staged asset-prewarm context
  resolution, result victory character / current-stage lookup, threaded-vs-
  normal prewarm flag forwarding, and status copying are delegated to
  `stage_clear_result_prewarm_step_data.gd`. Screen-backed prewarm handler
  extraction and pending-spawn prewarm callback wiring are delegated to
  `stage_clear_result_prewarm_screen_data.gd`.
- `scripts/core/stage_clear_result_prewarm_step_data.gd`
  Owns stateless result-screen prewarm step execution: scene-shell prewarm call
  normalization, staged asset-prewarm owner fallback resolution, result victory
  character / current-stage lookup through the runtime context handler,
  threaded-vs-normal prewarm flag forwarding, invalid-handler fallback results,
  and cached status dictionary copying.
- `scripts/core/stage_clear_result_prewarm_screen_data.gd`
  Owns stateless screen-backed prewarm adapters: blocking prewarm from screen,
  shell prewarm from screen, pending owner / stage / scene-spawn handler /
  scene-shell handler / runtime-context extraction, pending-spawn callback
  construction, and null-screen status clearing through the prewarm flow
  handler.
- `scripts/core/stage_clear_result_plaza_enter_flow_handler.gd`
  Owns result-screen plaza-entry semantics: active gating, pending reward grant
  timing, stage-clear progress apply timing, starpoint-choice reset, pending
  spawn-state clear callback dispatch, result-scene free callback dispatch,
  plaza asset readiness blocking, plaza scene-config timing, plaza scene spawn
  timing, fallback-to-continue behavior, and redraw requests after successful
  plaza spawn. It returns explicit `false` while composed resource/GPU readiness
  is incomplete so the live plaza callback remains retryable. Screen-backed
  context and callback wiring are delegated to
  `stage_clear_result_plaza_enter_screen_data.gd`.
- `scripts/core/stage_clear_result_plaza_enter_screen_data.gd`
  Owns stateless screen-backed plaza-entry context assembly: active / stage /
  plaza save store / owner / registry / scene / plaza-scene handler /
  starpoint-choice handler reads, selected-character lookup, pending reward
  grant callback binding, stage-clear progress callback binding, pending-spawn
  mutation callback binding, and guarded screen property reads.
- `scripts/core/stage_clear_result_scene_shell_handler.gd`
  Owns the result-scene shell surface: scene path exposure, packed-scene cache,
  callback / spawn / free adapter exposure, and screen result-scene free
  surface. Result-scene callback schema assembly, scene instantiation /
  normalization, config scene-handler wiring, owner child attachment, runtime
  reference cleanup, and screen scene-node reads are delegated to
  `stage_clear_result_scene_shell_scene_data.gd`. Staged prewarm status,
  prewarm step state, result-asset readiness, and required asset-key policy are
  delegated to `stage_clear_result_scene_shell_prewarm_state.gd`.
- `scripts/core/stage_clear_result_scene_shell_scene_data.gd`
  Owns stateless result-scene shell node glue: result-scene callback schema
  dictionaries, packed scene instantiation checks, Control normalization,
  process / z-index / texture filter setup, config scene-handler wiring,
  owner-child attachment, runtime-reference cleanup before free, and
  screen-backed result-scene free adapters.
- `scripts/core/stage_clear_result_scene_shell_prewarm_state.gd`
  Owns stateful result-scene prewarm and readiness policy: packed-scene ready
  status mirroring, selected-character / stage prewarm status, staged config
  prewarm delegation, threaded-vs-normal prewarm branching, cached prewarm
  status copying, selected-stage asset readiness checks, and per-stage required
  result asset-key lists.
- `scripts/core/stage_clear_result_finish_flow_handler.gd`
  Owns the public result-screen finish action surface: stable action constants,
  context-builder / action-dispatch wrappers, next-stage / plaza-continuation /
  exit wrapper methods, and the screen-backed finish adapter entry point.
  Actual finish-flow context schema, action dispatch internals, reward-grant
  timing, progress-apply timing, inactive-state callback ordering, result /
  plaza scene cleanup callbacks, and reset-vs-exit callback selection are
  delegated to `stage_clear_result_finish_action_data.gd`. Screen-backed
  context callback assembly is delegated to
  `stage_clear_result_finish_screen_context_data.gd`.
- `scripts/core/stage_clear_result_finish_action_data.gd`
  Owns stateless result-screen finish action execution: finish-flow context
  schema, next-stage / plaza-continuation / exit dispatch internals, pending
  reward-grant timing, stage-clear progress apply timing, inactive-state
  callback ordering, result / plaza scene cleanup callbacks, guarded context
  callable reads, and reset-vs-exit callback selection.
- `scripts/core/stage_clear_result_finish_screen_context_data.gd`
  Owns stateless finish-flow screen context extraction: pending reset / exit
  callbacks, pending reward grant callback binding, stage-clear progress
  callback binding, finish-inactive callback binding, plaza-scene cleanup
  callback binding, and guarded screen property reads. It routes final context
  schema assembly back through `stage_clear_result_finish_flow_handler.gd`.
- `scripts/core/stage_clear_result_update_flow_handler.gd`
  Owns result-screen per-frame update semantics: plaza-scene-first routing,
  result-scene visibility / timer updates, plaza background prewarm stepping,
  mythic acquisition cinematic updates, runtime perk choice updates, pending
  starpoint-choice updates, and registry instance lookup for update-time
  runtime services. Screen-backed context extraction and pending-spawn callback
  wiring are delegated to `stage_clear_result_update_screen_context_data.gd`.
- `scripts/core/stage_clear_result_update_screen_context_data.gd`
  Owns stateless screen context extraction for result update flow: active /
  spawn-pending state reads, plaza-scene presence and update dispatch, pending
  result-scene spawn callback binding, result-scene existence checks, owner /
  registry / current-stage / selected-character context assembly, and guarded
  screen property reads.
- `scripts/core/stage_clear_result_screen_status_handler.gd`
  Owns public result-screen status schema assembly: base active / score /
  stage / reward-plan / scene-ready / pending-spawn status fields, stage-start
  and stage-reward snapshot copies, and status merges from reward-grant,
  starpoint-choice, and plaza-scene handlers. Screen-backed field reads,
  cached plaza-progress summary lookup, and reward-plan copying are delegated
  to `stage_clear_result_screen_status_screen_data.gd`.
- `scripts/core/stage_clear_result_screen_status_screen_data.gd`
  Owns stateless screen-backed status adapter work: active / score / stage /
  scene-ready / spawn-pending reads, result reward-plan copying, cached plaza
  progress summary reads, stage-start and reward snapshot copying, and handler
  object extraction before routing through the status handler's schema builder.
- `scripts/core/stage_clear_result_input_flow_handler.gd`
  Owns result-screen input semantics: active gating, plaza-scene priority,
  pending-spawn consumption, mythic acquisition input priority, result-scene
  input fanout, post-input active / scene-valid checks, runtime-perk state
  lookup, and starpoint-choice reward sync. Screen-backed context extraction,
  result-scene input timing lookup, and screen callback wiring are delegated to
  `stage_clear_result_input_screen_data.gd`.
- `scripts/core/stage_clear_result_input_screen_data.gd`
  Owns stateless screen-backed input context assembly: spawn-pending / scene /
  owner / registry / plaza / mythic / starpoint handler reads, Dalji click
  dialogue duration lookup, active callback binding, result-scene existence
  callback binding, and guarded screen property reads.
- `scripts/core/stage_clear_result_scene_spawn_flow_handler.gd`
  Owns the public result-screen scene-spawn flow call surface. Raw result-scene
  spawn and configured result-scene spawn are exposed here as a compatibility
  surface but owned by `stage_clear_result_scene_spawn_core_data.gd`.
  Screen-backed spawn / show / pending adapter assembly is exposed here as a
  compatibility surface but owned by
  `stage_clear_result_scene_spawn_screen_data.gd`. Show-time ready-vs-pending
  branching and pending-spawn advancement are exposed here as a compatibility
  surface but owned by `stage_clear_result_scene_spawn_pending_data.gd`.
  Shell prewarm / readiness / required-key delegation is also exposed here as a
  compatibility surface but owned by
  `stage_clear_result_scene_spawn_shell_data.gd`. Callback wiring and
  result-scene config / screen-field reads are owned by their focused helper
  modules below and no longer have private wrapper shells in this flow handler.
- `scripts/core/stage_clear_result_scene_spawn_callback_data.gd`
  Owns stateless result-scene callback wiring: scene-shell callback schema
  delegation, screen-backed spawn callbacks, finish-action callbacks, plaza
  entry / plaza-continue callbacks, roll reward callbacks, immediate reward
  callbacks, and free-result-scene callbacks. The scene-spawn flow handler keeps
  the public result-screen adapter call surface.
- `scripts/core/stage_clear_result_scene_spawn_config_data.gd`
  Owns stateless result-scene spawn config assembly and screen-field extraction:
  scene config builder delegation, result victory character lookup, reward-plan
  copying, snapshot dictionary copying, score / stage integer reads, current
  scene Control reads, and object-service reads. The scene-spawn flow handler
  keeps the public result-screen adapter call surface.
- `scripts/core/stage_clear_result_scene_spawn_core_data.gd`
  Owns stateless result-scene spawn execution: Node-owner validation,
  free-existing-scene dispatch before respawn, shell `spawn_scene` delegation,
  spawned Control normalization, and configured spawn composition from config
  and callback helper payloads. The scene-spawn flow handler keeps the public
  result-screen call surface.
- `scripts/core/stage_clear_result_scene_spawn_pending_data.gd`
  Owns stateless show / pending scene-spawn branching: ready-vs-pending show
  decisions, staged prewarm advancement, result-scene spawn callback dispatch,
  reset dispatch on failed ready spawn, and redraw requests while scene assets
  are pending. The scene-spawn flow handler keeps the public result-screen call
  surface.
- `scripts/core/stage_clear_result_scene_spawn_screen_data.gd`
  Owns stateless screen-backed scene-spawn adapter assembly: pulling pending
  owner / registry / shell / config-builder / score / stage / reward fields
  from the result screen, building result-scene callbacks, invoking configured
  scene spawn through the flow handler, writing back `_scene_node`, and exposing
  screen-backed show / pending spawn entry points. Show / pending call assembly
  is delegated to `stage_clear_result_scene_spawn_screen_pending_data.gd`. The
  scene-spawn flow handler keeps the public result-screen call surface.
- `scripts/core/stage_clear_result_scene_spawn_screen_pending_data.gd`
  Owns stateless screen-backed show / pending adapter assembly: reading pending
  owner / registry / runtime context / stage fields from the result screen,
  resolving the result victory character, building screen spawn callbacks, and
  invoking show / pending spawn through the flow handler's public surface.
- `scripts/core/stage_clear_result_scene_spawn_shell_data.gd`
  Owns stateless result-scene shell delegation: packed-scene shell prewarm,
  staged asset prewarm, copied prewarm status payloads, selected-character /
  stage asset readiness checks, and required asset-key normalization. The
  scene-spawn flow handler keeps the public result-screen call surface.
- `scripts/core/stage_clear_result_reward_plan_builder.gd`
  Owns stage-clear reward-preview plan construction for the result screen:
  score-margin-to-box-count mapping, localized item-box summary text, box
  list materialization, and normal / advanced / guaranteed-mythic box kind
  odds. The result screen keeps only the public `get_reward_plan()` surface
  and no longer owns box-count or odds calculation.
- `scripts/core/stage_clear_result_stage_snapshot_builder.gd`
  Owns stage-clear progress snapshot reads for the result screen: stage-start
  active slots, passive/mythic inventory, runtime perk levels, registry-backed
  mythic runtime and runtime-perk state lookups, plus the public stage-reward
  snapshot call surface. Stage-reward diff row construction is delegated to
  `stage_clear_result_stage_reward_diff_data.gd`. The result screen stores the
  snapshots and passes them into the visible result scene, but no longer owns
  item/perk inventory reads or stage-diff reward construction.
- `scripts/core/stage_clear_result_stage_reward_diff_data.gd`
  Owns stateless stage-clear reward diff construction from prepared snapshots:
  baseline stage mismatch handling, active / passive / mythic reward-list
  selection, and gained-perk reward-list selection. Item reward row construction
  is delegated to `stage_clear_result_stage_item_reward_data.gd`; perk reward row
  construction is delegated to `stage_clear_result_stage_perk_reward_data.gd`.
- `scripts/core/stage_clear_result_stage_item_reward_data.gd`
  Owns stateless stage-clear item reward row construction: remaining active-item
  rows, passive/mythic inventory identity counting, newly acquired passive /
  mythic rows, mythic-vs-passive classification, catalog enrichment, display
  name resolution, icon path forwarding, and item identity fallback keys.
- `scripts/core/stage_clear_result_stage_perk_reward_data.gd`
  Owns stateless stage-clear gained-perk reward rows: baseline-vs-current level
  comparison, runtime perk catalog enrichment, level-delta labels, and payload
  fields consumed by the result scene.
- `scripts/core/stage_clear_result_plaza_progress_handler.gd`
  Owns the result-screen plaza progress edge: one-shot volatile
  `runtime_perk_gold` transfer into `plaza_save_store.gd`, one-shot
  stage-clear AP grant gating, cached progress-summary reporting, and plaza
  save-path lookup for the plaza scene configuration. The result screen keeps
  the battle-flow transition and scene-spawn orchestration, but no longer owns
  the gold/AP idempotence state directly.
- `scripts/core/stage_clear_result_plaza_scene_handler.gd`
  Owns the result-screen plaza scene edge: plaza packed-scene caching,
  scene spawn / configure / free, plaza update / input forwarding, and plaza
  status keys exposed through `stage_clear_result_screen.gd`. Background
  threaded plaza prewarm, blocking prewarm before entry, and prewarm status are
  delegated to `stage_clear_result_plaza_scene_prewarm_state.gd`. The result
  screen keeps the route decision and callback sequencing, but no longer owns
  the plaza node, packed scene, or prewarm state directly.
- `scripts/core/stage_clear_result_plaza_scene_prewarm_state.gd`
  Owns stateful result-screen plaza asset readiness: background prewarm enable
  toggles, current-stage resource-cache status, threaded plaza prewarm stepping,
  composed GPU readiness through `battle_pso_prewarmer.gd`, blocking plaza
  prewarm before entry, and timeout/rejection status for incomplete readiness.
- `scripts/core/stage_clear_result_reward_grant_handler.gd`
  Owns the public result-screen reward grant facade: box reward-roll
  delegation, result-scene resolved reward reads, pending reward grant entry
  points, immediate box grant entry point, and reward-resolver test injection.
  Final pending reward grant idempotence, pending reward filtering, immediate
  starpoint / mythic box grant summary capture, grant-summary merging, cached
  status assembly, and reset state are delegated to
  `stage_clear_result_reward_grant_state.gd`. Stateless immediate starpoint /
  mythic grant branching, grant payload mutation, and grant result dictionary
  construction are delegated to
  `stage_clear_result_immediate_reward_grant_data.gd`. The result screen still
  coordinates visible side effects such as deferred starpoint-choice gates and
  mythic acquisition cinematic z-order, but no longer stores reward resolver,
  final-grant flags, or immediate-grant summary lists directly.
- `scripts/core/stage_clear_result_immediate_reward_flow_handler.gd`
  Owns the public result-screen immediate reward followup facade: direct
  reward grants and screen-backed reward grant callbacks. Deferred
  starpoint-choice followup, mythic acquisition cinematic dispatch, scene
  visibility resync, screen-scene extraction, and registry reads are delegated
  to `stage_clear_result_immediate_reward_flow_data.gd`.
- `scripts/core/stage_clear_result_immediate_reward_flow_data.gd`
  Owns stateless immediate reward followup side-effect routing after an
  immediate starpoint / mythic box grant: defer-choice availability checks,
  deferred starpoint-choice scheduling, mythic acquisition cinematic raising,
  successful-grant scene visibility sync, active-screen guarding, and
  result-screen scene-node lookup.
- `scripts/core/stage_clear_result_reward_grant_state.gd`
  Owns stateful stage-clear reward grant bookkeeping: final pending reward
  idempotence, non-immediate pending reward filtering, resolver grant fallback
  summaries, immediate grant summary capture, cumulative grant-summary merging,
  failed reward list copying, public status snapshots, and reset cleanup.
- `scripts/core/stage_clear_result_immediate_reward_grant_data.gd`
  Owns stateless immediate stage-clear box reward grant execution for starpoint
  and mythic rewards: reward-type branching, starpoint defer-choice payload
  mutation, mythic acquisition cinematic payload mutation, single-reward
  resolver dispatch, and result dictionary assembly. The reward grant handler
  keeps stateful summary capture and merge policy.
- `scripts/core/stage_clear_reward_resolver.gd`
  Owns stage-clear chest reward selection and final grant dispatch. Normal
  chests use the active / passive / starpoint lanes, mythic chests use the
  mythic lane, and final confirmation routes rewards through the existing
  active-item, passive/mythic-item, and runtime-perk starpoint systems.
  Registered as `stage_clear_reward_resolver`.
- `scenes/stage_clear_result.tscn` +
  `scripts/ui/stage_clear_result_scene.gd`
  Own the visible fullscreen result scene: stage-selected result-background
  drawing, Dalji defeated cutscene sheet playback, player victory-side
  sheet playback, score-based reward chest animation, result scroll input,
  result scroll drawing, and scene-local linear texture filtering for
  cutscene art. Result-scroll reward summary arrays, source counts,
  perk-info tile payloads, active / passive / mythic item grouping,
  starpoint totals, and perk reward ID classification are delegated to
  `stage_clear_result_summary_builder.gd`;
  reward card colors / rects, reward label visual state, reward item icon
  visual state / palettes, starpoint visual state, badges, fallback reward
  icon state, and source-chip labels / colors / rects are delegated to
  `stage_clear_result_reward_visual_resolver.gd`; reward icon path
  resolution and scene-local texture caching are delegated to
  `stage_clear_result_reward_icon_resolver.gd`; reward-card title,
  starpoint title formatting, fallback type labels, detail text, and
  catalog-backed perk-data resolution are delegated to
  `stage_clear_result_reward_text_resolver.gd`; result chest layout,
  box-frame policy, reward-card grid layout, and sheet / cover source-rect
  math, floating-box center / AABB / rotate geometry, actor / click / scroll
  content rects, and cinematic-local coordinate conversion are delegated to
  `stage_clear_result_layout_helper.gd`; result-box plan materialization,
  kind normalization, and display-label assembly are delegated to
  `stage_clear_result_box_plan_data.gd` through the `stage_clear_result_box_data.gd`
  compatibility facade; Dalji / Stage 2 / Stage 3 defeated,
  Stage 4 Ponk fallback, Stage 6 Tetriser defeated result actor drawing,
  and player-victory Live2D sheet drawing are delegated
  to `stage_clear_result_actor_draw_helper.gd`; result reward pickup / Live2D
  target position pairing for mythic acquisition cinematics is delegated to
  `stage_clear_result_cinematic_position_helper.gd`; centered text
  baseline, word wrapping, and font-size fitting helpers are delegated to
  `stage_clear_result_text_layout_helper.gd`; result scroll phase
  progression, unfurl progress, and background box alpha are delegated to
  `stage_clear_result_scroll_state.gd`; result button layout / hit state
  and box opened / opening counts are delegated to
  `stage_clear_result_interaction_state.gd`; floating result-box animation /
  hover / reward-label drawing is delegated to
  `stage_clear_result_box_draw_helper.gd`; result scroll texture-region
  drawing, fallback panel, rod drawing, and reward section group panel chrome
  are delegated to
  `stage_clear_result_scroll_draw_helper.gd`;
  opened-scroll header / summary strip / reward section / button draw
  sequencing is delegated to `stage_clear_result_scroll_content_draw_helper.gd`;
  result-box FX host pooling, prewarm cursor, and per-box FX host sync are
  delegated to `stage_clear_result_fx_host_pool.gd`;
  result scroll button chrome,
  hover colors, and next / exit button text drawing are delegated to
  `stage_clear_result_scroll_button_draw_helper.gd`;
  static result-scene surfaces (background fallback / cover blit, Dalji click
  dialogue bubble, player-victory fallback panel, and footer text) are
  delegated to `stage_clear_result_static_draw_helper.gd`; reusable ellipse / radial /
  star polygon point generation plus result-box ornament / hover geometry
  is delegated to `stage_clear_result_shape_helper.gd`; result sheet-frame
  source rect and texture-region drawing are delegated to
  `stage_clear_result_sheet_draw_helper.gd`; public QA / smoke-test
  interaction status dictionary orchestration is delegated to
  `stage_clear_result_status_builder.gd`, with scene snapshot collection
  routed through `stage_clear_result_scene_context_builder.gd` and final
  actor / non-actor status payload assembly routed through
  `stage_clear_result_actor_status_builder.gd` /
  `stage_clear_result_non_actor_status_builder.gd`; player-victory and Dalji
  click-reaction frame / transition / alpha math is delegated to
  `stage_clear_result_click_reaction_state.gd`; result actor click-reaction
  timer advancement is delegated to
  `stage_clear_result_actor_reaction_update_handler.gd`. Keep future reward-pick
  animation / settlement UI work here rather than adding draw blocks back
  to the battle shell; route top-level draw fanout through
  `stage_clear_result_draw_scene_handler.gd` instead of reintroducing focused
  `_draw_*` wrapper methods on the result scene, and do not put grant logic
  back in this UI scene.
- `scripts/ui/stage_clear_result_asset_loader.gd`
  Owns stage-clear result asset loading and staged prewarm dispatch:
  result background / scroll / chest sheets, Stage 4 / Stage 5 / Stage 6 result
  backgrounds, Dalji and player-victory sheets, Stage 4 Ponk fallback sheet,
  Stage 5 Hongryun fallback result sheet, Stage 6 Tetriser result defeat sheet, Dalji click voice, result-box FX
  prewarm, and the stateful result-asset prewarm step cursor / status map used by the screen shell. It
  also owns player-victory character id normalization, default result asset
  path config assembly, and result asset path selection. The asset apply
  handler owns texture-field collection / invalidation / application for the
  scene; the character asset state handler owns configure-time selected
  character cache invalidation; the config scene handler owns configure / ready
  load timing, while the scene still owns loaded stream fields and path constant
  compatibility aliases.
- `scripts/ui/stage_clear_result_character_asset_state_handler.gd`
  Owns configure-time result character asset state resolution: normalizing the
  requested result character through `stage_clear_result_asset_loader.gd`,
  detecting selected-character changes, preserving existing victory sheet
  caches when the normalized character is unchanged, and clearing player-victory
  base / click sheets plus cached loaded paths when it changes. It also owns
  character asset apply payloads and scene-field apply payloads for the
  selected character, player-victory sheet references, and cached loaded path
  fields. The config scene handler owns calling it and writing the returned
  fields through the shared field-payload applier.
- `scripts/ui/stage_clear_result_audio_apply_handler.gd`
  Owns stage-clear result audio stream / SFX application policy: the
  Stage 1 Dalji click-voice stage gate, clearing non-Stage 1 voice streams,
  delegating actual audio loading to `stage_clear_result_asset_loader.gd`,
  preserving already-loaded voice streams, and routing result-box-open SFX
  calls through the optional game-audio dependency.
- `scripts/ui/stage_clear_result_audio_scene_handler.gd`
  Owns stage-clear result audio scene glue: reading / writing the scene's
  Dalji click voice stream and player fields, invoking the audio apply handler
  for stream load and result-box SFX routing, invoking the voice player for
  immediate / deferred playback and stop requests, and preserving the scene's
  existing stage-gated voice behavior. The config scene handler owns ready /
  configure / clear audio lifecycle calls; actor / box scene handlers own their
  focused click and SFX trigger calls.
- `scripts/ui/stage_clear_result_asset_apply_handler.gd`
  Owns stage-clear result texture-field application for the scene: collecting
  current texture fields from the canonical asset-loader key list, invalidating
  player-victory base / click sheets when the selected character path changes,
  delegating the actual load to `stage_clear_result_asset_loader.gd`, writing
  loaded textures back to scene fields, and returning the applied victory sheet
  path state. It also packages texture-path apply payloads for the cached
  player-victory base / click sheet path fields plus scene-field apply payloads
  for the cached path strings. The config scene handler owns when to call it and
  stores the returned path cache strings through the shared field-payload
  applier.
- `scripts/ui/stage_clear_result_voice_player.gd`
  Owns stage-clear one-shot voice player lifecycle for result-scene click
  voices: AudioStreamPlayer creation / parent attachment, stream and volume
  assignment, explicit deferred-method compatibility for detached legacy
  callers, immediate playback, and stopping. Actor-click / callback / config
  scene handlers own play and cleanup timing. The result scene keeps only the
  loaded stream/player fields and should not reintroduce a deferred voice
  callback method.
- `scripts/ui/stage_clear_result_actor_click_handler.gd`
  Owns stage-clear result actor click routing for player-victory, Dalji,
  Stage 2 / Stage 3 boss defeat reaction sheets, Stage 4 Ponk fallback
  result sheet, Stage 5 Hongryun fallback result sheet, and Stage 6 Tetriser result defeat sheet: stage / sheet guards,
  hit-test delegation to the actor draw helper, click-consume vs restart
  classification, Stage 2 / Stage 3 Live2D boss result and Stage 4 / Stage 5 /
  Stage 6 fallback click property config, captured base-frame payloads,
  click-rect apply payloads, click-reaction apply payloads, Dalji dialogue /
  voice request flags, and Dalji click side-effect apply payloads for dialogue
  timer / voice-play requests.
- `scripts/ui/stage_clear_result_actor_click_scene_apply_handler.gd`
  Owns stage-clear result actor click scene-field apply orchestration for
  player-victory, Dalji, and current Stage 2-6 boss-result clicks: reading the
  scene's live timer / sheet / transition fields, invoking the low-level actor
  click helper, merging click-rect / reaction / Dalji side-effect field payloads,
  and carrying voice-play flags back to the scene apply boundary.
- `scripts/ui/stage_clear_result_actor_click_scene_handler.gd`
  Owns stage-clear result actor click scene glue: reading current-stage / timer
  state from the scene, resolving view size and draw scale, calling
  `stage_clear_result_actor_click_scene_apply_handler.gd` for player-victory /
  Dalji / Stage 2-6 boss-result click payloads, applying those payloads through
  the scene's shared applier, routing Dalji click voice playback through
  `stage_clear_result_audio_scene_handler.gd`, and requesting redraws. The
  input scene handler calls this scene handler directly for result actor
  clicks; the result scene should not keep actor-click pass-through wrappers,
  per-stage click wrappers, direct boss click config reads, low-level
  click-reaction payload assembly, actor click scene-field payload packaging,
  or local click apply / redraw / voice branching.
- `scripts/ui/stage_clear_result_font_cache.gd`
  Owns the stage-clear result UI font variation cache: it wraps the fallback
  font with scaled glyph spacing for compact Korean result-scroll labels and
  reuses the variation until the base font or requested spacing changes. The
  scene still owns when to request the font for a draw pass.
- `scripts/ui/stage_clear_result_actor_draw_helper.gd`
  Owns the stable public result-actor drawing facade: legacy constant names,
  reaction-state helper names, click-attempt helper names, and draw helper names
  used by presenter / click / context / reset modules. It delegates defeated
  Dalji, Stage 2 / Stage 3 boss, and player-victory Live2D implementation to
  `stage_clear_result_live2d_actor_draw_helper.gd`, and delegates Stage 4 Ponk,
  Stage 5 Hongryun, and Stage 6 Tetriser pulse fallback implementation to
  `stage_clear_result_pulse_actor_draw_helper.gd`.
- `scripts/ui/stage_clear_result_live2d_actor_draw_helper.gd`
  Owns the shared Live2D-sheet result actor contract for defeated Dalji,
  Stage 2 / Stage 3 boss result sheets, and player-victory Live2D sheets:
  frame / cell / click timing constants, click-reaction state construction,
  click hit rects, layout-helper rect resolution, reaction-sheet blending, and
  the null-sheet player-victory compatibility result.
- `scripts/ui/stage_clear_result_pulse_actor_draw_helper.gd`
  Owns the shared pulse-sheet result actor contract for Stage 4 Ponk, Stage 5
  Hongryun, and Stage 6 Tetriser: fallback sheet constants, reaction-state
  timing, click-attempt hit rects, pulse grow / ghost overlay drawing, and
  Stage-specific fallback draw wrappers. Public callers should continue using
  `stage_clear_result_actor_draw_helper.gd` unless they are extending the
  pulse fallback implementation itself.
- `scripts/ui/stage_clear_result_actor_presenter.gd`
  Owns stage-clear result actor draw orchestration for player-victory Live2D
  and defeated-boss actors: current-stage branching for Dalji / Stage 2 /
  Stage 3 / Stage 4 Ponk fallback / Stage 5 Hongryun fallback / Stage 6 Tetriser, draw-context assembly / unpacking, click-reaction state assembly,
  returning draw-time click rects, and packaging actor draw apply payloads for
  player-victory / defeated-boss click rect fields plus player drawn state. It
  also packages draw scene-field apply payloads for `_player_victory_click_rect`,
  `_dalji_click_rect`, `_stage4_ponk_result_click_rect`, and
  `_stage5_hongryun_result_click_rect`, and `_stage6_boss_defeat_click_rect`.
  It delegates low-level sheet drawing and reaction-frame math to
  `stage_clear_result_actor_draw_helper.gd`.
- `scripts/ui/stage_clear_result_actor_draw_scene_handler.gd`
  Owns stage-clear actor draw scene glue: reading live timer / reaction timer /
  transition-frame / texture / click-rect fields from the result scene,
  building player-victory and defeated-boss draw contexts through
  `stage_clear_result_actor_presenter.gd`, routing presenter scene-field apply
  payloads back through the scene's shared applier, and drawing the
  player-victory static fallback through `stage_clear_result_static_draw_helper.gd`
  when Live2D drawing is unavailable. The draw scene handler owns calling this
  scene handler; the result scene still owns stored actor draw fields but not
  actor draw fanout wrappers.
- `scripts/ui/stage_clear_result_draw_scene_handler.gd`
  Owns stage-clear result top-level `_draw()` scene glue: resolving current
  view size, preserving draw-time texture loading, resolving layout scale and
  cached font, drawing the static background / tint / dialogue / footer,
  invoking actor, box, scroll, and runtime-overlay scene handlers in the
  established back-to-front order, and keeping static draw helper calls out of
  `stage_clear_result_scene.gd`. The scene keeps only the public `_draw()` entry
  and should not keep focused `_draw_*` fanout wrapper names for actor, box,
  scroll, or runtime overlay drawing.
- `scripts/ui/stage_clear_result_actor_reaction_update_handler.gd`
  Owns result-scene actor reaction timer context assembly and advancement for
  the per-frame update loop: Dalji base-loop timer, Dalji click reaction,
  player-victory click reaction, Stage 2 / Stage 3 boss defeat click
  reactions, Stage 4 Ponk fallback pulse, Stage 6 Tetriser defeated pulse,
  and Dalji dialogue countdown clamping. It delegates reaction timer
  clamping to
  `stage_clear_result_click_reaction_state.gd`, uses actor draw helper
  duration constants, and packages actor reaction timer apply payloads plus
  scene-field apply payloads. The update scene handler owns reading live timer
  fields from the result scene, routing the per-frame update, and applying the
  returned scene-field payloads through the shared field-payload applier.
- `scripts/ui/stage_clear_result_update_scene_handler.gd`
  Owns stage-clear result per-frame scene glue: advancing the result
  timer, reading actor reaction timer fields, invoking
  `stage_clear_result_actor_reaction_update_handler.gd`, routing box and scroll
  update wrappers, synchronizing the viewport-sized Control, invoking
  `stage_clear_result_fx_host_update_handler.gd`, and requesting the redraw at
  the end of the update tick. The result scene's `_process()` and the
  screen/controller call this handler directly; public update wrappers,
  actor-reaction pass-through wrappers, and direct actor-reaction / FX-host
  update helper calls should not be reintroduced there.
- `scripts/ui/stage_clear_result_layout_helper.gd`
  Owns stateless stage-clear result layout and frame policy helpers:
  floating chest anchor layouts, result-box safe-frame selection, reward
  section card grid fitting, sheet cell source-rect calculation, and
  cover-fit source cropping, plus floating-box draw centers, hover AABBs,
  point rotation, player-victory actor / click / panel rects, Dalji draw
  rects, scroll-content margins, and cinematic-local coordinate conversion.
  The scene still owns live timers, hover / click state, drawing, texture
  loading, reward rolling, and callbacks.
- `scripts/ui/stage_clear_result_sheet_draw_helper.gd`
  Owns stateless stage-clear result sheet-frame drawing: source-rect
  calculation through the layout helper, null / alpha guards, and
  `draw_texture_rect_region` for Dalji, player-victory, and boss result
  sheets, plus base / click-reaction sheet alpha-blend drawing. The scene
  still owns which sheet pair, reaction-state dictionary, grid, cell size,
  rect, and overall alpha to draw.
- `scripts/ui/stage_clear_result_box_data.gd`
  Owns the stable public compatibility facade for stateless stage-clear
  result-box data APIs. Reward-plan box materialization, standalone preview
  defaults, legacy mythic box-kind normalization, box display labels, and
  display-label extraction are exposed here but owned by
  `stage_clear_result_box_plan_data.gd`. Reward-roll fallback selection, box
  opening setup, next-idle selection, and box opening / reward-emerge state
  transitions are exposed here but owned by
  `stage_clear_result_box_opening_data.gd`. Resolved reward-copy extraction,
  selected starpoint perk append mutation, and append apply payload packaging
  are exposed here but owned by `stage_clear_result_box_resolved_reward_data.gd`.
  Immediate reward payload assembly, granted-state marking, and callback attempt
  sequencing are exposed here but owned by
  `stage_clear_result_box_immediate_reward_data.gd`. Box hover / click / next-idle
  opening input now routes through `stage_clear_result_box_input_handler.gd`;
  opening-state update sequencing now routes through
  `stage_clear_result_box_update_handler.gd`; the scene still owns reward
  callback wiring, audio side effects, drawing, and the public result-scene box
  constants kept as compatibility aliases.
- `scripts/ui/stage_clear_result_box_immediate_reward_data.gd`
  Owns stateless immediate result-box reward mutation: building the callback
  payload from an opened box and cinematic positions, marking the stored box /
  reward as already granted, and packaging the success / miss result from the
  immediate reward callback without mutating source arrays in place. The public
  `stage_clear_result_box_data.gd` facade keeps the stable call surface for
  existing scene and helper modules.
- `scripts/ui/stage_clear_result_box_opening_data.gd`
  Owns stateless result-box opening data mutation: reward callback / fallback
  rolling, opening an idle box with a copied reward, opening with a roll-kind
  override, finding the next idle box, and advancing opening / reward-emerge
  progress with lid-open ids and just-opened indices. The public
  `stage_clear_result_box_data.gd` facade keeps the stable call surface for box
  input and update handlers.
- `scripts/ui/stage_clear_result_box_plan_data.gd`
  Owns stateless result-box plan and kind data: standalone preview reward-plan
  defaults, materializing positioned floating boxes from reward plans and layout
  slots, normalizing legacy mythic box kinds, mythic-visual kind predicates, and
  Korean fallback display labels for normal / advanced / guaranteed-mythic
  boxes. The public `stage_clear_result_box_data.gd` facade keeps the stable
  call surface for preview defaults, scene configuration, and existing box
  helpers.
- `scripts/ui/stage_clear_result_box_resolved_reward_data.gd`
  Owns stateless resolved result-box reward mutation: extracting copied rewards
  with source box kind / state metadata, appending selected starpoint perk
  rewards into a copied box array, and packaging append apply / scene-field
  payloads for redraw and box writes. The public
  `stage_clear_result_box_data.gd` facade keeps the stable call surface for the
  box scene handler and starpoint choice flow.
- `scripts/ui/stage_clear_result_preview_defaults_handler.gd`
  Owns stage-clear result standalone-preview default application decisions:
  determining when an otherwise empty result scene should receive preview data,
  requesting the preview reward-plan defaults from `stage_clear_result_box_data.gd`,
  returning an explicit apply flag plus field payload, and packaging standalone
  preview apply payloads that preserve current fields when defaults should not
  apply. It also packages standalone preview scene-field apply payloads for
  score / stage / reward-plan fields. The config scene handler owns writing the
  returned fields through the shared field-payload applier.
- `scripts/ui/stage_clear_result_runtime_object_state_handler.gd`
  Owns configure-time result scene runtime object dependency resolution:
  the canonical runtime object key list, accepting only valid Godot objects from
  configure data, rejecting non-object values, and returning null for missing
  or invalid dependencies. It also owns runtime object apply payloads that map
  canonical configure keys to result-scene private dependency field names. The
  config scene handler owns writing the returned private dependency fields; the
  focused runtime overlay scene handler owns invoking their runtime methods.
- `scripts/ui/stage_clear_result_input_router.gd`
  Owns top-level stage-clear result input context assembly and route
  classification: modal capture priority for mythic acquisition / runtime perk
  choices / treasure-hunt effects, keyboard advance / escape mapping, gamepad
  confirm / cancel mapping, mouse-motion hover / drag routing, and left-click /
  drag-release route payloads. The input scene handler owns reading live scene
  modal / drag state, invoking this router, and dispatching routed side effects.
- `scripts/ui/stage_clear_result_input_scene_handler.gd`
  Owns stage-clear result input scene glue: building router context from live
  modal overlay and scroll fields, invoking `stage_clear_result_input_router.gd`,
  cancelling scroll drags when modal capture takes over, dispatching runtime
  overlay input, advance / escape navigation, hover / drag updates, click-chain
  ordering for Dalji / boss / player / scroll / button / box clicks, and the
  fallback box-hover update when a left click hits no action. The result
  scene's `_gui_input()` and the screen/controller call this handler directly;
  public input wrappers, input context, mouse-left side effects, advance /
  escape, and button-click pass-through wrappers should not be reintroduced
  there.
- `scripts/ui/stage_clear_result_runtime_overlay_presenter.gd`
  Owns result-scene runtime overlay and modal dependency interaction policy:
  runtime-perk input forwarding, mythic acquisition input forwarding, active
  state checks for runtime perk / mythic acquisition / treasure-hunt effects,
  result-interaction blocking policy, overlay visibility checks, fallback-vs-
  runtime catalog / icon-renderer selection, and delegating final overlay draw
  calls to `runtime_perk_overlay_renderer.gd`.
- `scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd`
  Owns result-scene runtime overlay scene glue: reading the scene's live
  runtime perk / mythic / treasure-hunt dependency fields, forwarding modal
  input through the runtime overlay presenter, forwarding the current view size,
  requesting redraw after modal input, exposing active / visibility / blocking /
  draw scene-handler calls to input, context, navigation, box, scroll, and draw
  scene handlers, plus writing the starpoint-choice gate fields that block
  result input while a perk choice opens. The screen/controller should call the
  scene handler directly for starpoint gate writes; the scene still owns the
  live dependency fields and result callbacks, but should not keep focused
  runtime-overlay input/status / visibility fanout wrappers or a public
  starpoint-gate facade.
- `scripts/ui/stage_clear_result_viewport_layout.gd`
  Owns stage-clear result viewport sizing policy: detached-scene fallback size,
  current-size fallback, 1920x1080 layout-scale calculation, and synchronizing
  the result `Control` to the full visible viewport.
- `scripts/ui/stage_clear_result_viewport_scene_handler.gd`
  Owns live result-scene viewport glue: forwarding scene view-size lookups,
  current-size fallback, layout-scale lookup, and viewport sync to
  `stage_clear_result_viewport_layout.gd`. The scene keeps only compatibility
  wrapper methods for status builders and existing smoke tests; the scene and
  stage-clear result scene handlers should not call the viewport layout helper
  directly.
- `scripts/ui/stage_clear_result_scene_field_applier.gd`
  Owns stage-clear result scene-field payload application: unwrapping nested
  `field_payload` dictionaries from helper apply-results, caching valid scene
  property names, rejecting unknown field keys, and writing approved values to
  the result scene.
- `scripts/ui/stage_clear_result_field_apply_scene_handler.gd`
  Owns live result-scene field-apply glue: reading the scene's field-name lookup
  cache and delegating nested apply-results to
  `stage_clear_result_scene_field_applier.gd`. Stage-clear result scene
  handlers and focused smoke tests should route scene-field apply payloads
  through this field-apply scene handler instead of bouncing through a result
  scene `_apply_scene_apply_result()` wrapper or calling the field applier
  directly; that compatibility wrapper should not be reintroduced.
- `scripts/ui/stage_clear_result_config_reset_state_handler.gd`
  Owns configure-time result scene reset-state, reset apply payloads, and
  reset scene-field apply payloads: lid counter, starpoint gate fields, hover
  state, button rects, scroll phase / timer / drag state, scene timers, actor
  click-reaction inactive timers, reset-owned click-reaction default lookup,
  and Dalji dialogue timer.
  The config scene handler owns applying the returned values, rebuilding boxes,
  FX-pool side effects, voice cleanup, callback storage, and redraw / resource
  sync.
- `scripts/ui/stage_clear_result_config_data_state_handler.gd`
  Owns configure-time result scene data normalization: player / boss score,
  current stage, requested selected-character id, reward-plan dictionary
  validation, stage-reward snapshot dictionary validation, and config data
  apply payloads plus scene-field apply payloads with fallback handling for
  public score / stage / reward fields. The config scene handler owns applying
  the returned public fields through the shared field-payload applier, routing
  the requested character through the character asset-state handler, and
  building live result boxes from the sanitized reward plan.
- `scripts/ui/stage_clear_result_config_scene_handler.gd`
  Owns stage-clear result configure / ready / teardown scene glue: Control
  input/display setup, standalone preview default application, configure data
  normalization, selected-character asset cache invalidation, runtime object
  dependency application, box rebuilding from the sanitized reward plan,
  configure reset-state application, FX pool reset / teardown, callback storage,
  viewport sync, texture loading, audio loading / stop, redraw, runtime
  reference clearing, exit-time helper-cache nulling, result asset prewarm
  API calls, reset-owned reaction timer default facade calls, and default
  helper creation for runtime perk catalog / icon / overlay rendering, font
  cache, and result-box FX host pool. The scene keeps Godot lifecycle callbacks
  and live storage fields. The screen/controller and tests should call this
  scene handler directly for result-scene configure, asset prewarm, and
  runtime-reference cleanup; the scene should not reintroduce configure or
  static prewarm facades, direct
  configure/reset/preview / asset-apply/runtime-object helper calls, direct
  config-data / character-asset / runtime-object / reset / preview / texture /
  audio pass-through wrappers, direct asset-loader prewarm calls, helper
  constructor calls, direct actor-draw timing policy reads, inline
  reset-current-state maps, or inline exit-tree teardown.
- `scripts/ui/stage_clear_result_callback_handler.gd`
  Owns stage-clear result callback invocation policy: next-stage confirm calls,
  exit-to-menu calls, the exit fallback to confirm when no explicit exit
  callback exists, and explicit `false` plaza-entry results as a retryable
  non-success.
- `scripts/ui/stage_clear_result_callback_scene_handler.gd`
  Owns stage-clear result callback scene glue: stopping the Dalji click voice
  before navigation callbacks, reading and clearing the scene's confirm /
  plaza / exit callback fields, preserving exit-to-confirm fallback semantics,
  retaining the plaza callable when invocation returns retryable `false`, and
  delegating final callback invocation to the callback handler. The scene
  still owns callback storage and redraw state, but callback pass-through
  wrappers should not be reintroduced there.
- `scripts/ui/stage_clear_result_navigation_action_handler.gd`
  Owns stage-clear result navigation action policy: advance input while boxes
  are hidden vs scroll-visible, blocked advance consumption, escape behavior,
  next / plaza / exit scroll-button action mapping, including live
  `BUTTON_PLAZA -> ACTION_ENTER_PLAZA`, action apply payloads for handled
  vs actionless results, and scroll-button click apply payloads that preserve
  button rects while reporting the resulting action / handled state.
- `scripts/ui/stage_clear_result_navigation_scene_handler.gd`
  Owns stage-clear result navigation scene glue: reading scroll phase, querying
  modal-blocking state through the runtime overlay scene handler, building
  advance / escape / scroll-button navigation apply results through the
  navigation action handler, forwarding scroll-button layout payloads through
  the scroll scene handler, and routing final navigation actions directly
  through the box scene handler or callback scene handler. The scene keeps only
  stored scroll / box state, callbacks, and redraw surfaces; the navigation
  scene handler should not route
  actions back through the result scene's `_open_next_idle_box`, `_confirm`,
  `_enter_plaza`, `_exit_to_menu`, `_apply_scroll_button_layout`, or
  `_is_result_interaction_blocked` wrappers.
- `scripts/ui/stage_clear_result_box_input_handler.gd`
  Owns the result scene's floating-box input adapter layer: next idle box
  selection, clicked idle box classification, blocked-click consumption,
  opening-result packaging, opened-index reporting, hover-index change
  payloads, hover apply payloads, and box-open apply payloads for scene state
  writes / audio / redraw requests. It also packages common box-state apply
  payloads for box arrays, hover index fallback, consumed state, audio
  requests, and redraw requests. It delegates pure box data mutation to
  `stage_clear_result_box_data.gd` and pure box hit-test math to
  `stage_clear_result_interaction_state.gd`.
- `scripts/ui/stage_clear_result_box_update_handler.gd`
  Owns the result scene's floating-box update sequencing: applying
  `stage_clear_result_box_data.gd` opening / reward-emerge state transitions,
  collecting just-opened box indices, and routing those indices through
  `stage_clear_result_immediate_reward_helper.gd` for cinematic immediate
  reward grants. It also packages update apply payloads and scene field apply
  payloads for the live box array and lid-open counter.
- `scripts/ui/stage_clear_result_box_scene_handler.gd`
  Owns stage-clear result-box scene glue: reading live boxes, hover index,
  lid-open counter, scroll phase / timer, result-box sheet textures, reward icon
  cache, viewport scale, reward callbacks, and runtime-overlay modal blocking
  through the runtime overlay scene handler; delegating click / next-idle /
  hover policy to
  `stage_clear_result_box_input_handler.gd`; delegating opening animation and
  immediate-grant sequencing to `stage_clear_result_box_update_handler.gd`;
  delegating resolved reward extraction and starpoint-choice resolved-perk
  append payloads to `stage_clear_result_box_data.gd`;
  delegating floating-box draw orchestration and draw-context assembly to
  `stage_clear_result_box_presenter.gd`;
  applying scene-field payloads through the scene's shared applier; routing
  result-box-open SFX through `stage_clear_result_audio_scene_handler.gd`; and
  requesting redraws. Navigation, input, update, and draw scene handlers call
  this box scene handler directly; the result scene still owns live stored
  box / hover / lid-counter / texture fields, but should not keep focused box
  click / hover / update / state-apply fanout wrappers, and the box scene
  handler should not bounce interaction-block checks through the result scene
  wrapper.
- `scripts/ui/stage_clear_result_box_presenter.gd`
  Owns stage-clear floating result-box draw orchestration: iterating the live
  box array, resolving hover state by index, assembling draw context payloads,
  passing scroll reveal timing, and delegating per-box draw-context assembly
  plus final drawing to
  `stage_clear_result_box_draw_helper.gd`. The box scene handler owns live box
  state / texture / reward icon cache scene reads; the draw scene handler owns
  when to invoke floating-box drawing through the box scene handler.
- `scripts/ui/stage_clear_result_cinematic_position_helper.gd`
  Owns stateless stage-clear result cinematic position assembly for
  immediate mythic reward grants: floating result-box pickup points,
  player-victory Live2D target points, field-local conversion, and field
  clamping. The scene still owns live size / scale lookup, reward mutation,
  and the immediate-grant callback.
- `scripts/ui/stage_clear_result_box_draw_helper.gd`
  Owns stage-clear floating result-box drawing: global scroll fade, bob /
  shake / hover growth, shadow and hover FX, sheet-frame texture-region
  drawing, fallback drawing used when the authored chest sheet texture is
  unavailable, opened reward-label sequencing, source rect selection from the
  frame grid, fallback body / lid rects, open-lid easing, rim highlights, and
  canvas transform reset. It also owns result-box sheet draw constants, default
  floating-box draw context assembly, and box-kind-to-sheet texture selection.
  The box presenter owns array iteration / hover routing; the scene still owns
  loaded sheet texture storage and FX-host sync.
- `scripts/ui/stage_clear_result_scroll_state.gd`
  Owns stateless stage-clear result scroll progression helpers: hidden /
  delay / unfurling / visible phase transitions, gate-aware update
  blocking, smooth unfurl progress, fading the floating boxes behind
  the opened scroll, authored scroll region / content / drag-margin
  constants, region rect helpers, and scroll rect / drag-offset clamping
  geometry.
  The scroll update handler owns combining live box-open state with the phase
  transition helper; the scroll scene handler owns live scene-field glue for
  phase update, input, and drawing.
- `scripts/ui/stage_clear_result_scroll_update_handler.gd`
  Owns the result scene's scroll phase update sequencing: checking whether all
  floating boxes have opened via `stage_clear_result_interaction_state.gd`,
  applying gate-blocked state, and routing phase / timer transitions through
  `stage_clear_result_scroll_state.gd` with the authored delay and unfurl
  duration constants. It also packages update apply payloads and scene field
  apply payloads for the live scroll phase / timer fields. The scroll scene
  handler owns reading live scene fields, gate sources, and applying the field
  payload through the shared scene applier.
- `scripts/ui/stage_clear_result_scroll_draw_helper.gd`
  Owns stage-clear result scroll drawing helpers that are independent of
  scene state: authored cyber-scroll texture-region drawing, the fallback
  panel and top / bottom rod chrome used when the authored scroll texture is
  unavailable, plus the reward section group panel chrome inside the opened
  scroll. The scene still owns scroll texture selection and high-level
  visibility phase / rect storage.
- `scripts/ui/stage_clear_result_scroll_content_draw_helper.gd`
  Owns opened stage-clear scroll content draw sequencing: header text,
  divider, summary strip metrics, reward section grouping / empty-state
  drawing, reward-card stack draw context, and next / exit button draw calls.
  The scene still owns scroll visibility phase, live score / reward state,
  perk catalog / icon-renderer instances, and storing the returned button
  rects for input.
- `scripts/ui/stage_clear_result_scroll_presenter.gd`
  Owns stage-clear result scroll draw context assembly and draw orchestration:
  draw-time scroll-offset clamping, unfurl progress lookup, visible source rect
  construction, content reveal alpha, content rect lookup, scroll-frame draw
  delegation, opened scroll content draw delegation, and returning updated
  scroll offset plus next / exit button rects. It also owns draw-result apply
  payload packaging for the scene's scroll offset and button rect fields. The
  scroll scene handler owns the loaded scroll texture / live score / reward /
  hover scene reads, draw-context glue, and routing draw apply payloads through
  common scroll-state scene application.
- `scripts/ui/stage_clear_result_fx_host_pool.gd`
  Owns result-box open FX host pooling for the stage-clear result scene:
  host allocation, prewarm cursor advancement, active / inactive sync state,
  and teardown. The FX host update handler owns per-frame prewarm/sync
  sequencing; the update scene handler owns passing the live boxes, timer,
  scroll phase/timer, and layout scale into that helper each tick. The scene
  still owns the pool instance and pool lifecycle reset / teardown calls.
- `scripts/ui/stage_clear_result_fx_host_update_handler.gd`
  Owns per-frame stage-clear result-box FX host update sequencing: one staged
  pool prewarm step followed by active host sync with the current boxes,
  layout scale, timer, and scroll phase/timer. It is invoked by
  `stage_clear_result_update_scene_handler.gd` and delegates host allocation,
  visibility, and state payload construction to `stage_clear_result_fx_host_pool.gd`.
- `scripts/ui/stage_clear_result_interaction_state.gd`
  Owns stateless stage-clear result interaction calculations: scroll-button
  layout rects, button hover / visible-click hit classification, opened /
  opening box counts, all-boxes-open checks, and floating box hover / idle
  click hit-tests. The scene still owns
  actual input consumption, callback dispatch, hover redraw requests, live
  box mutation, and drawing.
- `scripts/ui/stage_clear_result_scroll_input_handler.gd`
  Owns the result scene's scroll-input adapter policy: refreshing visible
  next / exit button rects from scroll phase and offset, classifying scroll
  button clicks / hovers for scene callbacks, and packaging scroll drag
  start / update / finish offsets plus refreshed button / hover state. It now
  also packages hover / drag-start / drag-update / drag-finish / drag-cancel
  apply payloads plus common scene scroll-state apply payloads for button rects,
  scroll offset, drag state, grab offset, and hovered-button fallback handling.
- `scripts/ui/stage_clear_result_scroll_scene_handler.gd`
  Owns the result scene's scroll scene glue: reading live scroll phase, timer,
  boxes, texture, reward / score / hover state, offset, drag, grab, hover, and
  modal-blocking state through the runtime overlay scene handler; invoking the
  scroll-input handler for hover / drag / refresh payloads; invoking the
  scroll-update handler for phase / timer sequencing; invoking the scroll
  presenter for scroll frame / content drawing and draw-context assembly;
  applying all payloads through the shared scene-field applier; and requesting
  redraw when the handler marks a scroll input change as visible. The scene
  still owns the live scroll fields and when top-level input / update / draw
  entry points are called, but should not keep focused scroll input / update /
  state-apply fanout wrappers; the scroll scene handler should not bounce
  interaction-block checks through the result scene wrapper.
  It delegates pure geometry and hit-test math to
  `stage_clear_result_interaction_state.gd` and
  `stage_clear_result_scroll_state.gd`; the scene still owns actual confirm /
  exit callbacks, live field mutation, and `queue_redraw()` execution.
- `scripts/ui/stage_clear_result_scroll_button_draw_helper.gd`
  Owns stage-clear scroll button drawing: shared next-stage / exit button
  layout lookup, visible-phase hover coloring, button panel chrome, and
  centered button label rendering. The scene still owns scroll phase /
  hovered-button state, localized labels, button rect storage, and action
  dispatch.
- `scripts/ui/stage_clear_result_status_builder.gd`
  Owns read-only result-scene interaction-status dictionary assembly
  orchestration for smoke tests and QA probes. It accepts either
  scene-prepared state snapshots or a live scene object, adds the canonical
  `current_stage` field, and merges the actor / non-actor status payloads.
  It must not mutate boxes, timers, click-reaction state, or reward snapshots.
- `scripts/ui/stage_clear_result_status_scene_handler.gd`
  Owns the live scene glue for interaction-status probes: reading the scene
  object plus Dalji dialogue copy supplied by the caller and delegating the
  actual read-only status assembly to `stage_clear_result_status_builder.gd`.
  Tests and QA probes should call this handler directly; the scene should not
  keep a public `get_interaction_status()` facade or call the status builder
  directly.
- `scripts/ui/stage_clear_result_scene_context_builder.gd`
  Owns read-only scene snapshot collection for result interaction status:
  viewport / layout scale, box arrays, reward-summary state, perk-info
  summaries, scroll state, button / gate status, modal activity, and
  box-open audio readiness. Actor-specific snapshot collection is delegated to
  `stage_clear_result_actor_scene_context_builder.gd`; viewport values are
  routed through `stage_clear_result_viewport_scene_handler.gd`, and runtime
  perk / treasure-hunt activity is routed through
  `stage_clear_result_runtime_overlay_scene_handler.gd`. The scene still owns
  the live fields used for the snapshot, but the context builder should not
  bounce view-size, layout-scale, or overlay activity lookups through result
  scene wrapper methods.
- `scripts/ui/stage_clear_result_actor_scene_context_builder.gd`
  Owns read-only actor snapshot collection for result interaction status:
  Dalji reaction / dialogue / voice state and player-victory sheet / reaction
  state. Stage 2 / Stage 3 Live2D defeated boss snapshot collection is
  delegated to `stage_clear_result_live2d_boss_scene_context_builder.gd`;
  Stage 4 / Stage 5 / Stage 6 fallback result sheet snapshot collection is
  delegated to `stage_clear_result_fallback_actor_scene_context_builder.gd`.
  It may call asset-loader constants and actor draw-helper reaction math, but
  must not draw, load textures, or mutate scene timers.
- `scripts/ui/stage_clear_result_live2d_boss_scene_context_builder.gd`
  Owns read-only Stage 2 / Stage 3 Live2D defeated boss snapshot collection for
  result interaction status: sheet paths / load states, click-reaction sheet
  paths / load states, frame-grid metadata, reaction timers, transition frames,
  and reaction-state payloads from actor draw-helper math.
- `scripts/ui/stage_clear_result_fallback_actor_scene_context_builder.gd`
  Owns read-only Stage 4 Ponk / Stage 5 Hongryun / Stage 6 Tetriser fallback
  result sheet snapshot collection for result interaction status: sheet paths /
  load states, frame-grid metadata, click rects, reaction timers, transition
  frames, and reaction-state payloads from actor draw-helper math.
- `scripts/ui/stage_clear_result_non_actor_status_builder.gd`
  Owns non-actor interaction-status payload derivation: result-box counts,
  reward-source counts, display labels, perk-info summary, starpoint totals,
  scroll visibility / rect / drag status, button clickability, modal gates, and
  box-open audio readiness. It consumes prepared context dictionaries instead
  of reading scene fields directly.
- `scripts/ui/stage_clear_result_actor_status_builder.gd`
  Owns actor interaction-status payload orchestration plus direct Dalji and
  player-victory status derivation. Stage 2 / Stage 3 Live2D defeated boss
  status is delegated to `stage_clear_result_live2d_boss_status_builder.gd`;
  Stage 4 Ponk / Stage 5 Hongryun / Stage 6 Tetriser fallback result status is
  delegated to `stage_clear_result_fallback_actor_status_builder.gd`. It
  consumes prepared context dictionaries plus layout helper rect math; drawing
  and click-routing remain in the actor presenter / draw / click-handler owners.
- `scripts/ui/stage_clear_result_live2d_boss_status_builder.gd`
  Owns Stage 2 / Stage 3 Live2D defeated boss public interaction-status
  derivation: active-stage flags, sheet / click-reaction sheet paths and load
  states, frame-grid metadata, draw / click rects, reaction timers, transition
  frames, base frames, and reaction alpha.
- `scripts/ui/stage_clear_result_fallback_actor_status_builder.gd`
  Owns Stage 4 Ponk / Stage 5 Hongryun / Stage 6 Tetriser fallback actor public
  interaction-status derivation: active-stage flags, sheet paths and load
  states, frame-grid metadata, draw / click rects with valid-rect fallback,
  reaction timers, transition frames, base frames, and reaction alpha.
- `scripts/ui/stage_clear_result_static_draw_helper.gd`
  Owns stage-clear result static draw surfaces: result background fallback /
  cover blit, Dalji click dialogue bubble / tail / text, player-victory
  fallback panel / text / sheet frame, and footer text. The draw scene handler
  owns static background / dialogue / footer draw sequencing; the actor draw
  scene handler owns the player-victory fallback draw call. The scene still owns
  the live texture / timer / stage storage fields.
- `scripts/ui/stage_clear_result_shape_helper.gd`
  Owns stateless result-scene shape point generation and low-level
  CanvasItem draw helpers: ellipse fill polygons, ellipse polylines,
  radial burst polygons, star polygons, closed polyline conversion,
  filled ellipse / ellipse-outline / star / radial-burst drawing, StyleBoxFlat
  panel drawing, fitted texture blits, fallback reward icon primitives, plus
  result-box hover glow / sparkle geometry and drawing. Draw scene handlers /
  presenters own high-level draw sequencing, color selection, alpha gates, and
  animation timing.
- `scripts/ui/stage_clear_result_click_reaction_state.gd`
  Owns stateless result-scene click-reaction animation math shared by the
  player victory and Dalji result sheets: base frame selection, reaction
  frame selection, captured-base transition frame selection, reaction
  alpha including return hold / fade, active checks, and return-blend
  checks, plus shared click-attempt hit / restart classification. The scene
  still owns click input dispatch, timers, captured transition frames, voice
  playback, sheet textures, and actual drawing.
- `scripts/ui/stage_clear_result_summary_builder.gd`
  Owns stateless stage-clear result summary assembly for the UI scene:
  stage-vs-box reward source tagging, item / perk / visible reward arrays,
  active / passive / mythic item grouping, reward-source count payloads,
  perk-info tile payloads and their first-reward text preparation, box
  starpoint totals, display-gold / score-rating summary-strip metrics,
  stage-summary array duplication, and perk reward ID classification. The
  scene still owns reward rolling, final grant callbacks, scroll/button input,
  drawing, and passes the live perk catalog instance into the summary builder.
- `scripts/ui/stage_clear_result_summary_draw_helper.gd`
  Owns stage-clear summary strip drawing: strip tile layout, gold / score
  metric tiles, and score-rating star tiles. It delegates primitive panels,
  stars, and text to the low-level draw helpers. The scene still owns
  summary-strip placement, localized labels, and score / gold metric
  calculation inputs.
- `scripts/ui/stage_clear_result_reward_card_draw_helper.gd`
  Owns stage-clear reward card draw helpers that are independent of scene
  state: reward section-stack band / grid drawing, complete reward-card body
  assembly, reward-card base shell / badge rendering, stage-vs-box reward
  source-chip rendering, reward title plate / icon drawing, and card text
  resolution through the reward-text resolver. The scene still owns reward
  icon cache / perk icon renderer access, perk catalog instance, starpoint
  animation state, and the context values passed into card drawing. Starpoint
  primitive drawing is delegated further to
  `stage_clear_result_starpoint_draw_helper.gd`.
- `scripts/ui/stage_clear_result_reward_float_draw_helper.gd`
  Owns opened result-box floating reward draw routing: reward label visual
  state lookup, active / passive / mythic item icon disc drawing, reward icon
  texture fallback text, and starpoint visual-state dispatch through the
  shared starpoint draw helper. The scene still owns opened-box timing,
  reward icon cache storage, and box draw sequencing.
- `scripts/ui/stage_clear_result_starpoint_draw_helper.gd`
  Owns reusable stage-clear result starpoint primitive drawing: glow layers,
  star polygon body, sparkle rays, center dot, and optional amount label.
  Reward-card and floating reward helpers provide visual-state dictionaries;
  this helper owns only the CanvasItem draw primitives.
- `scripts/ui/stage_clear_result_reward_visual_resolver.gd`
  Owns stateless stage-clear reward visual classification: reward card base
  colors / rects, reward label visual state, reward item icon visual state /
  palettes, fallback reward icon state, starpoint visual state, reward badge
  text, and stage-vs-box source-chip labels / colors / rects. The scene still
  owns all actual drawing.
- `scripts/ui/stage_clear_result_reward_icon_resolver.gd`
  Owns stage-clear reward icon resolution: direct and nested icon paths,
  item-name fallback sprite paths, preloaded `icon_texture` handling, and
  scene-local texture-cache lookups / fills through `ProjectResourceLoader`.
  The scene still owns the local cache dictionary and actual icon drawing.
- `scripts/ui/stage_clear_result_reward_text_resolver.gd`
  Owns stateless stage-clear reward text resolution: direct reward label /
  detail precedence, perk description / level-description / detail fallback,
  catalog-backed perk-data duplication, perk-name title fallback, starpoint
  title formatting, and localized reward type fallback labels. The scene
  still owns the catalog instance and actual drawing.
- `scripts/ui/stage_clear_result_text_layout_helper.gd`
  Owns stateless stage-clear result text measurement and low-level
  CanvasItem text draw helpers: centered baseline calculation, word
  wrapping to width / max-lines, font-size fitting, baseline text draw,
  centered text draw, and wrapped text draw. The scene still owns
  localized copy, high-level text placement, shadow alpha choices, and
  color selection.
- `scripts/core/match_round_restart_controller.gd`
  Owns round-restart fanout below match flow: reset-ball callback dispatch
  or round-wait fallback reset, rematch notice startup, and round-restart
  audio loop cleanup. Registered as `match_round_restart_controller`.
- `scripts/core/match_reset_controller.gd`
  Owns full-game reset fanout for match flow: scoreboard/score/round
  state, HUD gauge and active-slot state, active/mythic/treasure item
  runtimes, registered player skill states, runtime skill configs and
  runtimes, Drive input callbacks, dash token reset, reset-time audio loop
  cleanup, stage skill/event/background state, and the reset-result
  dictionary consumed by `battle_scene_match_flow_driver.gd`. Registered
  as `match_reset_controller`.
- `scripts/stages/stage_runtime_router.gd`
  Owns the current stage-to-module mapping for draw/update helper roles:
  actor renderer, pillar scene drawer, and stage-background state. Core
  draw/update modules ask this router for stage-specific owners instead of
  hardcoding the Stage 1 renderer keys as new stages are ported.
- `scripts/stages/common/weather_event_state.gd`
  Owns the shared Godot weather-event state machine ported from the Python
  original: 10% round-start weather rolls, weighted 1/2/3-round durations
  with 1-round gust/sand exceptions, wind direction, warning/end messages,
  breeze/gust player/boss/ball push, fire gauge drain and hit-speed boost,
  fire-event unlimited ball-speed handoff, doubled fire paddle-hit exchange
  boost, weather debug force/cycle helpers,
  ice movement-control penalties, rain movement slow, hail
  collision knockback / dash destruction, four-side sand terrain collision /
  erosion, and harvest/force-end hooks used by weather-absorbing items such
  as Baal's Boots. Player/boss ice transition motion delegates to
  `weather_ice_motion_state.gd`. It also exposes weather particles and sand
  visual segments to the renderer; keep weather activation, registry lookup,
  dash cancellation, warp wrapping, and particle emission here rather than in draw
  code. Fire-hit explosion, hail-impact, ice-slide, sand-erosion, and
  sand-dissolve particle payload construction is delegated to
  `weather_event_payload_factory.gd`; shared fallback-render LOD budgets are
  delegated to `weather_event_render_budget.gd`.
- `scripts/stages/common/weather_ice_motion_state.gd`
  Owns allocation-free mutable player/boss ice motion: player dash-transition
  gating, 25-pixel initial slide, 0.96 decay, active-warp continuation versus
  wall stop, boss dash release/slide, and the normal 0.35 blend plus 0.975
  friction. It mutates the facade's existing result dictionary and returns only
  a slide-start signal. It does not own weather activation, registry lookup,
  dash cancellation, warp wrapping, particle payloads, RNG, audio, or drawing.
- `scripts/stages/common/weather_event_render_budget.gd`
  Owns the shared weather render-budget policy used by the state fallback draw
  and texture renderer: LOD / severe-LOD thresholds, generic weather particle
  caps, wind particle caps, particle stride values, sand stride values, and the
  sparse-wind exception that prevents index-based stride flicker for breeze /
  gust ribbons. Keep gameplay state, particle payload generation, and texture
  drawing outside this helper.
- `scripts/stages/common/weather_event_renderer.gd`
  Owns the common weather-event field VFX pass. It reads the weather state
  through public context / particle / sand-segment snapshots and draws
  layered texture pieces for rain streaks, wind ribbons, fire embers, ice
  glints, hail shards, scanline messages, and sand-wall texture fills.
  Future sprite-sheet or shader upgrades should replace this renderer's
  texture pieces without moving the gameplay rules out of the weather state
  owners; shared render-budget thresholds come from
  `weather_event_render_budget.gd`.
- `scripts/stages/common/starpoint_bonus_drop_policy.gd`
  Owns shared Star Detector bonus-drop policy for stage starpoint reward
  sources: mythic item runtime lookup through direct deps, context registry,
  or deps registry, one-call bonus-drop roll dispatch, missing-runtime
  fallback, and negative-roll clamping. Stage 1 balloon, Stage 2 golden rock,
  Stage 3 Menhera tail, and Stage 4 bird events keep their own spawn
  positions, source tags, particle counts, collection rewards, and visual
  styling, but no longer keep private Star Detector roll wrappers or mythic
  runtime lookup copies.
- `scripts/stages/common/starpoint_collection_compaction.gd`
  Owns shared modal-open starpoint drop compaction helpers for Stage 1 through
  Stage 4 collectors: in-place tail preservation for write-index loops and
  kept-array tail preservation for Stage 3's `next_drops` loop. Stage owners
  still decide when a starpoint is collected, whether a perk-choice modal
  opened, normal no-modal survivor compaction, collection rewards, particles,
  redraws, and audio.
- `scripts/stages/common/starpoint_collection_reward_policy.gd`
  Owns shared starpoint reward-collection glue for Stage 1 through Stage 4
  collectors: runtime-perk-state lookup, character / catalog / owner /
  registry payload construction, Stage 1's no-deps-registry compatibility
  mode, opened-choice return value, and owner redraw requests. Stage owners
  still own drop hit/delivery detection, collection particles, collect audio
  routing, and survivor compaction.
- `scripts/stages/common/starpoint_drop_motion_state.gd`
  Owns shared starpoint drop per-frame motion for Stage 1 through Stage 4:
  lifetime expiry, float wobble, horizontal drift / wall bounce, fall-speed
  acceleration, floor-edge culling, rotation, glow timer, and glow intensity.
  Stage owners keep spawn payloads, playfield-bound inputs, Starlight
  Tracking delivery checks, collection rewards, particles, audio, and list
  compaction.
- `scripts/stages/common/starpoint_drop_overlap_query.gd`
  Owns shared starpoint drop player-overlap queries for Stage 1 through
  Stage 4: Stage 1's rectangle-intersection collection mode, Stage 2 through
  Stage 4's circle-vs-player-rect collection mode, collect-radius scaling,
  and zero-size rect rejection. Stage owners still own player-rect source
  construction and the collection side effects after a hit is detected.
- `scripts/stages/common/starpoint_payload_factory.gd`
  Owns shared starpoint drop and pickup-particle payload construction for
  Stage 1 through Stage 4: initial drop velocity / rotation / glow fields,
  optional Star Detector size scaling, optional source tags, random-generator
  or global random compatibility, and burst particle dictionaries. Stage
  owners still own spawn positions, bonus-drop bounds clamps, particle caps,
  draw fanout, collection rewards, redraw requests, and collect audio.
- `scripts/stages/common/starpoint_particle_state.gd`
  Owns shared starpoint pickup-particle mutation for Stage 1 through Stage 4:
  position integration, gravity, alpha fade, lifetime decay, non-dictionary
  payload defense, and survivor compaction. Stage owners still own per-stage
  particle caps, draw fanout, and collection timing.
- `scripts/stages/common/stage_player_interaction_rects.gd`
  Owns shared player interaction rect assembly for stage event collision /
  collection paths: context-to-player-rect conversion, empty-base rejection,
  and Smasher Warp Gate mirror-rect expansion. Stage 1 balloon, Stage 2
  collision geometry, Stage 3 Menhera tail, and Stage 4 bird event code call
  this helper instead of carrying private Warp Gate mirror-rect copies.
- `scripts/stages/common/stage_playfield_bounds.gd`
  Owns shared playfield bounds lookup for stage event logic: left-edge
  fallback, right-edge `play_right` / `width` / default-width fallback, and
  height / default-height fallback. Stage 2 keeps a compatibility wrapper in
  `stage2_playfield_bounds.gd`; Stage 3 Menhera tail and Stage 4 bird event
  call the common helper directly for starpoint spawn clamps and drop motion
  bounds.
- `scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd` /
  `stage1_han_miryang_prologue_overlay_host.gd` /
  `stage1_han_miryang_prologue_text.gd`
  Own Han Miryang's character-select Stage 1 prologue: transient entry
  eligibility, completion history, the controller-driven viewport overlay,
  eight-plate 48-second timeline, four cropped rev6 motion layers, A-family plus
  tablet-FX startup prewarm, and B/C/D plus orb/ray/shard live streaming with
  request-time gates and transition-complete per-asset release capped at four
  resident plates plus two resident FX layers (six total), nonblocking in-flight
  detachment on skip/teardown,
  first-view versus repeat-view skip lock, skip fade, and seven-locale
  CPS-budgeted story copy. The overlay owns the 26.25-second B2-to-C1 hard cut,
  deterministic presentation-only RNG, additive FX child, camera source-rect
  motion, and label-excluding impact shake. Each character-select confirmation replays the
  prologue; completion history controls only the skip lock, while retry/debug
  direct entry stays skipped. Lore semantics and open decisions live in
  `docs/araul_foundation_prologue_canon.md`.
  Battle intro flow retains BGM and landing orchestration, while the boot
  prewarmer owns staged texture upload timing.
- `scripts/stages/stage1/stage1_pillar_background.gd`
  Owns the layered Stage 1 pillar background port: base hanji texture,
  texture loading, draw composition, and delegation to focused Stage 1
  pillar layer renderers / ambient state.
- `scripts/stages/stage1/stage1_pillar_background_assets.gd`
  Owns Stage 1 pillar-background asset metadata: layered texture resource
  paths, butterfly sheet frame / color counts, and bounded threaded prewarm
  fallback values. `stage1_pillar_background.gd` keeps texture caches,
  staged prewarm order, ambient state, and draw composition.
- `scripts/stages/stage1/stage1_pillar_ambient_state.gd`
  Owns Stage 1 pillar ambient runtime state: butterflies, wall-impact
  tree shakes, layout snapshots, and ambient update orchestration. Static
  butterfly setup, trail snapshot entries, and butterfly absorption particle
  payloads are delegated to `stage1_pillar_ambient_payload_factory.gd`.
- `scripts/stages/stage1/stage1_pillar_ambient_payload_factory.gd`
  Owns pure Stage 1 pillar ambient payload construction for idle butterflies,
  in-game butterfly trail entries, and butterfly absorption particles.
- `scripts/stages/stage1/stage1_pillar_petal_state.gd`
  Owns Stage 1 pillar ambient floating-petal runtime state: layout memory
  for pillar spawn regions, floating petal spawning, motion integration,
  lifetime trimming, and delegation to the tree-drop petal state. Floating
  petal payload construction is delegated to
  `stage1_pillar_petal_payload_factory.gd`.
- `scripts/stages/stage1/stage1_pillar_tree_drop_petal_state.gd`
  Owns Stage 1 wall-impact tree-drop petal bursts: tree-rect spawn
  positioning, burst velocity setup, gravity / sway motion integration,
  lifetime trimming, and max-count capping. Tree-drop petal payload
  construction is delegated to `stage1_pillar_petal_payload_factory.gd`.
- `scripts/stages/stage1/stage1_pillar_petal_payload_factory.gd`
  Owns pure Stage 1 pillar petal payload construction for floating ambient
  petals and wall-impact tree-drop petals.
- `scripts/stages/stage1/stage1_pillar_layer_renderer.gd`
  Owns the public Stage 1 layered-pillar draw helper API and delegates
  chrome, sprite layers, petals, butterflies, and shared geometry to
  focused Stage 1 modules.
- `scripts/stages/stage1/stage1_pillar_layer_geometry.gd`
  Owns shared Stage 1 pillar geometry helpers: side / tree rects,
  viewport clipping, sheet-region slicing, fit-to-bounds rectangles,
  texture-region blits including horizontal flip, and ellipse points.
- `scripts/stages/stage1/stage1_pillar_chrome_renderer.gd`
  Owns Stage 1 pillar chrome overlays: hanji border lines, gameplay-field
  frame outlines, lower seam line, and animated border shine.
- `scripts/stages/stage1/stage1_pillar_cloud_renderer.gd`
  Owns Stage 1 cloud sprite motion layers: cloud sheet source selection,
  side-pillar placement, drift offsets, alpha, and horizontal flip.
- `scripts/stages/stage1/stage1_pillar_tree_renderer.gd`
  Owns Stage 1 tree sprite placement and wall-impact shake offsets.
- `scripts/stages/stage1/stage1_pillar_petal_renderer.gd`
  Owns Stage 1 floating petals and wall-impact tree-drop petal drawing.
- `scripts/stages/stage1/stage1_pillar_butterfly_renderer.gd`
  Owns Stage 1 butterfly sprite animation, side placement, color rows,
  wing frame selection, and scale.
- `scripts/stages/stage1/stage1_fallback_pillar_renderer.gd`
  Owns the procedural Stage 1 pillar fallback used when the layered
  image-backed background cannot draw: silk panels, border bands,
  gameplay-border fallback chrome, and delegation to the panel ornament /
  frame motif renderers.
- `scripts/stages/stage1/stage1_fallback_panel_ornament_renderer.gd`
  Owns procedural Stage 1 fallback panel ornaments: flowers, branches,
  butterflies, and falling petals drawn over the silk side panels.
- `scripts/stages/stage1/stage1_fallback_frame_motif_renderer.gd`
  Owns procedural Stage 1 fallback frame motifs: thunder marks along the
  gameplay border and corner flower ornaments scaled from live field
  geometry.
- `scripts/stages/stage1/stage1_pillar_scene_drawer.gd`
  Owns Stage 1 outer-scene pillar composition: layered/fallback pillar
  background draw selection and delegation to the Stage 1 pillar HUD scene
  drawer. It also exposes the post-playfield pillar HUD pass so active-item
  cooldown rings and boss skillcard hover tooltips can extend above their
  trays without being covered by the central playfield background.
  `battle_scene_drawer.gd` keeps the high-level draw order and passes the
  viewport/game layout snapshot.
- `scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd`
  Owns Stage 1 outer-scene HUD composition ordering and left/right pillar
  HUD context assembly. It delegates top mini-scoreboard, pillar HUD, and
  post-playfield active-item / boss-skill HUD context assembly to focused
  scene drawers.
- `scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd`
  Owns Stage 1 scene-facing top mini-scoreboard draw context assembly:
  live score snapshot lookup, deuce flag forwarding, sparkle timing, and
  handoff to the shared scoreboard renderer.
- `scripts/stages/stage1/stage1_active_item_hud_scene_drawer.gd`
  Owns Stage 1 scene-facing active-item HUD draw context assembly: active
  slot list normalization, bottom HUD layout build, round-start timing,
  and handoff to the active-item HUD renderer.
- `scripts/stages/stage1/stage1_actor_renderer.gd`
  Owns the public Stage 1 playfield / actor draw entry point and preserves
  the actor draw order. It delegates court / trail, Smasher, and boss
  drawing to focused Stage 1 renderer modules. Actor animation timers live
  in `actor_animation_state.gd`, and gameplay state reaches this renderer
  through draw-context snapshots.
- `scripts/stages/stage1/stage1_commando_firearm_renderer.gd`
  Owns the Stage 1 transitional Commando firearm VFX presentation:
  projectile, muzzle-flash, impact-flash, base-slot pistol bullet,
  pistol / AK-47 shell-casing, pistol headshot / legshot feedback text,
  support-marker, fire-support aircraft motion trails / shadows,
  tuned compact fire-support aircraft draw size, wall-missile smoke tails /
  launch flashes, imagegen fire-support bomb projectile texture projection,
  fire-support airstrike grenade-explosion texture-layer accounting, net,
  rocket, trap, installed
  bowling-trap, captured-ball, and drone feedback
  from actor draw context. Muzzle flashes, impact flashes, support markers, and
  lingering fields now add cached glow / burst / sparkle / ring texture-piece
  layers before the direct detail strokes and sync a playfield-local
  `CommandoFirearmFxHost` for shader / `GPUParticles2D` / Tween glow and
  spark density. The renderer's deferred host attach path keeps the first
  pre-tree active sync alive through `_ready()` and hides the host when the
  firearm VFX context goes empty. The renderer also exposes a visual identity
  report that audits the eight Commando firearm families against distinct
  silhouette / FX layers such as aimed bullet, brass casing, rocket smoke,
  harpoon rope, aircraft marker, bomb projectile, trap claw, and drone rotor.
  Direct draw remains the fallback/detail layer while the host carries the
  Godot-native remaster path.
- `scripts/stages/stage1/stage1_commando_firearm_assets.gd`
  Owns the Stage 1 Commando firearm renderer asset manifest: projectile /
  trap / fire-support texture paths, texture-load warning text, sprite-sheet
  frame metadata, and visual-family QA lists. The renderer keeps public cache
  fields, prewarm step sequencing, draw layout, and FX-host sync.
- `scripts/stages/stage1/stage1_commando_firearm_fx_host.gd`
  Owns the node-backed Stage 1 Commando firearm FX host: a `ShaderMaterial`
  core glow, muzzle and impact `GPUParticles2D` layers, shared procedural
  texture-piece prewarm, playfield-local anchor selection, shake-offset
  application, pre-tree sync preservation, and pulse `Tween` lifecycle.
- `scripts/stages/common/stage_boss_variant_catalog.gd`
  Owns the non-tower Stage 2 / Stage 3 boss-variant identity boundary:
  canonical variant id, stage membership, player-facing Korean name, codex
  key, default headline boss, and fail-closed normalization. It does not own
  Tower Ascent slot or stand-in mapping.
- `scripts/stages/stage2/stage2_boss_variant_skill_state.gd`
  Owns Stage 2 boss-variant dispatch while preserving
  `stage2_boss_skill_state.gd` as the unchanged Cheongringwi implementation.
  Variant states implement the same update, contact, AI, HUD, actor-context,
  reset, and score-event surface consumed by the production battle modules.
- `scripts/stages/stage2/stage2_molewang_boss_state.gd`
  Owns Molewang's frozen-Python-parity gameplay kit: hit-gauge routing,
  Tunnel Raid sequence and locked-target strike, Spinning Claw contact
  activation, and the two-round golden friend-mole event. Tunnel Raid keeps
  the shared boss AI mobile because the frozen Python call path has no
  tunnel-phase movement lock; only its boss presentation tunnels while the
  warning endpoint retargets the live player (GRT-052/GRT-053).
- `scripts/stages/stage2/stage2_variant_boss_renderer.gd`
  Owns original-procedural Stage 2 variant boss and skill presentation. The
  Stage 2 actor renderer remains the production draw-order owner and delegates
  only the selected variant boss lane here.
- `scripts/stages/stage2/stage2_pillar_assets.gd`
  Owns the Stage 2 pillar-background asset surface: the six imagegen
  texture `res://` paths (`BASE`, `TREE`, `GAME_FRAME`, `LEAF`, `ROCK`,
  `ROCK_DEBRIS`), measured static source-region constants
  (`TREE_SOURCE_REGION_DATA`, `LEAF_SOURCE_REGION_DATA`,
  `GAME_FRAME_SOURCE_HOLE`), the rock atlas grid sizes
  (`ROCK_ATLAS_COLUMNS` / `ROCK_ATLAS_ROWS`), and the pure
  `slice_alpha_atlas_regions(path, columns, rows, padding)` helper that
  trims each cell of a packed atlas to its alpha bounds with a small
  padding margin. No runtime state. `stage2_pillar_asset_state.gd` consumes
  this immutable catalog for loading and cache population.
- `scripts/stages/stage2/stage2_pillar_asset_state.gd`
  Retained mutable owner for the six Stage 2 pillar textures, synchronous
  first-draw fallback loading, one-texture-at-a-time threaded prewarm progress
  and completion latch, measured tree / leaf / rock / debris region caches,
  and the game-frame source-hole cache. Completed prewarm is idempotent, and
  an early hole query cannot cache an empty result before the frame texture
  exists. The background retains ambient-layout preparation, renderer fanout,
  asset-status publication, and compatibility properties without duplicate
  texture or prewarm-progress storage.
- `scripts/stages/stage2/stage2_pillar_background.gd`
  Owns the Stage 2 outer-pillar background slice: the original Python
  imagegen jungle/cyber presentation, ambient falling-leaf sheet, and firefly
  layer, with the procedural jungle-panel fallback kept only for missing
  assets. The immutable asset catalog lives in `stage2_pillar_assets.gd`, and
  retained texture / region / prewarm state lives in
  `stage2_pillar_asset_state.gd`; the background exposes compatibility
  properties while delegating actual storage and loading. Imagegen base
  cover, split left / right tree sprites, unified edge lines, and stretch-
  composed moss / leaf game-frame drawing are delegated to
  `stage2_pillar_imagegen_renderer.gd`; imagegen pillar renderer asset
  payloads are delegated to `stage2_pillar_imagegen_assets_builder.gd`;
  imagegen asset-ready snapshots are delegated to
  `stage2_imagegen_asset_status_builder.gd`. It retains the shared
  `trigger_tree_shake()` facade and wall-feedback draw fanout while
  `stage2_wall_reaction_coordinator.gd` owns the flash / bush-leaf reaction.
  Rock generation, base lifetime, and quake-drop / landing side effects are
  delegated to `stage2_rock_lifecycle_coordinator.gd`; contact traversal is
  delegated to `stage2_rock_interaction_coordinator.gd`. Reverse frame
  traversal, expiry / Chaos removal, destruction feedback / reward / result
  ordering, visual timers / offsets, and fragment advancement are delegated to
  `stage2_rock_frame_coordinator.gd`. The background keeps the frame position,
  public facades, collision / reward entry points, and drawing.
  Ordinary quake activation, rock-cap / zero-request gating, post-quake water-
  cannon scheduling, timing feedback / audio sync, ball motion / restore,
  boss-launch backstop behavior, and round cleanup are delegated to
  `stage2_quake_coordinator.gd`. Water-cannon target selection, charge / fire
  progression, trails, and fragment-hit fanout are delegated to
  `stage2_water_cannon_coordinator.gd`; impact side effects live in its focused
  impact coordinator. The background retains compact playfield boss-skill
  warning rendering, falling quake-rock presentation / landed-only collision,
  crisis-score rage reservation, round-start boss stomp presentation,
  rage actor tint / offset draw context, defensive rock-wall drops, target
  rock removal, golden-rock starpoint drops / Star Detector bonus spawn
  handoff, and the boss score-expression API exposed to the Stage 2 actor /
  playfield renderers. The short-lived boss score-expression state is
  delegated to `stage2_boss_expression_state.gd`. Actor draw-context payload
  construction is delegated to `stage2_actor_draw_context_builder.gd`.
  Base boss-AI context payload construction is delegated to
  `stage2_boss_ai_context_builder.gd`. Boss-rage snapshots are delegated
  to `stage2_boss_rage_snapshot_builder.gd`; boss-rage crisis reservation,
  pending / active lifecycle, timer, stomp latch/count, AI mode, and tint /
  offset visual state are delegated to the retained
  `stage2_boss_rage_state.gd` owner; cached pre-rally audio, start / stomp
  feedback, final-stomp ordering, and quake-loop audio fallback are delegated
  to `stage2_boss_rage_coordinator.gd`. BattlePerf overlay /
  obstacle counter label writes are delegated to
  `stage2_perf_counter_recorder.gd`.
  Rock / rock-fragment /
  starpoint particle and drop drawing is delegated to
  `stage2_pillar_obstacle_visual_renderer.gd`; starpoint drop / particle
  collection storage, atomic reset, append, counts, and deep drop snapshots
  are delegated to retained `stage2_starpoint_runtime_state.gd`; shared-RNG
  spawn, motion, collection, feedback, particle updates, and stage-exit host
  cleanup are delegated to `stage2_starpoint_coordinator.gd`; water-cannon target rings,
  trail, charge / beam, splash, and player-hit flash drawing are delegated
  to `stage2_water_cannon_visual_renderer.gd`; player-hit flash timer
  state is delegated to `stage2_fragment_hit_flash_state.gd`;
  quake-wave and skill-warning
  banner drawing is delegated to `stage2_warning_visual_renderer.gd`;
  quake-wave renderer visual-state payloads are delegated to
  `stage2_quake_wave_visual_state_builder.gd`; quake screen-shake offset
  calculation is delegated to `stage2_quake_screen_shake_state.gd`;
  quake ball-motion impulse / player-pull / speed-cap / boss-launch guard
  math is delegated to `stage2_quake_ball_motion_state.gd`;
  quake cast timing, legacy cooldown, ball-velocity backup / restore,
  screen / ball motion RNGs, loop-audio active latch, and boss-launch guard
  state are delegated to `stage2_quake_runtime_state.gd`;
  quake loop and boss-rage cry audio routing is delegated to
  `stage2_audio_router.gd`;
  skill-warning timer / text state is delegated to
  `stage2_skill_warning_state.gd`;
  border-flash and boss-rage screen tint drawing is delegated to
  `stage2_screen_overlay_visual_renderer.gd`; side-wall reaction resolution,
  border-flash lifetime, and bush-band ambient burst orchestration are
  delegated to `stage2_wall_reaction_coordinator.gd`, which retains
  `stage2_border_flash_state.gd`;
  falling-leaf / firefly / leaf-particle and rustle vegetation drawing is
  delegated to `stage2_ambient_visual_renderer.gd`.
  Ambient leaf / firefly / leaf-particle payload generation is delegated
  to `stage2_ambient_payload_factory.gd`; ambient layout freshness,
  initial population, and falling-leaf spawn cadence helpers are delegated
  to `stage2_ambient_layout_helper.gd`; ambient visual count snapshots are
  delegated to `stage2_ambient_visual_snapshot_builder.gd`;
  ambient RNG, time / excitement, layout cache, falling-leaf / firefly /
  leaf-particle collections, spawn cadence, caps, and per-frame motion are
  delegated to the retained `stage2_ambient_visual_state.gd` owner;
  rustle bush / vine layout payload generation is delegated to
  `stage2_rustle_payload_factory.gd`; live rustle collections, layout cache,
  boss / player paddle history, trigger / decay mutation, and active checks
  are delegated to retained `stage2_rustle_state.gd`; Stage 2 gating, current-
  position / dash interpretation, boss bush / vine versus player bush routing,
  and trigger-before-decay order are delegated to
  `stage2_rustle_coordinator.gd`. The state's pure side-wall band predicate is
  consumed by the wall-reaction coordinator; rustle active-count snapshots are
  delegated to `stage2_rustle_snapshot_builder.gd`.
  Rock visual payload generation is delegated to
  `stage2_rock_visual_factory.gd`; rock renderer asset payloads are
  delegated to `stage2_rock_visual_assets_builder.gd`; rock collection
  storage / reset, next-id claims, common list mutation / snapshots, and
  short-lived visual timers / water-target flash mutation are delegated to
  retained `stage2_rock_runtime_state.gd`; rock dictionary
  lookup / landed / center / target queries are delegated to
  `stage2_rock_query.gd`; ball / blade / explosion / pistol contact
  orchestration is delegated to `stage2_rock_interaction_coordinator.gd`;
  quake / crisis generation, retained insertion / id ordering, spawn
  feedback, finite-life expiry, and quake-drop / landing mutation are
  delegated to `stage2_rock_lifecycle_coordinator.gd`, which consumes the
  following spawn / payload / drop helpers;
  quake-rock random spawn batches are delegated to
  `stage2_quake_rock_spawn_factory.gd`; spawn payload assembly is delegated to
  `stage2_quake_rock_payload_factory.gd`; boss-rage crisis-wall rock payload
  assembly is delegated to `stage2_crisis_rock_wall_payload_factory.gd`;
  quake-rock drop / bounce state
  updates are delegated to `stage2_quake_rock_drop_state.gd`; quake-rock
  visual offset decay / shake state is delegated to
  `stage2_quake_rock_offset_state.gd`;
  rock-fragment payload generation is delegated to
  `stage2_rock_fragment_payload_factory.gd`; normal rock-fragment factory
  config payloads are delegated to
  `stage2_rock_fragment_payload_config_builder.gd`; rock-fragment collection
  storage, reset, newest-window caps, and per-frame motion / compaction are
  delegated to retained `stage2_rock_fragment_motion_state.gd`.
  The Stage 2 starpoint coordinator consumes common payload, bonus, motion,
  overlap, Dowsing, Starlight Tracking, reward, compaction, and particle-state
  helpers without rebuilding their policies in the background facade.
  Water-cannon post-quake delay plus charge / fire / cancel lifecycle state is
  delegated to `stage2_water_cannon_runtime_state.gd`; completed-impact
  ordering is delegated to `stage2_water_cannon_impact_coordinator.gd`;
  target selection / tracking, cast-event routing, trail timing, water-visual
  advancement, and fragment-hit fanout are delegated to
  `stage2_water_cannon_coordinator.gd`;
  fragment / splash payload generation is delegated to
  `stage2_water_cannon_payload_factory.gd`; water-cannon factory config
  payloads are delegated to
  `stage2_water_cannon_payload_config_builder.gd`; water-cannon renderer
  visual-state payloads are delegated to
  `stage2_water_cannon_visual_state_builder.gd`; water-cannon start-point
  geometry and context-to-start-point assembly is delegated to
  `stage2_water_cannon_geometry.gd`; water-trail
  payload generation is delegated to `stage2_water_trail_payload_factory.gd`;
  water-trail / splash collection storage, reset, newest-window caps,
  per-frame motion / compaction, and deep splash snapshots are delegated to
  retained `stage2_water_visual_state.gd`. Stage 2
  performance sample accumulation and opt-in logging is delegated to
  `stage2_perf_logger.gd`; performance log contextual snapshots are
  delegated to `stage2_perf_log_snapshot_builder.gd`; render-budget array
  trimming, recent-entry start indexes, and LOD count decisions are delegated
  to `stage2_render_budget_helper.gd`; visible-effect / playfield draw-gate
  and boss movement-lock boolean composition is delegated to
  `stage2_visibility_state.gd`.
  Stage 2 ball / player overlap geometry and context-to-player-rect helpers are delegated to
  `stage2_collision_geometry.gd`; Chaos Spear refresh center / timer, pending
  destroyed-rock result queue / single-drain semantics, and pure pull math are
  delegated to retained `stage2_chaos_rock_absorb_state.gd`. Session timing,
  landed-rock activation, splash compaction, motion stepping, and absorbed
  payload publication are delegated to
  `stage2_chaos_rock_absorb_coordinator.gd`; playfield bounds lookup is
  delegated to `stage2_playfield_bounds.gd`.
  The original center-field bush / vine visual rustle now lives in
  `stage2_playfield_renderer`.
- `scripts/stages/stage2/stage2_render_budget_helper.gd`
  Owns stateless Stage 2 render-budget helpers: capped-array trimming,
  newest-entry start-index calculation, `BattleRenderQuality` effect-scale
  lookup, LOD threshold checks, LOD / severe-LOD count selection, and render
  budget status payload construction.
  `stage2_pillar_background.gd` keeps render call sites, live arrays,
  threshold constants, and wrapper names used by existing smoke tests.
- `scripts/stages/stage2/stage2_perf_counter_recorder.gd`
  Owns stateless Stage 2 BattlePerf counter label writes for playfield
  overlay and obstacle lanes. `stage2_pillar_background.gd` keeps the live
  array counts, active-state predicates, draw-pass gates, and timing labels.
- `scripts/stages/stage2/stage2_visibility_state.gd`
  Owns stateless Stage 2 visibility and lock predicates: overall visible
  effect presence, playfield overlay draw gates, playfield obstacle draw
  gates, and boss movement-lock checks from already-resolved state values.
  `stage2_pillar_background.gd` keeps live arrays, timer / phase mutation,
  state object ownership, and public wrapper names used by drawers and smoke
  tests.
- `scripts/stages/stage2/stage2_pillar_imagegen_renderer.gd`
  Owns the stateless Stage 2 imagegen pillar draw pass: cover-fitting the
  base PNG, unified translucent viewport edge lines, clipped left / right
  tree placement, and stretch-composed game-frame pieces using the source
  hole measured in `stage2_pillar_assets.gd`. It receives textures and
  source regions from `stage2_pillar_background.gd` and does not own
  texture loading, ambient particles, rocks, boss-skill state, or gameplay
  mutation.
- `scripts/stages/stage2/stage2_pillar_imagegen_assets_builder.gd`
  Owns the read-only Stage 2 imagegen pillar renderer asset payload: base
  texture, tree texture / source regions, game-frame texture, and the
  measured game-frame source hole. The retained asset state owns loading and
  caches; the background module owns renderer handoff.
- `scripts/stages/stage2/stage2_imagegen_asset_status_builder.gd`
  Owns the read-only Stage 2 imagegen asset status payload: base, tree,
  game-frame, leaf, rock, and rock-debris readiness booleans. The
  retained asset state owns texture loading, source-region storage, and the
  synchronous draw fallback; the background publishes the status facade.
- `scripts/stages/stage2/stage2_perf_logger.gd`
  Owns Stage 2 opt-in performance logging: environment / flag enable
  checks, sample timing, accumulation, interval throttling, and log-line
  formatting. `stage2_pillar_background.gd` still owns the measured call
  sites and passes a read-only state snapshot for contextual counters.
- `scripts/stages/stage2/stage2_perf_log_snapshot_builder.gd`
  Owns the read-only Stage 2 performance log context payload: stage id,
  rock / fragment / water counts, quake timer, boss-rage flag, water-cannon
  phase, and skill-warning kind. The background module still owns measured
  call sites, live gameplay arrays, and the actual logger invocation.
- `scripts/stages/stage2/stage2_collision_geometry.gd`
  Owns Stage 2 stateless collision geometry helpers: ball segment vs rock
  circle checks, circle-vs-player-rect checks, first overlapping rect
  lookup, and compatibility wrappers for context-to-player-rect assembly /
  Warp Gate mirror interaction rect expansion delegated to
  `scripts/stages/common/stage_player_interaction_rects.gd`.
  `stage2_pillar_background.gd` still owns collision timing, rock HP
  mutation, starpoint collection, water-fragment hit effects, and status
  immunity handling.
- `scripts/stages/stage2/stage2_playfield_bounds.gd`
  Owns the Stage 2 compatibility wrapper for stateless playfield bounds
  lookup, delegating left / right / height fallback policy to
  `scripts/stages/common/stage_playfield_bounds.gd`.
  `stage2_pillar_background.gd` still owns starpoint bonus spawn clamp,
  drop physics, collection, and reward routing.
- `scripts/stages/stage2/stage2_pillar_obstacle_visual_renderer.gd`
  Owns the stateless Stage 2 obstacle reward draw pass for background-owned
  runtime dictionaries: crisis / quake rocks, rock debris sprites,
  procedural rock fallback shapes, golden-rock glow, starpoint particles,
  and starpoint drop glyphs. It receives live arrays plus texture atlas
  references from `stage2_pillar_background.gd`; it does not spawn,
  update, collide, collect, score, or trigger audio.
- `scripts/stages/stage2/stage2_rock_visual_assets_builder.gd`
  Owns the read-only Stage 2 rock renderer asset payload: rock / debris
  textures, atlas source regions, and the default rock-fragment lifetime.
  The retained asset state owns texture / region caches and staged prewarm;
  the background module owns live rock arrays and renderer fanout.
- `scripts/stages/stage2/stage2_quake_rock_payload_factory.gd`
  Owns Stage 2 quake-rock spawn payload assembly: falling start position,
  target position, stagger frames, gravity / bounce fields, radius, seed /
  phase metadata, and merging visual data. The rock lifecycle coordinator
  consumes the payload and owns insertion, leaf bursts, and spawn audio.
- `scripts/stages/stage2/stage2_quake_rock_spawn_factory.gd`
  Owns Stage 2 random quake-rock spawn batches: target candidate selection,
  spacing retry against existing / newly-spawned rocks, size / fall-height /
  seed / golden rolls, visual payload handoff, sequential rock-id assignment,
  and next-id return. The rock lifecycle coordinator owns live array insertion,
  leaf bursts, next-id publication, and spawn audio.
- `scripts/stages/stage2/stage2_crisis_rock_wall_payload_factory.gd`
  Owns Stage 2 boss-rage crisis-wall rock payload assembly: lane target
  selection, falling start position, scaled collision radius, drop stagger /
  timer fields, seed / phase metadata, and rock visual data merging. The rock
  lifecycle coordinator owns live insertion, rock-id allocation, water-cannon
  cancellation / deferral, leaf bursts, and spawn audio; the rage owner and
  rage coordinator retain wall activation and warnings.
- `scripts/stages/stage2/stage2_quake_rock_drop_state.gd`
  Owns Stage 2 quake-rock drop and bounce mutation helpers for both the
  original frame-stepped falling rocks and timed drop payloads. The rock
  lifecycle coordinator owns target lookup and landing leaf feedback; the rock-
  frame coordinator owns list iteration and calls this policy, the background
  retains renderer fanout, and the retained quake runtime state owns cast
  timing.
- `scripts/stages/stage2/stage2_quake_rock_offset_state.gd`
  Owns Stage 2 quake-rock visual offset state: inactive offset decay, active
  quake intensity tapering, size / falling scale, and deterministic
  sinusoidal offset composition. The retained quake runtime state owns timers;
  the rock-frame coordinator owns list iteration and offset calls, while the
  background retains rock-center renderer fanout.
- `scripts/stages/stage2/stage2_water_cannon_visual_renderer.gd`
  Owns the stateless Stage 2 water-cannon draw pass: target-rock
  highlight rings, beam charge / firing visuals, water trail circles,
  stone / water splash presentation, and the red fragment-hit screen
  flash. It receives the runtime-state-owned phase / timer / target
  dictionary and the existing rock-debris visual renderer for imagegen
  stone fragments; it does not select targets, advance timers, spawn
  fragments, collide with the player, cancel skills, or trigger audio.
- `scripts/stages/stage2/stage2_water_cannon_visual_state_builder.gd`
  Owns the read-only Stage 2 water-cannon renderer state payload: phase,
  start / target / current beam points, progress, timer, charge duration,
  and trail lifetime. The retained runtime state owns lifecycle values; the
  water-cannon coordinator owns target selection and trail requests, while the
  background keeps retained-state projection and renderer handoff.
- `scripts/stages/stage2/stage2_water_cannon_runtime_state.gd`
  Retained mutable owner for the Stage 2 background water-cannon cast:
  legacy post-quake delay, idle / charging / firing phase, timer, target id,
  live muzzle / target / beam points, normalized progress, duplicate-activation
  guard, charge-to-fire transition, trail-sample / completion events, cancel,
  and reset. This is deliberately separate from
  `stage2_boss_skill_state.gd`'s boss-scheduler cooldown. The water-cannon
  coordinator keeps random rock selection, target tracking / flash mutation,
  charge / fire event routing, and trail spawning. The background keeps
  renderer handoff and compatibility properties without a second mutable state
  copy. Completed-impact side effects are delegated to the impact coordinator.
- `scripts/stages/stage2/stage2_water_cannon_coordinator.gd`
  Borrows the shared Stage 2 RNG and owns target selection, live boss-muzzle /
  rock-center tracking, target flash, idle-delay activation, fire warning ->
  hydro audio -> early-return ordering, trail append timing, visual collection
  advancement, missing-target / boss-hit cancellation, and ordered fragment
  resolver-to-player-hit-applier fanout. Construction and configuration do not
  consume RNG. The pillar background retains frame-loop positions, rendering,
  public compatibility facades, and completion-only starpoint callback binding;
  the focused impact coordinator retains completed-impact side effects. This
  owner is registered in `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_water_cannon_impact_coordinator.gd`
  Owns Stage 2 completed water-cannon impact orchestration in production order:
  target-id validation and missing-target cancel, target-rock removal, capped
  water payload append, normal rock-fragment and leaf feedback requests,
  golden-reward callback timing, impact shake, size-aware break audio,
  fragment-warning publication, and final retained beam cancellation. The
  water-cannon coordinator retains activation / active-beam event routing,
  trail spawn, and player-fragment fanout. The pillar background retains
  rendering and the completion-time starpoint payload callback.
- `scripts/stages/stage2/stage2_water_cannon_geometry.gd`
  Owns the stateless Stage 2 water-cannon geometry helper for deriving the
  boss muzzle / start point from boss position and hitbox size, including
  the context-to-start-point adapter. The water-cannon coordinator owns target
  selection and live geometry requests; the background keeps renderer handoff,
  while the retained runtime state owns phase and beam-point lifecycle.
- `scripts/stages/stage2/stage2_fragment_hit_flash_state.gd`
  Owns Stage 2 water-fragment player-hit flash state: duration, active
  timer, reset, trigger, and decay. The water-fragment player-hit applier owns
  hit-time trigger requests; `stage2_pillar_background.gd` retains reset and
  passes timer values to `stage2_water_cannon_visual_renderer.gd`.
- `scripts/stages/stage2/stage2_water_fragment_hit_resolver.gd`
  Owns Stage 2 water-fragment player-hit candidate resolution: hit-enabled
  filtering, per-splash cooldown decay, collision radius selection, first
  overlapping player rect lookup, and hit result fanout. Hit payload
  dictionaries are delegated to
  `stage2_water_fragment_hit_payload_factory.gd`. The water-cannon coordinator
  owns player-rect context assembly and resolver fanout; resolved-hit
  consumption, immunity, feedback, audio, and knockback are delegated to the
  player-hit applier.
- `scripts/stages/stage2/stage2_water_fragment_player_hit_applier.gd`
  Owns Stage 2 resolved water-fragment response: valid-index gating, mandatory
  fragment consumption / cooldown before immunity, Cleanse short-circuit,
  Celestial Armor lookup / source payload, flash / shake / particle / rock-hit
  audio order, zero-horizontal-velocity direction fallback, and the shipped
  knockback speed / duration / decay / replacement request. It is registered
  in `gameplay_stage_module_catalog.gd`; the water-cannon coordinator retains
  only player-rect assembly and resolver-to-applier fanout.
- `scripts/stages/stage2/stage2_water_fragment_hit_payload_factory.gd`
  Owns pure Stage 2 water-fragment hit payload construction for resolver
  outputs consumed by `stage2_water_cannon_coordinator.gd`.
- `scripts/stages/stage2/stage2_water_trail_payload_factory.gd`
  Owns Stage 2 water-cannon trail payload construction: randomized offset,
  life fields, radius scaling by beam progress, and trail color. The
  retained water visual state owns live trail append / cap; the water-cannon
  coordinator owns spawn timing and payload requests, while the background
  keeps renderer fanout.
- `scripts/stages/stage2/stage2_water_visual_state.gd`
  Retains the mutable Stage 2 water-cannon trail / splash collections and owns
  reset, newest-window append caps, trail lifetime compaction, splash lifetime,
  gravity, damping, position, spin, in-place survivor compaction, and deep
  splash snapshots. The separate retained cannon runtime state owns phase
  timing; the water-cannon coordinator owns trail spawn timing, player-rect
  assembly, trail payload requests, and per-frame advancement. The background
  keeps absorption and renderer fanout. Resolved player-hit responses live in
  the player-hit applier; completed-impact splash requests and rewards are
  owned by the impact coordinator.
- `scripts/stages/stage2/stage2_water_cannon_payload_factory.gd`
  Owns Stage 2 water-cannon impact payload construction: stone fragment
  dictionaries, water splash dictionaries, sprite-index selection, and
  initial velocity / radius / gravity / life fields.
  The retained water visual state owns splash-list append / cap;
  `stage2_water_cannon_impact_coordinator.gd` owns impact-time requests,
  target removal, warning / audio / reward ordering, while the water-cannon
  coordinator keeps later player collision / knockback routing.
- `scripts/stages/stage2/stage2_water_cannon_payload_config_builder.gd`
  Owns the read-only Stage 2 water-cannon factory config payload: stone
  fragment / water splash counts, lifetimes, and gravity values. The
  retained water visual state owns list caps and per-frame splash update; the
  impact coordinator owns the constants and completed-impact lifecycle; the
  water-cannon coordinator keeps later collision / knockback routing.
- `scripts/stages/stage2/stage2_warning_visual_renderer.gd`
  Owns the stateless Stage 2 warning draw pass: quake-wave line ribbons
  and the compact boss-skill warning banner. It receives timer / duration /
  kind / text dictionaries from `stage2_pillar_background.gd`; it does not
  trigger warnings, advance timers, affect ball physics, or mutate stage
  state.
- `scripts/stages/stage2/stage2_quake_wave_visual_state_builder.gd`
  Owns the read-only Stage 2 quake-wave renderer state payload: timer,
  duration, ball-affecting vs visual-only state, and normal / visual-only
  wave count and segment constants. The retained quake runtime state owns
  lifecycle values; the quake coordinator owns ball-scene mutation, audio
  handoff, and screen-shake feedback, while the background keeps renderer
  handoff.
- `scripts/stages/stage2/stage2_quake_screen_shake_state.gd`
  Owns Stage 2 quake screen-shake offset calculation from quake timer,
  duration, and the injected motion RNG. The retained quake runtime state owns
  lifecycle timing plus the RNG instance / seed; the quake coordinator owns
  feedback dispatch, audio handoff, and ball-scene mutation.
- `scripts/stages/stage2/stage2_quake_ball_motion_state.gd`
  Owns Stage 2 quake ball-motion stateless helpers: impulse-scale tapering,
  player-center pull, original speed-cap enforcement, and boss-launch guard
  safety-band / minimum downward-speed math. The retained quake runtime state
  owns cast lifecycle, first-write ball-velocity backup / restore, boss-launch
  guard timer storage, and bounded ball-shake RNG sampling; the quake
  coordinator owns impulse scaling and scene mutation timing.
- `scripts/stages/stage2/stage2_quake_runtime_state.gd`
  Retained mutable owner for the Stage 2 background quake cast: timer,
  duration, legacy repeat cooldown, ball-affecting vs visual-only flag,
  first-write velocity backup with extreme-speed clamp, minimum-speed restore,
  boss-launch guard timer, seeded screen / ball motion RNGs, bounded ball-shake
  sampling, loop-audio active latch, active-vs-cooldown frame ordering,
  activation, round cleanup, and reset. This remains separate from
  `stage2_boss_skill_state.gd`'s boss-scheduler cooldown. The quake coordinator
  owns ordinary activation / capacity gating, rock and delayed-cannon handoff,
  impulse scaling / scene writes, screen-shake feedback, backstop / cleanup,
  and audio handoff. The background keeps renderer handoff and compatibility
  properties. Quake-loop audio side effects and the cached fallback live in the
  rage coordinator.
- `scripts/stages/stage2/stage2_quake_coordinator.gd`
  Owns ordinary Stage 2 quake cross-domain orchestration: activation-time audio
  retention, shared eight-rock capacity and zero-request guard, rock-lifecycle
  handoff, delayed water-cannon scheduling, warning then loop-audio publication,
  active timing / cooldown eligibility, fixed shake before audio sync, ball
  velocity capture / perturb / restore, boss-launch guard, home-band top-goal
  backstop, and round cleanup before loop stop. It consumes the retained quake,
  rock, and water-cannon states; delegates rock construction to the rock
  lifecycle coordinator and audio to the rage coordinator; and is registered
  in `gameplay_stage_module_catalog.gd`. The pillar background retains frame-
  loop position, renderer projection, compatibility properties, and thin public
  facades.
- `scripts/stages/stage2/stage2_audio_router.gd`
  Owns Stage 2 gameplay-audio routing helpers for quake loop start / stop /
  sync, boss-rage cry playback, rock spawn / break / hit cues, water-cannon
  hydro cues, and starpoint collection cues, including the cached rage-audio
  fallback used during pre-rally animations. The retained quake runtime state
  owns logical lifecycle values and the live loop latch;
  `stage2_boss_rage_coordinator.gd` keeps the cached audio handle, loop-routing
  methods, and rage cue timing. The quake coordinator owns ordinary quake cue
  call positions, while other focused owners route their own one-shots.
- `scripts/stages/stage2/stage2_skill_warning_state.gd`
  Owns Stage 2 skill-warning state: trigger text / kind, minimum duration
  clamp, timer decay, active checks, reset, and renderer snapshot payload.
  Focused coordinators own water / rage / ordinary-quake warning triggers; the
  pillar background retains snapshot renderer handoff.
- `scripts/stages/stage2/stage2_screen_overlay_visual_renderer.gd`
  Owns the stateless Stage 2 screen-overlay draw pass for border-hit
  flashes and boss-rage tint rectangles. It receives timer / side /
  impact-Y / tint snapshots from `stage2_pillar_background.gd`; it does
  not trigger wall-hit reactions, advance rage timers, alter actor tint,
  or mutate gameplay state.
- `scripts/stages/stage2/stage2_border_flash_state.gd`
  Owns Stage 2 border-flash state: duration, active timer, side, impact-Y
  snapshot, reset, and decay. `stage2_wall_reaction_coordinator.gd` retains
  and advances this state; the background exposes a compatibility property
  and keeps overlay renderer fanout.
- `scripts/stages/stage2/stage2_wall_reaction_coordinator.gd`
  Retained coordinator for Stage 2 side-wall presentation reactions: legacy
  empty-side fallback, side validation, impact-Y / left-right origin geometry,
  bush-band classification through `stage2_rustle_state.gd`, bounded impact
  speed scale, two-leaf ambient burst, 10-26 leaf-particle burst policy,
  retained border-flash lifecycle, and direct mutation of the retained ambient
  state through its existing capped append APIs. Middle-wall hits create only
  the flash; upper / lower bush-band hits additionally raise excitement and
  emit leaves. `stage2_pillar_background.gd` retains the public
  `trigger_tree_shake()` facade and draw fanout without reaction math or burst
  loops.
- `scripts/stages/stage2/stage2_ambient_visual_renderer.gd`
  Owns the stateless Stage 2 ambient draw pass for falling-leaf sprites /
  fallbacks, firefly glow dots, wall-hit leaf particles, and bush / vine
  rustle visuals. It receives retained-state arrays and texture references
  through `stage2_pillar_background.gd`; it does not spawn leaves, build the
  rustle layout, update rustle reactions, decay particles, update
  fireflies, or mutate gameplay state.
- `scripts/stages/stage2/stage2_ambient_payload_factory.gd`
  Owns Stage 2 ambient payload construction for viewport-side falling
  leaves, fireflies, and leaf particles emitted by wall / rock reactions.
  The retained ambient state owns layout invalidation, live collections,
  spawn cadence, and particle pruning; the wall-reaction coordinator owns wall
  burst requests, while the background keeps rock reactions and renderer
  fanout. Rustle mutation lives in its retained state and focused coordinator.
- `scripts/stages/stage2/stage2_ambient_visual_state.gd`
  Retained mutable owner for Stage 2 ambient presentation: deterministic RNG,
  elapsed time, wall-impact excitement / decay, viewport / game layout cache,
  falling-leaf / firefly / wall-hit leaf-particle collections, layout reuse /
  initial population, ambient leaf cadence / cap, particle newest-window cap,
  y / sway / rotation advancement, off-layout compaction, firefly drift / side
  wrapping, particle gravity / damping / life decay, and reset. Static motion
  helpers remain for focused tests and compatibility. The wall-reaction
  coordinator owns side-wall burst timing and requests; the background keeps
  rock reactions, textures, renderer fanout, and compatibility properties
  without duplicate storage. Rustle context mutation lives in its coordinator.
- `scripts/stages/stage2/stage2_ambient_layout_helper.gd`
  Owns Stage 2 ambient layout helper decisions: current-layout matching,
  initial falling-leaf / firefly population, falling-leaf spawn chance, and
  max-count guarded leaf append. The retained ambient state owns the live
  arrays, layout fields, update orchestration, and particle pruning; the
  background keeps rustle renderer fanout while the rustle coordinator owns its
  context updates.
- `scripts/stages/stage2/stage2_ambient_visual_snapshot_builder.gd`
  Owns the read-only Stage 2 ambient visual snapshot counts for falling
  leaves, fireflies, and available leaf sprites. The retained ambient state
  owns layout readiness, arrays, and particle updates; the background keeps
  texture readiness, snapshot publication, and renderer fanout.
- `scripts/stages/stage2/stage2_rustle_payload_factory.gd`
  Owns Stage 2 rustle layout payload construction: fixed bush anchors,
  height-dependent player-side bush positions, vine anchors, and initial
  amount / angle / phase fields. The retained rustle state owns layout cache /
  invalidation and live payload collections; the rustle coordinator requests
  layout assurance and interprets paddle context. `stage2_pillar_background.gd`
  publishes snapshots and fans out rendering.
- `scripts/stages/stage2/stage2_rustle_state.gd`
  Retains Stage 2 bush / vine collections, layout size, independent boss /
  player previous-center samples and validity latches. It owns reset, layout
  reuse / rebuild, first-sample-safe motion sampling, bush / vine proximity
  trigger mutation, decay, and active-visibility checks; the side-wall
  bush-band predicate and collection mutation helpers remain static for
  focused tests and compatibility. `stage2_rustle_coordinator.gd` owns current-
  position / dash interpretation and ordered mutation calls;
  `stage2_pillar_background.gd` exposes compatibility properties and keeps
  snapshot publication and renderer fanout. Both state and coordinator are
  registered in `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_rustle_coordinator.gd`
  Owns outer-pillar bush / vine context orchestration: Stage 2-only gating,
  layout assurance, boss and player paddle-center projection, first-sample-safe
  history consumption, movement threshold, boss velocity / player dash
  classification, boss bush then vine routing, player bush-only routing, and
  final same-frame decay. It consumes the retained rustle state and payload
  factory without duplicating collections. The pillar background keeps update
  position, snapshots, rendering, and thin compatibility methods; the separate
  wall-reaction coordinator retains side-wall bush-band effects. This owner is
  registered in `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_rustle_snapshot_builder.gd`
  Owns Stage 2 rustle snapshot construction: active bush count, active
  player / boss bush counts, and active vine count. The retained rustle state
  owns live collections and trigger / decay mutation; the background module
  still publishes snapshots and fans out rendering.
- `scripts/stages/stage2/stage2_rock_visual_factory.gd`
  Owns the Stage 2 rock visual payload factory: style selection, style
  color arrays, seeded fixed polygon points, visual radius, rock seed, and
  initial rotation. `stage2_rock_lifecycle_coordinator.gd` owns spawn and base
  life orchestration; the interaction / feedback owners handle collision and
  HP, while the pillar background retains golden-drop callback creation,
  fragments, and rendering.
- `scripts/stages/stage2/stage2_rock_query.gd`
  Owns Stage 2 rock dictionary query helpers: id lookup, landed checks,
  runtime-update predicates, random id selection for water-cannon targeting,
  target position, render / collision center, center mutation, and
  spawn-spacing distance tests.
  The retained rock state owns collection mutation; the interaction coordinator
  owns public-contact traversal and geometry; the lifecycle coordinator owns
  spawn, base-life, and quake-drop queries. `stage2_pillar_background.gd`
  retains response callback routing and public golden-drop behavior; the rock-
  frame coordinator owns frame iteration and absorbed-rock golden callbacks.
- `scripts/stages/stage2/stage2_rock_runtime_state.gd`
  Retains the mutable Stage 2 rock collection and next-id counter and owns
  reset, append / replace / remove, atomic id claims, deep snapshots,
  indexed hit-flash / water-target-flash decay / mark / clear, and phase
  advancement. `stage2_pillar_background.gd` exposes compatibility properties
  while the rock-frame coordinator owns collection iteration, Chaos absorption,
  visual-timer calls, and removal. The background keeps collision / reward entry
  points and renderer fanout. Spawn / lifetime / quake-drop
  orchestration lives in the lifecycle coordinator; hit mutation and shared
  feedback routing live in the rock-feedback coordinator.
- `scripts/stages/stage2/stage2_rock_lifecycle_coordinator.gd`
  Owns Stage 2 quake / crisis rock generation around the existing factories:
  shared-RNG order, retained insertion / id advancement, ordered spawn leaf
  bursts, water-cannon cancellation / skill deferral, and spawn audio. It also
  owns finite-life expiry and quake-drop / landing mutation plus leaf feedback.
  The rock-frame coordinator consumes its expiry / drop methods; the pillar
  background retains rendering and public compatibility facades. This owner is
  registered in `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_rock_frame_coordinator.gd`
  Owns reverse per-frame traversal of the retained Stage 2 rock collection:
  base expiry, expired-session Chaos flag clearing, active Chaos pull / remove,
  ordinary visual timers, quake drop / offset, survivor replacement, and final
  fragment advancement. Absorbed destruction preserves fragment / leaf /
  golden-starpoint / break-audio feedback before publishing the absorbed result
  and removing the rock. It delegates lifecycle, Chaos math / payload, feedback,
  and starpoint construction to their existing owners and is registered in
  `gameplay_stage_module_catalog.gd`. The pillar background keeps frame position,
  renderer fanout, and thin compatibility methods without a second loop.
- `scripts/stages/stage2/stage2_starpoint_runtime_state.gd`
  Retains the mutable Stage 2 starpoint drop and particle collections and owns
  atomic clear / prior-state reporting, append operations, drop counts, and
  deep drop snapshots. `stage2_pillar_background.gd` exposes compatibility
  properties while starpoint orchestration lives in the focused coordinator.
  This owner is registered in
  `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_starpoint_coordinator.gd`
  Borrows the shared Stage 2 RNG and owns primary drop -> particles -> Star
  Detector bonus payload order, playfield-clamped bonus positions, drop motion,
  Dowsing attraction, Starlight Tracking delivery, circle overlap, modal-safe
  in-place compaction, reward -> particles -> audio -> redraw feedback order,
  particle motion, and stage-exit state-clear -> detached-host-hide order. It
  consumes the common starpoint helpers and retained runtime state without
  duplicating arrays or consuming RNG during configuration. The pillar
  background retains rendering, update position, and public compatibility
  facades. This owner is registered in `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_pistol_rock_bounce_state.gd`
  Owns pure Stage 2 pistol-vs-rock ricochet policy: the two-bounce limit,
  contacted-side resolution for rect and swept-segment hits, reflected
  projectile position / velocity damping, speed refresh, and hit-side
  stamping. `stage2_rock_interaction_coordinator.gd` owns rock iteration,
  landed filtering, collision probing, bounce-limit routing, and the public
  result payload; the pillar facade exposes the compatibility method and the
  rock-feedback coordinator owns ricochet flash / audio.
- `scripts/stages/stage2/stage2_rock_interaction_coordinator.gd`
  Owns Stage 2 ball / blade / explosion / pistol contact orchestration: stage
  and landed-rock gates, swept-segment and overlap checks, ball reflection plus
  scene-write-before-feedback order, reverse removal-safe area traversal,
  forced one-hit break preparation, explosion visual-radius fallback, and
  pistol ricochet / consume payloads. It calls unbound response callbacks and
  owns no HP decrement, reward, RNG, particles, shake, or audio. The pillar
  background retains the public methods; feedback remains in
  `stage2_rock_feedback_coordinator.gd`. This owner is registered in
  `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_rock_feedback_coordinator.gd`
  Owns Stage 2 normal rock-hit and ricochet feedback orchestration: HP
  decrement, full-hit / minimum-ricochet flash, hit shake, survivor replace
  versus destroyed removal, hit / break cue selection, golden-reward callback
  timing, and bounded leaf / fragment burst recipes. It also owns the shared
  Chaos-absorb destruction-feedback order. The rock-interaction coordinator
  owns contact traversal and calls this response through the pillar's public
  facade; the pillar keeps starpoint callback creation, retained-state access,
  and renderer fanout. The water-cannon impact coordinator consumes its shared
  fragment / leaf / golden-reward helpers.
- `scripts/stages/stage2/stage2_rock_fragment_payload_factory.gd`
  Owns Stage 2 normal rock-fragment payload construction after quake /
  crisis rocks break: fragment count, radial velocity, source sprite index,
  fallback color, size, rotation, spin, gravity, life, and bounce fields.
  `stage2_rock_feedback_coordinator.gd` owns normal payload requests and break
  routing; the retained fragment state owns payload-list append / cap, while
  the interaction coordinator owns contact detection and the pillar background
  keeps public response routing and draw fanout.
- `scripts/stages/stage2/stage2_rock_fragment_payload_config_builder.gd`
  Owns the read-only Stage 2 normal rock-fragment factory config payload,
  currently the fragment lifetime override. The rock-feedback coordinator
  consumes the config and owns normal break routing; the retained fragment
  state owns list pruning.
- `scripts/stages/stage2/stage2_rock_fragment_motion_state.gd`
  Retains the mutable Stage 2 rock-fragment collection and owns reset,
  newest-window payload append / cap, lifetime decay, gravity, floor bounce /
  horizontal damping, position, rotation, and survivor compaction. The
  rock-frame coordinator owns per-frame advancement. The background module
  still owns renderer fanout and collision / reward entry points behind a
  compatibility property; shared payload requests and break feedback live in
  the rock-feedback coordinator.
- `scripts/stages/stage2/stage2_chaos_rock_absorb_state.gd`
  Retains the Stage 2 Chaos Spear rock-absorb session center, refresh timer,
  and pending destroyed-rock result queue. It owns reset / timer advance,
  refresh-time deep-copy single drain, destroyed-result queueing, and rock-pull
  motion math: destroy-threshold checks, angular velocity, radial pull speed,
  next-center calculation, rotation / phase mutation, and destroyed/moved
  result payloads. The background module exposes compatibility properties;
  orchestration is owned by the Chaos absorb coordinator.
- `scripts/stages/stage2/stage2_chaos_rock_absorb_coordinator.gd`
  Owns Stage 2 Chaos Spear session advancement, refresh-time landed-rock
  activation and parity-stable spin direction, center normalization through
  `stage2_rock_query.gd`, water-target-flash clearing, immediate splash
  compaction / absorption, whole-frame plus remainder pull stepping, and
  absorbed splash / rock payload publication. It reports rock destruction
  before queueing it so the rock-frame coordinator can preserve fragment / leaf
  / golden-reward callback / break-audio feedback before publishing the
  absorbed result. Payload construction remains delegated to
  `stage2_chaos_absorb_payload_factory.gd`; retained values and pure pull math
  remain in `stage2_chaos_rock_absorb_state.gd`. This owner is registered in
  `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_chaos_absorb_payload_factory.gd`
  Owns pure Stage 2 Chaos Spear absorbed-entry payload construction for water
  splash absorption and destroyed-rock absorption pulses.
- `scripts/stages/stage2/stage2_monkey_banana_event.gd`
  Owns the Stage 2 original monkey-banana side event: first spawn after
  5-10 seconds, repeat spawns after 15-30 seconds, left/right outer-tree
  monkey climb / sit / throw / leave state, 1.5-3.0 second throw wait,
  player 40% vs boss 60% banana targeting, 1-second arced banana flight,
  2-second landed peel window, burst-particle simulation, banana throw / slip audio,
  player slip / dash-wall-slip movement, and boss-control-loss slip context
  consumed by `boss_ai_state.gd`. It maps renderer-owned alpha-median source
  points through the live Stage 2 tree rect and lends its monkey/banana arrays
  to the pillar/playfield renderer facades without copying.
  Monkey / banana initial payloads and banana burst-particle payloads are
  delegated to `stage2_monkey_banana_payload_factory.gd`.
- `scripts/stages/stage2/stage2_monkey_banana_renderer.gd`
  Owns staged climb/throw/banana/tree-resource prewarm, cached texture-image
  decompression and left/right alpha-median trunk scans, deterministic sheet-
  frame and transform-safe UV-flip projection, letterbox-aware banana culling,
  procedural fallbacks, landed shadow/body layering, and burst presentation.
  It owns no event timing, target/collision/slip behavior, audio, simulation,
  payload creation, RNG, or retained monkey/banana arrays.
- `scripts/stages/stage2/stage2_boss_skill_state.gd`
  Owns the first Stage 2 악어장군 boss-pattern scheduler: initial/repeat
  jungle-quake cooldown gating, boss-paddle-hit gauge gain / 500-point
  consume timing, 80% round-carry behavior, score-gated water-cannon
  reservation after quake, pressure-scaled cooldown / water-cannon delay
  profiles, difficulty-based MVP rock counts, and the boss-AI
  movement-lock context while water cannon is charging or firing. The
  background module still owns the actual rocks, collision, VFX, and
  audio-triggered water-cannon lifecycle. It also exposes the compact
  Korean HUD context for the currently ported jungle-quake / water-cannon
  / speed-defense skill state, including the boss-gauge bar used by the
  right pillar HUD. It owns Stage 2 speed-defense danger detection,
  35-second activation interval, 3-second serve grace, 2-second movement
  burst state, 80-gauge spend, boss-AI speed/turn context, start/block/hit
  audio triggers, and actor-draw trail context.
- `scripts/stages/stage2/stage2_boss_ai_context_builder.gd`
  Owns the read-only base Stage 2 boss-AI context payload for movement-lock
  and water-cannon phase fields. The background still owns the movement-lock
  predicate while the retained water-cannon runtime state owns phase
  lifecycle; the boss skill state may add skill-specific AI fields on top of
  this base context.
- `scripts/stages/stage2/stage2_boss_rage_snapshot_builder.gd`
  Owns the read-only Stage 2 boss-rage snapshot payload: pending / active
  flags, timer, stomp count, final-stomp flag, actor Y offset, and tint.
  It projects values borrowed from the retained rage-state owner; the
  background publishes the snapshot without duplicating its mutable storage.
- `scripts/stages/stage2/stage2_boss_rage_state.gd`
  Retained mutable owner for the Stage 2 boss-rage lifecycle: one-shot crisis
  reservation, pending-to-active transition, AI mode, timer, stomp count,
  final-stomp latch, actor offset / tint progression, completion, and reset.
  It also retains the pure crisis, rock-count, visual-envelope, stomp-window,
  and finish helpers for focused tests and compatibility.
  `stage2_boss_rage_coordinator.gd` consumes its events; the pillar background
  keeps frame-loop position, renderer, snapshot publication, and legacy field
  accessors without storing a second copy.
- `scripts/stages/stage2/stage2_boss_rage_coordinator.gd`
  Owns Stage 2 rage orchestration around the retained state: one-shot crisis
  reservation facade, pending start, serve-wait audio fallback retention,
  start warning before shake, per-step cry before shake, mythic / champion wall
  count projection, and final quake activation -> crisis wall -> warning ->
  quake audio -> cry -> shake ordering. It also owns quake-loop play / stop /
  sync through the cached fallback. Crisis rock construction remains delegated
  to `stage2_rock_lifecycle_coordinator.gd`; the pillar background retains
  frame-loop position, rendering, public compatibility facades, and snapshots.
  This owner and the retained rage state are registered in
  `gameplay_stage_module_catalog.gd`.
- `scripts/stages/stage2/stage2_boss_expression_state.gd`
  Owns the short-lived Stage 2 boss score-expression state: accepted
  expression IDs, neutral fallback, timer decay, reset, and actor /
  playfield snapshot payload. `stage2_pillar_background.gd` still owns the
  public `set_expression()` API and draw-context handoff.
- `scripts/stages/stage2/stage2_actor_draw_context_builder.gd`
  Owns the read-only Stage 2 actor draw-context payload for boss rage
  active / offset / tint fields and boss expression fields. The background
  module still owns rage / expression state and renderer handoff.
- `scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd`
  Owns the first Stage 2 악어장군 boss-skill HUD surface: a compact
  right-pillar status panel for 정글지진 / 물대포 readiness, cooldown, and
  active-cast copy. It draws only from the scheduler's HUD context so the
  scene drawer stays as composition glue.
- `scripts/stages/stage2/stage2_boss_skill_hud_assets.gd`
  Owns Stage 2 boss skill-card HUD asset metadata: skill-card PNG paths and
  staged prewarm skill ids. The renderer keeps texture caching, card layout,
  tooltip, and draw behavior.
- `scripts/stages/stage2/stage2_pillar_scene_drawer.gd`
  Owns Stage 2 outer-scene pillar composition for the initial port slice.
  It draws the Stage 2 pillar background, temporarily reuses the current
  Stage 1 active-item / pillar HUD scene drawer, and composes the Stage 2
  boss-skill HUD renderer in the post-playfield HUD pass.
- `scripts/stages/stage2/stage2_actor_renderer.gd`
  Owns the public Stage 2 playfield / actor draw entry point. It delegates the
  jungle court to `stage2_playfield_renderer`, reuses the shared Smasher player
  renderer, and draws the sprite-backed Stage 2 boss through
  `stage2_boss_actor_renderer`.
- `scripts/stages/stage2/stage2_playfield_renderer.gd`
  Owns the Stage 2 center playfield background: the original Python
  imagegen center-field source/fallback, crocodile center emblem, ball-
  tracking eye pupils, score expression overlays, boss-vine atlas layer,
  12 original bush anchors with paddle rustle, falling leaves, and the
  center electric line. The procedural jungle court remains only as the
  missing-asset fallback.
- `scripts/stages/stage2/stage2_boss_actor_renderer.gd`
  Owns the Stage 2 boss actor renderer. It selects the accepted idle, left /
  right walk, attack, Jungle Quake stomp, speed-defense, victory, and defeat
  sheets; keeps procedural alligator silhouette drawing as a missing-asset
  fallback; consumes live boss position / facing, stage-owned rage tint /
  offset, score expression overlays, contact-state context, status overlays,
  speed-defense shield presentation, and ghost trail draw data from the Stage 2
  boss skill context.
- `scripts/stages/stage3/stage3_pillar_background.gd`
  Owns the Stage 3 outer Menhera plush frame map slice. It loads the
  Python reference imagegen assets copied under `godot/assets/sprites/hud/`,
  composes the full-screen cyber-menhera base, ambient sprite atlas, center
  frame pieces outside the live field, and floating side-pillar hearts.
- `scripts/stages/stage3/stage3_pillar_background_assets.gd`
  Owns Stage 3 pillar-background asset metadata: Menhera base / ambient /
  center-frame resource paths, baked ambient atlas regions, center-frame
  window rect, and staged prewarm count. `stage3_pillar_background.gd`
  keeps texture caches, LOD policy, floating hearts, and draw composition.
- `scripts/stages/stage3/stage3_pillar_scene_drawer.gd`
  Owns Stage 3 outer-scene pillar composition for the map port. It draws
  the Stage 3 pillar background and reuses the current Stage 1 pillar HUD
  scene drawer for active items / orb HUD, then composes the Menhera boss
  skill-card HUD in the post-playfield HUD pass.
- `scripts/stages/stage3/stage3_actor_renderer.gd`
  Owns the public Stage 3 playfield / actor draw entry point for the map
  and Menhera boss port. It delegates the Menhera center court to
  `stage3_playfield_renderer`, the boss sheets to
  `stage3_menhera_boss_actor_renderer`, skill VFX to
  `stage3_menhera_skill_effect_renderer`, draws the Kuromi awakening
  event's dark pause overlay, and keeps using the shared Stage 1 player
  renderer for Smasher until character-specific Stage 3 actor work needs a
  new owner.
- `scripts/stages/stage3/stage3_playfield_renderer.gd`
  Owns the Stage 3 center playfield background port from
  `ui/stage3_menhera_world.py`: emotional checkerboard field, dashed center
  court ring, electric pulse, petrified Kuromi mascot, floating heart
  particles, heart/star border, Python-coordinate Kuromi face / normal-tail
  geometry, and the score-3 Kuromi awakening cracks / stone-fragment burst. It
  remains the CanvasItem draw-order, render-quality, performance-label, and
  compatibility facade while delegating mutable presentation state and cache
  construction to the focused Stage 3 helpers below.
- `scripts/stages/stage3/stage3_playfield_presentation_state.gd`
  Owns the Stage 3 playfield animation clock, emotional phase sync, bounded
  floating-heart simulation, and stadium electric-spark burst scheduling.
- `scripts/stages/stage3/stage3_ellipse_geometry_cache.gd`
  Owns bounded unit, transformed, and closed-outline ellipse point caches used
  by the playfield renderer without per-frame array duplication.
- `scripts/stages/stage3/stage3_playfield_texture_cache.gd`
  Owns Stage 3 checker/border texture construction and caches, image raster
  primitives, emotional phase color projection, and cache limits.
- `scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd`
  Owns the Godot Menhera Girl boss sprite port from
  `entities/menhera_boss_sprite.py`: six 4x2 source sheets, alpha-bbox
  frame trimming, Python-parity 176x88 bottom-aligned draw sizing,
  attack/dash/turn/victory/defeat priority, dash flip, turn hold/hop,
  boss-gauge red tint, ready aura, and psycho-ball afterimage trails.
- `scripts/stages/stage3/stage3_boss_skill_state.gd`
  Owns the public Stage 3 Menhera boss-skill runtime facade, with the old
  boss-hit gauge gain disabled. It retains public boss-hit/gauge fields,
  owner construction/shared-RNG order, reset and event facade methods, and
  public actor/snapshot/HUD signatures. Per-frame ordering delegates to
  `stage3_boss_skill_update_coordinator.gd`; actor and diagnostic projection
  delegates to `stage3_boss_skill_context_builder.gd`; shared cooldown/
  activation/status policy delegates to `stage3_boss_skill_scheduler.gd`; HUD
  payload projection delegates to `stage3_boss_skill_hud_state_builder.gd`;
  ordered full/round reset policy delegates to
  `stage3_boss_skill_lifecycle.gd` while the update coordinator orders
  stage-leave detached-host cleanup around the public reset facade. Its 67
  inherited legacy property proxies delegate to
  `stage3_boss_skill_compatibility_surface.gd`; the host retains exact focused
  owner construction and shared-RNG order. Tail and Kuromi synchronous
  producer-consumer fanout delegates to
  `stage3_boss_skill_handoff_coordinator.gd`; the update coordinator retains
  their exact frame positions. Its only runtime-owned constants are `STAGE_ID`,
  `BOSS_GAUGE_MAX`, and `BOSS_GAUGE_GAIN_ON_HIT`; skill-specific timing,
  geometry, collision, and particle budgets remain with their focused state
  owners and are consumed directly without host re-export aliases.
  Kuromi score-3 awakening eligibility/timer/feedback/audio/flags/projection and
  fracture-helper driving are delegated to `stage3_kuromi_awakening_state.gd`;
  the host retains thin compatibility properties and public query/force wrappers.
  Tear Shower cooldown/activation/motion/collision/slow/audio/projection is
  delegated to `stage3_tear_shower_state.gd`; the host retains thin public
  compatibility accessors while the scheduler retains Tears-before-Curse
  activation priority.
  Curse Chest cooldown/phase/smoke/reverse/explosion/audio/projection, including
  timeout falloff knockback and shared hostile-knockback immunity gates, is
  delegated to `stage3_curse_chest_state.gd`; the host retains thin public
  compatibility accessors, the update coordinator retains its frame position,
  and the scheduler retains its established activation position.
  Tail Whip targeting/cooldown/curve/collision/burst/projection is delegated to
  `stage3_tail_whip_state.gd`; the update coordinator immediately forwards its
  hit event for shared prism, impact, starpoint, and audio side effects. Psychoball
  cooldown/activation/hitstop/motion/smoke/audio/
  projection is delegated to `stage3_psychoball_state.gd`. Kuromi ball-eating
  state/phase/audio/external-ownership/projection is delegated to
  `stage3_kuromi_eating_state.gd`; the update coordinator retains its exact
  cross-skill update position and consumes the post-spit prism request using the
  shared Prism owner/RNG. Menhera-tail starpoint spawning/updating/collection is delegated
  to `stage3_starpoint_state.gd` without changing tail-hit or shared-RNG call
  order. Prism array/spawn/motion/cap/projection and payload dispatch are
  delegated to `stage3_prism_burst_state.gd`; the host retains strong/normal
  public compatibility surface while the update coordinator retains handoff
  positions around Tail hit and Kuromi release. The Tear Shower, Curse Chest,
  Psychoball, Kuromi eating, and Tail Whip owners delegate their focused
  payloads to `stage3_boss_skill_payload_factory.gd` as well.
  It is reset from round, match, and stage-debug cleanup paths.
- `scripts/stages/stage3/stage3_boss_skill_compatibility_surface.gd`
  Owns the inherited static compatibility properties for seven focused Stage 3
  owners. All 67 getters/setters route directly to the exact owner instances,
  preserving property names/types, reflection visibility, and RefCounted
  identity without mirrored state or dynamic lookup. It owns no construction,
  RNG, update/reset policy, payload, audio, or drawing.
- `scripts/stages/stage3/stage3_boss_skill_handoff_coordinator.gd`
  Owns draw-free synchronous cross-owner fanout. Tail hit events dispatch
  strong Prism -> unit impact -> Starpoint -> audio in exact shared-RNG order;
  Kuromi's one-shot request dispatches one normal Prism. Missing optional sinks
  and invalid-position fallback retain legacy behavior. It owns no clocks,
  producer state, result mutation, activation, reset, or drawing.
- `scripts/stages/stage3/stage3_boss_skill_update_coordinator.gd`
  Owns the complete draw-free Stage 3 boss-skill frame order: off-stage reset
  and detached Starpoint-host cleanup, 0.05-second delta clamp, awakening/Tail-
  burst/Starpoint early ticks, Psychoball hitstop short circuit, scheduler call
  positions, Tear/Curse/Kuromi/Tail/Psychoball/Prism advancement, handoff
  positions, boss-red decay, audio sync, and status publication. It stores the
  injected stage id and focused-owner/coordinator references but never retains
  the host, owns focused state/RNG/payloads, or renders.
- `scripts/stages/stage3/stage3_boss_skill_lifecycle.gd`
  Owns draw-free Stage 3 reset coordination across eight focused owners. Full
  reset restores initial Psychoball/Tear/Curse cooldowns, charging status,
  fixed Tail initial cooldown, and petrified Kuromi. Round reset preserves
  those three live cooldowns, status, and awakening state while clearing live
  effects, then rerolls Tail after cleanup to preserve shared-RNG order. It
  owns no per-frame state, RNG, audio, payload, or detached visual-host nodes.
- `scripts/stages/stage3/stage3_boss_skill_scheduler.gd`
  Owns draw-free Stage 3 cross-skill policy: canonical/legacy active-item pause
  key precedence, exact Psychoball/Tears/Curse/Tail/eating cooldown fanout,
  awakened/not-overdrive Tail gating, serve/ball/awakening/overdrive activation
  guards, one-writer Tears-before-Curse-before-Tail activation priority, and
  active-skill/public pause status priority. It owns no RNG, mutable skill
  clock, reset state, payload, audio, or drawing; the facade calls it at the
  established frame positions.
- `scripts/stages/stage3/stage3_curse_chest_state.gd`
  Owns Menhera Curse Chest's focused mutable lifecycle: 35-second cooldown,
  windup/parabolic throw/landing, closed-chest lifetime and nudge/wobble,
  dash-open smoke, two-second control reversal, timeout explosion with
  120-pixel falloff knockback and shared Cleanse/Celestial Armor gates, one-shot
  audio, effect/full reset policy, and borrowed-or-copied actor projection. It
  borrows the shared Stage 3 RNG without construction-time consumption and
  owns focused smoke/explosion payload dispatch through
  `stage3_boss_skill_payload_factory.gd`. The facade keeps public compatibility
  properties and the reverse query consumed by the input proxy; the focused
  scheduler keeps cross-skill activation policy.
- `scripts/stages/stage3/stage3_tear_shower_state.gd`
  Owns Menhera Tear Shower's focused mutable lifecycle: 25-second cooldown,
  automatic normal/enraged spawn, 400-frame duration, falling and recycle
  motion, reverse-order player collision, source-scoped stacking slow and
  Cleanse immunity, per-hit audio, effect/full reset policy, and borrowed-or-
  copied actor projection. It borrows the shared Stage 3 RNG without
  construction-time consumption and delegates falling-tear payload creation to
  `stage3_boss_skill_payload_factory.gd`. The facade retains compatibility
  properties and update position; the focused scheduler owns activation
  priority.
- `scripts/stages/stage3/stage3_kuromi_awakening_state.gd`
  Owns Kuromi's score-3 statue-awakening lifecycle: eligibility/start, the
  three-second timer and progress, progressive and burst screen shake, one-shot
  awake/stonebreak audio, petrified/awakening/awakened flags, forced-awake
  transition, round/full reset policy, and borrowed-or-copied actor projection.
  It borrows the shared Stage 3 RNG without construction-time consumption and
  owns the fracture helper before Starpoint owner construction. The optional
  `sounds/stonebreak_large.wav` cue remains silent when the Python-reference
  asset is absent.
- `scripts/stages/stage3/stage3_kuromi_fracture_particles.gd`
  Focused bounded fracture subsystem owned by the awakening state. It owns
  pending large/small spawn budgets, fragment RNG payloads, per-frame motion and
  decay, z-order sorting, the 96-particle cap, and separate pending-only versus
  full-clear semantics. It borrows the awakening owner's shared Stage 3 RNG.
- `scripts/stages/stage3/stage3_prism_burst_state.gd`
  Owns the shared normal/strong Prism burst lifecycle: fixed 18-particle normal
  spawn, 18-22 count-roll strong spawn, focused factory payload dispatch,
  frame-rate-scaled motion/gravity/damping/sparkle/life, in-place compaction,
  60-particle newest-window cap, reset, and borrowed-or-deep-copied actor
  projection. It borrows the shared Stage 3 RNG without construction-time
  consumption. The facade retains only compatibility storage and immediate
  Tail/Kuromi handoff ordering.
- `scripts/stages/stage3/stage3_kuromi_eating_state.gd`
  Owns Kuromi's focused ball-eating runtime: overlap/chance entry, current
  ball-owner deferral, tongue/swallow/chew/direction/spit phases, ball hide and
  release result writes, 0.3-second spit-audio lead, one-shot tongue/swallow/
  spit cues, Chaos Spear ownership release, cooldown/reset, mouth particles,
  spit-trail lifecycle, and borrowed-or-copied actor projection. It borrows the
  Stage 3 RNG without consuming it during construction and preserves release
  order through spit speed then 25 mouth particles. The host consumes its
  one-shot center-Prism request immediately afterward through the focused Prism
  owner, retaining shared-RNG and cross-skill order.
- `scripts/stages/stage3/stage3_psychoball_state.gd`
  Owns Psychoball's focused mutable lifecycle: 70-second cooldown and boss-hit
  gate, normal/enraged duration, hitstop, shared-RNG curve/rare teleport,
  tear-gas smoke-zone lookup and neutralization, afterimage trails, capped
  neutralize particles, loop-audio start/stop/sync, shake feedback, effect/full
  reset policy, and borrowed-or-copied actor projection. It borrows the Stage 3
  RNG without construction-time consumption. The facade retains boss-gauge
  reset-before-feedback ordering, compatibility accessors, early-hitstop
  return, and cross-skill order.
- `scripts/stages/stage3/stage3_tail_whip_state.gd`
  Owns Kuromi Tail Whip's mutable lifecycle: target tracking, cooldown/attack/
  curve clocks, redirected ball result and speed cap, one-hit collision gate,
  capped burst payloads, reset policy, and borrowed-or-copied actor projection.
  It borrows the Stage 3 RNG without construction-time consumption and returns
  a synchronous hit event after consuming the burst seed. The facade then owns
  strong prism -> impact -> starpoint -> audio dispatch in the established
  shared-RNG/frame order.
- `scripts/stages/stage3/stage3_tail_whip_geometry.gd`
  Pure draw-free owner for the live Tail Whip 24-point curve and bounded middle-
  segment collision query. The state injects the animation clock; both live
  runtime and focused geometry tests call this same implementation.
- `scripts/stages/stage3/stage3_starpoint_state.gd`
  Owns the Stage 3 Menhera-tail starpoint lifecycle behind the boss-skill host:
  borrowed shared-RNG payload and pickup-particle generation, Star Detector
  bonus recursion and caps, falling motion, Dowsing attraction, Lingpet
  Starlight Tracking, player overlap, reward/audio/redraw dispatch, modal-safe
  compaction, visual-host cleanup, and borrowed-or-copied actor draw snapshots.
  Construction consumes no RNG; the host retains tail-hit sequencing, stage
  lifecycle, and public snapshot/context facades while the context builder owns
  read-only merge composition.
- `scripts/stages/stage3/stage3_menhera_skill_effect_renderer.gd`
  Owns the Godot-native Stage 3 skill VFX layer for the Menhera runtime:
  psycho-field overlay, tear drops, curse chest/smoke/explosion, reverse
  curse marker, cached-texture pink curse smoke, Kuromi spit trail,
  Python-coordinate Kuromi tail-whip curve, and prism hit sparks.
- `scripts/stages/stage3/stage3_curse_control_input_proxy.gd`
  Owns the Stage 3 curse-smoke input projection used by player-control
  deps: while the Menhera curse reverse timer is active it swaps horizontal
  left/right input and flips horizontal direction metadata before character
  movement, full dash, half dash, and direction-reading skill runtimes
  consume the input snapshot.
- `scripts/stages/stage3/stage3_boss_skill_context_builder.gd`
  Owns read-only Stage 3 actor/snapshot composition: base gauge/ready/red keys,
  exact eight-owner merge precedence, borrowed/deep-copy flag forwarding, and
  the established diagnostic status/gauge/ready/cooldown fields. It captures
  owner references once after Starpoint construction, allocates no owner list in
  the draw path, and owns no RNG, mutable runtime, reset, audio, or drawing.
- `scripts/stages/stage3/stage3_boss_skill_hud_state_builder.gd`
  Owns pure Stage 3 boss-skill HUD projection: exact top-level payload keys,
  Korean boss identity, disabled legacy gauge flag, gauge progress, fixed
  Tears/Curse/Psychoball card order, labels/colors, cooldown status/progress,
  trigger metadata, and fresh per-read dictionaries/arrays. It reads the three
  focused state owners without mutating them and owns no clocks, RNG, reset,
  texture, sorting, tooltip, or CanvasItem behavior.
- `scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd`
  Owns Stage 3 boss skill-card layout, next-activation sorting, atlas/fallback
  gauge drawing, tooltip rendering, and texture caching. It draws Menhera's
  tears, curse chest, and psycho ball as compact cooldown cards. Kuromi is not a
  Menhera Girl skill card; the separate Kuromi event/tail runtime stays out
  of this HUD. The old top-right wand gauge is suppressed for Stage 3's
  cooldown-only skill model. The HUD loads the generated
  `assets/sprites/stage3/menhera_boss_skill_cards_imagegen_v1.png` atlas
  first and falls back to procedural cards only if that PNG is missing.
- `scripts/stages/stage3/stage3_boss_skill_hud_assets.gd`
  Owns Stage 3 boss skill-card HUD asset metadata: Menhera skill-card atlas
  path, skill-id-to-atlas-index mapping, and atlas column count. The renderer
  keeps atlas caching, layout, tooltip, and draw behavior.
- `scripts/stages/common/boss_skill_card_hud_spec.gd`
  Owns the shared Godot boss skill-card HUD sizing contract. Stage 1
  Dalji's compact card metrics are the canonical size: base pillar width
  `80`, card base `33.6x9.0`, min rect `24x10`, gap `2`, right margin `3`,
  and left-pillar Y margin `5`. Stage-specific renderers should pull these
  values from this spec rather than keeping independent card widths or
  heights.
- `scripts/stages/stage4/stage4_pillar_background.gd`
  Owns the first Stage 4 Shaolin Temple outer-scene map slice. It loads
  the current Python `pillar_temple.py` imagegen-mode pillar source:
  `stage4_empty_temple_nightsky_base_imagegen_v4_nomoon.png` as the
  full-screen base, with the Python-disabled Tibetan motion layer kept
  disabled in Godot too. The three-state right-pillar moon sheets are
  positioned from the Python source anchor. It also exposes the
  Stage 4-compatible stage-background hooks used by shared runtime code:
  smoke-to-brazier facade calls, star-bird ball collision, and the
  compatibility bird position / catch APIs. It now also forwards the
  generic stage-background ball-motion hook to Ponk's magnetic field and
  keeps magnetic-projectile collision on the same shared background path.
  Wall-impact accent payload construction is delegated to
  `stage4_pillar_background_payload_factory.gd`.
- `scripts/stages/stage4/stage4_pillar_background_payload_factory.gd`
  Owns pure Stage 4 pillar-background payload construction for transient
  wall-impact shake accents.
- `scripts/stages/stage4/stage4_pillar_scene_drawer.gd`
  Owns Stage 4 outer-scene composition. It draws the Stage 4 pillar
  background, reuses the current Stage 1 pillar HUD / active-item drawer,
  and composes the Ponk boss skill-card HUD in the post-playfield HUD pass,
  with the older vertical gauge kept only as a fallback surface.
- `scripts/stages/stage4/stage4_actor_renderer.gd`
  Owns the public Stage 4 playfield / actor draw entry point for the first
  map slice. It delegates the Shaolin center court to
  `stage4_playfield_renderer`, the placeholder Ponk boss body to
  `stage4_ponk_boss_actor_renderer`, and keeps using the shared Stage 1
  player renderer for Smasher while owning the Stage 4 player burn overlay,
  Ponk magnetic / meditation VFX draw pass, and moon-fragment draw pass
  ordering.
- `scripts/stages/stage4/stage4_playfield_renderer.gd`
  Owns the Stage 4 center playfield background port from
  `ui/stage4_shaolin_temple.py`: the center base, floating temple, ambient
  sprite atlas, a subtle procedural floating aura that avoids stretching
  the low-resolution aura sheet into a visible purple strip, original-style
  bob / swing motion for the temple, lanterns, training dummies, brazier,
  incense, and leaf field,
  brazier-lit read, temple destruction overlay, explosion sheet, debris
  atlas, red-moon fragment drawing, and missing-asset procedural fallbacks.
- `scripts/stages/stage4/stage4_map_state.gd`
  Owns Stage 4 map-level runtime glue for this slice: smoke-to-brazier API
  stubs, pending player-three-score destruction, immediate enrage
  destruction trigger, phase-2 BGM start, and actor / HUD draw-context
  export.
- `scripts/stages/stage4/stage4_temple_destruction_event.gd`
  Owns the Stage 4 temple destruction state machine: moon turning red, red
  light, moon-shot wave, collapsing temple, ruins state, screen shake
  context, and moon-shoot audio timing. Destruction-wave initial payload,
  trail particles, beam particles, and energy-ring payloads are delegated to
  `stage4_destruction_wave_payload_factory.gd`; collapse debris, dust-cloud,
  ground-fire particle, and falling-lantern payload defaults are delegated to
  `stage4_temple_collapse_payload_factory.gd`.
- `scripts/stages/stage4/stage4_moon_event.gd`
  Owns the Stage 4 right-pillar moon render surface and compatibility API:
  white idle, red transform, and red burst sheet selection, six-frame
  slicing, pulse scale, red-moon active state reporting, red moon fragment
  volley spawning, fragment trail / impact draw context, player burn /
  knockback / gauge-drain collision, dash deflection toward the boss, and
  deflected-fragment boss stun / Ponk gauge damage. Red moon fragment payload
  construction is delegated to `stage4_moon_payload_factory.gd`.
- `scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd`
  Owns the Stage 4 Ponk boss actor renderer so the Stage 4 route never falls
  through to the Stage 1 Dalji actor. It uses the current generated Ponk idle
  sheet with procedural fallback drawing, and owns the procedural
  `illusion_ripple` awaken aura / chi-orbit amplification pass, rotating light
  crown, and one-shot awaken burst driven by `stage4_illusion_awaken_stage`,
  first-cast delay, and awaken-burst draw context while the full action /
  result sheet set remains incomplete.
- `scripts/stages/stage4/stage4_ponk_gauge_hud_renderer.gd`
  Owns the first Stage 4 Ponk gauge HUD port as a separate post-playfield
  HUD renderer. Final skill-card conversion can replace or narrow this
  surface without folding gauge drawing into map state.
- `scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd`
  Owns the Stage 4 Ponk boss skill-card HUD. It renders compact left-pillar
  cards for `굴절 자기장` and `위빠사나 명상`, using dedicated
  current-VFX-matched skill-card PNGs
  `stage4_ponk_refraction_magnetic_field_skillcard_imagegen_v1.png` and
  `stage4_ponk_vipassana_meditation_skillcard_imagegen_v1.png` before
  falling back to the ported magnetic-field sheet / floating-temple aura
  sheet and then procedural fills.
- `scripts/stages/stage4/stage4_ponk_boss_skill_hud_assets.gd`
  Owns Stage 4 Ponk boss skill-card HUD asset metadata: skill-card PNG
  paths, fallback sheet paths, and fallback sheet grid dimensions. The
  renderer keeps texture caching, prewarm sequencing, card layout, and draw
  composition.
- `scripts/stages/stage4/stage4_ponk_skill_state.gd`
  Owns the public Stage 4 Ponk compatibility facade, live gauge HUD context,
  boss skill-card metadata, actor VFX draw context, and
  the magnetic-field sheet under `godot/assets/sprites/stage4/`. It delegates
  node-free magnetic-field state/curvature/release math to
  `stage4_ponk_magnetic_field_state.gd` and delegates the
  node-backed visual remasters to `stage4_ponk_magnetic_fx_host.gd`,
  `stage4_ponk_meditation_fx_host.gd`, and
  `stage4_ponk_illusion_ripple_fx_host.gd`. The illusion-ripple mutable
  lifecycle and actor/debug projection are delegated to
  `stage4_ponk_illusion_state.gd`; cross-skill runtime/reset order is delegated
  to `stage4_ponk_runtime_coordinator.gd`. The host preserves public
  compatibility properties/methods and thin presentation/diagnostic delegates.
  Static asset prewarm, fallback gating, cross-effect draw order, and asset/host
  status are delegated to `stage4_ponk_presentation_coordinator.gd`. Host-facing
  Dictionary projection is delegated to `stage4_ponk_fx_context_builder.gd`; retained
  sheet caching and procedural fallback recipes are delegated to
  `stage4_ponk_fallback_fx_renderer.gd`; detached FX-host reference/prewarm/
  attach/sync/cleanup lifecycle is delegated to `stage4_ponk_fx_host_coordinator.gd`. The
  post-field projectile's mutable motion/collision/fade state and projection
  are delegated to `stage4_ponk_magnetic_projectile_state.gd`; cross-owner ball
  handoff and projectile-contact policy are delegated to
  `stage4_ponk_ball_interaction_coordinator.gd`. The runtime coordinator keeps
  same-tick field-to-projectile spawn/update order and FX reset sync.
  Meditation orbit/transient/release state is delegated to
  `stage4_ponk_meditation_state.gd`; the runtime coordinator keeps activation/
  release audio order, cross-skill updates, and reset FX lifecycle. Loop sound cleanup stays
  registered through `gameplay_loop_audio_cleanup.gd`. Three-card order,
  Korean display copy, trigger/status/progress projection, and fresh card
  snapshots are delegated to `stage4_ponk_skill_card_state_builder.gd`; the
  host retains the public HUD facade and live-owner assembly.
- `scripts/stages/stage4/stage4_ponk_ball_interaction_coordinator.gd`
  Owns stateless cross-owner gameplay sequencing for the public Stage 4 Ponk
  ball paths: active meditation control, meditation release, magnetic release,
  active curvature and speed capping, plus magnetic-projectile player contact.
  It also owns boss/player geometry normalization, base-speed dependency
  precedence, shared freeze gates, cleanse immunity, exact slow-status/scene
  annotations, hit counters, and collision-time loop-audio cleanup. It owns no
  RNG, mutable skill clocks, frame advancement, field/projectile activation,
  nodes, assets, or drawing; `stage4_ponk_skill_state.gd` retains thin public
  ball facades while the runtime coordinator owns update/activation orchestration.
- `scripts/stages/stage4/stage4_ponk_runtime_coordinator.gd`
  Owns stateful Ponk cross-owner runtime flow: shared gauge/ready/effect-clock
  scalars, score and boss-hit activation, forced activation, cooldown/pause/
  freeze policy, magnetic-field -> same-tick projectile -> meditation ->
  illusion order, audio dispatch, and full/round/stage reset sequencing. It
  directly requests all detached-host stops on lifecycle boundaries, including
  meditation on stage leave, while preserving the mixed pending-release,
  cooldown, gauge/clock, and illusion-unlock carry contracts. It holds focused
  owner references but owns no Nodes, RNG, drawing, payload arrays, or focused
  state clocks; the skill facade exposes thin methods and coordinator-backed
  scalar properties.
- `scripts/stages/stage4/stage4_ponk_presentation_coordinator.gd`
  Owns Ponk's presentation-only orchestration: fixed five-step static asset
  prewarm, draw-clock synchronization, pipeline/host status aggregation, exact
  magnetic-field/projectile/meditation/awaken-aura/illusion draw fanout,
  modular-host active gates, and deferred-host creation-frame fallback. It
  borrows the live runtime clock, four focused state owners, context builder,
  replaceable fallback renderer, and the same FX-host coordinator used by
  runtime cleanup. It owns no gameplay update/reset policy, RNG, audio, mutable
  skill payloads, or Nodes; the skill facade preserves public methods and
  private diagnostic seams as thin delegates.
- `scripts/stages/stage4/stage4_ponk_fx_host_coordinator.gd`
  Owns Ponk's four detached FX-host references and lifecycle: magnetic,
  meditation, illusion-ripple, and awaken-aura existing-child adoption,
  duplicate-safe deferred attachment, fixed four-step runtime-node prewarm,
  capability/runtime-asset gates, active sync, awaken-aura global cleanup
  registration, and immediate deactivation on round/stage/full reset. It keeps
  newly created hosts unattached for the creation frame so the presentation
  coordinator can retain its procedural fallback, and it owns no gameplay clocks, RNG, static
  asset-prewarm order, FX-context projection, reset ordering, or draw order.
- `scripts/stages/stage4/stage4_ponk_fx_context_builder.gd`
  Owns pure host-facing payload projection for magnetic field/projectile,
  meditation/release, illusion ripple, and awaken aura: exact Dictionary keys,
  state/default vs live-context precedence, progress/time/radius clamps,
  Vector2/Vector2i normalization, render-scale and view-size fallback, magnetic
  sheet-frame selection, meditation release trail/ball switching, and aura
  center/intensity. Top-level payloads are fresh while existing meditation
  trail arrays remain borrowed to avoid per-draw copies. It owns no nodes, RNG,
  audio, gameplay clocks, host lifecycle, static asset prewarm, or draw order.
- `scripts/stages/stage4/stage4_ponk_fallback_fx_renderer.gd`
  Owns the retained magnetic-field sheet cache/status and draw-only fallback
  recipes for magnetic field, magnetic projectile/fade, and meditation. It
  preserves circle/sheet/ring/core layer order, atlas-region slicing, shared
  frame/phase timing, shake, projectile fade alpha, meditation payload
  filtering, radius floors, and borrowed owner arrays. It owns no gameplay
  mutation, RNG, audio, modular-host lifecycle, or cross-effect fallback
  decisions; `stage4_ponk_presentation_coordinator.gd` keeps host-handled gating
  and order.
- `scripts/stages/stage4/stage4_ponk_illusion_state.gd`
  Owns Ponk illusion-ripple mutable state and pure projection: permanent
  four-point unlock, awaken stages 0-4, serve-wait transitions, the 180-frame
  first-cast countdown, one-shot 90-frame awaken burst, 240-frame active
  duration, 70-second automatic cooldown loop, round/stage/full-reset policy,
  enraged aura flag/intensity, and actor/debug snapshots. It owns no nodes,
  textures, audio, or cross-skill ordering; `stage4_ponk_skill_state.gd` keeps
  those responsibilities and exposes owner-backed compatibility properties.
- `scripts/stages/stage4/stage4_ponk_magnetic_field_state.gd`
  Owns Ponk's refraction magnetic-field mutable state and pure ball math:
  cooldown/activation gates, normal/enraged radius and duration, live boss
  center, curve-angle accumulation, rotated acceleration, per-frame speed
  growth, 2.2x base-speed cap, one-shot release-speed floor, round/stage/full
  reset policy, and actor/debug projection. It consumes no RNG and owns no
  audio, scene annotations, projectile state, or nodes; the ball-interaction
  coordinator retains base-speed lookup and release/curvature application order,
  while the runtime coordinator retains gauge side effects, projectile spawn/
  update order, and reset-time magnetic FX-host lifecycle.
- `scripts/stages/stage4/stage4_ponk_magnetic_projectile_state.gd`
  Owns Ponk's post-magnetic projectile mutable gameplay state and pure
  projection: spawn/radius floor, normal/enraged horizontal homing, vertical
  motion and contact slowdown, elapsed/velocity tracking, player-rect overlap,
  floor exit, fade capture/decay, reset policy, and actor/debug snapshots. It
  consumes no RNG and owns no status, audio, or nodes; the ball-interaction
  coordinator retains immunity and shared slow-status application, scene
  annotations, audio stop, and magnetic-field release order, while the runtime
  coordinator retains projectile spawn/update and reset-time magnetic FX-host
  lifecycle.
- `scripts/stages/stage4/stage4_ponk_meditation_state.gd`
  Owns Ponk meditation's mutable gameplay and pure projection: orbit position,
  trail/particle/circle lifecycle, borrowed shared-RNG particle gate/payload and
  release roll, cooldown, round/stage/full-reset policy, one-shot ball release,
  detached release-FX snapshot/clock, and actor/debug context. Construction and
  activation consume no RNG. The ball-interaction coordinator retains
  base-ball-speed lookup and scene flags/spin/cap; the runtime coordinator
  retains activation/release audio order, cross-skill frame order, and reset-
  time meditation FX-host lifecycle.
- `scripts/stages/stage4/stage4_ponk_skill_card_state_builder.gd`
  Owns pure Ponk boss skill-card projection: fixed magnetic-field, meditation,
  illusion-ripple order; Korean names/labels/descriptions; trigger metadata;
  ready/casting/charging/locked rules; normal cooldown and first-awaken
  countdown progress/seconds; and fresh card dictionaries. It reads the three
  focused runtime state owners without mutating them and owns no renderer,
  nodes, textures, audio, RNG, or gameplay clocks. `stage4_ponk_skill_state.gd`
  keeps the public HUD facade and supplies the clamped meditation trigger chance.
- `scripts/stages/stage4/stage4_ponk_magnetic_assets.gd`
  Owns shared Stage 4 Ponk magnetic-field asset metadata: the retained
  16-frame sheet path / grid / frame interval plus magnetic FX host texture
  paths for glyph, lattice, shard, ribbon, collapse, projectile, trail, and
  impact pieces. `stage4_ponk_skill_state.gd` and
  `stage4_ponk_magnetic_fx_host.gd` keep their public aliases and runtime
  cache / prewarm sequencing.
- `scripts/stages/stage4/stage4_ponk_skill_payload_factory.gd`
  Owns pure Stage 4 Ponk boss-skill payload construction for meditation
  trail, particle, and circle VFX dictionaries; their mutable lifecycle lives
  in `stage4_ponk_meditation_state.gd`.
- `scripts/stages/stage4/stage4_ponk_magnetic_fx_host.gd`
  Owns the Godot-native visual host for Ponk's refraction magnetic field:
  the Claude-provided charge glyph, shared `WritheEmberMaterial`
  `magnetic_charge_glyph` / `magnetic_lattice` preset backplates, retained
  16-frame magnetic-field sheet layer, three shader-scrolled arc-ribbon
  sprites, prism-shard `GPUParticles2D`, collapse burst, cyan / amethyst
  projectile orb, projectile trail sprite, impact burst, viewport-layout
  transform, and Tween-driven open lifecycle. The current PNG slots live under
  `res://assets/sprites/stage4/effects/` as
  `stage4_ponk_magnetic_charge_glyph_imagegen_v1.png`,
  `stage4_ponk_magnetic_lattice_imagegen_v1.png`,
  `stage4_ponk_magnetic_prism_shard_imagegen_v1.png`, and
  `stage4_ponk_magnetic_arc_ribbon_imagegen_v1.png`, with Phase 2 using
  `stage4_ponk_magnetic_collapse_burst_imagegen_v1.png`,
  `stage4_ponk_magnetic_projectile_orb_imagegen_v1.png`, and
  `stage4_ponk_magnetic_projectile_trail_imagegen_v1.png`, plus
  `stage4_ponk_magnetic_impact_burst_imagegen_v1.png`; gameplay timing
  remains in `stage4_ponk_skill_state.gd`.
- `scripts/stages/stage4/stage4_ponk_meditation_fx_host.gd`
  Owns the Godot-native visual host for Ponk's Vipassana meditation: the
  mandala PNG sprite driven by the shared `WritheEmberMaterial`
  `meditation_mandala` preset, procedural mandala fallback quad,
  shader-driven figure-eight trail lines, Claude-provided lotus / sutra /
  lock-burst / release-burst / release-trail texture slots with procedural
  fallbacks, mote / petal / release `GPUParticles2D` layers,
  viewport-layout transform, and Tween-driven open / breath / release flash
  lifecycle. The current PNG slots live under
  `res://assets/sprites/stage4/effects/` as
  `stage4_ponk_meditation_mandala_imagegen_v1.png`,
  `stage4_ponk_meditation_lotus_petal_imagegen_v1.png`, and
  `stage4_ponk_meditation_sutra_shard_imagegen_v1.png`, plus
  `stage4_ponk_meditation_lock_burst_imagegen_v1.png`,
  `stage4_ponk_meditation_release_burst_imagegen_v1.png`, and
  `stage4_ponk_meditation_release_trail_imagegen_v1.png`; gameplay timing
  remains in `stage4_ponk_skill_state.gd`.
- `scripts/stages/stage4/stage4_ponk_illusion_ripple_fx_host.gd`
  Owns the Godot-native full-screen screen-read host for Ponk's
  `illusion_ripple` / 몽환포영 awakening effect: absolute z-index 1272,
  `BackBufferCopy(COPY_MODE_VIEWPORT)`, fullscreen `ColorRect`,
  `hint_screen_texture` shader sampling, two-frequency sine-wave UV
  displacement, chromatic aberration, hue-wave color rotation, saturation
  breath, host-driven strength envelope, grace-timeout self cleanup, staged
  asset prewarm through `stage4_ponk_presentation_coordinator.gd`, and the
  boot PSO draw pass in `battle_pso_prewarmer.gd`. Gameplay unlock,
  `illusion_awaken_stage`, first-cast delay, duration, cooldown, and result /
  round cleanup ownership remains in the focused state/runtime owners.
- `scripts/stages/stage4/stage4_ponk_meditation_assets.gd`
  Owns shared Stage 4 Ponk meditation FX texture-path metadata for mandala,
  lotus, sutra, lock-burst, release-burst, and release-trail PNG slots.
  `stage4_ponk_meditation_fx_host.gd` keeps public aliases, texture caches,
  prewarm sequencing, shader setup, particles, and lifecycle tweens.
- `scripts/stages/stage5/stage5_hongryun_state.gd`
  Owns the first Stage 5 Hongryun runtime slice: Hongryun fireball counters,
  dragon-orb / inferno readiness state, ball-motion hijack query, boss-AI /
  actor-draw / boss-skill HUD context payloads, and the single cleanup core
  used by round-end, result-screen entry, and stage-leave reset paths.
  Fireball projectile and impact-event payload construction is delegated to
  `stage5_hongryun_payload_factory.gd`.
- `scripts/stages/stage5/stage5_hongryun_payload_factory.gd`
  Owns pure Stage 5 Hongryun boss-state payload construction for fireball
  projectile dictionaries and transient fireball-impact events consumed by the
  playfield renderer / VFX context.
- `scripts/stages/stage5/stage5_hongryun_pillar_background.gd`
  Owns the Stage 5 Hongryun pillar-background visual state: base / inferno
  texture prewarm, inferno blend fade, spiral burst and fire-impact transient
  lifetime updates, LOD-aware pillar heat tint, spiral arcs, fire impact arcs,
  and vignette drawing. Spiral-burst and fire-impact initial payloads are
  delegated to `stage5_hongryun_pillar_background_payload_factory.gd`.
- `scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd`
  Owns the Stage 5 Hongryun fire-machine map event state: cooldown / phase
  timing, dragon target locking, fire-stream progression, fire-zone lifetime,
  player dash extinguish / immunity parry / knockback collision side effects,
  audio cue dispatch, public update result fields, and actor-draw context
  snapshots. Initial dragon, stream, zone, flame, stream-particle, and smoke
  payload construction is delegated to
  `stage5_hongryun_fire_machine_payload_factory.gd`.
- `scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd`
  Owns Stage 5 Hongryun's boss skill-card HUD presentation: fireball /
  inferno card stacking, fallback skill-card textures, tooltip copy,
  dragon-orb fractional slot overlay, and the inferno charge wedge. It reads
  only the `stage5_boss_skill_hud_*` context emitted by
  `stage5_hongryun_state.gd`.
- `scripts/stages/stage5/stage5_pillar_scene_drawer.gd`
  Owns the Stage 5 pillar draw route: it delegates Hongryun-specific layered
  pillar / background art through the routed stage-background owner when
  available, falls back to the Stage 1 pillar background path when needed,
  reuses the Stage 1 shared pillar HUD chrome, and adds the Stage 5 Hongryun
  boss skill-card HUD in the post-playfield HUD pass.
- `scripts/stages/stage6/` — Stage 6 테트리서 / Tetriser cluster (port of Python
  Stage 7; Godot slot 6, see `docs/stage6_tetriser_port_plan.md`). Status:
  **complete through step 5c + boss sprite + static pillar background +
  crystal-shield boss skill; loading/result art pending**. Owners (21 modules):
  - `stage6_tetriser_state.gd` — single owner of boss gauge (max 500, 25/sec
    charge, round-persist via reset_round vs full reset), per-frame owner order,
    obstacle/starpoint/combat-feedback/player-explosion/event/context/HUD
    delegation, falling/guard/wall/super/central-cube/Crystal Shield delegation,
    and the single
    `_clear_combat_state` cleanup core. Emits boss-AI / actor-draw /
    `stage6_boss_skill_hud_*` HUD context.
  - `stage6_tetriser_tetromino_state.gd` — single owner of the falling
    tetromino shared-RNG cooldown and spawn rolls, canonical shape/color
    catalogs, assembly→discrete fall→drift/rotate→settle→cell evaporation,
    super-cell scaling and landing removal, installed-wall settling geometry,
    solid-cell collision/attack queries, ordered clear visitation, and copied
    draw/debug snapshots. It emits lifecycle callbacks synchronously so the
    starpoint owner's shared-RNG payload, feedback-owner debris/EMP/sounds, and
    player-explosion response retain their original frame and random-consumption
    order. The host must not keep parallel tetromino arrays, spawn timers, or
    motion functions.
  - `stage6_tetriser_obstacle_interaction.gd` — single owner of the ordered
    tetromino→guard→wall ball-collision policy, boss-serve penetration matrix,
    power-smash pass-through destruction, normal-ball super-tetromino bounce,
    reflection axis/min-speed/shared-RNG X jitter, and ordered dash/smoke/
    explosion attack sweeps. It mutates the focused obstacle owners and calls
    the event coordinator synchronously for starpoint/feedback owners and cube
    progress; the host must not restore parallel reflection or sweep policy.
  - `stage6_tetriser_starpoint_state.gd` — single owner of Stage 6 starpoint
    drop payload construction with the shared stage RNG, golden-block
    `star_dropped` one-shot mutation, motion/bounds/lifetime, Dowsing Pendulum
    attraction, player overlap and runtime-perk collection, stage-leave/reset
    cleanup, and deep-copied draw/debug snapshots. Combat event reactions remain
    synchronous in the event coordinator; the host must keep no drop-array or
    payload/motion/collection mirror.
  - `stage6_tetriser_combat_feedback_state.gd` — single owner of grouped debris
    flash geometry/lifetimes, EMP ripple lifetimes, copied renderer snapshots,
    and the six frame-scoped sound requests. Sound cues deduplicate within the
    frame and flush in legacy break→wall→super→big→shield→laser order, then clear
    even without an audio dependency. Round/result/stage-leave reset clears all
    feedback; the host must keep no parallel arrays, cue flags, or flush logic.
  - `stage6_tetriser_player_explosion_applier.gd` — stateless owner of the
    tetromino landing response applied to the player: scaled center-distance
    gate, Smasher cleanse immunity, Celestial Armor lookup/consumption, then
    stun followed by knockback. It preserves the 80px base radius, exact-edge
    inclusion, normal/super 30/54-frame stun, normal/super 12/24 knockback,
    18-frame window, 0.88 decay, and left/right direction rule. Range and
    cleanse gates must run before Celestial Armor consumption; the event
    coordinator keeps only the synchronous lifecycle-event call.
  - `stage6_tetriser_event_coordinator.gd` — synchronous cross-owner reaction
    owner for tetromino evaporation/landing/destruction, guard and wall removal,
    central-cube explosion, and super-laser fire. It preserves live obstacle
    visitation and shared-RNG starpoint order, then debris/EMP, sound,
    player-explosion, cube rebuild/melt order. It never advances time; the host
    retains frame ordering, reset policy, public gauge/status, and collision
    facade.
  - `stage6_tetriser_hud_state_builder.gd` — pure boss-skill HUD projection
    owner. It owns the fixed tetromino→guard→wall→super card order, display
    metadata, timer-based cost-card progress, gauge-gated ready/paused state,
    `next_activation_remaining`, and gauge-based super card state. The Stage 6
    host passes its live gauge/status plus focused owner timer snapshots and
    must retain no parallel card builders or HUD-only aliases.
  - `stage6_tetriser_context_builder.gd` — read-only actor and boss-AI context
    projection owner. It owns the stable public key maps and the existing base
    →super→Crystal Shield actor merge order plus base→Crystal Shield AI merge
    order. Focused owners retain snapshot-copy policy; this builder performs no
    additional deep copy, and the host retains only its two public facades.
  - `stage6_tetriser_guard_state.gd` — single owner of guard-bar shared-RNG
    cooldowns, one/pair spawn choice and side balancing, assembly→slide→active
    transitions, active collision lookup/removal, dash/smoke/explosion extraction,
    and copied draw/debug snapshots. The interaction owner consumes collision
    and sweep queries; the host retains public boss-gauge accounting while the
    event coordinator routes feedback, without a parallel guard array or
    cooldown mirror.
  - `stage6_tetriser_wall_state.gd` — single owner of edge-wall fixed cooldown,
    shared-RNG left/right tetromino-piece generation, assembly→installed→natural
    or hit-fast evaporation transitions, installed-cell collision/attack queries,
    tetromino-settling collision geometry, block transfer for cube/laser clears,
    and copied draw/debug snapshots. The interaction owner consumes collision
    and sweep queries; the host retains gauge while the event coordinator owns
    starpoint/feedback reactions, and must not keep parallel wall arrays or
    cooldown fields.
  - `stage6_tetriser_super_state.gd` — single owner of the 초인테트리서
    activation/drain/deactivation lifecycle, intro clock, body-scale transition,
    and super-scoped one-shot cube-laser charge/fire/linger cycle plus copied
    renderer snapshot. The Stage 6 host retains public boss gauge/status and
    activation sound; the event coordinator owns laser sound, cube melt,
    obstacle clear, EMP, and debris order without super or laser state mirrors.
  - `stage6_tetriser_cube_state.gd` — single owner of the 2D logical central
    cube: shared-RNG 3×3 grid/pass target, outside-to-inside ball pass edges,
    one-second solve delay and one-shot explosion event, player/dash-only
    five-destroy rebuild, laser-melt state, delta-driven spin/melt clocks, and
    copied draw/debug snapshots. The event coordinator consumes the explosion
    event to clear obstacles, delegate the center drop to the starpoint owner,
    and delegate debris/EMP to the feedback owner without restoring a parallel
    cube dictionary in the host.
  - `stage6_tetriser_crystal_shield_state.gd` — owner of the Tetriser Crystal
    Shield boss skill port from Python `CrystalShieldSystem`: player-score-4
    scheduling, next-serve formation freeze flag, 24 orbiting shield blocks,
    player-ball collision with hit+neighbor evaporation, radial reflection, and
    round/stage cleanup state.
  - `stage6_tetriser_playfield_renderer.gd` — draws cube / tetrominoes / guard
    bars / wall cells / debris / laser beam / EMP rings / Crystal Shield blocks
    (procedural; no art yet).
  - `stage6_tetriser_boss_actor_renderer.gd` — real AutoSprite boss sprite
    (7 sheets idle/walk/attack/dash/victory/defeat/stun under
    `assets/sprites/bosses/stage6_tetriser/`, 3-col 8-frame 256px grid),
    priority state machine (defeat>victory>stun>dash>attack>walk>idle),
    preserves `super_scale` growth + aura.
  - `stage6_tetriser_actor_renderer.gd` — orchestrates playfield + shared Stage1
    player/commando renderers + boss renderer (main draw entry).
  - `stage6_tetriser_pillar_background.gd` — static imagegen mood backdrop
    Loads
    `stage6_tetriser_pillar_bg_imagegen_v1.png`, cover-fits it behind the
    shared pillar HUD, and draws only a quiet playfield shade / edge boundary.
    Central cube is NOT drawn here (owned by the playfield renderer).
  - `stage6_tetriser_pillar_scene_drawer.gd` — background fanout + shared Stage 1
    pillar HUD chrome; live pillar Tetris wells were retired so HUD cards /
    dash-orb chrome remain the foreground read. It drives the boss skill-card
    HUD in `draw_post_playfield_hud` (merges state `get_hud_context`).
  - `stage6_tetriser_boss_skill_hud_renderer.gd` — 달지식 boss skill-card HUD
    (gauge + 낙하/가드/벽/초인 cards) via shared `BossSkillCardHudSpec`
    with Stage 6 Tetriser imagegen skill-card textures and staged prewarm.
  - `stage6_tetriser_boss_skill_hud_assets.gd` — focused card texture paths,
    fallback-color specs, staged prewarm, and cached texture lookup consumed by
    the Stage 6 boss-skill HUD renderer.
  - Integration touch points: `stage_runtime_router` (role map), `stage_debug_picker`
    (id 6, reset keys, prewarm), `gameplay_stage_module_catalog` (7 keys),
    `battle_update_stage_runtime_deps_builder` / `battle_update_boss_ai_context_builder`
    (`current_stage == 6`), `battle_effects_update_controller` (state.update),
    `battle_draw_actor_context` (actor draw merge), `ball_update_controller`
    (`_process_stage6_tetromino_collision`), `battle_playfield_effects_drawer`
    (inactive-transient stage list incl. 6), `battle_scene_match_event_driver`
    (`DEMO_STAGE_SEQUENCE_END = 6`), `game_audio` (stage6 BGM ogg + break/wall/
    roar SFX), `battle_scene_update_prewarm_driver` (`STAGE6_RUNTIME_PREWARM_KEYS`).
  - Regression guard: `tests/stage6_tetriser_context_builder_smoke.gd`,
    `tests/stage6_tetriser_event_coordinator_smoke.gd`,
    `tests/stage6_tetriser_hud_state_builder_smoke.gd`,
    `tests/stage6_tetriser_player_explosion_applier_smoke.gd`,
    `tests/stage6_tetriser_state_smoke.gd`,
    `tests/battle_scene_stage_transition_loading_smoke.gd`,
    `tests/battle_perf_logger_smoke.gd`, full warning/headless gate, and direct
    Stage 6 runtime serve capture.
- `scripts/stages/stage7/` — Stage 7 아카무 리고 / Akamu Rigo cluster (port of
  Python Stage 8 닌자 보스; Godot slot 7). Status: runtime, audio, render,
  skill-card HUD, prebattle video, result routing, and focused clone, shuriken,
  Cloud Veil, Stun/Net Escape, Superspeed, Awakening/Wind Aura, and shared
  boss-gauge/motion/freeze/Odin/presentation/HUD/context-state/timing-policy/
  geometry owners are present in the current worktree. Owners (26 current modules):
  - `stage7_akamu_state.gd` — owner of Awakening/Superspeed freeze-completion
    and audio / cross-skill orchestration, shared clone-bounce application,
    public boss-AI / actor-draw / HUD context facades, and compatibility
    facades for the focused state owners.
  - `stage7_akamu_gauge_state.gd` — owns the shared boss-gauge value,
    generation-guarded 0.7 score carry, normal/Awakened/Superspeed boss-hit
    rewards, capped positive rewards, external drains, ordinary-dash cost, and
    skill transaction result commits. `stage7_akamu_state.gd` retains the raw
    public property facade required by external item/character integrations and
    routes every internal mutation through this owner.
  - `stage7_akamu_motion_state.gd` — owns the single scripted boss-position
    publication boundary: Escape > Cloud Veil > clone > shuriken > debug
    priority, external writer/conflict state, one-frame final-position release,
    clone/shuriken Odin knockback-yield and stun-residual parity, and composite
    clone/external ball-intangibility sources. Skill owners still calculate
    their own trajectories; `stage7_akamu_state.gd` supplies their snapshots
    and retains the public compatibility/context facades.
  - `stage7_akamu_presentation_state.gd` — owns the 0.2-second boss attack-pose
    clock/source/target and the single actor/HUD status-priority projection from
    gameplay freeze through Escape, Cloud Veil, Superspeed, pause, casts,
    lingering entities/debuffs, Wind Aura, and charging. Gameplay owners retain
    skill timing; `stage7_akamu_state.gd` supplies typed state snapshots without
    allocating a per-frame Dictionary and keeps the public `status` facade.
  - `stage7_akamu_freeze_state.gd` — owns the atomic gameplay-freeze remaining
    time/reason pair, begin/cancel/reset lifecycle, and one-shot completed-reason
    edge. `stage7_akamu_state.gd` retains public frame-flow methods and advances
    Awakening/Superspeed visuals plus reason-specific completion side effects.
  - `stage7_akamu_odin_cc_state.gd` — owns the read-only per-update Odin boss-CC
    snapshot and its non-instantiating lookup precedence: direct injected swamp
    state, provided mythic runtime, then one registry `get_cached_instance`
    peek. It publishes knockback-window velocity, independent stun residual,
    and the pre-AI Escape rewind value to the motion/Escape orchestration.
  - `stage7_akamu_hud_state_builder.gd` — owns pure boss-skill card projection:
    clone → shuriken → Cloud Veil → Superspeed ordering, shared pause state,
    per-card cross-skill/writer blocking, and calls into each skill owner's
    existing `build_hud_skill` contract. The facade retains top-level boss/gauge
    context publication and the routed HUD renderer retains all drawing.
  - `stage7_akamu_context_builder.gd` — owns pure boss-AI and actor-draw context
    assembly. It preserves the live clone, shuriken, Wind Aura burst, and other
    render-payload array identities instead of deep-copying per-frame data;
    `stage7_akamu_state.gd` retains the public context facade and supplies typed
    owner snapshots.
  - `stage7_akamu_timing_policy.gd` — owns pure cross-feature timing gates:
    inactive/serve/global/item/perk/character gameplay freezes, direct Star
    Coil pause, canonical active-item pause with legacy Tear Gas fallback, and
    the one-shot active-item runtime context fallback. Wind Aura retains its
    historical direct-context-only pause lookup through the same policy.
  - `stage7_akamu_geometry_state.gd` — owns the last-known boss position, size,
    and visual-scale snapshot shared by live updates, freeze visuals, Awakening,
    Wind Aura collision, and Superspeed. It preserves typed `boss_paddle_size`
    precedence, legacy width/height fallback, invalid-type cache retention, and
    the shipped 0.2–1.0 visual-scale clamp.
  - `stage7_akamu_clone_state.gd` — owns shadow-clone cast/cooldown state,
    transactional gauge commit, normal/awakened entity spawn, deterministic
    motion, emerge/fade/natural-expiry and hit-death lifecycles, swept collision
    geometry, invulnerability buffer, HUD projection, and transient cleanup.
    `stage7_akamu_state.gd` retains shared paddle-bounce application, auxiliary
    contact side effects, and compatibility facades; the motion coordinator
    composes clone intangibility and scripted-position ordering.
  - `stage7_akamu_shuriken_state.gd` — owns shuriken cooldown scheduling,
    casting/pending awakened volley, projectile motion and swept collision,
    smoke absorption, cleanse/slow/gauge-drain results, hit particles, HUD
    projection, and round-transient cleanup. `stage7_akamu_state.gd` keeps the
    compatibility facade plus shared gauge and attack-pose coordination; the
    motion coordinator owns scripted-position composition.
  - `stage7_akamu_cloud_state.gd` — owns Cloud Veil trigger/cooldown and gauge
    commit, precast/down/up motion state, field spawn/alpha/expiry lifecycle,
    landing audio boundary, post-dash invulnerability buffer, render payloads,
    HUD projection, and transient cleanup. `stage7_akamu_state.gd` keeps the
    compatibility facade plus boss attack-pose publication; the motion
    coordinator owns release delivery and intangibility-source composition.
  - `stage7_akamu_escape_state.gd` — owns Stun/Net Escape episode detection,
    net-delay and one-roll scheduling, disable-context collection/cleanup,
    Odin knockback rewind application, gauge commit, target selection, ease-out
    motion, fixed-scale ghosts/hologram, and transient cleanup.
    `stage7_akamu_state.gd` keeps compatibility fields plus boss attack-pose
    publication; the motion coordinator owns release delivery and composite
    intangibility-source coordination.
  - `stage7_akamu_superspeed_state.gd` — owns Superspeed activation eligibility
    and gauge result, duration/cooldown state, dash metadata notifications,
    afterimage/dark-particle/trail render payloads, HUD projection, and
    full-vs-round cleanup. `stage7_akamu_state.gd` keeps compatibility fields
    plus cross-skill cancellation, gameplay-freeze orchestration, and shared
    context publication; predictive paddle movement remains in shared BossAI.
  - `stage7_akamu_awakening_state.gd` — owns the score-threshold trigger and
    intro flags, persistent Awakening state, Wind Aura collision/reflection
    decision, five-hit durability, ten-second recharge, free-skill roll
    decisions/queued-clone flag, persistent/burst particle payloads, draw-context
    projection, and full-vs-round cleanup. `stage7_akamu_state.gd` keeps
    compatibility fields plus gameplay-freeze, audio, gauge commit, and actual
    Cloud Veil/shadow-clone execution orchestration.
  - `stage7_akamu_actor_renderer.gd` / `stage7_akamu_boss_actor_renderer.gd` /
    `stage7_akamu_playfield_renderer.gd` / `stage7_akamu_pillar_background.gd` /
    `stage7_akamu_pillar_scene_drawer.gd` / `stage7_akamu_boss_skill_hud_renderer.gd`
    (+ `_boss_skill_hud_assets.gd`, `_vfx_texture_cache.gd`) — render cluster;
    the skill-card gauge uses the shared
    `boss_skill_card_hud_spec.draw_skillcard_gauge_fill` cover-crop helper.
  - `stage7_akamu_prebattle_presentation.gd` /
    `stage7_akamu_prebattle_overlay_host.gd` — prebattle intro video state,
    overlay host, catalog route, input/modal/readiness gates, teardown, and
    transition cleanup.
  - Sprite contract: nine 4x2 sheets (dash is native left/right, mirroring
    forbidden) — `docs/sprites/stage7_akamu_rigo.md` +
    `stage7_akamu_boss_sprite_manifest.json`.
  - Regression guard: `tests/stage7_akamu_slice1_smoke.gd` (routing, deps,
    score-carry, freeze, collision + intangibility, prewarm dispatch,
    overdrive committed-bounce gating, result-reset fanout) +
    `tests/stage7_akamu_audio_smoke.gd` +
    `tests/stage7_akamu_clone_state_refactor_smoke.gd` +
    `tests/stage7_akamu_shuriken_state_refactor_smoke.gd` +
    `tests/stage7_akamu_cloud_state_refactor_smoke.gd` +
    `tests/stage7_akamu_escape_state_refactor_smoke.gd` +
    `tests/stage7_akamu_superspeed_state_refactor_smoke.gd` +
    `tests/stage7_akamu_awakening_state_refactor_smoke.gd` +
    `tests/stage7_akamu_gauge_state_refactor_smoke.gd` +
    `tests/stage7_akamu_motion_state_refactor_smoke.gd` +
    `tests/stage7_akamu_presentation_state_refactor_smoke.gd` +
    `tests/stage7_akamu_control_state_refactor_smoke.gd` +
    `tests/stage7_akamu_hud_state_builder_refactor_smoke.gd` +
    `tests/stage7_akamu_context_builder_refactor_smoke.gd` +
    `tests/stage7_akamu_timing_policy_refactor_smoke.gd` +
    `tests/stage7_akamu_geometry_state_refactor_smoke.gd` +
    `tests/boss_skill_card_shuffle_motion_smoke.gd`; later slices own the
    remaining `stage7_akamu_*` smokes.
- `scripts/stages/stage4/stage4_bird_event.gd` and
  `scripts/stages/stage4/stage4_brazier_monk_event.gd`
  Own the first Stage 4 event runtime slice. `stage4_bird_event` handles
  star-bird spawn timing / movement, gold-dust trail updates, catch
  positions, catch side effects, starpoint rendering/host cleanup, and
  draw-context export; starpoint state is delegated to
  `stage4_bird_starpoint_state.gd`, while star-bird, gold-dust, fragment, and
  debris-particle payload construction is delegated to
  `stage4_bird_payload_factory.gd`.
  `stage4_brazier_monk_event` handles normal monk spawning, five
  smoke-grenade monks from the lit brazier, monk return timing, collapse
  cleanup explosions, staff-swing trigger / deflection timing, monk-hit
  effects, full draw-context export, and live-array/visual-time renderer facade;
  monk default payloads, staff hit-effect payloads, and monk explosion particle
  payloads are delegated to `stage4_brazier_monk_payload_factory.gd`.
  `stage4_brazier_monk_renderer.gd` owns the three temple-ghost sheet caches,
  deterministic walk/attack frame and hover projection, transform-safe UV flip,
  procedural actor/staff fallback, and capped hit/death presentation. The map-state and pillar
  background facades forward smoke / brazier, tear-gas expiry, star-bird
  collision, monk staff collision, moon-fragment collision, and draw-context
  access so shared active-item and ball-runtime code do not need to know the
  event storage details.
- `scripts/stages/stage4/stage4_bird_starpoint_state.gd`
  Owns retained Stage 4 star-bird drop/particle collections, crow and Star
  Detector spawn/clamping, borrowed shared-RNG payload order, caps, motion,
  Dowsing and Starlight Tracking, circular paddle overlap, modal-safe
  compaction, reward/particle/audio/redraw sequencing, and particle advancement.
  The bird event keeps owner-backed compatibility accessors/methods plus draw
  and detached-host cleanup responsibilities.
- `scripts/characters/smasher_magnum_grip_state.gd`
  Owns the Godot Smasher Magnum Grip port: 300ms left+right hold
  activation, gauge/cooldown spend through the shared skill state, 2.5s
  active lifetime, per-frame ball pull toward the player paddle, particle
  state, pulled-ball player-hit speed-cap handoff up to 45 effective
  speed, player-hit/round-reset cleanup, and draw context for the shared
  Smasher skill feedback renderer.
- `scripts/characters/smasher_dash_spirit_state.gd` and
  `scripts/characters/smasher_dash_spirit_renderer.gd`
  Own the Godot Smasher Dash Spirit perk port: `dash_spirit` Lv.1-5
  chance consumption from runtime perks, Python-parity dash-origin laser
  spawning, 360-frame laser lifetime, 10-frame spawn invulnerability,
  electric jitter state, ball-block reflection / one-shot laser removal,
  delete-sound feedback, evaporation particles, round/game reset cleanup,
  and playfield draw delegation.
- `scripts/characters/smasher_shield_kiting_state.gd` and
  `scripts/characters/smasher_shield_kiting_renderer.gd`
  Own the Godot Smasher Shield Kiting port: SPACE / left-click action
  double-tap activation, `unlock_shield_kiting` equipped-skill gating,
  130-gauge / 12-second shared cooldown spend, Python-parity wind-up
  timing tiers, hand-position movement lock until launch, homing shield
  projectile travel / return, shield hit sound and 1.3x ball speed burst,
  15 perk-gold skill reward, plasma hit effects, round/game reset cleanup,
  and playfield draw delegation.
- `scripts/characters/smasher_plasma_state.gd`
  Owns the Godot Smasher Plasma port: W / Up hold charging,
  0.5-second minimum-release refund, gauge drain and cooldown spend,
  charge / shoot / contact audio sync, homing plasma-wave motion and payload
  simulation/RNG, boss slow context for AI movement plus shared boss slow
  status application, Stage 1 boss-gauge and Hongryun orb-gauge drain hooks,
  modular-host state projection, and round/game-reset cleanup. Its two draw
  facades sample one visual clock each and lend three typed live arrays.
- `scripts/characters/smasher_plasma_renderer.gd`
  Owns eight-step flare/shockwave/modular-host/node-pipeline prewarm and the
  immediate-mode fallback presentation: player-anchored charge field, homing
  wave/trail/particles, and boss-contact distortion overlay. It receives
  explicit time/state/geometry and owns no charging, gauge/cooldown, boss
  mutation, slow policy, audio, simulation, RNG, or retained arrays.
- `scripts/characters/smasher_recovery_state.gd`
  Owns the Godot Smasher Recovery port: W / Up edge activation only during
  dash recovery, 120-gauge / shared-cooldown spend, immediate dash-recovery
  timer cleanup, dash-delay sound cancel, `recovery.wav` cast cue, 18-frame
  green-burst and moving-trail payload creation/simulation/RNG, 5-second 50%
  movement-speed boost, `extension_gear` duration scaling, and round/game-reset
  cleanup. Its draw facade samples one visual clock and lends three typed arrays.
- `scripts/characters/smasher_recovery_renderer.gd`
  Owns staged flare/shockwave-cache prewarm and Recovery presentation: moving
  light trail, cast glow/rings/sparkles, and shared right-bottom timer-stack
  drawing. It receives explicit timing/state and owns no activation, cooldown,
  dash cleanup, duration scaling, audio, simulation, RNG, or retained arrays.
- `scripts/characters/smasher_cleanse_state.gd`
  Owns the Godot Smasher Cleanse port: W / Up edge activation only while a
  player status effect is present, 100-gauge / shared-cooldown spend,
  `cleanse.wav` cast cue, current movement-knockback cleanup and immunity
  blocking, 30-frame purification-wave / particle simulation and RNG, 5-second
  immunity with `extension_gear` duration scaling, 2-second one-hit counter
  speed bonus, skill-orb debuff-ready gating, and round/game-reset cleanup. Its
  draw facade samples one visual clock and lends the two typed live arrays.
- `scripts/characters/smasher_cleanse_renderer.gd`
  Owns Cleanse presentation and render-resource prewarm: flare/shockwave caches,
  cast flash/rings/sparkles, immunity-shield projection, and the shared right-
  bottom timer-stack recipe. It receives explicit state/timing/geometry and owns
  no activation, cooldown, effective-level, status, simulation, or RNG behavior.
- `scripts/characters/smasher_warp_gate_state.gd`
  Owns the Godot Smasher Warp Gate port: S / Down 0.5-second hold
  activation, 100-gauge / 50-second shared cooldown spend, 20-second
  gate lifetime with `extension_gear` duration scaling, free wall-wrap
  transitions, offscreen movement bounds, mirrored player paddle collision /
  actor draw context, round-pause remaining-duration resume, portal payload
  spawn/expiry, `warpgate.wav` loop sync, feedback, and round/game-reset
  cleanup. Its draw facade samples one visual clock and lends the typed live
  portal array without copying; lifecycle exits directly hide retained FX.
- `scripts/characters/smasher_warp_gate_presentation.gd`
  Owns staged flare/shockwave/FX-host prewarm, detached-host adoption/deferred
  attachment/direct hiding, game-to-screen active/burst portal projection,
  modular node-FX synchronization, the complete procedural fallback, and the
  shared index-0 right-bottom timer-stack recipe. It receives explicit time,
  phase, player geometry, layout, and borrowed portals, and owns no activation,
  cooldown, effective duration, wrapping, audio, feedback, payload mutation,
  or RNG.
- `scripts/characters/smasher_wheel_state.gd` and
  `scripts/characters/smasher_wheel_cloud_fx_host.gd`
  Own the Godot `풍운천선무` port (compatibility id `smasher_wheel`):
  A->W->D / D->W->A edge-command
  activation, 200-gauge / 25-second shared cooldown spend, 1.2-second
  rolling movement mode with dash blocking, command-locked one-way travel,
  -15% max speed, one-hit high-speed random
  curve relaunch with a difficulty-independent 60 effective-speed cap,
  non-drive spin state, 30 perk-gold skill reward,
  dedicated 4x4 body-spin sheet, drive-particle trail handoff, right-bottom
  timer-gauge feedback, and round/game-reset cleanup. The state owns gameplay,
  burst serial/contact coordinates, and screen-layout handoff; the controller-
  driven host owns the prewarmed static cloud piece, nine widening orbit
  sprites, continuous swirl particles, contact scatter burst, and direct hide /
  emission cleanup without an independent process loop.
- `scripts/characters/viper_jetpack_state.gd`
  Owns the Godot Viper jetpack / hover port: SPACE / left-click hold input,
  Python-parity 200px rise/fall height, effective-level
  `jetpack_enhance` hold scaling above Lv.5, overheat/recharge state,
  actual player Y-position handoff for paddle collision, copied
  `jetpack.wav` loop sync, flame/smoke actor draw context, height-scaled
  airborne movement boost up to 3.15x max speed / acceleration, Air Strike
  1.15x player-hit speed bonus, height-based gauge bonus,
  `jetpack_enhance` airborne gauge bonus, 3-gold skill reward, Chaos
  Spear airborne activation gating, and round/game reset cleanup.
- `scripts/characters/runtime_perk_catalog.gd`,
  `scripts/characters/runtime_perk_state.gd`,
  `scripts/characters/runtime_perk_character_context.gd`,
  `scripts/characters/runtime_perk_registry_lookup.gd`,
  `scripts/characters/runtime_perk_gamepad_navigation.gd`,
  `scripts/characters/runtime_perk_modal_input.gd`,
  `scripts/characters/runtime_perk_choice_selection.gd`,
  `scripts/characters/runtime_perk_snapshot_builder.gd`,
  `scripts/characters/runtime_perk_fusion_runtime_state.gd`,
  `scripts/characters/runtime_perk_mystic_dice_runtime_state.gd`,
  `scripts/characters/runtime_perk_physique_training_runtime_state.gd`,
  `scripts/characters/runtime_perk_hyeonmun_charyeok_runtime_state.gd`,
  `scripts/characters/runtime_perk_angel_blessing_runtime_state.gd`,
  `scripts/characters/runtime_perk_choice_pipeline_state.gd`,
  `scripts/characters/runtime_perk_unlock_pipeline_state.gd`,
  `scripts/characters/runtime_perk_display_projection_state.gd`,
  `scripts/characters/runtime_perk_choice_audio.gd`,
  `scripts/characters/runtime_perk_choice_feedback.gd`,
  `scripts/characters/runtime_perk_choice_offer_modifiers.gd`,
  `scripts/characters/runtime_perk_choice_opening.gd`,
  `scripts/characters/runtime_perk_choice_completion.gd`,
  `scripts/characters/runtime_perk_choice_dispatch.gd`,
  `scripts/characters/runtime_perk_choice_action_runner.gd`,
  `scripts/characters/runtime_perk_choice_standard_path.gd`,
  `scripts/characters/runtime_perk_choice_open_flow.gd`,
  `scripts/characters/runtime_perk_choice_apply_flow.gd`,
  `scripts/characters/runtime_perk_choice_confirm_flow.gd`,
  `scripts/characters/runtime_perk_choice_finish_flow.gd`,
  `scripts/characters/runtime_perk_update_flow.gd`,
  `scripts/characters/runtime_perk_debug_grants.gd`,
  `scripts/characters/runtime_perk_unlock_choice_apply.gd`,
  `scripts/characters/runtime_perk_owner_projection.gd`,
  `scripts/characters/runtime_perk_owner_sync_flow.gd`,
  `scripts/characters/runtime_perk_choice_layout.gd`,
  `scripts/characters/runtime_perk_active_unlock_flight.gd`,
  `scripts/characters/runtime_perk_unlock_showcase.gd`,
  `scripts/characters/runtime_perk_unlock_showcase_flow.gd`,
  `scripts/characters/runtime_perk_unlock_swap_layout.gd`,
  `scripts/characters/runtime_perk_unlock_swap_flow.gd`,
  `scripts/characters/runtime_perk_skill_cooldown_pause.gd`,
  `scripts/characters/runtime_perk_deferred_instants.gd`,
  `scripts/characters/runtime_perk_effective_levels.gd`,
  `scripts/characters/runtime_perk_effective_stat_query_surface.gd`,
  `scripts/characters/runtime_perk_dynamic_effects.gd`,
  `scripts/characters/runtime_perk_instant_rewards.gd`,
  `scripts/characters/runtime_perk_instant_choice_flow.gd`,
  `scripts/characters/runtime_perk_level_side_effects.gd`,
  `scripts/characters/runtime_perk_lingpet_rewards.gd`,
  `scripts/characters/runtime_perk_owner_effect_sync.gd`,
  `scripts/characters/runtime_perk_resume_safety.gd`,
  `scripts/characters/runtime_perk_starpoint_absorption.gd`,
  `scripts/characters/runtime_perk_starpoint_collection_flow.gd`,
  `scripts/characters/runtime_perk_gold_awards.gd`,
  `scripts/characters/runtime_perk_gold_award_flow.gd`,
  `scripts/characters/runtime_perk_reset_state.gd`, and
  `scripts/hud/runtime_perk_overlay_renderer.gd`
  Own the first Godot runtime perk / starpoint choice port: starpoint-to-
  pending-choice state, current-run perk levels, character-filtered offer
  construction, center-screen card selection, keyboard/mouse interaction,
  pending unlock-swap dialogs for slot-full Commando firearm unlocks,
  cancel no-op semantics,
  basic immediate effects including 풀게이징 / 차원개방, and reset wiring.
  Commando unlock choice cards, pending firearm-swap dialogs, and debug
  grant feedback use catalog / skill-config Korean display names instead
  of leaking `soldier_*` internal ids.
  Shared dash scaling perks now include `dash_acceleration` / 대붕전익: the
  runtime state exposes level * 70% dash collision-height scaling plus
  level * 10% centered collision-width scaling, and keeps effective Lv.6+
  bonus sources live instead of hard-capping at the base Lv.5 card text.
  Common scaling perks now include `perk_laurel_shield` / 월계수잎; its
  effective level is exposed as a live leaf count and intentionally keeps
  scaling above Lv.5 when runtime perk-level bonuses apply.
  The overlay renderer owns the per-character filled card back glow used by
  runtime perk choice cards, and Stage 1 through Stage 4 starpoint collectors
  stop same-frame drop iteration when a collection opens a perk choice or
  clears the in-flight drop arrays.
  `runtime_perk_character_context.gd` owns runtime perk character-context
  lookup policy: character id alias normalization, skill config / state
  registry-key routing, owner-selected character fallback behavior, current
  stage reads, and starting dash-token fallback through `battle_scene_config`.
  `runtime_perk_state.gd` keeps narrow private wrapper names for existing
  call sites while delegating the policy to this helper.
  `runtime_perk_registry_lookup.gd` owns runtime perk registry instance lookup
  policy: null / empty-key / missing-API rejection, generic `get_instance`
  routing, and the runtime-perk catalog shortcut. `runtime_perk_state.gd` keeps
  the `_get_instance()` / `_get_catalog()` callback wrapper names for existing
  helper facades while delegating lookup policy to this helper.
  `runtime_perk_gamepad_navigation.gd` owns runtime perk modal gamepad
  horizontal-latch policy for choice cards and unlock-swap cards: left-stick
  neutral reset, held-direction suppression, sub-threshold latch retention, and
  non-left-axis passthrough, plus runtime-state navigation facades for both
  choice and unlock-swap latch fields. `runtime_perk_modal_input.gd` owns runtime perk
  modal input event routing for choice cards and pending unlock-swap dialogs:
  keyboard / gamepad / mouse classification, active-flight and unlock-showcase
  input gating, mouse hit-index callback routing, confirm / cancel dispatch, and
  runtime-state callback-map assembly. `runtime_perk_state.gd` keeps the choice and
  unlock-swap latch fields plus narrow private wrappers for selection,
  confirmation, cancellation, hit testing, and showcase dismissal.
  `runtime_perk_choice_selection.gd` owns choice-card selected-index updates:
  keyboard / gamepad wrap movement, direct mouse hover / click index validation,
  runtime-state choice-count extraction for move / direct selection facades,
  runtime-state selectable gating across choice flight / unlock showcase /
  pending swap / animation age / choice count, empty-choice rejection,
  state-field application, and
  selected-choice payload validation for choice confirmation.
  `runtime_perk_state.gd` keeps card hit testing wrappers and choice
  confirmation side-effect execution.
  `runtime_perk_snapshot_builder.gd` owns runtime perk modal snapshot
  assembly for HUD / overlay consumers: deep-copied level, choice, unlock-swap,
  context, slot-status, flight / showcase, deferred-instant, and absorption
  payload fields plus runtime-state helper lookup for the public snapshot
  facade. Its last-selected choice snapshot API is kept as a compatibility
  wrapper around `runtime_perk_choice_completion.gd`.
  `runtime_perk_state.gd` keeps the live fields and exposes the public
  `get_snapshot()` wrapper.
  `runtime_perk_fusion_runtime_state.gd` owns the lazy lifetime and cohesive
  behavior of the fusion core state, byproduct transient runtime, and offer
  planner. It owns commit/restore/query delegation, catalog-aware max-level
  result context, fail-closed offer planning, production offer injection,
  deterministic one-shot offer rolls, byproduct speed/gold/point-loss
  calculations, round reset, and full-reset cleanup. Offer injection performs
  source/candidate/lane eligibility before consuming RNG or its test seam, then
  writes an appeared replacement back to runtime choices. It also owns modal
  flow/input/catalog lifetime, candidate construction, frozen-catalog
  authority, S0 start/input/cancel, S2 result RNG/build plus core commit, S4
  common-choice-finish handoff, preview-cache reset boundaries, and direct
  cold-boot host shutdown. Missing runtime/common-finish dependencies fail
  closed before S2 commit. `runtime_perk_state.gd` retains the open-flow
  callback position that enforces fusion-before-training order, modal priority,
  public gameplay facades, snapshot/preview presentation composition, the
  common choice-finish implementation, and the final global `gold_from_perks`
  mutation. The owner-backed `_perk_fusion_modal_flow`,
  `_perk_fusion_modal_input`, `_perk_fusion_modal_catalog`, and
  `_test_perk_fusion_offer_roll_override` properties
  preserve string lookup and focused-test replacement without parallel state.
  The match-finished point-loss
  facade must pass a non-random sentinel so clearing stale pending effects does
  not consume the next gameplay RNG value. Regression guard:
  `tests/runtime_perk_fusion_runtime_state_refactor_smoke.gd`.
  `perk_fusion_reverb_vfx_state.gd` owns Reverb's activation flash, capped
  direction-aware movement echoes, active wind seal, player sampling, and
  visual cleanup. `perk_fusion_byproduct_runtime.gd` alone triggers and
  advances it from the canonical Reverb timer; the shared playfield draw fanout
  consumes it, and `battle_scene_runtime_perk_update_driver.gd` routes its
  visible-tick redraw requests through `request_battle_redraw()`.
  `runtime_perk_mystic_dice_runtime_state.gd` owns the lazy lifetime and
  cohesive behavior of Mystic Dice permanent raw/use-count state, the roller,
  offer planner, modal flow/input, and paddle-effect state/host binding. It owns
  deterministic or production roll generation, fail-closed offer planning,
  D0 modal start, input/action routing, rerolls, accepted raw commit,
  ordinary/mythic owner synchronization, common choice-finish handoff, new-run
  reset, detached-host cleanup, and the modal-to-first-physics-tick pending
  boundary that starts the three-second effect without consuming blocked-modal
  time. `runtime_perk_state.gd` retains the D0 interception position,
  modal-update/input priority, and public facades. Its planner, pending, and
  modal flow/input compatibility properties forward old lookup/test seams into
  the owner and must not become duplicate storage. Missing runtime, owner-sync,
  or common-finish dependencies fail closed before raw commit so a Dice use
  cannot be partially consumed. Regression guard:
  `tests/runtime_perk_mystic_dice_runtime_state_refactor_smoke.gd`.
  `runtime_perk_physique_training_runtime_state.gd` owns the cohesive lifetime
  of the Physique Training catalog, run state, offer planner, and probe-only
  bonus override. It owns final active-item/Chosik cooldown, dash recharge/
  recovery, and posture saturation probes; dedicated choice commit plus
  ordinary/mythic consumer synchronization; and the 60% replacement offer with
  fusion-first and no-op RNG ordering. `runtime_perk_state.gd` retains public
  and save facades. Its writable computed catalog/state/planner properties
  preserve string lookup and focused-test seams without parallel storage.
  Regression guards:
  `tests/runtime_perk_physique_training_runtime_state_refactor_smoke.gd` and
  `tests/physique_training_category_smoke.gd`.
  `runtime_perk_hyeonmun_charyeok_runtime_state.gd` owns the cohesive lifetime
  of the Hyeonmun state machine and timer renderer plus raw invested-level proc,
  refresh/expiry/round-reset orchestration, Transcendent Crown composition,
  canonical `item_perk_level_bonus` publication, and cached-consumer refresh on
  both bonus activation and removal. `runtime_perk_state.gd` retains public
  gameplay/draw facades and writable computed state/renderer compatibility
  properties without parallel storage. Regression guards:
  `tests/runtime_perk_hyeonmun_charyeok_runtime_state_refactor_smoke.gd` and
  `tests/hyeonmun_charyeok_runtime_smoke.gd`.
  `runtime_perk_angel_blessing_runtime_state.gd` owns the five Angel feature
  lifetimes: core blessing state, character cooldown-capability selector, stage
  lifecycle, modal flow, and acquisition lifecycle. It owns core roll/query,
  capability, stage-intro, accepted-choice, acquisition-finished, and core-reset
  delegation plus the public perk/policy vocabulary used by the facade. It also
  owns acquisition snapshot/work queries, update/input routing, higher-priority
  blocker resolution, current-stage roll/reveal, cinematic-completion release,
  deferred-choice resume/finalization, Angel audio handoff, and round/stage
  cleanup. A banked ordinary runtime choice must reopen before a ready Angel
  reveal after scoreboard release. `runtime_perk_state.gd` retains cross-feature
  spawn-intro ordering, public APIs/input priority, and the shared
  choice/cooldown/owner-sync callback implementations. Its computed
  `_angel_blessing_state` and
  `_angel_blessing_modal_flow` properties preserve existing
  `RuntimePerkRuntimeStateAccess`, effective-stat, reset, acquisition, and test
  consumers without becoming second storage locations. Regression guard:
  `tests/runtime_perk_angel_blessing_runtime_state_refactor_smoke.gd`.
  `runtime_perk_choice_pipeline_state.gd` owns the nine helper
  lifetimes that implement the common choice pipeline: selection, completion,
  dispatch, action execution, standard level path, open, apply, confirm, and
  finish. `runtime_perk_state.gd` retains the public transaction orchestration
  and source-contract type aliases. Its writable computed `_choice_*`
  properties forward both production string lookup and focused-test injection
  into the owner; they must never become parallel helper storage. The finish
  helper is intentionally stateful: it owns the last committed Mystic Dice and
  Fusion revisions and rejects duplicate D3/S4 finish calls before any common
  choice state or side effect is consumed. Regression
  guard: `tests/runtime_perk_choice_pipeline_state_refactor_smoke.gd`.
  `runtime_perk_unlock_pipeline_state.gd` owns the six helpers that implement
  active-unlock flight, showcase presentation flow, and slot-full unlock swap:
  flight state, showcase controller/flow, swap layout/flow, and unlock-choice
  apply. `runtime_perk_state.gd` keeps the live flight/showcase/swap payloads,
  public wrappers, and transaction ordering. Writable computed compatibility
  properties preserve reset helpers, production string lookup, and focused-test
  replacement without parallel helper storage. Regression guard:
  `tests/runtime_perk_unlock_pipeline_state_refactor_smoke.gd`.
  `runtime_perk_display_projection_state.gd` owns runtime perk display cache
  state and projection infrastructure: default catalog and projector lifetime,
  the composite perk-fusion plus Mystic Dice cache signature across level hash,
  fusion/Dice revision, locale, dynamic level bonuses, and catalog identity,
  live pre-fusion and production-adjusted option projection, cache-hit/build
  accounting, dedicated Dice projection, fusion-modal outcome/source preview
  construction and caching, and explicit reset invalidation. Modal preview reuse
  is keyed by selected sources, modal phase, and fusion revision, with explicit
  invalidation at start/cancel/finish/full-reset boundaries.
  Cache hits compare the seven signature scalars directly; the public
  `cache_signature` hash Array is built only after a miss, so repeated HUD/TAB
  reads do not allocate that temporary Array.
  `runtime_perk_state.gd` retains live projection inputs, fusion snapshot
  presentation composition, and public projection/cache-stat facades. Regression guard:
  `tests/runtime_perk_display_projection_state_refactor_smoke.gd`.
  `runtime_perk_choice_audio.gd` owns runtime perk choice-modal one-shot audio
  routing: active-unlock flight cue priority (`play_item_get` before the
  runtime choice-open fallback), ordinary perk-select confirmation audio, and
  runtime-state-facing get-instance callback assembly for those one-shot cue
  wrappers. It does not own looped audio or round-boundary cleanup.
  `runtime_perk_choice_feedback.gd` owns runtime perk choice-feedback payload
  policy: apply-failure feedback including pending unlock-swap suppression and
  application, Dowsing Goggles feedback text / timer policy and application,
  Megingjord bonus-pick feedback text / timer policy, helper-result fallback
  feedback normalization / application,
  per-frame feedback timer tick / expiry payloads and application,
  visible-feedback query policy, live feedback-field application, and
  runtime-state-facing assembly for visible-feedback, failure-feedback, and
  result-feedback state wrapper calls.
  `runtime_perk_state.gd` keeps the live feedback fields and delegates feedback
  payload application.
  `runtime_perk_choice_offer_modifiers.gd` owns choice-offer modifier bridge
  policy around item/catalog contributors: mythic item bonus choice counts,
  target choice-count calculation, Dowsing Goggles bonus-card tagging,
  perk-slot status snapshot copies, and Megingjord new-batch /
  new-pending-choice batch reset / after-choice extra-pick calls.
  `runtime_perk_state.gd` keeps the live choice arrays, feedback application,
  and modal sequencing.
  `runtime_perk_choice_opening.gd` owns runtime perk choice-open state
  transition payloads for no-pending, missing-catalog, empty-choice catalog
  results, generated choice/context/slot-status state application, and
  successful ready-open setup: modal close flags, current choice / context /
  slot-status clearing, pending-choice consumption, chained open-next requests,
  selected-card / gamepad-latch / animation reset, active-modal state, active
  modal query including runtime-state pending-swap lookup, active animation
  tick payloads, and cooldown / Lingpet / particle-work requests.
  `runtime_perk_choice_open_flow.gd` owns `open_next_choice()` orchestration:
  active-unlock flight clearing, no-pending / missing-catalog unavailable
  routing, item bonus choice-count calculation, catalog choice generation,
  perk-slot status capture, generated-choice state application, empty-choice
  recursive reopen, Dowsing bonus-card marking plus feedback, ready-state
  application, Lingpet cooldown tick callback, skill-cooldown pause callback,
  particle rebuild callback, open-next perf labels, runtime-state helper
  lookup, callback-map assembly, and the default base choice-count value used
  by the public state wrapper. `runtime_perk_state.gd` keeps the public
  `open_next_choice()` wrapper, live fields, and side-effect callback
  implementations.
  `runtime_perk_choice_completion.gd` owns successful-choice completion
  payload policy: last-selected id / snapshot handoff, selected-choice sequence
  increments, selected-choice snapshot construction, pending-choice consumption
  plus Megingjord extra-pick restoration, live success-state application,
  current-choice clearing, feedback handoff, animation reset, post-state
  open-next / context-clear plans, next-choice context snapshot handoff, and
  final post-state context-clear application plus modal-close side-effect
  gating / ordered close-step payloads for cooldown resume, resume safety,
  starpoint absorption, and owner sync.
  `runtime_perk_state.gd` keeps the actual modal progression calls and final
  close side-effect execution.
  `runtime_perk_choice_dispatch.gd` owns runtime perk `apply_choice()` dispatch
  policy for special choice ids: gold conversion, immediate vs deferred
  full-gauge / Dimension Gate instants, Monkey Blessing, Treasure Hunt,
  Lingpet affinity-chip, and Lingpet ring-core upgrade actions. Generic instant
  bookkeeping, unlock choices, and ordinary level-ups intentionally fall through
  to the standard state path.
  `runtime_perk_choice_action_runner.gd` owns explicit dispatch-action
  extraction and callback routing, state-callback map assembly, fallback
  feedback timers, and handled action-result feedback / accepted normalization.
  It calls the state-provided side-effect callbacks for gold conversion,
  full-gauge / Dimension Gate immediate and deferred actions, Monkey Blessing,
  Treasure Hunt, Lingpet affinity-chip, and Lingpet ring-core upgrade, then
  returns a normalized handled / accepted / feedback-result payload.
  `runtime_perk_state.gd` keeps the live field writes and callback
  implementations.
  `runtime_perk_choice_standard_path.gd` owns the standard `apply_choice()`
  fallback path policy after explicit dispatch actions miss: bookkeeping-instant
  callback sequencing, bookkeeping state-update payload selection,
  unlock-vs-level path selection, bookkeeping fallback feedback timer,
  bookkeeping live-state plus feedback completion,
  level-update callback sequencing, current-level lookup, level next-value /
  feedback payload extraction, level feedback callback completion, and standard
  bookkeeping / level state-application payloads including runtime-level patch
  application plus bookkeeping / level live pending-starpoint result application.
  `runtime_perk_state.gd` keeps side-effect callbacks and feedback application.
  `runtime_perk_choice_apply_flow.gd` owns runtime perk `apply_choice()`
  orchestration: dispatch payload consumption, action-runner handled-action
  sequencing, standard bookkeeping / unlock / level path selection, bookkeeping
  live-state completion, unlock callback dispatch and perf labeling, level
  live-state completion, level side-effect callback dispatch and perf labeling,
  level feedback callback sequencing, runtime-state helper lookup,
  live level / pending-starpoint extraction, apply-choice default constants,
  and callback-map assembly for the public state wrapper.
  `runtime_perk_state.gd` keeps the public `apply_choice()` wrapper, live
  fields, public compatibility constants, and side-effect callback
  implementations.
  `runtime_perk_choice_confirm_flow.gd` owns selected-choice confirmation
  orchestration: selected payload consumption, active-skill unlock flight start
  sequencing, flight state application, direct choice application callback
  routing, select / flight audio callback routing, apply-failure feedback
  callback routing, flight advancement / landing payload consumption, landed
  choice application callback routing, finish-or-showcase callback handoff,
  runtime-state helper lookup, current-selection extraction, flight-effect
  lookup, and callback-map assembly for confirm / flight-update wrappers.
  `runtime_perk_state.gd` keeps the public `choose_selected()` wrapper, flight
  effect field, and callback implementations.
  `runtime_perk_update_flow.gd` owns per-frame runtime perk update
  orchestration: feedback timer ticks, active-unlock flight advancement,
  unlock-showcase advancement, starpoint absorption advancement, active-choice
  animation gate updates, particle tick routing, and the focused perf sample
  labels for each branch. Its runtime-state facade also owns helper lookup,
  update-context construction, callback-map assembly, and the default particle
  lifetime used by the public state update wrapper. `runtime_perk_state.gd` keeps the public
  `update()` / `update_with_perf()` wrappers, live fields, and side-effect
  callbacks used by the flow helper.
  `runtime_perk_choice_finish_flow.gd` owns successful-choice finish
  orchestration after a choice has applied: Megingjord extra-pick callback
  sequencing, extra-pick feedback handoff, selected-choice success payload
  application via `runtime_perk_choice_completion.gd`, post-state open-next /
  context-clear plan execution, next-choice open callback routing, modal-close
  side-effect callback sequencing, close-step perf labels, runtime-state
  helper lookup, runtime-level lookup, callback-map assembly, and Mystic
  Dice/Fusion committed-revision idempotency. Duplicate D3/S4 calls return
  `already_finished` before pending/sequence, next-choice, Megingjord/Dowsing,
  or close callbacks can repeat. `runtime_perk_state.gd` keeps the public/private
  finish wrapper, live perk fields, and side-effect callback implementations.
  `runtime_perk_unlock_choice_apply.gd` owns normal unlock-choice application
  orchestration: unlock-choice validation, character skill-config resolution,
  slot-full pending-swap start payload application, skill-config
  `unlock_and_equip_skill` calls, unlock-level commit sequencing,
  owner-effect sync callback sequencing, Commando weapon-controller/audio sync,
  unlock feedback callback sequencing, runtime-state helper lookup, live
  runtime-level dictionary extraction, and callback-map assembly.
  `runtime_perk_state.gd` keeps the private wrapper consumed by
  standard-path/debug-grant flows plus live runtime-level dictionary ownership.
  `runtime_perk_debug_grants.gd` owns developer/debug perk grant path policy:
  ring-core / instant / unlock / ordinary-level path selection, debug choice-data
  patch payloads plus combined patch composition/application for `next_tier`,
  current/next level fields, catalog lookup, path-specific apply-call
  orchestration, ordinary debug runtime-level patch application, level
  side-effect / feedback callback sequencing, post-apply last-selected /
  owner-sync application, runtime-state helper lookup, live runtime-level
  dictionary extraction, debug default constants, feedback-timer lookup, and
  grant callback-map assembly. `runtime_perk_state.gd` keeps the public debug
  setter wrapper, live runtime-level dictionary, and callback implementations.
  `runtime_perk_owner_projection.gd` owns owner-facing runtime perk field
  projection: projection-state payload assembly, runtime/effective level
  copies, pending-choice/starpoint/gold counters, choice-active flag, item
  perk level bonus, and Viper Ignition Aura flag.
  `runtime_perk_owner_sync_flow.gd` owns state-facing owner-sync orchestration:
  runtime-state projection into owner-facing payloads, owner-effect sync
  context assembly, item/mythic runtime-perk consumer refresh routing, and
  skill-config training refresh routing. Its runtime-state facade also owns
  owner projection / owner-effect-sync helper lookup and get-instance callback
  assembly for owner-effect, item-polish, mythic-consumer, and training
  refreshes. `runtime_perk_state.gd` keeps the narrow callback names consumed
  by choice, unlock, debug, dynamic-effect, and instant/deferred flows.
  `runtime_perk_reset_state.gd` owns plain runtime perk reset field
  payload/application: run-level dictionaries, pending/starpoint/gold counters,
  choice modal fields, feedback fields, selected-choice snapshot fields,
  item/perk bonus flags, unlock-swap indices/latches, and choice context/status
  clears. Its runtime-state reset facade also owns reset ordering and
  side-effectful helper-object resets such as cooldown resume, absorption,
  flight, showcase, deferred-instant, and resume-safety reset.
  `runtime_perk_state.gd` keeps the public `reset()` wrapper.
  `runtime_perk_choice_layout.gd` owns runtime perk choice modal geometry:
  responsive card / description / status-panel / hint positions, animated
  card entry offsets, runtime-state choice-count / animation-time extraction
  for layout facades, card hit rects, mouse hit-index resolution, ambient
  choice-modal particles, runtime-state particle rebuild, and live
  particle-field application.
  `runtime_perk_state.gd` keeps the public `build_layout()` /
  `get_card_rects()` wrappers for overlay and input callers.
  `runtime_perk_resume_safety.gd` owns the post-choice ball resume freeze /
  recovery lifecycle, pre-choice velocity capture, Stopwatch velocity handoff,
  serve-wait / Stopwatch arming guards, and upward-hit release so attack skills
  can preserve their launch velocity after the modal closes. Its runtime-state
  facade owns resume-safety helper lookup for state wrappers and the pre-update
  Viper Ignition Aura dirty owner-sync handoff before each resume-safety tick.
  `runtime_perk_starpoint_absorption.gd` owns starpoint collection update
  payloads and the post-modal starpoint absorption effect payload: collected
  amount normalization, starpoint-to-choice conversion, live collection result
  application to starpoint / pending-choice state, collection feedback,
  post-collection choice-open / failed-open resume-cleanup gating, activation,
  duration, deterministic sparkle seeds, moving-paddle target/source screen
  projection, runtime-state active / start / update facades including flight-
  layout lookup for projection, and snapshot data consumed by the overlay
  renderer.
  `runtime_perk_starpoint_collection_flow.gd` owns starpoint collection
  orchestration around those payloads: collection-update construction and
  application, Megingjord new-pending-choice reset callbacks, collection
  feedback application, post-collection choice-open planning, pre-choice
  resume velocity capture, `open_next_choice()` callback routing, failed-open
  pre-choice cleanup, owner sync callback routing, and public choice-active
  result normalization. Its runtime-state facade also owns the helper lookup,
  callback-map assembly, and default starpoint-to-choice conversion value used
  by the public `runtime_perk_state.gd` `collect_star_points()` wrapper.
  `runtime_perk_state.gd` keeps the public wrapper, live fields, and
  side-effect callbacks.
  `runtime_perk_active_unlock_flight.gd` owns active-skill unlock flight
  payload construction: selected-card index bounds / source-rect handoff,
  target skill-orb slot resolution, pillar/orb layout lookup, deterministic
  trail particles, flight state application, flight effect consumption /
  clearing, landing payload validation, active-state gating including the
  runtime-state active query, flight age advancement, and runtime-state flight
  layout facade routing.
  `runtime_perk_state.gd` still owns the choice modal, delayed unlock
  application callback, failure feedback, and live state fields.
  `runtime_perk_unlock_showcase.gd` owns the junior-mode active-skill unlock
  showcase payload: open eligibility, skill metadata fallback, display age,
  input-dismiss gate, auto-dismiss age, runtime-state active query, showcase
  state application, and payload consumption. `runtime_perk_unlock_showcase_flow.gd` owns junior unlock
  showcase orchestration: finish-vs-open branching, showcase state application
  plus owner sync, auto/input dismissal, consumed-showcase choice extraction,
  delayed successful-choice callback handoff, runtime-state showcase/controller
  lookup, and callback-map assembly. It does not commit the unlock, resume
  cooldowns, or run post-choice starpoint absorption directly; those delayed-
  success side effects remain in `runtime_perk_state.gd` callbacks.
  `runtime_perk_unlock_swap_layout.gd` owns pending unlock-swap modal geometry
  and hit testing: panel / card sizing, narrow-view scaling, option rect
  construction, runtime-state pending-swap extraction for layout facades, and
  mouse index resolution. `runtime_perk_state.gd` keeps the pending swap state,
  gamepad latch fields, and narrow cancel / confirm wrappers.
  `runtime_perk_unlock_swap_flow.gd` owns pending unlock-swap flow policy:
  slot-full start gating, pending payload construction from skill-config
  display data, pending-swap existence / snapshot / selected-index queries,
  runtime-state-facing query extraction, candidate-count / has-candidates
  queries, pending-swap-based selected-index move / direct / clamp state
  updates, runtime-state move / direct selection facades,
  runtime-state-facing confirm assembly
  for pending payload / selected index / live levels / catalog / character type
  lookup, level-side-effect helper lookup, confirm callback-map assembly,
  confirm-request validation / payload extraction, confirm selection-update
  callback sequencing, confirm skill-config request construction / registry
  resolution, confirm level-commit callback sequencing, confirm owner-effect
  sync callback sequencing, full pending-swap confirm orchestration,
  confirm-completion state/showcase payload planning plus post-confirm
  completion/showcase callback sequencing, live pending-swap state application,
  feedback-helper routing
  for cancel / confirm state updates, runtime-state-facing feedback-helper /
  fallback-timer / owner-sync callback assembly for swap state application,
  runtime-state cancel orchestration including pending-swap guard and cancel
  state-update application,
  owner-sync callback sequencing after helper application, selected shared-slot swap execution plus confirm-request
  selected-index routing and replaced unlock-perk cleanup sequencing including
  the Commando pistol fallback id,
  Commando weapon controller / weapon-change-audio sync including confirm-request
  wrapper routing, and swap cancel / confirm feedback payloads.
  `runtime_perk_state.gd` keeps the public pending state, modal input wrapper,
  owner-sync callback handoff, owner-effect sync implementation, and
  unlock-showcase finish implementation.
  `runtime_perk_skill_cooldown_pause.gd` owns the runtime perk choice modal's
  player-skill cooldown pause lifecycle: resolving
  `battle_scene_skill_tooltip_driver`, calling pause once per modal, retaining
  the pause owner / registry, and resuming exactly once on choice close or
  reset. Its runtime-state facade owns pause/resume helper lookup for state
  wrappers and reset lifecycle callers. `runtime_perk_state.gd` keeps the
  narrow pause/resume wrapper names.
  `runtime_perk_deferred_instants.gd` owns result-box deferred instant perk
  state for `instant_dimension_gate` and `instant_gauge_full`: context-key
  deferral checks, pending flags, origin-stage guards, pending feedback text,
  queued-choice success feedback payloads, next-spawn-intro action collection,
  ready-action resolution, success/failure result flags, feedback text
  resolution, owner-sync request policy, state-update extraction, and
  helper-owned feedback application sequencing / public-result cleanup.
  `runtime_perk_state.gd` still applies the actual dimension gate / full-gauge
  side effects through callbacks and keeps the public
  pending-query and `on_ball_spawn_intro_finished()` surfaces.
  `runtime_perk_effective_levels.gd` owns runtime perk effective-level and
  numeric bonus policy: Lv.6+ bonus eligibility, Ignition Aura exclusions,
  Ignition Aura active-state dirty-sync payloads, item perk-level bonus clamp
  payloads, dynamic owner/training/consumer refresh plans, dirty owner-sync
  refresh plans, converted-perk bridge levels, Polish amplify eligibility,
  shared dash / item / treasure-map / common-stat bonus math, derived
  dash / active-item / player stat query formulas, Laurel leaf totals, and
  combo-amplifier output.
  `runtime_perk_effective_stat_query_surface.gd` owns runtime-state
  projection for public effective-stat reads: runtime-state-facing effective-
  level helper lookup, extracting current `runtime_skill_levels`, item
  perk-level bonus, Ignition Aura active state, applying those inputs to the
  effective-level helper, neutral fallbacks for missing helpers, Viper Ignition
  Aura level-bonus / level-bonus eligibility reads, Sacred Laurel registry
  bonus lookup for Laurel leaf count, and runtime-state-facing get-instance
  callback assembly for the Laurel wrapper. `runtime_perk_state.gd` keeps the
  public query wrapper names consumed by HUD, item, dash, owner-effect, and
  skill-config callers.
  `runtime_perk_dynamic_effects.gd` owns runtime perk dynamic-effect
  orchestration for Viper Ignition Aura and item perk-level bonus sources:
  active-state update / query application, item-level bonus update / query
  application,
  dynamic refresh plan execution, dirty owner-sync refresh execution, owner
  effect sync callback sequencing, no-owner skill-config training fallback,
  consumer refresh callback sequencing, runtime-state effective-level helper
  lookup, and callback-map assembly for those operations.
  `runtime_perk_state.gd` keeps the public setter / refresh wrapper names
  consumed by HUD, item, dash, and owner-effect callers.
  `runtime_perk_instant_rewards.gd` owns instant perk runtime side effects
  and bookkeeping: owner-character-aware full-gauge refill / dash-token
  refill / skill-cooldown reset, Dimension Gate activation through active-item runtime, Monkey
  Blessing delivery or banana-fill fallback, Treasure Hunt runtime start,
  `common_refresh` pending-choice bookkeeping, `star_change`
  starpoint-to-choice conversion, immediate full-gauge / Dimension Gate /
  Monkey Blessing / Treasure Hunt success feedback payloads, bookkeeping
  feedback payloads, bookkeeping state-update extraction, generic
  `is_instant` feedback payloads, and debug instant current / next level
  payloads.
  `runtime_perk_instant_choice_flow.gd` owns instant-choice orchestration
  around those payload helpers: runtime-state-facing dependency assembly for
  full-gauge / Dimension Gate apply wrappers, deferred full-gauge /
  Dimension Gate queue wrappers and pending/defer queries, spawn-intro deferred
  action collection / resolution / feedback application, owner-sync callback
  routing after deferred actions, and runtime-state-facing Monkey Blessing /
  Treasure Hunt choice wrapper dispatch. `runtime_perk_state.gd` keeps choice
  dispatch, shared helper-feedback result application, owner-state writes, and the
  public/private callback names consumed by choice-action runners and
  spawn-intro completion callers.
  `runtime_perk_level_side_effects.gd` owns post-level-up side effects:
  ordinary level-choice update payloads, max-level capping, level feedback
  payloads, unlock-choice success update payloads and runtime-level commits,
  debug level-grant clamp / current-next / feedback payloads,
  debug unlock-grant current / next payloads,
  `dash_amplification` dash-token reset policy including mythic capacity
  override, owner-effect sync callback dispatch, mythic runtime-perk consumer
  refresh, and the defensive unlock-side-effect fallback for skill config /
  Commando weapon sync. Its runtime-state facade owns character-context /
  unlock-swap helper lookup and callback assembly for get-instance,
  owner-effect sync, and mythic-consumer refresh.
  `runtime_perk_state.gd` keeps the public level write and narrow
  `_apply_level_side_effect()` / debug-grant entry wrappers.
  `runtime_perk_lingpet_rewards.gd` owns runtime perk Lingpet one-shot reward
  application: affinity-chip enhancement, this-run ring-core tier upgrades
  through `lingpet_egg_runtime`, max-tier / stale-tier guards, localized
  ring-core tier-name resolution, Lingpet reward feedback payloads, runtime-
  state-facing get-instance callback assembly for affinity-chip / ring-core
  choice actions and ring-core offer-cooldown ticks, debug ring-core tier-clamp
  payloads, and ring-core offer-cooldown ticks. `runtime_perk_state.gd` keeps
  the choice branch and applies helper feedback fields to the live modal state.
  `runtime_perk_owner_effect_sync.gd` owns runtime perk owner-effect sync:
  sync-context payload assembly, effective-level / accessory / Laurel leaf
  owner fields, combined perk + active-item + mythic paddle scaling,
  grounded-bottom preservation during resize, warp-gate-aware x clamps,
  player-skill cooldown multiplier sync, and mythic runtime-perk scaling
  refreshes. `runtime_perk_owner_sync_flow.gd` owns the runtime-state-facing
  context assembly and refresh dispatch into this helper.
  `runtime_perk_gold_awards.gd` owns runtime perk gold calculation policy:
  rally speed tiers, enraged / Ignition Aura / Gold Digger order, Smasher combo
  scaling, Blacksmith structure bonuses, owner-context extraction, rally /
  skill-gold award payload construction, arena-mode rally suppression, dash
  rally multiplier consumption, `convert_to_gold` award payload construction,
  Ignition Aura gold-bonus lookup, item-gold multiplier clamp payloads,
  item-gold multiplier live-state application,
  stored-gold / conversion feedback text metadata, default gold-feedback
  fallback resolution, gold award state-update extraction, state-field
  application payloads, and live stored-gold state application.
  `runtime_perk_gold_award_flow.gd` owns runtime perk gold award
  orchestration: public rally-gold / skill-gold / already-boosted store
  calls, `convert_to_gold` choice award dispatch, current gold / item
  multiplier / Ignition Aura state reads, runtime-state item-gold multiplier
  setter / getter wrappers, runtime-state rally-gold calculator wrapping,
  Ignition Aura gold-bonus query wrapping,
  award-result application fallback, feedback callback wiring, runtime-state-facing dependency assembly for
  rally / skill / stored / conversion / award-result wrapper calls,
  Smasher combo-state lookup for conversion choices, owner sync after
  conversion, and the public returned-total normalization.
  `runtime_perk_state.gd` keeps the public/private wrapper names consumed by
  player-hit, skill-hit, choice-action, and legacy helper call sites.
  The battle scene shell only routes the public starpoint trigger, debug F8
  trigger, modal input,
  modal pause, and draw ordering.
- `scripts/core/stage_clear_result_starpoint_choice_handler.gd`
  Owns the public result-screen starpoint perk-choice flow surface: defer
  eligibility, deferred-choice scheduling wrapper, pending-choice update fanout,
  runtime-choice update fanout, selected-perk sync wrapper, and runtime perk
  choice-active probing. Deferred delay state, result input gate writes,
  deferred-open state tracking, selected-sequence idempotence, and resolved
  perk append dispatch through the box scene handler are delegated to
  `stage_clear_result_starpoint_choice_state.gd`. Runtime perk modal opening,
  choice context assembly, active-state probing, and choice-open audio fallback
  are delegated to `stage_clear_result_starpoint_choice_open_data.gd`.
  Selected perk reward payload assembly and runtime perk snapshot copying are
  delegated through the choice state to
  `stage_clear_result_starpoint_perk_reward_data.gd`.
- `scripts/core/stage_clear_result_starpoint_choice_state.gd`
  Owns stateful result-box starpoint choice tracking: pending delay / box-index
  storage, result input gate scene writes, delayed-open countdown, opened-choice
  active box tracking, selected-choice sequence idempotence, resolved perk
  reward append dispatch through the box scene handler, runtime perk snapshot
  reads through `stage_clear_result_starpoint_perk_reward_data.gd`, and active /
  pending state reset.
- `scripts/core/stage_clear_result_starpoint_choice_open_data.gd`
  Owns stateless result-box starpoint deferred-choice opening: defer eligibility,
  runtime perk choice active-state probing, `open_next_choice` dispatch,
  result-box choice context flags that defer instant grants until spawn-intro
  completion, pre-open sequence capture, and runtime-perk choice-open audio
  fallback.
- `scripts/core/stage_clear_result_starpoint_perk_reward_data.gd`
  Owns stateless result-box starpoint perk reward data assembly: copied
  runtime-perk snapshots, selected-choice sequence extraction, perk catalog /
  choice fallback data merging, level label construction, and the
  `box_starpoint_choice` reward payload returned to the starpoint choice
  handler.
- `scripts/characters/laurel_leaf_shield_state.gd`
  Owns the Godot 월계수잎 runtime shield: effective perk leaves plus future
  Sacred Laurel leaf bonuses, player-centered elliptical orbit timing,
  back-side-only ball collision, consumed-leaf 30-second regeneration,
  upward random-speed reflection, leaf-break particle creation/simulation,
  `leaf.wav` audio feedback, match-reset cleanup, and ball-update collision
  handoff. Its draw facade lends both live arrays and explicit orbit geometry.
- `scripts/characters/laurel_leaf_shield_renderer.gd`
  Owns the shield's depth-sorted procedural CanvasItem presentation: full and
  severe-LOD leaf silhouettes, pygame-parity ellipse/line/arc helpers, particle
  stride/drawing, deterministic orbit projection, and triangulation-safe fills.
  It owns no perk count, collision, regeneration, reflection, audio, simulation,
  RNG, reset, or retained leaf/particle state.
- `scripts/characters/monkey_blessing_delivery_state.gd` and
  `scripts/characters/monkey_blessing_delivery_renderer.gd`
  Own the Godot `instant_monkey_blessing` delivery event: the perk-state
  trigger starts a delayed playfield actor, the actor enters from either
  floor edge, tracks the live player X position, fills empty active-item
  slots with bananas during the handoff pose, then exits and cleans itself
  up through match reset. Runtime art is loaded from the imagegen 4x4
  monkey delivery sheets under `assets/sprites/perks/`.
- `scripts/hud/runtime_perk_debug_picker.gd`
  Owns the Godot F3 runtime perk debug picker: modal open/close state,
  compact all-perk grid layout, click-to-apply routing, mouse-wheel target
  level selection, current-level display, and handoff to
  `runtime_perk_state.debug_set_perk_level()` so debug grants reuse normal
  unlock / side-effect sync.
- `scripts/hud/runtime_perk_icon_renderer.gd`
  Owns runtime perk-choice icon rendering: Python perk PNG parity assets,
  instant-trigger sheet-first animation, unlock-perk alias mapping to the
  real skill-orb PNGs including Commando firearm unlock aliases, cached
  texture loads, and procedural fallback only
  when an asset is missing.
  Commando `soldier_unlock_*` / `soldier_pistol_perk` cards reuse the
  exact real orb PNG path / loaded texture, while the unlock badge is
  applied only on the perk-card alias and not on the equipped orb id.
- `scripts/hud/character_info_overlay.gd`
  Owns the first Godot TAB character-info overlay port: TAB / ESC close
  state, modal battle pause, selected-character status summary, equipment
  slot readout, equipped skill slots, acquired runtime-perk grid with hover
  tooltips, active-item slot readout, bottom passive/mythic inventory grid
  with right-click equip / unequip management, passive-item hover tooltips
  split into an item-description box plus a right-side roll-option box,
  and live stat rows sourced from the battle scene owner and existing
  character / item / perk modules.
  It normalizes `soldier` / `commando` through `player_character_runtime`,
  displays 코만도 as the selected character, and reads
  `commando_skill_config` for TAB skill/perk rows instead of falling back
  to Smasher labels.
  The battle scene shell only
  routes the TAB toggle, modal input, pause gate, and final overlay draw.
- `scripts/hud/character_info_overlay_static_data.gd`
  Owns static TAB character-info overlay data tables such as extra
  active-item prewarm ids and equipment slot definitions. It is data-only;
  runtime state, input handling, draw caches, and live tooltip assembly stay
  in `character_info_overlay.gd`.
- `scripts/hud/character_info_overlay_equipment_geometry.gd`
  Owns TAB character-info equipment anatomy silhouette geometry updates:
  body anchor positions, head / neck rects, torso polygons, limb polygons, and
  the cached geometry fields mutated on the overlay. The overlay keeps cache
  hit checks, draw colors, connector drawing, equipment slot layout, and
  smoke-facing draw wrapper names.
- `scripts/hud/character_info_overlay_equipment_drawer.gd`
  Owns stateless TAB character-info equipment helper drawing: hover connector
  line target selection and empty-slot placeholder glyphs for body parts /
  accessories. The overlay keeps slot draw order, hover gates, draw-budget
  constants, anatomy silhouette drawing, and smoke-facing wrapper names.
- `scripts/hud/character_info_overlay_value_utils.gd`
  Owns pure value-normalization helpers for the TAB character-info overlay,
  including safe owner-property reads and Variant-to-Array / Dictionary /
  Color coercion, active-item label cache key comparison, and active-item
  label state resolution. It also owns active-item catalog text prewarm
  iteration, skill-config text prewarm iteration, and perk text-entry prewarm
  iteration while the overlay keeps the actual text measurement caches. It has
  no overlay state, no cache ownership, and no draw or input side effects.
- `scripts/hud/character_info_overlay_formatter.gd`
  Owns pure Korean display formatting for the TAB character-info overlay,
  including character labels / colors, slot labels, passive-item roll value
  text, equipment empty-color selection, compact item hash helpers, short
  labels, level badges, and simple number / time formatting. It has no overlay
  state, cache ownership, input handling, or draw side effects.
- `scripts/hud/character_info_overlay_lingpet_presenter.gd`
  Owns pure Lingpet presentation data for the TAB character-info overlay:
  catalog-backed display names, owner-to-panel snapshot assembly, skill-card
  tooltip specs, translated stat-row dictionaries, and Lingpet stat cache
  hashes. The overlay keeps texture caches, hover rects, drawing, and cache
  storage.
- `scripts/hud/character_info_overlay_pendulum_interior.gd`
  Owns the TAB character-info Ring Core pendulum-interior sub-screen:
  open / close state, reusable Lingpet companion walking draw config,
  generic Lingpet-language speech selection, decoder-level rich-text run
  caching, and immediate-mode modal chrome. The main overlay keeps input
  routing, z-order, hover rect collection, and redraw decisions.
- `scripts/hud/character_info_overlay_header_presenter.gd`
  Owns pure TAB character-info header text assembly: stable subtitle text and
  localized pending-choice / perk-gold status strings. The overlay keeps the
  actual header caches, width measurement cache, owner snapshot fallback
  reads, and drawing.
- `scripts/hud/character_info_overlay_hover_geometry.gd`
  Owns stateless TAB character-info hover geometry helpers: rect-map hit
  checks, cached grid / linear slot hover signatures, and pure slot / grid
  index math. The overlay keeps the hover state caches, public smoke-test
  wrapper names, section scan order, and input / redraw decisions.
- `scripts/hud/character_info_overlay_passive_item_presenter.gd`
  Owns pure passive-item and equipment presentation helpers for the TAB
  character-info overlay: passive tooltip body text, passive item body / frame
  color hashes, passive inventory icon hashes, roll-option value fallback,
  passive-roll entry append helpers, passive frame color selection, and
  quality-backed equipment display names / quality colors. The overlay keeps
  tooltip caches, draw caches, hover state, passive inventory draw-state
  enrichment, registry lookups, and item equip / unequip input handling.
- `scripts/hud/character_info_overlay_perk_presenter.gd`
  Owns pure TAB character-info acquired-perk presentation helpers: equipped
  unlock-skill lookup construction, equipped unlock duplicate hiding, catalog
  perk data fallback / duplication, description fallback, draw metadata
  enrichment, catalog prewarm entry collection, and runtime-perk text prewarm
  orchestration, acquired perk core typed draw-array refresh, and effective
  runtime-level override resolution plus acquired-perk sort ordering. The
  overlay keeps cache hash guards, hover text cache anchors, hover rects, text
  measurement caches, and public smoke-test wrapper names.
- `scripts/hud/character_info_overlay_stats_presenter.gd`
  Owns pure TAB character-info stat math helpers: delta color classification,
  effective gauge / move-speed / paddle-width / gauge-gain / dash timing
  calculations, and frame-to-seconds conversion. The overlay keeps stat row
  cache arrays, source lookup order, row write helpers, and the public
  `_build_stats()` / focused smoke entry points.
- `scripts/hud/character_info_overlay_texture_drawer.gd`
  Owns stateless TAB character-info texture helpers for contained / cover-fit
  drawing, raw texture touches, visible item-icon collection, and item icon
  prewarm iteration. The overlay keeps texture path resolution, load caches,
  Lingpet catalog iteration, hover data, prewarm source resolution / cache
  guards, and fallback symbol drawing.
- `scripts/hud/premium_panel_frame.gd`
  Owns shared zero-allocation StyleBoxFlat chrome for premium HUD panels:
  rounded main / section / slot / cell geometry, soft container shadows,
  a main-panel halo pass, and reusable corner-bracket accents. Character-info
  presenters pass per-call colors through this helper while keeping layout,
  hover state, text, icon, and gameplay data ownership in their existing
  overlay modules.
- `scripts/hud/character_info_overlay_lingpet_texture_loader.gd`
  Owns catalog-backed Lingpet art / skill icon path resolution,
  `ProjectResourceLoader` texture loads, and Lingpet skill-icon prewarm cache
  population for the TAB character-info overlay. The overlay keeps the cache
  dictionaries, wrapper entry points, drawing, hover data, and fallback symbol
  rendering.
- `scripts/hud/character_info_overlay_text_width_cache.gd`
  Owns stateless indexed / single-entry text-width cache hit checks and miss
  measurement updates for the TAB character-info overlay. The overlay keeps
  the cache fields, `_text_size()` measurement entry point, wrapper names, and
  draw decisions.
- `scripts/hud/character_info_overlay_owner_state.gd`
  Owns stateless TAB character-info owner / runtime state fallback helpers:
  selected-character normalization, display-name fallback, equipment slot
  fallback resolution, accessory slot number / count math, stat-source list
  assembly, active-item slot count / capacity, Smasher dash snapshot lookup,
  active-item cooldown chain calculation, registry / prewarm instance lookup,
  and character skill-config key resolution. The overlay keeps wrapper names,
  caches, drawing, and the public focused-smoke wrapper names.
- `scripts/hud/ball_speed_debug_overlay.gd`
  Owns the Godot F9 real-time ball-speed debug overlay: toggle state,
  current base velocity readout, `ball_impact_boost` readout, effective
  movement speed versus the active league cap, and compact final overlay
  drawing.
  Input routing stays in `battle_scene_overlay_input_controller.gd`; draw
  ordering stays in `battle_scene_overlay_frame_controller.gd`.
- `scripts/stages/stage1/stage1_dalji_whip_skill_state.gd`
  Owns the Stage 1 Dalji 상모돌리기 boss-skill port: boss skill gauge gain
  on boss paddle hits after cooldown READY, downward wave ball
  steering, player-hit cancellation, post-spin slowdown state, and the
  draw/AI flags consumed by ball, AI, and Stage 1 boss render modules.
- `scripts/stages/stage1/stage1_dalji_spinning_top_skill_state.gd`
  Owns the Stage 1 Dalji spinning-top boss-skill port: cooldown-ready
  repeatable instant activation, whip
  startup timing, two/four top spawning, top movement, top-to-top bounce,
  ball collision deflection, golden-top starpoint drop, impact feedback, and draw context for the
  focused spinning-top renderer. Spawned top payload construction is
  delegated to `stage1_dalji_spinning_top_payload_factory.gd`.
- `scripts/stages/stage1/stage1_dalji_spinning_top_payload_factory.gd`
  Owns pure Stage 1 Dalji spinning-top payload construction for spawned top
  dictionaries; skill timing, collision, rewards, and audio remain in
  `stage1_dalji_spinning_top_skill_state.gd`.
- `scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd`
  Owns the first Stage 1 boss-skill cooldown model: Dalji's immediate
  spinning-top trigger, boss-hit whip trigger, round-to-round cooldown
  progress preservation, READY / CAST / recharging HUD state, and deterministic
  cooldown charging that replaces the old random gauge activation in the
  Godot port.
- `scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd`
  Owns the Stage 1 Dalji boss-skill cooldown queue HUD in the left pillar:
  imagegen skillcard rendering keyed by boss skill id, arena-style
  left-to-right skillcard gauge reveal, ready / casting / used border
  feedback, compact hover tooltips for trigger / cooldown / effect text,
  left-pillar-preferred tooltip anchoring, and fixed screen-space placement
  outside the transformed central playfield.
- `scripts/stages/stage1/stage1_dalji_boss_skill_hud_assets.gd`
  Owns Stage 1 Dalji boss skill-card HUD asset metadata: whip and spinning-top
  skill-card PNG paths. The renderer keeps texture caching, prewarm sequencing,
  queue animation, card layout, tooltip, and draw behavior.
- `scripts/stages/stage1/stage1_dalji_spinning_top_renderer.gd`
  Owns the procedural Stage 1 Dalji spinning-top skill rendering:
  startup whip curves, wooden top bodies, rotating color discs, golden-top
  glow, boost brightening, shadows, tilt, and fade-out.
- `scripts/stages/stage1/stage1_pododaejang_patrol_guards_skill_state.gd`
  Owns the Stage 1 Pododaejang 포졸소환 combat state: once-per-round
  cooldown activation, two independently patrolling guards, deterministic
  test RNG, fade/expiry, speed-preserving random ball deflection, guard push,
  collision feedback, and round/reset cleanup.
- `scripts/stages/stage1/stage1_pododaejang_arrest_rope_skill_state.gd`
  Owns the Stage 1 Pododaejang 포승줄 combat state: boss-hit activation,
  snapshotted target, throw/bound/release/miss phases, smoke immunity,
  half-speed movement projection, dash break, audio cues, and draw context.
- `scripts/stages/stage1/stage1_pododaejang_boss_skill_cooldown_state.gd`
  Owns Pododaejang's 16-second instant Patrol Guards and 20-second on-hit
  Arrest Rope cooldowns, per-round normalization, pause handling, and the
  two-card HUD snapshot.
- `scripts/stages/stage1/stage1_pododaejang_boss_skill_hud_renderer.gd` /
  `stage1_pododaejang_boss_skill_hud_assets.gd`
  Own Pododaejang's left-pillar skill-card layout, generated PNG metadata,
  texture prewarm/cache, cooldown reveal, status feedback, and localized
  trigger/effect tooltips.
- `scripts/stages/stage1/stage1_pododaejang_skill_renderer.gd`
  Owns Pododaejang's playfield skill presentation: the declared 3x3/eight-
  frame guard walk sheet with procedural fallback plus throwing, bound,
  releasing, and missed rope geometry.
- `scripts/stages/stage1/stage1_balloon_event.gd`
  Owns the Stage 1 balloon-machine event facade: balloon sprite-sheet loading,
  live balloon payload construction/pop audio, pop-effect/starpoint rendering,
  and detached starpoint-host hide cleanup. Balloon spawn payloads,
  Chaos Spear absorb result payloads, and sprite / fallback pop-effect payloads
  are delegated to `stage1_balloon_payload_factory.gd`; retained starpoint
  collections and their gameplay lifecycle are delegated to
  `stage1_balloon_starpoint_state.gd` behind writable compatibility properties
  and thin spawn/update methods. Machine cooldown/phase state, shot-plan RNG,
  phase audio, and ordered prewarm/shot callbacks are delegated to
  `stage1_balloon_machine_state.gd` behind writable compatibility properties
  and methods. Live balloon storage/motion/geometry are delegated to
  `stage1_balloon_runtime_state.gd`; destructive ball/projectile/Chaos/paddle
  interactions and immunity/knockback policy are delegated to
  `stage1_balloon_interaction_coordinator.gd`. The facade supplies their
  synchronous pop-feedback callback.
  Its raw PNG sheets live under
  `godot/assets/sprites/stage1/balloon/`, with event sounds under
  `godot/assets/sounds/`.
- `scripts/stages/stage1/stage1_balloon_machine_state.gd`
  Retains Stage 1 balloon-machine active/phase/cooldown/presentation state and
  the per-activation shot plan. It owns the original global-RNG sequence,
  initial/reset cooldown, activation-frame delay, phase envelopes/transitions,
  door/machine start-edge audio, prewarm request position, multi-shot catch-up,
  and ordered facade shot callbacks. The facade retains concrete balloon
  construction, pop audio, textures and drawing.
- `scripts/stages/stage1/stage1_balloon_runtime_state.gd`
  Retains the live Stage 1 balloon collection and playfield bounds. Owns
  frame-scaled translation, post-paddle drag/cooldown, bob/spin, radius-aware
  wall reflection, lifetime, swept-path and circle/rectangle geometry, paddle
  bounce response, deflection math, and deep snapshots. Its random fallback /
  deflection branches preserve the original global RNG.
- `scripts/stages/stage1/stage1_balloon_interaction_coordinator.gd`
  Owns Stage 1 ball collision/Whip response, Commando bullet filtering and
  result projection, reverse-safe Chaos absorption/result creation, dash pop,
  player/boss paddle routing, Cleanse-before-Celestial-Armor immunity, and
  knockback. It removes first, calls the facade's pop feedback synchronously,
  then applies deflection or publishes absorbed results.
- `scripts/stages/stage1/stage1_balloon_starpoint_state.gd`
  Retains the Stage 1 balloon-event starpoint drop and particle collections and
  owns bounds configuration, primary / Star Detector bonus payload generation,
  global-RNG ordering, fall/bounce motion, Dowsing attraction, Starlight
  Tracking claim/delivery, rectangle-overlap collection, modal-safe in-place
  compaction, reward/particle/audio/redraw ordering, clear state, and particle
  advancement. The balloon facade retains draw and detached-host cleanup.
- `scripts/stages/stage1/stage1_balloon_event_assets.gd`
  Owns Stage 1 balloon-event asset metadata: balloon sheet resource paths,
  sheet frame counts, texture prewarm step count, and balloon color palette.
  `stage1_balloon_event.gd` keeps texture cache fields, staged load order,
  spawn/pop feedback, draw paths, and collision handoff.
- `scripts/stages/stage1/stage1_context_reader.gd`
  Owns typed reads for Stage 1 renderer dictionaries: Vector2 and Color
  fallback coercion used by playfield, player, boss, and sprite fallback
  renderers. Stage 1 render modules should reuse this helper instead of
  duplicating local `_as_vector2` / `_as_color` bodies.
- `scripts/stages/stage1/stage1_playfield_renderer.gd`
  Owns Stage 1 court background drawing, including the Python-generated dark
  stone central field PNG, dancheong border, stadium electric-flow / particle
  accents, and Smasher sprite-silhouette dash afterimages. The renderer keeps
  a procedural floor fallback for missing background assets.
- `scripts/stages/stage1/stage1_player_actor_renderer.gd`
  Owns Stage 1 Smasher actor drawing: hover / breath / hit-pose offsets,
  attack-sheet draw-size anchoring, active-item throw-pose offsets,
  Python-parity post-dash recovery jitter, soft shadow placement, visual
  rect assembly, AI Pill `AI SYSTEM` label placement, and delegation to the
  player sprite renderer.
- `scripts/stages/stage1/stage1_player_sprite_renderer.gd`
  Owns Stage 1 Smasher sprite drawing: hit / idle / walk texture
  selection, 4x2 attack-sheet source-rect selection, legacy strip source
  selection, throw-pose sprite rotation, Python-parity post-dash recovery
  `BLEND_RGB_MULT` tinting, AI Pill clipped horizontal cyber-glitch slices,
  and fallback paddle drawing.
- `scripts/stages/stage1/stage1_boss_actor_renderer.gd`
  Owns Stage 1 boss actor drawing: shadow placement, visual-center
  alignment, Dalji walk-left / walk-right / idle / ball-contact attack
  source-rect selection, active-item stun-sheet / spinning-star overlay,
  active-item confusion question-mark overlay, and fallback paddle drawing.
  Runtime state vocabulary follows
  `docs/sprites/boss_sprite_runtime_contract.md`; for Dalji-specific
  texture keys, see `docs/sprites/stage1_dalji.md`.
- `scripts/ball/ball_physics.gd`
  Owns the public ball-physics API and league/stage/weather context
  normalization. It delegates serve velocity, speed dampening, rally
  multipliers, impact boost, serve launch boost, boost decay, minimum vertical bounce
  correction, serve-speed rally floor, and base speed capping to focused
  physics policies.
- `scripts/ball/ball_context_reader.gd`
  Owns typed reads for ball-domain dictionaries: Vector2 fallback
  coercion used by ball update, motion, round reset, and paddle-bounce
  helpers. Ball modules should reuse this helper instead of duplicating
  local `_get_vector2` / `_as_vector2` bodies.
- `scripts/ball/ball_speed_policy.gd`
  Owns ball speed policy calculations: serve velocity, junior / rally
  speed multipliers, fire-weather 2x rally speed-increase scaling,
  50% reduced normal-rally acceleration tuning, dampened multipliers, scaled random multipliers,
  15% lowered base-speed tuning, serve-speed rally floor, minimum vertical
  bounce correction, and base speed capping. Champion League caps effective
  speed at 26, Mythic League uses its own 32 effective-speed cap,
  Power-Smashing uses a difficulty-independent 35 effective-speed cap,
  Magnum Grip pulled-ball player hits can temporarily raise the cap to 45,
  and Smasher Wheel ball hits use a difficulty-independent 60
  effective-speed cap.
- `scripts/ball/ball_impact_boost_policy.gd`
  Owns paddle-hit momentary acceleration policy: speed-dependent impact
  boost shaping, 65% amplified launch burst with angle-fixed boost and
  straight-hit 1.0s decay with 1.02s to 0.82s wide-angle decay tuning,
  vertical-shot decay strengthening, speed-normalized
  boost travel distance with delayed high-speed burst softening, slow rally
  carry-floor ramping, straight high-rally carry-floor clamping with a balanced late-rally floor, 15% raised
  overall boost scale tuning, reduced serve-only launch burst, stage boost caps,
  early-rally boost softening, junior boost scaling,
  decay-rate calculation, and the public boost-policy facade.
- `scripts/ball/ball_impact_angle_boost_policy.gd`
  Owns paddle-hit angle boost lookup. Current tuning intentionally returns
  the straight-hit boost multiplier for every angle, leaving outgoing angle
  to affect decay duration rather than launch boost strength.
- `scripts/ball/ball_impact_decay_policy.gd`
  Owns per-frame impact boost decay after paddle-hit acceleration has been
  applied, honoring the configured decay-rate duration.
- `scripts/ball/ball_intensity.gd`
  Owns ball rally tracking and intensity level progression, while
  delegating color / glow palette rules to the focused palette module.
  `battle_draw_ball_context.gd` asks this module for draw-time colors /
  glow / intensity directly instead of mirroring those values as scene
  variables.
- `scripts/ball/ball_intensity_palette.gd`
  Owns ball intensity color policy: level palettes, glow colors, and
  display-level blending between adjacent intensity levels.
- `scripts/ball/ball_effects.gd`
  Owns the public ball effect-state facade and delegates ghost trail and
  intensity particle / trail runtime state to focused modules. It also
  stores the current hit-pulse event consumed by node-backed ball VFX.
  The scene shell no longer keeps mirrored effect arrays; draw code reads
  the owning module snapshots at the narrow render call site.
- `scripts/ball/ball_ghost_trail_state.gd`
  Owns ball ghost-trail runtime state: interpolation between ball
  positions, max-length trimming, alpha fade, point age, and trail reset.
  Trail point payload dictionaries are delegated to
  `ball_effect_payload_factory.gd`.
- `scripts/ball/ball_intensity_effect_state.gd`
  Owns the public ball intensity effect facade: color fallback selection,
  low-intensity update gating, clear / update fanout, and renderer-facing
  particle / trail accessors.
- `scripts/ball/ball_intensity_particle_state.gd`
  Owns ball intensity particle runtime state: speed-scaled particle spawn,
  low-intensity particle drift, flame / spark decay, and
  intensity-dependent max-particle capping. Particle payload dictionaries are
  delegated to `ball_effect_payload_factory.gd`.
- `scripts/ball/ball_intensity_trail_state.gd`
  Owns ball intensity trail runtime state: trail point sampling,
  spacing-based interpolation, trail length capping, alpha fade, and size
  decay. Trail point payload dictionaries are delegated to
  `ball_effect_payload_factory.gd`.
- `scripts/ball/ball_effect_payload_factory.gd`
  Owns pure ball VFX payload construction for ghost-trail points, intensity
  trail points, and intensity flame / spark particles. The state modules keep
  sampling, LOD, fade, simulation, and cap policy.
- `scripts/ball/ball_effects_renderer.gd`
  Owns drawing orchestration for ball ghost trails, intensity effects,
  and energy-explosion particles. `battle_playfield_ball_drawer.gd` and
  `battle_playfield_scene_drawer.gd` own draw ordering and pass draw-time
  snapshots from the owning state modules.
- `scripts/ball/ball_intensity_effect_renderer.gd`
  Owns ball intensity effect drawing: intensity trail points, flame /
  spark particles, active ball glow, default display colors, and color
  brightening.
- `scripts/ball/ball_renderer.gd`
  Owns current-ball canvas draw dispatch and delegation to focused ball
  body / status-overlay render helpers. `ball_update_controller.gd` owns
  active-frame physics orchestration, while `battle_draw_ball_context.gd`
  passes a compact visual snapshot into the renderer.
- `scripts/ball/bomb_ball_renderer.gd`
  Owns bomb-ball body rendering: dark shell, fuse line, blinking fuse
  flame, and shell outline.
- `scripts/ball/ball_status_overlay_renderer.gd`
  Owns current-ball status overlay drawing: poisoned green aura / motes
  and Viper knockback fire aura / embers.
- `scripts/ball/energy_ball_renderer.gd`
  Owns the default energy-ball canvas drawing: glow rings, boost-charge
  rainbow tint, core highlights, and delegation to the orbit and ambient
  energy particle renderers. It also syncs the optional node-backed energy
  ball FX host for shader / GPU-particle / tween embellishments.
  `ball_renderer.gd` delegates the energy visual path here.
- `scripts/ball/energy_ball_texture_cache.gd`
  Owns one-time procedural texture baking for the default energy-ball body:
  solid core and highlight texture shards reused by the canvas renderer so
  high-quality core layering does not allocate per frame.
- `scripts/ball/energy_ball_fx_host.gd`
  Owns the node-backed default energy-ball embellishment layer: additive
  ShaderMaterial core wash, GPUParticles2D aura motes, one-shot hit-burst
  particles, and Tween-driven pulse / burst scale. The canvas renderer
  keeps the authoritative ball body while this host follows the current
  draw position in screen coordinates.
- `scripts/ball/energy_ball_orbit_renderer.gd`
  Owns the default energy-ball orbit drawing facade: ring rotation / tilt /
  radius configuration and delegation to the focused orbit-ring renderer.
- `scripts/ball/energy_ball_orbit_ring_renderer.gd`
  Owns one energy-ball orbit ring draw pass: ring point-cloud geometry,
  depth-tinted ring colors, connector lines, and bright orbit glints.
- `scripts/ball/energy_ball_particle_renderer.gd`
  Owns the default energy-ball ambient particle state and drawing:
  particle spawning, life aging, max-particle capping, glow circles, and
  particle reset.
- `scripts/ball/pingpong_ball_renderer.gd`
  Owns ping-pong ball body rendering: texture draw fallback, procedural
  white ball fallback, and spin angle state reset.
- `scripts/ball/prism_ball_renderer.gd`
  Owns prism-ball body rendering: rainbow orbit point rings, depth tint,
  white core, and highlight.
- `scripts/ball/ball_motion_stepper.gd`
  Owns per-frame ball sweep detection: sub-step movement, left/right wall
  / active Brick Wall / paddle / Holy Barrier collision detector delegation,
  detector-owned contact-position preservation, and top/bottom score events.
  Stopwatch score-block context can suppress the bottom-score event while the
  time-stop / recovery window is active. The ball update controller owns the
  reactions to those events.
- `scripts/ball/ball_motion_collision_detector.gd`
  Owns ball motion collision tests used during sweep stepping: left/right
  wall clamping and impact positions plus player / boss paddle hitbox
  overlap snapshots, active Brick Wall overlap snapshots, and active Holy
  Barrier bottom-wall overlap snapshots. The player-paddle branch also
  consumes shared `dash_acceleration` context to inflate the collision
  hitbox vertically (+70%/Lv) and horizontally (+10%/Lv) around its unchanged
  center during an active dash. The restrained horizontal expansion is an
  intentional Godot extension beyond Python's vertical-only behavior and is
  sized to remain inside the rendered wing aura. On committed 대붕전익 contact,
  it also separates the ball through the nearest incoming/side surface before
  the same-tick bounce, preventing an overlapped sample from looking like the
  ball was pulled into the wing and fired back out. The Stage 5 Hongryun
  motion-bypass guard reuses the same resolver through `ball_update_controller`.
- `scripts/ball/ball_update_controller.gd`
  Owns active-ball frame orchestration: freeze-frame handoff, base-speed
  caps, impact-boost decay, Drive spin decay, Power Smashing motion,
  Stage 2 quake ball-motion application, active-item Magnet Field pull
  application, motion-step event processing, scoring event reporting,
  post-step Dash Spirit laser collision checks, and ball trail / intensity
  updates. `battle_scene_ball_update_driver.gd` applies the returned scene
  snapshot and forwards score events to the match flow controller.
- `scripts/ball/ball_frame_motion_controller.gd`
  Owns active-ball frame motion modifiers: Power Smashing freeze handoff,
  base-speed capping, serve-speed floor enforcement for base and effective
  movement speed, impact-boost decay, Drive spin application, Power
  Smashing parabola motion mergeback, Dash Spirit one-shot reflection
  mergeback, and active-item Magnet Field vector correction for balls last
  hit by the boss.
- `scripts/ball/ball_motion_event_processor.gd`
  Owns active-ball motion-step event handling: motion-stepper invocation,
  wall / active Brick Wall / paddle / Holy Barrier dispatch, scene mergeback
  from bounce results, and top / bottom score-event translation, including
  the Stage 2 quake boss-hit top backstop before a player-score event is
  accepted.
- `scripts/ball/ball_update_context.gd`
  Owns ball-frame context assembly for active-ball updates, reset config,
  serve config, and delegation to dependency-map builders. It composes
  owner-field snapshots with static gameplay config instead of keeping the
  wide fanout inline.
- `scripts/ball/ball_update_owner_snapshot.gd`
  Owns dynamic owner-field extraction for ball-frame updates: live ball
  state, Drive flags, player / boss positions, timing counters, and hit
  sprite availability flags.
- `scripts/ball/ball_update_static_config.gd`
  Owns static ball update config: court dimensions, ball / paddle sizes,
  Drive / Power Smashing constants, 500 max-gauge constants, speed caps, reset
  config, and serve config including the visual serve-ball radius used to
  keep waiting-serve and launch-frame positions continuous.
- `scripts/ball/ball_dependency_context.gd`
  Owns ball update / round dependency map assembly from the gameplay
  module registry, including Power-Smashing counter knockback access to
  player movement state and Smasher Dash Spirit collision/reset state.
  This keeps registry key fanout out of the
  ball-frame context snapshot builder.
- `scripts/ball/ball_scene_bridge.gd`
  Owns the stable scene-facing ball bridge API and delegates physics /
  visual runtime state plus Drive-specific handoff to focused scene bridge
  modules. `battle_scene_shell.gd` keeps compatibility wrapper methods
  here.
- `scripts/ball/ball_runtime_scene_bridge.gd`
  Owns scene-facing ball runtime snapshots: external ball physics context
  configuration, league-mode normalization, visual-state snapshots, and
  owner snapshot application.
- `scripts/ball/ball_drive_scene_bridge.gd`
  Owns scene-facing Drive ball state handoff: Drive activation snapshots,
  Drive clear snapshots, Power-Smashing state clear, and Drive input reset.
  The ball scene bridge keeps the stable external API and delegates these
  Drive-specific operations here.
- `scripts/ball/ball_round_state.gd`
  Owns ball round-start snapshots: common ball / spin / Drive runtime
  resets, full ball reset position, serve placement with serve velocity
  from `ball_physics.gd`, serve launch boost, visual-continuity serve
  offsets, and serve collision cooldown fields. The ball round controller
  owns the surrounding reset / serve fanout.
- `scripts/ball/ball_round_controller.gd`
  Owns ball reset / serve orchestration around `ball_round_state`: applying
  reset and serve snapshots through the scene callback, invoking round
  cleanup, triggering serve impact feedback / sound, and returning player /
  boss position and speed fields for the scene-facing ball snapshot applier.
- `scripts/ball/ball_round_cleanup.gd`
  Owns reset / serve cleanup fanout: Power-Smashing / Drive input state,
  Smasher Magnum Grip / Dash Spirit / Warp Gate state, combo state /
  effects, VFX cleanup delegation, round wait delegation, actor round-state
  delegation, and battle-feedback round-state handoff.
- `scripts/ball/ball_round_effect_cleanup.gd`
  Owns reset / serve visual cleanup: ball VFX, impact VFX, ball renderer
  cache, and rally intensity reset.
- `scripts/ball/ball_round_actor_cleanup.gd`
  Owns reset / serve actor cleanup: round wait state, AI state,
  animation state, Power-Smashing counter knockback state, dash round
  state, Viper skill runtime round state, Commando supply / weapon round
  state, and feedback reset token count.
- `scripts/ball/ball_spin_state.gd`
  Owns Drive-ball spin lifecycle: per-frame spin force / decay, Drive ball
  activation speed bump, and Drive state clearing snapshots. Ball snapshot
  application lives in the ball update driver, while character skill
  activation timing lives in the character controllers.
- `scripts/ball/wall_bounce_state.gd`
  Owns wall-bounce velocity response: impact-speed calculation, left/right
  horizontal reflection, damping, wall-hit screen-shake values, and Python
  parity no-paddle rematch detection after repeated alternating left/right
  wall bounces. Paddle hits and ball resets clear this guard; the core
  match-flow layer only consumes the resulting restart request.
- `scripts/ball/wall_bounce_controller.gd`
  Owns wall-bounce reaction fanout: wall-hit sound playback, wall-impact
  VFX spawning, Stage 1 pillar tree-shake triggering, and battle-feedback
  screen shake. The ball motion event processor merges the returned ball
  velocity into the active-ball scene snapshot.
- `scripts/ball/paddle_bounce_state.gd`
  Owns the public shared paddle-bounce velocity facade: initial speed
  lookup and resolved velocity request forwarding. The paddle bounce
  controller consumes this stable API.
- `scripts/ball/paddle_bounce_velocity_resolver.gd`
  Owns shared paddle-bounce velocity orchestration: base / boss hit speed
  multiplier delegation, contact-shape resolver handoff, normal curve
  chance, final speed clamp, and vertical anti-stall guard delegation.
- `scripts/ball/paddle_bounce_contact_shape_resolver.gd`
  Owns paddle-bounce contact-shape selection: boss center-preserve
  correction, Drive contact-shape callback handoff, and normal center /
  mid / smash shaping result normalization.
- `scripts/ball/paddle_bounce_speed_multiplier_resolver.gd`
  Owns paddle-bounce speed multiplier application: base hit multiplier,
  boss hit multiplier, and angle-softened edge-hit boost ordering.
- `scripts/ball/paddle_bounce_vertical_stall_guard.gd`
  Owns paddle-bounce vertical anti-stall correction: tracking near-vertical
  returns, applying small/random escape rotations, and returning the
  updated vertical-bounce counter.
- `scripts/ball/paddle_bounce_velocity_rules.gd`
  Owns low-level shared paddle-bounce velocity rules: dampened multiplier
  lookup, scaled random multiplier lookup, boss center-preserve correction,
  normal center / mid / smash contact shaping, and minimum vertical
  correction.
- `scripts/ball/paddle_bounce_controller.gd`
  Owns paddle-hit orchestration: dynamic impact-boost updates, resolved
  bounce state application, final ball-position snapping, and delegation
  to paddle-hit skill-flow / event helpers. The ball motion event processor
  merges the returned scene-state snapshot.
- `scripts/ball/paddle_bounce_player_skill_step.gd`
  Owns the player-only paddle-hit skill step: invoking player skill flow,
  merging skill results into the paddle-bounce frame state, and returning
  normalized power / Drive activation plus speed / angle updates.
- `scripts/ball/paddle_bounce_velocity_step.gd`
  Owns the paddle-hit velocity step: invoking the resolved paddle-bounce
  velocity state with the current serve-speed floor, merging the bounce
  result into frame state, and returning the updated ball velocity.
- `scripts/ball/paddle_bounce_post_hit_step.gd`
  Owns the paddle-hit post-hit step: invoking the post-hit handler,
  merging post-hit results into frame state, and returning final ball /
  actor speed values for the result snapshot.
- `scripts/ball/paddle_bounce_frame_state.gd`
  Owns mutable per-hit paddle-bounce frame values: context extraction,
  dynamic impact boost snapshot with outgoing launch-angle handoff,
  acceleration scale lookup, skill-result mergeback, bounce-result mergeback,
  post-hit mergeback, and final
  scene-state snapshot assembly.
- `scripts/ball/paddle_bounce_skill_flow.gd`
  Owns player paddle-hit skill flow around the shared skill router:
  Drive-state clearing, Power Smashing activation attempts, Drive skill
  flow delegation, and normalized skill-result snapshots.
- `scripts/ball/paddle_bounce_drive_skill_flow.gd`
  Owns paddle-hit Drive skill activation result flow: invoking the shared
  skill router and normalizing Drive activation snapshots for mergeback.
- `scripts/ball/paddle_bounce_post_hit_handler.gd`
  Owns paddle-hit post-processing after the velocity is resolved: final
  Power-Smashing hit velocity adjustment, rally feedback, normalized
  post-hit scene snapshots, and delegation to player / boss post-hit
  handlers.
- `scripts/ball/paddle_bounce_player_post_hit_handler.gd`
  Owns player paddle-hit post-processing: ball snap to the player paddle,
  Power-Smashing freeze-pose lock, temporary player / boss freeze speeds,
  player hit animation, combo registration, gauge gain handoff through the
  event router, and stage-owned player-hit notifications such as Stage 2
  quake cancellation.
- `scripts/ball/paddle_bounce_boss_post_hit_handler.gd`
  Owns boss paddle-hit post-processing: ball snap to the boss hitbox,
  Drive boss-counter mergeback, Power-Smashing boss-counter cleanup /
  knockback side-effect handoff, boss hit animation handoff, and
  stage-owned boss-hit skill notifications such as Stage 2 악어장군
  boss-gauge gain.
- `scripts/ball/paddle_bounce_power_hit_handler.gd`
  Owns paddle-hit Power Smashing handoff: hit-velocity resolver call,
  Power-Smashing trail spawn, and original blue-white activation burst
  particles.
- `scripts/ball/paddle_bounce_skill_router.gd`
  Owns paddle-hit skill routing: Power-Smashing activation request
  assembly, Drive activation router delegation, and Drive-state clearing
  snapshots used when Drive is countered or superseded by Power Smashing.
  The paddle bounce controller consumes its returned activation snapshots.
- `scripts/ball/paddle_bounce_drive_activation_router.gd`
  Owns paddle-hit Drive activation request assembly: Drive activation
  context, focused dependency dictionary, and controller invocation.
- `scripts/ball/paddle_bounce_event_router.gd`
  Owns paddle-hit side-effect fanout: combo-aware gauge gain, dash /
  dash-recovery gauge-gain blocking, Drive boss counter decay,
  Power-Smashing counter speed reset plus combo knockback trigger, actor
  hit animations, Power-Smashing pending contact offsets, Python-parity
  intensity-based paddle-hit self-knockback dispatch, and delegation to
  rally feedback side effects. The paddle bounce controller calls this
  after resolving the core bounce.
- `scripts/ball/paddle_bounce_rally_feedback_router.gd`
  Owns paddle-hit rally feedback side effects: intensity hit registration,
  energy explosion / paddle particles, baseline screen shake merged via
  `max_screen_shake()` so stronger item / skill impact feedback is not
  overwritten, and non-Power-Smashing paddle-hit sound.
- `scripts/effects/impact_effects.gd`
  Owns the public generic impact-effect state API used by the rally loop
  and delegates paddle-hit, wall-impact, and energy / Drive spark storage
  to focused effect-state modules.
- `scripts/effects/impact_paddle_effect_state.gd`
  Owns paddle-hit particle / ring / streak / flash lifetime updates and their
  player / boss color palette. Payload dictionaries are delegated to
  `impact_effect_payload_factory.gd`.
- `scripts/effects/impact_wall_effect_state.gd`
  Owns wall-impact flash timing, wall-impact position, and wall-impact
  particle / ring lifetime updates. Payload dictionaries are delegated to
  `impact_effect_payload_factory.gd`.
- `scripts/effects/impact_energy_effect_state.gd`
  Owns energy explosions and Drive spark particles shared by ball and
  skill feedback paths. Payload dictionaries are delegated to
  `impact_effect_payload_factory.gd`.
- `scripts/effects/impact_effect_payload_factory.gd`
  Owns pure shared impact VFX payload construction for paddle sparks / rings /
  streaks / flashes, wall rings / particles, energy bursts, and Drive sparks.
  The state modules keep public spawn APIs, lifetime updates, caps, and
  renderer-facing arrays.
- `scripts/effects/battle_feedback_state.gd`
  Owns scene-level battle feedback timers: screen shake, gauge-gain flash,
  dash-token flash, dash-token divider animation, and controller rumble
  dispatch for player paddle hits.
  Gameplay branches still trigger these events, while the battle effects
  update controller advances the timers and draw-time render modules read
  the values. The battle-scene drawer applies the shake offset to the
  transformed playfield pass for full-field impact feedback.
- `scripts/core/gamepad_vibration_settings.gd`
  Owns the persisted 1-5 gamepad vibration sensitivity setting. Level 3 is
  the shipped rumble baseline, while the pause/settings controls tab edits
  the stored value and `battle_feedback_state.gd` applies it at dispatch time.
- `scripts/core/language_settings.gd`
  Owns the persisted UI language setting for the Godot port. It normalizes the
  supported Korean / English / Simplified Chinese locale codes, stores the
  selected language under `user://language_settings.cfg`, applies the engine
  locale, and provides the current shared text table for pause/settings,
  main-menu quit confirmation, display / render pacing labels, combat HUD
  labels, skill / perk overlays, item cinematic feedback, weather status copy,
  boss skill cards, and stage-clear result text. It aliases the localization
  data maps from `language_settings_data.gd` so existing callers can continue
  reading `LanguageSettings.TEXT`, item maps, perk maps, exact text maps, and
  quality prefixes without owning the bulky static data. Skill configs and
  runtime renderers should call this owner for locale-specific UI text instead
  of duplicating local translation dictionaries. `boot_flow_scene.gd` and
  `main_menu_scene.gd` apply the saved language on startup, while
  `pause_menu_overlay.gd` owns the visible language tab interaction.
- `scripts/core/language_settings_data.gd`
  Owns the static localization data maps for active / mythic item names,
  mythic descriptions, perk names / summaries, character-select metadata,
  skill-config copy, exact Korean text, composed-label patterns, native
  language names, and passive quality prefixes. Keep runtime language
  normalization, persistence, pattern translation, and formatting behavior in
  `language_settings.gd`; this file should stay data-only.
- `scripts/effects/battle_effects_update_controller.gd`
  Owns per-frame battle-effect fanout: battle feedback timers, audio tick,
  dash-recovery loop sync, Drive text timer decay, Power Smashing text /
  VFX update, Smasher Magnum Grip / Dash Spirit / Warp Gate effect-state
  updates, combo timer update, Stage 1 background update, gauge / dash orb
  spin sync, actor animation update, and impact-particle update.
  `battle_scene_effects_update_driver.gd` applies returned effect fields
  such as Drive text timer values. Top
  mini-scoreboard visual sparkle is intentionally advanced from the
  idle-process scene update driver so the display can redraw at monitor
  refresh instead of physics tick rate.
- `scripts/effects/impact_effects_renderer.gd`
  Owns generic impact canvas drawing: paddle-hit particles and rings,
  wall-impact flash / rings / particles, and cached shockwave texture
  blits. `battle_playfield_effects_drawer.gd` owns draw ordering and passes
  the impact state object to the renderer.
- `scripts/effects/impact_shockwave_texture_cache.gd`
  Owns one-time procedural texture baking for reusable hit and wall
  shockwave rings. Generic impact rendering and Smasher Shield Kiting hit
  feedback reuse these textures instead of rebuilding arc geometry during
  contact frames.
- `scripts/effects/impact_flare_texture_cache.gd`
  Owns one-time procedural texture baking for reusable 2D impact polish:
  soft glows, radial light bursts, and sparkle flashes. Generic impact
  rendering and Smasher Shield Kiting hit feedback reuse these textures so
  higher-quality contact effects stay texture-blit based instead of
  per-frame procedural draw heavy.
- `scripts/effects/writhe_ember_material.gd`
  Owns the shared modular VFX shader family for bright alpha-backed texture
  pieces that need living motion. It exposes preset-driven `ShaderMaterial`
  construction for chaos cracks, Stage 4 meditation mandalas, Stage 4
  magnetic lattice / charge glyphs, and future charge-glyph style backplates.
  Presets tune the common uniform lanes: `elapsed`, `intensity`,
  `distort_strength`, `lateral_strength`, `jitter_strength`, flow speed,
  flicker / pulse speed, breath amplitude, and hot / ember / amethyst color
  ramps. Future writhing cracks, lightning branches, energy lattices, vines,
  roots, or curved streams should add a preset here before cloning shader
  code in a feature-specific host.
- `scripts/audio/game_audio.gd`
  Owns battle sound setup-group composition and playback: paddle / wall hit
  cooldowns,
  serve and ping-pong serve sounds, dash and half-dash sounds, looping
  dash-recovery control-loss sound, active-item throw / grenade / flashbomb
  sounds, Drive / Power Smashing sounds, Dash Spirit delete sound, launch
  sound, Commando supply / fire-support radio and aircraft loops, Commando
  firearm-specific fire / impact cue wrappers, AK-47 rapid-fire layered
  player mixing, Horn Strawberry transform / eat / stem / field / horn /
  bomb-trigger dedicated cues, round-set sound, Stage 2 hydro / stone-break /
  rock-hit / rock-spawn / boss-cry / quake-loop cues, Stage 1 BGM looping
  with Python's per-track gain, pitch randomization, and audio-player factory
  delegation. It retains public Guardian Spirit click-voice player properties,
  final pitch/play policy, lazy replacement SFX-bus configuration, and staged
  setup group side effects while delegating that catalog and player cache to
  `lingpet_click_voice_audio.gd`. It retains the three Guardian Spirit
  acquisition compatibility player properties, public playback/fallback
  policy, cut-in pitch jitter, and item-phase orchestration while delegating
  those cue specs and player cache to `lingpet_acquisition_audio.gd`. It also
  retains Guardian Spirit combat-cue
  play/stop/sync facades, pitch/fallback policy, random egg-hit playback, and
  safe loop-stream mutation while delegating those player specs and caches to
  `lingpet_combat_audio.gd`.
  It retains audio-bus compatibility constants/properties, complete player
  projections, public volume APIs, cue playback/pitch, hit cooldowns, and
  event-time source-X selection while delegating bus creation/routing, volume
  state/adoption, panner effects/cache, and pan geometry to
  `game_audio_bus_controller.gd`.
  It retains stage BGM compatibility constants/player properties, owner-stage
  filtering, per-step player/mute setup side effects, and shared-stream-safe
  loop mutation
  while delegating nine track specs, ordered prewarm/catalog pools, and player
  cache to `stage_bgm_audio.gd`. It retains public BGM method and state/RNG
  property facades while delegating prime/play/stop/mute state, shared mute
  persistence, and Stage 1/2 selection RNG to
  `stage_bgm_playback_controller.gd`.
  It retains UI move/confirm/back/perk-select/character-info-toggle
  compatibility constants and
  properties, public playback/pitch/fallback policy, bus volume, and modal
  event timing while delegating five one-shot specs, eager setup, step-0
  prewarm/SFX-bus head order, and player cache to
  `game_ui_feedback_audio.gd`.
  It also exposes `set/is_character_info_bgm_muffled` and releases the muffle
  from `stop_bgm()` while delegating the filter itself to
  `game_audio_bus_controller.gd`.
  It retains core ball/dash compatibility properties, hit cooldown/panning,
  public playback and selection/fallback policy, and shared-stream-safe Dash
  Delay loop mutation/cleanup while delegating twelve cue specs, eager
  setup/prewarm/SFX-bus order, and player cache to `core_ball_dash_audio.gd`.
  It retains item/reward/defeat/Cold Boot/legendary-cinematic/generic-action
  compatibility constants and player properties, public playback/fallback and
  pitch policy, explicit Legendary After stopping, the Angel Blessing
  three-player rotation cursor, and forced Angel cleanup while delegating
  twenty-six primary cue specs, two optional absorb layers, three phase-correct
  setup/prewarm/SFX projections, and cache ownership to
  `item_reward_feedback_audio.gd`.
  It retains projectile-item compatibility constants/properties, public
  playback/fallback and pitch policy, dynamic Dynamite Fuse lifecycle, Bomb
  Surprise tick-volume policy, and safe Boomerang/Spider Mine loop mutation
  and cleanup while delegating twenty-four specs, twenty-three resident
  players, split setup order, selective prewarm, SFX projection, and cache
  ownership to `projectile_item_audio.gd`.
  It retains Horn Strawberry/Odin's Eye compatibility constants/properties,
  public playback aliases, pitch/fallback policy, explicit Eat stopping, and
  transformation event timing while delegating fourteen cue specs, eager
  setup, Horn-only prewarm, split SFX-bus projection, and player cache to
  `transformation_item_audio.gd`.
  It retains Ragnarok/Electric Shock/Poseidon and Lumion lightning
  compatibility constants/properties, public playback/fallback and RNG policy,
  plus shared-stream-safe loop mutation and cleanup while delegating ten cue
  specs, eager setup/SFX-bus order, nine-path prewarm, three Mini Spark
  candidates, loop membership, and player cache to
  `elemental_combat_audio.gd`.
  It retains shared round/intro/balloon/star/leaf-shield/trampoline
  compatibility constants/properties, public playback/pitch/fallback policy,
  and explicit ball-spawn intro stopping while delegating nine one-shot specs,
  split primary/tail setup/prewarm/SFX projections, and player cache to
  `shared_stage_feedback_audio.gd`.
  It retains Stage 1 Dalji/Gaksital compatibility properties, public playback,
  pitch/dynamic-volume policy, fan-pool cursor, and Whip cleanup while
  delegating three primary cue specs, two extra fan players, interleaved setup,
  unique prewarm, split SFX-bus projections, and cache ownership to
  `stage1_boss_skill_audio.gd`.
  It retains Blacksmith Thor Shield compatibility properties and public
  playback/pitch policy while delegating the four one-shot cue specs, eager
  creation/SFX-bus order, and player cache to
  `blacksmith_thor_shield_audio.gd`. Those cues retain their no-explicit-prewarm
  policy and non-looping cached streams.
  It retains Smasher compatibility player/voice-stream properties, public
  playback, pitch/voice-RNG policy, and shared-stream-safe loop mutation while
  delegating thirteen base skill cues, four Power/Ghost Smashing feedback cues,
  split setup/prewarm/SFX-bus projections, player cache, and both four-stream
  cut-in voice pools to `smasher_skill_audio.gd`.
  It retains Viper/Chaos compatibility player properties, public playback,
  pitch/fallback policy, and shared-stream-safe Jetpack/black-hole loop mutation
  while delegating twenty-two cue specs, eager setup/SFX-bus order, selective
  prewarm projection, and player cache to `viper_skill_audio.gd`.
  It retains Commando compatibility player properties, playback/pitch/fallback
  policy, the four-player AK-47 rotation cursor, and shared-stream-safe loop
  mutation while delegating nineteen primary cue specs, optional setup order,
  selective prewarm/SFX-bus projections, and three extra AK-47 layers to
  `commando_skill_audio.gd`. The historical supply-radio loop name remains a
  non-looping one-shot; central cleanup still force-stops it at boundaries.
  It retains Stage 7 Akamu compatibility player properties, public playback
  methods, and per-cue pitch policy while delegating the six cue specs, eager
  creation/prewarm order, and player cache to `stage7_akamu_audio.gd`.
  It retains Stage 5 Hongryun compatibility player properties, public
  play/stop methods, pitch policy, and random hurt selection while delegating
  the primary/hurt catalogs, split setup/prewarm order, and player caches to
  `stage5_hongryun_audio.gd`.
  It retains Stage 6 Tetriser compatibility player properties, public playback
  methods, and per-cue pitch policy while delegating the six cue specs, eager
  creation order, and player cache to `stage6_tetriser_audio.gd`. The facade's
  stage prewarm list intentionally remains free of those six paths.
  It retains Stage 2 compatibility player properties, one-shot and size-banded
  stonebreak pitch policy, Quake play/stop/sync, and shared-stream-safe loop
  mutation while delegating nine cue specs, setup/prewarm order, and player
  cache to `stage2_battle_audio.gd`.
  It retains Stage 3 compatibility player properties, one-shot pitch policy,
  Psychoball play/stop/sync, and shared-stream-safe loop mutation while
  delegating eleven cue specs, optional stonebreak creation, setup/prewarm
  order, and player cache to `stage3_battle_audio.gd`. Bomb Surprise retains a
  separate semantic alias for its shared weak-explosion WAV.
  It retains Stage 4 Ponk compatibility player properties, one-shot pitch
  policy, magnetic play/stop/sync, and shared-stream-safe loop mutation while
  delegating the seven cue specs, setup/prewarm order, and player cache to
  `stage4_ponk_audio.gd`.
- `scripts/audio/lingpet_click_voice_audio.gd`
  Owns the Guardian Spirit click-reaction voice catalog for all eleven
  supported pets, stable eager player-creation order, the existing four-stream
  prewarm list, normalized pet-id lookup, ordered player enumeration, and
  missing-stream recovery. Unsupported pet ids remain silent. It does not own
  global SFX-bus application or final playback pitch.
- `scripts/audio/lingpet_acquisition_audio.gd`
  Owns the three Guardian Spirit acquisition-cinematic cue specs, stable eager
  player-creation order, ordered item-phase prewarm projection, player cache,
  and missing-stream recovery. It preserves optional-player fallback creation
  but does not own cut-in pitch jitter, item-get fallback, or final playback
  order.
- `scripts/audio/lingpet_combat_audio.gd`
  Owns twenty-seven Guardian Spirit combat-cue specs, item/projectile/stage
  phase player creation order, selective item/stage prewarm projection,
  phase-correct SFX-bus player enumeration, and the two loaded egg-hit
  candidates. The stage projection deliberately keeps only the two Ghost
  Summon players in the global SFX list; skeleton/barrier cues retain their
  previous exclusion. Star Coil movement and projectile-phase cues retain
  their existing lazy prewarm policy. It does not own playback pitch,
  fallbacks, or loop-stream mutation.
- `scripts/audio/smasher_skill_audio.gd`
  Owns thirteen base Smasher skill-cue specs, four Power/Ghost Smashing
  stage-feedback specs, their phase-stable setup/prewarm/SFX-bus projections,
  player cache, and two four-stream cut-in voice pools. It does not own
  playback pitch/voice RNG, shared-stream loop mutation, event timing, or
  round cleanup.
- `scripts/audio/game_audio_bus_controller.gd`
  Owns BGM/SFX and Paddle/Wall pan-bus names, default and adopted volume state,
  AudioServer bus creation/routing, volume application, panner installation/
  cache, source-X pan projection, and the character-info BGM low-pass filter
  (named-effect install/lookup, enable toggle, and setup-time re-sync to the
  stored muffle state). It does not own cue catalogs, playback,
  pitch, hit cooldowns, event timing, or player lifecycle.
- `scripts/audio/game_audio_setup_controller.gd`
  Owns the audio setup group/prewarm/BGM cursors, current group's borrowed
  stream path list, shared-cache checks and synchronous loading, the
  one-new-stream-per-call loading budget, 92/8 progress projection, and setup
  completion math. `game_audio.gd` retains the exact seven group path
  composition and setup side effects plus compatibility properties used by
  boot performance labels.
- `scripts/audio/stage_bgm_audio.gd`
  Owns nine Stage 1-7 BGM specs, authored linear gains, stable setup/prewarm
  order, Stage 1/2 selection pools, required-stream projection, and player
  cache. It does not own owner-stage filtering, setup progress, track
  selection/RNG, prime/play/stop/mute state, loop mutation, or bus volume.
- `scripts/audio/stage_bgm_playback_controller.gd`
  Owns current/muted names, prime-gain state, shared mute persistence, Stage
  1/2 selection RNG, fixed-stage routing, and prime/play/restart/stop/mute
  transitions. Catalog and player callbacks are invocation-scoped. It does not
  own paths, player creation, stream loop mutation, bus policy, or event timing.
- `scripts/audio/game_ui_feedback_audio.gd`
  Owns five UI Move/Confirm/Back/Perk Select/Character Info Toggle one-shot
  specs, native gains,
  stable eager setup, step-0 prewarm and global SFX-bus head order, and player
  cache. It does not own playback pitch/fallbacks, bus volume, or menu/modal/
  reward event timing. Sibling owner smokes anchor core ball/dash order off
  `get_cue_ids().size()`, never a hardcoded index — see the absolute-index
  trap in `docs/godot_runtime_traps.md`.
- `scripts/audio/core_ball_dash_audio.gd`
  Owns twelve Paddle/Serve/Wall and Dash cue specs, native gains, stable eager
  setup and step-0 prewarm order, global SFX-bus projection, and player cache.
  It does not own hit cooldowns, positional buses, playback pitch/selections or
  fallbacks, Dash Delay loop mutation, or round cleanup.
- `scripts/audio/item_reward_feedback_audio.gd`
  Owns twenty-six primary item, reward, defeat, perk-fusion Cold Boot,
  legendary-cinematic, and generic item-action cue specs plus two optional
  Angel Blessing absorb players. It preserves the original twenty-three-player
  head phase, two-player post-Guardian-Spirit cinematic phase, three-player
  post-elemental action phase, their matching split prewarm/SFX projections,
  absorb-layer tail projection, and player cache. The four Cold Boot cues stay
  outside prewarm. It does not choose playback pitch/fallbacks, stop Legendary
  After, advance the Angel pool cursor, mutate streams, or own forced cleanup.
- `scripts/audio/projectile_item_audio.gd`
  Owns twenty-four throwable/deployable cue specs, twenty-three resident
  players, the exact nine-player/loop-mutation/fourteen-player split setup,
  selective sixteen-path step-4 prewarm projection, global SFX-bus order, and
  player cache. Dynamite Fuse is cataloged here but intentionally created per
  use by the facade. It does not choose playback/fallbacks, mutate Boomerang or
  Spider Mine streams, own Bomb Surprise volume policy, or perform cleanup.
- `scripts/audio/transformation_item_audio.gd`
  Owns fourteen Horn Strawberry and Odin's Eye cue specs, exact nine-Horn then
  five-Odin eager setup, Horn-only nine-path prewarm, legacy split SFX-bus
  order, and player cache. Odin's five one-shots deliberately remain outside
  prewarm. It does not choose pitch/fallbacks, stop Horn Eat, mutate streams,
  or own transformation/revival event timing.
- `scripts/audio/elemental_combat_audio.gd`
  Owns ten Ragnarok, electric-shock, Lumion lightning, and Poseidon cue specs,
  exact eager setup/SFX-bus order, nine-path step-3 prewarm projection, three
  setup-time Mini Spark candidate streams, loop membership metadata, and player
  cache. Mini Spark deliberately stays outside explicit prewarm. It does not
  choose playback/fallbacks, consume RNG, mutate the two loop streams, or own
  event timing and round cleanup.
- `scripts/audio/shared_stage_feedback_audio.gd`
  Owns nine Round Set, ball-spawn/stage-landing intro, balloon, star, Laurel
  Leaf Shield, and Trampoline one-shot specs, their seven-player primary and
  two-player tail setup/prewarm/SFX projections, and player cache. It does not
  choose playback/pitch/fallbacks, consume RNG, stop intro audio, mutate
  streams, or own score/intro/stage/perk/field event timing.
- `scripts/audio/stage1_boss_skill_audio.gd`
  Owns the Stage 1 Dalji Whip, Gaksital Fan, and Gaksital Whipcrack specs plus
  two optional Fan players, their exact interleaved eager setup, three-path
  unique prewarm projection, split primary/tail SFX-bus projections, and player
  cache. It does not own playback pitch or dynamic volume, the fan-pool cursor,
  event timing, or round cleanup.
- `scripts/audio/blacksmith_thor_shield_audio.gd`
  Owns four Blacksmith Thor Shield one-shot cue specs, native gains, stable
  eager Open/Close/Swing/Block creation and SFX-bus order, and player cache. It
  deliberately exposes no explicit prewarm projection and does not own pitch,
  stream mutation, phase/collision event timing, or runtime cleanup.
- `scripts/audio/perk_fusion_combat_audio.gd`
  Owns the cross-character Mugong-fusion combat cue catalog, ordered
  stage-feedback setup/prewarm/SFX projection, and player cache. It currently
  ports the legacy `magicdefense.wav` Spellbreaker Guard parry one-shot at
  linear volume 0.5 and does not own playback timing, pitch policy, stream
  mutation, or round cleanup.
- `scripts/audio/viper_skill_audio.gd`
  Owns twenty-two Viper and Chaos Spear cue specs, native gains, stable eager
  creation and global SFX-bus order, selective twenty-one-path prewarm
  projection, and player cache. Marshal Kick deliberately reuses Shadow Kick's
  stream without adding a duplicate prewarm entry. It does not own playback,
  pitch/fallback policy, loop mutation, event timing, or round cleanup.
- `scripts/audio/commando_skill_audio.gd`
  Owns nineteen Commando primary cue specs, stable optional-player creation
  order, selective prewarm and global SFX-bus projections, primary player
  cache, and three extra AK-47 rapid-fire layers. It preserves the existing
  weapon-change SFX-list exclusion, net-constrict prewarm exclusion, and AK-47
  tail projection. It does not own playback/pitch/fallback policy, the pool
  cursor, loop mutation, or round cleanup.
- `scripts/audio/stage2_battle_audio.gd`
  Owns nine Stage 2 cue specs, native gains, stable eager player-creation order,
  ordered stage prewarm projection, and player cache. It does not mutate the
  Quake stream loop flag, choose playback or size-banded stonebreak pitch, or
  own round cleanup.
- `scripts/audio/stage3_battle_audio.gd`
  Owns eleven Stage 3 Menhera/Kuromi cue specs, native gains, stable eager
  player-creation order, optional stonebreak-player routing, ordered stage
  prewarm projection, and player cache. It does not mutate the Psychoball
  stream loop flag, choose playback pitch, or own round cleanup.
- `scripts/audio/stage4_ponk_audio.gd`
  Owns seven Stage 4 Ponk cue specs, native gains, stable eager player-creation
  order, stage prewarm projection, and player cache. It does not mutate the
  magnetic stream loop flag, choose playback pitch, or own round cleanup.
- `scripts/audio/stage5_hongryun_audio.gd`
  Owns the three Stage 5 Hongryun primary cue specs and three-stream hurt pool,
  including their deliberately split eager setup, prewarm, cache, and global
  SFX projection positions. It does not own playback pitch, stop policy,
  random hurt selection, or Stage 5 event timing.
- `scripts/audio/stage6_tetriser_audio.gd`
  Owns six Stage 6 Tetriser one-shot cue specs, native gains, stable eager
  player-creation order, and player cache. It deliberately does not expose a
  prewarm projection, choose pitch, or own combat-feedback trigger timing.
- `scripts/audio/stage7_akamu_audio.gd`
  Owns the six Stage 7 Akamu one-shot battle-cue specs, native gains, stable
  eager player-creation order, ordered stage prewarm projection, and player
  cache. It does not own playback pitch or the shuriken/cloud/aura/clone event
  timing retained by the GameAudio facade and Stage 7 state modules.
- `scripts/audio/gameplay_loop_audio_cleanup.gd`
  Owns the shared hard-stop list for non-BGM gameplay loop sounds across
  score events, scoreboard / serve-wait frames, round restart, ball reset,
  stage debug reset, and full game reset. New looped or sustained stop-capable
  gameplay SFX must add their `stop_*` method here when introduced; this list
  includes Dual Glitch wind-up so startup cancellation cannot leak its cue.
- `scripts/audio/game_audio_player_factory.gd`
  Owns AudioStreamPlayer creation for battle sounds: bus / volume setup,
  resource loading, raw WAV / MP3 / OGG fallback loading,
  missing-resource warnings, and parent attachment.
- `scripts/core/battle_scene_bootstrap.gd`
  Owns battle-scene startup wiring: initial player / boss placement,
  audio setup, battle texture loading, Smasher skill icon extraction,
  and initial ball-physics context configuration through the shared
  registry cache. The lifecycle module applies the returned startup
  snapshot and then enters the normal reset / serve flow.
- `scripts/core/battle_scene_shell.gd`
  Owns the thin Node2D shell inherited by `scenes/main.gd`: registry
  creation, dynamic scene-state `_get` / `_set`, Godot callback bridges,
  and public compatibility wrapper names. The shell delegates startup,
  update, draw, and public ball API behavior to registered modules. Its idle
  bridge also performs the one-per-frame nonblocking collection of detached
  threaded-texture results before delegating battle update. Module
  instance caching and cached-only cleanup lookups live in the gameplay
  module registry / script-instance cache, and boot / intro readiness gates
  live in the battle scene readiness controller, not in the shell. Modal /
  debug overlay pause gates live in the battle scene modal-gate controller.
  BattlePerf draw logging is emitted after `draw.shell.total` closes so log
  formatting is not charged to frame-controller or shell draw samples.
- `scripts/core/battle_scene_lifecycle.gd`
  Owns Godot scene startup lifecycle: random setup, canvas texture policy,
  window layout configuration, bootstrap snapshot application, and initial
  ball reset / ball-update prewarm through the update driver.
- `scripts/core/battle_scene_readiness_controller.gd`
  Owns shared boot / intro readiness checks for the battle scene: logo
  intro active, boot warmup finished, stage-landing intro active,
  ball-spawn intro active, early input blocking, and mobile-touch scene
  readiness. Shell, input, and frame controllers should call this module
  instead of duplicating `is_active()` ladders for intro gates.
- `scripts/core/battle_scene_modal_gate_controller.gd`
  Owns shared modal / debug overlay gate checks for the battle scene:
  runtime perk choice and feedback state, runtime perk debug picker,
  passive / mythic management menu, F6 weather debug picker, character
  info overlay, active-item debug spawn menu, physics blocking, and
  mobile-control blocking.
  Input, frame, and mobile-touch controllers should call this module
  instead of repeating menu-open predicates.
- `scripts/core/battle_boot_warmup_plan.gd`
  Owns the boot warmup module-group lists: startup, item runtime, update
  runtime, ball runtime, and draw runtime prewarm keys. The warmup
  controller reads this plan instead of carrying long inline module arrays
  inside the step executor.
- `scripts/core/battle_boot_resource_prewarm_controller.gd`
  Owns boot-time resource prewarm state and resource/audio prewarm actions:
  battle texture groups, resource-cache finalization, staged audio setup,
  BGM priming, Stage 1 pillar background prewarm, stage-intro asset prewarm,
  and Stage 1 runtime asset prewarm. The warmup controller delegates these
  actions here while preserving its public `prewarm_battle_resources()`
  wrapper for existing callers.
- `scripts/core/battle_pso_prewarmer.gd`
  Owns hidden offscreen draw warmup for first-use GPU / Vulkan paths after
  boot texture resources are cached. This includes HUD / playfield
  primitives, skill-icon texture draws, common shader variants, and Stage 1
  round-result player / Dalji pose texture-region uploads so the first
  scoreboard frame does not pay the upload cost. It also owns Hwangyeok plaza
  GPU readiness: an independent 512x512 `SubViewport` performs the actual
  retained seven-building/21-layer draw, then seals 21 current `Texture2D`
  instance IDs, 21 in-bounds layers, and two `frame_post_draw` flushes. Texture
  identity drift invalidates readiness.
- `scripts/core/battle_scene_intro_input_controller.gd`
  Owns battle-scene intro input routing after boot / warmup gates:
  stage-landing skip / advance input, ball-spawn intro input, landing-to-
  ball-spawn handoff callbacks, redraw requests, and viewport handled
  marking. The top-level input controller delegates here before overlay or
  debug input so intro phases keep their exclusive input priority.
- `scripts/core/battle_scene_overlay_input_controller.gd`
  Owns battle-scene overlay and debug input priority after intro phases:
  F3 passive / mythic management toggles and menu input, F4 runtime perk
  picker toggles and menu input, F5 debug stage picker toggles and menu
  input, F6 weather picker toggles and menu input, runtime perk choice input, TAB
  character-info open / modal input,
  F8 runtime perk debug point grants,
  F9 ball-speed debug overlay toggles, and F2 active-item debug spawn
  input. Debug screens are routed through one central switcher so pressing
  another debug key closes the current debug surface and opens the target
  immediately; future debug screens should join that switcher instead of
  adding a standalone toggle. The top-level input controller
  delegates here once window, mobile-touch, and intro routing are settled.
- `scripts/core/stage_debug_picker.gd`
  Owns the F5 debug stage picker overlay for stages 1-10,
  4천왕(11), and 진엔딩(12). It applies `current_stage` immediately,
  syncs `GameSelectionState`, resets the lightweight battle runtime, and
  lets not-yet-ported stages continue through the current stage-router
  fallback.
- `scripts/core/weather_debug_picker.gd`
  Owns the F6 debug weather picker overlay: modal open / close state,
  Korean weather-card layout, hover / click / keyboard selection, the
  clear-weather option, and selection handoff to
  `battle_scene_weather_update_driver.debug_force_weather_event()`.
- `scripts/core/battle_scene_intro_frame_controller.gd`
  Owns idle and draw-frame handling for boot / intro phases: penguin-logo
  update and prewarm draw, boot warmup stepping, battle initialization
  handoff, stage-landing intro update / draw, ball-spawn intro update, and
  ball-spawn overlay draw. The main frame controller delegates these phases
  here before running modal, scoreboard, or normal battle-frame work.
- `scripts/core/battle_loading_screen_renderer.gd`
  Owns the visible battle-entry loading screen between character selection
  and the first stage frame, plus the same presentation when a stage-clear
  result advances into the next demo stage. It draws warmup progress,
  stage / character context, and shared loading-wave art while boot,
  battle initialization, stage-intro readiness gates, or match-transition
  loading gates are still blocking normal battle drawing.
  Stages 1 and 2 use the stained-glass path: one full-color imagegen PNG
  plus one grayscale reveal-mask PNG per stage, composed through
  `battle_loading_stained_glass_host.gd` so loading progress can reveal
  color while preserving dark lead lines.
- `scripts/core/battle_loading_stained_glass_host.gd`
  Owns the node-backed stained-glass loading view: fullscreen
  layout, shader uniforms for mask-threshold reveal / completion flash,
  Korean loading text, and progress-bar placement. The renderer owns stage
  selection, asset loading, and completion-hold timing.
- `scripts/core/battle_scene_overlay_frame_controller.gd`
  Owns idle update and final draw ordering for battle-scene overlays after
  the base battle draw: runtime perk choice / feedback updates, F4 runtime
  perk picker update / draw, F5 debug stage picker draw, F6 weather picker
  draw, F3 passive / mythic management draw, TAB character-info update / draw, active-item
  debug spawn menu draw, and
  non-modal F9 ball-speed debug overlay redraw / draw.
  The main frame controller delegates overlay work here after intro phases
  and before ending the draw frame.
- `scripts/core/battle_scene_config.gd`
  Owns the scene-size and startup configuration constants for the Godot
  battle scene. Lifecycle and drawer modules read this config through the
  registry so the scene shell no longer carries gameplay-surface constants.
- `scripts/core/battle_scene_owner_reader.gd`
  Owns shared scene-owner value reads for core context builders and scene
  snapshot appliers: null-safe property lookup plus typed Vector2,
  Dictionary, and Array fallback helpers. Core modules should delegate to
  this reader instead of duplicating owner property access logic; Ringpet
  runtime code should call it directly rather than keeping local owner-value
  pass-through wrappers.
- `scripts/core/battle_context_reader.gd`
  Owns shared dictionary value reads for core draw/context modules:
  Dictionary fallback coercion and typed Vector2 lookup from context
  snapshots. Core draw modules should reuse this helper instead of
  duplicating local `_get_dict` / `_get_vector2` bodies.
- `scripts/core/battle_scene_api.gd`
  Owns compatibility-facing scene API calls that external tests or tools
  may invoke on `main.gd`, such as ball physics context, ball visual state,
  Drive-ball activation, runtime perk debug point grants, character
  configuration, and mythic-item debug/equip helpers. The scene shell keeps
  the public wrapper names and delegates the behavior here.
- `scripts/core/battle_scene_state.gd`
  Owns mutable scene field defaults for the Godot battle shell. The scene shell
  uses a small `_get` / `_set` property bridge so modules can continue to
  read and write scene properties without keeping dozens of direct state
  variable declarations in the scene script. Player paddle width / height /
  scale live here so timed item effects can resize the player actor without
  reintroducing constants into the scene shell.
- `scripts/core/battle_frame_flow_controller.gd`
  Owns per-physics-frame battle flow branching: scoreboard-lock updates,
  Power Smashing freeze updates, player / active-item / boss updates,
  serve-wait advancement, active-ball updates, effect updates, and redraw
  requests. The scene update driver supplies callbacks for the actual
  scene-level operations.
- `scripts/core/battle_frame_flow_deps_builder.gd`
  Owns the per-frame dependency map passed into
  `battle_frame_flow_controller.gd`: scoreboard state, Smasher-only Power
  Smash state, round/serve flow state, serve context, and skill-orb
  tooltip hover flags. Keeping this assembly separate keeps
  `battle_scene_update_driver.gd` focused on binding callbacks and calling
  the flow controller.
- `scripts/core/battle_scene_drawer.gd`
  Owns the scene draw-frame orchestration: viewport background, pillar
  draw pass delegation, transformed playfield draw pass setup, and
  delegation into the focused playfield drawer.
- `scripts/core/battle_scene_pillar_draw_pass.gd`
  Owns the outer pillar scene draw pass bridge: pillar draw-context
  assembly, top mini-score sparkle timing handoff, and delegation into
  the Stage 1 pillar scene drawer.
- `scripts/core/battle_playfield_scene_drawer.gd`
  Owns the transformed playfield draw pass facade: actor / ball / effect /
  combo / banner ordering and delegation to focused playfield draw helpers.
  The scene drawer keeps viewport and pillar composition.
- `scripts/core/battle_playfield_ball_drawer.gd`
  Owns playfield ball draw dispatch inside the transformed playfield pass:
  active ball effect draw context handoff, current ball draw snapshot
  lookup, renderer dispatch, and draw-position fallback helpers.
- `scripts/core/battle_playfield_effects_drawer.gd`
  Owns playfield actor / effect draw helpers inside the transformed pass:
  actor draw handoff, Power Smashing effect handoff, impact / combo effect
  drawing, shared `dash_acceleration` silk-ribbon dash trail / aura
  drawing from the live dash snapshot, and related focused effect renderer
  delegation.
- `scripts/core/battle_perf_logger.gd`
  Owns opt-in live battle performance sampling for draw-pass investigation:
  `PINGFIGHTER_BATTLE_PERF_LOG` / `battle_perf_log.flag` enablement,
  microsecond sub-draw aggregation, spike / gap / physics monitor routing,
  process-node reporter routing, enabled-state reads for instrumented draw
  helpers, and Godot `Performance` monitor output used to compare actor-body
  rendering, effect layers, weather, items, and HUD overlays before changing
  runtime behavior.
- `scripts/core/battle_perf_process_node_reporter.gd`
  Owns BattlePerf process / physics node scans for leak and rogue-process
  diagnosis: owner-vs-root scan scope, script callback detection,
  active/inactive callback counts, stale loading-host suppression, outside
  shell labels, and summary formatting. Keep this reporter pure; the main
  logger owns scene-owner storage and log emission.
- `scripts/core/battle_perf_spike_window_reporter.gd`
  Owns focused BattlePerf spike-window summary formatting: draw-shell /
  draw-frame / playfield / active-item / mythic-field / Stage 2 actor
  focus-label thresholds, trigger lists, max-hot sorting, focus sorting, and
  counter-summary attachment.
  Keep this reporter pure; the main logger owns collection and interval
  gating.
- `scripts/core/battle_playfield_overlay_drawer.gd`
  Owns playfield overlay draw helpers inside the transformed pass: skill
  feedback banners, serve-wait indicator dispatch, and scoreboard overlay
  dispatch.
- `scripts/core/battle_scene_update_driver.gd`
  Owns scene update-frame orchestration around the existing flow
  controller: flow dependency lookup, stateless callback-table creation,
  and lifecycle reset-ball entry point. Startup update-module warming is
  delegated to `battle_scene_update_prewarm_driver.gd`.
- `scripts/core/battle_scene_update_prewarm_driver.gd`
  Owns update-runtime startup warming: lazy-loading frame-flow modules,
  staged dependency execution/detail labels, priming update context builders,
  staged asset readiness, BattlePerf lookup sampling, and forwarding ball-
  update prewarm to the ball update driver so first serve does not pay the
  lazy-load cost. Character/stage dependency composition is delegated to
  `battle_scene_update_prewarm_plan.gd`.
- `scripts/core/battle_scene_update_prewarm_plan.gd`
  Owns pure update-prewarm planning: normalized character/stage cache keys,
  character-specific player/effects/match dependency composition, current-
  stage/all-stage selection, and stable nonempty deduplication. It has no
  registry or staged-execution state.
- `scripts/core/battle_scene_update_prewarm_key_sets.gd`
  Owns the ordered static dependency groups consumed by the update-prewarm
  plan. Keep runtime selection policy in the plan and step execution in the
  driver instead of adding behavior to this data-only catalog.
- `scripts/core/battle_scene_update_callbacks.gd`
  Owns the stateless scene update callback table for player / active items
  / boss / ball / effects-driver, score events, scoreboard updates,
  serve/reset requests, and delegation to registry-owned actor, item,
  ball, effects, skill-tooltip, runtime-perk, and match-event scene
  drivers. Callback context is carried through `Callable.bind()` rather
  than mutable bind/clear state.
- `scripts/core/battle_scene_match_event_driver.gd`
  Owns scene-facing match event callback fanout for the frame flow: score
  events, round-restart events, scoreboard overlay progression callbacks,
  reset-game fanout, ball reset callbacks, Drive input-frame reset, and
  round-end restoration of pending throwable active items before match
  flow consumes the event. Demo stage-clear advancement also lives here:
  it starts a 2.2-second stage-transition loading gate, waits until the
  loading screen has drawn once, then performs the real stage reset /
  texture reload / audio restart work behind that screen before releasing
  play.
- `scripts/core/battle_scene_effects_update_driver.gd`
  Owns scene-facing effect update callbacks for the frame flow: invoking
  the battle effects update controller and handing returned effect fields
  to `battle_scene_effects_update_result_applier.gd`. It is registered in
  the core module catalog so update callbacks do not instantiate an effects
  driver directly.
- `scripts/core/battle_scene_effects_update_result_applier.gd`
  Owns owner-field application for effect update results returned by
  `battle_effects_update_controller.gd`: Drive text timer state and
  optional special-gauge updates. It also consumes Commando firearm
  boss-damage result fields, decrements configured `boss_current_health`
  when a stage has set one, raises `boss_defeated_by_health` at zero, and
  records damage totals for boss HP / HUD handoff. Registered as
  `battle_scene_effects_update_result_applier`.
- `scripts/core/battle_scene_boss_health_flow.gd`
  Owns the small scene-level bridge from Python-style health-boss stage
  configuration and defeat state to match flow: publishing 15 HP snapshots
  for stages 11 / 16 / 21, clearing HP on normal score stages, consuming a
  pending `boss_defeated_by_health` flag as one player score event, clearing
  the pending flag so effect updates cannot double score during scoreboard
  frames, and restoring configured boss health on ball / round / delayed
  item reset. Registered as `battle_scene_boss_health_flow`.
- `scripts/core/battle_scene_match_flow_driver.gd`
  Owns scene-facing match-flow callbacks for score events, scoreboard
  updates, game/continue reset callbacks, run-ending navigation, match-flow
  dependency lookup, and handoff of reset results to
  `battle_scene_match_reset_result_applier.gd`. Defeat classification and
  chance-gem/settlement policy are delegated to
  `battle_defeat_flow_resolver.gd`. It is
  registered in the core module catalog so scoreboard / score-event
  callbacks use the same lazy-load and warmup path as other update drivers.
  Reset-result application prefers the registry-owned applier and falls
  back to an internal instance for direct unit callers.
- `scripts/core/battle_defeat_flow_resolver.gd`
  Owns scoreboard defeat classification, chance-gem save-store reads and
  owner mirroring, delayed confirmation-time consumption, legacy/missing
  continue-screen fallbacks, and zero-gem settlement selection. It receives
  match-flow-owned continue/exit callbacks so reset execution and scene
  navigation stay in `battle_scene_match_flow_driver.gd`; the driver retains
  one resolver instance for callbacks that outlive the scoreboard tick.
- `scripts/core/battle_scene_match_reset_result_applier.gd`
  Owns owner-field application for match reset results returned by
  `match_flow_controller.gd`: special gauge values, paddle scale/size,
  runtime perk counters, active/passive/mythic item snapshots, equipment
  slots, and accessory-slot bonus. Keep reset-result typing and deep-copy
  behavior here instead of spreading `owner.set()` fanout through match
  orchestration. Registered as `battle_scene_match_reset_result_applier`.
- `scripts/core/battle_scene_actor_update_driver.gd`
  Owns scene-facing actor update callbacks for the frame flow: Smasher
  player-control updates and boss AI updates. Player-control config
  composition and returned actor snapshots are delegated to focused helpers
  below.
- `scripts/core/battle_scene_actor_update_result_applier.gd`
  Owns owner-field application for actor update results returned by player
  controllers and boss AI: player / boss positions, velocities, frame
  counters, special gauge, ball handoff fields, collision cooldown, and
  runtime perk gold awards. Registered as
  `battle_scene_actor_update_result_applier`.
- `scripts/core/battle_scene_player_control_config_builder.gd`
  Owns scene-owner player-control config composition before the character
  controller runs: live paddle size / floor handoff, special gauge and ball
  snapshots, boss position, field dimensions, and multiplicative movement
  speed modifiers from runtime perks, Smasher recovery, weather events,
  active items, and mythic items. Registered as
  `battle_scene_player_control_config_builder`.
- `scripts/core/battle_scene_item_update_driver.gd`
  Owns scene-facing item update callbacks for the frame flow: active-item
  runtime updates, mythic-item runtime updates, and round-end restoration
  of pending throwable active items that were consumed at key press before
  their projectile/deploy branch completed.
- `scripts/core/battle_scene_weather_update_driver.gd`
  Owns scene-facing weather-event callbacks for the frame flow: ticking the
  common weather state, performing round-start weather rolls after ball
  reset, drawing the current weather layer, routing F6 weather debug
  force-start selections from the picker, and notifying Baal's Boots when
  a weather event is active at round start or selected through the debug
  picker.
- `scripts/core/battle_scene_skill_tooltip_driver.gd`
  Owns scene-facing skill-tooltip callbacks for the frame flow: pausing /
  resuming the active character skill cooldown state while a skill-orb or
  Commando current-firearm tooltip is held open, and routing final
  screen-space tooltip overlay show/hide requests to the HUD overlay host.
- `scripts/core/battle_scene_runtime_perk_update_driver.gd`
  Owns scene-facing runtime-perk frame callbacks for the frame flow:
  delegating perk-choice resume-safety ticking to `runtime_perk_state` and
  ticking the player-centered 월계수잎 shield state before ball physics.
  The character modules still own the actual resume-freeze / recovery and
  leaf-shield state; this core driver only keeps the frame callback fanout
  out of `battle_scene_update_callbacks.gd`.
- `scripts/core/battle_scene_scoreboard_update_driver.gd`
  Owns scene-facing scoreboard idle updates: scoreboard overlay progress
  callbacks while physics gameplay is paused, top mini-scoreboard sparkle
  ticking, and deuce-mode redraw requests. The main update driver keeps
  the public entry points used by the frame controller and delegates the
  scoreboard-specific work here.
- `scripts/core/battle_scene_ball_update_driver.gd`
  Owns scene-facing ball callbacks for the frame flow: ball reset,
  serve-ball fanout, active-ball updates, Drive-state callback bridging,
  score-event forwarding, and returned ball snapshot application
  delegation. Callback owner / registry context is carried through
  `Callable.bind()` instead of temporary driver-owned frame state.
- `scripts/core/battle_scene_ball_snapshot_applier.gd`
  Owns applying returned ball/reset snapshots to the scene owner, including
  reset-specific player / boss position and speed fallback handling.
- `scripts/core/battle_view_layout.gd`
  Owns battle window / viewport geometry: common 1080p-style window
  target scaling, game-surface render scale, centered game offset, and
  scaled game-size calculation. On mobile targets it skips desktop window
  resizing, maps Godot's display safe area into the viewport, and removes
  the desktop vertical render margin so the battle view fills the phone
  screen instead of preserving letterbox bands.
  It also owns the desktop window target used by the boot logo,
  character-select scene, and battle scene so top-level transitions do not
  visibly jump between different OS-window sizes. The battle shell uses the
  same module for the F11 windowed/fullscreen toggle and restores the last
  windowed size / position when leaving fullscreen. `battle_scene_drawer.gd`
  and draw-context builders use this layout snapshot for draw-order
  orchestration instead of carrying viewport math inline.
- `scripts/core/mobile_touch_controls.gd`
    Owns the first mobile-readiness input layer for the battle scene:
    a connected left / right movement pad, separate up / down / accept
    touchscreen hit regions, side-letterbox-preferred mobile placement that
    keeps controls out of the central playfield, uses the lower pillar orb
    zones when the mobile pillar HUD has been lifted, enlarged touch hit
    radii for thumb-friendly mobile input, synthetic Godot `ui_*` action
    press / release fanout, and a lightweight
  translucent virtual-control overlay that only appears on mobile targets
  or while a real touch is active. Its button layout uses the same display
  safe-area discipline as the battle view layout. The battle shell enables
  it only during active gameplay so modal perk choices, character info,
  debug item menus, logo intro, and stage landing intro keep their own input
  semantics.
- `scripts/core/battle_draw_context.gd`
  Owns the public draw-time context builder API used by the scene drawer.
  It preserves the existing snapshot method names and delegates Stage 1
  pillar / scene, actor, ball, and banner dictionaries to focused context
  builders.
- `scripts/core/battle_draw_scene_context.gd`
  Owns the draw-time scene-context facade: playfield snapshot delegation,
  pillar-scene snapshot delegation, and shared draw dependencies.
- `scripts/core/battle_draw_playfield_scene_context.gd`
  Owns draw-time playfield scene snapshots: dash snapshots, actor / ball
  base positions, ball visual flags, dynamic player-paddle size / scale,
  boss paddle constants, and banner timing constants.
- `scripts/core/battle_draw_pillar_context.gd`
  Owns draw-time Stage 1 pillar scene snapshots: viewport/game layout,
  owner battle texture / skill icon maps, active-item slots, gauge values,
  and pillar renderer state dependencies.
- `scripts/core/battle_draw_actor_context.gd`
  Owns Stage 1 actor draw snapshots: animation-state draw data, dash
  status, player / boss positions, paddle sizes / scale, and player / boss
  sprite texture references. Result scoreboard-to-actor draw state,
  result-frame constants, and cached result texture sync are delegated to
  `scripts/core/battle_draw_actor_result_context.gd`; player customization
  texture/slot projection delegates to
  `scripts/core/battle_draw_actor_customization_context.gd`; Commando B2,
  weapon-fire, radio, anchor, and legacy overlay projection delegates to
  `scripts/core/battle_draw_actor_commando_context.gd`; Stage 1-8 source
  capture and merge precedence delegates to
  `scripts/core/battle_draw_actor_stage_context.gd`.
- `scripts/core/battle_draw_actor_customization_context.gd`
  Owns draw-time player customization projection into the two established
  dictionaries: deep-copied caller textures/slots, Texture2D-only battle-cache
  additions, user-entry priority, Optimus default slot recipes, owned runtime
  perk visual-part injection, and the Smasher debug paddle fallback. It does
  not own actor animation/context assembly, resource loading, or rendering and
  must not add an outer wrapper payload to the draw path.
- `scripts/core/battle_draw_actor_commando_context.gd`
  Owns Commando-specific draw projection: B2 animation/frame selection,
  anchor-table lifetime/lookup/override resolution, authored weapon-fire
  sheet/frame/facing policy, supply/reload/fire-support radio-motion detection,
  radio-frame timing, and the dormant legacy weapon-overlay calibration table.
  The shared actor facade retains final public key assembly; this owner returns
  direct scalar/resource values and adds no per-frame wrapper dictionary.
- `scripts/core/battle_draw_actor_stage_context.gd`
  Owns Stage 1-8 actor-source capture and last-writer merge precedence,
  including Stage 1 Dalji/Gaksital skill/cooldown/wall-flash order, Stage 2
  background-before-skill, Stage 4 map dependencies and flash override, the
  Stage 5 fire-machine availability gate, and direct Stage 3/6/7/8 reads. It
  borrows payload dictionaries, merges into the facade's established result
  before item/status contexts, and releases captured references after merging;
  it returns no wrapper payload and owns no gameplay state.
- `scripts/core/battle_draw_ball_context.gd`
  Owns ball draw snapshots: ball effect trails / particles, current
  intensity colors, serve-wait draw placement, current ball renderer flags,
  ball texture references, and Power Smashing draw flags.
- `scripts/core/battle_draw_banner_context.gd`
  Owns skill-feedback banner draw snapshots for dash, Drive text, and
  Power Smashing text timing.
- `scripts/core/battle_update_context.gd`
  Owns the public non-ball frame-update context facade and delegates
  player / boss, battle-effect, and match-flow dependency snapshots to
  focused context builders. The scene update driver keeps frame-order
  orchestration and applies returned scene values.
- `scripts/core/battle_update_actor_context.gd`
  Owns the public non-ball actor update context facade for selected-
  character player-control config / dependencies and boss-AI owner
  snapshots. Selected-character player control config / deps and boss-AI
  owner snapshots are delegated directly to the focused builders below.
- `scripts/core/battle_update_player_control_deps_builder.gd`
  Owns selected-character Smasher/Viper player-control dependency assembly:
  base movement config, input reader, shared dash state, character skill
  state/config, Smasher-only skill states, Viper runtime / jetpack state,
  movement state, combo state, runtime perk state, orb HUD, active-item
  runtime, round state, audio, and feedback.
- `scripts/core/battle_update_boss_ai_context_builder.gd`
  Owns boss-AI context assembly for frame updates: shared owner snapshots,
  round serve state, Power Smashing reaction state, Stage 1 whip context,
  active / mythic item boss-AI context merge, Smasher plasma merge, Stage 2
  routed boss context, and Viper runtime boss context.
- `scripts/core/battle_update_effects_context.gd`
  Owns the public generic battle-effect update context facade. Frame
  context assembly and battle-effect dependency collection are delegated
  to the focused builders below.
- `scripts/core/battle_update_effects_frame_context_builder.gd`
  Owns battle-effect frame context assembly: owner battle textures,
  selected-character normalization, sprite availability metadata, owner /
  round snapshots, live dash snapshot lookup, and final sprite-over-owner
  context merge.
- `scripts/core/battle_update_dash_snapshot_builder.gd`
  Owns update-context dash snapshot lookup for effect frames. It returns
  the live `smasher_dash_state` snapshot when available and otherwise keeps
  the shared default dash-token / recovery / Boost Charging fields used by
  effect and HUD consumers.
- `scripts/core/battle_update_effects_owner_context_builder.gd`
  Owns effect-update owner and round-state snapshot assembly: current
  stage/mode, field bounds, Drive text timer, ball/gauge state, waiting
  for serve, player position / speed / paddle size, boss position /
  velocity / hitbox size, and the dash snapshot supplied by the dash
  snapshot builder.
- `scripts/core/battle_update_effects_sprite_context_builder.gd`
  Owns effect-update sprite availability and animation metadata:
  Smasher/Viper player sprite and idle presence, Smasher directional /
  legacy attack-sheet timing, Viper walk cadence, Dalji walk cadence, and
  boss attack-sheet presence.
- `scripts/core/battle_update_effects_deps_builder.gd`
  Owns battle-effect dependency map assembly for update frames and
  delegates core, character, and routed stage runtime dependency
  collection to the focused builders below.
- `scripts/core/battle_update_effects_core_deps_builder.gd`
  Owns shared battle-effect dependency collection for update frames:
  feedback / audio / score state, scoreboard state, orb HUD, actor
  animation state, impact effects, player movement state, active-item
  runtime, runtime perk state, and runtime perk catalog.
- `scripts/core/battle_update_effects_character_deps_builder.gd`
  Owns character-facing battle-effect dependency collection for update
  frames: Smasher Power Smash / plasma / recovery / cleanse / warp-gate /
  wheel / Magnum Grip / Dash Spirit / Shield Kiting states, Viper skill
  runtime / jetpack / config / state, Monkey Blessing delivery state, and
  Smasher combo state.
- `scripts/core/battle_update_match_flow_context.gd`
  Owns match-flow dependency map assembly for score, round, scoreboard,
  audio, HUD, active-item runtime, player skill-state / skill-config /
  skill-runtime reset groups, Drive-input, dash state, and stage-runtime
  modules. It keeps the public `build_match_flow_deps()` facade and
  delegates grouped dependency collection to
  `battle_update_match_flow_deps_groups.gd`.
- `scripts/core/battle_update_match_flow_deps_groups.gd`
  Owns grouped match-flow dependency collection: match-state/controller
  deps, item/HUD runtime deps, player-skill runtime deps, and stage-runtime
  deps. Each grouped dependency collection path delegates to a focused
  builder below.
- `scripts/core/battle_update_match_state_deps_builder.gd`
  Owns match-flow match-state and controller dependency collection:
  score state, round flow state, scoreboard state, game audio, score-event
  controller, scoreboard-flow controller, round-restart controller, and
  reset controller.
- `scripts/core/battle_update_match_item_runtime_deps_builder.gd`
  Owns match-flow item / HUD runtime dependency collection used by full
  game reset and related match flows: orb HUD, active-item HUD,
  active-item runtime, mythic-item runtime, and treasure-hunt runtime.
- `scripts/core/battle_update_match_player_skill_deps_builder.gd`
  Owns match-flow player-skill runtime dependency collection used by full
  game reset and related match flows: Smasher/Viper skill-state arrays,
  legacy `skill_state`, Drive input, Smasher skill modules, Monkey Blessing
  delivery state, runtime perk state, Smasher/Viper skill configs, Viper
  skill runtime, and shared dash state.
- `scripts/core/battle_update_stage_runtime_deps_builder.gd`
  Owns shared stage-runtime dependency collection for update and match
  flows, including variant-scoped Stage 1 Dalji, Gaksital, and Pododaejang
  skill/event states, Stage 2 boss skill state, and routed
  `stage_background` lookup with Stage 1 fallback.
- `scripts/core/battle_update_match_stage_runtime_deps_builder.gd`
  Keeps the match-flow stage-runtime dependency facade and delegates to
  the shared stage-runtime dependency builder.
- `scripts/core/smasher_25d_sheet_override.gd`
  Owns the experimental Smasher 2.5D prerender sheet toggle. It reads the
  session-fixed env / flag switch, verifies the full pilot sheet set is
  available, and exposes active sheet paths for `battle_resources.gd` so
  staged prewarm and synchronous loading resolve the same idle / walk /
  attack-left paths without changing gameplay collision state.
- `scripts/resources/battle_resources.gd`
  Owns public battle-texture path aliases, domain-specific texture spec and
  cache-key composition, result texture spec selection, transition step
  composition, pseudo-spec and skill-icon temporary cache cleanup, skill-icon
  normalization, and the public transition/result prewarm compatibility
  facades. The backing cache and concrete resource-loading policy live in
  `battle_texture_spec_store.gd`.
  Smasher ball-contact attacks prefer the 4x2 `player_attack_sheet` when
  present, while legacy hit strips remain the fallback path. The scene
  bootstrap loads this map, while the battle scene state keeps the loaded
  texture dictionary and draw modules resolve texture keys through that
  shared resource map. Boss texture keys must keep attack and stun semantics
  separate; `boss_hit_sprite_sheet` is a legacy ball-contact attack alias,
  not a stun key.
- `scripts/resources/battle_texture_spec_store.gd`
  Owns the backing battle-texture `Dictionary`, texture spec construction,
  alias/path completeness checks, raw/imported/optional loader selection,
  shared cached-texture adoption, and writes to every compatibility alias.
  `battle_resources.gd` retains domain composition and exposes this same
  dictionary reference to existing consumers.
- `scripts/resources/battle_transition_texture_prewarm_controller.gd`
  Owns the active transition key, fine-grained step cursor, one threaded
  texture request/status/completion slot, central export-safe threadability
  gate, synchronous failure fallback, and reset drain. `battle_resources.gd`
  supplies per-call spec/cache/load callbacks and retains domain-specific step
  ordering plus skill-icon normalization.
- `scripts/resources/battle_result_texture_prewarm_controller.gd`
  Owns the round-result texture prewarm job queue, deferred-start frame count,
  duplicate-path suppression, threaded request/status/completion slot, and
  replacement drain. Score-event handling therefore still yields the
  configured frame before starting texture work, while `battle_resources.gd`
  supplies per-call spec/cache callbacks and retains no duplicated worker
  state.
- `scripts/resources/battle_skill_icon_paths.gd`
  Owns the read-only Smasher / Viper / Commando player skill-orb PNG path
  dictionaries. `battle_resources.gd` keeps the public `*_SKILL_ICON_PATHS`
  aliases plus spec/cache-key composition, normalization, and prewarm
  sequencing; the spec store performs concrete loading and owns the cache.
- `scripts/resources/battle_core_texture_paths.gd`
  Owns read-only core battle texture paths for the runtime ball, orb / dash
  frames, player skill-cluster frames, and Stage 1 center background / border.
  `battle_resources.gd` keeps public aliases plus spec/cache-key composition
  and staged prewarm sequencing through the shared spec store.
- `scripts/resources/battle_boss_sprite_paths.gd`
  Owns read-only battle boss sprite sheet paths for Stage 1 Dalji, Stage 2,
  Stage 3 Menhera, and the current Godot Stage 5 Hongryun route.
  `battle_resources.gd` keeps public aliases plus boss spec composition,
  compatibility keys, and staged prewarm sequencing through the spec store.
- `scripts/resources/battle_blacksmith_sprite_paths.gd`
  Owns read-only Blacksmith / Baltor player sprite paths, including Thor
  Shield presentation textures and result sheets. `battle_resources.gd` keeps
  public aliases plus spec/cache-key composition and staged prewarm sequencing;
  the spec store performs concrete I/O.
- `scripts/resources/battle_commando_sprite_paths.gd`
  Owns read-only Commando / Soldier player sprite, firearm action-sheet, and
  weapon overlay paths. `battle_resources.gd` keeps public aliases plus texture
  spec/cache-key composition and staged prewarm sequencing through the store.
- `scripts/resources/battle_optimus_sprite_paths.gd`
  Owns read-only Optimus player sprite and overlay paths. `battle_resources.gd`
  keeps public aliases plus optional-spec/cache-key composition and staged
  prewarm sequencing; the store owns optional loading.
- `scripts/resources/battle_smasher_sprite_paths.gd`
  Owns read-only Smasher player sprite paths, including idle / walk / dash /
  attack / hit / wheel / result sheets and the customization-debug overlay.
  `battle_resources.gd` keeps public aliases plus spec/cache-key composition,
  2.5D override fallback integration, and staged prewarm sequencing through
  the store.
- `scripts/resources/battle_viper_sprite_paths.gd`
  Owns read-only Viper player sprite paths, including idle / walk / attack /
  airborne / wall / Venom Edge / hit / result sheets. `battle_resources.gd`
  keeps public aliases plus spec/cache-key composition and staged prewarm
  sequencing through the store.
- `scripts/resources/battle_skill_cutin_paths.gd`
  Owns read-only skill-presentation texture paths for Smasher / Viper cut-in
  sheets, Drive cut-in pieces, Shield Kiting cut-in art, and the Lingpet
  acquire resonance portal. `battle_resources.gd` keeps public aliases plus
  imported-spec/cache-key composition and staged prewarm sequencing; the spec
  store performs imported loading and owns the cache.
- `scripts/resources/project_resource_loader.gd`
  Owns clean-clone-safe resource loading helpers: raw source PNG and WAV
  files are loaded directly when present, while imported Godot resources
  remain the fallback path. It also owns the shared bounded threaded-texture
  slot, per-waiter timeout clocks, optional no-sync live-presentation fallback,
  and immediate owner detachment plus nonblocking terminal-result collection
  that keeps abandoned or wedged cinematic workers from occupying that shared
  slot. A path that currently owns the threaded slot must close through terminal
  `load_threaded_get()` even if another consumer fills the project cache or Godot
  exposes it through the engine cache first; either cache shortcut is only valid
  for non-owner paths. Texture, HUD, stage, and audio modules should
  reuse this helper instead of duplicating loader branches.
- `scripts/resources/gameplay_module_registry.gd`
  Owns the public lazy-loaded gameplay module lookup API. It delegates the
  stable module key catalog to `gameplay_module_catalog.gd` and delegates
  script / instance caching to `script_instance_cache.gd`, including
  cached-only instance lookup for teardown paths. The scene shell and
  focused modules ask for modules by stable keys instead of keeping path
  constants and one-line getter functions for each renderer / state helper.
- `scripts/resources/gameplay_module_catalog.gd`
  Owns the stable gameplay module catalog facade. It delegates module keys,
  `res://` script paths, and diagnostic labels to focused domain catalogs
  such as `gameplay_core_module_catalog.gd`,
  `gameplay_stage_module_catalog.gd`, `gameplay_hud_module_catalog.gd`,
  `gameplay_ball_module_catalog.gd`,
  `gameplay_actor_module_catalog.gd`,
  `gameplay_item_module_catalog.gd`,
  `gameplay_effect_audio_module_catalog.gd`, and
  `gameplay_resource_module_catalog.gd`. New Godot module owners should be
  added to the matching domain catalog instead of growing the registry
  logic or the facade.
- `scripts/resources/gameplay_item_module_catalog.gd`
  Owns item-domain gameplay module keys. Active-item runtime modules should
  register here so the facade and registry do not grow item-specific path
  knowledge.
- `scripts/resources/script_instance_cache.gd`
  Owns shared lazy script / instance caching for optional RefCounted
  modules, including non-instantiating cached-instance reads for cleanup
  callers. The gameplay module registry uses this cache instead of letting
  the scene shell carry duplicate per-module script-cache boilerplate.
- `scripts/hud/orb_hud_state.gd`
  Owns the gauge-orb and dash-token frame spin state: trigger timing,
  cooldown gates, value/charge change detection, and eased spin-angle
  calculation. Effect update, trigger, and draw-context call sites read
  this state directly; texture loading and draw placement still stay in
  scene / renderer orchestration.
- `scripts/hud/pillar_orb_drawer.gd`
  Owns the public shared pillar / orb draw-helper API used by HUD and
  Stage 1 renderers. It preserves existing helper names and delegates
  geometry, chrome, liquid, and vignette drawing to focused helpers.
- `scripts/hud/pillar_shape_helper.gd`
  Owns shared shape / easing primitives: ellipse point generation, sector
  point generation, soft ellipse shadows, cubic ease-out, and sine
  ease-in-out.
- `scripts/hud/pillar_orb_chrome_drawer.gd`
  Owns reusable orb chrome drawing: generated frame texture sizing /
  rotation, fallback metal orb frame, glass highlights, and centered orb
  text.
- `scripts/hud/pillar_liquid_drawer.gd`
  Owns reusable orb liquid drawing: circular wave fill, highlight bands,
  bubbles, dash-token sector charging liquid, and the stable full-gauge
  circle fill used when a smoothed gauge reaches the near-full threshold.
- `scripts/hud/pillar_stage1_vignette_drawer.gd`
  Owns Stage 1 inner side vignette drawing and the left / right pillar
  vignette pair helper.
- `scripts/hud/pillar_status_orb_renderer.gd`
  Owns the public status-orb draw API for the left gauge orb and right
  dash-token orb. It preserves the Stage 1 pillar UI entry points and
  delegates the visual bodies to focused orb renderers.
- `scripts/hud/pillar_gauge_orb_renderer.gd`
  Owns left gauge-orb drawing: blue outer glows, fallback frame, glass
  interior, gain flash rings, rotating frame texture, centered gauge
  label, near-full display-ratio snapping, and liquid-fill renderer
  delegation.
- `scripts/hud/pillar_gauge_orb_fill_renderer.gd`
  Owns left gauge-orb liquid-fill drawing: fill palette selection, liquid
  surface handoff, and inner fill glow.
- `scripts/hud/pillar_dash_orb_renderer.gd`
  Owns right dash-token orb drawing: red outer glows, fallback frame,
  glass interior, rotating frame texture, Python-parity post-dash recovery
  lock/seal effect, centered token label, the HALF marker, body renderer
  delegation, and delegation to the dash-token fill renderer.
- `scripts/hud/pillar_dash_orb_body_renderer.gd`
  Owns right dash-token orb body drawing: red outer glows, fallback frame,
  interior background, ambient particles, and token-count core glow.
- `scripts/hud/pillar_dash_token_renderer.gd`
  Owns the public right dash-token draw facade and delegates token fills
  and dash flash effects to focused renderers.
- `scripts/hud/pillar_dash_token_fill_renderer.gd`
  Owns right dash-token fill drawing: single / multi-token fills,
  charge liquid, and divider renderer delegation.
- `scripts/hud/pillar_dash_token_divider_renderer.gd`
  Owns right dash-token divider drawing: token-sector divider rays, divider
  tips, divider animation easing, and divider center chrome.
- `scripts/hud/pillar_dash_token_flash_renderer.gd`
  Owns right dash-token flash drawing: flash rings, expanding arc, and
  burst particles.
- `scripts/hud/smasher_skill_orb_renderer.gd`
  Owns the public Smasher skill-orb HUD API plus cluster slot geometry.
  It preserves `draw_underlay()` / `draw_orbs()` for Stage 1 pillar draw
  ordering and delegates the visual bodies to focused renderers.
- `scripts/hud/smasher_skill_orb_underlay_renderer.gd`
  Owns Smasher skill-orb cluster underlay drawing: generated full cluster
  frame placement, fallback socket rails, connector strokes, socket frame
  texture placement, and fallback socket chrome.
- `scripts/hud/smasher_skill_orb_slot_renderer.gd`
  Owns Smasher skill-orb slot orchestration: equipped / empty slot loops,
  skill readiness checks, PNG skill icon blits, and delegation to socket /
  cooldown / fallback-symbol renderers. Skill tables come from
  character-specific skill-config modules, gauge values arrive through
  draw-context snapshots, and draw ordering lives in the pillar HUD scene
  drawers.
- `scripts/hud/smasher_skill_orb_socket_renderer.gd`
  Owns Smasher skill-orb socket chrome: empty / filled socket circles,
  activation flash glow, and ready-ring sweep arcs.
- `scripts/hud/smasher_skill_orb_cooldown_renderer.gd`
  Owns Smasher skill-orb cooldown overlays: dark socket cover, remaining
  cooldown sector fill, fallback sector-point construction, and cooldown
  progress arc.
- `scripts/hud/smasher_skill_orb_symbol_renderer.gd`
  Owns fallback Smasher skill-orb symbols when no PNG icon is available:
  Drive star spokes, Power Smashing burst spokes, and generic orb dots.
- `scripts/hud/stage1_pillar_ui_renderer.gd`
  Owns Stage 1 pillar HUD composition draw ordering: Smasher skill-orb
  underlay/orbs, status-orb renderer calls, Commando fixed current-firearm
  panel handoff, and combo-HUD draw handoff.
  `stage1_pillar_hud_scene_drawer.gd` gathers live gameplay snapshots and
  passes them into this renderer.
- `scripts/hud/stage1_pillar_ui_layout.gd`
  Owns Stage 1 pillar HUD placement and draw-context assembly: gauge /
  dash orb centers, mobile-only pillar HUD lift above the thumb-control
  zones, common orb radius, skill-orb config snapshot shaping, and
  combo-HUD anchor rect.
- `scripts/hud/commando_firearm_selector_renderer.gd`
  Owns the Commando left-pillar firearm selector presentation. It draws one
  fixed panel for the current selected weapon, ammo/status text, owned/rental
  badge, mouse-wheel hint, and weapon-specific ammo icon styles such as Fire
  Support radio-call markers; it must not reintroduce per-weapon stacked
  pillar cards.
- `scripts/hud/commando_firearm_selector_assets.gd`
  Owns the Commando firearm selector HUD asset manifest: frame/icon/recoil
  sheet resource paths, renderer prewarm order, and panel-state asset-path
  defaults. The selector renderer keeps layout, draw ordering, and runtime
  state derivation.
- `scripts/hud/commando_firearm_tooltip_renderer.gd`
  Owns the Commando current-firearm panel tooltip surface: Korean title,
  ammo/status text, base/permanent/rental ownership, reload eligibility,
  final cooldown readout from the skill-config snapshot, and unlock-orb
  alias copy. `smasher_skill_orb_tooltip_renderer.gd` performs the shared
  final-overlay hover handoff so the frame-flow tooltip pause/resume path is
  reused instead of adding a second scene-owned overlay.
- `scripts/hud/stage1_pillar_status_orb_context_builder.gd`
  Owns Stage 1 status-orb draw-context assembly: left gauge-orb values,
  dash-token snapshot shaping including recovery-lock fields, flash timers,
  rotating frame textures, and shared fallback frame width.
- `scripts/hud/scoreboard_state.gd`
  Owns scoreboard overlay timing, scoreboard animation frame state, pending
  game-reset handoff, and top mini-scoreboard sparkle timing. It is the
  single source for overlay draw-time status; the round-end overlay uses the
  Python scoreboard's 15-frame fade-in and 90-frame hold cadence, with
  continuous idle-process frame values for high-refresh LED pulse animation
  while physics-frame gameplay remains paused. Top mini-scoreboard sparkle
  timers are also stepped from idle process so score flashes and deuce
  pulses redraw smoothly on high-refresh displays. Match score rules live
  in `match_score_state.gd`, and score-event sound playback is routed
  through `match_flow_controller.gd` / `game_audio.gd`.
- `scripts/hud/scoreboard_renderer.gd`
  Owns the public scoreboard draw API and delegates visual bodies to
  focused scoreboard helpers. The scene drawer decides when to draw it and
  passes score/state snapshots in.
- `scripts/hud/serve_wait_indicator_renderer.gd`
  Owns the serve-wait playfield indicator port: Player / Boss Serve labels,
  accent lines, manual / auto-serve helper text, boss Preparing / Ready
  status text, and tutorial-stage suppression. The playfield overlay drawer
  invokes this renderer while `round_flow_state` is waiting for serve.
- `scripts/hud/scoreboard_led_digits.gd`
  Owns the public reusable scoreboard LED number API: score-number
  drawing and multi-digit width calculation. It keeps the original
  dot-matrix number silhouette and delegates dot glow drawing to focused
  helpers.
- `scripts/hud/scoreboard_led_digit_patterns.gd`
  Owns reusable scoreboard LED numeric dot patterns for digits 0-9.
- `scripts/hud/scoreboard_led_dot_renderer.gd`
  Owns one-dot scoreboard LED rendering: a reduced lit glow stack, bright
  dot body, dim/off dots, and the round-end scoreboard draw-call budget.
- `scripts/hud/scoreboard_overlay_renderer.gd`
  Owns the full-screen score overlay canvas drawing: Hwangyeokjeon scroll
  layout/unfurl timing, final-player-victory gating, and delegation to the
  frame, header, score-panel, and victory renderers.
- `scripts/hud/scoreboard_overlay_victory_renderer.gd` and
  `scripts/characters/player_character_portrait_catalog.gd`
  Own the stage-clear-only player-column portrait plaque, its delayed
  portrait/feathered-backflash/stamp beats, visible upper hangers, dedicated
  right-side vertical `승리` calligraphy with a small red seal, full-plaque
  flash centering, and player-victory loser-column dimming plus the shared
  character-select/scoreboard portrait source paths and crop anchors.
  `battle_resources.gd` prewarms the selected portrait into `battle_textures`;
  the victory renderer performs no draw-time loads.
- `scripts/hud/scoreboard_overlay_frame_renderer.gd`
  Owns the full-screen score overlay frame chrome: metal frame bands,
  bevel lines, drop shadow, corner bolts, and frame color helpers.
- `scripts/hud/scoreboard_overlay_header_renderer.gd`
  Owns the full-screen score overlay header: header panel chrome, player /
  boss logo orbs, glow halos, the PLAYER label, and the localized Stage 1
  boss name resolved from `stage1_boss_variant`. `stage_boss_variant` remains
  a separate compatibility key and is not used for Stage 1 identity.
- `scripts/hud/scoreboard_overlay_score_panel_renderer.gd`
  Owns the full-screen score overlay score panel: score-area split, LED
  score placement, continuous score glow / pulse timing, and VS plate
  drawing.
- `scripts/hud/scoreboard_top_mini_renderer.gd`
  Owns the top mini-scoreboard canvas entry point, geometry, sparkle
  timing normalization, deuce-mode selection, and delegation to normal /
  deuce mini-scoreboard renderers. `scoreboard_renderer.gd` keeps the
  compatibility entry point and delegates the visual body here.
- `scripts/hud/scoreboard_top_mini_normal_renderer.gd`
  Owns the top mini-scoreboard normal variant orchestration: chrome
  background, normal mini score text, and post-text sparkle delegation.
- `scripts/hud/scoreboard_top_mini_normal_chrome_renderer.gd`
  Owns the top mini-scoreboard normal chrome layer: glow margins,
  gradient panel, border chrome, and delegation to the normal decoration
  renderer.
- `scripts/hud/scoreboard_top_mini_normal_decoration_renderer.gd`
  Owns the top mini-scoreboard normal decoration layer: score diamonds,
  sweep sparkles, and corner starbursts.
- `scripts/hud/scoreboard_top_mini_deuce_renderer.gd`
  Owns the top mini-scoreboard deuce variant text layer: DEUCE label,
  pulsing score text, deuce score jitter / glow, and delegation to the
  deuce effect renderer.
- `scripts/hud/scoreboard_top_mini_deuce_effect_renderer.gd`
  Owns the top mini-scoreboard deuce fire effect layer: glow margins, fire
  gradient panel, flame tongues, and ember renderer delegation.
- `scripts/hud/scoreboard_top_mini_deuce_ember_renderer.gd`
  Owns the top mini-scoreboard deuce ember particles: particle phase,
  drifting position, size / alpha decay, and ember color ramp.
- `scripts/hud/scoreboard_top_mini_text_renderer.gd`
  Owns reusable top mini-scoreboard score text rendering: centered text
  baseline, glow layers, shadow pass, alpha application, and shared
  normal / deuce score text styling support.
- `scripts/hud/active_item_hud_state.gd`
  Owns active-item HUD slot state that is independent from drawing:
  selected slot index, cooldown completion flash timing, active-item
  cooldown ratios, and early-round throw-lock countdown calculation. It is
  the single source for those runtime status values. Draw callers should
  request a status snapshot for drawing, while slot layout, icon loading,
  and draw primitives live in the active-item HUD layout / visuals /
  renderer modules.
- `scripts/hud/active_item_hud_layout.gd`
  Owns active-item HUD geometry for the bottom pillar: main slot tray,
  overflow tray, slot rects, responsive scale, visible-slot clipping, and
  mobile fullscreen side-pillar placement when horizontal outer space is
  available, with bottom-center fallback geometry only when no side band can
  fit the tray. The Stage 1 active-item HUD scene drawer passes the
  generated rects into the active-item HUD renderer.
- `scripts/hud/active_item_hud_visuals.gd`
  Owns active-item HUD icon texture caching/loading and item color
  normalization. The active-item HUD renderer consumes these values;
  scene-level callers should not duplicate item texture/color parsing.
- `scripts/hud/active_item_hud_renderer.gd`
  Owns the public active-item HUD draw API and delegates slot-panel,
  per-slot status overlays, visual bodies, hover highlighting / tooltip
  composition, and slot-context normalization to focused helpers. The Stage 1
  active-item HUD scene drawer owns when to draw it and passes layout/state/
  visual modules into the renderer.
- `scripts/hud/active_item_hud_interaction_controller.gd`
  Owns desktop active-item HUD pointer hit testing and click activation. It
  reuses `active_item_hud_layout` rects and routes occupied-slot clicks through
  `active_item_runtime.use_slot()` so keyboard and mouse use share cooldown,
  input-lock, effect, consumption, and selection semantics. Mobile touch input
  remains owned by `battle_mobile_touch_controller.gd`.
- `scripts/hud/active_item_hud_tooltip_renderer.gd`
  Owns the battle HUD active-item hover card: live-localized item name and
  description, slot/click hint, ready/cooldown/throw-lock state, screen-edge
  clamping, and compact text wrapping.
- `scripts/hud/active_item_hud_slot_context_builder.gd`
  Owns active-item slot draw context normalization: selected index,
  round-start elapsed time, item dictionary lookup, and per-slot cooldown /
  throw-lock status fallback.
- `scripts/hud/active_item_hud_panel_renderer.gd`
  Owns active-item HUD tray panel drawing. Slot-local status visuals stay
  in the slot status renderer so progress frames remain inside the wells.
- `scripts/hud/active_item_hud_slot_renderer.gd`
  Owns active-item HUD per-slot drawing: slot backgrounds, item icons,
  status overlays, selection borders, and inside-slot number badges. It
  delegates icon bodies and status overlay details to focused slot helpers.
- `scripts/hud/active_item_hud_slot_icon_renderer.gd`
  Owns active-item HUD slot icon drawing: PNG-backed item texture draw,
  sheet-first animated mythic item icons such as Megingjord / Ragnarok
  Hammer, slot-fill metadata for mythic icons that should occupy the
  whole box, procedural fallback gem, visual-module icon lookup, and
  item-color fallback.
- `scripts/hud/active_item_hud_slot_status_renderer.gd`
  Owns active-item HUD slot status overlays: cooldown darkening, ready
  flashes, inside-slot cooldown progress frames, throw-lock countdown
  panels, and countdown text centering.
- `scripts/characters/smasher_combo_state.gd`
  Owns the public Smasher combo runtime facade: hit registration, combo
  reset / effect clearing, gauge-gain helpers, renderer-facing accessors,
  and delegation to the combo progress / effect runtime states.
  Skill-specific interactions live in character controllers and paddle-hit
  skill-flow helpers. Ball-hit, update, and playfield draw callers must
  gate this state to `selected_character_type == "smasher"`;
  Viper must not receive Smasher combo count, gauge-bonus, grace, HUD, or
  burst effects.
- `scripts/characters/smasher_combo_progress_state.gd`
  Owns Smasher combo progression state: combo count, legacy dash grace window,
  combo gauge smoothing, effective combo selection, and renderer-facing
  combo timing / threshold constants.
- `scripts/characters/smasher_combo_effect_state.gd`
  Owns Smasher combo effect runtime state: active timer, display
  position, displayed combo count, effect duration, and the particle
  state used by the combo burst renderers.
- `scripts/characters/smasher_combo_rules.gd`
  Owns Smasher combo presentation / reward rules: combo colors,
  high-combo glow colors, gauge bonus percentage, and combo-aware gauge
  gain scaling.
- `scripts/characters/smasher_combo_particle_state.gd`
  Owns Smasher combo effect particle runtime state: particle spawning,
  per-frame motion / damping, life trimming, and max-particle capping.
- `scripts/characters/smasher_combo_renderer.gd`
  Owns Smasher combo draw orchestration and delegates combo particles,
  active burst effects, and HUD gauge drawing to focused renderers.
  `battle_playfield_effects_drawer.gd` decides when to draw it and passes
  the combo state snapshot in.
- `scripts/characters/smasher_combo_particle_renderer.gd`
  Owns Smasher combo particle drawing: glow circles, star particles,
  high-combo cross glints, alpha fade, and shake-offset application.
- `scripts/characters/smasher_combo_burst_renderer.gd`
  Owns active Smasher combo burst drawing: starburst body, shake jitter,
  and delegation to the combo burst accent / text renderers.
- `scripts/characters/smasher_combo_burst_accent_renderer.gd`
  Owns active Smasher combo burst accent drawing: rays, slashes, rings,
  and high-combo rainbow orbit accents.
- `scripts/characters/smasher_combo_burst_text_renderer.gd`
  Owns active Smasher combo burst text drawing: outlined COMBO label
  layers, high-combo white glints, font baseline alignment, and alpha
  fade.
- `scripts/characters/smasher_combo_gauge_renderer.gd`
  Owns the Smasher combo gauge HUD near the left pillar skill cluster:
  anchored bar geometry, milestone ticks, max-combo pulse, grace fade
  behavior, and delegation to the gauge fill / text renderers.
- `scripts/characters/smasher_combo_gauge_fill_renderer.gd`
  Owns Smasher combo gauge fill drawing: filled gradient shade, wave
  highlight, bubbles, and sparkle particles inside the active fill.
- `scripts/characters/smasher_combo_gauge_text_renderer.gd`
  Owns Smasher combo gauge text drawing: outlined combo count,
  COMBO label, and GRACE label placement.
- `scripts/characters/smasher_skill_state.gd`
  Owns Smasher skill runtime HUD state: cooldown dictionaries,
  configured cooldown triggering / ratio calculation, ready-transition
  tracking, and activation flash timing. Skill cost/color tables live in
  `smasher_skill_config.gd`, icon drawing lives in focused HUD renderers,
  and activation side effects live in character skill controllers.
- `scripts/characters/player_character_runtime.gd`
  Owns the current playable-character routing map for the Godot port:
  selected-character normalization, character-specific controller /
  input / skill-config / skill-state / HUD-icon keys, shared dash-state
  lookup, base movement config, and temporary render fallback policy while
  character-specific sprites are still being ported.
- `scripts/characters/viper_skill_config.gd`
  Owns the first Viper active-skill metadata slice in Godot: equipped
  starter orbs, gauge costs, colors, cooldown seconds, Korean tooltip
  copy, motion hints, and effect-preview keys for the Viper skill HUD.
- `scripts/characters/viper_skill_state.gd`
  Owns Viper skill HUD cooldown / ready-transition state by reusing the
  existing generic skill-state behavior under a separate Viper registry
  instance.
- `scripts/characters/viper_input_reader.gd`
  Owns raw Viper gameplay input polling for horizontal movement, up/down
  command keys, dash key state, and action state.
- `scripts/characters/viper_skill_command_tracker.gd`
  Owns Viper skill command-edge bookkeeping before movement: down/up/left/right
  edge snapshots, Dual Glitch A-D-A-D command buffering, Chaos Spear A-W-D
  command buffering, and Core Flip left/right press-frame markers. It mutates
  the existing `viper_skill_runtime.gd` state directly and returns only the
  edge flags needed by activation sequencing; runtime remains authoritative
  for skill activation, costs, cooldowns, hitboxes, audio, and rewards.
- `scripts/characters/viper_skill_activation_runtime.gd`
  Owns Viper's before-movement activation/update routing order: raw input
  snapshot handoff to the command tracker, active Nerve / Dual Glitch startup /
  EMP / Core Flip / Blade / Marshal updates, Core Flip / Dual Glitch / Blade /
  Chaos / Ignition / EMP / Marshal / Air Blade / Shadow Step activation probes,
  and exact early-return sequencing. It deliberately calls the focused
  skill-runtime modules and existing `viper_skill_runtime.gd` wrappers so
  state storage, costs, cooldown side effects, hitboxes, audio, and rewards
  stay with their current owners.
- `scripts/characters/viper_skill_reset_runtime.gd`
  Owns Viper round / full-reset orchestration: input-edge and dash snapshots,
  Shadow Step / Marshal / Phantom transient state, Venom Edge presentation
  flags, focused skill reset delegation, the Ignition Aura cross-round
  preserve exception, and final particle list cleanup. It deliberately mutates
  the existing `viper_skill_runtime.gd` state and calls its reset helpers so
  storage ownership, public wrapper names, audio cleanup, and skill-specific
  reset behavior stay with their current owners.
- `scripts/characters/viper_skill_contact_runtime.gd`
  Owns Viper contact-side runtime glue: player-ball contact arming for Core
  Flip, contact cancellation of startup-only EMP / Dual Glitch / Chaos paths,
  early Chaos blackhole release, Shadow Step paddle-hit collision conversion,
  Phantom Kick knockback consumption, and Kick Enhance guard-knockback
  consumption. It calls the existing `viper_skill_runtime.gd` wrappers for
  resets, immunity checks, fallback impact feedback, and Shadow Step hit
  application so public result fields and side effects remain unchanged.
- `scripts/characters/viper_skill_draw_runtime.gd`
  Owns the top-level Viper draw fanout and performance sample labels:
  detached EMP / Chaos FX-host sync and fallback hiding, Ignition Aura and
  Dual Glitch timer gauges, Blade / Nerve / Core Flip / Marshal / Shadow Step
  renderer calls, Chaos absorb-pulse / fallback drawing, and effect LOD
  handoff. `viper_skill_runtime.gd` remains the mutable draw-state store and
  exposes the thin public `draw()` wrapper.
- `scripts/characters/viper_skill_core_flip_runtime.gd`
  Owns Core Flip's ready-window activation and active per-frame motion phases:
  left/right input buffering inside the armed window, cooldown / gauge /
  dash-cancel side effects, startup spin, wall-climb zigzag, kick hit side
  effects, return, miss text, Dark Blade handoff, Venom Mist mythic hit hook,
  and motion-result construction. `viper_skill_runtime.gd` remains
  authoritative for dash-contact ready-window arming, public wrapper names,
  and draw-state storage.
- `scripts/characters/viper_skill_blade_ball_motion_runtime.gd`
  Owns Air Blade / Dark Blade per-frame projectile ball-motion checks:
  primary blade travel / trail / fadeout, follow-up blade travel / trail /
  fadeout, Stage 2 rock collision probes, and blade-vs-ball hit testing. It
  calls the existing `viper_skill_runtime.gd` blade hit and clear wrappers so
  hit speed, gold, combo-window, follow-up spawning, feedback, and reset side
  effects stay routed through `viper_skill_blade_motion_runtime.gd`.
- `scripts/characters/viper_skill_blade_motion_runtime.gd`
  Owns Air Blade / Dark Blade activation and active motion body: cooldown /
  gauge side effects, phase-2 Air Blade / Dark Blade / Nerve follow-up
  activation decisions, spin-sound startup, horizontal control during spin,
  Dark Blade auto-fire transition, projectile launch state, primary and
  follow-up hit side effects, Dual Glitch replica blade spawning, Stage 2 rock
  collision routing, Blade reset fields, and `blade_amp` cost / follow-up
  scaling. `viper_skill_runtime.gd` remains authoritative for public wrapper
  names, draw-state storage, and shared Blade constants.
- `scripts/characters/viper_skill_blade_window_runtime.gd`
  Owns Air Blade / Dark Blade per-frame follow-up window timers: Core Flip
  Dark Blade handoff countdown, Dark Blade start-window expiry / airborne
  gate checks, and phase-2 Air Blade / Dark Blade combo-window opening.
  `viper_skill_runtime.gd` remains authoritative for public wrapper names,
  draw-state storage, and reset entry points.
- `scripts/characters/viper_skill_chaos_spear_runtime.gd`
  Owns Chaos Spear command activation and per-frame phase advancement:
  startup lock-result reporting, command consumption, activation gates,
  cooldown / gauge side effects, absorb-pulse and cancel-flash clocks,
  context-stop / serve-wait cancellation, startup prep scaling, flying
  interpolation, impact shake / audio transition, blackhole release timing,
  and fade cleanup. `viper_skill_runtime.gd` remains authoritative for
  public wrapper names, blackhole ball-motion math, release-hit result marking,
  and reset entry points.
- `scripts/characters/viper_skill_chaos_spear_ball_motion_runtime.gd`
  Owns Chaos Spear blackhole ball-motion after impact: pending release
  handoff, orbit / ingress position locking, skip-step velocity output,
  gold tick payout, stage-object absorb polling, and absorb-pulse spawning.
  `viper_skill_runtime.gd` remains authoritative for command activation,
  hit-triggered release calls, audio / phase transitions, and reset entry
  points.
- `scripts/characters/viper_skill_dual_glitch_clone_runtime.gd`
  Owns Dual Glitch command activation and clone lifecycle / EMP replication
  timers: A-D-A-D command consumption, activation gate checks, cooldown /
  gauge side effects, clone HP / duration scaling, startup / spawn / active /
  fade clock advancement, context-position sync, clone evaporation timers,
  living / evaporating clone pruning, delayed clone shockwave entries,
  telegraph-window flags, one-shot clone dive particle bursts, and clone
  shockwave entry removal. `viper_skill_runtime.gd` remains authoritative for
  spawning the EMP entries, primary EMP hit behavior, clone EMP ball-hit
  refresh, public wrapper names, and draw-state storage.
- `scripts/characters/viper_skill_emp_strike_ball_motion_runtime.gd`
  Owns EMP Strike per-frame ball-hit checks after shockwave activation:
  primary dive shockwave vertical-window testing, Dual Glitch clone shockwave
  hit testing, ball-boost result construction, clone-hit marking, and direct
  calls back to the runtime for slip, Chaos release, feedback, hit-pulse, and
  gold side effects. `viper_skill_runtime.gd` remains the public call surface
  for ball-motion result fields.
- `scripts/characters/viper_skill_emp_strike_runtime.gd`
  Owns EMP Strike's non-ball-hit runtime body: S-hold activation gating,
  charge-particle ramp, activation result setup, cooldown / gauge spend side
  effects through the runtime action router, prep / fall / shockwave phase
  advancement, boss-slip duration setup, boss-slip motion application, Dual
  Glitch EMP replica entry spawn, and EMP hold / active reset cleanup.
  `viper_skill_runtime.gd` remains authoritative for public wrapper names,
  draw-state storage, and shared EMP constants.
- `scripts/characters/viper_skill_ignition_aura_runtime.gd`
  Owns Ignition Aura hold activation and per-frame sustain: hold gating,
  charge-particle ramp, configured cooldown / gauge side effects, activation
  feedback, burst spawning, live-ember particle aging, selected-character
  cancellation, live player position / paddle-size sync, runtime-perk bonus
  refresh, serve-wait / inactive-ball duration pause, ember spawning, and
  duration expiry cleanup. `viper_skill_runtime.gd` remains authoritative for
  public wrapper names, round-reset carryover policy, draw-state storage, and
  public snapshots.
- `scripts/characters/viper_skill_marshal_window_runtime.gd`
  Owns per-frame Marshal / Phantom chain-window timers after activation:
  first Marshal ready-window timeout / gauge checks, first-hit Phantom delay,
  Double Marshal ready-window timeout / gauge checks, DMK freeze-frame decay,
  and phantom-show text lifetime. `viper_skill_runtime.gd` remains
  authoritative for opening those windows, public wrapper names, draw-state
  storage, and chain reset entry points.
- `scripts/characters/viper_skill_marshal_kick_runtime.gd`
  Owns the actual Marshal / Phantom wall-dive runtime body: activation setup,
  configured cooldown / gauge side effects, wall jump / cling / reclimb,
  charge / return phases, hit velocity / curve / gold / Dark Blade handoff,
  Phantom follow-up arming, impact-object cleanup, dash-cancel fallback, and
  Marshal reset fields. `viper_skill_runtime.gd` remains authoritative for
  activation gating, public wrapper names, draw-state storage, and shared
  Marshal constants.
- `scripts/characters/viper_skill_nerve_clone_runtime.gd`
  Owns Nerve Strike clone-slash per-frame state advancement for the Four
  Poisons / Dual Glitch replication path: delayed pending entries, target
  tracking during travel, one-shot confusion / slash feedback application,
  slash linger timers, and removal of completed clone entries.
  The real confusion / feedback helpers remain available through the runtime
  wrappers and are implemented by `viper_skill_nerve_strike_runtime.gd`.
- `scripts/characters/viper_skill_nerve_strike_runtime.gd`
  Owns the real Nerve Strike runtime body: activation setup / cooldown and
  gauge side effects, dash tracking, hit / miss branching, Venom Mist boss
  hook, slash trigger, confusion scaling, return motion, clone-slash spawn
  entries for Dual Glitch replication, and Nerve reset fields.
  `viper_skill_runtime.gd` remains authoritative for activation gating,
  public wrapper names, draw-state storage, and shared Nerve constants.
- `scripts/characters/viper_skill_shadow_step_runtime.gd`
  Owns Shadow Step dash-origin activation setup and runtime effects:
  snapback target calculation, cooldown / gauge / dash-cancel side effects,
  activation feedback, shadow-kick ready-window decay, hologram progress /
  destination shock feedback, phantom-strike visual timer, delayed Marshal
  chain-window opening, starburst frame advancement, and Shadow Step hit
  result side effects including ball launch speed / curve, Chaos release
  handoff, feedback, knockback arming, and skill-gold payout.
  `viper_skill_runtime.gd` remains authoritative for public wrapper names,
  draw-state storage, and public reset / snapshot fields.
- `scripts/characters/viper_skill_shadow_step_ball_motion_runtime.gd`
  Owns Shadow Step per-frame ball-motion collision checks after activation:
  wave travel / trail pruning, wave-vs-ball hit testing, hologram-vs-ball hit
  testing, and active shadow-curve velocity bending. It calls the existing
  `viper_skill_runtime.gd` hit wrapper so audio, gold, feedback, Chaos
  release, and knockback sequencing stay routed through
  `viper_skill_shadow_step_runtime.gd`.
- `scripts/characters/viper_skill_transient_effect_runtime.gd`
  Owns Viper's remaining per-frame transient effect ticks that are not
  themselves activation state machines: Nerve Strike miss text / slash VFX
  countdowns, Dive Strike hit text and dive particle aging, Core Flip miss
  text countdown, Venom Edge short strike lifetime, and Marshal / Phantom
  hit-particle aging. `viper_skill_runtime.gd` remains authoritative for
  triggering, spawning, drawing, snapshots, and reset entry points for those
  transient effects.
- `scripts/characters/viper_skill_runtime.gd`
  Owns the first Viper active-skill runtimes in Godot: `shadow_step`
  public state storage, snapshot surface, and thin reset / before-movement
  activation / contact / draw wrappers delegated to
  `viper_skill_reset_runtime.gd`, `viper_skill_activation_runtime.gd`,
  `viper_skill_contact_runtime.gd`, and `viper_skill_draw_runtime.gd`.
  Shadow Step activation
  setup, visual / chain-window timers, and hit side effects are delegated to
  `viper_skill_shadow_step_runtime.gd`.
  Shadow Step wave / hologram / curve ball-motion checks are delegated to
  `viper_skill_shadow_step_ball_motion_runtime.gd`. Simple Nerve / Dive /
  Core Flip / Venom Edge / Marshal transient-effect ticks are delegated to
  `viper_skill_transient_effect_runtime.gd`. Core Flip ready-window
  activation and active motion are delegated to
  `viper_skill_core_flip_runtime.gd`; real Nerve Strike active motion and
  hit / return lifecycle are delegated to
  `viper_skill_nerve_strike_runtime.gd`. Actual `marshal_kick` /
  `phantom_kick` wall-dive activation, phase motion, hit side effects, and
  reset fields are delegated to `viper_skill_marshal_kick_runtime.gd`;
  per-frame Marshal / Phantom chain-window decay is delegated to
  `viper_skill_marshal_window_runtime.gd`. Air Blade / Dark Blade activation,
  phase-2 Air Blade / Dark Blade / Nerve follow-up activation decisions, spin /
  launch / jump-rest phase progress, hit side effects, follow-up spawning,
  Stage 2 rock collision routing, and Blade reset fields are delegated to
  `viper_skill_blade_motion_runtime.gd`. Blade projectile
  ball-motion checks are delegated to `viper_skill_blade_ball_motion_runtime.gd`,
  while per-frame Blade follow-up window timers are delegated to
  `viper_skill_blade_window_runtime.gd`. Air Blade and Dark Blade currently
  use the direct canvas fan-polygon projectile VFX; this remains the preferred
  runtime version after the image-piece experiment was rolled back. Blade
  projectile ball hits also own
  difficulty-independent effective-speed caps: Air Blade 40 and Dark Blade
  50 until the boss paddle returns the ball.
  EMP Strike activation gating and public wrapper methods remain on the
  runtime, while S-hold activation setup, prep / fall / shockwave phase
  advancement, slip setup / motion, and reset cleanup are delegated to
  `viper_skill_emp_strike_runtime.gd`. EMP Strike ball-hit checks are
  delegated to `viper_skill_emp_strike_ball_motion_runtime.gd`. Dual Glitch
  command activation and clone lifecycle are delegated to
  `viper_skill_dual_glitch_clone_runtime.gd`; the runtime still owns the
  shared right-bottom timer-gauge claims, the
  sheet-first Ignition Aura field with procedural fallback accents,
  audio / feedback cues, clone-slash entry spawning, and runtime-perk bonus
  handoff. Ignition Aura hold activation and active sustain clocks are delegated to
  `viper_skill_ignition_aura_runtime.gd`. Its Chaos Spear command activation
  and per-frame `startup` / `flying` / `impact` / `blackhole` / `fade` phase
  clock are delegated to `viper_skill_chaos_spear_runtime.gd`; blackhole
  ball-motion and absorb payout ticks are delegated to
  `viper_skill_chaos_spear_ball_motion_runtime.gd`, while the draw bridge
  hands that state to the node-backed Chaos Spear FX host. The host keeps the
  older direct canvas spear / impact / blackhole draw path as a fallback
  while it is not inside the scene tree or its PNG slots are unavailable.
- `scripts/characters/viper_skill_visibility_query.gd`
  Owns Viper skill runtime visibility and read-only derived state queries:
  visible-effect gates, ball-motion/update gates, timer ratios, Venom Edge
  and Nerve Strike frame reads, Dual Glitch remaining-frame / clone queries,
  skill-config / skill-state / dash-state reads, and Stage 2 speed-defense
  immunity checks. `viper_skill_runtime.gd`, `viper_skill_context_builder.gd`,
  `viper_skill_snapshot_builder.gd`, and
  `viper_skill_timer_gauge_renderer.gd` should call this owner directly
  instead of reintroducing private runtime read bridges.
- `scripts/characters/viper_skill_scaling.gd`
  Owns reusable Viper scalar / balance helpers: Four Poisons percentage and
  additive cooldown math, Dual Glitch clone HP scaling, Blade skill cost
  scaling and Blade Amp follow-up chance scaling, Marshal Kick
  prep-duration / hit-speed scaling, and Core Flip duration / hit-speed scaling.
- `scripts/characters/viper_skill_geometry.gd`
  Owns shared Viper skill geometry helpers: player / ball / boss center
  extraction, player-position clamping / locked startup X positioning, blade start-position combo pop, blade prep fall motion, blade projectile launch / hit-velocity motion, speed / homing scalars, blade rest-position arc, blade horizontal control motion, blade / ball hit rects, segment-rect
  intersection, blade projectile trail append/limit, homing gate, target-reach fadeout decision / fadeout timer / ball-hit gate,
  Dark Blade auto-fire window / proximity decision,
  EMP Strike hit velocity, shockwave position / radius /
  boss-reach / ring-touch tests plus boss slip start / motion calculation,
  Shadow Step wave motion / curve velocity / hit profile / hologram progress / hitbox rects,
  Marshal Kick launch angle tuning, initial / reclimb wall targets and reclimb decision,
  phase progress, jump / reclimb / charge / return motion, charge hit test,
  return target, and wall kick direction,
  Viper kick knockback velocity calculation,
  Nerve Strike dash / hit test / miss-text placement / slash progress / slash trigger gate /
  return / clone slash motion, Core Flip start / wall-climb /
  wall-contact / kick-direction / kick / kick-hit / return motion, miss-text
  placement, phase gate / progress, spin timing, and bank velocity, and the common aimed kick launch angle / velocity used by Shadow
  Step and Marshal Kick. `viper_skill_runtime.gd` keeps skill-state ownership and
  delegates reusable geometry / launch math here.
- `scripts/characters/viper_skill_context_builder.gd`
  Owns renderer / ball-collision / boss-AI context dictionaries for Viper
  skill runtime. It reads derived visibility fields through
  `viper_skill_visibility_query.gd` while leaving mutable skill state and
  gameplay timing on `viper_skill_runtime.gd`.
- `scripts/characters/viper_skill_snapshot_builder.gd`
  Owns the Viper skill debug / save-style snapshot payload shape and reads
  Dual Glitch derived remaining-frame state through
  `viper_skill_visibility_query.gd`.
- `scripts/characters/viper_skill_timer_gauge_renderer.gd`
  Owns Viper's right-bottom runtime timer gauges for Ignition Aura and Dual
  Glitch, including stack claiming, frame/fill drawing, warning coloring, and
  derived ratio / remaining-frame reads through `viper_skill_visibility_query.gd`.
- `scripts/characters/viper_chaos_spear_fx_host.gd`
  Owns the node-backed Viper Chaos Spear visual remaster. It composes the
  five image-generated chaos-spear texture pieces (`glyph`, spear
  silhouette, trail, impact burst, and cracks) with the existing shader
  blackhole disk, charge particles, four blackhole particle layers, and
  phase-specific alpha / scale / rotation timing. The cracks layer uses the
  shared `WritheEmberMaterial` `chaos_cracks` / `chaos_cracks_enraged`
  presets for UV displacement, `lateral_strength` tangent writhing, heat
  chroma, flicker, outward energy flow, and tweened phase intensity.
  `viper_skill_command_tracker.gd` owns command input buffering, while
  `viper_skill_runtime.gd` remains authoritative for gameplay timing,
  hitboxes, audio, ball capture / release, and gold rewards.
- `scripts/characters/viper_emp_strike_fx_host.gd`
  Owns the node-backed EMP Strike visual remaster. `viper_skill_runtime.gd`
  remains authoritative for timing, hitboxes, audio, gold, and boss slip,
  while this host renders the visible charge / dive / shockwave / hit
  feedback through texture pieces, ShaderMaterial quads, GPUParticles2D,
  and Tween-driven pulse / flash timing. The older direct canvas EMP draw
  path is kept only as a fallback while the host is not yet inside the
  scene tree.
  Viper's other
  active skills remain separate character-module slices.
- `scripts/characters/viper_player_controller.gd`
  Owns the first Viper player-control port. It currently reuses the
  shared Smasher movement / dash orchestration with Viper's Python-parity
  lower ground movement speed and calls the Viper skill runtime before /
  after shared movement so dash-linked and wall-dive skills can consume
  input cleanly. Jetpack and the remaining Viper active skills remain
  separate future slices.
- `scripts/characters/commando_skill_config.gd`
  Owns the first Commando active-skill metadata slice in Godot: fixed
  `supply_drop` / `emergency_supply` orbs, permanent firearm slot capacity,
  equipped permanent firearm ordering, full-slot swap candidates / mutation,
  gauge costs, colors, cooldown seconds, Python-matching skill-use gold
  rewards, Korean HUD copy, and skill icon metadata for the shared orb
  renderer. The skill-use gold policy is base-cooldown driven: `supply_drop`
  awards 96 through the common result path, while `emergency_supply`,
  permanent firearms, and `commando_pistol` award 0. It also owns the
  Commando skill-config save-snapshot surface for shared-slot equipped
  order, cooldown multipliers, and item-provided slot bonus, dropping
  unknown / duplicate / over-capacity restored skill ids.
- `scripts/characters/commando_skill_state.gd`
  Owns Commando skill HUD cooldown / ready-transition state by reusing the
  generic skill-state behavior under a separate Commando registry instance.
  It also exposes the Commando save-snapshot surface for cooldowns,
  active-transition timestamps, and tooltip-pause timing.
- `scripts/characters/commando_weapon_controller.gd`
  Owns Commando weapon state: base pistol, permanent-owned firearms,
  equipped permanent firearm order, stage-rental firearms, current weapon
  selection, ammo reads/mutation, `commando_pistol` Beretta display profile
  with 4-round magazine / 2-spare-magazine total-12-shot / 120-frame reload
  state, bazooka 4-round permanent
  ammo state, net gun 3-round permanent ammo state, fire-support 2-radio-call
  ammo state, AK-47 90-round ammo and
  1800-frame durability display / refill state, rental release on
  depletion, stage-rental cleanup, stage-start permanent-firearm refill,
  explicit round-reset preservation, save-snapshot export / restore for
  owned / equipped / rental / selected / prepared-stage weapon state, and
  the single derived weapon list consumed by the fixed HUD selector.
- `scripts/characters/commando_weapon_anchor_table.gd`
  Owns the B2 Commando held-weapon visual contract: per-animation /
  per-frame grip anchors in 160x160 source-cell space, per-weapon pivot /
  draw-size metadata for weapon-only PNGs, and safe fallbacks while future
  attack / walk-back sheets are authored. The current B2v2 perspective pass
  uses weapon PNGs whose muzzle / front end points toward the top of the
  image (boss direction) and whose bottom-center alpha bbox is the grip
  pivot. QA compositing showed the proposed upper-torso y=80 anchor lands
  on the head / neck line for the current base sheets, so the first v2
  calibration starts `idle_back` at `Vector2(80, 119)` and side-walk states
  at `Vector2(80, 116)` with `rot = 0`, while
  `walk_back` remains empty until a runtime path needs it. Weapon pivots
  are populated for pistol, AK-47, bazooka, net gun, bowling trap, and
  suicide drone from
  `assets/sprites/characters/commando/weapons_b2_perspective/`; the old
  `weapons_b2/` side-profile pass remains on disk as a rollback/reference.
  `battle_resources.gd` now loads Gemini MCP base-grip idle / side-walk
  sheets as the active Commando idle / walk textures, keeping the old
  pistol-baked sheets under `commando_player_legacy_*` cache keys. The B2
  idle / walk weapon-only overlay renderer in
  `stage1_player_actor_renderer.gd` is gated off because separate weapon
  sprites still do not match the hand / arm / body perspective reliably.
  The active visual policy is: idle / walk stays empty-handed, and firearms
  appear only in weapon-specific firing / placement / control sheets where
  the weapon, hands, arms, and body pose are authored together. The first
  runtime pass is wired for AK-47, bazooka, net gun, bowling-trap placement,
  and suicide-drone control sheets; `commando_firearm_runtime.gd` starts a
  mutually exclusive 8-frame weapon-fire sheet state from the corresponding
  fire / place / launch trigger, maps pistol / bazooka / net-gun projectile
  origins to authored fire-sheet muzzle source anchors, and starts instant
  projectile weapons (AK-47, bazooka, net gun) on their F3 fire frame so
  the gameplay projectile does not appear before the firing pose.
  `battle_draw_actor_context.gd` resolves the active sheet and frame, and
  emits horizontal-flip flags so the authored right-facing weapon-fire /
  pistol-fire sheets face left while the player is moving left. The v5
  legacy attack sheet flips by `player_hit_side`, so a ball contact left of
  the paddle center swings left and a contact right of center stays right.
  `stage1_player_sprite_renderer.gd` draws that sheet before pistol-fire,
  attack, hit, idle, or walk fallback branches.
  Pistol-fire and the v5 legacy attack sheet remain separate authored sheets.
  The failed Option A overlay path also remains gated off in
  `stage1_player_actor_renderer.gd`. AutoSprite
  remains useful for Commando cards / illustrations, but the current B2
  runtime sheet pass uses Gemini MCP because AutoSprite animation outputs
  repeatedly drifted the character camera angle.
- `scripts/characters/commando_emergency_supply_state.gd`
  Owns the Godot Commando `emergency_supply` input and activation slice:
  down-key double-tap timing, idle-only tap gating, gauge / cooldown gates,
  selected permanent-firearm refill, and failure paths that leave gauge and
  cooldown untouched. `commando_weapon_controller.gd` remains authoritative
  for owned / rental weapon state and ammo mutation.
- `scripts/characters/commando_supply_drop_state.gd`
  Owns the stateful Commando `supply_drop` runtime orchestration slice: delayed
  payload dispatch, presentation-context assembly, detached-FX visibility
  decisions, radio / aircraft / drop / pickup / explosion audio event timing,
  ball-update aircraft collision handoff,
  player-ball shootdown, player-paddle / Brick-wall aircraft collision,
  crash-impact explosion/audio sequencing and response delegation, and round-boundary
  cleanup orchestration. Its save-snapshot facade composes aircraft lifecycle,
  pending payload queues, collectible parachute drops, and transient effect
  state so a future integrated save file can resume the in-flight supply flow.
- `scripts/characters/commando_supply_drop_activation_policy.gd`
  Owns the pure Supply Drop activation boundary: down/supply-hold command
  aliases, Commando/Soldier identity normalization, original-skill and
  transform blocks including runtime method fallbacks, Emergency Supply
  suppression precedence, player-serve six-second and post-serve three-second
  gates, explicit round bypass, configured gauge cost, and cooldown readiness.
  `commando_supply_drop_state.gd` retains the actual activation commit and
  delegates mutable hold feedback to its focused state owner. Regression guards:
  `tests/commando_supply_drop_activation_policy_refactor_smoke.gd` and
  `tests/commando_supply_drop_activation_gate_smoke.gd`.
- `scripts/characters/commando_supply_drop_hold_feedback_state.gd`
  Owns mutable Supply Drop hold feedback state: live and post-serve-buffered
  hold duration, the Python-parity 0.3-second gauge threshold and one-second
  activation edge, cached paddle anchor and gauge rectangle/progress
  projection, radio-call pose tail timing, one-playback-per-hold audio gate,
  transient cancel/reset, and normalized snapshot restore. The state host
  delegates these transitions while retaining activation commit, save-schema
  composition, and public gauge/audio query facades; concrete method routing
  lives in `commando_supply_drop_audio_state.gd`.
  Regression guards:
  `tests/commando_supply_drop_hold_feedback_state_refactor_smoke.gd`,
  `tests/commando_supply_drop_activation_gate_smoke.gd`,
  `tests/commando_supply_drop_audio_cleanup_smoke.gd`, and
  `tests/commando_save_load_snapshot_smoke.gd`.
- `scripts/characters/commando_supply_drop_audio_state.gd`
  Owns Supply Drop audio dispatch state: edge-triggered aircraft-loop start/
  stop and snapshot projection, eligible restore-time loop restart, preferred
  hold-radio loop with one-shot fallback, forced radio-loop stop, activation
  radio, payload-drop cue, and grenade-explosion with supply-drop fallback.
  It reuses `commando_firearm_audio_dispatcher.gd` for `audio`/`game_audio`
  lookup and first-supported-method dispatch. The state host chooses gameplay
  cue timing and composes the public audio snapshot/query facades. Regression
  guards: `tests/commando_supply_drop_audio_state_refactor_smoke.gd`,
  `tests/commando_supply_drop_audio_cleanup_smoke.gd`,
  `tests/commando_supply_drop_activation_gate_smoke.gd`,
  `tests/commando_save_load_snapshot_smoke.gd`, and
  `tests/gameplay_loop_audio_cleanup_smoke.gd`.
- `scripts/characters/commando_supply_drop_aircraft_lifecycle_state.gd`
  Owns the Supply Drop aircraft state machine without runtime side effects:
  delayed-arrival timer and exact remainder, randomized/configured direction,
  off-canvas start lane, 120 px/s bidirectional flight, collision projection,
  payload drop-window elapsed math, offscreen completion, invulnerability
  readiness, shoot-down transition, quadratic crash position, rotation,
  one-shot impact edge, and deep-copy-compatible snapshot/restore fields. Its
  combined active-flight transaction returns one allocation-conscious result
  and advances motion with only the delta remaining after the arrival edge.
  `commando_supply_drop_state.gd` retains activation, resolved-payload side
  effects, collision eligibility/result application, audio-event timing,
  effect-state spawn dispatch, and crash-response sequencing; concrete shake
  and ball/player knockback side effects live in
  `commando_supply_drop_crash_response.gd`.
  Regression guards:
  `tests/commando_supply_drop_aircraft_lifecycle_state_refactor_smoke.gd`,
  `tests/commando_supply_drop_aircraft_crash_smoke.gd`,
  `tests/commando_supply_drop_obstacle_crash_smoke.gd`,
  `tests/commando_supply_drop_audio_cleanup_smoke.gd`, and
  `tests/commando_save_load_snapshot_smoke.gd`.
- `scripts/characters/commando_supply_drop_runtime_context.gd`
  Owns draw-free per-frame Supply Drop context projection: deep-copying the
  injected collision base, merging active-item collision keys with override
  precedence, safely rejecting invalid providers, deriving payload center
  bounds from play width and collectible safe margins, collapsing inverted
  bounds to center, and clamping aircraft-relative payload positions to the
  shipped vertical range. The host consumes this projection for aircraft
  obstacles, crash-player response, collectible pickup, and resolved-drop
  placement. Regression guards:
  `tests/commando_supply_drop_runtime_context_refactor_smoke.gd`,
  `tests/commando_supply_drop_obstacle_crash_smoke.gd`,
  `tests/commando_supply_drop_field_item_smoke.gd`, and
  `tests/commando_supply_drop_multi_payload_smoke.gd`.
- `scripts/characters/commando_supply_drop_aircraft_collision_resolver.gd`
  Owns draw-free Supply Drop aircraft collision math: explicit/derived player
  paddle hitboxes including centered dash-size expansion, paddle-before-brick obstacle
  precedence, brick index/impact projection, swept segment-vs-grown-aircraft
  tests, aircraft-hit vertical reflection, crash-blast radial falloff/upward
  bias/speed ceiling, and player blast edge/fallback-direction knockback.
  `commando_supply_drop_runtime_context.gd` owns merged context assembly, while
  `commando_supply_drop_state.gd` retains last-hitter eligibility, shoot-down
  state mutation, wall non-consumption,
  audio-event timing, and response sequencing. One-shot impulse application,
  movement-state calls, and feedback dispatch live in
  `commando_supply_drop_crash_response.gd`.
  Regression guards:
  `tests/commando_supply_drop_aircraft_collision_resolver_refactor_smoke.gd`,
  `tests/commando_supply_drop_aircraft_crash_smoke.gd`, and
  `tests/commando_supply_drop_obstacle_crash_smoke.gd`.
- `scripts/characters/commando_supply_drop_crash_impact_state.gd`
  Owns the mutable post-crash impact window: one pending ball-impulse edge and
  center, consume-on-first-ball-frame semantics, grenade-class blast
  timer/center, one successful player-knockback gate, blast-zone presentation
  projection, reset, and the existing three-field save snapshot/restore
  contract. Restore intentionally never recreates the unpersisted ball edge.
  `commando_supply_drop_crash_response.gd` consumes this state for collision-
  resolver calls, scene ball velocity application, movement-state lookup/call,
  and screen shake. The state host retains impact ordering, explosion particles,
  and audio-event timing; method routing lives in the audio state.
  Regression guards:
  `tests/commando_supply_drop_crash_impact_state_refactor_smoke.gd`,
  `tests/commando_supply_drop_aircraft_crash_smoke.gd`,
  `tests/commando_supply_drop_aircraft_collision_resolver_refactor_smoke.gd`,
  `tests/commando_supply_drop_snapshot_codec_smoke.gd`, and
  `tests/commando_save_load_snapshot_smoke.gd`.
- `scripts/characters/commando_supply_drop_crash_response.gd`
  Owns post-crash runtime side-effect application around the pure impact state
  and collision resolver: optional feedback screen shake, consume-on-first-
  attempt ball impulse and `scene.ball_vel` mutation, live player-hitbox
  projection, direct/cached movement-state lookup, direction-aware player
  knockback, and the successful one-shot player gate. A spatial miss leaves the
  gate open so a paddle entering the active blast later is still shoved. The
  state host preserves the shipped order: arm the impact before the instant
  player response and consume the pending ball response before aircraft-hit
  eligibility can early-out. Regression guards:
  `tests/commando_supply_drop_crash_response_refactor_smoke.gd`,
  `tests/commando_supply_drop_aircraft_crash_smoke.gd`,
  `tests/commando_supply_drop_crash_impact_state_refactor_smoke.gd`, and
  `tests/commando_supply_drop_aircraft_collision_resolver_refactor_smoke.gd`.
- `scripts/characters/commando_supply_drop_snapshot_codec.gd`
  Owns the Supply Drop persistence schema boundary: public save-version stamp,
  deep-copied save payloads, legacy spawned-aircraft inference, direction and
  timing-pattern normalization, nonnegative scalar clamps, Vector2 fallbacks,
  typed dictionary/float array filtering, pending-delay padding, and the
  crashing-aircraft audio gate. `commando_supply_drop_state.gd` retains the
  public save/restore facade and runtime field application; focused sub-owners
  restore their fields and the audio state restarts an eligible aircraft loop.
  Regression guards:
  `tests/commando_supply_drop_snapshot_codec_smoke.gd`,
  `tests/commando_save_load_snapshot_smoke.gd`, and
  `tests/commando_supply_drop_audio_cleanup_smoke.gd`.
- `scripts/characters/commando_supply_drop_aircraft_sprite_renderer.gd`
  Owns the Supply Drop aircraft sprite presentation contract: left/right tilt
  and crash sheet paths, one-time texture caches, 4x4 atlas frame projection,
  looping flight frames, final-frame-held crash frames, public pipeline status,
  prewarm, normal-flight region drawing, and normalized-UV rotated crash quads.
  `commando_supply_drop_state.gd` delegates status/prewarm/sprite drawing here
  through `commando_supply_drop_presentation_renderer.gd`; that presentation
  owner retains the procedural missing-asset aircraft fallback plus shared
  glow/ring composition. Regression guards:
  `tests/commando_supply_drop_aircraft_sprite_renderer_smoke.gd`,
  `tests/commando_supply_drop_vfx_remaster_smoke.gd`, and
  `tests/commando_supply_drop_aircraft_crash_smoke.gd`.
- `scripts/characters/commando_supply_drop_collectible_state.gd`
  Owns Supply Drop parachute collectibles end to end: live array, deterministic
  payload-index sway/fall setup, safe-margin motion, rotation, offscreen
  despawn, deep-copy snapshot restore, 40x30 pickup geometry, rental weapon
  grant routing, direct active-item collection / slot-store fallback / field
  spawn fallback, rejected-pickup retention, result payloads, and pickup audio
  ordering. `commando_supply_drop_runtime_context.gd` assembles player collision
  context; the state host projects its paddle rect and retains collectible
  drawing. Regression guards:
  `tests/commando_supply_drop_collectible_state_refactor_smoke.gd`,
  `tests/commando_supply_drop_field_item_smoke.gd`,
  `tests/commando_supply_drop_multi_payload_smoke.gd`, and
  `tests/commando_save_load_snapshot_smoke.gd`.
- `scripts/characters/commando_supply_drop_payload_resolver.gd`
  Owns the pure payload planning slice for Commando `supply_drop`: 1-3
  payload queue construction, Python parity delay schedules, rental weapon
  candidate filtering, Godot-ported field-item candidate weights,
  `ammo_box` / `doping_potion` candidate eligibility rules, duplicate rental
  reservation prevention, configured forced-payload handling, and fallback
  field-item identity. `commando_supply_drop_payload_queue_state.gd` consumes
  these planning functions, while `commando_supply_drop_state.gd` retains one
  field-item candidate compatibility wrapper for the existing smoke surface.
- `scripts/characters/commando_supply_drop_payload_queue_state.gd`
  Owns the mutable payload delivery queue after pure planning: configured
  pending dictionaries and delay array, current-payload compatibility facade,
  aircraft-flight timer start/advance, ordered ready-drop popping, same-frame
  zero-delay chaining, elapsed-time overshoot carry into the next delay,
  aircraft-loss cleanup, deep-copy snapshot projection, and spawned-vs-arrival
  restore timing. `commando_supply_drop_state.gd` retains the drop-window gate
  and applies resolved collectible/VFX/audio dispatch; payload positions are
  projected by `commando_supply_drop_runtime_context.gd`.
  Regression guards:
  `tests/commando_supply_drop_payload_queue_state_refactor_smoke.gd`,
  `tests/commando_supply_drop_multi_payload_smoke.gd`,
  `tests/commando_supply_drop_weighted_table_smoke.gd`,
  `tests/commando_supply_drop_snapshot_codec_smoke.gd`, and
  `tests/commando_save_load_snapshot_smoke.gd`.
- `scripts/characters/commando_supply_drop_effect_state.gd`
  Owns the transient Supply Drop presentation state without CanvasItem calls:
  the 0.55-second falling-drop fade and 84 px/s motion, the 12-spark plus
  7-smoke aircraft-hit recipe, direction-mirrored damage smoke, the 18-spark
  plus 14-smoke plus 10-debris crash recipe, per-effect gravity/damping/lifetime
  updates, reset, and filtered deep-copy snapshot/restore. The state host
  chooses gameplay spawn edges and synchronizes the texture/shader/particle FX
  host, while the presentation renderer draws the projected arrays. Regression guards:
  `tests/commando_supply_drop_effect_state_refactor_smoke.gd`,
  `tests/commando_supply_drop_vfx_remaster_smoke.gd`,
  `tests/commando_supply_drop_aircraft_crash_smoke.gd`,
  `tests/commando_supply_drop_audio_cleanup_smoke.gd`,
  `tests/commando_supply_drop_snapshot_codec_smoke.gd`, and
  `tests/commando_save_load_snapshot_smoke.gd`.
- `scripts/characters/commando_supply_drop_presentation_renderer.gd`
  Owns the complete immediate-mode Supply Drop draw pass: normalized draw-plan
  inputs, hold-gauge fill/text, flare/shockwave texture layers, grenade-class
  crash-zone composition, aircraft sprite delegation plus procedural fallback,
  transient spark/smoke/debris primitives, parachute-crate sprite plus
  procedural fallback, collectible projection, payload texture cache/status,
  and presentation-only prewarm. `commando_supply_drop_state.gd` now supplies
  one borrowed-reference presentation context and retains no direct
  `CanvasItem.draw_*` calls. Regression guards:
  `tests/commando_supply_drop_presentation_renderer_refactor_smoke.gd`,
  `tests/commando_supply_drop_aircraft_sprite_renderer_smoke.gd`,
  `tests/commando_supply_drop_vfx_remaster_smoke.gd`, and
  `tests/commando_supply_drop_aircraft_crash_smoke.gd`.
- `scripts/items/active_item_commando_supply_actions.gd`
  Owns the Commando-specific active-item effects that entered through the
  `supply_drop` table: `ammo_box` refills all non-rental permanent firearms
  through `commando_weapon_controller.gd`, while `doping_potion` requires
  permanent `commando_pistol`, exposes the 480-frame timer context, and feeds
  the pistol cooldown / control-lock / head-leg chance / bullet-speed metadata
  consumed by `commando_firearm_runtime.gd`.
- `scripts/characters/commando_supply_drop_fx_host.gd`
  Owns the live canvas-attached VFX host for `supply_drop`: cached flare /
  shockwave texture pieces, an additive shader core, one drift
  `GPUParticles2D` layer, one crash `GPUParticles2D` layer, and a looping
  pulse `Tween`. `commando_supply_drop_fx_host_lifecycle.gd` owns allocation,
  attachment, synchronization, diagnostics, and teardown around this node.
- `scripts/characters/commando_supply_drop_fx_host_lifecycle.gd`
  Owns the detached Supply Drop FX-host lifecycle: one retained host reference,
  invalid/queued-free rejection, existing named-child adoption, deferred
  `add_child` deduplication and pending-state clearance after attachment,
  snapshot/shake/layout synchronization, visible/attached/status projection,
  immediate hide-and-reuse teardown, optional queue-free release, and FX-host
  pipeline prewarm/status delegation. The state host decides whether logical
  VFX layers exist and exposes a compatibility `get_fx_host()` diagnostic
  facade without retaining host fields. Regression guards:
  `tests/commando_supply_drop_fx_host_lifecycle_refactor_smoke.gd`,
  `tests/commando_supply_drop_vfx_remaster_smoke.gd`,
  `tests/commando_supply_drop_fx_host_layout_smoke.gd`, and
  `tests/commando_supply_drop_audio_cleanup_smoke.gd`.
- `scripts/characters/commando_firearm_runtime.gd`
  Owns the first Commando selected-firearm use slice: action-edge input
  gating, supply-hold suppression, current-weapon readiness checks, ammo
  spend, wheel-switch fire suppression, cooldown trigger, base `pistol`
  4-round ammo runtime, ready-sound queued shot, 24-frame aim delay before
  projectile spawn, empty-magazine left-click 150-gauge full-magazine reload,
  per-round reload progress cues, base-pistol reload switch / fire lock,
  one-round 150-gauge emergency reload, switch-held input
  suppression, and the minimal
  projectile / muzzle / impact draw-context state used by the Stage 1
  transitional renderer. It also owns the current target-hit event handoff
  into shared impact particles, battle feedback, boss hit animation, ball hit
  pulse including base-slot pistol pulse-kind normalization,
  weapon-specific one-shot firearm audio cue routing, first-pass boss
  status outcomes via `status_effect_state`, pistol hit-lane stun / headshot /
  legshot / combo outcomes, `commando_pistol` 24-frame aim delay before projectile
  spawn, Beretta's 30%-faster 46.15-frame fire cooldown, 18-frame player horizontal control lock,
  `doping_potion`'s 30-frame fire cooldown / 9-frame control lock /
  head-leg chance multiplier / bullet-speed metadata, pistol shell-casing
  context, 120-frame empty-magazine reload start, pistol
  headshot / legshot gauge-gain result handoff through the effects controller,
  renderer-facing feedback text context, pending
  gauge / boss-damage result updates even when a hit has no lingering visual
  effect, boss health damage-unit result handoff, pistol headshot / 3-hit
  combo boss-health damage, bazooka's 4-round ammo spend, 120-frame
  internal cooldown, 30-frame control lock / firing pose, vertical rocket
  launch from the player top, 3px/frame initial speed with 0.8/frame
  acceleration up to 35, 10-point smoke trail, 155px explosion radius,
  40px knockback, and 90-frame stun, net gun's 3-round ammo spend,
  120-frame cooldown, 30-frame control lock / throw pose, 18px/frame
  harpoon projectile, rope trail, 240-frame capture field, 21-frame miss
  dissolve, dash rope break, 70% hooked-player movement slow, and boss X
  clamp inside the deployed net, AK-47 hold-fire state with 6-frame intervals,
  first-trigger two-shot burst metadata, 90-round ammo spend, 1800-frame
  durability tick, recoil spread accumulation / recovery, 50% movement
  speed multiplier while held, Python-reference 16px/frame bullet speed
  and 60-frame bullet life, AK-47 accumulated boss-health damage every 20 hits, and the
  first lingering-field lane for net fields, suicide-drone fire zones, trap
  clamp remnants, and fire-support blast residue. The fire-support route
  also owns the first call lifecycle:
  42-frame radio-call lock, 120-180-frame inbound delay, aircraft draw
  context, 60-frame drop-arm timing, dedicated radio cue, dedicated
  aircraft-loop start / strike-completion / reset cleanup, Python-parity
  no-crash ball pass-through for the bomber, and a 5-7 bomb gravity-drop
  strike sequence. The bowling-trap route owns the Python-parity input gate:
  3-trap ammo, a 120-frame internal cooldown, 30-frame control lock,
  lower-60% player-field install validation, 48-frame install pose / gauge
  state, waiting trap draw context, downward-ball capture, 90-frame held-ball
  motion ownership, and 4x upward relaunch result handoff through the shared
  ball-position / ball-velocity result lane. It also owns the runtime-armed
  boss-guard collision consumption through boss paddle post-hit: reduced
  original-speed ball restore, `status_effect_state` boss stun / knockback AI
  context, and one-shot guard-state clearing. The suicide-drone route owns
  4-drone ammo, 6-frame grace, active-player movement lock, direct-control
  acceleration / max speed state, manual detonation, ball-hit 3x upward fan
  boost, and boss-return original-speed restoration. Health-boss
  score flow and the shared boss HP bar live in focused core / status
  helpers, so configured boss health now reaches HUD draw context and
  player-score flow. Fire-support activation is radio-only at call time and
  each wall-missile impact uses the Python grenade strike cue. The runtime
  now routes
  the Python-reference firearm wavs for pistol ready / fire / one-round reload, AK-47,
  bazooka launch, net capture, bowling-trap install / snap, and the suicide-drone loop,
  with the drone loop stopped on detonation and round-boundary cleanup. It
  now uses Python-reference firearm hitboxes:
  10x10 pistol bullets, 6x6 AK-47 bullets, bazooka wall bursts with the
  155px explosion radius, the
  net gun's expanded boss capture hitbox, and configured explosion radii for
  support / drone impacts. The Stage 1 firearm renderer and FX host own the
  Godot-native VFX remaster path; remaining work is live visual tuning and
  weapon-feel QA. Public `reset()` / `reset_round()` remain compatibility
  facades and delegate their mutations to the focused lifecycle owner below.
  Public `WEAPON_*` profile aliases remain on this facade, backed by the
  focused load-time profile catalog.
- `scripts/characters/commando_firearm_runtime_lifecycle_state.gd`
  Owns Commando firearm full-reset and round-boundary mutation: transient
  collection clearing, pending damage/gauge cleanup, slingshot/pistol/AK-47/
  bazooka/net-gun/bowling-trap/suicide-drone input and timer defaults, fire-
  sheet cleanup, and bowling-guard clearing. At round boundaries it first
  stops active support-aircraft loops and the suicide-drone loop, builds the
  eligible bowling-trap carryover, performs the full reset, and restores the
  normalized waiting traps unless explicit full cleanup was requested. It
  intentionally preserves net-constrict direction/tick history and the shot
  serial because those fields were outside the existing runtime reset
  contract. Regression guard:
  `tests/commando_firearm_runtime_lifecycle_refactor_smoke.gd`.
- `scripts/characters/commando_firearm_runtime_config_catalog.gd`
  Owns the read-only key projection for twelve Commando firearm facade routes:
  base pistol, AK-47, bazooka, net gun, bowling trap, suicide-drone launch and
  active control, fire spawn, projectile update, projectile hit, and lingering
  spawn, plus per-frame effect update. The runtime supplies authoritative
  scalar/profile tuning once at script load, and hot-path facade calls reuse
  the projected dictionaries
  without rebuilding literals. Fire spawn duplicates only its base route at
  the actual shot event before merging dynamic Pistol Enhance options, so
  shared static config is never mutated. Regression guard:
  `tests/commando_firearm_runtime_config_catalog_refactor_smoke.gd`.
- `scripts/characters/commando_firearm_ammo_weapon_input_state.gd`
  Owns single-press ammo-weapon input side effects for bazooka, net gun,
  bowling trap, and the generic extension-weapon fallback: post-switch and
  shared-debounce gates, configured cooldown checks/triggers, ammo
  consumption, firearm spawn-profile resolution, fire audio dispatch, and
  stable success/failure results. `commando_firearm_runtime.gd` keeps selected-
  weapon routing and delegates the generic branch through the same owner; no
  per-frame config Dictionary is introduced because it reuses the static
  `fire_spawn` route. Regression guard:
  `tests/commando_firearm_generic_weapon_input_refactor_smoke.gd`.
- `scripts/characters/commando_firearm_hit_geometry.gd`
  Owns the pure hit-geometry and projectile impact-reason helpers for
  Commando firearm runtime: boss-hitbox rect construction, projectile hitbox
  rect construction, explosion-radius fallback resolution, rect expansion,
  circle-vs-rect checks, segment-vs-rect checks, direct-hit / support-target-Y
  / wall-impact / target-reached / net-pass / terminal reason priority,
  opponent-wall fire-support direct-hit suppression, hit-result knockback
  profile / velocity / direction math, and the small terminal classification
  helpers those reason paths need. `commando_firearm_runtime.gd` keeps
  selected-firearm input, ammo, cooldown, audio, VFX, projectile removal,
  status application, result handoff paths, and the integrated
  `_get_projectile_impact_reason()` boundary while deterministic projectile
  impact / knockback geometry is tested and called through this helper.
- `scripts/characters/commando_firearm_hit_result_state.gd`
  Owns pure Commando firearm hit-result dictionary scaffolding: base hit-result
  payloads plus stun / slow status-data dictionaries. `commando_firearm_runtime.gd`
  keeps hit classification side effects, status application calls, damage /
  gauge queueing, and weapon-specific hit counters while delegating stable
  hit-result payload shapes here.
- `scripts/characters/commando_firearm_hit_feedback_dispatcher.gd`
  Owns Commando firearm hit-feedback side-effect dispatch: shared impact
  particle spawning, screen-shake feedback, boss-hit animation triggers, and
  ball hit-pulse registration through resolver-owned pulse kind names.
  `commando_firearm_runtime.gd` keeps gameplay timing and pending result
  mutation while calling this dispatcher directly instead of preserving
  private feedback / particle / animation / pulse bridges.
- `scripts/characters/commando_firearm_pistol_hit_state.gd`
  Owns pure Commando pistol hit-roll payload calculation: headshot / legshot /
  normal-hit result fields, doping-exposed hit chances, gauge gain source,
  pistol combo-count rollover, damage deltas, and feedback-hit kind requests.
  `commando_firearm_runtime.gd` keeps the mutable hit counter, feedback spawn
  side effect, status application sequencing, and damage merge into the shared
  combat result while delegating deterministic pistol-hit payload math here.
- `scripts/characters/commando_firearm_ak47_hit_state.gd`
  Owns pure Commando AK-47 accumulated-hit payload calculation: hit-count
  increment / rollover, threshold-ready metadata, and accumulated damage-unit
  fields. `commando_firearm_runtime.gd` keeps the mutable AK-47 hit counter
  and shared combat-result merge while delegating deterministic AK-47 counter
  payload math here.
- `scripts/characters/commando_firearm_audio_resolver.gd`
  Owns pure Commando firearm audio-name lookup behavior: ball-hit pulse
  kind names, weapon-specific fire cue method lists, and weapon-specific
  impact cue method lists. `commando_firearm_runtime.gd` keeps fire-support
  radio suppression, call-site timing, and audio dispatch side effects while
  calling these string mappings directly instead of preserving private audio
  lookup bridges.
- `scripts/characters/commando_firearm_audio_dispatcher.gd`
  Owns Commando firearm audio dispatch mechanics: audio / game_audio dep
  lookup, first-available no-arg method calls, weapon fire / impact routing
  through resolver-owned cue lists, weapon-specific cue fallback to generic
  fire / impact methods, per-round pistol reload cue repetition, and
  suicide-drone loop stop dispatch, plus support-aircraft loop start / stop
  state flag gating for fire-support calls. The runtime keeps gameplay timing
  while calling the dispatcher directly instead of preserving private fire /
  impact or support-aircraft audio bridges; the focused runtime lifecycle
  owner calls it for round-boundary loop shutdown.
- `scripts/characters/commando_firearm_bowling_trap_geometry.gd`
  Owns pure Commando bowling-trap geometry, state payloads, and kinematic
  helpers: install position / payload / marker dictionaries, install and
  player-field eligibility, install / carryover / draw-state summary helpers,
  capture timer progression, capture result handoff, release motion and
  pseudo-projectile dictionaries, guard state / status / result payloads,
  guard ball-speed restoration, guard knockback side, deterministic launch
  direction, and trap-vs-ball rectangle hits. `commando_firearm_runtime.gd`
  now calls this owner directly for install position / trap payload / marker
  flash, install eligibility, active-install predicates,
  capture result payloads, guard ball softening / knockback, launch direction,
  and trap-vs-ball hits while resolving Stage 2 guard-immunity inline without
  private runtime bridge helpers. It still keeps the trap array, ammo / cooldown
  gates, capture / release side effects, audio, VFX, status application, and
  guard state variable ownership. The lifecycle owner calls the carryover
  builder at round reset.
- `scripts/characters/commando_firearm_control_state.gd`
  Owns Commando firearm control-state decisions: effect-update gating,
  player-control lock aggregation, movement-speed multiplier calculation for
  AK-47 hold fire and active suicide-drone control, serve-wait suppression/
  release-latch resolution and firearm-input clearing, plus reset-to-base-
  weapon selection. The compatibility suppression query still returns its
  documented Dictionary, while the production runtime uses compact bit flags
  and applies the latch/clear result directly so the per-frame input path does
  not allocate and unpack that Dictionary. `commando_firearm_runtime.gd` keeps
  the actual timer/projectile/lingering state and selected-weapon routing.
- `scripts/characters/commando_firearm_fire_sheet_resolver.gd`
  Owns pure Commando firearm weapon-fire sheet lookup behavior: which
  weapons use the shared authored fire sheet overlay, which use the long
  duration, and which authored source frame should be the starting pose.
  `commando_firearm_runtime.gd` keeps timer state, replay suppression, and
  draw-state publication while calling this resolver directly for mapping
  decisions instead of preserving private fire-sheet lookup bridges.
- `scripts/characters/commando_firearm_fire_result_state.gd`
  Owns pure Commando firearm result dictionary scaffolding for weapon-fire
  failure payloads plus pistol delayed-shot, shot-queued, delayed-fire, and
  reload-started payloads, AK-47 holding / fired payloads, and generic
  ammo-weapon fired payloads. `commando_firearm_runtime.gd` keeps the input
  gates, ammo / cooldown mutations, reload side effects, audio cues, and
  current timer reads while delegating stable result payload shapes to this
  helper. AK-47 durability consumption and skill-cooldown triggering now stay
  inline at the fire side-effect point instead of passing through private
  runtime helper bridges.
- `scripts/characters/commando_firearm_draw_state_resolver.gd`
  Owns pure Commando firearm renderer-facing draw-state dictionary scaffolding
  for slingshot charge, pistol fire pose, shared weapon-fire sheet overlay,
  AK-47, bazooka, net gun, bowling trap, suicide drone payloads, and the
  actor draw-context payload shape, plus the pure visible-effect gate over
  effect arrays and draw timers. The runtime keeps timer ownership, weapon-fire
  sheet / projectile / trap lifecycle, and actor-context publication while
  composing these resolver payloads directly in `get_actor_draw_context()`.
  Do not reintroduce private runtime `_get_*_draw_state()` bridges for these
  renderer-facing dictionaries; tests should verify the public actor draw
  context or this resolver directly.
- `scripts/characters/commando_firearm_impact_flash_resolver.gd`
  Owns pure Commando impact-flash dictionary construction: bullet / non-
  bullet timers, fire-support grenade visual kind and duration, explosion
  radius fallback, position, color, and secondary-color fallback.
  `commando_firearm_runtime.gd` calls this resolver directly from the
  impact-flash spawn path while keeping impact-flash array limits, lifetime
  updates, draw-state publication, hit / environment side effects, and
  damage handoff.
- `scripts/characters/commando_firearm_input_resolver.gd`
  Owns tiny pure Commando firearm input reads: suicide-drone directional
  vector construction and the legacy `action_just_pressed` fallback to
  `action_pressed`, plus post-switch fire-suppression checks.
  `commando_firearm_runtime.gd` now calls this resolver directly without
  private bridge wrappers, while keeping all input side effects, weapon firing
  gates, manual-control velocity mutation, and detonation logic.
- `scripts/characters/commando_firearm_lingering_effect_state.gd`
  Owns pure Commando lingering-effect base state: duration / size resolution,
  base effect and spawn-result payloads, timer / phase / rope-snap arithmetic,
  active / fire-zone predicates, and boss-clamp result merge helpers. The
  runtime keeps active effect storage, projectile impact ownership, fire-zone
  flame updates, status application, and net dash-break mutation while
  calling the deterministic base lingering-effect math here directly instead
  of preserving private duration / size / payload / timer / clamp bridge
  wrappers. Active lingering-effect update, removal, and array write-back now
  operate on `lingering_effects` directly instead of via private storage
  bridges. The spawn path resolves lingering effect ids inline so explicit
  projectile ids and `_next_shot_id()` allocation stay at the runtime
  side-effect boundary. Fire-zone spawns call the fire-zone predicate and
  deterministic flame builder directly, and frame updates call the timer owner
  plus flame-frame owner directly, so no private fire-seed or frame-update
  bridge remains. Suicide-drone detonation / hit paths branch to the
  molotov-backed fire-zone path directly instead of via private lingering
  dispatch or molotov trigger bridges.
- `scripts/characters/commando_firearm_lingering_fire_flame_state.gd`
  Owns pure Commando lingering fire-zone flame state: deterministic flame
  seeding, effect-size fallback reads, ring / size / lifetime patterns,
  per-frame drift / reset motion, and safe flame array reads. The runtime
  keeps lingering-effect ownership, fire-zone activation, and status
  application while calling this helper directly for spawn-time seeding and
  frame updates. Tests call this helper directly for deterministic frame /
  seed / reset / drift / clamp / size-decay behavior instead of runtime
  fire-flame owner bridges.
- `scripts/characters/commando_firearm_lingering_net_field_state.gd`
  Owns pure Commando lingering net-field state: live / dissolve lifecycle
  payloads, dash-break rope-broken payloads, profile-derived rope / origin /
  player-slow fields, active hooked-field scans, active hooked-field break
  mutation, deterministic net outline generation, net-field position and height
  clamping, dash-active / rising-trigger reads, alternating constrict input
  predicates, and boss clamp rectangle / result math. The
  runtime keeps projectile impact ownership, active lingering-effect storage,
  stored previous-dash state, audio side effects, live spawn / field setup
  side-effect boundaries, candidate-index scanning, and constrict mutation
  while the spawn path calls `apply_net_fields()` directly for live / dissolve
  net payloads, dash-trigger handling reads `get_dash_trigger_result()`, and
  dash-break handling calls `break_active_hooked_net_fields()` directly. The
  alternating-input constrict path performs its candidate-index scan inline
  before calling the helper's next-factor calculation directly. Active lingering
  effect updates also resolve rope-origin resync and boss-clamp merge inline
  instead of routing through private rope-origin / clamp bridges. Tests cover
  the real spawn / break / hooked-field query / dash-trigger / constrict /
  candidate-index / rope-origin paths plus this
  helper's deterministic lifecycle / profile / geometry / shape / height-limit
  / clamp / predicate / constrict-factor calculations instead of runtime
  position, net-height, setup, clamp, predicate, and candidate-index bridges.
- `scripts/characters/commando_firearm_lingering_status_state.gd`
  Owns pure Commando lingering status state: profile-derived status payload
  fields, status application candidate dictionaries, slow-multiplier status
  data, cooldown arithmetic, and lingering-effect / boss-rect overlap tests.
  The runtime keeps the actual `status_effect_state.apply_status()` side
  effect, cooldown reset sequencing, and active lingering-effect storage while
  delegating deterministic setup, application gating, status-data, cooldown,
  and rect / overlap calculations here. The runtime's active status path now
  builds, applies, and resets the cooldown inline in the real update flow
  instead of routing through `_apply_lingering_effect_status()` or older private
  application bridges. Tests call this helper directly and cover the real status
  path instead of runtime setup / application / rect bridges.
- `scripts/characters/commando_firearm_muzzle_flash_resolver.gd`
  Owns pure Commando muzzle-flash dictionary construction: profile kind,
  radius / timer clamps, origin / direction, and secondary-color fallback.
  `commando_firearm_runtime.gd` calls this resolver directly from the
  muzzle-flash spawn paths while keeping muzzle-flash array limits, lifetime
  updates, draw-state publication, and weapon firing side effects; do not
  reintroduce a private runtime muzzle-flash append bridge.
- `scripts/characters/commando_firearm_pistol_feedback_state.gd`
  Owns pure Commando pistol headshot / legshot feedback state: supported hit
  kind filtering, text / wave anchor placement from the boss rect, timer
  payloads, and per-frame timer advancement. `commando_firearm_runtime.gd`
  keeps the `pistol_feedbacks` array limit, append / remove ownership, draw
  context publication, and hit-result side effects while calling this owner
  directly from the spawn path. Do not reintroduce a private runtime pistol
  feedback builder bridge.
- `scripts/characters/commando_firearm_projectile_motion_state.gd`
  Owns pure Commando projectile motion state for small projectile-local
  updates: pistol side-wall bounce payloads, bazooka rocket acceleration and
  smoke-trail trimming, and net-gun rope trail origin / point trimming.
  `commando_firearm_runtime.gd` keeps projectile array ownership,
  weapon-kind dispatch, collision / impact handling, audio, VFX, and result
  handoff while calling this owner directly for rocket acceleration, pistol
  side-wall bounce, and net-rope updates. Stage 2 pistol rock-bounce routing
  calls `CommandoFirearmStage2RockInteractionResolver` directly from the
  projectile update path, and Stage 1 balloon bullet pops route through
  `CommandoFirearmStage1BalloonInteractionResolver` before normal boss /
  wall impact dispatch. Do not reintroduce private runtime projectile-motion
  or bounce / balloon bridges for those helpers.
- `scripts/characters/commando_firearm_projectile_impact_state.gd`
  Owns pure Commando projectile impact payload scaffolding: boss hit-event
  dictionaries and environment-impact result dictionaries. The runtime keeps
  combat-result calculation, boss damage / gauge queueing, particle / feedback
  / audio side effects, lingering-effect spawning, and hit-event array
  ownership while delegating stable result payload shapes here.
- `scripts/characters/commando_firearm_projectile_spawn_state.gd`
  Owns pure direct-fire Commando projectile payload scaffolding: base bullet /
  rocket / net dictionaries plus optional doping, slingshot, explosion,
  acceleration, smoke-trail, and rope-trail fields, plus normalized launch
  direction / angle-offset calculation. The runtime keeps fire input gates,
  profile mutation, origin / target calculation, projectile-array
  ownership, support-call / bowling-trap dispatch, muzzle flashes, shell
  casing side effects, and audio while delegating stable projectile field
  shapes here.
- `scripts/characters/commando_firearm_slingshot_state.gd`
  Owns pure Commando slingshot charge state: charging / not-ready /
  charge-canceled / release result payloads, charge-level thresholds, interval
  gauge-drain calculations, charge-derived projectile profile fields, and
  charge-derived hit-effect payload fields. The runtime keeps input gates,
  mutable charge fields, projectile spawning, audio, cooldown / control-lock
  mutation, status application, and hit-result sequencing while delegating
  deterministic slingshot calculations here. Do not reintroduce private
  runtime bridges for charge-level refresh, slingshot fire-profile construction,
  or slingshot hit-effect application.
- `scripts/characters/commando_firearm_shell_casing_state.gd`
  Owns pure Commando shell-casing state: AK-47 / pistol ejection payloads,
  deterministic seed-derived velocity / rotation values, paddle-floor
  clamping, per-frame gravity / bounce / lifetime advancement, and
  out-of-bounds deactivation. `commando_firearm_runtime.gd` keeps the
  `shell_casings` array limit, append / remove ownership, draw-state
  publication, and weapon fire side effects while delegating deterministic
  casing payload and motion updates to this helper. Do not reintroduce private
  runtime shell-spawn bridges for AK-47 or pistol casings.
- `scripts/characters/commando_firearm_origin_geometry.gd`
  Owns the pure origin / anchor math for Commando firearm runtime:
  generic player muzzle position, authored weapon-fire sheet world anchors,
  player paddle dimensions / scale reads, fallback player position, and
  boss target center resolution, plus weapon/profile based firearm origin
  selection and aim-origin projection. `commando_firearm_runtime.gd` keeps
  its existing private wrapper names while delegating the coordinate and
  origin-selection math here, so projectile timing, ammo, cooldown, audio,
  and hit-result handoff remain unchanged.
- `scripts/characters/commando_firearm_pending_result_state.gd`
  Owns pure Commando firearm pending result queue state: boss-health damage
  unit/source accumulation, special-gauge gain/source/last-hit-kind
  accumulation, and the one-shot result dictionaries emitted to the battle
  effects controller. `commando_firearm_runtime.gd` keeps only the pending
  fields while calling this owner directly from projectile-hit
  queueing and `update_effects()` result emission. Do not reintroduce private
  runtime queue / consume bridges for these pending-result paths; the focused
  runtime lifecycle owner clears pending state during reset.
- `scripts/characters/commando_firearm_pistol_enhance_state.gd`
  Owns Commando Pistol Enhance runtime policy: safe effective-level lookup,
  the authored spread ladder and `Lv.5` accuracy cap, documented `Lv.5`
  speed/normal-hit-knockback caps, intentionally uncapped `Lv.6+` magazine
  growth, base-pistol ammo-max synchronization without per-frame spent-ammo
  refill, and Beretta-isolated spawn-option projection. The firearm runtime
  keeps its public static helpers plus `_build_firearm_spawn_options()` and
  per-frame ammo-sync facades for compatibility. Regression guards:
  `tests/commando_firearm_pistol_enhance_state_refactor_smoke.gd` and
  `tests/commando_pistol_enhance_smoke.gd`.
- `scripts/characters/commando_firearm_profile_catalog.gd`
  Owns load-time construction of the eight weapon profiles, eight hit-feedback
  profiles, eight hit-result profiles, three lingering-effect profiles, and
  the fire-support profile/feedback/result override tables. The builder takes
  the runtime's existing scalar tuning values as input, so projectile speed,
  hitbox/lifetime, explosion, knockback, stun, and net-duration data keep one
  authoritative tuning source while leaving the catalog independent of the
  runtime facade. `commando_firearm_runtime.gd` builds it once and preserves
  the existing public table names as compatibility aliases. Regression guard:
  `tests/commando_firearm_profile_catalog_refactor_smoke.gd`.
- `scripts/characters/commando_firearm_profile_resolver.gd`
  Owns pure Commando firearm profile lookup behavior: weapon-id
  normalization, fallback profile selection, deep-copy protection,
  fire-support override application, and no-fallback lingering-effect
  lookup. Runtime call sites query this resolver directly instead of preserving
  private profile lookup bridges, including direct bazooka / net-gun fire
  profile bridges. Selected-firearm input, ammo, cooldown, projectile timing,
  audio, and result handoff remain untouched.
- `scripts/characters/commando_firearm_stage2_rock_interaction_resolver.gd`
  Owns Commando firearm routing into Stage 2 rock interactions: explosion
  rock target discovery across direct deps / registry / stage router,
  duplicate target suppression, bazooka / Fire Support rock-break context
  stamping, and Commando pistol rock-bounce payload merging. The firearm
  runtime keeps projectile ownership, weapon-id checks, impact flashes, audio,
  damage / gauge result handoff, and the surrounding projectile update loop.
- `scripts/characters/commando_firearm_stage1_balloon_interaction_resolver.gd`
  Owns Commando firearm routing into Stage 1 balloon interactions: bullet-only
  weapon filtering for base pistol / Beretta / AK-47, direct dependency and
  registry lookup for the Stage 1 balloon event, duplicate target suppression,
  and pop-result forwarding so projectile motion can consume the bullet
  without spawning a boss-impact flash. The Stage 1 balloon interaction
  coordinator owns actual removal; `stage1_balloon_event.gd` owns synchronous
  pop VFX / audio and special-balloon starpoint feedback.
- `scripts/characters/commando_firearm_support_aircraft_geometry.gd`
  Owns pure Commando fire-support aircraft geometry: collision-rect
  construction and ball-path segment intersection against the grown
  aircraft bounds. `commando_firearm_runtime.gd` keeps support-call state,
  aircraft audio lifecycle, and public collision-query routing while calling
  this helper directly for geometry decisions.
- `scripts/characters/commando_firearm_support_call_resolver.gd`
  Owns pure Commando fire-support call math: deterministic support-call
  seed generation, aircraft-entry delay selection, bomb-count selection
  from the runtime's tuned min / max constants, initial call payload
  construction including configurable aircraft start / curved flight
  metadata, support-marker flash payloads, tuned drop-arm / bomb-interval /
  aircraft-speed progression supplied by the runtime, and
  deterministic per-bomb target selection with seeded random x scatter, plus
  pure per-frame call-state advancement flags for aircraft start, bomb spawn,
  call completion, and active radio/call-lock lookup.
  `commando_firearm_runtime.gd` keeps support-call array mutation, aircraft
  audio lifecycle, projectile spawning, and draw / damage handoff while
  calling this helper directly for deterministic payload / target /
  lifecycle-step decisions instead of preserving private support-call setup or
  advance bridges.
- `scripts/characters/commando_firearm_support_projectile_resolver.gd`
  Owns pure Commando fire-support projectile construction: deterministic
  drop-row fallback construction, opponent-wall missile construction,
  target-y / wall-y clamping, horizontal jitter or wall-flight velocity,
  projectile metadata, and profile/default value projection.
  `commando_firearm_runtime.gd`
  keeps shot-id allocation, projectile-array limits, aircraft timing, audio,
  VFX, and damage handoff while calling this resolver directly for
  support-round dictionary construction instead of preserving a private build
  bridge.
- `scripts/characters/commando_firearm_suicide_drone_ball_boost_resolver.gd`
  Owns pure Commando suicide-drone ball-boost result math: deterministic
  fan-angle selection, original / restore speed fallback, boosted speed, and
  upward launch velocity metadata. `commando_firearm_runtime.gd` keeps
  detonation, cooldown, audio, VFX, boss-restore state application, and
  result handoff while calling this owner directly for ball-hit boost result
  dictionaries instead of preserving a private boost-result or fan-angle
  bridge.
- `scripts/characters/commando_firearm_suicide_drone_geometry.gd`
  Owns pure Commando suicide-drone geometry: spawn and player-lock anchors,
  centered drone rectangles, ball / boss rectangle hits, explosion-vs-boss
  center checks, and top-wall hits. `commando_firearm_runtime.gd` now calls
  this owner directly for spawn / lock anchors, ball / boss / top-wall hits,
  and explosion-vs-boss checks while keeping manual-control velocity mutation,
  detonation, cooldown, audio, VFX, and result handoff.
- `scripts/characters/commando_firearm_suicide_drone_state.gd`
  Owns pure Commando suicide-drone state payloads: manual-control projectile
  dictionaries, input-derived velocity / rotor speed, grace / rotor frame
  advancement, field-bound clamping, non-manual homing velocity, active
  suicide-drone projectile predicates / lookup, and fire / fire-failed /
  active-input / detonation result dictionaries.
  `commando_firearm_runtime.gd` calls active projectile predicates / lookup,
  projectile construction, input velocity mutation, homing velocity, field
  clamping, and result dictionary builders directly from this owner and keeps
  projectile-array ownership, input gate side effects, detonation removal,
  cooldown mutation, audio, VFX, boss-hit application, lingering effect
  spawning, and ball-boost merge sequencing. Do not reintroduce private runtime
  suicide-drone state/result bridge methods for these owner calls.
- `scripts/characters/commando_firearm_value_utils.gd`
  Owns tiny pure Commando firearm value helpers: limited append eviction
  safe Variant-to-Vector2 / Color / Dictionary / Array fallback reads,
  projectile target / weapon-id / kind reads,
  pistol weapon classification / hit-roll / hit-chance helpers,
  doping-potion context normalization / dependency reads / config projection,
  doping-adjusted pistol cooldown / control-lock, fire-rate multiplier,
  AK-47 fire interval, and bazooka cooldown / control-lock calculations,
  pending pistol-fire geometry refresh, generic timed-effect array advancement,
  and registry instance fallback lookup. `commando_firearm_runtime.gd` now
  calls the type fallback, projectile, pistol-hit, doping/cooldown,
  limited-append, timed-effect, and registry value reads directly while
  keeping only stateful runtime helpers for runtime-owned mutation; shot-id
  state remains in the runtime.
- `scripts/characters/commando_firearm_cooldown_state.gd`
  Owns Commando firearm skill-cooldown interaction details: configured
  cooldown readiness queries, `trigger_cooldown` preference for cooldown-state
  owners that accept explicit seconds, configured-cooldown fallback routing,
  Doping Potion fire-rate scaling for cooldown seconds, and no-op behavior
  when a skill-state dependency is absent. The firearm runtime should call
  this owner directly for readiness and skill-cooldown triggering instead of
  reintroducing private `_is_ready` / `_trigger_firearm_skill_cooldown` /
  `_get_firearm_skill_cooldown_seconds` bridges.
- `scripts/characters/commando_input_reader.gd`
  Owns Commando raw input on top of the shared Smasher snapshot and adds
  mouse-wheel weapon switching. Wheel events route only when the selected
  runtime character is `soldier` / `commando` and mutate the weapon
  controller, not stacked pillar HUD slots.
- `scripts/characters/commando_player_controller.gd`
  Owns Commando player-control orchestration for the active rally loop:
  syncing permanent firearms from the skill config, preparing one-shot
  stage-boundary weapon policy, running emergency supply, supply drop, and
  selected-firearm input before delegating shared movement / dash behavior
  to the Smasher controller. When the firearm runtime reports a post-fire
  control lock, it passes a horizontal-input lock into the shared controller
  so Python-parity afterdelay can stop normal movement without inventing a
  second movement stack. When the firearm runtime reports a movement-speed
  multiplier, it passes that into the shared movement state so AK-47 held
  fire can reuse normal paddle motion at 50% max speed. It then returns the updated special gauge and
  any positive Commando skill-use gold as `skill_gold_award` for the common
  actor-result applier. It does not write `runtime_perk_gold` directly.
- `scripts/characters/smasher_input_reader.gd`
  Owns raw Smasher gameplay input polling for horizontal movement, dash
  key state, Drive action state, and exclusive Power Smashing direction.
  `smasher_player_controller.gd` and the actor update driver route the
  snapshot into dash, movement, and skill activation modules.
- `scripts/characters/smasher_player_controller.gd`
  Owns Smasher player-control orchestration for the active rally loop:
  input snapshot consumption, active-item throwable windup control locks,
  optional `horizontal_input_locked` suppression for callers such as
  Commando firearm afterdelay, drive input frame updates, horizontal movement
  application, and delegation to the dash controller.
  `battle_scene_actor_update_driver.gd` calls this controller once per
  physics tick and applies the returned player position, speed, and gameplay
  frame counter.
- `scripts/characters/smasher_player_dash_controller.gd`
  Owns Smasher player-control dash orchestration: dash start / chain side
  effects, half/full dash selection, dash-to-skill combo grace start /
  effect clearing, Dash Spirit spawn hook, dash-token HUD spin, dash audio
  / shake feedback, dash-position update forwarding, and
  recharge flash feedback.
- `scripts/characters/smasher_drive_input_state.gd`
  Owns the public Smasher drive input facade: frame input updates,
  buffered direction consumption, cooldown updates, and delegation to the
  buffer / frame-cooldown states. Raw Smasher input polling lives in
  `smasher_input_reader.gd`, and Drive ball activation behavior lives in
  `smasher_drive_activation_controller.gd`.
- `scripts/characters/smasher_drive_input_buffer_state.gd`
  Owns Smasher drive input buffering: directional/action press-frame
  tracking, last-pressed edge detection, stale input expiry, and buffered
  Drive direction consumption.
- `scripts/characters/smasher_drive_frame_cooldown_state.gd`
  Owns Smasher Drive / Power Smashing frame-cooldown lockout timers,
  cooldown decay, trigger clamping, and blocked-state reporting.
- `scripts/characters/smasher_drive_activation_controller.gd`
  Owns the player-paddle Drive activation sequence: activation eligibility,
  buffered direction consumption, combo-aware initial Drive bounce request,
  activation result assembly, and delegation to the activation feedback
  controller. The paddle-bounce skill-flow path applies the returned ball /
  Drive scene fields before resolving final paddle bounce velocity.
- `scripts/characters/smasher_drive_activation_feedback_controller.gd`
  Owns Drive activation side effects: combo consumption, frame /
  configured cooldown triggers, gauge-orb spin, Drive particles, and
  Drive sound.
- `scripts/characters/smasher_drive_bounce_state.gd`
  Owns the public Smasher Drive bounce facade: initial Drive bounce
  requests and contact-shape requests. It delegates the initial bounce and
  center/smash contact math to focused resolvers.
- `scripts/characters/smasher_drive_initial_bounce_resolver.gd`
  Owns Smasher Drive initial bounce calculation: no-combo / combo speed
  multipliers, Godot-side combo balance scaling, combo bypass bonus, curve angle shaping, spin strength,
  Drive particle count, and combo-consumption / text-duration outputs.
- `scripts/characters/smasher_drive_contact_shape_resolver.gd`
  Owns Smasher Drive contact-shape bonuses during paddle resolution:
  center-hit speed / moderated spin bonus, smash-edge speed bonus, and smash-angle
  jitter.
- `scripts/characters/smasher_drive_counter_state.gd`
  Owns the boss-counter reaction against an active Drive ball: first boss
  contact detection, retained spin, softened Drive speed-increase reduction,
  and higher counter speed caps. The paddle-bounce boss-hit path owns when
  the boss paddle collision invokes the counter calculation.
- `scripts/characters/smasher_power_smash_state.gd`
  Owns the public Smasher Power Smashing state API and delegates runtime
  field storage, velocity / motion calculation, and VFX state to focused
  modules. The scene shell no longer mirrors those runtime fields as scene
  variables; activation and motion controllers consume this facade, while
  internal hit-velocity and motion resolvers receive the runtime state
  directly instead of duplicate pass-through accessors.
- `scripts/characters/smasher_ghost_shot_state.gd`
  Owns the Godot Smasher Ghost Shot runtime layered on the Power Smashing
  facade: unlock-gated activation mode, three-phase ball steering,
  pending teleport / hidden-ball handoff, final boss-side refire velocity,
  and blackhole / ghost afterimage VFX state. The ball update controller
  skips normal ball physics only while Ghost Shot is waiting inside a
  teleport gap.
- `scripts/characters/smasher_power_smash_velocity_facade.gd`
  Owns the Power Smashing velocity facade: hit-velocity resolver
  invocation, active parabola motion resolver invocation, and passing the
  shared runtime state into both resolver paths.
- `scripts/characters/smasher_power_smash_runtime_state.gd`
  Owns the public Power Smashing runtime-field API and delegation to the
  lifecycle, speed marker, and text timer states.
- `scripts/characters/smasher_power_smash_lifecycle_state.gd`
  Owns Power Smashing lifecycle orchestration: activation eligibility,
  freeze-to-parabola transition, and delegation to freeze / parabola
  state modules.
- `scripts/characters/smasher_power_smash_activation_rules.gd`
  Owns pure Power Smashing activation checks: serve / active-ball gates,
  gauge cost, active freeze / parabola lockouts, frame cooldown block, and
  skill cooldown availability.
- `scripts/characters/smasher_power_smash_parabola_state.gd`
  Owns Power Smashing parabola fields: activity, elapsed time, curve
  direction / strength, consumed combo count, and motion stepping.
- `scripts/characters/smasher_power_smash_freeze_state.gd`
  Owns Power Smashing freeze fields: freeze activity, freeze timer, ball
  pose lock, locked ball position, and freeze duration completion.
- `scripts/characters/smasher_power_smash_speed_state.gd`
  Owns Power Smashing speed markers: original speed capture, target /
  boosted speed values, initial-boost active flag, and initial-boost
  timeout clearing.
- `scripts/characters/smasher_power_smash_text_state.gd`
  Owns Power Smashing banner text timing: reset semantics, activation
  duration setup, per-frame countdown, and renderer-facing timer access.
- `scripts/characters/smasher_power_smash_hit_velocity_resolver.gd`
  Owns Power Smashing initial hit-velocity math: original-speed capture,
  moderated dampened speed boost, no-combo penalties, combo speed bonus,
  launch-speed clamping, initial boosted-speed setup, and delegation to the
  hit-direction resolver.
- `scripts/characters/smasher_power_smash_hit_direction_resolver.gd`
  Owns Power Smashing initial hit direction shaping: side launch turn
  minimums, straight launch paddle-offset correction, and moderated dampened
  direction multipliers.
- `scripts/characters/smasher_power_smash_motion_resolver.gd`
  Owns Power Smashing active-ball motion math after launch: initial boost
  interpolation, horizontal arc force, lift / pull phases, and per-frame
  curve chaos.
- `scripts/characters/smasher_power_smash_effects_state.gd`
  Owns the Smasher Power Smashing VFX facade: trail / particle clear,
  original-style blue electric hit bursts, active-parabola ambient spawning,
  per-frame update fanout, and public VFX accessors. Storage and decay live
  in focused VFX states.
- `scripts/characters/smasher_power_smash_trail_state.gd`
  Owns Power Smashing trail snapshots: original 8px spawn spacing,
  ball-size trail snapshots, max-trail trimming, fast alpha-style trail
  life decay, and renderer-facing trail access.
- `scripts/characters/smasher_power_smash_particle_state.gd`
  Owns Power Smashing particles: original blue-white radial burst spawning,
  moving ambient energy / spark spawning, lifetime / velocity decay,
  light gravity, max-particle trimming, and renderer-facing particle access.
- `scripts/characters/smasher_power_smash_activation_controller.gd`
  Owns Power Smashing / Ghost Shot activation orchestration: action-input
  eligibility, Ghost Shot priority when its unlocked slot, gauge, and
  cooldown are ready, moderated directional arc selection, combo
  consumption, gauge spend, activation begin request, and delegation to the
  activation feedback controller.
  The Smasher player-control path applies the returned scene gauge value;
  later freeze / parabola progression lives in the motion controller.
- `scripts/characters/smasher_power_smash_activation_feedback_controller.gd`
  Owns Power Smashing activation side effects: configured cooldown trigger,
  frame-cooldown trigger, gauge-orb spin, Drive-state clearing callbacks,
  and activation sound. Hit bursts live in the paddle-hit handler and launch
  shake lives in the motion controller to match the original timing split.
- `scripts/characters/smasher_power_smash_motion_controller.gd`
  Owns Power Smashing post-activation progression: freeze-pose locking,
  pending contact-animation release, freeze launch sound, combo-tier launch
  shake, and parabola motion stepping. The ball update driver applies the
  returned ball snapshot.
- `scripts/characters/smasher_skill_feedback_renderer.gd`
  Owns Smasher skill feedback drawing: dash status text, Drive / Power
  Smashing timing monitors, center banners, and the feedback draw facade.
  Character controllers own skill activation, feedback controllers route
  sound playback, and `battle_playfield_overlay_drawer.gd` owns draw
  ordering.
- `scripts/characters/smasher_skill_timing_monitor_renderer.gd`
  Owns the original Smasher Drive / Power-Smashing pre-hit timing monitor:
  yellow early Drive ring, red close-range SMASHING ring, ball / paddle
  approach checks, gauge-cost color selection, pulse ring, and label draw.
- `scripts/characters/smasher_power_smash_feedback_effect_renderer.gd`
  Owns Power Smashing / Ghost Shot canvas rendering from runtime snapshots,
  including original-style blue linked lightning trails, white energy cores,
  glow shells, spark streaks, Ghost Shot blackhole rings, purple aura, and
  orbiting ghost afterimages.
- `scripts/characters/actor_animation_state.gd`
  Owns the public actor animation state API and combines player / boss
  draw snapshots. It also exposes player pending-contact offset helpers for
  Power Smashing freeze release. The battle effects update controller passes
  texture availability and movement state, while `battle_draw_actor_context.gd`
  forwards the animation snapshot to the Stage 1 actor renderer.
- `scripts/characters/player_actor_animation_state.gd`
  Owns Smasher animation timers and frame state: idle / walk frames, hit
  pose timing, hit side, hit-frame easing, contact-animation intensity,
  shield / left-raise follow-through timers, pending contact offsets, and
  player animation clock.
- `scripts/characters/boss_actor_animation_state.gd`
  Owns boss animation timers and frame state: Dalji walk frame, facing,
  idle frame, anticipated ball-contact attack timing plus exact-contact
  fallback protection, and default boss frame timing constants.
- `scripts/characters/smasher_dash_state.gd`
  Owns the legacy-named shared dash facade: dash-key release state, input-facing
  start/chain gates, and coordination between dash motion and dash-token
  recharge state. Raw input polling lives in `smasher_input_reader.gd`, and
  `battle_scene_actor_update_driver.gd` applies returned player positions;
  the Smasher dash controller owns dash start feedback while effect/audio
  modules consume dash recovery snapshots. It also captures active
  `dash_acceleration` / 버스트업 bonus, exposes the temporary collision
  context, and routes full-dash audio to copied `bustup.wav` while half
  dash keeps the half-dash sound path.
- `scripts/characters/smasher_dash_motion_state.gd`
  Owns Smasher dash motion state: full/half dash timers, recovery lockout,
  consecutive-dash elapsed-frame timing, start / chain eligibility, and
  returned player-position update, including draw/audio recovery-progress
  snapshot fields plus active `dash_acceleration` level / width-and-height bonus
  snapshot fields. Active movement and recovery timing are delegated to
  the motion update resolver.
- `scripts/characters/smasher_dash_motion_update_resolver.gd`
  Owns Smasher dash motion update math: inactive recovery timer ticking,
  active-motion resolver delegation, state mergeback, and dash end state
  cleanup.
- `scripts/characters/smasher_dash_active_motion_resolver.gd`
  Owns active Smasher dash movement math: dash deceleration speed,
  horizontal clamp, end detection, elapsed-frame delta, and half-dash
  recovery multiplier application.
- `scripts/characters/smasher_dash_token_state.gd`
  Owns Smasher dash token state: max token count, current token charges,
  recharge countdown, full-dash token consumption, recharge completion,
  consecutive-dash count reset, and Boost Charging's pending free-dash
  flag plus 90% remaining recharge reduction for one charging token.
- `scripts/characters/player_movement_state.gd`
  Owns shared non-dash horizontal movement calculation: character-provided
  acceleration / max speed, optional runtime max-speed multiplier, release
  deceleration, Python-parity turn deceleration, Power-Smashing boss-counter knockback decay,
  intensity-based paddle-hit self-knockback decay, and clamp to the
  playfield. Character input readers own raw input polling, while
  character player controllers own dash/skill input routing.
- `scripts/characters/smasher_skill_config.gd`
  Owns Smasher skill data tables: equipped skill slots, gauge costs,
  skill colors, cooldown seconds, active-orb tooltip metadata, and
  runtime equipped-skill order. `drive` and `power_smashing` are the
  starter slots; unlock-style runtime perks such as `unlock_magnum_grip`
  and `unlock_shield_kiting` add implemented skills into the first free slot through
  `unlock_and_equip_skill()`. Focused character state modules own
  implemented skill activation behavior, and draw-context builders pass this
  snapshot into HUD renderers.
- `scripts/hud/smasher_skill_orb_tooltip_renderer.gd`
  Owns Smasher skill-orb hover hit testing and tooltip drawing: slot
  geometry reuse, active-skill field order, wrapped Korean copy,
  structured control rows, cooldown / gauge readout, and handoff to the
  focused effect-preview renderer. It also detects Commando current-firearm
  panel hover and delegates that tooltip surface to
  `commando_firearm_tooltip_renderer.gd`. It renders as a final screen-space
  HUD overlay after the transformed playfield so tooltip panels are not
  covered by gameplay drawing.
- `scripts/hud/skill_orb_tooltip_effect_preview_renderer.gd`
  Owns the skill-specific animated effect-preview sketches shown inside
  orb tooltips. `smasher_skill_orb_tooltip_renderer.gd` keeps hover,
  layout, and text ownership while delegating only this preview drawing
  family classification and canvas sketch rendering.
- `scripts/hud/skill_orb_tooltip_hover_state.gd`
  Owns frame-time skill-orb and Commando current-firearm panel hover-state
  detection for the final tooltip overlay. It builds the required pillar
  layout / draw context and calls the tooltip renderer's hover API, keeping
  HUD hover geometry out of `battle_scene_update_driver.gd`.
- `scripts/hud/skill_orb_tooltip_overlay_host.gd`
  Owns the scene child node used for final screen-space skill-orb tooltip
  redraws. Frame/update controllers request show/hide through this HUD host
  so `battle_scene_shell.gd` does not preload or store the tooltip overlay
  node directly.
- `scripts/ai/boss_ai_state.gd`
  Owns the current boss movement AI slice: prediction-state delegation,
  active-item grenade stun / flare confusion movement branches,
  approaching-ball urgency detection, latest ball impact-boost snapshot
  handoff, Stage 1 emergency dash token / recharge / post-dash recovery,
  Power-Smashing combo reaction multiplier handoff, turn-inertia velocity
  delegation, boss-serve psychological feint profiles (hold-snap,
  side-step, bait-reverse, double-bluff, stare-down, shuffle),
  intensity-based paddle-hit self-knockback decay, and horizontal position
  updates. `battle_update_boss_ai_context_builder.gd` passes the current
  serve timer / target delay so these feints can pace themselves while
  `serve_flow_controller.gd` still owns the actual release.
  `battle_scene_actor_update_driver.gd` applies boss position/velocity
  snapshots each physics tick.
- `scripts/ai/boss_ai_turn_inertia_resolver.gd`
  Owns boss horizontal velocity math: acceleration/deceleration,
  sticky turn-around inertia that slides on the old direction with reduced
  reversal braking, approaching-ball brake recovery, restrained opposite acceleration release,
  speed clamping, and the current Stage 1 / Dalji champion-league movement
  profile plus the shared +3% per-stage boss movement ramp emitted by
  `battle_update_boss_ai_context_builder.gd`.
- `scripts/ai/boss_ai_prediction_state.gd`
  Owns boss ball-position prediction: champion-league speed-based prediction
  frames, impact-boost / decay-aware boss-line arrival simulation,
  side-wall reflection prediction, boss-center target clamping, random
  prediction error, Power-Smashing combo focus mistake reduction, temporary
  fail windows, and fail-timer reset. The reflection bounds arguments and
  the boss-center clamp are decoupled: callers may narrow the reflection
  bounds (허공환영 deception frames pass the decoy visual margin) while the
  target clamp stays on the context-global play bounds. The decoy opt-in
  flag prediction_reflect_velocity switches the boss-line arrival to an O(1)
  closed form that is fps-scale-aware to mirror the decoy's real integer-tick
  motion (decoys move vel × fps_scale per tick; the project default is 72Hz
  = 5/6): ticks = ceil(distance / (descent × fps_scale)) and
  dx = vx × fps_scale × ticks, folded with the initial signed vx through a
  reflected triangle-wave modulo — no frame budget, no bounce limit, and no
  per-frame allocation. The fps_scale plumbing responsibility spans all
  three BossAiState call surfaces (normal tracking predict_future_x, the
  whip-deactivation predict_exact_arrival_x trailing argument, and
  chained-dash targeting); the legacy real-ball approximation keeps the
  original vx each frame and stays untouched.
- `scenes/main.gd`
  Is now only a one-line entry script that extends
  `res://scripts/core/battle_scene_shell.gd`.
- `scripts/core/boot_flow_scene.gd`
  Owns the Godot app-root boot flow inherited by `scenes/boot_flow.tscn`:
  startup penguin logo playback / skip input, fixed Stage 1 startup
  selection, logo-to-loading-to-character-select flow, one-shot
  battle-logo skip handoff, and transition into the character-select scene
  before battle. It delegates early main-menu BGM preload/mute/player state to
  `main_menu_audio_controller.gd` and drains its character-select prewarm on
  scene exit, then releases all scene-local `RefCounted` collaborators before
  ObjectDB shutdown.
- `scripts/core/application_quit_coordinator.gd`
  Owns process-lifetime final quit routing for the main-menu action, window
  close, and the headless-load probe. It disables automatic close acceptance,
  stops/detaches all tree audio streams, frees current and late-arriving scenes
  across deferred scene-change gaps, drains loader caches, waits a bounded
  mix-thread/RefCounted quiet window, and only then calls `SceneTree.quit()`.
- `scripts/core/screenshot_capture.gd`
  Owns the app-wide F12 screenshot shortcut as an autoload. It listens
  above individual boot, character-select, and battle input ladders,
  captures the root viewport after the current draw frame, and saves PNGs
  under `user://screenshots/` with timestamped `diskhearts_lingpia_*`
  filenames.
- `scripts/core/battle_scene_shell.gd`
  Owns the thin Node2D shell inherited by `scenes/main.gd`: registry
  construction, scene-state property forwarding, the public compatibility
  API, and the top-level `_ready`, `_physics_process`, and `_draw`
  delegation points. Player-control orchestration now lives in the Smasher
  controller, startup / cleanup routing lives in the battle scene startup
  controller, battle initialization and intro-start flags live in the battle
  scene flow controller, boot / intro readiness gates live in the battle
  scene readiness controller, modal / debug overlay gates live in the battle
  scene modal-gate controller, startup wiring lives in the battle-scene bootstrap,
  viewport geometry lives in the battle view-layout module, match / scoreboard flow
  lives in the match-flow controller, ball reset / serve fanout lives in
  the ball round controller, active-ball frame orchestration lives in the
  ball update controller, paddle-hit orchestration lives in the paddle
  bounce controller, per-frame effect fanout lives in the battle effects
  update controller, boot-time resource prewarming lives in the battle boot
  warmup controller, idle / physics / draw-frame shell routing lives in the
  battle scene frame controller, top-level input routing lives in the battle
  scene input controller, mobile touch controls live in the battle mobile touch
  controller, Power Smashing post-activation motion lives in the
  Smasher motion controller, and lazy-loaded module metadata / cached
  module instances live in the gameplay module registry and script-instance
  cache instead of scene-level path constants, per-module getter functions,
  or local shell dictionaries. Future ports should keep peeling stable
  systems into the module map above instead of growing this shell.
- `scripts/core/battle_scene_startup_controller.gd`
  Owns battle-scene startup facade routing: applying selection / logo-ready
  startup through `battle_scene_ready_lifecycle.gd`, teardown through
  `battle_scene_teardown_lifecycle.gd`, and preserving the public startup /
  teardown methods used by the shell. Character-selection handoff is
  delegated to `battle_scene_selection_startup_lifecycle.gd`; small startup
  helper methods remain here for the ready lifecycle to call.
- `scripts/core/battle_scene_selection_startup_lifecycle.gd`
  Owns the battle-scene selection handoff lifecycle: reading the optional
  `GameSelectionState` autoload selection, normalizing runtime character and
  league mode, clamping the selected stage, resolving the Stage 1 entry boss
  three-boss roulette through its dedicated RNG unless an explicit debug or
  seeded Tower variant was selected, and writing the selected character /
  runtime / display-name / AI-mode fields onto the battle owner.
- `scripts/core/battle_scene_ready_lifecycle.gd`
  Owns battle-scene ready/startup lifecycle: applying the optional
  `GameSelectionState` autoload selection into battle state, initial
  battle-window configuration, consuming the one-shot battle-logo skip flag
  after the app-root logo has already played, startup logo begin handoff,
  and redraw request.
- `scripts/core/battle_scene_teardown_lifecycle.gd`
  Owns battle-scene teardown lifecycle: exit-time logo cleanup, BGM stop,
  project resource-cache clear, skill-orb texture-normalizer cache clear,
  gameplay registry clear, and module-cache clear callback. The startup
  controller keeps its public `exit_tree()` surface and delegates teardown
  here.
- `scripts/core/battle_scene_flow_controller.gd`
  Owns battle-scene start-flow state: battle initialization guard, delayed
  stage-BGM start after logo audio, stage-landing intro start, ball-spawn
  intro start, and the flags consumed by input / frame / mobile-touch gates.
  The battle shell delegates its initialization and intro callback methods
  here instead of keeping those booleans directly. Battle initialization is
  delegated to `battle_scene_battle_initialize_lifecycle.gd`, and
  stage-landing / ball-spawn intro handoff is delegated to
  `battle_scene_stage_intro_flow_lifecycle.gd`.
- `scripts/core/battle_scene_battle_initialize_lifecycle.gd`
  Owns the battle initialization lifecycle: one-shot initialization guard,
  `battle_scene_lifecycle.initialize()` handoff, `play_stage_bgm` startup
  context forwarding, and battle / BGM-start flag latching.
- `scripts/core/battle_scene_stage_intro_flow_lifecycle.gd`
  Owns the post-logo stage intro flow lifecycle: waiting for penguin-logo
  audio to finish, starting stage BGM, beginning the stage-landing intro,
  falling through to ball-spawn intro when landing does not claim the frame,
  and issuing redraws for active intro transitions.
- `scripts/core/battle_scene_readiness_controller.gd`
  Owns shared battle-scene readiness gates: boot warmup completion, logo /
  stage-landing / ball-spawn intro active checks, early input / physics
  blocking, and the mobile-touch scene-ready predicate. Shell, input, and
  frame controllers use this module so intro-state gating stays consistent
  as the port grows.
- `scripts/core/battle_scene_modal_gate_controller.gd`
  Owns shared modal / debug overlay gates: runtime perk choice and feedback,
  F4 runtime-perk picker open state, F3 passive / mythic management menu,
  F6 weather debug picker, TAB character-info overlay, active-item debug
  spawn menu, physics blocking, and mobile-control blocking. Frame, input, and mobile-touch controllers
  use this module so pause / overlay predicates stay consistent while each
  controller still owns update, input handling, and drawing order.
- `scripts/core/battle_scene_intro_input_controller.gd`
  Owns battle-scene intro input after boot / warmup routing: stage-landing
  skip / advance input, ball-spawn intro input, landing-to-ball-spawn
  handoff callbacks, redraw requests, and viewport handled marking. The
  input controller delegates this ladder before overlay / debug input so
  intro phases keep their exclusive input priority.
- `scripts/core/battle_debug_menu_shortcut_router.gd`
  Owns pressed/non-echo logical and physical key matching plus the F1-F7/F9
  key-to-menu mapping and switcher handoff. F8 remains the overlay
  controller's separate perk-point grant and F10 remains the exhibition-reset
  autoload key. The overlay controller retains public key aliases only for
  compatibility and does not dispatch direct debug switches.
- `scripts/core/battle_debug_menu_switcher.gd`
  Owns the F1-F7/F9 debug-menu catalog and direct-switch lifecycle: selected
  open-state lookup, normal-overlay closure, close-all and same-key-close
  policy, menu-specific prewarm-before-open, active-item / mythic / ball-speed
  close fallbacks, redraw, and handled-input marking. It receives owner/module
  access per call and does not retain live runtime references. Menu-local state,
  input, and drawing remain with each picker/runtime; modal predicates remain
  in `battle_scene_modal_gate_controller.gd`.
- `scripts/core/battle_debug_menu_input_router.gd`
  Owns open-menu input delivery for character, weather, stage, Lingpet,
  mythic-management, and runtime-perk debug surfaces. An open menu consumes
  the event even when its local handler returns false; redraw and viewport-
  handled marking happen only for a true handler result. It receives all live
  references per call and retains none.
- `scripts/core/battle_active_item_debug_input_router.gd`
  Owns F2 active-item debug-grid event delivery after higher-priority overlay
  routes: current full-event dispatch, legacy left-click compatibility,
  viewport-size forwarding, and redraw/handled marking for true results. It
  does not own active-slot input edges, catalog entries, item effects, or
  acquisition state, and retains no live reference.
- `scripts/core/battle_lingpet_priority_input_router.gd`
  Owns the highest-priority acquisition-cutin and collection-full overflow
  input routes. Acquisition dismissal outranks overflow choice, both active
  modals swallow every event, and redraw/handled marking occurs only after a
  successful local action. The router resolves the overflow host cache-first,
  receives all live references per call, and retains none; modal predicates,
  Lingpet state, and overflow rendering remain with their focused owners.
- `scripts/core/battle_lingpet_interaction_input_router.gd`
  Owns the top-level Guardian Spirit shell-break/acquisition guard and the later
  companion click, E/RT interaction, and L/Shift+L slot-cycle route. It
  preserves the two original ladder positions, click/interact/cycle priority,
  screen-to-playfield conversion, module-first registry fallback, RT edge
  latching, and success-only redraw/handled marking. Runtime state, reaction
  effects, overlay-local cut-in/overflow input, rendering, and modal physics
  remain with their existing owners.
- `scripts/core/battle_terminal_screen_input_router.gd`
  Owns the chance-gem continue, defeat settlement, and stage-clear result input
  ladder in that order, including chance-gem refusal fallthrough, viewport-size
  forwarding, active-screen consumption/redraw, and stage-clear runtime-perk
  overlay forwarding. It retains no live reference; screen state/navigation,
  rewards/effects/rendering, and runtime-perk state remain with their existing
  owners.
- `scripts/core/battle_reward_modal_input_router.gd`
  Owns mythic acquisition, Pandora Legacy selection, and Angel Blessing modal
  input in that order after the general runtime-perk choice route. It preserves
  each handler signature, live viewport forwarding, active-modal consumption,
  redraw, and handled marking while retaining no live reference. Reward state,
  grants, effects, rendering, audio, and modal physics remain with their
  existing owners.
- `scripts/core/battle_combat_shortcut_input_router.gd`
  Owns the post-overlay skill-tooltip-cycle then Commando-firearm-switch input
  pair, including gamepad Back, arrow-space Shift aliases, grip normalization,
  tooltip refusal fallthrough, focused driver/reader fanout, and success-only
  redraw/handled marking. Tooltip UI/state and Commando weapon gameplay remain
  with their existing owners.
- `scripts/core/battle_system_shortcut_input_router.gd`
  Owns top-priority F11 fullscreen, B-key BGM, right-stick suppression, and the
  stateful 450ms synthetic-wheel suppression deadline. It preserves fullscreen
  window/redraw forwarding, BGM's no-shell-redraw policy, and normal-wheel
  fallthrough while retaining no owner/module reference.
- `scripts/core/battle_pre_intro_stage_input_router.gd`
  Owns the post-loading/pre-readiness stage input rung: F9 debug force-clear
  before Stage 7 Akamu prebattle video input. It preserves battle/landing gates,
  5:0 score and scoreboard/result handoff, completion callbacks, active-result
  repeat-F9 behavior, module-first presentation fallback, and success-only
  Stage 7 redraw. Score/result and video runtime state remain with their owners.
- `scripts/core/battle_guided_overlay_input_router.gd`
  Owns the fixed grip-selection-before-skill-tooltip-tutorial input priority,
  active-modal consumption, local handler delivery, and success-only redraw /
  handled-input marking. It retains no live reference; overlay state, local
  input rules, drawing, modal predicates, and physics blocking remain with the
  existing HUD and modal-gate owners.
- `scripts/core/battle_character_info_input_router.gd`
  Owns battle TAB character-info input and open policy: active-event delivery,
  redraw-request throttling, overlay-frame redraw forwarding, pause closure,
  equipped-slot Guardian Spirit prewarm filtering, current viewport size, and
  modern/legacy `open` signature compatibility. The pause-menu character-info
  action reuses its prewarm/open entry; overlay state and local input remain in
  `character_info_overlay.gd`, and modal predicates remain in the modal gate.
- `scripts/core/battle_pause_menu_input_router.gd`
  Owns active pause-menu event consumption, dictionary/boolean result parsing,
  character-info / continue / exit action dispatch, ESC and gamepad Start open
  shortcuts, debug-menu close-all before open, redraw requests, and handled-
  input marking. It reuses the character-info router, debug-menu switcher, and
  match-flow driver while retaining no live runtime reference; pause overlay
  state/rendering and modal predicates remain with their existing owners.
- `scripts/core/battle_elixir_cinematic_input_router.gd`
  Owns active Elixir of Mastery cinematic consumption, Space/Enter, left-mouse,
  and shared gamepad confirm recognition, runtime confirm handoff, plus
  success-only redraw and handled-input marking. It retains no live reference;
  cinematic state/effects/drawing remain in active-item owners and the active
  predicate remains in the modal gate.
- `scripts/core/battle_runtime_perk_input_router.gd`
  Owns active runtime-perk choice event delivery/consumption and the later F8
  debug starpoint shortcut/callback, including logical/physical key edges,
  success-only choice redraw, and debug-grant redraw/handled marking. It
  retains no live reference; choice data, application, UI, persistence, and
  effective-level behavior remain with the runtime perk owners.
- `scripts/core/battle_scene_overlay_input_controller.gd`
  Owns battle-scene overlay input priority after intro / warmup routing and
  switch-key priority for F1-F7/F9, runtime perk choice, TAB placement,
  F8 perk-point grants, specialized F2 active-item clicks, and pause. It
  delegates the first acquisition/overflow modal rung to
  `battle_lingpet_priority_input_router.gd`, the next grip/tutorial rungs to
  `battle_guided_overlay_input_router.gd`,
  delegates F1-F7/F9 key mapping to `battle_debug_menu_shortcut_router.gd`,
  direct debug-menu switch/close/prewarm policy to
  `battle_debug_menu_switcher.gd`, and six-menu local event delivery to
  `battle_debug_menu_input_router.gd`, then delegates the final F2 grid/click
  path to `battle_active_item_debug_input_router.gd`. Active character-info
  input and TAB open delegate to `battle_character_info_input_router.gd`;
  active pause input, shortcut opening, debug cleanup, and pause actions
  delegate to `battle_pause_menu_input_router.gd`, while Elixir cinematic input
  delegates to `battle_elixir_cinematic_input_router.gd`. Active runtime-perk
  choice input and the later F8 grant delegate to
  `battle_runtime_perk_input_router.gd`. The
  top-level input controller enters this ladder after fullscreen, mobile touch,
  and intro-skip handling.
- `scripts/core/stage_debug_picker.gd`
  Owns the F5 debug stage picker overlay for stages 1-10,
  4천왕(11), and 진엔딩(12). It applies `current_stage` immediately,
  syncs `GameSelectionState`, resets the lightweight battle runtime, and
  lets not-yet-ported stages continue through the current stage-router
  fallback.
- `scripts/core/weather_debug_picker.gd`
  Owns the F6 debug weather picker overlay: modal open / close state,
  Korean weather-card layout, hover / click / keyboard selection, the
  clear-weather option, and selection handoff to
  `battle_scene_weather_update_driver.debug_force_weather_event()`.
- `scripts/core/battle_scene_intro_frame_controller.gd`
  Owns battle-scene boot / intro frame phases: penguin-logo idle and draw,
  logo-time prewarm, boot warmup stepping, battle initialization handoff,
  stage-landing update / draw, ball-spawn update, and ball-spawn overlay
  draw. The frame controller calls this module first, then continues into
  modal, scoreboard, and normal battle drawing only when intro phases no
  longer consume the frame.
- `scripts/core/battle_loading_screen_renderer.gd`
  Owns the visible battle-entry loading screen shown after character
  selection while boot warmup, battle initialization, and stage-intro
  readiness gates are still blocking the first playable frame. The same
  renderer is reused for stage-clear-to-next-stage loading gates, where the
  match-event driver supplies transition progress / status text. The intro
  frame controller delegates this draw instead of painting a plain black
  fallback, while the warmup controller owns progress / status text for
  initial battle entry.
  Stages 1 and 2 route to `battle_loading_stained_glass_host.gd` and reveal
  a full-color stained-glass PNG through one baked grayscale mask, clamping
  the final reveal until loading completion so the transition does not snap.
- `scripts/core/battle_loading_stained_glass_host.gd`
  Owns the node-backed stained-glass loading presentation for supported
  stages:
  fullscreen art layout, shader-driven grayscale-to-color reveal, black
  lead-line preservation, completion flash, and Korean status / percent UI.
- `scripts/core/battle_scene_overlay_frame_controller.gd`
  Owns battle-scene overlay frame phases after intro / base battle drawing:
  runtime perk choice / feedback idle updates, runtime perk debug picker
  idle / draw, F5 debug stage picker draw, F6 weather picker draw,
  passive / mythic management menu draw, character-info idle / draw, active-item debug spawn menu
  draw, and non-modal F9 ball-speed
  debug overlay redraw / draw. The frame controller calls
  this module after the normal battle scene and mobile touch controls are
  drawn.
- `scripts/core/battle_boot_warmup_controller.gd`
  Owns boot warmup step execution: logo asset prewarm, calls into
  `battle_boot_resource_prewarm_controller.gd`, startup / item / update /
  ball / draw module group instantiation from
  `battle_boot_warmup_plan.gd`, and the final deferred battle
  initialization step. The battle shell only asks this controller to
  advance warmup and checks whether it has finished before allowing input,
  physics, and final battle drawing.
- `scripts/core/battle_boot_warmup_plan.gd`
  Owns the boot warmup module-group plan used by the warmup controller:
  startup, item runtime, update runtime, ball runtime, and draw runtime
  module keys. Keeping these lists out of the step executor makes future
  port slices easier to audit without changing warmup control flow.
- `scripts/core/battle_boot_resource_prewarm_controller.gd`
  Owns boot-time resource prewarm state and resource/audio actions: battle
  texture groups, resource-cache finalization, staged audio setup, BGM
  priming, Stage 1 pillar background prewarm, stage-intro asset prewarm,
  and Stage 1 runtime asset prewarm. The warmup controller keeps a public
  `prewarm_battle_resources()` wrapper for compatibility and delegates the
  actual work here.
- `scripts/core/battle_mobile_touch_controller.gd`
  Owns battle-scene mobile touch routing: active-item HUD slot hit testing,
  mobile active-slot use, touch-control enable / disable sync, mobile touch
  layout context construction from the shared view-layout and scene-config
  modules, and final touch-control drawing. The battle shell passes only
  the scene-ready gate and module getter, while modal blocking is delegated
  to the battle scene modal-gate controller.
- `scripts/core/battle_scene_input_controller.gd`
  Owns battle-scene top-level unhandled-input routing: fullscreen toggle,
  mobile touch handoff, and boot / warmup gating. After those gates, it
  delegates intro input to `battle_scene_intro_input_controller.gd`, Guardian
  Spirit cut-in/companion input to
  `battle_lingpet_interaction_input_router.gd`, top-level system shortcuts to
  `battle_system_shortcut_input_router.gd`, pre-intro F9/Stage 7 input to
  `battle_pre_intro_stage_input_router.gd`, and the overlay / debug
  keybinding ladder to `battle_scene_overlay_input_controller.gd`. Terminal
  result-screen priority delegates to `battle_terminal_screen_input_router.gd`.
  Mythic/Pandora/Angel reward-modal priority delegates to
  `battle_reward_modal_input_router.gd`. Desktop active-item HUD input remains
  immediately before the later companion route, followed by combat shortcuts
  delegated to `battle_combat_shortcut_input_router.gd`. The battle shell passes
  current boot / intro readiness plus callbacks instead of owning those focused
  policies directly.
- `scripts/core/battle_drive_cutin_presenter.gd`
  Owns Drive-over-Shield cut-in priority, modal suppression, immediate draw
  dispatch, shared particle-host lifecycle, FX state projection, reusable sync
  payload, and cut-in BattlePerf samples. The frame controller keeps only draw
  ordering and a narrow compatibility facade.
- `scripts/core/battle_skill_cutin_presenter.gd`
  Owns Smasher-before-Viper full-screen skill cut-in selection, modal
  suppression, cached host lookup, draw dispatch, and its BattlePerf sample.
  It retains no state/runtime/host reference and avoids a per-draw route Array;
  the frame controller keeps only final ordering and a narrow facade.
- `scripts/core/battle_lingpet_overlay_presenter.gd`
  Owns the common cached-first registry lookup, normal-instantiation fallback,
  route-active gate, host draw dispatch, and BattlePerf sampling for Lingpet
  acquire-cut-in and overflow-choice overlays. It retains no runtime or host
  reference; the frame controller keeps the two route facades, keys, labels,
  and final draw ordering.
- `scripts/core/battle_lingpet_ungated_idle_coordinator.gd`
  Owns shell-break-before-acquire-before-overflow idle priority while modal
  physics is paused, exact advance signatures, and redraw requests. It retains
  no runtime/frame reference; the frame controller keeps group placement, total
  sample closure, and a static source-wiring compatibility method catalog.
- `scripts/core/battle_tutorial_idle_coordinator.gd`
  Owns the seven tutorial/practice idle update routes, their fixed order,
  signature differences, redraw requests, and BattlePerf labels. It retains no
  owner, registry, module-getter, hint, or performance-logger reference and adds
  no per-frame route collection.
- `scripts/core/battle_tutorial_draw_coordinator.gd`
  Owns the seven tutorial/practice draw routes, their fixed display order,
  owner-only versus registry-aware signature difference, and BattlePerf labels.
  It retains no draw-context or hint reference and adds no per-frame route
  collection. The frame controller keeps only group placement and a static
  source-wiring compatibility key catalog.
- `scripts/core/battle_terminal_overlay_idle_coordinator.gd`
  Owns stage-clear result, defeat continue, and defeat settlement idle priority,
  the result-owned runtime-perk single tick, nonblocking-continue fallthrough,
  redraw requests, and four BattlePerf samples. It retains no frame/runtime
  reference; the frame controller keeps group placement and total-sample exit.
- `scripts/core/battle_terminal_overlay_draw_presenter.gd`
  Owns early result-screen dispatch plus late defeat continue-before-settlement
  dispatch and their BattlePerf labels. It retains no draw context or screen
  reference; the frame controller keeps the two placements around normal battle
  and Lingpet overlays.
- `scripts/core/battle_spawn_overlay_draw_coordinator.gd`
  Owns normal battle draw, ball-spawn overlay hook, conditional pillar-overlay
  restoration, and their three BattlePerf samples. It retains no draw/runtime
  reference and does not own the intro FX host or full-playfield clip; the frame
  controller keeps only this group's placement before mobile controls.
- `scripts/core/battle_stage_transition_frame_coordinator.gd`
  Owns first-priority stage-transition idle update/redraw and draw dispatch,
  including the black fallback and three BattlePerf samples. It retains no
  driver/runtime reference; transition state, staged work, artwork, and final
  ball-spawn replay remain in the match-event driver.
- `scripts/core/battle_physics_gate_coordinator.gd`
  Owns the ordered physics gate ladder from logo readiness through modal block,
  per-gate BattlePerf labels, the grip zero-delta/redraw probe, and modal pause
  enter/leave symmetry. It retains no frame/runtime reference; the frame
  controller keeps total/update-driver timing and a direct-test grip facade.
- `scripts/core/battle_grip_selection_frame_coordinator.gd`
  Owns grip-selection idle update/redraw/active blocking plus active draw
  dispatch and both BattlePerf samples. It retains no overlay/runtime reference;
  physics gating, input, and selection/render state remain in their existing
  focused owners.
- `scripts/core/battle_result_prewarm_frame_coordinator.gd`
  Owns result-prewarm idle scheduling: visible-scoreboard delay, score-pause
  safety gate, pending reset and custom win-goal checks, active result-screen
  exclusion, work gates, and result/stage-clear BattlePerf samples. It retains no
  owner or module references; the resource worker and staged boot prewarm remain
  in their existing owners.
- `scripts/core/battle_modal_pause_runtime_state.gd`
  Owns the physics-blocking modal interval's active-item cooldown pause latch and
  per-blocked-tick gameplay-loop audio cleanup. It receives owner, registry, and
  module getter only for the current call and retains no runtime references.
  `battle_scene_frame_controller.gd` keeps the gate ordering and delegates modal
  block entry/exit to this composed state.
- `scripts/core/battle_scene_frame_controller.gd`
  Owns battle-scene shell frame routing for idle process, physics process,
  and final draw: intro-frame delegation, overlay-frame delegation,
  scoreboard visual idle updates, normal battle-scene draw, and final
  draw priority. It records draw pass samples but does not print BattlePerf
  logs inside `draw.frame.total`; the battle shell handles that after the
  shell sample closes. The battle shell keeps
  only callbacks for initialization, intro starts, battle draw, mobile
  controls, and current flow flags; modal open-state predicates are delegated
  to the battle scene modal-gate controller, while boot / logo / landing /
  ball-spawn frame phases are delegated to the intro-frame controller, overlay
  idle / draw phases are delegated to the overlay-frame controller, modal
  cooldown/audio pause lifetime is delegated to
  `battle_modal_pause_runtime_state.gd`, result-prewarm scoreboard scheduling is
  delegated to `battle_result_prewarm_frame_coordinator.gd`, tutorial / practice
  idle fanout is delegated to `battle_tutorial_idle_coordinator.gd`, tutorial /
  practice draw fanout is delegated to `battle_tutorial_draw_coordinator.gd`,
  terminal result/defeat idle routing is delegated to
  `battle_terminal_overlay_idle_coordinator.gd`,
  terminal result/defeat drawing is delegated at two ordered points to
  `battle_terminal_overlay_draw_presenter.gd`,
  normal battle / ball-spawn / conditional pillar restoration drawing is
  delegated to `battle_spawn_overlay_draw_coordinator.gd`,
  first-priority stage-transition idle/draw work is delegated to
  `battle_stage_transition_frame_coordinator.gd`,
  the ordered pre-update physics gate ladder is delegated to
  `battle_physics_gate_coordinator.gd`,
  grip-selection idle and draw frame work is delegated to
  `battle_grip_selection_frame_coordinator.gd`,
  full-screen skill cut-in selection/draw is delegated to
  `battle_skill_cutin_presenter.gd`, and Drive/Shield cut-in draw plus FX-host
  lifecycle is delegated to
  `battle_drive_cutin_presenter.gd`. Lingpet acquire-cut-in and overflow-choice
  runtime/host resolution plus draw dispatch is delegated to
  `battle_lingpet_overlay_presenter.gd`. Lingpet shell-break/acquire/overflow
  ungated idle branching is delegated to
  `battle_lingpet_ungated_idle_coordinator.gd`.
- `scripts/core/penguin_logo_intro.gd`
  Owns the Godot startup penguin-logo screen port: full-screen black intro
  draw, Python-parity bootstrap red-disc pre-roll, wave-sheet frame
  selection, PFStardust-first studio-text reveal / tracking / glint timing,
  logo sound playback, and the short battle-bootstrap gate that keeps Stage
  BGM / gameplay startup behind the logo just like the Python startup path.
- `scripts/core/stage_landing_intro.gd`
  Owns the Godot stage-entry landing zoom port that runs after battle
  bootstrap and before gameplay physics: generated landing-background load,
  camera zoom, scaled playfield preview, stage / scan overlays, final shake,
  skip input handling, and serve-input edge synchronization so a skipped
  intro does not immediately fire the opening serve.
- `scripts/core/stage_ball_spawn_intro.gd`
  Owns the post-landing opening ball-spawn animation. It preserves the
  Python original's three phases, compressed from 8 seconds to 4 seconds:
  energy condensation, ball formation / levitation, and movement to the
  current server's launch position. The module pauses round serve waiting
  while active, writes only the temporary visible ball position to the battle
  owner, and restores serve waiting with synced input edges on completion.
  Public draw-frame guard, layout resolution, FX-host layout sync, and the
  game-space canvas transform bracket are delegated to
  `stage_ball_spawn_intro_draw_lifecycle.gd`; the intro module still owns
  spawn-layer draw ordering.
  Atmosphere drawing is delegated to
  `stage_ball_spawn_intro_atmosphere_renderer.gd`: haze clouds, starfield,
  god rays, and aurora fog. Pure ball phase / position / alpha / scale
  composition is delegated to
  `stage_ball_spawn_intro_ball_state.gd` so the large VFX module does not
  also own the state resolver math. Ball-specific drawing is delegated to
  `stage_ball_spawn_intro_ball_renderer.gd`: landing shockwave, Phase 3
  trail ghosts, the energy ball body, and the phase flash overlay. One-time
  glow / ball texture baking plus the baked ball-body shard source is
  delegated to `stage_ball_spawn_intro_texture_cache.gd` so the particle-
  heavy intro module can reuse cached surfaces without owning the bake
  implementation. Node-backed visual flourishes
  (Phase 1 shader vortex / inflow particles, Phase 2-3 shader core,
  GPUParticles2D, Tween-driven scalar accents, and texture-shard
  convergence) are delegated to
  `stage_ball_spawn_intro_fx_host.gd`; the intro module keeps the logical
  ball position. Phase 1 energy-condensation update choreography is
  delegated to `stage_ball_spawn_intro_phase_1_updater.gd`, and Phase 2
  ball-formation / levitation update choreography is delegated to
  `stage_ball_spawn_intro_phase_2_updater.gd`. Phase 3 launch movement and
  cleanup choreography is delegated to
  `stage_ball_spawn_intro_phase_3_updater.gd`. Per-frame active / elapsed /
  phase-dispatch update and post-update ball-snapshot sync are delegated to
  `stage_ball_spawn_intro_update_lifecycle.gd`. Begin-time stage
  eligibility, prewarm, serve-side capture, seed / target / start-position
  setup, initial reset / spawn / FX attachment, start ball-snapshot publish,
  and serve-wait pause are delegated to
  `stage_ball_spawn_intro_begin_lifecycle.gd`. FX host attachment, state /
  layout sync, and teardown are delegated to
  `stage_ball_spawn_intro_fx_lifecycle.gd`. Particle / lightning / ring /
  spark dictionary creation is delegated to
  `stage_ball_spawn_intro_effect_factory.gd`; the intro module keeps draw
  ordering. Particle /
  lightning / ring / spark drawing is delegated to
  `stage_ball_spawn_intro_effect_renderer.gd`. Per-entity dictionary
  updates and lifetime pruning are delegated to
  `stage_ball_spawn_intro_effect_updater.gd`.
- `scripts/core/stage_ball_spawn_intro_atmosphere_renderer.gd`
  Owns the opening ball-spawn intro's background atmosphere CanvasItem
  drawing: drifting haze clouds, twinkling starfield dots, volumetric god
  rays, and the aurora fog wash. The intro module keeps atmosphere entity
  state and draw ordering while passing timing, dimensions, and cached
  textures into this renderer.
- `scripts/core/stage_ball_spawn_intro_ball_state.gd`
  Owns the opening ball-spawn intro's pure ball-state resolver: current
  phase lookup, phase progress, Phase 2 levitation / scale easing, and
  Phase 3 movement arc toward the serve target. It has no mutable VFX state
  and is intentionally kept separate from the particle-heavy intro module.
- `scripts/core/stage_ball_spawn_intro_ball_renderer.gd`
  Owns the opening ball-spawn intro's ball-specific CanvasItem drawing:
  landing shockwave, Phase 3 trail ghosts, layered energy-ball body, and
  phase flash overlay. The intro module still owns draw ordering and passes
  cached textures / timing data into this renderer.
- `scripts/core/stage_ball_spawn_intro_draw_lifecycle.gd`
  Owns the opening ball-spawn intro's public draw-frame lifecycle: active
  / null guards, layout lookup, FX-host layout sync, game-space canvas
  transform setup, intro draw dispatch, and transform restore. The intro
  module keeps the public `draw()` surface and spawn-layer draw ordering.
- `scripts/core/stage_ball_spawn_intro_begin_lifecycle.gd`
  Owns the opening ball-spawn intro's begin / startup lifecycle: stage
  eligibility, texture prewarm, serve-side capture, seed / target /
  start-position setup, reset and initial spawn fanout, FX host attachment,
  start ball-snapshot publication, serve-wait pause, and serve-input edge
  sync. The broader intro lifecycle module keeps its public `begin_intro()`
  surface and delegates startup here.
- `scripts/core/stage_ball_spawn_intro_effect_factory.gd`
  Owns the opening ball-spawn intro's VFX entity dictionary factories:
  quantum particles, vortex rings, starfield dots, haze clouds, lightning
  bolts and segments, electric arcs, hologram rings, sparks, and energy rings. It receives the existing
  `RandomNumberGenerator` from the intro module so seeded visual behavior
  remains stable while factory code lives outside the large update / draw
  file.
- `scripts/core/stage_ball_spawn_intro_effect_renderer.gd`
  Owns the opening ball-spawn intro's VFX CanvasItem drawing for vortex
  rings, quantum particles, lightning bolts, electric arcs, hologram rings,
  sparks, energy rings, and the central core glow. The intro module keeps
  draw ordering and passes cached textures plus seeded flicker RNG into
  this renderer.
- `scripts/core/stage_ball_spawn_intro_effect_updater.gd`
  Owns the opening ball-spawn intro's VFX entity dictionary mutation:
  quantum particle motion / trail updates, vortex ring decay, electric arc
  and hologram noise updates, spark physics, energy-ring expansion, and
  lifetime pruning for normal entities and chain lightning collections.
- `scripts/core/stage_ball_spawn_intro_finish_lifecycle.gd`
  Owns the opening ball-spawn intro's finish / serve-resume lifecycle:
  inactive-state transition, elapsed reset, reset helper fanout, target
  ball-snapshot restore, serve-wait preparation / fallback reset, and
  serve-input edge sync. The broader intro lifecycle module keeps its
  public `finish()` surface and delegates completion here.
- `scripts/core/stage_ball_spawn_intro_initial_entity_lifecycle.gd`
  Owns the opening ball-spawn intro's initial transient VFX population:
  configured quantum particles, vortex rings, opening lightning burst,
  starfield dots, haze clouds, and initial fog color / alpha. The broader
  intro lifecycle module delegates the initial spawn surface here during
  begin-time setup and reset-safe respawn tests.
- `scripts/core/stage_ball_spawn_intro_phase_1_updater.gd`
  Owns the opening ball-spawn intro's Phase 1 energy-condensation update
  lifecycle: particle / ring ticking, lightning / chain / arc spawn
  timers, particle top-up, lifetime pruning, core glow, and aurora-fog
  color / alpha progression. The intro module keeps the public `update()`
  surface and forwards only the Phase 1 branch here.
- `scripts/core/stage_ball_spawn_intro_phase_2_updater.gd`
  Owns the opening ball-spawn intro's Phase 2 ball-formation / levitation
  update lifecycle: fading lightning spawn cadence, energy-ring and
  electric-arc timers, ball-centered ring / arc updates, lifetime pruning,
  remaining particle / vortex ticking, core glow, and levitation fog color
  / alpha progression. The intro module keeps the public `update()`
  surface and forwards only the Phase 2 branch here.
- `scripts/core/stage_ball_spawn_intro_phase_3_updater.gd`
  Owns the opening ball-spawn intro's Phase 3 launch update lifecycle:
  vortex cleanup, serve-position trail maintenance, hologram / spark / arc
  / energy-ring timers, optional trail lightning, remaining particle
  cleanup, core glow, and final launch-fog fade. The intro module keeps the
  public `update()` surface and forwards only the Phase 3 branch here.
- `scripts/core/stage_ball_spawn_intro_reset_lifecycle.gd`
  Owns the opening ball-spawn intro's reset / cleanup lifecycle: current FX
  host teardown, VFX entity array clearing, spawn-timer reset, fog alpha
  clear, and core-glow reset. The broader intro lifecycle module delegates
  reset state here during begin-time reset and finish cleanup.
- `scripts/core/stage_ball_spawn_intro_update_lifecycle.gd`
  Owns the opening ball-spawn intro's per-frame lifecycle: active guard,
  delta clamp, elapsed-time tick, finish trigger, Phase 1 / 2 / 3 update
  dispatch, post-update FX-host state sync, and visible-ball owner snapshot
  publication. The broader intro lifecycle module keeps its public
  `update_intro()` surface and delegates the frame tick here.
- `scripts/core/stage_ball_spawn_intro_lifecycle.gd`
  Owns the opening ball-spawn intro's public lifecycle facade methods for
  begin / update / spawn / finish / reset, delegating each lifecycle-sized
  body to focused helpers while preserving the surface used by
  `stage_ball_spawn_intro.gd`.
- `scripts/core/stage_ball_spawn_intro_texture_cache.gd`
  Owns one-time procedural texture baking for the opening ball-spawn intro:
  the soft glow texture used by particles / halos and the wide ball-corona
  texture used by haze clouds and the energy orb renderer. It also bakes a
  compact layered ball-body texture for FX-host shard sprites; the logic
  ball still comes from `stage_ball_spawn_intro_ball_state.gd`.
- `scripts/core/stage_ball_spawn_intro_fx_host.gd`
  Owns the node-backed ball-spawn embellishment layer: Phase 1 vortex PNG
  using the shared `WritheEmberMaterial` `ball_spawn_vortex` preset with
  legacy shader fallback, Phase 1 orbit-rings PNG using the
  `ball_spawn_orbit_rings` preset with slow rotation / breathing tweens,
  inflow GPUParticles2D, Phase 2-3 ShaderMaterial core quad, condensation /
  launch GPUParticles2D emitters, Phase 3 ray-burst PNG one-shot over the
  older procedural 12-ray accents, Tween-driven shader / burst / shard
  scalar values, and AtlasTexture shard sprites cut from the cached
  ball-body texture. The intro module attaches, syncs, stage-tints, and
  tears down the host while retaining the authoritative logical ball
  position and serve flow.
- `scripts/core/stage_ball_spawn_intro_fx_lifecycle.gd`
  Owns the opening ball-spawn intro's node-backed FX host lifecycle:
  replacing any prior host, attaching the host node to the scene owner,
  forwarding begin parameters, syncing logical ball state / viewport layout,
  and requesting teardown with host self-cleanup. The intro module keeps
  the public intro API and stores only the current host reference.
- `scripts/core/game_selection_state.gd`
  Owns the small top-level character-selection handoff state for the Godot
  port: source character id, runtime character id, display name, starting
  stage id, selected Champion / Mythic league mode, and the one-shot
  battle-logo skip flag. It is registered as an autoload and deliberately
  stores only flow-level selection data, not character gameplay behavior.
- `scripts/ui/character_select_data.gd`
  Owns the compact Godot character-select roster copied from the Python
  screen: unlocked Smasher / Commando / Baltor / Optimus / Viper entries,
  stat summaries, descriptions, runtime-id mapping, card-art paths, and
  future Live2D-style layer path conventions.
  Visible roster role copy is localized in Korean, while Commando keeps
  `id` / `runtime_id` as `soldier` for runtime routing.
- `scripts/ui/character_select_prewarm.gd`
  Owns the boot-time character-select preload queue used between the logo
  and character-select scene. It loads the character-select scene plus each
  unlocked character's card / still image and primary Live2D preview sheet
  into `ProjectResourceLoader`'s shared texture cache so card clicks do not
  trigger large per-character PNG loads. Its cancel-and-drain terminal path
  claims the current threaded request before a boot/menu owner is destroyed,
  clears queued work, and releases the retained PackedScene.
- `scripts/ui/character_live_preview.gd`
  Owns the animated top preview for the character-select scene: texture/cache
  loading, first-use alpha-trim scheduling, animation and one-shot state,
  VFX-host lifecycle, and CanvasItem drawing. It delegates trim/projection math
  to `character_live_preview_sheet_geometry.gd`.
- `scripts/ui/character_live_preview_sheet_geometry.gd`
  Owns draw-free LivePreview sheet geometry: explicit trim metadata parsing,
  bounded sampled alpha bounds, normalized source mapping, source-to-target
  projection, aspect fit, bottom-anchored stage Y scale, and centered scale.
- `scripts/ui/character_select_screen.gd`
  Owns the Godot character-select scene orchestration: scene-tree lifecycle,
  CanvasItem drawing, texture lookup, input/selection routing, live-preview and
  flash-overlay sync, compatibility facades, and handoff to `main.tscn`.
  Focused owners provide layout, confirm state, skill-preview resolution,
  motion config, and audio lifecycle.
- `scripts/ui/character_select_layout.gd`
  Owns draw-free responsive character-select geometry, card/action/info-panel
  layout, text wrapping, badge sizing, and lore microstat row projection.
- `scripts/ui/character_select_confirm_intro_state.gd`
  Owns confirm-intro logical state: selected-character snapshot, elapsed/hold
  clocks, pending scene path, exit-flash action edge, and flash payload values.
- `scripts/ui/character_select_skill_preview_resolver.gd`
  Owns character runtime-id normalization, skill-config cache selection,
  representative icon skill-id inference, tooltip data lookup, colors, and
  cost/cooldown number formatting.
- `scripts/audio/character_select_audio_controller.gd`
  Owns character-select BGM/click/confirm players, mute/manual-loop state,
  delayed voice playback, stream release, and player teardown. The screen
  retains only input routing and compatibility property reads.
- `scripts/characters/optimus_energy_state.gd`
  Owns the initial Godot Optimus / Io core battery mechanic: full starting
  battery, per-second drain, gauge-ratio paddle shrink, movement-speed
  multiplier, owner paddle scale snapshot, and reset-time reinitialization.
  Optimus perks, charge skills, arm skills, and dedicated HUD/VFX remain
  separate future modules.
- `scripts/characters/optimus_player_controller.gd`
  Owns the thin Optimus player-control overlay. It reuses the shared
  Smasher movement / dash controller, disables Smasher-only skill deps
  through the character routing layer, and merges the Optimus energy
  state's scale / gauge result back into the owner result.
- `scripts/characters/player_skill_lock_input_proxy.gd`
  Owns the shared transformed-form input gate for player-control deps. It
  preserves horizontal movement from the source input reader while clearing
  original character skill inputs such as up/down/action, Viper jetpack,
  Commando supply hold, firearm reset, and power-smash direction whenever
  the mythic transform runtime reports skill or control lock.
- `scripts/characters/player_customization_overlay_renderer.gd`
  Owns the first Godot in-game character customization render path. V1 is
  Smasher-only: it builds pose-locked overlay draw commands for the
  documented `back`, `outfit_accent`, `head_hat`, `accessory`, and `paddle`
  slots, reuses the base sheet `frame_index`, and lets Stage 1 draw back
  overlays before the base sprite and front overlays after it. Missing
  overlay sheets intentionally skip cleanly while real assets are pending.
- `scripts/items/horn_strawberry_command_listener.gd`
  Owns the shared A/D edge-sequence detector for Horn Strawberry Mask:
  command buffer, 2-second timeout, input-edge tracking, and completion
  reporting independent from any one character input reader.
- `scripts/items/mythic_item_horn_strawberry_mask_state.gd`
  Owns Horn Strawberry Mask's Godot transform state machine for the first
  port slice: IDLE, transform event, transformed, detransform event,
  one-use-per-stage tracking, rolled duration, and base transformed stat
  exposure. Skill-specific state remains future item modules.
- `scripts/items/mythic_item_horn_strawberry_mask_runtime.gd`
  Owns Horn Strawberry Mask's mythic-runtime facade: equipment sync,
  command polling through character input readers, gauge spend, transform
  lifecycle updates, Viper jetpack landing on the finalize edge, paddle
  growth sync, owner snapshot context, and round-vs-stage reset delegation
  through `mythic_item_runtime.gd`.
- `scripts/items/horn_strawberry_eat_state.gd`
  Owns Horn Strawberry Mask's 딸기먹기 skill state: raw action activation,
  50-gauge spend, 0.8s eating timer, +20% paddle-growth request, deterministic
  3-shot stem burst, projectile lifetime, boss stun / knockback application,
  and lightweight draw context.
- `scripts/items/horn_strawberry_field_state.gd`
  Owns Horn Strawberry Mask's 딸기장판 skill state: S-hold gauge drain,
  1-second hold completion, paddle-bottom anchored 120x12 barrier placement
  (Python live BoneBarrier core parity; the module-level 180x12 constant was
  dead code), 3.0s build with build-phase hit destruction (no reflect),
  seeded berry-surface visual points, build / death timers, dual-lane
  cooldown tick (2x while transformed — Python live-runtime parity, felt
  cooldown ~5s), lingering post-transform collision context, and barrier
  consumption after a ball reflection (vy reflect ×1.05 + vx hit-offset
  nudge ×0.03).
- `scripts/items/horn_strawberry_horn_charge_state.gd`
  Owns Horn Strawberry Mask's W horn-charge skill state: 300-gauge activation,
  20-second cooldown, live-tracking charge (t^2 ease) / impact / quadratic
  return phases ending immediately after the return (Python kills the STUN
  window; ~1.13s active), active control locking during charge / impact,
  direct boss stun / strong knockback with 50:50 random push direction
  (Python main-game parity), same-frame paddle-hit knockback suppression,
  Python-parity impact screen shake, and lightweight charge trail draw
  context.
- `scripts/items/horn_strawberry_bomb_state.gd`
  Owns Horn Strawberry Mask's A+D hold bomb skill state: 0.5-second dual-input
  hold, 400-gauge spend, 30 deterministic hopping bombs over 1 second
  (+/-25px sweep spawn spread), boss-bottom-edge detonation line, boss
  stun / knockback on explosion, 5-second paint splatter slow, 30-second
  cooldown armed only at bomb exhaustion (Python: 투척 완료 + 모든 폭탄
  소진; `cooldown_pending` gates recast and the HUD ready read), and
  lingering bomb / paint cleanup.
- `scripts/items/mythic_item_audio_router.gd`
  Owns mythic / passive item cue routing and fallback order, including
  Ragnarok / Poseidon loop-handle caching, Horn Strawberry skill cues
  including eat-loop stop, field break / build-break cues, and intentional
  no-extra-cue horn-impact / bomb-explosion routing, and the
  shared screen-shake feedback helpers used by mythic item runtime helpers.
  `mythic_item_runtime.gd` should call this owner or let focused helpers call
  it directly instead of reintroducing one-line `_play_*` bridge methods.
- `scripts/items/mythic_item_gauge_feedback.gd`
  Owns shared mythic / passive item gauge feedback routing: battle gauge flash
  lookup from deps or registry, and orb-HUD gauge-spin triggering for item
  helpers that grant or spend special gauge. `mythic_item_runtime.gd` should
  not reintroduce one-line `_trigger_gauge_feedback` /
  `_trigger_orb_gauge_spin` bridge methods.
- `scripts/items/mythic_item_owner_syncer.gd`
  Owns mythic runtime owner synchronization details: runtime-perk state ref
  sync, active-item paddle scale lookup, owner X clamping, skill cooldown
  config sync, removed-skill cleanup, dash-token capacity sync, player status
  resistance sync, Gold Digger runtime-perk sync, item perk-level bonus sync,
  Fuel Pouch gauge max sync, Boomerang active-slot visual sync, transient
  owner-state sync, Bulk-Up paddle-scale sync, and shared player / boss center
  reads used by Poseidon Trident and Baal's Boots. The runtime facade may keep
  high-level context-supplying sync entry points, but should not reintroduce
  one-line private bridges for these detail methods or owner-geometry reads;
  focused helpers should call this owner directly when they need those
  behaviors.
- `scripts/items/mythic_item_stat_bonus_runtime.gd`
  Owns aggregate player stat composition for mythic / passive items. Player
  speed composition should pass Baal's Boots constants directly to
  `scripts/items/mythic_item_baal_boots_runtime.gd` instead of reintroducing
  a private runtime Baal speed getter bridge.
- `scripts/items/mythic_item_lifecycle_runtime.gd`,
  `scripts/items/mythic_item_equipment_facade.gd`, and
  `scripts/items/mythic_item_roll_editor_runtime.gd`
  Own Baal's Boots clear / round-clear / weather-arm call sites for reset,
  equip / unequip / remove, and roll-adjustment flows. Pass
  `BAAL_BOOTS_CONSTANTS` into these helpers and call
  `scripts/items/mythic_item_baal_boots_runtime.gd` directly; do not
  reintroduce private runtime Baal clear / arm bridge methods.
- `scripts/items/mythic_item_stage_immunity.gd`
  Owns mythic item Stage 2 speed-defense status-immunity queries. Ragnarok
  Hammer and Shrapnel Armor should call this owner directly for boss /
  context immunity checks instead of reintroducing private runtime stage-
  immunity bridge methods.
- `scripts/items/mythic_item_equipment_index.gd`
  Owns mythic inventory / equipped-item index lookup, public equipped-state
  checks, equipped-item rebuilds, equipment slot canonicalization, slot
  resolution, single-equipment checks, and accessory-slot enablement.
  Equipment, debug, ownership, Revival consume, and owner-sync helpers
  should call this owner directly instead of
  reintroducing private runtime equipment-index bridge methods.
- `scripts/items/mythic_item_pickup_bonus.gd`
  Owns acquisition-side pickup bonuses such as Reinforced Boomerang
  Gauntlet's immediate Boomerang grant. Equipment flow should call this owner
  directly for bonus-item building and active-slot-controller lookup instead
  of reintroducing private runtime pickup-bonus bridge methods.
- `scripts/items/mythic_item_roll_query.gd`
  Owns acquired quality identity preservation and roll-option lookup used by
  equipment and debug flows, plus polish multiplier lookup for final item-roll
  value composition. Those helpers should call this owner directly instead of
  reintroducing private runtime roll-metadata or polish bridge methods.
- `scripts/items/mythic_item_update_runtime.gd`
  Owns mythic per-frame update sequencing and idle-update fallback routing.
  It calls constants-free focused update owners directly for Smartphone,
  Kick Charger, Soul Burst, Foul Whistle, Revival Charm, Danger Sensor Belt,
  Venom Mist Gauntlet, Rainbow Fur Glove, Celestial Armor, Hermes Shoes,
  Shrapnel Armor, and Horn Strawberry Mask. Do not reintroduce
  private runtime `_update_*` bridges for those paths. It also calls
  `mythic_item_update_gate.gd`
  directly for runtime-work detection and `mythic_item_poseidon_runtime.gd`
  directly for the idle Poseidon poll; do not reintroduce private runtime
  update-gate or idle-poll bridge methods. Ragnarok, Poseidon, and Baal's
  Boots update constants should be passed explicitly into this sequencer so
  it can call those focused owners directly; do not
  reintroduce private runtime update wrappers just to bind constant
  dictionaries.
- `scripts/items/mythic_item_field_effect_visibility.gd`,
  `scripts/items/mythic_item_field_effect_renderer.gd`,
  `scripts/items/mythic_item_aura_field_renderer.gd`,
  `scripts/items/mythic_item_armor_field_renderer.gd`,
  `scripts/items/mythic_item_hermes_field_renderer.gd`,
  `scripts/items/mythic_item_horn_strawberry_field_renderer.gd`,
  `scripts/items/mythic_item_momentum_field_renderer.gd`,
  `scripts/items/mythic_item_poseidon_field_renderer.gd`,
  `scripts/items/mythic_item_ragnarok_field_renderer.gd`,
  `scripts/items/mythic_item_context_builder.gd`,
  `scripts/items/mythic_item_snapshot_builder.gd`, and
  `scripts/items/mythic_item_owner_syncer.gd`
  Own the current mythic field/query read surfaces and should call focused
  item owners directly for Venom Mist alpha, Celestial Armor wave state,
  Rainbow Fur Glove aura state, Hermes Shoes host state, Adversity Armor timer
  / barrier / visible state, Shrapnel Armor visible state, Knee Pads / Soul
  Burst draw state, Ragnarok elapsed timing, visible-field perf counters,
  and lazy Horn
  Strawberry sub-context reads gated by visible state.
  `scripts/items/mythic_item_ragnarok_runtime.gd` owns the public elapsed-time
  helper methods for Ragnarok ball / impact state; do not reintroduce
  private runtime getter bridges for these read paths.
- `scripts/lingpet/lingpet_banana_slice_payload_factory.gd`
  Owns pure Monkeyring Banana Slice runtime payload construction for thrown
  bananas, landed banana slip traps, and slip burst particles.
  `scripts/lingpet/lingpet_banana_slice_skill.gd` should not reintroduce inline
  projectile / landed-banana / burst-particle dictionary scaffolding.
- `scripts/lingpet/lingpet_banana_slice_skill.gd`
  Owns Monkeyring Banana Slice level scaling, prepare/staged-throw lifecycle,
  landing-x and slip-direction RNG, projectile/trail movement, landed-banana
  collision/expiry, boss-slip decay and AI context, burst-particle simulation,
  audio, companion pose, and `banana_slice_*` snapshots. It delegates render
  resources/composition to `lingpet_banana_slice_renderer.gd` with three borrowed
  live arrays and preserves texture-readiness snapshot compatibility.
- `scripts/lingpet/lingpet_banana_slice_renderer.gd`
  Owns the Banana Slice texture and filled-ellipse mesh caches plus stateless
  prepare, trail/projectile, rotated-region, landed shadow/blink, and particle
  drawing. It owns no gameplay/RNG/payload/audio/context/snapshot state and must
  not retain the borrowed projectile, landed-banana, or particle arrays.
- `scripts/lingpet/lingpet_gatling_burst_skill.gd`
  Owns Volty Gatling Burst runtime: mount / fire / dismount timing, aimed spread
  fire, bullet movement and boss collision, AK-style status application,
  transform/fire/hit feedback, loop-audio cleanup, particle simulation,
  gameplay-aligned tank/muzzle geometry, and `gatling_burst_*` snapshots.
  Stateless drawing and the transform-sheet cache are delegated to
  `lingpet_gatling_burst_renderer.gd` with four borrowed live arrays.
- `scripts/lingpet/lingpet_gatling_burst_renderer.gd`
  Owns Volty Gatling Burst's transform-sheet load/prewarm cache and stateless
  tank/cannon/muzzle-flash, mount-bar, bullet/trail, hit-particle, casing, and
  smoke CanvasItem recipes. It must not own phase/projectile simulation,
  spread RNG, collision/status/audio policy, or retained payload collections.
- `scripts/lingpet/lingpet_gatling_burst_payload_factory.gd`
  Owns pure Volty Gatling Burst payload construction for bullets, AK-style
  stun status data, hit particles, shell casings, and muzzle smoke.
  `scripts/lingpet/lingpet_gatling_burst_skill.gd` should keep transform /
  firing phase timing, aiming, hit detection, audio, loop cleanup, and
  simulation while rendering stays in `lingpet_gatling_burst_renderer.gd`;
  neither owner should reintroduce inline Gatling projectile / particle
  dictionary scaffolding.
- `scripts/characters/runtime_perk_angel_blessing_state.gd`,
  `scripts/characters/runtime_perk_angel_blessing_cooldown_capability.gd`,
  `scripts/characters/runtime_perk_angel_blessing_projection.gd`, and
  `scripts/characters/runtime_perk_angel_blessing_gauge_compositor.gd`, plus
  `scripts/characters/runtime_perk_angel_blessing_stage_lifecycle.gd`
  Own the live Angel Dice runtime foundation: canonical six-buff
  vocabulary, character-capability filtering, deterministic 1-3 sampling
  without replacement, per-stage dedupe/history, HUD-facing multiplier
  snapshot, and pure six-lane numeric composition. The runtime perk query
  surface consumes the five shared live getters and exposes a bespoke final
  maximum-gauge facade. The gauge compositor separates Fuel ratio preservation
  from Angel absolute-value preservation; `mythic_item_owner_syncer.gd` is its
  single owner writer, and Optimus now consumes the effective gauge maximum.
  Optimus per-tick paddle snapshots are base-only so the shared item/perk/mythic
  composition is not overwritten. `battle_scene_player_control_config_builder.gd`
  owns Horn's replacement-base-before-shared-multipliers ordering and publishes
  explicit transform/skill-lock flags. Optimus, Commando, Blacksmith, Viper, and
  Smasher movement owners suppress or cancel incompatible character-specific
  post-overrides; Commando's suicide-drone hard freeze and non-Horn behavior stay
  intact. `character_info_overlay_stats_presenter.gd` mirrors the same Horn base,
  Smasher exception, weather, and status speed sources for TAB. Blacksmith cooldown
  capability is now evidence-gated: the current empty config produces a
  five-candidate pool, while a future explicitly live skill-id/config API contract
  plus configured timer owner opens the sixth candidate without a character
  hardcode. Shared
  runtime/item multiplier inputs already reach the compatibility config, but
  Hammer Shock itself remains unported. The stage lifecycle helper now filters
  campaign context, uses normalized character capability, rolls only from the
  existing 4.4-second intro completion callback, and resynchronizes owner/config/
  gauge consumers only after a successful new stage roll. Existing deferred
  Dimension Gate/full-gauge effects resolve first; rally restarts preserve the
  result, later stages replace it, and full reset clears state/history.
  `runtime_perk_angel_blessing_acquisition_lifecycle.gd` owns accepted raw
  `0 -> 1` battle-vs-result route classification, and
  `runtime_perk_angel_blessing_modal_flow.gd` owns deduplicated current-stage /
  next-valid-intro reservations, acquisition-cinematic release, pending reveal,
  three-second confirm state, input arm, and round/stage/full-reset queue policy.
  `runtime_perk_state.gd` orchestrates the Angel-only roll and shared pause/sync
  seams; the mythic cinematic runtime owns the natural completion edge, while
  core modal/input/overlay/frame owners provide active-only blocking and the
  post-mythic-update no-gap recheck. Round/stage cancellation releases the
  preserved queue entry explicitly without masquerading as natural completion;
  scoreboard/result/shared modal blockers retain ordering until it is safe to
  resume remaining choices or Angel.
- `scripts/characters/runtime_perk_catalog.gd`,
  `perk_conversion_values.gd`, `mythic_perk_grant_helper.gd`, and
  `runtime_perk_debug_grants.gd`
  Own Angel's public thirteenth converted-mythic registration, fixed 30%
  value, regular jackpot/debug and guaranteed-choice exposure, shared mythic
  cinematic payload, plus unchanged-target debug no-op semantics. Angel is a
  runtime perk only and must not enter mythic item, field, Pandora, shop,
  crane, gacha, treasure-hunt, polish, or equipment routes.
- `scripts/characters/runtime_perk_angel_blessing_localization.gd` and
  `scripts/core/language_settings_data.gd`
  Own seven-locale dynamic modal/status text and the static catalog
  Korean-plus-six-locale name/summary respectively.
- `scripts/hud/angel_blessing_roll_overlay_host.gd`,
  `shaders/angel_blessing_halo.gdshader`, and the Angel branches in
  `runtime_perk_icon_renderer.gd` / `runtime_perk_overlay_renderer.gd`
  Own the full-canvas-clipped modular modal, non-blocking absorption tail,
  static/sheet art, and snapshot-only presentation sync. The detached host
  does not own logical time or cleanup.
- Angel branches in `scripts/audio/game_audio.gd`,
  `scripts/audio/gameplay_loop_audio_cleanup.gd`,
  `scripts/core/battle_pso_prewarmer.gd`, staged battle resource prewarm, and
  round/stage/full-reset cleanup owners
  Own the roll cue, three-voice absorption pool, first-use GPU/resource warmup,
  and direct host/audio teardown when draw fanout is inactive.
- `scripts/items/mythic_item_acquisition_timeline_state.gd`
  Owns mythic acquisition phase clocks, reveal-click arming, one-shot absorb,
  delayed after-cue stop, cancellation, and natural-completion events.
- `scripts/items/mythic_item_acquisition_presentation_factory.gd`
  Owns the cinematic's fixed 13-node manifest, writhe/arc materials, particle
  recipes, icon hosts, and reveal-text controls.
- `scripts/items/mythic_item_acquisition_visual_envelope.gd`
  Owns allocation-free buildup/ignite/fade/reveal/absorb/impact scalar
  projection. The cinematic host applies these values to live nodes.
- `scripts/items/mythic_item_acquisition_light_beam_state.gd` and
  `scripts/items/mythic_item_acquisition_light_beam_renderer.gd`
  Own seeded sparse-beam spawn/lifetime and exact full-set geometry/rendering,
  respectively. The renderer must not use live-index stride decimation.
- `scripts/items/mythic_item_acquisition_overlay_renderer.gd`
  Owns shaken-field overscan, monitor-covering white-out, and paddle glow/slam
  ray geometry while the host retains lazy resource loading and draw order.
- `scripts/items/mythic_item_acquisition_reveal_presenter.gd`
  Owns injected-time icon frame/fit projection and fixed reveal text layout.
  `mythic_item_acquisition_cinematic_v2.gd` retains localization and resource
  loading.
- `tools/bake_mythic_acquisition_raster_textures.gd` and the three PNGs under
  `assets/sprites/effects/mythic_acquisition/`
  Own offline generation of the icon backdrop, soft vignette, and soft white
  flash. Runtime acquisition code loads these assets and performs no raster
  buffer allocation or image upload.
- `scripts/hud/pause_menu_session_state.gd`
  Owns pause activation/options modes, opening and dial clocks, main selection,
  and slider-drag lifetime. `pause_menu_overlay.gd` exposes compatibility
  properties and delegates transitions.
- `scripts/hud/pause_menu_options_navigation_policy.gd` and
  `scripts/hud/pause_menu_options_navigation_state.gd`
  Own settings tab/device order, focus counts, wrapping/clamping, feedback
  scopes, and the live tab/focus/device tuple.
- `scripts/hud/pause_menu_input_command_router.gd`
  Owns side-effect-free keyboard/gamepad interpretation into semantic pause
  commands across main and every settings tab. The overlay executes those
  commands with audio/state/system side effects.
  Regression guard: `tests/pause_menu_input_command_router_smoke.gd`.
- `scripts/hud/pause_menu_pointer_command_router.gd`
  Owns side-effect-free mouse press/release, right-click, main/options hit
  routing, slider-drag projection, select-chevron direction, and language/
  control/display click commands. The overlay retains hover animation updates
  and executes pointer commands through the shared side-effect boundary.
  Regression guard: `tests/pause_menu_pointer_command_router_smoke.gd`.
- `scripts/hud/pause_menu_audio_controller.gd`
  Owns pause-menu `game_audio` lookup, move/confirm/back cues, BGM/SFX fallback
  reads, clamped writes, focused adjustment, and slider-value projection. The
  overlay retains timing decisions and compatibility wrappers. Regression
  guard: `tests/pause_menu_audio_controller_owner_smoke.gd`.
- `scripts/hud/pause_menu_content_catalog.gd`
  Owns stable main action identifiers, localized main entries, options
  back/close labels, and the exact tab/device/focus-to-readout-description
  mapping. The overlay preserves `_text`/`_get_*` compatibility wrappers and
  assembles the final options render snapshot. Regression guard:
  `tests/pause_menu_content_catalog_owner_smoke.gd`.
- `scripts/hud/pause_menu_controls_settings_controller.gd`
  Owns saved vibration sync, clamped adjustment/persistence, default
  restoration, localized vibration labels, and keyboard/joypad mapping-row
  projection. Device selection and focus clamping remain in the options
  navigation state; the overlay preserves compatibility properties and
  wrappers. Regression guard:
  `tests/pause_menu_controls_settings_controller_owner_smoke.gd`.
- `scripts/hud/pause_menu_language_settings_controller.gd`
  Owns saved-language sync, canonical language ordering/focus mapping,
  cycle/wrap selection, persistence, native-name projection, and owner
  text-refresh notification. The pointer router reuses its canonical mapping;
  the overlay retains compatibility wrappers and localized render-snapshot
  assembly. Regression guard:
  `tests/pause_menu_language_settings_controller_owner_smoke.gd`.
- `scripts/hud/pause_menu_selection_feedback_state.gd` and
  `scripts/hud/pause_menu_selection_feedback_renderer.gd`
  Own selection slide/pop clocks and hover transitions, plus main/options focus
  rect routing, interpolation, pop scaling, flash panel, and focus-frame draw,
  respectively. The facade retains transition triggers and compatibility
  wrappers. Regression guards: `tests/pause_menu_selection_feedback_state_smoke.gd`
  and `tests/pause_menu_selection_feedback_renderer_owner_smoke.gd`.
- `scripts/hud/pause_menu_display_settings_state.gd` and
  `scripts/hud/pause_menu_display_settings_controller.gd`
  Own normalized display preference values/local transitions/baselines and the
  `battle_view_layout` sync/apply/save transaction respectively. The controller
  also owns refresh-rate discovery, labels/recommendations, and the explicit
  60 Hz system-settings fallback. The overlay preserves compatibility wrappers.
  Regression guards: `tests/pause_menu_display_settings_state_smoke.gd` and
  `tests/pause_menu_display_settings_controller_owner_smoke.gd`.
- `scripts/hud/pause_menu_main_renderer.gd`
  Owns editorial pause-main asset prewarm, opening projections, background and
  compass geometry, selection bar, and entry rendering. Compatibility wrappers
  in `pause_menu_overlay.gd` delegate to this renderer.
- `scripts/hud/pause_menu_overlay_layout.gd`
  Owns pure pause-main and all settings-tab geometry shared by rendering, mouse
  hit testing, hover feedback, and keyboard/gamepad focus projection. The
  facade preserves its established `_get_*` methods but delegates every layout
  calculation here. Regression guard:
  `tests/pause_menu_overlay_layout_owner_smoke.gd`.
- `scripts/hud/pause_menu_options_renderer.gd`
  Owns the options palette, stateless option-window and display/controls/
  language tab composition, plus header, tab/icon, slider, setting row, toggle,
  button, readout, shared panel, neon-line, and focus-frame drawing. It consumes
  only the facade's resolved render snapshot and does not read registries or
  settings singletons. `pause_menu_overlay.gd` retains snapshot projection,
  selection-feedback/readout ordering, and compatibility `_draw_*` APIs.
  Regression guard: `tests/pause_menu_options_renderer_owner_smoke.gd`.
- `scripts/core/display_settings_config_codec.gd`
  Owns display-settings schema defaults, missing-key completion, version
  migration, graphics payload copying, BOM recognition, and display/FPS/VSync
  normalization. `battle_view_layout.gd` retains filesystem, backup recovery,
  OS/window application, and diagnostics.
- `scripts/plaza/plaza_save_config_codec.gd`
  Owns the plaza save `ConfigFile` schema, encode/decode, legacy schema reads,
  quest and stage-map projections, boolean/int section filtering, and
  gold/AP/gem/decoder sanitization. `plaza_save_store.gd` retains live state,
  transactions, filesystem/BOM handling, backup recovery, and diagnostics.
- `scripts/hud/character_info_overlay_lingpet_vitality_projection.gd`
  Owns character-info satiety snapshot merge and affinity/satiety strip state,
  layout, color, shared meter width, and hover zones.
- `scripts/hud/character_info_overlay_lingpet_card_specs.gd`
  Owns Lingpet names, active/passive skill-card specs, unlock-option filtering,
  and unlock candidate/title/subtitle projection.
- `scripts/hud/character_info_overlay_lingpet_stats_projection.gd`
  Owns Lingpet character-info stat rows, row-budget policy, cache invalidation
  hash, and cached row payloads.
- `scripts/hud/character_info_overlay_lingpet_ring_core_projection.gd`
  Owns Ring Core/chip row geometry, labels, hover/tooltip projection, icon inset,
  and stable vertical pip geometry. The Lingpet presenter retains drawing and
  texture lookup.
- `scripts/ui/main_menu_ambient_state.gd`
  Owns deterministic main-menu ambient particle, sky-light, and silhouette
  simulation, including seeded RNG order and silhouette scheduling. The ambient
  `Control` retains process gating and drawing, clears the payload, and releases
  the state owner on tree exit.
- `scripts/ui/main_menu_ambient_projection.gd`
  Owns draw-free main-menu source/screen projection, rectangle/line clipping,
  title glint sweep/fade/hash math, and gate-seam mask classification used by the offline
  baker. `main_menu_ambient.gd` keeps compatibility facades.
- `scripts/ui/main_menu_ambient_mask_data.gd` and
  `assets/ui/main_menu/main_menu_ambient_masks.res`
  Own the validated baked Hangul-title/gate-seam mask schema and accepted pixel arrays.
  Runtime code duplicates the packed arrays once and performs no source-image
  readback or pixel scan.
- `assets/ui/main_menu/main_menu_ambient_vignette.res`,
  `tools/bake_main_menu_ambient_masks.gd`, and
  `tools/bake_main_menu_ambient_vignette.gd`
  Own the baked 256x256 vignette and the offline-only mask/vignette regeneration
  paths. Runtime ambient code performs no `Image` allocation or texture upload.
- `scripts/ui/main_menu_scene.gd`
  Owns title-screen scene orchestration, input/navigation, reveal/settings/quit
  routing, transition tweens/drawing, background-prewarm polling, and the final
  character-select scene handoff. Focused owners provide clocks, prompt UI,
  audio lifetime, and settings services; the scene explicitly releases those
  short-lived owners during tree exit.
- `scripts/ui/main_menu_start_transition_state.gd`
  Owns the deterministic start-transition duration, elapsed clock, normalized
  progress, cancel/reset, and one-shot completion edge.
- `scripts/ui/main_menu_gate_transition_projection.gd`
  Owns draw-free gate-opening panel rectangles, expanding spirit-light beam,
  shadow, and final whitewash envelopes. The scene retains CanvasItem drawing.
- `scripts/ui/main_menu_touch_start_prompt.gd`
  Owns the runtime localized input-neutral start copy, label/control, pulse clock,
  full-rect anchor contract, faded-ribbon drawing, and visible pulse sync.
- `scripts/audio/main_menu_audio_controller.gd`
  Owns title BGM/start-SFX players, boot-preloaded player creation/adoption,
  mute toggles, player/stream cleanup, and lazy settings-adapter lifetime.
- `scripts/audio/main_menu_audio_stream_policy.gd`
  Owns AudioServer bus defaults, volume conversion, and private looping stream
  duplication so shared path-cached audio is never mutated per player.
- `scripts/ui/main_menu_audio_settings.gd`
  Owns the AudioServer-backed BGM/SFX volume adapter consumed by the shared
  pause/settings overlay on the main menu.
- `scripts/ui/main_menu_settings_registry.gd`
  Owns the narrow main-menu dependency registry for audio settings and
  `battle_view_layout`, including explicit reference cleanup.

## 2026-07-13 — Smasher Overdrive active skill

- `scripts/characters/smasher_overdrive_state.gd` owns `smasher_overdrive` activation, the 360-frame gameplay-time duration (5 seconds at the shipped 72 Hz physics tick), capped flat speed boost, alternating kink schedule, reflection heading refresh, timer snapshot, and visual-facing kink/active signals.
- `scripts/ball/ball_frame_motion_controller.gd` applies the non-owning velocity field and temporary speed cap; `ball_motion_event_processor.gd` centrally reports the final velocity after wall, paddle, barrier, terrain, trampoline, and Stage 2 backstop reflections. Overdrive never skips the normal motion step or replaces collision ownership.
- The skill awards no separate skill gold; normal paddle/rally reward paths remain authoritative.
- Runtime ids are sealed as `smasher_overdrive` and `unlock_smasher_overdrive`; the pre-existing Lingpet `overdrive` id is intentionally untouched.

## 2026-07-29 — 허공환영 (Void Phantom) Smasher form

Supersedes the deleted `scripts/items/active_item_hologram_disk_runtime.gd`
active-item entry above. Design note: `docs/void_phantom_smasher_skill.md`.

- `scripts/characters/smasher_void_phantom_state.gd` owns the `void_phantom`
  form end to end: the contact-launch gate (↓/S + left-click held at the
  paddle bounce), the 60-frame owned-ball charge (ball follows the player at
  zero velocity with motion-step skip), one-shot decoy spawning on release
  (two fixed left/right phantoms, so exactly three balls read on screen), the
  24°~35° widened split-angle band, the single per-activation deception roll,
  decoy kinematics in the center-coordinate convention (visual-margin wall reflection, boss-band
  glitch-pop death), pop-particle spawning, the cache-only deception peek the
  boss AI context builder consumes, and round/match cleanup. The 1-second
  cinematic startup is internal and has no duration HUD; the flight remains
  one-shot.
- `is_command_armable()` in that module is the **single ownership predicate**
  for the shared input tokens. Both `scripts/ball/paddle_bounce_skill_router.gd`
  (left-click contact, yielding 천뢰격/빙혼비격 and 벽력타) and
  `scripts/characters/smasher_warp_gate_state.gd` (↓ hold, suppressing 건곤환문
  arming) must route through it; splitting the predicate is what let the warp
  gate stay sealed through the 100~349 gauge band and the whole 70s cooldown.
  It is peek-only — activation and gauge spend stay in
  `ball_motion_event_processor._try_launch_smasher_void_phantom`, which writes
  the spend into the snapshotted `scene` dict.
- `ball_frame_motion_controller.apply_smasher_void_phantom_charge` owns the
  pre-step charge wrapper and runs before the first skip early-return in
  `ball_update_controller`; the 60th tick clears stale skip and restores the
  preserved launch velocity into the scene snapshot. `_skip_advance_on_launch_frame`
  then owns the release-frame ordering contract so freshly spawned decoys do
  not advance ahead of the real ball.
- `scripts/characters/smasher_void_phantom_renderer.gd` owns decoy and
  pop-particle drawing plus the charge/release Taoist seal composition
  (prewarmed Hanryeongtan seal ring, cyan gathering arcs, gold converging
  strokes). `stage1_player_sprite_renderer.gd` owns the dedicated 16-frame
  Han Miryang charge sheet at
  `assets/sprites/smasher/hanmiryang_void_phantom_charge_autosprite_v2_4x4_160_clean.png`.
  The VFX is driven from
  `battle_playfield_scene_drawer._draw_void_phantom_decoys`, deliberately
  outside the decorative LOD gate because decoys are gameplay-readable
  entities, not decoration.
- `scripts/ball/ball_frame_motion_controller.gd` owns the ball-path decoy tick
  wrapper plus the stopwatch time-freeze gate; `battle_effects_update_controller.gd`
  drives pop-particle lifetime so pops finish after the form ends.
- Runtime ids are sealed as `void_phantom` and `unlock_void_phantom`. The 5-orb
  icon and perk-card cover currently reuse the retired item art as a
  placeholder (`assets/sprites/skills/smasher_void_phantom_skill_orb.png`);
  a dedicated 비급 cover is still outstanding.
- Seals: `tests/smasher_void_phantom_smoke.gd` and
  `tests/smasher_void_phantom_vfx_contract_smoke.gd` (replaces the deleted
  `tests/active_item_hologram_disk_smoke.gd` in the pre-push and CI lists).

## 2026-07-21 minimal loading cameo presentation

- `scripts/core/loading_cameo_catalog.gd` owns the shared minimalist loading
  layout, prewarmed cameo registry, silhouette shader, and translated tip
  projection used by both boot and battle loading surfaces.
- `scripts/core/loading_cameo_host.gd` owns the loading-session random pick,
  16-frame animation projection, layered glow sprites, and literal English
  `Now Loading...` copy. The pick is stable until `hide_loading()` resets the
  session. Terminal `tear_down()` releases texture/material/font/RNG ownership;
  boot and battle loading owners synchronously free the detached host so final
  shutdown never depends on another message-queue flush.
- `scripts/core/battle_loading_screen_renderer.gd` retains warmup snapshot,
  completion-hold, stage-transition, and Stage 7 Akamu exemption contracts;
  `scripts/core/boot_flow_scene.gd` retains character-select prewarm and
  navigation ownership. Both delegate their visible loading presentation to
  the shared cameo modules.

## 2026-07-24 defeat continue scene presentation

- `scripts/core/defeat_continue_visual_projection.gd` owns draw-free confirm,
  shatter, impact, and whiteout envelopes plus gem/button/source-sheet
  geometry, fit/cover rectangles, scaling, and easing. Screen and renderers
  delegate shared math here instead of retaining parallel formulas.
- `scripts/core/defeat_continue_ambient_renderer.gd` owns the chance-gem
  continue screen's bounded divine-mote and fan-ray counts, portal-breath
  status projection, and portal-glow/light-shaft/mote drawing.
- `scripts/core/defeat_continue_scene_renderer.gd` owns static backdrop cover,
  vignette bands, entry reveal glow/veil, cached boss-victory sheet selection,
  stage-specific source rectangles, boss portal figure drawing, and the
  full-screen whiteout/fringe overlay.
- `scripts/core/defeat_continue_gem_renderer.gd` owns reusable scalar
  presentation state, chance-gem rail/slot layout, cached full/broken/shatter
  texture projection, 64-frame sheet handoff, pre-shatter charge/cracks,
  chroma split, and impact ring/shard/beam drawing. It accepts explicit scalar
  sync calls and allocates no per-frame context dictionary.
- `scripts/core/defeat_continue_ui_renderer.gd` owns defeat title ornaments,
  three-phase status copy, normal/last-chance guide copy, confirm-button frame,
  and text drawing. It shares button geometry with the pure projection and
  avoids the former per-frame segment dictionaries.
- `scripts/core/defeat_continue_cinematic_state.gd` owns PRESENT/CONSUMING
  phase, confirm-clock advancement, consumed-count fallback/result state,
  allocation-free one-shot consume/shatter/reset event bits, the hitch-safe
  peak-white clamp, revival-update gating, fadeback completion, and confirm-
  time projection delegation. It owns no callback, audio, tree, or draw side
  effects.
- `scripts/core/defeat_continue_transition_controller.gd` owns explicit bind,
  attachment, scalar sync, and direct reset cleanup for the detached shatter
  and color-restore hosts. It also bridges the registered revival beat's
  start/update/draw/reset/physics-gate protocol without an independent process
  loop or draw-time node creation.
- `scripts/core/defeat_chance_gems_continue_screen.gd` retains chance-gem
  state, input, consume/continue callbacks, audio one-shots, and the modal
  facade. It consumes cinematic-state event bits and delegates
  scene, ambient, gem, UI, detached-host, and revival-beat work using the
  shared pure projection, existing screen clocks, and derived impact envelopes.

## 2026-08-01 Viper Wall-Leap Night Raid

- `scripts/characters/viper_skill_wall_leap_runtime.gd` owns Wall-Leap Night
  Raid state, costs, tween/return geometry, status commits, and reset.
- `scripts/characters/viper_skill_runtime.gd` remains the character facade for
  activation, draw, collision, boss-prediction, armability, and unavailable-
  state observation contracts.
- `scripts/ball/ball_update_controller.gd` owns observations A/B;
  `scripts/ball/ball_motion_event_processor.gd` owns the 0.7 displacement-only
  multiplier; `scripts/ball/ball_motion_collision_detector.gd` owns the base-
  paddle-only guard gate.

## 2026-08-03 common boss Vision Chosik

- `scripts/characters/common_skill_catalog.gd` owns character-neutral Chosik
  definitions and boss-manual metadata. `dalji_vision_chain_top` is the first
  boss Vision entry and remains equipable through every character skill config.
- `scripts/characters/dalji_vision_chosik_state.gd` owns Shift+A-D-A command
  recognition, vigor/cooldown/cast state, two-top lifecycle, ball capture and
  boss-directed release, boss stagger consumption, and round/full reset.
- `scripts/characters/cheongringwi_vision_chosik_state.gd` owns the Stage 2
  `cheongringwi_vision_dragon_torrent` Shift+D-A-D command, 140-vigor / 28-second
  cooldown contract, tracking water-cannon lifecycle, boss-owned-ball capture,
  boss-directed release, and round/full reset. Its renderer reuses the Stage 2
  water-cannon visual owner rather than duplicating that effect family.
- `scripts/characters/yeonmyo_vision_chosik_state.gd` owns the Stage 3
  `yeonmyo_vision_bonghongwe` Shift+S command, 200-vigor / 35-second cooldown,
  gravity-arc throw, closed-chest 12-second lifetime, dash-segment opening,
  three-second smoke emission, smoke-radius exposure, dash cancellation without
  recovery stun, and owned confusion cleanup. Landing does not apply confusion:
  the chest must first be opened by dash contact, then the boss center must enter
  the smoke. The renderer owns the detached moving shadow, tumble/landing impact,
  open lid, and smoke layers and must not draw a player-to-chest tether. The
  equipped 5-orb HUD and `unlock_*` perk-choice card use the accepted
  `yeonmyo_vision_bonghongwe` orb and dedicated manual-cover PNGs. Only the
  dedicated Stage 3 victory-result box sheet remains an art-track deferral and
  currently uses the normal result-box fallback.
- `scripts/core/victory_loot_phase_state.gd` owns the one-roll-per-victory
  boss-manual box reservation: Stage 1 Dalji and Stage 2 Cheongringwi each use
  their dedicated 16-frame sheet under the shared 20-percent screen-level
  chance. `runtime_perk_catalog.gd` owns the protected next-offer card; the
  existing unlock swap flow remains the only full-slot replacement authority.

## 2026-08-05 Physique Training Category

- `scripts/characters/physique_training_catalog.gd` owns the ten `physique_*`
  definitions, per-pick amounts, per-stat caps, weights, and card payloads.
- `scripts/characters/physique_training_state.gd` owns run-lifetime acquisition
  counts, the six-pick total cap, save restore, and pre/post Mystic Dice offer
  metrics. Round reset must not clear this state.
- `scripts/characters/physique_training_offer_planner.gd` owns eligible-source
  filtering, the conditional 40-percent roll, weighted selection, and append-
  only auxiliary-card planning. `runtime_perk_choice_open_flow.gd` remains the
  sole owner of Dice-before-training lane order.
- `runtime_perk_effective_stat_query_surface.gd` is the only gameplay stat
  composition point. Training values bypass Mugong level, fusion, and polish
  amplification; active-item cooldown still flows through the shared composer.

## 2026-08-07 Victory Highlight Replay

- `scripts/core/victory_highlight_recorder.gd` owns visual/event history,
  time-based eviction, goal promotion, and dramatic clip selection.
- `scripts/core/victory_highlight_actor_resolver.gd` owns the flat replay actor
  snapshot contract and the slice-1 silhouette fallback.
- `scripts/core/victory_highlight_playback_state.gd` owns timeline, input skip,
  clipped host lifecycle, replay-only audio, and cleanup.
- `scripts/core/victory_highlight_renderer.gd` owns snapshot-only replay
  drawing. Match-flow, frame-flow, and input controllers retain orchestration,
  freeze, and routing authority respectively.
- `scripts/core/victory_highlight_frame_capture_state.gd` owns the optional
  380x375/30Hz async CPU-ring frame lane, its three online clip candidates,
  epoch rejection, and detached blit-viewport/RD cleanup. It never replaces
  the recorder's shadow state lane.
- `scripts/core/victory_highlight_frame_renderer.gd` owns the single
  ImageTexture frame-replay surface. Playback state alone selects it when every
  selected clip carries a frame payload; otherwise the snapshot renderer stays
  authoritative.

## 2026-08-08 Online 1v1 Han Miryang MVP

- `scripts/network/online_match_session.gd` owns the online activity flag,
  host/client role, handshake/readiness/phase flow, RTT, prediction history,
  reconciliation, interpolation, presentation-only client Y mirror, and the
  fixed 60Hz simulation-tick lock lifecycle.
- `scripts/network/online_enet_transport.gd` owns raw ENet peer lifecycle and
  channels; `online_match_protocol.gd` owns sanitized compact binary packets.
- `scripts/network/online_match_simulation.gd` owns host-authoritative ball,
  collision, serve, and match outcomes by composing existing score/round/ball
  owners plus the production paddle-bounce resolver group and public rally-cap
  progression API. `online_paddle_state.gd` owns the symmetric 155px
  player-rule state.
- `scripts/network/online_match_runtime.gd` owns the battle-shell takeover,
  central single-player feature bypass, compatibility projection, audio-event
  bridge, online draw/input routing, and fail-closed startup error when a
  required online owner is unavailable.
- `scripts/network/online_match_input_collector.gd` owns one idempotent local
  InputFrame snapshot per physics frame; `online_match_renderer.gd` owns the
  role-projected technical battle presentation only.
- `scripts/core/battle_scene_input_controller.gd` retains input orchestration
  ownership and consumes active-online events before all legacy feature routes;
  ESC stops the online runtime and exits through the existing match-flow owner.

## 2026-08-09 Lingpet ownership refresh

- `scripts/lingpet/guardian_egg_access_policy.gd` owns the shared read-only
  Guardian Egg access predicate and cached-registry lookup used before an egg
  candidate enters a reward surface.
- `scripts/lingpet/lingpet_duration_runtime_state.gd` owns duration-pool drain,
  drain-exemption latching, inactive advancement, percentage projection, and
  passive-skill drain multipliers. `scripts/lingpet/lingpet_duration_field_gauge_renderer.gd`
  owns the matching layout, color tier, pulse, and snapshot-only field gauge
  draw contract.
- `scripts/lingpet/lingpet_guardian_duration_lifecycle_coordinator.gd` owns the
  cross-owner Guardian uptime lifecycle: active/stowed state, six-second manual
  hold, recovery-gated resummon, transition start/completion, drain warnings,
  stage/replacement refill order, forced expiry, and ordered skill/passive/VFX/
  mount/guard teardown. It holds the egg-runtime facade through `WeakRef` only;
  legacy facade fields and APIs project to this canonical state. Regression
  guard: `tests/lingpet_guardian_duration_lifecycle_coordinator_owner_smoke.gd`.
- `scripts/lingpet/lingpet_guard_feedback_state.gd` owns transient guard-label
  timing, position, reset, visibility, and snapshot state.
  `scripts/lingpet/lingpet_guard_hit_tag_resolver.gd` owns the draw-free merge
  of motion and ring-dash guard tags plus the authoritative defense-tag query.
- `scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd` owns Guardian
  Enhancement eligibility, screen cooldown, localized card/result copy,
  candidate weighting, and offer state. `scripts/lingpet/lingpet_guardian_enhance_applier.gd`
  owns weighted selection, runtime application dispatch, and normalized result
  feedback, while `scripts/lingpet/lingpet_guardian_enhance_result_detail.gd`
  owns the before/after detail payload for skill, stat, unlock, and fallback
  results.
- `scripts/lingpet/lingpet_guardian_enhance_flow_coordinator.gd` owns the
  end-to-end gameplay orchestration across those focused owners: Guardian
  resolution/context, offer/live candidates, weighted roll and revalidation,
  run-state application, unlock loadout refresh, result detail/fallback,
  snapshot and owner sync, and presentation handoff. It retains the egg-runtime
  facade through `WeakRef` only; public facade methods are compatibility
  delegates. Regression guard:
  `tests/lingpet_guardian_enhance_flow_coordinator_owner_smoke.gd`.
- `scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd` owns the five-phase
  cut-in clock, roll/reaction frame projection, cancel/reset, and immutable
  snapshot. `scripts/lingpet/lingpet_guardian_enhance_cutin_overlay_host_resolver.gd`
  owns cache-only overlay-host resolution, animation readiness/contract reads,
  and result-icon prewarm queries; it does not own cut-in logical time.
- `scripts/lingpet/lingpet_guardian_enhance_presentation_coordinator.gd` owns
  the applied-result presentation lifecycle across those focused owners:
  cache-only reel-icon filtering, source labeling and offer reservation commit,
  retained result, prewarm/start/advance/cancel, modal cooldown pause/resume
  safety, and enhancement-loop audio shutdown. `lingpet_egg_runtime.gd` keeps
  only its public compatibility methods and one configured coordinator field.
  Regression guard:
  `tests/lingpet_guardian_enhance_presentation_coordinator_owner_smoke.gd`.
- `scripts/lingpet/lingpet_guardian_run_state.gd` owns persistent per-run
  Guardian duration, enhancement, re-summon, and dirty/save state.
  `scripts/lingpet/lingpet_guardian_run_context_coordinator.gd` owns new-run
  configuration, current-profile synchronization, stored-loadout selection,
  and enhancement-gain handoff into that state.
- `scripts/lingpet/lingpet_guardian_transition_state.gd` owns summon/stow
  transition timing, alpha/progress projection, trail presentation, prewarm,
  and immediate reset.
- `scripts/lingpet/lingpet_item_offer_policy.gd` owns the shared Guardian Egg
  and Spirit Water candidate gate. Cards, drops, capsules, gacha, and future
  reward builders must call this policy before selection instead of repairing
  an already-selected forbidden item.
- `scripts/lingpet/lingpet_mokrin_transform_skill.gd` owns Mokrin transform
  launch/update/cancel, guard-stage progression, cue routing, remaining time,
  cast-pose projection, and snapshots.
- `scripts/lingpet/lingpet_mount_topdown_readiness.gd` owns cache-only readiness
  resolution for top-down mount/rider textures and canonical rider specs; it
  must not trigger synchronous asset loading from the live render path.
- `scripts/lingpet/lingpet_overflow_absorb_plan.gd` owns the draw-free consume
  plan for overflow Guardian absorption, including selected-pet and collection
  validation plus the normalized no-op result.
- `scripts/lingpet/lingpet_spirit_water_drop_state.gd` owns the once-per-run
  Spirit Water pending/succeeded gate, stage-transition rearm, eligibility from
  Guardian duration state, save/restore, and diagnostic snapshot.
- `scripts/tower_ascent/tower_ascent_flow_owner.gd` is the stable one-line
  compatibility facade for the default-off generated run-map flow. Its eager
  inheritance chain splits ownership without changing the public API:
  `tower_ascent_flow_runtime.gd` owns lifecycle/input/update/draw coordination;
  `tower_ascent_flow_snapshot_progress.gd` owns full-graph snapshot recovery and
  pending-reward journals; `tower_ascent_flow_ending_progress.gd` owns floor 9
  judgment/choice, settlement, floor 11 gauntlet, floor 12 true ending, and
  defeat records; `tower_ascent_flow_node_progress.gd` owns node-modal routing
  and service-node delegation; `tower_ascent_flow_economy_progress.gd` owns run
  economy plus shop/training transactions; `tower_ascent_flow_map_progress.gd`
  owns graph consumption, route candidates, selector-ball simulation, movement,
  and idempotent node resolution; `tower_ascent_flow_state.gd` eagerly owns the
  shared state/dependencies and reset utilities. The chain must not lazy-create
  modules from `update_selective()` or `draw()`.
- `scripts/tower_ascent/tower_ascent_feature_flags.gd`,
  `tower_ascent_map_generator.gd`, `tower_ascent_boss_registry.gd`,
  `tower_ascent_route_candidate_policy.gd`, `tower_ascent_enraged_policy.gd`,
  and `tower_ascent_flow_renderer.gd` retain activation, versioned seeded
  12-floor generation, boss pools/routing, avoided-boss filtering,
  generation-time enraged marking, and code-drawn parchment presentation.
  Existing battle match/input/physics/draw modules only route the facade; the
  legacy result/plaza path remains the fallback until a later atomic production
  promotion.
