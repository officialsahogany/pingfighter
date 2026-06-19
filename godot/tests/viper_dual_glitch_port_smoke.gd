extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const TooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const DualGlitchEffectRenderer := preload("res://scripts/characters/viper_skill_dual_glitch_effect_renderer.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	var equipped := ["dual_glitch", "blade_rush", "dive_strike"]

	func is_skill_equipped(skill_name: String) -> bool:
		return equipped.has(skill_name)

	func get_skill_cost(skill_name: String) -> float:
		match skill_name:
			"dual_glitch":
				return 220.0
			"blade_rush":
				return 200.0
			"dive_strike":
				return 150.0
		return 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		match skill_name:
			"dual_glitch":
				return 45.0
			"blade_rush":
				return 20.0
			"dive_strike":
				return 70.0
		return 0.0


class FakeSkillState:
	var triggered: Array[String] = []
	var cooldown_seconds: Dictionary = {}

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered.append(skill_name)

	func trigger_cooldown(skill_name: String, _now_msec: int, seconds: float) -> void:
		triggered.append(skill_name)
		cooldown_seconds[skill_name] = seconds

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakePerkState:
	var levels: Dictionary = {"four_poisons": 0, "blade_amp": 0}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeAudio:
	var blade_fire := 0
	var dual_glitch_windup := 0
	var dual_glitch_split := 0
	var dual_glitch_windup_stopped := 0

	func play_viper_blade() -> void:
		blade_fire += 1

	func play_viper_dual_glitch_windup() -> void:
		dual_glitch_windup += 1

	func stop_viper_dual_glitch_windup() -> void:
		dual_glitch_windup_stopped += 1

	func play_viper_dual_glitch_split() -> void:
		dual_glitch_split += 1


class FakeOwner:
	var selected_character_type := "viper"
	var runtime_accessory_slot_bonus := 0
	var runtime_paddle_scale := 1.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false


class RealViperRegistry:
	var perk_state: Object
	var skill_config: Object

	func _init(new_perk_state: Object, new_skill_config: Object) -> void:
		perk_state = new_perk_state
		skill_config = new_skill_config

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return perk_state
			"viper_skill_config":
				return skill_config
		return null


class FakeMotionStepper:
	var captured_context: Dictionary = {}

	func step(ball_pos: Vector2, _effective_move: Vector2, _ball_vel: Vector2, context: Dictionary) -> Dictionary:
		captured_context = context.duplicate(true)
		return {
			"event": "player_paddle",
			"ball_pos": ball_pos,
			"paddle_x": 12.0,
			"paddle_w": 155.0,
			"is_player": true,
			"viper_dual_glitch_clone_hit": true,
			"viper_dual_glitch_clone_index": 1,
			"viper_dual_glitch_clone_side": 1,
		}


class FakePaddleController:
	var captured_context: Dictionary = {}

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary = {}
	) -> Dictionary:
		captured_context = context.duplicate(true)
		return {
			"ball_pos": context.get("ball_pos", Vector2.ZERO),
			"ball_vel": context.get("ball_vel", Vector2.ZERO),
		}


func _init() -> void:
	_test_catalog_unlock_wiring()
	_test_command_activation_clone_collision_and_hp()
	_test_dual_glitch_activation_plays_windup_sound()
	_test_dual_glitch_spawn_plays_split_sound()
	_test_actor_context_and_sprite_clone_geometry()
	_test_dual_glitch_startup_body_wiggle()
	_test_dual_glitch_spawn_alpha_flicker()
	_test_dual_glitch_spawn_echo_and_split()
	_test_dual_glitch_clone_steam_puff()
	_test_dual_glitch_timeout_dispel_slices()
	_test_dual_glitch_dispel_real_sprite_slicing()
	_test_dual_glitch_effect_renderer_startup_parity_source()
	_test_round_boundary_preserves_active_dual_glitch()
	_test_startup_cancel_and_four_poisons_super_armor()
	_test_four_poisons_duration_cooldown_and_replication()
	_test_four_poisons_emp_clone_replication()
	_test_motion_processor_forwards_clone_context()
	_test_tooltip_runtime_bonus()
	print("viper_dual_glitch_port_smoke: ok")
	quit(0)


func _test_catalog_unlock_wiring() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var perk_state: Object = RuntimePerkState.new()
	var skill_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := RealViperRegistry.new(perk_state, skill_config)
	var unlock_data: Dictionary = catalog.get_perk_data("unlock_dual_glitch")
	_expect(not unlock_data.is_empty(), "unlock_dual_glitch should exist in the Viper perk catalog")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "dual_glitch", "unlock_dual_glitch should equip the dual_glitch orb")
	_expect(not skill_config.is_skill_equipped("dual_glitch"), "Dual Glitch should not be equipped before the unlock")
	unlock_data["id"] = "unlock_dual_glitch"
	_expect(perk_state.apply_choice(unlock_data, owner, registry), "selecting unlock_dual_glitch should apply cleanly")
	_expect(perk_state.get_runtime_skill_level("unlock_dual_glitch") == 1, "unlock perk level should be recorded")
	_expect(skill_config.is_skill_equipped("dual_glitch"), "Dual Glitch unlock should equip the runtime skill")


func _test_command_activation_clone_collision_and_hp() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var deps := _deps(input, skill_config, skill_state, perk_state, orb, feedback, FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	var result: Dictionary = _activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "A-D-A-D should activate Dual Glitch")
	_expect(str(result.get("skill_name", "")) == "dual_glitch", "Dual Glitch activation should report its skill id")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 280.0) < 0.01, "Dual Glitch should spend 220 gauge")
	_expect(skill_state.triggered.back() == "dual_glitch", "Dual Glitch activation should trigger its cooldown")
	_expect(orb.spins == 1, "Dual Glitch activation should spin the skill orb")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(str(snap.get("dual_glitch_state", "")) == "startup", "Dual Glitch should begin in startup")
	_expect((snap.get("dual_glitch_clones", []) as Array).size() == 2, "Dual Glitch should create two clones")
	_expect(int(((snap.get("dual_glitch_clones", []) as Array)[0] as Dictionary).get("hp", 0)) == 2, "base clone HP should be 2")

	var moved_pos := Vector2(420.0, player_pos.y)
	result = runtime.try_activate_before_movement(1.0 / 60.0, moved_pos, 280.0, config, deps)
	_expect(abs(_get_vector2(result, "player_pos", moved_pos).x - player_pos.x) < 0.01, "startup should lock Viper's X position")
	_advance_dual(runtime, config, deps, player_pos, 49)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "spawn", "startup should advance into spawn")
	_advance_dual(runtime, config, deps, player_pos, 24)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "active", "spawn should advance into active")

	var collision_context: Dictionary = config.duplicate(true)
	collision_context["player_pos"] = player_pos
	collision_context["player_collision_cooldown"] = 0.0
	collision_context.merge(runtime.get_ball_collision_context(), true)
	var clone_entries: Array = collision_context.get("viper_dual_glitch_clone_rects", [])
	_expect(clone_entries.size() == 2, "active Dual Glitch should expose two clone collision rects")
	var clone_rect: Rect2 = (clone_entries[0] as Dictionary).get("rect", Rect2())
	_expect(abs(clone_rect.position.x - (player_pos.x - 140.0)) < 0.01, "left clone offset should match Python's paddle width plus -15 padding")
	var detector: Object = BallMotionCollisionDetector.new()
	var collision: Dictionary = detector.check_paddles(clone_rect.get_center(), Vector2(0.0, 8.0), 28.6, collision_context)
	_expect(str(collision.get("event", "")) == "player_paddle", "clone rect should participate in player paddle collision")
	_expect(bool(collision.get("viper_dual_glitch_clone_hit", false)), "clone collision should be tagged for post-hit handling")

	var first_index: int = int(collision.get("viper_dual_glitch_clone_index", -1))
	var hp_result: Dictionary = runtime.apply_dual_glitch_clone_ball_hit(collision, deps)
	_expect(bool(hp_result.get("hit", false)) and int(hp_result.get("clone_hp", -1)) == 1, "first clone hit should reduce HP")
	hp_result = runtime.apply_dual_glitch_clone_ball_hit(collision, deps)
	_expect(bool(hp_result.get("clone_destroyed", false)), "second hit should destroy a base clone")
	var second_hit := {"viper_dual_glitch_clone_index": 1 if first_index == 0 else 0}
	runtime.apply_dual_glitch_clone_ball_hit(second_hit, deps)
	hp_result = runtime.apply_dual_glitch_clone_ball_hit(second_hit, deps)
	_expect(bool(hp_result.get("clone_destroyed", false)), "destroying the final clone should be detected")
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "fade", "Dual Glitch should fade after all clones are destroyed")


func _test_dual_glitch_activation_plays_windup_sound() -> void:
	# 발동 → startup(부르르 떠는) 단계 진입 시 dualglitch1.wav가 정확히 1회 재생되어야 한다.
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var audio := FakeAudio.new()
	var deps := _deps(input, FakeSkillConfig.new(), FakeSkillState.new(), FakePerkState.new(), FakeOrbHud.new(), FakeFeedback.new(), audio)
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	var result: Dictionary = _activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "A-D-A-D should activate Dual Glitch")
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "startup", "activation should enter the startup trembling phase")
	_expect(audio.dual_glitch_windup == 1, "Dual Glitch startup should play the dualglitch1 windup cue exactly once")

	# 게이지 부족으로 발동이 막히면 windup 큐는 울리지 않아야 한다(가드 이후에만 재생).
	var blocked_runtime: Object = ViperSkillRuntime.new()
	var blocked_input := FakeInput.new()
	var blocked_audio := FakeAudio.new()
	var blocked_deps := _deps(blocked_input, FakeSkillConfig.new(), FakeSkillState.new(), FakePerkState.new(), FakeOrbHud.new(), FakeFeedback.new(), blocked_audio)
	var blocked: Dictionary = _activate_dual_glitch(blocked_runtime, blocked_input, player_pos, 10.0, config, blocked_deps)
	_expect(not bool(blocked.get("activated", false)), "insufficient gauge should not activate Dual Glitch")
	_expect(blocked_audio.dual_glitch_windup == 0, "a blocked Dual Glitch activation must not play the windup trembling cue")


func _test_dual_glitch_spawn_plays_split_sound() -> void:
	# 분신이 몸에서 갈라져 분리되는 순간(startup -> spawn)에 dualglitch2(split)가 1회 재생되고,
	# 그때 dualglitch1(windup)은 정지되어야 한다.
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var audio := FakeAudio.new()
	var deps := _deps(input, FakeSkillConfig.new(), FakeSkillState.new(), FakePerkState.new(), FakeOrbHud.new(), FakeFeedback.new(), audio)
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_expect(audio.dual_glitch_windup == 1, "activation should play the dualglitch1 windup")
	_expect(audio.dual_glitch_split == 0, "split cue must not play during startup, before the clones separate")
	_expect(audio.dual_glitch_windup_stopped == 0, "windup should not stop before the split moment")

	# startup(48f)을 지나 spawn 진입 = 분리 시작 순간.
	_advance_dual(runtime, config, deps, player_pos, 49)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "spawn", "should reach the spawn split phase")
	_expect(audio.dual_glitch_split == 1, "clone separation (startup -> spawn) should play dualglitch2 exactly once")
	_expect(audio.dual_glitch_windup_stopped == 1, "dualglitch1 windup should stop when dualglitch2 plays")

	# spawn 내에서 더 진행해도 split 큐가 반복 재생되면 안 된다.
	_advance_dual(runtime, config, deps, player_pos, 6)
	_expect(audio.dual_glitch_split == 1, "split cue should fire once at the transition, not every spawn frame")


func _test_actor_context_and_sprite_clone_geometry() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	var actor_context: Dictionary = runtime.get_actor_draw_context()
	_expect(str(actor_context.get("viper_dual_glitch_state", "")) == "active", "actor draw context should expose active Dual Glitch state")
	var clone_entries: Array = actor_context.get("viper_dual_glitch_clone_rects", [])
	_expect(clone_entries.size() == 2, "actor draw context should expose visible Dual Glitch clone entries")

	var renderer: Object = Stage1PlayerActorRenderer.new()
	var visual_rect := Rect2(Vector2(300.0, 582.0), Vector2(160.0, 160.0))
	actor_context["selected_character_type"] = "viper"
	actor_context["viper_dual_glitch_wiggle_amplitude"] = 0.0
	var clone_draws: Array = renderer.build_viper_dual_glitch_clone_sprite_draws(
		actor_context,
		visual_rect,
		false,
		player_pos,
		Vector2(155.0, 50.0),
		Vector2.ZERO
	)
	_expect(clone_draws.size() == 2, "player actor renderer should build two clone sprite draw passes")
	var first_draw: Dictionary = clone_draws[0]
	var first_visual_rect: Rect2 = first_draw.get("visual_rect", Rect2())
	var first_rect: Rect2 = (clone_entries[0] as Dictionary).get("rect", Rect2())
	_expect(first_visual_rect.size == visual_rect.size, "clone draw should reuse the full player sprite size instead of the paddle hitbox size")
	_expect(abs(first_visual_rect.position.y - visual_rect.position.y) < 0.01, "clone sprite should keep the live player sprite's vertical anchor")
	_expect(abs(first_visual_rect.position.x - (first_rect.position.x - 2.5)) < 0.01, "clone sprite should preserve the player sprite offset from the paddle rect")
	var main_modulate: Color = first_draw.get("main_modulate", Color.WHITE)
	_expect(main_modulate.a < 1.0, "clone sprite pass should render as a ghosted copied sprite")


func _test_dual_glitch_startup_body_wiggle() -> void:
	# 원본 _get_viper_dual_glitch_startup_offset_px(): startup 동안 본체 렌더 rect만
	# ±3px / 12Hz 좌우 흔들림. phase 1.25 = sin(pi/2) -> +3px 피크.
	var renderer: Object = Stage1PlayerActorRenderer.new()
	_expect(abs(renderer.compute_dual_glitch_startup_wiggle_x("idle", 1.25)) < 0.0001, "wiggle must be zero outside startup (idle)")
	_expect(abs(renderer.compute_dual_glitch_startup_wiggle_x("active", 1.25)) < 0.0001, "wiggle must be zero outside startup (active)")
	_expect(abs(renderer.compute_dual_glitch_startup_wiggle_x("startup", 1.25) - 3.0) < 0.0001, "startup wiggle should peak at +3px at phase 1.25 (sin(pi/2))")
	var base_rect := Rect2(Vector2(100.0, 600.0), Vector2(160.0, 160.0))
	var shifted: Rect2 = renderer.apply_dual_glitch_startup_body_wiggle(
		base_rect, {"viper_dual_glitch_state": "startup", "viper_dual_glitch_phase_frames": 1.25}
	)
	_expect(abs(shifted.position.x - (base_rect.position.x + 3.0)) < 0.0001, "startup wiggle should shift the body rect X by the wiggle amount")
	_expect(abs(shifted.position.y - base_rect.position.y) < 0.0001, "startup wiggle must leave the body rect Y unchanged")
	var unchanged: Rect2 = renderer.apply_dual_glitch_startup_body_wiggle(base_rect, {"viper_dual_glitch_state": "idle"})
	_expect(unchanged == base_rect, "no wiggle outside startup must leave the body rect untouched")


func _test_dual_glitch_spawn_alpha_flicker() -> void:
	var spawn_frames := 22.8
	var quarter_phase := spawn_frames * 0.25
	var quarter_expected: float = 0.25 * (1.0 - pow(0.75, 0.7) * 0.7)
	var quarter_actor: float = Stage1PlayerActorRenderer.compute_dual_glitch_spawn_alpha_factor(quarter_phase, spawn_frames)
	var quarter_effect: float = DualGlitchEffectRenderer.compute_dual_glitch_spawn_alpha_factor(quarter_phase, spawn_frames)
	_expect(abs(quarter_actor - quarter_expected) < 0.0001, "spawn alpha at 25% should use Python pulse-dim ramp, not a linear 0.25")
	_expect(abs(quarter_effect - quarter_expected) < 0.0001, "effect renderer spawn alpha should match the actor sprite alpha ramp")
	_expect(quarter_actor < 0.14, "spawn alpha 25% pulse-dim trough should stay visibly below the linear ramp")

	var half_phase := spawn_frames * 0.5
	var half_expected: float = 0.5 * (1.0 - pow(0.5, 0.7) * 0.7)
	var half_actor: float = Stage1PlayerActorRenderer.compute_dual_glitch_spawn_alpha_factor(half_phase, spawn_frames)
	var half_effect: float = DualGlitchEffectRenderer.compute_dual_glitch_spawn_alpha_factor(half_phase, spawn_frames)
	_expect(abs(half_actor - half_expected) < 0.0001, "spawn alpha at 50% should keep the second Python pulse-dim trough")
	_expect(abs(half_effect - half_expected) < 0.0001, "effect renderer should keep the second Python pulse-dim trough")
	_expect(half_actor < 0.32, "spawn alpha 50% trough should remain below the old linear 0.5 ramp")


func _test_dual_glitch_spawn_echo_and_split() -> void:
	# 원본 spawn 잔상(echo afterimage) + chromatic split 확장 패리티.
	# split shift: active 2px 수렴, spawn 동안 확장.
	_expect(abs(Stage1PlayerActorRenderer.compute_dual_glitch_split_shift("active", 1.0) - 2.0) < 0.0001, "active chromatic split should settle to the 2px base")
	_expect(Stage1PlayerActorRenderer.compute_dual_glitch_split_shift("spawn", 0.125) > 6.0, "spawn chromatic split should widen well past the 2px base")
	# split alpha boost: active 1.0, spawn 시작에서 밝아짐.
	_expect(abs(Stage1PlayerActorRenderer.compute_dual_glitch_split_alpha_boost("active", 1.0) - 1.0) < 0.0001, "active split alpha boost should be 1.0")
	_expect(Stage1PlayerActorRenderer.compute_dual_glitch_split_alpha_boost("spawn", 0.0) > 1.5, "spawn split alpha boost should brighten ghosts at spawn start")
	# echo alpha: 중간 펄스 피크에서 보이고 spawn 완료 시 0.
	_expect(Stage1PlayerActorRenderer.compute_dual_glitch_echo_alpha(0, 0.5, 0.63) > 0.1, "echo should be clearly visible at its mid-spawn pulse peak")
	_expect(Stage1PlayerActorRenderer.compute_dual_glitch_echo_alpha(0, 1.0, 0.63) <= 0.0001, "echoes must fade out by spawn completion (residual -> 0)")
	_expect(abs(Stage1PlayerActorRenderer.compute_dual_glitch_echo_t(0, 0.5) - 0.5) < 0.0001, "echo_t for idx0 at mid-spawn should be 0.5 (halfway player -> clone)")

	# build 배선: spawn은 echoes + 확장 shift, active는 echoes 없음 + 2px base.
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var deps := _deps(input, skill_config, FakeSkillState.new(), FakePerkState.new(), FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 54)  # startup(48) 지나 spawn 중반
	var renderer_inst: Object = Stage1PlayerActorRenderer.new()
	var spawn_ctx: Dictionary = runtime.get_actor_draw_context()
	spawn_ctx["selected_character_type"] = "viper"
	spawn_ctx["viper_dual_glitch_wiggle_amplitude"] = 0.0
	_expect(str(spawn_ctx.get("viper_dual_glitch_state", "")) == "spawn", "test setup should land in spawn")
	var visual_rect := Rect2(Vector2(300.0, 582.0), Vector2(160.0, 160.0))
	var spawn_draws: Array = renderer_inst.build_viper_dual_glitch_clone_sprite_draws(spawn_ctx, visual_rect, false, player_pos, Vector2(155.0, 50.0), Vector2.ZERO)
	_expect(spawn_draws.size() == 2, "spawn build should still produce two clone draws")
	var spawn_first: Dictionary = spawn_draws[0]
	var spawn_echoes: Array = spawn_first.get("echoes", [])
	_expect(spawn_echoes.size() >= 1, "spawn clone draw should carry echo afterimage passes")
	_expect(float(spawn_first.get("ghost_shift_x", 0.0)) > 2.0, "spawn clone split shift should be widened above the 2px base")
	var echo0: Dictionary = spawn_echoes[0]
	var echo_x: float = (echo0.get("rect", Rect2()) as Rect2).position.x
	var clone_x: float = (spawn_first.get("visual_rect", Rect2()) as Rect2).position.x
	var lo: float = min(visual_rect.position.x, clone_x) - 0.5
	var hi: float = max(visual_rect.position.x, clone_x) + 0.5
	_expect(echo_x >= lo and echo_x <= hi, "echo should sit between the player body and the clone position")

	_advance_dual(runtime, config, deps, player_pos, 24)  # spawn -> active
	var active_ctx: Dictionary = runtime.get_actor_draw_context()
	active_ctx["selected_character_type"] = "viper"
	active_ctx["viper_dual_glitch_wiggle_amplitude"] = 0.0
	_expect(str(active_ctx.get("viper_dual_glitch_state", "")) == "active", "test setup should reach active")
	var active_draws: Array = renderer_inst.build_viper_dual_glitch_clone_sprite_draws(active_ctx, visual_rect, false, player_pos, Vector2(155.0, 50.0), Vector2.ZERO)
	_expect((active_draws[0] as Dictionary).get("echoes", []).size() == 0, "active clones must have no echo afterimages")
	_expect(abs(float((active_draws[0] as Dictionary).get("ghost_shift_x", 0.0)) - 2.0) < 0.0001, "active clone split should settle to the 2px base")


func _test_dual_glitch_clone_steam_puff() -> void:
	# 원본: 공에 맞아 파괴된 분신(hp<=0 + evaporating)은 스프라이트 대신 스팀 퍼프로 증발.
	# 퍼프 알파: idx 클수록 어둡고, evaporation 끝에서 0.
	_expect(
		Stage1PlayerActorRenderer.compute_dual_glitch_steam_puff_alpha(0, 0.0, 0.63) > Stage1PlayerActorRenderer.compute_dual_glitch_steam_puff_alpha(2, 0.0, 0.63),
		"steam puff 0 should be brighter than puff 2"
	)
	_expect(Stage1PlayerActorRenderer.compute_dual_glitch_steam_puff_alpha(0, 1.0, 0.63) <= 0.0001, "steam should fully fade at evaporation end")
	_expect(Stage1PlayerActorRenderer.compute_dual_glitch_steam_puff_alpha(0, 0.0, 0.63) > 0.2, "steam puff 0 should start clearly visible")

	# build: 파괴/증발 중 분신 -> steam_puff draw spec(스프라이트 패스 없음), 생존 분신은 스프라이트 유지.
	var renderer_inst: Object = Stage1PlayerActorRenderer.new()
	var ctx := {
		"selected_character_type": "viper",
		"viper_dual_glitch_state": "active",
		"viper_dual_glitch_alpha": 0.63,
		"viper_dual_glitch_wiggle_amplitude": 0.0,
		"viper_dual_glitch_evaporation_frames": 13.2,
		"viper_dual_glitch_clone_rects": [
			{"rect": Rect2(Vector2(160.0, 560.0), Vector2(155.0, 50.0)), "index": 0, "side": -1, "hp": 0, "evaporating": true, "evaporation_frames": 5.0},
			{"rect": Rect2(Vector2(445.0, 560.0), Vector2(155.0, 50.0)), "index": 1, "side": 1, "hp": 2},
		],
	}
	var visual_rect := Rect2(Vector2(300.0, 472.0), Vector2(160.0, 160.0))
	var draws: Array = renderer_inst.build_viper_dual_glitch_clone_sprite_draws(ctx, visual_rect, false, Vector2(302.5, 560.0), Vector2(155.0, 50.0), Vector2.ZERO)
	_expect(draws.size() == 2, "build should emit a draw for the steaming clone and the live clone")
	var steam_found := false
	var live_has_sprite := false
	for d_value in draws:
		var d: Dictionary = d_value
		if bool(d.get("steam_puff", false)):
			steam_found = true
			_expect(not d.has("main_modulate"), "steam clone must not carry sprite passes")
			_expect(float(d.get("evaporation_progress", -1.0)) > 0.0, "steam clone should carry its evaporation progress")
		elif d.has("main_modulate"):
			live_has_sprite = true
	_expect(steam_found, "destroyed/evaporating clone should produce a steam_puff draw spec")
	_expect(live_has_sprite, "the surviving clone should still draw its sprite")


func _test_dual_glitch_timeout_dispel_slices() -> void:
	_expect(abs(Stage1PlayerActorRenderer.compute_dual_glitch_timeout_drift_y(0.0) - 6.0) < 0.0001, "timeout dispel should start with Python's 6px upward drift")
	_expect(abs(Stage1PlayerActorRenderer.compute_dual_glitch_timeout_drift_y(1.0) - 24.0) < 0.0001, "timeout dispel should end with Python's 24px upward drift")
	var early_slice_alpha: float = Stage1PlayerActorRenderer.compute_dual_glitch_timeout_slice_alpha(0, 0.0, 0.63)
	var late_slice_alpha: float = Stage1PlayerActorRenderer.compute_dual_glitch_timeout_slice_alpha(0, 0.8, 0.63)
	var lower_slice_alpha: float = Stage1PlayerActorRenderer.compute_dual_glitch_timeout_slice_alpha(7, 0.0, 0.63)
	_expect(early_slice_alpha > late_slice_alpha, "timeout slice alpha should fade as the dispel progresses")
	_expect(early_slice_alpha > lower_slice_alpha, "later horizontal slices should be dimmer like the Python slice_index falloff")
	_expect(Stage1PlayerActorRenderer.compute_dual_glitch_timeout_ghost_alpha(0.0, 0.63) > Stage1PlayerActorRenderer.compute_dual_glitch_timeout_ghost_alpha(1.0, 0.63), "timeout split ghosts should dim over the dispel")
	var offset_start: Vector2 = Stage1PlayerActorRenderer.compute_dual_glitch_timeout_slice_offset(3, 0, -1, 0.0, 0.0)
	var offset_end: Vector2 = Stage1PlayerActorRenderer.compute_dual_glitch_timeout_slice_offset(3, 0, -1, 1.0, 0.0)
	_expect(offset_end.y < offset_start.y, "timeout slices should drift upward as fade progresses")

	var renderer_inst: Object = Stage1PlayerActorRenderer.new()
	var ctx := {
		"selected_character_type": "viper",
		"viper_dual_glitch_state": "fade",
		"viper_dual_glitch_fade_reason": "timeout",
		"viper_dual_glitch_phase_frames": 9.0,
		"viper_dual_glitch_fade_frames": 18.0,
		"viper_dual_glitch_alpha": 0.63,
		"viper_dual_glitch_wiggle_amplitude": 0.0,
		"viper_dual_glitch_clone_rects": [
			{"rect": Rect2(Vector2(160.0, 560.0), Vector2(155.0, 50.0)), "index": 0, "side": -1, "hp": 2},
			{"rect": Rect2(Vector2(445.0, 560.0), Vector2(155.0, 50.0)), "index": 1, "side": 1, "hp": 2},
		],
	}
	var visual_rect := Rect2(Vector2(300.0, 472.0), Vector2(160.0, 160.0))
	var timeout_draws: Array = renderer_inst.build_viper_dual_glitch_clone_sprite_draws(ctx, visual_rect, false, Vector2(302.5, 560.0), Vector2(155.0, 50.0), Vector2.ZERO)
	_expect(timeout_draws.size() == 2, "timeout fade should keep both clones visible as dispel specs")
	var first_timeout: Dictionary = timeout_draws[0]
	_expect(bool(first_timeout.get("timeout_dispel", false)), "timeout fade clone should use the dispel draw path")
	_expect(not first_timeout.has("main_modulate"), "timeout dispel must replace the normal sprite clone pass")
	_expect((first_timeout.get("slice_specs", []) as Array).size() == 8, "timeout dispel should emit the Python-style 8 horizontal slices")
	_expect((first_timeout.get("particles", []) as Array).size() == 16, "timeout dispel should emit the Python-style 16 particles")
	_expect((first_timeout.get("ghosts", []) as Array).size() == 2, "timeout dispel should emit the two chromatic split ghosts")
	_expect(float(first_timeout.get("drift_y", 0.0)) > 6.0, "mid-fade timeout dispel should have upward drift beyond the starting offset")
	var timeout_drift_y: float = float(first_timeout.get("drift_y", 0.0))
	var first_slice: Dictionary = (first_timeout.get("slice_specs", []) as Array)[0]
	var first_slice_rect: Rect2 = first_slice.get("rect", Rect2())
	var first_slice_offset: Vector2 = first_slice.get("offset", Vector2.ZERO)
	_expect(
		abs(first_slice_rect.position.y - (visual_rect.position.y + first_slice_offset.y - timeout_drift_y)) < 0.01,
		"timeout slice rect should include both Python vertical offsets: slice offset -drift_y plus whole glitch surface -drift_y"
	)
	var first_particle: Dictionary = (first_timeout.get("particles", []) as Array)[0]
	var first_particle_pos: Vector2 = first_particle.get("pos", Vector2.ZERO)
	var first_particle_local_offset: Vector2 = first_particle.get("local_offset", Vector2.ZERO)
	var first_visual_rect: Rect2 = first_timeout.get("visual_rect", Rect2())
	_expect(
		abs(first_particle_pos.y - (first_visual_rect.position.y + first_particle_local_offset.y - timeout_drift_y)) < 0.01,
		"timeout particles should inherit the whole glitch surface -drift_y upward blit offset"
	)

	ctx["viper_dual_glitch_fade_reason"] = "destroyed"
	var destroyed_draws: Array = renderer_inst.build_viper_dual_glitch_clone_sprite_draws(ctx, visual_rect, false, Vector2(302.5, 560.0), Vector2(155.0, 50.0), Vector2.ZERO)
	_expect(destroyed_draws.size() == 2, "destroyed fade with living entries should still build regular clone draws")
	_expect(not bool((destroyed_draws[0] as Dictionary).get("timeout_dispel", false)), "destroyed fade must not use timeout-only slice dispel")

	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var deps := _deps(input, FakeSkillConfig.new(), FakeSkillState.new(), FakePerkState.new(), FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	runtime.dual_glitch_active_total_frames = 0.0
	_advance_dual(runtime, config, deps, player_pos, 1)
	var actor_ctx: Dictionary = runtime.get_actor_draw_context()
	_expect(str(actor_ctx.get("viper_dual_glitch_state", "")) == "fade", "timeout setup should enter Dual Glitch fade")
	_expect(str(actor_ctx.get("viper_dual_glitch_fade_reason", "")) == "timeout", "actor draw context should expose timeout fade reason for dispel rendering")


func _test_dual_glitch_dispel_real_sprite_slicing() -> void:
	# resolve 훅: 현재 컨텍스트가 그릴 base 스프라이트의 (texture, region, flip)을
	# 캔버스에 그리지 않고 회수해야 한다(디졸브 슬라이스가 실제 스프라이트를 자르기 위함).
	var renderer_inst: Object = Stage1PlayerActorRenderer.new()
	var sr: Object = renderer_inst.sprite_renderer
	var img := Image.create_empty(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.6, 1.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	var sprite_ctx := {
		"selected_character_type": "viper",
		"player_sprite_texture": tex,
		"player_sprite_frame_count": 1,
		"player_sprite_frame_width": 64.0,
		"player_sprite_frame_height": 96.0,
	}
	var resolved: Dictionary = sr.resolve_current_sprite(
		sprite_ctx, Rect2(Vector2.ZERO, Vector2(160.0, 160.0)), false, Vector2.ZERO, Vector2(155.0, 50.0), Vector2.ZERO
	)
	_expect(resolved.get("texture", null) == tex, "resolve hook should return the live sprite texture without drawing")
	var region: Rect2 = resolved.get("region", Rect2())
	_expect(region.size.x > 0.0 and region.size.y > 0.0, "resolve hook should return a non-empty source region")
	_expect(not bool(resolved.get("flip_h", true)), "directional viper walk sprite should resolve unflipped")

	# slice_specs가 실제 텍스처 슬라이싱용 source-band 분수(src_frac_y/h)와 틴트 modulate를 운반.
	var ctx := {
		"selected_character_type": "viper",
		"viper_dual_glitch_state": "fade",
		"viper_dual_glitch_fade_reason": "timeout",
		"viper_dual_glitch_alpha": 0.63,
		"viper_dual_glitch_wiggle_amplitude": 0.0,
		"viper_dual_glitch_fade_frames": 18.0,
		"viper_dual_glitch_phase_frames": 6.0,
		"viper_dual_glitch_clone_rects": [
			{"rect": Rect2(Vector2(160.0, 560.0), Vector2(155.0, 50.0)), "index": 0, "side": -1, "hp": 2},
		],
	}
	var draws: Array = renderer_inst.build_viper_dual_glitch_clone_sprite_draws(
		ctx, Rect2(Vector2(300.0, 472.0), Vector2(160.0, 160.0)), false, Vector2(302.5, 560.0), Vector2(155.0, 50.0), Vector2.ZERO
	)
	_expect(draws.size() == 1, "timeout dispel build should produce one dispel draw")
	var specs: Array = (draws[0] as Dictionary).get("slice_specs", [])
	_expect(specs.size() == 8, "dispel should emit 8 horizontal slices")
	var s0: Dictionary = specs[0]
	_expect(abs(float(s0.get("src_frac_y", -1.0))) < 0.001, "slice 0 source band starts at the top of the sprite region")
	_expect(abs(float(s0.get("src_frac_h", 0.0)) - 0.125) < 0.01, "each slice covers ~1/8 of the sprite region height")
	_expect((s0.get("modulate", Color.WHITE) as Color).a > 0.0, "slice carries a tint modulate alpha for the textured strip")
	var s4: Dictionary = specs[4]
	_expect(abs(float(s4.get("src_frac_y", -1.0)) - 0.5) < 0.02, "slice 4 source band starts ~halfway down the sprite region")


func _test_dual_glitch_effect_renderer_startup_parity_source() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_dual_glitch_effect_renderer.gd")
	_expect(
		source.find("var ring_center: Vector2 = foot + Vector2(0.0, 10.0)") >= 0,
		"Dual Glitch startup ring center should match Python's foot_y + 10 center: blit -ring_r + 6 plus local ring_r + 4"
	)
	_expect(
		source.find("shock_t") < 0 and source.find("shock_center") < 0,
		"Dual Glitch startup should not draw the dormant Python spawn_shockwave dead-call as a live green shockwave"
	)
	_expect(
		source.find("DUAL_GLITCH_RGB_SPLIT") >= 0 and source.find("for spark_idx in range(8)") >= 0,
		"Dual Glitch startup should keep the Python RGB split rings and 8-spark loop"
	)


func _test_round_boundary_preserves_active_dual_glitch() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	var remaining_before_reset: float = float(runtime.get_snapshot().get("dual_glitch_remaining_frames", 0.0))
	runtime.reset_round(deps)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(str(snap.get("dual_glitch_state", "")) == "active", "round reset should preserve active Dual Glitch for the next round")
	_expect((snap.get("dual_glitch_clones", []) as Array).size() == 2, "round reset should preserve living Dual Glitch clones")
	_expect(abs(float(snap.get("dual_glitch_remaining_frames", 0.0)) - remaining_before_reset) < 0.01, "round reset should preserve Dual Glitch's remaining duration")

	var waiting_context := _base_config()
	waiting_context["ball_active"] = false
	waiting_context["waiting_for_serve"] = true
	waiting_context["player_pos"] = Vector2(380.0, 680.0)
	waiting_context["player_paddle_size"] = Vector2(155.0, 50.0)
	runtime.update_effects(120.0, Time.get_ticks_msec(), waiting_context, deps)
	snap = runtime.get_snapshot()
	_expect(str(snap.get("dual_glitch_state", "")) == "active", "serve-wait frames should pause, not cancel, cross-round Dual Glitch")
	_expect(abs(float(snap.get("dual_glitch_remaining_frames", 0.0)) - remaining_before_reset) < 0.01, "serve-wait frames should not consume Dual Glitch's remaining duration")
	_expect(abs(_get_vector2(snap, "dual_glitch_base_pos", Vector2.ZERO).x - 380.0) < 0.01, "serve-wait frames should re-anchor carried Dual Glitch clones to the reset paddle")

	runtime.update_effects(10.0, Time.get_ticks_msec(), config, deps)
	_expect(float(runtime.get_snapshot().get("dual_glitch_remaining_frames", 0.0)) < remaining_before_reset, "next live round should resume Dual Glitch's countdown")
	var hard_reset_deps := deps.duplicate()
	hard_reset_deps["preserve_dual_glitch"] = false
	runtime.reset_round(hard_reset_deps)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "idle", "explicit hard reset should still clear Dual Glitch")


func _test_startup_cancel_and_four_poisons_super_armor() -> void:
	var low_poison := _make_runtime_bundle(0)
	var runtime: Object = low_poison["runtime"]
	_activate_dual_glitch(runtime, low_poison["input"], Vector2(302.5, 680.0), 500.0, _base_config(), low_poison["deps"])
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "startup", "Dual Glitch startup should be active before contact")
	runtime.register_player_ball_contact(low_poison["deps"], _base_config())
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "idle", "Dual Glitch startup should cancel on player-ball contact without Four Poisons super armor")

	var armored := _make_runtime_bundle(3)
	runtime = armored["runtime"]
	_activate_dual_glitch(runtime, armored["input"], Vector2(302.5, 680.0), 500.0, _base_config(), armored["deps"])
	runtime.register_player_ball_contact(armored["deps"], _base_config())
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "startup", "Four Poisons Lv3 super armor should preserve Dual Glitch startup")


func _test_four_poisons_duration_cooldown_and_replication() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = 5
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	var result: Dictionary = _activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "Four Poisons should not block Dual Glitch activation")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(abs(float(snap.get("dual_glitch_active_total_frames", 0.0)) - 1197.0) < 0.01, "Four Poisons Lv5 should extend Dual Glitch active time by 33%")
	_expect(abs(float(skill_state.cooldown_seconds.get("dual_glitch", 0.0)) - 32.0) < 0.01, "Four Poisons Lv5 should reduce Dual Glitch cooldown by 20%")
	_expect(int(((snap.get("dual_glitch_clones", []) as Array)[0] as Dictionary).get("hp", 0)) == 4, "Four Poisons Lv5 should raise clone HP to 4")
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	runtime._launch_blade_projectile(player_pos, config, deps)
	snap = runtime.get_snapshot()
	var followups: Array = snap.get("blade_followup_projectiles", [])
	_expect(followups.size() == 2, "Four Poisons Lv5 active Dual Glitch should replicate Blade Rush from both living clones")
	for projectile_value in followups:
		var projectile: Dictionary = projectile_value
		_expect(bool(projectile.get("dual_glitch_replica", false)), "replicated blades should be tagged as Dual Glitch replicas")


func _test_four_poisons_emp_clone_replication() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = 5
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	config["player_floor_y"] = 680.0
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "active", "Dual Glitch should be active before EMP replication")

	var dive_pos := Vector2(302.5, 560.0)
	runtime._start_dive_strike(dive_pos, 500.0, config, deps, Time.get_ticks_msec())
	var dive_result: Dictionary = {}
	for _i in range(32):
		dive_result = runtime._update_dive_strike(1.0 / 60.0, dive_pos, 350.0, config, deps)
		dive_pos = _get_vector2(dive_result, "player_pos", dive_pos)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(int(snap.get("dive_phase", -1)) == 2, "EMP should land before checking clone shockwaves")
	_expect((snap.get("dual_glitch_clone_dive_entries", []) as Array).size() == 2, "Four Poisons Lv5 should schedule two clone EMP shockwaves")

	var scene := {
		"ball_pos": Vector2(380.0, 720.0),
		"ball_vel": Vector2(0.0, 8.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	var result: Dictionary = runtime.apply_emp_strike_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel") and not bool(result.get("viper_dual_glitch_clone_emp_hit", false)), "primary EMP should hit first and remain the gold-bearing hit")
	scene.merge(result, true)
	motion_context.merge(scene, true)
	for _i in range(13):
		runtime.update_effects(1.0, Time.get_ticks_msec(), motion_context, deps)
	result = runtime.apply_emp_strike_ball_motion(1.0, scene, motion_context, deps)
	_expect(bool(result.get("viper_dual_glitch_clone_emp_hit", false)), "left clone EMP should be able to refresh the ball hit after the stagger")
	_expect(not result.has("runtime_perk_gold") and not result.has("skill_gold_award"), "clone EMP replication should not duplicate EMP gold")


func _test_motion_processor_forwards_clone_context() -> void:
	var processor: Object = BallMotionEventProcessor.new()
	var stepper := FakeMotionStepper.new()
	var paddle_controller := FakePaddleController.new()
	var scene := {
		"ball_pos": Vector2(200.0, 690.0),
		"ball_vel": Vector2(0.0, 8.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	var context := _base_config()
	context["viper_dual_glitch_state"] = "active"
	context["viper_dual_glitch_clone_rects"] = [{
		"rect": Rect2(Vector2(162.5, 680.0), Vector2(155.0, 50.0)),
		"index": 1,
		"side": -1,
	}]
	processor.step_motion(scene, 1.0, context, {
		"motion_stepper": stepper,
		"paddle_bounce_controller": paddle_controller,
	}, {})
	_expect(stepper.captured_context.has("viper_dual_glitch_clone_rects"), "motion step context should preserve clone rects")
	_expect(bool(paddle_controller.captured_context.get("viper_dual_glitch_clone_hit", false)), "paddle bounce context should receive clone hit tag")
	_expect(int(paddle_controller.captured_context.get("viper_dual_glitch_clone_index", -1)) == 1, "paddle bounce context should receive clone index")


func _test_tooltip_runtime_bonus() -> void:
	var renderer: Object = TooltipRenderer.new()
	var skill_config: Object = ViperSkillConfig.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = 5
	var skill_data: Dictionary = skill_config.get_skill_data("dual_glitch")
	var hover_context := {"runtime_perk_state": perk_state}
	var description: String = renderer._build_description_with_runtime_bonus(skill_data, hover_context)
	_expect(description.find("분신 HP 4") >= 0, "Dual Glitch tooltip should show Four Poisons clone HP")
	_expect(description.find("스킬 복제") >= 0, "Dual Glitch tooltip should show the Lv5 clone replication bonus")
	var cooldown: float = renderer._get_effective_skill_cooldown_seconds(skill_data, hover_context)
	_expect(abs(cooldown - 32.0) < 0.01, "Dual Glitch tooltip cooldown should include Four Poisons reduction")


func _activate_dual_glitch(
	runtime: Object,
	input: Object,
	player_pos: Vector2,
	gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	for key in ["left_pressed", "right_pressed", "left_pressed", "right_pressed"]:
		input.snapshot[key] = true
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		if bool(result.get("activated", false)):
			return result
		input.snapshot[key] = false
		runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	return result


func _advance_dual(runtime: Object, config: Dictionary, deps: Dictionary, player_pos: Vector2, frames: int) -> void:
	var effect_context: Dictionary = config.duplicate(true)
	effect_context["selected_character_type"] = "viper"
	effect_context["ball_active"] = true
	effect_context["player_pos"] = player_pos
	effect_context["player_paddle_size"] = Vector2(155.0, 50.0)
	for _i in range(frames):
		runtime.update_effects(1.0, Time.get_ticks_msec(), effect_context, deps)


func _make_runtime_bundle(four_poisons_level: int) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = four_poisons_level
	var deps := _deps(
		input,
		skill_config,
		skill_state,
		perk_state,
		FakeOrbHud.new(),
		FakeFeedback.new(),
		FakeAudio.new()
	)
	return {
		"runtime": runtime,
		"input": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"perk_state": perk_state,
		"deps": deps,
	}


func _deps(
	input: Object,
	skill_config: Object,
	skill_state: Object,
	perk_state: Object,
	orb: Object,
	feedback: Object,
	audio: Object
) -> Dictionary:
	return {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"runtime_perk_state": perk_state,
		"orb_hud_state": orb,
		"feedback": feedback,
		"audio": audio,
	}


func _base_config() -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_size": 28.6,
		"hitbox_padding": 5.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
