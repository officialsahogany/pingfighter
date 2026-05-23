extends RefCounted

const CommandoReloadDeliveryRenderer := preload("res://scripts/characters/commando_reload_delivery_renderer.gd")

const PHASE_NONE := "none"
const PHASE_RADIO := "radio"
const PHASE_RUN := "run"
const PHASE_HANDOVER := "handover"
const PHASE_EXIT := "exit"
const WIDTH := 760.0
const HEIGHT := 750.0
const RADIO_DURATION_SEC := 1.25
const RUN_SPEED := 410.0
const EXIT_SPEED := 460.0
const HANDOVER_DISTANCE := 38.0
const HANDOVER_DURATION_SEC := 0.95
const HANDOVER_GIVE_SEC := 0.42
const RUN_FRAME_SEC := 0.08
const HANDOVER_FRAME_SEC := 0.18
const DRAW_SIZE := Vector2(104.0, 104.0)
const PLAYER_SIDE_GAP := 58.0
const EXIT_MARGIN := 70.0
const RADIO_ANCHOR_OFFSET := Vector2(0.0, 0.0)
const LEG_PHASE_SPEED := 12.0

var renderer: Object = CommandoReloadDeliveryRenderer.new()
var active := false
var phase := PHASE_NONE
var phase_time := 0.0
var pos := Vector2.ZERO
var facing := 1.0
var spawn_side := -1.0
var handover_done := false
var leg_phase := 0.0
var radio_anchor := Vector2.ZERO
var radio_visible := false
var pending_weapon_id := ""
var pending_refilled := false
var owner_ref: Object
var weapon_controller_ref: Object


func prewarm_assets() -> void:
	if renderer != null and renderer.has_method("prewarm_assets"):
		renderer.prewarm_assets()


func prewarm_assets_step() -> bool:
	if renderer != null and renderer.has_method("prewarm_assets_step"):
		return bool(renderer.prewarm_assets_step())
	if renderer != null and renderer.has_method("prewarm_assets"):
		renderer.prewarm_assets()
	return true


func reset() -> void:
	# If a delivery was interrupted mid-flight after gauge / cooldown were already spent,
	# settle the pending refill so the player does not lose the resource investment.
	_settle_pending_refill_if_needed()
	active = false
	phase = PHASE_NONE
	phase_time = 0.0
	pos = Vector2.ZERO
	facing = 1.0
	spawn_side = -1.0
	handover_done = false
	leg_phase = 0.0
	radio_anchor = Vector2.ZERO
	radio_visible = false
	pending_weapon_id = ""
	pending_refilled = false
	owner_ref = null
	weapon_controller_ref = null


func start(owner: Object, weapon_id: String, deps: Dictionary) -> bool:
	if owner == null or weapon_id == "":
		return false
	_settle_pending_refill_if_needed()
	owner_ref = owner
	weapon_controller_ref = _resolve_weapon_controller(owner, deps)
	active = true
	phase = PHASE_RADIO
	phase_time = 0.0
	handover_done = false
	pending_weapon_id = weapon_id
	pending_refilled = false
	leg_phase = 0.0

	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(WIDTH * 0.5, HEIGHT - 80.0))
	var paddle_size := Vector2(
		max(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		max(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	radio_anchor = Vector2(
		player_pos.x + paddle_size.x * 0.5,
		player_pos.y + RADIO_ANCHOR_OFFSET.y
	)
	radio_visible = true
	var from_left: bool = (randi() % 2) == 0
	spawn_side = -1.0 if from_left else 1.0
	facing = 1.0 if from_left else -1.0
	pos = Vector2(
		-DRAW_SIZE.x * 0.6 if from_left else WIDTH + DRAW_SIZE.x * 0.6,
		_get_ground_y(player_pos, paddle_size)
	)

	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_commando_supply_radio"):
		audio.play_commando_supply_radio()
	return true


func update_effects(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if not active:
		return
	var safe_delta: float = max(0.0, delta)
	phase_time += safe_delta
	_update_radio_anchor(context)
	match phase:
		PHASE_RADIO:
			_update_radio()
		PHASE_RUN:
			leg_phase += LEG_PHASE_SPEED * safe_delta
			_update_run(safe_delta, context)
		PHASE_HANDOVER:
			leg_phase = max(0.0, leg_phase - LEG_PHASE_SPEED * 0.5 * safe_delta)
			_update_handover(deps)
		PHASE_EXIT:
			leg_phase += LEG_PHASE_SPEED * safe_delta
			_update_exit(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if renderer != null:
		renderer.draw(canvas, get_snapshot(), shake_offset)


func get_snapshot() -> Dictionary:
	return {
		"visible": active and phase != PHASE_NONE and phase != PHASE_RADIO,
		"pos": pos,
		"draw_size": DRAW_SIZE,
		"facing": facing,
		"frame": _get_frame_index(),
		"alpha": _get_alpha(),
		"leg_phase": leg_phase,
		"box_offset": _get_box_offset(),
		"box_alpha": _get_box_alpha(),
		"radio_visible": radio_visible,
		"radio_anchor": radio_anchor,
		"radio_alpha": _get_radio_alpha(),
		"radio_pulse": _get_radio_pulse(),
	}


func is_active() -> bool:
	return active


func has_visible_effects() -> bool:
	return active and phase != PHASE_NONE


func needs_effect_update() -> bool:
	return active


func _update_radio() -> void:
	if phase_time < RADIO_DURATION_SEC:
		return
	phase = PHASE_RUN
	phase_time = 0.0
	radio_visible = false


func _update_run(delta: float, context: Dictionary) -> void:
	var owner: Object = _get_owner(context)
	var player_pos: Vector2 = _get_context_vector2(
		context, "player_pos",
		_get_owner_vector2(owner, "player_pos", Vector2(WIDTH * 0.5, HEIGHT - 80.0))
	)
	var paddle_size: Vector2 = _get_context_vector2(
		context, "player_paddle_size",
		Vector2(155.0, 50.0)
	)
	pos.y = lerp(pos.y, _get_ground_y(player_pos, paddle_size), clamp(delta * 7.0, 0.0, 1.0))

	var target_x: float = clamp(
		player_pos.x + paddle_size.x * 0.5 - facing * PLAYER_SIDE_GAP,
		DRAW_SIZE.x * 0.35,
		WIDTH - DRAW_SIZE.x * 0.35
	)
	var distance: float = target_x - pos.x
	var step: float = RUN_SPEED * delta
	if abs(distance) <= max(HANDOVER_DISTANCE, step):
		pos.x = target_x
		phase = PHASE_HANDOVER
		phase_time = 0.0
		return
	pos.x += sign(distance) * step


func _update_handover(deps: Dictionary) -> void:
	if not handover_done and phase_time >= HANDOVER_GIVE_SEC:
		handover_done = true
		_complete_refill(deps)
		var audio: Object = deps.get("audio", null)
		if audio != null and audio.has_method("play_commando_reload"):
			audio.play_commando_reload()
	if phase_time >= HANDOVER_DURATION_SEC:
		phase = PHASE_EXIT
		phase_time = 0.0


func _update_exit(delta: float) -> void:
	pos.x += spawn_side * EXIT_SPEED * delta
	if pos.x < -EXIT_MARGIN or pos.x > WIDTH + EXIT_MARGIN:
		reset()


func _update_radio_anchor(context: Dictionary) -> void:
	if not radio_visible:
		return
	var owner: Object = _get_owner(context)
	var player_pos: Vector2 = _get_context_vector2(
		context, "player_pos",
		_get_owner_vector2(owner, "player_pos", Vector2(WIDTH * 0.5, HEIGHT - 80.0))
	)
	var paddle_size: Vector2 = _get_context_vector2(
		context, "player_paddle_size",
		Vector2(155.0, 50.0)
	)
	radio_anchor = Vector2(
		player_pos.x + paddle_size.x * 0.5,
		player_pos.y + RADIO_ANCHOR_OFFSET.y
	)


func _complete_refill(deps: Dictionary) -> void:
	if pending_refilled or pending_weapon_id == "":
		return
	var weapon_controller: Object = weapon_controller_ref
	if weapon_controller == null:
		weapon_controller = _resolve_weapon_controller(owner_ref, deps)
	if weapon_controller != null and weapon_controller.has_method("refill_weapon_to_max"):
		weapon_controller.refill_weapon_to_max(pending_weapon_id)
	pending_refilled = true


func _settle_pending_refill_if_needed() -> void:
	if pending_refilled or pending_weapon_id == "":
		return
	var weapon_controller: Object = weapon_controller_ref
	if weapon_controller == null:
		weapon_controller = _resolve_weapon_controller(owner_ref, {})
	if weapon_controller != null and weapon_controller.has_method("refill_weapon_to_max"):
		weapon_controller.refill_weapon_to_max(pending_weapon_id)
	pending_refilled = true


func _resolve_weapon_controller(owner: Object, deps: Dictionary) -> Object:
	var controller: Variant = deps.get("commando_weapon_controller", null)
	if typeof(controller) == TYPE_OBJECT and controller != null:
		return controller
	if owner == null:
		return null
	var value: Variant = owner.get("commando_weapon_controller")
	if typeof(value) == TYPE_OBJECT:
		return value
	return null


func _get_frame_index() -> int:
	match phase:
		PHASE_RUN:
			return int(phase_time / RUN_FRAME_SEC) % 8
		PHASE_HANDOVER:
			return 8 + clampi(int(phase_time / HANDOVER_FRAME_SEC), 0, 3)
		PHASE_EXIT:
			return 12 + (int(phase_time / RUN_FRAME_SEC) % 4)
	return 0


func _get_alpha() -> float:
	if phase == PHASE_RUN:
		return clamp(phase_time / 0.16, 0.0, 1.0)
	if phase == PHASE_EXIT:
		var remaining: float = min(abs(pos.x + EXIT_MARGIN), abs((WIDTH + EXIT_MARGIN) - pos.x))
		return clamp(remaining / 70.0, 0.0, 1.0)
	if phase == PHASE_HANDOVER:
		return 1.0
	return 0.0


func _get_box_offset() -> Vector2:
	if phase != PHASE_HANDOVER:
		return Vector2.ZERO
	var progress: float = clamp(phase_time / HANDOVER_GIVE_SEC, 0.0, 1.0)
	return Vector2(facing * 8.0 * progress, -4.0 * progress)


func _get_box_alpha() -> float:
	if phase == PHASE_RUN:
		return 1.0
	if phase == PHASE_HANDOVER:
		if not handover_done:
			return 1.0
		var fade: float = clamp((phase_time - HANDOVER_GIVE_SEC) / max(0.001, HANDOVER_DURATION_SEC - HANDOVER_GIVE_SEC), 0.0, 1.0)
		return 1.0 - fade
	return 0.0


func _get_radio_alpha() -> float:
	if not radio_visible:
		return 0.0
	if phase == PHASE_RADIO:
		var fade_in: float = clamp(phase_time / 0.18, 0.0, 1.0)
		var fade_out: float = clamp((RADIO_DURATION_SEC - phase_time) / 0.22, 0.0, 1.0)
		return min(fade_in, fade_out)
	return 0.0


func _get_radio_pulse() -> float:
	if not radio_visible:
		return 0.0
	return 0.5 + 0.5 * sin(phase_time * 14.0)


func _get_ground_y(player_pos: Vector2, paddle_size: Vector2) -> float:
	return clamp(player_pos.y + paddle_size.y + 10.0, HEIGHT * 0.58, HEIGHT - 22.0)


func _get_owner(context: Dictionary) -> Object:
	var owner: Variant = context.get("owner", owner_ref)
	if typeof(owner) == TYPE_OBJECT and owner != null:
		return owner
	return owner_ref


func _get_context_vector2(context: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = context.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value
