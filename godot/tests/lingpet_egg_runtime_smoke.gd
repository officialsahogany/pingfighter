extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const BattleSceneLifecycle := preload("res://scripts/core/battle_scene_lifecycle.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEggFieldState := preload("res://scripts/lingpet/lingpet_egg_field_state.gd")
const LingpetEggFieldRenderer := preload("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetGhostBlinkVfx := preload("res://scripts/lingpet/lingpet_ghost_blink_vfx.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetCompanionSwitchState := preload("res://scripts/lingpet/lingpet_companion_switch_state.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetActiveSkillSlotResolver := preload("res://scripts/lingpet/lingpet_active_skill_slot_resolver.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const LingpetSaveStore := preload("res://scripts/lingpet/lingpet_save_store.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetCompanionDistanceRollState := preload("res://scripts/lingpet/lingpet_companion_distance_roll_state.gd")
const LingpetCompanionSkillArmGate := preload("res://scripts/lingpet/lingpet_companion_skill_arm_gate.gd")
const LingpetCompanionSkillPersistence := preload("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
const LingpetCompanionSkillVisualResolver := preload("res://scripts/lingpet/lingpet_companion_skill_visual_resolver.gd")
const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const HydroPuddleTextureCache := preload("res://scripts/effects/hydro_puddle_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetAffinityStore := preload("res://scripts/lingpet/lingpet_affinity_store.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
const LingpetTutorialBootstrap := preload("res://scripts/lingpet/lingpet_tutorial_bootstrap.gd")
const LingpetUnlockLoadoutReconciler := preload("res://scripts/lingpet/lingpet_unlock_loadout_reconciler.gd")
const LingpetNoneOwnerSyncState := preload("res://scripts/lingpet/lingpet_none_owner_sync_state.gd")
const LingpetItemEggAbsorbRouter := preload("res://scripts/lingpet/lingpet_item_egg_absorb_router.gd")
const LingpetItemEggLifecycleState := preload("res://scripts/lingpet/lingpet_item_egg_lifecycle_state.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior league"
	var current_stage := 1
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var lingpet_puppet_grab_active := false
	var lingpet_star_coil_boss_slow_active := false
	var lingpet_star_coil_boss_slow_multiplier := 1.0
	var lingpet_star_coil_block_boss_dash := false
	var lingpet_star_coil_freeze_boss_skill_cd := false
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_pos_prev := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_serve_origin := ""
	var ball_size := 28.6
	var rally_speed_cap_bonus := 0.0
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
	var lingpet_companion_appearance_rate := 0.0
	var ringpet_companion_appearance_rate := 0.0
	var lingpet_affinity_level := 0
	var ringpet_affinity_level := 0
	var lingpet_affinity_points := 0.0
	var ringpet_affinity_points := 0.0
	var lingpet_affinity_next_requirement := 0.0
	var ringpet_affinity_next_requirement := 0.0
	var lingpet_affinity_next_label := ""
	var ringpet_affinity_next_label := ""
	var lingpet_ring_core_tier := 0
	var ringpet_ring_core_tier := 0
	var lingpet_affinity_chip_count := 0
	var ringpet_affinity_chip_count := 0
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
	var lingpet_second_active_skill_id := ""
	var ringpet_second_active_skill_id := ""
	var lingpet_second_active_skill_level := 0
	var ringpet_second_active_skill_level := 0
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
	var lingpet_second_skill_id := ""
	var ringpet_second_skill_id := ""
	var lingpet_second_skill_name := ""
	var ringpet_second_skill_name := ""
	var lingpet_second_skill_max_level := 0
	var ringpet_second_skill_max_level := 0
	var lingpet_second_skill_cooldown := 0.0
	var ringpet_second_skill_cooldown := 0.0
	var lingpet_second_skill_cooldown_duration := 0.0
	var ringpet_second_skill_cooldown_duration := 0.0
	var lingpet_second_skill_ready := false
	var ringpet_second_skill_ready := false
	var lingpet_second_skill_winding_up := false
	var ringpet_second_skill_winding_up := false
	var lingpet_second_skill_windup_ratio := 0.0
	var ringpet_second_skill_windup_ratio := 0.0
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
	var lingpet_companion_appearance_rate := 0.0
	var ringpet_companion_appearance_rate := 0.0
	var lingpet_affinity_level := 0
	var ringpet_affinity_level := 0
	var lingpet_affinity_points := 0.0
	var ringpet_affinity_points := 0.0
	var lingpet_affinity_next_requirement := 0.0
	var ringpet_affinity_next_requirement := 0.0
	var lingpet_affinity_next_label := ""
	var ringpet_affinity_next_label := ""
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
	var lingpet_second_skill_id := ""
	var ringpet_second_skill_id := ""
	var lingpet_second_skill_name := ""
	var ringpet_second_skill_name := ""
	var lingpet_second_skill_max_level := 0
	var ringpet_second_skill_max_level := 0
	var lingpet_second_skill_cooldown := 0.0
	var ringpet_second_skill_cooldown := 0.0
	var lingpet_second_skill_cooldown_duration := 0.0
	var ringpet_second_skill_cooldown_duration := 0.0
	var lingpet_second_skill_ready := false
	var ringpet_second_skill_ready := false
	var lingpet_second_skill_winding_up := false
	var ringpet_second_skill_winding_up := false
	var lingpet_second_skill_windup_ratio := 0.0
	var ringpet_second_skill_windup_ratio := 0.0
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


class FakePerfLogger:
	extends RefCounted

	var counter_samples: Array[Dictionary] = []

	func record_counter_sample(label: String, value: float) -> void:
		counter_samples.append({
			"label": label,
			"value": value,
		})

	func total_for(label: String) -> float:
		var total := 0.0
		for sample in counter_samples:
			if str(sample.get("label", "")) == label:
				total += float(sample.get("value", 0.0))
		return total


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

	func play_paddle_hit(_source_x: float = 380.0) -> void:
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


class FakeDashState:
	extends RefCounted

	var active := false
	var direction := 0.0

	func is_active() -> bool:
		return active

	func get_snapshot() -> Dictionary:
		return {
			"active": active,
			"direction": direction,
		}


class FakeRuntimePerkState:
	extends RefCounted

	var runtime_skill_levels := {
		CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1,
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID: 1,
	}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(runtime_skill_levels.get(skill_id, 0))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances.duplicate()
		if not instances.has("runtime_perk_state"):
			instances["runtime_perk_state"] = FakeRuntimePerkState.new()

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if value is Object:
			return value
		return null

	# 핫패스 소비자는 peek 전용(get_cached_instance)만 쓴다 — 이 훅이 없으면
	# 그 경로가 조용히 빈손으로 돌아 씰이 공허-GREEN이 된다.
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakePlayerDashState:
	extends RefCounted

	var dash_active := false
	var dash_timer := 0.0
	var dash_direction := 0.0
	var dash_distance_multiplier := 1.0

	func is_active() -> bool:
		return dash_active

	func get_snapshot() -> Dictionary:
		return {
			"active": dash_active,
			"timer": dash_timer,
			"direction": dash_direction,
			"dash_distance_multiplier": dash_distance_multiplier,
		}


class FakeEggHitAudio:
	extends RefCounted

	var egg_hit_calls := 0

	func play_lingpet_egg_hit() -> void:
		egg_hit_calls += 1


class FakeCutinHost:
	extends RefCounted

	var prewarm_calls: Array[String] = []
	var done_after := 2
	var anim_ready := true

	func prewarm_pet_assets_step(
		pet_id: String,
		_allow_sync_fallback: bool = false,
		_perf_logger: Object = null,
		_perf_label_prefix: String = ""
	) -> bool:
		prewarm_calls.append(pet_id)
		return prewarm_calls.size() >= done_after

	func is_pet_cutin_anim_ready(_pet_id: String) -> bool:
		return anim_ready


func _init() -> void:
	_verify_registry_and_frame_wiring()
	_verify_item_egg_hatch_rolls_loadout()
	_verify_lingpet_catalog_random_hatch_scaffold()
	_verify_junior_mika_spawn_syncs_character_info_keys()
	_verify_junior_mika_tutorial_grants_standard_ring_core_before_hatch()
	_verify_tutorial_ring_core_grant_does_not_lower_or_bypass_eligibility()
	_verify_egg_player_contact_nudges_and_wobbles()
	_verify_egg_color_rolls_once_and_restores()
	_verify_bare_egg_roll_physics_and_renderer()
	_verify_egg_hatch_required_hits_roll()
	_verify_egg_settle_oscillation()
	_verify_egg_ball_hit_knockback_impulse()
	_verify_egg_crack_overlay_assets_and_prewarm()
	_verify_egg_dash_collision_knocks_and_wall_rebounds()
	_verify_player_serve_ball_does_not_hatch_egg()
	_verify_egg_hit_uses_player_paddle_reflection()
	_verify_one_ball_hit_hatches_unidentified_egg()
	_verify_affinity_hatch_bonus_hook()
	_verify_acquire_cutin_triggers_on_hatch()
	_verify_hatch_break_sequence_defers_cutin()
	_verify_acquire_cutin_assets_prewarm_during_egg_phase()
	_verify_acquire_cutin_reveal_holds_until_anim_sheet_ready()
	_verify_owned_maribo_is_kept_as_companion()
	_verify_pro_league_egg_item_deploy()
	_verify_lingpet_egg_deploys_while_companion_active()
	_verify_lingpet_egg_overflow_replace_release_choice()
	_verify_lingpet_egg_overflow_reset_resolves_to_release()
	_verify_lingpet_egg_deploy_blocked_in_junior()
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
	_verify_exhaustion_suppresses_starlight_tracking()
	_verify_exhaustion_suppresses_linkport()
	_verify_ring_dash_passive()
	_verify_ring_dash_single_roll_per_descent()
	_verify_ring_dash_defers_to_committed_player_dash()
	_verify_ring_dash_ground_pet_keeps_y_on_teleport()
	_verify_companion_paddle_hit_width()
	_verify_companion_guards_dalji_whip()
	_verify_companion_skill_card_hydro_sphere()
	_verify_hydro_sphere_scales_with_level()
	_verify_lingpet_skill_cooldown_survives_slot_switch()
	_verify_lingpet_slot_switch_clears_owner_locked_skill_flags()
	_verify_lingpet_skill_waits_for_switch_transition()
	_verify_hydro_puddle_vfx()
	_verify_save_snapshot_roundtrip()
	_verify_save_store_persists_and_restores_maribo()
	_verify_battle_lifecycle_restores_lingpet_save()
	_verify_maribo_companion_gauge_bonus()
	_verify_maribo_defense_rate_intercepts_descending_ball()
	_verify_maribo_defense_actually_blocks_reachable_ball()
	_verify_player_takes_ball_priority_when_companion_overlaps()
	_verify_lingpet_body_draws_behind_player()
	_verify_lingpet_defense_guard_chase_feedback()
	_verify_maribo_defense_anticipates_moderate_distance_ball()
	_verify_maribo_high_defense_reaches_widened_zone()
	_verify_maribo_defense_hold_stops_walk_animation()
	_verify_walk_animation_freezes_when_update_skipped()
	_verify_starlight_pickup_hold_reads_idle()
	_verify_patrol_static_frame_reads_idle()
	_verify_orosha_distance_roll_angle_tracks_horizontal_travel()
	_verify_patrol_dir_recovers_after_defense_park()
	_verify_rabi_ghost_blink_cycle()
	_verify_ghost_blink_vfx()
	_verify_lunabi_free_flight_profile()
	_verify_lunabi_headbutt_skill()
	_verify_lunabi_headbutt_level_scaling()
	_verify_lunabi_headbutt_mega()
	_verify_koyora_puppet_grab_skill()
	_verify_skeleton_archer_resets_on_stage_transition()
	_verify_loadout_apply_prewarms_active_skill_runtime()
	_verify_companion_click_reaction()
	_verify_affinity_click_start_edge_and_visibility_gate()
	_verify_companion_interact_key_reaction()
	_verify_affinity_score_event_and_battle_reset()
	_verify_ring_core_upgrade_grants_affinity_to_all_owned_pets()
	_verify_affinity_reward_application()
	_verify_second_active_slot_runtime_foundation()
	_verify_debug_grant_unlock_reconcile_skip_is_sticky_until_pet_change()
	_verify_second_active_resource_conflict_mediation()
	_verify_affinity_level_up_feedback_and_income_log()
	_verify_affinity_point_gain_popup()
	_verify_lingpet_guard_label_feedback()
	_verify_affinity_store_v5_meta_only()
	_verify_ring_core_cap_run_state_source()
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
	var lingpet_catalog_source: String = FileAccess.get_file_as_string("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
	_expect(lingpet_catalog_source.find("\"lingpet_affinity_store\"") < 0, "meta-only affinity store should not stay registered as a live gameplay module")
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
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/resonance_egg_holder.png"), "shared unidentified lingpet egg should ship the common holder layer")
	var asset_renderer := LingpetEggFieldRenderer.new()
	_expect(LingpetEggFieldRenderer.EGG_BARE_VARIANT_PATHS.size() == asset_renderer.get_variant_count(), "egg renderer variant count should be derived from the bare variant path list")
	_expect(LingpetEggFieldRenderer.EGG_VARIANT_GLOW.size() == asset_renderer.get_variant_count(), "egg renderer should keep one glow color per variant path")
	for variant_index in range(asset_renderer.get_variant_count()):
		var traditional_path: String = str(LingpetEggFieldRenderer.EGG_BARE_VARIANT_PATHS[variant_index])
		_expect(FileAccess.file_exists(traditional_path), "field guardian-spirit egg should ship traditional variant layer %d" % variant_index)
		_expect(traditional_path.ends_with("guardian_spirit_egg_traditional_variant_%d_v1.png" % variant_index), "field guardian-spirit egg variant %d should use the traditional craft family" % variant_index)
		_expect(FileAccess.file_exists("res://assets/sprites/lingpet/resonance_egg_bare_variant_%d.png" % variant_index), "legacy bare resonance egg variant layer %d should stay on disk for rollback/reference" % variant_index)
		_expect(FileAccess.file_exists("res://assets/sprites/lingpet/resonance_egg_variant_%d.png" % variant_index), "holder-era resonance egg variant layer %d should stay on disk for rollback/icon/reference" % variant_index)
	for crack_path: String in LingpetEggFieldRenderer.EGG_CRACK_STAGE_TEXTURE_PATHS:
		_expect(FileAccess.file_exists(crack_path), "guardian-spirit egg should ship its warm ceramic-fissure overlay")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png"), "guardian-spirit egg active-item slot icon should ship the traditional porcelain image")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/resonance_egg_item_icon.png"), "legacy resonance egg active-item slot icon should stay on disk for rollback/reference")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/resonance_egg_base.png"), "legacy neutral resonance egg base should stay on disk for rollback/reference")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/resonance_egg_base_crack_1.png"), "legacy neutral first-crack resonance egg should stay on disk for rollback/reference")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/resonance_egg_base_crack_2.png"), "legacy neutral second-crack resonance egg should stay on disk for rollback/reference")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_egg_v002.png"), "legacy Maribo egg art should stay on disk for reference even after the shared resonance egg repoint")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var round_resetter_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_round_resetter.gd")
	_expect(runtime_source.find("LINGPET_EGG_TEXTURE") < 0, "field egg rendering should not hard-preload the shared egg PNGs")
	_expect(runtime_source.find("lingpet_egg_field_renderer.gd") >= 0, "egg runtime should delegate field egg rendering to the egg renderer module")
	_expect(runtime_source.find("func _get_egg_texture_for_hits") < 0, "egg runtime should not keep a single-use egg-texture wrapper after renderer-owned layer delegation")
	_expect(runtime_source.find("func _draw_egg") < 0, "egg runtime should not keep a single-use field-egg draw wrapper")
	_expect(runtime_source.find("func _draw_item_egg") < 0, "egg runtime should not keep a single-use item-egg draw wrapper")
	_expect(runtime_source.find("func _draw_hatch_flash") < 0, "egg runtime should not keep a single-use hatch-flash draw wrapper")
	_expect(runtime_source.find("_current_profile.get_visual_texture") < 0, "egg runtime should not resolve egg textures through the current pet profile")
	_expect(runtime_source.find("_egg_renderer.draw_profile_egg") >= 0, "egg runtime should delegate coexisting item-egg drawing to the shared egg renderer")
	_expect(runtime_source.find("_egg_renderer.draw_hatch_flash") >= 0, "egg runtime should call the egg renderer directly for hatch-flash drawing")
	_expect(runtime_source.find("_egg_renderer.prewarm()") >= 0, "egg runtime should prewarm renderer-owned bare variant egg textures off the draw path")
	_expect(runtime_source.find("var _hatch_flash_timer") < 0, "egg runtime should not keep raw hatch-flash timer state")
	_expect(runtime_source.find("_egg_state.has_hatch_flash") >= 0 and runtime_source.find("_egg_state.get_hatch_flash_timer") >= 0, "egg runtime should read hatch-flash timer state from the egg field state")
	# The hatch-flash TRIGGER is routed through the companion runtime resetter: egg runtime
	# loads egg_state + hatch_flash_seconds into the hatch-reveal context, and the resetter
	# calls egg_state.trigger_hatch_flash() from that context.
	_expect(runtime_source.find("\"hatch_flash_seconds\"") >= 0 and runtime_source.find("start_hatch_reveal_effects") >= 0, "egg runtime should load egg_state + hatch_flash_seconds into the hatch-reveal context for the resetter")
	var hatch_runtime_resetter_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_runtime_resetter.gd")
	_expect(hatch_runtime_resetter_source.find("trigger_hatch_flash") >= 0, "companion runtime resetter should trigger the hatch flash via the context egg_state")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_egg_field_renderer.gd"), "egg-field renderer module should exist")
	var egg_renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
	var egg_field_state_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_field_state.gd")
	_expect(egg_renderer_source.find("HOLDER_PATH") < 0 and egg_renderer_source.find("EGG_BARE_VARIANT_PATHS") >= 0, "field egg renderer should use bare variant texture paths and no holder layer")
	_expect(egg_renderer_source.find("func prewarm") >= 0 and egg_renderer_source.find("load_imported_texture") >= 0, "egg renderer should expose a prewarm path for bare variant textures")
	var egg_draw_body: String = _function_body(egg_renderer_source, "func draw_egg")
	_expect(egg_draw_body.find("load_imported_texture") < 0 and egg_draw_body.find("_load_egg_texture") < 0, "egg renderer draw_egg() should use cached textures only, never hot-path lazy loading")
	_expect(egg_draw_body.find("holder_texture") < 0 and egg_renderer_source.find("draw_texture_rect(holder_texture") < 0, "field egg renderer must not draw the holder layer")
	_expect(egg_renderer_source.find("_draw_rotated_texture(canvas, egg_texture, texture_rect, final_rotation)") >= 0, "field egg renderer should draw the bare egg through the rotated texture path")
	_expect(egg_renderer_source.find("draw_set_transform") < 0, "field egg rotation should avoid draw_set_transform state leaks")
	_expect(egg_renderer_source.find("Color(tint.r") < 0 and egg_renderer_source.find("EGG_TINTS") < 0 and egg_renderer_source.find("get_tint_for_index") < 0, "egg renderer should not keep the old tint/modulate path")
	_expect(egg_renderer_source.find("profile.get_visual_texture") < 0 and egg_renderer_source.find("get_visual_key_for_hits") < 0, "egg renderer should not read egg textures from pet profiles")
	_expect(egg_field_state_source.find("func trigger_hatch_flash") >= 0 and egg_field_state_source.find("func get_hatch_flash_timer") >= 0, "egg field state should own hatch-flash timer lifecycle")
	_expect(egg_field_state_source.find("egg_color_index") >= 0 and egg_field_state_source.find("roll_color_index()") >= 0, "egg field state should own the one-time resonance color roll")
	_expect(egg_renderer_source.find("EGG_VARIANT_GLOW") >= 0, "egg renderer should own variant-specific glow colors")
	var hatch_flash_body: String = _function_body(egg_renderer_source, "func draw_hatch_flash")
	var hatch_burst_body: String = _function_body(egg_renderer_source, "func _draw_hatch_shell_burst")
	_expect(hatch_flash_body.find("variant_index") >= 0 and hatch_flash_body.find("_draw_hatch_shell_burst(canvas, center, t, variant_index)") >= 0, "hatch flash should pass the egg variant into the shard burst")
	_expect(hatch_burst_body.find("_get_glow_for_index(variant_index)") >= 0 and hatch_burst_body.find("glow.lerp(Color.WHITE") >= 0, "hatch shards should tint by the egg variant glow, not a fixed palette")
	_expect(hatch_burst_body.find("Color(1.0, 0.74, 0.93") < 0, "hatch shards should drop the fixed pink shell palette so amber/violet/jade eggs do not spray pink")
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
	var loadout_state_source_for_snapshot: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_loadout_state.gd")
	var current_loadout_applier_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
	var current_pet_transition_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_pet_transition.gd")
	_expect(snapshot_builder_source.find("build_runtime_snapshot") >= 0, "snapshot builder should own live runtime snapshot assembly")
	_expect(snapshot_builder_source.find("build_save_snapshot") >= 0, "snapshot builder should own save snapshot assembly")
	_expect(snapshot_builder_source.find("sync_owner") >= 0, "snapshot builder should own owner compatibility key sync")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_effect_text_resolver.gd"), "lingpet effect-text resolver module should exist")
	_expect(runtime_source.find("LingpetEffectTextResolver.resolve") >= 0, "egg runtime should delegate owner-facing effect text selection to the effect-text resolver")
	_expect(runtime_source.find("func _get_effect_text") < 0, "egg runtime should not keep a single-use effect-text wrapper")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_affinity_context_coordinator.gd"), "lingpet affinity context coordinator module should exist")
	_expect(runtime_source.find("_affinity_context_coordinator.configure") >= 0, "egg runtime should call the affinity coordinator directly for reward-context composition")
	_expect(current_pet_transition_source.find("sync_current_profile") >= 0 and current_loadout_applier_source.find("sync_current_profile") >= 0, "current-pet transition and current-loadout applier should own current-profile affinity projection")
	_expect(runtime_source.find("func _configure_affinity_reward_context") < 0, "egg runtime should not keep a reward-context configuration pass-through wrapper")
	_expect(runtime_source.find("func _sync_current_profile_affinity") < 0, "egg runtime should not keep a current-profile affinity sync pass-through wrapper")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_current_pet_transition.gd"), "current pet transition helper should exist")
	_expect(current_pet_transition_source.find("func apply") >= 0 and current_pet_transition_source.find("sync_current_profile") >= 0 and current_pet_transition_source.find("invalidate_runtime_and_snapshot_cache") >= 0, "current pet transition helper should own current-pet profile sync and change side effects")
	_expect(runtime_source.find("lingpet_current_pet_transition.gd") >= 0 and runtime_source.find("_current_pet_transition.apply") >= 0, "egg runtime should delegate current-pet id transition side effects")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_current_loadout_applier.gd"), "current loadout applier should exist")
	_expect(current_loadout_applier_source.find("func apply") >= 0 and current_loadout_applier_source.find("ensure_pet_loadout") >= 0 and current_loadout_applier_source.find("reconcile_for_runtime") >= 0, "current loadout applier should own current-pet loadout ensure and unlock reconciliation")
	_expect(current_loadout_applier_source.find("LingpetLoadoutCacheKeyBuilder") >= 0 and current_loadout_applier_source.find("mark_runtime_cache_applied") >= 0, "current loadout applier should own current-loadout apply-cache keying")
	_expect(runtime_source.find("lingpet_current_loadout_applier.gd") >= 0 and runtime_source.find("_current_loadout_applier.apply") >= 0, "egg runtime should delegate current-loadout application fanout")
	_expect(runtime_source.find("lingpet_loadout_cache_key_builder.gd") < 0, "egg runtime should not own current-loadout cache-key construction directly")
	_expect(snapshot_builder_source.find("func invalidate_sync_cache") >= 0, "snapshot builder should expose cache invalidation as a fixed module contract")
	_expect(loadout_state_source_for_snapshot.find("func invalidate_runtime_and_snapshot_cache") >= 0 and loadout_state_source_for_snapshot.find("snapshot_builder.invalidate_sync_cache()") >= 0, "loadout state should own runtime-cache and snapshot-sync cache invalidation")
	_expect(loadout_state_source_for_snapshot.find("func forget_pet_loadout_and_invalidate") >= 0 and loadout_state_source_for_snapshot.find("forget_pet_loadout(owner, pet_id)") >= 0, "loadout state should own forget-loadout plus cache invalidation fanout")
	_expect(loadout_state_source_for_snapshot.find("func set_pet_loadout_and_invalidate") >= 0 and loadout_state_source_for_snapshot.find("set_pet_loadout(") >= 0, "loadout state should own set-loadout plus cache invalidation fanout")
	_expect(runtime_source.find("func _invalidate_current_loadout_cache") < 0, "egg runtime should not keep a private loadout-cache invalidation wrapper")
	_expect(runtime_source.find("_loadout_state.invalidate_runtime_and_snapshot_cache") >= 0, "egg runtime should delegate cache invalidation to the loadout-state owner")
	_expect(runtime_source.find("_loadout_state.forget_pet_loadout(") < 0, "egg runtime should not repeat forget-loadout without the loadout-state invalidation helper")
	var debug_grant_body := _function_body(runtime_source, "func debug_grant_and_activate_pet")
	_expect(debug_grant_body.find("_loadout_state.set_pet_loadout_and_invalidate") >= 0, "debug-grant loadout writes should use the loadout-state invalidation helper")
	_expect(debug_grant_body.find("_loadout_state.set_pet_loadout(") < 0, "debug-grant loadout writes should not repeat set-loadout without cache invalidation")
	_expect(runtime_source.find("_snapshot_builder.has_method(\"invalidate_sync_cache\")") < 0, "egg runtime should not guard the fixed snapshot builder invalidation contract dynamically")
	var save_restore_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_save_restore_planner.gd")
	_expect(runtime_source.find("lingpet_save_restore_planner.gd") >= 0, "egg runtime should delegate save-restore target decisions to the restore planner")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_save_restore_planner.gd"), "lingpet save-restore planner module should exist")
	_expect(save_restore_source.find("build_plan") >= 0, "save-restore planner should own restore target plan assembly")
	_expect(save_restore_source.find("active_pet_id") >= 0 and save_restore_source.find("battle_slot_pet_ids") >= 0, "save-restore planner should preserve active pet and battle slot interpretation")
	_expect(runtime_source.find("lingpet_companion_body_hit_state.gd") >= 0, "egg runtime should delegate companion body hit bounce/gauge state to the body-hit module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_body_hit_state.gd"), "companion body-hit state module should exist")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_feed_controller.gd"), "lingpet feed controller module should exist")
	_expect(runtime_source.find("func _advance_feed_bowl_state") < 0, "egg runtime should not keep a single-use feed-bowl advance wrapper")
	_expect(runtime_source.find("func _reset_feed_bowl_state") < 0, "egg runtime should not keep a single-use feed reset wrapper")
	_expect(runtime_source.find("_feed_controller.advance") >= 0 and runtime_source.find("get_duration_pool_current") >= 0 and runtime_source.find("\"duration_feed\"") >= 0, "egg runtime should advance feed bowls and restore completed feeds through the shared duration source")
	_expect(runtime_source.find("LingpetAffinityState.SOURCE_FEED") < 0, "egg runtime should not grant completed feeds through the superseded affinity source")
	_expect(runtime_source.find("_feed_controller.reset_for_new_battle") >= 0, "egg runtime should call the feed controller directly for battle-cap reset")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd"), "companion body presence resolver module should exist")
	_expect(runtime_source.find("func _is_companion_body_available_for_hit") < 0, "egg runtime should not keep a single-use companion body hit-availability wrapper")
	_expect(runtime_source.find("func _is_companion_body_draw_suppressed") < 0, "egg runtime should not keep a single-use companion body draw-suppression wrapper")
	_expect(runtime_source.find("func _is_companion_body_visible_for_draw") < 0, "egg runtime should not keep a single-use companion body draw-visibility wrapper")
	_expect(runtime_source.find("_companion_body_presence_resolver.is_available_for_hit") >= 0, "egg runtime should call the body presence resolver directly for hit availability")
	_expect(runtime_source.find("_companion_body_presence_resolver.is_visible_for_draw") >= 0, "egg runtime should call the body presence resolver directly for draw visibility")
	_expect(runtime_source.find("lingpet_afterglow_leak_state.gd") >= 0, "egg runtime should delegate the Afterglow Leak residue passive to a focused state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_afterglow_leak_state.gd"), "Afterglow Leak passive state module should exist")
	_expect(runtime_source.find("lingpet_starlight_tracking_state.gd") >= 0, "egg runtime should delegate the Starlight Tracking auto-collection passive to a focused state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_starlight_tracking_state.gd"), "Starlight Tracking passive state module should exist")
	_expect(FileAccess.file_exists("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd"), "starpoint stages should share a lingpet Starlight Tracking bridge")
	_expect(runtime_source.find("lingpet_ring_dash_state.gd") >= 0, "egg runtime should delegate the Ring Dash emergency guard passive to a focused state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_ring_dash_state.gd"), "Ring Dash passive state module should exist")
	_expect(runtime_source.find("func _play_ring_dash_audio") < 0, "egg runtime should not keep a single-use Ring Dash audio wrapper")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_ring_dash") >= 0, "egg runtime should dispatch Ring Dash audio directly from the dash-start event")
	_expect(runtime_source.find("lingpet_companion_motion_state.gd") >= 0, "egg runtime should delegate companion patrol/defense motion to the motion-state module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_motion_state.gd"), "companion motion-state module should exist")
	_expect(runtime_source.find("func _reset_companion_defense") < 0, "egg runtime should not keep a single-use companion defense reset wrapper")
	_expect(round_resetter_source.find("companion_motion_state.reset_defense") >= 0, "round resetter should reset companion defense state through the motion-state module")
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
	_expect(cutin_host_source.find("CUTIN_ANIM_COLS := 8") >= 0, "cut-in host should default to the 8x4 / 32-frame acquisition Live2D sheet contract")
	_expect(cutin_host_source.find("CUTIN_ANIM_ROWS := 4") >= 0, "cut-in host should default to the 8x4 / 32-frame acquisition Live2D sheet contract")
	_expect(cutin_host_source.find("CUTIN_ANIM_FRAMES := 32") >= 0, "cut-in host should default to the 32-frame acquisition Live2D sheet contract")
	_expect(
		cutin_host_source.find("\"maribo\": 4") >= 0
		and cutin_host_source.find("\"maribo\": 16") >= 0,
		"Maribo's legacy 4x4 / 16-frame acquisition cut-in should stay protected by an explicit override"
	)
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
	_expect(runtime_source.find("func _get_current_acquire_cutin_dismiss_seconds") < 0, "lingpet runtime should not reintroduce the single-use acquisition dismiss-duration wrapper")
	_expect(runtime_source.find("var _acquire_cutin_pet_id") < 0, "lingpet runtime should not keep raw acquire-cutin display identity state")
	_expect(runtime_source.find("_acquire_cutin_state.get_display_pet_id") >= 0 and runtime_source.find("_acquire_cutin_state.has_display_override") >= 0, "lingpet runtime should ask acquire-cutin state for display identity")
	for cutin_identity_wrapper in ["func _get_cutin_pet_id", "func _get_cutin_profile"]:
		_expect(runtime_source.find(cutin_identity_wrapper) < 0, "lingpet runtime should resolve acquire-cutin display identity at the call site instead of keeping private wrappers (%s)" % cutin_identity_wrapper)
	_expect(runtime_source.find("cutin_dismiss_seconds") >= 0 and runtime_source.find("LingpetAcquireCutinState.DISMISS_SECONDS") >= 0, "lingpet runtime should allow pet-specific acquisition click-dismiss duration tuning")
	_expect(runtime_source.find("is_acquire_cutin_dismissing") >= 0, "lingpet runtime should expose the exit-action (dismissing) state")
	_expect(runtime_source.find("get_acquire_cutin_dismiss_progress") >= 0, "lingpet runtime should expose the exit-action progress for the host")
	var acquire_cutin_state_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
	_expect(
		acquire_cutin_state_source.find("dismiss_seconds") >= 0
		and acquire_cutin_state_source.find("begin_dismiss(duration_seconds") >= 0,
		"lingpet acquire cut-in state should time the exit action with the pet-specific dismiss duration"
	)
	_expect(
		acquire_cutin_state_source.find("display_pet_id") >= 0
		and acquire_cutin_state_source.find("func get_display_pet_id") >= 0
		and acquire_cutin_state_source.find("func has_display_override") >= 0,
		"lingpet acquire cut-in state should own reveal-only display identity"
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
	# by the priority lingpet input owner for click dismissal.
	var modal_gate_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(modal_gate_source.find("is_lingpet_acquire_cutin_active") >= 0, "modal gate should expose the lingpet acquisition cut-in as a physics-blocking modal")
	_expect(modal_gate_source.find("physics.modal_gate.lingpet_acquire_cutin") >= 0, "modal gate should block battle physics while the acquisition cut-in is active")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_priority_input_router.gd")
	_expect(input_source.find("is_acquire_cutin_awaiting_dismiss") >= 0, "priority lingpet input owner should only act after the reveal finishes")
	_expect(input_source.find("begin_acquire_cutin_dismiss") >= 0, "priority lingpet input owner should start the exit action on click/confirm (not close instantly)")
	_expect(input_source.find("begin_acquire_cutin_dismiss(registry)") >= 0, "priority lingpet input owner should pass the registry so acquisition-click voice can play")
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
	_expect(runtime_source.find("_acquire_cutin_asset_prewarm_state.prewarm_registry_step") >= 0, "lingpet runtime should delegate acquire cut-in registry host resolution to the asset-prewarm owner")
	for prewarm_wrapper in ["func _prewarm_acquire_cutin_assets_step", "func _prewarm_item_egg_cutin_assets_step"]:
		_expect(runtime_source.find(prewarm_wrapper) < 0, "lingpet runtime should not keep private acquire cut-in asset-prewarm wrappers (%s)" % prewarm_wrapper)
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
	var acquisition_audio_source: String = FileAccess.get_file_as_string("res://scripts/audio/lingpet_acquisition_audio.gd")
	var click_voice_audio_source: String = FileAccess.get_file_as_string("res://scripts/audio/lingpet_click_voice_audio.gd")
	var combat_audio_source: String = FileAccess.get_file_as_string("res://scripts/audio/lingpet_combat_audio.gd")
	_expect(acquisition_audio_source.find("lingpet_acquire_ominous_shadow_shimmer_02.wav") >= 0, "acquisition audio owner should register the lingpet acquisition cut-in sound path")
	_expect(acquisition_audio_source.find('"gain_db": 0.0') >= 0, "acquisition audio owner should play the cinematic lingpet acquisition sound at full SFX gain")
	_expect(acquisition_audio_source.find("LingpetAcquireCutinSfx") >= 0, "acquisition audio owner should create a dedicated player for the lingpet acquisition cut-in sound")
	_expect(acquisition_audio_source.find("func ensure_player") >= 0, "acquisition audio owner should lazily recover the lingpet acquisition SFX player if setup did not create it")
	_expect(game_audio_source.find("play_lingpet_acquire_cutin") >= 0, "GameAudio should expose a lingpet acquisition cut-in play method")
	_expect(runtime_source.find("play_lingpet_acquire_cutin") >= 0, "lingpet runtime should request the acquisition cut-in sound when the screen starts")
	_expect(runtime_source.find("func _play_acquire_cutin_audio") < 0, "lingpet runtime should not keep a single-use acquisition cut-in audio wrapper")
	_expect(runtime_source.find("func _start_acquire_cutin") < 0, "lingpet runtime should not keep a single-use acquisition cut-in start wrapper")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_acquire_cutin") >= 0, "lingpet runtime should dispatch acquisition cut-in audio directly from the cut-in start event")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lingpet_acquire_click_deep_bass_doom.wav"), "lingpet acquisition click Live2D should ship the deep bass doom backing SFX in the lingpet sound asset folder")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lingpet_acquire_click_magic_crackle_sweep.wav"), "lingpet acquisition click Live2D should ship the magic crackle sweep backing SFX in the lingpet sound asset folder")
	var acquire_click_bass_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lingpet_acquire_click_deep_bass_doom.wav")
	var acquire_click_sweep_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lingpet_acquire_click_magic_crackle_sweep.wav")
	_expect(acquire_click_bass_stream != null and acquire_click_bass_stream.get_length() > 2.0, "lingpet acquisition click deep bass SFX should load as a playable Godot AudioStream")
	_expect(acquire_click_sweep_stream != null and acquire_click_sweep_stream.get_length() > 2.0, "lingpet acquisition click crackle sweep SFX should load as a playable Godot AudioStream")
	_expect(acquisition_audio_source.find("lingpet_acquire_click_deep_bass_doom.wav") >= 0, "acquisition audio owner should register the lingpet acquisition click deep bass sound path")
	_expect(acquisition_audio_source.find("lingpet_acquire_click_magic_crackle_sweep.wav") >= 0, "acquisition audio owner should register the lingpet acquisition click crackle sweep sound path")
	_expect(acquisition_audio_source.find("LingpetAcquireClickDeepBassSfx") >= 0, "acquisition audio owner should create a dedicated player for the acquisition click deep bass backing")
	_expect(acquisition_audio_source.find("LingpetAcquireClickCrackleSweepSfx") >= 0, "acquisition audio owner should create a dedicated player for the acquisition click crackle sweep backing")
	_expect(game_audio_source.find("play_lingpet_acquire_click_reaction_backing") >= 0, "GameAudio should expose a dedicated acquisition-click backing play method")
	_expect(runtime_source.find("play_lingpet_acquire_click_reaction_backing") >= 0, "lingpet runtime should request the backing SFX only when the acquisition click Live2D starts")
	_expect(runtime_source.find("func _play_acquire_click_reaction_backing_audio") < 0, "lingpet runtime should not keep a single-use acquisition-click backing audio wrapper")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_acquire_click_reaction_backing") >= 0, "lingpet runtime should dispatch acquisition-click backing audio directly from the dismiss-start event")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lunabi_click_reaction_voice_v1.mp3"), "Lunabi should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var lunabi_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lunabi_click_reaction_voice_v1.mp3")
	_expect(lunabi_click_voice_stream != null and lunabi_click_voice_stream.get_length() > 0.1, "Lunabi click-reaction voice should load as a playable Godot AudioStream")
	_expect(click_voice_audio_source.find("lunabi_click_reaction_voice_v1.mp3") >= 0, "click-voice owner should register the Lunabi sound path")
	_expect(click_voice_audio_source.find("LingpetLunabiClickVoiceSfx") >= 0, "click-voice owner should create a dedicated Lunabi player")
	_expect(click_voice_audio_source.find("func ensure_player_for_pet") >= 0, "click-voice owner should lazily recover missing voice players")
	_expect(click_voice_audio_source.find("\"lunabi\"") >= 0 and click_voice_audio_source.find("_normalize_pet_id") >= 0, "click-voice owner should route normalized lunabi ids")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/volty_click_reaction_voice_v1.mp3"), "Volty should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var volty_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/volty_click_reaction_voice_v1.mp3")
	_expect(volty_click_voice_stream != null and volty_click_voice_stream.get_length() > 0.1, "Volty click-reaction voice should load as a playable Godot AudioStream")
	_expect(click_voice_audio_source.find("volty_click_reaction_voice_v1.mp3") >= 0, "click-voice owner should register the Volty sound path")
	_expect(click_voice_audio_source.find("LingpetVoltyClickVoiceSfx") >= 0, "click-voice owner should create a dedicated Volty player")
	_expect(game_audio_source.find("lingpet_click_voice_audio.ensure_player_for_pet(pet_id)") >= 0, "GameAudio should delegate click-voice lazy recovery")
	_expect(game_audio_source.find("func play_lingpet_click_reaction") >= 0, "GameAudio should expose a pet-agnostic click-reaction play method")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/milkring_click_reaction_voice_v1.mp3"), "Milkring should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var milkring_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/milkring_click_reaction_voice_v1.mp3")
	_expect(milkring_click_voice_stream != null and milkring_click_voice_stream.get_length() > 0.1, "Milkring click-reaction voice should load as a playable Godot AudioStream")
	_expect(click_voice_audio_source.find("milkring_click_reaction_voice_v1.mp3") >= 0, "click-voice owner should register the Milkring sound path")
	_expect(click_voice_audio_source.find("LingpetMilkringClickVoiceSfx") >= 0, "click-voice owner should create a dedicated Milkring player")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/red_dragon_click_reaction_voice_v1.mp3"), "Red Dragon (Farukiras) should ship its dedicated click-reaction voice in the lingpet sound asset folder")
	var red_dragon_click_voice_stream: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/red_dragon_click_reaction_voice_v1.mp3")
	_expect(red_dragon_click_voice_stream != null and red_dragon_click_voice_stream.get_length() > 0.1, "Red Dragon click-reaction voice should load as a playable Godot AudioStream")
	_expect(click_voice_audio_source.find("red_dragon_click_reaction_voice_v1.mp3") >= 0, "click-voice owner should register the Red Dragon sound path")
	_expect(click_voice_audio_source.find("LingpetRedDragonClickVoiceSfx") >= 0, "click-voice owner should create a dedicated Red Dragon player")
	_expect(click_voice_audio_source.find("\"red_dragon\"") >= 0, "click-voice owner should route the red_dragon pet id")
	# 수호령 알 히트 SFX(뼈 부러지는 임팩트 2종 랜덤): 자산 + GameAudio 등록 + 디스패처 + 런타임/아이템 알 배선.
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_1.wav"), "lingpet egg-hit should ship its first bone-break impact SFX in the lingpet sound asset folder")
	_expect(FileAccess.file_exists("res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_2.wav"), "lingpet egg-hit should ship its second bone-break impact SFX in the lingpet sound asset folder")
	var egg_hit_stream_1: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_1.wav")
	var egg_hit_stream_2: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_2.wav")
	_expect(egg_hit_stream_1 != null and egg_hit_stream_1.get_length() > 0.1, "first lingpet egg-hit bone-break SFX should load as a playable Godot AudioStream")
	_expect(egg_hit_stream_2 != null and egg_hit_stream_2.get_length() > 0.1, "second lingpet egg-hit bone-break SFX should load as a playable Godot AudioStream")
	_expect(combat_audio_source.find("const EGG_HIT_STREAM_PATHS") >= 0, "combat-audio owner should register the lingpet egg-hit bone-break sound path list")
	_expect(combat_audio_source.find("egg_hit_streams = _load_audio_stream_candidates(EGG_HIT_STREAM_PATHS)") >= 0, "combat-audio owner should load both egg-hit candidate streams for random selection")
	_expect(game_audio_source.find("func play_lingpet_egg_hit") >= 0, "GameAudio should expose a lingpet egg-hit play method")
	_expect(game_audio_source.find("lingpet_combat_audio.get_candidate_streams(\"egg_hit\")") >= 0, "GameAudio egg-hit facade should consume both focused random candidates")
	var egg_hit_dispatcher_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_audio_dispatcher.gd")
	_expect(egg_hit_dispatcher_source.find("func play_lingpet_egg_hit") >= 0, "audio dispatcher should own a lingpet egg-hit dispatch method")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_egg_hit") >= 0, "lingpet runtime should dispatch the egg-hit SFX when the ball strikes the egg")
	var egg_hit_item_egg_lifecycle_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_item_egg_lifecycle_state.gd")
	_expect(egg_hit_item_egg_lifecycle_source.find("on_ball_hit") >= 0, "coexisting item egg should forward a ball-hit callback so it plays the same hit SFX")


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
	_expect(all_catalog_pet_ids.has("nekuring"), "catalog should keep the Nekuring lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("nekuring"), "Nekuring should appear in enabled pet ids after production promotion")
	_expect(candidates.has("nekuring"), "Nekuring should enter the random hatch pool after production promotion")
	_expect(LingpetCatalog.is_pet_enabled("nekuring"), "Nekuring should be treated as a live pet")
	_expect(all_catalog_pet_ids.has("milkring"), "catalog should keep the Milkring lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("milkring"), "Milkring should appear in enabled pet ids after companion/cut-in/click assets ship")
	_expect(candidates.has("milkring"), "Milkring should enter the random hatch pool after live catalog integration")
	_expect(LingpetCatalog.is_pet_enabled("milkring"), "Milkring should be treated as a live pet")
	_expect(all_catalog_pet_ids.has("volty"), "catalog should keep the Volty lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("volty"), "Volty should appear in enabled pet ids after companion/cut-in/click assets ship")
	_expect(candidates.has("volty"), "Volty should enter the random hatch pool after live catalog integration")
	_expect(LingpetCatalog.is_pet_enabled("volty"), "Volty should be treated as a live pet")
	_expect(all_catalog_pet_ids.has("orbi"), "catalog should keep the Serabi lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("orbi"), "Serabi should be enabled after the Gravity Accel skill port")
	_expect(candidates.has("orbi"), "Serabi should enter the random hatch pool after the Gravity Accel skill port")
	_expect(LingpetCatalog.is_pet_enabled("orbi"), "Serabi should be treated as a live pet")
	_expect(all_catalog_pet_ids.has("orosha"), "catalog should keep the Orosha lingpet metadata")
	_expect(enabled_catalog_pet_ids.has("orosha"), "Orosha should be enabled after Star Coil production promotion")
	_expect(candidates.has("orosha"), "Orosha should enter the random hatch pool after Star Coil production promotion")
	_expect(LingpetCatalog.is_pet_enabled("orosha"), "Orosha should be treated as a live pet")
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
	_expect(
		maribo_passive_pool.size() == 6
		and maribo_passive_ids.has("lingpet_resonance_boost")
		and maribo_passive_ids.has("lingpet_afterglow_leak")
		and maribo_passive_ids.has("lingpet_tailwind_steps")
		and maribo_passive_ids.has("lingpet_starlight_tracking")
		and maribo_passive_ids.has("lingpet_ring_dash")
		and maribo_passive_ids.has("lingpet_light_eater"),
		"Maribo should expose the six approved shared passives"
	)
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
	var broken_windup_pool: Array = broken_windup_entry["active_skill_pool"] as Array
	var broken_windup_skill: Dictionary = broken_windup_pool[0] as Dictionary
	broken_windup_skill["windup_seconds"] = -0.25
	var broken_windup_issues: Array[String] = LingpetCatalog.validate_entries(broken_windup_entries, false)
	_expect(_issues_contain(broken_windup_issues, "active_skill_pool[0].windup_seconds must be >= 0"), "catalog validator should catch invalid active-skill wind-up timing")
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
	_expect(LingpetCatalog.get_display_name("nekuring") == "네쿠링", "catalog should expose Nekuring as the visible name for the nekuring debug id")
	_expect(LingpetCatalog.get_display_name("rabi") == "모락모랑", "catalog should expose Morakmorang as the visible name for the rabi runtime id")
	_expect(str(LingpetCatalog.get_visual_path("maribo", "egg")).ends_with("guardian_spirit_egg_traditional_variant_0_v1.png"), "catalog should own the current shared traditional guardian-spirit egg visual path")
	_expect(str(LingpetCatalog.get_visual_path("lunabi", "egg")).ends_with("guardian_spirit_egg_traditional_variant_0_v1.png"), "Lunabi should hatch from the same shared traditional guardian-spirit egg visual path")
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
	_expect(str(LingpetCatalog.get_visual_path("orbi", "companion_walk")).ends_with("orbi_companion_walk.png"), "catalog should own Serabi companion walk visual path")
	_expect(str(LingpetCatalog.get_visual_path("orbi", "companion_strike")).ends_with("orbi_companion_strike.png"), "catalog should own Serabi companion strike visual path")
	# Decoupled (2026-06-24): koyora / nekuring / monkeyring / orosha use dedicated
	# 14x7/98 dismiss sheets at 512px cells. Panel click Live2D sheets that are
	# not reused by fullscreen dismiss may ship as 4096px VRAM-compressed imports;
	# koyora stays uncapped until explicitly moved.
	for _dc_entry in [
		{"pet": "nekuring", "click": "nekuring_click_live2d_pingpong_98f"},
		{"pet": "koyora", "click": "koyora_click_live2d_pingpong_98f"},
		{"pet": "monkeyring", "click": "monkeyring_click_live2d_pingpong_98f"},
		{"pet": "orosha", "click": "orosha_click_rolling_autosprite_98f"},
	]:
		var _dc_pet: String = str(_dc_entry["pet"])
		var _dc_click: String = str(_dc_entry["click"])
		_expect(str(LingpetCatalog.get_visual_path(_dc_pet, "cutin_dismiss_anim")).ends_with("%s_cutin_dismiss_anim.png" % _dc_pet), "catalog should route %s's hatch click-dismiss to a dedicated sheet (decoupled from the full-res click sheet so the hatch prewarm stays small)" % _dc_pet)
		_expect(FileAccess.file_exists("res://assets/sprites/lingpet/%s_cutin_dismiss_anim.png" % _dc_pet), "%s should ship a dedicated click-dismiss sheet separate from the full-res click Live2D" % _dc_pet)
		var _dc_dismiss_tex: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/%s_cutin_dismiss_anim.png" % _dc_pet)
		var _dc_w: int = _dc_dismiss_tex.get_width() if _dc_dismiss_tex != null else 0
		var _dc_h: int = _dc_dismiss_tex.get_height() if _dc_dismiss_tex != null else 0
		_expect(_dc_dismiss_tex != null and _dc_w == 7168 and _dc_h == 3584, "%s dismiss must be a dedicated 14x7 / 98-frame 512-cell sheet, not the old 5x5/25 low-fps sheet nor the full-res click sheet" % _dc_pet)
		var _dc_dismiss_import := FileAccess.get_file_as_string("res://assets/sprites/lingpet/%s_cutin_dismiss_anim.png.import" % _dc_pet)
		_expect(_dc_dismiss_import.find("process/size_limit=0") >= 0, "%s dedicated dismiss import should not be downscaled after the 512-cell repack" % _dc_pet)
		_expect(_dc_dismiss_import.find("compress/mode=2") >= 0 and _dc_dismiss_import.find("\"vram_texture\": true") >= 0, "%s dedicated 98-frame dismiss sheet should be VRAM-compressed for hatch prewarm" % _dc_pet)
		_expect(str(LingpetCatalog.get_visual_path(_dc_pet, "click_reaction_anim")).ends_with("%s.png" % _dc_click), "catalog should keep %s's panel click on the full-res click sheet" % _dc_pet)
		var _dc_click_import := FileAccess.get_file_as_string("res://assets/sprites/lingpet/%s.png.import" % _dc_click)
		if _dc_pet in ["nekuring", "monkeyring", "orosha"]:
			_expect(_dc_click_import.find("process/size_limit=4096") >= 0, "%s panel click Live2D import should use the 4096px cap after fullscreen dismiss was decoupled" % _dc_pet)
			_expect(_dc_click_import.find("compress/mode=2") >= 0 and _dc_click_import.find("\"vram_texture\": true") >= 0, "%s panel click Live2D import should be VRAM-compressed after the 4096px cap policy" % _dc_pet)
		else:
			_expect(_dc_click_import.find("process/size_limit=0") >= 0, "%s full click Live2D import should stay uncapped until its panel policy is explicitly moved" % _dc_pet)
		var _dc_seconds: float = float(LingpetCatalog.get_visual_layout_value(_dc_pet, "cutin_dismiss_seconds", 3.35))
		var _dc_action_portion: float = float(LingpetCatalog.get_visual_layout_value(_dc_pet, "cutin_dismiss_action_portion", 0.74))
		var _dc_effective_fps: float = 98.0 / maxf(0.01, _dc_seconds * _dc_action_portion)
		_expect(_dc_effective_fps >= 22.0, "%s dismiss should have enough source frames for the long action window (effective fps %.2f)" % [_dc_pet, _dc_effective_fps])
	var _lunabi_click_import := FileAccess.get_file_as_string("res://assets/sprites/lingpet/lunabi_click_live2d_pingpong_98f.png.import")
	var _lunabi_dismiss_path := str(LingpetCatalog.get_visual_path("lunabi", "cutin_dismiss_anim"))
	var _lunabi_click_path := str(LingpetCatalog.get_visual_path("lunabi", "click_reaction_anim"))
	_expect(_lunabi_dismiss_path.ends_with("lunabi_cutin_dismiss_anim.png") and _lunabi_dismiss_path != _lunabi_click_path, "Lunabi fullscreen dismiss should stay decoupled from the panel click Live2D sheet")
	_expect(FileAccess.file_exists(_lunabi_dismiss_path), "Lunabi should ship the dedicated fullscreen dismiss sheet used by the decoupled catalog path")
	_expect(_lunabi_click_import.find("process/size_limit=4096") >= 0, "Lunabi panel click Live2D import should keep the 4096px cap because fullscreen dismiss is decoupled")
	_expect(_lunabi_click_import.find("compress/mode=2") >= 0 and _lunabi_click_import.find("\"vram_texture\": true") >= 0, "Lunabi panel click Live2D import should be VRAM-compressed for stage-entry prewarm")
	for _alias_pet in [
		{"pet": "onimaru", "click": "onimaru_click_live2d_autosprite_98f_amber_gripfix"},
		{"pet": "rahoset", "click": "rahoset_click_ritual_linked_v2_autosprite_98f"},
	]:
		var _alias_pet_id: String = str(_alias_pet["pet"])
		var _alias_click: String = str(_alias_pet["click"])
		_expect(str(LingpetCatalog.get_visual_path(_alias_pet_id, "cutin_dismiss_anim")).ends_with("%s.png" % _alias_click), "%s should still document the click-sheet fullscreen dismiss alias" % _alias_pet_id)
		var _alias_click_import := FileAccess.get_file_as_string("res://assets/sprites/lingpet/%s.png.import" % _alias_click)
		_expect(_alias_click_import.find("process/size_limit=0") >= 0, "%s click sheet should stay uncapped while fullscreen dismiss still aliases it" % _alias_pet_id)
		if _alias_pet_id == "rahoset":
			_expect(_alias_click_import.find("compress/mode=2") >= 0 and _alias_click_import.find("\"vram_texture\": true") >= 0, "Rahoset aliased full-res click/dismiss sheet should stay uncapped but VRAM-compressed")
		else:
			_expect(_alias_click_import.find("compress/mode=0") >= 0 and _alias_click_import.find("\"vram_texture\": false") >= 0, "Onimaru aliased full-res click/dismiss sheet should stay uncapped and lossless until dismiss decouples")
	# These four dedicated sheets are 14x7/98, so they must carry the same grid override
	# as the backlog 98-frame dismiss pets. A stale default would slice them as 5x5/25.
	var _dismiss_host_source: String = FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	for _dc_98_pet in ["koyora", "nekuring", "monkeyring", "orosha"]:
		_expect(_dismiss_host_source.find("\"%s\": 14" % _dc_98_pet) >= 0 and _dismiss_host_source.find("\"%s\": 98" % _dc_98_pet) >= 0, "%s must carry the 14x7/98 dismiss override for its dedicated 98-frame sheet" % _dc_98_pet)
	_expect(_dismiss_host_source.find("\"rabi\": 14") >= 0 and _dismiss_host_source.find("\"rabi\": 98") >= 0, "rabi (still reusing its 14x7/98 click sheet as the dismiss) should keep the 14x7/98 override")
	_expect(str(LingpetCatalog.get_visual_path("nekuring", "click_reaction_anim")).ends_with("nekuring_click_live2d_pingpong_98f.png"), "catalog should route Nekuring's panel click Live2D to the full 98-frame click sheet")
	_expect(str(LingpetCatalog.get_visual_path("nekuring", "companion_click_reaction_anim")).ends_with("nekuring_companion_click_reaction_98f.png"), "catalog should route Nekuring's in-battle companion click to the downscaled 98-frame sheet")
	ProjectResourceLoader.clear_caches()
	var nekuring_imported_click_texture: Texture2D = ProjectResourceLoader.load_imported_texture("res://assets/sprites/lingpet/nekuring_click_live2d_pingpong_98f.png")
	_expect(nekuring_imported_click_texture != null and nekuring_imported_click_texture.get_width() <= 4096 and nekuring_imported_click_texture.get_width() >= 4000 and is_equal_approx(float(nekuring_imported_click_texture.get_width()) / float(maxi(1, nekuring_imported_click_texture.get_height())), 2.0), "Nekuring imported panel click Live2D should load through the 4096px / 14x7 runtime cap")
	ProjectResourceLoader.clear_caches()
	var nekuring_companion_click_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/lingpet/nekuring_companion_click_reaction_98f.png")
	_expect(nekuring_companion_click_texture != null and nekuring_companion_click_texture.get_width() == 1792 and nekuring_companion_click_texture.get_height() == 896, "Nekuring companion click Live2D should load as a 14x7 / 98-frame 128-cell sheet")
	var nekuring_click_manifest_source: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_click_live2d_pingpong_98f_manifest.json")
	_expect(nekuring_click_manifest_source.find("\"frame_count\": 98") >= 0 and nekuring_click_manifest_source.find("\"final_cell_size\": [") >= 0 and nekuring_click_manifest_source.find("1152") >= 0 and nekuring_click_manifest_source.find("\"realesrgan_upscale\"") >= 0 and nekuring_click_manifest_source.find("\"final_cells_with_edge_touch\": []") >= 0, "Nekuring full click Live2D manifest should pin the 98-frame clean-edge HQ runtime grid")
	_expect(is_equal_approx(LingpetCatalog.get_visual_layout_value("maribo", "companion_walk_draw_size", 0.0), 104.0), "catalog should upscale Maribo's refreshed walk sheet to match strike/cast scale")
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
	_expect(LingpetCatalog.get_active_skill_entry("orbi_ring_orbit").is_empty(), "catalog should no longer expose Serabi's removed Ring Orbit skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("orbi_gravity_accel").get("runtime_kind", "")) == "gravity_accel", "catalog should expose Serabi's Gravity Accel runtime kind by skill id")
	_expect(LingpetCatalog.get_active_skill_pool("orbi").size() == 2, "Serabi should expose a 2-skill active pool (gravity_accel + dwarf_magic)")
	var orbi_gravity_lv1: Dictionary = LingpetCatalog.get_active_skill("orbi", "orbi_gravity_accel", 1)
	var orbi_gravity_lv5: Dictionary = LingpetCatalog.get_active_skill("orbi", "orbi_gravity_accel", 5)
	_expect(float(orbi_gravity_lv5.get("duration_seconds", 0.0)) > float(orbi_gravity_lv1.get("duration_seconds", 0.0)), "Serabi Gravity Accel duration should grow with level")
	_expect(float(orbi_gravity_lv5.get("gravity_strength", 0.0)) > float(orbi_gravity_lv1.get("gravity_strength", 0.0)), "Serabi Gravity Accel strength should grow with level")
	_expect(str(LingpetCatalog.get_active_skill_entry("orbi_dwarf_magic").get("runtime_kind", "")) == "dwarf_magic", "catalog should expose Serabi's Dwarf Magic runtime kind by skill id")
	_expect(LingpetSkillDispatcher.is_dwarf_magic("orbi_dwarf_magic"), "skill dispatcher should route Serabi's Dwarf Magic through the dwarf_magic runtime")
	var orbi_dwarf_lv1: Dictionary = LingpetCatalog.get_active_skill("orbi", "orbi_dwarf_magic", 1)
	var orbi_dwarf_lv5: Dictionary = LingpetCatalog.get_active_skill("orbi", "orbi_dwarf_magic", 5)
	_expect(float(orbi_dwarf_lv5.get("shrink_scale", 1.0)) < float(orbi_dwarf_lv1.get("shrink_scale", 1.0)), "Serabi Dwarf Magic should shrink the boss more at higher level")
	_expect(float(orbi_dwarf_lv5.get("shrink_duration", 0.0)) > float(orbi_dwarf_lv1.get("shrink_duration", 0.0)), "Serabi Dwarf Magic shrink should last longer at higher level")
	_expect(float(orbi_dwarf_lv5.get("boss_slow_multiplier", 1.0)) < float(orbi_dwarf_lv1.get("boss_slow_multiplier", 1.0)), "Serabi Dwarf Magic should slow the boss more at higher level")
	_expect(LingpetCatalog.get_active_skill_entry("nekuring_ghost_summon").is_empty(), "catalog should no longer expose Nekuring's removed Skeleton Summon skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("nekuring_skeleton_archer").get("runtime_kind", "")) == "skeleton_archer", "catalog should expose Nekuring's Skeleton Archer runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("nekuring_bone_barrier").get("runtime_kind", "")) == "bone_barrier", "catalog should expose Nekuring's Bone Barrier runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("monkeyring_banana_slice").get("runtime_kind", "")) == "banana_slice", "catalog should expose Ppanamong's Banana Slice runtime kind by skill id")
	_expect(str(LingpetCatalog.get_active_skill_entry("onimaru_headbutt").get("runtime_kind", "")) == "headbutt", "catalog should route Onimaru's 뿔박치기 through the shared headbutt runtime")
	_expect(LingpetSkillDispatcher.is_headbutt("onimaru_headbutt"), "skill dispatcher should resolve Onimaru's 뿔박치기 to the headbutt module via catalog runtime_kind")
	var onimaru_headbutt_lv1: Dictionary = LingpetCatalog.get_active_skill("onimaru", "onimaru_headbutt", 1)
	var onimaru_headbutt_lv5: Dictionary = LingpetCatalog.get_active_skill("onimaru", "onimaru_headbutt", 5)
	_expect(str(onimaru_headbutt_lv1.get("name", "")) == "뿔박치기", "Onimaru active skill should be named 뿔박치기")
	_expect(float(onimaru_headbutt_lv1.get("disable_moving_miss", 0.0)) > 0.5, "Onimaru 뿔박치기 should disable the random moving-target miss roll, unlike the Lunabi template")
	_expect(int(round(float(onimaru_headbutt_lv1.get("headbutt_count", 0.0)))) == 1 and int(round(float(onimaru_headbutt_lv5.get("headbutt_count", 0.0)))) == 1, "Onimaru 뿔박치기 should stay a single committed headbutt at every level (no Lunabi combo)")
	_expect(float(onimaru_headbutt_lv5.get("mega_chance", -1.0)) == 0.0, "Onimaru 뿔박치기 should never roll the random Lunabi mega charge")
	_expect(float(onimaru_headbutt_lv5.get("dash_radius", 0.0)) > float(onimaru_headbutt_lv1.get("dash_radius", 0.0)), "Onimaru 뿔박치기 reach/hit radius should widen with level")
	_expect(is_equal_approx(float(onimaru_headbutt_lv1.get("hit_stun_seconds", 0.0)), 2.0) and is_equal_approx(float(onimaru_headbutt_lv5.get("hit_stun_seconds", 0.0)), 3.5), "Onimaru 뿔박치기 boss stun should grow Lv.1 2.0s → Lv.5 3.5s")
	_expect(is_equal_approx(float(onimaru_headbutt_lv1.get("self_stun_seconds", 0.0)), 5.0) and is_equal_approx(float(onimaru_headbutt_lv5.get("self_stun_seconds", 0.0)), 2.0), "Onimaru 뿔박치기 self-stun should shrink Lv.1 5.0s → Lv.5 2.0s")
	# Onimaru headbutt RUNTIME behavior (fixed wall target / dodgeable empty slam,
	# per-hit stun, self-stun + body-hit suppression) is owned by the dedicated
	# lingpet_headbutt_skill_smoke.gd.
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
	_expect(not LingpetSkillDispatcher.is_moon_orbit("orbi_ring_orbit"), "skill dispatcher should not route Serabi's removed Ring Orbit skill through moon_orbit")
	_expect(LingpetSkillDispatcher.is_gravity_accel("orbi_gravity_accel"), "skill dispatcher should route Serabi's Gravity Accel skill through the gravity_accel runtime")
	_expect(LingpetSkillDispatcher.is_supported_kind("gravity_accel"), "skill dispatcher should expose Serabi's gravity_accel runtime kind")
	_expect(not LingpetSkillDispatcher.is_ghost_summon("nekuring_ghost_summon"), "skill dispatcher should not route Nekuring's removed Skeleton Summon skill through ghost_summon")
	_expect(LingpetSkillDispatcher.is_skeleton_archer("nekuring_skeleton_archer"), "skill dispatcher should route Nekuring's Skeleton Archer skill through the skeleton_archer runtime")
	_expect(LingpetSkillDispatcher.is_bone_barrier("nekuring_bone_barrier"), "skill dispatcher should route Nekuring's Bone Barrier skill through the bone_barrier runtime")
	_expect(LingpetSkillDispatcher.is_banana_slice("monkeyring_banana_slice"), "skill dispatcher should route Ppanamong's Banana Slice skill through the banana_slice runtime")
	_expect(LingpetSkillDispatcher.is_supported_kind("hydro_sphere"), "skill dispatcher should expose supported runtime kinds for future lingpet skill modules")
	_expect(LingpetSkillDispatcher.is_supported_kind("headbutt"), "skill dispatcher should expose the Lunabi headbutt runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("milk_production"), "skill dispatcher should expose Milkring's milk-production runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("thunder_orb"), "skill dispatcher should expose Lumion's Thunder Orb runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("bomb_surprise"), "skill dispatcher should expose Volty's Bomb Surprise runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("gatling_burst"), "skill dispatcher should expose Volty's Gatling Burst runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("dragon_breath"), "skill dispatcher should expose Red Dragon's Dragon Breath runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("bone_barrier"), "skill dispatcher should expose Nekuring's bone-barrier runtime kind")
	_expect(LingpetSkillDispatcher.is_supported_kind("banana_slice"), "skill dispatcher should expose Ppanamong's banana-slice runtime kind")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var dispatcher_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
	var skill_runtime_host_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	var skill_runtime_surface_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")
	var skill_controller_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
	var skill_update_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_update_context_builder.gd")
	var skill_persistence_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
	var companion_runtime_resetter_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_runtime_resetter.gd")
	var round_resetter_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_round_resetter.gd")
	var affinity_hit_tag_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_hit_tag_resolver.gd")
	var hatch_stat_roll_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hatch_stat_roll_state.gd")
	var current_loadout_applier_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
	var distance_roll_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_distance_roll_state.gd")
	var body_presence_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
	var companion_motion_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_motion_state.gd")
	var collection_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_collection_state.gd")
	var save_restore_applier_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_save_restore_applier.gd")
	var tutorial_bootstrap_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_tutorial_bootstrap.gd")
	var current_profile_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_profile.gd")
	var profile_runtime_surface_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_profile_runtime_surface.gd")
	var current_visual_prewarm_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_visual_prewarm_coordinator.gd")
	var overflow_choice_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_overflow_choice_state.gd")
	var overflow_replace_plan_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_overflow_replace_plan.gd")
	var overflow_release_plan_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_overflow_release_plan.gd")
	var item_egg_absorb_router_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_item_egg_absorb_router.gd")
	var item_egg_lifecycle_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_item_egg_lifecycle_state.gd")
	var loadout_state_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_loadout_state.gd")
	var none_owner_sync_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_none_owner_sync_state.gd")
	_expect(runtime_source.find("lingpet_collection_state.gd") >= 0, "egg runtime should delegate owned collection + hatch candidate selection to the collection-state helper")
	_expect(collection_source.find("LingpetCatalog.pick_hatch_pet_id") >= 0, "collection-state helper should pick the hidden egg identity through the catalog")
	_expect(collection_source.find("func should_spawn_egg") >= 0, "collection-state helper should own hatch-candidate availability checks")
	_expect(collection_source.find("func is_auto_present_league") >= 0, "collection-state helper should own Junior auto-present league checks")
	_expect(collection_source.find("func ensure_pet_active_slot") >= 0, "collection-state helper should own owned-pet active battle-slot placement")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_collection_state.gd"), "lingpet collection-state helper should exist")
	_expect(runtime_source.find("func _should_spawn_lingpet_egg") < 0, "egg runtime should not keep a thin hatch-candidate availability wrapper after collection-state delegation")
	_expect(runtime_source.find("func _pick_hatch_pet_id") < 0, "egg runtime should not keep a thin hatch-selection wrapper after collection-state delegation")
	_expect(runtime_source.find("func _is_lingpet_auto_present_league") < 0, "egg runtime should not keep a thin auto-present league wrapper after collection-state delegation")
	_expect(runtime_source.find("_collection_state.should_spawn_egg") >= 0, "egg runtime should ask collection-state directly when gating automatic or plaza egg spawns")
	_expect(runtime_source.find("_collection_state.pick_hatch_pet_id") >= 0, "egg runtime should ask collection-state directly when selecting the hidden egg identity")
	_expect(runtime_source.find("_collection_state.is_auto_present_league") >= 0, "egg runtime should ask collection-state directly when gating Junior auto-present behavior")
	_expect(runtime_source.find("func _find_first_owned_pet_id") < 0, "egg runtime should not keep an unused first-owned-pet wrapper after collection-state delegation")
	_expect(runtime_source.find("func _find_active_slot_pet_id") < 0, "egg runtime should not keep a single-use active-slot pet lookup wrapper after collection-state delegation")
	_expect(runtime_source.find("func _mark_current_pet_owned") < 0, "egg runtime should not keep a current-pet ownership pass-through wrapper after collection-state delegation")
	_expect(runtime_source.find("func _mark_pet_owned") < 0, "egg runtime should not keep an owned-pet pass-through wrapper after collection-state delegation")
	_expect(runtime_source.find("func _select_current_pet_slot") < 0, "egg runtime should not keep a current-pet active-slot pass-through wrapper after collection-state delegation")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_none_owner_sync_state.gd"), "none owner-sync gate helper should exist")
	_expect(none_owner_sync_source.find("func update_none_state") >= 0 and none_owner_sync_source.find("func should_sync_once") >= 0 and none_owner_sync_source.find("func reset") >= 0, "none owner-sync gate should own STATE_NONE update policy and the once-per-none-state sync latch")
	_expect(runtime_source.find("var _has_synced_none") < 0, "egg runtime should not keep raw none-state owner-sync latch")
	_expect(runtime_source.find("func _update_none_state") < 0, "egg runtime should not keep a private STATE_NONE update helper")
	_expect(runtime_source.find("_none_owner_sync_state.update_none_state") >= 0, "egg runtime should delegate STATE_NONE update policy to the none owner-sync helper")
	var none_sync_gate := LingpetNoneOwnerSyncState.new()
	_expect(bool(none_sync_gate.should_sync_once()), "none owner-sync gate should allow the first sync")
	_expect(not bool(none_sync_gate.should_sync_once()), "none owner-sync gate should block repeat syncs until reset")
	none_sync_gate.reset()
	_expect(bool(none_sync_gate.should_sync_once()), "none owner-sync gate reset should allow sync again")
	_expect(runtime_source.find("func _has_overflow_choice_pending") < 0, "egg runtime should not keep a single-use overflow-choice pending predicate wrapper")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_overflow_choice_state.gd"), "overflow choice state helper should exist")
	_expect(overflow_choice_source.find("func begin_main_overflow") >= 0 and overflow_choice_source.find("func begin_item_egg_overflow") >= 0, "overflow choice helper should own main-egg and item-egg overflow state setup")
	_expect(overflow_choice_source.find("func resolve_after_acquire_cutin") >= 0 and overflow_choice_source.find("mark_absorb_ready_if_awaiting") >= 0, "overflow choice helper should own acquire-cutin close routing between item-egg absorb and pending overflow activation")
	_expect(runtime_source.find("func _begin_item_egg_overflow") < 0, "egg runtime should not keep a single-use item-egg overflow setup wrapper")
	_expect(runtime_source.find("func _activate_overflow_choice_after_cutin") < 0, "egg runtime should not keep a private acquire-cutin completion router")
	_expect(runtime_source.find("_overflow_choice_state.resolve_after_acquire_cutin") >= 0, "egg runtime should ask the overflow choice owner to resolve acquire-cutin completion")
	_expect(overflow_choice_source.find("func build_snapshot") >= 0 and overflow_choice_source.find("pending_display_name") >= 0, "overflow choice helper should own modal snapshot payload assembly")
	_expect(overflow_choice_source.find("func consume_release_context") >= 0 and overflow_choice_source.find("func consume_commit_pet_id") >= 0, "overflow choice helper should own capture-before-reset release/commit context")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_overflow_release_plan.gd"), "overflow release plan helper should exist")
	_expect(overflow_release_plan_source.find("func consume") >= 0 and overflow_release_plan_source.find("consume_release_context") >= 0 and overflow_release_plan_source.find("ACTION_RESTORE_COMPANION") >= 0, "overflow release plan helper should own release context interpretation and restore action selection")
	_expect(overflow_release_plan_source.find("has_owned_pet") >= 0 and overflow_release_plan_source.find("ACTION_CLEAR_PENDING") >= 0, "overflow release plan helper should own restore-vs-clear release decision")
	var overflow_release_body := _function_body(runtime_source, "func commit_overflow_release")
	_expect(overflow_release_body.find("_overflow_release_plan.consume") >= 0, "overflow release commit should ask the release-plan owner for action routing")
	_expect(overflow_release_body.find("consume_release_context") < 0 and overflow_release_body.find("\"from_item_egg\"") < 0 and overflow_release_body.find("suspended_companion_pet_id") < 0, "overflow release commit should not interpret release context inline")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_overflow_replace_plan.gd"), "overflow replace plan helper should exist")
	_expect(overflow_replace_plan_source.find("func consume") >= 0 and overflow_replace_plan_source.find("is_item_egg_source") >= 0 and overflow_replace_plan_source.find("replace_slot") >= 0, "overflow replace plan helper should own replace context interpretation and main-slot replacement")
	_expect(overflow_replace_plan_source.find("ACTION_ITEM_EGG_REPLACE") >= 0 and overflow_replace_plan_source.find("ACTION_FINISH_MAIN_COMMIT") >= 0, "overflow replace plan helper should expose item-egg and main-commit actions")
	var overflow_replace_body := _function_body(runtime_source, "func commit_overflow_replace")
	_expect(overflow_replace_body.find("_overflow_replace_plan.consume") >= 0, "overflow replace commit should ask the replace-plan owner for action routing")
	_expect(overflow_replace_body.find("_collection_state.replace_slot") < 0 and overflow_replace_body.find("_overflow_choice_state.is_item_egg_source") < 0 and overflow_replace_body.find("_overflow_choice_state.get_pending_pet_id") < 0, "overflow replace commit should not interpret replace context inline")
	_expect(runtime_source.find("func get_overflow_choice_snapshot") >= 0 and runtime_source.find("_overflow_choice_state.build_snapshot") >= 0, "egg runtime should keep only the public overflow snapshot bridge")
	_expect(runtime_source.find("\"pending_display_name\"") < 0, "egg runtime should not assemble overflow modal display payloads inline")
	for overflow_field in ["_pending_overflow_choice", "_overflow_choice_active", "_pending_overflow_pet_id", "_suspended_companion_pet_id", "_overflow_from_item_egg"]:
		_expect(runtime_source.find("var %s" % overflow_field) < 0, "egg runtime should not keep raw overflow modal state fields (%s)" % overflow_field)
	for direct_overflow_field in [".active", ".pending_pet_id", ".from_item_egg", ".suspended_companion_pet_id"]:
		_expect(runtime_source.find("_overflow_choice_state%s" % direct_overflow_field) < 0, "egg runtime should not read overflow state fields directly (%s)" % direct_overflow_field)
	_expect(runtime_source.find("func _clear_overflow_choice_state") < 0, "egg runtime should not keep a private overflow-choice reset wrapper")
	_expect(runtime_source.find("_overflow_choice_state.has_pending_or_active()") >= 0, "egg runtime should gate egg offers/deploy/reset through the overflow choice state owner")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_item_egg_lifecycle_state.gd"), "item-egg lifecycle state helper should exist")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_item_egg_absorb_router.gd"), "item-egg absorb router should exist")
	_expect(item_egg_absorb_router_source.find("func route_absorbed_pet") >= 0 and item_egg_absorb_router_source.find("begin_item_egg_overflow") >= 0 and item_egg_absorb_router_source.find("add_pet_to_collection_keep_active") >= 0, "item-egg absorb router should own free-slot vs overflow routing")
	_expect(item_egg_absorb_router_source.find("func commit_overflow_replace") >= 0 and item_egg_absorb_router_source.find("replace_slot") >= 0 and item_egg_absorb_router_source.find("ensure_pet_active_slot") >= 0, "item-egg absorb router should own overflow replace slot routing and companion-slot preservation")
	_expect(item_egg_lifecycle_source.find("func begin_incubation") >= 0 and item_egg_lifecycle_source.find("func finish_incubation_for_reveal") >= 0 and item_egg_lifecycle_source.find("func consume_ready_absorb") >= 0, "item-egg lifecycle helper should own active/reveal/absorb state transitions")
	_expect(item_egg_lifecycle_source.find("LingpetCurrentProfile") >= 0 and item_egg_lifecycle_source.find("func get_profile") >= 0 and item_egg_lifecycle_source.find("func get_required_hits") >= 0, "item-egg lifecycle helper should own the dedicated incubator-egg profile")
	_expect(item_egg_lifecycle_source.find("func clear_runtime_state") >= 0 and item_egg_lifecycle_source.find("clear_display_pet_id") >= 0, "item-egg lifecycle helper should own full item-egg cleanup across lifecycle, field egg, absorb VFX, and reveal identity")
	_expect(item_egg_lifecycle_source.find("func advance_incubation_for_reveal") >= 0 and item_egg_lifecycle_source.find("resolve_ball_hit") >= 0, "item-egg lifecycle helper should own the coexisting item-egg tick-to-reveal transition")
	_expect(runtime_source.find("_item_egg_lifecycle_state") >= 0, "egg runtime should delegate coexisting item-egg lifecycle flags to the lifecycle helper")
	_expect(runtime_source.find("func _clear_item_egg_state") < 0, "egg runtime should not keep a private item-egg cleanup wrapper after lifecycle delegation")
	_expect(runtime_source.find("func _advance_item_egg") < 0 and runtime_source.find("func _on_item_egg_hatched") < 0, "egg runtime should not keep private item-egg tick/reveal wrappers after lifecycle delegation")
	_expect(runtime_source.find("_item_egg_lifecycle_state.clear_runtime_state") >= 0, "egg runtime should ask the item-egg lifecycle helper to clear coexisting item-egg runtime state")
	_expect(runtime_source.find("_item_egg_lifecycle_state.advance_incubation_for_reveal") >= 0, "egg runtime should ask the item-egg lifecycle helper to advance coexisting item eggs into reveal")
	_expect(runtime_source.find("_item_egg_absorb_router.route_absorbed_pet") >= 0, "egg runtime should ask the item-egg absorb router to register or overflow absorbed pets")
	var item_absorb_body := _function_body(runtime_source, "func _perform_item_egg_absorb")
	_expect(item_absorb_body.find("_collection_state.is_full") < 0 and item_absorb_body.find("add_pet_to_collection_keep_active") < 0 and item_absorb_body.find("begin_item_egg_overflow") < 0, "item-egg absorb should not keep collection full/free-slot/overflow routing inline")
	var item_overflow_replace_body := _function_body(runtime_source, "func _commit_item_egg_overflow_replace")
	_expect(item_overflow_replace_body.find("_item_egg_absorb_router.commit_overflow_replace") >= 0, "item-egg overflow replace should ask the absorb router to commit slot routing")
	_expect(item_overflow_replace_body.find("_collection_state.replace_slot") < 0 and item_overflow_replace_body.find("_collection_state.ensure_pet_active_slot") < 0, "item-egg overflow replace should not keep collection replace/active-slot routing inline")
	_expect(runtime_source.find("var _item_egg_profile") < 0, "egg runtime should not keep a raw coexisting item-egg profile")
	_expect(runtime_source.find("_item_egg_lifecycle_state.get_profile") >= 0 and runtime_source.find("_item_egg_lifecycle_state.get_required_hits") >= 0, "egg runtime should ask item-egg lifecycle for incubator profile reads")
	var item_lifecycle := LingpetItemEggLifecycleState.new()
	_expect(bool(item_lifecycle.begin_incubation("rabi")), "item-egg lifecycle should accept a valid incubator pet id")
	_expect(str(item_lifecycle.get_profile().pet_id) == "rabi", "item-egg lifecycle should update its dedicated profile when incubation starts")
	var item_absorb_router := LingpetItemEggAbsorbRouter.new()
	_expect(item_absorb_router != null, "item-egg absorb router should instantiate for runtime routing")
	for item_egg_field in ["_item_egg_active", "_item_egg_pet_id", "_item_egg_awaiting_absorb", "_item_egg_absorb_ready", "_item_egg_absorb_pet_id", "_item_egg_absorb_origin"]:
		_expect(runtime_source.find("var %s" % item_egg_field) < 0, "egg runtime should not keep raw coexisting item-egg lifecycle fields (%s)" % item_egg_field)
	_expect(companion_runtime_resetter_source.find("collection_state.ensure_pet_active_slot") >= 0, "companion runtime resetter should ask collection-state when marking/selecting the active lingpet")
	_expect(save_restore_applier_source.find("ensure_pet_active_slot") >= 0, "save-restore applier should republish restored owned pets through collection-state instead of runtime private hooks")
	_expect(save_restore_applier_source.find("_mark_current_pet_owned") < 0, "save-restore applier should not depend on the old runtime-owned-pet private hook")
	_expect(runtime_source.find("lingpet_tutorial_bootstrap.gd") >= 0, "egg runtime should delegate Junior Mika first-egg tutorial ring-core policy to a focused bootstrap helper")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_tutorial_bootstrap.gd"), "lingpet tutorial bootstrap helper should exist")
	_expect(runtime_source.find("func _grant_tutorial_standard_ring_core_if_needed") < 0, "egg runtime should not keep the tutorial ring-core grant policy after bootstrap delegation")
	_expect(runtime_source.find("func _is_tutorial_first_lingpet_egg") < 0, "egg runtime should not keep the tutorial first-egg eligibility policy after bootstrap delegation")
	_expect(runtime_source.find("_tutorial_bootstrap.grant_standard_ring_core_if_needed") >= 0, "egg runtime should call the tutorial bootstrap helper before spawning an automatic egg")
	_expect(int(LingpetTutorialBootstrap.STANDARD_RING_CORE_TIER) == 1, "tutorial bootstrap standard tier constant should stay at the shipped tutorial tier")
	_expect(tutorial_bootstrap_source.find("STANDARD_RING_CORE_TIER := 1") >= 0, "tutorial bootstrap should own the standard ring-core tutorial tier")
	_expect(tutorial_bootstrap_source.find("is_first_lingpet_egg_eligible") >= 0 and tutorial_bootstrap_source.find("upgrade_run_ring_core_tier") >= 0, "tutorial bootstrap should own first-egg eligibility and run-state ring-core upgrade")
	_expect(runtime_source.find("lingpet_current_profile.gd") >= 0, "egg runtime should delegate current pet catalog lookups to the current-profile helper")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_profile_runtime_surface.gd"), "profile runtime surface should exist for guarded companion stat/passive reads")
	_expect(runtime_source.find("lingpet_profile_runtime_surface.gd") >= 0 and runtime_source.find("_profile_runtime_surface") >= 0, "egg runtime should ask the profile runtime surface for repeated companion profile values")
	_expect(profile_runtime_surface_source.find("func build_runtime_surface") >= 0 and profile_runtime_surface_source.find("func get_catch_width") >= 0 and profile_runtime_surface_source.find("func get_passive_skill") >= 0, "profile runtime surface should own companion stat/passive surface assembly")
	_expect(runtime_source.find("LingpetCatalog") < 0, "egg runtime should not directly query the lingpet catalog after profile delegation")
	_expect(runtime_source.find("func _get_current_display_name") < 0, "egg runtime should not keep an unused current-profile display-name wrapper")
	for profile_wrapper in ["func _get_current_active_skill_pool", "func _get_current_passive_skill_pool", "func _get_current_player_speed_bonus_pct", "func _get_current_hit_half_width", "func _get_current_hit_half_height", "func _get_current_visual_texture", "func _get_current_cached_visual_texture", "func _get_current_passive_skill", "func _get_current_motion_style", "func _get_current_gauge_gain_bonus_pct", "func _get_current_required_hits", "func _get_current_stat", "func _get_current_hit_gauge_gain", "func _normalize_pet_id"]:
		_expect(runtime_source.find(profile_wrapper) < 0, "egg runtime should not keep single-use current-profile pass-through wrappers (%s)" % profile_wrapper)
	for profile_direct_call in [".get_required_hits(", ".get_stat(", ".get_hit_gauge_gain(", ".get_gauge_gain_bonus_pct(", ".get_player_speed_bonus_pct(", ".get_passive_skill(", ".get_motion_style(", ".get_active_skill_pool(", ".get_passive_skill_pool("]:
		_expect(runtime_source.find("_current_profile%s" % profile_direct_call) < 0, "egg runtime should route repeated current-profile companion reads through the profile runtime surface (%s)" % profile_direct_call)
	for unlock_wrapper in ["func _get_active_unlock_candidate_ids", "func _first_raw_candidates", "func _loadout_matches_unlock_reconcile"]:
		_expect(runtime_source.find(unlock_wrapper) < 0, "egg runtime should not keep old unlock reconciler test wrappers (%s)" % unlock_wrapper)
	_expect(current_profile_source.find("LingpetCatalog.get_stat") >= 0, "current-profile helper should own current pet stat lookup")
	_expect(current_profile_source.find("LingpetVisualTextureCache") >= 0, "current-profile helper should own visual-cache access for the selected pet")
	_expect(current_profile_source.find("_active_skill_cache_key") >= 0, "current-profile helper should cache resolved active-skill metadata for the companion hot path")
	_expect(current_profile_source.find("_passive_effect_cache") >= 0, "current-profile helper should cache passive effect lookups instead of reapplying level dictionaries per frame")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_current_visual_prewarm_coordinator.gd"), "current visual prewarm coordinator should exist")
	_expect(current_visual_prewarm_source.find("func prewarm_current") >= 0 and current_visual_prewarm_source.find("prewarm_visuals") >= 0 and current_visual_prewarm_source.find("prewarm_assets") >= 0, "current visual prewarm coordinator should own selected profile + companion renderer prewarm fanout")
	_expect(current_visual_prewarm_source.find("queue_if_companion") >= 0, "current visual prewarm coordinator should own companion click-reaction queue fanout")
	_expect(companion_runtime_resetter_source.find("current_visual_prewarm_coordinator.prewarm_current") >= 0, "companion runtime resetter should route current visual prewarm fanout through the coordinator")
	_expect(runtime_source.find("func _prewarm_current_visuals") < 0, "egg runtime should not keep a private current-visual prewarm wrapper")
	for loadout_runtime_field in ["_applied_loadout_key", "_synced_owner_loadout_key", "_skip_unlock_reconcile"]:
		_expect(runtime_source.find("var %s" % loadout_runtime_field) < 0, "egg runtime should not keep raw loadout runtime transient field (%s)" % loadout_runtime_field)
	_expect(loadout_state_source.find("func has_applied_runtime_cache") >= 0 and loadout_state_source.find("func should_skip_unlock_reconcile") >= 0, "loadout-state owner should expose runtime cache and unlock-reconcile skip helpers")
	_expect(current_loadout_applier_source.find("loadout_state.has_applied_runtime_cache") >= 0 and current_loadout_applier_source.find("loadout_state.should_skip_unlock_reconcile") >= 0, "current loadout applier should ask loadout-state owner for loadout runtime cache and debug reconcile skip")
	_expect(runtime_source.find("func _forget_pet_loadout") < 0, "egg runtime should not keep a private loadout-forget pass-through wrapper")
	_expect(runtime_source.find("_loadout_state.forget_pet_loadout_and_invalidate") >= 0, "egg runtime should ask the loadout-state owner to forget overflow pets with cache invalidation")
	for debug_stat_wrapper in ["func _get_current_patrol_speed", "func _get_current_defense_rate", "func _get_current_appearance_rate"]:
		_expect(runtime_source.find(debug_stat_wrapper) < 0, "egg runtime should not keep profile-aware debug stat pass-through wrappers (%s)" % debug_stat_wrapper)
	_expect(runtime_source.find("_debug_stat_overrides.get_patrol_speed") >= 0, "egg runtime should ask debug stat owner directly for profile-aware patrol speed")
	_expect(runtime_source.find("_debug_stat_overrides.get_defense_rate") >= 0, "egg runtime should ask debug stat owner directly for profile-aware defense rate")
	_expect(runtime_source.find("_debug_stat_overrides.get_appearance_rate") >= 0, "egg runtime should ask debug stat owner directly for profile-aware appearance rate")
	_expect(companion_motion_source.find("func resume_sortie_loiter_from_current") >= 0, "companion motion state should own sortie-loiter resume after Ring Dash")
	_expect(runtime_source.find("func _resume_companion_motion_after_ring_dash") < 0, "egg runtime should not keep a private ring-dash resume pass-through wrapper")
	_expect(runtime_source.find("_companion_motion_state.resume_sortie_loiter_from_current") >= 0, "egg runtime should call the motion-state owner directly when Ring Dash releases position control")
	var current_profile := LingpetCurrentProfile.new()
	_expect(str(current_profile.set_pet_id("unknown_pet")) == "maribo", "current-profile helper should fall back to the default pet for unknown ids")
	_expect(is_equal_approx(current_profile.get_visual_layout_value("companion_walk_draw_size", 0.0), 104.0), "current-profile helper should expose current pet visual-layout overrides")
	_expect(is_equal_approx(float(current_profile.get_hit_gauge_gain(0.0)), 40.0), "current-profile helper should expose current pet hit gauge gain")
	_expect(runtime_source.find("_update_companion_skill_effects") >= 0, "egg runtime should keep a narrow companion active-skill update hook")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_active_skill_slot_resolver.gd"), "active skill slot resolver should exist for second-active slot policy")
	_expect(skill_controller_source.find("skill_runtime_surface.get_active_slot_count") >= 0, "skill controller should ask the skill-runtime surface for active slot count")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_active_slot_count") < 0, "egg runtime should not reassemble active slot count inline")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_skill_id_for_slot") < 0, "egg runtime should ask the skill-runtime surface for per-slot skill ids")
	_expect(skill_controller_source.find("skill_runtime_surface.get_active_skill_ids") >= 0, "skill controller should ask the skill-runtime surface for runtime active skill id lists")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_active_skill_ids_for_runtime") < 0, "egg runtime should not reassemble runtime active skill id lists inline")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_active_skill_for_slot") < 0, "egg runtime should ask the skill-runtime surface for active skill dictionaries")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_skill_windup_seconds_for_slot") < 0, "egg runtime should ask the skill-runtime surface for per-slot windup seconds")
	for active_slot_wrapper in ["func _get_active_skill_for_slot", "func _get_skill_windup_seconds_for_slot", "func _get_skill_id_for_slot", "func _get_active_slot_count", "func _get_active_skill_ids_for_runtime"]:
		_expect(runtime_source.find(active_slot_wrapper) < 0, "egg runtime should not keep single-use active-slot resolver pass-through wrappers (%s)" % active_slot_wrapper)
	_expect(runtime_source.find("BattleSceneOwnerReader.get_value") >= 0, "egg runtime should read owner values through the shared owner reader directly")
	_expect(runtime_source.find("func _get_owner_value") < 0, "egg runtime should not keep a single-use owner-reader pass-through wrapper")
	for affinity_pet_id_wrapper in ["func _resolve_affinity_pet_id", "func _get_active_affinity_pet_id"]:
		_expect(runtime_source.find(affinity_pet_id_wrapper) < 0, "egg runtime should resolve affinity pet ids at the public call site instead of keeping private pass-through wrappers (%s)" % affinity_pet_id_wrapper)
	_expect(runtime_source.find("lingpet_companion_skill_controller.gd") >= 0, "egg runtime should delegate companion active-skill arm/launch decisions to the skill controller")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_skill_controller.gd"), "companion skill controller should exist for future lingpet active skills")
	_expect(skill_controller_source.find("func update_active_slots") >= 0, "companion skill controller should own full active-slot update orchestration")
	_expect(skill_controller_source.find("ACTION_ARM") >= 0 and skill_controller_source.find("ACTION_LAUNCH") >= 0, "companion skill controller should own active-skill action decisions")
	_expect(skill_controller_source.find("LingpetSkillDispatcher.has_supported_runtime") >= 0, "companion skill controller should guard supported runtime skill ids")
	_expect(skill_controller_source.find("LingpetCompanionSkillArmGate") >= 0 and skill_controller_source.find("_arm_gate.can_arm") >= 0, "companion skill controller should own cross-slot arm-gate mediation")
	_expect(skill_update_context_source.find("\"slot_index\"") >= 0 and skill_update_context_source.find("\"active_skill_ids\"") >= 0 and skill_update_context_source.find("\"skill_states\"") >= 0, "companion skill update context should carry slot data for controller-owned arm gating")
	_expect(runtime_source.find("var _companion_skill_arm_gate") < 0, "egg runtime should not keep a companion skill arm-gate instance outside the controller")
	_expect(skill_persistence_source.find("func is_any_winding_up") >= 0, "companion skill persistence should own shared windup-active checks")
	_expect(skill_persistence_source.find("func get_state_for_slot") >= 0, "companion skill persistence should own clamped skill-state slot lookup")
	_expect(skill_persistence_source.find("func reset_runtime_transients") >= 0, "companion skill persistence should own skill host runtime transient resets")
	_expect(skill_persistence_source.find("var state_by_pet_id") >= 0, "companion skill persistence should own the stored per-pet skill-state dictionary")
	_expect(runtime_source.find("var _companion_skill_state_by_pet_id") < 0, "egg runtime should not expose a raw stored skill-state dictionary alias")
	_expect(runtime_source.find("func _is_any_companion_skill_winding_up") < 0, "egg runtime should not keep a single-use companion skill windup predicate wrapper")
	_expect(runtime_source.find("_companion_skill_persistence.is_any_winding_up") >= 0, "egg runtime should ask skill persistence directly when motion needs the windup gate")
	_expect(runtime_source.find("func _get_companion_skill_state_for_slot") < 0, "egg runtime should not keep a private companion skill slot accessor wrapper")
	_expect(runtime_source.find("_companion_skill_persistence.get_state_for_slot") < 0, "egg runtime should ask the skill-runtime surface for clamped skill-state slot lookup")
	_expect(runtime_source.find("func _cancel_companion_skill_windups") < 0, "egg runtime should not keep a single-use companion skill windup-cancel wrapper")
	_expect(runtime_source.find("func _reset_companion_skill_round_transients") < 0, "egg runtime should not keep a single-use companion skill round-reset wrapper")
	_expect(runtime_source.find("func _reset_companion_skill_states") < 0, "egg runtime should not keep a single-use companion skill state-reset wrapper")
	_expect(runtime_source.find("func _reset_skill_runtime_transients") < 0, "egg runtime should not keep a private skill runtime transient reset wrapper")
	_expect(runtime_source.find("func _save_current_companion_skill_state") < 0, "egg runtime should not keep a current-skill-state save pass-through wrapper")
	_expect(runtime_source.find("func _restore_current_companion_skill_state") < 0, "egg runtime should not keep a current-skill-state restore pass-through wrapper")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_companion_runtime_resetter.gd"), "companion runtime resetter should exist")
	_expect(companion_runtime_resetter_source.find("func reset_state") >= 0 and companion_runtime_resetter_source.find("reset_runtime_transients") >= 0 and companion_runtime_resetter_source.find("reset_states") >= 0, "companion runtime resetter should own full companion runtime reset fanout")
	_expect(companion_runtime_resetter_source.find("reset_defense") >= 0 and companion_runtime_resetter_source.find("feed_controller.reset_all") >= 0, "companion runtime resetter should own defense-gated and feed cleanup")
	_expect(companion_runtime_resetter_source.find("func reset_to_egg_wait") >= 0 and companion_runtime_resetter_source.find("egg_state.spawn") >= 0 and companion_runtime_resetter_source.find("current_visual_prewarm_coordinator.prewarm_current") >= 0, "companion runtime resetter should own egg-wait transition reset/prewarm fanout")
	_expect(companion_runtime_resetter_source.find("func reset_companion_position") >= 0 and companion_runtime_resetter_source.find("\"companion_pos\"") >= 0, "companion runtime resetter should own companion position reset surfaces")
	_expect(companion_runtime_resetter_source.find("func prepare_hatch_position") >= 0 and companion_runtime_resetter_source.find("reset_contact_motion") >= 0, "companion runtime resetter should own hatch-position capture and egg contact reset")
	_expect(companion_runtime_resetter_source.find("func start_hatch_reveal_effects") >= 0 and companion_runtime_resetter_source.find("trigger_hatch_flash") >= 0 and companion_runtime_resetter_source.find("play_lingpet_acquire_cutin") >= 0 and companion_runtime_resetter_source.find("current_visual_prewarm_coordinator.prewarm_current") >= 0, "companion runtime resetter should own hatch reveal flash/cutin/prewarm fanout")
	_expect(companion_runtime_resetter_source.find("func prepare_companion_activation") >= 0 and companion_runtime_resetter_source.find("restore_current") >= 0 and companion_runtime_resetter_source.find("ensure_pet_active_slot") >= 0, "companion runtime resetter should own companion activation restore/prewarm/active-slot fanout")
	_expect(companion_runtime_resetter_source.find("func reset_to_none") >= 0 and companion_runtime_resetter_source.find("item_egg_lifecycle_state.clear_runtime_state") >= 0 and companion_runtime_resetter_source.find("egg_state.reset_all") >= 0, "companion runtime resetter should own clear-pending none-return cleanup fanout")
	_expect(companion_runtime_resetter_source.find("func clear_field_state") >= 0 and companion_runtime_resetter_source.find("overflow_choice_state.reset") >= 0 and companion_runtime_resetter_source.find("ring_dash_state.reset_all") >= 0, "companion runtime resetter should own save-restore field cleanup fanout")
	_expect(runtime_source.find("_companion_runtime_resetter.reset_state") >= 0, "egg runtime should delegate full companion runtime reset fanout")
	var deploy_egg_body := _function_body(runtime_source, "func deploy_egg_from_item")
	var plaza_spawn_body := _function_body(runtime_source, "func spawn_plaza_resonance_egg")
	var auto_spawn_body := _function_body(runtime_source, "func _spawn_egg")
	for egg_wait_body in [deploy_egg_body, plaza_spawn_body, auto_spawn_body]:
		_expect(egg_wait_body.find("_companion_runtime_resetter.reset_to_egg_wait") >= 0, "egg-wait transitions should call the companion runtime resetter transition helper")
		_expect(egg_wait_body.find("_reset_companion_runtime_state") < 0 and egg_wait_body.find("_reset_companion_patrol") < 0 and egg_wait_body.find("_current_visual_prewarm_coordinator.prewarm_current") < 0, "egg-wait transitions should not inline reset/prewarm fanout")
	var regular_hatch_body := _function_body(runtime_source, "func _finish_regular_hatch")
	var begin_overflow_hatch_body := _function_body(runtime_source, "func _begin_overflow_hatch")
	var overflow_commit_body := _function_body(runtime_source, "func _finish_overflow_hatch_commit")
	for hatch_reveal_body in [regular_hatch_body, begin_overflow_hatch_body, overflow_commit_body]:
		_expect(hatch_reveal_body.find("_companion_runtime_resetter.prepare_hatch_position") >= 0, "hatch reveal transitions should ask the resetter for hatch position capture")
		_expect(hatch_reveal_body.find("_companion_runtime_resetter.start_hatch_reveal_effects") >= 0, "hatch reveal transitions should ask the resetter for flash/cutin/prewarm fanout")
		_expect(hatch_reveal_body.find("_egg_state.reset_contact_motion") < 0 and hatch_reveal_body.find("_egg_state.trigger_hatch_flash") < 0 and hatch_reveal_body.find("_current_visual_prewarm_coordinator.prewarm_current") < 0 and hatch_reveal_body.find("_audio_dispatcher.play_lingpet_acquire_cutin") < 0, "hatch reveal transitions should not inline contact/flash/cutin/prewarm fanout")
	var debug_grant_activation_body := _function_body(runtime_source, "func debug_grant_and_activate_pet")
	var slot_switch_body := _function_body(runtime_source, "func switch_lingpet_slot")
	var adopt_owned_body := _function_body(runtime_source, "func _adopt_owned_pet")
	for companion_activation_body in [debug_grant_activation_body, slot_switch_body, adopt_owned_body]:
		_expect(companion_activation_body.find("_companion_runtime_resetter.prepare_companion_activation") >= 0, "companion activation transitions should ask the resetter for activation fanout")
		_expect(companion_activation_body.find("_reset_companion_runtime_state") < 0 and companion_activation_body.find("_companion_skill_persistence.restore_current") < 0 and companion_activation_body.find("_collection_state.ensure_pet_active_slot") < 0 and companion_activation_body.find("_current_visual_prewarm_coordinator.prewarm_current") < 0, "companion activation transitions should not inline reset/restore/active-slot/prewarm fanout")
	var clear_pending_body := _function_body(runtime_source, "func _clear_pending_egg_without_collection_reset")
	_expect(clear_pending_body.find("_companion_runtime_resetter.reset_to_none") >= 0, "clear-pending none-return should ask the resetter for cleanup fanout")
	_expect(clear_pending_body.find("_egg_state.reset_all") < 0 and clear_pending_body.find("_item_egg_lifecycle_state.clear_runtime_state") < 0 and clear_pending_body.find("_reset_companion_runtime_state") < 0 and clear_pending_body.find("_reset_companion_patrol") < 0 and clear_pending_body.find("_current_visual_prewarm_coordinator.prewarm_current") < 0, "clear-pending none-return should not inline cleanup/reset/prewarm fanout")
	var field_cleanup_body := _function_body(runtime_source, "func _clear_lingpet_field_state")
	_expect(field_cleanup_body.find("_companion_runtime_resetter.clear_field_state") >= 0, "save-restore field cleanup should ask the resetter for field cleanup fanout")
	_expect(field_cleanup_body.find("_egg_state.reset_all") < 0 and field_cleanup_body.find("_item_egg_lifecycle_state.clear_runtime_state") < 0 and field_cleanup_body.find("_reset_companion_patrol") < 0 and field_cleanup_body.find("_afterglow_leak_state.reset_all") < 0 and field_cleanup_body.find("_overflow_choice_state.reset") < 0, "save-restore field cleanup should not inline field cleanup fanout")
	var companion_runtime_reset_body := _function_body(runtime_source, "func _reset_companion_runtime_state")
	_expect(companion_runtime_reset_body.find("_companion_skill_persistence.reset_runtime_transients") < 0, "companion runtime reset wrapper should not reset skill runtime transients inline after resetter delegation")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_round_resetter.gd"), "lingpet round resetter should exist")
	_expect(round_resetter_source.find("func reset_round") >= 0 and round_resetter_source.find("reset_runtime_transients") >= 0 and round_resetter_source.find("reset_round_caps") >= 0, "lingpet round resetter should own round-boundary runtime reset fanout")
	_expect(round_resetter_source.find("reset_round_transients") >= 0 and round_resetter_source.find("feed_controller.reset_all") >= 0, "lingpet round resetter should own per-round transient cleanup")
	var reset_round_body := _function_body(runtime_source, "func reset_round")
	_expect(reset_round_body.find("_round_resetter.reset_round") >= 0, "egg runtime should delegate round reset fanout")
	_expect(reset_round_body.find("_companion_skill_persistence.reset_runtime_transients") < 0 and reset_round_body.find("_companion_skill_persistence.reset_round_transients") < 0 and reset_round_body.find("_affinity_state.reset_round_caps") < 0, "egg runtime round reset should not keep round reset fanout inline")
	_expect(round_resetter_source.find("companion_skill_persistence.reset_round_transients") >= 0, "round resetter should ask skill persistence directly when resetting round skill transients")
	_expect(companion_runtime_resetter_source.find("companion_skill_persistence.reset_states") >= 0, "companion runtime resetter should ask skill persistence directly when resetting skill states")
	_expect(runtime_source.find("_companion_skill_persistence.save_current") >= 0, "egg runtime should ask skill persistence directly when saving the current skill state")
	_expect(companion_runtime_resetter_source.find("companion_skill_persistence.restore_current") >= 0, "companion runtime resetter should ask skill persistence directly when restoring the current skill state")
	_expect(runtime_source.find("func _sync_shared_companion_skill_trigger_count") < 0, "egg runtime should not keep a single-use skill trigger-count sync wrapper")
	_expect(runtime_source.find("func _record_companion_skill_launch") < 0, "egg runtime should not keep a single-use skill launch-record wrapper")
	_expect(runtime_source.find("_companion_skill_persistence.sync_shared_trigger_count") >= 0, "egg runtime should ask skill persistence directly when initializing shared trigger counts")
	_expect(runtime_source.find("_companion_skill_persistence.record_launch") >= 0, "egg runtime should ask skill persistence directly when a companion skill launches")
	_expect(runtime_source.find("LingpetSkillDispatcher") < 0, "egg runtime should not directly dispatch lingpet active-skill kinds after controller delegation")
	_expect(affinity_hit_tag_source.find("func merge") >= 0 and affinity_hit_tag_source.find("func has_defense_tag") >= 0, "affinity hit-tag resolver should own tag merge and defense-tag detection")
	_expect(runtime_source.find("_affinity_hit_tag_resolver.capture") >= 0, "egg runtime should ask the affinity hit-tag resolver directly when capturing hit-tag snapshots")
	_expect(runtime_source.find("func _capture_affinity_hit_tags") < 0, "egg runtime should not keep a single-use affinity hit-tag capture wrapper")
	_expect(runtime_source.find("func _merge_affinity_hit_tags") < 0, "egg runtime should not keep a single-use affinity hit-tag merge wrapper")
	_expect(runtime_source.find("_affinity_hit_tag_resolver.merge") >= 0, "egg runtime should ask the affinity hit-tag resolver directly when merging tag snapshots")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_hatch_stat_roll_state.gd"), "hatch stat-roll helper should exist")
	_expect(hatch_stat_roll_source.find("func ensure_roll") >= 0 and hatch_stat_roll_source.find("set_hatch_stat_roll") >= 0, "hatch stat-roll helper should own random hatch headstart roll application")
	_expect(hatch_stat_roll_source.find("func roll_item_egg_hatch_traits") >= 0 and hatch_stat_roll_source.find("roll_and_store_pet_loadout_unsynced") >= 0, "hatch stat-roll helper should own item-egg hatch loadout/stat headstart coordination")
	_expect(hatch_stat_roll_source.find("invalidate_owner_loadout_sync_for_runtime") >= 0, "hatch stat-roll helper should invalidate owner loadout sync after unsynced item-egg hatch loadout writes")
	_expect(runtime_source.find("func _ensure_hatch_stat_roll") < 0, "egg runtime should not keep hatch stat-roll policy inline after helper delegation")
	_expect(runtime_source.find("func _roll_item_egg_hatch_traits") < 0, "egg runtime should not keep the item-egg hatch trait wrapper inline after helper delegation")
	_expect(current_loadout_applier_source.find("hatch_stat_roll_state.ensure_roll") >= 0, "current loadout applier should ask the hatch stat-roll helper when randomizing a new hatch loadout")
	_expect(runtime_source.find("_hatch_stat_roll_state.roll_item_egg_hatch_traits") >= 0, "egg runtime should ask the hatch stat-roll helper when rolling item-egg hatch traits")
	var item_egg_absorb_body_for_hatch_roll := _function_body(runtime_source, "func _perform_item_egg_absorb")
	var item_egg_replace_body_for_hatch_roll := _function_body(runtime_source, "func _commit_item_egg_overflow_replace")
	_expect(item_egg_absorb_body_for_hatch_roll.find("invalidate_owner_loadout_sync_for_runtime") < 0 and item_egg_replace_body_for_hatch_roll.find("invalidate_owner_loadout_sync_for_runtime") < 0, "egg runtime should not repeat item-egg hatch owner-loadout sync invalidation inline")
	_expect(distance_roll_source.find("func get_draw_angle") >= 0, "companion distance-roll state should own roll draw-angle calculation")
	_expect(distance_roll_source.find("func advance_draw_movement") >= 0 and distance_roll_source.find("func get_override_move_ratio") >= 0, "companion distance-roll state should own actual-draw-movement ratio calculation")
	_expect(runtime_source.find("func _get_companion_roll_draw_angle") < 0, "egg runtime should not keep a single-use companion roll draw-angle wrapper")
	_expect(runtime_source.find("_companion_distance_roll_state.get_draw_angle") >= 0, "egg runtime should ask distance-roll state directly for draw angle")
	for draw_transient_field in ["_companion_draw_pos_prev", "_companion_override_move_ratio"]:
		_expect(runtime_source.find("var %s" % draw_transient_field) < 0, "egg runtime should not keep raw companion draw-movement transient state (%s)" % draw_transient_field)
	_expect(runtime_source.find("_companion_distance_roll_state.advance_draw_movement") >= 0, "egg runtime should ask distance-roll state to advance actual draw-movement state")
	_expect(body_presence_source.find("get_override_move_ratio") >= 0, "body-presence resolver should ask distance-roll state for the draw-motion override ratio")
	_expect(body_presence_source.find("func get_draw_motion_speed_ratio_from_runtime") >= 0 and body_presence_source.find("func get_draw_motion_speed_ratio_from_surface") >= 0, "body-presence resolver should own runtime and draw-surface motion-speed ratio assembly")
	_expect(body_presence_source.find("func is_visible_for_draw_from_surface") >= 0 and body_presence_source.find("is_companion_visual_hidden") >= 0, "body-presence resolver should own draw-surface visibility source assembly")
	_expect(body_presence_source.find("func is_available_for_hit_from_surface") >= 0, "body-presence resolver should own body-hit availability source assembly")
	_expect(runtime_source.find("_companion_body_presence_resolver.get_draw_motion_speed_ratio_from_runtime") >= 0, "egg runtime should ask body-presence resolver for runtime draw-motion speed ratio assembly")
	_expect(skill_runtime_surface_source.find("func get_active_slot_count") >= 0 and skill_runtime_surface_source.find("has_method(\"get_active_slot_count\")") >= 0, "skill runtime surface should own active slot-count assembly")
	_expect(skill_runtime_surface_source.find("func get_active_skill_ids") >= 0 and skill_runtime_surface_source.find("get_active_skill_ids_for_runtime") >= 0, "skill runtime surface should own active skill id list assembly")
	_expect(skill_runtime_surface_source.find("func get_active_surface_for_slot") >= 0 and skill_runtime_surface_source.find("get_skill_id_for_slot") >= 0 and skill_runtime_surface_source.find("get_active_skill_for_slot") >= 0 and skill_runtime_surface_source.find("get_skill_windup_seconds_for_slot") >= 0 and skill_runtime_surface_source.find("get_state_for_slot") >= 0 and skill_runtime_surface_source.find("get_active_skill_level_for_slot") >= 0, "skill runtime surface should own per-slot active-skill update/snapshot/owner-sync surface assembly")
	_expect(skill_runtime_surface_source.find("func get_second_active_surface") >= 0 and skill_runtime_surface_source.find("get_active_surface_for_slot(") >= 0, "skill runtime surface should keep second-active surface as a slot-1 specialization")
	var skill_update_body := _function_body(runtime_source, "func _update_companion_skill_effects")
	_expect(skill_update_body.find("_companion_skill_controller.update_active_slots") >= 0, "companion skill runtime hook should delegate the full slot tick to the controller")
	_expect(skill_controller_source.find("skill_runtime_surface.get_active_surface_for_slot") >= 0, "companion skill controller should ask skill runtime surface for per-slot active surface data")
	_expect(skill_update_body.find("_active_skill_slot_resolver.get_active_skill_for_slot") < 0 and skill_update_body.find("_active_skill_slot_resolver.get_skill_windup_seconds_for_slot") < 0 and skill_update_body.find("_companion_skill_persistence.get_state_for_slot") < 0 and skill_update_body.find("_current_profile.get_active_skill_level_for_slot") < 0, "companion skill update should not reassemble active-skill surface inline")
	var skill_launch_body := _function_body(runtime_source, "func _launch_companion_skill")
	_expect(skill_launch_body.find("_skill_runtime_surface.get_active_surface_for_slot") >= 0, "companion skill launch should ask skill runtime surface for per-slot active surface data")
	_expect(skill_launch_body.find("_current_profile.get_active_skill_level_for_slot") < 0, "companion skill launch should not reassemble active skill level fallback inline")
	var runtime_snapshot_body := _function_body(runtime_source, "func _build_runtime_snapshot_uncached")
	if runtime_snapshot_body == "":
		runtime_snapshot_body = _function_body(runtime_source, "func get_snapshot")
	var runtime_sync_owner_body := _function_body(runtime_source, "func _sync_owner")
	_expect(runtime_snapshot_body.find("_skill_runtime_surface.get_active_surface_for_slot") >= 0, "runtime snapshot should ask skill runtime surface for primary active-skill surface data")
	_expect(runtime_sync_owner_body.find("_skill_runtime_surface.get_active_surface_for_slot") >= 0, "owner sync should ask skill runtime surface for primary active-skill surface data")
	_expect(runtime_snapshot_body.find("_skill_runtime_surface.get_second_active_surface") >= 0, "runtime snapshot should ask skill runtime surface for second-active surface data")
	_expect(runtime_sync_owner_body.find("_skill_runtime_surface.get_second_active_surface") >= 0, "owner sync should ask skill runtime surface for second-active surface data")
	_expect(runtime_snapshot_body.find("get_active_skill_for_slot") < 0 and runtime_snapshot_body.find("get_skill_windup_seconds_for_slot") < 0 and runtime_snapshot_body.find("_companion_skill_persistence.get_state_for_slot") < 0, "runtime snapshot should not reassemble active-skill surface inline")
	_expect(runtime_sync_owner_body.find("get_active_skill_for_slot") < 0 and runtime_sync_owner_body.find("get_skill_windup_seconds_for_slot") < 0 and runtime_sync_owner_body.find("_companion_skill_persistence.get_state_for_slot") < 0, "owner sync should not reassemble active-skill surface inline")
	_expect(skill_runtime_surface_source.find("func get_visual_surface") >= 0 and skill_runtime_surface_source.find("get_active_visual_slot_index") >= 0 and skill_runtime_surface_source.find("get_active_position_override_owner") >= 0, "skill runtime surface should own companion draw visual-skill surface assembly")
	_expect(skill_runtime_surface_source.find("func get_active_position_owner") >= 0 and skill_runtime_surface_source.find("func has_active_position_override") >= 0, "skill runtime surface should own active position-owner queries and predicates")
	_expect(skill_runtime_surface_source.find("func get_body_skill_id") >= 0, "skill runtime surface should own companion body-skill id assembly")
	_expect(skill_runtime_surface_source.find("\"body_skill_id\"") >= 0 and skill_runtime_surface_source.find("get_companion_body_skill_id") >= 0, "skill runtime surface should carry companion body skill id in the visual surface")
	var draw_body := _function_body(runtime_source, "func draw")
	var draw_behind_body := _function_body(runtime_source, "func draw_lingpet_body_behind_actors")
	_expect(draw_body.find("_skill_runtime_surface.get_body_skill_id") >= 0, "front-pass draw should ask skill runtime surface for companion body skill id")
	_expect(draw_behind_body.find("_skill_runtime_surface.get_body_skill_id") >= 0, "behind-actors draw should ask skill runtime surface for companion body skill id")
	_expect(draw_body.find("get_active_position_override_owner") < 0 and draw_body.find("get_companion_body_skill_id") < 0, "front-pass draw should not reassemble body skill id inline")
	_expect(draw_behind_body.find("get_active_position_override_owner") < 0 and draw_behind_body.find("get_companion_body_skill_id") < 0, "behind-actors draw should not reassemble body skill id inline")
	var draw_companion_body := _function_body(runtime_source, "func _draw_companion")
	_expect(draw_companion_body.find("_skill_runtime_surface.get_visual_surface") >= 0, "companion draw should ask skill runtime surface for visual-skill surface data")
	_expect(draw_companion_body.find("_companion_body_presence_resolver.get_draw_motion_speed_ratio_from_surface") >= 0, "companion draw should ask body-presence resolver for draw-surface speed ratio assembly")
	_expect(draw_companion_body.find("_companion_body_presence_resolver.is_visible_for_draw_from_surface") >= 0, "companion draw should ask body-presence resolver for draw-surface visibility assembly")
	_expect(draw_companion_body.find("get_active_visual_slot_index") < 0 and draw_companion_body.find("get_active_position_override_owner") < 0 and draw_companion_body.find("_companion_skill_persistence.get_state_for_slot") < 0 and draw_companion_body.find("get_skill_windup_seconds_for_slot") < 0, "companion draw should not reassemble visual-skill surface inline")
	_expect(draw_companion_body.find("is_companion_visual_hidden") < 0 and draw_companion_body.find("has_companion_position_override") < 0 and draw_companion_body.find("motion_visible") < 0, "companion draw should not reassemble body visibility sources inline")
	var advance_draw_anim_body := _function_body(runtime_source, "func _advance_companion_draw_anim")
	_expect(advance_draw_anim_body.find("get_draw_motion_speed_ratio_from_runtime") >= 0 and advance_draw_anim_body.find("get_draw_motion_speed_ratio_from_sources") < 0, "companion draw animator should not reassemble motion-speed ratio sources inline")
	var resolve_companion_ball_hit_body := _function_body(runtime_source, "func _resolve_companion_ball_hit")
	_expect(resolve_companion_ball_hit_body.find("_skill_runtime_surface.get_visual_surface") >= 0, "companion body-hit should ask skill runtime surface for visual/body-skill surface data")
	_expect(resolve_companion_ball_hit_body.find("_companion_body_presence_resolver.is_available_for_hit_from_surface") >= 0, "companion body-hit should ask body-presence resolver for availability source assembly")
	_expect(resolve_companion_ball_hit_body.find("get_active_position_override_owner") < 0 and resolve_companion_ball_hit_body.find("has_active_position_override") < 0 and resolve_companion_ball_hit_body.find("has_companion_position_override") < 0 and resolve_companion_ball_hit_body.find("is_companion_visual_hidden") < 0, "companion body-hit should not reassemble body availability sources inline")
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
	_expect(skill_runtime_host_source.find("lingpet_banana_slice_skill.gd") >= 0, "skill runtime host should own Ppanamong's Banana Slice module")
	_expect(skill_runtime_host_source.find("preload(\"res://scripts/lingpet/lingpet_hydro_sphere_skill.gd\")") < 0, "skill runtime host should not hard-preload every lingpet skill during boot")
	_expect(skill_runtime_host_source.find("var _hydro_sphere_skill: Object = null") >= 0, "skill runtime host should keep concrete skill modules lazy until the active skill needs them")
	_expect(skill_runtime_host_source.find("_new_skill(") >= 0 and skill_runtime_host_source.find("load(path)") >= 0, "skill runtime host should dynamically load concrete skill modules on demand")
	_expect(skill_runtime_host_source.find("func prewarm_many") >= 0, "skill runtime host should own batch prewarm for resolver-built active skill ids")
	_expect(skill_runtime_host_source.find("func clear_for_tests") >= 0, "skill runtime host should expose test cleanup that releases lazy skill modules")
	_expect(runtime_source.find("_skill_runtime_host.prewarm_many(_skill_runtime_surface.get_active_skill_ids") >= 0, "egg runtime should hand surface-built active-skill prewarm batches to the host")
	var runtime_reset_for_tests_body := _function_body(runtime_source, "func reset_for_tests")
	_expect(runtime_reset_for_tests_body.find("_skill_runtime_host.clear_for_tests") >= 0, "egg runtime test reset should release lazy skill runtime modules")
	_expect(current_loadout_applier_source.find("skill_runtime_host.prewarm_many") >= 0 and current_loadout_applier_source.find("active_skill_slot_resolver.get_active_skill_ids_for_runtime") >= 0, "current loadout applier should prewarm active-skill runtimes after applying a loadout")
	_expect(runtime_source.find("func _prewarm_current_skill_runtime") < 0, "egg runtime should not keep a private active-skill prewarm wrapper")
	_expect(skill_runtime_host_source.find("get_companion_position_override") >= 0, "skill runtime host should let body-driven skills override the real companion position")
	_expect(runtime_source.find("func _apply_active_companion_skill_position_override") < 0, "egg runtime should not keep a single-use position-override apply wrapper")
	_expect(runtime_source.find("func _apply_companion_skill_position_override") < 0, "egg runtime should not keep a dead companion skill position-override wrapper")
	_expect(skill_controller_source.find("_skill_runtime_surface.get_active_position_owner_for_ids") >= 0 and skill_controller_source.find("_skill_runtime_surface.has_active_position_override") >= 0 and skill_controller_source.find("_vector2_or_fallback") >= 0, "skill controller should resolve body-driven positions through the skill-runtime active-position surface")
	_expect(runtime_source.find("_companion_pos = _companion_skill_controller.update_active_slots") >= 0, "egg runtime should apply the controller-resolved companion position")
	_expect(runtime_source.find("_companion_skill_visual_resolver.get_active_position_override_owner") < 0 and runtime_source.find("_companion_skill_visual_resolver.has_active_position_override") < 0, "egg runtime should not reassemble active position-owner queries inline")
	for visual_wrapper in ["func _get_active_position_override_owner", "func _has_active_companion_position_override", "func _get_companion_body_skill_id"]:
		_expect(runtime_source.find(visual_wrapper) < 0, "egg runtime should not keep single-use companion-skill visual resolver pass-through wrappers (%s)" % visual_wrapper)
	_expect(runtime_source.find("func _trigger_companion_skill_strike_if_requested") < 0, "egg runtime should not keep a single-use companion strike-request wrapper")
	_expect(skill_controller_source.find("skill_runtime_surface.consume_companion_strike_request") >= 0, "skill controller should consume companion strike requests through the skill-runtime surface")
	_expect(skill_runtime_surface_source.find("func is_companion_body_hit_suppressed") >= 0, "skill-runtime surface should own companion body-hit suppression checks")
	_expect(runtime_source.find("func _is_companion_body_hit_suppressed") < 0, "egg runtime should not keep a single-use companion body-hit suppression wrapper")
	_expect(runtime_source.find("_skill_runtime_surface.is_companion_body_hit_suppressed") >= 0, "egg runtime should ask the skill-runtime surface directly for body-hit suppression")
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
	var motion_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_motion_state.gd")
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
	_expect(companion_renderer_source.find("func prewarm_assets") >= 0, "companion renderer should expose the soft-glow prewarm API as a fixed module contract")
	_expect(runtime_source.find("_companion_renderer.prewarm_assets()") >= 0, "egg runtime should call the companion renderer prewarm contract directly")
	_expect(runtime_source.find("_companion_renderer.has_method(\"prewarm_assets\")") < 0, "egg runtime should not guard the fixed companion renderer prewarm contract dynamically")
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
	_expect(motion_source.find("func resolve_facing_left_from_patrol_dir") >= 0, "companion motion state should own patrol_dir-based facing resolution")
	_expect(motion_source.find("func resolve_facing_left_after_motion") >= 0, "companion motion state should own dx-based facing resolution")
	_expect(runtime_source.find("func _set_companion_facing_from_patrol_dir") < 0, "egg runtime should not keep a private patrol_dir facing resolver")
	_expect(runtime_source.find("func _update_companion_facing_after_motion") < 0, "egg runtime should not keep a private dx-based facing resolver")
	_expect(runtime_source.find("_companion_motion_state.resolve_facing_left_from_patrol_dir") >= 0, "egg runtime should seed companion facing from the motion-state patrol_dir owner")
	_expect(runtime_source.find("_companion_motion_state.resolve_facing_left_after_motion") >= 0, "egg runtime should update companion facing from the motion-state dx owner")
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
	var strike_anticipator_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_strike_anticipator.gd")
	_expect(runtime_source.find("func _maybe_arm_companion_strike") < 0, "egg runtime should not keep a private companion strike-arm helper")
	_expect(runtime_source.find("_companion_strike_anticipator.maybe_arm_from_sources") >= 0, "companion should arm the strike anticipatorily through the strike-anticipator owner")
	_expect(strike_anticipator_source.find("func maybe_arm_from_sources") >= 0, "strike anticipator should own runtime-source strike arm mediation")
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


func _verify_junior_mika_tutorial_grants_standard_ring_core_before_hatch() -> void:
	# R3 / v5: store is no longer a live module; the tutorial grant is run-state.
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var host := FakeCutinHost.new()
	host.done_after = 99
	var registry := FakeRegistry.new({"lingpet_acquire_cutin_overlay_host": host})

	_expect(runtime.update(0.0, owner, registry), "Junior Mika tutorial should spawn the first egg with a registry that has no affinity store")
	_expect(str(owner.lingpet_state) == "egg", "tutorial ring-core grant should happen while the first lingpet is still an egg")
	_expect_eq(int(runtime._affinity_state.get_run_ring_core_tier()), 1, "Junior Mika first egg should grant this-run standard ring-core before hatch")
	_expect_eq(int(runtime._affinity_state.get_run_ring_core_cap()), 5, "standard tutorial ring-core should expose run cap 5 before hatch affinity resolves")

	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1, registry)
	var hatched_id := str(owner.active_lingpet_id)
	_expect(hatched_id != "", "tutorial ring-core hatch should reveal a concrete pet")
	for _i in range(200):
		runtime.debug_add_affinity_points_for_tests(hatched_id, LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
	_expect_eq(runtime.get_affinity_level(hatched_id), 5, "tutorial standard ring-core should cap first-pet affinity at Lv5")
	_expect_float(runtime.get_affinity_points(hatched_id), 50.0, "tutorial standard ring-core should clamp overflow at the Lv5->Lv6 requirement (50)")
	_expect_eq(int(owner.lingpet_ring_core_tier), 1, "owner/TAB ring-core tier should display the tutorial run tier, not the store tier")

	var storeless_owner := FakeOwner.new()
	var storeless_runtime: Object = LingpetEggRuntime.new()
	_expect(storeless_runtime.update(0.0, storeless_owner), "Junior Mika tutorial should spawn and grant a run ring-core without an affinity store")
	_expect(str(storeless_owner.lingpet_state) == "egg", "storeless tutorial fixture should reach egg state")
	_expect_eq(int(storeless_runtime._affinity_state.get_run_ring_core_tier()), 1, "storeless tutorial grant should set this-run tier 1")
	_expect_eq(int(storeless_runtime._affinity_state.get_run_ring_core_cap()), 5, "storeless tutorial grant should expose run cap 5")


func _verify_tutorial_ring_core_grant_does_not_lower_or_bypass_eligibility() -> void:
	# R3 / v5: store no longer persists ring-core; seed the run tier directly below.
	var higher_owner := FakeOwner.new()
	var higher_runtime: Object = LingpetEggRuntime.new()
	higher_runtime._affinity_state.set_run_ring_core_tier(2)
	_expect(higher_runtime.update(0.0, higher_owner, FakeRegistry.new({})), "higher-tier Junior Mika should still spawn the tutorial egg without an affinity store module")
	_expect_eq(int(higher_runtime._affinity_state.get_run_ring_core_tier()), 2, "tutorial grant should not lower an existing run ring-core tier")

	# R3 / v5: store no longer persists ring-core. Junior starter-egg characters
	# (smasher/commando/viper) DO get the standard grant; other characters do not.
	var optimus_owner := FakeOwner.new()
	optimus_owner.selected_character_type = "optimus"
	var optimus_runtime: Object = LingpetEggRuntime.new()
	_expect(not optimus_runtime.update(0.0, optimus_owner, FakeRegistry.new({})), "Junior non-starter character should not spawn the first tutorial egg")
	_expect_eq(int(optimus_runtime._affinity_state.get_run_ring_core_tier()), 0, "ineligible non-starter owner should keep this-run ring-core at tier 0")

	# Commando/Viper now share the Smasher starter grant in the test (Junior) league.
	for starter_character in ["viper", "soldier"]:
		var starter_owner := FakeOwner.new()
		starter_owner.selected_character_type = str(starter_character)
		var starter_runtime: Object = LingpetEggRuntime.new()
		_expect(starter_runtime.update(0.0, starter_owner, FakeRegistry.new({})), "Junior %s should spawn the first starter egg like Smasher" % starter_character)
		_expect_eq(int(starter_runtime._affinity_state.get_run_ring_core_tier()), 1, "Junior %s starter egg should grant the standard run ring-core tier 1" % starter_character)


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
	_expect(first_nudge > 0.0 and first_nudge < 0.7, "player contact should gently nudge the Ringpet egg away from the player on the first frame")
	_expect(absf(float(snapshot.get("egg_wobble_angle", 0.0))) > 0.01, "player contact should wobble the Ringpet egg")
	_expect(int(owner.lingpet_hatch_hits) == 0, "player contact should not count as a hatch hit")
	for _idx in range(30):
		runtime.update(0.016, owner)
	var sustained_nudge: float = owner.lingpet_egg_pos.x - start_pos.x
	# Walking now influences the egg noticeably more than before (old cap was 14),
	# but still stays a gentle push, not a dash-strength shove.
	_expect(sustained_nudge > 15.0, "walking into the egg should influence it noticeably more than the old faint nudge")
	_expect(sustained_nudge < 30.0, "sustained player contact should still not shove the Ringpet egg a full body-width away")
	var walk_egg_state: Object = runtime.get("_egg_state")
	_expect(absf(float(walk_egg_state.roll_angle)) > 0.05, "walking should also roll the egg (Δx-driven), not just slide it flat")


func _verify_egg_color_rolls_once_and_restores() -> void:
	var renderer: Object = LingpetEggFieldRenderer.new()
	_expect(int(LingpetEggFieldState.EGG_VARIANT_COUNT) == int(renderer.get_variant_count()), "egg field state and renderer should agree on the resonance egg variant count")

	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var first_snapshot: Dictionary = runtime.get_snapshot()
	var color_index: int = int(first_snapshot.get("egg_color_index", -1))
	_expect(color_index >= 0 and color_index < int(renderer.get_variant_count()), "spawned main egg should roll one valid resonance variant index")
	for _idx in range(16):
		runtime.update(0.016, owner)
	_expect(int(runtime.get_snapshot().get("egg_color_index", -1)) == color_index, "main egg resonance color must not reroll during normal frame advancement")

	var save_snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(int(save_snapshot.get("egg_color_index", -1)) == color_index, "save snapshot should preserve the rolled egg resonance color index")
	var restored_owner := FakeOwner.new()
	var restored_runtime: Object = LingpetEggRuntime.new()
	var restore_result: Dictionary = restored_runtime.apply_save_snapshot(save_snapshot, restored_owner)
	_expect(bool(restore_result.get("restored", false)), "egg save snapshot should restore after adding resonance color")
	_expect(int(restored_runtime.get_snapshot().get("egg_color_index", -1)) == color_index, "egg restore should preserve the saved resonance color index")

	var item_owner := FakeOwner.new()
	item_owner.ai_mode = "champion"
	var item_registry := FakeRegistry.new()
	var item_runtime: Object = LingpetEggRuntime.new()
	_expect(bool(item_runtime.debug_grant_and_activate_pet("maribo", item_owner, false, "", "", item_registry)), "item color fixture should start with an active companion")
	_expect(bool(item_runtime.deploy_egg_from_item(item_owner, item_registry)), "item color fixture should deploy a coexisting incubator egg")
	var item_egg_state: Object = item_runtime.get("_item_egg_state") as Object
	var item_color_index: int = int(item_egg_state.get_color_index())
	_expect(item_color_index >= 0 and item_color_index < int(renderer.get_variant_count()), "deployed item egg should roll its own valid resonance variant index")
	for _idx in range(8):
		item_runtime.update(0.016, item_owner, item_registry)
	_expect(int(item_egg_state.get_color_index()) == item_color_index, "deployed item egg resonance color must not reroll during incubation frames")

	var field_state_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_field_state.gd")
	var spawn_start: int = field_state_source.find("func spawn(")
	var spawn_end: int = field_state_source.find("\nfunc ", spawn_start + 1)
	var spawn_body: String = field_state_source.substr(spawn_start, spawn_end - spawn_start)
	var advance_start: int = field_state_source.find("func advance(")
	var advance_end: int = field_state_source.find("\nfunc ", advance_start + 1)
	var advance_body: String = field_state_source.substr(advance_start, advance_end - advance_start)
	_expect(spawn_body.find("roll_color_index()") >= 0, "egg resonance color should be rolled in spawn()")
	_expect(advance_body.find("roll_color_index") < 0 and advance_body.find("egg_color_index") < 0, "egg resonance color must not reroll or mutate in per-frame advance()")
	_expect(field_state_source.find("pet_id") < 0 and field_state_source.find("profile") < 0, "egg resonance color roll must stay decoupled from pet/profile identity")

	var item_catalog_source: String = FileAccess.get_file_as_string("res://scripts/items/active_item_catalog.gd")
	_expect(item_catalog_source.find("guardian_spirit_egg_traditional_item_icon_v1.png") >= 0, "active item slot icon should point at the traditional guardian-spirit egg icon")
	_expect(item_catalog_source.find("Color(0.30, 0.80, 1.0)") >= 0 and item_catalog_source.find("Color(1.0, 0.86, 0.62)") < 0, "lingpet egg pickup catalog color should use the cyan resonance color, not the old peach-gold glow")

	var visual_cache_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
	var default_prewarm_start: int = visual_cache_source.find("const DEFAULT_PREWARM_KEYS")
	var default_prewarm_end: int = visual_cache_source.find("]", default_prewarm_start)
	var default_prewarm_body: String = visual_cache_source.substr(default_prewarm_start, default_prewarm_end - default_prewarm_start)
	_expect(default_prewarm_body.find("\"egg\"") < 0 and default_prewarm_body.find("\"egg_crack_") < 0, "per-pet visual prewarm should not load egg layers now owned by the egg renderer")


func _verify_bare_egg_roll_physics_and_renderer() -> void:
	var renderer: Object = LingpetEggFieldRenderer.new()
	for variant_index in range(renderer.get_variant_count()):
		var path: String = str(LingpetEggFieldRenderer.EGG_BARE_VARIANT_PATHS[variant_index])
		_expect(FileAccess.file_exists(path), "traditional field guardian-spirit egg variant %d should exist" % variant_index)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null, "bare field egg variant %d should load as an image" % variant_index)
		if image == null:
			continue
		var bounds: Rect2i = _image_alpha_bounds(image)
		_expect_eq(bounds.size.x, 316, "bare field egg variant %d should keep the shared alpha bbox width" % variant_index)
		_expect_eq(bounds.size.y, 396, "bare field egg variant %d should keep the shared alpha bbox height" % variant_index)
		_expect_float(float(bounds.position.x) + (float(bounds.size.x) - 1.0) * 0.5, 255.5, "bare field egg variant %d alpha bbox should be centered on the canvas x pivot" % variant_index)
		_expect_float(float(bounds.position.y) + (float(bounds.size.y) - 1.0) * 0.5, 255.5, "bare field egg variant %d alpha bbox should be centered on the canvas y pivot" % variant_index)
		_expect_float(image.get_pixel(0, 0).a, 0.0, "bare field egg variant %d top-left corner should be transparent" % variant_index)
		_expect_float(image.get_pixel(image.get_width() - 1, 0).a, 0.0, "bare field egg variant %d top-right corner should be transparent" % variant_index)
		_expect_float(image.get_pixel(0, image.get_height() - 1).a, 0.0, "bare field egg variant %d bottom-left corner should be transparent" % variant_index)
		_expect_float(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a, 0.0, "bare field egg variant %d bottom-right corner should be transparent" % variant_index)

	var radius_from_art: float = (LingpetEggFieldRenderer.EGG_SEMI_MAJOR + LingpetEggFieldRenderer.EGG_SEMI_MINOR) * 0.5
	_expect(absf(LingpetEggFieldState.EGG_ROLL_CONTACT_RADIUS - radius_from_art) <= 1.0, "egg roll contact radius should stay tied to the renderer's measured bare-egg semi-axes")

	var owner := FakeOwner.new()
	owner.player_pos = Vector2(0.0, 0.0)
	var roll_state := LingpetEggFieldState.new()
	roll_state.pos = Vector2(200.0, 704.0)
	roll_state.dash_vx = 12.0
	var traveled := 0.0
	for _idx in range(8):
		var x_before: float = roll_state.pos.x
		roll_state.update_player_contact(0.016, owner)
		traveled += roll_state.pos.x - x_before
	var expected_roll: float = fposmod(traveled / LingpetEggFieldState.EGG_ROLL_CONTACT_RADIUS, TAU)
	_expect_float(float(roll_state.roll_angle), expected_roll, "egg roll angle should integrate from actual x displacement, not time or raw velocity")

	var wrap_state := LingpetEggFieldState.new()
	wrap_state.pos = Vector2(100.0, 704.0)
	wrap_state.dash_vx = 400.0
	wrap_state.update_player_contact(0.016, owner)
	_expect(float(wrap_state.roll_angle) >= 0.0 and float(wrap_state.roll_angle) < TAU, "egg roll angle should stay wrapped to [0, TAU)")

	var wall_state := LingpetEggFieldState.new()
	wall_state.pos = Vector2(LingpetEggFieldState.FIELD_WIDTH - LingpetEggFieldState.EGG_TEXTURE_DRAW_SIZE.x * 0.5 - 1.0, 704.0)
	wall_state.dash_vx = 16.0
	var angle_before_wall: float = wall_state.roll_angle
	wall_state.update_player_contact(0.016, owner)
	var into_wall_delta: float = _signed_angle_delta(angle_before_wall, wall_state.roll_angle)
	var angle_after_wall: float = wall_state.roll_angle
	wall_state.update_player_contact(0.016, owner)
	var rebound_delta: float = _signed_angle_delta(angle_after_wall, wall_state.roll_angle)
	_expect(into_wall_delta > 0.0, "egg roll should advance in the original travel direction before wall rebound")
	_expect(rebound_delta < 0.0, "egg roll direction should reverse automatically after wall rebound")

	var settle_state := LingpetEggFieldState.new()
	settle_state.pos = Vector2(300.0, 704.0)
	settle_state.roll_angle = PI * 0.57
	for _idx in range(90):
		settle_state.update_player_contact(0.016, owner)
	var upright_error: float = minf(absf(float(settle_state.roll_angle)), absf(TAU - float(settle_state.roll_angle)))
	_expect(upright_error <= LingpetEggFieldState.EGG_ROLL_SETTLE_EPSILON * 1.5, "motionless egg should settle back near upright instead of stopping on an arbitrary tip angle")
	settle_state.roll_angle = PI * 0.5
	settle_state.reset_contact_motion()
	_expect_float(float(settle_state.roll_angle), 0.0, "reset_contact_motion should reset volatile roll angle")

	var texture_rect := Rect2(Vector2(40.0, 80.0), Vector2(88.0, 88.0))
	var crack_path: Array[Vector2] = [
		Vector2(0.50, 0.15),
		Vector2(0.46, 0.26),
		Vector2(0.51, 0.36),
	]
	var flat_points: PackedVector2Array = renderer.build_crack_light_points_for_tests(texture_rect, crack_path, 0.0)
	var turned_points: PackedVector2Array = renderer.build_crack_light_points_for_tests(texture_rect, crack_path, PI * 0.5)
	var crack_center: Vector2 = texture_rect.get_center()
	for point_index in range(flat_points.size()):
		var expected_point: Vector2 = crack_center + (flat_points[point_index] - crack_center).rotated(PI * 0.5)
		_expect(turned_points[point_index].distance_to(expected_point) <= 0.001, "egg crack-light point %d should rotate with the egg body" % point_index)

	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("_egg_state.roll_angle") >= 0, "main field egg draw should pass roll_angle into the renderer")
	_expect(runtime_source.find("_item_egg_state.roll_angle") >= 0, "coexisting item egg draw should pass roll_angle into the renderer")


func _verify_egg_hatch_required_hits_roll() -> void:
	# (a) hatch difficulty roll — 1/2/3 pool. Roll off a LOCAL seeded RNG so this
	# statistical seal never drains the global randi() stream that later RNG-coupled
	# tests in this smoke depend on (reward-deck shuffle / V3-2c reconcile). Production
	# spawn() still uses global randi (roll_required_hits() with no arg).
	_expect(LingpetEggFieldState.HATCH_REQUIRED_HITS_POOL == [1, 2, 3], "hatch difficulty pool should be the 1/2/3 tiers")
	var roll_rng := RandomNumberGenerator.new()
	roll_rng.seed = 20260703
	var roll_state := LingpetEggFieldState.new()
	var seen_tiers: Dictionary = {}
	for _roll_index in range(60):
		roll_state.roll_required_hits(roll_rng)
		var rolled: int = int(roll_state.hatch_required_hits)
		_expect(rolled >= 1 and rolled <= 3, "hatch difficulty roll should stay in the 1..3 pool")
		seen_tiers[rolled] = true
	_expect(seen_tiers.size() == 3, "60 local-RNG rolls should hit every 1/2/3 tier (statistical seal, no global randi)")
	# no reroll on frame advance; rolled value beats the fallback; snapshot exposes it
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(-800.0, -800.0)
	var stable_state := LingpetEggFieldState.new()
	stable_state.pos = Vector2(300.0, 704.0)
	stable_state.roll_required_hits(roll_rng)
	var first_roll: int = int(stable_state.hatch_required_hits)
	for _frame in range(30):
		stable_state.advance(0.016)
		stable_state.update_player_contact(0.016, owner)
	_expect(int(stable_state.hatch_required_hits) == first_roll, "required-hits roll must not reroll during normal frame advancement")
	_expect(int(stable_state.get_required_hits(9)) == first_roll, "rolled state should win over the caller fallback")
	_expect(int(stable_state.get_snapshot().get("egg_required_hits", -1)) == first_roll, "state snapshot should expose the required-hits roll")
	var unrolled_state := LingpetEggFieldState.new()
	_expect(int(unrolled_state.get_required_hits(7)) == 7, "unrolled state should fall back to the caller value")
	stable_state.reset_all()
	_expect(int(stable_state.hatch_required_hits) == 0, "reset_all should clear the required-hits roll back to the unrolled sentinel")

	# (b) junior auto-present starter egg is ALWAYS forced to 1 hit. This is a
	# deterministic override (not a probabilistic roll), so a few iterations suffice.
	for _junior_index in range(3):
		var junior_owner := FakeOwner.new()
		var junior_runtime: Object = LingpetEggRuntime.new()
		junior_runtime.update(0.0, junior_owner)
		_expect(int(junior_owner.lingpet_hatch_required_hits) == 1, "junior auto-present starter egg must always hatch on the first hit")

	# (c) multi-hit OUTCOME through the live runtime hit path: a 3-hit egg cracks on
	# hits 1 and 2 (state stays egg, crack stages = hatch_hits) and hatches on hit 3
	var outcome_owner := FakeOwner.new()
	var outcome_runtime: Object = LingpetEggRuntime.new()
	outcome_runtime.update(0.0, outcome_owner)
	var outcome_egg_state: Object = outcome_runtime.get("_egg_state")
	outcome_egg_state.set_required_hits(3)
	outcome_runtime.update(0.016, outcome_owner)
	_expect(int(outcome_owner.lingpet_hatch_required_hits) == 3, "owner sync should publish the egg's own required-hits roll")
	var outcome_egg_pos: Vector2 = outcome_owner.lingpet_egg_pos
	outcome_owner.ball_active = true
	_register_hit(outcome_runtime, outcome_owner, outcome_egg_pos, 1)
	_expect(int(outcome_owner.lingpet_hatch_hits) == 1 and str(outcome_owner.lingpet_state) == "egg", "first hit on a 3-hit egg should crack it, not hatch it")
	_register_hit(outcome_runtime, outcome_owner, outcome_egg_pos, 2)
	_expect(int(outcome_owner.lingpet_hatch_hits) == 2 and str(outcome_owner.lingpet_state) == "egg", "second hit on a 3-hit egg should deepen the crack, not hatch it")
	_register_hit(outcome_runtime, outcome_owner, outcome_egg_pos, 3)
	_expect(str(outcome_owner.lingpet_state) == "companion", "third hit on a 3-hit egg should hatch it")

	# (d) save/load roundtrip keeps the per-egg roll (mirrors the color-index seal)
	var save_owner := FakeOwner.new()
	var save_runtime: Object = LingpetEggRuntime.new()
	save_runtime.update(0.0, save_owner)
	var save_egg_state: Object = save_runtime.get("_egg_state")
	save_egg_state.set_required_hits(2)
	var required_save_snapshot: Dictionary = save_runtime.get_save_snapshot()
	_expect(int(required_save_snapshot.get("required_hits", 0)) == 2, "save snapshot should persist the per-egg required-hits roll")
	var restore_owner := FakeOwner.new()
	var restore_runtime: Object = LingpetEggRuntime.new()
	restore_runtime.apply_save_snapshot(required_save_snapshot, restore_owner)
	var restored_egg_state: Object = restore_runtime.get("_egg_state")
	_expect(int(restored_egg_state.get_required_hits(0)) == 2, "restored egg should keep its saved required-hits roll")

	# (e) coexist item egg prefers its own spawn roll over the incubating pet's profile
	var lifecycle_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_item_egg_lifecycle_state.gd")
	_expect(lifecycle_source.find("egg_state.call(\"get_required_hits\"") >= 0, "item egg incubation should prefer the egg state's own required-hits roll")


func _verify_egg_settle_oscillation() -> void:
	# Roly-poly (오뚜기) settle: after motion stops, the egg should swing back and
	# forth across upright and take a while to rest — NOT snap straight back.
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(-800.0, -800.0)  # far away: no nudge disturbs the settle
	var settle_state := LingpetEggFieldState.new()
	settle_state.pos = Vector2(300.0, 704.0)
	settle_state.roll_angle = PI * 0.5
	var started_signed: float = _signed_angle_delta(0.0, settle_state.roll_angle)
	_expect(started_signed > 0.0, "settle fixture should start tilted to one side")
	var crossings: int = 0
	var min_signed: float = started_signed
	var max_step: float = 0.0
	var frames_to_rest: int = -1
	var prev_signed: float = started_signed
	var prev_angle: float = settle_state.roll_angle
	for i in range(400):
		settle_state.update_player_contact(0.016, owner)
		var signed: float = _signed_angle_delta(0.0, settle_state.roll_angle)
		if absf(signed) > 0.01 and absf(prev_signed) > 0.01 and (signed > 0.0) != (prev_signed > 0.0):
			crossings += 1
		min_signed = minf(min_signed, signed)
		max_step = maxf(max_step, absf(_signed_angle_delta(prev_angle, settle_state.roll_angle)))
		if frames_to_rest < 0 and settle_state.roll_angle == 0.0:
			frames_to_rest = i
		prev_signed = signed
		prev_angle = settle_state.roll_angle
	_expect(min_signed < -0.03, "roly-poly settle should OVERSHOOT past upright to the other side, not stop at upright")
	_expect(crossings >= 2, "roly-poly settle should swing back and forth across upright at least twice (오뚜기)")
	_expect(frames_to_rest >= 40, "gentle settle should take many frames to come to rest, not a fast snap-back")
	_expect(frames_to_rest > 0, "settle should actually reach rest within the observation window")
	_expect(max_step < 0.30, "settle wobble peak should stay below the old monotonic snap's opening rush")
	var final_err: float = absf(_signed_angle_delta(0.0, settle_state.roll_angle))
	_expect(final_err <= LingpetEggFieldState.EGG_ROLL_SETTLE_EPSILON * 1.5, "damped settle should still come to rest near upright")
	settle_state.reset_contact_motion()
	_expect_float(float(settle_state.roll_settle_vel), 0.0, "reset_contact_motion should clear the settle wobble velocity")


func _verify_egg_dash_collision_knocks_and_wall_rebounds() -> void:
	var dash_state := FakeDashState.new()
	var registry := FakeRegistry.new({"smasher_dash_state": dash_state})
	var owner := FakeOwner.new()
	owner.player_paddle_width = 120.0
	owner.player_paddle_height = 50.0
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	var start_pos: Vector2 = owner.lingpet_egg_pos
	owner.player_pos = Vector2(
		start_pos.x - owner.player_paddle_width - 90.0,
		start_pos.y - owner.player_paddle_height * 0.5
	)
	runtime.update(0.016, owner, registry)
	dash_state.active = true
	dash_state.direction = 1.0
	owner.player_pos = Vector2(
		start_pos.x - owner.player_paddle_width * 0.5 - 2.0,
		start_pos.y - owner.player_paddle_height * 0.5
	)
	runtime.update(0.016, owner, registry)
	var knocked_pos: Vector2 = owner.lingpet_egg_pos
	var knocked_snapshot: Dictionary = runtime.get_snapshot()
	_expect(knocked_pos.x > start_pos.x + 6.0, "player dash contact should knock the Ringpet egg away from the dash")
	_expect(float(knocked_snapshot.get("egg_dash_vx", 0.0)) > 0.0, "Ringpet egg should keep dash knockback velocity after dash contact")
	_expect(int(owner.lingpet_hatch_hits) == 0, "player dash contact should not count as a hatch hit")
	dash_state.active = false
	dash_state.direction = 0.0
	runtime.update(0.016, owner, registry)
	_expect(owner.lingpet_egg_pos.x > knocked_pos.x, "dash-knocked Ringpet egg should keep sliding briefly after contact")

	var wall_dash_state := FakeDashState.new()
	var wall_registry := FakeRegistry.new({"smasher_dash_state": wall_dash_state})
	var wall_owner := FakeOwner.new()
	wall_owner.player_paddle_width = 120.0
	wall_owner.player_paddle_height = 50.0
	var wall_runtime: Object = LingpetEggRuntime.new()
	wall_runtime.update(0.0, wall_owner, wall_registry)
	var wall_y: float = wall_owner.lingpet_egg_pos.y
	var wall_x: float = LingpetEggFieldState.FIELD_WIDTH - LingpetEggFieldState.EGG_TEXTURE_DRAW_SIZE.x * 0.5
	wall_owner.player_pos = Vector2(
		wall_x - wall_owner.player_paddle_width - 90.0,
		wall_y - wall_owner.player_paddle_height * 0.5
	)
	wall_runtime.update(0.016, wall_owner, wall_registry)
	wall_runtime._egg_state.pos = Vector2(wall_x - 1.0, wall_y)
	wall_dash_state.active = true
	wall_dash_state.direction = 1.0
	wall_owner.player_pos = Vector2(
		wall_x - wall_owner.player_paddle_width * 0.5 - 2.0,
		wall_y - wall_owner.player_paddle_height * 0.5
	)
	wall_runtime.update(0.016, wall_owner, wall_registry)
	var wall_snapshot: Dictionary = wall_runtime.get_snapshot()
	_expect(wall_owner.lingpet_hatch_hits == 0, "wall rebound fixture should not affect hatch progress")
	_expect(wall_owner.lingpet_egg_pos.x <= wall_x, "Ringpet egg should stay inside the playfield when it hits the wall")
	_expect(float(wall_snapshot.get("egg_dash_vx", 0.0)) < 0.0, "Ringpet egg should rebound away from the wall")
	wall_dash_state.active = false
	var rebound_start_x: float = wall_owner.lingpet_egg_pos.x
	wall_runtime.update(0.016, wall_owner, wall_registry)
	_expect(wall_owner.lingpet_egg_pos.x < rebound_start_x, "wall rebound should push the Ringpet egg back toward the opposite side")

	var item_dash_state := FakeDashState.new()
	var item_registry := FakeRegistry.new({"smasher_dash_state": item_dash_state})
	var item_owner := FakeOwner.new()
	item_owner.ai_mode = "champion"
	item_owner.player_paddle_width = 120.0
	item_owner.player_paddle_height = 50.0
	var item_runtime: Object = LingpetEggRuntime.new()
	_expect(bool(item_runtime.debug_grant_and_activate_pet("maribo", item_owner, false, "", "", item_registry)), "dash fixture should start with an active companion")
	_expect(bool(item_runtime.deploy_egg_from_item(item_owner, item_registry)), "dash fixture should deploy a coexisting item egg")
	var item_egg_state: Object = item_runtime.get("_item_egg_state") as Object
	var item_start_pos: Vector2 = item_egg_state.pos
	item_owner.player_pos = Vector2(
		item_start_pos.x - item_owner.player_paddle_width - 90.0,
		item_start_pos.y - item_owner.player_paddle_height * 0.5
	)
	item_runtime.update(0.016, item_owner, item_registry)
	item_dash_state.active = true
	item_dash_state.direction = 1.0
	item_owner.player_pos = Vector2(
		item_start_pos.x - item_owner.player_paddle_width * 0.5 - 2.0,
		item_start_pos.y - item_owner.player_paddle_height * 0.5
	)
	item_runtime.update(0.016, item_owner, item_registry)
	_expect(item_egg_state.pos.x > item_start_pos.x + 6.0, "deployed item egg should use the same dash knockback path")
	_expect(bool(item_runtime.is_item_egg_active()), "dash knockback should not consume or hatch the deployed item egg")


func _verify_player_serve_ball_does_not_hatch_egg() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var egg_hit_audio := FakeEggHitAudio.new()
	var registry := FakeRegistry.new({"game_audio": egg_hit_audio})
	runtime.update(0.0, owner, registry)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_serve_origin = "player"
	_register_hit(runtime, owner, egg_pos, 1, registry)
	_expect(int(owner.lingpet_hatch_hits) == 0, "player serve ball should not crack the egg (no hatch count)")
	_expect(str(owner.lingpet_state) == "egg", "player serve ball should not hatch the Ringpet egg")
	# 서브공은 알과 타격판정 자체를 하지 않고 그대로 통과한다: 바운스가 없으므로 공
	# 속도가 입력값(0, 12)에서 변하지 않고(아래로 계속 진행), 히트 SFX도 울리지 않는다.
	# 이 두 단언은 서브공 통과 로직을 예전의 "바운스+SFX는 시키고 카운트만 제외"로
	# 되돌리면 RED가 되는 반증 시일이다.
	_expect(owner.ball_vel.y > 0.0 and is_equal_approx(owner.ball_vel.x, 0.0), "player serve ball should pass straight through the egg without any bounce")
	_expect(egg_hit_audio.egg_hit_calls == 0, "a passed-through player-serve ball must NOT play the egg-hit SFX (no hit detection at all)")

	var serve_only_calls := egg_hit_audio.egg_hit_calls
	owner.ball_serve_origin = "boss"
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	runtime.update(0.21, owner, registry)
	_register_hit(runtime, owner, egg_pos, 2, registry)
	_expect(int(owner.lingpet_hatch_hits) == 1, "non-player-serve ball hits should still count as a hatch hit")
	_expect(str(owner.lingpet_state) == "companion", "non-player-serve ball hit should hatch the Ringpet egg")
	_expect(egg_hit_audio.egg_hit_calls > serve_only_calls, "a counted (non-serve) hatch hit should also play the egg-hit bone-break SFX")


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
	# The hatch itself now defers through the shell-break cinematic; the paddle
	# reflection under test still resolves on the hit frame.
	_expect(bool(runtime.is_hatch_break_active()), "the reflection hatch hit should start the shell-break sequence")
	_pump_hatch_break(runtime, owner)
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
	_expect(owner.lingpet_loadouts is Dictionary and (owner.lingpet_loadouts as Dictionary).has(hatched_id), "hatched lingpet should receive a persisted hatch-roll loadout shell")
	var hatched_loadout: Dictionary = (owner.lingpet_loadouts as Dictionary).get(hatched_id, {}) as Dictionary
	var selected_active_id := str(hatched_loadout.get("active_skill_id", ""))
	var selected_passive_id := str(hatched_loadout.get("passive_skill_id", ""))
	_expect(str(owner.lingpet_active_skill_id) == selected_active_id, "owner should publish the active skill selected by the lingpet loadout")
	_expect(str(owner.lingpet_passive_skill_id) == selected_passive_id, "owner should publish the passive skill selected by the lingpet loadout")
	var hatched_hit_gauge_gain := float(runtime.get_gauge_gain_per_hit(50.0))
	# Hatch passive is now randomly drawn from the common pool, so only a rolled Resonance Boost
	# raises gauge gain; any other passive (or none) leaves the base gauge gain untouched.
	if selected_passive_id == "lingpet_resonance_boost":
		_expect(hatched_hit_gauge_gain > 50.0, "hatched Resonance Boost passive should apply a gauge-gain bonus")
	else:
		_expect_float(hatched_hit_gauge_gain, 50.0, "no passive or a non-gauge passive should keep base gauge gain")
	_expect(runtime.has_visible_effects(), "hatched lingpet should keep visible companion effects after hatching")
	_expect(owner.lingpet_companion_pos is Vector2 and owner.lingpet_companion_pos != Vector2.ZERO, "hatched lingpet should publish companion position")
	var runtime_snapshot: Dictionary = runtime.get_snapshot()
	_expect(float(runtime_snapshot.get("hatch_flash_timer", 0.0)) > 0.0, "hatched lingpet should keep the egg-break animation active briefly")
	_expect(str(runtime_snapshot.get("active_skill_id", "")) == selected_active_id, "runtime snapshot should expose the selected active skill id")
	_expect(str(runtime_snapshot.get("passive_skill_id", "")) == selected_passive_id, "runtime snapshot should expose the selected passive skill id")
	_expect_hatched_skill_channel_matches_owner(owner, runtime_snapshot, hatched_loadout, "active", "hatched active skill roll")
	_expect_hatched_skill_channel_matches_owner(owner, runtime_snapshot, hatched_loadout, "passive", "hatched passive skill roll")
	var panel: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(panel.get("title", "")) == LingpetCatalog.get_display_name(hatched_id), "character-info panel should reveal the hatched lingpet after hatching")
	_expect(str(panel.get("subtitle", "")) == LanguageSettings.translate_text("동행 중"), "character-info panel should show the plain 동행 중 companion status after hatching (R3b: permanent affinity title removed)")


func _verify_affinity_hatch_bonus_hook() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true

	_register_hit(runtime, owner, egg_pos, 1)
	var hatched_id := str(owner.active_lingpet_id)
	_expect(hatched_id != "", "affinity hatch hook should run after the egg resolves a concrete pet id")
	_expect_float(runtime.get_affinity_points(hatched_id), 25.0, "hatching should grant the once-per-pet affinity hatch bonus")
	_expect_eq(runtime.get_affinity_level(hatched_id), 0, "single hatch bonus should stay below the first affinity level")
	var duplicate: Dictionary = runtime.debug_add_affinity_points_for_tests(hatched_id, LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(duplicate.get("granted_points", 0.0)), 0.0, "manual duplicate hatch bonus should be blocked by the runtime-owned affinity state")
	_expect_str(str(duplicate.get("blocked_reason", "")), "hatch_bonus_granted", "duplicate hatch bonus should report its gate")

	runtime.reset_round({"owner": owner})
	var after_round_reset: Dictionary = runtime.debug_add_affinity_points_for_tests(hatched_id, LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(after_round_reset.get("granted_points", 0.0)), 0.0, "round reset should not reload the hatch affinity bonus")

	_expect(runtime.debug_grant_and_activate_pet(hatched_id, owner), "debug reactivation should keep the already-hatched pet active")
	var after_body_reset_path: Dictionary = runtime.debug_add_affinity_points_for_tests(hatched_id, LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(after_body_reset_path.get("granted_points", 0.0)), 0.0, "companion runtime reset paths should not reset the affinity hatch gate")

	runtime.reset_for_tests()
	var fresh_run_hatch: Dictionary = runtime.debug_add_affinity_points_for_tests(hatched_id, LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(fresh_run_hatch.get("granted_points", 0.0)), 25.0, "full runtime reset should start a fresh affinity run for tests/new runs")


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2, index: int, registry: Object = null) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)
	# The final counted hit defers the hatch behind the shell-break cinematic
	# (physics held by the modal gate; clock pumped from the ungated idle path).
	# Mirror that pump so post-hatch assertions see the committed state.
	_pump_hatch_break(runtime, owner, registry)


func _pump_hatch_break(runtime: Object, owner: Object, registry: Object = null) -> void:
	var pump_guard := 0
	while bool(runtime.is_hatch_break_active()) and pump_guard < 300:
		runtime.advance_hatch_break(1.0 / 60.0, owner, registry)
		pump_guard += 1


func _finish_acquire_cutin(runtime: Object, registry: Object = null) -> void:
	runtime.advance_acquire_cutin(3.0, registry)
	if runtime.has_method("is_acquire_cutin_awaiting_dismiss") and bool(runtime.is_acquire_cutin_awaiting_dismiss()):
		runtime.begin_acquire_cutin_dismiss(registry)
	var guard := 0
	while runtime.has_method("is_acquire_cutin_active") and bool(runtime.is_acquire_cutin_active()) and guard < 700:
		runtime.advance_acquire_cutin(0.1, registry)
		guard += 1
	_expect(not bool(runtime.is_acquire_cutin_active()), "test helper should finish the acquisition cut-in")


func _skill_state_for_runtime_slot(runtime: Object, slot_index: int) -> Object:
	return LingpetCompanionSkillPersistence.new().get_state_for_slot(runtime._companion_skill_states, slot_index)


func _seed_lingpet_roster(owner: Object, pet_ids: Array[String], active_slot_index: int = 0) -> void:
	var ids: Array = pet_ids.duplicate()
	var collection: Dictionary = {}
	for pet_id in ids:
		collection[pet_id] = true
	owner.lingpet_owned_pet_ids = ids.duplicate()
	owner.owned_lingpet_ids = ids.duplicate()
	owner.owned_ringpet_ids = ids.duplicate()
	owner.lingpet_collection = collection.duplicate(true)
	owner.ringpet_collection = collection.duplicate(true)
	owner.owned_lingpets = collection.duplicate(true)
	owner.owned_ringpets = collection.duplicate(true)
	owner.lingpet_slots = ids.duplicate()
	while owner.lingpet_slots.size() < 3:
		owner.lingpet_slots.append("")
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = active_slot_index
	owner.ringpet_active_slot_index = active_slot_index


# The final counted egg hit no longer opens the acquire cut-in on the same
# frame: the 1.5s shell-break cinematic (state-scripted roll + staged cracks +
# light leak) runs first, the shell bursts and holds briefly so the shard burst
# reads, and only the deferred commit opens the cut-in. Battle physics is held
# by the modal gate for the whole window; the clock is pumped from the frame
# controller's ungated idle path (advance_hatch_break), mirroring the cut-in.
func _verify_hatch_break_sequence_defers_cutin() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	var audio := FakePaddleAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	# Drive the final hit WITHOUT the shared helper's auto-pump so the deferred
	# window itself can be asserted.
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(1.0, -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)
	_expect(bool(runtime.is_hatch_break_active()), "final counted hit should start the shell-break sequence")
	_expect(not bool(runtime.is_acquire_cutin_active()), "acquire cut-in must not open on the hatch frame anymore")
	_expect(str(owner.lingpet_state) == "egg", "the egg must stay in the egg state through the shell-break window")
	_expect(audio.lingpet_acquire_count == 0, "acquisition cut-in audio must not play before the deferred commit")
	# The gated update path must be inert during the break (modal-gate mirror).
	var pos_before_gated: Vector2 = runtime._egg_state.pos
	runtime.update(0.5, owner, registry)
	_expect(runtime._egg_state.pos == pos_before_gated and bool(runtime.is_hatch_break_active()), "gated update() must not advance or cancel the shell-break sequence")
	# The break motion must actually ROLL the egg (position + roll angle move).
	var moved := false
	var rolled := false
	for _i in range(30):
		runtime.advance_hatch_break(1.0 / 60.0, owner, registry)
		if absf(runtime._egg_state.pos.x - egg_pos.x) > 2.0:
			moved = true
		var roll_angle := float(runtime._egg_state.roll_angle)
		if absf(roll_angle) > 0.01 and absf(roll_angle - TAU) > 0.01:
			rolled = true
	_expect(moved, "shell-break should visibly roll the egg sideways")
	_expect(rolled, "shell-break roll should rotate the egg (rolling, not sliding)")
	_expect(not bool(runtime.is_acquire_cutin_active()), "cut-in must stay closed mid-break")
	# Complete the break: the shell bursts (hatch flash + shard burst) and holds
	# briefly; the cut-in opens only after the burst hold commits the hatch.
	var burst_seen := false
	var guard := 0
	while bool(runtime.is_hatch_break_active()) and guard < 300:
		runtime.advance_hatch_break(1.0 / 60.0, owner, registry)
		if bool(runtime._egg_state.has_hatch_flash()) and not bool(runtime.is_acquire_cutin_active()):
			burst_seen = true
		guard += 1
	_expect(burst_seen, "the shard burst must start BEFORE the cut-in opens (burst hold)")
	_expect(bool(runtime.is_acquire_cutin_active()), "deferred commit should open the acquire cut-in")
	_expect(audio.lingpet_acquire_count == 1, "acquisition cut-in audio should play once at the deferred commit")
	_expect(str(owner.lingpet_state) == "companion", "deferred commit should activate the hatched companion")
	_expect(str(owner.active_lingpet_id) != "", "deferred commit should publish the hatched pet id")

	# Structural seals: the pause / pump / input wiring mirrors the acquire cut-in.
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var resolve_body: String = _function_body(runtime_source, "func _resolve_ball_hit")
	_expect(resolve_body.find("_egg_state.trigger_hatch_break()") >= 0, "the hatched branch must defer through the shell-break trigger")
	_expect(resolve_body.find("_finish_regular_hatch(") < 0 and resolve_body.find("_begin_overflow_hatch(") < 0, "the hatched branch must not commit the hatch on the hit frame")
	var modal_gate_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(modal_gate_source.find("physics.modal_gate.lingpet_hatch_break") >= 0 and modal_gate_source.find("is_hatch_break_active") >= 0, "the modal gate must hold battle physics through the shell-break window")
	var frame_controller_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_controller_source.find("advance_hatch_break") >= 0, "the frame controller idle pump must advance the shell-break clock while physics is held")
	var lingpet_input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_interaction_input_router.gd")
	_expect(lingpet_input_source.find("is_hatch_break_active") >= 0, "the lingpet input router must swallow input during the shell-break beat (mid-break pause/save would strand an uncommitted hatch)")
	var egg_break_renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
	_expect(egg_break_renderer_source.find("func draw_hatch_break_egg") >= 0 and egg_break_renderer_source.find("HATCH_BREAK_CRACK_STAGE_RATIOS") >= 0, "the egg renderer must own the staged shell-break crack visuals")
	var behind_pass_body: String = _function_body(runtime_source, "func draw_lingpet_body_behind_actors")
	_expect(behind_pass_body.find("draw_hatch_break_egg") >= 0, "the behind-actors egg pass must render the shell-break sequence")


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
	# Advance through the exit action + fade until the cut-in auto-closes. Dismiss durations
	# vary by pet (cutin_dismiss_seconds, up to ~4.25s for Koyora) and the random hatch may
	# pick any live pet, so loop to completion instead of assuming a fixed advance budget.
	var dismiss_guard := 0
	while bool(runtime.is_acquire_cutin_active()) and dismiss_guard < 600:
		runtime.advance_acquire_cutin(0.1)
		dismiss_guard += 1
	_expect(dismiss_guard < 600, "the acquisition cut-in exit action should auto-complete within the guard budget")
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


func _verify_pro_league_egg_item_deploy() -> void:
	# Pro (champion) / Mythic leagues do NOT auto-present the lingpet at battle start;
	# it must be deployed via the "lingpet_egg" active item. Junior keeps the
	# auto-present behavior (covered by the owned-maribo / egg-spawn tests above).
	var host := FakeCutinHost.new()
	host.done_after = 99
	var registry := FakeRegistry.new({"lingpet_acquire_cutin_overlay_host": host})

	# Champion: a fresh owner stays STATE_NONE on update (no auto egg spawn).
	var champion_owner := FakeOwner.new()
	champion_owner.ai_mode = "champion"
	var champion_runtime: Object = LingpetEggRuntime.new()
	champion_runtime.update(0.0, champion_owner, registry)
	_expect(str(champion_owner.lingpet_state) == "none", "Pro league should not auto-spawn a lingpet egg at battle start")
	_expect(bool(champion_runtime.can_offer_egg_item(champion_owner, registry)), "Pro league should offer the egg item while no lingpet is deployed")

	# Using the egg item deploys the egg with a random catalog pet (STATE_EGG).
	_expect(bool(champion_runtime.deploy_egg_from_item(champion_owner, registry)), "egg item use should deploy the egg in Pro league")
	_expect(str(champion_owner.lingpet_state) == "egg", "deployed egg item should place the egg in the field (egg phase)")
	var deployed_pet_id := str(champion_runtime.get("_pet_id"))
	_expect(LingpetCatalog.has_pet(deployed_pet_id), "deployed egg should resolve a valid random catalog pet")
	_expect(host.prewarm_calls.has(deployed_pet_id), "egg item use should kick acquisition cut-in streaming as soon as the pet id is known")

	# Once deployed, the item no longer offers and a second use is a no-op so the
	# slot controller leaves the item unconsumed (see _try_use_slot).
	_expect(not bool(champion_runtime.can_offer_egg_item(champion_owner, registry)), "egg item should stop being offered once a lingpet is deployed")
	_expect(not bool(champion_runtime.deploy_egg_from_item(champion_owner, registry)), "deploying a second egg while one is already present must be a no-op")

	# Champion auto-adopt is also suppressed: owning a pet must NOT auto-deploy it
	# (the whole point is to earn the deploy via the item). Contrast the junior
	# owned-maribo test, which adopts directly.
	var owned_champion := FakeOwner.new()
	owned_champion.ai_mode = "champion"
	owned_champion.lingpet_owned_pet_ids = ["maribo"]
	var owned_champion_runtime: Object = LingpetEggRuntime.new()
	owned_champion_runtime.update(0.0, owned_champion, registry)
	_expect(str(owned_champion.lingpet_state) == "none", "Pro league must not auto-adopt an owned lingpet at battle start")
	_expect(bool(owned_champion_runtime.can_offer_egg_item(owned_champion, registry)), "Pro league with an owned pet should still require the egg item to deploy")

	# Mythic league behaves like Pro (also gated).
	var mythic_owner := FakeOwner.new()
	mythic_owner.ai_mode = "mythic"
	var mythic_runtime: Object = LingpetEggRuntime.new()
	mythic_runtime.update(0.0, mythic_owner, registry)
	_expect(str(mythic_owner.lingpet_state) == "none", "Mythic league should not auto-spawn a lingpet egg at battle start")
	_expect(bool(mythic_runtime.can_offer_egg_item(mythic_owner, registry)), "Mythic league should offer the egg item while no lingpet is deployed")


# Coexist incubator egg: using the lingpet_egg item while a companion is ALREADY on field
# must NOT suspend / replace the companion. The companion keeps accompanying the player and
# stays in the character-info panel; a SEPARATE egg incubates alongside it, and on hatch the
# new pet is absorbed into a free collection slot (digital absorb VFX) without stealing the
# active companion. Reverse-verified: the pre-coexist suspend code published lingpet_state
# "egg" and cleared the companion -- the exact bug this slice fixes.
func _verify_lingpet_egg_deploys_while_companion_active() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "champion"
	var host := FakeCutinHost.new()
	host.done_after = 99
	var registry := FakeRegistry.new({"lingpet_acquire_cutin_overlay_host": host})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)), "fixture should start with Maribo as an active companion")
	_expect(bool(runtime.can_offer_egg_item(owner, registry)), "egg should still be offerable while a companion is active")
	_expect(bool(runtime.deploy_egg_from_item(owner, registry)), "egg item should deploy a coexisting incubator while a companion is active")
	# The companion is NOT replaced -- it stays on field and in the panel.
	_expect(str(owner.lingpet_state) == "companion", "deploying the egg must NOT suspend/replace the active companion")
	_expect(str(owner.active_lingpet_id) == "maribo", "the active companion should stay Maribo while the new egg incubates")
	_expect(bool(runtime.is_item_egg_active()), "a separate incubator egg should be active alongside the companion")
	var egg_pet_id := str(runtime.get_item_egg_pet_id())
	_expect(egg_pet_id != "maribo" and LingpetCatalog.has_pet(egg_pet_id), "incubator egg should roll an unowned catalog pet")
	_expect(host.prewarm_calls.has(egg_pet_id), "coexisting egg item use should kick acquisition cut-in streaming for the rolled pet immediately")
	# No second egg may be offered / deployed while one is already incubating.
	_expect(not bool(runtime.can_offer_egg_item(owner, registry)), "no second egg item should be offered while an incubator egg is active")
	_expect(not bool(runtime.deploy_egg_from_item(owner, registry)), "a second incubator deploy must be a no-op while one is active")

	_hatch_item_egg_with_reveal(runtime, owner, registry)
	# Hatch outcome: the new pet is absorbed into a free slot; the companion is UNCHANGED.
	_expect(str(owner.lingpet_state) == "companion", "the companion should remain active after the incubator egg hatches")
	_expect(str(owner.active_lingpet_id) == "maribo", "the absorbed pet is collected, NOT made the companion")
	_expect(not bool(runtime.is_item_egg_active()), "the incubator egg should clear after hatching")
	_expect(bool(runtime.is_item_egg_absorbing()), "hatching should trigger the digital absorb VFX")
	_expect((owner.lingpet_owned_pet_ids as Array).size() == 2, "owned roster should grow to two pets")
	_expect((owner.lingpet_owned_pet_ids as Array).has("maribo"), "the companion should remain owned")
	_expect((owner.lingpet_owned_pet_ids as Array).has(egg_pet_id), "the absorbed pet should be added to ownership")
	_expect((owner.lingpet_slots as Array).has("maribo"), "the companion should keep its battle slot")
	_expect((owner.lingpet_slots as Array).has(egg_pet_id), "the absorbed pet should fill an empty battle slot")
	_expect(int(owner.lingpet_active_slot_index) == (owner.lingpet_slots as Array).find("maribo"), "the active slot should stay the companion's, not the absorbed pet's")
	_expect(not bool(runtime.is_overflow_choice_active()), "an empty-slot absorb should not open the overflow modal")


# Hits the COEXIST incubator egg (not the main egg) until it hatches. The incubator egg's
# pet is random, so its required_hits can be > 1; loop until is_item_egg_active() clears.
# After this returns the reveal acquire cut-in is active (the egg has hatched into the
# reveal phase), but the new pet is NOT yet absorbed -- call _finish_item_egg_reveal next.
func _register_item_egg_hits_until_hatched(runtime: Object, owner: FakeOwner, registry: Object = null, max_hits: int = 12) -> void:
	owner.ball_active = true
	var guard := 0
	while bool(runtime.is_item_egg_active()) and guard < max_hits:
		var pos: Vector2 = (runtime.get("_item_egg_state") as Object).pos
		_register_hit(runtime, owner, pos, guard + 1, registry)
		guard += 1


# Drives the full incubator-egg hatch: hit until hatched (reveal cut-in opens), assert the
# acquire cut-in (획득 라투디 + 클릭 라투디) plays for the new pet, dismiss it, then run one
# update(owner) so the deferred absorb (_perform_item_egg_absorb) restores the companion and
# registers / overflows the new pet.
func _verify_item_egg_hatch_rolls_loadout() -> void:
	# REGRESSION: item-egg hatches (the 2nd+ consecutive hatch, while a companion stays active)
	# must roll their hatch loadout like the regular hatch -- not fall back to a DEFAULT Lv.1/Lv.1
	# loadout. Drive several real item-egg hatches and confirm the absorbed pet's STORED loadout
	# level reflects a roll (varies, including levels >= 2), and is persisted to owner.lingpet_loadouts.
	# Without the hatch-stat owner's item-egg trait roll every item-egg pet would be exactly Lv.1, so over this
	# many rolls (>= 2 levels each) at least one level >= 2 is effectively certain (~1 - 0.5^N).
	var saw_level_two_or_more := false
	var saw_none_or_one := false
	var all_present := true
	var hatched_count := 0
	for _attempt in range(16):
		var owner := FakeOwner.new()
		owner.ai_mode = "champion"
		var registry := FakeRegistry.new({})
		var runtime: Object = LingpetEggRuntime.new()
		runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)
		if not bool(runtime.deploy_egg_from_item(owner, registry)):
			continue
		var egg_pet_id := str(runtime.get_item_egg_pet_id())
		_hatch_item_egg_with_reveal(runtime, owner, registry)
		var loadouts: Dictionary = owner.lingpet_loadouts as Dictionary
		if not loadouts.has(egg_pet_id):
			all_present = false
			continue
		hatched_count += 1
		var lo: Dictionary = loadouts.get(egg_pet_id, {}) as Dictionary
		var active_level := int(lo.get("active_skill_level", 1))
		var passive_level := int(lo.get("passive_skill_level", 1))
		_expect(active_level >= 0 and active_level <= 3, "item-egg active hatch level should stay in the 0..3 roll range")
		_expect(passive_level >= 0 and passive_level <= 3, "item-egg passive hatch level should stay in the 0..3 roll range")
		if active_level >= 2 or passive_level >= 2:
			saw_level_two_or_more = true
		if active_level <= 1 or passive_level <= 1:
			saw_none_or_one = true
	_expect(hatched_count > 0, "fixture should hatch at least one item egg into a free slot")
	_expect(all_present, "every item-egg-hatched pet should persist its rolled loadout into owner.lingpet_loadouts")
	_expect(saw_level_two_or_more, "item-egg hatches must ROLL the loadout (a level >= 2 must appear), not default to Lv.1")
	_expect(saw_none_or_one, "item-egg roll should still produce low (none/Lv.1) levels too, proving a real distribution")


func _hatch_item_egg_with_reveal(runtime: Object, owner: FakeOwner, registry: Object = null) -> void:
	var companion_before := str(owner.active_lingpet_id)
	var state_before := str(owner.lingpet_state)
	_register_item_egg_hits_until_hatched(runtime, owner, registry)
	_expect(bool(runtime.is_acquire_cutin_active()), "incubator-egg hatch should play the acquire cut-in for the new pet before absorbing")
	# High: the not-yet-absorbed new pet must NOT be published as the active companion during
	# the reveal -- owner active_lingpet_id / lingpet_state keep pointing at the real companion.
	_expect(str(owner.active_lingpet_id) == companion_before, "reveal must NOT publish the new pet as the active companion (owner active_lingpet_id unchanged)")
	_expect(str(owner.lingpet_state) == state_before, "reveal must keep the owner lingpet_state as the companion")
	# Medium: no new egg can be offered/deployed during the reveal.
	_expect(not bool(runtime.can_offer_egg_item(owner, registry)), "no egg should be offerable during the incubator-egg reveal")
	_finish_acquire_cutin(runtime, registry)
	# Medium: the gap between the cut-in closing and the deferred absorb must also stay closed.
	_expect(not bool(runtime.can_offer_egg_item(owner, registry)), "no egg should be offerable between cut-in close and absorb")
	_expect(not bool(runtime.deploy_egg_from_item(owner, registry)), "no egg should deploy between cut-in close and absorb")
	runtime.update(0.0, owner, registry)


# Coexist incubator egg, ROSTER FULL: hatching opens a slot-replace choice WITHOUT
# disturbing the active companion. Replace registers the new pet into the chosen
# (non-companion) slot and keeps the companion active; release discards the new pet and
# leaves the roster + companion untouched.
func _verify_lingpet_egg_overflow_replace_release_choice() -> void:
	var full_roster: Array[String] = ["maribo", "lunabi", "milkring"]

	# --- Replace path ---
	var replace_owner := FakeOwner.new()
	replace_owner.ai_mode = "champion"
	_seed_lingpet_roster(replace_owner, full_roster, 0)
	var replace_registry := FakeRegistry.new({})
	var replace_runtime: Object = LingpetEggRuntime.new()
	_expect(bool(replace_runtime.debug_grant_and_activate_pet("maribo", replace_owner, false, "", "", replace_registry)), "replace fixture should start with an active full roster")
	_expect(bool(replace_runtime.deploy_egg_from_item(replace_owner, replace_registry)), "full roster should still allow a coexisting incubator egg")
	var pending_replace_id := str(replace_runtime.get_item_egg_pet_id())
	_hatch_item_egg_with_reveal(replace_runtime, replace_owner, replace_registry)
	# Roster full -> after the reveal + absorb, the slot-replace choice opens.
	_expect(bool(replace_runtime.is_overflow_choice_active()), "a full-roster incubator hatch should open the slot-replace choice")
	_expect(str(replace_owner.active_lingpet_id) == "maribo", "the companion stays active while the overflow choice is open")
	_expect(not (replace_owner.lingpet_owned_pet_ids as Array).has(pending_replace_id), "overflow hatch should not be owned before the choice commits")
	var old_slot_pet := str((replace_owner.lingpet_slots as Array)[1])
	_expect(old_slot_pet != "maribo", "fixture: chosen replace slot 1 should not be the companion's slot")
	_expect(bool(replace_runtime.commit_overflow_replace(1, replace_owner, replace_registry)), "replace commit should accept a chosen existing slot")
	_expect((replace_owner.lingpet_owned_pet_ids as Array).size() == 3, "replace should keep the owned roster capped at three")
	_expect((replace_owner.lingpet_owned_pet_ids as Array).has(pending_replace_id), "replace should keep the newly hatched pet")
	_expect(not (replace_owner.lingpet_owned_pet_ids as Array).has(old_slot_pet), "replace should permanently release the chosen old pet")
	_expect(str((replace_owner.lingpet_slots as Array)[1]) == pending_replace_id, "new pet should take the selected battle slot")
	# The companion is preserved -> it stays active, NOT the newly placed pet.
	_expect(str(replace_owner.active_lingpet_id) == "maribo", "replace must keep the companion active, not the absorbed pet")
	_expect(not bool(replace_runtime.is_overflow_choice_active()), "replace commit should close the overflow modal")
	_expect(float(replace_runtime.get_affinity_points(pending_replace_id)) > 0.0, "kept overflow hatch should receive the hatch affinity grant")
	# REGRESSION (Codex Medium): the full-roster overflow-REPLACE commit must ROLL + persist the
	# hatch loadout for the kept new pet, exactly like the free-slot absorb path
	# (_verify_item_egg_hatch_rolls_loadout). _commit_item_egg_overflow_replace rolls via
	# roll_item_egg_hatch_traits then republishes through _sync_owner (companion-untouched branch),
	# so the rolled loadout must already be on owner.lingpet_loadouts after the commit. Without that
	# roll the kept pet would silently fall back to a DEFAULT Lv.1/Lv.1 loadout.
	var replace_loadouts: Dictionary = replace_owner.lingpet_loadouts as Dictionary
	_expect(replace_loadouts.has(pending_replace_id), "overflow-replace must persist the rolled hatch loadout into owner.lingpet_loadouts")
	var replace_lo: Dictionary = replace_loadouts.get(pending_replace_id, {}) as Dictionary
	var replace_active := int(replace_lo.get("active_skill_level", 1))
	var replace_passive := int(replace_lo.get("passive_skill_level", 1))
	_expect(replace_active >= 0 and replace_active <= 3, "overflow-replace active hatch level should stay in the 0..3 roll range")
	_expect(replace_passive >= 0 and replace_passive <= 3, "overflow-replace passive hatch level should stay in the 0..3 roll range")

	# --- Release path ---
	var release_owner := FakeOwner.new()
	release_owner.ai_mode = "champion"
	_seed_lingpet_roster(release_owner, full_roster, 0)
	var release_registry := FakeRegistry.new({})
	var release_runtime: Object = LingpetEggRuntime.new()
	_expect(bool(release_runtime.debug_grant_and_activate_pet("maribo", release_owner, false, "", "", release_registry)), "release fixture should start with an active full roster")
	_expect(bool(release_runtime.deploy_egg_from_item(release_owner, release_registry)), "full roster should allow a release-path incubator egg")
	var pending_release_id := str(release_runtime.get_item_egg_pet_id())
	_hatch_item_egg_with_reveal(release_runtime, release_owner, release_registry)
	_expect(bool(release_runtime.is_overflow_choice_active()), "release path should also open the overflow modal")
	_expect(bool(release_runtime.commit_overflow_release(release_owner, release_registry)), "release commit should discard the newly hatched pet")
	_expect((release_owner.lingpet_owned_pet_ids as Array) == full_roster, "release should preserve the original three owned pets")
	_expect(not (release_owner.lingpet_owned_pet_ids as Array).has(pending_release_id), "released new hatch should not enter ownership")
	_expect((release_owner.lingpet_slots as Array) == full_roster, "release should preserve the original battle slots")
	_expect(str(release_owner.active_lingpet_id) == "maribo", "release should keep the companion active untouched")
	_expect(float(release_runtime.get_affinity_points(pending_release_id)) <= 0.0, "released overflow hatch should not receive hatch affinity")


# Trap 5 / safety-critical: an unresolved overflow choice modal must be force-resolved as
# 방생 (release) by reset_round even though the round-cleanup deps carry NO "owner"
# (ball_dependency_context._build_common_round_deps). Otherwise is_overflow_choice_active
# stays true and softlocks the next round. The owner-less commit_overflow_release must clear
# the flag in-memory and self-heal (restore the suspended companion) on the next update(owner).
func _verify_lingpet_egg_overflow_reset_resolves_to_release() -> void:
	var full_roster: Array[String] = ["maribo", "lunabi", "milkring"]
	var owner := FakeOwner.new()
	owner.ai_mode = "champion"
	_seed_lingpet_roster(owner, full_roster, 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)), "reset fixture should start with an active full roster")
	_expect(bool(runtime.deploy_egg_from_item(owner, registry)), "full roster should allow a coexisting incubator egg")
	var pending_id := str(runtime.get_item_egg_pet_id())
	_hatch_item_egg_with_reveal(runtime, owner, registry)
	_expect(bool(runtime.is_overflow_choice_active()), "fixture should reach an open overflow choice modal")

	# Round-cleanup deps carry registry but NOT owner (the owner-less round-cleanup trap).
	runtime.reset_round({"registry": registry})
	_expect(not bool(runtime.is_overflow_choice_active()), "reset_round must force-resolve an unresolved overflow modal so it cannot softlock the next round")

	# The companion was never suspended for the coexist path, so it stays active.
	runtime.update(0.0, owner, registry)
	_expect(str(owner.active_lingpet_id) == "maribo", "the companion stays active after an owner-less reset release")
	_expect((owner.lingpet_owned_pet_ids as Array).size() == 3, "reset 방생 should keep the owned roster capped at three")
	_expect(not (owner.lingpet_owned_pet_ids as Array).has(pending_id), "reset 방생 should not add the unresolved overflow hatch to ownership")


# Junior must NEVER use an egg, even if a direct-grant reward path (Pandora active
# grant, plaza gacha) bypassed the offer/pickup gate and dropped one into a junior
# slot. deploy_egg_from_item is the central use-site seal (item_runtime_checklist §1.7).
# Reverse-verified: removing the is_auto_present_league guard lets the junior deploy
# succeed and this assertion fails.
func _verify_lingpet_egg_deploy_blocked_in_junior() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "junior"
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	# Fresh STATE_NONE runtime where a Pro/Mythic deploy WOULD succeed — only the
	# junior-league guard should reject it.
	_expect(not bool(runtime.deploy_egg_from_item(owner, registry)), "junior league must never deploy an egg from the item (auto-present tutorial invariant)")
	_expect(str(runtime.get("_state")) != "egg", "a blocked junior deploy must not place a field egg")


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
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.owned_ringpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.apply_save_snapshot({
		"pet_id": "maribo",
		"state": "companion",
		"owned_pet_ids": ["maribo"],
		"companion_pos": Vector2.ZERO,
		"companion_patrol_dir": -1.0,
		"companion_patrol_seed": 24680,
		"companion_patrol_speed": 216.0,
	}, owner)
	_expect(owner.lingpet_companion_pos != Vector2.ZERO, "Maribo companion should initialize from a zero saved position")
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
	_expect_float(runtime.get_affinity_points("maribo"), 8.0, "Maribo body collision should grant one direct-hit affinity award")
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
	_expect(str(passive_spec.get("subtitle", "")).find(LanguageSettings.translate_text("이동")) >= 0, "Tailwind Steps passive subtitle should explain the movement-speed bonus")


func _verify_starlight_tracking_passive() -> void:
	var passive_lv1 := LingpetCatalog.get_passive_skill("maribo", "lingpet_starlight_tracking", 1)
	var passive_lv5 := LingpetCatalog.get_passive_skill("maribo", "lingpet_starlight_tracking", 5)
	_expect(str(passive_lv1.get("name", "")) == "별빛 추적", "shared passive catalog should expose the agreed Starlight Tracking Korean name")
	_expect(is_equal_approx(float(passive_lv1.get("starpoint_tracking_chance_pct", 0.0)), 20.0), "Starlight Tracking Lv.1 should start at a 20 percent drop-trigger chance")
	_expect(is_equal_approx(float(passive_lv5.get("starpoint_tracking_chance_pct", 0.0)), 60.0), "Starlight Tracking Lv.5 should scale to a 60 percent drop-trigger chance")
	_expect(float(passive_lv5.get("starpoint_tracking_chase_speed", 0.0)) > float(passive_lv1.get("starpoint_tracking_chase_speed", 0.0)), "Starlight Tracking chase speed should scale by passive level")

	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var stage1_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_starpoint_state.gd")
	var stage2_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_starpoint_coordinator.gd")
	var stage3_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_starpoint_state.gd")
	var stage4_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_bird_starpoint_state.gd")
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
	_expect(str(passive_spec.get("subtitle", "")).find(LanguageSettings.translate_text("추적")) >= 0, "Starlight Tracking passive subtitle should explain the drop-trigger chance")

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

	var owner4 := FakeOwner.new()
	var runtime4: Object = LingpetEggRuntime.new()
	_expect(runtime4.debug_grant_and_activate_pet("maribo", owner4, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", registry, 1, 5), "fourth debug loadout should equip Starlight Tracking Lv.5 for a ground-prediction smoke")
	var ground_start: Vector2 = owner4.lingpet_companion_pos
	var high_drop := _make_starpoint_drop(ground_start + Vector2(150.0, -260.0), 0.0)
	high_drop["vel"] = Vector2(1.6, 4.0)
	owner4.player_pos = ground_start + Vector2(-130.0, 0.0) - Vector2(owner4.player_paddle_width, owner4.player_paddle_height) * 0.5
	var ground_context := _starpoint_delivery_context(owner4)
	ground_context["play_left"] = 0.0
	ground_context["play_right"] = 760.0
	ground_context["height"] = 750.0
	var ground_approach_result: Dictionary = runtime4.update_starlight_tracking_for_starpoint_drop(high_drop, 1.0, ground_context)
	_expect(bool(ground_approach_result.get("ground_tracking", false)), "Ground Starlight Tracking should report the patrol-only ground route")
	_expect(bool(ground_approach_result.get("claimed", false)) and not bool(ground_approach_result.get("picked_up", false)), "Ground Starlight Tracking should claim a high falling star but wait for it near the floor")
	var ground_pos_value: Variant = ground_approach_result.get("companion_pos", Vector2.ZERO)
	var ground_pos: Vector2 = ground_pos_value if ground_pos_value is Vector2 else Vector2.ZERO
	var ground_target_value: Variant = ground_approach_result.get("target_pos", Vector2.ZERO)
	var ground_target: Vector2 = ground_target_value if ground_target_value is Vector2 else Vector2.ZERO
	_expect(ground_pos != Vector2.ZERO and absf(ground_pos.y - ground_start.y) <= 0.01, "Ground Starlight Tracking should move along the floor instead of flying up to a high starpoint")
	_expect(ground_target != Vector2.ZERO and absf(ground_target.y - ground_start.y) <= 0.01, "Ground Starlight Tracking should target the predicted floor catch lane")
	high_drop["pos"] = ground_target + Vector2(0.0, -18.0)
	high_drop["vel"] = Vector2.ZERO
	var ground_catch_result: Dictionary = runtime4.update_starlight_tracking_for_starpoint_drop(high_drop, 0.0, ground_context)
	_expect(bool(ground_catch_result.get("picked_up", false)) and bool(ground_catch_result.get("holding", false)), "Ground Starlight Tracking should catch the falling star after waiting under the predicted point")
	var jump_pos_value: Variant = ground_catch_result.get("companion_pos", Vector2.ZERO)
	var jump_pos: Vector2 = jump_pos_value if jump_pos_value is Vector2 else Vector2.ZERO
	_expect(jump_pos != Vector2.ZERO and jump_pos.y < ground_start.y, "Ground Starlight Tracking should use a small jump at pickup instead of staying flat")


# WIP 파괴 소실 복원 씰: 탈진(포만도 소진) 중엔 위치-스크립팅 패시브 별빛추적이
# 억제돼야 한다. Slice3a 탈진 5소비처 게이트가 이 패시브를 안 덮어 KO 중 순간이동/
# 전달이 났다. companion_active fold(2콜사이트: advance + update_starlight)로 봉인.
func _verify_exhaustion_suppresses_starlight_tracking() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "champion"  # 주니어 리그는 탈진 면제(D9) — 비면제 리그로 강제
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", registry, 1, 5), "exhaustion seal should equip Starlight Tracking Lv.5")
	# 탈진 강제: 포만도 0 + 텔레그래프 창 경과(1.75s).
	runtime.set_satiety_for_tests("maribo", 0.0)
	for _i in 160:
		runtime.update(1.0 / 60.0, owner, registry)
	_expect(runtime.is_companion_exhausted_for_tests(owner), "fixture must reach exhaustion before the suppression assert")
	# 탈진 중 클레임 가능한(roll 0 = 항상 성공) 근접 드랍 → 별빛추적 억제.
	var companion_pos: Vector2 = owner.lingpet_companion_pos
	var drop := _make_starpoint_drop(companion_pos + Vector2(8.0, 0.0), 0.0)
	owner.player_pos = companion_pos + Vector2(116.0, 0.0) - Vector2(owner.player_paddle_width, owner.player_paddle_height) * 0.5
	var result: Dictionary = runtime.update_starlight_tracking_for_starpoint_drop(drop, 0.0, _starpoint_delivery_context(owner))
	_expect(
		not bool(result.get("claimed", false)) and not bool(result.get("picked_up", false)) and not bool(result.get("delivered", false)),
		"exhausted companion must NOT run Starlight Tracking (KO teleport/delivery bug — WIP-loss restore)"
	)
	_expect(not bool(runtime.is_starlight_tracking_active_for_tests()), "exhaustion must clear any Starlight Tracking position override")


# WIP 파괴 소실 복원 씰: 탈진 중엔 링크포트(ring_dash) 비상 순간이동도 억제돼야
# 한다. advance가 _update_companion_motion에서 탈진 판정보다 먼저 돌며
# companion_active만 받아 KO 중 순간이동+VFX+사운드를 냈다(탈진 판정 호이스트로 봉인).
func _verify_exhaustion_suppresses_linkport() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "champion"  # 주니어 면제 회피
	owner.lingpet_ring_dash_force_roll_pct = 0.0  # 롤 강제 성공
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_ring_dash", registry, 1, 5), "exhaustion seal should equip Ring Dash Lv.5")
	# 탈진 강제: 비상 공 없이 텔레그래프 경과(탈진 전 트리거 방지).
	owner.ball_active = false
	runtime.set_satiety_for_tests("maribo", 0.0)
	for _i in 160:
		runtime.update(1.0 / 60.0, owner, registry)
	_expect(runtime.is_companion_exhausted_for_tests(owner), "linkport fixture must reach exhaustion")
	# 탈진 후 비상 하강 공 → 링크포트 억제(트리거/순간이동 없음).
	var start_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(Vector2(120.0, start_pos.y), 2, 0.0, false)
	owner.player_pos = Vector2(240.0, owner.player_pos.y)
	owner.player_paddle_width = 170.0
	owner.ball_active = true
	owner.ball_pos = Vector2(640.0, owner.player_pos.y - 40.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	var trigger_before: int = int(runtime.get_ring_dash_trigger_count_for_tests())
	runtime.update(0.12, owner, registry)
	_expect(not bool(runtime.is_ring_dash_active_for_tests()), "exhausted companion must NOT run Linkport emergency dash (KO teleport bug — WIP-loss restore)")
	_expect(int(runtime.get_ring_dash_trigger_count_for_tests()) == trigger_before, "exhaustion must not spend a Linkport trigger")


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
	_expect(str(passive_spec.get("subtitle", "")).find(LanguageSettings.translate_text("전이")) >= 0, "Linkport passive subtitle should explain the emergency teleport chance")

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
	# Flight pets CAN move to the ball, so Linkport still dives them to the player guard-center
	# Y (~704 for lunabi's 58px catch height at player_pos.y 675), far from the offscreen
	# ingress Y (245). The ground-pet Y-lock must NOT touch flight behavior.
	_expect(absf(owner3.lingpet_companion_pos.y - 704.0) < 2.0, "Linkport should still dive a flight companion to the player guard-center Y")
	_expect(owner3.lingpet_companion_pos.y > 600.0, "Linkport flight dive should pull the offscreen companion down into the guard band, not keep its ingress Y")
	_expect(bool(flight_hidden_dash.get("ring_dash_visual_hidden", false)), "Linkport should keep the flight companion hidden for the vanish beat")
	_expect(int(flight_hidden_dash.get("companion_contact_count", 0)) == 0, "Linkport should not let an invisible flight companion hit the ball before it reappears")
	runtime3.update(0.05, owner3, registry)
	var flight_visible_dash: Dictionary = runtime3.get_snapshot()
	_expect(int(flight_visible_dash.get("companion_contact_count", 0)) == 1, "Linkport should hit after the flight companion has reappeared")
	_expect(float(owner3.ball_vel.y) < 0.0, "Linkport hit should bounce the descending ball upward after reappearing")
	_expect_float(runtime3.get_affinity_points("lunabi"), 21.0, "Linkport flight guard hit should double only the base (8*2) and keep the flat +5 guard bonus = 21")
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


func _verify_ring_dash_defers_to_committed_player_dash() -> void:
	# 이중수비 씰: 플레이어가 이미 공 쪽으로 대쉬를 커밋했으면 링크포트가 같은 공에
	# 동시 발동해선 안 된다. `_player_can_block`은 패들의 현재 정지 스팬만 보므로
	# 대쉬 비행 중엔 "못 막음"으로 오판한다 — 접촉 시점 위치를 투영해야 한다.
	# 반대로 커버가 불가능한 대쉬(반대 방향 / 접촉까지 못 닿는 짧은 잔여 타이머)는
	# 보류하면 안 된다. "대쉬 중이면 무조건 보류"는 링크포트를 죽인다.
	# 지오메트리: 패들 400..570(+공반지름 14.3 -> 385.7..584.3), 접촉 X 620 = 정지
	# 스팬 밖(대조군이 실제로 발동함으로 증명). 공 하강 4px/frame -> 접촉까지 ~10프레임,
	# 풀 대쉬(15f) 잔여 이동 ~194px -> 투영 스팬이 620을 덮는다.
	var contact_x := 620.0

	# --- 레그 1(대조군): 대쉬 없음 -> 정상 발동 (이 지오메트리가 진짜 비상 상황임을 증명)
	var idle_dash := FakePlayerDashState.new()
	var idle_registry := FakeRegistry.new({"smasher_dash_state": idle_dash})
	var owner_idle := FakeOwner.new()
	owner_idle.lingpet_ring_dash_force_roll_pct = 0.0
	var runtime_idle: Object = LingpetEggRuntime.new()
	_expect(runtime_idle.debug_grant_and_activate_pet("maribo", owner_idle, false, "maribo_hydro_sphere", "lingpet_ring_dash", idle_registry, 1, 5), "dash-defer control leg should equip Linkport Lv.5")
	_arm_ring_dash_dash_defer_scenario(runtime_idle, owner_idle, contact_x)
	runtime_idle.update(0.05, owner_idle, idle_registry)
	_expect(bool(runtime_idle.is_ring_dash_active_for_tests()), "control leg: Linkport must fire when the standing paddle span cannot reach the contact X (otherwise the defer legs prove nothing)")
	_expect(int(runtime_idle.get_ring_dash_trigger_count_for_tests()) == 1, "control leg: the unblockable descent should spend exactly one Linkport trigger")

	# --- 레그 2: 공 쪽으로 커밋된 대쉬 -> 보류(굴림 락도 소모하지 않는다)
	var committed_dash := FakePlayerDashState.new()
	committed_dash.dash_active = true
	committed_dash.dash_direction = 1.0
	committed_dash.dash_timer = 15.0
	var committed_registry := FakeRegistry.new({"smasher_dash_state": committed_dash})
	var owner_dash := FakeOwner.new()
	owner_dash.lingpet_ring_dash_force_roll_pct = 0.0
	var runtime_dash: Object = LingpetEggRuntime.new()
	_expect(runtime_dash.debug_grant_and_activate_pet("maribo", owner_dash, false, "maribo_hydro_sphere", "lingpet_ring_dash", committed_registry, 1, 5), "dash-defer leg should equip Linkport Lv.5")
	_arm_ring_dash_dash_defer_scenario(runtime_dash, owner_dash, contact_x)
	runtime_dash.update(0.05, owner_dash, committed_registry)
	_expect(not bool(runtime_dash.is_ring_dash_active_for_tests()), "Linkport must NOT double-guard a ball the player already dashed to cover")
	_expect(int(runtime_dash.get_ring_dash_trigger_count_for_tests()) == 0, "a deferred Linkport must not spend a trigger")
	_expect(not bool(runtime_dash.get_snapshot().get("ring_dash_rolled_this_descent", true)), "a deferred Linkport must not burn the per-descent roll lock — the dash may still whiff")

	# --- 레그 3: 반대 방향 대쉬 -> 커버 불가이므로 보류하지 않는다
	var away_dash := FakePlayerDashState.new()
	away_dash.dash_active = true
	away_dash.dash_direction = -1.0
	away_dash.dash_timer = 15.0
	var away_registry := FakeRegistry.new({"smasher_dash_state": away_dash})
	var owner_away := FakeOwner.new()
	owner_away.lingpet_ring_dash_force_roll_pct = 0.0
	var runtime_away: Object = LingpetEggRuntime.new()
	_expect(runtime_away.debug_grant_and_activate_pet("maribo", owner_away, false, "maribo_hydro_sphere", "lingpet_ring_dash", away_registry, 1, 5), "opposite-direction dash leg should equip Linkport Lv.5")
	_arm_ring_dash_dash_defer_scenario(runtime_away, owner_away, contact_x)
	runtime_away.update(0.05, owner_away, away_registry)
	_expect(bool(runtime_away.is_ring_dash_active_for_tests()), "a dash AWAY from the ball cannot cover it — Linkport must still fire")

	# --- 레그 4: 잔여 타이머가 접촉까지 닿지 못하는 대쉬 -> 보류하지 않는다
	var short_dash := FakePlayerDashState.new()
	short_dash.dash_active = true
	short_dash.dash_direction = 1.0
	short_dash.dash_timer = 2.0
	var short_registry := FakeRegistry.new({"smasher_dash_state": short_dash})
	var owner_short := FakeOwner.new()
	owner_short.lingpet_ring_dash_force_roll_pct = 0.0
	var runtime_short: Object = LingpetEggRuntime.new()
	_expect(runtime_short.debug_grant_and_activate_pet("maribo", owner_short, false, "maribo_hydro_sphere", "lingpet_ring_dash", short_registry, 1, 5), "short-timer dash leg should equip Linkport Lv.5")
	_arm_ring_dash_dash_defer_scenario(runtime_short, owner_short, contact_x)
	runtime_short.update(0.05, owner_short, short_registry)
	_expect(bool(runtime_short.is_ring_dash_active_for_tests()), "a dash whose remaining travel cannot reach the contact X must NOT suppress Linkport")


func _arm_ring_dash_dash_defer_scenario(runtime: Object, owner: Object, contact_x: float) -> void:
	var start_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(Vector2(120.0, start_pos.y), 2, 0.0, false)
	owner.player_pos = Vector2(400.0, owner.player_pos.y)
	owner.player_paddle_width = 170.0
	owner.ball_active = true
	owner.ball_pos = Vector2(contact_x, owner.player_pos.y - 40.0)
	# 느린 하강(4px/frame)으로 접촉까지 ~10프레임을 확보한다 — 대쉬가 실제로
	# 접촉 지점까지 이동할 시간이 있는 상황이어야 투영 판정이 의미를 가진다.
	owner.ball_vel = Vector2(0.0, 4.0)


func _verify_ring_dash_ground_pet_keeps_y_on_teleport() -> void:
	# 지상형(patrol) 수호령은 공중으로 이동할 수 없으므로, 링크포트(Linkport) 순간이동은 X만
	# 바꾸고 Y(지상 레인)는 유지해야 한다. 가드 센터 Y로 내려보내면 패들 높이만큼 위로
	# 튀어오르는데, 50px 기본 패들에선 미미하지만 패들 높이 증가 퍽/아이템이 켜지면 눈에
	# 보일 만큼 커진다. 여기서는 패들 높이 75로 그 분기(rest Y ~712.5 vs 옛 guard Y ~697)를
	# 키운 뒤 Y 유지 + X 이동을 단언한다. 반증검증: 옛 가드-다이브 코드는 Y를 ~697로 만들어
	# 마지막 두 단언에서 실패한다.
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_ring_dash_force_roll_pct = 0.0  # guaranteed roll success
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_ring_dash", registry, 1, 5), "ground-pet Y-lock smoke should equip Ring Dash Lv.5 on a patrol pet")
	owner.player_pos = Vector2(240.0, 675.0)  # tall paddle baseline (height 75)
	owner.player_paddle_width = 170.0
	owner.player_paddle_height = 75.0
	# Settle the patrol pet onto its low ground lane with no ball present.
	owner.ball_active = false
	for i in range(6):
		runtime.update(0.05, owner, registry)
	var rest_y: float = owner.lingpet_companion_pos.y
	_expect(rest_y > 705.0, "patrol pet should rest on its low ground lane (paddle 75 -> ~712.5)")
	# Pin the pet far from the predicted ball X so the min-distance emergency gate passes.
	runtime.configure_companion_motion_for_tests(Vector2(120.0, rest_y), 2, 0.0, false)
	# Descending, unblockable ball in the lower emergency band.
	owner.ball_active = true
	owner.ball_pos = Vector2(640.0, owner.player_pos.y - 40.0)
	owner.ball_pos_prev = owner.ball_pos
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.05, owner, registry)
	_expect(bool(runtime.is_ring_dash_active_for_tests()), "Linkport should fire for the far, unblockable descending ball")
	_expect(is_equal_approx(owner.lingpet_companion_pos.x, 640.0), "Linkport should teleport the ground pet's X to the predicted ball X")
	_expect(absf(owner.lingpet_companion_pos.y - rest_y) < 1.0, "Linkport must KEEP the ground pet's ground-lane Y (only X teleports, no upward pop)")
	# Reverse guard: the old guard-center dive would land Y at ~697 (15px up). Prove the pet
	# is NOT popped up, so any regression that re-introduces the dive fails here.
	_expect(owner.lingpet_companion_pos.y > 705.0, "Linkport ground pet must not pop up toward the guard-center Y")


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
	_expect_float(puddle_hw, 94.08, "Hydro Sphere Lv.1 puddle should shrink X half-width by 30%")
	_expect_float(puddle_hh, 33.6, "Hydro Sphere level scaling should not change the puddle Y half-height")
	var slow_calls: Array[Dictionary] = status_state.get_calls_for_source("maribo_hydro_sphere_puddle")
	_expect(not slow_calls.is_empty(), "Hydro Sphere puddle should apply boss slow while the boss touches it")
	if not slow_calls.is_empty():
		var first_slow: Dictionary = slow_calls[0]
		_expect(str(first_slow.get("target", "")) == "boss", "Hydro Sphere puddle slow should target the boss")
		_expect(str(first_slow.get("status_id", "")) == "slow", "Hydro Sphere puddle should apply the slow status")
		_expect(is_equal_approx(float(first_slow.get("duration_frames", 0.0)), 4.0), "Hydro Sphere puddle should refresh a short slow while touched")
		_expect_float(float((first_slow.get("data", {}) as Dictionary).get("multiplier", 0.0)), 0.80, "Hydro Sphere Lv.1 puddle should apply the weak slow multiplier")

	owner.player_pos = Vector2(40.0, owner.player_pos.y)
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


func _verify_hydro_sphere_scales_with_level() -> void:
	var lv1_result: Dictionary = _run_hydro_sphere_host_launch_for_level(1)
	var lv5_result: Dictionary = _run_hydro_sphere_host_launch_for_level(5)
	var lv1_snapshot: Dictionary = lv1_result.get("snapshot", {}) as Dictionary
	var lv5_snapshot: Dictionary = lv5_result.get("snapshot", {}) as Dictionary
	_expect_eq(int(lv1_snapshot.get("hydro_sphere_active_skill_level", 0)), 1, "Hydro Sphere should capture Lv.1 from launch context")
	_expect_eq(int(lv5_snapshot.get("hydro_sphere_active_skill_level", 0)), 5, "Hydro Sphere should capture Lv.5 from launch context")
	_expect_float(float(lv1_snapshot.get("hydro_sphere_puddle_half_width", 0.0)), 94.08, "Hydro Sphere Lv.1 should use the -30% X half-width")
	_expect_float(float(lv5_snapshot.get("hydro_sphere_puddle_half_width", 0.0)), 174.72, "Hydro Sphere Lv.5 should use the +30% X half-width")
	_expect_float(float(lv1_snapshot.get("hydro_sphere_puddle_half_height", 0.0)), 33.6, "Hydro Sphere Lv.1 should keep the base Y half-height")
	_expect_float(float(lv5_snapshot.get("hydro_sphere_puddle_half_height", 0.0)), 33.6, "Hydro Sphere Lv.5 should keep the base Y half-height")
	var lv1_slow: float = _get_first_hydro_slow_multiplier(lv1_result.get("slow_calls", []) as Array)
	var lv5_slow: float = _get_first_hydro_slow_multiplier(lv5_result.get("slow_calls", []) as Array)
	_expect_float(lv1_slow, 0.80, "Hydro Sphere Lv.1 should apply weak boss slow")
	_expect_float(lv5_slow, 0.45, "Hydro Sphere Lv.5 should apply strong boss slow")
	_expect(lv5_slow < lv1_slow, "Hydro Sphere slow multiplier should get lower, therefore stronger, from Lv.1 to Lv.5")


func _run_hydro_sphere_host_launch_for_level(active_skill_level: int) -> Dictionary:
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(330.0, 25.0)
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({
		"status_effect_state": status_state,
	})
	var runtime_host: Object = LingpetSkillRuntimeHost.new()
	var launch_context := {"active_skill_level": active_skill_level}
	_expect(
		bool(runtime_host.launch("maribo_hydro_sphere", Vector2(380.0, 90.0), owner, launch_context)),
		"Hydro Sphere host should launch with active skill Lv.%d context" % active_skill_level
	)
	runtime_host.update(0.4, owner, registry, "maribo_hydro_sphere")
	var snapshot: Dictionary = runtime_host.get_snapshot()
	_expect(bool(snapshot.get("hydro_sphere_puddle_active", false)), "Hydro Sphere Lv.%d host smoke should spawn a puddle" % active_skill_level)
	var slow_calls: Array[Dictionary] = status_state.get_calls_for_source("maribo_hydro_sphere_puddle")
	_expect(not slow_calls.is_empty(), "Hydro Sphere Lv.%d host smoke should apply boss slow" % active_skill_level)
	return {
		"snapshot": snapshot,
		"slow_calls": slow_calls,
	}


func _get_first_hydro_slow_multiplier(slow_calls: Array) -> float:
	if slow_calls.is_empty():
		return 0.0
	var first_slow: Dictionary = slow_calls[0] as Dictionary
	var data: Dictionary = first_slow.get("data", {}) as Dictionary
	return float(data.get("multiplier", 0.0))


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
	var lunabi_shared_cooldown: float = float(owner.lingpet_skill_cooldown)
	_expect(lunabi_shared_cooldown > LingpetEggRuntime.COMPANION_SKILL_SHARED_COOLDOWN_SECONDS - 0.1, "freshly switched Lunabi should inherit the shared lingpet skill cooldown")
	_expect(not bool(owner.lingpet_skill_ready), "freshly switched Lunabi must not be ready for a burst cast during shared cooldown")
	_expect(float(runtime.get_snapshot().get("companion_skill_shared_cooldown", 0.0)) > LingpetEggRuntime.COMPANION_SKILL_SHARED_COOLDOWN_SECONDS - 0.1, "runtime snapshot should expose the shared lingpet skill cooldown for HUD/debug consumers")
	owner.ball_active = false
	runtime.update(10.0, owner, registry)
	_expect(is_equal_approx(float(owner.lingpet_skill_cooldown), 0.0), "freshly switched Lunabi shared cooldown should tick down normally")
	_expect(bool(runtime.switch_lingpet_slot(0, owner)), "switching back to Maribo should succeed")
	_expect(str(owner.active_lingpet_id) == "maribo", "slot switch should reactivate Maribo")
	var restored_cooldown: float = float(owner.lingpet_skill_cooldown)
	_expect(restored_cooldown > 28.0 and restored_cooldown < maribo_cooldown - 9.5, "inactive Maribo cooldown should keep ticking while another lingpet is active")


func _verify_lingpet_slot_switch_clears_owner_locked_skill_flags() -> void:
	var puppet_owner := FakeOwner.new()
	puppet_owner.lingpet_owned_pet_ids = ["koyora", "maribo"]
	puppet_owner.owned_lingpet_ids = puppet_owner.lingpet_owned_pet_ids.duplicate()
	puppet_owner.owned_ringpet_ids = puppet_owner.lingpet_owned_pet_ids.duplicate()
	puppet_owner.lingpet_slots = ["koyora", "maribo", ""]
	puppet_owner.ringpet_slots = puppet_owner.lingpet_slots.duplicate()
	puppet_owner.lingpet_slot_pet_ids = puppet_owner.lingpet_slots.duplicate()
	puppet_owner.ringpet_slot_pet_ids = puppet_owner.lingpet_slots.duplicate()
	puppet_owner.lingpet_active_slot_index = 0
	puppet_owner.ringpet_active_slot_index = 0
	puppet_owner.ball_active = true
	var puppet_runtime: Object = LingpetEggRuntime.new()
	var puppet_registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new()})
	_expect(
		puppet_runtime.debug_grant_and_activate_pet("koyora", puppet_owner, false, "koyora_puppet_control", "", puppet_registry, 1, 1),
		"slot-switch puppet fixture should activate Koyora"
	)
	_expect(
		bool(puppet_runtime._skill_runtime_host.launch("koyora_puppet_control", Vector2(380.0, 600.0), puppet_owner, {"active_skill_level": 1})),
		"slot-switch puppet fixture should launch Puppet Control"
	)
	puppet_runtime._skill_runtime_host.update(0.9, puppet_owner, puppet_registry, "koyora_puppet_control", {})
	_expect(bool(puppet_owner.lingpet_puppet_grab_active), "slot-switch puppet setup should hold the boss before switching")
	_expect(puppet_owner.boss_pos.y > 25.0, "slot-switch puppet setup should drag the boss before switching")
	_expect(bool(puppet_runtime.switch_lingpet_slot(1, puppet_owner, puppet_registry)), "switching away from active Puppet Control should succeed")
	_expect(not bool(puppet_owner.lingpet_puppet_grab_active), "switching away from Puppet Control must clear the boss-freeze flag immediately")
	_expect(_vector2_distance(puppet_owner.boss_pos, Vector2(330.0, 25.0)) <= 0.01, "switching away from Puppet Control must restore boss_pos immediately")

	var star_owner := FakeOwner.new()
	star_owner.lingpet_owned_pet_ids = ["orosha", "maribo"]
	star_owner.owned_lingpet_ids = star_owner.lingpet_owned_pet_ids.duplicate()
	star_owner.owned_ringpet_ids = star_owner.lingpet_owned_pet_ids.duplicate()
	star_owner.lingpet_slots = ["orosha", "maribo", ""]
	star_owner.ringpet_slots = star_owner.lingpet_slots.duplicate()
	star_owner.lingpet_slot_pet_ids = star_owner.lingpet_slots.duplicate()
	star_owner.ringpet_slot_pet_ids = star_owner.lingpet_slots.duplicate()
	star_owner.lingpet_active_slot_index = 0
	star_owner.ringpet_active_slot_index = 0
	star_owner.ball_active = true
	var star_runtime: Object = LingpetEggRuntime.new()
	var star_registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new()})
	_expect(
		star_runtime.debug_grant_and_activate_pet("orosha", star_owner, false, "orosha_star_coil", "", star_registry, 5, 1),
		"slot-switch Star Coil fixture should activate Orosha"
	)
	var star_context := {
		"companion_pos": Vector2(380.0, 650.0),
		"companion_visible": true,
		"active_skill_id": "orosha_star_coil",
		"active_skill_level": 5,
		"slow_duration": 3.5,
		"slow_multiplier": 0.4,
		"ball_active": true,
		"boss_pos": star_owner.boss_pos,
		"boss_paddle_width": star_owner.boss_paddle_width,
		"boss_hitbox_height": star_owner.boss_hitbox_height,
	}
	_expect(
		bool(star_runtime._skill_runtime_host.launch("orosha_star_coil", Vector2(380.0, 650.0), star_owner, star_context)),
		"slot-switch Star Coil fixture should launch Star Coil"
	)
	for _i in range(240):
		star_runtime._skill_runtime_host.update(1.0 / 60.0, star_owner, star_registry, "orosha_star_coil", star_context)
		if bool(star_owner.lingpet_star_coil_boss_slow_active):
			break
	_expect(bool(star_owner.lingpet_star_coil_boss_slow_active), "slot-switch Star Coil setup should slow the boss before switching")
	_expect(bool(star_owner.lingpet_star_coil_block_boss_dash), "slot-switch Star Coil setup should block boss dash at Lv.5")
	_expect(bool(star_owner.lingpet_star_coil_freeze_boss_skill_cd), "slot-switch Star Coil setup should freeze boss skill cooldown at Lv.5")
	_expect(bool(star_runtime.switch_lingpet_slot(1, star_owner, star_registry)), "switching away from active Star Coil should succeed")
	_expect(not bool(star_owner.lingpet_star_coil_boss_slow_active), "switching away from Star Coil must clear boss slow immediately")
	_expect(is_equal_approx(float(star_owner.lingpet_star_coil_boss_slow_multiplier), 1.0), "switching away from Star Coil must restore slow multiplier")
	_expect(not bool(star_owner.lingpet_star_coil_block_boss_dash), "switching away from Star Coil must clear boss dash block")
	_expect(not bool(star_owner.lingpet_star_coil_freeze_boss_skill_cd), "switching away from Star Coil must clear boss skill cooldown freeze")


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

	# Source wiring: gameplay state stays in the skill while the focused renderer owns
	# texture-cache preparation plus the caustic/particle CanvasItem recipe.
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var skill_runtime_host_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	var hydro_skill_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")
	var hydro_renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hydro_sphere_renderer.gd")
	_expect(runtime_source.find("lingpet_skill_runtime_host.gd") >= 0, "egg runtime should delegate concrete skill effects to the runtime host")
	_expect(skill_runtime_host_source.find("lingpet_hydro_sphere_skill.gd") >= 0, "skill runtime host should delegate Hydro Sphere projectile/puddle behavior to the skill module")
	_expect(hydro_skill_source.find("LingpetHydroSphereRenderer") >= 0, "Hydro Sphere gameplay owner should delegate presentation to the focused renderer")
	_expect(hydro_renderer_source.find("HydroPuddleTextureCache") >= 0, "Hydro Sphere renderer should draw through the procedural texture cache")
	_expect(hydro_renderer_source.find("_draw_particles") >= 0, "Hydro Sphere renderer should draw borrowed pooled water particles")
	_expect(hydro_renderer_source.find("_blit_hydro_caustic") >= 0, "Hydro Sphere renderer should blit scroll-animated caustic layers")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd"), "Hydro Sphere skill module should exist")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_hydro_sphere_renderer.gd"), "Hydro Sphere renderer module should exist")
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
	_expect(int(snapshot.get("version", 0)) == 2, "lingpet save snapshot should carry the shared-duration schema version")
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
	var companion_path := _smoke_save_path("save_store_companion")
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

	var egg_path := _smoke_save_path("save_store_egg")
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
	var save_path := _smoke_save_path("lifecycle_restore")
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
	_expect(lingpet_stats.size() == 6, "character-info lingpet stats should show implemented Maribo companion rows plus the affinity row")
	_expect(_stat_values_have_exact(lingpet_stats, "2.00"), "character-info lingpet stats should show Maribo speed as a slower single player-style value")
	_expect(_stat_values_have_fragment(lingpet_stats, "100x44"), "character-info lingpet stats should show the body-size footprint")
	_expect(_stat_values_have_exact(lingpet_stats, "40pt"), "character-info lingpet stats should show the direct hit gauge gain as a common stat")
	_expect(_stat_values_have_exact(lingpet_stats, CharacterInfoOverlayFormatter.format_seconds_text(40.0)), "character-info lingpet stats should show Hydro Sphere cooldown")
	_expect(_stat_values_have_exact(lingpet_stats, "30%"), "character-info lingpet stats should show the real defense rate")
	_expect(_stat_values_have_exact(lingpet_stats, "Lv.0"), "character-info lingpet stats should show the text-only affinity level row")

	var overlay_gain: float = CharacterInfoOverlayStatsPresenter.effective_gauge_gain_per_hit(null, null, runtime)
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
	_expect_float(LingpetCompanionMotionState.get_defense_local_zone(0.0), 150.0, "defense local zone should start at 150px at 0 percent")
	_expect_float(LingpetCompanionMotionState.get_defense_local_zone(0.30), 210.0, "Maribo 30 percent defense should use a 210px local zone")
	_expect_float(LingpetCompanionMotionState.get_defense_local_zone(1.0), 350.0, "defense local zone should reach 350px at 100 percent")
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
	_expect_float(runtime.get_affinity_points("maribo"), 13.0, "defense intercept should grant direct-hit affinity plus one defense bonus captured before resolve")
	_expect(not bool(owner.lingpet_companion_defense_intercept_active), "defense guard aura should clear immediately after the guarded hit")
	_expect_float(float(runtime.get_player_speed_multiplier()), 1.0, "defense guard should leave the player movement speed at the passive-only baseline after the guarded hit")
	_expect((runtime.get_snapshot().get("affinity_guard_label", {}) as Dictionary).get("text", "") == "방어", "defense intercept should spawn the guard label at the hit moment")


func _verify_player_takes_ball_priority_when_companion_overlaps() -> void:
	# When the companion stands over the player paddle and a descending ball is within
	# the PLAYER's reach, the player must take the hit -- the companion must NOT bounce it.
	# When the player CANNOT reach the ball, the companion still guards it (control case
	# below; mirrors _verify_maribo_defense_actually_blocks_reachable_ball at x=650).
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	# Clear the maribo Hydro Sphere auto-cast wind-up (freezes companion motion) by
	# letting the initial cast LAUNCH (parked ball away from the lane), then proceed.
	owner.ball_active = true
	owner.ball_pos = Vector2(60.0, 120.0)
	owner.ball_vel = Vector2(0.0, 0.0)
	for _w in range(10):
		runtime.update(0.2, owner, registry)
	_expect(not bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "initial Hydro Sphere wind-up should be finished before the priority scenario")
	var lane_y: float = owner.lingpet_companion_pos.y

	# --- Case 1: companion overlaps the player; ball within the player's reach -> the
	#     companion must NOT bounce it (player priority) -------------------------------
	owner.player_paddle_width = 170.0
	owner.player_pos = Vector2(300.0, owner.player_pos.y)  # paddle x[300,470], reach ~[285,485]
	runtime.configure_companion_motion_for_tests(Vector2(385.0, lane_y), 2, 0.0, false)  # over the paddle
	owner.ball_active = true
	owner.ball_pos = Vector2(385.0, lane_y)  # inside the companion catch box AND within player reach
	owner.ball_vel = Vector2(0.0, 12.0)
	var prev_contacts: int = int(owner.lingpet_companion_contact_count)
	runtime.update(0.05, owner, registry)
	_expect(int(owner.lingpet_companion_contact_count) == prev_contacts, "companion must NOT steal a ball the player can reach while overlapping the player")
	_expect(float(owner.ball_vel.y) > 0.0, "the ball should keep descending toward the player (companion did not bounce it)")

	# --- Case 2 (control): same companion, player paddle moved away -> companion guards
	owner.player_pos = Vector2(40.0, owner.player_pos.y)  # paddle x[40,210], reach ~[25,224]
	runtime.configure_companion_motion_for_tests(Vector2(385.0, lane_y), 2, 0.0, false)
	owner.ball_active = true
	owner.ball_pos = Vector2(385.0, lane_y)  # in the companion catch box, OUTSIDE the player's reach
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.05, owner, registry)
	_expect(int(owner.lingpet_companion_contact_count) >= prev_contacts + 1, "companion must still guard a ball the player CANNOT reach (defense feature intact)")
	_expect(float(owner.ball_vel.y) < 0.0, "a guarded (player-unreachable) ball should still be bounced upward")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("func _player_can_block_companion_ball") < 0, "runtime should not keep a single-use player-block predicate wrapper")
	_expect(runtime_source.find("_companion_player_block_resolver.can_player_block") >= 0, "runtime should call the player-block resolver directly for companion hit priority")


func _verify_lingpet_body_draws_behind_player() -> void:
	# Draw order: the default lingpet BODY (egg sprite AND patrol companion sprite) must render
	# behind the player through draw_lingpet_body_behind_actors(). The only front-pass exception
	# is the explicit bind-sheet gate, where the companion body has to wrap over a target.
	# Reverse-check: a raw _draw_companion( leak into draw() would cover the player again.
	var runtime_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var body_presence_resolver_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
	var draw_fn_start: int = runtime_src.find("\nfunc draw(canvas: CanvasItem")
	_expect(draw_fn_start >= 0, "egg runtime should define draw(canvas: CanvasItem, ...)")
	var draw_fn_end: int = runtime_src.find("\nfunc ", draw_fn_start + 1)
	var draw_fn_body: String = runtime_src.substr(draw_fn_start, draw_fn_end - draw_fn_start)
	var front_gate_idx: int = draw_fn_body.find("if _companion_body_presence_resolver.is_front_pass_body_active(")
	var front_companion_idx: int = draw_fn_body.find("_draw_companion(")
	_expect(front_companion_idx < 0 or (front_gate_idx >= 0 and front_gate_idx < front_companion_idx), "main draw() may draw the companion body only behind the explicit bind-sheet front-pass gate")
	_expect(draw_fn_body.find("_egg_renderer.draw_egg(") < 0, "main draw() must NOT draw the egg body (it renders behind the player instead)")
	_expect(runtime_src.find("func _is_companion_body_drawn_in_front()") < 0, "egg runtime should not keep a private front-pass companion body predicate")
	_expect(body_presence_resolver_src.find("func is_front_pass_body_active") >= 0, "front-pass companion draw should stay guarded by a named body-presence resolver predicate")
	var behind_fn_start: int = runtime_src.find("func draw_lingpet_body_behind_actors(")
	_expect(behind_fn_start >= 0, "egg runtime should expose draw_lingpet_body_behind_actors() for the behind-player body pass")
	var behind_fn_end: int = runtime_src.find("\nfunc ", behind_fn_start + 1)
	var behind_fn_body: String = runtime_src.substr(behind_fn_start, behind_fn_end - behind_fn_start)
	_expect(behind_fn_body.find("_draw_companion(") >= 0, "draw_lingpet_body_behind_actors() should draw the companion body")
	_expect(behind_fn_body.find("_egg_renderer.draw_egg(") >= 0, "draw_lingpet_body_behind_actors() should draw the egg body")
	# The shared player actor renderer must invoke the hook BEFORE the player sprite.
	var player_src: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
	var hook_idx: int = player_src.find("lingpet_body_draw")
	var first_sprite_draw_idx: int = player_src.find("sprite_renderer.draw(")
	_expect(hook_idx >= 0, "shared player actor renderer should invoke the lingpet body hook")
	_expect(first_sprite_draw_idx < 0 or hook_idx < first_sprite_draw_idx, "lingpet body hook must run before the player sprite is drawn")
	# The scene drawer must inject the hook into the actor context.
	var scene_src: String = FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	_expect(scene_src.find("\"lingpet_body_draw\"") >= 0, "scene drawer should inject the lingpet body draw hook into the actor context")


func _verify_lingpet_defense_guard_chase_feedback() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var defense_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_defense_state.gd")
	var renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	var draw_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	_expect(runtime_source.find("COMPANION_DEFENSE_GUARD_PLAYER_SPEED_BONUS_PCT") < 0, "defense guard should not smuggle an undocumented player speed bonus into the runtime")
	_expect(defense_source.find("COMPANION_DEFENSE_GUARD_SPEED_RATE_GAIN") >= 0, "defense guard chase speed should scale with defense_rate through a single rate-gain lever, not a fixed multiplier")
	_expect(defense_source.find("COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS") >= 0, "every defending lingpet must get the universal +60% guard-speed floor (not a maribo-only value)")
	_expect(renderer_source.find("defense_guard_aura_ratio") >= 0 and renderer_source.find("_resolve_aura_color") >= 0, "companion renderer should tint the soft aura through a guard ratio")
	_expect(draw_context_source.find("\"defense_guard_active\"") >= 0 and draw_context_source.find("\"defense_guard_aura_ratio\"") >= 0, "draw context should expose guard chase aura fields")
	var guard_speed: float = LingpetCompanionMotionState.get_defense_guard_speed(120.0, 0.30)
	_expect_float(guard_speed, 192.0, "Maribo (0.30 rate) sits exactly on the +60% floor: pet_speed * 1.60 = 192")
	# Universal +60% FLOOR: every defending lingpet -- not just maribo -- gets at least
	# +60%, regardless of its (possibly lower) defense_rate, and for ANY base move speed.
	_expect_float(LingpetCompanionMotionState.get_defense_guard_speed(120.0, 0.10), 192.0, "a LOW 0.10-rate defending pet still gets the +60% floor (192), not +10% (132)")
	_expect_float(LingpetCompanionMotionState.get_defense_guard_speed(175.0, 0.16), 280.0, "the +60% floor applies to ANY pet's own move speed (175px/s pet -> 280, under the 320 cap), so the buff is universal not maribo-specific")
	var guard_speed_max: float = LingpetCompanionMotionState.get_defense_guard_speed(120.0, 1.0)
	_expect_float(guard_speed_max, 240.0, "above the floor, a higher defense rate scales the chase speed up (rate 1.0 -> pet_speed * 2.0 = 240) so the widened zone stays reachable")
	_expect(guard_speed_max > guard_speed, "a defense rate above the 0.60 floor must raise the guard CHASE SPEED beyond it, not only the commit zone")

	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	_prepare_maribo_guard_after_windup(runtime, owner, registry)
	var lane_y: float = owner.lingpet_companion_pos.y
	runtime.configure_companion_motion_for_tests(Vector2(570.0, lane_y), 2, 0.0, false)
	var step_delta := 0.05
	var ball_vy := 12.0
	var step_drop := ball_vy * step_delta * 60.0
	var ball_y: float = lane_y - 300.0
	owner.ball_active = true
	owner.ball_pos = Vector2(650.0, ball_y)
	owner.ball_vel = Vector2(0.0, ball_vy)
	runtime.update(step_delta, owner, registry)
	var first_snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(first_snapshot.get("companion_defense_intercept_active", false)), "guard chase fixture should arm the defense intercept")
	_expect_float(float(runtime.get_player_speed_multiplier()), 1.0, "active defense guard should leave player movement speed to equipped passive bonuses")
	var first_aura := float(first_snapshot.get("companion_defense_guard_aura_ratio", 0.0))
	_expect(first_aura > 0.0 and first_aura < 1.0, "guard aura should ramp in instead of popping instantly")
	ball_y += step_drop
	for _i in range(2):
		owner.ball_pos = Vector2(650.0, ball_y)
		owner.ball_vel = Vector2(0.0, ball_vy)
		runtime.update(step_delta, owner, registry)
		ball_y += step_drop
	var fast_snapshot: Dictionary = runtime.get_snapshot()
	_expect(float(fast_snapshot.get("companion_patrol_speed", 0.0)) <= guard_speed + 0.001, "guard chase must not exceed the lingpet movement baseline plus 60 percent")
	_expect(float(fast_snapshot.get("companion_patrol_speed", 0.0)) >= guard_speed - 0.001, "guard chase should ramp up to the lingpet movement baseline plus 60 percent")
	_expect_float(float(fast_snapshot.get("companion_defense_guard_aura_ratio", 0.0)), 1.0, "guard aura should reach full red after the short ramp")

	var builder_config: Dictionary = LingpetCompanionDrawContextBuilder.new().build_config({
		"defense_guard_active": true,
		"defense_guard_aura_ratio": 0.5,
	})
	_expect(bool(builder_config.get("defense_guard_active", false)), "draw config should keep the guard-active flag true while chasing")
	_expect_float(float(builder_config.get("defense_guard_aura_ratio", 0.0)), 0.5, "draw config should preserve the guard aura ramp ratio")


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
	# 180px aside: inside Maribo's 30 percent local commit zone (210) but well beyond
	# a single-frame reach, and beyond the player paddle (x[249,511]) so the player
	# cannot block it.
	owner.ball_pos = Vector2(600.0, start_pos.y - 300.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.05, owner)
	_expect(bool(owner.lingpet_companion_defense_intercept_active), "defense should anticipatorily arm for a moderate-distance ball inside the local zone (not wait until it is one-frame reachable)")
	_expect(owner.lingpet_companion_pos.x > 420.0, "an anticipatory guard should start easing toward the predicted X early")
	_expect(float(owner.lingpet_companion_defense_intercept_target_x) > 560.0, "the anticipatory anchor should be the predicted landing X (~600), not the lingpet's current spot")

	# 330px aside: outside Maribo's base 210px zone, but inside the 100 percent 350px
	# zone. Defense rate should therefore widen the commit distance, not only the roll.
	var base_owner := FakeOwner.new()
	base_owner.lingpet_owned_pet_ids = ["maribo"]
	var base_runtime: Object = LingpetEggRuntime.new()
	base_runtime.update(0.0, base_owner)
	var base_start: Vector2 = base_owner.lingpet_companion_pos
	base_runtime.configure_companion_motion_for_tests(Vector2(220.0, base_start.y), 2, 0.0, false)
	base_owner.ball_active = true
	base_owner.ball_pos = Vector2(550.0, base_start.y - 300.0)
	base_owner.ball_vel = Vector2(0.0, 12.0)
	base_runtime.update(0.05, base_owner)
	_expect(not bool(base_owner.lingpet_companion_defense_intercept_active), "base 30 percent defense should ignore a 330px predicted gap outside its scaled zone")

	var max_owner := FakeOwner.new()
	max_owner.lingpet_owned_pet_ids = ["maribo"]
	var max_runtime: Object = LingpetEggRuntime.new()
	max_runtime.set_debug_defense_rate_override(1.0)
	max_runtime.update(0.0, max_owner)
	var max_start: Vector2 = max_owner.lingpet_companion_pos
	max_runtime.configure_companion_motion_for_tests(Vector2(220.0, max_start.y), 2, 0.0, false)
	max_owner.ball_active = true
	max_owner.ball_pos = Vector2(550.0, max_start.y - 300.0)
	max_owner.ball_vel = Vector2(0.0, 12.0)
	max_runtime.update(0.05, max_owner)
	_expect(bool(max_owner.lingpet_companion_defense_intercept_active), "100 percent defense should cover a 330px predicted gap inside its widened 350px zone")

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


func _verify_maribo_high_defense_reaches_widened_zone() -> void:
	# OUTCOME seal (saga rule: assert the BOUNCE, not the armed flag). A HIGH defense
	# rate widens the local commit zone to 350px, so the guard must actually REACH and
	# BOUNCE a ball well past the ~64px body catch -- ~230px aside here, far beyond the
	# trivial 80px case in _verify_maribo_defense_actually_blocks_reachable_ball. Ball
	# descends at the real fps_scale rate (ball_vel * delta * 60); a raw-ball_vel step
	# would inflate the guard window. NOTE: the SPEED-coupling regression is sealed
	# deterministically by get_defense_guard_speed's 192->240 assertions in
	# _verify_lingpet_defense_guard_chase_feedback (verified to FAIL on a rate-independent
	# speed). This case is the "widened reach yields a real bounce" half, not the
	# speed-regression seal: at this gap/descent even the floor 192px/s (no rate coupling) would also catch,
	# so do not read a pass here as proof the coupling is active.
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.set_debug_defense_rate_override(1.0)
	runtime.update(0.0, owner, registry)
	_prepare_maribo_guard_after_windup(runtime, owner, registry)
	var lane_y: float = owner.lingpet_companion_pos.y
	runtime.configure_companion_motion_for_tests(Vector2(350.0, lane_y), 2, 0.0, false)
	var step_delta := 0.05
	var ball_vy := 6.0
	var step_drop := ball_vy * step_delta * 60.0  # 18px/step (real fps_scale descent)
	# Start just inside the 320px vertical lookahead so the guard can commit, with a
	# generous descent runway to the lane (the lookahead caps reach independently of
	# speed -- a ball far above the lane cannot be armed for yet at any chase speed).
	var ball_y: float = lane_y - 345.0
	owner.ball_active = true
	owner.ball_pos = Vector2(580.0, ball_y)  # 230px aside, beyond player reach (~x[249,511])
	owner.ball_vel = Vector2(0.0, ball_vy)
	var armed := false
	var blocked := false
	for _i in range(40):
		owner.ball_pos = Vector2(580.0, ball_y)
		owner.ball_vel = Vector2(0.0, ball_vy)
		runtime.update(step_delta, owner, registry)
		if bool(owner.lingpet_companion_defense_intercept_active):
			armed = true
		if int(owner.lingpet_companion_contact_count) >= 1:
			blocked = true
			break
		ball_y += step_drop
	_expect(armed, "100 percent defense should arm for the 230px ball inside its widened 350px zone")
	_expect(blocked, "the rate-scaled chase speed must actually REACH and bounce the far widened-zone ball, not merely arm for it")
	_expect(float(owner.ball_vel.y) < 0.0, "the widened-zone guard hit should bounce the ball upward")


func _verify_maribo_defense_hold_stops_walk_animation() -> void:
	# The anticipatory guard arrives at the predicted landing X EARLY by design, then
	# waits there for the ball. While parked, the draw-side motion_speed_ratio (the
	# renderer's walk/idle gate AND walk-anim speed) must be 0 so the companion reads
	# as idle — a guard-cap-based ratio made it treadmill in place at full walk speed.
	# The chase phase toward the anchor must still keep a positive ratio.
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	_prepare_maribo_guard_after_windup(runtime, owner, registry)
	var lane_y: float = owner.lingpet_companion_pos.y
	# 15px short of the landing X: arms immediately, arrives within ~3 steps, then
	# holds for several steps while the ball is still descending.
	runtime.configure_companion_motion_for_tests(Vector2(585.0, lane_y), 2, 0.0, false)
	var step_delta := 0.05
	var ball_vy := 12.0
	var step_drop := ball_vy * step_delta * 60.0  # mirror runtime fps_scale = delta * 60
	var ball_y: float = lane_y - 300.0
	owner.ball_active = true
	owner.ball_pos = Vector2(600.0, ball_y)
	owner.ball_vel = Vector2(0.0, ball_vy)
	runtime.update(step_delta, owner, registry)
	ball_y += step_drop
	_expect(bool(owner.lingpet_companion_defense_intercept_active), "hold fixture should arm the defense intercept for the near unblockable ball")
	_expect(float(runtime.get_companion_draw_motion_speed_ratio_for_tests()) > 0.01, "the chase phase toward the anchor should keep the walk animation running")
	# Let the guard finish the short approach and snap onto the anchor.
	for _i in range(2):
		owner.ball_pos = Vector2(600.0, ball_y)
		owner.ball_vel = Vector2(0.0, ball_vy)
		runtime.update(step_delta, owner, registry)
		ball_y += step_drop
	var anchored_x: float = owner.lingpet_companion_pos.x
	_expect(absf(anchored_x - 600.0) <= 0.001, "the guard should be parked exactly on the predicted landing X after the approach")
	# Arrived-and-holding: position frozen, intercept still active, walk ratio 0.
	for _i in range(3):
		owner.ball_pos = Vector2(600.0, ball_y)
		owner.ball_vel = Vector2(0.0, ball_vy)
		runtime.update(step_delta, owner, registry)
		ball_y += step_drop
		_expect(bool(owner.lingpet_companion_defense_intercept_active), "the guard should stay armed while holding at the anchor for the descending ball")
		_expect(absf(owner.lingpet_companion_pos.x - anchored_x) <= 0.001, "the holding guard should not move off the anchor")
		_expect_float(float(runtime.get_companion_draw_motion_speed_ratio_for_tests()), 0.0, "an arrived-and-holding guard must read as idle (no in-place walk animation)")


func _verify_walk_animation_freezes_when_update_skipped() -> void:
	# Mechanism A: a pause branch in battle_frame_flow_controller skips update_lingpet, so
	# advance_walk_phase() is NOT called while the scene keeps redrawing. The walk frame must
	# FREEZE (it rides the accumulator), instead of marching in place on wall-clock time while
	# the frozen pet's position never advances.
	var animator := LingpetCompanionSpriteAnimator.new()
	for _i in range(20):
		animator.advance_walk_phase(0.05, 1.0)
	var frame_before: int = int(animator.get_walk_frame(0.0, 1000, 1.0))
	# Skip the tick (no advance_walk_phase) while wall-clock leaps forward. A wall-clock walk
	# would cycle here; the accumulator-driven walk must hold the same frame.
	var frame_skip_a: int = int(animator.get_walk_frame(0.0, 5000, 1.0))
	var frame_skip_b: int = int(animator.get_walk_frame(0.0, 9000, 1.0))
	_expect(frame_skip_a == frame_before and frame_skip_b == frame_before, "a skipped update_lingpet must freeze the companion walk frame, not march in place on wall-clock time")
	# Resuming ticks advances it again.
	for _i in range(20):
		animator.advance_walk_phase(0.05, 1.0)
	var frame_resumed: int = int(animator.get_walk_frame(0.0, 9000, 1.0))
	_expect(frame_resumed != frame_before, "the walk frame should resume advancing once update_lingpet ticks again")
	# A never-driven animator keeps the wall-clock fallback so the soul-clone path is intact.
	var fallback := LingpetCompanionSpriteAnimator.new()
	var wc_a: int = int(fallback.get_walk_frame(0.0, 1000, 1.0))
	var wc_b: int = int(fallback.get_walk_frame(0.0, 1370, 1.0))
	_expect(wc_a != wc_b, "an animator never driven by advance_walk_phase must keep the wall-clock cadence (soul-clone fallback)")


func _verify_starlight_pickup_hold_reads_idle() -> void:
	# Mechanism B: a ground pet with Starlight Tracking holds position for ~1s during the
	# pickup hold (only a vertical hop, x fixed). The draw ratio used to be hardcoded 1.0 for
	# ANY starlight override, so the held pet marched in place. It must now read the real
	# (zero horizontal) movement => idle.
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", registry, 1, 5), "starlight hold smoke should equip Starlight Tracking Lv.5 on a ground pet")
	# Settle a normal frame so the draw-anim prev-pos seed is established.
	runtime.update(0.05, owner, registry)
	var companion_pos: Vector2 = owner.lingpet_companion_pos
	var close_drop := _make_starpoint_drop(companion_pos + Vector2(8.0, 0.0), 0.0)
	owner.player_pos = companion_pos + Vector2(116.0, 0.0) - Vector2(owner.player_paddle_width, owner.player_paddle_height) * 0.5
	var close_context := _starpoint_delivery_context(owner)
	var pickup: Dictionary = runtime.update_starlight_tracking_for_starpoint_drop(close_drop, 0.0, close_context)
	_expect(bool(pickup.get("holding", false)), "starlight hold smoke fixture should reach the pickup hold")
	# One settle cycle: the pet relocates from its patrol spot to the catch X (a legitimate
	# horizontal move that DOES read as walking), and the draw-anim prev-pos catches up to the
	# held X. Then x is fixed for the rest of the ~1s hold.
	runtime.update_starlight_tracking_for_starpoint_drop(close_drop, 0.05, close_context)
	runtime.update(0.05, owner, registry)
	var held_x: float = owner.lingpet_companion_pos.x
	# Interleave the per-frame starpoint hook + runtime update across the held frames. Position
	# x must now stay put (only a vertical hop) and the draw ratio must read idle (0).
	for _i in range(3):
		var hold_result: Dictionary = runtime.update_starlight_tracking_for_starpoint_drop(close_drop, 0.05, close_context)
		_expect(bool(hold_result.get("holding", false)), "starlight pickup hold should persist across the held frames")
		runtime.update(0.05, owner, registry)
		_expect(absf(owner.lingpet_companion_pos.x - held_x) <= 0.001, "the held starlight pet must not travel horizontally during the pickup hold")
		_expect_float(float(runtime.get_companion_draw_motion_speed_ratio_for_tests()), 0.0, "a position-held starlight override must read as idle (no in-place walk animation)")


func _verify_patrol_static_frame_reads_idle() -> void:
	# The patrol/free-flight draw walk-idle gate must reflect ACTUAL drawn movement, not the
	# motion state's INTENDED speed. On a zero-delta tick (and other "pos did not advance" frames
	# such as a defense intercept arriving at a lane-clamped target) motion_state recomputes
	# motion_speed_ratio = _speed_ratio(patrol_speed) > 0.01 while the position stays put, which
	# would march the move sheet in place. Reference: nekuring (patrol, defense_rate 0.14) 제자리걸음.
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_ring_dash", registry, 1, 1), "static-frame smoke should activate a patrol pet")
	var lane_y: float = owner.lingpet_companion_pos.y
	runtime.configure_companion_motion_for_tests(Vector2(300.0, lane_y), 7, 0.0, false)
	# A real moving frame: seeds the draw-anim prev-pos and reads as walking.
	runtime.update(0.05, owner, registry)
	_expect(float(runtime.get_snapshot().get("companion_patrol_pause", 1.0)) <= 0.0, "fixture should leave the pet mid-stride (no patrol pause) before the static tick")
	_expect(float(runtime.get_companion_draw_motion_speed_ratio_for_tests()) > 0.01, "a genuinely moving patrol pet should read as walking")
	# Zero-delta tick: motion_speed_ratio is recomputed positive from patrol_speed, but the
	# position does NOT advance. The draw gate must read idle because no real movement happened.
	var pos_before: Vector2 = owner.lingpet_companion_pos
	runtime.update(0.0, owner, registry)
	_expect(absf(owner.lingpet_companion_pos.x - pos_before.x) <= 0.001, "a zero-delta tick must not advance the companion position")
	_expect(float(runtime.get_snapshot().get("companion_motion_speed_ratio", 0.0)) > 0.01, "the zero-delta tick should leave the INTENDED motion_speed_ratio positive (the trap input)")
	_expect_float(float(runtime.get_companion_draw_motion_speed_ratio_for_tests()), 0.0, "a patrol companion that did not actually move must read idle, even when intended motion_speed_ratio is positive (nekuring 제자리걸음)")


func _verify_orosha_distance_roll_angle_tracks_horizontal_travel() -> void:
	var direct_profile := LingpetCurrentProfile.new()
	direct_profile.set_pet_id("orosha")
	var direct_roll: Object = LingpetCompanionDistanceRollState.new()
	direct_roll.advance_draw_movement(Vector2(100.0, 100.0), 0.05, 200.0, direct_profile, 100.0, 0.35)
	_expect_float(float(direct_roll.get_override_move_ratio()), 0.35, "distance-roll state should seed draw-movement ratio from the motion state on the first frame")
	direct_roll.advance_draw_movement(Vector2(100.0, 130.0), 0.05, 200.0, direct_profile, 100.0, 0.0)
	_expect_float(float(direct_roll.get_override_move_ratio()), 0.0, "distance-roll state should keep vertical-only movement idle for side-view walk sheets")
	direct_roll.advance_draw_movement(Vector2(105.0, 130.0), 0.05, 200.0, direct_profile, 100.0, 0.0)
	_expect_float(float(direct_roll.get_override_move_ratio()), 0.5, "distance-roll state should normalize real horizontal draw movement into the walk ratio")
	direct_roll.reset()
	_expect_float(float(direct_roll.get_override_move_ratio()), 0.0, "distance-roll state reset should clear draw-movement ratio transients")

	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("orosha", owner, false, "", "", registry, 1, 1), "Orosha distance-roll smoke should activate the debug pet")
	_expect_float(float(runtime.get_companion_roll_angle_for_tests()), 0.0, "Orosha roll angle should start upright after activation")
	var base_pos: Vector2 = owner.lingpet_companion_pos
	runtime.configure_companion_motion_for_tests(base_pos, 2, 0.0, false)
	runtime.advance_companion_draw_anim_for_tests(0.05)
	runtime.configure_companion_motion_for_tests(base_pos + Vector2(12.0, 0.0), 2, 0.0, false)
	runtime.advance_companion_draw_anim_for_tests(0.05)
	var right_angle: float = float(runtime.get_companion_roll_angle_for_tests())
	var right_draw_angle: float = float(runtime.get_companion_roll_draw_angle_for_tests())
	var right_velocity: float = float(runtime.get_companion_roll_angular_velocity_for_tests())
	_expect(right_angle > 0.20, "Orosha should rotate forward when its drawn companion position moves right")
	_expect(is_equal_approx(right_draw_angle, right_angle), "Orosha should full-rotate the complete circular roll source instead of using the rejected limited-tilt fallback")
	_expect(right_velocity > 0.0, "Orosha should remember a positive visual roll velocity after moving right")
	runtime.advance_companion_draw_anim_for_tests(0.05)
	var coast_angle: float = float(runtime.get_companion_roll_angle_for_tests())
	var coast_velocity: float = float(runtime.get_companion_roll_angular_velocity_for_tests())
	_expect(coast_angle > right_angle, "Orosha should keep rolling briefly after its position stops instead of snapping to a hard stop")
	_expect(coast_velocity > 0.0 and coast_velocity < right_velocity, "Orosha stop coast should decelerate the remembered roll velocity")
	for _i in range(12):
		runtime.advance_companion_draw_anim_for_tests(0.05)
	_expect(is_zero_approx(float(runtime.get_companion_roll_angular_velocity_for_tests())), "Orosha visual roll coast should settle to rest after a short deceleration")
	var settled_angle: float = float(runtime.get_companion_roll_angle_for_tests())
	runtime.configure_companion_motion_for_tests(base_pos, 2, 0.0, false)
	runtime.advance_companion_draw_anim_for_tests(0.05)
	var left_angle: float = float(runtime.get_companion_roll_angle_for_tests())
	_expect(left_angle < settled_angle - 0.20, "Orosha should rotate back the opposite way when its drawn companion position moves left")
	_expect(float(runtime.get_companion_roll_angular_velocity_for_tests()) < 0.0, "Orosha should remember a negative visual roll velocity after moving left")


func _verify_patrol_dir_recovers_after_defense_park() -> void:
	# ROOT-CAUSE regression: the defense intercept parks patrol_dir at 0 on arrival, and nothing
	# restores it once the guard clears (flip = -1 * 0 = 0, and a heading-less pet can never reach
	# a lane edge to be re-aimed) — so the pet sits frozen in place until a round reset. That is
	# the real lingpet "제자리걸음" / barely-moving bug; the earlier animation fixes only changed
	# whether the frozen pet showed a walk or an idle frame. Drive the motion state directly so no
	# ball ever re-arms defense.
	var motion: Object = LingpetCompanionMotionState.new()
	var owner := FakeOwner.new()  # no active ball -> defense never arms
	# One real frame initializes the patrol lane + a heading.
	motion.update(0.05, owner, false, 0.0, 0, 150.0, 96.0, 204.0, "patrol", 0.0)
	# Simulate the leftover state after a defense intercept arrived and then cleared.
	motion.patrol_dir = 0.0
	motion.patrol_pause = 0.0
	var x_before: float = motion.pos.x
	for _i in range(16):
		motion.update(0.05, owner, false, 0.0, 0, 150.0, 96.0, 204.0, "patrol", 0.0)
	_expect(not is_zero_approx(motion.patrol_dir), "patrol must recover a non-zero heading after a defense park left patrol_dir at 0")
	_expect(absf(motion.pos.x - x_before) > 1.0, "a patrol pet must resume travelling after the defense guard clears, not sit frozen in place (제자리걸음 root cause)")


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
	vfx.sync_visibility(true, false, Vector2(440.0, 310.0))
	_expect(vfx.has_visible_effects(), "sync_visibility should trigger vanish on a free-flight visible->hidden edge")
	vfx.reset()
	vfx.sync_visibility(false, false, Vector2(440.0, 310.0))
	vfx.sync_visibility(true, false, Vector2(440.0, 310.0))
	_expect(not vfx.has_visible_effects(), "sync_visibility should not replay a stale non-free-flight hidden edge")
	vfx.sync_visibility(true, true, Vector2(440.0, 310.0))
	_expect(vfx.has_visible_effects(), "sync_visibility should trigger appear on a free-flight hidden->visible edge")

	# Wiring: the egg runtime must advance, draw, and fire the blink on free-flight
	# visibility edges, and reset it on the lingpet reset paths.
	var runtime_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var ghost_vfx_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_ghost_blink_vfx.gd")
	_expect(runtime_src.find("func _update_ghost_blink_vfx_triggers") < 0, "egg runtime should not keep a single-use ghost blink trigger wrapper")
	_expect(runtime_src.find("var _prev_ghost_visible") < 0, "egg runtime should not keep raw ghost visibility edge state")
	_expect(runtime_src.find("_ghost_blink_vfx.sync_visibility") >= 0, "egg runtime should ask the ghost blink VFX owner to sync free-flight visibility edges")
	_expect(ghost_vfx_src.find("func sync_visibility") >= 0 and ghost_vfx_src.find("trigger_appear") >= 0 and ghost_vfx_src.find("trigger_vanish") >= 0, "ghost blink VFX should own appear/vanish edge triggering")
	_expect(runtime_src.find("_ghost_blink_vfx.draw(") >= 0 and runtime_src.find("_ghost_blink_vfx.advance(") >= 0, "egg runtime should advance + draw the ghost blink VFX")
	# Reset moved off the runtime into the dedicated resetters; assert the new owners.
	var companion_resetter_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_runtime_resetter.gd")
	var round_resetter_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_round_resetter.gd")
	_expect(companion_resetter_src.find("ghost_blink_vfx.reset()") >= 0 and round_resetter_src.find("ghost_blink_vfx.reset()") >= 0, "lingpet reset paths (companion runtime + round resetters) should reset the ghost blink VFX")


func _measure_ghost_hidden_wait(rate: float) -> Dictionary:
	var motion: Object = LingpetCompanionMotionState.new()
	var owner := FakeOwner.new()
	motion.patrol_seed = 24680  # fixed seed: both rates share the RNG so only the
	motion.pos = Vector2.ZERO   # appearance_rate scaling differs, not the random rolls
	var dt := 0.1
	# First update initializes the ghost (spawn spot, visible).
	motion.update(dt, owner, false, 0.0, 0, 120.0, 70.0, 200.0, "free_flight", rate)
	var spawn_pos: Vector2 = motion.pos
	# Advance through the visible phase (drifting) until the ghost first vanishes.
	var visible_elapsed := 0.0
	while bool(motion.motion_visible) and visible_elapsed < 25.0:
		motion.update(dt, owner, false, 0.0, 0, 120.0, 70.0, 200.0, "free_flight", rate)
		visible_elapsed += dt
	var vanish_pos: Vector2 = motion.pos
	# Advance through the hidden wait until it reappears.
	var hidden := 0.0
	while not bool(motion.motion_visible) and hidden < 40.0:
		motion.update(dt, owner, false, 0.0, 0, 120.0, 70.0, 200.0, "free_flight", rate)
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
	# A sub-"moving"-threshold ratio (renderer treats ratio <= 0.01 as idle) must ALSO show the
	# static IDLE_FRAME, not cycle the idle sheet in place — otherwise a tiny stale ratio marches.
	var tiny_frame_a: int = int(animator.get_walk_frame(0.0, 1000, 0.005))
	var tiny_frame_b: int = int(animator.get_walk_frame(0.0, 9000, 0.005))
	_expect(tiny_frame_a == LingpetCompanionSpriteAnimator.IDLE_FRAME and tiny_frame_b == LingpetCompanionSpriteAnimator.IDLE_FRAME, "a sub-0.01 ratio must read the static idle frame, matching the renderer's moving gate")
	var slow_frame: int = int(animator.get_walk_frame(0.0, 1000, 0.20))
	var fast_frame: int = int(animator.get_walk_frame(0.0, 1000, 1.0))
	_expect(fast_frame != slow_frame and fast_frame > slow_frame, "Lunabi wing-flap frame cadence should increase with flight speed")
	var hover_frame_a: int = int(animator.get_walk_frame(1.0, 1000, 0.12))
	var hover_frame_b: int = int(animator.get_walk_frame(1.0, 1400, 0.12))
	_expect(hover_frame_a != hover_frame_b, "Sortie-flight companions should keep cycling wing-flap frames while hovering")
	_expect(LingpetCompanionSpriteAnimator.FLIGHT_FPS_MAX <= 14.0, "Lunabi wing-flap cadence should stay below vibration-speed playback")
	var egg_runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var body_presence_resolver_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
	_expect(egg_runtime_source.find("COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO") >= 0, "Sortie-flight runtime should keep a minimum visible wing-flap cadence during hover")
	_expect(egg_runtime_source.find("func _get_companion_draw_motion_speed_ratio") < 0, "egg runtime should not keep a private draw-motion speed-ratio helper")
	_expect(body_presence_resolver_source.find("func get_draw_motion_speed_ratio_from_runtime") >= 0 and body_presence_resolver_source.find("func get_draw_motion_speed_ratio_from_sources") >= 0, "Companion draw context should route sortie-flight cadence through source-aware body-presence helpers")

	var forced_companion_pos := Vector2(380.0, 310.0)
	runtime.configure_companion_motion_for_tests(forced_companion_pos, 2, 0.0, false)
	owner.player_pos = Vector2(40.0, owner.player_pos.y)
	owner.ball_active = true
	owner.ball_pos = forced_companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.01, owner)
	_expect(owner.ball_vel.y < 0.0, "Lunabi overlap should bounce the ball")
	_expect(int(owner.lingpet_companion_contact_count) == 1, "Lunabi overlap should register one companion contact")
	_expect(bool(runtime.is_companion_striking_for_tests()), "Lunabi should play the ball-swoop strike sheet on contact")


func _verify_lunabi_headbutt_mega() -> void:
	var HeadbuttSkill := load("res://scripts/lingpet/lingpet_headbutt_skill.gd")

	# Lv.5 forced mega: 2s charge -> single dash -> compounded knockback + stun + mega impact flag.
	var skill = HeadbuttSkill.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(330.0, 25.0)
	owner.boss_vel = 0.0
	var boss_ai := FakeBossAiState.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new(), "boss_ai_state": boss_ai, "status_effect_state": status_state})
	var ctx := {
		"active_skill_level": 5,
		"knockback_scale": 1.40,
		"headbutt_count": 3,
		"mega_chance": 0.25,
		"mega_knockback_bonus_pct": 0.50,
		"mega_stun_seconds": 1.5,
		"headbutt_mega_roll": 0.0,
	}
	_expect(skill.launch(Vector2(380.0, 600.0), owner, ctx), "forced mega roll should launch the headbutt")
	var launch_snap: Dictionary = skill.get_snapshot()
	_expect(bool(launch_snap.get("headbutt_is_mega", false)), "roll 0.0 < 0.25 should trigger Mega Headbutt at Lv.5")
	_expect(bool(launch_snap.get("headbutt_mega_charging", false)), "Mega Headbutt should enter the 2s charge before dashing")
	_expect(not bool(launch_snap.get("headbutt_active", false)), "Mega Headbutt should not dash during the charge")
	_expect(int(launch_snap.get("headbutt_combo_total", 0)) == 1, "Mega Headbutt should be a single hit (combo 1)")
	_expect(is_equal_approx(float(launch_snap.get("headbutt_mega_charge_seconds", 0.0)), 2.0), "Mega Headbutt charge should last 2 seconds")

	skill.update(1.0, owner, registry)
	_expect(bool(skill.get_snapshot().get("headbutt_mega_charging", false)), "Mega Headbutt should still be charging at 1.0s")
	_expect(int(skill.get_hit_count_for_tests()) == 0, "Mega Headbutt should not hit during the charge")

	var hit := false
	for _i in range(60):
		skill.update(0.05, owner, registry)
		if int(skill.get_hit_count_for_tests()) > 0:
			hit = true
			break
	_expect(hit, "Mega Headbutt should dash and hit after the charge")
	var hit_snap: Dictionary = skill.get_snapshot()
	_expect(str(hit_snap.get("headbutt_last_result", "")) == "mega_hit", "Mega Headbutt hit should report the mega result")
	_expect(bool(hit_snap.get("headbutt_mega_impact", false)), "Mega Headbutt hit should flag the stronger impact VFX")
	_expect(boss_ai.knockback_calls == 0, "Mega Headbutt must NOT queue the paddle-hit knockback channel (the boss stun branch bypasses it); the knockback rides the stun instead")
	var stun_calls := status_state.get_calls_for_source("lingpet_headbutt_mega")
	_expect(stun_calls.size() == 1, "Mega Headbutt should apply exactly one boss stun")
	var stun_data: Dictionary = stun_calls[0].get("data", {})
	_expect(str(stun_calls[0].get("target", "")) == "boss", "Mega Headbutt stun should target the boss")
	_expect(str(stun_calls[0].get("status_id", "")) == "stun", "Mega Headbutt should apply a stun status")
	_expect(is_equal_approx(float(stun_calls[0].get("duration_frames", 0.0)), 90.0), "Mega Headbutt Lv.5 stun should be 1.5s (90 frames)")
	_expect(bool(stun_data.get("knockback_active", false)), "Mega Headbutt stun MUST carry an active knockback so the stunned boss actually slides back")
	_expect(is_equal_approx(absf(float(stun_data.get("knockback_vel", 0.0))), 13.0 * 1.40 * 1.50), "Mega Headbutt Lv.5 stun knockback should compound normal scale (1.40) x mega bonus (1.50)")
	_expect(is_equal_approx(float(stun_data.get("knockback_frames", 0.0)), 30.0), "Mega Headbutt stun knockback should run for the 30-frame headbutt window")
	_expect(is_equal_approx(float(stun_data.get("knockback_decay_per_frame", 0.0)), 0.91), "Mega Headbutt stun knockback should use the headbutt knockback decay")

	# Lv.3 mega tuning: knockback 1.25 x 1.30, stun 1.0s (60 frames).
	var skill3 = HeadbuttSkill.new()
	var owner3 := FakeOwner.new()
	owner3.boss_pos = Vector2(330.0, 25.0)
	owner3.boss_vel = 0.0
	var boss_ai3 := FakeBossAiState.new()
	var status3 := FakeStatusEffectState.new()
	var registry3 := FakeRegistry.new({"game_audio": FakePaddleAudio.new(), "boss_ai_state": boss_ai3, "status_effect_state": status3})
	var ctx3 := {"active_skill_level": 3, "knockback_scale": 1.25, "headbutt_count": 2, "mega_chance": 0.20, "mega_knockback_bonus_pct": 0.30, "mega_stun_seconds": 1.0, "headbutt_mega_roll": 0.1}
	_expect(skill3.launch(Vector2(380.0, 600.0), owner3, ctx3), "Lv.3 forced mega should launch")
	for _i in range(60):
		skill3.update(0.05, owner3, registry3)
		if int(skill3.get_hit_count_for_tests()) > 0:
			break
	_expect(boss_ai3.knockback_calls == 0, "Mega Headbutt Lv.3 should route knockback through the stun, not the paddle-hit channel")
	var stun3 := status3.get_calls_for_source("lingpet_headbutt_mega")
	_expect(stun3.size() == 1, "Mega Headbutt Lv.3 should apply one boss stun")
	_expect(is_equal_approx(float(stun3[0].get("duration_frames", 0.0)), 60.0), "Mega Headbutt Lv.3 stun should be 1.0s (60 frames)")
	_expect(is_equal_approx(absf(float(stun3[0].get("data", {}).get("knockback_vel", 0.0))), 13.0 * 1.25 * 1.30), "Mega Headbutt Lv.3 stun knockback should compound 1.25 x 1.30")
	_expect(bool(stun3[0].get("data", {}).get("knockback_active", false)), "Mega Headbutt Lv.3 stun knockback should be active")

	# Non-mega roll: normal multi-hit combo, no mega charge, no mega stun.
	var skill2 = HeadbuttSkill.new()
	var owner2 := FakeOwner.new()
	owner2.boss_pos = Vector2(330.0, 25.0)
	owner2.boss_vel = 0.0
	var status2 := FakeStatusEffectState.new()
	var registry2 := FakeRegistry.new({"game_audio": FakePaddleAudio.new(), "boss_ai_state": FakeBossAiState.new(), "status_effect_state": status2})
	var ctx2 := {"active_skill_level": 5, "knockback_scale": 1.40, "headbutt_count": 3, "mega_chance": 0.25, "mega_knockback_bonus_pct": 0.50, "mega_stun_seconds": 1.5, "headbutt_mega_roll": 0.99}
	_expect(skill2.launch(Vector2(380.0, 600.0), owner2, ctx2), "non-mega roll should still launch the headbutt")
	var snap2: Dictionary = skill2.get_snapshot()
	_expect(not bool(snap2.get("headbutt_is_mega", false)), "roll 0.99 >= 0.25 should NOT trigger Mega Headbutt")
	_expect(not bool(snap2.get("headbutt_mega_charging", false)), "non-mega cast should not charge")
	_expect(int(snap2.get("headbutt_combo_total", 0)) == 3, "non-mega Lv.5 cast should keep the 3-hit combo")
	for _i in range(20):
		skill2.update(0.05, owner2, registry2)
		if int(skill2.get_hit_count_for_tests()) > 0:
			break
	_expect(status2.get_calls_for_source("lingpet_headbutt_mega").size() == 0, "non-mega headbutt should not apply a mega stun")


func _verify_lunabi_headbutt_level_scaling() -> void:
	var cases := [
		{"level": 1, "combo": 1, "scale": 1.10},
		{"level": 3, "combo": 2, "scale": 1.25},
		{"level": 5, "combo": 3, "scale": 1.40},
	]
	for case in cases:
		var level := int(case.get("level", 1))
		var expected_combo := int(case.get("combo", 0))
		var expected_scale := float(case.get("scale", 0.0))
		var owner := FakeOwner.new()
		owner.boss_pos = Vector2(320.0, 25.0)
		owner.boss_vel = 0.0
		owner.ball_active = true
		var runtime: Object = LingpetEggRuntime.new()
		var registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new(), "boss_ai_state": FakeBossAiState.new()})
		_expect(runtime.debug_grant_and_activate_pet("lunabi", owner, false, "lunabi_headbutt", "", registry, level, 1), "Headbutt level fixture should equip Lv.%d" % level)
		runtime.set_headbutt_force_mega_roll_for_tests(1.0)
		runtime.update(0.0, owner, registry)
		runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
		runtime.update(0.0, owner, registry)
		runtime.update(0.50, owner, registry)
		var snap: Dictionary = runtime.get_snapshot()
		_expect(bool(snap.get("headbutt_active", false)), "Headbutt Lv.%d should launch after its wind-up" % level)
		_expect(int(snap.get("headbutt_active_skill_level", 0)) == level, "Headbutt should publish the active skill level %d" % level)
		_expect(int(snap.get("headbutt_combo_total", 0)) == expected_combo, "Headbutt Lv.%d should perform %d total dashes" % [level, expected_combo])
		_expect(is_equal_approx(float(snap.get("headbutt_knockback_scale", 0.0)), expected_scale), "Headbutt Lv.%d knockback distance scale should be %.3f" % [level, expected_scale])


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
	owner.boss_pos = Vector2(320.0, 25.0)
	owner.boss_vel = 0.0
	owner.ball_active = true
	var runtime: Object = LingpetEggRuntime.new()
	var audio := FakePaddleAudio.new()
	var boss_ai := FakeBossAiState.new()
	var registry := FakeRegistry.new({"game_audio": audio, "boss_ai_state": boss_ai})
	_expect(runtime.debug_grant_and_activate_pet("lunabi", owner, false, "lunabi_headbutt", "", registry, 5, 1), "Lunabi Headbutt fixture should equip the Lv.5 three-hit combo")
	runtime.set_headbutt_force_mega_roll_for_tests(1.0)
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
	_expect(owner.lingpet_skill_cooldown > 25.0 and owner.lingpet_skill_cooldown <= 26.5, "Lunabi Headbutt Lv.5 should enter the level-reduced ~26.4s cooldown (30s base - 12% global level reduction)")
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


func _verify_loadout_apply_prewarms_active_skill_runtime() -> void:
	# Hot-path lazy-init regression: the skill runtime host must already hold
	# the active skill module (and its heavy sheet) after the discrete
	# loadout-apply / boot-prewarm moments, never on the first per-frame
	# update() or the first arm.
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		runtime.debug_grant_and_activate_pet("koyora", owner, false, "koyora_doll_curse", "lingpet_resonance_boost"),
		"prewarm regression setup should activate Koyora with the doll curse loadout"
	)
	var host: Object = runtime._skill_runtime_host
	_expect(host._doll_curse_skill != null, "loadout apply should build the doll curse module before any per-frame host update")
	if host._doll_curse_skill != null:
		_expect(host._doll_curse_skill._doll_sheet_texture != null, "loadout apply should load the doll sheet before the first arm")

	host._doll_curse_skill = null
	runtime.prewarm_assets()
	_expect(host._doll_curse_skill != null, "boot prewarm_assets should rebuild the carried pet's active skill module")

	var fresh: Object = LingpetEggRuntime.new()
	fresh.prewarm_assets()
	_expect(fresh._skill_runtime_host._doll_curse_skill == null, "boot prewarm without an equipped pet should not build skill modules")


func _verify_skeleton_archer_resets_on_stage_transition() -> void:
	# Summoned Skeleton Archers persist across ROUND boundaries (reset_round keeps them) but
	# must be wiped when the player advances to the next STAGE. The egg runtime self-detects
	# the owner's current_stage change and runs a full skill-host reset (round_scope=false).
	var runtime: Object = LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	owner.current_stage = 1
	owner.ball_active = false
	var registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new()})
	var host: Object = runtime._skill_runtime_host
	var skill_persistence: Object = runtime._companion_skill_persistence
	_expect(
		bool(host.launch("nekuring_skeleton_archer", Vector2(380.0, 680.0), owner, {"registry": registry, "spawn_x": 380.0, "spawn_y": 650.0, "arrow_cooldown": 99.0})),
		"stage-transition fixture should summon a Skeleton Archer"
	)
	host.update(1.21, owner, registry, "nekuring_skeleton_archer", {})
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 1, "stage-transition fixture should keep one live archer before any stage change")
	# First observation at stage 1 only adopts the stage number (no wipe -- not a real change).
	skill_persistence.maybe_reset_runtime_transients_for_stage(owner.current_stage, runtime._companion_skill_states, host, owner, registry)
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 1, "adopting the initial stage number must not wipe the summoned archer")
	# Staying on the same stage (a round boundary within the stage) keeps the archer.
	skill_persistence.maybe_reset_runtime_transients_for_stage(owner.current_stage, runtime._companion_skill_states, host, owner, registry)
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 1, "staying on the same stage (round boundary) must keep the summoned archer")
	# Advancing to the next stage wipes the deployed archer.
	owner.current_stage = 2
	skill_persistence.maybe_reset_runtime_transients_for_stage(owner.current_stage, runtime._companion_skill_states, host, owner, registry)
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 0, "advancing to the next stage must wipe the summoned archer")
	# The detector must actually be wired into the per-frame update, or it never fires in play.
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var persistence_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
	_expect(runtime_source.find("func _maybe_reset_skill_deployments_for_stage") < 0, "egg runtime should not keep a private per-stage deployment reset wrapper")
	_expect(runtime_source.find("_companion_skill_persistence.maybe_reset_runtime_transients_for_stage") >= 0, "egg runtime update should drive the persistence-owned per-stage deployment reset")
	_expect(persistence_source.find("func maybe_reset_runtime_transients_for_stage") >= 0 and persistence_source.find("func reset_stage_observer") >= 0, "companion skill persistence should own stage-change deployment reset state")


func _verify_koyora_puppet_grab_skill() -> void:
	# 꼭두각시 조종 (Puppet Control) — ported from 연화 (maria) in the original.
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_puppet_grab_skill.gd"), "Koyora puppet-grab skill module should exist")
	var src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_puppet_grab_skill.gd")
	_expect(
		src.find("PHASE_EXTENDING") >= 0 and src.find("PHASE_PULLING") >= 0 and src.find("PHASE_KISSING") >= 0 and src.find("PHASE_RETURNING") >= 0,
		"꼭두각시 조종 should keep the original 4-phase extend/pull/kiss/return machine"
	)
	_expect(src.find("ball_pos") >= 0 and src.find("ROPE_CUT_BALL_RADIUS_PAD") >= 0, "꼭두각시 조종 should read live ball position only for rope-cut counterplay")
	_expect(src.find("ball_vel") < 0 and src.find("owner.set(\"ball_pos\"") < 0, "꼭두각시 조종 must not move the ball or read its velocity")
	_expect(src.find("lingpet_puppet_grab_active") >= 0, "꼭두각시 조종 should flag the owner so the boss AI is held while scripted")
	_expect(src.find("play_lingpet_puppet_grab_pull") >= 0, "꼭두각시 조종 should play the original grab.wav on the pull phase edge")
	_expect(src.find("play_lingpet_puppet_grab_kiss") >= 0, "꼭두각시 조종 should play the original kissing.wav on the kiss phase edge")
	var puppet_skill_data: Dictionary = LingpetCatalog.get_active_skill("koyora", "koyora_puppet_control")
	var puppet_desc := str(puppet_skill_data.get("description", ""))
	_expect(puppet_desc.find("줄이 공에 닿으면") >= 0 and puppet_desc.find("원래 위치") >= 0, "Koyora Puppet Control tooltip should explain the ball-cut return counterplay")

	_expect(
		src.find("STRING_TIP_FOCUS_START") >= 0 and src.find("_string_tip_focus") >= 0,
		"Puppet Control string VFX should tighten near the target so MISS visuals do not look like boss contact"
	)
	var string_visual_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	_expect(float(string_visual_skill.get_string_visual_lateral_radius_for_tests(1.0)) <= 0.05, "Puppet Control strings should converge exactly at the lock-on point")
	_expect(float(string_visual_skill.get_string_visual_lateral_radius_for_tests(0.95)) <= 3.0, "Puppet Control strings should be narrow near the lock-on point so edge-dodges do not read as contact")
	_expect(float(string_visual_skill.get_string_visual_lateral_radius_for_tests(0.75)) >= 8.0, "Puppet Control strings should keep visible wave/body before the final target focus")

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
	var launch_feedback_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_launch_feedback_router.gd")
	_expect(
		skill_host_src.find("_launch_feedback_router.trigger(skill_id, registry)") >= 0
			and launch_feedback_src.find("play_lingpet_puppet_grab_cast") >= 0,
		"skill runtime facade should delegate the original tentacle cast SFX instead of generic active-item feedback"
	)
	var draw_context_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	var visual_cache_src: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
	_expect(skill_host_src.find("get_companion_cast_pose_progress") >= 0, "skill runtime host should expose active skill companion-cast pose progress")
	_expect(draw_context_src.find("companion_puppet_control") >= 0 and draw_context_src.find("skill_cast_pose_active") >= 0, "companion draw context should swap to Koyora's Puppet Control sheet during active puppet phases")
	_expect(visual_cache_src.find("companion_puppet_control") >= 0, "lingpet visual prewarm should include Koyora's active Puppet Control sheet key")
	_expect(LingpetCatalog.get_visual_path("koyora", "companion_puppet_control") == "res://assets/sprites/lingpet/koyora_puppet_control_cast.png", "Koyora catalog should own the Puppet Control active companion sheet path")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/koyora_puppet_control_cast.png"), "Koyora Puppet Control active companion sheet should exist")
	var puppet_control_sheet: Texture2D = load("res://assets/sprites/lingpet/koyora_puppet_control_cast.png") as Texture2D
	_expect(puppet_control_sheet != null, "Koyora Puppet Control active companion sheet should load as a Texture2D")
	if puppet_control_sheet != null:
		_expect(puppet_control_sheet.get_width() == 1280 and puppet_control_sheet.get_height() == 1280, "Koyora Puppet Control sheet should be the normalized 1280px 5x5 runtime sheet")
		_expect(puppet_control_sheet.get_width() % 5 == 0 and puppet_control_sheet.get_height() % 5 == 0, "Koyora Puppet Control sheet should divide evenly into the companion 5x5 grid")
	var puppet_control_manifest: String = FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_puppet_control_cast_manifest.json")
	_expect(
		puppet_control_manifest.find("koyora_puppet_control_cast_original_idle_big_two_arm_v3") >= 0
			and puppet_control_manifest.find("koyora_companion_idle.png") >= 0
			and puppet_control_manifest.find("\"new_attack_strings_drawn\": false") >= 0
			and puppet_control_manifest.find("visible_motion_tuning") >= 0
			and puppet_control_manifest.find("\"edge_alpha_max\": 0") >= 0
			and puppet_control_manifest.find("\"edge_touch_frames\": []") >= 0,
		"Koyora Puppet Control manifest should pin the original-idle-derived sheet provenance and clean-edge QA"
	)
	_expect(
		_sheet_frame_motion_score("res://assets/sprites/lingpet/koyora_puppet_control_cast.png", 0, 14, 112) > 900.0
			and _sheet_frame_motion_score("res://assets/sprites/lingpet/koyora_puppet_control_cast.png", 14, 24, 112) > 900.0,
		"Koyora Puppet Control sheet should have visible frame-to-frame sleeve motion at runtime draw size"
	)

	# Boss-side plumbing: the grab only works if the freeze wiring is present,
	# while normal boss-paddle collision remains active as in the Python original.
	var ai_src: String = FileAccess.get_file_as_string("res://scripts/ai/boss_ai_state.gd")
	_expect(ai_src.find("lingpet_puppet_grab_active") >= 0, "boss_ai_state should freeze the boss while it is puppeted")
	var ctx_src: String = FileAccess.get_file_as_string("res://scripts/core/battle_update_boss_ai_context_builder.gd")
	_expect(ctx_src.find("lingpet_puppet_grab_active") >= 0, "boss AI context should publish the puppet-grab flag")
	var det_src: String = FileAccess.get_file_as_string("res://scripts/ball/ball_motion_collision_detector.gd")
	_expect(det_src.find("lingpet_puppet_grab_active") < 0, "ball collision detector must not skip the puppeted boss")

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
	_expect(bool(owner.lingpet_puppet_grab_active), "HIT-transition into PULLING must NOW flag the owner so the boss AI is frozen")
	_expect(owner.boss_pos.y > boss_original.y + 2.0, "the boss should be dragged downward during the pull")
	var puppeted_collision_detector: Object = BallMotionCollisionDetector.new()
	var puppeted_boss_size := Vector2(owner.boss_paddle_width, owner.boss_hitbox_height)
	var puppeted_collision_context: Dictionary = {
		"hitbox_padding": 5.0,
		"player_pos": owner.player_pos,
		"player_paddle_size": Vector2(owner.player_paddle_width, owner.player_paddle_height),
		"boss_pos": owner.boss_pos,
		"boss_paddle_size": puppeted_boss_size,
		"boss_collision_cooldown": 0.0,
		"lingpet_puppet_grab_active": true,
	}
	var puppeted_collision: Dictionary = puppeted_collision_detector.check_paddles(
		owner.boss_pos + puppeted_boss_size * 0.5,
		Vector2(0.0, -12.0),
		owner.ball_size,
		puppeted_collision_context
	)
	_expect(
		str(puppeted_collision.get("event", "")) == BallMotionCollisionDetector.EVENT_BOSS_PADDLE,
		"puppeted boss paddle should still collide with a rising ball, matching the Python original"
	)
	# Outcome regression: the post-hit snap must anchor to the LIVE displaced
	# boss paddle. The old snap used the static `boss_y` constant, so a ball
	# touching the dragged-down boss teleported back to the top of the screen.
	var puppeted_post_hit: Object = load("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd").new()
	var puppeted_post_hit_result: Dictionary = puppeted_post_hit.apply(
		owner.boss_pos + puppeted_boss_size * 0.5,
		Vector2(0.0, 12.0),
		0.0,
		0.0,
		false,
		false,
		false,
		{
			"boss_y": 25.0,
			"boss_hitbox_height": owner.boss_hitbox_height,
			"ball_size": owner.ball_size,
			"boss_pos": owner.boss_pos,
			"boss_paddle_width": owner.boss_paddle_width,
			"boss_vel": 0.0,
		},
		{},
		null
	)
	var puppeted_snap_pos: Vector2 = puppeted_post_hit_result.get("ball_pos", Vector2.ZERO)
	var puppeted_expected_snap_y: float = owner.boss_pos.y + owner.boss_hitbox_height + owner.ball_size
	_expect(
		abs(puppeted_snap_pos.y - puppeted_expected_snap_y) <= 0.01,
		"a puppeted boss-paddle hit must snap the ball below the DISPLACED paddle, not teleport it to the static top"
	)
	# Python parity (pingfighter.py 174199): every boss hit re-arms the boss
	# collision cooldown. With the kiss point parked just above the player
	# band, a missing cooldown lets the snapped ball ping-pong boss<->player
	# every couple of frames through the whole kiss window.
	var puppeted_hit_cooldown: float = float(puppeted_post_hit_result.get("boss_collision_cooldown", 0.0))
	_expect(
		puppeted_hit_cooldown > 0.0,
		"a boss-paddle hit must re-arm boss_collision_cooldown (Python parity) so a displaced boss cannot re-collide frame-to-frame"
	)
	var puppeted_recollision_context: Dictionary = puppeted_collision_context.duplicate()
	puppeted_recollision_context["boss_collision_cooldown"] = puppeted_hit_cooldown
	var puppeted_recollision: Dictionary = puppeted_collision_detector.check_paddles(
		owner.boss_pos + puppeted_boss_size * 0.5,
		Vector2(0.0, -12.0),
		owner.ball_size,
		puppeted_recollision_context
	)
	_expect(
		str(puppeted_recollision.get("event", "")) == "",
		"while the post-hit cooldown is armed, a rising overlap must NOT re-collide with the puppeted boss"
	)
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

	# --- Ball-cut counterplay: once the boss is actually being controlled, a
	# live ball crossing the puppet strings should snap them and force the boss
	# into the same return path without counting as MISS / retry.
	var cut_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var cut_audio := FakePaddleAudio.new()
	var cut_registry := FakeRegistry.new({"game_audio": cut_audio})
	var cut_owner := FakeOwner.new()
	cut_owner.boss_pos = Vector2(330.0, 25.0)
	cut_owner.boss_paddle_width = 100.0
	cut_owner.boss_hitbox_height = 40.0
	cut_owner.ball_active = true
	cut_owner.ball_pos = Vector2(20.0, 700.0)
	cut_owner.ball_pos_prev = cut_owner.ball_pos
	var cut_origin := Vector2(380.0, 600.0)
	_expect(bool(cut_skill.launch(cut_origin, cut_owner, {})), "ball-cut launch should succeed")
	cut_skill.update(0.75, cut_owner, cut_registry)
	var pre_cut_snap: Dictionary = cut_skill.get_snapshot()
	_expect(int(pre_cut_snap.get("puppet_grab_phase", -1)) == 1, "ball-cut setup should be in PULLING before the ball touches the rope")
	_expect(bool(cut_owner.lingpet_puppet_grab_active), "ball-cut setup should own and freeze the boss before the rope is cut")
	var cut_hand := cut_origin + Vector2(0.0, -6.0)
	var pre_cut_boss_center: Vector2 = pre_cut_snap.get("puppet_grab_boss_center", Vector2.ZERO)
	var rope_mid := cut_hand.lerp(pre_cut_boss_center, 0.5)
	cut_owner.ball_pos_prev = rope_mid + Vector2(-80.0, 0.0)
	cut_owner.ball_pos = rope_mid + Vector2(80.0, 0.0)
	cut_skill.update(0.016, cut_owner, cut_registry)
	var cut_snap: Dictionary = cut_skill.get_snapshot()
	_expect(int(cut_snap.get("puppet_grab_phase", -1)) == 3, "ball touching the puppet string should switch the grab into RETURNING")
	_expect(bool(cut_snap.get("puppet_grab_cut_by_ball", false)), "rope-cut snapshot should mark the ball-cut reason")
	_expect(int(cut_snap.get("puppet_grab_cut_count", -1)) == 1, "rope-cut should count exactly once")
	_expect(not bool(cut_snap.get("puppet_grab_missed", false)), "rope-cut should not be treated as a lock-on MISS")
	_expect(int(cut_snap.get("puppet_grab_miss_count", -1)) == 0, "rope-cut should not consume MISS retry accounting")
	_expect(int(cut_snap.get("puppet_grab_kiss_count", -1)) == 0, "rope-cut before kiss should skip the kiss payoff")
	_expect(cut_audio.puppet_grab_miss_count == 1, "rope-cut should play the short snap/miss feedback cue once")
	var cut_start_pos: Vector2 = cut_owner.boss_pos
	cut_skill.update(0.30, cut_owner, cut_registry)
	_expect(
		_vector2_distance(cut_owner.boss_pos, Vector2(330.0, 25.0)) < _vector2_distance(cut_start_pos, Vector2(330.0, 25.0)),
		"after the rope is cut, the boss should travel back toward its captured origin"
	)
	cut_skill.update(1.0, cut_owner, cut_registry)
	_expect(not bool(cut_skill.is_active()), "rope-cut return should finish through the normal return phase")
	_expect(not bool(cut_owner.lingpet_puppet_grab_active), "rope-cut return should release the boss-freeze flag")
	_expect(_vector2_distance(cut_owner.boss_pos, Vector2(330.0, 25.0)) <= 0.01, "rope-cut return should restore the boss to its exact origin")

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

	var pose_host: Object = LingpetSkillRuntimeHost.new()
	var pose_profile: Object = LingpetCurrentProfile.new()
	pose_profile.set_pet_id("koyora")
	pose_profile.set_loadout("koyora_puppet_control", "")
	var pose_owner := FakeOwner.new()
	pose_owner.boss_pos = Vector2(330.0, 25.0)
	pose_owner.boss_paddle_width = 100.0
	pose_owner.boss_hitbox_height = 40.0
	var pose_registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new()})
	_expect(bool(pose_host.launch("koyora_puppet_control", Vector2(380.0, 600.0), pose_owner, {})), "Puppet Control pose host should launch")
	pose_host.update(0.2, pose_owner, pose_registry, "koyora_puppet_control")
	var pose_extend_config: Dictionary = LingpetCompanionDrawContextBuilder.new().build_config({
		"companion_active": true,
		"skill_runtime_host": pose_host,
		"current_profile": pose_profile,
		"skill_id": "koyora_puppet_control",
		"animator": LingpetCompanionSpriteAnimator.new(),
		"windup_seconds": 0.8,
	})
	_expect(bool(pose_extend_config.get("skill_cast_pose_active", false)), "active Puppet Control EXTENDING should force the companion cast pose sheet")
	_expect(pose_extend_config.get("cast_texture", null) is Texture2D, "active Puppet Control EXTENDING should resolve a cast texture")
	_expect(is_equal_approx(float(pose_extend_config.get("cast_draw_size", 0.0)), 112.0), "active Puppet Control should use the larger action-pose draw size so the sleeve motion is readable")
	_expect(float(pose_extend_config.get("windup_seconds", 0.0)) == 1.0, "active Puppet Control pose progress should use normalized cast-sheet progress")
	_expect(float(pose_extend_config.get("windup_elapsed", -1.0)) >= 0.0 and float(pose_extend_config.get("windup_elapsed", -1.0)) < 0.56, "active Puppet Control EXTENDING should map to the arm-thrust half of the sheet")
	pose_host.update(0.5, pose_owner, pose_registry, "koyora_puppet_control")
	var pose_pull_config: Dictionary = LingpetCompanionDrawContextBuilder.new().build_config({
		"companion_active": true,
		"skill_runtime_host": pose_host,
		"current_profile": pose_profile,
		"skill_id": "koyora_puppet_control",
		"animator": LingpetCompanionSpriteAnimator.new(),
		"windup_seconds": 0.8,
	})
	_expect(bool(pose_pull_config.get("skill_cast_pose_active", false)), "active Puppet Control PULLING should keep the companion cast pose sheet")
	_expect(float(pose_pull_config.get("windup_elapsed", -1.0)) >= 0.62, "active Puppet Control PULLING should map to the pull-in frames of the sheet")

	var level_context_owner := FakeOwner.new()
	level_context_owner.lingpet_owned_pet_ids = ["koyora"]
	level_context_owner.lingpet_slots = ["koyora", "", ""]
	level_context_owner.boss_pos = Vector2(330.0, 25.0)
	level_context_owner.boss_paddle_width = 100.0
	level_context_owner.boss_hitbox_height = 40.0
	level_context_owner.ball_active = true
	var level_context_runtime: Object = LingpetEggRuntime.new()
	var level_context_registry := FakeRegistry.new({"game_audio": FakePaddleAudio.new()})
	_expect(level_context_runtime.debug_grant_and_activate_pet("koyora", level_context_owner, false, "koyora_puppet_control", "", level_context_registry, 5, 1), "debug Koyora grant should accept active skill Lv.5")
	level_context_runtime.update(0.0, level_context_owner, level_context_registry)
	level_context_runtime.configure_companion_motion_for_tests(Vector2(380.0, 600.0), 2, 0.0, false)
	level_context_runtime.update(0.0, level_context_owner, level_context_registry)
	level_context_runtime.update(0.85, level_context_owner, level_context_registry)
	_expect(int(level_context_runtime.get_snapshot().get("puppet_grab_active_skill_level", 0)) == 5, "egg runtime should pass the equipped active skill level into puppet-grab launch context")

	# --- Skill-level retry rules: Lv.1-2 never retry, Lv.3-4 can retry once,
	# Lv.5 can chain up to two retry launches. Forced roll queues prove the 50%
	# gate is rolled once per MISS edge, not every frame while the MISS feedback
	# remains active.
	var lv2_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var lv2_owner := FakeOwner.new()
	var lv2_audio := FakePaddleAudio.new()
	var lv2_registry := FakeRegistry.new({"game_audio": lv2_audio})
	lv2_owner.boss_pos = Vector2(330.0, 25.0)
	_expect(bool(lv2_skill.launch(Vector2(380.0, 600.0), lv2_owner, {"active_skill_level": 2})), "Lv.2 puppet retry smoke should launch")
	lv2_skill.set_retry_roll_queue_for_tests([true])
	lv2_owner.boss_pos = Vector2(600.0, 25.0)
	lv2_skill.update(float(lv2_skill.get_snapshot().get("puppet_grab_extend_seconds", 0.538)), lv2_owner, lv2_registry)
	var lv2_snap: Dictionary = lv2_skill.get_snapshot()
	_expect(int(lv2_snap.get("puppet_grab_phase", -1)) == int(lv2_snap.get("puppet_grab_phase_missing", -2)), "Lv.2 MISS should not enter retry wait even if the forced retry roll would succeed")
	_expect(int(lv2_snap.get("puppet_grab_shot_count", -1)) == 1, "Lv.2 should fire exactly one string shot")
	_expect(int(lv2_snap.get("puppet_grab_retry_rolls_queued", -1)) == 1, "Lv.2 should not consume a retry roll because it has no retry chance")

	var lv3_fail_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var lv3_fail_owner := FakeOwner.new()
	var lv3_fail_audio := FakePaddleAudio.new()
	var lv3_fail_registry := FakeRegistry.new({"game_audio": lv3_fail_audio})
	lv3_fail_owner.boss_pos = Vector2(330.0, 25.0)
	_expect(bool(lv3_fail_skill.launch(Vector2(380.0, 600.0), lv3_fail_owner, {"active_skill_level": 3})), "Lv.3 failed-roll retry smoke should launch")
	lv3_fail_skill.set_retry_roll_queue_for_tests([false])
	lv3_fail_owner.boss_pos = Vector2(600.0, 25.0)
	var lv3_fail_extend := float(lv3_fail_skill.get_snapshot().get("puppet_grab_extend_seconds", 0.538))
	lv3_fail_skill.update(lv3_fail_extend, lv3_fail_owner, lv3_fail_registry)
	var lv3_fail_first: Dictionary = lv3_fail_skill.get_snapshot()
	_expect(int(lv3_fail_first.get("puppet_grab_phase", -1)) == int(lv3_fail_first.get("puppet_grab_phase_missing", -2)), "Lv.3 forced-fail retry roll should end in MISSING")
	for _i in range(5):
		lv3_fail_skill.update(0.1, lv3_fail_owner, lv3_fail_registry)
	var lv3_fail_done: Dictionary = lv3_fail_skill.get_snapshot()
	_expect(int(lv3_fail_done.get("puppet_grab_shot_count", -1)) == 1, "a failed retry roll must not be re-rolled across later MISS frames")
	_expect(lv3_fail_audio.puppet_grab_cast_count == 0, "failed retry roll should not play a retry cast sound")

	var lv3_success_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var lv3_success_owner := FakeOwner.new()
	var lv3_success_audio := FakePaddleAudio.new()
	var lv3_success_registry := FakeRegistry.new({"game_audio": lv3_success_audio})
	lv3_success_owner.boss_pos = Vector2(330.0, 25.0)
	_expect(bool(lv3_success_skill.launch(Vector2(380.0, 600.0), lv3_success_owner, {"active_skill_level": 3})), "Lv.3 success retry smoke should launch")
	lv3_success_skill.set_retry_roll_queue_for_tests([true])
	lv3_success_owner.boss_pos = Vector2(600.0, 25.0)
	var lv3_success_extend := float(lv3_success_skill.get_snapshot().get("puppet_grab_extend_seconds", 0.538))
	var lv3_retry_delay := float(lv3_success_skill.get_snapshot().get("puppet_grab_retry_delay_seconds", 0.5))
	lv3_success_skill.update(lv3_success_extend, lv3_success_owner, lv3_success_registry)
	var lv3_wait: Dictionary = lv3_success_skill.get_snapshot()
	_expect(int(lv3_wait.get("puppet_grab_phase", -1)) == int(lv3_wait.get("puppet_grab_phase_retry_wait", -2)), "Lv.3 successful retry roll should enter the retry wait phase")
	lv3_success_owner.boss_pos = Vector2(420.0, 25.0)
	lv3_success_skill.update(lv3_retry_delay - 0.01, lv3_success_owner, lv3_success_registry)
	_expect(int(lv3_success_skill.get_snapshot().get("puppet_grab_shot_count", -1)) == 1, "retry should wait the full 0.5s before firing")
	lv3_success_skill.update(0.02, lv3_success_owner, lv3_success_registry)
	var lv3_relaunched: Dictionary = lv3_success_skill.get_snapshot()
	_expect(int(lv3_relaunched.get("puppet_grab_phase", -1)) == 0, "Lv.3 retry should re-enter EXTENDING after the wait")
	_expect(int(lv3_relaunched.get("puppet_grab_shot_count", -1)) == 2, "Lv.3 successful retry should fire a second string shot")
	_expect(int(lv3_relaunched.get("puppet_grab_retry_count", -1)) == 1, "Lv.3 should count one retry launch")
	_expect(lv3_success_audio.puppet_grab_cast_count == 1, "retry launch should play the puppet cast SFX once")
	_expect(_vector2_distance(lv3_relaunched.get("puppet_grab_predicted_target", Vector2.ZERO), lv3_success_owner.boss_pos + Vector2(50.0, 20.0)) <= 0.01, "retry launch should snapshot the boss's current position, not reuse the stale MISS target")

	var lv3_hit_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var lv3_hit_owner := FakeOwner.new()
	var lv3_hit_audio := FakePaddleAudio.new()
	var lv3_hit_registry := FakeRegistry.new({"game_audio": lv3_hit_audio})
	lv3_hit_owner.boss_pos = Vector2(330.0, 25.0)
	_expect(bool(lv3_hit_skill.launch(Vector2(380.0, 600.0), lv3_hit_owner, {"active_skill_level": 3})), "Lv.3 retry-hit smoke should launch")
	lv3_hit_skill.set_retry_roll_queue_for_tests([true])
	var lv3_hit_extend := float(lv3_hit_skill.get_snapshot().get("puppet_grab_extend_seconds", 0.538))
	var lv3_hit_delay := float(lv3_hit_skill.get_snapshot().get("puppet_grab_retry_delay_seconds", 0.5))
	lv3_hit_owner.boss_pos = Vector2(600.0, 25.0)
	lv3_hit_skill.update(lv3_hit_extend, lv3_hit_owner, lv3_hit_registry)
	lv3_hit_owner.boss_pos = Vector2(420.0, 25.0)
	lv3_hit_skill.update(lv3_hit_delay, lv3_hit_owner, lv3_hit_registry)
	lv3_hit_skill.update(lv3_hit_extend, lv3_hit_owner, lv3_hit_registry)
	var lv3_hit_snap: Dictionary = lv3_hit_skill.get_snapshot()
	_expect(int(lv3_hit_snap.get("puppet_grab_phase", -1)) == 1, "a retry shot that catches the boss should enter PULLING normally")
	_expect(bool(lv3_hit_owner.lingpet_puppet_grab_active), "retry HIT should take boss ownership and freeze boss AI")
	_expect(lv3_hit_audio.puppet_grab_pull_count == 1, "retry HIT should play the pull sound exactly once")

	var lv5_chain_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var lv5_chain_owner := FakeOwner.new()
	var lv5_chain_audio := FakePaddleAudio.new()
	var lv5_chain_registry := FakeRegistry.new({"game_audio": lv5_chain_audio})
	lv5_chain_owner.boss_pos = Vector2(330.0, 25.0)
	_expect(bool(lv5_chain_skill.launch(Vector2(380.0, 600.0), lv5_chain_owner, {"active_skill_level": 5})), "Lv.5 chain retry smoke should launch")
	lv5_chain_skill.set_retry_roll_queue_for_tests([true, true])
	var lv5_extend := float(lv5_chain_skill.get_snapshot().get("puppet_grab_extend_seconds", 0.538))
	var lv5_delay := float(lv5_chain_skill.get_snapshot().get("puppet_grab_retry_delay_seconds", 0.5))
	lv5_chain_owner.boss_pos = Vector2(600.0, 25.0)
	lv5_chain_skill.update(lv5_extend, lv5_chain_owner, lv5_chain_registry)
	lv5_chain_skill.update(lv5_delay, lv5_chain_owner, lv5_chain_registry)
	lv5_chain_owner.boss_pos = Vector2(180.0, 25.0)
	lv5_chain_skill.update(lv5_extend, lv5_chain_owner, lv5_chain_registry)
	lv5_chain_skill.update(lv5_delay, lv5_chain_owner, lv5_chain_registry)
	lv5_chain_owner.boss_pos = Vector2(600.0, 25.0)
	lv5_chain_skill.update(lv5_extend, lv5_chain_owner, lv5_chain_registry)
	var lv5_chain_snap: Dictionary = lv5_chain_skill.get_snapshot()
	_expect(int(lv5_chain_snap.get("puppet_grab_shot_count", -1)) == 3, "Lv.5 with two successful retry gates should fire three total shots")
	_expect(int(lv5_chain_snap.get("puppet_grab_retry_count", -1)) == 2, "Lv.5 should count two retry launches when both retry gates succeed")
	_expect(int(lv5_chain_snap.get("puppet_grab_retries_remaining", -1)) == 0, "Lv.5 should have no retries left after two retry launches")
	_expect(int(lv5_chain_snap.get("puppet_grab_phase", -1)) == int(lv5_chain_snap.get("puppet_grab_phase_missing", -2)), "Lv.5 third MISS should end instead of retrying a third time")
	_expect(lv5_chain_audio.puppet_grab_cast_count == 2, "Lv.5 two retry launches should play two retry cast sounds")

	var lv5_stop_skill: Object = load("res://scripts/lingpet/lingpet_puppet_grab_skill.gd").new()
	var lv5_stop_owner := FakeOwner.new()
	var lv5_stop_audio := FakePaddleAudio.new()
	var lv5_stop_registry := FakeRegistry.new({"game_audio": lv5_stop_audio})
	lv5_stop_owner.boss_pos = Vector2(330.0, 25.0)
	_expect(bool(lv5_stop_skill.launch(Vector2(380.0, 600.0), lv5_stop_owner, {"active_skill_level": 5})), "Lv.5 fail-second retry smoke should launch")
	lv5_stop_skill.set_retry_roll_queue_for_tests([true, false])
	var lv5_stop_extend := float(lv5_stop_skill.get_snapshot().get("puppet_grab_extend_seconds", 0.538))
	var lv5_stop_delay := float(lv5_stop_skill.get_snapshot().get("puppet_grab_retry_delay_seconds", 0.5))
	lv5_stop_owner.boss_pos = Vector2(600.0, 25.0)
	lv5_stop_skill.update(lv5_stop_extend, lv5_stop_owner, lv5_stop_registry)
	lv5_stop_skill.update(lv5_stop_delay, lv5_stop_owner, lv5_stop_registry)
	lv5_stop_owner.boss_pos = Vector2(180.0, 25.0)
	lv5_stop_skill.update(lv5_stop_extend, lv5_stop_owner, lv5_stop_registry)
	var lv5_stop_snap: Dictionary = lv5_stop_skill.get_snapshot()
	_expect(int(lv5_stop_snap.get("puppet_grab_shot_count", -1)) == 2, "Lv.5 should stop at two shots when the second retry gate fails")
	_expect(int(lv5_stop_snap.get("puppet_grab_retry_count", -1)) == 1, "Lv.5 failed second gate should count only the first retry launch")
	_expect(int(lv5_stop_snap.get("puppet_grab_phase", -1)) == int(lv5_stop_snap.get("puppet_grab_phase_missing", -2)), "Lv.5 failed second gate should enter final MISSING")


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

	var nekuring_owner := FakeOwner.new()
	nekuring_owner.lingpet_owned_pet_ids = ["nekuring"]
	nekuring_owner.lingpet_slots = ["nekuring", "", ""]
	var nekuring_runtime: Object = LingpetEggRuntime.new()
	var nekuring_audio := FakePaddleAudio.new()
	var nekuring_registry := FakeRegistry.new({"game_audio": nekuring_audio})
	nekuring_runtime.update(0.0, nekuring_owner, nekuring_registry)
	nekuring_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(bool(nekuring_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0), nekuring_registry)), "Nekuring companion click reaction should start from the companion tap zone")
	_expect(nekuring_audio.lingpet_click_reaction_pet_ids == ["nekuring"], "Nekuring companion click reaction should request the pet-agnostic click voice hook once")

	ProjectResourceLoader.clear_caches()
	var onimaru_click_path := LingpetCatalog.get_visual_path("onimaru", "companion_click_reaction_anim")
	var onimaru_owner := FakeOwner.new()
	onimaru_owner.lingpet_owned_pet_ids = ["onimaru"]
	onimaru_owner.lingpet_slots = ["onimaru", "", ""]
	var onimaru_runtime: Object = LingpetEggRuntime.new()
	onimaru_runtime.update(0.0, onimaru_owner)
	onimaru_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(ProjectResourceLoader.get_cached_texture(onimaru_click_path) == null, "Onimaru click sheet should start cold for the first-click visibility guard")
	_expect(bool(onimaru_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0))), "Onimaru companion click reaction should start even when the click sheet was not prewarmed")
	_expect(ProjectResourceLoader.get_cached_texture(onimaru_click_path) != null, "Onimaru first companion click should synchronously secure the downscaled click Live2D sheet")

	ProjectResourceLoader.clear_caches()
	var rahoset_click_path := LingpetCatalog.get_visual_path("rahoset", "companion_click_reaction_anim")
	var rahoset_owner := FakeOwner.new()
	rahoset_owner.lingpet_owned_pet_ids = ["rahoset"]
	rahoset_owner.lingpet_slots = ["rahoset", "", ""]
	var rahoset_runtime: Object = LingpetEggRuntime.new()
	rahoset_runtime.update(0.0, rahoset_owner)
	rahoset_runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(ProjectResourceLoader.get_cached_texture(rahoset_click_path) == null, "Rahoset click sheet should start cold for the first-click visibility guard")
	_expect(bool(rahoset_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0))), "Rahoset companion click reaction should start even when the click sheet was not prewarmed")
	_expect(ProjectResourceLoader.get_cached_texture(rahoset_click_path) != null, "Rahoset first companion click should synchronously secure the downscaled click Live2D sheet")

	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var click_reaction_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
	var click_draw_size_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_click_reaction_draw_size_resolver.gd")
	var profile_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_profile.gd")
	var current_visual_prewarm_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_visual_prewarm_coordinator.gd")
	var visual_cache_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var lingpet_input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_interaction_input_router.gd")
	var body_presence_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
	_expect(runtime_source.find("lingpet_companion_click_reaction_state.gd") >= 0, "lingpet runtime should delegate click-reaction timing state")
	_expect(runtime_source.find("_draw_companion_click_reaction") < 0, "lingpet runtime should delegate click-reaction sheet drawing to the click-reaction module")
	_expect(click_reaction_source.find("PREWARM_VISUAL_KEYS") >= 0, "click-reaction module should own the focused visual prewarm keys")
	_expect(click_reaction_source.find("PANEL_VISUAL_KEY := \"click_reaction_anim\"") >= 0 and click_reaction_source.find("PREWARM_VISUAL_KEYS := [RUNTIME_VISUAL_KEY, PANEL_VISUAL_KEY]") >= 0, "post-hatch companion prewarm should include the character-info panel click Live2D sheet")
	_expect(click_reaction_source.find("can_start_at") >= 0 and click_reaction_source.find("CLICK_ZONE_HALF_WIDTH") >= 0, "click-reaction module should own the companion tap-zone math")
	_expect(click_reaction_source.find("draw_texture_rect_region") >= 0, "click-reaction module should own the popup sheet frame draw")
	_expect(click_reaction_source.find("DEFAULT_VIEW_HEIGHT := 82.0") >= 0, "click-reaction module should fall back to the same small size as the SD walk sprite")
	_expect(click_reaction_source.find("CENTER_OFFSET_Y := -6.0") >= 0, "click-reaction module should align to the SD walk sprite center instead of floating above it")
	_expect(click_reaction_source.find("RUNTIME_VISUAL_KEY := \"companion_click_reaction_anim\"") >= 0, "click-reaction module should use the downscaled in-battle visual key")
	_expect(click_reaction_source.find("REACTION_DURATION") >= 0 and click_reaction_source.find("FRAME_INTERVAL := 0.036") >= 0, "click-reaction module should keep the original fixed 98-frame playback timing")
	_expect(click_reaction_source.find("large popup") < 0, "click-reaction module should no longer describe or draw a large in-battle popup")
	_expect(profile_source.find("prewarm_visual_keys") >= 0, "lingpet current profile should support focused visual prewarm keys for large optional sheets")
	_expect(profile_source.find("get_cached_visual_texture") >= 0, "lingpet current profile should expose cached-only texture lookup for click-reaction draw frames")
	_expect(visual_cache_source.find("prewarm_pet_key_threaded_step") >= 0 and visual_cache_source.find("ProjectResourceLoader.prewarm_texture_threaded_step") >= 0, "lingpet visual cache should thread-prewarm large optional click-reaction sheets")
	_expect(runtime_source.find("func _queue_click_reaction_visual_prewarm") < 0, "lingpet runtime should not keep a single-use click-reaction visual prewarm queue wrapper")
	_expect(runtime_source.find("func _prewarm_click_reaction_visual_step") < 0, "lingpet runtime should not keep a single-use click-reaction visual prewarm step wrapper")
	_expect(current_visual_prewarm_source.find("_reaction_visual_prewarm_state.queue_if_companion") >= 0 or current_visual_prewarm_source.find("queue_if_companion") >= 0, "current visual prewarm coordinator should schedule click-reaction visual prewarm through the focused prewarm state")
	_expect(runtime_source.find("func _prewarm_current_visuals") < 0, "lingpet runtime should not keep a single-use current visual prewarm wrapper")
	_expect(runtime_source.find("_companion_click_reaction_visual_prewarm_state.prewarm_step") >= 0, "lingpet runtime should spread click-reaction visual prewarm over companion updates through the focused prewarm state")
	_expect(click_reaction_source.find("func get_ready_texture") >= 0 and click_reaction_source.find("get_cached_visual_texture") >= 0, "click-reaction module should own cached-first texture readiness lookup")
	_expect(runtime_source.find("_companion_click_reaction_state.get_ready_texture") >= 0, "lingpet runtime should ask the click-reaction owner for the ready texture")
	_expect(runtime_source.find("func _ensure_companion_click_reaction_texture_ready") < 0, "lingpet runtime should not keep a private click-reaction texture readiness wrapper")
	_expect(runtime_source.find("_get_current_cached_visual_texture(\"click_reaction_anim\", null)") < 0, "lingpet click-reaction draw should not use the full-size cut-in/result sheet key")
	_expect(runtime_source.find("_get_current_visual_texture(\"click_reaction_anim\", null)") < 0, "lingpet click-reaction draw should not synchronously load the large sheet")
	_expect(
		LingpetEggRuntime.CLICK_REACTION_TEXTURE_PREWARM_MAX_MSEC == 0
			and LingpetEggRuntime.CLICK_REACTION_TEXTURE_PREWARM_MAX_POLLS == 0,
		"lingpet live-rally click/panel prewarm should never demote an in-flight threaded texture to a synchronous main-thread fallback"
	)
	_expect(_lingpet_runtime_click_sheet_is_small("maribo"), "Maribo in-battle click-reaction sheet should be the downscaled companion sheet")
	_expect(_lingpet_runtime_click_sheet_is_small("lunabi"), "Lunabi in-battle click-reaction sheet should be the downscaled companion sheet")
	_expect(_lingpet_runtime_click_sheet_is_small("nekuring"), "Nekuring in-battle click-reaction sheet should be the downscaled companion sheet")
	_expect(runtime_source.find("func _get_companion_click_reaction_draw_size") < 0, "lingpet runtime should not reintroduce the single-use click-reaction draw-size wrapper")
	_expect(runtime_source.find("_companion_click_reaction_draw_size_resolver.resolve") >= 0, "lingpet runtime should size click-reaction Live2D through the focused resolver")
	_expect(click_draw_size_source.find("click_reaction_draw_size") >= 0 and click_draw_size_source.find("companion_walk_draw_size") >= 0, "lingpet draw-size resolver should support a per-pet click-reaction size override before falling back to SD walk draw size")
	_expect(runtime_source.find("if not click_reaction_visible") >= 0, "lingpet runtime should hide the base SD companion while the click-reaction Live2D is visible")
	_expect(body_presence_source.find("func is_click_reaction_visible") >= 0, "body-presence resolver should own click-reaction visibility gating")
	var body_draw_fn := _function_body(runtime_source, "func draw_lingpet_body_behind_actors")
	_expect(body_draw_fn.find("_companion_body_presence_resolver.is_click_reaction_visible") >= 0, "lingpet body draw should ask body-presence resolver for click-reaction visibility")
	_expect(body_draw_fn.find("_ring_dash_state.is_companion_visual_hidden") < 0, "lingpet body draw should not reassemble click-reaction visibility inline")
	_expect(input_source.find("BattleLingpetInteractionInputRouter") >= 0, "battle input should compose the focused lingpet interaction router")
	_expect(lingpet_input_source.find("try_begin_companion_click_reaction") >= 0, "lingpet input router should route playfield companion clicks to the lingpet runtime")
	_expect(lingpet_input_source.find("try_begin_companion_click_reaction(playfield_pos, registry)") >= 0, "lingpet input router should hand the registry to the click-reaction so the per-pet voice can play")
	_expect(runtime_source.find("func _play_click_reaction_audio") < 0, "lingpet runtime should not keep a single-use click-reaction audio wrapper")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_click_reaction") >= 0, "lingpet runtime should route click-reaction voice timing directly through the audio dispatcher")


func _verify_affinity_click_start_edge_and_visibility_gate() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var forced_click_pos := Vector2(250.0, 245.0)
	runtime.configure_companion_motion_for_tests(forced_click_pos, 2, 0.0, false)
	_expect(not bool(runtime.try_begin_companion_click_reaction(Vector2(40.0, 40.0))), "affinity click hook should ignore misses outside the companion tap zone")
	_expect_float(runtime.get_affinity_points("maribo"), 0.0, "missed companion clicks should not grant affinity")

	var click_pos: Vector2 = forced_click_pos
	_expect(bool(runtime.try_begin_companion_click_reaction(click_pos)), "first visible companion click should start the click reaction")
	_expect_float(runtime.get_affinity_points("maribo"), 20.0, "first start-edge click should grant affinity (20)")
	_expect(bool(runtime.try_begin_companion_click_reaction(click_pos)), "active companion click should still be consumed")
	_expect_float(runtime.get_affinity_points("maribo"), 20.0, "active click-reaction replay branch should not grant a second affinity award")

	runtime.update(5.0, owner)
	click_pos = owner.lingpet_companion_pos
	_expect(bool(runtime.try_begin_companion_click_reaction(click_pos)), "second visible start-edge click in the same round should be allowed")
	_expect_float(runtime.get_affinity_points("maribo"), 40.0, "second start-edge click should use the remaining round click budget (2x20)")
	runtime.update(5.0, owner)
	click_pos = owner.lingpet_companion_pos
	_expect(bool(runtime.try_begin_companion_click_reaction(click_pos)), "third same-round start edge should still consume the companion click")
	_expect_float(runtime.get_affinity_points("maribo"), 40.0, "third same-round start edge should be blocked by the affinity round cap")
	var capped_result: Dictionary = runtime.get_last_affinity_result_for_tests()
	_expect_str(str(capped_result.get("blocked_reason", "")), "round_cap", "third same-round click should report the affinity round cap")

	runtime.update(5.0, owner)
	runtime.reset_round({"owner": owner})
	click_pos = owner.lingpet_companion_pos
	_expect(bool(runtime.try_begin_companion_click_reaction(click_pos)), "new round should restore the click affinity round budget")
	# Cumulative would be 60 here, but that crosses the 50 level requirement, so assert the
	# fresh click GRANT (+20) rather than the level-up-sensitive banked residual.
	var new_round_click: Dictionary = runtime.get_last_affinity_result_for_tests()
	_expect_float(float(new_round_click.get("granted_points", 0.0)), 20.0, "new-round visible click should grant a fresh +20 once the round budget resets")

	var hidden_owner := FakeOwner.new()
	var hidden_runtime: Object = LingpetEggRuntime.new()
	_expect(hidden_runtime.debug_grant_and_activate_pet("lunabi", hidden_owner), "hidden click fixture should activate Lunabi")
	hidden_runtime.configure_companion_sortie_hidden_for_tests(Vector2(250.0, 245.0), 2, 8.0)
	_expect(bool(hidden_runtime.try_begin_companion_click_reaction(Vector2(250.0, 245.0))), "hidden sortie companion tap may still consume the click reaction")
	_expect_float(hidden_runtime.get_affinity_points("lunabi"), 0.0, "hidden sortie companion click should not grant affinity")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var body_presence_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
	_expect(runtime_source.find("func _can_grant_click_affinity") < 0, "runtime should not keep a single-use click-affinity visibility predicate wrapper")
	_expect(body_presence_source.find("func can_grant_click_affinity") >= 0, "body-presence resolver should own click-affinity visibility gating")
	var click_reaction_body := _function_body(runtime_source, "func try_begin_companion_click_reaction")
	_expect(click_reaction_body.find("_companion_body_presence_resolver.can_grant_click_affinity") >= 0, "runtime should gate click affinity through the body-presence resolver")
	_expect(click_reaction_body.find("_companion_motion_state.motion_visible") < 0 and click_reaction_body.find("_ring_dash_state.is_companion_visual_hidden") < 0, "click reaction should not reassemble click-affinity visibility inline")

	var dash_owner := FakeOwner.new()
	dash_owner.lingpet_ring_dash_force_roll_pct = 0.0
	var dash_runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new({})
	_expect(dash_runtime.debug_grant_and_activate_pet("maribo", dash_owner, false, "maribo_hydro_sphere", "lingpet_ring_dash", registry, 1, 5), "ring-dash hidden click fixture should equip Linkport")
	var start_pos: Vector2 = dash_owner.lingpet_companion_pos
	dash_runtime.configure_companion_motion_for_tests(Vector2(120.0, start_pos.y), 2, 0.0, false)
	dash_owner.player_pos = Vector2(240.0, dash_owner.player_pos.y)
	dash_owner.player_paddle_width = 170.0
	dash_owner.ball_active = true
	dash_owner.ball_pos = Vector2(640.0, dash_owner.player_pos.y - 40.0)
	dash_owner.ball_vel = Vector2(0.0, 12.0)
	dash_runtime.update(0.12, dash_owner, registry)
	_expect(bool(dash_runtime.is_ring_dash_visual_hidden_for_tests()), "ring-dash fixture should enter the visual-hidden beat")
	var before_hidden_click: float = dash_runtime.get_affinity_points("maribo")
	dash_runtime.try_begin_companion_click_reaction(dash_owner.lingpet_companion_pos, registry)
	_expect_float(dash_runtime.get_affinity_points("maribo"), before_hidden_click, "Ring Dash visual-hidden click should not grant affinity")


func _verify_companion_interact_key_reaction() -> void:
	# Non-mouse bond entry (E key / future pad button): the wrapper must
	# self-target _companion_pos so the click body is reused verbatim --
	# same reaction, same SOURCE_CLICK grant, same round cap, no new lever.
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	# Park the companion far from the origin: a broken self-target (passing
	# Vector2.ZERO instead of _companion_pos) would miss the tap zone here.
	runtime.configure_companion_motion_for_tests(Vector2(250.0, 245.0), 2, 0.0, false)
	_expect(bool(runtime.try_begin_companion_interact_reaction()), "interact key should start the reaction by self-targeting the companion position")
	_expect(bool(runtime.is_companion_click_reaction_active()), "interact-started reaction should report active")
	_expect_float(runtime.get_affinity_points("maribo"), 20.0, "interact start edge should grant the same SOURCE_CLICK affinity (+20)")
	_expect(bool(runtime.try_begin_companion_interact_reaction()), "interact during an active reaction should still be consumed (audio replay branch)")
	_expect_float(runtime.get_affinity_points("maribo"), 20.0, "interact replay branch should not double-grant affinity")

	runtime.update(5.0, owner)
	_expect(bool(runtime.try_begin_companion_interact_reaction()), "second interact start edge in the same round should be allowed")
	_expect_float(runtime.get_affinity_points("maribo"), 40.0, "second interact should consume the remaining round click budget (2x20)")
	runtime.update(5.0, owner)
	_expect(bool(runtime.try_begin_companion_interact_reaction()), "third same-round interact should still consume the reaction")
	_expect_float(runtime.get_affinity_points("maribo"), 40.0, "third same-round interact should be blocked by the shared SOURCE_CLICK round cap")
	var capped_interact: Dictionary = runtime.get_last_affinity_result_for_tests()
	_expect_str(str(capped_interact.get("blocked_reason", "")), "round_cap", "capped interact should report the same affinity round cap as clicks")

	var eggless_runtime: Object = LingpetEggRuntime.new()
	_expect(not bool(eggless_runtime.try_begin_companion_interact_reaction()), "interact without an accompanying companion should refuse (input falls through)")

	var hidden_owner := FakeOwner.new()
	var hidden_runtime: Object = LingpetEggRuntime.new()
	_expect(hidden_runtime.debug_grant_and_activate_pet("lunabi", hidden_owner), "hidden interact fixture should activate Lunabi")
	hidden_runtime.configure_companion_sortie_hidden_for_tests(Vector2(250.0, 245.0), 2, 8.0)
	_expect(bool(hidden_runtime.try_begin_companion_interact_reaction()), "hidden sortie interact may still consume the reaction")
	_expect_float(hidden_runtime.get_affinity_points("lunabi"), 0.0, "hidden sortie interact should inherit the body-presence affinity gate (no grant)")

	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var interact_body := _function_body(runtime_source, "func try_begin_companion_interact_reaction")
	_expect(interact_body.find("try_begin_companion_click_reaction(_companion_pos") >= 0, "interact wrapper should self-target _companion_pos through the click body instead of forking a second grant path")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var lingpet_input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_interaction_input_router.gd")
	_expect(input_source.find("BattleLingpetInteractionInputRouter") >= 0, "battle input should compose the focused lingpet interaction router")
	_expect(lingpet_input_source.find("LINGPET_INTERACT_KEY := KEY_E") >= 0, "lingpet input router should bind the non-mouse bond interact key to E")
	_expect(lingpet_input_source.find("try_begin_companion_interact_reaction(registry)") >= 0, "lingpet input router should hand the registry to the interact wrapper so the per-pet voice can play")


func _verify_ring_core_upgrade_grants_affinity_to_all_owned_pets() -> void:
	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo", "lunabi"]  # lunabi is NEVER a companion this run
	owner.lingpet_slots = ["maribo", "", ""]
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner), "ring-core grant fixture should activate Maribo")
	_expect_eq(runtime.get_affinity_level("maribo"), 0, "fixture should start the active pet at affinity Lv0")
	_expect_eq(runtime.get_affinity_level("lunabi"), 0, "never-engaged owned pet should start at Lv0")

	# Tier 0 -> 1 (cap 5). Every OWNED pet must receive the flat +50 (= Lv1), incl. lunabi, which
	# has never been a companion this run (its context is built from the catalog on first grant).
	var result: Dictionary = runtime.upgrade_run_ring_core_tier(1, owner, registry)
	_expect(bool(result.get("accepted", false)), "ring-core tier 0->1 upgrade should be accepted")
	_expect_eq(int(result.get("affinity_granted_pets", 0)), 2, "ring-core upgrade should grant affinity to both owned pets")
	_expect_eq(runtime.get_affinity_level("maribo"), 1, "active owned pet should gain ~1 level from the +50 ring-core grant")
	_expect_eq(runtime.get_affinity_level("lunabi"), 1, "never-engaged owned pet should also receive the +50 ring-core grant")

	# Per-upgrade (not once-per-run): a second tier rise pays another +50 to the whole roster.
	var second: Dictionary = runtime.upgrade_run_ring_core_tier(2, owner, registry)
	_expect(bool(second.get("accepted", false)), "second ring-core upgrade should be accepted")
	_expect_eq(runtime.get_affinity_level("maribo"), 2, "a second ring-core upgrade should grant another +50 (per-upgrade)")
	_expect_eq(runtime.get_affinity_level("lunabi"), 2, "a second ring-core upgrade should also re-grant the never-engaged pet")

	# Chip-exempt: 5 enhancement chips keep the grant a flat +50 (Lv1), not +100 (Lv2).
	var chip_owner := FakeOwner.new()
	chip_owner.lingpet_owned_pet_ids = ["maribo"]
	chip_owner.lingpet_slots = ["maribo", "", ""]
	var chip_runtime: Object = LingpetEggRuntime.new()
	_expect(chip_runtime.debug_grant_and_activate_pet("maribo", chip_owner), "chip-exempt fixture should activate Maribo")
	for _i in range(5):
		chip_runtime._affinity_state.add_enhancement_chip()
	chip_runtime.upgrade_run_ring_core_tier(1, chip_owner, registry)
	_expect_eq(chip_runtime.get_affinity_level("maribo"), 1, "ring-core +50 grant should be chip-exempt (flat 50 = Lv1, not 100 = Lv2)")


func _verify_affinity_score_event_and_battle_reset() -> void:
	var inactive_runtime: Object = LingpetEggRuntime.new()
	inactive_runtime.handle_score_event("player", {"match_finished": true}, {})
	_expect(inactive_runtime.get_affinity_tracked_pet_ids_for_tests().is_empty(), "score events should not create affinity entries before a pet is actively accompanying the player")

	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner), "score-event fixture should activate Maribo")
	runtime.handle_score_event("boss", {"match_finished": false}, {})
	_expect_float(runtime.get_affinity_points("maribo"), 0.0, "a lost point must not pay the round-commit award (2026-06-12 design: player-scored commits only)")
	runtime.handle_score_event("player", {"match_finished": false}, {})
	_expect_float(runtime.get_affinity_points("maribo"), 5.0, "a player-scored commit should pay one +5 round award")
	runtime.handle_score_event("player", {"match_finished": true}, {})
	# Match finish pays round-completion (+5), victory (+20) and stage clear (+50) = +75, but this
	# fixture runs at ring-core tier 0 (cap 0), so banked points clamp at the 50 next-level
	# requirement. The duplicate self-seal checks below are the real proof both bonuses were paid.
	_expect_float(runtime.get_affinity_points("maribo"), 50.0, "player match finish income (5+20+50) clamps to the 50 cap-0 next-level requirement")
	var duplicate_victory: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_VICTORY)
	_expect_float(float(duplicate_victory.get("granted_points", 0.0)), 0.0, "victory payout should self-seal inside one battle")
	_expect_str(str(duplicate_victory.get("blocked_reason", "")), "victory_already_paid", "duplicate victory should report the battle seal")
	var duplicate_stage_clear: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_STAGE_CLEAR)
	_expect_float(float(duplicate_stage_clear.get("granted_points", 0.0)), 0.0, "match finish should already have paid stage clear once, so a second is self-sealed")
	_expect_str(str(duplicate_stage_clear.get("blocked_reason", "")), "stage_clear_already_paid", "duplicate stage clear should report the battle seal")

	runtime.reset_affinity_for_new_battle()
	var first_hatch: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(first_hatch.get("granted_points", 0.0)), 25.0, "battle reset should not prevent the first run hatch bonus for a pet")
	runtime.reset_affinity_for_new_battle()
	var duplicate_hatch: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(duplicate_hatch.get("granted_points", 0.0)), 0.0, "battle reset should preserve the once-per-run hatch bonus gate")
	_expect_str(str(duplicate_hatch.get("blocked_reason", "")), "hatch_bonus_granted", "post-battle duplicate hatch should still report the hatch gate")

	for _i in range(5):
		var click_result: Dictionary = runtime.debug_add_affinity_points_for_tests("koyora", LingpetAffinityState.SOURCE_CLICK)
		_expect_float(float(click_result.get("granted_points", 0.0)), 20.0, "click battle-cap setup should grant each of the five battle clicks (20)")
		runtime.reset_round({"owner": owner})
	var capped_click: Dictionary = runtime.debug_add_affinity_points_for_tests("koyora", LingpetAffinityState.SOURCE_CLICK)
	_expect_float(float(capped_click.get("granted_points", 0.0)), 0.0, "sixth click in one battle should be blocked before battle reset")
	_expect_str(str(capped_click.get("blocked_reason", "")), "battle_cap", "sixth click should report the battle cap")
	runtime.reset_affinity_for_new_battle()
	var reloaded_click: Dictionary = runtime.debug_add_affinity_points_for_tests("koyora", LingpetAffinityState.SOURCE_CLICK)
	_expect_float(float(reloaded_click.get("granted_points", 0.0)), 20.0, "new-battle reset should reload click battle budget (20)")

	runtime.reset_affinity_for_new_battle()
	runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	runtime.debug_add_affinity_points_for_tests("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	runtime.debug_add_affinity_points_for_tests("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var blocked_win: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_VICTORY)
	_expect_float(float(blocked_win.get("granted_points", 0.0)), 0.0, "pre-reset attendance ledger should block a below-half victory")
	_expect_str(str(blocked_win.get("blocked_reason", "")), "ineligible", "below-half victory should report ineligible before battle reset")
	runtime.reset_affinity_for_new_battle()
	runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var reset_win: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_VICTORY)
	_expect_float(float(reset_win.get("granted_points", 0.0)), 20.0, "new-battle reset should clear the attendance ledger and allow a fresh eligible victory")

	var defeat_registry := FakeRegistry.new({})
	var defeat_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(defeat_runtime)
	_expect(defeat_runtime.debug_grant_and_activate_pet("maribo", FakeOwner.new()), "bond defeat fixture should activate Maribo")
	_grant_affinity_round_commits(defeat_runtime, "maribo", 10)
	defeat_runtime.handle_score_event("boss", {"match_finished": true}, {"registry": defeat_registry})
	var defeat_settlement: Dictionary = defeat_runtime.get_last_affinity_bond_settlement_for_tests()
	_expect_eq(int((defeat_settlement.get("discarded", {}) as Dictionary).get("maribo", 0)), 1, "boss match-finish should discard pending bond level-ups")

	var short_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(short_runtime)
	_expect(short_runtime.debug_grant_and_activate_pet("maribo", FakeOwner.new()), "bond short-run fixture should activate Maribo")
	_grant_affinity_round_commits(short_runtime, "maribo", 10)
	short_runtime.reset_affinity_for_new_battle()
	_expect(short_runtime.get_last_affinity_bond_settlement_for_tests().is_empty(), "short run reset should not produce a bond settlement")

	var gated_registry := FakeRegistry.new({})
	var gated_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(gated_runtime)
	var gated_owner := FakeOwner.new()
	_expect(gated_runtime.debug_grant_and_activate_pet("maribo", gated_owner), "bond 50-percent fixture should activate Maribo")
	_grant_affinity_round_commits(gated_runtime, "maribo", 10)
	_expect(gated_runtime.debug_grant_and_activate_pet("lunabi", gated_owner), "bond 50-percent fixture should switch to Lunabi")
	_grant_affinity_round_commits(gated_runtime, "lunabi", 11)
	gated_runtime.handle_score_event("player", {"match_finished": true}, {"registry": gated_registry})
	var gated_settlement: Dictionary = gated_runtime.get_last_affinity_bond_settlement_for_tests()
	_expect_eq(int((gated_settlement.get("discarded", {}) as Dictionary).get("maribo", 0)), 1, "below-50-percent pending pet should not settle bond levels")
	# lunabi: 11 commits -> Lv1, then the match-finish income (round +5, victory +20, stage clear +50)
	# crosses a second 50 boundary -> Lv2, so it settles 2 bond level-ups (1 commit + 1 finish burst).
	_expect_eq(int((gated_settlement.get("settled", {}) as Dictionary).get("lunabi", 0)), 2, "eligible active pet settles its pending bond levels incl. the match-finish burst (run-state, not store)")

	var swap_registry := FakeRegistry.new({})
	var swap_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(swap_runtime)
	var swap_owner := FakeOwner.new()
	_expect(swap_runtime.debug_grant_and_activate_pet("maribo", swap_owner), "bond swap fixture should activate Maribo")
	_grant_affinity_round_commits(swap_runtime, "maribo", 11)
	_expect(swap_runtime.debug_grant_and_activate_pet("lunabi", swap_owner), "bond swap fixture should switch to Lunabi")
	_grant_affinity_round_commits(swap_runtime, "lunabi", 10)
	swap_runtime.handle_score_event("player", {"match_finished": true}, {"registry": swap_registry})
	var swap_settlement: Dictionary = swap_runtime.get_last_affinity_bond_settlement_for_tests()
	_expect_eq(int((swap_settlement.get("settled", {}) as Dictionary).get("maribo", 0)), 1, "inactive swapped pet with 50-percent attendance should settle its own pending bond level")
	# lunabi: 10 commits -> Lv1, then the match-finish income burst (+75) crosses a second boundary -> Lv2.
	_expect_eq(int((swap_settlement.get("settled", {}) as Dictionary).get("lunabi", 0)), 2, "final active pet settles its own eligible pending bond levels incl. the match-finish burst (run-state)")


func _verify_affinity_reward_application() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var affinity_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_context_coordinator.gd")
	_expect(runtime_source.find("func _handle_affinity_level_gain") < 0, "egg runtime should not keep a private affinity level-gain callback helper")
	_expect(runtime_source.find("Callable(_affinity_context_coordinator, \"handle_level_gain\")") >= 0, "affinity level-up callback should route through the affinity context coordinator")
	_expect(affinity_context_source.find("func handle_level_gain") >= 0 and affinity_context_source.find("invalidate_runtime_cache") >= 0 and affinity_context_source.find("invalidate_sync_cache") >= 0, "affinity context coordinator should own level-gain profile sync and cache invalidation")

	var profile := LingpetCurrentProfile.new()
	profile.set_pet_id("maribo")
	profile.set_loadout("maribo_hydro_sphere", "lingpet_ring_dash", 1, 1)
	var profile_rewards := LingpetAffinityState.get_empty_reward_counts()
	profile_rewards["active_skill_bonus"] = 1
	profile_rewards["passive_skill_bonus"] = 1
	profile_rewards["signature"] = "1|1|0|0|0|0"
	profile.set_affinity_state(2, profile_rewards)
	_expect_eq(int(profile.get_active_skill().get("level", 0)), 2, "profile should synthesize active skill level from base loadout plus affinity reward")
	var profile_passive: Dictionary = profile.get_passive_skill()
	_expect_eq(int(profile_passive.get("level", 0)), 2, "profile should synthesize passive skill level from base loadout plus affinity reward")
	_expect_float(float(profile_passive.get("ring_dash_chance_pct", 0.0)), 32.5, "profile flattened passive values should use the synthesized passive level")

	var run_seed_a: Object = LingpetEggRuntime.new()
	run_seed_a.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_HATCH)
	var run_seed_b: Object = LingpetEggRuntime.new()
	run_seed_b.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_HATCH)
	var seed_a := int(run_seed_a.get_affinity_data("maribo").get("reward_seed", 0))
	var seed_b := int(run_seed_b.get_affinity_data("maribo").get("reward_seed", 0))
	_expect(seed_a > 0 and seed_b > 0, "runtime should generate and store a run-local reward seed")
	_expect(seed_a != seed_b, "separate runtime instances should not reuse the same default reward deck seed for a pet")
	var sticky_deck := _deck_type_sequence(run_seed_a.get_affinity_reward_deck_for_tests("maribo"))
	run_seed_a.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_BALL_HIT)
	_expect_str(_deck_type_sequence(run_seed_a.get_affinity_reward_deck_for_tests("maribo")), sticky_deck, "runtime reward seed should be sticky after first configure")
	var injected_seed_a: Object = LingpetEggRuntime.new()
	injected_seed_a.set_affinity_reward_seed_for_tests("maribo", 777)
	var injected_seed_b: Object = LingpetEggRuntime.new()
	injected_seed_b.set_affinity_reward_seed_for_tests("maribo", 778)
	_expect(_deck_type_sequence(injected_seed_a.get_affinity_reward_deck_for_tests("maribo")) != _deck_type_sequence(injected_seed_b.get_affinity_reward_deck_for_tests("maribo")), "runtime seed injection should affect deck order")
	var bench_flight: Object = LingpetEggRuntime.new()
	bench_flight.set_affinity_reward_seed_for_tests("rabi", 777)
	bench_flight.debug_add_affinity_points_for_tests("rabi", LingpetAffinityState.SOURCE_HATCH)
	_expect_eq(_deck_type_count(bench_flight.get_affinity_reward_deck_for_tests("rabi"), LingpetAffinityState.REWARD_TYPE_DEFENSE), 0, "bench flight pets should use their catalog-profile flight deck, not the patrol fallback")

	# R3 / v5: the store-headstart "high base" reward scenario (previous best ->
	# floor(best/3) headstart) was removed. No-headstart is sealed by
	# _verify_affinity_store_v5_meta_only; the reward dealer's deck composition is
	# covered by the run-state cases above.

	var skill_owner := FakeOwner.new()
	skill_owner.lingpet_owned_pet_ids = ["maribo"]
	skill_owner.lingpet_slots = ["maribo", "", ""]
	var skill_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(skill_runtime)
	var skill_registry := FakeRegistry.new({})
	skill_runtime.set_affinity_reward_seed_for_tests("maribo", 4)
	_expect(skill_runtime.debug_grant_and_activate_pet("maribo", skill_owner, false, "maribo_hydro_sphere", "lingpet_ring_dash", skill_registry, 1, 1), "skill synthesis fixture should activate Maribo with base Lv.1 skills")
	var before_skill_snapshot: Dictionary = skill_runtime.get_snapshot()
	_expect_eq(int(before_skill_snapshot.get("active_skill_level", 0)), 1, "base loadout should start active skill at Lv.1 before affinity rewards")
	_expect_eq(int(before_skill_snapshot.get("companion_passive_skill_level", 0)), 1, "base loadout should start passive skill at Lv.1 before affinity rewards")
	_grant_affinity_round_commits(skill_runtime, "maribo", 20)
	skill_runtime.update(0.0, skill_owner, skill_registry)
	var after_skill_snapshot: Dictionary = skill_runtime.get_snapshot()
	_expect_eq(skill_runtime.get_affinity_level("maribo"), 2, "20 committed rounds should reach affinity Lv.2 for the synthesis fixture")
	_expect_eq(int(after_skill_snapshot.get("affinity_level", 0)), 2, "runtime snapshot should expose the current affinity level for the TAB panel")
	_expect_float(float(skill_owner.lingpet_affinity_points), 0.0, "owner sync should expose post-level-up affinity points")
	_expect_float(float(skill_owner.lingpet_affinity_next_requirement), 50.0, "owner sync should expose the next affinity requirement")
	_expect(str(skill_owner.lingpet_affinity_next_label) != "", "owner sync should expose the next affinity reward label")
	_expect_eq(int(after_skill_snapshot.get("active_skill_level", 0)), 1, "V3 Lv.1 active unlock should not add an active skill level")
	_expect_eq(int(after_skill_snapshot.get("companion_passive_skill_level", 0)), 1, "V3 Lv.2 passive unlock should not add a passive skill level")
	_grant_affinity_round_commits(skill_runtime, "maribo", 20)
	skill_runtime.update(0.0, skill_owner, skill_registry)
	var pre_plus_one_snapshot: Dictionary = skill_runtime.get_snapshot()
	_expect_eq(skill_runtime.get_affinity_level("maribo"), 4, "40 committed rounds should reach affinity Lv.4 before the first skill +1 card")
	_expect_eq(int(pre_plus_one_snapshot.get("active_skill_level", 0)), 1, "V3 Lv.4 should still keep the active skill at base Lv.1")
	_expect_eq(int(pre_plus_one_snapshot.get("companion_passive_skill_level", 0)), 1, "V3 Lv.4 should still keep the passive skill at base Lv.1")
	_grant_affinity_round_commits(skill_runtime, "maribo", 10)
	skill_runtime.update(0.0, skill_owner, skill_registry)
	var first_plus_one_snapshot: Dictionary = skill_runtime.get_snapshot()
	var first_plus_rewards: Dictionary = skill_runtime.get_affinity_rewards_for_tests("maribo")
	_expect_eq(skill_runtime.get_affinity_level("maribo"), 5, "50 committed rounds should reach affinity Lv.5 for the first active +1 card")
	_expect_eq(int(first_plus_rewards.get("active_skill_bonus", 0)), 1, "V3 Lv.5 should be the first active skill +1 reward for this seed")
	_expect_eq(int(first_plus_one_snapshot.get("active_skill_level", 0)), 2, "V3 Lv.5 active +1 should synthesize active skill Lv.2")
	_expect_eq(int(first_plus_one_snapshot.get("companion_passive_skill_level", 0)), 1, "V3 Lv.5 should not add a passive skill level yet")

	var base_defense_owner := FakeOwner.new()
	base_defense_owner.lingpet_owned_pet_ids = ["maribo"]
	var base_defense_runtime: Object = LingpetEggRuntime.new()
	base_defense_runtime.update(0.0, base_defense_owner)
	var base_start: Vector2 = base_defense_owner.lingpet_companion_pos
	base_defense_runtime.configure_companion_motion_for_tests(Vector2(570.0, base_start.y), 5, 0.0, false)
	base_defense_owner.ball_active = true
	base_defense_owner.ball_pos = Vector2(650.0, base_start.y - 300.0)
	base_defense_owner.ball_vel = Vector2(0.0, 12.0)
	base_defense_runtime.update(0.05, base_defense_owner)
	_expect(not bool(base_defense_owner.lingpet_companion_defense_intercept_active), "seed 5 defense roll should fail at base Maribo defense rate 0.30")

	var boosted_owner := FakeOwner.new()
	boosted_owner.lingpet_owned_pet_ids = ["maribo"]
	var boosted_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(boosted_runtime)
	var boosted_registry := FakeRegistry.new({})
	boosted_runtime.set_affinity_reward_seed_for_tests("maribo", 4)
	boosted_runtime.update(0.0, boosted_owner, boosted_registry)
	_grant_affinity_round_commits(boosted_runtime, "maribo", 120)
	boosted_runtime.update(0.0, boosted_owner, boosted_registry)
	var boosted_snapshot: Dictionary = boosted_runtime.get_snapshot()
	_expect_eq(boosted_runtime.get_affinity_level("maribo"), 12, "120 committed rounds should reach affinity Lv.12 on the flat-50 requirement curve")
	var boosted_rewards: Dictionary = boosted_runtime.get_affinity_rewards_for_tests("maribo")
	_expect_eq(int(boosted_rewards.get("active_skill_bonus", 0)), 2, "V3 Lv.12 fixture should have two active skill +1 rewards")
	_expect_eq(int(boosted_rewards.get("passive_skill_bonus", 0)), 2, "V3 Lv.12 fixture should have two passive skill +1 rewards")
	_expect_eq(int(boosted_snapshot.get("active_skill_level", 0)), 3, "V3 Lv.12 should synthesize active skill Lv.3 from base Lv.1 plus two bonuses")
	_expect_eq(int(boosted_snapshot.get("companion_passive_skill_level", 0)), 3, "V3 Lv.12 should synthesize passive skill Lv.3 from base Lv.1 plus two bonuses")
	_expect_eq(int(boosted_rewards.get("defense_stacks", 0)), 2, "V3 Lv.12 patrol fixture should keep both defense cards")
	_expect_eq(int(boosted_rewards.get("gauge_stacks", 0)), 2, "V3 Lv.12 patrol fixture should keep both gauge cards")
	_expect_eq(int(boosted_rewards.get("mobility_stacks", 0)), 4, "V3 Lv.12 patrol fixture should keep all four mobility cards from the current seeded deck")
	_prepare_maribo_guard_after_windup(boosted_runtime, boosted_owner, boosted_registry)
	var lane_y: float = boosted_owner.lingpet_companion_pos.y
	boosted_runtime.configure_companion_motion_for_tests(Vector2(570.0, lane_y), 5, 0.0, false)
	var step_delta := 0.05
	var ball_vy := 12.0
	var step_drop := ball_vy * step_delta * 60.0
	var ball_y: float = lane_y - 300.0
	boosted_owner.ball_active = true
	boosted_owner.ball_pos = Vector2(650.0, ball_y)
	boosted_owner.ball_vel = Vector2(0.0, ball_vy)
	boosted_runtime.update(step_delta, boosted_owner, boosted_registry)
	_expect(bool(boosted_owner.lingpet_companion_defense_intercept_active), "affinity-boosted defense should pass the seed 5 roll and arm")
	ball_y += step_drop
	var boosted_blocked := false
	for _i in range(20):
		boosted_owner.ball_pos = Vector2(650.0, ball_y)
		boosted_owner.ball_vel = Vector2(0.0, ball_vy)
		boosted_runtime.update(step_delta, boosted_owner, boosted_registry)
		if int(boosted_owner.lingpet_companion_contact_count) >= 1:
			boosted_blocked = true
			break
		ball_y += step_drop
	_expect(boosted_blocked, "affinity-boosted defense should actually intercept and bounce the reachable ball")
	_expect(float(boosted_owner.ball_vel.y) < 0.0, "affinity-boosted defense should bounce the ball upward")

	var far_owner := FakeOwner.new()
	far_owner.lingpet_owned_pet_ids = ["maribo"]
	var far_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(far_runtime)
	far_runtime.set_affinity_reward_seed_for_tests("maribo", 78912611)
	far_runtime.update(0.0, far_owner)
	_grant_affinity_round_commits(far_runtime, "maribo", 245)
	far_runtime.update(0.0, far_owner)
	var far_start: Vector2 = far_owner.lingpet_companion_pos
	far_runtime.configure_companion_motion_for_tests(Vector2(120.0, far_start.y), 5, 0.0, false)
	far_owner.ball_active = true
	far_owner.ball_pos = Vector2(700.0, far_start.y - 150.0)
	far_owner.ball_vel = Vector2(0.0, 12.0)
	far_runtime.update(0.05, far_owner)
	_expect(not bool(far_owner.lingpet_companion_defense_intercept_active), "affinity defense boost should not bypass the far-ball local-zone gate")

	var flight_owner := FakeOwner.new()
	flight_owner.lingpet_owned_pet_ids = ["rabi"]
	flight_owner.lingpet_slots = ["rabi", "", ""]
	var flight_runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(flight_runtime)
	var flight_registry := FakeRegistry.new({})
	flight_runtime.set_affinity_reward_seed_for_tests("rabi", 305686070)
	_expect(flight_runtime.debug_grant_and_activate_pet("rabi", flight_owner, false, "rabi_soul_clone", "lingpet_resonance_boost", flight_registry, 1, 1), "flight reward fixture should activate Rabi")
	var base_flight_snapshot: Dictionary = flight_runtime.get_snapshot()
	var base_appearance_rate: float = float(base_flight_snapshot.get("companion_appearance_rate", 0.0))
	_grant_affinity_round_commits(flight_runtime, "rabi", 70)
	flight_runtime.update(0.0, flight_owner, flight_registry)
	var mobility_flight_snapshot: Dictionary = flight_runtime.get_snapshot()
	var boosted_appearance_rate: float = float(mobility_flight_snapshot.get("companion_appearance_rate", 0.0))
	_expect_float(boosted_appearance_rate, base_appearance_rate + 0.10, "flight mobility rewards should raise appearance rate by 10 percentage points")
	var base_hidden: float = float(_measure_ghost_hidden_wait(base_appearance_rate).get("hidden", 0.0))
	var boosted_hidden: float = float(_measure_ghost_hidden_wait(boosted_appearance_rate).get("hidden", 0.0))
	_expect(boosted_hidden < base_hidden, "flight mobility reward should measurably shorten hidden wait")
	_grant_affinity_round_commits(flight_runtime, "rabi", 30)
	flight_runtime.update(0.0, flight_owner, flight_registry)
	var support_flight_snapshot: Dictionary = flight_runtime.get_snapshot()
	_expect_eq(flight_runtime.get_affinity_level("rabi"), 10, "100 committed rounds should reach affinity Lv.10 on the flat-50 requirement curve")
	_expect_float(float(support_flight_snapshot.get("companion_defense_rate", -1.0)), 0.0, "flight support reward should not create a dead defense-rate stat")
	var support_flight_rewards: Dictionary = flight_runtime.get_affinity_rewards_for_tests("rabi")
	_expect_eq(int(support_flight_rewards.get("active_skill_bonus", 0)), 2, "V3 Lv.10 flight fixture should have two active skill +1 rewards")
	_expect_eq(int(support_flight_rewards.get("passive_skill_bonus", 0)), 1, "V3 Lv.10 flight fixture should have one passive skill +1 reward")
	_expect_eq(int(support_flight_snapshot.get("active_skill_level", 0)), 3, "V3 Lv.10 flight fixture should synthesize active skill Lv.3")
	_expect_eq(int(support_flight_snapshot.get("companion_passive_skill_level", 0)), 2, "V3 Lv.10 flight fixture should synthesize passive skill Lv.2")
	_expect_eq(int(support_flight_rewards.get("gauge_stacks", 0)), 4, "V3 Lv.10 flight fixture should count four gauge cards from the current seeded deck")
	_expect_float(float(support_flight_snapshot.get("companion_appearance_rate", 0.0)), base_appearance_rate + 0.15, "V3 Lv.10 flight fixture should synthesize three mobility cards into appearance rate")
	_expect_float(float(support_flight_snapshot.get("companion_hit_gauge_gain", 0.0)), 60.0, "V3 Lv.10 flight fixture should synthesize four gauge cards into hit gauge gain")


func _verify_second_active_slot_runtime_foundation() -> void:
	var active_slot_resolver := LingpetActiveSkillSlotResolver.new()
	var owner := FakeOwner.new()
	owner.ball_active = true
	owner.ball_pos = Vector2(380.0, 260.0)
	owner.ball_vel = Vector2(0.0, -12.0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(runtime)
	runtime.set_affinity_reward_seed_for_tests("red_dragon", 1)
	_expect(
		runtime.debug_grant_and_activate_pet("red_dragon", owner, false, "", "", registry, 1, 1),
		"second-active fixture should activate Red Dragon without a debug-forced loadout"
	)
	runtime._loadout_state.set_pet_loadout_and_invalidate(
		owner,
		"red_dragon",
		"red_dragon_dragon_breath",
		"",
		1,
		1,
		runtime._snapshot_builder,
		"red_dragon_dragon_wing",
		"",
		1,
		1
	)
	runtime.update(0.0, owner, registry)
	_expect_eq(active_slot_resolver.get_active_slot_count(runtime._current_profile, runtime._skill_runtime_host), 1, "slot 1 should stay runtime-locked before second_active_unlocked")
	runtime.configure_companion_motion_for_tests(Vector2(380.0, 260.0), 7, 0.0, true)
	runtime.update(0.05, owner, registry)
	var locked_slot_state: Object = _skill_state_for_runtime_slot(runtime, 1)
	_expect(not bool(locked_slot_state.windup_active), "locked slot 1 should not arm even when a second active id exists")
	_expect_float(float(locked_slot_state.cooldown), 0.0, "locked slot 1 should not spend cooldown")

	runtime.reset_round({"owner": owner, "registry": registry})
	_grant_affinity_round_commits_until_reward(runtime, "red_dragon", "second_active_unlocked", 300)
	runtime.update(0.0, owner, registry)
	# The second-active unlock is now granted by a per-level probability roll once the
	# combined skill-level prerequisite is met, so its level is no longer pinned -- only
	# bounded by the run (1..MAX). The reward FLAG landing is what enables slot 1 below.
	_expect(
		runtime.get_affinity_level("red_dragon") >= 1 and runtime.get_affinity_level("red_dragon") <= LingpetAffinityState.MAX_LEVEL,
		"second-active fixture should roll the unlock within the run"
	)
	var rewards: Dictionary = runtime.get_affinity_rewards_for_tests("red_dragon")
	_expect(bool(rewards.get("second_active_unlocked", false)), "shuffled reward deck should record the second-active unlock flag")
	var loadout: Dictionary = runtime._loadout_state.get_loadout("red_dragon")
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 2, "V3-2c reconcile should write a real slot-1 active id")
	_expect(str(loadout.get("second_active_skill_id", "")) != "", "V3-2c reconcile should persist the resolved second active id")
	_expect(str(owner.lingpet_second_active_skill_id) != "", "owner second active key should expose the reconciled slot-1 id")
	_expect_eq(active_slot_resolver.get_active_slot_count(runtime._current_profile, runtime._skill_runtime_host), 2, "second unlock flag with a slot-1 id should enable two active slots")
	_expect(active_slot_resolver.get_skill_id_for_slot(runtime._current_profile, 1) != "", "slot 1 should resolve a real skill id after V3-2c reconcile")
	_expect(runtime._skill_runtime_host._dragon_breath_skill != null, "slot 0 skill runtime should prewarm at loadout apply")
	_expect(runtime._skill_runtime_host._dragon_wing_skill != null, "V3-2c should prewarm the reconciled second active runtime")

	runtime.configure_companion_motion_for_tests(Vector2(380.0, 260.0), 7, 0.0, true)
	runtime.update(0.05, owner, registry)
	var slot0_state: Object = _skill_state_for_runtime_slot(runtime, 0)
	var slot1_state: Object = _skill_state_for_runtime_slot(runtime, 1)
	_expect(bool(slot0_state.windup_active), "slot 0 FREE skill should arm its own windup")
	_expect(bool(slot1_state.windup_active), "slot 1 should arm its own windup after V3-2c reconcile")
	_expect_float(float(slot0_state.cooldown), 0.0, "slot 0 windup should not spend slot 0 cooldown before launch")
	_expect_float(float(slot1_state.cooldown), 0.0, "slot 1 windup should not spend slot 1 cooldown before launch")

	var same_kind_runtime: Object = LingpetEggRuntime.new()
	var same_kind_owner := FakeOwner.new()
	same_kind_owner.ball_active = true
	same_kind_owner.ball_pos = Vector2(380.0, 260.0)
	same_kind_owner.ball_vel = Vector2(0.0, -12.0)
	_expect(
		same_kind_runtime.debug_grant_and_activate_pet("red_dragon", same_kind_owner, false, "red_dragon_dragon_breath", "", registry, 1, 1),
		"same-kind fixture should activate Red Dragon"
	)
	_expect(
		bool(same_kind_runtime._skill_runtime_host.would_share_module("red_dragon_dragon_breath", "red_dragon_dragon_breath")),
		"would_share_module should identify same-kind active skills"
	)
	_expect(
		not bool(same_kind_runtime._skill_runtime_host.would_share_module("red_dragon_dragon_breath", "red_dragon_dragon_wing")),
		"would_share_module should allow different runtime kinds"
	)
	var same_kind_rewards := LingpetAffinityState.get_empty_reward_counts()
	same_kind_rewards["second_active_unlocked"] = true
	same_kind_rewards["signature"] = "same-kind-second-active"
	var same_kind_active_ids: Array[String] = ["red_dragon_dragon_breath", "red_dragon_dragon_breath"]
	same_kind_runtime._current_profile.active_skill_ids = same_kind_active_ids
	same_kind_runtime._current_profile.active_skill_levels = {"red_dragon_dragon_breath": 1}
	same_kind_runtime._current_profile.active_slot_count = 2
	same_kind_runtime._current_profile.set_affinity_state(22, same_kind_rewards)
	_expect_eq(active_slot_resolver.get_active_slot_count(same_kind_runtime._current_profile, same_kind_runtime._skill_runtime_host), 1, "same-kind active slots should collapse to slot 0 to avoid shared state")
	same_kind_runtime.configure_companion_motion_for_tests(Vector2(380.0, 260.0), 8, 0.0, true)
	same_kind_runtime.update(0.05, same_kind_owner, registry)
	var same_kind_slot1: Object = _skill_state_for_runtime_slot(same_kind_runtime, 1)
	_expect(not bool(same_kind_slot1.windup_active), "same-kind slot 1 should not arm when module sharing is blocked")

	var suppress_runtime: Object = LingpetEggRuntime.new()
	var suppress_owner := FakeOwner.new()
	_expect(
		suppress_runtime.debug_grant_and_activate_pet("red_dragon", suppress_owner, false, "", "", registry, 1, 1),
		"same-kind reconcile fixture should activate Red Dragon"
	)
	suppress_runtime._affinity_state.resolve_single_unlock("red_dragon", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "red_dragon_dragon_breath")
	suppress_runtime._affinity_state.resolve_single_unlock("red_dragon", LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK, "red_dragon_dragon_breath")
	suppress_runtime._loadout_state.invalidate_runtime_and_snapshot_cache(suppress_runtime._snapshot_builder)
	suppress_runtime.update(0.0, suppress_owner, registry)
	var suppress_loadout: Dictionary = suppress_runtime._loadout_state.get_loadout("red_dragon")
	_expect_str(str(suppress_loadout.get("active_skill_id", "")), "red_dragon_dragon_breath", "forced same-kind reconcile should preserve slot 0")
	_expect_str(str(suppress_loadout.get("second_active_skill_id", "")), "", "write-time would_share_module should suppress a same-kind slot-1 id")
	_expect_float(float(same_kind_slot1.cooldown), 0.0, "same-kind slot 1 should not spend cooldown when module sharing is blocked")

	var passive_runtime: Object = LingpetEggRuntime.new()
	var passive_owner := FakeOwner.new()
	_expect(
		passive_runtime.debug_grant_and_activate_pet("maribo", passive_owner, false, "", "", registry, 1, 1),
		"second-passive reconcile fixture should activate Maribo"
	)
	passive_runtime._affinity_state.resolve_single_unlock("maribo", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "maribo_hydro_sphere")
	passive_runtime._affinity_state.resolve_single_unlock("maribo", LingpetAffinityState.REWARD_TYPE_PASSIVE_UNLOCK, "lingpet_resonance_boost")
	passive_runtime._affinity_state.resolve_single_unlock("maribo", LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK, "lingpet_tailwind_steps")
	passive_runtime._loadout_state.invalidate_runtime_and_snapshot_cache(passive_runtime._snapshot_builder)
	passive_runtime.update(0.0, passive_owner, registry)
	var passive_loadout: Dictionary = passive_runtime._loadout_state.get_loadout("maribo")
	_expect_str(str(passive_loadout.get("passive_skill_id", "")), "lingpet_resonance_boost", "primary passive reconcile should write slot 0")
	_expect_str(str(passive_loadout.get("second_passive_skill_id", "")), "lingpet_tailwind_steps", "second-passive reconcile should write slot 1")
	_expect_eq((passive_loadout.get("passive_skill_ids", []) as Array).size(), 2, "second-passive reconcile should persist two passive ids")
	var unlock_reconciler := LingpetUnlockLoadoutReconciler.new()
	var unlock_reconciler_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_unlock_loadout_reconciler.gd")
	var current_loadout_applier_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("func _reconcile_unlock_choices") < 0, "egg runtime should not keep a private unlock reconcile wrapper")
	_expect(current_loadout_applier_source.find("unlock_loadout_reconciler.reconcile_for_runtime") >= 0, "current loadout applier should delegate runtime unlock reconcile to the reconciler owner")
	_expect(unlock_reconciler_source.find("func reconcile_for_runtime") >= 0 and unlock_reconciler_source.find("invalidate_runtime_cache") >= 0 and unlock_reconciler_source.find("invalidate_sync_cache") >= 0, "unlock loadout reconciler should own runtime reconcile cache invalidation")
	_expect(
		unlock_reconciler.loadout_matches(passive_loadout, "maribo_hydro_sphere", "lingpet_resonance_boost", "", "lingpet_tailwind_steps"),
		"loadout match should include the second passive id so a settled reconcile does not thrash"
	)
	_expect(
		not bool(unlock_reconciler.reconcile_for_runtime(
			passive_owner,
			"maribo",
			passive_runtime._current_profile,
			passive_runtime._affinity_state,
			passive_runtime._loadout_state,
			passive_runtime._skill_runtime_host,
			passive_runtime._snapshot_builder
		)),
		"a settled 4-key reconcile should return false instead of rewriting every frame"
	)

	var legacy_persistence := LingpetCompanionSkillPersistence.new()
	legacy_persistence.state_by_pet_id["red_dragon"] = {
		"cooldown": 20.0,
		"trigger_count": 3,
		"last_gain": 1.0,
		"origin": Vector2(12.0, 34.0),
	}
	# Stored cooldown migration/advance now runs only while a guardian is
	# summoned; an unmatched active id keeps this fixture focused on the legacy
	# snapshot shape rather than the stow freeze contract.
	legacy_persistence.advance_stored_cooldowns(3.0, "", true, LingpetCatalog.MAX_ACTIVE_SLOT_COUNT)
	var legacy_stored: Dictionary = legacy_persistence.state_by_pet_id.get("red_dragon", {}) as Dictionary
	var legacy_slot0: Dictionary = legacy_stored.get("slot_0", {}) as Dictionary
	var legacy_slot1: Dictionary = legacy_stored.get("slot_1", {}) as Dictionary
	_expect_float(float(legacy_slot0.get("cooldown", 0.0)), 17.0, "legacy flat skill snapshot should migrate into slot 0 and advance")
	_expect_float(float(legacy_slot1.get("cooldown", -1.0)), 0.0, "legacy flat skill snapshot should leave slot 1 cold")
	_expect_eq(int(legacy_stored.get("trigger_count", 0)), 3, "legacy flat skill snapshot should preserve shared trigger count")


func _verify_debug_grant_unlock_reconcile_skip_is_sticky_until_pet_change() -> void:
	var owner := FakeOwner.new()
	owner.ball_active = true
	owner.ball_pos = Vector2(380.0, 260.0)
	owner.ball_vel = Vector2(0.0, -12.0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(runtime)
	_expect(
		runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "", registry, 1, 1),
		"explicit debug active fixture should activate Maribo"
	)
	_expect(bool(runtime._loadout_state.should_skip_unlock_reconcile()), "debug-grant unlock reconcile skip should stay sticky for the forced same-pet loadout")
	var initial_loadout: Dictionary = runtime._loadout_state.get_loadout("maribo")
	_expect_str(str(initial_loadout.get("active_skill_id", "")), "maribo_hydro_sphere", "explicit debug grant should keep its forced active skill")
	_expect_str(str(initial_loadout.get("passive_skill_id", "")), "", "explicit active-only debug grant should start without a passive skill")

	_grant_affinity_round_commits(runtime, "maribo", 25)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("maribo"), 2, "25 committed rounds should reach the V3 Lv.2 passive unlock gate")
	var reconciled_loadout: Dictionary = runtime._loadout_state.get_loadout("maribo")
	var reconciled_passive_id := str(reconciled_loadout.get("passive_skill_id", ""))
	_expect_str(str(reconciled_loadout.get("active_skill_id", "")), "maribo_hydro_sphere", "same-pet reconcile should preserve the selected primary active")
	_expect_str(reconciled_passive_id, "", "same-pet debug grant should keep unlock reconcile blocked for the forced loadout")
	_expect_eq((reconciled_loadout.get("passive_skill_ids", []) as Array).size(), 0, "same-pet debug grant should not auto-fill a primary passive slot")
	_expect_str(str(owner.lingpet_passive_skill_id), "", "owner sync should keep passive empty while the forced debug loadout is protected")

	_expect(
		runtime.debug_grant_and_activate_pet("lumion", owner, false, "", "", registry, 1, 1),
		"same fixture should switch to Lumion without a forced debug loadout"
	)
	_expect(not bool(runtime._loadout_state.should_skip_unlock_reconcile()), "pet change should clear the debug reconcile skip flag")
	_grant_affinity_round_commits(runtime, "lumion", 10)
	runtime.update(0.0, owner, registry)
	var lumion_loadout: Dictionary = runtime._loadout_state.get_loadout("lumion")
	var lumion_active_id := str(lumion_loadout.get("active_skill_id", ""))
	var unlock_reconciler := LingpetUnlockLoadoutReconciler.new()
	var lumion_active_candidates: Array[String] = unlock_reconciler.get_active_unlock_candidate_ids("lumion")
	_expect(lumion_active_id != "", "unforced pet after a debug switch should reconcile a primary active unlock")
	_expect(lumion_active_candidates.has(lumion_active_id), "unforced Lumion active unlock should resolve to one of the current active candidates")
	var lumion_resolved: Dictionary = runtime._affinity_state.get_resolved_unlock_choices("lumion")
	var lumion_active_choice: Dictionary = lumion_resolved.get("active", {}) as Dictionary
	_expect_str(str(lumion_active_choice.get("selected", "")), lumion_active_id, "Lumion loadout should mirror the resolved active unlock choice")


func _verify_second_active_resource_conflict_mediation() -> void:
	var arm_gate := LingpetCompanionSkillArmGate.new()
	var active_slot_resolver := LingpetActiveSkillSlotResolver.new()
	var visual_resolver := LingpetCompanionSkillVisualResolver.new()
	_expect(
		bool(LingpetSkillDispatcher.skills_share_exclusive_resource("rabi_ghost_summon", "maribo_hydro_sphere")),
		"BALL_OWNER skills should report an exclusive-resource intersection"
	)
	_expect(
		bool(LingpetSkillDispatcher.skills_share_exclusive_resource("monkeyring_wild_roar", "maribo_hydro_sphere")),
		"Wild Roar should intersect BALL_OWNER skills"
	)
	_expect(
		bool(LingpetSkillDispatcher.skills_share_exclusive_resource("monkeyring_wild_roar", "lunabi_headbutt")),
		"Wild Roar should also intersect POS_OVERRIDE skills"
	)
	_expect(
		not bool(LingpetSkillDispatcher.skills_share_exclusive_resource("rabi_ghost_summon", "red_dragon_dragon_breath")),
		"FREE skills should not be blocked by a BALL_OWNER wind-up"
	)

	var registry := FakeRegistry.new({})
	var ball_owner := FakeOwner.new()
	ball_owner.ball_active = true
	ball_owner.ball_pos = Vector2(380.0, 260.0)
	ball_owner.ball_vel = Vector2(0.0, -12.0)
	var ball_runtime: Object = LingpetEggRuntime.new()
	_expect(
		ball_runtime.debug_grant_and_activate_pet("rabi", ball_owner, false, "rabi_ghost_summon", "", registry, 1, 1),
		"BALL_OWNER conflict fixture should activate Rabi"
	)
	_force_second_active_runtime_profile(ball_runtime, "rabi", "rabi_ghost_summon", "maribo_hydro_sphere")
	ball_runtime.configure_companion_motion_for_tests(Vector2(380.0, 260.0), 4, 0.0, true)
	ball_runtime.update(0.05, ball_owner, registry)
	var ball_slot0: Object = _skill_state_for_runtime_slot(ball_runtime, 0)
	var ball_slot1: Object = _skill_state_for_runtime_slot(ball_runtime, 1)
	_expect(bool(ball_slot0.windup_active), "slot 0 BALL_OWNER should arm first")
	_expect(not bool(ball_slot1.windup_active), "slot 1 BALL_OWNER should wait while slot 0 owns the class")
	var blocked_slot1_cooldown := float(ball_slot1.cooldown)
	ball_runtime.update(0.05, ball_owner, registry)
	_expect_float(float(ball_slot1.cooldown), blocked_slot1_cooldown, "blocked BALL_OWNER slot 1 should not spend cooldown while waiting")
	_expect_eq(int(ball_slot1.trigger_count), 0, "blocked BALL_OWNER slot 1 should not count a trigger while waiting")
	_expect(
		not bool(arm_gate.can_arm(
			1,
			"maribo_hydro_sphere",
			active_slot_resolver.get_active_skill_ids_for_runtime(ball_runtime._current_profile, ball_runtime._skill_runtime_host),
			ball_runtime._companion_skill_states,
			ball_runtime._skill_runtime_host
		)),
		"BALL_OWNER arm gate should be falsifiable at slot 1"
	)
	_expect(
		bool(arm_gate.can_arm(
			1,
			"red_dragon_dragon_breath",
			active_slot_resolver.get_active_skill_ids_for_runtime(ball_runtime._current_profile, ball_runtime._skill_runtime_host),
			ball_runtime._companion_skill_states,
			ball_runtime._skill_runtime_host
		)),
		"FREE slot should remain eligible beside a BALL_OWNER wind-up"
	)
	ball_slot0.cancel_windup()
	ball_slot0.cooldown = 1.0
	_expect(
		bool(arm_gate.can_arm(
			1,
			"maribo_hydro_sphere",
			active_slot_resolver.get_active_skill_ids_for_runtime(ball_runtime._current_profile, ball_runtime._skill_runtime_host),
			ball_runtime._companion_skill_states,
			ball_runtime._skill_runtime_host
		)),
		"BALL_OWNER loser should become eligible after the winning slot releases the exclusive class"
	)
	ball_runtime.update(0.05, ball_owner, registry)
	_expect(not bool(ball_slot0.windup_active), "cooling BALL_OWNER slot 0 should not immediately reclaim wind-up")
	_expect(bool(ball_slot1.windup_active), "BALL_OWNER loser should arm once slot 0 no longer holds the class")
	_expect_float(float(ball_slot1.cooldown), 0.0, "resumed BALL_OWNER slot 1 should not spend cooldown before its own launch")

	var pos_owner := FakeOwner.new()
	pos_owner.ball_active = true
	pos_owner.ball_pos = Vector2(380.0, 260.0)
	pos_owner.ball_vel = Vector2(0.0, -12.0)
	var pos_runtime: Object = LingpetEggRuntime.new()
	_expect(
		pos_runtime.debug_grant_and_activate_pet("lunabi", pos_owner, false, "lunabi_headbutt", "", registry, 1, 1),
		"POS_OVERRIDE conflict fixture should activate Lunabi"
	)
	_force_second_active_runtime_profile(pos_runtime, "lunabi", "lunabi_headbutt", "koyora_puppet_control")
	pos_runtime.configure_companion_motion_for_tests(Vector2(380.0, 310.0), 5, 0.0, true)
	pos_runtime.update(0.05, pos_owner, registry)
	var pos_slot0: Object = _skill_state_for_runtime_slot(pos_runtime, 0)
	var pos_slot1: Object = _skill_state_for_runtime_slot(pos_runtime, 1)
	_expect(bool(pos_slot0.windup_active), "slot 0 POS_OVERRIDE should arm first")
	_expect(not bool(pos_slot1.windup_active), "slot 1 POS_OVERRIDE should wait while slot 0 owns the class")
	pos_runtime.update(0.50, pos_owner, registry)
	var override_owner: Dictionary = visual_resolver.get_active_position_override_owner(
		active_slot_resolver.get_active_skill_ids_for_runtime(pos_runtime._current_profile, pos_runtime._skill_runtime_host),
		pos_runtime._skill_runtime_host,
		pos_runtime._companion_pos
	)
	_expect(bool(override_owner.get("has", false)), "launched POS_OVERRIDE skill should expose one active position owner")
	_expect_str(str(override_owner.get("skill_id", "")), "lunabi_headbutt", "position override owner query should keep slot-0 priority")
	_expect_str(
		visual_resolver.get_companion_body_skill_id(
			override_owner,
			active_slot_resolver.get_skill_id_for_slot(pos_runtime._current_profile, 0)
		),
		"lunabi_headbutt",
		"body hit/draw gates should read the active position owner"
	)

	var wild_runtime: Object = LingpetEggRuntime.new()
	var wild_owner := FakeOwner.new()
	_expect(
		wild_runtime.debug_grant_and_activate_pet("monkeyring", wild_owner, false, "monkeyring_wild_roar", "", registry, 1, 1),
		"Wild Roar resource-class fixture should activate Monkeyring"
	)
	_force_second_active_runtime_profile(wild_runtime, "monkeyring", "monkeyring_wild_roar", "maribo_hydro_sphere")
	_skill_state_for_runtime_slot(wild_runtime, 0).arm_windup()
	_expect(
		not bool(arm_gate.can_arm(
			1,
			"maribo_hydro_sphere",
			active_slot_resolver.get_active_skill_ids_for_runtime(wild_runtime._current_profile, wild_runtime._skill_runtime_host),
			wild_runtime._companion_skill_states,
			wild_runtime._skill_runtime_host
		)),
		"Wild Roar should block BALL_OWNER peers through set intersection"
	)
	_force_second_active_runtime_profile(wild_runtime, "monkeyring", "monkeyring_wild_roar", "lunabi_headbutt")
	_expect(
		not bool(arm_gate.can_arm(
			1,
			"lunabi_headbutt",
			active_slot_resolver.get_active_skill_ids_for_runtime(wild_runtime._current_profile, wild_runtime._skill_runtime_host),
			wild_runtime._companion_skill_states,
			wild_runtime._skill_runtime_host
		)),
		"Wild Roar should block POS_OVERRIDE peers through set intersection"
	)

	var visual_runtime: Object = LingpetEggRuntime.new()
	var visual_owner := FakeOwner.new()
	_expect(
		visual_runtime.debug_grant_and_activate_pet("koyora", visual_owner, false, "koyora_doll_curse", "", registry, 1, 1),
		"active visual slot fixture should activate Koyora"
	)
	_force_second_active_runtime_profile(visual_runtime, "koyora", "red_dragon_dragon_breath", "koyora_doll_curse")
	_skill_state_for_runtime_slot(visual_runtime, 1).arm_windup()
	_expect_eq(
		visual_resolver.get_active_visual_slot_index(
			active_slot_resolver.get_active_skill_ids_for_runtime(visual_runtime._current_profile, visual_runtime._skill_runtime_host),
			visual_runtime._companion_skill_states,
			visual_runtime._skill_runtime_host
		),
		1,
		"draw context should select slot 1 when only the second active is casting"
	)

	var strike_runtime: Object = LingpetEggRuntime.new()
	var strike_owner := FakeOwner.new()
	strike_owner.ball_active = true
	strike_owner.ball_pos = Vector2(720.0, 720.0)
	strike_owner.ball_vel = Vector2.ZERO
	_expect(
		strike_runtime.debug_grant_and_activate_pet("red_dragon", strike_owner, false, "red_dragon_dragon_breath", "", registry, 1, 1),
		"slot-1 strike fixture should activate Red Dragon"
	)
	_force_second_active_runtime_profile(strike_runtime, "red_dragon", "red_dragon_dragon_breath", "lunabi_headbutt")
	strike_runtime.configure_companion_motion_for_tests(Vector2(80.0, 310.0), 6, 0.0, true)
	strike_runtime.update(0.05, strike_owner, registry)
	var strike_slot0: Object = _skill_state_for_runtime_slot(strike_runtime, 0)
	var strike_slot1: Object = _skill_state_for_runtime_slot(strike_runtime, 1)
	_expect(not bool(strike_slot0.windup_active), "slot 0 FREE fixture should stay idle by failing its center-position arm gate")
	_expect(bool(strike_slot1.windup_active), "slot 1 headbutt should arm its own windup beside a FREE slot 0 skill")
	_expect(not bool(strike_runtime.is_companion_striking_for_tests()), "slot 1 headbutt should not begin strike before launch")
	var strike_slot1_surface: Dictionary = strike_runtime._skill_runtime_surface.get_active_surface_for_slot(
		strike_runtime._current_profile,
		strike_runtime._active_skill_slot_resolver,
		strike_runtime._companion_skill_persistence,
		strike_runtime._companion_skill_states,
		strike_runtime._skill_runtime_host,
		LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS,
		1
	)
	var strike_slot1_windup := float(strike_slot1_surface.get("windup_seconds", LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS))
	strike_runtime.update(strike_slot1_windup + 0.05, strike_owner, registry)
	_expect(not bool(strike_slot1.windup_active), "slot 1 headbutt windup should clear after launch")
	_expect(float(strike_slot1.cooldown) > 0.0, "slot 1 headbutt launch should spend slot 1 cooldown")
	_expect(bool(strike_runtime.is_companion_striking_for_tests()), "slot 1 headbutt launch should consume its strike request")
	_expect_eq(
		strike_runtime.get_companion_strike_frame_for_tests(),
		LingpetCompanionSpriteAnimator.STRIKE_START_FRAME,
		"slot 1 strike request should start the shared animator at the wind-up strike frame"
	)


func _verify_affinity_level_up_feedback_and_income_log() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var grant_controller_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_grant_controller.gd")
	var renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	var draw_context_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_affinity_feedback_state.gd"), "affinity level-up feedback state should be a focused runtime module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_affinity_income_tracker.gd"), "affinity income logging should be a focused runtime module")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_affinity_grant_controller.gd"), "affinity grant lifecycle should have a focused controller")
	_expect(runtime_source.find("draw_affinity_feedback") >= 0, "runtime should draw affinity level-up feedback as a non-pausing playfield overlay")
	_expect(runtime_source.find("func _draw_affinity_feedback") < 0, "egg runtime should not keep a single-use affinity-feedback draw wrapper")
	_expect(runtime_source.find("_companion_renderer.draw_affinity_feedback") >= 0, "egg runtime should call the companion renderer affinity feedback draw owner directly")
	_expect(grant_controller_source.find("income_tracker.record") >= 0, "grant controller should record affinity income on every granted source")
	_expect(grant_controller_source.find("func remember_result") >= 0 and grant_controller_source.find("func get_last_result") >= 0, "grant controller should own the latest affinity grant result")
	_expect(runtime_source.find("var _last_affinity_result") < 0, "egg runtime should not keep raw latest-affinity-result state")
	_expect(runtime_source.find("_affinity_grant_controller.get_last_result") >= 0, "egg runtime should expose latest affinity result through the grant controller owner")
	_expect(renderer_source.find("draw_affinity_feedback") >= 0, "companion renderer should own the affinity level-up burst draw")
	_expect(renderer_source.find("affinity_heart_tint") >= 0, "companion renderer should support the max-level permanent heart tint")
	_expect(draw_context_source.find("build_affinity_feedback_config") >= 0, "draw context builder should expose a small affinity feedback draw config")
	_expect(draw_context_source.find("\"affinity_label\"") >= 0 and draw_context_source.find("\"affinity_heart_tint\"") >= 0, "draw context should pass label and heart-tint fields")
	_expect(renderer_source.find("친밀도") < 0 and draw_context_source.find("친밀도") < 0, "live run feedback should reserve 친밀도 for permanent bond surfaces")

	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	var runtime: Object = LingpetEggRuntime.new()
	_set_run_ring_core_tier_for_smoke(runtime)
	var perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new({"battle_perf_logger": perf_logger})
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_resonance_boost", registry, 1, 1), "affinity feedback fixture should activate Maribo")

	for _i in range(10):
		runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
	var lv1_snapshot: Dictionary = runtime.get_snapshot()
	_expect_eq(int(lv1_snapshot.get("affinity_level", 0)), 1, "ten round commits should reach affinity Lv.1 for feedback")
	_expect_float(float(lv1_snapshot.get("affinity_feedback_flash_ratio", 0.0)), 1.0, "level-up feedback should start at full flash ratio")
	_expect_str(str(lv1_snapshot.get("affinity_feedback_label", "")), "교감 Lv.1!", "level-up feedback should use the player-facing 교감 label")
	_expect(not bool(lv1_snapshot.get("affinity_feedback_heart_tint", false)), "non-max level-up should not unlock permanent heart tint")
	var lv1_income: Dictionary = runtime.get_affinity_income_summary_for_tests()
	_expect_float(float(lv1_income.get("total", 0.0)), 50.0, "income summary should accumulate the Lv.1 round-commit points")
	_expect_float(perf_logger.total_for("lingpet.affinity.income.round_commit"), 50.0, "BattlePerf counter should receive round-commit affinity income")
	_expect_float(perf_logger.total_for("lingpet.affinity.level_ups"), 1.0, "BattlePerf counter should receive the Lv.1 level-up")

	runtime.update(0.90, owner, registry)
	var expired_snapshot: Dictionary = runtime.get_snapshot()
	_expect_float(float(expired_snapshot.get("affinity_feedback_flash_ratio", -1.0)), 0.0, "level-up feedback should expire without pausing battle update")
	_expect_str(str(expired_snapshot.get("affinity_feedback_label", "")), "", "expired level-up feedback should stop drawing the label")

	for _i in range(825):
		runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
	var max_snapshot: Dictionary = runtime.get_snapshot()
	var max_title := str(LingpetAffinityState.get_reward_for_level(LingpetAffinityState.MAX_LEVEL).get("title", ""))
	_expect_eq(int(max_snapshot.get("affinity_level", 0)), LingpetAffinityState.MAX_LEVEL, "affinity fixture should reach max level")
	_expect_str(str(max_snapshot.get("affinity_feedback_label", "")), "교감 Lv.30!", "max-level feedback should still use 교감 in the live overlay")
	_expect_str(str(max_snapshot.get("affinity_feedback_title", "")), max_title, "max-level feedback should expose the max title")
	_expect(bool(max_snapshot.get("affinity_feedback_heart_tint", false)), "max-level feedback should unlock permanent heart tint")
	_expect_float(float(runtime.get_affinity_income_summary_for_tests().get("total", 0.0)), 1500.0, "income summary should preserve the full battle total (flat-50 Lv.30 income) until battle reset")
	runtime.update(1.0, owner, registry)
	var post_max_snapshot: Dictionary = runtime.get_snapshot()
	_expect_float(float(post_max_snapshot.get("affinity_feedback_flash_ratio", -1.0)), 0.0, "max-level flash should expire")
	_expect(bool(post_max_snapshot.get("affinity_feedback_heart_tint", false)), "heart tint should remain after the max-level flash expires")
	runtime.reset_affinity_for_new_battle()
	_expect_float(float(runtime.get_affinity_income_summary_for_tests().get("total", -1.0)), 0.0, "battle reset should clear the debug income summary")


func _verify_affinity_point_gain_popup() -> void:
	# Rising "+N" popup above the companion on every REAL point grant:
	# spawns with the granted amount, coalesces rapid gains, skips blocked
	# (granted_points 0) results, expires after its lifetime, and caps the
	# concurrent count so grant spam cannot flood the overlay.
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_resonance_boost")),
		"point-popup fixture should activate a Maribo companion"
	)
	var fb: Object = runtime._affinity_feedback_state
	_expect((fb.get_point_popups() as Array).is_empty(), "no popup should exist before any affinity grant")

	var first: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var first_granted := float(first.get("granted_points", 0.0))
	_expect(first_granted > 0.0, "point-popup fixture grant should land real points")
	var popups: Array = fb.get_point_popups()
	_expect(popups.size() == 1, "a granted gain should spawn exactly one +N popup")
	if popups.is_empty():
		return
	_expect(is_equal_approx(float((popups[0] as Dictionary).get("amount", 0.0)), first_granted), "the popup should carry the granted amount")

	runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	popups = fb.get_point_popups()
	_expect(popups.size() == 1, "rapid gains inside the coalesce window should merge into one popup")
	_expect(is_equal_approx(float((popups[0] as Dictionary).get("amount", 0.0)), 2.0 * first_granted), "the merged popup should sum both gains")
	_expect((runtime.get_snapshot().get("affinity_point_popups", []) as Array).size() == 1, "the companion snapshot should expose the point popups for the draw context")

	fb.point_popups.clear()
	var hatch_first: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect(float(hatch_first.get("granted_points", 0.0)) > 0.0, "first hatch-source grant should land for the blocked-grant case")
	var hatch_blocked: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect(is_equal_approx(float(hatch_blocked.get("granted_points", -1.0)), 0.0), "duplicate hatch grant should be blocked")
	popups = fb.get_point_popups()
	_expect(popups.size() == 1 and is_equal_approx(float((popups[0] as Dictionary).get("amount", 0.0)), float(hatch_first.get("granted_points", 0.0))), "a blocked grant must not spawn or merge a popup")

	runtime.update(1.0, owner)
	_expect((fb.get_point_popups() as Array).is_empty(), "point popups should expire after their lifetime")
	_expect(not bool(fb.has_visible_effects(true)), "expired popups should release the visible-effects redraw gate")

	fb.point_popups.clear()
	for _i in range(5):
		fb.trigger_point_gain(3.0)
		if not fb.point_popups.is_empty():
			fb.point_popups[fb.point_popups.size() - 1]["age"] = 0.3
	_expect(fb.point_popups.size() == fb.MAX_POINT_POPUPS, "concurrent popups should cap at MAX_POINT_POPUPS")
	_expect(bool(fb.has_visible_effects(true)), "live popups should hold the visible-effects redraw gate without a level-up flash")
	_expect((fb.get_point_popups(false) as Array).is_empty(), "non-companion draw context should expose no point popups")
	fb.point_popups.clear()


func _verify_lingpet_guard_label_feedback() -> void:
	var renderer_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(renderer_source.find("LanguageSettings.translate_text") >= 0 and renderer_source.find("_draw_guard_label") >= 0, "guard label should translate at the raw draw-string boundary")
	_expect(runtime_source.find("trigger_guard_label") >= 0 and runtime_source.find("_affinity_hit_tag_resolver.has_defense_tag") >= 0, "runtime should trigger the guard label from resolver-owned defense-tagged hits")
	_expect(runtime_source.find("func _has_defense_affinity_hit_tag") < 0, "runtime should not keep a single-use defense affinity hit-tag wrapper")

	var plain_owner := FakeOwner.new()
	plain_owner.lingpet_owned_pet_ids = ["maribo"]
	var plain_runtime: Object = LingpetEggRuntime.new()
	plain_runtime.update(0.0, plain_owner)
	var plain_pos: Vector2 = plain_owner.lingpet_companion_pos
	plain_owner.ball_active = true
	plain_owner.ball_pos = plain_pos + Vector2(0.0, -6.0)
	plain_owner.ball_vel = Vector2(0.0, 14.0)
	plain_runtime.update(0.01, plain_owner)
	_expect((plain_runtime.get_snapshot().get("affinity_guard_label", {}) as Dictionary).is_empty(), "ordinary companion hits should not spawn the defense label")

	var registry := FakeRegistry.new({})
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_resonance_boost", registry, 1, 1), "guard-label fixture should activate Maribo")
	_prepare_maribo_guard_after_windup(runtime, owner, registry)
	var contact_center := Vector2(650.0, owner.lingpet_companion_pos.y)
	for _i in range(3):
		_force_tagged_guard_hit(runtime, owner, registry, contact_center)
	var snapshot: Dictionary = runtime.get_snapshot()
	var label: Dictionary = snapshot.get("affinity_guard_label", {}) as Dictionary
	_expect(not label.is_empty(), "third defense-tagged guard should still expose a guard label after the two-bonus cap is exhausted")
	_expect_str(str(label.get("text", "")), "방어", "guard label should use the localized exact-text key")
	_expect(_get_vector2(label.get("position", Vector2.ZERO), Vector2.ZERO).distance_to(owner.lingpet_companion_last_contact_pos) <= 0.01, "guard label should anchor at the hit position, not at the moving companion")
	_expect_float(runtime.get_affinity_points("maribo"), 34.0, "third guard should be past the two-bonus cap while still showing the defense label")
	_expect(not bool(owner.lingpet_companion_defense_intercept_active), "guard hit should clear the intercept flag immediately after contact")

	owner.ball_active = false
	runtime.update(0.81, owner, registry)
	_expect((runtime.get_snapshot().get("affinity_guard_label", {}) as Dictionary).is_empty(), "guard label should expire after its short fade")
	runtime._affinity_feedback_state.trigger_guard_label(Vector2(320.0, 520.0))
	runtime.reset_round({"owner": owner, "registry": registry})
	_expect((runtime.get_snapshot().get("affinity_guard_label", {}) as Dictionary).is_empty(), "round reset should clear a lingering guard label without relying on draw")


func _verify_affinity_store_v5_meta_only() -> void:
	# R3 / per-run: LingpetAffinityStore is meta-only (v5). Legacy v4 sections
	# ([best_levels]/[bond_points]/[ring_core]/[resolved_unlock_choices]) are
	# ignored on load and never re-persisted; affinity lives in run-state only.
	var store_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_store.gd")
	var ring_core_rules_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_ring_core_rules.gd")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(store_source.find("SAVE_SCHEMA_VERSION := 5") >= 0, "affinity store should stamp the v5 meta-only schema")
	_expect(store_source.find("bytes.slice(3)") >= 0, "affinity store should still strip UTF-8 BOM before parsing")
	for store_residue_needle in ["MAX_BEST_LEVEL", "MAX_AFFINITY_LEVEL", "MAX_RING_CORE_TIER", "func get_ring_core_cap_for_tier", "var _best_levels", "var _bond_points", "var _ring_core_tier", "var _resolved_unlock_choices", "func _load_best_levels", "func _load_bond_points", "func _load_ring_core", "func _load_resolved_unlock_choices"]:
		_expect(store_source.find(store_residue_needle) < 0, "v5 affinity store should not keep legacy backing residue (%s)" % store_residue_needle)
	_expect(ring_core_rules_source.find("MAX_RING_CORE_TIER := 6") >= 0 and ring_core_rules_source.find("get_ring_core_cap_for_tier") >= 0, "ring-core tier constants/cap helper should live in the dedicated rules helper")
	_verify_affinity_store_not_production_dependency()
	for store_api_needle in ["func get_best_level", "func get_best_levels", "func set_best_level", "func merge_best_levels", "func get_bond_points", "func get_bond_points_map", "func add_bond_levels", "func get_resolved_unlock_choices", "func get_all_resolved_unlock_choices", "func set_resolved_unlock_choice", "func clear_resolved_unlock_choice", "func has_ring_core_tier", "func get_ring_core_tier", "func get_ring_core_cap(", "func set_ring_core_tier", "func upgrade_ring_core_tier"]:
		_expect(store_source.find(store_api_needle) < 0, "v5 affinity store should not expose legacy progression API (%s)" % store_api_needle)
	for store_needle in ["store.get_best_level", "store.set_best_level", "store.add_bond_levels", "store.get_bond_points", "store.get_resolved_unlock_choices", "store.set_resolved_unlock_choice", "store.clear_resolved_unlock_choice", "store.get_ring_core_tier", "store.set_ring_core_tier", "store.upgrade_ring_core_tier", "store.get_ring_core_cap"]:
		_expect(runtime_source.find(store_needle) < 0, "egg_runtime must not touch the persisted affinity axis (%s)" % store_needle)
	_expect(runtime_source.find("add_bond_levels") < 0, "egg_runtime should not reintroduce a permanent bond settlement write")
	var smoke_source := FileAccess.get_file_as_string("res://tests/lingpet_egg_runtime_smoke.gd")
	var legacy_fixture_writers := [
		"_write_affinity_store_" + "bom_file",
		"_write_affinity_store_" + "broken_file",
		"_write_affinity_store_" + "v1_file",
		"_write_affinity_store_" + "v2_file",
		"_write_affinity_store_" + "corrupt_bond_file",
	]
	for legacy_fixture_writer in legacy_fixture_writers:
		_expect(smoke_source.find(legacy_fixture_writer) < 0, "egg runtime smoke should not keep unused legacy affinity-store fixture writer %s" % legacy_fixture_writer)
	for runtime_needle in ["_apply_affinity_headstart_from_store", "_get_affinity_store", "_affinity_store_override", "_affinity_headstart_applied_pet_ids"]:
		_expect(runtime_source.find(runtime_needle) < 0, "egg_runtime should not keep private v4 store/headstart residue (%s)" % runtime_needle)
	for unlock_store_needle in ["func _apply_persisted_unlock_choices", "func _get_store_resolved_unlock_choices"]:
		_expect(runtime_source.find(unlock_store_needle) < 0, "egg_runtime should not keep v4 persisted unlock-choice residue (%s)" % unlock_store_needle)
	_expect(runtime_source.find("set_affinity_store_for_tests") < 0, "egg_runtime should not keep the removed v5 no-op store compatibility hook")

	var legacy_text := "[meta]\nschema_version=4\n\n[best_levels]\nmaribo=30\n\n[bond_points]\nmaribo=18\n\n[ring_core]\ntier=6\n\n[resolved_unlock_choices]\n\"maribo.active\"=\"legacy_skill\"\n"
	var legacy_path := _smoke_save_path("affinity_store_v5_legacy")
	var legacy_backup := legacy_path.trim_suffix(".cfg") + ".last_good.cfg"
	_remove_user_file(legacy_path)
	_remove_user_file(legacy_backup)
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	_expect(legacy_file != null, "v5 legacy fixture should open the main file")
	if legacy_file != null:
		legacy_file.store_string(legacy_text)
		legacy_file.close()
	var legacy_backup_file := FileAccess.open(legacy_backup, FileAccess.WRITE)
	_expect(legacy_backup_file != null, "v5 legacy fixture should open the backup file")
	if legacy_backup_file != null:
		legacy_backup_file.store_string(legacy_text)
		legacy_backup_file.close()

	var store: Object = LingpetAffinityStore.new()
	store.set_save_path(legacy_path)
	for removed_method in ["get_best_level", "get_best_levels", "set_best_level", "merge_best_levels", "get_bond_points", "get_bond_points_map", "add_bond_levels", "get_resolved_unlock_choices", "get_all_resolved_unlock_choices", "set_resolved_unlock_choice", "clear_resolved_unlock_choice", "has_ring_core_tier", "get_ring_core_tier", "get_ring_core_cap", "set_ring_core_tier", "upgrade_ring_core_tier"]:
		_expect(not bool(store.has_method(removed_method)), "v5 store should remove legacy progression method %s" % removed_method)
	_expect(bool(store.load()), "v5 store should load a legacy file while ignoring progression sections")
	_expect_eq(int(store.get_schema_version()), LingpetAffinityStore.SAVE_SCHEMA_VERSION, "v5 store load should expose the current meta-only schema")
	var loaded_summary: Dictionary = store.get_summary()
	for legacy_summary_key in ["best_levels", "bond_points", "has_ring_core_tier", "ring_core_tier", "ring_core_cap", "resolved_unlock_choices"]:
		_expect(not loaded_summary.has(legacy_summary_key), "v5 store summary should not expose legacy progression key %s" % legacy_summary_key)

	# An explicit save() must drop every legacy section -> meta-only file.
	_expect(bool(store.save()), "v5 store save should succeed")
	var saved_text := FileAccess.get_file_as_string(legacy_path)
	_expect(saved_text.find("schema_version=5") >= 0, "saved v5 file should stamp schema_version=5")
	for legacy_section in ["[best_levels]", "[bond_points]", "[ring_core]", "[resolved_unlock_choices]"]:
		_expect(saved_text.find(legacy_section) < 0, "saved v5 file should not re-create the legacy section %s" % legacy_section)

	# Reload of the now meta-only file stays default, and the legacy backup must
	# not resurrect old sections through the recovery path.
	var reloaded: Object = LingpetAffinityStore.new()
	reloaded.set_save_path(legacy_path)
	_expect(bool(reloaded.load()), "reloaded v5 store should load the meta-only file")
	_expect_eq(int(reloaded.get_schema_version()), LingpetAffinityStore.SAVE_SCHEMA_VERSION, "reloaded v5 store should keep the current schema")
	var reloaded_summary: Dictionary = reloaded.get_summary()
	for legacy_summary_key in ["best_levels", "bond_points", "has_ring_core_tier", "ring_core_tier", "ring_core_cap", "resolved_unlock_choices"]:
		_expect(not reloaded_summary.has(legacy_summary_key), "reloaded v5 summary should not resurrect legacy key %s" % legacy_summary_key)

	# Runtime: a legacy store best=30 / ring tier 6 must NOT headstart or open the
	# affinity cap. The run starts fresh at tier 0 / level 0.
	var headstart_path := _smoke_save_path("affinity_store_v5_headstart")
	var headstart_backup := headstart_path.trim_suffix(".cfg") + ".last_good.cfg"
	_remove_user_file(headstart_path)
	_remove_user_file(headstart_backup)
	var headstart_file := FileAccess.open(headstart_path, FileAccess.WRITE)
	if headstart_file != null:
		headstart_file.store_string(legacy_text)
		headstart_file.close()
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new({})
	runtime.update(0.0, owner, registry)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1, registry)
	var hatched_pet_id := str(owner.active_lingpet_id)
	_expect(hatched_pet_id != "", "v5 headstart fixture should hatch a concrete pet")
	_expect_eq(runtime.get_affinity_level(hatched_pet_id), 0, "legacy store best=30 must NOT headstart a v5 run (affinity starts at Lv0)")
	_expect(int(owner.lingpet_ring_core_tier) != 6, "owner/TAB ring-core tier should ignore the legacy store tier 6 (run-state, not store)")

	_remove_user_file(legacy_path)
	_remove_user_file(legacy_backup)
	_remove_user_file(headstart_path)
	_remove_user_file(headstart_backup)


func _grant_affinity_round_commits(runtime: Object, pet_id: String, count: int) -> void:
	for _i in range(maxi(0, count)):
		runtime.debug_add_affinity_points_for_tests(pet_id, LingpetAffinityState.SOURCE_ROUND_COMMIT)


func _grant_affinity_round_commits_until_reward(runtime: Object, pet_id: String, reward_key: String, max_commits: int) -> void:
	for _i in range(maxi(0, max_commits)):
		var rewards: Dictionary = runtime.get_affinity_rewards_for_tests(pet_id)
		if bool(rewards.get(reward_key, false)):
			return
		runtime.debug_add_affinity_points_for_tests(pet_id, LingpetAffinityState.SOURCE_ROUND_COMMIT)


func _set_run_ring_core_tier_for_smoke(runtime: Object, tier: int = LingpetRingCoreRules.MAX_RING_CORE_TIER) -> void:
	runtime._affinity_state.set_run_ring_core_tier(tier)


func _deck_type_sequence(deck: Array) -> String:
	var parts: Array[String] = []
	for raw_card in deck:
		if raw_card is Dictionary:
			parts.append(str((raw_card as Dictionary).get("type", "")))
	return ",".join(parts)


func _deck_type_count(deck: Array, reward_type: String) -> int:
	var count := 0
	for raw_card in deck:
		if raw_card is Dictionary and str((raw_card as Dictionary).get("type", "")) == reward_type:
			count += 1
	return count


func _force_second_active_runtime_profile(runtime: Object, pet_id: String, first_skill_id: String, second_skill_id: String) -> void:
	var ids: Array[String] = [first_skill_id, second_skill_id]
	var levels: Dictionary = {}
	if first_skill_id != "":
		levels[first_skill_id] = 1
	if second_skill_id != "":
		levels[second_skill_id] = 1
	var rewards := LingpetAffinityState.get_empty_reward_counts()
	rewards["second_active_unlocked"] = true
	rewards["signature"] = "runtime-second-active-%s-%s" % [first_skill_id, second_skill_id]
	runtime._current_profile.set_pet_id(pet_id)
	runtime._current_profile.active_skill_ids = ids
	runtime._current_profile.active_skill_levels = levels
	runtime._current_profile.active_slot_count = 2
	runtime._current_profile.active_skill_id = first_skill_id
	runtime._current_profile.active_skill_level = 1 if first_skill_id != "" else 0
	runtime._current_profile.set_affinity_state(22, rewards)


func _prepare_maribo_guard_after_windup(runtime: Object, owner: FakeOwner, registry: Object) -> void:
	owner.ball_active = true
	owner.ball_pos = Vector2(60.0, 120.0)
	owner.ball_vel = Vector2(0.0, 0.0)
	for _w in range(10):
		runtime.update(0.2, owner, registry)
	_expect(not bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "Maribo guard fixture should finish the initial Hydro Sphere wind-up")


func _force_tagged_guard_hit(runtime: Object, owner: FakeOwner, registry: Object, companion_pos: Vector2) -> void:
	runtime.configure_companion_motion_for_tests(companion_pos, 2, 0.0, true)
	runtime._companion_body_hit_state.ball_was_inside = false
	runtime._companion_body_hit_state.cooldown = 0.0
	owner.ball_active = true
	owner.ball_pos = companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.01, owner, registry)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _verify_ring_core_cap_run_state_source() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("store.get_ring_core_tier") < 0, "runtime cap/display should not read the permanent ring-core tier store in R2")
	_expect(runtime_source.find("store.get_ring_core_cap") < 0, "runtime cap should not read the permanent ring-core cap store in R2")
	_expect(runtime_source.find("store.has_ring_core_tier") < 0, "runtime cap should not branch on permanent ring-core store presence in R2")

	var ignored_store_path := _smoke_save_path("ring_core_store_ignored")
	var standard_path := _smoke_save_path("ring_core_run_standard")
	var missing_path := _smoke_save_path("ring_core_missing")
	_remove_user_file(ignored_store_path)
	_remove_user_file(standard_path)
	_remove_user_file(missing_path)

	# R3 / v5: store no longer persists best/ring-core and is not a live module.
	var no_core_runtime: Object = LingpetEggRuntime.new()
	var no_core_owner := FakeOwner.new()
	var no_core_registry := FakeRegistry.new({})
	_expect(no_core_runtime.debug_grant_and_activate_pet("maribo", no_core_owner, false, "", "", no_core_registry), "run-tier fixture should activate Maribo")
	no_core_runtime.update(0.0, no_core_owner, no_core_registry)
	_expect_eq(no_core_runtime.get_affinity_level("maribo"), 0, "legacy store T6 should not open this-run ring-core cap")
	_expect_eq(int(no_core_owner.lingpet_ring_core_tier), 0, "owner/TAB ring-core tier should use run tier 0 (no store fallback)")
	for _i in range(20):
		no_core_runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, no_core_registry)
	_expect_eq(no_core_runtime.get_affinity_level("maribo"), 0, "run tier 0 should keep affinity at Lv0")
	_expect_float(no_core_runtime.get_affinity_points("maribo"), 50.0, "run tier 0 should clamp banked points at the Lv1 requirement (50/50), not overshoot")

	# R3 / v5: store no longer persists ring-core; the run tier is seeded directly.
	var standard_runtime: Object = LingpetEggRuntime.new()
	var standard_owner := FakeOwner.new()
	var standard_registry := FakeRegistry.new({})
	standard_runtime._affinity_state.set_run_ring_core_tier(1)
	_expect(standard_runtime.debug_grant_and_activate_pet("maribo", standard_owner, false, "", "", standard_registry), "standard fixture should activate Maribo")
	standard_runtime.update(0.0, standard_owner, standard_registry)
	for _i in range(200):
		standard_runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, standard_registry)
	_expect_eq(standard_runtime.get_affinity_level("maribo"), 5, "this-run standard ring-core should cap affinity at Lv5")
	_expect_eq(int(standard_owner.lingpet_ring_core_tier), 1, "owner/TAB ring-core tier should show this-run tier 1")
	var banked_points: float = standard_runtime.get_affinity_points("maribo")
	_expect_float(banked_points, 50.0, "this-run standard ring-core cap should clamp overflow at the next-level requirement (Lv5->Lv6 = 50)")
	standard_runtime.update(0.0, standard_owner, standard_registry)
	standard_runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, standard_registry)
	_expect_eq(standard_runtime.get_affinity_level("maribo"), 5, "owner snapshot sync should not reset ring-core cap to fail-open MAX")
	standard_runtime._loadout_state.invalidate_runtime_and_snapshot_cache(standard_runtime._snapshot_builder)
	standard_runtime._apply_current_loadout(standard_owner, true, false)
	standard_runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, standard_registry)
	_expect_eq(standard_runtime.get_affinity_level("maribo"), 5, "loadout apply without registry should preserve the this-run ring-core cap")
	_expect(standard_runtime._affinity_state.upgrade_run_ring_core_tier(2), "run-state ring-core upgrade should move the cap to tier 2")
	standard_runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, standard_registry)
	_expect_eq(standard_runtime.get_affinity_level("maribo"), 6, "upgrading this-run ring-core cap should release only the clamped ceiling (bounded head start), not a banked level burst")
	_expect(not FileAccess.file_exists(standard_path), "run-state cap upgrades must not write the permanent ring-core store")

	# R3 / v5: store no longer persists best levels and is not a live module.
	var missing_runtime: Object = LingpetEggRuntime.new()
	var missing_owner := FakeOwner.new()
	var missing_registry := FakeRegistry.new({})
	_expect(missing_runtime.debug_grant_and_activate_pet("maribo", missing_owner, false, "", "", missing_registry), "missing-tier fixture should activate Maribo")
	missing_runtime.update(0.0, missing_owner, missing_registry)
	_expect_eq(missing_runtime.get_affinity_level("maribo"), 0, "missing store ring-core data should not fail open beyond this-run tier 0")
	for _i in range(20):
		missing_runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, missing_registry)
	_expect_eq(missing_runtime.get_affinity_level("maribo"), 0, "missing store ring-core data should keep T0 affinity capped at Lv0")
	_expect_float(missing_runtime.get_affinity_points("maribo"), 50.0, "missing store ring-core data should clamp T0 overflow at the Lv1 requirement (50/50)")

	_remove_user_file(ignored_store_path)
	_remove_user_file(standard_path)
	_remove_user_file(missing_path)
	_remove_user_file(ignored_store_path.trim_suffix(".cfg") + ".last_good.cfg")
	_remove_user_file(standard_path.trim_suffix(".cfg") + ".last_good.cfg")
	_remove_user_file(missing_path.trim_suffix(".cfg") + ".last_good.cfg")


func _verify_ineligible_conditions_do_not_spawn() -> void:
	var champion_owner := FakeOwner.new()
	champion_owner.ai_mode = "champion"
	_expect(not LingpetEggRuntime.new().update(0.0, champion_owner), "Champion League should not spawn the first unidentified lingpet egg")

	var optimus_owner := FakeOwner.new()
	optimus_owner.selected_character_type = "optimus"
	_expect(not LingpetEggRuntime.new().update(0.0, optimus_owner), "Junior non-starter character should not spawn the first unidentified lingpet egg")

	# Commando/Viper are now starter-egg eligible in the test (Junior) league.
	var starter_viper := FakeOwner.new()
	starter_viper.selected_character_type = "viper"
	_expect(LingpetEggRuntime.new().update(0.0, starter_viper), "Junior Viper should spawn the starter lingpet egg like Smasher")
	var starter_commando := FakeOwner.new()
	starter_commando.selected_character_type = "soldier"
	_expect(LingpetEggRuntime.new().update(0.0, starter_commando), "Junior Commando should spawn the starter lingpet egg like Smasher")


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


func _expect_hatched_skill_channel_matches_owner(
	owner: FakeOwner,
	runtime_snapshot: Dictionary,
	loadout: Dictionary,
	channel: String,
	label: String
) -> void:
	var id_key := "%s_skill_id" % channel
	var level_key := "%s_skill_level" % channel
	var ids_key := "%s_skill_ids" % channel
	var levels_key := "%s_skill_levels" % channel
	var slot_count_key := "%s_slot_count" % channel
	var skill_id := str(loadout.get(id_key, ""))
	var level := int(loadout.get(level_key, 0))
	var ids: Array = loadout.get(ids_key, []) as Array
	var levels: Dictionary = loadout.get(levels_key, {}) as Dictionary
	var slot_count := int(loadout.get(slot_count_key, 0))
	_expect_str(str(owner.get("lingpet_%s_skill_id" % channel)), skill_id, "%s owner id should mirror loadout" % label)
	_expect_eq(int(owner.get("lingpet_%s_skill_level" % channel)), level, "%s owner level should mirror loadout" % label)
	_expect_str(str(runtime_snapshot.get(id_key, "")), skill_id, "%s snapshot id should mirror loadout" % label)
	_expect_eq(int(runtime_snapshot.get(level_key, 0)), level, "%s snapshot level should mirror loadout" % label)
	_expect(level >= 0 and level <= 3, "%s level should stay in hatch roll range 0..3" % label)
	if skill_id == "":
		_expect_eq(level, 0, "%s empty id should have zero level" % label)
		_expect_eq(ids.size(), 0, "%s empty id should keep ids empty" % label)
		_expect_eq(slot_count, 0, "%s empty id should keep slot count zero" % label)
	else:
		_expect(level > 0, "%s non-empty id should have positive level" % label)
		_expect(ids.has(skill_id), "%s ids should include the primary skill" % label)
		_expect_eq(slot_count, 1, "%s slot count should open with a primary skill" % label)
		_expect_eq(int(levels.get(skill_id, 0)), level, "%s level map should mirror primary level" % label)
	if channel == "active":
		var expected_skill_name := ""
		if skill_id != "":
			expected_skill_name = str(LingpetCatalog.get_active_skill_entry(skill_id).get("name", ""))
		_expect_str(str(runtime_snapshot.get("companion_skill_id", "")), skill_id, "%s rail/TAB skill id should mirror loadout" % label)
		_expect_str(str(runtime_snapshot.get("companion_skill_name", "")), expected_skill_name, "%s rail/TAB skill name should mirror catalog" % label)


func _vector2_distance(a: Variant, b: Variant) -> float:
	if not (a is Vector2) or not (b is Vector2):
		return INF
	return (a as Vector2).distance_to(b as Vector2)


func _sheet_frame_motion_score(path: String, frame_a: int, frame_b: int, draw_size: int) -> float:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		return -1.0
	var cols := 5
	var rows := 5
	var cell_w: int = int(image.get_width() / cols)
	var cell_h: int = int(image.get_height() / rows)
	if cell_w <= 0 or cell_h <= 0:
		return -1.0
	var safe_a := clampi(frame_a, 0, cols * rows - 1)
	var safe_b := clampi(frame_b, 0, cols * rows - 1)
	var region_a := image.get_region(Rect2i((safe_a % cols) * cell_w, int(safe_a / cols) * cell_h, cell_w, cell_h))
	var region_b := image.get_region(Rect2i((safe_b % cols) * cell_w, int(safe_b / cols) * cell_h, cell_w, cell_h))
	var target_size := maxi(8, draw_size)
	region_a.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	region_b.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	var score := 0.0
	for y in range(0, target_size, 2):
		for x in range(0, target_size, 2):
			var color_a: Color = region_a.get_pixel(x, y)
			var color_b: Color = region_b.get_pixel(x, y)
			score += absf(color_a.r - color_b.r)
			score += absf(color_a.g - color_b.g)
			score += absf(color_a.b - color_b.b)
			score += absf(color_a.a - color_b.a)
	return score


func _image_alpha_bounds(image: Image, alpha_threshold: float = 16.0 / 255.0) -> Rect2i:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > alpha_threshold:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _signed_angle_delta(from_angle: float, to_angle: float) -> float:
	return fposmod(to_angle - from_angle + PI, TAU) - PI


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


func _verify_affinity_store_not_production_dependency() -> void:
	var script_paths := _collect_gd_script_paths("res://scripts")
	_expect(not script_paths.is_empty(), "production affinity-store scan should find scripts")
	for path in script_paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("LingpetAffinityStore") < 0, "%s should not preload or use LingpetAffinityStore after the v5 meta-only split" % path)
		_expect(source.find("lingpet_affinity_store") < 0, "%s should not request the removed lingpet_affinity_store module key after the v5 meta-only split" % path)


func _collect_gd_script_paths(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var path := root_path.path_join(entry)
		if dir.current_is_dir():
			result.append_array(_collect_gd_script_paths(path))
		elif entry.ends_with(".gd"):
			result.append(path)
	dir.list_dir_end()
	return result


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


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


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


func _smoke_save_path(slug: String) -> String:
	# 격리 worktree(신선 체크아웃)에는 미추적 res://.tmp가 없어 ConfigFile.save가
	# 통째로 실패한다 — 저장 레그가 환경에 기대지 않도록 여기서 보장한다.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	return "res://.tmp/lingpet_egg_runtime_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# 피격 넉백 씰(2026-07-06 전시 후속, WIP 파괴 후 재구현): counted 비최종
# 히트는 접촉 반대방향으로 굴러가며 튕겨나가고(dash 임펄스 레인 재사용),
# 최종 히트(셸브레이크 안무 소유)와 서브공(타격판정 없음)은 임펄스가
# 없어야 한다. ⚠️크랙 히트 후 알이 미끄러지므로 다타격 조준은 반드시
# owner.lingpet_egg_pos 신선 재독으로 해야 한다.
func _verify_egg_ball_hit_knockback_impulse() -> void:
	for direction_info in [[-20.0, 1.0], [20.0, -1.0]]:
		var contact_dx: float = float(direction_info[0])
		var expected_sign: float = float(direction_info[1])
		var owner := FakeOwner.new()
		var runtime: Object = LingpetEggRuntime.new()
		runtime.update(0.0, owner)
		var egg_state: Object = runtime.get("_egg_state")
		egg_state.set_required_hits(3)
		owner.player_pos = Vector2(-500.0, 700.0)
		var egg_pos: Vector2 = owner.lingpet_egg_pos
		owner.ball_active = true
		owner.ball_serve_origin = "boss"
		owner.ball_pos = egg_pos + Vector2(contact_dx, -8.0)
		owner.ball_vel = Vector2(0.0, 12.0)
		runtime.update(0.0, owner)
		_expect(int(owner.lingpet_hatch_hits) == 1, "knockback leg: contact should count the crack hit (dx=%.0f)" % contact_dx)
		var snapshot: Dictionary = runtime.get_snapshot()
		_expect(
			signf(float(snapshot.get("egg_dash_vx", 0.0))) == expected_sign,
			"counted crack hit should skid the egg away from the contact side (dx=%.0f)" % contact_dx
		)
		_expect(
			signf(float(snapshot.get("egg_wobble_vel", 0.0))) == expected_sign,
			"counted crack hit should wobble the egg toward the skid direction (dx=%.0f)" % contact_dx
		)
		var start_x: float = owner.lingpet_egg_pos.x
		for _frame_index in range(600):
			runtime.update(1.0 / 60.0, owner)
		var skid: float = (owner.lingpet_egg_pos.x - start_x) * expected_sign
		_expect(skid > 25.0, "ball-hit knockback should visibly skid the egg (>25px, got %.1f)" % skid)
		var settled: Dictionary = runtime.get_snapshot()
		_expect(
			is_equal_approx(float(settled.get("egg_dash_vx", 1.0)), 0.0),
			"knockback impulse should be spent after the skid settles (dx=%.0f)" % contact_dx
		)
		_expect(
			is_equal_approx(float(settled.get("egg_roll_angle", 1.0)), 0.0),
			"egg should settle upright after the knockback skid (dx=%.0f)" % contact_dx
		)

	var final_owner := FakeOwner.new()
	var final_runtime: Object = LingpetEggRuntime.new()
	final_runtime.update(0.0, final_owner)
	var final_state: Object = final_runtime.get("_egg_state")
	final_state.set_required_hits(1)
	final_owner.ball_active = true
	final_owner.ball_serve_origin = "boss"
	final_owner.ball_pos = final_owner.lingpet_egg_pos + Vector2(-20.0, -8.0)
	final_owner.ball_vel = Vector2(0.0, 12.0)
	final_runtime.update(0.0, final_owner)
	_expect(
		is_equal_approx(float(final_state.dash_vx), 0.0),
		"the FINAL counted hit must not apply the knockback impulse (shell-break choreography owns motion)"
	)

	var serve_owner := FakeOwner.new()
	var serve_runtime: Object = LingpetEggRuntime.new()
	serve_runtime.update(0.0, serve_owner)
	serve_owner.ball_active = true
	serve_owner.ball_serve_origin = "player"
	serve_owner.ball_pos = serve_owner.lingpet_egg_pos + Vector2(-20.0, -8.0)
	serve_owner.ball_vel = Vector2(0.0, 12.0)
	serve_runtime.update(0.0, serve_owner)
	var serve_state: Object = serve_runtime.get("_egg_state")
	_expect(
		is_equal_approx(float(serve_state.dash_vx), 0.0),
		"a player-serve pass-through must not apply any knockback impulse"
	)

	# 데드센터 접촉(리뷰 P2): 바운스 반사가 vx를 0으로 만들어도 넉백은
	# 반사 전 진입 방향(+7 → 오른쪽 스키드)을 따라야 한다.
	var center_owner := FakeOwner.new()
	var center_runtime: Object = LingpetEggRuntime.new()
	center_runtime.update(0.0, center_owner)
	center_runtime.get("_egg_state").set_required_hits(3)
	center_owner.player_pos = Vector2(-500.0, 700.0)
	center_owner.ball_active = true
	center_owner.ball_serve_origin = "boss"
	center_owner.ball_pos = center_owner.lingpet_egg_pos + Vector2(0.0, -8.0)
	center_owner.ball_vel = Vector2(7.0, 12.0)
	center_runtime.update(0.0, center_owner)
	_expect(
		float(center_runtime.get_snapshot().get("egg_dash_vx", 0.0)) > 0.0,
		"dead-center hit must skid along the PRE-bounce entry direction (reflected vx=0 must not erase it)"
	)

	# 반대 잔여 모멘텀(리뷰 P2): dash_vx=+16으로 미끄러지는 중 오른쪽 피격
	# (기대 방향 −)이면 단순 가산(+10)이 아니라 부호가 반드시 −여야 한다.
	var momentum_owner := FakeOwner.new()
	var momentum_runtime: Object = LingpetEggRuntime.new()
	momentum_runtime.update(0.0, momentum_owner)
	var momentum_state: Object = momentum_runtime.get("_egg_state")
	momentum_state.set_required_hits(3)
	momentum_owner.player_pos = Vector2(-500.0, 700.0)
	momentum_state.dash_vx = 16.0
	momentum_owner.ball_active = true
	momentum_owner.ball_serve_origin = "boss"
	momentum_owner.ball_pos = momentum_owner.lingpet_egg_pos + Vector2(20.0, -8.0)
	momentum_owner.ball_vel = Vector2(0.0, 12.0)
	momentum_runtime.update(0.0, momentum_owner)
	_expect(
		float(momentum_state.dash_vx) < 0.0,
		"a fresh hit must override opposing residual momentum (post-hit dash_vx sign == intent direction)"
	)


# 크랙 PNG 오버레이 씰(2026-07-06 퀄업 재배선): 파일 존재(부재 경로를
# per-frame draw에 물리면 재-stat 트랩)+프리웜 실로드+스테이지 클램프+
# 구조(오버레이 관통·절차 폴백·회전쿼드 동일변환·셸브레이크 누적 유지).
func _verify_egg_crack_overlay_assets_and_prewarm() -> void:
	for crack_path: String in LingpetEggFieldRenderer.EGG_CRACK_STAGE_TEXTURE_PATHS:
		_expect(ResourceLoader.exists(crack_path), "crack overlay texture must exist on disk: %s" % crack_path)
	var renderer := LingpetEggFieldRenderer.new()
	renderer.prewarm()
	var stage1: Texture2D = renderer._get_cached_crack_texture(0)
	var stage2: Texture2D = renderer._get_cached_crack_texture(1)
	_expect(stage1 != null, "prewarm should load the stage-1 crack overlay texture")
	_expect(stage2 != null, "prewarm should load the stage-2 crack overlay texture")
	_expect(renderer._get_cached_crack_texture(99) == stage2, "crack stage lookup must clamp to the last stage (3-hit eggs)")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
	var draw_body := _function_body(renderer_source, "func draw_egg(")
	_expect(draw_body.find("_draw_egg_crack_overlay(") >= 0, "draw_egg must route hit cracks through the PNG overlay")
	var overlay_body := _function_body(renderer_source, "func _draw_egg_crack_overlay(")
	_expect(overlay_body.find("_draw_egg_crack_light(") >= 0, "crack overlay must keep the procedural fallback for load failure")
	_expect(overlay_body.find("_draw_rotated_texture(") >= 0, "crack overlay must ride the same rotated-quad transform as the egg (rotation sync)")
	var break_body := _function_body(renderer_source, "func draw_hatch_break_egg(")
	_expect(break_body.find("_draw_egg_crack_overlay(") >= 0, "shell-break must keep drawing the accumulated hit cracks")
