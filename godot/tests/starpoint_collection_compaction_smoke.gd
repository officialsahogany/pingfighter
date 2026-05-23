extends SceneTree

const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage4BirdEvent := preload("res://scripts/stages/stage4/stage4_bird_event.gd")

var _failures: Array[String] = []


class ClearingRuntimePerkState:
	var target: Object = null
	var collect_calls := 0
	var opens_choice := true

	func _init(next_target: Object, next_opens_choice: bool = true) -> void:
		target = next_target
		opens_choice = next_opens_choice

	func collect_star_points(
		_amount: int,
		_character_type: String,
		_catalog: Object,
		_owner: Object = null,
		_registry: Object = null,
		_defer_choice_open: bool = false
	) -> bool:
		collect_calls += 1
		if target != null:
			var drops_value: Variant = target.get("starpoint_drops")
			if drops_value is Array:
				(drops_value as Array).clear()
		return opens_choice


func _init() -> void:
	_verify_stage1_collection_stops_after_runtime_clear()
	_verify_stage1_collection_stops_after_false_runtime_clear()
	_verify_stage2_collection_stops_after_runtime_clear()
	_verify_stage3_collection_stops_after_runtime_clear()
	_verify_stage4_collection_stops_after_runtime_clear()

	if _failures.is_empty():
		print("starpoint_collection_compaction_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage1_collection_stops_after_runtime_clear() -> void:
	var event := Stage1BalloonEvent.new()
	event.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
	]
	var runtime_state := ClearingRuntimePerkState.new(event)
	event._update_starpoint_drops(0.0, _context(1), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 1 should collect exactly one starpoint before the modal clears drops")
	_expect(event.starpoint_drops.is_empty(), "Stage 1 should keep runtime-cleared starpoint drops empty")


func _verify_stage1_collection_stops_after_false_runtime_clear() -> void:
	var event := Stage1BalloonEvent.new()
	event.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
	]
	var runtime_state := ClearingRuntimePerkState.new(event, false)
	event._update_starpoint_drops(0.0, _context(1), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 1 should stop after runtime clears drops even if no choice opens")
	_expect(event.starpoint_drops.is_empty(), "Stage 1 false-open clear should not re-read the old second drop")


func _verify_stage2_collection_stops_after_runtime_clear() -> void:
	var background := Stage2PillarBackground.new()
	background.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), 12.0),
		_make_drop(Vector2(110.0, 100.0), 12.0),
	]
	var runtime_state := ClearingRuntimePerkState.new(background)
	background._update_starpoint_drops(0.0, _context(2), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 2 should collect exactly one starpoint before the modal clears drops")
	_expect(background.starpoint_drops.is_empty(), "Stage 2 should keep runtime-cleared starpoint drops empty")


func _verify_stage3_collection_stops_after_runtime_clear() -> void:
	var boss_state := Stage3BossSkillState.new()
	boss_state.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage3BossSkillState.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage3BossSkillState.STARPOINT_DROP_SIZE),
	]
	var runtime_state := ClearingRuntimePerkState.new(boss_state)
	boss_state._update_starpoint_drops(0.0, _context(3), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 3 should collect exactly one starpoint before the modal clears drops")
	_expect(boss_state.starpoint_drops.is_empty(), "Stage 3 should keep runtime-cleared starpoint drops empty")


func _verify_stage4_collection_stops_after_runtime_clear() -> void:
	var event := Stage4BirdEvent.new()
	event.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage4BirdEvent.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage4BirdEvent.STARPOINT_DROP_SIZE),
	]
	var runtime_state := ClearingRuntimePerkState.new(event)
	event._update_starpoint_drops(0.0, _context(4), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 4 should collect exactly one starpoint before the modal clears drops")
	_expect(event.starpoint_drops.is_empty(), "Stage 4 should keep runtime-cleared starpoint drops empty")


func _context(stage_id: int) -> Dictionary:
	return {
		"current_stage": stage_id,
		"player_pos": Vector2(92.0, 92.0),
		"player_paddle_size": Vector2(32.0, 32.0),
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
		"height": 750.0,
		"selected_character_type": "smasher",
	}


func _make_drop(pos: Vector2, size: float) -> Dictionary:
	return {
		"pos": pos,
		"vel": Vector2.ZERO,
		"size": size,
		"rotation": 0.0,
		"rotation_speed": 0.0,
		"glow_intensity": 1.0,
		"glow_timer": 0.0,
		"life": 600.0,
		"float_timer": 0.0,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
