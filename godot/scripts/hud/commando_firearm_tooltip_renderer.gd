extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const TOOLTIP_SIZE := Vector2(306.0, 228.0)
const BASE_PISTOL_INTERNAL_COOLDOWN_SECONDS := 1.0
const BERETTA_INTERNAL_COOLDOWN_SECONDS := BASE_PISTOL_INTERNAL_COOLDOWN_SECONDS / 2.0


func build_hover_state(panel_state: Dictionary, view_size: Vector2, scale_factor: float, context: Dictionary) -> Dictionary:
	var panel_rect: Rect2 = _get_rect2(panel_state.get("rect", Rect2()))
	var mouse_pos: Vector2 = _get_vector2(context, "mouse_pos", Vector2(-100000.0, -100000.0))
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0 or not panel_rect.has_point(mouse_pos):
		return {}
	return build_tooltip_state(panel_state, view_size, scale_factor, context)


func build_tooltip_state(panel_state: Dictionary, view_size: Vector2, scale_factor: float, context: Dictionary) -> Dictionary:
	if panel_state.is_empty():
		return {}
	var resolved_scale: float = max(0.85, float(panel_state.get("resolved_scale", scale_factor)))
	var panel_rect: Rect2 = _get_rect2(panel_state.get("rect", Rect2()))
	var weapon: Dictionary = _get_dict(panel_state.get("weapon", {}))
	var weapon_id: String = str(panel_state.get("current_weapon_id", weapon.get("weapon_id", "pistol")))
	var slingshot_state: Dictionary = _get_dict(context.get("commando_firearm_slingshot_state", panel_state.get("slingshot_state", {})))
	var skill_config_snapshot: Dictionary = _get_dict(context.get("skill_config_snapshot", {}))
	var title: String = LanguageSettings.translate_text(str(panel_state.get("title", weapon.get("display_name_ko", weapon_id))))
	var badge: String = LanguageSettings.translate_text(str(panel_state.get("badge", weapon.get("badge", ""))))
	var ammo_text: String = LanguageSettings.translate_text(str(panel_state.get("status", weapon.get("ammo_text", ""))))
	if weapon_id == "pistol":
		ammo_text = str(weapon.get("ammo_text", ammo_text))
	var cooldown_seconds: float = _get_cooldown_seconds(weapon_id, skill_config_snapshot)
	var tooltip_size := TOOLTIP_SIZE * resolved_scale
	var tooltip_rect := _build_tooltip_rect(panel_rect, tooltip_size, view_size, resolved_scale)
	var can_fire: bool = bool(weapon.get("can_fire", true))
	var ownership_text: String = _get_ownership_text(weapon_id, weapon)
	return {
		"tooltip_key": "commando_firearm:%s" % weapon_id,
		"rect": tooltip_rect,
		"panel_rect": panel_rect,
		"scale_factor": resolved_scale,
		"weapon_id": weapon_id,
		"title": title,
		"badge": badge,
		"ammo_text": ammo_text,
		"ownership_text": ownership_text,
		"ready_text": _get_ready_text(weapon_id, can_fire, slingshot_state),
		"reload_text": _get_reload_text(weapon_id, weapon, slingshot_state),
		"alias_text": _get_alias_text(weapon_id, title),
		"cooldown_seconds": cooldown_seconds,
		"cooldown_text": _format_cooldown(cooldown_seconds),
		"description": _get_description(weapon_id, skill_config_snapshot, weapon),
		"control_text": _get_control_text(weapon_id),
		"can_fire": can_fire,
		"color": _get_weapon_color(weapon_id),
	}


func draw(canvas: CanvasItem, tooltip_state: Dictionary) -> void:
	if canvas == null or tooltip_state.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var rect: Rect2 = _get_rect2(tooltip_state.get("rect", Rect2()))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale_factor: float = max(0.55, float(tooltip_state.get("scale_factor", 1.0)))
	var color: Color = _get_color(tooltip_state.get("color", Color(0.5, 0.7, 0.4)), Color(0.5, 0.7, 0.4))
	var padding: float = 10.0 * scale_factor
	var title_size: int = max(13, int(round(15.0 * scale_factor)))
	var normal_size: int = max(10, int(round(11.0 * scale_factor)))
	var small_size: int = max(9, int(round(10.0 * scale_factor)))

	_draw_panel(canvas, rect, Color(14.0 / 255.0, 18.0 / 255.0, 20.0 / 255.0, 0.94), color, 2.0 * scale_factor, 7.0 * scale_factor)
	var header_rect := Rect2(rect.position + Vector2(2.0, 2.0) * scale_factor, Vector2(rect.size.x - 4.0 * scale_factor, 32.0 * scale_factor))
	_draw_panel(canvas, header_rect, Color(color.r, color.g, color.b, 0.23), Color(0.0, 0.0, 0.0, 0.0), 0.0, 5.0 * scale_factor)

	var cursor := rect.position + Vector2(padding, padding)
	_draw_text(canvas, font, cursor, str(tooltip_state.get("title", "")), title_size, Color.WHITE)
	var badge: String = str(tooltip_state.get("badge", ""))
	if not badge.is_empty():
		var badge_size: Vector2 = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size)
		_draw_text(canvas, font, Vector2(rect.end.x - padding - badge_size.x, cursor.y + 2.0 * scale_factor), badge, small_size, Color(color.r, color.g, color.b, 0.96))

	cursor.y += 39.0 * scale_factor
	_draw_labeled_line(canvas, font, cursor, LanguageSettings.translate_text("탄약"), str(tooltip_state.get("ammo_text", "")), normal_size, Color(0.74, 0.88, 0.68))
	cursor.y += 19.0 * scale_factor
	var ready_color := Color(0.58, 1.0, 0.62) if bool(tooltip_state.get("can_fire", false)) else Color(1.0, 0.45, 0.38)
	_draw_labeled_line(canvas, font, cursor, LanguageSettings.translate_text("상태"), str(tooltip_state.get("ready_text", "")), normal_size, ready_color)
	cursor.y += 19.0 * scale_factor
	_draw_labeled_line(canvas, font, cursor, LanguageSettings.translate_text("쿨타임"), str(tooltip_state.get("cooldown_text", "")), normal_size, Color(0.84, 0.84, 0.86))
	cursor.y += 21.0 * scale_factor

	var body_lines: Array[String] = [
		str(tooltip_state.get("ownership_text", "")),
		str(tooltip_state.get("description", "")),
		str(tooltip_state.get("reload_text", "")),
		str(tooltip_state.get("alias_text", "")),
		str(tooltip_state.get("control_text", "")),
	]
	var max_width: float = rect.size.x - padding * 2.0
	for line in body_lines:
		if line.is_empty():
			continue
		for wrapped in _wrap_text(line, font, small_size, max_width, 2):
			_draw_text(canvas, font, cursor, wrapped, small_size, Color(0.83, 0.86, 0.82))
			cursor.y += 15.0 * scale_factor


func _build_tooltip_rect(panel_rect: Rect2, tooltip_size: Vector2, view_size: Vector2, scale_factor: float) -> Rect2:
	var pos := Vector2(panel_rect.end.x + 10.0 * scale_factor, panel_rect.position.y - 14.0 * scale_factor)
	pos.x = clamp(pos.x, 5.0, max(5.0, view_size.x - tooltip_size.x - 5.0))
	pos.y = clamp(pos.y, 10.0, max(10.0, view_size.y - tooltip_size.y - 10.0))
	return Rect2(pos, tooltip_size)


func _get_cooldown_seconds(weapon_id: String, skill_config_snapshot: Dictionary) -> float:
	if weapon_id == "pistol":
		return BASE_PISTOL_INTERNAL_COOLDOWN_SECONDS
	if weapon_id == "commando_pistol":
		return BERETTA_INTERNAL_COOLDOWN_SECONDS
	var cooldowns: Dictionary = _get_dict(skill_config_snapshot.get("cooldown_seconds", {}))
	if cooldowns.has(weapon_id):
		return float(cooldowns.get(weapon_id, 0.0))
	var skill_data: Dictionary = _get_dict(_get_dict(skill_config_snapshot.get("skill_data", {})).get(weapon_id, {}))
	return float(skill_data.get("cooldown", 0.0))


func _get_description(weapon_id: String, skill_config_snapshot: Dictionary, weapon: Dictionary = {}) -> String:
	if weapon_id == "pistol":
		var ammo_max: int = max(1, int(weapon.get("ammo_max", 5)))
		return _pick_language_text(
			"기본 권총은 %d발 탄창을 사용하며 준비음 뒤 조준 지연 후 발사합니다." % ammo_max,
			"The basic pistol uses a %d-round magazine and fires after a ready sound and aim delay." % ammo_max,
			"基础手枪使用%d发弹匣，并在准备音和瞄准延迟后开火。" % ammo_max,
			"基本拳銃は%d発マガジンを使い、準備音と照準遅延の後に発射します。" % ammo_max,
			"La pistola básica usa un cargador de %d balas y dispara tras el sonido de preparación y la demora de apuntado." % ammo_max,
			"A pistola básica usa um carregador de %d balas e dispara após o som de preparo e a demora de mira." % ammo_max,
			"Базовый пистолет использует магазин на %d патронов и стреляет после звука готовности и задержки прицеливания." % ammo_max
		)
	var skill_data: Dictionary = _get_dict(_get_dict(skill_config_snapshot.get("skill_data", {})).get(weapon_id, {}))
	var description: String = str(skill_data.get("description", ""))
	if description.is_empty():
		return _pick_language_text(
			"코만도 화기 스킬구슬과 같은 해금명을 사용합니다.",
			"Uses the same unlock name as the Commando firearm skill orb.",
			"使用与突击兵火器技能珠相同的解锁名。",
			"コマンドー火器スキル珠と同じ解放名を使います。",
			"Usa el mismo nombre de desbloqueo que el orbe de arma de Commando.",
			"Usa o mesmo nome de desbloqueio do orbe de arma do Commando.",
			"Использует то же имя открытия, что и орб огнестрельного навыка Commando."
		)
	return LanguageSettings.translate_text(str(description.split("\n", false)[0]))


func _get_ownership_text(weapon_id: String, weapon: Dictionary) -> String:
	if weapon_id == "pistol" or str(weapon.get("kind", "")) == "base":
		return _pick_language_text("기본 화기", "Base Weapon", "基础火器", "基本火器", "Arma base", "Arma base", "Базовое оружие")
	if bool(weapon.get("rental", false)) or str(weapon.get("kind", "")) == "rental":
		return _pick_language_text("대여 화기", "Rented Weapon", "租借火器", "レンタル火器", "Arma alquilada", "Arma alugada", "Арендованное оружие")
	return _pick_language_text("영구 화기", "Permanent Weapon", "永久火器", "永久火器", "Arma permanente", "Arma permanente", "Постоянное оружие")


func _get_ready_text(weapon_id: String, can_fire: bool, _slingshot_state: Dictionary) -> String:
	if weapon_id == "pistol":
		return _pick_language_text(
			"발사 가능" if can_fire else "탄약 없음",
			"Ready to Fire" if can_fire else "No Ammo",
			"可开火" if can_fire else "无弹药",
			"発射可能" if can_fire else "弾薬なし",
			"Lista para disparar" if can_fire else "Sin munición",
			"Pronta para disparar" if can_fire else "Sem munição",
			"Готово к стрельбе" if can_fire else "Нет патронов"
		)
	return _pick_language_text(
		"발사 가능" if can_fire else "탄약 없음",
		"Ready to Fire" if can_fire else "No Ammo",
		"可开火" if can_fire else "无弹药",
		"発射可能" if can_fire else "弾薬なし",
		"Lista para disparar" if can_fire else "Sin munición",
		"Pronta para disparar" if can_fire else "Sem munição",
		"Готово к стрельбе" if can_fire else "Нет патронов"
	)


func _get_reload_text(weapon_id: String, weapon: Dictionary, _slingshot_state: Dictionary) -> String:
	if weapon_id == "pistol":
		return _pick_language_text(
			"탄약이 0이면 좌클릭으로 150 게이지를 소모해 탄창을 한 발씩 가득 채웁니다.",
			"At 0 ammo, left-click spends 150 gauge to refill the magazine one round at a time.",
			"弹药为0时，左键消耗150能量并逐发填满弹匣。",
			"弾薬が0の時、左クリックで150ゲージを消費しマガジンを1発ずつ満たします。",
			"Con 0 munición, clic izquierdo gasta 150 de energía para rellenar el cargador bala por bala.",
			"Com 0 munição, clique esquerdo gasta 150 de energia para recarregar o carregador bala por bala.",
			"При 0 патронов левый клик тратит 150 энергии и пополняет магазин по одному патрону."
		)
	if bool(weapon.get("rental", false)) or str(weapon.get("kind", "")) == "rental":
		return _pick_language_text(
			"대여 화기는 재장전 대상이 아닙니다.",
			"Rented weapons cannot be reloaded.",
			"租借火器无法装填。",
			"レンタル火器はリロードできません。",
			"Las armas alquiladas no se pueden recargar.",
			"Armas alugadas não podem ser recarregadas.",
			"Арендованное оружие нельзя перезаряжать."
		)
	if weapon_id == "commando_pistol":
		return _pick_language_text(
			"기본 화기가 아니므로 발사 입력으로 재장전되지 않습니다. 재장전 스킬로 탄약을 보충합니다.",
			"This is not the base weapon, so fire input will not reload it. Refill ammo with the reload skill.",
			"这不是基础火器，开火输入不会装填。请用装填技能补充弹药。",
			"基本火器ではないため、発射入力ではリロードされません。リロードスキルで弾薬を補充します。",
			"No es el arma base, así que disparar no la recarga. Rellena munición con la habilidad de recarga.",
			"Esta não é a arma base, então disparar não a recarrega. Reponha munição com a habilidade de recarga.",
			"Это не базовое оружие, поэтому ввод стрельбы не перезаряжает его. Пополните патроны навыком перезарядки."
		)
	if weapon_id in ["ak47", "fire_support"]:
		return _pick_language_text(
			"재장전 게이지 완충 시 보충됩니다.",
			"Refills when the reload gauge is fully charged.",
			"装填能量充满后补充。",
			"リロードゲージが満タンになると補充されます。",
			"Se rellena cuando la energía de recarga está llena.",
			"Recarrega quando a energia de recarga fica cheia.",
			"Пополняется, когда энергия перезарядки заполнена."
		)
	return _pick_language_text(
		"재장전 스킬로 1발씩 보충됩니다.",
		"Reload skill refills one round at a time.",
		"装填技能会逐发补充。",
		"リロードスキルで1発ずつ補充されます。",
		"La habilidad de recarga rellena una bala a la vez.",
		"A habilidade de recarga repõe uma bala por vez.",
		"Навык перезарядки пополняет по одному патрону."
	)


func _get_alias_text(weapon_id: String, title: String) -> String:
	if weapon_id == "pistol":
		return _pick_language_text(
			"기본 슬롯: 장전 후 조준 지연을 거쳐 발사합니다.",
			"Base slot: fires after reload and aim delay.",
			"基础栏位：装填并经过瞄准延迟后开火。",
			"基本スロット：装填後、照準遅延を経て発射します。",
			"Espacio base: dispara tras recargar y demorar el apuntado.",
			"Espaço base: dispara após recarregar e esperar a mira.",
			"Базовая ячейка: стреляет после перезарядки и задержки прицеливания."
		)
	return _pick_language_text(
		"해금 스킬구슬: %s" % title,
		"Unlocked Skill Orb: %s" % title,
		"解锁技能珠：%s" % title,
		"解放スキル珠：%s" % title,
		"Orbe de habilidad desbloqueado: %s" % title,
		"Orbe de habilidade desbloqueado: %s" % title,
		"Открытый орб навыка: %s" % title
	)


func _get_control_text(weapon_id: String) -> String:
	if weapon_id == "pistol":
		return _pick_language_text(
			"좌클릭 또는 SPACE 발사 / 휠 전환",
			"Left Click or SPACE to fire / Wheel to switch",
			"左键或SPACE开火 / 滚轮切换",
			"左クリックまたはSPACEで発射 / ホイールで切替",
			"Clic izq. o SPACE para disparar / Rueda para cambiar",
			"Clique esq. ou SPACE para disparar / Roda para trocar",
			"Левый клик или SPACE для стрельбы / колесо для смены"
		)
	return _pick_language_text(
		"휠 전환 / 좌클릭 또는 SPACE 발사",
		"Wheel to switch / Left Click or SPACE to fire",
		"滚轮切换 / 左键或SPACE开火",
		"ホイールで切替 / 左クリックまたはSPACEで発射",
		"Rueda para cambiar / Clic izq. o SPACE para disparar",
		"Roda para trocar / Clique esq. ou SPACE para disparar",
		"Колесо для смены / левый клик или SPACE для стрельбы"
	)


func _format_cooldown(cooldown_seconds: float) -> String:
	if cooldown_seconds <= 0.0:
		return LanguageSettings.translate_text("없음")
	var language := LanguageSettings.get_language()
	if is_equal_approx(cooldown_seconds, roundf(cooldown_seconds)):
		if language == LanguageSettings.LANGUAGE_ENGLISH:
			return "%ds" % int(roundf(cooldown_seconds))
		if language == LanguageSettings.LANGUAGE_SPANISH:
			return "%ds" % int(roundf(cooldown_seconds))
		if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			return "%ds" % int(roundf(cooldown_seconds))
		if language == LanguageSettings.LANGUAGE_RUSSIAN:
			return "%dс" % int(roundf(cooldown_seconds))
		if language == LanguageSettings.LANGUAGE_CHINESE or language == LanguageSettings.LANGUAGE_JAPANESE:
			return "%d秒" % int(roundf(cooldown_seconds))
		return "%d초" % int(roundf(cooldown_seconds))
	if language == LanguageSettings.LANGUAGE_ENGLISH:
		return "%.1fs" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_SPANISH:
		return "%.1fs" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "%.1fs" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_RUSSIAN:
		return "%.1fс" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_CHINESE or language == LanguageSettings.LANGUAGE_JAPANESE:
		return "%.1f秒" % cooldown_seconds
	return "%.1f초" % cooldown_seconds


func _pick_language_text(korean: String, english: String, chinese: String, japanese: String = "", spanish: String = "", portuguese_brazil: String = "", russian: String = "") -> String:
	var language := LanguageSettings.get_language()
	if language == LanguageSettings.LANGUAGE_ENGLISH:
		return english
	if language == LanguageSettings.LANGUAGE_SPANISH:
		return spanish if not spanish.is_empty() else english
	if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		if not portuguese_brazil.is_empty():
			return portuguese_brazil
		return spanish if not spanish.is_empty() else english
	if language == LanguageSettings.LANGUAGE_RUSSIAN:
		if not russian.is_empty():
			return russian
		if not portuguese_brazil.is_empty():
			return portuguese_brazil
		return spanish if not spanish.is_empty() else english
	if language == LanguageSettings.LANGUAGE_CHINESE:
		return chinese
	if language == LanguageSettings.LANGUAGE_JAPANESE:
		return japanese if not japanese.is_empty() else LanguageSettings.translate_text(korean)
	return korean


func _draw_labeled_line(canvas: CanvasItem, font: Font, pos: Vector2, label: String, value: String, font_size: int, value_color: Color) -> void:
	_draw_text(canvas, font, pos, "%s:" % label, font_size, Color(0.62, 0.66, 0.64))
	_draw_text(canvas, font, pos + Vector2(54.0, 0.0), value, font_size, value_color)


func _draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> Vector2:
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(pos.x, pos.y + font.get_ascent(font_size))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return size


func _wrap_text(text: String, font: Font, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	if text.is_empty() or max_lines <= 0:
		return lines
	for hard_line in text.split("\n", false):
		var line: String = ""
		var segment: String = str(hard_line)
		for index in range(segment.length()):
			var glyph: String = segment.substr(index, 1)
			var candidate: String = line + glyph
			if line.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
				line = candidate
			else:
				lines.append(line)
				if lines.size() >= max_lines:
					return lines
				line = glyph
		if not line.is_empty():
			lines.append(line)
			if lines.size() >= max_lines:
				return lines
	return lines


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill_color: Color, border_color: Color, border_width: float, corner_radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	var width: int = max(0, int(round(border_width)))
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	var radius: int = max(0, int(round(corner_radius)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	canvas.draw_style_box(style, rect)


func _get_weapon_color(weapon_id: String) -> Color:
	match weapon_id:
		"net_gun":
			return Color(100.0 / 255.0, 180.0 / 255.0, 100.0 / 255.0)
		"fire_support", "suicide_drone":
			return Color(1.0, 100.0 / 255.0, 50.0 / 255.0)
		"bowling_trap":
			return Color(200.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0)
		"bazooka":
			return Color(220.0 / 255.0, 120.0 / 255.0, 70.0 / 255.0)
		"ak47":
			return Color(110.0 / 255.0, 135.0 / 255.0, 85.0 / 255.0)
		"commando_pistol":
			return Color(200.0 / 255.0, 180.0 / 255.0, 120.0 / 255.0)
	return Color(120.0 / 255.0, 180.0 / 255.0, 82.0 / 255.0)


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
