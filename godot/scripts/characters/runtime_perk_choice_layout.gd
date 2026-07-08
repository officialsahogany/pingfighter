extends RefCounted

const DEFAULT_CARD_SIZE := Vector2(250.0, 126.0)
const DEFAULT_CARD_GAP := 16.0
const PARTICLE_COLORS := [
	Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(1.0, 220.0 / 255.0, 100.0 / 255.0),
	Color(150.0 / 255.0, 1.0, 150.0 / 255.0),
	Color(1.0, 150.0 / 255.0, 200.0 / 255.0),
]


func build_layout(view_size: Vector2, choice_count_value: int) -> Dictionary:
	var card_count: int = max(1, choice_count_value)
	var game_width: float = min(1120.0, max(420.0, view_size.x - 128.0))
	var card_gap: float = DEFAULT_CARD_GAP
	var card_width: float = DEFAULT_CARD_SIZE.x
	var card_height: float = DEFAULT_CARD_SIZE.y
	var total_width: float = card_width * float(card_count) + card_gap * float(max(0, card_count - 1))
	if total_width > game_width:
		var scale_factor: float = game_width / total_width
		card_width = floor(card_width * scale_factor)
		card_height = floor(card_height * scale_factor)
		card_gap = max(8.0, floor(card_gap * scale_factor))
		total_width = card_width * float(card_count) + card_gap * float(max(0, card_count - 1))
	var title_to_card: float = 72.0
	var desc_gap: float = 18.0
	# desc_h holds the level stats (up to 2 lines) plus the friendly `detail`
	# explanation added below them (2026-07-09 request); taller than the old
	# stats-only box so the description reads without clipping.
	var desc_h: float = 128.0
	var panel_gap: float = 14.0
	var panel_h: float = 158.0
	var hint_gap: float = 34.0
	var group_h: float = title_to_card + card_height + desc_gap + desc_h + panel_gap + panel_h + hint_gap + 18.0
	var group_top: float = max(48.0, floor((view_size.y - group_h) * 0.5))
	var card_y: float = group_top + title_to_card
	var card_x: float = floor((view_size.x - total_width) * 0.5)
	var desc_y: float = card_y + card_height + desc_gap
	var panel_y: float = desc_y + desc_h + panel_gap
	var panel_w: float = min(game_width, total_width + 128.0)
	return {
		"card_size": Vector2(card_width, card_height),
		"card_gap": card_gap,
		"cards_start": Vector2(card_x, card_y),
		"total_width": total_width,
		"desc_rect": Rect2(Vector2(card_x, desc_y), Vector2(total_width, desc_h)),
		"panel_rect": Rect2(Vector2(max(20.0, (view_size.x - panel_w) * 0.5), panel_y), Vector2(panel_w, panel_h)),
		"title_pos": Vector2(view_size.x * 0.5, group_top + 32.0),
		"hint_pos": Vector2(view_size.x * 0.5, panel_y + panel_h + hint_gap),
	}


func build_layout_from_runtime_state(runtime_state: Object, view_size: Vector2) -> Dictionary:
	if runtime_state == null:
		return build_layout(view_size, 0)
	return build_layout(view_size, _get_array(runtime_state.get("current_choices")).size())


func get_card_rects(view_size: Vector2, choice_count_value: int, animation_time: float) -> Array:
	var layout: Dictionary = build_layout(view_size, choice_count_value)
	var rects: Array = []
	var card_size: Vector2 = _get_vector2(layout.get("card_size", DEFAULT_CARD_SIZE))
	var start: Vector2 = _get_vector2(layout.get("cards_start", Vector2.ZERO))
	var gap: float = float(layout.get("card_gap", DEFAULT_CARD_GAP))
	for index in range(max(0, choice_count_value)):
		var offset := get_card_offset(index, animation_time)
		rects.append(Rect2(start + Vector2(float(index) * (card_size.x + gap), 0.0) + offset, card_size))
	return rects


func get_card_rects_from_runtime_state(runtime_state: Object, view_size: Vector2) -> Array:
	if runtime_state == null:
		return []
	return get_card_rects(
		view_size,
		_get_array(runtime_state.get("current_choices")).size(),
		float(runtime_state.get("animation_time"))
	)


func get_card_index_at(
	position: Vector2,
	view_size: Vector2,
	choice_count_value: int,
	animation_time: float
) -> int:
	var rects: Array = get_card_rects(view_size, choice_count_value, animation_time)
	for index in range(rects.size()):
		var rect: Rect2 = rects[index]
		if rect.has_point(position):
			return index
	return -1


func get_card_index_at_from_runtime_state(runtime_state: Object, position: Vector2, view_size: Vector2) -> int:
	if runtime_state == null:
		return -1
	return get_card_index_at(
		position,
		view_size,
		_get_array(runtime_state.get("current_choices")).size(),
		float(runtime_state.get("animation_time"))
	)


func get_card_offset(index: int, animation_time: float) -> Vector2:
	var progress: float = clamp(animation_time / 0.28, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	if index == 1:
		return Vector2(0.0, -260.0 * (1.0 - eased))
	if index % 2 == 0:
		return Vector2(-260.0 * (1.0 - eased), 0.0)
	return Vector2(260.0 * (1.0 - eased), 0.0)


func build_particles(count: int) -> Array:
	var out: Array = []
	for _index in range(max(0, count)):
		out.append({})
	return out


func apply_particles_state_update(runtime_state: Object, particles_update: Array) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	runtime_state.set("particles", particles_update.duplicate(true))
	var applied_particles: Array = _get_array(runtime_state.get("particles"))
	return {
		"accepted": true,
		"particle_count": applied_particles.size(),
	}


func rebuild_particles_from_runtime_state(runtime_state: Object, count: int) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	return apply_particles_state_update(runtime_state, build_particles(count))


func update_particles(particles: Array, delta: float, view_size: Vector2, particle_life: float) -> void:
	var left: float = max(0.0, view_size.x * 0.5 - 300.0)
	var right: float = min(view_size.x, view_size.x * 0.5 + 300.0)
	for particle in particles:
		var data: Dictionary = particle
		data["age"] = float(data.get("age", 0.0)) + delta
		data["position"] = _get_vector2(data.get("position", Vector2.ZERO)) + _get_vector2(data.get("velocity", Vector2.ZERO)) * delta
		var pos: Vector2 = _get_vector2(data.get("position", Vector2.ZERO))
		if pos.x < left or pos.x > right or float(data.get("age", 0.0)) > particle_life:
			reset_particle(data, view_size, particle_life)


func reset_particle(particle: Dictionary, view_size: Vector2, particle_life: float) -> void:
	var center_x: float = view_size.x * 0.5
	var x: float = randf_range(center_x - 280.0, center_x + 280.0)
	var y: float = randf_range(80.0, max(100.0, view_size.y * 0.64))
	particle["position"] = Vector2(x, y)
	particle["velocity"] = Vector2(randf_range(-24.0, 24.0), randf_range(-92.0, -22.0))
	particle["age"] = randf_range(0.0, particle_life * 0.65)
	particle["size"] = randf_range(2.0, 5.5)
	particle["color"] = PARTICLE_COLORS[randi() % PARTICLE_COLORS.size()]


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
