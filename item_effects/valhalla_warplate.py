"""
발할라의 전갑 (Valhalla's Warplate) - 전설 아이템 효과 모듈

상의(갑옷) 부위 전설 아이템.
플레이어가 공을 타격 시 일정 확률(롤옵션 8~15%)로 투기장 영웅을 호위무사로 소환.
소환된 영웅은 보유 스킬 2개 중 1개를 랜덤 발동 후 퇴장 모션으로 사라짐.

실제 InGameBodyguard 시스템을 활용하여 인장과 동일한 스킬 발동.
"""

import random
import math
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
    SUMMONED = 2       # 소환됨, 스킬 발동 대기
    SKILL_ACTIVE = 3   # 스킬 발동 중
    EXITING = 4        # 퇴장 모션 재생 중

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
        self._pending_hero = None     # 컷신 중 대기하는 영웅 데이터
        self._pending_skill_idx = 0   # 컷신 중 대기하는 스킬 인덱스

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

    def _start_exit(self):
        """퇴장 모션 시작 (exiting phase 트리거)"""
        if self._bodyguard_ref and self._bodyguard_ref.active and self._bodyguard_ref._guard_system:
            gs = self._bodyguard_ref._guard_system
            gs._exit_start_x_bottom = gs.x_bottom
            gs._exit_start_y_bottom = float(gs.y_bottom)
            gs.phase_bottom = "exiting"
            gs.anim_timer_bottom = 0.0
            self.state = self.EXITING
            self.summoning = True
        else:
            self._force_dismiss()

    def _clear_state(self):
        """내부 상태 초기화"""
        self._bodyguard_ref = None
        self.summoning = False
        self.state = self.IDLE
        self.summon_timer = 0.0
        self.post_skill_timer = 0.0
        self.summoned_hero_name = ""
        self._pending_hero = None
        self._pending_skill_idx = 0
        self.cutscene_timer = 0.0
        self.cutscene_particles.clear()

    def try_summon(self) -> bool:
        """공 타격 시 소환 시도. 성공하면 True (컷신 시작)."""
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
            self.state = self.SUMMONED
            self.summon_timer = 0.0
            self.post_skill_timer = 0.0
            self._pending_hero = None
            print(f"⚔ 발할라의 전갑: {hero['name']} 소환 완료! (스킬 {skill_idx + 1}번)")

        except Exception as e:
            print(f"[WARN] 발할라 전갑 소환 실패: {e}")
            self._clear_state()

    def update(self, dt: float):
        """매 프레임 업데이트 - 상태 머신 기반 관리"""
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

        # ── SUMMONED: 스킬 발동 대기 ──
        if self.state == self.SUMMONED:
            if gs:
                phase = getattr(gs, 'phase_bottom', 'patrolling')
                if phase not in ('patrolling', 'patrol_entering', None):
                    self.state = self.SKILL_ACTIVE
                    print(f"⚔ 발할라의 전갑: {self.summoned_hero_name} 스킬 발동!")
            if self.summon_timer >= self.max_summon_time:
                self._start_exit()

        # ── SKILL_ACTIVE: 스킬 시전 완료 대기 → 퇴장 모션 시작 ──
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
                            self._start_exit()
            else:
                self._clear_state()

        # ── EXITING: 퇴장 모션 완료 대기 ──
        elif self.state == self.EXITING:
            if gs:
                phase = getattr(gs, 'phase_bottom', None)
                if phase != "exiting":
                    if bg and bg.active:
                        bg.dismiss_keep_skills()
                    self._clear_state()
                    return
            else:
                self._clear_state()
                return
            if self.summon_timer >= self.max_summon_time + 2.0:
                self._force_dismiss()

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


# ── 싱글톤 ──────────────────────────────────────────────────────

_valhalla_state: ValhallaWarplateState = None

def get_valhalla_warplate_state() -> ValhallaWarplateState:
    global _valhalla_state
    if _valhalla_state is None:
        _valhalla_state = ValhallaWarplateState()
    return _valhalla_state
