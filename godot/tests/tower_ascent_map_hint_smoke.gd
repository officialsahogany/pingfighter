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
	_verify_production_drawer_uses_cached_flow_only()
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
	_expect(
		TowerAscentMapOverlayLocalization.get_registered_keys().has(
			TowerAscentMapOverlayLocalization.KEY_HUD_HINT
		),
		"the HUD hint must have a registered localization key"
	)


func _verify_production_drawer_uses_cached_flow_only() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_playfield_scene_drawer.gd"
	)
	var start := source.find("func _draw_tower_ascent_flow(")
	var finish := source.find("\nfunc ", start + 1)
	var body := source.substr(start) if finish < 0 else source.substr(start, finish - start)
	_expect(start >= 0, "the production playfield drawer must own the tower HUD hint")
	_expect(body.find("_get_cached_instance(registry, \"tower_ascent_flow_owner\")") >= 0, "the hot draw path must use cached flow lookup")
	_expect(body.find("_get_instance(registry, \"tower_ascent_flow_owner\")") < 0, "the map hint must not cold-instantiate the flow owner in draw")
	_expect(body.find("_tower_ascent_map_hint_renderer.draw(canvas, flow_active)") >= 0, "the production playfield path must draw the localized hint")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
