extends SceneTree

# 승리 전리품 페이즈 씰: 보스 격파 후 상자 드랍 -> 낙하 -> 패들 획득 -> 개봉 시
# 보상 롤/그랜트 -> 전부 획득하면 종료 콜백(결과화면 진입) 계약을 검증한다.
# 결과화면 상자 이벤트에서 이관된 롤/그랜트/시네마틱 플래그 계약도 여기서 승계.

const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const ActiveItemFieldSpawnScheduler := preload("res://scripts/items/active_item_field_spawn_scheduler.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const MatchStateDepsBuilder := preload("res://scripts/core/battle_update_match_state_deps_builder.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")

var _failures: Array[String] = []
var _finish_calls: int = 0


class SchemaGatedOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var rejected_keys: Array[String] = []

	func _init() -> void:
		scene_state.reset()
		scene_state.set_value("boss_pos", Vector2(330.0, 25.0))
		scene_state.set_value("player_pos", Vector2(300.0, 700.0))
		scene_state.set_value("player_paddle_width", 155.0)
		scene_state.set_value("player_paddle_height", 50.0)

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			rejected_keys.append(key)
			return false
		scene_state.set_value(key, value)
		return true

	func value_of(key: String) -> Variant:
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null


class FakeGameAudio:
	extends RefCounted

	var result_box_open_calls := 0

	func play_result_box_open() -> void:
		result_box_open_calls += 1


class FakeActiveItemRuntime:
	extends RefCounted

	var collect_calls := 0
	var collect_result := true
	var last_collect_item_name := ""
	var last_collect_position := Vector2.ZERO
	var spawn_calls := 0

	func collect_item_by_name(item_name: String, position: Vector2, _owner: Object, _registry: Object) -> bool:
		collect_calls += 1
		last_collect_item_name = item_name
		last_collect_position = position
		return collect_result

	func spawn_field_item_data(_item_data: Dictionary, _position: Variant = null) -> bool:
		spawn_calls += 1
		return true


class FakeRegistry:
	extends RefCounted

	var game_audio: Object = null
	var active_item_runtime: Object = null

	func get_instance(key: String) -> Object:
		match key:
			"game_audio":
				return game_audio
			"active_item_runtime":
				return active_item_runtime
			_:
				return null


class FakeRewardResolver:
	extends RefCounted

	var reward_type := "starpoint"
	var roll_calls := 0
	var grant_calls := 0
	var rolled_kinds: Array = []
	var granted_rewards: Array = []

	func roll_reward(box_kind: String, _owner: Object, _registry: Object) -> Dictionary:
		roll_calls += 1
		rolled_kinds.append(box_kind)
		match reward_type:
			"starpoint":
				return {"type": "starpoint", "label": "★ 1", "amount": 1}
			"passive":
				return {"type": "passive", "label": "테스트 패시브", "item_name": "speedboots", "amount": 1}
			"active":
				return {"type": "active", "label": "테스트 액티브", "item_name": "banana", "amount": 1, "item_data": {"name": "banana"}}
		return {"type": reward_type, "label": "테스트 보상", "amount": 1}

	func grant_rewards(rewards: Array, _owner: Object, _registry: Object) -> Dictionary:
		grant_calls += 1
		for reward in rewards:
			if reward is Dictionary:
				granted_rewards.append((reward as Dictionary).duplicate(true))
		return {"attempted": rewards.size(), "granted": rewards.size(), "failed": []}


class LootCallRecordingState:
	extends RefCounted

	var active := true
	var update_calls := 0

	func is_active() -> bool:
		return active

	func update(_delta: float) -> void:
		update_calls += 1


class CallbackRecorder:
	extends RefCounted

	var calls: Dictionary = {}

	func record(key: String) -> void:
		calls[key] = int(calls.get(key, 0)) + 1

	func count(key: String) -> int:
		return int(calls.get(key, 0))

	func make(key: String) -> Callable:
		return Callable(self, "_on_call").bind(key)

	func make_delta(key: String) -> Callable:
		return Callable(self, "_on_call_delta").bind(key)

	func _on_call(key: String) -> void:
		record(key)

	func _on_call_delta(_delta: float, key: String) -> void:
		record(key)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_module_registration()
	_verify_start_guards_and_plan()
	_verify_drop_physics_and_stagger()
	_verify_pickup_open_grant_and_finish()
	_verify_active_reward_routes_through_pickup_rail()
	_verify_actor_draw_context()
	_verify_frame_flow_loot_branch()
	_verify_spawn_scheduler_blocks_during_loot()
	_verify_match_reset_clears_loot()

	if _failures.is_empty():
		print("victory_loot_phase_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_module_registration() -> void:
	var catalog := GameplayCoreModuleCatalog.new()
	var spec: Dictionary = catalog.get_spec("victory_loot_phase_state")
	_expect(
		str(spec.get("path", "")) == "res://scripts/core/victory_loot_phase_state.gd",
		"victory loot phase state should be registered in the core module catalog"
	)
	_expect(
		BattleSceneState.DEFAULT_VALUES.has("victory_loot_phase_active"),
		"victory loot phase owner flag must be declared in the owner schema"
	)


func _verify_start_guards_and_plan() -> void:
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	var registry := FakeRegistry.new()
	loot.set_reward_resolver_for_test(FakeRewardResolver.new())

	_expect(not loot.start(owner, registry, 3, 5, Callable()), "boss win must not start the victory loot phase")
	_expect(not loot.is_active(), "failed start should keep the loot phase inactive")

	_expect(loot.start(owner, registry, 5, 0, Callable()), "player 5:0 win should start the victory loot phase")
	_expect(loot.is_active(), "started loot phase should be active")
	_expect(loot.boxes.size() == 3, "5:0 win should drop three boxes under the 2026-07-28 reward tuning")
	_expect(bool(owner.value_of("victory_loot_phase_active")), "loot start should mirror the owner schema flag on")
	_expect(owner.rejected_keys.is_empty(), "owner flag mirror must use declared schema keys only; rejected=%s" % ", ".join(owner.rejected_keys))
	_expect(not loot.start(owner, registry, 5, 0, Callable()), "an active loot phase must reject a second start")

	var deuce_loot := VictoryLootPhaseState.new()
	deuce_loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(deuce_loot.start(owner, registry, 7, 6, Callable()), "deuce win should still start the loot phase")
	_expect(deuce_loot.boxes.size() == 1, "7:6 deuce win should drop exactly one box")
	deuce_loot.reset(owner)
	_expect(not bool(owner.value_of("victory_loot_phase_active")), "loot reset should clear the owner schema flag")


func _verify_drop_physics_and_stagger() -> void:
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	# 픽업 판정을 피하도록 플레이어를 왼쪽 끝으로 치워 낙하만 관찰한다.
	owner.scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
	var registry := FakeRegistry.new()
	loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(loot.start(owner, registry, 5, 0, Callable()), "drop physics leg should start the loot phase")

	loot.update(1.0 / 60.0)
	var first_box: Dictionary = loot.boxes[0]
	var second_box: Dictionary = loot.boxes[1]
	_expect(str(first_box.get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_DROP, "first box should start dropping immediately")
	_expect(str(second_box.get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_PENDING, "second box should stay pending until its stagger delay")

	var origin_y: float = (first_box.get("pos") as Vector2).y
	_expect(origin_y < 100.0, "boxes should spawn from the boss body band at the top")
	for _i in range(600):
		loot.update(1.0 / 60.0)
		if str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST:
			break
	first_box = loot.boxes[0]
	_expect(str(first_box.get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST, "dropped box should settle to rest on the floor band")
	_expect(is_equal_approx((first_box.get("pos") as Vector2).y, VictoryLootPhaseState.REST_Y), "rested box should sit exactly on the rest line")
	_expect(_finish_calls == 0, "loot phase must not finish while boxes are unopened")


func _verify_pickup_open_grant_and_finish() -> void:
	_finish_calls = 0
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	owner.scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
	var registry := FakeRegistry.new()
	var audio := FakeGameAudio.new()
	registry.game_audio = audio
	var resolver := FakeRewardResolver.new()
	resolver.reward_type = "passive"
	loot.set_reward_resolver_for_test(resolver)
	_expect(
		loot.start(owner, registry, 6, 4, Callable(self, "_record_finish")),
		"pickup leg should start a one-box deuce loot phase"
	)
	_expect(loot.boxes.size() == 1, "deuce loot phase should carry one box")

	# 낙하 완료까지 진행 후 플레이어를 상자 위치로 이동 -> 픽업 -> 개봉.
	for _i in range(600):
		loot.update(1.0 / 60.0)
		if str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST:
			break
	var rest_pos: Vector2 = (loot.boxes[0] as Dictionary).get("pos")
	owner.scene_state.set_value("player_pos", rest_pos - Vector2(77.5, 25.0))
	loot.update(1.0 / 60.0)
	_expect(
		str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_OPENING,
		"paddle contact with a rested box should begin opening it"
	)
	_expect(audio.result_box_open_calls == 1, "box opening should play the result box-open SFX")
	_expect(resolver.grant_calls == 0, "reward must not grant before the lid-open moment")

	for _i in range(120):
		loot.update(1.0 / 60.0)
		if _finish_calls > 0:
			break
	_expect(resolver.roll_calls == 1, "opening one box should roll exactly one reward")
	_expect(resolver.grant_calls == 1, "opening one box should grant exactly one reward")
	_expect(
		not resolver.rolled_kinds.is_empty() and str(resolver.rolled_kinds[0]) != "",
		"reward roll should receive the box kind"
	)
	var granted: Dictionary = resolver.granted_rewards[0] if not resolver.granted_rewards.is_empty() else {}
	_expect(granted.get("pickup_position", null) is Vector2, "granted reward should carry the box field position for cinematics")
	_expect(bool(granted.get("show_acquisition_cinematic", false)), "passive reward should request the in-battle acquisition cinematic")
	_expect(_finish_calls == 1, "collecting every box should fire the finish callback exactly once")
	_expect(not loot.is_active(), "finished loot phase should deactivate")
	_expect(not bool(owner.value_of("victory_loot_phase_active")), "finish should clear the owner schema flag")
	loot.update(1.0 / 60.0)
	_expect(_finish_calls == 1, "finish callback must never fire twice")


func _verify_active_reward_routes_through_pickup_rail() -> void:
	_finish_calls = 0
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	owner.scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
	var registry := FakeRegistry.new()
	var item_runtime := FakeActiveItemRuntime.new()
	registry.active_item_runtime = item_runtime
	var resolver := FakeRewardResolver.new()
	resolver.reward_type = "active"
	loot.set_reward_resolver_for_test(resolver)
	_expect(
		loot.start(owner, registry, 6, 4, Callable(self, "_record_finish")),
		"active reward leg should start a one-box loot phase"
	)
	for _i in range(600):
		loot.update(1.0 / 60.0)
		if str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST:
			break
	var rest_pos: Vector2 = (loot.boxes[0] as Dictionary).get("pos")
	owner.scene_state.set_value("player_pos", rest_pos - Vector2(77.5, 25.0))
	for _i in range(120):
		loot.update(1.0 / 60.0)
		if _finish_calls > 0:
			break
	_expect(item_runtime.collect_calls == 1, "active reward should route through the field pickup rail for popup/slot rules")
	_expect(item_runtime.last_collect_item_name == "banana", "pickup rail should receive the rolled active item name")
	_expect(resolver.grant_calls == 0, "active reward must not double-grant through the resolver when the pickup rail succeeds")
	_expect(_finish_calls == 1, "active reward loot phase should still finish once")

	# 슬롯 만석(수납 실패) 시나리오: 필드 아이템으로 남기면 결과화면 전환 +
	# 다음 스테이지 field_spawn_controller 리셋에 보상이 소실되므로, 반드시
	# 리졸버 그랜트(allow_overflow) 폴백으로 지급되어야 한다.
	_finish_calls = 0
	var full_loot := VictoryLootPhaseState.new()
	var full_owner := SchemaGatedOwner.new()
	full_owner.scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
	var full_registry := FakeRegistry.new()
	var full_item_runtime := FakeActiveItemRuntime.new()
	full_item_runtime.collect_result = false
	full_registry.active_item_runtime = full_item_runtime
	var full_resolver := FakeRewardResolver.new()
	full_resolver.reward_type = "active"
	full_loot.set_reward_resolver_for_test(full_resolver)
	_expect(
		full_loot.start(full_owner, full_registry, 6, 4, Callable(self, "_record_finish")),
		"slot-full active reward leg should start a one-box loot phase"
	)
	for _i in range(600):
		full_loot.update(1.0 / 60.0)
		if str((full_loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST:
			break
	var full_rest_pos: Vector2 = (full_loot.boxes[0] as Dictionary).get("pos")
	full_owner.scene_state.set_value("player_pos", full_rest_pos - Vector2(77.5, 25.0))
	for _i in range(120):
		full_loot.update(1.0 / 60.0)
		if _finish_calls > 0:
			break
	_expect(full_item_runtime.collect_calls == 1, "slot-full leg should still try the pickup rail first")
	_expect(full_resolver.grant_calls == 1, "slot-full active reward must fall back to the resolver overflow grant (no reward loss)")
	_expect(full_item_runtime.spawn_calls == 0, "slot-full active reward must never be dumped as a field item (lost on result-screen gate + stage reset)")
	_expect(_finish_calls == 1, "slot-full active reward loot phase should still finish once")


func _verify_actor_draw_context() -> void:
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	var registry := FakeRegistry.new()
	loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(loot.get_actor_draw_context().is_empty(), "inactive loot phase must not emit a boss defeat context")
	_expect(loot.start(owner, registry, 5, 0, Callable()), "actor context leg should start the loot phase")
	var context: Dictionary = loot.get_actor_draw_context()
	_expect(bool(context.get("boss_defeat_active", false)), "active loot phase should keep the boss defeat sheet playing")
	# 연속성 계약: 전리품 페이즈는 스코어보드(1.75s)가 홀드하던 마지막 defeat
	# 프레임에서 이어져야 한다(0프레임 되감김 금지). 1.75s > 8f x 0.18s 이므로
	# 일반 보스는 시작 즉시 마지막 프레임 홀드 상태다.
	_expect(
		int(context.get("boss_result_frame", -1)) == VictoryLootPhaseState.BOSS_RESULT_FRAME_COUNT - 1,
		"loot phase must continue the defeat clock from the scoreboard hold (no frame-zero rewind)"
	)
	loot.update(10.0)
	context = loot.get_actor_draw_context()
	_expect(
		int(context.get("boss_result_frame", -1)) == VictoryLootPhaseState.BOSS_RESULT_FRAME_COUNT - 1,
		"long loot phases should hold the final defeat frame"
	)
	_expect(not context.has("player_victory_active"), "loot phase must leave the player actor in normal control poses")

	# Stage 2 는 64프레임 defeat 시트를 쓴다: 스코어보드가 홀드하던
	# min(63, floor(1.75/0.025)) = 63 프레임에서 이어져야 한다.
	var stage2_loot := VictoryLootPhaseState.new()
	var stage2_owner := SchemaGatedOwner.new()
	stage2_owner.scene_state.set_value("current_stage", 2)
	stage2_loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(stage2_loot.start(stage2_owner, registry, 5, 0, Callable()), "stage2 actor context leg should start the loot phase")
	var stage2_context: Dictionary = stage2_loot.get_actor_draw_context()
	_expect(
		int(stage2_context.get("boss_defeat_frame", -1)) == VictoryLootPhaseState.BOSS_STAGE2_DEFEAT_FRAME_COUNT - 1,
		"stage2 loot phase must continue the 64f defeat clock from the scoreboard hold"
	)


func _verify_frame_flow_loot_branch() -> void:
	var controller := BattleFrameFlowController.new()
	var loot := LootCallRecordingState.new()
	var recorder := CallbackRecorder.new()
	var callbacks := {
		"update_weather": recorder.make_delta("update_weather"),
		"update_mythic_items": recorder.make_delta("update_mythic_items"),
		"update_player_control": recorder.make_delta("update_player_control"),
		"update_active_items": recorder.make_delta("update_active_items"),
		"update_ball": recorder.make_delta("update_ball"),
		"update_boss_ai": recorder.make_delta("update_boss_ai"),
		"update_lingpet": recorder.make_delta("update_lingpet"),
		"update_effects": recorder.make_delta("update_effects"),
		"queue_redraw": recorder.make("queue_redraw"),
	}
	controller.update(1.0 / 60.0, {"victory_loot_phase_state": loot}, callbacks)
	_expect(loot.update_calls == 1, "frame flow loot branch should tick the loot phase")
	_expect(recorder.count("update_player_control") == 1, "loot branch should keep player paddle control alive")
	_expect(recorder.count("update_active_items") == 1, "loot branch should keep item runtime (pickup popups) alive")
	_expect(recorder.count("update_effects") == 1, "loot branch should keep effects alive")
	_expect(recorder.count("update_ball") == 0, "loot branch must freeze the ball")
	_expect(recorder.count("update_boss_ai") == 0, "loot branch must freeze the boss AI")
	_expect(recorder.count("update_lingpet") == 0, "loot branch should pause the companion like other pause branches")

	# 신화 획득 시네마틱/퍽 선택 모달 페이즈에서는 전리품 갱신도 함께 멈춘다.
	var paused_recorder := CallbackRecorder.new()
	var paused_callbacks := {
		"update_weather": paused_recorder.make_delta("update_weather"),
		"update_mythic_items": paused_recorder.make_delta("update_mythic_items"),
		"update_player_control": paused_recorder.make_delta("update_player_control"),
		"update_effects": paused_recorder.make_delta("update_effects"),
		"queue_redraw": paused_recorder.make("queue_redraw"),
	}
	var pausing_perk_state := FakePausingRuntimePerkState.new()
	controller.update(
		1.0 / 60.0,
		{"victory_loot_phase_state": loot, "runtime_perk_state": pausing_perk_state},
		paused_callbacks
	)
	_expect(loot.update_calls == 1, "perk-choice pause must freeze the loot phase update")
	_expect(paused_recorder.count("update_player_control") == 0, "perk-choice pause must freeze player control during loot")
	_expect(paused_recorder.count("update_effects") == 1, "perk-choice pause should keep effects flowing during loot")


class FakePausingRuntimePerkState:
	extends RefCounted

	func is_choice_active() -> bool:
		return true


func _verify_spawn_scheduler_blocks_during_loot() -> void:
	var scheduler := ActiveItemFieldSpawnScheduler.new()
	var owner := SchemaGatedOwner.new()
	owner.scene_state.set_value("victory_loot_phase_active", true)
	_expect(scheduler.is_item_spawn_blocked(owner), "field item spawns must be blocked during the victory loot phase")
	owner.scene_state.set_value("victory_loot_phase_active", false)
	_expect(not scheduler.is_item_spawn_blocked(owner), "field item spawns should resume outside the loot phase")


class FakeMatchStateDepsRegistry:
	extends RefCounted

	var loot: Object

	func _init(new_loot: Object) -> void:
		loot = new_loot

	func get_instance(key: String) -> Object:
		if key == "victory_loot_phase_state":
			return loot
		return null


func _verify_match_reset_clears_loot() -> void:
	# F9 결과화면 직행/매치 리셋 경로: 매치 상태 리셋 deps에 전리품 페이즈가
	# 포함되고 _reset_match_state가 이를 reset해, 활성 전리품 페이즈가 다음
	# 매치의 프레임 플로우를 하이재킹하는 것을 막는다.
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	var registry := FakeRegistry.new()
	loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(loot.start(owner, registry, 5, 0, Callable()), "match reset leg should start the loot phase")
	var deps: Dictionary = MatchStateDepsBuilder.new().build_deps(FakeMatchStateDepsRegistry.new(loot))
	_expect(deps.get("victory_loot_phase_state") == loot, "match-state reset deps must include the victory loot phase")
	MatchResetController.new()._reset_match_state(deps)
	_expect(not loot.is_active(), "match reset must clear an in-progress victory loot phase")
	_expect(not bool(owner.value_of("victory_loot_phase_active")), "match reset must clear the owner loot flag")


func _record_finish() -> void:
	_finish_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
