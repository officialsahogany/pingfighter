extends SceneTree

# 신령환(aipill) = 호신령 빙의 연출 봉인.
#
# 구 연출(시안 9슬라이스 글리치 + "AI SYSTEM" 라벨)은 환격전 리브랜딩 이후
# 픽션과 정반대였다("해킹된 로봇" vs "호신령이 몸을 대신 움직인다").
# 이 스모크가 지키는 것은 "예쁘냐"가 아니라 **조종당함이 코드 계약으로
# 남아 있느냐**다:
#   - 인과 역전(신령이 몸보다 3프레임 먼저 반응)
#   - 선행 잔상이 대시와 배타
#   - phase TAU 랩에서 전 레이어가 동시에 튀지 않음(정수 배음만)
#   - 드로우 슬롯 상한(상시-가시성 절차 드로우 회귀 방지)
#   - 구 사이버 어휘가 소스에서 완전히 사라졌는지

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")

const PLAYER_RECT := Rect2(Vector2(300.0, 612.0), Vector2(160.0, 160.0))
const NOW_MSEC := 1234.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_inactive_plan_is_empty()
	_verify_stationary_slot_budget()
	_verify_lead_afterimage_requires_movement()
	_verify_lead_afterimage_is_dash_exclusive()
	_verify_guard_flash_causal_inversion()
	_verify_guard_flash_slot_budget()
	_verify_lod_ladder()
	_verify_phase_wrap_is_continuous()
	_verify_lead_offset_self_heals()
	_verify_legacy_glitch_vocabulary_removed()

	if _failures.is_empty():
		print("aipill_possession_visual_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _base_context(active: bool) -> Dictionary:
	return {
		"active_item_aipill_active": active,
		"active_item_aipill_phase": 0.0,
		"active_item_aipill_flash_timer_frames": 0.0,
		"active_item_aipill_flash_initial_frames": 12.0,
		"ball_active": true,
		"ball_pos": Vector2(400.0, 380.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"play_left": 0.0,
		"play_right": 760.0,
	}


func _plan(context: Dictionary, lod: int = 0, lead_dx: float = 0.0) -> Dictionary:
	return Stage1PlayerActorRenderer.build_possession_plan(context, PLAYER_RECT, NOW_MSEC, lod, lead_dx)


func _verify_inactive_plan_is_empty() -> void:
	var plan: Dictionary = _plan(_base_context(false))
	_expect(not bool(plan.get("active", true)), "inactive aipill should produce an inactive possession plan")
	_expect(int(plan.get("draw_count", -1)) == 0, "inactive possession plan should draw nothing")
	_expect(plan.get("motes", []).is_empty(), "inactive possession plan should carry no motes")


# 정지 상태 = 배경판 1 + 부적 1 + 광점 2 + 정수리 1 + 라벨 2 + 조준선 1 = 8.
# 구 연출의 상시 비용(9 슬라이스 + draw_string 2 = 11)보다 낮아야 한다.
func _verify_stationary_slot_budget() -> void:
	var plan: Dictionary = _plan(_base_context(true))
	_expect(bool(plan.get("active", false)), "active aipill should produce an active possession plan")
	_expect(int(plan.get("draw_count", -1)) == 8, "stationary possession plan should stay at 8 draw slots, got %d" % int(plan.get("draw_count", -1)))
	_expect(plan.get("motes", []).size() == 2, "possession plan should descend exactly 2 spirit motes at LOD0")
	_expect(bool(plan.get("sight", {}).get("enabled", false)), "possession plan should mark the auto-guard intercept")
	_expect(plan.get("meridians", []).is_empty(), "possession plan should keep zero persistent thread shapes outside the guard flash")
	_expect(not bool(plan.get("lead", {}).get("enabled", true)), "stationary possession plan should not draw a lead afterimage")


# 신탁 조준선은 자동 가드가 실제로 노리는 지점(공 x 를 play 범위로 클램프)에
# 서야 한다 — active_item_aipill_behavior.apply_player_control 과 같은 식.
func _verify_lead_afterimage_requires_movement() -> void:
	var plan: Dictionary = _plan(_base_context(true), 0, 12.0)
	var lead: Dictionary = plan.get("lead", {})
	_expect(bool(lead.get("enabled", false)), "moving possession plan should lead the body with an afterimage")
	_expect(int(plan.get("draw_count", -1)) == 9, "moving possession plan should add exactly one draw slot")
	var offset: Vector2 = lead.get("offset", Vector2.ZERO)
	_expect(offset.x > 0.0, "lead afterimage should sit ahead in the travel direction")
	_expect(is_equal_approx(offset.y, 0.0), "lead afterimage must stay horizontal (no rise / scale)")

	var far_plan: Dictionary = _plan(_base_context(true), 0, 900.0)
	var far_offset: Vector2 = far_plan.get("lead", {}).get("offset", Vector2.ZERO)
	_expect(far_offset.x <= 22.0 + 0.001, "lead afterimage offset must stay clamped, got %f" % far_offset.x)


# 대시 잔상(최대 3개, 수평 산개)과 겹치면 판독이 붕괴한다.
func _verify_lead_afterimage_is_dash_exclusive() -> void:
	for dash_key in ["dash_active", "player_dashing", "dash_recovering"]:
		var context: Dictionary = _base_context(true)
		context[dash_key] = true
		var plan: Dictionary = _plan(context, 0, 12.0)
		_expect(
			not bool(plan.get("lead", {}).get("enabled", true)),
			"lead afterimage must be suppressed while %s is set" % dash_key
		)


# 가드 12프레임 중 12→10f 는 신령측만 반응하고 몸은 가만히 있어야 한다.
func _verify_guard_flash_causal_inversion() -> void:
	var early: Dictionary = _base_context(true)
	early["active_item_aipill_flash_timer_frames"] = 11.0
	var early_plan: Dictionary = _plan(early)
	_expect(float(early_plan.get("spirit_ease", 0.0)) > 0.8, "spirit side should react immediately on the guard frame")
	_expect(
		is_equal_approx(float(early_plan.get("body_ease", 1.0)), 0.0),
		"body side must NOT react during the first 3 guard frames (causal inversion)"
	)

	var late: Dictionary = _base_context(true)
	late["active_item_aipill_flash_timer_frames"] = 8.0
	var late_plan: Dictionary = _plan(late)
	_expect(float(late_plan.get("spirit_ease", 0.0)) > 0.0, "spirit side should still be lit later in the guard flash")
	_expect(float(late_plan.get("body_ease", 0.0)) > 0.0, "body side should catch up after the 3-frame delay")


func _verify_guard_flash_slot_budget() -> void:
	var context: Dictionary = _base_context(true)
	context["active_item_aipill_flash_timer_frames"] = 11.0
	var plan: Dictionary = _plan(context)
	_expect(plan.get("meridians", []).size() == 2, "guard flash should raise exactly 2 meridian strands")
	_expect(bool(plan.get("seal", {}).get("enabled", false)), "guard flash should stamp the cinnabar seal")
	_expect(int(plan.get("draw_count", -1)) == 11, "guard flash should cost 8 + 3 draw slots, got %d" % int(plan.get("draw_count", -1)))


func _verify_lod_ladder() -> void:
	var expected := {0: 8, 1: 7, 2: 5}
	for lod in expected.keys():
		var plan: Dictionary = _plan(_base_context(true), int(lod))
		_expect(
			int(plan.get("draw_count", -1)) == int(expected[lod]),
			"LOD%d possession plan should cost %d draw slots, got %d" % [int(lod), int(expected[lod]), int(plan.get("draw_count", -1))]
		)
	var severe: Dictionary = _plan(_base_context(true), 2)
	_expect(severe.get("motes", []).is_empty(), "severe LOD should drop the descending motes")
	_expect(not bool(severe.get("sight", {}).get("enabled", true)), "severe LOD should drop the oracle sight line")


# phase 는 active_item_aipill_runtime 에서 TAU 로 fmod 된다. 분수 계수를 쓰면
# 랩 순간 전 레이어가 동시에 튄다(0.48초마다 발생, 헤드리스로는 절대 안 잡힘).
func _verify_phase_wrap_is_continuous() -> void:
	var zero_context: Dictionary = _base_context(true)
	zero_context["active_item_aipill_phase"] = 0.0
	var wrapped_context: Dictionary = _base_context(true)
	wrapped_context["active_item_aipill_phase"] = TAU
	var zero_plan: Dictionary = _plan(zero_context)
	var wrapped_plan: Dictionary = _plan(wrapped_context)
	for key in ["tremor", "crown_radius", "crown_alpha", "backplate_alpha", "talisman_alpha", "label_alpha"]:
		_expect(
			is_equal_approx(float(zero_plan.get(key, 0.0)), float(wrapped_plan.get(key, 1.0))),
			"possession plan field '%s' must be continuous across the phase TAU wrap" % key
		)


# 라운드 리셋 / 텔레포트에서 반대편 잔상이 날아오면 안 된다.
func _verify_lead_offset_self_heals() -> void:
	var renderer: Object = Stage1PlayerActorRenderer.new()
	_expect(is_equal_approx(renderer._advance_possession_lead_offset(true, 380.0, 1.0), 0.0), "first possession frame should seed the lead tracker at zero")
	_expect(renderer._advance_possession_lead_offset(true, 390.0, 1.0) > 0.0, "a real move should produce a lead offset")
	_expect(
		is_equal_approx(renderer._advance_possession_lead_offset(true, 120.0, 1.0), 0.0),
		"a teleport-sized jump should self-heal to zero instead of flinging an afterimage across the field"
	)
	renderer._advance_possession_lead_offset(true, 130.0, 1.0)
	_expect(is_equal_approx(renderer._advance_possession_lead_offset(false, 130.0, 1.0), 0.0), "deactivating aipill should clear the lead tracker")
	_expect(
		is_equal_approx(renderer._advance_possession_lead_offset(true, 600.0, 1.0), 0.0),
		"re-activating aipill should re-seed rather than diff against the stale x"
	)


func _verify_legacy_glitch_vocabulary_removed() -> void:
	var actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
	var sprite_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")
	_expect(not actor_source.contains("AI SYSTEM"), "the cyber 'AI SYSTEM' label must not come back")
	_expect(not actor_source.contains("_draw_aipill_system_label"), "the legacy aipill label renderer must stay removed")
	_expect(actor_source.contains("_draw_possession_overlay"), "the possession overlay renderer should be wired")
	_expect(actor_source.contains("actors.stage1.player.possession_front"), "possession draw cost must be attributed to its own perf label")
	for legacy in ["_draw_ai_glitch_texture_region", "_draw_clipped_ai_glitch_slice", "_draw_ai_glitch_fallback"]:
		_expect(not sprite_source.contains(legacy), "legacy glitch helper %s must stay removed" % legacy)
	_expect(
		sprite_source.contains("_draw_possession_paddle_fallback"),
		"sheet-less characters should fall back to the possession paddle overlay"
	)
	# 실루엣 림 억제 회귀 방지: 빙의 중 캐릭터가 배경에서 분리되지 않던 출고 버그.
	_expect(
		not sprite_source.contains("if bool(context.get(\"active_item_aipill_active\", false)):\n\t\treturn false"),
		"aipill must no longer disable the silhouette rim pass"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
