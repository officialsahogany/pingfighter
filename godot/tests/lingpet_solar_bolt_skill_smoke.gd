extends SceneTree

const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const LingpetSolarBoltSkill := preload("res://scripts/lingpet/lingpet_solar_bolt_skill.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SKILL_ID := "lumion_solar_bolt"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var skip_ball_motion_step := false
	var ball_pos := Vector2(620.0, 430.0)
	var ball_vel := Vector2(3.0, 12.0)
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var player_collision_cooldown := 0.0
	var player_pos := Vector2(240.0, 675.0)
	var player_paddle_width := 170.0
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeAudio:
	extends RefCounted

	var solar_count := 0
	var fallback_count := 0

	func play_solar_bolt_strike() -> void:
		solar_count += 1

	func play_active_item() -> void:
		fallback_count += 1


class FakeRegistry:
	extends RefCounted

	var game_audio: Object = null
	var ball_intensity: Object = null
	var lingpet_egg_runtime: Object = null

	func _init(audio: Object = null, intensity: Object = null, runtime: Object = null) -> void:
		game_audio = audio
		ball_intensity = intensity
		lingpet_egg_runtime = runtime

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		match key:
			"game_audio":
				return game_audio
			"ball_intensity":
				return ball_intensity
			"lingpet_egg_runtime":
				return lingpet_egg_runtime
		return null


class FakeLingpetRuntime:
	extends RefCounted

	var snapshot: Dictionary = {}

	func is_companion_active(_pet_id: String = "") -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return snapshot


func _init() -> void:
	seed(20260614)
	_verify_dispatcher_audio_and_no_catalog_exposure()
	_verify_can_arm_gate_matrix()
	_verify_first_strike_speed_owner_and_cooldown()
	_verify_defense_intercept_disarms_after_reflect()
	_verify_launch_time_refire_preroll()
	_verify_refire_retargets_current_boss_center_once()
	_verify_host_feedback_snapshot_and_rail_card()
	_verify_reset_and_ball_inactive_cancel_refires()
	_verify_source_wiring_surfaces()

	if _failures.is_empty():
		print("lingpet_solar_bolt_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_audio_and_no_catalog_exposure() -> void:
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_solar_bolt_skill.gd"), "Solar Bolt runtime module should exist")
	_expect(LingpetSkillDispatcher.is_supported_kind("solar_bolt"), "solar_bolt should be a supported runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "lumion_solar_bolt should route through the dispatcher")
	_expect(LingpetSkillDispatcher.is_solar_bolt(SKILL_ID), "dispatcher should expose a Solar Bolt helper")
	_expect(str(LingpetCatalog.get_active_skill_entry(SKILL_ID).get("runtime_kind", "")) == "solar_bolt", "Solar Bolt should be exposed as an affinity unlock candidate with runtime_kind")
	var solar_entry: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(str(solar_entry.get("card_texture_path", "")).ends_with("lumion_solar_bolt_skillcard_imagegen_v1.png"), "Solar Bolt should use the dedicated golden skill-card art")
	_expect(str(solar_entry.get("icon_texture_path", "")).ends_with("lumion_solar_bolt_skill_icon_imagegen_v1.png"), "Solar Bolt should use the dedicated golden skill icon")
	_expect(str(LingpetCatalog.get_active_skill("lumion").get("id", "")) == "lumion_thunder_orb", "Lumion default active should remain Thunder Orb")
	_expect(str(LingpetCatalog.get_active_skill("lumion", "", 1).get("id", "")) == "", "explicit empty active id should not fall back to Lumion pool[0]")
	_expect(str(LingpetCatalog.build_empty_loadout("lumion").get("active_skill_id", "")) == "", "explicit empty Lumion hatch loadout should keep active skill empty")
	var hatch_rng := RandomNumberGenerator.new()
	hatch_rng.seed = 20260626
	var hatch_loadout: Dictionary = LingpetCatalog.pick_skill_loadout("lumion", hatch_rng)
	var hatch_active_id := str(hatch_loadout.get("active_skill_id", ""))
	_expect(hatch_active_id == "" or hatch_active_id == "lumion_thunder_orb", "Lumion hatch roll should only use empty active or the default Thunder Orb active")
	_expect(hatch_active_id != SKILL_ID, "Lumion hatch roll should not grant Solar Bolt before affinity unlock resolve")
	_expect(FileAccess.file_exists(GameAudio.SOLAR_BOLT_STRIKE_SOUND_PATH), "Solar Bolt should expose a dedicated strike sound path")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.SOLAR_BOLT_STRIKE_SOUND_PATH) != null, "Solar Bolt strike sound should load through the resource helper")
	_expect(absf(GameAudio.SOLAR_BOLT_STRIKE_GAIN_DB - linear_to_db(0.5)) <= 0.001, "Solar Bolt strike gain should preserve the original 0.5 volume target")


func _verify_can_arm_gate_matrix() -> void:
	var host := LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var params := _base_params(owner)
	_expect(bool(host.can_arm(SKILL_ID, params)), "Solar Bolt should arm for a descending lower-half ball the player cannot block")

	var upward := _base_params(owner)
	upward["ball_vel"] = Vector2(0.0, -12.0)
	_expect(not bool(host.can_arm(SKILL_ID, upward)), "Solar Bolt should not arm for an upward ball")

	var upper := _base_params(owner)
	upper["ball_pos"] = Vector2(620.0, 240.0)
	_expect(not bool(host.can_arm(SKILL_ID, upper)), "Solar Bolt should not arm in the upper half")

	var hidden := _base_params(owner)
	hidden["companion_visible"] = false
	_expect(not bool(host.can_arm(SKILL_ID, hidden)), "Solar Bolt should require a visible companion")

	owner.skip_ball_motion_step = true
	_expect(not bool(host.can_arm(SKILL_ID, _base_params(owner))), "Solar Bolt should not arm while another owner skips ball motion")
	owner.skip_ball_motion_step = false

	owner.player_pos = Vector2(560.0, 675.0)
	_expect(not bool(host.can_arm(SKILL_ID, _base_params(owner))), "Solar Bolt should not steal balls the player can block")
	owner.player_pos = Vector2(240.0, 675.0)

	var past_player := _base_params(owner)
	past_player["ball_pos"] = Vector2(620.0, 668.0)
	_expect(not bool(host.can_arm(SKILL_ID, past_player)), "Solar Bolt should only arm while the ball is still above the player paddle")


func _verify_first_strike_speed_owner_and_cooldown() -> void:
	var owner := FakeOwner.new()
	var intensity := BallIntensity.new()
	var registry := FakeRegistry.new(null, intensity)
	var skill := LingpetSolarBoltSkill.new()
	skill.set_jitter_degrees_for_tests([0.0])
	var speed_pre := owner.ball_vel.length()
	_expect(bool(skill.launch(Vector2(500.0, 610.0), owner, _launch_context(owner, registry, 2, 50.0))), "Solar Bolt first strike should launch")
	_expect(skill.get_strike_count_for_tests() == 1, "Lv.2 Solar Bolt should perform only the first strike")
	_expect(owner.ball_vel.y < 0.0, "Solar Bolt first strike should force the ball upward")
	_expect(absf(owner.ball_vel.length() - speed_pre) <= 0.001, "Solar Bolt first strike should preserve px/frame speed")
	_expect(owner.player_collision_cooldown >= 6.0, "Solar Bolt first strike should set the player collision cooldown floor")
	_expect(not owner.skip_ball_motion_step, "Solar Bolt should not own the ball or set skip_ball_motion_step")
	_expect(str(intensity.get_last_hit_by()) == "player", "Solar Bolt should transfer rally ownership to the player side")
	_expect(intensity.contact_count == 1, "Solar Bolt should register exactly one ball-intensity contact for the first strike")

	var cooldown_owner := FakeOwner.new()
	cooldown_owner.player_collision_cooldown = 9.0
	var cooldown_skill := LingpetSolarBoltSkill.new()
	cooldown_skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(cooldown_skill.launch(Vector2(500.0, 610.0), cooldown_owner, _launch_context(cooldown_owner, null, 2, 50.0))), "cooldown-preserve case should launch")
	_expect(absf(cooldown_owner.player_collision_cooldown - 9.0) <= 0.001, "Solar Bolt should preserve an existing higher player collision cooldown")


func _verify_defense_intercept_disarms_after_reflect() -> void:
	var owner := FakeOwner.new()
	var motion := LingpetCompanionMotionState.new()
	motion.initialize(owner, true, 1, 80.0, 160.0)
	motion.configure_for_tests(Vector2(500.0, 610.0), 991, 0.0, true)
	var armed_snapshot: Dictionary = motion.get_snapshot(120.0, 80.0, 160.0, 1.0)
	_expect(bool(armed_snapshot.get("companion_defense_intercept_active", false)), "S15 setup should start with defense intercept armed")

	var skill := LingpetSolarBoltSkill.new()
	skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(skill.launch(Vector2(500.0, 610.0), owner, _launch_context(owner, null, 2, 50.0))), "S15 Solar Bolt launch should reflect the descending ball")
	_expect(owner.ball_vel.y < 0.0, "S15 Solar Bolt launch should leave the ball traveling upward")
	motion.update(1.0 / 60.0, owner, false, 1.0, 1, 120.0, 80.0, 160.0)
	var disarmed_snapshot: Dictionary = motion.get_snapshot(120.0, 80.0, 160.0, 1.0)
	_expect(not bool(disarmed_snapshot.get("companion_defense_intercept_active", true)), "S15 reflected upward ball should disarm the companion defense intercept on the next motion tick")
	_expect(float(disarmed_snapshot.get("companion_defense_decision_timer", 1.0)) <= 0.001, "S15 reflected upward ball should clear the defense decision timer")


func _verify_launch_time_refire_preroll() -> void:
	var fail_owner := FakeOwner.new()
	var fail_skill := LingpetSolarBoltSkill.new()
	fail_skill.set_force_rolls_for_tests([1.0])
	fail_skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(fail_skill.launch(Vector2(500.0, 610.0), fail_owner, _launch_context(fail_owner, null, 3, 50.0))), "Lv.3 Solar Bolt forced-fail launch should still perform first strike")
	_expect(fail_skill.get_scheduled_refires_for_tests() == 0, "Lv.3 forced-fail preroll should schedule no follow-up")
	fail_skill.update(3.0, fail_owner, null)
	_expect(fail_skill.get_strike_count_for_tests() == 1, "forced-fail preroll should not roll again on later frames")

	var lv3_owner := FakeOwner.new()
	var lv3_audio := FakeAudio.new()
	var lv3_registry := FakeRegistry.new(lv3_audio, BallIntensity.new())
	var lv3_skill := LingpetSolarBoltSkill.new()
	lv3_skill.set_force_rolls_for_tests([0.0, 1.0])
	lv3_skill.set_jitter_degrees_for_tests([0.0])
	# Re-fire gap is now a per-follow-up 0.5..1.0s roll; force 0.6s to seal the
	# delta-gated timing (and prove a sub-1.0s gap fires correctly).
	lv3_skill.set_force_refire_delays_for_tests([0.6])
	_expect(bool(lv3_skill.launch(Vector2(500.0, 610.0), lv3_owner, _launch_context(lv3_owner, lv3_registry, 3, 50.0))), "Lv.3 forced-success launch should schedule one follow-up")
	_expect(lv3_skill.get_scheduled_refires_for_tests() == 1, "Lv.3 should schedule exactly one follow-up on success")
	lv3_owner.ball_pos = Vector2(500.0, 300.0)
	lv3_skill.update(0.59, lv3_owner, lv3_registry)
	_expect(lv3_skill.get_strike_count_for_tests() == 1, "refire timer should be delta-based and not fire before the rolled 0.6s gap")
	lv3_skill.update(0.02, lv3_owner, lv3_registry)
	_expect(lv3_skill.get_strike_count_for_tests() == 2, "Lv.3 follow-up should fire once after the 0.6s gap without consuming a fire-time reroll")
	_expect(lv3_audio.solar_count == 1, "follow-up strike should play the dedicated Solar Bolt cue")

	var lv5_owner := FakeOwner.new()
	var lv5_skill := LingpetSolarBoltSkill.new()
	lv5_skill.set_force_rolls_for_tests([0.0, 0.0])
	lv5_skill.set_jitter_degrees_for_tests([0.0])
	# Two follow-ups -> two independent gap rolls; force 1.0s each to keep the
	# catch-up-clamp math deterministic (one re-fire per update + carry).
	lv5_skill.set_force_refire_delays_for_tests([1.0, 1.0])
	_expect(bool(lv5_skill.launch(Vector2(500.0, 610.0), lv5_owner, _launch_context(lv5_owner, null, 5, 50.0))), "Lv.5 forced-success launch should schedule two follow-ups")
	_expect(lv5_skill.get_scheduled_refires_for_tests() == 2, "Lv.5 should cap at two extra strikes")
	lv5_owner.ball_pos = Vector2(500.0, 300.0)
	lv5_skill.update(2.05, lv5_owner, null)
	_expect(lv5_skill.get_strike_count_for_tests() == 2, "Lv.5 catch-up delta should fire at most one follow-up per update")
	_expect(lv5_skill.get_scheduled_refires_for_tests() == 1, "Lv.5 catch-up delta should keep the remaining follow-up queued")
	lv5_skill.update(0.0, lv5_owner, null)
	_expect(lv5_skill.get_strike_count_for_tests() == 3, "Lv.5 should still cap at three total strikes across separate updates")
	_expect(lv5_skill.get_scheduled_refires_for_tests() == 0, "Lv.5 should drain queued follow-ups after the final strike")

	var chain_fail_owner := FakeOwner.new()
	var chain_fail_skill := LingpetSolarBoltSkill.new()
	chain_fail_skill.set_force_rolls_for_tests([1.0, 0.0])
	chain_fail_skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(chain_fail_skill.launch(Vector2(500.0, 610.0), chain_fail_owner, _launch_context(chain_fail_owner, null, 5, 50.0))), "Lv.5 first-roll fail launch should still perform first strike")
	_expect(chain_fail_skill.get_scheduled_refires_for_tests() == 0, "Lv.5 chain should break on the first failed preroll and not use later rolls")


func _verify_refire_retargets_current_boss_center_once() -> void:
	var owner := FakeOwner.new()
	var skill := LingpetSolarBoltSkill.new()
	skill.set_force_rolls_for_tests([0.0])
	skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(skill.launch(Vector2(500.0, 610.0), owner, _launch_context(owner, null, 3, 50.0))), "retarget case should launch")
	owner.ball_pos = Vector2(300.0, 300.0)
	owner.boss_pos = Vector2(500.0, 25.0)
	var ball_center := owner.ball_pos + Vector2(owner.ball_size * 0.5, owner.ball_size * 0.5)
	var boss_center := Rect2(owner.boss_pos, Vector2(owner.boss_paddle_width, owner.boss_hitbox_height)).get_center()
	var expected_dir := (boss_center - ball_center).normalized()
	var speed_locked := float(skill.get_snapshot().get("solar_bolt_speed_locked", 0.0))
	owner.ball_vel = Vector2(0.0, 40.0)
	skill.update(1.01, owner, null)
	_expect(owner.ball_vel.normalized().dot(expected_dir) > 0.999, "follow-up should retarget once toward the current boss center")
	_expect(absf(owner.ball_vel.length() - speed_locked) <= 0.001, "follow-up should preserve the first-strike locked speed")
	_expect(absf(owner.ball_vel.length() - 40.0) > 0.1, "follow-up should not re-read the mutated owner ball speed at fire time")
	var locked_vel := owner.ball_vel
	owner.boss_pos = Vector2(120.0, 25.0)
	skill.update(0.20, owner, null)
	_expect(owner.ball_vel.is_equal_approx(locked_vel), "follow-up should not keep per-frame homing after its one-time retarget")


func _verify_host_feedback_snapshot_and_rail_card() -> void:
	var owner := FakeOwner.new()
	var host := LingpetSkillRuntimeHost.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio, BallIntensity.new())
	host.set_solar_bolt_jitter_degrees_for_tests([0.0])
	host.set_solar_bolt_force_roll_for_tests(1.0)
	_expect(bool(host.launch(SKILL_ID, Vector2(500.0, 610.0), owner, _launch_context(owner, registry, 2, 50.0))), "host should launch Solar Bolt")
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.solar_count == 1, "host launch feedback should use play_solar_bolt_strike")
	_expect(bool(host.is_launch_blocked(SKILL_ID)), "Solar Bolt should block relaunch while its VFX is visible")
	var snapshot := host.get_snapshot()
	_expect(bool(snapshot.get("solar_bolt_active", false)), "host snapshot should merge Solar Bolt active state")
	_expect(int(host.get_solar_bolt_strike_count_for_tests()) == 1, "host test getter should expose Solar Bolt strikes")

	var reset_owner := FakeOwner.new()
	var reset_host := LingpetSkillRuntimeHost.new()
	reset_host.set_solar_bolt_force_rolls_for_tests([0.0, 0.0])
	reset_host.set_solar_bolt_jitter_degrees_for_tests([0.0])
	_expect(bool(reset_host.launch(SKILL_ID, Vector2(500.0, 610.0), reset_owner, _launch_context(reset_owner, null, 5, 50.0))), "host reset case should launch Solar Bolt")
	_expect(reset_host.get_solar_bolt_scheduled_refires_for_tests() == 2, "host reset case should have queued Solar Bolt refires")
	reset_host.reset(reset_owner, null)
	_expect(reset_host.get_solar_bolt_scheduled_refires_for_tests() == 0, "host.reset should clear queued Solar Bolt refires")
	_expect(not bool(reset_host.get_solar_bolt_snapshot_for_tests().get("solar_bolt_active", true)), "host.reset should clear Solar Bolt active state")

	var runtime := FakeLingpetRuntime.new()
	runtime.snapshot = {
		"companion_skill_id": SKILL_ID,
		"companion_skill_name": "Solar Bolt",
		"companion_skill_description": "standalone hidden test entry",
		"companion_skill_cooldown": 10.0,
		"companion_skill_cooldown_duration": 22.0,
		"companion_skill_ready": false,
		"solar_bolt_refire_pending": true,
	}
	var rail_entry: Dictionary = LingpetRailCard.build_entry(FakeRegistry.new(null, null, runtime))
	_expect(str(rail_entry.get("id", "")) == SKILL_ID, "shared rail-card entry should accept Solar Bolt snapshots")
	_expect(str(rail_entry.get("status", "")) == "casting", "Solar Bolt refire/VFX flags should read as casting on the shared rail")


func _verify_reset_and_ball_inactive_cancel_refires() -> void:
	var owner := FakeOwner.new()
	var reset_skill := LingpetSolarBoltSkill.new()
	reset_skill.set_force_rolls_for_tests([0.0, 0.0])
	reset_skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(reset_skill.launch(Vector2(500.0, 610.0), owner, _launch_context(owner, null, 5, 50.0))), "reset case should launch")
	_expect(reset_skill.get_scheduled_refires_for_tests() == 2, "reset case should have pending refires")
	reset_skill.reset()
	_expect(reset_skill.get_scheduled_refires_for_tests() == 0, "reset should clear pending refires")
	_expect(not bool(reset_skill.get_snapshot().get("solar_bolt_active", true)), "reset should clear Solar Bolt active state")

	var inactive_owner := FakeOwner.new()
	var inactive_skill := LingpetSolarBoltSkill.new()
	inactive_skill.set_force_rolls_for_tests([0.0])
	inactive_skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(inactive_skill.launch(Vector2(500.0, 610.0), inactive_owner, _launch_context(inactive_owner, null, 3, 50.0))), "inactive-cancel case should launch")
	inactive_owner.ball_active = false
	inactive_skill.update(1.10, inactive_owner, null)
	_expect(inactive_skill.get_strike_count_for_tests() == 1, "ball_active=false at refire time should skip the follow-up strike")
	_expect(inactive_skill.get_scheduled_refires_for_tests() == 0, "ball_active=false at refire time should clear remaining refires")


func _verify_source_wiring_surfaces() -> void:
	var host_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	_expect(host_src.find("SOLAR_BOLT_SKILL_PATH") >= 0, "runtime host should lazy-load the Solar Bolt module")
	_expect(host_src.find("play_solar_bolt_strike") >= 0, "runtime host should call the dedicated Solar Bolt audio API")
	var payload_builder_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")
	_expect(payload_builder_src.find("\"refire_chance_pct\"") >= 0, "payload builder should pass Solar Bolt refire chance through launch_context")
	var rail_src := FileAccess.get_file_as_string("res://scripts/stages/common/lingpet_rail_card.gd")
	_expect(rail_src.find("solar_bolt_refire_pending") >= 0, "lingpet rail card should include Solar Bolt casting flags")
	var audio_src := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(audio_src.find("SOLAR_BOLT_STRIKE_SOUND_PATH") >= 0, "GameAudio should declare the Solar Bolt strike sound path")
	_expect(audio_src.find("func play_solar_bolt_strike") >= 0, "GameAudio should expose the Solar Bolt strike method")
	var solar_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_solar_bolt_skill.gd")
	_expect(solar_src.find("while _scheduled_refires") < 0, "Solar Bolt refire updates should not drain multiple queued strikes in one update")
	_expect(solar_src.find("skip_ball_motion_step\", true") < 0 and solar_src.find("skip_ball_motion_step = true") < 0, "Solar Bolt should never set skip_ball_motion_step ownership")


func _base_params(owner: FakeOwner) -> Dictionary:
	return {
		"owner": owner,
		"skill_id": SKILL_ID,
		"ball_active": owner.ball_active,
		"ball_pos": owner.ball_pos,
		"ball_vel": owner.ball_vel,
		"ball_size": owner.ball_size,
		"companion_visible": true,
		"companion_pos": Vector2(500.0, 610.0),
		"companion_radius": 24.0,
		"active_skill_level": 1,
	}


func _launch_context(owner: FakeOwner, registry: Object, level: int, refire_chance_pct: float) -> Dictionary:
	return {
		"registry": registry,
		"companion_pos": Vector2(500.0, 610.0),
		"active_skill_level": level,
		"refire_chance_pct": refire_chance_pct,
		"ball_active": owner.ball_active,
		"ball_pos": owner.ball_pos,
		"ball_vel": owner.ball_vel,
		"ball_size": owner.ball_size,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
