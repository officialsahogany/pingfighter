extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const Stage1PillarUILayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")

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
const UNLOCK_SHOWCASE_MAX_AGE := 6.0
const UNLOCK_SHOWCASE_MIN_DISMISS_AGE := 0.3
# Starpoint absorption effect: plays after the perk choice modal fully closes
# (no more pending picks, no pending unlock swap) so the collected starpoint
# visually "absorbs" into the player body. Fires from above the player and
# spirals down into the paddle center with a sparkle trail and arrival burst.
const STARPOINT_ABSORPTION_DURATION := 0.70
const STARPOINT_ABSORPTION_PARTICLE_COUNT := 7
const STARPOINT_ABSORPTION_SOURCE_PLAYFIELD_OFFSET_Y := -120.0
const PERK_RESUME_FREEZE_FRAMES := 10.0
const PERK_RESUME_RECOVERY_FRAMES := 60.0
const PERK_RESUME_MIN_SPEED_RATIO := 0.30
const RALLY_GOLD_BASE := 4
const RALLY_GOLD_SPEED_BONUS_8 := 2
const RALLY_GOLD_SPEED_BONUS_12 := 4
const RALLY_GOLD_SPEED_BONUS_16 := 6
const RALLY_GOLD_SPEED_BONUS_20 := 8
const ENRAGED_BOSS_GOLD_MULTIPLIER := 1.50
const SMASHER_COMBO_GOLD_BONUS_PER_STACK := 0.08
const BLACKSMITH_STRUCTURE_GOLD_BONUS := 0.15
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
const CHOICE_CONTEXT_DEFER_DIMENSION_GATE_UNTIL_SPAWN_END := "defer_instant_dimension_gate_until_spawn_intro_end"
const CHOICE_CONTEXT_DEFER_FULL_GAUGE_UNTIL_SPAWN_END := "defer_instant_full_gauge_until_spawn_intro_end"
const DOWNTOWN_TREASURE_MAP_ID := "downtown_treasure_map"
const TREASURE_MAP_FIELD_MYTHIC_BONUS_PER_LEVEL := 1.50
const TREASURE_MAP_PASSIVE_DROP_SHARE_BONUS_PER_LEVEL := 0.03
const TREASURE_MAP_HUNT_LEGENDARY_BONUS_PER_LEVEL := 0.03
const LINGPET_AFFINITY_CHIP_CHOICE_ID := "lingpet_affinity_chip"
const LINGPET_RING_CORE_UPGRADE_CHOICE_ID := "lingpet_ring_core_upgrade"
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
var last_selected_choice: Dictionary = {}
var selected_choice_sequence := 0
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
var unlock_showcase: Dictionary = {}
# Starpoint absorption effect dict — `active`, `age`, `duration`, `source_pos`
# (above-head screen pos), `target_pos` (player center screen pos), `particles`
# (orbital sparkle seeds). Empty when no effect is running.
var starpoint_absorption_effect: Dictionary = {}
var gamepad_choice_horizontal_latch := 0
var gamepad_unlock_swap_horizontal_latch := 0
var current_choice_context: Dictionary = {}
var pending_dimension_gate_after_spawn_intro := false
var pending_dimension_gate_origin_stage := 0
var pending_dimension_gate_feedback_text := ""
var pending_full_gauge_after_spawn_intro := false
var pending_full_gauge_origin_stage := 0
var pending_full_gauge_feedback_text := ""
var _skill_cooldown_pause_active := false
var _skill_cooldown_pause_owner: Object = null
var _skill_cooldown_pause_registry: Object = null
var _flight_scene_config: Object = BattleSceneConfig.new()
var _flight_view_layout: Object = BattleViewLayout.new()
var _flight_pillar_layout: Object = Stage1PillarUILayout.new()
var _flight_orb_positioner: Object = SmasherSkillOrbRenderer.new()


func reset() -> void:
	_resume_skill_cooldowns_for_choice()
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
	last_selected_choice.clear()
	selected_choice_sequence = 0
	starpoint_absorption_effect.clear()
	item_gold_gain_multiplier = 1.0
	item_perk_level_bonus = 0
	viper_ignition_aura_active = false
	viper_ignition_aura_owner_sync_dirty = false
	pending_unlock_swap.clear()
	unlock_swap_selected_index = 0
	choice_flight_effect.clear()
	unlock_showcase.clear()
	gamepad_choice_horizontal_latch = 0
	gamepad_unlock_swap_horizontal_latch = 0
	current_choice_context.clear()
	pending_dimension_gate_after_spawn_intro = false
	pending_dimension_gate_origin_stage = 0
	pending_dimension_gate_feedback_text = ""
	pending_full_gauge_after_spawn_intro = false
	pending_full_gauge_origin_stage = 0
	pending_full_gauge_feedback_text = ""
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
	perf_logger: Object = null,
	choice_context: Dictionary = {}
) -> void:
	choice_flight_effect.clear()
	if pending_skill_choices <= 0:
		choice_active = false
		current_choices.clear()
		current_choice_context.clear()
		_resume_skill_cooldowns_for_choice()
		return
	if catalog == null or not catalog.has_method("get_choices"):
		choice_active = false
		current_choice_context.clear()
		_resume_skill_cooldowns_for_choice()
		return

	current_choice_context = choice_context.duplicate(true)
	var sample_start: int = _perf_begin(perf_logger)
	var item_bonus_choice_count: int = _get_item_perk_choice_count_bonus(owner, registry)
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.item_bonus", sample_start)
	var target_choice_count: int = max(0, BASE_PERK_CHOICE_COUNT + item_bonus_choice_count)
	sample_start = _perf_begin(perf_logger)
	current_choices = catalog.get_choices(character_type, runtime_skill_levels, exclude_instant, target_choice_count, owner, registry)
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.catalog", sample_start)
	if current_choices.is_empty():
		pending_skill_choices = max(0, pending_skill_choices - 1)
		choice_active = pending_skill_choices > 0
		if choice_active:
			open_next_choice(character_type, catalog, exclude_instant, owner, registry, perf_logger, current_choice_context)
		else:
			current_choice_context.clear()
			_resume_skill_cooldowns_for_choice()
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
	_tick_lingpet_ring_core_offer_cooldown(registry)
	_pause_skill_cooldowns_for_choice(owner, registry)
	sample_start = _perf_begin(perf_logger)
	_build_particles()
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.particles", sample_start)


func is_choice_active() -> bool:
	return choice_active or has_pending_unlock_swap()


func is_selectable() -> bool:
	return choice_active and not is_choice_flight_active() and not is_unlock_showcase_active() and not has_pending_unlock_swap() and animation_time >= 0.24 and not current_choices.is_empty()


func is_choice_flight_active() -> bool:
	return bool(choice_flight_effect.get("active", false))


func is_unlock_showcase_active() -> bool:
	return bool(unlock_showcase.get("active", false))


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
	if is_unlock_showcase_active():
		_update_unlock_showcase(delta, owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.unlock_showcase", sample_start)
	sample_start = _perf_begin(perf_logger)
	if is_starpoint_absorption_active():
		_update_starpoint_absorption_effect(delta, view_size, owner, registry)
	_perf_end(perf_logger, "process.runtime_perk.starpoint_absorption", sample_start)
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
	if is_unlock_showcase_active():
		return _handle_unlock_showcase_input(event, owner, registry)
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

	_play_perk_select_audio(registry)
	_finish_or_open_unlock_showcase(choice_id, owner, registry, null, choice)


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
	_finish_or_open_unlock_showcase(choice_id, owner, registry, perf_logger, choice)
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


func _play_perk_select_audio(registry: Object) -> void:
	# 일반 퍽 확정음. 액티브 언락 퍽은 오브로 날아가는 비행 사운드
	# (_play_active_unlock_flight_audio)를 별도로 유지하므로 이 경로만 담당한다.
	var game_audio: Object = _get_instance(registry, "game_audio")
	if game_audio == null:
		return
	if game_audio.has_method("play_runtime_perk_select"):
		game_audio.play_runtime_perk_select()


func is_starpoint_absorption_active() -> bool:
	return bool(starpoint_absorption_effect.get("active", false))


func _start_starpoint_absorption_effect(owner: Object) -> void:
	# Trigger called the moment the perk modal fully closes. We don't have
	# view_size here, so positions are computed from playfield-local player_pos
	# at trigger time and re-translated into screen coords every frame inside
	# `_update_starpoint_absorption_effect`. That way the absorption target
	# tracks the player paddle as it moves under input during the ~0.7s effect.
	if owner == null:
		starpoint_absorption_effect.clear()
		return
	starpoint_absorption_effect = {
		"active": true,
		"age": 0.0,
		"duration": STARPOINT_ABSORPTION_DURATION,
		"source_pos": Vector2.ZERO,
		"target_pos": Vector2.ZERO,
		"screen_scale": 1.0,
		"particles": _build_starpoint_absorption_particles(),
	}


func _build_starpoint_absorption_particles() -> Array:
	# Orbital sparkle seeds. Each particle holds a fixed phase + radius factor
	# so the renderer can derive its position from `age` deterministically
	# (no per-frame integration cost). Phase = orbit start angle, twinkle seed
	# = brightness-pulse offset.
	var out: Array = []
	for index in range(STARPOINT_ABSORPTION_PARTICLE_COUNT):
		out.append({
			"phase": _pseudo_unit(index, 1.3) * TAU,
			"radius_seed": _pseudo_unit(index, 3.7),
			"twinkle_seed": _pseudo_unit(index, 8.3),
			"orbit_dir": 1.0 if _pseudo_unit(index, 5.1) >= 0.5 else -1.0,
		})
	return out


func _update_starpoint_absorption_effect(delta: float, view_size: Vector2, owner: Object, registry: Object) -> void:
	if starpoint_absorption_effect.is_empty():
		return
	var age: float = float(starpoint_absorption_effect.get("age", 0.0)) + max(0.0, delta)
	starpoint_absorption_effect["age"] = age
	if age >= float(starpoint_absorption_effect.get("duration", STARPOINT_ABSORPTION_DURATION)):
		starpoint_absorption_effect.clear()
		return
	if owner == null or registry == null or view_size == Vector2.ZERO:
		# Without owner / view we can't translate the playfield position into
		# screen coords; renderer guards on `source_pos == ZERO` so this just
		# skips drawing for the frame.
		return
	var player_pos: Vector2 = _safe_owner_get(owner, "player_pos", Vector2.ZERO)
	var paddle_width: float = float(_safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH))
	var player_center_pf := player_pos + Vector2(paddle_width * 0.5, PLAYER_BASE_PADDLE_HEIGHT * 0.5)
	var layout_state: Dictionary = _build_flight_layout_state(registry, view_size)
	var game_offset: Vector2 = _get_vector2(layout_state.get("game_offset", Vector2.ZERO))
	var game_size: Vector2 = _get_vector2(layout_state.get("game_size", Vector2.ZERO))
	var pf_height: float = float(layout_state.get("height", FIELD_HEIGHT))
	var screen_scale: float = max(0.001, game_size.y / max(1.0, pf_height))
	var target_screen: Vector2 = game_offset + player_center_pf * screen_scale
	var source_screen: Vector2 = target_screen + Vector2(0.0, STARPOINT_ABSORPTION_SOURCE_PLAYFIELD_OFFSET_Y * screen_scale)
	starpoint_absorption_effect["source_pos"] = source_screen
	starpoint_absorption_effect["target_pos"] = target_screen
	starpoint_absorption_effect["screen_scale"] = screen_scale


func _finish_successful_choice(
	choice_id: String,
	owner: Object,
	registry: Object,
	perf_logger: Object = null,
	choice: Dictionary = {}
) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	var next_choice_context: Dictionary = current_choice_context.duplicate(true)
	last_selected_id = choice_id
	last_selected_choice = _build_selected_choice_snapshot(choice_id, choice)
	selected_choice_sequence += 1
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
		open_next_choice(character_type, catalog, false, owner, registry, perf_logger, next_choice_context)
		_perf_end(perf_logger, "process.runtime_perk.finish_success.open_next_choice", sample_start)
	elif not has_pending_unlock_swap():
		current_choice_context.clear()
	if not choice_active and not has_pending_unlock_swap():
		sample_start = _perf_begin(perf_logger)
		_resume_skill_cooldowns_for_choice()
		_perf_end(perf_logger, "process.runtime_perk.finish_success.resume_skill_cooldowns", sample_start)
		sample_start = _perf_begin(perf_logger)
		_try_arm_resume_safety(owner, registry)
		_perf_end(perf_logger, "process.runtime_perk.finish_success.resume_safety", sample_start)
		# Starpoint-into-body absorption: only fires when the modal fully closes
		# (last picked perk, no pending unlock swap). The update tick will keep
		# translating the player's playfield position into screen coords for the
		# next ~0.7s so the absorption target tracks the moving paddle.
		sample_start = _perf_begin(perf_logger)
		_start_starpoint_absorption_effect(owner)
		_perf_end(perf_logger, "process.runtime_perk.finish_success.starpoint_absorption", sample_start)
	sample_start = _perf_begin(perf_logger)
	_sync_owner(owner)
	_perf_end(perf_logger, "process.runtime_perk.finish_success.sync_owner", sample_start)


func _finish_or_open_unlock_showcase(
	choice_id: String,
	owner: Object,
	registry: Object,
	perf_logger: Object,
	choice: Dictionary = {}
) -> void:
	if _should_open_unlock_showcase(choice, owner):
		_open_unlock_showcase(choice_id, owner, registry, choice)
		return
	_finish_successful_choice(choice_id, owner, registry, perf_logger, choice)


func _should_open_unlock_showcase(choice: Dictionary, owner: Object) -> bool:
	if str(choice.get("unlocks_skill", "")) == "":
		return false
	var ai_mode: String = BattleSceneConfig.normalize_league_mode(str(_safe_owner_get(owner, "ai_mode", "champion")))
	return ai_mode == "junior"


func _open_unlock_showcase(choice_id: String, owner: Object, registry: Object, choice: Dictionary) -> void:
	var skill_id: String = str(choice.get("unlocks_skill", ""))
	var character_type: String = _normalize_character_type(str(choice.get("character_restriction", _get_character_type(owner))))
	var skill_data: Dictionary = _get_unlock_showcase_skill_data(skill_id, character_type, registry)
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
	unlock_showcase = {
		"active": true,
		"age": 0.0,
		"choice_id": choice_id,
		"choice": choice.duplicate(true),
		"skill_id": skill_id,
		"character_type": character_type,
		"skill_data": skill_data.duplicate(true),
	}
	_sync_owner(owner)


func _get_unlock_showcase_skill_data(skill_id: String, character_type: String, registry: Object) -> Dictionary:
	var skill_config: Object = _get_instance(registry, _get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("get_skill_data"):
		return {}
	var value: Variant = skill_config.get_skill_data(skill_id)
	if value is Dictionary:
		var data: Dictionary = value
		return data.duplicate(true)
	return {}


func _update_unlock_showcase(delta: float, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	if not is_unlock_showcase_active():
		return
	var age: float = max(0.0, float(unlock_showcase.get("age", 0.0)) + max(0.0, delta))
	unlock_showcase["age"] = age
	if age >= UNLOCK_SHOWCASE_MAX_AGE:
		_dismiss_unlock_showcase(owner, registry, perf_logger)


func _dismiss_unlock_showcase(owner: Object, registry: Object, perf_logger: Object = null) -> bool:
	if not is_unlock_showcase_active():
		return false
	var showcase: Dictionary = unlock_showcase.duplicate(true)
	unlock_showcase.clear()
	var choice: Dictionary = _get_dict(showcase.get("choice", {}))
	var choice_id: String = str(showcase.get("choice_id", choice.get("id", "")))
	if choice_id == "":
		_sync_owner(owner)
		return false
	_finish_successful_choice(choice_id, owner, registry, perf_logger, choice)
	return true


func _handle_unlock_showcase_input(event: InputEvent, owner: Object, registry: Object) -> bool:
	var dismiss_requested := false
	if GamepadInput.is_gamepad_event(event):
		dismiss_requested = GamepadInput.is_confirm_event(event)
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		dismiss_requested = key_event.pressed and not key_event.echo
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		dismiss_requested = mouse_event.pressed and not _is_mouse_wheel_button(mouse_event.button_index)
	if dismiss_requested and float(unlock_showcase.get("age", 0.0)) >= UNLOCK_SHOWCASE_MIN_DISMISS_AGE:
		_dismiss_unlock_showcase(owner, registry)
	return true


func _is_mouse_wheel_button(button_index: int) -> bool:
	return (
		button_index == MOUSE_BUTTON_WHEEL_UP
		or button_index == MOUSE_BUTTON_WHEEL_DOWN
		or button_index == MOUSE_BUTTON_WHEEL_LEFT
		or button_index == MOUSE_BUTTON_WHEEL_RIGHT
	)


func _build_selected_choice_snapshot(choice_id: String, choice: Dictionary) -> Dictionary:
	var snapshot: Dictionary = choice.duplicate(true)
	snapshot["id"] = choice_id
	if str(snapshot.get("name", "")) == "":
		snapshot["name"] = choice_id
	var applied_level: int = int(runtime_skill_levels.get(choice_id, 0))
	if applied_level > 0:
		snapshot["current_level"] = max(0, applied_level - 1)
		snapshot["next_level"] = applied_level
		snapshot["level_delta"] = 1
	return snapshot


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
		var gold_context: Dictionary = _build_owner_gold_gain_context(owner, registry)
		var gold_amount: int = _apply_runtime_gold_gain_modifiers(
			int(choice.get("gold_amount", 500)),
			gold_context,
			{"registry": registry}
		)
		gold_from_perks += gold_amount
		feedback_text = "골드 +%d" % gold_amount
		feedback_timer = 1.2
		_sync_owner(owner)
		return true

	if choice_id == "instant_gauge_full":
		if _should_defer_full_gauge_until_spawn_intro_end():
			_queue_full_gauge_after_spawn_intro(owner, str(choice.get("name", choice_id)))
			feedback_text = str(choice.get("name", choice_id))
			feedback_timer = 1.2
			return true
		_apply_full_gauge(owner, registry)
		feedback_text = "게이지 완충"
		feedback_timer = 1.2
		return true

	if choice_id == "instant_dimension_gate":
		if _should_defer_dimension_gate_until_spawn_intro_end():
			_queue_dimension_gate_after_spawn_intro(owner, str(choice.get("name", choice_id)))
			feedback_text = str(choice.get("name", choice_id))
			feedback_timer = 1.2
			return true
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

	if choice_id == LINGPET_AFFINITY_CHIP_CHOICE_ID:
		var chip_result := _apply_lingpet_affinity_chip(owner, registry)
		if not bool(chip_result.get("accepted", false)):
			return false
		feedback_text = "%s %d/%d" % [
			str(choice.get("name", choice_id)),
			int(chip_result.get("chip_count", 0)),
			int(chip_result.get("max_chips", 0)),
		]
		feedback_timer = 1.1
		return true

	if choice_id == LINGPET_RING_CORE_UPGRADE_CHOICE_ID:
		var ring_core_result := _apply_lingpet_ring_core_upgrade(owner, registry, int(choice.get("next_tier", 0)))
		if not bool(ring_core_result.get("accepted", false)):
			return false
		feedback_text = "%s %s" % [
			str(choice.get("name", choice_id)),
			str(ring_core_result.get("ring_core_name", "")),
		]
		feedback_timer = 1.1
		return true

	if choice_id == "common_refresh":
		# Instant one-shot perk: only re-open a choice. Do NOT write into
		# runtime_skill_levels — that dict is the "collected perks" source for
		# the character-info grid, and every other instant perk (convert_to_gold,
		# instant_gauge_full, treasure_hunt, ...) returns without writing.
		pending_skill_choices += 1
		feedback_text = "선택지 새로고침"
		feedback_timer = 1.0
		return true

	if choice_id == "star_change":
		# Instant one-shot perk: grant starpoints only. See common_refresh note —
		# no runtime_skill_levels write, or it leaks into the collected-perk grid.
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
		"unlock_showcase": unlock_showcase.duplicate(true),
		"starpoint_absorption_effect": starpoint_absorption_effect.duplicate(true),
		"feedback_text": feedback_text,
		"feedback_timer": feedback_timer,
		"last_selected_id": last_selected_id,
		"last_selected_choice": last_selected_choice.duplicate(true),
		"selected_choice_sequence": selected_choice_sequence,
		"current_choice_context": current_choice_context.duplicate(true),
		"pending_dimension_gate_after_spawn_intro": pending_dimension_gate_after_spawn_intro,
		"pending_dimension_gate_origin_stage": pending_dimension_gate_origin_stage,
		"pending_full_gauge_after_spawn_intro": pending_full_gauge_after_spawn_intro,
		"pending_full_gauge_origin_stage": pending_full_gauge_origin_stage,
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


# Smasher 콤보증폭칩: 콤보 소모형 드라이브/파워스매싱의 콤보 비례 항을 추가 증폭.
# Python get_combo_amplifier_chip_bonus()(pingfighter.py) 패리티. GDScript는 튜플
# 미지원이라 Dictionary 반환. 레벨은 유효레벨(아이템/점화 오버플로우 포함)을 쓰되,
# 커브 레인만 mini(level,3)로 Lv3 하드캡(밸런스 보호) — drive/power-smash 주입부에서
# (1.0 + amp)로 콤보 항에만 곱한다(base 상수는 비증폭).
func get_combo_amplifier_chip_bonus() -> Dictionary:
	var level: int = get_runtime_skill_level("combo_amplifier_chip")
	if level <= 0:
		return {"drive_speed": 0.0, "drive_curve": 0.0, "smash_speed": 0.0}
	return {
		"drive_speed": float(level) * 0.90,
		"smash_speed": float(level) * 0.45,
		"drive_curve": float(mini(level, 3)) * 0.05,
	}


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


func calculate_rally_gold(ball_vel: Vector2) -> int:
	var speed: float = ball_vel.length()
	var speed_bonus := 0
	if speed < 8.0:
		speed_bonus = 0
	elif speed < 12.0:
		speed_bonus = RALLY_GOLD_SPEED_BONUS_8
	elif speed < 16.0:
		speed_bonus = RALLY_GOLD_SPEED_BONUS_12
	elif speed < 20.0:
		speed_bonus = RALLY_GOLD_SPEED_BONUS_16
	else:
		speed_bonus = RALLY_GOLD_SPEED_BONUS_20
	return RALLY_GOLD_BASE + speed_bonus


func award_rally_gold(ball_vel: Vector2, context: Dictionary = {}, deps: Dictionary = {}) -> int:
	if bool(context.get("arena_mode_enabled", false)):
		return gold_from_perks
	var amount: int = calculate_rally_gold(ball_vel)
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("consume_next_rally_gold_multiplier"):
		if bool(dash_state.consume_next_rally_gold_multiplier()):
			amount *= 2
	return award_gold(amount, context, deps)


func award_gold(amount: int, context: Dictionary = {}, deps: Dictionary = {}) -> int:
	var boosted_amount: int = _apply_runtime_gold_gain_modifiers(amount, context, deps)
	return _store_gold_gain(boosted_amount, 1.0)


func _store_gold_gain(boosted_amount: int, _feedback_duration: float) -> int:
	boosted_amount = max(0, boosted_amount)
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


func _apply_runtime_gold_gain_modifiers(amount: int, context: Dictionary = {}, deps: Dictionary = {}) -> int:
	var base_amount: int = max(0, amount)
	if base_amount <= 0:
		return 0
	if _is_enraged_gold_context(context):
		base_amount = int(float(base_amount) * ENRAGED_BOSS_GOLD_MULTIPLIER)
	if viper_ignition_aura_active and base_amount > 0:
		base_amount += VIPER_IGNITION_AURA_GOLD_BONUS
	base_amount = _apply_item_gold_gain_bonus(base_amount)
	var combo_count: int = _get_smasher_gold_combo_count(context, deps)
	if combo_count >= 1:
		base_amount = int(float(base_amount) * (1.0 + float(combo_count) * SMASHER_COMBO_GOLD_BONUS_PER_STACK))
	var blacksmith_bonus: float = _get_blacksmith_structure_gold_bonus(context, deps)
	if blacksmith_bonus > 0.0:
		base_amount = int(float(base_amount) * (1.0 + blacksmith_bonus))
	return base_amount


func _is_enraged_gold_context(context: Dictionary) -> bool:
	return bool(context.get("enraged_boss_active", context.get("boss_enraged", false)))


func _get_smasher_gold_combo_count(context: Dictionary, deps: Dictionary = {}) -> int:
	if str(context.get("selected_character_type", "")).strip_edges().to_lower() != "smasher":
		return 0
	if context.has("smasher_combo_count"):
		return max(0, int(context.get("smasher_combo_count", 0)))
	var combo_state: Object = deps.get("combo_state", null)
	if combo_state != null and combo_state.has_method("get_combo_count"):
		return max(0, int(combo_state.get_combo_count()))
	return 0


func _get_blacksmith_structure_gold_bonus(context: Dictionary, _deps: Dictionary = {}) -> float:
	if str(context.get("selected_character_type", "")).strip_edges().to_lower() != "blacksmith":
		return 0.0
	var bonus := 0.0
	if _has_gold_context_flag(context, [
		"blacksmith_divine_stone_active",
		"blacksmith_divine_active",
		"blacksmith_divine_stone_state",
	]):
		bonus += BLACKSMITH_STRUCTURE_GOLD_BONUS
	if _has_gold_context_flag(context, [
		"blacksmith_turret_active",
		"blacksmith_turret_state",
	]):
		bonus += BLACKSMITH_STRUCTURE_GOLD_BONUS
	return bonus


func _has_gold_context_flag(context: Dictionary, keys: Array) -> bool:
	for key in keys:
		var value: Variant = context.get(str(key), null)
		if value == null:
			continue
		if value is bool:
			if bool(value):
				return true
			continue
		if value is Dictionary:
			if not (value as Dictionary).is_empty():
				return true
			continue
		return true
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

	if clean_id == LINGPET_RING_CORE_UPGRADE_CHOICE_ID:
		data["next_tier"] = clampi(target_level, 1, int(data.get("max_level", 1)))
		if not apply_choice(data, owner, registry):
			return false
		last_selected_id = clean_id
		_sync_owner(owner)
		return true

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
	gamepad_unlock_swap_horizontal_latch = 0
	_sync_owner(owner)
	return true


func cancel_pending_unlock_swap(owner: Object = null) -> bool:
	if pending_unlock_swap.is_empty():
		return false
	pending_unlock_swap.clear()
	unlock_swap_selected_index = 0
	gamepad_unlock_swap_horizontal_latch = 0
	current_choice_context.clear()
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
	gamepad_unlock_swap_horizontal_latch = 0
	feedback_text = "%s 교체 완료" % str(choice.get("name", choice_id))
	feedback_timer = 1.1
	_finish_or_open_unlock_showcase(choice_id, owner, registry, null, choice)
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
	# Light up the firearm HUD rainbow border on perk unlock so it matches the
	# supply_drop rental acquisition behavior. Empty unlocked_skill means a
	# generic equip sync — skip in that case so we don't flash on neutral
	# refresh paths.
	if unlocked_skill != "" and weapon_controller.has_method("trigger_hud_highlight"):
		weapon_controller.trigger_hud_highlight(unlocked_skill)
	if unlocked_skill != "":
		_play_commando_weapon_change_audio(registry)


func _play_commando_weapon_change_audio(registry: Object) -> void:
	var game_audio: Object = _get_instance(registry, "game_audio")
	if game_audio == null:
		return
	if game_audio.has_method("play_commando_weapon_change"):
		game_audio.play_commando_weapon_change()


func _apply_level_side_effect(choice: Dictionary, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	var choice_id: String = str(choice.get("id", ""))
	if owner == null:
		return
	if choice_id == "dash_amplification":
		var dash_start: int = _perf_begin(perf_logger)
		var dash_state: Object = _get_instance(registry, "smasher_dash_state")
		if dash_state != null and dash_state.has_method("reset_full"):
			var base_tokens: int = _get_starting_dash_tokens(owner)
			var max_tokens: int = base_tokens + int(get_runtime_skill_bonus("dash_amplification"))
			var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
			if mythic_item_runtime != null and mythic_item_runtime.has_method("get_dash_token_capacity"):
				max_tokens = int(mythic_item_runtime.get_dash_token_capacity(base_tokens, self))
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
				if weapon_controller.has_method("trigger_hud_highlight"):
					weapon_controller.trigger_hud_highlight(unlocked_skill)
				_play_commando_weapon_change_audio(registry)


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


func _should_defer_dimension_gate_until_spawn_intro_end() -> bool:
	return bool(current_choice_context.get(CHOICE_CONTEXT_DEFER_DIMENSION_GATE_UNTIL_SPAWN_END, false))


func _should_defer_full_gauge_until_spawn_intro_end() -> bool:
	return bool(current_choice_context.get(CHOICE_CONTEXT_DEFER_FULL_GAUGE_UNTIL_SPAWN_END, false))


func _queue_dimension_gate_after_spawn_intro(owner: Object, pending_feedback_text: String = "") -> void:
	pending_dimension_gate_after_spawn_intro = true
	pending_dimension_gate_origin_stage = _get_current_stage(owner)
	pending_dimension_gate_feedback_text = pending_feedback_text


func has_pending_dimension_gate_after_spawn_intro() -> bool:
	return pending_dimension_gate_after_spawn_intro


func _queue_full_gauge_after_spawn_intro(owner: Object, pending_feedback_text: String = "") -> void:
	pending_full_gauge_after_spawn_intro = true
	pending_full_gauge_origin_stage = _get_current_stage(owner)
	pending_full_gauge_feedback_text = pending_feedback_text


func has_pending_full_gauge_after_spawn_intro() -> bool:
	return pending_full_gauge_after_spawn_intro


func on_ball_spawn_intro_finished(owner: Object, registry: Object) -> Dictionary:
	var result := {
		"dimension_gate_pending": pending_dimension_gate_after_spawn_intro,
		"dimension_gate_activated": false,
		"dimension_gate_failed": false,
		"full_gauge_pending": pending_full_gauge_after_spawn_intro,
		"full_gauge_activated": false,
		"wait_for_stage_advance": false,
	}
	if not pending_dimension_gate_after_spawn_intro and not pending_full_gauge_after_spawn_intro:
		return result
	var current_stage_value: int = _get_current_stage(owner)
	if (
		pending_dimension_gate_after_spawn_intro
		and pending_dimension_gate_origin_stage > 0
		and current_stage_value == pending_dimension_gate_origin_stage
	):
		result["wait_for_stage_advance"] = true
	else:
		if pending_dimension_gate_after_spawn_intro:
			var dimension_feedback_text := pending_dimension_gate_feedback_text
			pending_dimension_gate_after_spawn_intro = false
			pending_dimension_gate_origin_stage = 0
			pending_dimension_gate_feedback_text = ""
			if _apply_dimension_gate(registry):
				result["dimension_gate_activated"] = true
				feedback_text = _resolve_pending_instant_feedback_text(dimension_feedback_text, "instant_dimension_gate")
				feedback_timer = 1.2
			else:
				result["dimension_gate_failed"] = true
	if (
		pending_full_gauge_after_spawn_intro
		and pending_full_gauge_origin_stage > 0
		and current_stage_value == pending_full_gauge_origin_stage
	):
		result["wait_for_stage_advance"] = true
	else:
		if pending_full_gauge_after_spawn_intro:
			var full_gauge_feedback_text := pending_full_gauge_feedback_text
			pending_full_gauge_after_spawn_intro = false
			pending_full_gauge_origin_stage = 0
			pending_full_gauge_feedback_text = ""
			_apply_full_gauge(owner, registry)
			result["full_gauge_activated"] = true
			feedback_text = _resolve_pending_instant_feedback_text(full_gauge_feedback_text, "instant_gauge_full")
			feedback_timer = 1.2
	if bool(result.get("dimension_gate_activated", false)) or bool(result.get("dimension_gate_failed", false)) or bool(result.get("full_gauge_activated", false)):
		_sync_owner(owner)
	return result


func _resolve_pending_instant_feedback_text(pending_feedback_text: String, fallback: String) -> String:
	if pending_feedback_text != "":
		return pending_feedback_text
	return fallback


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


func _apply_lingpet_affinity_chip(owner: Object, registry: Object) -> Dictionary:
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("add_enhancement_chip"):
		return {"accepted": false, "blocked_reason": "missing_lingpet_runtime"}
	var result: Variant = runtime.add_enhancement_chip(owner, registry)
	if result is Dictionary:
		return result
	return {"accepted": bool(result)}


func _apply_lingpet_ring_core_upgrade(_owner: Object, registry: Object, requested_tier: int = 0) -> Dictionary:
	# R5 / per-run: the ring-core perk upgrades THIS run's tier (run-state) through
	# the egg_runtime, not the dropped permanent store. Mirrors the plaza
	# transaction (R4); the store path was a no-op after R3.
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("upgrade_run_ring_core_tier"):
		return {"accepted": false, "blocked_reason": "missing_lingpet_runtime"}
	var max_tier := LingpetRingCoreRules.MAX_RING_CORE_TIER
	var current_tier := 0
	if runtime.has_method("get_run_ring_core_tier"):
		current_tier = clampi(int(runtime.get_run_ring_core_tier()), 0, max_tier)
	var target_tier := requested_tier if requested_tier > 0 else current_tier + 1
	target_tier = clampi(target_tier, 1, max_tier)
	if target_tier <= current_tier:
		return {
			"accepted": false,
			"blocked_reason": "max_ring_core_tier" if current_tier >= max_tier else "not_higher_ring_core_tier",
			"current_tier": current_tier,
			"target_tier": target_tier,
			"max_tier": max_tier,
		}
	var upgrade_result: Dictionary = runtime.upgrade_run_ring_core_tier(target_tier, _owner, registry)
	if not bool(upgrade_result.get("accepted", false)):
		return {
			"accepted": false,
			"blocked_reason": str(upgrade_result.get("blocked_reason", "ring_core_upgrade_failed")),
			"current_tier": current_tier,
			"target_tier": target_tier,
			"max_tier": max_tier,
		}
	return {
		"accepted": true,
		"current_tier": current_tier,
		"new_tier": int(upgrade_result.get("new_tier", target_tier)),
		"max_tier": max_tier,
		"ring_core_name": _get_lingpet_ring_core_tier_name(target_tier),
	}


func _get_lingpet_ring_core_tier_name(tier: int) -> String:
	var clamped_tier := clampi(tier, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN:
		match clamped_tier:
			1:
				return "Standard"
			2:
				return "Boost"
			3:
				return "Hyper"
			4:
				return "Overdrive"
			5:
				return "Ultimate"
			6:
				return "Zenith"
		return ""
	match clamped_tier:
		1:
			return "스탠다드"
		2:
			return "부스트"
		3:
			return "하이퍼"
		4:
			return "오버드라이브"
		5:
			return "얼티밋"
		6:
			return "제니스"
	return ""


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


func _pause_skill_cooldowns_for_choice(owner: Object, registry: Object) -> void:
	if _skill_cooldown_pause_active or owner == null or registry == null:
		return
	var skill_tooltip_driver: Object = _get_instance(registry, "battle_scene_skill_tooltip_driver")
	if skill_tooltip_driver == null or not skill_tooltip_driver.has_method("pause_skill_cooldowns"):
		return
	skill_tooltip_driver.pause_skill_cooldowns(owner, registry)
	_skill_cooldown_pause_active = true
	_skill_cooldown_pause_owner = owner
	_skill_cooldown_pause_registry = registry


func _resume_skill_cooldowns_for_choice() -> void:
	if not _skill_cooldown_pause_active:
		return
	var owner: Object = _skill_cooldown_pause_owner
	var registry: Object = _skill_cooldown_pause_registry
	_skill_cooldown_pause_active = false
	_skill_cooldown_pause_owner = null
	_skill_cooldown_pause_registry = null
	var skill_tooltip_driver: Object = _get_instance(registry, "battle_scene_skill_tooltip_driver")
	if skill_tooltip_driver != null and skill_tooltip_driver.has_method("resume_skill_cooldowns"):
		skill_tooltip_driver.resume_skill_cooldowns(owner, registry)


func _tick_lingpet_ring_core_offer_cooldown(registry: Object) -> void:
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime != null and runtime.has_method("tick_ring_core_offer_cooldown"):
		runtime.tick_ring_core_offer_cooldown()


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


func _get_current_stage(owner: Object) -> int:
	if owner == null:
		return 0
	var value: Variant = owner.get("current_stage")
	if value == null:
		return 0
	return max(0, int(value))


func _get_starting_dash_tokens(owner: Object) -> int:
	if owner == null:
		return 1
	var owner_value: Variant = owner.get("starting_dash_tokens")
	if owner_value != null:
		return max(1, int(owner_value))
	if _flight_scene_config != null and _flight_scene_config.has_method("get_starting_dash_tokens"):
		return max(1, int(_flight_scene_config.get_starting_dash_tokens(owner)))
	return 1


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
