extends SceneTree

# S2 안장 게이트 씰 (2026-08-05) — D1 "해금(=현재 액티브 슬롯 장착)되어야 탑승".
#
# 계약 (docs/lingpet_baekrin_mokrin_slice_plan.md §2-1·§2-4):
#  - 지원 펫 = MOUNT_SADDLE_SKILL_IDS 키 ∪ 유예 목록 (화이트리스트 기준 폐지)
#  - 온이마루 유예: 오니마루의안장(S8) 전까지 장착 없이 permitted — 명시 봉인
#  - permit은 진입 게이트이자 철회 전이: 탑승 중 permit 상실 → 같은 프레임 강제
#    하차(toggled=true), 슬롯 유지 대조군은 계속 탑승
#  - egg runtime은 장착 슬롯 조회로 불리언 하나만 전달 (맵·유예 해석은 mount_state)

const LingpetMountState := preload("res://scripts/lingpet/lingpet_mount_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionSkillPersistence := preload("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")
const LingpetUnlockLoadoutReconciler := preload("res://scripts/lingpet/lingpet_unlock_loadout_reconciler.gd")
const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")

const STATE_COMPANION := "companion"
const LANE_Y := 655.0

var _failed := false


class FakeInputProbe:
	extends RefCounted

	var rmb := false
	var down := false

	func is_rmb_pressed() -> bool:
		return rmb

	func is_down_pressed() -> bool:
		return down


class FakeMountOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 675.0)
	var player_paddle_width := 155.0
	var player_speed := 0.0


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_test_supported_pets()
	_test_permit_resolution()
	_test_entry_gate_blocks_unpermitted()
	_test_revocation_transition_and_control()
	_test_runtime_slot_lookup_pierced()
	_test_exposure_lockout_both_sides()
	_test_shared_cooldown_immunity()
	_test_snapshot_interaction_projection()
	if _failed:
		printerr("lingpet_mount_saddle_gate_smoke: FAILED")
		quit(1)
		return
	print("lingpet_mount_saddle_gate_smoke: ok")
	quit(0)


func _test_supported_pets() -> void:
	_expect("onimaru 지원(유예)", LingpetMountState.is_supported_pet("onimaru"))
	_expect("baekrin 지원(맵 키)", LingpetMountState.is_supported_pet("baekrin"))
	_expect("maribo 미지원", not LingpetMountState.is_supported_pet("maribo"))


func _test_permit_resolution() -> void:
	_expect("온이마루 유예: 장착 없이 permitted", LingpetMountState.is_mount_permitted("onimaru", []))
	_expect("baekrin: 미장착 → false", not LingpetMountState.is_mount_permitted("baekrin", []))
	_expect(
		"baekrin: 안장 장착 → true",
		LingpetMountState.is_mount_permitted("baekrin", ["baekrin_saddle"])
	)
	_expect(
		"baekrin: 다른 스킬만 장착 → false (보유·유사 id 불인정)",
		not LingpetMountState.is_mount_permitted("baekrin", ["baekrin_mokrin_transform"])
	)
	_expect("미지 펫: fail-closed false", not LingpetMountState.is_mount_permitted("no_such_pet", ["anything"]))


func _mount_via_toggle(state: Object, probe: FakeInputProbe, owner: Object, companion_pos: Vector2, permitted: bool) -> bool:
	# 엣지 감지: 눌리지 않은 프레임 → 눌린 프레임.
	probe.rmb = false
	state.advance(owner, companion_pos, true, false, 0.016, permitted)
	probe.rmb = true
	var result: Dictionary = state.advance(owner, companion_pos, true, false, 0.016, permitted)
	probe.rmb = false
	return bool(result.get("mounted", false))


func _test_entry_gate_blocks_unpermitted() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeMountOwner.new()
	var companion_pos := Vector2(377.5, 640.0)  # 패들 중심 정확히 위 (근접 확실)

	var gated := LingpetMountState.new()
	gated.set_input_probe(probe)
	gated.set_pet_id("baekrin")
	_expect(
		"진입 게이트: 미장착 baekrin은 우클릭에도 탑승 불가",
		not _mount_via_toggle(gated, probe, owner, companion_pos, false)
	)

	var legacy := LingpetMountState.new()
	legacy.set_input_probe(probe)
	legacy.set_pet_id("onimaru")
	_expect(
		"온이마루 유예: 현행 탑승 유지 (장착 없이 진입)",
		_mount_via_toggle(legacy, probe, owner, companion_pos, LingpetMountState.is_mount_permitted("onimaru", []))
	)


func _test_revocation_transition_and_control() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeMountOwner.new()
	var companion_pos := Vector2(377.5, 640.0)

	# permit=true로 baekrin 탑승 성립 (장착 상태 가정의 단위 주입)
	var state := LingpetMountState.new()
	state.set_input_probe(probe)
	state.set_pet_id("baekrin")
	_expect("사전: permit=true면 baekrin 탑승 성립", _mount_via_toggle(state, probe, owner, companion_pos, true))

	# 대조군: 슬롯 유지(permit=true) → 계속 탑승
	var held: Dictionary = state.advance(owner, companion_pos, true, false, 0.016, true)
	_expect("대조군: permit 유지 → 계속 탑승", bool(held.get("mounted", false)))

	# 철회 전이: 같은 프레임 강제 하차 + toggled
	var revoked: Dictionary = state.advance(owner, companion_pos, true, false, 0.016, false)
	_expect("철회: permit 상실 프레임에 mounted=false", not bool(revoked.get("mounted", true)))
	_expect("철회: toggled=true (강제 하차 전이)", bool(revoked.get("toggled", false)))
	_expect("철회 후 재프레임에도 하차 유지", not bool(state.advance(owner, companion_pos, true, false, 0.016, false).get("mounted", true)))


class NullRegistry:
	extends RefCounted

	func get_cached_instance(_key: String) -> Variant:
		return null

	func get_instance(_key: String) -> Variant:
		return null


class RuntimeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 675.0)
	var player_paddle_width := 155.0
	var player_speed := 0.0
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6


func _make_summoned_runtime(pet_id: String, equipped_skill_id: String, owner: Object) -> Object:
	# 실 슬롯 조회 관통용: debug grant로 loadout(장착 슬롯)을 실제로 기록하고,
	# 컴패니언을 플레이어 중심에 소환 상태로 배치한다.
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet(pet_id, owner, false, equipped_skill_id)
	runtime._state = STATE_COMPANION
	runtime._guardian_stowed = false
	var center_x: float = owner.player_pos.x + owner.player_paddle_width * 0.5
	runtime._companion_pos = Vector2(center_x, LANE_Y)
	runtime._companion_motion_state.pos = runtime._companion_pos
	runtime._companion_motion_state.motion_visible = true
	return runtime


func _mount_via_runtime(runtime: Object, owner: Object, registry: Object) -> bool:
	# 운영 경로: _update_companion_motion() 안에서 permit이 실 슬롯 조회로 계산되고
	# advance()에 전달된다 — 수제 불리언 주입 없음 (2026-08-05 리뷰 P1).
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = false
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = true
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = false
	return bool(runtime._mount_state.is_mounted())


func _test_runtime_slot_lookup_pierced() -> void:
	var owner := RuntimeOwner.new()
	var registry := NullRegistry.new()

	# ① 온이마루 유예: 장착 없이 운영 경로로 탑승 성립 (현행 유지)
	var legacy: Object = _make_summoned_runtime("onimaru", "", owner)
	_expect("운영 관통①: 온이마루 유예 탑승 성립", _mount_via_runtime(legacy, owner, registry))

	# ② 백린 미장착: 운영 경로에서 진입 차단 (실 슬롯 조회가 false를 만든다)
	var bare: Object = _make_summoned_runtime("baekrin", "baekrin_mokrin_transform", owner)
	_expect("운영 관통②: 안장 미장착 백린은 진입 불가", not _mount_via_runtime(bare, owner, registry))

	var saddled: Object = _make_summoned_runtime("baekrin", "baekrin_saddle", owner)
	var mounted: bool = _mount_via_runtime(saddled, owner, registry)
	_expect("운영 관통③: 안장 장착 백린 탑승 성립 (실 슬롯 조회 양성)", mounted)
	if not mounted:
		return

	# ④ 대조군: 슬롯 유지 → 다음 프레임에도 계속 탑승
	saddled._update_companion_motion(0.016, owner, registry)
	_expect("운영 관통④: 슬롯 유지 대조군은 계속 탑승", bool(saddled._mount_state.is_mounted()))

	# ⑤ 철회: 탑승 중 안장 슬롯을 다른 스킬로 교체 → 같은 프레임 강제 하차
	saddled.debug_grant_and_activate_pet("baekrin", owner, false, "baekrin_mokrin_transform")
	saddled._state = STATE_COMPANION
	saddled._guardian_stowed = false
	saddled._update_companion_motion(0.016, owner, registry)
	_expect(
		"운영 관통⑤: 슬롯 교체 프레임에 강제 하차 (실 슬롯 조회 → 철회 전이)",
		not bool(saddled._mount_state.is_mounted())
	)


func _test_exposure_lockout_both_sides() -> void:
	# 정의(정규화 통과)와 노출(획득 후보)의 분리 — 양쪽 모두 봉인 (S2 수락 조건).
	_expect(
		"정의: 명시 장착 정규화 통과",
		LingpetCatalog.normalize_active_skill_id("baekrin", "baekrin_saddle") == "baekrin_saddle"
	)
	var issues := LingpetCatalog.validate_entry("baekrin", LingpetCatalog.get_entry("baekrin"), true)
	_expect("정의: permit 포함 baekrin 엔트리 검증 0건: %s" % str(issues), issues.is_empty())
	var full_ids: Array[String] = []
	for skill in LingpetCatalog.get_active_skill_pool("baekrin"):
		full_ids.append(str(skill.get("id", "")))
	_expect("정의: 전체 풀에는 안장 존재 (판별력)", full_ids.has("baekrin_saddle"))

	var acquirable_ids: Array[String] = []
	for skill in LingpetCatalog.get_acquirable_active_skill_pool("baekrin"):
		acquirable_ids.append(str(skill.get("id", "")))
	_expect("노출: 획득가능 풀에서 안장 제외", not acquirable_ids.has("baekrin_saddle"))
	_expect("노출: 획득가능 풀에 묵린변신 유지", acquirable_ids.has("baekrin_mokrin_transform"))

	# 부화 롤: 레벨 롤이 0이면 active_skill_id가 빈 문자열이 되는 정상 경로가
	# 있으므로 "묵린변신과 동일"이 아니라 "안장을 뽑지 않음"을 반복 단언한다.
	for roll_index in range(40):
		var rolled: Dictionary = LingpetCatalog.pick_skill_loadout("baekrin")
		var rolled_id := str(rolled.get("active_skill_id", ""))
		if rolled_id == "baekrin_saddle":
			_expect("노출: 부화 롤이 안장을 뽑음 (금지) — %d회차" % (roll_index + 1), false)
			return
	_expect("노출: 부화 롤 40회 전부 안장 미출현", true)
	var default_loadout: Dictionary = LingpetCatalog.build_default_loadout("baekrin")
	_expect("노출: 기본 로드아웃 = 묵린변신", str(default_loadout.get("active_skill_id", "")) == "baekrin_mokrin_transform")

	var reconciler := LingpetUnlockLoadoutReconciler.new()
	var primary_candidates: Array[String] = reconciler.get_active_unlock_candidate_ids("baekrin")
	_expect("노출: 1차 해금 후보에 안장 부재 %s" % str(primary_candidates), not primary_candidates.has("baekrin_saddle"))

	var run_state := LingpetGuardianRunState.new()
	var availability: Dictionary = run_state.get_guardian_enhancement_skill_availability("baekrin")
	_expect("노출: 2차 액티브 가용성 false (안장만으로 열리지 않음)", not bool(availability.get("has_second_active", true)))


func _test_shared_cooldown_immunity() -> void:
	# 수신 면역 (persistence 전파 지점) + 정상 전파 대조군.
	var persistence := LingpetCompanionSkillPersistence.new()
	var normal_state := LingpetCompanionSkillState.new()
	var permit_state := LingpetCompanionSkillState.new()
	permit_state.shared_cooldown_immune = true
	persistence.start_shared_cooldown(10.0, [normal_state, permit_state])
	_expect("수신 대조군: 일반 슬롯은 공유 쿨다운 10초 수신", is_equal_approx(float(normal_state.cooldown), 10.0))
	_expect("수신 면역: permit 슬롯은 0초 유지", float(permit_state.cooldown) <= 0.0)

	# 배선: egg가 프로필 경유로 면역 플래그를 동기화한다 (장착 교체 추적).
	var owner := RuntimeOwner.new()
	var registry := NullRegistry.new()
	var saddled: Object = _make_summoned_runtime("baekrin", "baekrin_saddle", owner)
	saddled.update(0.016, owner, registry)
	_expect("배선: 안장 슬롯0 면역 true", bool(saddled._companion_skill_states[0].shared_cooldown_immune))
	var launcher: Object = _make_summoned_runtime("baekrin", "baekrin_mokrin_transform", owner)
	launcher.update(0.016, owner, registry)
	_expect("배선 대조군: 묵린변신 슬롯0 면역 false", not bool(launcher._companion_skill_states[0].shared_cooldown_immune))

	# 시작 면역: 탑승 토글 시퀀스가 공유 쿨다운을 시작하지 않는다.
	var rider: Object = _make_summoned_runtime("baekrin", "baekrin_saddle", owner)
	_expect("시작 면역 사전: 탑승 성립", _mount_via_runtime(rider, owner, registry))
	_expect(
		"시작 면역: 탑승 후 공유 쿨다운 0 유지",
		float(rider._companion_skill_persistence.shared_cooldown) <= 0.0
	)
	# 양성 대조군: 지표 자체는 start_shared_cooldown으로 살아 있다.
	rider._companion_skill_persistence.start_shared_cooldown(10.0, [])
	_expect("시작 면역 지표 생존 (대조군)", float(rider._companion_skill_persistence.shared_cooldown) >= 10.0)


func _test_snapshot_interaction_projection() -> void:
	# 3상태 계약 (양 슬롯 동일 코드 경로 — 슬롯0 3상태 + 슬롯1 기본 상태 봉인).
	var owner := RuntimeOwner.new()
	var registry := NullRegistry.new()

	# 장착·비탑승: available=T / active=F
	var saddled: Object = _make_summoned_runtime("baekrin", "baekrin_saddle", owner)
	saddled.update(0.016, owner, registry)
	var equipped_snap: Dictionary = saddled.get_snapshot()
	_expect("스냅샷: 장착 모델 = interaction_permit", str(equipped_snap.get("companion_skill_activation_model", "")) == "interaction_permit")
	_expect("스냅샷 장착·비탑승: available=true", bool(equipped_snap.get("companion_skill_interaction_available", false)))
	_expect("스냅샷 장착·비탑승: active=false", not bool(equipped_snap.get("companion_skill_interaction_active", true)))
	_expect("스냅샷 슬롯1(미장착): available=false", not bool(equipped_snap.get("companion_skill_interaction_available_1", true)))
	_expect("스냅샷 슬롯1(미장착): active=false", not bool(equipped_snap.get("companion_skill_interaction_active_1", true)))
	_expect("스냅샷 슬롯1 모델 기본값 launch", str(equipped_snap.get("companion_skill_activation_model_1", "")) == "launch")

	# 장착·탑승: T/T
	_expect("스냅샷 사전: 탑승 성립", _mount_via_runtime(saddled, owner, registry))
	var mounted_snap: Dictionary = saddled.get_snapshot()
	_expect("스냅샷 탑승: available=true", bool(mounted_snap.get("companion_skill_interaction_available", false)))
	_expect("스냅샷 탑승: active=true", bool(mounted_snap.get("companion_skill_interaction_active", false)))

	# 철회 직후: F/F (슬롯 교체 → 같은 프레임 하차 → 스냅샷도 함께 떨어진다)
	saddled.debug_grant_and_activate_pet("baekrin", owner, false, "baekrin_mokrin_transform")
	saddled._state = STATE_COMPANION
	saddled._guardian_stowed = false
	saddled._update_companion_motion(0.016, owner, registry)
	var revoked_snap: Dictionary = saddled.get_snapshot()
	_expect("스냅샷 철회: 모델 launch 복귀", str(revoked_snap.get("companion_skill_activation_model", "")) == "launch")
	_expect("스냅샷 철회: available=false", not bool(revoked_snap.get("companion_skill_interaction_available", true)))
	_expect("스냅샷 철회: active=false", not bool(revoked_snap.get("companion_skill_interaction_active", true)))
