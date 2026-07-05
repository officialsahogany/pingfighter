extends Control

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")

const STAINED_GLASS_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D mask_texture : source_color;
uniform float reveal_progress = 0.0;
uniform float reveal_softness = 0.055;
uniform float lead_luma_cutoff = 0.15;
uniform float completion_flash = 0.0;
uniform float glass_dim = 0.84;
uniform float glass_alpha = 1.0;
uniform float time = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec4 mask_data = texture(mask_texture, UV);
	float lum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float reveal = smoothstep(mask_data.r, min(mask_data.r + reveal_softness, 1.0), reveal_progress);
	float glass_domain = smoothstep(0.05, 0.30, mask_data.a);
	float lead = 1.0 - smoothstep(lead_luma_cutoff - 0.035, lead_luma_cutoff + 0.020, lum);
	float chroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
	float black_lead = lead * (1.0 - smoothstep(0.025, 0.10, chroma));

	vec3 gray_color = vec3(gray) * glass_dim;
	vec3 revealed_color = mix(gray_color, color.rgb, reveal);
	vec3 flash_color = color.rgb + vec3(1.0, 0.82, 0.45) * completion_flash * 0.28;
	revealed_color = mix(revealed_color, flash_color, completion_flash);
	revealed_color = mix(revealed_color, color.rgb, black_lead);

	float band_dist = mask_data.r - reveal_progress;
	float band = exp(-(band_dist * band_dist) * 700.0);
	float band_pulse = 0.85 + sin(time * 6.5) * 0.15;
	float band_active = smoothstep(0.0, 0.05, reveal_progress) * (1.0 - smoothstep(0.94, 1.0, reveal_progress));
	vec3 band_glow = vec3(0.45, 0.92, 1.0) * 1.4 + vec3(1.0, 0.78, 0.36) * 0.35;
	revealed_color += band_glow * band * band_pulse * band_active * glass_domain;

	vec3 final_color = mix(color.rgb, revealed_color, glass_domain);
	COLOR = vec4(final_color, color.a * glass_alpha);
}
"""

# Soft dark band behind the central text cluster so tips stay readable over
# the busy stained-glass art. Top/bottom edges feather out via UV.y.
const TEXT_BACKDROP_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float edge_softness : hint_range(0.05, 0.5) = 0.22;
uniform float max_alpha : hint_range(0.0, 1.0) = 0.60;

void fragment() {
	float fade = smoothstep(0.0, edge_softness, UV.y) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, UV.y));
	COLOR = vec4(0.010, 0.014, 0.026, max_alpha * fade);
}
"""

const PROGRESS_FILL_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float time = 0.0;
uniform vec3 base_color : source_color = vec3(0.0, 0.82, 1.0);
uniform vec3 pulse_color : source_color = vec3(1.0, 0.78, 0.36);

void fragment() {
	vec2 uv = UV;
	float pulse_phase = fract(uv.x - time * 0.6);
	float pulse_glow = exp(-pow((pulse_phase - 0.5) * 4.0, 2.0));
	float scan = abs(sin(uv.x * 90.0 - time * 5.0));
	float scan_mask = smoothstep(0.7, 1.0, scan) * 0.25;
	float vertical_fade = clamp(1.0 - abs(uv.y - 0.5) * 1.4, 0.0, 1.0);
	vec3 col = base_color * (0.65 + pulse_glow * 0.5 + scan_mask);
	col += pulse_color * pulse_glow * 0.55;
	col *= vertical_fade;
	COLOR = vec4(col, 0.92);
}
"""

var art_rect: TextureRect = null
var title_label: Label = null
var title_ghost_r: Label = null
var title_ghost_b: Label = null
var subtitle_label: Label = null
var status_label: Label = null
var percent_label: Label = null
var hint_label: Label = null
var progress_track: ColorRect = null
var progress_fill: ColorRect = null
var progress_glow: ColorRect = null
var shader_material: ShaderMaterial = null
var progress_fill_material: ShaderMaterial = null
var flash_overlay: ColorRect = null
var text_backdrop: ColorRect = null

const PROGRESS_SMOOTH_RATE_PER_SEC := 1.2

var snapshot: Dictionary = {}
var view_size := Vector2.ZERO
var display_progress: float = 0.0
var animation_time: float = 0.0
var glass_dim: float = 0.84
var reveal_softness: float = 0.055
var lead_luma_cutoff: float = 0.15
var glass_alpha: float = 1.0
var _smoothed_progress: float = 0.0
var _last_sync_msec: int = -1
# Tip index this load started on; re-rolled each time the screen re-appears so
# short loads don't always open on the same tip.
var _tip_start_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_build_nodes()
	visible = false


func configure(full_texture: Texture2D, mask_texture: Texture2D, font: Font = null) -> void:
	_build_nodes()
	if art_rect != null:
		art_rect.texture = full_texture
	if shader_material != null:
		shader_material.set_shader_parameter("mask_texture", mask_texture)
	_apply_font(font)


func show_loading(next_snapshot: Dictionary, next_progress: float, next_view_size: Vector2) -> void:
	_build_nodes()
	var was_hidden := not visible
	snapshot = next_snapshot.duplicate(true)
	display_progress = clampf(next_progress, 0.0, 1.0)
	view_size = next_view_size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(1280.0, 720.0)
	if was_hidden:
		_smoothed_progress = 0.0
		_last_sync_msec = Time.get_ticks_msec()
		# Vary the opening tip per load via boot time (no global RNG side effect).
		_tip_start_index = Time.get_ticks_msec()
	var sync_delta := _consume_sync_delta()
	visible = true
	set_process(false)
	animation_time += sync_delta
	_update_smoothed_progress(sync_delta)
	_layout()
	_sync_text()
	_sync_shader()
	queue_redraw()


func hide_loading() -> void:
	visible = false
	set_process(false)
	_smoothed_progress = 0.0
	_last_sync_msec = -1


func _process(delta: float) -> void:
	if not visible:
		return
	animation_time += delta
	_update_smoothed_progress(delta)
	_sync_shader()
	queue_redraw()


func _update_smoothed_progress(delta: float) -> void:
	var step_max: float = PROGRESS_SMOOTH_RATE_PER_SEC * delta
	var diff: float = display_progress - _smoothed_progress
	if absf(diff) <= step_max:
		_smoothed_progress = display_progress
	else:
		_smoothed_progress += signf(diff) * step_max


func _consume_sync_delta() -> float:
	var now_msec := Time.get_ticks_msec()
	if _last_sync_msec < 0:
		_last_sync_msec = now_msec
		return 1.0 / 60.0
	var delta: float = clampf(float(now_msec - _last_sync_msec) / 1000.0, 0.0, 0.05)
	_last_sync_msec = now_msec
	if delta <= 0.0:
		return 1.0 / 60.0
	return delta


func _draw() -> void:
	if not visible:
		return
	var center := view_size * 0.5
	var pulse := 0.5 + sin(animation_time * 4.0) * 0.5
	_draw_cyber_background(view_size)
	draw_circle(center + Vector2(0.0, -20.0), 184.0 + pulse * 20.0, Color(0.0, 0.72, 1.0, 0.045), true)
	draw_circle(center + Vector2(0.0, -20.0), 116.0 + pulse * 14.0, Color(1.0, 0.72, 0.26, 0.035), true)
	var art := _art_target_rect()
	draw_rect(art.grow(10.0), Color(0.0, 0.0, 0.0, 0.35), false, 2.0)


func _draw_cyber_background(size_v: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.008, 0.010, 0.018, 1.0))
	var top_rect := Rect2(Vector2.ZERO, Vector2(size_v.x, size_v.y * 0.42))
	draw_rect(top_rect, Color(0.018, 0.042, 0.060, 0.74))
	var grid_step: float = max(34.0, size_v.x / 34.0)
	var x_offset: float = fmod(animation_time * 18.0, grid_step)
	var x: float = -size_v.y * 0.18 + x_offset
	while x < size_v.x + grid_step:
		draw_line(Vector2(x, 0.0), Vector2(x + size_v.y * 0.18, size_v.y), Color(0.0, 0.74, 1.0, 0.045), 1.0)
		x += grid_step
	var y_offset: float = fmod(animation_time * 12.0, grid_step)
	var y: float = y_offset
	while y < size_v.y:
		draw_line(Vector2(0.0, y), Vector2(size_v.x, y), Color(1.0, 0.72, 0.26, 0.030), 1.0)
		y += grid_step


func _build_nodes() -> void:
	if art_rect != null and is_instance_valid(art_rect):
		return
	art_rect = TextureRect.new()
	art_rect.name = "StainedGlassArt"
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_SCALE
	art_rect.z_index = 10
	shader_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = STAINED_GLASS_SHADER
	shader_material.shader = shader
	art_rect.material = shader_material
	add_child(art_rect)

	text_backdrop = ColorRect.new()
	text_backdrop.name = "TextBackdrop"
	text_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_backdrop.z_index = 15
	var backdrop_material := ShaderMaterial.new()
	var backdrop_shader := Shader.new()
	backdrop_shader.code = TEXT_BACKDROP_SHADER
	backdrop_material.shader = backdrop_shader
	text_backdrop.material = backdrop_material
	add_child(text_backdrop)

	progress_track = ColorRect.new()
	progress_track.name = "ProgressTrack"
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.color = Color(1.0, 1.0, 1.0, 0.12)
	progress_track.z_index = 20
	add_child(progress_track)

	progress_glow = ColorRect.new()
	progress_glow.name = "ProgressGlow"
	progress_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_glow.color = Color(0.0, 0.72, 1.0, 0.20)
	progress_glow.z_index = 21
	add_child(progress_glow)

	progress_fill = ColorRect.new()
	progress_fill.name = "ProgressFill"
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_fill.color = Color(0.0, 0.82, 1.0, 0.92)
	progress_fill.z_index = 22
	progress_fill_material = ShaderMaterial.new()
	var progress_shader := Shader.new()
	progress_shader.code = PROGRESS_FILL_SHADER
	progress_fill_material.shader = progress_shader
	progress_fill.material = progress_fill_material
	add_child(progress_fill)

	flash_overlay = ColorRect.new()
	flash_overlay.name = "FlashOverlay"
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.color = Color(1.0, 0.94, 0.78, 0.0)
	flash_overlay.z_index = 50
	add_child(flash_overlay)

	title_ghost_r = _make_label("TitleGhostR", 30, Color(1.0, 0.18, 0.30, 0.0), 29)
	title_ghost_b = _make_label("TitleGhostB", 30, Color(0.20, 0.58, 1.0, 0.0), 29)
	title_label = _make_label("Title", 30, Color.WHITE, 30)
	subtitle_label = _make_label("Subtitle", 15, Color(0.92, 0.78, 0.46, 0.92), 30)
	status_label = _make_label("Status", 17, Color(0.76, 0.88, 0.96, 0.96), 30)
	# Tips can be longer than one line in some languages; wrap instead of clipping.
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	percent_label = _make_label("Percent", 18, Color(0.88, 0.94, 1.0, 0.94), 30)
	hint_label = _make_label("Hint", 13, Color(0.64, 0.74, 0.82, 0.72), 30)


func _make_label(node_name: String, font_size: int, font_color: Color, z: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, font_color.a * 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	# Dark outline keeps text legible over the bright stained-glass art.
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, font_color.a * 0.85))
	label.add_theme_constant_override("outline_size", clampi(int(round(float(font_size) * 0.24)), 3, 8))
	label.z_index = z
	add_child(label)
	return label


func _apply_font(font: Font) -> void:
	if font == null:
		return
	for label in [title_label, title_ghost_r, title_ghost_b, subtitle_label, status_label, percent_label, hint_label]:
		if label != null:
			label.add_theme_font_override("font", font)


func _layout() -> void:
	size = view_size
	position = Vector2.ZERO
	if art_rect != null:
		var art := _art_target_rect()
		art_rect.position = art.position
		art_rect.size = art.size
	if flash_overlay != null:
		flash_overlay.position = Vector2.ZERO
		flash_overlay.size = view_size
	var center := view_size * 0.5
	var text_w: float = min(view_size.x - 80.0, 780.0)
	if text_backdrop != null:
		# Full-width feathered band behind title..hint so text reads over the art.
		var band_top: float = center.y - 88.0
		var band_bottom: float = center.y + 174.0
		text_backdrop.position = Vector2(0.0, band_top)
		text_backdrop.size = Vector2(view_size.x, band_bottom - band_top)
	_set_label_rect(title_label, Rect2(center.x - text_w * 0.5, center.y - 58.0, text_w, 38.0))
	_set_label_rect(subtitle_label, Rect2(center.x - text_w * 0.5, center.y - 20.0, text_w, 24.0))
	# Taller rect so a longer localized tip can wrap to a second line without
	# colliding with the progress bar below (which starts at center.y + 76).
	_set_label_rect(status_label, Rect2(center.x - text_w * 0.5, center.y + 14.0, text_w, 52.0))
	_set_label_rect(percent_label, Rect2(center.x - 80.0, center.y + 102.0, 160.0, 28.0))
	_set_label_rect(hint_label, Rect2(center.x - text_w * 0.5, center.y + 138.0, text_w, 22.0))
	var progress_w: float = clampf(view_size.x * 0.44, 360.0, 680.0)
	var progress_rect := Rect2(Vector2(center.x - progress_w * 0.5, center.y + 76.0), Vector2(progress_w, 10.0))
	if progress_track != null:
		progress_track.position = progress_rect.position
		progress_track.size = progress_rect.size
	if progress_glow != null:
		progress_glow.position = progress_rect.position - Vector2(0.0, 3.0)
		progress_glow.size = Vector2(progress_rect.size.x * _smoothed_progress, progress_rect.size.y + 6.0)
	if progress_fill != null:
		progress_fill.position = progress_rect.position
		progress_fill.size = Vector2(progress_rect.size.x * _smoothed_progress, progress_rect.size.y)


func _set_label_rect(label: Label, rect: Rect2) -> void:
	if label == null:
		return
	label.position = rect.position
	label.size = rect.size


func _sync_text() -> void:
	var title_text := LanguageSettings.translate_text(str(snapshot.get("title", "스테이지 진입 준비 중")))
	if title_label != null:
		title_label.text = title_text
	if title_ghost_r != null:
		title_ghost_r.text = title_text
	if title_ghost_b != null:
		title_ghost_b.text = title_text
	if subtitle_label != null:
		subtitle_label.text = LanguageSettings.translate_text(str(snapshot.get("subtitle", "")))
	if status_label != null:
		# Show a rotating gameplay tip in place of the old mechanical boot-status
		# line. The tier (basic for 테스트/junior, advanced otherwise) and the
		# selected character ride in on the snapshot from the loading renderer;
		# the character contributes one extra control-tip rotation slot.
		var tip_tier := str(snapshot.get("tip_tier", BattleLoadingTips.TIER_ADVANCED))
		var tip_character := str(snapshot.get("tip_character", ""))
		status_label.text = BattleLoadingTips.rotation_tip_for_elapsed(tip_tier, tip_character, _tip_start_index, animation_time)
	_sync_percent_label()
	if hint_label != null:
		hint_label.text = LanguageSettings.translate_text("잠시만 기다려 주세요")


func _sync_shader() -> void:
	if shader_material == null:
		return
	var flash_progress: float = clampf((display_progress - 0.94) / 0.06, 0.0, 1.0)
	var flash: float = sin(flash_progress * PI) * (0.55 + sin(animation_time * 18.0) * 0.12)
	shader_material.set_shader_parameter("reveal_progress", _smoothed_progress)
	shader_material.set_shader_parameter("completion_flash", max(0.0, flash))
	shader_material.set_shader_parameter("time", animation_time)
	shader_material.set_shader_parameter("glass_dim", glass_dim)
	shader_material.set_shader_parameter("reveal_softness", reveal_softness)
	shader_material.set_shader_parameter("lead_luma_cutoff", lead_luma_cutoff)
	shader_material.set_shader_parameter("glass_alpha", glass_alpha)
	if progress_fill_material != null:
		progress_fill_material.set_shader_parameter("time", animation_time)
	if flash_overlay != null:
		flash_overlay.color.a = clampf(max(0.0, flash) * 0.22, 0.0, 0.30)
	if progress_track != null:
		var bar_w: float = progress_track.size.x
		if progress_fill != null:
			progress_fill.size = Vector2(bar_w * _smoothed_progress, progress_track.size.y)
		if progress_glow != null:
			progress_glow.size = Vector2(bar_w * _smoothed_progress, progress_track.size.y + 6.0)
	_sync_percent_label()
	_sync_title_glitch()


func _sync_percent_label() -> void:
	if percent_label != null:
		percent_label.text = "%d%%" % int(round(_smoothed_progress * 100.0))


func _sync_title_glitch() -> void:
	if title_label == null:
		return
	var base_pos: Vector2 = title_label.position
	var base_size: Vector2 = title_label.size
	@warning_ignore("shadowed_global_identifier")
	var seed: float = floor(animation_time * 8.0)
	var trigger_rng: float = fmod(abs(sin(seed * 91.31)) * 47453.5, 1.0)
	var trigger: float = 1.0 if trigger_rng > 0.88 else 0.0
	var jitter_rng: float = fmod(abs(sin(seed * 17.13)) * 9876.5, 1.0)
	var jitter: float = (jitter_rng - 0.5) * 3.0
	if title_ghost_r != null:
		title_ghost_r.size = base_size
		title_ghost_r.position = base_pos + Vector2(jitter + 1.6, 0.0)
		title_ghost_r.modulate.a = trigger * 0.65
	if title_ghost_b != null:
		title_ghost_b.size = base_size
		title_ghost_b.position = base_pos - Vector2(jitter + 1.6, 0.0)
		title_ghost_b.modulate.a = trigger * 0.65


func _art_target_rect() -> Rect2:
	# Cover-fit at the ART's own aspect ratio (fallback = the 1672x941 ratio the
	# stage 1-5 stained-glass sheets share) so non-standard art such as the
	# square stage 6 Tetriser placeholder is not stretched.
	var aspect: float = 1672.0 / 941.0
	if art_rect != null and art_rect.texture != null:
		var texture_size: Vector2 = art_rect.texture.get_size()
		if texture_size.x > 1.0 and texture_size.y > 1.0:
			aspect = texture_size.x / texture_size.y
	var target_w: float = max(view_size.x, 1.0)
	var target_h: float = target_w / aspect
	if target_h < view_size.y:
		target_h = view_size.y
		target_w = target_h * aspect
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = 0.88
	target_w *= scale
	target_h *= scale
	var center := view_size * 0.5 + Vector2(0.0, -36.0)
	return Rect2(center - Vector2(target_w, target_h) * 0.5, Vector2(target_w, target_h))
