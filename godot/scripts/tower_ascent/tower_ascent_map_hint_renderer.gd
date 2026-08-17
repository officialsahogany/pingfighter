extends RefCounted

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const PANEL_FILL := Color(0.045, 0.028, 0.02, 0.84)
const PANEL_BORDER := Color("bd8c35")
const TEXT_COLOR := Color("f1dfb8")


func draw(canvas: CanvasItem, tower_surface_active: bool) -> void:
	if canvas == null or not is_visible(tower_surface_active):
		return
	var rect := TowerAscentTuning.TEMP_MAP_HINT_RECT
	canvas.draw_rect(rect, PANEL_FILL, true)
	canvas.draw_rect(rect, PANEL_BORDER, false, 1.5)
	canvas.draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(0.0, 20.0),
		get_hint_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		TowerAscentTuning.TEMP_MAP_HINT_FONT_SIZE,
		TEXT_COLOR
	)


func is_visible(tower_surface_active: bool) -> bool:
	return (
		TowerAscentFeatureFlags.is_vertical_slice_enabled()
		and not tower_surface_active
	)


func get_hint_text() -> String:
	return TowerAscentMapOverlayLocalization.text(
		TowerAscentMapOverlayLocalization.KEY_HUD_HINT
	)
