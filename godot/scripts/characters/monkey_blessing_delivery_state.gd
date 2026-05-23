extends RefCounted

const MonkeyBlessingDeliveryRenderer := preload("res://scripts/characters/monkey_blessing_delivery_renderer.gd")

const PHASE_NONE := "none"
const PHASE_DELAY := "delay"
const PHASE_RUN := "run"
const PHASE_HANDOVER := "handover"
const PHASE_EXIT := "exit"
const WIDTH := 760.0
const HEIGHT := 750.0
const START_DELAY_SEC := 1.0
const RUN_SPEED := 390.0
const EXIT_SPEED := 430.0
const HANDOVER_DISTANCE := 34.0
const HANDOVER_DURATION_SEC := 0.92
const HANDOVER_GIVE_SEC := 0.38
const RUN_FRAME_SEC := 0.075
const HANDOVER_FRAME_SEC := 0.16
const DRAW_SIZE := Vector2(104.0, 104.0)
const PLAYER_SIDE_GAP := 54.0
const EXIT_MARGIN := 70.0
const BANANA_FILL_LIMIT := 9

var renderer: Object = MonkeyBlessingDeliveryRenderer.new()
var active := false
var phase := PHASE_NONE
var phase_time := 0.0
var pos := Vector2.ZERO
var facing := 1.0
var spawn_side := -1.0
var handover_done := false
var delivered_count := 0
var owner_ref: Object
var registry_ref: Object


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
	active = false
	phase = PHASE_NONE
	phase_time = 0.0
	pos = Vector2.ZERO
	facing = 1.0
	spawn_side = -1.0
	handover_done = false
	delivered_count = 0
	owner_ref = null
	registry_ref = null


func start(owner: Object, registry: Object) -> bool:
	if owner == null:
		return false
	owner_ref = owner
	registry_ref = registry
	active = true
	phase = PHASE_DELAY
	phase_time = 0.0
	handover_done = false
	delivered_count = 0

	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(WIDTH * 0.5, HEIGHT - 80.0))
	var paddle_size := Vector2(
		max(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		max(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	var from_left: bool = (randi() % 2) == 0
	spawn_side = -1.0 if from_left else 1.0
	facing = 1.0 if from_left else -1.0
	pos = Vector2(
		-DRAW_SIZE.x * 0.6 if from_left else WIDTH + DRAW_SIZE.x * 0.6,
		_get_ground_y(player_pos, paddle_size)
	)
	return true


func update_effects(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if not active:
		return
	phase_time += max(0.0, delta)
	match phase:
		PHASE_DELAY:
			_update_delay(deps)
		PHASE_RUN:
			_update_run(delta, context)
		PHASE_HANDOVER:
			_update_handover(context, deps)
		PHASE_EXIT:
			_update_exit(delta)


func draw(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if renderer != null:
		renderer.draw(canvas, get_snapshot(), shake_offset)


func get_snapshot() -> Dictionary:
	return {
		"visible": active and phase != PHASE_DELAY and phase != PHASE_NONE,
		"pos": pos,
		"draw_size": DRAW_SIZE,
		"facing": facing,
		"frame": _get_frame_index(),
		"alpha": _get_alpha(),
		"delivered_count": delivered_count,
	}


func is_active() -> bool:
	return active


func has_visible_effects() -> bool:
	return active and phase != PHASE_DELAY and phase != PHASE_NONE


func needs_effect_update() -> bool:
	return active


func _update_delay(deps: Dictionary) -> void:
	if phase_time < START_DELAY_SEC:
		return
	phase = PHASE_RUN
	phase_time = 0.0
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_banana_throw"):
		audio.play_banana_throw()


func _update_run(delta: float, context: Dictionary) -> void:
	var owner: Object = _get_owner(context)
	var player_pos: Vector2 = _get_context_vector2(context, "player_pos", _get_owner_vector2(owner, "player_pos", Vector2(WIDTH * 0.5, HEIGHT - 80.0)))
	var paddle_size: Vector2 = _get_context_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
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


func _update_handover(context: Dictionary, deps: Dictionary) -> void:
	var owner: Object = _get_owner(context)
	if not handover_done and phase_time >= HANDOVER_GIVE_SEC:
		handover_done = true
		delivered_count = _fill_banana_slots(owner, deps)
		var audio: Object = deps.get("audio", null)
		if audio != null:
			if audio.has_method("play_item_get") and delivered_count > 0:
				audio.play_item_get()
			elif audio.has_method("play_active_item"):
				audio.play_active_item()
	if phase_time >= HANDOVER_DURATION_SEC:
		phase = PHASE_EXIT
		phase_time = 0.0


func _update_exit(delta: float) -> void:
	pos.x += spawn_side * EXIT_SPEED * delta
	if pos.x < -EXIT_MARGIN or pos.x > WIDTH + EXIT_MARGIN:
		reset()


func _fill_banana_slots(owner: Object, deps: Dictionary) -> int:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("fill_empty_slots_with_item"):
		return int(active_item_runtime.fill_empty_slots_with_item("banana", owner, registry_ref, BANANA_FILL_LIMIT))
	if active_item_runtime != null and active_item_runtime.has_method("debug_add_item_to_slot"):
		var count := 0
		for _i in range(BANANA_FILL_LIMIT):
			if not bool(active_item_runtime.debug_add_item_to_slot("banana", owner, registry_ref)):
				break
			count += 1
		return count
	return 0


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
	return 1.0


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
