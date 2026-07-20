extends RefCounted

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const INVALID_MOUSE_POS := Vector2(-1000000.0, -1000000.0)
const HOVER_CACHE_MSEC := 160

var layout_helper: Object = Stage1PillarUiLayout.new()
var fallback_orb_renderer: Object = SmasherSkillOrbRenderer.new()
var character_runtime: Object = PlayerCharacterRuntime.new()
var _cached_mouse_pos := INVALID_MOUSE_POS
var _cached_view_size := Vector2.ZERO
var _cached_stage := 0
var _cached_character_type := ""
var _cached_result: Dictionary = {}
var _cached_msec := -1000000
var _gamepad_selected_character_type := ""
var _gamepad_selected_stage := 0
var _gamepad_selected_skill_name := ""
var _gamepad_selected_skill_index := -1


func update_hover_state(owner: Object, registry: Object) -> Dictionary:
	if owner == null:
		return {}

	var gamepad_result: Dictionary = _get_gamepad_selection_result(owner, registry)
	if not gamepad_result.is_empty():
		return gamepad_result

	var view_size: Vector2 = _get_owner_view_size(owner)
	if view_size == Vector2.ZERO:
		return {}
	var mouse_pos: Vector2 = _get_owner_mouse_position(owner)
	if mouse_pos == INVALID_MOUSE_POS:
		_store_cached_result(owner, mouse_pos, view_size, {})
		return {}
	if _can_reuse_cached_result(owner, mouse_pos, view_size):
		return _cached_result.duplicate(true)
	var scene_config: Dictionary = _build_scene_config(registry)
	var layout: Dictionary = _build_layout(
		registry,
		view_size,
		float(scene_config.get("width", 760.0)),
		float(scene_config.get("height", 750.0))
	)
	if not _is_mouse_near_skill_hover_area(mouse_pos, layout, scene_config):
		_store_cached_result(owner, mouse_pos, view_size, {})
		return {}
	var horn_result: Dictionary = _find_hovered_horn_strawberry_skill_fast(owner, registry, mouse_pos, layout, scene_config)
	if not horn_result.is_empty():
		_store_cached_result(owner, mouse_pos, view_size, horn_result)
		return horn_result
	var odins_result: Dictionary = _find_hovered_odins_eye_skill_fast(owner, registry, mouse_pos, layout, scene_config)
	if not odins_result.is_empty():
		_store_cached_result(owner, mouse_pos, view_size, odins_result)
		return odins_result
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	if not character_runtime.is_commando(character_type):
		var fast_result: Dictionary = _find_hovered_skill_fast(registry, mouse_pos, layout, scene_config, character_type)
		_store_cached_result(owner, mouse_pos, view_size, fast_result)
		return fast_result

	var result: Dictionary = _find_hovered_skill_fast(registry, mouse_pos, layout, scene_config, character_type)
	if result.is_empty():
		result = _find_hovered_commando_firearm_fast(registry, mouse_pos, view_size, layout, scene_config)
	_store_cached_result(owner, mouse_pos, view_size, result)
	return result


func cycle_gamepad_tooltip(owner: Object, registry: Object) -> Dictionary:
	if owner == null:
		clear_gamepad_tooltip_selection()
		return {"handled": false, "active": false}
	var selectable_skills: Array = _get_gamepad_selectable_skills(owner, registry)
	if selectable_skills.is_empty():
		clear_gamepad_tooltip_selection()
		return {"handled": false, "active": false}

	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var current_index := -1
	if _gamepad_selected_character_type == character_type and _gamepad_selected_stage == stage:
		for i in range(selectable_skills.size()):
			if str(_get_dict(selectable_skills[i]).get("skill_name", "")) == _gamepad_selected_skill_name:
				current_index = i
				break

	if current_index < 0:
		return _set_gamepad_tooltip_selection(character_type, stage, 0, selectable_skills)
	if current_index + 1 >= selectable_skills.size():
		clear_gamepad_tooltip_selection()
		return {"handled": true, "active": false}
	return _set_gamepad_tooltip_selection(character_type, stage, current_index + 1, selectable_skills)


func clear_gamepad_tooltip_selection() -> void:
	_gamepad_selected_character_type = ""
	_gamepad_selected_stage = 0
	_gamepad_selected_skill_name = ""
	_gamepad_selected_skill_index = -1


func get_gamepad_selected_skill_name() -> String:
	return _gamepad_selected_skill_name


func _find_hovered_skill_fast(
	registry: Object,
	mouse_pos: Vector2,
	layout: Dictionary,
	scene_config: Dictionary,
	character_type: String
) -> Dictionary:
	var skill_config: Object = _get_instance(registry, character_runtime.get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return {}
	var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var skill_data_map: Dictionary = _get_dict(snapshot.get("skill_data", {}))
	if equipped_skills.is_empty() or skill_data_map.is_empty():
		return {}
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_config.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var skill_context: Dictionary = layout_helper.build_skill_orb_context({
		"skill_state": _get_instance(registry, character_runtime.get_skill_state_key(character_type)),
		"selected_character_type": character_type,
		"skill_config_snapshot": snapshot,
	}, _get_instance(registry, "pillar_orb_drawer"))
	var orb_renderer: Object = _get_instance(registry, "smasher_skill_orb_renderer")
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		orb_renderer = fallback_orb_renderer
	var positions: Array = orb_renderer.get_slot_positions(
		_get_vector2(ui_layout, "left_center", Vector2.ZERO),
		float(ui_layout.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var equipped_count: int = min(equipped_skills.size(), positions.size())
	for idx in range(equipped_count):
		var skill_name: String = str(equipped_skills[idx])
		if not skill_data_map.has(skill_name):
			continue
		var slot_center: Vector2 = _as_vector2(positions[idx], Vector2.ZERO)
		var rect := Rect2(slot_center - Vector2(icon_radius, icon_radius), Vector2(icon_radius * 2.0, icon_radius * 2.0))
		if rect.has_point(mouse_pos):
			return {"skill_name": skill_name}
	return {}


func _get_gamepad_selection_result(owner: Object, registry: Object) -> Dictionary:
	if _gamepad_selected_skill_name == "":
		return {}
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var stage: int = int(_get_owner_value(owner, "current_stage", 1))
	if character_type != _gamepad_selected_character_type or stage != _gamepad_selected_stage:
		clear_gamepad_tooltip_selection()
		return {}
	for entry_value in _get_gamepad_selectable_skills(owner, registry):
		var entry: Dictionary = _get_dict(entry_value)
		if str(entry.get("skill_name", "")) == _gamepad_selected_skill_name:
			return {
				"skill_name": _gamepad_selected_skill_name,
				"gamepad_selected": true,
			}
	clear_gamepad_tooltip_selection()
	return {}


func _set_gamepad_tooltip_selection(
	character_type: String,
	stage: int,
	index: int,
	selectable_skills: Array
) -> Dictionary:
	if index < 0 or index >= selectable_skills.size():
		clear_gamepad_tooltip_selection()
		return {"handled": true, "active": false}
	var entry: Dictionary = _get_dict(selectable_skills[index])
	var skill_name: String = str(entry.get("skill_name", ""))
	if skill_name == "":
		clear_gamepad_tooltip_selection()
		return {"handled": false, "active": false}
	_gamepad_selected_character_type = character_type
	_gamepad_selected_stage = stage
	_gamepad_selected_skill_name = skill_name
	_gamepad_selected_skill_index = index
	return {
		"handled": true,
		"active": true,
		"skill_name": skill_name,
		"gamepad_selected": true,
	}


func _get_gamepad_selectable_skills(owner: Object, registry: Object) -> Array:
	var horn_skills: Array = _get_horn_strawberry_gamepad_skills(registry)
	if not horn_skills.is_empty():
		return horn_skills
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var skill_config: Object = _get_instance(registry, character_runtime.get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return []
	var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var skill_data_map: Dictionary = _get_dict(snapshot.get("skill_data", {}))
	if equipped_skills.is_empty() or skill_data_map.is_empty():
		return []
	var result: Array = []
	for skill_value in equipped_skills:
		var skill_name: String = str(skill_value)
		if skill_name == "" or not skill_data_map.has(skill_name):
			continue
		result.append({"skill_name": skill_name})
	return result


func _get_horn_strawberry_gamepad_skills(registry: Object) -> Array:
	var mythic_item_runtime: Object = _get_cached_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("get_horn_strawberry_context"):
		return []
	var horn_context: Dictionary = _get_dict(mythic_item_runtime.get_horn_strawberry_context())
	if not bool(horn_context.get("transformed", false)):
		return []
	var horn_renderer: Object = _get_cached_instance(registry, "horn_strawberry_skill_pillar_renderer")
	if (
		horn_renderer == null
		or not horn_renderer.has_method("get_skill_order")
		or not horn_renderer.has_method("get_skill_data_map")
	):
		return []
	var order: Array = _get_array(horn_renderer.get_skill_order())
	var data_map: Dictionary = _get_dict(horn_renderer.get_skill_data_map())
	var result: Array = []
	for skill_value in order:
		var skill_name: String = str(skill_value)
		if skill_name == "" or not data_map.has(skill_name):
			continue
		result.append({"skill_name": skill_name})
	return result


func _find_hovered_horn_strawberry_skill_fast(
	owner: Object,
	registry: Object,
	mouse_pos: Vector2,
	layout: Dictionary,
	scene_config: Dictionary
) -> Dictionary:
	var mythic_item_runtime: Object = _get_cached_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("get_horn_strawberry_context"):
		return {}
	var horn_context: Dictionary = _get_dict(mythic_item_runtime.get_horn_strawberry_context())
	if not bool(horn_context.get("transformed", false)):
		return {}
	var horn_renderer: Object = _get_cached_instance(registry, "horn_strawberry_skill_pillar_renderer")
	if (
		horn_renderer == null
		or not horn_renderer.has_method("build_skill_orb_context")
		or not horn_renderer.has_method("find_hovered_skill")
	):
		return {}
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_config.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var base_context: Dictionary = layout_helper.build_skill_orb_context({
		"selected_character_type": "smasher",
		"skill_config_snapshot": {
			"max_slots": 4,
			"equipped_skills": [],
		},
	}, _get_cached_instance(registry, "pillar_orb_drawer"))
	var skill_context: Dictionary = horn_renderer.build_skill_orb_context(
		horn_context,
		float(_get_owner_value(owner, "special_gauge", 0.0)),
		_get_cached_instance(registry, "pillar_orb_drawer"),
		base_context
	)
	var skill_data: Dictionary = horn_renderer.find_hovered_skill(
		mouse_pos,
		_get_vector2(ui_layout, "left_center", Vector2.ZERO),
		float(ui_layout.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	if skill_data.is_empty():
		return {}
	return {
		"skill_name": str(skill_data.get("name", "")),
	}


# 오딘의 눈 변신 오브 hover(혼딸기 형제 계약 미러): 변신 중 어둠의 늪
# 단일 오브가 일반 클러스터를 대체하므로 hover도 오딘 렌더러가 소유한다.
func _find_hovered_odins_eye_skill_fast(
	owner: Object,
	registry: Object,
	mouse_pos: Vector2,
	layout: Dictionary,
	scene_config: Dictionary
) -> Dictionary:
	var mythic_item_runtime: Object = _get_cached_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("get_odins_eye_context"):
		return {}
	var odins_context: Dictionary = _get_dict(mythic_item_runtime.get_odins_eye_context())
	if not bool(odins_context.get("transformed", false)):
		return {}
	var odins_renderer: Object = _get_cached_instance(registry, "odins_eye_skill_pillar_renderer")
	if (
		odins_renderer == null
		or not odins_renderer.has_method("build_skill_orb_context")
		or not odins_renderer.has_method("find_hovered_skill")
	):
		return {}
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_config.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var base_context: Dictionary = layout_helper.build_skill_orb_context({
		"selected_character_type": "smasher",
		"skill_config_snapshot": {
			"max_slots": 4,
			"equipped_skills": [],
		},
	}, _get_cached_instance(registry, "pillar_orb_drawer"))
	var skill_context: Dictionary = odins_renderer.build_skill_orb_context(
		odins_context,
		float(_get_owner_value(owner, "special_gauge", 0.0)),
		_get_cached_instance(registry, "pillar_orb_drawer"),
		base_context
	)
	var skill_data: Dictionary = odins_renderer.find_hovered_skill(
		mouse_pos,
		_get_vector2(ui_layout, "left_center", Vector2.ZERO),
		float(ui_layout.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	if skill_data.is_empty():
		return {}
	return {
		"skill_name": str(skill_data.get("name", "")),
	}


func _find_hovered_commando_firearm_fast(
	registry: Object,
	mouse_pos: Vector2,
	view_size: Vector2,
	layout: Dictionary,
	scene_config: Dictionary
) -> Dictionary:
	var selector_renderer: Object = _get_cached_instance(registry, "commando_firearm_selector_renderer")
	var tooltip_renderer: Object = _get_cached_instance(registry, "commando_firearm_tooltip_renderer")
	var weapon_controller: Object = _get_cached_instance(registry, "commando_weapon_controller")
	if (
		selector_renderer == null
		or tooltip_renderer == null
		or weapon_controller == null
		or not selector_renderer.has_method("build_panel_state")
		or not tooltip_renderer.has_method("build_hover_state")
	):
		return {}
	var skill_config: Object = _get_instance(registry, character_runtime.get_skill_config_key("soldier"))
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return {}
	var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_config.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var left_center: Vector2 = _get_vector2(ui_layout, "left_center", Vector2.ZERO)
	var orb_radius: float = float(ui_layout.get("orb_radius", 55.0))
	var skill_context: Dictionary = layout_helper.build_skill_orb_context({
		"skill_state": _get_cached_instance(registry, character_runtime.get_skill_state_key("soldier")),
		"selected_character_type": "soldier",
		"skill_config_snapshot": snapshot,
	}, _get_cached_instance(registry, "pillar_orb_drawer"))
	var orb_renderer: Object = _get_cached_instance(registry, "smasher_skill_orb_renderer")
	if orb_renderer == null or not orb_renderer.has_method("get_cluster_bounds"):
		orb_renderer = fallback_orb_renderer
	var panel_center: Vector2 = left_center + Vector2(28.0, -180.0) * scale_factor
	if orb_renderer != null and orb_renderer.has_method("get_cluster_bounds"):
		var cluster_bounds: Rect2 = orb_renderer.get_cluster_bounds(left_center, orb_radius, scale_factor, skill_context)
		if cluster_bounds.size.x > 0.0 and cluster_bounds.size.y > 0.0:
			panel_center = Vector2(
				cluster_bounds.position.x + cluster_bounds.size.x * 0.5,
				cluster_bounds.position.y
			) + Vector2(28.0, -64.0) * scale_factor
	var commando_firearm_runtime: Object = _get_cached_instance(registry, "commando_firearm_runtime")
	var firearm_context: Dictionary = {}
	if commando_firearm_runtime != null and commando_firearm_runtime.has_method("get_actor_draw_context"):
		firearm_context = commando_firearm_runtime.get_actor_draw_context()
	var panel_state: Dictionary = selector_renderer.build_panel_state(panel_center, scale_factor, {
		"commando_weapon_controller": weapon_controller,
		"commando_firearm_slingshot_state": _get_dict(firearm_context.get("commando_firearm_slingshot_state", {})),
		"commando_firearm_pistol_state": _get_dict(firearm_context.get("commando_firearm_pistol_state", {})),
		"commando_firearm_weapon_fire_sheet_state": _get_dict(firearm_context.get("commando_firearm_weapon_fire_sheet_state", {})),
		"commando_firearm_bowling_trap_state": _get_dict(firearm_context.get("commando_firearm_bowling_trap_state", {})),
		"commando_firearm_bowling_traps": _get_array(firearm_context.get("commando_firearm_bowling_traps", [])),
	})
	var tooltip_state: Dictionary = tooltip_renderer.build_hover_state(panel_state, view_size, scale_factor, {
		"mouse_pos": mouse_pos,
		"commando_weapon_controller": weapon_controller,
		"skill_config_snapshot": snapshot,
		"commando_firearm_slingshot_state": _get_dict(firearm_context.get("commando_firearm_slingshot_state", {})),
		"commando_firearm_pistol_state": _get_dict(firearm_context.get("commando_firearm_pistol_state", {})),
	})
	if tooltip_state.is_empty():
		return {}
	return {
		"skill_name": str(tooltip_state.get("tooltip_key", "commando_firearm")),
	}


func _build_layout(registry: Object, view_size: Vector2, width: float, height: float) -> Dictionary:
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_size": Vector2(width, height),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


func _build_scene_config(registry: Object) -> Dictionary:
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config != null and config.has_method("build_draw_context"):
		return config.build_draw_context()
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
	}


func _is_mouse_near_skill_hover_area(mouse_pos: Vector2, layout: Dictionary, scene_config: Dictionary) -> bool:
	if mouse_pos == INVALID_MOUSE_POS:
		return true
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var base_height: float = max(1.0, float(scene_config.get("height", 750.0)))
	var scale_factor: float = max(0.45, game_size.y / base_height)
	var bounds := Rect2(
		Vector2(game_offset.x - 320.0 * scale_factor, game_offset.y + game_size.y - 460.0 * scale_factor),
		Vector2(390.0 * scale_factor, 530.0 * scale_factor)
	)
	return bounds.has_point(mouse_pos)


func _can_reuse_cached_result(owner: Object, mouse_pos: Vector2, view_size: Vector2) -> bool:
	if mouse_pos == INVALID_MOUSE_POS:
		return false
	if mouse_pos != _cached_mouse_pos or view_size != _cached_view_size:
		return false
	if int(_get_owner_value(owner, "current_stage", 1)) != _cached_stage:
		return false
	if str(_get_owner_value(owner, "selected_character_type", "")) != _cached_character_type:
		return false
	return Time.get_ticks_msec() - _cached_msec <= HOVER_CACHE_MSEC


func _store_cached_result(owner: Object, mouse_pos: Vector2, view_size: Vector2, result: Dictionary) -> void:
	_cached_mouse_pos = mouse_pos
	_cached_view_size = view_size
	_cached_stage = int(_get_owner_value(owner, "current_stage", 1))
	_cached_character_type = str(_get_owner_value(owner, "selected_character_type", ""))
	_cached_result = result.duplicate(true)
	_cached_msec = Time.get_ticks_msec()


func _get_owner_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2.ZERO


func _get_owner_mouse_position(owner: Object) -> Vector2:
	if owner == null or not owner.has_method("get_viewport"):
		return INVALID_MOUSE_POS
	var viewport: Viewport = owner.get_viewport()
	if viewport == null:
		return INVALID_MOUSE_POS
	return viewport.get_mouse_position()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "":
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
		return null
	return _get_instance(registry, key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
