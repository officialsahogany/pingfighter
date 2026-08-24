extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const PANEL_SIZE := Vector2(590.0, 394.0)
const CHOICE_SIZE := Vector2(246.0, 126.0)
const COMPARE_PANEL_SIZE := Vector2(704.0, 664.0)
const COMPARE_CARD_SIZE := Vector2(314.0, 500.0)
# The card lists EVERY unlocked active/passive slot, so the block height is derived
# from the remaining card space instead of a fixed two-block layout.
const SKILL_LIST_TOP_OFFSET := 257.0
const SKILL_LIST_BOTTOM_PADDING := 8.0
const SKILL_ENTRY_BASE_HEIGHT := 45.0
const SKILL_ENTRY_LINE_HEIGHT := 13.0
const SKILL_ENTRY_MAX_DESCRIPTION_LINES := 2
const ACTION_BUTTON_SIZE := Vector2(160.0, 48.0)
const CHOICE_REPLACE := 0
const CHOICE_ABSORB := 1
const PHASE_CHOICE := 0
const PHASE_COMPARE := 1
const PHASE_CONFIRM := 2
const TOOLTIP_WIDTH := 390.0
const TOOLTIP_TEXT_SIZE := 12
const TOOLTIP_LINE_HEIGHT := 17.0
const _COPY_BY_LANGUAGE := {
	"ko": {"skill_none": "없음", "title": "새 수호령", "subtitle": "동행 방식을 선택하세요", "replace": "교체", "replace_desc": "현재 수호령과 교체", "absorb": "흡수", "absorb_desc": "수호령강화 1회", "absorb_only": "수집 완료 · 흡수 전용", "cancel": "ESC: 흡수", "base_note": "개체 보정은 교체 확정 후 결정됩니다.", "passive_note": "획득 시 공용 패시브 풀에서 1개가 결정됩니다.", "passive_pending_title": "획득 후 결정", "compare_title": "수호령 교체", "compare_subtitle": "능력치와 스킬을 비교하세요", "current_guardian": "기존 수호령", "replacement_guardian": "교체 대상", "cancel_action": "취소", "confirm": "확인", "confirm_question": "%s로 교체하시겠습니까?", "back_hint": "ESC: 이전 화면"},
	"en": {"skill_none": "None", "title": "New Guardian Spirit", "subtitle": "Choose how to receive it", "replace": "Replace", "replace_desc": "Replace the current guardian", "absorb": "Absorb", "absorb_desc": "Gain 1 Guardian Enhancement", "absorb_only": "Collected · Absorb only", "cancel": "ESC: Absorb", "base_note": "Individual stat bonuses are rolled after replacement is confirmed.", "passive_note": "One passive is chosen from the shared pool when acquired.", "passive_pending_title": "Chosen on acquisition", "compare_title": "Replace Guardian Spirit", "compare_subtitle": "Compare stats and skills", "current_guardian": "Current Guardian", "replacement_guardian": "Replacement", "cancel_action": "Cancel", "confirm": "Confirm", "confirm_question": "Replace with %s?", "back_hint": "ESC: Back"},
	"zh": {"skill_none": "无", "title": "新守护灵", "subtitle": "选择接收方式", "replace": "替换", "replace_desc": "替换当前守护灵", "absorb": "吸收", "absorb_desc": "获得1次守护灵强化", "absorb_only": "已收集 · 仅可吸收", "cancel": "ESC：吸收", "base_note": "确认替换后决定个体属性加成。", "passive_note": "获得时从公共被动池中决定1个被动。", "passive_pending_title": "获得后决定", "compare_title": "替换守护灵", "compare_subtitle": "比较能力值与技能", "current_guardian": "当前守护灵", "replacement_guardian": "替换对象", "cancel_action": "取消", "confirm": "确认", "confirm_question": "确定替换为%s吗？", "back_hint": "ESC：返回"},
	"ja": {"skill_none": "なし", "title": "新しい守護霊", "subtitle": "受け入れ方を選択", "replace": "交代", "replace_desc": "現在の守護霊と交代", "absorb": "吸収", "absorb_desc": "守護霊強化を1回獲得", "absorb_only": "収集済み · 吸収のみ", "cancel": "ESC：吸収", "base_note": "交代確定後に個体補正が決まります。", "passive_note": "獲得時に共通パッシブプールから1つ決まります。", "passive_pending_title": "獲得後に決定", "compare_title": "守護霊の交代", "compare_subtitle": "能力値とスキルを比較", "current_guardian": "現在の守護霊", "replacement_guardian": "交代対象", "cancel_action": "キャンセル", "confirm": "確認", "confirm_question": "%sと交代しますか？", "back_hint": "ESC：戻る"},
	"es": {"skill_none": "Ninguna", "title": "Nuevo espíritu guardián", "subtitle": "Elige cómo recibirlo", "replace": "Reemplazar", "replace_desc": "Reemplaza al guardián actual", "absorb": "Absorber", "absorb_desc": "Obtén 1 mejora de guardián", "absorb_only": "Ya obtenido · Solo absorber", "cancel": "ESC: Absorber", "base_note": "Los bonos individuales se deciden tras confirmar el reemplazo.", "passive_note": "Al obtenerlo se elige una pasiva del conjunto común.", "passive_pending_title": "Se decide al obtener", "compare_title": "Reemplazar guardián", "compare_subtitle": "Compara atributos y habilidades", "current_guardian": "Guardián actual", "replacement_guardian": "Reemplazo", "cancel_action": "Cancelar", "confirm": "Confirmar", "confirm_question": "¿Reemplazar por %s?", "back_hint": "ESC: Volver"},
	"pt-BR": {"skill_none": "Nenhuma", "title": "Novo espírito guardião", "subtitle": "Escolha como recebê-lo", "replace": "Substituir", "replace_desc": "Substitui o guardião atual", "absorb": "Absorver", "absorb_desc": "Receba 1 aprimoramento", "absorb_only": "Já coletado · Só absorver", "cancel": "ESC: Absorver", "base_note": "Os bônus individuais são definidos após confirmar a troca.", "passive_note": "Ao obter, uma passiva é escolhida do conjunto compartilhado.", "passive_pending_title": "Definida ao obter", "compare_title": "Substituir guardião", "compare_subtitle": "Compare atributos e habilidades", "current_guardian": "Guardião atual", "replacement_guardian": "Substituto", "cancel_action": "Cancelar", "confirm": "Confirmar", "confirm_question": "Substituir por %s?", "back_hint": "ESC: Voltar"},
	"ru": {"skill_none": "Нет", "title": "Новый дух-хранитель", "subtitle": "Выберите способ принятия", "replace": "Заменить", "replace_desc": "Заменить текущего хранителя", "absorb": "Поглотить", "absorb_desc": "Получить 1 усиление", "absorb_only": "Уже собран · Только поглощение", "cancel": "ESC: Поглотить", "base_note": "Личные бонусы определятся после подтверждения замены.", "passive_note": "При получении выбирается один навык из общего набора пассивов.", "passive_pending_title": "Выбирается при получении", "compare_title": "Замена хранителя", "compare_subtitle": "Сравните параметры и навыки", "current_guardian": "Текущий хранитель", "replacement_guardian": "Новый хранитель", "cancel_action": "Отмена", "confirm": "Подтвердить", "confirm_question": "Заменить на %s?", "back_hint": "ESC: Назад"},
}

var _phase := PHASE_CHOICE
var _selected_index := CHOICE_REPLACE
var _hover_index := -1
var _mouse_position := Vector2(-10000.0, -10000.0)
var _skill_icon_cache: Dictionary = {}
var _pet_art_cache: Dictionary = {}
var _tooltip_layout_cache_key := ""
var _tooltip_layout_cache: Dictionary = {}
var _active_pending_pet_id := ""
var _prewarm_icon_paths: Array[String] = []
var _prewarm_icon_index := 0
var _prewarm_assets_complete := false


func prewarm_assets() -> void:
	if _prewarm_assets_complete:
		return
	for path in _build_prewarm_icon_paths():
		_prewarm_skill_icon(path)
	_prewarm_icon_paths.clear()
	_prewarm_icon_index = 0
	_prewarm_assets_complete = true


func prewarm_assets_step() -> bool:
	if _prewarm_assets_complete:
		return true
	if _prewarm_icon_paths.is_empty() and _prewarm_icon_index == 0:
		_prewarm_icon_paths = _build_prewarm_icon_paths()
	if _prewarm_icon_index < _prewarm_icon_paths.size():
		var path := _prewarm_icon_paths[_prewarm_icon_index]
		var result := ProjectResourceLoader.prewarm_texture_threaded_step(path)
		if not bool(result.get("done", true)):
			return false
		_skill_icon_cache[path] = result.get("texture", null) as Texture2D
		_prewarm_icon_index += 1
		return false
	_prewarm_icon_paths.clear()
	_prewarm_icon_index = 0
	_prewarm_assets_complete = true
	return true


func _build_prewarm_icon_paths() -> Array[String]:
	var paths: Array[String] = []
	for pet_id in LingpetCatalog.get_pet_ids():
		for skill in LingpetCatalog.get_active_skill_pool(pet_id):
			var active_path := str(skill.get("icon_texture_path", "")).strip_edges()
			if active_path != "" and not paths.has(active_path):
				paths.append(active_path)
	for passive in LingpetCatalog.get_passive_skill_pool(LingpetCatalog.DEFAULT_PET_ID):
		var passive_path := str(passive.get("icon_texture_path", "")).strip_edges()
		if passive_path != "" and not paths.has(passive_path):
			paths.append(passive_path)
	return paths


func _prewarm_skill_icon(path_value: String) -> void:
	var path := path_value.strip_edges()
	if path == "" or _skill_icon_cache.has(path):
		return
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
	_sync_modal_identity(snapshot)
	var absorb_only := bool(snapshot.get("absorb_only", false))
	if absorb_only:
		_selected_index = CHOICE_ABSORB
	var copy := _get_copy()
	if _phase == PHASE_COMPARE or _phase == PHASE_CONFIRM:
		_draw_comparison(canvas, snapshot, copy, view_size)
		if _phase == PHASE_CONFIRM:
			_draw_confirmation(canvas, snapshot, copy, view_size)
		return
	var layout := _build_layout(view_size)
	var panel: Rect2 = layout.get("panel", Rect2())
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.025, 0.04, 0.72), true)
	canvas.draw_rect(panel, Color(0.07, 0.09, 0.13, 0.98), true)
	canvas.draw_rect(panel, Color(0.45, 0.90, 0.88, 0.82), false, 2.0)
	var title_pos := panel.position + Vector2(28.0, 40.0)
	_draw_text(canvas, title_pos, str(copy.get("title", "New Guardian Spirit")), 25, Color(0.82, 1.0, 0.96), true)
	_draw_text(canvas, title_pos + Vector2(0.0, 29.0), str(copy.get("subtitle", "")), 15, Color(0.72, 0.84, 0.92), false)
	_draw_new_pet(canvas, layout.get("new_rect", Rect2()), layout.get("new_art_rect", Rect2()), snapshot, copy)
	_draw_choice(canvas, layout.get("replace_rect", Rect2()), CHOICE_REPLACE, copy, snapshot, absorb_only)
	_draw_choice(canvas, layout.get("absorb_rect", Rect2()), CHOICE_ABSORB, copy, snapshot, false)
	_draw_text(canvas, panel.end - Vector2(124.0, 17.0), str(copy.get("cancel", "ESC: Absorb")), 12, Color(0.58, 0.70, 0.76), false)
	var art_rect: Rect2 = layout.get("new_art_rect", Rect2()) as Rect2
	if art_rect.has_point(_mouse_position):
		_draw_guardian_tooltip(canvas, art_rect, snapshot, copy, view_size)


func handle_input(event: InputEvent, runtime: Object, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if runtime == null or not runtime.has_method("is_overflow_choice_active") or not bool(runtime.is_overflow_choice_active()):
		return false
	var snapshot := _get_snapshot(runtime)
	_sync_modal_identity(snapshot)
	var absorb_only := bool(snapshot.get("absorb_only", false))
	var compare_only := bool(snapshot.get("compare_only", false))
	var layout := _get_phase_layout(view_size)
	if event is InputEventMouseMotion:
		_mouse_position = (event as InputEventMouseMotion).position
		_hover_index = _phase_action_at_position(_mouse_position, layout)
		if _phase != PHASE_CHOICE or _hover_index == CHOICE_ABSORB or (_hover_index == CHOICE_REPLACE and not absorb_only):
			_selected_index = _hover_index
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		_mouse_position = mouse_event.position
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			return _commit_phase_action(_phase_action_at_position(mouse_event.position, layout), absorb_only, compare_only, runtime, owner, registry)
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode in [KEY_ESCAPE, KEY_BACKSPACE] or key_event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			return _cancel_current_phase(runtime, owner, registry, compare_only)
		if key_event.keycode in [KEY_LEFT, KEY_RIGHT] or key_event.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
			_selected_index = CHOICE_ABSORB if _phase == PHASE_CHOICE and absorb_only else 1 - _selected_index
			return true
		if key_event.keycode in [KEY_1, KEY_KP_1] or key_event.physical_keycode in [KEY_1, KEY_KP_1]:
			return _commit_phase_action(CHOICE_REPLACE, absorb_only, compare_only, runtime, owner, registry)
		if key_event.keycode in [KEY_2, KEY_KP_2] or key_event.physical_keycode in [KEY_2, KEY_KP_2]:
			return _commit_phase_action(CHOICE_ABSORB, absorb_only, compare_only, runtime, owner, registry)
		if key_event.keycode in [KEY_ENTER, KEY_SPACE] or key_event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			return _commit_phase_action(_selected_index, absorb_only, compare_only, runtime, owner, registry)
	if GamepadInput.is_confirm_event(event):
		return _commit_phase_action(_selected_index, absorb_only, compare_only, runtime, owner, registry)
	return true


func _commit_phase_action(
	choice: int,
	absorb_only: bool,
	compare_only: bool,
	runtime: Object,
	owner: Object,
	registry: Object
) -> bool:
	if choice < 0:
		return true
	match _phase:
		PHASE_CHOICE:
			if choice == CHOICE_REPLACE and not absorb_only:
				_phase = PHASE_COMPARE
				_selected_index = CHOICE_REPLACE
				_hover_index = -1
				return true
			if choice == CHOICE_ABSORB or absorb_only:
				_reset_phase()
				return bool(runtime.commit_overflow_absorb(owner, registry))
		PHASE_COMPARE:
			if choice == CHOICE_REPLACE:
				_phase = PHASE_CONFIRM
				_selected_index = CHOICE_REPLACE
				_hover_index = -1
				return true
			if compare_only:
				_reset_phase()
				return bool(runtime.commit_overflow_absorb(owner, registry))
			_phase = PHASE_CHOICE
			_selected_index = CHOICE_REPLACE
			_hover_index = -1
			return true
		PHASE_CONFIRM:
			if choice == CHOICE_REPLACE:
				_reset_phase()
				return bool(runtime.commit_overflow_replace(0, owner, registry))
			_phase = PHASE_COMPARE
			_selected_index = CHOICE_REPLACE
			_hover_index = -1
			return true
	return true


func _cancel_current_phase(
	runtime: Object,
	owner: Object,
	registry: Object,
	compare_only: bool = false
) -> bool:
	if _phase == PHASE_CONFIRM:
		_phase = PHASE_COMPARE
		_selected_index = CHOICE_REPLACE
		_hover_index = -1
		return true
	if _phase == PHASE_COMPARE:
		if compare_only:
			_reset_phase()
			return bool(runtime.commit_overflow_absorb(owner, registry))
		_phase = PHASE_CHOICE
		_selected_index = CHOICE_REPLACE
		_hover_index = -1
		return true
	_reset_phase()
	return bool(runtime.commit_overflow_absorb(owner, registry))


func _sync_modal_identity(snapshot: Dictionary) -> void:
	var pending_pet_id := str(snapshot.get("pending_pet_id", "")).strip_edges().to_lower()
	if pending_pet_id == _active_pending_pet_id:
		return
	_active_pending_pet_id = pending_pet_id
	_reset_phase()
	if bool(snapshot.get("compare_only", false)):
		_phase = PHASE_COMPARE


func _reset_phase() -> void:
	_phase = PHASE_CHOICE
	_selected_index = CHOICE_REPLACE
	_hover_index = -1


func _draw_comparison(canvas: CanvasItem, snapshot: Dictionary, copy: Dictionary, view_size: Vector2) -> void:
	var layout := _build_compare_layout(view_size)
	var panel: Rect2 = layout.get("panel", Rect2()) as Rect2
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.025, 0.04, 0.78), true)
	canvas.draw_rect(panel, Color(0.055, 0.075, 0.115, 0.99), true)
	canvas.draw_rect(panel, Color(0.45, 0.90, 0.88, 0.88), false, 2.0)
	var title_pos := panel.position + Vector2(24.0, 34.0)
	_draw_text(canvas, title_pos, str(copy.get("compare_title", "Replace Guardian Spirit")), 24, Color(0.82, 1.0, 0.96), true)
	_draw_text(canvas, title_pos + Vector2(0.0, 25.0), str(copy.get("compare_subtitle", "")), 13, Color(0.68, 0.80, 0.88), false)
	var current_guardian := _get_current_guardian(snapshot)
	var replacement_guardian := _get_replacement_guardian(snapshot)
	_draw_comparison_card(
		canvas,
		layout.get("current_card", Rect2()),
		current_guardian,
		str(copy.get("current_guardian", "Current Guardian")),
		copy,
		Color(0.42, 0.88, 0.96, 0.95)
	)
	_draw_comparison_card(
		canvas,
		layout.get("replacement_card", Rect2()),
		replacement_guardian,
		str(copy.get("replacement_guardian", "Replacement")),
		copy,
		Color(1.0, 0.72, 0.30, 0.98)
	)
	var arrow_pos: Vector2 = layout.get("arrow_pos", Vector2()) as Vector2
	_draw_text(canvas, arrow_pos, "▶", 22, Color(0.70, 0.98, 0.88), true)
	_draw_action_button(canvas, layout.get("primary_button", Rect2()), CHOICE_REPLACE, str(copy.get("replace", "Replace")), Color(0.92, 0.48, 0.88, 0.98))
	_draw_action_button(canvas, layout.get("secondary_button", Rect2()), CHOICE_ABSORB, str(copy.get("cancel_action", "Cancel")), Color(0.48, 0.72, 0.82, 0.92))
	_draw_text(canvas, panel.end - Vector2(108.0, 13.0), str(copy.get("back_hint", "ESC: Back")), 11, Color(0.56, 0.68, 0.75), false)


func _draw_comparison_card(
	canvas: CanvasItem,
	rect: Rect2,
	guardian: Dictionary,
	section_label: String,
	copy: Dictionary,
	border: Color
) -> void:
	canvas.draw_rect(rect, Color(0.072, 0.10, 0.145, 0.99), true)
	canvas.draw_rect(rect, border, false, 1.7)
	_draw_text(canvas, rect.position + Vector2(14.0, 23.0), section_label, 13, border, true)
	var art_rect := Rect2(rect.position + Vector2((rect.size.x - 136.0) * 0.5, 32.0), Vector2(136.0, 112.0))
	canvas.draw_rect(art_rect, Color(0.025, 0.045, 0.075, 0.96), true)
	canvas.draw_circle(art_rect.get_center(), art_rect.size.y * 0.42, Color(border.r, border.g, border.b, 0.13))
	var art_texture := _get_guardian_art_texture(guardian)
	if art_texture != null:
		_draw_contained_texture(canvas, art_texture, art_rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.98))
	canvas.draw_rect(art_rect, Color(border.r, border.g, border.b, 0.72), false, 1.2)
	var info := _build_guardian_info_from_guardian(guardian, copy)
	_draw_centered_text(canvas, Vector2(rect.get_center().x, rect.position.y + 170.0), str(info.get("title", "")), 19, Color(1.0, 0.91, 0.66), true)
	var y := rect.position.y + 194.0
	var stat_rows: Array = info.get("stat_rows", []) as Array
	for i in range(mini(4, stat_rows.size())):
		var row: Dictionary = stat_rows[i] as Dictionary
		_draw_text(canvas, Vector2(rect.position.x + 14.0, y), LanguageSettings.translate_text(str(row.get("label", ""))), 10, Color(0.64, 0.78, 0.86), false)
		_draw_right_aligned_text(canvas, Vector2(rect.end.x - 14.0, y), str(row.get("value", "")), 10, Color(0.90, 1.0, 0.96))
		y += 15.0
	var entries: Array = info.get("skill_entries", []) as Array
	if entries.is_empty():
		return
	var list_top := rect.position.y + SKILL_LIST_TOP_OFFSET
	var list_height := maxf(0.0, rect.end.y - SKILL_LIST_BOTTOM_PADDING - list_top)
	var entry_height := list_height / float(entries.size())
	var description_budget := clampi(
		int(floor((entry_height - SKILL_ENTRY_BASE_HEIGHT) / SKILL_ENTRY_LINE_HEIGHT)),
		0,
		SKILL_ENTRY_MAX_DESCRIPTION_LINES
	)
	var entry_y := list_top
	for entry_value in entries:
		if entry_value is Dictionary:
			_draw_comparison_skill_entry(canvas, rect, entry_y, entry_value as Dictionary, description_budget)
		entry_y += entry_height


func _draw_comparison_skill_entry(
	canvas: CanvasItem,
	rect: Rect2,
	top_y: float,
	entry: Dictionary,
	description_budget: int
) -> void:
	_draw_card_divider(canvas, rect, top_y)
	var is_active := str(entry.get("kind", "active")) == "active"
	var accent := Color(0.38, 0.88, 1.0) if is_active else Color(0.48, 0.96, 0.72)
	var icon_rect := Rect2(Vector2(rect.position.x + 14.0, top_y + 4.0), Vector2(30.0, 30.0))
	_draw_skill_icon_box(canvas, icon_rect, str(entry.get("icon_path", "")), accent, "A" if is_active else "P")
	var text_x := rect.position.x + 53.0
	_draw_text(
		canvas,
		Vector2(text_x, top_y + 16.0),
		LanguageSettings.translate_text("액티브 스킬" if is_active else "패시브"),
		11,
		Color(0.48, 0.96, 0.86),
		true
	)
	_draw_text(
		canvas,
		Vector2(text_x, top_y + 31.0),
		str(entry.get("title", "")),
		11,
		Color(0.88, 0.97, 1.0) if is_active else Color(0.86, 0.96, 0.88),
		true
	)
	if description_budget <= 0:
		return
	var lines := _wrap_text(str(entry.get("description", "")), 10, rect.size.x - 28.0, description_budget)
	var y := top_y + SKILL_ENTRY_BASE_HEIGHT
	for line_value in lines:
		_draw_text(
			canvas,
			Vector2(rect.position.x + 14.0, y),
			str(line_value),
			10,
			Color(0.76, 0.86, 0.93) if is_active else Color(0.78, 0.90, 0.82),
			false
		)
		y += SKILL_ENTRY_LINE_HEIGHT


func _draw_card_divider(canvas: CanvasItem, rect: Rect2, y: float) -> void:
	canvas.draw_line(Vector2(rect.position.x + 14.0, y), Vector2(rect.end.x - 14.0, y), Color(0.38, 0.62, 0.68, 0.28), 1.0)


func _draw_skill_icon_box(canvas: CanvasItem, rect: Rect2, path: String, accent: Color, fallback: String) -> void:
	canvas.draw_rect(rect, Color(0.025, 0.045, 0.075, 0.98), true)
	var texture: Texture2D = _skill_icon_cache.get(path, null) as Texture2D
	if texture != null:
		_draw_contained_texture(canvas, texture, rect.grow(-3.0), Color(1.0, 1.0, 1.0, 0.98))
	else:
		_draw_centered_text(canvas, Vector2(rect.get_center().x, rect.position.y + 25.0), fallback, 14, Color(accent.r, accent.g, accent.b, 0.88), true)
	canvas.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.90), false, 1.3)


func _draw_action_button(canvas: CanvasItem, rect: Rect2, choice: int, label: String, accent: Color) -> void:
	var selected := _selected_index == choice or _hover_index == choice
	canvas.draw_rect(rect, Color(0.075, 0.10, 0.15, 0.99), true)
	canvas.draw_rect(rect, accent if selected else Color(accent.r, accent.g, accent.b, 0.62), false, 2.4 if selected else 1.3)
	_draw_centered_text(canvas, Vector2(rect.get_center().x, rect.position.y + 31.0), label, 17, Color(0.93, 0.98, 1.0), true)


func _draw_confirmation(canvas: CanvasItem, snapshot: Dictionary, copy: Dictionary, view_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.58), true)
	var layout := _build_confirm_layout(view_size)
	var panel: Rect2 = layout.get("panel", Rect2()) as Rect2
	canvas.draw_rect(panel, Color(0.055, 0.075, 0.115, 0.995), true)
	canvas.draw_rect(panel, Color(1.0, 0.72, 0.30, 0.98), false, 2.0)
	var replacement_guardian := _get_replacement_guardian(snapshot)
	var name := str(replacement_guardian.get("display_name", replacement_guardian.get("pet_id", "")))
	var question := _build_confirmation_question(name, copy)
	_draw_centered_text(canvas, Vector2(panel.get_center().x, panel.position.y + 65.0), question, 19, Color(1.0, 0.94, 0.78), true)
	_draw_action_button(canvas, layout.get("primary_button", Rect2()), CHOICE_REPLACE, str(copy.get("confirm", "Confirm")), Color(0.92, 0.48, 0.88, 0.98))
	_draw_action_button(canvas, layout.get("secondary_button", Rect2()), CHOICE_ABSORB, str(copy.get("cancel_action", "Cancel")), Color(0.48, 0.72, 0.82, 0.92))


func _build_confirmation_question(name: String, copy: Dictionary) -> String:
	if LanguageSettings.get_language() != "ko":
		return str(copy.get("confirm_question", "Replace with %s?")) % name
	var particle := "로"
	if not name.is_empty():
		var codepoint := name.unicode_at(name.length() - 1)
		if codepoint >= 0xAC00 and codepoint <= 0xD7A3:
			var final_consonant_index := (codepoint - 0xAC00) % 28
			if final_consonant_index != 0 and final_consonant_index != 8:
				particle = "으로"
	return "%s%s 교체하시겠습니까?" % [name, particle]


func _draw_new_pet(canvas: CanvasItem, rect: Rect2, art_rect: Rect2, snapshot: Dictionary, copy: Dictionary) -> void:
	canvas.draw_rect(rect, Color(0.10, 0.15, 0.18, 0.98), true)
	canvas.draw_rect(rect, Color(1.0, 0.77, 0.30, 0.92), false, 2.0)
	var art_hovered := art_rect.has_point(_mouse_position)
	canvas.draw_rect(art_rect, Color(0.035, 0.055, 0.08, 0.96), true)
	canvas.draw_circle(art_rect.get_center(), art_rect.size.y * 0.43, Color(0.20, 0.74, 0.72, 0.14))
	var art_texture := _get_guardian_art_texture(_get_replacement_guardian(snapshot))
	if art_texture != null:
		_draw_contained_texture(canvas, art_texture, art_rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.98))
	var art_border := Color(0.62, 1.0, 0.92, 1.0) if art_hovered else Color(0.42, 0.82, 0.80, 0.82)
	canvas.draw_rect(art_rect, art_border, false, 2.2 if art_hovered else 1.2)
	var badge_center := art_rect.end - Vector2(10.0, 10.0)
	canvas.draw_circle(badge_center, 7.0, Color(0.06, 0.10, 0.15, 0.96))
	canvas.draw_circle(badge_center, 7.0, art_border, false, 1.2)
	_draw_text(canvas, badge_center + Vector2(-1.8, 4.2), "i", 10, art_border, true)
	var name := str(snapshot.get("pending_display_name", snapshot.get("pending_pet_id", "")))
	var text_x := art_rect.end.x + 14.0
	_draw_text(canvas, Vector2(text_x, rect.position.y + 36.0), name, 23, Color(1.0, 0.91, 0.66), true)
	var skill_name := str(snapshot.get("replacement_skill_name", "")).strip_edges()
	var icon_rect := Rect2(rect.end - Vector2(56.0, 51.0), Vector2(36.0, 36.0))
	var icon_path := str(snapshot.get("replacement_skill_icon_path", ""))
	var texture: Texture2D = _skill_icon_cache.get(icon_path, null) as Texture2D
	if texture != null:
		canvas.draw_texture_rect(texture, icon_rect, false, Color.WHITE)
		canvas.draw_rect(icon_rect, Color(0.74, 1.0, 0.90, 0.8), false, 1.0)
	_draw_text(canvas, Vector2(text_x, rect.position.y + 70.0), skill_name, 15, Color(0.76, 0.91, 0.95), false)
	if bool(snapshot.get("absorb_only", false)):
		_draw_text(canvas, Vector2(text_x, rect.position.y + 94.0), str(copy.get("absorb_only", "Absorb only")), 13, Color(1.0, 0.66, 0.58), false)


func _get_guardian_art_texture(guardian: Dictionary) -> Texture2D:
	var pet_id := str(guardian.get("pet_id", "")).strip_edges().to_lower()
	var path := str(guardian.get("art_path", "")).strip_edges()
	if path == "" and pet_id != "":
		path = LingpetCatalog.get_visual_path(pet_id, "cutin_art")
	if path == "":
		return null
	if _pet_art_cache.has(path):
		var cached: Variant = _pet_art_cache[path]
		if cached is Texture2D:
			return cached as Texture2D
		_pet_art_cache.erase(path)
	# Production reaches this screen after the acquisition cut-in has staged the
	# same cutin_art path. The fallback keeps isolated debug/capture harnesses
	# functional without making the normal draw path decode the image twice.
	var texture := ProjectResourceLoader.get_cached_texture(path)
	if texture == null:
		texture = ProjectResourceLoader.load_imported_texture(
			path,
			"Missing guardian replacement art: %s",
			"Failed to load guardian replacement art: %s"
		)
	if texture != null:
		_pet_art_cache[path] = texture
	return texture


func _draw_contained_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color) -> void:
	if texture == null or rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var scale_factor := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	var draw_rect := Rect2(rect.get_center() - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect(texture, draw_rect, false, modulate)


func _draw_guardian_tooltip(
	canvas: CanvasItem,
	anchor_rect: Rect2,
	snapshot: Dictionary,
	copy: Dictionary,
	view_size: Vector2
) -> void:
	var width := minf(TOOLTIP_WIDTH, view_size.x - 16.0)
	var layout := _get_guardian_tooltip_layout(snapshot, copy, width - 28.0)
	var height := float(layout.get("height", 180.0))
	var pos := Vector2(anchor_rect.end.x + 10.0, anchor_rect.position.y - 4.0)
	if pos.x + width > view_size.x - 8.0:
		pos.x = anchor_rect.position.x - width - 10.0
	if pos.y + height > view_size.y - 8.0:
		pos.y = view_size.y - height - 8.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view_size.x - width - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view_size.y - height - 8.0))
	var tooltip_rect := Rect2(pos, Vector2(width, height))
	canvas.draw_rect(tooltip_rect, Color(0.035, 0.052, 0.082, 0.985), true)
	canvas.draw_rect(tooltip_rect, Color(0.50, 0.98, 0.88, 0.96), false, 2.0)
	var x := pos.x + 14.0
	var y := pos.y + 25.0
	_draw_text(canvas, Vector2(x, y), str(layout.get("title", "")), 18, Color(1.0, 0.91, 0.66), true)
	y += 24.0
	_draw_tooltip_section_label(canvas, Vector2(x, y), LanguageSettings.translate_text("능력치"))
	y += 18.0
	for row_value in layout.get("stat_rows", []) as Array:
		var row: Dictionary = row_value as Dictionary
		_draw_text(canvas, Vector2(x, y), LanguageSettings.translate_text(str(row.get("label", ""))), 11, Color(0.69, 0.82, 0.90), false)
		_draw_right_aligned_text(canvas, Vector2(tooltip_rect.end.x - 14.0, y), str(row.get("value", "")), 11, Color(0.90, 1.0, 0.96))
		y += 16.0
	y += 4.0
	_draw_tooltip_section_label(canvas, Vector2(x, y), LanguageSettings.translate_text("액티브 스킬"))
	y += 19.0
	var skill_icon_rect := Rect2(Vector2(x, y - 12.0), Vector2(38.0, 38.0))
	_draw_skill_icon_box(canvas, skill_icon_rect, str(layout.get("skill_icon_path", "")), Color(0.38, 0.88, 1.0), "A")
	_draw_text(canvas, Vector2(x + 48.0, y + 3.0), str(layout.get("skill_title", "")), 13, Color(0.88, 0.98, 1.0), true)
	y += 44.0
	for line_value in layout.get("skill_lines", []) as Array:
		_draw_text(canvas, Vector2(x, y), str(line_value), TOOLTIP_TEXT_SIZE, Color(0.80, 0.89, 0.95), false)
		y += TOOLTIP_LINE_HEIGHT
	y += 7.0
	_draw_tooltip_section_label(canvas, Vector2(x, y), LanguageSettings.translate_text("패시브"))
	y += 19.0
	var passive_icon_rect := Rect2(Vector2(x, y - 12.0), Vector2(38.0, 38.0))
	_draw_skill_icon_box(canvas, passive_icon_rect, str(layout.get("passive_icon_path", "")), Color(0.48, 0.96, 0.72), "?")
	_draw_text(canvas, Vector2(x + 48.0, y + 3.0), str(layout.get("passive_title", "")), 13, Color(0.88, 0.98, 0.90), true)
	y += 44.0
	for line_value in layout.get("passive_lines", []) as Array:
		_draw_text(canvas, Vector2(x, y), str(line_value), TOOLTIP_TEXT_SIZE, Color(0.84, 0.93, 0.86), false)
		y += TOOLTIP_LINE_HEIGHT
	y += 3.0
	for line_value in layout.get("note_lines", []) as Array:
		_draw_text(canvas, Vector2(x, y), str(line_value), 10, Color(0.62, 0.70, 0.76), false)
		y += 15.0


func _draw_tooltip_section_label(canvas: CanvasItem, pos: Vector2, label: String) -> void:
	_draw_text(canvas, pos, label, 12, Color(0.48, 0.96, 0.86), true)
	canvas.draw_line(pos + Vector2(0.0, 4.0), pos + Vector2(350.0, 4.0), Color(0.35, 0.72, 0.68, 0.30), 1.0)


func _draw_right_aligned_text(canvas: CanvasItem, right_pos: Vector2, text: String, size: int, color: Color) -> void:
	var text_width := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	_draw_text(canvas, Vector2(right_pos.x - text_width, right_pos.y), text, size, color, false)


func _get_guardian_tooltip_layout(snapshot: Dictionary, copy: Dictionary, text_width: float) -> Dictionary:
	var cache_key := "%s:%s:%d:%d" % [
		str(snapshot.get("pending_pet_id", "")),
		LanguageSettings.get_language(),
		int(round(text_width)),
		hash(snapshot),
	]
	if cache_key == _tooltip_layout_cache_key and not _tooltip_layout_cache.is_empty():
		return _tooltip_layout_cache
	var info := _build_guardian_info(snapshot, copy)
	var skill_lines := _wrap_text(str(info.get("skill_description", "")), TOOLTIP_TEXT_SIZE, text_width, 8)
	var passive_lines := _wrap_text(str(info.get("passive_description", "")), TOOLTIP_TEXT_SIZE, text_width, 4)
	var note_lines := _wrap_text(str(info.get("base_note", "")), 10, text_width, 2)
	var stat_rows: Array = info.get("stat_rows", []) as Array
	var height := (
		14.0 + 24.0 + 18.0 + float(stat_rows.size()) * 16.0 + 4.0
		+ 19.0 + 44.0 + float(skill_lines.size()) * TOOLTIP_LINE_HEIGHT + 7.0
		+ 19.0 + 44.0 + float(passive_lines.size()) * TOOLTIP_LINE_HEIGHT + 3.0
		+ float(note_lines.size()) * 15.0 + 12.0
	)
	_tooltip_layout_cache_key = cache_key
	_tooltip_layout_cache = {
		"title": str(info.get("title", "")),
		"stat_rows": stat_rows,
		"skill_title": str(info.get("skill_title", "")),
		"skill_icon_path": str(info.get("skill_icon_path", "")),
		"skill_lines": skill_lines,
		"passive_title": str(info.get("passive_title", "")),
		"passive_icon_path": str(info.get("passive_icon_path", "")),
		"passive_lines": passive_lines,
		"note_lines": note_lines,
		"height": height,
	}
	return _tooltip_layout_cache


static func _build_guardian_info(snapshot: Dictionary, copy: Dictionary) -> Dictionary:
	return _build_guardian_info_from_guardian(_get_replacement_guardian(snapshot), copy)


static func _build_guardian_info_from_guardian(guardian: Dictionary, copy: Dictionary) -> Dictionary:
	var stats: Dictionary = guardian.get("stats", {}) as Dictionary
	var speed_default := float(stats.get("patrol_speed_default", 0.0))
	var speed_min := float(stats.get("patrol_speed_min", 0.0))
	var speed_max := float(stats.get("patrol_speed_max", 0.0))
	var stat_rows: Array[Dictionary] = []
	if speed_default > 0.0:
		stat_rows.append({
			"label": "이동 속도",
			"value": "%spx/s (%s~%s)" % [
				CharacterInfoOverlayFormatter.format_plain_number(speed_default),
				CharacterInfoOverlayFormatter.format_plain_number(speed_min),
				CharacterInfoOverlayFormatter.format_plain_number(speed_max),
			],
		})
	var catch_width := float(stats.get("catch_width", 0.0))
	var catch_height := float(stats.get("catch_height", 0.0))
	if catch_width > 0.0 and catch_height > 0.0:
		stat_rows.append({
			"label": "몸집크기",
			"value": "%sx%spx" % [
				CharacterInfoOverlayFormatter.format_plain_number(catch_width),
				CharacterInfoOverlayFormatter.format_plain_number(catch_height),
			],
		})
	var hit_gain := float(stats.get("hit_gauge_gain", 0.0))
	if hit_gain > 0.0:
		stat_rows.append({"label": "기력 획득량", "value": "%spt" % CharacterInfoOverlayFormatter.format_plain_number(hit_gain)})
	var defense_rate := float(stats.get("defense_rate", 0.0))
	var appearance_rate := float(stats.get("appearance_rate", 0.0))
	if defense_rate > 0.0:
		stat_rows.append({"label": "방어율", "value": CharacterInfoOverlayFormatter.format_percent_text(defense_rate * 100.0)})
	elif appearance_rate > 0.0:
		stat_rows.append({"label": "출현율", "value": CharacterInfoOverlayFormatter.format_percent_text(appearance_rate * 100.0)})
	var active_entries := _build_skill_entries(guardian, "active_skills", "active", {
		"name": "active_skill_name",
		"level": "active_skill_level",
		"cooldown": "active_skill_cooldown",
		"icon": "active_skill_icon_path",
		"description": "active_skill_description",
	})
	var passive_entries := _build_skill_entries(guardian, "passive_skills", "passive", {
		"name": "passive_skill_name",
		"level": "passive_skill_level",
		"cooldown": "",
		"icon": "passive_skill_icon_path",
		"description": "passive_skill_description",
	})
	if active_entries.is_empty():
		active_entries.append(_build_empty_slot_entry(guardian, "active_skills", "active", copy))
	if passive_entries.is_empty():
		passive_entries.append(_build_empty_slot_entry(guardian, "passive_skills", "passive", copy))
	var primary_active: Dictionary = active_entries[0]
	var primary_passive: Dictionary = passive_entries[0]
	var passive_title := str(primary_passive.get("title", ""))
	var passive_description := str(primary_passive.get("description", ""))
	var passive_note := passive_title
	if passive_description != "":
		passive_note += "\n" + passive_description
	var skill_entries: Array[Dictionary] = []
	skill_entries.append_array(active_entries)
	skill_entries.append_array(passive_entries)
	return {
		"title": str(guardian.get("display_name", guardian.get("pet_id", ""))),
		"stat_rows": stat_rows,
		"skill_entries": skill_entries,
		"skill_title": str(primary_active.get("title", "")),
		"skill_description": str(primary_active.get("description", "")),
		"skill_icon_path": str(primary_active.get("icon_path", "")),
		"passive_title": passive_title,
		"passive_description": passive_description,
		"passive_icon_path": str(primary_passive.get("icon_path", "")),
		"passive_note": passive_note,
		"base_note": str(copy.get("base_note", "")) if bool(guardian.get("pending_roll", false)) else "",
	}


# An empty slot has two very different meanings and must not be collapsed:
#   * the producer published per-slot arrays and they came back EMPTY -> the roll is
#     already known and this guardian simply HAS no skill in that slot -> "없음".
#   * the producer only knows the flat legacy keys (no per-slot array at all) -> the
#     passive genuinely has not been decided yet -> keep the pending-roll copy.
# Collapsing the first case into the pending copy would promise a passive that is
# never coming; collapsing it into a pool fallback would invent one outright.
static func _build_empty_slot_entry(
	guardian: Dictionary,
	list_key: String,
	kind: String,
	copy: Dictionary
) -> Dictionary:
	if not guardian.has(list_key) and kind == "passive":
		return {
			"kind": kind,
			"title": str(copy.get("passive_pending_title", "Chosen on acquisition")),
			"description": str(copy.get("passive_note", "")),
			"icon_path": "",
		}
	return {
		"kind": kind,
		"title": str(copy.get("skill_none", "None")),
		"description": "",
		"icon_path": "",
	}


# Every unlocked slot must be listed: a Guardian Enhancement can unlock a second
# active or passive, and showing only slot 0 reads as "the guardian lost a skill".
# The list key is preferred; the flat primary keys stay as the legacy fallback for
# snapshots (debug capture harnesses) that never learned the per-slot arrays.
static func _build_skill_entries(
	guardian: Dictionary,
	list_key: String,
	kind: String,
	legacy_keys: Dictionary
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var raw_list: Variant = guardian.get(list_key, [])
	if raw_list is Array and not (raw_list as Array).is_empty():
		for value in raw_list as Array:
			if not (value is Dictionary):
				continue
			var skill := value as Dictionary
			if str(skill.get("name", "")).strip_edges() == "":
				continue
			entries.append(_build_skill_entry(
				kind,
				str(skill.get("name", "")),
				int(skill.get("level", 0)),
				float(skill.get("cooldown", 0.0)),
				str(skill.get("icon_path", "")),
				str(skill.get("description", ""))
			))
		return entries
	var legacy_name := str(guardian.get(str(legacy_keys.get("name", "")), "")).strip_edges()
	if legacy_name == "":
		return entries
	var cooldown_key := str(legacy_keys.get("cooldown", ""))
	entries.append(_build_skill_entry(
		kind,
		legacy_name,
		int(guardian.get(str(legacy_keys.get("level", "")), 0)),
		float(guardian.get(cooldown_key, 0.0)) if cooldown_key != "" else 0.0,
		str(guardian.get(str(legacy_keys.get("icon", "")), "")),
		str(guardian.get(str(legacy_keys.get("description", "")), ""))
	))
	return entries


static func _build_skill_entry(
	kind: String,
	name: String,
	level: int,
	cooldown: float,
	icon_path: String,
	description: String
) -> Dictionary:
	# The skill NAME needs translating too, not just the description: the catalog stores
	# Korean names and LanguageSettingsData carries their 6 non-Korean forms, so leaving
	# the raw name here ships a half-Korean title in every non-Korean UI.
	var title := LanguageSettings.translate_text(name)
	if level > 0:
		title += " · Lv.%d" % level
	if cooldown > 0.0:
		title += " · %s %s" % [
			LanguageSettings.translate_text("쿨타임"),
			CharacterInfoOverlayFormatter.format_seconds_text(cooldown),
		]
	return {
		"kind": kind,
		"title": title,
		"description": LanguageSettings.translate_text(description).strip_edges(),
		"icon_path": icon_path,
	}


static func _get_replacement_guardian(snapshot: Dictionary) -> Dictionary:
	var replacement_value: Variant = snapshot.get("replacement_guardian", {})
	if replacement_value is Dictionary and not (replacement_value as Dictionary).is_empty():
		return (replacement_value as Dictionary).duplicate(true)
	return {
		"pet_id": str(snapshot.get("pending_pet_id", "")),
		"display_name": str(snapshot.get("pending_display_name", snapshot.get("pending_pet_id", ""))),
		"art_path": str(snapshot.get("pending_art_path", "")),
		"stats": (snapshot.get("pending_stats", {}) as Dictionary).duplicate(true),
		"active_skill_name": str(snapshot.get("replacement_skill_name", "")),
		"active_skill_description": str(snapshot.get("replacement_skill_description", "")),
		"active_skill_cooldown": float(snapshot.get("replacement_skill_cooldown", 0.0)),
		"active_skill_icon_path": str(snapshot.get("replacement_skill_icon_path", "")),
		"active_skill_level": 1,
		"passive_skill_name": "",
		"passive_skill_description": "",
		"passive_skill_icon_path": "",
		"passive_skill_level": 0,
		"pending_roll": not bool(snapshot.get("absorb_only", false)),
	}


static func _get_current_guardian(snapshot: Dictionary) -> Dictionary:
	var current_value: Variant = snapshot.get("current_guardian", {})
	if current_value is Dictionary and not (current_value as Dictionary).is_empty():
		return (current_value as Dictionary).duplicate(true)
	var slots: Array = snapshot.get("slots", []) as Array
	if slots.is_empty() or not (slots[0] is Dictionary):
		return {}
	var slot := slots[0] as Dictionary
	var pet_id := str(slot.get("pet_id", ""))
	var default_loadout := LingpetCatalog.build_default_loadout(pet_id)
	var active_skill := LingpetCatalog.get_active_skill(
		pet_id,
		str(default_loadout.get("active_skill_id", "")),
		maxi(1, int(default_loadout.get("active_skill_level", 1)))
	)
	var passive_skill := LingpetCatalog.get_passive_skill(
		pet_id,
		str(default_loadout.get("passive_skill_id", "")),
		maxi(1, int(default_loadout.get("passive_skill_level", 1)))
	)
	return {
		"pet_id": pet_id,
		"display_name": str(slot.get("display_name", LingpetCatalog.get_display_name(pet_id))),
		"art_path": LingpetCatalog.get_visual_path(pet_id, "cutin_art"),
		"stats": {
			"patrol_speed_default": LingpetCatalog.get_stat(pet_id, "patrol_speed_default", 0.0),
			"patrol_speed_min": LingpetCatalog.get_stat(pet_id, "patrol_speed_min", 0.0),
			"patrol_speed_max": LingpetCatalog.get_stat(pet_id, "patrol_speed_max", 0.0),
			"catch_width": LingpetCatalog.get_stat(pet_id, "catch_width", 0.0),
			"catch_height": LingpetCatalog.get_stat(pet_id, "catch_height", 0.0),
			"defense_rate": LingpetCatalog.get_stat(pet_id, "defense_rate", 0.0),
			"appearance_rate": LingpetCatalog.get_stat(pet_id, "appearance_rate", 0.0),
			"hit_gauge_gain": LingpetCatalog.get_stat(pet_id, "hit_gauge_gain", 0.0),
		},
		"active_skill_name": str(active_skill.get("name", "")),
		"active_skill_description": str(active_skill.get("description", "")),
		"active_skill_cooldown": float(active_skill.get("cooldown", 0.0)),
		"active_skill_icon_path": str(active_skill.get("icon_texture_path", "")),
		"active_skill_level": maxi(1, int(default_loadout.get("active_skill_level", 1))),
		"passive_skill_name": str(passive_skill.get("name", "")),
		"passive_skill_description": str(passive_skill.get("description", "")),
		"passive_skill_icon_path": str(passive_skill.get("icon_texture_path", "")),
		"passive_skill_level": maxi(1, int(default_loadout.get("passive_skill_level", 1))),
		"pending_roll": false,
	}


func _wrap_text(text: String, size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph_value in text.split("\n"):
		var paragraph := str(paragraph_value).strip_edges()
		if paragraph == "":
			continue
		var current := ""
		for word_value in paragraph.split(" ", false):
			var word := str(word_value)
			var candidate := word if current == "" else current + " " + word
			if TITLE_FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= max_width:
				current = candidate
				continue
			if current != "":
				lines.append(current)
				if lines.size() >= max_lines:
					return lines
			current = word
		if current != "" and lines.size() < max_lines:
			lines.append(current)
	return lines


static func build_guardian_info_for_tests(snapshot: Dictionary, language: String = "ko") -> Dictionary:
	var copy_value: Variant = _COPY_BY_LANGUAGE.get(language, _COPY_BY_LANGUAGE["en"])
	return _build_guardian_info(snapshot, copy_value as Dictionary)


static func build_current_guardian_info_for_tests(snapshot: Dictionary, language: String = "ko") -> Dictionary:
	var copy_value: Variant = _COPY_BY_LANGUAGE.get(language, _COPY_BY_LANGUAGE["en"])
	return _build_guardian_info_from_guardian(_get_current_guardian(snapshot), copy_value as Dictionary)


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
	var new_art_rect := Rect2(new_rect.position + Vector2(8.0, 5.0), Vector2(104.0, 98.0))
	var gap := 18.0
	var total_w := CHOICE_SIZE.x * 2.0 + gap
	var start_x := panel.position.x + (panel_size.x - total_w) * 0.5
	var choice_y := panel.position.y + 218.0
	return {
		"panel": panel,
		"new_rect": new_rect,
		"new_art_rect": new_art_rect,
		"replace_rect": Rect2(Vector2(start_x, choice_y), CHOICE_SIZE),
		"absorb_rect": Rect2(Vector2(start_x + CHOICE_SIZE.x + gap, choice_y), CHOICE_SIZE),
	}


func _build_compare_layout(view_size: Vector2) -> Dictionary:
	var panel_size := Vector2(minf(COMPARE_PANEL_SIZE.x, view_size.x - 28.0), minf(COMPARE_PANEL_SIZE.y, view_size.y - 28.0))
	var panel := Rect2((view_size - panel_size) * 0.5, panel_size)
	var card_gap := 28.0
	var card_width := minf(COMPARE_CARD_SIZE.x, (panel_size.x - 48.0 - card_gap) * 0.5)
	var card_height := minf(COMPARE_CARD_SIZE.y, panel_size.y - 150.0)
	var current_card := Rect2(panel.position + Vector2(24.0, 72.0), Vector2(card_width, card_height))
	var replacement_card := Rect2(Vector2(current_card.end.x + card_gap, current_card.position.y), Vector2(card_width, card_height))
	var button_gap := 18.0
	var total_button_width := ACTION_BUTTON_SIZE.x * 2.0 + button_gap
	var button_x := panel.position.x + (panel.size.x - total_button_width) * 0.5
	var button_y := panel.end.y - 69.0
	return {
		"panel": panel,
		"current_card": current_card,
		"replacement_card": replacement_card,
		"arrow_pos": Vector2(current_card.end.x + 4.0, current_card.position.y + 196.0),
		"primary_button": Rect2(Vector2(button_x, button_y), ACTION_BUTTON_SIZE),
		"secondary_button": Rect2(Vector2(button_x + ACTION_BUTTON_SIZE.x + button_gap, button_y), ACTION_BUTTON_SIZE),
	}


func _build_confirm_layout(view_size: Vector2) -> Dictionary:
	var panel_size := Vector2(minf(460.0, view_size.x - 36.0), minf(200.0, view_size.y - 36.0))
	var panel := Rect2((view_size - panel_size) * 0.5, panel_size)
	var button_size := Vector2(132.0, 44.0)
	var gap := 16.0
	var start_x := panel.position.x + (panel.size.x - button_size.x * 2.0 - gap) * 0.5
	var button_y := panel.end.y - 66.0
	return {
		"panel": panel,
		"primary_button": Rect2(Vector2(start_x, button_y), button_size),
		"secondary_button": Rect2(Vector2(start_x + button_size.x + gap, button_y), button_size),
	}


func _get_phase_layout(view_size: Vector2) -> Dictionary:
	if _phase == PHASE_CONFIRM:
		return _build_confirm_layout(view_size)
	if _phase == PHASE_COMPARE:
		return _build_compare_layout(view_size)
	return _build_layout(view_size)


func _phase_action_at_position(pos: Vector2, layout: Dictionary) -> int:
	if _phase == PHASE_CHOICE:
		if (layout.get("replace_rect", Rect2()) as Rect2).has_point(pos):
			return CHOICE_REPLACE
		if (layout.get("absorb_rect", Rect2()) as Rect2).has_point(pos):
			return CHOICE_ABSORB
		return -1
	if (layout.get("primary_button", Rect2()) as Rect2).has_point(pos):
		return CHOICE_REPLACE
	if (layout.get("secondary_button", Rect2()) as Rect2).has_point(pos):
		return CHOICE_ABSORB
	return -1


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


func get_new_pet_art_rect_for_tests(view_size: Vector2) -> Rect2:
	return _build_layout(view_size).get("new_art_rect", Rect2()) as Rect2


func get_phase_for_tests() -> int:
	return _phase


func get_compare_layout_for_tests(view_size: Vector2) -> Dictionary:
	return _build_compare_layout(view_size).duplicate(true)


func get_confirm_layout_for_tests(view_size: Vector2) -> Dictionary:
	return _build_confirm_layout(view_size).duplicate(true)


func _draw_text(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, shadow: bool) -> void:
	if shadow:
		canvas.draw_string(TITLE_FONT, pos + Vector2(1.4, 1.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(0.0, 0.0, 0.0, 0.62))
	canvas.draw_string(TITLE_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_centered_text(canvas: CanvasItem, center_baseline: Vector2, text: String, size: int, color: Color, shadow: bool) -> void:
	var text_width := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	_draw_text(canvas, center_baseline - Vector2(text_width * 0.5, 0.0), text, size, color, shadow)
