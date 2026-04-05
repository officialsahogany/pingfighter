"""
발할라의 전갑 (Valhalla's Warplate) - 전설 아이템 효과 모듈

상의(갑옷) 부위 전설 아이템.
플레이어가 공을 타격 시 일정 확률(롤옵션 8~15%)로 투기장 영웅을 호위무사로 소환.
소환된 영웅은 보유 스킬 2개 중 1개를 랜덤 발동 후 퇴장 모션으로 사라짐.

실제 InGameBodyguard 시스템을 활용하여 인장과 동일한 스킬 발동.
"""

import random

# ── 영웅 목록 (투기장 15영웅) ──────────────────────────────────
VALHALLA_HEROES = [
    {"id": "mugen",      "name": "무겐",     "color": (120, 60, 180)},
    {"id": "kraken",     "name": "크라켄",    "color": (40, 120, 140)},
    {"id": "chronos",    "name": "크로노스",  "color": (200, 170, 100)},
    {"id": "onimaru",    "name": "오니마루",  "color": (200, 50, 70)},
    {"id": "maria",      "name": "연화",      "color": (180, 100, 150)},
    {"id": "ignis",      "name": "이그니스",  "color": (220, 100, 40)},
    {"id": "gear",       "name": "기어",      "color": (140, 100, 60)},
    {"id": "kurokage",   "name": "쿠로카게",  "color": (50, 50, 70)},
    {"id": "banshee",    "name": "밴시",      "color": (100, 200, 180)},
    {"id": "necro",      "name": "네크로",    "color": (80, 60, 100)},
    {"id": "joker",      "name": "조커",      "color": (220, 180, 50)},
    {"id": "mirage",     "name": "미라쥬",    "color": (200, 170, 120)},
    {"id": "android",    "name": "안드로이드", "color": (100, 150, 200)},
    {"id": "ra",         "name": "라",        "color": (255, 200, 50)},
    {"id": "monkeyking", "name": "오공",      "color": (200, 120, 50)},
]

# ── 상태 관리 ──────────────────────────────────────────────────

class ValhallaWarplateState:
    """발할라의 전갑 인게임 상태"""

    # 상태 머신
    IDLE = 0           # 대기 중
    SUMMONED = 1       # 소환됨, 스킬 발동 대기
    SKILL_ACTIVE = 2   # 스킬 발동 중
    EXITING = 3        # 퇴장 모션 재생 중

    def __init__(self):
        self.active = False           # 장착 중인지
        self.summon_chance = 0.10     # 소환 확률 (롤옵션에서 갱신)
        self.enhancement_bonus_pct = 0

        # 소환 관리
        self.state = self.IDLE
        self.summoning = False        # 현재 소환 중 (하위호환)
        self.summon_timer = 0.0       # 소환 후 경과 시간
        self.post_skill_timer = 0.0   # 스킬 발동 후 경과 시간
        self.post_skill_linger = 1.0  # 스킬 완료 후 퇴장 시작까지 대기 (초)
        self.max_summon_time = 10.0   # 스킬 미발동 시 최대 대기 시간 (초)
        self._bodyguard_ref = None    # 사용 중인 InGameBodyguard 참조
        self.summoned_hero_name = ""  # 소환된 영웅 이름 (로그용)

    def activate(self, summon_chance: float):
        """장착 시 활성화"""
        self.active = True
        self.summon_chance = summon_chance

    def deactivate(self):
        """해제"""
        self.active = False
        self._force_dismiss()

    def reset(self):
        """게임 종료 시 완전 초기화"""
        self.active = False
        self._force_dismiss()
        self.enhancement_bonus_pct = 0

    def _force_dismiss(self):
        """즉시 강제 해산 (reset 용)"""
        if self._bodyguard_ref and self._bodyguard_ref.active:
            self._bodyguard_ref.reset()
        self._clear_state()

    def _start_exit(self):
        """퇴장 모션 시작 (exiting phase 트리거)"""
        if self._bodyguard_ref and self._bodyguard_ref.active and self._bodyguard_ref._guard_system:
            gs = self._bodyguard_ref._guard_system
            # exiting phase 설정 (걸어서 나가는 모션)
            gs._exit_start_x_bottom = gs.x_bottom
            gs._exit_start_y_bottom = float(gs.y_bottom)
            gs.phase_bottom = "exiting"
            gs.anim_timer_bottom = 0.0
            self.state = self.EXITING
            self.summoning = True  # exiting 중에도 summoning 유지
            print(f"⚔ 발할라의 전갑: {self.summoned_hero_name} 퇴장 모션 시작!")
        else:
            # guard_system 없으면 바로 해산
            self._force_dismiss()

    def _clear_state(self):
        """내부 상태 초기화"""
        self._bodyguard_ref = None
        self.summoning = False
        self.state = self.IDLE
        self.summon_timer = 0.0
        self.post_skill_timer = 0.0
        self.summoned_hero_name = ""

    def try_summon(self) -> bool:
        """공 타격 시 소환 시도. 성공하면 True 반환."""
        if not self.active or self.state != self.IDLE:
            return False

        # 실제 소환 확률 계산 (연마 + 강화 보너스 적용)
        effective_chance = self.summon_chance
        try:
            from legendary_items import get_legendary_roll_value
            effective_chance = get_legendary_roll_value(
                "valhalla_warplate", "summon_chance",
                apply_polish=True,
                enhancement_bonus_pct=self.enhancement_bonus_pct
            ) / 100.0
        except Exception:
            pass

        if random.random() > effective_chance:
            return False

        # 소환 성공! 실제 InGameBodyguard 시스템 사용
        hero = random.choice(VALHALLA_HEROES)
        skill_idx = random.randint(0, 1)

        try:
            from game_mechanics.ingame_bodyguard import get_bodyguard, get_bodyguard2

            _bg = get_bodyguard()
            _bg2 = get_bodyguard2()

            # 빈 호위무사 슬롯 찾기
            target_bg = None
            if not _bg.active:
                target_bg = _bg
            elif not _bg2.active:
                target_bg = _bg2
            else:
                return False

            # 인장과 동일한 방식으로 호위무사 setup
            hero_data = {
                "id": hero["id"],
                "name": hero["name"],
                "color": tuple(hero["color"]),
                "title": ""
            }
            skill_sel = {hero["id"]: skill_idx}
            target_bg.setup(hero_data, skill_selections=skill_sel, first_spawn=True)

            # 쿨다운을 거의 0으로 설정 → 즉시 스킬 발동
            if target_bg._guard_system:
                target_bg._guard_system.cooldown_bottom = 0.1

            self._bodyguard_ref = target_bg
            self.state = self.SUMMONED
            self.summoning = True
            self.summon_timer = 0.0
            self.post_skill_timer = 0.0
            self.summoned_hero_name = hero["name"]

            print(f"⚔ 발할라의 전갑: {hero['name']} 소환! (스킬 {skill_idx + 1}번 발동 예정)")
            return True

        except Exception as e:
            print(f"[WARN] 발할라 전갑 소환 실패: {e}")
            return False

    def update(self, dt: float):
        """매 프레임 업데이트 - 상태 머신 기반 관리"""
        if self.state == self.IDLE:
            return

        self.summon_timer += dt
        bg = self._bodyguard_ref
        gs = bg._guard_system if bg and bg.active else None

        # ── SUMMONED: 스킬 발동 대기 ──
        if self.state == self.SUMMONED:
            if gs:
                phase = getattr(gs, 'phase_bottom', 'patrolling')
                # patrolling/patrol_entering 이외 = 스킬 발동 시작
                if phase not in ('patrolling', 'patrol_entering', None):
                    self.state = self.SKILL_ACTIVE
                    print(f"⚔ 발할라의 전갑: {self.summoned_hero_name} 스킬 발동!")

            # 안전장치: 너무 오래 대기하면 퇴장
            if self.summon_timer >= self.max_summon_time:
                self._start_exit()

        # ── SKILL_ACTIVE: 스킬 완료 대기 → 퇴장 모션 시작 ──
        elif self.state == self.SKILL_ACTIVE:
            if gs:
                phase = getattr(gs, 'phase_bottom', 'patrolling')
                # 스킬 완료 = patrolling으로 복귀
                if phase in ('patrolling', 'patrol_entering', None):
                    self.post_skill_timer += dt
                    if self.post_skill_timer >= self.post_skill_linger:
                        self._start_exit()
            else:
                # guard_system 사라짐 → 정리
                self._clear_state()

        # ── EXITING: 퇴장 모션 완료 대기 ──
        elif self.state == self.EXITING:
            if gs:
                phase = getattr(gs, 'phase_bottom', None)
                # exiting 완료 → phase가 None이나 다른 값으로 전환
                if phase != "exiting":
                    # 퇴장 완료 → 스킬 이펙트 유지한 채 캐릭터만 해산
                    if bg and bg.active:
                        bg.dismiss_keep_skills()
                    self._clear_state()
                    return
            else:
                # guard_system 없으면 정리
                self._clear_state()
                return

            # 안전장치: exiting이 너무 오래 걸리면 강제 해산
            if self.summon_timer >= self.max_summon_time + 2.0:
                self._force_dismiss()


# ── 싱글톤 ──────────────────────────────────────────────────────

_valhalla_state: ValhallaWarplateState = None

def get_valhalla_warplate_state() -> ValhallaWarplateState:
    global _valhalla_state
    if _valhalla_state is None:
        _valhalla_state = ValhallaWarplateState()
    return _valhalla_state
