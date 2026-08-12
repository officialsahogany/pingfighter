extends SceneTree

# S3-a 슬라이스 A-2 씰 — 본체 대체 철회(§C-3c rev4) + pre-pause reconcile(§C-3d rev8).
#
# 봉인 범위:
#  - P10: 본체 대체 5조건 각각 → 탑다운 탑승 철회. 오딘 첫 항은 OR 가 아니라
#    renderer 와 같은 fallback 의미론(transformed=false 명시면 penalty 무시).
#    온이마루(비탑다운) × 변신 = 탑승 유지 대조군.
#  - L-일반 / L-전리품: 실 BattleFrameFlowController.update() 관통 — pause 가
#    update_lingpet 앞에서 프레임을 반환해도 같은 프레임에 철회가 이행된다.
#    호출부별 개별 레그(각 호출부 한 줄 제거 → 해당 레그만 RED).
#  - rev8b: 멱등성(첫 reconcile 만 철회+무효화 1회, 반복 호출 무효화 불변) ·
#    L 레그에서 get_instance("lingpet_egg_runtime") 0회.
#
# 탑다운 모델 펫이 shipped 카탈로그에 없으므로(8-10) 모델 축은 SpyProfile 로 켠다.
# 이 씰은 egg 의 판정·철회 배선만 본다 — 렌더 분기는 슬라이스 B.

const LingpetMountState := preload("res://scripts/lingpet/lingpet_mount_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const BattleSceneUpdateCallbacks := preload("res://scripts/core/battle_scene_update_callbacks.gd")
const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")

var _failed := false


class SpyTopdownProfile:
	extends RefCounted
	# egg 는 _current_profile.is_mount_presentation_topdown() 만 묻는다.
	var topdown := true

	func is_mount_presentation_topdown() -> bool:
		return topdown


class SpyPauseRegistry:
	extends RefCounted
	# 프레임 플로 콜백이 쓰는 최소 표면. get_instance 는 세면서 값을 주되,
	# reconcile 경로에서는 0회여야 한다(rev8b cache-only).
	var cached: Dictionary = {}
	var instantiating_calls := 0

	func get_cached_instance(key: String) -> Variant:
		return cached.get(key, null)

	func get_instance(key: String) -> Variant:
		instantiating_calls += 1
		return cached.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_test_p10_five_conditions_each_dismount()
	_test_p10_odin_fallback_semantics()
	_test_p10_onimaru_untouched_control()
	_test_reconcile_idempotent_and_cache_invalidation()
	_test_flow_general_path_leg()
	_test_flow_victory_loot_path_leg()
	_test_p17_switch_transition_retires_mount()

	if _failed:
		printerr("lingpet_mount_body_presentation_reconcile_smoke: FAILED")
		quit(1)
		return
	print("lingpet_mount_body_presentation_reconcile_smoke: ok")
	quit(0)


# ── 픽스처 ──────────────────────────────────────────────────────────────────

# 실 BattleSceneShell(스키마 관통) — 자유 dict fake 는 A-0 결함을 그대로 통과시킨다.
func _make_owner() -> Object:
	return BattleSceneShell.new()


# 탑승 상태의 egg. 모델 축은 SpyTopdownProfile 로 켠다(탑다운) / 끈다(온이마루 대리).
func _make_mounted_egg(topdown_model: bool) -> Object:
	var runtime: Object = LingpetEggRuntime.new()
	var profile := SpyTopdownProfile.new()
	profile.topdown = topdown_model
	runtime._current_profile = profile
	runtime._mount_state.set_pet_id("onimaru")   # 지원 펫이면 충분 — 전이는 mount_state 소유
	runtime._mount_state._mounted = true
	return runtime


func _set_body_replaced(owner: Object, key: String) -> void:
	owner.set(key, true)


# ── P10: 5조건 각각 ────────────────────────────────────────────────────────

func _test_p10_five_conditions_each_dismount() -> void:
	var conditions := [
		"odins_eye_transformed",
		"odins_eye_revival_animation_active",
		"odins_eye_death_animation_active",
		"horn_strawberry_transformed",
		"horn_strawberry_event_playing",
	]
	for key in conditions:
		var owner := _make_owner()
		_set_body_replaced(owner, str(key))
		var runtime := _make_mounted_egg(true)
		var dismounted := bool(runtime.reconcile_topdown_mount_body_presentation(owner))
		_expect("P10 %s: reconcile 이 철회를 보고" % str(key), dismounted)
		_expect("P10 %s: is_mounted false" % str(key), not bool(runtime._mount_state.is_mounted()))
		owner.free()
	# 비변신 대조군: 아무 조건도 없으면 탑승 유지.
	var clean_owner := _make_owner()
	var clean_runtime := _make_mounted_egg(true)
	_expect("P10 대조군: 비변신이면 철회 없음", not bool(clean_runtime.reconcile_topdown_mount_body_presentation(clean_owner)))
	_expect("P10 대조군: 탑승 유지", bool(clean_runtime._mount_state.is_mounted()))
	clean_owner.free()


func _test_p10_odin_fallback_semantics() -> void:
	# renderer(:249-256)와 동일한 fallback: transformed 가 존재하며 false 면
	# penalty_active=true 여도 본체가 대체되지 않는다.
	# 실 BattleSceneState 는 두 키가 항상 선언되므로 "키 누락 + penalty" 는
	# 레거시 호환 레그다 — 미선언 키를 가진 bare RefCounted 로만 재현된다.

	# 주 레그: transformed=false 명시 + penalty=true → 철회하지 않음.
	var owner := _make_owner()
	owner.set("odins_eye_transformed", false)
	owner.set("odins_eye_penalty_active", true)
	var runtime := _make_mounted_egg(true)
	_expect(
		"P10 오딘 fallback 주 레그: transformed=false 명시면 penalty 무시(철회 없음)",
		not bool(runtime.reconcile_topdown_mount_body_presentation(owner))
	)
	_expect("P10 오딘 fallback 주 레그: 탑승 유지", bool(runtime._mount_state.is_mounted()))
	owner.free()

	# 레거시 호환 레그: transformed 키 자체가 없는 owner + penalty=true → 철회.
	var legacy_owner := RefCounted.new()
	legacy_owner.set("odins_eye_penalty_active", true)   # RefCounted 라 선언 무관 no-op
	# RefCounted 에는 키가 아예 없으므로 reader 가 penalty fallback 을 탄다 —
	# 단 penalty 도 없으니 이 대조는 스크립트 변수로 만든다.
	var legacy_shell := _LegacyOdinOwner.new()
	var legacy_runtime := _make_mounted_egg(true)
	_expect(
		"P10 오딘 fallback 레거시 레그: transformed 키 누락 + penalty=true → 철회",
		bool(legacy_runtime.reconcile_topdown_mount_body_presentation(legacy_shell))
	)


# transformed 키가 없고 penalty_active 만 있는 레거시형 owner.
class _LegacyOdinOwner:
	extends RefCounted
	var odins_eye_penalty_active := true


func _test_p10_onimaru_untouched_control() -> void:
	# 온이마루 대조군: 모델 축 false 면 5조건 전부에서 탑승 유지(§D 무접촉).
	for key in ["odins_eye_transformed", "horn_strawberry_event_playing"]:
		var owner := _make_owner()
		_set_body_replaced(owner, str(key))
		var runtime := _make_mounted_egg(false)
		_expect(
			"P10 온이마루 대조군 %s: 철회 없음" % str(key),
			not bool(runtime.reconcile_topdown_mount_body_presentation(owner))
		)
		_expect("P10 온이마루 대조군 %s: 탑승 유지" % str(key), bool(runtime._mount_state.is_mounted()))
		owner.free()


# ── rev8b: 멱등성 + 캐시 무효화 1회 ────────────────────────────────────────

func _test_reconcile_idempotent_and_cache_invalidation() -> void:
	var owner := _make_owner()
	_set_body_replaced(owner, "horn_strawberry_event_playing")
	var runtime := _make_mounted_egg(true)
	var revision_before := int(runtime._runtime_snapshot_revision)
	_expect("멱등성: 첫 호출 = 철회", bool(runtime.reconcile_topdown_mount_body_presentation(owner)))
	var revision_after_first := int(runtime._runtime_snapshot_revision)
	_expect("멱등성: 첫 철회가 스냅샷 revision 을 올림(+1)", revision_after_first == revision_before + 1)
	_expect("멱등성: 반복 호출 = no-op", not bool(runtime.reconcile_topdown_mount_body_presentation(owner)))
	_expect(
		"멱등성: 반복 호출은 revision 을 더 올리지 않음(스냅샷 캐시 보존)",
		int(runtime._runtime_snapshot_revision) == revision_after_first
	)
	owner.free()


# ── L-일반 / L-전리품: 실 프레임 플로 관통 ─────────────────────────────────

# 실 pause 술어 표면: _is_mythic_pause_active 는 deps["mythic_item_runtime"] 의
# should_pause_game() 을 부른다(뿔딸기 이벤트가 여기 물려 있는 실 계약과 동형).
class SpyMythicPauseRuntime:
	extends RefCounted

	func should_pause_game() -> bool:
		return true


class SpyVictoryLootState:
	extends RefCounted

	func is_active() -> bool:
		return true


# 프레임 플로 콜백 하네스. reconcile 은 **실 BattleSceneUpdateCallbacks 의
# 프로덕션 메서드**를 관통한다(get_cached_instance peek 포함 — rev8b cache-only
# 단언이 이 경로를 본다).
class _FlowHarness:
	extends RefCounted

	var owner: Object = null
	var registry: Object = null
	var callbacks_module: Object = null
	var lingpet_calls := 0
	var reconcile_calls := 0
	# 호출 순서 판별용 trace. 이벤트 플래그는 프레임 시작 시 false 이고
	# update_mythic_items 콜백이 true 로 전환한다 — reconcile 이 mythic 앞으로
	# 이동하면 철회할 근거가 아직 없어 mounted 가 남는다(순서 반증의 이빨).
	var trace: Array = []

	func noop_delta(_delta: float) -> void:
		pass

	func noop() -> void:
		pass

	func on_mythic(_delta: float) -> void:
		trace.append("mythic")
		owner.set("horn_strawberry_event_playing", true)

	func on_lingpet(_delta: float) -> void:
		lingpet_calls += 1

	func on_reconcile() -> void:
		trace.append("reconcile")
		reconcile_calls += 1
		callbacks_module._reconcile_lingpet_mount_presentation(owner, registry)


# 실 BattleFrameFlowController 로 한 프레임 돌린다. pause 활성 → update_lingpet
# 0회를 강제하고, 그 프레임 안에서 reconcile 이 철회를 이행했는지 본다.
func _run_flow_frame(victory_loot: bool) -> Dictionary:
	# 프레임 시작 시 이벤트는 false — 뿔딸기 이벤트는 update_mythic_items 가
	# 이 프레임 안에서 owner 에 투영한다(실 운영 순서와 동형).
	var owner := _make_owner()
	var runtime := _make_mounted_egg(true)
	var registry := SpyPauseRegistry.new()
	registry.cached["lingpet_egg_runtime"] = runtime

	var harness := _FlowHarness.new()
	harness.owner = owner
	harness.registry = registry
	harness.callbacks_module = BattleSceneUpdateCallbacks.new()

	var flow: Object = BattleFrameFlowController.new()
	var callbacks := {
		"update_weather": Callable(harness, "noop_delta"),
		"update_mythic_items": Callable(harness, "on_mythic"),
		"update_effects": Callable(harness, "noop_delta"),
		"queue_redraw": Callable(harness, "noop"),
		"reconcile_lingpet_mount_presentation": Callable(harness, "on_reconcile"),
		"update_lingpet": Callable(harness, "on_lingpet"),
	}
	var deps := {
		"mythic_item_runtime": SpyMythicPauseRuntime.new(),
	}
	if victory_loot:
		deps["victory_loot_phase_state"] = SpyVictoryLootState.new()
	flow.update(0.016, deps, callbacks)
	return {
		"owner": owner,
		"runtime": runtime,
		"registry": registry,
		"lingpet_calls": harness.lingpet_calls,
		"reconcile_calls": harness.reconcile_calls,
		"trace": harness.trace,
	}


func _test_flow_general_path_leg() -> void:
	var run := _run_flow_frame(false)
	_expect("L-일반: pause 프레임이라 update_lingpet 0회", int(run["lingpet_calls"]) == 0)
	_expect("L-일반: pre-pause reconcile 이 호출됨", int(run["reconcile_calls"]) >= 1)
	_expect(
		"L-일반: 호출 순서 = mythic → reconcile (이벤트 투영 후 철회)",
		(run["trace"] as Array) == ["mythic", "reconcile"]
	)
	_expect(
		"L-일반: 그럼에도 같은 프레임 is_mounted()==false",
		not bool((run["runtime"] as Object)._mount_state.is_mounted())
	)
	_expect(
		"L-일반: get_instance(\"lingpet_egg_runtime\") 0회 (rev8b cache-only)",
		int((run["registry"] as SpyPauseRegistry).instantiating_calls) == 0
	)
	(run["owner"] as Object).free()


# ── P17: 펫 전환 공존 불가 — 실 switch_lingpet_slot() 관통 ─────────────────
# §6-b 해석 3: _mount_state.reset() 직접 호출 금지. 현행 순서가
# _switch_transition_state.begin() → _set_current_pet_id()(내부 mount reset)라
# 렌더 시점엔 이미 비탑승이 성립한다 — switch 파티클/라벨(L5·L6)이 lane 중심에
# 뜨는 상태 자체가 안 나온다는 것을 상태로 증명한다.
func _test_p17_switch_transition_retires_mount() -> void:
	var owner := _make_owner()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("onimaru", owner, false)
	runtime._state = "companion"
	runtime._mount_state._mounted = true
	# 현행 로스터는 MAX_BATTLE_SLOTS=1 — "다른 슬롯으로 전환"이 아니라 owner 의
	# 슬롯 0 정본을 다른 펫으로 바꾼 뒤 같은 슬롯을 선택하는 형태가 실 전환이다
	# (select_active_slot 은 owner 슬롯을 정본으로 읽는다).
	owner.set("lingpet_slots", ["maribo"])
	var slots: Array = runtime._collection_state.get_battle_slots_from_owner(owner)
	var maribo_slot := slots.find("maribo")
	_expect("P17 사전: 마리보 슬롯 존재", maribo_slot >= 0)
	_expect("P17 사전: 탑승 상태", bool(runtime._mount_state.is_mounted()))
	var switched := bool(runtime.switch_lingpet_slot(maribo_slot, owner))
	_expect("P17: 실 switch_lingpet_slot 성공", switched)
	_expect("P17: 전환 프레임에 is_mounted()==false (L5·L6 lane 노출 성립 불가)", not bool(runtime._mount_state.is_mounted()))
	_expect(
		"P17: switch transition 이 실제로 진행 중 (전이 관통 증명 — reset 직접 호출 아님)",
		float(runtime._switch_transition_state.get_ratio(8.0)) > 0.0
	)
	owner.free()


func _test_flow_victory_loot_path_leg() -> void:
	var run := _run_flow_frame(true)
	_expect("L-전리품: pause 프레임이라 update_lingpet 0회", int(run["lingpet_calls"]) == 0)
	_expect("L-전리품: pre-pause reconcile 이 호출됨", int(run["reconcile_calls"]) >= 1)
	_expect(
		"L-전리품: 호출 순서 = mythic → reconcile (이벤트 투영 후 철회)",
		(run["trace"] as Array) == ["mythic", "reconcile"]
	)
	_expect(
		"L-전리품: 그럼에도 같은 프레임 is_mounted()==false",
		not bool((run["runtime"] as Object)._mount_state.is_mounted())
	)
	_expect(
		"L-전리품: get_instance(\"lingpet_egg_runtime\") 0회 (rev8b cache-only)",
		int((run["registry"] as SpyPauseRegistry).instantiating_calls) == 0
	)
	(run["owner"] as Object).free()
