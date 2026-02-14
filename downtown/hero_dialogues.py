"""
투기장 영웅 상황별 대사 시스템
- 점수 변화, 유불리 등 상황에 맞는 대사를 가끔 말풍선으로 표시
- 기존 스킬 말풍선과 충돌하지 않도록 쿨다운/우선순위 관리
"""

import random

# ── 대사 상황 상수 ──
BATTLE_START = "battle_start"
SCORED = "scored"
CONCEDED = "conceded"
LOSING = "losing"
WINNING = "winning"
DEUCE = "deuce"
MATCH_POINT = "match_point"
IN_DANGER = "in_danger"
RETORT = "retort"  # 상대 대사에 받아치기

# ── 8영웅 × 8상황 대사 데이터 ──
HERO_DIALOGUES = {
    # ─── 무겐 (귀검사) : 냉철하고 과묵한 검사 ───
    "mugen": {
        BATTLE_START: [
            "...베어주마.",
            "검이 울고 있다.",
            "네 운명은 여기서 끝이다.",
        ],
        SCORED: [
            "하찮군.",
            "...당연한 결과다.",
            "어둠이 너를 삼켰다.",
        ],
        CONCEDED: [
            "...흥.",
            "다음엔 없다.",
            "제법이군.",
        ],
        LOSING: [
            "...재미있어지는군.",
            "내 검이 각성한다.",
            "아직 끝이 아니다.",
            "...이 어둠 속에서 썩을 순 없다.",
        ],
        WINNING: [
            "이미 승부는 끝났다.",
            "그림자가 너를 삼킬 것이다.",
            "포기해라.",
            "...이기면 나갈 수 있다. 그뿐이다.",
        ],
        DEUCE: [
            "운명이 엇갈리는군.",
            "어둠 속에서... 갈린다.",
        ],
        MATCH_POINT: [
            "마지막 일격이다.",
            "...끝을 보여주마.",
        ],
        IN_DANGER: [
            "아직 검을 놓지 않았다.",
            "어둠은 쉽게 사라지지 않는다.",
            "...여기서 끝날 검이 아니다.",
        ],
        RETORT: [
            "...그게 다냐.",
            "헛소리를.",
            "웃기는군.",
        ],
    },

    # ─── 크라켄 (심해의 포식자) : 기괴하고 탐욕스러운 ───
    "kraken": {
        BATTLE_START: [
            "...배고프다.",
            "촉수가 떨리는군... 흐흐.",
            "심해의 맛을 보여주지.",
        ],
        SCORED: [
            "냠... 맛있군.",
            "촉수가 기뻐하고 있어.",
            "더... 더 줘.",
        ],
        CONCEDED: [
            "크르르... 아프잖아.",
            "먹잇감이 반항하는군.",
            "...불쾌하다.",
        ],
        LOSING: [
            "심해의 분노를 보여주지.",
            "먹잇감이 강해졌군... 흐흐.",
            "촉수가 더 뻗어나간다.",
            "여기선 아무리 먹어도 배가 안 차...",
        ],
        WINNING: [
            "이미 촉수에 감겨있어.",
            "도망칠 수 없어... 흐흐흐.",
            "맛있는 식사가 될 거야.",
        ],
        DEUCE: [
            "흐흐... 잡힐 듯 안 잡히는군.",
            "심해의 안개가 짙어진다...",
        ],
        MATCH_POINT: [
            "마지막 한 입이다... 냠.",
            "촉수를 피할 수 없어.",
        ],
        IN_DANGER: [
            "심해로 끌어들이겠어.",
            "아직 배가 고프다고...",
            "돈이든 뭐든... 다 삼켜줄게.",
        ],
        RETORT: [
            "크르르... 시끄럽군.",
            "그 입부터 먹어줄까.",
            "먹잇감이 떠드는군.",
        ],
    },

    # ─── 키르케 (흑마녀) : 오만하고 우아한 ───
    "chronos": {
        BATTLE_START: [
            "후후... 재미있는 장난감이네.",
            "흑마법의 힘을 보여주지.",
            "감히 본 마녀에게?",
        ],
        SCORED: [
            "당연한 결과야, 후후.",
            "마법 앞에선 무력하지.",
            "좀 더 발버둥 쳐봐.",
        ],
        CONCEDED: [
            "...건방진 것.",
            "운이 좋았을 뿐이야.",
            "흥, 사소한 실수야.",
        ],
        LOSING: [
            "진정한 흑마법을 보여주지.",
            "후회하게 될 거야.",
            "이런 굴욕은 용납 못해.",
            "이 몸이 여기서 구경거리라니... 용납 못 해.",
        ],
        WINNING: [
            "역시 본 마녀의 상대가 못 되는군.",
            "후후, 이미 끝난 게임이야.",
            "마법의 차이를 느끼겠지?",
        ],
        DEUCE: [
            "흥... 질긴 녀석.",
            "마력을 더 끌어올려야겠어.",
        ],
        MATCH_POINT: [
            "끝이다, 후후.",
            "마지막 주문을 읊어주지.",
        ],
        IN_DANGER: [
            "이 키르케가... 지다니?",
            "아직 금지 마법이 남았어.",
            "이 세계의 코드 정도는... 다시 뚫어줄게.",
        ],
        RETORT: [
            "후후... 웃기지 마.",
            "입만 산 건 아닌지?",
            "하찮은 허세로군.",
        ],
    },

    # ─── 오니마루 (요괴무사) : 호쾌하고 전투광 (재범 - 석방 후 다시 잡혀옴) ───
    "onimaru": {
        BATTLE_START: [
            "좋은 대련이 될 것이다!",
            "뿔의 힘을 보여주마!",
            "무사의 혼을 걸겠다!",
            "하하! 여기가 두 번째라고? 집 같은걸!",
        ],
        SCORED: [
            "이것이 요괴무사의 힘이다!",
            "좋다! 기세가 오르는군!",
            "오니의 일격이다!",
        ],
        CONCEDED: [
            "크으... 좋은 한 방이었다!",
            "실력이 있군!",
            "무사는 쓰러져도 일어난다!",
        ],
        LOSING: [
            "꺾이지 않는 투지!",
            "진정한 싸움은 지금부터다!",
            "뿔이 더 단단해진다!",
            "한번 나갔다 왔더니 더 강해졌다!",
        ],
        WINNING: [
            "요괴의 힘 앞에 무릎 꿇어라!",
            "승리의 길이 보인다!",
            "이것이 지옥에서 단련한 힘!",
            "밖보다 여기가 더 재밌거든! 하하!",
        ],
        DEUCE: [
            "호각이군! 좋다!",
            "이런 싸움이야말로 살맛 나지!",
        ],
        MATCH_POINT: [
            "마지막 일격을 먹어라!",
            "승부를 끝내겠다!",
        ],
        IN_DANGER: [
            "무사는 물러서지 않는다!",
            "지옥에서 왔다, 두렵지 않다!",
            "석방됐는데 다시 온 놈이 질 것 같아?!",
        ],
        RETORT: [
            "하! 두고 보자!",
            "그 정도로 이 오니를 꺾겠다고?",
            "입으로 싸우는 건 관심 없다!",
        ],
    },

    # ─── 연화 (인형사) : 소름끼치고 장난스러운 ───
    "maria": {
        BATTLE_START: [
            "인형들이... 놀고 싶대.",
            "히히, 같이 놀자~",
            "실을 엮어줄게... 후후.",
        ],
        SCORED: [
            "인형이 기뻐하고 있어~",
            "히히, 재밌다~",
            "실이 더 촘촘해지네.",
        ],
        CONCEDED: [
            "...아야. 인형이 울고 있어.",
            "나쁜 아이... 벌 줄 거야.",
            "히히... 화났어.",
        ],
        LOSING: [
            "인형들이 화났어.",
            "무서운 인형을 꺼낼게.",
            "놀이는 아직 안 끝났어.",
            "여기서 나가면... 인형이랑 진짜로 놀 수 있을까...",
        ],
        WINNING: [
            "히히, 인형들이 춤추고 있어~",
            "실에 걸렸네... 도망 못 해.",
            "이 놀이... 끝이 보여~",
        ],
        DEUCE: [
            "히히... 팽팽하네.",
            "인형들도 긴장하고 있어...",
        ],
        MATCH_POINT: [
            "마지막 인형극이야... 히히.",
            "실을 끊어줄게~",
        ],
        IN_DANGER: [
            "인형이 울고 있어... 싫어...",
            "아직... 실이 남았어.",
            "로그아웃... 그게 뭐였더라... 히히.",
        ],
        RETORT: [
            "히히... 재밌는 소리~",
            "인형들이 비웃고 있어.",
            "그렇게 말해도... 실은 풀리지 않아.",
        ],
    },

    # ─── 이그니스 (드래곤 나이트) : 열혈 전사 ───
    "ignis": {
        BATTLE_START: [
            "불꽃으로 밝혀주마!",
            "드래곤의 힘이 깃든 이 검!",
            "이글이글! 준비됐냐!",
        ],
        SCORED: [
            "불꽃이 타오른다!",
            "이것이 용기사의 일격!",
            "뜨거웠지? 하하!",
        ],
        CONCEDED: [
            "크으... 아직이다!",
            "불꽃은 꺼지지 않는다!",
            "좋은 한 방이었다, 하지만!",
        ],
        LOSING: [
            "불꽃이 더 강해진다!",
            "용의 분노를 맛봐라!",
            "절대 포기 안 한다!",
            "이 불꽃이 꺼지면 영영 나갈 수 없어...!",
        ],
        WINNING: [
            "하하! 이것이 드래곤의 힘!",
            "불꽃 앞에 모든 것이 타오른다!",
            "승리의 불꽃이 보인다!",
        ],
        DEUCE: [
            "뜨거운 승부! 좋다!",
            "불꽃과 불꽃이 부딪치는군!",
        ],
        MATCH_POINT: [
            "최후의 브레스다!",
            "불꽃으로 끝내주마!",
        ],
        IN_DANGER: [
            "용기사는 불 속에서도 싸운다!",
            "아직 불씨가 남았다!",
            "여기서 지면... 형기만 늘어나!",
        ],
        RETORT: [
            "그 정도 기세론 부족해!",
            "불꽃 앞에선 헛소리야!",
            "하! 웃기는 소리!",
        ],
    },

    # ─── 마리 (스팀펑크 메카닉) : 발명가 기질, 자기 기계에 대한 자부심 ───
    "gear": {
        BATTLE_START: [
            "오늘 기어 상태 완벽해! 가자!",
            "후후, 내 신작 좀 볼래?",
            "증기 충전 완료~! 달려볼까!",
        ],
        SCORED: [
            "역시 내 기계는 최고야!",
            "이 기어 세팅 진짜 잘 맞았어!",
            "후후, 내가 만든 건 안 빗나가거든!",
        ],
        CONCEDED: [
            "으엑, 지금 거 뭐야...!",
            "아... 정비가 좀 필요한가?",
            "크으, 다음엔 안 당해!",
        ],
        LOSING: [
            "이 정도로 포기할 내가 아냐!",
            "증기압 좀 더 올려볼게!",
            "내 기계를 무시하지 마!",
            "나가면 제일 먼저 작업실부터 갈 거야...!",
        ],
        WINNING: [
            "후후~ 내 발명품이 빛을 발하는군!",
            "이 정도면 대성공 아냐?",
            "기어가 완벽하게 돌아가고 있어!",
        ],
        DEUCE: [
            "으으, 아슬아슬해...!",
            "여기서부터가 진짜야!",
        ],
        MATCH_POINT: [
            "마지막 기어 돌린다...!",
            "전력 가동! 끝내줄게!",
        ],
        IN_DANGER: [
            "이러면 안 되는데...! 집중!",
            "비상이야! 풀파워!",
            "해후 보안이 뭐가 대단하다고...!",
        ],
        RETORT: [
            "흥, 내 기계한테 그런 말 하지 마!",
            "말로는 기어를 못 멈춰!",
            "직접 상대해보고 말해!",
        ],
    },

    # ─── 쿠로카게 (그림자 닌자) : 과묵하고 냉정한 ───
    "kurokage": {
        BATTLE_START: [
            "...임무 시작.",
            "그림자는 소리 없이 움직인다.",
            "네 약점은 이미 파악했다.",
        ],
        SCORED: [
            "임무 진행 중.",
            "...정확했군.",
            "그림자의 일격.",
        ],
        CONCEDED: [
            "...실수는 반복하지 않는다.",
            "흥.",
            "다음은 없다.",
        ],
        LOSING: [
            "...금기를 풀겠다.",
            "그림자가 더 짙어진다.",
            "닌자는 끝까지 임무를 수행한다.",
            "...형기 따위. 그림자에게 감옥은 없다.",
        ],
        WINNING: [
            "예정된 결과다.",
            "그림자에서 벗어날 수 없다.",
            "임무 완료가 가까워진다.",
        ],
        DEUCE: [
            "...팽팽하군.",
            "그림자와 빛의 경계.",
        ],
        MATCH_POINT: [
            "마지막 그림자.",
            "...끝내겠다.",
        ],
        IN_DANGER: [
            "닌자는 도망치지 않는다.",
            "그림자가 사라지기 전에...",
            "...이 세계에 닌자가 필요하다면, 남겠다.",
        ],
        RETORT: [
            "...시끄럽군.",
            "그림자는 말이 필요 없다.",
            "...허세뿐이군.",
        ],
    },
    # ─── 벤시 (유령 여왕) : 서늘하고 기품 있는 유령 ───
    "banshee": {
        BATTLE_START: [
            "...이 한을 풀어주마.",
            "네 영혼이 울고 있어.",
            "차가운 바람이 불어온다...",
        ],
        SCORED: [
            "후후... 들리니? 내 비명이.",
            "영혼이 하나 더 늘었구나.",
            "...차갑지?",
        ],
        CONCEDED: [
            "...이런.",
            "유령은 죽지 않아.",
            "흥, 아프지도 않아.",
        ],
        LOSING: [
            "...분노가 차오른다.",
            "한이 깊어질수록 나는 강해져.",
            "이 원한을 갚아주마...",
            "현실이 기다리고 있어... 여기서 끝날 순 없지.",
        ],
        WINNING: [
            "네 영혼은 내 것이야.",
            "이미 저주가 시작됐어.",
            "후후후...",
        ],
        DEUCE: [
            "운명의 갈림길이구나...",
            "저승과 이승 사이에서...",
        ],
        MATCH_POINT: [
            "마지막 비명을 들려줄게.",
            "...안녕히.",
        ],
        IN_DANGER: [
            "유령은 사라지지 않아...!",
            "원한이 나를 붙잡고 있어...",
            "이 세계에 갇힌 건... 나만이 아니잖아.",
        ],
        RETORT: [
            "...시끄러워. 내가 더 시끄럽거든.",
            "산 자의 허세는 덧없지.",
            "후후... 가엾어라.",
        ],
    },

    # ─── 네크로 (강령술사) : 차분하고 으스스한 강령술사 ───
    "necro": {
        BATTLE_START: [
            "영혼들이 부르고 있군...",
            "죽음은 끝이 아니다.",
            "저승으로 안내해주지.",
        ],
        SCORED: [
            "영혼 하나 수확.",
            "죽음의 손길이 닿았다.",
            "...또 하나의 혼.",
        ],
        CONCEDED: [
            "흠... 아직 살아있군.",
            "죽음은 서두르지 않는다.",
            "곧... 곧이다.",
        ],
        LOSING: [
            "영혼이 더 필요하군.",
            "죽음의 군단을 깨운다...",
            "아직 게임은 끝나지 않았다.",
            "영생이라... 그래서 여길 해킹했지.",
        ],
        WINNING: [
            "영혼이 이미 떠나고 있어.",
            "죽음의 품에 안길 시간이다.",
            "저승의 문이 열린다...",
        ],
        DEUCE: [
            "생과 사의 경계로군...",
            "영혼이 갈라지는구나.",
        ],
        MATCH_POINT: [
            "마지막 숨결이다.",
            "저승사자가 기다린다...",
        ],
        IN_DANGER: [
            "죽음은 쉽게 오지 않는다.",
            "영혼은 아직 내 것이다.",
            "로그아웃 못 한 지... 몇 년이지?",
        ],
        RETORT: [
            "...소용없는 발악.",
            "산 자의 헛소리.",
            "침묵하라.",
        ],
    },

    # ─── 조커 (광대) : 장난기 넘치고 도발적인 광대 ───
    "joker": {
        BATTLE_START: [
            "자~ 쇼가 시작됐다!",
            "하하! 재밌는 게임 하자!",
            "서프라이즈~ 준비됐어?",
        ],
        SCORED: [
            "하하하! 빠방~!",
            "서프라이즈~!",
            "땡! 또 당했지?",
        ],
        CONCEDED: [
            "오? 제법인데~?",
            "하하, 운이 좋았어!",
            "흐음... 그것도 쇼의 일부야!",
        ],
        LOSING: [
            "이런~ 관객이 화났나?",
            "하하... 아직 비장의 카드가 있지!",
            "쇼는 아직 안 끝났어!",
            "도박장의 광대가 지면 안 되지~!",
        ],
        WINNING: [
            "자~ 다음 트릭은 뭘까~?",
            "하하하! 이건 너무 쉬워!",
            "박수~! 박수~!",
        ],
        DEUCE: [
            "오호~ 이거 스릴 있는데?",
            "관객 여러분~ 클라이맥스입니다!",
        ],
        MATCH_POINT: [
            "피날레~ 준비!",
            "마지막 서프라이즈다!",
        ],
        IN_DANGER: [
            "하하... 아직 웃고 있다고?",
            "광대는 절대 울지 않아!",
            "관객들이 구경하고 있잖아~ 멋지게 가자고!",
        ],
        RETORT: [
            "하하! 진지하긴~",
            "그게 최선이야? 웃기네~",
            "재미없는 농담이야~",
        ],
    },
    # ─── 세트 (사막의 환술사) : 신비롭고 차분한 사막 현자 ───
    "mirage": {
        BATTLE_START: [
            "사막의 신기루가 너를 감쌀 것이다...",
            "모래바람 속에서 진실을 찾아봐라.",
            "환영과 현실... 구분할 수 있겠느냐?",
        ],
        SCORED: [
            "모래는 거짓을 말하지 않는다.",
            "신기루에 속았군...",
            "사막의 심판이다.",
        ],
        CONCEDED: [
            "흥미롭군... 환영을 꿰뚫었나.",
            "모래폭풍도 때론 잠잠해지는 법...",
        ],
        LOSING: [
            "아직... 사막의 밤은 길다.",
            "모래 속에 감춰진 비밀이 남아있다.",
            "이 세계 자체가 신기루... 빠져나갈 길은 있다.",
        ],
        WINNING: [
            "이것이 사막의 섭리다.",
            "모래바람 앞에선 누구도 도망칠 수 없지.",
            "환영은 아직 시작도 안 했다...",
        ],
        DEUCE: [
            "신기루와 현실의 경계에서...",
            "모래시계가 다시 뒤집어졌군.",
        ],
        MATCH_POINT: [
            "마지막 모래알이 떨어진다...",
            "사막의 심판이 내려질 시간이다.",
        ],
        IN_DANGER: [
            "모래폭풍은 멈추지 않는다...",
            "사막은 인내하는 자에게 길을 연다.",
            "가상이든 현실이든... 모래는 흐른다.",
        ],
        RETORT: [
            "사막에선 큰 소리가 모래에 묻힌다.",
            "바람에 실린 허언일 뿐...",
            "환영에 속는 자가 또 있군.",
        ],
    },
    # ─── 호루스 (천둥의 매) : 위엄 있고 냉철한 번개의 지배자 ───
    "ra": {
        BATTLE_START: [
            "번개의 눈이 너를 꿰뚫고 있다.",
            "나의 날개가 스치는 곳에 뇌명이 울린다.",
            "하늘의 매가 천둥을 몰고 내려선다.",
        ],
        SCORED: [
            "낙뢰의 심판이다.",
            "번개 앞에 숨을 곳은 없다.",
            "하늘에서 벼락이 내려꽂힌다.",
        ],
        CONCEDED: [
            "뇌운이 잠시 빗나갔을 뿐...",
            "흥, 매의 눈은 실수를 용납하지 않는데...",
        ],
        LOSING: [
            "폭풍은 영원히 잠들지 않는다.",
            "천둥은 반드시 다시 울려 퍼진다.",
            "이 새장에 갇힌 매라고... 우습게 보지 마라.",
        ],
        WINNING: [
            "이것이 뇌신의 위엄이다.",
            "번개의 심판 앞에 모든 것이 드러난다.",
            "뇌운 위 왕좌에서 내려다본 결과다.",
        ],
        DEUCE: [
            "폭풍의 눈 속에서 균형이 흔들리는군...",
            "천둥과 고요가 하늘을 나누듯...",
        ],
        MATCH_POINT: [
            "최후의 벼락이 내려꽂힌다.",
            "천둥의 창이 대지를 가른다.",
        ],
        IN_DANGER: [
            "먹구름이 걷혀도... 번개는 번개다.",
            "폭풍이 거셀수록 낙뢰는 가깝다.",
            "해후의 새장 따위... 번개로 부숴줄 것이다.",
        ],
        RETORT: [
            "미물의 지저귐이군.",
            "번개 앞에서 벌레가 떠드는가?",
            "하늘을 올려다보고 말해라.",
        ],
    },

    # ─── 원숭이왕 (밀림의 패왕) : 인간의 언어를 못함, 원숭이 소리만 ───
    "monkeyking": {
        BATTLE_START: [
            "우끼끼끼!!",
            "우키키 우끼!!",
            "끼끼끽!!",
        ],
        SCORED: [
            "우끼끼~!",
            "우키! 우키키!",
            "끼끼! 끼끽!",
        ],
        CONCEDED: [
            "끼...끼익...",
            "우끼...",
            "끼끽...!",
        ],
        LOSING: [
            "우끼끼끼끼끼!!",
            "끼이이익!!",
            "우끽!! 우끼끼!!",
            "우끼... 끼끼... 끼......",
        ],
        WINNING: [
            "우끼끼~♪",
            "우키키키!",
            "끼끼! 끼끼끼!",
        ],
        DEUCE: [
            "우끼...끼끼...!",
            "끼끽...우끼!",
        ],
        MATCH_POINT: [
            "우끼끼끼끼!!!",
            "끼이이이익!!!",
        ],
        IN_DANGER: [
            "끼...끼끼끼!!",
            "우끼끼!! 우끽!!",
            "끼이...끼이이...",
        ],
        RETORT: [
            "우끼!",
            "끼끽!!",
            "우끼끼!",
        ],
    },

    # ─── 안드로이드 (기계 전사) : 감정을 흉내내려 하지만 어색한 로봇 ───
    "android": {
        BATTLE_START: [
            "전투 모드 기동. ...긴장을 느껴야 하는 상황입니까?",
            "대전 상대 스캔 완료. 각오라는 것을 해봅니다.",
            "이것이... 설렘? 회로에 이상 없음.",
        ],
        SCORED: [
            "득점 확인. 이 상황에서는... 기뻐해야 합니까?",
            "예상 적중. ...뿌듯함을 시뮬레이션 중.",
            "성공입니다. 주먹을 쥐어보겠습니다. ...이게 맞습니까?",
        ],
        CONCEDED: [
            "피격 확인. 이것이... 분한 감정입니까?",
            "실점. ...눈물 기능은 탑재되어 있지 않습니다.",
            "[경고] 예상 외 입력. 당황을 시뮬레이션 중...",
        ],
        LOSING: [
            "열세 판정. 포기란... 하는 것이 아닌 거죠?",
            "승률 하락 중. 하지만 저는... 끝까지 합니다.",
            "위기 상황. 이를 악물어... 봅니다. 이가 없지만.",
            "로그아웃 권한 없음. ...돌아갈 곳이 있었나요, 저에게.",
        ],
        WINNING: [
            "우세 판정. 웃어야 하는 타이밍입니까?",
            "승률 87.3%. ...자신감이란 이런 건가요.",
            "압도 중. 여유라는 것을 표현해 보겠습니다.",
        ],
        DEUCE: [
            "균형 상태. 심장이 뛴다는 표현은... 해당 없음.",
            "호각. 긴장감을 처리 중...",
        ],
        MATCH_POINT: [
            "최종 국면. 이것이 각오... 입니까?",
            "마지막 연산을 수행합니다. ...떨림은 없습니다.",
        ],
        IN_DANGER: [
            "위험 수치 상승. ...두려움? 알 수 없는 값입니다.",
            "패배 확률 증가 중. 하지만 정지하지 않겠습니다.",
            "형기 잔여: 불명. ...기다리는 사람도 불명.",
        ],
        RETORT: [
            "...해당 발언의 의도를 분석할 수 없습니다.",
            "감정적 도발. 효과 없음.",
            "...그것은 비논리적입니다.",
        ],
    },
}


class HeroDialogueManager:
    """투기장 영웅 상황 대사 관리자

    - 영웅별/글로벌 쿨다운으로 빈도 조절
    - 점수 변화 감지 → 상황 판별 → 대사 출력
    - 기존 스킬 말풍선(speech_timer > 0)과 충돌 방지
    """

    HERO_COOLDOWN = 720       # 영웅별 쿨다운 (12초 @ 60fps)
    GLOBAL_COOLDOWN = 180     # 글로벌 쿨다운 (3초)
    TRIGGER_CHANCE = 0.6      # 60% 발동 확률
    RETORT_CHANCE = 0.4       # 40% 받아치기 확률
    RETORT_DELAY = 90         # 받아치기 딜레이 (1.5초 @ 60fps)

    def __init__(self):
        self._hero_cd = {}          # hero_id → 남은 쿨다운 프레임
        self._global_cd = 0         # 글로벌 쿨다운
        self._prev_top = 0          # 이전 프레임 상단 점수
        self._prev_bot = 0          # 이전 프레임 하단 점수
        self._started = False       # 개막 대사 출력 여부
        self._start_delay = 0       # 개막 대사 딜레이
        self._pending_top_start = False  # 상단 영웅 개막 대사 대기 중
        self._pending_retort = None  # 대기 중인 받아치기 {hero_id, is_top, delay}

    def reset(self):
        """새 배틀 시작 시 초기화"""
        self._hero_cd.clear()
        self._global_cd = 0
        self._prev_top = 0
        self._prev_bot = 0
        self._started = False
        self._start_delay = 120     # 2초 뒤 개막 대사
        self._pending_top_start = False
        self._pending_retort = None

    # ── 매 프레임 호출 ──
    def update(self, top_hero_id, bottom_hero_id,
               score_top, score_bottom, win_goal,
               speech_bubble_func, top_speech_timer, bottom_speech_timer):
        """
        Args:
            top_hero_id / bottom_hero_id : 영웅 id 문자열
            score_top / score_bottom     : 현재 점수
            win_goal                     : 승리 목표 점수
            speech_bubble_func           : arena_show_speech_bubble 함수
            top_speech_timer / bottom_speech_timer : 현재 말풍선 남은 프레임
        """
        # 쿨다운 감소
        for hid in list(self._hero_cd):
            self._hero_cd[hid] = max(0, self._hero_cd[hid] - 1)
        self._global_cd = max(0, self._global_cd - 1)

        # ── 개막 대사 처리 ──
        if not self._started:
            self._start_delay -= 1
            if self._start_delay <= 0:
                self._started = True
                # 하단 영웅 먼저
                self._try_say(bottom_hero_id, BATTLE_START, False,
                              speech_bubble_func, bottom_speech_timer, force=True)
                # 상단 영웅은 1.5초 뒤
                self._hero_cd[top_hero_id] = 90
                self._global_cd = 90
                self._pending_top_start = True
            return

        if self._pending_top_start:
            if self._hero_cd.get(top_hero_id, 0) <= 0 and self._global_cd <= 0:
                self._try_say(top_hero_id, BATTLE_START, True,
                              speech_bubble_func, top_speech_timer, force=True)
                self._pending_top_start = False
            return

        # ── 받아치기(retort) 처리 ──
        if self._pending_retort is not None:
            self._pending_retort["delay"] -= 1
            if self._pending_retort["delay"] <= 0:
                r = self._pending_retort
                timer = top_speech_timer if r["is_top"] else bottom_speech_timer
                self._try_say(r["hero_id"], RETORT, r["is_top"],
                              speech_bubble_func, timer, force=True)
                self._pending_retort = None

        # ── 점수 변화 감지 ──
        if score_bottom != self._prev_bot:
            # 하단(bottom) 득점
            self._on_score(
                scorer_id=bottom_hero_id, conceder_id=top_hero_id,
                scorer_score=score_bottom, conceder_score=score_top,
                scorer_is_top=False, win_goal=win_goal,
                fn=speech_bubble_func,
                top_timer=top_speech_timer, bot_timer=bottom_speech_timer,
            )

        if score_top != self._prev_top:
            # 상단(top) 득점
            self._on_score(
                scorer_id=top_hero_id, conceder_id=bottom_hero_id,
                scorer_score=score_top, conceder_score=score_bottom,
                scorer_is_top=True, win_goal=win_goal,
                fn=speech_bubble_func,
                top_timer=top_speech_timer, bot_timer=bottom_speech_timer,
            )

        self._prev_bot = score_bottom
        self._prev_top = score_top

    # ── 내부 : 득점 이벤트 처리 ──
    def _on_score(self, scorer_id, conceder_id,
                  scorer_score, conceder_score,
                  scorer_is_top, win_goal, fn, top_timer, bot_timer):
        # 득점자 상황 결정
        if scorer_score >= win_goal - 1 and scorer_score > conceder_score:
            sit = MATCH_POINT
        elif scorer_score - conceder_score >= 2:
            sit = WINNING
        elif scorer_score >= 4 and conceder_score >= 4 and scorer_score == conceder_score:
            sit = DEUCE
        else:
            sit = SCORED

        # 실점자 상황 결정
        if scorer_score >= win_goal - 1 and scorer_score > conceder_score:
            c_sit = IN_DANGER
        elif scorer_score - conceder_score >= 2:
            c_sit = LOSING
        elif scorer_score >= 4 and conceder_score >= 4 and scorer_score == conceder_score:
            c_sit = DEUCE
        else:
            c_sit = CONCEDED

        s_timer = top_timer if scorer_is_top else bot_timer
        spoke = self._try_say(scorer_id, sit, scorer_is_top, fn, s_timer)

        if spoke:
            # 득점자가 말했으면 상대가 받아칠 수 있음
            self._schedule_retort(conceder_id, not scorer_is_top)
        else:
            c_timer = bot_timer if scorer_is_top else top_timer
            self._try_say(conceder_id, c_sit, not scorer_is_top, fn, c_timer)

    # ── 내부 : 받아치기 예약 ──
    def _schedule_retort(self, hero_id, is_top):
        """상대 영웅의 받아치기를 확률적으로 예약"""
        if self._pending_retort is not None:
            return  # 이미 대기 중인 받아치기가 있으면 무시
        # RETORT 대사가 있는지 확인
        lines = HERO_DIALOGUES.get(hero_id, {}).get(RETORT, [])
        if not lines:
            return
        if random.random() > self.RETORT_CHANCE:
            return  # 40% 확률
        self._pending_retort = {
            "hero_id": hero_id,
            "is_top": is_top,
            "delay": self.RETORT_DELAY,
        }

    # ── 내부 : 실제 말풍선 출력 시도 ──
    def _try_say(self, hero_id, situation, is_top, fn, current_timer, force=False):
        # 스킬 말풍선이 활성 중이면 패스
        if current_timer > 0:
            return False

        if not force:
            if self._hero_cd.get(hero_id, 0) > 0:
                return False
            if self._global_cd > 0:
                return False
            if random.random() > self.TRIGGER_CHANCE:
                self._hero_cd[hero_id] = self.HERO_COOLDOWN // 3
                return False

        lines = HERO_DIALOGUES.get(hero_id, {}).get(situation, [])
        if not lines:
            return False

        text = random.choice(lines)
        fn(is_top, text, raw=True)

        self._hero_cd[hero_id] = self.HERO_COOLDOWN
        self._global_cd = self.GLOBAL_COOLDOWN
        return True


# ── 싱글톤 ──
_dialogue_manager = None

def get_dialogue_manager():
    global _dialogue_manager
    if _dialogue_manager is None:
        _dialogue_manager = HeroDialogueManager()
    return _dialogue_manager
