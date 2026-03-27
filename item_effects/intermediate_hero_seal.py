"""~의 중급인장 (Intermediate Hero Seal) - 액티브 아이템

사용 시 해당 영웅이 임시 호위무사로 소환되어 한 스테이지 동안 도와준 뒤 떠남.
투기장 4강 승리 보상으로 획득 가능.
정식 인장(hero_seal)의 중간 등급 버전.
"""
import random

try:
    import pygame
except ImportError:
    pygame = None


# ============================================================================
# 상수
# ============================================================================
# 중급인장으로 소환 가능한 영웅 목록 (초급인장과 동일 풀)
INTERMEDIATE_SEAL_HEROES = {
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

# 중급인장 전용 등장 대사
INTERMEDIATE_SEAL_ENTRANCE_LINES = {
    "hero_lines": [
        "중급인장이군... 이번 전투는 함께하지.",
        "한 스테이지 동안은 내가 지켜주마.",
        "인장의 힘이 제법이군. 끝까지 함께하겠다.",
        "이 스테이지가 끝날 때까지... 맡겨라.",
    ],
    "guard_lines": [
        "이번 스테이지, 함께 싸우겠습니다.",
        "중급인장의 계약... 끝까지 지키겠습니다.",
        "스테이지가 끝나면 떠나야 하지만, 최선을 다합니다.",
        "호위 임무, 시작합니다.",
    ],
}


# ============================================================================
# 중급인장 상태 관리
# ============================================================================
class IntermediateHeroSealState:
    """중급인장 임시 호위무사 상태 (1스테이지 지속)"""

    def __init__(self):
        self.active = False
        self.hero_id = None
        self.hero_name = None
        self._stage_snapshot = None     # 발동 시점의 스테이지 번호
        self._bodyguard_ref = None      # InGameBodyguard 인스턴스 참조

    def activate(self, hero_id: str, current_stage: int):
        """중급인장 발동 - 임시 호위무사 소환 (1스테이지)"""
        self.active = True
        self.hero_id = hero_id
        hero_info = INTERMEDIATE_SEAL_HEROES.get(hero_id, {})
        self.hero_name = hero_info.get("name", hero_id)
        self._stage_snapshot = current_stage
        print(f"[IntermediateSeal] {self.hero_name}의 중급인장 발동! "
              f"스테이지 {current_stage} 동안 호위")

    def check_stage_change(self, current_stage: int) -> bool:
        """스테이지 변경 체크. 호위무사가 떠나야 하면 True 반환."""
        if not self.active:
            return False

        if current_stage != self._stage_snapshot:
            print(f"[IntermediateSeal] {self.hero_name}의 중급인장 만료! "
                  f"(스테이지 {self._stage_snapshot} → {current_stage})")
            self.deactivate()
            return True
        return False

    def deactivate(self):
        """중급인장 비활성화 - 호위무사 퇴장"""
        if self._bodyguard_ref and self._bodyguard_ref.active:
            self._bodyguard_ref.reset()
            self._bodyguard_ref._seal_setup_done = False
        self.active = False
        self.hero_id = None
        self.hero_name = None
        self._stage_snapshot = None
        self._bodyguard_ref = None

    def reset(self):
        """완전 리셋 (게임 오버/메인 복귀 시)"""
        self.deactivate()


# ============================================================================
# 싱글턴
# ============================================================================
_intermediate_seal_state = None


def get_intermediate_seal_state() -> IntermediateHeroSealState:
    global _intermediate_seal_state
    if _intermediate_seal_state is None:
        _intermediate_seal_state = IntermediateHeroSealState()
    return _intermediate_seal_state


def pick_random_hero(unlocked_heroes: list = None) -> str:
    """해금된 영웅 중 랜덤 선택. unlocked_heroes가 없으면 기본 풀에서 선택."""
    pool = list(INTERMEDIATE_SEAL_HEROES.keys())
    if unlocked_heroes:
        pool = [h for h in unlocked_heroes if h in INTERMEDIATE_SEAL_HEROES]
    if not pool:
        pool = list(INTERMEDIATE_SEAL_HEROES.keys())
    return random.choice(pool)


def get_hero_display_name(hero_id: str) -> str:
    """영웅 한국어 이름 반환"""
    info = INTERMEDIATE_SEAL_HEROES.get(hero_id, {})
    return info.get("name", hero_id)
