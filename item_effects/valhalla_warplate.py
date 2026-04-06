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

# ── 소환 연출 상수 ──────────────────────────────────────────────
SUMMON_CUTSCENE_DURATION = 1.0  # 소환 컷신 시간 (초)

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
        self.cutscene_timer = 0.0
        self.cutscene_particles.clear()
        self.portal_timer = 0.0
        self.portal_alpha = 0.0
        self.portal_particles.clear()

    def try_summon(self) -> bool:
        """공 타격 시 소환 시도. 성공하면 True (컷신 시작)."""
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

        # 빈 슬롯 확인 (dismissed 상태는 빈 슬롯으로 간주)
        try:
            from game_mechanics.ingame_bodyguard import get_bodyguard, get_bodyguard2
            _bg = get_bodyguard()
            _bg2 = get_bodyguard2()
            _bg1_avail = not _bg.active or getattr(_bg, '_valhalla_dismissed', False)
            _bg2_avail = not _bg2.active or getattr(_bg2, '_valhalla_dismissed', False)
            if not _bg1_avail and not _bg2_avail:
                return False
        except Exception:
            return False

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
        self.cutscene_timer = 0.0
        self.summoned_hero_name = hero["name"]

        # 컷신 파티클 생성
        try:
            from core.constants import WIDTH, HEIGHT
            particle_cx = float(WIDTH // 2)
            particle_cy = float(HEIGHT // 2)
        except Exception:
            particle_cx = 380.0
            particle_cy = 375.0
        self.cutscene_particles.clear()
        for _ in range(30):
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

        try:
            from game_mechanics.ingame_bodyguard import get_bodyguard, get_bodyguard2
            _bg = get_bodyguard()
            _bg2 = get_bodyguard2()
            # dismissed 상태(스킬 잔여물만 남은 슬롯)는 강제 정리 후 재사용
            def _is_available(bg):
                if not bg.active:
                    return True
                if getattr(bg, '_valhalla_dismissed', False):
                    bg.reset()  # 잔여 스킬도 정리하고 재사용
                    return True
                return False
            target_bg = _bg if _is_available(_bg) else (_bg2 if _is_available(_bg2) else None)
            if not target_bg:
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

            if target_bg._guard_system:
                target_bg._guard_system.cooldown_bottom = 0.1

            self._bodyguard_ref = target_bg
            self.summon_timer = 0.0
            self.post_skill_timer = 0.0

            # 포탈 하강 시작: guard_system의 위치와 phase를 강제 오버라이드
            gs = target_bg._guard_system
            if gs:
                self.portal_x = 380.0  # 화면 중앙
                # 호위무사를 포탈 위치에 배치 (화면 밖 상단)
                gs.x_bottom = self.portal_x
                gs.y_bottom = self.PORTAL_Y - 30  # 포탈 위쪽 (화면 밖, 하강하면서 등장)
                # patrol_entering(옆에서 걸어들어오기)을 무효화
                # phase를 None으로 → guard_system이 자체 이동 안 함
                gs.phase_bottom = None
                gs.active_bottom = gs.guard_warriors_bottom[0] if gs.guard_warriors_bottom else None
                # 쿨다운을 포탈 시간 동안 길게 (하강 완료 후 단축)
                gs.cooldown_bottom = 99.0
                # 영웅이 보이도록 걷기 모션 초기화
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
            self._portal_sound_played = False  # 하강 사운드 1회 재생용
            # 포탈 이동 중 플래그 설정 (y_bottom 강제 덮어쓰기 방지)
            target_bg._valhalla_portal_moving = True
            # 포탈 열림 사운드 재생
            self._play_sound("potal.wav", 0.7)
            print(f"⚔ 발할라의 전갑: {hero['name']} 포탈 하강 시작!")

        except Exception as e:
            print(f"[WARN] 발할라 전갑 소환 실패: {e}")
            self._clear_state()

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
            # 컷신 종료 → 실제 소환
            if self.cutscene_timer >= SUMMON_CUTSCENE_DURATION:
                self._do_actual_summon()
            return

        self.summon_timer += dt
        bg = self._bodyguard_ref
        gs = bg._guard_system if bg and bg.active else None

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
                # 하강 시작 순간 사운드 + 포탈 반짝
                if not self._portal_sound_played:
                    self._portal_sound_played = True
                    self._play_sound("potal2.wav", 0.8)
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
                # 상승 시작 순간 사운드
                if not self._portal_sound_played:
                    self._portal_sound_played = True
                    self._play_sound("potal2.wav", 0.8)
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

    def _play_sound(self, filename, volume=0.7):
        """사운드 재생 헬퍼"""
        try:
            # 프로젝트 루트 기준 경로 (다른 스킬과 동일 방식)
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            path = os.path.join(project_root, "sounds", filename)
            if os.path.exists(path):
                snd = pygame.mixer.Sound(path)
                snd.set_volume(volume)
                snd.play()
            else:
                print(f"[WARN] 사운드 파일 없음: {path}")
        except Exception as e:
            print(f"[WARN] 사운드 재생 실패 ({filename}): {e}")

    def _spawn_portal_swirl(self, chance):
        """소용돌이 파티클 생성 (매혹과 동일 구조)"""
        if random.random() < chance:
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
        """전기 아크 생성 (매혹과 동일 구조)"""
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
        """소환 컷신 연출 드로잉 (게임 렌더링 위에 오버레이)"""
        if self.state != self.CUTSCENE:
            return

        _c = self._clamp
        W, H = 760, 750  # 게임 내부 해상도 고정
        progress = min(1.0, self.cutscene_timer / SUMMON_CUTSCENE_DURATION)
        hero = self._pending_hero
        if not hero:
            return

        cx, cy = W // 2, H // 2 - 30

        # 전체를 하나의 SRCALPHA 서피스에 그림 (screen 직접 그리기 금지)
        cutscene_surf = pygame.Surface((W, H), pygame.SRCALPHA)

        # 1) 반투명 어두운 오버레이
        fade = _c(100 * min(1.0, progress * 3))
        cutscene_surf.fill((10, 10, 30, fade))

        # 2) 소환진 (확장되는 금빛 원형 룬)
        rune_progress = min(1.0, progress * 2)
        rune_r = int(20 + 80 * rune_progress)
        ra = _c(200 * (1.0 - progress * 0.5))
        rc = rune_r + 10
        rune_surf = pygame.Surface((rc * 2, rc * 2), pygame.SRCALPHA)
        pygame.draw.circle(rune_surf, (255, 215, 80, ra), (rc, rc), rune_r, 2)
        pygame.draw.circle(rune_surf, (255, 230, 120, _c(ra * 0.5)), (rc, rc), int(rune_r * 0.6), 1)
        cl = rune_r - 8
        pygame.draw.line(rune_surf, (255, 220, 100, _c(ra * 0.5)), (rc - cl, rc), (rc + cl, rc), 1)
        pygame.draw.line(rune_surf, (255, 220, 100, _c(ra * 0.5)), (rc, rc - cl), (rc, rc + cl), 1)
        diag = int(cl * 0.7)
        pygame.draw.line(rune_surf, (255, 200, 80, _c(ra * 0.33)), (rc - diag, rc - diag), (rc + diag, rc + diag), 1)
        pygame.draw.line(rune_surf, (255, 200, 80, _c(ra * 0.33)), (rc + diag, rc - diag), (rc - diag, rc + diag), 1)
        for i in range(8):
            angle = i * math.pi / 4 + progress * math.pi
            rx = rc + int(math.cos(angle) * (rune_r - 12))
            ry = rc + int(math.sin(angle) * (rune_r - 12))
            pygame.draw.circle(rune_surf, (255, 235, 150, ra), (rx, ry), 3)
        cutscene_surf.blit(rune_surf, (cx - rc, cy - rc))

        # 3) 빛기둥 (간소화 - 그라데이션 직사각형)
        beam_a = _c(100 * min(1.0, progress * 2))
        beam_w = int(6 + 24 * rune_progress)
        if beam_a > 5:
            beam_surf = pygame.Surface((beam_w, H), pygame.SRCALPHA)
            beam_surf.fill((255, 220, 100, _c(beam_a * 0.3)))
            # 중앙이 밝은 1px 선
            pygame.draw.line(beam_surf, (255, 240, 160, beam_a), (beam_w // 2, 0), (beam_w // 2, H), 1)
            cutscene_surf.blit(beam_surf, (cx - beam_w // 2, 0))

        # 4) "발할라의 부름" 텍스트
        ta = _c(255 * min(1.0, progress * 3))
        if progress > 0.7:
            ta = _c(255 * (1.0 - (progress - 0.7) / 0.3))
        if ta > 10:
            try:
                from core.constants import resource_path
                font_path = resource_path("fonts/NanumSquareB.ttf")
                main_font = pygame.freetype.Font(font_path, 32)
                main_surf, main_rect = main_font.render("발할라의 부름", (255, 230, 150))
                main_surf.set_alpha(ta)
                cutscene_surf.blit(main_surf, (cx - main_rect.width // 2, cy - 60))
                name_font = pygame.freetype.Font(font_path, 20)
                name_surf, name_rect = name_font.render(f"― {hero['name']} ―", tuple(hero["color"][:3]))
                name_surf.set_alpha(ta)
                cutscene_surf.blit(name_surf, (cx - name_rect.width // 2, cy + 40))
            except Exception:
                try:
                    font = pygame.font.Font(None, 36)
                    text_surf = font.render("VALHALLA'S CALL", True, (255, 230, 150))
                    text_surf.set_alpha(ta)
                    cutscene_surf.blit(text_surf, (cx - text_surf.get_width() // 2, cy - 50))
                except Exception:
                    pass

        # 5) 파티클
        for p in self.cutscene_particles:
            ratio = max(0, p["life"] / p["max_life"])
            sz = int(p["size"] * ratio)
            if sz < 1:
                continue
            pa = _c(200 * ratio)
            if p["type"] == "gold":
                col = (255, 215, 80, pa)
            elif p["type"] == "rune":
                col = (180, 160, 255, pa)
            else:
                col = (255, 255, 220, pa)
            ps = pygame.Surface((sz * 2 + 2, sz * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, col, (sz + 1, sz + 1), sz)
            cutscene_surf.blit(ps, (int(p["x"]) - sz - 1, int(p["y"]) - sz - 1))

        # 6) 금빛 비네팅
        va = _c(60 * min(1.0, progress * 2))
        if va > 5:
            for i in range(3):
                pygame.draw.rect(cutscene_surf, (255, 200, 60, _c(va / (i + 1))),
                               (i * 2, i * 2, W - i * 4, H - i * 4), 2)

        # 최종 blit
        screen.blit(cutscene_surf, (0, 0))

    def draw_portal(self, screen: pygame.Surface):
        """포탈 이펙트 드로잉 (매혹 차원의 문과 동일 구조, 황금빛 고퀄리티)"""
        if self.state not in (self.PORTAL_DESCEND, self.PORTAL_ASCEND):
            return

        scale = self.portal_scale
        if scale < 0.01:
            return

        cx = int(self.portal_x)
        cy = int(self.PORTAL_Y)
        pw = int(50 * scale)    # 포탈 너비 (약간 키움)
        ph = int(70 * scale)    # 포탈 높이 (세로 타원)
        if pw < 2 or ph < 2:
            return

        _c = self._clamp
        t = self.portal_timer
        flash = getattr(self, 'portal_flash', 0.0)

        # ── 0) 플래시 (진입/퇴장 순간 화면 반짝) ──
        if flash > 0.05:
            flash_surf = pygame.Surface((760, 750), pygame.SRCALPHA)
            flash_surf.fill((255, 230, 150, _c(80 * flash)))
            screen.blit(flash_surf, (0, 0))

        # ── 0.5) 시공간 균열 (포탈 열리기 전, scale < 0.6) ──
        if scale < 0.6:
            crack_intensity = 1.0 - scale / 0.6  # 1.0 → 0.0 (포탈이 열리면서 사라짐)
            crack_surf = pygame.Surface((200, 200), pygame.SRCALPHA)
            crack_cx, crack_cy = 100, 100

            # 균열선 (중앙에서 뻗어나가는 불규칙한 갈라진 선들)
            random.seed(int(t * 2))  # 시간에 따라 약간씩 변화하되 안정적
            num_cracks = 6 + int(scale * 8)  # 점점 많아짐
            for ci in range(num_cracks):
                angle = ci * (math.pi * 2 / num_cracks) + math.sin(t * 1.5 + ci) * 0.3
                length = int(20 + 60 * scale + random.uniform(-10, 10))
                # 불규칙 지그재그 선
                pts = [(crack_cx, crack_cy)]
                segments = random.randint(3, 6)
                for seg in range(segments):
                    frac = (seg + 1) / segments
                    nx = crack_cx + int(math.cos(angle) * length * frac)
                    ny = crack_cy + int(math.sin(angle) * length * frac)
                    # 지그재그 (균열 느낌)
                    nx += random.randint(-6, 6)
                    ny += random.randint(-6, 6)
                    pts.append((nx, ny))
                if len(pts) >= 2:
                    # 글로우 (두꺼운 어두운 금색선)
                    ca = _c(120 * crack_intensity)
                    pygame.draw.lines(crack_surf, (200, 160, 40, ca), False, pts, 3)
                    # 밝은 코어선
                    ca2 = _c(200 * crack_intensity)
                    pygame.draw.lines(crack_surf, (255, 230, 140, ca2), False, pts, 1)

                    # 균열 끝에서 작은 파편 스파크
                    if seg > 1:
                        ex, ey = pts[-1]
                        spark_a = _c(150 * crack_intensity)
                        pygame.draw.circle(crack_surf, (255, 240, 160, spark_a), (ex, ey), 2)
            random.seed()  # 시드 리셋

            # 중앙 왜곡 효과 (시공간이 찢어지는 느낌의 밝은 점)
            distort_pulse = (math.sin(t * 8) + 1) * 0.5
            distort_r = max(2, int(5 + 8 * scale))
            distort_a = _c((100 + 60 * distort_pulse) * crack_intensity)
            pygame.draw.circle(crack_surf, (255, 240, 180, distort_a),
                             (crack_cx, crack_cy), distort_r)
            # 내부 흰색 점 (더 밝게)
            pygame.draw.circle(crack_surf, (255, 255, 240, _c(distort_a * 0.8)),
                             (crack_cx, crack_cy), max(1, distort_r // 2))

            # 파편 입자 (균열에서 떨어져 나오는 작은 조각들)
            for fi in range(int(8 * crack_intensity)):
                f_angle = random.uniform(0, math.pi * 2)
                f_dist = random.uniform(15, 50 + 30 * scale)
                fx = crack_cx + int(math.cos(f_angle + t * 0.5) * f_dist)
                fy = crack_cy + int(math.sin(f_angle + t * 0.5) * f_dist)
                f_sz = random.randint(1, 3)
                fa = _c(120 * crack_intensity * random.uniform(0.3, 1.0))
                if random.random() < 0.3:
                    fc = (255, 220, 100, fa)  # 금빛
                else:
                    fc = (200, 180, 140, fa)  # 돌조각 색
                pygame.draw.circle(crack_surf, fc, (fx, fy), f_sz)

            screen.blit(crack_surf, (cx - 100, cy - 100))

        # ── 1) 외곽 글로우 (3중, 넓게 퍼지는 황금 빛) ──
        for gi in range(3):
            gw = pw * (4 - gi) + 10
            gh = ph * (4 - gi) + 10
            if gw > 0 and gh > 0:
                gs = pygame.Surface((gw, gh), pygame.SRCALPHA)
                pulse = (math.sin(t * 3.5 + gi * 0.5) + 1) * 0.5
                ga = _c((20 + 15 * pulse) * scale)
                colors = [(220, 180, 50), (200, 150, 30), (180, 130, 20)]
                pygame.draw.ellipse(gs, (*colors[gi], ga), (0, 0, gw, gh))
                screen.blit(gs, (cx - gw // 2, cy - gh // 2))

        # ── 2) 검은 코어 (공허의 구멍, 깊은 어둠) ──
        core_w, core_h = int(pw * 1.6), int(ph * 1.6)
        core_surf = pygame.Surface((core_w, core_h), pygame.SRCALPHA)
        # 2중 코어 (더 깊은 느낌)
        pygame.draw.ellipse(core_surf, (5, 3, 12, 240), (0, 0, core_w, core_h))
        inner_m = max(2, int(core_w * 0.15))
        pygame.draw.ellipse(core_surf, (2, 1, 6, 250),
                           (inner_m, inner_m, core_w - inner_m * 2, core_h - inner_m * 2))
        screen.blit(core_surf, (cx - core_w // 2, cy - core_h // 2))

        # ── 3) 에너지 링 (6중 레이어, 밝은 금→어두운 금) ──
        for i in range(6):
            ring_w = pw + i * 4 + 3
            ring_h = ph + i * 4 + 3
            pulse_offset = math.sin(t * (4 + i * 0.7) + i * 1.0) * 0.3 + 0.7
            alpha = _c((180 - i * 25) * pulse_offset * scale)
            if alpha < 8:
                continue
            ring_surf = pygame.Surface((ring_w * 2 + 4, ring_h * 2 + 4), pygame.SRCALPHA)
            # 밝은 금(안쪽) → 어두운 금(바깥)
            r = min(255, 255 - i * 8)
            g = min(255, 220 - i * 20)
            b = min(255, 80 + i * 10)
            thickness = max(1, 4 - i)
            pygame.draw.ellipse(ring_surf, (r, g, b, alpha),
                                (0, 0, ring_w * 2 + 4, ring_h * 2 + 4), thickness)
            screen.blit(ring_surf, (cx - ring_w - 2, cy - ring_h - 2))

        # ── 4) 소용돌이 에너지 (20개, 타원 궤도) ──
        for j in range(20):
            angle = self.portal_angle + j * (math.pi * 2 / 20)
            r_mult = 0.5 + 0.2 * math.sin(t * 2.5 + j * 0.4)
            sx = cx + int(math.cos(angle) * pw * r_mult)
            sy = cy + int(math.sin(angle) * ph * r_mult)
            sz = max(1, int(2.5 + 2.0 * math.sin(t * 5 + j)))
            # 색상 변화: 밝은 금 → 흰금 → 주황
            phase = (j + t * 2) % 3
            if phase < 1:
                color = (255, 220, 80, 220)
            elif phase < 2:
                color = (255, 245, 180, 200)
            else:
                color = (255, 180, 50, 190)
            dot_s = pygame.Surface((sz * 2 + 2, sz * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(dot_s, color, (sz + 1, sz + 1), sz)
            # 글로우
            if sz > 1:
                pygame.draw.circle(dot_s, (255, 240, 150, 60), (sz + 1, sz + 1), sz + 2)
            screen.blit(dot_s, (sx - sz - 1, sy - sz - 1))

        # ── 5) 내부 소용돌이 (역방향 회전, 12개) ──
        for k in range(12):
            angle = -self.portal_angle * 1.8 + k * (math.pi * 2 / 12)
            r_mult = 0.25 + 0.12 * math.sin(t * 4 + k)
            ix = cx + int(math.cos(angle) * pw * r_mult)
            iy = cy + int(math.sin(angle) * ph * r_mult)
            ia = _c(140 + 80 * math.sin(t * 3.5 + k * 0.5))
            ds = pygame.Surface((6, 6), pygame.SRCALPHA)
            pygame.draw.circle(ds, (255, 235, 160, ia), (3, 3), 2)
            pygame.draw.circle(ds, (255, 250, 220, _c(ia * 0.5)), (3, 3), 3)
            screen.blit(ds, (ix - 3, iy - 3))

        # ── 6) 전기 아크 (황금 번개) ──
        for arc in self.portal_lightning:
            ratio = arc['life'] / arc['max_life']
            arc_alpha = _c(240 * ratio)
            sa = arc['angle']
            al = arc['length'] * scale
            sx = cx + int(math.cos(sa) * pw)
            sy = cy + int(math.sin(sa) * ph)
            points = [(sx, sy)]
            for seg in range(arc['segments']):
                frac = (seg + 1) / arc['segments']
                nx = sx + int(math.cos(sa) * al * frac) + random.randint(-5, 5)
                ny = sy + int(math.sin(sa) * al * frac) + random.randint(-5, 5)
                points.append((nx, ny))
            if len(points) >= 2:
                buf_w, buf_h = int(pw * 3), int(ph * 3)
                if buf_w > 4 and buf_h > 4:
                    arc_s = pygame.Surface((buf_w, buf_h), pygame.SRCALPHA)
                    ox, oy = cx - buf_w // 2, cy - buf_h // 2
                    adj = [(p[0] - ox, p[1] - oy) for p in points]
                    try:
                        # 글로우 (두꺼운)
                        pygame.draw.lines(arc_s, (255, 200, 80, _c(arc_alpha * 0.4)), False, adj, 3)
                        # 본체 (얇은)
                        pygame.draw.lines(arc_s, (255, 240, 160, arc_alpha), False, adj, 1)
                    except Exception:
                        pass
                    screen.blit(arc_s, (ox, oy))

        # ── 7) 흩어지는 파티클 ──
        for p in self.portal_particles:
            ratio = p['life'] / p['max_life']
            alpha = _c(200 * ratio)
            sz = max(1, int(p['size'] * ratio))
            c = (255, 220, 80, alpha) if int(p['angle'] * 10) % 2 == 0 else (255, 190, 50, alpha)
            ps = pygame.Surface((sz * 2 + 2, sz * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, c, (sz + 1, sz + 1), sz)
            screen.blit(ps, (int(p['x']) - sz - 1, int(p['y']) - sz - 1))

        # ── 8) 중앙 코어 빛 (빛나는 중심) ──
        core_glow_r = max(3, int(8 * scale))
        pulse = (math.sin(t * 6) + 1) * 0.5
        cg_a = _c(80 + 60 * pulse)
        cg = pygame.Surface((core_glow_r * 4, core_glow_r * 4), pygame.SRCALPHA)
        pygame.draw.circle(cg, (255, 240, 180, cg_a), (core_glow_r * 2, core_glow_r * 2), core_glow_r * 2)
        pygame.draw.circle(cg, (255, 250, 220, _c(cg_a * 1.3)), (core_glow_r * 2, core_glow_r * 2), core_glow_r)
        screen.blit(cg, (cx - core_glow_r * 2, cy - core_glow_r * 2))


# ── 싱글톤 ──────────────────────────────────────────────────────

_valhalla_state: ValhallaWarplateState = None

def get_valhalla_warplate_state() -> ValhallaWarplateState:
    global _valhalla_state
    if _valhalla_state is None:
        _valhalla_state = ValhallaWarplateState()
    return _valhalla_state
