extends RefCounted

# Procedural "digital absorb" VFX for the lingpet_egg active item.
#
# When a SECOND egg (deployed while a companion is already on field, the coexisting
# incubator path) hatches, the new pet is NOT placed as a companion -- it dissolves
# into white digital code and is absorbed into the player as energy, then registered
# to a collection battle slot. This module delivers that one-shot
# dissolve -> converge -> absorb burst the immediate-draw way (cached soft-glow blits +
# small square "code" pixels), the same class as the ghost-blink / afterglow VFX (no
# node fx_host / GPUParticles / Tween). See lingpet_ghost_blink_vfx for the pattern and
# the hot-path perf rules (cached glow texture, bounded particle pool, no per-frame
# Surface allocation).

const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

const DURATION := 0.72
const MOTE_COUNT := 16
const CODE_COUNT := 10  # of MOTE_COUNT, the first CODE_COUNT render as digital squares
const GLOW_TEX_SIZE := 64
const BURST_RADIUS := 30.0

# White / cyan "digital energy" palette.
const COLOR_CORE := Color(0.98, 1.0, 1.0)
const COLOR_GLOW := Color(0.62, 0.95, 1.0)
const COLOR_CODE := Color(0.70, 1.0, 0.96)

var _origin := Vector2.ZERO
var _target := Vector2.ZERO
var _timer := 0.0
var _motes: Array = []
var _prewarmed := false


func prewarm() -> void:
	_ensure_prewarmed()


func trigger(origin: Vector2, target: Vector2) -> void:
	_ensure_prewarmed()
	_origin = origin
	_target = target
	_timer = DURATION
	_motes.clear()
	# Deterministic per-trigger phase (no Math.random in the hot path).
	var spin := fposmod(origin.x * 0.017 + origin.y * 0.021, TAU)
	for i in MOTE_COUNT:
		var ang := spin + TAU * float(i) / float(MOTE_COUNT)
		var dir := Vector2(cos(ang), sin(ang))
		var var01 := fposmod(float(i) * 0.61803, 1.0)
		_motes.append({
			"pos": origin + dir * lerpf(4.0, BURST_RADIUS, var01),
			"vel": dir * lerpf(40.0, 120.0, var01),
			"delay": lerpf(0.0, 0.18, fposmod(float(i) * 0.371, 1.0)),
			"size": lerpf(3.0, 6.5, var01),
			"spin": ang,
			"code": i < CODE_COUNT,
			"seed": var01,
		})


func advance(delta: float, target: Vector2 = Vector2.ZERO) -> void:
	var d := maxf(0.0, delta)
	if target != Vector2.ZERO:
		_target = target
	_timer = maxf(0.0, _timer - d)
	if _motes.is_empty() or d <= 0.0:
		return
	var elapsed := DURATION - _timer
	for i in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		var delay := float(m.get("delay", 0.0))
		if elapsed < delay:
			continue
		# After a brief outward scatter, every mote accelerates toward the player to
		# read as "absorbed as energy".
		var to_target: Vector2 = _target - (m["pos"] as Vector2)
		var converge := clampf((elapsed - delay) / maxf(0.01, DURATION - delay), 0.0, 1.0)
		var vel: Vector2 = m["vel"]
		vel = vel.lerp(to_target * lerpf(3.0, 9.0, converge), clampf(d * (4.0 + converge * 8.0), 0.0, 1.0))
		m["vel"] = vel
		m["pos"] = (m["pos"] as Vector2) + vel * d
		m["spin"] = float(m["spin"]) + d * 9.0
		_motes[i] = m
		# Absorbed: retire a mote once it reaches the player.
		if (m["pos"] as Vector2).distance_to(_target) < 10.0 and converge > 0.4:
			_motes.remove_at(i)


func has_visible_effects() -> bool:
	return _timer > 0.0 or not _motes.is_empty()


func is_active_for_tests() -> bool:
	return has_visible_effects()


func reset() -> void:
	_timer = 0.0
	_motes.clear()
	_origin = Vector2.ZERO
	_target = Vector2.ZERO


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not has_visible_effects():
		return
	var p := clampf(1.0 - _timer / DURATION, 0.0, 1.0)
	var tex := _glow_texture()
	# Early white dissolve flash at the egg origin (the egg "breaks into code").
	if p < 0.35 and tex != null:
		var flash := 1.0 - p / 0.35
		var fr := lerpf(14.0, 40.0, p / 0.35)
		_blit(canvas, tex, _origin + shake_offset, fr, fr, COLOR_GLOW, 0.55 * flash)
		_blit(canvas, tex, _origin + shake_offset, fr * 0.5, fr * 0.5, COLOR_CORE, 0.85 * flash)
	# Converging motes + digital "code" squares.
	for m in _motes:
		var pos: Vector2 = (m["pos"] as Vector2) + shake_offset
		var dist := pos.distance_to(_target + shake_offset)
		var a := clampf(dist / 120.0, 0.15, 1.0) * 0.9
		var s := float(m["size"])
		if bool(m.get("code", false)):
			# Flickering axis-aligned pixel -> "디지털 코드" read.
			var flick := 0.6 + 0.4 * sin((p + float(m["seed"])) * 30.0)
			var hs := s * (0.7 + 0.3 * flick)
			canvas.draw_rect(
				Rect2(pos - Vector2(hs, hs), Vector2(hs * 2.0, hs * 2.0)),
				Color(COLOR_CODE.r, COLOR_CODE.g, COLOR_CODE.b, a * flick),
				true
			)
		elif tex != null:
			_blit(canvas, tex, pos, s, s, COLOR_CORE, a)
	# Absorb glow blooming at the player as motes arrive.
	if p > 0.4 and tex != null:
		var ab := (p - 0.4) / 0.6
		var ar := lerpf(8.0, 26.0, ab) * (1.0 - ab * 0.5)
		_blit(canvas, tex, _target + shake_offset, ar, ar, COLOR_GLOW, (1.0 - ab) * 0.6)


func _blit(canvas: CanvasItem, tex: Texture2D, center: Vector2, rx: float, ry: float, color: Color, a: float) -> void:
	if tex == null or rx <= 0.5 or ry <= 0.5 or a <= 0.0:
		return
	canvas.draw_texture_rect(
		tex,
		Rect2(center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)),
		false,
		Color(color.r, color.g, color.b, clampf(a, 0.0, 1.0))
	)


func _glow_texture() -> Texture2D:
	return SoftGlowTexture.get_texture(GLOW_TEX_SIZE)


func _ensure_prewarmed() -> void:
	if _prewarmed:
		return
	SoftGlowTexture.get_texture(GLOW_TEX_SIZE)
	_prewarmed = true
