"""
academy.py  — 호환용 최소 스텁 (Minimal Compatibility Stub)

아카데미 스킬 트리 시스템은 런타임 퍽 시스템으로 완전 대체되었다.
이 파일은 기존 호출부가 깨지지 않도록 동일한 public API를 유지하되,
모든 보너스를 0/1.0(중립값)으로 반환한다.

남아있는 역할:
  - ANGEL_ITEM_COOLDOWN_MULTIPLIER (천사 가호 전역 배율)
  - transcendent_crown_skill_bonus (전설 아이템 연동)
  - get_*() → 중립값 반환
"""

# ── 전설 아이템 연동 전역 변수 ────────────────────────────────────
transcendent_crown_skill_bonus = 0
ANGEL_ITEM_COOLDOWN_MULTIPLIER = 1.0

# ── 더미 skill_system ─────────────────────────────────────────────

class _DummySkillSystem:
    skill_points = 0
    skill_levels = {}
    total_invested_points = 0
    total_invested_points_by_tree = {}

    def get_skill_level(self, skill_id): return 0
    def get_skill_data(self, skill_id): return None
    def can_upgrade_skill(self, skill_id): return False
    def upgrade_skill(self, skill_id): return False
    def add_skill_points(self, pts): pass
    def reset_skill_points(self): pass
    def reset_all(self): pass
    def init_fresh_skills(self): pass
    def get_tree_total(self, tree_id): return 0
    def get_tree_id_for_skill(self, sid): return None
    def register_manual_investment(self, t, a): pass
    def to_save_dict(self): return {}
    def load_from_dict(self, d): return False

skill_system = _DummySkillSystem()

# 호환: academy.skill_points 접근
def __getattr__(name):
    if name == "skill_points":
        return skill_system.skill_points
    if name == "dash_quick_recovery_level":
        return 0
    raise AttributeError(f"module 'academy' has no attribute {name!r}")

# ── 발토르 대장장이 메뉴 호환 ─────────────────────────────────────
SKILL_TREES = {
    "blacksmith": {"name": "대장장이 스킬", "color": (180, 100, 220), "skills": []},
}
TREE_SUMMARIES = {"blacksmith": "발토르 전용 스킬입니다. (퇴역됨)"}

# ── get_*() 중립값 헬퍼 ───────────────────────────────────────────
def get_skill_bonus(skill_id): return 0
def get_skill_level(skill_id): return 0
def get_item_spawn_delay_multiplier(): return 1.0
def get_active_item_cooldown_multiplier(): return 1.0 * ANGEL_ITEM_COOLDOWN_MULTIPLIER
def get_active_item_gauge_bonus(): return 0
def get_item_slot_bonus(): return 0
def get_item_recycle_chance(): return 0.0
def get_caffeine_duration_multiplier(): return 1.0
def get_polish_efficiency_multiplier(): return 1.0
def get_treasure_map_field_multiplier(): return 1.0
def get_treasure_map_gacha_bonus(): return 0.0
def get_downtown_treasure_map_field_multiplier(): return 1.0
def get_downtown_treasure_map_gacha_bonus(): return 0.0
def get_downtown_gamble_settings(): return get_item_gamble_settings()
def check_all_dash_skills_mastered(): return False

def get_item_gamble_settings():
    runtime_bonus = 0.0
    try:
        from pingfighter import get_runtime_skill_bonus
        runtime_bonus = get_runtime_skill_bonus("downtown_gamble")
    except Exception:
        pass
    if runtime_bonus <= 0:
        return 0.0, 0
    return min(0.95, runtime_bonus), 1

# ── 포인트/스킬 관리 (no-op) ──────────────────────────────────────
def add_skill_points(pts): pass
def reset_skill_points(): pass
def reset_all_skills(): pass
def debug_max_dash_skills(): pass

# ── UI (no-op) ────────────────────────────────────────────────────
def show_academy_menu(screen, width, height, selected_character="smasher", read_only=False):
    return None
