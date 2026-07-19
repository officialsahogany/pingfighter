extends SceneTree

# 신화퍽 오퍼 리빌 백드롭 복원 씰(오버레이 측 첫 슬라이스).
#  - _choices_include_mythic: 일반 오퍼=false / 신화 포함 오퍼=true(발동 게이트)
#  - prewarm_assets: 리빌 lightburst/smoke + 쇼케이스 백플레이트 텍스처를
#    디스크리트 프리웜으로 채우고, draw 핫패스 게터는 같은 인스턴스를
#    조회만 한다(핫패스 재로드 금지 트랩)
#  - 소스씰: draw 진입부 배선(타이틀 뒤·카드 앞, choices 조기반환 이후 =
#    쇼케이스/스왑/주사위 전용 분기와 배타 — 이중 드로 없음), 백드롭의
#    mythic 게이트+수명(MYTHIC_REVEAL_DURATION) 게이트+절차 폴백,
#    쇼케이스 backplate 배선+PNG 우선/절차 폴백
# 픽셀 실렌더는 mythic_reveal_render_capture_smoke(비-headless)가 봉인한다.

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_choices_include_mythic_gate()
	_test_cold_renderer_getters_never_load()
	_test_prewarm_fills_texture_caches_once()
	_test_draw_wiring_source()
	if _failures.is_empty():
		print("mythic_reveal_backdrop_smoke: ok")
		ProjectResourceLoader.clear_caches()
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	ProjectResourceLoader.clear_caches()
	quit(1)


func _test_choices_include_mythic_gate() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var normal_choices := [
		{"id": "dash_lightweight", "rarity": "common"},
		{"id": "item_luck"},
		"not-a-dictionary",
	]
	_expect(not renderer._choices_include_mythic(normal_choices), "normal offers must not trigger the mythic reveal")
	_expect(not renderer._choices_include_mythic([]), "empty offers must not trigger the mythic reveal")
	var mythic_choices := normal_choices.duplicate()
	mythic_choices.append({"id": "revival", "rarity": "Mythic"})
	_expect(renderer._choices_include_mythic(mythic_choices), "an offer containing a mythic card must trigger the reveal (case-insensitive rarity)")


func _test_cold_renderer_getters_never_load() -> void:
	# 코덱스 v1 P1: 프리웜되지 않은 cold 렌더러(플라자/결과화면 등 별도
	# 인스턴스)의 draw 핫패스 게터는 로드를 트리거하지 않고 null을 돌려
	# 절차 폴백으로 그리게 한다 — 첫 표시 프레임 디스크 로드 히치 차단.
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	_expect(renderer._get_unlock_showcase_panel_texture() == null, "cold getter must not load the showcase backplate")
	_expect(renderer._get_mythic_reveal_lightburst_texture() == null, "cold getter must not load the reveal lightburst")
	_expect(renderer._get_mythic_reveal_smoke_texture() == null, "cold getter must not load the reveal smoke")
	_expect(renderer._unlock_showcase_panel_texture == null, "cold getter must leave the backplate cache empty")
	_expect(renderer._mythic_reveal_lightburst_texture == null, "cold getter must leave the lightburst cache empty")
	_expect(renderer._mythic_reveal_smoke_texture == null, "cold getter must leave the smoke cache empty")
	# 소스씰: draw 경로 어디에도 텍스처 load 호출이 없어야 한다 — 이 파일의
	# ProjectResourceLoader.load_texture 호출은 전부 prewarm_assets 본문 안.
	var source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	var prewarm_body := _extract_function_source(source, "func prewarm_assets(")
	var total_loads := source.count("ProjectResourceLoader.load_texture(")
	var prewarm_loads := prewarm_body.count("ProjectResourceLoader.load_texture(")
	_expect(
		total_loads == prewarm_loads and prewarm_loads >= 3,
		"every load_texture call must live inside prewarm_assets (total %d, prewarm %d)" % [total_loads, prewarm_loads]
	)


func _test_prewarm_fills_texture_caches_once() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	_expect(renderer._mythic_reveal_lightburst_texture == null, "lightburst cache should start empty before prewarm")
	renderer.prewarm_assets()
	_expect(renderer._mythic_reveal_lightburst_texture != null, "prewarm must load the mythic reveal lightburst texture")
	_expect(renderer._mythic_reveal_smoke_texture != null, "prewarm must load the mythic reveal smoke texture")
	_expect(renderer._unlock_showcase_panel_texture != null, "prewarm must load the unlock showcase backplate texture")
	# 핫패스 무로드: prewarm 이후 게터는 캐시된 동일 인스턴스를 돌려준다.
	var burst_a: Texture2D = renderer._get_mythic_reveal_lightburst_texture()
	var burst_b: Texture2D = renderer._get_mythic_reveal_smoke_texture()
	_expect(renderer._get_mythic_reveal_lightburst_texture() == burst_a, "draw-path getter must return the cached lightburst instance (no reload)")
	_expect(renderer._get_mythic_reveal_smoke_texture() == burst_b, "draw-path getter must return the cached smoke instance (no reload)")
	var panel_a: Texture2D = renderer._get_unlock_showcase_panel_texture()
	_expect(renderer._get_unlock_showcase_panel_texture() == panel_a, "draw-path getter must return the cached backplate instance (no reload)")


func _test_draw_wiring_source() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")

	# 진입부 배선: 리빌 백드롭은 choices 조기반환 이후(전용 모달 분기와
	# 배타), 타이틀 뒤·카드 앞에 정확히 1회 배선된다.
	var draw_body := _extract_function_source(source, "func draw(")
	var reveal_call := draw_body.find("_draw_mythic_reveal_backdrop(canvas, runtime_state, choices, view_size,")
	_expect(reveal_call >= 0, "draw() must wire the mythic reveal backdrop")
	_expect(draw_body.count("_draw_mythic_reveal_backdrop(") == 1, "the reveal backdrop must be wired exactly once (no double draw)")
	var choices_guard := draw_body.find("if choices.is_empty():")
	var title_call := draw_body.find("_draw_title(")
	var cards_call := draw_body.find("_draw_cards(")
	var showcase_branch := draw_body.find("is_unlock_showcase_active")
	_expect(
		showcase_branch >= 0 and choices_guard > showcase_branch and reveal_call > choices_guard,
		"the reveal must sit after the exclusive modal branches and the empty-choices guard"
	)
	_expect(title_call >= 0 and cards_call > reveal_call and reveal_call > title_call, "the reveal must draw after the title and before the cards")
	_expect(draw_body.find("hud.perk_overlay.mythic_reveal") >= 0, "the reveal must carry its own perf label")

	# 백드롭 본문: mythic 게이트 + 수명 게이트 + degraded 절차 폴백.
	var backdrop_body := _extract_function_source(source, "func _draw_mythic_reveal_backdrop(")
	_expect(backdrop_body.find("if not _choices_include_mythic(choices):") >= 0, "the backdrop must gate on the mythic-offer check")
	_expect(backdrop_body.find("MYTHIC_REVEAL_DURATION") >= 0, "the backdrop must fade against the reveal lifetime")
	_expect(backdrop_body.find("draw_circle") >= 0, "the backdrop must keep a procedural fallback when the lightburst is missing")

	# 쇼케이스: backplate 배선 + PNG 우선/절차 폴백.
	var showcase_body := _extract_function_source(source, "func _draw_unlock_showcase(")
	_expect(showcase_body.find("_draw_unlock_showcase_backplate(") >= 0, "the unlock showcase must route its panel through the backplate helper")
	var backplate_body := _extract_function_source(source, "func _draw_unlock_showcase_backplate(")
	_expect(backplate_body.find("_get_unlock_showcase_panel_texture()") >= 0, "the backplate must try the PNG texture first")
	_expect(backplate_body.find("draw_texture_rect") >= 0 and backplate_body.find("draw_line") >= 0, "the backplate must keep the procedural fallback after the PNG path")

	# 프리웜 배선: 3종 텍스처 로드가 prewarm_assets 본문에 등재(게터는
	# 조회 전용이므로 로드는 여기서만 일어난다 — cold 씰과 한 쌍).
	var prewarm_body := _extract_function_source(source, "func prewarm_assets(")
	for warm_path in ["UNLOCK_SHOWCASE_PANEL_TEXTURE_PATH", "MYTHIC_REVEAL_LIGHTBURST_PATH", "MYTHIC_REVEAL_SMOKE_PATH"]:
		_expect(prewarm_body.find(warm_path) >= 0, "prewarm_assets must load %s" % warm_path)


func _extract_function_source(source: String, header: String) -> String:
	var start := source.find(header)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + header.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
