extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetBubbleTrapSkill := preload("res://scripts/lingpet/lingpet_bubble_trap_skill.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var current_stage := 1
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_size := 28.6
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array[Dictionary] = []
	var clears: Array[Dictionary] = []

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

	func clear_status(target: String, status_id: String = "", source: String = "") -> void:
		clears.append({
			"target": target,
			"status_id": status_id,
			"source": source,
		})

	func get_calls_for_source(source: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in calls:
			if str(status_call.get("source", "")) == source:
				matches.append(status_call)
		return matches


class FakeAudio:
	extends RefCounted

	var hydro_count := 0

	func play_stage2_hydro() -> void:
		hydro_count += 1


class FakeRegistry:
	extends RefCounted

	var status_effect_state: Object = null
	var game_audio: Object = null
	var lingpet_runtime: Object = null

	func _init(status_state: Object = null, audio: Object = null, runtime: Object = null) -> void:
		status_effect_state = status_state
		game_audio = audio
		lingpet_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "status_effect_state":
			return status_effect_state
		if key == "game_audio":
			return game_audio
		if key == "lingpet_egg_runtime":
			return lingpet_runtime
		return null


class FakeLingpetRuntime:
	extends RefCounted

	var snapshot: Dictionary = {}

	func is_companion_active(_pet_id: String = "") -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return snapshot


func _init() -> void:
	_verify_dispatcher_and_catalog()
	_verify_level_scaled_launch_values()
	_verify_forced_extra_shot_rolls()
	_verify_rainbow_projectile_rules()
	_verify_multi_shot_sequence_tracks_moving_origin()
	_verify_runtime_capture_and_ball_pop()
	_verify_projectile_ball_pop()
	_verify_capture_expiry_pop()
	_verify_rail_card_reads_bubble_casting()

	if _failures.is_empty():
		print("lingpet_bubble_trap_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("bubble_trap"), "bubble_trap should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime("maribo_bubble_trap"), "maribo_bubble_trap should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_bubble_trap("maribo_bubble_trap"), "dispatcher should expose a Bubble Trap helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry("maribo_bubble_trap")
	_expect(not skill.is_empty(), "Maribo catalog should expose Bubble Trap metadata")
	_expect(str(skill.get("runtime_kind", "")) == "bubble_trap", "Bubble Trap metadata should use the bubble_trap runtime kind")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 25.0), "Bubble Trap should use a 25-second cooldown")
	_expect(str(skill.get("name", "")) == "물방울트랩", "Bubble Trap should keep the requested Korean skill name")
	_expect(str(skill.get("description", "")).find("2.0~4.0초") >= 0 and str(skill.get("description", "")).find("무지개") >= 0, "Bubble Trap catalog description should mention level-scaled duration and rainbow behavior")
	_expect(str(skill.get("card_texture_path", "")).ends_with("maribo_bubble_trap_skillcard_imagegen_v1.png"), "Bubble Trap should use its own Maribo-matched skill card")
	_expect(str(skill.get("icon_texture_path", "")).ends_with("maribo_bubble_trap_skill_icon_imagegen_v1.png"), "Bubble Trap should use its own Maribo-matched skill icon")
	_expect(FileAccess.file_exists(str(skill.get("card_texture_path", ""))), "Bubble Trap skill-card PNG should exist")
	_expect(FileAccess.file_exists(str(skill.get("icon_texture_path", ""))), "Bubble Trap skill-icon PNG should exist")
	_expect(LingpetRailCard.is_lingpet_skill({"id": "maribo_bubble_trap"}), "shared rail-card helper should recognize Bubble Trap as a lingpet skill")

	var maribo_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("maribo"))
	_expect(maribo_ids.has("maribo_hydro_sphere") and maribo_ids.has("maribo_bubble_trap"), "Maribo active-skill pool should contain Hydro Sphere and Bubble Trap")
	_expect(str(LingpetCatalog.build_default_loadout("maribo").get("active_skill_id", "")) == "maribo_hydro_sphere", "legacy/default Maribo loadout should still choose Hydro Sphere")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "live lingpet catalog should validate after adding Bubble Trap")
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bubble_trap_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bubble_trap_renderer.gd")
	_expect(source.find("INNER_BUBBLE_SIZE_VARIANCE := 0.30") >= 0, "Bubble Trap inner bubble sizes should vary by +/-30 percent")
	_expect(source.find("PROJECTILE_WOBBLE_AMPLITUDE") >= 0 and renderer_source.find("_draw_inner_bubbles") >= 0, "Bubble Trap visuals should use bubbly wobble motion and inner bubble rendering")
	_expect(source.find("launch_context: Dictionary") >= 0 and source.find("_read_level(launch_context)") >= 0, "Bubble Trap launch should consume active-skill level context")
	_expect(source.find("SHOT_COUNT_MIN") < 0 and source.find("SHOT_COUNT_MAX") < 0, "Bubble Trap should use independent extra-shot rolls instead of min/max span rolls")
	_expect(source.find("EXTRA_ROLL_SALT + float(index)") >= 0, "Bubble Trap extra-shot rolls should salt each independent roll by index")


func _verify_level_scaled_launch_values() -> void:
	var lv1 := _launch_skill_direct(1)
	var lv5 := _launch_skill_direct(5)
	var lv1_snapshot: Dictionary = lv1.get_snapshot()
	var lv5_snapshot: Dictionary = lv5.get_snapshot()
	_expect(int(lv1_snapshot.get("bubble_trap_active_skill_level", 0)) == 1, "Bubble Trap should capture Lv.1 from launch context")
	_expect(int(lv5_snapshot.get("bubble_trap_active_skill_level", 0)) == 5, "Bubble Trap should capture Lv.5 from launch context")
	_expect(is_equal_approx(float(lv1_snapshot.get("bubble_trap_projectile_speed", 0.0)), 185.0), "Bubble Trap Lv.1 projectile speed should be 185")
	_expect(is_equal_approx(float(lv5_snapshot.get("bubble_trap_projectile_speed", 0.0)), 285.0), "Bubble Trap Lv.5 projectile speed should be 285")

	var lv1_capture := _capture_duration_for_level(1)
	var lv5_capture := _capture_duration_for_level(5)
	_expect(lv1_capture >= 2.0 and lv1_capture <= 3.0, "Bubble Trap Lv.1 capture duration should stay in the 2.0-3.0s band")
	_expect(lv5_capture >= 3.0 and lv5_capture <= 4.0, "Bubble Trap Lv.5 capture duration should stay in the 3.0-4.0s band")
	_expect(lv5_capture > lv1_capture, "Bubble Trap capture duration should increase for the same fixture from Lv.1 to Lv.5")


func _verify_forced_extra_shot_rolls() -> void:
	var lv1_all_success := _launch_skill_direct(1, 1)
	var lv5_all_success := _launch_skill_direct(5, 1)
	var lv1_all_fail := _launch_skill_direct(1, 0)
	var lv5_all_fail := _launch_skill_direct(5, 0)
	_expect(int(lv1_all_success.get_snapshot().get("bubble_trap_shot_count_target", 0)) == 3, "Bubble Trap Lv.1 all-success extra rolls should fire 3 total bubbles")
	_expect(int(lv5_all_success.get_snapshot().get("bubble_trap_shot_count_target", 0)) == 5, "Bubble Trap Lv.5 all-success extra rolls should fire 5 total bubbles")
	_expect(int(lv1_all_fail.get_snapshot().get("bubble_trap_shot_count_target", 0)) == 2, "Bubble Trap Lv.1 failed extra rolls should fall back to 2 base bubbles")
	_expect(int(lv5_all_fail.get_snapshot().get("bubble_trap_shot_count_target", 0)) == 2, "Bubble Trap Lv.5 failed extra rolls should fall back to 2 base bubbles")


func _verify_rainbow_projectile_rules() -> void:
	var lv1_skill := _launch_skill_direct(1, 0, 1)
	var lv5_skill := _launch_skill_direct(5, 0, 1)
	var lv1_snapshot: Dictionary = lv1_skill.get_snapshot()
	var lv5_snapshot: Dictionary = lv5_skill.get_snapshot()
	_expect(not bool(lv1_snapshot.get("bubble_trap_projectile_is_rainbow", false)), "Bubble Trap Lv.1 should not create a rainbow bubble even when the test override asks for one")
	_expect(bool(lv5_snapshot.get("bubble_trap_projectile_is_rainbow", false)), "Bubble Trap Lv.5 forced rainbow should replace the lead bubble")
	var lv5_radii: Array = lv5_snapshot.get("bubble_trap_projectile_visual_radii", [])
	_expect(not lv5_radii.is_empty() and is_equal_approx(float(lv5_radii[0]), 22.0 * 2.5), "Bubble Trap Lv.5 rainbow lead bubble should use the 2.5x radius")

	var rainbow_owner := FakeOwner.new()
	rainbow_owner.ball_active = true
	rainbow_owner.ball_pos = lv5_snapshot.get("bubble_trap_projectile_pos", Vector2.ZERO)
	lv5_skill.update(0.01, rainbow_owner, FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new()))
	_expect(bool(lv5_skill.get_snapshot().get("bubble_trap_projectile_active", false)), "Bubble Trap rainbow projectile should not pop on ball contact")

	var normal_skill := _launch_skill_direct(5, 0, 0)
	var normal_snapshot: Dictionary = normal_skill.get_snapshot()
	var normal_owner := FakeOwner.new()
	normal_owner.ball_active = true
	normal_owner.ball_pos = normal_snapshot.get("bubble_trap_projectile_pos", Vector2.ZERO)
	normal_skill.update(0.01, normal_owner, FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new()))
	_expect(not bool(normal_skill.get_snapshot().get("bubble_trap_projectile_active", true)), "Bubble Trap normal projectile should still pop on ball contact")

	var capture_skill := _launch_skill_direct(5, 0, 1, Vector2(380.0, 160.0))
	var capture_owner := FakeOwner.new()
	capture_skill.update(0.50, capture_owner, FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new()))
	_expect(bool(capture_skill.get_snapshot().get("bubble_trap_capture_active", false)), "Bubble Trap rainbow projectile should still capture the boss")


func _verify_runtime_capture_and_ball_pop() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	var skill_id := "maribo_bubble_trap"

	_expect(host.launch(skill_id, Vector2(380.0, 160.0), owner), "runtime host should launch Bubble Trap")
	_expect(host.is_launch_blocked(skill_id), "Bubble Trap should block relaunch while its projectile is active")
	host.update(0.50, owner, registry, skill_id)

	var snapshot: Dictionary = host.get_snapshot()
	_expect(not bool(snapshot.get("bubble_trap_projectile_active", true)), "Bubble Trap projectile should stop after touching the boss paddle")
	_expect(bool(snapshot.get("bubble_trap_capture_active", false)), "Bubble Trap should capture the boss paddle on contact")
	_expect(int(host.get_bubble_trap_capture_count_for_tests()) == 1, "Bubble Trap should count one capture")
	_expect(_is_capture_duration_in_range(float(snapshot.get("bubble_trap_capture_duration", 0.0))), "Bubble Trap default Lv.1 capture duration should be between 2.0 and 3.0 seconds")
	_expect(float(snapshot.get("bubble_trap_radius", 0.0)) >= 82.0, "Bubble Trap capture bubble should be large enough to cover the boss body, not only the head")
	var visual_center: Vector2 = snapshot.get("bubble_trap_center", Vector2.ZERO)
	var hitbox_center_y := owner.boss_pos.y + owner.boss_hitbox_height * 0.5
	_expect(visual_center.y > hitbox_center_y + 10.0, "Bubble Trap capture bubble should center on the boss visual body instead of the small hitbox head area")
	_expect(is_equal_approx(float(owner.boss_vel), 0.0), "captured boss paddle velocity should be forced to zero")

	var stun_calls: Array[Dictionary] = status_state.get_calls_for_source("maribo_bubble_trap_capture")
	_expect(not stun_calls.is_empty(), "Bubble Trap should refresh a shared boss stun while captured")
	if not stun_calls.is_empty():
		var first_call: Dictionary = stun_calls[0]
		_expect(str(first_call.get("target", "")) == "boss", "Bubble Trap stun should target the boss")
		_expect(str(first_call.get("status_id", "")) == "stun", "Bubble Trap should reuse the shared boss stun status")
		_expect(is_equal_approx(float(first_call.get("duration_frames", 0.0)), 4.0), "Bubble Trap stun should refresh with a short frame duration")
		var data: Dictionary = first_call.get("data", {}) as Dictionary
		_expect(str(data.get("visual", "")) == "maribo_bubble_trap", "Bubble Trap stun should tag its own visual id")

	var locked_pos: Vector2 = owner.boss_pos
	owner.boss_pos = Vector2(12.0, owner.boss_pos.y)
	owner.boss_vel = 99.0
	host.update(0.25, owner, registry, skill_id)
	_expect(owner.boss_pos.distance_to(locked_pos) > 1.0, "captured bubble should float the boss paddle instead of leaving it at the first capture point")
	_expect(owner.boss_pos.x > 12.0, "captured boss paddle should be pulled back inside the bubble after AI movement tries to escape")
	_expect(is_equal_approx(float(owner.boss_vel), 0.0), "captured boss paddle should stay movement-locked after an AI escape attempt")

	snapshot = host.get_snapshot()
	owner.ball_active = true
	owner.ball_pos = snapshot.get("bubble_trap_center", Vector2.ZERO)
	host.update(0.01, owner, registry, skill_id)
	snapshot = host.get_snapshot()
	_expect(not bool(snapshot.get("bubble_trap_capture_active", true)), "Bubble Trap should pop when the ball touches the captured bubble")
	_expect(str(snapshot.get("bubble_trap_last_burst_reason", "")) == "captured_ball", "captured bubble pop reason should report ball contact")
	_expect(int(host.get_bubble_trap_pop_count_for_tests()) >= 1, "Bubble Trap should count the captured-bubble pop")
	_expect(not status_state.clears.is_empty(), "Bubble Trap should clear its shared stun source when the bubble pops")
	_expect(audio.hydro_count >= 2, "Bubble Trap should reuse the hydro water sound on capture and pop")


func _verify_multi_shot_sequence_tracks_moving_origin() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new())
	var skill_id := "maribo_bubble_trap"
	owner.lingpet_companion_pos = Vector2(260.0, 680.0)
	host.launch(skill_id, Vector2(260.0, 656.0), owner, {"companion_pos": owner.lingpet_companion_pos, "companion_radius": 16.0})
	var snapshot: Dictionary = host.get_snapshot()
	var shot_target := int(snapshot.get("bubble_trap_shot_count_target", 0))
	_expect(shot_target >= 2 and shot_target <= 3, "Bubble Trap should choose a 2-3 shot sequence on launch")
	_expect(int(snapshot.get("bubble_trap_shots_launched", 0)) == 1, "Bubble Trap should fire the first bubble immediately")
	_expect(int(snapshot.get("bubble_trap_projectile_count", 0)) == 1, "Bubble Trap should start with one active bubble projectile")
	_expect(is_equal_approx(float(snapshot.get("bubble_trap_inner_bubble_size_variance", 0.0)), 0.30), "Bubble Trap snapshot should expose the +/-30 percent inner bubble size variance")

	var first_origin: Vector2 = snapshot.get("bubble_trap_projectile_pos", Vector2.ZERO)
	host.update(0.20, owner, registry, skill_id, {"companion_pos": owner.lingpet_companion_pos, "companion_radius": 16.0})
	snapshot = host.get_snapshot()
	var first_bob_pos: Vector2 = snapshot.get("bubble_trap_projectile_pos", Vector2.ZERO)
	_expect(absf(first_bob_pos.x - first_origin.x) >= 0.1, "Bubble Trap projectile should wobble sideways instead of moving in a perfectly straight line")

	host.update(0.39, owner, registry, skill_id, {"companion_pos": owner.lingpet_companion_pos, "companion_radius": 16.0})
	snapshot = host.get_snapshot()
	_expect(int(snapshot.get("bubble_trap_shots_launched", 0)) == 1, "Bubble Trap should wait for the 0.6s interval before the second bubble")

	owner.lingpet_companion_pos = Vector2(360.0, 680.0)
	host.update(0.02, owner, registry, skill_id, {"companion_pos": owner.lingpet_companion_pos, "companion_radius": 16.0})
	snapshot = host.get_snapshot()
	var positions: Array = snapshot.get("bubble_trap_projectile_positions", [])
	_expect(int(snapshot.get("bubble_trap_shots_launched", 0)) == 2, "Bubble Trap should fire the second bubble after the 0.6s interval")
	_expect(positions.size() >= 2, "Bubble Trap should keep multiple bubble projectiles active after the second shot")
	if positions.size() >= 2:
		var first_pos: Vector2 = positions[0]
		var second_pos: Vector2 = positions[1]
		_expect(absf(first_pos.x - second_pos.x) >= 20.0, "Bubble Trap follow-up shot should use a different launch X while Maribo keeps moving")


func _verify_projectile_ball_pop() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new())
	var skill_id := "maribo_bubble_trap"
	host.launch(skill_id, Vector2(220.0, 260.0), owner)
	owner.ball_active = true
	owner.ball_pos = Vector2(220.0, 260.0 - 220.0 * 0.10)
	host.update(0.10, owner, registry, skill_id)
	var snapshot: Dictionary = host.get_snapshot()
	_expect(not bool(snapshot.get("bubble_trap_projectile_active", true)), "Bubble Trap projectile should pop when hit by the ball")
	_expect(str(snapshot.get("bubble_trap_last_burst_reason", "")) == "ball", "projectile pop reason should report ball contact")
	_expect(host.is_launch_blocked(skill_id), "Bubble Trap should keep relaunch blocked while follow-up bubble shots are queued")
	host.update(3.0, owner, registry, skill_id)
	_expect(not host.is_launch_blocked(skill_id), "Bubble Trap should stop blocking relaunch after the queued bubble sequence finishes")
	host.update(0.7, owner, registry, skill_id)
	_expect(not host.has_visible_effects(), "Bubble Trap projectile pop particles should fully clear after their lifetime")


func _verify_capture_expiry_pop() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new())
	var skill_id := "maribo_bubble_trap"
	host.launch(skill_id, Vector2(380.0, 160.0), owner)
	host.update(0.50, owner, registry, skill_id)
	_expect(bool(host.get_snapshot().get("bubble_trap_capture_active", false)), "expiry fixture should start from a captured bubble")
	var snapshot: Dictionary = host.get_snapshot()
	_expect(_is_capture_duration_in_range(float(snapshot.get("bubble_trap_capture_duration", 0.0))), "expiry fixture should expose the Lv.1 2.0-3.0s capture duration")
	var remaining := float(snapshot.get("bubble_trap_capture_timer", 0.0))
	host.update(maxf(0.0, remaining - 0.05), owner, registry, skill_id)
	_expect(bool(host.get_snapshot().get("bubble_trap_capture_active", false)), "Bubble Trap should stay captured until the selected level-scaled duration nearly ends")
	snapshot = host.get_snapshot()
	host.update(float(snapshot.get("bubble_trap_capture_timer", 0.0)) + 0.05, owner, registry, skill_id)
	snapshot = host.get_snapshot()
	_expect(not bool(snapshot.get("bubble_trap_capture_active", true)), "Bubble Trap should release after the selected level-scaled capture duration")
	_expect(str(snapshot.get("bubble_trap_last_burst_reason", "")) == "expire", "capture expiry should pop the bubble")


func _verify_rail_card_reads_bubble_casting() -> void:
	var runtime := FakeLingpetRuntime.new()
	runtime.snapshot = {
		"companion_skill_id": "maribo_bubble_trap",
		"companion_skill_name": "물방울트랩",
		"companion_skill_description": "상대 패들을 물방울에 가둡니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/maribo_bubble_trap_skillcard_imagegen_v1.png",
		"companion_skill_cooldown": 21.0,
		"companion_skill_cooldown_duration": 25.0,
		"companion_skill_ready": false,
		"bubble_trap_projectile_active": false,
		"bubble_trap_capture_active": true,
	}
	var rail_entry: Dictionary = LingpetRailCard.build_entry(FakeRegistry.new(null, null, runtime))
	_expect(str(rail_entry.get("id", "")) == "maribo_bubble_trap", "shared rail-card entry should use the Bubble Trap skill id")
	_expect(str(rail_entry.get("status", "")) == "casting", "Bubble Trap capture should read as casting on the shared rail")
	_expect(absf(float(rail_entry.get("cooldown_total", 0.0)) - 25.0) <= 0.01, "Bubble Trap rail entry should carry its 25s cooldown")


func _launch_skill_direct(
	active_skill_level: int,
	force_extra: int = -1,
	force_rainbow: int = -1,
	origin: Vector2 = Vector2(260.0, 656.0)
) -> Object:
	var skill: Object = LingpetBubbleTrapSkill.new()
	skill._force_extra_for_tests = force_extra
	skill._force_rainbow_for_tests = force_rainbow
	skill.launch(origin, null, {"active_skill_level": active_skill_level})
	return skill


func _capture_duration_for_level(active_skill_level: int) -> float:
	var skill := _launch_skill_direct(active_skill_level, 0, 0, Vector2(380.0, 160.0))
	skill.update(0.50, FakeOwner.new(), FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new()))
	return float(skill.get_snapshot().get("bubble_trap_capture_duration", 0.0))


func _skill_ids(skills: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for skill in skills:
		var skill_id := str(skill.get("id", "")).strip_edges()
		if skill_id != "":
			ids.append(skill_id)
	return ids


func _is_capture_duration_in_range(duration: float) -> bool:
	return duration >= 2.0 and duration <= 3.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
