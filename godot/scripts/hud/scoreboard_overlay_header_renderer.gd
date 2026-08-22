extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const SCOREBOARD_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const BRUSH_FONT: Font = preload("res://assets/fonts/NanumBrushScript-Regular.ttf")

const BOSS_NAMES_BY_STAGE := {
	4: "퐁크",
	5: "홍련",
	6: "테트리서",
	7: "아카무 리고",
	8: "미노타우로스",
}
const STAGE1_BOSS_NAMES_BY_VARIANT := {
	"dalji": "달지",
	"gaksi": "각시탈",
	"podo": "포도대장",
}

const INK_COLOR := Color(0.105, 0.065, 0.035, 1.0)
const SCORE_INK_COLOR := Color(0.49, 0.075, 0.045, 1.0)
const MUTED_GOLD := Color(0.49, 0.32, 0.12, 1.0)
const PAPER_LIGHT := Color(0.97, 0.91, 0.77, 1.0)
const TITLE_PAPER_COLOR := Color(0.929, 0.843, 0.702, 1.0)
const ROUND_TITLE_Y_RATIO := 0.145
const NAME_Y_RATIO := 0.222
const NAME_FONT_RATIO := 0.051
const NAME_FONT_MIN := 16.0
const NAME_FONT_MAX := 20.0


func draw(
	canvas: CanvasItem,
	board_rect: Rect2,
	alpha: float,
	emphasis_side: String,
	round_index: int,
	draw_context: Dictionary,
	player_alpha_scale: float = 1.0,
	boss_alpha_scale: float = 1.0
) -> void:
	if canvas == null or alpha <= 0.001:
		return
	_draw_round_title(canvas, board_rect, round_index, alpha)
	var name_y: float = board_rect.position.y + board_rect.size.y * NAME_Y_RATIO
	var name_size: int = int(clampf(roundf(board_rect.size.y * NAME_FONT_RATIO), NAME_FONT_MIN, NAME_FONT_MAX))
	var nameplate_size := Vector2(board_rect.size.x * 0.255, board_rect.size.y * 0.072)
	var player_color: Color = SCORE_INK_COLOR if emphasis_side == "player" else INK_COLOR
	var boss_color: Color = SCORE_INK_COLOR if emphasis_side == "boss" else INK_COLOR
	var player_center := Vector2(board_rect.position.x + board_rect.size.x * 0.315, name_y)
	var boss_center := Vector2(board_rect.position.x + board_rect.size.x * 0.685, name_y)
	_draw_nameplate_accents(
		canvas,
		player_center,
		nameplate_size,
		emphasis_side == "player",
		alpha * clampf(player_alpha_scale, 0.0, 1.0)
	)
	_draw_nameplate_accents(
		canvas,
		boss_center,
		nameplate_size,
		emphasis_side == "boss",
		alpha * clampf(boss_alpha_scale, 0.0, 1.0)
	)
	_draw_text_centered(
		canvas,
		player_center,
		resolve_player_name(draw_context),
		name_size,
		player_color,
		alpha * clampf(player_alpha_scale, 0.0, 1.0),
		nameplate_size
	)
	_draw_text_centered(
		canvas,
		boss_center,
		resolve_boss_name(draw_context),
		name_size,
		boss_color,
		alpha * clampf(boss_alpha_scale, 0.0, 1.0),
		nameplate_size
	)


func _draw_round_title(canvas: CanvasItem, board_rect: Rect2, round_index: int, alpha: float) -> void:
	var title: String = format_round_title(round_index)
	var center: Vector2 = resolve_round_title_center(board_rect)
	var font: Font = SCOREBOARD_FONT if SCOREBOARD_FONT != null else BRUSH_FONT
	if font == null:
		return
	var font_size: int = int(clampf(roundf(board_rect.size.y * 0.043), 15.0, 18.0))
	var text_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(
		center.x - text_size.x * 0.5,
		center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	_draw_title_clearance(canvas, center, text_size.x, font_size, alpha)
	canvas.draw_string_outline(
		font,
		baseline,
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		1,
		Color(PAPER_LIGHT.r, PAPER_LIGHT.g, PAPER_LIGHT.b, 0.58 * alpha)
	)
	canvas.draw_string(
		font,
		baseline,
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.88 * alpha)
	)
	_draw_title_flanking_lines(canvas, board_rect, center, text_size.x, alpha)


func resolve_round_title_center(board_rect: Rect2) -> Vector2:
	return Vector2(
		board_rect.get_center().x,
		board_rect.position.y + board_rect.size.y * ROUND_TITLE_Y_RATIO
	)


func _draw_title_clearance(
	canvas: CanvasItem,
	center: Vector2,
	text_width: float,
	font_size: int,
	alpha: float
) -> void:
	var clearance_size := Vector2(text_width + 28.0, float(font_size) + 5.0)
	var clearance_rect := Rect2(center - clearance_size * 0.5, clearance_size)
	canvas.draw_rect(
		clearance_rect,
		Color(TITLE_PAPER_COLOR.r, TITLE_PAPER_COLOR.g, TITLE_PAPER_COLOR.b, 0.34 * alpha)
	)
	canvas.draw_rect(
		Rect2(
			Vector2(clearance_rect.position.x, center.y + 0.5),
			Vector2(clearance_rect.size.x, 4.0)
		),
		Color(TITLE_PAPER_COLOR.r, TITLE_PAPER_COLOR.g, TITLE_PAPER_COLOR.b, alpha)
	)


func _draw_title_flanking_lines(
	canvas: CanvasItem,
	board_rect: Rect2,
	center: Vector2,
	text_width: float,
	alpha: float
) -> void:
	var line_half: float = minf(board_rect.size.x * 0.105, 82.0)
	var text_half_with_air: float = text_width * 0.5 + 15.0
	if text_half_with_air >= line_half - 3.0:
		return
	var line_y: float = floorf(center.y) + 0.5
	var line_color := Color(MUTED_GOLD.r, MUTED_GOLD.g, MUTED_GOLD.b, 0.34 * alpha)
	canvas.draw_line(
		Vector2(center.x - line_half, line_y),
		Vector2(center.x - text_half_with_air, line_y),
		line_color,
		1.0
	)
	canvas.draw_line(
		Vector2(center.x + text_half_with_air, line_y),
		Vector2(center.x + line_half, line_y),
		line_color,
		1.0
	)


func format_round_title(round_index: int) -> String:
	return "제 %d합 종료" % round_index if round_index > 0 else "라운드 종료"


func _draw_nameplate_accents(
	canvas: CanvasItem,
	center: Vector2,
	max_size: Vector2,
	is_leading: bool,
	alpha: float
) -> void:
	var accent_color: Color = SCORE_INK_COLOR if is_leading else MUTED_GOLD
	var underline_y: float = center.y + max_size.y * 0.36
	var half_width: float = max_size.x * (0.27 if is_leading else 0.22)
	canvas.draw_line(
		Vector2(center.x - half_width, underline_y),
		Vector2(center.x + half_width, underline_y),
		Color(accent_color.r, accent_color.g, accent_color.b, (0.58 if is_leading else 0.28) * alpha),
		2.0 if is_leading else 1.0
	)
	for direction in [-1.0, 1.0]:
		var point := Vector2(center.x + direction * (half_width + 4.0), underline_y)
		var diamond := PackedVector2Array([
			point + Vector2(0.0, -2.5),
			point + Vector2(2.5, 0.0),
			point + Vector2(0.0, 2.5),
			point + Vector2(-2.5, 0.0),
		])
		canvas.draw_colored_polygon(
			diamond,
			Color(accent_color.r, accent_color.g, accent_color.b, (0.48 if is_leading else 0.23) * alpha)
		)


func resolve_player_name(draw_context: Dictionary) -> String:
	var character_type: String = str(draw_context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	if character_type == "commando":
		character_type = "soldier"
	var class_label: String = str(draw_context.get("selected_character_name", "")).strip_edges()
	var personal_name: String = CharacterInfoOverlayOwnerState.character_display_name(class_label, character_type)
	return LanguageSettings.translate_text(personal_name)


func resolve_boss_name(draw_context: Dictionary) -> String:
	var explicit_name: String = str(draw_context.get("boss_display_name", "")).strip_edges()
	if explicit_name != "":
		return LanguageSettings.translate_text(explicit_name)
	var current_stage: int = int(draw_context.get("current_stage", 1))
	var boss_name: String
	if current_stage == 1:
		# The catalog is the display-name authority for every stage. The local
		# table stays only as a fallback for an id the catalog does not carry.
		var variant: String = _normalize_stage1_variant(draw_context.get("stage1_boss_variant", "dalji"))
		boss_name = str(StageBossVariantCatalog.get_entry(1, variant).get("display_name", ""))
		if boss_name == "":
			boss_name = str(STAGE1_BOSS_NAMES_BY_VARIANT.get(variant, "달지"))
	else:
		var entry: Dictionary = StageBossVariantCatalog.get_entry(
			current_stage,
			draw_context.get("stage_boss_variant", "")
		)
		boss_name = str(entry.get("display_name", ""))
		if boss_name == "":
			boss_name = str(BOSS_NAMES_BY_STAGE.get(current_stage, "보스"))
	return LanguageSettings.translate_text(boss_name)


func _normalize_stage1_variant(value: Variant) -> String:
	var variant: String = str(value).strip_edges().to_lower()
	if variant in ["gaksi", "gaksital", "talkwangdae", "talchum"]:
		return "gaksi"
	if variant in ["podo", "pododaejang", "podo_daejang"]:
		return "podo"
	return "dalji"


func _draw_text_centered(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
	alpha: float,
	max_size: Vector2
) -> void:
	var font: Font = SCOREBOARD_FONT if SCOREBOARD_FONT != null else ThemeDB.fallback_font
	if font == null:
		return
	var fitted_size: int = _fit_font_size(font, text, font_size, max_size)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size)
	var ascent: float = font.get_ascent(fitted_size)
	var descent: float = font.get_descent(fitted_size)
	var baseline := Vector2(center.x - text_size.x * 0.5, center.y + (ascent - descent) * 0.5)
	canvas.draw_string(
		font,
		baseline + Vector2(1.5, 1.5),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		fitted_size,
		Color(0.35, 0.20, 0.09, 0.20 * alpha)
	)
	canvas.draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		fitted_size,
		Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))
	)


func _fit_font_size(font: Font, text: String, requested_size: int, max_size: Vector2) -> int:
	var fitted_size: int = maxi(requested_size, 12)
	while fitted_size > 12:
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size)
		if text_size.x <= max_size.x and text_size.y <= max_size.y:
			break
		fitted_size -= 1
	return fitted_size
