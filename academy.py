"""
academy.py  — 호환용 셸 (Compatibility Shell)

아카데미 스킬 트리 시스템은 런타임 퍽 시스템으로 대체되었다.
이 파일은 기존 호출부(pingfighter, items, game_logic, downtown, ai 등)가
깨지지 않도록 동일한 public API를 유지하되, 모든 보너스를 0/1.0(중립값)으로 반환한다.

남아있는 역할:
  - skill_system 더미 객체 (세이브/로드 호환, skill_points 저장소)
  - get_*() 헬퍼 → 중립값 반환
  - show_academy_menu() → no-op
  - transcendent_crown_skill_bonus (전설 아이템 연동 유지)
  - ANGEL_ITEM_COOLDOWN_MULTIPLIER (천사 가호 전역 배율 유지)
"""

import os
import sys

ACADEMY_DEBUG = os.getenv("ACADEMY_DEBUG") == "1"

# 초월자의 관 스킬 보너스 (전설 아이템 효과)
# 이 값은 legendary_items.py의 TranscendentCrown.activate()에서 설정됨
transcendent_crown_skill_bonus = 0

# PyInstaller 실행 파일에서 리소스 경로를 찾기 위한 함수
def resource_path(relative_path):
    """PyInstaller로 패키징된 실행 파일에서 리소스 경로를 찾는 함수"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


# ── SKILL_TREES 호환 스텁 ──────────────────────────────────────────
# pingfighter.py의 발토르 퍽 메뉴가 SKILL_TREES["blacksmith"]를 순회하므로
# 최소한의 구조만 남긴다. 나머지 트리는 빈 스킬 목록으로 처리.

SKILL_TREES = {
    "dash":       {"name": "대쉬 스킬",  "color": (100, 150, 255), "skills": []},
    "item":       {"name": "아이템 스킬", "color": (100, 200, 100), "skills": []},
    "paddle":     {"name": "패들 스킬",   "color": (200, 150, 50),  "skills": []},
    "downtown":   {"name": "광장 스킬",   "color": (180, 120, 200), "skills": []},
    "blacksmith": {
        "name": "대장장이 스킬",
        "color": (180, 100, 220),
        "skills": [
            {
                "id": "blacksmith_hammer_shock",
                "name": "해머쇼크",
                "description": "(퇴역) 아카데미 스킬 비활성",
                "max_level": 3,
                "cost": 1,
                "icon_color": (220, 150, 50),
                "requires": None,
                "row": 0, "col": 0,
            },
            {
                "id": "blacksmith_gauge_efficiency",
                "name": "게이지 효율",
                "description": "(퇴역) 아카데미 스킬 비활성",
                "max_level": 3,
                "cost": 1,
                "icon_color": (180, 100, 220),
                "requires": None,
                "row": 0, "col": 1,
            },
            {
                "id": "blacksmith_build_speed",
                "name": "건설 속도",
                "description": "(퇴역) 아카데미 스킬 비활성",
                "max_level": 3,
                "cost": 1,
                "icon_color": (180, 100, 220),
                "requires": None,
                "row": 0, "col": 2,
            },
        ],
    },
}

TREE_SUMMARIES = {
    "dash": "",
    "item": "",
    "paddle": "",
    "downtown": "",
    "blacksmith": "발토르 전용 스킬입니다. (퇴역됨)",
}

# 아카데미에서 마지막으로 본 탭을 기억 (호환용)
ACADEMY_LAST_SELECTED_TREE = "dash"


# ── SkillSystem 더미 ───────────────────────────────────────────────

class SkillSystem:
    """호환용 더미 — 스킬 보너스는 항상 0, skill_points만 저장소로 유지"""

    def __init__(self):
        self.skill_points = 0
        self.skill_levels = {}
        self.total_invested_points = 0
        self.total_invested_points_by_tree = {t: 0 for t in SKILL_TREES}
        self.skill_to_tree = {}

    # ── 세이브/로드 호환 ──
    def to_save_dict(self):
        return {
            "skill_points": self.skill_points,
            "skill_levels": {},
            "total_invested_points": 0,
            "total_invested_points_by_tree": {},
        }

    def load_from_dict(self, data):
        """구세이브 데이터를 읽되, skill_points만 복원하고 스킬 레벨은 버린다."""
        if not data:
            return False
        self.skill_points = data.get("skill_points", 0)
        # 스킬 레벨은 의도적으로 무시 — 아카데미 투자 보너스 제거
        return True

    # ── 포인트 관리 ──
    def add_skill_points(self, points):
        self.skill_points += points

    def reset_skill_points(self):
        self.skill_points = 0

    def reset_all(self):
        self.skill_points = 0
        self.skill_levels = {}
        self.total_invested_points = 0
        self.total_invested_points_by_tree = {t: 0 for t in SKILL_TREES}

    def init_fresh_skills(self):
        self.reset_all()

    # ── 스킬 조회 (항상 0) ──
    def get_skill_level(self, skill_id):
        return 0

    def get_skill_data(self, skill_id):
        for tree_data in SKILL_TREES.values():
            for skill in tree_data["skills"]:
                if skill["id"] == skill_id:
                    return skill
        return None

    # ── 업그레이드 (항상 불가) ──
    def can_upgrade_skill(self, skill_id):
        return False

    def upgrade_skill(self, skill_id):
        return False

    # ── 트리 추적 (no-op) ──
    def get_tree_total(self, tree_id):
        return 0

    def get_tree_id_for_skill(self, skill_id):
        return self.skill_to_tree.get(skill_id)

    def register_manual_investment(self, tree_id, amount):
        pass


# ── 전역 인스턴스 ──────────────────────────────────────────────────
skill_system = SkillSystem()

# pingfighter.py에서 academy.skill_points 로 접근하는 코드가 있으므로
# 모듈 __getattr__로 skill_system.skill_points에 위임한다.
def __getattr__(name):
    if name == "skill_points":
        return skill_system.skill_points
    raise AttributeError(f"module 'academy' has no attribute {name!r}")


# ── get_*() 중립값 헬퍼 ───────────────────────────────────────────

def get_skill_bonus(skill_id):
    """항상 0 반환 — 아카데미 투자 보너스 없음"""
    return 0


def get_skill_level(skill_id):
    """항상 0 — 초월자의 관 보너스도 기저 레벨이 0이라 적용 안 됨"""
    return 0


def compute_item_spawn_delay_multiplier(level):
    """순수 계산 함수 (호환용 유지)"""
    base = max(0.05, 1.0 - 0.06 * level)
    if level >= 5:
        base = max(0.05, base - 0.06)
    return base


def compute_item_cooldown_multiplier(level: int) -> float:
    base = max(0.1, 1.0 - 0.08 * level)
    if level >= 5:
        base = max(0.1, base - 0.08)
    return base


def compute_item_gauge_bonus(level: int) -> int:
    bonus = level * 7
    if level >= 5:
        bonus += 7
    return bonus


# 전설/버프용 전역 배율 (천사의 가호 등)
ANGEL_ITEM_COOLDOWN_MULTIPLIER = 1.0


def get_item_spawn_delay_multiplier():
    """아카데미 레벨 0 → 배율 1.0 (변화 없음)"""
    return 1.0


def get_active_item_cooldown_multiplier():
    """아카데미 레벨 0 → 배율 1.0 × ANGEL_ITEM_COOLDOWN_MULTIPLIER"""
    return 1.0 * ANGEL_ITEM_COOLDOWN_MULTIPLIER


def get_active_item_gauge_bonus():
    return 0


def get_item_slot_bonus():
    return 0


def get_item_recycle_chance():
    return 0.0


def get_item_gamble_settings():
    """아카데미 보너스 0 + 런타임 스킬 보너스만 반환"""
    runtime_bonus = 0.0
    try:
        from pingfighter import get_runtime_skill_bonus
        runtime_bonus = get_runtime_skill_bonus("downtown_gamble")
    except Exception:
        pass
    if runtime_bonus <= 0:
        return 0.0, 0
    return min(0.95, runtime_bonus), 1


def get_downtown_gamble_settings():
    return get_item_gamble_settings()


def get_treasure_map_field_multiplier():
    """아카데미 레벨 0 → 배율 1.0 (기본)"""
    return 1.0


def get_treasure_map_gacha_bonus():
    return 0.0


def get_downtown_treasure_map_field_multiplier():
    return get_treasure_map_field_multiplier()


def get_downtown_treasure_map_gacha_bonus():
    return get_treasure_map_gacha_bonus()


def get_caffeine_duration_multiplier():
    return 1.0


def get_polish_efficiency_multiplier():
    return 1.0


# ── 포인트 관리 래퍼 ──────────────────────────────────────────────

def add_skill_points(points):
    skill_system.add_skill_points(points)


def reset_skill_points():
    skill_system.reset_skill_points()


def reset_all_skills():
    skill_system.reset_all()


def check_all_dash_skills_mastered():
    return False


def debug_max_dash_skills():
    pass


# ── UI 진입점 (no-op) ─────────────────────────────────────────────

def show_academy_menu(screen, width, height, selected_character="smasher", read_only: bool = False):
    """아카데미 UI가 퇴역했으므로 아무 동작 없이 복귀"""
    return None
