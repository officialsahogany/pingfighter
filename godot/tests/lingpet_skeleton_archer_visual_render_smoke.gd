extends SceneTree

const LingpetSkeletonArcherSkill := preload("res://scripts/lingpet/lingpet_skeleton_archer_skill.gd")

const VIEW_SIZE := Vector2i(760, 750)
const BACKGROUND := Color(0.012, 0.014, 0.018, 1.0)

var _failures: Array[String] = []
var _probe: SkeletonArcherVisualProbe = null
var _skill: Object = null


class FakeOwner:
	extends RefCounted

	var ball_active := false
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class SkeletonArcherVisualProbe:
	extends Node2D

	var skill: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND, true)
		if skill != null:
			skill.draw(self, Vector2.ZERO)


func _init() -> void:
	get_root().size = VIEW_SIZE
	_skill = LingpetSkeletonArcherSkill.new()
	var owner := FakeOwner.new()
	_skill.set_golden_rolls_for_tests([1.0])
	_expect(_skill.launch(Vector2(300.0, 680.0), owner, {"active_skill_level": 1, "spawn_x": 300.0, "spawn_y": 650.0, "arrow_cooldown": 0.0}), "normal Skeleton Archer visual fixture should launch")
	_skill.set_golden_rolls_for_tests([0.0])
	_expect(_skill.launch(Vector2(460.0, 680.0), owner, {"golden_chance_pct": 100.0, "spawn_x": 460.0, "spawn_y": 650.0, "arrow_cooldown": 0.0}), "golden Skeleton Archer visual fixture should launch")
	_skill.update(1.21, owner, null)
	_skill.update(1.05, owner, null)
	_probe = SkeletonArcherVisualProbe.new()
	_probe.name = "SkeletonArcherVisualProbe"
	_probe.skill = _skill
	get_root().add_child(_probe)
	_probe.queue_redraw()
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	await process_frame
	_verify_draw_state()
	_verify_capture_if_available()
	_finish()


func _verify_draw_state() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "Skeleton Archer visual probe should receive a draw callback")
	var snapshot: Dictionary = _skill.get_snapshot()
	_expect(int(snapshot.get("skeleton_archer_archer_count", 0)) == 2, "visual fixture should keep a normal and a golden archer alive")
	_expect(bool(snapshot.get("skeleton_archer_has_golden", false)), "visual fixture should include a golden archer")
	_expect(int(snapshot.get("skeleton_archer_arrow_count", 0)) >= 4, "visual fixture should draw the normal arrow plus golden volley")


func _verify_capture_if_available() -> void:
	if _is_headless_run():
		return
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return
	var snapshot: Dictionary = _skill.get_snapshot()
	var archer_positions: Array = snapshot.get("skeleton_archer_archer_positions", []) as Array
	var arrow_positions: Array = snapshot.get("skeleton_archer_arrow_positions", []) as Array
	_expect(archer_positions.size() >= 2, "visual fixture should expose live archer positions for pixel sampling")
	_expect(arrow_positions.size() >= 1, "visual fixture should expose live arrow positions for pixel sampling")
	if archer_positions.size() < 2:
		return
	var normal_center := _as_vector2(archer_positions[0], Vector2(300.0, 650.0)) + Vector2(0.0, 14.0)
	var golden_center := _as_vector2(archer_positions[1], Vector2(460.0, 650.0)) + Vector2(0.0, 14.0)
	var normal_signature := _region_signature(image, _sample_rect(normal_center, Vector2i(120, 120)))
	var golden_signature := _region_signature(image, _sample_rect(golden_center, Vector2i(140, 120)))
	_expect(int(normal_signature.get("active_count", 0)) >= 24, "normal Skeleton Archer render region should contain visible pixels")
	_expect(int(golden_signature.get("active_count", 0)) >= 24, "golden Skeleton Archer render region should contain visible pixels")
	var arrow_active_count := 0
	for arrow_position in arrow_positions:
		var arrow_signature := _region_signature(image, _sample_rect(_as_vector2(arrow_position, Vector2.ZERO), Vector2i(48, 48)))
		arrow_active_count += int(arrow_signature.get("active_count", 0))
	_expect(arrow_active_count >= 12, "Skeleton Archer arrow render regions should contain visible pixels")
	_expect(_signature_distance(normal_signature, golden_signature) >= 0.025, "normal and golden Skeleton Archer renders should remain visually distinct")


func _is_headless_run() -> bool:
	if OS.get_cmdline_args().has("--headless"):
		return true
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		return true
	return OS.has_feature("headless")


func _region_signature(image: Image, rect: Rect2i) -> Dictionary:
	var active_count := 0
	var red_sum := 0.0
	var green_sum := 0.0
	var blue_sum := 0.0
	for y in range(rect.position.y, min(rect.end.y, image.get_height()), 2):
		for x in range(rect.position.x, min(rect.end.x, image.get_width()), 2):
			var color: Color = image.get_pixel(x, y)
			var delta: float = absf(color.r - BACKGROUND.r) + absf(color.g - BACKGROUND.g) + absf(color.b - BACKGROUND.b)
			if delta <= 0.06:
				continue
			active_count += 1
			red_sum += color.r
			green_sum += color.g
			blue_sum += color.b
	var denom := float(maxi(1, active_count))
	return {
		"active_count": active_count,
		"avg": Color(red_sum / denom, green_sum / denom, blue_sum / denom, 1.0),
		"coverage": float(active_count) / maxf(1.0, float(rect.size.x * rect.size.y) * 0.25),
	}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _sample_rect(center: Vector2, size: Vector2i) -> Rect2i:
	var half := size / 2
	var top_left := Vector2i(int(roundf(center.x)) - half.x, int(roundf(center.y)) - half.y)
	var x0 := clampi(top_left.x, 0, VIEW_SIZE.x - 1)
	var y0 := clampi(top_left.y, 0, VIEW_SIZE.y - 1)
	var x1 := clampi(top_left.x + size.x, x0 + 1, VIEW_SIZE.x)
	var y1 := clampi(top_left.y + size.y, y0 + 1, VIEW_SIZE.y)
	return Rect2i(Vector2i(x0, y0), Vector2i(x1 - x0, y1 - y0))


func _signature_distance(left: Dictionary, right: Dictionary) -> float:
	var left_color: Color = left.get("avg", Color.BLACK)
	var right_color: Color = right.get("avg", Color.BLACK)
	var color_distance: float = (
		absf(left_color.r - right_color.r)
		+ absf(left_color.g - right_color.g)
		+ absf(left_color.b - right_color.b)
	) / 3.0
	var coverage_distance := absf(float(left.get("coverage", 0.0)) - float(right.get("coverage", 0.0)))
	return color_distance + coverage_distance * 0.8


func _finish() -> void:
	if _failures.is_empty():
		print("lingpet_skeleton_archer_visual_render_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
