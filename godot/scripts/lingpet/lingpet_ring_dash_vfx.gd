extends RefCounted

# Procedural "Linkport" (링크포트) teleport VFX for the lingpet ring-dash passive.
#
# Two beats fire together the instant the companion blinks to intercept a ball:
#   * a DEPARTURE collapse at the spot it vanished from, and
#   * an ARRIVAL burst at the spot it reappears in front of the ball.
#
# The dash itself is an instant position snap (see lingpet_ring_dash_state.gd) --
# this module only adds the readable "전이" cue so the teleport does not look
# like the companion silently winking out and back. Drawn with layered
# translucent arcs / spokes / motes (no draw_set_transform, no blend-mode
# switching), so it composes exactly like the afterglow-leak VFX inside the same
# companion draw pass. See feedback_godot_draw_set_transform_trap.

# Beat lifetimes. Arrival outlives departure so the reappearing body is framed
# by an expanding portal shockwave instead of popping back in cold.
const DEPART_DURATION := 0.26
const ARRIVE_DURATION := 0.46

# All radii are anchored to the companion's real on-screen draw size
# (WALK_DRAW_SIZE ~= 82 px), NOT the 16 px hit radius -- otherwise the portal
# hides behind the sprite. See feedback_godot_companion_vfx_size_basis.
const BODY_DRAW_SIZE := 82.0
const ARRIVE_RING_MAX := BODY_DRAW_SIZE * 1.12    # ~92 px outer shockwave
const DEPART_RING_START := BODY_DRAW_SIZE * 0.70  # ~57 px implosion start
const SPOKE_COUNT := 12

const COLOR_CORE := Color(0.90, 0.99, 1.0)
const COLOR_RING := Color(0.38, 0.80, 1.0)
const COLOR_RING_HOT := Color(0.66, 0.94, 1.0)
const COLOR_ACCENT := Color(0.72, 0.64, 1.0)

var _depart_pos := Vector2.ZERO
var _arrive_pos := Vector2.ZERO
var _depart_timer := 0.0
var _arrive_timer := 0.0
var _spin := 0.0


func trigger(depart_pos: Vector2, arrive_pos: Vector2) -> void:
	_depart_pos = depart_pos
	_arrive_pos = arrive_pos
	_depart_timer = DEPART_DURATION
	_arrive_timer = ARRIVE_DURATION
	# Deterministic per-trigger spoke phase (no Math.random in the hot path);
	# varies the spoke fan so repeated dashes do not look rubber-stamped.
	_spin = fposmod(arrive_pos.x * 0.013 + arrive_pos.y * 0.021, TAU)


func advance(delta: float) -> void:
	var d := maxf(0.0, delta)
	_depart_timer = maxf(0.0, _depart_timer - d)
	_arrive_timer = maxf(0.0, _arrive_timer - d)


func has_visible_effects() -> bool:
	return _depart_timer > 0.0 or _arrive_timer > 0.0


func is_active_for_tests() -> bool:
	return has_visible_effects()


func reset() -> void:
	_depart_timer = 0.0
	_arrive_timer = 0.0
	_depart_pos = Vector2.ZERO
	_arrive_pos = Vector2.ZERO


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _depart_timer > 0.0:
		_draw_departure(canvas, _depart_pos + shake_offset)
	if _arrive_timer > 0.0:
		_draw_arrival(canvas, _arrive_pos + shake_offset)


func _draw_departure(canvas: CanvasItem, center: Vector2) -> void:
	var p := clampf(1.0 - _depart_timer / DEPART_DURATION, 0.0, 1.0)  # 0 -> 1
	var fade := 1.0 - p
	# Imploding double ring: the radius snaps inward toward the vanish point.
	for i in 2:
		var phase := clampf(p - float(i) * 0.12, 0.0, 1.0)
		var radius := lerpf(DEPART_RING_START, 3.0, _ease_in(phase))
		var ring_a := fade * (0.62 - float(i) * 0.16)
		if ring_a > 0.01:
			canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(COLOR_RING.r, COLOR_RING.g, COLOR_RING.b, ring_a), maxf(1.0, 3.0 - float(i)), true)
	# Inward streaks collapsing into the point.
	var outer := lerpf(DEPART_RING_START, 8.0, p)
	var inner := lerpf(DEPART_RING_START * 0.42, 1.0, p)
	var streak_a := fade * 0.7
	if streak_a > 0.01:
		for i in SPOKE_COUNT:
			var ang := _spin + TAU * float(i) / float(SPOKE_COUNT)
			var dir := Vector2(cos(ang), sin(ang))
			canvas.draw_line(center + dir * outer, center + dir * inner, Color(COLOR_RING_HOT.r, COLOR_RING_HOT.g, COLOR_RING_HOT.b, streak_a), 2.0, true)
	# Bright core that snaps shut as it leaves.
	var core_r := lerpf(16.0, 1.5, _ease_out(p))
	canvas.draw_circle(center, core_r, Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, fade * 0.85))


func _draw_arrival(canvas: CanvasItem, center: Vector2) -> void:
	var p := clampf(1.0 - _arrive_timer / ARRIVE_DURATION, 0.0, 1.0)  # 0 -> 1
	# White-out flash for the first slice so the reappearance visibly "pops".
	if p < 0.32:
		var flash := 1.0 - p / 0.32
		canvas.draw_circle(center, lerpf(10.0, 34.0, p / 0.32), Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, 0.85 * flash))
		canvas.draw_circle(center, lerpf(4.0, 16.0, p / 0.32), Color(1.0, 1.0, 1.0, 0.9 * flash))
	# Three expanding shockwave rings, each delayed, fading as they grow.
	for i in 3:
		var span := maxf(0.2, 1.0 - float(i) * 0.14)
		var phase := clampf((p - float(i) * 0.14) / span, 0.0, 1.0)
		if phase <= 0.0:
			continue
		var radius := ARRIVE_RING_MAX * _ease_out(phase)
		var ring_a := (1.0 - phase) * (0.80 - float(i) * 0.16)
		if ring_a <= 0.01:
			continue
		var col := COLOR_RING_HOT if i == 0 else COLOR_RING
		canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, ring_a), maxf(1.0, 4.0 - float(i)), true)
	# Radiating spokes that shoot outward and fade -- the loudest "전이" cue.
	var spoke_fade := clampf(1.0 - p / 0.7, 0.0, 1.0)
	if spoke_fade > 0.01:
		var inner := lerpf(6.0, ARRIVE_RING_MAX * 0.5, _ease_out(p))
		var outer := lerpf(18.0, ARRIVE_RING_MAX * 1.04, _ease_out(p))
		for i in SPOKE_COUNT:
			var ang := _spin + TAU * float(i) / float(SPOKE_COUNT)
			var dir := Vector2(cos(ang), sin(ang))
			var hot := COLOR_RING_HOT if i % 2 == 0 else COLOR_ACCENT
			canvas.draw_line(center + dir * inner, center + dir * outer, Color(hot.r, hot.g, hot.b, spoke_fade * 0.85), 2.0, true)
			# Sparkle mote riding the spoke tip.
			canvas.draw_circle(center + dir * outer, 2.2 * spoke_fade, Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, spoke_fade * 0.9))
	# Lingering soft halo so the burst eases out instead of cutting hard.
	var halo_a := clampf(1.0 - p, 0.0, 1.0) * 0.3
	if halo_a > 0.01:
		canvas.draw_arc(center, ARRIVE_RING_MAX * 0.5, 0.0, TAU, 40, Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, halo_a), 6.0, true)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


func _ease_in(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c
