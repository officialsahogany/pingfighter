extends SceneTree

const SandPrisonSkill := preload("res://scripts/lingpet/lingpet_sand_prison_skill.gd")

const VIEW_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var lingpet_sand_prison_clamp_active := false
	var lingpet_sand_prison_cage_left := 0.0
	var lingpet_sand_prison_cage_right := 760.0


class SandPrisonDrawNode:
	extends Node2D

	var skill: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if skill != null:
			skill.draw(self, Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := FakeOwner.new()
	var skill := SandPrisonSkill.new()
	_expect(skill.launch(Vector2(380.0, 640.0), owner, {"active_skill_level": 5}), "visual smoke should launch Sand Prison")
	skill.update(float(skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, owner)
	_expect(bool(owner.lingpet_sand_prison_clamp_active), "visual smoke should enter captured cage state")

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var draw_node := SandPrisonDrawNode.new()
	draw_node.skill = skill
	viewport.add_child(draw_node)
	draw_node.queue_redraw()
	for _idx in range(4):
		await process_frame

	_expect(draw_node.draw_count > 0, "Sand Prison cage draw should run through a viewport CanvasItem _draw")
	_expect(skill.has_visible_effects(), "Sand Prison visual state should remain visible after the draw pass")
	_verify_capture_pixels(viewport, skill, owner)

	# MISS 세척(모래바람) draw 경로도 실행 커버리지에 포함: 도주 → MISSING 중간 시점에서 draw.
	var miss_owner := FakeOwner.new()
	var miss_skill := SandPrisonSkill.new()
	_expect(miss_skill.launch(Vector2(380.0, 640.0), miss_owner, {"active_skill_level": 1}), "visual smoke miss case should launch")
	miss_owner.boss_pos.x = float(miss_skill.get_snapshot().get("sand_prison_cage_right", 760.0)) + 24.0
	miss_skill.update(float(miss_skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, miss_owner)
	miss_skill.update(0.2, miss_owner)
	_expect(bool(miss_skill.get_snapshot().get("sand_prison_missing", false)), "visual smoke miss case should be mid-wash in MISSING")
	var miss_draw_node := SandPrisonDrawNode.new()
	miss_draw_node.skill = miss_skill
	viewport.add_child(miss_draw_node)
	miss_draw_node.queue_redraw()
	for _idx in range(2):
		await process_frame
	_expect(miss_draw_node.draw_count > 0, "Sand Prison MISS wash draw should run through a viewport CanvasItem _draw")

	viewport.queue_free()

	if _failures.is_empty():
		print("lingpet_sand_prison_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_capture_pixels(viewport: SubViewport, skill: Object, owner: FakeOwner) -> void:
	if _is_headless_run():
		return
	var texture: Texture2D = viewport.get_texture()
	_expect(texture != null, "Sand Prison visual smoke should expose a viewport texture")
	if texture == null:
		return
	var image: Image = texture.get_image()
	_expect(image != null and image.get_width() == VIEW_SIZE.x and image.get_height() == VIEW_SIZE.y, "Sand Prison visual smoke should capture a full-size viewport image")
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var snapshot: Dictionary = skill.get_snapshot()
	var left := int(roundf(float(snapshot.get("sand_prison_cage_left", 0.0))))
	var right := int(roundf(float(snapshot.get("sand_prison_cage_right", 0.0))))
	var top := int(roundf(clampf(owner.boss_pos.y - 50.0, 0.0, float(VIEW_SIZE.y - 1))))
	var bottom := int(roundf(clampf(owner.boss_pos.y + owner.boss_hitbox_height + 88.0, 1.0, float(VIEW_SIZE.y))))
	var total_visible := _count_alpha_pixels(image, Rect2i(Vector2i.ZERO, VIEW_SIZE), 0.02, 4)
	_expect(total_visible > 700, "Sand Prison capture should draw non-empty cage pixels")
	var left_wall_visible := _count_alpha_pixels(image, _sample_rect(left - 4, top, left + 4, bottom), 0.45, 1)
	var right_wall_visible := _count_alpha_pixels(image, _sample_rect(right - 4, top, right + 4, bottom), 0.45, 1)
	_expect(left_wall_visible > 180, "Sand Prison left wall should render high-alpha grain strips")
	_expect(right_wall_visible > 180, "Sand Prison right wall should render high-alpha grain strips")
	var top_bar_visible := _count_alpha_pixels(image, _sample_rect(left - 4, top, right + 4, top + 5), 0.45, 1)
	var bottom_bar_visible := _count_alpha_pixels(image, _sample_rect(left - 4, bottom - 5, right + 4, bottom), 0.45, 1)
	_expect(top_bar_visible > 180, "Sand Prison completed cage should reveal the high-alpha top grain bar")
	_expect(bottom_bar_visible > 180, "Sand Prison completed cage should keep the high-alpha bottom grain bar")


func _is_headless_run() -> bool:
	if OS.get_cmdline_args().has("--headless"):
		return true
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		return true
	return OS.has_feature("headless")


func _sample_rect(x0: int, y0: int, x1: int, y1: int) -> Rect2i:
	var left := clampi(mini(x0, x1), 0, VIEW_SIZE.x - 1)
	var top := clampi(mini(y0, y1), 0, VIEW_SIZE.y - 1)
	var right := clampi(maxi(x0, x1), left + 1, VIEW_SIZE.x)
	var bottom := clampi(maxi(y0, y1), top + 1, VIEW_SIZE.y)
	return Rect2i(Vector2i(left, top), Vector2i(right - left, bottom - top))


func _count_alpha_pixels(image: Image, rect: Rect2i, min_alpha: float, step: int) -> int:
	var count := 0
	var stride := maxi(1, step)
	for y in range(rect.position.y, rect.end.y, stride):
		for x in range(rect.position.x, rect.end.x, stride):
			if image.get_pixel(x, y).a > min_alpha:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
