extends Control

# Detached, controller-driven host for the three-second post-commit paddle aura.
# The runtime-perk effect owns the clock and calls set_active(false) directly on
# every cleanup boundary; this node owns presentation only and never processes.

const MysticDicePaddleDrawBridge := preload(
	"res://scripts/characters/mystic_dice_paddle_draw_bridge.gd"
)

var _state: Dictionary = {}
var _draw_bridge: Node2D = null


func _init() -> void:
	_configure_host()


func _ready() -> void:
	_configure_host()
	_ensure_draw_bridge()
	if _can_draw_state(_state):
		_apply_layout()
		_draw_bridge.sync_state(_state, true)
		visible = true
	else:
		set_active(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	_state = next_state.duplicate(true)
	_ensure_draw_bridge()
	if not active or not _can_draw_state(_state):
		set_active(false)
		return
	_apply_layout()
	_draw_bridge.sync_state(_state, true)
	visible = true


func set_active(active: bool) -> void:
	visible = active
	if _draw_bridge != null and is_instance_valid(_draw_bridge):
		_draw_bridge.set_active(active)
	set_process(false)


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	var bridge_status: Dictionary = {}
	if _draw_bridge != null and is_instance_valid(_draw_bridge):
		bridge_status = _draw_bridge.get_debug_status()
	return {
		"active": visible,
		"processing": is_processing(),
		"visible_particle_count": int(bridge_status.get("visible_particle_count", 0)),
		"draw_bridge_is_child": _draw_bridge != null and _draw_bridge.get_parent() == self,
		"draw_bridge_position": bridge_status.get("position", Vector2.ZERO),
		"state": _state.duplicate(true),
	}


func _apply_layout() -> void:
	position = _vector2(_state.get("clip_position", Vector2.ZERO), Vector2.ZERO)
	size = _vector2(_state.get("clip_size", Vector2(760.0, 750.0)), Vector2(760.0, 750.0))
	scale = Vector2.ONE


func _can_draw_state(candidate: Dictionary) -> bool:
	return (
		bool(candidate.get("active", false))
		and candidate.get("screen_pos", null) is Vector2
		and candidate.get("clip_position", null) is Vector2
		and candidate.get("clip_size", null) is Vector2
		and _vector2(candidate.get("clip_size", Vector2.ZERO), Vector2.ZERO).x > 0.0
		and _vector2(candidate.get("clip_size", Vector2.ZERO), Vector2.ZERO).y > 0.0
		and float(candidate.get("intensity", 0.0)) > 0.0
	)


func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _configure_host() -> void:
	z_as_relative = false
	z_index = 12
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ensure_draw_bridge() -> void:
	if _draw_bridge != null and is_instance_valid(_draw_bridge):
		return
	_draw_bridge = MysticDicePaddleDrawBridge.new()
	_draw_bridge.name = "MysticDicePaddleDrawBridge"
	add_child(_draw_bridge)
