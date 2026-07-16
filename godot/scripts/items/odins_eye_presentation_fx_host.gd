extends Node2D

const OdinsEyePresentationRenderer := preload("res://scripts/items/odins_eye_presentation_renderer.gd")

const GAME_SIZE := Vector2(760.0, 750.0)


class OverlayDrawBridge:
	extends Control

	var host: Object = null

	func _draw() -> void:
		if host != null and host.has_method("_draw_overlay"):
			host._draw_overlay(self)


# Direct lifecycle cleanup: this detached z=620 node is hidden explicitly at
# every reset boundary (round / serve / stage advance / full reset / unequip /
# victory / death finalize) through the static live-host list below — no
# draw-idle heuristic, so a legitimately skipped redraw can never hide a live
# effect. A static list (not a scene-tree group) is used deliberately: the
# renderer attaches new hosts via call_deferred("add_child"), so a reset that
# lands BEFORE the deferred attach must still reach the pending host.
static var _live_hosts: Array = []

var renderer: Object = OdinsEyePresentationRenderer.new()
var _playfield_clip: Control = null
var _draw_bridge: Control = null
var _context: Dictionary = {}
var _player_pos := Vector2.ZERO
var _paddle_size := Vector2(155.0, 50.0)
var _shake_offset := Vector2.ZERO
var _active := false


func _init() -> void:
	set_process(false)
	visible = false
	z_as_relative = false
	z_index = 620
	_live_hosts.append(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_live_hosts.erase(self)


static func hide_all() -> void:
	# Owner-less reset paths (mythic lifecycle runtimes hold no canvas ref)
	# reach every live host — attached OR still pending deferred add_child.
	for host in _live_hosts.duplicate():
		if is_instance_valid(host) and host.has_method("set_active"):
			host.set_active(false)


func prepare() -> void:
	_build_children()


func sync_state(
	next_context: Dictionary,
	next_player_pos: Vector2,
	next_paddle_size: Vector2,
	next_shake_offset: Vector2,
	layout: Dictionary
) -> void:
	_build_children()
	_context = next_context.duplicate(true)
	_player_pos = next_player_pos
	_paddle_size = next_paddle_size
	_shake_offset = next_shake_offset
	position = _as_vector2(layout.get("game_offset", Vector2.ZERO))
	var render_scale: float = maxf(0.001, float(layout.get("render_scale", 1.0)))
	scale = Vector2(render_scale, render_scale)
	_active = true
	visible = true
	if _draw_bridge != null:
		_draw_bridge.queue_redraw()


func set_active(next_active: bool) -> void:
	_active = next_active
	visible = next_active
	if next_active:
		return
	_context.clear()
	if _draw_bridge != null:
		_draw_bridge.queue_redraw()


func get_debug_status() -> Dictionary:
	return {
		"active": _active and visible,
		"playfield_clip_active": (
			_playfield_clip != null
			and _playfield_clip.clip_contents
			and _playfield_clip.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW
			and _playfield_clip.position == Vector2.ZERO
			and _playfield_clip.size == GAME_SIZE
		),
		"draw_bridge_inside_clip": (
			_draw_bridge != null
			and _playfield_clip != null
			and _draw_bridge.get_parent() == _playfield_clip
			and _draw_bridge.size == GAME_SIZE
		),
		"game_offset": position,
		"render_scale": scale.x,
		"shake_offset": _shake_offset,
	}


func _draw_overlay(canvas: CanvasItem) -> void:
	if not _active or canvas == null:
		return
	renderer.draw_overlay(canvas, _context, _player_pos, _paddle_size, _shake_offset)


func _build_children() -> void:
	if _playfield_clip != null:
		return
	_playfield_clip = Control.new()
	_playfield_clip.name = "OdinsEyePlayfieldClip"
	_playfield_clip.position = Vector2.ZERO
	_playfield_clip.size = GAME_SIZE
	_playfield_clip.clip_contents = true
	_playfield_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_playfield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playfield_clip)

	var bridge := OverlayDrawBridge.new()
	bridge.name = "OdinsEyeOverlayDrawBridge"
	bridge.host = self
	bridge.position = Vector2.ZERO
	bridge.size = GAME_SIZE
	bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_clip.add_child(bridge)
	_draw_bridge = bridge


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO
