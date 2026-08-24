extends RefCounted

# Stage 6 Tetriser transient combat feedback owner.
#
# Debris flashes, EMP ripples, and one-frame-deduplicated sound requests share
# the same combat-event/reset lifecycle. The Stage 6 host decides when events
# occur; this owner retains, advances, snapshots, flushes, and clears them.

const TetriserCubeState := preload("res://scripts/stages/stage6/stage6_tetriser_cube_state.gd")

const DEBRIS_LIFE_SEC := 0.35
const EMP_LIFE_SEC := 0.6

const SOUND_BREAK: StringName = &"break"
const SOUND_WALL: StringName = &"wall"
const SOUND_SUPER: StringName = &"super"
const SOUND_BIG: StringName = &"big"
const SOUND_SHIELD: StringName = &"shield"
const SOUND_LASER: StringName = &"laser"
const SOUND_ORDER := [
	SOUND_BREAK,
	SOUND_WALL,
	SOUND_SUPER,
	SOUND_BIG,
	SOUND_SHIELD,
	SOUND_LASER,
]
const SOUND_METHODS := {
	SOUND_BREAK: &"play_stage6_tetriser_break",
	SOUND_WALL: &"play_stage6_tetriser_wall",
	SOUND_SUPER: &"play_stage6_tetriser_super",
	SOUND_BIG: &"play_stage6_tetriser_big",
	SOUND_SHIELD: &"play_stage6_tetriser_shield",
	SOUND_LASER: &"play_stage6_tetriser_laser",
}

var _debris: Array[Dictionary] = []
var _emp_ripples: Array[Dictionary] = []
var _pending_sounds: Dictionary = {}


func reset() -> void:
	_debris.clear()
	_emp_ripples.clear()
	_pending_sounds.clear()


func has_runtime_state() -> bool:
	return not _debris.is_empty() or not _emp_ripples.is_empty() or not _pending_sounds.is_empty()


func emit_debris(origin: Vector2, cells: Array, color: Color, cell_size: float) -> void:
	var rects: Array = []
	for cell in cells:
		rects.append(Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size)))
	_debris.append({
		"rects": rects,
		"color": color,
		"life": DEBRIS_LIFE_SEC,
		"max_life": DEBRIS_LIFE_SEC,
	})


func emit_debris_events(events: Array, fallback_color: Color, default_cell_size: float) -> void:
	for event in events:
		emit_debris(
			event.get("origin", Vector2.ZERO),
			event.get("cells", []),
			event.get("color", fallback_color),
			float(event.get("cell_size", default_cell_size))
		)


func emit_emp(center: Vector2) -> void:
	_emp_ripples.append({
		"center": center,
		"timer": EMP_LIFE_SEC,
		"max": EMP_LIFE_SEC,
	})


func queue_sound(cue: StringName) -> void:
	if SOUND_METHODS.has(cue):
		_pending_sounds[cue] = true


func update(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	_update_emp(safe_delta)
	_update_debris(safe_delta)


func flush_sounds(deps: Dictionary) -> void:
	if _pending_sounds.is_empty():
		return
	var audio_value: Variant = deps.get("audio", null)
	if audio_value is Object:
		var audio := audio_value as Object
		for cue in SOUND_ORDER:
			if not _pending_sounds.has(cue):
				continue
			var method := StringName(SOUND_METHODS.get(cue, &""))
			if method != &"" and audio.has_method(method):
				audio.call(method)
	_pending_sounds.clear()


func get_debris_draw_list() -> Array:
	var out: Array = []
	for debris in _debris:
		var max_life: float = maxf(0.001, float(debris.get("max_life", DEBRIS_LIFE_SEC)))
		out.append({
			"rects": (debris.get("rects", []) as Array).duplicate(),
			"color": debris.get("color", Color(1.0, 1.0, 1.0)),
			"progress": clampf(1.0 - float(debris.get("life", 0.0)) / max_life, 0.0, 1.0),
		})
	return out


func get_emp_draw_list() -> Array:
	var out: Array = []
	for ripple in _emp_ripples:
		var max_life: float = maxf(0.001, float(ripple.get("max", EMP_LIFE_SEC)))
		out.append({
			"center": ripple.get("center", TetriserCubeState.CENTER),
			"progress": clampf(1.0 - float(ripple.get("timer", 0.0)) / max_life, 0.0, 1.0),
		})
	return out


func get_debris_count() -> int:
	return _debris.size()


func get_emp_count() -> int:
	return _emp_ripples.size()


func get_pending_sound_cues() -> Array:
	var out: Array = []
	for cue in SOUND_ORDER:
		if _pending_sounds.has(cue):
			out.append(cue)
	return out


func _update_debris(delta: float) -> void:
	if _debris.is_empty():
		return
	var alive: Array[Dictionary] = []
	for debris in _debris:
		var life: float = float(debris.get("life", 0.0)) - delta
		if life > 0.0:
			debris["life"] = life
			alive.append(debris)
	_debris = alive


func _update_emp(delta: float) -> void:
	if _emp_ripples.is_empty():
		return
	var alive: Array[Dictionary] = []
	for ripple in _emp_ripples:
		var timer: float = float(ripple.get("timer", 0.0)) - delta
		if timer > 0.0:
			ripple["timer"] = timer
			alive.append(ripple)
	_emp_ripples = alive
