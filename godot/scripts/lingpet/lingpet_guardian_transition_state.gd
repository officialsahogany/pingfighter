extends RefCounted

const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

const MODE_NONE := ""
const MODE_SUMMON := "summon"
const MODE_STOW := "stow"
const SUMMON_DURATION := 0.52
const STOW_DURATION := 0.46
const SUMMON_TRAVEL_END := 0.62
const STOW_TRAVEL_START := 0.12
const TRAIL_PIECES := 9

const COLOR_CORE := Color(0.92, 1.0, 0.94, 1.0)
const COLOR_JADE := Color(0.28, 1.0, 0.72, 1.0)
const COLOR_TEAL := Color(0.12, 0.78, 0.82, 1.0)

var _mode := MODE_NONE
var _timer := 0.0
var _duration := 0.0
var _source := Vector2.ZERO
var _target := Vector2.ZERO
var _prewarmed := false


func prewarm() -> void:
	SoftGlowTexture.get_texture(64)
	_prewarmed = true


func begin_summon(source: Vector2, target: Vector2) -> bool:
	if is_active():
		return false
	_begin(MODE_SUMMON, source, target, SUMMON_DURATION)
	return true


func begin_stow(source: Vector2, target: Vector2) -> bool:
	if is_active():
		return false
	_begin(MODE_STOW, source, target, STOW_DURATION)
	return true


func advance(delta: float) -> String:
	if not is_active():
		return MODE_NONE
	_timer = maxf(0.0, _timer - maxf(0.0, delta))
	if _timer > 0.0:
		return MODE_NONE
	var completed_mode := _mode
	reset()
	return completed_mode


func reset() -> void:
	_mode = MODE_NONE
	_timer = 0.0
	_duration = 0.0
	_source = Vector2.ZERO
	_target = Vector2.ZERO


func is_active() -> bool:
	return _mode != MODE_NONE and _timer > 0.0 and _duration > 0.0


func is_summoning() -> bool:
	return is_active() and _mode == MODE_SUMMON


func is_stowing() -> bool:
	return is_active() and _mode == MODE_STOW


func get_progress() -> float:
	if not is_active():
		return 0.0
	return clampf(1.0 - _timer / _duration, 0.0, 1.0)


func get_companion_alpha() -> float:
	var progress := get_progress()
	if is_summoning():
		if progress <= SUMMON_TRAVEL_END:
			return 0.0
		return _smoothstep((progress - SUMMON_TRAVEL_END) / (1.0 - SUMMON_TRAVEL_END))
	if is_stowing():
		return 1.0 - _smoothstep(clampf(progress / 0.72, 0.0, 1.0))
	return 0.0


func get_snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"mode": _mode,
		"progress": get_progress(),
		"source": _source,
		"target": _target,
		"companion_alpha": get_companion_alpha(),
		"duration_draining": is_summoning(),
	}


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not is_active():
		return
	_ensure_prewarmed()
	if is_summoning():
		_draw_summon(canvas, shake_offset)
	else:
		_draw_stow(canvas, shake_offset)


func _begin(mode: String, source: Vector2, target: Vector2, duration: float) -> void:
	_ensure_prewarmed()
	_mode = mode
	_source = source
	_target = target
	_duration = maxf(0.001, duration)
	_timer = _duration


func _draw_summon(canvas: CanvasItem, offset: Vector2) -> void:
	var progress := get_progress()
	var travel_ratio := clampf(progress / SUMMON_TRAVEL_END, 0.0, 1.0)
	var orb_pos := _quadratic_bezier(
		_source,
		(_source + _target) * 0.5 + Vector2(0.0, -118.0),
		_target,
		_ease_out(travel_ratio)
	) + offset
	var source := _source + offset
	var target := _target + offset
	# Piece 1: a cached soft-glow projectile core.
	_blit(canvas, orb_pos, 22.0, COLOR_JADE, 0.86)
	_blit(canvas, orb_pos, 9.0, COLOR_CORE, 0.98)
	# Piece 2: stable trailing motes along the parabola (no live-index LOD).
	_draw_trail(canvas, source, orb_pos, progress, false)
	# Piece 3: landing flash + expanding resonance ring, followed by alpha-only
	# companion materialization in the body pass.
	if progress > SUMMON_TRAVEL_END:
		var landing := clampf((progress - SUMMON_TRAVEL_END) / (1.0 - SUMMON_TRAVEL_END), 0.0, 1.0)
		var flash_alpha := 1.0 - landing
		_blit(canvas, target, lerpf(34.0, 68.0, landing), COLOR_CORE, flash_alpha * 0.72)
		_blit(canvas, target, lerpf(24.0, 92.0, _ease_out(landing)), COLOR_TEAL, flash_alpha * 0.38)
		canvas.draw_arc(target, lerpf(18.0, 74.0, _ease_out(landing)), 0.0, TAU, 48, Color(COLOR_JADE.r, COLOR_JADE.g, COLOR_JADE.b, flash_alpha * 0.82), 2.4, true)


func _draw_stow(canvas: CanvasItem, offset: Vector2) -> void:
	var progress := get_progress()
	var source := _source + offset
	var target := _target + offset
	var travel_ratio := clampf((progress - STOW_TRAVEL_START) / (1.0 - STOW_TRAVEL_START), 0.0, 1.0)
	var stream_pos := _quadratic_bezier(
		source,
		(source + target) * 0.5 + Vector2(0.0, -54.0),
		target,
		_ease_in(travel_ratio)
	)
	# Light silhouette halo at the guardian, then a reversed stream into the player.
	var silhouette_alpha := 1.0 - _smoothstep(clampf(progress / 0.62, 0.0, 1.0))
	_blit(canvas, source, lerpf(58.0, 30.0, progress), COLOR_JADE, silhouette_alpha * 0.62)
	_draw_trail(canvas, source, stream_pos, progress, true)
	_blit(canvas, stream_pos, lerpf(18.0, 9.0, travel_ratio), COLOR_CORE, 0.92)
	_blit(canvas, stream_pos, lerpf(34.0, 15.0, travel_ratio), COLOR_TEAL, 0.55)
	if progress > 0.72:
		var arrival := clampf((progress - 0.72) / 0.28, 0.0, 1.0)
		var flash_alpha := sin(arrival * PI)
		_blit(canvas, target, lerpf(12.0, 42.0, arrival), COLOR_CORE, flash_alpha * 0.85)
		canvas.draw_arc(target, lerpf(8.0, 34.0, arrival), 0.0, TAU, 36, Color(COLOR_JADE.r, COLOR_JADE.g, COLOR_JADE.b, flash_alpha * 0.72), 2.0, true)


func _draw_trail(
	canvas: CanvasItem,
	start: Vector2,
	end: Vector2,
	progress: float,
	inward: bool
) -> void:
	for index in TRAIL_PIECES:
		var ratio := float(index + 1) / float(TRAIL_PIECES + 1)
		var eased := ratio * ratio if inward else 1.0 - pow(1.0 - ratio, 2.0)
		var pos := start.lerp(end, eased)
		var wave := sin(float(index) * 2.17 + progress * 14.0)
		var tangent := (end - start).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		pos += normal * wave * lerpf(10.0, 3.0, ratio)
		var alpha := (1.0 - ratio) * 0.62 + 0.14
		var radius := lerpf(11.0, 4.0, ratio)
		_blit(canvas, pos, radius, COLOR_JADE if index % 2 == 0 else COLOR_TEAL, alpha)


func _blit(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	var texture: Texture2D = SoftGlowTexture.get_texture(64)
	if texture == null or radius <= 0.0 or alpha <= 0.0:
		return
	var size := Vector2.ONE * radius * 2.0
	canvas.draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0)))


func _ensure_prewarmed() -> void:
	if not _prewarmed:
		prewarm()


func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var one_minus := 1.0 - clampf(t, 0.0, 1.0)
	return a * one_minus * one_minus + b * 2.0 * one_minus * t + c * t * t


func _smoothstep(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _ease_out(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


func _ease_in(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * clamped
