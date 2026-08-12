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
	_test_shared_cooldown_store_immunity()
	_test_shared_cooldown_identity_mismatch()
	_test_snapshot_interaction_projection()
	_test_rail_card_surface_interaction_projection()
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
	state.advance(owner, companion_pos, true, false, 0.016, permitted, false, false)
	probe.rmb = true
	var result: Dictionary = state.advance(owner, companion_pos, true, false, 0.016, permitted, false, false)
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
	var held: Dictionary = state.advance(owner, companion_pos, true, false, 0.016, true, false, false)
	_expect("대조군: permit 유지 → 계속 탑승", bool(held.get("mounted", false)))

	# 철회 전이: 같은 프레임 강제 하차 + toggled
	var revoked: Dictionary = state.advance(owner, companion_pos, true, false, 0.016, false, false, false)
	_expect("철회: permit 상실 프레임에 mounted=false", not bool(revoked.get("mounted", true)))
	_expect("철회: toggled=true (강제 하차 전이)", bool(revoked.get("toggled", false)))
	_expect("철회 후 재프레임에도 하차 유지", not bool(state.advance(owner, companion_pos, true, false, 0.016, false, false, false).get("mounted", true)))


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

func _test_rail_card_surface_interaction_projection() -> void:
	# S2-c (리뷰 P2): 레일은 get_rail_card_surface()를 get_snapshot()보다 먼저
	# 읽는다 — 투영이 스냅샷 경로에만 있으면 씰만 GREEN이고 실전 레일에서 죽는다
	# (projection-분기 후처리 탈락 트랩). 두 표면은 같은 정본 헬퍼를 써야 한다.
	var owner := RuntimeOwner.new()
	var registry := NullRegistry.new()
	var saddled: Object = _make_summoned_runtime("baekrin", "baekrin_saddle", owner)
	saddled.update(0.016, owner, registry)

	var permit_keys: Array = [
		"companion_skill_activation_model",
		"companion_skill_interaction_available",
		"companion_skill_interaction_active",
	]
	var surface: Dictionary = saddled.get_rail_card_surface()
	var snapshot: Dictionary = saddled.get_snapshot()
	_expect("레일 표면: 모델 = interaction_permit", str(surface.get("companion_skill_activation_model", "")) == "interaction_permit")
	_expect("레일 표면 비탑승: available=true", bool(surface.get("companion_skill_interaction_available", false)))
	_expect("레일 표면 비탑승: active=false", not bool(surface.get("companion_skill_interaction_active", true)))
	for permit_key in permit_keys:
		for suffix in ["", "_1"]:
			var key := "%s%s" % [str(permit_key), str(suffix)]
			_expect(
				"레일 표면 == 스냅샷 (정본 하나): %s" % key,
				surface.has(key) and snapshot.has(key) and surface[key] == snapshot[key]
			)

	# 캐시 정체성: 같은 프레임 재조회는 캐시 히트, 탑승 토글은 정적 표면까지
	# 재빌드해야 한다 (정적 키에 permit 3키가 없으면 낡은 표면이 서빙된다).
	saddled.reset_runtime_snapshot_cache_counters_for_tests()
	saddled.get_rail_card_surface()
	var static_builds_before: int = int(saddled.get_rail_card_static_surface_build_count_for_tests())
	saddled.get_rail_card_surface()
	_expect(
		"레일 캐시: 같은 프레임 재조회는 정적 표면 재빌드 없음 (대조군)",
		int(saddled.get_rail_card_static_surface_build_count_for_tests()) == static_builds_before
	)
	_expect("레일 캐시 사전: 탑승 성립", _mount_via_runtime(saddled, owner, registry))
	var mounted_surface: Dictionary = saddled.get_rail_card_surface()
	_expect("레일 표면 탑승: active=true", bool(mounted_surface.get("companion_skill_interaction_active", false)))
	_expect(
		"레일 캐시 정체성: 탑승 토글이 정적 표면을 재빌드 (permit 3키가 키에 포함)",
		int(saddled.get_rail_card_static_surface_build_count_for_tests()) > static_builds_before
	)

	# 대조군: 안장 미장착 백린은 레일 표면도 launch / F / F
	var bare: Object = _make_summoned_runtime("baekrin", "baekrin_mokrin_transform", owner)
	bare.update(0.016, owner, registry)
	var bare_surface: Dictionary = bare.get_rail_card_surface()
	_expect("레일 표면 대조군: 미장착 모델 launch", str(bare_surface.get("companion_skill_activation_model", "")) == "launch")
	_expect("레일 표면 대조군: available=false", not bool(bare_surface.get("companion_skill_interaction_available", true)))
	_expect("레일 표면 대조군: active=false", not bool(bare_surface.get("companion_skill_interaction_active", true)))


func _test_shared_cooldown_store_immunity() -> void:
	# 저장 경로 수신 면역 (2026-08-05 리뷰 P1) — 면역 정본은 저장 bool이 아니라
	# 저장된 skill_id에서 파생한다 (슬롯 정체성 함정 방지).
	var persistence := LingpetCompanionSkillPersistence.new()
	persistence.save_current(
		"baekrin",
		[LingpetCompanionSkillState.new(), LingpetCompanionSkillState.new()],
		["baekrin_saddle", "baekrin_mokrin_transform"]
	)

	# 다른 펫의 일반 스킬이 공유 쿨다운 시작 → 저장소 전체 전파
	persistence.start_shared_cooldown(10.0, [LingpetCompanionSkillState.new(), LingpetCompanionSkillState.new()])
	var stored: Dictionary = persistence.state_by_pet_id.get("baekrin", {})
	var saddle_slot: Dictionary = stored.get("slot_0", {}) as Dictionary
	var normal_slot: Dictionary = stored.get("slot_1", {}) as Dictionary
	_expect("저장 면역: 안장 슬롯(저장 id 파생) 0 유지", float(saddle_slot.get("cooldown", -1.0)) <= 0.0)
	_expect("저장 대조군: 일반 슬롯 10초 수신", is_equal_approx(float(normal_slot.get("cooldown", 0.0)), 10.0))

	# 저장 틱 갱신(advance의 shared 바닥 재고정 경로) 후에도 0
	persistence.advance_stored_cooldowns(0.5, "maribo", true, 2)
	stored = persistence.state_by_pet_id.get("baekrin", {})
	saddle_slot = stored.get("slot_0", {}) as Dictionary
	_expect("저장 면역: 틱 갱신 후에도 안장 슬롯 0", float(saddle_slot.get("cooldown", -1.0)) <= 0.0)

	# 동일 로드아웃 복원: 면역 재계산 true + 0 유지 / 일반 슬롯은 수신
	var restored_saddle := LingpetCompanionSkillState.new()
	var restored_second := LingpetCompanionSkillState.new()
	persistence.restore_current("baekrin", [restored_saddle, restored_second], ["baekrin_saddle", "baekrin_mokrin_transform"])
	_expect("복원: 안장 슬롯 0 유지", float(restored_saddle.cooldown) <= 0.0)
	_expect("복원: 면역 재계산 true", bool(restored_saddle.shared_cooldown_immune))
	_expect("복원 대조군: 일반 슬롯은 공유 쿨다운 수신", float(restored_second.cooldown) > 0.0)


func _test_shared_cooldown_identity_mismatch() -> void:
	# 로드아웃 교체 불일치 (2026-08-06 리뷰 최종 P1): 슬롯 상태는 skill_id
	# 정체성에 귀속 — 두 방향 모두 start_shared_cooldown() "실 라이터 관통"으로
	# 봉인한다 (shared_cooldown 직접 대입은 저장 라이터를 우회하는 공허 GREEN).
	# A: permit 저장 → 일반 스킬로 교체 복원 → 면역 false + 공유 쿨다운 적용
	var pa := LingpetCompanionSkillPersistence.new()
	pa.save_current("baekrin", [LingpetCompanionSkillState.new()], ["baekrin_saddle"])
	pa.start_shared_cooldown(10.0, [LingpetCompanionSkillState.new()])
	var swapped_to_normal := LingpetCompanionSkillState.new()
	pa.restore_current("baekrin", [swapped_to_normal], ["baekrin_mokrin_transform"])
	_expect("불일치A: permit→일반 교체 복원 면역 false", not bool(swapped_to_normal.shared_cooldown_immune))
	_expect(
		"불일치A: 진행 중 공유 쿨다운 적용(10초, 실측 %.2f)" % float(swapped_to_normal.cooldown),
		is_equal_approx(float(swapped_to_normal.cooldown), 10.0)
	)

	# B: 일반 저장 → 공유 쿨다운 시작(저장 스냅샷 10초 오염) → permit으로 교체
	#    복원 → 저장된 10초는 이전 스킬 소유물이라 폐기 + 면역 true + 0 유지
	var pb := LingpetCompanionSkillPersistence.new()
	pb.save_current("baekrin", [LingpetCompanionSkillState.new()], ["baekrin_mokrin_transform"])
	pb.start_shared_cooldown(10.0, [LingpetCompanionSkillState.new()])
	var stored_before: Dictionary = pb.state_by_pet_id.get("baekrin", {})
	_expect(
		"불일치B 사전: 저장 스냅샷이 실제로 10초 오염됨 (라이터 관통 증명)",
		is_equal_approx(float((stored_before.get("slot_0", {}) as Dictionary).get("cooldown", 0.0)), 10.0)
	)
	var swapped_to_permit := LingpetCompanionSkillState.new()
	pb.restore_current("baekrin", [swapped_to_permit], ["baekrin_saddle"])
	_expect("불일치B: 일반→permit 교체 복원 면역 true", bool(swapped_to_permit.shared_cooldown_immune))
	_expect(
		"불일치B: 저장 10초 폐기 + 공유 쿨다운 미적용(0초, 실측 %.2f)" % float(swapped_to_permit.cooldown),
		float(swapped_to_permit.cooldown) <= 0.0
	)
