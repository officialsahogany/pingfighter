extends RefCounted

const GOLDEN_ANGLE := 2.39996323
const PALETTE: Array[Color] = [
	Color(1.0, 0.84, 0.45),
	Color(1.0, 1.0, 0.95),
	Color(0.62, 0.66, 1.0),
]

var beams: Array[Dictionary] = []
var angle_cursor := 0.0


func begin(rng: RandomNumberGenerator) -> void:
	beams.clear()
	angle_cursor = rng.randf() * TAU if rng != null else 0.0


func clear() -> void:
	beams.clear()
	angle_cursor = 0.0


func spawn_tick(tick_index: int, rng: RandomNumberGenerator) -> void:
	if rng == null:
		return
	var count := 2 + int(round(float(tick_index) * 1.6)) + rng.randi_range(0, 2)
	for _beam_index in range(count):
		angle_cursor += GOLDEN_ANGLE + rng.randf_range(-0.22, 0.22)
		beams.append({
			"angle": angle_cursor,
			"age": 0.0,
			"life": 0.7 + rng.randf() * 0.5,
			"extend_time": 0.07 + rng.randf() * 0.05,
			"max_len": 900.0 + rng.randf() * 560.0,
			"width": (rng.randf_range(14.0, 22.0) + float(tick_index) * rng.randf_range(3.0, 6.0)) * rng.randf_range(1.2, 1.8),
			"color": PALETTE[rng.randi() % PALETTE.size()],
		})


func update(delta: float) -> void:
	if beams.is_empty():
		return
	var dt := maxf(0.0, delta)
	var index := beams.size() - 1
	while index >= 0:
		var beam: Dictionary = beams[index]
		beam["age"] = float(beam.get("age", 0.0)) + dt
		if float(beam["age"]) >= float(beam.get("life", 0.5)):
			beams.remove_at(index)
		index -= 1
