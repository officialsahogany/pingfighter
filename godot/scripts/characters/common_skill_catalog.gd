extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const SOUL_SUMMON_ART_ID := "soul_summon_art"
const SOUL_SUMMON_ART_UNLOCK_ID := "unlock_soul_summon_art"
const SOUL_SUMMON_ART_COLOR := Color(0.55, 0.88, 1.0, 1.0)
const DALJI_VISION_CHAIN_TOP_ID := "dalji_vision_chain_top"
const DALJI_VISION_CHAIN_TOP_UNLOCK_ID := "unlock_dalji_vision_chain_top"
const DALJI_VISION_CHAIN_TOP_COLOR := Color(0.46, 0.91, 0.86, 1.0)
const DALJI_VISION_CHAIN_TOP_COST := 120.0
const DALJI_VISION_CHAIN_TOP_COOLDOWN := 32.0
const CHEONGRINGWI_VISION_DRAGON_TORRENT_ID := "cheongringwi_vision_dragon_torrent"
const CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID := "unlock_cheongringwi_vision_dragon_torrent"
# Compatibility constants retain their original names so existing saves keep
# the same skill and unlock IDs after the Chosik concept changed to earth/rock.
const CHEONGRINGWI_VISION_DRAGON_TORRENT_COLOR := Color(0.78, 0.68, 0.26, 1.0)
const CHEONGRINGWI_VISION_DRAGON_TORRENT_COST := 250.0
const CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN := 40.0
const YEONMYO_VISION_BONGHONGWE_ID := "yeonmyo_vision_bonghongwe"
const YEONMYO_VISION_BONGHONGWE_UNLOCK_ID := "unlock_yeonmyo_vision_bonghongwe"
const YEONMYO_VISION_BONGHONGWE_COLOR := Color(0.64, 0.32, 0.78, 1.0)
const YEONMYO_VISION_BONGHONGWE_COST := 200.0
const YEONMYO_VISION_BONGHONGWE_COOLDOWN := 35.0

const _DALJI_VISION_COPY_BY_LANGUAGE := {
	"ko": {
		"name": "달지 비전 · 연환팽이",
		"manual_name": "달지 비전 · 연환팽이 비급",
		"timer_label": "연환팽이",
		"description": "팽이 둘이 7초간 필드를 누빕니다.\n누가 친 공이든 벽까지 크게 휘며 속도 +50%.\n첫 벽 반사에서 속도 +30%.",
		"how_to_use": "Shift를 누른 채 W (또는 ↑)",
		"motion_hint": "달지의 연환팽이 둘을 필드로 날려 보냅니다",
		"perk_description": "모든 캐릭터가 배울 수 있는 달지의 비전 초식입니다. 팽이 둘이 7초간 누가 친 공이든 벽까지 크게 휘게 하며 50% 가속하고 첫 벽 반사에서 다시 30% 가속합니다.",
	},
	"en": {
		"name": "Dalji Vision · Linked Tops",
		"manual_name": "Dalji Vision · Linked Tops Manual",
		"timer_label": "Linked Tops",
		"description": "Two tops roam for 7 seconds.\nAny ball: curves wallward, +50% speed.\nFirst wall rebound: +30% speed.",
		"how_to_use": "Hold Shift, then press W (or ↑)",
		"motion_hint": "Launch two of Dalji's linked tops onto the field",
		"perk_description": "Learn Dalji's Vision Chosik, usable by every character. Two tops roam for 7 seconds, curve any ball that touches them toward a wall at +50% speed, and gain another 30% on the first wall rebound.",
	},
	"zh": {
		"name": "达尔吉秘传 · 连环陀螺",
		"manual_name": "达尔吉秘传 · 连环陀螺秘笈",
		"timer_label": "连环陀螺",
		"description": "两枚陀螺会在场上移动7秒。\n任何球触碰后都会以50%加速弯向墙壁。\n首次墙壁反弹时再加速30%。",
		"how_to_use": "按住 Shift，再按 W（或 ↑）",
		"motion_hint": "将达尔吉的两枚连环陀螺发射到场上",
		"perk_description": "所有角色都能习得的达尔吉秘传招式。两枚陀螺会移动7秒，任何球触碰后都会以50%加速弯向墙壁，并在首次墙壁反弹时再次加速30%。",
	},
	"ja": {
		"name": "ダルジ秘伝・連環独楽",
		"manual_name": "ダルジ秘伝・連環独楽 秘伝書",
		"timer_label": "連環独楽",
		"description": "2つの独楽が7秒間フィールドを動きます。\nどちらの球も壁へ強く曲がり、速度+50%。\n最初の壁反射でさらに30%加速します。",
		"how_to_use": "Shiftを押しながら W（または ↑）を押す",
		"motion_hint": "ダルジの連環独楽を2つフィールドへ放つ",
		"perk_description": "全キャラクターが習得できるダルジの秘伝招式です。2つの独楽が7秒間、どちらの球も触れると壁へ強く曲げて50%加速し、最初の壁反射でさらに30%加速します。",
	},
	"es": {
		"name": "Visión de Dalji · Peonzas enlazadas",
		"manual_name": "Manual de Visión de Dalji · Peonzas enlazadas",
		"timer_label": "Peonzas enlazadas",
		"description": "Dos peonzas recorren el campo 7 segundos.\nCualquier pelota: curva a la pared, +50%.\nPrimer rebote: +30% de velocidad.",
		"how_to_use": "Mantén Shift y pulsa W (o ↑)",
		"motion_hint": "Lanza al campo dos peonzas enlazadas de Dalji",
		"perk_description": "Aprende el Chosik de Visión de Dalji, disponible para todos los personajes. Durante 7 segundos, las peonzas curvan cualquier pelota hacia la pared con +50% de velocidad y añaden otro 30% en el primer rebote.",
	},
	"pt-BR": {
		"name": "Visão de Dalji · Piões encadeados",
		"manual_name": "Manual da Visão de Dalji · Piões encadeados",
		"timer_label": "Piões encadeados",
		"description": "Dois piões percorrem o campo por 7 segundos.\nQualquer bola: curva à parede, +50%.\nPrimeiro ricochete: +30% de velocidade.",
		"how_to_use": "Segure Shift e aperte W (ou ↑)",
		"motion_hint": "Lança no campo dois piões encadeados de Dalji",
		"perk_description": "Aprenda o Chosik da Visão de Dalji, disponível para todos os personagens. Por 7 segundos, os piões curvam qualquer bola rumo à parede com +50% de velocidade e concedem mais 30% no primeiro ricochete.",
	},
	"ru": {
		"name": "Тайное искусство Дальджи · Связанные волчки",
		"manual_name": "Свиток тайного искусства Дальджи · Связанные волчки",
		"timer_label": "Связанные волчки",
		"description": "Два волчка движутся по полю 7 секунд.\nЛюбой мяч: к стене, скорость +50%.\nПервый отскок: ещё +30% скорости.",
		"how_to_use": "Удерживайте Shift и нажмите W (или ↑)",
		"motion_hint": "Запускает на поле два связанных волчка Дальджи",
		"perk_description": "Тайный приём Дальджи, доступный всем персонажам. Два волчка 7 секунд изгибают любой мяч к стене с ускорением 50% и добавляют ещё 30% при первом отскоке.",
	},
}

const _CHEONGRINGWI_VISION_COPY_BY_LANGUAGE := {
	"ko": {
		"name": "청린귀 비전 · 지맥진동",
		"manual_name": "청린귀 비전 · 지맥진동 비급",
		"description": "청린귀의 비전으로 화면에 지진을 일으키고\n상공에서 바위 3~5개를 무작위로 떨어뜨립니다.\n착지한 바위는 보스가 친 공만 되받아칩니다.",
		"how_to_use": "Shift를 누른 채 A → D → A (또는 ← → ←)",
		"motion_hint": "바위 3~5개를 무작위로 낙하시킵니다",
		"perk_description": "모든 캐릭터가 배울 수 있는 청린귀의 비전 초식입니다. 화면에 지진을 일으키고 바위 3~5개를 무작위로 떨어뜨리며, 착지한 바위는 보스가 친 공만 되받아칩니다.",
	},
	"en": {
		"name": "Cheongringwi Vision · Earth-Vein Quake",
		"manual_name": "Cheongringwi Vision · Earth-Vein Quake Manual",
		"description": "Shake the whole screen with Cheongringwi's secret art.\nDrop three to five rocks at random from above.\nLanded rocks return only boss-hit balls.",
		"how_to_use": "Hold Shift, then input A → D → A (or ← → ←)",
		"motion_hint": "Rattle the earth and randomly drop three to five rocks",
		"perk_description": "Learn Cheongringwi's Vision Chosik, usable by every character. It causes a quake and randomly drops three to five rocks; landed rocks return only boss-hit balls.",
	},
	"zh": {
		"name": "青鳞鬼秘传 · 地脉震荡",
		"manual_name": "青鳞鬼秘传 · 地脉震荡秘笈",
		"description": "以青鳞鬼秘传震动整个画面。\n从上空随机落下三至五块巨岩。\n落地岩石只会反弹首领击出的球。",
		"how_to_use": "按住 Shift，再输入 A → D → A（或 ← → ←）",
		"motion_hint": "震动地脉，随机落下三至五块巨岩",
		"perk_description": "所有角色都能习得的青鳞鬼秘传招式。引发地震并随机落下三至五块巨岩，落地岩石只会反弹首领击出的球。",
	},
	"ja": {
		"name": "青鱗鬼秘伝・地脈震動",
		"manual_name": "青鱗鬼秘伝・地脈震動 秘伝書",
		"description": "青鱗鬼の秘伝で画面全体を揺らします。\n上空から三～五つの岩をランダムに落とします。\n着地した岩はボスの打球だけを打ち返します。",
		"how_to_use": "Shiftを押しながら A → D → A（または ← → ←）",
		"motion_hint": "地脈を揺らし、三～五つの岩をランダムに落とす",
		"perk_description": "全キャラクターが習得できる青鱗鬼の秘伝招式です。地震を起こして三～五つの岩をランダムに落とし、着地した岩はボスの打球だけを打ち返します。",
	},
	"es": {
		"name": "Visión de Cheongringwi · Sismo telúrico",
		"manual_name": "Manual de Visión de Cheongringwi · Sismo telúrico",
		"description": "Sacude toda la pantalla con el arte de Cheongringwi.\nDeja caer entre tres y cinco rocas al azar.\nLas rocas caídas solo devuelven golpes del jefe.",
		"how_to_use": "Mantén Shift y pulsa A → D → A (o ← → ←)",
		"motion_hint": "Sacude la tierra y deja caer de tres a cinco rocas al azar",
		"perk_description": "Aprende el Chosik de Visión de Cheongringwi, disponible para todos. Provoca un sismo y deja caer de tres a cinco rocas al azar; solo devuelven golpes del jefe.",
	},
	"pt-BR": {
		"name": "Visão de Cheongringwi · Abalo telúrico",
		"manual_name": "Manual da Visão de Cheongringwi · Abalo telúrico",
		"description": "Sacuda toda a tela com a arte de Cheongringwi.\nDerrube de três a cinco rochas aleatoriamente.\nRochas no chão rebatem apenas golpes do chefe.",
		"how_to_use": "Segure Shift e aperte A → D → A (ou ← → ←)",
		"motion_hint": "Sacode a terra e derruba de três a cinco rochas ao acaso",
		"perk_description": "Aprenda o Chosik da Visão de Cheongringwi, disponível para todos. Causa um abalo e derruba de três a cinco rochas ao acaso; elas rebatem apenas golpes do chefe.",
	},
	"ru": {
		"name": "Тайное искусство Чхоннигви · Дрожь земных жил",
		"manual_name": "Свиток Чхоннигви · Дрожь земных жил",
		"description": "Тайный приём Чхоннигви сотрясает весь экран.\nСверху случайно падают от трёх до пяти валунов.\nКамни возвращают только удары босса.",
		"how_to_use": "Удерживайте Shift и введите A → D → A (или ← → ←)",
		"motion_hint": "Сотрясает землю и случайно обрушивает от трёх до пяти валунов",
		"perk_description": "Тайный приём Чхоннигви для всех персонажей. Он вызывает землетрясение и случайно обрушивает от трёх до пяти валунов; камни возвращают только удары босса.",
	},
}

const _YEONMYO_VISION_COPY_BY_LANGUAGE := {
	"ko": {
		"name": "연묘 비전 · 봉혼궤",
		"manual_name": "연묘 비전 · 봉혼궤 비급",
		"timer_label": "봉혼궤",
		"description": "보스 앞에 닫힌 저주상자를 던져 최대 12초간 둡니다.\n보스가 대시로 상자를 건드리면 열리며 3초간 연기를 뿜습니다.\n연기에 닿은 보스는 대시가 끊기고 3초간 혼란에 빠집니다.",
		"how_to_use": "Shift를 누른 채 S (또는 ↓)",
		"motion_hint": "저주상자를 던져 보스의 대시 길목을 봉쇄합니다",
		"perk_description": "모든 캐릭터가 배울 수 있는 연묘의 비전 초식입니다. 대시로 저주상자를 열게 한 뒤, 피어나는 연기에 보스를 닿게 하면 대시를 끊고 3초 동안 혼란시킵니다.",
	},
	"en": {
		"name": "Yeonmyo Vision · Soul-Sealing Chest",
		"manual_name": "Yeonmyo Vision · Soul-Sealing Chest Manual",
		"timer_label": "Soul-Sealing Chest",
		"description": "Throw a closed cursed chest that remains for up to 12 seconds.\nA boss dash touching it opens the chest and vents smoke for 3 seconds.\nTouching the smoke cancels the dash and confuses the boss for 3 seconds.",
		"how_to_use": "Hold Shift, then press S (or ↓)",
		"motion_hint": "Throw a cursed chest across the boss's dash route",
		"perk_description": "Learn Yeonmyo's Vision Chosik, usable by every character. Make the boss open the cursed chest with a dash, then lure it into the smoke to cancel the dash and cause 3 seconds of confusion.",
	},
	"zh": {
		"name": "莲妙秘传 · 封魂柜",
		"manual_name": "莲妙秘传 · 封魂柜秘籍",
		"timer_label": "封魂柜",
		"description": "向首领前方投掷关闭的诅咒宝箱，最多留存12秒。\n首领冲刺碰到宝箱时，宝箱开启并喷出烟雾3秒。\n首领触碰烟雾时会中断冲刺并混乱3秒。",
		"how_to_use": "按住 Shift，再按 S（或 ↓）",
		"motion_hint": "投掷诅咒宝箱，封锁首领的冲刺路线",
		"perk_description": "学习所有角色均可使用的莲妙秘传招式。让首领用冲刺打开诅咒宝箱，再诱使其触碰烟雾，即可中断冲刺并使其混乱3秒。",
	},
	"ja": {
		"name": "蓮妙秘伝・封魂櫃",
		"manual_name": "蓮妙秘伝・封魂櫃の秘伝書",
		"timer_label": "封魂櫃",
		"description": "閉じた呪いの箱を投げ、最大12秒間設置します。\nボスがダッシュで箱に触れると開き、3秒間煙を噴きます。\n煙に触れたボスはダッシュを止められ、3秒間混乱します。",
		"how_to_use": "Shiftを押しながら S（または ↓）",
		"motion_hint": "呪いの箱を投げてボスのダッシュ経路を封じます",
		"perk_description": "全キャラクターが習得できる蓮妙の秘伝招式です。ボスのダッシュで呪いの箱を開かせ、煙に触れさせるとダッシュを止めて3秒間混乱させます。",
	},
	"es": {
		"name": "Visión de Yeonmyo · Cofre sellalmas",
		"manual_name": "Manual de Visión de Yeonmyo · Cofre sellalmas",
		"timer_label": "Cofre sellalmas",
		"description": "Lanza un cofre maldito cerrado que permanece hasta 12 segundos.\nUna embestida del jefe lo abre y libera humo durante 3 segundos.\nTocar el humo cancela la embestida y confunde al jefe durante 3 segundos.",
		"how_to_use": "Mantén Shift y pulsa S (o ↓)",
		"motion_hint": "Lanza un cofre maldito para cerrar la ruta de embestida",
		"perk_description": "Aprende el Chosik de Visión de Yeonmyo, disponible para todos. Haz que el jefe abra el cofre con una embestida y llévalo al humo para cancelarla y confundirlo 3 segundos.",
	},
	"pt-BR": {
		"name": "Visão de Yeonmyo · Baú sela-almas",
		"manual_name": "Manual da Visão de Yeonmyo · Baú sela-almas",
		"timer_label": "Baú sela-almas",
		"description": "Arremesse um baú amaldiçoado fechado que permanece por até 12 segundos.\nUma investida do chefe abre o baú e libera fumaça por 3 segundos.\nTocar a fumaça cancela a investida e confunde o chefe por 3 segundos.",
		"how_to_use": "Segure Shift e aperte S (ou ↓)",
		"motion_hint": "Arremesse um baú amaldiçoado na rota de investida do chefe",
		"perk_description": "Aprenda o Chosik da Visão de Yeonmyo, disponível para todos. Faça o chefe abrir o baú com uma investida e atraia-o para a fumaça para cancelá-la e causar 3 segundos de confusão.",
	},
	"ru": {
		"name": "Тайное искусство Ёнмё · Ларец печати душ",
		"manual_name": "Свиток тайного искусства Ёнмё · Ларец печати душ",
		"timer_label": "Ларец печати душ",
		"description": "Бросает закрытый проклятый ларец, который лежит до 12 секунд.\nРывок босса открывает ларец, и тот выпускает дым 3 секунды.\nКасание дыма прерывает рывок и вызывает замешательство на 3 секунды.",
		"how_to_use": "Удерживайте Shift и нажмите S (или ↓)",
		"motion_hint": "Бросает проклятый ларец на путь рывка босса",
		"perk_description": "Тайный прием Ёнмё для всех персонажей. Заставьте босса открыть ларец рывком, затем заманите его в дым, чтобы прервать рывок и вызвать замешательство на 3 секунды.",
	},
}

const _COPY_BY_LANGUAGE := {
	"ko": {
		"name": "영혼소환술",
		"manual_name": "영혼소환술 비급",
		"description": "수호령 알을 깨워 함께 싸우게 합니다.\n소환 중에만 스킬 쿨타임과 기력이 진행됩니다.\n수호령은 하나의 공유 지속시간을 사용합니다.",
		"how_to_use": "Ctrl 또는 R3를 눌러 수호령 소환·수납을 전환합니다.",
		"motion_hint": "수호령 알을 부화해 소환",
		"perk_description": "선택 즉시 수호령 알 1개가 필드에 떨어집니다.",
	},
	"en": {
		"name": "Soul Summoning Art",
		"manual_name": "Soul Summoning Art Manual",
		"description": "Awaken a guardian spirit egg to fight beside you.\nSkill cooldowns and energy advance only while summoned.\nAll guardians share one duration pool.",
		"how_to_use": "Press Ctrl or R3 to switch between summoning and stowing the guardian.",
		"motion_hint": "Hatch a guardian spirit egg and summon it",
		"perk_description": "Choosing this immediately drops one guardian spirit egg on the field.",
	},
	"zh": {
		"name": "灵魂召唤术",
		"manual_name": "灵魂召唤术秘笈",
		"description": "孵化守护灵蛋，让它与你并肩作战。\n只有在召唤中，技能冷却和能量才会推进。\n所有守护灵共用一个持续时间池。",
		"how_to_use": "按 Ctrl 或 R3 切换守护灵的召唤与收纳。",
		"motion_hint": "孵化守护灵蛋并召唤",
		"perk_description": "选择后立即在场上掉落 1 枚守护灵蛋。",
	},
	"ja": {
		"name": "魂魄召喚術",
		"manual_name": "魂魄召喚術秘伝書",
		"description": "守護霊の卵を孵化させ、共に戦わせます。\n召喚中だけスキルのクールダウンと気力が進行します。\nすべての守護霊は1つの持続時間プールを共有します。",
		"how_to_use": "Ctrl または R3 を押して守護霊の召喚・収納を切り替えます。",
		"motion_hint": "守護霊の卵を孵化させて召喚",
		"perk_description": "選択すると即座に守護霊の卵が1つフィールドに落ちます。",
	},
	"es": {
		"name": "Arte de Invocación de Almas",
		"manual_name": "Manual del Arte de Invocación de Almas",
		"description": "Incuba un huevo de espíritu guardián para que luche contigo.\nLos enfriamientos y la energía avanzan solo mientras está invocado.\nTodos los guardianes comparten una reserva de duración.",
		"how_to_use": "Pulsa Ctrl o R3 para alternar entre invocar y guardar al guardián.",
		"motion_hint": "Incuba un huevo de guardián y lo invoca",
		"perk_description": "Al elegirlo, cae de inmediato un huevo de espíritu guardián en el campo.",
	},
	"pt-BR": {
		"name": "Arte de Invocação de Almas",
		"manual_name": "Manual da Arte de Invocação de Almas",
		"description": "Choque um ovo de espírito guardião para lutar ao seu lado.\nRecargas e energia avançam apenas enquanto ele está invocado.\nTodos os guardiões compartilham uma reserva de duração.",
		"how_to_use": "Pressione Ctrl ou R3 para alternar entre invocar e guardar o guardião.",
		"motion_hint": "Choca um ovo de guardião e o invoca",
		"perk_description": "Ao escolher, um ovo de espírito guardião cai imediatamente no campo.",
	},
	"ru": {
		"name": "Искусство призыва душ",
		"manual_name": "Тайный свиток искусства призыва душ",
		"description": "Выведите духа-хранителя из яйца, чтобы он сражался рядом.\nОткаты и энергия идут только во время призыва.\nВсе хранители делят один запас времени.",
		"how_to_use": "Нажмите Ctrl или R3, чтобы призвать или убрать хранителя.",
		"motion_hint": "Выводит духа-хранителя из яйца",
		"perk_description": "При выборе на поле сразу появляется одно яйцо духа-хранителя.",
	},
}


static func get_skill_data(skill_id: String = SOUL_SUMMON_ART_ID) -> Dictionary:
	if skill_id == DALJI_VISION_CHAIN_TOP_ID:
		var vision_copy: Dictionary = _get_dalji_vision_copy()
		return {
			"name": DALJI_VISION_CHAIN_TOP_ID,
			"korean": str(vision_copy.get("name", "Dalji Vision - Linked Tops")),
			"cost": DALJI_VISION_CHAIN_TOP_COST,
			"color": DALJI_VISION_CHAIN_TOP_COLOR,
			"cooldown": DALJI_VISION_CHAIN_TOP_COOLDOWN,
			"key": "vision_modifier",
			"description": str(vision_copy.get("description", "")),
			"how_to_use": str(vision_copy.get("how_to_use", "")),
			"motion_hint": str(vision_copy.get("motion_hint", "")),
			"effect_type": "dalji_vision_chain_top",
			"slot_occupancy": "active_orb",
			"cooldown_reduction_eligible": true,
			"show_cooldown": true,
			"description_max_lines": 3,
			"cleanup_policy": "perk_id_lookup",
			"fixed_level": 1,
			"vision_chosik": true,
			"boss_id": "dalji",
		}
	if skill_id == CHEONGRINGWI_VISION_DRAGON_TORRENT_ID:
		var vision_copy: Dictionary = _get_cheongringwi_vision_copy()
		return {
			"name": CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
			"korean": str(vision_copy.get("name", "Cheongringwi Vision - Earth-Vein Quake")),
			"cost": CHEONGRINGWI_VISION_DRAGON_TORRENT_COST,
			"color": CHEONGRINGWI_VISION_DRAGON_TORRENT_COLOR,
			"cooldown": CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN,
			"key": "vision_modifier",
			"description": str(vision_copy.get("description", "")),
			"how_to_use": str(vision_copy.get("how_to_use", "")),
			"motion_hint": str(vision_copy.get("motion_hint", "")),
			"effect_type": "cheongringwi_vision_dragon_torrent",
			"slot_occupancy": "active_orb",
			"cooldown_reduction_eligible": true,
			"show_cooldown": true,
			"description_max_lines": 3,
			"cleanup_policy": "perk_id_lookup",
			"fixed_level": 1,
			"vision_chosik": true,
			"boss_id": "cheongringwi",
		}
	if skill_id == YEONMYO_VISION_BONGHONGWE_ID:
		var vision_copy: Dictionary = _get_yeonmyo_vision_copy()
		return {
			"name": YEONMYO_VISION_BONGHONGWE_ID,
			"korean": str(vision_copy.get("name", "연묘 비전 · 봉혼궤")),
			"cost": YEONMYO_VISION_BONGHONGWE_COST,
			"color": YEONMYO_VISION_BONGHONGWE_COLOR,
			"cooldown": YEONMYO_VISION_BONGHONGWE_COOLDOWN,
			"key": "vision_modifier",
			"description": str(vision_copy.get("description", "")),
			"how_to_use": str(vision_copy.get("how_to_use", "")),
			"motion_hint": str(vision_copy.get("motion_hint", "")),
			"effect_type": YEONMYO_VISION_BONGHONGWE_ID,
			"slot_occupancy": "active_orb",
			"cooldown_reduction_eligible": true,
			"show_cooldown": true,
			"description_max_lines": 3,
			"cleanup_policy": "perk_id_lookup",
			"fixed_level": 1,
			"vision_chosik": true,
			"boss_id": "yeonmyo",
		}
	var copy: Dictionary = _get_copy()
	return {
		"name": SOUL_SUMMON_ART_ID,
		"korean": str(copy.get("name", "영혼소환술")),
		"cost": 0.0,
		"color": SOUL_SUMMON_ART_COLOR,
		"cooldown": 0.0,
		"key": "guardian_toggle",
		"description": str(copy.get("description", "")),
		"how_to_use": str(copy.get("how_to_use", "")),
		"motion_hint": str(copy.get("motion_hint", "")),
		"effect_type": "guardian_soul_orb",
		"slot_occupancy": "active_orb",
		"cooldown_reduction_eligible": false,
		"show_cooldown": false,
		"description_max_lines": 3,
		"cleanup_policy": "perk_id_lookup",
		"fixed_level": 1,
	}


static func get_unlock_perk_data(unlock_id: String = SOUL_SUMMON_ART_UNLOCK_ID) -> Dictionary:
	if unlock_id == DALJI_VISION_CHAIN_TOP_UNLOCK_ID:
		var vision_copy: Dictionary = _get_dalji_vision_copy()
		return {
			"name": str(vision_copy.get("manual_name", "Dalji Vision - Linked Tops Manual")),
			"max_level": 1,
			"descriptions": {1: str(vision_copy.get("perk_description", ""))},
			"detail": str(vision_copy.get("description", "")),
			"icon_color": DALJI_VISION_CHAIN_TOP_COLOR,
			"tree": "boss_vision_unlock",
			"unlocks_skill": DALJI_VISION_CHAIN_TOP_ID,
			"is_skill_manual": true,
			"slot_occupancy": "active_orb",
			"character_info_slot_free": true,
			"cooldown_reduction_eligible": true,
			"show_cooldown": true,
			"cleanup_policy": "perk_id_lookup",
			"fixed_level": 1,
			"exclude_from_perk_fusion": true,
			"vision_chosik": true,
			"boss_id": "dalji",
		}
	if unlock_id == CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID:
		var vision_copy: Dictionary = _get_cheongringwi_vision_copy()
		return {
			"name": str(vision_copy.get("manual_name", "Cheongringwi Vision - Earth-Vein Quake Manual")),
			"max_level": 1,
			"descriptions": {1: str(vision_copy.get("perk_description", ""))},
			"detail": str(vision_copy.get("description", "")),
			"icon_color": CHEONGRINGWI_VISION_DRAGON_TORRENT_COLOR,
			"tree": "boss_vision_unlock",
			"unlocks_skill": CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
			"is_skill_manual": true,
			"slot_occupancy": "active_orb",
			"character_info_slot_free": true,
			"cooldown_reduction_eligible": true,
			"show_cooldown": true,
			"cleanup_policy": "perk_id_lookup",
			"fixed_level": 1,
			"exclude_from_perk_fusion": true,
			"vision_chosik": true,
			"boss_id": "cheongringwi",
		}
	if unlock_id == YEONMYO_VISION_BONGHONGWE_UNLOCK_ID:
		var vision_copy: Dictionary = _get_yeonmyo_vision_copy()
		return {
			"name": str(vision_copy.get("manual_name", "연묘 비전 · 봉혼궤 비급")),
			"max_level": 1,
			"descriptions": {1: str(vision_copy.get("perk_description", ""))},
			"detail": str(vision_copy.get("description", "")),
			"icon_color": YEONMYO_VISION_BONGHONGWE_COLOR,
			"tree": "boss_vision_unlock",
			"unlocks_skill": YEONMYO_VISION_BONGHONGWE_ID,
			"is_skill_manual": true,
			"slot_occupancy": "active_orb",
			"character_info_slot_free": true,
			"cooldown_reduction_eligible": true,
			"show_cooldown": true,
			"cleanup_policy": "perk_id_lookup",
			"fixed_level": 1,
			"exclude_from_perk_fusion": true,
			"vision_chosik": true,
			"boss_id": "yeonmyo",
		}
	var copy: Dictionary = _get_copy()
	return {
		"name": str(copy.get("manual_name", "영혼소환술 비급")),
		"max_level": 1,
		"descriptions": {1: str(copy.get("perk_description", ""))},
		"detail": str(copy.get("description", "")),
		"icon_color": SOUL_SUMMON_ART_COLOR,
		"tree": "common_unlock",
		"unlocks_skill": SOUL_SUMMON_ART_ID,
		# This common unlock is still a real Chosik manual even though it has no
		# character restriction. Presentation classifiers must not infer the
		# manual category from character_restriction alone.
		"is_skill_manual": true,
		"slot_occupancy": "active_orb",
		# The battle Chosik orb still occupies one of the five combat slots. This
		# flag is only for the TAB Mugong collection grid, where the common art is
		# presented after the paid cells without consuming their budget.
		"character_info_slot_free": true,
		"cooldown_reduction_eligible": false,
		"show_cooldown": false,
		"cleanup_policy": "perk_id_lookup",
		"fixed_level": 1,
		"exclude_from_perk_fusion": true,
	}


static func _get_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _COPY_BY_LANGUAGE.get(language, _COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func get_dalji_vision_timer_label() -> String:
	return str(_get_dalji_vision_copy().get("timer_label", "Linked Tops"))


static func _get_dalji_vision_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _DALJI_VISION_COPY_BY_LANGUAGE.get(language, _DALJI_VISION_COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _get_cheongringwi_vision_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _CHEONGRINGWI_VISION_COPY_BY_LANGUAGE.get(language, _CHEONGRINGWI_VISION_COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func get_yeonmyo_vision_timer_label() -> String:
	return str(_get_yeonmyo_vision_copy().get("timer_label", "봉혼궤"))


static func _get_yeonmyo_vision_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _YEONMYO_VISION_COPY_BY_LANGUAGE.get(language, _YEONMYO_VISION_COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func is_common_skill(skill_id: String) -> bool:
	match skill_id:
		SOUL_SUMMON_ART_ID, DALJI_VISION_CHAIN_TOP_ID, CHEONGRINGWI_VISION_DRAGON_TORRENT_ID, YEONMYO_VISION_BONGHONGWE_ID:
			return true
	return false


static func is_common_unlock(unlock_id: String) -> bool:
	match unlock_id:
		SOUL_SUMMON_ART_UNLOCK_ID, DALJI_VISION_CHAIN_TOP_UNLOCK_ID, CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID, YEONMYO_VISION_BONGHONGWE_UNLOCK_ID:
			return true
	return false


static func is_vision_unlock_id(unlock_id: String) -> bool:
	match unlock_id:
		DALJI_VISION_CHAIN_TOP_UNLOCK_ID, CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID, YEONMYO_VISION_BONGHONGWE_UNLOCK_ID:
			return true
	return false


static func get_unlock_id_for_skill(skill_id: String) -> String:
	match skill_id:
		SOUL_SUMMON_ART_ID:
			return SOUL_SUMMON_ART_UNLOCK_ID
		DALJI_VISION_CHAIN_TOP_ID:
			return DALJI_VISION_CHAIN_TOP_UNLOCK_ID
		CHEONGRINGWI_VISION_DRAGON_TORRENT_ID:
			return CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID
		YEONMYO_VISION_BONGHONGWE_ID:
			return YEONMYO_VISION_BONGHONGWE_UNLOCK_ID
	return ""


static func get_skill_id_for_unlock(unlock_id: String) -> String:
	match unlock_id:
		SOUL_SUMMON_ART_UNLOCK_ID:
			return SOUL_SUMMON_ART_ID
		DALJI_VISION_CHAIN_TOP_UNLOCK_ID:
			return DALJI_VISION_CHAIN_TOP_ID
		CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID:
			return CHEONGRINGWI_VISION_DRAGON_TORRENT_ID
		YEONMYO_VISION_BONGHONGWE_UNLOCK_ID:
			return YEONMYO_VISION_BONGHONGWE_ID
	return ""


static func get_all_skill_ids() -> Array[String]:
	return [
		SOUL_SUMMON_ART_ID,
		DALJI_VISION_CHAIN_TOP_ID,
		CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
		YEONMYO_VISION_BONGHONGWE_ID,
	]


static func get_all_skill_data() -> Dictionary:
	return {
		SOUL_SUMMON_ART_ID: get_skill_data(SOUL_SUMMON_ART_ID),
		DALJI_VISION_CHAIN_TOP_ID: get_skill_data(DALJI_VISION_CHAIN_TOP_ID),
		CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: get_skill_data(CHEONGRINGWI_VISION_DRAGON_TORRENT_ID),
		YEONMYO_VISION_BONGHONGWE_ID: get_skill_data(YEONMYO_VISION_BONGHONGWE_ID),
	}


static func get_skill_costs() -> Dictionary:
	return {
		SOUL_SUMMON_ART_ID: 0.0,
		DALJI_VISION_CHAIN_TOP_ID: DALJI_VISION_CHAIN_TOP_COST,
		CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: CHEONGRINGWI_VISION_DRAGON_TORRENT_COST,
		YEONMYO_VISION_BONGHONGWE_ID: YEONMYO_VISION_BONGHONGWE_COST,
	}


static func get_skill_colors() -> Dictionary:
	return {
		SOUL_SUMMON_ART_ID: SOUL_SUMMON_ART_COLOR,
		DALJI_VISION_CHAIN_TOP_ID: DALJI_VISION_CHAIN_TOP_COLOR,
		CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: CHEONGRINGWI_VISION_DRAGON_TORRENT_COLOR,
		YEONMYO_VISION_BONGHONGWE_ID: YEONMYO_VISION_BONGHONGWE_COLOR,
	}


static func get_cooldown_seconds_map(cooldown_multiplier: float = 1.0) -> Dictionary:
	return {
		SOUL_SUMMON_ART_ID: 0.0,
		DALJI_VISION_CHAIN_TOP_ID: DALJI_VISION_CHAIN_TOP_COOLDOWN * max(0.0, cooldown_multiplier),
		CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN * max(0.0, cooldown_multiplier),
		YEONMYO_VISION_BONGHONGWE_ID: YEONMYO_VISION_BONGHONGWE_COOLDOWN * max(0.0, cooldown_multiplier),
	}
