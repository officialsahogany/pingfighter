extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LingpetThunderOrbSkill := preload("res://scripts/lingpet/lingpet_thunder_orb_skill.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var boss_wall_y := 12.0
	var ball_active := true


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

	var shot_count := 0
	var boom_count := 0
	var mini_spark_plays := 0
	var electric_syncs: Array[bool] = []

	func play_thunder_orb_shot() -> void:
		shot_count += 1

	func play_thunder_orb_boom() -> void:
		boom_count += 1

	func play_mini_spark() -> void:
		mini_spark_plays += 1

	func sync_electric_shock_loop(active: bool) -> void:
		electric_syncs.append(active)


class FakeRegistry:
	extends RefCounted

	var status_effect_state: Object = null
	var game_audio: Object = null
	var lingpet_runtime: Object = null

	func _init(status_state: Object = null, audio: Object = null, runtime: Object = null) -> void:
		status_effect_state = status_state
		game_audio = audio
		lingpet_runtime = runtime

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

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
	_verify_runtime_physics_and_electric_stun()
	_verify_stun_duration_honors_launch_context()
	_verify_explosion_radius_honors_launch_context()
	_verify_spark_miss_does_not_stun()
	_verify_edge_overlap_center_outside_does_not_stun()
	_verify_reset_stops_electric_loop_and_clears_status()
	_verify_rail_card_reads_thunder_casting()
	_verify_mini_spark_count_scales_with_level()
	_verify_mini_spark_stuns_after_main_stun_ends()
	_verify_mini_spark_miss_does_not_stun()

	if _failures.is_empty():
		print("lingpet_thunder_orb_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("thunder_orb"), "thunder_orb should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime("lumion_thunder_orb"), "lumion_thunder_orb should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_thunder_orb("lumion_thunder_orb"), "dispatcher should expose a Thunder Orb helper")
	_expect(LingpetCatalog.get_display_name("lumion") == "벼락여우", "Lumion compatibility id should expose the rebranded Korean display name")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry("lumion_thunder_orb")
	_expect(not skill.is_empty(), "Lumion catalog should expose Thunder Orb metadata")
	_expect(str(skill.get("runtime_kind", "")) == "thunder_orb", "Thunder Orb metadata should use the thunder_orb runtime kind")
	_expect(str(skill.get("name", "")) == "천둥 뇌구", "Thunder Orb should keep the requested Korean skill name")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 25.0), "Thunder Orb should use the requested 25-second cooldown")
	_expect(str(LingpetCatalog.get_active_skill("lumion").get("id", "")) == "lumion_thunder_orb", "Lumion's default active skill should be Thunder Orb")
	# Electric stun now scales with the active-skill level (Lv.1 0.8s -> Lv.5 1.6s,
	# with the current 1.4s state anchored at Lv.4).
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("lumion", "lumion_thunder_orb", 1).get("stun_duration_seconds", 0.0)), 0.8), "Thunder Orb Lv.1 should stun for 0.8s")
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("lumion", "lumion_thunder_orb", 4).get("stun_duration_seconds", 0.0)), 1.4), "Thunder Orb Lv.4 should stun for the current 1.4s baseline")
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("lumion", "lumion_thunder_orb", 5).get("stun_duration_seconds", 0.0)), 1.6), "Thunder Orb Lv.5 should stun for 1.6s")
	# Main blast range also scales with level: Lv.1 is 20% narrower (136px), growing
	# linearly to the full 170px at Lv.5 (this radius is BOTH the visual blast and
	# the boss-center CC reach, so low levels reach less).
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("lumion", "lumion_thunder_orb", 1).get("explosion_radius", 0.0)), 136.0), "Thunder Orb Lv.1 explosion radius should be 20% narrower (136px)")
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("lumion", "lumion_thunder_orb", 3).get("explosion_radius", 0.0)), 153.0), "Thunder Orb Lv.3 explosion radius should be the mid step (153px)")
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("lumion", "lumion_thunder_orb", 5).get("explosion_radius", 0.0)), 170.0), "Thunder Orb Lv.5 explosion radius should reach the full 170px")
	_expect(LingpetRailCard.is_lingpet_skill({"id": "lumion_thunder_orb"}), "shared rail-card helper should recognize Lumion Thunder Orb as a lingpet skill")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "live lingpet catalog should validate after wiring Thunder Orb")
	_expect(FileAccess.file_exists(GameAudio.THUNDER_ORB_SHOT_SOUND_PATH), "Thunder Orb should include the original thunderbolt.wav launch sound")
	_expect(FileAccess.file_exists(GameAudio.THUNDER_ORB_BOOM_SOUND_PATH), "Thunder Orb should include the original thunderboltboom.wav explosion sound")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.THUNDER_ORB_SHOT_SOUND_PATH) != null, "Thunder Orb launch sound should load through the Godot resource helper")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.THUNDER_ORB_BOOM_SOUND_PATH) != null, "Thunder Orb explosion sound should load through the Godot resource helper")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.ELECTRIC_SHOCK_SOUND_PATH) != null, "Thunder Orb electric shock loop should load through the Godot resource helper")
	_expect(absf(GameAudio.THUNDER_ORB_SHOT_GAIN_DB - linear_to_db(0.4)) <= 0.001, "Thunder Orb launch gain should match the original Horus Thunder Orb volume")
	_expect(absf(GameAudio.THUNDER_ORB_BOOM_GAIN_DB - linear_to_db(0.5)) <= 0.001, "Thunder Orb explosion gain should match the original Horus Thunder Orb volume")
	_expect(absf(GameAudio.ELECTRIC_SHOCK_GAIN_DB - linear_to_db(0.45)) <= 0.001, "Thunder Orb electric shock gain should match the original Horus Thunder Orb volume")


func _verify_runtime_physics_and_electric_stun() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	var skill_id := "lumion_thunder_orb"
	var launch_origin := Vector2(380.0, 700.0)

	_expect(host.launch(skill_id, launch_origin, owner), "runtime host should launch Lumion Thunder Orb")
	host.trigger_launch_feedback(skill_id, registry)
	_expect(audio.shot_count == 1, "Thunder Orb launch should play the original thunderbolt.wav feedback")
	_expect(host.is_launch_blocked(skill_id), "Thunder Orb should block relaunch while the orb is active")

	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("thunder_orb_projectile_active", false)), "Thunder Orb should start as a projectile")
	_expect(is_equal_approx(float(snapshot.get("thunder_orb_speed_multiplier", 0.0)), 3.6), "Thunder Orb should launch at the original fast 3.6x speed")

	host.update(0.05, owner, registry, skill_id)
	var early_snapshot: Dictionary = host.get_snapshot()
	var early_speed: float = float(early_snapshot.get("thunder_orb_projectile_speed", 0.0))
	var early_pos: Vector2 = early_snapshot.get("thunder_orb_projectile_pos", Vector2.ZERO)
	_expect(bool(early_snapshot.get("thunder_orb_projectile_active", false)), "Thunder Orb should still travel after the first short step")
	_expect(absf(early_pos.x - launch_origin.x) <= 0.01, "Thunder Orb should travel in a straight vertical line")
	_expect(early_pos.y < launch_origin.y, "Thunder Orb should move toward the opponent side")

	host.update(0.20, owner, registry, skill_id)
	var slowed_snapshot: Dictionary = host.get_snapshot()
	var slowed_speed: float = float(slowed_snapshot.get("thunder_orb_projectile_speed", 0.0))
	var slowed_pos: Vector2 = slowed_snapshot.get("thunder_orb_projectile_pos", Vector2.ZERO)
	_expect(bool(slowed_snapshot.get("thunder_orb_projectile_active", false)), "Thunder Orb should still be visible before reaching the target row")
	_expect(slowed_speed < early_speed, "Thunder Orb should decelerate after its fast opening burst")
	_expect(absf(slowed_pos.x - launch_origin.x) <= 0.01, "Thunder Orb deceleration should not introduce sideways drift")

	var safety := 0
	while bool(host.get_snapshot().get("thunder_orb_projectile_active", false)) and safety < 180:
		host.update(1.0 / 60.0, owner, registry, skill_id)
		safety += 1
	snapshot = host.get_snapshot()
	_expect(int(snapshot.get("thunder_orb_explosion_count", 0)) == 1, "Thunder Orb should explode once at the opponent side")
	_expect(is_equal_approx(float(snapshot.get("thunder_orb_explosion_radius", 0.0)), 170.0), "Thunder Orb should use the original 170px explosion radius")
	_expect(audio.boom_count == 1, "Thunder Orb explosion should play the original thunderboltboom.wav feedback")
	# Horus parity: the stun is judged ONLY after the 0.2s explosion animation
	# finishes, so nothing is stunned (and the electric loop has not started)
	# while the blast is still animating.
	_expect(int(host.get_thunder_orb_shock_count_for_tests()) == 0, "Thunder Orb should not apply the stun during the explosion animation")
	_expect(status_state.get_calls_for_source("lumion_thunder_orb_electric_stun").is_empty(), "Thunder Orb should not apply its stun source mid-explosion")
	_expect(not audio.electric_syncs.has(true), "Thunder Orb should not start the electric shock loop during the explosion animation")

	# Finish the 0.2s explosion -> the blast is now judged by boss-center distance.
	host.update(0.25, owner, registry, skill_id)
	_expect(int(host.get_thunder_orb_shock_count_for_tests()) == 1, "Thunder Orb should apply one electric stun when the boss center is inside the blast at explosion end")

	var stun_calls: Array[Dictionary] = status_state.get_calls_for_source("lumion_thunder_orb_electric_stun")
	_expect(not stun_calls.is_empty(), "Thunder Orb should apply a shared boss stun with its own source")
	if not stun_calls.is_empty():
		var first_call: Dictionary = stun_calls[0]
		_expect(str(first_call.get("target", "")) == "boss", "Thunder Orb electric stun should target the boss")
		_expect(str(first_call.get("status_id", "")) == "stun", "Thunder Orb should reuse the shared boss stun status")
		var data: Dictionary = first_call.get("data", {}) as Dictionary
		_expect(str(data.get("visual", "")) == "lumion_thunder_orb", "Thunder Orb stun should tag its own visual id")
		_expect(bool(data.get("suppress_stun_stars", false)), "Thunder Orb electric stun should suppress generic stun stars")
		_expect(bool(data.get("electric_stun", false)), "Thunder Orb stun data should mark the electric-stun flavor")
	_expect(audio.electric_syncs.has(true), "Thunder Orb electric stun should start the electric shock loop")

	host.update(2.25, owner, registry, skill_id)
	_expect(not bool(host.get_snapshot().get("thunder_orb_electric_stun_active", true)), "Thunder Orb electric stun should expire after its 1.4-second stun window")
	_expect(not host.is_launch_blocked(skill_id), "Thunder Orb should stop blocking relaunch after the electric stun ends")
	_expect(audio.electric_syncs.has(false), "Thunder Orb electric stun should stop the electric shock loop")
	_expect(_has_clear(status_state.clears, "lumion_thunder_orb_electric_stun"), "Thunder Orb should clear its own stun source when the shock ends")


func _verify_stun_duration_honors_launch_context() -> void:
	# The companion launch path forwards the level-scaled `stun_duration_seconds`
	# through launch_context. A long value must keep the boss stunned well past
	# the 1.4s const fallback, proving the runtime reads the per-launch duration
	# instead of the hardcoded constant.
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	var skill_id := "lumion_thunder_orb"

	_expect(host.launch(skill_id, Vector2(380.0, 700.0), owner, {"stun_duration_seconds": 3.0}), "host should launch Thunder Orb with a level-scaled stun duration")
	var safety := 0
	while bool(host.get_snapshot().get("thunder_orb_projectile_active", false)) and safety < 180:
		host.update(1.0 / 60.0, owner, registry, skill_id)
		safety += 1
	# Finish the 0.2s explosion so the stun begins with the configured duration.
	host.update(0.25, owner, registry, skill_id)
	_expect(bool(host.get_snapshot().get("thunder_orb_electric_stun_active", false)), "Thunder Orb should stun the boss at explosion end")

	# 2.0s in, a 3.0s stun must still be live (the 1.4s const fallback would be long gone).
	host.update(2.0, owner, registry, skill_id)
	_expect(bool(host.get_snapshot().get("thunder_orb_electric_stun_active", false)), "a 3.0s launch-context stun should still be active 2.0s in, not capped at the 1.4s const")
	# Past the full 3.0s window it must expire.
	host.update(1.2, owner, registry, skill_id)
	_expect(not bool(host.get_snapshot().get("thunder_orb_electric_stun_active", true)), "the launch-context stun should expire after its own duration")


func _verify_explosion_radius_honors_launch_context() -> void:
	# The companion launch path forwards the level-scaled `explosion_radius`
	# (Lv.1 136px -> Lv.5 170px). A SMALL override must shrink BOTH the reported
	# blast radius and the boss-CENTER CC reach, proving the runtime reads the
	# per-launch radius instead of the 170px const.
	# --- Boss inside the default 170px blast but OUTSIDE a 100px override: NOT stunned ---
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(480.0, 25.0)  # centre (530,45) ~151px from the blast at (380,65)
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	var skill_id := "lumion_thunder_orb"
	host.launch(skill_id, Vector2(380.0, 700.0), owner, {"explosion_radius": 100.0})
	var safety := 0
	while bool(host.get_snapshot().get("thunder_orb_projectile_active", false)) and safety < 180:
		host.update(1.0 / 60.0, owner, registry, skill_id)
		safety += 1
	_expect(is_equal_approx(float(host.get_snapshot().get("thunder_orb_explosion_radius", 0.0)), 100.0), "Thunder Orb should report the launch-context explosion radius, not the 170px const")
	host.update(0.25, owner, registry, skill_id)
	_expect(int(host.get_thunder_orb_shock_count_for_tests()) == 0, "a ~151px boss is inside the default 170px blast but OUTSIDE a 100px override -> must NOT be stunned")

	# --- Same 100px override, a boss well inside it IS stunned (override shrinks, not disables) ---
	var host2: Object = LingpetSkillRuntimeHost.new()
	var owner2 := FakeOwner.new()  # default centre (380,45), ~20px from the blast
	var status2 := FakeStatusEffectState.new()
	var registry2 := FakeRegistry.new(status2, FakeAudio.new())
	host2.launch(skill_id, Vector2(380.0, 700.0), owner2, {"explosion_radius": 100.0})
	var safety2 := 0
	while bool(host2.get_snapshot().get("thunder_orb_projectile_active", false)) and safety2 < 180:
		host2.update(1.0 / 60.0, owner2, registry2, skill_id)
		safety2 += 1
	host2.update(0.25, owner2, registry2, skill_id)
	_expect(int(host2.get_thunder_orb_shock_count_for_tests()) == 1, "a boss well inside the 100px override should still be stunned (the override shrinks, not disables, the reach)")


func _verify_spark_miss_does_not_stun() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(12.0, 25.0)
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	var skill_id := "lumion_thunder_orb"
	host.launch(skill_id, Vector2(720.0, 700.0), owner)
	var safety := 0
	while bool(host.get_snapshot().get("thunder_orb_projectile_active", false)) and safety < 180:
		host.update(1.0 / 60.0, owner, registry, skill_id)
		safety += 1
	host.update(0.25, owner, registry, skill_id)
	_expect(int(host.get_thunder_orb_shock_count_for_tests()) == 0, "Thunder Orb sparks should not stun a boss outside the explosion radius")
	_expect(status_state.get_calls_for_source("lumion_thunder_orb_electric_stun").is_empty(), "Thunder Orb miss should not apply the electric stun source")
	_expect(not audio.electric_syncs.has(true), "Thunder Orb miss should not start the electric shock loop")


func _verify_edge_overlap_center_outside_does_not_stun() -> void:
	# A boss whose RECT clips the 170px blast edge but whose CENTER is outside the
	# radius: the original Horus geometry uses boss-CENTER distance (pure circle),
	# so this must NOT stun. A circle-vs-rect overlap (the old Godot behavior)
	# would wrongly stun here.
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	# Explosion lands at x=380; boss centre at (559, 45) is ~180px away (> 170),
	# but the boss rect's near edge (x=509) is only ~129px away (< 170).
	owner.boss_pos = Vector2(509.0, 25.0)
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	var skill_id := "lumion_thunder_orb"
	host.launch(skill_id, Vector2(380.0, 700.0), owner)
	var safety := 0
	while bool(host.get_snapshot().get("thunder_orb_projectile_active", false)) and safety < 180:
		host.update(1.0 / 60.0, owner, registry, skill_id)
		safety += 1
	host.update(0.25, owner, registry, skill_id)
	_expect(int(host.get_thunder_orb_shock_count_for_tests()) == 0, "Thunder Orb must use boss-CENTER distance: a boss whose rect only clips the blast edge (centre outside 170px) is not stunned")
	_expect(status_state.get_calls_for_source("lumion_thunder_orb_electric_stun").is_empty(), "edge-only overlap should not apply the electric stun source")
	_expect(not audio.electric_syncs.has(true), "edge-only overlap should not start the electric shock loop")


func _verify_reset_stops_electric_loop_and_clears_status() -> void:
	# A round / pet-transition reset MID-STUN must stop the electric shock loop
	# and clear the thunder-orb stun source, even though the host reset path is
	# registry-less (the skill caches the last registry from update()).
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	var skill_id := "lumion_thunder_orb"
	host.launch(skill_id, Vector2(380.0, 700.0), owner)
	var safety := 0
	while bool(host.get_snapshot().get("thunder_orb_projectile_active", false)) and safety < 180:
		host.update(1.0 / 60.0, owner, registry, skill_id)
		safety += 1
	host.update(0.25, owner, registry, skill_id)  # finish explosion -> stun + loop live
	_expect(audio.electric_syncs.has(true), "stun should have started the electric shock loop before the reset")
	_expect(not audio.electric_syncs.has(false), "electric shock loop should still be running before the reset")
	_expect(not _has_clear(status_state.clears, "lumion_thunder_orb_electric_stun"), "stun source should still be live before the reset")
	host.reset()
	_expect(audio.electric_syncs.has(false), "reset mid-stun should stop the electric shock loop")
	_expect(_has_clear(status_state.clears, "lumion_thunder_orb_electric_stun"), "reset mid-stun should clear the thunder orb stun source")


func _verify_rail_card_reads_thunder_casting() -> void:
	var runtime := FakeLingpetRuntime.new()
	runtime.snapshot = {
		"companion_skill_id": "lumion_thunder_orb",
		"companion_skill_name": "천둥 뇌구",
		"companion_skill_description": "빠르게 발사된 뒤 감속해 폭발합니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/lumion_cutin_art.png",
		"companion_skill_cooldown": 19.0,
		"companion_skill_cooldown_duration": 25.0,
		"companion_skill_ready": false,
		"thunder_orb_explosion_active": true,
	}
	var rail_entry: Dictionary = LingpetRailCard.build_entry(FakeRegistry.new(null, null, runtime))
	_expect(str(rail_entry.get("id", "")) == "lumion_thunder_orb", "shared rail-card entry should use the Lumion Thunder Orb skill id")
	_expect(str(rail_entry.get("status", "")) == "casting", "Thunder Orb projectile/explosion/stun should read as casting on the shared rail")
	_expect(absf(float(rail_entry.get("cooldown_total", 0.0)) - 25.0) <= 0.01, "Thunder Orb rail entry should carry its 25s cooldown")


func _advance_module_to_explosion_end(skill: Object, owner: Object, registry: Object) -> void:
	var safety := 0
	while skill.is_projectile_active() and safety < 240:
		skill.update(1.0 / 60.0, owner, registry)
		safety += 1
	skill.update(0.25, owner, registry)  # finish the 0.2s explosion -> judge the blast


func _verify_mini_spark_count_scales_with_level() -> void:
	# Lv.3+ schedules count == active level (Lv.3->3, Lv.4->4, Lv.5->5); none below.
	for level_case in [{"level": 2, "expected": 0}, {"level": 3, "expected": 3}, {"level": 4, "expected": 4}, {"level": 5, "expected": 5}]:
		var skill: Object = LingpetThunderOrbSkill.new()
		var owner := FakeOwner.new()
		skill.launch(Vector2(380.0, 700.0), owner, {"active_skill_level": int(level_case["level"])})
		_expect(
			int(skill.get_mini_spark_total_for_tests()) == int(level_case["expected"]),
			"Thunder Orb Lv.%d should schedule %d mini-sparks" % [int(level_case["level"]), int(level_case["expected"])]
		)


func _verify_mini_spark_stuns_after_main_stun_ends() -> void:
	# Boss centre sits inside the blast -> main stun triggers. Mini-sparks must NOT
	# start during the main stun (메인 감전중엔 무효); only after it ends do they
	# crackle and re-stun the still-near boss for 0.5s.
	var skill: Object = LingpetThunderOrbSkill.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new(status_state, FakeAudio.new())
	skill.launch(Vector2(380.0, 700.0), owner, {"active_skill_level": 3, "stun_duration_seconds": 0.4})
	skill.set_mini_spark_offset_scale_for_tests(0.0)  # sparks at the blast centre (deterministic hit)
	_advance_module_to_explosion_end(skill, owner, registry)
	_expect(skill.is_electric_stun_active(), "main stun should be active right after the blast")
	_expect(int(skill.get_mini_spark_remaining_for_tests()) == 0, "mini-sparks must NOT start while the main stun is active (메인 감전중엔 무효)")
	var safety := 0
	while int(skill.get_mini_spark_applied_count_for_tests()) == 0 and safety < 150:
		skill.update(1.0 / 60.0, owner, registry)
		safety += 1
	_expect(int(skill.get_mini_spark_applied_count_for_tests()) >= 1, "a mini-spark touching the boss after the main stun should apply a 0.5s stun")
	_expect(skill.is_electric_stun_active(), "the mini-spark stun should re-stun the boss")
	_expect(not status_state.get_calls_for_source("lumion_thunder_orb_electric_stun").is_empty(), "mini-spark stun should apply the thunder-orb stun source")


func _verify_mini_spark_miss_does_not_stun() -> void:
	# Boss far from the blast -> the main blast misses (no main stun), so the Lv.5
	# chain starts right after the explosion; every spark still misses the distant boss.
	var skill: Object = LingpetThunderOrbSkill.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(12.0, 25.0)
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(status_state, audio)
	skill.launch(Vector2(720.0, 700.0), owner, {"active_skill_level": 5})
	_advance_module_to_explosion_end(skill, owner, registry)
	_expect(not skill.is_electric_stun_active(), "a far boss should not be caught by the main blast")
	_expect(int(skill.get_mini_spark_remaining_for_tests()) == 5, "with no main stun, the Lv.5 mini-spark chain starts right after the blast")
	var safety := 0
	while int(skill.get_mini_spark_remaining_for_tests()) > 0 and safety < 300:
		skill.update(1.0 / 60.0, owner, registry)
		safety += 1
	_expect(int(skill.get_mini_spark_applied_count_for_tests()) == 0, "mini-sparks must not stun a boss far from the explosion site")
	_expect(status_state.get_calls_for_source("lumion_thunder_orb_electric_stun").is_empty(), "a full miss chain should not apply the electric stun source")
	_expect(int(audio.mini_spark_plays) == 5, "each of the 5 mini-sparks should play a spark sound on appearance, even on a CC miss")


func _has_clear(clears: Array[Dictionary], source: String) -> bool:
	for clear_call in clears:
		if str(clear_call.get("source", "")) == source:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
