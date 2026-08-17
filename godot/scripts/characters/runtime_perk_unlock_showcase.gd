extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const MAX_AGE := 6.0
const MIN_DISMISS_AGE := 0.3


func reset(showcase: Dictionary) -> void:
	showcase.clear()


func is_active(showcase: Dictionary) -> bool:
	return bool(showcase.get("active", false))


func is_active_from_runtime_state(runtime_state: Object) -> bool:
	return is_active(_get_runtime_state_dict(runtime_state, "unlock_showcase"))


func should_open(choice: Dictionary, owner: Object) -> bool:
	if str(choice.get("unlocks_skill", "")) == "":
		return false
	var ai_mode: String = BattleSceneConfig.normalize_league_mode(str(_safe_owner_get(owner, "ai_mode", "champion")))
	return ai_mode == "junior"


func build(choice_id: String, owner: Object, registry: Object, choice: Dictionary) -> Dictionary:
	var skill_id: String = str(choice.get("unlocks_skill", ""))
	if skill_id == "":
		return {}
	var character_type: String = _normalize_character_type(str(choice.get("character_restriction", _get_character_type(owner))))
	var skill_data: Dictionary = _get_skill_data(skill_id, character_type, registry)
	if skill_data.is_empty():
		skill_data = {
			"name": skill_id,
			"korean": str(choice.get("name", skill_id)),
			"how_to_use": "",
			"motion_hint": "",
			"color": _get_color(choice.get("icon_color", Color(100.0 / 255.0, 180.0 / 255.0, 1.0))),
		}
	elif not skill_data.has("color"):
		skill_data["color"] = _get_color(choice.get("icon_color", Color(100.0 / 255.0, 180.0 / 255.0, 1.0)))
	return {
		"active": true,
		"age": 0.0,
		"choice_id": choice_id,
		"choice": choice.duplicate(true),
		"skill_id": skill_id,
		"character_type": character_type,
		"skill_data": skill_data.duplicate(true),
	}


func apply_showcase_state_update(runtime_state: Object, showcase: Dictionary) -> Dictionary:
	if runtime_state == null or showcase.is_empty():
		return {"accepted": false}
	runtime_state.set("unlock_showcase", showcase.duplicate(true))
	var applied_showcase: Dictionary = _get_dict(runtime_state.get("unlock_showcase"))
	return {
		"accepted": true,
		"active": is_active(applied_showcase),
		"choice_id": str(applied_showcase.get("choice_id", "")),
		"skill_id": str(applied_showcase.get("skill_id", "")),
	}


func advance(showcase: Dictionary, delta: float) -> bool:
	if not is_active(showcase):
		return false
	var age: float = max(0.0, float(showcase.get("age", 0.0)) + max(0.0, delta))
	showcase["age"] = age
	return age >= MAX_AGE


func should_dismiss_from_input(showcase: Dictionary, event: InputEvent) -> bool:
	if float(showcase.get("age", 0.0)) < MIN_DISMISS_AGE:
		return false
	var dismiss_requested := false
	if GamepadInput.is_gamepad_event(event):
		dismiss_requested = GamepadInput.is_confirm_event(event)
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		dismiss_requested = key_event.pressed and not key_event.echo
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		dismiss_requested = mouse_event.pressed and not _is_mouse_wheel_button(mouse_event.button_index)
	return dismiss_requested


func consume(showcase: Dictionary) -> Dictionary:
	if not is_active(showcase):
		return {}
	var payload: Dictionary = showcase.duplicate(true)
	reset(showcase)
	return payload


func _get_skill_data(skill_id: String, character_type: String, registry: Object) -> Dictionary:
	var skill_config: Object = _get_instance(registry, _get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("get_skill_data"):
		return {}
	var value: Variant = skill_config.get_skill_data(skill_id)
	if value is Dictionary:
		var data: Dictionary = value
		return data.duplicate(true)
	return {}


func _get_skill_config_key(character_type: String) -> String:
	match _normalize_character_type(character_type):
		"viper":
			return "viper_skill_config"
		"soldier":
			return "commando_skill_config"
		"optimus":
			return "optimus_skill_config"
		"blacksmith":
			return "blacksmith_skill_config"
	return "smasher_skill_config"


func _normalize_character_type(character_type: String) -> String:
	var normalized: String = str(character_type).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	if normalized == "blacksmith" or normalized == "baltor" or normalized == "kohaku":
		return "blacksmith"
	return "smasher"


func _get_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	return _normalize_character_type(str(value))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _get_runtime_state_dict(runtime_state: Object, key: String) -> Dictionary:
	if runtime_state == null:
		return {}
	return _get_dict(runtime_state.get(key))


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _is_mouse_wheel_button(button_index: int) -> bool:
	return (
		button_index == MOUSE_BUTTON_WHEEL_UP
		or button_index == MOUSE_BUTTON_WHEEL_DOWN
		or button_index == MOUSE_BUTTON_WHEEL_LEFT
		or button_index == MOUSE_BUTTON_WHEEL_RIGHT
	)
