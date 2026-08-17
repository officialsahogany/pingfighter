extends RefCounted

const TRACE_FLAG_PATH := "res://victory_highlight_pillar_trace.flag"
const TRACE_ENV_KEY := "VICTORY_HIGHLIGHT_PILLAR_TRACE"
const TRACE_FRAME_COUNT := 4

static var _enabled_cache := -1
static var _phase_first_frame: Dictionary = {}
static var _logged_calls: Dictionary = {}


static func trace_draw_pass(
	pass_name: String,
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	layout: Dictionary
) -> void:
	if not _is_enabled() or canvas == null or registry == null:
		return
	var phase := _resolve_phase(registry)
	if phase == "spawn_intro":
		return
	var frame := Engine.get_process_frames()
	if not _phase_first_frame.has(phase):
		_phase_first_frame[phase] = frame
	var first_frame := int(_phase_first_frame.get(phase, frame))
	if frame - first_frame >= TRACE_FRAME_COUNT:
		return
	var call_key := "%s:%d:%s:%d" % [phase, frame, pass_name, canvas.get_instance_id()]
	if _logged_calls.has(call_key):
		return
	_logged_calls[call_key] = true

	var game_offset := _get_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size := _get_vector2(layout.get("game_size", view_size), view_size)
	var right_x := game_offset.x + game_size.x
	var left_rect := Rect2(Vector2.ZERO, Vector2(maxf(0.0, game_offset.x), view_size.y))
	var right_rect := Rect2(
		Vector2(right_x, 0.0),
		Vector2(maxf(0.0, view_size.x - right_x), view_size.y)
	)
	var local_position := Vector2.ZERO
	var local_scale := Vector2.ONE
	var global_origin := Vector2.ZERO
	if canvas is Node2D:
		local_position = (canvas as Node2D).position
		local_scale = (canvas as Node2D).scale
		global_origin = (canvas as Node2D).global_position
	elif canvas is Control:
		local_position = (canvas as Control).position
		local_scale = (canvas as Control).scale
		global_origin = (canvas as Control).global_position
	print(
		"victory_highlight_pillar_trace: frame=%d phase=%s pass=%s canvas=%s id=%d parent=%s local_pos=%s global_pos=%s local_scale=%s game_offset=%s game_size=%s left=%s right=%s host=%s" % [
			frame,
			phase,
			pass_name,
			_safe_node_path(canvas),
			canvas.get_instance_id(),
			_safe_node_path(canvas.get_parent()),
			local_position,
			global_origin,
			local_scale,
			game_offset,
			game_size,
			left_rect,
			right_rect,
			JSON.stringify(_get_highlight_host_snapshot(registry)),
		]
	)


static func reset_for_tests() -> void:
	_enabled_cache = -1
	_phase_first_frame.clear()
	_logged_calls.clear()


static func _resolve_phase(registry: Object) -> String:
	var playback := _get_instance(registry, "victory_highlight_playback_state")
	if _is_active(playback):
		var mode := "unknown"
		if playback.has_method("get_host_debug_snapshot"):
			var snapshot: Variant = playback.get_host_debug_snapshot()
			if snapshot is Dictionary:
				mode = str((snapshot as Dictionary).get("current_content_mode", mode))
		return "highlight_%s" % mode
	var loot := _get_instance(registry, "victory_loot_phase_state")
	if _is_active(loot):
		return "victory_loot"
	var spawn_intro := _get_instance(registry, "stage_ball_spawn_intro")
	if spawn_intro != null and spawn_intro.has_method("is_overlay_active") and bool(spawn_intro.is_overlay_active()):
		return "spawn_intro"
	return "normal"


static func _get_highlight_host_snapshot(registry: Object) -> Dictionary:
	var playback := _get_instance(registry, "victory_highlight_playback_state")
	if playback == null or not playback.has_method("get_host_debug_snapshot"):
		return {}
	var value: Variant = playback.get_host_debug_snapshot()
	return value if value is Dictionary else {}


static func _is_enabled() -> bool:
	if _enabled_cache >= 0:
		return _enabled_cache == 1
	var env_value := OS.get_environment(TRACE_ENV_KEY).strip_edges().to_lower()
	_enabled_cache = 1 if (
		OS.is_debug_build()
		and (env_value in ["1", "true", "yes", "on"] or FileAccess.file_exists(TRACE_FLAG_PATH))
	) else 0
	return _enabled_cache == 1


static func _is_active(value: Object) -> bool:
	return value != null and value.has_method("is_active") and bool(value.is_active())


static func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


static func _safe_node_path(value: Variant) -> String:
	if not (value is Node) or not is_instance_valid(value):
		return "<none>"
	var node := value as Node
	return str(node.get_path()) if node.is_inside_tree() else node.name


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value as Vector2 if value is Vector2 else fallback
