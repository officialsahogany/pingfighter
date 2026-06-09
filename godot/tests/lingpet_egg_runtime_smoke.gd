extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const BattleSceneLifecycle := preload("res://scripts/core/battle_scene_lifecycle.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetGhostBlinkVfx := preload("res://scripts/lingpet/lingpet_ghost_blink_vfx.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetCompanionSwitchState := preload("res://scripts/lingpet/lingpet_companion_switch_state.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSaveStore := preload("res://scripts/lingpet/lingpet_save_store.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const HydroPuddleTextureCache := preload("res://scripts/effects/hydro_puddle_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var lingpet_puppet_grab_active := false
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
	var lingpet_active_skill_id := ""
	var ringpet_active_skill_id := ""
	var lingpet_active_skill_level := 0
	var ringpet_active_skill_level := 0
	var lingpet_active_skill_max_level := 0
	var ringpet_active_skill_max_level := 0
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
	var lingpet_skill_icon_path := ""
	var ringpet_skill_icon_path := ""
	var lingpet_passive_skill_id := ""
	var ringpet_passive_skill_id := ""
	var lingpet_passive_skill_level := 0
	var ringpet_passive_skill_level := 0
	var lingpet_passive_skill_max_level := 0
	var ringpet_passive_skill_max_level := 0
	var lingpet_passive_skill_name := ""
	var ringpet_passive_skill_name := ""
	var lingpet_passive_skill_description := ""
	var ringpet_passive_skill_description := ""
	var lingpet_passive_skill_icon_path := ""
	var ringpet_passive_skill_icon_path := ""
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_player_speed_bonus_pct := 0.0
	var ringpet_player_speed_bonus_pct := 0.0
	var lingpet_starpoint_tracking_chance_pct := 0.0
	var ringpet_starpoint_tracking_chance_pct := 0.0
	var lingpet_ring_dash_chance_pct := 0.0
	var ringpet_ring_dash_chance_pct := 0.0
	var lingpet_ring_dash_force_roll_pct := -1.0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_loadouts: Dictionary = {}
	var ringpet_loadouts: Dictionary = {}
	var owned_lingpet_loadouts: Dictionary = {}
	var owned_ringpet_loadouts: Dictionary = {}
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
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
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
	var lingpet_active_skill_id := ""
	var ringpet_active_skill_id := ""
	var lingpet_active_skill_level := 0
	var ringpet_active_skill_level := 0
	var lingpet_active_skill_max_level := 0
	var ringpet_active_skill_max_level := 0
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
	var lingpet_skill_icon_path := ""
	var ringpet_skill_icon_path := ""
	var lingpet_passive_skill_id := ""
	var ringpet_passive_skill_id := ""
	var lingpet_passive_skill_level := 0
	var ringpet_passive_skill_level := 0
	var lingpet_passive_skill_max_level := 0
	var ringpet_passive_skill_max_level := 0
	var lingpet_passive_skill_name := ""
	var ringpet_passive_skill_name := ""
	var lingpet_passive_skill_description := ""
	var ringpet_passive_skill_description := ""
	var lingpet_passive_skill_icon_path := ""
	var ringpet_passive_skill_icon_path := ""
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_player_speed_bonus_pct := 0.0
	var ringpet_player_speed_bonus_pct := 0.0
	var lingpet_starpoint_tracking_chance_pct := 0.0
	var ringpet_starpoint_tracking_chance_pct := 0.0
	var lingpet_ring_dash_chance_pct := 0.0
	var ringpet_ring_dash_chance_pct := 0.0
	var lingpet_ring_dash_force_roll_pct := -1.0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_loadouts: Dictionary = {}
	var ringpet_loadouts: Dictionary = {}
	var owned_lingpet_loadouts: Dictionary = {}
	var owned_ringpet_loadouts: Dictionary = {}
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
	var boomerang_hits := 0
	var hydro_count := 0
	var lingpet_acquire_count := 0
	var lingpet_acquire_click_backing_count := 0
	var lingpet_click_reaction_pet_ids: Array = []
	var puppet_grab_cast_count := 0
	var puppet_grab_pull_count := 0
	var puppet_grab_kiss_count := 0
	var puppet_grab_miss_count := 0

	func play_paddle_hit() -> void:
		paddle_hits += 1

	func play_boomerang_hit() -> void:
		boomerang_hits += 1

	func play_stage2_hydro() -> void:
		hydro_count += 1

	func play_lingpet_acquire_cutin() -> void:
		lingpet_acquire_count += 1

	func play_lingpet_acquire_click_reaction_backing() -> void:
		lingpet_acquire_click_backing_count += 1

	func play_lingpet_click_reaction(pet_id: String) -> void:
		lingpet_click_reaction_pet_ids.append(pet_id)

	func play_lingpet_puppet_grab_cast() -> void:
		puppet_grab_cast_count += 1

	func play_lingpet_puppet_grab_pull() -> void:
		puppet_grab_pull_count += 1

	func play_lingpet_puppet_grab_kiss() -> void:
		puppet_grab_kiss_count += 1

	func play_lingpet_puppet_grab_miss() -> void:
		puppet_grab_miss_count += 1


class FakeBossAiState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace := false

	func start_paddle_hit_knockback(velocity: float, frames: float = 36.0, decay_per_frame: float = 0.85, replace_current: bool = true) -> void:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay_per_frame
		last_replace = replace_current


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


class FakeCutinHost:
	extends RefCounted

	var prewarm_calls: Array[String] = []
	var done_after := 2
	var anim_ready := true

	func prewarm_pet_assets_step(pet_id: String) -> bool:
		prewarm_calls.append(pet_id)
		return prewarm_calls.size() >= done_after

	func is_pet_cutin_anim_ready(_pet_id: String) -> bool:
		return anim_ready


func _init() -> void:
	_verify_registry_and_frame_wiring()
	_verify_lingpet_catalog_random_hatch_scaffold()
	_verify_junior_mika_spawn_syncs_character_info_keys()
	_verify_egg_player_contact_nudges_and_wobbles()
	_verify_player_serve_ball_does_not_hatch_egg()
	_verify_egg_hit_uses_player_paddle_reflection()
	_verify_one_ball_hit_hatches_unidentified_egg()
	_verify_acquire_cutin_triggers_on_hatch()
	_verify_acquire_cutin_assets_prewarm_during_egg_phase()
	_verify_acquire_cutin_reveal_holds_until_anim_sheet_ready()
	_verify_owned_maribo_is_kept_as_companion()
	_verify_lingpet_battle_slot_model()
	_verify_companion_visual_and_pillar_card()
	_verify_companion_patrol_ignores_viper_airborne_y()
	_verify_companion_initial_facing_uses_patrol_dir()
	_verify_companion_patrol_edge_pause_and_speed_change()
	_verify_companion_ball_collision_soft_bounce()
	_verify_companion_strike_anticipates_contact()
	_verify_companion_paddle_bounce_and_sound()
	_verify_companion_hit_gauge_passive()
	_verify_afterglow_leak_passive()
	_verify_tailwind_steps_passive()
	_verify_starlight_tracking_passive()
	_verify_ring_dash_passive()
	_verify_ring_dash_single_roll_per_descent()
	_verify_companion_paddle_hit_width()
	_verify_companion_guards_dalji_whip()
	_verify_companion_skill_card_hydro_sphere()
	_verify_lingpet_skill_cooldown_survives_slot_switch()
	_verify_lingpet_skill_waits_for_switch_transition()
	_verify_hydro_puddle_vfx()
	_verify_save_snapshot_roundtrip()
	_verify_save_store_persists_and_restores_maribo()
	_verify_battle_lifecycle_restores_lingpet_save()
	_verify_maribo_companion_gauge_bonus()
	_verify_maribo_defense_rate_intercepts_descending_ball()
	_verify_maribo_defense_actually_blocks_reachable_ball()
	_verify_maribo_defense_anticipates_moderate_distance_ball()
	_verify_rabi_ghost_blink_cycle()
	_verify_ghost_blink_vfx()
	_verify_lunabi_free_flight_profile()
	_verify_lunabi_headbutt_skill()
	_verify_koyora_puppet_grab_skill()
	_verify_companion_click_reaction()
	_verify_ineligible_conditions_do_not_spawn()

	ProjectResourceLoader.clear_caches()
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
	var character_info_source: String = _character_info_overlay_source()
	var character_info_frame_source: String = FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_frame_presenter.gd")
	var pillar_hud_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
	var pillar_ui_source: String = FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	_expect(callback_source.find("update_lingpet") >= 0, "battle callbacks should expose lingpet update")
	_expect(callback_source.find("save_runtime(owner, registry)") >= 0, "battle callbacks should persist lingpet runtime changes")
	_expect(flow_source.find("update_lingpet") >= 0, "battle flow should update lingpet after ball/serve flow")
	_expect(drawer_source.find("lingpet_egg_runtime") >= 0, "playfield drawer should render visible lingpet runtime")
	_expect(lifecycle_source.find("_restore_lingpet_save(owner, registry)") >= 0, "battle lifecycle should restore saved lingpet data after bootstrap")
	_expect(deps_source.find("\"lingpet_egg_runtime\"") >= 0, "ball dependencies should expose the lingpet runtime")
	_expect(hit_router_source.find("get_gauge_gain_per_hit") >= 0, "player hit gauge routing should read lingpet gauge bonuses")
	_expect(character_info_source.find("var _frame_stat_sources: Array = []") >= 0 and character_info_frame_source.find("stat_sources.append(lingpet_runtime)") >= 0, "character info stats should include lingpet stat sources")
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
	_expect(runtime_source.find("LINGPET_EGG_TEXTURE") < 0, "field egg rendering should not hard-preload the shared egg PNGs")
	_expect(runtime_source.find("\"egg_crack_1\"") >= 0, "field egg rendering should still keep the first cracked catalog visual key for multi-hit profiles")
	_expect(runtime_source.find("\"egg_crack_2\"") >= 0, "field egg rendering should still keep the stronger cracked catalog visual key")
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
	_expect(runtime_source.find("lingpet_afterglow_leak_state.gd") >= 0, "egg runtime should delegate the Afterglow Leak residue passive to a focused state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_afterglow_leak_state.gd"), "Afterglow Leak passive state module should exist")
	_expect(runtime_source.find("lingpet_starlight_tracking_state.gd") >= 0, "egg runtime should delegate the Starlight Tracking auto-collection passive to a focused state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_starlight_tracking_state.gd"), "Starlight Tracking passive state module should exist")
	_expect(FileAccess.file_exists("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd"), "starpoint stages should share a lingpet Starlight Tracking bridge")
	_expect(runtime_source.find("lingpet_ring_dash_state.gd") >= 0, "egg runtime should delegate the Ring Dash emergency guard passive to a focused state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_ring_dash_state.gd"), "Ring Dash passive state module should exist")
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
	_expect(cutin_host_source.find("func _draw_portal_quad") >= 0 and cutin_host_source.find("draw_colored_polygon") >= 0, "cut-in host should rotate the painted resonance portal with textured quads")
	_expect(cutin_host_source.find("_draw_resonance_bg") < cutin_host_source.find("func _draw_portal_quad"), "cut-in host should keep the portal-quad helper near the resonance background draw path")
	_expect(runtime_source.find("is_acquire_cutin_active") >= 0, "lingpet runtime should expose the acquisition cut-in active flag")
	_expect(runtime_source.find("lingpet_acquire_cutin_state.gd") >= 0, "lingpet runtime should delegate cut-in timing state to the acquire-cutin state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_acquire_cutin_state.gd"), "lingpet acquire cut-in state module should exist")
	_expect(runtime_source.find("get_acquire_cutin_progress") >= 0, "lingpet runtime should expose the acquisition cut-in progress")
	_expect(runtime_source.find("advance_acquire_cutin") >= 0, "lingpet runtime should advance the cut-in from the ungated idle pump")
	_expect(runtime_source.find("is_acquire_cutin_awaiting_dismiss") >= 0, "lingpet runtime should expose the post-reveal dismissable state")
	_expect(runtime_source.find("dismiss_acquire_cutin") >= 0, "lingpet runtime should support hard dismissal of the cut-in")
	_expect(runtime_source.find("begin_acquire_cutin_dismiss") >= 0, "lingpet runtime should start the click-triggered exit action")
	_expect(runtime_source.find("_get_current_acquire_cutin_dismiss_seconds") >= 0 and runtime_source.find("cutin_dismiss_seconds") >= 0, "lingpet runtime should allow pet-specific acquisition click-dismiss duration tuning")
	_expect(runtime_source.find("is_acquire_cutin_dismissing") >= 0, "lingpet runtime should expose the exit-action (dismissing) state")
	_expect(runtime_source.find("get_acquire_cutin_dismiss_progress") >= 0, "lingpet runtime should expose the exit-action progress for the host")
	var acquire_cutin_state_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
	_expect(
		acquire_cutin_state_source.find("dismiss_seconds") >= 0
		and acquire_cutin_state_source.find("begin_dismiss(duration_seconds") >= 0,
		"lingpet acquire cut-in state should time the exit action with the pet-specific dismiss duration"
	)
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
	_expect(input_source.find("begin_acquire_cutin_dismiss(registry)") >= 0, "overlay input controller should pass the registry so acquisition-click voice can play")
	var modal_gate: Object = GameplayModuleRegistry.new().get_instance("battle_scene_modal_gate_controller")
	_expect(modal_gate != null and modal_gate.has_method("is_lingpet_acquire_cutin_active"), "modal gate controller should implement the cut-in gate method")
	var host: Object = GameplayModuleRegistry.new().get_instance("lingpet_acquire_cutin_overlay_host")
	_expect(host != null and host.has_method("draw"), "lingpet acquisition cut-in host should be registered and drawable")
	var cutin_host_dynamic_source: String = FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	_expect(cutin_host_dynamic_source.find("LingpetCatalog.get_visual_path") >= 0, "lingpet acquisition cut-in host should resolve art through the hatched pet catalog entry")
	_expect(cutin_host_dynamic_source.find("_get_runtime_pet_id") >= 0, "lingpet acquisition cut-in host should read the hatched pet id from runtime instead of staying Maribo-only")
	_expect(cutin_host_dynamic_source.find("CUTIN_ANIM_FRAMES_OVERRIDES") >= 0 and cutin_host_dynamic_source.find("\"red_dragon\": 32") >= 0, "Red Dragon acquisition cut-in should use its 32-frame per-pet playback override")
	_expect(cutin_host_dynamic_source.find("CUTIN_ANIM_FPS_OVERRIDES") >= 0 and cutin_host_dynamic_source.find("\"red_dragon\": 16.0") >= 0, "Red Dragon acquisition cut-in should keep a 2-second loop with 32 frames at 16fps")
	_expect(cutin_host_dynamic_source.find("cutin_anim_view_h_ratio") >= 0 and cutin_host_dynamic_source.find("cutin_dismiss_view_h_ratio") >= 0, "Red Dragon acquisition cut-in should support per-pet visual-size matching through catalog layout ratios")
	_expect(
		cutin_host_dynamic_source.find("cutin_dismiss_action_portion") >= 0
		and cutin_host_dynamic_source.find("cutin_dismiss_fade_start") >= 0,
		"acquisition click-dismiss host should support per-pet action/fade pacing for longer 98-frame Live2D sheets"
	)
	_expect(host.has_method("prewarm_assets_step"), "lingpet acquisition cut-in host should expose staged prewarm for hatch-time cut-in assets")
	_expect(cutin_host_dynamic_source.find("prewarm_texture_threaded_step") >= 0, "cut-in host should thread-prewarm catalog cut-in PNGs instead of sync-loading them on the draw frame")
	_expect(host.has_method("prewarm_pet_assets_step"), "lingpet acquisition cut-in host should expose per-pet texture prewarm instead of warming every pet during boot")
	_expect(cutin_host_dynamic_source.find("Boot warmup must stay lightweight") >= 0, "boot prewarm should avoid decoding every lingpet cut-in texture at Stage 1 loading")
	var boot_prewarm_body := _function_body(cutin_host_dynamic_source, "func prewarm_assets_step")
	var pet_prewarm_body := _function_body(cutin_host_dynamic_source, "func prewarm_pet_assets_step")
	var sync_assets_body := _function_body(cutin_host_dynamic_source, "func _sync_assets_for_pet")
	var refresh_assets_body := _function_body(cutin_host_dynamic_source, "func _refresh_deferred_cutin_sheets")
	var load_catalog_texture_body := _function_body(cutin_host_dynamic_source, "func _load_catalog_texture")
	_expect(boot_prewarm_body.find("prewarm_texture_threaded_step") < 0, "boot cut-in prewarm should not request large per-pet PNG sheets")
	_expect(pet_prewarm_body.find("prewarm_texture_threaded_step") >= 0, "per-pet cut-in prewarm should keep the threaded texture path for hatch-time assets")
	_expect(pet_prewarm_body.find("FileAccess.file_exists(path)") < 0, "per-pet cut-in prewarm should not reject imported textures in exported builds")
	_expect(sync_assets_body.find("_cutin_art = _get_cached_cutin_texture") >= 0, "cut-in host should not sync-load static art on the first draw frame")
	_expect(sync_assets_body.find("_cutin_art = _load_catalog_texture") < 0, "cut-in host should keep static art out of the synchronous draw setup path")
	_expect(refresh_assets_body.find("_cutin_art == null") >= 0 and refresh_assets_body.find("_get_cached_cutin_texture(pet_id, \"cutin_art\")") >= 0, "cut-in host should pick up static art from cache once threaded prewarm finishes")
	_expect(load_catalog_texture_body.find("FileAccess.file_exists(path)") < 0, "cut-in texture loading should not require raw PNG files in exported builds")
	_expect(load_catalog_texture_body.find("ProjectResourceLoader.load_imported_texture(path") >= 0, "cut-in texture loading should use the imported (size_limit'd) texture via ProjectResourceLoader, not the raw 8192px source decode that froze the first draw")
	_expect(cutin_host_dynamic_source.find("_load_catalog_texture(pet_id, \"cutin_dismiss_anim\")") >= 0, "click-dismiss should import-load the dismiss sheet if threaded prewarm has not finished before the user clicks")
	_expect(cutin_host_dynamic_source.find("preload(\"res://assets/sprites/lingpet/maribo_cutin_anim.png\")") < 0, "cut-in host should not hard-preload the 8192px Maribo cut-in sheet during module instantiation")
	_expect(cutin_host_dynamic_source.find("preload(\"res://assets/sprites/lingpet/maribo_cutin_dismiss_anim.png\")") < 0, "cut-in host should not hard-preload the dismiss sheet during module instantiation")
	_expect(cutin_host_dynamic_source.find("_recon_mask_cache") >= 0, "cut-in host should cache reconstruction masks instead of reparsing JSON on pet switches")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lingpet_acquire_ominous_shadow_shimmer_02.wav"), "lingpet acquisition cut-in should ship its cinematic one-shot SFX in the lingpet sound asset folder")
	var acquire_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lingpet_acquire_ominous_shadow_shimmer_02.wav")
	_expect(acquire_stream != null and acquire_stream.get_length() > 2.0, "lingpet acquisition cut-in SFX should load as a playable Godot AudioStream")
	var game_audio_source: String = FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(game_audio_source.find("LINGPET_ACQUIRE_CUTIN_SOUND_PATH") >= 0, "GameAudio should register the lingpet acquisition cut-in sound path")
	_expect(game_audio_source.find("LINGPET_ACQUIRE_CUTIN_GAIN_DB := 0.0") >= 0, "GameAudio should play the cinematic lingpet acquisition sound at full SFX gain")
	_expect(game_audio_source.find("LingpetAcquireCutinSfx") >= 0, "GameAudio should create a dedicated player for the lingpet acquisition cut-in sound")
	_expect(game_audio_source.find("_ensure_lingpet_acquire_cutin_sfx") >= 0, "GameAudio should lazily recover the lingpet acquisition SFX player if setup did not create it")
	_expect(game_audio_source.find("play_lingpet_acquire_cutin") >= 0, "GameAudio should expose a lingpet acquisition cut-in play method")
	_expect(runtime_source.find("play_lingpet_acquire_cutin") >= 0, "lingpet runtime should request the acquisition cut-in sound when the screen starts")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lingpet_acquire_click_deep_bass_doom.wav"), "lingpet acquisition click Live2D should ship the deep bass doom backing SFX in the lingpet sound asset folder")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lingpet_acquire_click_magic_crackle_sweep.wav"), "lingpet acquisition click Live2D should ship the magic crackle sweep backing SFX in the lingpet sound asset folder")
	var acquire_click_bass_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lingpet_acquire_click_deep_bass_doom.wav")
	var acquire_click_sweep_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lingpet_acquire_click_magic_crackle_sweep.wav")
	_expect(acquire_click_bass_stream != null and acquire_click_bass_stream.get_length() > 2.0, "lingpet acquisition click deep bass SFX should load as a playable Godot AudioStream")
	_expect(acquire_click_sweep_stream != null and acquire_click_sweep_stream.get_length() > 2.0, "lingpet acquisition click crackle sweep SFX should load as a playable Godot AudioStream")
	_expect(game_audio_source.find("LINGPET_ACQUIRE_CLICK_DEEP_BASS_SOUND_PATH") >= 0, "GameAudio should register the lingpet acquisition click deep bass sound path")
	_expect(game_audio_source.find("LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_SOUND_PATH") >= 0, "GameAudio should register the lingpet acquisition click crackle sweep sound path")
	_expect(game_audio_source.find("LingpetAcquireClickDeepBassSfx") >= 0, "GameAudio should create a dedicated player for the acquisition click deep bass backing")
	_expect(game_audio_source.find("LingpetAcquireClickCrackleSweepSfx") >= 0, "GameAudio should create a dedicated player for the acquisition click crackle sweep backing")
	_expect(game_audio_source.find("play_lingpet_acquire_click_reaction_backing") >= 0, "GameAudio should expose a dedicated acquisition-click backing play method")
	_expect(runtime_source.find("play_lingpet_acquire_click_reaction_backing") >= 0, "lingpet runtime should request the backing SFX only when the acquisition click Live2D starts")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lunabi_click_reaction_voice_v1.mp3"), "Lunabi should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var lunabi_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lunabi_click_reaction_voice_v1.mp3")
	_expect(lunabi_click_voice_stream != null and lunabi_click_voice_stream.get_length() > 0.1, "Lunabi click-reaction voice should load as a playable Godot AudioStream")
	_expect(game_audio_source.find("LINGPET_LUNABI_CLICK_VOICE_SOUND_PATH") >= 0, "GameAudio should register the Lunabi click-reaction voice sound path")
	_expect(game_audio_source.find("LingpetLunabiClickVoiceSfx") >= 0, "GameAudio should create a dedicated player for the Lunabi click-reaction voice")
	_expect(game_audio_source.find("_ensure_lingpet_lunabi_click_voice_sfx") >= 0, "GameAudio should lazily recover the Lunabi click-reaction voice player if setup did not create it")
	_expect(game_audio_source.find("normalized_pet_id == \"lunabi\"") >= 0, "GameAudio click-reaction dispatch should route the lunabi pet id to its dedicated voice")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/volty_click_reaction_voice_v1.mp3"), "Volty should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var volty_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/volty_click_reaction_voice_v1.mp3")
	_expect(volty_click_voice_stream != null and volty_click_voice_stream.get_length() > 0.1, "Volty click-reaction voice should load as a playable Godot AudioStream")
	_expect(game_audio_source.find("LINGPET_VOLTY_CLICK_VOICE_SOUND_PATH") >= 0, "GameAudio should register the Volty click-reaction voice sound path")
	_expect(game_audio_source.find("LingpetVoltyClickVoiceSfx") >= 0, "GameAudio should create a dedicated player for the Volty click-reaction voice")
	_expect(game_audio_source.find("_ensure_lingpet_volty_click_voice_sfx") >= 0, "GameAudio should lazily recover the Volty click-reaction voice player if setup did not create it")
	_expect(game_audio_source.find("func play_lingpet_click_reaction") >= 0, "GameAudio should expose a pet-agnostic click-reaction play method")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/milkring_click_reaction_voice_v1.mp3"), "Milkring should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var milkring_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/milkring_click_reaction_voice_v1.mp3")
	_expect(milkring_click_voice_stream != null and milkring_click_voice_stream.get_length() > 0.1, "Milkring click-reaction voice should load as a playable Godot AudioStream")
	_expect(game_audio_source.find("LINGPET_MILKRING_CLICK_VOICE_SOUND_PATH") >= 0, "GameAudio should register the Milkring click-reaction voice sound path")
	_expect(game_audio_source.find("LingpetMilkringClickVoiceSfx") >= 0, "GameAudio should create a dedicated player for the Milkring click-reaction voice")
	_expect(game_audio_source.find("_ensure_lingpet_milkring_click_voice_sfx") >= 0, "GameAudio should lazily recover the Milkring click-reaction voice player if setup did not create it")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/red_dragon_click_reaction_voice_v1.mp3"), "Red Dragon (Farukiras) should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var red_dragon_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/red_dragon_click_reaction_voice_v1.mp3")
	_expect(red_dragon_click_voice_stream != null and red_dragon_click_voice_stream.get_length() > 0.1, "Red Dragon click-reaction voice should load as a playable Godot AudioStream")
	_expect(game_audio_source.find("LINGPET_RED_DRAGON_CLICK_VOICE_SOUND_PATH") >= 0, "GameAudio should register the Red Dragon click-reaction voice sound path")
	_expect(game_audio_source.find("LingpetRedDragonClickVoiceSfx") >= 0, "GameAudio should create a dedicated player for the Red Dragon click-reaction voice")
	_expect(game_audio_source.find("_ensure_lingpet_red_dragon_click_voice_sfx") >= 0, "GameAudio should lazily recover the Red Dragon click-reaction voice player if setup did not create it")
	_expect(game_audio_source.find("normalized_pet_id == \"red_dragon\"") >= 0, "GameAudio click-reaction dispatch should route the red_dragon pet id to its dedicated voice")


func _verify_lingpet_catalog_random_hatch_scaffold() -> void:
	var eligible_context := {
		"league_mode": "junior",
		"character_type": "smasher",
	}
	var expected_candidate_ids: Array[String] = LingpetCatalog.get_pet_ids()
	var candidates: Array[String] = LingpetCatalog.get_hatch_candidates(eligible_context, [])
	for expected_pet_id in expected_candidate_ids:
		_expect(candidates.has(expected_pet_id), "catalog should expose %s as an unidentified Junior Smasher egg hatch candidate" % expected_pet_id)
	var hatch_rng := RandomNumberGenerator.new()
	hatch_rng.seed = 7
	_expect(candidates.has(str(LingpetCatalog.pick_hatch_pet_id(eligible_context, [], hatch_rng))), "weighted hatch pick should resolve to one of the current unidentified egg candidates")
	var after_maribo_owned_live: Array[String] = LingpetCatalog.get_hatch_candidates(eligible_context, ["maribo"])
	for expected_pet_id in expected_candidate_ids:
		if expected_pet_id == "maribo":
			_expect(not after_maribo_owned_live.has(expected_pet_id), "owned Maribo should be removed from unidentified egg candidates")
		else:
			_expect(after_maribo_owned_live.has(expected_pet_id), "owned Maribo should not hide %s as another unidentified egg candidate" % expected_pet_id)
	var after_maribo_lunabi_owned_live: Array[String] = LingpetCatalog.get_hatch_candidates(eligible_context, ["maribo", "lunabi"])
	var expected_after_maribo_lunabi := expected_candidate_ids.duplicate()
	expected_after_maribo_lunabi.erase("maribo")
	expected_after_maribo_lunabi.erase("lunabi")
	for expected_pet_id in expected_after_maribo_lunabi:
		_expect(after_maribo_lunabi_owned_live.has(expected_pet_id), "%s should stay eligible until it is also owned" % expected_pet_id)
	_expect(after_maribo_lunabi_owned_live.size() == expected_after_maribo_lunabi.size(), "only unowned shipped lingpets should remain eligible after Maribo and Lunabi are owned")
	_expect(LingpetCatalog.get_hatch_candidates(eligible_context, expected_candidate_ids).is_empty(), "random hatch candidates should empty only after all current lingpets are owned")
	_expect(LingpetCatalog.get_hatch_candidates({"league_mode": "champion", "character_type": "smasher"}, []).is_empty(), "catalog should keep Junior League eligibility gating")
	var live_catalog_issues: Array[String] = LingpetCatalog.validate_catalog(true)
	_expect(live_catalog_issues.is_empty(), "live lingpet catalog should validate cleanly: %s" % str(live_catalog_issues))
	var all_catalog_pet_ids: Array[String] = LingpetCatalog.get_pet_ids(true)
	var enabled_catalog_pet_ids: Array[String] = LingpetCatalog.get_pet_ids()
	_expect(all_catalog_pet_ids.has("draft_bat"), "catalog should keep the draft Bat lingpet metadata")
	_expect(not enabled_catalog_pet_ids.has("draft_bat"), "draft Bat should stay out of enabled pet ids until hatch-pool approval")
	_expect(not candidates.has("draft_bat"), "draft Bat should stay out of the random hatch pool until hatch-pool approval")
	_expect(not LingpetCatalog.is_pet_enabled("draft_bat"), "draft Bat should remain a parked draft pet")
	_expect(all_catalog_pet_ids.has("milkring"), "catalog should keep the Milkring lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("milkring"), "Milkring should appear in enabled pet ids after companion/cut-in/click assets ship")
	_expect(candidates.has("milkring"), "Milkring should enter the random hatch pool after live catalog integration")
	_expect(LingpetCatalog.is_pet_enabled("milkring"), "Milkring should be treated as a live pet")
	_expect(all_catalog_pet_ids.has("volty"), "catalog should keep the Volty lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("volty"), "Volty should appear in enabled pet ids after companion/cut-in/click assets ship")
	_expect(candidates.has("volty"), "Volty should enter the random hatch pool after live catalog integration")
	_expect(LingpetCatalog.is_pet_enabled("volty"), "Volty should be treated as a live pet")
	_expect(all_catalog_pet_ids.has("orbi"), "catalog should keep the Orbi lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("orbi"), "Orbi should appear in enabled pet ids after companion/cut-in/click assets ship")
	_expect(candidates.has("orbi"), "Orbi should enter the random hatch pool after live catalog integration")
	_expect(LingpetCatalog.is_pet_enabled("orbi"), "Orbi should be treated as a live pet")
	var draft_bat_entry: Dictionary = LingpetCatalog.get_entry("draft_bat")
	var draft_bat_concept_path := str(draft_bat_entry.get("concept_art_path", ""))
	var draft_bat_chromakey_path := str(draft_bat_entry.get("concept_chromakey_path", ""))
	var draft_bat_magenta_path := str(draft_bat_entry.get("concept_magenta_source_path", ""))
	_expect(FileAccess.file_exists(draft_bat_concept_path), "draft Bat concept art should stay parked under the lingpet asset tree")
	_expect(FileAccess.file_exists(draft_bat_chromakey_path), "draft Bat chromakey source should stay parked under the lingpet asset tree")
	_expect(FileAccess.file_exists(draft_bat_magenta_path), "draft Bat magenta source should stay parked under the lingpet asset tree")
	for live_pet_id in LingpetCatalog.get_pet_ids():
		var live_skill: Dictionary = LingpetCatalog.get_active_skill(live_pet_id)
		var live_skill_id := str(live_skill.get("id", "")).strip_edges()
		var live_skill_enabled := bool(live_skill.get("enabled", true))
		var live_runtime_kind := str(live_skill.get("runtime_kind", "")).strip_edges().to_lower()
		var live_active_pool: Array[Dictionary] = LingpetCatalog.get_active_skill_pool(live_pet_id)
		_expect(not live_active_pool.is_empty(), "%s should expose an active-skill pool for loadout selection" % live_pet_id)
		if live_skill_enabled:
			_expect(live_skill_id != "", "%s enabled active skill should publish a skill id" % live_pet_id)
			_expect(live_runtime_kind != "" and live_runtime_kind != "none", "%s enabled active skill should publish a concrete runtime kind" % live_pet_id)
			_expect(LingpetSkillDispatcher.is_supported_kind(live_runtime_kind), "%s enabled active skill runtime kind should be wired into the dispatcher" % live_pet_id)
			_expect(LingpetSkillDispatcher.has_supported_runtime(live_skill_id), "%s enabled active skill id should resolve to a supported runtime" % live_pet_id)
		else:
			_expect(not LingpetSkillDispatcher.has_supported_runtime(live_skill_id), "%s disabled placeholder skill should not resolve to a live runtime" % live_pet_id)
	var maribo_skill := LingpetCatalog.get_active_skill("maribo")
	_expect(is_equal_approx(float(maribo_skill.get("windup_seconds", 0.0)), 1.0), "Maribo Hydro Sphere wind-up timing should live in the active-skill catalog entry")
	var maribo_active_pool: Array[Dictionary] = LingpetCatalog.get_active_skill_pool("maribo")
	var maribo_active_ids: Array[String] = _skill_ids(maribo_active_pool)
	_expect(maribo_active_ids.has("maribo_hydro_sphere") and maribo_active_ids.has("maribo_bubble_trap"), "Maribo should expose Hydro Sphere plus Bubble Trap in its active-skill pool")
	var maribo_passive_pool: Array[Dictionary] = LingpetCatalog.get_passive_skill_pool("maribo")
	var maribo_passive_ids: Array[String] = _skill_ids(maribo_passive_pool)
	_expect(maribo_passive_pool.size() == 5 and maribo_passive_ids.has("lingpet_resonance_boost") and maribo_passive_ids.has("lingpet_afterglow_leak") and maribo_passive_ids.has("lingpet_tailwind_steps") and maribo_passive_ids.has("lingpet_starlight_tracking") and maribo_passive_ids.has("lingpet_ring_dash"), "Maribo should expose the five approved shared passives")
	var maribo_loadout: Dictionary = LingpetCatalog.build_default_loadout("maribo")
	_expect(str(maribo_loadout.get("active_skill_id", "")) == "maribo_hydro_sphere", "default Maribo loadout should keep Hydro Sphere for legacy owned Maribo")
	_expect(str(maribo_loadout.get("passive_skill_id", "")) == "lingpet_resonance_boost", "default Maribo loadout should keep Resonance Boost for legacy owned Maribo")
	_expect(LingpetCatalog.normalize_passive_skill_id("maribo", "maribo_resonance_boost") == "lingpet_resonance_boost", "legacy Maribo passive ids should normalize to Resonance Boost")
	var draft_entries := {
		"maribo": LingpetCatalog.get_entry("maribo"),
		"draft_bat": {
			"id": "draft_bat",
			"display_name": "드래프트 배트",
			"enabled": false,
			"hatch_weight": 1.0,
			"required_hits": 1,
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
			"required_hits": 1,
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
			"required_hits": 1,
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
	_expect(LingpetCatalog.get_required_hits("maribo") == 1, "catalog should own Maribo hatch-hit requirements")
	_expect(LingpetCatalog.get_display_name("maribo") == "마리보", "catalog should own lingpet display names")
	_expect(LingpetCatalog.get_display_name("lunabi") == "달벳", "catalog should expose Dalbet as the visible name for the lunabi runtime id")
	_expect(LingpetCatalog.get_display_name("milkring") == "밀쿠", "catalog should expose Milku as the visible name for the milkring runtime id")
	_expect(LingpetCatalog.get_display_name("volty") == "볼탄", "catalog should expose Voltan as the visible name for the volty runtime id")
	_expect(LingpetCatalog.get_display_name("rabi") == "모락모랑", "catalog should expose Morakmorang as the visible name for the rabi runtime id")
	_expect(str(LingpetCatalog.get_visual_path("maribo", "egg")).ends_with("maribo_egg_v002.png"), "catalog should own the current shared unidentified egg visual path")
	_expect(str(LingpetCatalog.get_visual_path("lunabi", "egg")).ends_with("maribo_egg_v002.png"), "Lunabi should hatch from the same shared unidentified egg visual path")
	_expect(str(LingpetCatalog.get_visual_path("maribo", "companion_walk")).ends_with("maribo_companion_walk.png"), "catalog should own Maribo companion visual paths")
	_expect(str(LingpetCatalog.get_visual_path("milkring", "companion_walk")).ends_with("milkring_companion_walk.png"), "catalog should own Milkring's true leg-walk companion visual path")
	_expect(str(LingpetCatalog.get_visual_path("milkring", "companion_strike")).ends_with("milkring_companion_strike.png"), "catalog should own Milkring companion strike visual path")
	_expect(str(LingpetCatalog.get_visual_path("milkring", "companion_cast")).ends_with("milkring_milk_production_autosprite_25f.png"), "catalog should route Milkring's cast visual to the milk-production AutoSprite sheet")
	var milkring_walk_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/milkring_companion_walk.png")
	_expect(milkring_walk_texture != null and milkring_walk_texture.get_width() == 1280 and milkring_walk_texture.get_height() == 1280, "Milkring companion walk sheet should load as a 5x5 256-cell AutoSprite sheet")
	var milkring_walk_manifest_source: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/milkring_companion_walk_manifest.json")
	_expect(milkring_walk_manifest_source.find("high_step_true_leg_walk") >= 0 and milkring_walk_manifest_source.find("milkring_companion_idle_back.png") >= 0, "Milkring walk manifest should record the accepted high-step leg-walk replacement for the old idle/back sheet")
	_expect(milkring_walk_manifest_source.find("frame_order_fix") >= 0 and milkring_walk_manifest_source.find("backpedal_fix") >= 0, "Milkring walk manifest should record the frame-order reversal that fixes backwards-walking playback")
	_expect(milkring_walk_manifest_source.find("horizontal_orientation_fix") >= 0 and milkring_walk_manifest_source.find("flip_entire_5x5_runtime_sheet_left_to_right") >= 0, "Milkring walk manifest should record the horizontal orientation fix for the rightward-source walk contract")
	var milkring_production_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/milkring_milk_production_autosprite_25f.png")
	_expect(milkring_production_texture != null and milkring_production_texture.get_width() == 2560 and milkring_production_texture.get_height() == 2560, "Milkring milk-production sheet should load as a 5x5 512-cell AutoSprite sheet")
	var milkring_click_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/milkring_click_live2d_pingpong_98f.png")
	_expect(milkring_click_texture != null and milkring_click_texture.get_width() == 16128 and milkring_click_texture.get_height() == 8064, "Milkring click Live2D texture should match Maribo's 14x7 1152-cell sheet size")
	var milkring_click_manifest_source: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/milkring_click_live2d_pingpong_98f_manifest.json")
	_expect(milkring_click_manifest_source.find("maribo_size_match_cell_size") >= 0 and milkring_click_manifest_source.find("realesrgan_upscale") >= 0, "Milkring click Live2D manifest should record the Maribo-size repack plus Real-ESRGAN upscale")
	_expect(str(LingpetCatalog.get_visual_path("milkring", "cutin_dismiss_anim")).ends_with("milkring_cutin_dismiss_anim.png"), "catalog should route Milkring's click-dismiss cut-in to the dedicated 5x5 sheet")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/milkring_cutin_dismiss_anim.png"), "Milkring cut-in should ship a dedicated click-dismiss action sheet")
	var milkring_dismiss_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/milkring_cutin_dismiss_anim.png")
	_expect(milkring_dismiss_texture != null and milkring_dismiss_texture.get_width() == 5120 and milkring_dismiss_texture.get_height() == 5120, "Milkring click-dismiss texture should load as a 5x5 1024-cell sheet")
	var milkring_dismiss_manifest_source: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/milkring_cutin_dismiss_anim_manifest.json")
	_expect(milkring_dismiss_manifest_source.find("\"cols\": 5") >= 0 and milkring_dismiss_manifest_source.find("\"frame_count\": 25") >= 0, "Milkring click-dismiss manifest should pin the 5x5/25 runtime grid")
	var milkring_cutin_manifest_source: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/milkring_cutin_anim_manifest.json")
	_expect(milkring_cutin_manifest_source.find("reconstruction_frame0") >= 0 and milkring_cutin_manifest_source.find("milkring_cutin_dismiss_anim.png") >= 0, "Milkring cut-in manifest should keep the reconstruction mask and dismiss-sheet contract")
	_expect(milkring_cutin_manifest_source.find("\"cell_fill_h_pct\": 61.951") >= 0 and milkring_cutin_manifest_source.find("slightly larger than the click/dismiss") >= 0, "Milkring acquisition Live2D should stay slightly larger than its click Live2D after size matching")
	_expect(str(LingpetCatalog.get_visual_path("volty", "companion_walk")).ends_with("volty_companion_walk.png"), "catalog should own Volty companion walk visual path")
	_expect(str(LingpetCatalog.get_visual_path("volty", "companion_strike")).ends_with("volty_companion_strike.png"), "catalog should own Volty companion strike visual path")
	_expect(str(LingpetCatalog.get_visual_path("volty", "cutin_dismiss_anim")).ends_with("volty_cutin_dismiss_anim.png"), "catalog should route Volty's click-dismiss cut-in to the dedicated 5x5 sheet")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/volty_cutin_dismiss_anim.png"), "Volty cut-in should ship a dedicated click-dismiss action sheet")
	var volty_dismiss_manifest_source: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/volty_cutin_dismiss_anim_manifest.json")
	_expect(volty_dismiss_manifest_source.find("\"cols\": 5") >= 0 and volty_dismiss_manifest_source.find("\"frame_count\": 25") >= 0, "Volty click-dismiss manifest should pin the 5x5/25 runtime grid")
	_expect(str(LingpetCatalog.get_visual_path("orbi", "companion_walk")).ends_with("orbi_companion_walk.png"), "catalog should own Orbi companion walk visual path")
	_expect(str(LingpetCatalog.get_visual_path("orbi", "companion_strike")).ends_with("orbi_companion_strike.png"), "catalog should own Orbi companion strike visual path")
	_expect(is_equal_approx(LingpetCatalog.get_visual_layout_value("maribo", "companion_walk_draw_size", 0.0), 104.0), "catalog should upscale Maribo's refreshed walk sheet to match strike/cast scale")
	_expect(is_equal_approx(LingpetCatalog.get_visual_layout_value("draft_bat", "companion_walk_draw_size", 82.0), 82.0), "catalog walk-size override should be per-pet, not a global companion scale")
	_expect(str(LingpetCatalog.get_active_skill_entry("maribo_hydro_sphere").get("runtime_kind", "")) == "hydro_sphere", "catalog should expose Maribo active-skill runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("maribo_bubble_trap").get("runtime_kind", "")) == "bubble_trap", "catalog should expose Maribo Bubble Trap runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("lunabi_headbutt").get("runtime_kind", "")) == "headbutt", "catalog should expose Lunabi headbutt runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("milkring_milk_production").get("runtime_kind", "")) == "milk_production", "catalog should expose Milkring's milk-production runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("lumion_thunder_orb").get("runtime_kind", "")) == "thunder_orb", "catalog should expose Lumion's Thunder Orb runtime kind by skill id")
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("lumion", "cutin_anim_view_h_ratio", 0.0), 0.68)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("lumion", "cutin_dismiss_view_h_ratio", 0.0), 0.68)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("lumion", "click_reaction_draw_size", 0.0), 83.2),
		"Lumion acquisition and click Live2D visuals should apply the requested 20 percent smaller layout"
	)
	_expect(str(LingpetCatalog.get_active_skill_entry("volty_bomb_surprise").get("runtime_kind", "")) == "bomb_surprise", "catalog should expose Volty's Bomb Surprise runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("volty_gatling_burst").get("runtime_kind", "")) == "gatling_burst", "catalog should expose Volty's Gatling Burst runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("red_dragon_dragon_breath").get("runtime_kind", "")) == "dragon_breath", "catalog should expose Red Dragon's Dragon Breath runtime kind by skill id")
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill_entry("red_dragon_dragon_breath").get("cooldown", 0.0)), 40.0), "Red Dragon Dragon Breath should use the requested 40-second cooldown")
	_expect(str(LingpetCatalog.get_active_skill_entry("orbi_ring_orbit").get("runtime_kind", "")) == "moon_orbit", "catalog should expose Orbi's temporary ring-orbit runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_runtime_kind_from_entries(multi_entries, "test_bubble_guard")) == "bubble_guard", "catalog should resolve future lingpet skill runtime kinds from active_skill metadata")
	_expect(str(LingpetCatalog.get_passive_skill("maribo", "maribo_resonance_boost").get("id", "")) == "lingpet_resonance_boost", "catalog should resolve legacy passive-skill ids to Resonance Boost metadata")
	_expect(str(LingpetCatalog.get_passive_skill("maribo", "maribo_resonance_boost").get("name", "")) == "공명 증폭", "catalog should resolve selected passive-skill metadata by id")
	_expect(LingpetSkillDispatcher.is_hydro_sphere("maribo_hydro_sphere"), "skill dispatcher should recognize the current Maribo active skill")
	_expect(LingpetSkillDispatcher.is_milk_production("milkring_milk_production"), "skill dispatcher should route Milkring's milk-production skill through the milk-production runtime")
	_expect(LingpetSkillDispatcher.is_bubble_trap("maribo_bubble_trap"), "skill dispatcher should recognize Maribo Bubble Trap")
	_expect(LingpetSkillDispatcher.is_thunder_orb("lumion_thunder_orb"), "skill dispatcher should recognize Lumion Thunder Orb")
	_expect(LingpetSkillDispatcher.is_headbutt("lunabi_headbutt"), "skill dispatcher should recognize the current Lunabi active skill")
	_expect(LingpetSkillDispatcher.is_bomb_surprise("volty_bomb_surprise"), "skill dispatcher should route Volty's Bomb Surprise skill through the bomb_surprise runtime")
	_expect(LingpetSkillDispatcher.is_gatling_burst("volty_gatling_burst"), "skill dispatcher should route Volty's Gatling Burst skill through the gatling_burst runtime")
	_expect(LingpetSkillDispatcher.is_dragon_breath("red_dragon_dragon_breath"), "skill dispatcher should route Red Dragon's Dragon Breath skill through the dragon_breath runtime")
	_expect(LingpetSkillDispatcher.is_moon_orbit("orbi_ring_orbit"), "skill dispatcher should route Orbi's temporary ring-orbit skill through the moon-orbit runtime")
	_expect(LingpetSkillDispatcher.is_supported_kind("hydro_sphere"), "skill dispatcher should expose supported runtime kinds for future lingpet skill modules")
	_expect(LingpetSkillDispatcher.is_supported_kind("headbutt"), "skill dispatcher should expose the Lunabi headbutt runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("milk_production"), "skill dispatcher should expose Milkring's milk-production runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("thunder_orb"), "skill dispatcher should expose Lumion's Thunder Orb runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("bomb_surprise"), "skill dispatcher should expose Volty's Bomb Surprise runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("gatling_burst"), "skill dispatcher should expose Volty's Gatling Burst runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("dragon_breath"), "skill dispatcher should expose Red Dragon's Dragon Breath runtime kind")
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
	_expect(current_profile_source.find("_active_skill_cache_key") >= 0, "current-profile helper should cache resolved active-skill metadata for the companion hot path")
	_expect(current_profile_source.find("_passive_effect_cache") >= 0, "current-profile helper should cache passive effect lookups instead of reapplying level dictionaries per frame")
	_expect(runtime_source.find("_applied_loadout_key") >= 0, "egg runtime should not deep-normalize the active lingpet loadout every companion update")
	var current_profile := LingpetCurrentProfile.new()
	_expect(str(current_profile.set_pet_id("unknown_pet")) == "maribo", "current-profile helper should fall back to the default pet for unknown ids")
	_expect(is_equal_approx(current_profile.get_visual_layout_value("companion_walk_draw_size", 0.0), 104.0), "current-profile helper should expose current pet visual-layout overrides")
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
	_expect(skill_runtime_host_source.find("lingpet_bubble_trap_skill.gd") >= 0, "skill runtime host should own the Maribo Bubble Trap module")
	_expect(skill_runtime_host_source.find("lingpet_thunder_orb_skill.gd") >= 0, "skill runtime host should own Lumion's Thunder Orb module")
	_expect(skill_runtime_host_source.find("lingpet_bomb_surprise_skill.gd") >= 0, "skill runtime host should own Volty's Bomb Surprise module")
	_expect(skill_runtime_host_source.find("lingpet_gatling_burst_skill.gd") >= 0, "skill runtime host should own Volty's Gatling Burst module")
	_expect(skill_runtime_host_source.find("lingpet_headbutt_skill.gd") >= 0, "skill runtime host should own the Lunabi Headbutt module")
	_expect(skill_runtime_host_source.find("preload(\"res://scripts/lingpet/lingpet_hydro_sphere_skill.gd\")") < 0, "skill runtime host should not hard-preload every lingpet skill during boot")
	_expect(skill_runtime_host_source.find("var _hydro_sphere_skill: Object = null") >= 0, "skill runtime host should keep concrete skill modules lazy until the active skill needs them")
	_expect(skill_runtime_host_source.find("_new_skill(") >= 0 and skill_runtime_host_source.find("load(path)") >= 0, "skill runtime host should dynamically load concrete skill modules on demand")
	_expect(skill_runtime_host_source.find("get_companion_position_override") >= 0, "skill runtime host should let body-driven skills override the real companion position")
	_expect(runtime_source.find("_apply_companion_skill_position_override") >= 0, "egg runtime should apply body-driven skill positions to the real companion")
	_expect(dispatcher_source.find("LingpetCatalog.get_active_skill_runtime_kind") >= 0, "skill dispatcher should resolve active-skill runtime kind through the catalog before falling back to legacy ids")
	_expect(runtime_source.find("lingpet_companion_skill_state.gd") >= 0, "egg runtime should delegate shared active-skill cooldown/wind-up state to the companion skill-state controller")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_skill_state.gd"), "companion skill-state controller should exist for future lingpet active skills")
	_expect(current_profile_source.find("lingpet_visual_texture_cache.gd") >= 0, "current-profile helper should delegate catalog visual texture loading to the visual cache module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_visual_texture_cache.gd"), "lingpet visual texture cache module should exist")
	var visual_cache_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
	_expect(visual_cache_source.find("LingpetCatalog.get_visual_path") >= 0, "visual cache should query catalog visual paths instead of hardcoding only Maribo paths")
	_expect(
		visual_cache_source.find("ProjectResourceLoader.load_texture") >= 0
			or visual_cache_source.find("ProjectResourceLoader.load_imported_texture") >= 0,
		"visual cache should route texture loads through the shared project resource loader"
	)


func _verify_companion_walk_sheet_wiring(runtime_source: String) -> void:
	# The hatched companion now renders from the AutoSprite back-view walk sheet
	# (idle is derived from the same sheet). Seal the asset + grid spec so a
	# future PNG swap or grid change cannot silently desync the frame math.
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_companion_walk.png"), "Maribo companion should use a PNG-backed back-view walk sheet")
	_expect(runtime_source.find("MARIBO_COMPANION_WALK_SHEET") < 0, "companion rendering should no longer hard-preload a Maribo walk fallback")
	var draw_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	_expect(draw_context_source.find("companion_walk") >= 0, "companion draw context should resolve walk visuals through the current lingpet catalog profile")
	_expect(
		draw_context_source.find("companion_idle") >= 0
		and draw_context_source.find("companion_move_left") >= 0
		and draw_context_source.find("companion_move_right") >= 0,
		"companion draw context should resolve optional dedicated rear idle / left / right SD sheets through the catalog profile"
	)
	_expect(runtime_source.find("\"walk_fallback\"") < 0, "runtime draw config should not pass a Maribo walk fallback after catalog-profile wiring")
	_expect(draw_context_source.find("walk_fallback") < 0, "companion draw context should not accept a legacy walk fallback parameter")
	_expect(runtime_source.find("lingpet_companion_renderer.gd") >= 0, "egg runtime should delegate companion sprite drawing to the companion renderer")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_renderer.gd"), "companion renderer module should exist")
	var companion_renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	_expect(companion_renderer_source.find("draw_texture_rect_region") >= 0, "companion renderer should blit walk-sheet cells, not draw a procedural body")
	_expect(draw_context_source.find("companion_walk_draw_size") >= 0, "companion draw context should pass per-pet walk draw-size overrides")
	_expect(draw_context_source.find("companion_wing_flap_max_speed_ratio") >= 0, "companion draw context should support per-pet wing-flap cadence caps")
	_expect(companion_renderer_source.find("draw_size_override") >= 0, "companion renderer should pass draw-size overrides into the sprite animator")
	_expect(companion_renderer_source.find("_draw_burst") >= 0, "companion renderer should own hit/gauge/skill flash burst drawing")
	var red_dragon_profile := LingpetCurrentProfile.new()
	red_dragon_profile.set_pet_id("red_dragon")
	var red_dragon_draw_config: Dictionary = LingpetCompanionDrawContextBuilder.new().build_config({
		"current_profile": red_dragon_profile,
		"motion_speed_ratio": 1.0,
	})
	_expect(is_equal_approx(float(red_dragon_draw_config.get("motion_speed_ratio", -1.0)), 0.55), "Red Dragon draw context should clamp high-speed wing-flap cadence")
	var lunabi_profile := LingpetCurrentProfile.new()
	lunabi_profile.set_pet_id("lunabi")
	var lunabi_draw_config: Dictionary = LingpetCompanionDrawContextBuilder.new().build_config({
		"current_profile": lunabi_profile,
		"motion_speed_ratio": 1.0,
	})
	_expect(is_equal_approx(float(lunabi_draw_config.get("motion_speed_ratio", -1.0)), 1.0), "Uncapped sortie-flight companions should keep their full speed-ratio cadence")
	_expect(runtime_source.find("lingpet_companion_sprite_animator.gd") >= 0, "egg runtime should delegate companion frame/source-rect math to the sprite animator")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_sprite_animator.gd"), "companion sprite animator module should exist")
	var sprite_animator_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
	_expect(sprite_animator_source.find("get_walk_frame") >= 0, "companion sprite animator should resolve walk/idle frames")
	_expect(sprite_animator_source.find("get_source_rect") >= 0, "companion sprite animator should resolve sheet source rects")
	_expect(sprite_animator_source.find("_resolve_draw_size") >= 0, "companion sprite animator should honor per-pet draw-size overrides")
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
		var animator := LingpetCompanionSpriteAnimator.new()
		var draw_rects: Dictionary = animator.build_draw_rects(
			sheet,
			LingpetCompanionSpriteAnimator.MODE_WALK,
			Vector2(320.0, 440.0),
			0.0,
			0.0,
			0.0,
			0.0,
			Vector2(104.0, 104.0)
		)
		var dest_rect: Rect2 = draw_rects.get("dest", Rect2())
		_expect(is_equal_approx(dest_rect.size.x, 104.0) and is_equal_approx(dest_rect.size.y, 104.0), "Maribo walk draw-size override should render the refreshed walk sheet at strike/cast scale")
	# Directional facing: dedicated rear-view idle / left / right sheets take
	# precedence when present. Older pets still use the AutoSprite iso_walk_northeast
	# 3/4-back sheet facing rightward and mirror the UVs for leftward travel. The
	# facing must be latched from ACTUAL horizontal travel (dx) during normal
	# movement: patrol_dir toggles during pauses / reverse-and-pause decisions,
	# which snapped held sheet sides while standing still. First spawn/restore is
	# the exception because zero-to-spawn placement is not travel; seed that frame
	# from patrol_dir. Seal the travel -> face_left -> dedicated-or-flip chain so
	# neither the latch nor the mirror fallback silently regresses.
	_expect(runtime_source.find("_companion_facing_left") >= 0, "egg runtime should latch companion facing to actual horizontal travel, not raw patrol_dir")
	_expect(runtime_source.find("_set_companion_facing_from_patrol_dir") >= 0, "egg runtime should seed companion facing from patrol_dir on first spawn/restore")
	_expect(runtime_source.find("\"face_left\"") >= 0, "egg runtime should feed the latched facing into the draw config")
	_expect(draw_context_source.find("face_left") >= 0, "companion draw context should pass the face_left flag through to the renderer")
	_expect(companion_renderer_source.find("face_left") >= 0, "companion renderer should use the latched facing to select a dedicated left sheet or flip the fallback walk sheet")
	_expect(
		companion_renderer_source.find("idle_texture") >= 0
		and companion_renderer_source.find("move_left_texture") >= 0
		and companion_renderer_source.find("move_right_texture") >= 0
		and companion_renderer_source.find("should_flip_sprite") >= 0,
		"companion renderer should prefer dedicated idle/left/right sheets and keep the legacy walk-sheet flip fallback"
	)
	_expect(companion_renderer_source.find("_draw_flipped_texture_region") >= 0, "companion renderer should mirror via UV-swapped polygon drawing")
	_expect(companion_renderer_source.find("-dest_rect.size.x") < 0, "companion renderer should not use negative-width destination rects for left-facing sheets")
	# Ball-hit strike sheet (same 5x5/25 grid) played on companion ball contact.
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_companion_strike.png"), "Maribo companion should have a back-view ball-hit strike sheet")
	_expect(runtime_source.find("MARIBO_COMPANION_STRIKE_SHEET") < 0, "companion rendering should no longer hard-preload a Maribo strike fallback")
	_expect(draw_context_source.find("companion_strike") >= 0, "companion draw context should resolve strike visuals through the current lingpet catalog profile")
	_expect(runtime_source.find("\"strike_fallback\"") < 0, "runtime draw config should not pass a Maribo strike fallback after catalog-profile wiring")
	_expect(draw_context_source.find("strike_fallback") < 0, "companion draw context should not accept a legacy strike fallback parameter")
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
	_expect(runtime_source.find("MARIBO_COMPANION_HYDRO_CAST_SHEET") < 0, "companion rendering should no longer hard-preload a Maribo cast fallback")
	_expect(draw_context_source.find("companion_cast") >= 0, "companion draw context should resolve cast visuals through the current lingpet catalog profile")
	_expect(runtime_source.find("\"cast_fallback\"") < 0, "runtime draw config should not pass a Maribo cast fallback after catalog-profile wiring")
	_expect(draw_context_source.find("cast_fallback") < 0, "companion draw context should not accept a legacy cast fallback parameter")
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
	_expect(int(owner.lingpet_hatch_required_hits) == 1, "egg should require one hit to hatch")
	_expect(owner.lingpet_egg_pos is Vector2, "egg should publish a playfield position")
	var expected_floor_y := 750.0 - 28.0 - 18.0
	_expect(absf(owner.lingpet_egg_pos.y - expected_floor_y) <= 1.0, "egg should start as a floor-placed brick-like object")

	var panel: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(panel.get("state", "")) == "egg", "character-info ringpet panel should read the shared egg state")
	_expect(str(panel.get("subtitle", "")).find("0 / 1") >= 0, "character-info panel should show hatch progress")
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
	_expect(int(owner.lingpet_hatch_hits) == 1, "non-player-serve ball hits should still count as a hatch hit")
	_expect(str(owner.lingpet_state) == "companion", "non-player-serve ball hit should hatch the Ringpet egg")


func _verify_egg_hit_uses_player_paddle_reflection() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_pos = egg_pos + Vector2(30.0, -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner)
	_expect(int(owner.lingpet_hatch_hits) == 1, "egg paddle-reflection hit should count the hatch hit")
	_expect(str(owner.lingpet_state) == "companion", "egg paddle-reflection hit should hatch the Ringpet egg")
	_expect(owner.ball_vel.y < 0.0, "egg hit should reflect the ball toward the opponent side")
	_expect(owner.ball_vel.x > 0.0, "right-side egg contact should angle the reflected ball to the right like a paddle hit")
	_expect(owner.ball_pos.y < egg_pos.y, "egg hit should separate the ball above the egg after reflection")


func _verify_one_ball_hit_hatches_unidentified_egg() -> void:
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
	_expect(int(owner.lingpet_hatch_hits) == 1, "first counted hit should fill the hatch counter")
	_expect(str(owner.lingpet_state) == "companion", "first counted hit should hatch the unidentified egg into companion state")
	_expect(owner.ball_vel.y < 0.0, "egg hit should reflect a downward ball toward the opponent side")

	var hatched_id := str(owner.active_lingpet_id)
	_expect(hatch_candidates.has(hatched_id), "hatched lingpet should be one of the current unidentified egg candidates")
	_expect(owner.lingpet_owned_pet_ids.has(hatched_id), "hatched lingpet should be added to the owned pet id list")
	_expect((owner.lingpet_slots as Array).size() == 3 and str((owner.lingpet_slots as Array)[0]) == hatched_id, "hatched lingpet should auto-fill the first lingpet battle slot")
	_expect(int(owner.lingpet_active_slot_index) == 0, "hatched lingpet should use slot 0 as the active battle slot")
	_expect(bool(owner.lingpet_collection.get(hatched_id, false)), "hatched lingpet should be marked in the lingpet collection")
	_expect(owner.lingpet_loadouts is Dictionary and (owner.lingpet_loadouts as Dictionary).has(hatched_id), "hatched lingpet should receive a persisted active/passive loadout")
	var hatched_loadout: Dictionary = (owner.lingpet_loadouts as Dictionary).get(hatched_id, {}) as Dictionary
	var selected_active_id := str(hatched_loadout.get("active_skill_id", ""))
	var selected_passive_id := str(hatched_loadout.get("passive_skill_id", ""))
	_expect(_skill_ids(LingpetCatalog.get_active_skill_pool(hatched_id)).has(selected_active_id), "hatched lingpet loadout should store one active skill from its active-skill pool")
	var passive_pool_ids := _skill_ids(LingpetCatalog.get_passive_skill_pool(hatched_id))
	if passive_pool_ids.is_empty():
		_expect(selected_passive_id == "", "hatched lingpet with no passive-skill pool should store an empty passive skill id")
	else:
		_expect(passive_pool_ids.has(selected_passive_id), "hatched lingpet loadout should store one passive skill from its passive-skill pool")
	_expect(str(owner.lingpet_active_skill_id) == selected_active_id, "owner should publish the active skill selected by the lingpet loadout")
	_expect(str(owner.lingpet_passive_skill_id) == selected_passive_id, "owner should publish the passive skill selected by the lingpet loadout")
	var selected_passive: Dictionary = LingpetCatalog.get_passive_skill(hatched_id, selected_passive_id)
	var expected_bonus_pct: float = float(selected_passive.get("gauge_gain_bonus_pct", 0.0))
	var expected_gain: float = floor(50.0 * (1.0 + expected_bonus_pct / 100.0))
	_expect(is_equal_approx(float(runtime.get_gauge_gain_per_hit(50.0)), expected_gain), "hatched lingpet should expose its catalog gauge-gain bonus")
	_expect(runtime.has_visible_effects(), "hatched lingpet should keep visible companion effects after hatching")
	_expect(owner.lingpet_companion_pos is Vector2 and owner.lingpet_companion_pos != Vector2.ZERO, "hatched lingpet should publish companion position")
	var runtime_snapshot: Dictionary = runtime.get_snapshot()
	_expect(float(runtime_snapshot.get("hatch_flash_timer", 0.0)) > 0.0, "hatched lingpet should keep the egg-break animation active briefly")
	_expect(str(runtime_snapshot.get("active_skill_id", "")) == selected_active_id, "runtime snapshot should expose the selected active skill id")
	_expect(str(runtime_snapshot.get("passive_skill_id", "")) == selected_passive_id, "runtime snapshot should expose the selected passive skill id")
	_expect(int(runtime_snapshot.get("active_skill_level", 0)) == 1, "runtime snapshot should expose the selected active skill level")
	_expect(int(runtime_snapshot.get("passive_skill_level", 0)) == 1, "runtime snapshot should expose the selected passive skill level")
	var panel: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(panel.get("title", "")) == LingpetCatalog.get_display_name(hatched_id), "character-info panel should reveal the hatched lingpet after hatching")
	_expect(str(panel.get("subtitle", "")) == "동행 중", "character-info panel should show companion status after hatching")


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2, index: int, registry: Object = null) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)


func _verify_acquire_cutin_triggers_on_hatch() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	var audio := FakePaddleAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	_register_hit(runtime, owner, egg_pos, 1, registry)
	_expect(str(owner.lingpet_state) == "companion", "first counted hit should hatch the unidentified egg before the cut-in check")
	_expect(bool(runtime.is_acquire_cutin_active()), "hatching should trigger the fullscreen acquisition cut-in")
	_expect(audio.lingpet_acquire_count == 1, "hatching should play the lingpet acquisition cut-in sound once")
	_expect(audio.lingpet_acquire_click_backing_count == 0, "hatching should not play the acquisition click backing SFX before the player clicks the Live2D")
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
	var hatched_pet_id := str(owner.active_lingpet_id)
	_expect(hatched_pet_id != "", "hatching should publish the active lingpet id before the cut-in dismissal click")
	_expect(bool(runtime.begin_acquire_cutin_dismiss(registry)), "click should start the exit action")
	_expect(audio.lingpet_acquire_click_backing_count == 1, "clicking the acquisition Live2D exit action should play the backing SFX once")
	_expect(audio.lingpet_click_reaction_pet_ids == [hatched_pet_id], "clicking the acquisition Live2D exit action should request the hatched pet voice once")
	_expect(bool(runtime.is_acquire_cutin_dismissing()), "exit action should be playing after the click")
	_expect(bool(runtime.is_acquire_cutin_active()), "cut-in should stay active (gameplay paused) during the exit action")
	_expect(not bool(runtime.is_acquire_cutin_awaiting_dismiss()), "a second click must not re-trigger the exit action once it is playing")
	_expect(not bool(runtime.begin_acquire_cutin_dismiss(registry)), "begin_acquire_cutin_dismiss should be a no-op once already dismissing")
	_expect(audio.lingpet_acquire_click_backing_count == 1, "re-clicking during the acquisition Live2D exit action should not replay backing SFX")
	_expect(audio.lingpet_click_reaction_pet_ids == [hatched_pet_id], "re-clicking during the acquisition Live2D exit action should not replay voice")
	_expect(float(runtime.get_acquire_cutin_dismiss_progress()) >= 0.0, "exit action should expose a dismiss progress for the host")
	# Advancing through the exit action + fade auto-closes the cut-in and resumes play.
	runtime.advance_acquire_cutin(2.0)
	_expect(not bool(runtime.is_acquire_cutin_active()), "exit action completing should resume battle physics on its own")
	_expect(not bool(runtime.is_acquire_cutin_dismissing()), "dismissing state should clear once the exit action finishes")
	_expect(not bool(runtime.begin_acquire_cutin_dismiss(registry)), "starting the exit action on an inactive cut-in should be a no-op")

	for voiced_pet_id in ["volty", "milkring"]:
		var voiced_owner := FakeOwner.new()
		var voiced_runtime: Object = LingpetEggRuntime.new()
		var voiced_audio := FakePaddleAudio.new()
		var voiced_registry := FakeRegistry.new({"game_audio": voiced_audio})
		_expect(voiced_runtime.debug_grant_and_activate_pet(voiced_pet_id, voiced_owner, true, "", "", voiced_registry), "direct debug grant should start acquisition cut-in for voiced pets")
		voiced_runtime.advance_acquire_cutin(2.0)
		_expect(bool(voiced_runtime.begin_acquire_cutin_dismiss(voiced_registry)), "voiced pet acquisition cut-in click should start the exit action")
		_expect(voiced_audio.lingpet_acquire_click_backing_count == 1, "voiced pet acquisition Live2D click should play the backing SFX once")
		_expect(voiced_audio.lingpet_click_reaction_pet_ids == [voiced_pet_id], "voiced pet acquisition Live2D click should request the pet-specific voice")

	var rabi_owner := FakeOwner.new()
	var rabi_runtime: Object = LingpetEggRuntime.new()
	var rabi_audio := FakePaddleAudio.new()
	var rabi_registry := FakeRegistry.new({"game_audio": rabi_audio})
	_expect(
		rabi_runtime.debug_grant_and_activate_pet("rabi", rabi_owner, true, "rabi_ghost_summon", "", rabi_registry),
		"direct debug grant should start acquisition cut-in for Rabi"
	)
	rabi_runtime.advance_acquire_cutin(2.0)
	_expect(bool(rabi_runtime.begin_acquire_cutin_dismiss(rabi_registry)), "Rabi acquisition cut-in click should start the 98-frame Live2D exit action")
	rabi_runtime.advance_acquire_cutin(2.0)
	_expect(bool(rabi_runtime.is_acquire_cutin_active()), "Rabi 98-frame click Live2D should still be visible after the old 1.6s default dismiss window")
	_expect(float(rabi_runtime.get_acquire_cutin_dismiss_progress()) < 1.0, "Rabi 98-frame click Live2D should progress more slowly than the old compressed dismiss timing")
	rabi_runtime.advance_acquire_cutin(2.0)
	_expect(not bool(rabi_runtime.is_acquire_cutin_active()), "Rabi 98-frame click Live2D should close after its longer pet-specific dismiss window")

	# Re-adopting an already-owned Maribo (no hatch event) must NOT replay the
	# acquisition cut-in.
	var owned_owner := FakeOwner.new()
	owned_owner.lingpet_owned_pet_ids = ["maribo"]
	var owned_runtime: Object = LingpetEggRuntime.new()
	owned_runtime.update(0.0, owned_owner)
	_expect(str(owned_owner.lingpet_state) == "companion", "owned Maribo should adopt directly as companion")
	_expect(not bool(owned_runtime.is_acquire_cutin_active()), "adopting an already-owned Maribo should not replay the acquisition cut-in")


func _verify_acquire_cutin_assets_prewarm_during_egg_phase() -> void:
	# The acquire cut-in reveal is only LingpetAcquireCutinState.REVEAL_SECONDS long,
	# so a cold draw-time stream of the heavy 8192px+ Live2D sheets cannot always
	# finish before the reveal ends -- the cut-in then falls back to the static 원화
	# still. The STATE_EGG update must drive the overlay host's incremental prewarm
	# during the calm egg-wait frames so the sheets are cached by hatch time.
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	_expect(str(owner.lingpet_state) == "egg", "fresh junior-league owner should spawn a hatch egg before hatching")
	var egg_pet_id := str(runtime.get("_pet_id"))
	_expect(egg_pet_id != "", "egg phase should resolve a pending hatch pet id to prewarm the cut-in for")

	var host := FakeCutinHost.new()
	host.done_after = 2
	var registry := FakeRegistry.new({"lingpet_acquire_cutin_overlay_host": host})

	# Keep the ball away from the egg so it never hatches; we only exercise the
	# STATE_EGG pre-stream window across multiple frames.
	owner.ball_active = false
	for _i in range(5):
		runtime.update(0.016, owner, registry)

	_expect(str(owner.lingpet_state) == "egg", "egg should stay unhatched while the ball never reaches it")
	_expect(host.prewarm_calls.size() == 2, "egg-phase update should drive the cut-in host prewarm until it reports done, then stop re-driving it")
	for raw_called_pet_id in host.prewarm_calls:
		_expect(str(raw_called_pet_id) == egg_pet_id, "egg-phase cut-in prewarm should target the pending hatch pet id")


func _verify_acquire_cutin_reveal_holds_until_anim_sheet_ready() -> void:
	# Regression: on the F7 grant and 1-hit egg paths the reveal can open before the heavy
	# Live2D acquisition sheet finishes streaming. It must NOT lock solid on the static 원화
	# fallback for a few seconds -- it holds in the reconstruction phase until the sheet is
	# cached, then completes on the animation.
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var host := FakeCutinHost.new()
	host.anim_ready = false
	var registry := FakeRegistry.new({"lingpet_acquire_cutin_overlay_host": host})
	_expect(
		runtime.debug_grant_and_activate_pet("maribo", owner, true, "", "", registry),
		"debug grant should start the acquisition cut-in for the gate test"
	)
	# Sheet still streaming: the reveal must hold below the lock-solid progress and stay
	# non-dismissable (no locked 원화), and it must keep pumping the host's stream.
	runtime.advance_acquire_cutin(2.0, registry)
	_expect(bool(runtime.is_acquire_cutin_active()), "cut-in should stay active while held for the streaming sheet")
	_expect(
		not bool(runtime.is_acquire_cutin_awaiting_dismiss()),
		"reveal must hold in reconstruction until the anim sheet is cached (must not lock solid on the static 원화)"
	)
	_expect(
		float(runtime.get_acquire_cutin_progress()) <= LingpetAcquireCutinState.REVEAL_ASSET_GATE_FRACTION + 0.001
			and float(runtime.get_acquire_cutin_progress()) > 0.0,
		"held reveal progress should clamp at the asset gate fraction, below the lock-solid frame"
	)
	_expect(host.prewarm_calls.size() > 0, "advance should keep streaming the cut-in sheet while the reveal is gated")
	# Sheet cached: the gate releases and the reveal completes on the animation.
	host.anim_ready = true
	runtime.advance_acquire_cutin(2.0, registry)
	_expect(bool(runtime.is_acquire_cutin_awaiting_dismiss()), "reveal should complete once the anim sheet is ready")
	_expect(is_equal_approx(float(runtime.get_acquire_cutin_progress()), 1.0), "released reveal should reach full progress")

	# Failsafe: a sheet that never caches must not soft-lock the modal forever -- after the
	# max hold the reveal completes on the static art (the old pre-fix behavior).
	var stuck_owner := FakeOwner.new()
	var stuck_runtime: Object = LingpetEggRuntime.new()
	var stuck_host := FakeCutinHost.new()
	stuck_host.anim_ready = false
	var stuck_registry := FakeRegistry.new({"lingpet_acquire_cutin_overlay_host": stuck_host})
	_expect(
		stuck_runtime.debug_grant_and_activate_pet("maribo", stuck_owner, true, "", "", stuck_registry),
		"debug grant should start the acquisition cut-in for the failsafe test"
	)
	for _i in range(10):
		stuck_runtime.advance_acquire_cutin(1.0, stuck_registry)
	_expect(
		bool(stuck_runtime.is_acquire_cutin_awaiting_dismiss()),
		"a never-cached sheet must not hang the reveal -- the failsafe should release it after the max hold"
	)


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
	_expect(renderer_source.find("_draw_switch_label") >= 0, "companion renderer should draw a short active-lingpet name label during switch transition")
	var draw_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	_expect(draw_context_source.find("\"display_name\"") >= 0 and draw_context_source.find("get_display_name") >= 0, "companion draw context should pass the active lingpet display name to the switch label")


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
	_expect(float(runtime.get_companion_draw_motion_speed_ratio_for_tests()) > 0.0, "Maribo walk animation cadence should be driven by real patrol movement")
	_expect(absf(moved_pos.x - (owner.player_pos.x + owner.player_paddle_width * 0.5)) > 20.0, "Maribo companion should not snap to the paddle center after player movement")
	var snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(snapshot.get("companion_pos", Vector2.ZERO) is Vector2, "save snapshot should keep companion visual position")
	_expect(float(snapshot.get("companion_patrol_dir", 0.0)) != 0.0, "save snapshot should keep Maribo patrol direction")
	_expect(float(snapshot.get("companion_patrol_speed", 0.0)) >= 70.0 and float(snapshot.get("companion_patrol_speed", 0.0)) <= 135.0, "save snapshot should keep Maribo's current patrol speed")


func _verify_companion_patrol_ignores_viper_airborne_y() -> void:
	var owner := FakeOwner.new()
	owner.selected_character_type = "viper"
	owner.player_pos = Vector2(302.5, 700.0)
	owner.player_paddle_width = 155.0
	owner.player_paddle_height = 50.0
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var grounded_y: float = owner.lingpet_companion_pos.y
	owner.player_pos.y = 560.0
	runtime.update(0.16, owner)
	var airborne_follow_y: float = owner.player_pos.y + owner.player_paddle_height * 0.5
	_expect(absf(owner.lingpet_companion_pos.y - grounded_y) <= 0.01, "Viper jetpack Y should not pull the Maribo patrol lane into the air")
	_expect(absf(owner.lingpet_companion_pos.y - airborne_follow_y) > 80.0, "Maribo patrol should use the ground lane, not Viper's airborne player_pos.y")


func _verify_companion_initial_facing_uses_patrol_dir() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["draft_bat"]
	owner.owned_lingpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.owned_ringpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.apply_save_snapshot({
		"pet_id": "draft_bat",
		"state": "companion",
		"owned_pet_ids": ["draft_bat"],
		"companion_pos": Vector2.ZERO,
		"companion_patrol_dir": -1.0,
		"companion_patrol_seed": 24680,
		"companion_patrol_speed": 216.0,
	}, owner)
	_expect(owner.lingpet_companion_pos != Vector2.ZERO, "Draft Bat companion should initialize from a zero saved position")
	_expect(bool(runtime.is_companion_facing_left_for_tests()), "companion first-spawn facing should use restored patrol_dir, not the zero-to-spawn placement dx")


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


func _verify_afterglow_leak_passive() -> void:
	var afterglow_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_afterglow_leak_state.gd")
	var boot_prewarm_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(afterglow_source.find("var kept: Array") < 0, "Afterglow Leak particle update should avoid per-frame replacement arrays")
	_expect(afterglow_source.find("const PARTICLE_MAX := 48") >= 0, "Afterglow Leak should keep a bounded lightweight particle budget")
	_expect(runtime_source.find("func prewarm_assets") >= 0 and runtime_source.find("_afterglow_leak_state.prewarm()") >= 0, "lingpet runtime should expose Afterglow Leak texture prewarm before first passive hit")
	_expect(boot_prewarm_source.find("\"lingpet_runtime\"") >= 0 and boot_prewarm_source.find("lingpet_runtime.prewarm_assets()") >= 0, "boot prewarm should warm lingpet passive VFX textures off the first hit frame")
	var passive_lv1 := LingpetCatalog.get_passive_skill("maribo", "lingpet_afterglow_leak", 1)
	var passive_lv5 := LingpetCatalog.get_passive_skill("maribo", "lingpet_afterglow_leak", 5)
	_expect(str(passive_lv1.get("name", "")) == "잔광 유출", "shared passive catalog should expose the agreed Afterglow Leak Korean name")
	_expect(is_equal_approx(float(passive_lv1.get("afterglow_total_gauge", 0.0)), 20.0), "Afterglow Leak Lv.1 should spill a meaningful +20 gauge pickup")
	_expect(is_equal_approx(float(passive_lv5.get("afterglow_total_gauge", 0.0)), 100.0), "Afterglow Leak Lv.5 should scale to a rare-hit-worthy +100 gauge pickup")
	_expect(str(LingpetCatalog.normalize_passive_skill_id("maribo", "lingpet_focus_link")) == "lingpet_afterglow_leak", "old Focus Link scaffold saves should normalize to Afterglow Leak")

	var owner := FakeOwner.new()
	owner.special_gauge = 100.0
	var feedback := FakeFeedback.new()
	var orb_hud_state := FakeOrbHudState.new()
	var registry := FakeRegistry.new({
		"battle_feedback_state": feedback,
		"orb_hud_state": orb_hud_state,
	})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_afterglow_leak", registry), "debug loadout should equip Afterglow Leak for a focused passive smoke")
	owner.ball_active = true
	_hit_companion(runtime, owner, registry, owner.lingpet_companion_pos)
	var after_body_hit_gauge: float = owner.special_gauge
	var spawn_snapshot: Dictionary = runtime.get_snapshot()
	var residue_pos: Vector2 = spawn_snapshot.get("afterglow_leak_first_pos", Vector2.ZERO)
	_expect(int(runtime.get_afterglow_leak_residue_count_for_tests()) == 1, "Afterglow Leak should spill one residue when the companion hits the ball")
	_expect(residue_pos != Vector2.ZERO, "Afterglow Leak snapshot should expose the first residue position for UI/debug inspection")

	owner.player_pos = residue_pos - Vector2(owner.player_paddle_width * 0.5, owner.player_paddle_height * 0.5)
	for _i in range(8):
		runtime.update(0.10, owner, registry)
	var absorbed_snapshot: Dictionary = runtime.get_snapshot()
	_expect(absf(owner.special_gauge - (after_body_hit_gauge + 20.0)) <= 0.05, "Afterglow Leak Lv.1 should absorb 20 total gauge when the paddle approaches")
	_expect(int(absorbed_snapshot.get("afterglow_leak_trigger_count", 0)) >= 6, "Afterglow Leak should publish the fast absorb tick count")
	_expect(int(runtime.get_afterglow_leak_residue_count_for_tests()) == 0, "Afterglow Leak residue should vanish once fully absorbed")
	_expect(feedback.gauge_flashes >= 7, "Afterglow Leak absorption should reuse the gauge flash feedback after the body-hit flash")
	_expect(orb_hud_state.gauge_spins >= 7, "Afterglow Leak absorption should spin the gauge orb on every absorbed tick")

	var owner2 := FakeOwner.new()
	owner2.special_gauge = 100.0
	var runtime2: Object = LingpetEggRuntime.new()
	var registry2 := FakeRegistry.new({})
	_expect(runtime2.debug_grant_and_activate_pet("maribo", owner2, false, "maribo_hydro_sphere", "lingpet_afterglow_leak", registry2), "second debug loadout should equip Afterglow Leak for the seep-away smoke")
	owner2.ball_active = true
	_hit_companion(runtime2, owner2, registry2, owner2.lingpet_companion_pos)
	_expect(int(runtime2.get_afterglow_leak_residue_count_for_tests()) == 1, "seep-away smoke should start with one residue")
	owner2.player_pos = Vector2(0.0, 0.0)
	runtime2.update(2.6, owner2, registry2)
	_expect(int(runtime2.get_afterglow_leak_residue_count_for_tests()) == 0, "unabsorbed Afterglow Leak residue should seep into the floor after its Lv.1 lifetime")


func _verify_tailwind_steps_passive() -> void:
	var passive_lv1 := LingpetCatalog.get_passive_skill("maribo", "lingpet_tailwind_steps", 1)
	var passive_lv5 := LingpetCatalog.get_passive_skill("maribo", "lingpet_tailwind_steps", 5)
	_expect(str(passive_lv1.get("id", "")) == "lingpet_tailwind_steps", "Tailwind Steps should resolve from the shared passive catalog")
	_expect(is_equal_approx(float(passive_lv1.get("player_speed_bonus_pct", 0.0)), 4.0), "Tailwind Steps Lv.1 should increase player movement speed by 4 percent")
	_expect(is_equal_approx(float(passive_lv5.get("player_speed_bonus_pct", 0.0)), 16.0), "Tailwind Steps Lv.5 should increase player movement speed by 16 percent")

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(is_equal_approx(float(runtime.get_player_speed_multiplier()), 1.0), "inactive lingpet should not change player movement speed")
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_tailwind_steps", registry), "debug loadout should equip Tailwind Steps for a focused passive smoke")
	_expect(is_equal_approx(float(runtime.get_player_speed_multiplier()), 1.04), "Tailwind Steps Lv.1 should publish a 1.04x player speed multiplier")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(is_equal_approx(float(snapshot.get("companion_player_speed_bonus_pct", 0.0)), 4.0), "runtime snapshot should expose Tailwind Steps speed bonus for the character-info panel")
	_expect(is_equal_approx(float(owner.lingpet_player_speed_bonus_pct), 4.0), "owner should publish the lingpet player speed bonus")
	_expect(is_equal_approx(float(owner.ringpet_player_speed_bonus_pct), 4.0), "owner should publish the ringpet player speed bonus alias")
	var panel: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(panel, Color.WHITE)
	_expect(specs.size() >= 2, "Tailwind Steps panel should still expose active and passive skill specs")
	var passive_spec: Dictionary = specs[1] as Dictionary
	_expect(str(passive_spec.get("id", "")) == "lingpet_tailwind_steps", "Tailwind Steps panel spec should keep the passive id")
	_expect(str(passive_spec.get("subtitle", "")).find("이동") >= 0, "Tailwind Steps passive subtitle should explain the movement-speed bonus")


func _verify_starlight_tracking_passive() -> void:
	var passive_lv1 := LingpetCatalog.get_passive_skill("maribo", "lingpet_starlight_tracking", 1)
	var passive_lv5 := LingpetCatalog.get_passive_skill("maribo", "lingpet_starlight_tracking", 5)
	_expect(str(passive_lv1.get("name", "")) == "별빛 추적", "shared passive catalog should expose the agreed Starlight Tracking Korean name")
	_expect(is_equal_approx(float(passive_lv1.get("starpoint_tracking_chance_pct", 0.0)), 20.0), "Starlight Tracking Lv.1 should start at a 20 percent drop-trigger chance")
	_expect(is_equal_approx(float(passive_lv5.get("starpoint_tracking_chance_pct", 0.0)), 60.0), "Starlight Tracking Lv.5 should scale to a 60 percent drop-trigger chance")
	_expect(float(passive_lv5.get("starpoint_tracking_chase_speed", 0.0)) > float(passive_lv1.get("starpoint_tracking_chase_speed", 0.0)), "Starlight Tracking chase speed should scale by passive level")

	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var stage1_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_event.gd")
	var stage2_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	var stage3_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
	var stage4_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_bird_event.gd")
	_expect(runtime_source.find("update_starlight_tracking_for_starpoint_drop") >= 0, "lingpet runtime should expose a starpoint-drop tracking hook")
	_expect(stage1_source.find("LingpetStarlightTrackingBridge.update_drop") >= 0, "Stage 1 starpoint drops should offer Starlight Tracking collection")
	_expect(stage2_source.find("LingpetStarlightTrackingBridge.update_drop") >= 0, "Stage 2 starpoint drops should offer Starlight Tracking collection")
	_expect(stage3_source.find("LingpetStarlightTrackingBridge.update_drop") >= 0, "Stage 3 starpoint drops should offer Starlight Tracking collection")
	_expect(stage4_source.find("LingpetStarlightTrackingBridge.update_drop") >= 0, "Stage 4 starpoint drops should offer Starlight Tracking collection")

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", registry, 1, 5), "debug loadout should equip Starlight Tracking Lv.5 for a focused passive smoke")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(is_equal_approx(float(snapshot.get("companion_starpoint_tracking_chance_pct", 0.0)), 60.0), "runtime snapshot should expose Starlight Tracking chance for character-info")
	_expect(is_equal_approx(float(owner.lingpet_starpoint_tracking_chance_pct), 60.0), "owner should publish the lingpet starpoint tracking chance")
	_expect(is_equal_approx(float(owner.ringpet_starpoint_tracking_chance_pct), 60.0), "owner should publish the ringpet starpoint tracking chance alias")
	var panel: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(panel, Color.WHITE)
	_expect(specs.size() >= 2, "Starlight Tracking panel should still expose active and passive skill specs")
	var passive_spec: Dictionary = specs[1] as Dictionary
	_expect(str(passive_spec.get("id", "")) == "lingpet_starlight_tracking", "Starlight Tracking panel spec should keep the passive id")
	_expect(str(passive_spec.get("subtitle", "")).find("추적") >= 0, "Starlight Tracking passive subtitle should explain the drop-trigger chance")

	var companion_pos: Vector2 = owner.lingpet_companion_pos
	var close_drop := _make_starpoint_drop(companion_pos + Vector2(8.0, 0.0), 0.0)
	owner.player_pos = companion_pos + Vector2(116.0, 0.0) - Vector2(owner.player_paddle_width, owner.player_paddle_height) * 0.5
	var close_context := _starpoint_delivery_context(owner)
	var close_result: Dictionary = runtime.update_starlight_tracking_for_starpoint_drop(close_drop, 0.0, close_context)
	_expect(bool(close_result.get("picked_up", false)) and not bool(close_result.get("delivered", false)), "Starlight Tracking should pick up a successfully claimed nearby starpoint without granting it immediately")
	_expect(bool(close_result.get("holding", false)), "Starlight Tracking should pause briefly after picking up a starpoint")
	_expect(int(runtime.get_starlight_tracking_trigger_count_for_tests()) == 0, "Starlight Tracking should not count the reward before delivering the starpoint to the player")
	var close_hold_result: Dictionary = runtime.update_starlight_tracking_for_starpoint_drop(close_drop, 0.30, close_context)
	_expect(bool(close_hold_result.get("holding", false)) and not bool(close_hold_result.get("delivered", false)), "Starlight Tracking should still hesitate during the one-second pickup hold")
	_expect(int(runtime.get_starlight_tracking_trigger_count_for_tests()) == 0, "Starlight Tracking should not count the reward while the companion is hesitating")
	var close_carry_result: Dictionary = runtime.update_starlight_tracking_for_starpoint_drop(close_drop, 0.70, close_context)
	_expect(not bool(close_carry_result.get("holding", true)) and not bool(close_carry_result.get("delivered", false)), "Starlight Tracking should start carrying only after the pickup hold finishes")
	var close_delivery_result: Dictionary = runtime.update_starlight_tracking_for_starpoint_drop(close_drop, 0.30, close_context)
	_expect(bool(close_delivery_result.get("delivered", false)), "Starlight Tracking should grant the starpoint only after the companion carries it to the player")
	_expect(int(runtime.get_starlight_tracking_trigger_count_for_tests()) == 1, "Starlight Tracking should count successful deliveries")

	var owner2 := FakeOwner.new()
	var runtime2: Object = LingpetEggRuntime.new()
	_expect(runtime2.debug_grant_and_activate_pet("maribo", owner2, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", registry, 1, 1), "second debug loadout should equip Starlight Tracking Lv.1 for a failed-roll smoke")
	var failed_drop := _make_starpoint_drop(owner2.lingpet_companion_pos + Vector2(8.0, 0.0), 99.0)
	var failed_result: Dictionary = runtime2.update_starlight_tracking_for_starpoint_drop(failed_drop, 0.0, _starpoint_delivery_context(owner2))
	_expect(not bool(failed_result.get("claimed", false)), "Starlight Tracking should not claim a drop when its spawn roll fails")
	_expect(bool(failed_drop.get("lingpet_starlight_tracking_roll_done", false)), "Starlight Tracking should roll each starpoint drop only once")

	var owner3 := FakeOwner.new()
	var runtime3: Object = LingpetEggRuntime.new()
	_expect(runtime3.debug_grant_and_activate_pet("maribo", owner3, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", registry, 1, 5), "third debug loadout should equip Starlight Tracking Lv.5 for a chase smoke")
	var far_target := owner3.lingpet_companion_pos + Vector2(160.0, 0.0)
	var far_drop := _make_starpoint_drop(far_target, 0.0)
	owner3.player_pos = owner3.lingpet_companion_pos + Vector2(-120.0, 0.0) - Vector2(owner3.player_paddle_width, owner3.player_paddle_height) * 0.5
	var far_context := _starpoint_delivery_context(owner3)
	var far_result: Dictionary = runtime3.update_starlight_tracking_for_starpoint_drop(far_drop, 0.10, far_context)
	_expect(bool(far_result.get("claimed", false)) and not bool(far_result.get("picked_up", false)), "Starlight Tracking should chase a successful far starpoint before picking it up")
	_expect(bool(runtime3.is_starlight_tracking_active_for_tests()), "Starlight Tracking should keep a companion-position override while chasing")
	var chase_pos_value: Variant = far_result.get("companion_pos", Vector2.ZERO)
	var chase_pos: Vector2 = chase_pos_value if chase_pos_value is Vector2 else Vector2.ZERO
	_expect(chase_pos != Vector2.ZERO and chase_pos.distance_to(far_target) < owner3.lingpet_companion_pos.distance_to(far_target), "Starlight Tracking should move the companion toward the starpoint")
	var pickup_result: Dictionary = runtime3.update_starlight_tracking_for_starpoint_drop(far_drop, 0.20, far_context)
	_expect(bool(pickup_result.get("picked_up", false)) and bool(pickup_result.get("holding", false)) and not bool(pickup_result.get("delivered", false)), "Starlight Tracking should hold the far starpoint briefly after the companion reaches it")
	var far_hold_result: Dictionary = runtime3.update_starlight_tracking_for_starpoint_drop(far_drop, 0.40, far_context)
	_expect(bool(far_hold_result.get("holding", false)) and not bool(far_hold_result.get("delivered", false)), "Starlight Tracking should not deliver a far pickup before the one-second hold is over")
	var far_carry_result: Dictionary = runtime3.update_starlight_tracking_for_starpoint_drop(far_drop, 0.60, far_context)
	_expect(not bool(far_carry_result.get("holding", true)) and not bool(far_carry_result.get("delivered", false)), "Starlight Tracking should leave the pickup hold after one second")
	var deliver_result: Dictionary = runtime3.update_starlight_tracking_for_starpoint_drop(far_drop, 0.40, far_context)
	_expect(bool(deliver_result.get("delivered", false)), "Starlight Tracking should deliver the carried far starpoint to the player before granting it")


func _verify_ring_dash_passive() -> void:
	var passive_lv1 := LingpetCatalog.get_passive_skill("maribo", "lingpet_ring_dash", 1)
	var passive_lv5 := LingpetCatalog.get_passive_skill("maribo", "lingpet_ring_dash", 5)
	_expect(str(passive_lv1.get("name", "")) == "링크포트", "shared passive catalog should expose the agreed Linkport Korean name")
	_expect(is_equal_approx(float(passive_lv1.get("ring_dash_chance_pct", 0.0)), 25.0), "Ring Dash Lv.1 should start as a rare emergency guard")
	_expect(is_equal_approx(float(passive_lv5.get("ring_dash_chance_pct", 0.0)), 55.0), "Ring Dash Lv.5 should improve the emergency guard chance")
	_expect(float(passive_lv5.get("ring_dash_reappear_delay_seconds", 99.0)) < float(passive_lv1.get("ring_dash_reappear_delay_seconds", 0.0)), "Ring Dash reappear delay should shrink by passive level")
	_expect(float(passive_lv5.get("ring_dash_cooldown_seconds", 99.0)) < float(passive_lv1.get("ring_dash_cooldown_seconds", 0.0)), "Ring Dash cooldown should shrink by passive level")
	_expect(is_equal_approx(float(passive_lv5.get("ring_dash_lookahead_gap", 0.0)), 120.0), "Linkport should only scan the lower emergency band near the player paddle")

	var owner := FakeOwner.new()
	owner.lingpet_ring_dash_force_roll_pct = 0.0
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_ring_dash", registry, 1, 5), "debug loadout should equip Ring Dash Lv.5 for a focused passive smoke")
	var start_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(Vector2(120.0, start_pos.y), 2, 0.0, false)
	owner.player_pos = Vector2(240.0, owner.player_pos.y)
	owner.player_paddle_width = 170.0
	owner.ball_active = true
	owner.ball_pos = Vector2(640.0, owner.player_pos.y - 180.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.12, owner, registry)
	_expect(not bool(runtime.is_ring_dash_active_for_tests()), "Linkport should wait while the descending ball is still well above the player-side emergency line")
	_expect(int(runtime.get_ring_dash_trigger_count_for_tests()) == 0, "Linkport should not spend a trigger before the ball reaches the lower emergency band")
	owner.ball_pos = Vector2(640.0, owner.player_pos.y - 40.0)
	runtime.update(0.12, owner, registry)
	var dash_snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(runtime.is_ring_dash_active_for_tests()), "Ring Dash should start when the player cannot block and the companion is far from the predicted ball")
	_expect(int(runtime.get_ring_dash_trigger_count_for_tests()) == 1, "Ring Dash should count emergency dash starts")
	_expect(is_equal_approx(owner.lingpet_companion_pos.x, 640.0), "Ring Dash should teleport the companion directly to the predicted ball X instead of sliding across the field")
	_expect(bool(dash_snapshot.get("ring_dash_active", false)), "runtime snapshot should expose the active Ring Dash state")
	_expect(bool(dash_snapshot.get("ring_dash_visual_hidden", false)), "Ring Dash should briefly hide the companion body for a vanish/reappear beat")
	_expect(bool(runtime.is_ring_dash_visual_hidden_for_tests()), "Ring Dash visual-hidden test hook should expose the vanish beat")
	_expect(bool(runtime.is_ring_dash_vfx_active_for_tests()), "Ring Dash should fire the Linkport teleport burst VFX on dash start for a visible 전이 cue")
	_expect(is_equal_approx(float(dash_snapshot.get("companion_ring_dash_chance_pct", 0.0)), 55.0), "runtime snapshot should expose Ring Dash chance for character-info")
	_expect(is_equal_approx(float(owner.lingpet_ring_dash_chance_pct), 55.0), "owner should publish the lingpet Ring Dash chance")
	_expect(is_equal_approx(float(owner.ringpet_ring_dash_chance_pct), 55.0), "owner should publish the ringpet Ring Dash chance alias")
	runtime.update(0.05, owner, registry)
	var reappear_snapshot: Dictionary = runtime.get_snapshot()
	_expect(not bool(reappear_snapshot.get("ring_dash_visual_hidden", true)), "Ring Dash should reveal the companion again after the short teleport vanish")
	_expect(is_equal_approx(owner.lingpet_companion_pos.x, 640.0), "Ring Dash should hold the reappeared companion at the intercept point instead of drifting back and forth")

	var panel: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(panel, Color.WHITE)
	_expect(specs.size() >= 2, "Ring Dash panel should still expose active and passive skill specs")
	var passive_spec: Dictionary = specs[1] as Dictionary
	_expect(str(passive_spec.get("id", "")) == "lingpet_ring_dash", "Ring Dash panel spec should keep the passive id")
	_expect(str(passive_spec.get("subtitle", "")).find("전이") >= 0, "Linkport passive subtitle should explain the emergency teleport chance")

	var owner2 := FakeOwner.new()
	owner2.lingpet_ring_dash_force_roll_pct = 0.0
	var runtime2: Object = LingpetEggRuntime.new()
	_expect(runtime2.debug_grant_and_activate_pet("maribo", owner2, false, "maribo_hydro_sphere", "lingpet_ring_dash", registry, 1, 5), "second debug loadout should equip Ring Dash Lv.5 for player-block gating")
	var start_pos2: Vector2 = owner2.lingpet_companion_pos
	runtime2.configure_companion_motion_for_tests(Vector2(120.0, start_pos2.y), 2, 0.0, false)
	owner2.player_pos = Vector2(560.0, owner2.player_pos.y)
	owner2.player_paddle_width = 170.0
	owner2.ball_active = true
	owner2.ball_pos = Vector2(640.0, owner2.player_pos.y - 40.0)
	owner2.ball_vel = Vector2(0.0, 12.0)
	runtime2.update(0.12, owner2, registry)
	_expect(not bool(runtime2.is_ring_dash_active_for_tests()), "Ring Dash should stay idle when the player paddle can still block the predicted ball")
	_expect(int(runtime2.get_ring_dash_trigger_count_for_tests()) == 0, "Ring Dash should not spend a trigger on player-blockable balls")

	var owner3 := FakeOwner.new()
	owner3.lingpet_ring_dash_force_roll_pct = 0.0
	var runtime3: Object = LingpetEggRuntime.new()
	_expect(runtime3.debug_grant_and_activate_pet("lunabi", owner3, false, "lunabi_headbutt", "lingpet_ring_dash", registry, 1, 5), "flight companion debug loadout should equip Linkport Lv.5")
	var hidden_pos := Vector2(-120.0, 245.0)
	runtime3.configure_companion_sortie_hidden_for_tests(hidden_pos, 2, 8.0)
	owner3.player_pos = Vector2(240.0, owner3.player_pos.y)
	owner3.player_paddle_width = 170.0
	owner3.ball_active = true
	owner3.ball_pos = Vector2(640.0, owner3.player_pos.y - 13.0)
	owner3.ball_vel = Vector2(0.0, 12.0)
	runtime3.update(0.12, owner3, registry)
	var flight_hidden_dash: Dictionary = runtime3.get_snapshot()
	_expect(bool(flight_hidden_dash.get("ring_dash_active", false)), "Linkport should start even if a sortie-flight companion was offscreen")
	_expect(bool(flight_hidden_dash.get("ring_dash_visual_hidden", false)), "Linkport should keep the flight companion hidden for the vanish beat")
	_expect(int(flight_hidden_dash.get("companion_contact_count", 0)) == 0, "Linkport should not let an invisible flight companion hit the ball before it reappears")
	runtime3.update(0.05, owner3, registry)
	var flight_visible_dash: Dictionary = runtime3.get_snapshot()
	_expect(int(flight_visible_dash.get("companion_contact_count", 0)) == 1, "Linkport should hit after the flight companion has reappeared")
	_expect(float(owner3.ball_vel.y) < 0.0, "Linkport hit should bounce the descending ball upward after reappearing")
	runtime3.update(0.05, owner3, registry)
	var flight_resume: Dictionary = runtime3.get_snapshot()
	_expect(not bool(flight_resume.get("ring_dash_active", false)), "Linkport should clear once the guarded ball has bounced away")
	_expect(bool(flight_resume.get("companion_visible", false)), "A sortie-flight companion should stay visible after Linkport instead of disappearing again")
	_expect(str(flight_resume.get("companion_sortie_phase", "")) == "loiter", "A sortie-flight companion should resume normal visible roaming after Linkport")
	var resumed_pos: Vector2 = flight_resume.get("companion_pos", Vector2.ZERO)
	_expect(resumed_pos.x >= 0.0 and resumed_pos.x <= 760.0 and resumed_pos.y >= 0.0 and resumed_pos.y <= 750.0, "A sortie-flight companion should keep an on-screen body position after Linkport")


func _verify_ring_dash_single_roll_per_descent() -> void:
	# Linkport must roll ONCE per descent, not once per frame. Without the per-descent
	# lock the per-frame roll compounds (1 - (1 - p)^N over the frames the ball spends
	# in the guard band), so even Lv.1's 12% saturates toward certainty and every level
	# feels identical. A failed roll must NOT get a second chance while the same
	# descending ball stays inside the band.
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_ring_dash_force_roll_pct = 100.0  # roll 100 > Lv.5 chance 55 -> guaranteed fail
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_ring_dash", registry, 1, 5), "single-roll smoke should equip Ring Dash Lv.5")
	var start_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(Vector2(120.0, start_pos.y), 2, 0.0, false)
	owner.player_pos = Vector2(240.0, owner.player_pos.y)
	owner.player_paddle_width = 170.0
	owner.ball_active = true
	owner.ball_pos = Vector2(640.0, owner.player_pos.y - 40.0)  # inside the lower emergency band
	owner.ball_vel = Vector2(0.0, 12.0)  # descending toward the player floor

	runtime.update(0.05, owner, registry)
	_expect(not bool(runtime.is_ring_dash_active_for_tests()), "a failed Linkport roll should not trigger the dash")
	_expect(int(runtime.get_ring_dash_trigger_count_for_tests()) == 0, "a failed Linkport roll should spend no trigger")
	_expect(bool(runtime.get_snapshot().get("ring_dash_rolled_this_descent", false)), "a Linkport roll should lock further rolls for the current descent")

	# Same descent, now make the next roll a guaranteed success. The per-descent lock
	# must suppress the re-roll, so the dash still must NOT fire this frame.
	owner.lingpet_ring_dash_force_roll_pct = 0.0  # would succeed if a re-roll happened
	runtime.update(0.05, owner, registry)
	_expect(not bool(runtime.is_ring_dash_active_for_tests()), "Linkport must not re-roll within the same descent even when the next roll would succeed")
	_expect(int(runtime.get_ring_dash_trigger_count_for_tests()) == 0, "Linkport must spend exactly one roll per descent")

	# A genuinely new descent (ball bounced upward, then falls again) re-arms the roll.
	owner.ball_vel = Vector2(0.0, -8.0)  # bounced upward -> the opportunity ends, lock clears
	runtime.update(0.05, owner, registry)
	_expect(not bool(runtime.get_snapshot().get("ring_dash_rolled_this_descent", true)), "a non-descending ball should clear the Linkport descent lock")
	owner.ball_pos = Vector2(640.0, owner.player_pos.y - 40.0)
	owner.ball_vel = Vector2(0.0, 12.0)  # fresh descent into the band
	runtime.update(0.05, owner, registry)
	_expect(bool(runtime.is_ring_dash_active_for_tests()), "a fresh descent should re-arm the single Linkport roll")
	_expect(int(runtime.get_ring_dash_trigger_count_for_tests()) == 1, "the fresh descent should produce exactly one successful trigger")


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


func _verify_lingpet_skill_cooldown_survives_slot_switch() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo", "lunabi"]
	owner.owned_lingpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.owned_ringpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.lingpet_slots = ["maribo", "lunabi", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	owner.ball_active = true
	var runtime: Object = LingpetEggRuntime.new()
	var audio := FakePaddleAudio.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"status_effect_state": FakeStatusEffectState.new(),
	})
	runtime.update(0.0, owner, registry)
	runtime.update(0.0, owner, registry)
	runtime.update(LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS + 0.05, owner, registry)
	var maribo_cooldown: float = float(owner.lingpet_skill_cooldown)
	_expect(str(owner.active_lingpet_id) == "maribo", "skill cooldown switch test should start with Maribo active")
	_expect(maribo_cooldown > 39.0, "Maribo skill should have a live cooldown before switching away")
	_expect(bool(runtime.switch_lingpet_slot(1, owner)), "switching to the occupied Lunabi slot should succeed")
	_expect(str(owner.active_lingpet_id) == "lunabi", "slot switch should activate Lunabi")
	_expect(is_equal_approx(float(owner.lingpet_skill_cooldown), 0.0), "freshly switched Lunabi should publish its own ready skill state")
	owner.ball_active = false
	runtime.update(10.0, owner, registry)
	_expect(bool(runtime.switch_lingpet_slot(0, owner)), "switching back to Maribo should succeed")
	_expect(str(owner.active_lingpet_id) == "maribo", "slot switch should reactivate Maribo")
	var restored_cooldown: float = float(owner.lingpet_skill_cooldown)
	_expect(restored_cooldown > 28.0 and restored_cooldown < maribo_cooldown - 9.5, "inactive Maribo cooldown should keep ticking while another lingpet is active")


func _verify_lingpet_skill_waits_for_switch_transition() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["lunabi", "maribo"]
	owner.owned_lingpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.owned_ringpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.lingpet_slots = ["lunabi", "maribo", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	owner.ball_active = true
	var runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new({
		"game_audio": FakePaddleAudio.new(),
		"status_effect_state": FakeStatusEffectState.new(),
	})
	runtime.update(0.0, owner, registry)
	_expect(str(owner.active_lingpet_id) == "lunabi", "switch-transition skill test should start with Lunabi active")
	_expect(bool(runtime.switch_lingpet_slot(1, owner)), "switch-transition skill test should switch to Maribo")
	runtime.update(0.1, owner, registry)
	_expect(not bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "newly switched lingpet should not auto-arm its skill while the switch transition is still playing")
	runtime.update(LingpetEggRuntime.COMPANION_SWITCH_TRANSITION_SECONDS + 0.05, owner, registry)
	_expect(bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "newly switched lingpet may arm its skill after the switch transition finishes")


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
	var hatched_id := str(owner.active_lingpet_id)

	var snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(int(snapshot.get("version", 0)) == 1, "lingpet save snapshot should carry a schema version")
	_expect((snapshot.get("owned_pet_ids", []) as Array).has(hatched_id), "lingpet save snapshot should preserve the hatched lingpet")
	_expect(str((snapshot.get("battle_slot_pet_ids", []) as Array)[0]) == hatched_id, "lingpet save snapshot should preserve the battle slot assignment")
	_expect(int(snapshot.get("active_slot_index", -1)) == 0, "lingpet save snapshot should preserve the active battle slot index")
	_expect(snapshot.get("lingpet_loadouts", {}) is Dictionary and (snapshot.get("lingpet_loadouts", {}) as Dictionary).has(hatched_id), "lingpet save snapshot should preserve selected skill loadouts")

	var restored_owner := FakeOwner.new()
	restored_owner.ai_mode = "champion"
	var restored: Object = LingpetEggRuntime.new()
	var restore_result: Dictionary = restored.apply_save_snapshot(snapshot, restored_owner)
	_expect(bool(restore_result.get("restored", false)), "lingpet save snapshot should restore successfully")
	_expect(str(restored_owner.lingpet_state) == "companion", "restored owned lingpet should sync companion state")
	_expect(restored_owner.owned_lingpet_ids.has(hatched_id), "restore should republish owned pet ids to the owner")
	_expect(str((restored_owner.lingpet_slots as Array)[0]) == hatched_id, "restore should republish battle slot assignment")
	_expect(bool(restored_owner.owned_lingpets.get(hatched_id, false)), "restore should republish owned collection to the owner")
	_expect(restored_owner.lingpet_loadouts is Dictionary and (restored_owner.lingpet_loadouts as Dictionary).has(hatched_id), "restore should republish the selected lingpet loadout")


func _verify_save_store_persists_and_restores_maribo() -> void:
	var companion_path := "user://lingpet_save_store_companion_smoke.cfg"
	_remove_user_file(companion_path)
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1)

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
	var egg_store: Object = LingpetSaveStore.new()
	egg_store.set_save_path(egg_path)
	_expect(bool(egg_store.save_runtime(egg_owner, FakeRegistry.new({"lingpet_egg_runtime": egg_runtime}))), "lingpet save store should clear volatile egg state")
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
	_expect(str(owner.lingpet_effect_text).find("공용 풀") >= 0, "owner effect text should defer passive details to the shared passive loadout")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(is_equal_approx(float(snapshot.get("companion_patrol_speed_min", 0.0)), 70.0), "Maribo snapshot should expose patrol speed min for the character-info panel")
	_expect(is_equal_approx(float(snapshot.get("companion_patrol_speed_max", 0.0)), 135.0), "Maribo snapshot should expose patrol speed max for the character-info panel")
	_expect(is_equal_approx(float(snapshot.get("companion_catch_width", 0.0)), 100.0), "Maribo snapshot should expose the real horizontal catch footprint")
	_expect(is_equal_approx(float(snapshot.get("companion_catch_height", 0.0)), 44.0), "Maribo snapshot should expose the real vertical catch footprint")
	_expect(is_equal_approx(float(snapshot.get("companion_defense_rate", 0.0)), 0.30), "Maribo snapshot should expose defense rate only once AI is wired")
	_expect(is_equal_approx(float(owner.lingpet_companion_patrol_speed_min), 70.0), "owner should sync Maribo speed range for character-info")
	_expect(is_equal_approx(float(owner.lingpet_companion_catch_width), 100.0), "owner should sync Maribo catch width for character-info")
	_expect(is_equal_approx(float(owner.lingpet_companion_defense_rate), 0.30), "owner should sync Maribo defense rate for character-info")
	_expect(is_equal_approx(float(runtime.get_gauge_gain_per_hit(50.0)), 52.0), "Maribo's Lv.1 Resonance Boost should turn 50 gauge gain into 52")

	var overlay := CharacterInfoOverlay.new()
	var lingpet_stats: Array = overlay._build_lingpet_stats(owner)
	_expect(lingpet_stats.size() == 5, "character-info lingpet stats should show only implemented Maribo companion rows")
	_expect(_stat_values_have_exact(lingpet_stats, "2.00"), "character-info lingpet stats should show Maribo speed as a slower single player-style value")
	_expect(_stat_values_have_fragment(lingpet_stats, "100x44"), "character-info lingpet stats should show the body-size footprint")
	_expect(_stat_values_have_exact(lingpet_stats, "40pt"), "character-info lingpet stats should show the direct hit gauge gain as a common stat")
	_expect(_stat_values_have_exact(lingpet_stats, "40초"), "character-info lingpet stats should show Hydro Sphere cooldown")
	_expect(_stat_values_have_exact(lingpet_stats, "30%"), "character-info lingpet stats should show the real defense rate")

	var overlay_gain: float = CharacterInfoOverlayStatsPresenter.effective_gauge_gain_per_hit(null, [runtime], Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))
	_expect(is_equal_approx(overlay_gain, 52.0), "character-info gauge-gain stat should read the Lv.1 Resonance Boost passive bonus")

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
	_expect(is_equal_approx(gauge_after_hit, 152.0), "player paddle hit should apply Maribo's Lv.1 Resonance Boost passive bonus")
	var gauge_after_drive: float = router.register_player_hit(Vector2(320.0, 690.0), 0.0, true, false, 100.0, context, deps)
	_expect(is_equal_approx(gauge_after_drive, 100.0), "Maribo should not bypass drive-hit gauge gain blocking")


func _verify_maribo_defense_rate_intercepts_descending_ball() -> void:
	# Defense is a LOCAL predictive guard with three gates: (1) the PLAYER cannot
	# reach the ball, (2) it falls NEAR the lingpet (reachable), (3) the roll passes.
	# It aims at the PREDICTED landing X. FakeOwner's player paddle covers ~x[249,511]
	# (pos 263.75, width 232.5, ball r 14.3), so x=650 is a ball the player can't
	# block and x=420 is one the player CAN block.
	# --- near but PLAYER CAN block: must NOT arm (a guard the player could make is
	#     pointless) -----------------------------------------------------------------
	var block_owner := FakeOwner.new()
	block_owner.lingpet_owned_pet_ids = ["maribo"]
	var block_runtime: Object = LingpetEggRuntime.new()
	block_runtime.update(0.0, block_owner)
	var block_start: Vector2 = block_owner.lingpet_companion_pos
	block_runtime.configure_companion_motion_for_tests(Vector2(340.0, block_start.y), 2, 0.0, false)
	block_owner.ball_active = true
	block_owner.ball_pos = Vector2(420.0, block_start.y - 300.0)  # near lingpet, but inside player reach
	block_owner.ball_vel = Vector2(0.0, 12.0)
	block_runtime.update(0.05, block_owner)
	_expect(not bool(block_owner.lingpet_companion_defense_intercept_active), "defense must NOT arm for a near ball the PLAYER can still block")

	# --- near AND player CANNOT block: arms and aims at the predicted landing X ----
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var start_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(Vector2(570.0, start_pos.y), 2, 0.0, false)
	owner.ball_active = true
	owner.ball_pos = Vector2(650.0, start_pos.y - 300.0)  # 80px aside, beyond player reach
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.05, owner)
	_expect(bool(owner.lingpet_companion_defense_intercept_active), "defense should arm for a near ball the player cannot block")
	_expect(owner.lingpet_companion_pos.x > 570.0, "an armed local guard should start moving toward the predicted ball X")
	_expect(absf(float(owner.lingpet_companion_defense_intercept_target_x) - 650.0) <= 8.0, "the guard should aim at the predicted landing X")

	owner.ball_active = false
	runtime.update(0.10, owner)
	_expect(not bool(owner.lingpet_companion_defense_intercept_active), "defense intercept should clear once the ball is no longer active")

	# --- predictive lead: a horizontally drifting ball -> target LEADS its current X
	var lead_owner := FakeOwner.new()
	lead_owner.lingpet_owned_pet_ids = ["maribo"]
	var lead_runtime: Object = LingpetEggRuntime.new()
	lead_runtime.update(0.0, lead_owner)
	var lead_start: Vector2 = lead_owner.lingpet_companion_pos
	lead_runtime.configure_companion_motion_for_tests(Vector2(620.0, lead_start.y), 2, 0.0, false)
	lead_owner.ball_active = true
	lead_owner.ball_pos = Vector2(620.0, lead_start.y - 120.0)  # beyond player reach
	lead_owner.ball_vel = Vector2(3.0, 12.0)  # drifting right while descending
	lead_runtime.update(0.05, lead_owner)
	_expect(bool(lead_owner.lingpet_companion_defense_intercept_active), "defense should arm for a near drifting ball the player cannot block")
	_expect(float(lead_owner.lingpet_companion_defense_intercept_target_x) > 620.0, "predictive guard target should LEAD a rightward-drifting ball, not aim at its current X")

	# --- far ball: out of the local guard zone, must NOT arm (no field sprint) -----
	var far_owner := FakeOwner.new()
	far_owner.lingpet_owned_pet_ids = ["maribo"]
	var far_runtime: Object = LingpetEggRuntime.new()
	far_runtime.update(0.0, far_owner)
	var far_start: Vector2 = far_owner.lingpet_companion_pos
	far_runtime.configure_companion_motion_for_tests(Vector2(120.0, far_start.y), 2, 0.0, false)
	far_owner.ball_active = true
	far_owner.ball_pos = Vector2(700.0, far_start.y - 150.0)  # player can't block AND 580px from lingpet
	far_owner.ball_vel = Vector2(0.0, 12.0)
	far_runtime.update(0.05, far_owner)
	_expect(not bool(far_owner.lingpet_companion_defense_intercept_active), "defense must NOT arm for a far ball outside the lingpet's local guard zone")


func _verify_maribo_defense_actually_blocks_reachable_ball() -> void:
	# A LOCAL guard that arms for a NEAR ball must actually GUARD it: the ball is
	# bounced upward (ball_vel.y < 0), not merely leaned toward. (Far balls never arm
	# -- that zone gate is covered by _verify_maribo_defense_rate_intercepts_descending_ball.)
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	# Maribo auto-casts Hydro Sphere with a ~1s wind-up that FREEZES companion motion
	# (windup_active -> freeze_motion). Let the initial cast LAUNCH (needs an active
	# ball) so it enters its 40s cooldown and stops re-winding; then the guard moves
	# freely. Ball is parked away from the lane so it triggers nothing during warm-up.
	owner.ball_active = true
	owner.ball_pos = Vector2(60.0, 120.0)
	owner.ball_vel = Vector2(0.0, 0.0)
	for _w in range(10):
		runtime.update(0.2, owner, registry)
	_expect(not bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "initial Hydro Sphere wind-up should be finished before the guard scenario")
	var lane_y: float = owner.lingpet_companion_pos.y
	runtime.configure_companion_motion_for_tests(Vector2(570.0, lane_y), 2, 0.0, false)
	# Real ball motion = ball_vel * delta * 60 (ball_update_controller fps_scale).
	# Mirror it, or the ball descends ~3x too slowly and inflates the guard window.
	var step_delta := 0.05
	var ball_vy := 12.0
	var step_drop := ball_vy * step_delta * 60.0  # 36px/step (real descent)
	owner.ball_active = true
	# Near ball the PLAYER CANNOT block: x=650 is beyond the player paddle reach
	# (~x[249,511]) and 80px aside from the lingpet (outside the ~64px body catch, so
	# the guard MUST move in), within the local reach budget from the start gap.
	var ball_y: float = lane_y - 300.0
	owner.ball_pos = Vector2(650.0, ball_y)
	owner.ball_vel = Vector2(0.0, ball_vy)
	runtime.update(step_delta, owner, registry)
	_expect(bool(owner.lingpet_companion_defense_intercept_active), "the near, player-unblockable ball should arm the local guard")
	ball_y += step_drop
	var blocked := false
	for _i in range(20):
		owner.ball_pos = Vector2(650.0, ball_y)
		owner.ball_vel = Vector2(0.0, ball_vy)
		runtime.update(step_delta, owner, registry)
		if int(owner.lingpet_companion_contact_count) >= 1:
			blocked = true
			break
		ball_y += step_drop
	_expect(blocked, "an armed local guard should actually intercept-and-bounce the near ball at the real descent rate, not just lean toward it")
	_expect(float(owner.ball_vel.y) < 0.0, "a guarded ball should be bounced upward (ball_vel.y < 0)")


func _verify_maribo_defense_anticipates_moderate_distance_ball() -> void:
	# Anticipatory commit: the guard must arm EARLY for a ball heading to a moderate
	# distance INSIDE the local zone (farther than it could reach in a single frame),
	# then start easing toward the predicted X. This is what stops a high defense rate
	# from whiffing nearby balls because it committed too late. A far ball beyond the
	# local zone must still NOT arm (no field sprint).
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var start_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(Vector2(420.0, start_pos.y), 2, 0.0, false)
	owner.ball_active = true
	# 180px aside: inside the local commit zone (220) but well beyond a single-frame
	# reach, and beyond the player paddle (x[249,511]) so the player cannot block it.
	owner.ball_pos = Vector2(600.0, start_pos.y - 300.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.05, owner)
	_expect(bool(owner.lingpet_companion_defense_intercept_active), "defense should anticipatorily arm for a moderate-distance ball inside the local zone (not wait until it is one-frame reachable)")
	_expect(owner.lingpet_companion_pos.x > 420.0, "an anticipatory guard should start easing toward the predicted X early")
	_expect(float(owner.lingpet_companion_defense_intercept_target_x) > 560.0, "the anticipatory anchor should be the predicted landing X (~600), not the lingpet's current spot")

	# A ball beyond the local zone must still be ignored (no field sprint).
	var far_owner := FakeOwner.new()
	far_owner.lingpet_owned_pet_ids = ["maribo"]
	var far_runtime: Object = LingpetEggRuntime.new()
	far_runtime.update(0.0, far_owner)
	var far_start: Vector2 = far_owner.lingpet_companion_pos
	far_runtime.configure_companion_motion_for_tests(Vector2(120.0, far_start.y), 2, 0.0, false)
	far_owner.ball_active = true
	far_owner.ball_pos = Vector2(700.0, far_start.y - 150.0)  # 580px away, beyond the local zone
	far_owner.ball_vel = Vector2(0.0, 12.0)
	far_runtime.update(0.05, far_owner)
	_expect(not bool(far_owner.lingpet_companion_defense_intercept_active), "a ball beyond the local zone must not arm the anticipatory guard")


func _verify_rabi_ghost_blink_cycle() -> void:
	# rabi (free_flight) is a GHOST: it must VANISH in place then REAPPEAR at a NEW spot
	# (not roam continuously), and a higher appearance_rate (출현율) must shorten the
	# hidden wait between blinks. Drives the motion state directly for determinism.
	var slow: Dictionary = _measure_ghost_hidden_wait(0.0)
	var fast: Dictionary = _measure_ghost_hidden_wait(1.0)
	var slow_hidden: float = float(slow.get("hidden", 0.0))
	var fast_hidden: float = float(fast.get("hidden", 0.0))
	var slow_vanish: Vector2 = slow.get("vanish_pos", Vector2.ZERO)
	var slow_reappear: Vector2 = slow.get("reappear_pos", Vector2.ZERO)
	var slow_spawn: Vector2 = slow.get("spawn_pos", Vector2.ZERO)
	_expect(slow_hidden > 0.0, "rabi ghost should vanish then reappear, not stay visible forever (the old center-roaming bug)")
	_expect(slow_reappear != slow_vanish, "rabi ghost should reappear at a NEW random spot, not the spot it vanished from")
	_expect(slow_vanish != slow_spawn, "rabi ghost should DRIFT while visible (keep moving after appearing), not sit frozen until it vanishes")
	_expect(fast_hidden > 0.0, "rabi ghost should still reappear at appearance_rate 1.0")
	_expect(fast_hidden < slow_hidden, "higher appearance_rate should shorten rabi's hidden wait before reappearing")


func _verify_ghost_blink_vfx() -> void:
	# The high-quality "퐁" blink VFX (cached glow texture + wisp particles + eased
	# envelopes) must light up on appear/vanish, run its particle sim, and fully expire.
	var vfx: Object = LingpetGhostBlinkVfx.new()
	_expect(not vfx.has_visible_effects(), "ghost blink VFX should start idle")
	vfx.trigger_appear(Vector2(380.0, 360.0))
	_expect(vfx.has_visible_effects(), "trigger_appear should make the ghost blink VFX active (pop + scatter wisps)")
	# Drive the particle sim well past the envelope + wisp lifetimes; it must clear.
	for _i in range(40):
		vfx.advance(0.05)
	_expect(not vfx.has_visible_effects(), "appear VFX should fully expire (timers + wisp pool drained)")
	vfx.trigger_vanish(Vector2(420.0, 300.0))
	_expect(vfx.has_visible_effects(), "trigger_vanish should make the ghost blink VFX active (implode poof)")
	for _j in range(40):
		vfx.advance(0.05)
	_expect(not vfx.has_visible_effects(), "vanish VFX should fully expire")

	# Wiring: the egg runtime must advance, draw, and fire the blink on free-flight
	# visibility edges, and reset it on the lingpet reset paths.
	var runtime_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_src.find("_ghost_blink_vfx.trigger_appear") >= 0 and runtime_src.find("_ghost_blink_vfx.trigger_vanish") >= 0, "egg runtime should fire the ghost blink VFX on appear/vanish edges")
	_expect(runtime_src.find("_ghost_blink_vfx.draw(") >= 0 and runtime_src.find("_ghost_blink_vfx.advance(") >= 0, "egg runtime should advance + draw the ghost blink VFX")
	_expect(runtime_src.find("_ghost_blink_vfx.reset()") >= 0, "egg runtime should reset the ghost blink VFX on lingpet resets")


func _measure_ghost_hidden_wait(rate: float) -> Dictionary:
	var motion: Object = LingpetCompanionMotionState.new()
	var owner := FakeOwner.new()
	motion.patrol_seed = 24680  # fixed seed: both rates share the RNG so only the
	motion.pos = Vector2.ZERO   # appearance_rate scaling differs, not the random rolls
	var dt := 0.1
	# First update initializes the ghost (spawn spot, visible).
	motion.update(dt, owner, false, 0.0, 0, 70.0, 200.0, "free_flight", rate)
	var spawn_pos: Vector2 = motion.pos
	# Advance through the visible phase (drifting) until the ghost first vanishes.
	var visible_elapsed := 0.0
	while bool(motion.motion_visible) and visible_elapsed < 25.0:
		motion.update(dt, owner, false, 0.0, 0, 70.0, 200.0, "free_flight", rate)
		visible_elapsed += dt
	var vanish_pos: Vector2 = motion.pos
	# Advance through the hidden wait until it reappears.
	var hidden := 0.0
	while not bool(motion.motion_visible) and hidden < 40.0:
		motion.update(dt, owner, false, 0.0, 0, 70.0, 200.0, "free_flight", rate)
		hidden += dt
	return {"hidden": hidden, "spawn_pos": spawn_pos, "vanish_pos": vanish_pos, "reappear_pos": motion.pos}


func _verify_lunabi_free_flight_profile() -> void:
	var eligible_context := {
		"league_mode": "junior",
		"character_type": "smasher",
	}
	_expect(LingpetCatalog.has_pet("lunabi"), "catalog should recognize Lunabi for owned/runtime adoption")
	_expect(LingpetCatalog.get_hatch_candidates(eligible_context, []).has("lunabi"), "Lunabi should be eligible from the shared unidentified Junior League egg")
	_expect(str(LingpetCatalog.get_motion_style("lunabi")) == "sortie_flight", "Lunabi should use the offscreen sortie-flight companion motion style")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/lunabi_companion_wing_flap.png"), "Lunabi companion move wing-flap sheet should exist")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/lunabi_companion_strike.png"), "Lunabi companion strike sheet should exist")
	_expect(str(LingpetCatalog.get_visual_path("lunabi", "companion_walk")).ends_with("lunabi_companion_wing_flap.png"), "Lunabi runtime walk slot should resolve to the move wing-flap sheet")
	_expect(str(LingpetCatalog.get_visual_path("lunabi", "companion_strike")).ends_with("lunabi_companion_strike.png"), "Lunabi runtime strike slot should resolve to the ball-swoop sheet")

	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["lunabi"]
	owner.lingpet_slots = ["lunabi", "", ""]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	_expect(str(owner.active_lingpet_id) == "lunabi", "owned Lunabi should become the active companion through the slot model")
	_expect(str(owner.lingpet_skill_id) == "lunabi_headbutt", "owned Lunabi should publish its Headbutt skill-card id")
	_expect(str(owner.lingpet_skill_name) == "박치기", "owned Lunabi should publish its Korean Headbutt skill-card name")
	_expect(bool(owner.lingpet_skill_ready), "owned Lunabi Headbutt should start ready")

	var start_pos: Vector2 = owner.lingpet_companion_pos
	var player_lane_y: float = owner.player_pos.y + owner.player_paddle_height * 0.5
	_expect(absf(start_pos.y - player_lane_y) > 20.0, "Lunabi should not start locked to the player-height patrol lane")
	_expect(start_pos.x < 0.0 or start_pos.x > 760.0, "Lunabi should enter mainly from the left or right edge")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("companion_motion_style", "")) == "sortie_flight", "Lunabi snapshot should expose sortie-flight motion style")
	_expect(snapshot.get("companion_free_flight_target", Vector2.ZERO) is Vector2, "Lunabi snapshot should expose a sortie destination")
	_expect(snapshot.get("companion_motion_velocity", Vector2.ZERO) is Vector2, "Lunabi snapshot should expose sortie velocity for save/restore")
	_expect(float(snapshot.get("companion_motion_speed_ratio", 0.0)) > 0.0, "Lunabi sortie should expose a speed ratio for wing-flap cadence")
	_expect(str(snapshot.get("companion_sortie_phase", "")) == "ingress", "Lunabi sortie should start in a fast ingress phase")
	var first_target: Vector2 = snapshot.get("companion_free_flight_target", Vector2.ZERO)
	_expect(first_target.x >= 150.0 and first_target.x <= 610.0 and first_target.y >= 150.0 and first_target.y <= 480.0, "Lunabi ingress should initially aim toward the central playfield background")
	_expect(is_equal_approx(float(snapshot.get("companion_defense_rate", -1.0)), 0.0), "Lunabi should not use Maribo's defensive intercept rate")
	_expect(str(snapshot.get("companion_skill_id", "")) == "lunabi_headbutt", "Lunabi should publish a Headbutt rail-card id")
	_expect(is_equal_approx(float(snapshot.get("companion_skill_cooldown_duration", 0.0)), 30.0), "Lunabi Headbutt should use the 30-second cooldown")
	_expect(is_equal_approx(float(snapshot.get("companion_skill_windup_seconds", 0.0)), 0.45), "Lunabi Headbutt should expose its short charge wind-up")
	_expect(str(snapshot.get("companion_skill_card_path", "")).ends_with("lunabi_headbutt_skillcard_imagegen_v1.png"), "Lunabi Headbutt should expose its imagegen skill-card art")
	_expect(str(snapshot.get("companion_skill_icon_path", "")).ends_with("lunabi_headbutt_skill_icon_imagegen_v1.png"), "Lunabi Headbutt should expose its imagegen skill icon")

	var ingress_speed_ratio: float = float(snapshot.get("companion_motion_speed_ratio", 0.0))
	var saw_entry_deceleration := false
	var saw_central_loiter := false
	var saw_visible_hold := false
	var saw_offscreen_target := false
	var saw_exit_acceleration := false
	var saw_hidden_period := false
	var hidden_pause_seconds := 0.0
	var exit_previous_speed_ratio := -1.0
	for _i in range(180):
		runtime.update(0.15, owner)
		snapshot = runtime.get_snapshot()
		var target: Vector2 = snapshot.get("companion_free_flight_target", Vector2.ZERO)
		var phase := str(snapshot.get("companion_sortie_phase", ""))
		var speed_ratio := float(snapshot.get("companion_motion_speed_ratio", 0.0))
		if (phase == "ingress" or phase == "loiter") and speed_ratio < ingress_speed_ratio - 0.12:
			saw_entry_deceleration = true
		if phase == "loiter" and target.x >= 150.0 and target.x <= 610.0 and target.y >= 150.0 and target.y <= 480.0:
			saw_central_loiter = true
		if phase == "hold" and bool(snapshot.get("companion_visible", true)) and speed_ratio <= 0.10:
			saw_visible_hold = true
		if target.x < 0.0 or target.x > 760.0 or target.y < 0.0 or target.y > 750.0:
			saw_offscreen_target = true
		if phase == "exit":
			if exit_previous_speed_ratio >= 0.0 and speed_ratio > exit_previous_speed_ratio + 0.08:
				saw_exit_acceleration = true
			exit_previous_speed_ratio = speed_ratio
		if not bool(snapshot.get("companion_visible", true)) and float(snapshot.get("companion_patrol_pause", 0.0)) > 0.0:
			saw_hidden_period = true
			hidden_pause_seconds = float(snapshot.get("companion_patrol_pause", 0.0))
			break
	_expect(saw_entry_deceleration, "Lunabi ingress should visibly decelerate before central loitering")
	_expect(saw_central_loiter, "Lunabi should roam around the central background before leaving")
	_expect(saw_visible_hold, "Lunabi should briefly hover/stop before the exit burst")
	_expect(saw_offscreen_target, "Lunabi sortie flight should target outside the screen")
	_expect(saw_exit_acceleration, "Lunabi exit should accelerate into a fast departure")
	_expect(saw_hidden_period, "Lunabi sortie flight should disappear offscreen before the next entry")
	_expect(hidden_pause_seconds >= 6.5, "Lunabi should wait several seconds offscreen before reappearing")

	var motion_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_motion_state.gd")
	_expect(motion_source.find("SORTIE_PHASE_INGRESS") >= 0 and motion_source.find("SORTIE_EXIT_ACCELERATION") >= 0, "Lunabi sortie flight should use phased ingress/loiter/exit acceleration")
	var animator := LingpetCompanionSpriteAnimator.new()
	var idle_frame_a: int = int(animator.get_walk_frame(0.0, 1000, 0.0))
	var idle_frame_b: int = int(animator.get_walk_frame(0.0, 1800, 0.0))
	_expect(idle_frame_a == LingpetCompanionSpriteAnimator.IDLE_FRAME and idle_frame_b == LingpetCompanionSpriteAnimator.IDLE_FRAME, "Companion walk sheet should not keep cycling while the body has zero motion speed")
	var slow_frame: int = int(animator.get_walk_frame(0.0, 1000, 0.20))
	var fast_frame: int = int(animator.get_walk_frame(0.0, 1000, 1.0))
	_expect(fast_frame != slow_frame and fast_frame > slow_frame, "Lunabi wing-flap frame cadence should increase with flight speed")
	var hover_frame_a: int = int(animator.get_walk_frame(1.0, 1000, 0.12))
	var hover_frame_b: int = int(animator.get_walk_frame(1.0, 1400, 0.12))
	_expect(hover_frame_a != hover_frame_b, "Sortie-flight companions should keep cycling wing-flap frames while hovering")
	_expect(LingpetCompanionSpriteAnimator.FLIGHT_FPS_MAX <= 14.0, "Lunabi wing-flap cadence should stay below vibration-speed playback")
	var egg_runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(egg_runtime_source.find("COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO") >= 0, "Sortie-flight runtime should keep a minimum visible wing-flap cadence during hover")
	_expect(egg_runtime_source.find("_get_companion_draw_motion_speed_ratio") >= 0, "Companion draw context should route sortie-flight cadence through a hover-safe helper")

	var forced_companion_pos := Vector2(380.0, 310.0)
	runtime.configure_companion_motion_for_tests(forced_companion_pos, 2, 0.0, false)
	owner.ball_active = true
	owner.ball_pos = forced_companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.01, owner)
	_expect(owner.ball_vel.y < 0.0, "Lunabi overlap should bounce the ball")
	_expect(int(owner.lingpet_companion_contact_count) == 1, "Lunabi overlap should register one companion contact")
	_expect(bool(runtime.is_companion_striking_for_tests()), "Lunabi should play the ball-swoop strike sheet on contact")


func _verify_lunabi_headbutt_skill() -> void:
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png"), "Lunabi Headbutt skill card should ship as an imagegen PNG")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/lunabi_headbutt_skill_icon_imagegen_v1.png"), "Lunabi Headbutt skill icon should ship as an imagegen PNG")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_headbutt_skill.gd"), "Lunabi Headbutt skill module should exist")
	var headbutt_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_headbutt_skill.gd")
	_expect(headbutt_source.find("HOMING_TURN_RATE") >= 0 and headbutt_source.find("_get_homing_target") >= 0, "Lunabi Headbutt should keep steering toward the boss paddle while charging")
	_expect(headbutt_source.find("start_paddle_hit_knockback") >= 0, "Lunabi Headbutt should use the boss AI knockback path for a natural rebound")
	_expect(headbutt_source.find("play_boomerang_hit") >= 0, "Lunabi Headbutt hit should reuse the boomerang boss-hit sound")
	_expect(headbutt_source.find("GUARANTEED_MISS_SPEED := 18.0") >= 0 and headbutt_source.find("MOVING_MISS_MAX_CHANCE") >= 0, "Lunabi Headbutt should avoid guaranteed misses except against extreme paddle movement")
	_expect(headbutt_source.find("COMBO_MAX_COUNT := 3") >= 0 and headbutt_source.find("REPEAT_DELAY_MIN_SECONDS := 1.0") >= 0, "Lunabi Headbutt should support 1-3 dashes with 1-2 second repeat waits")

	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["lunabi"]
	owner.lingpet_slots = ["lunabi", "", ""]
	owner.boss_pos = Vector2(320.0, 25.0)
	owner.boss_vel = 0.0
	owner.ball_active = true
	var runtime: Object = LingpetEggRuntime.new()
	var audio := FakePaddleAudio.new()
	var boss_ai := FakeBossAiState.new()
	var registry := FakeRegistry.new({"game_audio": audio, "boss_ai_state": boss_ai})
	runtime.update(0.0, owner, registry)

	runtime.configure_companion_motion_for_tests(Vector2(-72.0, 245.0), 2, 0.0, false)
	runtime.update(0.0, owner, registry)
	var offscreen_ready_snap: Dictionary = runtime.get_snapshot()
	_expect(not bool(offscreen_ready_snap.get("companion_skill_winding_up", false)), "Lunabi Headbutt should wait while cooldown is ready but Lunabi is still offscreen")

	runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	runtime.update(0.0, owner, registry)
	var windup_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(windup_snap.get("companion_skill_winding_up", false)), "Lunabi Headbutt should telegraph a short wind-up before the charge")
	_expect(not bool(windup_snap.get("headbutt_active", false)), "Lunabi Headbutt should not dash before its wind-up releases")

	runtime.update(0.50, owner, registry)
	var launched_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(launched_snap.get("headbutt_active", false)), "Lunabi Headbutt should launch after its wind-up")
	_expect(bool(launched_snap.get("headbutt_companion_override_active", false)), "Lunabi Headbutt should drive the real companion body during the charge")
	_expect(_vector2_distance(launched_snap.get("companion_pos", Vector2.ZERO), launched_snap.get("headbutt_pos", Vector2.INF)) <= 0.1, "Lunabi Headbutt launch should start from the real companion body position")
	var combo_total := int(launched_snap.get("headbutt_combo_total", 0))
	_expect(combo_total >= 1 and combo_total <= 3, "Lunabi Headbutt should choose a combo count between 1 and 3 per launch")
	_expect(combo_total >= 2, "the Lunabi Headbutt smoke fixture should exercise a repeat-capable combo")
	_expect(int(launched_snap.get("headbutt_combo_index", 0)) == 1, "Lunabi Headbutt should publish the first dash as combo index 1")
	_expect(int(owner.lingpet_skill_trigger_count) == 1, "Lunabi Headbutt should count one launch")
	_expect(owner.lingpet_skill_cooldown > 29.0, "Lunabi Headbutt should enter a 30-second cooldown at launch")
	_expect(not bool(owner.lingpet_skill_ready), "Lunabi Headbutt should not be ready during cooldown")

	var boss_x_before := owner.boss_pos.x
	runtime.update(0.05, owner, registry)
	var charge_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(charge_snap.get("headbutt_active", false)), "Lunabi Headbutt should stay active while the body is still charging")
	_expect(_vector2_distance(charge_snap.get("companion_pos", Vector2.ZERO), charge_snap.get("headbutt_pos", Vector2.INF)) <= 0.1, "Lunabi's actual companion body should be the charging Headbutt position")
	for _i in range(17):
		runtime.update(0.05, owner, registry)
		if int(runtime.get_headbutt_hit_count_for_tests()) > 0:
			break
	var hit_snap: Dictionary = runtime.get_snapshot()
	_expect(int(runtime.get_headbutt_hit_count_for_tests()) == 1, "Lunabi Headbutt should hit a stationary boss paddle")
	_expect(str(hit_snap.get("headbutt_last_result", "")) == "hit", "Lunabi Headbutt snapshot should publish the last hit result")
	_expect(_vector2_distance(hit_snap.get("companion_pos", Vector2.ZERO), hit_snap.get("headbutt_companion_pos", Vector2.INF)) <= 0.1, "Lunabi's actual companion body should remain at the Headbutt impact position")
	_expect(bool(hit_snap.get("headbutt_repeat_wait_active", false)), "Lunabi Headbutt should wait on screen before a repeat dash when the combo rolled 2+ hits")
	_expect(float(hit_snap.get("headbutt_repeat_wait_timer", 0.0)) >= 0.95 and float(hit_snap.get("headbutt_repeat_wait_timer", 0.0)) <= 2.0, "Lunabi Headbutt repeat wait should be between 1 and 2 seconds")
	_expect(int(hit_snap.get("headbutt_combo_remaining", 0)) == combo_total - 1, "Lunabi Headbutt should publish remaining repeat dashes after the first impact")
	var repeat_impact_pos: Vector2 = hit_snap.get("headbutt_companion_pos", Vector2.ZERO)
	var repeat_recoil_anchor: Vector2 = hit_snap.get("headbutt_repeat_recoil_anchor_pos", Vector2.ZERO)
	_expect(repeat_recoil_anchor.y > repeat_impact_pos.y + 60.0, "Lunabi Headbutt repeat anchor should pull the body downward before the next dash")
	_expect(absf((owner.boss_pos.x - boss_x_before) - 24.0) <= 1.0, "Lunabi Headbutt should apply only a small immediate impact nudge before the ongoing recoil")
	_expect(boss_ai.knockback_calls == 1, "Lunabi Headbutt should hand the continuing knockback to boss_ai_state")
	_expect(boss_ai.last_velocity > 0.0 and boss_ai.last_frames >= 30.0 and boss_ai.last_decay >= 0.90, "Lunabi Headbutt should use a longer decaying boss knockback so recovery is not instant")
	_expect(_estimated_knockback_distance(24.0, boss_ai.last_velocity, boss_ai.last_frames, boss_ai.last_decay) >= 140.0, "Lunabi Headbutt nudge plus decaying recoil should travel about 150px")
	_expect(audio.boomerang_hits == 1, "Lunabi Headbutt hit should use the boomerang boss-hit sound")
	_expect(audio.paddle_hits == 0, "Lunabi Headbutt hit should not use the generic paddle-hit sound when boomerang hit audio is available")
	runtime.update(minf(0.45, float(hit_snap.get("headbutt_repeat_wait_timer", 0.0)) * 0.5), owner, registry)
	var recoil_snap: Dictionary = runtime.get_snapshot()
	var recoil_pos: Vector2 = recoil_snap.get("headbutt_companion_pos", Vector2.ZERO)
	_expect(bool(recoil_snap.get("headbutt_repeat_wait_active", false)), "Lunabi Headbutt should still be in repeat wait while recoiling downward")
	_expect(not bool(recoil_snap.get("headbutt_active", false)), "Lunabi Headbutt should not start the repeat dash until the recoil wait finishes")
	_expect(recoil_pos.y > repeat_impact_pos.y + 24.0, "Lunabi Headbutt body should drop downward to build momentum before repeating")
	_expect(absf(recoil_pos.x - repeat_impact_pos.x) <= 1.0, "Lunabi Headbutt recoil should be primarily a y-axis pullback")
	runtime.update(minf(0.38, maxf(0.0, float(recoil_snap.get("headbutt_repeat_wait_timer", 0.0)) - 0.12)), owner, registry)
	var loiter_snap: Dictionary = runtime.get_snapshot()
	var loiter_pos: Vector2 = loiter_snap.get("headbutt_companion_pos", Vector2.ZERO)
	_expect(bool(loiter_snap.get("headbutt_repeat_wait_active", false)), "Lunabi Headbutt should keep moving during the repeat wait instead of freezing at the recoil anchor")
	_expect(bool(loiter_snap.get("headbutt_repeat_loiter_active", false)), "Lunabi Headbutt should enter a natural loiter after the downward recoil")
	_expect(_vector2_distance(loiter_pos, recoil_pos) > 3.0, "Lunabi Headbutt repeat wait should drift like normal flight before the next dash")
	runtime.update(float(loiter_snap.get("headbutt_repeat_wait_timer", 0.0)) + 0.05, owner, registry)
	var repeat_launch_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(repeat_launch_snap.get("headbutt_active", false)), "Lunabi Headbutt should launch another dash after the repeat wait")
	_expect(int(repeat_launch_snap.get("headbutt_combo_index", 0)) == 2, "Lunabi Headbutt should advance the combo index on the repeat dash")
	_expect(bool(runtime.is_companion_striking_for_tests()), "Lunabi Headbutt repeat dash should restart the companion strike animation")
	_expect(repeat_launch_snap.get("headbutt_pos", Vector2.ZERO).y > repeat_impact_pos.y + 60.0, "Lunabi Headbutt repeat dash should start from the lower recoil position")
	_expect(_vector2_distance(repeat_launch_snap.get("headbutt_pos", Vector2.ZERO), repeat_recoil_anchor) > 3.0, "Lunabi Headbutt repeat dash should launch from the moving loiter position, not a frozen anchor")

	var tracking_owner := FakeOwner.new()
	tracking_owner.lingpet_owned_pet_ids = ["lunabi"]
	tracking_owner.lingpet_slots = ["lunabi", "", ""]
	tracking_owner.boss_pos = Vector2(320.0, 25.0)
	tracking_owner.boss_vel = 3.0
	tracking_owner.ball_active = true
	var tracking_runtime: Object = LingpetEggRuntime.new()
	var tracking_audio := FakePaddleAudio.new()
	var tracking_registry := FakeRegistry.new({"game_audio": tracking_audio, "boss_ai_state": FakeBossAiState.new()})
	tracking_runtime.update(0.0, tracking_owner, tracking_registry)
	tracking_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	tracking_runtime.update(0.0, tracking_owner, tracking_registry)
	tracking_runtime.update(0.50, tracking_owner, tracking_registry)
	for _i in range(20):
		tracking_runtime.update(0.05, tracking_owner, tracking_registry)
		if int(tracking_runtime.get_headbutt_hit_count_for_tests()) > 0 or int(tracking_runtime.get_headbutt_miss_count_for_tests()) > 0:
			break
	_expect(int(tracking_runtime.get_headbutt_hit_count_for_tests()) == 1, "Lunabi Headbutt should reliably hit a moderately moving boss paddle")
	_expect(int(tracking_runtime.get_headbutt_miss_count_for_tests()) == 0, "moderate boss movement should not force a Lunabi Headbutt miss")

	var miss_owner := FakeOwner.new()
	miss_owner.lingpet_owned_pet_ids = ["lunabi"]
	miss_owner.lingpet_slots = ["lunabi", "", ""]
	miss_owner.boss_pos = Vector2(320.0, 25.0)
	miss_owner.boss_vel = 20.0
	miss_owner.ball_active = true
	var miss_runtime: Object = LingpetEggRuntime.new()
	var miss_audio := FakePaddleAudio.new()
	var miss_registry := FakeRegistry.new({"game_audio": miss_audio})
	miss_runtime.update(0.0, miss_owner, miss_registry)
	miss_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	miss_runtime.update(0.0, miss_owner, miss_registry)
	miss_runtime.update(0.50, miss_owner, miss_registry)
	var miss_boss_x_before := miss_owner.boss_pos.x
	for _i in range(24):
		miss_runtime.update(0.05, miss_owner, miss_registry)
		if int(miss_runtime.get_headbutt_miss_count_for_tests()) > 0:
			break
	var miss_snap: Dictionary = miss_runtime.get_snapshot()
	_expect(int(miss_runtime.get_headbutt_miss_count_for_tests()) == 1, "Lunabi Headbutt should still be able to miss an extremely fast-moving boss paddle")
	_expect(str(miss_snap.get("headbutt_last_result", "")) == "miss", "Lunabi Headbutt snapshot should publish the last miss result")
	_expect(str(miss_snap.get("headbutt_last_miss_reason", "")) == "moving_target", "Lunabi Headbutt miss should report the moving-target reason")
	_expect(is_equal_approx(miss_owner.boss_pos.x, miss_boss_x_before), "missed Lunabi Headbutt should not knock back the boss paddle")
	_expect(miss_audio.boomerang_hits == 0, "missed Lunabi Headbutt should not play the boomerang boss-hit sound")
	_expect(miss_audio.paddle_hits == 0, "missed Lunabi Headbutt should not play the paddle-hit fallback sound")


func _verify_koyora_puppet_grab_skill() -> void:
	# 꼭두각시 조종 (Puppet Control) — ported from 연화 (maria) in the original.
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_puppet_grab_skill.gd"), "Koyora puppet-grab skill module should exist")
	var src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_puppet_grab_skill.gd")
	_expect(
		src.find("PHASE_EXTENDING") >= 0 and src.find("PHASE_PULLING") >= 0 and src.find("PHASE_KISSING") >= 0 and src.find("PHASE_RETURNING") >= 0,
		"꼭두각시 조종 should keep the original 4-phase extend/pull/kiss/return machine"
	)
	_expect(src.find("ball_vel") < 0 and src.find("ball_pos") < 0, "꼭두각시 조종 is pure paddle CC — it must not read or write the ball")
	_expect(src.find("lingpet_puppet_grab_active") >= 0, "꼭두각시 조종 should flag the owner so the boss is held + uncollidable")
	_expect(src.find("play_lingpet_puppet_grab_pull") >= 0, "꼭두각시 조종 should play the original grab.wav on the pull phase edge")
	_expect(src.find("play_lingpet_puppet_grab_kiss") >= 0, "꼭두각시 조종 should play the original kissing.wav on the kiss phase edge")

	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/puppet_grab_tentacle.wav"), "Godot should ship the original Puppet Control tentacle cast sound")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/puppet_grab.wav"), "Godot should ship the original Puppet Control grab sound")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/puppet_grab_kissing.wav"), "Godot should ship the original Puppet Control kissing sound")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/puppet_grab_tentacle.wav") != null, "Puppet Control tentacle cast sound should load as an AudioStream")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/puppet_grab.wav") != null, "Puppet Control grab sound should load as an AudioStream")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/puppet_grab_kissing.wav") != null, "Puppet Control kissing sound should load as an AudioStream")
	var game_audio_src: String = FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(
		game_audio_src.find("play_lingpet_puppet_grab_cast") >= 0
			and game_audio_src.find("play_lingpet_puppet_grab_pull") >= 0
			and game_audio_src.find("play_lingpet_puppet_grab_kiss") >= 0,
		"game_audio should expose the three original Puppet Control SFX calls"
	)
	var skill_host_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	_expect(
		skill_host_src.find("_play_puppet_grab_cast_feedback") >= 0
			and skill_host_src.find("play_lingpet_puppet_grab_cast") >= 0,
		"skill runtime host should use the original tentacle cast SFX instead of generic active-item feedback"
	)

	# Boss-side plumbing: the grab only works if the freeze + collision-skip wiring is present.
	var ai_src: String = FileAccess.get_file_as_string("res://scripts/ai/boss_ai_state.gd")
	_expect(ai_src.find("lingpet_puppet_grab_active") >= 0, "boss_ai_state should freeze the boss while it is puppeted")
	var ctx_src: String = FileAccess.get_file_as_string("res://scripts/core/battle_update_boss_ai_context_builder.gd")
	_expect(ctx_src.find("lingpet_puppet_grab_active") >= 0, "boss AI context should publish the puppet-grab flag")
	var det_src: String = FileAccess.get_file_as_string("res://scripts/ball/ball_motion_collision_detector.gd")
	_expect(det_src.find("lingpet_puppet_grab_active") >= 0, "ball collision detector should skip the boss while it is puppeted")

	# --- Live grab through the runtime: arm -> launch -> pull -> kiss -> return -> release.
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["koyora"]
	owner.lingpet_slots = ["koyora", "", ""]
	owner.boss_pos = Vector2(330.0, 25.0)
	owner.boss_paddle_width = 100.0
	owner.boss_hitbox_height = 40.0
	owner.boss_vel = 0.0
	owner.ball_active = true
	var boss_original: Vector2 = owner.boss_pos
	var runtime: Object = LingpetEggRuntime.new()
	var puppet_audio := FakePaddleAudio.new()
	var registry := FakeRegistry.new({"game_audio": puppet_audio})
	runtime.update(0.0, owner, registry)
	runtime.configure_companion_motion_for_tests(Vector2(380.0, 600.0), 2, 0.0, false)
	runtime.update(0.0, owner, registry)
	var windup_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(windup_snap.get("companion_skill_winding_up", false)), "Koyora 꼭두각시 조종 should telegraph a wind-up before grabbing")
	_expect(not bool(windup_snap.get("puppet_grab_active", false)), "Koyora 꼭두각시 조종 should not grab before its wind-up releases")
	_expect(not bool(owner.lingpet_puppet_grab_active), "the boss should not be flagged held during the wind-up")

	runtime.update(0.85, owner, registry)  # exceed the 0.8s wind-up
	var launched: Dictionary = runtime.get_snapshot()
	_expect(bool(launched.get("puppet_grab_active", false)), "Koyora 꼭두각시 조종 should launch after its wind-up")
	# Snapshot lock-on: the freeze flag is NOT set during EXTENDING. The boss is
	# free to dodge during the 0.7s extend window — only a confirmed HIT at the
	# end of EXTENDING commits the grab. This is what makes a MISS possible.
	_expect(not bool(owner.lingpet_puppet_grab_active), "EXTENDING must leave the boss free so it has a real chance to dodge before the strings arrive")
	_expect(int(launched.get("puppet_grab_phase", -1)) == 0, "the grab should open in the extending phase")
	_expect(bool(launched.get("puppet_grab_companion_override_active", false)), "Koyora should stay pinned at her cast spot while puppeteering")
	_expect(int(runtime.get_puppet_grab_count_for_tests()) == 1, "the grab should count one launch")
	_expect(owner.lingpet_skill_cooldown > 20.0, "꼭두각시 조종 should enter its long cooldown at launch (25s)")
	_expect(puppet_audio.puppet_grab_cast_count == 1, "launching Puppet Control should play the original tentacle cast sound once")
	_expect(puppet_audio.puppet_grab_pull_count == 0 and puppet_audio.puppet_grab_kiss_count == 0, "Puppet Control should not play pull/kiss sounds before their phase edges")

	# Extending phase: FakeOwner has no AI so the boss naturally stays at its
	# launch position; that gives us the HIT path on the phase boundary below.
	runtime.update(0.3, owner, registry)
	var ext: Dictionary = runtime.get_snapshot()
	_expect(int(ext.get("puppet_grab_phase", -1)) == 0, "the boss should still be extending at 0.3s")
	_expect(_vector2_distance(owner.boss_pos, boss_original) <= 0.01, "FakeOwner has no AI driving the boss so it stays put during extend (giving us a HIT in this test path)")
	_expect(not bool(owner.lingpet_puppet_grab_active), "the boss must NOT be flagged held mid-EXTEND — the freeze only commits on HIT")
	_expect(puppet_audio.puppet_grab_pull_count == 0 and puppet_audio.puppet_grab_kiss_count == 0, "extending strings should remain silent after the cast sound")

	# Pulling phase: HIT at the extend boundary commits the grab and the boss is
	# dragged downward toward Koyora.
	runtime.update(0.5, owner, registry)  # +0.5 -> 0.8s total -> into PULLING
	var pull: Dictionary = runtime.get_snapshot()
	_expect(int(pull.get("puppet_grab_phase", -1)) == 1, "the boss should be pulling once the extend window ends")
	_expect(bool(owner.lingpet_puppet_grab_active), "HIT-transition into PULLING must NOW flag the owner so the boss is frozen + uncollidable")
	_expect(owner.boss_pos.y > boss_original.y + 2.0, "the boss should be dragged downward during the pull")
	_expect(puppet_audio.puppet_grab_pull_count == 1, "entering the pull phase should play the original grab.wav once")
	_expect(puppet_audio.puppet_grab_kiss_count == 0, "the kiss sound should wait until the kiss phase edge")
	_expect(puppet_audio.puppet_grab_miss_count == 0, "a HIT path should never play the miss sound")

	# Kissing phase: the boss is pinned at the kiss point and the kiss registers.
	runtime.update(1.5, owner, registry)  # 2.3s total -> into KISSING
	var kiss: Dictionary = runtime.get_snapshot()
	_expect(int(kiss.get("puppet_grab_phase", -1)) == 2, "the boss should be kissing after the pull completes")
	_expect(int(runtime.get_puppet_grab_kiss_count_for_tests()) == 1, "the kiss should register once the boss is pulled in")
	var kiss_center: Vector2 = kiss.get("puppet_grab_kiss_center", Vector2.ZERO)
	var boss_center: Vector2 = owner.boss_pos + Vector2(50.0, 20.0)
	_expect(_vector2_distance(boss_center, kiss_center) <= 0.5, "the boss should be pinned at the kiss point during the kiss")
	_expect(kiss_center.y < boss_original.y + 700.0 and kiss_center.y > boss_original.y, "the kiss point should sit in front of Koyora, below the boss origin")
	_expect(puppet_audio.puppet_grab_kiss_count == 1, "entering the kiss phase should play the original kissing.wav once")

	# Return phase completes: boss restored to exact origin, owner flag released.
	runtime.update(1.5, owner, registry)  # 3.8s total > 3.616s -> finished
	var done: Dictionary = runtime.get_snapshot()
	_expect(not bool(done.get("puppet_grab_active", false)), "꼭두각시 조종 should finish after the return phase")
	_expect(not bool(owner.lingpet_puppet_grab_active), "finishing the grab should release the owner boss-freeze flag")
	_expect(_vector2_distance(owner.boss_pos, boss_original) <= 0.01, "the boss must be returned to its exact original position")

	# --- Ownerless HIT edge: if the HIT transition happens without an owner,
	# keep the pending pin and apply it on the first owner-backed update instead
	# of losing the owner write for one frame.
	var pending_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var pending_owner := FakeOwner.new()
	pending_owner.boss_pos = Vector2(330.0, 25.0)
	pending_owner.boss_paddle_width = 100.0
	pending_owner.boss_hitbox_height = 40.0
	_expect(bool(pending_skill.launch(Vector2(380.0, 600.0), pending_owner, {})), "pending-pin launch should succeed")
	pending_skill.update(0.75, null, registry)
	var pending_snap: Dictionary = pending_skill.get_snapshot()
	_expect(int(pending_snap.get("puppet_grab_phase", -1)) == 1, "ownerless HIT transition should still enter PULLING")
	_expect(bool(pending_snap.get("puppet_grab_pending_owner", false)), "ownerless HIT transition should keep a pending owner pin")
	_expect(not bool(pending_snap.get("puppet_grab_owns_boss", false)), "ownerless HIT transition should not claim ownership before writing the owner")
	_expect(not bool(pending_owner.lingpet_puppet_grab_active), "ownerless HIT transition should not mutate a missing owner")
	pending_skill.update(0.0, pending_owner, registry)
	_expect(bool(pending_owner.lingpet_puppet_grab_active), "next owner-backed update should apply the pending puppet grab immediately")
	_expect(bool(pending_skill.get_snapshot().get("puppet_grab_owns_boss", false)), "pending pin should become real ownership after owner write")
	pending_skill.cancel(pending_owner)
	_expect(not bool(pending_owner.lingpet_puppet_grab_active), "pending-pin cleanup should release the owner flag")

	# --- Direct cleanup case: cancelling mid-grab must release the boss with no leak.
	var skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var cowner := FakeOwner.new()
	cowner.boss_pos = Vector2(330.0, 25.0)
	cowner.boss_paddle_width = 100.0
	cowner.boss_hitbox_height = 40.0
	_expect(bool(skill.launch(Vector2(380.0, 600.0), cowner, {})), "puppet-grab launch should succeed with a valid owner")
	skill.update(0.9, cowner)  # into the pull
	_expect(bool(cowner.lingpet_puppet_grab_active), "the grab should hold the boss while active")
	_expect(cowner.boss_pos.y > 25.0, "the grab should have started dragging the boss down")
	skill.cancel(cowner)
	_expect(not bool(cowner.lingpet_puppet_grab_active), "cancel should release the boss-freeze flag")
	_expect(not bool(skill.is_active()), "cancel should end the grab")
	_expect(_vector2_distance(cowner.boss_pos, Vector2(330.0, 25.0)) <= 0.01, "cancel should snap the boss back to its origin")

	# --- Round-end leak regression: the round cleanup deps carry NO owner, so
	# cancel() runs owner-less mid-grab. The boss must NOT stay dragged/frozen into
	# the next round — the next update() with the owner must restore it.
	var leak_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var lowner := FakeOwner.new()
	lowner.boss_pos = Vector2(330.0, 25.0)
	lowner.boss_paddle_width = 100.0
	lowner.boss_hitbox_height = 40.0
	_expect(bool(leak_skill.launch(Vector2(380.0, 600.0), lowner, {})), "leak-case launch should succeed")
	leak_skill.update(0.9, lowner)  # into the pull -> boss dragged down, flag held
	_expect(bool(lowner.lingpet_puppet_grab_active) and lowner.boss_pos.y > 25.0, "grab should be holding the boss mid-pull")
	leak_skill.cancel(null)  # round-end cleanup WITHOUT owner (reproduces the bug trigger)
	_expect(bool(leak_skill.get_snapshot().get("puppet_grab_owns_boss", false)), "owner-less cancel should defer the release, not drop ownership")
	leak_skill.update(0.0, lowner)  # next round's first lingpet update HAS the owner
	_expect(not bool(lowner.lingpet_puppet_grab_active), "deferred release must clear the stuck boss-freeze flag next round")
	_expect(_vector2_distance(lowner.boss_pos, Vector2(330.0, 25.0)) <= 0.01, "deferred release must restore the boss y to the top, not leave it dragged")
	_expect(not bool(leak_skill.is_active()) and not bool(leak_skill.get_snapshot().get("puppet_grab_owns_boss", false)), "after the deferred release the grab owns nothing")

	# --- Full round-reset regression: reset_ball builds its config before cleanup,
	# so its returned boss_pos must not preserve the dragged Y after cleanup releases Koyora.
	var round_owner := FakeOwner.new()
	round_owner.lingpet_owned_pet_ids = ["koyora"]
	round_owner.lingpet_slots = ["koyora", "", ""]
	round_owner.boss_pos = Vector2(330.0, 25.0)
	round_owner.boss_paddle_width = 100.0
	round_owner.boss_hitbox_height = 40.0
	round_owner.ball_active = true
	var round_runtime: Object = LingpetEggRuntime.new()
	var round_registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new()})
	round_runtime.update(0.0, round_owner, round_registry)
	round_runtime.configure_companion_motion_for_tests(Vector2(380.0, 600.0), 2, 0.0, false)
	round_runtime.update(0.0, round_owner, round_registry)
	round_runtime.update(0.85, round_owner, round_registry)
	round_runtime.update(0.9, round_owner, round_registry)
	var dragged_pos: Vector2 = round_owner.boss_pos
	_expect(bool(round_owner.lingpet_puppet_grab_active) and dragged_pos.y > 25.0, "full reset setup should have Koyora dragging the boss before reset_ball")
	var reset_result: Dictionary = BallRoundController.new().reset_ball({
		"width": 760.0,
		"height": 750.0,
		"player_pos": round_owner.player_pos,
		"boss_pos": dragged_pos,
		"player_y": round_owner.player_pos.y,
		"boss_y": 25.0,
		"player_paddle_width": round_owner.player_paddle_width,
		"boss_paddle_width": round_owner.boss_paddle_width,
	}, {
		"lingpet_egg_runtime": round_runtime,
		"owner": round_owner,
	}, {})
	var reset_boss_pos: Vector2 = reset_result.get("boss_pos", Vector2.ZERO)
	_expect(not bool(round_owner.lingpet_puppet_grab_active), "reset_ball cleanup should release Koyora's boss-freeze flag")
	_expect(is_equal_approx(reset_boss_pos.y, 25.0), "reset_ball result must reset boss Y instead of replaying the pre-cleanup dragged Y")

	# --- MISS-path regression: if the boss leaves the predicted lock-on point
	# before the strings arrive at end of EXTENDING, the grab MUST whiff. No
	# freeze flag, no PULL / KISS / RETURN, no boss displacement — just a brief
	# MISS feedback phase and a clean skill end.
	var miss_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var miss_audio_for_skill := FakePaddleAudio.new()
	var miss_registry := FakeRegistry.new({"game_audio": miss_audio_for_skill})
	var miss_owner := FakeOwner.new()
	miss_owner.boss_pos = Vector2(330.0, 25.0)
	miss_owner.boss_paddle_width = 100.0
	miss_owner.boss_hitbox_height = 40.0
	var miss_origin := Vector2(380.0, 600.0)
	_expect(bool(miss_skill.launch(miss_origin, miss_owner, {})), "MISS-case launch should succeed")
	_expect(not bool(miss_owner.lingpet_puppet_grab_active), "the boss must not be flagged held during EXTENDING — that is what makes a dodge possible")
	miss_skill.update(0.3, miss_owner, miss_registry)  # 0.3s into EXTEND (still 0.4s left)
	_expect(int(miss_skill.get_snapshot().get("puppet_grab_phase", -1)) == 0, "0.3s into extend should still be EXTENDING")
	_expect(not bool(miss_owner.lingpet_puppet_grab_active), "still no freeze mid-EXTEND")
	# Simulate the boss tracking the ball across the field and leaving the
	# predicted lock-on point before the strings arrive.
	miss_owner.boss_pos = Vector2(600.0, 25.0)  # ~270px right of the launch position
	miss_skill.update(0.5, miss_owner, miss_registry)  # +0.5 -> past 0.7s extend → HIT/MISS check fires
	var miss_snap: Dictionary = miss_skill.get_snapshot()
	_expect(int(miss_snap.get("puppet_grab_phase", -1)) == 4, "boss outside hit tolerance at extend end should send the skill to PHASE_MISSING")
	_expect(bool(miss_snap.get("puppet_grab_missed", false)), "MISS should be flagged on the snapshot")
	_expect(int(miss_snap.get("puppet_grab_miss_count", -1)) == 1, "MISS should register exactly once")
	_expect(not bool(miss_owner.lingpet_puppet_grab_active), "a MISS must NEVER set the boss freeze flag")
	_expect(_vector2_distance(miss_owner.boss_pos, Vector2(600.0, 25.0)) <= 0.01, "a MISS must not displace the boss")
	_expect(not bool(miss_snap.get("puppet_grab_owns_boss", false)), "a MISS must not take ownership of the boss")
	_expect(miss_audio_for_skill.puppet_grab_pull_count == 0, "MISS path must not play the pull (grab.wav) sound")
	_expect(miss_audio_for_skill.puppet_grab_kiss_count == 0, "MISS path must not play the kiss (kissing.wav) sound")
	_expect(miss_audio_for_skill.puppet_grab_miss_count == 1, "MISS path should play the dedicated miss feedback once")
	# Let the MISS feedback fade out — skill ends naturally with no leak.
	miss_skill.update(0.5, miss_owner, miss_registry)  # 0.5s > MISS_SECONDS (0.45)
	_expect(not bool(miss_skill.is_active()), "MISS phase should auto-end after MISS_SECONDS")
	_expect(not bool(miss_owner.lingpet_puppet_grab_active), "MISS end leaves the boss free")
	_expect(_vector2_distance(miss_owner.boss_pos, Vector2(600.0, 25.0)) <= 0.01, "MISS end must not teleport the boss anywhere")

	# --- MISS hit-tolerance edge case: a small dodge inside the tolerance window
	# should still HIT (boss center within ~58px of launch position for a 100px
	# paddle = HIT_TOLERANCE_PAD(8) + boss_size.x*0.5(50)).
	var grazed_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var grazed_audio := FakePaddleAudio.new()
	var grazed_registry := FakeRegistry.new({"game_audio": grazed_audio})
	var grazed_owner := FakeOwner.new()
	grazed_owner.boss_pos = Vector2(330.0, 25.0)
	grazed_owner.boss_paddle_width = 100.0
	grazed_owner.boss_hitbox_height = 40.0
	_expect(bool(grazed_skill.launch(Vector2(380.0, 600.0), grazed_owner, {})), "edge-case launch should succeed")
	grazed_owner.boss_pos = Vector2(370.0, 25.0)  # 40px right — well inside tolerance
	grazed_skill.update(0.75, grazed_owner, grazed_registry)
	var grazed_snap: Dictionary = grazed_skill.get_snapshot()
	_expect(int(grazed_snap.get("puppet_grab_phase", -1)) == 1, "small dodge inside tolerance should still HIT and enter PULLING")
	_expect(not bool(grazed_snap.get("puppet_grab_missed", false)), "small dodge must not register a MISS")
	_expect(bool(grazed_owner.lingpet_puppet_grab_active), "small dodge should still flip the freeze flag on HIT")
	_expect(grazed_audio.puppet_grab_pull_count == 1, "small dodge HIT path should play the pull sound")
	_expect(grazed_audio.puppet_grab_miss_count == 0, "small dodge HIT path should not play the miss sound")


func _verify_companion_click_reaction() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(not bool(runtime.try_begin_companion_click_reaction(Vector2(40.0, 40.0))), "companion click reaction should ignore clicks outside the companion tap zone")
	_expect(bool(runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0))), "companion click reaction should start from the companion tap zone")
	_expect(bool(runtime.is_companion_click_reaction_active()), "companion click reaction should report active after a valid click")
	runtime.update(5.0, owner)
	_expect(not bool(runtime.is_companion_click_reaction_active()), "companion click reaction should automatically finish after one popup pass")

	var volty_owner := FakeOwner.new()
	volty_owner.lingpet_owned_pet_ids = ["volty"]
	volty_owner.lingpet_slots = ["volty", "", ""]
	var volty_runtime: Object = LingpetEggRuntime.new()
	var volty_audio := FakePaddleAudio.new()
	var volty_registry := FakeRegistry.new({"game_audio": volty_audio})
	volty_runtime.update(0.0, volty_owner, volty_registry)
	volty_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(bool(volty_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0), volty_registry)), "Volty companion click reaction should start from the companion tap zone")
	_expect(volty_audio.lingpet_click_reaction_pet_ids == ["volty"], "Volty companion click reaction should request the Volty voice once")
	_expect(volty_audio.lingpet_acquire_click_backing_count == 0, "in-battle companion clicks should not play the acquisition-screen backing SFX")
	_expect(not bool(volty_runtime.try_begin_companion_click_reaction(Vector2(40.0, 40.0), volty_registry)), "active Volty click reaction should still ignore clicks outside the companion tap zone")
	_expect(bool(volty_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0), volty_registry)), "active Volty click reaction should consume another companion tap without restarting the popup")
	_expect(volty_audio.lingpet_click_reaction_pet_ids == ["volty", "volty"], "active Volty companion taps should replay the click voice without stacking animation state")
	_expect(volty_audio.lingpet_acquire_click_backing_count == 0, "repeated in-battle companion taps should still not play the acquisition-screen backing SFX")

	var milkring_owner := FakeOwner.new()
	milkring_owner.lingpet_owned_pet_ids = ["milkring"]
	milkring_owner.lingpet_slots = ["milkring", "", ""]
	var milkring_runtime: Object = LingpetEggRuntime.new()
	var milkring_audio := FakePaddleAudio.new()
	var milkring_registry := FakeRegistry.new({"game_audio": milkring_audio})
	milkring_runtime.update(0.0, milkring_owner, milkring_registry)
	milkring_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(bool(milkring_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0), milkring_registry)), "Milkring companion click reaction should start from the companion tap zone")
	_expect(milkring_audio.lingpet_click_reaction_pet_ids == ["milkring"], "Milkring companion click reaction should request the Milkring voice once")

	var red_dragon_owner := FakeOwner.new()
	red_dragon_owner.lingpet_owned_pet_ids = ["red_dragon"]
	red_dragon_owner.lingpet_slots = ["red_dragon", "", ""]
	var red_dragon_runtime: Object = LingpetEggRuntime.new()
	var red_dragon_audio := FakePaddleAudio.new()
	var red_dragon_registry := FakeRegistry.new({"game_audio": red_dragon_audio})
	red_dragon_runtime.update(0.0, red_dragon_owner, red_dragon_registry)
	red_dragon_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(bool(red_dragon_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0), red_dragon_registry)), "Red Dragon companion click reaction should start from the companion tap zone")
	_expect(red_dragon_audio.lingpet_click_reaction_pet_ids == ["red_dragon"], "Red Dragon companion click reaction should request the Red Dragon voice once")

	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var click_reaction_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
	var profile_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_profile.gd")
	var visual_cache_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	_expect(runtime_source.find("lingpet_companion_click_reaction_state.gd") >= 0, "lingpet runtime should delegate click-reaction timing state")
	_expect(runtime_source.find("_draw_companion_click_reaction") < 0, "lingpet runtime should delegate click-reaction sheet drawing to the click-reaction module")
	_expect(click_reaction_source.find("PREWARM_VISUAL_KEYS") >= 0, "click-reaction module should own the focused visual prewarm keys")
	_expect(click_reaction_source.find("can_start_at") >= 0 and click_reaction_source.find("CLICK_ZONE_HALF_WIDTH") >= 0, "click-reaction module should own the companion tap-zone math")
	_expect(click_reaction_source.find("draw_texture_rect_region") >= 0, "click-reaction module should own the popup sheet frame draw")
	_expect(click_reaction_source.find("DEFAULT_VIEW_HEIGHT := 82.0") >= 0, "click-reaction module should fall back to the same small size as the SD walk sprite")
	_expect(click_reaction_source.find("CENTER_OFFSET_Y := -6.0") >= 0, "click-reaction module should align to the SD walk sprite center instead of floating above it")
	_expect(click_reaction_source.find("RUNTIME_VISUAL_KEY := \"companion_click_reaction_anim\"") >= 0, "click-reaction module should use the downscaled in-battle visual key")
	_expect(click_reaction_source.find("large popup") < 0, "click-reaction module should no longer describe or draw a large in-battle popup")
	_expect(profile_source.find("prewarm_visual_keys") >= 0, "lingpet current profile should support focused visual prewarm keys for large optional sheets")
	_expect(profile_source.find("get_cached_visual_texture") >= 0, "lingpet current profile should expose cached-only texture lookup for click-reaction draw frames")
	_expect(visual_cache_source.find("prewarm_pet_key_threaded_step") >= 0 and visual_cache_source.find("ProjectResourceLoader.prewarm_texture_threaded_step") >= 0, "lingpet visual cache should thread-prewarm large optional click-reaction sheets")
	_expect(runtime_source.find("_prewarm_click_reaction_visual_step") >= 0, "lingpet runtime should spread click-reaction visual prewarm over companion updates")
	_expect(runtime_source.find("LingpetCompanionClickReactionState.RUNTIME_VISUAL_KEY") >= 0, "lingpet click-reaction draw should use the dedicated in-battle visual key")
	_expect(runtime_source.find("_get_current_cached_visual_texture(\"click_reaction_anim\", null)") < 0, "lingpet click-reaction draw should not use the full-size cut-in/result sheet key")
	_expect(runtime_source.find("_get_current_visual_texture(\"click_reaction_anim\", null)") < 0, "lingpet click-reaction draw should not synchronously load the large sheet")
	_expect(
		LingpetEggRuntime.CLICK_REACTION_TEXTURE_PREWARM_MAX_MSEC <= ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC
			and LingpetEggRuntime.CLICK_REACTION_TEXTURE_PREWARM_MAX_POLLS <= ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
		"lingpet in-battle click-reaction prewarm should keep the short threaded guard instead of a long live-gameplay load"
	)
	_expect(_lingpet_runtime_click_sheet_is_small("maribo"), "Maribo in-battle click-reaction sheet should be the downscaled companion sheet")
	_expect(_lingpet_runtime_click_sheet_is_small("lunabi"), "Lunabi in-battle click-reaction sheet should be the downscaled companion sheet")
	_expect(runtime_source.find("_get_companion_click_reaction_draw_size") >= 0, "lingpet runtime should size click-reaction Live2D through a focused helper")
	_expect(runtime_source.find("click_reaction_draw_size") >= 0 and runtime_source.find("companion_walk_draw_size") >= 0, "lingpet runtime should support a per-pet click-reaction size override before falling back to SD walk draw size")
	_expect(runtime_source.find("if not click_reaction_visible") >= 0, "lingpet runtime should hide the base SD companion while the click-reaction Live2D is visible")
	_expect(input_source.find("try_begin_companion_click_reaction") >= 0, "battle input should route playfield companion clicks to the lingpet runtime")
	_expect(input_source.find("try_begin_companion_click_reaction(playfield_pos, registry)") >= 0, "battle input should hand the registry to the click-reaction so the per-pet voice can play")
	_expect(runtime_source.find("_play_click_reaction_audio") >= 0, "lingpet runtime should request the click-reaction voice when a companion click lands")
	_expect(runtime_source.find("play_lingpet_click_reaction") >= 0, "lingpet runtime should route the click-reaction voice through the pet-agnostic GameAudio entry")


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


func _stat_values_have_exact(stats: Array, expected_value: String) -> bool:
	for value in stats:
		if value is Dictionary:
			var stat: Dictionary = value
			if str(stat.get("value", "")) == expected_value:
				return true
	return false


func _stat_values_have_fragment(stats: Array, expected_fragment: String) -> bool:
	for value in stats:
		if value is Dictionary:
			var stat: Dictionary = value
			if str(stat.get("value", "")).find(expected_fragment) >= 0:
				return true
	return false


func _issues_contain(issues: Array[String], needle: String) -> bool:
	for issue in issues:
		if issue.find(needle) >= 0:
			return true
	return false


func _skill_ids(skills: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for skill in skills:
		var skill_id := str(skill.get("id", "")).strip_edges()
		if skill_id != "":
			ids.append(skill_id)
	return ids


func _vector2_distance(a: Variant, b: Variant) -> float:
	if not (a is Vector2) or not (b is Vector2):
		return INF
	return (a as Vector2).distance_to(b as Vector2)


func _lingpet_runtime_click_sheet_is_small(pet_id: String) -> bool:
	var path := LingpetCatalog.get_visual_path(pet_id, "companion_click_reaction_anim")
	if path == "" or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_length() > 0 and file.get_length() < 5000000


func _estimated_knockback_distance(initial_nudge: float, velocity: float, frames: float, decay: float) -> float:
	var safe_decay := clampf(decay, 0.0, 0.999)
	var travel := absf(initial_nudge)
	if safe_decay <= 0.0:
		return travel + absf(velocity)
	return travel + absf(velocity) * (1.0 - pow(safe_decay, maxf(0.0, frames))) / (1.0 - safe_decay)


func _character_info_overlay_source() -> String:
	return FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_state.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_core.gd")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	var next_static_func := source.find("\nstatic func ", start + signature.length())
	var end := source.length()
	if next_func >= 0:
		end = mini(end, next_func)
	if next_static_func >= 0:
		end = mini(end, next_static_func)
	return source.substr(start, end - start)


func _make_starpoint_drop(pos: Vector2, forced_roll_pct: float) -> Dictionary:
	return {
		"pos": pos,
		"vel": Vector2.ZERO,
		"size": 12.0,
		"life": 600.0,
		"lingpet_starlight_tracking_force_roll_pct": forced_roll_pct,
	}


func _starpoint_delivery_context(owner: FakeOwner) -> Dictionary:
	return {
		"owner": owner,
		"player_pos": owner.player_pos,
		"player_paddle_size": Vector2(owner.player_paddle_width, owner.player_paddle_height),
	}


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
