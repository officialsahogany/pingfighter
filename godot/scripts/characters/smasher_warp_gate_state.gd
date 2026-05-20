extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const WarpGateFxHost := preload("res://scripts/characters/smasher_warp_gate_fx_host.gd")

const SKILL_NAME := "warp_gate"
const GAUGE_COST := 100.0
const WRAP_GAUGE_COST := 0.0
const BASE_DURATION_MSEC := 20000
const HOLD_MSEC := 500
const EXTENSION_GEAR_DURATION_BONUS := 0.25
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const EFFECT_MIN_SIZE := 188.0
const EFFECT_MAX_SIZE := 286.0
const WALL_PORTAL_THROAT_ANCHOR_RATIO := 0.34
const WALL_CENTER_Y_OFFSET := -42.0
const PORTAL_LIFE_MSEC := 620
const MAX_PORTAL_BURSTS := 12
const MAX_RENDERED_PORTAL_BURSTS := 8
const PORTAL_SPARK_COUNT := 9
const PORTAL_ARC_SEGMENTS := 18
const PORTAL_ARC_LAYERS := 4
const PORTAL_PHASE_SPEED := 0.08
const TIMER_BAR_SIZE := Vector2(170.0, 14.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0
const TIMER_STACK_KEY := "warp_gate"
const TIMER_STACK_INDEX := 0

var active := false
var start_msec := 0
var end_msec := 0
var total_duration_msec := BASE_DURATION_MSEC
var paused_remaining_msec := 0
var hold_start_msec := -1
var hold_consumed := false
var activated_this_frame := false
var phase := 0.0
var portals: Array[Dictionary] = []
var _last_player_pos := Vector2(FIELD_WIDTH * 0.5 - DEFAULT_PLAYER_SIZE.x * 0.5, FIELD_HEIGHT - DEFAULT_PLAYER_SIZE.y)
var _last_player_size := DEFAULT_PLAYER_SIZE
var fx_host: Node = null
var fx_host_add_pending := false


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	WarpGateFxHost.prewarm_assets()


func reset() -> void:
	active = false
	start_msec = 0
	end_msec = 0
	total_duration_msec = BASE_DURATION_MSEC
	paused_remaining_msec = 0
	hold_start_msec = -1
	hold_consumed = false
	activated_this_frame = false
	phase = 0.0
	portals.clear()
	_hide_node_fx()


func reset_round() -> void:
	pause_between_rounds(Time.get_ticks_msec())


func pause_between_rounds(current_msec: int) -> void:
	if active:
		paused_remaining_msec = max(0, end_msec - current_msec)
	active = false
	start_msec = 0
	end_msec = 0
	hold_start_msec = -1
	hold_consumed = false
	activated_this_frame = false
	portals.clear()
	_hide_node_fx()


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	activated_this_frame = false
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
	}

	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	if not down_pressed:
		hold_start_msec = -1
		hold_consumed = false
		return result

	if hold_start_msec < 0:
		hold_start_msec = current_msec

	if hold_consumed:
		return result
	if current_msec - hold_start_msec < HOLD_MSEC:
		return result
	if not _can_activate(current_msec, special_gauge, config, deps):
		return result

	var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null)))
	_activate(current_msec, player_pos, config, deps)
	_trigger_cooldown(current_msec, deps)
	hold_consumed = true
	activated_this_frame = true

	result["special_gauge"] = next_gauge
	result["activated"] = true
	return result


func update_effects(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	phase += PORTAL_PHASE_SPEED * max(0.0, fps_scale)
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	if _should_resume(context):
		_resume(current_msec, deps)
	if active and current_msec >= end_msec:
		_deactivate(true, current_msec, deps)
	_update_portals(current_msec)
	if not active and portals.is_empty():
		_hide_node_fx()
	_sync_audio(deps)


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	node_fx_layout: Dictionary = {},
	timer_stack: Object = null
) -> void:
	if canvas == null:
		return
	var node_fx_synced: bool = _sync_node_fx(canvas, shake_offset, node_fx_layout)
	if active:
		if not node_fx_synced:
			_draw_wall_portals(canvas, shake_offset)
		_draw_timer_bar(canvas, timer_stack)
	if not node_fx_synced:
		_draw_portal_bursts(canvas, shake_offset)


func _sync_node_fx(canvas: CanvasItem, shake_offset: Vector2, node_fx_layout: Dictionary) -> bool:
	if node_fx_layout.is_empty():
		return false
	var states: Array[Dictionary] = _build_node_fx_portal_states(shake_offset, node_fx_layout)
	if states.is_empty():
		_hide_node_fx()
		return false
	var host: Node = _get_or_create_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return false
	if not host.is_inside_tree():
		return false
	host.sync_state(states, true)
	return true


func _build_node_fx_portal_states(shake_offset: Vector2, node_fx_layout: Dictionary) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if active:
		var wall_y: float = clamp(_last_player_pos.y + _last_player_size.y * 0.5 + WALL_CENTER_Y_OFFSET, 92.0, FIELD_HEIGHT - 92.0)
		var pulse: float = 0.5 + 0.5 * sin(phase)
		var size: float = clamp(230.0 + pulse * 34.0, EFFECT_MIN_SIZE, EFFECT_MAX_SIZE)
		states.append(_build_node_fx_portal_state(Vector2(_get_wall_portal_center_x(-1, size), wall_y), size, 1.0, -1, "active", 0.0, start_msec, shake_offset, node_fx_layout))
		states.append(_build_node_fx_portal_state(Vector2(_get_wall_portal_center_x(1, size), wall_y), size, 1.0, 1, "active", 0.0, start_msec, shake_offset, node_fx_layout))

	if not portals.is_empty():
		var now_msec: int = Time.get_ticks_msec()
		var portal_start: int = max(0, portals.size() - MAX_RENDERED_PORTAL_BURSTS)
		for index in range(portal_start, portals.size()):
			var portal: Dictionary = portals[index]
			var center: Vector2 = _as_vector2(portal.get("center", Vector2.ZERO), Vector2.ZERO)
			var spawn_msec: int = int(portal.get("spawn_msec", now_msec))
			var life_msec: int = max(1, int(portal.get("life_msec", PORTAL_LIFE_MSEC)))
			var progress: float = clamp(float(now_msec - spawn_msec) / float(life_msec), 0.0, 1.0)
			var alpha: float = 1.0 - progress
			var size: float = EFFECT_MIN_SIZE * (0.75 + progress * 0.75)
			var side: int = int(portal.get("side", 1))
			if bool(portal.get("wall_anchor", false)):
				center.x = _get_wall_portal_center_x(side, size)
			states.append(_build_node_fx_portal_state(center, size, alpha, side, str(portal.get("kind", "burst")), progress, spawn_msec, shake_offset, node_fx_layout))
	return states


func _build_node_fx_portal_state(
	center: Vector2,
	size: float,
	alpha: float,
	side: int,
	kind: String,
	progress: float,
	spawn_msec: int,
	shake_offset: Vector2,
	node_fx_layout: Dictionary
) -> Dictionary:
	var render_scale: float = max(0.01, float(node_fx_layout.get("render_scale", 1.0)))
	var game_offset: Vector2 = _as_vector2(node_fx_layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var screen_center: Vector2 = game_offset + (center + shake_offset) * render_scale
	return {
		"screen_center": screen_center,
		"screen_size": size * render_scale,
		"side": side,
		"kind": kind,
		"alpha": alpha,
		"progress": progress,
		"spawn_msec": spawn_msec,
		"tint": _get_portal_tint(kind, 1.0),
		"hot": _get_portal_hot_color(kind),
	}


func _get_or_create_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_fx_host():
		return fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("SmasherWarpGateFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		fx_host = existing
		fx_host_add_pending = false
		return fx_host
	fx_host = WarpGateFxHost.new()
	fx_host.name = "SmasherWarpGateFxHost"
	fx_host.visible = false
	if not fx_host_add_pending:
		fx_host_add_pending = true
		parent.call_deferred("add_child", fx_host)
	return fx_host


func _hide_node_fx() -> void:
	if _is_valid_fx_host():
		if fx_host.has_method("set_active"):
			fx_host.set_active(false)


func _is_valid_fx_host() -> bool:
	return fx_host != null and is_instance_valid(fx_host) and not fx_host.is_queued_for_deletion()


func is_active() -> bool:
	return active


func has_visible_effects() -> bool:
	return active or not portals.is_empty()


func needs_effect_update() -> bool:
	return active or paused_remaining_msec > 0 or not portals.is_empty()


func was_activated_this_frame() -> bool:
	return activated_this_frame


func get_remaining_ratio(current_msec: int = -1) -> float:
	if not active or total_duration_msec <= 0:
		return 0.0
	var now_msec: int = current_msec if current_msec >= 0 else Time.get_ticks_msec()
	return clamp(float(end_msec - now_msec) / float(total_duration_msec), 0.0, 1.0)


func get_movement_bounds(play_left: float, play_right: float, paddle_width: float) -> Dictionary:
	if not active:
		return {
			"play_left": play_left,
			"play_right": play_right,
		}
	return {
		"play_left": -max(1.0, paddle_width),
		"play_right": FIELD_WIDTH + max(1.0, paddle_width),
	}


func wrap_player_position(
	player_pos: Vector2,
	paddle_size: Vector2,
	special_gauge: float,
	deps: Dictionary = {}
) -> Dictionary:
	if not active:
		player_pos.x = clamp(player_pos.x, 0.0, FIELD_WIDTH - max(1.0, paddle_size.x))
		return {
			"player_pos": player_pos,
			"special_gauge": special_gauge,
			"wrapped": false,
		}

	var next_gauge: float = special_gauge
	var wrapped := false
	if player_pos.x + paddle_size.x <= 0.0:
		_spawn_wall_portal_pair("exit_left", 0.0, "enter_right", FIELD_WIDTH)
		player_pos.x += FIELD_WIDTH
		next_gauge = max(0.0, next_gauge - WRAP_GAUGE_COST)
		wrapped = true
	elif player_pos.x >= FIELD_WIDTH:
		_spawn_wall_portal_pair("exit_right", FIELD_WIDTH, "enter_left", 0.0)
		player_pos.x -= FIELD_WIDTH
		next_gauge = max(0.0, next_gauge - WRAP_GAUGE_COST)
		wrapped = true

	if wrapped:
		_trigger_wrap_feedback(deps)
	return {
		"player_pos": player_pos,
		"special_gauge": next_gauge,
		"wrapped": wrapped,
	}


func get_mirror_offset_x(player_pos: Vector2, paddle_width: float) -> float:
	if not active:
		return 0.0
	var center_x: float = player_pos.x + paddle_width * 0.5
	if center_x < 0.0:
		return FIELD_WIDTH
	if center_x > FIELD_WIDTH:
		return -FIELD_WIDTH
	return 0.0


func get_ball_collision_context(player_pos: Vector2, paddle_size: Vector2) -> Dictionary:
	return {
		"warp_gate_active": active,
		"player_paddle_mirror_offset_x": get_mirror_offset_x(player_pos, paddle_size.x),
	}


func get_actor_draw_context(player_pos: Vector2, paddle_size: Vector2) -> Dictionary:
	var mirror_offset_x: float = get_mirror_offset_x(player_pos, paddle_size.x)
	return {
		"warp_gate_active": active,
		"warp_gate_mirror_offset_x": mirror_offset_x,
		"warp_gate_player_visual_offset_x": mirror_offset_x,
	}


func get_status_context() -> Dictionary:
	return {
		"active": active,
		"remaining_ratio": get_remaining_ratio(),
		"remaining_msec": max(0, end_msec - Time.get_ticks_msec()) if active else 0,
		"total_duration_msec": total_duration_msec,
		"paused_remaining_msec": paused_remaining_msec,
	}


func _activate(current_msec: int, player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	total_duration_msec = _get_duration_msec(deps)
	start_msec = current_msec
	end_msec = current_msec + total_duration_msec
	paused_remaining_msec = 0
	active = true
	portals.clear()
	_spawn_wall_portal_pair("open_left", 0.0, "open_right", FIELD_WIDTH)
	_play_audio(deps)
	_trigger_activation_feedback(deps)


func _resume(current_msec: int, deps: Dictionary) -> void:
	var preserved_total_msec: int = max(total_duration_msec, BASE_DURATION_MSEC, paused_remaining_msec)
	total_duration_msec = preserved_total_msec
	start_msec = current_msec - max(0, total_duration_msec - paused_remaining_msec)
	end_msec = current_msec + paused_remaining_msec
	paused_remaining_msec = 0
	active = true
	_spawn_wall_portal_pair("resume_left", 0.0, "resume_right", FIELD_WIDTH)
	_play_audio(deps)


func _deactivate(spawn_fade: bool, _current_msec: int, deps: Dictionary) -> void:
	if spawn_fade:
		_spawn_wall_portal_pair("fade_left", 0.0, "fade_right", FIELD_WIDTH)
	active = false
	start_msec = 0
	end_msec = 0
	hold_start_msec = -1
	hold_consumed = false
	paused_remaining_msec = 0
	_stop_audio(deps)


func _should_resume(context: Dictionary) -> bool:
	if active or paused_remaining_msec <= 0:
		return false
	if not bool(context.get("ball_active", false)):
		return false
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	return ball_vel.length_squared() > 0.01


func _can_activate(current_msec: int, special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if active:
		return false
	if _is_input_blocked(config, deps):
		return false
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return false
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return false
	if _get_cooldown_remaining(current_msec, deps) > 0.0:
		return false
	return true


func _is_input_blocked(config: Dictionary, deps: Dictionary) -> bool:
	var power_state: Object = deps.get("power_state", null)
	if power_state != null:
		if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
			return true
		if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
			return true
	var plasma_state: Object = deps.get("smasher_plasma_state", null)
	if plasma_state != null and plasma_state.has_method("is_charging") and bool(plasma_state.is_charging()):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	return bool(config.get("player_skill_input_locked", false))


func _get_duration_msec(deps: Dictionary) -> int:
	var extension_level: int = _get_runtime_skill_level(deps, "extension_gear")
	return int(round(float(BASE_DURATION_MSEC) * (1.0 + EXTENSION_GEAR_DURATION_BONUS * float(extension_level))))


func _get_runtime_skill_level(deps: Dictionary, skill_id: String) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return int(runtime_perk_state.get_runtime_skill_level(skill_id))
	return 0


func _get_cooldown_remaining(current_msec: int, deps: Dictionary) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_configured_cooldown_remaining"):
		return 0.0
	return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(SKILL_NAME, GAUGE_COST))
	return GAUGE_COST


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var equipped: Variant = snapshot.get("equipped_skills", [])
			if equipped is Array:
				return equipped.has(SKILL_NAME)
	return false


func _spawn_wall_portal_pair(left_kind: String, left_x: float, right_kind: String, right_x: float) -> void:
	var y: float = clamp(_last_player_pos.y + _last_player_size.y * 0.5 + WALL_CENTER_Y_OFFSET, 92.0, FIELD_HEIGHT - 92.0)
	_spawn_portal(left_kind, Vector2(left_x, y), -1, true)
	_spawn_portal(right_kind, Vector2(right_x, y), 1, true)


func _spawn_portal(kind: String, center: Vector2, side: int, wall_anchor: bool = false) -> void:
	portals.append({
		"kind": kind,
		"center": center,
		"side": side,
		"wall_anchor": wall_anchor,
		"spawn_msec": Time.get_ticks_msec(),
		"life_msec": PORTAL_LIFE_MSEC,
	})
	while portals.size() > MAX_PORTAL_BURSTS:
		portals.pop_front()


func _update_portals(current_msec: int) -> void:
	var write_index := 0
	for read_index in range(portals.size()):
		var portal: Dictionary = portals[read_index]
		var life_msec: int = int(portal.get("life_msec", PORTAL_LIFE_MSEC))
		var spawn_msec: int = int(portal.get("spawn_msec", current_msec))
		if current_msec - spawn_msec <= life_msec:
			portals[write_index] = portal
			write_index += 1
	if write_index < portals.size():
		portals.resize(write_index)


func _draw_wall_portals(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var wall_y: float = clamp(_last_player_pos.y + _last_player_size.y * 0.5 + WALL_CENTER_Y_OFFSET, 92.0, FIELD_HEIGHT - 92.0)
	var pulse: float = 0.5 + 0.5 * sin(phase)
	var size: float = clamp(230.0 + pulse * 34.0, EFFECT_MIN_SIZE, EFFECT_MAX_SIZE)
	var left_center := Vector2(_get_wall_portal_center_x(-1, size), wall_y)
	var right_center := Vector2(_get_wall_portal_center_x(1, size), wall_y)
	_draw_portal_frame(canvas, left_center + shake_offset, size, 1.0, -1, "active")
	_draw_portal_frame(canvas, right_center + shake_offset, size, 1.0, 1, "active")


func _draw_portal_bursts(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if portals.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var portal_start: int = max(0, portals.size() - MAX_RENDERED_PORTAL_BURSTS)
	for index in range(portal_start, portals.size()):
		var portal: Dictionary = portals[index]
		var center: Vector2 = _as_vector2(portal.get("center", Vector2.ZERO), Vector2.ZERO)
		var spawn_msec: int = int(portal.get("spawn_msec", now_msec))
		var life_msec: int = max(1, int(portal.get("life_msec", PORTAL_LIFE_MSEC)))
		var progress: float = clamp(float(now_msec - spawn_msec) / float(life_msec), 0.0, 1.0)
		var alpha: float = 1.0 - progress
		var size: float = EFFECT_MIN_SIZE * (0.75 + progress * 0.75)
		var side: int = int(portal.get("side", 1))
		if bool(portal.get("wall_anchor", false)):
			center.x = _get_wall_portal_center_x(side, size)
		_draw_portal_frame(
			canvas,
			center + shake_offset,
			size,
			alpha,
			side,
			str(portal.get("kind", "burst"))
		)


func _get_wall_portal_center_x(side: int, size: float) -> float:
	var radius_x: float = max(1.0, size * 0.24)
	var center_offset: float = radius_x * WALL_PORTAL_THROAT_ANCHOR_RATIO
	if side < 0:
		return center_offset
	return FIELD_WIDTH - center_offset


func _draw_portal_frame(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	alpha: float,
	side: int,
	kind: String
) -> void:
	_draw_procedural_portal(canvas, center, size, alpha, side, kind)


func _draw_procedural_portal(canvas: CanvasItem, center: Vector2, size: float, alpha: float, side: int, kind: String) -> void:
	var radius_x: float = size * 0.24
	var radius_y: float = size * 0.43
	var tint: Color = _get_portal_tint(kind, alpha)
	var local_phase: float = phase + float(side) * 0.55 + _get_kind_phase_offset(kind)
	var pulse: float = 0.5 + 0.5 * sin(local_phase * 2.4)
	var side_sign: float = -1.0 if side < 0 else 1.0
	var core_color := Color(0.18, 0.04, 0.34)
	var hot_color := Color(1.0, 0.84, 0.36)
	var violet := Color(0.72, 0.26, 1.0)
	var cyan := Color(0.36, 0.92, 1.0)

	_draw_oval_glow(canvas, center, Vector2(radius_x * 2.15, radius_y * 1.44), Color(tint.r, tint.g, tint.b), alpha * (0.20 + pulse * 0.07))
	_draw_oval_glow(canvas, center + Vector2(side_sign * radius_x * 0.08, 0.0), Vector2(radius_x * 0.72, radius_y * 1.02), core_color, alpha * 0.34)
	_draw_portal_rings(canvas, center, Vector2(radius_x, radius_y), tint, violet, alpha, local_phase)
	_draw_portal_vortex(canvas, center, Vector2(radius_x, radius_y), side, tint, hot_color, cyan, alpha, local_phase)
	_draw_portal_sparks(canvas, center, Vector2(radius_x, radius_y), side, kind, tint, hot_color, alpha, local_phase)
	_draw_portal_throat(canvas, center, Vector2(radius_x, radius_y), side, hot_color, cyan, alpha, local_phase)


func _draw_portal_rings(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	tint: Color,
	violet: Color,
	alpha: float,
	local_phase: float
) -> void:
	for i in range(3):
		var t: float = float(i)
		var ring_pulse: float = 0.5 + 0.5 * sin(local_phase * (1.8 + t * 0.17) + t * 1.2)
		var radius_scale := Vector2(
			1.0 + t * 0.13 + ring_pulse * 0.030,
			1.0 + t * 0.09 - ring_pulse * 0.018
		)
		var ring_alpha: float = alpha * (0.40 - t * 0.070)
		_draw_oval_ring(canvas, center, radius_size * radius_scale, Color(tint.r, tint.g, tint.b), ring_alpha)
		_draw_oval_ring(canvas, center, radius_size * radius_scale * 0.82, violet, ring_alpha * 0.56)
	var collapse: float = 0.5 + 0.5 * sin(local_phase * 3.4)
	_draw_oval_ring(canvas, center, radius_size * (0.50 + collapse * 0.09), Color(1.0, 0.88, 0.42), alpha * 0.32)


func _draw_portal_vortex(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	side: int,
	tint: Color,
	hot_color: Color,
	cyan: Color,
	alpha: float,
	local_phase: float
) -> void:
	var side_sign: float = -1.0 if side < 0 else 1.0
	for layer in range(PORTAL_ARC_LAYERS):
		var layer_f: float = float(layer)
		var ring_scale: float = 0.48 + layer_f * 0.15
		var sweep: float = PI * (0.42 + layer_f * 0.045)
		var start_angle: float = local_phase * (1.6 + layer_f * 0.19) * side_sign + layer_f * 1.22
		var color: Color = tint.lerp(hot_color if layer % 2 == 0 else cyan, 0.42)
		var width: float = 2.3 - layer_f * 0.26
		var arc_alpha: float = alpha * (0.42 - layer_f * 0.055)
		_draw_ellipse_arc_polyline(
			canvas,
			center,
			radius_size * ring_scale,
			start_angle,
			sweep * side_sign,
			Color(color.r, color.g, color.b, arc_alpha),
			width
		)
		_draw_ellipse_arc_polyline(
			canvas,
			center,
			radius_size * ring_scale * Vector2(0.82, 0.88),
			start_angle + PI * 0.92,
			-sweep * 0.58 * side_sign,
			Color(cyan.r, cyan.g, cyan.b, arc_alpha * 0.44),
			max(1.0, width * 0.58)
		)


func _draw_portal_sparks(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	side: int,
	kind: String,
	tint: Color,
	hot_color: Color,
	alpha: float,
	local_phase: float
) -> void:
	var side_sign: float = -1.0 if side < 0 else 1.0
	var burst_scale: float = 1.35 if kind.begins_with("open") or kind.begins_with("resume") else 1.0
	for j in range(PORTAL_SPARK_COUNT):
		var jf: float = float(j)
		var orbit: float = 0.64 + 0.24 * sin(local_phase * 1.7 + jf * 1.31)
		var angle: float = local_phase * (1.15 + float(j % 3) * 0.16) * side_sign + jf * TAU / float(PORTAL_SPARK_COUNT)
		var spark_pos := center + Vector2(cos(angle) * radius_size.x * orbit, sin(angle) * radius_size.y * (0.72 + 0.08 * sin(jf)))
		var spark_alpha: float = alpha * (0.32 + 0.24 * sin(local_phase * 2.6 + jf) * sin(local_phase * 2.6 + jf)) * burst_scale
		var spark_color: Color = hot_color if j % 3 == 0 else Color(tint.r, tint.g, tint.b)
		ImpactFlareTextureCache.draw_sparkle(canvas, spark_pos, 3.0 + float(j % 4) * 0.7, spark_color, spark_alpha)


func _draw_portal_throat(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	side: int,
	hot_color: Color,
	cyan: Color,
	alpha: float,
	local_phase: float
) -> void:
	var side_sign: float = -1.0 if side < 0 else 1.0
	var throat_x: float = side_sign * radius_size.x * (0.32 + 0.06 * sin(local_phase * 2.1))
	var throat_width: float = 4.5 + 4.0 * abs(sin(local_phase * 2.7))
	var top := center + Vector2(throat_x, -radius_size.y * 0.88)
	var bottom := center + Vector2(throat_x, radius_size.y * 0.88)
	canvas.draw_line(top, bottom, Color(0.18, 0.03, 0.28, alpha * 0.62), throat_width + 5.5, true)
	canvas.draw_line(top, bottom, Color(hot_color.r, hot_color.g, hot_color.b, alpha * 0.76), throat_width, true)
	canvas.draw_line(
		center + Vector2(throat_x - side_sign * radius_size.x * 0.10, -radius_size.y * 0.62),
		center + Vector2(throat_x + side_sign * radius_size.x * 0.10, radius_size.y * 0.62),
		Color(cyan.r, cyan.g, cyan.b, alpha * 0.36),
		max(1.0, throat_width * 0.42),
		true
	)


func _draw_ellipse_arc_polyline(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	start_angle: float,
	sweep: float,
	color: Color,
	width: float
) -> void:
	if color.a <= 0.0 or radius_size.x <= 1.0 or radius_size.y <= 1.0:
		return
	var points := PackedVector2Array()
	for i in range(PORTAL_ARC_SEGMENTS + 1):
		var ratio: float = float(i) / float(PORTAL_ARC_SEGMENTS)
		var angle: float = start_angle + sweep * ratio
		points.append(center + Vector2(cos(angle) * radius_size.x, sin(angle) * radius_size.y))
	canvas.draw_polyline(points, color, width, true)


func _get_kind_phase_offset(kind: String) -> float:
	if kind.begins_with("enter"):
		return 0.7
	if kind.begins_with("exit"):
		return 1.4
	if kind.begins_with("resume"):
		return 2.1
	if kind.begins_with("fade"):
		return 2.8
	return 0.0


func _draw_oval_glow(canvas: CanvasItem, center: Vector2, half_extents: Vector2, color: Color, alpha: float) -> void:
	_draw_centered_cached_texture(canvas, ImpactFlareTextureCache.get_glow_texture(), center, half_extents, color, alpha)


func _draw_oval_ring(canvas: CanvasItem, center: Vector2, radius_size: Vector2, color: Color, alpha: float) -> void:
	var ring_ratio: float = max(0.001, float(ImpactShockwaveTextureCache.RING_RADIUS_RATIO))
	_draw_centered_cached_texture(canvas, ImpactShockwaveTextureCache.get_full_ring_texture(), center, radius_size / ring_ratio, color, alpha)


func _draw_centered_cached_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	half_extents: Vector2,
	color: Color,
	alpha: float
) -> void:
	if canvas == null or texture == null or half_extents.x <= 0.0 or half_extents.y <= 0.0 or alpha <= 0.0:
		return
	canvas.draw_texture_rect(
		texture,
		Rect2(center - half_extents, half_extents * 2.0),
		false,
		Color(color.r, color.g, color.b, alpha)
	)


func _draw_timer_bar(canvas: CanvasItem, timer_stack: Object = null) -> void:
	var ratio: float = get_remaining_ratio()
	if ratio <= 0.0:
		return
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	canvas.draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_rect(rect, Color(0.05, 0.04, 0.12, 0.78))
	var fill_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * ratio, rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, Color(0.95, 0.50, 1.0, 0.92))
	canvas.draw_rect(rect, Color(1.0, 0.78, 0.38, 0.86), false, 2.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		canvas.draw_string(font, rect.position + Vector2(6.0, rect.size.y - 3.0), "WARP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.88, 0.58, 0.95))


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		FIELD_WIDTH - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * TIMER_STACK_SPACING
	)


func _claim_timer_stack_index(timer_stack: Object, key: String, fallback_index: int) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return fallback_index


func _get_portal_tint(kind: String, alpha: float) -> Color:
	if kind.begins_with("fade"):
		return Color(0.75, 0.34, 1.0, 0.58 * alpha)
	if kind.begins_with("resume"):
		return Color(1.0, 0.78, 0.35, 0.78 * alpha)
	if kind.begins_with("exit"):
		return Color(0.32, 0.92, 1.0, 0.82 * alpha)
	if kind.begins_with("enter"):
		return Color(1.0, 0.62, 0.28, 0.82 * alpha)
	return Color(0.92, 0.45, 1.0, 0.88 * alpha)


func _get_portal_hot_color(kind: String) -> Color:
	if kind.begins_with("exit"):
		return Color(0.40, 1.0, 0.96)
	if kind.begins_with("enter"):
		return Color(1.0, 0.70, 0.28)
	if kind.begins_with("resume"):
		return Color(1.0, 0.86, 0.34)
	if kind.begins_with("fade"):
		return Color(0.84, 0.34, 1.0)
	return Color(1.0, 0.84, 0.36)


func _play_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_warp_gate_loop"):
		audio.play_warp_gate_loop()


func _stop_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_warp_gate_loop"):
		audio.stop_warp_gate_loop()


func _sync_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_warp_gate_loop"):
		audio.sync_warp_gate_loop(active)


func _trigger_activation_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.12, 4.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _trigger_wrap_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.06, 2.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _get_player_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", DEFAULT_PLAYER_SIZE.x))),
		max(1.0, float(config.get("paddle_height", DEFAULT_PLAYER_SIZE.y)))
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
