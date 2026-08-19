extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TimelineState := preload("res://scripts/items/mythic_item_acquisition_timeline_state.gd")

const ICON_SIZE := 96.0
const TEXT_BAND_SIZE := Vector2(560.0, 112.0)
const TEXT_BAND_TOP := 456.0
const TEXT_NAME_HEIGHT := 36.0
const TEXT_PADDING := 16.0
const TEXT_DESCRIPTION_TOP := 40.0
const TEXT_DESCRIPTION_HEIGHT := 56.0
const REVEAL_PHASE := "reveal"
const ABSORB_PHASE := "absorb"
const CONTINUE_HINT_TEXT := "클릭해 계속"
const BASE_DESCRIPTION_META := &"mythic_acquisition_base_description"


static func compute_icon_source_rect(
	texture_size: Vector2,
	frame_count: int,
	frame_msec: int,
	source_inset: float,
	now_msec: int
) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var safe_frame_count := maxi(1, frame_count)
	var safe_frame_msec := maxi(1, frame_msec)
	var frame_width := texture_size.x / float(safe_frame_count)
	var frame_index := 0
	if safe_frame_count > 1:
		frame_index = int(floor(float(maxi(0, now_msec)) / float(safe_frame_msec))) % safe_frame_count
	var inset := minf(maxf(0.0, source_inset), maxf(0.0, minf(frame_width, texture_size.y) * 0.42))
	return Rect2(
		Vector2(frame_width * float(frame_index) + inset, inset),
		Vector2(maxf(1.0, frame_width - inset * 2.0), maxf(1.0, texture_size.y - inset * 2.0))
	)


static func compute_icon_fit(source_size: Vector2, icon_scale: float) -> float:
	var reference_extent := maxf(1.0, maxf(source_size.x, source_size.y))
	return ICON_SIZE * icon_scale / reference_extent


static func compute_text_alpha(phase: String, phase_timer: float) -> float:
	match phase:
		REVEAL_PHASE:
			return clampf(phase_timer / 0.45, 0.0, 1.0)
		ABSORB_PHASE:
			return clampf(1.0 - phase_timer / 0.35, 0.0, 1.0)
		_:
			return 0.0


static func compute_text_band_position(field_width: float, float_offset: float) -> Vector2:
	return Vector2(
		(field_width - TEXT_BAND_SIZE.x) * 0.5,
		TEXT_BAND_TOP + float_offset
	)


func apply_icon_texture(
	icon_sprite: Sprite2D,
	texture: Texture2D,
	frame_count: int,
	frame_msec: int,
	source_inset: float,
	now_msec: int
) -> void:
	if icon_sprite == null:
		return
	if texture == null:
		icon_sprite.texture = null
		icon_sprite.region_enabled = false
		return
	icon_sprite.texture = texture
	if frame_count > 1:
		var source_rect := compute_icon_source_rect(texture.get_size(), frame_count, frame_msec, source_inset, now_msec)
		if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
			icon_sprite.region_enabled = true
			icon_sprite.region_rect = source_rect
			return
	icon_sprite.region_enabled = false


func apply_icon_visual(
	icon_sprite: Sprite2D,
	texture: Texture2D,
	frame_count: int,
	frame_msec: int,
	source_inset: float,
	now_msec: int,
	icon_scale: float,
	icon_alpha: float,
	reveal_position: Vector2,
	set_reveal_position: bool
) -> void:
	if icon_sprite == null or texture == null:
		return
	var source_rect := compute_icon_source_rect(texture.get_size(), frame_count, frame_msec, source_inset, now_msec)
	if frame_count > 1 and source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
		icon_sprite.region_enabled = true
		icon_sprite.region_rect = source_rect
	var reference_size := source_rect.size if icon_sprite.region_enabled else texture.get_size()
	var fit := compute_icon_fit(reference_size, icon_scale)
	icon_sprite.scale = Vector2(fit, fit)
	icon_sprite.modulate = Color(1.0, 1.0, 1.0, clampf(icon_alpha, 0.0, 1.0))
	if set_reveal_position:
		icon_sprite.position = reveal_position


func sync_text_content(
	name_label: Label,
	description_label: Label,
	enabled: bool,
	display_name: String,
	description: String
) -> void:
	if name_label != null:
		name_label.text = display_name if enabled else ""
	if description_label != null:
		description_label.set_meta(BASE_DESCRIPTION_META, description if enabled else "")
		description_label.text = description if enabled else ""


func apply_text_state(
	text_band: ColorRect,
	name_label: Label,
	description_label: Label,
	enabled: bool,
	phase: String,
	phase_timer: float,
	field_width: float,
	float_offset: float
) -> void:
	var alpha := compute_text_alpha(phase, phase_timer) if enabled else 0.0
	var band_position := compute_text_band_position(field_width, float_offset)
	if text_band != null:
		text_band.position = band_position
		text_band.size = TEXT_BAND_SIZE
	if name_label != null:
		name_label.position = band_position + Vector2(TEXT_PADDING, 6.0)
		name_label.size = Vector2(TEXT_BAND_SIZE.x - TEXT_PADDING * 2.0, TEXT_NAME_HEIGHT)
	if description_label != null:
		description_label.position = band_position + Vector2(TEXT_PADDING, TEXT_DESCRIPTION_TOP)
		description_label.size = Vector2(TEXT_BAND_SIZE.x - TEXT_PADDING * 2.0, TEXT_DESCRIPTION_HEIGHT)
		sync_continue_hint(
			description_label,
			enabled
			and phase == REVEAL_PHASE
			and phase_timer >= TimelineState.REVEAL_CLICK_DELAY
		)
	apply_text_alpha(text_band, name_label, description_label, enabled, alpha)


func sync_continue_hint(description_label: Label, waiting_for_click: bool) -> void:
	if description_label == null:
		return
	var base_description := str(description_label.get_meta(BASE_DESCRIPTION_META, ""))
	if not waiting_for_click:
		description_label.text = base_description
		return
	var hint := LanguageSettings.translate_text(CONTINUE_HINT_TEXT)
	description_label.text = (
		"%s\n%s" % [base_description, hint]
		if not base_description.is_empty()
		else hint
	)


func apply_text_alpha(
	text_band: ColorRect,
	name_label: Label,
	description_label: Label,
	enabled: bool,
	alpha: float
) -> void:
	var clamped_alpha := clampf(alpha, 0.0, 1.0)
	var is_visible := enabled and clamped_alpha > 0.001
	var modulate := Color(1.0, 1.0, 1.0, clamped_alpha)
	if text_band != null:
		text_band.visible = is_visible
		text_band.modulate = modulate
	if name_label != null:
		name_label.visible = is_visible
		name_label.modulate = modulate
	if description_label != null:
		description_label.visible = is_visible
		description_label.modulate = modulate
