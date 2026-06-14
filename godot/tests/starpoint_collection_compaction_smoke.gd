extends SceneTree

const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage4BirdEvent := preload("res://scripts/stages/stage4/stage4_bird_event.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")

var _failures: Array[String] = []


class RuntimePerkStateStub:
	var collect_calls := 0
	var opens_choice := true

	func _init(_target: Object, next_opens_choice: bool = true) -> void:
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
		return opens_choice


class LingpetStarlightRuntimeStub:
	var update_calls := 0

	func update_starlight_tracking_for_starpoint_drop(_drop: Dictionary, _delta_seconds: float, _context: Dictionary = {}) -> Dictionary:
		update_calls += 1
		if update_calls == 1:
			_drop["lingpet_starlight_tracking_carrying"] = true
			return {
				"picked_up": true,
				"carrying": true,
				"claimed": true,
			}
		return {
			"delivered": true,
			"claimed": true,
		}


func _init() -> void:
	_verify_common_compaction_helpers()
	_verify_stage_sources_delegate_compaction()
	_verify_stage1_collection_preserves_remaining_drop_after_modal()
	_verify_stage1_collection_continues_without_modal()
	_verify_stage1_starlight_tracking_collects_without_player_overlap()
	_verify_stage2_collection_preserves_remaining_drop_after_modal()
	_verify_stage3_collection_preserves_remaining_drop_after_modal()
	_verify_stage4_collection_preserves_remaining_drop_after_modal()

	if _failures.is_empty():
		print("starpoint_collection_compaction_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_common_compaction_helpers() -> void:
	var drops := [
		_make_drop(Vector2(100.0, 100.0), 12.0),
		_make_drop(Vector2(110.0, 100.0), 12.0),
		_make_drop(Vector2(120.0, 100.0), 12.0),
	]
	StarpointCollectionCompaction.finish_in_place(drops, 1, 0, 3)
	_expect(drops.size() == 1, "common in-place compaction should keep tail drops after the collected index")
	_expect(_drop_pos(drops[0]) == Vector2(120.0, 100.0), "common in-place compaction should preserve the correct tail drop")

	var original := [
		_make_drop(Vector2(100.0, 100.0), 12.0),
		_make_drop(Vector2(110.0, 100.0), 12.0),
		_make_drop(Vector2(120.0, 100.0), 12.0),
	]
	var kept := [_make_drop(Vector2(90.0, 100.0), 12.0)]
	var preserved: Array = StarpointCollectionCompaction.build_preserved_after_modal(original, kept, 1, 3)
	_expect(preserved.size() == 2, "common kept-array compaction should join pre-kept drops and tail drops")
	_expect(_drop_pos(preserved[0]) == Vector2(90.0, 100.0), "common kept-array compaction should preserve prior kept drops")
	_expect(_drop_pos(preserved[1]) == Vector2(120.0, 100.0), "common kept-array compaction should preserve tail drops")


func _verify_stage_sources_delegate_compaction() -> void:
	var in_place_paths := [
		"res://scripts/stages/stage1/stage1_balloon_event.gd",
		"res://scripts/stages/stage2/stage2_pillar_background.gd",
		"res://scripts/stages/stage4/stage4_bird_event.gd",
	]
	for path in in_place_paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.find("StarpointCollectionCompaction.finish_in_place") >= 0, "%s should delegate in-place modal compaction" % path)
		_expect(source.find("func _finish_starpoint_modal_collection") < 0, "%s should not keep private modal compaction" % path)
	var stage3_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
	_expect(stage3_source.find("StarpointCollectionCompaction.build_preserved_after_modal") >= 0, "Stage 3 should delegate kept-array modal compaction")
	_expect(stage3_source.find("func _finish_starpoint_modal_collection") < 0, "Stage 3 should not keep private modal compaction")


func _verify_stage1_collection_preserves_remaining_drop_after_modal() -> void:
	var event := Stage1BalloonEvent.new()
	event.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
	]
	var runtime_state := RuntimePerkStateStub.new(event)
	event._update_starpoint_drops(0.0, _context(1), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 1 should collect exactly one starpoint before the modal opens")
	_expect(event.starpoint_drops.size() == 1, "Stage 1 should preserve remaining starpoint drops after the modal opens")
	_expect(_drop_pos(event.starpoint_drops[0]) == Vector2(110.0, 100.0), "Stage 1 should remove only the collected starpoint")


func _verify_stage1_collection_continues_without_modal() -> void:
	var event := Stage1BalloonEvent.new()
	event.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
	]
	var runtime_state := RuntimePerkStateStub.new(event, false)
	event._update_starpoint_drops(0.0, _context(1), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 2, "Stage 1 should continue normal collection when no modal opens")
	_expect(event.starpoint_drops.is_empty(), "Stage 1 should remove collected drops when no modal opens")


func _verify_stage1_starlight_tracking_collects_without_player_overlap() -> void:
	var event := Stage1BalloonEvent.new()
	event.starpoint_drops = [
		_make_drop(Vector2(320.0, 160.0), Stage1BalloonEvent.STARPOINT_DROP_SIZE),
	]
	var runtime_state := RuntimePerkStateStub.new(event, false)
	var starlight_runtime := LingpetStarlightRuntimeStub.new()
	event._update_starpoint_drops(0.0, _context(1), {
		"runtime_perk_state": runtime_state,
		"lingpet_egg_runtime": starlight_runtime,
	})
	_expect(starlight_runtime.update_calls == 1, "Stage 1 should offer live starpoint drops to the lingpet Starlight Tracking runtime")
	_expect(runtime_state.collect_calls == 0, "Starlight Tracking pickup should not grant the starpoint before player delivery")
	_expect(event.starpoint_drops.size() == 1, "Starlight Tracking should keep the carried starpoint in-flight until delivery")
	event._update_starpoint_drops(0.0, _context(1), {
		"runtime_perk_state": runtime_state,
		"lingpet_egg_runtime": starlight_runtime,
	})
	_expect(runtime_state.collect_calls == 1, "Starlight Tracking collection should grant the starpoint through the normal reward path")
	_expect(event.starpoint_drops.is_empty(), "Starlight Tracking should remove the auto-collected starpoint drop")


func _verify_stage2_collection_preserves_remaining_drop_after_modal() -> void:
	var background := Stage2PillarBackground.new()
	background.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), 12.0),
		_make_drop(Vector2(110.0, 100.0), 12.0),
	]
	var runtime_state := RuntimePerkStateStub.new(background)
	background._update_starpoint_drops(0.0, _context(2), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 2 should collect exactly one starpoint before the modal opens")
	_expect(background.starpoint_drops.size() == 1, "Stage 2 should preserve remaining starpoint drops after the modal opens")
	_expect(_drop_pos(background.starpoint_drops[0]) == Vector2(110.0, 100.0), "Stage 2 should remove only the collected starpoint")


func _verify_stage3_collection_preserves_remaining_drop_after_modal() -> void:
	var boss_state := Stage3BossSkillState.new()
	boss_state.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage3BossSkillState.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage3BossSkillState.STARPOINT_DROP_SIZE),
	]
	var runtime_state := RuntimePerkStateStub.new(boss_state)
	boss_state._update_starpoint_drops(0.0, _context(3), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 3 should collect exactly one starpoint before the modal opens")
	_expect(boss_state.starpoint_drops.size() == 1, "Stage 3 should preserve remaining starpoint drops after the modal opens")
	_expect(_drop_pos(boss_state.starpoint_drops[0]) == Vector2(110.0, 100.0), "Stage 3 should remove only the collected starpoint")


func _verify_stage4_collection_preserves_remaining_drop_after_modal() -> void:
	var event := Stage4BirdEvent.new()
	event.starpoint_drops = [
		_make_drop(Vector2(100.0, 100.0), Stage4BirdEvent.STARPOINT_DROP_SIZE),
		_make_drop(Vector2(110.0, 100.0), Stage4BirdEvent.STARPOINT_DROP_SIZE),
	]
	var runtime_state := RuntimePerkStateStub.new(event)
	event._update_starpoint_drops(0.0, _context(4), {"runtime_perk_state": runtime_state})
	_expect(runtime_state.collect_calls == 1, "Stage 4 should collect exactly one starpoint before the modal opens")
	_expect(event.starpoint_drops.size() == 1, "Stage 4 should preserve remaining starpoint drops after the modal opens")
	_expect(_drop_pos(event.starpoint_drops[0]) == Vector2(110.0, 100.0), "Stage 4 should remove only the collected starpoint")


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


func _drop_pos(drop: Dictionary) -> Vector2:
	var value: Variant = drop.get("pos", Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
