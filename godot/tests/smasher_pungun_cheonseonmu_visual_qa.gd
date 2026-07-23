extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")
const SmasherWheelCloudFxHost := preload("res://scripts/characters/smasher_wheel_cloud_fx_host.gd")

const VIEW_SIZE := Vector2i(1000, 640)
const CAPTURE_PATH := "res://.tmp/smasher_pungun_cheonseonmu_runtime_qa.png"
const BODY_SHEET_PATH := "res://assets/sprites/smasher/hanmiryang_pungun_cheonseonmu_spin_16f_4x4_160.png"
const ICON_PATH := "res://assets/sprites/skills/smasher_wheel_skill_orb.png"


class Backdrop:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.015, 0.027, 0.065), true)
		draw_rect(Rect2(300.0, 64.0, 650.0, 520.0), Color(0.04, 0.085, 0.15), true)
		for line_index: int in range(8):
			var y: float = 100.0 + float(line_index) * 62.0
			draw_line(Vector2(326.0, y), Vector2(924.0, y), Color(0.30, 0.62, 0.82, 0.10), 1.0)
		draw_circle(Vector2(628.0, 330.0), 156.0, Color(0.16, 0.48, 0.72, 0.08))
		draw_arc(Vector2(628.0, 330.0), 178.0, 0.0, TAU, 80, Color(0.58, 0.82, 1.0, 0.18), 2.0, true)
		var font: Font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(36.0, 55.0), "풍운천선무", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color(0.91, 0.97, 1.0))
			draw_string(font, Vector2(36.0, 86.0), "초식 아이콘 · 전투 VFX", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.58, 0.78, 0.96))
			draw_string(font, Vector2(337.0, 620.0), "구름 회전 · 외곽 산개 · 접촉 순간 운무 폭발", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.78, 0.90, 1.0))


func _init() -> void:
	get_root().size = VIEW_SIZE
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var backdrop := Backdrop.new()
	get_root().add_child(backdrop)

	var source_icon: Texture2D = ProjectResourceLoader.load_texture(ICON_PATH)
	var normalized_icon: Texture2D = SkillOrbTextureNormalizer.normalize("smasher_wheel", source_icon)
	for icon_spec: Dictionary in [
		{"position": Vector2(105.0, 185.0), "size": 48.0},
		{"position": Vector2(200.0, 185.0), "size": 72.0},
		{"position": Vector2(150.0, 320.0), "size": 124.0},
	]:
		var icon := Sprite2D.new()
		icon.texture = normalized_icon
		icon.position = Vector2(icon_spec.get("position", Vector2.ZERO))
		var icon_size: float = float(icon_spec.get("size", 64.0))
		icon.scale = Vector2.ONE * icon_size / 256.0
		icon.z_index = 3
		get_root().add_child(icon)

	var body_texture: Texture2D = ProjectResourceLoader.load_texture(BODY_SHEET_PATH)
	var body := Sprite2D.new()
	body.texture = body_texture
	body.region_enabled = true
	body.region_rect = Rect2(0.0, 0.0, 160.0, 160.0)
	body.position = Vector2(628.0, 350.0)
	body.scale = Vector2.ONE * 1.08
	body.z_index = 2
	get_root().add_child(body)

	var host: Node2D = SmasherWheelCloudFxHost.new()
	get_root().add_child(host)
	await process_frame
	for frame_index: int in range(12):
		host.sync_state({
			"active": true,
			"direction": 1,
			"screen_center": Vector2(628.0, 350.0),
			"burst_screen_pos": Vector2(742.0, 272.0),
			"burst_serial": 0,
			"current_msec": 1940 + frame_index * 17,
			"start_msec": 1500,
			"render_scale": 1.0,
		}, true)
		await process_frame
	host.sync_state({
		"active": true,
		"direction": 1,
		"screen_center": Vector2(628.0, 350.0),
		"burst_screen_pos": Vector2(742.0, 272.0),
		"burst_serial": 1,
		"current_msec": 2160,
		"start_msec": 1500,
		"render_scale": 1.0,
	}, true)
	for _frame_index: int in range(7):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_root().get_texture().get_image()
	if image.get_size() != VIEW_SIZE:
		image = image.get_region(Rect2i(Vector2i.ZERO, VIEW_SIZE))
	var error: Error = image.save_png(CAPTURE_PATH)
	if error != OK:
		push_error("Failed to save 풍운천선무 runtime visual QA capture")
		quit(1)
		return
	print("smasher_pungun_cheonseonmu_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
