extends SceneTree

const LingpetBoneBarrierSkill := preload("res://scripts/lingpet/lingpet_bone_barrier_skill.gd")

const VIEW_SIZE := Vector2i(760, 750)
const BACKGROUND := Color(0.012, 0.014, 0.018, 1.0)

var _failures: Array[String] = []
var _probe: BoneBarrierVisualProbe = null
var _skill: Object = null


class FakeOwner:
	extends RefCounted

	var ball_active := false
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6


class BoneBarrierVisualProbe:
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
	_skill = LingpetBoneBarrierSkill.new()
	var owner := FakeOwner.new()
	_expect(_skill.launch(Vector2(380.0, 680.0), owner, {"barrier_x": 320.0}), "built Bone Barrier visual fixture should launch")
	_skill.update(3.01, owner, null)
	_expect(_skill.launch(Vector2(230.0, 680.0), owner, {"barrier_x": 170.0}), "building Bone Barrier visual fixture should launch")
	_skill.update(0.35, owner, null)
	_probe = BoneBarrierVisualProbe.new()
	_probe.name = "BoneBarrierVisualProbe"
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
	_expect(_probe != null and _probe.draw_count > 0, "Bone Barrier visual probe should receive a draw callback")
	var snapshot: Dictionary = _skill.get_snapshot()
	_expect(int(snapshot.get("bone_barrier_barrier_count", 0)) == 2, "visual fixture should keep one built and one building barrier alive")
	_expect(int(snapshot.get("bone_barrier_built_count", 0)) == 1, "visual fixture should include exactly one built barrier")


func _verify_capture_if_available() -> void:
	if _is_headless_run():
		return
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return
	var built_signature := _region_signature(image, Rect2i(Vector2i(300, 710), Vector2i(160, 40)))
	var building_signature := _region_signature(image, Rect2i(Vector2i(150, 690), Vector2i(180, 70)))
	_expect(int(built_signature.get("active_count", 0)) >= 24, "built Bone Barrier render region should contain visible pixels")
	_expect(int(building_signature.get("active_count", 0)) >= 12, "building Bone Barrier render region should contain visible assembly pixels")


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
	}


func _finish() -> void:
	if _failures.is_empty():
		print("lingpet_bone_barrier_visual_render_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
