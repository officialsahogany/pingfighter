extends RefCounted

# Stage 6 Tetriser crystal shield boss skill.
# Source parity: pillar_tetriser.py CrystalShieldSystem / CrystalShieldBlock.

const STAGE_ID := 6
const TRIGGER_PLAYER_SCORE := 4
const BLOCK_COUNT := 24
const BLOCK_SIZE := 16.0
const COLLISION_SIZE := 40.0
const ORBIT_RADIUS := 100.0
const ORBIT_SPEED := 0.4
const FORMATION_FREEZE_SEC := 1.8
const HIT_FADE_SEC := 0.28
const HIT_COOLDOWN_SEC := 0.13
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DEFAULT_BOSS_POS := Vector2(330.0, 25.0)
const DEFAULT_BOSS_SIZE := Vector2(100.0, 40.0)

var pending_activation: bool = false
var score_trigger_consumed: bool = false
var phase: String = "idle"
var animation_timer: float = 0.0
var shield_blocks: Array[Dictionary] = []
var hit_cooldown_sec: float = 0.0
var _boss_center: Vector2 = DEFAULT_BOSS_POS + DEFAULT_BOSS_SIZE * 0.5


func reset(clear_match_state: bool = false) -> void:
	if not clear_match_state:
		return
	pending_activation = false
	phase = "idle"
	animation_timer = 0.0
	shield_blocks.clear()
	hit_cooldown_sec = 0.0
	_boss_center = DEFAULT_BOSS_POS + DEFAULT_BOSS_SIZE * 0.5
	score_trigger_consumed = false


func update(delta: float, context: Dictionary) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		reset(true)
		return get_update_result()

	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	_maybe_schedule_from_score(context)
	if pending_activation and _should_start_pending(context):
		start_activation(_get_boss_center(context))

	hit_cooldown_sec = maxf(0.0, hit_cooldown_sec - clamped_delta)
	if phase != "idle" and phase != "spent":
		_update_blocks(clamped_delta, _get_boss_center(context))
	return get_update_result()


func start_activation(boss_center: Vector2) -> bool:
	if phase != "idle" and phase != "spent":
		return false
	pending_activation = false
	phase = "forming"
	animation_timer = 0.0
	hit_cooldown_sec = 0.0
	_boss_center = boss_center
	_create_shield_blocks(boss_center)
	return true


func schedule_activation() -> void:
	if phase == "idle" or phase == "spent":
		pending_activation = true


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	if phase != "active" or hit_cooldown_sec > 0.0 or not _is_player_ball(context, deps):
		return false
	var ball_pos: Vector2 = _as_vector2(scene.get("ball_pos", Vector2.ZERO))
	var radius: float = maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	var ball_rect := Rect2(ball_pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	var active_entries: Array[Dictionary] = _active_entries_sorted()
	for idx in range(active_entries.size()):
		var entry: Dictionary = active_entries[idx]
		var block: Dictionary = entry["block"]
		var center: Vector2 = _as_vector2(block.get("position", Vector2.ZERO))
		var collision_size: float = maxf(COLLISION_SIZE, float(block.get("size", BLOCK_SIZE)) + radius)
		var block_rect := Rect2(center - Vector2(collision_size, collision_size) * 0.5, Vector2(collision_size, collision_size))
		if not ball_rect.intersects(block_rect):
			continue
		var hit_radius: float = radius + float(block.get("size", BLOCK_SIZE)) * 0.5 + 8.0
		if ball_pos.distance_squared_to(center) > hit_radius * hit_radius:
			continue
		_evaporate_hit_and_neighbors(active_entries, idx)
		_apply_shield_reflection(scene, center)
		hit_cooldown_sec = HIT_COOLDOWN_SEC
		return true
	return false


func get_actor_draw_context() -> Dictionary:
	return {
		"stage6_tetriser_crystal_shield_blocks": _build_draw_list(),
		"stage6_tetriser_crystal_shield_phase": phase,
		"stage6_tetriser_crystal_shield_freeze_active": is_freeze_active(),
		"stage6_tetriser_crystal_shield_center": _boss_center,
		"stage6_tetriser_crystal_shield_radius": ORBIT_RADIUS,
		"stage6_tetriser_crystal_shield_progress": _formation_progress(),
	}


func get_update_result() -> Dictionary:
	return {
		"stage6_tetriser_crystal_shield_pending": pending_activation,
		"stage6_tetriser_crystal_shield_active": is_active(),
		"stage6_tetriser_crystal_shield_freeze_active": is_freeze_active(),
	}


func get_boss_ai_context() -> Dictionary:
	return {
		"stage6_tetriser_crystal_shield_pending": pending_activation,
		"stage6_tetriser_crystal_shield_active": is_active(),
		"stage6_tetriser_crystal_shield_blocks": get_active_block_count(),
	}


func has_runtime_state() -> bool:
	return pending_activation or phase != "idle" or not shield_blocks.is_empty()


func is_freeze_active() -> bool:
	return phase == "forming"


func is_active() -> bool:
	return phase == "active" and get_active_block_count() > 0


func get_active_block_count() -> int:
	var count: int = 0
	for block in shield_blocks:
		if bool(block.get("active", false)):
			count += 1
	return count


func debug_force_pending() -> void:
	pending_activation = true


func debug_start(boss_center: Vector2 = DEFAULT_BOSS_POS + DEFAULT_BOSS_SIZE * 0.5, active_immediately: bool = false) -> void:
	start_activation(boss_center)
	if active_immediately:
		phase = "active"
		animation_timer = FORMATION_FREEZE_SEC
		_update_blocks(0.0, boss_center)


func _maybe_schedule_from_score(context: Dictionary) -> void:
	if score_trigger_consumed:
		return
	var player_score: int = int(context.get("player_score", -1))
	if player_score < TRIGGER_PLAYER_SCORE:
		return
	schedule_activation()
	score_trigger_consumed = true


func _should_start_pending(context: Dictionary) -> bool:
	return bool(context.get("waiting_for_serve", false)) \
		or not bool(context.get("ball_active", true)) \
		or bool(context.get("stage6_tetriser_crystal_shield_start_now", false))


func _create_shield_blocks(boss_center: Vector2) -> void:
	shield_blocks.clear()
	for i in range(BLOCK_COUNT):
		var angle: float = TAU * float(i) / float(BLOCK_COUNT)
		var source: Vector2 = _source_position_for_index(i)
		var color := Color.from_hsv(float(i) / float(BLOCK_COUNT), 0.62, 1.0, 1.0)
		shield_blocks.append({
			"angle": angle,
			"source": source,
			"position": source,
			"target": boss_center + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS,
			"size": BLOCK_SIZE,
			"color": color,
			"active": true,
			"alpha": 1.0,
			"evaporating": false,
			"evaporate_timer": 0.0,
		})


func _source_position_for_index(index: int) -> Vector2:
	var side_index: int = floori(float(index) * 0.5)
	var y_span: float = FIELD_HEIGHT - 220.0
	var y: float = 110.0 + y_span * (float(side_index % 12) / 11.0)
	var x: float = 34.0 if index % 2 == 0 else FIELD_WIDTH - 34.0
	return Vector2(x, y)


func _update_blocks(delta: float, boss_center: Vector2) -> void:
	_boss_center = boss_center
	animation_timer += delta
	var progress: float = _formation_progress()
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	var alive_blocks: Array[Dictionary] = []
	for block in shield_blocks:
		var angle: float = float(block.get("angle", 0.0))
		var active: bool = bool(block.get("active", false))
		if active:
			var speed_mult: float = 0.35 + progress * 2.2 if phase == "forming" else 1.0
			angle += ORBIT_SPEED * delta * speed_mult
			block["angle"] = angle
		var target: Vector2 = boss_center + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		block["target"] = target
		if phase == "forming":
			var source: Vector2 = _as_vector2(block.get("source", target))
			var lift: float = sin(progress * PI) * -28.0
			block["position"] = source.lerp(target, eased) + Vector2(0.0, lift)
		else:
			block["position"] = target

		if bool(block.get("evaporating", false)):
			var timer: float = float(block.get("evaporate_timer", 0.0)) + delta
			block["evaporate_timer"] = timer
			var fade: float = clampf(1.0 - timer / HIT_FADE_SEC, 0.0, 1.0)
			block["alpha"] = fade
			block["size"] = BLOCK_SIZE * (1.0 + (1.0 - fade) * 1.6)
			if fade > 0.0:
				alive_blocks.append(block)
		else:
			alive_blocks.append(block)
	shield_blocks = alive_blocks
	if phase == "forming" and animation_timer >= FORMATION_FREEZE_SEC:
		phase = "active"
		animation_timer = FORMATION_FREEZE_SEC
	if phase == "active" and shield_blocks.is_empty():
		phase = "spent"


func _active_entries_sorted() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for idx in range(shield_blocks.size()):
		var block: Dictionary = shield_blocks[idx]
		if bool(block.get("active", false)):
			entries.append({"index": idx, "block": block})
	entries.sort_custom(Callable(self, "_sort_active_entries_by_angle"))
	return entries


func _sort_active_entries_by_angle(a: Dictionary, b: Dictionary) -> bool:
	var a_block: Dictionary = a.get("block", {})
	var b_block: Dictionary = b.get("block", {})
	return fposmod(float(a_block.get("angle", 0.0)), TAU) < fposmod(float(b_block.get("angle", 0.0)), TAU)


func _evaporate_hit_and_neighbors(active_entries: Array[Dictionary], hit_entry_index: int) -> void:
	if active_entries.is_empty():
		return
	var target_indices := {}
	target_indices[int(active_entries[hit_entry_index].get("index", -1))] = true
	if active_entries.size() > 1:
		target_indices[int(active_entries[(hit_entry_index - 1 + active_entries.size()) % active_entries.size()].get("index", -1))] = true
		target_indices[int(active_entries[(hit_entry_index + 1) % active_entries.size()].get("index", -1))] = true
	for index_value in target_indices.keys():
		var block_index: int = int(index_value)
		if block_index < 0 or block_index >= shield_blocks.size():
			continue
		var block: Dictionary = shield_blocks[block_index]
		if not bool(block.get("active", false)):
			continue
		block["active"] = false
		block["evaporating"] = true
		block["evaporate_timer"] = 0.0
		block["alpha"] = 1.0


func _apply_shield_reflection(scene: Dictionary, block_center: Vector2) -> void:
	var ball_pos: Vector2 = _as_vector2(scene.get("ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = _as_vector2(scene.get("ball_vel", Vector2.ZERO))
	var normal: Vector2 = ball_pos - block_center
	if normal.length_squared() <= 0.001:
		normal = Vector2(0.0, 1.0 if ball_vel.y < 0.0 else -1.0)
	else:
		normal = normal.normalized()
	var speed: float = maxf(10.0, ball_vel.length())
	ball_vel = Vector2(normal.x * speed * 0.6, normal.y * speed)
	ball_vel.x += randf_range(-0.5, 0.5)
	ball_pos += normal * 25.0
	scene["ball_pos"] = ball_pos
	scene["ball_vel"] = ball_vel


func _is_player_ball(context: Dictionary, deps: Dictionary) -> bool:
	var last_hit_by: String = str(context.get("last_hit_by", "")).strip_edges().to_lower()
	if last_hit_by == "":
		var ball_intensity: Object = deps.get("ball_intensity", null)
		if ball_intensity != null and ball_intensity.has_method("get_last_hit_by"):
			last_hit_by = str(ball_intensity.get_last_hit_by()).strip_edges().to_lower()
	return last_hit_by == "" or last_hit_by == "player"


func _build_draw_list() -> Array:
	var out: Array = []
	for block in shield_blocks:
		out.append({
			"position": block.get("position", Vector2.ZERO),
			"target": block.get("target", Vector2.ZERO),
			"source": block.get("source", Vector2.ZERO),
			"size": float(block.get("size", BLOCK_SIZE)),
			"color": block.get("color", Color(0.6, 0.9, 1.0)),
			"alpha": float(block.get("alpha", 1.0)),
			"active": bool(block.get("active", false)),
			"evaporating": bool(block.get("evaporating", false)),
		})
	return out


func _formation_progress() -> float:
	if FORMATION_FREEZE_SEC <= 0.0:
		return 1.0
	return clampf(animation_timer / FORMATION_FREEZE_SEC, 0.0, 1.0)


func _get_boss_center(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", DEFAULT_BOSS_POS))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", DEFAULT_BOSS_SIZE))
	return boss_pos + boss_size * 0.5


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
