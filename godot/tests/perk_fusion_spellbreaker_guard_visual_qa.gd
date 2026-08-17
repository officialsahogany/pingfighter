extends SceneTree

const SpellbreakerGuardState := preload("res://scripts/characters/perk_fusion_spellbreaker_guard_state.gd")
const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")

const VIEW_SIZE := Vector2i(760, 750)
const CAPTURE_PATH := "res://.tmp/perk_fusion_spellbreaker_guard_visual_qa.png"
const BOSS_POS := Vector2(330.0, 25.0)
const BOSS_SIZE := Vector2(100.0, 40.0)


# 실전 호출부 대부분은 명시 위치를 넘기지 않는다. 그러니 QA도 상태에 좌표를
# 직접 먹이지 말고 공용 게이트를 관통해야 한다 — 원점이 결계 자신으로
# 무너지는 회귀는 그때만 캡처에 드러난다.
class ParryGateRuntime:
	extends RefCounted
	var state: Object = SpellbreakerGuardState.new()

	func is_perk_fusion_boss_skill_parry_active() -> bool:
		return bool(state.is_active())

	func try_parry_perk_fusion_boss_skill(skill_id: String, label: String, impact_pos: Vector2) -> Dictionary:
		return state.try_parry(skill_id, label, impact_pos)


class WardProbe:
	extends Node2D
	var ward: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.018, 0.024, 0.050), true)
		for line_index in range(10):
			var y := 46.0 + float(line_index) * 68.0
			draw_line(Vector2(0.0, y), Vector2(float(VIEW_SIZE.x), y), Color(0.08, 0.13, 0.25, 0.32), 1.0)
		var player_rect := Rect2(Vector2(302.5, 675.0), Vector2(155.0, 50.0))
		draw_rect(player_rect, Color(0.22, 0.32, 0.50, 1.0), true)
		draw_rect(player_rect, Color(0.72, 0.84, 1.0, 0.92), false, 2.0)
		var boss_rect := Rect2(BOSS_POS, BOSS_SIZE)
		draw_rect(boss_rect, Color(0.42, 0.20, 0.26, 1.0), true)
		draw_rect(boss_rect, Color(1.0, 0.62, 0.58, 0.92), false, 2.0)
		if ward != null:
			ward.draw(self)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("perk_fusion_spellbreaker_guard_visual_qa: capture skipped under headless display server")
		print("perk_fusion_spellbreaker_guard_visual_qa: ok")
		quit(0)
		return

	var baseline_probe := WardProbe.new()
	var baseline_viewport := _build_viewport(baseline_probe)
	var runtime := ParryGateRuntime.new()
	var active_state: Object = runtime.state
	active_state.try_activate(["spellbreaker_guard"], 0.0, Vector2(380.0, 700.0))
	var parried: bool = BossSkillParryGate.try_parry(
		"visual_probe",
		"화염탄",
		{
			"player_pos": Vector2(302.5, 675.0),
			"player_paddle_width": 155.0,
			"player_paddle_height": 50.0,
			"boss_pos": BOSS_POS,
			"boss_paddle_width": BOSS_SIZE.x,
			"boss_hitbox_height": BOSS_SIZE.y,
		},
		{"runtime_perk_state": runtime}
	)
	if not parried:
		_fail("the shared parry gate should block through the open ward")
		return
	var active_probe := WardProbe.new()
	active_probe.ward = active_state
	var active_viewport := _build_viewport(active_probe)

	baseline_probe.queue_redraw()
	active_probe.queue_redraw()
	for _frame_index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var baseline_image := baseline_viewport.get_texture().get_image()
	var active_image := active_viewport.get_texture().get_image()
	if baseline_image == null or active_image == null or baseline_image.is_empty() or active_image.is_empty():
		_fail("spellbreaker ward visual QA should render non-empty images")
		return
	var changed_pixels := _count_changed_pixels(baseline_image, active_image)
	if changed_pixels < 1100:
		_fail("spellbreaker ward and parry line should remain clearly visible (%d changed pixels)" % changed_pixels)
		return
	var ward_ink := _count_ward_pixels(active_image)
	if ward_ink < 260:
		_fail("spellbreaker ward should retain readable cyan-violet energy (%d pixels)" % ward_ink)
		return
	# 파열광이 결계 위로만 남고 스킬 원점까지 뻗지 않으면(원점 붕괴 회귀)
	# 중앙 필드 밴드는 완전히 비어 있다.
	var midfield_ink := _count_changed_pixels_in_band(baseline_image, active_image, 200, 520)
	if midfield_ink < 200:
		_fail("the parry beam should reach from the ward up to the boss skill origin (%d midfield pixels)" % midfield_ink)
		return
	if active_image.save_png(CAPTURE_PATH) != OK:
		_fail("failed to save spellbreaker ward visual QA capture")
		return
	baseline_probe.queue_free()
	baseline_viewport.queue_free()
	active_probe.queue_free()
	active_viewport.queue_free()
	await process_frame
	print("perk_fusion_spellbreaker_guard_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)


func _build_viewport(probe: Node2D) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)
	viewport.add_child(probe)
	return viewport


func _count_changed_pixels(first: Image, second: Image) -> int:
	var changed := 0
	for y in range(VIEW_SIZE.y):
		for x in range(VIEW_SIZE.x):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
				changed += 1
	return changed


func _count_ward_pixels(image: Image) -> int:
	var count := 0
	for y in range(VIEW_SIZE.y):
		for x in range(VIEW_SIZE.x):
			var pixel := image.get_pixel(x, y)
			if pixel.b > 0.56 and (pixel.g > 0.46 or pixel.r > 0.46):
				count += 1
	return count


func _count_changed_pixels_in_band(first: Image, second: Image, y_min: int, y_max: int) -> int:
	var changed := 0
	for y in range(maxi(0, y_min), mini(VIEW_SIZE.y, y_max)):
		for x in range(VIEW_SIZE.x):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
				changed += 1
	return changed


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
