"""
스테이지 1~8 보스 상황별 대사 시스템
- 투기장 영웅 대사 시스템(hero_dialogues.py)과 동일한 패턴
- 보스만 말하고, 기존 스킬 외침풍선과 별도 채널로 동작
"""

import random

from localization.manager import get_localization_manager
_loc = get_localization_manager()
def _t(key, fallback=""):
    return _loc.get_text(key, fallback)

# 보스 변형 키 매핑 (한글 보스이름 → 영문 키)
_VARIANT_KEY_MAP = {
    "포도대장": "podo",
    "각시탈": "gaksi",
    "두더지왕": "mole",
}

# ── 대사 상황 상수 ──
BATTLE_START = "battle_start"
SCORED = "scored"          # 보스 득점
CONCEDED = "conceded"      # 보스 실점 (플레이어 득점)
LOSING = "losing"          # 보스 2점 이상 뒤처짐
WINNING = "winning"        # 보스 2점 이상 앞섬
MATCH_POINT = "match_point" # 보스 매치포인트
IN_DANGER = "in_danger"    # 플레이어 매치포인트

# ── 8보스 × 7상황 대사 데이터 ──
# 키: 스테이지 번호 (1~8)
BOSS_DIALOGUES = {
    # ─── 스테이지 1: 풍악보이 (장난스런 전통음악 소년) ───
    1: {
        BATTLE_START: [
            "자~ 신나는 한 판 해볼까!",
            "이 리듬에 맞춰봐!",
            "풍악을 울려라~!",
        ],
        SCORED: [
            "이 리듬을 따라올 수 있겠어?",
            "딩동댕~ 한 점!",
            "내 장단에 놀아나는군!",
        ],
        CONCEDED: [
            "오~ 꽤 하는데?",
            "흥, 박자가 어긋났을 뿐이야.",
            "운이 좋았어!",
        ],
        LOSING: [
            "아직 클라이맥스가 안 왔는데!",
            "이 정도에 물러설 풍악보이가 아니지!",
        ],
        WINNING: [
            "이대로 피날레다~!",
            "내 리듬을 못 따라오는군!",
        ],
        MATCH_POINT: [
            "마지막 한 소절이다!",
            "피날레를 장식해주마!",
        ],
        IN_DANGER: [
            "끝까지 연주는 계속된다!",
            "아직 앵콜이 남았어!",
        ],
    },

    # ─── 스테이지 2: 악어장군 (위엄있는 정글의 장군) ───
    2: {
        BATTLE_START: [
            "정글의 왕이 상대해주마!",
            "이 늪에서 살아남을 수 있겠나!",
            "전진! 돌격이다!",
        ],
        SCORED: [
            "이것이 정글의 법칙이다!",
            "본관의 이빨을 맛보거라!",
            "하하! 나약한 것!",
        ],
        CONCEDED: [
            "크으... 제법이군.",
            "이 정도는 찰과상이다!",
            "잔꾀를 부리는군!",
        ],
        LOSING: [
            "악어장군은 물러서지 않는다!",
            "정글의 왕이 지다니... 있을 수 없다!",
        ],
        WINNING: [
            "하하하! 이것이 실력의 차이다!",
            "정글에서 빠져나갈 수 없다!",
        ],
        MATCH_POINT: [
            "최후의 돌격이다!",
            "이 한 방으로 끝장을 내겠다!",
        ],
        IN_DANGER: [
            "악어는 궁지에 몰릴수록 강하다!",
            "본관을 얕보지 마라!",
        ],
    },

    # ─── 스테이지 3: 멘헤라걸 (불안정하고 소름끼치는 소녀) ───
    3: {
        BATTLE_START: [
            "같이 놀아줄 거지...?",
            "도망가지 마... 제발...",
            "히히... 시작이야.",
        ],
        SCORED: [
            "히히... 아팠어?",
            "싫어하지 마... 더 아프게 할 거야.",
            "인형처럼 예쁘게 쓰러져...",
        ],
        CONCEDED: [
            "왜... 왜 나를 때려...",
            "아파... 아파아아...",
            "싫어... 나빠...!",
        ],
        LOSING: [
            "나를... 버릴 거야...?",
            "그러면 안 돼... 안 돼에에...",
        ],
        WINNING: [
            "히히히... 이제 내 거야.",
            "도망갈 수 없어... 영원히...",
        ],
        MATCH_POINT: [
            "끝이야... 같이 가자...",
            "영원히 함께야... 히히.",
        ],
        IN_DANGER: [
            "버리지 마아아아...!",
            "아직... 끝내고 싶지 않아...",
        ],
    },

    # ─── 스테이지 4: 퐁크 (명상적이고 철학적인 사원 수도승) ───
    4: {
        BATTLE_START: [
            "진정한 수행이 시작된다.",
            "평정심을 유지하거라.",
            "옴... 마니반메훔...",
        ],
        SCORED: [
            "이것도 수행의 일부다.",
            "깨달음의 길은 험하지.",
            "아직 수련이 부족하구나.",
        ],
        CONCEDED: [
            "깨달음이 부족했군.",
            "흠... 좋은 가르침이었다.",
            "수행은 고통 속에 있다.",
        ],
        LOSING: [
            "번뇌가 흔들릴 뿐이다.",
            "진정한 깨달음은 고난에서 온다.",
        ],
        WINNING: [
            "마음의 평화가 승리를 이끈다.",
            "수행의 결실이 보이는군.",
        ],
        MATCH_POINT: [
            "마지막 관문이다, 정진하거라.",
            "해탈의 순간이 다가온다.",
        ],
        IN_DANGER: [
            "집착을 버리면 길이 보인다.",
            "아직 수행은 끝나지 않았다.",
        ],
    },

    # ─── 스테이지 5: 네메시스 (냉철한 해군 사령관) ───
    # 주의: 코드에서는 stage6 변수명이지만 실제 스테이지 5
    5: {
        BATTLE_START: [
            "전투 태세 진입. 포격 개시.",
            "이 바다의 주인은 나다.",
            "소나 탐지 완료. 격침한다.",
        ],
        SCORED: [
            "전술대로 진행 중.",
            "명중. 다음 표적으로.",
            "도주 경로는 없다.",
        ],
        CONCEDED: [
            "이 정도는 예상 범위다.",
            "경미한 손상. 전투 속행.",
            "반격 좌표 수정.",
        ],
        LOSING: [
            "전략을 재편성한다.",
            "전세 역전을 위한 작전 개시.",
        ],
        WINNING: [
            "포위망이 좁혀지고 있다.",
            "퇴각할 기회는 지났다.",
        ],
        MATCH_POINT: [
            "최종 포격 준비 완료.",
            "격침까지 카운트다운 개시.",
        ],
        IN_DANGER: [
            "네메시스는 침몰하지 않는다.",
            "아직 비장의 화력이 남았다.",
        ],
    },

    # ─── 스테이지 6: 홍련 (격렬한 중국 화염 전사) ───
    # 주의: 코드에서는 stage5 변수명이지만 실제 스테이지 6
    6: {
        BATTLE_START: [
            "홍련의 불꽃을 받아라!",
            "타오르는 불길 속으로!",
            "잿더미가 되어라!",
        ],
        SCORED: [
            "불꽃에 타라!",
            "재가 되거라!",
            "홍련의 불길은 멈추지 않아!",
        ],
        CONCEDED: [
            "이 정도론 꺼지지 않아!",
            "흥... 불씨는 남아있다!",
            "더 뜨겁게 타오를 뿐이야!",
        ],
        LOSING: [
            "불꽃은 꺼져도 다시 타오른다!",
            "지옥의 업화를 보여주마!",
        ],
        WINNING: [
            "모든 것을 태워버리겠다!",
            "불길에서 벗어날 수 없다!",
        ],
        MATCH_POINT: [
            "최후의 업화다!",
            "잿더미 속에서 끝이다!",
        ],
        IN_DANGER: [
            "홍련은 사그라지지 않아!",
            "마지막 불꽃을 피워주마!",
        ],
    },

    # ─── 스테이지 7: 테트리서 (체계적이고 게임에 빠진 게이머) ───
    7: {
        BATTLE_START: [
            "게임 시작. 레벨 1 로딩 완료.",
            "최종 방어 프로토콜 가동.",
            "블록 배치 최적화 중...",
        ],
        SCORED: [
            "퍼즐 완성.",
            "라인 클리어!",
            "계산대로야.",
        ],
        CONCEDED: [
            "...다시 계산한다.",
            "미스블록. 재배치.",
            "오차 수정 중...",
        ],
        LOSING: [
            "난이도 상향 조정.",
            "새로운 알고리즘 적용 중...",
        ],
        WINNING: [
            "게임 오버가 다가온다.",
            "완벽한 블록 배치.",
        ],
        MATCH_POINT: [
            "마지막 블록이다.",
            "테트리스 완성까지 1줄.",
        ],
        IN_DANGER: [
            "긴급 프로토콜 발동.",
            "...아직 T스핀이 남았다.",
        ],
    },

    # ─── 스테이지 8: 아카무 리고 (신비로운 그림자 닌자) ───
    8: {
        BATTLE_START: [
            "...그림자가 심판한다.",
            "숨어봤자 소용없다.",
            "닌법의 깊이를 보여주마.",
        ],
        SCORED: [
            "그림자는 피할 수 없다.",
            "...보이지 않는 일격.",
            "임무 진행 중.",
        ],
        CONCEDED: [
            "...흥미롭군.",
            "실수는 반복하지 않는다.",
            "다음엔 그림자조차 남기지 않겠다.",
        ],
        LOSING: [
            "...진정한 닌법을 보여주지.",
            "아직 숨겨둔 술법이 있다.",
        ],
        WINNING: [
            "이미 승부는 보였다.",
            "그림자에서 벗어날 수 없다.",
        ],
        MATCH_POINT: [
            "마지막 인술이다.",
            "...끝이다.",
        ],
        IN_DANGER: [
            "닌자는 최후까지 싸운다.",
            "아직 각성이 남아있다.",
        ],
    },
}


# ── 보스 변형별 대사 (한 스테이지에 여러 보스가 있을 때) ──
# 키: (스테이지, 보스이름) → 대사 딕셔너리
BOSS_VARIANT_DIALOGUES = {
    # ─── 스테이지 1: 포도대장 (위엄있는 조선 포도청 대장, 사극 말투) ───
    (1, "포도대장"): {
        BATTLE_START: [
            "이 몸은 포도청 대장이니라! 덤벼보거라!",
            "어명을 받들어 너를 잡으러 왔느니라!",
            "썩 물렀거라... 하면 물러날 것이냐!",
            "포도청의 위엄을 보여주마!",
        ],
        SCORED: [
            "호령 한 번에 꼼짝 못 하는구나!",
            "하하! 이것이 포도청의 실력이니라!",
            "네 이놈! 어디로 도망치려느냐!",
            "관아의 법도를 어기면 이렇게 되느니라!",
        ],
        CONCEDED: [
            "이런... 잠시 방심하였구나.",
            "흥! 요행이로다!",
            "제법이로구나... 허나 다음은 없느니라!",
            "건방진 것! 이 몸을 놀리느냐!",
        ],
        LOSING: [
            "이 몸이 밀리다니... 있을 수 없는 일이니라!",
            "포도대장이 지다니! 체면이 말이 아니구나!",
        ],
        WINNING: [
            "이대로 포박하여 옥에 가두리라!",
            "더 이상 발버둥 쳐봤자 소용없느니라!",
        ],
        MATCH_POINT: [
            "최후의 포승줄이다! 각오하거라!",
            "곧 옥에 가두리니 순순히 잡히거라!",
        ],
        IN_DANGER: [
            "포도대장은 끝까지 물러서지 않느니라!",
            "이 몸의 체면이 걸려있느니라!",
        ],
    },
    # ─── 스테이지 1: 각시탈 (익살맞은 하회탈 광대, 장난꾸러기 말투) ───
    (1, "각시탈"): {
        BATTLE_START: [
            "히히히! 자, 놀아보자꾸나~!",
            "이 탈 뒤에 뭐가 숨었게? 맞춰봐~!",
            "광대가 왔으니 축제 시작이다아~!",
        ],
        SCORED: [
            "아이고~ 속았지? 히히히!",
            "탈 뒤에서 웃고 있었다구~!",
            "어이쿠, 또 당했네 또 당했어~!",
        ],
        CONCEDED: [
            "에잇, 재주를 안 넘었어야 했나!",
            "이런! 탈이 삐뚤어졌잖아~!",
            "크흐흐, 한 판 더 놀아볼까~?",
        ],
        LOSING: [
            "히히, 지는 것도 재미있다구~!",
            "에잉~ 탈을 바꿔 써야겠군!",
        ],
        WINNING: [
            "히히히! 광대는 항상 이기는 법~!",
            "바람 좀 쐬고 가렴~ 부채바람~!",
        ],
        MATCH_POINT: [
            "마지막 탈바꿈이다! 잘 봐~!",
            "히히히! 이 판이 마지막 놀이다~!",
        ],
        IN_DANGER: [
            "에엣?! 광대가 질 수는 없지!",
            "탈이 깨지기 전에 역전이다~!",
        ],
    },
    # ─── 스테이지 2: 두더지왕 (땅속 왕국의 투박하지만 위엄있는 왕) ───
    (2, "두더지왕"): {
        BATTLE_START: [
            "땅속 왕국의 왕이 직접 나섰다!",
            "이 발톱으로 갈기갈기 찢어주마!",
            "지상의 녀석이 감히... 파헤쳐주지!",
            "두더지왕의 발톱은 무엇이든 가른다!",
        ],
        SCORED: [
            "크하하! 이것이 땅속 왕의 실력이다!",
            "발톱에 찍혀봐라! 어떠냐!",
            "지상에서 온 녀석치곤 약하구나!",
        ],
        CONCEDED: [
            "크윽... 제법 날카롭군!",
            "땅속 왕이 이런 일에 당하다니!",
            "한 번은 봐주마... 다음은 없다!",
        ],
        LOSING: [
            "두더지왕이 밀리다니... 있을 수 없다!",
            "이 발톱이... 통하지 않는단 말인가!",
        ],
        WINNING: [
            "크하하! 지상 녀석은 역시 별것 아니구나!",
            "땅속 왕국으로 끌고 가주마!",
        ],
        MATCH_POINT: [
            "최후의 일격! 발톱 전력으로 간다!",
            "이 한 방으로 묻어버리겠다!",
        ],
        IN_DANGER: [
            "두더지왕은 궁지에서 더 강해진다!",
            "아직 끝나지 않았다! 파고들어간다!",
        ],
    },
}


class BossDialogueManager:
    """스테이지 보스 상황 대사 관리자

    - 스킬 외침풍선(speech_timer)과 별도 채널로 동작
    - 쿨다운으로 빈도 조절, 스킬 외침 우선
    """

    COOLDOWN = 900            # 쿨다운 (15초 @ 60fps)
    TRIGGER_CHANCE = 0.5      # 50% 발동 확률

    def __init__(self):
        self._cooldown = 0         # 남은 쿨다운 프레임
        self._prev_player = 0      # 이전 플레이어 점수
        self._prev_boss = 0        # 이전 보스 점수
        self._started = False       # 개막 대사 출력 여부
        self._start_delay = 0       # 개막 대사 딜레이
        self._current_stage = 0     # 현재 스테이지

    def reset(self, stage=0):
        """새 스테이지/라운드 시작 시 초기화"""
        self._cooldown = 0
        self._prev_player = 0
        self._prev_boss = 0
        self._started = False
        self._start_delay = 150     # 2.5초 뒤 개막 대사
        self._current_stage = stage

    def update(self, stage, player_score, boss_score, win_goal,
               speech_timer, show_dialogue_func, boss_name=None):
        """매 프레임 호출

        Args:
            stage: 현재 스테이지 (1~8)
            player_score: 플레이어 점수 (round_wins)
            boss_score: 보스 점수 (round_losses)
            win_goal: 승리 목표 점수
            speech_timer: 스킬 외침 남은 프레임 (> 0이면 대사 건너뜀)
            show_dialogue_func: show_boss_dialogue 함수
            boss_name: 보스 변형 이름 (None이면 기본 보스)
        """
        self._current_stage = stage
        self._boss_name = boss_name
        self._cooldown = max(0, self._cooldown - 1)

        # 개막 대사 처리
        if not self._started:
            self._start_delay -= 1
            if self._start_delay <= 0:
                self._started = True
                self._try_say(stage, BATTLE_START, speech_timer,
                              show_dialogue_func, force=True)
            return

        # 점수 변화 감지
        if boss_score != self._prev_boss:
            # 보스 득점
            self._on_boss_scored(stage, player_score, boss_score,
                                 win_goal, speech_timer, show_dialogue_func)

        if player_score != self._prev_player:
            # 플레이어 득점 (보스 실점)
            self._on_player_scored(stage, player_score, boss_score,
                                   win_goal, speech_timer, show_dialogue_func)

        self._prev_player = player_score
        self._prev_boss = boss_score

    def _on_boss_scored(self, stage, p_score, b_score, win_goal,
                        speech_timer, fn):
        """보스 득점 시 상황 판별"""
        if b_score >= win_goal - 1 and b_score > p_score:
            sit = MATCH_POINT
        elif b_score - p_score >= 2:
            sit = WINNING
        else:
            sit = SCORED
        self._try_say(stage, sit, speech_timer, fn)

    def _on_player_scored(self, stage, p_score, b_score, win_goal,
                          speech_timer, fn):
        """플레이어 득점 시 (보스 실점) 상황 판별"""
        if p_score >= win_goal - 1 and p_score > b_score:
            sit = IN_DANGER
        elif p_score - b_score >= 2:
            sit = LOSING
        else:
            sit = CONCEDED
        self._try_say(stage, sit, speech_timer, fn)

    def _try_say(self, stage, situation, speech_timer, fn, force=False):
        """대사 출력 시도"""
        # 스킬 외침이 활성 중이면 건너뜀
        if speech_timer > 0:
            return False

        if not force:
            if self._cooldown > 0:
                return False
            if random.random() > self.TRIGGER_CHANCE:
                self._cooldown = self.COOLDOWN // 4
                return False

        # 보스 변형 대사 우선 탐색
        boss_name = getattr(self, '_boss_name', None)
        lines = None
        if boss_name:
            variant_data = BOSS_VARIANT_DIALOGUES.get((stage, boss_name), {})
            lines = variant_data.get(situation, [])

        # 변형 대사 없으면 기본 대사
        if not lines:
            lines = BOSS_DIALOGUES.get(stage, {}).get(situation, [])
        if not lines:
            return False

        idx = random.randint(0, len(lines) - 1)
        # 번역 키 구성
        boss_name = getattr(self, '_boss_name', None)
        if boss_name and (stage, boss_name) in BOSS_VARIANT_DIALOGUES:
            vdata = BOSS_VARIANT_DIALOGUES.get((stage, boss_name), {})
            if situation in vdata and lines == vdata[situation]:
                vkey = _VARIANT_KEY_MAP.get(boss_name, boss_name)
                tkey = f"bdlg.{stage}.v_{vkey}.{situation}.{idx}"
            else:
                tkey = f"bdlg.{stage}.{situation}.{idx}"
        else:
            tkey = f"bdlg.{stage}.{situation}.{idx}"
        text = _t(tkey, lines[idx])
        fn(text, duration=90)

        self._cooldown = self.COOLDOWN
        return True


# ── 싱글톤 ──
_boss_dialogue_manager = None


def get_boss_dialogue_manager():
    global _boss_dialogue_manager
    if _boss_dialogue_manager is None:
        _boss_dialogue_manager = BossDialogueManager()
    return _boss_dialogue_manager
