"""
발할라의 전갑 (Valhalla's Warplate) - 전설 아이템 효과 모듈

상의(갑옷) 부위 전설 아이템.
플레이어가 공을 타격 시 일정 확률(롤옵션 8~15%)로 투기장 영웅을 호위무사로 소환.
소환된 영웅은 보유 스킬 2개 중 1개를 랜덤 발동 후 즉시 사라짐.
"""

import random
import math
import pygame

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

    def __init__(self):
        self.active = False           # 장착 중인지
        self.summon_chance = 0.10     # 소환 확률 (롤옵션에서 갱신)
        self.enhancement_bonus_pct = 0

        # 소환 연출용
        self.summoning = False        # 현재 소환 연출 중
        self.summon_timer = 0.0       # 소환 연출 경과 시간
        self.summon_duration = 1.5    # 소환 연출 전체 시간 (초)
        self.summoned_hero = None     # 소환된 영웅 정보
        self.summoned_skill_idx = 0   # 발동할 스킬 인덱스 (0 or 1)
        self.skill_fired = False      # 스킬 발동 완료 여부
        self.summon_x = 0             # 소환 위치 X
        self.summon_y = 0             # 소환 위치 Y

        # 소환 이펙트 파티클
        self.particles = []
        self.flash_alpha = 0

    def activate(self, summon_chance: float):
        """장착 시 활성화"""
        self.active = True
        self.summon_chance = summon_chance

    def deactivate(self):
        """해제 / 초기화"""
        self.active = False
        self.summoning = False
        self.summon_timer = 0.0
        self.summoned_hero = None
        self.skill_fired = False
        self.particles.clear()

    def reset(self):
        """게임 종료 시 완전 초기화"""
        self.active = False
        self.summoning = False
        self.summon_timer = 0.0
        self.summoned_hero = None
        self.summoned_skill_idx = 0
        self.skill_fired = False
        self.summon_x = 0
        self.summon_y = 0
        self.particles.clear()
        self.flash_alpha = 0
        self.enhancement_bonus_pct = 0

    def try_summon(self, ball_x: int, ball_y: int) -> bool:
        """공 타격 시 소환 시도. 성공하면 True 반환."""
        if not self.active or self.summoning:
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

        # 소환 성공!
        self.summoning = True
        self.summon_timer = 0.0
        self.skill_fired = False
        self.summoned_hero = random.choice(VALHALLA_HEROES)
        self.summoned_skill_idx = random.randint(0, 1)
        self.summon_x = ball_x
        self.summon_y = max(200, min(ball_y, 550))  # 화면 중앙부에 소환
        self.flash_alpha = 255

        # 소환 파티클 생성 (발할라 금빛 + 룬 문양)
        self._spawn_summon_particles()
        return True

    def _spawn_summon_particles(self):
        """소환 시 파티클 생성"""
        cx, cy = self.summon_x, self.summon_y
        for _ in range(20):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(40, 120)
            self.particles.append({
                "x": cx, "y": cy,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 30,
                "life": random.uniform(0.5, 1.2),
                "max_life": random.uniform(0.5, 1.2),
                "size": random.uniform(2, 5),
                "color_type": random.choice(["gold", "rune", "light"]),
            })

    def update(self, dt: float) -> dict:
        """매 프레임 업데이트. 스킬 발동 시점이면 정보 반환."""
        result = {"fire_skill": False, "hero_id": None, "skill_idx": 0, "done": False}

        if not self.summoning:
            return result

        self.summon_timer += dt

        # 플래시 감쇠
        if self.flash_alpha > 0:
            self.flash_alpha = max(0, self.flash_alpha - dt * 600)

        # 파티클 업데이트
        for p in self.particles:
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt
            p["vy"] += 50 * dt  # 약간의 중력
            p["life"] -= dt
        self.particles = [p for p in self.particles if p["life"] > 0]

        # 0.5초 시점: 스킬 발동
        if not self.skill_fired and self.summon_timer >= 0.5:
            self.skill_fired = True
            result["fire_skill"] = True
            result["hero_id"] = self.summoned_hero["id"]
            result["skill_idx"] = self.summoned_skill_idx

        # 1.5초: 소환 종료
        if self.summon_timer >= self.summon_duration:
            self.summoning = False
            self.summoned_hero = None
            self.summon_timer = 0.0
            result["done"] = True

        return result

    def draw(self, screen: pygame.Surface):
        """소환 연출 드로잉"""
        if not self.summoning or not self.summoned_hero:
            return

        cx, cy = self.summon_x, self.summon_y
        progress = min(1.0, self.summon_timer / self.summon_duration)
        hero_color = self.summoned_hero["color"]

        # 1) 플래시 (소환 순간)
        if self.flash_alpha > 10:
            flash_surf = pygame.Surface((760, 750), pygame.SRCALPHA)
            flash_surf.fill((255, 220, 100, int(self.flash_alpha * 0.3)))
            screen.blit(flash_surf, (0, 0))

        # 2) 소환진 (바닥 원형 룬)
        rune_alpha = int(255 * (1.0 - progress))
        rune_radius = int(40 + 20 * math.sin(self.summon_timer * 4))
        rune_surf = pygame.Surface((rune_radius * 2 + 4, rune_radius * 2 + 4), pygame.SRCALPHA)
        pygame.draw.circle(rune_surf, (255, 200, 80, rune_alpha), (rune_radius + 2, rune_radius + 2), rune_radius, 2)
        # 내부 룬 십자
        cross_len = rune_radius - 6
        center = rune_radius + 2
        pygame.draw.line(rune_surf, (255, 220, 120, rune_alpha // 2), (center - cross_len, center), (center + cross_len, center), 1)
        pygame.draw.line(rune_surf, (255, 220, 120, rune_alpha // 2), (center, center - cross_len), (center, center + cross_len), 1)
        screen.blit(rune_surf, (cx - rune_radius - 2, cy + 20 - rune_radius - 2))

        # 3) 영웅 실루엣 (등장 → 사라짐)
        if progress < 0.3:
            # 등장: 아래에서 올라옴
            appear = progress / 0.3
            hero_y = cy + int(30 * (1.0 - appear))
            alpha = int(255 * appear)
        elif progress < 0.7:
            # 체류
            hero_y = cy
            alpha = 255
        else:
            # 퇴장: 위로 사라짐
            fade = (progress - 0.7) / 0.3
            hero_y = cy - int(20 * fade)
            alpha = int(255 * (1.0 - fade))

        # 영웅 몸체 (간단한 실루엣)
        hero_surf = pygame.Surface((50, 60), pygame.SRCALPHA)
        body_color = (*hero_color, min(255, alpha))
        # 머리
        pygame.draw.circle(hero_surf, body_color, (25, 12), 10)
        # 몸통
        pygame.draw.rect(hero_surf, body_color, (15, 22, 20, 25), border_radius=4)
        # 다리
        pygame.draw.rect(hero_surf, body_color, (17, 47, 7, 12), border_radius=2)
        pygame.draw.rect(hero_surf, body_color, (27, 47, 7, 12), border_radius=2)
        # 갑옷 하이라이트
        highlight = (min(255, hero_color[0] + 80), min(255, hero_color[1] + 80), min(255, hero_color[2] + 80), alpha // 2)
        pygame.draw.rect(hero_surf, highlight, (18, 24, 14, 6), border_radius=2)

        screen.blit(hero_surf, (cx - 25, hero_y - 30))

        # 영웅 이름
        if alpha > 50:
            try:
                font = pygame.font.Font(None, 18)
                name_surf = font.render(self.summoned_hero["name"], True, (255, 255, 255))
                name_surf.set_alpha(alpha)
                screen.blit(name_surf, (cx - name_surf.get_width() // 2, hero_y - 50))
            except Exception:
                pass

        # 4) 파티클
        for p in self.particles:
            ratio = max(0, p["life"] / p["max_life"])
            size = int(p["size"] * ratio)
            if size < 1:
                continue
            if p["color_type"] == "gold":
                color = (255, 215, 80, int(200 * ratio))
            elif p["color_type"] == "rune":
                color = (180, 140, 255, int(180 * ratio))
            else:
                color = (255, 255, 200, int(150 * ratio))
            ps = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, color, (size, size), size)
            screen.blit(ps, (int(p["x"]) - size, int(p["y"]) - size))

        # 5) 스킬 발동 순간 이펙트
        if self.skill_fired and self.summon_timer < 0.8:
            burst_progress = (self.summon_timer - 0.5) / 0.3
            if 0 <= burst_progress <= 1.0:
                burst_r = int(30 + 50 * burst_progress)
                burst_alpha = int(200 * (1.0 - burst_progress))
                burst_surf = pygame.Surface((burst_r * 2 + 4, burst_r * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(burst_surf, (*hero_color, burst_alpha), (burst_r + 2, burst_r + 2), burst_r, 3)
                screen.blit(burst_surf, (cx - burst_r - 2, cy - burst_r - 2))


# ── 싱글톤 ──────────────────────────────────────────────────────

_valhalla_state: ValhallaWarplateState = None

def get_valhalla_warplate_state() -> ValhallaWarplateState:
    global _valhalla_state
    if _valhalla_state is None:
        _valhalla_state = ValhallaWarplateState()
    return _valhalla_state
