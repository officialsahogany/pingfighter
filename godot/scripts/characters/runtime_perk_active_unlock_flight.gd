extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const Stage1PillarUILayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")

const DURATION := 1.86
const PARTICLE_COUNT := 18
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

var _scene_config: Object = BattleSceneConfig.new()
var _view_layout: Object = BattleViewLayout.new()
var _pillar_layout: Object = Stage1PillarUILayout.new()
var _orb_positioner: Object = SmasherSkillOrbRenderer.new()


func reset(effect: Dictionary) -> void:
	effect.clear()


func consume_effect(effect: Dictionary) -> Dictionary:
	if effect.is_empty():
		return {}
	var snapshot: Dictionary = effect.duplicate(true)
	reset(effect)
	return snapshot


func build_landing_payload(effect: Dictionary) -> Dictionary:
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(effect.get("choice", {}))
	var choice_id: String = str(effect.get("choice_id", choice.get("id", "")))
	if choice_id == "" or choice.is_empty():
		return {"accepted": false}
	return {
		"accepted": true,
		"choice": choice.duplicate(true),
		"choice_id": choice_id,
	}


func is_active(effect: Dictionary) -> bool:
	return bool(effect.get("active", false))


func is_active_from_runtime_state(runtime_state: Object) -> bool:
	return is_active(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "choice_flight_effect"))


func build_effect(
	choice: Dictionary,
	source_rect: Rect2,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> Dictionary:
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill == "" or view_size == Vector2.ZERO:
		return {}
	var target: Dictionary = resolve_target(choice, owner, registry, view_size)
	if target.is_empty():
		return {}
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return {}
	var source_pos: Vector2 = source_rect.get_center()
	var target_pos: Vector2 = RuntimePerkPayloadAccess.as_vector2(target.get("target_pos", Vector2.ZERO))
	if source_pos == Vector2.ZERO or target_pos == Vector2.ZERO:
		return {}
	var color: Color = RuntimePerkPayloadAccess.as_color(choice.get("icon_color", Color(100.0 / 255.0, 180.0 / 255.0, 1.0)))
	return {
		"active": true,
		"age": 0.0,
		"duration": DURATION,
		"choice": choice.duplicate(true),
		"choice_id": str(choice.get("id", "")),
		"skill_id": unlocked_skill,
		"character_type": str(target.get("character_type", _get_character_type(owner))),
		"source_pos": source_pos,
		"source_rect": source_rect,
		"target_pos": target_pos,
		"target_slot_index": int(target.get("slot_index", -1)),
		"icon_color": color,
		"particles": build_particles(color),
	}


func build_effect_for_selected_card(
	choice: Dictionary,
	selected_index: int,
	card_rects: Array,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> Dictionary:
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill == "" or view_size == Vector2.ZERO:
		return {}
	if selected_index < 0 or selected_index >= card_rects.size():
		return {}
	var source_rect: Rect2 = RuntimePerkPayloadAccess.as_rect2(card_rects[selected_index])
	return build_effect(choice, source_rect, owner, registry, view_size)


func apply_effect_state_update(runtime_state: Object, effect: Dictionary) -> Dictionary:
	if runtime_state == null or effect.is_empty():
		return {"accepted": false}
	runtime_state.set("choice_flight_effect", effect.duplicate(true))
	var applied_effect: Dictionary = RuntimePerkPayloadAccess.as_dict(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "choice_flight_effect"))
	return {
		"accepted": true,
		"active": is_active(applied_effect),
		"choice_id": str(applied_effect.get("choice_id", "")),
		"skill_id": str(applied_effect.get("skill_id", "")),
	}


func advance(effect: Dictionary, delta: float) -> bool:
	if not is_active(effect):
		return false
	var age: float = max(0.0, float(effect.get("age", 0.0)) + max(0.0, delta))
	effect["age"] = age
	return age >= float(effect.get("duration", DURATION))


func resolve_target(choice: Dictionary, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill == "":
		return {}
	var character_type: String = _normalize_character_type(str(choice.get("character_restriction", _get_character_type(owner))))
	var skill_config: Object = _get_instance(registry, _get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return {}
	var snapshot: Dictionary = RuntimePerkPayloadAccess.as_dict(skill_config.get_snapshot())
	var equipped: Array = RuntimePerkPayloadAccess.as_array(snapshot.get("equipped_skills", []))
	var max_slots: int = max(1, int(snapshot.get("max_slots", 5)))
	var slot_index: int = equipped.find(unlocked_skill)
	if slot_index < 0:
		if equipped.size() >= max_slots:
			return {}
		slot_index = equipped.size()

	var layout_state: Dictionary = build_layout_state(registry, view_size)
	var game_offset: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout_state.get("game_offset", Vector2.ZERO))
	var game_size: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout_state.get("game_size", Vector2.ZERO))
	var height: float = float(layout_state.get("height", FIELD_HEIGHT))
	if game_size.x <= 0.0 or game_size.y <= 0.0 or height <= 0.0:
		return {}
	var pillar_layout: Dictionary = _pillar_layout.build_layout(game_offset, game_size, {"height": height})
	var scale_factor: float = max(0.001, float(pillar_layout.get("scale_factor", game_size.y / height)))
	var left_center: Vector2 = RuntimePerkPayloadAccess.as_vector2(pillar_layout.get("left_center", Vector2.ZERO))
	var orb_radius: float = max(1.0, float(pillar_layout.get("orb_radius", 55.0 * scale_factor)))
	var slot_layout: Dictionary = _pillar_layout.get_skill_orb_slot_layout(character_type)
	var positions: Array = _orb_positioner.get_slot_positions(left_center, orb_radius, scale_factor, {
		"max_slots": max_slots,
		"skill_orb_radius": 24.0,
		"gauge_gap": 28.0,
		"orb_radius_base": 55.0,
		"slot_base_angle": slot_layout.get("base_angle", 165.0),
		"slot_angle_step": slot_layout.get("angle_step", 33.0),
	})
	if slot_index < 0 or slot_index >= positions.size():
		return {}
	var target_pos: Vector2 = RuntimePerkPayloadAccess.as_vector2(positions[slot_index])
	if target_pos == Vector2.ZERO:
		return {}
	return {
		"target_pos": target_pos,
		"slot_index": slot_index,
		"character_type": character_type,
	}


func build_layout_state(registry: Object, view_size: Vector2) -> Dictionary:
	var draw_context: Dictionary = _scene_config.build_draw_context()
	var scene_config: Object = _get_instance(registry, "battle_scene_config")
	if scene_config != null and scene_config.has_method("build_draw_context"):
		draw_context = RuntimePerkPayloadAccess.as_dict(scene_config.build_draw_context())
	var width: float = float(draw_context.get("width", FIELD_WIDTH))
	var height: float = float(draw_context.get("height", FIELD_HEIGHT))
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module == null or not layout_module.has_method("build_game_layout"):
		layout_module = _view_layout
	var layout: Dictionary = RuntimePerkPayloadAccess.as_dict(layout_module.build_game_layout(view_size, width, height))
	layout["width"] = width
	layout["height"] = height
	return layout


func build_layout_state_from_runtime_state(
	runtime_state: Object,
	registry: Object,
	view_size: Vector2
) -> Dictionary:
	if runtime_state == null:
		return {}
	return build_layout_state(registry, view_size)


func build_particles(color: Color) -> Array:
	var particles_out: Array = []
	for index in range(PARTICLE_COUNT):
		var a: float = _pseudo_unit(index, 1.7)
		var b: float = _pseudo_unit(index, 4.1)
		var c: float = _pseudo_unit(index, 9.3)
		var mix_white: float = 0.22 + b * 0.46
		particles_out.append({
			"delay": 0.18 + a * 0.22,
			"duration": 0.64 + b * 0.24,
			"arc": 38.0 + c * 86.0,
			"side": -1.0 if index % 2 == 0 else 1.0,
			"side_offset": -30.0 + a * 60.0,
			"size": 2.1 + b * 3.4,
			"color": Color(
				lerpf(color.r, 1.0, mix_white),
				lerpf(color.g, 1.0, mix_white),
				lerpf(color.b, 1.0, mix_white),
				1.0
			),
		})
	return particles_out


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


func _pseudo_unit(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 12.9898 + salt) * 43758.5453, 1.0)
