extends SceneTree

const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const BACKGROUND := Color(0.015, 0.018, 0.025, 1.0)

var _failures: Array[String] = []
var _probe: CommandoFirearmStage1VisualProbe = null
var _frame_count := 0


class CommandoFirearmStage1VisualProbe:
	extends Node2D

	var renderer: Object = Stage1CommandoFirearmRenderer.new()
	var context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND, true)
		renderer.draw(self, context, Vector2.ZERO)


func _init() -> void:
	get_root().size = VIEW_SIZE
	_probe = CommandoFirearmStage1VisualProbe.new()
	_probe.name = "CommandoFirearmStage1VisualProbe"
	_probe.context = _build_visual_qa_context()
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_verify_visual_qa_capture()
	if _failures.is_empty():
		print("commando_firearm_stage1_visual_qa_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _verify_visual_qa_capture() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "Stage1 Commando firearm visual QA probe should receive a live draw callback")
	if _is_headless_run():
		_verify_visual_identity_context_without_pixels()
		return
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		_verify_visual_identity_context_without_pixels()
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_verify_visual_identity_context_without_pixels()
		return
	_expect(image != null and image.get_width() >= VIEW_SIZE.x and image.get_height() >= VIEW_SIZE.y, "Stage1 visual QA should capture the rendered viewport image")
	var regions := {
		"pistol": Rect2i(55, 70, 100, 120),
		"commando_pistol": Rect2i(205, 70, 110, 120),
		"ak47": Rect2i(360, 70, 120, 120),
		"bazooka": Rect2i(535, 60, 130, 140),
		"net_gun": Rect2i(45, 345, 130, 140),
		"fire_support": Rect2i(205, 310, 140, 170),
		"bowling_trap": Rect2i(350, 345, 140, 150),
		"suicide_drone": Rect2i(540, 330, 150, 160),
	}
	var signatures := {}
	for family in regions.keys():
		var signature: Dictionary = _region_signature(image, regions[family])
		signatures[family] = signature
		_expect(int(signature.get("active_count", 0)) >= 18, "Stage1 visual QA should render visible pixels for %s" % family)
		_expect(float(signature.get("alpha_sum", 0.0)) > 4.0, "Stage1 visual QA should capture nontransparent draw output for %s" % family)
	for left_index in range(regions.keys().size()):
		for right_index in range(left_index + 1, regions.keys().size()):
			var left: String = str(regions.keys()[left_index])
			var right: String = str(regions.keys()[right_index])
			var distance: float = _signature_distance(signatures[left], signatures[right])
			_expect(distance >= 0.030, "Stage1 visual QA should keep %s and %s visually distinguishable" % [left, right])
	var report: Dictionary = Stage1CommandoFirearmRenderer.new().build_visual_identity_report(_probe.context)
	_expect(bool(report.get("all_required_families_present", false)), "Stage1 visual QA context should still cover every Commando firearm identity family")


func _verify_visual_identity_context_without_pixels() -> void:
	var renderer := Stage1CommandoFirearmRenderer.new()
	var report: Dictionary = renderer.build_visual_identity_report(_probe.context)
	_expect(bool(report.get("all_required_families_present", false)), "Stage1 headless visual QA should still cover every Commando firearm identity family")
	_expect(int(report.get("family_count", 0)) == 8, "Stage1 headless visual QA should still distinguish eight Commando firearm families")
	var plan: Dictionary = renderer.build_texture_remaster_plan(_probe.context)
	_expect(int(plan.get("weapon_visual_identity_count", 0)) == 8, "Stage1 headless visual QA should keep the renderer visual identity count at eight")


func _is_headless_run() -> bool:
	if OS.get_cmdline_args().has("--headless"):
		return true
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		return true
	return OS.has_feature("headless")


func _build_visual_qa_context() -> Dictionary:
	return {
		"commando_firearm_projectiles": [
			{
				"weapon_id": "pistol",
				"kind": "bullet",
				"pos": Vector2(105.0, 130.0),
				"prev_pos": Vector2(72.0, 160.0),
				"velocity": Vector2(22.0, -18.0),
				"radius": 4.4,
				"color": Color(0.96, 0.82, 0.36),
				"secondary": Color(1.0, 0.52, 0.18),
			},
			{
				"weapon_id": "commando_pistol",
				"kind": "bullet",
				"pos": Vector2(260.0, 130.0),
				"prev_pos": Vector2(232.0, 160.0),
				"velocity": Vector2(20.0, -20.0),
				"radius": 5.0,
				"color": Color(1.0, 0.86, 0.40),
				"secondary": Color(1.0, 0.50, 0.18),
			},
			{
				"weapon_id": "ak47",
				"kind": "bullet",
				"pos": Vector2(420.0, 130.0),
				"prev_pos": Vector2(384.0, 150.0),
				"velocity": Vector2(26.0, -13.0),
				"radius": 3.6,
				"color": Color(0.95, 1.0, 0.50),
				"secondary": Color(0.72, 0.94, 0.25),
			},
			{
				"weapon_id": "bazooka",
				"kind": "rocket",
				"pos": Vector2(600.0, 130.0),
				"prev_pos": Vector2(600.0, 174.0),
				"velocity": Vector2(0.0, -16.0),
				"radius": 10.0,
				"color": Color(1.0, 0.46, 0.18),
				"secondary": Color(1.0, 0.88, 0.38),
				"smoke_trail": [Vector2(600.0, 156.0), Vector2(596.0, 174.0), Vector2(604.0, 192.0)],
			},
			{
				"weapon_id": "net_gun",
				"kind": "net",
				"pos": Vector2(105.0, 420.0),
				"origin": Vector2(60.0, 465.0),
				"rope_points": [Vector2(72.0, 455.0), Vector2(88.0, 438.0)],
				"radius": 18.0,
				"color": Color(0.42, 1.0, 0.52),
				"secondary": Color(0.18, 0.65, 0.28),
			},
			{
				"weapon_id": "fire_support",
				"kind": "support",
				"pos": Vector2(265.0, 430.0),
				"prev_pos": Vector2(265.0, 370.0),
				"radius": 9.0,
				"color": Color(1.0, 0.34, 0.16),
				"secondary": Color(1.0, 0.82, 0.25),
			},
			{
				"weapon_id": "suicide_drone",
				"kind": "drone",
				"pos": Vector2(610.0, 420.0),
				"velocity": Vector2(5.0, -12.0),
				"radius": 24.0,
				"size": Vector2(48.0, 48.0),
				"rotor_angle": 135.0,
				"color": Color(1.0, 0.42, 0.18),
				"secondary": Color(0.45, 0.86, 1.0),
			},
		],
		"commando_firearm_shell_casings": [
			{"weapon_id": "ak47", "pos": Vector2(450.0, 155.0), "velocity": Vector2(4.0, -2.0), "rotation": 28.0, "lifetime_frames": 90.0, "length": 10.0, "width": 3.0},
		],
		"commando_firearm_support_calls": [
			{
				"origin": Vector2(230.0, 470.0),
				"target": Vector2(265.0, 430.0),
				"call_timer_frames": 26.0,
				"delay_frames": 150.0,
				"aircraft_active": true,
				"aircraft_pos": Vector2(265.0, 350.0),
				"secondary": Color(1.0, 0.82, 0.25),
			},
		],
		"commando_firearm_bowling_traps": [
			{
				"state": "capturing",
				"pos": Vector2(420.0, 430.0),
				"captured_ball_pos": Vector2(420.0, 407.0),
				"width": 72.0,
				"height": 24.0,
				"capture_progress": 0.55,
				"install_progress": 1.0,
				"claw_angle": 0.75,
				"color": Color(0.95, 0.18, 0.24),
				"secondary": Color(0.22, 0.10, 0.12),
			},
		],
		"commando_firearm_lingering_effects": [
			{"kind": "net_field", "pos": Vector2(105.0, 420.0), "width": 116.0, "height": 72.0, "timer_frames": 80.0, "max_timer_frames": 120.0, "color": Color(0.42, 1.0, 0.52), "secondary": Color(0.18, 0.65, 0.28)},
			{"kind": "trap_clamp", "pos": Vector2(420.0, 430.0), "width": 92.0, "height": 42.0, "timer_frames": 50.0, "max_timer_frames": 80.0, "color": Color(0.95, 0.18, 0.24), "secondary": Color(0.22, 0.10, 0.12)},
			{"kind": "fire_zone", "pos": Vector2(610.0, 450.0), "width": 150.0, "height": 60.0, "timer_frames": 64.0, "max_timer_frames": 120.0, "color": Color(1.0, 0.42, 0.18), "secondary": Color(0.45, 0.86, 1.0)},
		],
		"commando_firearm_pistol_feedbacks": [
			{"kind": "headshot", "text": "헤드샷!", "text_pos": Vector2(260.0, 82.0), "timer_frames": 45.0, "max_timer_frames": 60.0},
		],
	}


func _region_signature(image: Image, rect: Rect2i) -> Dictionary:
	var active_count := 0
	var alpha_sum := 0.0
	var red_sum := 0.0
	var green_sum := 0.0
	var blue_sum := 0.0
	for y in range(rect.position.y, min(rect.end.y, image.get_height()), 2):
		for x in range(rect.position.x, min(rect.end.x, image.get_width()), 2):
			var color: Color = image.get_pixel(x, y)
			var delta: float = abs(color.r - BACKGROUND.r) + abs(color.g - BACKGROUND.g) + abs(color.b - BACKGROUND.b)
			if delta <= 0.06:
				continue
			active_count += 1
			alpha_sum += color.a
			red_sum += color.r
			green_sum += color.g
			blue_sum += color.b
	var denom: float = float(max(1, active_count))
	return {
		"active_count": active_count,
		"alpha_sum": alpha_sum,
		"avg": Color(red_sum / denom, green_sum / denom, blue_sum / denom, 1.0),
		"coverage": float(active_count) / max(1.0, (float(rect.size.x) * 0.5) * (float(rect.size.y) * 0.5)),
	}


func _signature_distance(left: Dictionary, right: Dictionary) -> float:
	var left_color: Color = left.get("avg", Color.BLACK)
	var right_color: Color = right.get("avg", Color.BLACK)
	var color_distance: float = (
		abs(left_color.r - right_color.r)
		+ abs(left_color.g - right_color.g)
		+ abs(left_color.b - right_color.b)
	) / 3.0
	var coverage_distance: float = abs(float(left.get("coverage", 0.0)) - float(right.get("coverage", 0.0)))
	return color_distance + coverage_distance * 0.8


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
