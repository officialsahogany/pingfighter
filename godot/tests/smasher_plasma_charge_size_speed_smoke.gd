extends SceneTree

# 플라즈마 투사체 크기 30% 확대 + 차징 비례 이동속도 감속(최대 60%)
# + 차징 비례 쿨타임(3~15초) 봉인.
# 실제 발사 경로(홀드 -> 릴리즈)를 태워 파동 반경 / 첫 프레임 전진 거리 / 쿨타임을 측정한다.

const SmasherPlasmaState := preload("res://scripts/characters/smasher_plasma_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

const PLAYER_POS := Vector2(300.0, 700.0)


func _init() -> void:
	_test_size_scaled_30_percent()
	_test_charge_proportional_slowdown()
	_test_max_charge_wave_reaches_top()
	_test_charge_scaled_cooldown()
	_test_charge_scaled_cooldown_multiplier_and_tooltip_range()
	_test_retired_cpu_particles_stay_empty()
	print("smasher_plasma_charge_size_speed_smoke: ok")
	quit(0)


func _fire_all(hold_frames: int, cooldown_multiplier: float = 1.0) -> Dictionary:
	var state: Object = SmasherPlasmaState.new()
	var skill_config: Object = SmasherSkillConfig.new()
	var skill_state: Object = SmasherSkillState.new()
	_expect(skill_config.unlock_and_equip_skill("plasma"), "plasma should equip")
	skill_config.set_runtime_cooldown_multiplier(cooldown_multiplier)
	var deps := {
		"skill_config": skill_config,
		"skill_state": skill_state,
	}
	var config := {
		"ball_active": true,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"gauge_max": 500.0,
	}
	var gauge := 500.0
	for i in range(hold_frames):
		var hold_result: Dictionary = state.update_input(
			{"up_pressed": true}, 1000 + i * 16, gauge, PLAYER_POS, config, deps
		)
		gauge = float(hold_result.get("special_gauge", gauge))
	state.update_input({"up_pressed": false}, 1000 + hold_frames * 16, gauge, PLAYER_POS, config, deps)
	return {"plasma": state, "skill_state": skill_state, "skill_config": skill_config}


func _fire_at_charge(hold_frames: int) -> Object:
	return _fire_all(hold_frames)["plasma"]


# 보스를 파동에서 멀리 둔 채 한 프레임 전진시켜 위쪽 이동 거리(px)를 잰다.
# 보스가 파동 안에 들어가면 별도 0.5배 감속이 끼어들어 측정이 오염되므로 멀리 둔다.
func _measure_first_frame_dy(state: Object) -> float:
	var before: Vector2 = state.get_draw_context().get("smasher_plasma_wave_pos", Vector2.ZERO)
	var context := {
		"current_stage": 1,
		"player_pos": PLAYER_POS,
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(20.0, 20.0),
		"boss_paddle_width": 40.0,
		"boss_hitbox_height": 20.0,
	}
	state.update_effects(1.0, context, {})
	var after: Vector2 = state.get_draw_context().get("smasher_plasma_wave_pos", Vector2.ZERO)
	_expect(not state.is_boss_slowed(), "boss must stay outside the wave so the dy measurement is clean")
	return before.y - after.y


func _test_size_scaled_30_percent() -> void:
	# 최대 차징: charge_size = 1.0 -> wave_radius = WAVE_MAX_RADIUS = 130 (구 100의 x1.3).
	var max_state: Object = _fire_at_charge(182)
	var max_ctx: Dictionary = max_state.get_draw_context()
	_expect(bool(max_ctx.get("smasher_plasma_wave_active", false)), "max-charge release should fire the wave")
	var max_radius: float = float(max_ctx.get("smasher_plasma_wave_radius", 0.0))
	_expect(is_equal_approx(max_radius, 130.0), "max-charge radius should be 30%% larger (100 -> 130)")

	# 최소 차징: charge_size = 30/180 -> wave_radius = 52 + 78 * (1/6) = 65 (구 50의 x1.3).
	var min_state: Object = _fire_at_charge(31)
	var min_radius: float = float(min_state.get_draw_context().get("smasher_plasma_wave_radius", 0.0))
	_expect(is_equal_approx(min_radius, 65.0), "min-charge radius should also scale 30%% (50 -> 65)")


func _test_charge_proportional_slowdown() -> void:
	# 최대 차징: 6.0 * (1 - 0.6 * 1.0) = 2.4 (지금보다 60% 감속).
	# dy는 Vector2(32비트 float) 성분 뺄셈이라 0.01px 엡실론으로 비교한다.
	var max_state: Object = _fire_at_charge(182)
	var dy_max: float = _measure_first_frame_dy(max_state)
	_expect(absf(dy_max - 2.4) < 0.01, "max-charge wave should move 60%% slower (6.0 -> 2.4)")

	# 최소 차징: 6.0 * (1 - 0.6 * (1/6)) = 6.0 * 0.9 = 5.4 (거의 원속).
	var min_state: Object = _fire_at_charge(31)
	var dy_min: float = _measure_first_frame_dy(min_state)
	_expect(absf(dy_min - 5.4) < 0.01, "min-charge wave should stay near full speed (~5.4)")

	_expect(dy_min > dy_max, "more charge (bigger projectile) must move slower")


# 감속으로 파동이 화면 중간에서 수명이 다해 사라지면 안 된다. 최대 차징(가장 느림)
# 에서도 상단까지 도달해 위치 조건으로 소멸해야 한다. 보스를 화면 위로 치워
# 접촉 감속이 측정에 끼어들지 않게 한다.
func _test_max_charge_wave_reaches_top() -> void:
	var state: Object = _fire_at_charge(182)
	var context := {
		"current_stage": 1,
		"player_pos": PLAYER_POS,
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(377.5, -520.0),
		"boss_paddle_width": 1.0,
		"boss_hitbox_height": 1.0,
	}
	var min_y := 9999.0
	var cleared := false
	for _i in range(1000):
		state.update_effects(1.0, context, {})
		var ctx: Dictionary = state.get_draw_context()
		var wave_pos: Vector2 = ctx.get("smasher_plasma_wave_pos", Vector2.ZERO)
		min_y = minf(min_y, wave_pos.y)
		if not bool(ctx.get("smasher_plasma_wave_active", false)):
			cleared = true
			break
	_expect(not state.is_boss_slowed(), "boss placed above the field must not slow the wave")
	_expect(cleared, "max-charge wave should eventually clear")
	# 상단 도달 시 wave_pos.y < -wave_radius(=-130)로 소멸. 중간 소멸이면 min_y는
	# 양수(약 248)로 남는다.
	_expect(min_y < -100.0, "max-charge wave must reach the top of the field, not vanish mid-screen")
	var fade_fx: Dictionary = state.get_plasma_fx_state()
	_expect(str(fade_fx.get("phase", "")) == "fade", "wave clear should hand off to a short fade phase")
	_expect(float(fade_fx.get("intensity", 0.0)) > 0.0, "wave fade should keep visible intensity for the release tail")


# 쿨타임도 차징에 비례: 발사가능 최소 차징 = 3초, 최대 차징 = 15초.
# get_cooldown_total_seconds()는 실제 트리거된 쿨타임 총길이(초)를 돌려준다.
func _test_charge_scaled_cooldown() -> void:
	var short_fire: Dictionary = _fire_all(31)
	var short_cd: float = float(short_fire["skill_state"].get_cooldown_total_seconds("plasma"))
	_expect(absf(short_cd - 3.0) < 0.05, "shortest charge should give ~3s cooldown")

	var long_fire: Dictionary = _fire_all(182)
	var long_cd: float = float(long_fire["skill_state"].get_cooldown_total_seconds("plasma"))
	_expect(absf(long_cd - 15.0) < 0.05, "max charge should give ~15s cooldown")

	# 중간 차징은 3~15초 사이의 중간값이어야 한다(단조 증가).
	var mid_fire: Dictionary = _fire_all(105)
	var mid_cd: float = float(mid_fire["skill_state"].get_cooldown_total_seconds("plasma"))
	_expect(mid_cd > short_cd and mid_cd < long_cd, "mid charge cooldown must sit between 3s and 15s")

	# 실제 쿨타임을 발동시켜야 한다(비율 > 0).
	_expect(short_fire["skill_state"].get_cooldown_remaining("plasma", 1000 + 31 * 16, 8.0) > 0.0, "firing should arm the plasma cooldown")


func _test_charge_scaled_cooldown_multiplier_and_tooltip_range() -> void:
	var half_fire: Dictionary = _fire_all(182, 0.5)
	var half_cd: float = float(half_fire["skill_state"].get_cooldown_total_seconds("plasma"))
	_expect(absf(half_cd - 7.5) < 0.05, "cooldown multiplier should scale max-charge cooldown (15s * 0.5)")

	var skill_config: Object = half_fire["skill_config"]
	var plasma_data: Dictionary = skill_config.get_skill_data("plasma")
	var range_value: Variant = plasma_data.get("cooldown_range", [])
	_expect(range_value is Array and (range_value as Array).size() == 2, "plasma tooltip data should expose a cooldown range")
	var cooldown_range: Array = range_value
	_expect(absf(float(cooldown_range[0]) - 1.5) < 0.01, "tooltip minimum cooldown range should include cooldown multiplier")
	_expect(absf(float(cooldown_range[1]) - 7.5) < 0.01, "tooltip maximum cooldown range should include cooldown multiplier")


# 은퇴한 절차 CPU 파티클(charge_particles/wave_trail/wave_particles)이 매 프레임
# 갱신되지 않고 항상 빈 배열인지 봉인 — FX 호스트(GPUParticles2D)가 오브 비주얼을
# 소유하므로 이 Dictionary 배열들의 spawn/update per-frame 비용은 은퇴했다.
func _test_retired_cpu_particles_stay_empty() -> void:
	var state := SmasherPlasmaState.new()
	var skill_config := SmasherSkillConfig.new()
	var skill_state := SmasherSkillState.new()
	_expect(skill_config.unlock_and_equip_skill("plasma"), "plasma should equip for retirement seal")
	var deps := {"skill_config": skill_config, "skill_state": skill_state}
	var config := {"ball_active": true, "paddle_width": 155.0, "paddle_height": 50.0, "gauge_max": 500.0}
	var gauge := 500.0
	for i in range(120):
		var r: Dictionary = state.update_input({"up_pressed": true}, 1000 + i * 16, gauge, PLAYER_POS, config, deps)
		gauge = float(r.get("special_gauge", gauge))
	_expect((state.get_draw_context().get("smasher_plasma_charge_particles", []) as Array).is_empty(), "charge_particles must stay empty every frame (retired CPU feed)")
	state.update_input({"up_pressed": false}, 1000 + 120 * 16, gauge, PLAYER_POS, config, deps)
	_expect(bool(state.get_draw_context().get("smasher_plasma_wave_active", false)), "release should fire the wave for the retirement seal")
	var ctx := {
		"current_stage": 1,
		"player_pos": PLAYER_POS,
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(20.0, 20.0),
		"boss_paddle_width": 40.0,
		"boss_hitbox_height": 20.0,
	}
	for _f in range(20):
		state.update_effects(1.0, ctx, deps)
	var dc: Dictionary = state.get_draw_context()
	_expect((dc.get("smasher_plasma_wave_trail", []) as Array).is_empty(), "wave_trail must stay empty every frame (retired CPU feed)")
	_expect((dc.get("smasher_plasma_wave_particles", []) as Array).is_empty(), "wave_particles must stay empty every frame (retired CPU feed)")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
