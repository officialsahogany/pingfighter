extends SceneTree

# 오딘의 눈 액터-컨텍스트 병합 씰(2026-07-21 라이브 회귀 복원).
#
# 라이브 프레임의 액터 draw 컨텍스트는 mythic_item_context_builder.
# get_actor_draw_context() 병합으로만 mythic 시각 정보를 받는다. 이 빌더에
# 오딘 분기가 빠지면 상태·화면흔들림(별도 경로)은 살아도 변신 본체 스와프·
# 부활/사망 시네마틱·잔상·늪 가시 렌더가 전부 죽는다 — 실제 라이브 증상:
# "흔들림만 나오고 변신/사망 연출·변신 몸·스킬 비주얼 없음". 씰은 실
# MythicItemRuntime 실 트리거(equip→score event→finalize)로 producer를
# 관통하고, 액터 렌더러의 소비 판정(body swap/overlay active)까지 잇는다.

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"gameplay_frame_counter": 1,
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"active_item_slots": [],
		"ball_pos": Vector2(340.0, 760.0),
		"ball_pos_prev": Vector2(340.0, 730.0),
		"ball_vel": Vector2(0.0, 12.0),
		"ball_active": true,
		"boss_max_health": 20,
		"boss_current_health": 7,
		"boss_health_damage_units": 13,
		"boss_defeated_by_health": true,
		"starting_dash_tokens": 3,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true

	func queue_redraw() -> void:
		values["queue_redraw_calls"] = int(values.get("queue_redraw_calls", 0)) + 1


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false
	var player_serves := false

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		waiting_for_serve = true

	func start_scoreboard_wait() -> void:
		pass

	func start_round_restart_notice() -> void:
		pass

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeScoreboardState:
	extends RefCounted

	func trigger_top_mini_sparkle() -> void:
		pass

	func start(_a: int, _b: int, _c: bool, _d: String, _e: int = 5) -> void:
		pass


class FakeAudio:
	extends RefCounted

	func stop_dash_delay() -> void:
		pass

	func stop_warp_gate_loop() -> void:
		pass

	func stop_stage2_quake_loop() -> void:
		pass

	func play_round_set() -> void:
		pass


class FakeBallDriver:
	extends RefCounted

	func reset_ball(owner: Object, _registry: Object) -> void:
		owner.set("ball_pos", Vector2(380.0, 375.0))
		owner.set("ball_pos_prev", Vector2(380.0, 375.0))
		owner.set("ball_vel", Vector2.ZERO)
		owner.set("ball_active", false)


class FakeBossHealthFlow:
	extends RefCounted

	func reset_round_health(owner: Object) -> void:
		owner.set("boss_current_health", owner.get("boss_max_health"))
		owner.set("boss_health_damage_units", 0)
		owner.set("boss_defeated_by_health", false)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var score_state: Object = MatchScoreState.new()
	var round_state := FakeRoundState.new()
	var match_flow: Object = MatchFlowController.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"match_score_state": score_state,
		"round_flow_state": round_state,
		"scoreboard_state": FakeScoreboardState.new(),
		"game_audio": FakeAudio.new(),
		"battle_scene_ball_update_driver": FakeBallDriver.new(),
		"battle_scene_boss_health_flow": FakeBossHealthFlow.new(),
		"match_flow_controller": match_flow,
	})
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"Odin's Eye should equip for the actor-context smoke"
	)

	# Leg 1 — idle(장착만): 오딘 키 없음 + 게이트 false(핫패스 절약 계약).
	_expect(not runtime.has_actor_draw_context(), "idle equipped Odin should not open the actor draw context gate")
	_expect(
		not (runtime.get_actor_draw_context() as Dictionary).has("odins_eye_context"),
		"idle equipped Odin should not emit odins_eye_context"
	)

	# Leg 2 — 실 트리거(보스 득점 → 부활 시네마틱): producer가 오딘 컨텍스트를
	# 실어야 하고, 액터 렌더러의 소비 판정 둘 다 활성이어야 한다.
	match_flow.handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": runtime,
		"audio": registry.get_instance("game_audio"),
		"owner": owner,
		"registry": registry,
	}, {})
	_expect(runtime.is_odins_eye_revival_animation_active(), "boss score with 100% Odin should start the revival animation")
	_expect(runtime.has_actor_draw_context(), "revival animation should open the actor draw context gate")
	var revival_context: Dictionary = runtime.get_actor_draw_context()
	var revival_odins: Dictionary = revival_context.get("odins_eye_context", {}) as Dictionary
	_expect(not revival_odins.is_empty(), "revival animation should merge odins_eye_context into the actor draw context")
	_expect(bool(revival_odins.get("revival_animation_active", false)), "merged context should mark the revival animation active")
	var renderer := Stage1PlayerActorRenderer.new()
	_expect(renderer._is_odins_eye_body_swap_active(revival_odins), "actor renderer body swap should activate from the merged revival context")
	_expect(renderer._is_odins_eye_overlay_active(revival_odins), "actor renderer overlay host should activate from the merged revival context")

	# Leg 3 — finalize 후 변신 유지: transformed 단독으로도 컨텍스트가 실려
	# 본체 스와프가 살아야 한다(시네마틱 종료 후 "기존 캐릭터 그대로" 회귀).
	var item_driver := BattleSceneItemUpdateDriver.new()
	owner.set("gameplay_frame_counter", int(owner.get("gameplay_frame_counter")) + 1)
	item_driver.update_mythic_items(owner, registry, 3.85)
	_expect(runtime.is_odins_eye_transformed(), "revival finalize should leave the penalty transform active")
	_expect(not runtime.is_odins_eye_revival_animation_active(), "revival animation should be over after finalize")
	_expect(runtime.has_actor_draw_context(), "transformed form should keep the actor draw context gate open")
	var transformed_odins: Dictionary = (runtime.get_actor_draw_context() as Dictionary).get("odins_eye_context", {}) as Dictionary
	_expect(not transformed_odins.is_empty(), "transformed form should keep merging odins_eye_context")
	_expect(renderer._is_odins_eye_body_swap_active(transformed_odins), "actor renderer body swap should stay active while transformed")

	# Leg 4 — 잔상 payload 단독(폼 없음 가정의 페이드 계약): 실 afterimage
	# state에 payload를 남기면 컨텍스트가 계속 실려야 한다.
	var fade_runtime: Object = MythicItemRuntime.new()
	var fade_owner := FakeOwner.new()
	_expect(
		fade_runtime.equip_item("odins_eye", fade_owner, registry, {"revival_chance": 100.0}, false),
		"fade-leg runtime should equip Odin's Eye"
	)
	var afterimage_state: Object = fade_runtime.odins_eye_afterimage_state
	_expect(afterimage_state != null, "equipped Odin runtime should own an afterimage state")
	if afterimage_state != null:
		afterimage_state.create_afterimage(Vector2(320.0, 700.0), 155.0, 50.0)
		_expect(fade_runtime.has_actor_draw_context(), "lingering afterimage payload alone should keep the context gate open")
		var fade_odins: Dictionary = (fade_runtime.get_actor_draw_context() as Dictionary).get("odins_eye_context", {}) as Dictionary
		_expect(not fade_odins.is_empty(), "lingering afterimage payload should still merge odins_eye_context")
		_expect(renderer._is_odins_eye_overlay_active(fade_odins), "overlay host should stay active for the lingering afterimage fade")

	if _failures.is_empty():
		print("odins_eye_actor_context_merge_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
