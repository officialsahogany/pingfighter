extends SceneTree

const SpellbreakerGuardState := preload("res://scripts/characters/perk_fusion_spellbreaker_guard_state.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")
const Stage1DaljiBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd")
const Stage2BossSkillState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage3BossSkillScheduler := preload("res://scripts/stages/stage3/stage3_boss_skill_scheduler.gd")
const Stage4PonkRuntimeCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_runtime_coordinator.gd")
const Stage4PonkIllusionState := preload("res://scripts/stages/stage4/stage4_ponk_illusion_state.gd")
const Stage4PonkMagneticFieldState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_field_state.gd")
const Stage4PonkMagneticProjectileState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_projectile_state.gd")
const Stage4PonkMeditationState := preload("res://scripts/stages/stage4/stage4_ponk_meditation_state.gd")
const Stage4PonkFxHostCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_fx_host_coordinator.gd")
const Stage4PonkBallInteractionCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_ball_interaction_coordinator.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")

var _failures: Array[String] = []


class FakeRuntime:
	extends RefCounted
	var state: Object = SpellbreakerGuardState.new()
	var owned: Array = ["spellbreaker_guard"]

	func can_activate_perk_fusion_spellbreaker_guard() -> bool:
		return owned.has("spellbreaker_guard") and not bool(state.is_active())

	func try_activate_perk_fusion_spellbreaker_guard(
		roll_unit: float,
		player_center: Vector2
	) -> Dictionary:
		return state.try_activate(owned, roll_unit, player_center)

	func is_perk_fusion_boss_skill_parry_active() -> bool:
		return bool(state.is_active())

	func try_parry_perk_fusion_boss_skill(skill_id: String, label: String, impact_pos: Vector2) -> Dictionary:
		return state.try_parry(skill_id, label, impact_pos)

	func open_ward() -> void:
		state.try_activate(owned, 0.0, Vector2(380.0, 700.0))

	func parry_count() -> int:
		return int(state.get_snapshot().get("spellbreaker_guard_parry_count", 0))


class FakeAudio:
	extends RefCounted
	var block_count := 0

	func play_spellbreaker_guard_parry() -> void:
		block_count += 1


class FakeSpinningTop:
	extends RefCounted
	var activation_count := 0

	func is_active() -> bool:
		return false

	func activate(_context: Dictionary, _deps: Dictionary) -> bool:
		activation_count += 1
		return true


class FakePaddleBounceController:
	extends RefCounted
	var bounce_count := 0

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		_context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary
	) -> Dictionary:
		bounce_count += 1
		return {"ball_vel": Vector2(0.0, -8.0)}


class FakeStage2Background:
	extends RefCounted
	var quake_count := 0

	func activate_quake(
		_duration: float,
		_rock_count: int,
		_flag: bool,
		_launch_guard: bool,
		_deps: Dictionary
	) -> bool:
		quake_count += 1
		return true


class FakeStage3Skill:
	extends RefCounted
	var ready := true
	var parried_count := 0
	var activate_count := 0

	func is_ready() -> bool:
		return ready

	func consume_parried() -> void:
		parried_count += 1

	func activate(_first = null, _second = null) -> void:
		activate_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_exact_roll_and_duration_contract()
	_verify_multiple_parries_do_not_consume_the_ward()
	_verify_parry_burst_anchors_on_the_boss_skill_origin()
	_verify_production_paddle_hook()
	_verify_stage1_skill_is_spent_without_activation()
	_verify_stage2_quake_is_spent_without_activation()
	_verify_stage3_direct_skills_are_spent_without_activation()
	_verify_stage4_magnetic_field_is_spent_without_activation()
	_verify_stage5_fireball_is_spent_without_activation()
	if _failures.is_empty():
		print("perk_fusion_spellbreaker_guard_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_exact_roll_and_duration_contract() -> void:
	var state := SpellbreakerGuardState.new()
	var unowned: Dictionary = state.try_activate([], 0.0, Vector2(380.0, 700.0))
	_expect(not bool(unowned.get("rolled", true)), "an unowned ward must not consume a return roll")
	var success: Dictionary = state.try_activate(["spellbreaker_guard"], 0.119999, Vector2(380.0, 700.0))
	_expect(bool(success.get("triggered", false)), "a roll strictly below 12 percent should activate")
	_expect(state.is_active(), "successful return should open the five-second ward")
	var blocked_retrigger: Dictionary = state.try_activate(["spellbreaker_guard"], 0.0, Vector2.ZERO)
	_expect(not bool(blocked_retrigger.get("rolled", true)), "an active ward must not reroll on later returns")
	state.advance(4.999, null)
	_expect(state.is_active(), "ward should remain active until the full five seconds elapse")
	state.advance(0.001, null)
	_expect(not state.is_active(), "ward should expire exactly at five seconds")
	state.reset_round()
	var boundary: Dictionary = state.try_activate(["spellbreaker_guard"], 0.12, Vector2.ZERO)
	_expect(bool(boundary.get("rolled", false)) and not bool(boundary.get("triggered", true)), "the exact 12-percent boundary should fail")


func _verify_multiple_parries_do_not_consume_the_ward() -> void:
	var state := SpellbreakerGuardState.new()
	state.try_activate(["spellbreaker_guard"], 0.0, Vector2(380.0, 700.0))
	state.advance(1.25, null)
	var before: float = float(state.get_snapshot().get("spellbreaker_guard_remaining_sec", 0.0))
	var first: Dictionary = state.try_parry("skill_a", "첫 기술", Vector2(380.0, 180.0))
	var second: Dictionary = state.try_parry("skill_b", "둘째 기술", Vector2(420.0, 220.0))
	var snapshot: Dictionary = state.get_snapshot()
	_expect(bool(first.get("parried", false)) and bool(second.get("parried", false)), "one ward should parry multiple eligible skills")
	_expect(is_equal_approx(float(snapshot.get("spellbreaker_guard_remaining_sec", 0.0)), before), "parrying must not consume or shorten the original five-second timer")
	_expect(int(snapshot.get("spellbreaker_guard_parry_count", 0)) == 2, "each blocked skill should be recorded")
	_expect(bool(snapshot.get("spellbreaker_guard_vfx_active", false)), "activation and parry should keep visible ward feedback alive")
	state.reset_round()
	_expect(not state.is_active() and not bool(state.get_snapshot().get("spellbreaker_guard_vfx_active", true)), "round reset should clear ward gameplay and VFX")


# 파열광은 결계(플레이어) -> 쳐낸 스킬로 뻗어야 한다. 명시 위치를 넘기지 않는
# 호출부에서 원점이 플레이어 중심으로 잡히면 선 길이가 0이 되어 연출이 사라진다.
func _verify_parry_burst_anchors_on_the_boss_skill_origin() -> void:
	var runtime := FakeRuntime.new()
	runtime.open_ward()
	var player_center := Vector2(380.0, 725.0)
	var context := {
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var parried: bool = BossSkillParryGate.try_parry(
		"origin_probe",
		"원점 검사",
		context,
		{"runtime_perk_state": runtime}
	)
	_expect(parried, "an open ward should parry through the shared gate")
	var burst: Vector2 = runtime.state._last_parry_pos
	_expect(
		burst.distance_to(player_center) > 200.0,
		"a call site without an explicit impact position must not collapse the burst onto the ward itself"
	)
	_expect(
		burst.is_equal_approx(Vector2(380.0, 45.0)),
		"the implicit parry origin should be the boss paddle center that cast the skill"
	)


# 12% 굴림은 실제 플레이어 타구 커밋 경로에서만 일어나야 한다. 소스 문자열이
# 아니라 _process_paddle 왕복으로 봉인한다.
func _verify_production_paddle_hook() -> void:
	var processor := BallMotionEventProcessor.new()
	var runtime := FakeRuntime.new()
	var controller := FakePaddleBounceController.new()
	var deps := {
		"runtime_perk_state": runtime,
		"paddle_bounce_controller": controller,
	}
	var scene := {
		"ball_vel": Vector2(0.0, -8.0),
		"ball_pos": Vector2(380.0, 690.0),
	}
	var context := {
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"perk_fusion_spellbreaker_guard_roll_unit": 0.9,
	}
	var player_step := {"is_player": true, "paddle_x": 302.5, "paddle_w": 155.0}
	var missed: bool = processor._process_paddle(player_step, scene, context, deps, {})
	_expect(missed, "the player paddle bounce should commit through the live processor")
	_expect(not runtime.state.is_active(), "a 0.9 roll on a committed return must leave the ward closed")

	context["perk_fusion_spellbreaker_guard_roll_unit"] = 0.05
	processor._process_paddle(player_step, scene, context, deps, {})
	_expect(runtime.state.is_active(), "a 0.05 roll on a committed player return should open the ward through the live paddle path")

	var boss_runtime := FakeRuntime.new()
	var boss_deps := {
		"runtime_perk_state": boss_runtime,
		"paddle_bounce_controller": FakePaddleBounceController.new(),
	}
	var boss_context := context.duplicate(true)
	boss_context["perk_fusion_spellbreaker_guard_roll_unit"] = 0.0
	processor._process_paddle(
		{"is_player": false, "paddle_x": 330.0, "paddle_w": 100.0},
		scene.duplicate(true),
		boss_context,
		boss_deps,
		{}
	)
	_expect(not boss_runtime.state.is_active(), "a boss-side bounce must never roll the player ward")


func _verify_stage1_skill_is_spent_without_activation() -> void:
	var runtime := FakeRuntime.new()
	runtime.open_ward()
	var audio := FakeAudio.new()
	var spinning_top := FakeSpinningTop.new()
	var cooldown := Stage1DaljiBossSkillCooldownState.new()
	cooldown.update(960.0, {
		"current_stage": 1,
		"ball_active": true,
		"player_pos": Vector2(302.5, 700.0),
	}, {
		"runtime_perk_state": runtime,
		"audio": audio,
		"stage1_dalji_spinning_top_skill_state": spinning_top,
	})
	var skill: Dictionary = cooldown.skill_runtime.get("spinning_top", {})
	_expect(spinning_top.activation_count == 0, "a parried boss skill must not enter its gameplay activation")
	_expect(not bool(skill.get("ready", true)) and is_zero_approx(float(skill.get("timer", -1.0))), "the parried skill should still spend its ready state and restart cooldown")
	_expect(audio.block_count == 1, "a successful parry should play one block cue")
	_expect(runtime.parry_count() == 1, "the stage 1 gate should reach the live ward owner")


func _verify_stage2_quake_is_spent_without_activation() -> void:
	var runtime := FakeRuntime.new()
	runtime.open_ward()
	var background := FakeStage2Background.new()
	var state := Stage2BossSkillState.new()
	state.quake_cooldown = 0.0
	var context := {"waiting_for_serve": false, "ball_active": true}
	var parried: bool = state._activate_quake_from_cooldown(
		context,
		{"runtime_perk_state": runtime, "audio": FakeAudio.new()},
		background
	)
	_expect(parried, "a parried quake should still report the skill slot as spent")
	_expect(background.quake_count == 0, "a parried quake must not reach the stage background activation")
	_expect(state.quake_cooldown > 0.0, "a parried quake should restart its cooldown")
	_expect(runtime.parry_count() == 1, "the stage 2 gate should reach the live ward owner")

	var closed := Stage2BossSkillState.new()
	closed.quake_cooldown = 0.0
	var control_background := FakeStage2Background.new()
	var control_runtime := FakeRuntime.new()
	closed._activate_quake_from_cooldown(
		context,
		{"runtime_perk_state": control_runtime, "audio": FakeAudio.new()},
		control_background
	)
	_expect(control_background.quake_count == 1, "a closed ward must let the quake activate normally")
	_expect(control_runtime.parry_count() == 0, "a closed ward must not record a parry")


func _verify_stage3_direct_skills_are_spent_without_activation() -> void:
	var runtime := FakeRuntime.new()
	runtime.open_ward()
	var scheduler := Stage3BossSkillScheduler.new()
	var tear := FakeStage3Skill.new()
	var chest := FakeStage3Skill.new()
	var tail := FakeStage3Skill.new()
	var context := {"waiting_for_serve": false, "ball_active": true, "ball_pos": Vector2(380.0, 400.0)}
	var deps := {"runtime_perk_state": runtime, "audio": FakeAudio.new()}
	var outcome: String = scheduler.try_activate_skills(context, deps, false, true, false, tear, chest, tail, 1000)
	_expect(outcome == "tear_shower_parried", "the stage 3 scheduler should report the parried outcome")
	_expect(tear.activate_count == 0 and tear.parried_count == 1, "a parried tear shower must be consumed instead of activated")

	tear.ready = false
	outcome = scheduler.try_activate_skills(context, deps, false, true, false, tear, chest, tail, 1000)
	_expect(outcome == "curse_chest_parried", "the curse chest branch should route through the same gate")
	_expect(chest.activate_count == 0 and chest.parried_count == 1, "a parried curse chest must be consumed instead of activated")

	chest.ready = false
	outcome = scheduler.try_activate_skills(context, deps, false, true, false, tear, chest, tail, 1000)
	_expect(outcome == "tail_whip_parried", "the tail whip branch should route through the same gate")
	_expect(tail.activate_count == 0 and tail.parried_count == 1, "a parried tail whip must be consumed instead of activated")
	_expect(runtime.parry_count() == 3, "each stage 3 skill should reach the live ward owner")

	var control_runtime := FakeRuntime.new()
	var control_tear := FakeStage3Skill.new()
	var control_outcome: String = scheduler.try_activate_skills(
		context,
		{"runtime_perk_state": control_runtime, "audio": FakeAudio.new()},
		false,
		true,
		false,
		control_tear,
		FakeStage3Skill.new(),
		FakeStage3Skill.new(),
		1000
	)
	_expect(control_outcome == "tear_shower", "a closed ward must let the tear shower fire normally")
	_expect(control_tear.activate_count == 1 and control_tear.parried_count == 0, "a closed ward must not consume the skill as parried")


func _build_stage4_coordinator() -> Dictionary:
	var magnetic: Object = Stage4PonkMagneticFieldState.new()
	var coordinator: Object = Stage4PonkRuntimeCoordinator.new(
		magnetic,
		Stage4PonkMagneticProjectileState.new(),
		Stage4PonkMeditationState.new(RandomNumberGenerator.new()),
		Stage4PonkIllusionState.new(),
		Stage4PonkFxHostCoordinator.new(),
		Stage4PonkBallInteractionCoordinator.new()
	)
	return {"coordinator": coordinator, "magnetic": magnetic}


func _verify_stage4_magnetic_field_is_spent_without_activation() -> void:
	var runtime := FakeRuntime.new()
	runtime.open_ward()
	var built: Dictionary = _build_stage4_coordinator()
	var coordinator: Object = built["coordinator"]
	var magnetic: Object = built["magnetic"]
	coordinator.boss_special_ready = true
	var context := {
		"waiting_for_serve": false,
		"ball_active": true,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	coordinator._activate_magnetic(context, {"runtime_perk_state": runtime, "audio": FakeAudio.new()})
	_expect(not bool(magnetic.get("magnetic_active")), "a parried magnetic field must not become active")
	_expect(not bool(coordinator.boss_special_ready), "a parried magnetic field should still spend the boss special charge")
	_expect(runtime.parry_count() == 1, "the stage 4 gate should reach the live ward owner")

	var control_built: Dictionary = _build_stage4_coordinator()
	var control: Object = control_built["coordinator"]
	var control_magnetic: Object = control_built["magnetic"]
	control.boss_special_ready = true
	var control_runtime := FakeRuntime.new()
	control._activate_magnetic(context, {"runtime_perk_state": control_runtime, "audio": FakeAudio.new()})
	_expect(bool(control_magnetic.get("magnetic_active")), "a closed ward must let the magnetic field activate")
	_expect(control_runtime.parry_count() == 0, "a closed ward must not record a parry")


func _verify_stage5_fireball_is_spent_without_activation() -> void:
	var runtime := FakeRuntime.new()
	runtime.open_ward()
	var state := Stage5HongryunState.new()
	var context := {
		"ball_active": true,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var result: Dictionary = {}
	state._spawn_fireball_volley(context, {"runtime_perk_state": runtime, "audio": FakeAudio.new()}, result)
	_expect(bool(result.get("stage5_hongryun_fireball_parried", false)), "a parried fireball volley should report the parried outcome")
	_expect(state.fireball_cooldown > 0.0, "a parried fireball volley should restart its cooldown")
	_expect(runtime.parry_count() == 1, "the stage 5 gate should reach the live ward owner")

	var control := Stage5HongryunState.new()
	var control_runtime := FakeRuntime.new()
	var control_result: Dictionary = {}
	control._spawn_fireball_volley(
		context,
		{"runtime_perk_state": control_runtime, "audio": FakeAudio.new()},
		control_result
	)
	_expect(not bool(control_result.get("stage5_hongryun_fireball_parried", false)), "a closed ward must not report a parried fireball volley")
	_expect(control_runtime.parry_count() == 0, "a closed ward must not record a parry")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
