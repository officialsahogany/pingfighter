extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const GENERAL_IDS := [
	"star_detector",
	"adversity_armor",
	"reinforced_boomerang_gauntlet",
	"sensor",
	"gravitybelt",
	"dowsing_pendulum",
	"chargebag",
	"battery",
	"revival",
	"master",
	"gold_digger",
	"lucky_coin",
	"shrapnel_armor",
	"fuel_pouch",
	"bluetooth_ring",
	"foul_whistle",
	"smartphone",
	"neural_helmet",
	"commando_arm",
	"rainbow_fur_glove",
	"knee_pads",
	"soul_burst",
	"bulletproof_hat",
	"spiked_helmet",
	"venom_mist_gauntlet",
	"speedgear",
]

const EXPECTED_STATIC_SIZE := Vector2i(128, 128)
const CAPTURE_PATH := "res://../.tmp/perk_icon_redraw/godot_general_icon_render_probe.png"


class GeneralIconRenderProbe:
	extends Node2D

	var renderer := RuntimePerkIconRenderer.new()
	var ids: Array = []
	var draw_results: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_results.clear()
		draw_rect(Rect2(Vector2.ZERO, Vector2(720.0, 382.0)), Color(6.0 / 255.0, 20.0 / 255.0, 35.0 / 255.0))
		for i in range(ids.size()):
			var perk_id := str(ids[i])
			var col := i % 7
			var row := int(floor(float(i) / 7.0))
			var cell_rect := Rect2(Vector2(18.0 + float(col) * 98.0, 18.0 + float(row) * 86.0), Vector2(78.0, 78.0))
			draw_rect(cell_rect, Color(9.0 / 255.0, 27.0 / 255.0, 48.0 / 255.0))
			draw_rect(cell_rect, Color(52.0 / 255.0, 121.0 / 255.0, 152.0 / 255.0), false, 1.0)
			draw_results[perk_id] = bool(renderer.draw_icon(self, perk_id, Rect2(cell_rect.position + Vector2(11.0, 5.0), Vector2(56.0, 56.0)), 1.0, true))
			var font := ThemeDB.fallback_font
			if font != null:
				draw_string(font, cell_rect.position + Vector2(23.0, 69.0), "Lv.1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.88, 0.25))


var _failures: Array[String] = []
var _probe: GeneralIconRenderProbe = null
var _frame_count := 0


func _init() -> void:
	_verify_static_wiring()
	get_root().size = Vector2i(720, 382)
	_probe = GeneralIconRenderProbe.new()
	_probe.ids = GENERAL_IDS.duplicate()
	_probe.name = "GeneralIconRenderProbe"
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_verify_draw_probe()
	_capture_probe_if_available()

	if _failures.is_empty():
		print("runtime_perk_general_icon_static_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _verify_static_wiring() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	var covered_ids := renderer.covered_ids()
	for id_value in GENERAL_IDS:
		var perk_id := str(id_value)
		var expected_path := "res://assets/sprites/perks/%s_perk_icon.png" % perk_id
		var actual_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, ""))
		_expect(actual_path == expected_path, "%s should register its static PNG path" % perk_id)
		_expect(not RuntimePerkIconRenderer.PERK_SHEET_PATHS.has(perk_id), "%s should stay static-only and not register an animated sheet" % perk_id)
		_expect(covered_ids.has(perk_id), "%s should be covered by runtime perk icon ids" % perk_id)
		_expect(ResourceLoader.exists(expected_path, "Texture2D"), "%s static icon should import as Texture2D" % perk_id)

		var static_texture: Texture2D = renderer._get_texture(expected_path)
		_expect(static_texture != null, "%s static icon should load through ProjectResourceLoader" % perk_id)
		if static_texture != null:
			_expect(static_texture.get_width() == EXPECTED_STATIC_SIZE.x and static_texture.get_height() == EXPECTED_STATIC_SIZE.y, "%s static icon should stay 128x128" % perk_id)

		var source: Dictionary = renderer._get_icon_source(perk_id)
		_expect(source.get("texture", null) == static_texture, "%s should use the static PNG as its draw source" % perk_id)
		_expect(source.get("region", Rect2()).size == Vector2.ZERO, "%s static source should not carry a sheet region" % perk_id)
		_verify_source_png_alpha(expected_path, EXPECTED_STATIC_SIZE, "%s static icon" % perk_id)

	renderer.prewarm_assets()
	for id_value in GENERAL_IDS:
		var perk_id := str(id_value)
		var expected_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS[perk_id])
		_expect(renderer.has_icon(perk_id), "%s should remain drawable after prewarm" % perk_id)
		_expect(renderer._texture_cache.has(expected_path), "%s static icon should be cached by prewarm" % perk_id)


func _verify_source_png_alpha(path: String, expected_size: Vector2i, label: String) -> void:
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(path))
	if load_error != OK:
		load_error = image.load(path)
	_expect(load_error == OK, "%s source PNG should load for alpha QA" % label)
	if load_error != OK:
		return
	_expect(image.get_width() == expected_size.x and image.get_height() == expected_size.y, "%s source PNG should keep expected dimensions" % label)
	var opaque_count := 0
	var semi_alpha_count := 0
	var edge_alpha_count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha >= 0.999:
				opaque_count += 1
			elif alpha > 0.001:
				semi_alpha_count += 1
			if (x == 0 or y == 0 or x == image.get_width() - 1 or y == image.get_height() - 1) and alpha > 0.001:
				edge_alpha_count += 1
	_expect(opaque_count > 0, "%s source PNG should contain visible pixels" % label)
	_expect(semi_alpha_count == 0, "%s source PNG should be hard-alpha with no semi-transparent residue" % label)
	_expect(edge_alpha_count == 0, "%s source PNG should leave transparent outer edges" % label)


func _verify_draw_probe() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "general icon render probe should receive a live draw callback")
	if _probe == null:
		return
	for id_value in GENERAL_IDS:
		var perk_id := str(id_value)
		_expect(bool(_probe.draw_results.get(perk_id, false)), "%s should draw through RuntimePerkIconRenderer.draw_icon" % perk_id)


func _capture_probe_if_available() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		return
	image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
