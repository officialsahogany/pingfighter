extends RefCounted

const LingpetBoneBarrierPayloadFactory := preload("res://scripts/lingpet/lingpet_bone_barrier_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GAME_LEFT := 0.0
const GAME_RIGHT := FIELD_WIDTH
# Widths are the original Necro BoneBarrier values scaled to 60% (-40%):
# original [120, 140, 160, 180, 200] -> [72, 84, 96, 108, 120].
const BARRIER_WIDTH_BY_LEVEL := [72.0, 84.0, 96.0, 108.0, 120.0]
const BONUS_BARRIER_CHANCE_BY_LEVEL := [0.0, 0.0, 0.20, 0.30, 0.40]
const BARRIER_WIDTH := 72.0
const BARRIER_HEIGHT := 12.0
const BUILD_TIME := 3.0
const DEATH_DURATION := 0.6
const MIN_SPACING := 110.0
const BOTTOM_BARRIER_Y := 738.0
const TOP_BARRIER_Y := 8.0
const PARTICLE_MAX := 96
const MAX_ACTIVE_BARRIERS := 8
const REFLECT_SPEED_MULTIPLIER := 1.05
const HIT_OFFSET_VEL_SCALE := 0.03
const NO_FORCED_X := -999999.0

# Warm ivory bone palette ported 1:1 from the original Necro BoneBarrier
# (downtown/hero_skills.py). Green (SOUL_COLOR / necro_glow) is reserved for
# spike poison wisps and the shatter shockwave only.
const BONE_COLOR := Color(0.824, 0.784, 0.686, 1.0)    # bone_c  (210, 200, 175)
const BONE_DARK := Color(0.627, 0.588, 0.471, 1.0)     # bone_dk (160, 150, 120)
const BONE_HILITE := Color(0.902, 0.882, 0.784, 1.0)   # bone_br (230, 225, 200)
const BONE_SHADOW := Color(0.471, 0.431, 0.333, 1.0)   # bone_sh (120, 110,  85)
const BONE_CREAM := Color(0.922, 0.894, 0.824, 1.0)    # bone_cream (235, 228, 210)
const SPIKE_COLOR := Color(0.784, 0.745, 0.627, 1.0)   # spike_c (200, 190, 160)
const SPIKE_HILITE := Color(0.882, 0.855, 0.765, 1.0)  # spike_br (225, 218, 195)
const SOUL_COLOR := Color(0.314, 1.0, 0.471, 1.0)      # necro_glow (80, 255, 120)
const CRACK_COLOR := Color(0.471, 0.431, 0.333, 1.0)   # micro-cracks (= bone_sh)

var _barriers: Array[Dictionary] = []
var _dying_barriers: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _active := false
var _active_skill_level := 1
var _barrier_width := BARRIER_WIDTH
var _bonus_barrier_chance := 0.0
var _next_barrier_id := 1
var _build_count := 0
var _bonus_barrier_count := 0
var _reflect_count := 0
var _build_break_count := 0
var _last_hit_pos := Vector2.ZERO
var _last_reflect_vel := Vector2.ZERO
var _last_registry: Object = null
var _forced_x_values_for_tests: Array[float] = []
var _bonus_barrier_rolls_for_tests: Array[float] = []


func reset() -> void:
	_barriers.clear()
	_dying_barriers.clear()
	_particles.clear()
	_active = false
	_active_skill_level = 1
	_barrier_width = BARRIER_WIDTH
	_bonus_barrier_chance = 0.0
	_next_barrier_id = 1
	_build_count = 0
	_bonus_barrier_count = 0
	_reflect_count = 0
	_build_break_count = 0
	_last_hit_pos = Vector2.ZERO
	_last_reflect_vel = Vector2.ZERO
	_forced_x_values_for_tests.clear()
	_bonus_barrier_rolls_for_tests.clear()


func cancel(_owner: Object = null, registry: Object = null) -> void:
	if registry != null:
		_last_registry = registry
	reset()


# Round-boundary reset: installed barriers persist into the next round
# (matches the original Necro BoneBarrier reset_for_new_round), so only the
# transient shatter fragments and spark particles are cleared. A full reset()
# (companion change / hatch / new battle) still wipes everything.
func reset_round() -> void:
	_dying_barriers.clear()
	_particles.clear()
	_active = not _barriers.is_empty()


func prewarm() -> void:
	pass


func launch(_origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
	var ctx_registry: Variant = launch_context.get("registry", null)
	if typeof(ctx_registry) == TYPE_OBJECT and is_instance_valid(ctx_registry):
		_last_registry = ctx_registry as Object
	_active = true
	_sync_level_values(launch_context)
	var caster_is_top := bool(launch_context.get("caster_is_top", false))
	var y := _get_context_float(launch_context, "barrier_y", TOP_BARRIER_Y if caster_is_top else BOTTOM_BARRIER_Y)
	y = clampf(y, 0.0, FIELD_HEIGHT - BARRIER_HEIGHT)
	var install_count := _get_install_count_for_launch(launch_context)
	for index in range(install_count):
		var x := _consume_forced_barrier_x()
		if x <= NO_FORCED_X * 0.5 and index == 0:
			x = _get_context_float(launch_context, "barrier_x", NO_FORCED_X)
		if x <= NO_FORCED_X * 0.5:
			x = _choose_barrier_x(_barrier_width)
		x = clampf(x, GAME_LEFT + 10.0, GAME_RIGHT - _barrier_width - 10.0)
		var barrier := LingpetBoneBarrierPayloadFactory.build_barrier(
			_next_barrier_id,
			Vector2(x, y),
			_barrier_width,
			BARRIER_HEIGHT,
			caster_is_top
		)
		_next_barrier_id += 1
		_build_count += 1
		if index > 0:
			_bonus_barrier_count += 1
		_barriers.append(barrier)
		_spawn_build_particles(Vector2(x + _barrier_width * 0.5, y + BARRIER_HEIGHT * 0.5))
	_limit_barriers()
	return true


func update(delta: float, _owner: Object = null, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if registry != null:
		_last_registry = registry
	var safe_delta := maxf(0.0, delta)
	_update_particles(safe_delta)
	_update_dying_barriers(safe_delta)
	_update_barriers(safe_delta)
	_active = not _barriers.is_empty()


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, shake_offset)
	for dying in _dying_barriers:
		_draw_dying_barrier(canvas, dying, shake_offset)
	for barrier in _barriers:
		_draw_barrier(canvas, barrier, shake_offset)


func has_visible_effects() -> bool:
	return _active or not _barriers.is_empty() or not _dying_barriers.is_empty() or not _particles.is_empty()


func is_active() -> bool:
	return not _barriers.is_empty()


func get_ball_collision_context() -> Dictionary:
	var entries: Array[Dictionary] = []
	for barrier in _barriers:
		entries.append({
			"id": int(barrier.get("id", 0)),
			"rect": _get_barrier_rect(barrier),
			"built": bool(barrier.get("built", false)),
			"reflect_speed_mult": REFLECT_SPEED_MULTIPLIER,
			"hit_offset_vel_scale": HIT_OFFSET_VEL_SCALE,
		})
	return {
		"lingpet_bone_barrier_active": not entries.is_empty(),
		"lingpet_bone_barrier_barriers": entries,
	}


func notify_ball_collision(
	barrier_id: int,
	impact_pos: Vector2,
	next_ball_vel: Vector2,
	built: bool = true,
	registry: Object = null
) -> bool:
	var index := _find_barrier_index(barrier_id)
	if index < 0:
		return false
	var source_barrier := _barriers[index]
	_break_barrier_at_index(index, impact_pos, next_ball_vel, built, registry if registry != null else _last_registry, source_barrier)
	if built:
		_last_reflect_vel = next_ball_vel
	return true


func get_barrier_count_for_tests() -> int:
	return _barriers.size()


func get_reflect_count_for_tests() -> int:
	return _reflect_count


func get_build_break_count_for_tests() -> int:
	return _build_break_count


func get_snapshot() -> Dictionary:
	return {
		"bone_barrier_active": _active,
		"bone_barrier_active_skill_level": _active_skill_level,
		"bone_barrier_barrier_count": _barriers.size(),
		"bone_barrier_barrier_ids": _get_barrier_ids(),
		"bone_barrier_barrier_positions": _get_barrier_positions(),
		"bone_barrier_built_count": _get_built_count(),
		"bone_barrier_dying_count": _dying_barriers.size(),
		"bone_barrier_particle_count": _particles.size(),
		"bone_barrier_build_count": _build_count,
		"bone_barrier_bonus_barrier_count": _bonus_barrier_count,
		"bone_barrier_reflect_count": _reflect_count,
		"bone_barrier_build_break_count": _build_break_count,
		"bone_barrier_last_hit_pos": _last_hit_pos,
		"bone_barrier_last_reflect_vel": _last_reflect_vel,
		"bone_barrier_width": _barrier_width,
		"bone_barrier_widths": _get_barrier_widths(),
		"bone_barrier_height": BARRIER_HEIGHT,
		"bone_barrier_build_time": BUILD_TIME,
		"bone_barrier_death_duration": DEATH_DURATION,
		"bone_barrier_reflect_speed_mult": REFLECT_SPEED_MULTIPLIER,
		"bone_barrier_bonus_chance": _bonus_barrier_chance,
		"bone_barrier_bonus_chance_pct": _bonus_barrier_chance * 100.0,
	}


func set_barrier_x_values_for_tests(values: Array) -> void:
	_forced_x_values_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_forced_x_values_for_tests.append(float(value))


func set_bonus_barrier_rolls_for_tests(values: Array) -> void:
	_bonus_barrier_rolls_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_bonus_barrier_rolls_for_tests.append(float(value))


func _update_barriers(delta: float) -> void:
	if _barriers.is_empty():
		return
	for barrier in _barriers:
		var timer := float(barrier.get("timer", 0.0)) + delta
		barrier["timer"] = timer
		if timer >= BUILD_TIME:
			barrier["built"] = true


func _break_barrier_at_index(
	index: int,
	impact_pos: Vector2,
	next_ball_vel: Vector2,
	built: bool,
	registry: Object,
	source_barrier: Dictionary
) -> void:
	if index < 0 or index >= _barriers.size():
		return
	_barriers.remove_at(index)
	var fragments: Array[Dictionary] = []
	var barrier_rect := _get_barrier_rect(source_barrier)
	for fragment_index in range(18):
		fragments.append(LingpetBoneBarrierPayloadFactory.build_bone_fragment(barrier_rect.get_center(), next_ball_vel, fragment_index))
	_dying_barriers.append({
		"timer": 0.0,
		"impact_pos": impact_pos,
		"fragments": fragments,
		"built": built,
	})
	_last_hit_pos = impact_pos
	if built:
		_reflect_count += 1
		_spawn_hit_particles(impact_pos, next_ball_vel)
		_play_audio(registry, ["play_lingpet_bone_barrier_break", "play_boomerang_break", "play_active_item"])
	else:
		_build_break_count += 1
		_spawn_hit_particles(impact_pos, next_ball_vel)
		_play_audio(registry, ["play_lingpet_bone_barrier_build_break", "play_shuriken_hit", "play_active_item"])


func _update_dying_barriers(delta: float) -> void:
	if _dying_barriers.is_empty():
		return
	var kept: Array[Dictionary] = []
	for dying in _dying_barriers:
		var timer := float(dying.get("timer", 0.0)) + delta
		var fragments: Array = dying.get("fragments", []) as Array
		for fragment in fragments:
			var pos := _get_dict_vector2(fragment, "pos", Vector2.ZERO)
			var vel := _get_dict_vector2(fragment, "vel", Vector2.ZERO)
			pos += vel * delta
			vel.y += 390.0 * delta
			fragment["pos"] = pos
			fragment["vel"] = vel
			fragment["rotation"] = float(fragment.get("rotation", 0.0)) + float(fragment.get("rotation_speed", 0.0)) * delta
		dying["timer"] = timer
		if timer <= DEATH_DURATION:
			kept.append(dying)
	_dying_barriers = kept


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var kept: Array[Dictionary] = []
	for particle in _particles:
		var age := float(particle.get("age", 0.0)) + delta
		var life := float(particle.get("life", 0.0))
		if age >= life:
			continue
		var pos := _get_dict_vector2(particle, "pos", Vector2.ZERO)
		var vel := _get_dict_vector2(particle, "vel", Vector2.ZERO)
		pos += vel * delta
		vel.y += 120.0 * delta
		particle["age"] = age
		particle["pos"] = pos
		particle["vel"] = vel
		kept.append(particle)
	_particles = kept


func _draw_barrier(canvas: CanvasItem, barrier: Dictionary, shake_offset: Vector2) -> void:
	var rect := _get_barrier_rect(barrier)
	rect.position += shake_offset
	var progress := clampf(float(barrier.get("timer", 0.0)) / BUILD_TIME, 0.0, 1.0)
	if bool(barrier.get("built", false)):
		_draw_built_barrier(canvas, barrier, rect, progress)
	else:
		_draw_building_barrier(canvas, barrier, shake_offset, progress)


func _draw_building_barrier(canvas: CanvasItem, barrier: Dictionary, shake_offset: Vector2, _progress: float) -> void:
	var segments: Array = barrier.get("bone_segments", []) as Array
	var build_timer := float(barrier.get("timer", 0.0))
	for segment in segments:
		var delay := float(segment.get("delay", 0.0))
		var adjusted := _get_build_segment_adjusted_progress(build_timer, delay)
		if adjusted <= 0.001:
			continue
		var eased := 1.0 - pow(1.0 - adjusted, 3.0)
		var start_pos := _get_dict_vector2(segment, "start_pos", Vector2.ZERO)
		var final_pos := _get_dict_vector2(segment, "final_pos", Vector2.ZERO)
		var pos := start_pos.lerp(final_pos, eased) + shake_offset
		var rotation := lerpf(float(segment.get("rotation_start", 0.0)), float(segment.get("rotation_end", 0.0)), eased)
		var alpha := clampf(adjusted * 2.5, 0.0, 1.0)
		_draw_bone_segment(canvas, pos, float(segment.get("length", 10.0)), rotation, Color(BONE_COLOR.r, BONE_COLOR.g, BONE_COLOR.b, alpha))


static func _get_build_segment_adjusted_progress(build_timer: float, delay: float) -> float:
	var build_progress := clampf(build_timer / BUILD_TIME, 0.0, 1.0)
	var delay_norm := clampf(delay / BUILD_TIME, 0.0, 0.99)
	return clampf((build_progress - delay_norm) / maxf(0.01, 1.0 - delay_norm), 0.0, 1.0)


func _draw_built_barrier(canvas: CanvasItem, barrier: Dictionary, rect: Rect2, _progress: float) -> void:
	# Animation clock is the barrier's own build timer (keeps advancing post-build),
	# so subtle pulses freeze with the skill tick instead of free-running on wall clock.
	var t := float(barrier.get("timer", 0.0))
	var phase := float(barrier.get("phase", 0.0))
	var is_top := bool(barrier.get("caster_is_top", false))
	var w := rect.size.x
	var h := rect.size.y
	var center_y := rect.position.y + h * 0.5
	# Drop shadow.
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size), BONE_SHADOW, true)
	# 3-layer gradient body: dark base -> bone mid -> cream inner.
	canvas.draw_rect(rect, BONE_DARK, true)
	canvas.draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 2.0)), BONE_COLOR, true)
	var inner_h := maxf(1.0, h - 4.0)
	canvas.draw_rect(Rect2(rect.position + Vector2(3.0, (h - inner_h) * 0.5), Vector2(maxf(1.0, w - 6.0), inner_h)), BONE_CREAM, true)
	# Bone segment texture: separator lines, joint bumps, marrow, micro-cracks.
	var seg_count := maxi(1, int(w / 10.0))
	for i in range(seg_count):
		var lx := rect.position.x + w * 0.5
		if seg_count > 1:
			lx = rect.position.x + 5.0 + float(i) * (w - 10.0) / float(seg_count - 1)
		canvas.draw_line(Vector2(lx, rect.position.y + 1.0), Vector2(lx, rect.end.y - 1.0), BONE_DARK, 1.0)
		canvas.draw_circle(Vector2(lx, center_y), 3.0, BONE_HILITE)
		canvas.draw_arc(Vector2(lx, center_y), 3.0, 0.0, TAU, 12, BONE_COLOR, 1.0, true)
		canvas.draw_circle(Vector2(lx, center_y), 1.0, BONE_DARK)
		if i < seg_count - 1:
			var next_lx := rect.position.x + 5.0 + float(i + 1) * (w - 10.0) / float(maxi(1, seg_count - 1))
			var marrow_a := 0.16 * (0.8 + 0.2 * sin(t * 2.0 + float(i) * 0.8))
			canvas.draw_line(Vector2(lx + 3.0, center_y), Vector2(next_lx - 3.0, center_y), Color(BONE_CREAM.r, BONE_CREAM.g, BONE_CREAM.b, marrow_a), 1.0)
		if i % 3 == 1:
			var crack_y := rect.position.y + 2.0
			canvas.draw_line(Vector2(lx + 2.0, crack_y), Vector2(lx + 4.0, crack_y + 3.0), CRACK_COLOR, 1.0)
	# Sharp spikes: shadow + body + bright facet + ridge, with a green poison wisp.
	var spike_heights: Array = barrier.get("spike_heights", []) as Array
	var num_spikes := spike_heights.size() if not spike_heights.is_empty() else maxi(1, int(w / 14.0))
	var dir := 1.0 if is_top else -1.0
	var base_y := rect.end.y if is_top else rect.position.y
	for i in range(num_spikes):
		var sx := rect.position.x + (float(i) + 0.5) * w / float(num_spikes)
		var sh := float(spike_heights[i]) if i < spike_heights.size() else 7.0
		var wobble := sin(t * 4.0 + float(i) * 1.5)
		var tip_y := base_y + dir * (sh + wobble)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 3.0, base_y + dir), Vector2(sx + 1.0, tip_y + dir), Vector2(sx + 4.0, base_y + dir),
		]), BONE_SHADOW)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 3.0, base_y), Vector2(sx, tip_y), Vector2(sx + 3.0, base_y),
		]), SPIKE_COLOR)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 2.0, base_y), Vector2(sx, tip_y), Vector2(sx, base_y),
		]), SPIKE_HILITE)
		canvas.draw_line(Vector2(sx, base_y), Vector2(sx, tip_y), BONE_DARK, 1.0)
		var poison := sin(t * 5.0 + float(i) * 2.3 + phase)
		if poison > 0.6:
			var pa := (poison - 0.6) / 0.4 * 0.55
			canvas.draw_circle(Vector2(sx, tip_y + dir * 2.0), 1.4, Color(SOUL_COLOR.r, SOUL_COLOR.g, SOUL_COLOR.b, pa))
	# Top-edge highlight + bottom-edge shadow lines.
	canvas.draw_line(Vector2(rect.position.x + 3.0, rect.position.y + 1.0), Vector2(rect.end.x - 3.0, rect.position.y + 1.0), BONE_HILITE, 1.0)
	canvas.draw_line(Vector2(rect.position.x + 3.0, rect.end.y - 1.0), Vector2(rect.end.x - 3.0, rect.end.y - 1.0), BONE_SHADOW, 1.0)


func _draw_dying_barrier(canvas: CanvasItem, dying: Dictionary, shake_offset: Vector2) -> void:
	var timer := float(dying.get("timer", 0.0))
	var ratio := clampf(timer / DEATH_DURATION, 0.0, 1.0)
	var impact_pos := _get_dict_vector2(dying, "impact_pos", Vector2.ZERO) + shake_offset
	canvas.draw_arc(impact_pos, 8.0 + 42.0 * ratio, 0.0, TAU, 36, Color(SOUL_COLOR.r, SOUL_COLOR.g, SOUL_COLOR.b, 0.52 * (1.0 - ratio)), 2.0, true)
	var fragments: Array = dying.get("fragments", []) as Array
	for fragment in fragments:
		var pos := _get_dict_vector2(fragment, "pos", Vector2.ZERO) + shake_offset
		var alpha := clampf(1.0 - ratio, 0.0, 1.0)
		_draw_bone_segment(canvas, pos, float(fragment.get("length", 9.0)), float(fragment.get("rotation", 0.0)), Color(BONE_COLOR.r, BONE_COLOR.g, BONE_COLOR.b, alpha))


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var age := float(particle.get("age", 0.0))
		var life := maxf(0.001, float(particle.get("life", 1.0)))
		var ratio := clampf(age / life, 0.0, 1.0)
		var color: Color = particle.get("color", SOUL_COLOR) as Color
		color.a *= 1.0 - ratio
		canvas.draw_circle(_get_dict_vector2(particle, "pos", Vector2.ZERO) + shake_offset, float(particle.get("size", 2.0)) * (1.0 + ratio * 0.4), color)


func _draw_bone_segment(canvas: CanvasItem, pos: Vector2, length: float, rotation: float, color: Color) -> void:
	var axis := Vector2(cos(rotation), sin(rotation))
	var half := length * 0.5
	var p0 := pos - axis * half
	var p1 := pos + axis * half
	var a := color.a
	# shadow
	canvas.draw_line(p0 + Vector2(1.0, 1.0), p1 + Vector2(1.0, 1.0), Color(BONE_SHADOW.r, BONE_SHADOW.g, BONE_SHADOW.b, a * 0.4), 3.0, true)
	# body
	canvas.draw_line(p0, p1, color, 2.5, true)
	# highlight (head half)
	var mid := (p0 + p1) * 0.5
	canvas.draw_line(p0, mid, Color(BONE_HILITE.r, BONE_HILITE.g, BONE_HILITE.b, a * 0.6), 1.5, true)
	# joints
	canvas.draw_circle(p0, 2.0, Color(BONE_HILITE.r, BONE_HILITE.g, BONE_HILITE.b, a))
	canvas.draw_circle(p1, 2.0, Color(BONE_DARK.r, BONE_DARK.g, BONE_DARK.b, a))


func _spawn_build_particles(pos: Vector2) -> void:
	for _index in range(24):
		_particles.append(LingpetBoneBarrierPayloadFactory.build_build_particle(pos))
	_limit_particles()


func _spawn_hit_particles(pos: Vector2, velocity: Vector2) -> void:
	for index in range(18):
		_particles.append(LingpetBoneBarrierPayloadFactory.build_hit_particle(pos, velocity, index))
	_limit_particles()


func _limit_particles() -> void:
	while _particles.size() > PARTICLE_MAX:
		_particles.remove_at(0)


func _limit_barriers() -> void:
	while _barriers.size() > MAX_ACTIVE_BARRIERS:
		_barriers.remove_at(0)


func _choose_barrier_x(width: float) -> float:
	for _attempt in range(20):
		var x := randf_range(GAME_LEFT + 10.0, GAME_RIGHT - width - 10.0)
		if _has_enough_spacing(x, width):
			return x
	return randf_range(GAME_LEFT + 10.0, GAME_RIGHT - width - 10.0)


func _has_enough_spacing(x: float, width: float) -> bool:
	var center_x := x + width * 0.5
	for barrier in _barriers:
		var rect := _get_barrier_rect(barrier)
		if absf(center_x - rect.get_center().x) < MIN_SPACING:
			return false
	return true


func _get_barrier_rect(barrier: Dictionary) -> Rect2:
	var pos := _get_dict_vector2(barrier, "pos", Vector2.ZERO)
	return Rect2(pos, Vector2(maxf(1.0, float(barrier.get("width", BARRIER_WIDTH))), maxf(1.0, float(barrier.get("height", BARRIER_HEIGHT)))))


func _find_barrier_index(barrier_id: int) -> int:
	for index in range(_barriers.size()):
		if int(_barriers[index].get("id", 0)) == barrier_id:
			return index
	return -1


func _get_barrier_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for barrier in _barriers:
		positions.append(_get_barrier_rect(barrier).get_center())
	return positions


func _get_barrier_ids() -> Array[int]:
	var ids: Array[int] = []
	for barrier in _barriers:
		ids.append(int(barrier.get("id", 0)))
	return ids


func _get_barrier_widths() -> Array[float]:
	var widths: Array[float] = []
	for barrier in _barriers:
		widths.append(float(barrier.get("width", BARRIER_WIDTH)))
	return widths


func _get_built_count() -> int:
	var count := 0
	for barrier in _barriers:
		if bool(barrier.get("built", false)):
			count += 1
	return count


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", _active_skill_level))), 1, 5)


func _sync_level_values(launch_context: Dictionary) -> void:
	_active_skill_level = _get_active_skill_level(launch_context)
	_barrier_width = _get_positive_context_float(launch_context, "barrier_width", _get_level_array_value(BARRIER_WIDTH_BY_LEVEL, BARRIER_WIDTH))
	_bonus_barrier_chance = _get_context_chance(launch_context, "bonus_barrier_chance_pct", _get_level_array_value(BONUS_BARRIER_CHANCE_BY_LEVEL, 0.0))


func _get_level_array_value(values: Array, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(_active_skill_level - 1, 0, values.size() - 1)
	return float(values[index])


func _get_install_count_for_launch(launch_context: Dictionary) -> int:
	var forced_count := _get_context_float(launch_context, "barrier_count", -1.0)
	if forced_count > 0.0:
		return clampi(int(round(forced_count)), 1, 2)
	if _bonus_barrier_chance <= 0.0:
		return 1
	return 2 if _consume_bonus_barrier_roll() < _bonus_barrier_chance else 1


func _consume_bonus_barrier_roll() -> float:
	if not _bonus_barrier_rolls_for_tests.is_empty():
		return clampf(_bonus_barrier_rolls_for_tests.pop_front(), 0.0, 1.0)
	return randf()


func _get_context_chance(context: Dictionary, pct_key: String, fallback: float) -> float:
	if not context.has(pct_key):
		return clampf(fallback, 0.0, 1.0)
	var value: Variant = context.get(pct_key, 0.0)
	if value is int or value is float:
		var pct := float(value)
		if pct < 0.0:
			return clampf(fallback, 0.0, 1.0)
		return clampf(pct / 100.0, 0.0, 1.0)
	return clampf(fallback, 0.0, 1.0)


func _get_context_float(context: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = context.get(key, fallback)
	if value is int or value is float:
		return float(value)
	return fallback


func _get_positive_context_float(context: Dictionary, key: String, fallback: float) -> float:
	var value := _get_context_float(context, key, fallback)
	if value <= 0.0:
		return fallback
	return value


func _consume_forced_barrier_x() -> float:
	if _forced_x_values_for_tests.is_empty():
		return NO_FORCED_X
	return _forced_x_values_for_tests.pop_front()


func _get_dict_vector2(dict: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = dict.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _play_audio(registry: Object, methods: Array[String]) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	for method in methods:
		if audio.has_method(method):
			audio.call(method)
			return


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
