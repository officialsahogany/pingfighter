extends RefCounted

const HelperRegistry := preload("res://scripts/items/mythic_item_helper_registry.gd")
const AutoDefenseRuntime := preload("res://scripts/items/mythic_item_auto_defense_runtime.gd")
const VenomMistRuntime := preload("res://scripts/items/mythic_item_venom_mist_runtime.gd")
const RainbowFurGloveRuntime := preload("res://scripts/items/mythic_item_rainbow_fur_glove_runtime.gd")
const AdversityArmorRuntime := preload("res://scripts/items/mythic_item_adversity_armor_runtime.gd")
const ShrapnelArmorRuntime := preload("res://scripts/items/mythic_item_shrapnel_armor_runtime.gd")
const KneePadsRuntime := preload("res://scripts/items/mythic_item_knee_pads_runtime.gd")
const SoulBurstRuntime := preload("res://scripts/items/mythic_item_soul_burst_runtime.gd")
const FoulWhistleRuntime := preload("res://scripts/items/mythic_item_foul_whistle_runtime.gd")
const HermesShoesRuntime := preload("res://scripts/items/mythic_item_hermes_shoes_runtime.gd")
const CelestialArmorRuntime := preload("res://scripts/items/mythic_item_celestial_armor_runtime.gd")
const ITEM_MEGINGJORD := "megingjord"
const ITEM_DOWSING_PENDULUM := "dowsing_pendulum"
const ITEM_DOWSING_GOGGLES := "dowsing_goggles"
const ITEM_SPEEDBOOTS := "speedboots"
const ITEM_SPEEDGEAR := "speedgear"
const ITEM_GRAVITYBELT := "gravitybelt"
const ITEM_SPIKEBOOTS := "spikeboots"
const ITEM_BULLETPROOF_HAT := "bulletproof_hat"
const ITEM_SPIKED_HELMET := "spiked_helmet"
const ITEM_GOLD_BAR := "gold_bar"
const ITEM_ADVERSITY_ARMOR := "adversity_armor"
const ITEM_SHRAPNEL_ARMOR := "shrapnel_armor"
const ITEM_SMARTPHONE := "smartphone"
const ITEM_VENOM_MIST_GAUNTLET := "venom_mist_gauntlet"
const ITEM_REINFORCED_BOOMERANG_GAUNTLET := "reinforced_boomerang_gauntlet"
const ITEM_BOOMERANG := "boomerang"
const ITEM_RAINBOW_FUR_GLOVE := "rainbow_fur_glove"
const ITEM_KNEE_PADS := "knee_pads"
const ITEM_DASHGEAR := "dashgear"
const ITEM_SOUL_BURST := "soul_burst"
const ITEM_BULKUP := "bulkup"
const ITEM_DASHHOLDER := "dashholder"
const ITEM_RAGNAROK_HAMMER := "ragnarok_hammer"
const ITEM_HERMES_SHOES := "hermes_shoes"
const ITEM_POSEIDON_TRIDENT := "poseidon_trident"
const ITEM_HEAVENLY_CAPE := "heavenly_cape"
const ITEM_HORN_STRAWBERRY_MASK := "horn_strawberry_mask"
const ITEM_CELESTIAL_ARMOR := "celestial_armor"
const ITEM_BAAL_BOOTS := "baal_boots"
const ARM_SLOT_KEYS := ["left_arm", "right_arm"]
const ACCESSORY_SLOT_KEYS := ["accessory1", "accessory2", "accessory3", "accessory4"]
const DOWSING_PENDULUM_ATTRACTION_FORCE := 3.5
const DOWSING_PENDULUM_MIN_DISTANCE := 30.0
const DOWSING_PENDULUM_MAX_SPEED := 8.0
const RAGNAROK_BOSS_KNOCKBACK_FRAMES := 36.0
const RAGNAROK_BOSS_KNOCKBACK_DECAY := 0.86
const RAGNAROK_STUN_BALL_EFFECT_DURATION := 0.80
const RAGNAROK_IMPACT_EFFECT_DURATION := 0.74
const RAGNAROK_SPARK_COUNT := 12
const RAGNAROK_PARTICLE_ALPHA_CUTOFF := 0.02
const RAGNAROK_BASE_KNOCKBACK_POWER := 18.326
const RAGNAROK_SPEED_WEIGHT := 0.0748
const RAGNAROK_MAX_KNOCKBACK_POWER := 25.823
const RAGNAROK_BOSS_KNOCKBACK_MULTIPLIER := 2.1
const RAGNAROK_CHARGE_SHAKE_AMOUNT := 0.08
const RAGNAROK_CHARGE_SHAKE_INTENSITY := 2.4
const RAGNAROK_IMPACT_SHAKE_AMOUNT := 1.38
const RAGNAROK_IMPACT_SHAKE_INTENSITY := 22.0
const RAGNAROK_ELECTRIC_STUN_DRIFT_SPEED := 0.36
const RAGNAROK_ELECTRIC_STUN_INTENSITY := 1.15
const RAGNAROK_BOSS_STUN_FRAME_MSEC := 100
const RAGNAROK_COUNTER_SPEED_RETENTION := 0.58
const RAGNAROK_COUNTER_MAX_SPEED := 20.0
const RAGNAROK_COUNTER_MIN_SPEED := 7.0
const RAGNAROK_COUNTER_MAX_HORIZONTAL_RATIO := 0.42
const RAGNAROK_SPEED_CAP_BONUS := 6.0
const RAGNAROK_COUNTER_MIN_DOWNWARD_RATIO := 0.82
const POSEIDON_VORTEX_OFFSET_X := 120.0
const POSEIDON_VORTEX_MAX_HEIGHT := 350.0
const POSEIDON_VORTEX_GROW_FRAMES := 18.0
const POSEIDON_VORTEX_HOLD_FRAMES := 48.0
const POSEIDON_VORTEX_TOTAL_FRAMES := 96.0
const POSEIDON_INITIAL_PARTICLES_PER_SIDE := 18
const POSEIDON_MAX_PARTICLES := 84
const POSEIDON_REENTRY_COOLDOWN_FRAMES := 60.0
const POSEIDON_WATER_TRAIL_LIFE_FRAMES := 30.0
const POSEIDON_WATER_TRAIL_MAX_POINTS := 24
const POSEIDON_REFLECT_MIN_SPEED := 18.0
const POSEIDON_REFLECT_MAX_SPEED := 34.0
const POSEIDON_REFLECT_MAX_X_SPEED := 24.0
const POSEIDON_REFLECT_MIN_UPWARD_SPEED := 14.0
const POSEIDON_FEEDBACK_SHAKE_AMOUNT := 0.16
const POSEIDON_FEEDBACK_SHAKE_INTENSITY := 4.8
const POSEIDON_PARTICLE_RADIUS_DECAY := 0.98
const POSEIDON_PARTICLE_RISE_SPEED := 3.0
const POSEIDON_DROPLET_GRAVITY := 0.5
const POSEIDON_DROPLET_SPAWN_CHANCE := 0.35
const POSEIDON_DROPLET_MIN_PER_TICK := 1
const POSEIDON_DROPLET_MAX_PER_TICK := 3
const POSEIDON_EXPLOSION_PARTICLE_COUNT := 8
const POSEIDON_EXPLOSION_FLASH_DURATION := 0.4
const POSEIDON_EXPLOSION_VEL_DAMP := 0.92
const POSEIDON_CAPTURE_DURATION_FRAMES := 34.0
const POSEIDON_CAPTURE_MIN_TURNS := 2.0
const POSEIDON_CAPTURE_MAX_TURNS := 3.0
const POSEIDON_CAPTURE_MIN_RADIUS := 42.0
const POSEIDON_CAPTURE_RELEASE_BOOST := 1.35
const POSEIDON_CAPTURE_RELEASE_SPREAD := PI / 4.0
const BAAL_TRIGGER_DELAY_FRAMES := 150.0
const BAAL_TELEGRAPH_FRAMES := 48.0
const BAAL_ABSORB_FRAMES := 150.0
const BAAL_WIND_SPEED_MULTIPLIER := 1.5
const BAAL_RAIN_SLOW_FRAMES := 180.0
const BAAL_RAIN_SLOW_MULTIPLIER := 0.70
const BAAL_BALL_MARK_FRAMES := 240.0
const BAAL_PROJECTILE_LIFE_FRAMES := 150.0
const BAAL_PROJECTILE_SPEED := 8.5
const BAAL_KNOCKBACK_FRAMES := 34.0
const BAAL_KNOCKBACK_DECAY := 0.88
const BAAL_KNOCKBACK_POWER := 17.0
const BAAL_ABSORB_PARTICLE_FALLBACK_COUNT := 42
const BAAL_AURA_PARTICLE_MAX := 42
const BOOMERANG_ICON_PATH := "res://assets/sprites/items/boomerang.png"
const BOOMERANG_METAL_ICON_PATH := "res://assets/sprites/items/boomerang_metal.png"
const BASE_SPECIAL_GAUGE_MAX := 500.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const CONTEXT_CONSTANTS := {
	"accessory_slot_keys": ACCESSORY_SLOT_KEYS,
	"arm_slot_keys": ARM_SLOT_KEYS,
	"dowsing_pendulum_attraction_force": DOWSING_PENDULUM_ATTRACTION_FORCE,
	"dowsing_pendulum_min_distance": DOWSING_PENDULUM_MIN_DISTANCE,
	"dowsing_pendulum_max_speed": DOWSING_PENDULUM_MAX_SPEED,
	"base_special_gauge_max": BASE_SPECIAL_GAUGE_MAX,
	"boomerang_icon_path": BOOMERANG_ICON_PATH,
	"boomerang_metal_icon_path": BOOMERANG_METAL_ICON_PATH,
	"field_width": FIELD_WIDTH,
	"field_height": FIELD_HEIGHT,
	"item_baal_boots": ITEM_BAAL_BOOTS,
	"item_celestial_armor": ITEM_CELESTIAL_ARMOR,
	"item_dowsing_goggles": ITEM_DOWSING_GOGGLES,
	"item_hermes_shoes": ITEM_HERMES_SHOES,
	"item_horn_strawberry_mask": ITEM_HORN_STRAWBERRY_MASK,
	"item_megingjord": ITEM_MEGINGJORD,
	"item_poseidon_trident": ITEM_POSEIDON_TRIDENT,
	"item_ragnarok_hammer": ITEM_RAGNAROK_HAMMER,
	"item_smartphone": ITEM_SMARTPHONE,
	"player_base_paddle_width": PLAYER_BASE_PADDLE_WIDTH,
	"player_base_paddle_height": PLAYER_BASE_PADDLE_HEIGHT,
	"venom_mist_radius": VenomMistRuntime.RADIUS,
	"baal_rain_slow_multiplier": BAAL_RAIN_SLOW_MULTIPLIER,
	"ragnarok_boss_stun_frame_msec": RAGNAROK_BOSS_STUN_FRAME_MSEC,
}
const RAGNAROK_CONSTANTS := {
	"boss_knockback_frames": RAGNAROK_BOSS_KNOCKBACK_FRAMES,
	"boss_knockback_decay": RAGNAROK_BOSS_KNOCKBACK_DECAY,
	"spark_count": RAGNAROK_SPARK_COUNT,
	"base_knockback_power": RAGNAROK_BASE_KNOCKBACK_POWER,
	"speed_weight": RAGNAROK_SPEED_WEIGHT,
	"max_knockback_power": RAGNAROK_MAX_KNOCKBACK_POWER,
	"boss_knockback_multiplier": RAGNAROK_BOSS_KNOCKBACK_MULTIPLIER,
	"charge_shake_amount": RAGNAROK_CHARGE_SHAKE_AMOUNT,
	"charge_shake_intensity": RAGNAROK_CHARGE_SHAKE_INTENSITY,
	"impact_shake_amount": RAGNAROK_IMPACT_SHAKE_AMOUNT,
	"impact_shake_intensity": RAGNAROK_IMPACT_SHAKE_INTENSITY,
	"electric_stun_drift_speed": RAGNAROK_ELECTRIC_STUN_DRIFT_SPEED,
	"counter_speed_retention": RAGNAROK_COUNTER_SPEED_RETENTION,
	"counter_max_speed": RAGNAROK_COUNTER_MAX_SPEED,
	"counter_min_speed": RAGNAROK_COUNTER_MIN_SPEED,
	"counter_max_horizontal_ratio": RAGNAROK_COUNTER_MAX_HORIZONTAL_RATIO,
	"counter_min_downward_ratio": RAGNAROK_COUNTER_MIN_DOWNWARD_RATIO,
}
const POSEIDON_CONSTANTS := {
	"vortex_offset_x": POSEIDON_VORTEX_OFFSET_X,
	"vortex_max_height": POSEIDON_VORTEX_MAX_HEIGHT,
	"vortex_grow_frames": POSEIDON_VORTEX_GROW_FRAMES,
	"vortex_hold_frames": POSEIDON_VORTEX_HOLD_FRAMES,
	"vortex_total_frames": POSEIDON_VORTEX_TOTAL_FRAMES,
	"initial_particles_per_side": POSEIDON_INITIAL_PARTICLES_PER_SIDE,
	"max_particles": POSEIDON_MAX_PARTICLES,
	"reentry_cooldown_frames": POSEIDON_REENTRY_COOLDOWN_FRAMES,
	"water_trail_life_frames": POSEIDON_WATER_TRAIL_LIFE_FRAMES,
	"water_trail_max_points": POSEIDON_WATER_TRAIL_MAX_POINTS,
	"reflect_min_speed": POSEIDON_REFLECT_MIN_SPEED,
	"reflect_max_speed": POSEIDON_REFLECT_MAX_SPEED,
	"reflect_max_x_speed": POSEIDON_REFLECT_MAX_X_SPEED,
	"reflect_min_upward_speed": POSEIDON_REFLECT_MIN_UPWARD_SPEED,
	"feedback_shake_amount": POSEIDON_FEEDBACK_SHAKE_AMOUNT,
	"feedback_shake_intensity": POSEIDON_FEEDBACK_SHAKE_INTENSITY,
	"particle_radius_decay": POSEIDON_PARTICLE_RADIUS_DECAY,
	"particle_rise_speed": POSEIDON_PARTICLE_RISE_SPEED,
	"droplet_gravity": POSEIDON_DROPLET_GRAVITY,
	"droplet_spawn_chance": POSEIDON_DROPLET_SPAWN_CHANCE,
	"droplet_min_per_tick": POSEIDON_DROPLET_MIN_PER_TICK,
	"droplet_max_per_tick": POSEIDON_DROPLET_MAX_PER_TICK,
	"explosion_particle_count": POSEIDON_EXPLOSION_PARTICLE_COUNT,
	"explosion_flash_duration": POSEIDON_EXPLOSION_FLASH_DURATION,
	"explosion_vel_damp": POSEIDON_EXPLOSION_VEL_DAMP,
	"capture_duration_frames": POSEIDON_CAPTURE_DURATION_FRAMES,
	"capture_min_turns": POSEIDON_CAPTURE_MIN_TURNS,
	"capture_max_turns": POSEIDON_CAPTURE_MAX_TURNS,
	"capture_min_radius": POSEIDON_CAPTURE_MIN_RADIUS,
	"capture_release_boost": POSEIDON_CAPTURE_RELEASE_BOOST,
	"capture_release_spread": POSEIDON_CAPTURE_RELEASE_SPREAD,
}
const BAAL_BOOTS_CONSTANTS := {
	"trigger_delay_frames": BAAL_TRIGGER_DELAY_FRAMES,
	"telegraph_frames": BAAL_TELEGRAPH_FRAMES,
	"absorb_frames": BAAL_ABSORB_FRAMES,
	"wind_speed_multiplier": BAAL_WIND_SPEED_MULTIPLIER,
	"rain_slow_frames": BAAL_RAIN_SLOW_FRAMES,
	"ball_mark_frames": BAAL_BALL_MARK_FRAMES,
	"projectile_life_frames": BAAL_PROJECTILE_LIFE_FRAMES,
	"projectile_speed": BAAL_PROJECTILE_SPEED,
	"knockback_frames": BAAL_KNOCKBACK_FRAMES,
	"knockback_decay": BAAL_KNOCKBACK_DECAY,
	"knockback_power": BAAL_KNOCKBACK_POWER,
	"absorb_particle_fallback_count": BAAL_ABSORB_PARTICLE_FALLBACK_COUNT,
	"aura_particle_max": BAAL_AURA_PARTICLE_MAX,
	"field_width": FIELD_WIDTH,
	"field_height": FIELD_HEIGHT,
	"base_special_gauge_max": BASE_SPECIAL_GAUGE_MAX,
}
const FIELD_EFFECT_CONSTANTS := {
	"field_size": Vector2(FIELD_WIDTH, FIELD_HEIGHT),
	"hermes_trail_life_frames": HermesShoesRuntime.TRAIL_LIFE_FRAMES,
	"hermes_move_trail_threshold": HermesShoesRuntime.MOVE_TRAIL_THRESHOLD,
	"celestial_wave_radius_max": CelestialArmorRuntime.WAVE_RADIUS_MAX,
	"celestial_shard_count": CelestialArmorRuntime.SHARD_COUNT,
	"celestial_arc_segments": CelestialArmorRuntime.ARC_SEGMENTS,
	"venom_mist_radius": VenomMistRuntime.RADIUS,
	"foul_whistle_total_frames": FoulWhistleRuntime.TOTAL_FRAMES,
	"foul_whistle_referee_frame_count": FoulWhistleRuntime.REFEREE_FRAME_COUNT,
	"foul_whistle_referee_frame_frames": FoulWhistleRuntime.REFEREE_FRAME_FRAMES,
	"sensor_auto_dash_effect_frames": AutoDefenseRuntime.SENSOR_AUTO_DASH_EFFECT_FRAMES,
	"ragnarok_particle_alpha_cutoff": RAGNAROK_PARTICLE_ALPHA_CUTOFF,
	"poseidon_explosion_flash_duration": POSEIDON_EXPLOSION_FLASH_DURATION,
	"rainbow_fur_glove_colors": RainbowFurGloveRuntime.COLORS,
	"shrapnel_armor_flash_frames": ShrapnelArmorRuntime.FLASH_FRAMES,
	"shrapnel_armor_shard_life_frames": ShrapnelArmorRuntime.SHARD_LIFE_FRAMES,
	"shrapnel_armor_boss_impact_frames": ShrapnelArmorRuntime.BOSS_IMPACT_FRAMES,
	"knee_pads_flash_duration_frames": KneePadsRuntime.FLASH_DURATION_FRAMES,
	"soul_burst_particle_alpha_cutoff": SoulBurstRuntime.PARTICLE_ALPHA_CUTOFF,
}

var catalog: Object = null
var audio_router: Object = null
var gauge_feedback: Object = null
var context_builder: Object = null
var roll_editor_runtime: Object = null
var equipment_index: Object = null
var equipment_facade: Object = null
var ownership_runtime: Object = null
var auto_defense_runtime: Object = null
var ai_assist_runtime: Object = null
var dowsing_runtime: Object = null
var perk_choice_runtime: Object = null
var defense_gear_runtime: Object = null
var capacity_gauge_runtime: Object = null
var resource_bonus_runtime: Object = null
var throw_bonus_runtime: Object = null
var cooldown_gear_runtime: Object = null
var progression_bonus_runtime: Object = null
var venom_mist_runtime: Object = null
var rainbow_fur_glove_runtime: Object = null
var adversity_armor_runtime: Object = null
var shrapnel_armor_runtime: Object = null
var ragnarok_runtime: Object = null
var poseidon_runtime: Object = null
var soul_burst_runtime: Object = null
var knee_pads_runtime: Object = null
var stat_bonus_runtime: Object = null
var pause_gate: Object = null
var update_gate: Object = null
var update_runtime: Object = null
var lifecycle_runtime: Object = null
var owner_syncer: Object = null
var pickup_bonus: Object = null
var roll_query: Object = null
var stage_immunity: Object = null
var debug_management_menu: Object = null
var debug_management_facade: Object = null
var activation_effect_renderer: Object = null
var activation_effect_runtime: Object = null
var field_effect_visibility: Object = null
var field_effect_renderer: Object = null
var support_effect_renderer: Object = null
var snapshot_builder: Object = null
var acquisition_cinematic_runtime: Object = null
var foul_whistle_runtime: Object = null
var acquisition_cinematic: Object = null
var inventory_items: Array = []
var equipped_items: Dictionary = {}
var next_inventory_id := 1
var megingjord_extra_pick_count := 0
var dowsing_goggles_bonus_triggered := false
var activation_started_msec := -1000000
var activation_particles: Array = []
var activation_bolts: Array = []
var ragnarok_stun_ball_active := false
var ragnarok_stun_attempted_this_rally := false
var ragnarok_original_speed := 0.0
var ragnarok_first_shot_speed := 0.0
var ragnarok_ball_started_msec := -1000000
var ragnarok_boss_stun_timer_frames := 0.0
var ragnarok_boss_knockback_timer_frames := 0.0
var ragnarok_boss_knockback_vel := 0.0
var ragnarok_boss_electric_drift_vel := 0.0
var ragnarok_impact_started_msec := -1000000
var ragnarok_impact_center := Vector2.ZERO
var ragnarok_stun_target_size := Vector2(100.0, 40.0)
var ragnarok_sparks: Array = []
var ragnarok_shock_loop_active := false
var ragnarok_audio: Object = null
var poseidon_effect_cooldown_frames := 0.0
var poseidon_vortex_active := false
var poseidon_vortex_timer_frames := 0.0
var poseidon_vortex_left_pos := Vector2.ZERO
var poseidon_vortex_right_pos := Vector2.ZERO
var poseidon_vortex_left_height := 0.0
var poseidon_vortex_right_height := 0.0
var poseidon_vortex_spin_speed := 0.0
var poseidon_vortex_reentry_cooldown_frames := 0.0
var poseidon_vortex_affected := false
var poseidon_dash_was_active := false
var poseidon_dash_was_recovering := false
var poseidon_last_dash_direction := 0.0
var poseidon_particles: Array = []
var poseidon_water_trail: Array = []
var poseidon_water_trail_active := false
var poseidon_audio: Object = null
var poseidon_player_center := Vector2.ZERO
var poseidon_explosion_active := false
var poseidon_explosion_timer := 0.0
var poseidon_explosion_particles: Array = []
var poseidon_capture_active := false
var poseidon_capture_timer_frames := 0.0
var poseidon_capture_duration_frames := 0.0
var poseidon_capture_base_pos := Vector2.ZERO
var poseidon_capture_start_angle := 0.0
var poseidon_capture_radius := 0.0
var poseidon_capture_turns := 0.0
var poseidon_capture_spin_sign := 1.0
var poseidon_capture_original_speed := 0.0
var poseidon_capture_last_pos := Vector2.ZERO
var knee_pads_half_dash_consumed := false
var knee_pads_flash_timer_frames := 0.0
var knee_pads_flash_center := Vector2.ZERO
var knee_pads_particles: Array = []
var soul_burst_effect_timer_frames := 0.0
var soul_burst_dash_active := false
var soul_burst_center := Vector2.ZERO
var soul_burst_direction := 0.0
var soul_burst_particles: Array = []
var soul_burst_shockwaves: Array = []
var soul_burst_wind_trails: Array = []
var foul_whistle_state: Object = null
var revival_state: Object = null
var sensor_enabled := true
var sensor_cooldown_timer_frames := 0.0
var sensor_last_dash_direction := 0.0
var sensor_auto_dash_effect_timer_frames := 0.0
var sensor_auto_dash_center := Vector2.ZERO
var smartphone_cooldown_frames := 0.0
var smartphone_last_auto_item := ""
var venom_mist_ball_poisoned := false
var venom_mist_field_active := false
var venom_mist_timer_frames := 0.0
var venom_mist_duration_frames := 0.0
var venom_mist_center := Vector2.ZERO
var venom_mist_particles: Array = []
var venom_mist_gauge_drain_accumulator := 0.0
var venom_mist_boss_in_field := false
var rainbow_fur_glove_aura_timer_frames := 0.0
var rainbow_fur_glove_aura_life_frames := RainbowFurGloveRuntime.AURA_FRAMES
var rainbow_fur_glove_aura_center := Vector2.ZERO
var rainbow_fur_glove_aura_phase := 0.0
var rainbow_fur_glove_particles: Array = []
var rainbow_fur_glove_last_reduction_pct := 0.0
var adversity_armor_pending_invincible := false
var adversity_armor_serve_speed_boost_pending := false
var adversity_armor_invincible_timer_frames := 0.0
var adversity_armor_invincible_total_frames := 0.0
var adversity_armor_flash_timer_frames := 0.0
var adversity_armor_phase := 0.0
var adversity_armor_last_trigger_roll_pct := -1.0
var adversity_armor_last_triggered := false
var adversity_armor_last_reflect_center := Vector2.ZERO
var adversity_armor_aura_particles: Array = []
var adversity_armor_barrier_particles: Array = []
var shrapnel_armor_shards: Array = []
var shrapnel_armor_dust_particles: Array = []
var shrapnel_armor_flash_timer_frames := 0.0
var shrapnel_armor_flash_center := Vector2.ZERO
var shrapnel_armor_boss_impact_timer_frames := 0.0
var shrapnel_armor_boss_impact_center := Vector2.ZERO
var shrapnel_armor_boss_knockback_timer_frames := 0.0
var shrapnel_armor_boss_knockback_vel := 0.0
var shrapnel_armor_boss_stun_timer_frames := 0.0
var shrapnel_armor_last_proc_shard_count := 0
var shrapnel_armor_last_gauge_cost := 0.0
var revival_runtime: Object = null
var celestial_armor_runtime: Object = null
var celestial_armor_state: Object = null
var heavenly_cape_runtime: Object = null
var horn_strawberry_mask_runtime: Object = null
var horn_strawberry_mask_state: Object = null
var horn_strawberry_eat_state: Object = null
var horn_strawberry_field_state: Object = null
var horn_strawberry_horn_charge_state: Object = null
var horn_strawberry_bomb_state: Object = null
var hermes_shoes_runtime: Object = null
var hermes_shoes_state: Object = null
var baal_boots_runtime: Object = null
var baal_boots_effect_renderer: Object = null
var baal_boots_weather_state: Object = null
var baal_boots_effect_state: Object = null
var baal_boots_combat_state: Object = null
var synced_special_gauge_max := BASE_SPECIAL_GAUGE_MAX
var runtime_perk_state_ref: Object = null
var pandora_legacy_runtime: Object = null
var pandora_legacy_choice_builder: Object = null
var pandora_legacy_grant_router: Object = null
var pandora_legacy_pool_builder: Object = null
var pandora_legacy_selection_renderer: Object = null
var pandora_legacy_selection_state: Object = null
var pandora_legacy_icon_texture_cache: Dictionary = {}
var _helper_init_step_index := 0
var _helpers_initialized := false


func prewarm_initialization_step(perform_reset: bool = true) -> bool:
	if _helpers_initialized:
		return true
	if _helper_init_step_index < HelperRegistry.INIT_ORDER.size():
		_init_helper(str(HelperRegistry.INIT_ORDER[_helper_init_step_index]))
		_helper_init_step_index += 1
		return false
	_helpers_initialized = true
	_helper_init_step_index = 0
	if perform_reset:
		reset()
	return true


func reset() -> void:
	_ensure_helpers_ready(false)
	lifecycle_runtime.reset(self, BASE_SPECIAL_GAUGE_MAX, BAAL_BOOTS_CONSTANTS)


func prewarm_assets() -> void:
	_ensure_helpers_ready()
	debug_management_facade.prewarm_assets(self)


func prewarm_acquisition_cinematic(owner: Object = null, registry: Object = null) -> void:
	_ensure_helpers_ready()
	acquisition_cinematic_runtime.prewarm(self, owner, registry)


func prewarm_acquisition_cinematic_assets() -> void:
	_ensure_helpers_ready()
	while not prewarm_acquisition_cinematic_assets_step():
		pass


func prewarm_acquisition_cinematic_assets_step() -> bool:
	_ensure_helpers_ready()
	if acquisition_cinematic_runtime != null and acquisition_cinematic_runtime.has_method("prewarm_static_assets_step"):
		return bool(acquisition_cinematic_runtime.prewarm_static_assets_step())
	if acquisition_cinematic_runtime != null and acquisition_cinematic_runtime.has_method("prewarm_static_assets"):
		acquisition_cinematic_runtime.prewarm_static_assets()
	return true


func build_starting_equipment_slots() -> Dictionary:
	_ensure_helpers_ready()
	return {}


func build_starting_inventory() -> Array:
	_ensure_helpers_ready()
	return []


func has_owned_item_name(item_name: String) -> bool:
	_ensure_helpers_ready()
	return ownership_runtime.has_owned_item_name(self, item_name)


func should_skip_one_time_passive_spawn(item_name: String) -> bool:
	_ensure_helpers_ready()
	return ownership_runtime.should_skip_one_time_passive_spawn(self, item_name)


func reset_round(registry: Object = null) -> void:
	_ensure_helpers_ready()
	lifecycle_runtime.reset_round(self, registry, BAAL_BOOTS_CONSTANTS)


func refresh_runtime_perk_scaling(owner: Object = null, registry: Object = null) -> void:
	_ensure_helpers_ready()
	owner_syncer.sync_runtime_perk_state_ref(self, registry)
	if owner != null:
		_sync_owner(owner, registry)


func acquire_item(
	item_name: String,
	owner: Object,
	registry: Object = null,
	roll_overrides: Dictionary = {},
	auto_equip: bool = true,
	play_pickup_sound: bool = false,
	acquired_item_data: Dictionary = {}
) -> int:
	_ensure_helpers_ready()
	return equipment_facade.acquire_item(
		self,
		item_name,
		owner,
		registry,
		roll_overrides,
		auto_equip,
		play_pickup_sound,
		acquired_item_data,
		CONTEXT_CONSTANTS,
		BAAL_BOOTS_CONSTANTS
	)


func equip_item(
	item_name: String,
	owner: Object,
	registry: Object = null,
	roll_overrides: Dictionary = {},
	play_pickup_sound: bool = false
) -> bool:
	_ensure_helpers_ready()
	return equipment_facade.equip_item(self, item_name, owner, registry, roll_overrides, play_pickup_sound, CONTEXT_CONSTANTS, BAAL_BOOTS_CONSTANTS)


func unequip_item(item_name: String, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return equipment_facade.unequip_item(self, item_name, owner, registry, CONTEXT_CONSTANTS, BAAL_BOOTS_CONSTANTS)


func equip_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return equipment_facade.equip_inventory_item(self, index, owner, registry, CONTEXT_CONSTANTS, BAAL_BOOTS_CONSTANTS)


func unequip_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return equipment_facade.unequip_inventory_item(self, index, owner, registry, CONTEXT_CONSTANTS, BAAL_BOOTS_CONSTANTS)


func toggle_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return equipment_facade.toggle_inventory_item(self, index, owner, registry, CONTEXT_CONSTANTS, BAAL_BOOTS_CONSTANTS)


func unequip_slot(slot_key: String, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return equipment_facade.unequip_slot(self, slot_key, owner, registry, CONTEXT_CONSTANTS, BAAL_BOOTS_CONSTANTS)


func discard_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return equipment_facade.discard_inventory_item(self, index, owner, registry, CONTEXT_CONSTANTS, BAAL_BOOTS_CONSTANTS)


func debug_toggle_megingjord(owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return ownership_runtime.toggle_inventory_item_by_name(
		self,
		str(CONTEXT_CONSTANTS.get("item_megingjord", "megingjord")),
		owner,
		registry
	)


func debug_toggle_item(item_name: String, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return ownership_runtime.toggle_inventory_item_by_name(self, item_name, owner, registry)


func debug_add_item_to_inventory(item_name: String, owner: Object, registry: Object, roll_overrides: Dictionary = {}) -> bool:
	_ensure_helpers_ready()
	return ownership_runtime.add_inventory_item_for_debug(
		self,
		item_name,
		owner,
		registry,
		roll_overrides
	)


func debug_build_roll_editor_item(item_name: String, roll_overrides: Dictionary = {}) -> Dictionary:
	_ensure_helpers_ready()
	return roll_editor_runtime.build_preview_item(self, item_name, roll_overrides)


func get_debug_item_counts() -> Dictionary:
	_ensure_helpers_ready()
	return ownership_runtime.get_inventory_item_counts(self)


func debug_ensure_item_for_roll_editor(item_name: String, owner: Object, registry: Object) -> int:
	_ensure_helpers_ready()
	return ownership_runtime.ensure_inventory_item_for_roll_editor(self, item_name, owner, registry)


func debug_get_inventory_item(index: int) -> Dictionary:
	_ensure_helpers_ready()
	return ownership_runtime.get_inventory_item(self, index)


func get_inventory_item(index: int) -> Dictionary:
	_ensure_helpers_ready()
	return ownership_runtime.get_inventory_item(self, index)


func debug_adjust_inventory_roll(index: int, option_key: String, delta_steps: int, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return roll_editor_runtime.adjust_inventory_roll(
		self,
		index,
		option_key,
		delta_steps,
		owner,
		registry,
		CONTEXT_CONSTANTS,
		BAAL_BOOTS_CONSTANTS
	)


func get_debug_item_entries() -> Array:
	_ensure_helpers_ready()
	return roll_editor_runtime.get_item_entries(self)


func toggle_debug_management_menu() -> void:
	_ensure_helpers_ready()
	debug_management_facade.toggle_menu(self, 0)


func close_debug_management_menu() -> void:
	_ensure_helpers_ready()
	debug_management_facade.close_menu(self)


func is_debug_management_menu_open() -> bool:
	_ensure_helpers_ready()
	return debug_management_facade.is_menu_open(self)


func handle_debug_management_menu_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	_ensure_helpers_ready()
	return debug_management_facade.handle_menu_input(self, event, owner, registry, view_size)


func draw_debug_management_menu(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	_ensure_helpers_ready()
	debug_management_facade.draw_menu(self, canvas, owner, registry, view_size)


func is_equipped(item_name: String = ITEM_MEGINGJORD) -> bool:
	_ensure_helpers_ready()
	return equipment_index.is_item_equipped(self, item_name)


func on_new_perk_choice_batch(owner: Object = null) -> void:
	_ensure_helpers_ready()
	perk_choice_runtime.on_new_perk_choice_batch(self, owner)


func should_check_extra_pick(choice_id: String) -> bool:
	_ensure_helpers_ready()
	return perk_choice_runtime.should_check_extra_pick(choice_id)


func try_after_perk_choice(choice_id: String, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return perk_choice_runtime.try_after_perk_choice(self, choice_id, owner, registry)


func get_megingjord_extra_pick_chance() -> float:
	_ensure_helpers_ready()
	return perk_choice_runtime.get_megingjord_extra_pick_chance(self)


func is_dowsing_pendulum_equipped() -> bool:
	_ensure_helpers_ready()
	return dowsing_runtime.is_pendulum_equipped(self)


func get_dowsing_pendulum_range() -> float:
	_ensure_helpers_ready()
	return dowsing_runtime.get_pendulum_range(self)


func get_dowsing_pendulum_context() -> Dictionary:
	_ensure_helpers_ready()
	return dowsing_runtime.get_pendulum_context(self, CONTEXT_CONSTANTS)


func is_dowsing_goggles_equipped() -> bool:
	_ensure_helpers_ready()
	return dowsing_runtime.is_goggles_equipped(self)


func is_dowsing_goggles_active() -> bool:
	_ensure_helpers_ready()
	return dowsing_runtime.is_goggles_active(self)


func get_dowsing_goggles_bonus_perk_chance_pct() -> float:
	_ensure_helpers_ready()
	return dowsing_runtime.get_goggles_bonus_perk_chance_pct(self)


func get_runtime_perk_choice_count_bonus(owner: Object = null, registry: Object = null) -> int:
	_ensure_helpers_ready()
	return dowsing_runtime.get_runtime_perk_choice_count_bonus(self, owner, registry)


func was_dowsing_goggles_bonus_triggered() -> bool:
	_ensure_helpers_ready()
	return dowsing_runtime.was_goggles_bonus_triggered(self)


func clear_dowsing_goggles_bonus_trigger(owner: Object = null, registry: Object = null) -> void:
	_ensure_helpers_ready()
	dowsing_runtime.clear_goggles_bonus_trigger(self, owner, registry)


func is_speedboots_equipped() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_speedboots_equipped(self)


func get_speedboots_speed_bonus_pct() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_speedboots_speed_bonus_pct(self)


func is_speedgear_equipped() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_speedgear_equipped(self)


func is_gravitybelt_equipped() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_gravitybelt_equipped(self)


func is_gravitybelt_active() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_gravitybelt_active(self)


func apply_player_movement_config(config: Dictionary) -> void:
	_ensure_helpers_ready()
	stat_bonus_runtime.apply_player_movement_config(self, config)


func get_speedgear_turn_decel_multiplier() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_speedgear_turn_decel_multiplier(self)


func get_player_turn_decel_multiplier() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_player_turn_decel_multiplier(self)


func is_sensor_equipped() -> bool:
	_ensure_helpers_ready()
	return auto_defense_runtime.is_sensor_equipped(self)


func is_sensor_enabled() -> bool:
	_ensure_helpers_ready()
	return auto_defense_runtime.is_sensor_enabled(self)


func set_sensor_enabled(enabled: bool, owner: Object = null, registry: Object = null) -> void:
	_ensure_helpers_ready()
	auto_defense_runtime.set_sensor_enabled(self, enabled, owner, registry)


func get_sensor_cooldown_seconds() -> float:
	_ensure_helpers_ready()
	return auto_defense_runtime.get_sensor_cooldown_seconds(self)


func get_sensor_cooldown_frames() -> float:
	_ensure_helpers_ready()
	return auto_defense_runtime.get_sensor_cooldown_frames(self)


func get_sensor_cooldown_remaining_seconds() -> float:
	_ensure_helpers_ready()
	return auto_defense_runtime.get_sensor_cooldown_remaining_seconds(self)


func get_sensor_cooldown_progress() -> float:
	_ensure_helpers_ready()
	return auto_defense_runtime.get_sensor_cooldown_progress(self)


func is_sensor_auto_dash_ready() -> bool:
	_ensure_helpers_ready()
	return auto_defense_runtime.is_sensor_auto_dash_ready(self)


func get_sensor_context() -> Dictionary:
	_ensure_helpers_ready()
	return auto_defense_runtime.get_sensor_context(self)


func build_sensor_auto_dash_request(player_pos: Vector2, config: Dictionary, deps: Dictionary = {}) -> Dictionary:
	_ensure_helpers_ready()
	return auto_defense_runtime.build_sensor_auto_dash_request(self, player_pos, config, deps)


func notify_sensor_auto_dash_started(player_center: Vector2, direction: float, deps: Dictionary = {}) -> void:
	_ensure_helpers_ready()
	auto_defense_runtime.notify_sensor_auto_dash_started(self, player_center, direction, deps, POSEIDON_CONSTANTS)


func is_hermes_shoes_equipped() -> bool:
	_ensure_helpers_ready()
	return hermes_shoes_runtime.is_equipped(self)


func is_hermes_shoes_active() -> bool:
	_ensure_helpers_ready()
	return is_hermes_shoes_equipped()


func get_hermes_shoes_speed_bonus_pct() -> float:
	_ensure_helpers_ready()
	return hermes_shoes_runtime.get_speed_bonus_pct(self)


func get_hermes_shoes_speed_multiplier() -> float:
	_ensure_helpers_ready()
	return hermes_shoes_runtime.get_speed_multiplier(self)


func get_hermes_shoes_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_hermes_shoes_context(self)


func get_player_speed_multiplier() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_player_speed_multiplier(self, BAAL_BOOTS_CONSTANTS)


func is_bulkup_equipped() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_bulkup_equipped(self)


func get_bulkup_body_size_pct() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_bulkup_body_size_pct(self)


func get_player_paddle_scale() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_player_paddle_scale(self)


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_player_paddle_width(self, base_width)


func get_player_paddle_height(base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_player_paddle_height(self, base_height)


func is_spikeboots_equipped() -> bool:
	_ensure_helpers_ready()
	return defense_gear_runtime.is_spikeboots_equipped(self)


func get_spikeboots_dash_afterdelay_reduction_pct() -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_spikeboots_dash_afterdelay_reduction_pct(self)


func get_spikeboots_dash_cooldown_reduction_pct() -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_spikeboots_dash_cooldown_reduction_pct(self)


func is_bulletproof_hat_equipped() -> bool:
	_ensure_helpers_ready()
	return defense_gear_runtime.is_bulletproof_hat_equipped(self)


func get_bulletproof_hat_stun_resist_pct() -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_bulletproof_hat_stun_resist_pct(self)


func get_player_stun_resist_pct() -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_player_stun_resist_pct(self)


func get_player_stun_duration_seconds(base_seconds: float) -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_player_stun_duration_seconds(self, base_seconds)


func is_spiked_helmet_equipped() -> bool:
	_ensure_helpers_ready()
	return defense_gear_runtime.is_spiked_helmet_equipped(self)


func get_spiked_helmet_knockback_resist_pct() -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_spiked_helmet_knockback_resist_pct(self)


func get_player_knockback_resist_pct() -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_player_knockback_resist_pct(self)


func get_player_knockback_resist_scale() -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_player_knockback_resist_scale(self)


func is_celestial_armor_equipped() -> bool:
	_ensure_helpers_ready()
	return celestial_armor_runtime.is_equipped(self)


func is_celestial_armor_active() -> bool:
	_ensure_helpers_ready()
	return is_celestial_armor_equipped()


func get_celestial_armor_trigger_chance_pct() -> float:
	_ensure_helpers_ready()
	return celestial_armor_runtime.get_trigger_chance_pct(self)


func get_celestial_armor_gauge_cost() -> float:
	_ensure_helpers_ready()
	return celestial_armor_runtime.get_gauge_cost(self)


func get_celestial_armor_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_celestial_armor_context(self)


func is_baal_boots_equipped() -> bool:
	_ensure_helpers_ready()
	return baal_boots_runtime.is_equipped(self)


func is_baal_boots_active() -> bool:
	_ensure_helpers_ready()
	return is_baal_boots_equipped()


func get_baal_boots_gauge_recovery() -> float:
	_ensure_helpers_ready()
	return baal_boots_runtime.get_gauge_recovery(self)


func get_baal_boots_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_baal_boots_context(self)


func should_pause_game() -> bool:
	_ensure_helpers_ready()
	return pause_gate.should_pause_game(self)


func is_baal_boots_cinematic_active() -> bool:
	_ensure_helpers_ready()
	return pause_gate.is_baal_boots_cinematic_active(self)


func is_acquisition_cinematic_active() -> bool:
	_ensure_helpers_ready()
	return acquisition_cinematic_runtime.is_active(self)


func start_acquisition_cinematic(
	acquired_item_data: Dictionary,
	pickup_position: Vector2,
	owner: Object,
	registry: Object = null,
	target_player_center_override: Vector2 = Vector2.INF
) -> bool:
	_ensure_helpers_ready()
	return acquisition_cinematic_runtime.start(
		self,
		acquired_item_data,
		pickup_position,
		owner,
		registry,
		target_player_center_override,
		CONTEXT_CONSTANTS,
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
	)


func handle_acquisition_cinematic_input(event: InputEvent, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return acquisition_cinematic_runtime.handle_input(self, event, registry)


func get_acquisition_cinematic_snapshot() -> Dictionary:
	_ensure_helpers_ready()
	return acquisition_cinematic_runtime.get_snapshot(self)


func is_pandora_legacy_equipped() -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.is_equipped(self)


func is_pandora_legacy_active() -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.is_active(self)


func get_pandora_legacy_selection_quality() -> float:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.get_selection_quality(self)


func get_pandora_legacy_trigger_chance() -> float:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.get_trigger_chance(self)


func is_pandora_legacy_selection_active() -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.is_selection_active(self)


func update_pandora_legacy_selection_overlay(delta: float) -> void:
	_ensure_helpers_ready()
	pandora_legacy_runtime.update_selection_overlay(self, delta)


func has_pending_pandora_legacy_selection() -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.has_pending_selection(self)


func try_queue_pandora_legacy_round_win(deps: Dictionary = {}) -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.try_queue_round_win(self, deps)


func start_pending_pandora_legacy_selection(owner: Object = null, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.start_pending_selection(self, owner, registry)


func start_pandora_legacy_selection(choices: Array, owner: Object = null, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.start_selection(self, choices, owner, registry)


func confirm_pandora_legacy_selection(index: int, owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.confirm_selection(self, index, owner, registry)


func cancel_pandora_legacy_selection(owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.cancel_selection(self, owner, registry)


func generate_pandora_legacy_selection_choices(owner: Object = null, _registry: Object = null) -> Array:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.generate_selection_choices(self, owner, _registry)


func handle_pandora_legacy_selection_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	_ensure_helpers_ready()
	return pandora_legacy_runtime.handle_selection_input(self, event, owner, registry, view_size)


func draw_pandora_legacy_selection(
	canvas: CanvasItem,
	_owner: Object,
	_registry: Object,
	view_size: Vector2
) -> void:
	_ensure_helpers_ready()
	pandora_legacy_runtime.draw_selection(self, canvas, view_size)


func on_weather_round_start(owner: Object, registry: Object, weather_type: String = "") -> void:
	_ensure_helpers_ready()
	baal_boots_runtime.clear_round_state(self, registry, BAAL_BOOTS_CONSTANTS)
	baal_boots_runtime.try_arm_from_weather(self, owner, registry, weather_type, BAAL_BOOTS_CONSTANTS)


func try_consume_celestial_armor_immunity(
	source: String = "",
	effect_type: String = "",
	deps: Dictionary = {}
) -> bool:
	_ensure_helpers_ready()
	return celestial_armor_runtime.try_consume_immunity(
		self,
		source,
		effect_type,
		deps
	)


func get_dash_recovery_frames(base_frames: float) -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_dash_recovery_frames(self, base_frames)


func get_dash_recharge_frames(base_frames: float) -> float:
	_ensure_helpers_ready()
	return defense_gear_runtime.get_dash_recharge_frames(self, base_frames)


func is_slot_add_equipped() -> bool:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.is_slot_add_equipped(self)


func get_slot_add_active_item_slot_bonus() -> int:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.get_slot_add_active_item_slot_bonus(self)


func get_active_item_slot_capacity(base_slots: int = 3) -> int:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.get_active_item_slot_capacity(self, base_slots)


func is_chargebag_equipped() -> bool:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.is_chargebag_equipped(self)


func get_chargebag_wall_bounce_gauge_pct() -> float:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.get_chargebag_wall_bounce_gauge_pct(self)


func apply_chargebag_wall_bounce_gauge(special_gauge: float, context: Dictionary, deps: Dictionary) -> float:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.apply_chargebag_wall_bounce_gauge(self, special_gauge, context, deps)


func is_battery_equipped() -> bool:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.is_battery_equipped(self)


func get_battery_gauge_preserve_pct() -> float:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.get_battery_gauge_preserve_pct(self)


func get_stage_transition_gauge(current_gauge: float, gauge_max: float = 500.0, aipill_active: bool = false) -> float:
	_ensure_helpers_ready()
	return capacity_gauge_runtime.get_stage_transition_gauge(self, current_gauge, gauge_max, aipill_active)


func is_knee_pads_equipped() -> bool:
	_ensure_helpers_ready()
	return knee_pads_runtime.is_equipped(self)


func get_knee_pads_charge_pct() -> float:
	_ensure_helpers_ready()
	return knee_pads_runtime.get_charge_pct(self)


func try_apply_knee_pads_player_hit(
	ball_pos: Vector2,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_ensure_helpers_ready()
	return knee_pads_runtime.try_apply_player_hit(
		self,
		ball_pos,
		special_gauge,
		context,
		deps
	)


func is_fuel_pouch_equipped() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_fuel_pouch_equipped(self)


func get_fuel_pouch_gauge_bonus() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_fuel_pouch_gauge_bonus(self)


func get_effective_special_gauge_max(base_max: float = BASE_SPECIAL_GAUGE_MAX) -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_effective_special_gauge_max(self, base_max)


func is_bluetooth_ring_equipped() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_bluetooth_ring_equipped(self)


func is_bluetooth_ring_active() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_bluetooth_ring_active(self)


func get_bluetooth_ring_gauge_gain_pct() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_bluetooth_ring_gauge_gain_pct(self)


func get_bluetooth_ring_gauge_multiplier() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_bluetooth_ring_gauge_multiplier(self)


func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.calculate_bluetooth_ring_gauge_charge(self, base_charge)


func is_star_detector_equipped() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_star_detector_equipped(self)


func is_star_detector_active() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_star_detector_active(self)


func get_star_detector_star_bonus_pct() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_star_detector_star_bonus_pct(self)


func get_star_detector_bonus_chance() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_star_detector_bonus_chance(self)


func roll_star_detector_bonus_drop_count() -> int:
	_ensure_helpers_ready()
	return resource_bonus_runtime.roll_star_detector_bonus_drop_count(self)


func is_sage_ring_equipped() -> bool:
	_ensure_helpers_ready()
	return progression_bonus_runtime.is_sage_ring_equipped(self)


func is_sage_ring_active() -> bool:
	_ensure_helpers_ready()
	return progression_bonus_runtime.is_sage_ring_active(self)


func get_sage_ring_count() -> int:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_sage_ring_count(self)


func get_sage_ring_perk_level_bonus() -> int:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_sage_ring_perk_level_bonus(self)


func get_sage_ring_speed_penalty_pct() -> float:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_sage_ring_speed_penalty_pct(self)


func get_sage_ring_body_penalty_pct() -> float:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_sage_ring_body_penalty_pct(self)


func get_sage_ring_speed_multiplier() -> float:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_sage_ring_speed_multiplier(self)


func is_smartphone_equipped() -> bool:
	_ensure_helpers_ready()
	return ai_assist_runtime.is_smartphone_equipped(self)


func is_smartphone_active() -> bool:
	_ensure_helpers_ready()
	return ai_assist_runtime.is_smartphone_active(self)


func get_smartphone_count() -> int:
	_ensure_helpers_ready()
	return ai_assist_runtime.get_smartphone_count(self)


func is_neural_helmet_equipped() -> bool:
	_ensure_helpers_ready()
	return ai_assist_runtime.is_neural_helmet_equipped(self)


func is_neural_helmet_active() -> bool:
	_ensure_helpers_ready()
	return ai_assist_runtime.is_neural_helmet_active(self)


func get_neural_helmet_count() -> int:
	_ensure_helpers_ready()
	return ai_assist_runtime.get_neural_helmet_count(self)


func get_neural_helmet_aipill_gauge_reduction() -> float:
	_ensure_helpers_ready()
	return ai_assist_runtime.get_neural_helmet_aipill_gauge_reduction(self)


func get_neural_helmet_aipill_spawn_bonus_pct() -> float:
	_ensure_helpers_ready()
	return ai_assist_runtime.get_neural_helmet_aipill_spawn_bonus_pct(self)


func get_aipill_gauge_drain(base_drain: float = 90.0) -> float:
	_ensure_helpers_ready()
	return ai_assist_runtime.get_aipill_gauge_drain(self, base_drain)


func get_aipill_item_spawn_multiplier() -> float:
	_ensure_helpers_ready()
	return ai_assist_runtime.get_aipill_item_spawn_multiplier(self)


func get_aipill_item_spawn_chance(base_chance: float) -> float:
	_ensure_helpers_ready()
	return ai_assist_runtime.get_aipill_item_spawn_chance(self, base_chance)


func should_cancel_aipill_on_direction_key() -> bool:
	_ensure_helpers_ready()
	return ai_assist_runtime.should_cancel_aipill_on_direction_key(self)


func is_venom_mist_gauntlet_equipped() -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.is_equipped(self)


func is_venom_mist_gauntlet_active() -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.is_active(self)


func get_venom_mist_gauntlet_count() -> int:
	_ensure_helpers_ready()
	return venom_mist_runtime.get_count(self)


func get_venom_mist_trigger_chance_pct() -> float:
	_ensure_helpers_ready()
	return venom_mist_runtime.get_trigger_chance_pct(self)


func get_venom_mist_trigger_chance() -> float:
	_ensure_helpers_ready()
	return venom_mist_runtime.get_trigger_chance(self)


func get_venom_mist_duration_sec() -> float:
	_ensure_helpers_ready()
	return venom_mist_runtime.get_duration_sec(self)


func get_venom_mist_boss_slow_multiplier() -> float:
	_ensure_helpers_ready()
	return venom_mist_runtime.get_boss_slow_multiplier(self)


func is_venom_mist_ball_poisoned() -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.is_ball_poisoned(self)


func is_venom_mist_field_active() -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.is_field_active(self)


func is_boss_in_venom_mist() -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.is_boss_in_field(self)


func get_venom_mist_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_venom_mist_context(self, CONTEXT_CONSTANTS)


func try_venom_mist_poison_ball(deps: Dictionary = {}) -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.try_poison_ball(self, deps)


func consume_venom_mist_ball_poison(boss_center: Vector2, deps: Dictionary = {}) -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.consume_ball_poison(self, boss_center, deps)


func try_spawn_venom_mist_at_boss(
	boss_center: Vector2,
	deps: Dictionary = {},
	force: bool = false
) -> bool:
	_ensure_helpers_ready()
	return venom_mist_runtime.try_spawn_at_boss(self, boss_center, deps, force)


func clear_venom_mist_round_state() -> void:
	_ensure_helpers_ready()
	venom_mist_runtime.clear_runtime(self)


func is_reinforced_boomerang_gauntlet_equipped() -> bool:
	_ensure_helpers_ready()
	return throw_bonus_runtime.is_reinforced_boomerang_gauntlet_equipped(self)


func is_reinforced_boomerang_gauntlet_active() -> bool:
	_ensure_helpers_ready()
	return throw_bonus_runtime.is_reinforced_boomerang_gauntlet_active(self)


func get_reinforced_boomerang_gauntlet_count() -> int:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_reinforced_boomerang_gauntlet_count(self)


func get_boomerang_launch_speed_pct() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_launch_speed_pct(self)


func get_boomerang_homing_pct() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_homing_pct(self)


func get_boomerang_spawn_bonus_pct() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_spawn_bonus_pct(self)


func get_boomerang_launch_speed_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_launch_speed_multiplier(self)


func get_boomerang_homing_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_homing_multiplier(self)


func get_boomerang_item_spawn_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_item_spawn_multiplier(self)


func get_boomerang_item_spawn_chance(base_chance: float) -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_item_spawn_chance(self, base_chance)


func get_boomerang_knockback_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_knockback_multiplier(self)


func get_boomerang_stun_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_boomerang_stun_multiplier(self)


func is_commando_arm_equipped() -> bool:
	_ensure_helpers_ready()
	return throw_bonus_runtime.is_commando_arm_equipped(self)


func is_commando_arm_active() -> bool:
	_ensure_helpers_ready()
	return throw_bonus_runtime.is_commando_arm_active(self)


func get_commando_arm_count() -> int:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_count(self)


func get_commando_arm_throw_speed_pct() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_throw_speed_pct(self)


func get_commando_arm_explosion_range_pct() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_explosion_range_pct(self)


func get_commando_arm_smoke_duration_pct() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_smoke_duration_pct(self)


func get_commando_arm_prep_reduction_pct() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_prep_reduction_pct(self)


func get_commando_arm_prep_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_prep_multiplier(self)


func get_commando_arm_windup_msec(base_msec: int) -> int:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_windup_msec(self, base_msec)


func get_commando_arm_throw_speed_multiplier(use_rolled_speed: bool = false) -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_throw_speed_multiplier(self, use_rolled_speed)


func get_commando_arm_range_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_range_multiplier(self)


func get_commando_arm_range_value(base_value: float) -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_range_value(self, base_value)


func get_commando_arm_smoke_duration_multiplier() -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_smoke_duration_multiplier(self)


func get_commando_arm_duration_frames(base_frames: float) -> float:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_duration_frames(self, base_frames)


func get_commando_arm_context() -> Dictionary:
	_ensure_helpers_ready()
	return throw_bonus_runtime.get_commando_arm_context(self)


func is_rainbow_fur_glove_equipped() -> bool:
	_ensure_helpers_ready()
	return rainbow_fur_glove_runtime.is_equipped(self)


func is_rainbow_fur_glove_active() -> bool:
	_ensure_helpers_ready()
	return rainbow_fur_glove_runtime.is_active(self)


func get_rainbow_fur_glove_trigger_chance_pct() -> float:
	_ensure_helpers_ready()
	return rainbow_fur_glove_runtime.get_trigger_chance_pct(self)


func get_rainbow_fur_glove_cooldown_reduction_pct() -> float:
	_ensure_helpers_ready()
	return rainbow_fur_glove_runtime.get_cooldown_reduction_pct(self)


func get_rainbow_fur_glove_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_rainbow_fur_glove_context(self)


func try_proc_rainbow_fur_glove_player_hit(
	ball_pos: Vector2,
	context: Dictionary = {},
	deps: Dictionary = {}
) -> Dictionary:
	_ensure_helpers_ready()
	return rainbow_fur_glove_runtime.try_proc_player_hit(
		self,
		ball_pos,
		context,
		deps
	)


func is_adversity_armor_equipped() -> bool:
	_ensure_helpers_ready()
	return adversity_armor_runtime.is_equipped(self)


func is_adversity_armor_active() -> bool:
	_ensure_helpers_ready()
	return adversity_armor_runtime.is_active(self)


func is_adversity_armor_invincible() -> bool:
	_ensure_helpers_ready()
	return adversity_armor_runtime.is_invincible(self)


func get_adversity_armor_trigger_chance_pct() -> float:
	_ensure_helpers_ready()
	return adversity_armor_runtime.get_trigger_chance_pct(self)


func get_adversity_armor_invincible_duration_sec() -> float:
	_ensure_helpers_ready()
	return adversity_armor_runtime.get_invincible_duration_sec(self)


func get_adversity_armor_serve_speed_bonus_pct() -> float:
	_ensure_helpers_ready()
	return adversity_armor_runtime.get_serve_speed_bonus_pct(self)


func get_adversity_armor_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_adversity_armor_context(self)


func get_ball_collision_context() -> Dictionary:
	_ensure_helpers_ready()
	var context: Dictionary = adversity_armor_runtime.get_ball_collision_context(self)
	context.merge(horn_strawberry_field_state.get_ball_collision_context(), true)
	if ragnarok_stun_ball_active:
		# Ragnarok no longer fully removes the cap; it raises the current league
		# ball-speed limit by a fixed +6 while the charged stun ball travels.
		# The effective cap is applied in ball_frame_motion_controller via
		# get_ragnarok_speed_cap_bonus(); this key is exposed for debug / parity.
		context["ragnarok_hammer_speed_cap_bonus"] = RAGNAROK_SPEED_CAP_BONUS
	return context


func try_queue_adversity_armor_after_loss(deps: Dictionary = {}) -> bool:
	_ensure_helpers_ready()
	return adversity_armor_runtime.try_queue_after_loss(self, deps)


func on_round_start(owner: Object, registry: Object = null) -> void:
	_ensure_helpers_ready()
	horn_strawberry_mask_runtime.reset_round(self)
	adversity_armor_runtime.on_round_start(self, owner, registry)
	if owner != null:
		_sync_owner(owner, registry)


func consume_adversity_armor_serve_speed_bonus() -> float:
	_ensure_helpers_ready()
	return adversity_armor_runtime.consume_serve_speed_bonus(self)


func notify_adversity_armor_barrier_hit(
	impact_pos: Vector2,
	ball_vel: Vector2 = Vector2.ZERO,
	deps: Dictionary = {}
) -> void:
	_ensure_helpers_ready()
	adversity_armor_runtime.notify_barrier_hit(self, impact_pos, ball_vel, deps)

func is_shrapnel_armor_equipped() -> bool:
	_ensure_helpers_ready()
	return shrapnel_armor_runtime.is_equipped(self)


func is_shrapnel_armor_active() -> bool:
	_ensure_helpers_ready()
	return shrapnel_armor_runtime.is_active(self)


func get_shrapnel_armor_trigger_chance_pct() -> float:
	_ensure_helpers_ready()
	return shrapnel_armor_runtime.get_trigger_chance_pct(self)


func get_shrapnel_armor_shard_count() -> int:
	_ensure_helpers_ready()
	return shrapnel_armor_runtime.get_shard_count(self)


func get_shrapnel_armor_knockback_level() -> int:
	_ensure_helpers_ready()
	return shrapnel_armor_runtime.get_knockback_level(self)


func get_shrapnel_armor_gauge_cost() -> float:
	_ensure_helpers_ready()
	return shrapnel_armor_runtime.get_gauge_cost(self)


func get_shrapnel_armor_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_shrapnel_armor_context(self)


func try_proc_shrapnel_armor_player_hit(
	ball_pos: Vector2,
	context: Dictionary = {},
	deps: Dictionary = {}
) -> Dictionary:
	_ensure_helpers_ready()
	return shrapnel_armor_runtime.try_proc_player_hit(self, ball_pos, context, deps)


func is_foul_whistle_equipped() -> bool:
	_ensure_helpers_ready()
	return foul_whistle_runtime.is_equipped(self)


func is_foul_whistle_active() -> bool:
	_ensure_helpers_ready()
	return foul_whistle_runtime.is_active(self)


func get_foul_whistle_negate_chance_pct() -> float:
	_ensure_helpers_ready()
	return foul_whistle_runtime.get_negate_chance_pct(self)


func get_foul_whistle_negate_chance() -> float:
	_ensure_helpers_ready()
	return foul_whistle_runtime.get_negate_chance(self)


func try_trigger_foul_whistle(loss_type: String = "round", audio_source: Variant = null) -> bool:
	_ensure_helpers_ready()
	return foul_whistle_runtime.try_trigger(self, loss_type, audio_source)


func consume_foul_whistle_reset_ready() -> bool:
	_ensure_helpers_ready()
	return foul_whistle_runtime.consume_reset_ready(self)


func is_foul_whistle_effect_active() -> bool:
	_ensure_helpers_ready()
	return foul_whistle_runtime.is_effect_active(self)


func is_revival_equipped() -> bool:
	_ensure_helpers_ready()
	return revival_runtime.is_equipped(self)


func is_revival_available() -> bool:
	_ensure_helpers_ready()
	return revival_runtime.is_available(self)


func has_revival_used() -> bool:
	_ensure_helpers_ready()
	return revival_runtime.has_used(self)


func is_revival_effect_active() -> bool:
	_ensure_helpers_ready()
	return revival_runtime.is_effect_active(self)


func try_trigger_revival(loss_type: String = "round", context: Dictionary = {}) -> bool:
	_ensure_helpers_ready()
	return revival_runtime.try_trigger(self, loss_type, context, CONTEXT_CONSTANTS)


func is_gold_digger_equipped() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_gold_digger_equipped(self)


func get_gold_digger_count() -> int:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_gold_digger_count(self)


func get_gold_digger_gold_bonus_pct() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_gold_digger_gold_bonus_pct(self)


func get_gold_digger_multiplier() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_gold_digger_multiplier(self)


func apply_gold_digger_gauge_bonus(gauge_gain: float) -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.apply_gold_digger_gauge_bonus(self, gauge_gain)


func apply_gold_digger_gold_bonus(amount: int) -> int:
	_ensure_helpers_ready()
	return resource_bonus_runtime.apply_gold_digger_gold_bonus(self, amount)


func is_gold_bar_equipped() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_gold_bar_equipped(self)


func is_gold_bar_owned() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_gold_bar_owned(self)


func is_gold_bar_active() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_gold_bar_active(self)


func get_gold_bar_count() -> int:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_gold_bar_count(self)


func get_gold_bar_sell_price() -> int:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_gold_bar_sell_price(self)


func get_gold_bar_total_sell_price() -> int:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_gold_bar_total_sell_price(self)


func get_gold_bar_speed_penalty_pct() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_gold_bar_speed_penalty_pct(self)


func get_gold_bar_speed_multiplier() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_gold_bar_speed_multiplier(self)


func is_lucky_coin_equipped() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_lucky_coin_equipped(self)


func is_lucky_coin_active() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.is_lucky_coin_active(self)


func get_lucky_coin_double_spawn_pct() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_lucky_coin_double_spawn_pct(self)


func get_lucky_coin_double_spawn_chance() -> float:
	_ensure_helpers_ready()
	return resource_bonus_runtime.get_lucky_coin_double_spawn_chance(self)


func should_lucky_coin_double_spawn() -> bool:
	_ensure_helpers_ready()
	return resource_bonus_runtime.should_lucky_coin_double_spawn(self)


func is_master_equipped() -> bool:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.is_master_equipped(self)


func get_master_wall_length_bonus_pct() -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_master_wall_length_bonus_pct(self)


func get_master_item_cooldown_reduction_pct() -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_master_item_cooldown_reduction_pct(self)


func get_master_wall_spawn_bonus_pct() -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_master_wall_spawn_bonus_pct(self)


func get_brick_wall_width(base_width: float) -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_brick_wall_width(self, base_width)


func get_wall_item_spawn_chance(base_chance: float) -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_wall_item_spawn_chance(self, base_chance)


func is_cooltime_equipped() -> bool:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.is_cooltime_equipped(self)


func get_cooltime_active_item_cooldown_reduction_pct() -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_cooltime_active_item_cooldown_reduction_pct(self)


func get_total_active_item_cooldown_reduction_pct() -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_total_active_item_cooldown_reduction_pct(self)


func get_active_item_cooldown_msec(base_cooldown_msec: int) -> int:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_active_item_cooldown_msec(self, base_cooldown_msec)


func is_timer_belt_equipped() -> bool:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.is_timer_belt_equipped(self)


func get_timer_belt_skill_cooldown_reduction_pct() -> float:
	_ensure_helpers_ready()
	return cooldown_gear_runtime.get_timer_belt_skill_cooldown_reduction_pct(self)


func is_sacred_laurel_equipped() -> bool:
	_ensure_helpers_ready()
	return progression_bonus_runtime.is_sacred_laurel_equipped(self)


func get_sacred_laurel_leaf_bonus() -> int:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_sacred_laurel_leaf_bonus(self)


func get_sacred_laurel_context() -> Dictionary:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_sacred_laurel_context(self)


func is_transcendent_crown_equipped() -> bool:
	_ensure_helpers_ready()
	return progression_bonus_runtime.is_transcendent_crown_equipped(self)


func get_transcendent_crown_skill_bonus() -> int:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_transcendent_crown_skill_bonus(self)


func get_total_item_perk_level_bonus() -> int:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_total_item_perk_level_bonus(self)


func get_transcendent_crown_context() -> Dictionary:
	_ensure_helpers_ready()
	return progression_bonus_runtime.get_transcendent_crown_context(self)


func is_heavenly_cape_equipped() -> bool:
	_ensure_helpers_ready()
	return heavenly_cape_runtime.is_equipped(self)


func get_heavenly_cape_skill_cooldown_reduction_pct() -> float:
	_ensure_helpers_ready()
	return heavenly_cape_runtime.get_skill_cooldown_reduction_pct(self)


func get_heavenly_cape_skill_slot_bonus() -> int:
	_ensure_helpers_ready()
	return heavenly_cape_runtime.get_skill_slot_bonus(self)


func get_player_skill_max_slots(base_slots: int = 5) -> int:
	_ensure_helpers_ready()
	return heavenly_cape_runtime.get_player_skill_max_slots(self, base_slots)


func get_player_skill_cooldown_multiplier() -> float:
	_ensure_helpers_ready()
	return heavenly_cape_runtime.get_player_skill_cooldown_multiplier(self)


func get_player_skill_cooldown_seconds(base_cooldown_seconds: float) -> float:
	_ensure_helpers_ready()
	return heavenly_cape_runtime.get_player_skill_cooldown_seconds(self, base_cooldown_seconds)


func is_horn_strawberry_mask_equipped() -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.is_equipped(self)


func is_horn_strawberry_transformed() -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.is_transformed(self)


func is_horn_strawberry_event_playing() -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.is_event_playing(self)


func is_horn_strawberry_skills_locked() -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.is_skills_locked(self)


func is_horn_strawberry_control_locked() -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.is_control_locked(self)


func get_horn_strawberry_move_speed() -> Variant:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.get_move_speed(self)


func get_horn_strawberry_paddle_size_bonus_pct() -> float:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.get_paddle_size_bonus_pct(self)


func get_horn_strawberry_gauge_on_hit() -> float:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.get_gauge_on_hit(self)


func get_horn_strawberry_context() -> Dictionary:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.get_context(self)


func try_horn_strawberry_transform(owner: Object, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.try_transform(self, owner, registry)


func feed_horn_strawberry_command_input(
	input_snapshot: Dictionary,
	delta: float,
	owner: Object = null,
	registry: Object = null
) -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.feed_command_input(self, input_snapshot, delta, owner, registry)


func add_horn_strawberry_eat_paddle_growth(owner: Object, registry: Object = null, amount_pct: float = 0.20) -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.add_eat_paddle_growth(self, owner, registry, amount_pct, CONTEXT_CONSTANTS)


func get_horn_strawberry_eat_context() -> Dictionary:
	_ensure_helpers_ready()
	return horn_strawberry_eat_state.get_context()


func get_horn_strawberry_field_context() -> Dictionary:
	_ensure_helpers_ready()
	return horn_strawberry_field_state.get_context()


func get_horn_strawberry_horn_charge_context() -> Dictionary:
	_ensure_helpers_ready()
	return horn_strawberry_horn_charge_state.get_context()


func get_horn_strawberry_bomb_context() -> Dictionary:
	_ensure_helpers_ready()
	return horn_strawberry_bomb_state.get_context()


func notify_horn_strawberry_field_hit(barrier_id: int, impact_pos: Vector2 = Vector2.ZERO, deps: Dictionary = {}) -> bool:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.notify_field_hit(self, barrier_id, impact_pos, deps)


func consume_horn_strawberry_strong_boss_hit(
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary = {}
) -> Dictionary:
	_ensure_helpers_ready()
	return horn_strawberry_mask_runtime.consume_strong_boss_hit(self, ball_pos, ball_vel, context, deps)


func on_stage_advance(owner: Object = null, registry: Object = null) -> void:
	_ensure_helpers_ready()
	horn_strawberry_mask_runtime.on_stage_advance(self)
	if owner != null:
		_sync_owner(owner, registry)


func is_dashgear_equipped() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_dashgear_equipped(self)


func get_dashgear_dash_distance_bonus_pct() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_dashgear_dash_distance_bonus_pct(self)


func get_dashgear_boost_charge_chance_pct() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_dashgear_boost_charge_chance_pct(self)


func get_dash_duration_frames(base_frames: float) -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_dash_duration_frames(self, base_frames)


func get_boost_charge_chance_pct() -> float:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_boost_charge_chance_pct(self)


func is_soul_burst_equipped() -> bool:
	_ensure_helpers_ready()
	return soul_burst_runtime.is_equipped(self)


func is_soul_burst_active() -> bool:
	_ensure_helpers_ready()
	return soul_burst_runtime.is_active(self)


func get_soul_burst_gauge_cost() -> float:
	_ensure_helpers_ready()
	return soul_burst_runtime.get_gauge_cost(self)


func can_soul_burst_dash(special_gauge: float) -> bool:
	_ensure_helpers_ready()
	return soul_burst_runtime.can_dash(self, special_gauge)


func try_consume_soul_burst_dash(
	special_gauge: float,
	player_center: Vector2,
	direction: float,
	registry: Object = null
) -> Dictionary:
	_ensure_helpers_ready()
	return soul_burst_runtime.try_consume_dash(
		self,
		special_gauge,
		player_center,
		direction,
		registry
	)


func trigger_soul_burst_effect(player_center: Vector2, direction: float, registry: Object = null) -> void:
	_ensure_helpers_ready()
	soul_burst_runtime.trigger_effect(self, player_center, direction, registry)


func is_dashholder_equipped() -> bool:
	_ensure_helpers_ready()
	return stat_bonus_runtime.is_dashholder_equipped(self)


func get_dashholder_dash_token_bonus() -> int:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_dashholder_dash_token_bonus(self)


func get_dash_token_capacity(base_tokens: int = 1, runtime_perk_state: Object = null) -> int:
	_ensure_helpers_ready()
	return stat_bonus_runtime.get_dash_token_capacity(self, base_tokens, runtime_perk_state)


func update(owner: Object, registry: Object, delta: float) -> void:
	_ensure_helpers_ready()
	update_runtime.update(
		self,
		owner,
		registry,
		delta,
		RAGNAROK_CONSTANTS,
		POSEIDON_CONSTANTS,
		BAAL_BOOTS_CONSTANTS,
		CONTEXT_CONSTANTS
	)


func try_apply_ragnarok_player_hit(
	ball_vel: Vector2,
	special_gauge: float,
	_context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_ensure_helpers_ready()
	return ragnarok_runtime.try_apply_player_hit(self, ball_vel, special_gauge, deps, RAGNAROK_CONSTANTS)


func apply_ragnarok_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	_ensure_helpers_ready()
	return ragnarok_runtime.apply_boss_hit(self, ball_vel, context, deps, RAGNAROK_CONSTANTS)


func get_ragnarok_speed_cap_bonus() -> float:
	# While a charged Ragnarok stun ball is in flight, raise the current league
	# ball-speed cap by +6 instead of removing it entirely.
	return RAGNAROK_SPEED_CAP_BONUS if ragnarok_stun_ball_active else 0.0


func apply_poseidon_wave_to_ball(scene: Dictionary, fps_scale: float, _context: Dictionary, deps: Dictionary) -> Dictionary:
	_ensure_helpers_ready()
	return poseidon_runtime.apply_wave_to_ball(self, scene, fps_scale, deps, POSEIDON_CONSTANTS)


func apply_poseidon_boss_hit(ball_vel: Vector2) -> Dictionary:
	_ensure_helpers_ready()
	return poseidon_runtime.apply_boss_hit(self, ball_vel)


func apply_baal_boots_player_hit(ball_pos: Vector2, ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	_ensure_helpers_ready()
	return baal_boots_runtime.apply_player_hit(self, ball_pos, ball_vel, context, deps, BAAL_BOOTS_CONSTANTS)


func apply_baal_boots_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	_ensure_helpers_ready()
	return baal_boots_runtime.apply_boss_hit(self, ball_vel, context, deps, BAAL_BOOTS_CONSTANTS)


func get_ragnarok_trigger_chance() -> float:
	_ensure_helpers_ready()
	return ragnarok_runtime.get_trigger_chance(self)


func get_ragnarok_stun_duration() -> float:
	_ensure_helpers_ready()
	return ragnarok_runtime.get_stun_duration(self)


func get_ragnarok_speed_boost() -> float:
	_ensure_helpers_ready()
	return ragnarok_runtime.get_speed_boost(self)


func get_ragnarok_gauge_cost() -> float:
	_ensure_helpers_ready()
	return ragnarok_runtime.get_gauge_cost(self)


func get_poseidon_cooldown() -> float:
	_ensure_helpers_ready()
	return poseidon_runtime.get_cooldown(self)


func get_poseidon_gauge_cost() -> float:
	_ensure_helpers_ready()
	return poseidon_runtime.get_gauge_cost(self)


func get_poseidon_vortex_size() -> float:
	_ensure_helpers_ready()
	return poseidon_runtime.get_vortex_size(self)


func is_poseidon_ball_motion_active() -> bool:
	_ensure_helpers_ready()
	return poseidon_runtime.is_ball_motion_active(self, POSEIDON_CONSTANTS)


func get_poseidon_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_poseidon_context(self, CONTEXT_CONSTANTS)


func get_boss_ai_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_boss_ai_context(self, CONTEXT_CONSTANTS)


func has_actor_draw_context() -> bool:
	_ensure_helpers_ready()
	return context_builder.has_actor_draw_context(self)


func get_actor_draw_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_actor_draw_context(self, CONTEXT_CONSTANTS)


func has_ball_draw_context() -> bool:
	_ensure_helpers_ready()
	return context_builder.has_ball_draw_context(self)


func get_ball_draw_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_builder.get_ball_draw_context(self)


func has_visible_field_effects() -> bool:
	_ensure_helpers_ready()
	return field_effect_visibility.has_visible_field_effects(self, RAGNAROK_IMPACT_EFFECT_DURATION)


func draw_field_effects(
	canvas: CanvasItem,
	_registry: Object,
	shake_offset: Vector2,
	perf_logger: Object = null,
	timer_stack: Object = null,
	draw_context: Dictionary = {}
) -> void:
	_ensure_helpers_ready()
	field_effect_renderer.draw_field_effects(
		self,
		canvas,
		shake_offset,
		RAGNAROK_IMPACT_EFFECT_DURATION,
		RAGNAROK_ELECTRIC_STUN_INTENSITY,
		perf_logger,
		timer_stack,
		FIELD_EFFECT_CONSTANTS,
		draw_context
	)


func is_activation_effect_active() -> bool:
	_ensure_helpers_ready()
	return activation_effect_runtime.is_active(self)


func draw_activation_effect(canvas: CanvasItem, view_size: Vector2) -> void:
	_ensure_helpers_ready()
	activation_effect_runtime.draw(self, canvas, view_size)


func get_snapshot() -> Dictionary:
	_ensure_helpers_ready()
	return snapshot_builder.build_snapshot(self)


func get_item_roll_value(
	item_data: Dictionary,
	option_key: String,
	apply_polish: bool = true,
	registry: Object = null
) -> float:
	_ensure_helpers_ready()
	return roll_query.get_public_item_roll_value(self, item_data, option_key, apply_polish, registry)


func _sync_owner(owner: Object, registry: Object = null) -> void:
	owner_syncer.sync_owner(self, owner, registry, CONTEXT_CONSTANTS)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _ensure_helpers_ready(perform_reset: bool = false) -> void:
	while not prewarm_initialization_step(perform_reset):
		pass


func _init_helper(member_name: String) -> void:
	if get(member_name) is Object:
		return
	var helper := HelperRegistry.create_helper(member_name)
	if helper != null:
		set(member_name, helper)


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE
