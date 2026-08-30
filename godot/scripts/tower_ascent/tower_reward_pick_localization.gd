extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const TEXT := {
	"title": {
		"ko": "승리 보상", "en": "Victory Reward", "zh": "胜利奖励", "ja": "勝利報酬",
		"es": "Recompensa de victoria", "pt-BR": "Recompensa da vitória", "ru": "Награда за победу",
	},
	"continue": {
		"ko": "계속하기", "en": "Continue", "zh": "继续", "ja": "続ける",
		"es": "Continuar", "pt-BR": "Continuar", "ru": "Продолжить",
	},
	"balance": {
		"ko": "무혼 : {amount}개", "en": "Muhon : {amount}", "zh": "武魂 : {amount}个", "ja": "武魂 : {amount}個",
		"es": "Muhon : {amount}", "pt-BR": "Muhon : {amount}", "ru": "Мухон : {amount} шт.",
	},
	"victory_margin_reward": {
		"ko": "무혼 +{amount} (점수차 보상)", "en": "Muhon +{amount} (victory margin reward)", "zh": "武魂 +{amount}（分差奖励）", "ja": "武魂 +{amount}（得点差報酬）",
		"es": "Muhon +{amount} (recompensa por diferencia de puntos)", "pt-BR": "Muhon +{amount} (recompensa por diferença de pontos)", "ru": "Мухон +{amount} (награда за разницу в счёте)",
	},
	"price": {
		"ko": "무혼 {amount}", "en": "{amount} Muhon", "zh": "武魂 {amount}", "ja": "武魂 {amount}",
		"es": "{amount} Muhon", "pt-BR": "{amount} Muhon", "ru": "{amount} мухон",
	},
	"spent": {
		"ko": "구매 완료", "en": "Purchased", "zh": "已购买", "ja": "購入済み",
		"es": "Comprado", "pt-BR": "Comprado", "ru": "Куплено",
	},
	"insufficient": {
		"ko": "무혼이 부족합니다", "en": "Not enough Muhon", "zh": "武魂不足", "ja": "武魂が足りません",
		"es": "Muhon insuficiente", "pt-BR": "Muhon insuficiente", "ru": "Недостаточно мухона",
	},
	"perk_slot_limit": {
		"ko": "무공 슬롯이 가득 찼습니다", "en": "Mugong slots are full", "zh": "武功栏位已满", "ja": "武功スロットが満杯です",
		"es": "Los espacios de Mugong están llenos", "pt-BR": "Os espaços de Mugong estão cheios", "ru": "Ячейки мугона заполнены",
	},
	"hint": {
		"ko": "카드를 여러 장 살 수 있습니다", "en": "You may buy multiple cards", "zh": "可以购买多张卡牌", "ja": "複数のカードを購入できます",
		"es": "Puedes comprar varias cartas", "pt-BR": "Você pode comprar várias cartas", "ru": "Можно купить несколько карт",
	},
	"vision_swap": {
		"ko": "초식 교체 필요", "en": "Form swap required", "zh": "需要替换招式", "ja": "技の入れ替えが必要",
		"es": "Requiere cambiar técnica", "pt-BR": "Requer trocar técnica", "ru": "Нужно заменить приём",
	},
	"owned_upgrade_title": {
		"ko": "현재무공 강화하기", "en": "Upgrade Current Mugong", "zh": "强化当前武功", "ja": "現在の武功を強化",
		"es": "Mejorar Mugong actual", "pt-BR": "Aprimorar Mugong atual", "ru": "Улучшить текущий мугон",
	},
	"owned_upgrade_cta": {
		"ko": "클릭하여 강화하기", "en": "Click to upgrade", "zh": "点击强化", "ja": "クリックして強化",
		"es": "Haz clic para mejorar", "pt-BR": "Clique para aprimorar", "ru": "Нажмите, чтобы улучшить",
	},
	"upgrade_show_all": {
		"ko": "모든 무공 단계 보기", "en": "Show all Mugong levels", "zh": "查看所有武功阶段", "ja": "すべての武功段階を表示",
		"es": "Ver todos los niveles de Mugong", "pt-BR": "Ver todos os níveis de Mugong", "ru": "Показать все уровни мугона",
	},
	"upgrade_back": {
		"ko": "뒤로가기", "en": "Back", "zh": "返回", "ja": "戻る",
		"es": "Volver", "pt-BR": "Voltar", "ru": "Назад",
	},
	"upgrade_confirm": {
		"ko": "강화", "en": "Upgrade", "zh": "强化", "ja": "強化",
		"es": "Mejorar", "pt-BR": "Aprimorar", "ru": "Улучшить",
	},
	"upgrade_max_rank": {
		"ko": "최대 단계", "en": "Max rank", "zh": "最高星级", "ja": "最大ランク",
		"es": "Rango máximo", "pt-BR": "Grau máximo", "ru": "Максимальный ранг",
	},
	"upgrade_count_type_read_only": {
		"ko": "카운트형 무공은 여기서 강화할 수 없습니다", "en": "Count-type Mugong cannot be upgraded here", "zh": "计数型武功无法在此强化", "ja": "カウント型の武功はここでは強化できません",
		"es": "Los Mugong de tipo contador no se pueden mejorar aquí", "pt-BR": "Mugong do tipo contador não pode ser aprimorado aqui", "ru": "Мугон со счетчиком нельзя улучшить здесь",
	},
	"upgrade_cost": {
		"ko": "강화 비용: 무혼 {amount}", "en": "Upgrade cost: {amount} Muhon", "zh": "强化费用：武魂 {amount}", "ja": "強化費用：武魂 {amount}",
		"es": "Coste de mejora: {amount} Muhon", "pt-BR": "Custo do aprimoramento: {amount} Muhon", "ru": "Стоимость улучшения: {amount} мухон",
	},
	"upgrade_current": {
		"ko": "현재", "en": "Current", "zh": "当前", "ja": "現在",
		"es": "Actual", "pt-BR": "Atual", "ru": "Текущий",
	},
	"upgrade_after": {
		"ko": "강화 후", "en": "After upgrade", "zh": "强化后", "ja": "強化後",
		"es": "Tras la mejora", "pt-BR": "Após aprimorar", "ru": "После улучшения",
	},
	"mugong_swap_title": {
		"ko": "교체할 무공 선택", "en": "Choose Mugong to Replace", "zh": "选择要替换的武功", "ja": "入れ替える武功を選択",
		"es": "Elige el Mugong que reemplazar", "pt-BR": "Escolha o Mugong para substituir", "ru": "Выберите мугон для замены",
	},
	"mugong_swap_new_label": {
		"ko": "새 무공: {name}", "en": "New Mugong: {name}", "zh": "新武功：{name}", "ja": "新しい武功：{name}",
		"es": "Nuevo Mugong: {name}", "pt-BR": "Novo Mugong: {name}", "ru": "Новый мугон: {name}",
	},
	"mugong_swap_hint": {
		"ko": "교체할 무공을 클릭하세요. Esc로 취소", "en": "Click a Mugong to replace. Press Esc to cancel", "zh": "点击要替换的武功。按 Esc 取消", "ja": "入れ替える武功をクリック。Escでキャンセル",
		"es": "Haz clic en el Mugong que reemplazar. Pulsa Esc para cancelar", "pt-BR": "Clique no Mugong para substituir. Pressione Esc para cancelar", "ru": "Нажмите на мугон для замены. Esc для отмены",
	},
	"refresh_name": {
		"ko": "새로고침", "en": "Refresh", "zh": "刷新", "ja": "更新",
		"es": "Actualizar", "pt-BR": "Atualizar", "ru": "Обновить",
	},
	"refresh_description": {
		"ko": "보상 선택지를 다시 뽑습니다", "en": "Reroll the reward choices", "zh": "重新抽取奖励选项", "ja": "報酬の選択肢を引き直します",
		"es": "Vuelve a sortear las recompensas", "pt-BR": "Sorteia novamente as recompensas", "ru": "Повторно выбирает варианты награды",
	},
	"refresh_detail": {
		"ko": "현재 보상판을 새로운 선택지로 교체합니다. 구매한 보상은 유지됩니다.", "en": "Replaces the current reward board with new choices. Purchased rewards are kept.", "zh": "用新的选项替换当前奖励面板。已购买的奖励会保留。", "ja": "現在の報酬ボードを新しい選択肢に入れ替えます。購入済みの報酬は維持されます。",
		"es": "Sustituye el panel actual por nuevas opciones. Conservas las recompensas compradas.", "pt-BR": "Substitui o painel atual por novas opções. As recompensas compradas são mantidas.", "ru": "Заменяет текущий набор новыми вариантами. Купленные награды сохраняются.",
	},
	"bag_expansion_name": {
		"ko": "가방확장", "en": "Bag Expansion", "zh": "背包扩展", "ja": "バッグ拡張",
		"es": "Expansión de bolsa", "pt-BR": "Expansão da bolsa", "ru": "Расширение сумки",
	},
	"bag_expansion_description": {
		"ko": "액티브 아이템 슬롯 +1", "en": "Active item slots +1", "zh": "主动道具栏位 +1", "ja": "アクティブアイテムスロット +1",
		"es": "Espacios de objeto activo +1", "pt-BR": "Espaços de item ativo +1", "ru": "Ячейки активных предметов +1",
	},
	"bag_expansion_detail": {
		"ko": "이번 런의 액티브 아이템 슬롯을 1칸 늘립니다. 무공 슬롯을 차지하지 않습니다.", "en": "Increases active item slots by 1 for this run. Does not occupy a Mugong slot.", "zh": "本次挑战的主动道具栏位增加1格。不占用武功栏位。", "ja": "今回のランでアクティブアイテムスロットを1枠増やします。武功スロットは使用しません。",
		"es": "Aumenta en 1 los espacios de objeto activo de esta partida. No ocupa un espacio de Mugong.", "pt-BR": "Aumenta em 1 os espaços de item ativo desta partida. Não ocupa um espaço de Mugong.", "ru": "Увеличивает число ячеек активных предметов на 1 в этом забеге. Не занимает ячейку мугона.",
	},
}


static func text(key: String, replacements: Dictionary = {}) -> String:
	var entries: Dictionary = TEXT.get(key, {})
	var locale := LanguageSettings.get_language()
	var value := str(entries.get(locale, entries.get("en", key)))
	for replacement_key in replacements:
		value = value.replace("{%s}" % str(replacement_key), str(replacements[replacement_key]))
	return value
