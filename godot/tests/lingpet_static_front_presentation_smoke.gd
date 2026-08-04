extends SceneTree

# S1 정적 정면 프레젠테이션 모델(front_presentation_model="static") 씰 — Commit A 인프라.
#
# 계약 (2026-08-04 사용자 확정):
#  - 정적 모델은 동적 정면 3키(cutin_anim/cutin_dismiss_anim/click_reaction_anim)를
#    요구하지 않는다. cutin_art는 계속 필수.
#  - 정적 모델이 그 키(+companion_click_reaction_anim)를 정의하면 검증 실패다
#    (하드코딩 그리드 소비자 오슬라이스 위장 금지, fail-closed).
#  - 기존 펫(dynamic 기본값) 검증은 불변 — 회귀 레그로 봉인.
#  - 획득 퇴장: 퇴장 시트가 없으면 정적 원화가 같은 축소·페이드 엔벨로프로
#    마지막까지 페이드된다(급소멸 금지) — SubViewport 픽셀 캡처로 검증.
#
# 정적 펫이 카탈로그에 실존해야 하는 레그(호스트 dismiss 로드 게이트의
# is_front_presentation_static 관통, egg runtime 클릭 false·미소비·무음)는
# 백린 A5 활성 커밋의 활성화 씰에서 봉인한다 — 여기서는 인프라만.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const AcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")

var _failed := false


class DismissProbe:
	extends Node2D

	var host: RefCounted = null
	var progress := 0.5
	var view := Vector2(400.0, 300.0)

	func _draw() -> void:
		if host != null:
			host._draw_dismiss_action(self, view, progress)


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _has_issue(issues: Array[String], needle: String) -> bool:
	for issue in issues:
		if str(issue).contains(needle):
			return true
	return false


func _make_static_entry() -> Dictionary:
	return {
		"id": "staticprobe",
		"display_name": "정적 프로브",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {},
		"front_presentation_model": "static",
		"stats": {
			"patrol_speed_default": 150.0,
			"patrol_speed_min": 100.0,
			"patrol_speed_max": 200.0,
			"catch_width": 80.0,
			"catch_height": 50.0,
			"defense_rate": 0.1,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": LingpetCatalog.SHARED_GUARDIAN_SPIRIT_EGG_PATH,
			"egg_crack_1": LingpetCatalog.SHARED_GUARDIAN_SPIRIT_EGG_CRACK_1_PATH,
			"egg_crack_2": LingpetCatalog.SHARED_GUARDIAN_SPIRIT_EGG_CRACK_2_PATH,
			"companion_walk": "res://assets/sprites/lingpet/koyora_companion_idle.png",
			"companion_strike": "res://assets/sprites/lingpet/koyora_companion_idle.png",
			"companion_cast": "res://assets/sprites/lingpet/koyora_companion_idle.png",
			"cutin_art": "res://assets/sprites/lingpet/maribo_cutin_art.png",
		},
		"active_skill": {
			"id": "staticprobe_skill",
			"runtime_kind": "puppet_grab",
			"name": "프로브 스킬",
			"description": "검증 픽스처",
			"cooldown": 10.0,
			"card_texture_path": "res://assets/sprites/lingpet/koyora_puppet_control_skillcard_imagegen_v1.png",
		},
		"effect_text": "검증 픽스처",
	}


func _run() -> void:
	_test_static_exempts_dynamic_front_keys()
	_test_static_still_requires_cutin_art()
	_test_static_forbids_dynamic_key_definitions()
	_test_unknown_model_rejected()
	_test_dynamic_pets_unchanged()
	_test_static_helper_defaults()
	await _test_dismiss_static_art_fades_to_end()
	if _failed:
		printerr("lingpet_static_front_presentation_smoke: FAILED")
		quit(1)
		return
	print("lingpet_static_front_presentation_smoke: ok")
	quit(0)


func _test_static_exempts_dynamic_front_keys() -> void:
	var issues := LingpetCatalog.validate_entries({"staticprobe": _make_static_entry()}, false)
	_expect("static: cutin_anim 미요구", not _has_issue(issues, "cutin_anim"))
	_expect("static: cutin_dismiss_anim 미요구", not _has_issue(issues, "cutin_dismiss_anim"))
	_expect("static: click_reaction_anim 미요구", not _has_issue(issues, "click_reaction_anim"))
	_expect("static: 모델 자체는 유효", not _has_issue(issues, "front_presentation_model"))
	_expect("static: staticprobe 잔여 이슈 0", not _has_issue(issues, "staticprobe"))


func _test_static_still_requires_cutin_art() -> void:
	var entry := _make_static_entry()
	(entry["visuals"] as Dictionary).erase("cutin_art")
	var issues := LingpetCatalog.validate_entries({"staticprobe": entry}, false)
	_expect("static: cutin_art는 계속 필수", _has_issue(issues, "missing visuals.cutin_art"))


func _test_static_forbids_dynamic_key_definitions() -> void:
	var entry := _make_static_entry()
	(entry["visuals"] as Dictionary)["cutin_anim"] = "res://assets/sprites/lingpet/maribo_cutin_art.png"
	var issues := LingpetCatalog.validate_entries({"staticprobe": entry}, false)
	_expect("static: cutin_anim 정의 = 위장 금지 실패", _has_issue(issues, "must not define visuals.cutin_anim"))
	var entry2 := _make_static_entry()
	(entry2["visuals"] as Dictionary)["companion_click_reaction_anim"] = "res://assets/sprites/lingpet/maribo_cutin_art.png"
	var issues2 := LingpetCatalog.validate_entries({"staticprobe": entry2}, false)
	_expect(
		"static: companion_click_reaction_anim 정의도 금지",
		_has_issue(issues2, "must not define visuals.companion_click_reaction_anim")
	)


func _test_unknown_model_rejected() -> void:
	var entry := _make_static_entry()
	entry["front_presentation_model"] = "statik"
	var issues := LingpetCatalog.validate_entries({"staticprobe": entry}, false)
	_expect("unknown 모델 문자열 거부", _has_issue(issues, "unknown front_presentation_model"))


func _test_dynamic_pets_unchanged() -> void:
	var koyora := LingpetCatalog.get_entry("koyora")
	var baseline := LingpetCatalog.validate_entry("koyora", koyora, false)
	_expect("dynamic(koyora): 정적 모델 도입 후에도 이슈 0", baseline.is_empty())
	var stripped := LingpetCatalog.get_entry("koyora")
	(stripped["visuals"] as Dictionary).erase("cutin_anim")
	var issues := LingpetCatalog.validate_entry("koyora", stripped, false)
	_expect("dynamic(koyora): cutin_anim은 여전히 필수", _has_issue(issues, "missing visuals.cutin_anim"))


func _test_static_helper_defaults() -> void:
	_expect("koyora는 dynamic", not LingpetCatalog.is_front_presentation_static("koyora"))
	_expect("미지 펫도 dynamic 폴백", not LingpetCatalog.is_front_presentation_static("no_such_pet_id"))


func _test_dismiss_static_art_fades_to_end() -> void:
	# 표준 러너는 더미 렌더링 서버라 SubViewport 픽셀 캡처가 불가능하다. 여기서는
	# 정적 원화 분기가 실제 _draw 경로에서 SCRIPT ERROR 없이 끝까지 실행됨(엔진
	# 오류는 러너가 실패로 승격)을 관통 검증하고, 픽셀 증명(중반 가시·페이드 구간
	# 잔존·종단 0·대조군 0)은 비헤드리스 lingpet_static_front_dismiss_visual_qa.gd가
	# 소유한다 — 구조 GREEN ≠ 픽셀 트랩을 알고 분리한 것.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 300)
	root.add_child(viewport)

	var art_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	art_image.fill(Color(0.0, 1.0, 0.0, 1.0))
	var art_texture := ImageTexture.create_from_image(art_image)

	var host := AcquireCutinOverlayHost.new()
	host._cutin_dismiss_sheet = null
	host._cutin_art = art_texture

	var probe := DismissProbe.new()
	probe.host = host
	viewport.add_child(probe)

	for progress in [0.5, 0.85, 0.995]:
		probe.progress = float(progress)
		probe.queue_redraw()
		await process_frame
	_expect("퇴장 정적 원화 분기: 시트 null + 원화 주입으로 _draw 관통 실행", true)

	host._cutin_art = null
	probe.progress = 0.5
	probe.queue_redraw()
	await process_frame
	_expect("퇴장 대조군(원화 null)도 _draw 관통 실행", true)

	viewport.queue_free()
	await process_frame
