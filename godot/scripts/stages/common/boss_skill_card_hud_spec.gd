extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const BASE_PILLAR_WIDTH := 80.0
const CARD_WIDTH_BASE := 33.6
const CARD_HEIGHT_BASE := 9.0
const CARD_GAP_BASE := 2.0
const CARD_RIGHT_MARGIN_BASE := 3.0
const CARD_MIN_SIZE := Vector2(24.0, 10.0)
const LEFT_PILLAR_Y_MARGIN_BASE := 5.0
const COMMANDO_FIREARM_PANEL_GAP_BASE := 14.0
const COMMANDO_FIREARM_PANEL_GAP_MIN := 8.0
const TOOLTIP_WIDTH_BASE := 168.0
const TOOLTIP_PADDING_BASE := 10.0
const TOOLTIP_GAP_BASE := 8.0
const TOOLTIP_LINE_SPACING_BASE := 4.0
const TOOLTIP_MAX_DESC_LINES := 2
const TOOLTIP_SCALE_MIN := 0.85
const TOOLTIP_SCALE_MAX := 1.15
const TOOLTIP_MIN_LEFT_WIDTH := 120.0
const SORT_ACTIVE_REMAINING := -0.001
const SORT_INACTIVE_REMAINING := 100000000.0
# 2분법 색 계약: 보스 스킬 카드 좌측 띠 = 붉은 띠(링펫 레일은 렌더러 쪽 청록).
const BOSS_SKILL_STRIP_COLOR := Color(0.86, 0.22, 0.24, 0.95)


static func get_scale_factor(pillar_width: float) -> float:
	return maxf(0.0, pillar_width) / BASE_PILLAR_WIDTH


static func get_card_size(scale_factor: float) -> Vector2:
	return Vector2(
		maxf(CARD_MIN_SIZE.x, round(CARD_WIDTH_BASE * scale_factor)),
		maxf(CARD_MIN_SIZE.y, round(CARD_HEIGHT_BASE * scale_factor))
	)


static func get_card_gap(scale_factor: float) -> float:
	return maxf(1.0, round(CARD_GAP_BASE * scale_factor))


static func get_right_margin(scale_factor: float) -> float:
	return maxf(1.0, round(CARD_RIGHT_MARGIN_BASE * scale_factor))


static func get_left_pillar_y_margin(scale_factor: float) -> float:
	return maxf(2.0, round(LEFT_PILLAR_Y_MARGIN_BASE * scale_factor))


static func get_card_metrics(pillar_width: float) -> Dictionary:
	var scale_factor: float = get_scale_factor(pillar_width)
	return {
		"scale_factor": scale_factor,
		"card_size": get_card_size(scale_factor),
		"card_gap": get_card_gap(scale_factor),
		"margin_x": get_right_margin(scale_factor),
		"margin_y": get_left_pillar_y_margin(scale_factor),
	}


static func get_commando_firearm_panel_gap(scale_factor: float) -> float:
	return maxf(COMMANDO_FIREARM_PANEL_GAP_MIN, round(COMMANDO_FIREARM_PANEL_GAP_BASE * maxf(0.0, scale_factor)))


static func get_tooltip_scale(scale_factor: float) -> float:
	return clampf(scale_factor, TOOLTIP_SCALE_MIN, TOOLTIP_SCALE_MAX)


static func get_mouse_position(canvas: CanvasItem) -> Vector2:
	if canvas == null:
		return Vector2(-100000.0, -100000.0)
	var viewport: Viewport = canvas.get_viewport()
	if viewport == null:
		return Vector2(-100000.0, -100000.0)
	return viewport.get_mouse_position()


static func compare_skill_entries_by_next_activation(a: Dictionary, b: Dictionary) -> bool:
	var remaining_a: float = get_skill_entry_next_activation_sort_value(a)
	var remaining_b: float = get_skill_entry_next_activation_sort_value(b)
	if not is_equal_approx(remaining_a, remaining_b):
		return remaining_a < remaining_b
	var priority_a: int = get_skill_entry_status_sort_priority(a)
	var priority_b: int = get_skill_entry_status_sort_priority(b)
	if priority_a != priority_b:
		return priority_a < priority_b
	return str(a.get("id", "")) < str(b.get("id", ""))


static func get_skill_entry_next_activation_sort_value(skill: Dictionary) -> float:
	var status: String = str(skill.get("status", "charging"))
	if bool(skill.get("used", false)) or status == "used" or status == "locked":
		return SORT_INACTIVE_REMAINING
	if bool(skill.get("active", false)) or status == "casting" or status == "inferno_charge":
		return SORT_ACTIVE_REMAINING
	if bool(skill.get("ready", false)) or status == "ready":
		return 0.0
	if _has_numeric_value(skill, "sort_remaining"):
		return maxf(0.0, float(skill.get("sort_remaining", 0.0)))
	if _has_numeric_value(skill, "next_activation_remaining"):
		return maxf(0.0, float(skill.get("next_activation_remaining", 0.0)))
	if _has_numeric_value(skill, "cooldown_remaining"):
		return maxf(0.0, float(skill.get("cooldown_remaining", 0.0)))
	if _has_numeric_value(skill, "remaining"):
		return maxf(0.0, float(skill.get("remaining", 0.0)))
	var progress: float = clampf(float(skill.get("progress", 0.0)), 0.0, 1.0)
	if _has_numeric_value(skill, "cooldown_total"):
		return maxf(0.0, (1.0 - progress) * maxf(0.0, float(skill.get("cooldown_total", 0.0))))
	if _has_numeric_value(skill, "total"):
		return maxf(0.0, (1.0 - progress) * maxf(0.0, float(skill.get("total", 0.0))))
	return maxf(0.0, 1.0 - progress)


static func get_skill_entry_status_sort_priority(skill: Dictionary) -> int:
	var status: String = str(skill.get("status", "charging"))
	if bool(skill.get("active", false)) or status == "casting" or status == "inferno_charge":
		return 0
	if bool(skill.get("ready", false)) or status == "ready":
		return 1
	if bool(skill.get("used", false)) or status == "used" or status == "locked":
		return 3
	return 2


static func draw_skill_tooltip(
	canvas: CanvasItem,
	skill: Dictionary,
	card_rect: Rect2,
	view_size: Vector2,
	pillar_width: float,
	tooltip_info: Dictionary,
	scale_factor: float,
	style: Dictionary = {}
) -> void:
	var font: Font = ThemeDB.fallback_font
	if canvas == null or font == null or view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var info: Dictionary = _build_tooltip_info(skill, tooltip_info)
	if str(info.get("name", "")).is_empty() and str(info.get("description", "")).is_empty():
		return

	var tooltip_scale: float = get_tooltip_scale(scale_factor)
	var gap: float = maxf(4.0, round(TOOLTIP_GAP_BASE * tooltip_scale))
	var left_available: float = maxf(0.0, card_rect.position.x - gap - 6.0)
	var width: float = TOOLTIP_WIDTH_BASE * tooltip_scale
	if left_available >= TOOLTIP_MIN_LEFT_WIDTH:
		width = minf(width, left_available)
	var padding: float = TOOLTIP_PADDING_BASE * tooltip_scale
	var line_gap: float = TOOLTIP_LINE_SPACING_BASE * tooltip_scale
	var title_size: int = max(13, int(round(15.0 * tooltip_scale)))
	var normal_size: int = max(10, int(round(11.0 * tooltip_scale)))
	var small_size: int = max(9, int(round(9.0 * tooltip_scale)))
	var max_text_width: float = width - padding * 2.0
	var max_desc_lines: int = max(1, int(style.get("max_desc_lines", TOOLTIP_MAX_DESC_LINES)))
	var desc_lines: Array[String] = _wrap_text(LanguageSettings.translate_text(str(info.get("description", ""))), font, normal_size, max_text_width, max_desc_lines)
	var status_text: String = _get_tooltip_status_text(skill, style)
	var meta_text: String = _build_meta_text(LanguageSettings.translate_text(str(info.get("trigger", ""))), LanguageSettings.translate_text(str(info.get("cooldown", ""))), str(style.get("meta_separator", " / ")))
	var title_h: float = 20.0 * tooltip_scale
	var meta_h: float = 17.0 * tooltip_scale if not meta_text.is_empty() else 0.0
	var line_h: float = 14.0 * tooltip_scale
	var height: float = padding * 2.0 + title_h + meta_h + float(desc_lines.size()) * (line_h + line_gap)
	height = maxf(58.0 * tooltip_scale, height)

	var pos := Vector2(card_rect.position.x - width - gap, card_rect.position.y + card_rect.size.y * 0.5 - height * 0.5)
	if pos.x < 6.0:
		pos.x = minf(card_rect.end.x + gap, view_size.x - width - 6.0)
	if pos.x < pillar_width and pos.x + width > pillar_width and card_rect.position.x - width - gap >= 6.0:
		pos.x = card_rect.position.x - width - gap
	pos.y = clampf(pos.y, 6.0, maxf(6.0, view_size.y - height - 6.0))
	var rect := Rect2(pos, Vector2(width, height))

	var skill_color: Color = _as_color(skill.get("color", Color(1.0, 0.76, 0.18, 1.0)), Color(1.0, 0.76, 0.18, 1.0))
	var background_color: Color = _as_color(style.get("background_color", Color(0.055, 0.045, 0.065, 0.94)), Color(0.055, 0.045, 0.065, 0.94))
	var inner_color: Color = _as_color(style.get("inner_color", Color(0.14, 0.10, 0.12, 0.54)), Color(0.14, 0.10, 0.12, 0.54))
	canvas.draw_rect(rect, background_color)
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), inner_color, false, maxf(1.0, round(1.0 * tooltip_scale)))
	canvas.draw_rect(rect, Color(skill_color.r, skill_color.g, skill_color.b, 0.78), false, maxf(1.0, round(1.5 * tooltip_scale)))

	var cursor_y: float = pos.y + padding
	_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), LanguageSettings.translate_text(str(info.get("name", ""))), title_size, Color(1.0, 0.92, 0.74, 1.0))
	var status_size: Vector2 = font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size)
	_draw_text(
		canvas,
		font,
		Vector2(pos.x + width - padding - status_size.x, cursor_y + 2.0 * tooltip_scale),
		status_text,
		small_size,
		_get_status_color(skill, style)
	)
	cursor_y += title_h
	if not meta_text.is_empty():
		_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), meta_text, small_size, Color(0.88, 0.76, 0.60, 1.0))
		cursor_y += meta_h
	for line in desc_lines:
		_draw_text(canvas, font, Vector2(pos.x + padding, cursor_y), line, normal_size, Color(0.88, 0.86, 0.80, 1.0))
		cursor_y += line_h + line_gap


static func resolve_stack_start_y(
	game_offset: Vector2,
	pillar_h: float,
	total_h: float,
	margin_y: float,
	card_x: float,
	card_w: float,
	scale_factor: float,
	avoid_rect: Rect2 = Rect2()
) -> float:
	var start_y: float = game_offset.y + maxf(margin_y, floor((pillar_h - total_h) * 0.5))
	if avoid_rect.size.x > 0.0 and avoid_rect.size.y > 0.0:
		var card_lane := Rect2(Vector2(card_x, game_offset.y), Vector2(card_w, pillar_h))
		if rects_overlap_x(card_lane, avoid_rect):
			var safe_bottom: float = avoid_rect.position.y - get_commando_firearm_panel_gap(scale_factor)
			if start_y + total_h > safe_bottom:
				start_y = safe_bottom - total_h
	return floor(maxf(game_offset.y + margin_y, start_y))


static func rects_overlap_x(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x


# --- Skill-card reorder "shuffle" motion (single-sourced, v2 timed tween) ----
# 스킬카드 정렬(다음 발동 순)이 바뀔 때 카드게임에서 카드를 뽑아 옮겨 꽂는 듯한
# 셔플 모션. v1은 감쇠 스프링 + |vy| 비례 리프트였는데, 오버슈트 정점에서 vy가
# 0을 지나며 리프트가 꺼졌다 켜지는 더블펌프(중간 버벅거림)가 있어 폐기했다.
# v2는 고정 시간 트윈: easeInOutCubic으로 단조 이동(오버슈트 0) + 리프트는
# 이동 "진행률"의 사인 아치 sin(p*PI)라 구조적으로 단일 아치 — 버벅거림 불가.
# 위로 가는 카드에 리프트 배율을 더 줘 스왑 시 두 카드가 좌우로 벌어지며
# 지나간다(리플감). 리프트는 항상 왼쪽(필러 안쪽)이라 플레이필드 침범 없음.
# 상태는 호출부 소유 Dictionary(store)에 카드 id별 sub-dict로 저장.
const SHUFFLE_DURATION := 0.38            # 재정렬 트윈 시간(초)
const SHUFFLE_LIFT_MAX_BASE := 7.0        # 최대 가로 리프트(base px @ scale 1)
const SHUFFLE_LIFT_DIR_BIAS := 0.5        # 위로 가는 카드 추가 리프트 배율(스왑 좌우 분리)
const SHUFFLE_LIFT_TRAVEL_REF_BASE := 11.0  # 이 이동거리(base px)에서 리프트 100% (미세 재정렬은 살짝만)
const SHUFFLE_RETARGET_EPS := 0.5         # 목표 y 변경 감지 임계(px)


# `store`: 렌더러 소유 Dictionary(카드 id → 트윈 상태). 반환:
#   {"x": 이번 프레임 x, "y": 이번 프레임 y, "motion": 0..1 이동 강도}.
# 정지 시 x==target_x, y==target_y로 정확히 수렴(정지 픽셀 기존과 동일).
# 시간 점프(스톨/탭 복귀)는 트윈이 그냥 완료될 뿐이라 폭주/NaN이 없다.
static func advance_card_shuffle(
	store: Dictionary,
	key: String,
	target_x: float,
	target_y: float,
	scale_factor: float,
	time_seconds: float
) -> Dictionary:
	var sf: float = maxf(0.25, scale_factor)
	var state: Variant = store.get(key)
	if not (state is Dictionary):
		# 새 카드 첫 등장: 목적지에 스냅(트윈 완료 상태로 시작).
		store[key] = {
			"from_y": target_y,
			"target_y": target_y,
			"t0": time_seconds - SHUFFLE_DURATION,
			"lift_from": 0.0,
			"up": false,
		}
		return {"x": target_x, "y": target_y, "motion": 0.0}

	var s: Dictionary = state
	# 현재(구 목표 기준) 표시 위치/리프트 — 재타겟 연속성의 기준점.
	var p_now: float = _shuffle_progress(s, time_seconds)
	var y_now: float = lerpf(float(s.get("from_y", target_y)), float(s.get("target_y", target_y)), _shuffle_ease(p_now))
	var lift_now: float = _shuffle_lift(s, p_now, sf)

	if absf(target_y - float(s.get("target_y", target_y))) > SHUFFLE_RETARGET_EPS:
		# 정렬이 바뀜: 현재 표시 위치에서 새 트윈 시작(위치·리프트 연속, 점프 없음).
		s["from_y"] = y_now
		s["target_y"] = target_y
		s["t0"] = time_seconds
		s["lift_from"] = lift_now
		s["up"] = target_y < y_now

	var p: float = _shuffle_progress(s, time_seconds)
	var y: float = lerpf(float(s.get("from_y", target_y)), float(s.get("target_y", target_y)), _shuffle_ease(p))
	var lift: float = _shuffle_lift(s, p, sf)
	if p >= 1.0:
		y = float(s.get("target_y", target_y))
		lift = 0.0
	return {"x": target_x - lift, "y": y, "motion": sin(clampf(p, 0.0, 1.0) * PI)}


static func _shuffle_progress(s: Dictionary, time_seconds: float) -> float:
	return clampf((time_seconds - float(s.get("t0", time_seconds))) / SHUFFLE_DURATION, 0.0, 1.0)


# easeInOutCubic: 살짝 모았다가 미끄러져 들어가 감속 안착. 단조라 오버슈트 없음.
static func _shuffle_ease(p: float) -> float:
	if p < 0.5:
		return 4.0 * p * p * p
	var q: float = -2.0 * p + 2.0
	return 1.0 - q * q * q * 0.5


static func _shuffle_lift(s: Dictionary, p: float, sf: float) -> float:
	if p >= 1.0:
		return 0.0
	var travel: float = absf(float(s.get("target_y", 0.0)) - float(s.get("from_y", 0.0)))
	# 한 칸(카드높이급) 이상 이동이면 풀 리프트, 미세 조정은 비례해 살짝만.
	var travel_norm: float = clampf(travel / (SHUFFLE_LIFT_TRAVEL_REF_BASE * sf), 0.0, 1.0)
	var dir_mult: float = 1.0 + (SHUFFLE_LIFT_DIR_BIAS if bool(s.get("up", false)) else 0.0)
	var arc: float = SHUFFLE_LIFT_MAX_BASE * sf * dir_mult * travel_norm * sin(p * PI)
	# 재타겟 직후엔 이전 리프트에서 이어받아 자연 감쇠(리프트 순간 점프 방지).
	return maxf(arc, float(s.get("lift_from", 0.0)) * (1.0 - p))


# 정렬에서 사라진 카드의 트윈 상태 정리(렌더러별 _prune_queue_positions 공용화).
# `entries`의 각 항목은 "id" 키를 갖는 Dictionary를 기대한다.
static func prune_shuffle_store(store: Dictionary, entries: Array) -> void:
	var active_keys := {}
	for entry in entries:
		if entry is Dictionary:
			active_keys[str((entry as Dictionary).get("id", ""))] = true
	for key in store.keys():
		if not active_keys.has(str(key)):
			store.erase(key)


static func _build_tooltip_info(skill: Dictionary, tooltip_info: Dictionary) -> Dictionary:
	var info: Dictionary = tooltip_info.duplicate(true)
	if not info.has("name") or str(info.get("name", "")).is_empty():
		info["name"] = str(skill.get("name", skill.get("label", skill.get("short_label", ""))))
	if not info.has("trigger") or str(info.get("trigger", "")).is_empty():
		info["trigger"] = _get_trigger_label(skill)
	if not info.has("cooldown") or str(info.get("cooldown", "")).is_empty():
		info["cooldown"] = _get_cooldown_label(info, skill)
	if not info.has("description"):
		info["description"] = str(skill.get("description", ""))
	return info


static func _get_trigger_label(skill: Dictionary) -> String:
	if skill.has("trigger") and not str(skill.get("trigger", "")).is_empty():
		return LanguageSettings.translate_text(str(skill.get("trigger", "")))
	if skill.has("trigger_label") and not str(skill.get("trigger_label", "")).is_empty():
		return LanguageSettings.translate_text(str(skill.get("trigger_label", "")))
	var trigger_type: String = str(skill.get("trigger_type", ""))
	match trigger_type:
		"auto", "auto_cooldown", "timer":
			return LanguageSettings.translate_text("자동")
		"instant":
			return LanguageSettings.translate_text("즉시 발동")
		"hit", "hit_cooldown", "boss_paddle_contact", "on_boss_hit":
			return LanguageSettings.translate_text("보스 타격")
	return ""


static func _get_cooldown_label(info: Dictionary, skill: Dictionary) -> String:
	if info.has("cooldown_seconds"):
		return _format_cooldown_label(float(info.get("cooldown_seconds", 0.0)))
	var total: float = float(skill.get("cooldown_total", skill.get("total", 0.0)))
	if total > 0.0:
		return _format_cooldown_label(total)
	return ""


static func _format_cooldown_label(value: float) -> String:
	var seconds_text := _format_seconds(value)
	if seconds_text.is_empty():
		return ""
	var language := LanguageSettings.get_language()
	if language == LanguageSettings.LANGUAGE_ENGLISH:
		return "Cooldown %s" % seconds_text
	if language == LanguageSettings.LANGUAGE_SPANISH:
		return "Recarga %s" % seconds_text
	if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Recarga %s" % seconds_text
	if language == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Перезарядка %s" % seconds_text
	if language == LanguageSettings.LANGUAGE_CHINESE:
		return "冷却%s" % seconds_text
	if language == LanguageSettings.LANGUAGE_JAPANESE:
		return "クールタイム%s" % seconds_text
	return "쿨타임 %s" % seconds_text


static func _format_seconds(value: float) -> String:
	if value <= 0.0:
		return ""
	var language := LanguageSettings.get_language()
	if abs(value - round(value)) < 0.05:
		if language == LanguageSettings.LANGUAGE_ENGLISH:
			return "%ds" % int(round(value))
		if language == LanguageSettings.LANGUAGE_SPANISH:
			return "%ds" % int(round(value))
		if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			return "%ds" % int(round(value))
		if language == LanguageSettings.LANGUAGE_RUSSIAN:
			return "%dс" % int(round(value))
		if language == LanguageSettings.LANGUAGE_CHINESE:
			return "%d秒" % int(round(value))
		if language == LanguageSettings.LANGUAGE_JAPANESE:
			return "%d秒" % int(round(value))
		return "%d초" % int(round(value))
	if language == LanguageSettings.LANGUAGE_ENGLISH:
		return "%.1fs" % value
	if language == LanguageSettings.LANGUAGE_SPANISH:
		return "%.1fs" % value
	if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "%.1fs" % value
	if language == LanguageSettings.LANGUAGE_RUSSIAN:
		return "%.1fс" % value
	if language == LanguageSettings.LANGUAGE_CHINESE:
		return "%.1f秒" % value
	if language == LanguageSettings.LANGUAGE_JAPANESE:
		return "%.1f秒" % value
	return "%.1f초" % value


static func _build_meta_text(trigger_text: String, cooldown_text: String, separator: String) -> String:
	if trigger_text.is_empty():
		return cooldown_text
	if cooldown_text.is_empty():
		return trigger_text
	return "%s%s%s" % [trigger_text, separator, cooldown_text]


static func _get_tooltip_status_text(skill: Dictionary, style: Dictionary) -> String:
	var status: String = str(skill.get("status", "charging"))
	var status_labels: Variant = style.get("status_labels", {})
	if status_labels is Dictionary and (status_labels as Dictionary).has(status):
		return LanguageSettings.translate_text(str((status_labels as Dictionary).get(status, "")))
	if status == "inferno_charge":
		return LanguageSettings.translate_text("폭염 예열")
	if status == "casting":
		return LanguageSettings.translate_text("발동 중")
	if status == "used":
		return LanguageSettings.translate_text("사용됨")
	if status == "paused" or status == "waiting":
		return LanguageSettings.translate_text("대기")
	if status == "locked":
		return LanguageSettings.translate_text("잠김")
	if bool(skill.get("ready", false)) or status == "ready":
		return LanguageSettings.translate_text("준비 완료")
	var progress_percent := int(round(clampf(float(skill.get("progress", 0.0)), 0.0, 1.0) * 100.0))
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Charge %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Carga %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Carga %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Заряд %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "充能 %d%%" % progress_percent
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "チャージ %d%%" % progress_percent
	return "충전 %d%%" % progress_percent


static func _get_status_color(skill: Dictionary, style: Dictionary) -> Color:
	var status: String = str(skill.get("status", "charging"))
	var status_colors: Variant = style.get("status_colors", {})
	if status_colors is Dictionary and (status_colors as Dictionary).has(status):
		return _as_color((status_colors as Dictionary).get(status), Color(0.78, 0.72, 0.64, 1.0))
	if status == "inferno_charge":
		return Color(1.0, 0.44, 0.28, 1.0)
	if status == "casting":
		return Color(1.0, 0.84, 0.26, 1.0)
	if status == "used" or status == "locked":
		return Color(0.58, 0.55, 0.52, 1.0)
	if bool(skill.get("ready", false)) or status == "ready":
		return Color(0.48, 1.0, 0.64, 1.0)
	return Color(0.78, 0.72, 0.64, 1.0)


static func _wrap_text(text: String, font: Font, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for i in range(text.length()):
		var character: String = text.substr(i, 1)
		if character == "\n":
			if not current.strip_edges().is_empty():
				lines.append(current.strip_edges())
				if lines.size() >= max_lines:
					return lines
			current = ""
			continue
		if character == " " and current.is_empty():
			continue
		var candidate: String = current + character
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width or current.is_empty():
			current = candidate
			continue
		lines.append(current.strip_edges())
		if lines.size() >= max_lines:
			return lines
		current = "" if character == " " else character
	if not current.strip_edges().is_empty() and lines.size() < max_lines:
		lines.append(current.strip_edges())
	return lines


static func _draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, minf(0.72, color.a)))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


static func _as_color(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	return fallback


static func _has_numeric_value(source: Dictionary, key: String) -> bool:
	if not source.has(key):
		return false
	var value: Variant = source.get(key)
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


# 스킬카드 게이지 필 공용 draw (수정14 cover-crop 통일 복원): 카드 아트를
# 종횡비 보존 cover-crop으로 배치해 찌그러짐을 없애고, 어두운 백플레이트 위에
# 좌→우 fill 비율만큼 밝은 부분을 같은 비율의 소스 크롭으로 겹친다.
# draw_texture_rect_region은 픽셀 rect를 받으므로 UV 정규화 트랩과 무관.
static func draw_skillcard_gauge_fill(
	canvas: CanvasItem,
	rect: Rect2,
	texture: Texture2D,
	source_rect: Rect2,
	fill_ratio: float,
	back_modulate: Color,
	front_modulate: Color
) -> void:
	if canvas == null or texture == null or not rect.has_area():
		return
	var cover: Rect2 = _cover_crop_source(texture, source_rect, rect.size)
	canvas.draw_texture_rect_region(texture, rect, cover, back_modulate)
	var clamped: float = clampf(fill_ratio, 0.0, 1.0)
	if clamped <= 0.0:
		return
	var lit_rect := Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y))
	var lit_source := Rect2(cover.position, Vector2(cover.size.x * clamped, cover.size.y))
	canvas.draw_texture_rect_region(texture, lit_rect, lit_source, front_modulate)


static func _cover_crop_source(texture: Texture2D, source_rect: Rect2, target_size: Vector2) -> Rect2:
	var source := source_rect
	if not source.has_area():
		source = Rect2(Vector2.ZERO, texture.get_size())
	var source_aspect: float = source.size.x / maxf(1.0, source.size.y)
	var target_aspect: float = target_size.x / maxf(1.0, target_size.y)
	var cropped := source
	if source_aspect > target_aspect:
		cropped.size.x = source.size.y * target_aspect
		cropped.position.x += (source.size.x - cropped.size.x) * 0.5
	else:
		cropped.size.y = source.size.x / maxf(0.01, target_aspect)
		cropped.position.y += (source.size.y - cropped.size.y) * 0.5
	return cropped
