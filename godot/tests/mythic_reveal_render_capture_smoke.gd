extends SceneTree

# 신화퍽 오퍼 리빌·쇼케이스 백플레이트의 "실제 CanvasItem 렌더" 픽셀 씰.
# 실 오퍼 진입점(open_next_choice, jackpot 강제)부터 full draw() 렌더
# fanout까지 관통해 SubViewport(1:1)에서 frame_post_draw 이후 캡처한다.
#  - [A] 신화 오퍼 양성 vs 일반 오퍼 음성: lightburst 전용 밴드(상단)와
#    smoke 전용 스트립(좌측) ROI를 각각 독립 판정(차분 픽셀)
#  - [B] 리빌 수명(MYTHIC_REVEAL_DURATION) 경과 후 재캡처 = 두 ROI 소멸
#    (신화 오퍼당 정확 1회 페이드 — 상시 발동 아님)
#  - [C] 쇼케이스 백플레이트: PNG 소스 픽셀과 캡처 픽셀 직접 대조(절차
#    폴백이 아니라 실제 PNG가 그려짐), inactive 스냅샷 음성 대조
# headless는 렌더 서버가 dummy라 스킵(perk_slot_limit 선례) — 비-headless
# 게이트 실행이 실판정.

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkUnlockShowcase := preload("res://scripts/characters/runtime_perk_unlock_showcase.gd")

const VIEW_SIZE := Vector2(960.0, 720.0)
const CAPTURE_DIR := "res://../.tmp/mythic_reveal_capture"
const REVEAL_AGE := 0.35
# 리빌 판정 밴드(실측 차분 맵 기반): 설명 칼럼 아래~상태 패널 위의
# 중앙 강영역 2조각 — 카드/타이틀/패널 콘텐츠 밖이고 normal·expired
# 음성에서 pulse 노이즈 0이 실측된 영역. 타이틀 아래 상부 밴드는
# 텍스처 투명 가장자리+pulse 위상에 따라 delta 0이 되는 취약 ROI였다
# (실측 폐기). 두 텍스처의 독립 판별은 ROI 분리가 아니라 단독-렌더
# 레그(한쪽을 투명 더미로 교체)로 봉인한다.
const REVEAL_UPPER_BAND := Rect2(250.0, 365.0, 450.0, 50.0)
const REVEAL_LOWER_BAND := Rect2(300.0, 425.0, 300.0, 45.0)

# 기대 캡처 수 독립 선언(코덱스 v2 P2): 오퍼 8장(mythic/burst_only/
# smoke_only/stub/expired/expired_stub/normal/normal_stub)+쇼케이스 3장
# (active/inactive/cold). 실행 수와 저장 수를 각각 이 값과 정확 비교해야
# 캡처 레그 하나가 삭제돼도 10==10으로 조용히 GREEN이 되지 않는다.
const EXPECTED_CAPTURE_COUNT := 11

var _failures: Array[String] = []
var _viewport: SubViewport = null
# 증적 fail-closed(코덱스 v1 P2): 저장 성공한 경로를 모아 종료 전에 파일
# 존재·비어있지 않음·기대 수를 성공 조건으로 묶는다.
var _evidence_paths: Array[String] = []
var _capture_count := 0


class FakeOwner:
	extends Node

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(mapping: Dictionary) -> void:
		instances = mapping

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class ChoiceModalProbe:
	extends Control

	var overlay_renderer: Object = null
	var runtime_state: Object = null
	var catalog: Object = null
	var icon_renderer: Object = null

	func _draw() -> void:
		overlay_renderer.draw(self, runtime_state, catalog, Vector2(960.0, 720.0), icon_renderer)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("mythic_reveal_render_capture_smoke: capture legs skipped under headless display server")
		print("mythic_reveal_render_capture_smoke: ok")
		quit(0)
		return

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	PerkConversionFlags.debug_set_enabled(true)
	await _test_reveal_positive_negative_and_lifetime()
	await _test_showcase_backplate_png_render()
	PerkConversionFlags.debug_set_enabled(false)
	_viewport.queue_free()
	_verify_evidence_files()

	if _failures.is_empty():
		print("mythic_reveal_render_capture_smoke: ok")
		ProjectResourceLoader.clear_caches()
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	ProjectResourceLoader.clear_caches()
	quit(1)


func _capture(probe: Control, slug: String) -> Image:
	_capture_count += 1
	probe.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var viewport_texture := _viewport.get_texture()
	if viewport_texture == null:
		_failures.append("capture '%s': viewport texture unavailable" % slug)
		return null
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		_failures.append("capture '%s': viewport image empty" % slug)
		return null
	# 증적 저장 fail-closed: 디렉터리 생성/저장 실패는 즉시 실패다 — PNG가
	# 하나도 남지 않아도 GREEN이 되는 조용한 증적 소실을 막는다.
	var output_path := ProjectSettings.globalize_path("%s/%s_%d_%d.png" % [CAPTURE_DIR, slug, OS.get_process_id(), Time.get_ticks_usec()])
	var dir_error: int = DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if dir_error != OK:
		_failures.append("capture '%s': evidence dir create failed (%d)" % [slug, dir_error])
		return image
	var save_error: int = image.save_png(output_path)
	if save_error != OK:
		_failures.append("capture '%s': evidence save failed (%d)" % [slug, save_error])
		return image
	_evidence_paths.append(output_path)
	print("mythic_reveal_render_capture_smoke: evidence %s" % output_path)
	return image


func _verify_evidence_files() -> void:
	_expect(
		_capture_count == EXPECTED_CAPTURE_COUNT,
		"the smoke must execute exactly %d captures (got %d) — a dropped capture leg must fail loudly" % [EXPECTED_CAPTURE_COUNT, _capture_count]
	)
	_expect(
		_evidence_paths.size() == EXPECTED_CAPTURE_COUNT,
		"exactly %d evidence PNGs must persist (got %d)" % [EXPECTED_CAPTURE_COUNT, _evidence_paths.size()]
	)
	for path in _evidence_paths:
		if not FileAccess.file_exists(path):
			_failures.append("evidence file missing on disk: %s" % path)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() <= 0:
			_failures.append("evidence file unreadable or empty: %s" % path)
		if file != null:
			file.close()


func _diff_pixels(a: Image, b: Image, roi: Rect2) -> int:
	var count := 0
	for y in range(int(roi.position.y), int(roi.end.y)):
		for x in range(int(roi.position.x), int(roi.end.x)):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			if absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b) > 0.06:
				count += 1
	return count


func _open_offer_probe(mythic: bool) -> ChoiceModalProbe:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	renderer.prewarm_assets()
	var catalog: Object = RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 1.0 if mythic else 0.0
	catalog.dash_token_boost_chances = [0.0, 0.0, 0.0]
	catalog.owned_upgrade_partial_chance = 0.0
	var state: Object = RuntimePerkState.new()
	state.pending_skill_choices = 1
	var owner := FakeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({"runtime_perk_state": state, "runtime_perk_catalog": catalog})
	state.open_next_choice("smasher", catalog, false, owner, registry)
	state.animation_time = REVEAL_AGE
	var probe := ChoiceModalProbe.new()
	probe.size = VIEW_SIZE
	probe.overlay_renderer = renderer
	probe.runtime_state = state
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	probe.set_meta("owner_node", owner)
	_viewport.add_child(probe)
	return probe


func _free_offer_probe(probe: ChoiceModalProbe) -> void:
	var owner: Node = probe.get_meta("owner_node") as Node
	probe.queue_free()
	if owner != null:
		owner.queue_free()


func _transparent_stub_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


func _band_delta(a: Image, b: Image) -> Dictionary:
	return {
		"upper": _diff_pixels(a, b, REVEAL_UPPER_BAND),
		"lower": _diff_pixels(a, b, REVEAL_LOWER_BAND),
	}


func _test_reveal_positive_negative_and_lifetime() -> void:
	# 모든 레그가 "같은 오퍼·같은 시각에서 리빌 텍스처만 투명 더미로 스왑한
	# 짝" 대조를 쓴다 — 카드 내용/위치/선택 글로우/파티클이 완전히 동일해
	# 리빌 기여만 차분에 남는다. 오퍼-간 대조(신화 vs 일반)는 카드 내용
	# 차이만으로 임계를 넘어 배선 제거 반증이 통과하는 공허 씰이었다(실측).
	var mythic_probe := _open_offer_probe(true)
	var mythic_choices: Array = mythic_probe.runtime_state.get_snapshot().get("current_choices", [])
	_expect(
		mythic_probe.overlay_renderer._choices_include_mythic(mythic_choices),
		"jackpot=1.0 real offer must contain mythic cards (fixture guard)"
	)
	var real_smoke: Texture2D = mythic_probe.overlay_renderer._mythic_reveal_smoke_texture
	var real_burst: Texture2D = mythic_probe.overlay_renderer._mythic_reveal_lightburst_texture
	var image_mythic: Image = await _capture(mythic_probe, "offer_mythic_reveal")

	# 단독-렌더: smoke만 더미 → lightburst 기여, lightburst만 더미 → smoke 기여.
	mythic_probe.overlay_renderer._mythic_reveal_smoke_texture = _transparent_stub_texture()
	var image_burst_only: Image = await _capture(mythic_probe, "offer_lightburst_only")
	mythic_probe.overlay_renderer._mythic_reveal_smoke_texture = real_smoke
	mythic_probe.overlay_renderer._mythic_reveal_lightburst_texture = _transparent_stub_texture()
	var image_smoke_only: Image = await _capture(mythic_probe, "offer_smoke_only")
	# 양쪽 더미 = 리빌 원천 차단 기준선(같은 오퍼).
	mythic_probe.overlay_renderer._mythic_reveal_smoke_texture = _transparent_stub_texture()
	var image_stub: Image = await _capture(mythic_probe, "offer_mythic_stub")
	mythic_probe.overlay_renderer._mythic_reveal_lightburst_texture = real_burst
	mythic_probe.overlay_renderer._mythic_reveal_smoke_texture = real_smoke

	# [B] 수명 경과: 같은 오퍼에서 animation_time만 리빌 수명 밖으로.
	mythic_probe.runtime_state.animation_time = 2.4
	var image_expired: Image = await _capture(mythic_probe, "offer_mythic_expired")
	mythic_probe.overlay_renderer._mythic_reveal_lightburst_texture = _transparent_stub_texture()
	mythic_probe.overlay_renderer._mythic_reveal_smoke_texture = _transparent_stub_texture()
	var image_expired_stub: Image = await _capture(mythic_probe, "offer_mythic_expired_stub")
	mythic_probe.overlay_renderer._mythic_reveal_lightburst_texture = real_burst
	mythic_probe.overlay_renderer._mythic_reveal_smoke_texture = real_smoke
	_free_offer_probe(mythic_probe)

	# 일반 오퍼 음성: 같은 오퍼에서 실텍스처 vs 양쪽 더미 — 게이트가 아예
	# 백드롭을 그리지 않으므로 두 캡처가 같아야 한다.
	var normal_probe := _open_offer_probe(false)
	var normal_choices: Array = normal_probe.runtime_state.get_snapshot().get("current_choices", [])
	_expect(
		not normal_probe.overlay_renderer._choices_include_mythic(normal_choices),
		"jackpot=0.0 real offer must stay mythic-free (fixture guard)"
	)
	normal_probe.runtime_state.animation_time = REVEAL_AGE
	var image_normal: Image = await _capture(normal_probe, "offer_normal_no_reveal")
	normal_probe.overlay_renderer._mythic_reveal_lightburst_texture = _transparent_stub_texture()
	normal_probe.overlay_renderer._mythic_reveal_smoke_texture = _transparent_stub_texture()
	var image_normal_stub: Image = await _capture(normal_probe, "offer_normal_stub")
	_free_offer_probe(normal_probe)

	if image_mythic == null or image_stub == null or image_expired == null \
			or image_burst_only == null or image_smoke_only == null or image_expired_stub == null \
			or image_normal == null or image_normal_stub == null:
		_failures.append("offer captures must produce non-empty images")
		return

	# [A] 전체 리빌 양성: 실텍스처-더미 차분이 상/하부 밴드 모두 유의.
	var full_delta := _band_delta(image_mythic, image_stub)
	_expect(int(full_delta["upper"]) > 200, "mythic offer must light the upper reveal band (delta %d px)" % int(full_delta["upper"]))
	_expect(int(full_delta["lower"]) > 200, "mythic offer must light the lower reveal band (delta %d px)" % int(full_delta["lower"]))

	# [A-독립] lightburst 단독·smoke 단독이 각각 실기여를 가진다.
	var burst_delta := _band_delta(image_burst_only, image_stub)
	var smoke_delta := _band_delta(image_smoke_only, image_stub)
	_expect(int(burst_delta["upper"]) + int(burst_delta["lower"]) > 150, "lightburst alone must contribute visible reveal pixels (delta %d px)" % (int(burst_delta["upper"]) + int(burst_delta["lower"])))
	_expect(int(smoke_delta["upper"]) + int(smoke_delta["lower"]) > 150, "smoke alone must contribute visible reveal pixels (delta %d px)" % (int(smoke_delta["upper"]) + int(smoke_delta["lower"])))

	# [A-음성] 일반 오퍼는 게이트가 백드롭을 그리지 않는다(더미 스왑 무영향).
	var normal_delta := _band_delta(image_normal, image_normal_stub)
	_expect(int(normal_delta["upper"]) < 60, "normal offers must not draw the reveal (upper delta %d px)" % int(normal_delta["upper"]))
	_expect(int(normal_delta["lower"]) < 60, "normal offers must not draw the reveal (lower delta %d px)" % int(normal_delta["lower"]))

	# [B] 수명 밖에서 실텍스처 캡처와 더미 캡처가 같아야 한다 = 리빌 기여 0
	# (오퍼당 1회 페이드 — 상시 발동 아님).
	var expired_delta := _band_delta(image_expired, image_expired_stub)
	_expect(int(expired_delta["upper"]) < 60, "after the reveal lifetime the upper band must fade out (delta %d px)" % int(expired_delta["upper"]))
	_expect(int(expired_delta["lower"]) < 60, "after the reveal lifetime the lower band must fade out (delta %d px)" % int(expired_delta["lower"]))


func _showcase_snapshot(active: bool) -> Dictionary:
	return {
		"unlock_showcase": {
			"active": active,
			"age": 1.0,
			"skill_id": "plasma",
			"skill_data": {
				"korean": "플라즈마",
				"color": Color(0.35, 0.75, 1.0),
				"how_to_use": "",
				"motion_hint": "",
			},
			"choice": {"id": "unlock_plasma", "name": "플라즈마", "icon_color": Color(0.35, 0.75, 1.0)},
		},
	}


func _open_showcase_probe(prewarmed: bool) -> ChoiceModalProbe:
	# 실 fanout(코덱스 v1 P2): 실 RuntimePerkState에 쇼케이스 상태를 실어
	# renderer.draw()의 is_unlock_showcase_active() 분기부터 관통한다 —
	# _draw_unlock_showcase 직접 호출은 배선 회귀를 못 잡는다.
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	if prewarmed:
		renderer.prewarm_assets()
	# 실전과 동일하게 choice 흐름 위에서 쇼케이스가 활성화된다 — draw()는
	# is_choice_active() false면 조기 반환하므로 오퍼를 실제로 연다.
	var catalog: Object = RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 0.0
	catalog.dash_token_boost_chances = [0.0, 0.0, 0.0]
	catalog.owned_upgrade_partial_chance = 0.0
	var state: Object = RuntimePerkState.new()
	state.pending_skill_choices = 1
	var owner := FakeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({"runtime_perk_state": state, "runtime_perk_catalog": catalog})
	state.open_next_choice("smasher", catalog, false, owner, registry)
	_expect(bool(state.is_choice_active()), "showcase fixture must sit on an active choice flow (real gate)")
	var helper: Object = RuntimePerkUnlockShowcase.new()
	var apply_result: Dictionary = helper.apply_showcase_state_update(state, _showcase_snapshot(true)["unlock_showcase"])
	_expect(bool(apply_result.get("accepted", false)), "showcase fixture must apply through the real showcase helper")
	_expect(bool(state.is_unlock_showcase_active()), "real state must report the showcase branch active")
	var probe := ChoiceModalProbe.new()
	probe.size = VIEW_SIZE
	probe.overlay_renderer = renderer
	probe.runtime_state = state
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	probe.set_meta("owner_node", owner)
	_viewport.add_child(probe)
	return probe


func _test_showcase_backplate_png_render() -> void:
	var probe := _open_showcase_probe(true)
	var image_active: Image = await _capture(probe, "showcase_backplate")
	# 음성: 실 helper reset으로 쇼케이스 해제 → draw()의 showcase 분기가
	# 아예 타지 않는다.
	var helper: Object = RuntimePerkUnlockShowcase.new()
	helper.reset(probe.runtime_state.unlock_showcase)
	_expect(not bool(probe.runtime_state.is_unlock_showcase_active()), "helper reset must deactivate the showcase branch")
	var image_inactive: Image = await _capture(probe, "showcase_inactive")
	_free_offer_probe(probe)

	# cold 렌더러 픽셀 씰(코덱스 v1 P1): 프리웜 없는 인스턴스는 같은 실
	# fanout에서 PNG 대신 절차 폴백만 그리고, draw 후에도 캐시가 null이다
	# (draw 경로 로드 부재의 픽셀 실증).
	var cold_probe := _open_showcase_probe(false)
	var image_cold: Image = await _capture(cold_probe, "showcase_cold_fallback")
	_expect(cold_probe.overlay_renderer._unlock_showcase_panel_texture == null, "cold renderer draw must not load the backplate texture")
	_expect(cold_probe.overlay_renderer._mythic_reveal_lightburst_texture == null, "cold renderer draw must not load the lightburst texture")
	_free_offer_probe(cold_probe)
	if image_active == null or image_inactive == null or image_cold == null:
		_failures.append("showcase captures must produce non-empty images")
		return

	# 패널 기하 재현(쇼케이스 공식): PNG 종횡비 레이아웃.
	var panel_width: float = min(max(520.0, VIEW_SIZE.x - 84.0), 690.0)
	var panel_height: float = panel_width / (1939.0 / 811.0)
	var panel_rect := Rect2(
		Vector2(floor((VIEW_SIZE.x - panel_width) * 0.5), floor((VIEW_SIZE.y - panel_height) * 0.5)),
		Vector2(panel_width, panel_height)
	)

	# [C] PNG 특징색 판별: 백플레이트 PNG의 레드/골드 장식 프레임은 절차
	# 폴백(네이비 박스+스킬색 파랑 테두리)에 존재하지 않는 고유 특징이다.
	# 텍셀 1:1 대조는 장식 그라데이션의 위치 민감성으로 불안정해(실측
	# 1/3) 특징색 카운트로 판별한다 — 폴백 반증은 PNG 로드 무력화 토글.
	var frame_band := Rect2(panel_rect.position + Vector2(panel_rect.size.x * 0.1, 0.0), Vector2(panel_rect.size.x * 0.8, panel_rect.size.y * 0.14))
	var red_gold := _count_red_gold(image_active, frame_band)
	_expect(red_gold > 150, "the showcase panel must render the backplate PNG's red/gold frame band (got %d px)" % red_gold)
	# cold 렌더러는 같은 밴드에서 PNG 특징색이 없어야 한다(절차 폴백).
	var red_gold_cold := _count_red_gold(image_cold, frame_band)
	_expect(red_gold_cold < 30, "the cold renderer must fall back to the procedural panel without the PNG frame (got %d px)" % red_gold_cold)

	# 음성: inactive 스냅샷은 패널 영역을 그리지 않는다.
	var panel_delta := _diff_pixels(image_active, image_inactive, Rect2(panel_rect.position, Vector2(panel_rect.size.x, panel_rect.size.y * 0.3)))
	_expect(panel_delta > 400, "active-vs-inactive showcase must differ across the panel band (delta %d px)" % panel_delta)


func _count_red_gold(image: Image, band: Rect2) -> int:
	var count := 0
	for y in range(int(band.position.y), int(band.end.y)):
		for x in range(int(band.position.x), int(band.end.x)):
			var p := image.get_pixel(x, y)
			if p.r > 0.45 and p.r > p.b + 0.15 and p.r > p.g + 0.1:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
