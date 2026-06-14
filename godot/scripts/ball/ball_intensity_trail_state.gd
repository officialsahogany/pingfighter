extends RefCounted

const BallEffectPayloadFactory := preload("res://scripts/ball/ball_effect_payload_factory.gd")

const SEVERE_LOD_SCALE_THRESHOLD := 0.50
const SEVERE_LOD_TRAIL_LENGTH := 4

var intensity_trail: Array[Dictionary] = []


func clear() -> void:
	intensity_trail.clear()


func update(
	ball_center: Vector2,
	fps_scale: float,
	intensity: float,
	colors: Array[Color],
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = effect_lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var trail_spacing: float = 8.0 + intensity * 5.0
	var trail_length: int = int(6.0 + intensity * 6.0)
	if severe_lod:
		trail_spacing *= 1.35
		trail_length = min(trail_length, SEVERE_LOD_TRAIL_LENGTH)
	var trail_alpha: float = (210.0 + intensity * 35.0) / 255.0
	var trail_size: float = 6.0 + intensity * 7.0
	if intensity_trail.is_empty():
		intensity_trail.append(BallEffectPayloadFactory.build_intensity_trail_point(ball_center, trail_alpha, trail_size, colors[0]))
	else:
		var last_trail: Dictionary = intensity_trail[intensity_trail.size() - 1]
		var last_pos: Vector2 = last_trail["pos"]
		var delta_pos: Vector2 = ball_center - last_pos
		var distance: float = delta_pos.length()
		if distance >= trail_spacing:
			var segments: int = int(distance / trail_spacing)
			segments = clampi(segments, 1, 2)
			if severe_lod:
				segments = 1
			for step in range(1, segments + 1):
				var t: float = float(step) / float(segments)
				intensity_trail.append(BallEffectPayloadFactory.build_intensity_trail_point(last_pos.lerp(ball_center, t), trail_alpha, trail_size, colors[0]))

	while intensity_trail.size() > trail_length:
		intensity_trail.pop_front()

	var write_idx: int = 0
	var trail_fade: float = pow(0.8 + intensity * 0.08, fps_scale)
	for i in range(intensity_trail.size()):
		var p: Dictionary = intensity_trail[i]
		var alpha: float = float(p["alpha"]) * trail_fade
		var size: float = float(p["size"]) * pow(0.94, fps_scale)
		if alpha > 10.0 / 255.0 and size > 0.5:
			p["alpha"] = alpha
			p["size"] = size
			intensity_trail[write_idx] = p
			write_idx += 1
	intensity_trail.resize(write_idx)


func get_trail() -> Array[Dictionary]:
	return intensity_trail
