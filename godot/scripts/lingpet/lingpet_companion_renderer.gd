extends RefCounted

const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")

# Soft ambient aura tuning. The persistent companion glow (Lunabi / Maribo) is a
# cached radial-falloff texture blitted at low normal-blend alpha -- NOT a hard
# draw_circle disc -- so the SD body reads as wrapped in soft transparent light.
# Kept deliberately faint and feathered ("아주 티 안 나게 투명"): a wide outer
# halo + a slightly whiter core + a few faint drifting light motes, all driven
# by a two-rate organic breathing ease. The flash/burst glows below stay sharp
# on purpose -- those are gameplay feedback, not the ambient aura.
const _SOFT_GLOW_TEX_SIZE := 64
const _AURA_MOTE_COUNT := 4

static var _soft_glow_texture: Texture2D = null


func prewarm_assets() -> void:
	_get_or_create_soft_glow_texture()


func draw_companion(canvas: CanvasItem, center: Vector2, config: Dictionary) -> void:
	if canvas == null:
		return
	if not bool(config.get("companion_visible", true)):
		return
	var radius: float = float(config.get("radius", 16.0))
	var hit_flash: float = float(config.get("hit_flash", 0.0))
	var gauge_flash: float = float(config.get("gauge_flash", 0.0))
	var skill_flash: float = float(config.get("skill_flash", 0.0))
	var switch_transition: float = clampf(float(config.get("switch_transition", 0.0)), 0.0, 1.0)
	var now_ms: float = float(Time.get_ticks_msec())
	var bob: float = sin(now_ms * 0.0048) * 2.6
	var draw_center: Vector2 = center + Vector2(0.0, bob)
	# Soft "barely-there" ambient aura -- replaces the old hard draw_circle disc.
	# See the _SOFT_GLOW_TEX_SIZE notes at the top of the file.
	_draw_soft_aura(canvas, draw_center, radius, now_ms)
	if switch_transition > 0.0:
		_draw_switch_transition(canvas, draw_center, radius, switch_transition, int(config.get("switch_particles", 12)), int(config.get("switch_trigger_count", 0)))
	var sprite_alpha: float = 1.0 if switch_transition <= 0.0 else lerpf(0.42, 1.0, 1.0 - switch_transition)
	_draw_companion_sprite(canvas, draw_center, config, sprite_alpha)
	if gauge_flash > 0.0:
		var gauge_radius: float = lerpf(radius + 14.0, radius + 42.0, 1.0 - gauge_flash)
		canvas.draw_circle(draw_center, gauge_radius, Color(1.0, 0.88, 0.24, 0.16 * gauge_flash))
		canvas.draw_arc(draw_center, gauge_radius * 0.82, 0.0, TAU, 36, Color(1.0, 0.94, 0.42, 0.68 * gauge_flash), 2.2, true)
		_draw_burst(canvas, draw_center, gauge_flash, int(config.get("burst_particles", 8)), int(config.get("gauge_trigger_count", 0)), Color(1.0, 0.88, 0.24, 1.0), true)
	if skill_flash > 0.0:
		var skill_radius: float = lerpf(radius + 18.0, radius + 54.0, 1.0 - skill_flash)
		canvas.draw_circle(draw_center, skill_radius, Color(0.24, 0.92, 1.0, 0.18 * skill_flash))
		canvas.draw_arc(draw_center, skill_radius * 0.82, 0.0, TAU, 40, Color(0.72, 1.0, 1.0, 0.72 * skill_flash), 2.6, true)
		_draw_burst(canvas, draw_center, skill_flash, int(config.get("burst_particles", 8)), int(config.get("skill_trigger_count", 0)), Color(0.54, 1.0, 1.0, 1.0), false)
	if hit_flash > 0.0:
		var flash_radius: float = lerpf(radius + 8.0, radius + 34.0, 1.0 - hit_flash)
		canvas.draw_circle(draw_center, flash_radius, Color(0.70, 1.0, 0.92, 0.22 * hit_flash))
		canvas.draw_arc(draw_center, flash_radius * 0.86, 0.0, TAU, 36, Color(0.88, 1.0, 0.76, 0.58 * hit_flash), 2.0, true)


func _draw_soft_aura(canvas: CanvasItem, center: Vector2, radius: float, now_ms: float) -> void:
	var tex: Texture2D = _get_or_create_soft_glow_texture()
	if tex == null:
		return
	# Two-rate breathing: a slow primary swell mixed with a gentler faster
	# shimmer so the pulse never reads as one mechanical sine. Small amplitude.
	var breath_slow: float = 0.5 + 0.5 * sin(now_ms * 0.00082)
	var breath_fast: float = 0.5 + 0.5 * sin(now_ms * 0.0021 + 1.3)
	var breath: float = lerpf(breath_slow, breath_fast, 0.32)
	# Wide outer halo (widest, faintest) + a tighter, slightly whiter core so the
	# center reads as soft light rather than a saturated green ring. Peak alpha
	# stays well below the old 0.17~0.24 hard disc and falls off feathered.
	var outer_r: float = radius + lerpf(24.0, 31.0, breath)
	var outer_a: float = lerpf(0.045, 0.072, breath)
	var core_r: float = radius + lerpf(11.0, 15.0, breath)
	var core_a: float = lerpf(0.060, 0.090, breath)
	_blit_soft_glow(canvas, tex, center, outer_r, Color(0.24, 1.0, 0.80, outer_a))
	_blit_soft_glow(canvas, tex, center, core_r, Color(0.66, 1.0, 0.92, core_a))
	_draw_aura_motes(canvas, tex, center, radius, now_ms)


func _blit_soft_glow(canvas: CanvasItem, tex: Texture2D, center: Vector2, glow_radius: float, color: Color) -> void:
	var r: float = maxf(1.0, glow_radius)
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, color)


func _draw_aura_motes(canvas: CanvasItem, tex: Texture2D, center: Vector2, radius: float, now_ms: float) -> void:
	for i in range(_AURA_MOTE_COUNT):
		var fi: float = float(i)
		# Slow orbit + gentle in/out drift + per-mote twinkle, all at very low
		# alpha so the motes register only as a faint floating shimmer, never as
		# discrete dots.
		var ang: float = TAU * fi / float(_AURA_MOTE_COUNT) + now_ms * 0.00019 * (1.0 + 0.18 * fi) + fi * 0.7
		var orbit: float = radius + 17.0 + 7.0 * sin(now_ms * 0.0012 + fi * 1.9)
		var mote_bob: float = sin(now_ms * 0.0017 + fi * 2.3) * 3.0
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * orbit + Vector2(0.0, mote_bob)
		var twinkle: float = 0.5 + 0.5 * sin(now_ms * 0.0029 + fi * 1.27)
		var mote_a: float = lerpf(0.035, 0.085, twinkle)
		var mote_r: float = lerpf(4.5, 7.5, twinkle)
		_blit_soft_glow(canvas, tex, pos, mote_r, Color(0.74, 1.0, 0.94, mote_a))


# Cached soft radial-falloff glow sprite (white RGB, feathered alpha) built once
# and shared by every companion. Matches the project's halo-texture convention in
# common_starpoint_visual_host.gd (cos^2 falloff via Image.create + set_pixel),
# squared once more here for an even gentler rim. One-time ~64x64 CPU build; the
# static cache keeps it off the per-frame hot path after first use.
static func _get_or_create_soft_glow_texture() -> Texture2D:
	if _soft_glow_texture != null:
		return _soft_glow_texture
	var size: int = _SOFT_GLOW_TEX_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var dx: float = (float(x) + 0.5) - half
			var dy: float = (float(y) + 0.5) - half
			var d: float = sqrt(dx * dx + dy * dy) / half
			var a: float = 0.0
			if d < 1.0:
				var c: float = cos(d * PI * 0.5)
				var base: float = c * c
				a = base * base
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_soft_glow_texture = ImageTexture.create_from_image(img)
	return _soft_glow_texture


func _draw_companion_sprite(canvas: CanvasItem, center: Vector2, config: Dictionary, alpha: float = 1.0) -> void:
	var animator: Object = config.get("animator", null) as Object
	if animator == null:
		return
	var mode: String = LingpetCompanionSpriteAnimator.MODE_WALK
	var tex: Texture2D = config.get("walk_texture", null) as Texture2D
	if bool(config.get("casting_windup", false)):
		mode = LingpetCompanionSpriteAnimator.MODE_CAST
		tex = config.get("cast_texture", null) as Texture2D
	elif bool(config.get("attacking", false)):
		mode = LingpetCompanionSpriteAnimator.MODE_STRIKE
		tex = config.get("strike_texture", null) as Texture2D
	if tex == null:
		return
	var rects: Dictionary = animator.build_draw_rects(
		tex,
		mode,
		center,
		float(config.get("patrol_pause", 0.0)),
		float(config.get("windup_elapsed", 0.0)),
		float(config.get("windup_seconds", 0.0)),
		float(config.get("motion_speed_ratio", 0.0))
	)
	if rects.is_empty():
		return
	var dest_rect: Rect2 = rects.get("dest", Rect2())
	var source_rect: Rect2 = rects.get("source", Rect2())
	canvas.draw_texture_rect_region(tex, dest_rect, source_rect, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))


func _draw_burst(
	canvas: CanvasItem,
	center: Vector2,
	flash_ratio: float,
	particle_count: int,
	trigger_count: int,
	tint: Color,
	is_gauge: bool
) -> void:
	var safe_count: int = maxi(1, particle_count)
	var expansion: float = 1.0 - flash_ratio
	var phase_offset: float = float(trigger_count % 5) * (0.19 if is_gauge else 0.17)
	var start_min: float = 8.0 if is_gauge else 10.0
	var start_max: float = 16.0 if is_gauge else 20.0
	var end_min: float = 18.0 if is_gauge else 22.0
	var end_max: float = 42.0 if is_gauge else 52.0
	var alpha: float = (0.58 if is_gauge else 0.62) * flash_ratio
	var line_width: float = (2.0 if is_gauge else 2.2) * flash_ratio
	var dot_radius: float = (2.4 if is_gauge else 2.6) * flash_ratio
	for i in range(safe_count):
		var angle: float = TAU * float(i) / float(safe_count) + phase_offset
		var dir := Vector2(cos(angle), sin(angle))
		var ray_start: Vector2 = center + dir * lerpf(start_min, start_max, expansion)
		var ray_end: Vector2 = center + dir * lerpf(end_min, end_max, expansion)
		var line_color := Color(tint.r, tint.g, tint.b, alpha)
		var dot_color := Color(1.0, 0.98, 0.62, alpha) if is_gauge else Color(0.88, 1.0, 1.0, alpha)
		canvas.draw_line(ray_start, ray_end, line_color, maxf(1.0, line_width), true)
		canvas.draw_circle(ray_end, maxf(1.1 if is_gauge else 1.2, dot_radius), dot_color)


func _draw_switch_transition(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	switch_ratio: float,
	particle_count: int,
	trigger_count: int
) -> void:
	var ratio := clampf(switch_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var progress := 1.0 - ratio
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var pulse := sin(progress * PI)
	var ring_radius := lerpf(radius + 58.0, radius + 18.0, eased)
	var ring_alpha := 0.16 + 0.28 * ratio + 0.14 * pulse
	canvas.draw_circle(center, ring_radius, Color(0.08, 0.64, 0.72, 0.10 * ratio))
	canvas.draw_arc(center, ring_radius, -PI * 0.5 + progress * TAU, PI * 1.35 + progress * TAU, 36, Color(0.42, 1.0, 0.96, ring_alpha), 2.4, true)
	canvas.draw_arc(center, ring_radius * 0.62, PI * 0.25 - progress * TAU, PI * 1.55 - progress * TAU, 32, Color(0.72, 1.0, 0.82, 0.32 * ratio), 1.8, true)
	var safe_count := maxi(4, particle_count)
	var phase_offset := float(trigger_count % 7) * 0.31
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count) + phase_offset
		var dir := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-dir.y, dir.x)
		var scatter := lerpf(radius + 66.0, radius + 10.0, eased)
		var wobble := sin(progress * TAU * 2.1 + float(i) * 1.77 + phase_offset) * lerpf(8.0, 2.0, eased)
		var shard_pos := center + dir * scatter + tangent * wobble
		var shard_target := center + dir * lerpf(radius + 18.0, radius + 4.0, eased)
		var shard_alpha := (0.26 + 0.34 * pulse) * ratio
		var shard_size := lerpf(3.0, 1.4, eased)
		canvas.draw_line(shard_pos, shard_target, Color(0.38, 1.0, 0.94, shard_alpha), maxf(1.0, 1.7 * ratio), true)
		canvas.draw_circle(shard_pos, maxf(1.0, shard_size), Color(0.82, 1.0, 0.88, minf(0.88, shard_alpha + 0.18)))
