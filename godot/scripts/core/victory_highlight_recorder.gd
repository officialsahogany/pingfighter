extends RefCounted

const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")
const VictoryHighlightActorResolver := preload("res://scripts/core/victory_highlight_actor_resolver.gd")

const MAX_CAPTURE_HZ := 120.0
const MAX_RECORD_SEC := 2.0
const VISUAL_CAPACITY := 248
const EVENT_CAPACITY := 512
const MIN_CLIP_SEC := 0.75
const MAX_CLIP_SEC := 1.10
const GOAL_HOLD_SEC := 0.25
const LONG_RALLY_MIN := 6
const CLUTCH_SCORE_MIN := 2.0

const EVENT_PLAYER_HIT := 1
const EVENT_BOSS_HIT := 2
const EVENT_WALL := 3
const EVENT_GOAL := 4

const LABEL_FINISHER := "victory_highlight_finisher"
const LABEL_LONG_RALLY := "victory_highlight_long_rally"
const LABEL_CLUTCH := "victory_highlight_clutch"

var _visual_slots: Array[Dictionary] = []
var _visual_head := 0
var _visual_write_index := 0
var _visual_count := 0
var _last_capture_sec := -INF

var _event_slots: Array[Dictionary] = []
var _event_head := 0
var _event_write_index := 0
var _event_count := 0

var _promoted_clips: Array[Dictionary] = []
var _last_player_hit_sec := -INF
var _last_player_skill_tag := ""
var _current_near_boss_distance := INF
var _latest_ball_pos := Vector2.ZERO
var _latest_ball_speed := 0.0
var _recording_enabled := true
var _next_clip_id := 1


func _init() -> void:
	_visual_slots.resize(VISUAL_CAPACITY)
	for index in range(VISUAL_CAPACITY):
		_visual_slots[index] = _make_visual_slot()
	_event_slots.resize(EVENT_CAPACITY)
	for index in range(EVENT_CAPACITY):
		_event_slots[index] = _make_event_slot()


func capture_visual(
	actor_context: Dictionary,
	draw_context: Dictionary,
	now_sec: float = -1.0
) -> bool:
	if not _recording_enabled or actor_context.is_empty() or not bool(draw_context.get("ball_active", false)):
		return false
	var capture_sec: float = _resolve_time(now_sec)
	if capture_sec - _last_capture_sec < (1.0 / MAX_CAPTURE_HZ) - 0.000001:
		return false
	_evict_visual_before(capture_sec - MAX_RECORD_SEC)
	_evict_events_before(capture_sec - MAX_RECORD_SEC)
	var slot: Dictionary = _visual_slots[_visual_write_index]
	slot["capture_time_sec"] = capture_sec
	var ball_pos: Vector2 = BallRenderInterpolation.get_render_ball_pos(
		draw_context,
		_get_vector2(draw_context, "ball_pos", Vector2.ZERO)
	)
	var ball_vel: Vector2 = _get_vector2(draw_context, "ball_vel", Vector2.ZERO)
	slot["ball_pos"] = ball_pos
	slot["ball_radius"] = maxf(1.0, float(draw_context.get("ball_render_radius", 26.6175)))
	slot["ball_vel"] = ball_vel
	slot["resolved"] = VictoryHighlightActorResolver.resolve_into(actor_context, slot)
	_latest_ball_pos = ball_pos
	_latest_ball_speed = ball_vel.length()
	_update_near_boss_distance(ball_pos, actor_context)
	_commit_visual_write()
	_last_capture_sec = capture_sec
	return true


func record_contact(
	kind: int,
	pos: Vector2,
	skill_tag: String = "",
	now_sec: float = -1.0
) -> void:
	if not _recording_enabled:
		return
	var capture_sec: float = _resolve_time(now_sec)
	_write_event(kind, pos, skill_tag, capture_sec)
	if kind == EVENT_PLAYER_HIT:
		_last_player_hit_sec = capture_sec
		if not skill_tag.is_empty():
			_last_player_skill_tag = skill_tag


func record_player_hit(pos: Vector2, skill_tag: String = "", now_sec: float = -1.0) -> void:
	record_contact(EVENT_PLAYER_HIT, pos, skill_tag, now_sec)


func record_boss_hit(pos: Vector2, skill_tag: String = "", now_sec: float = -1.0) -> void:
	record_contact(EVENT_BOSS_HIT, pos, skill_tag, now_sec)


func record_wall_hit(pos: Vector2, now_sec: float = -1.0) -> void:
	record_contact(EVENT_WALL, pos, "", now_sec)


func record_score_event(
	scoring_side: String,
	score_result: Dictionary,
	rally_count: int,
	last_hit_by: String,
	skill_tag: String = "",
	now_sec: float = -1.0
) -> bool:
	var capture_sec: float = _resolve_time(now_sec)
	var goal_skill_tag: String = skill_tag if not skill_tag.is_empty() else _last_player_skill_tag
	_write_event(EVENT_GOAL, _latest_ball_pos, goal_skill_tag, capture_sec)
	var promoted := false
	if scoring_side == "player":
		promoted = _promote_player_goal(
			capture_sec,
			score_result,
			maxi(0, rally_count),
			last_hit_by,
			goal_skill_tag
		)
	if bool(score_result.get("match_finished", false)):
		_recording_enabled = false
	_last_player_hit_sec = -INF
	_last_player_skill_tag = ""
	_current_near_boss_distance = INF
	return promoted


func get_selected_victory_clips() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var finisher_index := -1
	for index in range(_promoted_clips.size()):
		if bool(_promoted_clips[index].get("is_final", false)):
			finisher_index = index
	if finisher_index < 0:
		return selected
	selected.append(_copy_selected_clip(_promoted_clips[finisher_index], LABEL_FINISHER))

	var long_index := -1
	var longest_rally := LONG_RALLY_MIN - 1
	for index in range(_promoted_clips.size()):
		if index == finisher_index:
			continue
		var rally_count: int = int(_promoted_clips[index].get("rally_count", 0))
		if rally_count > longest_rally:
			longest_rally = rally_count
			long_index = index
	if long_index >= 0:
		selected.append(_copy_selected_clip(_promoted_clips[long_index], LABEL_LONG_RALLY))

	var clutch_index := -1
	var clutch_score := CLUTCH_SCORE_MIN - 0.001
	for index in range(_promoted_clips.size()):
		if index == finisher_index or index == long_index:
			continue
		var candidate_score: float = float(_promoted_clips[index].get("clutch_score", 0.0))
		if candidate_score > clutch_score:
			clutch_score = candidate_score
			clutch_index = index
	if clutch_index >= 0:
		selected.append(_copy_selected_clip(_promoted_clips[clutch_index], LABEL_CLUTCH))

	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("capture_time_sec", 0.0)) < float(b.get("capture_time_sec", 0.0))
	)
	return selected


func has_victory_clips() -> bool:
	return not get_selected_victory_clips().is_empty()


func release_match_clips() -> void:
	_promoted_clips.clear()
	_recording_enabled = false
	_clear_ring_texture_refs()


func reset() -> void:
	_promoted_clips.clear()
	_visual_head = 0
	_visual_write_index = 0
	_visual_count = 0
	_event_head = 0
	_event_write_index = 0
	_event_count = 0
	_last_capture_sec = -INF
	_last_player_hit_sec = -INF
	_last_player_skill_tag = ""
	_current_near_boss_distance = INF
	_latest_ball_pos = Vector2.ZERO
	_latest_ball_speed = 0.0
	_recording_enabled = true
	_next_clip_id = 1
	_clear_ring_texture_refs()


func get_debug_snapshot() -> Dictionary:
	return {
		"visual_capacity": _visual_slots.size(),
		"visual_count": _visual_count,
		"visual_head": _visual_head,
		"visual_write_index": _visual_write_index,
		"event_capacity": _event_slots.size(),
		"event_count": _event_count,
		"clip_count": _promoted_clips.size(),
		"recording_enabled": _recording_enabled,
	}


func get_promoted_clips_for_tests() -> Array[Dictionary]:
	return _promoted_clips.duplicate()


func get_visual_times_for_tests() -> Array[float]:
	var times: Array[float] = []
	for offset in range(_visual_count):
		times.append(float(_visual_slots[(_visual_head + offset) % VISUAL_CAPACITY].get("capture_time_sec", -INF)))
	return times


func has_ring_texture_refs_for_tests() -> bool:
	for slot in _visual_slots:
		if slot.get("player_texture", null) != null or slot.get("boss_texture", null) != null:
			return true
	return false


func _promote_player_goal(
	goal_sec: float,
	score_result: Dictionary,
	rally_count: int,
	last_hit_by: String,
	skill_tag: String
) -> bool:
	if _visual_count <= 0:
		return false
	var desired_start: float = _last_player_hit_sec - 0.2 if is_finite(_last_player_hit_sec) else goal_sec - 0.5
	var clip_start: float = clampf(desired_start, goal_sec - (MAX_CLIP_SEC - GOAL_HOLD_SEC), goal_sec - (MIN_CLIP_SEC - GOAL_HOLD_SEC))
	clip_start = maxf(clip_start, _oldest_visual_time())
	var samples: Array[Dictionary] = []
	for offset in range(_visual_count):
		var slot: Dictionary = _visual_slots[(_visual_head + offset) % VISUAL_CAPACITY]
		var sample_sec: float = float(slot.get("capture_time_sec", -INF))
		if sample_sec < clip_start or sample_sec > goal_sec + 0.0001:
			continue
		var copy: Dictionary = slot.duplicate()
		copy["t_sec"] = maxf(0.0, sample_sec - clip_start)
		samples.append(copy)
	if samples.is_empty():
		return false
	var goal_t_sec: float = clampf(goal_sec - clip_start, 0.0, MAX_CLIP_SEC - GOAL_HOLD_SEC)
	var hold_sample: Dictionary = samples[-1].duplicate()
	hold_sample["capture_time_sec"] = goal_sec + GOAL_HOLD_SEC
	hold_sample["t_sec"] = goal_t_sec + GOAL_HOLD_SEC
	samples.append(hold_sample)

	var events: Array[Dictionary] = []
	for offset in range(_event_count):
		var event_slot: Dictionary = _event_slots[(_event_head + offset) % EVENT_CAPACITY]
		var event_sec: float = float(event_slot.get("capture_time_sec", -INF))
		if event_sec < clip_start or event_sec > goal_sec + 0.0001:
			continue
		var event_copy: Dictionary = event_slot.duplicate()
		event_copy["t_sec"] = maxf(0.0, event_sec - clip_start)
		events.append(event_copy)

	var player_score: int = int(score_result.get("player_score", 0))
	var boss_score: int = int(score_result.get("boss_score", 0))
	var deuce_mode: bool = bool(score_result.get("deuce_mode", false))
	var near_distance: float = _current_near_boss_distance
	var clutch_score := 0.0
	if skill_tag != "":
		clutch_score += 3.0
	if near_distance <= 18.0:
		clutch_score += 2.0
	if deuce_mode:
		clutch_score += 2.0
	if player_score <= boss_score + 1:
		clutch_score += 1.0

	_promoted_clips.append({
		"id": _next_clip_id,
		"capture_time_sec": goal_sec,
		"samples": samples,
		"events": events,
		"duration_sec": clampf(goal_t_sec + GOAL_HOLD_SEC, MIN_CLIP_SEC, MAX_CLIP_SEC),
		"goal_t_sec": goal_t_sec,
		"rally_count": rally_count,
		"last_hit_by": last_hit_by,
		"skill_tag": skill_tag,
		"ball_speed": _latest_ball_speed,
		"near_boss_distance": near_distance,
		"clutch_score": clutch_score,
		"player_score": player_score,
		"boss_score": boss_score,
		"is_final": bool(score_result.get("match_finished", false)),
	})
	_next_clip_id += 1
	return true


func _copy_selected_clip(clip: Dictionary, label_key: String) -> Dictionary:
	var copy: Dictionary = clip.duplicate()
	copy["label_key"] = label_key
	return copy


func _write_event(kind: int, pos: Vector2, skill_tag: String, capture_sec: float) -> void:
	_evict_events_before(capture_sec - MAX_RECORD_SEC)
	var slot: Dictionary = _event_slots[_event_write_index]
	slot["capture_time_sec"] = capture_sec
	slot["kind"] = kind
	slot["pos"] = pos
	slot["skill_tag"] = skill_tag
	if _event_count == EVENT_CAPACITY:
		_event_head = (_event_head + 1) % EVENT_CAPACITY
	else:
		_event_count += 1
	_event_write_index = (_event_write_index + 1) % EVENT_CAPACITY


func _commit_visual_write() -> void:
	if _visual_count == VISUAL_CAPACITY:
		_visual_head = (_visual_head + 1) % VISUAL_CAPACITY
	else:
		_visual_count += 1
	_visual_write_index = (_visual_write_index + 1) % VISUAL_CAPACITY


func _evict_visual_before(cutoff_sec: float) -> void:
	while _visual_count > 0:
		var slot: Dictionary = _visual_slots[_visual_head]
		if float(slot.get("capture_time_sec", INF)) >= cutoff_sec:
			break
		_clear_slot_texture_refs(slot)
		_visual_head = (_visual_head + 1) % VISUAL_CAPACITY
		_visual_count -= 1


func _evict_events_before(cutoff_sec: float) -> void:
	while _event_count > 0:
		var slot: Dictionary = _event_slots[_event_head]
		if float(slot.get("capture_time_sec", INF)) >= cutoff_sec:
			break
		_event_head = (_event_head + 1) % EVENT_CAPACITY
		_event_count -= 1


func _oldest_visual_time() -> float:
	if _visual_count <= 0:
		return 0.0
	return float(_visual_slots[_visual_head].get("capture_time_sec", 0.0))


func _update_near_boss_distance(ball_pos: Vector2, actor_context: Dictionary) -> void:
	var boss_pos: Vector2 = _get_vector2(actor_context, "boss_pos", Vector2.ZERO)
	var boss_size: Vector2 = _get_vector2(actor_context, "boss_paddle_size", Vector2(100.0, 40.0))
	if ball_pos.y > boss_pos.y + boss_size.y + 110.0:
		return
	var nearest_x: float = clampf(ball_pos.x, boss_pos.x, boss_pos.x + boss_size.x)
	_current_near_boss_distance = minf(_current_near_boss_distance, absf(ball_pos.x - nearest_x))


func _clear_ring_texture_refs() -> void:
	for slot in _visual_slots:
		_clear_slot_texture_refs(slot)


func _clear_slot_texture_refs(slot: Dictionary) -> void:
	slot["player_texture"] = null
	slot["boss_texture"] = null


func _make_visual_slot() -> Dictionary:
	return {
		"capture_time_sec": -INF,
		"ball_pos": Vector2.ZERO,
		"ball_radius": 1.0,
		"ball_vel": Vector2.ZERO,
		"resolved": false,
		"player_texture": null,
		"player_src": Rect2(),
		"player_dest": Rect2(),
		"player_flip": false,
		"player_modulate": Color.WHITE,
		"boss_texture": null,
		"boss_src": Rect2(),
		"boss_dest": Rect2(),
		"boss_flip": false,
		"boss_modulate": Color.WHITE,
	}


func _make_event_slot() -> Dictionary:
	return {
		"capture_time_sec": -INF,
		"kind": 0,
		"pos": Vector2.ZERO,
		"skill_tag": "",
	}


func _resolve_time(value: float) -> float:
	if value >= 0.0:
		return value
	return float(Time.get_ticks_usec()) / 1000000.0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback
