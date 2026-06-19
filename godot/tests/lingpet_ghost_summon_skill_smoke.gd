extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := false
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(0.0, 10.0)
	var ball_size := 28.6
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var skip_ball_motion_step := false
	var stage3_kuromi_ball_hidden := false
	var ball_pos_prev := Vector2.ZERO
	var ball_interp_reset_requested := false


class FakeAudio:
	extends RefCounted

	var summon_count := 0
	var summon_out_count := 0
	var tongue_count := 0
	var swallow_count := 0
	var active_item_count := 0

	func play_lingpet_ghost_summon() -> void:
		summon_count += 1

	func play_lingpet_ghost_summon_out() -> void:
		summon_out_count += 1

	func play_stage3_kuromi_tongue() -> void:
		tongue_count += 1

	func play_stage3_kuromi_swallow() -> void:
		swallow_count += 1

	func play_active_item() -> void:
		active_item_count += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	_verify_dispatcher_and_catalog()
	_verify_capture_teleport_release()
	_verify_level_scaling_release_speed_and_far_teleport()
	_verify_reset_clears_held_ball()

	if _failures.is_empty():
		print("lingpet_ghost_summon_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("ghost_summon"), "ghost_summon should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime("rabi_ghost_summon"), "Rabi Ghost Summon should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_ghost_summon("rabi_ghost_summon"), "dispatcher should expose a Ghost Summon helper")
	_expect(not LingpetSkillDispatcher.has_supported_runtime("nekuring_ghost_summon"), "Nekuring should no longer expose the removed Skeleton Summon active skill")
	_expect(not LingpetSkillDispatcher.is_ghost_summon("nekuring_ghost_summon"), "removed Nekuring Skeleton Summon should not route through ghost_summon")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry("rabi_ghost_summon")
	_expect(not skill.is_empty(), "Rabi catalog should expose Ghost Summon metadata")
	_expect(str(skill.get("runtime_kind", "")) == "ghost_summon", "Rabi Ghost Summon metadata should use the ghost_summon runtime kind")
	_expect(str(skill.get("name", "")) == "유령소환", "Rabi active skill should use the requested Korean Ghost Summon name")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 40.0), "Rabi Ghost Summon should use the requested 40-second cooldown")
	var nekuring_skill: Dictionary = LingpetCatalog.get_active_skill_entry("nekuring_ghost_summon")
	_expect(nekuring_skill.is_empty(), "Nekuring catalog should not expose the removed Skeleton Summon metadata")
	_expect(FileAccess.file_exists("res://assets/sounds/bencyghost.wav"), "Godot should ship the original Banshee Ghost Summon sound")
	_expect(FileAccess.file_exists("res://assets/sounds/bencyghostout.wav"), "Godot should ship the original Banshee Ghost Summon outro sound")
	var game_audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(game_audio_source.find("play_lingpet_ghost_summon") >= 0, "game audio should expose the Rabi Ghost Summon start cue")
	_expect(game_audio_source.find("play_lingpet_ghost_summon_out") >= 0, "game audio should expose the Rabi Ghost Summon outro cue")


func _verify_capture_teleport_release() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	var origin := Vector2(380.0, 650.0)
	_expect(host.launch("rabi_ghost_summon", origin, owner, {"companion_pos": origin}), "runtime host should launch Rabi Ghost Summon")
	host.trigger_launch_feedback("rabi_ghost_summon", registry)
	_expect(audio.summon_count == 1 and audio.active_item_count == 0, "Ghost Summon launch feedback should use the original Banshee summon cue")

	host.update(0.86, owner, registry, "rabi_ghost_summon")
	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("ghost_summon_active", false)), "Ghost Summon should stay active after emergence")
	_expect(int(snapshot.get("ghost_summon_ghost_count", 0)) == 2, "Ghost Summon should spawn two ghost paddles")
	var ghost_positions: Array = snapshot.get("ghost_summon_ghost_positions", [])
	_expect(ghost_positions.size() == 2, "Ghost Summon should expose both ghost positions for runtime/UI consumers")
	if ghost_positions.is_empty() or not (ghost_positions[0] is Vector2):
		return

	owner.ball_active = true
	owner.ball_pos = ghost_positions[0]
	var swallowed_vel := Vector2(2.0, 10.0)
	owner.ball_vel = swallowed_vel
	host.update(0.016, owner, registry, "rabi_ghost_summon")
	snapshot = host.get_snapshot()
	_expect(bool(snapshot.get("ghost_summon_ball_hidden", false)), "Ghost Summon should hide the ball when a ghost eats it")
	_expect(bool(snapshot.get("ghost_summon_eating_active", false)), "Ghost Summon should expose its eating state while it owns the ball")
	_expect(owner.skip_ball_motion_step, "Ghost Summon should own the shared ball motion step while eating")
	_expect(owner.stage3_kuromi_ball_hidden, "Ghost Summon should hide the rendered ball through the shared hidden-ball flag")
	_expect(owner.ball_vel == Vector2.ZERO, "Ghost Summon should freeze the ball velocity while eating")
	_expect(host.get_ghost_summon_catch_count_for_tests() == 1, "Ghost Summon should record the catch for smoke coverage")
	_expect(audio.tongue_count == 1, "Ghost Summon catch should reuse the original tongue grab cue")

	host.update(0.72, owner, registry, "rabi_ghost_summon")
	_expect(audio.swallow_count == 1, "Ghost Summon eating should reuse the original swallow cue")
	host.update(0.85, owner, registry, "rabi_ghost_summon")
	host.update(0.31, owner, registry, "rabi_ghost_summon")
	host.update(0.41, owner, registry, "rabi_ghost_summon")
	host.update(0.02, owner, registry, "rabi_ghost_summon")
	snapshot = host.get_snapshot()
	_expect(not owner.skip_ball_motion_step, "Ghost Summon release should resume the normal ball motion step")
	_expect(not owner.stage3_kuromi_ball_hidden, "Ghost Summon release should unhide the rendered ball")
	_expect(not bool(snapshot.get("ghost_summon_ball_hidden", true)), "Ghost Summon snapshot should clear the hidden-ball state after release")
	_expect(host.get_ghost_summon_release_count_for_tests() == 1, "Ghost Summon should record one release after teleport")
	var last_release_vel: Variant = snapshot.get("ghost_summon_last_release_vel", Vector2.ZERO)
	var expected_release_vel := Vector2(swallowed_vel.x, -absf(swallowed_vel.y))
	_expect(owner.ball_vel == expected_release_vel, "Rabi Ghost Summon should spit the ball toward the opponent, not back at the player")
	_expect(last_release_vel is Vector2 and last_release_vel == expected_release_vel, "Ghost Summon snapshot should expose the opponent-facing release velocity")
	_expect(owner.ball_interp_reset_requested, "Ghost Summon release should reset ball render interpolation at the teleport exit")
	# P3 regression: launch() calls reset(), which must clear the per-cast catch/release
	# counters too -- otherwise the snapshot/debug metrics accumulate across casts.
	_expect(host.launch("rabi_ghost_summon", origin, owner, {"companion_pos": origin}), "Ghost Summon should relaunch for counter-reset coverage")
	_expect(host.get_ghost_summon_catch_count_for_tests() == 0, "relaunching Ghost Summon should reset the catch counter, not accumulate across casts")
	_expect(host.get_ghost_summon_release_count_for_tests() == 0, "relaunching Ghost Summon should reset the release counter")


func _verify_level_scaling_release_speed_and_far_teleport() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"game_audio": FakeAudio.new()})
	var origin := Vector2(380.0, 650.0)
	var skill_context := {
		"companion_pos": origin,
		"active_skill_level": 5,
	}
	_expect(host.launch("rabi_ghost_summon", origin, owner, skill_context), "Lv.5 Ghost Summon should launch for level-scaling coverage")
	host.update(0.86, owner, registry, "rabi_ghost_summon")
	var snapshot: Dictionary = host.get_snapshot()
	var ghost_positions: Array = snapshot.get("ghost_summon_ghost_positions", [])
	if ghost_positions.is_empty() or not (ghost_positions[0] is Vector2):
		_expect(false, "Lv.5 Ghost Summon coverage requires at least one emerged ghost")
		return

	owner.ball_active = true
	owner.ball_pos = ghost_positions[0]
	var swallowed_vel := Vector2(2.0, 10.0)
	owner.ball_vel = swallowed_vel
	host.update(0.016, owner, registry, "rabi_ghost_summon")
	snapshot = host.get_snapshot()
	_expect(int(snapshot.get("ghost_summon_active_skill_level", 0)) == 5, "Ghost Summon should keep the launch active-skill level")
	_expect(is_equal_approx(float(snapshot.get("ghost_summon_release_speed_multiplier", 0.0)), 2.25), "Lv.5 Ghost Summon should expose the boosted release-speed multiplier")
	_expect(is_equal_approx(float(snapshot.get("ghost_summon_far_teleport_chance", 0.0)), 1.0), "Lv.5 Ghost Summon should guarantee a far boss-X teleport roll")

	host.update(0.72, owner, registry, "rabi_ghost_summon")
	host.update(0.85, owner, registry, "rabi_ghost_summon")
	host.update(0.31, owner, registry, "rabi_ghost_summon")
	host.update(0.41, owner, registry, "rabi_ghost_summon")
	host.update(0.02, owner, registry, "rabi_ghost_summon")
	snapshot = host.get_snapshot()
	_expect(owner.ball_vel.y < 0.0, "Lv.5 Ghost Summon should still fire toward the opponent")
	_expect(owner.ball_vel.length() > swallowed_vel.length() * 2.0, "Lv.5 Ghost Summon release speed should exceed double the swallowed ball speed")
	var last_release_pos: Variant = snapshot.get("ghost_summon_last_release_pos", Vector2.ZERO)
	var far_min_distance := float(snapshot.get("ghost_summon_far_teleport_min_distance", 0.0))
	var boss_center_x := owner.boss_pos.x + owner.boss_paddle_width * 0.5
	if last_release_pos is Vector2:
		var release_pos: Vector2 = last_release_pos
		_expect(absf(release_pos.x - boss_center_x) >= far_min_distance - 0.01, "Lv.5 Ghost Summon should release from a far X offset from the boss")
	else:
		_expect(false, "Lv.5 Ghost Summon should expose a Vector2 release position")


func _verify_reset_clears_held_ball() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"game_audio": FakeAudio.new()})
	var origin := Vector2(380.0, 650.0)
	_expect(host.launch("rabi_ghost_summon", origin, owner, {"companion_pos": origin}), "runtime host should launch Ghost Summon for reset coverage")
	host.update(0.86, owner, registry, "rabi_ghost_summon")
	var snapshot: Dictionary = host.get_snapshot()
	var ghost_positions: Array = snapshot.get("ghost_summon_ghost_positions", [])
	if ghost_positions.is_empty() or not (ghost_positions[0] is Vector2):
		_expect(false, "Ghost Summon reset coverage requires at least one emerged ghost")
		return
	owner.ball_active = true
	owner.ball_pos = ghost_positions[0]
	owner.ball_vel = Vector2(1.0, 9.0)
	host.update(0.016, owner, registry, "rabi_ghost_summon")
	_expect(owner.skip_ball_motion_step and owner.stage3_kuromi_ball_hidden, "Ghost Summon reset setup should hold the ball")
	host.reset(owner, registry)
	snapshot = host.get_snapshot()
	_expect(not owner.skip_ball_motion_step, "Ghost Summon reset should clear a held shared ball motion step")
	_expect(not owner.stage3_kuromi_ball_hidden, "Ghost Summon reset should clear the shared hidden-ball flag")
	_expect(not host.has_visible_effects(), "Ghost Summon reset should remove active and lingering visual effects")
	_expect(not bool(snapshot.get("ghost_summon_active", false)), "Ghost Summon reset snapshot should no longer report active state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
