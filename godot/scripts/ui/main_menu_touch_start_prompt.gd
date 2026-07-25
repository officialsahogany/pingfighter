extends Control

# Runtime-owned input-neutral start ribbon. The main-menu scene decides when the
# prompt is present; this control owns its pulse clock, label, and hairline drawing.

const PROMPT_TEXT := "문을 두드려 귀문을 연다"
const PROMPT_FONT_SIZE := 40
const PULSE_PERIOD_SEC := 2.0
const RIBBON_HEIGHT := 40.0
const RIBBON_BACKGROUND_ALPHA := 0.0
const HAIRLINE_WIDTH := 1.0
const HAIRLINE_COLOR := Color(176.0 / 255.0, 141.0 / 255.0, 87.0 / 255.0, 1.0)
const SIDE_DASH_OUTER_MARGIN := 84.0
const SIDE_DASH_INNER_GAP := 220.0
const LOWER_ORNAMENT_Y_OFFSET := 29.0
const LOWER_DASH_HALF_LENGTH := 42.0
const LOWER_DASH_CENTER_GAP := 11.0
const CENTER_DIAMOND_RADIUS := 4.0

var host_button: Button = null
var prompt_label: Label = null
var elapsed_sec: float = 0.0
var prompt_text := PROMPT_TEXT


func configure(button: Button, localized_text: String = PROMPT_TEXT) -> void:
	host_button = button
	prompt_text = localized_text if not localized_text.is_empty() else PROMPT_TEXT
	name = "PromptRibbon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fill the host button via anchors AND offsets. `set_anchors_preset` with the
	# default keep_offsets=false would bake offsets against the button's size at
	# this instant (still its 845px custom_minimum_size, before the VBox stretches
	# it to 860), collapsing the ribbon to a 15x0 sliver so the centered label
	# renders pinned to the button's left edge.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_label()
	sync_visual(false)


func set_prompt_text(localized_text: String) -> void:
	prompt_text = localized_text if not localized_text.is_empty() else PROMPT_TEXT
	if host_button != null:
		host_button.text = prompt_text
	if prompt_label != null:
		prompt_label.text = prompt_text


func advance(delta: float, transition_active: bool) -> void:
	elapsed_sec += maxf(delta, 0.0)
	sync_visual(transition_active)


func sync_visual(transition_active: bool) -> void:
	if host_button == null or transition_active:
		return
	var pulse := get_pulse()
	host_button.modulate = Color(1.0, 1.0, 1.0, lerpf(0.90, 1.0, pulse))
	queue_redraw()
	if prompt_label != null:
		prompt_label.add_theme_color_override(
			"font_color",
			Color(0.88, 0.82, 0.68, lerpf(0.92, 1.0, pulse))
		)


func get_pulse() -> float:
	var wave := 0.5 + 0.5 * sin(elapsed_sec * TAU / PULSE_PERIOD_SEC)
	return _smoothstep01(wave)


func _build_label() -> void:
	for child in get_children():
		child.queue_free()
	prompt_label = null
	var center := CenterContainer.new()
	center.name = "PromptTextCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Same fill contract as the ribbon: force offsets to zero so the center never
	# collapses to its min-size when the parent is resized after this call.
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label = Label.new()
	prompt_label.name = "PromptText"
	prompt_label.text = prompt_text
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", PROMPT_FONT_SIZE)
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.08, 0.72))
	if host_button != null:
		var font: Font = host_button.get_theme_font("font")
		if font != null:
			prompt_label.add_theme_font_override("font", font)
	center.add_child(prompt_label)
	add_child(center)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var pulse := get_pulse()
	var line_alpha := lerpf(0.48, 0.64, pulse)
	var line_color := Color(HAIRLINE_COLOR.r, HAIRLINE_COLOR.g, HAIRLINE_COLOR.b, line_alpha)
	var center := rect.get_center()
	_draw_side_dash_ornaments(center, line_color)
	_draw_lower_diamond_ornament(
		center + Vector2(0.0, minf(LOWER_ORNAMENT_Y_OFFSET, rect.size.y * 0.34)),
		line_color
	)


func _draw_side_dash_ornaments(center: Vector2, color: Color) -> void:
	var outer_margin := minf(SIDE_DASH_OUTER_MARGIN, size.x * 0.18)
	var inner_gap := minf(SIDE_DASH_INNER_GAP, size.x * 0.34)
	if center.x - inner_gap <= outer_margin:
		return
	draw_line(Vector2(outer_margin, center.y), Vector2(center.x - inner_gap, center.y), color, HAIRLINE_WIDTH, true)
	draw_line(Vector2(center.x + inner_gap, center.y), Vector2(size.x - outer_margin, center.y), color, HAIRLINE_WIDTH, true)
	draw_circle(Vector2(center.x - inner_gap, center.y), 2.0, color)
	draw_circle(Vector2(center.x + inner_gap, center.y), 2.0, color)


func _draw_lower_diamond_ornament(center: Vector2, color: Color) -> void:
	draw_line(
		center + Vector2(-LOWER_DASH_HALF_LENGTH, 0.0),
		center + Vector2(-LOWER_DASH_CENTER_GAP, 0.0),
		color,
		HAIRLINE_WIDTH,
		true
	)
	draw_line(
		center + Vector2(LOWER_DASH_CENTER_GAP, 0.0),
		center + Vector2(LOWER_DASH_HALF_LENGTH, 0.0),
		color,
		HAIRLINE_WIDTH,
		true
	)
	draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -CENTER_DIAMOND_RADIUS),
			center + Vector2(CENTER_DIAMOND_RADIUS, 0.0),
			center + Vector2(0.0, CENTER_DIAMOND_RADIUS),
			center + Vector2(-CENTER_DIAMOND_RADIUS, 0.0),
			center + Vector2(0.0, -CENTER_DIAMOND_RADIUS),
		]),
		color,
		HAIRLINE_WIDTH,
		true
	)


func _smoothstep01(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
