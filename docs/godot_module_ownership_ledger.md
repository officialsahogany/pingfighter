# Godot Module Ownership Ledger

Current implementation target: Godot **디스크하츠 - 링피아**.

This ledger was split out of `docs/godot_port_architecture.md` to keep the
architecture guide readable. It records module ownership, split history, and
current port status so future work can resume without re-discovering every
owner.

Read this as a ledger, not a rulebook:
- Module entries describe who owns a behavior today and what was ported.
- Older `Python-parity`, `legacy`, or `current` wording records why the module
  exists or what behavior it matched at the time.
- New implementation rules belong in `AGENTS.md`,
  `docs/godot_port_architecture.md`, `docs/godot_port_checklist.md`, or the
  focused item / character runtime checklist.

---

## Module Ownership Ledger / Cumulative Port Log

This section is intentionally long; use search to find the nearest owner.

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
  selected passive-skill metadata, effect text, hit footprint helpers, and
  selected-pet visual prewarm / texture lookup
  through `lingpet_visual_texture_cache.gd`. `lingpet_egg_runtime.gd` should
  update this helper when the active pet id changes instead of querying
  `lingpet_catalog.gd` directly.
- `scripts/lingpet/lingpet_egg_field_state.gd`
  Owns Ringpet floor-egg field behavior: spawn position near the player paddle,
  player-contact nudge / wobble, egg ball-hit overlap state, player-serve
  bounce-without-crack semantics, paddle-style ball reflection, hit cooldown,
  hatch-hit counting, and egg snapshot fields. `lingpet_egg_runtime.gd` keeps
  the state transition into companion mode and the hatch flash / cut-in trigger.
- `scripts/lingpet/lingpet_egg_field_renderer.gd`
  Owns Ringpet floor-egg rendering: intact / cracked egg texture placement,
  glow, crack light leakage, hatch flash rings, and deterministic shell-shard
  burst geometry. `lingpet_egg_runtime.gd` supplies egg state and catalog-backed
  textures, but egg / hatch draw math should stay in this renderer.
- `scripts/lingpet/lingpet_companion_skill_state.gd`
  Owns Ringpet active-skill shared state: cooldown countdown, wind-up timing,
  launch origin, flash timer / ratio, trigger count, and snapshot payload
  fields. Pet-specific skill modules should own their projectile / field /
  status behavior, while `lingpet_egg_runtime.gd` uses this state controller
  for the common cast lifecycle.
- `scripts/lingpet/lingpet_companion_skill_controller.gd`
  Owns Ringpet companion active-skill arm / launch decisions: supported
  runtime id guard, host update, wind-up completion, ready-to-arm checks,
  skill prewarm before cast wind-up, launch completion, cooldown / flash
  commit, and launch feedback. `lingpet_egg_runtime.gd` should keep only the
  narrow update hook plus companion-position / launch-origin application.
- `scripts/lingpet/lingpet_companion_motion_state.gd`
  Owns Ringpet companion shared motion state: player-height patrol lane,
  stop-and-go randomized movement, save / restore patrol snapshot keys, and
  defense-rate intercept movement. `lingpet_egg_runtime.gd` keeps hatch /
  body-hit orchestration and delegates companion movement decisions here.
- `scripts/lingpet/lingpet_companion_sprite_animator.gd`
  Owns Ringpet companion sprite animation math: walk / idle frame selection,
  cast wind-up frame mapping, strike playback state, strike entry-frame mapping,
  source-rect slicing, draw-size offsets, and sheet geometry.
  `lingpet_companion_renderer.gd` uses this animator for draw rects, while
  future companion sheets should extend this animator instead of adding more
  frame math to the runtime.
- `scripts/lingpet/lingpet_companion_strike_anticipator.gd`
  Owns Ringpet companion visual strike anticipation: ball-active / descending
  checks, contact time prediction, current catalog hit-footprint inputs,
  horizontal future-position tolerance, latch reset, and animator strike start.
  The real bounce / gauge reward remains in `lingpet_companion_body_hit_state.gd`;
  this helper is visual timing only.
- `scripts/lingpet/lingpet_companion_draw_context_builder.gd`
  Owns Ringpet companion renderer config assembly: hit / gauge / skill flash
  ratios, switch-transition ratio and trigger counts, cast-vs-strike priority,
  patrol / wind-up timing fields, and current-profile walk / strike / cast
  texture resolution. `lingpet_companion_renderer.gd` should receive a finished
  config dictionary instead of making runtime-state decisions itself.
- `scripts/lingpet/lingpet_companion_renderer.gd`
  Owns Ringpet companion draw presentation: idle bob / glow, walk / strike /
  cast sprite blitting, hit flash rings, skill flash rings, and direct-hit
  gauge burst rays. `lingpet_egg_runtime.gd` supplies current textures and
  transient state, but companion draw math should stay in this renderer.
- `scripts/lingpet/lingpet_companion_body_hit_state.gd`
  Owns Ringpet companion body-contact behavior: wide catch-box overlap state,
  contact cooldown, last contact position, player-paddle-style ball reflection,
  boss ball-control release hooks, paddle-hit audio, body-hit gauge gain, and
  hit / gauge flash snapshot fields. Future Ringpets with different body-hit
  rules should extend this helper instead of adding more collision math to
  `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_afterglow_leak_state.gd`
  Owns the shared Ringpet passive `lingpet_afterglow_leak` / 잔광 유출:
  companion-hit residue spawning, residue lifetime / seep-away cleanup,
  player-paddle proximity absorption, fast gauge tick grants, the modular
  resonance-fluid VFX (bottle-burst at the hit point -> running-down cascade
  rivulets -> spreading luminous floor pool -> absorb wisps -> seep), its CPU
  droplet particle sim, gauge feedback calls, and debug / UI snapshot fields.
  The visual envelope is decorative only and never gates the absorb gameplay.
  `lingpet_egg_runtime.gd` should only call spawn / advance / draw / reset and
  should not inline residue math.
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
- `scripts/lingpet/lingpet_loadout_state.gd`
  Owns Ringpet acquisition loadouts: per-pet selected active-skill id,
  selected active/passive Lv.1-Lv.5 values, selected passive-skill id,
  passive slot unlock count, `lingpet_loadouts` / `ringpet_loadouts` owner-key
  compatibility, legacy missing-loadout defaults, and first-acquisition random
  shared-passive selection. Future Ringpet skill rerolls, choice tickets, or
  growth-driven loadout changes should update this helper instead of adding
  more selected-skill dictionaries to `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_collection_state.gd`
  Owns Ringpet owned-collection state and owner-key compatibility: save
  `owned_pet_ids`, `lingpet_owned_pet_ids` / `owned_lingpet_ids` /
  `owned_ringpet_ids`, collection dictionaries, first-owned companion adoption,
  and catalog-backed hatch candidate selection. Future Ringpet acquisition
  routes should update this helper instead of adding more collection key scans
  to `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_acquire_cutin_state.gd`
  Owns Ringpet acquisition cut-in timing state: reveal progress, hold-until-
  dismiss semantics, click-triggered exit-action progress, hard reset, and
  auto-close when the exit action completes. `lingpet_egg_runtime.gd` keeps
  the public modal / input / overlay API and delegates timing here so future
  Ringpet reveal variants do not add more cut-in clocks to the runtime.
- `scripts/lingpet/lingpet_companion_click_reaction_state.gd`
  Owns in-battle companion click-reaction behavior: tap-zone math, focused
  click-reaction sheet prewarm keys, 98-frame popup timing / alpha, and sheet
  frame drawing. `lingpet_egg_runtime.gd` keeps only the playfield click API
  and current-pet texture lookup.
- `scripts/lingpet/lingpet_runtime_snapshot_builder.gd`
  Owns Ringpet runtime data projection: live snapshot assembly, save snapshot
  assembly, selected loadout / passive-skill projection, and owner
  compatibility key sync for both `lingpet_*` and `ringpet_*` consumers.
  `lingpet_egg_runtime.gd` supplies current state / catalog stats / helper
  modules, but UI, HUD, and save-facing payload shapes should stay centralized
  here.
- `scripts/lingpet/lingpet_egg_runtime.gd`
  Owns the first Ringpet runtime slice: catalog-backed Junior League +
  Mika eligibility, hidden egg identity selection, owner-state sync for the
  character information panel via `lingpet_runtime_snapshot_builder.gd`,
  selected-loadout application via `lingpet_loadout_state.gd`,
  selected passive-skill player-hit gauge gain,
  owned-collection sync plus save-snapshot export / restore, hatch flash timing,
  player-height independent companion draw,
  post-hatch Maribo body ball-contact soft bounce with internal cooldown,
  Ringpet common body-contact gauge gain, generic companion skill cooldown /
  wind-up / launch handoff into `lingpet_skill_runtime_host.gd`, and the shared
  boss-skill rail Ringpet card surface. It exposes the acquisition cut-in API
  for modal / input / overlay controllers, but the reveal and dismiss timing
  state lives in `lingpet_acquire_cutin_state.gd`; companion click-reaction
  tap-zone / draw / timing state lives in `lingpet_companion_click_reaction_state.gd`.
- `scripts/lingpet/lingpet_skill_runtime_host.gd`
  Owns Ringpet active-skill module dispatch: skill-kind lookup, skill-specific
  prewarm / update / draw / visible-effect checks, launch blocking, launch
  calls, cast-windup visual gating, launch feedback, and skill snapshot merge.
  Future Ringpet active skills should add a focused skill module plus a
  dispatcher / host branch here instead of adding concrete projectile or field
  behavior to `lingpet_egg_runtime.gd`.
- `scripts/lingpet/lingpet_hydro_sphere_skill.gd`
  Owns Maribo Hydro Sphere's skill-specific runtime: projectile travel,
  opponent-wall impact, horizontal elliptical puddle, slow status refresh,
  splash / ambient droplet particles, procedural puddle texture drawing, and
  Hydro Sphere snapshot keys. `lingpet_skill_runtime_host.gd` calls this module
  instead of letting `lingpet_egg_runtime.gd` grow Maribo-specific projectile /
  puddle code inline.
- `scripts/lingpet/lingpet_bubble_trap_skill.gd`
  Owns Maribo Bubble Trap's skill-specific runtime: slow forward bubble
  projectile travel, boss-paddle collision capture, 2.5-3.0-second bubble movement
  lock, shared boss-stun refresh, ball-contact / expiry popping, lightweight
  procedural bubble burst VFX, reused hydro-water feedback, and Bubble Trap
  snapshot keys. `lingpet_skill_runtime_host.gd` dispatches this module by the
  `bubble_trap` runtime kind so `lingpet_egg_runtime.gd` stays limited to the
  common companion wind-up / launch lifecycle.
- `scripts/lingpet/lingpet_save_store.gd`
  Owns the Ringpet save-file route: loading / saving the runtime snapshot
  from `user://lingpet_save.cfg`, restoring it during battle bootstrap,
  and clearing egg / companion run-state snapshots so Ringpet eggs restart
  fresh on game re-entry instead of carrying a previous roguelike run.
  Default reset data comes from `lingpet_catalog.gd`.
- `scripts/items/mythic_item_catalog.gd` and
  `scripts/items/mythic_item_runtime.gd`
  Own the first mythic/passive equipment slice in the Godot port. The
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
  bonuses, result feedback, and a short overlay effect. It grants from
  the currently ported mythic lane through `mythic_item_runtime` and uses
  the ported passive item catalog for the 60% passive reward lane.
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
  Owns active-item slot state and use flow: starter active-slot
  construction, number-key edge input for visible slots, mobile HUD-slot
  touch activation, shared and per-item cooldown checks, consumable slot
  removal, `item_recycle` / Alchemy consume-preservation rolls and notice
  timers, `last_use_msec` fanout, selected-slot HUD sync, and field-pickup
  storage with active-effect store gating. Recycled consumables keep their
  slot, skip pending throw backup creation, still apply active-item use
  gauge bonuses, and route Alchemy feedback through `game_audio.play_alchemy`.
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
  `active_item_holy_barrier_runtime.gd`. Holy Barrier idle / hit particles
  and particle fade are delegated to `active_item_holy_barrier_particles.gd`.
  Holy Barrier activation application and activation feedback / audio
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
  compaction, and ring expiration. Non-visual reset work is handled by
  `active_item_regeneration_potion_runtime.gd`; activation-side spawning,
  audio, and feedback are handled by
  `active_item_regeneration_potion_actions.gd`.
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
  particle spawning, particle movement, and lifetime compaction. Trigger
  application and pickup audio remain in `active_item_pickup_actions.gd`.
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
  particle count, rainbow color sequence, center jitter, burst velocity,
  draw radius, and lifetime. Gauge gain, audio, feedback, and burst
  application remain in `active_item_gauge_actions.gd`; shared
  pickup-particle lifecycle updates remain in the pickup effect helper.
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
- `scripts/items/active_item_effect_context_builder.gd`
  Owns active consumable effect context snapshots consumed by item
  rendering, HUD timers, ball collision, and boss-returned ball processing:
  Giant Potion / Vitamin Pill / Strange Vial timer contexts, AI Pill /
  Stopwatch / Magnet Field / Holy Barrier render contexts, Holy Barrier
  collision context, Brick wall context, and Stopwatch ball-freeze /
  recovery context.
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
  pull lines / particles, Holy Barrier field wall / symbols / particles,
  Dash Boost / Vitamin Pill / Strange Vial field VFX, HUD-visual pickup icon
  lookup, pickup text sizing caches, and field-effect draw ordering. The
  runtime passes through the effect controller's exposed state arrays and
  timer context; timer bars are delegated below.
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
- `scripts/core/stage_clear_result_screen.gd`
  Owns the battle-flow handoff for the stage-clear result screen shown
  after a player match win. It reads the scoreboard snapshot, builds the
  reward-preview plan, instantiates `scenes/stage_clear_result.tscn` as a
  child of the battle scene, blocks battle update while active, forwards
  input, delegates reward rolls to `stage_clear_reward_resolver.gd`, grants
  resolved box rewards once on result confirmation, and delays the normal
  match-reset callback until confirmation.
  Registered as `stage_clear_result_screen`.
- `scripts/core/stage_clear_reward_resolver.gd`
  Owns stage-clear chest reward selection and final grant dispatch. Normal
  chests use the active / passive / starpoint lanes, mythic chests use the
  mythic lane, and final confirmation routes rewards through the existing
  active-item, passive/mythic-item, and runtime-perk starpoint systems.
  Registered as `stage_clear_reward_resolver`.
- `scenes/stage_clear_result.tscn` +
  `scripts/ui/stage_clear_result_scene.gd`
  Own the visible fullscreen result scene: Stage 1 result-background
  drawing, Dalji defeated cutscene sheet playback, player victory-side
  sheet playback, score-based reward chest animation, result scroll input,
  result scroll drawing, and scene-local linear texture filtering for
  cutscene art. Result-scroll reward summary arrays, source counts,
  perk-info tile payloads, starpoint totals, and perk reward ID
  classification are delegated to `stage_clear_result_summary_builder.gd`;
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
  `stage_clear_result_layout_helper.gd`; result reward pickup / Live2D
  target position pairing for mythic acquisition cinematics is delegated to
  `stage_clear_result_cinematic_position_helper.gd`; centered text
  baseline, word wrapping, and font-size fitting helpers are delegated to
  `stage_clear_result_text_layout_helper.gd`; result scroll phase
  progression, unfurl progress, and background box alpha are delegated to
  `stage_clear_result_scroll_state.gd`; result button layout / hit state
  and box opened / opening counts are delegated to
  `stage_clear_result_interaction_state.gd`; reusable ellipse / radial /
  star polygon point generation plus result-box ornament / hover geometry
  is delegated to `stage_clear_result_shape_helper.gd`; player-victory
  and Dalji
  click-reaction frame / transition / alpha math is delegated to
  `stage_clear_result_click_reaction_state.gd`. Keep future reward-pick
  animation / settlement UI work here rather than adding draw blocks back
  to the battle shell; do not put grant logic back in this UI scene.
- `scripts/ui/stage_clear_result_asset_loader.gd`
  Owns stage-clear result asset loading and staged prewarm dispatch:
  result background / scroll / chest sheets, Dalji and player-victory
  sheets, Dalji click voice, and result-box FX prewarm. The scene still
  owns the loaded texture / stream fields and decides when to load or
  prewarm.
- `scripts/ui/stage_clear_result_layout_helper.gd`
  Owns stateless stage-clear result layout and frame policy helpers:
  floating chest anchor layouts, result-box safe-frame selection, reward
  section card grid fitting, sheet cell source-rect calculation, and
  cover-fit source cropping, plus floating-box draw centers, hover AABBs,
  point rotation, player-victory actor / click / panel rects, Dalji draw
  rects, scroll-content margins, and cinematic-local coordinate conversion.
  The scene still owns live timers, hover / click state, drawing, texture
  loading, reward rolling, and callbacks.
- `scripts/ui/stage_clear_result_cinematic_position_helper.gd`
  Owns stateless stage-clear result cinematic position assembly for
  immediate mythic reward grants: floating result-box pickup points,
  player-victory Live2D target points, field-local conversion, and field
  clamping. The scene still owns live size / scale lookup, reward mutation,
  and the immediate-grant callback.
- `scripts/ui/stage_clear_result_scroll_state.gd`
  Owns stateless stage-clear result scroll progression helpers: hidden /
  delay / unfurling / visible phase transitions, gate-aware update
  blocking, smooth unfurl progress, and fading the floating boxes behind
  the opened scroll. The scene still owns the live box array, perk-choice
  and starpoint-choice gates, input, drawing, and confirmation callbacks.
- `scripts/ui/stage_clear_result_interaction_state.gd`
  Owns stateless stage-clear result interaction calculations: scroll-button
  layout rects, button hover / visible-click hit classification, opened /
  opening box counts, and all-boxes-open checks. The scene still owns
  actual input consumption, callback dispatch, hover redraw requests, live
  box mutation, and drawing.
- `scripts/ui/stage_clear_result_shape_helper.gd`
  Owns stateless result-scene shape point generation: ellipse fill
  polygons, ellipse polylines, radial burst polygons, star polygons, and
  closed polyline conversion, plus result-box hover glow / sparkle
  geometry. The scene still owns actual draw calls, colors, alpha gates,
  and animation timing.
- `scripts/ui/stage_clear_result_click_reaction_state.gd`
  Owns stateless result-scene click-reaction animation math shared by the
  player victory and Dalji result sheets: base frame selection, reaction
  frame selection, captured-base transition frame selection, reaction
  alpha including return hold / fade, active checks, and return-blend
  checks. The scene still owns click input, timers, captured transition
  frames, voice playback, sheet textures, and actual drawing.
- `scripts/ui/stage_clear_result_summary_builder.gd`
  Owns stateless stage-clear result summary assembly for the UI scene:
  stage-vs-box reward source tagging, item / perk / visible reward arrays,
  reward-source count payloads, perk-info tile payloads, box starpoint
  totals, stage-summary array duplication, and perk reward ID
  classification. The scene still owns
  reward rolling, final grant callbacks, scroll/button input, drawing, and
  the live perk catalog instance used by reward text resolution.
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
  Owns stateless stage-clear result text measurement helpers: centered
  baseline calculation, word wrapping to width / max-lines, and font-size
  fitting. The scene still owns all actual text drawing, localized copy,
  and shadow / color choices.
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
  ice movement-control penalties plus dash slide, rain movement slow, hail
  collision knockback / dash destruction, four-side sand terrain collision /
  erosion, and harvest/force-end hooks used by weather-absorbing items such
  as Baal's Boots. It also exposes weather particles and sand visual
  segments to the renderer; keep gameplay mutation here rather than in draw
  code.
- `scripts/stages/common/weather_event_renderer.gd`
  Owns the common weather-event field VFX pass. It reads the weather state
  through public context / particle / sand-segment snapshots and draws
  layered texture pieces for rain streaks, wind ribbons, fire embers, ice
  glints, hail shards, scanline messages, and sand-wall texture fills.
  Future sprite-sheet or shader upgrades should replace this renderer's
  texture pieces without moving the gameplay rules out of
  `weather_event_state.gd`.
- `scripts/stages/stage1/stage1_pillar_background.gd`
  Owns the layered Stage 1 pillar background port: base hanji texture,
  texture loading, draw composition, and delegation to focused Stage 1
  pillar layer renderers / ambient state.
- `scripts/stages/stage1/stage1_pillar_ambient_state.gd`
  Owns Stage 1 pillar ambient runtime state: butterflies, wall-impact
  tree shakes, layout snapshots, and ambient update orchestration.
- `scripts/stages/stage1/stage1_pillar_petal_state.gd`
  Owns Stage 1 pillar ambient floating-petal runtime state: layout memory
  for pillar spawn regions, floating petal spawning, motion integration,
  lifetime trimming, and delegation to the tree-drop petal state.
- `scripts/stages/stage1/stage1_pillar_tree_drop_petal_state.gd`
  Owns Stage 1 wall-impact tree-drop petal bursts: tree-rect spawn
  positioning, burst velocity setup, gravity / sway motion integration,
  lifetime trimming, and max-count capping.
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
- `scripts/stages/stage1/stage1_commando_firearm_fx_host.gd`
  Owns the node-backed Stage 1 Commando firearm FX host: a `ShaderMaterial`
  core glow, muzzle and impact `GPUParticles2D` layers, shared procedural
  texture-piece prewarm, playfield-local anchor selection, shake-offset
  application, pre-tree sync preservation, and pulse `Tween` lifecycle.
- `scripts/stages/stage2/stage2_pillar_assets.gd`
  Owns the Stage 2 pillar-background asset surface: the six imagegen
  texture `res://` paths (`BASE`, `TREE`, `GAME_FRAME`, `LEAF`, `ROCK`,
  `ROCK_DEBRIS`), measured static source-region constants
  (`TREE_SOURCE_REGION_DATA`, `LEAF_SOURCE_REGION_DATA`,
  `GAME_FRAME_SOURCE_HOLE`), the rock atlas grid sizes
  (`ROCK_ATLAS_COLUMNS` / `ROCK_ATLAS_ROWS`), and the pure
  `slice_alpha_atlas_regions(path, columns, rows, padding)` helper that
  trims each cell of a packed atlas to its alpha bounds with a small
  padding margin. No runtime state. `stage2_pillar_background.gd`
  preloads this module and forwards every texture-path / source-region /
  slicing call here so the background owner script can stay focused on
  state machines and rendering.
- `scripts/stages/stage2/stage2_pillar_background.gd`
  Owns the Stage 2 outer-pillar background slice: the original Python
  imagegen jungle/cyber texture loading, ambient falling-leaf sheet, and
  firefly layer, with the procedural jungle-panel fallback kept only for
  missing assets. Texture paths, source-region constants, and the alpha
  atlas slicer live in `stage2_pillar_assets.gd`; the background module
  preloads it and stores the loaded `Texture2D` and per-cell region
  arrays in its own member vars (`base_texture`, `tree_source_regions`,
  ...) so existing field readers keep working unchanged. Imagegen base
  cover, split left / right tree sprites, unified edge lines, and stretch-
  composed moss / leaf game-frame drawing are delegated to
  `stage2_pillar_imagegen_renderer.gd`; imagegen pillar renderer asset
  payloads are delegated to `stage2_pillar_imagegen_assets_builder.gd`;
  imagegen asset-ready snapshots are delegated to
  `stage2_imagegen_asset_status_builder.gd`. It also owns the
  first Stage 2 wall-hit reaction state:
  border flash and short-lived leaf particles triggered through the shared
  `trigger_tree_shake()` hook. The current MVP also owns Stage 2 temporary
  crisis-rock list reset / drawing and basic rock-vs-ball reflection. It also
  owns the first 악어장군 water-cannon MVP: delayed post-quake target
  selection, charge/fire VFX, hydro / stone-break / rock-hit audio cues,
  splash fragments, hittable rock-fragment knockback, red hit flash
  feedback, compact playfield boss-skill warning banners, quake ball-motion
  shake / boss-launch backstop behavior, player-hit quake cancellation,
  quake-loop audio start / stop sync through `game_audio.gd`, rock-spawn
  audio, falling quake-rock presentation / landed-only collision timing,
  crisis-score rage reservation, round-start boss stomp presentation,
  rage actor tint / offset draw context, defensive rock-wall drops, target
  rock removal, golden-rock starpoint drops / Star Detector bonus drop
  handoff, and the boss score-expression API exposed to the Stage 2 actor /
  playfield renderers. The short-lived boss score-expression state is
  delegated to `stage2_boss_expression_state.gd`. Actor draw-context payload
  construction is delegated to `stage2_actor_draw_context_builder.gd`.
  Base boss-AI context payload construction is delegated to
  `stage2_boss_ai_context_builder.gd`. Boss-rage snapshots are delegated
  to `stage2_boss_rage_snapshot_builder.gd`; boss-rage crisis gating,
  tint / offset visual timing, final-stomp threshold checks, and finish
  checks are delegated to `stage2_boss_rage_state.gd`. BattlePerf overlay /
  obstacle counter label writes are delegated to
  `stage2_perf_counter_recorder.gd`.
  Rock / rock-fragment /
  starpoint particle and drop drawing is delegated to
  `stage2_pillar_obstacle_visual_renderer.gd`; water-cannon target rings,
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
  quake loop and boss-rage cry audio routing is delegated to
  `stage2_audio_router.gd`;
  skill-warning timer / text state is delegated to
  `stage2_skill_warning_state.gd`;
  border-flash and boss-rage screen tint drawing is delegated to
  `stage2_screen_overlay_visual_renderer.gd`; border-flash timer / impact
  snapshot state is delegated to `stage2_border_flash_state.gd`;
  falling-leaf / firefly / leaf-particle and rustle vegetation drawing is
  delegated to `stage2_ambient_visual_renderer.gd`.
  Ambient leaf / firefly / leaf-particle payload generation is delegated
  to `stage2_ambient_payload_factory.gd`; ambient layout freshness,
  initial population, and falling-leaf spawn cadence helpers are delegated
  to `stage2_ambient_layout_helper.gd`; ambient visual count snapshots are
  delegated to `stage2_ambient_visual_snapshot_builder.gd`;
  falling-leaf, firefly, and leaf-particle per-frame motion is delegated to
  `stage2_ambient_visual_state.gd`;
  rustle bush / vine layout
  payload generation is delegated to `stage2_rustle_payload_factory.gd`;
  rustle trigger / decay mutation and side-wall band predicates are delegated
  to `stage2_rustle_state.gd`; rustle active-count snapshots are delegated
  to `stage2_rustle_snapshot_builder.gd`.
  Rock visual payload generation is delegated to
  `stage2_rock_visual_factory.gd`; rock renderer asset payloads are
  delegated to `stage2_rock_visual_assets_builder.gd`; short-lived rock
  visual runtime timers / water-target flash mutation are delegated to
  `stage2_rock_runtime_state.gd`; rock dictionary
  lookup / landed / center / target queries are delegated to
  `stage2_rock_query.gd`;
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
  `stage2_rock_fragment_payload_config_builder.gd`; rock-fragment per-frame
  motion is delegated to `stage2_rock_fragment_motion_state.gd`.
  Starpoint drop / particle payload generation is delegated to
  `stage2_starpoint_visual_factory.gd`; starpoint drop per-frame motion is
  delegated to `stage2_starpoint_drop_motion_state.gd`; starpoint drop
  player-overlap query is delegated to `stage2_starpoint_drop_query.gd`;
  starpoint particle
  per-frame physics / compacting is delegated to
  `stage2_starpoint_particle_state.gd`.
  Water-cannon fragment / splash payload generation is delegated to
  `stage2_water_cannon_payload_factory.gd`; water-cannon factory config
  payloads are delegated to
  `stage2_water_cannon_payload_config_builder.gd`; water-cannon renderer
  visual-state payloads are delegated to
  `stage2_water_cannon_visual_state_builder.gd`; water-cannon start-point
  geometry and context-to-start-point assembly is delegated to
  `stage2_water_cannon_geometry.gd`; water-trail
  payload generation is delegated to `stage2_water_trail_payload_factory.gd`;
  water-trail / splash visual state decay and compaction is delegated to
  `stage2_water_visual_state.gd`. Stage 2
  performance sample accumulation and opt-in logging is delegated to
  `stage2_perf_logger.gd`; performance log contextual snapshots are
  delegated to `stage2_perf_log_snapshot_builder.gd`; render-budget array
  trimming, recent-entry start indexes, and LOD count decisions are delegated
  to `stage2_render_budget_helper.gd`; visible-effect / playfield draw-gate
  and boss movement-lock boolean composition is delegated to
  `stage2_visibility_state.gd`.
  Stage 2 ball / player overlap geometry and context-to-player-rect helpers are delegated to
  `stage2_collision_geometry.gd`; Chaos Spear rock-pull motion is delegated
  to `stage2_chaos_rock_absorb_state.gd`; playfield bounds lookup is
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
  measured game-frame source hole. The background module still owns
  texture loading, source-region storage, game-frame hole caching, and
  renderer handoff.
- `scripts/stages/stage2/stage2_imagegen_asset_status_builder.gd`
  Owns the read-only Stage 2 imagegen asset status payload: base, tree,
  game-frame, leaf, rock, and rock-debris readiness booleans. The
  background module still owns texture loading, source-region storage, and
  lazy `_ensure_textures()` timing.
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
  lookup, context-to-player-rect assembly, and Warp Gate mirror interaction
  rect expansion.
  `stage2_pillar_background.gd` still owns collision timing, rock HP
  mutation, starpoint collection, water-fragment hit effects, and status
  immunity handling.
- `scripts/stages/stage2/stage2_playfield_bounds.gd`
  Owns Stage 2 stateless playfield bounds lookup from draw / update
  context: left edge, right edge fallback, and height fallback.
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
  The background module still owns texture loading, region slicing, lazy
  preload timing, live rock arrays, and renderer fanout.
- `scripts/stages/stage2/stage2_quake_rock_payload_factory.gd`
  Owns Stage 2 quake-rock spawn payload assembly: falling start position,
  target position, stagger frames, gravity / bounce fields, radius, seed /
  phase metadata, and merging visual data. The background module still owns
  list insertion, leaf bursts, and spawn audio.
- `scripts/stages/stage2/stage2_quake_rock_spawn_factory.gd`
  Owns Stage 2 random quake-rock spawn batches: target candidate selection,
  spacing retry against existing / newly-spawned rocks, size / fall-height /
  seed / golden rolls, visual payload handoff, sequential rock-id assignment,
  and next-id return. The background module still owns live array insertion,
  leaf bursts, water-cannon scheduling, and spawn audio.
- `scripts/stages/stage2/stage2_crisis_rock_wall_payload_factory.gd`
  Owns Stage 2 boss-rage crisis-wall rock payload assembly: lane target
  selection, falling start position, scaled collision radius, drop stagger /
  timer fields, seed / phase metadata, and rock visual data merging. The
  background module still owns wall activation, live array reset / insertion,
  rock-id allocation, water-cannon deferral, leaf bursts, warnings, and spawn
  audio.
- `scripts/stages/stage2/stage2_quake_rock_drop_state.gd`
  Owns Stage 2 quake-rock drop and bounce mutation helpers for both the
  original frame-stepped falling rocks and timed drop payloads. The
  background module still owns target lookup, list iteration, leaf bursts,
  quake lifecycle, and renderer fanout.
- `scripts/stages/stage2/stage2_quake_rock_offset_state.gd`
  Owns Stage 2 quake-rock visual offset state: inactive offset decay, active
  quake intensity tapering, size / falling scale, and deterministic
  sinusoidal offset composition. The background module still owns quake
  timers, rock list iteration, rock centers, and renderer fanout.
- `scripts/stages/stage2/stage2_water_cannon_visual_renderer.gd`
  Owns the stateless Stage 2 water-cannon draw pass: target-rock
  highlight rings, beam charge / firing visuals, water trail circles,
  stone / water splash presentation, and the red fragment-hit screen
  flash. It receives the background-owned phase / timer / target
  dictionary and the existing rock-debris visual renderer for imagegen
  stone fragments; it does not select targets, advance timers, spawn
  fragments, collide with the player, cancel skills, or trigger audio.
- `scripts/stages/stage2/stage2_water_cannon_visual_state_builder.gd`
  Owns the read-only Stage 2 water-cannon renderer state payload: phase,
  start / target / current beam points, progress, timer, charge duration,
  and trail lifetime. The background module still owns lifecycle updates,
  target selection, trail arrays, constants, and renderer handoff.
- `scripts/stages/stage2/stage2_water_cannon_geometry.gd`
  Owns the stateless Stage 2 water-cannon geometry helper for deriving the
  boss muzzle / start point from boss position and hitbox size, including
  the context-to-start-point adapter. The background module still owns
  target selection, phase lifecycle, and renderer handoff.
- `scripts/stages/stage2/stage2_fragment_hit_flash_state.gd`
  Owns Stage 2 water-fragment player-hit flash state: duration, active
  timer, reset, trigger, and decay. `stage2_pillar_background.gd` still
  owns water-fragment collision, player knockback / immunity effects, and
  passing timer values to `stage2_water_cannon_visual_renderer.gd`.
- `scripts/stages/stage2/stage2_water_fragment_hit_resolver.gd`
  Owns Stage 2 water-fragment player-hit candidate resolution: hit-enabled
  filtering, per-splash cooldown decay, collision radius selection, first
  overlapping player rect lookup, and hit payload construction. The
  background module still owns player-rect context assembly, immunity,
  flash, particles, audio, knockback, and splash handled-state side effects.
- `scripts/stages/stage2/stage2_water_trail_payload_factory.gd`
  Owns Stage 2 water-cannon trail payload construction: randomized offset,
  life fields, radius scaling by beam progress, and trail color. The
  background module still owns water-trail spawn timing, max-count pruning,
  and renderer fanout.
- `scripts/stages/stage2/stage2_water_visual_state.gd`
  Owns Stage 2 water-cannon trail / splash visual state mutation: trail
  lifetime compaction, splash lifetime, gravity, damping, position, spin,
  and in-place survivor compaction. The background module still owns
  water-cannon phase timing, spawn timing, player-hit collision / side
  effects, list caps, and renderer fanout.
- `scripts/stages/stage2/stage2_water_cannon_payload_factory.gd`
  Owns Stage 2 water-cannon impact payload construction: stone fragment
  dictionaries, water splash dictionaries, sprite-index selection, and
  initial velocity / radius / gravity / life fields.
  `stage2_pillar_background.gd` still owns target resolution, rock
  removal, list pruning, player collision / knockback, warnings, audio, and
  reward routing.
- `scripts/stages/stage2/stage2_water_cannon_payload_config_builder.gd`
  Owns the read-only Stage 2 water-cannon factory config payload: stone
  fragment / water splash counts, lifetimes, and gravity values. The
  background module still owns the constants, target resolution, impact
  lifecycle, list pruning, per-frame splash update, collision / knockback,
  warnings, audio, and reward routing.
- `scripts/stages/stage2/stage2_warning_visual_renderer.gd`
  Owns the stateless Stage 2 warning draw pass: quake-wave line ribbons
  and the compact boss-skill warning banner. It receives timer / duration /
  kind / text dictionaries from `stage2_pillar_background.gd`; it does not
  trigger warnings, advance timers, affect ball physics, or mutate stage
  state.
- `scripts/stages/stage2/stage2_quake_wave_visual_state_builder.gd`
  Owns the read-only Stage 2 quake-wave renderer state payload: timer,
  duration, ball-affecting vs visual-only state, and normal / visual-only
  wave count and segment constants. The background module still owns quake
  lifecycle, ball physics, audio, screen shake, and renderer handoff.
- `scripts/stages/stage2/stage2_quake_screen_shake_state.gd`
  Owns Stage 2 quake screen-shake offset calculation from quake timer,
  duration, and the injected motion RNG. The background module still owns
  quake lifecycle, the RNG instance / seed, feedback dispatch, audio, and
  ball physics.
- `scripts/stages/stage2/stage2_quake_ball_motion_state.gd`
  Owns Stage 2 quake ball-motion stateless helpers: impulse-scale tapering,
  player-center pull, original speed-cap enforcement, and boss-launch guard
  safety-band / minimum downward-speed math. The background module still
  owns quake lifecycle, ball velocity backup / restore, boss-launch guard
  timer storage, RNG shake injection, and scene mutation timing.
- `scripts/stages/stage2/stage2_audio_router.gd`
  Owns Stage 2 gameplay-audio routing helpers for quake loop start / stop /
  sync, boss-rage cry playback, rock spawn / break / hit cues, water-cannon
  hydro cues, and starpoint collection cues, including the cached rage-audio
  fallback used during pre-rally animations. `stage2_pillar_background.gd`
  still owns quake lifecycle state, the cached audio handle, and when cues
  are emitted.
- `scripts/stages/stage2/stage2_skill_warning_state.gd`
  Owns Stage 2 skill-warning state: trigger text / kind, minimum duration
  clamp, timer decay, active checks, reset, and renderer snapshot payload.
  `stage2_pillar_background.gd` still owns when warnings are triggered and
  passes the snapshot to `stage2_warning_visual_renderer.gd`.
- `scripts/stages/stage2/stage2_screen_overlay_visual_renderer.gd`
  Owns the stateless Stage 2 screen-overlay draw pass for border-hit
  flashes and boss-rage tint rectangles. It receives timer / side /
  impact-Y / tint snapshots from `stage2_pillar_background.gd`; it does
  not trigger wall-hit reactions, advance rage timers, alter actor tint,
  or mutate gameplay state.
- `scripts/stages/stage2/stage2_border_flash_state.gd`
  Owns Stage 2 border-flash state: duration, active timer, side, impact-Y
  snapshot, reset, and decay. `stage2_pillar_background.gd` still owns the
  `trigger_tree_shake()` hook, bush / leaf reactions, and overlay renderer
  fanout.
- `scripts/stages/stage2/stage2_ambient_visual_renderer.gd`
  Owns the stateless Stage 2 ambient draw pass for falling-leaf sprites /
  fallbacks, firefly glow dots, wall-hit leaf particles, and bush / vine
  rustle visuals. It receives runtime arrays and texture references from
  `stage2_pillar_background.gd`; it does not spawn leaves, build the
  rustle layout, update rustle reactions, decay particles, update
  fireflies, or mutate gameplay state.
- `scripts/stages/stage2/stage2_ambient_payload_factory.gd`
  Owns Stage 2 ambient payload construction for viewport-side falling
  leaves, fireflies, and leaf particles emitted by wall / rock reactions.
  `stage2_pillar_background.gd` still owns ambient layout invalidation,
  falling-leaf / firefly update orchestration, particle pruning, rustle
  state, and renderer fanout.
- `scripts/stages/stage2/stage2_ambient_visual_state.gd`
  Owns Stage 2 ambient per-frame visual mutation for falling leaves and
  fireflies plus short-lived wall-hit leaf particles: y / sway / rotation
  advancement, off-layout leaf compaction, firefly drift / side wrapping,
  particle gravity / damping / life decay, and particle compaction. The
  background module still owns layout size fields, spawn cadence, rustle
  state, and
  renderer fanout.
- `scripts/stages/stage2/stage2_ambient_layout_helper.gd`
  Owns Stage 2 ambient layout helper decisions: current-layout matching,
  initial falling-leaf / firefly population, falling-leaf spawn chance, and
  max-count guarded leaf append. The background module still owns the live
  ambient arrays, layout size fields, update orchestration, particle
  pruning, rustle state, and renderer fanout.
- `scripts/stages/stage2/stage2_ambient_visual_snapshot_builder.gd`
  Owns the read-only Stage 2 ambient visual snapshot counts for falling
  leaves, fireflies, and available leaf sprites. The background module
  still owns texture / layout readiness, ambient arrays, particle updates,
  and renderer fanout.
- `scripts/stages/stage2/stage2_rustle_payload_factory.gd`
  Owns Stage 2 rustle layout payload construction: fixed bush anchors,
  height-dependent player-side bush positions, vine anchors, and initial
  amount / angle / phase fields. `stage2_pillar_background.gd` still owns
  layout invalidation, paddle-proximity trigger orchestration, snapshots,
  and renderer fanout.
- `scripts/stages/stage2/stage2_rustle_state.gd`
  Owns Stage 2 rustle state mutation helpers: side-wall bush-band impact
  predicates, bush / vine paddle-proximity trigger mutation, decay, and
  active-visibility checks. `stage2_pillar_background.gd` still owns
  layout invalidation, paddle-position history, trigger orchestration,
  snapshots, and renderer fanout.
- `scripts/stages/stage2/stage2_rustle_snapshot_builder.gd`
  Owns Stage 2 rustle snapshot construction: active bush count, active
  player / boss bush counts, and active vine count. The background module
  still owns trigger orchestration, snapshots, and renderer fanout.
- `scripts/stages/stage2/stage2_rock_visual_factory.gd`
  Owns the Stage 2 rock visual payload factory: style selection, style
  color arrays, seeded fixed polygon points, visual radius, rock seed, and
  initial rotation. `stage2_pillar_background.gd` still owns actual rock
  spawning, collision, HP, life, golden-drop behavior, fragments, and
  audio.
- `scripts/stages/stage2/stage2_rock_query.gd`
  Owns Stage 2 rock dictionary query helpers: id lookup, landed checks,
  runtime-update predicates, random id selection for water-cannon targeting,
  target position, render / collision center, center mutation, and
  spawn-spacing distance tests.
  `stage2_pillar_background.gd` still owns rock array mutation, spawning,
  HP / collision, quake drop updates, and golden-drop behavior.
- `scripts/stages/stage2/stage2_rock_runtime_state.gd`
  Owns Stage 2 short-lived rock visual runtime mutation: hit flash decay,
  water-cannon target flash decay / mark / clear, and phase advancement.
  `stage2_pillar_background.gd` still owns rock list iteration, spawning,
  HP / collision, quake drop updates, golden-drop behavior, and renderer
  fanout.
- `scripts/stages/stage2/stage2_rock_fragment_payload_factory.gd`
  Owns Stage 2 normal rock-fragment payload construction after quake /
  crisis rocks break: fragment count, radial velocity, source sprite index,
  fallback color, size, rotation, spin, gravity, life, and bounce fields.
  `stage2_pillar_background.gd` still owns rock HP / collision, break
  routing, golden-rock rewards, list pruning, and draw fanout.
- `scripts/stages/stage2/stage2_rock_fragment_payload_config_builder.gd`
  Owns the read-only Stage 2 normal rock-fragment factory config payload,
  currently the fragment lifetime override. The background module still
  owns the lifetime constant, rock break routing, and fragment list pruning.
- `scripts/stages/stage2/stage2_rock_fragment_motion_state.gd`
  Owns Stage 2 rock-fragment per-frame mutation: lifetime decay, gravity,
  floor bounce / horizontal damping, position, rotation, and survivor
  compaction. The background module still owns fragment spawning, list caps,
  renderer fanout, and rock break / reward side effects.
- `scripts/stages/stage2/stage2_starpoint_visual_factory.gd`
  Owns the Stage 2 starpoint payload factory: initial drop velocity /
  rotation / glow fields and burst particle dictionaries. The background
  module still owns golden-rock gating, Star Detector bonus count and
  bounds clamp, drop collection, score/perk rewards,
  redraw requests, and collect audio.
- `scripts/stages/stage2/stage2_starpoint_drop_motion_state.gd`
  Owns Stage 2 starpoint drop per-frame mutation: lifetime decay, float
  wobble, velocity / gravity, horizontal bounds bounce, rotation, glow
  timing, and alive / expired return. The background module still owns
  drop list compaction, collection rewards, redraw requests, and collect
  audio.
- `scripts/stages/stage2/stage2_starpoint_drop_query.gd`
  Owns Stage 2 starpoint drop read-only query helpers: collect-radius
  derivation and player-rect overlap checks through the shared collision
  geometry helper. The background module still owns player-rect source
  construction, drop list compaction, collection rewards, redraw requests,
  and collect audio.
- `scripts/stages/stage2/stage2_starpoint_particle_state.gd`
  Owns Stage 2 starpoint particle per-frame mutation: position, gravity,
  alpha fade, lifetime decay, and in-place survivor compaction. The
  background module still owns particle spawning, drop collection timing,
  render fanout, and audio / reward side effects.
- `scripts/stages/stage2/stage2_chaos_rock_absorb_state.gd`
  Owns Stage 2 Chaos Spear rock-pull motion math: destroy-threshold checks,
  angular velocity, radial pull speed, next-center calculation, rotation /
  phase mutation, and destroyed/moved result payloads. The background module
  still owns landed-rock selection, center writes through `stage2_rock_query`,
  fragment / leaf / starpoint side effects, break audio, and absorbed-entry
  emission.
- `scripts/stages/stage2/stage2_monkey_banana_event.gd`
  Owns the Stage 2 original monkey-banana side event: first spawn after
  5-10 seconds, repeat spawns after 15-30 seconds, left/right outer-tree
  monkey climb / sit / throw / leave state, 1.5-3.0 second throw wait,
  player 40% vs boss 60% banana targeting, 1-second arced banana flight,
  2-second landed peel window, burst particles, banana throw / slip audio,
  player slip / dash-wall-slip movement, and boss-control-loss slip context
  consumed by `boss_ai_state.gd`. Monkeys draw in the Stage 2 pillar pass;
  flying and landed bananas draw in the transformed playfield pass. The
  climb path follows the same imagegen-tree alpha-median trunk sampling
  used by the Python reference, mapped through the live Stage 2 tree rect.
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
  and water-cannon phase fields. The background module still owns the
  movement-lock predicate and water-cannon phase lifecycle; the boss skill
  state may add skill-specific AI fields on top of this base context.
- `scripts/stages/stage2/stage2_boss_rage_snapshot_builder.gd`
  Owns the read-only Stage 2 boss-rage snapshot payload: pending / active
  flags, timer, stomp count, final-stomp flag, actor Y offset, and tint.
  The background module still owns rage lifecycle updates, stomp emission,
  crisis reservation, and renderer handoff.
- `scripts/stages/stage2/stage2_boss_rage_state.gd`
  Owns stateless Stage 2 boss-rage predicates and visual timing math:
  crisis trigger gating, inactive tint / offset decay, active rage tint /
  offset calculation, buildup stomp-step windows / offsets, final-stomp
  threshold checks, and finish checks.
  `stage2_pillar_background.gd` keeps the mutable pending / active flags,
  timers, stomp / quake / rock-wall side effects, audio / feedback
  emission, and snapshot publication.
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
- `scripts/stages/stage2/stage2_pillar_scene_drawer.gd`
  Owns Stage 2 outer-scene pillar composition for the initial port slice.
  It draws the Stage 2 pillar background, temporarily reuses the current
  Stage 1 active-item / pillar HUD scene drawer, and composes the Stage 2
  boss-skill HUD renderer in the post-playfield HUD pass.
- `scripts/stages/stage2/stage2_actor_renderer.gd`
  Owns the public Stage 2 playfield / actor draw entry point for the first
  MVP slice. It delegates the jungle court to `stage2_playfield_renderer`,
  reuses the shared Smasher player renderer, and draws the placeholder
  Stage 2 boss through `stage2_boss_actor_renderer`.
- `scripts/stages/stage2/stage2_playfield_renderer.gd`
  Owns the Stage 2 center playfield background: the original Python
  imagegen center-field source/fallback, crocodile center emblem, ball-
  tracking eye pupils, score expression overlays, boss-vine atlas layer,
  12 original bush anchors with paddle rustle, falling leaves, and the
  center electric line. The procedural jungle court remains only as the
  missing-asset fallback.
- `scripts/stages/stage2/stage2_boss_actor_renderer.gd`
  Owns the initial Stage 2 boss placeholder renderer. It draws an
  alligator-style boss silhouette from live boss position / facing,
  stage-owned rage tint / offset, score expression overlays, and
  contact-state context so Stage 2 can run before final boss sheets and
  boss-specific skills are ported. It also owns the speed-defense shield
  transform presentation and ghost trail draw path from the Stage 2 boss
  skill context.
- `scripts/stages/stage3/stage3_pillar_background.gd`
  Owns the Stage 3 outer Menhera plush frame map slice. It loads the
  Python reference imagegen assets copied under `godot/assets/sprites/hud/`,
  composes the full-screen cyber-menhera base, ambient sprite atlas, center
  frame pieces outside the live field, and floating side-pillar hearts.
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
  geometry, and the score-2 Kuromi awakening cracks / stone-fragment burst.
- `scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd`
  Owns the Godot Menhera Girl boss sprite port from
  `entities/menhera_boss_sprite.py`: six 4x2 source sheets, alpha-bbox
  frame trimming, Python-parity 176x88 bottom-aligned draw sizing,
  attack/dash/turn/victory/defeat priority, dash flip, turn hold/hop,
  boss-gauge red tint, ready aura, and psycho-ball afterimage trails.
- `scripts/stages/stage3/stage3_boss_skill_state.gd`
  Owns the Stage 3 Menhera boss skill runtime port: cooldown-only automatic
  scheduling for 70-second psycho ball, 25-second falling tears, and
  35-second curse chest, with the old boss-hit gauge gain disabled. It also
  owns psycho ball looping audio and ball curve/teleport handoff, falling
  tears with shared player slow status application, curse chest
  windup/throw/smoke/reverse/explosion lifecycle with
  capped dash-open smoke particles and the two-second curse control-reversal
  timer, Kuromi score-2 awakening trigger with the
  three-second pause, screen shake, one-shot audio, tail timing, and actor/HUD
  draw context. The Kuromi burst sound uses the
  original optional `sounds/stonebreak_large.wav` path and stays silent
  when that missing Python-reference asset is absent. It is reset from
  round, match, and stage-debug cleanup paths.
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
- `scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd`
  Owns the Stage 3 boss skill-card HUD slice. It exposes Menhera's tears,
  curse chest, and psycho ball as compact cooldown cards. Kuromi is not a
  Menhera Girl skill card; the separate Kuromi event/tail runtime stays out
  of this HUD. The old top-right wand gauge is suppressed for Stage 3's
  cooldown-only skill model. The HUD loads the generated
  `assets/sprites/stage3/menhera_boss_skill_cards_imagegen_v1.png` atlas
  first and falls back to procedural cards only if that PNG is missing.
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
  context, and moon-shoot audio timing.
- `scripts/stages/stage4/stage4_moon_event.gd`
  Owns the Stage 4 right-pillar moon render surface and compatibility API:
  white idle, red transform, and red burst sheet selection, six-frame
  slicing, pulse scale, red-moon active state reporting, red moon fragment
  volley spawning, fragment trail / impact draw context, player burn /
  knockback / gauge-drain collision, dash deflection toward the boss, and
  deflected-fragment boss stun / Ponk gauge damage.
- `scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd`
  Owns the initial Stage 4 Ponk boss placeholder renderer so the Stage 4
  route never falls through to the Stage 1 Dalji actor while final Ponk
  sprite sheets are still pending.
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
- `scripts/stages/stage4/stage4_ponk_skill_state.gd`
  Owns the first Stage 4 Ponk skill runtime slice: boss-hit gauge fill,
  meditation trigger / orbit / release, refraction magnetic-field loop,
  magnetic ball curvature, projectile launch / player slow collision, live
  gauge HUD context, boss skill-card metadata, actor VFX draw context, and
  the magnetic-field sheet under `godot/assets/sprites/stage4/`. It keeps
  magnetic and meditation gameplay timing here while delegating the
  node-backed visual remasters to `stage4_ponk_magnetic_fx_host.gd` and
  `stage4_ponk_meditation_fx_host.gd`. Loop sound cleanup stays
  registered through `gameplay_loop_audio_cleanup.gd`.
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
- `scripts/stages/stage5/stage5_hongryun_state.gd`
  Owns the first Stage 5 Hongryun runtime slice: Hongryun fireball counters,
  dragon-orb / inferno readiness state, ball-motion hijack query, boss-AI /
  actor-draw / boss-skill HUD context payloads, and the single cleanup core
  used by round-end, result-screen entry, and stage-leave reset paths.
- `scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd`
  Owns Stage 5 Hongryun's boss skill-card HUD presentation: fireball /
  inferno card stacking, fallback skill-card textures, tooltip copy,
  dragon-orb fractional slot overlay, and the inferno charge wedge. It reads
  only the `stage5_boss_skill_hud_*` context emitted by
  `stage5_hongryun_state.gd`.
- `scripts/stages/stage5/stage5_pillar_scene_drawer.gd`
  Owns the temporary Stage 5 pillar draw route while Hongryun-specific
  background / pillar art is still pending. It reuses the Stage 1 shared
  pillar HUD chrome and fallback background path, then adds the Stage 5
  Hongryun boss skill-card HUD in the post-playfield HUD pass.
- `scripts/stages/stage6/` — Stage 6 테트리서 / Tetriser cluster (port of Python
  Stage 7; Godot slot 6, see `docs/stage6_tetriser_port_plan.md`). Status:
  **complete through step 5c + boss sprite + background + pillar Tetris deco +
  crystal-shield boss skill; loading/result art pending**. Owners (9 modules):
  - `stage6_tetriser_state.gd` — single owner of boss gauge (max 500, 25/sec
    charge, round-persist via reset_round vs full reset), falling tetrominoes
    (assembly→fall→drift/rotate→settle), guard blocks (slide→active), edge tetro
    walls (per-cell), 초인테트리서 (gauge-drain transform, 2.0× body, super-flag
    + 1.7× cell tetrominoes), 2D central cube (3×3 solve→explode→rebuild),
    super laser melt + EMP, ball collision/reflection (`choose_reflection_axis`
    port) + dash/smoke/explosion destruction, debris, per-frame sound flags,
    Crystal Shield delegation, and the single `_clear_combat_state` cleanup core. Emits boss-AI / actor-draw
    / `stage6_boss_skill_hud_*` HUD context.
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
  - `stage6_tetriser_pillar_background.gd` — atmospheric arena backdrop
    (faithful procedural port of Python `AnimatedBackgroundStage7`): pulsing
    torch glows, sweeping light band, drifting motes, blue-purple border
    frame. Central cube is NOT drawn here (owned by the playfield renderer).
  - `stage6_tetriser_pillar_scene_drawer.gd` — background fanout + shared Stage 1
    pillar HUD chrome; draws the pillar Tetris deco between background and HUD;
    drives the boss skill-card HUD in `draw_post_playfield_hud` (merges state
    `get_hud_context`).
  - `stage6_tetriser_pillar_tetris.gd` — two self-playing Tetris wells in the
    screen letterbox margins (behavior port of Python `TetrisGame` /
    `TetriserPillarBackground`: auto-play, line clears, rainbow, NEXT preview).
    Visual deco only; Crystal Shield gameplay is owned by
    `stage6_tetriser_crystal_shield_state.gd`.
  - `stage6_tetriser_boss_skill_hud_renderer.gd` — 달지식 boss skill-card HUD
    (gauge + 낙하/가드/벽/초인 cards) via shared `BossSkillCardHudSpec`
    (procedural cards; tetriser skillcard textures pending).
  - Integration touch points: `stage_runtime_router` (role map), `stage_debug_picker`
    (id 6, reset keys, prewarm), `gameplay_stage_module_catalog` (7 keys),
    `battle_update_stage_runtime_deps_builder` / `battle_update_boss_ai_context_builder`
    (`current_stage == 6`), `battle_effects_update_controller` (state.update),
    `battle_draw_actor_context` (actor draw merge), `ball_update_controller`
    (`_process_stage6_tetromino_collision`), `battle_playfield_effects_drawer`
    (inactive-transient stage list incl. 6), `battle_scene_match_event_driver`
    (`DEMO_STAGE_SEQUENCE_END = 6`), `game_audio` (stage6 BGM ogg + break/wall/
    roar SFX), `battle_scene_update_prewarm_driver` (`STAGE6_RUNTIME_PREWARM_KEYS`).
  - Regression guard: `tests/stage6_tetriser_state_smoke.gd`,
    `tests/battle_scene_stage_transition_loading_smoke.gd`,
    `tests/battle_perf_logger_smoke.gd`, full warning/headless gate, and direct
    Stage 6 runtime serve capture.
- `scripts/stages/stage4/stage4_bird_event.gd` and
  `scripts/stages/stage4/stage4_brazier_monk_event.gd`
  Own the first Stage 4 event runtime slice. `stage4_bird_event` handles
  star-bird spawning, movement, gold-dust trails, catch positions, catch
  explosions, crow starpoint drops / pickup particles, and draw-context
  export. `stage4_brazier_monk_event` handles normal monk spawning, five
  smoke-grenade monks from the lit brazier, monk return timing, collapse
  cleanup explosions, staff-swing trigger / deflection timing, monk-hit
  effects, and draw-context export. The map-state and pillar
  background facades forward smoke / brazier, tear-gas expiry, star-bird
  collision, monk staff collision, moon-fragment collision, and draw-context
  access so shared active-item and ball-runtime code do not need to know the
  event storage details.
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
  charge / shoot / contact audio sync, homing plasma-wave VFX, boss slow
  context for AI movement plus shared boss slow status application,
  Stage 1 boss-gauge drain hook, and
  round/game-reset cleanup.
- `scripts/characters/smasher_recovery_state.gd`
  Owns the Godot Smasher Recovery port: W / Up edge activation only during
  dash recovery, 120-gauge / shared-cooldown spend, immediate dash-recovery
  timer cleanup, dash-delay sound cancel, `recovery.wav` cast cue, 18-frame
  green burst VFX, 5-second 30% movement-speed boost, `extension_gear`
  duration scaling, and round/game-reset cleanup.
- `scripts/characters/smasher_cleanse_state.gd`
  Owns the Godot Smasher Cleanse port: W / Up edge activation only while a
  player status effect is present, 100-gauge / shared-cooldown spend,
  `cleanse.wav` cast cue, current movement-knockback cleanup and immunity
  blocking, 30-frame purification wave / particles, 5-second immunity
  shield with `extension_gear` duration scaling, right-bottom timer-gauge
  feedback, 2-second one-hit counter speed bonus, skill-orb debuff-ready
  gating, and round/game-reset cleanup.
- `scripts/characters/smasher_warp_gate_state.gd`
  Owns the Godot Smasher Warp Gate port: S / Down 0.5-second hold
  activation, 100-gauge / 50-second shared cooldown spend, 20-second
  gate lifetime with `extension_gear` duration scaling, free wall-wrap
  transitions, offscreen movement bounds, mirrored player paddle collision /
  actor draw context, round-pause remaining-duration resume, copied
  `warpgate.wav` loop sync, copied 8x4 portal-effect sheet drawing with
  procedural fallback, right-bottom timer-gauge feedback, and
  round/game-reset cleanup.
- `scripts/characters/smasher_wheel_state.gd`
  Owns the Godot Smasher Wheel port: A->W->D / D->W->A edge-command
  activation, 200-gauge / 25-second shared cooldown spend, 1.2-second
  rolling movement mode with dash blocking, auto-roll direction, -15%
  max speed and slowed reverse acceleration, one-hit high-speed random
  curve relaunch with a difficulty-independent 60 effective-speed cap,
  non-drive spin state, 30 perk-gold skill reward,
  copied 8x4 wheel-effect sheet drawing with procedural fallback,
  drive-particle trail handoff, right-bottom timer-gauge feedback, and
  round/game-reset cleanup.
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
  `scripts/characters/runtime_perk_state.gd`, and
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
  Shared dash scaling perks now include `dash_acceleration` / 버스트업: the
  runtime state exposes level * 70% dash collision-height scaling and
  keeps effective Lv.6+ bonus sources live instead of hard-capping at
  the base Lv.5 card text.
  Common scaling perks now include `perk_laurel_shield` / 월계수잎; its
  effective level is exposed as a live leaf count and intentionally keeps
  scaling above Lv.5 when runtime perk-level bonuses apply.
  The overlay renderer owns the per-character filled card back glow used by
  runtime perk choice cards, and Stage 1 through Stage 4 starpoint collectors
  stop same-frame drop iteration when a collection opens a perk choice or
  clears the in-flight drop arrays.
  The battle scene shell only routes the public starpoint trigger, debug F8
  trigger, modal input,
  modal pause, and draw ordering.
- `scripts/characters/laurel_leaf_shield_state.gd`
  Owns the Godot 월계수잎 runtime shield: effective perk leaves plus future
  Sacred Laurel leaf bonuses, player-centered elliptical orbit timing,
  back-side-only ball collision, consumed-leaf 30-second regeneration,
  upward random-speed reflection, leaf break particles, draw-layered leaf
  visuals, `leaf.wav` audio feedback, match-reset cleanup, and ball-update
  collision handoff. This shield currently uses procedural CanvasItem leaf
  geometry and particles as a small parity-sized runtime effect rather than
  a generated sprite sheet.
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
  focused spinning-top renderer.
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
- `scripts/stages/stage1/stage1_dalji_spinning_top_renderer.gd`
  Owns the procedural Stage 1 Dalji spinning-top skill rendering:
  startup whip curves, wooden top bodies, rotating color discs, golden-top
  glow, boost brightening, shadows, tilt, and fade-out.
- `scripts/stages/stage1/stage1_balloon_event.gd`
  Owns the Stage 1 balloon-machine event port: timer-based machine
  phase state, balloon sprite-sheet loading, balloon motion / wall and
  paddle interaction, ball collision deflection, pop-effect rendering, and
  golden-balloon starpoint drop / paddle collection handoff to the runtime
  perk state.
  Its raw PNG sheets live under
  `godot/assets/sprites/stage1/balloon/`, with event sounds under
  `godot/assets/sounds/`.
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
- `scripts/ball/ball_intensity_effect_state.gd`
  Owns the public ball intensity effect facade: color fallback selection,
  low-intensity update gating, clear / update fanout, and renderer-facing
  particle / trail accessors.
- `scripts/ball/ball_intensity_particle_state.gd`
  Owns ball intensity particle runtime state: speed-scaled particle spawn,
  low-intensity particle drift, flame / spark decay, and
  intensity-dependent max-particle capping.
- `scripts/ball/ball_intensity_trail_state.gd`
  Owns ball intensity trail runtime state: trail point sampling,
  spacing-based interpolation, trail length capping, alpha fade, and size
  decay.
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
  and top/bottom score events. Stopwatch score-block context can suppress
  the bottom-score event while the time-stop / recovery window is active.
  The ball update controller owns the reactions to those events.
- `scripts/ball/ball_motion_collision_detector.gd`
  Owns ball motion collision tests used during sweep stepping: left/right
  wall clamping and impact positions plus player / boss paddle hitbox
  overlap snapshots, active Brick Wall overlap snapshots, and active Holy
  Barrier bottom-wall overlap snapshots. The player-paddle branch also
  consumes shared `dash_acceleration` context to vertically inflate only
  the collision hitbox during an active dash, matching the Python
  "visual paddle unchanged, hit range expanded" behavior.
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
  Owns paddle-hit particles and their player / boss color palette.
- `scripts/effects/impact_wall_effect_state.gd`
  Owns wall-impact flash timing, wall-impact position, and wall-impact
  particles.
- `scripts/effects/impact_energy_effect_state.gd`
  Owns energy explosions and Drive spark particles shared by ball and
  skill feedback paths.
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
  Owns battle sound setup and playback: paddle / wall hit cooldowns,
  serve and ping-pong serve sounds, dash and half-dash sounds, looping
  dash-recovery control-loss sound, active-item throw / grenade / flashbomb
  sounds, Drive / Power Smashing sounds, Dash Spirit delete sound, launch
  sound, Commando supply / fire-support radio and aircraft loops, Commando
  firearm-specific fire / impact cue wrappers, AK-47 rapid-fire layered
  player mixing, Horn Strawberry transform / eat / stem / field / horn /
  bomb-trigger dedicated cues, round-set sound, Stage 2 hydro / stone-break /
  rock-hit / rock-spawn / boss-cry / quake-loop cues, Stage 1 BGM looping
  with Python's per-track gain, pitch randomization, and audio-player factory
  delegation.
- `scripts/audio/gameplay_loop_audio_cleanup.gd`
  Owns the shared hard-stop list for non-BGM gameplay loop sounds across
  score events, scoreboard / serve-wait frames, round restart, ball reset,
  stage debug reset, and full game reset. New looped gameplay SFX must add
  their `stop_*` method here when they are introduced.
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
  update, draw, and public ball API behavior to registered modules. Module
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
  scoreboard frame does not pay the upload cost.
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
  this reader instead of duplicating owner property access logic.
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
  priming update context builders, and forwarding ball-update prewarm to
  the ball update driver so first serve does not pay the lazy-load cost.
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
  updates, game reset callbacks, match-flow dependency lookup, and handoff
  of reset results to `battle_scene_match_reset_result_applier.gd`. It is
  registered in the core module catalog so scoreboard / score-event
  callbacks use the same lazy-load and warmup path as other update drivers.
  Reset-result application prefers the registry-owned applier and falls
  back to an internal instance for direct unit callers.
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
  sprite texture references.
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
  flows, including Stage 1 Dalji skill/event states, Stage 2 boss skill
  state, and routed `stage_background` lookup with Stage 1 fallback.
- `scripts/core/battle_update_match_stage_runtime_deps_builder.gd`
  Keeps the match-flow stage-runtime dependency facade and delegates to
  the shared stage-runtime dependency builder.
- `scripts/resources/battle_resources.gd`
  Owns battle texture paths and loading: player / boss sprites, ball
  texture, orb / HUD frame textures, Smasher and Viper skill icon
  textures, and missing-resource warnings through the shared project
  resource loader. Round-result texture prewarm supports a one-frame delayed
  queue so score-event handling does not start threaded texture requests
  before the scoreboard has had a chance to draw.
  Smasher ball-contact attacks prefer the 4x2 `player_attack_sheet` when
  present, while legacy hit strips remain the fallback path. The scene
  bootstrap loads this map, while the battle scene state keeps the loaded
  texture dictionary and draw modules resolve texture keys through that
  shared resource map. Boss texture keys must keep attack and stun semantics
  separate; `boss_hit_sprite_sheet` is a legacy ball-contact attack alias,
  not a stun key.
- `scripts/resources/project_resource_loader.gd`
  Owns clean-clone-safe resource loading helpers: raw source PNG and WAV
  files are loaded directly when present, while imported Godot resources
  remain the fallback path. Texture, HUD, stage, and audio modules should
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
  Owns the full-screen score overlay canvas drawing: overlay layout,
  full-board frame placement, inner screen, footer target text, and
  delegation to the overlay frame / header / score-panel renderers.
- `scripts/hud/scoreboard_overlay_frame_renderer.gd`
  Owns the full-screen score overlay frame chrome: metal frame bands,
  bevel lines, drop shadow, corner bolts, and frame color helpers.
- `scripts/hud/scoreboard_overlay_header_renderer.gd`
  Owns the full-screen score overlay header: header panel chrome, player /
  boss logo orbs, glow halos, and PLAYER / BOSS labels.
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
  per-slot status overlays, visual bodies, and slot-context normalization
  to focused helpers. The Stage 1 active-item HUD scene drawer owns when to
  draw it and passes layout/state/visual modules into the renderer.
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
  Owns the first Commando `supply_drop` runtime slice: down-plus-action hold
  timing, radio-call transient state, delayed drop resolution, rental weapon
  candidate filtering, Godot-ported field-item candidate weights, Python
  `ammo_box` / `doping_potion` candidate eligibility rules, 1-3 payload
  queueing with duplicate rental reservation prevention, fallback field-item
  identity, supply-position collectible parachute boxes, direct player pickup,
  active-item pickup / slot-store handoff for field items,
  rejected-pickup retention, the aircraft / parachute / crash texture-piece
  remaster layers, `commando_supply_drop_fx_host.gd` shader /
  `GPUParticles2D` / pulse-Tween host synchronization, radio / aircraft /
  drop / pickup / explosion audio hooks,
  ball-update aircraft collision handoff,
  player-ball shootdown, player-paddle / Brick-wall aircraft collision,
  crash / explosion lifecycle, and round-boundary cleanup for the aircraft
  loop. Its save-snapshot surface restores active aircraft state, crash
  state, pending payload queues, and collectible parachute drops so a future
  integrated save file can resume the in-flight supply flow.
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
  pulse `Tween`. `commando_supply_drop_state.gd` remains the gameplay state
  owner and only synchronizes snapshots into this rendering host.
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
  weapon-feel QA.
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
  impact or support-aircraft audio bridges.
- `scripts/characters/commando_firearm_bowling_trap_geometry.gd`
  Owns pure Commando bowling-trap geometry, state payloads, and kinematic
  helpers: install position / payload / marker dictionaries, install and
  player-field eligibility, install / carryover / draw-state summary helpers,
  capture timer progression, capture result handoff, release motion and
  pseudo-projectile dictionaries, guard state / status / result payloads,
  guard ball-speed restoration, guard knockback side, deterministic launch
  direction, and trap-vs-ball rectangle hits. `commando_firearm_runtime.gd`
  now calls this owner directly for install position / trap payload / marker
  flash, install eligibility, active-install predicates, round carryover,
  capture result payloads, guard ball softening / knockback, launch direction,
  and trap-vs-ball hits while resolving Stage 2 guard-immunity inline without
  private runtime bridge helpers. It still keeps the trap array, ammo / cooldown
  gates, capture / release side effects, audio, VFX, status application, and
  guard state variable ownership.
- `scripts/characters/commando_firearm_control_state.gd`
  Owns pure Commando firearm control-state decisions: effect-update gating,
  player-control lock aggregation, and movement-speed multiplier calculation
  for AK-47 hold fire, hooked net fields, and active suicide-drone control.
  `commando_firearm_runtime.gd` keeps the actual timer / projectile / lingering
  state ownership and delegates only these boolean / scalar decisions.
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
  fields and reset timing while calling this owner directly from projectile-hit
  queueing and `update_effects()` result emission. Do not reintroduce private
  runtime queue / consume bridges for these pending-result paths.
- `scripts/characters/commando_firearm_profile_resolver.gd`
  Owns pure Commando firearm profile lookup behavior: weapon-id
  normalization, fallback profile selection, deep-copy protection,
  fire-support override application, and no-fallback lingering-effect
  lookup. The profile data tables stay in `commando_firearm_runtime.gd`, but
  runtime call sites now query this resolver directly instead of preserving
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
  without spawning a boss-impact flash. `stage1_balloon_event.gd` owns the
  actual balloon removal, pop VFX / audio, and special-balloon starpoint drop.
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
  snapshot fields plus active `dash_acceleration` level / height-bonus
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
  fail windows, and fail-timer reset.
- `scenes/main.gd`
  Is now only a one-line entry script that extends
  `res://scripts/core/battle_scene_shell.gd`.
- `scripts/core/boot_flow_scene.gd`
  Owns the Godot app-root boot flow inherited by `scenes/boot_flow.tscn`:
  startup penguin logo playback / skip input, fixed Stage 1 startup
  selection, logo-to-loading-to-character-select flow, one-shot
  battle-logo skip handoff, and transition into the character-select scene
  before battle.
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
  league mode, clamping the selected stage, and writing the selected
  character / runtime / display-name / AI-mode fields onto the battle owner.
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
- `scripts/core/battle_scene_overlay_input_controller.gd`
  Owns battle-scene overlay input after intro / warmup routing: F3 passive /
  mythic management toggles and menu controls, F4 runtime-perk picker
  toggles and menu controls, F5 debug stage picker toggles and menu
  controls, F6 weather picker toggles and menu controls, runtime perk choice input,
  TAB character-info open / modal controls, F8 debug perk-point grants,
  F9 ball-speed debug overlay
  toggles, and F2 active-item debug spawn toggles / clicks. These debug
  surfaces share a direct-switch group: pressing a different debug key
  moves to that screen without requiring the player to close the old one
  first. The input controller delegates this modal
  ladder here after fullscreen, mobile touch, and intro-skip handling.
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
  delegates intro input to `battle_scene_intro_input_controller.gd`, then
  delegates the overlay / debug keybinding ladder to
  `battle_scene_overlay_input_controller.gd`. The battle shell now passes
  current boot / intro readiness plus callbacks instead of owning the
  keybinding ladder directly.
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
  ball-spawn frame phases are delegated to the intro-frame controller and
  overlay idle / draw phases are delegated to the overlay-frame controller.
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
  quantum particles, vortex rings, lightning bolts and segments, electric
  arcs, hologram rings, sparks, and energy rings. It receives the existing
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
  trigger large per-character PNG loads.
- `scripts/ui/character_live_preview.gd`
  Owns the animated top preview for the character-select scene. It first
  consumes boot-prewarmed full-frame preview sheets from the shared texture
  cache, then attempts imagegen-style part layers under
  `assets/ui/character_live2d/`, then falls back to card-art parallax /
  breathing motion so the scene can ship before dedicated Live2D layer PNGs
  exist. It also owns the preview hover / click overlay so the large
  character portrait reads as an interactive selection target.
- `scripts/ui/character_select_screen.gd`
  Owns the Godot character-select UI: cyberpunk background, selected
  character detail panel, bottom card row, mouse / keyboard selection,
  bottom Champion / Mythic league buttons, content-area-safe responsive
  layout, preview-click confirmation, and handoff to `main.tscn` from
  either the app-root flow or direct scene execution.
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
  1-second hold completion, paddle-center anchored 180x12 barrier placement,
  seeded berry-surface visual points, build / death timers, lingering
  post-transform collision context, and barrier consumption after a ball
  reflection.
- `scripts/items/horn_strawberry_horn_charge_state.gd`
  Owns Horn Strawberry Mask's W horn-charge skill state: 300-gauge activation,
  20-second cooldown, boss-width aligned charge / impact / return / stun
  phases, active control locking during charge / impact, direct boss stun /
  strong knockback, same-frame paddle-hit knockback suppression, and
  lightweight charge trail draw context.
- `scripts/items/horn_strawberry_bomb_state.gd`
  Owns Horn Strawberry Mask's A+D hold bomb skill state: 0.5-second dual-input
  hold, 400-gauge spend, 30 deterministic hopping bombs over 1 second, boss
  stun / knockback on explosion, 5-second paint splatter slow, and lingering
  bomb / paint cleanup.
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
