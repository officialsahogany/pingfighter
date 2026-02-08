"""인게임 호위무사 시스템

투기장에서 우승 후 등용한 영웅이 다음 스테이지에서 일정 시간마다
화면 옆에서 등장하여 보스를 공격하는 시스템.
"""
import random
import math

try:
    import pygame
    import pygame.freetype
except ImportError:
    pygame = None


# ============================================================================
# 상수
# ============================================================================
GAME_AREA_X = 80           # 게임 영역 시작 X
GAME_AREA_WIDTH = 600      # 게임 영역 너비
GAME_AREA_CENTER_X = GAME_AREA_X + GAME_AREA_WIDTH // 2  # = 380

COOLDOWN_MIN = 25.0        # 호위무사 등장 최소 쿨다운 (초)
COOLDOWN_MAX = 35.0        # 호위무사 등장 최대 쿨다운 (초)
INITIAL_DELAY_MIN = 12.0   # 첫 등장까지 최소 대기 (초)
INITIAL_DELAY_MAX = 18.0   # 첫 등장까지 최대 대기 (초)

ENTER_DURATION = 0.6       # 등장 애니메이션 시간 (초)
CAST_DURATION = 1.0        # 스킬 시전 시간 (초)
EXIT_DURATION = 0.5        # 퇴장 애니메이션 시간 (초)

# 호위무사 등장 Y 위치 (보스 바로 아래쪽)
GUARD_Y = 130
# 호위무사 등장 목표 X (게임 영역 내)
GUARD_TARGET_X_LEFT = GAME_AREA_X + 80
GUARD_TARGET_X_RIGHT = GAME_AREA_X + GAME_AREA_WIDTH - 80

# 보스 스턴 효과 (호위무사 공격 시)
BOSS_STUN_FRAMES = 45      # 보스 경직 프레임 (0.75초)
BOSS_KNOCKBACK_VEL = 10.0  # 보스 넉백 속도

# 호위무사 크기
GUARD_WIDTH = 50
GUARD_HEIGHT = 50

# 영웅별 한국어 이름 및 스킬명
HERO_DISPLAY_INFO = {
    "mugen":    {"name": "무겐",    "skill": "달빛베기",     "color": (120, 60, 180)},
    "kraken":   {"name": "크라켄",  "skill": "촉수휘감기",   "color": (40, 120, 140)},
    "chronos":  {"name": "크로노스","skill": "중력제어",     "color": (200, 170, 100)},
    "onimaru":  {"name": "오니마루","skill": "지옥의 불꽃",  "color": (200, 50, 70)},
    "maria":    {"name": "연화",    "skill": "인형조종",     "color": (180, 100, 150)},
    "ignis":    {"name": "이그니스","skill": "드래곤 브레스", "color": (220, 100, 40)},
    "gear":     {"name": "기어",    "skill": "스팀배리어",   "color": (140, 100, 60)},
    "kurokage": {"name": "쿠로카게","skill": "그림자분신",   "color": (50, 50, 70)},
}


# ============================================================================
# 인게임 호위무사 클래스
# ============================================================================
class InGameBodyguard:
    """스테이지 진행 중 플레이어를 돕는 호위무사 시스템"""

    def __init__(self):
        self.hero_data = None           # 등용한 영웅 정보 dict
        self.active = False             # 시스템 활성화 여부
        self.cooldown = 0.0             # 다음 등장까지 남은 시간 (초)

        # 애니메이션 상태
        self.phase = None               # None / "entering" / "casting" / "exiting"
        self.anim_timer = 0.0
        self.x = 0.0                    # 현재 X 위치
        self.y = GUARD_Y                # 현재 Y 위치
        self.side = "left"              # 등장 방향
        self.target_x = 0.0             # 목표 X 위치
        self.start_x = 0.0              # 시작 X 위치

        # 스킬 이펙트
        self.skill_name = ""            # 현재 시전 중인 스킬명
        self.cast_particles = []        # 스킬 이펙트 파티클
        self.boss_effect_applied = False  # 이번 등장에서 보스 효과 적용 여부

        # 말풍선
        self.speech_text = ""
        self.speech_timer = 0.0

        # 렌더러 참조
        self._hero_paddle_renderer = None

    def setup(self, hero_data: dict):
        """호위무사 설정

        Args:
            hero_data: {'id': str, 'name': str, 'color': tuple, 'title': str}
        """
        self.hero_data = hero_data
        self.active = True
        self.cooldown = random.uniform(INITIAL_DELAY_MIN, INITIAL_DELAY_MAX)
        self.phase = None
        self.boss_effect_applied = False
        self.cast_particles = []

        # 패들 렌더러 초기화
        try:
            from downtown.hero_paddles import get_hero_paddle_renderer
            self._hero_paddle_renderer = get_hero_paddle_renderer()
        except Exception:
            self._hero_paddle_renderer = None

        print(f"[Bodyguard] 호위무사 설정: {hero_data.get('name', '???')} (id={hero_data.get('id')})")

    def reset(self):
        """호위무사 시스템 리셋"""
        self.hero_data = None
        self.active = False
        self.cooldown = 0.0
        self.phase = None
        self.anim_timer = 0.0
        self.cast_particles = []
        self.boss_effect_applied = False

    def update(self, dt: float) -> dict:
        """매 프레임 업데이트

        Args:
            dt: 델타 타임 (초)

        Returns:
            dict: 보스에 적용할 효과 (비어있으면 없음)
                  {'stun_frames': int, 'knockback_vel': float, 'knockback_dir': int}
        """
        if not self.active or not self.hero_data:
            return {}

        boss_effect = {}

        # 말풍선 타이머
        if self.speech_timer > 0:
            self.speech_timer -= dt

        # 파티클 업데이트
        self._update_particles(dt)

        if self.phase is None:
            # 대기 중 - 쿨다운 감소
            self.cooldown -= dt
            if self.cooldown <= 0:
                self._trigger_entrance()
        elif self.phase == "entering":
            self._update_entering(dt)
        elif self.phase == "casting":
            boss_effect = self._update_casting(dt)
        elif self.phase == "exiting":
            self._update_exiting(dt)

        return boss_effect

    def _trigger_entrance(self):
        """호위무사 등장 트리거"""
        self.side = random.choice(["left", "right"])
        if self.side == "left":
            self.start_x = GAME_AREA_X - 60
            self.target_x = GUARD_TARGET_X_LEFT
        else:
            self.start_x = GAME_AREA_X + GAME_AREA_WIDTH + 60
            self.target_x = GUARD_TARGET_X_RIGHT

        self.x = self.start_x
        self.phase = "entering"
        self.anim_timer = 0.0
        self.boss_effect_applied = False

        # 스킬명 결정
        hero_id = self.hero_data.get("id", "")
        info = HERO_DISPLAY_INFO.get(hero_id, {})
        self.skill_name = info.get("skill", "공격")

        print(f"[Bodyguard] {self.hero_data.get('name')} 등장! 방향={self.side}")

    def _update_entering(self, dt):
        """등장 애니메이션"""
        self.anim_timer += dt
        progress = min(self.anim_timer / ENTER_DURATION, 1.0)
        # 이징 함수 (감속)
        eased = 1 - (1 - progress) ** 3
        self.x = self.start_x + (self.target_x - self.start_x) * eased

        if progress >= 1.0:
            self.phase = "casting"
            self.anim_timer = 0.0
            # 말풍선 표시
            self.speech_text = self.skill_name
            self.speech_timer = CAST_DURATION

    def _update_casting(self, dt) -> dict:
        """스킬 시전 애니메이션"""
        self.anim_timer += dt
        boss_effect = {}

        # 스킬 시전 중간 지점에서 보스 효과 적용
        if not self.boss_effect_applied and self.anim_timer >= CAST_DURATION * 0.4:
            self.boss_effect_applied = True
            # 스킬 이펙트 파티클 생성
            self._create_skill_particles()
            # 보스에게 효과 전달
            knockback_dir = 1 if random.random() > 0.5 else -1
            boss_effect = {
                "stun_frames": BOSS_STUN_FRAMES,
                "knockback_vel": BOSS_KNOCKBACK_VEL * knockback_dir,
            }

        if self.anim_timer >= CAST_DURATION:
            self.phase = "exiting"
            self.anim_timer = 0.0

        return boss_effect

    def _update_exiting(self, dt):
        """퇴장 애니메이션"""
        self.anim_timer += dt
        progress = min(self.anim_timer / EXIT_DURATION, 1.0)
        # 이징 함수 (가속)
        eased = progress ** 2
        exit_x = self.start_x  # 등장한 쪽으로 퇴장
        self.x = self.target_x + (exit_x - self.target_x) * eased

        if progress >= 1.0:
            self.phase = None
            self.cooldown = random.uniform(COOLDOWN_MIN, COOLDOWN_MAX)
            self.cast_particles = []
            print(f"[Bodyguard] {self.hero_data.get('name')} 퇴장 완료. 다음 등장: {self.cooldown:.1f}초")

    def _create_skill_particles(self):
        """스킬 이펙트 파티클 생성"""
        hero_id = self.hero_data.get("id", "")
        color = HERO_DISPLAY_INFO.get(hero_id, {}).get("color", (200, 200, 200))

        # 스킬 발사 이펙트 (호위무사 위치에서 위쪽으로)
        for _ in range(15):
            angle = random.uniform(-math.pi * 0.4, -math.pi * 0.6)  # 위쪽 방향
            speed = random.uniform(2, 6)
            self.cast_particles.append({
                "x": self.x,
                "y": self.y,
                "vx": math.cos(angle) * speed + random.uniform(-1, 1),
                "vy": -abs(speed * 1.5) + random.uniform(-1, 0),  # 위로 이동
                "life": random.uniform(0.4, 0.8),
                "max_life": 0.8,
                "size": random.uniform(3, 7),
                "color": color,
            })

        # 충격파 이펙트 (보스 근처)
        boss_y = 45  # 보스 패들 중심 Y
        for _ in range(10):
            self.cast_particles.append({
                "x": GAME_AREA_CENTER_X + random.uniform(-80, 80),
                "y": boss_y + random.uniform(-15, 15),
                "vx": random.uniform(-3, 3),
                "vy": random.uniform(-2, 2),
                "life": random.uniform(0.3, 0.6),
                "max_life": 0.6,
                "size": random.uniform(4, 8),
                "color": (255, 255, 200),  # 충격파는 흰-노란색
            })

    def _update_particles(self, dt):
        """파티클 업데이트"""
        for p in self.cast_particles:
            p["x"] += p["vx"]
            p["y"] += p["vy"]
            p["vy"] += 0.3  # 중력
            p["life"] -= dt
        self.cast_particles = [p for p in self.cast_particles if p["life"] > 0]

    # ====================================================================
    # 렌더링
    # ====================================================================
    def draw(self, screen):
        """호위무사 캐릭터 및 이펙트 그리기"""
        if not self.active or not self.hero_data or self.phase is None:
            # 파티클만 그리기 (퇴장 후에도 잔여 파티클)
            self._draw_particles(screen)
            return

        hero_id = self.hero_data.get("id", "")
        color = HERO_DISPLAY_INFO.get(hero_id, {}).get("color", (150, 150, 150))

        # 호위무사 캐릭터 그리기
        draw_x = int(self.x) - GUARD_WIDTH // 2
        draw_y = int(self.y) - GUARD_HEIGHT // 2

        if self._hero_paddle_renderer:
            try:
                self._hero_paddle_renderer.draw_hero_paddle(
                    screen, hero_id,
                    draw_x, draw_y,
                    GUARD_WIDTH, GUARD_HEIGHT,
                    facing="down",
                    color=color,
                    scale_mode="icon",
                )
            except Exception:
                # 폴백: 단순 사각형
                self._draw_simple_guard(screen, draw_x, draw_y, color)
        else:
            self._draw_simple_guard(screen, draw_x, draw_y, color)

        # 등장 시 발광 효과
        if self.phase == "entering":
            alpha = int(180 * (1 - self.anim_timer / ENTER_DURATION))
            glow_surf = pygame.Surface((GUARD_WIDTH + 20, GUARD_HEIGHT + 20), pygame.SRCALPHA)
            pygame.draw.ellipse(glow_surf, (*color, alpha),
                                (0, 0, GUARD_WIDTH + 20, GUARD_HEIGHT + 20))
            screen.blit(glow_surf, (draw_x - 10, draw_y - 10))

        # 스킬 시전 이펙트
        if self.phase == "casting":
            self._draw_cast_effect(screen, color)

        # 파티클
        self._draw_particles(screen)

        # 말풍선
        if self.speech_timer > 0 and self.speech_text:
            self._draw_speech_bubble(screen)

    def _draw_simple_guard(self, screen, x, y, color):
        """폴백 호위무사 그리기 (hero_paddles 없을 때)"""
        # 몸체
        pygame.draw.rect(screen, color, (x, y, GUARD_WIDTH, GUARD_HEIGHT), border_radius=6)
        # 테두리
        pygame.draw.rect(screen, (255, 255, 255), (x, y, GUARD_WIDTH, GUARD_HEIGHT), 2, border_radius=6)
        # 눈
        eye_y = y + GUARD_HEIGHT // 3
        pygame.draw.circle(screen, (255, 255, 255), (x + GUARD_WIDTH // 3, eye_y), 4)
        pygame.draw.circle(screen, (255, 255, 255), (x + 2 * GUARD_WIDTH // 3, eye_y), 4)
        pygame.draw.circle(screen, (0, 0, 0), (x + GUARD_WIDTH // 3, eye_y), 2)
        pygame.draw.circle(screen, (0, 0, 0), (x + 2 * GUARD_WIDTH // 3, eye_y), 2)

    def _draw_cast_effect(self, screen, color):
        """스킬 시전 시각 효과"""
        progress = self.anim_timer / CAST_DURATION
        if progress < 0.4:
            # 차징 이펙트 - 호위무사 주변 회전 입자
            charge_p = progress / 0.4
            num_orbs = 6
            radius = 25 + charge_p * 10
            for i in range(num_orbs):
                angle = (charge_p * math.pi * 4) + (i * 2 * math.pi / num_orbs)
                ox = self.x + math.cos(angle) * radius
                oy = self.y + math.sin(angle) * radius
                orb_alpha = int(200 * charge_p)
                orb_surf = pygame.Surface((8, 8), pygame.SRCALPHA)
                pygame.draw.circle(orb_surf, (*color, orb_alpha), (4, 4), 4)
                screen.blit(orb_surf, (int(ox) - 4, int(oy) - 4))
        elif progress < 0.7:
            # 발사 이펙트 - 호위무사에서 보스 방향으로 빔
            beam_p = (progress - 0.4) / 0.3
            alpha = int(180 * (1 - beam_p))
            beam_width = max(2, int(6 * (1 - beam_p)))
            beam_surf = pygame.Surface((beam_width * 2, int(self.y)), pygame.SRCALPHA)
            pygame.draw.rect(beam_surf, (*color, alpha), (0, 0, beam_width * 2, int(self.y)))
            screen.blit(beam_surf, (int(self.x) - beam_width, 0))

    def _draw_particles(self, screen):
        """파티클 그리기"""
        for p in self.cast_particles:
            alpha = int(255 * (p["life"] / p["max_life"]))
            size = max(1, int(p["size"] * (p["life"] / p["max_life"])))
            p_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(p_surf, (*p["color"], alpha), (size, size), size)
            screen.blit(p_surf, (int(p["x"]) - size, int(p["y"]) - size))

    def _draw_speech_bubble(self, screen):
        """말풍선 그리기"""
        try:
            font = pygame.freetype.SysFont("malgungothic", 12)
            if font is None:
                return
        except Exception:
            return

        text_surf, text_rect = font.render(self.speech_text, (255, 255, 255))
        bw = text_rect.width + 16
        bh = text_rect.height + 10
        bx = int(self.x) - bw // 2
        by = int(self.y) - GUARD_HEIGHT // 2 - bh - 8

        # 배경
        alpha = min(230, int(255 * (self.speech_timer / CAST_DURATION)))
        bubble_surf = pygame.Surface((bw, bh), pygame.SRCALPHA)
        pygame.draw.rect(bubble_surf, (0, 0, 0, alpha), (0, 0, bw, bh), border_radius=5)
        pygame.draw.rect(bubble_surf, (255, 255, 255, alpha), (0, 0, bw, bh), 1, border_radius=5)
        screen.blit(bubble_surf, (bx, by))
        screen.blit(text_surf, (bx + 8, by + 5))

    def draw_pillar_icon(self, screen, pillar_x: int, pillar_y: int,
                         pillar_width: int, game_scale: float = 1.0):
        """왼쪽 필러에 호위무사 아이콘 표시

        Args:
            screen: 화면 Surface
            pillar_x: 필러 시작 X (스케일 적용 후)
            pillar_y: 아이콘 Y 위치 (스케일 적용 후)
            pillar_width: 필러 너비 (스케일 적용 후)
            game_scale: 게임 스케일 팩터
        """
        if not self.active or not self.hero_data:
            return

        hero_id = self.hero_data.get("id", "")
        hero_name = self.hero_data.get("name", "???")
        color = HERO_DISPLAY_INFO.get(hero_id, {}).get("color", (150, 150, 150))

        icon_size = int(36 * game_scale)
        icon_x = pillar_x + (pillar_width - icon_size) // 2
        icon_y = pillar_y

        # 아이콘 배경
        bg_rect = pygame.Rect(icon_x - 4, icon_y - 4, icon_size + 8, icon_size + 8)
        pygame.draw.rect(screen, (30, 30, 50), bg_rect, border_radius=6)
        pygame.draw.rect(screen, color, bg_rect, 2, border_radius=6)

        # 영웅 아이콘
        if self._hero_paddle_renderer:
            try:
                self._hero_paddle_renderer.draw_hero_paddle(
                    screen, hero_id,
                    icon_x, icon_y,
                    icon_size, icon_size,
                    facing="down",
                    color=color,
                    scale_mode="icon",
                )
            except Exception:
                pygame.draw.rect(screen, color, (icon_x, icon_y, icon_size, icon_size), border_radius=4)
        else:
            pygame.draw.rect(screen, color, (icon_x, icon_y, icon_size, icon_size), border_radius=4)

        # 쿨다운 오버레이
        if self.phase is None and self.cooldown > 0:
            cd_ratio = min(self.cooldown / COOLDOWN_MIN, 1.0)
            overlay_h = int(icon_size * cd_ratio)
            if overlay_h > 0:
                cd_surf = pygame.Surface((icon_size, overlay_h), pygame.SRCALPHA)
                cd_surf.fill((0, 0, 0, 140))
                screen.blit(cd_surf, (icon_x, icon_y + icon_size - overlay_h))
        elif self.phase is not None:
            # 활성 상태 - 밝은 테두리
            glow_rect = pygame.Rect(icon_x - 6, icon_y - 6, icon_size + 12, icon_size + 12)
            pulse = abs(math.sin(pygame.time.get_ticks() / 200.0))
            glow_alpha = int(100 + 100 * pulse)
            glow_surf = pygame.Surface((glow_rect.width, glow_rect.height), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*color, glow_alpha), (0, 0, glow_rect.width, glow_rect.height),
                             3, border_radius=8)
            screen.blit(glow_surf, glow_rect.topleft)

        # 라벨 "호위무사"
        try:
            label_font = pygame.freetype.SysFont("malgungothic", max(8, int(9 * game_scale)))
            if label_font:
                label_surf, label_rect = label_font.render("호위무사", (200, 200, 220))
                label_x = pillar_x + (pillar_width - label_rect.width) // 2
                screen.blit(label_surf, (label_x, icon_y + icon_size + 10))

                name_surf, name_rect = label_font.render(hero_name, color)
                name_x = pillar_x + (pillar_width - name_rect.width) // 2
                screen.blit(name_surf, (name_x, icon_y + icon_size + 24))
        except Exception:
            pass


# ============================================================================
# 싱글턴 인스턴스
# ============================================================================
_bodyguard_instance = None


def get_bodyguard() -> InGameBodyguard:
    """인게임 호위무사 싱글턴 인스턴스"""
    global _bodyguard_instance
    if _bodyguard_instance is None:
        _bodyguard_instance = InGameBodyguard()
    return _bodyguard_instance
