extends SceneTree

## 오딘의 눈 잔상(afterimage) + 대쉬 다이브 포팅 씰.
##
## Python parity oracle: legendary_items.py 6792-7791 (afterimage + dash dive
## systems) and pingfighter.py:205120-205165 (legendary-manager frame block:
## update → dive → movement spawn → descending-ball reflection with last-hit /
## rally / +50 gauge / odinshadow.wav side effects).

const OdinsEyeAfterimageState := preload("res://scripts/items/odins_eye_afterimage_state.gd")
const OdinsEyePresentationRenderer := preload("res://scripts/items/odins_eye_presentation_renderer.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"active_item_slots": [],
		"special_gauge": 150.0,
		"special_gauge_max": 500.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_pos": Vector2(380.0, 200.0),
		"ball_vel": Vector2(0.0, -6.0),
		"ball_active": true,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true

	func request_battle_redraw() -> void:
		values["redraw_requests"] = int(values.get("redraw_requests", 0)) + 1


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {"mouse_left_just_pressed": false}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeAudio:
	extends RefCounted

	var spirit_calls := 0
	var shadow_calls := 0
	var attack_calls := 0

	func play_odins_eye_spirit() -> void:
		spirit_calls += 1

	func play_odins_eye_shadow() -> void:
		shadow_calls += 1

	func play_odins_eye_attack() -> void:
		attack_calls += 1


class FakeFeedback:
	extends RefCounted

	var gauge_flash_calls := 0
	var update_calls := 0
	var fixed_pushes: Array = []

	func trigger_gauge_flash() -> void:
		gauge_flash_calls += 1

	func update(_delta: float, _dash_token_max: int) -> void:
		update_calls += 1

	func push_fixed_shake_offset(offset: Vector2) -> void:
		fixed_pushes.append(offset)


class FakeDashState:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active


class FakeBallIntensity:
	extends RefCounted

	var contacts: Array = []

	func register_contact(actor_id: String, side: String, tags: Dictionary = {}) -> void:
		contacts.append({"actor": actor_id, "side": side, "tags": tags})


class FakePauseGate:
	extends RefCounted

	var paused := false

	func should_pause_game(_runtime: Object) -> bool:
		return paused


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_movement_spawn_cadence()
	_verify_afterimage_lifecycle()
	_verify_ball_reflection_geometry()
	_verify_reflection_gating()
	_verify_reflection_speed_bounds()
	_verify_dive_phase_machine()
	_verify_redash_restarts_sink()
	_verify_anim_cancel_and_clear()
	_verify_dive_visual_plan_flow()
	_verify_overlay_active_predicate()
	_verify_ambient_particles()
	_verify_eldritch_body_polygon_triangulable()
	_verify_spin_resolution()
	_verify_rune_glyph_structure()
	_verify_runtime_integration_spawn_reflect_gauge()
	_verify_runtime_integration_dive_and_cleanup()
	_verify_pause_gate_freezes_afterimage_tick()
	_verify_real_driver_fanout_spawns_afterimages()
	_verify_character_input_reader_authority()
	_verify_victory_death_transitions_clear_afterimages()
	_verify_cinematic_shake_reaches_feedback()

	if _failures.is_empty():
		print("odins_eye_afterimage_dive_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _make_state() -> Object:
	var state: Object = OdinsEyeAfterimageState.new()
	state.set_random_seed(20260711)
	return state


func _tick(state: Object, params: Dictionary, frames: int = 1) -> void:
	for _frame in range(frames):
		state.update(1.0 / 60.0, params)


# ---------------------------------------------------------------- unit legs

func _verify_movement_spawn_cadence() -> void:
	var state: Object = _make_state()
	# 12px/frame movement: spawns on frames 1, 7, 13 (6-frame interval,
	# legendary_items.py:6797) — 3 afterimages after 13 frames.
	var center := Vector2(300.0, 730.0)
	for frame in range(13):
		_tick(state, {
			"player_center": center,
			"paddle_width": 155.0,
			"paddle_height": 50.0,
			"moving": true,
			"dash_active": false,
			"anim_blocked": false,
		})
		center.x += 12.0
	_expect(state.afterimages.size() == 3, "12px/frame 이동 13프레임 → 잔상 3개 (6프레임 간격), got %d" % state.afterimages.size())

	# Stationary hold: the 10px min-move gate blocks further spawns even with
	# movement intent held (legendary_items.py:7336-7340). Hold AT the last
	# spawn anchor so the residual distance is truly under 10px.
	var before: int = state.afterimages.size()
	var hold_center: Vector2 = state.last_afterimage_pos
	_tick(state, {
		"player_center": hold_center,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"moving": true,
		"dash_active": false,
		"anim_blocked": false,
	}, 12)
	_expect(
		state.afterimages.size() <= before,
		"정지 상태(10px 미만 이동)에서는 이동키 홀드 중에도 잔상이 늘지 않아야 함"
	)

	# No movement intent: no spawns at all.
	var idle_state: Object = _make_state()
	_tick(idle_state, {
		"player_center": Vector2(300.0, 730.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"moving": false,
		"dash_active": false,
		"anim_blocked": false,
	}, 20)
	_expect(idle_state.afterimages.is_empty(), "이동 의사 없음 → 잔상 스폰 없음")


func _verify_afterimage_lifecycle() -> void:
	var state: Object = _make_state()
	state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	_expect(state.afterimages.size() == 1, "create_afterimage 직접 호출 → 1개")
	var idle := {
		"player_center": Vector2(400.0, 730.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"moving": false,
		"dash_active": false,
		"anim_blocked": false,
	}
	_tick(state, idle, 59)
	_expect(str(state.afterimages[0]["phase"]) == "hold", "59프레임까지 hold 유지 (60f 홀드)")
	_tick(state, idle, 1)
	_expect(str(state.afterimages[0]["phase"]) == "fade", "60프레임에 fade 전환")
	_tick(state, idle, 15)
	var mid_alpha: float = float(state.afterimages[0]["alpha"])
	_expect(absf(mid_alpha - 100.0) < 8.0, "fade 중간(75f) 알파 ≈ 100/255, got %.1f" % mid_alpha)
	_tick(state, idle, 20)
	_expect(state.afterimages.is_empty(), "90프레임(60 hold + 30 fade) 이후 잔상 제거")


func _verify_ball_reflection_geometry() -> void:
	var state: Object = _make_state()
	state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	# Hitbox: x [322.5, 477.5], y [670, 720] (anchor-60, height 50 —
	# legendary_items.py:7701-7705). Ball right of center → rightward-upward
	# reflection with ±60° paddle-style angle mapping.
	var result: Dictionary = state.check_ball_collision(Vector2(420.0, 700.0), 14.3, Vector2(2.0, 6.0))
	_expect(bool(result.get("hit", false)), "히트박스 내부 하강 공 → 반사")
	var new_vel: Vector2 = result.get("new_velocity", Vector2.ZERO)
	_expect(new_vel.y < 0.0, "하강 공 반사는 위로 (vy<0), got %.2f" % new_vel.y)
	_expect(new_vel.x > 1.5 and new_vel.x < 2.0, "중심 우측 히트 → 우상향 각도 (vx∈[1.5,2.0]), got %.2f" % new_vel.x)
	var speed: float = new_vel.length()
	_expect(
		speed >= 6.32 - 0.01 and speed <= 6.325 * 1.1 + 0.01,
		"반사 속도 = 원속도 6.32 × 부스트[1.0,1.1], got %.3f" % speed
	)
	_expect(str(state.afterimages[0]["phase"]) == "hit", "반사된 잔상은 hit(영혼 이탈) 페이즈 진입")
	_expect(
		absf(float(state.afterimage_hit_cooldown_frames) - 55.0) < 0.01,
		"히트 쿨다운 45+10 프레임, got %.1f" % float(state.afterimage_hit_cooldown_frames)
	)
	_expect(state.soul_particles.size() == 15, "히트 시 영혼 파티클 15개 버스트, got %d" % state.soul_particles.size())

	# Outside the hitbox: no reflection.
	var miss_state: Object = _make_state()
	miss_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	var miss: Dictionary = miss_state.check_ball_collision(Vector2(400.0, 640.0), 14.3, Vector2(0.0, 6.0))
	_expect(not bool(miss.get("hit", false)), "히트박스 상단 밖(y=640) → 미스")


func _verify_reflection_gating() -> void:
	var state: Object = _make_state()
	state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	var first: Dictionary = state.check_ball_collision(Vector2(400.0, 700.0), 14.3, Vector2(0.0, 6.0))
	_expect(bool(first.get("hit", false)), "게이팅 전제: 첫 반사 성공")
	# Fresh overlapping afterimage while the hit cooldown runs → miss.
	state.create_afterimage(Vector2(430.0, 730.0), 155.0, 50.0)
	var during_cooldown: Dictionary = state.check_ball_collision(Vector2(430.0, 700.0), 14.3, Vector2(0.0, 6.0))
	_expect(not bool(during_cooldown.get("hit", false)), "히트 쿨다운 중에는 다른 잔상도 반사 불가")
	# Cooldown forced to zero but a hit-phase afterimage still lives → miss
	# (one soul-escape at a time, legendary_items.py:7687-7690).
	state.afterimage_hit_cooldown_frames = 0.0
	var during_hit_phase: Dictionary = state.check_ball_collision(Vector2(430.0, 700.0), 14.3, Vector2(0.0, 6.0))
	_expect(not bool(during_hit_phase.get("hit", false)), "hit 페이즈 잔상이 살아있는 동안 추가 히트 금지")


func _verify_reflection_speed_bounds() -> void:
	# Cap: a 20px/f ball clamps to 14 (legendary_items.py:7733).
	var fast_state: Object = _make_state()
	fast_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	var fast: Dictionary = fast_state.check_ball_collision(Vector2(400.0, 700.0), 14.3, Vector2(0.0, 20.0))
	_expect(bool(fast.get("hit", false)), "고속 공 반사 성공 전제")
	var fast_speed: float = (fast.get("new_velocity", Vector2.ZERO) as Vector2).length()
	_expect(absf(fast_speed - 14.0) < 0.01, "고속 공 반사 속도는 14.0 캡, got %.3f" % fast_speed)

	# Floor: a 1.1px/f ball reflects from the 4.0 minimum (legendary 7720-7721).
	var slow_state: Object = _make_state()
	slow_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	var slow: Dictionary = slow_state.check_ball_collision(Vector2(400.0, 700.0), 14.3, Vector2(0.5, 1.0))
	_expect(bool(slow.get("hit", false)), "저속 공 반사 성공 전제")
	var slow_speed: float = (slow.get("new_velocity", Vector2.ZERO) as Vector2).length()
	_expect(
		slow_speed >= 4.0 - 0.01 and slow_speed <= 4.4 + 0.01,
		"저속 공 반사 속도 = 최저 4.0 × 부스트[1.0,1.1], got %.3f" % slow_speed
	)


func _verify_dive_phase_machine() -> void:
	var state: Object = _make_state()
	var params := {
		"player_center": Vector2(400.0, 725.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"moving": false,
		"dash_active": true,
		"anim_blocked": false,
	}
	# Dash rising edge → sink starts (edge tick leaves sink_timer at 1).
	_tick(state, params)
	_expect(state.dive_active and state.dive_sink_phase, "대쉬 에지 → 다이브 sink 시작")
	_expect(state.dive_ground_cracks.size() == 5, "sink 시작 균열 5개, got %d" % state.dive_ground_cracks.size())
	_expect(state.dive_ground_ripples.size() == 1, "sink 시작 파문 1개")
	_expect(state.dive_burst_particles.size() == 12, "sink 하강 파티클 12개, got %d" % state.dive_burst_particles.size())
	_tick(state, params)
	# sink_timer = 2: p=0.25, ease=0.0625 → offset 7.5, not yet hidden (<4).
	var early: Dictionary = state.get_dive_visual_params()
	_expect(absf(float(early.get("offset_y", 0.0)) - 7.5) < 0.01, "sink 2f 오프셋 = 120·(2/8)² = 7.5, got %.2f" % float(early.get("offset_y", -1.0)))
	_expect(bool(early.get("visible", false)), "sink 초반 가시")
	_expect(not state.should_hide_player_for_dive(), "sink 2f(<4)에는 아직 숨김 아님")
	_tick(state, params, 3)
	# sink_timer = 5 ≥ 4 → hidden from the 50% point.
	_expect(state.should_hide_player_for_dive(), "sink 50%(4f) 이후 패들 숨김")
	_tick(state, params, 3)
	# sink_timer reached 8 → underground.
	_expect(state.dive_underground_phase, "sink 8프레임 완료 → 지하 이동")
	var underground: Dictionary = state.get_dive_visual_params()
	_expect(not bool(underground.get("visible", true)), "지하 이동 중 비가시")
	_expect(absf(float(underground.get("offset_y", 0.0)) - 120.0) < 0.01, "지하 오프셋 120")

	# 6 underground frames with the dash live: trail + path afterimages every
	# 2 frames (155x25 fixed size — legendary_items.py:7009-7020).
	_tick(state, params, 6)
	_expect(state.dive_trail.size() == 3, "지하 6프레임 → 트레일 3개(2프레임 간격), got %d" % state.dive_trail.size())
	_expect(state.afterimages.size() == 3, "지하 경로 잔상 3개, got %d" % state.afterimages.size())
	if not state.afterimages.is_empty():
		_expect(
			absf(float(state.afterimages[0]["width"]) - 155.0) < 0.01
			and absf(float(state.afterimages[0]["height"]) - 25.0) < 0.01,
			"지하 잔상 크기 155x25 고정"
		)

	# Dash ends → emerge with the richer burst (8 cracks / 18 particles up).
	var cracks_before: int = state.dive_ground_cracks.size()
	params["dash_active"] = false
	_tick(state, params)
	_expect(state.dive_emerge_phase, "대쉬 종료 → 솟아오르기")
	_expect(
		state.dive_ground_cracks.size() == cracks_before + 8,
		"솟아오르기 균열 +8, got %d→%d" % [cracks_before, state.dive_ground_cracks.size()]
	)
	_tick(state, params)
	# emerge_timer = 1 (<3) → still hidden below ground.
	_expect(state.should_hide_player_for_dive(), "솟아오르기 초반 25%(3f 미만) 숨김")
	var rising: Dictionary = state.get_dive_visual_params()
	_expect(bool(rising.get("visible", false)), "솟아오르기 params.visible = true")
	var rise_offset: float = float(rising.get("offset_y", 0.0))
	_expect(absf(rise_offset - 100.83) < 0.5, "emerge 1f 오프셋 ≈ 120·(11/12)² = 100.83, got %.2f" % rise_offset)
	_tick(state, params, 2)
	_expect(not state.should_hide_player_for_dive(), "emerge 3f부터 노출")
	_tick(state, params, 9)
	_expect(not state.dive_active, "emerge 12프레임 완료 → 다이브 종료")


func _verify_redash_restarts_sink() -> void:
	var state: Object = _make_state()
	var params := {
		"player_center": Vector2(400.0, 725.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"moving": false,
		"dash_active": true,
		"anim_blocked": false,
	}
	_tick(state, params, 9)
	params["dash_active"] = false
	_tick(state, params, 2)
	_expect(state.dive_emerge_phase, "재대쉬 전제: emerge 진행 중")
	# Consecutive dash: the new dash cancels the emerge and restarts the sink
	# (legendary_items.py:6954-6963).
	params["dash_active"] = true
	_tick(state, params)
	_expect(
		state.dive_active and state.dive_sink_phase and not state.dive_emerge_phase,
		"연속 대쉬 → emerge 취소 + sink 재시작"
	)
	_expect(float(state.dive_sink_timer_frames) <= 1.01, "재시작된 sink 타이머는 처음부터")


func _verify_anim_cancel_and_clear() -> void:
	var state: Object = _make_state()
	var params := {
		"player_center": Vector2(400.0, 725.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"moving": false,
		"dash_active": true,
		"anim_blocked": false,
	}
	_tick(state, params, 10)
	_expect(state.dive_active, "취소 전제: 다이브 진행 중")
	# Death / revival cinematic cancels the dive outright
	# (legendary_items.py:6982-6985).
	params["anim_blocked"] = true
	_tick(state, params)
	_expect(not state.dive_active, "부활/사망 연출 → 다이브 즉시 취소")
	_expect(
		state.dive_trail.is_empty() and state.dive_ground_cracks.is_empty()
		and state.dive_ground_ripples.is_empty() and state.dive_burst_particles.is_empty(),
		"취소 시 다이브 이펙트 전부 소거"
	)

	# clear_all: everything including cooldowns and the dash edge tracker.
	var full_state: Object = _make_state()
	full_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	full_state.check_ball_collision(Vector2(400.0, 700.0), 14.3, Vector2(0.0, 6.0))
	full_state.start_dash_dive(Vector2(400.0, 725.0))
	full_state.clear_all()
	_expect(
		full_state.afterimages.is_empty() and full_state.soul_particles.is_empty()
		and not full_state.dive_active and full_state.dive_ground_cracks.is_empty()
		and float(full_state.afterimage_hit_cooldown_frames) == 0.0,
		"clear_all → 잔상/영혼/다이브/쿨다운 전부 초기화"
	)


func _verify_dive_visual_plan_flow() -> void:
	var renderer: Object = OdinsEyePresentationRenderer.new()
	var underground_context := {
		"odins_eye_context": {
			"transformed": true,
			"penalty_active": true,
			"afterimage": {
				"dive_active": true,
				"dive_visual": {"active": true, "offset_y": 120.0, "alpha": 0.0, "visible": false},
			},
		},
	}
	var plan: Dictionary = renderer.build_presentation_plan(underground_context, Vector2(300.0, 700.0), Vector2(155.0, 50.0))
	_expect(not bool(plan.get("dive_visible", true)), "지하 이동 플랜 → dive_visible=false (드로우 스킵)")
	_expect(absf(float(plan.get("dive_offset_y", 0.0)) - 120.0) < 0.01, "플랜에 다이브 오프셋 관통")

	var plain_plan: Dictionary = renderer.build_presentation_plan({
		"odins_eye_context": {"transformed": true, "penalty_active": true},
	}, Vector2(300.0, 700.0), Vector2(155.0, 50.0))
	_expect(bool(plain_plan.get("dive_visible", false)), "다이브 컨텍스트 없음 → 기본 가시")
	_expect(absf(float(plain_plan.get("dive_alpha", 0.0)) - 1.0) < 0.01, "다이브 없음 → 알파 1.0")


func _verify_overlay_active_predicate() -> void:
	var actor_renderer: Object = Stage1PlayerActorRenderer.new()
	_expect(
		bool(actor_renderer._is_odins_eye_overlay_active({
			"transformed": true,
			"afterimage": {"afterimages": [{"x": 1.0}], "dive_active": false},
		})),
		"잔상 payload 존재 → 오버레이 호스트 활성"
	)
	_expect(
		bool(actor_renderer._is_odins_eye_overlay_active({
			"transformed": true,
			"afterimage": {"dive_active": true},
		})),
		"다이브 활성 → 오버레이 호스트 활성"
	)
	_expect(
		not bool(actor_renderer._is_odins_eye_overlay_active({
			"transformed": true,
			"afterimage": {"afterimages": [], "dive_active": false},
		})),
		"빈 잔상 payload → 호스트 비활성 유지"
	)


func _verify_ambient_particles() -> void:
	# 상시 어둠 입자 (legendary_items.py:10168-10196): ≤14 cap, upward drift,
	# life expiry, revival spawn pause.
	var state: Object = _make_state()
	var idle := {
		"player_center": Vector2(400.0, 725.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"moving": false,
		"dash_active": false,
		"anim_blocked": false,
		"revival_active": false,
	}
	_tick(state, idle, 100)
	_expect(
		state.ambient_particles.size() > 0 and state.ambient_particles.size() <= 14,
		"상시 입자는 스폰되되 14개 상한, got %d" % state.ambient_particles.size()
	)
	var all_rising := true
	for particle in state.ambient_particles:
		if float(particle["vy"]) >= 0.0:
			all_rising = false
	_expect(all_rising, "상시 입자는 전부 위로 상승 (vy<0)")

	# Life expiry keeps the pool churning: a marked particle disappears.
	var oldest_life: float = 999.0
	for particle in state.ambient_particles:
		oldest_life = minf(oldest_life, float(particle["life"]))
	_tick(state, idle, int(oldest_life) + 1)
	var min_life_after: float = 999.0
	for particle in state.ambient_particles:
		min_life_after = minf(min_life_after, float(particle["life"]))
	_expect(min_life_after > 0.0, "수명이 다한 입자는 제거됨 (life>0만 생존)")

	# Revival cinematic pauses SPAWNS but existing motes keep aging
	# (the legacy spawn site early-returns during revival only).
	var revival := idle.duplicate()
	revival["revival_active"] = true
	revival["anim_blocked"] = true
	_tick(state, revival, 70)
	_expect(
		state.ambient_particles.is_empty(),
		"부활 연출 70프레임: 신규 스폰 없이 기존 입자 전부 소멸, got %d" % state.ambient_particles.size()
	)

	state.clear_all()
	_tick(state, idle, 5)
	_expect(state.ambient_particles.size() > 0, "부활 종료 후 스폰 재개")
	state.clear_all()
	_expect(state.ambient_particles.is_empty(), "clear_all → 상시 입자 소거")


func _verify_eldritch_body_polygon_triangulable() -> void:
	# The 24-step organic silhouette must stay triangulable across animation
	# phases, lean, death displace, and dark-swamp spin compression (the
	# animated draw_colored_polygon trap).
	var renderer: Object = OdinsEyePresentationRenderer.new()
	var origin := Vector2(377.5, 640.0)
	var checked := 0
	for t in [0.0, 0.7, 1.3, 2.9, 5.11]:
		for lean_px in [0.0, 2.56, -2.56]:
			for displace in [0.0, 10.0]:
				for spin in [1.0, 0.4, -0.8]:
					var points: PackedVector2Array = renderer._build_eldritch_body_points(
						origin, 1.0, spin, t, lean_px, displace
					)
					checked += 1
					if points.size() != 50:
						_failures.append("몸통 폴리곤 점 수 50 기대, got %d" % points.size())
						return
					if Geometry2D.triangulate_polygon(points).is_empty():
						_failures.append(
							"몸통 폴리곤 삼각분할 실패 (t=%.2f lean=%.2f displace=%.1f spin=%.2f)"
							% [t, lean_px, displace, spin]
						)
						return
	_expect(checked == 90, "삼각분할 커버리지 90케이스 전수 확인")


func _verify_spin_resolution() -> void:
	var renderer: Object = OdinsEyePresentationRenderer.new()
	var plain := {"odins_eye_context": {"transformed": true, "penalty_active": true}}
	_expect(
		absf(float(renderer._resolve_spin(plain, 1.23)) - 1.0) < 0.0001,
		"늪 비활성 → 스핀 없음 (1.0)"
	)
	var spinning := {
		"odins_eye_context": {
			"transformed": true,
			"penalty_active": true,
			"dark_swamp": {"active": true, "spikes": [], "fragments": []},
		},
	}
	# spin = cos(time*0.8*20): time = π/32 → cos(π/2) = 0 → edge-on silhouette.
	var edge_spin: float = float(renderer._resolve_spin(spinning, PI / 32.0))
	_expect(absf(edge_spin) < 0.05, "늪 발동 중 cos(π/2) 시점 → 옆면 실루엣 임계(|spin|<0.05), got %.4f" % edge_spin)
	_expect(
		absf(float(renderer._resolve_spin(spinning, 0.0)) - 1.0) < 0.0001,
		"늪 발동 t=0 → cos(0)=1 (정면 프레임)"
	)
	# Spikes alive without the active flag also spin (legacy `or lurker_spikes`).
	var spikes_only := {
		"odins_eye_context": {
			"transformed": true,
			"penalty_active": true,
			"dark_swamp": {"active": false, "spikes": [{"x": 1.0}], "fragments": []},
		},
	}
	var spike_spin: float = float(renderer._resolve_spin(spikes_only, PI / 32.0))
	_expect(absf(spike_spin) < 0.05, "가시 잔존 중에도 스핀 유지")


func _verify_rune_glyph_structure() -> void:
	# The rune stroke loop consumes point PAIRS — an odd-length glyph would
	# silently drop its last stroke.
	var glyphs: Array = OdinsEyePresentationRenderer.ELDRITCH_RUNE_GLYPHS
	_expect(glyphs.size() == 8, "룬 글리프 8종 (엘더 푸타르크 순환 인덱스와 일치)")
	for glyph_index in range(glyphs.size()):
		var glyph: Array = glyphs[glyph_index]
		if glyph.size() < 4 or glyph.size() % 2 != 0:
			_failures.append("룬 글리프 %d: 선분 쌍이 아님 (size %d)" % [glyph_index, glyph.size()])


# ---------------------------------------------------- real-path integration

func _build_transformed_fixture(input_reader: Object, extra_instances: Dictionary = {}) -> Dictionary:
	var owner := FakeOwner.new()
	var instances := {
		"smasher_input_reader": input_reader,
		"game_audio": FakeAudio.new(),
		"battle_feedback_state": FakeFeedback.new(),
		"smasher_dash_state": FakeDashState.new(),
		"ball_intensity": FakeBallIntensity.new(),
	}
	for key in extra_instances:
		instances[key] = extra_instances[key]
	var registry := FakeRegistry.new(instances)
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"fixture: 오딘의 눈 장착"
	)
	_expect(runtime.try_trigger_odins_eye_revival("round", 0.0), "fixture: 부활 트리거")
	runtime.odins_eye_runtime.update_runtime(runtime, 231.0, owner, registry)
	_expect(runtime.consume_odins_eye_revival_finalize_ready(), "fixture: 부활 피날레 엣지 소비")
	_expect(runtime.odins_eye_afterimage_state != null, "fixture: 잔상 상태 헬퍼 초기화됨")
	if runtime.odins_eye_afterimage_state != null:
		runtime.odins_eye_afterimage_state.set_random_seed(20260711)
		# The 231-frame revival window ticks the afterimage system too; start
		# the integration legs from a clean slate.
		runtime.odins_eye_afterimage_state.clear_all()
	return {"owner": owner, "registry": registry, "runtime": runtime}


func _verify_runtime_integration_spawn_reflect_gauge() -> void:
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {"mouse_left_just_pressed": false, "left_pressed": true, "right_pressed": false}
	var fixture: Dictionary = _build_transformed_fixture(input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]
	var afterimage_state: Object = runtime.odins_eye_afterimage_state

	# Ball parked ascending far away: the movement legs must not reflect.
	owner.set("ball_pos", Vector2(380.0, 150.0))
	owner.set("ball_vel", Vector2(0.0, -6.0))
	# 13 frames of real update_runtime with movement intent + position delta.
	for _frame in range(13):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		var pos: Vector2 = owner.get("player_pos")
		owner.set("player_pos", pos + Vector2(-12.0, 0.0))
	_expect(
		afterimage_state.afterimages.size() == 3,
		"실경로 13프레임 이동 → 잔상 3개, got %d" % afterimage_state.afterimages.size()
	)

	# Descending ball overlapping the newest afterimage → reflection with
	# last-hit/rally credit, +50 gauge, and the odinshadow one-shot.
	var anchor := Vector2(
		float(afterimage_state.afterimages[0]["x"]),
		float(afterimage_state.afterimages[0]["y"])
	)
	owner.set("ball_pos", anchor + Vector2(10.0, -35.0))
	owner.set("ball_vel", Vector2(1.0, 7.0))
	var audio: Object = registry.get_instance("game_audio")
	var shadow_calls_before: int = audio.shadow_calls
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	var reflected_vel: Vector2 = owner.get("ball_vel")
	_expect(reflected_vel.y < 0.0, "실경로 반사: ball_vel 위로 반전, got %.2f" % reflected_vel.y)
	var ball_intensity: Object = registry.get_instance("ball_intensity")
	_expect(ball_intensity.contacts.size() == 1, "실경로 반사: register_contact 1회")
	if not ball_intensity.contacts.is_empty():
		_expect(
			str(ball_intensity.contacts[0]["side"]) == "player"
			and str(ball_intensity.contacts[0]["actor"]) == "odin_afterimage",
			"반사 크레딧 = player / odin_afterimage"
		)
	_expect_close(float(owner.get("special_gauge")), 200.0, "잔상 반사 게이지 +50 (150→200)")
	_expect(audio.shadow_calls == shadow_calls_before + 1, "잔상 반사 시 odinshadow 사운드 1회")

	# Ascending ball never consults the afterimages (pingfighter.py:205138).
	afterimage_state.afterimage_hit_cooldown_frames = 0.0
	for afterimage in afterimage_state.afterimages:
		afterimage["phase"] = "hold"
	owner.set("ball_pos", anchor + Vector2(10.0, -35.0))
	owner.set("ball_vel", Vector2(1.0, -7.0))
	var contacts_before: int = ball_intensity.contacts.size()
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		ball_intensity.contacts.size() == contacts_before,
		"상승 공(보스로 향함)은 잔상 반사 대상이 아님"
	)
	var ascending_vel: Vector2 = owner.get("ball_vel")
	_expect(ascending_vel.y < 0.0, "상승 공 속도 유지")

	# Gauge cap: near-max gauge clamps at special_gauge_max.
	afterimage_state.afterimage_hit_cooldown_frames = 0.0
	owner.set("special_gauge", 480.0)
	owner.set("ball_pos", anchor + Vector2(10.0, -35.0))
	owner.set("ball_vel", Vector2(1.0, 7.0))
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(float(owner.get("special_gauge")), 500.0, "게이지 상한 500 캡")


func _verify_runtime_integration_dive_and_cleanup() -> void:
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {"mouse_left_just_pressed": false, "left_pressed": false, "right_pressed": false}
	var fixture: Dictionary = _build_transformed_fixture(input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]
	var afterimage_state: Object = runtime.odins_eye_afterimage_state
	var dash_state: Object = registry.get_instance("smasher_dash_state")

	owner.set("ball_pos", Vector2(380.0, 150.0))
	owner.set("ball_vel", Vector2(0.0, -6.0))
	dash_state.active = true
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(afterimage_state.dive_active, "실경로: 공유 대쉬 상태 에지 → 다이브 시작")
	for _frame in range(9):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(afterimage_state.dive_underground_phase, "실경로: sink 완료 → 지하 이동")
	var context: Dictionary = runtime.get_odins_eye_context()
	var afterimage_context: Dictionary = context.get("afterimage", {})
	_expect(bool(afterimage_context.get("dive_active", false)), "get_context에 다이브 상태 관통")
	var ambient: Variant = afterimage_context.get("ambient_particles", [])
	_expect(
		ambient is Array and not (ambient as Array).is_empty(),
		"실경로 변신 틱 → 상시 입자 컨텍스트 관통"
	)
	_expect(
		not bool((afterimage_context.get("dive_visual", {}) as Dictionary).get("visible", true)),
		"get_context 다이브 비주얼 = 지하 비가시"
	)
	dash_state.active = false
	for _frame in range(14):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(not afterimage_state.dive_active, "실경로: 대쉬 종료 → emerge 완주 → 다이브 종료")

	# Round reset clears afterimages + dive residuals (Python parity:
	# go_to_next_round :182122 + reset_for_new_round :6922).
	afterimage_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	runtime.odins_eye_runtime.reset_round(runtime)
	_expect(
		afterimage_state.afterimages.is_empty() and afterimage_state.dive_trail.is_empty(),
		"reset_round → 잔상/다이브 잔여물 소거"
	)

	# Unequip transition also clears (sync_equipment_state path).
	afterimage_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	runtime.odins_eye_runtime.clear_on_unequip(runtime)
	_expect(afterimage_state.afterimages.is_empty(), "clear_on_unequip → 잔상 소거")


func _verify_pause_gate_freezes_afterimage_tick() -> void:
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {"mouse_left_just_pressed": false, "left_pressed": true, "right_pressed": false}
	var pause_gate := FakePauseGate.new()
	var fixture: Dictionary = _build_transformed_fixture(input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]
	runtime.pause_gate = pause_gate
	var afterimage_state: Object = runtime.odins_eye_afterimage_state
	owner.set("ball_pos", Vector2(380.0, 150.0))
	owner.set("ball_vel", Vector2(0.0, -6.0))
	pause_gate.paused = true
	for _frame in range(12):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		var pos: Vector2 = owner.get("player_pos")
		owner.set("player_pos", pos + Vector2(-12.0, 0.0))
	_expect(
		afterimage_state.afterimages.is_empty(),
		"신화 모달 pause 중에는 잔상 시스템 동결 (스폰 없음)"
	)
	pause_gate.paused = false
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		afterimage_state.afterimages.size() == 1,
		"pause 해제 후 첫 프레임부터 스폰 재개, got %d" % afterimage_state.afterimages.size()
	)


# [P1 실배선 씰] helper 직접 호출이 아니라 프로덕션 진입점
# BattleSceneItemUpdateDriver.update_mythic_items()를 관통시킨다 — 실제
# 오너 체인(driver → mythic_item_runtime.update → update_gate →
# mythic_item_update_runtime → odins update_runtime 4인자)이 owner/registry를
# 전달하지 않으면(또는 has_runtime_update_work가 변신 상태를 게이트에서
# 빠뜨리면) 이 레그의 잔상 스폰이 0이 된다.
func _verify_real_driver_fanout_spawns_afterimages() -> void:
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {"mouse_left_just_pressed": false, "left_pressed": true, "right_pressed": false}
	var fixture: Dictionary = _build_transformed_fixture(input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]
	registry.instances["mythic_item_runtime"] = runtime
	var afterimage_state: Object = runtime.odins_eye_afterimage_state
	owner.set("ball_pos", Vector2(380.0, 150.0))
	owner.set("ball_vel", Vector2(0.0, -6.0))
	# 부활 연출은 이미 종료(finalize 소비됨) — 시네마틱 플래그만 보는 게이트는
	# 여기서 닫혀 잔상 실경로가 죽는다.
	_expect(
		runtime.odins_eye_runtime.has_runtime_update_work(runtime),
		"부활 finalize 이후에도 변신 유지 중에는 has_runtime_update_work=true"
	)
	# 스모크의 _init에서는 물리 프레임이 흐르지 않아 드라이버의 프레임 dedup이
	# 두 번째 호출을 삼킨다 — 프레임마다 새 드라이버 인스턴스로 같은 프로덕션
	# 코드 경로를 관통시킨다.
	for _frame in range(13):
		var driver: Object = BattleSceneItemUpdateDriver.new()
		driver.update_mythic_items(owner, registry, 1.0 / 60.0)
		var pos: Vector2 = owner.get("player_pos")
		owner.set("player_pos", pos + Vector2(-12.0, 0.0))
	_expect(
		afterimage_state.afterimages.size() == 3,
		"실 드라이버 update_mythic_items 13프레임 → 잔상 3개, got %d" % afterimage_state.afterimages.size()
	)


# [P1 캐릭터 권위 씰] 잔상 이동 intent는 선택 캐릭터의 입력 리더 키에서
# 읽어야 한다 — 스매셔 키 고정이면 Viper/Commando/Blacksmith 변신에서 이동
# 잔상이 영구 불발된다. 부정 레그: 선택 캐릭터의 리더가 레지스트리에 없으면
# (스매셔 리더에 intent가 있어도) 스폰되지 않아야 키 라우팅이 증명된다.
func _verify_character_input_reader_authority() -> void:
	var reader_keys := {
		"viper": "viper_input_reader",
		"soldier": "commando_input_reader",
		"blacksmith": "blacksmith_input_reader",
	}
	for character_type in reader_keys:
		var idle_smasher := FakeInputReader.new()
		idle_smasher.snapshot = {"mouse_left_just_pressed": false, "left_pressed": false, "right_pressed": false}
		var character_reader := FakeInputReader.new()
		character_reader.snapshot = {"mouse_left_just_pressed": false, "left_pressed": true, "right_pressed": false}
		var fixture: Dictionary = _build_transformed_fixture(
			idle_smasher,
			{str(reader_keys[character_type]): character_reader}
		)
		var owner: Object = fixture["owner"]
		var registry: Object = fixture["registry"]
		var runtime: Object = fixture["runtime"]
		owner.set("selected_character_type", character_type)
		owner.set("ball_pos", Vector2(380.0, 150.0))
		owner.set("ball_vel", Vector2(0.0, -6.0))
		var afterimage_state: Object = runtime.odins_eye_afterimage_state
		for _frame in range(13):
			runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
			var pos: Vector2 = owner.get("player_pos")
			owner.set("player_pos", pos + Vector2(-12.0, 0.0))
		_expect(
			afterimage_state.afterimages.size() == 3,
			"%s 변신: 캐릭터 입력 리더 intent → 잔상 3개, got %d" % [character_type, afterimage_state.afterimages.size()]
		)
	# 부정: viper 선택 + viper 리더 부재. 스매셔 리더가 intent를 들고 있어도
	# 키 라우팅이 viper를 향하므로 스폰 0이어야 한다.
	var moving_smasher := FakeInputReader.new()
	moving_smasher.snapshot = {"mouse_left_just_pressed": false, "left_pressed": true, "right_pressed": false}
	var negative_fixture: Dictionary = _build_transformed_fixture(moving_smasher)
	var negative_owner: Object = negative_fixture["owner"]
	var negative_registry: Object = negative_fixture["registry"]
	var negative_runtime: Object = negative_fixture["runtime"]
	negative_owner.set("selected_character_type", "viper")
	negative_owner.set("ball_pos", Vector2(380.0, 150.0))
	negative_owner.set("ball_vel", Vector2(0.0, -6.0))
	for _frame in range(13):
		negative_runtime.odins_eye_runtime.update_runtime(negative_runtime, 1.0, negative_owner, negative_registry)
		var pos: Vector2 = negative_owner.get("player_pos")
		negative_owner.set("player_pos", pos + Vector2(-12.0, 0.0))
	_expect(
		negative_runtime.odins_eye_afterimage_state.afterimages.is_empty(),
		"viper 선택 시 스매셔 리더 intent는 무시(캐릭터 키 라우팅 증명)"
	)


# [P2 씰] 승리/사망 정리는 본체 상태·호스트만이 아니라 잔상 상태까지 지워야
# 한다 — 남은 payload를 owner sync가 다시 게시하면 actor renderer의 오버레이
# 판정이 호스트를 재활성화한다.
func _verify_victory_death_transitions_clear_afterimages() -> void:
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {"mouse_left_just_pressed": false, "left_pressed": false, "right_pressed": false}
	var fixture: Dictionary = _build_transformed_fixture(input_reader)
	var runtime: Object = fixture["runtime"]
	var afterimage_state: Object = runtime.odins_eye_afterimage_state
	afterimage_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	runtime.odins_eye_runtime.clear_after_victory(runtime)
	_expect(afterimage_state.afterimages.is_empty(), "clear_after_victory → 잔상 소거")
	afterimage_state.create_afterimage(Vector2(400.0, 730.0), 155.0, 50.0)
	runtime.odins_eye_runtime.clear_after_death(runtime)
	_expect(afterimage_state.afterimages.is_empty(), "clear_after_death → 잔상 소거")


# [P2 실소비자 씰] 부활/사망 셰이크 곡선은 effects 경로의
# battle_effects_update_controller가 feedback.update(프레임 리셋) 직후
# fixed offset으로 밀어야 실제 화면 offset에 도달한다. 결정적 단위원
# 회전이라 기대 오프셋을 정확히 재계산해 대조한다.
func _verify_cinematic_shake_reaches_feedback() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"shake fixture: 장착"
	)
	_expect(runtime.try_trigger_odins_eye_revival("round", 0.0), "shake fixture: 부활 트리거")
	# 60프레임 진행: progress=60/225≈0.267 → 빌드 구간 강도 3*(0.267/0.80)≈1.0px.
	runtime.odins_eye_runtime.update_runtime(runtime, 60.0, owner, registry)
	var intensity: float = float(runtime.get_odins_eye_cinematic_shake_intensity())
	_expect(intensity > 0.5, "부활 빌드 구간 셰이크 곡선 > 0.5px, got %.3f" % intensity)
	var feedback := FakeFeedback.new()
	var controller: Object = BattleEffectsUpdateController.new()
	var now_msec := 1234
	controller.update(1.0 / 60.0, {"current_msec": now_msec}, {
		"feedback": feedback,
		"mythic_item_runtime": runtime,
	})
	_expect(feedback.update_calls == 1, "effects 경로가 feedback.update를 구동")
	_expect(feedback.fixed_pushes.size() == 1, "부활 연출 중 fixed shake push 1회, got %d" % feedback.fixed_pushes.size())
	if not feedback.fixed_pushes.is_empty():
		var angle: float = float(now_msec) / 1000.0 * 47.0
		var expected: Vector2 = Vector2(cos(angle), sin(angle)) * intensity
		var pushed: Vector2 = feedback.fixed_pushes[0] as Vector2
		_expect(pushed.distance_to(expected) < 0.0001, "push 오프셋 = 곡선 강도 × 결정적 단위원 (정확 대조)")
		# 반경 봉인: 단위원이 아니면(주파수 상이 sin/cos) 실길이가 0~√2×강도로
		# 요동해 BANG 12px 스파이크가 증발/과대해진다.
		_expect(
			absf(pushed.length() - intensity) < 0.0001,
			"offset.length() == 곡선 강도 (BANG px 보존), got %.4f vs %.4f" % [pushed.length(), intensity]
		)
	# 사망 폭발 구간도 실제 effects 소비자까지 관통 — getter에서 death 항을
	# 빼면(부활만 남기면) 이 레그가 RED다.
	runtime.odins_eye_runtime.update_runtime(runtime, 231.0, owner, registry)
	runtime.consume_odins_eye_revival_finalize_ready()
	_expect(bool(runtime.begin_odins_eye_death_sequence("round")), "shake fixture: 사망 시퀀스 시작")
	# 150프레임 = 2.5s: 폭발 페이즈(2.0~3.0s) 한가운데 → 곡선 강도 lerp(10,5,0.5)=7.5px.
	runtime.odins_eye_runtime.update_runtime(runtime, 150.0, owner, registry)
	var death_intensity: float = float(runtime.get_odins_eye_cinematic_shake_intensity())
	_expect(death_intensity > 5.0, "사망 폭발 구간 셰이크 곡선 > 5px, got %.3f" % death_intensity)
	var death_feedback := FakeFeedback.new()
	controller.update(1.0 / 60.0, {"current_msec": now_msec}, {
		"feedback": death_feedback,
		"mythic_item_runtime": runtime,
	})
	_expect(death_feedback.fixed_pushes.size() == 1, "사망 폭발 중 fixed shake push 1회, got %d" % death_feedback.fixed_pushes.size())
	if not death_feedback.fixed_pushes.is_empty():
		_expect(
			absf((death_feedback.fixed_pushes[0] as Vector2).length() - death_intensity) < 0.0001,
			"사망 push 길이 == 사망 곡선 강도"
		)

	# 연출 없음 → push 없음(공회전 방지).
	runtime.odins_eye_runtime.clear_after_death(runtime)
	var idle_feedback := FakeFeedback.new()
	controller.update(1.0 / 60.0, {"current_msec": now_msec}, {
		"feedback": idle_feedback,
		"mythic_item_runtime": runtime,
	})
	_expect(idle_feedback.fixed_pushes.is_empty(), "연출 비활성 시 shake push 없음")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.01:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
