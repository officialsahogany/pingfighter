extends SceneTree

# S2-c 레일 카드 상호작용 권한형 분기 씰 (2026-08-06).
#
# 계약 (docs/lingpet_baekrin_mokrin_slice_plan.md §2-5 · 리뷰 P2):
#  - 레일은 get_rail_card_surface()를 get_snapshot()보다 우선하므로, permit 3키
#    (activation_model / interaction_available / interaction_active)가 그 표면에
#    실려야 한다. egg 쪽 실 표면 투영·캐시 정체성은
#    lingpet_mount_saddle_gate_smoke 가 관통 봉인하고, 이 씰은 그 3키를 받은
#    레일 카드가 라벨·진행도·상태·쿨다운·툴팁을 "같은 하나의 분기"로 처리하는지
#    본다.
#  - 권한형은 충전이 없다: 게이지 100%, 상태 = 탑승(casting) / 사용가능(ready),
#    쿨다운 총량 0, 툴팁 쿨다운 슬롯은 비어 있어야 한다("쿨타임 0초" 금지).
#  - 발동형(launch) 카드는 종전 그대로여야 한다 (대조군).

const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")

var _failed := false


class FakeLingpetRuntime:
	extends RefCounted

	var active := true
	var rail_surface := {}

	func is_companion_active(_pet_id: String = "") -> bool:
		return active

	func is_maribo_companion_active() -> bool:
		return active

	func get_rail_card_surface() -> Dictionary:
		return rail_surface


class FakeRegistry:
	extends RefCounted

	var runtime: Object = null

	func get_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			return runtime
		return null


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_test_permit_entry_states()
	_test_launch_entry_unchanged()
	_test_permit_tooltip_has_no_cooldown()
	_test_meta_line_drops_empty_cooldown()
	_test_stage_tooltips_use_shared_meta_line()
	_test_permit_trigger_label_localized()

	if _failed:
		call_deferred("_quit_with_code", 1)
	else:
		print("lingpet_rail_card_permit_branch_smoke: ok")
		call_deferred("_quit_with_code", 0)


func _quit_with_code(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


# 슬롯0 = 권한형(안장), 슬롯1 = 발동형(묵린변신) 이중 슬롯 스냅샷.
func _make_surface(mounted: bool) -> Dictionary:
	return {
		"companion_skill_id": "baekrin_saddle",
		"companion_skill_name": "백린의안장",
		"companion_skill_description": "우클릭으로 백린에 올라타거나 내립니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/baekrin_mokrin_transform_skillcard_v1.png",
		"companion_skill_cooldown": 0.0,
		"companion_skill_cooldown_duration": 0.0,
		"companion_skill_ready": true,
		"companion_skill_flash_ratio": 0.0,
		"companion_skill_winding_up": false,
		"companion_skill_activation_model": "interaction_permit",
		"companion_skill_interaction_available": true,
		"companion_skill_interaction_active": mounted,
		"companion_skill_id_1": "baekrin_mokrin_transform",
		"companion_skill_name_1": "묵린변신",
		"companion_skill_description_1": "5초 동안 묵린으로 변신합니다.",
		"companion_skill_card_path_1": "res://assets/sprites/lingpet/baekrin_mokrin_transform_skillcard_v1.png",
		"companion_skill_cooldown_1": 20.0,
		"companion_skill_cooldown_duration_1": 40.0,
		"companion_skill_ready_1": false,
		"companion_skill_flash_ratio_1": 0.0,
		"companion_skill_winding_up_1": false,
		"companion_skill_activation_model_1": "launch",
		"companion_skill_interaction_available_1": false,
		"companion_skill_interaction_active_1": false,
	}


func _build_entries(mounted: bool) -> Array:
	var runtime := FakeLingpetRuntime.new()
	runtime.rail_surface = _make_surface(mounted)
	var registry := FakeRegistry.new()
	registry.runtime = runtime
	return LingpetRailCard.build_entries(registry)


func _test_permit_entry_states() -> void:
	var toggle_label: String = LingpetRailCard.localized_permit_trigger_label()

	# ① 장착·비탑승: 사용 가능 = ready, 게이지는 항상 가득(충전 개념 없음)
	var idle_entries := _build_entries(false)
	_expect("권한형 이중 슬롯: 카드 2장", idle_entries.size() == 2)
	if idle_entries.size() != 2:
		return
	var permit: Dictionary = idle_entries[0]
	_expect("권한형 라벨: 트리거 타입 interaction", str(permit.get("trigger_type", "")) == "interaction")
	_expect("권한형 라벨: 트리거 라벨 = 토글(자동 아님)", str(permit.get("trigger_label", "")) == toggle_label and str(permit.get("trigger_label", "")) != "자동")
	_expect(
		"권한형 진행도: 100%% (실측 %.2f)" % float(permit.get("progress", -1.0)),
		absf(float(permit.get("progress", -1.0)) - 1.0) <= 0.001
	)
	_expect("권한형 상태: 비탑승 = ready", str(permit.get("status", "")) == "ready")
	_expect("권한형 상태: 비탑승 ready 플래그 true", bool(permit.get("ready", false)))
	_expect(
		"권한형 쿨다운: 총량 0 (실측 %.2f)" % float(permit.get("cooldown_total", -1.0)),
		absf(float(permit.get("cooldown_total", -1.0))) <= 0.001
	)
	_expect("권한형 쿨다운: 잔여 0", absf(float(permit.get("cooldown_remaining", -1.0))) <= 0.001)
	_expect("권한형 엔트리가 activation_model을 실어 툴팁이 같은 분기를 쓴다", str(permit.get("activation_model", "")) == "interaction_permit")
	_expect("권한형 엔트리: interaction_active=false", not bool(permit.get("interaction_active", true)))

	# ② 탑승 중: casting (draw_card 가 활성 펄스 + 가득 채운 게이지로 그린다)
	var mounted_entries := _build_entries(true)
	_expect("권한형 상태: 탑승 = casting", str((mounted_entries[0] as Dictionary).get("status", "")) == "casting")
	_expect("권한형 상태: 탑승 시 ready 플래그 false", not bool((mounted_entries[0] as Dictionary).get("ready", true)))
	_expect(
		"권한형 진행도: 탑승 중에도 100%",
		absf(float((mounted_entries[0] as Dictionary).get("progress", -1.0)) - 1.0) <= 0.001
	)
	_expect("권한형 엔트리: 탑승 시 interaction_active=true", bool((mounted_entries[0] as Dictionary).get("interaction_active", false)))


func _test_launch_entry_unchanged() -> void:
	# 대조군: 같은 스냅샷의 슬롯1(발동형)은 종전 계약 그대로여야 한다.
	var entries := _build_entries(true)
	if entries.size() != 2:
		_expect("대조군: 슬롯1 카드 존재", false)
		return
	var launch: Dictionary = entries[1]
	_expect("대조군 발동형: 트리거 자동 유지", str(launch.get("trigger_label", "")) == "자동" and str(launch.get("trigger_type", "")) == "auto")
	_expect(
		"대조군 발동형: 진행도 = 1 - 20/40 (실측 %.2f)" % float(launch.get("progress", -1.0)),
		absf(float(launch.get("progress", -1.0)) - 0.5) <= 0.01
	)
	_expect("대조군 발동형: 상태 charging", str(launch.get("status", "")) == "charging")
	_expect("대조군 발동형: 쿨다운 총량 40 유지", absf(float(launch.get("cooldown_total", 0.0)) - 40.0) <= 0.01)
	_expect("대조군 발동형: activation_model launch", str(launch.get("activation_model", "")) == "launch")


func _test_permit_tooltip_has_no_cooldown() -> void:
	var entries := _build_entries(false)
	if entries.size() != 2:
		_expect("툴팁 사전: 카드 2장", false)
		return
	var permit_info: Dictionary = LingpetRailCard.tooltip_info(entries[0] as Dictionary)
	_expect("권한형 툴팁: 이름 = 카드 라벨", str(permit_info.get("name", "")) == "백린의안장")
	_expect("권한형 툴팁: 트리거 = 토글", str(permit_info.get("trigger", "")) == LingpetRailCard.localized_permit_trigger_label())
	_expect(
		"권한형 툴팁: cooldown_seconds 0 (40초 폴백 금지, 실측 %.2f)" % float(permit_info.get("cooldown_seconds", -1.0)),
		absf(float(permit_info.get("cooldown_seconds", -1.0))) <= 0.001
	)
	_expect("권한형 툴팁: 쿨다운 문자열 비어있음('쿨타임 0초' 금지)", str(permit_info.get("cooldown", "x")) == "")
	_expect("권한형 툴팁: 설명 = 카드 설명", str(permit_info.get("description", "")) == "우클릭으로 백린에 올라타거나 내립니다.")

	# 대조군: 발동형 툴팁은 쿨다운 초·문자열을 그대로 유지한다.
	var launch_info: Dictionary = LingpetRailCard.tooltip_info(entries[1] as Dictionary)
	_expect("대조군 툴팁: cooldown_seconds 40 유지", absf(float(launch_info.get("cooldown_seconds", 0.0)) - 40.0) <= 0.01)
	_expect("대조군 툴팁: 쿨다운 문자열 유지", not str(launch_info.get("cooldown", "")).is_empty())
	_expect("대조군 툴팁: 트리거 자동 유지", str(launch_info.get("trigger", "")) == "자동")


func _test_meta_line_drops_empty_cooldown() -> void:
	# 쿨다운이 빈 카드에서 " · " 꼬리표가 남으면 안 된다.
	_expect(
		"메타라인: 쿨다운 비면 트리거만",
		BossSkillCardHudSpec.build_meta_line("토글", "", " · ") == "토글"
	)
	_expect(
		"메타라인: 둘 다 있으면 구분자로 결합 (대조군)",
		BossSkillCardHudSpec.build_meta_line("자동", "쿨타임 40초", " · ") == "자동 · 쿨타임 40초"
	)
	_expect(
		"메타라인: 트리거만 비면 쿨다운만",
		BossSkillCardHudSpec.build_meta_line("", "쿨타임 40초", " / ") == "쿨타임 40초"
	)


func _test_stage_tooltips_use_shared_meta_line() -> void:
	# 자체 툴팁을 그리는 두 스테이지가 공용 메타라인 규칙을 우회하면 권한형 카드에
	# "쿨타임 0초" / "토글 / " 가 다시 살아난다.
	var stage1_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
	var stage5_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
	_expect("스테이지1 툴팁이 공용 메타라인 사용", stage1_source.find("BossSkillCardHudSpec.build_meta_line(") >= 0)
	_expect("스테이지1 툴팁에 0초 가드 존재", stage1_source.find("if cooldown_seconds <= 0.0:") >= 0)
	_expect("스테이지1 툴팁의 무조건 결합 제거", stage1_source.find("\"%s · %s\" % [trigger_text, cooldown_text]") < 0)
	_expect("스테이지5 툴팁이 공용 메타라인 사용", stage5_source.find("BossSkillCardHudSpec.build_meta_line(") >= 0)
	_expect("스테이지5 툴팁의 무조건 결합 제거", stage5_source.find("\"%s / %s\" % [trigger_text, cooldown_text]") < 0)


func _test_permit_trigger_label_localized() -> void:
	var label: String = LingpetRailCard.localized_permit_trigger_label()
	_expect("토글 라벨 비어있지 않음", not label.strip_edges().is_empty())
	var rail_source: String = FileAccess.get_file_as_string("res://scripts/stages/common/lingpet_rail_card.gd")
	var body_start: int = rail_source.find("static func localized_permit_trigger_label(")
	_expect("토글 라벨 헬퍼 존재", body_start >= 0)
	if body_start < 0:
		return
	var body: String = rail_source.substr(body_start)
	var next_func: int = body.find("\nstatic func ", 1)
	if next_func > 0:
		body = body.substr(0, next_func)
	for expected in ["Toggle", "Alternar", "Переключение", "切换", "切り替え", "토글"]:
		_expect("토글 라벨 다국어 커버: %s" % expected, body.find(expected) >= 0)
