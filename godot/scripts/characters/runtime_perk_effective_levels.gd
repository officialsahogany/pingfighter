extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const VIPER_IGNITION_AURA_LEVEL_BONUS := 2
const ITEM_CAFFEINE_ID := "item_caffeine"
const ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL := RuntimePerkProgression.ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL
const ITEM_POLISH_ID := "item_polish"
const ITEM_POLISH_ROLL_BONUS_PER_LEVEL := RuntimePerkProgression.ITEM_POLISH_ROLL_BONUS_PER_LEVEL
const PERK_POLISH_AMPLIFY_PER_LEVEL := RuntimePerkProgression.PERK_POLISH_AMPLIFY_PER_LEVEL
const TRAINING_MASTERY_ID := "training_mastery"
const TRAINING_MASTERY_AMPLIFY_PER_LEVEL := RuntimePerkProgression.TRAINING_MASTERY_AMPLIFY_PER_LEVEL
const ITEM_RECYCLE_ID := "item_recycle"
const ITEM_RECYCLE_CHANCE_PER_LEVEL := RuntimePerkProgression.ITEM_RECYCLE_CHANCE_PER_LEVEL
const MAX_ITEM_RECYCLE_CHANCE := RuntimePerkProgression.MAX_ITEM_RECYCLE_CHANCE
const PERK_LAUREL_SHIELD_ID := "perk_laurel_shield"
const SLOT_EXPANSION_PERK_ID := "common_expansion"
const DASH_ACCELERATION_ID := "dash_acceleration"
const DASH_ACCELERATION_BONUS_PER_LEVEL := RuntimePerkProgression.DASH_ACCELERATION_BONUS_PER_LEVEL
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const BASE_ACTIVE_ITEM_SLOT_LIMIT := 3
const MIN_DASH_RECHARGE_FRAMES := 6.0
const MIN_DASH_RECOVERY_FRAMES := 1.0
const MIN_ITEM_SPAWN_DELAY_MSEC := 1
const DOWNTOWN_TREASURE_MAP_ID := "downtown_treasure_map"
const TREASURE_MAP_MYTHIC_BONUS_PER_LEVEL := RuntimePerkProgression.TREASURE_MAP_MYTHIC_BONUS_PER_LEVEL
const TREASURE_MAP_VISION_BOX_CHANCE_BONUS_PER_LEVEL := RuntimePerkProgression.TREASURE_MAP_VISION_BOX_CHANCE_BONUS_PER_LEVEL
const PERK_POLISH_AMPLIFIABLE_BONUS_IDS := {
	"dash_lightweight": true,
	"dash_module_control": true,
	"dash_jump": true,
	DASH_ACCELERATION_ID: true,
	"dash_spirit": true,
	"item_luck": true,
	"item_cooldown_mastery": true,
	"item_gauge_mastery": true,
	ITEM_CAFFEINE_ID: true,
	"common_swiftness": true,
	"common_bulk_up": true,
	TRAINING_MASTERY_ID: true,
	"common_training": true,
	"perk_boost_charge": true,
}
const VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS := {
	"unlock_magnum_grip": true,
	"unlock_plasma": true,
	"unlock_recovery": true,
	"unlock_cleanse": true,
	"unlock_shield_kiting": true,
	"unlock_ghost_shot": true,
	"unlock_warp_gate": true,
	"unlock_smasher_wheel": true,
	"unlock_smasher_overdrive": true,
	"unlock_void_phantom": true,
	"unlock_nerve_strike": true,
	"unlock_dive_strike": true,
	"unlock_chaos_spear": true,
	"unlock_dual_glitch": true,
	"unlock_ignition_aura": true,
	"double_marshal_kick": true,
	"core_flip": true,
	"dark_blade": true,
	"common_refresh": true,
	"star_change": true,
	"sage_ring": true,
}
# 슬롯-코스트 커플링 퍽: 레벨당 무공 슬롯 1개를 소모(레벨 = 슬롯 = 글라이드 1개). 무상 레벨
# 보너스(초월자의 관 · 세이지링 · 바이퍼 점화오라)가 이 퍽의 effective level을 올리면 슬롯을
# 내지 않고 글라이드가 공짜로 늘어나 슬롯-코스트 계약이 깨진다 — 모든 무상 레벨부스트에서 제외.
const SLOT_COST_COUPLED_LEVEL_BONUS_EXCLUDED_IDS := {
	"dash_amplification": true,
}


func get_viper_ignition_aura_level_bonus(viper_ignition_aura_active: bool) -> int:
	return VIPER_IGNITION_AURA_LEVEL_BONUS if viper_ignition_aura_active else 0


func build_viper_ignition_aura_active_update(current_active: bool, next_active: bool) -> Dictionary:
	return {
		"changed": current_active != next_active,
		"active": next_active,
		"owner_sync_dirty": current_active != next_active,
	}


func apply_viper_ignition_aura_active_update(runtime_state: Object, update: Dictionary) -> Dictionary:
	if runtime_state == null or not bool(update.get("changed", false)):
		return {"accepted": false}
	runtime_state.set(
		"viper_ignition_aura_active",
		bool(update.get("active", RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")))
	)
	runtime_state.set(
		"viper_ignition_aura_owner_sync_dirty",
		bool(update.get("owner_sync_dirty", true))
	)
	return {
		"accepted": true,
		"active": bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")),
		"owner_sync_dirty": bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_owner_sync_dirty")),
	}


func build_item_perk_level_bonus_update(current_bonus: int, bonus: int) -> Dictionary:
	var next_bonus: int = max(0, int(bonus))
	return {
		"changed": current_bonus != next_bonus,
		"bonus": next_bonus,
	}


func apply_item_perk_level_bonus_update(runtime_state: Object, update: Dictionary) -> Dictionary:
	if runtime_state == null or not bool(update.get("changed", false)):
		return {"accepted": false}
	runtime_state.set(
		"item_perk_level_bonus",
		int(update.get("bonus", RuntimePerkRuntimeStateAccess.get_int(runtime_state, "item_perk_level_bonus")))
	)
	return {
		"accepted": true,
		"bonus": int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "item_perk_level_bonus")),
	}


func build_dynamic_effect_refresh_plan(has_owner: bool, clear_owner_sync_dirty: bool = false) -> Dictionary:
	return {
		"sync_owner_effects": has_owner,
		"apply_training": not has_owner,
		"refresh_consumers": true,
		"clear_owner_sync_dirty": has_owner and clear_owner_sync_dirty,
	}


func build_dirty_owner_sync_refresh_plan(is_dirty: bool, has_owner: bool) -> Dictionary:
	return {
		"sync_owner_effects": is_dirty and has_owner,
		"apply_training": is_dirty and not has_owner,
		"refresh_consumers": is_dirty and has_owner,
		"clear_owner_sync_dirty": is_dirty and has_owner,
	}


func apply_dynamic_effect_refresh_state_update(runtime_state: Object, plan: Dictionary) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	if bool(plan.get("clear_owner_sync_dirty", false)):
		runtime_state.set("viper_ignition_aura_owner_sync_dirty", false)
	return {
		"accepted": true,
		"clear_owner_sync_dirty": bool(plan.get("clear_owner_sync_dirty", false)),
	}


func is_runtime_level_bonus_eligible(skill_id: String, base_level: int) -> bool:
	if base_level <= 0:
		return false
	var clean_id: String = skill_id.strip_edges()
	if clean_id == "" or clean_id.begins_with("instant_"):
		return false
	if PerkConversionFlags.is_enabled() and clean_id == SLOT_EXPANSION_PERK_ID:
		return false
	if bool(SLOT_COST_COUPLED_LEVEL_BONUS_EXCLUDED_IDS.get(clean_id, false)):
		return false
	return not bool(VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS.get(clean_id, false))


func is_ignition_aura_level_bonus_eligible(
	viper_ignition_aura_active: bool,
	skill_id: String,
	base_level: int
) -> bool:
	return viper_ignition_aura_active and is_runtime_level_bonus_eligible(skill_id, base_level)


func get_runtime_skill_level(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	skill_id: String
) -> int:
	var clean_id: String = skill_id.strip_edges()
	if PerkConversionValues.is_retired_converted_perk_id(clean_id):
		return 0
	var base_level: int = int(runtime_skill_levels.get(clean_id, 0))
	if is_runtime_level_bonus_eligible(clean_id, base_level):
		return base_level + item_perk_level_bonus + get_viper_ignition_aura_level_bonus(viper_ignition_aura_active)
	return base_level


func get_converted_perk_effect_level(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	perk_id: String
) -> int:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "" or PerkConversionValues.is_retired_converted_perk_id(clean_id):
		return 0
	var base_level: int = int(runtime_skill_levels.get(clean_id, 0))
	var bonus := 0
	if is_runtime_level_bonus_eligible(clean_id, base_level):
		bonus = item_perk_level_bonus + get_viper_ignition_aura_level_bonus(viper_ignition_aura_active)
	return PerkConversionValues.get_effective_converted_perk_level(clean_id, base_level, bonus)


func get_effective_runtime_skill_levels(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> Dictionary:
	var effective_levels: Dictionary = {}
	for skill_id_value in runtime_skill_levels.keys():
		var skill_id: String = str(skill_id_value)
		if PerkConversionValues.is_retired_converted_perk_id(skill_id):
			continue
		var base_level: int = int(runtime_skill_levels.get(skill_id_value, 0))
		if base_level > 0:
			effective_levels[skill_id] = get_runtime_skill_level(
				runtime_skill_levels,
				item_perk_level_bonus,
				viper_ignition_aura_active,
				skill_id
			)
	return effective_levels


func get_runtime_skill_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	skill_id: String
) -> float:
	var clean_id: String = skill_id.strip_edges()
	var level: int = get_runtime_skill_level(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		clean_id
	)
	var base_bonus := 0.0
	if RuntimePerkProgression.has_primary_runtime_bonus(clean_id):
		base_bonus = RuntimePerkProgression.get_primary_runtime_bonus(clean_id, level)
	else:
		# Compatibility-only lanes outside the 37-perk S2 owner: ten migrated
		# Training ids and the existing max-level 3/4 perks remain untouched.
		match clean_id:
			"dash_lightweight":
				base_bonus = float(level) * 0.12
			"dash_module_control":
				base_bonus = float(level) * 0.18
			"dash_jump":
				base_bonus = float(level) * 0.07
			"dash_amplification":
				base_bonus = float(level)
			"item_cooldown_mastery":
				base_bonus = float(level) * 0.13
			"common_swiftness":
				base_bonus = float(level) * 0.06
			SLOT_EXPANSION_PERK_ID:
				base_bonus = 0.0 if PerkConversionFlags.is_enabled() else float(level)
			"common_bulk_up":
				base_bonus = float(level) * 0.06
			"common_training":
				base_bonus = float(level) * 0.08
	return base_bonus * get_perk_amplify_multiplier(runtime_skill_levels, clean_id)


func get_perk_amplify_multiplier(runtime_skill_levels: Dictionary, skill_id: String) -> float:
	if not PerkConversionFlags.is_enabled():
		return 1.0
	var clean_id: String = skill_id.strip_edges()
	if not is_polish_amplifiable_perk_id(clean_id):
		return 1.0
	var polish_level: int = max(0, int(runtime_skill_levels.get(ITEM_POLISH_ID, 0)))
	if polish_level <= 0:
		return 1.0
	return 1.0 + RuntimePerkProgression.get_value(ITEM_POLISH_ID, "general_amplify", polish_level)


static func is_polish_amplifiable_perk_id(skill_id: String) -> bool:
	var clean_id := skill_id.strip_edges()
	return (
		bool(PERK_POLISH_AMPLIFIABLE_BONUS_IDS.get(clean_id, false))
		or PerkConversionValues.has_polish_amplifiable_option(clean_id)
	)


func get_combo_amplifier_chip_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> Dictionary:
	var level: int = get_runtime_skill_level(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		"combo_amplifier_chip"
	)
	if level <= 0:
		return {"drive_speed": 0.0, "drive_curve": 0.0, "smash_speed": 0.0}
	return {
		"drive_speed": RuntimePerkProgression.get_value("combo_amplifier_chip", "drive_speed_bonus", level),
		"smash_speed": RuntimePerkProgression.get_value("combo_amplifier_chip", "smash_speed_bonus", level),
		"drive_curve": RuntimePerkProgression.get_value("combo_amplifier_chip", "drive_curve_bonus", level),
	}


func get_dash_recharge_frames(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_frames: float
) -> float:
	return max(
		MIN_DASH_RECHARGE_FRAMES,
		float(base_frames) * max(0.0, 1.0 - get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"dash_lightweight"
		))
	)


func get_dash_recovery_frames(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_frames: float
) -> float:
	return max(
		MIN_DASH_RECOVERY_FRAMES,
		float(base_frames) * max(0.0, 1.0 - get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"dash_module_control"
		))
	)


func get_dash_duration_frames(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_frames: float
) -> float:
	return max(
		1.0,
		float(base_frames) * (1.0 + get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"dash_jump"
		))
	)


func get_item_spawn_delay_msec(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_delay_msec: int
) -> int:
	var adjusted: float = float(max(0, base_delay_msec)) * max(0.0, 1.0 - get_runtime_skill_bonus(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		"item_luck"
	))
	return max(MIN_ITEM_SPAWN_DELAY_MSEC, int(round(adjusted)))


func get_active_item_cooldown_msec(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_cooldown_msec: int
) -> int:
	var adjusted: float = float(max(0, base_cooldown_msec)) * max(0.0, 1.0 - get_runtime_skill_bonus(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		"item_cooldown_mastery"
	))
	return max(0, int(round(adjusted)))


func get_active_item_use_gauge_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.0,
		get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"item_gauge_mastery"
		)
	)


func get_active_item_slot_capacity(
	_runtime_skill_levels: Dictionary,
	_item_perk_level_bonus: int,
	_viper_ignition_aura_active: bool,
	base_slots: int = BASE_ACTIVE_ITEM_SLOT_LIMIT
) -> int:
	return maxi(1, base_slots)


func get_active_item_duration_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.0,
		get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			ITEM_CAFFEINE_ID
		)
	)


func get_active_item_duration_multiplier(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(0.0, 1.0 + get_active_item_duration_bonus(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active
	))


func get_active_item_duration_frames(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_duration_frames: float
) -> float:
	if base_duration_frames <= 0.0:
		return 0.0
	return max(
		1.0,
		float(int(base_duration_frames * get_active_item_duration_multiplier(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active
		)))
	)


func get_active_item_recycle_chance(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return clamp(
		get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			ITEM_RECYCLE_ID
		),
		0.0,
		MAX_ITEM_RECYCLE_CHANCE
	)


func get_effective_polish_multiplier(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.0,
		1.0 + get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			ITEM_POLISH_ID
		)
	)


func get_downtown_treasure_map_mythic_multiplier(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return 1.0 + get_downtown_treasure_map_mythic_bonus(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active
	)


func get_downtown_treasure_map_vision_box_chance(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_chance: float
) -> float:
	return clamp(
		float(base_chance) + get_downtown_treasure_map_vision_box_chance_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active
		),
		0.0,
		1.0
	)


func get_player_speed_multiplier(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.0,
		1.0 + get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"common_swiftness"
		)
	)


func get_player_paddle_size_multiplier(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.1,
		1.0 + get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"common_bulk_up"
		)
	)


func get_accessory_slot_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> int:
	return max(
		0,
		int(get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			SLOT_EXPANSION_PERK_ID
		))
	)


func get_player_skill_cooldown_multiplier(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.0,
		1.0 - get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"common_training"
		)
	)


func get_player_skill_cooldown_seconds(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_cooldown_seconds: float
) -> float:
	return max(
		0.0,
		float(base_cooldown_seconds) * get_player_skill_cooldown_multiplier(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active
		)
	)


func get_boost_charge_chance_pct(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.0,
		get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			"perk_boost_charge"
		)
	)


func get_dash_acceleration_level(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> int:
	return max(0, get_runtime_skill_level(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		DASH_ACCELERATION_ID
	))


func get_dash_acceleration_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	return max(
		0.0,
		get_runtime_skill_bonus(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			DASH_ACCELERATION_ID
		)
	)


func get_dash_acceleration_height_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	base_height: float = PLAYER_BASE_PADDLE_HEIGHT
) -> float:
	return max(0.0, float(base_height)) * get_dash_acceleration_bonus(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active
	)


func get_laurel_leaf_count(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool,
	sacred_laurel_leaf_bonus: int = 0
) -> int:
	var level: int = max(0, int(get_runtime_skill_level(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		PERK_LAUREL_SHIELD_ID
	)))
	return RuntimePerkProgression.get_int_value(PERK_LAUREL_SHIELD_ID, "leaf_count", level) + max(0, sacred_laurel_leaf_bonus)


func get_downtown_treasure_map_mythic_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	var level := get_runtime_skill_level(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		DOWNTOWN_TREASURE_MAP_ID
	)
	return max(0.0, RuntimePerkProgression.get_value(DOWNTOWN_TREASURE_MAP_ID, "mythic_offer_bonus", level))


func get_downtown_treasure_map_vision_box_chance_bonus(
	runtime_skill_levels: Dictionary,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> float:
	var level := get_runtime_skill_level(
		runtime_skill_levels,
		item_perk_level_bonus,
		viper_ignition_aura_active,
		DOWNTOWN_TREASURE_MAP_ID
	)
	return max(0.0, RuntimePerkProgression.get_value(DOWNTOWN_TREASURE_MAP_ID, "vision_box_chance_bonus", level))


func get_base_polish_multiplier(runtime_skill_levels: Dictionary) -> float:
	var base_level: int = max(0, int(runtime_skill_levels.get(ITEM_POLISH_ID, 0)))
	return max(0.0, 1.0 + RuntimePerkProgression.get_value(ITEM_POLISH_ID, "mythic_roll_bonus", base_level))
