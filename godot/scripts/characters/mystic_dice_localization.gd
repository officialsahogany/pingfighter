extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

# TAB 스탯 행 태그 프리픽스(융합 [[fusion:*]] 패턴 미러): 렌더 엔트리
# 분해기(build_perk_stat_entries)가 색으로 변환한다 — 표시는 raw 부호가
# 아니라 benefit(이득/손해) 부호 기준이다.
const STAT_BENEFIT_PREFIX := "[[dice:benefit]]"
const STAT_CURSE_PREFIX := "[[dice:curse]]"
const STAT_NEUTRAL_PREFIX := "[[dice:neutral]]"

const TEXT_BY_LOCALE := {
	"ko": {
		"roll_title": "신비의 주사위",
		"rolling": "별빛이 운명을 고르는 중...",
		"result_title": "운명 조정 결과",
		"reroll": "다시 굴리기",
		"confirm": "확정",
		"rerolls_left": "남은 굴리기: %d회",
		"continue": "결정 키를 눌러 계속",
		"badge": "주사위",
		"long_badge": "(운명 조정)",
		"accumulated_changes": "누적 변화",
		"roll_header": "이번 굴림", "total_header": "누적",
		"player_speed": "이동속도", "paddle_size": "몸집 크기", "skill_gauge": "최대 게이지",
		"dash_distance": "대쉬 거리", "dash_recovery": "대쉬 후딜", "dash_cooldown": "대쉬 쿨타임", "item_cooldown": "아이템 쿨타임",
	},
	"en": {
		"roll_title": "Mystic Dice", "rolling": "Starlight is choosing your fate...", "result_title": "Fate Shift Results",
		"reroll": "Reroll", "confirm": "Confirm", "rerolls_left": "Rerolls left: %d", "continue": "Confirm to continue",
		"badge": "Dice", "long_badge": "(Fate Shift)", "accumulated_changes": "Accumulated Changes",
		"roll_header": "This Roll", "total_header": "Total",
		"player_speed": "Move Speed", "paddle_size": "Body Size", "skill_gauge": "Max Gauge",
		"dash_distance": "Dash Distance", "dash_recovery": "Dash Recovery", "dash_cooldown": "Dash Cooldown", "item_cooldown": "Item Cooldown",
	},
	"zh": {
		"roll_title": "神秘骰子", "rolling": "星光正在选择命运...", "result_title": "命运调整结果",
		"reroll": "重掷", "confirm": "确认", "rerolls_left": "剩余重掷：%d次", "continue": "确认以继续",
		"badge": "骰子", "long_badge": "（命运调整）", "accumulated_changes": "累计变化",
		"roll_header": "本次", "total_header": "累计",
		"player_speed": "移动速度", "paddle_size": "体型大小", "skill_gauge": "最大能量",
		"dash_distance": "冲刺距离", "dash_recovery": "冲刺后摇", "dash_cooldown": "冲刺冷却", "item_cooldown": "道具冷却",
	},
	"ja": {
		"roll_title": "神秘のダイス", "rolling": "星明かりが運命を選んでいます...", "result_title": "運命調整の結果",
		"reroll": "振り直す", "confirm": "確定", "rerolls_left": "残り振り直し：%d回", "continue": "決定して続行",
		"badge": "ダイス", "long_badge": "（運命調整）", "accumulated_changes": "累積変化",
		"roll_header": "今回", "total_header": "累計",
		"player_speed": "移動速度", "paddle_size": "体の大きさ", "skill_gauge": "最大ゲージ",
		"dash_distance": "ダッシュ距離", "dash_recovery": "ダッシュ後隙", "dash_cooldown": "ダッシュCT", "item_cooldown": "アイテムCT",
	},
	"es": {
		"roll_title": "Dado Místico", "rolling": "La luz estelar elige tu destino...", "result_title": "Ajuste del destino",
		"reroll": "Relanzar", "confirm": "Confirmar", "rerolls_left": "Relanzamientos: %d", "continue": "Confirma para continuar",
		"badge": "Dado", "long_badge": "(Ajuste de destino)", "accumulated_changes": "Cambios acumulados",
		"roll_header": "Tirada", "total_header": "Total",
		"player_speed": "Vel. de movimiento", "paddle_size": "Tamaño corporal", "skill_gauge": "Energía máx.",
		"dash_distance": "Distancia de dash", "dash_recovery": "Recuper. de dash", "dash_cooldown": "Enfriam. de dash", "item_cooldown": "Enfriam. de objetos",
	},
	"pt-BR": {
		"roll_title": "Dado Místico", "rolling": "A luz estelar escolhe seu destino...", "result_title": "Ajuste do destino",
		"reroll": "Rerrolar", "confirm": "Confirmar", "rerolls_left": "Rerrolagens: %d", "continue": "Confirme para continuar",
		"badge": "Dado", "long_badge": "(Ajuste do destino)", "accumulated_changes": "Mudanças acumuladas",
		"roll_header": "Rolagem", "total_header": "Total",
		"player_speed": "Vel. de movimento", "paddle_size": "Tamanho do corpo", "skill_gauge": "Energia máx.",
		"dash_distance": "Distância do dash", "dash_recovery": "Recuper. do dash", "dash_cooldown": "Recarga do dash", "item_cooldown": "Recarga de itens",
	},
	"ru": {
		"roll_title": "Таинственный кубик", "rolling": "Звездный свет выбирает судьбу...", "result_title": "Изменение судьбы",
		"reroll": "Перебросить", "confirm": "Подтвердить", "rerolls_left": "Перебросов: %d", "continue": "Подтвердите, чтобы продолжить",
		"badge": "Кубик", "long_badge": "(Изменение судьбы)", "accumulated_changes": "Накопленные изменения",
		"roll_header": "Бросок", "total_header": "Итог",
		"player_speed": "Скорость", "paddle_size": "Размер тела", "skill_gauge": "Макс. энергия",
		"dash_distance": "Дальность рывка", "dash_recovery": "Восстан. рывка", "dash_cooldown": "КД рывка", "item_cooldown": "КД предметов",
	},
}


static func text(key: String) -> String:
	var english: Dictionary = TEXT_BY_LOCALE.get("en", {}) as Dictionary
	var localized: Dictionary = TEXT_BY_LOCALE.get(LanguageSettings.get_language(), english) as Dictionary
	return str(localized.get(key, english.get(key, key)))


static func format(key: String, values: Array) -> String:
	return text(key) % values
