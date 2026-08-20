extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentMapHintRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_hint_renderer.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_hint_visibility_and_copy()
	_verify_left_pillar_geometry()
	_verify_production_drawer_uses_screen_space_owner()
	_verify_visual_qa_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("tower_ascent_map_hint_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_hint_visibility_and_copy() -> void:
	var renderer := TowerAscentMapHintRenderer.new()
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect(not renderer.is_visible(false), "flag OFF must suppress the map hint")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_expect(renderer.is_visible(false), "flag ON combat must show the map hint")
	_expect(not renderer.is_visible(true), "an active tower surface must hide the underlying map hint")
	_expect(renderer.get_hint_text() == "M 지도", "the Korean HUD hint must be exactly M 지도")
	_expect(renderer.get_key_label() == "M", "the pillar hint must keep the M shortcut label")
	_expect(
		TowerAscentMapOverlayLocalization.get_registered_keys().has(
			TowerAscentMapOverlayLocalization.KEY_HUD_HINT
		),
		"the HUD hint must have a registered localization key"
	)


func _verify_left_pillar_geometry() -> void:
	var renderer := TowerAscentMapHintRenderer.new()
	var view_size := Vector2(2020.0, 1246.0)
	var game_size := Vector2(1098.0, 1084.0)
	var game_offset := Vector2(461.0, 81.0)
	var hint_rect := renderer.get_hint_rect(view_size, game_offset, game_size)
	var playfield_rect := Rect2(game_offset, game_size)
	_expect(hint_rect.size.x > 0.0, "a wide 2020 by 1246 view must expose the left-pillar hint")
	_expect(hint_rect.end.x <= playfield_rect.position.x, "the M hint must stay wholly left of the full 760 by 750 playfield")
	_expect(not hint_rect.intersects(playfield_rect), "the M hint must not cover the combat canvas")
	_expect(
		renderer.get_hint_rect(Vector2(760.0, 750.0), Vector2.ZERO, Vector2(760.0, 750.0)).size == Vector2.ZERO,
		"a view without a side letterbox must hide the hint instead of applying a legacy 80px inset"
	)
	_expect(
		renderer.get_hint_rect(Vector2(800.0, 750.0), Vector2(20.0, 0.0), Vector2(760.0, 750.0)).size == Vector2.ZERO,
		"an undersized left letterbox must hide the hint instead of overlapping the playfield"
	)


func _verify_production_drawer_uses_screen_space_owner() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_drawer.gd")
	var start := source.find("func _draw_tower_ascent_map_hint(")
	var finish := source.find("\nfunc ", start + 1)
	var body := source.substr(start) if finish < 0 else source.substr(start, finish - start)
	var draw_start := source.find("func draw(")
	var draw_finish := source.find("\nfunc ", draw_start + 1)
	var draw_body := source.substr(draw_start) if draw_finish < 0 else source.substr(draw_start, draw_finish - draw_start)
	var playfield_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	_expect(start >= 0, "the production screen-space scene drawer must own the tower HUD hint")
	_expect(body.find("_get_cached_instance(registry, \"tower_ascent_flow_owner\")") >= 0, "the hot draw path must use cached flow lookup")
	_expect(body.find("_get_instance(registry, \"tower_ascent_flow_owner\")") < 0, "the map hint must not cold-instantiate the flow owner in draw")
	_expect(body.find("_tower_ascent_map_hint_renderer.draw(") >= 0, "the screen-space owner must draw the pillar hint")
	_expect(draw_body.find("_draw_pillar_scene(canvas, registry, view_size, layout)") < draw_body.find("_draw_tower_ascent_map_hint(canvas, registry, view_size, layout)"), "the hint must draw after the pillar background")
	_expect(draw_body.find("_draw_tower_ascent_map_hint(canvas, registry, view_size, layout)") < draw_body.find("_draw_transformed_playfield_scene(canvas, registry, surface)"), "the hint must draw before the transformed playfield")
	_expect(playfield_source.find("TowerAscentMapHintRenderer") < 0, "the transformed playfield drawer must no longer own the hint")
	_expect(playfield_source.find("_tower_ascent_map_hint_renderer") < 0, "the transformed playfield path must not draw the hint")


func _verify_visual_qa_contract() -> void:
	var source := FileAccess.get_file_as_string(
		"res://tools/tower_map_hint_pillar_visual_qa.gd"
	)
	var wrapper := FileAccess.get_file_as_string(
		"res://tools/run_tower_map_hint_pillar_visual_qa.ps1"
	)
	_expect(source.find("BattleSceneDrawer.new()") >= 0, "visual QA must use the production screen-space drawer")
	_expect(source.find("const VIEW_SIZE := Vector2i(2020, 1246)") >= 0, "visual QA must use the acceptance resolution")
	_expect(source.find("RenderingServer.get_rendering_device()") >= 0, "visual QA must fail closed without Vulkan")
	_expect(wrapper.find("-AllowDuringPlay") >= 0, "visual QA wrapper must declare the play-mode policy")
	_expect(wrapper.find("--rendering-driver vulkan") >= 0, "visual QA wrapper must request Vulkan")
	_expect(wrapper.find("Restore-GodotValidationPriority") >= 0, "visual QA wrapper must restore caller priority")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
