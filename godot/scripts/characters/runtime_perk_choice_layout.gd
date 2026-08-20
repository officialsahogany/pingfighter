extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

# 카드 높이 390 -> 316 (2026-08-06): 하단 능력치 원장 자리를 만들면서 카드가
# "너무 크다"는 사용자 판정을 함께 반영한다. 폭(268)은 손대지 않는다 --
# 카드 이름/성급/설명 폰트 크기가 전부 card_width에서 파생되므로(_draw_card의
# rect.size.x * 0.072 / 0.057, _ensure_card_desc_cache의 card_width / 16.4)
# 폭을 줄이면 "설명·폰트 크기는 그대로" 요구가 깨진다.
const DEFAULT_CARD_SIZE := Vector2(268.0, 316.0)
const DEFAULT_CARD_GAP := 20.0
const REFERENCE_VIEW_HEIGHT := 920.0
const MIN_LAYOUT_SCALE := 0.58
const MAX_LAYOUT_SCALE := 1.32
# 카드가 낮아지면 성급 밑줄(_draw_card: 이름판 0.386 + 0.092 뒤 rank + 12)과
# 설명 블록 상단 괘선이 붙어 이중선처럼 읽힌다. S2에서는 0.595 -> 0.585로
# 1%만 되돌려 최장 9행 문구의 세로 예산을 확보한다. 출하 크기에서 성급 밑줄과
# 12px 이상 떨어지는 하한은 씰이 계속 잠근다.
const CARD_DESCRIPTION_TOP_RATIO := 0.585
# 0.375 -> 0.415 (S2): 카드 치수와 폰트 상한은 유지하면서, 카드 하단까지 남은
# 공간을 설명 영역에 돌린다. 실제 문구는 고정 5행으로 자르지 않고 렌더러가 이
# 높이에 맞는 가장 큰 글자 크기를 고른다. 봉인:
# runtime_perk_choice_stats_band_smoke._verify_worst_case_description_stays_inside_card
const CARD_DESCRIPTION_HEIGHT_RATIO := 0.415
# 하단 능력치 원장(2026-08-06): 캐릭터 정보창의 "플레이어 능력치" 10행을 퍽
# 선택 화면에도 그대로 싣는다. 드로어(draw_cached_player_stat_rows)는 제목 49px
# + 행당 최소 19px + 하단 여백 8px가 필요하고, 넘치는 행은 조용히 잘라 버린다
# (Godot Stats-Panel Row Budget Trap). 그래서 최소 높이를 밑돌면 띠를 그리는
# 대신 아예 끄고 기존 레이아웃으로 되돌린다 -- 잘린 행을 보여 주는 것보다
# 낫다.
const STATS_BAND_ROW_COUNT := 10
# draw_cached_player_stat_rows의 하드 지오메트리: 제목 49 + 행당 최소 19 + 하단
# 여백 8. 여기에 원장 크롬 안쪽 여백(runtime_perk_traditional_chrome의
# draw_stats_ledger가 rect.grow(-11)을 돌려준다)을 위아래로 더한 값이 10행이
# 온전히 보이는 최소 띠 높이다. 상수를 곱셈으로 유도해 두면 한쪽만 바뀌어도
# 봉인 스모크가 잡는다.
const STATS_BAND_CHROME_INSET := 11.0
const STATS_BAND_HEADER_HEIGHT := 49.0
const STATS_BAND_ROW_MIN_GAP := 19.0
const STATS_BAND_FOOTER_PADDING := 8.0
const STATS_BAND_MIN_HEIGHT := (
	STATS_BAND_CHROME_INSET * 2.0
	+ STATS_BAND_HEADER_HEIGHT
	+ STATS_BAND_ROW_MIN_GAP * STATS_BAND_ROW_COUNT
	+ STATS_BAND_FOOTER_PADDING
)
const STATS_BAND_MAX_HEIGHT := 292.0
const STATS_BAND_BASE_HEIGHT := 216.0
const STATS_BAND_GAP := 16.0
# 폭은 캐릭터 정보창의 능력치 박스와 같은 급으로 맞춘다. 게이지 바 좌측 시작점이
# rect.x + 186 * ui_text_scale 고정이라, 띠를 무공 원장처럼 full-width로 늘리면
# 바만 900px대로 길어져 원본과 다르게 읽힌다.
const STATS_BAND_BASE_WIDTH := 692.0
const STATS_BAND_MIN_WIDTH := 560.0
const STATS_BAND_MAX_WIDTH := 960.0
# 그룹 전체가 뷰 안에 들어와야 하는 최소 상/하 여백 합.
const GROUP_VERTICAL_SAFE_MARGIN := 32.0
# 제목 현판은 title_pos를 중심으로 그려지고(높이 최대 ~120), 그룹 박스 밖으로
# 올라간다. 능력치 띠가 켜지면 카드가 위로 올라와 기존 리프트(최대 160)를 다 쓸
# 수 없으므로, 현판 상단이 화면 밖으로 잘리지 않도록 중심 y의 하한을 둔다.
const TITLE_MIN_CENTER_Y := 72.0
const PARTICLE_COLORS := [
	Color(229.0 / 255.0, 192.0 / 255.0, 107.0 / 255.0),
	Color(244.0 / 255.0, 217.0 / 255.0, 145.0 / 255.0),
	Color(169.0 / 255.0, 130.0 / 255.0, 66.0 / 255.0),
	Color(98.0 / 255.0, 155.0 / 255.0, 139.0 / 255.0),
]


func build_layout(
	view_size: Vector2,
	choice_count_value: int,
	stats_band_requested: bool = false,
	panel_gap_min: float = -1.0,
	footer_reserve: float = 0.0
) -> Dictionary:
	var card_count: int = max(1, choice_count_value)
	var game_width: float = min(1720.0, max(420.0, view_size.x - 72.0))
	var base_total_width: float = DEFAULT_CARD_SIZE.x * float(card_count) + DEFAULT_CARD_GAP * float(max(0, card_count - 1))
	var width_scale: float = min(MAX_LAYOUT_SCALE, game_width / max(1.0, base_total_width))
	var height_scale: float = clamp(view_size.y / REFERENCE_VIEW_HEIGHT, MIN_LAYOUT_SCALE, MAX_LAYOUT_SCALE)
	var layout_scale: float = min(width_scale, height_scale)
	var card_gap: float = max(10.0, floor(DEFAULT_CARD_GAP * layout_scale))
	var card_width: float = floor(DEFAULT_CARD_SIZE.x * layout_scale)
	var card_height: float = floor(DEFAULT_CARD_SIZE.y * layout_scale)
	var total_width: float = card_width * float(card_count) + card_gap * float(max(0, card_count - 1))
	var title_to_card: float = floor(86.0 * layout_scale)
	var panel_gap: float = max(12.0, floor(22.0 * layout_scale))
	if panel_gap_min >= 0.0:
		panel_gap = maxf(panel_gap, panel_gap_min)
	# 무공 원장 기준 높이 172 -> 142 (2026-08-06): 사용자가 상단 선택 카드와 함께
	# "현재 소지중인 퍽 슬롯도 좀더 작게"를 요청했다. 이 값을 줄이면 슬롯 셀 크기
	# (_get_status_slot_rect)와 원장 글자 배율(_draw_status_panel /
	# _get_status_counter_rect의 status_scale)이 함께 따라 내려가므로, 그 두 곳의
	# 배율 기준값도 172 -> 142로 같이 옮겨야 글자 크기가 유지된다.
	var panel_h: float = clamp(floor(142.0 * layout_scale), 104.0, 190.0)
	var hint_gap: float = max(28.0, floor(38.0 * layout_scale))
	var stats_gap: float = max(10.0, floor(STATS_BAND_GAP * layout_scale))
	var group_h: float = (
		title_to_card
		+ card_height
		+ panel_gap
		+ panel_h
		+ hint_gap
		+ 18.0
		+ maxf(0.0, footer_reserve)
	)
	# 능력치 띠는 그룹 높이에 포함되어야 한다 -- card_y가 group_top에서 파생되고
	# get_card_rects()/get_card_index_at()이 같은 build_layout을 통과하므로,
	# 여기서 빠지면 그리는 좌표와 클릭 히트테스트가 어긋난다.
	var stats_h: float = 0.0
	var stats_budget: float = -1.0
	if stats_band_requested:
		stats_h = clamp(floor(STATS_BAND_BASE_HEIGHT * layout_scale), STATS_BAND_MIN_HEIGHT, STATS_BAND_MAX_HEIGHT)
		stats_budget = view_size.y - GROUP_VERTICAL_SAFE_MARGIN - group_h - stats_gap
		if stats_budget < STATS_BAND_MIN_HEIGHT:
			stats_h = 0.0
		else:
			stats_h = min(stats_h, stats_budget)
			group_h += stats_gap + stats_h
	var group_top: float = max(24.0, floor((view_size.y - group_h) * 0.5))
	var card_y: float = group_top + title_to_card
	var card_x: float = floor((view_size.x - total_width) * 0.5)
	var desc_y: float = card_y + card_height * CARD_DESCRIPTION_TOP_RATIO
	var desc_h: float = card_height * CARD_DESCRIPTION_HEIGHT_RATIO
	var panel_y: float = card_y + card_height + panel_gap
	var panel_w: float = min(game_width, total_width + max(68.0, floor(112.0 * layout_scale)))
	var stats_rect := Rect2()
	var content_bottom: float = panel_y + panel_h
	if stats_h > 0.0:
		var stats_w: float = min(panel_w, clamp(floor(STATS_BAND_BASE_WIDTH * layout_scale), STATS_BAND_MIN_WIDTH, STATS_BAND_MAX_WIDTH))
		var stats_y: float = content_bottom + stats_gap
		stats_rect = Rect2(Vector2(max(20.0, floor((view_size.x - stats_w) * 0.5)), stats_y), Vector2(stats_w, stats_h))
		content_bottom = stats_y + stats_h
	return {
		"card_size": Vector2(card_width, card_height),
		"card_gap": card_gap,
		"layout_scale": layout_scale,
		"cards_start": Vector2(card_x, card_y),
		"total_width": total_width,
		"desc_rect": Rect2(Vector2(card_x, desc_y), Vector2(total_width, desc_h)),
		"panel_rect": Rect2(Vector2(max(20.0, (view_size.x - panel_w) * 0.5), panel_y), Vector2(panel_w, panel_h)),
		"stats_rect": stats_rect,
		"stats_budget": stats_budget,
		"title_pos": Vector2(
			view_size.x * 0.5,
			max(TITLE_MIN_CENTER_Y, card_y - clamp(view_size.y * 0.145, 105.0, 160.0))
		),
		"hint_pos": Vector2(view_size.x * 0.5, content_bottom + hint_gap),
	}


func build_layout_from_runtime_state(runtime_state: Object, view_size: Vector2) -> Dictionary:
	if runtime_state == null:
		return build_layout(view_size, 0)
	return build_layout(
		view_size,
		RuntimePerkPayloadAccess.as_array(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")).size(),
		stats_band_requested_from_runtime_state(runtime_state)
	)


# 능력치 띠 요청 플래그는 레이아웃/카드 히트테스트가 반드시 같은 값을 읽어야
# 하므로 runtime_state 한 곳에서만 읽는다.
func stats_band_requested_from_runtime_state(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	var value: Variant = RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "stats_band_enabled")
	return value is bool and bool(value)


func get_card_rects(
	view_size: Vector2,
	choice_count_value: int,
	animation_time: float,
	stats_band_requested: bool = false,
	panel_gap_min: float = -1.0,
	footer_reserve: float = 0.0
) -> Array:
	var layout: Dictionary = build_layout(
		view_size,
		choice_count_value,
		stats_band_requested,
		panel_gap_min,
		footer_reserve
	)
	var rects: Array = []
	var card_size: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout.get("card_size", DEFAULT_CARD_SIZE))
	var start: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout.get("cards_start", Vector2.ZERO))
	var gap: float = float(layout.get("card_gap", DEFAULT_CARD_GAP))
	for index in range(max(0, choice_count_value)):
		var offset := get_card_offset(index, animation_time)
		rects.append(Rect2(start + Vector2(float(index) * (card_size.x + gap), 0.0) + offset, card_size))
	return rects


func get_card_rects_from_runtime_state(runtime_state: Object, view_size: Vector2) -> Array:
	if runtime_state == null:
		return []
	return get_card_rects(
		view_size,
		RuntimePerkPayloadAccess.as_array(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")).size(),
		float(RuntimePerkRuntimeStateAccess.get_float(runtime_state, "animation_time")),
		stats_band_requested_from_runtime_state(runtime_state)
	)


func get_card_index_at(
	position: Vector2,
	view_size: Vector2,
	choice_count_value: int,
	animation_time: float,
	stats_band_requested: bool = false,
	panel_gap_min: float = -1.0,
	footer_reserve: float = 0.0
) -> int:
	var rects: Array = get_card_rects(
		view_size,
		choice_count_value,
		animation_time,
		stats_band_requested,
		panel_gap_min,
		footer_reserve
	)
	for index in range(rects.size()):
		var rect: Rect2 = rects[index]
		if rect.has_point(position):
			return index
	return -1


func get_card_index_at_from_runtime_state(runtime_state: Object, position: Vector2, view_size: Vector2) -> int:
	if runtime_state == null:
		return -1
	return get_card_index_at(
		position,
		view_size,
		RuntimePerkPayloadAccess.as_array(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")).size(),
		float(RuntimePerkRuntimeStateAccess.get_float(runtime_state, "animation_time")),
		stats_band_requested_from_runtime_state(runtime_state)
	)


func get_card_offset(index: int, animation_time: float) -> Vector2:
	var progress: float = clamp(animation_time / 0.28, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	if index == 1:
		return Vector2(0.0, -260.0 * (1.0 - eased))
	if index % 2 == 0:
		return Vector2(-260.0 * (1.0 - eased), 0.0)
	return Vector2(260.0 * (1.0 - eased), 0.0)


func build_particles(count: int) -> Array:
	var out: Array = []
	for _index in range(max(0, count)):
		out.append({})
	return out


func apply_particles_state_update(runtime_state: Object, particles_update: Array) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	runtime_state.set("particles", particles_update.duplicate(true))
	var applied_particles: Array = RuntimePerkPayloadAccess.as_array(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "particles"))
	return {
		"accepted": true,
		"particle_count": applied_particles.size(),
	}


func rebuild_particles_from_runtime_state(runtime_state: Object, count: int) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	return apply_particles_state_update(runtime_state, build_particles(count))


func update_particles(particles: Array, delta: float, view_size: Vector2, particle_life: float) -> void:
	var left: float = max(0.0, view_size.x * 0.5 - 300.0)
	var right: float = min(view_size.x, view_size.x * 0.5 + 300.0)
	for particle in particles:
		var data: Dictionary = particle
		data["age"] = float(data.get("age", 0.0)) + delta
		data["position"] = RuntimePerkPayloadAccess.as_vector2(data.get("position", Vector2.ZERO)) + RuntimePerkPayloadAccess.as_vector2(data.get("velocity", Vector2.ZERO)) * delta
		var pos: Vector2 = RuntimePerkPayloadAccess.as_vector2(data.get("position", Vector2.ZERO))
		if pos.x < left or pos.x > right or float(data.get("age", 0.0)) > particle_life:
			reset_particle(data, view_size, particle_life)


func reset_particle(particle: Dictionary, view_size: Vector2, particle_life: float) -> void:
	var center_x: float = view_size.x * 0.5
	var x: float = randf_range(center_x - 280.0, center_x + 280.0)
	var y: float = randf_range(80.0, max(100.0, view_size.y * 0.64))
	particle["position"] = Vector2(x, y)
	particle["velocity"] = Vector2(randf_range(-12.0, 12.0), randf_range(-36.0, -12.0))
	particle["age"] = randf_range(0.0, particle_life * 0.65)
	particle["size"] = randf_range(1.5, 3.4)
	particle["color"] = PARTICLE_COLORS[randi() % PARTICLE_COLORS.size()]
