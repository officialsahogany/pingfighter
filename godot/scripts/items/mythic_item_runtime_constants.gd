extends RefCounted

const AutoDefenseRuntime := preload("res://scripts/items/mythic_item_auto_defense_runtime.gd")
const VenomMistRuntime := preload("res://scripts/items/mythic_item_venom_mist_runtime.gd")
const RainbowFurGloveRuntime := preload("res://scripts/items/mythic_item_rainbow_fur_glove_runtime.gd")
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
const ITEM_ODINS_EYE := "odins_eye"
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
const BOOMERANG_ICON_PATH := "res://assets/sprites/items/boomerang_icon_hq_v1.png"
const BOOMERANG_METAL_ICON_PATH := "res://assets/sprites/items/boomerang_metal_icon_hq_v1.png"
const BASE_SPECIAL_GAUGE_MAX := 500.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const RAINBOW_FUR_GLOVE_AURA_FRAMES := RainbowFurGloveRuntime.AURA_FRAMES
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
	"item_odins_eye": ITEM_ODINS_EYE,
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
