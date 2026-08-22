extends RefCounted

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const StageSnapshotBuilder := preload("res://scripts/core/stage_clear_result_stage_snapshot_builder.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")

const BUTTON_SIZE := Vector2(190.0, 42.0)
const LIST_LIMIT := 5
const STAGE_BOSS_NAMES := {
	1: "달지",
	4: "폰크",
	5: "홍련",
	6: "테트리서",
}

var active: bool = false
var elapsed_sec: float = 0.0
var settlement_snapshot: Dictionary = {}
var _pending_exit_callback: Callable = Callable()
var _stage_snapshot_builder: Object = StageSnapshotBuilder.new()
var _active_item_catalog: Object = ActiveItemCatalog.new()
var _mythic_item_catalog: Object = MythicItemCatalog.new()
var _perk_catalog: Object = RuntimePerkCatalog.new()


func show(owner: Object, registry: Object, exit_callback: Callable) -> bool:
	settlement_snapshot = _build_snapshot(owner, registry)
	_pending_exit_callback = exit_callback
	elapsed_sec = 0.0
	active = true
	_queue_redraw(owner)
	return true


func is_active() -> bool:
	return active


func reset() -> void:
	active = false
	elapsed_sec = 0.0
	settlement_snapshot = {}
	_pending_exit_callback = Callable()


func get_snapshot() -> Dictionary:
	return settlement_snapshot.duplicate(true)


func update(delta: float) -> void:
	if not active:
		return
	elapsed_sec += max(0.0, delta)


func handle_input(event: InputEvent, owner: Object, _registry: Object, view_size: Vector2) -> bool:
	if not active:
		return false
	if _is_dismiss_event(event, view_size):
		_dismiss(owner)
		return true
	return true


func draw(canvas: CanvasItem, _owner: Object, _registry: Object, view_size: Vector2) -> void:
	if canvas == null or not active:
		return
	var font := _get_ui_font()
	var panel_rect := _get_panel_rect(view_size)
	var pulse := 0.5 + 0.5 * sin(elapsed_sec * TAU * 0.72)
	var line_color := Color(0.84, 0.47, 0.38, 0.82)
	var gold_color := Color(1.0, 0.78, 0.32, 0.96)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.72))
	canvas.draw_rect(panel_rect.grow(12.0), Color(0.05, 0.018, 0.018, 0.48))
	canvas.draw_rect(panel_rect, Color(0.034, 0.030, 0.042, 0.97))
	canvas.draw_rect(panel_rect, Color(0.75, 0.23, 0.18, 0.70), false, 2.0)
	canvas.draw_rect(Rect2(panel_rect.position, Vector2(panel_rect.size.x, 4.0)), Color(0.96, 0.34, 0.24, 0.80))

	_draw_centered_text(canvas, font, "도전 종료", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 46.0), 31, Color(1.0, 0.94, 0.90, 0.98))
	_draw_centered_text(canvas, font, "이번 링피아 여정의 기록입니다", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 78.0), 15, Color(0.88, 0.76, 0.72, 0.88))

	var gold: Dictionary = settlement_snapshot.get("gold", {})
	var score: Dictionary = settlement_snapshot.get("score", {})
	var stage: Dictionary = settlement_snapshot.get("stage", {})
	var stat_y := panel_rect.position.y + 108.0
	var stat_w := (panel_rect.size.x - 50.0) / 3.0
	_draw_stat_box(canvas, font, Rect2(panel_rect.position + Vector2(18.0, stat_y - panel_rect.position.y), Vector2(stat_w, 76.0)), "획득 골드", "%dG" % int(gold.get("total", 0)), gold_color)
	_draw_stat_box(canvas, font, Rect2(panel_rect.position + Vector2(25.0 + stat_w, stat_y - panel_rect.position.y), Vector2(stat_w, 76.0)), "최종 스코어", "%d : %d" % [int(score.get("player", 0)), int(score.get("boss", 0))], Color(0.88, 0.92, 1.0, 0.96))
	_draw_stat_box(canvas, font, Rect2(panel_rect.position + Vector2(32.0 + stat_w * 2.0, stat_y - panel_rect.position.y), Vector2(stat_w, 76.0)), "도달 보스", str(stage.get("current_boss", "알 수 없음")), Color(0.96, 0.70, 0.62, 0.96))

	var details_y := panel_rect.position.y + 204.0
	var left_rect := Rect2(panel_rect.position + Vector2(22.0, details_y - panel_rect.position.y), Vector2((panel_rect.size.x - 58.0) * 0.5, 218.0))
	var right_rect := Rect2(Vector2(left_rect.end.x + 14.0, left_rect.position.y), left_rect.size)
	_draw_section(canvas, font, left_rect, "아이템", [
		"액티브  " + _format_labels(settlement_snapshot.get("active_items", [])),
		"패시브  " + _format_labels(settlement_snapshot.get("passive_items", [])),
	], line_color)
	_draw_section(canvas, font, right_rect, "무공", [
		_format_labels(settlement_snapshot.get("perks", [])),
	], line_color)

	var cleared_text := _format_labels(stage.get("cleared_bosses", []))
	_draw_text(canvas, font, "클리어한 보스  " + cleared_text, Vector2(panel_rect.position.x + 24.0, panel_rect.end.y - 82.0), 14, Color(0.78, 0.82, 0.90, 0.88), panel_rect.size.x - 48.0)
	_draw_text(canvas, font, "광장의 보유 골드 %dG + 이번 도전 골드 %dG" % [int(gold.get("plaza", 0)), int(gold.get("runtime", 0))], Vector2(panel_rect.position.x + 24.0, panel_rect.end.y - 58.0), 13, Color(0.73, 0.68, 0.64, 0.82), panel_rect.size.x - 250.0)

	var button_rect := _get_button_rect(view_size)
	canvas.draw_rect(button_rect, Color(0.22, 0.050, 0.046, 0.96))
	canvas.draw_rect(button_rect, Color(0.95, 0.36, 0.24, 0.76 + pulse * 0.16), false, 2.0)
	canvas.draw_rect(button_rect.grow(-4.0), Color(1.0, 0.82, 0.65, 0.06))
	_draw_centered_text(canvas, font, "메인 메뉴로", button_rect.get_center() + Vector2(0.0, 1.0), 16, Color.WHITE)


func _build_snapshot(owner: Object, registry: Object) -> Dictionary:
	var stage_id: int = max(1, _read_int(owner, "current_stage", 1))
	var stage_boss_variant: String = _read_string(owner, "stage_boss_variant", "")
	var stage1_boss_variant: String = _read_string(owner, "stage1_boss_variant", "")
	var progress: Dictionary = _build_progress_snapshot(owner, registry, stage_id)
	var runtime_gold: int = _read_int(owner, "runtime_perk_gold", 0)
	var plaza_gold: int = _get_plaza_gold(registry)
	var score: Dictionary = _get_score_snapshot(registry)
	var active_items: Array[String] = _build_item_labels(progress.get("active_item_slots", []), true)
	var passive_items: Array[String] = _build_item_labels(progress.get("passive_item_inventory", []), false)
	var perks: Array[String] = _build_perk_labels(progress.get("runtime_perk_levels", {}))
	return {
		"stage": _build_stage_snapshot(stage_id, stage_boss_variant, stage1_boss_variant),
		"score": score,
		"gold": {
			"plaza": plaza_gold,
			"runtime": runtime_gold,
			"total": plaza_gold + runtime_gold,
		},
		"active_items": active_items,
		"passive_items": passive_items,
		"perks": perks,
		"progress": progress,
	}


func _build_progress_snapshot(owner: Object, registry: Object, stage_id: int) -> Dictionary:
	if _stage_snapshot_builder != null and _stage_snapshot_builder.has_method("build_progress_snapshot"):
		var progress_value: Variant = _stage_snapshot_builder.build_progress_snapshot(owner, registry, stage_id)
		if progress_value is Dictionary:
			return (progress_value as Dictionary).duplicate(true)
	return {
		"stage": stage_id,
		"active_item_slots": _read_array(owner, "active_item_slots"),
		"passive_item_inventory": _read_array(owner, "passive_item_inventory"),
		"runtime_perk_levels": _read_dictionary(owner, "runtime_perk_levels"),
	}


func _build_stage_snapshot(
	stage_id: int,
	stage_boss_variant: String = "",
	stage1_boss_variant: String = ""
) -> Dictionary:
	# Stage 1 keeps its variant in a SEPARATE owner field from every other stage,
	# so a Stage 1 row must read stage1_boss_variant, and a cleared Stage 1 row
	# must keep that name even when the defeat happened on a later floor.
	var stage1_variant: String = stage1_boss_variant.strip_edges()
	var cleared: Array[String] = []
	for index in range(1, stage_id):
		cleared.append(_get_stage_boss_name(index, stage1_variant if index == 1 else ""))
	var current_variant: String = stage_boss_variant
	if stage_id == 1 and not stage1_variant.is_empty():
		current_variant = stage1_variant
	return {
		"current_stage": stage_id,
		"current_boss": _get_stage_boss_name(stage_id, current_variant),
		"reached_stage_label": "스테이지 %d" % stage_id,
		"cleared_bosses": cleared,
	}


func _get_score_snapshot(registry: Object) -> Dictionary:
	var score_state: Object = _get_instance(registry, "match_score_state")
	if score_state != null and score_state.has_method("get_snapshot"):
		var snapshot_value: Variant = score_state.get_snapshot()
		if snapshot_value is Dictionary:
			return _normalize_score_snapshot(snapshot_value as Dictionary)
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state != null and scoreboard_state.has_method("get_snapshot"):
		var scoreboard_snapshot: Variant = scoreboard_state.get_snapshot()
		if scoreboard_snapshot is Dictionary:
			return _normalize_score_snapshot(scoreboard_snapshot as Dictionary)
	return {
		"player": _call_int(scoreboard_state, "get_player_points", 0),
		"boss": _call_int(scoreboard_state, "get_boss_points", 0),
		"win_goal": max(1, _call_int(scoreboard_state, "get_win_goal", MatchScoreState.WIN_GOAL)),
	}


func _normalize_score_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"player": int(snapshot.get("player_score", snapshot.get("player_points", snapshot.get("player", 0)))),
		"boss": int(snapshot.get("boss_score", snapshot.get("boss_points", snapshot.get("boss", 0)))),
		"win_goal": max(1, int(snapshot.get("win_goal", MatchScoreState.WIN_GOAL))),
	}


func _get_plaza_gold(registry: Object) -> int:
	var store: Object = _get_instance(registry, "plaza_save_store")
	if store == null:
		return 0
	if store.has_method("get_plaza_gold"):
		return max(0, int(store.get_plaza_gold()))
	var summary_value: Variant = store.get("plaza_gold")
	return max(0, int(summary_value)) if summary_value != null else 0


func _build_item_labels(items_value: Variant, active_item: bool) -> Array[String]:
	var labels: Array[String] = []
	var items := _as_array(items_value)
	for item_value in items:
		var label := _format_item_label(item_value, active_item)
		if label != "":
			labels.append(label)
	return labels


func _format_item_label(item_value: Variant, active_item: bool) -> String:
	if item_value is Dictionary:
		var item_data: Dictionary = item_value
		var label := str(item_data.get("display_name", item_data.get("label", item_data.get("title", ""))))
		if label != "":
			return label
		var item_name := _get_item_name(item_data)
		if item_name == "":
			return ""
		if active_item and _active_item_catalog != null and _active_item_catalog.has_method("get_display_name"):
			return str(_active_item_catalog.get_display_name(item_name))
		if not active_item and _mythic_item_catalog != null and _mythic_item_catalog.has_method("get_display_name"):
			return str(_mythic_item_catalog.get_display_name(item_name))
		return item_name
	return str(item_value)


func _get_item_name(item_data: Dictionary) -> String:
	for key in ["name", "item_name", "item_id", "effect", "id"]:
		var value := str(item_data.get(key, ""))
		if value != "":
			return value
	return ""


func _build_perk_labels(levels_value: Variant) -> Array[String]:
	var labels: Array[String] = []
	if not (levels_value is Dictionary):
		return labels
	var levels: Dictionary = levels_value
	var perk_ids: Array[String] = []
	for perk_id_value in levels.keys():
		perk_ids.append(str(perk_id_value))
	perk_ids.sort()
	for perk_id in perk_ids:
		var level := int(levels.get(perk_id, levels.get(StringName(perk_id), 0)))
		if level <= 0:
			continue
		var perk_data := _get_perk_data(perk_id)
		labels.append("%s %s" % [
			str(perk_data.get("name", perk_id)),
			LanguageSettings.format_mugong_rank(perk_data, level),
		])
	return labels


func _get_perk_name(perk_id: String) -> String:
	return str(_get_perk_data(perk_id).get("name", perk_id))


func _get_perk_data(perk_id: String) -> Dictionary:
	if _perk_catalog != null and _perk_catalog.has_method("get_perk_data"):
		var perk_value: Variant = _perk_catalog.get_perk_data(perk_id)
		if perk_value is Dictionary:
			return (perk_value as Dictionary).duplicate(true)
	return {"id": perk_id, "name": perk_id}


func _get_stage_boss_name(stage_id: int, stage_boss_variant: String = "") -> String:
	var entry: Dictionary = StageBossVariantCatalog.get_entry(stage_id, stage_boss_variant)
	var display_name: String = str(entry.get("display_name", ""))
	if display_name != "":
		return display_name
	return str(STAGE_BOSS_NAMES.get(stage_id, "스테이지 %d 보스" % stage_id))


func _is_dismiss_event(event: InputEvent, view_size: Vector2) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and _get_button_rect(view_size).has_point(mouse_event.position)
		)
	return false


func _dismiss(owner: Object) -> void:
	var callback := _pending_exit_callback
	reset()
	if callback.is_valid():
		callback.call()
	_queue_redraw(owner)


func _get_panel_rect(view_size: Vector2) -> Rect2:
	var panel_size := Vector2(
		minf(690.0, maxf(560.0, view_size.x - 72.0)),
		minf(555.0, maxf(500.0, view_size.y - 72.0))
	)
	return Rect2(view_size * 0.5 - panel_size * 0.5, panel_size)


func _get_button_rect(view_size: Vector2) -> Rect2:
	var panel_rect := _get_panel_rect(view_size)
	return Rect2(
		Vector2(panel_rect.end.x - BUTTON_SIZE.x - 24.0, panel_rect.end.y - 72.0),
		BUTTON_SIZE
	)


func _draw_stat_box(canvas: CanvasItem, font: Font, rect: Rect2, label: String, value: String, value_color: Color) -> void:
	canvas.draw_rect(rect, Color(0.08, 0.07, 0.09, 0.88))
	canvas.draw_rect(rect, Color(0.46, 0.18, 0.15, 0.56), false, 1.0)
	_draw_text(canvas, font, label, rect.position + Vector2(12.0, 23.0), 12, Color(0.72, 0.66, 0.64, 0.86), rect.size.x - 24.0)
	_draw_text(canvas, font, value, rect.position + Vector2(12.0, 55.0), 21, value_color, rect.size.x - 24.0)


func _draw_section(canvas: CanvasItem, font: Font, rect: Rect2, title: String, lines: Array, accent: Color) -> void:
	canvas.draw_rect(rect, Color(0.07, 0.065, 0.083, 0.78))
	canvas.draw_rect(rect, Color(0.35, 0.14, 0.13, 0.55), false, 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), accent)
	_draw_text(canvas, font, title, rect.position + Vector2(12.0, 27.0), 15, Color(0.95, 0.82, 0.76, 0.96), rect.size.x - 24.0)
	var y := rect.position.y + 62.0
	for line_value in lines:
		var wrapped := _wrap_summary_line(str(line_value), rect.size.x - 24.0, font, 13)
		for line in wrapped:
			_draw_text(canvas, font, line, Vector2(rect.position.x + 12.0, y), 13, Color(0.80, 0.82, 0.88, 0.90), rect.size.x - 24.0)
			y += 24.0
			if y > rect.end.y - 14.0:
				return


func _format_labels(labels_value: Variant) -> String:
	var labels := _as_array(labels_value)
	if labels.is_empty():
		return "없음"
	var visible: Array[String] = []
	var limit := mini(labels.size(), LIST_LIMIT)
	for index in range(limit):
		visible.append(str(labels[index]))
	if labels.size() > LIST_LIMIT:
		visible.append("+%d" % (labels.size() - LIST_LIMIT))
	return " · ".join(visible)


func _wrap_summary_line(text: String, width: float, font: Font, font_size: int) -> Array[String]:
	if font == null or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
		return [text]
	var parts := text.split(" · ", false)
	var lines: Array[String] = []
	var current := ""
	for part in parts:
		var next := part if current == "" else current + " · " + part
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
			current = next
		else:
			if current != "":
				lines.append(current)
			current = part
	if current != "":
		lines.append(current)
	return lines


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.78)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text(canvas: CanvasItem, font: Font, text: String, baseline: Vector2, font_size: int, color: Color, max_width: float) -> void:
	if font == null or text == "":
		return
	var fit_size := _fit_font_size(font, text, font_size, max_width)
	canvas.draw_string(font, baseline + Vector2(1.3, 1.3), text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fit_size, Color(0.0, 0.0, 0.0, color.a * 0.62))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fit_size, color)


func _fit_font_size(font: Font, text: String, font_size: int, max_width: float) -> int:
	var fit_size := font_size
	while fit_size > 10 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fit_size).x > max_width:
		fit_size -= 1
	return fit_size


func _get_ui_font() -> Font:
	return ThemeDB.fallback_font


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "":
		return null
	if registry.has_method("get_cached_instance"):
		var cached_value: Variant = registry.get_cached_instance(key)
		if cached_value != null and typeof(cached_value) == TYPE_OBJECT and is_instance_valid(cached_value):
			return cached_value as Object
	if registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null


func _call_int(target: Object, method_name: String, fallback: int) -> int:
	if target != null and target.has_method(method_name):
		return int(target.call(method_name))
	return fallback


func _read_int(owner: Object, key: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return int(value)


func _read_string(owner: Object, key: String, fallback: String) -> String:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return str(value)


func _read_array(owner: Object, key: String) -> Array:
	if owner == null:
		return []
	return _as_array(owner.get(key))


func _read_dictionary(owner: Object, key: String) -> Dictionary:
	if owner == null:
		return {}
	var value: Variant = owner.get(key)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
