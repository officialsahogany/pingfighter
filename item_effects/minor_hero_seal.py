"""~의 초급인장 (Minor Hero Seal) - 액티브 아이템

사용 시 해당 영웅이 임시 호위무사로 소환되어 3라운드 동안 도와준 뒤 떠남.
투기장 8강 승리 보상으로 획득 가능.
정식 인장(hero_seal)의 임시 버전.
"""
import random

try:
    import pygame
except ImportError:
    pygame = None


# ============================================================================
# 상수
# ============================================================================
# 초급인장으로 소환 가능한 영웅 목록 (HERO_DISPLAY_INFO 기반)
MINOR_SEAL_HEROES = {
    "mugen":    {"name": "무겐",     "skill": "달빛베기",     "color": (120, 60, 180)},
    "kraken":   {"name": "크라켄",   "skill": "촉수휘감기",   "color": (40, 120, 140)},
    "chronos":  {"name": "크로노스", "skill": "중력제어",     "color": (200, 170, 100)},
    "onimaru":  {"name": "오니마루", "skill": "지옥의 불꽃",  "color": (200, 50, 70)},
    "maria":    {"name": "연화",     "skill": "인형조종",     "color": (180, 100, 150)},
    "ignis":    {"name": "이그니스", "skill": "드래곤 브레스", "color": (220, 100, 40)},
    "gear":     {"name": "기어",     "skill": "스팀배리어",   "color": (140, 100, 60)},
    "kurokage": {"name": "쿠로카게", "skill": "그림자분신",   "color": (50, 50, 70)},
    "banshee":  {"name": "밴시",     "skill": "혼령소환",     "color": (160, 200, 255)},
    "necro":    {"name": "네크로",   "skill": "해골소환",     "color": (180, 180, 160)},
    "monkeyking": {"name": "오공",   "skill": "여의봉",       "color": (255, 180, 50)},
    "ra":       {"name": "라",       "skill": "태양의 심판",  "color": (255, 200, 80)},
    "mirage":   {"name": "미라쥬",   "skill": "환영분신",     "color": (100, 200, 200)},
    "joker":    {"name": "조커",     "skill": "와일드카드",   "color": (200, 50, 200)},
    "android":  {"name": "안드로이드", "skill": "개틀링버스트", "color": (100, 180, 220)},
}

# 초급인장 전용 등장 대사
MINOR_SEAL_ENTRANCE_LINES = {
    "hero_lines": [
        "잠깐 얼굴만 비추지...",
        "초급인장의 소환... 오래 못 있어.",
        "임시 계약이다. 금방 돌아가야 해.",
        "인장의 힘이 약하군... 최대한 도와주지.",
    ],
    "guard_lines": [
        "...잠시만 함께하겠습니다.",
        "오래 못 있겠지만, 최선을 다하지.",
        "인장이 다하면 떠나야 합니다.",
        "임시 호위, 시작합니다.",
    ],
}


# ============================================================================
# 초급인장 상태 관리
# ============================================================================
MINOR_SEAL_ROUNDS = 3  # 초급인장 지속 라운드 수 (고정)


class MinorHeroSealState:
    """초급인장 임시 호위무사 상태"""

    def __init__(self):
        self.active = False
        self.hero_id = None
        self.hero_name = None
        self.rounds_remaining = 0       # 남은 라운드 수
        self._round_snapshot = None     # 발동 시점의 (round_wins + round_losses) 스냅샷
        self._bodyguard_ref = None      # InGameBodyguard 인스턴스 참조

    def activate(self, hero_id: str, round_wins: int, round_losses: int):
        """초급인장 발동 - 임시 호위무사 소환 (3라운드)"""
        self.active = True
        self.hero_id = hero_id
        hero_info = MINOR_SEAL_HEROES.get(hero_id, {})
        self.hero_name = hero_info.get("name", hero_id)
        self.rounds_remaining = MINOR_SEAL_ROUNDS
        self._round_snapshot = round_wins + round_losses
        print(f"[MinorSeal] {self.hero_name}의 초급인장 발동! "
              f"{self.rounds_remaining}라운드 동안 호위")

    def check_round_change(self, round_wins: int, round_losses: int) -> bool:
        """라운드 변경 체크. 호위무사가 떠나야 하면 True 반환."""
        if not self.active:
            return False

        current_total = round_wins + round_losses
        rounds_passed = current_total - self._round_snapshot

        if rounds_passed > self.rounds_remaining:
            print(f"[MinorSeal] {self.hero_name}의 초급인장 만료! "
                  f"({rounds_passed}라운드 경과)")
            self.deactivate()
            return True
        return False

    def deactivate(self):
        """초급인장 비활성화 - 호위무사 퇴장"""
        if self._bodyguard_ref and self._bodyguard_ref.active:
            self._bodyguard_ref.reset()
            self._bodyguard_ref._seal_setup_done = False
        self.active = False
        self.hero_id = None
        self.hero_name = None
        self.rounds_remaining = 0
        self._round_snapshot = None
        self._bodyguard_ref = None

    def reset(self):
        """완전 리셋 (게임 오버/메인 복귀 시)"""
        self.deactivate()


# ============================================================================
# 싱글턴
# ============================================================================
_minor_seal_state = None


def get_minor_seal_state() -> MinorHeroSealState:
    global _minor_seal_state
    if _minor_seal_state is None:
        _minor_seal_state = MinorHeroSealState()
    return _minor_seal_state


def pick_random_hero(unlocked_heroes: list = None) -> str:
    """해금된 영웅 중 랜덤 선택. unlocked_heroes가 없으면 기본 풀에서 선택."""
    pool = list(MINOR_SEAL_HEROES.keys())
    if unlocked_heroes:
        pool = [h for h in unlocked_heroes if h in MINOR_SEAL_HEROES]
    if not pool:
        pool = list(MINOR_SEAL_HEROES.keys())
    return random.choice(pool)


def get_hero_display_name(hero_id: str) -> str:
    """영웅 한국어 이름 반환"""
    info = MINOR_SEAL_HEROES.get(hero_id, {})
    return info.get("name", hero_id)
