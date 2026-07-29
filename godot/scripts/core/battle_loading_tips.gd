extends RefCounted

# Loading-screen gameplay tips.
#
# These replace the old mechanical boot-status line on the loading screen
# ("핵심 전투 리소스 불러오는 중", "스테이지 런타임 준비 중", "나노 조각을
# 동기화하는 중" 등) with rotating, genuinely useful play tips.
#
# Every tip is grounded in real runtime behavior:
#   - move / dash / active-item / character-info controls come from the live
#     tutorial hints (junior_mika_tutorial_hint.gd, active_item_use_tutorial_hint.gd,
#     character_info_tutorial_hint.gd, TEXT["tutorial.*"] in language_settings_data.gd)
#   - paddle-position bounce angle + edge speed boost: paddle_bounce_controller.gd
#     (hit_pos * MAX_BOUNCE_ANGLE 60), paddle_bounce_speed_multiplier_resolver.gd
#   - rally acceleration + rally gold: rally speed-cap progression,
#     runtime_perk_state.gd RALLY_GOLD_*
#   - score / deuce: match_score_state.gd (WIN_GOAL 5, deuce at 4:4)
#   - starpoint -> perk choice: runtime_perk_state.gd collect_star_points()
#   - weather (advanced tier only — junior league gets no weather):
#     stages/common/weather_event_state.gd
#   - chance-gem continue: defeat_chance_gems_continue_screen.gd
#   - item rules: docs/item_runtime_checklist.md (passive equip-gate; the
#     player-facing tier name for legendary/mythic is "신화")
#   - lingpet egg (1-3 random hatch hits: lingpet_egg_field_state.gd
#     HATCH_REQUIRED_HITS_POOL) / duration / guardian toggle / body-guard:
#     the lingpet module cluster
#
# Localization contract (see feedback_godot_localization_copy_sync): every
# language array MUST stay index-aligned and the SAME length as TIPS_KO. The
# sealing smoke (battle_loading_tips_smoke.gd) fails if any language drifts or
# leaves an entry blank, so a missing translation cannot ship silently.

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

static var _character_runtime: Object = null

# Seconds each tip stays on screen before rotating to the next one.
const TIP_ROTATE_SECONDS := 3.6

# Difficulty tiers. The junior league ("테스트" difficulty — exhibition /
# first-time players) shows only the must-know basics; every other league
# (champion "실전", mythic "오버클럭") rotates the deeper-system tips.
const TIER_BASIC := "basic"
const TIER_ADVANCED := "advanced"

# Index partition over the TIPS_* arrays below. The sealing smoke asserts the
# two lists exactly cover 0..count-1 with no overlap, so adding a tip without
# assigning its tier fails loudly.
const BASIC_TIP_INDICES: Array[int] = [0, 1, 2, 4, 6, 9, 10, 11, 14, 15, 20]
const ADVANCED_TIP_INDICES: Array[int] = [3, 5, 7, 8, 12, 13, 16, 17, 18, 19, 21, 22, 23]

# Character-specific control tips — one per playable character, appended as an
# extra rotation slot for the selected character in BOTH tiers (core controls
# matter at every difficulty). Copy mirrors each character's own in-game skill
# tooltips / tutorial hints (smasher_skill_config.gd, viper_skill_config.gd,
# commando_firearm_tutorial_hint.gd, optimus_energy_state.gd,
# blacksmith_thor_shield_state.gd); skill names use the canonical per-language
# terms already shipped in language_settings_data.gd (弧线击球 / マーシャルキック /
# Patada marcial / 雷神盾 / トールシールド ...). Keys are normalized runtime
# character types; the sealing smoke keeps all 7 languages key-aligned.
const CHARACTER_TIP_KEYS: Array[String] = ["smasher", "viper", "commando", "optimus", "blacksmith"]

const TIPS_KO: Array[String] = [
	"← / → 또는 A / D 키로 패들을 움직여 공을 받아치세요.",
	"패들 가운데로 받으면 공이 곧게, 가장자리로 받으면 크게 꺾이고 속도도 붙습니다.",
	"이동 중 ↓ 또는 S 키로 활주하면 순간적으로 빠르게 움직일 수 있습니다.",
	"활주 횟수는 시간이 지나면 다시 충전됩니다. 위급한 순간을 위해 아껴 두세요.",
	"화면 왼쪽 초식 구슬은 초식마다 발동법이 다릅니다. 툴팁에서 사용법을 확인하세요.",
	"초식을 펼치면 쿨타임이 돌아갑니다. 기력 구슬이 다 차면 다시 사용할 수 있어요.",
	"획득한 액티브 아이템은 숫자 키를 눌러 사용합니다.",
	"패시브 아이템은 해당 부위에 장착해야 효과가 발동합니다.",
	"신화 아이템은 최상급 아이템으로, 대부분 강력한 고정·랜덤 옵션을 지닙니다.",
	"TAB 키를 누르면 내 캐릭터의 초식·무공·장착 아이템을 자세히 볼 수 있습니다.",
	"랠리가 오래 이어질수록 공은 점점 빨라집니다. 긴 접전에서는 미리 자리를 잡으세요.",
	"공명 알은 공을 맞혀 부화시킵니다. 알마다 필요한 타격 횟수(1~3회)가 다릅니다.",
	"수호령은 소환 중 지속시간을 소모하고, 수납 중에는 천천히 회복합니다. 스테이지를 넘으면 전량 회복합니다.",
	"경기는 5점을 먼저 내면 승리합니다. 4:4가 되면 듀스가 발동해 목표 점수가 올라갑니다.",
	"스테이지의 특별한 오브젝트를 공으로 맞히면 스타포인트가 떨어집니다. 주우면 곧바로 새 무공을 고를 수 있어요.",
	"가끔 라운드 시작과 함께 날씨가 변합니다. 빙판에선 패들이 미끄러지고, 화염에선 공이 점점 더 빨라집니다.",
	"랠리가 길고 공이 빠를수록 골드를 더 많이 법니다. 모은 골드는 아이템 구매와 강화에 쓰입니다.",
	"패배해도 기회의 보석이 남아 있다면 이어서 도전할 수 있습니다. 보석은 패배할 때마다 1개씩 소모됩니다.",
	"손이 닿지 않는 공은 수호령이 몸으로 대신 받아 주기도 합니다. 수호령 스킬은 준비되면 자동으로 발동돼요.",
	"액티브 아이템은 전투 중 필드에 주기적으로 떨어집니다. 여유가 될 때 주워 두세요.",
	"액티브 아이템 슬롯은 기본 3칸입니다. 일부 장착 아이템은 슬롯을 늘려 줍니다.",
	"이미 가진 무공을 다시 고르면 레벨이 올라 효과가 강해집니다. 대부분 최대 Lv.5까지 성장해요.",
	"격노 상태의 보스와 랠리하면 골드가 1.5배로 들어옵니다.",
	"공이 빠를수록 보스가 받아칠 때 옆으로 크게 밀려납니다. 빠른 랠리로 보스 자리를 흔들 수 있어요.",
]

const TIPS_EN: Array[String] = [
	"Move your paddle with ← / → or A / D to return the ball.",
	"Hit with the paddle's center for a straight return; its edge bends the shot sharply and adds speed.",
	"Press ↓ or S while moving to dash and reach the ball in an instant.",
	"Dash tokens recharge over time. Save them for critical moments.",
	"Each skill orb on the left activates differently. Open its tooltip to see how it works.",
	"Skills go on cooldown after use. When the orb's gauge fills up, it's ready again.",
	"Use active items you've picked up by pressing the number keys.",
	"Passive items only take effect once equipped in their body slot.",
	"Mythic items are top-tier, and most carry powerful fixed and random options.",
	"Press TAB to view your character's skills, perks, and equipped items in detail.",
	"The longer a rally lasts, the faster the ball gets. Position yourself early in long exchanges.",
	"Hit a resonance egg with the ball to hatch it. Each egg needs a different number of hits (1-3).",
	"Guardian spirits spend duration while summoned, recover it while stowed, and refill on stage advance. Click one for its reaction; use Ctrl/R3 to stow or summon.",
	"First to 5 points wins the match. At 4:4 it's deuce, and the goal score rises.",
	"Hitting special stage objects with the ball drops Star Points. Pick one up to instantly choose a new perk.",
	"Weather sometimes changes as a round starts. Ice makes your paddle slide; fire makes the ball keep accelerating.",
	"Longer, faster rallies earn more gold. Spend it on buying and enhancing items.",
	"If you still have Chance Gems, you can continue after a defeat. One gem is spent per loss.",
	"Your guardian spirit may body-block balls you can't reach. Guardian spirit skills fire automatically when ready.",
	"Active items drop onto the field regularly during battle. Grab them when it's safe.",
	"You have 3 active item slots by default. Some equippable items add more.",
	"Picking a perk you already own levels it up and strengthens its effect. Most grow up to Lv.5.",
	"Rallying against an enraged boss earns 1.5x gold.",
	"The faster the ball, the further the boss recoils when returning it. Keep rallies fast to shake the boss out of position.",
]

const TIPS_ZH: Array[String] = [
	"用 ← / → 或 A / D 移动挡板来接球。",
	"用挡板中央接球会直线反弹，用边缘接球角度更大，还会加速。",
	"移动时按 ↓ 或 S 冲刺，可瞬间快速移动接球。",
	"冲刺充能会随时间恢复，请为关键时刻留着。",
	"左侧的技能珠各有不同的发动方式，打开提示框即可查看用法。",
	"使用技能后会进入冷却，技能珠的能量条充满后即可再次使用。",
	"按数字键即可使用已获得的主动道具。",
	"被动道具需要装备到对应部位才会生效。",
	"神话道具是最高级道具，大多带有强力的固定与随机属性。",
	"按 TAB 键可详细查看角色的技能、天赋与已装备道具。",
	"对拉越久，球速越快。长时间的对攻中要提前占好位置。",
	"用球击打共鸣蛋即可孵化。每颗蛋所需的击打次数不同（1~3次）。",
	"守护灵在召唤时消耗持续时间、收纳时缓慢恢复，并在推进关卡时回满。点击可播放反应，Ctrl/R3 可收纳或召唤。",
	"先得 5 分者获胜。打成 4:4 时进入平分，目标分数会提高。",
	"用球击中关卡中的特殊物件会掉落星点。捡起后可立即挑选新天赋。",
	"回合开始时天气偶尔会变化。冰面会让挡板打滑，火焰会让球不断加速。",
	"对拉越久、球速越快，赚的金币越多。金币可用于购买和强化道具。",
	"只要还有机会宝石，落败后就能继续挑战。每次失败消耗 1 颗宝石。",
	"你接不到的球，守护灵有时会用身体替你挡下。守护灵技能就绪后会自动施放。",
	"战斗中主动道具会定期掉落在场上。有空时记得捡起来。",
	"主动道具栏默认有 3 格。部分装备道具可以增加格数。",
	"再次选择已拥有的天赋会使其升级、效果更强。大多数最高可升到 Lv.5。",
	"与狂暴状态的首领对拉，金币收益为 1.5 倍。",
	"球越快，首领接球时被推得越远。保持高速对拉可以扰乱首领站位。",
]

const TIPS_JA: Array[String] = [
	"← / → または A / D でパドルを動かしてボールを打ち返そう。",
	"パドル中央で受けると真っ直ぐ、端で受けると大きく曲がりスピードも乗る。",
	"移動中に ↓ または S でダッシュすると、一瞬で素早く動ける。",
	"ダッシュトークンは時間で回復する。ここぞという場面のために温存しよう。",
	"画面左のスキル珠は発動方法がそれぞれ違う。ツールチップで使い方を確認しよう。",
	"スキルは使うとクールタイムに入る。珠のゲージが満タンになれば再び使える。",
	"手に入れたアクティブアイテムは数字キーで使用する。",
	"パッシブアイテムは対応する部位に装備して初めて効果が発動する。",
	"神話アイテムは最上級のアイテムで、多くは強力な固定・ランダムオプションを持つ。",
	"TAB キーで自キャラのスキル・パーク・装備アイテムを詳しく確認できる。",
	"ラリーが長引くほどボールは速くなる。長い攻防では早めに位置取りしよう。",
	"共鳴の卵はボールを当てて孵化させる。卵ごとに必要なヒット数（1～3回）が違う。",
	"守護霊は召喚中に持続時間を消費し、収納中は徐々に回復、ステージ進行で全回復する。クリックで反応、Ctrl/R3で収納・召喚できる。",
	"先に5点取った方が勝ち。4対4になるとデュースが発動し、目標点が上がる。",
	"ステージの特別なオブジェクトにボールを当てるとスターポイントが落ちる。拾うとすぐ新しいパークを選べる。",
	"ラウンド開始時にたまに天候が変わる。氷ではパドルが滑り、炎ではボールが加速し続ける。",
	"ラリーが長く速いほどゴールドを多く稼げる。集めたゴールドはアイテム購入と強化に使える。",
	"チャンスの宝石が残っていれば敗北しても再挑戦できる。宝石は敗北ごとに1個消費される。",
	"届かないボールは守護霊が体で受け止めてくれることも。守護霊のスキルは準備が整うと自動で発動する。",
	"アクティブアイテムは戦闘中、定期的にフィールドへ落ちてくる。余裕のあるときに拾っておこう。",
	"アクティブアイテムのスロットは基本3枠。一部の装備アイテムで枠を増やせる。",
	"すでに持っているパークをもう一度選ぶとレベルが上がり効果が強まる。大半は最大 Lv.5 まで成長する。",
	"激怒状態のボスとのラリーはゴールドが1.5倍になる。",
	"ボールが速いほど、ボスは打ち返す際に大きくのけぞる。速いラリーでボスの位置を揺さぶろう。",
]

const TIPS_ES: Array[String] = [
	"Mueve la paleta con ← / → o A / D para devolver la pelota.",
	"Golpea con el centro de la paleta para un rebote recto; con el borde el tiro se desvía mucho y gana velocidad.",
	"Pulsa ↓ o S mientras te mueves para hacer un dash y alcanzar la pelota al instante.",
	"Las cargas de dash se recargan con el tiempo. Guárdalas para momentos críticos.",
	"Cada orbe de habilidad de la izquierda se activa de forma distinta. Abre su descripción para ver cómo funciona.",
	"Las habilidades entran en enfriamiento tras usarse. Cuando el medidor del orbe se llena, vuelve a estar lista.",
	"Usa los objetos activos que recojas pulsando las teclas numéricas.",
	"Los objetos pasivos solo surten efecto al equiparlos en su ranura.",
	"Los objetos míticos son del máximo nivel y la mayoría trae potentes opciones fijas y aleatorias.",
	"Pulsa TAB para ver en detalle las habilidades, mejoras y objetos equipados de tu personaje.",
	"Cuanto más dura un peloteo, más rápida se vuelve la pelota. Colócate con antelación en los intercambios largos.",
	"Golpea el huevo de resonancia con la pelota para incubarlo. Cada huevo necesita un número distinto de golpes (1-3).",
	"El espíritu guardián gasta duración invocado, la recupera guardado y se rellena al avanzar de fase. Haz clic para ver su reacción; Ctrl/R3 lo guarda o invoca.",
	"Gana quien llegue primero a 5 puntos. Con 4:4 se activa el deuce y sube la puntuación objetivo.",
	"Golpear objetos especiales del escenario con la pelota suelta Puntos Estrella. Recoge uno para elegir al instante una nueva mejora.",
	"A veces el clima cambia al empezar la ronda. El hielo hace resbalar la paleta; el fuego acelera la pelota sin parar.",
	"Los peloteos largos y rápidos dan más oro. Gástalo en comprar y mejorar objetos.",
	"Si aún te quedan Gemas de Oportunidad, puedes continuar tras una derrota. Se gasta una gema por derrota.",
	"Tu espíritu guardián puede bloquear con su cuerpo las pelotas que no alcanzas. Sus habilidades se activan solas al estar listas.",
	"Los objetos activos caen al campo con regularidad durante la batalla. Recógelos cuando sea seguro.",
	"Tienes 3 ranuras de objetos activos por defecto. Algunos objetos equipables añaden más.",
	"Elegir una mejora que ya tienes la sube de nivel y refuerza su efecto. La mayoría crece hasta Lv.5.",
	"Pelotear contra un jefe enfurecido otorga 1,5 veces más oro.",
	"Cuanto más rápida la pelota, más retrocede el jefe al devolverla. Mantén el peloteo veloz para descolocarlo.",
]

const TIPS_PT_BR: Array[String] = [
	"Mova a raquete com ← / → ou A / D para rebater a bola.",
	"Rebata com o centro da raquete para uma volta reta; a borda desvia bastante o tiro e ganha velocidade.",
	"Pressione ↓ ou S enquanto se move para dar um dash e alcançar a bola num instante.",
	"As cargas de dash se recarregam com o tempo. Guarde-as para momentos críticos.",
	"Cada orbe de habilidade à esquerda ativa de um jeito. Abra a dica para ver como funciona.",
	"As habilidades entram em recarga após o uso. Quando o medidor do orbe enche, ela fica pronta de novo.",
	"Use os itens ativos que você pegou pressionando as teclas numéricas.",
	"Itens passivos só fazem efeito quando equipados no espaço correspondente.",
	"Itens míticos são do nível mais alto e a maioria traz opções fixas e aleatórias poderosas.",
	"Pressione TAB para ver em detalhes as habilidades, perks e itens equipados do seu personagem.",
	"Quanto mais longo o rali, mais rápida a bola fica. Posicione-se cedo nas trocas longas.",
	"Acerte o ovo de ressonância com a bola para chocá-lo. Cada ovo precisa de um número diferente de acertos (1-3).",
	"O espírito guardião gasta duração quando invocado, recupera-a guardado e enche ao avançar de fase. Clique para reagir; Ctrl/R3 guarda ou invoca.",
	"Vence quem fizer 5 pontos primeiro. Em 4:4 rola o deuce e a pontuação-alvo sobe.",
	"Acertar objetos especiais da fase com a bola derruba Pontos Estrela. Pegue um para escolher na hora um novo perk.",
	"Às vezes o clima muda no início da rodada. No gelo a raquete desliza; no fogo a bola acelera sem parar.",
	"Ralis longos e rápidos rendem mais ouro. Gaste-o comprando e aprimorando itens.",
	"Se ainda tiver Gemas da Chance, dá para continuar após a derrota. Uma gema é gasta por derrota.",
	"Seu espírito guardião pode bloquear com o corpo bolas que você não alcança. As habilidades dele disparam sozinhas quando prontas.",
	"Itens ativos caem no campo regularmente durante a batalha. Pegue-os quando der.",
	"Você tem 3 espaços de itens ativos por padrão. Alguns itens equipáveis adicionam mais.",
	"Escolher um perk que você já tem sobe o nível dele e reforça o efeito. A maioria cresce até o Lv.5.",
	"Trocar bolas com um chefe enfurecido rende 1,5x de ouro.",
	"Quanto mais rápida a bola, mais o chefe recua ao devolvê-la. Mantenha o rali veloz para tirá-lo da posição.",
]

const TIPS_RU: Array[String] = [
	"Двигайте ракетку клавишами ← / → или A / D, чтобы отбить мяч.",
	"Удар центром ракетки даёт прямой отскок; край сильно изменяет угол и добавляет скорости.",
	"Нажмите ↓ или S в движении, чтобы сделать рывок и мгновенно догнать мяч.",
	"Заряды рывка восстанавливаются со временем. Берегите их для решающих моментов.",
	"Каждая сфера навыка слева активируется по-своему. Откройте подсказку, чтобы узнать как.",
	"После использования навык уходит на перезарядку. Когда шкала сферы заполнится, он снова готов.",
	"Активные предметы, которые вы подобрали, используются цифровыми клавишами.",
	"Пассивные предметы действуют только после экипировки в свой слот.",
	"Мифические предметы — высший уровень; большинство несёт мощные фиксированные и случайные свойства.",
	"Нажмите TAB, чтобы подробно просмотреть навыки, перки и экипировку вашего персонажа.",
	"Чем дольше длится розыгрыш, тем быстрее мяч. В долгих обменах занимайте позицию заранее.",
	"Попадите мячом по резонансному яйцу, чтобы оно вылупилось. Каждому яйцу нужно своё число попаданий (1–3).",
	"Призванный дух-хранитель расходует время, в запасе восстанавливает его, а на новом этапе получает полный запас. Щелчок запускает реакцию, Ctrl/R3 убирает или призывает.",
	"Побеждает тот, кто первым наберёт 5 очков. При счёте 4:4 наступает деюс, и целевой счёт растёт.",
	"Попадая мячом по особым объектам сцены, вы выбиваете звёздные очки. Подберите очко — и сразу выберете новый перк.",
	"Иногда с началом раунда меняется погода. На льду ракетка скользит, а в огне мяч всё ускоряется.",
	"Чем длиннее и быстрее розыгрыш, тем больше золота. Тратьте его на покупку и усиление предметов.",
	"Если остались камни шанса, после поражения можно продолжить. За каждое поражение тратится один камень.",
	"Дух-хранитель может телом отбить мяч, до которого вы не дотянулись. Его навыки срабатывают автоматически, когда готовы.",
	"Активные предметы регулярно падают на поле во время боя. Подбирайте их, когда безопасно.",
	"По умолчанию у вас 3 ячейки активных предметов. Некоторые надеваемые предметы добавляют ещё.",
	"Выбрав перк, который уже есть, вы повысите его уровень и усилите эффект. Большинство растёт до Lv.5.",
	"Розыгрыши против разъярённого босса приносят в 1,5 раза больше золота.",
	"Чем быстрее мяч, тем сильнее босса отбрасывает при отбивании. Держите высокий темп, чтобы сбивать его позицию.",
]

const CHARACTER_TIPS_KO := {
	"smasher": "스매셔의 벽력타는 ←/→와 공격(좌클릭)을 동시에 눌러 뇌광을 두른 공을 휘어칩니다.",
	"viper": "바이퍼는 활주 직후 S로 쉐도우 백스텝을 쓰고, 이어지는 마샬 킥으로 벽을 차고 공에 돌진합니다.",
	"commando": "호란은 좌클릭으로 권총을 쏘고, 마우스 휠을 돌려 화기를 교체합니다.",
	"optimus": "옵티머스의 에너지는 계속 줄어 패들이 작아집니다. 아래 키(↓/S)를 길게 눌러 충전하세요.",
	"blacksmith": "발토르는 W(↑)로 토르 실드를 펼쳐 공을 막고, 실드를 편 채 방향키+공격으로 휘둘러 반격합니다.",
}

const CHARACTER_TIPS_EN := {
	"smasher": "Smasher's Thunderclap Strike curves a lightning-wrapped ball — press ←/→ and attack (left click) together.",
	"viper": "Viper can Shadow Backstep with S right after a dash, then chain Marshal Kick to kick off the wall at the ball.",
	"commando": "Horan fires the pistol with left click and swaps firearms by rolling the mouse wheel.",
	"optimus": "Optimus's energy keeps draining and the paddle shrinks. Hold the down key (↓/S) to recharge.",
	"blacksmith": "Baltor opens the Thor Shield with W (↑) to block, then swings it with a direction key plus attack to counter.",
}

const CHARACTER_TIPS_ZH := {
	"smasher": "粉碎者的霹雳击：同时按 ←/→ 和攻击（左键），让缠绕雷光的球划出弧线。",
	"viper": "毒蛇冲刺后立刻按 S 向后闪身，再接武术踢蹬墙扑向球。",
	"commando": "虎兰用左键开枪，滚动鼠标滚轮切换枪械。",
	"optimus": "奥普提姆斯的能量不断消耗，挡板会变小。长按下键（↓/S）充能。",
	"blacksmith": "巴尔托按 W（↑）展开雷神盾格挡，持盾时按方向键加攻击挥盾反击。",
}

const CHARACTER_TIPS_JA := {
	"smasher": "スマッシャーの霹靂打は ←/→ と攻撃（左クリック）を同時押しし、雷光をまとったボールを曲げる。",
	"viper": "バイパーはダッシュ直後に S でシャドウバックステップ、続くマーシャルキックで壁を蹴ってボールへ突進できる。",
	"commando": "ホランは左クリックで拳銃を撃ち、マウスホイールで武器を切り替える。",
	"optimus": "オプティマスのエネルギーは常に減り、パドルが小さくなる。下キー（↓/S）を長押しして充電しよう。",
	"blacksmith": "バルトルは W（↑）でトールシールドを展開して防ぎ、盾を構えたまま方向キー＋攻撃で振って反撃する。",
}

const CHARACTER_TIPS_ES := {
	"smasher": "El Golpe Relámpago de Smasher curva una pelota envuelta en rayos: pulsa ←/→ y ataque (clic izquierdo) a la vez.",
	"viper": "Viper retrocede como una sombra con S justo tras el dash y encadena la Patada marcial para lanzarse desde la pared hacia la pelota.",
	"commando": "Horan dispara la pistola con clic izquierdo y cambia de arma girando la rueda del ratón.",
	"optimus": "La energía de Optimus se agota sin parar y la paleta se encoge. Mantén la tecla abajo (↓/S) para recargar.",
	"blacksmith": "Baltor despliega el Thor Shield con W (↑) para bloquear y, con el escudo abierto, lo blande con dirección más ataque para contraatacar.",
}

const CHARACTER_TIPS_PT_BR := {
	"smasher": "O Golpe Relâmpago do Smasher curva uma bola envolta em raios: aperte ←/→ e ataque (clique esquerdo) juntos.",
	"viper": "Viper recua como uma sombra com S logo após o dash e emenda o Marshal Kick para saltar da parede na bola.",
	"commando": "Horan atira com a pistola no clique esquerdo e troca de arma girando a roda do mouse.",
	"optimus": "A energia do Optimus drena sem parar e a raquete encolhe. Segure a tecla para baixo (↓/S) para recarregar.",
	"blacksmith": "Baltor abre o Thor Shield com W (↑) para bloquear e, com o escudo aberto, o balança com direção mais ataque para contra-atacar.",
}

const CHARACTER_TIPS_RU := {
	"smasher": "Громовой удар Smasher закручивает мяч в молниях: нажмите ←/→ и атаку (ЛКМ) одновременно.",
	"viper": "Viper сразу после рывка отступает тенью по S, а затем Marshal Kick отталкивается от стены и летит к мячу.",
	"commando": "Хоран стреляет из пистолета ЛКМ и меняет оружие прокруткой колёсика мыши.",
	"optimus": "Энергия Optimus постоянно тает, и ракетка уменьшается. Удерживайте клавишу вниз (↓/S) для подзарядки.",
	"blacksmith": "Baltor раскрывает Thor Shield по W (↑), чтобы блокировать, и, держа щит, машет им (направление + атака) для контратаки.",
}

# Localized "TIP" tag prefixed to the tip text on screen.
const LABEL_BY_LANGUAGE := {
	"ko": "도움말",
	"en": "TIP",
	"zh": "提示",
	"ja": "ヒント",
	"es": "Consejo",
	"pt-BR": "Dica",
	"ru": "Совет",
}


static func get_tip_count() -> int:
	return TIPS_KO.size()


# league_mode is the normalized BattleSceneConfig league id (junior / champion / mythic).
static func tier_for_league(league_mode: String) -> String:
	return TIER_BASIC if league_mode == "junior" else TIER_ADVANCED


static func indices_for_tier(tier: String) -> Array:
	return BASIC_TIP_INDICES if tier == TIER_BASIC else ADVANCED_TIP_INDICES


static func get_tier_tip_count(tier: String) -> int:
	return indices_for_tier(tier).size()


static func normalize_character_type(character_type: String) -> String:
	if character_type.strip_edges() == "":
		return ""
	# Delegate to the canonical runtime normalizer (io / kohaku / baltor
	# aliases, unknown -> smasher) so the two alias tables can never drift.
	# Its canonical commando id is "soldier"; remap to this module's key.
	if _character_runtime == null:
		_character_runtime = PlayerCharacterRuntime.new()
	var normalized: String = str(_character_runtime.normalize(character_type))
	if normalized == "soldier":
		return "commando"
	return normalized


static func character_tips_for_language(language: String) -> Dictionary:
	match language:
		"en":
			return CHARACTER_TIPS_EN
		"zh":
			return CHARACTER_TIPS_ZH
		"ja":
			return CHARACTER_TIPS_JA
		"es":
			return CHARACTER_TIPS_ES
		"pt-BR":
			return CHARACTER_TIPS_PT_BR
		"ru":
			return CHARACTER_TIPS_RU
	return CHARACTER_TIPS_KO


static func character_tip_text_for_language(character_type: String, language: String) -> String:
	var key := normalize_character_type(character_type)
	var localized: Dictionary = character_tips_for_language(language)
	var candidate := str(localized.get(key, "")).strip_edges()
	if candidate != "":
		return str(localized[key])
	# Fall back to Korean if a language entry is missing / blank.
	return str(CHARACTER_TIPS_KO.get(key, ""))


static func has_character_tip(character_type: String) -> bool:
	return CHARACTER_TIPS_KO.has(normalize_character_type(character_type))


static func tips_for_language(language: String) -> Array:
	match language:
		"en":
			return TIPS_EN
		"zh":
			return TIPS_ZH
		"ja":
			return TIPS_JA
		"es":
			return TIPS_ES
		"pt-BR":
			return TIPS_PT_BR
		"ru":
			return TIPS_RU
	return TIPS_KO


static func tip_text_for_language(index: int, language: String) -> String:
	var count := TIPS_KO.size()
	if count <= 0:
		return ""
	var wrapped := ((index % count) + count) % count
	var localized: Array = tips_for_language(language)
	if wrapped < localized.size():
		var candidate := str(localized[wrapped]).strip_edges()
		if candidate != "":
			return str(localized[wrapped])
	# Fall back to Korean if a language entry is missing / blank.
	return str(TIPS_KO[wrapped])


static func get_tip_text(index: int) -> String:
	return tip_text_for_language(index, LanguageSettings.get_language())


static func label_for_language(language: String) -> String:
	return str(LABEL_BY_LANGUAGE.get(language, LABEL_BY_LANGUAGE.get("ko", "도움말")))


static func get_tip_label() -> String:
	return label_for_language(LanguageSettings.get_language())


static func format_tip_for_language(index: int, language: String) -> String:
	var text := tip_text_for_language(index, language)
	if text == "":
		return ""
	return "%s: %s" % [label_for_language(language), text]


static func format_tip(index: int) -> String:
	return format_tip_for_language(index, LanguageSettings.get_language())


# Formatted tip for a rotation slot inside a tier's index list (slot wraps).
static func format_tier_tip(tier: String, slot: int) -> String:
	var indices: Array = indices_for_tier(tier)
	var count := indices.size()
	if count <= 0:
		return ""
	var wrapped := ((slot % count) + count) % count
	return format_tip(int(indices[wrapped]))


# Which rotation slot to show, given the slot the load started on, how long the
# loading screen has been visible, and the slot count of the active tier list.
# Pure + wrap-safe so the smoke can seal it.
static func slot_for_elapsed(start_slot: int, elapsed_seconds: float, slot_count: int) -> int:
	if slot_count <= 0:
		return 0
	var advanced := int(floor(maxf(0.0, elapsed_seconds) / TIP_ROTATE_SECONDS))
	return (((start_slot + advanced) % slot_count) + slot_count) % slot_count


# Rotation list = tier tips + one extra slot for the selected character's
# control tip (when the character has one).
static func get_rotation_tip_count(tier: String, character_type: String = "") -> int:
	return get_tier_tip_count(tier) + (1 if has_character_tip(character_type) else 0)


static func format_rotation_tip(tier: String, character_type: String, slot: int) -> String:
	var tier_count := get_tier_tip_count(tier)
	var total := get_rotation_tip_count(tier, character_type)
	if total <= 0:
		return ""
	var wrapped := ((slot % total) + total) % total
	if wrapped >= tier_count:
		var language := LanguageSettings.get_language()
		return "%s: %s" % [label_for_language(language), character_tip_text_for_language(character_type, language)]
	return format_tier_tip(tier, wrapped)


# Convenience: formatted rotation tip for a tier + character at a point in time.
static func rotation_tip_for_elapsed(tier: String, character_type: String, start_slot: int, elapsed_seconds: float) -> String:
	return format_rotation_tip(
		tier,
		character_type,
		slot_for_elapsed(start_slot, elapsed_seconds, get_rotation_tip_count(tier, character_type))
	)
