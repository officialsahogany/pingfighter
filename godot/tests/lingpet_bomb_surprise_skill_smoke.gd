extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(0.0, 12.0)
	var ball_size := 28.6
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		var status_call := {
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		}
		calls.append(status_call)
		return status_call

	func get_calls_for_source(source: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in calls:
			if str(status_call.get("source", "")) == source:
				matches.append(status_call)
		return matches


class FakeMovementState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace := false
	var last_cleansable := false

	func start_knockback(
		velocity: float,
		frames: float = 18.0,
		decay_per_frame: float = 0.92,
		replace_current: bool = false,
		cleansable: bool = true
	) -> bool:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay_per_frame
		last_replace = replace_current
		last_cleansable = cleansable
		return true


class FakeAudio:
	extends RefCounted

	var active_item_count := 0
	var grenade_count := 0
	var weak_count := 0
	var bomb_attach_count := 0
	var bomb_transfer_count := 0
	var bomb_tick1_count := 0
	var bomb_tick2_count := 0
	var bomb_urgent_tick_count := 0
	var bomb_urgent_stop_count := 0
	var bomb_explosion_count := 0
	var bomb_self_explosion_count := 0
	var last_tick_ratio := 0.0

	func play_active_item() -> void:
		active_item_count += 1

	func play_grenade_explosion() -> void:
		grenade_count += 1

	func play_stage3_curse_explode() -> void:
		weak_count += 1

	func play_bomb_surprise_attach() -> void:
		bomb_attach_count += 1

	func play_bomb_surprise_transfer() -> void:
		bomb_transfer_count += 1

	func play_bomb_surprise_tick(use_second_tick: bool, fuse_ratio: float) -> void:
		last_tick_ratio = fuse_ratio
		if use_second_tick:
			bomb_tick2_count += 1
		else:
			bomb_tick1_count += 1

	func play_bomb_surprise_urgent_tick() -> void:
		bomb_urgent_tick_count += 1

	func stop_bomb_surprise_urgent_tick() -> void:
		bomb_urgent_stop_count += 1

	func play_bomb_surprise_explosion(self_explosion: bool) -> void:
		stop_bomb_surprise_urgent_tick()
		if self_explosion:
			bomb_self_explosion_count += 1
		else:
			bomb_explosion_count += 1


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


func _init() -> void:
	_verify_dispatcher_and_catalog()
	_verify_attachment_tracks_ball_and_transfers()
	_verify_enemy_side_explosion()
	_verify_player_side_self_explosion()
	_verify_level_scaling_outcomes()
	_verify_self_rescue_reroute_outcomes()

	if _failures.is_empty():
		print("lingpet_bomb_surprise_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("bomb_surprise"), "Bomb Surprise should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime("volty_bomb_surprise"), "Volty Bomb Surprise should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_bomb_surprise("volty_bomb_surprise"), "dispatcher should expose a Bomb Surprise helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry("volty_bomb_surprise")
	_expect(not skill.is_empty(), "Volty catalog should expose Bomb Surprise metadata")
	_expect(str(skill.get("runtime_kind", "")) == "bomb_surprise", "Volty Bomb Surprise metadata should use the bomb_surprise runtime kind")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 60.0), "Volty Bomb Surprise should use the requested 60-second cooldown")
	_expect(str(skill.get("name", "")) == "폭탄 서프라이즈", "Volty active skill should keep the requested Korean name")
	_expect(str(skill.get("description", "")).find("레벨이 오를수록") >= 0, "Volty Bomb Surprise description should expose level scaling")
	var lv1_skill: Dictionary = LingpetCatalog.get_active_skill("volty", "volty_bomb_surprise", 1)
	var lv5_skill: Dictionary = LingpetCatalog.get_active_skill("volty", "volty_bomb_surprise", 5)
	_expect(is_equal_approx(float(lv1_skill.get("cooldown", 0.0)), 60.0), "Bomb Surprise Lv.1 cooldown should keep the 60-second baseline")
	_expect(is_equal_approx(float(lv5_skill.get("cooldown", 0.0)), 42.0), "Bomb Surprise Lv.5 cooldown should use the explicit 42-second table value")
	_expect(bool(lv5_skill.get("cooldown_by_level_authoritative", false)), "Bomb Surprise cooldown_by_level should be authoritative")
	_expect(is_equal_approx(float(lv5_skill.get("active_skill_level_cooldown_reduction_pct", -1.0)), 0.0), "Bomb Surprise explicit cooldown table should disable generic cooldown reduction double-dip")
	for path in [
		"res://assets/sounds/boomstart.wav",
		"res://assets/sounds/spiderminesetup.wav",
		"res://assets/sounds/ticking1.wav",
		"res://assets/sounds/ticking2.wav",
		"res://assets/sounds/ticking3.wav",
		"res://assets/sounds/grenade.wav",
		"res://assets/sounds/weakexplosion.wav",
	]:
		_expect(FileAccess.file_exists(path), "Godot should ship the original Bomb Surprise sound asset: %s" % path)
	var game_audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(game_audio_source.find("play_bomb_surprise_attach") >= 0, "game audio should expose the original Bomb Surprise attach sound")
	_expect(game_audio_source.find("play_bomb_surprise_tick") >= 0, "game audio should expose the original alternating Bomb Surprise ticking sounds")
	_expect(game_audio_source.find("play_bomb_surprise_urgent_tick") >= 0 and game_audio_source.find("stop_bomb_surprise_urgent_tick") >= 0, "game audio should expose the original final urgent tick channel")
	_expect(game_audio_source.find("play_bomb_surprise_explosion") >= 0, "game audio should expose the original strong/weak Bomb Surprise explosion sounds")


func _verify_attachment_tracks_ball_and_transfers() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
	})
	var launch_origin := Vector2(300.0, 600.0)
	owner.ball_pos = Vector2(220.0, 420.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	_expect(host.launch("volty_bomb_surprise", launch_origin, owner, {"fuse_seconds": 4.0, "companion_pos": launch_origin}), "runtime host should launch Volty Bomb Surprise")
	host.trigger_launch_feedback("volty_bomb_surprise", registry)
	_expect(audio.bomb_attach_count == 1 and audio.active_item_count == 0, "Bomb Surprise launch feedback should use the original boomstart attach sound instead of the generic active-item sound")
	var snapshot: Dictionary = host.get_snapshot()
	_expect(str(snapshot.get("bomb_surprise_phase", "")) == "fly_to_ball", "Bomb Surprise should start by flying the real companion body to the ball")
	_expect(bool(snapshot.get("bomb_surprise_companion_override_active", false)), "Bomb Surprise should override the real companion body during the launch flight")
	_expect(_vector2_close(snapshot.get("bomb_surprise_body_pos", Vector2.ZERO), launch_origin, 0.1), "Bomb Surprise launch flight should start at the companion body position")
	_expect(host.has_companion_position_override("volty_bomb_surprise"), "runtime host should expose the Bomb Surprise body override")
	_expect(host.suppresses_companion_body_hit("volty_bomb_surprise"), "Bomb Surprise should suppress ordinary companion ball catches while the body is skill-driven")

	host.update(0.40, owner, registry, "volty_bomb_surprise")
	snapshot = host.get_snapshot()
	_expect(str(snapshot.get("bomb_surprise_phase", "")) == "attached", "Bomb Surprise should attach after the companion reaches the ball")
	_expect(str(snapshot.get("bomb_surprise_location", "")) == "ball", "Bomb Surprise should attach to the ball after the flight")
	_expect(bool(snapshot.get("bomb_surprise_attached_active", false)), "Bomb Surprise should publish the attached phase separately from the travel phase")
	_expect(_vector2_close(snapshot.get("bomb_surprise_body_pos", Vector2.ZERO), owner.ball_pos, 0.1), "attached Bomb Surprise should put the real companion body on the live ball position")
	_expect(_vector2_close(snapshot.get("bomb_surprise_attached_pos", Vector2.ZERO), owner.ball_pos, 0.1), "attached Bomb Surprise should track the live ball position")

	owner.ball_pos = Vector2(260.0, 390.0)
	host.update(0.20, owner, registry, "volty_bomb_surprise")
	snapshot = host.get_snapshot()
	_expect(_vector2_close(snapshot.get("bomb_surprise_body_pos", Vector2.ZERO), owner.ball_pos, 0.1), "attached Bomb Surprise should keep moving the companion body with the ball")

	owner.ball_vel = Vector2(0.0, -12.0)
	host.update(0.02, owner, registry, "volty_bomb_surprise")
	snapshot = host.get_snapshot()
	_expect(str(snapshot.get("bomb_surprise_location", "")) == "bottom", "bottom paddle hit should move the bomb from ball to player paddle")
	_expect(audio.bomb_transfer_count == 1, "Bomb Surprise should use the original spiderminesetup transfer sound when moving from ball to paddle")

	owner.ball_vel = Vector2(0.0, 12.0)
	host.update(0.02, owner, registry, "volty_bomb_surprise")
	snapshot = host.get_snapshot()
	_expect(str(snapshot.get("bomb_surprise_location", "")) == "bottom", "top paddle hit should not remove a bomb attached to the player paddle")

	owner.ball_vel = Vector2(0.0, -12.0)
	host.update(0.02, owner, registry, "volty_bomb_surprise")
	snapshot = host.get_snapshot()
	_expect(str(snapshot.get("bomb_surprise_location", "")) == "ball", "player paddle hit should return its attached bomb to the ball")
	_expect(audio.bomb_transfer_count == 2, "Bomb Surprise should use the transfer sound again when moving from paddle back to ball")


func _verify_enemy_side_explosion() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"status_effect_state": status_state,
		"game_audio": audio,
		"battle_feedback_state": feedback,
	})
	owner.ball_pos = Vector2(120.0, 120.0)
	owner.ball_vel = Vector2(0.0, -10.0)
	var launch_origin := Vector2(300.0, 600.0)
	_expect(host.launch("volty_bomb_surprise", launch_origin, owner, {"fuse_seconds": 0.20, "companion_pos": launch_origin}), "enemy-side fixture should launch Bomb Surprise")
	var attached_snap := _drive_until_phase(host, owner, registry, "attached", 1.0)
	_expect(str(attached_snap.get("bomb_surprise_phase", "")) == "attached", "enemy-side fixture should wait until Volty has attached to the ball before the fuse counts")
	host.update(0.21, owner, registry, "volty_bomb_surprise")

	var snapshot: Dictionary = host.get_snapshot()
	_expect(not bool(snapshot.get("bomb_surprise_active", true)), "Bomb Surprise should stop being attached once the fuse expires")
	_expect(str(snapshot.get("bomb_surprise_phase", "")) == "returning", "Bomb Surprise should fly back to the companion's launch position after exploding")
	_expect(bool(snapshot.get("bomb_surprise_companion_override_active", false)), "Bomb Surprise should keep overriding the companion body during the return flight")
	_expect(bool(snapshot.get("bomb_surprise_explosion_active", false)), "Bomb Surprise should expose an explosion flash after detonation")
	_expect(str(snapshot.get("bomb_surprise_last_target", "")) == "top", "top-half ball detonation should target the opponent side")
	_expect(not bool(snapshot.get("bomb_surprise_last_self_explosion", true)), "opponent-side detonation should be the strong explosion")
	_expect(int(snapshot.get("bomb_surprise_active_skill_level", 0)) == 1, "default Bomb Surprise launch should anchor at Lv.1")
	_expect(is_equal_approx(absf(float(snapshot.get("bomb_surprise_last_knockback_velocity", 0.0))), 52.0), "strong explosion should use the original 52px bomb knockback velocity")
	_expect(is_equal_approx(float(snapshot.get("bomb_surprise_last_stun_frames", 0.0)), 180.0), "strong explosion should apply the original 3-second stun")

	var calls: Array[Dictionary] = status_state.get_calls_for_source("volty_bomb_surprise")
	_expect(calls.size() == 1, "strong explosion should apply one shared status")
	if not calls.is_empty():
		var status_call: Dictionary = calls[0]
		_expect(str(status_call.get("target", "")) == "boss", "strong explosion should stun the boss")
		_expect(str(status_call.get("status_id", "")) == "stun", "strong explosion should use the shared stun status")
		var data: Dictionary = status_call.get("data", {}) as Dictionary
		_expect(is_equal_approx(absf(float(data.get("knockback_vel", 0.0))), 52.0), "boss status data should carry the original knockback velocity")
		_expect(is_equal_approx(float(data.get("knockback_frames", 0.0)), 18.0), "boss status data should carry the original 18-frame knockback window")
		_expect(not bool(data.get("suppress_stun_stars", false)), "Bomb Surprise boss stun should leave the normal stun-star animation enabled")
	_expect(audio.bomb_tick1_count + audio.bomb_tick2_count >= 1, "Bomb Surprise should play the original alternating ticking sound while the fuse runs")
	_expect(audio.bomb_urgent_tick_count == 1 and audio.bomb_urgent_stop_count == 1, "Bomb Surprise should start the original ticking3 urgent sound near detonation and stop it on explosion")
	_expect(audio.bomb_explosion_count == 1 and audio.bomb_self_explosion_count == 0 and audio.grenade_count == 0 and audio.weak_count == 0, "strong explosion should use the dedicated original Bomb Surprise grenade sound path")
	_expect(not feedback.shakes.is_empty() and feedback.shakes[0].y >= 1.3, "strong explosion should request a stronger screen shake")

	host.update(1.0, owner, registry, "volty_bomb_surprise")
	var returned_snapshot: Dictionary = host.get_snapshot()
	_expect(str(returned_snapshot.get("bomb_surprise_phase", "")) == "idle", "Bomb Surprise should release its body override after returning home")
	_expect(not bool(returned_snapshot.get("bomb_surprise_companion_override_active", true)), "Bomb Surprise should stop overriding the companion body after returning home")
	_expect(_vector2_close(returned_snapshot.get("bomb_surprise_body_pos", Vector2.ZERO), launch_origin, 0.1), "Bomb Surprise should return Volty to the launch position after the explosion")


func _verify_player_side_self_explosion() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var movement_state := FakeMovementState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"status_effect_state": status_state,
		"player_movement_state": movement_state,
		"game_audio": audio,
		"battle_feedback_state": feedback,
	})
	owner.ball_pos = Vector2(680.0, 640.0)
	owner.ball_vel = Vector2(0.0, 10.0)
	var launch_origin := Vector2(300.0, 600.0)
	_expect(host.launch("volty_bomb_surprise", launch_origin, owner, {"fuse_seconds": 0.20, "companion_pos": launch_origin}), "player-side fixture should launch Bomb Surprise")
	var attached_snap := _drive_until_phase(host, owner, registry, "attached", 1.0)
	_expect(str(attached_snap.get("bomb_surprise_phase", "")) == "attached", "player-side fixture should wait until Volty has attached to the ball before the fuse counts")
	host.update(0.21, owner, registry, "volty_bomb_surprise")

	var snapshot: Dictionary = host.get_snapshot()
	_expect(str(snapshot.get("bomb_surprise_last_target", "")) == "bottom", "bottom-half ball detonation should target the player side")
	_expect(bool(snapshot.get("bomb_surprise_last_self_explosion", false)), "player-side detonation should be the weak self explosion")
	_expect(int(snapshot.get("bomb_surprise_active_skill_level", 0)) == 1, "default self-explosion launch should anchor at Lv.1")
	_expect(is_equal_approx(absf(float(snapshot.get("bomb_surprise_last_knockback_velocity", 0.0))), 15.6), "weak explosion should scale the original knockback to 30 percent")
	_expect(is_equal_approx(float(snapshot.get("bomb_surprise_last_stun_frames", 0.0)), 48.0), "weak explosion should apply the original 0.8-second self stun")

	var calls: Array[Dictionary] = status_state.get_calls_for_source("volty_bomb_surprise")
	_expect(calls.size() == 1, "weak explosion should apply one shared player status")
	if not calls.is_empty():
		var status_call: Dictionary = calls[0]
		_expect(str(status_call.get("target", "")) == "player", "weak explosion should target the player")
		_expect(str(status_call.get("status_id", "")) == "stun", "weak explosion should still use the shared stun status")
	_expect(movement_state.knockback_calls == 1, "weak explosion should start player knockback")
	_expect(is_equal_approx(absf(movement_state.last_velocity), 15.6), "player knockback should use the 30 percent weak velocity")
	_expect(is_equal_approx(movement_state.last_frames, 10.0), "player knockback should use the original shortened self window")
	_expect(audio.bomb_tick1_count + audio.bomb_tick2_count >= 1, "weak Bomb Surprise detonation should still tick before exploding")
	_expect(audio.bomb_urgent_tick_count == 1 and audio.bomb_urgent_stop_count == 1, "weak Bomb Surprise detonation should stop ticking3 on explosion")
	_expect(audio.bomb_self_explosion_count == 1 and audio.bomb_explosion_count == 0 and audio.weak_count == 0 and audio.grenade_count == 0, "weak explosion should use the dedicated original weakexplosion sound path")
	_expect(not feedback.shakes.is_empty() and feedback.shakes[0].y < 1.0, "weak explosion should request a weaker screen shake")


func _verify_level_scaling_outcomes() -> void:
	var lv1_boss := _explode_level_fixture(1, false)
	_expect(int(lv1_boss.get("bomb_surprise_active_skill_level", 0)) == 1, "Lv.1 boss explosion should record active skill level 1")
	_expect(is_equal_approx(float(lv1_boss.get("bomb_surprise_last_stun_frames", 0.0)), 180.0), "Lv.1 boss explosion should stun for 180 frames")
	_expect(is_equal_approx(absf(float(lv1_boss.get("bomb_surprise_last_knockback_velocity", 0.0))), 52.0), "Lv.1 boss explosion should knock back at 52")

	var lv5_boss := _explode_level_fixture(5, false)
	_expect(int(lv5_boss.get("bomb_surprise_active_skill_level", 0)) == 5, "Lv.5 boss explosion should record active skill level 5")
	_expect(is_equal_approx(float(lv5_boss.get("bomb_surprise_last_stun_frames", 0.0)), 276.0), "Lv.5 boss explosion should stun for 276 frames")
	_expect(is_equal_approx(absf(float(lv5_boss.get("bomb_surprise_last_knockback_velocity", 0.0))), 72.0), "Lv.5 boss explosion should knock back at 72")

	var lv5_self := _explode_level_fixture(5, true)
	_expect(int(lv5_self.get("bomb_surprise_active_skill_level", 0)) == 5, "Lv.5 self explosion should record active skill level 5")
	_expect(is_equal_approx(float(lv5_self.get("bomb_surprise_last_stun_frames", 0.0)), 24.0), "Lv.5 self explosion should stun the player for 24 frames")
	_expect(is_equal_approx(absf(float(lv5_self.get("bomb_surprise_last_knockback_velocity", 0.0))), 12.96), "Lv.5 self explosion should use 72 * 0.18 knockback")


func _verify_self_rescue_reroute_outcomes() -> void:
	# Lv.5 + 강제 성공 롤: 자폭 판정이 보스 재라우팅으로 구조되어 보스쪽 폭발이 된다.
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({"status_effect_state": status_state})
	owner.ball_pos = Vector2(680.0, 640.0)
	owner.ball_vel = Vector2(0.0, 10.0)
	var launch_origin := Vector2(300.0, 600.0)
	_expect(host.launch("volty_bomb_surprise", launch_origin, owner, {
		"active_skill_level": 5,
		"fuse_seconds": 0.20,
		"self_rescue_roll": 0.0,
		"companion_pos": launch_origin,
	}), "rescue fixture should launch Bomb Surprise")
	var attached_snap := _drive_until_phase(host, owner, registry, "attached", 1.0)
	_expect(str(attached_snap.get("bomb_surprise_phase", "")) == "attached", "rescue fixture should reach the attached phase before detonation")
	_expect(is_equal_approx(float(attached_snap.get("bomb_surprise_self_rescue_chance", -1.0)), 0.40), "Lv.5 launch should cache the 40 percent self-rescue chance")
	host.update(0.21, owner, registry, "volty_bomb_surprise")
	var reroute_snap: Dictionary = host.get_snapshot()
	_expect(str(reroute_snap.get("bomb_surprise_phase", "")) == "reroute_to_boss", "rescued self-explosion should enter the boss reroute flight instead of detonating")
	_expect(bool(reroute_snap.get("bomb_surprise_reroute_active", false)), "reroute phase should be published in the snapshot")
	_expect(not bool(reroute_snap.get("bomb_surprise_explosion_active", true)), "rescued bomb should not detonate before reaching the boss")
	_expect(bool(reroute_snap.get("bomb_surprise_last_self_rescue", false)), "rescue roll success should be recorded")
	var exploded_snap := _drive_until_phase(host, owner, registry, "returning", 1.5)
	_expect(str(exploded_snap.get("bomb_surprise_phase", "")) == "returning", "rescued bomb should detonate at the boss and start returning home")
	_expect(str(exploded_snap.get("bomb_surprise_last_target", "")) == "top", "rescued detonation should target the boss side")
	_expect(not bool(exploded_snap.get("bomb_surprise_last_self_explosion", true)), "rescued detonation should be the strong boss explosion")
	_expect(is_equal_approx(float(exploded_snap.get("bomb_surprise_last_stun_frames", 0.0)), 276.0), "rescued Lv.5 detonation should apply the Lv.5 boss stun")
	_expect(is_equal_approx(absf(float(exploded_snap.get("bomb_surprise_last_knockback_velocity", 0.0))), 72.0), "rescued Lv.5 detonation should use the Lv.5 boss knockback velocity")
	var boss_center := Vector2(330.0 + 50.0, 25.0 + 20.0)
	_expect(_vector2_close(exploded_snap.get("bomb_surprise_explosion_pos", Vector2.ZERO), boss_center, 12.0), "rescued detonation should explode at the live boss position")
	var calls: Array[Dictionary] = status_state.get_calls_for_source("volty_bomb_surprise")
	_expect(calls.size() == 1 and str(calls[0].get("target", "")) == "boss", "rescued detonation should stun the boss")

	# Lv.5 + 강제 실패 롤: 구조 실패 시 기존 자폭이 그대로 일어난다.
	var fail_snap := _rescue_roll_fixture(5, 0.99)
	_expect(str(fail_snap.get("bomb_surprise_last_target", "")) == "bottom", "failed rescue roll should keep the original self-explosion")
	_expect(bool(fail_snap.get("bomb_surprise_last_self_explosion", false)), "failed rescue roll should stay a weak self explosion")
	_expect(not bool(fail_snap.get("bomb_surprise_last_self_rescue", true)), "failed rescue roll should not record a rescue")

	# Lv.1 앵커: 구조 확률 0 — 최상의 롤(0.0)에도 자폭이 유지된다(현행 밸런스 보존).
	var lv1_snap := _rescue_roll_fixture(1, 0.0)
	_expect(is_equal_approx(float(lv1_snap.get("bomb_surprise_self_rescue_chance", -1.0)), 0.0), "Lv.1 should keep a zero self-rescue chance")
	_expect(str(lv1_snap.get("bomb_surprise_last_target", "")) == "bottom", "Lv.1 should never reroute a self-explosion")
	_expect(bool(lv1_snap.get("bomb_surprise_last_self_explosion", false)), "Lv.1 self-explosion should stay the weak explosion")


func _rescue_roll_fixture(active_skill_level: int, rescue_roll: float) -> Dictionary:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.ball_pos = Vector2(680.0, 640.0)
	owner.ball_vel = Vector2(0.0, 10.0)
	var launch_origin := Vector2(300.0, 600.0)
	_expect(host.launch("volty_bomb_surprise", launch_origin, owner, {
		"active_skill_level": active_skill_level,
		"fuse_seconds": 0.20,
		"self_rescue_roll": rescue_roll,
		"companion_pos": launch_origin,
	}), "rescue roll fixture should launch Bomb Surprise")
	var attached_snap := _drive_until_phase(host, owner, registry, "attached", 1.0)
	_expect(str(attached_snap.get("bomb_surprise_phase", "")) == "attached", "rescue roll fixture should reach the attached phase before detonation")
	host.update(0.21, owner, registry, "volty_bomb_surprise")
	return host.get_snapshot()


func _explode_level_fixture(active_skill_level: int, self_explosion: bool) -> Dictionary:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.ball_pos = Vector2(680.0, 640.0) if self_explosion else Vector2(120.0, 120.0)
	owner.ball_vel = Vector2(0.0, 10.0) if self_explosion else Vector2(0.0, -10.0)
	var launch_origin := Vector2(300.0, 600.0)
	var launch_context := {
		"active_skill_level": active_skill_level,
		"fuse_seconds": 0.20,
		# 자폭 레인 검증 픽스처: Lv.2+에서 자폭 구조 롤이 확률적으로 개입하지 않도록
		# 실패 롤을 고정한다(구조 성공 레인은 _verify_self_rescue_reroute_outcomes 담당).
		"self_rescue_roll": 0.99,
		"companion_pos": launch_origin,
	}
	_expect(host.launch("volty_bomb_surprise", launch_origin, owner, launch_context), "level fixture should launch Bomb Surprise")
	var attached_snap := _drive_until_phase(host, owner, registry, "attached", 1.0)
	_expect(str(attached_snap.get("bomb_surprise_phase", "")) == "attached", "level fixture should reach the attached phase before detonation")
	host.update(0.21, owner, registry, "volty_bomb_surprise")
	return host.get_snapshot()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _drive_until_phase(host: Object, owner: Object, registry: Object, phase: String, max_seconds: float) -> Dictionary:
	var elapsed := 0.0
	var snapshot: Dictionary = host.get_snapshot()
	while elapsed < max_seconds:
		if str(snapshot.get("bomb_surprise_phase", "")) == phase:
			return snapshot
		host.update(0.05, owner, registry, "volty_bomb_surprise")
		elapsed += 0.05
		snapshot = host.get_snapshot()
	return snapshot


func _vector2_close(value: Variant, expected: Vector2, tolerance: float) -> bool:
	if not (value is Vector2):
		return false
	return (value as Vector2).distance_to(expected) <= tolerance
