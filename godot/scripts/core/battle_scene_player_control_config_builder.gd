extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const ViperHoverSheetOverride := preload("res://scripts/core/viper_hover_sheet_override.gd")

const BOSS_PADDLE_WIDTH := 100.0
const BOSS_HITBOX_HEIGHT := 40.0
const STAGE1_BOSS_VISUAL_CENTER_Y_OFFSET := 25.0
const STAGE2_BOSS_VISUAL_CENTER_Y_OFFSET := 31.0
const STAGE3_BOSS_VISUAL_CENTER_Y_OFFSET := 31.0
const STAGE4_BOSS_VISUAL_CENTER_Y_OFFSET := 34.0

const MOVEMENT_SPEED_KEYS := [
	"paddle_speed",
	"paddle_max_speed",
	"paddle_accel",
	"paddle_decel",
	"paddle_turn_decel",
]

var character_runtime: Object = PlayerCharacterRuntime.new()
var fallback_scene_config: Object = BattleSceneConfig.new()


func build_config(owner: Object, registry: Object, character_type: String, context_builder: Object) -> Dictionary:
	if owner == null or context_builder == null or not context_builder.has_method("build_player_control_config"):
		return {}

	var normalized_character_type: String = character_runtime.normalize(character_type)
	var config: Dictionary = context_builder.build_player_control_config(normalized_character_type)
	config["selected_character_type"] = normalized_character_type
	if normalized_character_type == PlayerCharacterRuntime.OPTIMUS:
		var optimus_paddle_base_scale: float = _get_league_player_paddle_scale(owner, registry)
		config["optimus_paddle_base_scale"] = optimus_paddle_base_scale
		var previous_paddle_size := Vector2(
			max(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
			max(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
		)
		var optimus_energy_state: Object = _get_instance(registry, "optimus_energy_state")
		var optimus_snapshot: Dictionary = {}
		if optimus_energy_state != null and optimus_energy_state.has_method("prepare_owner_runtime_base_for_optimus"):
			optimus_snapshot = optimus_energy_state.prepare_owner_runtime_base_for_optimus(
				owner,
				optimus_paddle_base_scale
			)
		elif optimus_energy_state != null and optimus_energy_state.has_method("prepare_owner_for_optimus"):
			optimus_snapshot = optimus_energy_state.prepare_owner_for_optimus(owner)
		if not optimus_snapshot.is_empty():
			for key in optimus_snapshot.keys():
				owner.set(str(key), optimus_snapshot[key])
		_align_optimus_paddle(owner, previous_paddle_size)
	var paddle_width: float = float(_get_owner_value(owner, "player_paddle_width", config.get("paddle_width", 155.0)))
	config["paddle_width"] = max(1.0, paddle_width)

	var paddle_height: float = float(_get_owner_value(owner, "player_paddle_height", 50.0))
	config["paddle_height"] = max(1.0, paddle_height)
	config["special_gauge"] = float(_get_owner_value(owner, "special_gauge", 0.0))
	# 승리 전리품 페이즈는 update_player_control만 돌고 update_ball은 동결한다
	# (battle_frame_flow_controller의 loot 분기). 매치 종료 득점은 reset_ball을
	# 거치지 않으므로 마지막 랠리의 ball_active=true가 그대로 살아 있고, 그 창에서
	# 공-패스로만 전진하는 플레이어 스킬이 발동하면 영원히 진행되지 않는다
	# (회천비륜 WIND_UP 이동잠금 -> 상자 픽업 불가 = 전리품 페이즈 소프트락).
	# 공 게이트를 페이즈 플래그와 함께 닫아 공-의존 스킬의 신규 발동을 차단한다.
	config["ball_active"] = (
		bool(_get_owner_value(owner, "ball_active", false))
		and not bool(_get_owner_value(owner, "victory_loot_phase_active", false))
		and not bool(_get_owner_value(owner, "victory_highlight_active", false))
	)
	config["ball_pos"] = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	config["ball_vel"] = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	config["ball_size"] = max(1.0, float(_get_owner_value(owner, "ball_size", 28.6)))
	config["ball_impact_boost"] = float(_get_owner_value(owner, "ball_impact_boost", 1.0))
	config["boss_pos"] = _get_owner_vector2(owner, "boss_pos", Vector2.ZERO)
	config["boss_paddle_width"] = max(1.0, float(_get_owner_value(owner, "boss_paddle_width", BOSS_PADDLE_WIDTH)))
	config["boss_hitbox_height"] = max(1.0, float(_get_owner_value(owner, "boss_hitbox_height", BOSS_HITBOX_HEIGHT)))
	config["width"] = 760.0
	config["height"] = 750.0
	config["current_stage"] = max(1, int(_get_owner_value(owner, "current_stage", 1)))
	config["boss_visual_center_y_offset"] = _get_boss_visual_center_y_offset(int(config["current_stage"]))
	config["gauge_max"] = float(_get_owner_value(owner, "special_gauge_max", 500.0))
	config["player_floor_y"] = 750.0 - paddle_height
	if normalized_character_type == PlayerCharacterRuntime.VIPER:
		var textures: Dictionary = BattleSceneOwnerReader.get_dictionary(owner, "battle_textures")
		var hover_sheet_loaded: bool = (
			textures.get("viper_player_hover_left_sheet", null) is Texture2D
			or textures.get("viper_player_hover_right_sheet", null) is Texture2D
		)
		config["viper_jetpack_hover_sheet_fx"] = hover_sheet_loaded and not ViperHoverSheetOverride.is_hover_sheet_force_disabled()

	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_player_movement_config"):
		# Horn's transformed speed is a replacement BASE (8), not a final fixed
		# value. Apply it before the shared multiplier chain so Angel/Swiftness,
		# weather, statuses, active items, Lingpet, and mythic modifiers survive.
		mythic_item_runtime.apply_player_movement_config(config)
	var horn_strawberry_transformed: bool = _is_horn_strawberry_transformed(mythic_item_runtime)
	config["horn_strawberry_transformed"] = horn_strawberry_transformed
	config["horn_strawberry_skill_input_locked"] = _is_horn_strawberry_skill_input_locked(mythic_item_runtime)
	_apply_speed_multiplier(config, _get_instance(registry, "runtime_perk_state"))
	if normalized_character_type == PlayerCharacterRuntime.SMASHER and not horn_strawberry_transformed:
		_apply_speed_multiplier(config, _get_instance(registry, "smasher_recovery_state"))
	var weather: Object = _get_instance(registry, "weather_event_state")
	if weather != null and weather.has_method("apply_player_movement_config"):
		weather.apply_player_movement_config(config)
	_apply_speed_multiplier(config, weather)
	_apply_speed_multiplier(config, _get_instance(registry, "status_effect_state"))
	_apply_speed_multiplier(config, _get_instance(registry, "active_item_runtime"))
	_apply_speed_multiplier(config, _get_instance(registry, "lingpet_egg_runtime"))
	_apply_speed_multiplier(config, mythic_item_runtime)
	_apply_turn_decel_multiplier(config, mythic_item_runtime)
	if mythic_item_runtime != null:
		config["player_skill_input_locked"] = _is_player_skill_locked(mythic_item_runtime)
		if (
			mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
			and bool(mythic_item_runtime.is_horn_strawberry_control_locked())
		):
			config["horizontal_input_locked"] = true
		if (
			mythic_item_runtime.has_method("is_odins_eye_control_locked")
			and bool(mythic_item_runtime.is_odins_eye_control_locked())
		):
			config["horizontal_input_locked"] = true
	return config


func _apply_speed_multiplier(config: Dictionary, source: Object) -> void:
	if source == null or not source.has_method("get_player_speed_multiplier"):
		return
	var speed_multiplier: float = max(0.0, float(source.get_player_speed_multiplier()))
	if abs(speed_multiplier - 1.0) <= 0.001:
		return
	for key in MOVEMENT_SPEED_KEYS:
		if config.has(key):
			config[key] = float(config[key]) * speed_multiplier


func _apply_turn_decel_multiplier(config: Dictionary, source: Object) -> void:
	if source == null or not source.has_method("get_player_turn_decel_multiplier"):
		return
	if not config.has("paddle_turn_decel"):
		return
	var turn_decel_multiplier: float = max(0.0, float(source.get_player_turn_decel_multiplier()))
	if abs(turn_decel_multiplier - 1.0) <= 0.001:
		return
	config["paddle_turn_decel"] = float(config["paddle_turn_decel"]) * turn_decel_multiplier


func _get_boss_visual_center_y_offset(current_stage: int) -> float:
	match current_stage:
		1:
			return STAGE1_BOSS_VISUAL_CENTER_Y_OFFSET
		2:
			return STAGE2_BOSS_VISUAL_CENTER_Y_OFFSET
		3:
			return STAGE3_BOSS_VISUAL_CENTER_Y_OFFSET
		4:
			return STAGE4_BOSS_VISUAL_CENTER_Y_OFFSET
	return 0.0


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_league_player_paddle_scale(owner: Object, registry: Object) -> float:
	var scene_config: Object = _get_instance(registry, "battle_scene_config")
	if scene_config == null:
		scene_config = fallback_scene_config
	if scene_config != null and scene_config.has_method("get_league_player_paddle_scale"):
		return maxf(0.1, float(scene_config.get_league_player_paddle_scale(owner)))
	return 1.0


func _is_player_skill_locked(mythic_item_runtime: Object) -> bool:
	if mythic_item_runtime == null:
		return false
	if (
		mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_skills_locked())
	):
		return true
	if (
		mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_control_locked())
	):
		return true
	if (
		mythic_item_runtime.has_method("is_odins_eye_skills_locked")
		and bool(mythic_item_runtime.is_odins_eye_skills_locked())
	):
		return true
	if (
		mythic_item_runtime.has_method("is_odins_eye_control_locked")
		and bool(mythic_item_runtime.is_odins_eye_control_locked())
	):
		return true
	return false


func _is_horn_strawberry_transformed(mythic_item_runtime: Object) -> bool:
	return (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_transformed")
		and bool(mythic_item_runtime.is_horn_strawberry_transformed())
	)


func _is_horn_strawberry_skill_input_locked(mythic_item_runtime: Object) -> bool:
	return (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_skills_locked())
	)


func _align_optimus_paddle(owner: Object, previous_paddle_size: Vector2) -> void:
	var next_width: float = max(1.0, float(_get_owner_value(owner, "player_paddle_width", previous_paddle_size.x)))
	var next_height: float = max(1.0, float(_get_owner_value(owner, "player_paddle_height", previous_paddle_size.y)))
	if is_equal_approx(previous_paddle_size.x, next_width) and is_equal_approx(previous_paddle_size.y, next_height):
		return
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(760.0 * 0.5 - previous_paddle_size.x * 0.5, 750.0 - previous_paddle_size.y))
	var center_x: float = player_pos.x + previous_paddle_size.x * 0.5
	player_pos.x = clamp(center_x - next_width * 0.5, 0.0, max(0.0, 760.0 - next_width))
	player_pos.y = 750.0 - next_height
	owner.set("player_pos", player_pos)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)
