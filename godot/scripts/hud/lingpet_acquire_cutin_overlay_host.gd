extends RefCounted

# Fullscreen acquisition cut-in for the Maribo lingpet. Overlay-only (does NOT
# pause gameplay): the ball keeps moving underneath while this draws on top of
# the HUD, mirroring skill_cutin_overlay_host. Driven by lingpet_egg_runtime's
# is_acquire_cutin_active() / get_acquire_cutin_progress(); triggered once when
# the egg hatches into the companion.
#
# Art is the ORIGINAL outsourced illustration (v003), NOT the SD walk sheet.
# Primary cut-in visual is a Live2D-style ANIMATION sheet: the v003 nukki art
# was animated via AutoSprite's asset pipeline (animate_asset, which animates the
# supplied image directly instead of re-deriving a humanoid -- so the trident
# spear and all detail are preserved, unlike the character-iso path). The frames
# carry the breathing / sway / spear-bob, so the host does NOT add squash/stretch
# on top; it only adds the entrance punch + aura chrome. The static PNG remains a
# fallback if the sheet is missing.
# Provenance: v003 magenta -> magenta-key nukki -> maribo_cutin_art.png (static)
#   -> AutoSprite create_asset + animate_asset (legendary, looping)
#   -> generate_asset_spritesheet 512px/49 -> Real-ESRGAN x2 (alpha-safe)
#   -> maribo_cutin_anim.png (1024px/frame, 7x7, 49 frames, 7168px sheet).

const CUTIN_ART: Texture2D = preload("res://assets/sprites/lingpet/maribo_cutin_art.png")
const CUTIN_ANIM_SHEET: Texture2D = preload("res://assets/sprites/lingpet/maribo_cutin_anim.png")
const CUTIN_ANIM_COLS := 7
const CUTIN_ANIM_ROWS := 7
const CUTIN_ANIM_FRAMES := 49
const CUTIN_ANIM_FPS := 14.0
const ANIM_CELL_VIEW_H_RATIO := 0.92
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const TITLE_TEXT := "마리보"
const SUBTITLE_TEXT := "공명으로 깨어난 링펫 · 동행 시작"

const DIM_ALPHA_MAX := 0.66
const OCEAN_DEEP := Color(0.04, 0.09, 0.18)
const OCEAN_GLOW := Color(0.24, 0.78, 1.0)
const RESONANCE := Color(0.55, 1.0, 0.95)
const TITLE_COLOR := Color(0.62, 1.0, 0.96)
const SPEED_LINE_COUNT := 22

# Phase breakpoints over normalized reveal progress (0..1). Progress is clamped
# at 1.0 by the runtime, so progress >= HOLD_PROGRESS means the reveal finished
# and the cut-in is holding for a click/confirm to dismiss.
const INTRO_END := 0.12
const TEXT_START := 0.62
const HOLD_PROGRESS := 0.999


func prewarm_assets() -> void:
	# Texture + font are const-preloaded at script load, so there is nothing to
	# lazy-load here. Method kept for parity with other overlay hosts and so the
	# prewarm controller can instantiate this host ahead of the hatch frame.
	pass


func prewarm_runtime_nodes(_owner: Object = null) -> void:
	prewarm_assets()


func draw(canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
	if canvas == null or runtime == null:
		return
	if not runtime.has_method("is_acquire_cutin_active") or not bool(runtime.is_acquire_cutin_active()):
		return
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var progress: float = 0.0
	if runtime.has_method("get_acquire_cutin_progress"):
		progress = clampf(float(runtime.get_acquire_cutin_progress()), 0.0, 1.0)

	_draw_dim(canvas, view_size, progress)
	_draw_resonance_bg(canvas, view_size, progress)
	_draw_speed_lines(canvas, view_size, progress)
	_draw_art(canvas, view_size, progress)
	_draw_title(canvas, view_size, progress)
	_draw_flash(canvas, view_size, progress)
	_draw_dismiss_hint(canvas, view_size, progress)


func _overlay_fade(progress: float) -> float:
	# Eases the overlay ON during the intro, then stays fully on (the cut-in
	# holds until the player clicks to dismiss — there is no auto fade-out).
	if progress <= INTRO_END:
		return clampf(progress / INTRO_END, 0.0, 1.0)
	return 1.0


func _ease_out_cubic(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


func _draw_dim(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	var alpha: float = DIM_ALPHA_MAX * _overlay_fade(progress)
	if alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, alpha))


func _draw_resonance_bg(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	var fade: float = _overlay_fade(progress)
	if fade <= 0.0:
		return
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46)
	var base_radius: float = view_size.length() * 0.5
	# Soft ocean wash behind the character.
	canvas.draw_circle(center, base_radius, Color(OCEAN_DEEP.r, OCEAN_DEEP.g, OCEAN_DEEP.b, 0.45 * fade))
	canvas.draw_circle(center, base_radius * 0.62, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, 0.18 * fade))
	# Expanding resonance rings (the "공명" pulse).
	var ring_phase: float = clampf((progress - INTRO_END) / 0.5, 0.0, 1.0)
	for i in 3:
		var ring_t: float = float(i) / 3.0
		var pulse: float = fposmod(ring_phase + ring_t, 1.0)
		var radius: float = base_radius * (0.20 + pulse * 0.70)
		var ring_alpha: float = (1.0 - pulse) * 0.40 * fade
		if ring_alpha <= 0.01:
			continue
		canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(RESONANCE.r, RESONANCE.g, RESONANCE.b, ring_alpha), maxf(2.0, view_size.y * 0.004), true)


func _draw_speed_lines(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	if progress < INTRO_END or progress >= HOLD_PROGRESS:
		return
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46)
	var max_radius: float = view_size.length() * 0.58
	var alpha: float = 0.16 * _overlay_fade(progress)
	if alpha <= 0.0:
		return
	for i in SPEED_LINE_COUNT:
		var angle: float = (float(i) / float(SPEED_LINE_COUNT)) * TAU
		var dir := Vector2(cos(angle), sin(angle))
		var inner_r: float = max_radius * 0.34
		var outer_r: float = max_radius * (0.70 + 0.30 * sin(angle * 3.0 + progress * 16.0))
		canvas.draw_line(center + dir * inner_r, center + dir * outer_r, Color(RESONANCE.r, RESONANCE.g, RESONANCE.b, alpha), maxf(1.0, view_size.y * 0.0022), true)


func _draw_art(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	var rise_raw: float = clampf((progress - INTRO_END) / 0.20, 0.0, 1.0)
	var alpha: float = clampf(rise_raw * 1.5, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var entrance: float = _ease_out_back(rise_raw)
	if CUTIN_ANIM_SHEET != null and CUTIN_ANIM_SHEET.get_width() > 1:
		_draw_art_animated(canvas, view_size, t, entrance, rise_raw, alpha)
	else:
		_draw_art_static(canvas, view_size, t, entrance, rise_raw, alpha)


func _draw_art_animated(
	canvas: CanvasItem,
	view_size: Vector2,
	t: float,
	entrance: float,
	rise_raw: float,
	alpha: float
) -> void:
	# Live2D-style: the AutoSprite asset animation carries the breathing / sway /
	# spear-bob, so we only frame-step the loop and apply the entrance punch +
	# aura chrome. No squash/stretch here (the frames already deform the art).
	var sheet: Texture2D = CUTIN_ANIM_SHEET
	var cols: int = maxi(1, CUTIN_ANIM_COLS)
	var rows: int = maxi(1, CUTIN_ANIM_ROWS)
	var cw: float = float(sheet.get_width()) / float(cols)
	var ch: float = float(sheet.get_height()) / float(rows)
	if cw <= 1.0 or ch <= 1.0:
		return
	var frame: int = int(t * CUTIN_ANIM_FPS) % maxi(1, CUTIN_ANIM_FRAMES)
	var col: int = frame % cols
	var row: int = int(floor(float(frame) / float(cols)))
	var src := Rect2(float(col) * cw, float(row) * ch, cw, ch)

	# The cell carries transparent padding (~1.4x) around the character, so size
	# the whole cell generously; the character then reads at roughly hero scale.
	var target_h: float = view_size.y * ANIM_CELL_VIEW_H_RATIO * entrance
	var scale: float = target_h / ch
	var max_w: float = view_size.x * 0.94
	if cw * scale > max_w:
		scale = max_w / cw
	var dw: float = cw * scale
	var dh: float = ch * scale
	var enter_offset: float = lerpf(view_size.y * 0.12, 0.0, _ease_out_cubic(rise_raw))
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46 + enter_offset)
	var pos := Vector2(center.x - dw * 0.5, center.y - dh * 0.5)

	# Character fills ~62% of the padded cell -> hug aura/glow to that radius.
	var char_radius: float = dh * 0.31
	_draw_art_aura(canvas, center, char_radius * 1.18, t, alpha, rise_raw)
	canvas.draw_circle(center, char_radius, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, 0.20 * alpha))
	canvas.draw_texture_rect_region(sheet, Rect2(pos, Vector2(dw, dh)), src, Color(1.0, 1.0, 1.0, alpha))


func _draw_art_static(
	canvas: CanvasItem,
	view_size: Vector2,
	t: float,
	entrance: float,
	rise_raw: float,
	alpha: float
) -> void:
	# Fallback when the animation sheet is missing: animate the single static
	# illustration with feet-anchored squash & stretch + sway + aura (no
	# draw_set_transform, which would trip the rotated-canvas trap).
	if CUTIN_ART == null:
		return
	var art_size: Vector2 = CUTIN_ART.get_size()
	if art_size.x <= 1.0 or art_size.y <= 1.0:
		return
	var target_h: float = view_size.y * 0.64
	var scale_factor: float = target_h / art_size.y
	var max_w: float = view_size.x * 0.86
	if art_size.x * scale_factor > max_w:
		scale_factor = max_w / art_size.x
	var base_size: Vector2 = art_size * scale_factor
	var breathe: float = sin(t * TAU * 0.55)
	var sx: float = 1.0 + breathe * 0.045
	var sy: float = 1.0 - breathe * 0.035
	var draw_size := Vector2(base_size.x * entrance * sx, base_size.y * entrance * sy)
	var settle_center_y: float = view_size.y * 0.42
	var enter_offset: float = lerpf(view_size.y * 0.14, 0.0, _ease_out_cubic(rise_raw))
	var feet_y: float = settle_center_y + base_size.y * 0.5 + enter_offset
	var sway_x: float = sin(t * TAU * 0.27) * view_size.x * 0.014
	var pos := Vector2(view_size.x * 0.5 - draw_size.x * 0.5 + sway_x, feet_y - draw_size.y)
	var center := Vector2(pos.x + draw_size.x * 0.5, pos.y + draw_size.y * 0.5)
	var glow_alpha: float = (0.22 + 0.08 * breathe) * alpha
	_draw_art_aura(canvas, center, maxf(draw_size.x, draw_size.y) * 0.5, t, alpha, rise_raw)
	canvas.draw_circle(center, draw_size.y * 0.46, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, glow_alpha))
	canvas.draw_texture_rect(CUTIN_ART, Rect2(pos, draw_size), false, Color(1.0, 1.0, 1.0, alpha))
	_draw_art_shimmer(canvas, Rect2(pos, draw_size), alpha, t)


func _ease_out_back(t: float) -> float:
	# Overshoot ease: rises past 1.0 then settles back, giving the entrance a
	# punchy "pop" instead of a flat zoom.
	var c: float = clampf(t, 0.0, 1.0)
	var s := 1.70158
	var u: float = c - 1.0
	return 1.0 + (s + 1.0) * pow(u, 3.0) + s * pow(u, 2.0)


func _draw_art_aura(canvas: CanvasItem, center: Vector2, radius: float, t: float, alpha: float, entrance: float) -> void:
	if radius <= 1.0 or alpha <= 0.0:
		return
	# Strong on entrance, then a calmer steady idle aura.
	var intensity: float = (0.45 + 0.55 * (1.0 - clampf(entrance, 0.0, 1.0))) * alpha
	var base_r: float = radius * 0.92
	for ring_index in 3:
		var ring_t: float = float(ring_index) / 2.0
		var spin: float = t * (0.8 + ring_t * 0.6) + ring_t * 1.7
		var r: float = base_r * (0.78 + ring_t * 0.26 + 0.03 * sin(t * 3.0 + ring_t))
		var ring_alpha: float = intensity * (0.42 - ring_t * 0.10)
		var col: Color = OCEAN_GLOW.lerp(RESONANCE, ring_t)
		canvas.draw_arc(center, r, spin, spin + TAU * 0.66, 44, Color(col.r, col.g, col.b, ring_alpha), maxf(2.0, radius * 0.02), true)
		canvas.draw_arc(center, r * 0.7, -spin * 0.9, -spin * 0.9 + TAU * 0.5, 36, Color(0.92, 1.0, 1.0, ring_alpha * 0.6), maxf(1.5, radius * 0.012), true)
	# Orbiting energy motes.
	for mote_index in 10:
		var mote_t: float = float(mote_index) / 10.0
		var angle: float = mote_t * TAU + t * (1.4 + float(mote_index % 3) * 0.25)
		var orbit: float = base_r * (0.92 + 0.10 * sin(t * 2.0 + mote_index))
		var mote_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * orbit
		var mote_alpha: float = intensity * (0.35 + 0.35 * sin(mote_t * PI + t * 2.0))
		if mote_alpha <= 0.02:
			continue
		canvas.draw_circle(mote_pos, maxf(1.5, radius * 0.012), Color(0.85, 1.0, 0.98, mote_alpha))


func _draw_art_shimmer(canvas: CanvasItem, art_rect: Rect2, alpha: float, t: float) -> void:
	# Cheap "living artwork" sparkle: a few cyan glints drifting up over the
	# illustration (concentrated around the spear / upper body) plus a slow
	# diagonal light sweep. Pure additive-feel dots, no per-frame allocation.
	var sparkle_count := 6
	for i in sparkle_count:
		var seed_f: float = float(i) * 1.37
		var phase: float = fposmod(t * 0.35 + seed_f, 1.0)
		var col_x: float = art_rect.position.x + art_rect.size.x * (0.20 + 0.62 * fposmod(seed_f * 0.61, 1.0))
		var sy: float = art_rect.position.y + art_rect.size.y * (0.92 - 0.74 * phase)
		var twinkle: float = sin((t * 6.0 + seed_f) * TAU)
		var sa: float = clampf((0.5 - absf(phase - 0.5)) * 2.0, 0.0, 1.0) * (0.35 + 0.35 * twinkle) * alpha
		if sa <= 0.02:
			continue
		var radius: float = art_rect.size.y * (0.006 + 0.004 * maxf(0.0, twinkle))
		canvas.draw_circle(Vector2(col_x, sy), radius, Color(0.80, 1.0, 0.98, sa))
	# Slow diagonal light sweep across the upper body.
	var sweep: float = fposmod(t * 0.18, 1.0)
	var sweep_x: float = art_rect.position.x + art_rect.size.x * lerpf(-0.1, 1.1, sweep)
	var band_alpha: float = (0.10 * (0.5 - absf(sweep - 0.5)) * 2.0) * alpha
	if band_alpha > 0.01:
		var w: float = art_rect.size.x * 0.10
		var top := Vector2(sweep_x, art_rect.position.y + art_rect.size.y * 0.10)
		var bottom := Vector2(sweep_x - art_rect.size.x * 0.12, art_rect.position.y + art_rect.size.y * 0.62)
		canvas.draw_line(top, bottom, Color(0.85, 1.0, 1.0, band_alpha), maxf(2.0, w * 0.25), true)


func _draw_title(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	if progress < TEXT_START:
		return
	var appear: float = _ease_out_cubic(clampf((progress - TEXT_START) / 0.12, 0.0, 1.0))
	var alpha: float = appear
	if alpha <= 0.0:
		return

	var title_size_px: int = int(view_size.y * 0.072)
	var title_dim: Vector2 = TITLE_FONT.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px)
	var slide: float = lerpf(view_size.y * 0.04, 0.0, appear)
	var title_pos := Vector2(
		(view_size.x - title_dim.x) * 0.5,
		view_size.y * 0.80 + slide
	)
	canvas.draw_string(TITLE_FONT, title_pos + Vector2(2, 2), TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px, Color(0.0, 0.05, 0.10, 0.55 * alpha))
	canvas.draw_string(TITLE_FONT, title_pos, TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px, Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, alpha))

	var sub_size_px: int = int(view_size.y * 0.032)
	var sub_dim: Vector2 = TITLE_FONT.get_string_size(SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size_px)
	var sub_pos := Vector2(
		(view_size.x - sub_dim.x) * 0.5,
		title_pos.y + title_dim.y * 0.78
	)
	canvas.draw_string(TITLE_FONT, sub_pos + Vector2(1, 1), SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size_px, Color(0.0, 0.05, 0.10, 0.5 * alpha))
	canvas.draw_string(TITLE_FONT, sub_pos, SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size_px, Color(0.86, 0.97, 1.0, 0.92 * alpha))


func _draw_flash(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	# One brief bright resonance flash as the title locks in (a short window after
	# TEXT_START). No auto fade-out afterwards -- the cut-in holds until dismissed.
	var flash_window: float = 0.26
	if progress < TEXT_START or progress >= TEXT_START + flash_window:
		return
	var local: float = (progress - TEXT_START) / flash_window
	var flash_alpha: float = (1.0 - local) * 0.30
	if flash_alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(RESONANCE.r, RESONANCE.g, RESONANCE.b, flash_alpha))


func _draw_dismiss_hint(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	# Once the reveal has finished playing, prompt the player to click to resume.
	if progress < HOLD_PROGRESS:
		return
	var pulse: float = 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.006)
	var hint_text := "클릭하여 계속"
	var hint_size_px: int = int(view_size.y * 0.028)
	var hint_dim: Vector2 = TITLE_FONT.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size_px)
	var hint_pos := Vector2(
		(view_size.x - hint_dim.x) * 0.5,
		view_size.y * 0.93
	)
	canvas.draw_string(TITLE_FONT, hint_pos + Vector2(1, 1), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size_px, Color(0.0, 0.05, 0.10, 0.45 * pulse))
	canvas.draw_string(TITLE_FONT, hint_pos, hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size_px, Color(0.92, 1.0, 1.0, 0.5 + 0.45 * pulse))
