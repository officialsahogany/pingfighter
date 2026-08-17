extends SceneTree

# expect-zero-object-leaks

const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage3StarpointState := preload("res://scripts/stages/stage3/stage3_starpoint_state.gd")

const HOST_PATH := "res://scripts/stages/stage3/stage3_boss_skill_state.gd"

var _failures: Array[String] = []


class FakeRuntimePerkState:
	extends RefCounted
	var open_choice := false
	var calls: Array[Dictionary] = []

	func collect_star_points(amount: int, character_type: String, catalog: Object, owner: Object, registry: Object) -> bool:
		calls.append({
			"amount": amount,
			"character_type": character_type,
			"catalog": catalog,
			"owner": owner,
			"registry": registry,
		})
		return open_choice


class FakeAudio:
	extends RefCounted
	var collect_count := 0

	func play_starpoint_collect() -> void:
		collect_count += 1


class FakeOwner:
	extends RefCounted
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeMythicRuntime:
	extends RefCounted
	var bonus_count := 0
	var roll_count := 0

	func roll_star_detector_bonus_drop_count() -> int:
		roll_count += 1
		return bonus_count


func _init() -> void:
	_verify_shared_rng_spawn_order()
	_verify_detector_bonus_and_caps()
	_verify_collection_and_modal_compaction()
	_verify_snapshot_copy_and_clear_contract()
	_verify_host_tail_hit_routes_live_owner()
	_verify_host_delegates_starpoint_ownership()
	if _failures.is_empty():
		print("stage3_starpoint_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_shared_rng_spawn_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3303
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 3303
	var state := Stage3StarpointState.new(rng)
	var ball_pos := Vector2(390.0, 375.0)
	var context := {"playfield_left": 0.0, "playfield_right": 760.0, "height": 750.0}
	var expected_pos := Vector2(
		clamp(
			ball_pos.x + float(expected_rng.randi_range(-30, 30)),
			StagePlayfieldBounds.get_left(context) + Stage3StarpointState.STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_right(context, Stage3StarpointState.FIELD_WIDTH) - Stage3StarpointState.STARPOINT_DROP_SIZE
		),
		clamp(
			ball_pos.y + float(expected_rng.randi_range(-30, 30)),
			Stage3StarpointState.STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_height(context, Stage3StarpointState.FIELD_HEIGHT) - Stage3StarpointState.STARPOINT_DROP_SIZE
		)
	)
	var expected_drop: Dictionary = StarpointPayloadFactory.build_drop(
		expected_pos,
		expected_rng,
		false,
		Stage3StarpointState.STARPOINT_DROP_SIZE,
		Stage3StarpointState.STARPOINT_DROP_LIFETIME,
		0.05,
		0.1,
		"menhera_tail"
	)
	var expected_particles: Array = StarpointPayloadFactory.build_particles(
		expected_pos,
		Stage3StarpointState.STARPOINT_PARTICLE_COUNT,
		1.0,
		expected_rng,
		Stage3StarpointState.STARPOINT_PARTICLE_LIFE
	)
	state.spawn_tail_drop(ball_pos, {}, context)
	var snapshot: Dictionary = state.get_snapshot()
	_expect(snapshot.get("stage3_starpoint_drops", []) == [expected_drop], "tail spawn should preserve position and drop-payload RNG order")
	_expect(snapshot.get("stage3_starpoint_particles", []) == expected_particles, "tail spawn should preserve particle RNG order")
	_expect(rng.randi() == expected_rng.randi(), "owner construction and spawn should consume exactly the legacy shared-RNG sequence")


func _verify_detector_bonus_and_caps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3304
	var state := Stage3StarpointState.new(rng)
	var mythic := FakeMythicRuntime.new()
	mythic.bonus_count = 2
	var context := {"playfield_left": 80.0, "playfield_right": 680.0, "height": 750.0}
	state.spawn_drop_at(Vector2(100.0, 100.0), {"mythic_item_runtime": mythic}, context)
	var bonus_snapshot: Dictionary = state.get_snapshot()
	var bonus_drops: Array = bonus_snapshot.get("stage3_starpoint_drops", [])
	_expect(mythic.roll_count == 1, "one primary drop should ask Star Detector exactly once")
	_expect(bonus_drops.size() == 3, "two Star Detector bonuses should append two drops")
	if bonus_drops.size() == 3:
		_expect(not bool((bonus_drops[0] as Dictionary).get("star_detector_bonus", true)), "primary drop should remain non-bonus")
		_expect(bool((bonus_drops[1] as Dictionary).get("star_detector_bonus", false)) and bool((bonus_drops[2] as Dictionary).get("star_detector_bonus", false)), "bonus drops should keep their bonus marker")
		for index in range(1, 3):
			var pos: Vector2 = (bonus_drops[index] as Dictionary).get("pos", Vector2.ZERO)
			_expect(pos.x >= 92.0 and pos.x <= 668.0 and pos.y >= 12.0 and pos.y <= 738.0, "bonus drop should clamp to the live playfield")

	state.clear()
	for index in range(15):
		state.spawn_drop_at(Vector2(200.0 + index, 200.0), {}, {}, false, false, "drop_%02d" % index)
	var capped: Dictionary = state.get_snapshot()
	var capped_drops: Array = capped.get("stage3_starpoint_drops", [])
	_expect(capped_drops.size() == Stage3StarpointState.MAX_STAGE3_STARPOINT_DROPS, "drop cap should retain ten newest entries")
	_expect(state.get_particle_count() == Stage3StarpointState.MAX_STAGE3_STARPOINT_PARTICLES, "particle cap should retain the newest 120 particles")
	if not capped_drops.is_empty():
		_expect(String((capped_drops[0] as Dictionary).get("source_type", "")) == "drop_05", "front compaction should discard the five oldest drops")


func _verify_collection_and_modal_compaction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3305
	var state := Stage3StarpointState.new(rng)
	state.spawn_drop_at(Vector2(100.0, 100.0), {}, {}, false, false, "first")
	state.spawn_drop_at(Vector2(300.0, 300.0), {}, {}, false, false, "collected")
	state.spawn_drop_at(Vector2(500.0, 500.0), {}, {}, false, false, "last")
	var runtime := FakeRuntimePerkState.new()
	runtime.open_choice = true
	var audio := FakeAudio.new()
	var owner := FakeOwner.new()
	var catalog := RefCounted.new()
	var registry := RefCounted.new()
	state.update(0.0, {
		"player_pos": Vector2(285.0, 285.0),
		"player_paddle_size": Vector2(30.0, 30.0),
		"selected_character_type": "viper",
		"owner": owner,
		"registry": registry,
	}, {
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"audio": audio,
	})
	var remaining: Array = state.get_snapshot().get("stage3_starpoint_drops", [])
	_expect(runtime.calls.size() == 1, "overlap should collect exactly one starpoint before modal suspension")
	if runtime.calls.size() == 1:
		var call: Dictionary = runtime.calls[0]
		_expect(int(call.get("amount", 0)) == 1 and String(call.get("character_type", "")) == "viper", "collection should forward amount and character")
		_expect(call.get("catalog", null) == catalog and call.get("owner", null) == owner and call.get("registry", null) == registry, "collection should forward live reward dependencies")
	_expect(audio.collect_count == 1 and owner.redraw_count == 1, "collection should play one cue and request one redraw")
	_expect(remaining.size() == 2, "modal collection should preserve unprocessed drops")
	if remaining.size() == 2:
		_expect(String((remaining[0] as Dictionary).get("source_type", "")) == "first" and String((remaining[1] as Dictionary).get("source_type", "")) == "last", "modal compaction should preserve before/after order")


func _verify_snapshot_copy_and_clear_contract() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3306
	var state := Stage3StarpointState.new(rng)
	state.spawn_drop_at(Vector2(200.0, 200.0), {}, {}, false)
	var borrowed: Dictionary = state.get_actor_draw_context(false)
	var borrowed_drops: Array = borrowed.get("stage3_starpoint_drops", [])
	(borrowed_drops[0] as Dictionary)["pos"] = Vector2(210.0, 210.0)
	_expect((state.get_snapshot().get("stage3_starpoint_drops", [])[0] as Dictionary).get("pos", Vector2.ZERO) == Vector2(210.0, 210.0), "default draw context should preserve the legacy borrowed-array contract")
	var copied: Dictionary = state.get_actor_draw_context(true)
	(copied.get("stage3_starpoint_drops", [])[0] as Dictionary)["pos"] = Vector2.ZERO
	_expect((state.get_snapshot().get("stage3_starpoint_drops", [])[0] as Dictionary).get("pos", Vector2.ZERO) == Vector2(210.0, 210.0), "copy_arrays should deep-copy the public snapshot")
	_expect(state.has_runtime_state(), "spawned drops and particles should count as runtime state")
	state.clear()
	_expect(not state.has_runtime_state() and state.get_drop_count() == 0 and state.get_particle_count() == 0, "clear should empty both owner arrays")


func _verify_host_tail_hit_routes_live_owner() -> void:
	var state := Stage3BossSkillState.new()
	state.force_kuromi_awake()
	state.set("kuromi_eating_cooldown", 10.0)
	state.set("tail_whip_active", true)
	state.set("tail_whip_timer", 0.5)
	state.set("tail_whip_target", Vector2(390.0, 375.0))
	state.set("tail_has_target", true)
	state.update(1.0 / 60.0, {
		"current_stage": 3,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(390.0, 375.0),
		"ball_vel": Vector2(10.0, 0.0),
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_size": Vector2(110.0, 18.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_score": 2,
	}, {})
	var drops: Array = state.get_snapshot().get("stage3_starpoint_drops", [])
	_expect(drops.size() == 1, "live Stage 3 tail hit should route one drop through the focused owner")
	if drops.size() == 1:
		_expect(String((drops[0] as Dictionary).get("source_type", "")) == "menhera_tail", "live tail hit should preserve its source tag")


func _verify_host_delegates_starpoint_ownership() -> void:
	var source := FileAccess.get_file_as_string(HOST_PATH)
	var update_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_update_coordinator.gd")
	_expect(source.contains("const Stage3StarpointState := preload("), "Stage 3 host should preload the starpoint owner")
	_expect(source.contains("var _starpoint_state: Object = null"), "Stage 3 host should retain one starpoint owner")
	var fracture_init: int = source.find("_kuromi_awakening_state = Stage3KuromiAwakeningState.new(rng)")
	var starpoint_init: int = source.find("_starpoint_state = Stage3StarpointState.new(rng)")
	_expect(fracture_init >= 0 and fracture_init < starpoint_init, "awakening owner insertion should preserve the existing fracture-before-starpoint RNG construction order")
	_expect(update_source.contains("_starpoint_state.update(clamped_delta * 60.0, context, deps)"), "Stage 3 update should delegate drop and particle motion")
	_expect(FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_handoff_coordinator.gd").contains("_starpoint_state.spawn_tail_drop(ball_pos, deps, context)"), "tail handoff should delegate its synchronous Starpoint spawn")
	_expect(FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_context_builder.gd").contains("context.merge(_starpoint_state.get_actor_draw_context(copy_arrays), true)"), "context builder should consume the Starpoint owner snapshot")
	_expect(FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_lifecycle.gd").contains("_starpoint_state.clear()"), "round reset lifecycle should clear the owner")
	_expect(update_source.contains("_starpoint_state.hide_all_existing_visual_hosts()"), "stage leave should retain detached visual-host cleanup")
	_expect(not source.contains("var starpoint_drops:"), "Stage 3 host should not restore a drop-array mirror")
	_expect(not source.contains("var starpoint_particles:"), "Stage 3 host should not restore a particle-array mirror")
	_expect(not source.contains("func _update_starpoint_drops("), "Stage 3 host should not restore drop lifecycle logic")
	_expect(not source.contains("const StarpointPayloadFactory := preload("), "Stage 3 host should not retain starpoint payload construction")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
