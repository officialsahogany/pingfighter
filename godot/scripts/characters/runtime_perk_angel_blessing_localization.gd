extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const EN := {
	"title": "Three Heavenly Omens",
	"rolling": "The celestial seal is reading this stage's omens...",
	"result": "Heavenly omens for this stage",
	"continue": "Confirm to receive the omens",
	"current": "Current omens (%d)",
	"next_stage_trigger": "Activates after the next stage begins",
	"next_stage_wait": "Omen reading queued for the next stage",
	"current_stage_wait": "Omen result is waiting for this stage",
	"paddle_size": "Body size",
	"gauge_max": "Maximum gauge",
	"item_cooldown": "Item cooldown",
	"active_cooldown": "Skill cooldown",
	"dash_cooldown": "Dash cooldown",
	"move_speed": "Move speed",
}

const KO := {
	"title": "천운삼괘",
	"rolling": "천문이 이번 스테이지의 괘상을 읽는 중...",
	"result": "이번 스테이지의 천운",
	"continue": "확인하여 천운을 받아들임",
	"current": "현재 천운 (%d)",
	"next_stage_trigger": "다음 스테이지 시작 후 발동",
	"next_stage_wait": "다음 스테이지에 괘상 대기",
	"current_stage_wait": "현재 스테이지 괘상 결과 대기",
	"paddle_size": "몸집 크기",
	"gauge_max": "최대 기력",
	"item_cooldown": "아이템 쿨타임",
	"active_cooldown": "초식 쿨타임",
	"dash_cooldown": "활주 재충전",
	"move_speed": "이동 속도",
}

const LOCALIZED := {
	"zh": {
		"title": "天运三卦", "rolling": "天印正在解读本关卦象……", "result": "本关天运", "continue": "确认并接受天运",
		"current": "当前天运（%d）", "next_stage_trigger": "下一关开始后发动", "next_stage_wait": "卦象将在下一关解读", "current_stage_wait": "本关卦象结果等待中",
		"paddle_size": "体型", "gauge_max": "最大能量", "item_cooldown": "道具冷却", "active_cooldown": "技能冷却", "dash_cooldown": "冲刺冷却", "move_speed": "移动速度",
	},
	"ja": {
		"title": "天運三卦", "rolling": "天印がこのステージの卦象を読み取り中…", "result": "今回の天運", "continue": "決定して天運を受け入れる",
		"current": "現在の天運（%d）", "next_stage_trigger": "次のステージ開始後に発動", "next_stage_wait": "次のステージで卦象待機", "current_stage_wait": "このステージの卦象結果待ち",
		"paddle_size": "体サイズ", "gauge_max": "最大ゲージ", "item_cooldown": "アイテムCT", "active_cooldown": "スキルCT", "dash_cooldown": "ダッシュCT", "move_speed": "移動速度",
	},
	"es": {
		"title": "Tres Presagios Celestiales", "rolling": "El sello celestial lee los presagios de esta fase...", "result": "Presagios de esta fase", "continue": "Confirma para recibirlos",
		"current": "Presagios actuales (%d)", "next_stage_trigger": "Se activa al comenzar la siguiente fase", "next_stage_wait": "Lectura preparada para la siguiente fase", "current_stage_wait": "Resultado del presagio en espera",
		"paddle_size": "Tamaño corporal", "gauge_max": "Energía máxima", "item_cooldown": "Recarga de objetos", "active_cooldown": "Recarga de habilidades", "dash_cooldown": "Recarga de dash", "move_speed": "Velocidad de movimiento",
	},
	"pt-BR": {
		"title": "Três Presságios Celestiais", "rolling": "O selo celestial lê os presságios desta fase...", "result": "Presságios desta fase", "continue": "Confirme para recebê-los",
		"current": "Presságios atuais (%d)", "next_stage_trigger": "Ativa após o início da próxima fase", "next_stage_wait": "Leitura aguardando a próxima fase", "current_stage_wait": "Resultado do presságio aguardando",
		"paddle_size": "Tamanho corporal", "gauge_max": "Energia máxima", "item_cooldown": "Recarga de itens", "active_cooldown": "Recarga de habilidades", "dash_cooldown": "Recarga do dash", "move_speed": "Velocidade de movimento",
	},
	"ru": {
		"title": "Три Небесных Знамения", "rolling": "Небесная печать читает знамения этапа...", "result": "Знамения этого этапа", "continue": "Подтвердите получение знамений",
		"current": "Текущие знамения (%d)", "next_stage_trigger": "Сработает после начала следующего этапа", "next_stage_wait": "Чтение ожидает следующего этапа", "current_stage_wait": "Результат знамения ожидает показа",
		"paddle_size": "Размер тела", "gauge_max": "Максимум энергии", "item_cooldown": "Перезарядка предметов", "active_cooldown": "Перезарядка навыков", "dash_cooldown": "Перезарядка рывка", "move_speed": "Скорость движения",
	},
}


static func text(key: String) -> String:
	var locale := LanguageSettings.get_language()
	if locale == LanguageSettings.LANGUAGE_KOREAN:
		return str(KO.get(key, EN.get(key, key)))
	if locale == LanguageSettings.LANGUAGE_ENGLISH:
		return str(EN.get(key, key))
	var table: Dictionary = LOCALIZED.get(locale, {}) as Dictionary
	return str(table.get(key, EN.get(key, key)))


static func buff_label(buff_id: String) -> String:
	return text(buff_id)


static func build_status_lines(
	roll_snapshot: Dictionary,
	acquisition_snapshot: Dictionary,
	owned: bool = true
) -> Array[String]:
	if not owned:
		return []
	var buff_ids: Array[String] = []
	for value: Variant in roll_snapshot.get("active_buff_ids", []):
		var buff_id := str(value)
		if buff_id != "" and buff_id not in buff_ids:
			buff_ids.append(buff_id)
	if not buff_ids.is_empty():
		var pct := absf(float(roll_snapshot.get("buff_pct", 30.0)))
		var lines: Array[String] = [text("current") % buff_ids.size()]
		for buff_id: String in buff_ids:
			var sign := "+" if buff_id in ["paddle_size", "gauge_max", "move_speed"] else "-"
			lines.append("%s %s%s%%" % [buff_label(buff_id), sign, _format_number(pct)])
		return lines

	for pending_value: Variant in acquisition_snapshot.get("pending_rolls", []):
		if not (pending_value is Dictionary):
			continue
		var pending: Dictionary = pending_value
		if str(pending.get("policy", "")) == "next_valid_intro":
			return [text("next_stage_wait")]
		return [text("current_stage_wait")]
	return [text("next_stage_trigger")]


static func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return ("%.1f" % value).trim_suffix(".0")
