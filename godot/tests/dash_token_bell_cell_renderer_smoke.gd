extends SceneTree

const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PillarDashOrbRenderer := preload("res://scripts/hud/pillar_dash_orb_renderer.gd")
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
	var orb_renderer := PillarDashOrbRenderer.new()
	var center := Vector2(100.0, 90.0)
	var content_radius: float = orb_renderer.get_orb_content_radius(55.0, bell_texture)
	var inner_radius: float = content_radius * PillarDashOrbRenderer.TOKEN_INNER_RADIUS_RATIO
	var frame_hole_radius := 154.0 * (196.0 / 240.0) * 0.5
	_expect(content_radius >= frame_hole_radius, "textured dash-orb content must underlap the measured v3 frame hole without a background gap")
	_expect(is_equal_approx(orb_renderer.get_orb_content_radius(55.0, null), 55.0), "frame-null boss dial must keep its existing content radius")
	var decorative_spec: Dictionary = renderer.build_decorative_bell_draw_spec(
		center,
		inner_radius,
		{"bell_cell_texture": bell_texture}
	)
	_expect(not decorative_spec.is_empty(), "dash dial must emit one decorative bell independent of token count")
	if not decorative_spec.is_empty():
		var bell_rect: Rect2 = decorative_spec.get("rect", Rect2())
		_expect(is_equal_approx(bell_rect.size.x, 28.0), "r=55 decorative HUD bell must keep the accepted 28px size")
		var visual_center_y := bell_rect.get_center().y - PillarDashTokenFillRenderer.BELL_VISUAL_CENTER_Y_RATIO * bell_rect.size.y
		_expect(abs(visual_center_y - (center.y - content_radius)) <= 0.25, "decorative bell alpha centroid must sit on the orb's top boundary")

	var orb_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_dash_orb_renderer.gd")
	var frame_draw_index := orb_source.find("pillar_drawer.draw_rotating_orb_frame_texture")
	var glass_draw_index := orb_source.find("pillar_drawer.draw_pillar_orb_glass(canvas")
	var bell_overlay_index := orb_source.find("token_renderer.draw_decorative_bell_overlay")
	_expect(frame_draw_index >= 0 and glass_draw_index > frame_draw_index, "glass must remain above the rotating frame/body pass")
	_expect(bell_overlay_index > glass_draw_index, "the single decorative bell must draw above the frame and glass instead of inside the orb pass")

	var fallback_spec: Dictionary = renderer.build_decorative_bell_draw_spec(
		center,
		50.0,
		{}
	)
	_expect(fallback_spec.is_empty(), "missing bell texture must preserve the liquid-only fallback without draw calls")

	var context_builder := Stage1PillarStatusOrbContextBuilder.new()
	var threaded_context := {"dash_token_bell_cell_texture": bell_texture}
	var player_context: Dictionary = context_builder.build_dash_orb_context(threaded_context, null)
	var boss_context: Dictionary = context_builder.build_boss_dash_orb_context(threaded_context, null)
	_expect(player_context.get("bell_cell_texture", null) == bell_texture, "player dash context must receive the prewarmed decorative bell texture")
	_expect(boss_context.get("bell_cell_texture", null) == bell_texture, "boss dash context must intentionally share the decorative bell texture")
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
