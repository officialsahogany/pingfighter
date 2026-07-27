extends SceneTree

const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const LingpetBoneBarrierSkill := preload("res://scripts/lingpet/lingpet_bone_barrier_skill.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

const SKILL_ID := "nekuring_bone_barrier"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(0.0, 9.0)
	var ball_size := 28.6


class FakeAudio:
	extends RefCounted

	var build_count := 0
	var break_count := 0
	var build_break_count := 0
	var skeleton_fallback_count := 0
	var active_item_count := 0

	func play_lingpet_bone_barrier_build() -> void:
		build_count += 1

	func play_lingpet_bone_barrier_break() -> void:
		break_count += 1

	func play_lingpet_bone_barrier_build_break() -> void:
		build_break_count += 1

	func play_lingpet_skeleton_archer_summon() -> void:
		skeleton_fallback_count += 1

	func play_active_item() -> void:
		active_item_count += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


func _init() -> void:
	seed(20260618)
	_verify_catalog_dispatcher_audio_and_host_wiring()
	_verify_level_scaling_widths_and_bonus_barrier_chance()
	_verify_build_animation_progress_spans_full_duration()
	_verify_building_barrier_breaks_without_reflection()
	_verify_built_barrier_reflects_and_notifies_audio()
	_verify_ball_motion_collision_context()
	_verify_barrier_count_is_capped_with_silent_oldest_eviction()

	if _failures.is_empty():
		print("lingpet_bone_barrier_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_dispatcher_audio_and_host_wiring() -> void:
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_bone_barrier_skill.gd"), "Bone Barrier skill module should exist")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_bone_barrier_payload_factory.gd"), "Bone Barrier payload factory should exist")
	_expect(LingpetSkillDispatcher.is_supported_kind("bone_barrier"), "dispatcher should support the bone_barrier runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "Nekuring Bone Barrier should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_bone_barrier(SKILL_ID), "dispatcher should expose a Bone Barrier helper")
	_expect(not LingpetSkillDispatcher.skills_share_exclusive_resource(SKILL_ID, "rabi_ghost_summon"), "Bone Barrier should not claim ball ownership")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not skill.is_empty(), "Nekuring catalog should expose Bone Barrier metadata")
	_expect(str(skill.get("runtime_kind", "")) == "bone_barrier", "Bone Barrier metadata should use the bone_barrier runtime kind")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 21.0), "Bone Barrier cooldown should preserve the original Necro 21s cooldown")
	_expect(is_equal_approx(float(skill.get("windup_seconds", -1.0)), 0.0), "Bone Barrier should launch immediately and let its 3s build animation carry the delay")
	_expect(is_equal_approx(float(skill.get("build_time", 0.0)), 3.0), "Bone Barrier metadata should expose the original 3s build time")
	_expect(skill.has("barrier_width_by_level"), "Bone Barrier metadata should expose level-scaled width values")
	_expect(skill.has("bonus_barrier_chance_pct_by_level"), "Bone Barrier metadata should expose level-scaled bonus barrier chances")
	var nekuring_skill_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("nekuring"))
	_expect(not nekuring_skill_ids.has("nekuring_ghost_summon"), "Nekuring active pool should remove Skeleton Summon")
	_expect(nekuring_skill_ids.has("nekuring_skeleton_archer"), "Nekuring active pool should keep Skeleton Archer")
	_expect(nekuring_skill_ids.has(SKILL_ID), "Nekuring active pool should add Bone Barrier")

	var spec := GameplayModuleCatalog.new().get_spec("lingpet_bone_barrier_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_bone_barrier_payload_factory.gd", "module catalog should list the Bone Barrier payload factory")

	var audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(audio_source.find("LINGPET_BONE_BARRIER_BUILD_SOUND_PATH") >= 0, "game audio should define a dedicated Bone Barrier build cue")
	_expect(audio_source.find("func play_lingpet_bone_barrier_break") >= 0, "game audio should expose a dedicated Bone Barrier break cue")

	var host_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	_expect(host_source.find("draw.lingpet.bone_barrier") >= 0, "Bone Barrier draw should expose a focused BattlePerf sample label")
	_expect(host_source.find("lingpet.bone_barrier.barriers") >= 0, "Bone Barrier draw should expose barrier-count perf counters")
	_expect(host_source.find("get_ball_collision_context") >= 0, "runtime host should expose Bone Barrier ball collision context")

	var host := LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	host.set_bone_barrier_x_values_for_tests([320.0])
	_expect(host.launch(SKILL_ID, Vector2(380.0, 680.0), owner, {"registry": registry}), "runtime host should launch Nekuring Bone Barrier")
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.build_count == 1, "Bone Barrier launch should play the original bonemake3 build cue")
	_expect(audio.skeleton_fallback_count == 0 and audio.active_item_count == 0, "Bone Barrier launch should prefer the dedicated cue over fallbacks")
	_expect(not host.is_launch_blocked(SKILL_ID), "Bone Barrier should allow later casts while existing barriers remain alive")
	host.update(2.99, owner, registry, SKILL_ID)
	var snapshot := host.get_bone_barrier_snapshot_for_tests()
	_expect(int(snapshot.get("bone_barrier_barrier_count", 0)) == 1, "runtime host should keep the live Bone Barrier module")
	_expect(int(snapshot.get("bone_barrier_built_count", 0)) == 0, "Bone Barrier should not be built before the original 3s build time")
	host.update(0.02, owner, registry, SKILL_ID)
	snapshot = host.get_bone_barrier_snapshot_for_tests()
	_expect(int(snapshot.get("bone_barrier_built_count", 0)) == 1, "Bone Barrier should become built after 3s")
	# Relaunch policy and LIVENESS are different questions. Bone Barrier is
	# nest-allowed, so is_launch_blocked stays false while its barriers are alive
	# -- which is exactly why the companion idle-update gate must read liveness
	# from needs_runtime_update_for_skill() instead.
	_expect(not host.is_launch_blocked(SKILL_ID), "nest-allowed Bone Barrier should stay castable while its barriers are alive")
	_expect(host.needs_runtime_update_for_skill(SKILL_ID), "a live Bone Barrier must still need runtime updates even though relaunch stays allowed")
	# Round boundary preserves installed barriers (original reset_for_new_round parity).
	host.reset_round(owner, registry)
	snapshot = host.get_bone_barrier_snapshot_for_tests()
	_expect(int(snapshot.get("bone_barrier_barrier_count", 0)) == 1, "round-boundary reset should keep the installed Bone Barrier so it persists into the next round")
	_expect(host.has_visible_effects(), "Bone Barrier should still be visible after a round-boundary reset")
	# A full reset (companion change / hatch / new battle) still wipes everything.
	host.reset(owner, registry)
	_expect(not host.has_visible_effects(), "full runtime host reset should clear all live Bone Barrier visuals")


func _verify_level_scaling_widths_and_bonus_barrier_chance() -> void:
	var lv1: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 1)
	var lv2: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 2)
	var lv3: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 3)
	var lv4: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 4)
	var lv5: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 5)
	_expect(is_equal_approx(float(lv1.get("barrier_width", 0.0)), 72.0), "Bone Barrier Lv.1 width should be the -40% scaled 72px width")
	_expect(float(lv2.get("barrier_width", 0.0)) > float(lv1.get("barrier_width", 0.0)), "Bone Barrier Lv.2 width should be wider than Lv.1")
	_expect(float(lv3.get("barrier_width", 0.0)) > float(lv2.get("barrier_width", 0.0)), "Bone Barrier Lv.3 width should be wider than Lv.2")
	_expect(float(lv4.get("barrier_width", 0.0)) > float(lv3.get("barrier_width", 0.0)), "Bone Barrier Lv.4 width should be wider than Lv.3")
	_expect(is_equal_approx(float(lv5.get("barrier_width", 0.0)), 120.0), "Bone Barrier Lv.5 width should reach the -40% scaled 120px width")
	_expect(is_equal_approx(float(lv1.get("bonus_barrier_chance_pct", -1.0)), 0.0), "Bone Barrier Lv.1 should not roll a bonus barrier")
	_expect(is_equal_approx(float(lv2.get("bonus_barrier_chance_pct", -1.0)), 0.0), "Bone Barrier Lv.2 should not roll a bonus barrier")
	_expect(is_equal_approx(float(lv3.get("bonus_barrier_chance_pct", -1.0)), 20.0), "Bone Barrier Lv.3 should roll a 20 percent bonus barrier")
	_expect(is_equal_approx(float(lv4.get("bonus_barrier_chance_pct", -1.0)), 30.0), "Bone Barrier Lv.4 should roll a 30 percent bonus barrier")
	_expect(is_equal_approx(float(lv5.get("bonus_barrier_chance_pct", -1.0)), 40.0), "Bone Barrier Lv.5 should roll a 40 percent bonus barrier")

	var owner := FakeOwner.new()
	var no_bonus_skill := LingpetBoneBarrierSkill.new()
	no_bonus_skill.set_bonus_barrier_rolls_for_tests([1.0])
	no_bonus_skill.set_barrier_x_values_for_tests([260.0])
	_expect(no_bonus_skill.launch(Vector2(380.0, 680.0), owner, {"active_skill_level": 5}), "Lv.5 no-bonus fixture should launch")
	var no_bonus_snapshot := no_bonus_skill.get_snapshot()
	_expect(int(no_bonus_snapshot.get("bone_barrier_barrier_count", 0)) == 1, "Lv.5 should install one barrier when the 40 percent roll fails")
	_expect(is_equal_approx(float(no_bonus_snapshot.get("bone_barrier_width", 0.0)), 120.0), "Lv.5 runtime snapshot should expose the -40% scaled 120px barrier width")
	_expect(is_equal_approx(float(no_bonus_snapshot.get("bone_barrier_bonus_chance_pct", -1.0)), 40.0), "Lv.5 runtime snapshot should expose the 40 percent bonus barrier chance")

	var bonus_skill := LingpetBoneBarrierSkill.new()
	bonus_skill.set_bonus_barrier_rolls_for_tests([0.0])
	bonus_skill.set_barrier_x_values_for_tests([120.0, 430.0])
	_expect(bonus_skill.launch(Vector2(380.0, 680.0), owner, {"active_skill_level": 5}), "Lv.5 bonus fixture should launch")
	var bonus_snapshot := bonus_skill.get_snapshot()
	_expect(int(bonus_snapshot.get("bone_barrier_barrier_count", 0)) == 2, "Lv.5 should install two barriers when the 40 percent roll succeeds")
	_expect(int(bonus_snapshot.get("bone_barrier_bonus_barrier_count", 0)) == 1, "Lv.5 successful roll should count exactly one bonus barrier")
	var widths: Array = bonus_snapshot.get("bone_barrier_widths", []) as Array
	_expect(widths.size() == 2 and is_equal_approx(float(widths[0]), 120.0) and is_equal_approx(float(widths[1]), 120.0), "bonus barrier should use the same level-scaled width as the primary barrier")


func _verify_build_animation_progress_spans_full_duration() -> void:
	var early := LingpetBoneBarrierSkill._get_build_segment_adjusted_progress(1.14, 0.0)
	var mid := LingpetBoneBarrierSkill._get_build_segment_adjusted_progress(2.10, 0.0)
	var delayed_early := LingpetBoneBarrierSkill._get_build_segment_adjusted_progress(1.14, 0.60)
	var delayed_late := LingpetBoneBarrierSkill._get_build_segment_adjusted_progress(2.70, 0.60)
	_expect(early > 0.30 and early < 0.50, "Bone Barrier build animation should not finish during the old 38 percent timing window")
	_expect(mid > early and mid < 1.0, "Bone Barrier build animation should continue progressing after the old pause point")
	_expect(delayed_early < early, "Bone Barrier delayed segments should trail earlier segments instead of snapping into place")
	_expect(delayed_late > delayed_early and delayed_late < 1.0, "Bone Barrier delayed segments should keep moving until late in the 3s build")
	_expect(is_equal_approx(LingpetBoneBarrierSkill._get_build_segment_adjusted_progress(3.0, 0.60), 1.0), "Bone Barrier segments should complete exactly at the original 3s build time")


func _verify_building_barrier_breaks_without_reflection() -> void:
	var skill := LingpetBoneBarrierSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	_expect(skill.launch(Vector2(380.0, 680.0), owner, {"registry": registry, "barrier_x": 320.0}), "building break fixture should launch")
	skill.update(0.20, owner, registry)
	owner.ball_pos = Vector2(380.0, 724.0)
	owner.ball_vel = Vector2(3.0, 9.0)
	var detector := BallMotionCollisionDetector.new()
	var event := detector.check_lingpet_bone_barrier(owner.ball_pos, owner.ball_vel, owner.ball_size, skill.get_ball_collision_context())
	_expect(str(event.get("event", "")) == "lingpet_bone_barrier", "unfinished Bone Barrier should be detected by the ball-motion collision path")
	_expect(not bool(event.get("built", true)), "unfinished Bone Barrier event should preserve built=false")
	_expect(_as_vector2(event.get("ball_vel", Vector2.ZERO), Vector2.ZERO) == owner.ball_vel, "unfinished Bone Barrier event should not alter the downward velocity")
	_expect(skill.notify_ball_collision(
		int(event.get("barrier_id", 0)),
		_as_vector2(event.get("impact_pos", Vector2.ZERO), Vector2.ZERO),
		_as_vector2(event.get("ball_vel", owner.ball_vel), owner.ball_vel),
		bool(event.get("built", false)),
		registry
	), "unfinished Bone Barrier notify should consume the barrier")
	var snapshot := skill.get_snapshot()
	_expect(int(snapshot.get("bone_barrier_barrier_count", -1)) == 0, "unfinished Bone Barrier should be consumed when the ball hits it")
	_expect(int(snapshot.get("bone_barrier_build_break_count", 0)) == 1, "unfinished Bone Barrier hit should count as a build break")
	_expect(int(snapshot.get("bone_barrier_reflect_count", 0)) == 0, "unfinished Bone Barrier should not reflect the ball")
	_expect(owner.ball_vel.y > 0.0, "unfinished Bone Barrier should leave the downward ball velocity intact")
	_expect(audio.build_break_count == 1, "unfinished Bone Barrier should play the original shurikenhit build-break cue")


func _verify_built_barrier_reflects_and_notifies_audio() -> void:
	var skill := LingpetBoneBarrierSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	_expect(skill.launch(Vector2(380.0, 680.0), owner, {"registry": registry, "barrier_x": 320.0}), "built reflect fixture should launch")
	skill.update(3.01, owner, registry)
	owner.ball_pos = Vector2(380.0, 724.0)
	owner.ball_vel = Vector2(3.0, 9.0)
	var detector := BallMotionCollisionDetector.new()
	var event := detector.check_lingpet_bone_barrier(owner.ball_pos, owner.ball_vel, owner.ball_size, skill.get_ball_collision_context())
	var next_vel := _as_vector2(event.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_expect(str(event.get("event", "")) == "lingpet_bone_barrier", "built Bone Barrier should be detected by the ball-motion collision path")
	_expect(bool(event.get("built", false)), "built Bone Barrier event should preserve built=true")
	_expect(next_vel.y < 0.0, "built Bone Barrier detector should reflect a downward ball upward")
	_expect(next_vel.length() > 9.0, "built Bone Barrier detector should keep the original 1.05 speed boost shape")
	_expect(skill.notify_ball_collision(
		int(event.get("barrier_id", 0)),
		_as_vector2(event.get("impact_pos", Vector2.ZERO), Vector2.ZERO),
		next_vel,
		true,
		registry
	), "built Bone Barrier notify should consume the barrier")
	var snapshot := skill.get_snapshot()
	_expect(int(snapshot.get("bone_barrier_reflect_count", 0)) == 1, "built Bone Barrier should count a reflected hit")
	_expect(int(snapshot.get("bone_barrier_barrier_count", -1)) == 0, "built Bone Barrier should be consumed after one reflect")
	_expect(audio.break_count == 1, "built Bone Barrier should play the original bonebreak cue")


func _verify_ball_motion_collision_context() -> void:
	var skill := LingpetBoneBarrierSkill.new()
	var owner := FakeOwner.new()
	_expect(skill.launch(Vector2(380.0, 680.0), owner, {"barrier_x": 320.0}), "collision context fixture should launch")
	skill.update(3.01, owner, null)
	var context := skill.get_ball_collision_context()
	_expect(bool(context.get("lingpet_bone_barrier_active", false)), "Bone Barrier should publish an active ball collision context")
	var detector := BallMotionCollisionDetector.new()
	var event := detector.check_lingpet_bone_barrier(
		Vector2(380.0, 724.0),
		Vector2(4.0, 10.0),
		28.6,
		context
	)
	_expect(str(event.get("event", "")) == "lingpet_bone_barrier", "ball detector should emit a Bone Barrier event before score")
	_expect(bool(event.get("built", false)), "ball detector event should preserve the built flag")
	_expect(_as_vector2(event.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y < 0.0, "ball detector should provide the reflected ball velocity")

	var event_processor_source := FileAccess.get_file_as_string("res://scripts/ball/ball_motion_event_processor.gd")
	var egg_runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(event_processor_source.find("notify_lingpet_bone_barrier_hit") >= 0, "ball event processor should notify the lingpet runtime when the barrier is hit")
	_expect(egg_runtime_source.find("func get_ball_collision_context") >= 0, "lingpet runtime should publish skill collision context to the ball step")


func _verify_barrier_count_is_capped_with_silent_oldest_eviction() -> void:
	var cap := int(LingpetBoneBarrierSkill.MAX_ACTIVE_BARRIERS)
	_expect(cap == 8, "Bone Barrier active cap should stay locked to the approved 8-barrier limit")
	var skill := LingpetBoneBarrierSkill.new()
	var owner := FakeOwner.new()
	var casts := cap + 12
	var forced_xs: Array[float] = []
	for index in range(casts):
		forced_xs.append(40.0 + float(index % cap) * 82.0)
	skill.set_barrier_x_values_for_tests(forced_xs)
	for index in range(casts):
		_expect(
			skill.launch(Vector2(380.0, 680.0), owner, {"active_skill_level": 1}),
			"Bone Barrier over-cap cast %d should launch" % index
		)
	var snapshot := skill.get_snapshot()
	_expect(int(snapshot.get("bone_barrier_barrier_count", 0)) == cap, "Bone Barrier should silently cap live installed barriers at 8")
	_expect(int(snapshot.get("bone_barrier_build_count", 0)) == casts, "silent cap eviction should still count every successful cast")
	_expect(int(snapshot.get("bone_barrier_dying_count", -1)) == 0, "silent cap eviction should not create death fragments")
	var ids: Array = snapshot.get("bone_barrier_barrier_ids", []) as Array
	_expect(ids.size() == cap, "Bone Barrier snapshot should expose the capped live ids")
	if ids.size() == cap:
		_expect(int(ids[0]) == casts - cap + 1, "Bone Barrier cap should evict the oldest barrier first")
		_expect(int(ids[ids.size() - 1]) == casts, "Bone Barrier cap should keep the newest barrier")
	skill.reset_round()
	snapshot = skill.get_snapshot()
	_expect(int(snapshot.get("bone_barrier_barrier_count", 0)) == cap, "round-boundary reset should preserve only the capped barrier set")
	skill.reset()
	_expect(int(skill.get_snapshot().get("bone_barrier_barrier_count", -1)) == 0, "full reset should still clear capped barriers")


func _skill_ids(pool: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry in pool:
		ids.append(str(entry.get("id", "")))
	return ids


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
