extends RefCounted

const WALL_ARC_REPOINT_SCALE := 0.25

var active: bool = false
var elapsed: float = 0.0
var direction: int = 0
var arc_strength: float = 0.0
var combo_consumed: int = 0
var wall_repointed: bool = false


func reset() -> void:
	active = false
	elapsed = 0.0
	direction = 0
	arc_strength = 0.0
	combo_consumed = 0
	wall_repointed = false


func prepare(new_direction: int, new_arc_strength: float, new_combo_consumed: int) -> void:
	direction = new_direction
	arc_strength = new_arc_strength
	combo_consumed = new_combo_consumed
	active = false
	elapsed = 0.0
	wall_repointed = false


func start() -> void:
	active = true
	elapsed = 0.0


func finish() -> void:
	active = false
	elapsed = 0.0


func step(fps_scale: float) -> bool:
	if not active:
		return false
	elapsed += fps_scale / 60.0
	return true


func repoint_arc_away_from(side: String) -> void:
	if not active:
		return
	if side != "left" and side != "right":
		return
	var away_sign: float = 1.0 if side == "left" else -1.0
	if wall_repointed:
		arc_strength = away_sign * abs(arc_strength)
		return
	arc_strength = away_sign * abs(arc_strength) * WALL_ARC_REPOINT_SCALE
	wall_repointed = true


func is_active() -> bool:
	return active


func get_elapsed() -> float:
	return elapsed


func get_direction() -> int:
	return direction


func get_arc_strength() -> float:
	return arc_strength


func get_combo_consumed() -> int:
	return combo_consumed
