extends RefCounted

const DEFAULT_LOCALE := "ko"
const TITLE_BY_LOCALE := {
	"ko": "아라울의 첫 승부",
	"en": "The First Contest of Araul",
	"zh": "阿罗蔚的第一战",
	"ja": "アラウルの最初の勝負",
	"es": "El primer duelo de Araul",
	"pt-BR": "A primeira disputa de Araul",
	"ru": "Первое состязание Араула",
}
const CHAPTER_BY_LOCALE := {
	"ko": "제1장 — 왕의 몸에 깃든 것",
	"en": "CHAPTER I — WHAT DWELT IN THE QUEEN'S BODY",
	"zh": "第一章 — 女王体内之物",
	"ja": "第一章 — 王の身に宿りしもの",
	"es": "CAPÍTULO I — LO QUE MORÓ EN EL CUERPO DE LA REINA",
	"pt-BR": "CAPÍTULO I — O QUE HABITOU O CORPO DA RAINHA",
	"ru": "ГЛАВА I — ТО, ЧТО ВСЕЛИЛОСЬ В ТЕЛО ГОСУДАРЫНИ",
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
		{"speaker": "여왕 해원", "text": "아라울은 피로 세운 나라가 아니다. 목숨이 아니라 승부로 겨루는 법을 세우겠다."},
		{"speaker": "제관", "text": "살아 계신 전하의 신주가…… 어찌 이곳에……."},
		{"speaker": "한미량", "text": "전하, 물러서십시오—!"},
		{"speaker": "여왕 해원", "text": "내 몸에서—나가라."},
		{"speaker": "한미량", "text": "베면 안 됩니다—령이 사람을 숙주로 삼았습니다."},
		{"speaker": "여왕 해원", "text": "사람은 남겨라. 깃든 것만 쳐내라."},
		{"speaker": "여왕 해원", "text": "령을 쳐서 공으로 되돌리는 이 승부—환격전이라 칭한다."},
	],
	"en": [
		{"speaker": "NARRATION", "text": "The old dynasty fell. A woman who heard spirits took the throne."},
		{"speaker": "QUEEN HAEWON", "text": "From this day forth, this land shall be called Araul."},
		{"speaker": "QUEEN HAEWON", "text": "Araul was not founded in blood. Contests, not lives, shall settle it."},
		{"speaker": "RITUAL OFFICIANT", "text": "Her Majesty's memorial tablet... while she still lives... how?"},
		{"speaker": "HAN MIRYANG", "text": "Majesty, stand back—!"},
		{"speaker": "QUEEN HAEWON", "text": "Get out—of my body."},
		{"speaker": "HAN MIRYANG", "text": "No blades—the spirit has taken him as its host."},
		{"speaker": "QUEEN HAEWON", "text": "Spare the man. Strike only what dwells within."},
		{"speaker": "QUEEN HAEWON", "text": "Strike the spirit back into the sphere. I name this Hwangyeokjeon."},
	],
	"zh": [
		{"speaker": "旁白", "text": "旧王朝覆灭之后，一位能听见神灵之声的女子登上了王座。"},
		{"speaker": "海元女王", "text": "从今日起，这片土地名为——阿罗蔚。"},
		{"speaker": "海元女王", "text": "阿罗蔚并非以鲜血立国。我要立下法度——不以性命，而以胜负定高下。"},
		{"speaker": "祭官", "text": "陛下尚在人世，灵位怎会出现在此……"},
		{"speaker": "韩美良", "text": "陛下，请退后——！"},
		{"speaker": "海元女王", "text": "从我体内——出去。"},
		{"speaker": "韩美良", "text": "不可挥刀——恶灵正以他为宿主。"},
		{"speaker": "海元女王", "text": "留下此人。只击出附身之物。"},
		{"speaker": "海元女王", "text": "击灵，使其归于球中——此赛，名为环击战。"},
	],
	"ja": [
		{"speaker": "語り", "text": "旧き王朝が滅びた後、神の声を聞く一人の女が王座に就いた。"},
		{"speaker": "女王ヘウォン", "text": "今日より、この地の名は——アラウル。"},
		{"speaker": "女王ヘウォン", "text": "アラウルは血で建てた国ではない。命ではなく、勝負で競う法を立てる。"},
		{"speaker": "祭官", "text": "ご存命の陛下の位牌が……なぜ、ここに……。"},
		{"speaker": "ハン・ミリャン", "text": "陛下、お下がりください——！"},
		{"speaker": "女王ヘウォン", "text": "我が身から——出よ。"},
		{"speaker": "ハン・ミリャン", "text": "斬ってはいけません——霊があの方を宿主にしています。"},
		{"speaker": "女王ヘウォン", "text": "人は残せ。宿りしものだけを打て。"},
		{"speaker": "女王ヘウォン", "text": "霊を打ち、球へと返すこの勝負——環撃戦と称する。"},
	],
	"es": [
		{"speaker": "NARRACIÓN", "text": "Cayó la antigua dinastía. Una mujer que oía espíritus subió al trono."},
		{"speaker": "REINA HAEWON", "text": "Desde hoy, esta tierra se llamará Araul."},
		{"speaker": "REINA HAEWON", "text": "Araul no nació de la sangre. Las disputas se resolverán con duelos, no con vidas."},
		{"speaker": "OFICIANTE", "text": "¿La tablilla funeraria de Su Majestad… si aún vive?"},
		{"speaker": "HAN MIRYANG", "text": "¡Majestad, apartaos!"},
		{"speaker": "REINA HAEWON", "text": "Sal—de mi cuerpo."},
		{"speaker": "HAN MIRYANG", "text": "¡No lo cortéis! El espíritu lo ha tomado como huésped."},
		{"speaker": "REINA HAEWON", "text": "Salva al hombre. Golpea solo lo que habita dentro."},
		{"speaker": "REINA HAEWON", "text": "Golpear al espíritu y devolverlo a la esfera. Lo llamo Hwangyeokjeon."},
	],
	"pt-BR": [
		{"speaker": "NARRAÇÃO", "text": "Caiu a antiga dinastia. Uma mulher que ouvia espíritos subiu ao trono."},
		{"speaker": "RAINHA HAEWON", "text": "A partir de hoje, esta terra se chamará Araul."},
		{"speaker": "RAINHA HAEWON", "text": "Araul não nasceu do sangue. Disputas serão resolvidas em duelos, não com vidas."},
		{"speaker": "OFICIANTE", "text": "A tabuleta funerária de Sua Majestade… e ela vive?"},
		{"speaker": "HAN MIRYANG", "text": "Majestade, afaste-se—!"},
		{"speaker": "RAINHA HAEWON", "text": "Saia—do meu corpo."},
		{"speaker": "HAN MIRYANG", "text": "Não o cortem—o espírito o tomou como hospedeiro."},
		{"speaker": "RAINHA HAEWON", "text": "Preserve o homem. Golpeie apenas o que habita dentro."},
		{"speaker": "RAINHA HAEWON", "text": "Golpear o espírito e devolvê-lo à esfera. A isto chamo Hwangyeokjeon."},
	],
	"ru": [
		{"speaker": "РАССКАЗЧИК", "text": "Старая династия пала. Женщина, слышавшая духов, взошла на трон."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "С этого дня эта земля зовётся Араулом."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Араул основан не на крови. Споры решат состязания, а не жизни."},
		{"speaker": "ЖРЕЦ", "text": "Поминальная табличка Её Величества… но она жива?"},
		{"speaker": "ХАН МИРЯН", "text": "Государыня, отойдите—!"},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Изыди—из моего тела."},
		{"speaker": "ХАН МИРЯН", "text": "Не рубите — дух сделал его своим носителем."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Пощадите человека. Бейте лишь то, что засело внутри."},
		{"speaker": "КОРОЛЕВА ХЭВОН", "text": "Бить духа и возвращать в сферу. Нарекаю это Хвангёкчоном."},
	],
}

const ELAPSED_BY_LOCALE := {
	"ko": ["여덟 줄기는 그날 밤 팔도로 사라졌다.", "세 해 뒤—환격회가 첫 줄기의 행방을 찾았다."],
	"en": ["That night, eight beams fled to the Eight Provinces.", "Three years on, the Hwangyeokhoe tracked the first."],
	"zh": ["那一夜，八条光芒散入八道。", "三年之后——环击会寻得了第一条光芒的下落。"],
	"ja": ["八条の光は、その夜、八道へと消えた。", "三年の後——環撃会が、最初の一条の行方を掴んだ。"],
	"es": ["Esa noche, ocho rayos se perdieron por las Ocho Provincias.", "Tres años después, el Hwangyeokhoe halló el primero."],
	"pt-BR": ["Naquela noite, oito raios sumiram nas Oito Províncias.", "Três anos depois, o Hwangyeokhoe encontrou o primeiro."],
	"ru": ["В ту ночь восемь лучей разлетелись по Восьми Провинциям.", "Три года спустя — Хвангёкхве напал на след первого."],
}

const SEGMENT_TIMES := [
	Vector2(0.8, 4.2),
	Vector2(4.2, 7.4),
	Vector2(7.4, 11.2),
	Vector2(11.8, 15.0),
	Vector2(15.6, 18.4),
	Vector2(23.0, 26.0),
	Vector2(30.2, 33.0),
	Vector2(33.4, 36.2),
	Vector2(36.2, 39.4),
]
const ELAPSED_TIMES := [Vector2(39.4, 42.2), Vector2(42.2, 45.0)]


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
			# rev7 can bind recorded voice amplitude here without changing the
			# segment/timeline schema. Empty IDs intentionally remain silent.
			"voice_id": str(line.get("voice_id", "")),
		})
	return result


static func get_elapsed_segments(locale: String) -> Array:
	var normalized := _normalize_locale(locale)
	var localized_lines: Array = ELAPSED_BY_LOCALE.get(normalized, ELAPSED_BY_LOCALE[DEFAULT_LOCALE])
	var result: Array = []
	for index in range(mini(localized_lines.size(), ELAPSED_TIMES.size())):
		var timing: Vector2 = ELAPSED_TIMES[index]
		result.append({
			"start": timing.x,
			"end": timing.y,
			"speaker": "",
			"text": str(localized_lines[index]),
			"elapsed_card": true,
			"voice_id": "",
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
