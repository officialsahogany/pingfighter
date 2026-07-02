extends RefCounted

# High-quality procedural "ghost blink" VFX for the rabi free-flight companion.
#
# rabi is a ghost: it fades in at a spot, drifts, fades out IN PLACE, waits, then
# reappears elsewhere (lingpet_companion_motion_state free-flight cycle). This module
# adds the "퐁" pop so each appear/vanish reads as a real spirit poof.
#
# The companion is an IMMEDIATE-DRAW actor (no node fx_host / GPUParticles / Tween --
# see project_lingpet_acquire_portal_modular_vfx), so the "고퀄 조합" is delivered the
# immediate-draw way, the same class as the afterglow-leak VFX:
#   * TEXTURE pieces  -> a cached soft radial-falloff sprite (SoftGlowTexture) reused as
#                        the glow backplate, the core flash, and every wisp/mote blob,
#                        so edges are feathered instead of hard draw_circle discs (the
#                        falloff is the "baked shader" — feedback_modular_vfx_3piece).
#   * PARTICLES       -> a bounded wisp simulation: outward buoyant scatter on appear,
#                        inward implosion on vanish, each with velocity decay + fade +
#                        size envelope + spin.
#   * TWEEN motion    -> eased (overshoot pop / ease-in implode) envelopes drive the
#                        glow scale, the shockwave ring, and the core flash.
# Layered translucent blits / arcs only, no draw_set_transform, no blend-mode switching,
# so it composes inside the same companion draw pass. See feedback_godot_draw_set_transform_trap.

const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

const APPEAR_DURATION := 0.44
const VANISH_DURATION := 0.38

# Radii anchored to the companion's on-screen draw size (~72-82 px), NOT the 16 px hit
# radius, or the poof hides behind the sprite. See feedback_godot_companion_vfx_size_basis.
const POP_RING_MAX := 78.0
const GLOW_BACKPLATE_MAX := 60.0
const WISP_COUNT := 12
const GLOW_TEX_SIZE := 64
const WISP_GRAVITY := -46.0  # negative = buoyant rise (ghosts float up as they fade)

# Pale green-white "spirit" palette (matches the companion aura tone).
const COLOR_CORE := Color(0.96, 1.0, 0.97)
const COLOR_GLOW := Color(0.42, 1.0, 0.74)
const COLOR_WISP := Color(0.66, 1.0, 0.82)
const COLOR_RING := Color(0.56, 1.0, 0.82)

var _appear_pos := Vector2.ZERO
var _vanish_pos := Vector2.ZERO
var _appear_timer := 0.0
var _vanish_timer := 0.0
var _appear_spin := 0.0
var _vanish_spin := 0.0
var _wisps: Array = []
var _prewarmed := false
var _last_visible := true


func prewarm() -> void:
	_ensure_prewarmed()


func trigger_appear(pos: Vector2) -> void:
	_ensure_prewarmed()
	_appear_pos = pos
	_appear_timer = APPEAR_DURATION
	# Deterministic per-trigger phase (no Math.random in the hot path).
	_appear_spin = fposmod(pos.x * 0.017 + pos.y * 0.023, TAU)
	_spawn_wisps(pos, _appear_spin, APPEAR_DURATION, false)


func trigger_vanish(pos: Vector2) -> void:
	_ensure_prewarmed()
	_vanish_pos = pos
	_vanish_timer = VANISH_DURATION
	_vanish_spin = fposmod(pos.x * 0.019 + pos.y * 0.013, TAU)
	_spawn_wisps(pos, _vanish_spin, VANISH_DURATION, true)


func sync_visibility(is_free_flight_companion: bool, motion_visible: bool, pos: Vector2) -> void:
	if is_free_flight_companion and motion_visible != _last_visible:
		if motion_visible:
			trigger_appear(pos)
		else:
			trigger_vanish(pos)
	_last_visible = motion_visible


func advance(delta: float) -> void:
	var d := maxf(0.0, delta)
	_appear_timer = maxf(0.0, _appear_timer - d)
	_vanish_timer = maxf(0.0, _vanish_timer - d)
	if _wisps.is_empty() or d <= 0.0:
		return
	for i in range(_wisps.size() - 1, -1, -1):
		var w: Dictionary = _wisps[i]
		var life: float = float(w["life"]) - d
		if life <= 0.0:
			_wisps.remove_at(i)
			continue
		var vel: Vector2 = w["vel"]
		if bool(w.get("implode", false)):
			# Inward implosion: ease toward the center and accelerate as it converges.
			var to_center: Vector2 = (w["center"] as Vector2) - (w["pos"] as Vector2)
			vel = vel.lerp(to_center * 6.0, clampf(d * 7.0, 0.0, 1.0))
		else:
			vel.y += WISP_GRAVITY * d        # buoyant rise
			vel *= maxf(0.0, 1.0 - d * 2.4)  # outward scatter decays
		w["vel"] = vel
		w["pos"] = (w["pos"] as Vector2) + vel * d
		w["spin"] = float(w["spin"]) + float(w["spin_rate"]) * d
		w["life"] = life
		_wisps[i] = w


func has_visible_effects() -> bool:
	return _appear_timer > 0.0 or _vanish_timer > 0.0 or not _wisps.is_empty()


func is_active_for_tests() -> bool:
	return has_visible_effects()


func reset() -> void:
	_appear_timer = 0.0
	_vanish_timer = 0.0
	_appear_pos = Vector2.ZERO
	_vanish_pos = Vector2.ZERO
	_wisps.clear()
	_last_visible = true


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	# Floor pools-equivalent ordering: soft glows/rings first, sharp motes on top.
	if _vanish_timer > 0.0:
		_draw_vanish(canvas, _vanish_pos + shake_offset)
	if _appear_timer > 0.0:
		_draw_appear(canvas, _appear_pos + shake_offset)
	_draw_wisps(canvas, shake_offset)


func _spawn_wisps(pos: Vector2, spin: float, duration: float, implode: bool) -> void:
	for i in WISP_COUNT:
		var ang: float = spin + TAU * float(i) / float(WISP_COUNT)
		var dir := Vector2(cos(ang), sin(ang))
		# Index-derived deterministic variation (no Math.random in the hot path).
		var var01: float = fposmod(float(i) * 0.61803, 1.0)
		var size: float = lerpf(5.0, 11.0, var01)
		var life: float = duration * lerpf(0.7, 1.05, fposmod(float(i) * 0.371, 1.0))
		var wisp := {
			"life": life,
			"max_life": life,
			"size": size,
			"spin": ang,
			"spin_rate": lerpf(-2.2, 2.2, var01),
			"tint": COLOR_WISP if (i % 2 == 0) else COLOR_CORE,
			"implode": implode,
			"center": pos,
		}
		if implode:
			# Start out on a ring and rush inward to the vanish point.
			var start_r: float = lerpf(POP_RING_MAX * 0.55, POP_RING_MAX * 0.92, var01)
			wisp["pos"] = pos + dir * start_r
			wisp["vel"] = -dir * lerpf(120.0, 200.0, var01)
		else:
			# Burst outward (with a buoyant upward bias) from the appear point.
			wisp["pos"] = pos + dir * 6.0
			wisp["vel"] = (dir + Vector2(0.0, -0.35)).normalized() * lerpf(150.0, 250.0, var01)
		_wisps.append(wisp)
	# Bound the pool so overlapping appear+vanish bursts can never grow unbounded.
	while _wisps.size() > WISP_COUNT * 2:
		_wisps.remove_at(0)


func _draw_appear(canvas: CanvasItem, center: Vector2) -> void:
	var p := clampf(1.0 - _appear_timer / APPEAR_DURATION, 0.0, 1.0)  # 0 -> 1
	var tex := _glow_texture()
	# TWEEN: overshoot "퐁" pop -- the soft glow backplate snaps up past full then settles.
	var pop := _ease_overshoot(clampf(p / 0.5, 0.0, 1.0))
	var glow_r := GLOW_BACKPLATE_MAX * pop
	var glow_a := (1.0 - p) * 0.6
	_blit(canvas, tex, center, glow_r, glow_r, COLOR_GLOW, glow_a)
	_blit(canvas, tex, center, glow_r * 0.55, glow_r * 0.55, COLOR_CORE, glow_a * 0.9)
	# White-out flash for the first slice so the entrance visibly snaps.
	if p < 0.30:
		var flash := 1.0 - p / 0.30
		_blit(canvas, tex, center, lerpf(10.0, 30.0, p / 0.30), lerpf(10.0, 30.0, p / 0.30), Color(1.0, 1.0, 1.0), 0.92 * flash)
	# Expanding feathered shockwave ring (soft textured halo + a crisp arc edge).
	var ring_phase := _ease_out(p)
	var ring_r := POP_RING_MAX * ring_phase
	var ring_a := (1.0 - p) * 0.5
	if ring_a > 0.01:
		_blit(canvas, tex, center, ring_r, ring_r * 0.7, COLOR_RING, ring_a * 0.4)
		canvas.draw_arc(center, ring_r, 0.0, TAU, 48, Color(COLOR_RING.r, COLOR_RING.g, COLOR_RING.b, ring_a), 2.2, true)


func _draw_vanish(canvas: CanvasItem, center: Vector2) -> void:
	var p := clampf(1.0 - _vanish_timer / VANISH_DURATION, 0.0, 1.0)  # 0 -> 1
	var fade := 1.0 - p
	var tex := _glow_texture()
	# TWEEN: ease-in implosion -- the soft halo snaps inward to the vanish point.
	var imp := _ease_in(p)
	var halo_r := lerpf(POP_RING_MAX * 0.7, 4.0, imp)
	if fade > 0.01:
		_blit(canvas, tex, center, halo_r, halo_r * 0.78, COLOR_GLOW, fade * 0.5)
		canvas.draw_arc(center, halo_r, 0.0, TAU, 40, Color(COLOR_RING.r, COLOR_RING.g, COLOR_RING.b, fade * 0.5), 2.0, true)
	# A quick core poof that flares then snaps shut as the spirit leaves.
	var core_r := lerpf(5.0, 20.0, _ease_out(p)) * fade + 1.0
	_blit(canvas, tex, center, core_r, core_r, COLOR_CORE, fade * 0.82)


func _draw_wisps(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if _wisps.is_empty():
		return
	var tex := _glow_texture()
	if tex == null:
		return
	for w in _wisps:
		var life_t: float = clampf(float(w["life"]) / maxf(0.01, float(w["max_life"])), 0.0, 1.0)
		var a: float = clampf(life_t * 1.3, 0.0, 1.0) * 0.85
		if a <= 0.02:
			continue
		var pos: Vector2 = (w["pos"] as Vector2) + shake_offset
		# Elongate along the spin direction so each blob reads as a wisp, not a dot.
		var s: float = float(w["size"]) * (0.6 + 0.4 * life_t)
		var spin: float = float(w["spin"])
		var stretch := Vector2(cos(spin), sin(spin))
		var rx: float = s * (1.0 + 0.5 * absf(stretch.x))
		var ry: float = s * (1.0 + 0.5 * absf(stretch.y))
		var tint: Color = w["tint"]
		_blit(canvas, tex, pos, rx, ry, tint, a)


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


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


func _ease_in(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c


func _ease_overshoot(t: float) -> float:
	# Back-ease overshoot for the "퐁" pop (peaks slightly past 1.0 then settles).
	var c := clampf(t, 0.0, 1.0)
	var s := 1.70158
	var c1 := c - 1.0
	return 1.0 + (s + 1.0) * pow(c1, 3.0) + s * pow(c1, 2.0)
