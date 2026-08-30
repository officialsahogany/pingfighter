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
#   - score / deuce: match_score_state.gd (WIN_GOAL 7, deuce at 6:6, goal caps at 10)
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
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

static var _character_runtime: Object = null
static var _catalog_mugong_max_level_cache := 0

const MUGONG_MAX_LEVEL_TOKEN := "{mugong_max_level}"

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
const GUARDIAN_BASIC_TIP_INDEX := 12
const GUARDIAN_DURATION_TIP_INDEX := 24
const GUARDIAN_ADVANCED_TIP_INDEX := 25
const BASIC_TIP_INDICES: Array[int] = [0, 1, 2, 4, 6, 9, 10, 11, GUARDIAN_BASIC_TIP_INDEX, 14, 15, 20]
const ADVANCED_TIP_INDICES: Array[int] = [3, 5, 7, 8, 13, 16, 17, 18, 19, 21, 22, 23, GUARDIAN_DURATION_TIP_INDEX, GUARDIAN_ADVANCED_TIP_INDEX]

# Reuse the live tutorial copy instead of maintaining a second input-label
# table. Only control-bearing tips need overrides; gameplay facts continue to
# come from the language-aligned arrays below.
const CONTROL_TIP_KEY_BY_GRIP := {
	"wasd_mouse": {
		0: "tutorial.mika.move.wasd_mouse",
		2: "tutorial.mika.dash.wasd_mouse",
		4: "tutorial.skill_tooltip.notice.wasd_mouse",
	},
	"space_arrows": {
		0: "tutorial.mika.move.space_arrows",
		2: "tutorial.mika.dash.space_arrows",
		4: "tutorial.skill_tooltip.notice.space_arrows",
	},
	"gamepad": {
		0: "tutorial.mika.move.gamepad",
		2: "tutorial.mika.dash.gamepad",
		4: "tutorial.skill_tooltip.notice.gamepad",
		6: "tutorial.active_item_use.gamepad",
		9: "tutorial.character_info.gamepad",
	},
}

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
	"← / → 또는 A / D 키로 몸집을 움직여 공을 받아치세요.",
	"몸집 가운데로 받으면 공이 곧게, 가장자리로 받으면 크게 꺾이고 속도도 붙습니다.",
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
	"수호령은 부화하면 자동으로 합류합니다. 소환 6초 뒤부터 Ctrl 키(패드 R3)로 수납·재소환하고, 클릭하면 반응합니다.",
	"경기는 7점을 먼저 내면 승리합니다. 6:6이 되면 듀스가 발동해 동점마다 목표 점수가 올라가고, 최대 10점에서 멈춥니다.",
	"스테이지의 특별한 오브젝트를 공으로 맞히면 무혼이 나타납니다. 거두면 곧바로 새 무공을 고를 수 있어요.",
	"가끔 라운드 시작과 함께 날씨가 변합니다. 빙판에선 몸이 미끄러지고, 화염에선 공이 점점 더 빨라집니다.",
	"랠리가 길고 공이 빠를수록 골드를 더 많이 법니다. 모은 골드는 아이템 구매와 강화에 쓰입니다.",
	"패배해도 기회의 보석이 남아 있다면 이어서 도전할 수 있습니다. 보석은 패배할 때마다 1개씩 소모됩니다.",
	"손이 닿지 않는 공은 수호령이 몸으로 대신 받아 주기도 합니다. 수호령 스킬은 준비되면 자동으로 발동돼요.",
	"액티브 아이템은 전투 중 필드에 주기적으로 떨어집니다. 여유가 될 때 주워 두세요.",
	"액티브 아이템 슬롯은 기본 3칸입니다. 일부 장착 아이템은 슬롯을 늘려 줍니다.",
	"같은 무공을 다시 고르면 기본 경지가 오릅니다. 직접 수련은 보통 {mugong_max_level}성까지이며, 장비와 버프로 유효 경지가 더 오를 수 있습니다.",
	"격노 상태의 보스와 랠리하면 골드가 1.5배로 들어옵니다.",
	"공이 빠를수록 보스가 받아칠 때 옆으로 크게 밀려납니다. 빠른 랠리로 보스 자리를 흔들 수 있어요.",
	"수호령 지속시간은 소환 중 줄고 수납 중 천천히 회복하며, 스테이지 전환 시 전량 회복합니다.",
	"지속시간이 0이면 수호령이 자동 수납됩니다. 지속시간 게이지가 30% 이상 회복되면 Ctrl 키(패드 R3)로 다시 소환할 수 있습니다.",
]

const TIPS_EN: Array[String] = [
	"Move with ← / → or A / D to return the ball.",
	"Hit with your body's center for a straight return; its edge bends the shot sharply and adds speed.",
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
	"Guardian spirits join automatically when hatched. After 6 seconds, use Ctrl (R3 on gamepad) to stow or resummon one; click it for a reaction.",
	"First to 7 points wins the match. At 6:6 it's deuce: every tie raises the goal score, up to a cap of 10.",
	"Hitting special stage objects with the ball reveals Martial Souls. Gather one to instantly choose a new martial art.",
	"Weather sometimes changes as a round starts. Ice makes your body slide; fire makes the ball keep accelerating.",
	"Longer, faster rallies earn more gold. Spend it on buying and enhancing items.",
	"If you still have Chance Gems, you can continue after a defeat. One gem is spent per loss.",
	"Your guardian spirit may body-block balls you can't reach. Guardian spirit skills fire automatically when ready.",
	"Active items drop onto the field regularly during battle. Grab them when it's safe.",
	"You have 3 active item slots by default. Some equippable items add more.",
	"Picking a Mugong you already own raises its base level. Direct investment usually stops at Lv.{mugong_max_level}, but equipment and buffs can raise its effective level further.",
	"Rallying against an enraged boss earns 1.5x gold.",
	"The faster the ball, the further the boss recoils when returning it. Keep rallies fast to shake the boss out of position.",
	"Guardian spirit duration drains while summoned, recovers while stowed, and refills on stage advance.",
	"At 0 duration, a guardian spirit stows automatically. Once the duration gauge recovers to 30% or more, use Ctrl (R3 on gamepad) to resummon it.",
]

const TIPS_ZH: Array[String] = [
	"用 ← / → 或 A / D 移动身体来接球。",
	"用身体中央接球会直线反弹，用边缘接球角度更大，还会加速。",
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
	"守护灵孵化后会自动加入。召唤满 6 秒后，按 Ctrl（手柄 R3）可收纳或重新召唤，点击它还能触发反应。",
	"先得 7 分者获胜。打成 6:6 时进入平分，每次战平目标分数都会提高，最高到 10 分。",
	"用球击中关卡中的特殊物件会出现武魂。收取后可立即挑选新武功。",
	"回合开始时天气偶尔会变化。冰面会让身体打滑，火焰会让球不断加速。",
	"对拉越久、球速越快，赚的金币越多。金币可用于购买和强化道具。",
	"只要还有机会宝石，落败后就能继续挑战。每次失败消耗 1 颗宝石。",
	"你接不到的球，守护灵有时会用身体替你挡下。守护灵技能就绪后会自动施放。",
	"战斗中主动道具会定期掉落在场上。有空时记得捡起来。",
	"主动道具栏默认有 3 格。部分装备道具可以增加格数。",
	"再次选择已拥有的武功会提升基础等级。直接投入通常到 Lv.{mugong_max_level}，但装备和增益可继续提高有效等级。",
	"与狂暴状态的首领对拉，金币收益为 1.5 倍。",
	"球越快，首领接球时被推得越远。保持高速对拉可以扰乱首领站位。",
	"守护灵的持续时间在召唤时减少、收纳时缓慢恢复，并在推进关卡时回满。",
	"持续时间归零时守护灵会自动收纳。持续时间槽恢复到 30% 以上后，按 Ctrl（手柄 R3）即可重新召唤。",
]

const TIPS_JA: Array[String] = [
	"← / → または A / D で体を動かしてボールを打ち返そう。",
	"体の中央で受けると真っ直ぐ、端で受けると大きく曲がりスピードも乗る。",
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
	"守護霊は孵化すると自動で合流する。召喚から 6 秒後、Ctrl（パッドは R3）で収納・再召喚でき、クリックすると反応する。",
	"先に7点取った方が勝ち。6対6になるとデュースが発動し、同点になるたび目標点が上がって最大10点で止まる。",
	"ステージの特別なオブジェクトにボールを当てると武魂が現れる。集めるとすぐ新しい武功を選べる。",
	"ラウンド開始時にたまに天候が変わる。氷では体が滑り、炎ではボールが加速し続ける。",
	"ラリーが長く速いほどゴールドを多く稼げる。集めたゴールドはアイテム購入と強化に使える。",
	"チャンスの宝石が残っていれば敗北しても再挑戦できる。宝石は敗北ごとに1個消費される。",
	"届かないボールは守護霊が体で受け止めてくれることも。守護霊のスキルは準備が整うと自動で発動する。",
	"アクティブアイテムは戦闘中、定期的にフィールドへ落ちてくる。余裕のあるときに拾っておこう。",
	"アクティブアイテムのスロットは基本3枠。一部の装備アイテムで枠を増やせる。",
	"すでに持つ武功をもう一度選ぶと基本レベルが上がる。直接投資は通常 Lv.{mugong_max_level} までだが、装備やバフで有効レベルはさらに上がる。",
	"激怒状態のボスとのラリーはゴールドが1.5倍になる。",
	"ボールが速いほど、ボスは打ち返す際に大きくのけぞる。速いラリーでボスの位置を揺さぶろう。",
	"守護霊の持続時間は召喚中に減り、収納中に徐々に回復し、ステージ進行で全回復する。",
	"持続時間が 0 になると守護霊は自動収納される。持続時間ゲージが 30% 以上まで回復したら Ctrl（パッドは R3）で再召喚できる。",
]

const TIPS_ES: Array[String] = [
	"Muévete con ← / → o A / D para devolver la pelota.",
	"Golpea con el centro del cuerpo para un rebote recto; con el borde el tiro se desvía mucho y gana velocidad.",
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
	"Los espíritus guardianes se unen automáticamente al incubarse. Tras 6 segundos, usa Ctrl (R3 en mando) para guardarlos o volver a invocarlos; haz clic para ver su reacción.",
	"Gana quien llegue primero a 7 puntos. Con 6:6 se activa el deuce: cada empate sube la puntuación objetivo hasta un máximo de 10.",
	"Golpear objetos especiales del escenario con la pelota revela Almas Marciales. Recoge una para elegir al instante un nuevo arte marcial.",
	"A veces el clima cambia al empezar la ronda. El hielo hace resbalar tu cuerpo; el fuego acelera la pelota sin parar.",
	"Los peloteos largos y rápidos dan más oro. Gástalo en comprar y mejorar objetos.",
	"Si aún te quedan Gemas de Oportunidad, puedes continuar tras una derrota. Se gasta una gema por derrota.",
	"Tu espíritu guardián puede bloquear con su cuerpo las pelotas que no alcanzas. Sus habilidades se activan solas al estar listas.",
	"Los objetos activos caen al campo con regularidad durante la batalla. Recógelos cuando sea seguro.",
	"Tienes 3 ranuras de objetos activos por defecto. Algunos objetos equipables añaden más.",
	"Elegir de nuevo un arte marcial que ya tienes sube su nivel base. La inversión directa suele llegar a Lv.{mugong_max_level}, pero el equipo y los efectos pueden elevar más el nivel efectivo.",
	"Pelotear contra un jefe enfurecido otorga 1,5 veces más oro.",
	"Cuanto más rápida la pelota, más retrocede el jefe al devolverla. Mantén el peloteo veloz para descolocarlo.",
	"La duración del espíritu guardián baja mientras está invocado, se recupera guardado y se rellena al avanzar de fase.",
	"Con duración 0, el espíritu guardián se guarda solo. Cuando el medidor de duración recupere al menos un 30%, usa Ctrl (R3 en mando) para volver a invocarlo.",
]

const TIPS_PT_BR: Array[String] = [
	"Movimente-se com ← / → ou A / D para rebater a bola.",
	"Rebata com o centro do corpo para uma volta reta; a borda desvia bastante o tiro e ganha velocidade.",
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
	"Espíritos guardiões entram automaticamente ao chocar. Após 6 segundos, use Ctrl (R3 no controle) para guardar ou invocar de novo; clique para ver a reação.",
	"Vence quem fizer 7 pontos primeiro. Em 6:6 rola o deuce: cada empate sobe a pontuação-alvo, até o limite de 10.",
	"Acertar objetos especiais da fase com a bola revela Almas Marciais. Recolha uma para escolher na hora uma nova arte marcial.",
	"Às vezes o clima muda no início da rodada. No gelo o corpo desliza; no fogo a bola acelera sem parar.",
	"Ralis longos e rápidos rendem mais ouro. Gaste-o comprando e aprimorando itens.",
	"Se ainda tiver Gemas da Chance, dá para continuar após a derrota. Uma gema é gasta por derrota.",
	"Seu espírito guardião pode bloquear com o corpo bolas que você não alcança. As habilidades dele disparam sozinhas quando prontas.",
	"Itens ativos caem no campo regularmente durante a batalha. Pegue-os quando der.",
	"Você tem 3 espaços de itens ativos por padrão. Alguns itens equipáveis adicionam mais.",
	"Escolher de novo uma arte marcial que você já tem aumenta o nível base. O investimento direto costuma ir até o Lv.{mugong_max_level}, mas equipamentos e efeitos podem elevar mais o nível efetivo.",
	"Trocar bolas com um chefe enfurecido rende 1,5x de ouro.",
	"Quanto mais rápida a bola, mais o chefe recua ao devolvê-la. Mantenha o rali veloz para tirá-lo da posição.",
	"A duração do espírito guardião cai quando invocado, recupera enquanto guardado e enche ao avançar de fase.",
	"Com duração 0, o espírito guardião se guarda sozinho. Quando a barra de duração recuperar pelo menos 30%, use Ctrl (R3 no controle) para invocá-lo de novo.",
]

const TIPS_RU: Array[String] = [
	"Двигайтесь клавишами ← / → или A / D, чтобы отбить мяч.",
	"Удар центром тела даёт прямой отскок; край сильно изменяет угол и добавляет скорости.",
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
	"Дух-хранитель автоматически присоединяется после вылупления. Через 6 секунд Ctrl (R3 на геймпаде) убирает или повторно призывает его, а щелчок вызывает реакцию.",
	"Побеждает тот, кто первым наберёт 7 очков. При счёте 6:6 наступает деюс: каждая ничья поднимает целевой счёт, максимум до 10.",
	"Попадая мячом по особым объектам сцены, вы пробуждаете боевые души. Соберите одну — и сразу выберете новое боевое искусство.",
	"Иногда с началом раунда меняется погода. На льду тело скользит, а в огне мяч всё ускоряется.",
	"Чем длиннее и быстрее розыгрыш, тем больше золота. Тратьте его на покупку и усиление предметов.",
	"Если остались камни шанса, после поражения можно продолжить. За каждое поражение тратится один камень.",
	"Дух-хранитель может телом отбить мяч, до которого вы не дотянулись. Его навыки срабатывают автоматически, когда готовы.",
	"Активные предметы регулярно падают на поле во время боя. Подбирайте их, когда безопасно.",
	"По умолчанию у вас 3 ячейки активных предметов. Некоторые надеваемые предметы добавляют ещё.",
	"Повторный выбор уже изученного боевого искусства повышает базовый уровень. Обычные вложения ограничены Lv.{mugong_max_level}, но снаряжение и эффекты могут поднять эффективный уровень выше.",
	"Розыгрыши против разъярённого босса приносят в 1,5 раза больше золота.",
	"Чем быстрее мяч, тем сильнее босса отбрасывает при отбивании. Держите высокий темп, чтобы сбивать его позицию.",
	"Время духа-хранителя убывает при призыве, восстанавливается в запасе и полностью заполняется при переходе этапа.",
	"При 0 времени дух-хранитель убирается сам. Когда шкала времени восстановится хотя бы до 30%, нажмите Ctrl (R3 на геймпаде), чтобы призвать его снова.",
]

const CHARACTER_TIPS_KO := {
	"smasher": "한미량의 벽력타는 좌우 방향과 공격 입력을 동시에 눌러 뇌광을 두른 공을 휘어칩니다.",
	"viper": "세린은 활주 직후 쉐도우 백스텝을 쓰고, 이어지는 마샬 킥으로 벽을 차고 공에 돌진합니다.",
	"commando": "호란은 공격 입력으로 단총통을 쏘고, 화기 교체 입력으로 무기를 바꿉니다.",
	"optimus": "이오는 에너지가 계속 줄어 몸집이 작아집니다. 아래 방향을 길게 눌러 충전하세요.",
	"blacksmith": "코하쿠는 위 방향으로 토르 실드를 펼쳐 공을 막고, 실드를 편 채 방향+공격 입력으로 휘둘러 반격합니다.",
}

const CHARACTER_TIPS_EN := {
	"smasher": "Han Miryang's Thunderclap Strike curves a lightning-wrapped ball when you press a horizontal direction and attack together.",
	"viper": "Serin can Shadow Backstep right after a dash, then chain Marshal Kick to kick off the wall at the ball.",
	"commando": "Horan fires the short hand cannon with the attack input and changes weapons with the firearm-swap input.",
	"optimus": "Io's energy keeps draining and its body shrinks. Hold the down direction to recharge.",
	"blacksmith": "Kohaku opens the Thor Shield with the up direction, then swings it with direction plus attack to counter.",
}

const CHARACTER_TIPS_ZH := {
	"smasher": "韩美良的霹雳击会在同时输入左右方向和攻击时，让缠绕雷光的球划出弧线。",
	"viper": "瑟琳可在冲刺后立刻向后闪身，再接武术踢蹬墙扑向球。",
	"commando": "虎兰用攻击输入击发短铳筒，并用火器切换输入更换武器。",
	"optimus": "伊奥的能量会不断消耗，体型也会变小。长按下方向充能。",
	"blacksmith": "琥珀用上方向展开雷神盾格挡，持盾时用方向加攻击挥盾反击。",
}

const CHARACTER_TIPS_JA := {
	"smasher": "ハン・ミリャンの霹靂打は左右方向と攻撃を同時入力し、雷光をまとったボールを曲げる。",
	"viper": "セリンはダッシュ直後にシャドウバックステップし、続くマーシャルキックで壁を蹴ってボールへ突進できる。",
	"commando": "ホランは攻撃入力で短銃筒を撃ち、火器切替入力で武器を替える。",
	"optimus": "イオのエネルギーは常に減り、体が小さくなる。下方向を長押しして充電しよう。",
	"blacksmith": "コハクは上方向でトールシールドを展開し、盾を構えたまま方向＋攻撃で振って反撃する。",
}

const CHARACTER_TIPS_ES := {
	"smasher": "El Golpe Relámpago de Han Miryang curva una pelota envuelta en rayos al pulsar una dirección horizontal y atacar a la vez.",
	"viper": "Serin retrocede como una sombra justo tras el dash y encadena la Patada marcial para lanzarse desde la pared hacia la pelota.",
	"commando": "Horan dispara el cañón corto con la entrada de ataque y cambia de arma con la entrada de cambio de fuego.",
	"optimus": "La energía de Io se agota sin parar y su cuerpo se encoge. Mantén pulsada la dirección abajo para recargar.",
	"blacksmith": "Kohaku despliega el Thor Shield con la dirección arriba y lo blande con dirección más ataque para contraatacar.",
}

const CHARACTER_TIPS_PT_BR := {
	"smasher": "O Golpe Relâmpago de Han Miryang curva uma bola envolta em raios ao apertar uma direção horizontal e atacar juntos.",
	"viper": "Serin recua como uma sombra logo após o dash e emenda o Marshal Kick para saltar da parede na bola.",
	"commando": "Horan atira com o canhão curto pelo comando de ataque e troca de arma pelo comando de troca de fogo.",
	"optimus": "A energia de Io drena sem parar e o corpo encolhe. Segure a direção para baixo para recarregar.",
	"blacksmith": "Kohaku abre o Thor Shield com a direção para cima e o balança com direção mais ataque para contra-atacar.",
}

const CHARACTER_TIPS_RU := {
	"smasher": "Громовой удар Хан Мирян закручивает мяч в молниях при одновременном вводе направления по горизонтали и атаки.",
	"viper": "Серин сразу после рывка отступает тенью, а затем Marshal Kick отталкивается от стены и летит к мячу.",
	"commando": "Хоран стреляет из короткой пищали командой атаки и меняет оружие командой смены огнестрела.",
	"optimus": "Энергия Ио постоянно тает, и тело уменьшается. Удерживайте направление вниз для подзарядки.",
	"blacksmith": "Кохаку раскрывает Thor Shield направлением вверх и, держа щит, машет им направлением плюс атакой для контратаки.",
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


static func get_tier_slot_for_tip_index(tier: String, tip_index: int) -> int:
	return indices_for_tier(tier).find(tip_index)


static func get_guardian_priority_tip_index(tier: String) -> int:
	return GUARDIAN_BASIC_TIP_INDEX if tier == TIER_BASIC else GUARDIAN_ADVANCED_TIP_INDEX


static func normalize_grip_style(grip_style: String) -> String:
	var normalized := grip_style.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if normalized in ["wasd_mouse", "wasd", "keyboard_mouse"]:
		return "wasd_mouse"
	if normalized in ["space_arrows", "space_arrow", "arrows", "arrow_keys", "arrows_space"]:
		return "space_arrows"
	if normalized in ["gamepad", "xbox", "controller", "pad"]:
		return "gamepad"
	return ""


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


static func tip_text_for_language(
	index: int,
	language: String,
	catalog_data_override: Dictionary = {},
	grip_style: String = ""
) -> String:
	var count := TIPS_KO.size()
	if count <= 0:
		return ""
	var wrapped := ((index % count) + count) % count
	var control_override := _control_tip_text_for_language(wrapped, language, grip_style)
	if control_override != "":
		return control_override
	var localized: Array = tips_for_language(language)
	if wrapped < localized.size():
		var candidate := str(localized[wrapped]).strip_edges()
		if candidate != "":
			return _format_catalog_mugong_max_level(str(localized[wrapped]), catalog_data_override)
	# Fall back to Korean if a language entry is missing / blank.
	return _format_catalog_mugong_max_level(str(TIPS_KO[wrapped]), catalog_data_override)


static func get_catalog_mugong_max_level(catalog_data_override: Dictionary = {}) -> int:
	if not catalog_data_override.is_empty():
		return RuntimePerkProgression.get_catalog_mugong_max_level(catalog_data_override)
	# Loading copy is requested from the draw loop. Build the O(37) catalog index
	# once, then serve an O(1) scalar. The source catalog is immutable at runtime;
	# the explicit invalidator exists for reload/test owners (GRT-020).
	if _catalog_mugong_max_level_cache <= 0:
		_catalog_mugong_max_level_cache = RuntimePerkProgression.get_catalog_mugong_max_level(
			RuntimePerkCatalog.new().get_all_perk_data()
		)
	return _catalog_mugong_max_level_cache


static func invalidate_catalog_mugong_max_level_cache() -> void:
	_catalog_mugong_max_level_cache = 0


static func _format_catalog_mugong_max_level(text: String, catalog_data_override: Dictionary = {}) -> String:
	if not text.contains(MUGONG_MAX_LEVEL_TOKEN):
		return text
	var max_level := get_catalog_mugong_max_level(catalog_data_override)
	return text.replace(MUGONG_MAX_LEVEL_TOKEN, str(max_level) if max_level > 0 else "?")


static func _control_tip_text_for_language(index: int, language: String, grip_style: String) -> String:
	var normalized_grip := normalize_grip_style(grip_style)
	var key_by_index_value: Variant = CONTROL_TIP_KEY_BY_GRIP.get(normalized_grip, {})
	if not (key_by_index_value is Dictionary):
		return ""
	var key_by_index: Dictionary = key_by_index_value
	var localization_key := str(key_by_index.get(index, ""))
	if localization_key == "":
		return ""
	var language_table_value: Variant = LanguageSettingsData.TEXT.get(language, {})
	if language_table_value is Dictionary:
		var localized := str((language_table_value as Dictionary).get(localization_key, "")).strip_edges()
		if localized != "":
			return localized
	var fallback_table_value: Variant = LanguageSettingsData.TEXT.get(LanguageSettings.DEFAULT_LANGUAGE, {})
	if fallback_table_value is Dictionary:
		return str((fallback_table_value as Dictionary).get(localization_key, "")).strip_edges()
	return ""


static func get_tip_text(index: int, grip_style: String = "") -> String:
	return tip_text_for_language(index, LanguageSettings.get_language(), {}, grip_style)


static func label_for_language(language: String) -> String:
	return str(LABEL_BY_LANGUAGE.get(language, LABEL_BY_LANGUAGE.get("ko", "도움말")))


static func get_tip_label() -> String:
	return label_for_language(LanguageSettings.get_language())


static func format_tip_for_language(index: int, language: String, grip_style: String = "") -> String:
	var text := tip_text_for_language(index, language, {}, grip_style)
	if text == "":
		return ""
	return "%s: %s" % [label_for_language(language), text]


static func format_tip(index: int, grip_style: String = "") -> String:
	return format_tip_for_language(index, LanguageSettings.get_language(), grip_style)


# Formatted tip for a rotation slot inside a tier's index list (slot wraps).
static func format_tier_tip(tier: String, slot: int, grip_style: String = "") -> String:
	var indices: Array = indices_for_tier(tier)
	var count := indices.size()
	if count <= 0:
		return ""
	var wrapped := ((slot % count) + count) % count
	return format_tip(int(indices[wrapped]), grip_style)


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


static func format_rotation_tip(tier: String, character_type: String, slot: int, grip_style: String = "") -> String:
	var tier_count := get_tier_tip_count(tier)
	var total := get_rotation_tip_count(tier, character_type)
	if total <= 0:
		return ""
	var wrapped := ((slot % total) + total) % total
	if wrapped >= tier_count:
		var language := LanguageSettings.get_language()
		return "%s: %s" % [label_for_language(language), character_tip_text_for_language(character_type, language)]
	return format_tier_tip(tier, wrapped, grip_style)


# Convenience: formatted rotation tip for a tier + character at a point in time.
static func rotation_tip_for_elapsed(
	tier: String,
	character_type: String,
	start_slot: int,
	elapsed_seconds: float,
	grip_style: String = ""
) -> String:
	return format_rotation_tip(
		tier,
		character_type,
		slot_for_elapsed(start_slot, elapsed_seconds, get_rotation_tip_count(tier, character_type)),
		grip_style
	)
