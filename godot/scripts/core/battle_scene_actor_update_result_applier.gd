extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

var _character_runtime: Object = PlayerCharacterRuntime.new()


func apply_player_result(owner: Object, registry: Object, result: Dictionary) -> void:
	if owner == null:
		return

	owner.set("gameplay_frame_counter", int(result.get(
		"frame_counter",
		int(_get_owner_value(owner, "gameplay_frame_counter", 0))
	)))

	var updated_pos: Variant = result.get("player_pos", _get_owner_vector2(owner, "player_pos", Vector2.ZERO))
	if updated_pos is Vector2:
		owner.set("player_pos", updated_pos)

	owner.set("player_speed", float(result.get("player_speed", _get_owner_value(owner, "player_speed", 0.0))))

	if result.has("special_gauge"):
		owner.set("special_gauge", float(result.get("special_gauge", _get_owner_value(owner, "special_gauge", 0.0))))
	if result.has("special_gauge_max"):
		owner.set("special_gauge_max", float(result.get("special_gauge_max", _get_owner_value(owner, "special_gauge_max", 500.0))))
	if result.has("runtime_paddle_base_width"):
		owner.set("runtime_paddle_base_width", max(1.0, float(result.get("runtime_paddle_base_width", _get_owner_value(owner, "runtime_paddle_base_width", 155.0)))))
	if result.has("runtime_paddle_base_height"):
		owner.set("runtime_paddle_base_height", max(1.0, float(result.get("runtime_paddle_base_height", _get_owner_value(owner, "runtime_paddle_base_height", 50.0)))))
	if result.has("player_paddle_width") or result.has("player_paddle_height"):
		_apply_player_paddle_size_result(owner, result)
	if result.has("player_paddle_scale"):
		owner.set("player_paddle_scale", max(0.1, float(result.get("player_paddle_scale", _get_owner_value(owner, "player_paddle_scale", 1.0)))))
	if result.has("runtime_paddle_scale"):
		owner.set("runtime_paddle_scale", max(0.1, float(result.get("runtime_paddle_scale", _get_owner_value(owner, "runtime_paddle_scale", 1.0)))))
	if result.has("optimus_energy_initialized"):
		owner.set("optimus_energy_initialized", bool(result.get("optimus_energy_initialized", false)))
	if result.has("optimus_energy_ratio"):
		owner.set("optimus_energy_ratio", clamp(float(result.get("optimus_energy_ratio", 1.0)), 0.0, 1.0))
	if result.has("optimus_paddle_scale"):
		owner.set("optimus_paddle_scale", max(0.1, float(result.get("optimus_paddle_scale", 1.0))))
	if result.has("optimus_speed_multiplier"):
		owner.set("optimus_speed_multiplier", max(0.0, float(result.get("optimus_speed_multiplier", 1.0))))
	if result.has("optimus_charge_active"):
		owner.set("optimus_charge_active", bool(result.get("optimus_charge_active", false)))
	if result.has("optimus_charge_hold_seconds"):
		owner.set("optimus_charge_hold_seconds", max(0.0, float(result.get("optimus_charge_hold_seconds", 0.0))))
	if result.has("optimus_charge_hold_ratio"):
		owner.set("optimus_charge_hold_ratio", clamp(float(result.get("optimus_charge_hold_ratio", 0.0)), 0.0, 1.0))
	if result.has("optimus_charge_lock_seconds"):
		owner.set("optimus_charge_lock_seconds", max(0.0, float(result.get("optimus_charge_lock_seconds", 0.0))))
	if result.has("optimus_charge_movement_locked"):
		owner.set("optimus_charge_movement_locked", bool(result.get("optimus_charge_movement_locked", false)))
	_apply_blacksmith_umbrella_result(owner, result)
	if result.has("ball_pos") and result.get("ball_pos", null) is Vector2:
		owner.set("ball_pos", result["ball_pos"])
	if result.has("ball_vel") and result.get("ball_vel", null) is Vector2:
		owner.set("ball_vel", result["ball_vel"])
	if result.has("ball_impact_boost"):
		owner.set("ball_impact_boost", float(result.get("ball_impact_boost", _get_owner_value(owner, "ball_impact_boost", 1.0))))
	if result.has("player_collision_cooldown"):
		owner.set("player_collision_cooldown", float(result.get("player_collision_cooldown", _get_owner_value(owner, "player_collision_cooldown", 0.0))))
	if result.has("skill_gold_award"):
		_award_skill_gold(owner, registry, int(result.get("skill_gold_award", 0)))
	if result.has("runtime_perk_gold") and int(result.get("runtime_perk_gold", -1)) >= 0:
		owner.set("runtime_perk_gold", int(result.get("runtime_perk_gold", 0)))
	if bool(result.get("activated", false)):
		# 캐릭터 컨트롤러가 publish한 스킬 활성화 에지 -> 융합 부산물(잔향)
		# 스킬-사용 훅. 에지 발행 프레임에만 도달하므로 홀드 프레임 반복 없음.
		var fusion_runtime: Object = _get_instance(registry, "runtime_perk_state")
		if fusion_runtime != null and fusion_runtime.has_method("notify_perk_fusion_skill_used"):
			fusion_runtime.notify_perk_fusion_skill_used()


func apply_boss_result(owner: Object, result: Dictionary) -> void:
	if owner == null:
		return

	var updated_pos: Variant = result.get("boss_pos", _get_owner_vector2(owner, "boss_pos", Vector2.ZERO))
	if updated_pos is Vector2:
		owner.set("boss_pos", updated_pos)
	owner.set("boss_vel", float(result.get("boss_vel", _get_owner_value(owner, "boss_vel", 0.0))))


func _apply_blacksmith_umbrella_result(owner: Object, result: Dictionary) -> void:
	for key in [
		"blacksmith_umbrella_open",
		"blacksmith_umbrella_anim_timer",
		"blacksmith_umbrella_retracting",
		"blacksmith_umbrella_anim_direction",
		"blacksmith_umbrella_open_ratio",
		"blacksmith_thor_shield_open_ratio",
		"blacksmith_umbrella_raise_amount",
		"blacksmith_umbrella_shield_open_amount",
		"blacksmith_umbrella_visual_state",
		"blacksmith_umbrella_folded",
		"blacksmith_umbrella_deployed",
		"blacksmith_umbrella_swing_active",
		"blacksmith_umbrella_swing_direction",
		"blacksmith_umbrella_swing_timer",
		"blacksmith_umbrella_gauge",
		"blacksmith_umbrella_gauge_max",
		"blacksmith_umbrella_gauge_gain",
		"blacksmith_umbrella_damage_flash_timer",
		"blacksmith_umbrella_hit_pulse_timer",
	]:
		if result.has(key):
			owner.set(key, result[key])


func _award_skill_gold(owner: Object, registry: Object, amount: int) -> void:
	if amount <= 0:
		return
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
		var gold_context: Dictionary = _build_owner_gold_gain_context(owner, registry)
		owner.set("runtime_perk_gold", int(_call_award_gold(runtime_perk_state, amount, gold_context, {"registry": registry})))
	else:
		owner.set("runtime_perk_gold", int(_get_owner_value(owner, "runtime_perk_gold", 0)) + amount)


func _call_award_gold(runtime_perk_state: Object, amount: int, context: Dictionary, deps: Dictionary) -> int:
	if _method_accepts_arg_count(runtime_perk_state, "award_gold", 3):
		return int(runtime_perk_state.award_gold(amount, context, deps))
	return int(runtime_perk_state.award_gold(amount))


func _method_accepts_arg_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method in target.get_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var args: Variant = method.get("args", [])
		if args is Array:
			return (args as Array).size() >= arg_count
	return false


func _build_owner_gold_gain_context(owner: Object, registry: Object) -> Dictionary:
	var context: Dictionary = {}
	if owner != null:
		for key in [
			"selected_character_type",
			"arena_mode_enabled",
			"enraged_boss_active",
			"boss_enraged",
			"blacksmith_divine_stone_active",
			"blacksmith_divine_active",
			"blacksmith_divine_stone_state",
			"blacksmith_turret_active",
			"blacksmith_turret_state",
		]:
			var value: Variant = owner.get(str(key))
			if value != null:
				context[str(key)] = value
	var combo_state: Object = _get_instance(registry, "smasher_combo_state")
	if combo_state != null and combo_state.has_method("get_combo_count"):
		context["smasher_combo_count"] = max(0, int(combo_state.get_combo_count()))
	return context


func _apply_player_paddle_size_result(owner: Object, result: Dictionary) -> void:
	var current_width: float = max(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0)))
	var current_height: float = max(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	var next_width: float = max(1.0, float(result.get("player_paddle_width", current_width)))
	var next_height: float = max(1.0, float(result.get("player_paddle_height", current_height)))
	if abs(current_width - next_width) <= 0.01 and abs(current_height - next_height) <= 0.01:
		owner.set("player_paddle_width", next_width)
		owner.set("player_paddle_height", next_height)
		return
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2.ZERO)
	var is_optimus: bool = _character_runtime.is_optimus(_get_owner_value(owner, "selected_character_type", ""))
	var center_x: float = player_pos.x + current_width * 0.5
	var bottom_y: float = FIELD_HEIGHT if is_optimus else player_pos.y + current_height
	player_pos.x = clamp(center_x - next_width * 0.5, 0.0, max(0.0, FIELD_WIDTH - next_width))
	player_pos.y = clamp(bottom_y - next_height, 0.0, max(0.0, FIELD_HEIGHT - next_height))
	owner.set("player_pos", player_pos)
	owner.set("player_paddle_width", next_width)
	owner.set("player_paddle_height", next_height)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)
