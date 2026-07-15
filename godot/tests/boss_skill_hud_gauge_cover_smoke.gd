extends SceneTree

# 스킬카드 게이지 cover-crop 통일(수정14 복원) 봉인.
# 1) 공용 BossSkillCardHudSpec.draw_skillcard_gauge_fill의 cover-crop 수학을
#    유닛으로 검증(극단 종횡비에서 중앙 크롭 — stretch였다면 소스 전체 사용).
# 2) 전 스킬카드 레일 소비자(스테이지 1~7 보스 HUD + 공용 링펫 레일 카드)가
#    공용 콜을 사용하고 stretch 잔재가 없는지 콜-사이트 커버리지로 봉인.
#    (헤드리스는 픽셀 검증이 불가하므로 '공용 함수 유닛 + 콜 커버리지' 조합이
#    이 회귀 클래스(콜 소실 → 카드 찌그러짐)의 실효 씰이다. 새 스테이지
#    레일 렌더러를 추가하면 아래 목록에도 추가할 것 — stage8은 WIP라 제외.)

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

const GAUGE_CALL := "BossSkillCardHudSpec.draw_skillcard_gauge_fill("
# 게이지 함수 본문에서 canvas.draw_texture_rect / draw_texture_rect_region을
# 직접 부르면 stretch 회귀(공용 helper 밖 draw). 본문 한정 추출이라 '함수
# 밖' 토큰의 공허 통과는 차단되지만, 여전히 문자열 검사이므로 본문 안의
# 주석 처리된 호출이나 도달 불가 분기까지 판별하지는 못한다(그 잔여 위험은
# cover-crop 수학 유닛 + 픽셀 QA가 보완).
const DIRECT_TEXTURE_DRAW := "draw_texture_rect"
const RAIL_RENDERER_SPECS := [
	{"path": "res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/stage1/stage1_gaksital_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd", "signature": "func _draw_skillcard_gauge("},
	{"path": "res://scripts/stages/common/lingpet_rail_card.gd", "signature": "static func _draw_gauge("},
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_cover_crop_math()
	_verify_rail_renderer_coverage()

	if _failures.is_empty():
		print("boss_skill_hud_gauge_cover_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_cover_crop_math() -> void:
	# 4:1 가로 소스 → 1:1 타깃: 중앙 1:1만 크롭(폭=소스높이), X는 중앙 정렬.
	var wide := ImageTexture.create_from_image(Image.create(400, 100, false, Image.FORMAT_RGBA8))
	var crop: Rect2 = BossSkillCardHudSpec._cover_crop_source(wide, Rect2(Vector2.ZERO, wide.get_size()), Vector2(100.0, 100.0))
	_expect(is_equal_approx(crop.size.x, 100.0) and is_equal_approx(crop.size.y, 100.0), "cover-crop should trim a 4:1 source to a centered 1:1 window (got %s)" % crop)
	_expect(is_equal_approx(crop.position.x, 150.0), "cover-crop should center the 4:1 trim horizontally (got %s)" % crop)
	# 1:4 세로 소스 → 1:1 타깃: 세로 크롭.
	var tall := ImageTexture.create_from_image(Image.create(100, 400, false, Image.FORMAT_RGBA8))
	crop = BossSkillCardHudSpec._cover_crop_source(tall, Rect2(Vector2.ZERO, tall.get_size()), Vector2(100.0, 100.0))
	_expect(is_equal_approx(crop.size.y, 100.0) and is_equal_approx(crop.position.y, 150.0), "cover-crop should trim a 1:4 source to a centered vertical window (got %s)" % crop)
	# 아틀라스 서브-rect 소스도 그 안에서만 크롭.
	var atlas_source := Rect2(Vector2(200.0, 0.0), Vector2(200.0, 100.0))
	crop = BossSkillCardHudSpec._cover_crop_source(wide, atlas_source, Vector2(100.0, 100.0))
	_expect(crop.position.x >= atlas_source.position.x and crop.end.x <= atlas_source.end.x, "cover-crop must stay inside the atlas cell source rect (got %s)" % crop)


func _verify_rail_renderer_coverage() -> void:
	for spec in RAIL_RENDERER_SPECS:
		var path: String = str(spec.get("path", ""))
		var script := load(path) as GDScript
		if script == null:
			_failures.append("rail renderer script should load: %s" % path)
			continue
		var body: String = SourceContractFunctionBody.extract(script.source_code, str(spec.get("signature", "")))
		if body == "":
			_failures.append("%s must keep its gauge draw function (%s)" % [path, spec.get("signature", "")])
			continue
		_expect(body.contains(GAUGE_CALL), "%s gauge body must draw through the shared cover-crop helper" % path)
		_expect(
			not body.contains(DIRECT_TEXTURE_DRAW),
			"%s gauge body must not draw the card texture directly (stretch regression class)" % path
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
