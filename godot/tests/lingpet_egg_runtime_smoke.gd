extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const BattleSceneLifecycle := preload("res://scripts/core/battle_scene_lifecycle.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetCompanionSwitchState := preload("res://scripts/lingpet/lingpet_companion_switch_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSaveStore := preload("res://scripts/lingpet/lingpet_save_store.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const HydroPuddleTextureCache := preload("res://scripts/effects/hydro_puddle_texture_cache.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_serve_origin := ""
	var ball_size := 28.6
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_patrol_speed_default := 120.0
	var ringpet_companion_patrol_speed_default := 120.0
	var lingpet_companion_patrol_speed_min := 70.0
	var ringpet_companion_patrol_speed_min := 70.0
	var lingpet_companion_patrol_speed_max := 135.0
	var ringpet_companion_patrol_speed_max := 135.0
	var lingpet_companion_catch_width := 100.0
	var ringpet_companion_catch_width := 100.0
	var lingpet_companion_catch_height := 44.0
	var ringpet_companion_catch_height := 44.0
	var lingpet_companion_defense_rate := 0.0
	var ringpet_companion_defense_rate := 0.0
	var lingpet_companion_defense_intercept_active := false
	var ringpet_companion_defense_intercept_active := false
	var lingpet_companion_defense_intercept_target_x := 0.0
	var ringpet_companion_defense_intercept_target_x := 0.0
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_companion_hit_gauge_gain := 0.0
	var ringpet_companion_hit_gauge_gain := 0.0
	var lingpet_companion_hit_gauge_last_gain := 0.0
	var ringpet_companion_hit_gauge_last_gain := 0.0
	var lingpet_companion_hit_gauge_trigger_count := 0
	var ringpet_companion_hit_gauge_trigger_count := 0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 40.0
	var ringpet_skill_cooldown_duration := 40.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_slots: Array = ["", "", ""]
	var ringpet_slots: Array = ["", "", ""]
	var lingpet_slot_pet_ids: Array = ["", "", ""]
	var ringpet_slot_pet_ids: Array = ["", "", ""]
	var lingpet_active_slot_index := 0
	var ringpet_active_slot_index := 0


class FakeBattleOwner:
	extends Node2D

	var current_stage := 1
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_patrol_speed_default := 120.0
	var ringpet_companion_patrol_speed_default := 120.0
	var lingpet_companion_patrol_speed_min := 70.0
	var ringpet_companion_patrol_speed_min := 70.0
	var lingpet_companion_patrol_speed_max := 135.0
	var ringpet_companion_patrol_speed_max := 135.0
	var lingpet_companion_catch_width := 100.0
	var ringpet_companion_catch_width := 100.0
	var lingpet_companion_catch_height := 44.0
	var ringpet_companion_catch_height := 44.0
	var lingpet_companion_defense_rate := 0.0
	var ringpet_companion_defense_rate := 0.0
	var lingpet_companion_defense_intercept_active := false
	var ringpet_companion_defense_intercept_active := false
	var lingpet_companion_defense_intercept_target_x := 0.0
	var ringpet_companion_defense_intercept_target_x := 0.0
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_companion_hit_gauge_gain := 0.0
	var ringpet_companion_hit_gauge_gain := 0.0
	var lingpet_companion_hit_gauge_last_gain := 0.0
	var ringpet_companion_hit_gauge_last_gain := 0.0
	var lingpet_companion_hit_gauge_trigger_count := 0
	var ringpet_companion_hit_gauge_trigger_count := 0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 40.0
	var ringpet_skill_cooldown_duration := 40.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_slots: Array = ["", "", ""]
	var ringpet_slots: Array = ["", "", ""]
	var lingpet_slot_pet_ids: Array = ["", "", ""]
	var ringpet_slot_pet_ids: Array = ["", "", ""]
	var lingpet_active_slot_index := 0
	var ringpet_active_slot_index := 0


class FakeBootstrap:
	extends RefCounted

	func initialize(_owner: Node, _context: Dictionary, _registry: Object) -> Dictionary:
		return {}


class FakeFeedback:
	extends RefCounted

	var gauge_flashes := 0

	func trigger_gauge_flash() -> void:
		gauge_flashes += 1


class FakeOrbHudState:
	extends RefCounted

	var gauge_spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		gauge_spins += 1


class FakePaddleAudio:
	extends RefCounted

	var paddle_hits := 0
	var hydro_count := 0

	func play_paddle_hit() -> void:
		paddle_hits += 1

	func play_stage2_hydro() -> void:
		hydro_count += 1


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		var status_call := {
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		}
		calls.append(status_call)
		return status_call

	func get_calls_for_source(source: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in calls:
			if str(status_call.get("source", "")) == source:
				matches.append(status_call)
		return matches


class FakeWhip:
	extends RefCounted

	var player_hits := 0

	func register_player_hit(_ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		player_hits += 1
		return {}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if value is Object:
			return value
		return null


func _init() -> void:
	_verify_registry_and_frame_wiring()
	_verify_lingpet_catalog_random_hatch_scaffold()
	_verify_junior_mika_spawn_syncs_character_info_keys()
	_verify_egg_player_contact_nudges_and_wobbles()
	_verify_player_serve_ball_does_not_hatch_egg()
	_verify_egg_hit_uses_player_paddle_reflection()
	_verify_two_ball_hits_hatch_unidentified_egg()
	_verify_acquire_cutin_triggers_on_hatch()
	_verify_owned_maribo_is_kept_as_companion()
	_verify_lingpet_battle_slot_model()
	_verify_companion_visual_and_pillar_card()
	_verify_companion_patrol_edge_pause_and_speed_change()
	_verify_companion_ball_collision_soft_bounce()
	_verify_companion_strike_anticipates_contact()
	_verify_companion_paddle_bounce_and_sound()
	_verify_companion_hit_gauge_passive()
	_verify_companion_paddle_hit_width()
	_verify_companion_guards_dalji_whip()
	_verify_companion_skill_card_hydro_sphere()
	_verify_hydro_puddle_vfx()
	_verify_save_snapshot_roundtrip()
	_verify_save_store_persists_and_restores_maribo()
	_verify_battle_lifecycle_restores_lingpet_save()
	_verify_maribo_companion_gauge_bonus()
	_verify_maribo_defense_rate_intercepts_descending_ball()
	_verify_lunabi_free_flight_profile()
	_verify_ineligible_conditions_do_not_spawn()

	if _failures.is_empty():
		print("lingpet_egg_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_registry_and_frame_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var runtime: Object = registry.get_instance("lingpet_egg_runtime")
	_expect(runtime != null and runtime.has_method("update"), "lingpet egg runtime should be registered")
	var save_store: Object = registry.get_instance("lingpet_save_store")
	_expect(save_store != null and save_store.has_method("restore_runtime"), "lingpet save store should be registered")
	var callback_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_update_callbacks.gd")
	var flow_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_frame_flow_controller.gd")
	var drawer_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var lifecycle_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_lifecycle.gd")
	var deps_source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_dependency_context.gd")
	var hit_router_source: String = FileAccess.get_file_as_string("res://scripts/ball/paddle_bounce_event_router.gd")
	var character_info_source: String = FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd")
	var pillar_hud_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
	var pillar_ui_source: String = FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	_expect(callback_source.find("update_lingpet") >= 0, "battle callbacks should expose lingpet update")
	_expect(callback_source.find("save_runtime(owner, registry)") >= 0, "battle callbacks should persist lingpet runtime changes")
	_expect(flow_source.find("update_lingpet") >= 0, "battle flow should update lingpet after ball/serve flow")
	_expect(drawer_source.find("lingpet_egg_runtime") >= 0, "playfield drawer should render visible lingpet runtime")
	_expect(lifecycle_source.find("_restore_lingpet_save(owner, registry)") >= 0, "battle lifecycle should restore saved lingpet data after bootstrap")
	_expect(deps_source.find("\"lingpet_egg_runtime\"") >= 0, "ball dependencies should expose the lingpet runtime")
	_expect(hit_router_source.find("get_gauge_gain_per_hit") >= 0, "player hit gauge routing should read lingpet gauge bonuses")
	_expect(character_info_source.find("_frame_stat_sources.append(lingpet_runtime)") >= 0, "character info stats should include lingpet stat sources")
	_expect(pillar_hud_source.find("\"lingpet_runtime\"") >= 0, "shared pillar HUD should pass lingpet runtime to the pillar UI")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_catalog.gd"), "lingpet catalog should exist as the random hatch source of truth")
	# Old separate bottom-left vertical lingpet card was removed; the skill now rides EVERY stage's boss skill-card rail via the shared LingpetRailCard helper.
	_expect(pillar_ui_source.find("_draw_lingpet_card(") < 0, "old separate lingpet pillar card call site should be removed from the pillar UI renderer")
	_expect(pillar_ui_source.find("draw_pillar_card") < 0, "pillar UI renderer should no longer call the runtime pillar card draw path")
	_expect(pillar_hud_source.find("LingpetRailCard") >= 0 and pillar_hud_source.find("append_entry(") >= 0, "Stage 1 boss-HUD composition should append the lingpet card via the shared LingpetRailCard helper")
	_expect(pillar_hud_source.find("stage1_dalji_boss_skill_hud_skills") >= 0, "Stage 1 lingpet append should target the boss skill-card rail array")
	var dalji_hud_renderer_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
	_expect(dalji_hud_renderer_source.find("LingpetRailCard") >= 0 and dalji_hud_renderer_source.find("is_lingpet_skill") >= 0, "Dalji boss skill HUD renderer should delegate the lingpet card to the shared helper")
	_expect(FileAccess.file_exists("res://scripts/stages/common/lingpet_rail_card.gd"), "shared lingpet rail card helper should exist")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png"), "Maribo Hydro Sphere rail card should ship a landscape (boss-card class) imagegen PNG")
	_expect(drawer_source.find("lingpet_egg_runtime") >= 0, "playfield drawer should keep drawing the ringpet companion after hatching")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_egg_v002.png"), "shared unidentified lingpet egg should use a PNG-backed runtime asset")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_egg_v002_crack1.png"), "shared unidentified lingpet egg should have a first-hit cracked PNG variant")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_egg_v002_crack2.png"), "shared unidentified lingpet egg should have a second-hit cracked PNG variant")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("LINGPET_EGG_TEXTURE_CRACK_1") >= 0, "field egg rendering should switch to the first cracked asset after one hit")
	_expect(runtime_source.find("LINGPET_EGG_TEXTURE_CRACK_2") >= 0, "field egg rendering should switch to the second cracked asset after two hits")
	_expect(runtime_source.find("lingpet_egg_field_renderer.gd") >= 0, "egg runtime should delegate field egg rendering to the egg renderer module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_egg_field_renderer.gd"), "egg-field renderer module should exist")
	var egg_renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
	_expect(egg_renderer_source.find("_draw_egg_crack_light") >= 0, "field egg rendering should leak light from cracked shell paths after a hatch hit")
	_expect(egg_renderer_source.find("HATCH_BREAK_SHARD_COUNT") >= 0, "field hatch should keep a shell-fragment burst spec")
	_expect(egg_renderer_source.find("_draw_hatch_shell_burst") >= 0, "field hatch should draw breaking egg fragments during the hatch flash")
	_expect(runtime_source.find("lingpet_egg_field_state.gd") >= 0, "egg runtime should delegate floor egg contact/hit/hatch state to the egg-field state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_egg_field_state.gd"), "egg-field state module should exist")
	var egg_field_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_field_state.gd")
	_expect(egg_field_source.find("resolve_ball_hit") >= 0, "egg-field state should own egg ball-hit cracking logic")
	_expect(egg_field_source.find("update_player_contact") >= 0, "egg-field state should own player-contact nudge/wobble logic")
	_expect(runtime_source.find("lingpet_runtime_snapshot_builder.gd") >= 0, "egg runtime should delegate live/save snapshot and owner sync payloads to the snapshot builder")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd"), "lingpet runtime snapshot builder module should exist")
	var snapshot_builder_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
	_expect(snapshot_builder_source.find("build_runtime_snapshot") >= 0, "snapshot builder should own live runtime snapshot assembly")
	_expect(snapshot_builder_source.find("build_save_snapshot") >= 0, "snapshot builder should own save snapshot assembly")
	_expect(snapshot_builder_source.find("sync_owner") >= 0, "snapshot builder should own owner compatibility key sync")
	var save_restore_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_save_restore_planner.gd")
	_expect(runtime_source.find("lingpet_save_restore_planner.gd") >= 0, "egg runtime should delegate save-restore target decisions to the restore planner")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_save_restore_planner.gd"), "lingpet save-restore planner module should exist")
	_expect(save_restore_source.find("build_plan") >= 0, "save-restore planner should own restore target plan assembly")
	_expect(save_restore_source.find("active_pet_id") >= 0 and save_restore_source.find("battle_slot_pet_ids") >= 0, "save-restore planner should preserve active pet and battle slot interpretation")
	_expect(runtime_source.find("lingpet_companion_body_hit_state.gd") >= 0, "egg runtime should delegate companion body hit bounce/gauge state to the body-hit module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_body_hit_state.gd"), "companion body-hit state module should exist")
	_expect(runtime_source.find("lingpet_companion_motion_state.gd") >= 0, "egg runtime should delegate companion patrol/defense motion to the motion-state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_motion_state.gd"), "companion motion-state module should exist")
	var draw_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	_expect(runtime_source.find("lingpet_companion_draw_context_builder.gd") >= 0, "egg runtime should delegate companion draw config assembly to the draw-context builder")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd"), "companion draw-context builder module should exist")
	_expect(draw_context_source.find("build_config") >= 0, "companion draw-context builder should own renderer config assembly")
	_expect(draw_context_source.find("companion_strike") >= 0 and draw_context_source.find("companion_cast") >= 0, "companion draw-context builder should resolve companion visual textures")
	var strike_anticipator_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_strike_anticipator.gd")
	_expect(runtime_source.find("lingpet_companion_strike_anticipator.gd") >= 0, "egg runtime should delegate anticipatory strike prediction to the strike-anticipator module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_strike_anticipator.gd"), "companion strike-anticipator module should exist")
	_expect(strike_anticipator_source.find("frames_to_contact") >= 0, "strike anticipator should predict time-to-contact to pick an entry frame")
	_expect(strike_anticipator_source.find("hit_half_width") >= 0 and strike_anticipator_source.find("hit_half_height") >= 0, "strike anticipator should receive hit half-size from the current lingpet catalog stats")
	_expect(runtime_source.find("frames_to_contact") < 0, "egg runtime should not keep inline strike time-to-contact prediction after delegation")
	_expect(runtime_source.find("_companion_pos.y - COMPANION_HIT_HALF_HEIGHT") < 0, "companion strike prediction should not be locked to Maribo's fallback half-height")
	_expect(runtime_source.find("COMPANION_HIT_HALF_WIDTH + ball_radius") < 0, "companion strike prediction should not be locked to Maribo's fallback half-width")
	var hydro_skill_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")
	_expect(hydro_skill_source.find("PUDDLE_HALF_WIDTH") >= 0 and hydro_skill_source.find("PUDDLE_HALF_HEIGHT") >= 0, "Maribo Hydro Sphere puddle should be a wide ellipse (half-width/half-height), not a circle radius")
	_verify_companion_walk_sheet_wiring(runtime_source)
	_verify_acquire_cutin_wiring(runtime_source)


func _verify_acquire_cutin_wiring(runtime_source: String) -> void:
	# The fullscreen acquisition cut-in reveals the ORIGINAL outsourced artwork
	# (not the SD walk sheet) once on hatch, as an overlay drawn above the HUD.
	# Seal the asset + host registration + frame-controller hook + prewarm so the
	# reveal cannot silently stop firing.
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_cutin_art.png"), "Maribo acquisition cut-in should keep the nukki'd original-art PNG as fallback")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_cutin_anim.png"), "Maribo acquisition cut-in should use the AutoSprite Live2D-style animation sheet")
	_expect(FileAccess.file_exists("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd"), "lingpet acquisition cut-in overlay host should exist")
	var cutin_host_source: String = FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	_expect(cutin_host_source.find("USE_ANIMATED_CUTIN := true") >= 0, "cut-in host should default to the upscaled Live2D-style animation sheet")
	_expect(cutin_host_source.find("CUTIN_ANIM_COLS := 4") >= 0, "cut-in host should use the 4x4 Maribo acquisition cut-in sheet")
	_expect(cutin_host_source.find("CUTIN_ANIM_FRAMES := 16") >= 0, "cut-in host should use the 16-frame Maribo acquisition cut-in sheet")
	_expect(cutin_host_source.find("CUTIN_ANIM_SHEET") >= 0, "cut-in host should reference the Live2D-style animation sheet")
	_expect(cutin_host_source.find("draw_texture_rect_region") >= 0, "cut-in host should frame-step the animation sheet")
	_expect(cutin_host_source.find("RESTORE_VOXEL_COLS") >= 0, "cut-in host should assemble Maribo from a virtual data-fragment grid")
	_expect(cutin_host_source.find("_draw_voxel_assembly") >= 0, "cut-in host should fly code-data shards into the final Live2D cut-in")
	_expect(cutin_host_source.find("_draw_holo_ghost") >= 0, "cut-in host should densify a chromatic hologram as the data shards assemble")
	_expect(cutin_host_source.find("_draw_scanline_print") >= 0, "cut-in host should solidify the restored art with a scan-printer sweep")
	# The shards/bevels must build only over Maribo's baked silhouette (not the
	# transparent frame padding), gated by the manifest occupancy mask.
	_expect(cutin_host_source.find("reconstruction_frame0") >= 0, "cut-in host should read the baked frame-0 alpha occupancy (silhouette, not a box)")
	_expect(cutin_host_source.find("_cell_visible") >= 0, "cut-in host should skip empty silhouette cells when assembling the data shards")
	var cutin_manifest_source: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/maribo_cutin_anim_manifest.json")
	_expect(cutin_manifest_source.find("reconstruction_frame0") >= 0, "cut-in manifest should bake the per-cell frame-0 occupancy + alpha bbox the reconstruction reads")
	_expect(cutin_host_source.find("_draw_data_restore_stream") >= 0, "cut-in host should draw loose coding-data bits before the cut-in fully restores")
	_expect(cutin_host_source.find("_draw_restoring_texture") >= 0, "cut-in host should gate the final texture through the restoration reveal")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_cutin_anim_manifest.json"), "Maribo acquisition cut-in should record its AutoSprite + Real-ESRGAN provenance")
	_expect(cutin_host_source.find("_draw_art_static") >= 0, "cut-in host should keep the smooth static-art primary path")
	_expect(cutin_host_source.find("_draw_spear_blade_repair") < 0, "cut-in host should not patch Maribo's spear with procedural overlays")
	_expect(cutin_host_source.find("_draw_dismiss_action") >= 0, "cut-in host should draw the click-triggered exit action")
	_expect(cutin_host_source.find("CUTIN_DISMISS_SHEET") >= 0, "cut-in host should play the spear-raise + water-spray exit sheet")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_cutin_dismiss_anim.png"), "Maribo cut-in should ship the exit-action (spear-raise + water-spray) sheet")
	_expect(runtime_source.find("is_acquire_cutin_active") >= 0, "lingpet runtime should expose the acquisition cut-in active flag")
	_expect(runtime_source.find("lingpet_acquire_cutin_state.gd") >= 0, "lingpet runtime should delegate cut-in timing state to the acquire-cutin state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_acquire_cutin_state.gd"), "lingpet acquire cut-in state module should exist")
	_expect(runtime_source.find("get_acquire_cutin_progress") >= 0, "lingpet runtime should expose the acquisition cut-in progress")
	_expect(runtime_source.find("advance_acquire_cutin") >= 0, "lingpet runtime should advance the cut-in from the ungated idle pump")
	_expect(runtime_source.find("is_acquire_cutin_awaiting_dismiss") >= 0, "lingpet runtime should expose the post-reveal dismissable state")
	_expect(runtime_source.find("dismiss_acquire_cutin") >= 0, "lingpet runtime should support hard dismissal of the cut-in")
	_expect(runtime_source.find("begin_acquire_cutin_dismiss") >= 0, "lingpet runtime should start the click-triggered exit action")
	_expect(runtime_source.find("is_acquire_cutin_dismissing") >= 0, "lingpet runtime should expose the exit-action (dismissing) state")
	_expect(runtime_source.find("get_acquire_cutin_dismiss_progress") >= 0, "lingpet runtime should expose the exit-action progress for the host")
	var hud_catalog_source: String = FileAccess.get_file_as_string("res://scripts/resources/gameplay_hud_module_catalog.gd")
	_expect(hud_catalog_source.find("lingpet_acquire_cutin_overlay_host") >= 0, "HUD module catalog should register the lingpet acquisition cut-in host")
	var frame_controller_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_controller_source.find("_draw_lingpet_acquire_cutin_if_active") >= 0, "battle frame controller should draw the lingpet acquisition cut-in above the HUD")
	_expect(frame_controller_source.find("lingpet_acquire_cutin_overlay_host") >= 0, "battle frame controller should resolve the lingpet acquisition cut-in host")
	_expect(frame_controller_source.find("advance_acquire_cutin") >= 0, "battle frame controller idle pump should advance the cut-in while physics is paused")
	var prewarm_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	_expect(prewarm_source.find("lingpet_acquire_cutin_overlay_host") >= 0, "Smasher prewarm should warm the lingpet acquisition cut-in host before the hatch frame")
	# Pause + dismiss wiring: the cut-in must gate battle physics and be reachable
	# by the overlay input controller for click dismissal.
	var modal_gate_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(modal_gate_source.find("is_lingpet_acquire_cutin_active") >= 0, "modal gate should expose the lingpet acquisition cut-in as a physics-blocking modal")
	_expect(modal_gate_source.find("physics.modal_gate.lingpet_acquire_cutin") >= 0, "modal gate should block battle physics while the acquisition cut-in is active")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_input_controller.gd")
	_expect(input_source.find("is_acquire_cutin_awaiting_dismiss") >= 0, "overlay input controller should only act after the reveal finishes")
	_expect(input_source.find("begin_acquire_cutin_dismiss") >= 0, "overlay input controller should start the exit action on click/confirm (not close instantly)")
	var modal_gate: Object = GameplayModuleRegistry.new().get_instance("battle_scene_modal_gate_controller")
	_expect(modal_gate != null and modal_gate.has_method("is_lingpet_acquire_cutin_active"), "modal gate controller should implement the cut-in gate method")
	var host: Object = GameplayModuleRegistry.new().get_instance("lingpet_acquire_cutin_overlay_host")
	_expect(host != null and host.has_method("draw"), "lingpet acquisition cut-in host should be registered and drawable")
	var cutin_host_dynamic_source: String = FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	_expect(cutin_host_dynamic_source.find("LingpetCatalog.get_visual_path") >= 0, "lingpet acquisition cut-in host should resolve art through the hatched pet catalog entry")
	_expect(cutin_host_dynamic_source.find("_get_runtime_pet_id") >= 0, "lingpet acquisition cut-in host should read the hatched pet id from runtime instead of staying Maribo-only")


func _verify_lingpet_catalog_random_hatch_scaffold() -> void:
	var eligible_context := {
		"league_mode": "junior",
		"character_type": "smasher",
	}
	var candidates: Array[String] = LingpetCatalog.get_hatch_candidates(eligible_context, [])
	_expect(candidates.has("maribo") and candidates.has("lunabi"), "catalog should expose every shipped Junior Smasher lingpet as an unidentified egg hatch candidate")
	var hatch_rng := RandomNumberGenerator.new()
	hatch_rng.seed = 7
	_expect(candidates.has(str(LingpetCatalog.pick_hatch_pet_id(eligible_context, [], hatch_rng))), "weighted hatch pick should resolve to one of the current unidentified egg candidates")
	var after_maribo_owned_live: Array[String] = LingpetCatalog.get_hatch_candidates(eligible_context, ["maribo"])
	_expect(not after_maribo_owned_live.has("maribo") and after_maribo_owned_live.has("lunabi"), "owned lingpets should be removed without hiding other unidentified egg candidates")
	_expect(LingpetCatalog.get_hatch_candidates(eligible_context, ["maribo", "lunabi"]).is_empty(), "random hatch candidates should empty only after all current lingpets are owned")
	_expect(LingpetCatalog.get_hatch_candidates({"league_mode": "champion", "character_type": "smasher"}, []).is_empty(), "catalog should keep Junior League eligibility gating")
	var live_catalog_issues: Array[String] = LingpetCatalog.validate_catalog(true)
	_expect(live_catalog_issues.is_empty(), "live lingpet catalog should validate cleanly: %s" % str(live_catalog_issues))
	var maribo_skill := LingpetCatalog.get_active_skill("maribo")
	_expect(is_equal_approx(float(maribo_skill.get("windup_seconds", 0.0)), 1.0), "Maribo Hydro Sphere wind-up timing should live in the active-skill catalog entry")
	var draft_entries := {
		"maribo": LingpetCatalog.get_entry("maribo"),
		"draft_bat": {
			"id": "draft_bat",
			"display_name": "드래프트 배트",
			"enabled": false,
			"hatch_weight": 1.0,
			"required_hits": 2,
			"unlock": {
				"league_mode": "junior",
				"character_type": "smasher",
			},
		},
	}
	var draft_candidates: Array[String] = LingpetCatalog.get_hatch_candidates_from_entries(draft_entries, eligible_context, [])
	_expect(draft_candidates.has("maribo") and not draft_candidates.has("draft_bat"), "disabled draft lingpets should never enter the random hatch pool")
	_expect(not LingpetCatalog.is_pet_enabled_from_entries(draft_entries, "draft_bat"), "disabled draft lingpets should not be treated as live pet ids")
	_expect(LingpetCatalog.validate_entries(draft_entries, true).is_empty(), "disabled draft lingpets should not require final visual/skill assets before shipping")
	var broken_entries := {
		"broken": {
			"id": "broken",
			"display_name": "검수 실패 샘플",
			"hatch_weight": 1.0,
			"required_hits": 2,
			"unlock": {},
			"stats": {
				"patrol_speed_default": 0.0,
			},
			"visuals": {
				"egg": "res://missing/broken_egg.png",
			},
			"active_skill": {
				"id": "broken_skill",
				"cooldown": 0.0,
			},
			"effect_text": "",
		},
	}
	var broken_issues: Array[String] = LingpetCatalog.validate_entries(broken_entries, false)
	_expect(_issues_contain(broken_issues, "stats.patrol_speed_default must be > 0"), "catalog validator should catch invalid movement stats before a new lingpet ships")
	_expect(_issues_contain(broken_issues, "missing visuals.companion_walk"), "catalog validator should catch missing companion visual paths")
	_expect(_issues_contain(broken_issues, "missing active_skill.runtime_kind"), "catalog validator should require active-skill runtime kind metadata")
	_expect(_issues_contain(broken_issues, "missing active_skill.card_texture_path"), "catalog validator should catch missing skill-card art paths")
	_expect(_issues_contain(broken_issues, "active_skill.cooldown must be > 0"), "catalog validator should catch invalid active-skill cooldowns")
	_expect(_issues_contain(broken_issues, "missing effect_text"), "catalog validator should catch missing ringpet effect text")
	var broken_windup_entries := {
		"broken_windup": LingpetCatalog.get_entry("maribo"),
	}
	var broken_windup_entry: Dictionary = broken_windup_entries["broken_windup"] as Dictionary
	broken_windup_entry["id"] = "broken_windup"
	var broken_windup_skill: Dictionary = broken_windup_entry["active_skill"] as Dictionary
	broken_windup_skill["windup_seconds"] = -0.25
	var broken_windup_issues: Array[String] = LingpetCatalog.validate_entries(broken_windup_entries, false)
	_expect(_issues_contain(broken_windup_issues, "active_skill.windup_seconds must be >= 0"), "catalog validator should catch invalid active-skill wind-up timing")
	var multi_entries := {
		"maribo": LingpetCatalog.get_entry("maribo"),
		"test_bubble": {
			"id": "test_bubble",
			"display_name": "테스트 버블",
			"hatch_weight": 3.0,
			"required_hits": 2,
			"unlock": {
				"league_mode": "junior",
				"character_type": "smasher",
			},
			"active_skill": {
				"id": "test_bubble_guard",
				"runtime_kind": "bubble_guard",
				"name": "Bubble Guard",
				"description": "Test future skill metadata",
				"cooldown": 18.0,
				"card_texture_path": "res://test/bubble_guard.png",
			},
		},
	}
	var multi_candidates: Array[String] = LingpetCatalog.get_hatch_candidates_from_entries(multi_entries, eligible_context, [])
	_expect(multi_candidates.has("maribo") and multi_candidates.has("test_bubble"), "catalog selection helper should support multiple eligible lingpet candidates")
	var after_maribo_owned: Array[String] = LingpetCatalog.get_hatch_candidates_from_entries(multi_entries, eligible_context, ["maribo"])
	_expect(not after_maribo_owned.has("maribo") and after_maribo_owned.has("test_bubble"), "multi-candidate selection should exclude already owned lingpets without hiding other candidates")
	_expect(str(LingpetCatalog.pick_hatch_pet_id_from_entries(multi_entries, eligible_context, ["maribo"])) == "test_bubble", "multi-candidate picker should resolve the remaining eligible pet after ownership filtering")
	_expect(LingpetCatalog.get_required_hits("maribo") == 2, "catalog should own Maribo hatch-hit requirements")
	_expect(LingpetCatalog.get_display_name("maribo") == "마리보", "catalog should own lingpet display names")
	_expect(str(LingpetCatalog.get_visual_path("maribo", "egg")).ends_with("maribo_egg_v002.png"), "catalog should own the current shared unidentified egg visual path")
	_expect(str(LingpetCatalog.get_visual_path("lunabi", "egg")).ends_with("maribo_egg_v002.png"), "Lunabi should hatch from the same shared unidentified egg visual path")
	_expect(str(LingpetCatalog.get_visual_path("maribo", "companion_walk")).ends_with("maribo_companion_walk.png"), "catalog should own Maribo companion visual paths")
	_expect(str(LingpetCatalog.get_active_skill_entry("maribo_hydro_sphere").get("runtime_kind", "")) == "hydro_sphere", "catalog should expose Maribo active-skill runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_runtime_kind_from_entries(multi_entries, "test_bubble_guard")) == "bubble_guard", "catalog should resolve future lingpet skill runtime kinds from active_skill metadata")
	_expect(LingpetSkillDispatcher.is_hydro_sphere("maribo_hydro_sphere"), "skill dispatcher should recognize the current Maribo active skill")
	_expect(LingpetSkillDispatcher.is_supported_kind("hydro_sphere"), "skill dispatcher should expose supported runtime kinds for future lingpet skill modules")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var dispatcher_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
	var skill_runtime_host_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	var skill_controller_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
	var collection_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_collection_state.gd")
	var current_profile_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_profile.gd")
	_expect(runtime_source.find("lingpet_collection_state.gd") >= 0, "egg runtime should delegate owned collection + hatch candidate selection to the collection-state helper")
	_expect(collection_source.find("LingpetCatalog.pick_hatch_pet_id") >= 0, "collection-state helper should pick the hidden egg identity through the catalog")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_collection_state.gd"), "lingpet collection-state helper should exist")
	_expect(runtime_source.find("lingpet_current_profile.gd") >= 0, "egg runtime should delegate current pet catalog lookups to the current-profile helper")
	_expect(runtime_source.find("LingpetCatalog") < 0, "egg runtime should not directly query the lingpet catalog after profile delegation")
	_expect(current_profile_source.find("LingpetCatalog.get_stat") >= 0, "current-profile helper should own current pet stat lookup")
	_expect(current_profile_source.find("LingpetVisualTextureCache") >= 0, "current-profile helper should own visual-cache access for the selected pet")
	var current_profile := LingpetCurrentProfile.new()
	_expect(str(current_profile.set_pet_id("unknown_pet")) == "maribo", "current-profile helper should fall back to the default pet for unknown ids")
	_expect(is_equal_approx(float(current_profile.get_hit_gauge_gain(0.0)), 40.0), "current-profile helper should expose current pet hit gauge gain")
	_expect(runtime_source.find("_pick_hatch_pet_id") >= 0, "egg runtime should keep a narrow hatch-selection hook for future weighted random lingpets")
	_expect(runtime_source.find("_update_companion_skill_effects") >= 0, "egg runtime should keep a narrow companion active-skill update hook")
	_expect(runtime_source.find("lingpet_companion_skill_controller.gd") >= 0, "egg runtime should delegate companion active-skill arm/launch decisions to the skill controller")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_skill_controller.gd"), "companion skill controller should exist for future lingpet active skills")
	_expect(skill_controller_source.find("ACTION_ARM") >= 0 and skill_controller_source.find("ACTION_LAUNCH") >= 0, "companion skill controller should own active-skill action decisions")
	_expect(skill_controller_source.find("LingpetSkillDispatcher.has_supported_runtime") >= 0, "companion skill controller should guard supported runtime skill ids")
	_expect(runtime_source.find("LingpetSkillDispatcher") < 0, "egg runtime should not directly dispatch lingpet active-skill kinds after controller delegation")
	_expect(runtime_source.find("lingpet_skill_runtime_host.gd") >= 0, "egg runtime should delegate concrete active-skill modules to the skill runtime host")
	_expect(runtime_source.find("lingpet_hydro_sphere_skill.gd") < 0, "egg runtime should not directly own the Hydro Sphere module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_skill_runtime_host.gd"), "lingpet skill runtime host should exist for future active-skill modules")
	_expect(skill_runtime_host_source.find("LingpetSkillDispatcher.get_skill_kind") >= 0, "skill runtime host should dispatch concrete active-skill behavior by skill id")
	_expect(skill_runtime_host_source.find("lingpet_hydro_sphere_skill.gd") >= 0, "skill runtime host should own the current Hydro Sphere module")
	_expect(dispatcher_source.find("LingpetCatalog.get_active_skill_runtime_kind") >= 0, "skill dispatcher should resolve active-skill runtime kind through the catalog before falling back to legacy ids")
	_expect(runtime_source.find("lingpet_companion_skill_state.gd") >= 0, "egg runtime should delegate shared active-skill cooldown/wind-up state to the companion skill-state controller")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_skill_state.gd"), "companion skill-state controller should exist for future lingpet active skills")
	_expect(current_profile_source.find("lingpet_visual_texture_cache.gd") >= 0, "current-profile helper should delegate catalog visual texture loading to the visual cache module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_visual_texture_cache.gd"), "lingpet visual texture cache module should exist")
	var visual_cache_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
	_expect(visual_cache_source.find("LingpetCatalog.get_visual_path") >= 0, "visual cache should query catalog visual paths instead of hardcoding only Maribo paths")
	_expect(visual_cache_source.find("ProjectResourceLoader.load_texture") >= 0, "visual cache should route texture loads through the shared project resource loader")


func _verify_companion_walk_sheet_wiring(runtime_source: String) -> void:
	# The hatched companion now renders from the AutoSprite back-view walk sheet
	# (idle is derived from the same sheet). Seal the asset + grid spec so a
	# future PNG swap or grid change cannot silently desync the frame math.
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_companion_walk.png"), "Maribo companion should use a PNG-backed back-view walk sheet")
	_expect(runtime_source.find("MARIBO_COMPANION_WALK_SHEET") >= 0, "companion rendering should reference the walk-sheet texture")
	var draw_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	_expect(draw_context_source.find("companion_walk") >= 0, "companion draw context should resolve walk visuals through the catalog with a Maribo fallback")
	_expect(runtime_source.find("lingpet_companion_renderer.gd") >= 0, "egg runtime should delegate companion sprite drawing to the companion renderer")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_renderer.gd"), "companion renderer module should exist")
	var companion_renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	_expect(companion_renderer_source.find("draw_texture_rect_region") >= 0, "companion renderer should blit walk-sheet cells, not draw a procedural body")
	_expect(companion_renderer_source.find("_draw_burst") >= 0, "companion renderer should own hit/gauge/skill flash burst drawing")
	_expect(runtime_source.find("lingpet_companion_sprite_animator.gd") >= 0, "egg runtime should delegate companion frame/source-rect math to the sprite animator")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_sprite_animator.gd"), "companion sprite animator module should exist")
	var sprite_animator_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
	_expect(sprite_animator_source.find("get_walk_frame") >= 0, "companion sprite animator should resolve walk/idle frames")
	_expect(sprite_animator_source.find("get_source_rect") >= 0, "companion sprite animator should resolve sheet source rects")
	var sheet: Texture2D = load("res://assets/sprites/lingpet/maribo_companion_walk.png") as Texture2D
	_expect(sheet != null, "companion walk sheet should load as a Texture2D")
	if sheet != null:
		# Grid metadata is hardcoded in the runtime; the asset must divide evenly
		# by it, and the frame count must fit cols*rows.
		var cols := 5
		var rows := 5
		var frames := 25
		_expect(sheet.get_width() % cols == 0, "walk sheet width must divide evenly into the column count")
		_expect(sheet.get_height() % rows == 0, "walk sheet height must divide evenly into the row count")
		_expect(frames <= cols * rows, "declared frame count must fit the walk-sheet grid")
	# Ball-hit strike sheet (same 5x5/25 grid) played on companion ball contact.
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_companion_strike.png"), "Maribo companion should have a back-view ball-hit strike sheet")
	_expect(runtime_source.find("MARIBO_COMPANION_STRIKE_SHEET") >= 0, "companion rendering should reference the strike sheet")
	_expect(draw_context_source.find("companion_strike") >= 0, "companion draw context should resolve strike visuals through the catalog with a Maribo fallback")
	_expect(sprite_animator_source.find("get_strike_frame") >= 0, "companion sprite animator should map the strike timer to sheet frames")
	# Impact-synced reaction: the ball-hit must seed the SHORT residual so the
	# thrust/apex frame renders at contact, NOT the full duration (which replayed
	# the long wind-up after the bounce = late-strike regression).
	_expect(runtime_source.find("_maybe_arm_companion_strike") >= 0, "companion should arm the strike anticipatorily (like player/boss attack sheets), not only on contact")
	var strike_anticipator_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_strike_anticipator.gd")
	_expect(strike_anticipator_source.find("frames_to_contact") >= 0, "anticipatory strike should predict time-to-contact to pick an entry frame")
	_expect(sprite_animator_source.find("STRIKE_START_FRAME") >= 0, "strike animator should declare a wind-up start frame (skip dead-air, show coil before the thrust)")
	var strike_sheet: Texture2D = load("res://assets/sprites/lingpet/maribo_companion_strike.png") as Texture2D
	_expect(strike_sheet != null, "companion strike sheet should load as a Texture2D")
	if strike_sheet != null:
		_expect(strike_sheet.get_width() % 5 == 0 and strike_sheet.get_height() % 5 == 0, "strike sheet must divide evenly into the 5x5 grid")
	# Hydro-cast wind-up sheet (telegraphed spear throw before the projectile launches).
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_companion_hydro_cast.png"), "Maribo companion should have a back-view hydro-cast wind-up sheet")
	_expect(runtime_source.find("MARIBO_COMPANION_HYDRO_CAST_SHEET") >= 0, "companion rendering should reference the hydro-cast wind-up sheet")
	_expect(draw_context_source.find("companion_cast") >= 0, "companion draw context should resolve cast visuals through the catalog with a Maribo fallback")
	_expect(sprite_animator_source.find("get_cast_frame") >= 0, "companion sprite animator should map the wind-up timer to cast sheet frames")
	_expect(runtime_source.find("COMPANION_SKILL_WINDUP_SECONDS") >= 0, "Hydro Sphere should declare a wind-up duration before launch")
	var cast_sheet: Texture2D = load("res://assets/sprites/lingpet/maribo_companion_hydro_cast.png") as Texture2D
	_expect(cast_sheet != null, "companion hydro-cast sheet should load as a Texture2D")
	if cast_sheet != null:
		_expect(cast_sheet.get_width() % 5 == 0 and cast_sheet.get_height() % 5 == 0, "hydro-cast sheet must divide evenly into the 5x5 grid")
	var player_serve_snapshot: Dictionary = BallRoundState.new().build_serve_snapshot(
		true,
		Vector2(300.0, 675.0),
		Vector2(300.0, 25.0),
		700.0,
		25.0,
		155.0,
		100.0,
		40.0,
		28.6,
		14.3,
		null
	)
	var boss_serve_snapshot: Dictionary = BallRoundState.new().build_serve_snapshot(
		false,
		Vector2(300.0, 675.0),
		Vector2(300.0, 25.0),
		700.0,
		25.0,
		155.0,
		100.0,
		40.0,
		28.6,
		14.3,
		null
	)
	_expect(str(player_serve_snapshot.get("ball_serve_origin", "")) == "player", "player serve snapshots should mark the serve origin")
	_expect(str(boss_serve_snapshot.get("ball_serve_origin", "")) == "boss", "boss serve snapshots should mark the serve origin")


func _verify_junior_mika_spawn_syncs_character_info_keys() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.update(0.0, owner), "Junior Mika should spawn the first unidentified lingpet egg immediately")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("state", "")) == "egg", "first unidentified lingpet state should become egg")
	_expect(str(owner.lingpet_id) == "" and str(owner.current_lingpet_id) == "" and str(owner.active_lingpet_id) == "", "egg state should not publish the hidden lingpet identity before hatch")
	_expect(str(owner.lingpet_state) == "egg", "owner should publish egg state")
	_expect(int(owner.lingpet_hatch_hits) == 0, "egg should start at 0 hatch hits")
	_expect(int(owner.lingpet_hatch_required_hits) == 2, "egg should require two hits to hatch")
	_expect(owner.lingpet_egg_pos is Vector2, "egg should publish a playfield position")
	var expected_floor_y := 750.0 - 28.0 - 18.0
	_expect(absf(owner.lingpet_egg_pos.y - expected_floor_y) <= 1.0, "egg should start as a floor-placed brick-like object")

	var panel: Dictionary = CharacterInfoOverlay.new()._get_lingpet_panel_snapshot(owner)
	_expect(str(panel.get("state", "")) == "egg", "character-info ringpet panel should read the shared egg state")
	_expect(str(panel.get("subtitle", "")).find("0 / 2") >= 0, "character-info panel should show hatch progress")
	_expect(str(owner.lingpet_effect_text).find("미확인 알") >= 0, "egg effect text should describe an unidentified egg without spoiling the lingpet")


func _verify_egg_player_contact_nudges_and_wobbles() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var start_pos: Vector2 = owner.lingpet_egg_pos
	owner.player_pos = Vector2(
		start_pos.x - owner.player_paddle_width * 0.5 - 16.0,
		start_pos.y - owner.player_paddle_height * 0.5
	)
	runtime.update(0.016, owner)
	var snapshot: Dictionary = runtime.get_snapshot()
	var first_nudge: float = owner.lingpet_egg_pos.x - start_pos.x
	_expect(first_nudge > 0.0 and first_nudge < 0.6, "player contact should gently nudge the Ringpet egg away from the player")
	_expect(absf(float(snapshot.get("egg_wobble_angle", 0.0))) > 0.01, "player contact should wobble the Ringpet egg")
	_expect(int(owner.lingpet_hatch_hits) == 0, "player contact should not count as a hatch hit")
	for _idx in range(30):
		runtime.update(0.016, owner)
	var sustained_nudge: float = owner.lingpet_egg_pos.x - start_pos.x
	_expect(sustained_nudge < 14.0, "sustained player contact should not shove the Ringpet egg too far")


func _verify_player_serve_ball_does_not_hatch_egg() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_serve_origin = "player"
	_register_hit(runtime, owner, egg_pos, 1)
	_expect(int(owner.lingpet_hatch_hits) == 0, "player serve ball should bounce off the egg without cracking it")
	_expect(str(owner.lingpet_state) == "egg", "player serve ball should not hatch the Ringpet egg")
	_expect(owner.ball_vel.y < 0.0, "ignored player serve hit should still reflect toward the opponent side")

	owner.ball_serve_origin = "boss"
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	runtime.update(0.21, owner)
	_register_hit(runtime, owner, egg_pos, 2)
	_expect(int(owner.lingpet_hatch_hits) == 1, "non-player-serve ball hits should still crack the egg")


func _verify_egg_hit_uses_player_paddle_reflection() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_pos = egg_pos + Vector2(30.0, -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner)
	_expect(int(owner.lingpet_hatch_hits) == 1, "egg paddle-reflection hit should still crack the egg")
	_expect(owner.ball_vel.y < 0.0, "egg hit should reflect the ball toward the opponent side")
	_expect(owner.ball_vel.x > 0.0, "right-side egg contact should angle the reflected ball to the right like a paddle hit")
	_expect(owner.ball_pos.y < egg_pos.y, "egg hit should separate the ball above the egg after reflection")


func _verify_two_ball_hits_hatch_unidentified_egg() -> void:
	var owner := FakeOwner.new()
	var hatch_candidates: Array[String] = LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true

	_register_hit(runtime, owner, egg_pos, 1)
	_expect(int(owner.lingpet_hatch_hits) == 1, "first hit should crack the egg but not yet hatch")
	_expect(str(owner.lingpet_state) == "egg", "egg should still be unhatched after one hit")
	_expect(owner.ball_vel.y < 0.0, "egg hit should reflect a downward ball toward the opponent side")

	_register_hit(runtime, owner, egg_pos, 2)
	var hatched_id := str(owner.active_lingpet_id)
	_expect(str(owner.lingpet_state) == "companion", "second hit should hatch the unidentified egg into companion state")
	_expect(hatch_candidates.has(hatched_id), "hatched lingpet should be one of the current unidentified egg candidates")
	_expect(owner.lingpet_owned_pet_ids.has(hatched_id), "hatched lingpet should be added to the owned pet id list")
	_expect((owner.lingpet_slots as Array).size() == 3 and str((owner.lingpet_slots as Array)[0]) == hatched_id, "hatched lingpet should auto-fill the first lingpet battle slot")
	_expect(int(owner.lingpet_active_slot_index) == 0, "hatched lingpet should use slot 0 as the active battle slot")
	_expect(bool(owner.lingpet_collection.get(hatched_id, false)), "hatched lingpet should be marked in the lingpet collection")
	var expected_bonus_pct: float = LingpetCatalog.get_stat(hatched_id, "gauge_gain_bonus_pct", 0.0)
	var expected_gain: float = floor(50.0 * (1.0 + expected_bonus_pct / 100.0))
	_expect(is_equal_approx(float(runtime.get_gauge_gain_per_hit(50.0)), expected_gain), "hatched lingpet should expose its catalog gauge-gain bonus")
	_expect(runtime.has_visible_effects(), "hatched lingpet should keep visible companion effects after hatching")
	_expect(owner.lingpet_companion_pos is Vector2 and owner.lingpet_companion_pos != Vector2.ZERO, "hatched lingpet should publish companion position")
	_expect(float(runtime.get_snapshot().get("hatch_flash_timer", 0.0)) > 0.0, "hatched lingpet should keep the egg-break animation active briefly")
	var panel: Dictionary = CharacterInfoOverlay.new()._get_lingpet_panel_snapshot(owner)
	_expect(str(panel.get("title", "")) == LingpetCatalog.get_display_name(hatched_id), "character-info panel should reveal the hatched lingpet after hatching")
	_expect(str(panel.get("subtitle", "")) == "동행 중", "character-info panel should show companion status after hatching")


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2, index: int) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner)


func _verify_acquire_cutin_triggers_on_hatch() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1)
	_expect(not bool(runtime.is_acquire_cutin_active()), "acquisition cut-in should not start before the egg fully hatches")
	_register_hit(runtime, owner, egg_pos, 2)
	_expect(str(owner.lingpet_state) == "companion", "second hit should hatch the unidentified egg before the cut-in check")
	_expect(bool(runtime.is_acquire_cutin_active()), "hatching should trigger the fullscreen acquisition cut-in")
	_expect(is_equal_approx(float(runtime.get_acquire_cutin_progress()), 0.0), "acquisition cut-in should start at zero progress")
	_expect(not bool(runtime.is_acquire_cutin_awaiting_dismiss()), "acquisition cut-in should not be dismissable before the reveal finishes")
	# The gated update driver must NOT advance the reveal -- only the ungated idle
	# pump does, via advance_acquire_cutin(). update() here is a no-op for it.
	runtime.update(5.0, owner)
	_expect(bool(runtime.is_acquire_cutin_active()) and is_equal_approx(float(runtime.get_acquire_cutin_progress()), 0.0), "gated update() must not advance the acquisition cut-in reveal")
	# Idle-pump advance drives the reveal; once the reveal duration elapses it
	# holds and becomes dismissable instead of auto-closing.
	runtime.advance_acquire_cutin(0.5)
	_expect(float(runtime.get_acquire_cutin_progress()) > 0.0, "advance_acquire_cutin should progress the reveal")
	_expect(not bool(runtime.is_acquire_cutin_awaiting_dismiss()), "reveal still playing should not be dismissable yet")
	runtime.advance_acquire_cutin(2.0)
	_expect(bool(runtime.is_acquire_cutin_active()), "acquisition cut-in should HOLD after the reveal (no auto-close)")
	_expect(bool(runtime.is_acquire_cutin_awaiting_dismiss()), "finished reveal should be dismissable")
	_expect(is_equal_approx(float(runtime.get_acquire_cutin_progress()), 1.0), "held reveal progress should clamp at 1.0")
	# Click/confirm does NOT close instantly -- it starts the spear-raise + water-spray
	# exit action; the cut-in stays active (gameplay paused) until the action+fade end.
	_expect(bool(runtime.begin_acquire_cutin_dismiss()), "click should start the exit action")
	_expect(bool(runtime.is_acquire_cutin_dismissing()), "exit action should be playing after the click")
	_expect(bool(runtime.is_acquire_cutin_active()), "cut-in should stay active (gameplay paused) during the exit action")
	_expect(not bool(runtime.is_acquire_cutin_awaiting_dismiss()), "a second click must not re-trigger the exit action once it is playing")
	_expect(not bool(runtime.begin_acquire_cutin_dismiss()), "begin_acquire_cutin_dismiss should be a no-op once already dismissing")
	_expect(float(runtime.get_acquire_cutin_dismiss_progress()) >= 0.0, "exit action should expose a dismiss progress for the host")
	# Advancing through the exit action + fade auto-closes the cut-in and resumes play.
	runtime.advance_acquire_cutin(2.0)
	_expect(not bool(runtime.is_acquire_cutin_active()), "exit action completing should resume battle physics on its own")
	_expect(not bool(runtime.is_acquire_cutin_dismissing()), "dismissing state should clear once the exit action finishes")
	_expect(not bool(runtime.begin_acquire_cutin_dismiss()), "starting the exit action on an inactive cut-in should be a no-op")

	# Re-adopting an already-owned Maribo (no hatch event) must NOT replay the
	# acquisition cut-in.
	var owned_owner := FakeOwner.new()
	owned_owner.lingpet_owned_pet_ids = ["maribo"]
	var owned_runtime: Object = LingpetEggRuntime.new()
	owned_runtime.update(0.0, owned_owner)
	_expect(str(owned_owner.lingpet_state) == "companion", "owned Maribo should adopt directly as companion")
	_expect(not bool(owned_runtime.is_acquire_cutin_active()), "adopting an already-owned Maribo should not replay the acquisition cut-in")


func _verify_owned_maribo_is_kept_as_companion() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.update(0.0, owner), "owned Maribo should sync as a companion instead of spawning an egg")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("state", "")) == "companion", "owned Maribo should restore companion runtime state")
	_expect(str(owner.lingpet_state) == "companion", "owned Maribo should publish companion state to the owner")
	_expect(str(owner.active_lingpet_id) == "maribo", "owned Maribo should become the active lingpet")


func _verify_lingpet_battle_slot_model() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.lingpet_slots = ["", "maribo", ""]
	owner.lingpet_active_slot_index = 1
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.update(0.0, owner), "runtime should adopt the lingpet from the active battle slot")
	_expect(str(owner.active_lingpet_id) == "maribo", "active battle slot should publish its lingpet as the active companion")
	_expect(int(owner.lingpet_active_slot_index) == 1, "owner should preserve the selected active lingpet slot")
	_expect(str((owner.lingpet_slots as Array)[1]) == "maribo", "owner should keep exactly three battle slot entries")
	var snapshot: Dictionary = runtime.get_snapshot()
	var slots: Array = snapshot.get("battle_slot_pet_ids", []) as Array
	_expect(slots.size() == 3 and str(slots[1]) == "maribo", "runtime snapshot should expose the three lingpet battle slots")
	_expect(int(snapshot.get("active_slot_index", -1)) == 1, "runtime snapshot should expose the active lingpet slot index")
	_expect(str(snapshot.get("active_pet_id", "")) == "maribo", "runtime snapshot should expose the active slot pet id")
	_expect(not bool(runtime.switch_lingpet_slot(0, owner)), "switching to an empty lingpet slot should fail")
	_expect(bool(runtime.switch_lingpet_slot(1, owner)), "switching to the occupied active lingpet slot should succeed")
	_expect(not bool(runtime.cycle_lingpet_slot(1, owner)), "cycling with only one occupied lingpet slot should be a no-op")
	var save_snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(str((save_snapshot.get("battle_slot_pet_ids", []) as Array)[1]) == "maribo", "save snapshot should carry the three battle slots")
	_expect(int(save_snapshot.get("active_slot_index", -1)) == 1, "save snapshot should carry the active slot index")

	var restored_owner := FakeOwner.new()
	var restored_runtime: Object = LingpetEggRuntime.new()
	var restore_result: Dictionary = restored_runtime.apply_save_snapshot({
		"version": 1,
		"pet_id": "maribo",
		"state": "companion",
		"owned_pet_ids": ["maribo"],
		"battle_slot_pet_ids": ["", "maribo", ""],
		"active_slot_index": 1,
		"active_pet_id": "maribo",
	}, restored_owner)
	_expect(bool(restore_result.get("restored", false)), "slot-backed lingpet save snapshot should restore")
	_expect(int(restored_owner.lingpet_active_slot_index) == 1, "restore should republish the active battle slot index")
	_expect(str((restored_owner.lingpet_slots as Array)[1]) == "maribo", "restore should republish the lingpet battle slots")

	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var collection_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_collection_state.gd")
	var switch_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_switch_state.gd")
	_expect(runtime_source.find("func cycle_lingpet_slot") >= 0, "lingpet runtime should expose a non-number-key slot cycle method")
	_expect(collection_source.find("func find_next_occupied_slot_index") >= 0, "lingpet collection state should find the next occupied battle slot for cycling")
	_expect(runtime_source.find("lingpet_companion_switch_state.gd") >= 0, "lingpet runtime should delegate switch transition state to the switch-state helper")
	_expect(runtime_source.find("_switch_transition_timer") < 0, "lingpet runtime should not own raw switch-transition timer fields")
	_expect(switch_source.find("func get_snapshot") >= 0, "switch-state helper should expose switch VFX snapshot fields")
	var collection_state := LingpetCollectionState.new()
	var test_slots: Array[String] = ["maribo", "", "future_pet"]
	collection_state.battle_slot_pet_ids = test_slots
	collection_state.active_slot_index = 0
	_expect(int(collection_state.find_next_occupied_slot_index(1, null)) == 2, "lingpet slot cycling should skip empty slots and land on the next occupied slot")
	collection_state.active_slot_index = 2
	_expect(int(collection_state.find_next_occupied_slot_index(-1, null)) == 0, "reverse lingpet slot cycling should skip empty slots and wrap to the previous occupied slot")

	var switch_state := LingpetCompanionSwitchState.new()
	switch_state.begin("maribo", "maribo", LingpetEggRuntime.COMPANION_SWITCH_TRANSITION_SECONDS)
	var switch_snapshot: Dictionary = switch_state.get_snapshot(LingpetEggRuntime.COMPANION_SWITCH_TRANSITION_SECONDS)
	_expect(float(switch_snapshot.get("companion_switch_transition", 0.0)) > 0.0, "lingpet slot switches should expose a transient companion switch VFX ratio")
	_expect(str(switch_snapshot.get("companion_switch_from_pet_id", "")) == "maribo", "switch VFX should expose the outgoing lingpet id while active")
	switch_state.advance(LingpetEggRuntime.COMPANION_SWITCH_TRANSITION_SECONDS + 0.05)
	var expired_switch_snapshot: Dictionary = switch_state.get_snapshot(LingpetEggRuntime.COMPANION_SWITCH_TRANSITION_SECONDS)
	_expect(is_equal_approx(float(expired_switch_snapshot.get("companion_switch_transition", -1.0)), 0.0), "lingpet switch VFX should expire after its short transition window")

	var renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	_expect(renderer_source.find("_draw_switch_transition") >= 0, "companion renderer should draw the lingpet slot switch transition")


func _verify_companion_visual_and_pillar_card() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var first_pos: Vector2 = owner.lingpet_companion_pos
	var expected_lane_y: float = owner.player_pos.y + owner.player_paddle_height * 0.5
	_expect(runtime.has_visible_effects(), "owned Maribo companion should remain visible on the playfield")
	_expect(absf(first_pos.y - expected_lane_y) <= 1.0, "owned Maribo companion should start on the player-height patrol lane")
	_expect(first_pos.x >= 42.0 and first_pos.x <= 718.0, "owned Maribo companion should start inside the patrol bounds")
	owner.player_pos.x += 120.0
	runtime.update(0.5, owner)
	var moved_pos: Vector2 = owner.lingpet_companion_pos
	_expect(absf(moved_pos.y - expected_lane_y) <= 1.0, "Maribo companion should stay on the player-height patrol lane")
	_expect(absf(moved_pos.x - first_pos.x) > 1.0, "Maribo companion should patrol independently instead of attaching to the player side")
	_expect(absf(moved_pos.x - (owner.player_pos.x + owner.player_paddle_width * 0.5)) > 20.0, "Maribo companion should not snap to the paddle center after player movement")
	var snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(snapshot.get("companion_pos", Vector2.ZERO) is Vector2, "save snapshot should keep companion visual position")
	_expect(float(snapshot.get("companion_patrol_dir", 0.0)) != 0.0, "save snapshot should keep Maribo patrol direction")
	_expect(float(snapshot.get("companion_patrol_speed", 0.0)) >= 70.0 and float(snapshot.get("companion_patrol_speed", 0.0)) <= 135.0, "save snapshot should keep Maribo's current patrol speed")


func _verify_companion_patrol_edge_pause_and_speed_change() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.apply_save_snapshot({
		"pet_id": "maribo",
		"state": "companion",
		"owned_pet_ids": ["maribo"],
		"companion_pos": Vector2(43.0, 704.0),
		"companion_patrol_dir": -1.0,
		"companion_patrol_seed": 12345,
		"companion_patrol_speed": 120.0,
	}, owner)
	runtime.update(0.2, owner)
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(is_equal_approx(owner.lingpet_companion_pos.x, 42.0), "Maribo patrol should clamp at the left edge")
	_expect(float(snapshot.get("companion_patrol_pause", 0.0)) > 0.0, "Maribo patrol should pause after hitting a patrol edge")
	_expect(float(snapshot.get("companion_patrol_speed", 0.0)) >= 70.0 and float(snapshot.get("companion_patrol_speed", 0.0)) <= 135.0, "Maribo patrol should keep a randomized speed band")


func _verify_companion_ball_collision_soft_bounce() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var companion_pos: Vector2 = owner.lingpet_companion_pos
	owner.ball_active = true
	owner.ball_pos = companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.01, owner)
	_expect(owner.ball_vel.y < 0.0, "Maribo body collision should softly bounce a downward ball upward")
	_expect(int(owner.lingpet_companion_contact_count) == 1, "Maribo body collision should publish a contact count")
	_expect(owner.lingpet_companion_hit_cooldown > 0.0, "Maribo body collision should arm an internal cooldown")
	_expect(owner.lingpet_companion_last_contact_pos is Vector2 and owner.lingpet_companion_last_contact_pos != Vector2.ZERO, "Maribo body collision should publish the last contact position")
	var count_after_first_hit: int = int(owner.lingpet_companion_contact_count)
	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -5.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.0, owner)
	_expect(int(owner.lingpet_companion_contact_count) == count_after_first_hit, "Maribo body collision cooldown should prevent same-overlap repeat hits")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(int(snapshot.get("companion_contact_count", 0)) == count_after_first_hit, "runtime snapshot should expose Maribo contact count")


func _verify_companion_guards_dalji_whip() -> void:
	# Bug: during Dalji's 상모돌리기 whip the ball is owned by the skill (forced
	# downward each frame), so the companion bounce was ignored. The companion hit
	# must route through the whip's register_player_hit (same as a player paddle
	# guard) so the whip releases the ball and it reflects upward.
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var whip := FakeWhip.new()
	var registry := FakeRegistry.new({"stage1_dalji_whip_skill_state": whip})
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	owner.ball_active = true
	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.01, owner, registry)
	_expect(int(owner.lingpet_companion_contact_count) == 1, "companion should register the hit during the whip")
	_expect(whip.player_hits == 1, "companion hit must notify the Dalji whip via register_player_hit so it releases the ball")
	_expect(owner.ball_vel.y < 0.0, "ball must reflect upward toward the boss even during the whip")


func _verify_companion_paddle_hit_width() -> void:
	# The hit zone is now a wide paddle-like box (~100px), not the old 44px circle.
	# A ball offset ~45px horizontally (which the old radius-22 circle would miss)
	# is caught; a ball well beyond the width is not.
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var companion_pos: Vector2 = owner.lingpet_companion_pos
	owner.ball_active = true
	owner.ball_pos = companion_pos + Vector2(45.0, 0.0)
	owner.ball_vel = Vector2(0.0, 8.0)
	runtime.update(0.01, owner)
	_expect(int(owner.lingpet_companion_contact_count) == 1, "wide paddle footprint should catch a ball ~45px off-center (old circle would miss)")

	var owner2 := FakeOwner.new()
	owner2.lingpet_owned_pet_ids = ["maribo"]
	var runtime2: Object = LingpetEggRuntime.new()
	runtime2.update(0.0, owner2)
	owner2.ball_active = true
	owner2.ball_pos = owner2.lingpet_companion_pos + Vector2(90.0, 0.0)
	owner2.ball_vel = Vector2(0.0, 8.0)
	runtime2.update(0.01, owner2)
	_expect(int(owner2.lingpet_companion_contact_count) == 0, "a ball well beyond the ~100px width should not be caught")


func _verify_companion_paddle_bounce_and_sound() -> void:
	# When Maribo hits the ball it must reflect like a PLAYER PADDLE: launched
	# toward the boss (upward), with the angle driven by the horizontal hit offset
	# and the incoming speed preserved -- and play the player paddle-hit sound.
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var audio := FakePaddleAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	var companion_pos: Vector2 = owner.lingpet_companion_pos
	owner.ball_active = true
	# Overlap with a horizontal offset so the launch angle is non-trivial.
	owner.ball_pos = companion_pos + Vector2(10.0, -6.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.01, owner, registry)
	# Launched toward the boss (upward), not a soft normal reflection.
	_expect(owner.ball_vel.y < 0.0, "Maribo hit must launch the ball toward the boss (upward), like a player paddle")
	# Speed preserved (paddle parity, not the old 0.96 soft slowdown).
	_expect(absf(owner.ball_vel.length() - 14.0) <= 0.5, "Maribo hit should preserve the incoming ball speed (paddle physics)")
	# Right-side hit (hit_pos > 0) should bias the launch toward +x (paddle angle).
	_expect(owner.ball_vel.x > 0.0, "off-center hit should angle the launch like a paddle (hit_pos sign)")
	# Launch within the paddle max-angle cone (<= 60 deg from straight up).
	_expect(absf(owner.ball_vel.x) <= absf(owner.ball_vel.y) * 1.8, "launch angle should stay within the paddle bounce cone")
	# Player paddle-hit sound played.
	_expect(audio.paddle_hits == 1, "Maribo hit should play the player paddle-hit sound")


func _verify_companion_hit_gauge_passive() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.special_gauge = 100.0
	var feedback := FakeFeedback.new()
	var orb_hud_state := FakeOrbHudState.new()
	var audio := FakePaddleAudio.new()
	var registry := FakeRegistry.new({
		"battle_feedback_state": feedback,
		"orb_hud_state": orb_hud_state,
		"game_audio": audio,
	})
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	owner.ball_active = true

	_hit_companion(runtime, owner, registry, owner.lingpet_companion_pos)
	_expect(is_equal_approx(owner.special_gauge, 140.0), "Maribo body hit should restore the original +40 gauge passive")
	_expect(is_equal_approx(owner.lingpet_companion_hit_gauge_last_gain, 40.0), "Maribo body hit should publish the passive gauge gain")
	_expect(int(owner.lingpet_companion_hit_gauge_trigger_count) == 1, "Maribo body hit should count the passive gauge trigger")
	_expect(feedback.gauge_flashes == 1, "Maribo body hit gauge passive should trigger gauge flash feedback")
	_expect(orb_hud_state.gauge_spins == 1, "Maribo body hit gauge passive should trigger the gauge orb spin")
	_expect(is_equal_approx(owner.lingpet_skill_last_gain, 0.0), "Maribo body-hit passive should not masquerade as Hydro Sphere direct gauge gain")

	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -160.0)
	runtime.update(0.43, owner, registry)
	_hit_companion(runtime, owner, registry, owner.lingpet_companion_pos)
	_expect(is_equal_approx(owner.special_gauge, 180.0), "Maribo body hit gauge gain should be a common ringpet stat without a resonance-charge cooldown")
	_expect(int(owner.lingpet_companion_hit_gauge_trigger_count) == 2, "repeat body-hit gauge gain should increment trigger count without a resonance-charge cooldown")
	_expect(feedback.gauge_flashes == 2, "repeat body-hit gauge gain should flash gauge again")


func _verify_companion_strike_anticipates_contact() -> void:
	# Like the player/boss attack sheets, the companion must start the strike
	# swing BEFORE the ball reaches it (anticipatory), so the wind-up is visible
	# ahead of contact and the thrust lands on the ball -- not after it bounced.
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var companion_pos: Vector2 = owner.lingpet_companion_pos
	owner.ball_active = true
	# Ball ABOVE the companion, descending, X-aligned, NOT yet overlapping.
	owner.ball_pos = Vector2(companion_pos.x, companion_pos.y - 70.0)
	owner.ball_vel = Vector2(0.0, 8.0)
	runtime.update(0.0139, owner)
	# Anticipation fired before any contact: strike active, no bounce yet.
	_expect(int(owner.lingpet_companion_contact_count) == 0, "ball is still above the companion -> no contact yet")
	_expect(bool(runtime.is_companion_striking_for_tests()), "strike must ARM before the ball reaches the companion (anticipatory, like other characters)")
	var strike_frame: int = int(runtime.get_companion_strike_frame_for_tests())
	_expect(strike_frame >= 8, "anticipatory strike skips the dead-air and starts in the wind-up")
	_expect(strike_frame < 22, "anticipatory strike shows the wind-up BEFORE the thrust apex (선행모션 precedes contact)")

	# A receding ball (moving away) must NOT arm a strike.
	var owner2 := FakeOwner.new()
	owner2.lingpet_owned_pet_ids = ["maribo"]
	var runtime2: Object = LingpetEggRuntime.new()
	runtime2.update(0.0, owner2)
	owner2.ball_active = true
	owner2.ball_pos = Vector2(owner2.lingpet_companion_pos.x, owner2.lingpet_companion_pos.y - 70.0)
	owner2.ball_vel = Vector2(0.0, -8.0)
	runtime2.update(0.0139, owner2)
	_expect(not bool(runtime2.is_companion_striking_for_tests()), "a receding ball must not arm an anticipatory strike")

	# Actual overlap still bounces and counts, with the swing active (pre-armed or
	# reactive fallback) and not double-counted within the cooldown.
	var owner3 := FakeOwner.new()
	owner3.lingpet_owned_pet_ids = ["maribo"]
	var runtime3: Object = LingpetEggRuntime.new()
	runtime3.update(0.0, owner3)
	owner3.ball_active = true
	owner3.ball_pos = owner3.lingpet_companion_pos + Vector2(0.0, -6.0)
	owner3.ball_vel = Vector2(0.0, 14.0)
	runtime3.update(0.01, owner3)
	_expect(owner3.ball_vel.y < 0.0, "overlap must still bounce the ball")
	_expect(int(owner3.lingpet_companion_contact_count) == 1, "overlap must still register one contact")
	_expect(bool(runtime3.is_companion_striking_for_tests()), "strike should be playing on contact (pre-armed or reactive fallback)")
	owner3.ball_pos = owner3.lingpet_companion_pos + Vector2(0.0, -5.0)
	owner3.ball_vel = Vector2(0.0, 14.0)
	runtime3.update(0.0, owner3)
	_expect(int(owner3.lingpet_companion_contact_count) == 1, "cooldown should prevent same-overlap re-count")


func _verify_companion_skill_card_hydro_sphere() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.special_gauge = 100.0
	var runtime: Object = LingpetEggRuntime.new()
	var audio := FakePaddleAudio.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"status_effect_state": status_state,
	})
	runtime.update(0.0, owner, registry)
	owner.ball_active = true
	_expect(str(owner.lingpet_skill_id) == "maribo_hydro_sphere", "owned Maribo should publish its Hydro Sphere skill-card id")
	_expect(str(owner.lingpet_skill_name) == "하이드로 스피어", "owned Maribo should publish its Korean Hydro Sphere skill-card name")
	_expect(bool(owner.lingpet_skill_ready), "owned Maribo skill should start ready")

	# Source keys the boss-rail composition layer reads to build the merged card.
	var rail_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(runtime.is_maribo_companion_active()), "owned Maribo should be companion-active for the boss-rail entry gate")
	_expect(str(rail_snap.get("companion_skill_id", "")) == "maribo_hydro_sphere", "active companion snapshot should expose the hydro sphere skill id for the rail entry")
	_expect(absf(float(rail_snap.get("companion_skill_cooldown_duration", 0.0)) - 40.0) <= 0.01, "lingpet rail entry should source the 40s companion cooldown duration")
	_expect(absf(float(rail_snap.get("companion_skill_windup_seconds", 0.0)) - 1.0) <= 0.01, "lingpet rail entry should source the catalog skill wind-up duration")
	_expect(rail_snap.has("companion_skill_ready"), "lingpet rail entry should source ready state from the companion snapshot")
	_expect(rail_snap.has("companion_skill_flash_ratio"), "lingpet rail entry should source a normalized flash ratio (not the raw 24-frame boss unit)")

	# Egg / pre-hatch state must NOT expose a rail entry -- the lingpet stays a mystery until it hatches.
	var egg_owner := FakeOwner.new()
	var egg_runtime: Object = LingpetEggRuntime.new()
	egg_runtime.update(0.0, egg_owner)
	_expect(not bool(egg_runtime.is_maribo_companion_active()), "pre-hatch lingpet must not be companion-active (no rail card before hatch)")
	var egg_snap: Dictionary = egg_runtime.get_snapshot()
	_expect(str(egg_snap.get("companion_skill_id", "")) == "", "pre-hatch snapshot should not expose a hydro sphere rail entry id")
	_expect(not bool(egg_snap.get("companion_skill_ready", false)), "pre-hatch snapshot should report the companion skill as not ready")

	# First skill update arms the telegraphed throw wind-up (no launch yet).
	runtime.update(0.0, owner, registry)
	var windup_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(windup_snap.get("companion_skill_winding_up", false)), "Hydro Sphere should enter a telegraphed throw wind-up before launching")
	_expect(not bool(windup_snap.get("hydro_sphere_projectile_active", false)), "Hydro Sphere should NOT launch the projectile during the wind-up")
	_expect(int(owner.lingpet_skill_trigger_count) == 0, "Hydro Sphere wind-up should not count a launch yet")
	_expect(audio.hydro_count == 0, "Hydro Sphere should hold its launch cue until the wind-up releases")

	# Completing the wind-up launches the projectile, counts the cast, and starts the 40s cooldown.
	runtime.update(LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS + 0.05, owner, registry)
	_expect(is_equal_approx(owner.special_gauge, 100.0), "Hydro Sphere should not replace Maribo's passive gauge bonus with a gauge grant")
	_expect(int(owner.lingpet_skill_trigger_count) == 1, "Hydro Sphere should count its launch after the wind-up")
	_expect(is_equal_approx(owner.lingpet_skill_last_gain, 0.0), "Hydro Sphere should publish zero direct gauge gain")
	_expect(owner.lingpet_skill_cooldown > 39.0, "Hydro Sphere should enter a 40-second cooldown at launch")
	_expect(not bool(owner.lingpet_skill_ready), "Maribo skill should not be ready during cooldown")
	_expect(audio.hydro_count == 1, "Hydro Sphere should play the water hydro cue on launch")
	var skill_snapshot: Dictionary = runtime.get_snapshot()
	_expect(not bool(skill_snapshot.get("companion_skill_winding_up", false)), "Hydro Sphere wind-up should clear once the projectile launches")
	_expect(float(skill_snapshot.get("companion_skill_flash_timer", 0.0)) > 0.0, "Maribo skill should expose an activation flash timer for playfield/card VFX")
	var flash_ratio: float = float(skill_snapshot.get("companion_skill_flash_ratio", 0.0))
	_expect(flash_ratio > 0.0 and flash_ratio <= 1.0, "Maribo skill flash ratio should be normalized 0..1 so the rail flash glow actually lights up")
	_expect(skill_snapshot.get("companion_skill_origin", Vector2.ZERO) is Vector2 and skill_snapshot.get("companion_skill_origin", Vector2.ZERO) != Vector2.ZERO, "Maribo skill should remember its activation origin for VFX")
	_expect(bool(skill_snapshot.get("hydro_sphere_projectile_active", false)), "Hydro Sphere should launch a projectile before the wall splash")
	var first_trigger_count: int = int(owner.lingpet_skill_trigger_count)

	owner.boss_pos = Vector2(owner.lingpet_companion_pos.x - owner.boss_paddle_width * 0.5, 25.0)
	runtime.update(1.6, owner, registry)
	skill_snapshot = runtime.get_snapshot()
	_expect(not bool(skill_snapshot.get("hydro_sphere_projectile_active", true)), "Hydro Sphere projectile should stop when it reaches the opponent wall")
	_expect(bool(skill_snapshot.get("hydro_sphere_puddle_active", false)), "Hydro Sphere should create a wet floor puddle after the wall impact")
	var puddle_hw: float = float(skill_snapshot.get("hydro_sphere_puddle_half_width", 0.0))
	var puddle_hh: float = float(skill_snapshot.get("hydro_sphere_puddle_half_height", 0.0))
	_expect(puddle_hw > 0.0 and puddle_hh > 0.0, "Hydro Sphere puddle should expose its ellipse half-extents")
	_expect(puddle_hw > puddle_hh * 1.5, "Hydro Sphere puddle should be a WIDE horizontal ellipse (width >> height)")
	var slow_calls: Array[Dictionary] = status_state.get_calls_for_source("maribo_hydro_sphere_puddle")
	_expect(not slow_calls.is_empty(), "Hydro Sphere puddle should apply boss slow while the boss touches it")
	if not slow_calls.is_empty():
		var first_slow: Dictionary = slow_calls[0]
		_expect(str(first_slow.get("target", "")) == "boss", "Hydro Sphere puddle slow should target the boss")
		_expect(str(first_slow.get("status_id", "")) == "slow", "Hydro Sphere puddle should apply the slow status")
		_expect(is_equal_approx(float(first_slow.get("duration_frames", 0.0)), 4.0), "Hydro Sphere puddle should refresh a short slow while touched")
		_expect(is_equal_approx(float((first_slow.get("data", {}) as Dictionary).get("multiplier", 0.0)), 0.65), "Hydro Sphere puddle should use the intended slow multiplier")

	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -90.0)
	_hit_companion(runtime, owner, registry, owner.lingpet_companion_pos)
	_expect(int(owner.lingpet_companion_contact_count) >= 1, "Maribo body should keep colliding while the skill is on cooldown")
	_expect(int(owner.lingpet_skill_trigger_count) == first_trigger_count, "Hydro Sphere cooldown should block repeated launches")
	_expect(is_equal_approx(owner.special_gauge, 140.0), "Hydro Sphere cooldown should still allow Maribo's body-hit +40 passive")
	_expect(is_equal_approx(owner.lingpet_skill_last_gain, 0.0), "Hydro Sphere should keep zero direct gauge gain while the body-hit passive is separate")
	_expect(is_equal_approx(owner.lingpet_companion_hit_gauge_last_gain, 40.0), "body-hit passive should publish +40 separately from the Hydro Sphere rail skill")

	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -90.0)
	# Cooldown expiry re-arms the wind-up; the relaunch only fires once it completes.
	runtime.update(40.1, owner, registry)
	_expect(bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "Hydro Sphere should re-arm its throw wind-up after the cooldown expires")
	_expect(int(owner.lingpet_skill_trigger_count) == first_trigger_count, "Hydro Sphere should not relaunch until the re-armed wind-up completes")
	runtime.update(LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS + 0.05, owner, registry)
	_expect(int(owner.lingpet_skill_trigger_count) == first_trigger_count + 1, "Hydro Sphere should relaunch after its 40-second cooldown plus the wind-up")


func _verify_hydro_puddle_vfx() -> void:
	# Texture-fragment cache builds clean (square radial-faded textures).
	var caustic: Texture2D = HydroPuddleTextureCache.get_caustic_texture()
	var surface: Texture2D = HydroPuddleTextureCache.get_surface_texture()
	var foam: Texture2D = HydroPuddleTextureCache.get_foam_ring_texture()
	var droplet: Texture2D = HydroPuddleTextureCache.get_droplet_texture()
	for tex in [caustic, surface, foam, droplet]:
		_expect(tex != null and tex.get_width() > 1 and tex.get_height() > 1, "hydro puddle texture cache should build a non-empty texture")

	# Driving the skill to a wall impact must seed a splash particle burst.
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	var audio := FakePaddleAudio.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"status_effect_state": status_state,
	})
	runtime.update(0.0, owner, registry)
	owner.ball_active = true
	runtime.update(0.0, owner, registry)  # arm wind-up
	runtime.update(LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS + 0.05, owner, registry)  # launch projectile
	_expect(bool(runtime.get_snapshot().get("hydro_sphere_projectile_active", false)), "hydro projectile should be in flight before the splash")
	# Step in small frames until the projectile reaches the opponent wall and spawns
	# the puddle; the spawning frame's small delta keeps the splash particles alive.
	var spawned := false
	for i in range(80):
		runtime.update(0.05, owner, registry)
		if bool(runtime.get_snapshot().get("hydro_sphere_puddle_active", false)):
			spawned = true
			break
	_expect(spawned, "hydro puddle should spawn after the projectile reaches the opponent wall")
	_expect(runtime.get_hydro_puddle_particle_count_for_tests() > 0, "wall impact should seed a splash particle burst")

	# Source wiring: the puddle draws via the texture cache + caustic layers + particles.
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var skill_runtime_host_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	var hydro_skill_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")
	_expect(runtime_source.find("lingpet_skill_runtime_host.gd") >= 0, "egg runtime should delegate concrete skill effects to the runtime host")
	_expect(skill_runtime_host_source.find("lingpet_hydro_sphere_skill.gd") >= 0, "skill runtime host should delegate Hydro Sphere projectile/puddle behavior to the skill module")
	_expect(hydro_skill_source.find("HydroPuddleTextureCache") >= 0, "Hydro Sphere module should draw through the procedural texture cache")
	_expect(hydro_skill_source.find("_draw_particles") >= 0, "Hydro Sphere module should draw pooled water particles")
	_expect(hydro_skill_source.find("_blit_hydro_caustic") >= 0, "Hydro Sphere module should blit scroll-animated caustic layers")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd"), "Hydro Sphere skill module should exist")
	_expect(FileAccess.file_exists("res://scripts/effects/hydro_puddle_texture_cache.gd"), "hydro puddle texture cache script should exist")


func _verify_save_snapshot_roundtrip() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1)
	_register_hit(runtime, owner, egg_pos, 2)
	var hatched_id := str(owner.active_lingpet_id)

	var snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(int(snapshot.get("version", 0)) == 1, "lingpet save snapshot should carry a schema version")
	_expect((snapshot.get("owned_pet_ids", []) as Array).has(hatched_id), "lingpet save snapshot should preserve the hatched lingpet")
	_expect(str((snapshot.get("battle_slot_pet_ids", []) as Array)[0]) == hatched_id, "lingpet save snapshot should preserve the battle slot assignment")
	_expect(int(snapshot.get("active_slot_index", -1)) == 0, "lingpet save snapshot should preserve the active battle slot index")

	var restored_owner := FakeOwner.new()
	restored_owner.ai_mode = "champion"
	var restored: Object = LingpetEggRuntime.new()
	var restore_result: Dictionary = restored.apply_save_snapshot(snapshot, restored_owner)
	_expect(bool(restore_result.get("restored", false)), "lingpet save snapshot should restore successfully")
	_expect(str(restored_owner.lingpet_state) == "companion", "restored owned lingpet should sync companion state")
	_expect(restored_owner.owned_lingpet_ids.has(hatched_id), "restore should republish owned pet ids to the owner")
	_expect(str((restored_owner.lingpet_slots as Array)[0]) == hatched_id, "restore should republish battle slot assignment")
	_expect(bool(restored_owner.owned_lingpets.get(hatched_id, false)), "restore should republish owned collection to the owner")


func _verify_save_store_persists_and_restores_maribo() -> void:
	var companion_path := "user://lingpet_save_store_companion_smoke.cfg"
	_remove_user_file(companion_path)
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1)
	_register_hit(runtime, owner, egg_pos, 2)

	var save_store: Object = LingpetSaveStore.new()
	save_store.set_save_path(companion_path)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_expect(bool(save_store.save_runtime(owner, registry)), "lingpet save store should clear companion run state on restart")
	_expect(not FileAccess.file_exists(companion_path), "lingpet save store should not keep a companion run-state save file")

	_write_lingpet_snapshot(companion_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "companion",
		"hatch_hits": 3,
		"required_hits": 3,
		"owned_pet_ids": ["maribo"],
		"active_pet_id": "maribo",
	})
	var restored_owner := FakeOwner.new()
	restored_owner.ai_mode = "champion"
	var restored_runtime: Object = LingpetEggRuntime.new()
	var restored_store: Object = LingpetSaveStore.new()
	restored_store.set_save_path(companion_path)
	var restored_registry := FakeRegistry.new({"lingpet_egg_runtime": restored_runtime})
	var restore_result: Dictionary = restored_store.restore_runtime(restored_owner, restored_registry)
	_expect(str(restore_result.get("reason", "")) == "run_state_reset_on_entry", "legacy saved companion should be treated as volatile on re-entry")
	_expect(str(restored_owner.lingpet_state) == "none", "saved Maribo should not restore as companion after game restart")
	_expect(is_equal_approx(float(restored_runtime.get_gauge_gain_per_hit(50.0)), 50.0), "reset saved Maribo should not keep the companion gauge bonus")
	_remove_user_file(companion_path)

	var egg_path := "user://lingpet_save_store_egg_smoke.cfg"
	_remove_user_file(egg_path)
	var egg_owner := FakeOwner.new()
	var egg_runtime: Object = LingpetEggRuntime.new()
	egg_runtime.update(0.0, egg_owner)
	egg_owner.ball_active = true
	_register_hit(egg_runtime, egg_owner, egg_owner.lingpet_egg_pos, 1)
	var egg_store: Object = LingpetSaveStore.new()
	egg_store.set_save_path(egg_path)
	_expect(bool(egg_store.save_runtime(egg_owner, FakeRegistry.new({"lingpet_egg_runtime": egg_runtime}))), "lingpet save store should clear volatile egg progress")
	_expect(not FileAccess.file_exists(egg_path), "lingpet save store should not keep a pre-hatch egg save file")

	_write_lingpet_snapshot(egg_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "egg",
		"hatch_hits": 1,
		"required_hits": 3,
		"egg_pos": Vector2(120.0, 704.0),
		"owned_pet_ids": [],
	})
	var deferred_owner := FakeOwner.new()
	deferred_owner.ai_mode = "champion"
	var deferred_runtime: Object = LingpetEggRuntime.new()
	var deferred_store: Object = LingpetSaveStore.new()
	deferred_store.set_save_path(egg_path)
	var deferred_result: Dictionary = deferred_store.restore_runtime(deferred_owner, FakeRegistry.new({"lingpet_egg_runtime": deferred_runtime}))
	_expect(str(deferred_result.get("reason", "")) == "run_state_reset_on_entry", "legacy saved egg progress should be treated as volatile on re-entry")
	_expect(str(deferred_result.get("state", "")) == "none", "legacy saved egg progress should not restore when the current run is ineligible")
	_expect(str(deferred_owner.lingpet_state) == "none", "ineligible restore should not show an egg")

	_write_lingpet_snapshot(egg_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "egg",
		"hatch_hits": 1,
		"required_hits": 3,
		"egg_pos": Vector2(120.0, 704.0),
		"owned_pet_ids": [],
	})
	var eligible_owner := FakeOwner.new()
	var eligible_runtime: Object = LingpetEggRuntime.new()
	var eligible_store: Object = LingpetSaveStore.new()
	eligible_store.set_save_path(egg_path)
	eligible_store.restore_runtime(eligible_owner, FakeRegistry.new({"lingpet_egg_runtime": eligible_runtime}))
	_expect(str(eligible_owner.lingpet_state) == "egg", "legacy saved egg progress should restart as a fresh Junior Mika egg")
	_expect(int(eligible_owner.lingpet_hatch_hits) == 0, "legacy saved egg progress should reset hatch-hit count on re-entry")
	_remove_user_file(egg_path)


func _verify_battle_lifecycle_restores_lingpet_save() -> void:
	var save_path := "user://lingpet_lifecycle_restore_smoke.cfg"
	_remove_user_file(save_path)
	var save_store: Object = LingpetSaveStore.new()
	save_store.set_save_path(save_path)
	_write_lingpet_snapshot(save_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "companion",
		"hatch_hits": 3,
		"required_hits": 3,
		"owned_pet_ids": ["maribo"],
		"active_pet_id": "maribo",
	})

	var owner := FakeBattleOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new({
		"battle_scene_bootstrap": FakeBootstrap.new(),
		"lingpet_egg_runtime": runtime,
		"lingpet_save_store": save_store,
	})
	BattleSceneLifecycle.new().initialize(owner, registry)
	_expect(str(owner.lingpet_state) == "none", "battle lifecycle should reset stale saved Maribo run state")
	_expect(str(owner.active_lingpet_id) == "", "battle lifecycle reset should not publish active Maribo")
	_expect(not FileAccess.file_exists(save_path), "battle lifecycle should clear stale lingpet run-state save files")
	owner.free()
	_remove_user_file(save_path)


func _verify_maribo_companion_gauge_bonus() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	_expect(bool(runtime.is_maribo_companion_active()), "owned Maribo should activate the companion effect")
	_expect(str(owner.lingpet_effect_text).find("+10%") >= 0, "owner effect text should describe Maribo's gauge bonus")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(is_equal_approx(float(snapshot.get("companion_patrol_speed_min", 0.0)), 70.0), "Maribo snapshot should expose patrol speed min for the character-info panel")
	_expect(is_equal_approx(float(snapshot.get("companion_patrol_speed_max", 0.0)), 135.0), "Maribo snapshot should expose patrol speed max for the character-info panel")
	_expect(is_equal_approx(float(snapshot.get("companion_catch_width", 0.0)), 100.0), "Maribo snapshot should expose the real horizontal catch footprint")
	_expect(is_equal_approx(float(snapshot.get("companion_catch_height", 0.0)), 44.0), "Maribo snapshot should expose the real vertical catch footprint")
	_expect(is_equal_approx(float(snapshot.get("companion_defense_rate", 0.0)), 0.30), "Maribo snapshot should expose defense rate only once AI is wired")
	_expect(is_equal_approx(float(owner.lingpet_companion_patrol_speed_min), 70.0), "owner should sync Maribo speed range for character-info")
	_expect(is_equal_approx(float(owner.lingpet_companion_catch_width), 100.0), "owner should sync Maribo catch width for character-info")
	_expect(is_equal_approx(float(owner.lingpet_companion_defense_rate), 0.30), "owner should sync Maribo defense rate for character-info")
	_expect(is_equal_approx(float(runtime.get_gauge_gain_per_hit(50.0)), 55.0), "Maribo should turn 50 gauge gain into 55")

	var overlay := CharacterInfoOverlay.new()
	var lingpet_stats: Array = overlay._build_lingpet_stats(owner)
	_expect(str(_find_stat(lingpet_stats, "이동 속도").get("value", "")) == "2.00", "character-info lingpet stats should show Maribo speed as a slower single player-style value")
	_expect(str(_find_stat(lingpet_stats, "몸집크기").get("value", "")).find("100x44") >= 0, "character-info lingpet stats should show the body-size footprint")
	_expect(_find_stat(lingpet_stats, "캐치 범위").is_empty(), "character-info lingpet stats should not show the old catch-range label")
	_expect(str(_find_stat(lingpet_stats, "게이지 획득량").get("value", "")) == "40pt", "character-info lingpet stats should show the direct hit gauge gain as a common stat")
	_expect(str(_find_stat(lingpet_stats, "액티브 쿨타임").get("value", "")) == "40초", "character-info lingpet stats should show Hydro Sphere cooldown")
	_expect(_find_stat(lingpet_stats, "공명 충전 쿨타임").is_empty(), "character-info lingpet stats should not show the removed resonance-charge cooldown")
	_expect(str(_find_stat(lingpet_stats, "방어율").get("value", "")) == "30%", "character-info lingpet stats should show the real defense rate")
	_expect(_find_stat(lingpet_stats, "대시 토큰").is_empty(), "character-info lingpet stats should not show unimplemented dash tokens")

	var overlay_gain: float = overlay._get_effective_gauge_gain_per_hit("smasher", null, [runtime])
	_expect(is_equal_approx(overlay_gain, 55.0), "character-info gauge-gain stat should read the Maribo bonus")

	var router := PaddleBounceEventRouter.new()
	var context := {
		"gauge_charge_per_hit": 50.0,
		"gauge_max": 500.0,
		"selected_character_type": "smasher",
	}
	var deps := {
		"lingpet_egg_runtime": runtime,
	}
	var gauge_after_hit: float = router.register_player_hit(Vector2(320.0, 690.0), 0.0, false, false, 100.0, context, deps)
	_expect(is_equal_approx(gauge_after_hit, 155.0), "player paddle hit should apply Maribo's gauge bonus")
	var gauge_after_drive: float = router.register_player_hit(Vector2(320.0, 690.0), 0.0, true, false, 100.0, context, deps)
	_expect(is_equal_approx(gauge_after_drive, 100.0), "Maribo should not bypass drive-hit gauge gain blocking")


func _verify_maribo_defense_rate_intercepts_descending_ball() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var start_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(Vector2(120.0, start_pos.y), 2, 0.0, false)
	owner.ball_active = true
	owner.ball_pos = Vector2(520.0, start_pos.y - 230.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.50, owner)
	_expect(bool(owner.lingpet_companion_defense_intercept_active), "Maribo defense rate should sometimes arm an intercept on a descending ball")
	_expect(owner.lingpet_companion_pos.x > 170.0, "armed Maribo defense intercept should move toward the predicted ball X")
	_expect(owner.lingpet_companion_defense_intercept_target_x > owner.lingpet_companion_pos.x, "defense target should stay ahead of the companion while chasing")

	owner.ball_active = false
	runtime.update(0.10, owner)
	_expect(not bool(owner.lingpet_companion_defense_intercept_active), "Maribo defense intercept should clear once the ball is no longer active")


func _verify_lunabi_free_flight_profile() -> void:
	var eligible_context := {
		"league_mode": "junior",
		"character_type": "smasher",
	}
	_expect(LingpetCatalog.has_pet("lunabi"), "catalog should recognize Lunabi for owned/runtime adoption")
	_expect(LingpetCatalog.get_hatch_candidates(eligible_context, []).has("lunabi"), "Lunabi should be eligible from the shared unidentified Junior League egg")
	_expect(str(LingpetCatalog.get_motion_style("lunabi")) == "free_flight", "Lunabi should use the free-flight companion motion style")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/lunabi_companion_flight.png"), "Lunabi companion free-flight sheet should exist")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/lunabi_companion_strike.png"), "Lunabi companion strike sheet should exist")
	_expect(str(LingpetCatalog.get_visual_path("lunabi", "companion_walk")).ends_with("lunabi_companion_flight.png"), "Lunabi runtime walk slot should resolve to the free-flight sheet")
	_expect(str(LingpetCatalog.get_visual_path("lunabi", "companion_strike")).ends_with("lunabi_companion_strike.png"), "Lunabi runtime strike slot should resolve to the ball-swoop sheet")

	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["lunabi"]
	owner.lingpet_slots = ["lunabi", "", ""]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	_expect(str(owner.active_lingpet_id) == "lunabi", "owned Lunabi should become the active companion through the slot model")
	_expect(str(owner.lingpet_skill_id) == "", "disabled Lunabi placeholder skill should not publish an owner skill-card id")
	_expect(not bool(owner.lingpet_skill_ready), "disabled Lunabi placeholder skill should not start ready")

	var start_pos: Vector2 = owner.lingpet_companion_pos
	var player_lane_y: float = owner.player_pos.y + owner.player_paddle_height * 0.5
	_expect(absf(start_pos.y - player_lane_y) > 20.0, "Lunabi should not start locked to the player-height patrol lane")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("companion_motion_style", "")) == "free_flight", "Lunabi snapshot should expose free-flight motion style")
	_expect(snapshot.get("companion_free_flight_target", Vector2.ZERO) is Vector2, "Lunabi snapshot should expose a free-flight target")
	_expect(is_equal_approx(float(snapshot.get("companion_defense_rate", -1.0)), 0.0), "Lunabi should not use Maribo's defensive intercept rate")
	_expect(str(snapshot.get("companion_skill_id", "")) == "", "disabled Lunabi placeholder skill should not publish a rail-card id")

	var saw_offscreen_target := false
	for _i in range(80):
		runtime.update(0.25, owner)
		snapshot = runtime.get_snapshot()
		var target: Vector2 = snapshot.get("companion_free_flight_target", Vector2.ZERO)
		if target.x < 0.0 or target.x > 760.0 or target.y < 0.0 or target.y > 750.0:
			saw_offscreen_target = true
			break
	_expect(saw_offscreen_target, "Lunabi free flight should sometimes target outside the screen")

	owner.ball_active = true
	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.01, owner)
	_expect(owner.ball_vel.y < 0.0, "Lunabi overlap should bounce the ball")
	_expect(int(owner.lingpet_companion_contact_count) == 1, "Lunabi overlap should register one companion contact")
	_expect(bool(runtime.is_companion_striking_for_tests()), "Lunabi should play the ball-swoop strike sheet on contact")


func _verify_ineligible_conditions_do_not_spawn() -> void:
	var champion_owner := FakeOwner.new()
	champion_owner.ai_mode = "champion"
	_expect(not LingpetEggRuntime.new().update(0.0, champion_owner), "Champion League should not spawn the first unidentified lingpet egg")

	var viper_owner := FakeOwner.new()
	viper_owner.selected_character_type = "viper"
	_expect(not LingpetEggRuntime.new().update(0.0, viper_owner), "Junior non-Mika character should not spawn the first unidentified lingpet egg")


func _find_stat(stats: Array, label: String) -> Dictionary:
	for value in stats:
		if value is Dictionary:
			var stat: Dictionary = value
			if str(stat.get("label", "")) == label:
				return stat
	return {}


func _issues_contain(issues: Array[String], needle: String) -> bool:
	for issue in issues:
		if issue.find(needle) >= 0:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _hit_companion(runtime: Object, owner: FakeOwner, registry: Object, companion_pos: Vector2) -> void:
	owner.ball_pos = companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.0, owner, registry)


func _write_lingpet_snapshot(path: String, snapshot: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("lingpet", "snapshot", snapshot.duplicate(true))
	var result: int = config.save(path)
	_expect(result == OK, "test helper should write a legacy lingpet snapshot")


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
