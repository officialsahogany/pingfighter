extends SceneTree

# 백린 A5 카탈로그 활성화 씰 — S1 정적 정면 프레젠테이션 + 묵린변신 액티브.
#
# Commit A(정적 모델 인프라)에서 "정적 펫 실존 필요"로 이월된 관통 레그를 여기서
# 봉인한다:
#  - A5 엔트리 검증(파일 실재 포함) · 정적 모델 판정 · 스킬/디스패처 계약
#  - 페이로드 화이트리스트: transform_duration이 카탈로그→launch payload로 전달
#  - D5a/D5c 레이아웃 메타 · 별칭 1×1·1f 메타
#  - 호스트 dismiss 로드 게이트: 정적 펫은 외래(마리보) 폴백 시트를 로드하지 않음
#  - 전투 클릭: false + 무음(스파이 오디오 0콜) — 98f 키 자체가 카탈로그에 없음
#  - Y1: 정보창 Live2D 맵 미등재(정적 원화 자연 폴백 유지)
#  - D15: 백린 활성 상태에서 launch → is_mokrin_transform_active 왕복
#
# 잔여(비봉인, 명시): 클릭 false가 "요약 게이트 중 어느 것"에서 떨어지는지는
# 세분하지 않는다(무음·false 결과 계약만 봉인). 운영 complete_launch 전체 프레임
# 플로는 별도 운영 QA에서 확인.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const PayloadBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")
const AcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
const PanelTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failed := false


class StubCutinRuntime:
	extends RefCounted

	var pet_id := "baekrin"

	func is_acquire_cutin_active() -> bool:
		return true

	func is_acquire_cutin_dismissing() -> bool:
		return true

	func get_acquire_cutin_dismiss_progress() -> float:
		return 0.5

	func get_snapshot() -> Dictionary:
		return {"cutin_pet_id": pet_id, "active_pet_id": pet_id, "pet_id": pet_id}


class HostDrawProbe:
	extends Node2D

	var host: RefCounted = null
	var runtime: RefCounted = null

	func _draw() -> void:
		if host != null and runtime != null:
			host.draw(self, runtime, Vector2(400.0, 300.0))


class SpyAudio:
	extends RefCounted

	var click_calls := 0

	func play_lingpet_click_reaction(_pet_id: String) -> void:
		click_calls += 1


class SpyRegistry:
	extends RefCounted

	var audio: SpyAudio = SpyAudio.new()

	func get_cached_instance(key: String) -> Variant:
		if key == "game_audio":
			return audio
		return null

	func get_instance(key: String) -> Variant:
		return get_cached_instance(key)


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_test_catalog_entry_valid()
	_test_static_model_and_skill_contract()
	_test_payload_whitelist()
	_test_layout_meta()
	_test_panel_live2d_map_unregistered()
	await _test_host_dismiss_load_gate()
	_test_click_sealed_silent()
	_test_launch_roundtrip()
	if _failed:
		printerr("lingpet_baekrin_static_activation_smoke: FAILED")
		quit(1)
		return
	print("lingpet_baekrin_static_activation_smoke: ok")
	quit(0)


func _test_catalog_entry_valid() -> void:
	var entry := LingpetCatalog.get_entry("baekrin")
	_expect("baekrin 엔트리 존재", str(entry.get("id", "")) == "baekrin")
	var issues := LingpetCatalog.validate_entry("baekrin", entry, true)
	_expect("baekrin 검증 이슈 0 (파일 실재 포함): %s" % str(issues), issues.is_empty())


func _test_static_model_and_skill_contract() -> void:
	_expect("baekrin은 static 모델", LingpetCatalog.is_front_presentation_static("baekrin"))
	var skill := LingpetCatalog.get_active_skill("baekrin")
	_expect("스킬 id", str(skill.get("id", "")) == "baekrin_mokrin_transform")
	_expect("runtime_kind = mokrin_transform", str(skill.get("runtime_kind", "")) == "mokrin_transform")
	_expect("쿨다운 40초", is_equal_approx(float(skill.get("cooldown", 0.0)), 40.0))
	_expect("flash style = mokrin_ink", str(skill.get("companion_skill_flash_style", "")) == "mokrin_ink")
	_expect("카드 경로 등재", str(skill.get("card_texture_path", "")).contains("baekrin_mokrin_transform_skillcard"))
	_expect("디스패처 지원", LingpetSkillDispatcher.has_supported_runtime("baekrin_mokrin_transform"))
	_expect(
		"동적 정면 키 부재 (cutin_anim)",
		LingpetCatalog.get_visual_path("baekrin", "cutin_anim") == ""
	)
	_expect(
		"전투 클릭 98f 키 부재",
		LingpetCatalog.get_visual_path("baekrin", "companion_click_reaction_anim") == ""
	)


func _test_payload_whitelist() -> void:
	var skill := LingpetCatalog.get_active_skill("baekrin")
	var payload: Dictionary = PayloadBuilder.new().build(
		skill, "baekrin_mokrin_transform", 1, Vector2(100.0, 600.0), 26.0, null
	)
	_expect(
		"payload.transform_duration = 5.0 (화이트리스트 전달)",
		is_equal_approx(float(payload.get("transform_duration", -1.0)), 5.0)
	)


func _test_layout_meta() -> void:
	var checks := {
		"companion_puppet_control_cols": 6.0,
		"companion_puppet_control_rows": 2.0,
		"companion_puppet_control_frame_count": 12.0,
		"companion_puppet_control_draw_size": 92.0,
		"companion_puppet_control_y_offset_delta": 6.0,
		"companion_walk_cols": 1.0,
		"companion_walk_frame_count": 1.0,
		"companion_strike_frame_count": 1.0,
		"companion_cast_frame_count": 1.0,
		"companion_idle_frame_count": 1.0,
		"companion_move_left_frame_count": 1.0,
		"companion_move_right_frame_count": 1.0,
	}
	for key in checks.keys():
		var got := LingpetCatalog.get_visual_layout_value("baekrin", str(key), -999.0)
		_expect(
			"layout %s = %s (실측 %s)" % [str(key), str(checks[key]), str(got)],
			is_equal_approx(got, float(checks[key]))
		)


func _test_panel_live2d_map_unregistered() -> void:
	var map: Dictionary = PanelTextureLoader.PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID
	_expect("Y1: 패널 Live2D 맵에 baekrin 미등재 (정적 원화 자연 폴백)", not map.has("baekrin"))


func _test_host_dismiss_load_gate() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 300)
	root.add_child(viewport)

	# 정적 펫: dismiss 시트가 null로 남아야 한다 (외래 마리보 폴백 차단).
	var host := AcquireCutinOverlayHost.new()
	var runtime := StubCutinRuntime.new()
	var probe := HostDrawProbe.new()
	probe.host = host
	probe.runtime = runtime
	viewport.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect("정적 펫(baekrin): dismiss 시트 미로드 (null 유지)", host._cutin_dismiss_sheet == null)

	# 대조군(dynamic 마리보): 같은 경로에서 폴백/시트 로드가 일어난다. 스파스 검증
	# 환경에서 imported 텍스처가 없으면 판별 불가라 명시 SKIP.
	var maribo_path := LingpetCatalog.get_visual_path("maribo", "cutin_dismiss_anim")
	var maribo_loadable: bool = ProjectResourceLoader.load_imported_texture(maribo_path, "", "") != null
	if maribo_loadable:
		runtime.pet_id = "maribo"
		host._cutin_dismiss_sheet = null
		probe.queue_redraw()
		await process_frame
		await process_frame
		_expect("대조군(maribo): dismiss 시트 로드됨 (게이트 판별력)", host._cutin_dismiss_sheet != null)
	else:
		print("SKIP: maribo dismiss 시트 임포트 부재(스파스 환경) — 대조군 레그는 풀 저장소에서만")

	viewport.queue_free()
	await process_frame


func _test_click_sealed_silent() -> void:
	var egg := LingpetEggRuntime.new()
	egg.debug_grant_and_activate_pet("baekrin")
	var registry := SpyRegistry.new()
	var began: bool = egg.try_begin_companion_click_reaction(Vector2(100.0, 600.0), registry)
	_expect("전투 클릭: false (정적 모델 — 98f 텍스처 자체가 없음)", began == false)
	_expect("전투 클릭: 무음 (스파이 오디오 0콜, 실측 %d)" % registry.audio.click_calls, registry.audio.click_calls == 0)
	_expect("클릭 상태 비활성 유지", not egg.is_companion_click_reaction_active())


func _test_launch_roundtrip() -> void:
	var egg := LingpetEggRuntime.new()
	egg.debug_grant_and_activate_pet("baekrin")
	_expect("발동 전 비활성", not egg.is_mokrin_transform_active())
	var launched: bool = egg.launch_mokrin_transform_for_tests()
	_expect("백린 활성 상태에서 묵린변신 launch 성공", launched)
	_expect("D15: is_mokrin_transform_active true", egg.is_mokrin_transform_active())
