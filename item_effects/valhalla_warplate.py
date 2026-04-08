"""
발할라의 전갑 (Valhalla's Warplate) - 전설 아이템 효과 모듈

상의(갑옷) 부위 전설 아이템.
플레이어가 공을 타격 시 일정 확률(롤옵션 8~15%)로 투기장 영웅을 호위무사로 소환.
소환된 영웅은 보유 스킬 2개 중 1개를 랜덤 발동 후 퇴장 모션으로 사라짐.

실제 InGameBodyguard 시스템을 활용하여 인장과 동일한 스킬 발동.
"""

import random
import math
import os
import pygame
import pygame.freetype

# 연출용 로컬 RNG (전역 RNG 오염 방지)
_vfx_rng = random.Random(42)

# ── 영웅 목록 (투기장 15영웅) ──────────────────────────────────
VALHALLA_HEROES = [
    {"id": "mugen",      "name": "무겐",       "color": (120, 60, 180)},
    {"id": "kraken",     "name": "크라켄",      "color": (40, 120, 140)},
    {"id": "chronos",    "name": "크로노스",    "color": (200, 170, 100)},
    {"id": "onimaru",    "name": "오니마루",    "color": (200, 50, 70)},
    {"id": "maria",      "name": "연화",        "color": (180, 100, 150)},
    {"id": "ignis",      "name": "이그니스",    "color": (220, 100, 40)},
    {"id": "gear",       "name": "기어",        "color": (140, 100, 60)},
    {"id": "kurokage",   "name": "쿠로카게",    "color": (50, 50, 70)},
    {"id": "banshee",    "name": "벤시",        "color": (80, 130, 160)},
    {"id": "necro",      "name": "네크로",      "color": (80, 60, 100)},
    {"id": "joker",      "name": "조커",        "color": (220, 60, 80)},
    {"id": "mirage",     "name": "세트",        "color": (210, 180, 100)},
    {"id": "android",    "name": "안드로이드",  "color": (130, 140, 160)},
    {"id": "ra",         "name": "호루스",      "color": (230, 160, 40)},
    {"id": "monkeyking", "name": "원숭이왕",    "color": (205, 165, 75)},
]

# ── 소환 연출 상수 ──────────────────────────────────────────────
SUMMON_CUTSCENE_DURATION = 1.0  # 소환 컷신 시간 (초)
CUTSCENE_DISSOLVE_DURATION = 1.5  # 컷신 소멸 이펙트 지속 시간 (포탈 열림과 겹침)

# ── 상태 관리 ──────────────────────────────────────────────────

class ValhallaWarplateState:
    """발할라의 전갑 인게임 상태"""

    # 상태 머신
    IDLE = 0           # 대기 중
    CUTSCENE = 1       # 소환 컷신 (화면 정지 + 텍스트)
    PORTAL_DESCEND = 2 # 포탈에서 하강 중
    SUMMONED = 3       # 소환됨, 스킬 발동 대기
    SKILL_ACTIVE = 4   # 스킬 발동 중
    PORTAL_ASCEND = 5  # 포탈로 상승 퇴장 중

    # 포탈 상수
    PORTAL_DURATION = 1.0      # 포탈 하강/상승 시간 (초)
    PORTAL_Y = 80.0            # 포탈 위치 Y (화면 상단)
    PATROL_Y = 690.0           # 호위무사 순찰 Y (_BODYGUARD_PATROL_Y와 동일)

    def __init__(self):
        self.active = False           # 장착 중인지
        self.summon_chance = 0.10     # 소환 확률 (롤옵션에서 갱신)
        self.enhancement_bonus_pct = 0

        # 캐시 (프레임마다 재생성 방지)
        self._cached_sounds = {}        # {filename: pygame.mixer.Sound}
        self._cached_surfaces = {}      # {key: pygame.Surface / pygame.freetype.Font}
        self._cached_text = {}          # {text_key: (surface, rect)} 텍스트 래스터 캐시
        self._consumed_gauge = 0        # 환불용 게이지 소모량

        # 소환 관리
        self.state = self.IDLE
        self.summoning = False        # 현재 소환 중 (하위호환)
        self.summon_timer = 0.0       # 소환 후 경과 시간
        self.post_skill_timer = 0.0   # 스킬 발동 후 경과 시간
        self.post_skill_linger = 1.0  # 스킬 완료 후 퇴장 시작까지 대기 (초)
        self.max_summon_time = 10.0   # 스킬 미발동 시 최대 대기 시간 (초)
        self.summon_cooldown = 0.0    # 소환 쿨타임 (연속 소환 방지)
        self.SUMMON_COOLDOWN_TIME = 5.0  # 소환 간 최소 간격 (초)
        self._bodyguard_ref = None    # 사용 중인 InGameBodyguard 참조
        self.summoned_hero_name = ""  # 소환된 영웅 이름 (로그용)
        self._pending_hero = None     # 컷신 중 대기하는 영웅 데이터
        self._pending_skill_idx = 0   # 컷신 중 대기하는 스킬 인덱스

        # 포탈 연출 (매혹 차원의 문과 동일 구조, 황금빛)
        self.portal_timer = 0.0       # 포탈 애니메이션 경과
        self.portal_x = 380.0         # 포탈 X 위치
        self.portal_scale = 0.0       # 포탈 열림 스케일 (0→1)
        self.portal_angle = 0.0       # 소용돌이 회전각
        self.portal_flash = 0.0       # 포탈 반짝임 (0→1, 진입/퇴장 순간)
        self.portal_particles = []    # 소용돌이 파티클
        self.portal_lightning = []    # 전기 아크

        # 컷신 연출
        self.cutscene_timer = 0.0     # 컷신 경과 시간
        self.cutscene_particles = []  # 컷신 파티클
        self.cutscene_dissolve_timer = 0.0  # 컷신 소멸 잔여 이펙트 타이머

    @property
    def is_cutscene_active(self) -> bool:
        """컷신(화면 정지) 중인지"""
        return self.state == self.CUTSCENE

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

    def _start_portal_ascend(self):
        """포탈 상승 퇴장 시작"""
        if self._bodyguard_ref and self._bodyguard_ref.active and self._bodyguard_ref._guard_system:
            gs = self._bodyguard_ref._guard_system
            self._ascend_start_y = gs.y_bottom  # 현재 Y 위치 저장
            self.portal_x = gs.x_bottom  # 현재 X 위치에서 포탈 열림
            self.state = self.PORTAL_ASCEND
            self.portal_timer = 0.0
            self.portal_scale = 0.0
            self.portal_flash = 0.0
            self.portal_particles.clear()
            self.portal_lightning.clear()
            self.summoning = True
            # 새 스킬 발동 방지 + 포탈 이동 플래그
            gs.cooldown_bottom = 99999.0
            self._bodyguard_ref._valhalla_portal_moving = True
            self._portal_sound_played = False  # 상승 사운드 1회 재생용
            # 포탈 열림 사운드 재생
            self._play_sound("potal.wav", 0.7)
            print(f"⚔ 발할라의 전갑: {self.summoned_hero_name} 포탈 상승 시작!")
        else:
            self._force_dismiss()

    def _clear_state(self):
        """내부 상태 초기화"""
        if self._bodyguard_ref:
            self._bodyguard_ref._valhalla_portal_moving = False
        self._bodyguard_ref = None
        self.summoning = False
        self.state = self.IDLE
        # 소환 쿨타임 시작 (연속 소환 방지)
        self.summon_cooldown = self.SUMMON_COOLDOWN_TIME
        self.summon_timer = 0.0
        self.post_skill_timer = 0.0
        self.summoned_hero_name = ""
        self._pending_hero = None
        self._pending_skill_idx = 0
        self._consumed_gauge = 0
        self.cutscene_timer = 0.0
        self.cutscene_dissolve_timer = 0.0
        self.cutscene_particles.clear()
        self.portal_timer = 0.0
        self.portal_scale = 0.0
        self.portal_flash = 0.0
        self.portal_particles.clear()
        self.portal_lightning.clear()
        # 영웅별 텍스트 캐시 정리 (다음 소환 시 다른 영웅일 수 있음)
        self._cached_text = {k: v for k, v in self._cached_text.items() if not k.startswith('hero_')}

    def try_summon(self, ball_x: int = 380) -> bool:
        """공 타격 시 소환 시도. ball_x는 공을 친 시점의 X좌표."""
        if not self.active or self.state != self.IDLE:
            return False

        # 소환 쿨타임 체크 (연속 소환 방지)
        if self.summon_cooldown > 0:
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

        # 게이지 소모량 계산 (롤옵션, reverse=True이므로 낮을수록 좋음)
        gauge_cost = 45  # 기본값
        try:
            from legendary_items import get_legendary_roll_value
            gauge_cost = get_legendary_roll_value(
                "valhalla_warplate", "gauge_cost",
                apply_polish=True,
                enhancement_bonus_pct=self.enhancement_bonus_pct
            )
        except Exception:
            pass

        # 빈 슬롯 확인 먼저! (게이지 소모 전에 소환 가능 여부 확인)
        try:
            from game_mechanics.ingame_bodyguard import get_bodyguard, get_bodyguard2
            _bg = get_bodyguard()
            _bg2 = get_bodyguard2()
            # dismissed 슬롯이라도 잔여 스킬 이펙트가 남아있으면 재사용 불가
            # (이전 영웅의 해골궁수/유령/축소 등이 중간에 끊기는 것을 방지)
            def _slot_available(bg):
                if not bg.active:
                    return True
                if getattr(bg, '_valhalla_dismissed', False) and not bg.has_active_skills():
                    return True
                return False
            if not _slot_available(_bg) and not _slot_available(_bg2):
                return False
        except Exception:
            return False

        # 게이지 잔량 체크 + 소모 (슬롯 확인 후 소모 - 게이지 낭비 방지)
        # ⚠️ 실패 시 반드시 소환 중단 (무료 소환 방지)
        try:
            import pingfighter
            if pingfighter.special_gauge < gauge_cost:
                return False  # 게이지 부족
            pingfighter.consume_special_gauge(int(gauge_cost))
            self._consumed_gauge = int(gauge_cost)  # 환불용 저장
        except Exception:
            return False  # 게이지 시스템 오류 시 소환 불가

        # 컷신 시작! (실제 소환은 컷신 끝에)
        hero = random.choice(VALHALLA_HEROES)
        self._pending_hero = hero
        skill_idx = random.randint(0, 1)
        # 스토리모드에서 작동하지 않는 스킬 회피:
        # - 밴시 매혹(인덱스 0): 적 호위무사가 없어 발동 불가 → 유령소환(인덱스 1) 강제
        if hero["id"] == "banshee" and skill_idx == 0:
            skill_idx = 1  # 유령소환 사용
        self._pending_skill_idx = skill_idx
        self.state = self.CUTSCENE
        self.summoning = True
        # 소환 위치를 공을 친 X좌표로 설정 (화면 범위 내 클램프)
        self.portal_x = float(max(100, min(660, ball_x)))
        # 컷신 시작 사운드
        self._play_sound("potal2.wav", 0.8)
        self.cutscene_timer = 0.0
        self.summoned_hero_name = hero["name"]

        # 컷신 파티클 생성 (소환 위치 기준)
        particle_cx = self.portal_x
        particle_cy = 375.0  # 화면 중앙 Y
        self.cutscene_particles.clear()
        for _ in range(18):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(20, 80)
            self.cutscene_particles.append({
                "x": particle_cx, "y": particle_cy,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 20,
                "life": random.uniform(0.5, 1.0),
                "max_life": random.uniform(0.5, 1.0),
                "size": random.uniform(2, 5),
                "type": random.choice(["gold", "rune", "light"]),
            })

        print(f"⚔ 발할라의 부름: {hero['name']} 소환 컷신 시작!")
        return True

    def _do_actual_summon(self):
        """컷신 종료 후 실제 호위무사 소환"""
        hero = self._pending_hero
        skill_idx = self._pending_skill_idx
        if not hero:
            self._clear_state()
            return

        _setup_bg = None  # setup() 성공한 bodyguard 추적 (예외 시 정리용)
        try:
            from game_mechanics.ingame_bodyguard import get_bodyguard, get_bodyguard2
            _bg = get_bodyguard()
            _bg2 = get_bodyguard2()
            # dismissed 상태 + 잔여 이펙트 완료된 슬롯만 재사용
            # (잔여 스킬 이펙트가 남아있으면 중간에 끊기므로 재사용 불가)
            def _is_available(bg):
                if not bg.active:
                    return True
                if getattr(bg, '_valhalla_dismissed', False) and not bg.has_active_skills():
                    bg.reset()  # 잔여 이펙트 완료 확인 후 정리
                    return True
                return False
            target_bg = _bg if _is_available(_bg) else (_bg2 if _is_available(_bg2) else None)
            if not target_bg:
                # 슬롯이 사라졌으면 게이지 환불
                self._refund_gauge()
                self._clear_state()
                return

            hero_data = {
                "id": hero["id"],
                "name": hero["name"],
                "color": tuple(hero["color"]),
                "title": ""
            }
            skill_sel = {hero["id"]: skill_idx}
            target_bg.setup(hero_data, skill_selections=skill_sel, first_spawn=True)
            _setup_bg = target_bg  # setup 성공 → 예외 시 reset 대상

            if target_bg._guard_system:
                target_bg._guard_system.cooldown_bottom = 0.1

            self._bodyguard_ref = target_bg
            self.summon_timer = 0.0
            self.post_skill_timer = 0.0

            # 포탈 하강 시작: guard_system의 위치와 phase를 강제 오버라이드
            gs = target_bg._guard_system
            if gs:
                gs.x_bottom = self.portal_x
                gs.y_bottom = self.PORTAL_Y - 30
                gs.phase_bottom = None
                gs.active_bottom = gs.guard_warriors_bottom[0] if gs.guard_warriors_bottom else None
                gs.cooldown_bottom = 99.0
                if gs.hero_paddle_renderer and hero:
                    gs.hero_paddle_renderer.update_movement(hero["id"], self.portal_x, 0.016)

            self.state = self.PORTAL_DESCEND
            self.portal_timer = 0.0
            self.portal_scale = 0.0
            self.portal_angle = 0.0
            self.portal_flash = 0.0
            self.portal_particles.clear()
            self.portal_lightning.clear()
            self._pending_hero = None
            self._portal_sound_played = False
            target_bg._valhalla_portal_moving = True
            self._play_sound("potal.wav", 0.7)
            print(f"⚔ 발할라의 전갑: {hero['name']} 포탈 하강 시작!")

        except Exception as e:
            print(f"[WARN] 발할라 전갑 소환 실패: {e}")
            # setup() 이후 예외 → 이미 활성화된 bodyguard 정리
            if _setup_bg is not None:
                try:
                    _setup_bg.reset()
                except Exception:
                    pass
            self._refund_gauge()
            self._clear_state()

    def _refund_gauge(self):
        """소환 실패 시 소모된 게이지 환불 (special_ready / game_state 동기화 포함)"""
        refund = getattr(self, '_consumed_gauge', 0)
        if refund > 0:
            try:
                import pingfighter
                pingfighter.special_gauge = min(
                    pingfighter.special_gauge + refund,
                    pingfighter.special_gauge_max
                )
                # consume_special_gauge()와 동일한 상태 동기화
                pingfighter.special_ready = pingfighter.special_gauge >= 350
                try:
                    pingfighter.game_state.special_gauge = pingfighter.special_gauge
                    pingfighter.game_state.special_ready = pingfighter.special_ready
                except Exception:
                    pass
                print(f"⚔ 발할라의 전갑: 소환 실패 → 게이지 {refund} 환불")
            except Exception:
                pass
            self._consumed_gauge = 0

    def update(self, dt: float):
        """매 프레임 업데이트 - 상태 머신 기반 관리"""
        # 소환 쿨타임 감소 (IDLE 상태에서도)
        if self.summon_cooldown > 0:
            self.summon_cooldown -= dt

        if self.state == self.IDLE:
            return

        # ── CUTSCENE: 소환 연출 (화면 정지) ──
        if self.state == self.CUTSCENE:
            self.cutscene_timer += dt
            # 파티클 업데이트
            for p in self.cutscene_particles:
                p["x"] += p["vx"] * dt
                p["y"] += p["vy"] * dt
                p["life"] -= dt
            self.cutscene_particles = [p for p in self.cutscene_particles if p["life"] > 0]
            # 컷신 종료 → 실제 소환 (소멸 이펙트는 포탈 단계에서 계속)
            if self.cutscene_timer >= SUMMON_CUTSCENE_DURATION:
                self.cutscene_dissolve_timer = CUTSCENE_DISSOLVE_DURATION
                self._do_actual_summon()
            return

        self.summon_timer += dt
        bg = self._bodyguard_ref
        gs = bg._guard_system if bg and bg.active else None

        # 컷신 소멸 타이머 (포탈 단계에서도 계속 감소)
        if self.cutscene_dissolve_timer > 0:
            self.cutscene_dissolve_timer -= dt

        # ── PORTAL_DESCEND: 포탈 열림(2.0초) → 플래시+하강(1.0초) → 포탈 닫힘(1.0초) ──
        if self.state == self.PORTAL_DESCEND:
            self.portal_timer += dt
            self.portal_angle += dt * 2.5  # 소용돌이 회전 (느리게)

            t = self.portal_timer
            if t < 2.0:
                # 포탈 천천히 열리는 중 (0→1, 2초)
                # 호위무사는 포탈 위(화면 밖)에 숨겨둠
                progress = t / 2.0
                self.portal_scale = 1.0 - (1.0 - progress) ** 3
                self._spawn_portal_swirl(0.4 + 0.4 * progress)
                self._spawn_portal_lightning(0.1 + 0.3 * progress)
                self.portal_flash = 0.0
                # 호위무사를 포탈 위에 숨김 (phase=None으로 자체 이동 차단)
                if gs:
                    gs.y_bottom = self.PORTAL_Y - 30
                    gs.x_bottom = self.portal_x
                    gs.phase_bottom = None
            elif t < 3.0:
                # 플래시 + 하강 (포탈에서 영웅이 내려옴!)
                self.portal_scale = 1.0
                descend_progress = min(1.0, (t - 2.0) / 1.0)
                # 하강 시작 순간 포탈 반짝
                if descend_progress < 0.15:
                    self.portal_flash = 1.0 - descend_progress / 0.15
                else:
                    self.portal_flash = 0.0
                eased = 1.0 - (1.0 - descend_progress) ** 2  # ease-out
                if gs:
                    # 포탈 위치(Y=80) → 순찰 위치(Y=620) 하강
                    gs.y_bottom = self.PORTAL_Y + (self.PATROL_Y - self.PORTAL_Y) * eased
                    gs.x_bottom = self.portal_x
                    # patrolling으로 설정해야 캐릭터가 보임
                    gs.phase_bottom = "patrolling"
                self._spawn_portal_swirl(0.3)
            elif t < 4.0:
                # 포탈 천천히 닫힘 (1→0, 1초)
                close_progress = (t - 3.0) / 1.0
                self.portal_scale = max(0, (1.0 - close_progress) ** 2)
                self.portal_flash = 0.0
                self._spawn_portal_swirl(0.15 * self.portal_scale)
                # 호위무사는 순찰 위치에 고정
                if gs:
                    gs.y_bottom = self.PATROL_Y
                    gs.phase_bottom = "patrolling"
            else:
                # 완료 → SUMMONED
                self.portal_scale = 0.0
                self.portal_flash = 0.0
                self.state = self.SUMMONED
                self.summon_timer = 0.0
                self.portal_particles.clear()
                self.portal_lightning.clear()
                if gs:
                    gs.cooldown_bottom = 0.1
                    gs.phase_bottom = "patrolling"
                    gs.y_bottom = self.PATROL_Y
                # 포탈 이동 플래그 해제
                if bg:
                    bg._valhalla_portal_moving = False
                print(f"⚔ 발할라의 전갑: {self.summoned_hero_name} 하강 완료 → 스킬 대기")

            self._update_portal_particles(dt)

        # ── SUMMONED: 스킬 발동 대기 ──
        elif self.state == self.SUMMONED:
            if gs:
                phase = getattr(gs, 'phase_bottom', 'patrolling')
                if phase not in ('patrolling', 'patrol_entering', None):
                    self.state = self.SKILL_ACTIVE
                    print(f"⚔ 발할라의 전갑: {self.summoned_hero_name} 스킬 발동!")
            if self.summon_timer >= self.max_summon_time:
                self._start_portal_ascend()

        # ── SKILL_ACTIVE: 스킬 시전 완료 대기 → 포탈 상승 시작 ──
        elif self.state == self.SKILL_ACTIVE:
            if gs:
                phase = getattr(gs, 'phase_bottom', 'patrolling')
                if phase in ('patrolling', 'patrol_entering', None):
                    casting_done = True
                    for hero_id, skills in gs.skill_instances.items():
                        for skill in skills:
                            if getattr(skill, 'is_active', False):
                                active_timer = getattr(skill, 'active_timer', 999)
                                if active_timer < 2.0:
                                    casting_done = False
                                    break
                        if not casting_done:
                            break
                    if casting_done:
                        self.post_skill_timer += dt
                        if self.post_skill_timer >= self.post_skill_linger:
                            self._start_portal_ascend()
            else:
                self._clear_state()

        # ── PORTAL_ASCEND: 포탈 열림(2.0초) → 플래시+상승(1.0초) → 포탈 닫힘(1.0초) ──
        elif self.state == self.PORTAL_ASCEND:
            self.portal_timer += dt
            self.portal_angle += dt * 2.5

            t = self.portal_timer
            if t < 2.0:
                # 복귀 포탈 천천히 열리는 중 (0→1, 2초)
                progress = t / 2.0
                self.portal_scale = 1.0 - (1.0 - progress) ** 3
                self._spawn_portal_swirl(0.4 + 0.4 * progress)
                self._spawn_portal_lightning(0.1 + 0.3 * progress)
                self.portal_flash = 0.0
                # 호위무사는 아래에서 대기 (순찰 위치)
                if gs:
                    gs.y_bottom = getattr(self, '_ascend_start_y', self.PATROL_Y)
                    gs.x_bottom = self.portal_x
                    gs.phase_bottom = "patrolling"
            elif t < 3.0:
                # 플래시 + 상승 (영웅이 포탈로 올라감!)
                self.portal_scale = 1.0
                ascend_progress = min(1.0, (t - 2.0) / 1.0)
                # 포탈 진입 순간 반짝 (상승 80% 지점)
                if 0.75 < ascend_progress < 0.9:
                    self.portal_flash = (ascend_progress - 0.75) / 0.15
                elif ascend_progress >= 0.9:
                    self.portal_flash = max(0, 1.0 - (ascend_progress - 0.9) / 0.1)
                else:
                    self.portal_flash = 0.0
                eased = ascend_progress ** 2  # ease-in (천천히 → 빠르게)
                start_y = getattr(self, '_ascend_start_y', self.PATROL_Y)
                if gs:
                    # 순찰 위치(Y=620) → 포탈 위치(Y=80) 상승
                    gs.y_bottom = start_y + (self.PORTAL_Y - start_y) * eased
                    gs.x_bottom = self.portal_x
                    gs.phase_bottom = "patrolling"  # 캐릭터 보이게
                self._spawn_portal_swirl(0.4)
            elif t < 4.0:
                # 포탈 천천히 닫힘 (1→0, 1초)
                # 호위무사는 포탈 안에 사라짐
                close_progress = (t - 3.0) / 1.0
                self.portal_scale = max(0, (1.0 - close_progress) ** 2)
                self.portal_flash = 0.0
                self._spawn_portal_swirl(0.15 * self.portal_scale)
                if gs:
                    gs.y_bottom = self.PORTAL_Y - 30  # 포탈 위로 숨김
                    gs.phase_bottom = None  # 캐릭터 안 보이게
            else:
                # 완료 → 스킬 유지한 채 해산
                self.portal_scale = 0.0
                self.portal_flash = 0.0
                if bg and bg.active:
                    bg.dismiss_keep_skills()
                print(f"⚔ 발할라의 전갑: {self.summoned_hero_name} 포탈로 퇴장 완료!")
                self._clear_state()
                return

            self._update_portal_particles(dt)

            # 안전장치
            if self.summon_timer >= self.max_summon_time + 8.0:
                self._force_dismiss()

        pass  # 파티클 업데이트는 각 상태 내에서 처리

    @staticmethod
    def _resolve_resource(relative_path):
        """resource_path 우선, 실패 시 프로젝트 루트 기준 fallback (PyInstaller 호환)"""
        try:
            from core.constants import resource_path
            p = resource_path(relative_path)
            if os.path.exists(p):
                return p
        except Exception:
            pass
        # fallback: __file__ 기준
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(project_root, relative_path)

    def _get_font(self, size):
        """폰트 캐시 (매 프레임 재로딩 방지)"""
        key = f"font_{size}"
        if key not in self._cached_surfaces:
            try:
                font_path = self._resolve_resource("NanumSquareB.ttf")
                self._cached_surfaces[key] = pygame.freetype.Font(font_path, size)
            except Exception:
                self._cached_surfaces[key] = None
        return self._cached_surfaces.get(key)

    def _get_cached_text(self, text_key, text, font_size, color):
        """텍스트 Surface 캐시 (매 프레임 래스터라이즈 방지, 폰트 fallback 포함)"""
        if text_key in self._cached_text:
            return self._cached_text[text_key]
        font = self._get_font(font_size)
        if font:
            try:
                surf, rect = font.render(text, color)
                self._cached_text[text_key] = (surf, rect)
                return (surf, rect)
            except Exception:
                pass
        # fallback: 기본 폰트 (NanumSquare 로드 실패 또는 렌더 실패 시)
        try:
            fb = pygame.font.Font(None, font_size + 2)
            surf = fb.render(text, True, color[:3] if len(color) > 3 else color)
            rect = surf.get_rect()
            self._cached_text[text_key] = (surf, rect)
            return (surf, rect)
        except Exception:
            return None

    def _get_surface(self, key, width, height, skip_clear=False):
        """재사용 Surface 캐시 (크기가 같으면 재사용, 다르면 재생성)
        skip_clear=True: 호출자가 직접 fill()할 경우 이중 fill 방지"""
        cached = self._cached_surfaces.get(key)
        if cached and cached.get_width() == width and cached.get_height() == height:
            if not skip_clear:
                cached.fill((0, 0, 0, 0))
            return cached
        surf = pygame.Surface((width, height), pygame.SRCALPHA)
        self._cached_surfaces[key] = surf
        return surf

    def _play_sound(self, filename, volume=0.7):
        """사운드 재생 헬퍼 (캐시 사용)"""
        try:
            if filename not in self._cached_sounds:
                path = self._resolve_resource(os.path.join("sounds", filename))
                if os.path.exists(path):
                    self._cached_sounds[filename] = pygame.mixer.Sound(path)
                else:
                    self._cached_sounds[filename] = None
            snd = self._cached_sounds.get(filename)
            if snd:
                snd.set_volume(volume)
                snd.play()
        except Exception:
            pass

    def _spawn_portal_swirl(self, chance):
        """소용돌이 파티클 생성 (최대 개수 제한으로 프레임 드랍 방지)"""
        if len(self.portal_particles) >= 20:  # 파티클 상한
            return
        if random.random() < chance * 0.6:  # 스폰율 40% 감소
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(25, 55)
            self.portal_particles.append({
                'x': self.portal_x + math.cos(angle) * dist,
                'y': self.PORTAL_Y + math.sin(angle) * dist * 0.7,
                'angle': angle,
                'dist': dist,
                'speed': random.uniform(2.0, 4.0),
                'life': random.uniform(0.4, 0.8),
                'max_life': 0.8,
                'size': random.uniform(2, 5),
            })

    def _spawn_portal_lightning(self, chance):
        """전기 아크 생성 (최대 개수 제한)"""
        if len(self.portal_lightning) >= 6:  # 번개 상한
            return
        if random.random() < chance and self.portal_scale > 0.15:
            self.portal_lightning.append({
                'angle': random.uniform(0, math.pi * 2),
                'length': random.uniform(8, 22),
                'life': random.uniform(0.05, 0.15),
                'max_life': 0.15,
                'segments': random.randint(2, 4),
            })

    def _update_portal_particles(self, dt):
        """파티클 + 번개 업데이트 (매혹과 동일 구조)"""
        alive = []
        for p in self.portal_particles:
            p['life'] -= dt
            if p['life'] > 0:
                p['angle'] += dt * p['speed']
                p['dist'] = max(0, p['dist'] - dt * 40)
                p['x'] = self.portal_x + math.cos(p['angle']) * p['dist']
                p['y'] = self.PORTAL_Y + math.sin(p['angle']) * p['dist'] * 0.7
                alive.append(p)
        self.portal_particles = alive
        alive_arcs = []
        for arc in self.portal_lightning:
            arc['life'] -= dt
            if arc['life'] > 0:
                alive_arcs.append(arc)
        self.portal_lightning = alive_arcs

    @staticmethod
    def _clamp(v):
        """RGBA alpha 값을 0~255 범위로 클램프"""
        return min(255, max(0, int(v)))

    def draw_cutscene(self, screen: pygame.Surface):
        """소환 컷신 연출 드로잉 - 단일 오버레이 Surface, 텍스트 캐시"""
        if self.state != self.CUTSCENE:
            return

        _c = self._clamp
        W, H = 760, 750
        progress = min(1.0, self.cutscene_timer / SUMMON_CUTSCENE_DURATION)
        hero = self._pending_hero
        if not hero:
            return
        # 단일 오버레이 Surface (cutscene + dissolve 공유, skip_clear: 직후 fill)
        overlay = self._get_surface('vw_overlay', W, H, skip_clear=True)

        cx, cy = int(self.portal_x), H // 2 - 30

        if progress < 0.3:
            fade_mult = progress / 0.3
        else:
            fade_mult = 1.0

        # ── 1) 어두운 오버레이 (전체 fill = clear 대체) ──
        overlay.fill((5, 5, 20, _c(120 * fade_mult)))

        # ── 2) 빛기둥 (고정 Surface, 실제 너비 bw 영역만 blit) ──
        beam_appear = min(1.0, progress * 2.5)
        beam_fade = fade_mult
        BW_MAX = 22
        beam_surf = self._get_surface('beam_shared', BW_MAX, H, skip_clear=True)
        for bi in range(2):
            bw = int((6 + bi * 14) * beam_appear)
            if bw < 2:
                continue
            ba = _c((55 - bi * 22) * beam_fade)
            if ba < 3:
                continue
            beam_surf.fill((255, 220 + bi * 15, 100 + bi * 40, _c(ba * 0.25)))
            pygame.draw.line(beam_surf, (255, 240, 160, ba), (BW_MAX // 2, 0), (BW_MAX // 2, H), 1)
            # bw 영역만 클리핑하여 blit → 초반 가늘게 열리는 애니메이션 유지
            clip_x = (BW_MAX - bw) // 2
            overlay.blit(beam_surf, (cx - bw // 2, 0), area=(clip_x, 0, bw, H))

        # ── 3) 텍스트 (캐시된 Surface 재사용) ──
        ta = _c(255 * fade_mult)
        if ta > 10:
            try:
                main_res = self._get_cached_text('valhalla_call', "발할라의 부름", 34, (255, 235, 160))
                if main_res:
                    main_surf, main_rect = main_res
                    main_surf.set_alpha(ta)
                    tx = cx - main_rect.width // 2
                    ty_main = cy - 65
                    overlay.blit(main_surf, (tx, ty_main))
                    line_w = int(main_rect.width * 0.8)
                    if line_w > 10:
                        pygame.draw.line(overlay, (255, 220, 100, _c(ta * 0.4)),
                                       (cx - line_w // 2, ty_main + main_rect.height + 4),
                                       (cx + line_w // 2, ty_main + main_rect.height + 4), 1)
                hero_key = f'hero_{hero["id"]}'
                name_res = self._get_cached_text(hero_key, f'― {hero["name"]} ―', 22, tuple(hero["color"][:3]))
                if name_res:
                    name_surf, name_rect = name_res
                    name_surf.set_alpha(ta)
                    overlay.blit(name_surf, (cx - name_rect.width // 2, cy + 40))
            except Exception:
                pass

        # ── 4) 파티클 ──
        for p in self.cutscene_particles:
            ratio = max(0, p["life"] / p["max_life"])
            sz = max(1, int(p["size"] * ratio))
            pa = _c(180 * ratio * fade_mult)
            if pa < 3 or sz < 1:
                continue
            if p["type"] == "gold":
                col = (255, 215, 80, pa)
            elif p["type"] == "rune":
                col = (200, 180, 255, pa)
            else:
                col = (255, 255, 230, pa)
            pygame.draw.circle(overlay, col, (int(p["x"]), int(p["y"])), sz)

        # ── 5) 비네팅 ──
        va = _c(50 * fade_mult)
        if va > 3:
            for i in range(2):
                pygame.draw.rect(overlay, (255, 200, 60, _c(va / (i + 1))),
                               (i * 4, i * 4, W - i * 8, H - i * 8), 2)

        screen.blit(overlay, (0, 0))

    def draw_cutscene_dissolve(self, screen: pygame.Surface):
        """컷신 소멸 이펙트 (cutscene과 동일 오버레이 Surface 공유, 텍스트 캐시)"""
        if self.cutscene_dissolve_timer <= 0:
            return

        _c = self._clamp
        W, H = 760, 750
        cx, cy = int(self.portal_x), H // 2 - 30
        fade = max(0, self.cutscene_dissolve_timer / CUTSCENE_DISSOLVE_DURATION)

        # cutscene과 동일한 Surface 재사용 (동시에 활성화되지 않음)
        overlay = self._get_surface('vw_overlay', W, H, skip_clear=True)

        # 1) 어두운 오버레이
        overlay_a = _c(80 * fade)
        if overlay_a > 2:
            overlay.fill((5, 5, 20, overlay_a))
        else:
            overlay.fill((0, 0, 0, 0))

        # 2) 빛기둥 잔상 (고정 Surface, fade에 따라 너비 축소)
        bw_d = max(1, int(8 * fade))
        ba = _c(35 * fade)
        if ba > 3 and bw_d > 0:
            beam_s = self._get_surface('beam_shared', 22, H, skip_clear=True)
            beam_s.fill((255, 230, 130, _c(ba * 0.2)))
            pygame.draw.line(beam_s, (255, 240, 160, ba), (11, 0), (11, H), 1)
            clip_x = (22 - bw_d) // 2
            overlay.blit(beam_s, (cx - bw_d // 2, 0), area=(clip_x, 0, bw_d, H))

        # 3) 흩뿌려지는 파편
        scatter = 1.0 - fade
        _rng = _vfx_rng
        _rng.seed(42)
        cols = [(255, 230, 100), (255, 250, 210), (220, 180, 60), (255, 200, 80)]
        for si in range(14):
            s_angle = _rng.uniform(0, math.pi * 2)
            s_dist = _rng.uniform(20, 180) * scatter + _rng.uniform(-5, 5)
            s_x = cx + int(math.cos(s_angle) * s_dist)
            s_y = cy + int(math.sin(s_angle) * s_dist * 0.7)
            s_sz = max(1, int(_rng.uniform(2, 4) * fade))
            s_a = _c(180 * fade * _rng.uniform(0.3, 1.0))
            if s_a > 3 and s_sz > 0:
                pygame.draw.circle(overlay, (*cols[si % 4], s_a), (s_x, s_y), s_sz)

        # 4) 텍스트 잔상 (캐시된 Surface)
        ta = _c(180 * fade)
        if ta > 8:
            try:
                main_res = self._get_cached_text('valhalla_call', "발할라의 부름", 34, (255, 235, 160))
                if main_res:
                    main_surf, main_rect = main_res
                    main_surf.set_alpha(ta)
                    overlay.blit(main_surf, (cx - main_rect.width // 2, cy - 65))
            except Exception:
                pass

        screen.blit(overlay, (0, 0))

    def draw_portal(self, screen: pygame.Surface):
        """포탈 이펙트 드로잉 (최적화: Surface 축소, 연산 감소)"""
        if self.state not in (self.PORTAL_DESCEND, self.PORTAL_ASCEND):
            return

        scale = self.portal_scale
        if scale < 0.01:
            return

        cx = int(self.portal_x)
        cy = int(self.PORTAL_Y)
        pw = int(50 * scale)
        ph = int(70 * scale)
        if pw < 2 or ph < 2:
            return

        _c = self._clamp
        t = self.portal_timer
        flash = getattr(self, 'portal_flash', 0.0)

        # 포탈 Surface 축소: 300→180 (실제 포탈 크기 대비 충분)
        PS = 180
        portal_surf = self._get_surface('portal_main', PS, PS)
        pc = PS // 2

        # ── 0) 플래시 (vw_overlay 재사용 → 별도 전체화면 Surface 제거) ──
        if flash > 0.05:
            flash_a = _c(80 * flash)
            flash_ov = self._get_surface('vw_overlay', 760, 750, skip_clear=True)
            flash_ov.fill((255, 230, 150, flash_a))
            screen.blit(flash_ov, (0, 0))

        # ── 0.5) 시공간 균열 (scale < 0.6, 크기 축소 200→120) ──
        if scale < 0.6:
            ci_val = 1.0 - scale / 0.6
            CS = 120
            cc = CS // 2
            crack_s = self._get_surface('portal_crack', CS, CS)
            _rng = _vfx_rng
            _rng.seed(int(t * 2))
            n_cracks = 4 + int(scale * 5)  # 6~10 → 4~8개로 축소
            step = math.pi * 2 / max(1, n_cracks)
            for ci in range(n_cracks):
                angle = ci * step + math.sin(t * 1.5 + ci) * 0.3
                length = int(15 + 40 * scale + _rng.uniform(-8, 8))
                cos_a, sin_a = math.cos(angle), math.sin(angle)
                pts = [(cc, cc)]
                for seg in range(_rng.randint(2, 4)):
                    frac = (seg + 1) / 4
                    pts.append((cc + int(cos_a * length * frac) + _rng.randint(-4, 4),
                                cc + int(sin_a * length * frac) + _rng.randint(-4, 4)))
                if len(pts) >= 2:
                    # 1겹으로 축소 (2겹→1겹)
                    pygame.draw.lines(crack_s, (255, 220, 120, _c(150 * ci_val)), False, pts, 2)
            dr = max(2, int(4 + 6 * scale))
            da = _c((100 + 50 * ((math.sin(t * 8) + 1) * 0.5)) * ci_val)
            pygame.draw.circle(crack_s, (255, 240, 180, da), (cc, cc), dr)
            screen.blit(crack_s, (cx - cc, cy - cc))

        # ── 1) 외곽 글로우 (3→2겹) ──
        for gi in range(2):
            gw = pw * (3 - gi) + 8
            gh = ph * (3 - gi) + 8
            if gw > 0 and gh > 0:
                pulse = (math.sin(t * 3.5 + gi * 0.7) + 1) * 0.5
                ga = _c((22 + 15 * pulse) * scale)
                colors = [(220, 180, 50), (190, 140, 30)]
                pygame.draw.ellipse(portal_surf, (*colors[gi], ga),
                                   (pc - gw // 2, pc - gh // 2, gw, gh))

        # ── 2) 검은 코어 ──
        cw, ch = int(pw * 1.6), int(ph * 1.6)
        if cw > 2 and ch > 2:
            pygame.draw.ellipse(portal_surf, (5, 3, 12, 240),
                               (pc - cw // 2, pc - ch // 2, cw, ch))
            im = max(2, int(cw * 0.15))
            pygame.draw.ellipse(portal_surf, (2, 1, 6, 250),
                               (pc - cw // 2 + im, pc - ch // 2 + im, cw - im * 2, ch - im * 2))

        # ── 3) 에너지 링 (4→3중) ──
        for i in range(3):
            rw = pw + i * 6 + 3
            rh = ph + i * 6 + 3
            po = math.sin(t * (4 + i) + i) * 0.3 + 0.7
            ra = _c((160 - i * 45) * po * scale)
            if ra < 8:
                continue
            r = min(255, 255 - i * 12)
            g = min(255, 220 - i * 30)
            b = min(255, 80 + i * 15)
            pygame.draw.ellipse(portal_surf, (r, g, b, ra),
                               (pc - rw, pc - rh, rw * 2, rh * 2), max(1, 3 - i))

        # ── 4) 소용돌이 (12→8개) + 내부 (6→4개) ──
        step8 = math.pi * 2 / 8
        for j in range(8):
            angle = self.portal_angle + j * step8
            rm = 0.5 + 0.2 * math.sin(t * 2.5 + j * 0.7)
            sx = pc + int(math.cos(angle) * pw * rm)
            sy = pc + int(math.sin(angle) * ph * rm)
            sz = max(1, int(2 + 1.5 * math.sin(t * 5 + j)))
            cols = [(255, 220, 80, 200), (255, 245, 180, 180), (255, 180, 50, 170)]
            pygame.draw.circle(portal_surf, cols[j % 3], (sx, sy), sz)
        step4 = math.pi * 2 / 4
        for k in range(4):
            angle = -self.portal_angle * 1.8 + k * step4
            rm = 0.25 + 0.1 * math.sin(t * 4 + k)
            pygame.draw.circle(portal_surf, (255, 240, 160, 140),
                             (pc + int(math.cos(angle) * pw * rm),
                              pc + int(math.sin(angle) * ph * rm)), 2)

        # ── 5) 전기 아크 ──
        for arc in self.portal_lightning:
            ratio = arc['life'] / arc['max_life']
            aa = _c(220 * ratio)
            sa = arc['angle']
            al = arc['length'] * scale
            cos_sa, sin_sa = math.cos(sa), math.sin(sa)
            sx = pc + int(cos_sa * pw)
            sy = pc + int(sin_sa * ph)
            pts = [(sx, sy)]
            for seg in range(arc['segments']):
                frac = (seg + 1) / arc['segments']
                pts.append((sx + int(cos_sa * al * frac) + _vfx_rng.randint(-4, 4),
                            sy + int(sin_sa * al * frac) + _vfx_rng.randint(-4, 4)))
            if len(pts) >= 2:
                try:
                    pygame.draw.lines(portal_surf, (255, 240, 160, aa), False, pts, 1)
                except Exception:
                    pass

        # ── 6) 파티클 ──
        for p in self.portal_particles:
            ratio = p['life'] / p['max_life']
            pa = _c(180 * ratio)
            if pa < 3:
                continue
            sz = max(1, int(p['size'] * ratio))
            px = pc + int(p['x'] - self.portal_x)
            py = pc + int(p['y'] - self.PORTAL_Y)
            if 0 <= px < PS and 0 <= py < PS:
                pygame.draw.circle(portal_surf, (255, 220, 80, pa), (px, py), sz)

        # ── 7) 코어 빛 ──
        cr = max(3, int(8 * scale))
        pulse = (math.sin(t * 6) + 1) * 0.5
        ca = _c(80 + 60 * pulse)
        pygame.draw.circle(portal_surf, (255, 240, 180, ca), (pc, pc), cr * 2)
        pygame.draw.circle(portal_surf, (255, 250, 220, _c(ca * 1.3)), (pc, pc), cr)

        # 1회 blit
        screen.blit(portal_surf, (cx - pc, cy - pc))


# ── 싱글톤 ──────────────────────────────────────────────────────

_valhalla_state: ValhallaWarplateState = None

def get_valhalla_warplate_state() -> ValhallaWarplateState:
    global _valhalla_state
    if _valhalla_state is None:
        _valhalla_state = ValhallaWarplateState()
    return _valhalla_state
