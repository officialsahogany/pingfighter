extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")

const LOADING_CAMEO_SILHOUETTE := true
const REFERENCE_VIEW_SIZE := Vector2(1280.0, 720.0)
const CAMEO_RIGHT_MARGIN := 150.0
const CAMEO_BOTTOM_MARGIN := 120.0
# The tallest hoop-roll frame plus its 1.3x glow reaches farther down than the
# cell average. Keep the copy clear for every frame while staying in the
# handoff's compact lower-right band.
const LOADING_COPY_OFFSET_Y := 68.0
const COPY_SIDE_MARGIN := 48.0
const LOADING_COPY_FONT_SIZE := 20.0
const TIP_FONT_SIZE := 16.0
const TIP_LABEL_FONT_SIZE := 20.0
const TIP_LABEL_GAP := 10.0
const TIP_MIN_FONT_SIZE := 11
const TIP_LABEL_COLOR := Color(0.92, 0.72, 0.34, 0.98)
const TIP_COLOR := Color(0.93, 0.90, 0.84, 0.95)
const LOADING_COPY_COLOR := Color(1.0, 1.0, 1.0, 0.92)
# Calligraphy face for the tip line (환격전 rebrand tone). Resolved from the
# OS because no brush-serif ships in the repo: Windows "Gungsuh"(궁서),
# macOS "GungSeo", with Batang serif and the loading font as fallbacks.
const TIP_SYSTEM_FONT_NAMES := ["Gungsuh", "궁서", "GungSeo", "Batang", "바탕"]

const SILHOUETTE_SHADER := """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(1.0, 1.0, 1.0, source.a * COLOR.a);
}
"""

const ENTRIES := [
	{
		"id": "dalji_hoop_roll",
		"sheet_path": "res://assets/ui/loading/loading_cameo_dalji_hoop_roll_16f_autosprite_v1.png",
		"cols": 4,
		"rows": 4,
		"frame_count": 16,
		"fps": 11.0,
		"base_height_ratio": 0.09,
		"content_height_px": 211.0,
	},
]

static var _textures_by_path: Dictionary = {}
static var _silhouette_shader: Shader = null
static var _silhouette_material: ShaderMaterial = null
static var _tip_font: Font = null


static func prewarm_assets() -> void:
	for entry_value in ENTRIES:
		var entry: Dictionary = entry_value
		var path := str(entry.get("sheet_path", ""))
		if path == "" or _textures_by_path.has(path):
			continue
		_textures_by_path[path] = ProjectResourceLoader.load_texture(path)
	if LOADING_CAMEO_SILHOUETTE:
		_get_silhouette_material()


static func get_prewarmed_entry_count() -> int:
	var loaded := 0
	for entry_value in ENTRIES:
		var entry: Dictionary = entry_value
		if get_prewarmed_texture(entry) != null:
			loaded += 1
	return loaded


static func get_prewarmed_texture(entry: Dictionary) -> Texture2D:
	var value: Variant = _textures_by_path.get(str(entry.get("sheet_path", "")), null)
	return value as Texture2D if value is Texture2D else null


static func get_cameo_material() -> Material:
	if not LOADING_CAMEO_SILHOUETTE:
		return null
	return _get_silhouette_material()


static func pick_random_entry(rng: RandomNumberGenerator) -> Dictionary:
	if ENTRIES.is_empty():
		return {}
	var index := rng.randi_range(0, ENTRIES.size() - 1)
	return (ENTRIES[index] as Dictionary).duplicate(true)


static func get_view_scale(view_size: Vector2) -> float:
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return 1.0
	return maxf(0.01, minf(view_size.x / REFERENCE_VIEW_SIZE.x, view_size.y / REFERENCE_VIEW_SIZE.y))


static func get_cameo_center(view_size: Vector2) -> Vector2:
	var view_scale := get_view_scale(view_size)
	return Vector2(view_size.x - CAMEO_RIGHT_MARGIN * view_scale, view_size.y - CAMEO_BOTTOM_MARGIN * view_scale)


static func get_copy_band_y(view_size: Vector2) -> float:
	return get_cameo_center(view_size).y + LOADING_COPY_OFFSET_Y * get_view_scale(view_size)


static func draw_minimal_chrome(
	canvas: CanvasItem,
	font: Font,
	view_size: Vector2,
	tip_tier: String,
	tip_character: String,
	tick_seconds: float,
	show_tip: bool = true,
	tip_start_slot: int = 0
) -> void:
	if canvas == null or font == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK)
	if not show_tip:
		return
	var view_scale := get_view_scale(view_size)
	var copy_y := get_copy_band_y(view_size)
	var tip_text := BattleLoadingTips.rotation_tip_for_elapsed(
		tip_tier,
		tip_character,
		tip_start_slot,
		tick_seconds
	)
	# Every language formats tips as "label: body"; split so the label renders
	# in the gold accent at a slightly larger size than the body copy.
	var label_text := ""
	var body_text := tip_text
	var split_index := tip_text.find(": ")
	if split_index > 0:
		label_text = tip_text.substr(0, split_index + 1)
		body_text = tip_text.substr(split_index + 2)
	var tip_font := _get_tip_font(font)
	var label_size_delta := int(round((TIP_LABEL_FONT_SIZE - TIP_FONT_SIZE) * view_scale))
	var label_gap := TIP_LABEL_GAP * view_scale
	var tip_font_size := maxi(TIP_MIN_FONT_SIZE, int(round(TIP_FONT_SIZE * view_scale)))
	var tip_left := COPY_SIDE_MARGIN * view_scale
	var tip_right := get_cameo_center(view_size).x - 92.0 * view_scale
	var tip_width := maxf(80.0, tip_right - tip_left)
	while tip_font_size > TIP_MIN_FONT_SIZE and _measure_tip_line_width(tip_font, label_text, body_text, tip_font_size, label_size_delta, label_gap) > tip_width:
		tip_font_size -= 1
	var body_size := tip_font.get_string_size(body_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tip_font_size)
	var baseline_y := copy_y + body_size.y * 0.34
	var draw_x := tip_left
	if label_text != "":
		var label_font_size := tip_font_size + label_size_delta
		canvas.draw_string(tip_font, Vector2(draw_x, baseline_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size, TIP_LABEL_COLOR)
		draw_x += tip_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size).x + label_gap
	canvas.draw_string(tip_font, Vector2(draw_x, baseline_y), body_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tip_font_size, TIP_COLOR)


static func _measure_tip_line_width(
	tip_font: Font,
	label_text: String,
	body_text: String,
	body_font_size: int,
	label_size_delta: int,
	label_gap: float
) -> float:
	var width := tip_font.get_string_size(body_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_font_size).x
	if label_text != "":
		width += tip_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_font_size + label_size_delta).x + label_gap
	return width


static func _get_tip_font(fallback: Font) -> Font:
	if _tip_font != null:
		return _tip_font
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(TIP_SYSTEM_FONT_NAMES)
	if fallback != null:
		system_font.fallbacks = [fallback]
	_tip_font = system_font
	return _tip_font


static func _get_silhouette_material() -> ShaderMaterial:
	if _silhouette_material != null:
		return _silhouette_material
	_silhouette_shader = Shader.new()
	_silhouette_shader.code = SILHOUETTE_SHADER
	_silhouette_material = ShaderMaterial.new()
	_silhouette_material.shader = _silhouette_shader
	return _silhouette_material
