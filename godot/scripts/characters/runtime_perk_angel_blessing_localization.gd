extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const EN := {
	"title": "Angel's Dice",
	"rolling": "The halo is choosing this stage's blessings...",
	"result": "Blessings for this stage",
	"continue": "Confirm to receive the blessings",
	"current": "Current blessings (%d)",
	"next_stage_trigger": "Activates after the next stage begins",
	"next_stage_wait": "Dice queued for the next stage",
	"current_stage_wait": "Dice result is waiting for this stage",
	"paddle_size": "Paddle size",
	"gauge_max": "Maximum gauge",
	"item_cooldown": "Item cooldown",
	"active_cooldown": "Skill cooldown",
	"dash_cooldown": "Dash cooldown",
	"move_speed": "Move speed",
}

const KO := {
	"title": "천사의 주사위",
	"rolling": "성광이 이번 스테이지의 축복을 고르는 중...",
	"result": "이번 스테이지의 축복",
	"continue": "확인하여 축복을 흡수",
	"current": "현재 축복 (%d)",
	"next_stage_trigger": "다음 스테이지 시작 후 발동",
	"next_stage_wait": "다음 스테이지에 주사위 대기",
	"current_stage_wait": "현재 스테이지 주사위 결과 대기",
	"paddle_size": "패들 크기",
	"gauge_max": "최대 게이지",
	"item_cooldown": "아이템 쿨타임",
	"active_cooldown": "스킬 쿨타임",
	"dash_cooldown": "대시 쿨타임",
	"move_speed": "이동 속도",
}

const LOCALIZED := {
	"zh": {
		"title": "天使骰子", "rolling": "圣光正在选择本关的祝福……", "result": "本关祝福", "continue": "确认并吸收祝福",
		"current": "当前祝福（%d）", "next_stage_trigger": "下一关开始后发动", "next_stage_wait": "骰子将在下一关投掷", "current_stage_wait": "本关骰子结果等待中",
		"paddle_size": "球拍大小", "gauge_max": "最大能量", "item_cooldown": "道具冷却", "active_cooldown": "技能冷却", "dash_cooldown": "冲刺冷却", "move_speed": "移动速度",
	},
	"ja": {
		"title": "天使のダイス", "rolling": "聖なる光がこのステージの祝福を選択中…", "result": "今回の祝福", "continue": "決定して祝福を吸収",
		"current": "現在の祝福（%d）", "next_stage_trigger": "次のステージ開始後に発動", "next_stage_wait": "次のステージでダイス待機", "current_stage_wait": "このステージの結果待ち",
		"paddle_size": "パドルサイズ", "gauge_max": "最大ゲージ", "item_cooldown": "アイテムCT", "active_cooldown": "スキルCT", "dash_cooldown": "ダッシュCT", "move_speed": "移動速度",
	},
	"es": {
		"title": "Dado angelical", "rolling": "La luz sagrada elige las bendiciones de esta fase...", "result": "Bendiciones de esta fase", "continue": "Confirma para recibirlas",
		"current": "Bendiciones actuales (%d)", "next_stage_trigger": "Se activa al comenzar la siguiente fase", "next_stage_wait": "Dado preparado para la siguiente fase", "current_stage_wait": "Resultado del dado en espera",
		"paddle_size": "Tamaño de paleta", "gauge_max": "Energía máxima", "item_cooldown": "Recarga de objetos", "active_cooldown": "Recarga de habilidades", "dash_cooldown": "Recarga de dash", "move_speed": "Velocidad de movimiento",
	},
	"pt-BR": {
		"title": "Dado angelical", "rolling": "A luz sagrada escolhe as bênçãos desta fase...", "result": "Bênçãos desta fase", "continue": "Confirme para receber as bênçãos",
		"current": "Bênçãos atuais (%d)", "next_stage_trigger": "Ativa após o início da próxima fase", "next_stage_wait": "Dado aguardando a próxima fase", "current_stage_wait": "Resultado do dado aguardando",
		"paddle_size": "Tamanho da raquete", "gauge_max": "Energia máxima", "item_cooldown": "Recarga de itens", "active_cooldown": "Recarga de habilidades", "dash_cooldown": "Recarga do dash", "move_speed": "Velocidade de movimento",
	},
	"ru": {
		"title": "Ангельская кость", "rolling": "Священный свет выбирает благословения этапа...", "result": "Благословения этапа", "continue": "Подтвердите получение",
		"current": "Текущие благословения (%d)", "next_stage_trigger": "Сработает после начала следующего этапа", "next_stage_wait": "Бросок ожидает следующего этапа", "current_stage_wait": "Результат броска ожидает показа",
		"paddle_size": "Размер ракетки", "gauge_max": "Максимум энергии", "item_cooldown": "Перезарядка предметов", "active_cooldown": "Перезарядка навыков", "dash_cooldown": "Перезарядка рывка", "move_speed": "Скорость движения",
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
