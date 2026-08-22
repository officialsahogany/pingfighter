extends RefCounted

const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")
const VictoryHighlightActorResolver := preload("res://scripts/core/victory_highlight_actor_resolver.gd")

const MAX_CAPTURE_HZ := 120.0
const MAX_RECORD_SEC := 2.0
const VISUAL_CAPACITY := 248
const EVENT_CAPACITY := 512
const MIN_CLIP_SEC := 0.75
const MAX_ACTION_SEC := 1.50
const GOAL_HOLD_SEC := 0.50
const MAX_CLIP_SEC := MAX_ACTION_SEC + GOAL_HOLD_SEC
const LONG_RALLY_MIN := 6
const CLUTCH_SCORE_MIN := 2.0

const EVENT_PLAYER_HIT := 1
const EVENT_BOSS_HIT := 2
const EVENT_WALL := 3
const EVENT_GOAL := 4

const LABEL_FINISHER := "victory_highlight_finisher"
const LABEL_LONG_RALLY := "victory_highlight_long_rally"
const LABEL_CLUTCH := "victory_highlight_clutch"
# Opt-in B-slice live measurement. Enable before the battle process starts via
# the environment variable or an untracked project-root flag; selected clips
# emit one JSON line when the victory presentation asks for them.
const POSE_COVERAGE_LOG_ENV := "PINGFIGHTER_VICTORY_HIGHLIGHT_POSE_COVERAGE"
const POSE_COVERAGE_LOG_FLAG_PATH := "res://victory_highlight_pose_coverage.flag"

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
var _pose_coverage_log_enabled := false
var _pose_coverage_report_emitted := false
var _frame_capture_state: Object = null


func _init() -> void:
	_pose_coverage_log_enabled = _is_pose_coverage_logging_requested()
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
	if _frame_capture_state != null and _frame_capture_state.has_method("capture_visual"):
		_frame_capture_state.capture_visual(capture_sec)
	return true


func set_frame_capture_state(frame_capture_state: Object) -> void:
	_frame_capture_state = frame_capture_state


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
	if _frame_capture_state != null and _frame_capture_state.has_method("attach_frame_payloads"):
		_frame_capture_state.attach_frame_payloads(selected)
	_maybe_emit_pose_coverage(selected)
	return selected


func get_selected_pose_coverage_report() -> Dictionary:
	return _build_pose_coverage_report(get_selected_victory_clips())


func has_victory_clips() -> bool:
	return not get_selected_victory_clips().is_empty()


func release_match_clips() -> void:
	_promoted_clips.clear()
	_recording_enabled = false
	_clear_ring_texture_refs()
	if _frame_capture_state != null and _frame_capture_state.has_method("release_match_clips"):
		_frame_capture_state.release_match_clips()


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
	_pose_coverage_report_emitted = false
	_clear_ring_texture_refs()
	if _frame_capture_state != null and _frame_capture_state.has_method("reset"):
		_frame_capture_state.reset()


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
		"pose_coverage_log_enabled": _pose_coverage_log_enabled,
		"frame_lane_attached": _frame_capture_state != null,
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
	var clip_start: float = maxf(goal_sec - MAX_ACTION_SEC, _oldest_visual_time())
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
	var goal_t_sec: float = clampf(goal_sec - clip_start, 0.0, MAX_ACTION_SEC)
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

	var promoted_clip := {
		"id": _next_clip_id,
		"capture_time_sec": goal_sec,
		"samples": samples,
		"events": events,
		"duration_sec": clampf(goal_t_sec + GOAL_HOLD_SEC, MIN_CLIP_SEC, MAX_CLIP_SEC),
		"goal_t_sec": goal_t_sec,
		"last_player_hit_t_sec": (
			_last_player_hit_sec - clip_start
			if is_finite(_last_player_hit_sec)
			and _last_player_hit_sec >= clip_start
			and _last_player_hit_sec <= goal_sec + 0.0001
			else -1.0
		),
		"rally_count": rally_count,
		"last_hit_by": last_hit_by,
		"skill_tag": skill_tag,
		"ball_speed": _latest_ball_speed,
		"near_boss_distance": near_distance,
		"clutch_score": clutch_score,
		"player_score": player_score,
		"boss_score": boss_score,
		"is_final": bool(score_result.get("match_finished", false)),
	}
	_promoted_clips.append(promoted_clip)
	if _frame_capture_state != null and _frame_capture_state.has_method("request_goal_capture"):
		_frame_capture_state.request_goal_capture(promoted_clip, _get_provisional_selected_clip_ids())
	_next_clip_id += 1
	return true


func _copy_selected_clip(clip: Dictionary, label_key: String) -> Dictionary:
	var copy: Dictionary = clip.duplicate()
	copy["label_key"] = label_key
	return copy


func _get_provisional_selected_clip_ids() -> Array[int]:
	var result: Array[int] = []
	if _promoted_clips.is_empty():
		return result
	var finisher_index := _promoted_clips.size() - 1
	result.append(int(_promoted_clips[finisher_index].get("id", -1)))
	var long_index := -1
	var longest_rally := LONG_RALLY_MIN - 1
	for index in range(_promoted_clips.size()):
		if index == finisher_index:
			continue
		var rally_count := int(_promoted_clips[index].get("rally_count", 0))
		if rally_count > longest_rally:
			longest_rally = rally_count
			long_index = index
	if long_index >= 0:
		result.append(int(_promoted_clips[long_index].get("id", -1)))
	var clutch_index := -1
	var clutch_score := CLUTCH_SCORE_MIN - 0.001
	for index in range(_promoted_clips.size()):
		if index == finisher_index or index == long_index:
			continue
		var candidate_score := float(_promoted_clips[index].get("clutch_score", 0.0))
		if candidate_score > clutch_score:
			clutch_score = candidate_score
			clutch_index = index
	if clutch_index >= 0:
		result.append(int(_promoted_clips[clutch_index].get("id", -1)))
	return result


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
		"stage_id": 0,
		"stage1_boss_variant": "",
		"boss_pose": VictoryHighlightActorResolver.BOSS_POSE_IDLE_OR_INTERNAL,
		"boss_pose_source": VictoryHighlightActorResolver.BOSS_POSE_SOURCE_AMBIGUOUS,
		"boss_pose_observable": false,
		"boss_resolution": VictoryHighlightActorResolver.BOSS_RESOLUTION_SILHOUETTE_UNSUPPORTED_POSE,
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


func _build_pose_coverage_report(selected_clips: Array[Dictionary]) -> Dictionary:
	var buckets_by_key: Dictionary = {}
	var total_sample_count := 0
	var total_weight_sec := 0.0
	var sheet_weight_sec := 0.0
	var silhouette_weight_sec := 0.0
	var mismatch_weight_sec := 0.0
	var ambiguous_weight_sec := 0.0
	for clip in selected_clips:
		var samples: Array = clip.get("samples", [])
		var duration_sec: float = maxf(0.0, float(clip.get("duration_sec", 0.0)))
		for index in range(samples.size()):
			var sample_value: Variant = samples[index]
			if not (sample_value is Dictionary):
				continue
			var sample: Dictionary = sample_value as Dictionary
			var sample_sec: float = clampf(float(sample.get("t_sec", 0.0)), 0.0, duration_sec)
			var next_sec := duration_sec
			if index + 1 < samples.size() and samples[index + 1] is Dictionary:
				var next_sample: Dictionary = samples[index + 1] as Dictionary
				next_sec = clampf(float(next_sample.get("t_sec", duration_sec)), sample_sec, duration_sec)
			var weight_sec: float = maxf(0.0, next_sec - sample_sec)
			var stage_id: int = int(sample.get("stage_id", 0))
			var stage1_variant: String = str(sample.get("stage1_boss_variant", "")) if stage_id == 1 else ""
			var pose: String = str(sample.get("boss_pose", VictoryHighlightActorResolver.BOSS_POSE_IDLE_OR_INTERNAL))
			var pose_source: String = str(sample.get("boss_pose_source", VictoryHighlightActorResolver.BOSS_POSE_SOURCE_AMBIGUOUS))
			var pose_observable: bool = bool(sample.get("boss_pose_observable", false))
			var resolution: String = str(sample.get(
				"boss_resolution",
				VictoryHighlightActorResolver.BOSS_RESOLUTION_SILHOUETTE_UNSUPPORTED_POSE
			))
			var bucket_key := "%02d|%s|%s|%s|%s" % [
				stage_id,
				stage1_variant,
				pose,
				pose_source,
				resolution,
			]
			var bucket: Dictionary = buckets_by_key.get(bucket_key, {})
			if bucket.is_empty():
				bucket = {
					"stage_id": stage_id,
					"stage1_boss_variant": stage1_variant,
					"pose": pose,
					"pose_source": pose_source,
					"pose_observable": pose_observable,
					"resolution": resolution,
					"sample_count": 0,
					"weighted_sec": 0.0,
				}
				buckets_by_key[bucket_key] = bucket
			bucket["sample_count"] = int(bucket.get("sample_count", 0)) + 1
			bucket["weighted_sec"] = float(bucket.get("weighted_sec", 0.0)) + weight_sec
			total_sample_count += 1
			total_weight_sec += weight_sec
			if resolution == str(VictoryHighlightActorResolver.BOSS_RESOLUTION_SHEET):
				sheet_weight_sec += weight_sec
			elif resolution == str(VictoryHighlightActorResolver.BOSS_RESOLUTION_SHEET_POSE_MISMATCH):
				mismatch_weight_sec += weight_sec
			elif resolution.begins_with("silhouette_"):
				silhouette_weight_sec += weight_sec
			if not pose_observable:
				ambiguous_weight_sec += weight_sec

	var bucket_keys: Array = buckets_by_key.keys()
	bucket_keys.sort()
	var buckets: Array[Dictionary] = []
	for key_value in bucket_keys:
		var bucket: Dictionary = (buckets_by_key[key_value] as Dictionary).duplicate()
		bucket["weighted_ratio"] = _ratio(float(bucket.get("weighted_sec", 0.0)), total_weight_sec)
		buckets.append(bucket)
	return {
		"contract": "selected_clip_pose_coverage_v1",
		"selected_clip_count": selected_clips.size(),
		"sample_count": total_sample_count,
		"weighted_sec": total_weight_sec,
		"sheet_weight_sec": sheet_weight_sec,
		"sheet_ratio": _ratio(sheet_weight_sec, total_weight_sec),
		"silhouette_weight_sec": silhouette_weight_sec,
		"silhouette_ratio": _ratio(silhouette_weight_sec, total_weight_sec),
		"sheet_pose_mismatch_weight_sec": mismatch_weight_sec,
		"sheet_pose_mismatch_ratio": _ratio(mismatch_weight_sec, total_weight_sec),
		"ambiguous_weight_sec": ambiguous_weight_sec,
		"ambiguous_ratio": _ratio(ambiguous_weight_sec, total_weight_sec),
		"buckets": buckets,
	}


func _maybe_emit_pose_coverage(selected_clips: Array[Dictionary]) -> void:
	if not _pose_coverage_log_enabled or _pose_coverage_report_emitted or selected_clips.is_empty():
		return
	_pose_coverage_report_emitted = true
	print("victory_highlight_pose_coverage: %s" % JSON.stringify(_build_pose_coverage_report(selected_clips)))


func _is_pose_coverage_logging_requested() -> bool:
	if not OS.is_debug_build():
		return false
	var env_value := OS.get_environment(POSE_COVERAGE_LOG_ENV).strip_edges().to_lower()
	return env_value in ["1", "true", "yes", "on"] or FileAccess.file_exists(POSE_COVERAGE_LOG_FLAG_PATH)


func _ratio(value: float, total: float) -> float:
	return value / total if total > 0.000001 else 0.0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback
