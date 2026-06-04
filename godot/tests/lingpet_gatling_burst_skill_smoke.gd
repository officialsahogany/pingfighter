extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(380.0, 360.0)
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeAudio:
	extends RefCounted

	var transform_count := 0
	var fire_count := 0
	var hit_count := 0
	var commando_bullet_impact_count := 0
	var commando_firearm_impact_calls: Array[String] = []
	var loop_start_count := 0
	var loop_stop_count := 0
	var active_item_count := 0

	func play_active_item() -> void:
		active_item_count += 1

	func play_lingpet_gatling_transform() -> void:
		transform_count += 1

	func play_lingpet_gatling_fire() -> void:
		fire_count += 1

	func play_lingpet_gatling_hit() -> void:
		hit_count += 1

	func play_commando_bullet_impact() -> void:
		commando_bullet_impact_count += 1

	func play_commando_firearm_impact(weapon_id: String) -> void:
		commando_firearm_impact_calls.append(weapon_id)

	func play_lingpet_gatling_loop() -> void:
		loop_start_count += 1

	func stop_lingpet_gatling_loop() -> void:
		loop_stop_count += 1

	func sync_lingpet_gatling_loop(active: bool) -> void:
		if active:
			play_lingpet_gatling_loop()
		else:
			stop_lingpet_gatling_loop()


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeBossAiState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace := false

	func start_paddle_hit_knockback(velocity: float, frames: float = 0.0, decay: float = 1.0, replace_current: bool = false) -> bool:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay
		last_replace = replace_current
		return true


class FakeStatusEffectState:
	extends RefCounted

	var applied: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})
		return {}

	func get_calls_for_source(source_prefix: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in applied:
			if str(status_call.get("source", "")).begins_with(source_prefix):
				matches.append(status_call)
		return matches


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


func _init() -> void:
	_verify_dispatcher_catalog_assets()
	_verify_phase_flow_and_audio()
	_verify_hit_knockback_and_reset_cleanup()

	if _failures.is_empty():
		print("lingpet_gatling_burst_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_catalog_assets() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("gatling_burst"), "Gatling Burst should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime("volty_gatling_burst"), "Volty Gatling Burst should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_gatling_burst("volty_gatling_burst"), "dispatcher should expose a Gatling Burst helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry("volty_gatling_burst")
	_expect(not skill.is_empty(), "Volty catalog should expose Gatling Burst metadata")
	_expect(str(skill.get("runtime_kind", "")) == "gatling_burst", "Gatling Burst metadata should use the gatling_burst runtime kind")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 50.0), "Volty Gatling Burst should use the requested 50-second cooldown")
	_expect(is_equal_approx(float(skill.get("windup_seconds", -1.0)), 0.0), "Gatling Burst should not add a separate lingpet windup before the original 1-second mount")
	_expect(str(skill.get("icon_texture_path", "")).ends_with("volty_gatling_burst_skill_icon.png"), "Gatling Burst should use the tank-mode AutoSprite crop as its skill icon")
	var icon_texture: Variant = load(str(skill.get("icon_texture_path", "")))
	_expect(icon_texture is Texture2D, "Gatling Burst skill icon should import as a Texture2D")
	var volty_skill_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("volty"))
	_expect(volty_skill_ids.has("volty_bomb_surprise"), "Volty active skill pool should keep Bomb Surprise")
	_expect(volty_skill_ids.has("volty_gatling_burst"), "Volty active skill pool should add Gatling Burst as the second skill")

	for path in [
		"res://assets/sprites/lingpet/volty_gatling_tank_transform.png",
		"res://assets/sprites/lingpet/volty_gatling_tank_transform_manifest.json",
		"res://assets/sprites/lingpet/volty_gatling_burst_skill_icon.png",
		"res://assets/sprites/lingpet/volty_gatling_burst_skill_icon_manifest.json",
		"res://assets/sounds/gatling.wav",
		"res://assets/sounds/smallboyshoot.wav",
		"res://assets/sounds/tanktransform.wav",
		"res://assets/sounds/bullethit.wav",
	]:
		_expect(FileAccess.file_exists(path), "Godot should ship the Gatling Burst runtime asset: %s" % path)
	var manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/volty_gatling_tank_transform_manifest.json")
	_expect(manifest.find("\"tool\": \"AutoSprite MCP\"") >= 0 and manifest.find("\"frame_count\": 25") >= 0, "Gatling transform manifest should pin the AutoSprite 5x5/25-frame sheet")
	var game_audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(game_audio_source.find("play_lingpet_gatling_transform") >= 0, "game audio should expose the original tank transform sound")
	_expect(game_audio_source.find("sync_lingpet_gatling_loop") >= 0 and game_audio_source.find("stop_lingpet_gatling_loop") >= 0, "game audio should expose Gatling loop start/stop cleanup")
	var cleanup_source := FileAccess.get_file_as_string("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
	_expect(cleanup_source.find("stop_lingpet_gatling_loop") >= 0, "gameplay loop cleanup should stop Gatling loop audio at round boundaries")


func _verify_phase_flow_and_audio() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"battle_feedback_state": feedback,
	})
	var launch_origin := Vector2(380.0, 640.0)
	_expect(host.launch("volty_gatling_burst", launch_origin, owner, {"companion_pos": launch_origin, "registry": registry}), "runtime host should launch Volty Gatling Burst")
	var snapshot: Dictionary = host.get_snapshot()
	_expect(str(snapshot.get("gatling_burst_phase", "")) == "mounting", "Gatling Burst should start with the original 1-second mount phase")
	_expect(audio.transform_count == 1 and audio.active_item_count == 0, "Gatling launch should use the original tank transform sound")
	_expect(host.has_companion_position_override("volty_gatling_burst"), "Gatling Burst should override Volty's companion body while transformed")
	_expect(host.suppresses_companion_body_hit("volty_gatling_burst"), "Gatling Burst should suppress ordinary companion catches while tank-driven")
	_expect(host.has_method("suppresses_companion_body_draw") and bool(host.suppresses_companion_body_draw("volty_gatling_burst")), "Gatling Burst should replace the normal Volty SD draw instead of rendering over it")
	_expect(is_equal_approx(float(snapshot.get("gatling_burst_tank_draw_size", 0.0)), 96.0), "Gatling Burst tank draw size should be scaled down to match Volty's SD companion body")
	_expect(float(snapshot.get("gatling_burst_tank_visual_scale", 1.0)) < 0.82, "Gatling Burst cannon and fallback accents should share the tank body scale")

	host.update(0.50, owner, registry, "volty_gatling_burst")
	snapshot = host.get_snapshot()
	_expect(str(snapshot.get("gatling_burst_phase", "")) == "mounting", "Gatling Burst should still be mounting at half a second")
	_expect(is_equal_approx(float(snapshot.get("gatling_burst_mount_progress", 0.0)), 0.5), "Gatling mount progress should reflect the original 1-second transform")

	host.update(0.51, owner, registry, "volty_gatling_burst")
	snapshot = host.get_snapshot()
	_expect(str(snapshot.get("gatling_burst_phase", "")) == "firing", "Gatling Burst should enter firing after the 1-second mount")
	_expect(audio.loop_start_count == 1, "Gatling Burst should start the original gatling.wav loop when firing begins")
	_expect(bool(snapshot.get("gatling_burst_loop_playing", false)), "Gatling snapshot should expose loop playback state")
	_expect(int(snapshot.get("gatling_burst_transform_frame_index", 0)) == int(snapshot.get("gatling_burst_transform_chassis_frame_index", -1)), "Gatling Burst should hold on the no-baked-barrel chassis frame while firing")

	host.update(0.25, owner, registry, "volty_gatling_burst")
	snapshot = host.get_snapshot()
	_expect(int(snapshot.get("gatling_burst_shot_count", 0)) >= 3, "Gatling Burst should fire repeatedly at the original 0.067-second fire rate")
	_expect(int(snapshot.get("gatling_burst_bullet_count", 0)) > 0, "Gatling Burst should keep live bullets after firing")
	_expect(audio.fire_count >= 1, "Gatling Burst should use the original smallboyshoot fire sound cadence")
	var centered_angle := float(snapshot.get("gatling_burst_aim_angle", 0.0))
	owner.boss_pos = Vector2(80.0, 25.0)
	host.update(0.05, owner, registry, "volty_gatling_burst")
	snapshot = host.get_snapshot()
	_expect(absf(float(snapshot.get("gatling_burst_aim_angle", 0.0)) - centered_angle) > 0.10, "Gatling Burst barrel aim should move with the current firing direction")


func _verify_hit_knockback_and_reset_cleanup() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(0.0, 40.0)
	owner.boss_paddle_width = 760.0
	owner.boss_hitbox_height = 95.0
	var audio := FakeAudio.new()
	var boss_ai := FakeBossAiState.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"boss_ai_state": boss_ai,
		"status_effect_state": status_state,
	})
	var launch_origin := Vector2(380.0, 180.0)
	_expect(host.launch("volty_gatling_burst", launch_origin, owner, {"companion_pos": launch_origin, "registry": registry}), "close-range fixture should launch Gatling Burst")
	host.update(1.01, owner, registry, "volty_gatling_burst")
	for i in range(16):
		host.update(0.05, owner, registry, "volty_gatling_burst")
		if host.get_gatling_burst_hit_count_for_tests() > 0:
			break
	var snapshot: Dictionary = host.get_snapshot()
	_expect(int(snapshot.get("gatling_burst_hit_count", 0)) > 0, "Gatling Burst bullets should hit the boss hitbox")
	_expect(boss_ai.knockback_calls == 0, "Gatling Burst should let shared boss stun status own AK-style knockback motion")
	var stun_calls: Array[Dictionary] = status_state.get_calls_for_source("volty_gatling_burst")
	_expect(not stun_calls.is_empty(), "Gatling Burst should apply a shared boss stun status on bullet impact")
	if not stun_calls.is_empty():
		var status_call: Dictionary = stun_calls[0]
		var status_data: Dictionary = _get_dict(status_call.get("data", {}))
		_expect(str(status_call.get("target", "")) == "boss", "Gatling Burst AK-style status should target the boss")
		_expect(str(status_call.get("status_id", "")) == "stun", "Gatling Burst should apply the same short stun family as AK-47")
		_expect(is_equal_approx(float(status_call.get("duration_frames", 0.0)), 12.0), "Gatling Burst stun should match AK-47's 0.2s status")
		var knockback_abs: float = absf(float(status_data.get("knockback_vel", 0.0)))
		var max_expected_knockback: float = CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_POWER + (620.0 / 60.0) * CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_VELOCITY_SCALE
		_expect(knockback_abs >= CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_POWER and knockback_abs <= max_expected_knockback + 0.001, "Gatling Burst knockback should use AK-47's small bullet nudge profile")
		_expect(is_equal_approx(float(status_data.get("knockback_frames", 0.0)), CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_FRAMES), "Gatling Burst knockback frames should match AK-47")
		_expect(is_equal_approx(float(status_data.get("knockback_decay_per_frame", 0.0)), CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_DECAY_PER_FRAME), "Gatling Burst knockback decay should match AK-47")
	_expect(audio.commando_bullet_impact_count >= 1, "Gatling Burst should use the Commando AK-47 bullet-impact sound route")
	_expect(audio.hit_count == 0, "Gatling Burst should not prefer its older softer hit cue when Commando bullet impact audio exists")
	host.reset()
	snapshot = host.get_snapshot()
	_expect(str(snapshot.get("gatling_burst_phase", "idle")) == "idle", "runtime host reset should clear Gatling Burst state")
	_expect(audio.loop_stop_count >= 1, "runtime host reset should stop a live Gatling loop through cached registry cleanup")


func _skill_ids(pool: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for skill in pool:
		ids.append(str(skill.get("id", "")))
	return ids


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
