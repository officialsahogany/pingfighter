extends SceneTree

# 가변 쿨타임 툴팁 실배선 봉인(WIP 파괴 후 재검수 회귀):
# 플라즈마는 차징 비례 쿨(3~15초, 실효 쿨감 배수 접힘)이지만 이전엔 툴팁이
# 고정 cooldown=8만 읽어 항상 "8초"로 표기됐다. 이제 렌더러
# _compose_cooldown_text가 ①대기 중엔 cooldown_range로 "3~15초" 범위를,
# ②발동 중엔 skill_state가 저장한 이번 시전 총쿨 × 잔여비율을 표시하고,
# 범위가 없는 다른 스킬은 바이트-동일하게 폴백하는지 문자열로 검증한다.
# 렌더러는 RefCounted라 트리/캔버스 없이 순수 호출한다.

const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")

var _failed := false


class FakeCooldownState:
	extends RefCounted

	var total_seconds: float = 0.0

	func _init(next_total: float = 0.0) -> void:
		total_seconds = next_total

	func get_cooldown_total_seconds(_skill_name: String) -> float:
		return total_seconds


func _init() -> void:
	var renderer: Object = SmasherSkillOrbTooltipRenderer.new()

	# 레그 1 — 대기 중 플라즈마: 고정 8이 아니라 3~15 범위를 표기.
	var idle_plasma: String = renderer._compose_cooldown_text(
		{"name": "plasma", "cooldown": 8.0, "cooldown_range": [3.0, 15.0]},
		{},
		8.0,
		0.0
	)
	_expect(idle_plasma.find("3~15") >= 0, "idle plasma tooltip should show the 3~15 cooldown range (got '%s')" % idle_plasma)
	_expect(idle_plasma.find("8") < 0, "idle plasma tooltip must not show the flat fixed 8 (got '%s')" % idle_plasma)

	# 레그 2 — 발동 중 플라즈마: 실제 총쿨(12) × 잔여비율(0.5) = 6.0, 고정 8*0.5=4.0 아님.
	var active_state := FakeCooldownState.new(12.0)
	var active_plasma: String = renderer._compose_cooldown_text(
		{"name": "plasma", "cooldown": 8.0, "cooldown_range": [3.0, 15.0]},
		{"skill_state": active_state},
		8.0,
		0.5
	)
	_expect(active_plasma.find("6.0") >= 0, "active plasma tooltip should show real total(12)*ratio(0.5)=6.0 (got '%s')" % active_plasma)
	_expect(active_plasma.find("4.0") < 0, "active plasma tooltip must not use the fixed 8*0.5=4.0 (got '%s')" % active_plasma)

	# 레그 3 — 범위 없는 스킬(드라이브)은 이전과 바이트-동일해야 한다.
	var idle_drive: String = renderer._compose_cooldown_text({"name": "drive", "cooldown": 12.0}, {}, 12.0, 0.0)
	_expect(idle_drive.find("12") >= 0, "idle non-range skill should show its flat cooldown (got '%s')" % idle_drive)
	_expect(idle_drive.find("~") < 0, "idle non-range skill must not render a range separator (got '%s')" % idle_drive)
	var active_drive: String = renderer._compose_cooldown_text({"name": "drive", "cooldown": 12.0}, {}, 12.0, 0.5)
	_expect(active_drive.find("6.0") >= 0, "active non-range skill should show cooldown*ratio (12*0.5=6.0) (got '%s')" % active_drive)

	# 레그 4 — 발동 중 desync 폴백: 범위는 있으나 skill_state가 총쿨 0이면 cooldown_seconds로 폴백.
	var desync_state := FakeCooldownState.new(0.0)
	var desync_plasma: String = renderer._compose_cooldown_text(
		{"name": "plasma", "cooldown": 8.0, "cooldown_range": [3.0, 15.0]},
		{"skill_state": desync_state},
		8.0,
		0.5
	)
	_expect(desync_plasma.find("4.0") >= 0, "active plasma with no stored total should fall back to cooldown_seconds*ratio (8*0.5=4.0) (got '%s')" % desync_plasma)

	if _failed:
		quit(1)
		return
	print("smasher_plasma_cooldown_tooltip_text_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
