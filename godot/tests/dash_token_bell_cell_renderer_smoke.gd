extends SceneTree

const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PillarDashTokenFillRenderer := preload("res://scripts/hud/pillar_dash_token_fill_renderer.gd")
const Stage1PillarStatusOrbContextBuilder := preload("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	var bell_path := BattleCoreTexturePaths.DASH_TOKEN_BELL_CELL_TEXTURE_PATH
	var frame_path := BattleCoreTexturePaths.DASH_TOKEN_FRAME_TEXTURE_PATH
	_expect(frame_path.ends_with("dash_token_frame_imagegen_v3.png"), "dash dial must use the accepted count-neutral v3 frame")
	_expect(FileAccess.file_exists(bell_path), "bell-cell PNG must exist before runtime wiring")
	_expect(FileAccess.file_exists(bell_path + ".import"), "bell-cell PNG must ship with its Godot import sidecar")
	_expect(FileAccess.file_exists(frame_path), "v3 dash frame PNG must exist before runtime wiring")
	_expect(FileAccess.file_exists(frame_path + ".import"), "v3 dash frame PNG must ship with its Godot import sidecar")

	var bell_image := Image.load_from_file(ProjectSettings.globalize_path(bell_path))
	var frame_image := Image.load_from_file(ProjectSettings.globalize_path(frame_path))
	_expect(bell_image != null and bell_image.get_size() == Vector2i(128, 128), "bell-cell runtime PNG must stay 128x128")
	_expect(frame_image != null and frame_image.get_size() == Vector2i(240, 240), "dash frame v3 must preserve the 240x240 drop-in contract")
	if bell_image != null:
		_expect(bell_image.get_pixel(0, 0).a <= 0.01, "bell-cell PNG corners must be transparent")
	if frame_image != null:
		_expect(frame_image.get_pixel(0, 0).a <= 0.01, "dash frame v3 corners must be transparent")
		_expect(frame_image.get_pixel(120, 120).a <= 0.01, "dash frame v3 center hole must be transparent")

	var texture_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	texture_image.fill(Color.WHITE)
	var bell_texture := ImageTexture.create_from_image(texture_image)
	var renderer := PillarDashTokenFillRenderer.new()
	var center := Vector2(100.0, 90.0)
	var multi_specs: Array = renderer.build_bell_cell_draw_specs(
		center,
		50.0,
		5,
		2,
		0.5,
		-PI * 0.5,
		TAU / 5.0,
		{"bell_cell_texture": bell_texture}
	)
	_expect(multi_specs.size() == 5, "five-token dial must emit one bell-cell draw spec per sector")
	if multi_specs.size() == 5:
		var acquired: Color = multi_specs[0].get("modulate", Color.TRANSPARENT)
		var charging: Color = multi_specs[2].get("modulate", Color.TRANSPARENT)
		var empty: Color = multi_specs[4].get("modulate", Color.TRANSPARENT)
		_expect(_brightness(acquired) > _brightness(charging), "acquired bell must be brighter than charging bell")
		_expect(_brightness(charging) > _brightness(empty), "charging bell must brighten above the empty silhouette")
		for spec_value in multi_specs:
			var spec: Dictionary = spec_value
			var cell_rect: Rect2 = spec.get("rect", Rect2())
			_expect(is_equal_approx(cell_rect.size.x, 24.0), "r=55 five-token bell cell must use the 24px readability target")

	var single_specs: Array = renderer.build_bell_cell_draw_specs(
		center,
		50.0,
		1,
		0,
		0.0,
		-PI * 0.5,
		TAU,
		{"bell_cell_texture": bell_texture}
	)
	_expect(single_specs.size() == 1, "single-token dial must emit one large bell-cell draw spec")
	if single_specs.size() == 1:
		var single_rect: Rect2 = single_specs[0].get("rect", Rect2())
		_expect(single_rect.end.y < center.y, "single-token bell texture rect must stay above the centered N/M count text")

	var fallback_specs: Array = renderer.build_bell_cell_draw_specs(
		center,
		50.0,
		3,
		1,
		0.25,
		-PI * 0.5,
		TAU / 3.0,
		{}
	)
	_expect(fallback_specs.is_empty(), "missing bell texture must preserve the liquid-only fallback without draw calls")

	var context_builder := Stage1PillarStatusOrbContextBuilder.new()
	var threaded_context := {"dash_token_bell_cell_texture": bell_texture}
	var player_context: Dictionary = context_builder.build_dash_orb_context(threaded_context, null)
	var boss_context: Dictionary = context_builder.build_boss_dash_orb_context(threaded_context, null)
	_expect(player_context.get("bell_cell_texture", null) == bell_texture, "player dash context must receive the prewarmed bell texture")
	_expect(boss_context.get("bell_cell_texture", null) == bell_texture, "boss dash context must intentionally share the bell-cell texture")
	_expect(boss_context.get("frame_texture", bell_texture) == null, "boss dash frame must remain null in this slice")

	var resources := BattleResources.new()
	var bell_spec_count := 0
	for spec_value in resources._get_core_texture_specs():
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		if str(spec.get("path", "")) == bell_path and "dash_token_bell_cell_texture" in spec.get("keys", []):
			bell_spec_count += 1
	_expect(bell_spec_count == 1, "bell-cell texture must join core staged prewarm exactly once")

	if _failures.is_empty():
		print("dash_token_bell_cell_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _brightness(color: Color) -> float:
	return color.r + color.g + color.b


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
