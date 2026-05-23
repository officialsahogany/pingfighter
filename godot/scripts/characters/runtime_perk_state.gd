extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const Stage1PillarUILayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const STARPOINT_PER_SKILL_CHOICE := 1
const BASE_PERK_CHOICE_COUNT := 3
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const SPECIAL_GAUGE_MAX := 500.0
const BASE_ACTIVE_ITEM_SLOT_LIMIT := 3
const MIN_DASH_RECHARGE_FRAMES := 6.0
const MIN_DASH_RECOVERY_FRAMES := 1.0
const MIN_ITEM_SPAWN_DELAY_MSEC := 1
const PARTICLE_COUNT := 20
const PARTICLE_LIFE := 1.45
const ACTIVE_UNLOCK_FLIGHT_DURATION := 1.86
const ACTIVE_UNLOCK_FLIGHT_PARTICLE_COUNT := 18
const PERK_RESUME_FREEZE_FRAMES := 10.0
const PERK_RESUME_RECOVERY_FRAMES := 60.0
const PERK_RESUME_MIN_SPEED_RATIO := 0.30
const VIPER_IGNITION_AURA_LEVEL_BONUS := 2
const VIPER_IGNITION_AURA_GOLD_BONUS := 50
const ITEM_CAFFEINE_ID := "item_caffeine"
const ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL := 0.30
const ITEM_POLISH_ID := "item_polish"
const ITEM_POLISH_ROLL_BONUS_PER_LEVEL := 0.12
const ITEM_RECYCLE_ID := "item_recycle"
const ITEM_RECYCLE_CHANCE_PER_LEVEL := 0.07
const MAX_ITEM_RECYCLE_CHANCE := 0.90
const PERK_LAUREL_SHIELD_ID := "perk_laurel_shield"
const DASH_ACCELERATION_ID := "dash_acceleration"
const DASH_ACCELERATION_BONUS_PER_LEVEL := 0.70
const DOWNTOWN_TREASURE_MAP_ID := "downtown_treasure_map"
const TREASURE_MAP_FIELD_MYTHIC_BONUS_PER_LEVEL := 1.50
const TREASURE_MAP_PASSIVE_DROP_SHARE_BONUS_PER_LEVEL := 0.03
const TREASURE_MAP_HUNT_LEGENDARY_BONUS_PER_LEVEL := 0.03
const VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS := {
	"unlock_magnum_grip": true,
	"unlock_plasma": true,
	"unlock_recovery": true,
	"unlock_cleanse": true,
	"unlock_shield_kiting": true,
	"unlock_ghost_shot": true,
	"unlock_warp_gate": true,
	"unlock_smasher_wheel": true,
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
}

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
var item_gold_gain_multiplier := 1.0
var item_perk_level_bonus := 0
var resume_freeze_timer_frames := 0.0
var resume_recovery_timer_frames := 0.0
var resume_original_ball_vel := Vector2.ZERO
var resume_pre_choice_ball_vel := Vector2.ZERO
var resume_has_original_ball_vel := false
var resume_has_pre_choice_ball_vel := false
var viper_ignition_aura_active := false
var viper_ignition_aura_owner_sync_dirty := false
var pending_unlock_swap: Dictionary = {}
var unlock_swap_selected_index := 0
var choice_flight_effect: Dictionary = {}
var gamepad_choice_horizontal_latch := 0
var gamepad_unlock_swap_horizontal_latch := 0
var _flight_scene_config: Object = BattleSceneConfig.new()
var _flight_view_layout: Object = BattleViewLayout.new()
var _flight_pillar_layout: Object = Stage1PillarUILayout.new()
var _flight_orb_positioner: Object = SmasherSkillOrbRenderer.new()


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
	item_gold_gain_multiplier = 1.0
	item_perk_level_bonus = 0
	viper_ignition_aura_active = false
	viper_ignition_aura_owner_sync_dirty = false
	pending_unlock_swap.clear()
	unlock_swap_selected_index = 0
	choice_flight_effect.clear()
	gamepad_choice_horizontal_latch = 0
	gamepad_unlock_swap_horizontal_latch = 0
	_clear_resume_safety()
	resume_pre_choice_ball_vel = Vector2.ZERO
	resume_has_pre_choice_ball_vel = false


func collect_star_points(
	amount: int,
	character_type: String,
	catalog: Object,
	owner: Object = null,
	registry: Object = null,
	defer_choice_open: bool = false
) -> bool:
	starpoint_for_skills += max(0, amount)
	while starpoint_for_skills >= STARPOINT_PER_SKILL_CHOICE:
		starpoint_for_skills -= STARPOINT_PER_SKILL_CHOICE
		pending_skill_choices += 1
		_reset_megingjord_extra_pick_count(owner, registry)
	feedback_text = "스타포인트 +%d" % max(0, amount)
	feedback_timer = 1.0
	if pending_skill_choices > 0 and not choice_active and not defer_choice_open:
		_capture_resume_pre_choice_velocity(owner)
		open_next_choice(character_type, catalog, false, owner, registry)
		if not choice_active:
			resume_has_pre_choice_ball_vel = false
	_sync_owner(owner)
	return choice_active


func open_next_choice(
	character_type: String,
	catalog: Object,
	exclude_instant: bool = false,
	owner: Object = null,
	registry: Object = null,
	perf_logger: Object = null
) -> void:
	choice_flight_effect.clear()
	if pending_skill_choices <= 0:
		choice_active = false
		current_choices.clear()
		return
	if catalog == null or not catalog.has_method("get_choices"):
		choice_active = false
		return

	var sample_start: int = _perf_begin(perf_logger)
	var item_bonus_choice_count: int = _get_item_perk_choice_count_bonus(owner, registry)
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.item_bonus", sample_start)
	var target_choice_count: int = max(0, BASE_PERK_CHOICE_COUNT + item_bonus_choice_count)
	sample_start = _perf_begin(perf_logger)
	current_choices = catalog.get_choices(character_type, runtime_skill_levels, exclude_instant, target_choice_count)
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.catalog", sample_start)
	if current_choices.is_empty():
		pending_skill_choices = max(0, pending_skill_choices - 1)
		choice_active = pending_skill_choices > 0
		if choice_active:
			open_next_choice(character_type, catalog, exclude_instant, owner, registry)
		return
	if item_bonus_choice_count > 0 and current_choices.size() >= target_choice_count + 1:
		var bonus_card_index: int = current_choices.size() - 2
		var bonus_choice: Dictionary = current_choices[bonus_card_index]
		bonus_choice["is_dowsing_goggles_bonus"] = true
		bonus_choice["bonus_source_item"] = "dowsing_goggles"
		current_choices[bonus_card_index] = bonus_choice
		feedback_text = "다우징 고글: 추가 퍽 등장!"
		feedback_timer = max(feedback_timer, 1.25)

	selected_index = min(1, current_choices.size() - 1)
	gamepad_choice_horizontal_latch = 0
	animation_time = 0.0
	choice_active = true
	sample_start = _perf_begin(perf_logger)
	_build_particles()
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.particles", sample_start)


func is_choice_active() -> bool:
	return choice_active or has_pending_unlock_swap()


func is_selectable() -> bool:
	return choice_active and not is_choice_flight_active() and not has_pending_unlock_swap() and animation_time >= 0.24 and not current_choices.is_empty()


func is_choice_flight_active() -> bool:
	return bool(choice_flight_effect.get("active", false))


func has_pending_unlock_swap() -> bool:
	return not pending_unlock_swap.is_empty()


func get_pending_unlock_swap() -> Dictionary:
	return pending_unlock_swap.duplicate(true)


func get_unlock_swap_selected_index() -> int:
	return unlock_swap_selected_index


func has_feedback() -> bool:
	return feedback_timer > 0.0 and feedback_text != ""


func update(delta: float, view_size: Vector2, owner: Object = null, registry: Object = null) -> void:
	_update_internal(delta, view_size, owner, registry, null)


func update_with_perf(delta: float, view_size: Vector2, owner: Object = null, registry: Object = null, perf_logger: Object = null) -> void:
	_update_internal(delta, view_size, owner, registry, perf_logger)


func _update_internal(delta: float, view_size: Vector2, owner: Object, registry: Object, perf_logger: Object) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	if feedback_timer > 0.0:
		feedback_timer = max(0.0, feedback_timer - delta)
		if feedback_timer <= 0.0:
			feedback_text = ""
	_perf_end(perf_logger, "process.runtime_perk.feedback", sample_start)
	sample_start = _perf_begin(perf_logger)
	if is_choice_flight_active():
		_update_choice_flight_effect(delta, owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.flight", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not choice_active:
		_perf_end(perf_logger, "process.runtime_perk.active_gate", sample_start)
		return
	animation_time += delta
	_perf_end(perf_logger, "process.runtime_perk.active_gate", sample_start)
	sample_start = _perf_begin(perf_logger)
	var left: float = max(0.0, view_size.x * 0.5 - 300.0)
	var right: float = min(view_size.x, view_size.x * 0.5 + 300.0)
	for particle in particles:
		var data: Dictionary = particle
		data["age"] = float(data.get("age", 0.0)) + delta
		data["position"] = _get_vector2(data.get("position", Vector2.ZERO)) + _get_vector2(data.get("velocity", Vector2.ZERO)) * delta
		var pos: Vector2 = _get_vector2(data.get("position", Vector2.ZERO))
		if pos.x < left or pos.x > right or float(data.get("age", 0.0)) > PARTICLE_LIFE:
			_reset_particle(data, view_size)
	_perf_end(perf_logger, "process.runtime_perk.particles", sample_start)


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not is_choice_active():
		return false
	if is_choice_flight_active():
		return true
	if has_pending_unlock_swap():
		return _handle_unlock_swap_input(event, owner, registry, view_size)
	if GamepadInput.is_gamepad_event(event):
		var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
		var navigation_direction := _consume_gamepad_choice_navigation(event, horizontal_direction)
		if navigation_direction != 0:
			move_selection(navigation_direction)
			return true
		if GamepadInput.is_confirm_event(event):
			choose_selected(owner, registry, view_size)
			return true
		return true
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
				choose_selected(owner, registry, view_size)
				return true
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return true
		var clicked_index: int = _get_card_index_at(mouse_event.position, view_size)
		if clicked_index >= 0:
			selected_index = clicked_index
			choose_selected(owner, registry, view_size)
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
	selected_index = posmod(selected_index + delta_index, current_choices.size())


func _consume_gamepad_choice_navigation(event: InputEvent, direction: int) -> int:
	return _consume_gamepad_horizontal_latch(event, direction, false)


func _consume_gamepad_unlock_swap_navigation(event: InputEvent, direction: int) -> int:
	return _consume_gamepad_horizontal_latch(event, direction, true)


func _consume_gamepad_horizontal_latch(event: InputEvent, direction: int, unlock_swap: bool) -> int:
	if not (event is InputEventJoypadMotion):
		return direction
	var motion_event: InputEventJoypadMotion = event
	if motion_event.axis != JOY_AXIS_LEFT_X:
		return direction
	if absf(motion_event.axis_value) <= GamepadInput.MENU_AXIS_RELEASE_THRESHOLD:
		if unlock_swap:
			gamepad_unlock_swap_horizontal_latch = 0
		else:
			gamepad_choice_horizontal_latch = 0
		return 0
	if direction == 0:
		return 0
	var current_latch := gamepad_unlock_swap_horizontal_latch if unlock_swap else gamepad_choice_horizontal_latch
	if current_latch == direction:
		return 0
	if unlock_swap:
		gamepad_unlock_swap_horizontal_latch = direction
	else:
		gamepad_choice_horizontal_latch = direction
	return direction


func _get_card_index_at(position: Vector2, view_size: Vector2) -> int:
	var card_rects: Array = get_card_rects(view_size)
	for index in range(card_rects.size()):
		var rect: Rect2 = card_rects[index]
		if rect.has_point(position):
			return index
	return -1


func build_unlock_swap_layout(view_size: Vector2) -> Dictionary:
	var swap: Dictionary = pending_unlock_swap
	var candidates: Array = _get_array(swap.get("candidates", []))
	var card_count: int = max(1, candidates.size())
	var card_width := 184.0
	var card_height := 116.0
	var gap := 14.0
	var max_width: float = min(760.0, max(360.0, view_size.x - 96.0))
	var total_width: float = card_width * float(card_count) + gap * float(max(0, card_count - 1))
	if total_width > max_width:
		var scale_factor: float = max_width / total_width
		card_width = floor(card_width * scale_factor)
		card_height = floor(card_height * scale_factor)
		gap = max(8.0, floor(gap * scale_factor))
		total_width = card_width * float(card_count) + gap * float(max(0, card_count - 1))
	var panel_height := 292.0
	var panel_width: float = min(max_width + 72.0, total_width + 96.0)
	var panel_pos := Vector2(floor((view_size.x - panel_width) * 0.5), floor((view_size.y - panel_height) * 0.5))
	var cards_start := Vector2(floor((view_size.x - total_width) * 0.5), panel_pos.y + 106.0)
	return {
		"panel_rect": Rect2(panel_pos, Vector2(panel_width, panel_height)),
		"title_pos": panel_pos + Vector2(panel_width * 0.5, 38.0),
		"new_skill_pos": panel_pos + Vector2(panel_width * 0.5, 70.0),
		"cards_start": cards_start,
		"card_size": Vector2(card_width, card_height),
		"card_gap": gap,
		"hint_pos": panel_pos + Vector2(panel_width * 0.5, panel_height - 34.0),
	}


func get_unlock_swap_option_rects(view_size: Vector2) -> Array:
	var layout: Dictionary = build_unlock_swap_layout(view_size)
	var candidates: Array = _get_array(pending_unlock_swap.get("candidates", []))
	var card_size: Vector2 = _get_vector2(layout.get("card_size", Vector2(184.0, 116.0)))
	var start: Vector2 = _get_vector2(layout.get("cards_start", Vector2.ZERO))
	var gap: float = float(layout.get("card_gap", 14.0))
	var rects: Array = []
	for index in range(candidates.size()):
		rects.append(Rect2(start + Vector2(float(index) * (card_size.x + gap), 0.0), card_size))
	return rects


func _get_unlock_swap_index_at(position: Vector2, view_size: Vector2) -> int:
	var rects: Array = get_unlock_swap_option_rects(view_size)
	for index in range(rects.size()):
		var rect: Rect2 = rects[index]
		if rect.has_point(position):
			return index
	return -1


func _handle_unlock_swap_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if GamepadInput.is_gamepad_event(event):
		var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
		var navigation_direction := _consume_gamepad_unlock_swap_navigation(event, horizontal_direction)
		if navigation_direction != 0:
			move_unlock_swap_selection(navigation_direction)
			return true
		if GamepadInput.is_confirm_event(event):
			confirm_pending_unlock_swap(owner, registry)
			return true
		if GamepadInput.is_cancel_event(event):
			cancel_pending_unlock_swap(owner)
			return true
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		match key_event.keycode:
			KEY_LEFT:
				move_unlock_swap_selection(-1)
				return true
			KEY_RIGHT:
				move_unlock_swap_selection(1)
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
				confirm_pending_unlock_swap(owner, registry)
				return true
			KEY_ESCAPE, KEY_X:
				cancel_pending_unlock_swap(owner)
				return true
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return true
		var clicked_index: int = _get_unlock_swap_index_at(mouse_event.position, view_size)
		if clicked_index >= 0:
			unlock_swap_selected_index = clicked_index
			confirm_pending_unlock_swap(owner, registry)
		return true
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var hovered_index: int = _get_unlock_swap_index_at(motion_event.position, view_size)
		if hovered_index >= 0:
			unlock_swap_selected_index = hovered_index
		return true
	return true


func move_unlock_swap_selection(delta_index: int) -> void:
	var candidates: Array = _get_array(pending_unlock_swap.get("candidates", []))
	if candidates.is_empty():
		return
	unlock_swap_selected_index = posmod(unlock_swap_selected_index + delta_index, candidates.size())


func choose_selected(owner: Object, registry: Object, view_size: Vector2 = Vector2.ZERO) -> void:
	if not is_selectable():
		return
	if selected_index < 0 or selected_index >= current_choices.size():
		return
	var choice: Dictionary = current_choices[selected_index]
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "":
		return

	if _try_start_active_unlock_flight(choice, owner, registry, view_size):
		return

	if not apply_choice(choice, owner, registry):
		if has_pending_unlock_swap():
			feedback_text = ""
			feedback_timer = 0.0
			return
		feedback_text = "선택을 적용할 수 없습니다"
		feedback_timer = 1.4
		return

	_finish_successful_choice(choice_id, owner, registry)


func _try_start_active_unlock_flight(choice: Dictionary, owner: Object, registry: Object, view_size: Vector2) -> bool:
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill == "" or view_size == Vector2.ZERO:
		return false
	var target: Dictionary = _resolve_unlock_flight_target(choice, owner, registry, view_size)
	if target.is_empty():
		return false
	var rects: Array = get_card_rects(view_size)
	if selected_index < 0 or selected_index >= rects.size():
		return false
	var source_rect: Rect2 = rects[selected_index]
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	var source_pos: Vector2 = source_rect.get_center()
	var target_pos: Vector2 = _get_vector2(target.get("target_pos", Vector2.ZERO))
	if source_pos == Vector2.ZERO or target_pos == Vector2.ZERO:
		return false
	var color: Color = _get_color(choice.get("icon_color", Color(100.0 / 255.0, 180.0 / 255.0, 1.0)))
	choice_flight_effect = {
		"active": true,
		"age": 0.0,
		"duration": ACTIVE_UNLOCK_FLIGHT_DURATION,
		"choice": choice.duplicate(true),
		"choice_id": str(choice.get("id", "")),
		"skill_id": unlocked_skill,
		"character_type": str(target.get("character_type", _get_character_type(owner))),
		"source_pos": source_pos,
		"source_rect": source_rect,
		"target_pos": target_pos,
		"target_slot_index": int(target.get("slot_index", -1)),
		"icon_color": color,
		"particles": _build_choice_flight_particles(color),
	}
	_play_active_unlock_flight_audio(registry)
	return true


func _update_choice_flight_effect(delta: float, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	if choice_flight_effect.is_empty():
		return
	var age: float = max(0.0, float(choice_flight_effect.get("age", 0.0)) + max(0.0, delta))
	choice_flight_effect["age"] = age
	if age < float(choice_flight_effect.get("duration", ACTIVE_UNLOCK_FLIGHT_DURATION)):
		return
	if owner == null or registry == null:
		return
	var sample_start: int = _perf_begin(perf_logger)
	_finish_choice_flight_effect(owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.flight.finish", sample_start)


func _finish_choice_flight_effect(owner: Object, registry: Object, perf_logger: Object = null) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	var effect: Dictionary = choice_flight_effect.duplicate(true)
	choice_flight_effect.clear()
	_perf_end(perf_logger, "process.runtime_perk.flight.capture", sample_start)
	var choice: Dictionary = _get_dict(effect.get("choice", {}))
	var choice_id: String = str(effect.get("choice_id", choice.get("id", "")))
	if choice_id == "" or choice.is_empty():
		return
	sample_start = _perf_begin(perf_logger)
	var applied: bool = apply_choice(choice, owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.flight.apply_choice", sample_start)
	if not applied:
		if has_pending_unlock_swap():
			feedback_text = ""
			feedback_timer = 0.0
			return
		feedback_text = "선택을 적용할 수 없습니다"
		feedback_timer = 1.4
		return
	sample_start = _perf_begin(perf_logger)
	_finish_successful_choice(choice_id, owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.flight.finish_success", sample_start)


func _resolve_unlock_flight_target(choice: Dictionary, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill == "":
		return {}
	var character_type: String = _normalize_character_type(str(choice.get("character_restriction", _get_character_type(owner))))
	var skill_config: Object = _get_instance(registry, _get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return {}
	var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
	var equipped: Array = _get_array(snapshot.get("equipped_skills", []))
	var max_slots: int = max(1, int(snapshot.get("max_slots", 5)))
	var slot_index: int = equipped.find(unlocked_skill)
	if slot_index < 0:
		if equipped.size() >= max_slots:
			return {}
		slot_index = equipped.size()

	var layout_state: Dictionary = _build_flight_layout_state(registry, view_size)
	var game_offset: Vector2 = _get_vector2(layout_state.get("game_offset", Vector2.ZERO))
	var game_size: Vector2 = _get_vector2(layout_state.get("game_size", Vector2.ZERO))
	var height: float = float(layout_state.get("height", FIELD_HEIGHT))
	if game_size.x <= 0.0 or game_size.y <= 0.0 or height <= 0.0:
		return {}
	var pillar_layout: Dictionary = _flight_pillar_layout.build_layout(game_offset, game_size, {"height": height})
	var scale_factor: float = max(0.001, float(pillar_layout.get("scale_factor", game_size.y / height)))
	var left_center: Vector2 = _get_vector2(pillar_layout.get("left_center", Vector2.ZERO))
	var orb_radius: float = max(1.0, float(pillar_layout.get("orb_radius", 55.0 * scale_factor)))
	var slot_layout: Dictionary = _flight_pillar_layout.get_skill_orb_slot_layout(character_type)
	var positions: Array = _flight_orb_positioner.get_slot_positions(left_center, orb_radius, scale_factor, {
		"max_slots": max_slots,
		"skill_orb_radius": 24.0,
		"gauge_gap": 28.0,
		"orb_radius_base": 55.0,
		"slot_base_angle": slot_layout.get("base_angle", 165.0),
		"slot_angle_step": slot_layout.get("angle_step", 33.0),
	})
	if slot_index < 0 or slot_index >= positions.size():
		return {}
	var target_pos: Vector2 = _get_vector2(positions[slot_index])
	if target_pos == Vector2.ZERO:
		return {}
	return {
		"target_pos": target_pos,
		"slot_index": slot_index,
		"character_type": character_type,
	}


func _build_flight_layout_state(registry: Object, view_size: Vector2) -> Dictionary:
	var draw_context: Dictionary = _flight_scene_config.build_draw_context()
	var scene_config: Object = _get_instance(registry, "battle_scene_config")
	if scene_config != null and scene_config.has_method("build_draw_context"):
		draw_context = _get_dict(scene_config.build_draw_context())
	var width: float = float(draw_context.get("width", FIELD_WIDTH))
	var height: float = float(draw_context.get("height", FIELD_HEIGHT))
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module == null or not layout_module.has_method("build_game_layout"):
		layout_module = _flight_view_layout
	var layout: Dictionary = _get_dict(layout_module.build_game_layout(view_size, width, height))
	layout["width"] = width
	layout["height"] = height
	return layout


func _build_choice_flight_particles(color: Color) -> Array:
	var particles_out: Array = []
	for index in range(ACTIVE_UNLOCK_FLIGHT_PARTICLE_COUNT):
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


func _pseudo_unit(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 12.9898 + salt) * 43758.5453, 1.0)


func _play_active_unlock_flight_audio(registry: Object) -> void:
	var game_audio: Object = _get_instance(registry, "game_audio")
	if game_audio == null:
		return
	if game_audio.has_method("play_item_get"):
		game_audio.play_item_get()
	elif game_audio.has_method("play_runtime_perk_choice_open"):
		game_audio.play_runtime_perk_choice_open()


func _finish_successful_choice(choice_id: String, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	last_selected_id = choice_id
	pending_skill_choices = max(0, pending_skill_choices - 1)
	if _try_megingjord_extra_pick(choice_id, owner, registry):
		pending_skill_choices += 1
		feedback_text = "메긴기요르드 발동"
		feedback_timer = max(feedback_timer, 1.25)
	choice_active = false
	current_choices.clear()
	animation_time = 0.0
	_perf_end(perf_logger, "process.runtime_perk.finish_success.state", sample_start)

	var character_type := _get_character_type(owner)
	var catalog := _get_catalog(registry)
	if pending_skill_choices > 0 and catalog != null:
		sample_start = _perf_begin(perf_logger)
		open_next_choice(character_type, catalog, false, owner, registry, perf_logger)
		_perf_end(perf_logger, "process.runtime_perk.finish_success.open_next_choice", sample_start)
	if not choice_active and not has_pending_unlock_swap():
		sample_start = _perf_begin(perf_logger)
		_try_arm_resume_safety(owner, registry)
		_perf_end(perf_logger, "process.runtime_perk.finish_success.resume_safety", sample_start)
	sample_start = _perf_begin(perf_logger)
	_sync_owner(owner)
	_perf_end(perf_logger, "process.runtime_perk.finish_success.sync_owner", sample_start)


func update_resume_safety(owner: Object, registry: Object, delta: float) -> void:
	_refresh_viper_ignition_aura_owner_sync_if_needed(owner, registry)
	if resume_freeze_timer_frames <= 0.0 and resume_recovery_timer_frames <= 0.0:
		return
	if _is_stopwatch_active(registry):
		_clear_resume_safety()
		resume_has_pre_choice_ball_vel = false
		return

	var fps_scale: float = max(0.001, delta * 60.0)
	if resume_freeze_timer_frames > 0.0:
		resume_freeze_timer_frames = max(0.0, resume_freeze_timer_frames - fps_scale)
		if owner != null:
			owner.set("ball_vel", Vector2.ZERO)
			owner.set("player_collision_cooldown", max(float(_safe_owner_get(owner, "player_collision_cooldown", 0.0)), resume_freeze_timer_frames + 4.0))
		if resume_freeze_timer_frames <= 0.0:
			resume_recovery_timer_frames = PERK_RESUME_RECOVERY_FRAMES
			_apply_resume_recovery_velocity(owner, PERK_RESUME_MIN_SPEED_RATIO)
		return

	if resume_recovery_timer_frames > 0.0:
		resume_recovery_timer_frames = max(0.0, resume_recovery_timer_frames - fps_scale)
		var recovery_ratio: float = 1.0 - (resume_recovery_timer_frames / max(1.0, PERK_RESUME_RECOVERY_FRAMES))
		_apply_resume_recovery_velocity(owner, max(PERK_RESUME_MIN_SPEED_RATIO, recovery_ratio))
		if resume_recovery_timer_frames <= 0.0:
			_apply_resume_recovery_velocity(owner, 1.0)
			resume_has_original_ball_vel = false
			resume_original_ball_vel = Vector2.ZERO


func get_ball_resume_context() -> Dictionary:
	return {
		"perk_resume_score_blocking": resume_freeze_timer_frames > 0.0,
		"perk_resume_freeze_active": resume_freeze_timer_frames > 0.0,
		"perk_resume_recovery_active": resume_recovery_timer_frames > 0.0,
		"perk_resume_recovery_speed_ratio": _get_resume_recovery_speed_ratio(),
		"perk_resume_original_ball_vel": resume_original_ball_vel if resume_has_original_ball_vel else Vector2.ZERO,
	}


func consume_resume_velocity_for_stopwatch() -> Dictionary:
	var resume_vel: Vector2 = Vector2.ZERO
	if resume_has_original_ball_vel:
		resume_vel = resume_original_ball_vel
	elif resume_has_pre_choice_ball_vel:
		resume_vel = resume_pre_choice_ball_vel
	if resume_vel.length() <= 0.01:
		return {}
	_clear_resume_safety()
	resume_has_pre_choice_ball_vel = false
	return {"ball_vel": resume_vel}


func apply_choice(choice: Dictionary, owner: Object, registry: Object, perf_logger: Object = null) -> bool:
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "":
		return false

	if choice_id == "convert_to_gold":
		var gold_amount: int = _apply_runtime_gold_gain_modifiers(int(choice.get("gold_amount", 500)))
		gold_from_perks += gold_amount
		feedback_text = "골드 +%d" % gold_amount
		feedback_timer = 1.2
		_sync_owner(owner)
		return true

	if choice_id == "instant_gauge_full":
		_apply_full_gauge(owner, registry)
		feedback_text = "게이지 완충"
		feedback_timer = 1.2
		return true

	if choice_id == "instant_dimension_gate":
		if not _apply_dimension_gate(registry):
			return false
		feedback_text = "차원개방"
		feedback_timer = 1.2
		return true

	if choice_id == "instant_monkey_blessing":
		if not _apply_monkey_blessing(owner, registry):
			return false
		feedback_text = str(choice.get("name", choice_id))
		feedback_timer = 1.1
		return true

	if choice_id == "instant_treasure_hunt":
		var treasure_result: Dictionary = _apply_treasure_hunt(owner, registry)
		if not bool(treasure_result.get("ok", false)):
			return false
		feedback_text = str(treasure_result.get("feedback_text", "보물탐색"))
		feedback_timer = 1.6
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

	if str(choice.get("unlocks_skill", "")) != "":
		var unlock_start: int = _perf_begin(perf_logger)
		var unlock_applied: bool = _apply_unlock_choice(choice, owner, registry, perf_logger)
		_perf_end(perf_logger, "process.runtime_perk.apply.unlock", unlock_start)
		return unlock_applied

	var old_level: int = int(runtime_skill_levels.get(choice_id, 0))
	runtime_skill_levels[choice_id] = old_level + 1
	var level_start: int = _perf_begin(perf_logger)
	_apply_level_side_effect(choice, owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.apply.level_side_effect", level_start)
	feedback_text = "%s Lv.%d" % [str(choice.get("name", choice_id)), old_level + 1]
	feedback_timer = 1.1
	return true


func get_card_rects(view_size: Vector2) -> Array:
	var layout: Dictionary = build_layout(view_size)
	var rects: Array = []
	var card_size: Vector2 = _get_vector2(layout.get("card_size", Vector2(250.0, 126.0)))
	var start: Vector2 = _get_vector2(layout.get("cards_start", Vector2.ZERO))
	var gap: float = float(layout.get("card_gap", 16.0))
	for i in range(current_choices.size()):
		var offset := _get_card_offset(i)
		rects.append(Rect2(start + Vector2(float(i) * (card_size.x + gap), 0.0) + offset, card_size))
	return rects


func build_layout(view_size: Vector2) -> Dictionary:
	var card_count: int = max(1, current_choices.size())
	var game_width: float = min(1120.0, max(420.0, view_size.x - 128.0))
	var card_gap: float = 16.0
	var card_width: float = 250.0
	var card_height: float = 126.0
	var total_width: float = card_width * float(card_count) + card_gap * float(max(0, card_count - 1))
	if total_width > game_width:
		var scale_factor: float = game_width / total_width
		card_width = floor(card_width * scale_factor)
		card_height = floor(card_height * scale_factor)
		card_gap = max(8.0, floor(card_gap * scale_factor))
		total_width = card_width * float(card_count) + card_gap * float(max(0, card_count - 1))
	var title_to_card: float = 72.0
	var desc_gap: float = 18.0
	var desc_h: float = 96.0
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
		"effective_runtime_skill_levels": get_effective_runtime_skill_levels(),
		"starpoint_for_skills": starpoint_for_skills,
		"pending_skill_choices": pending_skill_choices,
		"choice_active": choice_active,
		"current_choices": current_choices.duplicate(true),
		"selected_index": selected_index,
		"animation_time": animation_time,
		"particles": particles,
		"gold_from_perks": gold_from_perks,
		"item_gold_gain_multiplier": item_gold_gain_multiplier,
		"item_perk_level_bonus": item_perk_level_bonus,
		"viper_ignition_aura_active": viper_ignition_aura_active,
		"viper_ignition_aura_level_bonus": get_viper_ignition_aura_level_bonus(),
		"viper_ignition_aura_gold_bonus": get_viper_ignition_aura_gold_bonus(),
		"pending_unlock_swap": pending_unlock_swap.duplicate(true),
		"unlock_swap_selected_index": unlock_swap_selected_index,
		"choice_flight_effect": choice_flight_effect.duplicate(true),
		"feedback_text": feedback_text,
		"feedback_timer": feedback_timer,
		"last_selected_id": last_selected_id,
	}


func get_runtime_skill_level(skill_id: String) -> int:
	var base_level: int = int(runtime_skill_levels.get(skill_id, 0))
	if _is_runtime_level_bonus_eligible(skill_id, base_level):
		return base_level + item_perk_level_bonus + get_viper_ignition_aura_level_bonus()
	return base_level


func get_effective_runtime_skill_levels() -> Dictionary:
	var effective_levels: Dictionary = {}
	for skill_id_value in runtime_skill_levels.keys():
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(runtime_skill_levels.get(skill_id_value, 0))
		if base_level > 0:
			effective_levels[skill_id] = get_runtime_skill_level(skill_id)
	return effective_levels


func get_runtime_skill_bonus(skill_id: String) -> float:
	var level: int = get_runtime_skill_level(skill_id)
	match skill_id:
		"dash_lightweight":
			return float(level) * 0.12
		"dash_module_control":
			return float(level) * 0.18
		"dash_jump":
			return float(level) * 0.07
		DASH_ACCELERATION_ID:
			return float(level) * DASH_ACCELERATION_BONUS_PER_LEVEL
		"dash_spirit":
			return float(level) * 0.07
		"dash_amplification":
			return float(level)
		"item_luck":
			return float(level) * 0.12
		"item_cooldown_mastery":
			return float(level) * 0.13
		"item_gauge_mastery":
			return float(level) * 15.0
		"item_bag_expansion":
			return float(level)
		ITEM_CAFFEINE_ID:
			return float(level) * ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL
		ITEM_POLISH_ID:
			return float(level) * ITEM_POLISH_ROLL_BONUS_PER_LEVEL
		ITEM_RECYCLE_ID:
			return float(level) * ITEM_RECYCLE_CHANCE_PER_LEVEL
		DOWNTOWN_TREASURE_MAP_ID:
			return get_downtown_treasure_map_field_mythic_bonus()
		"common_swiftness":
			return float(level) * 0.06
		"common_expansion":
			return float(level)
		"common_bulk_up":
			return float(level) * 0.06
		"common_training":
			return float(level) * 0.08
		"perk_boost_charge":
			return float(level) * 7.0
		PERK_LAUREL_SHIELD_ID:
			return float(level)
	return 0.0


func get_dash_recharge_frames(base_frames: float) -> float:
	return max(MIN_DASH_RECHARGE_FRAMES, float(base_frames) * max(0.0, 1.0 - get_runtime_skill_bonus("dash_lightweight")))


func get_dash_recovery_frames(base_frames: float) -> float:
	return max(MIN_DASH_RECOVERY_FRAMES, float(base_frames) * max(0.0, 1.0 - get_runtime_skill_bonus("dash_module_control")))


func get_dash_duration_frames(base_frames: float) -> float:
	return max(1.0, float(base_frames) * (1.0 + get_runtime_skill_bonus("dash_jump")))


func get_item_spawn_delay_msec(base_delay_msec: int) -> int:
	var adjusted: float = float(max(0, base_delay_msec)) * max(0.0, 1.0 - get_runtime_skill_bonus("item_luck"))
	return max(MIN_ITEM_SPAWN_DELAY_MSEC, int(round(adjusted)))


func get_active_item_cooldown_msec(base_cooldown_msec: int) -> int:
	var adjusted: float = float(max(0, base_cooldown_msec)) * max(0.0, 1.0 - get_runtime_skill_bonus("item_cooldown_mastery"))
	return max(0, int(round(adjusted)))


func get_active_item_use_gauge_bonus() -> float:
	return max(0.0, get_runtime_skill_bonus("item_gauge_mastery"))


func get_active_item_slot_capacity(base_slots: int = BASE_ACTIVE_ITEM_SLOT_LIMIT) -> int:
	return max(1, int(base_slots) + int(get_runtime_skill_bonus("item_bag_expansion")))


func get_active_item_duration_bonus() -> float:
	return max(0.0, get_runtime_skill_bonus(ITEM_CAFFEINE_ID))


func get_active_item_duration_multiplier() -> float:
	return max(0.0, 1.0 + get_active_item_duration_bonus())


func get_active_item_duration_frames(base_duration_frames: float) -> float:
	if base_duration_frames <= 0.0:
		return 0.0
	return max(1.0, float(int(base_duration_frames * get_active_item_duration_multiplier())))


func get_active_item_recycle_chance() -> float:
	return clamp(get_runtime_skill_bonus(ITEM_RECYCLE_ID), 0.0, MAX_ITEM_RECYCLE_CHANCE)


func get_effective_polish_multiplier() -> float:
	return max(0.0, 1.0 + get_runtime_skill_bonus(ITEM_POLISH_ID))


func get_base_polish_multiplier() -> float:
	var base_level: int = max(0, int(runtime_skill_levels.get(ITEM_POLISH_ID, 0)))
	return max(0.0, 1.0 + float(base_level) * ITEM_POLISH_ROLL_BONUS_PER_LEVEL)


func get_downtown_treasure_map_field_mythic_bonus() -> float:
	return max(0.0, float(get_runtime_skill_level(DOWNTOWN_TREASURE_MAP_ID)) * TREASURE_MAP_FIELD_MYTHIC_BONUS_PER_LEVEL)


func get_downtown_treasure_map_field_mythic_multiplier() -> float:
	return 1.0 + get_downtown_treasure_map_field_mythic_bonus()


func get_downtown_treasure_map_passive_drop_share_bonus() -> float:
	return max(0.0, float(get_runtime_skill_level(DOWNTOWN_TREASURE_MAP_ID)) * TREASURE_MAP_PASSIVE_DROP_SHARE_BONUS_PER_LEVEL)


func get_treasure_hunt_legendary_chance_bonus() -> float:
	return max(0.0, float(get_runtime_skill_level(DOWNTOWN_TREASURE_MAP_ID)) * TREASURE_MAP_HUNT_LEGENDARY_BONUS_PER_LEVEL)


func get_treasure_hunt_legendary_chance(base_chance: float) -> float:
	return clamp(float(base_chance) + get_treasure_hunt_legendary_chance_bonus(), 0.0, 1.0)


func get_player_speed_multiplier() -> float:
	return max(0.0, 1.0 + get_runtime_skill_bonus("common_swiftness"))


func get_player_paddle_size_multiplier() -> float:
	return max(0.1, 1.0 + get_runtime_skill_bonus("common_bulk_up"))


func get_accessory_slot_bonus() -> int:
	return max(0, int(get_runtime_skill_bonus("common_expansion")))


func get_player_skill_cooldown_multiplier() -> float:
	return max(0.0, 1.0 - get_runtime_skill_bonus("common_training"))


func get_player_skill_cooldown_seconds(base_cooldown_seconds: float) -> float:
	return max(0.0, float(base_cooldown_seconds) * get_player_skill_cooldown_multiplier())


func get_boost_charge_chance_pct() -> float:
	return max(0.0, get_runtime_skill_bonus("perk_boost_charge"))


func get_dash_acceleration_level() -> int:
	return max(0, get_runtime_skill_level(DASH_ACCELERATION_ID))


func get_dash_acceleration_bonus() -> float:
	return max(0.0, get_runtime_skill_bonus(DASH_ACCELERATION_ID))


func get_dash_acceleration_height_bonus(base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	return max(0.0, float(base_height)) * get_dash_acceleration_bonus()


func get_laurel_leaf_count(registry: Object = null) -> int:
	var total_leaves: int = max(0, int(get_runtime_skill_level(PERK_LAUREL_SHIELD_ID)))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_sacred_laurel_leaf_bonus"):
		total_leaves += max(0, int(mythic_item_runtime.get_sacred_laurel_leaf_bonus()))
	return total_leaves


func award_gold(amount: int) -> int:
	var boosted_amount: int = _apply_runtime_gold_gain_modifiers(amount)
	gold_from_perks += boosted_amount
	if boosted_amount > 0:
		feedback_text = "퍽 골드 +%d" % boosted_amount
		feedback_timer = 1.0
	return gold_from_perks


func set_viper_ignition_aura_active(active: bool) -> void:
	if viper_ignition_aura_active == active:
		return
	viper_ignition_aura_active = active
	viper_ignition_aura_owner_sync_dirty = true


func is_viper_ignition_aura_active() -> bool:
	return viper_ignition_aura_active


func get_viper_ignition_aura_level_bonus() -> int:
	return VIPER_IGNITION_AURA_LEVEL_BONUS if viper_ignition_aura_active else 0


func get_viper_ignition_aura_gold_bonus() -> int:
	return VIPER_IGNITION_AURA_GOLD_BONUS if viper_ignition_aura_active else 0


func refresh_viper_ignition_aura_dynamic_effects(registry: Object, owner: Object = null) -> void:
	if owner != null:
		_sync_runtime_perk_owner_effects(owner, registry)
		viper_ignition_aura_owner_sync_dirty = false
		_refresh_item_polish_consumers(owner, registry)
		return
	_apply_training_to_skill_configs(registry)
	_refresh_item_polish_consumers(owner, registry)


func refresh_item_perk_level_bonus_dynamic_effects(registry: Object, owner: Object = null) -> void:
	if owner != null:
		_sync_runtime_perk_owner_effects(owner, registry)
		_refresh_item_polish_consumers(owner, registry)
		return
	_apply_training_to_skill_configs(registry)
	_refresh_item_polish_consumers(owner, registry)


func _is_runtime_level_bonus_eligible(skill_id: String, base_level: int) -> bool:
	if base_level <= 0:
		return false
	var clean_id: String = skill_id.strip_edges()
	if clean_id == "" or clean_id.begins_with("instant_"):
		return false
	return not bool(VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS.get(clean_id, false))


func _is_ignition_aura_level_bonus_eligible(skill_id: String, base_level: int) -> bool:
	return viper_ignition_aura_active and _is_runtime_level_bonus_eligible(skill_id, base_level)


func set_item_gold_gain_multiplier(multiplier: float) -> void:
	item_gold_gain_multiplier = max(0.0, float(multiplier))


func get_item_gold_gain_multiplier() -> float:
	return item_gold_gain_multiplier


func set_item_perk_level_bonus(bonus: int) -> bool:
	var next_bonus: int = max(0, int(bonus))
	if item_perk_level_bonus == next_bonus:
		return false
	item_perk_level_bonus = next_bonus
	return true


func get_item_perk_level_bonus() -> int:
	return item_perk_level_bonus


func _apply_item_gold_gain_bonus(amount: int) -> int:
	return int(floor(float(max(0, amount)) * item_gold_gain_multiplier))


func _apply_runtime_gold_gain_modifiers(amount: int) -> int:
	var base_amount: int = max(0, amount)
	if viper_ignition_aura_active and base_amount > 0:
		base_amount += VIPER_IGNITION_AURA_GOLD_BONUS
	return _apply_item_gold_gain_bonus(base_amount)


func _refresh_viper_ignition_aura_owner_sync_if_needed(owner: Object, registry: Object) -> void:
	if not viper_ignition_aura_owner_sync_dirty:
		return
	if owner == null:
		_apply_training_to_skill_configs(registry)
		return
	refresh_viper_ignition_aura_dynamic_effects(registry, owner)


func debug_set_perk_level(perk_id: String, target_level: int, owner: Object, registry: Object, catalog: Object) -> bool:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "":
		return false
	var data: Dictionary = catalog.get_perk_data(clean_id) if catalog != null and catalog.has_method("get_perk_data") else {}
	if data.is_empty():
		return false
	data["id"] = clean_id

	if bool(data.get("is_instant", false)) or clean_id == "convert_to_gold" or int(data.get("max_level", 1)) <= 0:
		data["current_level"] = 0
		data["next_level"] = 0
		if not apply_choice(data, owner, registry):
			return false
		last_selected_id = clean_id
		_sync_owner(owner)
		return true

	var max_level: int = max(1, int(data.get("max_level", 1)))
	var level: int = clampi(target_level, 1, max_level)
	if str(data.get("unlocks_skill", "")) != "":
		data["current_level"] = 0
		data["next_level"] = level
		if not _apply_unlock_choice(data, owner, registry):
			return false
		last_selected_id = clean_id
		_sync_owner(owner)
		return true
	runtime_skill_levels[clean_id] = level
	data["current_level"] = max(0, level - 1)
	data["next_level"] = level
	_apply_level_side_effect(data, owner, registry)
	feedback_text = "%s Lv.%d" % [str(data.get("name", clean_id)), level]
	feedback_timer = 1.1
	last_selected_id = clean_id
	_sync_owner(owner)
	return true


func _apply_unlock_choice(choice: Dictionary, owner: Object, registry: Object, perf_logger: Object = null) -> bool:
	var choice_id: String = str(choice.get("id", ""))
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if choice_id == "" or unlocked_skill == "":
		return false
	var character_type: String = str(choice.get("character_restriction", _get_character_type(owner)))
	var skill_config: Object = _get_instance(registry, _get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("unlock_and_equip_skill"):
		return false
	if _should_start_unlock_swap(skill_config, unlocked_skill, character_type):
		_start_pending_unlock_swap(choice, skill_config, owner)
		return false
	var sample_start: int = _perf_begin(perf_logger)
	if not bool(skill_config.unlock_and_equip_skill(unlocked_skill)):
		_perf_end(perf_logger, "process.runtime_perk.unlock.equip", sample_start)
		return false
	_perf_end(perf_logger, "process.runtime_perk.unlock.equip", sample_start)
	_commit_unlock_choice_level(choice)
	sample_start = _perf_begin(perf_logger)
	_sync_runtime_perk_owner_effects(owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.unlock.sync_owner_effects", sample_start)
	sample_start = _perf_begin(perf_logger)
	_sync_commando_weapon_controller(unlocked_skill, skill_config, registry, character_type)
	_perf_end(perf_logger, "process.runtime_perk.unlock.commando_sync", sample_start)
	feedback_text = "%s Lv.%d" % [str(choice.get("name", choice_id)), int(runtime_skill_levels.get(choice_id, 1))]
	feedback_timer = 1.1
	return true


func _should_start_unlock_swap(skill_config: Object, unlocked_skill: String, character_type: String) -> bool:
	if _normalize_character_type(character_type) != "soldier":
		return false
	if skill_config.has_method("is_skill_equipped") and bool(skill_config.is_skill_equipped(unlocked_skill)):
		return false
	if skill_config.has_method("is_shared_slot_full") and not bool(skill_config.is_shared_slot_full()):
		return false
	if skill_config.has_method("get_shared_slot_swap_candidates"):
		return not _get_array(skill_config.get_shared_slot_swap_candidates(unlocked_skill)).is_empty()
	return false


func _start_pending_unlock_swap(choice: Dictionary, skill_config: Object, owner: Object) -> bool:
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	var candidates: Array = []
	var raw_candidates: Array = []
	if skill_config.has_method("get_shared_slot_swap_candidates"):
		raw_candidates = _get_array(skill_config.get_shared_slot_swap_candidates(unlocked_skill))
	for value in raw_candidates:
		var skill_id := str(value)
		var skill_data: Dictionary = skill_config.get_skill_data(skill_id) if skill_config.has_method("get_skill_data") else {}
		candidates.append({
			"skill_id": skill_id,
			"name": str(skill_data.get("korean", skill_id)),
		})
	if candidates.is_empty():
		return false
	var new_skill_data: Dictionary = skill_config.get_skill_data(unlocked_skill) if skill_config.has_method("get_skill_data") else {}
	pending_unlock_swap = {
		"choice": choice.duplicate(true),
		"choice_id": str(choice.get("id", "")),
		"unlocks_skill": unlocked_skill,
		"new_name": str(new_skill_data.get("korean", choice.get("name", unlocked_skill))),
		"candidates": candidates,
	}
	unlock_swap_selected_index = 0
	_sync_owner(owner)
	return true


func cancel_pending_unlock_swap(owner: Object = null) -> bool:
	if pending_unlock_swap.is_empty():
		return false
	pending_unlock_swap.clear()
	unlock_swap_selected_index = 0
	feedback_text = "교체 취소"
	feedback_timer = 0.8
	_sync_owner(owner)
	return true


func confirm_pending_unlock_swap(owner: Object, registry: Object) -> bool:
	if pending_unlock_swap.is_empty():
		return false
	var choice: Dictionary = _get_dict(pending_unlock_swap.get("choice", {}))
	var choice_id: String = str(pending_unlock_swap.get("choice_id", choice.get("id", "")))
	var unlocked_skill: String = str(pending_unlock_swap.get("unlocks_skill", choice.get("unlocks_skill", "")))
	var candidates: Array = _get_array(pending_unlock_swap.get("candidates", []))
	if choice_id == "" or unlocked_skill == "" or candidates.is_empty():
		return false
	unlock_swap_selected_index = clampi(unlock_swap_selected_index, 0, candidates.size() - 1)
	var removed_skill: String = str(_get_dict(candidates[unlock_swap_selected_index]).get("skill_id", ""))
	if removed_skill == "":
		return false
	var character_type: String = str(choice.get("character_restriction", _get_character_type(owner)))
	var skill_config: Object = _get_instance(registry, _get_skill_config_key(character_type))
	if skill_config == null:
		return false
	var swapped := false
	if skill_config.has_method("swap_equipped_permanent"):
		swapped = bool(skill_config.swap_equipped_permanent(removed_skill, unlocked_skill))
	elif skill_config.has_method("unequip_skill") and skill_config.has_method("unlock_and_equip_skill"):
		swapped = bool(skill_config.unequip_skill(removed_skill)) and bool(skill_config.unlock_and_equip_skill(unlocked_skill))
	if not swapped:
		return false

	_remove_runtime_unlock_for_skill(removed_skill, registry)
	_commit_unlock_choice_level(choice)
	_sync_runtime_perk_owner_effects(owner, registry)
	_sync_commando_weapon_controller(unlocked_skill, skill_config, registry, character_type)
	pending_unlock_swap.clear()
	unlock_swap_selected_index = 0
	feedback_text = "%s 교체 완료" % str(choice.get("name", choice_id))
	feedback_timer = 1.1
	_finish_successful_choice(choice_id, owner, registry)
	return true


func _commit_unlock_choice_level(choice: Dictionary) -> void:
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "":
		return
	runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1


func _remove_runtime_unlock_for_skill(skill_id: String, registry: Object) -> void:
	var catalog: Object = _get_catalog(registry)
	var removed_perk_id := ""
	for perk_id in runtime_skill_levels.keys():
		var data: Dictionary = catalog.get_perk_data(str(perk_id)) if catalog != null and catalog.has_method("get_perk_data") else {}
		if str(data.get("unlocks_skill", "")) == skill_id:
			removed_perk_id = str(perk_id)
			break
	if removed_perk_id == "":
		var fallback_id := _get_commando_unlock_perk_id_for_skill(skill_id)
		if runtime_skill_levels.has(fallback_id):
			removed_perk_id = fallback_id
	if removed_perk_id != "":
		runtime_skill_levels.erase(removed_perk_id)


func _get_commando_unlock_perk_id_for_skill(skill_id: String) -> String:
	if skill_id == "commando_pistol":
		return "soldier_pistol_perk"
	return "soldier_unlock_%s" % skill_id


func _sync_commando_weapon_controller(unlocked_skill: String, skill_config: Object, registry: Object, character_type: String = "soldier") -> void:
	if _normalize_character_type(character_type) != "soldier":
		return
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null:
		return
	if weapon_controller.has_method("sync_equipped_permanent"):
		weapon_controller.sync_equipped_permanent(skill_config)
	elif weapon_controller.has_method("unlock_permanent_weapon"):
		weapon_controller.unlock_permanent_weapon(unlocked_skill)


func _apply_level_side_effect(choice: Dictionary, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	var choice_id: String = str(choice.get("id", ""))
	if owner == null:
		return
	if choice_id == "dash_amplification":
		var dash_start: int = _perf_begin(perf_logger)
		var dash_state: Object = _get_instance(registry, "smasher_dash_state")
		if dash_state != null and dash_state.has_method("reset_full"):
			var max_tokens: int = 1 + int(get_runtime_skill_bonus("dash_amplification"))
			var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
			if mythic_item_runtime != null and mythic_item_runtime.has_method("get_dash_token_capacity"):
				max_tokens = int(mythic_item_runtime.get_dash_token_capacity(1, self))
			dash_state.reset_full(max_tokens)
		_perf_end(perf_logger, "process.runtime_perk.level.dash_amplification", dash_start)
	var sync_start: int = _perf_begin(perf_logger)
	_sync_runtime_perk_owner_effects(owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.level.sync_owner_effects", sync_start)
	if choice_id == ITEM_POLISH_ID:
		var polish_start: int = _perf_begin(perf_logger)
		_refresh_item_polish_consumers(owner, registry)
		_perf_end(perf_logger, "process.runtime_perk.level.polish_refresh", polish_start)

	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill != "":
		var character_type: String = str(choice.get("character_restriction", _get_character_type(owner)))
		var config_key: String = _get_skill_config_key(character_type)
		var skill_config: Object = _get_instance(registry, config_key)
		if skill_config != null and skill_config.has_method("unlock_and_equip_skill"):
			skill_config.unlock_and_equip_skill(unlocked_skill)
		if _normalize_character_type(character_type) == "soldier":
			var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
			if weapon_controller != null and weapon_controller.has_method("unlock_permanent_weapon"):
				weapon_controller.unlock_permanent_weapon(unlocked_skill)


func _apply_full_gauge(owner: Object, registry: Object) -> void:
	if owner != null:
		owner.set("special_gauge", SPECIAL_GAUGE_MAX)
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("refill_tokens"):
		dash_state.refill_tokens()
	var character_type: String = _get_character_type(owner)
	var skill_state_key: String = _get_skill_state_key(character_type)
	var skill_state: Object = _get_instance(registry, skill_state_key)
	if skill_state != null and skill_state.has_method("reset_cooldowns"):
		skill_state.reset_cooldowns()


func _apply_dimension_gate(registry: Object) -> bool:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("activate_dimension_gate"):
		return false
	return bool(active_item_runtime.activate_dimension_gate(registry))


func _apply_monkey_blessing(owner: Object, registry: Object) -> bool:
	if owner == null:
		return false
	var delivery_state: Object = _get_instance(registry, "monkey_blessing_delivery_state")
	if delivery_state != null and delivery_state.has_method("start"):
		return bool(delivery_state.start(owner, registry))
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("fill_empty_slots_with_item"):
		active_item_runtime.fill_empty_slots_with_item("banana", owner, registry)
	return true


func _apply_treasure_hunt(owner: Object, registry: Object) -> Dictionary:
	var treasure_runtime: Object = _get_instance(registry, "treasure_hunt_runtime")
	if treasure_runtime == null or not treasure_runtime.has_method("start"):
		return {"ok": false}
	return treasure_runtime.start(owner, registry)


func _reset_megingjord_extra_pick_count(owner: Object, registry: Object) -> void:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("on_new_perk_choice_batch"):
		mythic_item_runtime.on_new_perk_choice_batch(owner)


func _get_item_perk_choice_count_bonus(owner: Object, registry: Object) -> int:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("get_runtime_perk_choice_count_bonus"):
		return 0
	return max(0, int(mythic_item_runtime.get_runtime_perk_choice_count_bonus(owner, registry)))


func _try_megingjord_extra_pick(choice_id: String, owner: Object, registry: Object) -> bool:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_after_perk_choice"):
		return false
	return bool(mythic_item_runtime.try_after_perk_choice(choice_id, owner, registry))


func _capture_resume_pre_choice_velocity(owner: Object) -> void:
	if resume_has_pre_choice_ball_vel:
		return
	var resume_vel: Vector2 = _get_valid_resume_velocity(_safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	if resume_vel.length() < 0.5:
		return
	resume_pre_choice_ball_vel = resume_vel
	resume_has_pre_choice_ball_vel = true


func _try_arm_resume_safety(owner: Object, registry: Object) -> void:
	var resume_vel: Vector2 = Vector2.ZERO
	if resume_has_pre_choice_ball_vel:
		resume_vel = _get_valid_resume_velocity(resume_pre_choice_ball_vel)
	else:
		resume_vel = _get_valid_resume_velocity(_safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	resume_has_pre_choice_ball_vel = false
	resume_pre_choice_ball_vel = Vector2.ZERO

	if resume_vel.length() < 0.5:
		return
	if resume_vel.y <= 0.0:
		return
	if _is_stopwatch_active(registry):
		return
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return
	if resume_freeze_timer_frames > 0.0 or resume_recovery_timer_frames > 0.0:
		return

	resume_original_ball_vel = resume_vel
	resume_has_original_ball_vel = true
	resume_freeze_timer_frames = PERK_RESUME_FREEZE_FRAMES
	resume_recovery_timer_frames = 0.0
	if owner != null:
		owner.set("ball_vel", Vector2.ZERO)
		owner.set("player_collision_cooldown", max(float(_safe_owner_get(owner, "player_collision_cooldown", 0.0)), PERK_RESUME_FREEZE_FRAMES + 4.0))


func _apply_resume_recovery_velocity(owner: Object, speed_ratio: float) -> void:
	if owner == null or not resume_has_original_ball_vel:
		return
	var original_speed: float = resume_original_ball_vel.length()
	if original_speed <= 0.01:
		return
	var current_vel: Vector2 = _get_valid_resume_velocity(_safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	var direction: Vector2
	if current_vel.length() > 0.01:
		direction = current_vel.normalized()
	elif resume_original_ball_vel.length() > 0.01:
		direction = resume_original_ball_vel.normalized()
	else:
		direction = Vector2(0.0, 1.0)
	owner.set("ball_vel", direction * original_speed * clamp(speed_ratio, 0.0, 1.0))


func _get_resume_recovery_speed_ratio() -> float:
	if resume_recovery_timer_frames <= 0.0:
		return 1.0
	var recovery_ratio: float = 1.0 - (resume_recovery_timer_frames / max(1.0, PERK_RESUME_RECOVERY_FRAMES))
	return max(PERK_RESUME_MIN_SPEED_RATIO, recovery_ratio)


func _clear_resume_safety() -> void:
	resume_freeze_timer_frames = 0.0
	resume_recovery_timer_frames = 0.0
	resume_original_ball_vel = Vector2.ZERO
	resume_has_original_ball_vel = false


func _is_stopwatch_active(registry: Object) -> bool:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime == null:
		return false
	if active_item_runtime.has_method("get_ball_collision_context"):
		var context: Dictionary = active_item_runtime.get_ball_collision_context()
		return bool(context.get("stopwatch_score_blocking", false))
	return false


func _get_valid_resume_velocity(value: Variant) -> Vector2:
	if value is Vector2:
		if is_finite(value.x) and is_finite(value.y):
			return value
	return Vector2.ZERO


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _sync_owner(owner: Object) -> void:
	if owner == null:
		return
	owner.set("runtime_perk_levels", runtime_skill_levels.duplicate(true))
	owner.set("runtime_perk_effective_levels", get_effective_runtime_skill_levels())
	owner.set("runtime_perk_pending_choices", pending_skill_choices)
	owner.set("runtime_perk_starpoints", starpoint_for_skills)
	owner.set("runtime_perk_gold", gold_from_perks)
	owner.set("runtime_perk_choice_active", is_choice_active())
	owner.set("item_perk_level_bonus", item_perk_level_bonus)
	owner.set("viper_ignition_aura_active", viper_ignition_aura_active)


func _sync_runtime_perk_owner_effects(owner: Object, registry: Object, perf_logger: Object = null) -> void:
	if owner == null:
		return
	var sample_start: int = _perf_begin(perf_logger)
	owner.set("runtime_perk_effective_levels", get_effective_runtime_skill_levels())
	owner.set("runtime_accessory_slot_bonus", get_accessory_slot_bonus())
	owner.set("runtime_laurel_leaf_count", get_laurel_leaf_count(registry))
	_perf_end(perf_logger, "process.runtime_perk.sync_owner_effects.stats", sample_start)
	sample_start = _perf_begin(perf_logger)
	var perk_scale: float = get_player_paddle_size_multiplier()
	owner.set("runtime_paddle_scale", perk_scale)
	var base_width: float = _get_runtime_paddle_base_width(owner)
	var base_height: float = _get_runtime_paddle_base_height(owner)
	var active_item_scale: float = _get_active_item_paddle_scale(registry)
	var mythic_item_scale: float = _get_mythic_item_paddle_scale(registry)
	var final_scale: float = max(0.1, perk_scale * active_item_scale * mythic_item_scale)
	var current_width: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var current_height: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_pos_value: Variant = _safe_owner_get(owner, "player_pos", Vector2.ZERO)
	var next_width: float = base_width * final_scale
	var next_height: float = base_height * final_scale
	if player_pos_value is Vector2 and (not is_equal_approx(current_width, next_width) or not is_equal_approx(current_height, next_height)):
		var player_pos: Vector2 = player_pos_value
		var center_x: float = player_pos.x + current_width * 0.5
		player_pos.x = _clamp_synced_player_x(center_x - next_width * 0.5, next_width, _get_instance(registry, "smasher_warp_gate_state"))
		var current_bottom: float = player_pos.y + current_height
		if abs(current_bottom - FIELD_HEIGHT) <= max(2.0, current_height * 0.05) or current_bottom > FIELD_HEIGHT:
			player_pos.y = FIELD_HEIGHT - next_height
		owner.set("player_pos", player_pos)
	owner.set("player_paddle_width", next_width)
	owner.set("player_paddle_height", next_height)
	owner.set("player_paddle_scale", max(0.1, next_width / PLAYER_BASE_PADDLE_WIDTH))
	_perf_end(perf_logger, "process.runtime_perk.sync_owner_effects.paddle", sample_start)
	sample_start = _perf_begin(perf_logger)
	_apply_training_to_skill_configs(registry)
	_perf_end(perf_logger, "process.runtime_perk.sync_owner_effects.training", sample_start)


func _refresh_item_polish_consumers(owner: Object, registry: Object) -> void:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("refresh_runtime_perk_scaling"):
		mythic_item_runtime.refresh_runtime_perk_scaling(owner, registry)


func _get_active_item_paddle_scale(registry: Object) -> float:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_scale"):
		return max(0.1, float(active_item_runtime.get_player_paddle_scale()))
	return 1.0


func _get_mythic_item_paddle_scale(registry: Object) -> float:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_player_paddle_scale"):
		return max(0.1, float(mythic_item_runtime.get_player_paddle_scale()))
	return 1.0


func _get_runtime_paddle_base_width(owner: Object) -> float:
	return max(1.0, float(_safe_owner_get(owner, "runtime_paddle_base_width", PLAYER_BASE_PADDLE_WIDTH)))


func _get_runtime_paddle_base_height(owner: Object) -> float:
	return max(1.0, float(_safe_owner_get(owner, "runtime_paddle_base_height", PLAYER_BASE_PADDLE_HEIGHT)))


func _clamp_synced_player_x(x: float, paddle_width: float, warp_gate_state: Object) -> float:
	if warp_gate_state != null and warp_gate_state.has_method("is_active") and bool(warp_gate_state.is_active()):
		return clamp(x, -max(1.0, paddle_width), FIELD_WIDTH)
	return clamp(x, 0.0, max(0.0, FIELD_WIDTH - max(1.0, paddle_width)))


func _apply_training_to_skill_configs(registry: Object) -> void:
	var multiplier: float = get_player_skill_cooldown_multiplier()
	for key in ["smasher_skill_config", "viper_skill_config", "commando_skill_config"]:
		var skill_config: Object = _get_instance(registry, key)
		if skill_config != null and skill_config.has_method("set_runtime_cooldown_multiplier"):
			skill_config.set_runtime_cooldown_multiplier(multiplier)


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


func _get_skill_config_key(character_type: String) -> String:
	match _normalize_character_type(character_type):
		"viper":
			return "viper_skill_config"
		"soldier":
			return "commando_skill_config"
		"optimus":
			return ""
	return "smasher_skill_config"


func _get_skill_state_key(character_type: String) -> String:
	match _normalize_character_type(character_type):
		"viper":
			return "viper_skill_state"
		"soldier":
			return "commando_skill_state"
		"optimus":
			return ""
	return "smasher_skill_state"


func _normalize_character_type(character_type: String) -> String:
	var normalized: String = str(character_type).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	return "smasher"


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	return "smasher"


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
