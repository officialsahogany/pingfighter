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
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const BattleDrawActorResultContext := preload("res://scripts/core/battle_draw_actor_result_context.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")

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
	# 이 타입의 보상은 grant summary에서 granted=0으로 보고한다(동일 액티브
	# 효과 진행 중 can_store_item 거절 등 실 리졸버의 지급 실패 재현).
	var grant_fail_types: Array = []

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
		var granted_count: int = 0
		var failed: Array = []
		for reward in rewards:
			if not (reward is Dictionary):
				continue
			var reward_dict: Dictionary = reward
			granted_rewards.append(reward_dict.duplicate(true))
			if grant_fail_types.has(str(reward_dict.get("type", ""))):
				failed.append(reward_dict.duplicate(true))
			else:
				granted_count += 1
		return {"attempted": rewards.size(), "granted": granted_count, "failed": failed}


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
	_verify_real_runtime_effect_gate_forces_starpoint_fallback_premise()
	_verify_final_win_scoreboard_plays_power_loss_vibration()
	_verify_loot_defeat_reaches_renderer_facing_actor_context()

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
	owner.scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
	var registry := FakeRegistry.new()
	loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(loot.start(owner, registry, 5, 0, Callable()), "drop physics leg should start the loot phase")

	var origin_y: float = ((loot.boxes[0] as Dictionary).get("pos") as Vector2).y
	_expect(origin_y < 100.0, "boxes should spawn from the boss body band at the top")

	# 인트로(패배 라투디 0프레임 재생) 동안은 어떤 상자도 드랍되지 않는다.
	for _i in range(30):
		loot.update(1.0 / 60.0)
	_expect(
		str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_PENDING,
		"boxes must stay pending during the defeat-latudi intro"
	)

	# 인트로 종료 후 첫 상자만 드랍 시작(스태거), 나머지는 대기.
	for _i in range(600):
		loot.update(1.0 / 60.0)
		if str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_DROP:
			break
	_expect(
		str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_DROP,
		"first box should start dropping after the intro"
	)
	_expect(
		str((loot.boxes[1] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_PENDING,
		"second box should stay pending until its stagger delay"
	)

	# 플레이어를 착지 x에 미리 세워두고: 팝업(위로 떠오름) -> 낙하 -> 바닥 바운스
	# -> 완전 안착(REST) 후에만 개봉되는지 프레임 단위로 관찰한다.
	var base_x: float = float((loot.boxes[0] as Dictionary).get("base_x", 380.0))
	owner.scene_state.set_value("player_pos", Vector2(base_x - 77.5, 700.0))
	var min_y: float = origin_y
	var floor_touched: bool = false
	var bounce_seen: bool = false
	var opened_from_phase: String = ""
	var prev_phase: String = str((loot.boxes[0] as Dictionary).get("phase", ""))
	for _i in range(900):
		loot.update(1.0 / 60.0)
		var box: Dictionary = loot.boxes[0]
		var cur_phase: String = str(box.get("phase", ""))
		var y: float = (box.get("pos") as Vector2).y
		min_y = minf(min_y, y)
		if cur_phase == VictoryLootPhaseState.BOX_PHASE_DROP:
			if y >= VictoryLootPhaseState.REST_Y - 0.5:
				floor_touched = true
			elif floor_touched and y < VictoryLootPhaseState.REST_Y - 2.0:
				bounce_seen = true
		if cur_phase == VictoryLootPhaseState.BOX_PHASE_OPENING:
			opened_from_phase = prev_phase
			break
		prev_phase = cur_phase
	_expect(min_y < origin_y - 15.0, "box must pop upward from the boss body before falling")
	_expect(bounce_seen, "box must bounce at least once on floor contact before settling")
	_expect(
		opened_from_phase == VictoryLootPhaseState.BOX_PHASE_REST,
		"box must only open after fully settling (REST) even with the paddle waiting under it"
	)
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

	# 리졸버 지급마저 실패하는 시나리오(동일 액티브 효과 진행 중 can_store_item
	# 거절 — allow_overflow보다 먼저 검사됨): 확정 스타포인트로 대체 지급되어야
	# 하며 상자만 조용히 완료 처리되면 안 된다.
	_finish_calls = 0
	var gated_loot := VictoryLootPhaseState.new()
	var gated_owner := SchemaGatedOwner.new()
	gated_owner.scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
	var gated_registry := FakeRegistry.new()
	var gated_item_runtime := FakeActiveItemRuntime.new()
	gated_item_runtime.collect_result = false
	gated_registry.active_item_runtime = gated_item_runtime
	var gated_resolver := FakeRewardResolver.new()
	gated_resolver.reward_type = "active"
	gated_resolver.grant_fail_types = ["active"]
	gated_loot.set_reward_resolver_for_test(gated_resolver)
	_expect(
		gated_loot.start(gated_owner, gated_registry, 6, 4, Callable(self, "_record_finish")),
		"grant-fail active reward leg should start a one-box loot phase"
	)
	for _i in range(600):
		gated_loot.update(1.0 / 60.0)
		if str((gated_loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST:
			break
	var gated_rest_pos: Vector2 = (gated_loot.boxes[0] as Dictionary).get("pos")
	gated_owner.scene_state.set_value("player_pos", gated_rest_pos - Vector2(77.5, 25.0))
	for _i in range(120):
		gated_loot.update(1.0 / 60.0)
		if _finish_calls > 0:
			break
	_expect(gated_resolver.grant_calls == 2, "failed active grant must trigger a second fallback grant call")
	var fallback_granted: Dictionary = gated_resolver.granted_rewards.back() if not gated_resolver.granted_rewards.is_empty() else {}
	_expect(str(fallback_granted.get("type", "")) == "starpoint", "grant-fail fallback must be a guaranteed starpoint reward")
	_expect(int(fallback_granted.get("amount", 0)) == 1, "grant-fail fallback should grant one starpoint")
	_expect(str(fallback_granted.get("fallback_from_item_name", "")) == "banana", "starpoint fallback should record the lost item for audit")
	_expect(not bool(fallback_granted.get("defer_choice_open", true)), "starpoint fallback should open the perk choice immediately like other loot starpoints")
	var recorded_reward: Dictionary = gated_loot.collected_rewards.back() if not gated_loot.collected_rewards.is_empty() else {}
	_expect(str(recorded_reward.get("type", "")) == "starpoint", "collected rewards must record the fallback, not the lost active")
	_expect(_finish_calls == 1, "grant-fail loot phase should still finish once")

	# 2차 스타포인트 지급까지 실패하는 극단 케이스(지급 인프라 부재): 소실을
	# grant_failed로 기록만 하고 상자 완료/종료는 유지해 소프트락을 막는다.
	_finish_calls = 0
	var dead_loot := VictoryLootPhaseState.new()
	var dead_owner := SchemaGatedOwner.new()
	dead_owner.scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
	var dead_registry := FakeRegistry.new()
	var dead_item_runtime := FakeActiveItemRuntime.new()
	dead_item_runtime.collect_result = false
	dead_registry.active_item_runtime = dead_item_runtime
	var dead_resolver := FakeRewardResolver.new()
	dead_resolver.reward_type = "active"
	dead_resolver.grant_fail_types = ["active", "starpoint"]
	dead_loot.set_reward_resolver_for_test(dead_resolver)
	_expect(
		dead_loot.start(dead_owner, dead_registry, 6, 4, Callable(self, "_record_finish")),
		"double-grant-fail leg should start a one-box loot phase"
	)
	for _i in range(600):
		dead_loot.update(1.0 / 60.0)
		if str((dead_loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST:
			break
	var dead_rest_pos: Vector2 = (dead_loot.boxes[0] as Dictionary).get("pos")
	dead_owner.scene_state.set_value("player_pos", dead_rest_pos - Vector2(77.5, 25.0))
	for _i in range(120):
		dead_loot.update(1.0 / 60.0)
		if _finish_calls > 0:
			break
	_expect(dead_resolver.grant_calls == 2, "double-grant-fail leg should attempt the original grant and the starpoint fallback")
	var dead_recorded: Dictionary = dead_loot.collected_rewards.back() if not dead_loot.collected_rewards.is_empty() else {}
	_expect(str(dead_recorded.get("type", "")) == "active", "double failure should record the original reward for audit")
	_expect(bool(dead_recorded.get("grant_failed", false)), "double failure must be flagged grant_failed on the recorded reward")
	_expect(str((dead_loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_DONE, "double failure must still complete the box (no softlock)")
	_expect(_finish_calls == 1, "double failure must still fire the finish callback exactly once")
	_expect(not dead_loot.is_active(), "double failure must still deactivate the loot phase")


func _verify_actor_draw_context() -> void:
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	var registry := FakeRegistry.new()
	loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(loot.get_actor_draw_context().is_empty(), "inactive loot phase must not emit a boss defeat context")
	_expect(loot.start(owner, registry, 5, 0, Callable()), "actor context leg should start the loot phase")
	var context: Dictionary = loot.get_actor_draw_context()
	_expect(bool(context.get("boss_defeat_active", false)), "active loot phase should keep the boss defeat sheet playing")
	# 신규 연출 계약: 최종 승리 스코어보드는 defeat 대신 파워로스 진동을 틀므로,
	# 패배 라투디(슬럼프)는 전리품 인트로에서 0프레임부터 새로 재생해야 한다.
	_expect(
		int(context.get("boss_result_frame", -1)) == 0,
		"loot intro must start the defeat slump from frame zero (vibration beat precedes it)"
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
		int(stage2_context.get("boss_defeat_frame", -1)) == 0,
		"stage2 loot intro must also start its 64f defeat slump from frame zero"
	)
	stage2_loot.update(VictoryLootPhaseState.INTRO_DEFEAT_SEC)
	stage2_context = stage2_loot.get_actor_draw_context()
	_expect(
		int(stage2_context.get("boss_defeat_frame", -1)) == VictoryLootPhaseState.BOSS_STAGE2_DEFEAT_FRAME_COUNT - 1,
		"stage2 defeat slump should reach its held final frame within the intro window"
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


func _verify_real_runtime_effect_gate_forces_starpoint_fallback_premise() -> void:
	# 폴백의 실전 전제 봉인: 실제 ActiveItemRuntime에서 동일 액티브 효과가
	# 진행 중이면(예: 자기장 지속 중 자기장) can_store_item 게이트가 용량 가드
	# (allow_overflow)보다 먼저 거절하고, 실제 리졸버 grant summary도 granted=0을
	# 보고한다 — 전리품 페이즈가 summary를 무시하면 보상이 소실되는 이유다.
	var runtime := ActiveItemRuntime.new()
	var owner := SchemaGatedOwner.new()
	var registry := FakeRegistry.new()
	registry.active_item_runtime = runtime
	runtime._ensure_helpers_ready()
	runtime.effect_controller.magnet_field_active = true
	_expect(
		not bool(runtime.grant_item_to_slot("magnet_field", owner, registry, true)),
		"real runtime must reject a duplicate active while its effect runs (can_store gate precedes overflow)"
	)
	var resolver := StageClearRewardResolver.new()
	var summary_value: Variant = resolver.grant_rewards(
		[{"type": "active", "item_name": "magnet_field", "label": "자기장", "amount": 1}],
		owner,
		registry
	)
	var summary: Dictionary = summary_value if summary_value is Dictionary else {}
	_expect(int(summary.get("granted", -1)) == 0, "real resolver must report zero granted for the effect-gated active reward")
	var failed_value: Variant = summary.get("failed", [])
	var failed: Array = failed_value if failed_value is Array else []
	_expect(not failed.is_empty(), "real resolver should list the effect-gated reward as failed")


class FakeScoreboardStateForResultContext:
	extends RefCounted

	var pending_game_reset := true
	var timer := 1.0

	func is_active() -> bool:
		return true

	func get_last_scoring_side() -> String:
		return "player"

	func get_player_points() -> int:
		return 5

	func get_boss_points() -> int:
		return 0

	func get_timer() -> float:
		return timer

	func has_pending_game_reset() -> bool:
		return pending_game_reset


func _verify_final_win_scoreboard_plays_power_loss_vibration() -> void:
	# 최종 승리 스코어보드는 보스를 defeat로 눕히지 않고 고속 진동(파워로스)을
	# 재생한다 — 패배 라투디는 전리품 인트로가 이어받는다. 라운드 승리(비종료)
	# 스코어보드는 기존 defeat 반응을 유지해야 한다.
	var scoreboard := FakeScoreboardStateForResultContext.new()
	var deps := {"scoreboard_state": scoreboard}
	var context: Dictionary = BattleDrawActorResultContext.get_boss_result_context(deps, 1)
	_expect(not bool(context.get("boss_defeat_active", false)), "final-win scoreboard must not slump the boss yet (vibration beat owns this window)")
	_expect(bool(context.get("boss_power_loss_shake_active", false)), "final-win scoreboard should emit the power-loss vibration context")
	var offset_value: Variant = context.get("boss_power_loss_shake_offset", Vector2.ZERO)
	var offset: Vector2 = offset_value if offset_value is Vector2 else Vector2.ZERO
	_expect(offset.length() > 0.5, "vibration should visibly displace the boss mid-window")
	_expect(bool(context.get("player_victory_active", false)), "player victory pose should keep playing during the vibration beat")

	# 구간 말미에는 진동이 잦아들어 슬럼프로 자연 연결된다.
	scoreboard.timer = 1.75
	var end_context: Dictionary = BattleDrawActorResultContext.get_boss_result_context(deps, 1)
	var end_offset_value: Variant = end_context.get("boss_power_loss_shake_offset", Vector2.ZERO)
	var end_offset: Vector2 = end_offset_value if end_offset_value is Vector2 else Vector2.ZERO
	_expect(end_offset.length() < 0.05, "vibration must settle to zero by the end of the scoreboard window")

	# 라운드 승리(매치 미종료)는 기존 defeat 반응 유지.
	scoreboard.pending_game_reset = false
	scoreboard.timer = 1.0
	var round_context: Dictionary = BattleDrawActorResultContext.get_boss_result_context(deps, 1)
	_expect(bool(round_context.get("boss_defeat_active", false)), "round-win scoreboard must keep the per-round boss defeat reaction")
	_expect(not round_context.has("boss_power_loss_shake_active"), "round-win scoreboard must not vibrate the boss")

	# 배선 씰(구조): actor context가 진동 오프셋을 보스 렌더 위치에 더한다.
	var actor_context_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_draw_actor_context.gd")
	_expect(
		actor_context_source.find("boss_power_loss_shake_offset") >= 0
			and actor_context_source.find("boss_draw_pos += ") >= 0,
		"actor context should apply the power-loss shake offset to the boss render position"
	)


func _verify_loot_defeat_reaches_renderer_facing_actor_context() -> void:
	# 회귀(라이브 발견): 전리품 defeat 키가 텍스처 sync용 combined에는 merge되고
	# 렌더러-대면 actor_context에는 merge되지 않아 보스가 일반 포즈로 남았다.
	# 소스(get_actor_draw_context) 단언만으로는 이 이음새를 못 잡으므로, 실제
	# BattleDrawActorContext.build() 반환 dict까지 관통해 봉인한다.
	var loot := VictoryLootPhaseState.new()
	var owner := SchemaGatedOwner.new()
	var registry := FakeRegistry.new()
	loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(loot.start(owner, registry, 5, 0, Callable()), "actor-context integration leg should start the loot phase")
	loot.update(0.5)
	var expected_frame: int = int(loot.get_actor_draw_context().get("boss_result_frame", -99))
	var builder := BattleDrawActorContext.new()
	var actor_context: Dictionary = builder.build(
		{"current_stage": 1, "selected_character_type": "smasher"},
		{"victory_loot_phase_state": loot}
	)
	_expect(
		bool(actor_context.get("boss_defeat_active", false)),
		"victory loot defeat keys must reach the renderer-facing actor context (not only the texture-sync combined context)"
	)
	_expect(
		int(actor_context.get("boss_result_frame", -1)) == expected_frame,
		"renderer-facing actor context should carry the loot defeat frame clock"
	)

	# Stage 2(64f 시트) 픽스처: S2/S6 렌더러는 boss_defeat_frame을 우선 소비하고
	# 키가 누락되면 자체 루프 클럭으로 조용히 폴백한다 — merge가 필드별 복사로
	# 바뀌어 frame 키만 빠지는 회귀까지 build() 반환값에서 직접 봉인한다.
	var stage2_loot := VictoryLootPhaseState.new()
	var stage2_owner := SchemaGatedOwner.new()
	stage2_owner.scene_state.set_value("current_stage", 2)
	stage2_loot.set_reward_resolver_for_test(FakeRewardResolver.new())
	_expect(
		stage2_loot.start(stage2_owner, registry, 5, 0, Callable()),
		"stage2 actor-context integration leg should start the loot phase"
	)
	var stage2_start_context: Dictionary = builder.build(
		{"current_stage": 2, "selected_character_type": "smasher"},
		{"victory_loot_phase_state": stage2_loot}
	)
	_expect(
		int(stage2_start_context.get("boss_defeat_frame", -1)) == 0,
		"renderer-facing actor context must carry the stage2 defeat frame from zero at loot start"
	)
	stage2_loot.update(VictoryLootPhaseState.INTRO_DEFEAT_SEC)
	var stage2_held_context: Dictionary = builder.build(
		{"current_stage": 2, "selected_character_type": "smasher"},
		{"victory_loot_phase_state": stage2_loot}
	)
	_expect(
		int(stage2_held_context.get("boss_defeat_frame", -1)) == VictoryLootPhaseState.BOSS_STAGE2_DEFEAT_FRAME_COUNT - 1,
		"renderer-facing actor context must carry the stage2 held final defeat frame after the intro"
	)


func _record_finish() -> void:
	_finish_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
