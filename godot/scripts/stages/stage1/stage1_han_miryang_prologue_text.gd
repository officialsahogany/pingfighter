extends RefCounted

const DEFAULT_LOCALE := "ko"
const TITLE_BY_LOCALE := {
	"ko": "아라울의 첫 박",
	"en": "The First Beat of Araul",
	"zh": "阿罗蔚的第一拍",
	"ja": "アラウルの第一拍",
	"es": "El primer compás de Araul",
	"pt-BR": "O primeiro compasso de Araul",
	"ru": "Первый такт Араула",
}
const CHAPTER_BY_LOCALE := {
	"ko": "제1장 — 빼앗긴 첫 박",
	"en": "CHAPTER I — THE STOLEN FIRST BEAT",
	"zh": "第一章 — 被夺走的第一拍",
	"ja": "第一章 — 奪われた第一拍",
	"es": "CAPÍTULO I — EL PRIMER COMPÁS ROBADO",
	"pt-BR": "CAPÍTULO I — O PRIMEIRO COMPASSO ROUBADO",
	"ru": "ГЛАВА I — УКРАДЕННЫЙ ПЕРВЫЙ ТАКТ",
}
const SKIP_BY_LOCALE := {
	"ko": "SPACE / 클릭으로 건너뛰기",
	"en": "SPACE / CLICK TO SKIP",
	"zh": "按空格 / 点击跳过",
	"ja": "SPACE / クリックでスキップ",
	"es": "ESPACIO / CLIC PARA OMITIR",
	"pt-BR": "ESPAÇO / CLIQUE PARA PULAR",
	"ru": "ПРОБЕЛ / ЩЕЛЧОК — ПРОПУСТИТЬ",
}

const LINES_BY_LOCALE := {
	"ko": [
		{"speaker": "내레이션", "text": "옛 왕조가 무너진 뒤, 신의 소리를 듣던 여인이 왕좌에 올랐다."},
		{"speaker": "여왕 해원", "text": "오늘부터 이 땅의 이름은—아라울이다."},
		{"speaker": "여왕 해원", "text": "아라울은 피로 세운 나라가 아니다. 목숨이 아니라 공으로 겨루라."},
		{"speaker": "여왕 해원", "text": "누구든 공을 되받아칠 수 있다면 이 판에 설 수 있다. 이 승부를—환격전이라 칭한다."},
		{"speaker": "한미량", "text": "잠깐…… 틀린 음이 아니야. 한 박이 비었어."},
		{"speaker": "제관", "text": "살아 계신 전하의 신주가…… 어찌 이곳에……."},
		{"speaker": "여왕 해원", "text": "소란 떨지 마라. 나의 즉위는 아직 끝나지 않았다."},
		{"speaker": "여왕 해원", "text": "무의관의 격령사, 한미량. 첫 판에 나서라."},
		{"speaker": "여왕 해원", "text": "누가 아라울의 첫 박을 훔쳤는지—그 공으로 밝혀내라."},
	],
	"en": [
		{"speaker": "NARRATION", "text": "After the old dynasty fell, a woman who heard the voices of spirits ascended the throne."},
		{"speaker": "QUEEN HAEWON", "text": "From this day forth, this land shall be called Araul."},
		{"speaker": "QUEEN HAEWON", "text": "Araul was not founded in blood. Let the ball, not lives, decide the contest."},
		{"speaker": "QUEEN HAEWON", "text": "Whoever can return the ball may stand upon this field. This contest shall be called Hwangyeokjeon."},
		{"speaker": "HAN MIRYANG", "text": "Wait... That was no wrong note. A beat is missing."},
		{"speaker": "RITUAL OFFICIANT", "text": "A memorial tablet for Your Majesty... while you yet live... How can this be?"},
		{"speaker": "QUEEN HAEWON", "text": "Do not make a commotion. My coronation is not yet over."},
		{"speaker": "QUEEN HAEWON", "text": "Spirit Striker Han Miryang of Muigwan. Take the first field."},
		{"speaker": "QUEEN HAEWON", "text": "Discover who stole Araul's first beat—with that ball."},
	],
	"zh": [
		{"speaker": "旁白", "text": "旧王朝覆灭后，一位能听见神灵之声的女子登上了王座。"},
		{"speaker": "海元女王", "text": "从今日起，这片土地名为——阿罗蔚。"},
		{"speaker": "海元女王", "text": "阿罗蔚并非以鲜血立国。不要以命相搏，以球决胜。"},
		{"speaker": "海元女王", "text": "只要能将球回击，任何人都可登场。此赛，名为——还击战。"},
		{"speaker": "韩美良", "text": "等等……不是错音。少了一拍。"},
		{"speaker": "祭官", "text": "陛下尚在人世，灵位为何会出现在这里……"},
		{"speaker": "海元女王", "text": "不得喧哗。我的即位礼尚未结束。"},
		{"speaker": "海元女王", "text": "巫仪馆击灵师韩美良，去打第一场。"},
		{"speaker": "海元女王", "text": "是谁偷走了阿罗蔚的第一拍——用那颗球查明真相。"},
	],
	"ja": [
		{"speaker": "語り", "text": "旧王朝が滅びた後、神々の声を聞く一人の女が王座に就いた。"},
		{"speaker": "女王ヘウォン", "text": "今日より、この地の名は——アラウル。"},
		{"speaker": "女王ヘウォン", "text": "アラウルは血で築く国ではない。命ではなく、球で競え。"},
		{"speaker": "女王ヘウォン", "text": "球を打ち返せる者なら誰でもこの場に立てる。この勝負を——環撃戦と呼ぶ。"},
		{"speaker": "ハン・ミリャン", "text": "待って……音を外したんじゃない。一拍、消えてる。"},
		{"speaker": "祭官", "text": "ご存命の陛下の神主が……なぜここに……。"},
		{"speaker": "女王ヘウォン", "text": "騒ぐな。私の即位はまだ終わっていない。"},
		{"speaker": "女王ヘウォン", "text": "巫儀館の撃霊師、ハン・ミリャン。初戦に出よ。"},
		{"speaker": "女王ヘウォン", "text": "アラウルの第一拍を盗んだ者を——その球で暴き出せ。"},
	],
	"es": [
		{"speaker": "NARRACIÓN", "text": "Tras caer la antigua dinastía, una mujer que oía a los espíritus ascendió al trono."},
		{"speaker": "REINA HAEWON", "text": "Desde hoy, esta tierra se llamará Araul."},
		{"speaker": "REINA HAEWON", "text": "Araul no nació de la sangre. Competid con la pelota, no con vuestras vidas."},
		{"speaker": "REINA HAEWON", "text": "Quien pueda devolver la pelota podrá entrar al campo. Esta contienda se llamará Hwangyeokjeon."},
		{"speaker": "HAN MIRYANG", "text": "Espera... No fue una nota equivocada. Falta un compás."},
		{"speaker": "OFICIANTE", "text": "Una tablilla funeraria de Su Majestad... mientras aún vive... ¿Cómo es posible?"},
		{"speaker": "REINA HAEWON", "text": "Silencio. Mi coronación aún no ha terminado."},
		{"speaker": "REINA HAEWON", "text": "Han Miryang, golpeadora espiritual de Muigwan. Disputa el primer encuentro."},
		{"speaker": "REINA HAEWON", "text": "Descubre quién robó el primer compás de Araul... con esa pelota."},
	],
	"pt-BR": [
		{"speaker": "NARRAÇÃO", "text": "Após a queda da antiga dinastia, uma mulher que ouvia os espíritos subiu ao trono."},
		{"speaker": "RAINHA HAEWON", "text": "A partir de hoje, esta terra se chamará Araul."},
		{"speaker": "RAINHA HAEWON", "text": "Araul não foi fundada em sangue. Disputem com a bola, não com a vida."},
		{"speaker": "RAINHA HAEWON", "text": "Quem conseguir devolver a bola poderá entrar em campo. Esta disputa se chamará Hwangyeokjeon."},
		{"speaker": "HAN MIRYANG", "text": "Espere... Não foi uma nota errada. Falta um compasso."},
		{"speaker": "OFICIANTE", "text": "Uma tabuleta funerária de Vossa Majestade... enquanto ainda vive... Como pode ser?"},
		{"speaker": "RAINHA HAEWON", "text": "Não façam alarde. Minha coroação ainda não terminou."},
		{"speaker": "RAINHA HAEWON", "text": "Han Miryang, batedora espiritual de Muigwan. Entre na primeira partida."},
		{"speaker": "RAINHA HAEWON", "text": "Descubra quem roubou o primeiro compasso de Araul... com aquela bola."},
	],
	"ru": [
		{"speaker": "РАССКАЗЧИК", "text": "После падения старой династии на престол взошла женщина, слышавшая голоса духов."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Отныне эта земля будет зваться Араулом."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Араул основан не на крови. Состязайтесь мячом, а не жизнями."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Каждый, кто способен отбить мяч, может выйти на поле. Это состязание назовём Хвангёкчон."},
		{"speaker": "ХАН МИРЯН", "text": "Постойте... Это не фальшивая нота. Пропал один такт."},
		{"speaker": "ЖРЕЦ", "text": "Поминальная табличка Вашего Величества... при живой королеве... Как такое возможно?"},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Без паники. Моя коронация ещё не окончена."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Хан Мирян, бьющая по духам из Мувигана. Выйди на первый поединок."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Узнай, кто украл первый такт Араула, — с помощью этого мяча."},
	],
}

const SEGMENT_TIMES := [
	Vector2(0.8, 4.3),
	Vector2(4.3, 7.5),
	Vector2(7.5, 11.5),
	Vector2(11.5, 16.3),
	Vector2(16.3, 20.3),
	Vector2(20.3, 23.4),
	Vector2(23.4, 26.7),
	Vector2(26.7, 30.3),
	Vector2(30.3, 34.9),
]


static func get_copy(locale: String) -> Dictionary:
	var normalized := _normalize_locale(locale)
	return {
		"locale": normalized,
		"title": str(TITLE_BY_LOCALE.get(normalized, TITLE_BY_LOCALE[DEFAULT_LOCALE])),
		"chapter": str(CHAPTER_BY_LOCALE.get(normalized, CHAPTER_BY_LOCALE[DEFAULT_LOCALE])),
		"skip": str(SKIP_BY_LOCALE.get(normalized, SKIP_BY_LOCALE[DEFAULT_LOCALE])),
	}


static func get_segments(locale: String) -> Array:
	var normalized := _normalize_locale(locale)
	var localized_lines: Array = LINES_BY_LOCALE.get(normalized, LINES_BY_LOCALE[DEFAULT_LOCALE])
	var result: Array = []
	for index in range(mini(localized_lines.size(), SEGMENT_TIMES.size())):
		var line_value: Variant = localized_lines[index]
		var line: Dictionary = line_value if line_value is Dictionary else {}
		var timing: Vector2 = SEGMENT_TIMES[index]
		result.append({
			"start": timing.x,
			"end": timing.y,
			"speaker": str(line.get("speaker", "")),
			"text": str(line.get("text", "")),
		})
	return result


static func get_segment_at(segments: Array, elapsed: float) -> Dictionary:
	for segment_value in segments:
		if not (segment_value is Dictionary):
			continue
		var segment: Dictionary = segment_value
		if elapsed >= float(segment.get("start", 0.0)) and elapsed < float(segment.get("end", 0.0)):
			return segment
	return {}


static func get_supported_locales() -> Array[String]:
	var result: Array[String] = []
	for key_value in LINES_BY_LOCALE:
		result.append(str(key_value))
	result.sort()
	return result


static func _normalize_locale(locale: String) -> String:
	var normalized := locale.strip_edges()
	if normalized.to_lower() == "pt-br" or normalized.to_lower() == "pt_br":
		return "pt-BR"
	if LINES_BY_LOCALE.has(normalized.to_lower()):
		return normalized.to_lower()
	return DEFAULT_LOCALE
