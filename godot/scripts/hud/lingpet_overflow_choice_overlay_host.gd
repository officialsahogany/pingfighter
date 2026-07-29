extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const PANEL_SIZE := Vector2(590.0, 394.0)
const CHOICE_SIZE := Vector2(246.0, 126.0)
const CHOICE_REPLACE := 0
const CHOICE_ABSORB := 1
const _COPY_BY_LANGUAGE := {
	"ko": {"title": "새 수호령", "subtitle": "동행 방식을 선택하세요", "replace": "교체", "replace_desc": "현재 수호령과 교체", "absorb": "흡수", "absorb_desc": "수호령강화 1회", "absorb_only": "수집 완료 · 흡수 전용", "cancel": "ESC: 흡수"},
	"en": {"title": "New Guardian Spirit", "subtitle": "Choose how to receive it", "replace": "Replace", "replace_desc": "Replace the current guardian", "absorb": "Absorb", "absorb_desc": "Gain 1 Guardian Enhancement", "absorb_only": "Collected · Absorb only", "cancel": "ESC: Absorb"},
	"zh": {"title": "新守护灵", "subtitle": "选择接收方式", "replace": "替换", "replace_desc": "替换当前守护灵", "absorb": "吸收", "absorb_desc": "获得1次守护灵强化", "absorb_only": "已收集 · 仅可吸收", "cancel": "ESC：吸收"},
	"ja": {"title": "新しい守護霊", "subtitle": "受け入れ方を選択", "replace": "交代", "replace_desc": "現在の守護霊と交代", "absorb": "吸収", "absorb_desc": "守護霊強化を1回獲得", "absorb_only": "収集済み · 吸収のみ", "cancel": "ESC：吸収"},
	"es": {"title": "Nuevo espíritu guardián", "subtitle": "Elige cómo recibirlo", "replace": "Reemplazar", "replace_desc": "Reemplaza al guardián actual", "absorb": "Absorber", "absorb_desc": "Obtén 1 mejora de guardián", "absorb_only": "Ya obtenido · Solo absorber", "cancel": "ESC: Absorber"},
	"pt-BR": {"title": "Novo espírito guardião", "subtitle": "Escolha como recebê-lo", "replace": "Substituir", "replace_desc": "Substitui o guardião atual", "absorb": "Absorver", "absorb_desc": "Receba 1 aprimoramento", "absorb_only": "Já coletado · Só absorver", "cancel": "ESC: Absorver"},
	"ru": {"title": "Новый дух-хранитель", "subtitle": "Выберите способ принятия", "replace": "Заменить", "replace_desc": "Заменить текущего хранителя", "absorb": "Поглотить", "absorb_desc": "Получить 1 усиление", "absorb_only": "Уже собран · Только поглощение", "cancel": "ESC: Поглотить"},
}

var _selected_index := CHOICE_REPLACE
var _hover_index := -1
var _skill_icon_cache: Dictionary = {}


func prewarm_assets() -> void:
	for pet_id in LingpetCatalog.get_pet_ids():
		for skill in LingpetCatalog.get_active_skill_pool(pet_id):
			var path := str(skill.get("icon_texture_path", "")).strip_edges()
			if path != "" and not _skill_icon_cache.has(path):
				_skill_icon_cache[path] = ProjectResourceLoader.load_texture(
					path,
					"",
					"Failed to prewarm guardian replacement skill icon: %s"
				)


func draw(canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
	if canvas == null or runtime == null or view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	if not runtime.has_method("is_overflow_choice_active") or not bool(runtime.is_overflow_choice_active()):
		return
	var snapshot := _get_snapshot(runtime)
	var absorb_only := bool(snapshot.get("absorb_only", false))
	if absorb_only:
		_selected_index = CHOICE_ABSORB
	var copy := _get_copy()
	var layout := _build_layout(view_size)
	var panel: Rect2 = layout.get("panel", Rect2())
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.025, 0.04, 0.72), true)
	canvas.draw_rect(panel, Color(0.07, 0.09, 0.13, 0.98), true)
	canvas.draw_rect(panel, Color(0.45, 0.90, 0.88, 0.82), false, 2.0)
	var title_pos := panel.position + Vector2(28.0, 40.0)
	_draw_text(canvas, title_pos, str(copy.get("title", "New Guardian Spirit")), 25, Color(0.82, 1.0, 0.96), true)
	_draw_text(canvas, title_pos + Vector2(0.0, 29.0), str(copy.get("subtitle", "")), 15, Color(0.72, 0.84, 0.92), false)
	_draw_new_pet(canvas, layout.get("new_rect", Rect2()), snapshot, copy)
	_draw_choice(canvas, layout.get("replace_rect", Rect2()), CHOICE_REPLACE, copy, snapshot, absorb_only)
	_draw_choice(canvas, layout.get("absorb_rect", Rect2()), CHOICE_ABSORB, copy, snapshot, false)
	_draw_text(canvas, panel.end - Vector2(124.0, 17.0), str(copy.get("cancel", "ESC: Absorb")), 12, Color(0.58, 0.70, 0.76), false)


func handle_input(event: InputEvent, runtime: Object, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if runtime == null or not runtime.has_method("is_overflow_choice_active") or not bool(runtime.is_overflow_choice_active()):
		return false
	var snapshot := _get_snapshot(runtime)
	var absorb_only := bool(snapshot.get("absorb_only", false))
	var layout := _build_layout(view_size)
	if event is InputEventMouseMotion:
		_hover_index = _choice_at_position((event as InputEventMouseMotion).position, layout)
		if _hover_index == CHOICE_ABSORB or (_hover_index == CHOICE_REPLACE and not absorb_only):
			_selected_index = _hover_index
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			return _commit_choice(_choice_at_position(mouse_event.position, layout), absorb_only, runtime, owner, registry)
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode in [KEY_ESCAPE, KEY_BACKSPACE] or key_event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			return bool(runtime.commit_overflow_absorb(owner, registry))
		if key_event.keycode in [KEY_LEFT, KEY_RIGHT] or key_event.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
			_selected_index = CHOICE_ABSORB if absorb_only else 1 - _selected_index
			return true
		if key_event.keycode in [KEY_1, KEY_KP_1] or key_event.physical_keycode in [KEY_1, KEY_KP_1]:
			return _commit_choice(CHOICE_REPLACE, absorb_only, runtime, owner, registry)
		if key_event.keycode in [KEY_2, KEY_KP_2] or key_event.physical_keycode in [KEY_2, KEY_KP_2]:
			return _commit_choice(CHOICE_ABSORB, absorb_only, runtime, owner, registry)
		if key_event.keycode in [KEY_ENTER, KEY_SPACE] or key_event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			return _commit_choice(_selected_index, absorb_only, runtime, owner, registry)
	if GamepadInput.is_confirm_event(event):
		return _commit_choice(_selected_index, absorb_only, runtime, owner, registry)
	return true


func _commit_choice(choice: int, absorb_only: bool, runtime: Object, owner: Object, registry: Object) -> bool:
	if choice == CHOICE_REPLACE and not absorb_only:
		return bool(runtime.commit_overflow_replace(0, owner, registry))
	if choice == CHOICE_ABSORB or absorb_only:
		return bool(runtime.commit_overflow_absorb(owner, registry))
	return true


func _draw_new_pet(canvas: CanvasItem, rect: Rect2, snapshot: Dictionary, copy: Dictionary) -> void:
	canvas.draw_rect(rect, Color(0.10, 0.15, 0.18, 0.98), true)
	canvas.draw_rect(rect, Color(1.0, 0.77, 0.30, 0.92), false, 2.0)
	var name := str(snapshot.get("pending_display_name", snapshot.get("pending_pet_id", "")))
	_draw_text(canvas, rect.position + Vector2(20.0, 36.0), name, 23, Color(1.0, 0.91, 0.66), true)
	var skill_name := str(snapshot.get("replacement_skill_name", "")).strip_edges()
	var icon_rect := Rect2(rect.end - Vector2(56.0, 51.0), Vector2(36.0, 36.0))
	var icon_path := str(snapshot.get("replacement_skill_icon_path", ""))
	var texture: Texture2D = _skill_icon_cache.get(icon_path, null) as Texture2D
	if texture != null:
		canvas.draw_texture_rect(texture, icon_rect, false, Color.WHITE)
		canvas.draw_rect(icon_rect, Color(0.74, 1.0, 0.90, 0.8), false, 1.0)
	_draw_text(canvas, rect.position + Vector2(20.0, 70.0), skill_name, 15, Color(0.76, 0.91, 0.95), false)
	if bool(snapshot.get("absorb_only", false)):
		_draw_text(canvas, rect.position + Vector2(20.0, 94.0), str(copy.get("absorb_only", "Absorb only")), 13, Color(1.0, 0.66, 0.58), false)


func _draw_choice(canvas: CanvasItem, rect: Rect2, choice: int, copy: Dictionary, snapshot: Dictionary, disabled: bool) -> void:
	var selected := _selected_index == choice or _hover_index == choice
	var base := Color(0.075, 0.10, 0.15, 0.98)
	var border := Color(0.92, 0.48, 0.88, 0.95) if choice == CHOICE_REPLACE else Color(0.42, 0.96, 0.76, 0.95)
	if disabled:
		base = Color(0.055, 0.06, 0.075, 0.92)
		border = Color(0.30, 0.34, 0.38, 0.65)
	canvas.draw_rect(rect, base, true)
	canvas.draw_rect(rect, border, false, 2.2 if selected and not disabled else 1.3)
	var label := str(copy.get("replace" if choice == CHOICE_REPLACE else "absorb", ""))
	var desc := str(copy.get("replace_desc" if choice == CHOICE_REPLACE else "absorb_desc", ""))
	_draw_text(canvas, rect.position + Vector2(18.0, 42.0), label, 23, Color(0.92, 0.98, 1.0) if not disabled else Color(0.48, 0.51, 0.55), true)
	_draw_text(canvas, rect.position + Vector2(18.0, 76.0), desc, 14, Color(0.72, 0.84, 0.92) if not disabled else Color(0.40, 0.43, 0.47), false)
	if choice == CHOICE_REPLACE:
		var slots: Array = snapshot.get("slots", []) as Array
		var current_name := ""
		if not slots.is_empty() and slots[0] is Dictionary:
			current_name = str((slots[0] as Dictionary).get("display_name", ""))
		_draw_text(canvas, rect.position + Vector2(18.0, 102.0), current_name, 13, Color(0.78, 0.72, 0.94) if not disabled else Color(0.40, 0.43, 0.47), false)


func _build_layout(view_size: Vector2) -> Dictionary:
	var panel_size := Vector2(minf(PANEL_SIZE.x, view_size.x - 36.0), minf(PANEL_SIZE.y, view_size.y - 36.0))
	var panel := Rect2((view_size - panel_size) * 0.5, panel_size)
	var new_rect := Rect2(panel.position + Vector2(28.0, 82.0), Vector2(panel_size.x - 56.0, 108.0))
	var gap := 18.0
	var total_w := CHOICE_SIZE.x * 2.0 + gap
	var start_x := panel.position.x + (panel_size.x - total_w) * 0.5
	var choice_y := panel.position.y + 218.0
	return {
		"panel": panel,
		"new_rect": new_rect,
		"replace_rect": Rect2(Vector2(start_x, choice_y), CHOICE_SIZE),
		"absorb_rect": Rect2(Vector2(start_x + CHOICE_SIZE.x + gap, choice_y), CHOICE_SIZE),
	}


func _choice_at_position(pos: Vector2, layout: Dictionary) -> int:
	if (layout.get("replace_rect", Rect2()) as Rect2).has_point(pos):
		return CHOICE_REPLACE
	if (layout.get("absorb_rect", Rect2()) as Rect2).has_point(pos):
		return CHOICE_ABSORB
	return -1


func _get_snapshot(runtime: Object) -> Dictionary:
	if runtime != null and runtime.has_method("get_overflow_choice_snapshot"):
		var value: Variant = runtime.get_overflow_choice_snapshot()
		if value is Dictionary:
			return value as Dictionary
	return {}


func _get_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _COPY_BY_LANGUAGE.get(language, _COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true)


static func get_copy_for_language_for_tests(language: String) -> Dictionary:
	var value: Variant = _COPY_BY_LANGUAGE.get(language, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _draw_text(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, shadow: bool) -> void:
	if shadow:
		canvas.draw_string(TITLE_FONT, pos + Vector2(1.4, 1.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(0.0, 0.0, 0.0, 0.62))
	canvas.draw_string(TITLE_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
