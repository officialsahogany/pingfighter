extends RefCounted

var _ui_font: FontVariation = null
var _ui_font_base: Font = null
var _ui_font_spacing: int = -1


func get_font(draw_scale: float) -> Font:
	var base: Font = ThemeDB.fallback_font
	if base == null:
		return base
	var spacing: int = max(1, int(round(2.0 * draw_scale)))
	if _ui_font == null or _ui_font_base != base or _ui_font_spacing != spacing:
		var variation := FontVariation.new()
		variation.base_font = base
		variation.set_spacing(TextServer.SPACING_GLYPH, spacing)
		_ui_font = variation
		_ui_font_base = base
		_ui_font_spacing = spacing
	return _ui_font
