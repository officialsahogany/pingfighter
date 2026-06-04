extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const WIDTH: float = 760.0
const PLAY_LEFT: float = 0.0
const PLAY_RIGHT: float = WIDTH
const PADDLE_WIDTH: float = 155.0
const BOSS_PADDLE_WIDTH: float = 100.0
const MYTHIC_BOSS_PADDLE_SCALE: float = 1.15
const BALL_SIZE: float = 28.6
const BOSS_Y: float = 25.0
const BOSS_HITBOX_HEIGHT: float = 40.0
const HITBOX_PADDING: float = 5.0
const DEFAULT_BOSS_MISTAKE_CHANCE: float = 0.10
const STAGE2_BOSS_MISTAKE_CHANCE: float = 0.09
const STAGE3_MENHERA_MISTAKE_CHANCE: float = 0.08
const STAGE4_PONK_MISTAKE_CHANCE: float = 0.07
const JUNIOR_DEFAULT_BOSS_MISTAKE_CHANCE: float = 0.15
const JUNIOR_STAGE1_DALJI_BOSS_MISTAKE_CHANCE: float = 0.20
const JUNIOR_BOSS_MISTAKE_STAGE_RATE: float = 0.01
const DEFAULT_BOSS_MISTAKE_ERROR_MIN: float = 78.0
const DEFAULT_BOSS_MISTAKE_ERROR_MAX: float = 140.0
const DEFAULT_BOSS_MISTAKE_SPEED_SCALE: float = 4.5
const MYTHIC_BOSS_MISTAKE_CHANCE: float = 0.005
const MYTHIC_BOSS_MISTAKE_ERROR_MIN: float = 0.0
const MYTHIC_BOSS_MISTAKE_ERROR_MAX: float = 20.0
const MYTHIC_BOSS_MISTAKE_SPEED_SCALE: float = 4.5
const BASE_BOSS_ACCEL: float = 0.798
const BASE_BOSS_DECEL: float = 0.798
const BASE_BOSS_MAX_SPEED: float = 6.3175
const BASE_BOSS_DASH_MAX_DISTANCE: float = 316.8
const BASE_BOSS_DASH_COOLDOWN_MIN_SECONDS: float = 40.0
const BASE_BOSS_DASH_COOLDOWN_MAX_SECONDS: float = 55.0
const CHAMPION_BOSS_SPEED_MULTIPLIER: float = 1.5
const JUNIOR_BOSS_MOVEMENT_MULTIPLIER: float = 0.90
const MYTHIC_BOSS_MOVEMENT_MULTIPLIER: float = 1.2307692308
const DEFAULT_BOSS_DASH_TRIGGER_CHANCE: float = 0.30
const MYTHIC_BOSS_DASH_TRIGGER_CHANCE: float = 1.0
const DEFAULT_BOSS_DASH_MAX_TOKENS: int = 1
const MYTHIC_BOSS_DASH_MAX_TOKENS: int = 2
const MYTHIC_STAGE5_BOSS_DASH_MAX_TOKENS: int = 3
const BOSS_STAGE_SPEED_RATE: float = 0.03
const BOSS_STAGE_SPEED_CAP: float = 0.50
const BOSS_DASH_DISTANCE_STAGE_RATE: float = 0.05
const BOSS_DASH_COOLDOWN_STAGE_RATE: float = 0.05
const BOSS_DASH_COOLDOWN_MIN_MULTIPLIER: float = 0.20

var character_runtime: Object = PlayerCharacterRuntime.new()


func build_context(owner: Object, registry: Object) -> Dictionary:
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var context: Dictionary = _build_base_context(owner, registry, current_stage, character_type)
	_merge_shared_context(context, registry, character_type)
	_merge_stage_context(context, registry, current_stage)
	_merge_character_context(context, registry, character_type)
	return context


func _build_base_context(owner: Object, registry: Object, current_stage: int, character_type: String) -> Dictionary:
	var round_state: Object = _get_instance(registry, "round_flow_state")
	var power_state: Object = _get_instance(registry, "smasher_power_smash_state") if _is_smasher(character_type) else null
	var ai_mode: String = str(_get_owner_value(owner, "ai_mode", "champion"))
	var boss_movement_profile: Dictionary = _build_boss_movement_profile(current_stage, ai_mode)
	var boss_dash_profile: Dictionary = _build_boss_dash_profile(current_stage)
	var boss_mistake_profile: Dictionary = _build_boss_mistake_profile(current_stage, ai_mode)
	return {
		"width": WIDTH,
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"current_stage": current_stage,
		"ai_mode": ai_mode,
		"boss_paddle_width": _get_boss_paddle_width(owner, ai_mode),
		"boss_stage_speed_multiplier": boss_movement_profile["boss_stage_speed_multiplier"],
		"boss_league_movement_multiplier": boss_movement_profile["boss_league_movement_multiplier"],
		"boss_max_speed": boss_movement_profile["boss_max_speed"],
		"boss_movement_accel": boss_movement_profile["boss_movement_accel"],
		"boss_movement_decel": boss_movement_profile["boss_movement_decel"],
		"boss_movement_max_speed": boss_movement_profile["boss_movement_max_speed"],
		"boss_dash_enabled": _is_boss_dash_enabled(current_stage),
		"boss_dash_max_tokens": _get_boss_dash_max_tokens(ai_mode, current_stage),
		"boss_dash_stage_distance_multiplier": boss_dash_profile["boss_dash_stage_distance_multiplier"],
		"boss_dash_stage_cooldown_multiplier": boss_dash_profile["boss_dash_stage_cooldown_multiplier"],
		"boss_dash_max_distance": boss_dash_profile["boss_dash_max_distance"],
		"boss_dash_trigger_chance": _get_boss_dash_trigger_chance(ai_mode),
		"boss_dash_chain_enabled": _is_boss_dash_chain_enabled(ai_mode, current_stage),
		"boss_dash_chain_trigger_chance": _get_boss_dash_chain_trigger_chance(ai_mode),
		"boss_dash_cooldown_min_seconds": boss_dash_profile["boss_dash_cooldown_min_seconds"],
		"boss_dash_cooldown_max_seconds": boss_dash_profile["boss_dash_cooldown_max_seconds"],
		"boss_dash_stun_seconds": 0.60,
		"boss_mistake_chance": boss_mistake_profile["boss_mistake_chance"],
		"boss_mistake_error_min": boss_mistake_profile["boss_mistake_error_min"],
		"boss_mistake_error_max": boss_mistake_profile["boss_mistake_error_max"],
		"boss_mistake_speed_scale": boss_mistake_profile["boss_mistake_speed_scale"],
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"waiting_for_serve": _is_waiting_for_serve(round_state),
		"player_serves": _does_player_serve(round_state),
		"boss_serve_timer": _get_round_snapshot_float(round_state, "serve_timer", 0.0),
		"boss_serve_target_delay": _get_round_snapshot_float(round_state, "serve_delay", 1.0),
		"player_pos": _get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		"player_paddle_width": PADDLE_WIDTH,
		"ball_pos": _get_owner_vector2(owner, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_owner_vector2(owner, "ball_vel", Vector2.ZERO),
		"ball_impact_boost": float(_get_owner_value(owner, "ball_impact_boost", 1.0)),
		"ball_boost_decay_rate": float(_get_owner_value(owner, "ball_boost_decay_rate", 0.975)),
		"ball_min_boost": float(_get_owner_value(owner, "ball_min_boost", 0.70)),
		"ball_size": BALL_SIZE,
		"boss_y": BOSS_Y,
		"boss_hitbox_height": max(1.0, float(_get_owner_value(owner, "boss_hitbox_height", BOSS_HITBOX_HEIGHT))),
		"hitbox_padding": HITBOX_PADDING,
		"power_smashing_parabola_active": power_state != null and power_state.has_method("is_parabola_active") and power_state.is_parabola_active(),
		"power_smashing_combo_consumed": int(power_state.get_combo_consumed()) if power_state != null and power_state.has_method("get_combo_consumed") else 0,
		"audio": _get_instance(registry, "game_audio"),
	}


func _merge_shared_context(context: Dictionary, registry: Object, character_type: String) -> void:
	for key in [
		"active_item_runtime",
		"mythic_item_runtime",
	]:
		var source: Object = _get_instance(registry, key)
		if source != null and source.has_method("get_boss_ai_context"):
			context.merge(source.get_boss_ai_context(), true)
	if _is_smasher(character_type):
		var plasma_state: Object = _get_instance(registry, "smasher_plasma_state")
		if plasma_state != null and plasma_state.has_method("get_boss_ai_context"):
			context.merge(plasma_state.get_boss_ai_context(), true)
	var status_effect_state: Object = _get_instance(registry, "status_effect_state")
	if status_effect_state != null and status_effect_state.has_method("get_boss_ai_context"):
		context.merge(status_effect_state.get_boss_ai_context(), true)


func _merge_stage_context(context: Dictionary, registry: Object, current_stage: int) -> void:
	if current_stage == 1:
		var whip_state: Object = _get_instance(registry, "stage1_dalji_whip_skill_state")
		if whip_state != null and whip_state.has_method("get_ai_context"):
			context.merge(whip_state.get_ai_context(), true)
		return
	if current_stage == 5:
		var stage5_hongryun_state: Object = _get_instance(registry, "stage5_hongryun_state")
		if stage5_hongryun_state != null and stage5_hongryun_state.has_method("get_boss_ai_context"):
			context.merge(stage5_hongryun_state.get_boss_ai_context(), true)
		return
	if current_stage == 6:
		var stage6_tetriser_state: Object = _get_instance(registry, "stage6_tetriser_state")
		if stage6_tetriser_state != null and stage6_tetriser_state.has_method("get_boss_ai_context"):
			context.merge(stage6_tetriser_state.get_boss_ai_context(), true)
		return
	if current_stage != 2:
		return
	var stage_background: Object = _get_stage_instance(registry, current_stage, "stage_background", "stage2_pillar_background")
	var stage2_skill_state: Object = _get_instance(registry, "stage2_boss_skill_state")
	if stage2_skill_state != null and stage2_skill_state.has_method("get_boss_ai_context"):
		context.merge(stage2_skill_state.get_boss_ai_context(stage_background), true)
	elif stage_background != null and stage_background.has_method("get_boss_ai_context"):
		context.merge(stage_background.get_boss_ai_context(), true)
	var monkey_event: Object = _get_instance(registry, "stage2_monkey_banana_event")
	if monkey_event != null and monkey_event.has_method("get_boss_ai_context"):
		context.merge(monkey_event.get_boss_ai_context(), true)


func _merge_character_context(context: Dictionary, registry: Object, character_type: String) -> void:
	if not character_runtime.is_viper(character_type):
		return
	var viper_skill_runtime: Object = _get_instance(registry, "viper_skill_runtime")
	if viper_skill_runtime != null and viper_skill_runtime.has_method("get_boss_ai_context"):
		context.merge(viper_skill_runtime.get_boss_ai_context(), true)


func _is_smasher(character_type: String) -> bool:
	return character_type == "smasher"


func _get_boss_paddle_width(owner: Object, ai_mode: String) -> float:
	var league_width: float = BOSS_PADDLE_WIDTH * _get_boss_paddle_scale(ai_mode)
	var owner_width: float = float(_get_owner_value(owner, "boss_paddle_width", league_width))
	if _normalize_league_mode(ai_mode) == "mythic":
		return max(1.0, max(owner_width, league_width))
	return max(1.0, owner_width)


func _get_boss_paddle_scale(ai_mode: String) -> float:
	return MYTHIC_BOSS_PADDLE_SCALE if _normalize_league_mode(ai_mode) == "mythic" else 1.0


func _get_stage_boss_mistake_chance(current_stage: int, ai_mode: String) -> float:
	var normalized_mode: String = _normalize_league_mode(ai_mode)
	if normalized_mode == "junior":
		return _get_junior_stage_boss_mistake_chance(current_stage)
	if normalized_mode == "mythic":
		return MYTHIC_BOSS_MISTAKE_CHANCE
	if current_stage == 2:
		return STAGE2_BOSS_MISTAKE_CHANCE
	if current_stage == 3:
		return STAGE3_MENHERA_MISTAKE_CHANCE
	if current_stage == 4:
		return STAGE4_PONK_MISTAKE_CHANCE
	return DEFAULT_BOSS_MISTAKE_CHANCE


func _build_boss_mistake_profile(current_stage: int, ai_mode: String) -> Dictionary:
	if _normalize_league_mode(ai_mode) == "mythic":
		return {
			"boss_mistake_chance": MYTHIC_BOSS_MISTAKE_CHANCE,
			"boss_mistake_error_min": MYTHIC_BOSS_MISTAKE_ERROR_MIN,
			"boss_mistake_error_max": MYTHIC_BOSS_MISTAKE_ERROR_MAX,
			"boss_mistake_speed_scale": MYTHIC_BOSS_MISTAKE_SPEED_SCALE,
		}
	return {
		"boss_mistake_chance": _get_stage_boss_mistake_chance(current_stage, ai_mode),
		"boss_mistake_error_min": DEFAULT_BOSS_MISTAKE_ERROR_MIN,
		"boss_mistake_error_max": DEFAULT_BOSS_MISTAKE_ERROR_MAX,
		"boss_mistake_speed_scale": DEFAULT_BOSS_MISTAKE_SPEED_SCALE,
	}


func _get_junior_stage_boss_mistake_chance(current_stage: int) -> float:
	if current_stage == 1:
		return JUNIOR_STAGE1_DALJI_BOSS_MISTAKE_CHANCE
	var stage_offset: int = _get_stage_offset(current_stage)
	return clamp(
		JUNIOR_DEFAULT_BOSS_MISTAKE_CHANCE - float(stage_offset) * JUNIOR_BOSS_MISTAKE_STAGE_RATE,
		0.0,
		1.0
	)


func _build_boss_movement_profile(current_stage: int, ai_mode: String) -> Dictionary:
	var stage_multiplier: float = _get_boss_stage_speed_multiplier(current_stage)
	var league_multiplier: float = _get_boss_league_movement_multiplier(ai_mode)
	return {
		"boss_stage_speed_multiplier": stage_multiplier,
		"boss_league_movement_multiplier": league_multiplier,
		"boss_max_speed": BASE_BOSS_MAX_SPEED * stage_multiplier * league_multiplier,
		"boss_movement_accel": BASE_BOSS_ACCEL * CHAMPION_BOSS_SPEED_MULTIPLIER * stage_multiplier * league_multiplier,
		"boss_movement_decel": BASE_BOSS_DECEL * CHAMPION_BOSS_SPEED_MULTIPLIER * stage_multiplier * league_multiplier,
		"boss_movement_max_speed": BASE_BOSS_MAX_SPEED * CHAMPION_BOSS_SPEED_MULTIPLIER * stage_multiplier * league_multiplier,
	}


func _get_boss_league_movement_multiplier(ai_mode: String) -> float:
	var normalized_mode: String = _normalize_league_mode(ai_mode)
	if normalized_mode == "junior":
		return JUNIOR_BOSS_MOVEMENT_MULTIPLIER
	if normalized_mode == "mythic":
		return MYTHIC_BOSS_MOVEMENT_MULTIPLIER
	return 1.0


func _get_boss_dash_max_tokens(ai_mode: String, current_stage: int) -> int:
	if _normalize_league_mode(ai_mode) == "mythic":
		if current_stage >= 5:
			return MYTHIC_STAGE5_BOSS_DASH_MAX_TOKENS
		return MYTHIC_BOSS_DASH_MAX_TOKENS
	return DEFAULT_BOSS_DASH_MAX_TOKENS


func _get_boss_dash_trigger_chance(ai_mode: String) -> float:
	if _normalize_league_mode(ai_mode) == "mythic":
		return MYTHIC_BOSS_DASH_TRIGGER_CHANCE
	return DEFAULT_BOSS_DASH_TRIGGER_CHANCE


func _get_boss_dash_chain_trigger_chance(ai_mode: String) -> float:
	return _get_boss_dash_trigger_chance(ai_mode)


func _is_boss_dash_chain_enabled(ai_mode: String, current_stage: int) -> bool:
	return _get_boss_dash_max_tokens(ai_mode, current_stage) > 1


func _normalize_league_mode(ai_mode: String) -> String:
	var normalized: String = ai_mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"


func _build_boss_dash_profile(current_stage: int) -> Dictionary:
	var stage_offset: int = _get_stage_offset(current_stage)
	var distance_multiplier: float = 1.0 + float(stage_offset) * BOSS_DASH_DISTANCE_STAGE_RATE
	var cooldown_multiplier: float = max(BOSS_DASH_COOLDOWN_MIN_MULTIPLIER, 1.0 - float(stage_offset) * BOSS_DASH_COOLDOWN_STAGE_RATE)
	return {
		"boss_dash_stage_distance_multiplier": distance_multiplier,
		"boss_dash_stage_cooldown_multiplier": cooldown_multiplier,
		"boss_dash_max_distance": BASE_BOSS_DASH_MAX_DISTANCE * distance_multiplier,
		"boss_dash_cooldown_min_seconds": BASE_BOSS_DASH_COOLDOWN_MIN_SECONDS * cooldown_multiplier,
		"boss_dash_cooldown_max_seconds": BASE_BOSS_DASH_COOLDOWN_MAX_SECONDS * cooldown_multiplier,
	}


func _get_boss_stage_speed_multiplier(current_stage: int) -> float:
	var stage_offset: int = _get_stage_offset(current_stage)
	return 1.0 + min(float(stage_offset) * BOSS_STAGE_SPEED_RATE, BOSS_STAGE_SPEED_CAP)


func _get_stage_offset(current_stage: int) -> int:
	if current_stage == 50:
		return 0
	return max(0, current_stage - 1)


func _is_boss_dash_enabled(current_stage: int) -> bool:
	return current_stage != 50


func _is_waiting_for_serve(round_state: Object) -> bool:
	if round_state == null or not round_state.has_method("is_waiting_for_serve"):
		return true
	return bool(round_state.is_waiting_for_serve())


func _does_player_serve(round_state: Object) -> bool:
	if round_state == null or not round_state.has_method("does_player_serve"):
		return true
	return bool(round_state.does_player_serve())


func _get_round_snapshot_float(round_state: Object, key: String, fallback: float) -> float:
	if round_state == null or not round_state.has_method("get_snapshot"):
		return fallback
	var snapshot: Variant = round_state.get_snapshot()
	if snapshot is Dictionary:
		return float(snapshot.get(key, fallback))
	return fallback


func _get_stage_instance(registry: Object, current_stage: int, role: String, fallback_key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var router: Object = registry.get_instance("stage_runtime_router")
	if router != null and router.has_method("get_instance"):
		var routed: Object = router.get_instance(registry, current_stage, role)
		if routed != null:
			return routed
	return registry.get_instance(fallback_key)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)
