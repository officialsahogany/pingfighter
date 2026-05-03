extends RefCounted

const STARPOINT_PER_SKILL_CHOICE := 1
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const SPECIAL_GAUGE_MAX := 500.0
const PARTICLE_COUNT := 42
const PARTICLE_LIFE := 1.45

var runtime_skill_levels: Dictionary = {}
var starpoint_for_skills := 0
var pending_skill_choices := 0
var choice_active := false
var current_choices: Array = []
var selected_index := 0
var animation_time := 0.0
var particles: Array = []
var gold_from_perks := 0
var feedback_text := ""
var feedback_timer := 0.0
var last_selected_id := ""


func reset() -> void:
	runtime_skill_levels.clear()
	starpoint_for_skills = 0
	pending_skill_choices = 0
	choice_active = false
	current_choices.clear()
	selected_index = 0
	animation_time = 0.0
	particles.clear()
	gold_from_perks = 0
	feedback_text = ""
	feedback_timer = 0.0
	last_selected_id = ""


func collect_star_points(amount: int, character_type: String, catalog: Object, owner: Object = null) -> bool:
	starpoint_for_skills += max(0, amount)
	while starpoint_for_skills >= STARPOINT_PER_SKILL_CHOICE:
		starpoint_for_skills -= STARPOINT_PER_SKILL_CHOICE
		pending_skill_choices += 1
	feedback_text = "스타포인트 +%d" % max(0, amount)
	feedback_timer = 1.0
	if pending_skill_choices > 0 and not choice_active:
		open_next_choice(character_type, catalog)
	_sync_owner(owner)
	return choice_active


func open_next_choice(character_type: String, catalog: Object, exclude_instant: bool = false) -> void:
	if pending_skill_choices <= 0:
		choice_active = false
		current_choices.clear()
		return
	if catalog == null or not catalog.has_method("get_choices"):
		choice_active = false
		return

	current_choices = catalog.get_choices(character_type, runtime_skill_levels, exclude_instant)
	if current_choices.is_empty():
		pending_skill_choices = max(0, pending_skill_choices - 1)
		choice_active = pending_skill_choices > 0
		if choice_active:
			open_next_choice(character_type, catalog, exclude_instant)
		return

	selected_index = min(1, current_choices.size() - 1)
	animation_time = 0.0
	choice_active = true
	_build_particles()


func is_choice_active() -> bool:
	return choice_active


func is_selectable() -> bool:
	return choice_active and animation_time >= 0.24 and not current_choices.is_empty()


func update(delta: float, view_size: Vector2) -> void:
	if feedback_timer > 0.0:
		feedback_timer = max(0.0, feedback_timer - delta)
	if not choice_active:
		return
	animation_time += delta
	var left: float = max(0.0, view_size.x * 0.5 - 300.0)
	var right: float = min(view_size.x, view_size.x * 0.5 + 300.0)
	for particle in particles:
		var data: Dictionary = particle
		data["age"] = float(data.get("age", 0.0)) + delta
		data["position"] = _get_vector2(data.get("position", Vector2.ZERO)) + _get_vector2(data.get("velocity", Vector2.ZERO)) * delta
		var pos: Vector2 = _get_vector2(data.get("position", Vector2.ZERO))
		if pos.x < left or pos.x > right or float(data.get("age", 0.0)) > PARTICLE_LIFE:
			_reset_particle(data, view_size)


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not choice_active:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		match key_event.keycode:
			KEY_LEFT:
				move_selection(-1)
				return true
			KEY_RIGHT:
				move_selection(1)
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
				choose_selected(owner, registry)
				return true
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return true
		var clicked_index: int = _get_card_index_at(mouse_event.position, view_size)
		if clicked_index >= 0:
			selected_index = clicked_index
			choose_selected(owner, registry)
		return true
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var hovered_index: int = _get_card_index_at(motion_event.position, view_size)
		if hovered_index >= 0:
			selected_index = hovered_index
		return true
	return true


func move_selection(delta_index: int) -> void:
	if current_choices.is_empty():
		return
	selected_index = (selected_index + delta_index) % current_choices.size()


func _get_card_index_at(position: Vector2, view_size: Vector2) -> int:
	var card_rects: Array = get_card_rects(view_size)
	for index in range(card_rects.size()):
		var rect: Rect2 = card_rects[index]
		if rect.has_point(position):
			return index
	return -1


func choose_selected(owner: Object, registry: Object) -> void:
	if not is_selectable():
		return
	if selected_index < 0 or selected_index >= current_choices.size():
		return
	var choice: Dictionary = current_choices[selected_index]
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "":
		return

	if not apply_choice(choice, owner, registry):
		feedback_text = "선택을 적용할 수 없습니다"
		feedback_timer = 1.4
		return

	last_selected_id = choice_id
	pending_skill_choices = max(0, pending_skill_choices - 1)
	choice_active = false
	current_choices.clear()
	animation_time = 0.0

	var character_type := _get_character_type(owner)
	var catalog := _get_catalog(registry)
	if pending_skill_choices > 0 and catalog != null:
		open_next_choice(character_type, catalog)
	_sync_owner(owner)


func apply_choice(choice: Dictionary, owner: Object, registry: Object) -> bool:
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "":
		return false

	if choice_id == "convert_to_gold":
		gold_from_perks += int(choice.get("gold_amount", 500))
		feedback_text = "골드 +%d" % int(choice.get("gold_amount", 500))
		feedback_timer = 1.2
		_sync_owner(owner)
		return true

	if choice_id == "instant_gauge_full":
		_apply_full_gauge(owner, registry)
		feedback_text = "게이지 완충"
		feedback_timer = 1.2
		return true

	if choice_id == "common_refresh":
		runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		pending_skill_choices += 1
		feedback_text = "선택지 새로고침"
		feedback_timer = 1.0
		return true

	if choice_id == "star_change":
		runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		starpoint_for_skills += 3
		while starpoint_for_skills >= STARPOINT_PER_SKILL_CHOICE:
			starpoint_for_skills -= STARPOINT_PER_SKILL_CHOICE
			pending_skill_choices += 1
		feedback_text = "스타포인트 +3"
		feedback_timer = 1.0
		return true

	if str(choice.get("is_instant", "")) == "true" or bool(choice.get("is_instant", false)):
		feedback_text = str(choice.get("name", choice_id))
		feedback_timer = 1.0
		return true

	var old_level: int = int(runtime_skill_levels.get(choice_id, 0))
	runtime_skill_levels[choice_id] = old_level + 1
	_apply_level_side_effect(choice, owner, registry)
	feedback_text = "%s Lv.%d" % [str(choice.get("name", choice_id)), old_level + 1]
	feedback_timer = 1.1
	return true


func get_card_rects(view_size: Vector2) -> Array:
	var layout: Dictionary = build_layout(view_size)
	var rects: Array = []
	var card_size: Vector2 = _get_vector2(layout.get("card_size", Vector2(176.0, 116.0)))
	var start: Vector2 = _get_vector2(layout.get("cards_start", Vector2.ZERO))
	var gap: float = float(layout.get("card_gap", 14.0))
	for i in range(current_choices.size()):
		var offset := _get_card_offset(i)
		rects.append(Rect2(start + Vector2(float(i) * (card_size.x + gap), 0.0) + offset, card_size))
	return rects


func build_layout(view_size: Vector2) -> Dictionary:
	var card_count: int = max(1, current_choices.size())
	var game_width: float = min(760.0, max(360.0, view_size.x - 96.0))
	var card_gap: float = 14.0
	var card_width: float = 176.0
	var card_height: float = 116.0
	var total_width: float = card_width * float(card_count) + card_gap * float(max(0, card_count - 1))
	if total_width > game_width:
		var scale_factor: float = game_width / total_width
		card_width = floor(card_width * scale_factor)
		card_height = floor(card_height * scale_factor)
		card_gap = max(8.0, floor(card_gap * scale_factor))
		total_width = card_width * float(card_count) + card_gap * float(max(0, card_count - 1))
	var title_to_card: float = 72.0
	var desc_gap: float = 18.0
	var desc_h: float = 92.0
	var panel_gap: float = 14.0
	var panel_h: float = 158.0
	var hint_gap: float = 34.0
	var group_h: float = title_to_card + card_height + desc_gap + desc_h + panel_gap + panel_h + hint_gap + 18.0
	var group_top: float = max(48.0, floor((view_size.y - group_h) * 0.5))
	var card_y: float = group_top + title_to_card
	var card_x: float = floor((view_size.x - total_width) * 0.5)
	var desc_y: float = card_y + card_height + desc_gap
	var panel_y: float = desc_y + desc_h + panel_gap
	var panel_w: float = min(game_width, total_width + 128.0)
	return {
		"card_size": Vector2(card_width, card_height),
		"card_gap": card_gap,
		"cards_start": Vector2(card_x, card_y),
		"total_width": total_width,
		"desc_rect": Rect2(Vector2(card_x, desc_y), Vector2(total_width, desc_h)),
		"panel_rect": Rect2(Vector2(max(20.0, (view_size.x - panel_w) * 0.5), panel_y), Vector2(panel_w, panel_h)),
		"title_pos": Vector2(view_size.x * 0.5, group_top + 32.0),
		"hint_pos": Vector2(view_size.x * 0.5, panel_y + panel_h + hint_gap),
	}


func get_snapshot() -> Dictionary:
	return {
		"runtime_skill_levels": runtime_skill_levels.duplicate(true),
		"starpoint_for_skills": starpoint_for_skills,
		"pending_skill_choices": pending_skill_choices,
		"choice_active": choice_active,
		"current_choices": current_choices.duplicate(true),
		"selected_index": selected_index,
		"animation_time": animation_time,
		"particles": particles,
		"gold_from_perks": gold_from_perks,
		"feedback_text": feedback_text,
		"feedback_timer": feedback_timer,
		"last_selected_id": last_selected_id,
	}


func get_runtime_skill_level(skill_id: String) -> int:
	return int(runtime_skill_levels.get(skill_id, 0))


func get_runtime_skill_bonus(skill_id: String) -> float:
	var level: int = get_runtime_skill_level(skill_id)
	match skill_id:
		"dash_lightweight":
			return float(level) * 0.12
		"dash_module_control":
			return float(level) * 0.18
		"dash_jump":
			return float(level) * 0.07
		"dash_amplification":
			return float(level)
		"common_swiftness":
			return float(level) * 0.06
		"common_bulk_up":
			return float(level) * 0.06
		"common_training":
			return float(level) * 0.08
	return 0.0


func _apply_level_side_effect(choice: Dictionary, owner: Object, registry: Object) -> void:
	var choice_id: String = str(choice.get("id", ""))
	if owner == null:
		return
	if choice_id == "common_bulk_up":
		var scale: float = 1.0 + get_runtime_skill_bonus("common_bulk_up")
		owner.set("player_paddle_width", PLAYER_BASE_PADDLE_WIDTH * scale)
		owner.set("player_paddle_scale", scale)
	elif choice_id == "dash_amplification":
		var dash_state: Object = _get_instance(registry, "smasher_dash_state")
		if dash_state != null and dash_state.has_method("reset_full"):
			dash_state.reset_full(1 + int(get_runtime_skill_bonus("dash_amplification")))

	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill != "":
		var character_type: String = str(choice.get("character_restriction", _get_character_type(owner)))
		var config_key: String = "viper_skill_config" if character_type == "viper" else "smasher_skill_config"
		var skill_config: Object = _get_instance(registry, config_key)
		if skill_config != null and skill_config.has_method("unlock_and_equip_skill"):
			skill_config.unlock_and_equip_skill(unlocked_skill)


func _apply_full_gauge(owner: Object, registry: Object) -> void:
	if owner != null:
		owner.set("special_gauge", SPECIAL_GAUGE_MAX)
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("refill_tokens"):
		dash_state.refill_tokens()
	var character_type: String = _get_character_type(owner)
	var skill_state_key: String = "viper_skill_state" if character_type == "viper" else "smasher_skill_state"
	var skill_state: Object = _get_instance(registry, skill_state_key)
	if skill_state != null and skill_state.has_method("reset_cooldowns"):
		skill_state.reset_cooldowns()


func _sync_owner(owner: Object) -> void:
	if owner == null:
		return
	owner.set("runtime_perk_levels", runtime_skill_levels.duplicate(true))
	owner.set("runtime_perk_pending_choices", pending_skill_choices)
	owner.set("runtime_perk_starpoints", starpoint_for_skills)
	owner.set("runtime_perk_gold", gold_from_perks)
	owner.set("runtime_perk_choice_active", choice_active)


func _get_card_offset(index: int) -> Vector2:
	var progress: float = clamp(animation_time / 0.28, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	if index == 1:
		return Vector2(0.0, -260.0 * (1.0 - eased))
	if index % 2 == 0:
		return Vector2(-260.0 * (1.0 - eased), 0.0)
	return Vector2(260.0 * (1.0 - eased), 0.0)


func _build_particles() -> void:
	particles.clear()
	for _i in range(PARTICLE_COUNT):
		particles.append({})


func _reset_particle(particle: Dictionary, view_size: Vector2) -> void:
	var center_x: float = view_size.x * 0.5
	var x: float = randf_range(center_x - 280.0, center_x + 280.0)
	var y: float = randf_range(80.0, max(100.0, view_size.y * 0.64))
	particle["position"] = Vector2(x, y)
	particle["velocity"] = Vector2(randf_range(-24.0, 24.0), randf_range(-92.0, -22.0))
	particle["age"] = randf_range(0.0, PARTICLE_LIFE * 0.65)
	particle["size"] = randf_range(2.0, 5.5)
	particle["color"] = [
		Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		Color(1.0, 220.0 / 255.0, 100.0 / 255.0),
		Color(150.0 / 255.0, 1.0, 150.0 / 255.0),
		Color(1.0, 150.0 / 255.0, 200.0 / 255.0),
	][randi() % 4]


func _get_catalog(registry: Object) -> Object:
	return _get_instance(registry, "runtime_perk_catalog")


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	return "smasher"


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
