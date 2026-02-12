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
        ],
        WINNING: [
            "이미 승부는 끝났다.",
            "그림자가 너를 삼킬 것이다.",
            "포기해라.",
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
        ],
        RETORT: [
            "후후... 웃기지 마.",
            "입만 산 건 아닌지?",
            "하찮은 허세로군.",
        ],
    },

    # ─── 오니마루 (요괴무사) : 호쾌하고 전투광 ───
    "onimaru": {
        BATTLE_START: [
            "좋은 대련이 될 것이다!",
            "뿔의 힘을 보여주마!",
            "무사의 혼을 걸겠다!",
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
        ],
        WINNING: [
            "요괴의 힘 앞에 무릎 꿇어라!",
            "승리의 길이 보인다!",
            "이것이 지옥에서 단련한 힘!",
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
        ],
        RETORT: [
            "그 정도 기세론 부족해!",
            "불꽃 앞에선 헛소리야!",
            "하! 웃기는 소리!",
        ],
    },

    # ─── 마리 (스팀펑크 메카닉) : 이성적이고 분석적 ───
    "gear": {
        BATTLE_START: [
            "분석 완료. 승률 87.3%.",
            "기계는 거짓말을 하지 않아.",
            "증기압 최적화. 전투 개시.",
        ],
        SCORED: [
            "계산대로야.",
            "예측 범위 안이야.",
            "기어 시스템 정상 작동 중.",
        ],
        CONCEDED: [
            "...오차 범위 내야.",
            "수정 알고리즘 적용 중.",
            "데이터 재분석 필요.",
        ],
        LOSING: [
            "변수가 많아... 재계산 중.",
            "비상 프로토콜 가동!",
            "증기압 과부하 모드!",
        ],
        WINNING: [
            "예측 모델 정확도 98%.",
            "모든 것이 계산 안이야.",
            "기계적 우위 확인.",
        ],
        DEUCE: [
            "확률 50:50... 흥미로운 데이터야.",
            "변수가 수렴하고 있어.",
        ],
        MATCH_POINT: [
            "최종 연산 실행.",
            "마지막 기어를 돌려줄게.",
        ],
        IN_DANGER: [
            "경고: 패배 확률 상승 중...",
            "비상! 풀파워 모드 가동!",
        ],
        RETORT: [
            "...데이터상 근거 없는 발언이야.",
            "감정론은 비효율적이야.",
            "수치로 말해줄까?",
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
        ],
        RETORT: [
            "...소용없는 발악.",
            "산 자의 헛소리.",
            "침묵하라.",
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
