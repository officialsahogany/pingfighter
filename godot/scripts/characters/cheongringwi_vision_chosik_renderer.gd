extends RefCounted

const Stage2PillarObstacleVisualRenderer := preload(
	"res://scripts/stages/stage2/stage2_pillar_obstacle_visual_renderer.gd"
)
const Stage2WarningVisualRenderer := preload(
	"res://scripts/stages/stage2/stage2_warning_visual_renderer.gd"
)
const Stage2QuakeCoordinator := preload("res://scripts/stages/stage2/stage2_quake_coordinator.gd")

var _rock_renderer: Object = Stage2PillarObstacleVisualRenderer.new()
var _warning_renderer: Object = Stage2WarningVisualRenderer.new()


func draw(canvas: CanvasItem, snapshot: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	var width := maxf(1.0, float(snapshot.get("width", 760.0)))
	var quake_timer := maxf(0.0, float(snapshot.get("quake_timer", 0.0)))
	var quake_duration := maxf(0.001, float(snapshot.get("quake_duration", Stage2QuakeCoordinator.DEFAULT_DURATION_SEC)))
	_warning_renderer.draw_quake_waves(canvas, width, shake_offset, {
		"timer": quake_timer,
		"duration": quake_duration,
		"wave_count": Stage2QuakeCoordinator.WAVE_COUNT,
		"wave_segments": Stage2QuakeCoordinator.WAVE_SEGMENTS,
	})
	var rocks_value: Variant = snapshot.get("rocks", [])
	var rocks: Array = rocks_value as Array if rocks_value is Array else []
	var rock_assets := {
		"rock_texture": snapshot.get("rock_texture", null),
		"rock_source_regions": snapshot.get("rock_source_regions", []),
		"rock_debris_texture": snapshot.get("rock_debris_texture", null),
		"rock_debris_source_regions": snapshot.get("rock_debris_source_regions", []),
		"rock_fragment_life_sec": snapshot.get("rock_fragment_life_sec", 45.0 / 60.0),
	}
	for rock_value: Variant in rocks:
		if rock_value is Dictionary:
			_rock_renderer.draw_rock(canvas, rock_value as Dictionary, shake_offset, rock_assets)
	var fragments_value: Variant = snapshot.get("rock_fragments", [])
	var fragments: Array = fragments_value as Array if fragments_value is Array else []
	for fragment_value: Variant in fragments:
		if fragment_value is Dictionary:
			_rock_renderer.draw_rock_fragment(
				canvas,
				fragment_value as Dictionary,
				shake_offset,
				rock_assets
			)
	var impacts_value: Variant = snapshot.get("impacts", [])
	var impacts: Array = impacts_value as Array if impacts_value is Array else []
	for impact_value: Variant in impacts:
		if impact_value is Dictionary:
			_draw_impact(canvas, impact_value as Dictionary, shake_offset)


func _draw_impact(canvas: CanvasItem, impact: Dictionary, shake_offset: Vector2) -> void:
	var max_life := maxf(0.001, float(impact.get("max_life", 0.34)))
	var life_ratio := clampf(float(impact.get("life", 0.0)) / max_life, 0.0, 1.0)
	if life_ratio <= 0.0:
		return
	var center := _get_vector2(impact.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var radius := maxf(1.0, float(impact.get("radius", 40.0)))
	var expand := 1.0 - life_ratio
	canvas.draw_circle(center, radius * (0.32 + expand * 0.36), Color(0.93, 0.68, 0.24, 0.16 * life_ratio))
	canvas.draw_arc(center, radius * (0.58 + expand * 0.70), 0.0, TAU, 30, Color(0.96, 0.84, 0.42, 0.72 * life_ratio), 3.0, true)
	for crack_index in range(8):
		var angle := TAU * float(crack_index) / 8.0 + float(crack_index % 2) * 0.12
		var inner := center + Vector2.from_angle(angle) * radius * 0.36
		var outer := center + Vector2.from_angle(angle + sin(float(crack_index) * 3.1) * 0.10) * radius * (0.78 + expand * 0.34)
		canvas.draw_line(inner, outer, Color(0.24, 0.16, 0.07, 0.80 * life_ratio), 2.0, true)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
