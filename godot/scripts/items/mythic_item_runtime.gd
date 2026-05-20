extends RefCounted

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemAudioRouter := preload("res://scripts/items/mythic_item_audio_router.gd")
const MythicItemContextBuilder := preload("res://scripts/items/mythic_item_context_builder.gd")
const MythicItemDebugInventory := preload("res://scripts/items/mythic_item_debug_inventory.gd")
const MythicItemEquipmentIndex := preload("res://scripts/items/mythic_item_equipment_index.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const MythicItemPickupBonus := preload("res://scripts/items/mythic_item_pickup_bonus.gd")
const MythicItemRollQuery := preload("res://scripts/items/mythic_item_roll_query.gd")
const MythicItemStageImmunity := preload("res://scripts/items/mythic_item_stage_immunity.gd")
const PassiveMythicItemDebugMenu := preload("res://scripts/items/passive_mythic_item_debug_menu.gd")
const MythicItemAcquisitionCinematicV2 := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const MythicItemSnapshotBuilder := preload("res://scripts/items/mythic_item_snapshot_builder.gd")
const BaalBootsCombatState := preload("res://scripts/items/baal_boots_combat_state.gd")
const BaalBootsEffectRenderer := preload("res://scripts/items/baal_boots_effect_renderer.gd")
const BaalBootsEffectState := preload("res://scripts/items/baal_boots_effect_state.gd")
const BaalBootsWeatherState := preload("res://scripts/items/baal_boots_weather_state.gd")
const CelestialArmorState := preload("res://scripts/items/celestial_armor_state.gd")
const FoulWhistleState := preload("res://scripts/items/foul_whistle_state.gd")
const HermesShoesState := preload("res://scripts/items/hermes_shoes_state.gd")
const MegingjordActivationEffectRenderer := preload("res://scripts/items/mythic_item_activation_effect_renderer.gd")
const MythicItemFieldEffectRenderer := preload("res://scripts/items/mythic_item_field_effect_renderer.gd")
const MythicItemSupportEffectRenderer := preload("res://scripts/items/mythic_item_support_effect_renderer.gd")
const PandoraLegacyChoiceBuilder := preload("res://scripts/items/pandora_legacy_choice_builder.gd")
const PandoraLegacyGrantRouter := preload("res://scripts/items/pandora_legacy_grant_router.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")
const PandoraLegacySelectionRenderer := preload("res://scripts/items/mythic_item_pandora_selection_renderer.gd")
const PandoraLegacySelectionState := preload("res://scripts/items/pandora_legacy_selection_state.gd")
const RevivalState := preload("res://scripts/items/revival_state.gd")

const ITEM_MEGINGJORD := "megingjord"
const ITEM_DOWSING_PENDULUM := "dowsing_pendulum"
const ITEM_DOWSING_GOGGLES := "dowsing_goggles"
const ITEM_SPEEDBOOTS := "speedboots"
const ITEM_SPEEDGEAR := "speedgear"
const ITEM_GRAVITYBELT := "gravitybelt"
const ITEM_SENSOR := "sensor"
const ITEM_SPIKEBOOTS := "spikeboots"
const ITEM_BULLETPROOF_HAT := "bulletproof_hat"
const ITEM_SPIKED_HELMET := "spiked_helmet"
const ITEM_SLOT_ADD := "slot_add"
const ITEM_CHARGEBAG := "chargebag"
const ITEM_BATTERY := "battery"
const ITEM_REVIVAL := "revival"
const ITEM_MASTER := "master"
const ITEM_GOLD_DIGGER := "gold_digger"
const ITEM_GOLD_BAR := "gold_bar"
const ITEM_LUCKY_COIN := "lucky_coin"
const ITEM_ADVERSITY_ARMOR := "adversity_armor"
const ITEM_SHRAPNEL_ARMOR := "shrapnel_armor"
const ITEM_SAGE_RING := "sage_ring"
const ITEM_COOLTIME := "cooltime"
const ITEM_TIMER_BELT := "timer_belt"
const ITEM_FUEL_POUCH := "fuel_pouch"
const ITEM_BLUETOOTH_RING := "bluetooth_ring"
const ITEM_STAR_DETECTOR := "star_detector"
const ITEM_FOUL_WHISTLE := "foul_whistle"
const ITEM_SMARTPHONE := "smartphone"
const ITEM_NEURAL_HELMET := "neural_helmet"
const ITEM_VENOM_MIST_GAUNTLET := "venom_mist_gauntlet"
const ITEM_REINFORCED_BOOMERANG_GAUNTLET := "reinforced_boomerang_gauntlet"
const ITEM_COMMANDO_ARM := "commando_arm"
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
const ITEM_SACRED_LAUREL := "sacred_laurel"
const ITEM_TRANSCENDENT_CROWN := "transcendent_crown"
const ITEM_HEAVENLY_CAPE := "heavenly_cape"
const ITEM_CELESTIAL_ARMOR := "celestial_armor"
const ITEM_BAAL_BOOTS := "baal_boots"
const ITEM_PANDORA_LEGACY := "pandora_legacy"
const ARM_SLOT_KEYS := ["left_arm", "right_arm"]
const ACCESSORY_SLOT_KEYS := ["accessory1", "accessory2", "accessory3", "accessory4"]
const PANDORA_SELECTION_CARD_COUNT := 3
const PANDORA_ACTIVE_ITEM_KOREAN_NAMES := {
	"gauge_charge": "에너지드링크",
	"life_elixir": "생명수",
	"vitamin_pill": "비타민드링크",
	"strange_vial": "이상한 약병",
	"aipill": "AI 알약",
	"pandora_box": "판도라의 상자",
	"grenade": "수류탄",
	"flare": "조명탄",
	"tear_gas": "최루탄",
	"dynamite": "다이너마이트",
	"molotov": "화염병",
	"stopwatch": "스탑워치",
	"magnet_field": "자기장",
	"long_boost": "거대화포션",
	"regeneration_potion": "재생물약",
	"holy_barrier": "홀리베리어",
	"wall": "벽돌",
	"boomerang": "부메랑",
	"banana": "바나나",
	"soap": "비누",
	"spider_mine": "스파이더지뢰",
}
const MEGINGJORD_MAX_EXTRA_PICKS := 2
const MEGINGJORD_ACTIVATION_DURATION := 2.20
const MEGINGJORD_PARTICLE_COUNT := 58
const MEGINGJORD_BOLT_COUNT := 24
const DOWSING_PENDULUM_ATTRACTION_FORCE := 3.5
const DOWSING_PENDULUM_MIN_DISTANCE := 30.0
const DOWSING_PENDULUM_MAX_SPEED := 8.0
const RAGNAROK_BOSS_KNOCKBACK_FRAMES := 36.0
const RAGNAROK_BOSS_KNOCKBACK_DECAY := 0.86
const RAGNAROK_STUN_BALL_EFFECT_DURATION := 0.80
const RAGNAROK_IMPACT_EFFECT_DURATION := 0.74
const RAGNAROK_SPARK_COUNT := 18
const RAGNAROK_PARTICLE_ALPHA_CUTOFF := 0.02
const RAGNAROK_IMPACT_RING_SEGMENTS := 32
const RAGNAROK_STUN_AURA_SEGMENTS := 32
const RAGNAROK_STUN_AURA_OUTER_SEGMENTS := 40
const RAGNAROK_ELECTRIC_ELLIPSE_SEGMENTS := 24
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
const RAGNAROK_ELECTRIC_CORE_COLORS := [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 230.0 / 255.0, 1.0),
	Color(1.0, 250.0 / 255.0, 200.0 / 255.0, 1.0),
]
const RAGNAROK_ELECTRIC_OUTER_COLORS := [
	Color(120.0 / 255.0, 180.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 140.0 / 255.0, 1.0, 1.0),
	Color(160.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(1.0, 240.0 / 255.0, 120.0 / 255.0, 1.0),
	Color(1.0, 220.0 / 255.0, 80.0 / 255.0, 1.0),
]
const RAGNAROK_ELECTRIC_BRANCH_COLORS := [
	Color(120.0 / 255.0, 180.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 140.0 / 255.0, 1.0, 1.0),
	Color(160.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(1.0, 240.0 / 255.0, 120.0 / 255.0, 1.0),
	Color(1.0, 220.0 / 255.0, 80.0 / 255.0, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 230.0 / 255.0, 1.0),
	Color(1.0, 250.0 / 255.0, 200.0 / 255.0, 1.0),
]
const RAGNAROK_ELECTRIC_SPARK_COLORS := [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 200.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0),
]
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
const KNEE_PADS_FLASH_DURATION_FRAMES := 30.0
const KNEE_PADS_PARTICLE_COUNT := 20
const KNEE_PADS_SHAKE_AMOUNT := 0.08
const KNEE_PADS_SHAKE_INTENSITY := 3.0
const SOUL_BURST_DEFAULT_GAUGE_COST := 160.0
const SOUL_BURST_MIN_GAUGE_COST := 110.0
const SOUL_BURST_MAX_GAUGE_COST := 160.0
const SOUL_BURST_EFFECT_FRAMES := 30.0
const SOUL_BURST_SHOCKWAVE_FRAMES := 18.0
const SOUL_BURST_PARTICLE_COUNT := 30
const SOUL_BURST_WIND_TRAIL_COUNT := 10
const SOUL_BURST_PARTICLE_ALPHA_CUTOFF := 0.02
const FOUL_WHISTLE_TOTAL_FRAMES := 120.0
const FOUL_WHISTLE_RESET_FRAME := 70.0
const FOUL_WHISTLE_REFEREE_FRAME_COUNT := 4
const FOUL_WHISTLE_REFEREE_FRAME_FRAMES := 6.0
const REVIVAL_EFFECT_FRAMES := 120.0
const SMARTPHONE_RECOVERY_GAUGE_THRESHOLD := 120.0
const SMARTPHONE_RECOVERY_COOLDOWN_FRAMES := 60.0
const SMARTPHONE_DEFENSE_COOLDOWN_FRAMES := 180.0
const SMARTPHONE_PRE_ACTIVATE_MARGIN := 16.0
const SMARTPHONE_MIN_PLAYABLE_MARGIN := 28.0
const SMARTPHONE_MIN_SAFE_DISTANCE := 35.0
const SAGE_RING_PERK_LEVEL_BONUS := 1
const SAGE_RING_MAX_SPEED_PENALTY_PCT := 95.0
const SAGE_RING_MAX_BODY_PENALTY_PCT := 95.0
const NEURAL_HELMET_GAUGE_REDUCTION_CAP := 90.0
const NEURAL_HELMET_SPAWN_CAP_PCT := 2000.0
const VENOM_MIST_RADIUS := 120.0
const VENOM_MIST_DEFAULT_DURATION_SEC := 3.0
const VENOM_MIST_MAX_TRIGGER_CHANCE_PCT := 100.0
const VENOM_MIST_BOSS_SLOW_AMOUNT := 0.70
const VENOM_MIST_GAUGE_DRAIN_PER_FRAME := 0.5
const VENOM_MIST_HONGRYUN_DRAIN_THRESHOLD := 60.0
const VENOM_MIST_FADE_IN_FRAMES := 18.0
const VENOM_MIST_FADE_OUT_FRAMES := 30.0
const VENOM_MIST_PARTICLE_COUNT := 46
const VENOM_MIST_PARTICLE_MAX := 76
const CELESTIAL_ARMOR_MAX_TRIGGER_CHANCE_PCT := 100.0
const CELESTIAL_ARMOR_MAX_GAUGE_COST := 100.0
const CELESTIAL_ARMOR_WAVE_LIFE_FRAMES := 33.0
const CELESTIAL_ARMOR_WAVE_RADIUS_MAX := 110.0
const CELESTIAL_ARMOR_PAIRED_PROC_WINDOW_FRAMES := 3.0
const CELESTIAL_ARMOR_SHARD_COUNT := 10
const CELESTIAL_ARMOR_ARC_SEGMENTS := 18
const CELESTIAL_ARMOR_FEEDBACK_SHAKE_AMOUNT := 0.052
const CELESTIAL_ARMOR_FEEDBACK_SHAKE_INTENSITY := 2.4
const HERMES_SHOES_MAX_SPEED_BONUS_PCT := 300.0
const SPEEDGEAR_TURN_DECEL_MULTIPLIER := 2.5
const SENSOR_DEFAULT_COOLDOWN_SEC := 15.0
const SENSOR_MIN_COOLDOWN_SEC := 1.0
const SENSOR_AUTO_DASH_EFFECT_FRAMES := 34.0
const SENSOR_PLAYER_REACH_SPEED := 8.0
const SENSOR_DETECTION_HEIGHT_RATIO := 0.75
const SENSOR_MAX_TIME_TO_PLAYER_FRAMES := 60.0
const HERMES_SHOES_TRAIL_LIFE_FRAMES := 24.0
const HERMES_SHOES_TRAIL_MAX := 5
const HERMES_SHOES_MOVE_TRAIL_THRESHOLD := 2.0
const HERMES_SHOES_WING_FLAP_SPEED := 0.16
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
const REINFORCED_BOOMERANG_LAUNCH_CAP_PCT := 200.0
const REINFORCED_BOOMERANG_HOMING_CAP_PCT := 150.0
const REINFORCED_BOOMERANG_SPAWN_CAP_PCT := 2000.0
const REINFORCED_BOOMERANG_KNOCKBACK_MULTIPLIER := 1.4
const REINFORCED_BOOMERANG_STUN_MULTIPLIER := 1.6
const GOLD_BAR_SELL_PRICE := 2000
const GOLD_BAR_SPEED_PENALTY_PCT := 30.0
const COMMANDO_ARM_MAX_STACKS := 2
const COMMANDO_ARM_GENERIC_THROW_SPEED_PER_STACK := 0.5
const COMMANDO_ARM_THROW_SPEED_CAP_PCT := 200.0
const COMMANDO_ARM_EXPLOSION_RANGE_CAP_PCT := 200.0
const COMMANDO_ARM_SMOKE_DURATION_CAP_PCT := 300.0
const COMMANDO_ARM_PREP_REDUCTION_CAP_PCT := 95.0
const RAINBOW_FUR_GLOVE_MAX_TRIGGER_CHANCE_PCT := 100.0
const RAINBOW_FUR_GLOVE_MAX_COOLDOWN_REDUCTION_PCT := 95.0
const RAINBOW_FUR_GLOVE_AURA_FRAMES := 36.0
const RAINBOW_FUR_GLOVE_PARTICLE_COUNT := 18
const RAINBOW_FUR_GLOVE_PARTICLE_MAX := 42
const ADVERSITY_ARMOR_MAX_TRIGGER_CHANCE_PCT := 100.0
const ADVERSITY_ARMOR_DEFAULT_SERVE_SPEED_BONUS_PCT := 20.0
const ADVERSITY_ARMOR_FLASH_FRAMES := 30.0
const ADVERSITY_ARMOR_AURA_PARTICLE_MAX := 48
const ADVERSITY_ARMOR_BARRIER_PARTICLE_MAX := 72
const ADVERSITY_ARMOR_BARRIER_Y_OFFSET := 18.0
const SHRAPNEL_ARMOR_MAX_TRIGGER_CHANCE_PCT := 100.0
const SHRAPNEL_ARMOR_MAX_SHARD_COUNT := 24
const SHRAPNEL_ARMOR_MAX_GAUGE_COST := 200.0
const SHRAPNEL_ARMOR_SHARD_LIFE_FRAMES := 120.0
const SHRAPNEL_ARMOR_SHARD_TRAIL_POINTS := 5
const SHRAPNEL_ARMOR_DUST_MAX := 96
const SHRAPNEL_ARMOR_FLASH_FRAMES := 8.0
const SHRAPNEL_ARMOR_BOSS_STUN_FRAMES := 15.0
const SHRAPNEL_ARMOR_BOSS_KNOCKBACK_FRAMES := 36.0
const SHRAPNEL_ARMOR_BOSS_KNOCKBACK_DECAY := 0.85
const SHRAPNEL_ARMOR_BOSS_IMPACT_FRAMES := 15.0
const RAINBOW_FUR_GLOVE_COLORS := [
	Color(1.0, 80.0 / 255.0, 80.0 / 255.0, 1.0),
	Color(1.0, 160.0 / 255.0, 60.0 / 255.0, 1.0),
	Color(1.0, 240.0 / 255.0, 80.0 / 255.0, 1.0),
	Color(90.0 / 255.0, 220.0 / 255.0, 110.0 / 255.0, 1.0),
	Color(90.0 / 255.0, 170.0 / 255.0, 1.0, 1.0),
	Color(200.0 / 255.0, 110.0 / 255.0, 1.0, 1.0),
]
const BOOMERANG_ICON_PATH := "res://assets/sprites/items/boomerang.png"
const BOOMERANG_METAL_ICON_PATH := "res://assets/sprites/items/boomerang_metal.png"
const BASE_SPECIAL_GAUGE_MAX := 500.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const SNAPSHOT_CONSTANTS := {
	"item_megingjord": ITEM_MEGINGJORD,
	"item_ragnarok_hammer": ITEM_RAGNAROK_HAMMER,
	"item_poseidon_trident": ITEM_POSEIDON_TRIDENT,
	"base_special_gauge_max": BASE_SPECIAL_GAUGE_MAX,
	"venom_mist_radius": VENOM_MIST_RADIUS,
}
const CONTEXT_CONSTANTS := {
	"accessory_slot_keys": ACCESSORY_SLOT_KEYS,
	"arm_slot_keys": ARM_SLOT_KEYS,
	"dowsing_pendulum_attraction_force": DOWSING_PENDULUM_ATTRACTION_FORCE,
	"dowsing_pendulum_min_distance": DOWSING_PENDULUM_MIN_DISTANCE,
	"dowsing_pendulum_max_speed": DOWSING_PENDULUM_MAX_SPEED,
	"base_special_gauge_max": BASE_SPECIAL_GAUGE_MAX,
	"boomerang_icon_path": BOOMERANG_ICON_PATH,
	"boomerang_metal_icon_path": BOOMERANG_METAL_ICON_PATH,
	"commando_arm_max_stacks": COMMANDO_ARM_MAX_STACKS,
	"field_width": FIELD_WIDTH,
	"field_height": FIELD_HEIGHT,
	"item_baal_boots": ITEM_BAAL_BOOTS,
	"item_celestial_armor": ITEM_CELESTIAL_ARMOR,
	"item_commando_arm": ITEM_COMMANDO_ARM,
	"item_dowsing_goggles": ITEM_DOWSING_GOGGLES,
	"item_hermes_shoes": ITEM_HERMES_SHOES,
	"item_megingjord": ITEM_MEGINGJORD,
	"item_poseidon_trident": ITEM_POSEIDON_TRIDENT,
	"item_ragnarok_hammer": ITEM_RAGNAROK_HAMMER,
	"item_smartphone": ITEM_SMARTPHONE,
	"player_base_paddle_width": PLAYER_BASE_PADDLE_WIDTH,
	"player_base_paddle_height": PLAYER_BASE_PADDLE_HEIGHT,
	"venom_mist_radius": VENOM_MIST_RADIUS,
	"baal_rain_slow_multiplier": BAAL_RAIN_SLOW_MULTIPLIER,
	"ragnarok_boss_stun_frame_msec": RAGNAROK_BOSS_STUN_FRAME_MSEC,
}

var catalog: Object = MythicItemCatalog.new()
var audio_router: Object = MythicItemAudioRouter.new()
var context_builder: Object = MythicItemContextBuilder.new()
var debug_inventory: Object = MythicItemDebugInventory.new()
var equipment_index: Object = MythicItemEquipmentIndex.new()
var owner_syncer: Object = MythicItemOwnerSyncer.new()
var pickup_bonus: Object = MythicItemPickupBonus.new()
var roll_query: Object = MythicItemRollQuery.new()
var stage_immunity: Object = MythicItemStageImmunity.new()
var debug_management_menu: Object = PassiveMythicItemDebugMenu.new()
var activation_effect_renderer: Object = MegingjordActivationEffectRenderer.new()
var field_effect_renderer: Object = MythicItemFieldEffectRenderer.new()
var support_effect_renderer: Object = MythicItemSupportEffectRenderer.new()
var snapshot_builder: Object = MythicItemSnapshotBuilder.new()
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
var foul_whistle_state: Object = FoulWhistleState.new()
var revival_state: Object = RevivalState.new()
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
var rainbow_fur_glove_aura_life_frames := RAINBOW_FUR_GLOVE_AURA_FRAMES
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
var celestial_armor_state: Object = CelestialArmorState.new()
var hermes_shoes_state: Object = HermesShoesState.new()
var baal_boots_effect_renderer: Object = BaalBootsEffectRenderer.new()
var baal_boots_weather_state: Object = BaalBootsWeatherState.new()
var baal_boots_effect_state: Object = BaalBootsEffectState.new()
var baal_boots_combat_state: Object = BaalBootsCombatState.new()
var synced_special_gauge_max := BASE_SPECIAL_GAUGE_MAX
var runtime_perk_state_ref: Object = null
var pandora_legacy_choice_builder: Object = PandoraLegacyChoiceBuilder.new()
var pandora_legacy_grant_router: Object = PandoraLegacyGrantRouter.new()
var pandora_legacy_pool_builder: Object = PandoraLegacyPoolBuilder.new()
var pandora_legacy_selection_renderer: Object = PandoraLegacySelectionRenderer.new()
var pandora_legacy_selection_state: Object = PandoraLegacySelectionState.new()
var pandora_legacy_icon_texture_cache: Dictionary = {}


func reset() -> void:
	debug_management_menu.reset()
	if acquisition_cinematic != null:
		acquisition_cinematic.reset()
	inventory_items.clear()
	equipped_items.clear()
	runtime_perk_state_ref = null
	next_inventory_id = 1
	megingjord_extra_pick_count = 0
	dowsing_goggles_bonus_triggered = false
	synced_special_gauge_max = BASE_SPECIAL_GAUGE_MAX
	activation_started_msec = -1000000
	activation_particles.clear()
	activation_bolts.clear()
	_clear_ragnarok_runtime(null)
	_clear_poseidon_runtime(null)
	_clear_knee_pads_runtime()
	_clear_soul_burst_runtime()
	_clear_foul_whistle_runtime()
	_clear_revival_runtime(true)
	_clear_sensor_runtime(true)
	_clear_smartphone_runtime()
	_clear_venom_mist_runtime()
	_clear_rainbow_fur_glove_runtime()
	_clear_adversity_armor_runtime()
	_clear_shrapnel_armor_runtime()
	_clear_celestial_armor_runtime()
	_clear_hermes_shoes_runtime()
	_clear_baal_boots_runtime()
	_clear_pandora_legacy_runtime()


func build_starting_equipment_slots() -> Dictionary:
	return {}


func build_starting_inventory() -> Array:
	return []


func has_owned_item_name(item_name: String) -> bool:
	for item_value in inventory_items:
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func should_skip_one_time_passive_spawn(item_name: String) -> bool:
	var normalized_name := str(item_name)
	match normalized_name:
		ITEM_REVIVAL:
			return revival_state.used or has_owned_item_name(normalized_name)
		"lucky_coin", "rainbow_fur_glove", "star_detector", ITEM_SACRED_LAUREL:
			return has_owned_item_name(normalized_name)
		_:
			return false


func reset_round(registry: Object = null) -> void:
	if acquisition_cinematic != null:
		acquisition_cinematic.reset(registry)
	_clear_ragnarok_runtime(registry)
	_clear_poseidon_runtime(registry)
	_clear_knee_pads_runtime()
	_clear_soul_burst_runtime()
	_clear_foul_whistle_runtime()
	_clear_sensor_round_state()
	_clear_venom_mist_round_state()
	_clear_rainbow_fur_glove_round_state()
	_clear_adversity_armor_round_state()
	_clear_shrapnel_armor_round_state()
	_clear_celestial_armor_round_state()
	_clear_hermes_shoes_round_state()
	_clear_baal_boots_round_state(registry)


func refresh_runtime_perk_scaling(owner: Object = null, registry: Object = null) -> void:
	_sync_runtime_perk_state_ref(registry)
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
	var item_data: Dictionary = catalog.build_item_by_name(item_name)
	if item_data.is_empty():
		return -1
	var item_rolls: Dictionary = catalog.build_random_rolls(item_name)
	if item_rolls.is_empty():
		item_rolls = _get_dict(item_data.get("rolls", {})).duplicate(true)
	for key in roll_overrides.keys():
		item_rolls[str(key)] = roll_overrides[key]
	item_data["rolls"] = item_rolls
	var preserve_acquired_quality := _has_acquired_quality_identity(acquired_item_data)
	if preserve_acquired_quality:
		item_data = _copy_acquired_quality_identity(item_data, acquired_item_data)
	item_data = catalog.sync_roll_fields(item_data, false, not preserve_acquired_quality)
	item_data["owned"] = true
	item_data["equipped"] = false
	item_data["_equipped_slot"] = ""
	item_data["_inventory_id"] = next_inventory_id
	next_inventory_id += 1
	inventory_items.append(item_data)
	var index: int = inventory_items.size() - 1
	if auto_equip:
		if not equip_inventory_item(index, owner, registry):
			_sync_owner(owner, registry)
	else:
		_sync_owner(owner, registry)
	_try_grant_reinforced_boomerang_pickup_bonus(item_name, owner, registry)
	if play_pickup_sound:
		_play_pickup_audio(registry)
	return index


func equip_item(
	item_name: String,
	owner: Object,
	registry: Object = null,
	roll_overrides: Dictionary = {},
	play_pickup_sound: bool = false
) -> bool:
	var index: int = _find_inventory_index_by_name(item_name)
	if index < 0:
		index = acquire_item(item_name, owner, registry, roll_overrides, false, play_pickup_sound)
		if index < 0:
			return false
	else:
		_apply_roll_overrides(index, roll_overrides)
	var equipped: bool = equip_inventory_item(index, owner, registry)
	if play_pickup_sound and not equipped:
		_play_pickup_audio(registry)
	return equipped


func unequip_item(item_name: String, owner: Object, registry: Object = null) -> bool:
	var index: int = _find_equipped_inventory_index_by_name(item_name)
	if index < 0:
		return false
	return unequip_inventory_item(index, owner, registry)


func equip_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	if index < 0 or index >= inventory_items.size():
		return false
	if not (inventory_items[index] is Dictionary):
		return false
	var item_data: Dictionary = inventory_items[index]
	var item_name: String = str(item_data.get("name", ""))
	if _is_single_equipment_item(item_name):
		var equipped_index: int = _find_equipped_inventory_index_by_name(item_name)
		if equipped_index >= 0 and equipped_index != index:
			return false
	var slot_key: String = _resolve_equipment_slot_key(item_data, owner)
	if slot_key == "":
		return false
	if not _is_equipment_slot_enabled(slot_key, owner):
		return false
	for i in range(inventory_items.size()):
		if i == index or not (inventory_items[i] is Dictionary):
			continue
		var other: Dictionary = inventory_items[i]
		if str(other.get("_equipped_slot", "")) == slot_key:
			other["equipped"] = false
			other["_equipped_slot"] = ""
	item_data["equipped"] = true
	item_data["_equipped_slot"] = slot_key
	inventory_items[index] = item_data
	_rebuild_equipped_items()
	if str(item_data.get("name", "")) == ITEM_MEGINGJORD:
		megingjord_extra_pick_count = 0
	if str(item_data.get("name", "")) == ITEM_DOWSING_GOGGLES:
		dowsing_goggles_bonus_triggered = false
	if str(item_data.get("name", "")) == ITEM_RAGNAROK_HAMMER:
		_clear_ragnarok_runtime(registry)
	if str(item_data.get("name", "")) == ITEM_POSEIDON_TRIDENT:
		_clear_poseidon_runtime(registry)
	if str(item_data.get("name", "")) == ITEM_FOUL_WHISTLE:
		_clear_foul_whistle_runtime()
	if str(item_data.get("name", "")) == ITEM_SOUL_BURST:
		_clear_soul_burst_runtime()
	if str(item_data.get("name", "")) == ITEM_SENSOR:
		sensor_enabled = true
		_clear_sensor_round_state()
	if str(item_data.get("name", "")) == ITEM_SMARTPHONE:
		_clear_smartphone_runtime()
	if str(item_data.get("name", "")) == ITEM_VENOM_MIST_GAUNTLET and not is_venom_mist_gauntlet_equipped():
		_clear_venom_mist_runtime()
	if str(item_data.get("name", "")) == ITEM_RAINBOW_FUR_GLOVE:
		_clear_rainbow_fur_glove_runtime()
	if str(item_data.get("name", "")) == ITEM_ADVERSITY_ARMOR:
		_clear_adversity_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_SHRAPNEL_ARMOR:
		_clear_shrapnel_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_CELESTIAL_ARMOR:
		_clear_celestial_armor_round_state()
	if str(item_data.get("name", "")) == ITEM_HERMES_SHOES:
		_clear_hermes_shoes_round_state()
	elif not is_hermes_shoes_equipped():
		_clear_hermes_shoes_runtime()
	if str(item_data.get("name", "")) == ITEM_RAINBOW_FUR_GLOVE:
		_clear_rainbow_fur_glove_round_state()
	if str(item_data.get("name", "")) == ITEM_ADVERSITY_ARMOR:
		_clear_adversity_armor_round_state()
	if str(item_data.get("name", "")) == ITEM_SHRAPNEL_ARMOR:
		_clear_shrapnel_armor_round_state()
	if str(item_data.get("name", "")) == ITEM_BAAL_BOOTS:
		_clear_baal_boots_round_state(registry)
		_try_arm_baal_boots_from_weather(owner, registry)
	if str(item_data.get("name", "")) == ITEM_PANDORA_LEGACY:
		_clear_pandora_legacy_selection(false)
	_sync_owner(owner, registry)
	_play_equipment_audio(registry)
	return true


func unequip_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	if index < 0 or index >= inventory_items.size():
		return false
	if not (inventory_items[index] is Dictionary):
		return false
	var item_data: Dictionary = inventory_items[index]
	if not bool(item_data.get("equipped", false)) and str(item_data.get("_equipped_slot", "")) == "":
		return false
	item_data["equipped"] = false
	item_data["_equipped_slot"] = ""
	inventory_items[index] = item_data
	_rebuild_equipped_items()
	if str(item_data.get("name", "")) == ITEM_MEGINGJORD:
		megingjord_extra_pick_count = 0
	if str(item_data.get("name", "")) == ITEM_DOWSING_GOGGLES:
		dowsing_goggles_bonus_triggered = false
	if str(item_data.get("name", "")) == ITEM_RAGNAROK_HAMMER:
		_clear_ragnarok_runtime(registry)
	if str(item_data.get("name", "")) == ITEM_POSEIDON_TRIDENT:
		_clear_poseidon_runtime(registry)
	if str(item_data.get("name", "")) == ITEM_FOUL_WHISTLE:
		_clear_foul_whistle_runtime()
	if str(item_data.get("name", "")) == ITEM_SOUL_BURST:
		_clear_soul_burst_runtime()
	if str(item_data.get("name", "")) == ITEM_SENSOR:
		_clear_sensor_round_state()
	if str(item_data.get("name", "")) == ITEM_SMARTPHONE:
		_clear_smartphone_runtime()
	if str(item_data.get("name", "")) == ITEM_VENOM_MIST_GAUNTLET and not is_venom_mist_gauntlet_equipped():
		_clear_venom_mist_runtime()
	if str(item_data.get("name", "")) == ITEM_RAINBOW_FUR_GLOVE:
		_clear_rainbow_fur_glove_runtime()
	if str(item_data.get("name", "")) == ITEM_ADVERSITY_ARMOR:
		_clear_adversity_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_SHRAPNEL_ARMOR:
		_clear_shrapnel_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_CELESTIAL_ARMOR:
		_clear_celestial_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_HERMES_SHOES:
		_clear_hermes_shoes_runtime()
	if str(item_data.get("name", "")) == ITEM_BAAL_BOOTS:
		_clear_baal_boots_runtime(registry)
	if str(item_data.get("name", "")) == ITEM_PANDORA_LEGACY:
		_clear_pandora_legacy_runtime()
	_sync_owner(owner, registry)
	_play_equipment_audio(registry)
	return true


func toggle_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	if index < 0 or index >= inventory_items.size():
		return false
	var item_data: Dictionary = _get_dict(inventory_items[index])
	if item_data.is_empty():
		return false
	if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
		return unequip_inventory_item(index, owner, registry)
	return equip_inventory_item(index, owner, registry)


func unequip_slot(slot_key: String, owner: Object, registry: Object = null) -> bool:
	var index: int = _find_equipped_inventory_index_by_slot(slot_key)
	if index < 0:
		return false
	return unequip_inventory_item(index, owner, registry)


func discard_inventory_item(index: int, owner: Object, registry: Object = null) -> bool:
	if index < 0 or index >= inventory_items.size():
		return false
	var item_data: Dictionary = _get_dict(inventory_items[index])
	inventory_items.remove_at(index)
	if str(item_data.get("name", "")) == ITEM_MEGINGJORD:
		megingjord_extra_pick_count = 0
	if str(item_data.get("name", "")) == ITEM_DOWSING_GOGGLES:
		dowsing_goggles_bonus_triggered = false
	if str(item_data.get("name", "")) == ITEM_RAGNAROK_HAMMER:
		_clear_ragnarok_runtime(null)
	if str(item_data.get("name", "")) == ITEM_POSEIDON_TRIDENT:
		_clear_poseidon_runtime(null)
	if str(item_data.get("name", "")) == ITEM_FOUL_WHISTLE:
		_clear_foul_whistle_runtime()
	if str(item_data.get("name", "")) == ITEM_SENSOR:
		_clear_sensor_round_state()
	if str(item_data.get("name", "")) == ITEM_SMARTPHONE:
		_clear_smartphone_runtime()
	if str(item_data.get("name", "")) == ITEM_BAAL_BOOTS:
		_clear_baal_boots_runtime(registry)
	if str(item_data.get("name", "")) == ITEM_PANDORA_LEGACY:
		_clear_pandora_legacy_runtime()
	_rebuild_equipped_items()
	if str(item_data.get("name", "")) == ITEM_VENOM_MIST_GAUNTLET and not is_venom_mist_gauntlet_equipped():
		_clear_venom_mist_runtime()
	if str(item_data.get("name", "")) == ITEM_RAINBOW_FUR_GLOVE and not is_rainbow_fur_glove_equipped():
		_clear_rainbow_fur_glove_runtime()
	if str(item_data.get("name", "")) == ITEM_ADVERSITY_ARMOR and not is_adversity_armor_equipped():
		_clear_adversity_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_SHRAPNEL_ARMOR and not is_shrapnel_armor_equipped():
		_clear_shrapnel_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_CELESTIAL_ARMOR and not is_celestial_armor_equipped():
		_clear_celestial_armor_runtime()
	if str(item_data.get("name", "")) == ITEM_HERMES_SHOES and not is_hermes_shoes_equipped():
		_clear_hermes_shoes_runtime()
	if str(item_data.get("name", "")) == ITEM_BAAL_BOOTS and not is_baal_boots_equipped():
		_clear_baal_boots_runtime(registry)
	_sync_owner(owner, registry)
	return true


func debug_toggle_megingjord(owner: Object, registry: Object) -> bool:
	return debug_inventory.debug_toggle_megingjord(self, owner, registry, CONTEXT_CONSTANTS)


func debug_toggle_item(item_name: String, owner: Object, registry: Object) -> bool:
	return debug_inventory.debug_toggle_item(self, item_name, owner, registry)


func debug_add_item_to_inventory(item_name: String, owner: Object, registry: Object, roll_overrides: Dictionary = {}) -> bool:
	return debug_inventory.debug_add_item_to_inventory(self, item_name, owner, registry, roll_overrides)


func debug_build_roll_editor_item(item_name: String, roll_overrides: Dictionary = {}) -> Dictionary:
	return debug_inventory.debug_build_roll_editor_item(self, item_name, roll_overrides)


func get_debug_item_counts() -> Dictionary:
	return debug_inventory.get_debug_item_counts(self)


func debug_ensure_item_for_roll_editor(item_name: String, owner: Object, registry: Object) -> int:
	return debug_inventory.debug_ensure_item_for_roll_editor(self, item_name, owner, registry)


func debug_get_inventory_item(index: int) -> Dictionary:
	return debug_inventory.debug_get_inventory_item(self, index)


func get_inventory_item(index: int) -> Dictionary:
	if index < 0 or index >= inventory_items.size():
		return {}
	var item_data: Dictionary = _get_dict(inventory_items[index])
	return item_data.duplicate(true)


func debug_adjust_inventory_roll(index: int, option_key: String, delta_steps: int, owner: Object, registry: Object = null) -> bool:
	return debug_inventory.debug_adjust_inventory_roll(self, index, option_key, delta_steps, owner, registry, CONTEXT_CONSTANTS)


func get_debug_item_entries() -> Array:
	return debug_inventory.get_debug_item_entries(self)


func toggle_debug_management_menu() -> void:
	debug_management_menu.toggle(0)


func close_debug_management_menu() -> void:
	debug_management_menu.close()


func is_debug_management_menu_open() -> bool:
	return debug_management_menu.is_open()


func handle_debug_management_menu_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	return debug_management_menu.handle_input(event, owner, registry, view_size)


func draw_debug_management_menu(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	debug_management_menu.draw(canvas, owner, registry, view_size)


func is_equipped(item_name: String = ITEM_MEGINGJORD) -> bool:
	return equipped_items.has(item_name)


func on_new_perk_choice_batch(owner: Object = null) -> void:
	megingjord_extra_pick_count = 0
	dowsing_goggles_bonus_triggered = false
	_sync_owner(owner)


func should_check_extra_pick(choice_id: String) -> bool:
	return choice_id != "common_refresh"


func try_after_perk_choice(choice_id: String, owner: Object, registry: Object) -> bool:
	if not should_check_extra_pick(choice_id):
		return false
	if not is_equipped(ITEM_MEGINGJORD):
		return false
	if megingjord_extra_pick_count >= MEGINGJORD_MAX_EXTRA_PICKS:
		return false
	var chance_pct: float = get_megingjord_extra_pick_chance()
	if randf() >= chance_pct / 100.0:
		_sync_owner(owner, registry)
		return false
	megingjord_extra_pick_count += 1
	_start_activation_effect(owner, registry)
	_sync_owner(owner, registry)
	return true


func get_megingjord_extra_pick_chance() -> float:
	if not equipped_items.has(ITEM_MEGINGJORD):
		return 0.0
	var item_data: Dictionary = _get_dict(equipped_items[ITEM_MEGINGJORD])
	var value: float = _get_item_roll_value(item_data, ITEM_MEGINGJORD, "extra_pick_chance")
	return clamp(value, 0.0, 95.0)


func is_dowsing_pendulum_equipped() -> bool:
	return is_equipped(ITEM_DOWSING_PENDULUM)


func get_dowsing_pendulum_range() -> float:
	if not equipped_items.has(ITEM_DOWSING_PENDULUM):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_DOWSING_PENDULUM, "attraction_range"), 0.0, 600.0)


func get_dowsing_pendulum_context() -> Dictionary:
	return context_builder.get_dowsing_pendulum_context(self, CONTEXT_CONSTANTS)


func is_dowsing_goggles_equipped() -> bool:
	return is_equipped(ITEM_DOWSING_GOGGLES)


func is_dowsing_goggles_active() -> bool:
	return is_dowsing_goggles_equipped()


func get_dowsing_goggles_bonus_perk_chance_pct() -> float:
	if not is_dowsing_goggles_equipped():
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_DOWSING_GOGGLES, "bonus_perk_chance"), 0.0, 100.0)


func get_runtime_perk_choice_count_bonus(owner: Object = null, registry: Object = null) -> int:
	dowsing_goggles_bonus_triggered = false
	var chance_pct: float = get_dowsing_goggles_bonus_perk_chance_pct()
	if chance_pct <= 0.0:
		_sync_owner(owner, registry)
		return 0
	if randf() * 100.0 >= chance_pct:
		_sync_owner(owner, registry)
		return 0
	dowsing_goggles_bonus_triggered = true
	_sync_owner(owner, registry)
	return 1


func was_dowsing_goggles_bonus_triggered() -> bool:
	return dowsing_goggles_bonus_triggered


func clear_dowsing_goggles_bonus_trigger(owner: Object = null, registry: Object = null) -> void:
	dowsing_goggles_bonus_triggered = false
	_sync_owner(owner, registry)


func is_speedboots_equipped() -> bool:
	return is_equipped(ITEM_SPEEDBOOTS)


func get_speedboots_speed_bonus_pct() -> float:
	if not equipped_items.has(ITEM_SPEEDBOOTS):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_SPEEDBOOTS, "speed_bonus_pct"), 0.0, 200.0)


func is_speedgear_equipped() -> bool:
	return is_equipped(ITEM_SPEEDGEAR)


func is_gravitybelt_equipped() -> bool:
	return is_equipped(ITEM_GRAVITYBELT)


func is_gravitybelt_active() -> bool:
	return is_gravitybelt_equipped()


func apply_player_movement_config(config: Dictionary) -> void:
	config["gravitybelt_active"] = is_gravitybelt_active()
	config["gravitybelt_instant_movement"] = is_gravitybelt_active()


func get_speedgear_turn_decel_multiplier() -> float:
	if not is_speedgear_equipped():
		return 1.0
	return SPEEDGEAR_TURN_DECEL_MULTIPLIER


func get_player_turn_decel_multiplier() -> float:
	return get_speedgear_turn_decel_multiplier()


func is_sensor_equipped() -> bool:
	return is_equipped(ITEM_SENSOR)


func is_sensor_enabled() -> bool:
	return sensor_enabled


func set_sensor_enabled(enabled: bool, owner: Object = null, registry: Object = null) -> void:
	sensor_enabled = bool(enabled)
	_sync_owner(owner, registry)


func get_sensor_cooldown_seconds() -> float:
	if not is_sensor_equipped():
		return SENSOR_DEFAULT_COOLDOWN_SEC
	var seconds: float = _get_equipped_roll_value(ITEM_SENSOR, "sensor_cooldown_sec")
	if seconds <= 0.0:
		seconds = SENSOR_DEFAULT_COOLDOWN_SEC
	return max(SENSOR_MIN_COOLDOWN_SEC, seconds)


func get_sensor_cooldown_frames() -> float:
	return get_sensor_cooldown_seconds() * 60.0


func get_sensor_cooldown_remaining_seconds() -> float:
	return max(0.0, sensor_cooldown_timer_frames / 60.0)


func get_sensor_cooldown_progress() -> float:
	if not is_sensor_equipped():
		return 0.0
	var cooldown_frames: float = max(1.0, get_sensor_cooldown_frames())
	return clamp(1.0 - sensor_cooldown_timer_frames / cooldown_frames, 0.0, 1.0)


func is_sensor_auto_dash_ready() -> bool:
	return is_sensor_equipped() and sensor_enabled and sensor_cooldown_timer_frames <= 0.0


func get_sensor_context() -> Dictionary:
	return context_builder.get_sensor_context(self)


func build_sensor_auto_dash_request(player_pos: Vector2, config: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not is_sensor_auto_dash_ready():
		return {"should_dash": false, "reason": "cooldown_or_inactive"}
	if _is_sensor_runtime_blocked(config, deps):
		return {"should_dash": false, "reason": "blocked"}
	if not bool(config.get("ball_active", true)):
		return {"should_dash": false, "reason": "ball_inactive"}

	var ball_vel: Vector2 = _get_vector2(config.get("ball_vel", Vector2.ZERO))
	if ball_vel.y <= 0.0:
		return {"should_dash": false, "reason": "ball_not_incoming"}

	var height: float = max(1.0, float(config.get("height", FIELD_HEIGHT)))
	var ball_pos: Vector2 = _get_vector2(config.get("ball_pos", Vector2.ZERO))
	var ball_size: float = max(1.0, float(config.get("ball_size", 28.6)))
	var ball_center := ball_pos + Vector2(ball_size * 0.5, ball_size * 0.5)
	if ball_center.y <= height * SENSOR_DETECTION_HEIGHT_RATIO:
		return {"should_dash": false, "reason": "not_low_enough"}

	var paddle_width: float = max(1.0, float(config.get("paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var paddle_height: float = max(1.0, float(config.get("paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_center := player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)
	var time_to_reach_player: float = (player_center.y - ball_center.y) / ball_vel.y
	if time_to_reach_player <= 0.0 or time_to_reach_player >= SENSOR_MAX_TIME_TO_PLAYER_FRAMES:
		return {"should_dash": false, "reason": "not_immediate"}

	var predicted_x: float = ball_center.x + ball_vel.x * time_to_reach_player
	var player_max_distance: float = SENSOR_PLAYER_REACH_SPEED * time_to_reach_player
	var distance_to_predicted: float = abs(predicted_x - player_center.x)
	if distance_to_predicted <= player_max_distance + paddle_width * 0.5:
		return {"should_dash": false, "reason": "reachable"}

	var direction: float = 1.0 if predicted_x > player_center.x else -1.0
	return {
		"should_dash": true,
		"direction": direction,
		"predicted_x": predicted_x,
		"time_to_reach_player": time_to_reach_player,
		"distance_to_predicted": distance_to_predicted,
		"player_center": player_center,
	}


func notify_sensor_auto_dash_started(player_center: Vector2, direction: float, deps: Dictionary = {}) -> void:
	if not is_sensor_equipped():
		return
	var registry: Object = _get_dict(deps).get("registry", null)
	var owner: Object = _get_dict(deps).get("owner", null)
	sensor_cooldown_timer_frames = get_sensor_cooldown_frames()
	sensor_last_dash_direction = sign(direction)
	if abs(sensor_last_dash_direction) <= 0.01:
		sensor_last_dash_direction = 1.0
	sensor_auto_dash_center = player_center
	sensor_auto_dash_effect_timer_frames = SENSOR_AUTO_DASH_EFFECT_FRAMES
	_try_trigger_poseidon_vortex(owner, registry, sensor_last_dash_direction)
	_sync_owner(owner, registry)


func _is_sensor_runtime_blocked(config: Dictionary, deps: Dictionary) -> bool:
	var round_state: Object = _get_dict(deps).get("round_state", null)
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return true
	var wheel_state: Object = _get_dict(deps).get("smasher_wheel_state", null)
	if wheel_state != null and wheel_state.has_method("is_active") and bool(wheel_state.is_active()):
		return true
	if _is_sensor_player_stunned(deps):
		return true
	return _is_sensor_umbrella_blocked(config, deps)


func _is_sensor_player_stunned(deps: Dictionary) -> bool:
	var status_state: Object = _get_dict(deps).get("status_effect_state", null)
	if status_state != null and status_state.has_method("has_status") and bool(status_state.has_status("player", "stun")):
		return true
	var owner: Object = _get_dict(deps).get("owner", null)
	if owner == null:
		return false
	if bool(_safe_owner_get(owner, "player_stunned", false)):
		return true
	if float(_safe_owner_get(owner, "player_stunned_timer", 0.0)) > 0.0:
		return true
	return float(_safe_owner_get(owner, "player_missile_stunned_timer", 0.0)) > 0.0


func _is_sensor_umbrella_blocked(config: Dictionary, deps: Dictionary) -> bool:
	var owner: Object = _get_dict(deps).get("owner", null)
	var character_type: String = str(config.get(
		"selected_character_type",
		_safe_owner_get(owner, "selected_character_type", "")
	)).strip_edges().to_lower()
	if character_type != "blacksmith" and character_type != "baltor":
		return false
	return (
		bool(_safe_owner_get(owner, "blacksmith_umbrella_open", false))
		or float(_safe_owner_get(owner, "blacksmith_umbrella_anim_timer", 0.0)) > 0.0
		or bool(_safe_owner_get(owner, "blacksmith_umbrella_retracting", false))
		or bool(_safe_owner_get(owner, "blacksmith_umbrella_swing_active", false))
	)


func is_hermes_shoes_equipped() -> bool:
	return is_equipped(ITEM_HERMES_SHOES)


func is_hermes_shoes_active() -> bool:
	return is_hermes_shoes_equipped()


func get_hermes_shoes_speed_bonus_pct() -> float:
	if not is_hermes_shoes_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_HERMES_SHOES, "speed_bonus"),
		0.0,
		HERMES_SHOES_MAX_SPEED_BONUS_PCT
	)


func get_hermes_shoes_speed_multiplier() -> float:
	return max(0.0, 1.0 + get_hermes_shoes_speed_bonus_pct() / 100.0)


func get_hermes_shoes_context() -> Dictionary:
	return context_builder.get_hermes_shoes_context(self)


func get_player_speed_multiplier() -> float:
	var multiplier: float = max(0.0, 1.0 + get_speedboots_speed_bonus_pct() / 100.0)
	return max(0.0, multiplier * get_hermes_shoes_speed_multiplier() * get_gold_bar_speed_multiplier() * get_sage_ring_speed_multiplier() * _get_baal_boots_player_speed_multiplier())


func is_bulkup_equipped() -> bool:
	return _has_equipped_item_name(ITEM_BULKUP)


func get_bulkup_body_size_pct() -> float:
	if not is_bulkup_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_BULKUP, "body_size_pct"), 0.0, 500.0)


func get_player_paddle_scale() -> float:
	return max(0.1, 1.0 + get_bulkup_body_size_pct() / 100.0 - get_sage_ring_body_penalty_pct() / 100.0)


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	return max(1.0, float(base_width) * get_player_paddle_scale())


func get_player_paddle_height(base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	return max(1.0, float(base_height) * get_player_paddle_scale())


func is_spikeboots_equipped() -> bool:
	return is_equipped(ITEM_SPIKEBOOTS)


func get_spikeboots_dash_afterdelay_reduction_pct() -> float:
	if not equipped_items.has(ITEM_SPIKEBOOTS):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_SPIKEBOOTS, "dash_afterdelay_pct"), 0.0, 95.0)


func get_spikeboots_dash_cooldown_reduction_pct() -> float:
	if not equipped_items.has(ITEM_SPIKEBOOTS):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_SPIKEBOOTS, "dash_cooldown_pct"), 0.0, 95.0)


func is_bulletproof_hat_equipped() -> bool:
	return is_equipped(ITEM_BULLETPROOF_HAT)


func get_bulletproof_hat_stun_resist_pct() -> float:
	if not equipped_items.has(ITEM_BULLETPROOF_HAT):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_BULLETPROOF_HAT, "stun_resist_pct"), 0.0, 100.0)


func get_player_stun_resist_pct() -> float:
	return get_bulletproof_hat_stun_resist_pct()


func get_player_stun_duration_seconds(base_seconds: float) -> float:
	var resist_scale: float = max(0.0, 1.0 - get_player_stun_resist_pct() / 100.0)
	return max(0.0, float(base_seconds) * resist_scale)


func is_spiked_helmet_equipped() -> bool:
	return is_equipped(ITEM_SPIKED_HELMET)


func get_spiked_helmet_knockback_resist_pct() -> float:
	if not equipped_items.has(ITEM_SPIKED_HELMET):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_SPIKED_HELMET, "knockback_resist_pct"), 0.0, 100.0)


func get_player_knockback_resist_pct() -> float:
	return get_spiked_helmet_knockback_resist_pct()


func get_player_knockback_resist_scale() -> float:
	return max(0.0, 1.0 - get_player_knockback_resist_pct() / 100.0)


func is_celestial_armor_equipped() -> bool:
	return _has_equipped_item_name(ITEM_CELESTIAL_ARMOR)


func is_celestial_armor_active() -> bool:
	return is_celestial_armor_equipped()


func get_celestial_armor_trigger_chance_pct() -> float:
	if not is_celestial_armor_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_CELESTIAL_ARMOR, "trigger_chance_pct"),
		0.0,
		CELESTIAL_ARMOR_MAX_TRIGGER_CHANCE_PCT
	)


func get_celestial_armor_gauge_cost() -> float:
	if not is_celestial_armor_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_CELESTIAL_ARMOR, "gauge_cost"),
		0.0,
		CELESTIAL_ARMOR_MAX_GAUGE_COST
	)


func get_celestial_armor_context() -> Dictionary:
	return context_builder.get_celestial_armor_context(self)


func is_baal_boots_equipped() -> bool:
	return _has_equipped_item_name(ITEM_BAAL_BOOTS)


func is_baal_boots_active() -> bool:
	return is_baal_boots_equipped()


func get_baal_boots_gauge_recovery() -> float:
	if not is_baal_boots_equipped():
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_BAAL_BOOTS, "gauge_recovery"), 0.0, 2000.0)


func get_baal_boots_context() -> Dictionary:
	return context_builder.get_baal_boots_context(self)


func should_pause_game() -> bool:
	return baal_boots_weather_state.cinematic_active or (acquisition_cinematic != null and acquisition_cinematic.is_active()) or pandora_legacy_selection_state.is_active()


func is_baal_boots_cinematic_active() -> bool:
	return baal_boots_weather_state.cinematic_active


func is_acquisition_cinematic_active() -> bool:
	return acquisition_cinematic != null and acquisition_cinematic.is_active()


func start_acquisition_cinematic(
	acquired_item_data: Dictionary,
	pickup_position: Vector2,
	owner: Object,
	registry: Object = null
) -> bool:
	if acquired_item_data.is_empty():
		return false
	if not _should_use_acquisition_cinematic(acquired_item_data):
		return false
	if acquisition_cinematic == null:
		if not (owner is Node):
			return false
		var node: Node2D = MythicItemAcquisitionCinematicV2.new()
		(owner as Node).add_child(node)
		acquisition_cinematic = node
	acquisition_cinematic.trigger(
		acquired_item_data,
		pickup_position,
		_resolve_acquisition_player_center(owner),
		registry
	)
	return true


func handle_acquisition_cinematic_input(event: InputEvent, registry: Object = null) -> bool:
	if acquisition_cinematic == null:
		return false
	return acquisition_cinematic.handle_input(event, registry)


func get_acquisition_cinematic_snapshot() -> Dictionary:
	if acquisition_cinematic == null:
		return {}
	return acquisition_cinematic.get_snapshot()


func is_pandora_legacy_equipped() -> bool:
	return is_equipped(ITEM_PANDORA_LEGACY)


func is_pandora_legacy_active() -> bool:
	return is_pandora_legacy_equipped()


func get_pandora_legacy_selection_quality() -> float:
	if not is_pandora_legacy_equipped():
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_PANDORA_LEGACY, "selection_quality"), 0.0, 100.0)


func get_pandora_legacy_trigger_chance() -> float:
	if not is_pandora_legacy_equipped():
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_PANDORA_LEGACY, "trigger_chance"), 0.0, 100.0)


func is_pandora_legacy_selection_active() -> bool:
	return pandora_legacy_selection_state.is_active()


func update_pandora_legacy_selection_overlay(delta: float) -> void:
	if not pandora_legacy_selection_state.is_active():
		return
	pandora_legacy_selection_state.advance_timer(max(0.0, delta * 60.0))


func has_pending_pandora_legacy_selection() -> bool:
	return pandora_legacy_selection_state.has_pending()


func try_queue_pandora_legacy_round_win(deps: Dictionary = {}) -> bool:
	pandora_legacy_selection_state.reset_trigger_result()
	if not is_pandora_legacy_active():
		return false
	var trigger_chance: float = get_pandora_legacy_trigger_chance()
	if trigger_chance <= 0.0:
		return false
	var roll: float = randf() * 100.0
	pandora_legacy_selection_state.set_trigger_roll(roll)
	if roll >= trigger_chance:
		return false
	var owner: Object = _get_dict(deps).get("owner", null)
	var registry: Object = _get_dict(deps).get("registry", null)
	var choices: Array = generate_pandora_legacy_selection_choices(owner, registry)
	if choices.size() < PANDORA_SELECTION_CARD_COUNT:
		return false
	pandora_legacy_selection_state.queue_choices(choices)
	return true


func start_pending_pandora_legacy_selection(owner: Object = null, registry: Object = null) -> bool:
	if not pandora_legacy_selection_state.start_pending():
		return false
	_sync_owner(owner, registry)
	_queue_owner_redraw(owner)
	return true


func start_pandora_legacy_selection(choices: Array, owner: Object = null, registry: Object = null) -> bool:
	if not pandora_legacy_selection_state.start(choices):
		return false
	_sync_owner(owner, registry)
	_queue_owner_redraw(owner)
	return true


func confirm_pandora_legacy_selection(index: int, owner: Object, registry: Object = null) -> bool:
	if not pandora_legacy_selection_state.is_active():
		return false
	var selected_item: Dictionary = pandora_legacy_selection_state.get_selected_item(index)
	if selected_item.is_empty():
		return false
	var granted: bool = _grant_pandora_legacy_selected_item(selected_item, owner, registry)
	_clear_pandora_legacy_selection(false)
	if granted:
		_play_pickup_audio(registry)
	_sync_owner(owner, registry)
	_queue_owner_redraw(owner)
	return granted


func cancel_pandora_legacy_selection(owner: Object, registry: Object = null) -> bool:
	return confirm_pandora_legacy_selection(0, owner, registry)


func generate_pandora_legacy_selection_choices(owner: Object = null, _registry: Object = null) -> Array:
	var quality_bonus: float = get_pandora_legacy_selection_quality() / 100.0
	return pandora_legacy_choice_builder.generate_choices(
		pandora_legacy_pool_builder.build_active_pool(owner),
		pandora_legacy_pool_builder.build_passive_pool(catalog, owner),
		pandora_legacy_pool_builder.build_mythic_pool(catalog),
		quality_bonus,
		PANDORA_ACTIVE_ITEM_KOREAN_NAMES,
		PANDORA_SELECTION_CARD_COUNT
	)


func handle_pandora_legacy_selection_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	if not pandora_legacy_selection_state.is_active():
		return false
	if event is InputEventMouseMotion:
		var hover_index: int = _get_pandora_card_index_at(event.position, view_size)
		if hover_index >= 0 and hover_index != int(pandora_legacy_selection_state.selected_index):
			pandora_legacy_selection_state.set_selected_index(hover_index)
			_queue_owner_redraw(owner)
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_index: int = _get_pandora_card_index_at(mouse_event.position, view_size)
			if clicked_index >= 0:
				confirm_pandora_legacy_selection(clicked_index, owner, registry)
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		var keycode: int = key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		match keycode:
			KEY_LEFT, KEY_A:
				pandora_legacy_selection_state.move_selected(-1)
				_queue_owner_redraw(owner)
				return true
			KEY_RIGHT, KEY_D:
				pandora_legacy_selection_state.move_selected(1)
				_queue_owner_redraw(owner)
				return true
			KEY_SPACE, KEY_ENTER:
				confirm_pandora_legacy_selection(int(pandora_legacy_selection_state.selected_index), owner, registry)
				return true
			KEY_ESCAPE:
				cancel_pandora_legacy_selection(owner, registry)
				return true
	return true


func draw_pandora_legacy_selection(
	canvas: CanvasItem,
	_owner: Object,
	registry: Object,
	view_size: Vector2
) -> void:
	if canvas == null or not pandora_legacy_selection_state.is_active():
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var intro_alpha: float = clamp(float(pandora_legacy_selection_state.timer_frames) / 20.0, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.01, 0.04, 0.72 * intro_alpha))
	var title_center := Vector2(view_size.x * 0.5, max(72.0, view_size.y * 0.18))
	_draw_pandora_centered_text(canvas, font, "판도라의 유산", title_center, 30, Color(1.0, 0.86, 0.32, intro_alpha))
	_draw_pandora_centered_text(
		canvas,
		font,
		"아이템을 선택하세요",
		title_center + Vector2(0.0, 34.0),
		15,
		Color(0.78, 0.82, 0.92, intro_alpha)
	)
	var selection_items: Array = pandora_legacy_selection_state.items
	for i in range(PANDORA_SELECTION_CARD_COUNT):
		var rect: Rect2 = _get_pandora_card_rect(i, view_size)
		var item_data: Dictionary = _get_dict(selection_items[i]) if i < selection_items.size() else {}
		_draw_pandora_choice_card(canvas, font, rect, item_data, i == int(pandora_legacy_selection_state.selected_index), intro_alpha, registry)
	_draw_pandora_centered_text(
		canvas,
		font,
		"← → / 클릭 / Enter",
		Vector2(view_size.x * 0.5, min(view_size.y - 38.0, title_center.y + 284.0)),
		13,
		Color(0.64, 0.68, 0.78, intro_alpha)
	)


func on_weather_round_start(owner: Object, registry: Object, weather_type: String = "") -> void:
	_clear_baal_boots_round_state(registry)
	if weather_type != "":
		_try_arm_baal_boots_from_weather(owner, registry, weather_type)
	else:
		_try_arm_baal_boots_from_weather(owner, registry)


func try_consume_celestial_armor_immunity(
	source: String = "",
	effect_type: String = "",
	deps: Dictionary = {}
) -> bool:
	var normalized_effect_type: String = effect_type.strip_edges().to_lower() if effect_type != "" else "generic"
	if normalized_effect_type != "stun":
		return false
	if celestial_armor_state.consume_paired_proc_bypass(source, normalized_effect_type):
		return true

	if not is_celestial_armor_equipped():
		return false
	var chance_pct: float = get_celestial_armor_trigger_chance_pct()
	if chance_pct <= 0.0 or randf() * 100.0 > chance_pct:
		return false
	var gauge_cost: int = max(0, int(round(get_celestial_armor_gauge_cost())))
	if not _consume_celestial_armor_gauge(gauge_cost, deps):
		return false

	_start_celestial_armor_wave(_resolve_celestial_armor_player_center(deps), source)
	celestial_armor_state.record_block(source, normalized_effect_type, CELESTIAL_ARMOR_PAIRED_PROC_WINDOW_FRAMES)
	_apply_ragnarok_feedback(
		deps,
		CELESTIAL_ARMOR_FEEDBACK_SHAKE_AMOUNT,
		CELESTIAL_ARMOR_FEEDBACK_SHAKE_INTENSITY
	)
	_trigger_gauge_feedback(deps)
	_play_celestial_armor_audio(_get_dict(deps).get("registry", null))
	var owner: Object = deps.get("owner", null)
	if owner != null:
		_sync_owner(owner, _get_dict(deps).get("registry", null))
	return true


func get_dash_recovery_frames(base_frames: float) -> float:
	var reduction_pct: float = get_spikeboots_dash_afterdelay_reduction_pct()
	return max(1.0, float(base_frames) * max(0.0, 1.0 - reduction_pct / 100.0))


func get_dash_recharge_frames(base_frames: float) -> float:
	var reduction_pct: float = get_spikeboots_dash_cooldown_reduction_pct()
	return max(1.0, float(base_frames) * max(0.0, 1.0 - reduction_pct / 100.0))


func is_slot_add_equipped() -> bool:
	return is_equipped(ITEM_SLOT_ADD)


func get_slot_add_active_item_slot_bonus() -> int:
	if not equipped_items.has(ITEM_SLOT_ADD):
		return 0
	var item_data: Dictionary = _get_dict(equipped_items[ITEM_SLOT_ADD])
	var rolls: Dictionary = _get_dict(item_data.get("rolls", {}))
	var value: float = float(rolls.get(
		"slot_add_count",
		catalog.get_default_roll_value(ITEM_SLOT_ADD, "slot_add_count")
	))
	var enhancement_bonus_pct: float = max(0.0, float(item_data.get("enhancement_bonus_pct", 0.0)))
	if enhancement_bonus_pct > 0.0:
		value *= 1.0 + enhancement_bonus_pct / 100.0
	return max(0, int(floor(value)))


func get_active_item_slot_capacity(base_slots: int = 3) -> int:
	return max(1, int(base_slots) + get_slot_add_active_item_slot_bonus())


func is_chargebag_equipped() -> bool:
	return _has_equipped_item_name(ITEM_CHARGEBAG)


func get_chargebag_wall_bounce_gauge_pct() -> float:
	if not is_chargebag_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_CHARGEBAG, "chargebag_pct"), 0.0, 500.0)


func apply_chargebag_wall_bounce_gauge(special_gauge: float, context: Dictionary, deps: Dictionary) -> float:
	if not is_chargebag_equipped() or _is_aipill_active_from_deps(deps):
		return special_gauge
	var bonus_pct: float = get_chargebag_wall_bounce_gauge_pct()
	if bonus_pct <= 0.0:
		return special_gauge
	var base_gain: float = _resolve_chargebag_base_wall_gauge_gain(context)
	if base_gain <= 0.0:
		return special_gauge
	var gain: float = floor(base_gain * bonus_pct / 100.0)
	gain = apply_gold_digger_gauge_bonus(gain)
	if gain <= 0.0:
		return special_gauge
	var gauge_max: float = max(0.0, float(context.get("gauge_max", context.get("special_gauge_max", 500.0))))
	var next_gauge: float = min(gauge_max, special_gauge + gain)
	if next_gauge > special_gauge:
		_trigger_gauge_feedback(deps)
	return next_gauge


func is_battery_equipped() -> bool:
	return _has_equipped_item_name(ITEM_BATTERY)


func get_battery_gauge_preserve_pct() -> float:
	if not is_battery_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_BATTERY, "gauge_preserve_pct"), 0.0, 100.0)


func get_stage_transition_gauge(current_gauge: float, gauge_max: float = 500.0, aipill_active: bool = false) -> float:
	var safe_max: float = max(0.0, gauge_max)
	var safe_gauge: float = clamp(float(current_gauge), 0.0, safe_max)
	if aipill_active:
		return safe_gauge
	var preserve_pct: float = get_battery_gauge_preserve_pct()
	if preserve_pct <= 0.0:
		return 0.0
	return clamp(floor(safe_gauge * preserve_pct / 100.0), 0.0, safe_max)


func is_knee_pads_equipped() -> bool:
	return _has_equipped_item_name(ITEM_KNEE_PADS)


func get_knee_pads_charge_pct() -> float:
	if not is_knee_pads_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_KNEE_PADS, "knee_charge_pct"), 0.0, 500.0)


func try_apply_knee_pads_player_hit(
	ball_pos: Vector2,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if not is_knee_pads_equipped():
		knee_pads_half_dash_consumed = false
		return {}
	if not _is_knee_pads_half_dash_window_active(deps):
		return {}
	if knee_pads_half_dash_consumed:
		return {}

	var charge_pct: float = get_knee_pads_charge_pct()
	var base_charge: float = _resolve_knee_pads_base_charge(context)
	var charge_amount: float = max(0.0, base_charge * charge_pct / 100.0)
	charge_amount = apply_gold_digger_gauge_bonus(charge_amount)
	if charge_amount <= 0.0:
		return {}

	knee_pads_half_dash_consumed = true
	var gauge_max: float = max(0.0, float(context.get("gauge_max", context.get("special_gauge_max", 500.0))))
	var next_gauge: float = min(gauge_max, max(0.0, special_gauge) + charge_amount)
	if next_gauge > special_gauge:
		_trigger_gauge_feedback(deps)
	_trigger_orb_gauge_spin(deps)
	_start_knee_pads_effect(ball_pos, deps)
	_play_knee_pads_audio(_get_dict(deps).get("registry", null))
	return {
		"special_gauge": next_gauge,
		"activated": true,
		"charge_amount": max(0.0, next_gauge - special_gauge),
	}


func is_fuel_pouch_equipped() -> bool:
	return _has_equipped_item_name(ITEM_FUEL_POUCH)


func get_fuel_pouch_gauge_bonus() -> float:
	if not is_fuel_pouch_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_FUEL_POUCH, "fuel_bonus_flat"), 0.0, 1000.0)


func get_effective_special_gauge_max(base_max: float = BASE_SPECIAL_GAUGE_MAX) -> float:
	return max(1.0, float(base_max) + get_fuel_pouch_gauge_bonus())


func is_bluetooth_ring_equipped() -> bool:
	return _has_equipped_item_name(ITEM_BLUETOOTH_RING)


func is_bluetooth_ring_active() -> bool:
	return is_bluetooth_ring_equipped()


func get_bluetooth_ring_gauge_gain_pct() -> float:
	if not is_bluetooth_ring_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_BLUETOOTH_RING, "gauge_gain_pct"), 0.0, 500.0)


func get_bluetooth_ring_gauge_multiplier() -> float:
	return max(0.0, 1.0 + get_bluetooth_ring_gauge_gain_pct() / 100.0)


func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
	if not is_bluetooth_ring_equipped():
		return float(base_charge)
	return floor(max(0.0, float(base_charge)) * get_bluetooth_ring_gauge_multiplier())


func is_star_detector_equipped() -> bool:
	return _has_equipped_item_name(ITEM_STAR_DETECTOR)


func is_star_detector_active() -> bool:
	return is_star_detector_equipped()


func get_star_detector_star_bonus_pct() -> float:
	if not is_star_detector_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_STAR_DETECTOR, "star_bonus_pct"), 0.0, 100.0)


func get_star_detector_bonus_chance() -> float:
	return get_star_detector_star_bonus_pct() / 100.0


func roll_star_detector_bonus_drop_count() -> int:
	var chance: float = get_star_detector_bonus_chance()
	if chance <= 0.0:
		return 0
	return 1 if randf() < chance else 0


func is_sage_ring_equipped() -> bool:
	return _has_equipped_item_name(ITEM_SAGE_RING)


func is_sage_ring_active() -> bool:
	return is_sage_ring_equipped()


func get_sage_ring_count() -> int:
	return _count_equipped_item_name(ITEM_SAGE_RING)


func get_sage_ring_perk_level_bonus() -> int:
	if not is_sage_ring_equipped():
		return 0
	return get_sage_ring_count() * SAGE_RING_PERK_LEVEL_BONUS


func get_sage_ring_speed_penalty_pct() -> float:
	if not is_sage_ring_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_SAGE_RING, "sage_speed_penalty_pct"),
		0.0,
		SAGE_RING_MAX_SPEED_PENALTY_PCT
	)


func get_sage_ring_body_penalty_pct() -> float:
	if not is_sage_ring_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_SAGE_RING, "sage_body_penalty_pct"),
		0.0,
		SAGE_RING_MAX_BODY_PENALTY_PCT
	)


func get_sage_ring_speed_multiplier() -> float:
	return max(0.0, 1.0 - get_sage_ring_speed_penalty_pct() / 100.0)


func is_smartphone_equipped() -> bool:
	return _has_equipped_item_name(ITEM_SMARTPHONE)


func is_smartphone_active() -> bool:
	return is_smartphone_equipped()


func get_smartphone_count() -> int:
	return _count_equipped_item_name(ITEM_SMARTPHONE)


func is_neural_helmet_equipped() -> bool:
	return _has_equipped_item_name(ITEM_NEURAL_HELMET)


func is_neural_helmet_active() -> bool:
	return is_neural_helmet_equipped()


func get_neural_helmet_count() -> int:
	return _count_equipped_item_name(ITEM_NEURAL_HELMET)


func get_neural_helmet_aipill_gauge_reduction() -> float:
	if not is_neural_helmet_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_NEURAL_HELMET, "aipill_gauge_reduction"),
		0.0,
		NEURAL_HELMET_GAUGE_REDUCTION_CAP
	)


func get_neural_helmet_aipill_spawn_bonus_pct() -> float:
	if not is_neural_helmet_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_NEURAL_HELMET, "aipill_spawn_bonus_pct"),
		0.0,
		NEURAL_HELMET_SPAWN_CAP_PCT
	)


func get_aipill_gauge_drain(base_drain: float = 90.0) -> float:
	return max(0.0, float(base_drain) - get_neural_helmet_aipill_gauge_reduction())


func get_aipill_item_spawn_multiplier() -> float:
	return max(0.0, 1.0 + get_neural_helmet_aipill_spawn_bonus_pct() / 100.0)


func get_aipill_item_spawn_chance(base_chance: float) -> float:
	return max(0.0, float(base_chance) * get_aipill_item_spawn_multiplier())


func should_cancel_aipill_on_direction_key() -> bool:
	return is_neural_helmet_equipped()


func is_venom_mist_gauntlet_equipped() -> bool:
	return _has_equipped_item_name(ITEM_VENOM_MIST_GAUNTLET)


func is_venom_mist_gauntlet_active() -> bool:
	return is_venom_mist_gauntlet_equipped()


func get_venom_mist_gauntlet_count() -> int:
	return _count_equipped_item_name(ITEM_VENOM_MIST_GAUNTLET)


func get_venom_mist_trigger_chance_pct() -> float:
	if not is_venom_mist_gauntlet_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_VENOM_MIST_GAUNTLET, "mist_trigger_chance_pct"),
		0.0,
		VENOM_MIST_MAX_TRIGGER_CHANCE_PCT
	)


func get_venom_mist_trigger_chance() -> float:
	return get_venom_mist_trigger_chance_pct() / 100.0


func get_venom_mist_duration_sec() -> float:
	if not is_venom_mist_gauntlet_equipped():
		return 0.0
	var duration_sec: float = _get_equipped_roll_max(ITEM_VENOM_MIST_GAUNTLET, "mist_duration_sec")
	if duration_sec <= 0.0:
		duration_sec = VENOM_MIST_DEFAULT_DURATION_SEC
	return clamp(duration_sec, 2.0, 5.0)


func get_venom_mist_boss_slow_multiplier() -> float:
	return max(0.05, 1.0 - VENOM_MIST_BOSS_SLOW_AMOUNT)


func is_venom_mist_ball_poisoned() -> bool:
	return venom_mist_ball_poisoned


func is_venom_mist_field_active() -> bool:
	return venom_mist_field_active


func is_boss_in_venom_mist() -> bool:
	return venom_mist_field_active and venom_mist_boss_in_field


func get_venom_mist_context() -> Dictionary:
	return context_builder.get_venom_mist_context(self, CONTEXT_CONSTANTS)


func try_venom_mist_poison_ball(deps: Dictionary = {}) -> bool:
	if not is_venom_mist_gauntlet_equipped():
		venom_mist_ball_poisoned = false
		return false
	if venom_mist_ball_poisoned:
		return true
	var chance: float = get_venom_mist_trigger_chance()
	if chance <= 0.0 or randf() >= chance:
		return false
	venom_mist_ball_poisoned = true
	_play_venom_mist_poison_audio(_get_dict(deps).get("registry", null))
	return true


func consume_venom_mist_ball_poison(boss_center: Vector2, deps: Dictionary = {}) -> bool:
	if not venom_mist_ball_poisoned:
		return false
	venom_mist_ball_poisoned = false
	return try_spawn_venom_mist_at_boss(boss_center, deps, true)


func try_spawn_venom_mist_at_boss(
	boss_center: Vector2,
	deps: Dictionary = {},
	force: bool = false
) -> bool:
	if not is_venom_mist_gauntlet_equipped():
		return false
	if not force:
		var chance: float = get_venom_mist_trigger_chance()
		if chance <= 0.0 or randf() >= chance:
			return false
	_start_venom_mist_field(boss_center, _get_dict(deps).get("registry", null))
	return true


func clear_venom_mist_round_state() -> void:
	_clear_venom_mist_round_state()


func is_reinforced_boomerang_gauntlet_equipped() -> bool:
	return _has_equipped_item_name(ITEM_REINFORCED_BOOMERANG_GAUNTLET)


func is_reinforced_boomerang_gauntlet_active() -> bool:
	return is_reinforced_boomerang_gauntlet_equipped()


func get_reinforced_boomerang_gauntlet_count() -> int:
	return _count_equipped_item_name(ITEM_REINFORCED_BOOMERANG_GAUNTLET)


func get_boomerang_launch_speed_pct() -> float:
	if not is_reinforced_boomerang_gauntlet_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_launch_speed_pct"),
		0.0,
		REINFORCED_BOOMERANG_LAUNCH_CAP_PCT
	)


func get_boomerang_homing_pct() -> float:
	if not is_reinforced_boomerang_gauntlet_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_homing_pct"),
		0.0,
		REINFORCED_BOOMERANG_HOMING_CAP_PCT
	)


func get_boomerang_spawn_bonus_pct() -> float:
	if not is_reinforced_boomerang_gauntlet_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_sum(ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_spawn_bonus_pct"),
		0.0,
		REINFORCED_BOOMERANG_SPAWN_CAP_PCT
	)


func get_boomerang_launch_speed_multiplier() -> float:
	return max(0.0, 1.0 + get_boomerang_launch_speed_pct() / 100.0)


func get_boomerang_homing_multiplier() -> float:
	return max(0.0, 1.0 + get_boomerang_homing_pct() / 100.0)


func get_boomerang_item_spawn_multiplier() -> float:
	return max(0.0, 1.0 + get_boomerang_spawn_bonus_pct() / 100.0)


func get_boomerang_item_spawn_chance(base_chance: float) -> float:
	return max(0.0, float(base_chance) * get_boomerang_item_spawn_multiplier())


func get_boomerang_knockback_multiplier() -> float:
	return REINFORCED_BOOMERANG_KNOCKBACK_MULTIPLIER if is_reinforced_boomerang_gauntlet_equipped() else 1.0


func get_boomerang_stun_multiplier() -> float:
	return REINFORCED_BOOMERANG_STUN_MULTIPLIER if is_reinforced_boomerang_gauntlet_equipped() else 1.0


func is_commando_arm_equipped() -> bool:
	return _has_equipped_item_name(ITEM_COMMANDO_ARM)


func is_commando_arm_active() -> bool:
	return is_commando_arm_equipped()


func get_commando_arm_count() -> int:
	return min(COMMANDO_ARM_MAX_STACKS, _count_equipped_item_name(ITEM_COMMANDO_ARM))


func get_commando_arm_throw_speed_pct() -> float:
	if not is_commando_arm_equipped():
		return 0.0
	return clamp(
		_get_commando_arm_roll_sum("throw_speed_pct"),
		0.0,
		COMMANDO_ARM_THROW_SPEED_CAP_PCT
	)


func get_commando_arm_explosion_range_pct() -> float:
	if not is_commando_arm_equipped():
		return 0.0
	return clamp(
		_get_commando_arm_roll_sum("explosion_range_pct"),
		0.0,
		COMMANDO_ARM_EXPLOSION_RANGE_CAP_PCT
	)


func get_commando_arm_smoke_duration_pct() -> float:
	if not is_commando_arm_equipped():
		return 0.0
	return clamp(
		_get_commando_arm_roll_sum("smoke_duration_pct"),
		0.0,
		COMMANDO_ARM_SMOKE_DURATION_CAP_PCT
	)


func get_commando_arm_prep_reduction_pct() -> float:
	if not is_commando_arm_equipped():
		return 0.0
	return clamp(
		_get_commando_arm_roll_sum("prep_reduction_pct"),
		0.0,
		COMMANDO_ARM_PREP_REDUCTION_CAP_PCT * COMMANDO_ARM_MAX_STACKS
	)


func get_commando_arm_prep_multiplier() -> float:
	if not is_commando_arm_equipped():
		return 1.0
	var multiplier := 1.0
	for reduction_value in _get_commando_arm_roll_values("prep_reduction_pct"):
		var reduction_pct: float = clamp(float(reduction_value), 0.0, COMMANDO_ARM_PREP_REDUCTION_CAP_PCT)
		multiplier *= max(0.01, 1.0 - reduction_pct / 100.0)
	return max(0.01, multiplier)


func get_commando_arm_windup_msec(base_msec: int) -> int:
	if not is_commando_arm_equipped():
		return max(1, int(base_msec))
	return max(1, int(floor(float(base_msec) * get_commando_arm_prep_multiplier())))


func get_commando_arm_throw_speed_multiplier(use_rolled_speed: bool = false) -> float:
	if not is_commando_arm_equipped():
		return 1.0
	if use_rolled_speed:
		return max(0.0, 1.0 + get_commando_arm_throw_speed_pct() / 100.0)
	return max(0.0, 1.0 + COMMANDO_ARM_GENERIC_THROW_SPEED_PER_STACK * float(get_commando_arm_count()))


func get_commando_arm_range_multiplier() -> float:
	return max(0.0, 1.0 + get_commando_arm_explosion_range_pct() / 100.0)


func get_commando_arm_range_value(base_value: float) -> float:
	return max(0.0, float(base_value) * get_commando_arm_range_multiplier())


func get_commando_arm_smoke_duration_multiplier() -> float:
	return max(0.0, 1.0 + get_commando_arm_smoke_duration_pct() / 100.0)


func get_commando_arm_duration_frames(base_frames: float) -> float:
	return max(0.0, float(base_frames) * get_commando_arm_smoke_duration_multiplier())


func get_commando_arm_context() -> Dictionary:
	return context_builder.get_commando_arm_context(self)


func is_rainbow_fur_glove_equipped() -> bool:
	return is_equipped(ITEM_RAINBOW_FUR_GLOVE)


func is_rainbow_fur_glove_active() -> bool:
	return is_rainbow_fur_glove_equipped()


func get_rainbow_fur_glove_trigger_chance_pct() -> float:
	if not is_rainbow_fur_glove_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_RAINBOW_FUR_GLOVE, "rainbow_glove_trigger_chance_pct"),
		0.0,
		RAINBOW_FUR_GLOVE_MAX_TRIGGER_CHANCE_PCT
	)


func get_rainbow_fur_glove_cooldown_reduction_pct() -> float:
	if not is_rainbow_fur_glove_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_RAINBOW_FUR_GLOVE, "rainbow_glove_cooldown_reduction_pct"),
		0.0,
		RAINBOW_FUR_GLOVE_MAX_COOLDOWN_REDUCTION_PCT
	)


func get_rainbow_fur_glove_context() -> Dictionary:
	return context_builder.get_rainbow_fur_glove_context(self)


func try_proc_rainbow_fur_glove_player_hit(
	ball_pos: Vector2,
	context: Dictionary = {},
	deps: Dictionary = {}
) -> Dictionary:
	if not is_rainbow_fur_glove_equipped():
		_clear_rainbow_fur_glove_runtime()
		return {"activated": false}
	var chance_pct: float = get_rainbow_fur_glove_trigger_chance_pct()
	if chance_pct <= 0.0 or randf() * 100.0 >= chance_pct:
		return {"activated": false}
	var reduction_pct: float = get_rainbow_fur_glove_cooldown_reduction_pct()
	var reduction_fraction: float = clamp(reduction_pct / 100.0, 0.0, 0.95)
	if reduction_fraction <= 0.0:
		return {"activated": false}
	var current_msec: int = _resolve_context_msec(context)
	var changed_count: int = _apply_rainbow_fur_glove_skill_cooldown_reduction(
		reduction_fraction,
		current_msec,
		deps
	)
	rainbow_fur_glove_last_reduction_pct = reduction_pct
	_start_rainbow_fur_glove_aura(_resolve_rainbow_fur_glove_center(ball_pos, context, deps))
	_play_rainbow_fur_glove_audio(_get_dict(deps).get("registry", null))
	_apply_ragnarok_feedback(deps, 0.035, 1.6)
	var owner: Object = _get_dict(deps).get("owner", null)
	_sync_owner(owner, _get_dict(deps).get("registry", null))
	return {
		"activated": true,
		"cooldown_reduction_pct": reduction_pct,
		"cooldown_reduction_fraction": reduction_fraction,
		"cooldown_states_changed": changed_count,
	}


func is_adversity_armor_equipped() -> bool:
	return _has_equipped_item_name(ITEM_ADVERSITY_ARMOR)


func is_adversity_armor_active() -> bool:
	return is_adversity_armor_equipped()


func is_adversity_armor_invincible() -> bool:
	return is_adversity_armor_equipped() and adversity_armor_invincible_timer_frames > 0.0


func get_adversity_armor_trigger_chance_pct() -> float:
	if not is_adversity_armor_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_ADVERSITY_ARMOR, "trigger_chance_pct"),
		0.0,
		ADVERSITY_ARMOR_MAX_TRIGGER_CHANCE_PCT
	)


func get_adversity_armor_invincible_duration_sec() -> float:
	if not is_adversity_armor_equipped():
		return 0.0
	return max(0.0, _get_equipped_roll_value(ITEM_ADVERSITY_ARMOR, "invincible_duration_sec"))


func get_adversity_armor_serve_speed_bonus_pct() -> float:
	return ADVERSITY_ARMOR_DEFAULT_SERVE_SPEED_BONUS_PCT if is_adversity_armor_equipped() else 0.0


func get_adversity_armor_context() -> Dictionary:
	return context_builder.get_adversity_armor_context(self)


func get_ball_collision_context() -> Dictionary:
	if not is_adversity_armor_invincible():
		return {"adversity_armor_invincible": false}
	return {
		"adversity_armor_invincible": true,
		"adversity_armor_barrier_y": _get_adversity_armor_barrier_y(),
	}


func try_queue_adversity_armor_after_loss(deps: Dictionary = {}) -> bool:
	if not is_adversity_armor_equipped():
		_clear_adversity_armor_runtime()
		return false
	var chance_pct: float = get_adversity_armor_trigger_chance_pct()
	if chance_pct <= 0.0:
		adversity_armor_last_trigger_roll_pct = -1.0
		adversity_armor_last_triggered = false
		return false
	if adversity_armor_pending_invincible:
		return true
	var roll_pct: float = randf() * 100.0
	adversity_armor_last_trigger_roll_pct = roll_pct
	adversity_armor_last_triggered = roll_pct <= chance_pct
	if not adversity_armor_last_triggered:
		_sync_owner(_get_dict(deps).get("owner", null), _get_dict(deps).get("registry", null))
		return false
	adversity_armor_pending_invincible = true
	adversity_armor_serve_speed_boost_pending = true
	_sync_owner(_get_dict(deps).get("owner", null), _get_dict(deps).get("registry", null))
	return true


func on_round_start(owner: Object, registry: Object = null) -> void:
	if not is_adversity_armor_equipped():
		_clear_adversity_armor_runtime()
		_sync_owner(owner, registry)
		return
	if not adversity_armor_pending_invincible:
		return
	adversity_armor_pending_invincible = false
	var duration_frames: float = get_adversity_armor_invincible_duration_sec() * 60.0
	adversity_armor_invincible_timer_frames = max(0.0, duration_frames)
	adversity_armor_invincible_total_frames = adversity_armor_invincible_timer_frames
	adversity_armor_flash_timer_frames = ADVERSITY_ARMOR_FLASH_FRAMES
	adversity_armor_last_reflect_center = Vector2(FIELD_WIDTH * 0.5, _get_adversity_armor_barrier_y())
	_spawn_adversity_armor_barrier_particles(adversity_armor_last_reflect_center, 22, false)
	_play_adversity_armor_activate_audio(registry)
	_apply_ragnarok_feedback({"registry": registry}, 0.05, 1.7)
	_sync_owner(owner, registry)
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func consume_adversity_armor_serve_speed_bonus() -> float:
	if not is_adversity_armor_equipped():
		adversity_armor_serve_speed_boost_pending = false
		return 0.0
	if not adversity_armor_serve_speed_boost_pending:
		return 0.0
	adversity_armor_serve_speed_boost_pending = false
	return get_adversity_armor_serve_speed_bonus_pct() / 100.0


func notify_adversity_armor_barrier_hit(
	impact_pos: Vector2,
	ball_vel: Vector2 = Vector2.ZERO,
	deps: Dictionary = {}
) -> void:
	if not is_adversity_armor_invincible():
		return
	adversity_armor_last_reflect_center = impact_pos
	adversity_armor_flash_timer_frames = max(adversity_armor_flash_timer_frames, ADVERSITY_ARMOR_FLASH_FRAMES * 0.55)
	_spawn_adversity_armor_barrier_particles(impact_pos, 18, true)
	_play_adversity_armor_reflect_audio(_get_dict(deps).get("registry", null), abs(ball_vel.y))
	_apply_ragnarok_feedback(deps, 0.06, 2.4)
	_sync_owner(_get_dict(deps).get("owner", null), _get_dict(deps).get("registry", null))

func is_shrapnel_armor_equipped() -> bool:
	return _has_equipped_item_name(ITEM_SHRAPNEL_ARMOR)


func is_shrapnel_armor_active() -> bool:
	return is_shrapnel_armor_equipped()


func get_shrapnel_armor_trigger_chance_pct() -> float:
	if not is_shrapnel_armor_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_SHRAPNEL_ARMOR, "trigger_chance_pct"),
		0.0,
		SHRAPNEL_ARMOR_MAX_TRIGGER_CHANCE_PCT
	)


func get_shrapnel_armor_shard_count() -> int:
	if not is_shrapnel_armor_equipped():
		return 0
	return clampi(
		int(round(_get_equipped_roll_value(ITEM_SHRAPNEL_ARMOR, "shard_count"))),
		0,
		SHRAPNEL_ARMOR_MAX_SHARD_COUNT
	)


func get_shrapnel_armor_knockback_level() -> int:
	if not is_shrapnel_armor_equipped():
		return 0
	return max(1, int(round(_get_equipped_roll_value(ITEM_SHRAPNEL_ARMOR, "knockback_level"))))


func get_shrapnel_armor_gauge_cost() -> float:
	if not is_shrapnel_armor_equipped():
		return 0.0
	return clamp(
		_get_equipped_roll_value(ITEM_SHRAPNEL_ARMOR, "gauge_cost"),
		0.0,
		SHRAPNEL_ARMOR_MAX_GAUGE_COST
	)


func get_shrapnel_armor_context() -> Dictionary:
	return context_builder.get_shrapnel_armor_context(self)


func try_proc_shrapnel_armor_player_hit(
	ball_pos: Vector2,
	context: Dictionary = {},
	deps: Dictionary = {}
) -> Dictionary:
	if not is_shrapnel_armor_equipped():
		_clear_shrapnel_armor_runtime()
		return {"activated": false}
	var chance_pct: float = get_shrapnel_armor_trigger_chance_pct()
	if chance_pct <= 0.0:
		return {"activated": false}
	var gauge_cost: float = get_shrapnel_armor_gauge_cost()
	var current_gauge: float = _get_shrapnel_armor_current_gauge(context, deps)
	if current_gauge + 0.001 < gauge_cost:
		return {
			"activated": false,
			"special_gauge": current_gauge,
			"insufficient_gauge": true,
			"gauge_cost": gauge_cost,
		}
	if randf() * 100.0 >= chance_pct:
		return {"activated": false, "special_gauge": current_gauge}
	var spend_result: Dictionary = _consume_shrapnel_armor_gauge(gauge_cost, context, deps)
	if not bool(spend_result.get("ok", false)):
		return {
			"activated": false,
			"special_gauge": float(spend_result.get("special_gauge", current_gauge)),
			"insufficient_gauge": true,
			"gauge_cost": gauge_cost,
		}
	var shard_count: int = get_shrapnel_armor_shard_count()
	var knockback_level: int = get_shrapnel_armor_knockback_level()
	_start_shrapnel_armor_burst(_resolve_shrapnel_armor_spawn_center(ball_pos, context, deps), shard_count)
	shrapnel_armor_last_proc_shard_count = shard_count
	shrapnel_armor_last_gauge_cost = gauge_cost
	_play_shrapnel_armor_fire_audio(_get_dict(deps).get("registry", null))
	_apply_ragnarok_feedback(deps, 0.045, 1.8)
	_trigger_gauge_feedback(deps)
	var owner: Object = _get_dict(deps).get("owner", null)
	_sync_owner(owner, _get_dict(deps).get("registry", null))
	return {
		"activated": true,
		"special_gauge": float(spend_result.get("special_gauge", current_gauge)),
		"gauge_cost": gauge_cost,
		"trigger_chance_pct": chance_pct,
		"shard_count": shard_count,
		"knockback_level": knockback_level,
	}


func is_foul_whistle_equipped() -> bool:
	return _has_equipped_item_name(ITEM_FOUL_WHISTLE)


func is_foul_whistle_active() -> bool:
	return is_foul_whistle_equipped()


func get_foul_whistle_negate_chance_pct() -> float:
	if not is_foul_whistle_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_FOUL_WHISTLE, "negate_chance_pct"), 0.0, 100.0)


func get_foul_whistle_negate_chance() -> float:
	return get_foul_whistle_negate_chance_pct() / 100.0


func try_trigger_foul_whistle(loss_type: String = "round", audio_source: Variant = null) -> bool:
	if not is_foul_whistle_equipped() or foul_whistle_state.animation_active:
		return false
	var chance: float = get_foul_whistle_negate_chance()
	if chance <= 0.0 or randf() >= chance:
		return false
	foul_whistle_state.start(loss_type)
	_play_foul_whistle_audio(audio_source)
	return true


func consume_foul_whistle_reset_ready() -> bool:
	return foul_whistle_state.consume_reset_ready()


func is_foul_whistle_effect_active() -> bool:
	return foul_whistle_state.animation_active


func is_revival_equipped() -> bool:
	return _has_equipped_item_name(ITEM_REVIVAL)


func is_revival_available() -> bool:
	return revival_state.is_available(is_revival_equipped())


func has_revival_used() -> bool:
	return revival_state.used


func is_revival_effect_active() -> bool:
	return revival_state.is_effect_active()


func try_trigger_revival(loss_type: String = "round", context: Dictionary = {}) -> bool:
	if not is_revival_available():
		return false
	revival_state.start(loss_type, REVIVAL_EFFECT_FRAMES)
	var owner: Object = _get_dict(context).get("owner", null)
	var registry: Object = _get_dict(context).get("registry", null)
	_consume_equipped_item_name(ITEM_REVIVAL, owner, registry)
	return true


func is_gold_digger_equipped() -> bool:
	return _has_equipped_item_name(ITEM_GOLD_DIGGER)


func get_gold_digger_count() -> int:
	return _count_equipped_item_name(ITEM_GOLD_DIGGER)


func get_gold_digger_gold_bonus_pct() -> float:
	if not is_gold_digger_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_GOLD_DIGGER, "gold_bonus_pct"), 0.0, 2000.0)


func get_gold_digger_multiplier() -> float:
	return max(0.0, 1.0 + get_gold_digger_gold_bonus_pct() / 100.0)


func apply_gold_digger_gauge_bonus(gauge_gain: float) -> float:
	if not is_gold_digger_equipped():
		return float(gauge_gain)
	return floor(max(0.0, float(gauge_gain)) * get_gold_digger_multiplier())


func apply_gold_digger_gold_bonus(amount: int) -> int:
	if not is_gold_digger_equipped():
		return max(0, amount)
	return int(floor(float(max(0, amount)) * get_gold_digger_multiplier()))


func is_gold_bar_equipped() -> bool:
	return _has_equipped_item_name(ITEM_GOLD_BAR)


func is_gold_bar_owned() -> bool:
	return get_gold_bar_count() > 0


func is_gold_bar_active() -> bool:
	return is_gold_bar_owned()


func get_gold_bar_count() -> int:
	return _count_owned_item_name(ITEM_GOLD_BAR)


func get_gold_bar_sell_price() -> int:
	return GOLD_BAR_SELL_PRICE if is_gold_bar_active() else 0


func get_gold_bar_total_sell_price() -> int:
	return get_gold_bar_count() * GOLD_BAR_SELL_PRICE


func get_gold_bar_speed_penalty_pct() -> float:
	return GOLD_BAR_SPEED_PENALTY_PCT if is_gold_bar_active() else 0.0


func get_gold_bar_speed_multiplier() -> float:
	if not is_gold_bar_active():
		return 1.0
	return max(0.0, 1.0 - GOLD_BAR_SPEED_PENALTY_PCT / 100.0)


func is_lucky_coin_equipped() -> bool:
	return _has_equipped_item_name(ITEM_LUCKY_COIN)


func is_lucky_coin_active() -> bool:
	return is_lucky_coin_equipped()


func get_lucky_coin_double_spawn_pct() -> float:
	if not is_lucky_coin_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_LUCKY_COIN, "double_spawn_pct"), 0.0, 100.0)


func get_lucky_coin_double_spawn_chance() -> float:
	return get_lucky_coin_double_spawn_pct() / 100.0


func should_lucky_coin_double_spawn() -> bool:
	var chance: float = get_lucky_coin_double_spawn_chance()
	return chance > 0.0 and randf() < chance


func is_master_equipped() -> bool:
	return _has_equipped_item_name(ITEM_MASTER)


func get_master_wall_length_bonus_pct() -> float:
	if not is_master_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_MASTER, "wall_length_pct"), 0.0, 500.0)


func get_master_item_cooldown_reduction_pct() -> float:
	if not is_master_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_MASTER, "item_cooldown_pct"), 0.0, 95.0)


func get_master_wall_spawn_bonus_pct() -> float:
	if not is_master_equipped():
		return 0.0
	return clamp(_get_equipped_roll_sum(ITEM_MASTER, "wall_spawn_bonus_pct"), 0.0, 2000.0)


func get_brick_wall_width(base_width: float) -> float:
	return max(1.0, float(base_width) * (1.0 + get_master_wall_length_bonus_pct() / 100.0))


func get_wall_item_spawn_chance(base_chance: float) -> float:
	return max(0.0, float(base_chance) * (1.0 + get_master_wall_spawn_bonus_pct() / 100.0))


func is_cooltime_equipped() -> bool:
	return _has_equipped_item_name(ITEM_COOLTIME)


func get_cooltime_active_item_cooldown_reduction_pct() -> float:
	return clamp(_get_equipped_roll_sum(ITEM_COOLTIME, "active_cooldown_pct"), 0.0, 95.0)


func get_total_active_item_cooldown_reduction_pct() -> float:
	var multiplier := 1.0
	multiplier *= max(0.0, 1.0 - get_master_item_cooldown_reduction_pct() / 100.0)
	multiplier *= max(0.0, 1.0 - get_cooltime_active_item_cooldown_reduction_pct() / 100.0)
	return clamp((1.0 - multiplier) * 100.0, 0.0, 100.0)


func get_active_item_cooldown_msec(base_cooldown_msec: int) -> int:
	var adjusted: float = float(max(0, base_cooldown_msec))
	var master_reduction_pct: float = get_master_item_cooldown_reduction_pct()
	if master_reduction_pct > 0.0:
		adjusted *= max(0.0, 1.0 - master_reduction_pct / 100.0)
	var cooltime_reduction_pct: float = get_cooltime_active_item_cooldown_reduction_pct()
	if cooltime_reduction_pct > 0.0:
		adjusted *= max(0.0, 1.0 - cooltime_reduction_pct / 100.0)
	return max(0, int(round(adjusted)))


func is_timer_belt_equipped() -> bool:
	return _has_equipped_item_name(ITEM_TIMER_BELT)


func get_timer_belt_skill_cooldown_reduction_pct() -> float:
	return clamp(_get_equipped_roll_sum(ITEM_TIMER_BELT, "skill_cooldown_pct"), 0.0, 95.0)


func is_sacred_laurel_equipped() -> bool:
	return _has_equipped_item_name(ITEM_SACRED_LAUREL)


func get_sacred_laurel_leaf_bonus() -> int:
	if not is_sacred_laurel_equipped():
		return 0
	return max(0, int(round(_get_equipped_roll_sum(ITEM_SACRED_LAUREL, "leaf_count"))))


func get_sacred_laurel_context() -> Dictionary:
	return context_builder.get_sacred_laurel_context(self)


func is_transcendent_crown_equipped() -> bool:
	return _has_equipped_item_name(ITEM_TRANSCENDENT_CROWN)


func get_transcendent_crown_skill_bonus() -> int:
	if not is_transcendent_crown_equipped():
		return 0
	return max(0, int(_get_equipped_roll_value(ITEM_TRANSCENDENT_CROWN, "skill_bonus")))


func get_total_item_perk_level_bonus() -> int:
	return max(0, get_sage_ring_perk_level_bonus() + get_transcendent_crown_skill_bonus())


func get_transcendent_crown_context() -> Dictionary:
	return context_builder.get_transcendent_crown_context(self)


func is_heavenly_cape_equipped() -> bool:
	return _has_equipped_item_name(ITEM_HEAVENLY_CAPE)


func get_heavenly_cape_skill_cooldown_reduction_pct() -> float:
	return clamp(_get_equipped_roll_sum(ITEM_HEAVENLY_CAPE, "skill_cooldown_reduction"), 0.0, 95.0)


func get_heavenly_cape_skill_slot_bonus() -> int:
	if not is_heavenly_cape_equipped():
		return 0
	return 1


func get_player_skill_max_slots(base_slots: int = 5) -> int:
	return max(1, int(base_slots) + get_heavenly_cape_skill_slot_bonus())


func get_player_skill_cooldown_multiplier() -> float:
	var multiplier := 1.0
	var timer_reduction_pct: float = get_timer_belt_skill_cooldown_reduction_pct()
	if timer_reduction_pct > 0.0:
		multiplier *= max(0.0, 1.0 - timer_reduction_pct / 100.0)
	var cape_reduction_pct: float = get_heavenly_cape_skill_cooldown_reduction_pct()
	if cape_reduction_pct > 0.0:
		multiplier *= max(0.0, 1.0 - cape_reduction_pct / 100.0)
	return max(0.0, multiplier)


func get_player_skill_cooldown_seconds(base_cooldown_seconds: float) -> float:
	return max(0.0, float(base_cooldown_seconds) * get_player_skill_cooldown_multiplier())


func is_dashgear_equipped() -> bool:
	return is_equipped(ITEM_DASHGEAR)


func get_dashgear_dash_distance_bonus_pct() -> float:
	if not equipped_items.has(ITEM_DASHGEAR):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_DASHGEAR, "dash_distance_pct"), 0.0, 200.0)


func get_dashgear_boost_charge_chance_pct() -> float:
	if not equipped_items.has(ITEM_DASHGEAR):
		return 0.0
	return clamp(_get_equipped_roll_value(ITEM_DASHGEAR, "boost_charge_pct"), 0.0, 100.0)


func get_dash_duration_frames(base_frames: float) -> float:
	var bonus_pct: float = get_dashgear_dash_distance_bonus_pct()
	return max(1.0, float(base_frames) * (1.0 + bonus_pct / 100.0))


func get_boost_charge_chance_pct() -> float:
	return max(0.0, get_dashgear_boost_charge_chance_pct())


func is_soul_burst_equipped() -> bool:
	return _has_equipped_item_name(ITEM_SOUL_BURST)


func is_soul_burst_active() -> bool:
	return is_soul_burst_equipped()


func get_soul_burst_gauge_cost() -> float:
	if not is_soul_burst_equipped():
		return SOUL_BURST_DEFAULT_GAUGE_COST
	var cost: float = _get_equipped_roll_value(ITEM_SOUL_BURST, "soul_burst_gauge_cost")
	if cost <= 0.0:
		cost = SOUL_BURST_DEFAULT_GAUGE_COST
	return clamp(cost, SOUL_BURST_MIN_GAUGE_COST, SOUL_BURST_MAX_GAUGE_COST)


func can_soul_burst_dash(special_gauge: float) -> bool:
	return is_soul_burst_equipped() and float(special_gauge) + 0.001 >= get_soul_burst_gauge_cost()


func try_consume_soul_burst_dash(
	special_gauge: float,
	player_center: Vector2,
	direction: float,
	registry: Object = null
) -> Dictionary:
	var current_gauge: float = max(0.0, float(special_gauge))
	if not can_soul_burst_dash(current_gauge):
		return {
			"activated": false,
			"special_gauge": current_gauge,
		}
	var gauge_cost: float = get_soul_burst_gauge_cost()
	trigger_soul_burst_effect(player_center, direction, registry)
	return {
		"activated": true,
		"soul_burst_dash": true,
		"gauge_cost": gauge_cost,
		"special_gauge": max(0.0, current_gauge - gauge_cost),
	}


func trigger_soul_burst_effect(player_center: Vector2, direction: float, registry: Object = null) -> void:
	soul_burst_center = player_center
	soul_burst_direction = sign(direction)
	if abs(soul_burst_direction) <= 0.01:
		soul_burst_direction = 1.0
	soul_burst_effect_timer_frames = SOUL_BURST_EFFECT_FRAMES
	soul_burst_dash_active = true
	_build_soul_burst_effects()
	_play_soul_burst_audio(registry)
	_apply_ragnarok_feedback({"registry": registry}, 0.11, 4.2)


func is_dashholder_equipped() -> bool:
	return get_dashholder_dash_token_bonus() > 0


func get_dashholder_dash_token_bonus() -> int:
	return max(0, _count_equipped_item_name(ITEM_DASHHOLDER))


func get_dash_token_capacity(base_tokens: int = 1, runtime_perk_state: Object = null) -> int:
	var capacity: int = max(1, int(base_tokens)) + get_dashholder_dash_token_bonus()
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_bonus"):
		capacity += int(runtime_perk_state.get_runtime_skill_bonus("dash_amplification"))
	return max(1, capacity)


func update(owner: Object, registry: Object, delta: float) -> void:
	if not _has_runtime_update_work():
		_poll_idle_poseidon_dash_trigger(owner, registry)
		return
	var fps_scale: float = max(0.0, delta * 60.0)
	if acquisition_cinematic != null:
		acquisition_cinematic.update(delta, registry)
	if pandora_legacy_selection_state.is_active():
		pandora_legacy_selection_state.advance_timer(fps_scale)
	var had_ragnarok_stun: bool = ragnarok_boss_stun_timer_frames > 0.0
	if ragnarok_boss_stun_timer_frames > 0.0:
		ragnarok_boss_stun_timer_frames = max(0.0, ragnarok_boss_stun_timer_frames - fps_scale)
	if ragnarok_boss_knockback_timer_frames > 0.0:
		ragnarok_boss_knockback_timer_frames = max(0.0, ragnarok_boss_knockback_timer_frames - fps_scale)
		ragnarok_boss_knockback_vel *= pow(RAGNAROK_BOSS_KNOCKBACK_DECAY, fps_scale)
		if ragnarok_boss_knockback_timer_frames <= 0.0 or abs(ragnarok_boss_knockback_vel) <= 0.3:
			ragnarok_boss_knockback_timer_frames = 0.0
			ragnarok_boss_knockback_vel = 0.0
	elif abs(ragnarok_boss_knockback_vel) > 0.0:
		ragnarok_boss_knockback_vel = 0.0
	if ragnarok_boss_stun_timer_frames > 0.0:
		_update_ragnarok_stun_target(owner)
	else:
		ragnarok_boss_electric_drift_vel = 0.0
	if _is_stage2_speed_defense_boss_immune(registry):
		_clear_ragnarok_boss_disable_state(registry)
	_update_ragnarok_sparks(delta)
	if had_ragnarok_stun and ragnarok_boss_stun_timer_frames <= 0.0:
		_stop_ragnarok_shock_audio(registry)
	elif ragnarok_boss_stun_timer_frames > 0.0:
		_play_ragnarok_shock_audio(registry)
	_update_smartphone_runtime(owner, registry, fps_scale)
	_update_knee_pads_runtime(fps_scale)
	_update_soul_burst_runtime(fps_scale)
	_update_foul_whistle_runtime(fps_scale)
	_update_revival_runtime(fps_scale)
	_update_sensor_runtime(fps_scale)
	_update_venom_mist_runtime(owner, registry, fps_scale)
	_update_rainbow_fur_glove_runtime(fps_scale)
	_update_adversity_armor_runtime(owner, registry, fps_scale)
	_update_shrapnel_armor_runtime(owner, registry, fps_scale)
	_update_poseidon_runtime(owner, registry, fps_scale)
	_update_celestial_armor_runtime(fps_scale)
	_update_hermes_shoes_runtime(owner, fps_scale)
	_update_baal_boots_runtime(owner, registry, fps_scale)
	_sync_owner(owner, registry)


func _has_runtime_update_work() -> bool:
	if acquisition_cinematic != null and acquisition_cinematic.has_method("is_active") and bool(acquisition_cinematic.is_active()):
		return true
	if pandora_legacy_selection_state.is_active():
		return true
	return _has_transient_runtime_update_work()


func _has_transient_runtime_update_work() -> bool:
	if is_activation_effect_active():
		return true
	if (
		ragnarok_stun_ball_active
		or ragnarok_stun_attempted_this_rally
		or ragnarok_boss_stun_timer_frames > 0.0
		or ragnarok_boss_knockback_timer_frames > 0.0
		or abs(ragnarok_boss_knockback_vel) > 0.0
		or ragnarok_shock_loop_active
		or not ragnarok_sparks.is_empty()
	):
		return true
	if (
		poseidon_effect_cooldown_frames > 0.0
		or poseidon_vortex_active
		or poseidon_vortex_reentry_cooldown_frames > 0.0
		or poseidon_water_trail_active
		or poseidon_explosion_active
		or poseidon_capture_active
		or not poseidon_particles.is_empty()
		or not poseidon_water_trail.is_empty()
		or not poseidon_explosion_particles.is_empty()
	):
		return true
	if knee_pads_flash_timer_frames > 0.0 or not knee_pads_particles.is_empty():
		return true
	if (
		soul_burst_effect_timer_frames > 0.0
		or soul_burst_dash_active
		or not soul_burst_particles.is_empty()
		or not soul_burst_shockwaves.is_empty()
		or not soul_burst_wind_trails.is_empty()
	):
		return true
	if foul_whistle_state.animation_active or foul_whistle_state.pending_round_reset:
		return true
	if revival_state.is_effect_active():
		return true
	if sensor_cooldown_timer_frames > 0.0 or sensor_auto_dash_effect_timer_frames > 0.0:
		return true
	if smartphone_cooldown_frames > 0.0:
		return true
	if venom_mist_field_active or not venom_mist_particles.is_empty():
		return true
	if rainbow_fur_glove_aura_timer_frames > 0.0 or not rainbow_fur_glove_particles.is_empty():
		return true
	if _is_adversity_armor_effect_active():
		return true
	if (
		not shrapnel_armor_shards.is_empty()
		or not shrapnel_armor_dust_particles.is_empty()
		or shrapnel_armor_flash_timer_frames > 0.0
		or shrapnel_armor_boss_impact_timer_frames > 0.0
		or shrapnel_armor_boss_knockback_timer_frames > 0.0
		or shrapnel_armor_boss_stun_timer_frames > 0.0
	):
		return true
	if celestial_armor_state.is_wave_active():
		return true
	if hermes_shoes_state.is_visible(false):
		return true
	if (
		baal_boots_weather_state.has_round_activity()
		or baal_boots_effect_state.is_visible(
			baal_boots_weather_state.cinematic_active,
			baal_boots_weather_state.round_effect_active
		)
	):
		return true
	return false


func _poll_idle_poseidon_dash_trigger(owner: Object, registry: Object) -> void:
	if not is_equipped(ITEM_POSEIDON_TRIDENT):
		return
	_update_poseidon_dash_trigger(owner, registry)
	if _has_transient_runtime_update_work():
		_sync_owner(owner, registry)


func try_apply_ragnarok_player_hit(
	ball_vel: Vector2,
	special_gauge: float,
	_context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if not is_equipped(ITEM_RAGNAROK_HAMMER):
		return {}
	if ragnarok_stun_ball_active or ragnarok_stun_attempted_this_rally:
		return {}
	ragnarok_stun_attempted_this_rally = true

	var gauge_cost: float = get_ragnarok_gauge_cost()
	if special_gauge < gauge_cost:
		return {"special_gauge": special_gauge}
	var trigger_chance: float = get_ragnarok_trigger_chance() / 100.0
	if randf() >= trigger_chance:
		return {"special_gauge": special_gauge}

	var next_ball_vel: Vector2 = ball_vel
	var original_speed: float = max(0.0, next_ball_vel.length())
	if original_speed > 0.01:
		next_ball_vel *= 1.0 + get_ragnarok_speed_boost() / 100.0
	ragnarok_stun_ball_active = true
	ragnarok_original_speed = original_speed
	ragnarok_first_shot_speed = max(original_speed, next_ball_vel.length())
	ragnarok_ball_started_msec = Time.get_ticks_msec()
	_play_ragnarok_shot_audio(_get_dict(deps).get("registry", null))
	_apply_ragnarok_feedback(deps, RAGNAROK_CHARGE_SHAKE_AMOUNT, RAGNAROK_CHARGE_SHAKE_INTENSITY)
	return {
		"ball_vel": next_ball_vel,
		"special_gauge": max(0.0, special_gauge - gauge_cost),
		"activated": true,
	}


func apply_ragnarok_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not is_equipped(ITEM_RAGNAROK_HAMMER):
		_clear_ragnarok_rally_state()
		return {}
	if not ragnarok_stun_ball_active:
		_clear_ragnarok_rally_state()
		return {}

	ragnarok_stun_ball_active = false
	ragnarok_stun_attempted_this_rally = false
	var next_ball_vel: Vector2 = _soften_ragnarok_counter_ball(ball_vel)
	if _is_stage2_speed_defense_context_immune(context, deps):
		return {
			"ball_vel": next_ball_vel,
			"applied": false,
			"boss_status_immune": true,
		}
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2(330.0, 25.0)))
	var boss_size: Vector2 = _get_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)))
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(100.0, 40.0)
	ragnarok_stun_target_size = boss_size
	var boss_center := Vector2(boss_pos.x + boss_size.x * 0.5, boss_pos.y + boss_size.y * 0.5)
	var field_center_x: float = float(context.get("width", 760.0)) * 0.5
	var direction: float = 1.0 if boss_center.x < field_center_x else -1.0
	var previous_boss_vel: float = float(context.get("boss_vel", 0.0))
	var drift_direction: float = sign(previous_boss_vel)
	if is_zero_approx(drift_direction):
		drift_direction = direction
	ragnarok_boss_electric_drift_vel = drift_direction * RAGNAROK_ELECTRIC_STUN_DRIFT_SPEED
	var knockback_power: float = _compute_ragnarok_knockback_power(max(ball_vel.length(), next_ball_vel.length()))
	ragnarok_boss_knockback_vel = direction * knockback_power * RAGNAROK_BOSS_KNOCKBACK_MULTIPLIER
	ragnarok_boss_knockback_timer_frames = RAGNAROK_BOSS_KNOCKBACK_FRAMES
	ragnarok_boss_stun_timer_frames = max(ragnarok_boss_stun_timer_frames, get_ragnarok_stun_duration() * 60.0)
	ragnarok_impact_center = boss_center
	ragnarok_impact_started_msec = Time.get_ticks_msec()
	_build_ragnarok_sparks()
	_play_ragnarok_boom_audio(_get_dict(deps).get("registry", null))
	if ragnarok_boss_stun_timer_frames > 0.0:
		_play_ragnarok_shock_audio(_get_dict(deps).get("registry", null))
	_apply_ragnarok_feedback(deps, RAGNAROK_IMPACT_SHAKE_AMOUNT, RAGNAROK_IMPACT_SHAKE_INTENSITY)
	return {
		"ball_vel": next_ball_vel,
		"applied": true,
	}


func apply_poseidon_wave_to_ball(scene: Dictionary, fps_scale: float, _context: Dictionary, deps: Dictionary) -> Dictionary:
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO))
	if poseidon_capture_active:
		return _update_poseidon_captured_ball(ball_pos, fps_scale, scene, deps)
	if poseidon_water_trail_active:
		_add_poseidon_water_trail(ball_pos)
	if not is_equipped(ITEM_POSEIDON_TRIDENT):
		return {}
	if not poseidon_vortex_active:
		return {}
	if poseidon_vortex_timer_frames >= POSEIDON_VORTEX_HOLD_FRAMES:
		return {}
	if ball_vel.y <= 0.0:
		return {}
	if poseidon_vortex_affected or poseidon_vortex_reentry_cooldown_frames > 0.0:
		return {}

	var vortex_hit: Dictionary = _get_poseidon_vortex_hit(ball_pos)
	if vortex_hit.is_empty():
		return {}

	_start_poseidon_capture(ball_pos, ball_vel, vortex_hit)
	_apply_poseidon_feedback(deps, POSEIDON_FEEDBACK_SHAKE_AMOUNT * 0.55, POSEIDON_FEEDBACK_SHAKE_INTENSITY * 0.70)
	return _update_poseidon_captured_ball(ball_pos, fps_scale, scene, deps)


func apply_poseidon_boss_hit(ball_vel: Vector2) -> Dictionary:
	if not poseidon_vortex_affected:
		return {}
	poseidon_vortex_affected = false
	poseidon_capture_active = false
	poseidon_water_trail_active = false
	poseidon_water_trail.clear()
	poseidon_vortex_reentry_cooldown_frames = 0.0
	return {
		"ball_vel": ball_vel * 0.5,
		"poseidon_trident_cleared": true,
	}


func apply_baal_boots_player_hit(ball_pos: Vector2, ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	var round_weather_type: String = baal_boots_weather_state.round_weather_type
	if not baal_boots_weather_state.round_effect_active or round_weather_type == "":
		return {}
	match round_weather_type:
		"fire", "ice":
			baal_boots_combat_state.mark_ball(round_weather_type, BAAL_BALL_MARK_FRAMES)
			_spawn_baal_aura_particles(ball_pos, round_weather_type, 8)
			_play_baal_boots_pulse_audio(_get_dict(deps).get("registry", null))
			return {
				"activated": true,
				"ball_vel": ball_vel,
				"baal_boots_ball_mark_type": baal_boots_combat_state.ball_mark_type,
			}
		"rain", "hail":
			_spawn_baal_projectiles(ball_pos, round_weather_type, context)
			_play_baal_boots_pulse_audio(_get_dict(deps).get("registry", null))
			return {
				"activated": true,
				"ball_vel": ball_vel,
			}
	return {}


func apply_baal_boots_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	if baal_boots_combat_state.ball_mark_timer_frames <= 0.0 or baal_boots_combat_state.ball_mark_type == "":
		return {}
	var mark_type: String = baal_boots_combat_state.consume_ball_mark()
	var boss_center: Vector2 = _resolve_boss_center_from_context(context)
	var result := {
		"applied": true,
		"ball_vel": ball_vel,
	}
	match mark_type:
		"fire":
			var direction: float = 1.0 if boss_center.x < FIELD_WIDTH * 0.5 else -1.0
			result["boss_vel"] = baal_boots_combat_state.apply_knockback(direction, BAAL_KNOCKBACK_POWER, BAAL_KNOCKBACK_FRAMES)
			result["ball_vel"] = ball_vel * 0.94
		"ice":
			baal_boots_combat_state.apply_slow(BAAL_RAIN_SLOW_FRAMES)
			result["boss_slow"] = true
	_spawn_baal_aura_particles(boss_center, mark_type, 14)
	_apply_ragnarok_feedback(deps, 0.09, 3.4)
	_play_baal_boots_pulse_audio(_get_dict(deps).get("registry", null))
	return result


func get_ragnarok_trigger_chance() -> float:
	return clamp(_get_equipped_roll_value(ITEM_RAGNAROK_HAMMER, "trigger_chance"), 0.0, 100.0)


func get_ragnarok_stun_duration() -> float:
	return clamp(_get_equipped_roll_value(ITEM_RAGNAROK_HAMMER, "stun_duration"), 0.8, 1.2)


func get_ragnarok_speed_boost() -> float:
	return clamp(_get_equipped_roll_value(ITEM_RAGNAROK_HAMMER, "speed_boost"), 0.0, 100.0)


func get_ragnarok_gauge_cost() -> float:
	return clamp(_get_equipped_roll_value(ITEM_RAGNAROK_HAMMER, "gauge_cost"), 0.0, 100.0)


func get_poseidon_cooldown() -> float:
	return clamp(_get_equipped_roll_value(ITEM_POSEIDON_TRIDENT, "cooldown"), 0.1, 30.0)


func get_poseidon_gauge_cost() -> float:
	return clamp(_get_equipped_roll_value(ITEM_POSEIDON_TRIDENT, "gauge_cost"), 0.0, 100.0)


func get_poseidon_vortex_size() -> float:
	return clamp(_get_equipped_roll_value(ITEM_POSEIDON_TRIDENT, "vortex_size"), 60.0, 500.0)


func is_poseidon_ball_motion_active() -> bool:
	if poseidon_capture_active or poseidon_water_trail_active:
		return true
	if not is_equipped(ITEM_POSEIDON_TRIDENT):
		return false
	return (
		poseidon_vortex_active
		and poseidon_vortex_timer_frames < POSEIDON_VORTEX_HOLD_FRAMES
		and not poseidon_vortex_affected
		and poseidon_vortex_reentry_cooldown_frames <= 0.0
	)


func get_poseidon_context() -> Dictionary:
	return context_builder.get_poseidon_context(self, CONTEXT_CONSTANTS)


func get_boss_ai_context() -> Dictionary:
	return context_builder.get_boss_ai_context(self, CONTEXT_CONSTANTS)


func has_actor_draw_context() -> bool:
	return context_builder.has_actor_draw_context(self)


func get_actor_draw_context() -> Dictionary:
	return context_builder.get_actor_draw_context(self, CONTEXT_CONSTANTS)


func has_ball_draw_context() -> bool:
	return context_builder.has_ball_draw_context(self)


func get_ball_draw_context() -> Dictionary:
	return context_builder.get_ball_draw_context(self)


func has_visible_field_effects() -> bool:
	if _ragnarok_impact_elapsed() < RAGNAROK_IMPACT_EFFECT_DURATION:
		return true
	if ragnarok_boss_stun_timer_frames > 0.0 or not ragnarok_sparks.is_empty():
		return true
	if (
		poseidon_capture_active
		or poseidon_vortex_active
		or not poseidon_particles.is_empty()
		or not poseidon_water_trail.is_empty()
		or poseidon_explosion_active
	):
		return true
	if knee_pads_flash_timer_frames > 0.0 or not knee_pads_particles.is_empty():
		return true
	if (
		soul_burst_effect_timer_frames > 0.0
		or not soul_burst_particles.is_empty()
		or not soul_burst_shockwaves.is_empty()
		or not soul_burst_wind_trails.is_empty()
	):
		return true
	if foul_whistle_state.animation_active:
		return true
	if revival_state.is_effect_active():
		return true
	if sensor_auto_dash_effect_timer_frames > 0.0:
		return true
	if venom_mist_field_active or not venom_mist_particles.is_empty():
		return true
	if rainbow_fur_glove_aura_timer_frames > 0.0 or not rainbow_fur_glove_particles.is_empty():
		return true
	if _is_adversity_armor_effect_active() or _is_shrapnel_armor_effect_active():
		return true
	if celestial_armor_state.is_wave_active():
		return true
	if hermes_shoes_state.is_visible(is_hermes_shoes_active()):
		return true
	if baal_boots_effect_state.is_visible(
		baal_boots_weather_state.cinematic_active,
		baal_boots_weather_state.round_effect_active
	):
		return true
	return acquisition_cinematic != null and acquisition_cinematic.is_active()


func draw_field_effects(
	canvas: CanvasItem,
	_registry: Object,
	shake_offset: Vector2,
	perf_logger: Object = null
) -> void:
	field_effect_renderer.draw_field_effects(
		self,
		canvas,
		shake_offset,
		RAGNAROK_IMPACT_EFFECT_DURATION,
		RAGNAROK_ELECTRIC_STUN_INTENSITY,
		perf_logger
	)


func _draw_hermes_shoes_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_hermes_shoes_effect(
		canvas,
		shake_offset,
		hermes_shoes_state,
		is_hermes_shoes_active(),
		HERMES_SHOES_TRAIL_LIFE_FRAMES,
		HERMES_SHOES_MOVE_TRAIL_THRESHOLD
	)


func _draw_hermes_wing_polygon(
	canvas: CanvasItem,
	points: PackedVector2Array,
	fill_color: Color,
	outline_color: Color,
	outline_width: float
) -> void:
	field_effect_renderer.draw_hermes_wing_polygon(canvas, points, fill_color, outline_color, outline_width)


func _draw_baal_boots_effects(canvas: CanvasItem, shake_offset: Vector2) -> void:
	baal_boots_effect_renderer.draw(
		canvas,
		shake_offset,
		baal_boots_weather_state,
		baal_boots_effect_state,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		_get_baal_weather_color(baal_boots_weather_state.get_draw_weather_type())
	)


func _draw_celestial_armor_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_celestial_armor_effect(
		canvas,
		shake_offset,
		celestial_armor_state,
		CELESTIAL_ARMOR_WAVE_RADIUS_MAX,
		CELESTIAL_ARMOR_SHARD_COUNT,
		CELESTIAL_ARMOR_ARC_SEGMENTS
	)


func _draw_venom_mist_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_venom_mist_effect(
		canvas,
		shake_offset,
		venom_mist_center,
		venom_mist_duration_frames,
		venom_mist_timer_frames,
		venom_mist_particles,
		venom_mist_boss_in_field,
		VENOM_MIST_RADIUS,
		_get_venom_mist_alpha()
	)


func is_activation_effect_active() -> bool:
	return _activation_elapsed() < MEGINGJORD_ACTIVATION_DURATION


func draw_activation_effect(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null or not is_activation_effect_active():
		return
	activation_effect_renderer.draw_activation_effect(
		canvas,
		view_size,
		_activation_elapsed(),
		activation_particles,
		activation_bolts,
		MEGINGJORD_ACTIVATION_DURATION
	)


func get_snapshot() -> Dictionary:
	return snapshot_builder.build_snapshot(self, SNAPSHOT_CONSTANTS)


func _grant_pandora_legacy_selected_item(selected_item: Dictionary, owner: Object, registry: Object = null) -> bool:
	return pandora_legacy_grant_router.grant_selected_item(selected_item, self, owner, registry, catalog)


func _clear_pandora_legacy_selection(clear_pending: bool = true) -> void:
	pandora_legacy_selection_state.clear_selection(clear_pending)


func _clear_pandora_legacy_runtime() -> void:
	pandora_legacy_selection_state.clear_runtime()
	pandora_legacy_icon_texture_cache.clear()


func _get_pandora_card_rect(index: int, view_size: Vector2) -> Rect2:
	return pandora_legacy_selection_renderer.get_card_rect(index, view_size, PANDORA_SELECTION_CARD_COUNT)


func _get_pandora_card_index_at(position: Vector2, view_size: Vector2) -> int:
	return pandora_legacy_selection_renderer.get_card_index_at(position, view_size, PANDORA_SELECTION_CARD_COUNT)


func _draw_pandora_choice_card(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	item_data: Dictionary,
	selected: bool,
	alpha: float,
	_registry: Object = null
) -> void:
	pandora_legacy_selection_renderer.draw_choice_card_body(
		canvas,
		font,
		rect,
		_get_pandora_choice_source_label(item_data),
		_get_pandora_choice_source_color(item_data),
		_get_pandora_choice_icon_texture(item_data),
		_get_pandora_choice_title(item_data),
		selected,
		alpha
	)
	if selected:
		_draw_pandora_centered_text(canvas, font, "선택", rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 18.0), 12, Color(1.0, 0.86, 0.38, alpha), rect.size.x - 16.0)


func _draw_pandora_badge(canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, alpha: float) -> void:
	pandora_legacy_selection_renderer.draw_badge(canvas, font, pos, text, color, alpha)


func _draw_pandora_centered_text(
	canvas: CanvasItem,
	font: Font,
	text: String,
	center: Vector2,
	font_size: int,
	color: Color,
	width: float = -1.0
) -> void:
	pandora_legacy_selection_renderer.draw_centered_text(canvas, font, text, center, font_size, color, width)


func _get_pandora_choice_source_label(item_data: Dictionary) -> String:
	return pandora_legacy_selection_renderer.get_choice_source_label(item_data)


func _get_pandora_choice_source_color(item_data: Dictionary) -> Color:
	return pandora_legacy_selection_renderer.get_choice_source_color(item_data)


func _get_pandora_choice_title(item_data: Dictionary) -> String:
	return pandora_legacy_selection_renderer.get_choice_title(item_data, PANDORA_ACTIVE_ITEM_KOREAN_NAMES)


func _get_pandora_choice_icon_texture(item_data: Dictionary) -> Texture2D:
	return pandora_legacy_selection_renderer.get_choice_icon_texture(item_data, pandora_legacy_icon_texture_cache)


func _queue_owner_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _start_activation_effect(owner: Object, registry: Object) -> void:
	activation_started_msec = Time.get_ticks_msec()
	_build_activation_particles()
	_build_activation_bolts()
	_play_activation_audio(registry)
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _build_activation_particles() -> void:
	activation_particles = activation_effect_renderer.build_activation_particles(MEGINGJORD_PARTICLE_COUNT)


func _build_activation_bolts() -> void:
	activation_bolts = activation_effect_renderer.build_activation_bolts(MEGINGJORD_BOLT_COUNT)


func _make_bolt_points(start: Vector2, end: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	return activation_effect_renderer.make_bolt_points(start, end, segments, jitter)


func _draw_activation_rings(canvas: CanvasItem, center: Vector2, t: float) -> void:
	activation_effect_renderer.draw_activation_rings(canvas, center, t)


func _draw_activation_bolts(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	activation_effect_renderer.draw_activation_bolts(canvas, center, elapsed, activation_bolts)


func _draw_activation_particles(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	activation_effect_renderer.draw_activation_particles(canvas, center, elapsed, activation_particles)


func _draw_activation_emblem(canvas: CanvasItem, center: Vector2, elapsed: float, t: float) -> void:
	activation_effect_renderer.draw_activation_emblem(canvas, center, elapsed, t)


func _draw_activation_text(canvas: CanvasItem, center: Vector2, t: float) -> void:
	activation_effect_renderer.draw_activation_text(canvas, center, t)


func _draw_foul_whistle_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	support_effect_renderer.draw_foul_whistle_effect(
		canvas,
		shake_offset,
		foul_whistle_state,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		FOUL_WHISTLE_TOTAL_FRAMES,
		FOUL_WHISTLE_REFEREE_FRAME_COUNT,
		FOUL_WHISTLE_REFEREE_FRAME_FRAMES
	)


func _draw_foul_whistle_referee(canvas: CanvasItem, center: Vector2, frame: int, alpha: float) -> void:
	support_effect_renderer.draw_foul_whistle_referee(canvas, center, frame, alpha)


func _draw_foul_whistle_text(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	support_effect_renderer.draw_foul_whistle_text(canvas, center, alpha, foul_whistle_state.animation_frame)


func _draw_revival_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	support_effect_renderer.draw_revival_effect(
		canvas,
		shake_offset,
		revival_state,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		REVIVAL_EFFECT_FRAMES
	)


func _draw_revival_text(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	support_effect_renderer.draw_revival_text(
		canvas,
		center,
		alpha,
		revival_state.effect_timer_frames,
		REVIVAL_EFFECT_FRAMES
	)


func _draw_sensor_auto_dash_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	support_effect_renderer.draw_sensor_auto_dash_effect(
		canvas,
		shake_offset,
		sensor_auto_dash_effect_timer_frames,
		sensor_auto_dash_center,
		sensor_last_dash_direction,
		SENSOR_AUTO_DASH_EFFECT_FRAMES
	)


func _clear_ragnarok_runtime(registry: Object) -> void:
	ragnarok_stun_ball_active = false
	ragnarok_stun_attempted_this_rally = false
	ragnarok_original_speed = 0.0
	ragnarok_first_shot_speed = 0.0
	ragnarok_ball_started_msec = -1000000
	ragnarok_boss_stun_timer_frames = 0.0
	ragnarok_boss_knockback_timer_frames = 0.0
	ragnarok_boss_knockback_vel = 0.0
	ragnarok_boss_electric_drift_vel = 0.0
	ragnarok_impact_started_msec = -1000000
	ragnarok_impact_center = Vector2.ZERO
	ragnarok_stun_target_size = Vector2(100.0, 40.0)
	ragnarok_sparks.clear()
	_stop_ragnarok_shock_audio(registry)


func _clear_ragnarok_boss_disable_state(registry: Object = null) -> void:
	ragnarok_boss_stun_timer_frames = 0.0
	ragnarok_boss_knockback_timer_frames = 0.0
	ragnarok_boss_knockback_vel = 0.0
	ragnarok_boss_electric_drift_vel = 0.0
	_stop_ragnarok_shock_audio(registry)


func _clear_poseidon_runtime(_registry: Object) -> void:
	poseidon_effect_cooldown_frames = 0.0
	poseidon_vortex_active = false
	poseidon_vortex_timer_frames = 0.0
	poseidon_vortex_left_pos = Vector2.ZERO
	poseidon_vortex_right_pos = Vector2.ZERO
	poseidon_vortex_left_height = 0.0
	poseidon_vortex_right_height = 0.0
	poseidon_vortex_spin_speed = 0.0
	poseidon_vortex_reentry_cooldown_frames = 0.0
	poseidon_vortex_affected = false
	poseidon_dash_was_active = false
	poseidon_dash_was_recovering = false
	poseidon_last_dash_direction = 0.0
	poseidon_particles.clear()
	poseidon_water_trail.clear()
	poseidon_water_trail_active = false
	poseidon_explosion_active = false
	poseidon_explosion_timer = 0.0
	poseidon_explosion_particles.clear()
	poseidon_capture_active = false
	poseidon_capture_timer_frames = 0.0
	poseidon_capture_duration_frames = 0.0
	poseidon_capture_base_pos = Vector2.ZERO
	poseidon_capture_start_angle = 0.0
	poseidon_capture_radius = 0.0
	poseidon_capture_turns = 0.0
	poseidon_capture_spin_sign = 1.0
	poseidon_capture_original_speed = 0.0
	poseidon_capture_last_pos = Vector2.ZERO


func _clear_knee_pads_runtime() -> void:
	knee_pads_half_dash_consumed = false
	knee_pads_flash_timer_frames = 0.0
	knee_pads_flash_center = Vector2.ZERO
	knee_pads_particles.clear()


func _clear_soul_burst_runtime() -> void:
	soul_burst_effect_timer_frames = 0.0
	soul_burst_dash_active = false
	soul_burst_center = Vector2.ZERO
	soul_burst_direction = 0.0
	soul_burst_particles.clear()
	soul_burst_shockwaves.clear()
	soul_burst_wind_trails.clear()


func _clear_foul_whistle_runtime() -> void:
	foul_whistle_state.clear()


func _clear_revival_runtime(clear_used: bool = false) -> void:
	revival_state.clear_runtime(clear_used)


func _clear_sensor_runtime(clear_cooldown: bool = true) -> void:
	sensor_enabled = true
	if clear_cooldown:
		sensor_cooldown_timer_frames = 0.0
	sensor_last_dash_direction = 0.0
	sensor_auto_dash_effect_timer_frames = 0.0
	sensor_auto_dash_center = Vector2.ZERO


func _clear_sensor_round_state() -> void:
	sensor_last_dash_direction = 0.0
	sensor_auto_dash_effect_timer_frames = 0.0
	sensor_auto_dash_center = Vector2.ZERO


func _clear_smartphone_runtime() -> void:
	smartphone_cooldown_frames = 0.0
	smartphone_last_auto_item = ""


func _clear_venom_mist_runtime() -> void:
	venom_mist_ball_poisoned = false
	venom_mist_field_active = false
	venom_mist_timer_frames = 0.0
	venom_mist_duration_frames = 0.0
	venom_mist_center = Vector2.ZERO
	venom_mist_particles.clear()
	venom_mist_gauge_drain_accumulator = 0.0
	venom_mist_boss_in_field = false


func _clear_venom_mist_round_state() -> void:
	_clear_venom_mist_runtime()


func _clear_rainbow_fur_glove_runtime() -> void:
	rainbow_fur_glove_aura_timer_frames = 0.0
	rainbow_fur_glove_aura_life_frames = RAINBOW_FUR_GLOVE_AURA_FRAMES
	rainbow_fur_glove_aura_center = Vector2.ZERO
	rainbow_fur_glove_aura_phase = 0.0
	rainbow_fur_glove_particles.clear()
	rainbow_fur_glove_last_reduction_pct = 0.0


func _clear_rainbow_fur_glove_round_state() -> void:
	rainbow_fur_glove_aura_timer_frames = 0.0
	rainbow_fur_glove_aura_life_frames = RAINBOW_FUR_GLOVE_AURA_FRAMES
	rainbow_fur_glove_aura_center = Vector2.ZERO
	rainbow_fur_glove_particles.clear()


func _clear_adversity_armor_runtime() -> void:
	adversity_armor_pending_invincible = false
	adversity_armor_serve_speed_boost_pending = false
	adversity_armor_last_trigger_roll_pct = -1.0
	adversity_armor_last_triggered = false
	_clear_adversity_armor_active_state()


func _clear_adversity_armor_round_state() -> void:
	_clear_adversity_armor_active_state()


func _clear_adversity_armor_active_state() -> void:
	adversity_armor_invincible_timer_frames = 0.0
	adversity_armor_invincible_total_frames = 0.0
	adversity_armor_flash_timer_frames = 0.0
	adversity_armor_phase = 0.0
	adversity_armor_last_reflect_center = Vector2.ZERO
	adversity_armor_aura_particles.clear()
	adversity_armor_barrier_particles.clear()

func _clear_shrapnel_armor_runtime() -> void:
	shrapnel_armor_shards.clear()
	shrapnel_armor_dust_particles.clear()
	shrapnel_armor_flash_timer_frames = 0.0
	shrapnel_armor_flash_center = Vector2.ZERO
	shrapnel_armor_boss_impact_timer_frames = 0.0
	shrapnel_armor_boss_impact_center = Vector2.ZERO
	shrapnel_armor_boss_knockback_timer_frames = 0.0
	shrapnel_armor_boss_knockback_vel = 0.0
	shrapnel_armor_boss_stun_timer_frames = 0.0
	shrapnel_armor_last_proc_shard_count = 0
	shrapnel_armor_last_gauge_cost = 0.0


func _clear_shrapnel_armor_round_state() -> void:
	shrapnel_armor_shards.clear()
	shrapnel_armor_dust_particles.clear()
	shrapnel_armor_flash_timer_frames = 0.0
	shrapnel_armor_flash_center = Vector2.ZERO
	shrapnel_armor_boss_impact_timer_frames = 0.0
	shrapnel_armor_boss_impact_center = Vector2.ZERO
	shrapnel_armor_boss_knockback_timer_frames = 0.0
	shrapnel_armor_boss_knockback_vel = 0.0
	shrapnel_armor_boss_stun_timer_frames = 0.0


func _clear_celestial_armor_runtime() -> void:
	celestial_armor_state.clear_runtime()


func _clear_celestial_armor_round_state() -> void:
	celestial_armor_state.clear_round_state()


func _clear_hermes_shoes_runtime() -> void:
	hermes_shoes_state.clear_runtime(Vector2(PLAYER_BASE_PADDLE_WIDTH, PLAYER_BASE_PADDLE_HEIGHT))


func _clear_hermes_shoes_round_state() -> void:
	hermes_shoes_state.clear_round_state(Vector2(PLAYER_BASE_PADDLE_WIDTH, PLAYER_BASE_PADDLE_HEIGHT))


func _clear_baal_boots_runtime(registry: Object = null) -> void:
	_clear_baal_boots_round_state(registry)


func _clear_baal_boots_round_state(registry: Object = null) -> void:
	var had_sand_round: bool = baal_boots_weather_state.clear_round_state()
	baal_boots_effect_state.clear()
	baal_boots_combat_state.clear()
	if had_sand_round:
		var weather: Object = _get_instance(registry, "weather_event_state")
		if weather != null and weather.has_method("dissolve_sand_terrain"):
			weather.dissolve_sand_terrain()


func _clear_ragnarok_rally_state() -> void:
	ragnarok_stun_ball_active = false
	ragnarok_stun_attempted_this_rally = false
	ragnarok_original_speed = 0.0
	ragnarok_first_shot_speed = 0.0
	ragnarok_ball_started_msec = -1000000


func _start_poseidon_capture(ball_pos: Vector2, ball_vel: Vector2, vortex_hit: Dictionary) -> void:
	poseidon_capture_active = true
	poseidon_capture_timer_frames = 0.0
	poseidon_capture_duration_frames = POSEIDON_CAPTURE_DURATION_FRAMES
	poseidon_capture_base_pos = _get_vector2(vortex_hit.get("pos", ball_pos))
	poseidon_capture_start_angle = atan2(ball_pos.y - poseidon_capture_base_pos.y, ball_pos.x - poseidon_capture_base_pos.x)
	poseidon_capture_radius = clamp(
		(ball_pos - poseidon_capture_base_pos).length(),
		POSEIDON_CAPTURE_MIN_RADIUS,
		max(POSEIDON_CAPTURE_MIN_RADIUS, get_poseidon_vortex_size() * 0.50)
	)
	poseidon_capture_turns = randf_range(POSEIDON_CAPTURE_MIN_TURNS, POSEIDON_CAPTURE_MAX_TURNS)
	poseidon_capture_spin_sign = -1.0 if str(vortex_hit.get("side", "left")) == "left" else 1.0
	poseidon_capture_original_speed = max(ball_vel.length(), POSEIDON_REFLECT_MIN_SPEED)
	poseidon_capture_last_pos = ball_pos
	poseidon_water_trail_active = true
	_add_poseidon_water_trail(ball_pos)


func _update_poseidon_captured_ball(ball_pos: Vector2, fps_scale: float, scene: Dictionary, deps: Dictionary) -> Dictionary:
	if not poseidon_capture_active:
		return {}
	poseidon_capture_timer_frames = min(
		poseidon_capture_duration_frames,
		poseidon_capture_timer_frames + max(0.0, fps_scale)
	)
	var progress: float = clamp(poseidon_capture_timer_frames / max(1.0, poseidon_capture_duration_frames), 0.0, 1.0)
	var next_pos: Vector2 = _get_poseidon_capture_position(progress)
	var previous_pos: Vector2 = poseidon_capture_last_pos if poseidon_capture_last_pos != Vector2.ZERO else ball_pos
	var capture_vel: Vector2 = (next_pos - previous_pos) / max(0.001, fps_scale)
	poseidon_capture_last_pos = next_pos
	_add_poseidon_water_trail(next_pos)

	if progress >= 1.0:
		var release_vel: Vector2 = _build_poseidon_release_velocity()
		poseidon_capture_active = false
		poseidon_vortex_affected = true
		poseidon_vortex_reentry_cooldown_frames = POSEIDON_REENTRY_COOLDOWN_FRAMES
		_apply_poseidon_feedback(deps, POSEIDON_FEEDBACK_SHAKE_AMOUNT, POSEIDON_FEEDBACK_SHAKE_INTENSITY)
		return {
			"ball_pos": next_pos,
			"ball_vel": release_vel,
			"skip_ball_motion_step": false,
			"ball_impact_boost": max(POSEIDON_CAPTURE_RELEASE_BOOST, float(scene.get("ball_impact_boost", 1.0))),
			"poseidon_trident_released": true,
			"poseidon_trident_capture_progress": progress,
		}

	return {
		"ball_pos": next_pos,
		"ball_vel": capture_vel,
		"skip_ball_motion_step": true,
		"ball_impact_boost": 1.0,
		"poseidon_trident_captured": true,
		"poseidon_trident_capture_progress": progress,
	}


func _get_poseidon_capture_position(progress: float) -> Vector2:
	var t: float = clamp(progress, 0.0, 1.0)
	var eased_up: float = 1.0 - pow(1.0 - t, 1.35)
	var rise_height: float = min(POSEIDON_VORTEX_MAX_HEIGHT * 0.72, max(170.0, get_poseidon_vortex_size() * 1.18))
	var radius: float = lerp(poseidon_capture_radius, max(22.0, poseidon_capture_radius * 0.45), t)
	var angle: float = poseidon_capture_start_angle + poseidon_capture_spin_sign * TAU * poseidon_capture_turns * t
	var center: Vector2 = poseidon_capture_base_pos + Vector2(0.0, -rise_height * eased_up)
	return center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.62)


func _build_poseidon_release_velocity() -> Vector2:
	var speed: float = clamp(
		poseidon_capture_original_speed * randf_range(1.55, 1.95),
		POSEIDON_REFLECT_MIN_SPEED,
		POSEIDON_REFLECT_MAX_SPEED
	)
	var angle: float = -PI * 0.5 + randf_range(-POSEIDON_CAPTURE_RELEASE_SPREAD, POSEIDON_CAPTURE_RELEASE_SPREAD)
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	if velocity.y > -POSEIDON_REFLECT_MIN_UPWARD_SPEED:
		velocity.y = -POSEIDON_REFLECT_MIN_UPWARD_SPEED
	velocity.x = clamp(velocity.x, -POSEIDON_REFLECT_MAX_X_SPEED, POSEIDON_REFLECT_MAX_X_SPEED)
	return velocity


func _update_smartphone_runtime(owner: Object, registry: Object, fps_scale: float) -> void:
	if smartphone_cooldown_frames > 0.0:
		smartphone_cooldown_frames = max(0.0, smartphone_cooldown_frames - fps_scale)
	if not is_smartphone_active():
		return

	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime == null:
		return

	if _should_smartphone_auto_defend(owner, registry, active_item_runtime, fps_scale):
		var defense_item: String = _call_smartphone_auto_use(active_item_runtime, "try_smartphone_auto_defense", owner, registry)
		if defense_item != "":
			smartphone_last_auto_item = defense_item
			smartphone_cooldown_frames = SMARTPHONE_DEFENSE_COOLDOWN_FRAMES
			return

	if smartphone_cooldown_frames > 0.0:
		return

	var recovery_item: String = _call_smartphone_auto_use(
		active_item_runtime,
		"try_smartphone_auto_recovery",
		owner,
		registry,
		SMARTPHONE_RECOVERY_GAUGE_THRESHOLD
	)
	if recovery_item != "":
		smartphone_last_auto_item = recovery_item
		smartphone_cooldown_frames = SMARTPHONE_RECOVERY_COOLDOWN_FRAMES


func _should_smartphone_auto_defend(owner: Object, registry: Object, active_item_runtime: Object, fps_scale: float) -> bool:
	if owner == null:
		return false
	if not bool(_safe_owner_get(owner, "ball_active", true)):
		return false
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return false
	if active_item_runtime != null:
		if active_item_runtime.has_method("is_stopwatch_active") and bool(active_item_runtime.is_stopwatch_active()):
			return false
		if active_item_runtime.has_method("is_holy_barrier_active") and bool(active_item_runtime.is_holy_barrier_active()):
			return false

	var ball_vel: Vector2 = _get_vector2(_safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	if ball_vel.y <= 0.0:
		return false

	var active_item_slots: Array = _get_array(_safe_owner_get(owner, "active_item_slots", []))
	if not _has_active_slot_item(active_item_slots, "stopwatch") and not _has_active_slot_item(active_item_slots, "holy_barrier"):
		return false

	var ball_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "ball_pos", Vector2.ZERO))
	var ball_size: float = 28.6
	var ball_bottom: float = ball_pos.y + ball_size * 0.5
	var distance_to_floor: float = FIELD_HEIGHT - ball_bottom
	var effective_step: float = max(0.0, ball_vel.y * max(0.0, fps_scale))
	var trigger_margin: float = max(SMARTPHONE_PRE_ACTIVATE_MARGIN, effective_step + 8.0)
	if distance_to_floor < 0.0 or distance_to_floor > trigger_margin:
		return false
	if ball_pos.y > FIELD_HEIGHT - SMARTPHONE_MIN_PLAYABLE_MARGIN:
		return false
	if _is_smartphone_ball_safe_for_player(owner, ball_pos, ball_size):
		return false
	return true


func _is_smartphone_ball_safe_for_player(owner: Object, ball_pos: Vector2, ball_size: float) -> bool:
	var player_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2(302.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)))
	var paddle_width: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var paddle_height: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_center := player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)
	if abs(ball_pos.x - player_center.x) <= SMARTPHONE_MIN_SAFE_DISTANCE and abs(ball_pos.y - player_center.y) <= SMARTPHONE_MIN_SAFE_DISTANCE:
		return true

	var ball_rect := Rect2(ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))
	var player_rect := Rect2(player_pos, Vector2(paddle_width, paddle_height)).grow(6.0)
	return player_rect.intersects(ball_rect)


func _has_active_slot_item(active_item_slots: Array, item_name: String) -> bool:
	for item_value in active_item_slots:
		var item_data: Dictionary = _get_dict(item_value)
		if str(item_data.get("name", "")) == item_name or str(item_data.get("effect", "")) == item_name:
			return true
	return false


func _call_smartphone_auto_use(
	active_item_runtime: Object,
	method_name: String,
	owner: Object,
	registry: Object,
	extra_arg: Variant = null
) -> String:
	if active_item_runtime == null or not active_item_runtime.has_method(method_name):
		return ""
	var result: Variant
	if extra_arg == null:
		result = active_item_runtime.call(method_name, owner, registry)
	else:
		result = active_item_runtime.call(method_name, owner, registry, extra_arg)
	return str(result)


func _update_venom_mist_runtime(owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_venom_mist_gauntlet_equipped():
		_clear_venom_mist_runtime()
		return
	if venom_mist_field_active:
		venom_mist_timer_frames = max(0.0, venom_mist_timer_frames - fps_scale)
		if venom_mist_timer_frames <= 0.0:
			venom_mist_field_active = false
			venom_mist_boss_in_field = false
			venom_mist_gauge_drain_accumulator = 0.0
	else:
		venom_mist_boss_in_field = false
	_update_venom_mist_particles(fps_scale)
	if not venom_mist_field_active:
		return
	var boss_center: Vector2 = _read_owner_boss_center(owner)
	venom_mist_boss_in_field = boss_center.distance_to(venom_mist_center) <= VENOM_MIST_RADIUS
	if venom_mist_boss_in_field:
		_update_venom_mist_boss_gauge_drain(owner, registry, fps_scale)


func _start_venom_mist_field(center: Vector2, registry: Object = null) -> void:
	venom_mist_field_active = true
	venom_mist_center = center
	venom_mist_duration_frames = max(1.0, get_venom_mist_duration_sec() * 60.0)
	venom_mist_timer_frames = venom_mist_duration_frames
	venom_mist_gauge_drain_accumulator = 0.0
	venom_mist_boss_in_field = false
	_build_venom_mist_particles()
	_play_venom_mist_spawn_audio(registry)


func _update_venom_mist_boss_gauge_drain(owner: Object, registry: Object, fps_scale: float) -> void:
	var current_stage: int = int(_safe_owner_get(owner, "current_stage", 1))
	venom_mist_gauge_drain_accumulator += VENOM_MIST_GAUGE_DRAIN_PER_FRAME * max(0.0, fps_scale)
	if current_stage == 5:
		if venom_mist_gauge_drain_accumulator < VENOM_MIST_HONGRYUN_DRAIN_THRESHOLD:
			return
		venom_mist_gauge_drain_accumulator -= VENOM_MIST_HONGRYUN_DRAIN_THRESHOLD
		_drain_boss_special_gauge(registry, 1.0, current_stage)
		return
	var drain_amount: int = int(floor(venom_mist_gauge_drain_accumulator))
	if drain_amount <= 0:
		return
	venom_mist_gauge_drain_accumulator -= float(drain_amount)
	_drain_boss_special_gauge(registry, float(drain_amount), current_stage)


func _drain_boss_special_gauge(registry: Object, amount: float, current_stage: int) -> bool:
	if amount <= 0.0:
		return false
	var state_keys: Array = []
	match current_stage:
		1:
			state_keys = ["stage1_dalji_whip_skill_state"]
		2:
			state_keys = ["stage2_boss_skill_state"]
		_:
			state_keys = ["stage1_dalji_whip_skill_state", "stage2_boss_skill_state"]
	for key in state_keys:
		var state: Object = _get_instance(registry, str(key))
		if state == null:
			continue
		if state.has_method("drain_boss_special_gauge"):
			state.drain_boss_special_gauge(amount)
			return true
		var current_value: Variant = state.get("boss_special_gauge")
		if current_value != null:
			state.set("boss_special_gauge", max(0.0, float(current_value) - amount))
			return true
	return false


func _read_owner_boss_center(owner: Object) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_pos", Vector2(330.0, 25.0)))
	var boss_width: float = max(1.0, float(_safe_owner_get(owner, "boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(_safe_owner_get(owner, "boss_hitbox_height", 40.0)))
	var boss_size_value: Variant = _safe_owner_get(owner, "boss_paddle_size", Vector2.ZERO)
	if boss_size_value is Vector2 and boss_size_value != Vector2.ZERO:
		var boss_size: Vector2 = boss_size_value
		boss_width = max(1.0, boss_size.x)
		boss_height = max(1.0, boss_size.y)
	return boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5)


func _build_venom_mist_particles() -> void:
	venom_mist_particles.clear()
	for _i in range(VENOM_MIST_PARTICLE_COUNT):
		venom_mist_particles.append(_create_venom_mist_particle(true))


func _create_venom_mist_particle(random_life: bool = false) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var dist: float = VENOM_MIST_RADIUS * sqrt(randf())
	var offset := Vector2(cos(angle), sin(angle)) * dist
	var drift_angle: float = angle + randf_range(-PI * 0.65, PI * 0.65)
	var velocity := Vector2(cos(drift_angle), sin(drift_angle)) * randf_range(0.12, 0.42)
	var life: float = randf_range(45.0, 95.0) if random_life else 95.0
	return {
		"offset": offset,
		"velocity": velocity,
		"size": randf_range(9.0, 24.0),
		"life": life,
		"max_life": life,
		"alpha": randf_range(0.12, 0.36),
		"layer": randi() % 3,
	}


func _update_venom_mist_particles(fps_scale: float) -> void:
	for i in range(venom_mist_particles.size() - 1, -1, -1):
		var particle: Dictionary = _get_dict(venom_mist_particles[i])
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			if venom_mist_field_active:
				venom_mist_particles[i] = _create_venom_mist_particle()
			else:
				venom_mist_particles.remove_at(i)
			continue
		var offset: Vector2 = _get_vector2(particle.get("offset", Vector2.ZERO))
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		offset += velocity * fps_scale
		if offset.length() > VENOM_MIST_RADIUS * 1.08:
			offset = offset.normalized() * VENOM_MIST_RADIUS * randf_range(0.45, 0.92)
		particle["offset"] = offset
		particle["life"] = life
		particle["size"] = max(2.0, float(particle.get("size", 8.0)) + sin((life + float(i)) * 0.08) * 0.04 * fps_scale)
		venom_mist_particles[i] = particle
	while venom_mist_field_active and venom_mist_particles.size() < VENOM_MIST_PARTICLE_COUNT:
		venom_mist_particles.append(_create_venom_mist_particle())
	while venom_mist_particles.size() > VENOM_MIST_PARTICLE_MAX:
		venom_mist_particles.pop_front()


func _get_venom_mist_alpha() -> float:
	if venom_mist_duration_frames <= 0.0:
		return 0.0
	var elapsed: float = max(0.0, venom_mist_duration_frames - venom_mist_timer_frames)
	var fade_in: float = clamp(elapsed / VENOM_MIST_FADE_IN_FRAMES, 0.0, 1.0)
	var fade_out: float = clamp(venom_mist_timer_frames / VENOM_MIST_FADE_OUT_FRAMES, 0.0, 1.0)
	return min(fade_in, fade_out)


func _apply_rainbow_fur_glove_skill_cooldown_reduction(
	reduction_fraction: float,
	current_msec: int,
	deps: Dictionary
) -> int:
	var total_changed := 0
	for skill_state in _collect_player_skill_states(deps):
		if skill_state == null or not skill_state.has_method("reduce_all_cooldowns_by_fraction"):
			continue
		total_changed += int(skill_state.reduce_all_cooldowns_by_fraction(reduction_fraction, current_msec))
	return total_changed


func _collect_player_skill_states(deps: Dictionary) -> Array:
	var result: Array = []
	_append_unique_object(result, _get_dict(deps).get("skill_state", null))
	for state_value in _get_array(_get_dict(deps).get("skill_states", [])):
		_append_unique_object(result, state_value)
	var registry: Object = _get_dict(deps).get("registry", null)
	for key in [
		"smasher_skill_state",
		"viper_skill_state",
		"soldier_skill_state",
		"commando_skill_state",
		"blacksmith_skill_state",
		"baltor_skill_state",
		"optimus_skill_state",
	]:
		_append_unique_object(result, _get_instance(registry, str(key)))
	return result


func _append_unique_object(items: Array, value: Variant) -> void:
	if value == null or not (value is Object):
		return
	var object_value: Object = value
	for existing in items:
		if existing == object_value:
			return
	items.append(object_value)


func _resolve_context_msec(context: Dictionary) -> int:
	for key in ["current_time_msec", "current_msec", "time_now_msec", "time_msec"]:
		if context.has(key):
			return max(0, int(context.get(key, 0)))
	return Time.get_ticks_msec()


func _resolve_rainbow_fur_glove_center(ball_pos: Vector2, context: Dictionary, deps: Dictionary) -> Vector2:
	var owner: Object = _get_dict(deps).get("owner", context.get("owner", null))
	var fallback_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", fallback_pos))
	var paddle_width: float = max(1.0, float(context.get(
		"player_paddle_width",
		context.get("paddle_width", _safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH))
	)))
	var paddle_height: float = max(1.0, float(context.get(
		"player_paddle_height",
		_safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)
	)))
	if player_pos != Vector2.ZERO:
		return player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)
	return ball_pos


func _start_rainbow_fur_glove_aura(center: Vector2) -> void:
	rainbow_fur_glove_aura_center = center
	rainbow_fur_glove_aura_life_frames = RAINBOW_FUR_GLOVE_AURA_FRAMES
	rainbow_fur_glove_aura_timer_frames = rainbow_fur_glove_aura_life_frames
	rainbow_fur_glove_aura_phase = randf_range(0.0, TAU)
	_build_rainbow_fur_glove_particles(center)


func _build_rainbow_fur_glove_particles(center: Vector2) -> void:
	rainbow_fur_glove_particles.clear()
	for _i in range(RAINBOW_FUR_GLOVE_PARTICLE_COUNT):
		rainbow_fur_glove_particles.append(_create_rainbow_fur_glove_particle(center, true))


func _create_rainbow_fur_glove_particle(center: Vector2, random_life: bool = false) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var dist: float = randf_range(12.0, 54.0)
	var life: float = randf_range(18.0, 36.0) if random_life else randf_range(24.0, 36.0)
	var color: Color = RAINBOW_FUR_GLOVE_COLORS[randi() % RAINBOW_FUR_GLOVE_COLORS.size()]
	return {
		"position": center + Vector2(cos(angle), sin(angle)) * dist,
		"velocity": Vector2(cos(angle), sin(angle)) * randf_range(1.2, 4.2),
		"life": life,
		"max_life": life,
		"size": randf_range(2.0, 4.8),
		"color": color,
		"phase": randf_range(0.0, TAU),
	}


func _update_rainbow_fur_glove_runtime(fps_scale: float) -> void:
	if not is_rainbow_fur_glove_equipped():
		if rainbow_fur_glove_aura_timer_frames > 0.0 or not rainbow_fur_glove_particles.is_empty():
			_clear_rainbow_fur_glove_runtime()
		return
	var step: float = max(0.0, fps_scale)
	if rainbow_fur_glove_aura_timer_frames > 0.0:
		rainbow_fur_glove_aura_timer_frames = max(0.0, rainbow_fur_glove_aura_timer_frames - step)
		rainbow_fur_glove_aura_phase = fmod(rainbow_fur_glove_aura_phase + 0.18 * step, TAU)
	for i in range(rainbow_fur_glove_particles.size() - 1, -1, -1):
		var particle: Dictionary = _get_dict(rainbow_fur_glove_particles[i])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			rainbow_fur_glove_particles.remove_at(i)
			continue
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		var position: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		velocity *= pow(0.965, step)
		position += velocity * step
		particle["life"] = life
		particle["velocity"] = velocity
		particle["position"] = position
		particle["phase"] = float(particle.get("phase", 0.0)) + 0.11 * step
		rainbow_fur_glove_particles[i] = particle
	while rainbow_fur_glove_aura_timer_frames > 0.0 and rainbow_fur_glove_particles.size() < RAINBOW_FUR_GLOVE_PARTICLE_COUNT:
		rainbow_fur_glove_particles.append(_create_rainbow_fur_glove_particle(rainbow_fur_glove_aura_center))
	while rainbow_fur_glove_particles.size() > RAINBOW_FUR_GLOVE_PARTICLE_MAX:
		rainbow_fur_glove_particles.pop_front()


func _draw_rainbow_fur_glove_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_rainbow_fur_glove_effect(
		canvas,
		shake_offset,
		rainbow_fur_glove_aura_center,
		rainbow_fur_glove_aura_life_frames,
		rainbow_fur_glove_aura_timer_frames,
		rainbow_fur_glove_aura_phase,
		rainbow_fur_glove_particles,
		RAINBOW_FUR_GLOVE_COLORS
	)


func _get_adversity_armor_barrier_y() -> float:
	return FIELD_HEIGHT - ADVERSITY_ARMOR_BARRIER_Y_OFFSET


func _get_adversity_armor_timer_ratio() -> float:
	if adversity_armor_invincible_total_frames <= 0.0:
		return 0.0
	return clamp(adversity_armor_invincible_timer_frames / adversity_armor_invincible_total_frames, 0.0, 1.0)


func _update_adversity_armor_runtime(owner: Object, _registry: Object, fps_scale: float) -> void:
	if not is_adversity_armor_equipped():
		if _is_adversity_armor_effect_active() or adversity_armor_pending_invincible or adversity_armor_serve_speed_boost_pending:
			_clear_adversity_armor_runtime()
		return
	var step: float = max(0.0, fps_scale)
	var was_invincible: bool = adversity_armor_invincible_timer_frames > 0.0
	if adversity_armor_invincible_timer_frames > 0.0:
		adversity_armor_invincible_timer_frames = max(0.0, adversity_armor_invincible_timer_frames - step)
		adversity_armor_phase += 0.09 * step
		_spawn_adversity_armor_idle_particles(owner)
	if was_invincible and adversity_armor_invincible_timer_frames <= 0.0:
		adversity_armor_invincible_total_frames = 0.0
	if adversity_armor_flash_timer_frames > 0.0:
		adversity_armor_flash_timer_frames = max(0.0, adversity_armor_flash_timer_frames - step)
	_update_adversity_armor_particles(step)


func _spawn_adversity_armor_idle_particles(owner: Object) -> void:
	var player_center: Vector2 = _resolve_adversity_armor_player_center(owner)
	while adversity_armor_aura_particles.size() < min(12, ADVERSITY_ARMOR_AURA_PARTICLE_MAX):
		adversity_armor_aura_particles.append({
			"position": player_center + Vector2(randf_range(-48.0, 48.0), randf_range(-30.0, 22.0)),
			"velocity": Vector2(randf_range(-0.24, 0.24), randf_range(-0.62, -0.18)),
			"life": randf_range(18.0, 38.0),
			"max_life": 38.0,
			"size": randf_range(1.4, 3.4),
		})
	while adversity_armor_barrier_particles.size() < min(18, ADVERSITY_ARMOR_BARRIER_PARTICLE_MAX):
		adversity_armor_barrier_particles.append({
			"position": Vector2(randf_range(26.0, FIELD_WIDTH - 26.0), _get_adversity_armor_barrier_y() + randf_range(-4.0, 4.0)),
			"velocity": Vector2(randf_range(-0.65, 0.65), randf_range(-0.26, 0.26)),
			"life": randf_range(20.0, 44.0),
			"max_life": 44.0,
			"size": randf_range(1.3, 3.2),
		})


func _spawn_adversity_armor_barrier_particles(center: Vector2, count: int, impact: bool) -> void:
	for _i in range(max(0, count)):
		var angle: float = randf_range(PI, TAU) if impact else randf_range(0.0, TAU)
		var speed: float = randf_range(2.0, 6.2) if impact else randf_range(0.7, 2.4)
		adversity_armor_barrier_particles.append({
			"position": center + Vector2(randf_range(-18.0, 18.0), randf_range(-5.0, 5.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(16.0, 34.0) if impact else randf_range(20.0, 42.0),
			"max_life": 34.0 if impact else 42.0,
			"size": randf_range(1.8, 4.8) if impact else randf_range(1.2, 3.0),
			"impact": impact,
		})
	while adversity_armor_barrier_particles.size() > ADVERSITY_ARMOR_BARRIER_PARTICLE_MAX:
		adversity_armor_barrier_particles.pop_front()


func _update_adversity_armor_particles(step: float) -> void:
	var aura_write_index := 0
	for read_index in range(adversity_armor_aura_particles.size()):
		var particle: Dictionary = _get_dict(adversity_armor_aura_particles[read_index])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			continue
		var position: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity.x *= pow(0.985, step)
		particle["position"] = position
		particle["velocity"] = velocity
		particle["life"] = life
		adversity_armor_aura_particles[aura_write_index] = particle
		aura_write_index += 1
	if aura_write_index < adversity_armor_aura_particles.size():
		adversity_armor_aura_particles.resize(aura_write_index)

	var barrier_write_index := 0
	for read_index in range(adversity_armor_barrier_particles.size()):
		var particle: Dictionary = _get_dict(adversity_armor_barrier_particles[read_index])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			continue
		var position: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity *= pow(0.965, step)
		particle["position"] = position
		particle["velocity"] = velocity
		particle["life"] = life
		barrier_write_index += 1
		adversity_armor_barrier_particles[barrier_write_index - 1] = particle
	if barrier_write_index < adversity_armor_barrier_particles.size():
		adversity_armor_barrier_particles.resize(barrier_write_index)


func _resolve_adversity_armor_player_center(owner: Object) -> Vector2:
	if owner == null:
		return Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
	var player_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)))
	var player_width: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var player_height: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	return player_pos + Vector2(player_width * 0.5, player_height * 0.5)


func _is_adversity_armor_effect_active() -> bool:
	return (
		adversity_armor_invincible_timer_frames > 0.0
		or adversity_armor_flash_timer_frames > 0.0
		or not adversity_armor_aura_particles.is_empty()
		or not adversity_armor_barrier_particles.is_empty()
	)


func _draw_adversity_armor_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_adversity_armor_effect(
		canvas,
		shake_offset,
		get_adversity_armor_context(),
		adversity_armor_aura_particles,
		adversity_armor_barrier_particles
	)

func _get_shrapnel_armor_current_gauge(context: Dictionary, deps: Dictionary) -> float:
	var owner: Object = _get_dict(deps).get("owner", context.get("owner", null))
	var fallback: float = float(context.get("special_gauge", 0.0))
	if owner != null:
		return max(0.0, float(_safe_owner_get(owner, "special_gauge", fallback)))
	return max(0.0, fallback)


func _consume_shrapnel_armor_gauge(gauge_cost: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var current_gauge: float = _get_shrapnel_armor_current_gauge(context, deps)
	if gauge_cost <= 0.0:
		context["special_gauge"] = current_gauge
		return {"ok": true, "special_gauge": current_gauge}
	if current_gauge + 0.001 < gauge_cost:
		return {"ok": false, "special_gauge": current_gauge}
	var next_gauge: float = max(0.0, current_gauge - gauge_cost)
	var owner: Object = _get_dict(deps).get("owner", context.get("owner", null))
	if owner != null:
		owner.set("special_gauge", next_gauge)
	context["special_gauge"] = next_gauge
	return {"ok": true, "special_gauge": next_gauge}


func _resolve_shrapnel_armor_spawn_center(ball_pos: Vector2, context: Dictionary, deps: Dictionary) -> Vector2:
	var owner: Object = _get_dict(deps).get("owner", context.get("owner", null))
	var fallback_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", fallback_pos))
	var paddle_width: float = max(1.0, float(context.get(
		"player_paddle_width",
		context.get("paddle_width", _safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH))
	)))
	if player_pos != Vector2.ZERO or context.has("player_pos"):
		return player_pos + Vector2(paddle_width * 0.5, 0.0)
	return ball_pos


func _start_shrapnel_armor_burst(center: Vector2, shard_count: int) -> void:
	var count: int = clampi(shard_count, 0, SHRAPNEL_ARMOR_MAX_SHARD_COUNT)
	if count <= 0:
		return
	var spread_deg := 60.0
	for i in range(count):
		var ratio: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var angle: float = deg_to_rad(-90.0 + spread_deg * (ratio - 0.5))
		var speed: float = randf_range(9.4, 14.0)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		shrapnel_armor_shards.append({
			"position": center + Vector2(randf_range(-10.0, 10.0), 0.0),
			"velocity": velocity,
			"life": SHRAPNEL_ARMOR_SHARD_LIFE_FRAMES,
			"max_life": SHRAPNEL_ARMOR_SHARD_LIFE_FRAMES,
			"size": randf_range(3.0, 6.0),
			"rotation": randf_range(0.0, TAU),
			"rot_speed": deg_to_rad(randf_range(-15.0, 15.0)),
			"color_shift": randf_range(-20.0, 20.0),
			"trail": [],
		})
	shrapnel_armor_flash_timer_frames = SHRAPNEL_ARMOR_FLASH_FRAMES
	shrapnel_armor_flash_center = center


func _update_shrapnel_armor_runtime(owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_shrapnel_armor_equipped():
		if _is_shrapnel_armor_effect_active():
			_clear_shrapnel_armor_runtime()
		return
	var step: float = max(0.0, fps_scale)
	if shrapnel_armor_flash_timer_frames > 0.0:
		shrapnel_armor_flash_timer_frames = max(0.0, shrapnel_armor_flash_timer_frames - step)
	if shrapnel_armor_boss_impact_timer_frames > 0.0:
		shrapnel_armor_boss_impact_timer_frames = max(0.0, shrapnel_armor_boss_impact_timer_frames - step)
	if shrapnel_armor_boss_stun_timer_frames > 0.0:
		shrapnel_armor_boss_stun_timer_frames = max(0.0, shrapnel_armor_boss_stun_timer_frames - step)
	if shrapnel_armor_boss_knockback_timer_frames > 0.0:
		shrapnel_armor_boss_knockback_timer_frames = max(0.0, shrapnel_armor_boss_knockback_timer_frames - step)
		shrapnel_armor_boss_knockback_vel *= pow(SHRAPNEL_ARMOR_BOSS_KNOCKBACK_DECAY, step)
		if shrapnel_armor_boss_knockback_timer_frames <= 0.0 or abs(shrapnel_armor_boss_knockback_vel) <= 0.3:
			shrapnel_armor_boss_knockback_timer_frames = 0.0
			shrapnel_armor_boss_knockback_vel = 0.0
	elif abs(shrapnel_armor_boss_knockback_vel) > 0.0:
		shrapnel_armor_boss_knockback_vel = 0.0

	var boss_rect: Rect2 = _get_shrapnel_armor_boss_rect(owner)
	var can_hit_boss := boss_rect.size != Vector2.ZERO and not _is_stage2_speed_defense_boss_immune(registry)
	var write_index := 0
	for read_index in range(shrapnel_armor_shards.size()):
		var shard: Dictionary = _get_dict(shrapnel_armor_shards[read_index])
		var position: Vector2 = _get_vector2(shard.get("position", Vector2.ZERO))
		var velocity: Vector2 = _get_vector2(shard.get("velocity", Vector2.ZERO))
		var trail: Array = _get_array(shard.get("trail", [])).duplicate()
		trail.append(position)
		while trail.size() > SHRAPNEL_ARMOR_SHARD_TRAIL_POINTS:
			trail.pop_front()
		position += velocity * step
		velocity.y += 0.08 * step
		var life: float = float(shard.get("life", 0.0)) - step
		var rotation: float = float(shard.get("rotation", 0.0)) + float(shard.get("rot_speed", 0.0)) * step
		if can_hit_boss and boss_rect.has_point(position):
			_spawn_shrapnel_armor_dust(position, 9, true)
			_apply_shrapnel_armor_boss_hit(position, velocity, boss_rect, registry)
			continue
		var expired := (
			life <= 0.0
			or position.x <= 0.0
			or position.x >= FIELD_WIDTH
			or position.y <= 0.0
			or position.y >= FIELD_HEIGHT
		)
		if expired:
			_spawn_shrapnel_armor_dust(position, 4, false)
			continue
		shard["position"] = position
		shard["velocity"] = velocity
		shard["life"] = life
		shard["rotation"] = rotation
		shard["trail"] = trail
		shrapnel_armor_shards[write_index] = shard
		write_index += 1
	if write_index < shrapnel_armor_shards.size():
		shrapnel_armor_shards.resize(write_index)
	_update_shrapnel_armor_dust(step)


func _update_shrapnel_armor_dust(step: float) -> void:
	var write_index := 0
	for read_index in range(shrapnel_armor_dust_particles.size()):
		var particle: Dictionary = _get_dict(shrapnel_armor_dust_particles[read_index])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			continue
		var position: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity.x *= pow(0.96, step)
		velocity.y -= 0.03 * step
		particle["position"] = position
		particle["velocity"] = velocity
		particle["life"] = life
		particle["size"] = max(0.4, float(particle.get("size", 2.0)) - 0.06 * step)
		shrapnel_armor_dust_particles[write_index] = particle
		write_index += 1
	if write_index < shrapnel_armor_dust_particles.size():
		shrapnel_armor_dust_particles.resize(write_index)
	while shrapnel_armor_dust_particles.size() > SHRAPNEL_ARMOR_DUST_MAX:
		shrapnel_armor_dust_particles.pop_front()


func _spawn_shrapnel_armor_dust(center: Vector2, count: int, impact: bool) -> void:
	for _i in range(max(0, count)):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(1.1, 4.2) if impact else randf_range(0.6, 2.4)
		shrapnel_armor_dust_particles.append({
			"position": center + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(12.0, 26.0) if impact else randf_range(8.0, 18.0),
			"max_life": 26.0 if impact else 18.0,
			"size": randf_range(1.4, 3.8) if impact else randf_range(0.8, 2.4),
			"color": Color(1.0, randf_range(0.55, 0.78), randf_range(0.18, 0.32), 1.0),
		})
	while shrapnel_armor_dust_particles.size() > SHRAPNEL_ARMOR_DUST_MAX:
		shrapnel_armor_dust_particles.pop_front()


func _get_shrapnel_armor_boss_rect(owner: Object) -> Rect2:
	if owner == null:
		return Rect2()
	var boss_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_pos", Vector2.ZERO))
	var boss_size: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_paddle_size", Vector2.ZERO))
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			max(1.0, float(_safe_owner_get(owner, "boss_paddle_width", 100.0))),
			max(1.0, float(_safe_owner_get(owner, "boss_hitbox_height", 40.0)))
		)
	if boss_pos == Vector2.ZERO and _safe_owner_get(owner, "boss_pos", null) == null:
		return Rect2()
	return Rect2(boss_pos, boss_size).grow(3.0)


func _apply_shrapnel_armor_boss_hit(hit_pos: Vector2, velocity: Vector2, boss_rect: Rect2, registry: Object) -> void:
	var direction: float = sign(velocity.x)
	if abs(direction) <= 0.01:
		direction = -1.0 if hit_pos.x >= boss_rect.get_center().x else 1.0
	shrapnel_armor_boss_knockback_vel = direction * _get_shrapnel_armor_knockback_velocity(get_shrapnel_armor_knockback_level())
	shrapnel_armor_boss_knockback_timer_frames = SHRAPNEL_ARMOR_BOSS_KNOCKBACK_FRAMES
	shrapnel_armor_boss_stun_timer_frames = max(shrapnel_armor_boss_stun_timer_frames, SHRAPNEL_ARMOR_BOSS_STUN_FRAMES)
	shrapnel_armor_boss_impact_timer_frames = SHRAPNEL_ARMOR_BOSS_IMPACT_FRAMES
	shrapnel_armor_boss_impact_center = boss_rect.get_center()
	_play_shrapnel_armor_hit_audio(registry)


func _get_shrapnel_armor_knockback_velocity(level: int) -> float:
	match max(1, level):
		1:
			return 6.0
		2:
			return 9.6
		3:
			return 14.4
		4:
			return 19.2
		_:
			return 19.2 + float(max(0, level - 4)) * 4.8


func _is_shrapnel_armor_effect_active() -> bool:
	return (
		shrapnel_armor_flash_timer_frames > 0.0
		or shrapnel_armor_boss_impact_timer_frames > 0.0
		or shrapnel_armor_boss_stun_timer_frames > 0.0
		or not shrapnel_armor_shards.is_empty()
		or not shrapnel_armor_dust_particles.is_empty()
	)


func _draw_shrapnel_armor_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_shrapnel_armor_effect(
		canvas,
		shake_offset,
		shrapnel_armor_flash_timer_frames,
		shrapnel_armor_flash_center,
		shrapnel_armor_shards,
		shrapnel_armor_dust_particles,
		shrapnel_armor_boss_impact_timer_frames,
		shrapnel_armor_boss_impact_center,
		SHRAPNEL_ARMOR_FLASH_FRAMES,
		SHRAPNEL_ARMOR_SHARD_LIFE_FRAMES,
		SHRAPNEL_ARMOR_BOSS_IMPACT_FRAMES
	)


func _update_knee_pads_runtime(fps_scale: float) -> void:
	if knee_pads_flash_timer_frames > 0.0:
		knee_pads_flash_timer_frames = max(0.0, knee_pads_flash_timer_frames - fps_scale)
	for i in range(knee_pads_particles.size() - 1, -1, -1):
		var particle: Dictionary = _get_dict(knee_pads_particles[i])
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			knee_pads_particles.remove_at(i)
			continue
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		var position: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		velocity.y += 0.30 * fps_scale
		position += velocity * fps_scale
		particle["life"] = life
		particle["velocity"] = velocity
		particle["position"] = position
		particle["size"] = max(1.0, float(particle.get("size", 2.0)) - 0.10 * fps_scale)
		knee_pads_particles[i] = particle


func _update_soul_burst_runtime(fps_scale: float) -> void:
	if not is_soul_burst_equipped() and (soul_burst_dash_active or not soul_burst_particles.is_empty()):
		_clear_soul_burst_runtime()
		return
	var step: float = max(0.0, fps_scale)
	if soul_burst_effect_timer_frames > 0.0:
		soul_burst_effect_timer_frames = max(0.0, soul_burst_effect_timer_frames - step)
	if soul_burst_effect_timer_frames <= 0.0:
		soul_burst_dash_active = false

	for i in range(soul_burst_shockwaves.size() - 1, -1, -1):
		var wave: Dictionary = _get_dict(soul_burst_shockwaves[i])
		var life: float = float(wave.get("life", 0.0)) - step
		if life <= 0.0:
			soul_burst_shockwaves.remove_at(i)
			continue
		wave["life"] = life
		soul_burst_shockwaves[i] = wave

	for i in range(soul_burst_particles.size() - 1, -1, -1):
		var particle: Dictionary = _get_dict(soul_burst_particles[i])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			soul_burst_particles.remove_at(i)
			continue
		var position: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity *= pow(0.95, step)
		particle["life"] = life
		particle["position"] = position
		particle["velocity"] = velocity
		particle["size"] = max(1.0, float(particle.get("size", 2.0)) * pow(0.985, step))
		soul_burst_particles[i] = particle

	for i in range(soul_burst_wind_trails.size() - 1, -1, -1):
		var trail: Dictionary = _get_dict(soul_burst_wind_trails[i])
		var life: float = float(trail.get("life", 0.0)) - step
		if life <= 0.0:
			soul_burst_wind_trails.remove_at(i)
			continue
		trail["life"] = life
		trail["offset"] = _get_vector2(trail.get("offset", Vector2.ZERO)) - Vector2(soul_burst_direction * 1.2 * step, 0.0)
		soul_burst_wind_trails[i] = trail


func _update_foul_whistle_runtime(fps_scale: float) -> void:
	foul_whistle_state.update(fps_scale, FOUL_WHISTLE_RESET_FRAME, FOUL_WHISTLE_TOTAL_FRAMES)


func _update_revival_runtime(fps_scale: float) -> void:
	revival_state.update(fps_scale)


func _update_sensor_runtime(fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	if sensor_cooldown_timer_frames > 0.0:
		sensor_cooldown_timer_frames = max(0.0, sensor_cooldown_timer_frames - step)
	if not is_sensor_equipped():
		sensor_auto_dash_effect_timer_frames = 0.0
		sensor_auto_dash_center = Vector2.ZERO
		sensor_last_dash_direction = 0.0
		return
	if sensor_auto_dash_effect_timer_frames > 0.0:
		sensor_auto_dash_effect_timer_frames = max(0.0, sensor_auto_dash_effect_timer_frames - step)
		if sensor_auto_dash_effect_timer_frames <= 0.0:
			sensor_auto_dash_center = Vector2.ZERO


func _update_poseidon_runtime(owner: Object, registry: Object, fps_scale: float) -> void:
	poseidon_player_center = _read_owner_player_center(owner)
	var was_cooling: bool = poseidon_effect_cooldown_frames > 0.0
	if poseidon_effect_cooldown_frames > 0.0:
		poseidon_effect_cooldown_frames = max(0.0, poseidon_effect_cooldown_frames - fps_scale)
	if was_cooling and poseidon_effect_cooldown_frames <= 0.0 and is_equipped(ITEM_POSEIDON_TRIDENT):
		_start_poseidon_water_explosion()
		_play_poseidon_charge_audio(registry)
	if poseidon_vortex_reentry_cooldown_frames > 0.0:
		poseidon_vortex_reentry_cooldown_frames = max(0.0, poseidon_vortex_reentry_cooldown_frames - fps_scale)
	_update_poseidon_dash_trigger(owner, registry)
	_update_poseidon_vortex(fps_scale)
	_update_poseidon_particles(fps_scale)
	_update_poseidon_water_trail(fps_scale)
	_update_poseidon_water_explosion(fps_scale)


func _update_celestial_armor_runtime(fps_scale: float) -> void:
	celestial_armor_state.update(fps_scale, is_celestial_armor_equipped())


func _update_hermes_shoes_runtime(owner: Object, fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	var player_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_size := Vector2(
		float(_safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)),
		float(_safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT))
	)
	hermes_shoes_state.update(
		is_hermes_shoes_equipped(),
		player_pos,
		player_size,
		step,
		HERMES_SHOES_TRAIL_LIFE_FRAMES,
		HERMES_SHOES_TRAIL_MAX,
		HERMES_SHOES_MOVE_TRAIL_THRESHOLD,
		HERMES_SHOES_WING_FLAP_SPEED
	)


func _consume_celestial_armor_gauge(gauge_cost: int, deps: Dictionary) -> bool:
	if gauge_cost <= 0:
		return true
	var context: Dictionary = _get_dict(deps.get("context", {}))
	var owner: Object = deps.get("owner", null)
	if owner == null and context.get("owner", null) is Object:
		owner = context.get("owner", null)
	var fallback_gauge: float = float(context.get("special_gauge", 0.0))
	if owner != null:
		var current_owner_gauge: float = max(0.0, float(_safe_owner_get(owner, "special_gauge", fallback_gauge)))
		if current_owner_gauge + 0.001 < float(gauge_cost):
			return false
		var next_owner_gauge: float = max(0.0, current_owner_gauge - float(gauge_cost))
		owner.set("special_gauge", next_owner_gauge)
		context["special_gauge"] = next_owner_gauge
		return true
	if context.is_empty():
		return false
	var current_context_gauge: float = max(0.0, float(context.get("special_gauge", 0.0)))
	if current_context_gauge + 0.001 < float(gauge_cost):
		return false
	context["special_gauge"] = max(0.0, current_context_gauge - float(gauge_cost))
	return true


func _start_celestial_armor_wave(center: Vector2, _source: String = "") -> void:
	celestial_armor_state.start_wave(center, CELESTIAL_ARMOR_WAVE_LIFE_FRAMES)


func _resolve_celestial_armor_player_center(deps: Dictionary) -> Vector2:
	var context: Dictionary = _get_dict(deps.get("context", {}))
	if not context.is_empty():
		var context_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO))
		var context_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2.ZERO))
		if context_size == Vector2.ZERO:
			context_size = Vector2(
				float(context.get("player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)),
				float(context.get("player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT))
			)
		if context_pos != Vector2.ZERO or context.has("player_pos"):
			return context_pos + context_size * 0.5
	var owner: Object = deps.get("owner", null)
	if owner == null and context.get("owner", null) is Object:
		owner = context.get("owner", null)
	if owner != null:
		var owner_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO))
		var owner_size := Vector2(
			float(_safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)),
			float(_safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT))
		)
		return owner_pos + owner_size * 0.5
	return Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)


func _update_poseidon_dash_trigger(owner: Object, registry: Object) -> void:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	var active := false
	var recovering := false
	var direction := 0.0
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Dictionary = dash_state.get_snapshot()
		active = bool(snapshot.get("active", false))
		recovering = bool(snapshot.get("recovering", false))
		direction = float(snapshot.get("direction", 0.0))
	if abs(direction) > 0.01:
		poseidon_last_dash_direction = direction

	var just_started_recovery: bool = recovering and not poseidon_dash_was_recovering and poseidon_dash_was_active
	if is_equipped(ITEM_POSEIDON_TRIDENT) and just_started_recovery:
		var trigger_direction: float = direction
		if abs(trigger_direction) <= 0.01:
			trigger_direction = poseidon_last_dash_direction
		_try_trigger_poseidon_vortex(owner, registry, trigger_direction)

	poseidon_dash_was_active = active
	poseidon_dash_was_recovering = recovering


func _try_trigger_poseidon_vortex(owner: Object, registry: Object, direction: float) -> bool:
	if not is_equipped(ITEM_POSEIDON_TRIDENT):
		return false
	if poseidon_effect_cooldown_frames > 0.0:
		return false
	var gauge_cost: float = get_poseidon_gauge_cost()
	var current_gauge: float = float(_safe_owner_get(owner, "special_gauge", 0.0))
	if current_gauge < gauge_cost:
		return false
	if owner != null:
		owner.set("special_gauge", max(0.0, current_gauge - gauge_cost))
	poseidon_effect_cooldown_frames = get_poseidon_cooldown() * 60.0
	_start_poseidon_vortex(owner, direction)
	_play_poseidon_wave_audio(registry)
	_apply_poseidon_feedback({"registry": registry}, POSEIDON_FEEDBACK_SHAKE_AMOUNT * 0.65, POSEIDON_FEEDBACK_SHAKE_INTENSITY * 0.75)
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return true


func _start_poseidon_vortex(owner: Object, direction: float) -> void:
	var player_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_size := Vector2(
		float(_safe_owner_get(owner, "player_paddle_width", 155.0)),
		float(_safe_owner_get(owner, "player_paddle_height", 50.0))
	)
	var anchor: Vector2 = player_pos + Vector2(player_size.x * 0.5, player_size.y * 0.5)
	poseidon_vortex_left_pos = anchor + Vector2(-POSEIDON_VORTEX_OFFSET_X, 0.0)
	poseidon_vortex_right_pos = anchor + Vector2(POSEIDON_VORTEX_OFFSET_X, 0.0)
	poseidon_vortex_left_height = 0.0
	poseidon_vortex_right_height = 0.0
	poseidon_vortex_spin_speed = 0.0
	poseidon_vortex_timer_frames = 0.0
	poseidon_vortex_active = true
	poseidon_vortex_reentry_cooldown_frames = 0.0
	poseidon_vortex_affected = false
	poseidon_water_trail.clear()
	poseidon_water_trail_active = false
	if abs(direction) > 0.01:
		poseidon_last_dash_direction = direction
	poseidon_particles.clear()
	_spawn_poseidon_particles(POSEIDON_INITIAL_PARTICLES_PER_SIDE, true)


func _update_poseidon_vortex(fps_scale: float) -> void:
	if not poseidon_vortex_active:
		return
	poseidon_vortex_timer_frames += fps_scale
	var max_height: float = POSEIDON_VORTEX_MAX_HEIGHT
	if poseidon_vortex_timer_frames < POSEIDON_VORTEX_GROW_FRAMES:
		var growth: float = clamp(poseidon_vortex_timer_frames / POSEIDON_VORTEX_GROW_FRAMES, 0.0, 1.0)
		poseidon_vortex_left_height = max_height * growth
		poseidon_vortex_right_height = max_height * growth
		poseidon_vortex_spin_speed = 10.0 * growth
	elif poseidon_vortex_timer_frames < POSEIDON_VORTEX_HOLD_FRAMES:
		poseidon_vortex_left_height = max_height
		poseidon_vortex_right_height = max_height
		poseidon_vortex_spin_speed = 10.0
	elif poseidon_vortex_timer_frames < POSEIDON_VORTEX_TOTAL_FRAMES:
		var fade: float = 1.0 - (poseidon_vortex_timer_frames - POSEIDON_VORTEX_HOLD_FRAMES) / (POSEIDON_VORTEX_TOTAL_FRAMES - POSEIDON_VORTEX_HOLD_FRAMES)
		poseidon_vortex_left_height = max_height * clamp(fade, 0.0, 1.0)
		poseidon_vortex_right_height = max_height * clamp(fade, 0.0, 1.0)
		poseidon_vortex_spin_speed = 10.0 * clamp(fade, 0.0, 1.0)
	else:
		poseidon_vortex_active = false
		poseidon_vortex_left_height = 0.0
		poseidon_vortex_right_height = 0.0

	if poseidon_vortex_active and poseidon_vortex_timer_frames < POSEIDON_VORTEX_HOLD_FRAMES and poseidon_particles.size() < POSEIDON_MAX_PARTICLES:
		_spawn_poseidon_particles(2, false)


func _spawn_poseidon_particles(count_per_side: int, initial_burst: bool) -> void:
	for side in [-1, 1]:
		for _i in range(count_per_side):
			if poseidon_particles.size() >= POSEIDON_MAX_PARTICLES:
				return
			poseidon_particles.append(_make_poseidon_particle(side, initial_burst))


func _make_poseidon_particle(side: int, initial_burst: bool) -> Dictionary:
	var width: float = get_poseidon_vortex_size()
	var center_pos: Vector2 = poseidon_vortex_left_pos if side < 0 else poseidon_vortex_right_pos
	var spawn_x: float
	var spawn_y: float
	var spiral_radius: float
	var life: float
	if initial_burst:
		var particle_spread: float = width * 0.15
		var spiral_max: float = max(20.0, width * 0.30)
		var height_offset: float = randf_range(0.0, width)
		spawn_x = center_pos.x + randf_range(-particle_spread, particle_spread)
		spawn_y = center_pos.y - height_offset
		spiral_radius = randf_range(20.0, spiral_max)
		life = float(randi_range(40, 80))
	else:
		spawn_x = center_pos.x + randf_range(-50.0, 50.0)
		spawn_y = center_pos.y + randf_range(-20.0, 20.0)
		spiral_radius = randf_range(20.0, 60.0)
		life = float(randi_range(30, 60))
	return {
		"side": side,
		"x": spawn_x,
		"y": spawn_y,
		"spiral_angle": randf_range(0.0, TAU),
		"spiral_radius": spiral_radius,
		"size": randf_range(3.0, 10.0),
		"life": life,
		"max_life": life,
		"color": Color(50.0 / 255.0, (150.0 + randf_range(0.0, 100.0)) / 255.0, 1.0),
	}


func _update_poseidon_particles(fps_scale: float) -> void:
	if poseidon_particles.is_empty():
		return
	var radius_decay: float = pow(POSEIDON_PARTICLE_RADIUS_DECAY, fps_scale)
	var write_index := 0
	for read_index in range(poseidon_particles.size()):
		var particle: Dictionary = _get_dict(poseidon_particles[read_index])
		var remaining: float = float(particle.get("life", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		particle["life"] = remaining
		var side: int = int(particle.get("side", -1))
		var center_pos: Vector2 = poseidon_vortex_left_pos if side < 0 else poseidon_vortex_right_pos
		var angle: float = float(particle.get("spiral_angle", 0.0)) + poseidon_vortex_spin_speed * 0.1 * fps_scale
		var radius: float = float(particle.get("spiral_radius", 0.0)) * radius_decay
		particle["spiral_angle"] = angle
		particle["spiral_radius"] = radius
		particle["x"] = center_pos.x + cos(angle) * radius
		particle["y"] = float(particle.get("y", 0.0)) - POSEIDON_PARTICLE_RISE_SPEED * fps_scale
		particle["size"] = float(particle.get("size", 0.0)) * radius_decay
		poseidon_particles[write_index] = particle
		write_index += 1
	if write_index < poseidon_particles.size():
		poseidon_particles.resize(write_index)


func _update_poseidon_water_trail(fps_scale: float) -> void:
	if poseidon_water_trail.is_empty():
		return
	var write_index := 0
	for read_index in range(poseidon_water_trail.size()):
		var droplet: Dictionary = _get_dict(poseidon_water_trail[read_index])
		var remaining: float = float(droplet.get("life", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		droplet["life"] = remaining
		droplet["x"] = float(droplet.get("x", 0.0)) + float(droplet.get("vx", 0.0)) * fps_scale
		droplet["y"] = float(droplet.get("y", 0.0)) + float(droplet.get("vy", 0.0)) * fps_scale
		droplet["vy"] = float(droplet.get("vy", 0.0)) + POSEIDON_DROPLET_GRAVITY * fps_scale
		poseidon_water_trail[write_index] = droplet
		write_index += 1
	if write_index < poseidon_water_trail.size():
		poseidon_water_trail.resize(write_index)
	if poseidon_water_trail.is_empty():
		poseidon_water_trail_active = false


func _add_poseidon_water_trail(ball_pos: Vector2) -> void:
	# Match original: 50% chance per ball-update tick to spawn 2-5 falling droplets.
	if randf() >= POSEIDON_DROPLET_SPAWN_CHANCE:
		return
	var count: int = randi_range(POSEIDON_DROPLET_MIN_PER_TICK, POSEIDON_DROPLET_MAX_PER_TICK)
	for _i in range(count):
		if poseidon_water_trail.size() >= POSEIDON_WATER_TRAIL_MAX_POINTS:
			break
		poseidon_water_trail.append({
			"x": ball_pos.x + randf_range(-8.0, 8.0),
			"y": ball_pos.y + randf_range(-8.0, 8.0),
			"vx": randf_range(-3.0, 3.0),
			"vy": randf_range(-2.0, 2.0),
			"size": randf_range(3.0, 6.0),
			"life": POSEIDON_WATER_TRAIL_LIFE_FRAMES,
			"max_life": POSEIDON_WATER_TRAIL_LIFE_FRAMES,
		})


func _read_owner_player_center(owner: Object) -> Vector2:
	var pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var size := Vector2(
		float(_safe_owner_get(owner, "player_paddle_width", 155.0)),
		float(_safe_owner_get(owner, "player_paddle_height", 50.0))
	)
	return pos + size * 0.5


func _start_poseidon_water_explosion() -> void:
	poseidon_explosion_active = true
	poseidon_explosion_timer = 0.0
	poseidon_explosion_particles.clear()
	for i in range(POSEIDON_EXPLOSION_PARTICLE_COUNT):
		var angle: float = float(i) / float(POSEIDON_EXPLOSION_PARTICLE_COUNT) * TAU + randf_range(-0.2, 0.2)
		var speed: float = randf_range(60.0, 90.0)
		poseidon_explosion_particles.append({
			"offset_x": 0.0,
			"offset_y": 0.0,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"size": randf_range(12.0, 24.0),
			"life": randf_range(1.2, 2.0),
			"max_life": 2.0,
			"color": Color(
				(100.0 + randf_range(0.0, 40.0)) / 255.0,
				(190.0 + randf_range(0.0, 50.0)) / 255.0,
				(240.0 + randf_range(0.0, 15.0)) / 255.0
			),
		})


func _update_poseidon_water_explosion(fps_scale: float) -> void:
	if not poseidon_explosion_active:
		return
	var dt: float = fps_scale / 60.0
	poseidon_explosion_timer += dt
	var damp: float = pow(POSEIDON_EXPLOSION_VEL_DAMP, fps_scale)
	var write_index := 0
	for read_index in range(poseidon_explosion_particles.size()):
		var p: Dictionary = _get_dict(poseidon_explosion_particles[read_index])
		var life: float = float(p.get("life", 0.0)) - dt
		if life <= 0.0:
			continue
		p["life"] = life
		p["offset_x"] = float(p.get("offset_x", 0.0)) + float(p.get("vx", 0.0)) * dt
		p["offset_y"] = float(p.get("offset_y", 0.0)) + float(p.get("vy", 0.0)) * dt
		p["vx"] = float(p.get("vx", 0.0)) * damp
		p["vy"] = float(p.get("vy", 0.0)) * damp
		poseidon_explosion_particles[write_index] = p
		write_index += 1
	if write_index < poseidon_explosion_particles.size():
		poseidon_explosion_particles.resize(write_index)
	if poseidon_explosion_particles.is_empty():
		poseidon_explosion_active = false


func _update_baal_boots_runtime(owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_baal_boots_equipped():
		if baal_boots_weather_state.has_round_activity():
			_clear_baal_boots_round_state(registry)
		return

	var step: float = max(0.0, fps_scale)
	if baal_boots_weather_state.has_round_activity():
		baal_boots_weather_state.set_absorb_center(_read_owner_player_center(owner))

	if baal_boots_weather_state.pending_weather_type != "":
		var pending_weather_type: String = baal_boots_weather_state.pending_weather_type
		_spawn_baal_aura_particles(baal_boots_weather_state.absorb_center, pending_weather_type, 1)
		if baal_boots_weather_state.tick_trigger(step):
			_begin_baal_absorb(owner, registry, pending_weather_type)

	if baal_boots_weather_state.tick_cinematic(step):
		_finish_baal_absorb(owner, registry)

	_update_baal_absorb_particles(step)
	_update_baal_aura_particles(step)
	_update_baal_projectiles(owner, registry, step)
	baal_boots_combat_state.update(step, BAAL_KNOCKBACK_DECAY)


func _try_arm_baal_boots_from_weather(
	owner: Object,
	registry: Object,
	weather_type_override: String = ""
) -> void:
	if not is_baal_boots_equipped() or baal_boots_weather_state.activated_this_round or baal_boots_weather_state.cinematic_active:
		return
	var weather: Object = _get_instance(registry, "weather_event_state")
	if weather == null:
		return
	var weather_active := true
	if weather.has_method("is_weather_active"):
		weather_active = bool(weather.is_weather_active())
	var weather_type := weather_type_override.strip_edges()
	if weather_type == "" and weather.has_method("get_weather_type"):
		weather_type = str(weather.get_weather_type())
	if not weather_active or weather_type == "":
		return
	baal_boots_weather_state.arm(weather_type, _read_owner_player_center(owner), BAAL_TRIGGER_DELAY_FRAMES)
	_spawn_baal_aura_particles(baal_boots_weather_state.absorb_center, weather_type, 12)


func _begin_baal_absorb(owner: Object, registry: Object, weather_type: String) -> void:
	var weather: Object = _get_instance(registry, "weather_event_state")
	if weather == null:
		baal_boots_weather_state.cancel_pending_activation()
		return
	var active_weather_type := weather_type
	if active_weather_type == "" and weather.has_method("get_weather_type"):
		active_weather_type = str(weather.get_weather_type())
	if active_weather_type == "" or (weather.has_method("is_weather_active") and not bool(weather.is_weather_active())):
		baal_boots_weather_state.cancel_pending_activation()
		return

	var absorb_center: Vector2 = _read_owner_player_center(owner)
	baal_boots_weather_state.set_absorb_center(absorb_center)
	var harvested: Array = []
	if weather.has_method("harvest_particles"):
		harvested = weather.harvest_particles(active_weather_type)
	var sand_absorbed_total := 0.0
	if active_weather_type == "sand" and weather.has_method("get_sand_total_depth"):
		sand_absorbed_total = float(weather.get_sand_total_depth())
	_build_baal_absorb_particles(harvested, active_weather_type)
	baal_boots_weather_state.start_absorb_cinematic(
		active_weather_type,
		absorb_center,
		sand_absorbed_total,
		BAAL_TELEGRAPH_FRAMES + BAAL_ABSORB_FRAMES
	)

	if weather.has_method("force_end_weather_event"):
		weather.force_end_weather_event(owner, registry)
	if weather.has_method("clear_visual_particles"):
		weather.clear_visual_particles()
	if active_weather_type == "sand" and weather.has_method("dissolve_sand_terrain"):
		weather.dissolve_sand_terrain()
	_apply_ragnarok_feedback({"registry": registry}, 0.14, 5.0)
	_play_baal_boots_absorb_audio(registry)


func _finish_baal_absorb(owner: Object, registry: Object) -> void:
	if not baal_boots_weather_state.finish_absorb():
		return
	if not baal_boots_weather_state.gauge_given:
		_give_baal_boots_gauge(owner, registry)
	if baal_boots_weather_state.round_weather_type == "sand":
		var weather: Object = _get_instance(registry, "weather_event_state")
		if weather != null and weather.has_method("rebuild_sand_behind_player"):
			weather.rebuild_sand_behind_player(_read_owner_player_center(owner))
	_spawn_baal_aura_particles(_read_owner_player_center(owner), baal_boots_weather_state.round_weather_type, 20)


func _build_baal_absorb_particles(harvested: Array, weather_type: String) -> void:
	baal_boots_effect_state.build_absorb_particles(
		harvested,
		weather_type,
		_get_baal_weather_color(weather_type),
		BAAL_ABSORB_PARTICLE_FALLBACK_COUNT,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		BAAL_ABSORB_FRAMES
	)


func _update_baal_absorb_particles(fps_scale: float) -> void:
	baal_boots_effect_state.update_absorb_particles(
		fps_scale,
		baal_boots_weather_state.absorb_center,
		baal_boots_weather_state.cinematic_active
	)


func _spawn_baal_aura_particles(center: Vector2, weather_type: String, count: int) -> void:
	baal_boots_effect_state.spawn_aura_particles(
		center,
		weather_type,
		count,
		_get_baal_weather_color(weather_type),
		BAAL_AURA_PARTICLE_MAX
	)


func _update_baal_aura_particles(fps_scale: float) -> void:
	baal_boots_effect_state.update_aura_particles(fps_scale)


func _spawn_baal_projectiles(ball_pos: Vector2, weather_type: String, context: Dictionary) -> void:
	var boss_center: Vector2 = _resolve_boss_center_from_context(context)
	baal_boots_effect_state.spawn_projectiles(
		ball_pos,
		boss_center,
		weather_type,
		_get_baal_weather_color(weather_type),
		BAAL_PROJECTILE_SPEED,
		BAAL_PROJECTILE_LIFE_FRAMES
	)


func _update_baal_projectiles(owner: Object, registry: Object, fps_scale: float) -> void:
	var boss_rect: Rect2 = _get_baal_boss_rect(owner)
	var hit_events: Array = baal_boots_effect_state.update_projectiles(
		fps_scale,
		boss_rect,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT)
	)
	for hit_event_value in hit_events:
		var hit_event: Dictionary = _get_dict(hit_event_value)
		_apply_baal_projectile_hit(
			_get_vector2(hit_event.get("position", Vector2.ZERO)),
			str(hit_event.get("weather_type", "")),
			owner,
			registry
		)


func _apply_baal_projectile_hit(pos: Vector2, weather_type: String, owner: Object, registry: Object) -> void:
	match weather_type:
		"rain":
			baal_boots_combat_state.apply_slow(BAAL_RAIN_SLOW_FRAMES)
		"hail":
			var boss_center: Vector2 = _read_owner_boss_center(owner)
			var direction: float = 1.0 if boss_center.x < FIELD_WIDTH * 0.5 else -1.0
			baal_boots_combat_state.apply_knockback(direction, BAAL_KNOCKBACK_POWER, BAAL_KNOCKBACK_FRAMES)
	_spawn_baal_aura_particles(pos, weather_type, 12)
	_apply_ragnarok_feedback({"registry": registry}, 0.06, 2.7)


func _get_baal_boss_rect(owner: Object) -> Rect2:
	var pos: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_pos", Vector2(330.0, 25.0)))
	var size: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_paddle_size", Vector2.ZERO))
	if size == Vector2.ZERO:
		size = Vector2(
			float(_safe_owner_get(owner, "boss_paddle_width", 100.0)),
			float(_safe_owner_get(owner, "boss_hitbox_height", 40.0))
		)
	return Rect2(pos, size)


func _give_baal_boots_gauge(owner: Object, registry: Object) -> void:
	baal_boots_weather_state.gauge_given = true
	if owner == null:
		return
	var gain: float = get_baal_boots_gauge_recovery()
	if gain <= 0.0:
		return
	var gauge_max: float = max(1.0, float(_safe_owner_get(owner, "special_gauge_max", BASE_SPECIAL_GAUGE_MAX)))
	var current_gauge: float = clamp(float(_safe_owner_get(owner, "special_gauge", 0.0)), 0.0, gauge_max)
	var next_gauge: float = clamp(current_gauge + gain, 0.0, gauge_max)
	if next_gauge <= current_gauge:
		return
	owner.set("special_gauge", next_gauge)
	_trigger_gauge_feedback({"registry": registry})
	_trigger_orb_gauge_spin({"orb_hud_state": _get_instance(registry, "orb_hud_state")})


func _get_baal_boots_player_speed_multiplier() -> float:
	if not baal_boots_weather_state.round_effect_active:
		return 1.0
	var round_weather_type: String = baal_boots_weather_state.round_weather_type
	return BAAL_WIND_SPEED_MULTIPLIER if round_weather_type == "breeze" or round_weather_type == "gust" else 1.0


func _resolve_boss_center_from_context(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2(330.0, 25.0)))
	var boss_size: Vector2 = _get_vector2(context.get("boss_paddle_size", Vector2.ZERO))
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	return boss_pos + boss_size * 0.5


func _get_baal_weather_color(weather_type: String) -> Color:
	match weather_type:
		"breeze":
			return Color(0.66, 0.90, 1.0, 1.0)
		"gust":
			return Color(1.0, 0.78, 0.36, 1.0)
		"fire":
			return Color(1.0, 0.26, 0.10, 1.0)
		"ice":
			return Color(0.62, 0.92, 1.0, 1.0)
		"rain":
			return Color(0.32, 0.66, 1.0, 1.0)
		"hail":
			return Color(0.82, 0.94, 1.0, 1.0)
		"sand":
			return Color(0.90, 0.68, 0.32, 1.0)
	return Color(1.0, 0.40, 0.22, 1.0)


func _get_poseidon_vortex_hit(ball_pos: Vector2) -> Dictionary:
	var width: float = get_poseidon_vortex_size()
	var half_width: float = width * 0.5
	var candidates: Array = [
		{"side": "left", "pos": poseidon_vortex_left_pos, "height": poseidon_vortex_left_height},
		{"side": "right", "pos": poseidon_vortex_right_pos, "height": poseidon_vortex_right_height},
	]
	for candidate_value in candidates:
		var candidate: Dictionary = _get_dict(candidate_value)
		var base: Vector2 = _get_vector2(candidate.get("pos", Vector2.ZERO))
		var height: float = min(float(candidate.get("height", 0.0)), POSEIDON_VORTEX_MAX_HEIGHT)
		if height <= 1.0:
			continue
		var x_in_vortex: bool = abs(ball_pos.x - base.x) <= half_width
		var y_in_vortex: bool = ball_pos.y >= base.y - height - 20.0 and ball_pos.y <= base.y + 100.0
		if x_in_vortex and y_in_vortex:
			return candidate
	return {}


func _draw_knee_pads_effects(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_knee_pads_effects(
		canvas,
		shake_offset,
		knee_pads_flash_center,
		knee_pads_flash_timer_frames,
		knee_pads_particles,
		KNEE_PADS_FLASH_DURATION_FRAMES
	)


func _draw_soul_burst_effects(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_soul_burst_effects(
		canvas,
		shake_offset,
		soul_burst_center,
		soul_burst_direction,
		soul_burst_wind_trails,
		soul_burst_shockwaves,
		soul_burst_particles,
		SOUL_BURST_PARTICLE_ALPHA_CUTOFF
	)


func _draw_soul_burst_ellipse_arc(
	canvas: CanvasItem,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	color: Color,
	width: float
) -> void:
	field_effect_renderer.draw_soul_burst_ellipse_arc(canvas, center, radius_x, radius_y, color, width)


func _draw_poseidon_effects(canvas: CanvasItem, shake_offset: Vector2) -> void:
	# Original Python ordering (legendary_items.PoseidonTrident.draw_effects):
	#   1) water trail droplets (drawn first so they appear under the vortex)
	#   2) vortex particles (NO column — original explicitly removed it)
	#   3) water explosion / cooldown-charge flash on top
	field_effect_renderer.draw_poseidon_effects(
		canvas,
		shake_offset,
		poseidon_water_trail,
		poseidon_particles,
		poseidon_explosion_active,
		poseidon_player_center,
		poseidon_explosion_timer,
		poseidon_explosion_particles,
		POSEIDON_EXPLOSION_FLASH_DURATION
	)


func _draw_poseidon_water_trail(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_poseidon_water_trail(canvas, shake_offset, poseidon_water_trail)


func _draw_poseidon_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_poseidon_particles(canvas, shake_offset, poseidon_particles)


func _draw_poseidon_water_explosion(canvas: CanvasItem, shake_offset: Vector2) -> void:
	field_effect_renderer.draw_poseidon_water_explosion(
		canvas,
		shake_offset,
		poseidon_explosion_active,
		poseidon_player_center,
		poseidon_explosion_timer,
		poseidon_explosion_particles,
		POSEIDON_EXPLOSION_FLASH_DURATION
	)


func _soften_ragnarok_counter_ball(ball_vel: Vector2) -> Vector2:
	var speed: float = ball_vel.length()
	if speed <= 0.01:
		return ball_vel
	var anchor_speed: float = max(ragnarok_original_speed, ragnarok_first_shot_speed * 0.80)
	if anchor_speed <= 0.01:
		anchor_speed = speed * 0.82
	var target_speed: float = max(7.0, anchor_speed)
	var next_ball_vel: Vector2 = ball_vel
	if speed > target_speed:
		next_ball_vel = next_ball_vel.normalized() * target_speed
	var next_speed: float = next_ball_vel.length()
	if next_speed > 0.01:
		next_ball_vel.x = clamp(next_ball_vel.x, -next_speed * 0.55, next_speed * 0.55)
		next_ball_vel.y = min(next_ball_vel.y, next_speed * 0.85)
		if next_ball_vel.length() > target_speed:
			next_ball_vel = next_ball_vel.normalized() * target_speed
	_clear_ragnarok_rally_state()
	return next_ball_vel


func _compute_ragnarok_knockback_power(ball_speed: float) -> float:
	var base_power: float = RAGNAROK_BASE_KNOCKBACK_POWER + max(0.0, ball_speed) * RAGNAROK_SPEED_WEIGHT
	base_power *= 1.0 + randf_range(0.02, 0.06)
	return clamp(base_power, 0.0, RAGNAROK_MAX_KNOCKBACK_POWER)


func _update_ragnarok_stun_target(owner: Object) -> void:
	var fallback_pos: Vector2 = ragnarok_impact_center - ragnarok_stun_target_size * 0.5
	var owner_size: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_paddle_size", ragnarok_stun_target_size))
	if owner_size != Vector2.ZERO:
		ragnarok_stun_target_size = owner_size
	var boss_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_pos", fallback_pos))
	ragnarok_impact_center = boss_pos + ragnarok_stun_target_size * 0.5


func _resolve_chargebag_base_wall_gauge_gain(context: Dictionary) -> float:
	var character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	match character_type:
		"optimus":
			return 0.0
		"soldier", "commando":
			return 50.0
		"blacksmith", "baltor":
			if bool(context.get("blacksmith_umbrella_open", false)):
				return max(0.0, float(context.get("blacksmith_umbrella_gauge_gain", 60.0)))
			return 30.0
	var fallback_gain: float = float(context.get("gauge_charge_per_hit", 50.0))
	return max(0.0, fallback_gain)


func _resolve_knee_pads_base_charge(context: Dictionary) -> float:
	var character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	match character_type:
		"soldier", "commando":
			return 60.0
		"blacksmith", "baltor":
			return 30.0
	return 60.0


func _is_knee_pads_half_dash_window_active(deps: Dictionary) -> bool:
	var dash_state: Object = _get_dict(deps).get("dash_state", null)
	if dash_state == null or not dash_state.has_method("get_snapshot"):
		knee_pads_half_dash_consumed = false
		return false
	var dash_snapshot: Dictionary = _get_dict(dash_state.get_snapshot())
	if not bool(dash_snapshot.get("is_half", false)):
		knee_pads_half_dash_consumed = false
		return false
	var valid_window: bool = (
		bool(dash_snapshot.get("active", false))
		or bool(dash_snapshot.get("recovering", false))
		or float(dash_snapshot.get("timer", 0.0)) > 0.0
		or float(dash_snapshot.get("stun_timer", 0.0)) > 0.0
	)
	if not valid_window:
		knee_pads_half_dash_consumed = false
	return valid_window


func _start_knee_pads_effect(ball_pos: Vector2, deps: Dictionary) -> void:
	knee_pads_flash_center = ball_pos
	knee_pads_flash_timer_frames = KNEE_PADS_FLASH_DURATION_FRAMES
	knee_pads_particles.clear()
	for _i in range(KNEE_PADS_PARTICLE_COUNT):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(3.0, 8.0)
		var color: Color = [
			Color(1.0, 1.0, 0.0),
			Color(1.0, 220.0 / 255.0, 0.0),
			Color(1.0, 200.0 / 255.0, 100.0 / 255.0),
		][randi() % 3]
		knee_pads_particles.append({
			"position": ball_pos,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": 30.0,
			"max_life": 30.0,
			"color": color,
			"size": randf_range(2.0, 5.0),
		})
	var feedback: Object = _get_dict(deps).get("feedback", null)
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(KNEE_PADS_SHAKE_AMOUNT, KNEE_PADS_SHAKE_INTENSITY)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(KNEE_PADS_SHAKE_AMOUNT, KNEE_PADS_SHAKE_INTENSITY)


func _build_soul_burst_effects() -> void:
	soul_burst_particles.clear()
	soul_burst_shockwaves.clear()
	soul_burst_wind_trails.clear()
	for wave_index in range(3):
		var max_life: float = max(8.0, SOUL_BURST_SHOCKWAVE_FRAMES - float(wave_index) * 2.0)
		soul_burst_shockwaves.append({
			"start_radius": 18.0 + float(wave_index) * 8.0,
			"max_radius": 78.0 + float(wave_index) * 18.0,
			"squeeze": 0.62 + float(wave_index) * 0.08,
			"life": max_life,
			"max_life": max_life,
		})
	for _i in range(SOUL_BURST_PARTICLE_COUNT):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(2.0, 7.2)
		var forward_boost := Vector2(soul_burst_direction * randf_range(1.0, 5.0), randf_range(-1.0, 1.0))
		var color: Color = [
			Color(92.0 / 255.0, 22.0 / 255.0, 170.0 / 255.0, 1.0),
			Color(170.0 / 255.0, 72.0 / 255.0, 1.0, 1.0),
			Color(235.0 / 255.0, 205.0 / 255.0, 1.0, 1.0),
		][randi() % 3]
		var life: float = randf_range(16.0, 30.0)
		soul_burst_particles.append({
			"position": soul_burst_center + Vector2(randf_range(-18.0, 18.0), randf_range(-16.0, 16.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed + forward_boost,
			"life": life,
			"max_life": life,
			"color": color,
			"size": randf_range(2.0, 4.8),
		})
	for _i in range(SOUL_BURST_WIND_TRAIL_COUNT):
		var life: float = randf_range(10.0, 24.0)
		soul_burst_wind_trails.append({
			"offset": Vector2(-soul_burst_direction * randf_range(8.0, 58.0), randf_range(-28.0, 28.0)),
			"length": randf_range(34.0, 92.0),
			"width": randf_range(1.5, 4.0),
			"life": life,
			"max_life": life,
		})


func _is_aipill_active_from_deps(deps: Dictionary) -> bool:
	var active_item_runtime: Object = _get_dict(deps).get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_aipill_active"):
		return bool(active_item_runtime.is_aipill_active())
	return false


func _trigger_gauge_feedback(deps: Dictionary) -> void:
	var feedback: Object = _get_dict(deps).get("feedback", null)
	if feedback == null:
		feedback = _get_instance(_get_dict(deps).get("registry", null), "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _trigger_orb_gauge_spin(deps: Dictionary) -> void:
	var orb_hud_state: Object = _get_dict(deps).get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(Time.get_ticks_msec())


func _get_commando_arm_roll_sum(option_key: String) -> float:
	return roll_query.get_commando_arm_roll_sum(self, option_key, CONTEXT_CONSTANTS)


func _get_commando_arm_roll_values(option_key: String) -> Array:
	return roll_query.get_commando_arm_roll_values(self, option_key, CONTEXT_CONSTANTS)


func _get_equipped_roll_values(item_name: String, option_key: String, limit: int = -1) -> Array:
	return roll_query.get_equipped_roll_values(self, item_name, option_key, limit)


func _get_equipped_roll_value(item_name: String, option_key: String) -> float:
	return roll_query.get_equipped_roll_value(self, item_name, option_key)


func get_item_roll_value(
	item_data: Dictionary,
	option_key: String,
	apply_polish: bool = true,
	registry: Object = null
) -> float:
	return roll_query.get_public_item_roll_value(self, item_data, option_key, apply_polish, registry)


func _get_item_roll_value(
	item_data: Dictionary,
	item_name: String,
	option_key: String,
	apply_polish: bool = true
) -> float:
	return roll_query.get_item_roll_value(self, item_data, item_name, option_key, apply_polish)


func _get_equipped_roll_sum(item_name: String, option_key: String) -> float:
	return roll_query.get_equipped_roll_sum(self, item_name, option_key)


func _get_equipped_roll_max(item_name: String, option_key: String) -> float:
	return roll_query.get_equipped_roll_max(self, item_name, option_key)


func _has_equipped_item_name(item_name: String) -> bool:
	return roll_query.has_equipped_item_name(self, item_name)


func _count_equipped_item_name(item_name: String) -> int:
	return roll_query.count_equipped_item_name(self, item_name)


func _count_owned_item_name(item_name: String) -> int:
	return roll_query.count_owned_item_name(self, item_name)


func _consume_equipped_item_name(item_name: String, owner: Object = null, registry: Object = null) -> bool:
	var index: int = _find_equipped_inventory_index_by_name(item_name)
	if index < 0:
		return false
	inventory_items.remove_at(index)
	_rebuild_equipped_items()
	_sync_owner(owner, registry)
	return true


func _find_catalog_roll_option(item_name: String, option_key: String) -> Dictionary:
	return roll_query.find_catalog_roll_option(self, item_name, option_key)


func _build_ragnarok_sparks() -> void:
	ragnarok_sparks.clear()
	for _i in range(RAGNAROK_SPARK_COUNT):
		var life: float = randf_range(0.26, 0.78)
		ragnarok_sparks.append({
			"angle": randf_range(0.0, TAU),
			"radius": randf_range(18.0, 48.0),
			"speed": randf_range(58.0, 188.0),
			"life": life,
			"max_life": life,
			"width": randf_range(1.0, 2.7),
			"color": Color(130.0 / 255.0, 210.0 / 255.0, 1.0),
		})


func _update_ragnarok_sparks(delta: float) -> void:
	if ragnarok_sparks.is_empty():
		return
	var write_index := 0
	for read_index in range(ragnarok_sparks.size()):
		var spark: Dictionary = _get_dict(ragnarok_sparks[read_index])
		var remaining: float = float(spark.get("life", 0.0)) - delta
		if remaining <= 0.0:
			continue
		spark["life"] = remaining
		spark["radius"] = float(spark.get("radius", 0.0)) + float(spark.get("speed", 0.0)) * delta
		ragnarok_sparks[write_index] = spark
		write_index += 1
	if write_index < ragnarok_sparks.size():
		ragnarok_sparks.resize(write_index)


func _draw_ragnarok_impact_rings(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	field_effect_renderer.draw_ragnarok_impact_rings(
		canvas,
		center,
		elapsed,
		RAGNAROK_IMPACT_EFFECT_DURATION,
		RAGNAROK_IMPACT_RING_SEGMENTS
	)


func _draw_ragnarok_stun_aura(canvas: CanvasItem, center: Vector2) -> void:
	field_effect_renderer.draw_ragnarok_stun_aura(
		canvas,
		center,
		RAGNAROK_STUN_AURA_SEGMENTS,
		RAGNAROK_STUN_AURA_OUTER_SEGMENTS
	)


func _draw_ragnarok_electric_stun_overlay(canvas: CanvasItem, center: Vector2, target_size: Vector2, intensity: float) -> void:
	field_effect_renderer.draw_ragnarok_electric_stun_overlay(
		canvas,
		center,
		target_size,
		intensity,
		RAGNAROK_ELECTRIC_ELLIPSE_SEGMENTS,
		RAGNAROK_ELECTRIC_OUTER_COLORS,
		RAGNAROK_ELECTRIC_CORE_COLORS,
		RAGNAROK_ELECTRIC_BRANCH_COLORS,
		RAGNAROK_ELECTRIC_SPARK_COLORS
	)

	# 글로우 링 - 패들 주변을 감싸는 청백 타원 글로우 (BLEND_ADD 대용으로 다층 알파 누적)


	# 메인 아크 - 짧고 들쭉날쭉한 번개 줄기 (원본 Python 스타일)

	# 가지 번개 - 짧은 곁가지 (4-7개)

	# 스파크 - 작은 빛 점들


func _make_ragnarok_ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	return field_effect_renderer.make_ragnarok_ellipse_points(center, radius_x, radius_y, segments)


func _draw_ragnarok_sparks(canvas: CanvasItem, center: Vector2, _shake_offset: Vector2 = Vector2.ZERO) -> void:
	field_effect_renderer.draw_ragnarok_sparks(canvas, center, ragnarok_sparks, RAGNAROK_PARTICLE_ALPHA_CUTOFF)


func _apply_ragnarok_feedback(deps: Dictionary, amount: float, intensity: float) -> void:
	audio_router.apply_ragnarok_feedback(self, deps, amount, intensity)


func _apply_poseidon_feedback(deps: Dictionary, amount: float, intensity: float) -> void:
	audio_router.apply_poseidon_feedback(self, deps, amount, intensity)


func _play_ragnarok_shot_audio(registry: Object) -> void:
	audio_router.play_ragnarok_shot_audio(self, registry)


func _play_ragnarok_boom_audio(registry: Object) -> void:
	audio_router.play_ragnarok_boom_audio(self, registry)


func _play_ragnarok_shock_audio(registry: Object) -> void:
	audio_router.play_ragnarok_shock_audio(self, registry)


func _stop_ragnarok_shock_audio(registry: Object) -> void:
	audio_router.stop_ragnarok_shock_audio(self, registry)


func _get_ragnarok_audio(registry: Object) -> Object:
	return audio_router.get_ragnarok_audio(self, registry)


func _play_poseidon_wave_audio(registry: Object) -> void:
	audio_router.play_poseidon_wave_audio(self, registry)


func _play_poseidon_charge_audio(registry: Object) -> void:
	audio_router.play_poseidon_charge_audio(self, registry)


func _play_knee_pads_audio(registry: Object) -> void:
	audio_router.play_knee_pads_audio(self, registry)


func _play_soul_burst_audio(registry: Object) -> void:
	audio_router.play_soul_burst_audio(self, registry)


func _play_celestial_armor_audio(registry: Object) -> void:
	audio_router.play_celestial_armor_audio(self, registry)


func _play_baal_boots_absorb_audio(registry: Object) -> void:
	audio_router.play_baal_boots_absorb_audio(self, registry)


func _play_baal_boots_pulse_audio(registry: Object) -> void:
	audio_router.play_baal_boots_pulse_audio(self, registry)


func _play_foul_whistle_audio(source: Variant) -> void:
	audio_router.play_foul_whistle_audio(self, source)


func _get_poseidon_audio(registry: Object) -> Object:
	return audio_router.get_poseidon_audio(self, registry)


func _ragnarok_ball_elapsed() -> float:
	return float(Time.get_ticks_msec() - ragnarok_ball_started_msec) / 1000.0


func _ragnarok_impact_elapsed() -> float:
	return float(Time.get_ticks_msec() - ragnarok_impact_started_msec) / 1000.0


func _sync_owner(owner: Object, registry: Object = null) -> void:
	owner_syncer.sync_owner(self, owner, registry, CONTEXT_CONSTANTS)


func _sync_fuel_pouch_gauge_max(owner: Object) -> void:
	owner_syncer.sync_fuel_pouch_gauge_max(self, owner, CONTEXT_CONSTANTS)


func _sync_boomerang_active_slot_visuals(owner: Object) -> void:
	owner_syncer.sync_boomerang_active_slot_visuals(self, owner, CONTEXT_CONSTANTS)


func _sync_bulkup_paddle_scale(owner: Object, registry: Object) -> void:
	owner_syncer.sync_bulkup_paddle_scale(self, owner, registry, CONTEXT_CONSTANTS)


func _get_active_item_paddle_scale(registry: Object) -> float:
	return owner_syncer.get_active_item_paddle_scale(self, registry)


func _clamp_synced_player_x(x: float, paddle_width: float, warp_gate_state: Object) -> float:
	return owner_syncer.clamp_synced_player_x(x, paddle_width, warp_gate_state, FIELD_WIDTH)


func _sync_skill_cooldown_to_configs(registry: Object) -> void:
	owner_syncer.sync_skill_cooldown_to_configs(self, registry)


func _cleanup_removed_player_skills(registry: Object, removed_skills: Array) -> void:
	owner_syncer.cleanup_removed_player_skills(self, registry, removed_skills)


func _sync_dash_token_capacity(registry: Object) -> void:
	owner_syncer.sync_dash_token_capacity(self, registry)


func _sync_player_status_resistance_to_movement(registry: Object) -> void:
	owner_syncer.sync_player_status_resistance_to_movement(self, registry)


func _sync_gold_digger_to_runtime_perk_state(registry: Object) -> void:
	owner_syncer.sync_gold_digger_to_runtime_perk_state(self, registry)


func _sync_runtime_perk_state_ref(registry: Object) -> void:
	owner_syncer.sync_runtime_perk_state_ref(self, registry)


func _get_polish_multiplier(item_name: String = "") -> float:
	if runtime_perk_state_ref == null or not is_instance_valid(runtime_perk_state_ref):
		return 1.0
	var method_name := "get_base_polish_multiplier" if item_name == "transcendent_crown" else "get_effective_polish_multiplier"
	if not runtime_perk_state_ref.has_method(method_name):
		return 1.0
	return max(0.0, float(runtime_perk_state_ref.call(method_name)))


func _sync_item_perk_level_bonus_to_runtime_perk_state(owner: Object, registry: Object) -> void:
	owner_syncer.sync_item_perk_level_bonus_to_runtime_perk_state(self, owner, registry)


func _rebuild_equipped_items() -> void:
	equipment_index.rebuild_equipped_items(self, CONTEXT_CONSTANTS)


func _is_single_equipment_item(item_name: String) -> bool:
	return equipment_index.is_single_equipment_item(item_name, CONTEXT_CONSTANTS)


func _find_inventory_index_by_name(item_name: String) -> int:
	return equipment_index.find_inventory_index_by_name(self, item_name)


func _find_equipped_inventory_index_by_name(item_name: String) -> int:
	return equipment_index.find_equipped_inventory_index_by_name(self, item_name)


func _find_equipped_inventory_index_by_slot(slot_key: String) -> int:
	return equipment_index.find_equipped_inventory_index_by_slot(self, slot_key)


func _resolve_equipment_slot_key(item_data: Dictionary, owner: Object) -> String:
	return equipment_index.resolve_equipment_slot_key(self, item_data, owner, CONTEXT_CONSTANTS)


func _canonical_equipment_slot_key(slot_key: String) -> String:
	match slot_key:
		"back", "등":
			return "belt2"
		"torso":
			return "top"
		_:
			return slot_key


func _apply_roll_overrides(index: int, roll_overrides: Dictionary) -> void:
	roll_query.apply_roll_overrides(self, index, roll_overrides)


func _has_acquired_quality_identity(item_data: Dictionary) -> bool:
	return roll_query.has_acquired_quality_identity(item_data)


func _copy_acquired_quality_identity(target: Dictionary, source: Dictionary) -> Dictionary:
	return roll_query.copy_acquired_quality_identity(target, source)


func _find_roll_option(item_data: Dictionary, option_key: String) -> Dictionary:
	return roll_query.find_roll_option(self, item_data, option_key)


func _is_equipment_slot_enabled(slot_key: String, owner: Object) -> bool:
	return equipment_index.is_equipment_slot_enabled(self, slot_key, owner)


func _play_pickup_audio(registry: Object) -> void:
	audio_router.play_pickup_audio(self, registry)


func _try_grant_reinforced_boomerang_pickup_bonus(item_name: String, owner: Object, registry: Object) -> bool:
	return pickup_bonus.try_grant_reinforced_boomerang_pickup_bonus(
		self,
		item_name,
		owner,
		registry,
		ITEM_REINFORCED_BOOMERANG_GAUNTLET,
		ITEM_BOOMERANG
	)


func _build_reinforced_boomerang_bonus_item(registry: Object) -> Dictionary:
	return pickup_bonus.build_reinforced_boomerang_bonus_item(self, registry, ITEM_BOOMERANG)


func _get_active_item_slot_controller(registry: Object) -> Object:
	return pickup_bonus.get_active_item_slot_controller(self, registry)


func _play_equipment_audio(registry: Object) -> void:
	audio_router.play_equipment_audio(self, registry)


func _play_activation_audio(registry: Object) -> void:
	audio_router.play_activation_audio(self, registry)


func _play_venom_mist_poison_audio(registry: Object) -> void:
	audio_router.play_venom_mist_poison_audio(self, registry)


func _play_venom_mist_spawn_audio(registry: Object) -> void:
	audio_router.play_venom_mist_spawn_audio(self, registry)


func _play_rainbow_fur_glove_audio(registry: Object) -> void:
	audio_router.play_rainbow_fur_glove_audio(self, registry)


func _play_adversity_armor_activate_audio(registry: Object) -> void:
	audio_router.play_adversity_armor_activate_audio(self, registry)


func _play_adversity_armor_reflect_audio(registry: Object, impact_speed: float) -> void:
	audio_router.play_adversity_armor_reflect_audio(self, registry, impact_speed)

func _play_shrapnel_armor_fire_audio(registry: Object) -> void:
	audio_router.play_shrapnel_armor_fire_audio(self, registry)


func _play_shrapnel_armor_hit_audio(registry: Object) -> void:
	audio_router.play_shrapnel_armor_hit_audio(self, registry)


func _is_stage2_speed_defense_context_immune(context: Dictionary, deps: Dictionary = {}) -> bool:
	return stage_immunity.is_stage2_speed_defense_context_immune(self, context, deps)


func _is_stage2_speed_defense_boss_immune(registry: Object) -> bool:
	return stage_immunity.is_stage2_speed_defense_boss_immune(self, registry)


func _activation_elapsed() -> float:
	return float(Time.get_ticks_msec() - activation_started_msec) / 1000.0


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _should_use_acquisition_cinematic(item_data: Dictionary) -> bool:
	return MythicItemAcquisitionCinematicV2.should_use_item_data(item_data)


func _resolve_acquisition_player_center(owner: Object) -> Vector2:
	return MythicItemAcquisitionCinematicV2.resolve_player_center(owner, CONTEXT_CONSTANTS)


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
