"""
소울버스트 (Soul Burst) - 무릎 부위 패시브 아이템
대쉬 토큰이 없을 때 (게이지 < 1) 대쉬 사용 시 스페셜 게이지를 대신 소모하여 풀 대쉬 발동.
스페셜 게이지 소모량은 롤 옵션으로 130~200 범위에서 결정됨.
"""

import math
import random

# 디버그 플래그
DEBUG_SOUL_BURST = False

# 이펙트 파티클 리스트 (모듈 레벨)
_burst_particles = []
_burst_shockwaves = []


class SoulBurst:
    def __init__(self):
        self.active = False
        self.obtained = False
        self.gauge_cost = 165  # 기본값 (롤옵션으로 130~200 사이 결정)

    def activate(self):
        """아이템 획득 시 활성화"""
        self.active = True
        self.obtained = True
        if DEBUG_SOUL_BURST:
            print(f"[SOUL_BURST] 활성화! 게이지 소모량: {self.gauge_cost}")

    def deactivate(self):
        """게임 종료/리셋 시 비활성화"""
        self.active = False
        self.obtained = False
        self.gauge_cost = 165

    def set_gauge_cost(self, cost):
        """롤 옵션에서 결정된 게이지 소모량 설정"""
        self.gauge_cost = cost
        if DEBUG_SOUL_BURST:
            print(f"[SOUL_BURST] 게이지 소모량 설정: {cost}")

    def can_soul_dash(self, special_gauge):
        """스페셜 게이지로 대쉬할 수 있는지 확인"""
        if not self.active:
            return False
        return special_gauge >= self.gauge_cost

    def get_gauge_cost(self):
        """현재 게이지 소모량 반환"""
        return self.gauge_cost

    def get_available_dashes(self, special_gauge):
        """현재 스페셜 게이지로 가능한 추가 대쉬 횟수"""
        if not self.active or self.gauge_cost <= 0:
            return 0
        return int(special_gauge // self.gauge_cost)

    def update(self, current_stage=None):
        pass

    def draw_effects(self, screen, **kwargs):
        pass


def trigger_soul_burst_effect(cx, cy, direction):
    """소울버스트 대쉬 발동 시 보라색 에너지 방출 이펙트 생성.

    Args:
        cx, cy: 플레이어 중심 좌표
        direction: 대쉬 방향 (-1: 왼쪽, 1: 오른쪽)
    """
    global _burst_particles, _burst_shockwaves

    # 충격파 (중심에서 빠르게 퍼지는 원형)
    _burst_shockwaves.append({
        "x": cx, "y": cy,
        "radius": 5, "max_radius": 45,
        "alpha": 220, "speed": 4.5,
    })

    # 보라색 에너지 파티클 (방사형 + 대쉬 방향 편향)
    for _ in range(18):
        angle = random.uniform(0, math.pi * 2)
        # 대쉬 방향으로 편향
        bias = direction * random.uniform(1.0, 3.0)
        speed = random.uniform(2.5, 6.0)
        vx = math.cos(angle) * speed + bias
        vy = math.sin(angle) * speed
        size = random.uniform(2.0, 5.0)
        life = random.randint(10, 20)
        _burst_particles.append({
            "x": cx + random.uniform(-5, 5),
            "y": cy + random.uniform(-5, 5),
            "vx": vx, "vy": vy,
            "size": size, "life": life, "max_life": life,
        })


def update_soul_burst_effects():
    """매 프레임 호출 - 파티클/충격파 업데이트."""
    global _burst_particles, _burst_shockwaves

    # 파티클 업데이트
    for p in _burst_particles:
        p["x"] += p["vx"]
        p["y"] += p["vy"]
        p["vx"] *= 0.88
        p["vy"] *= 0.88
        p["size"] *= 0.94
        p["life"] -= 1
    _burst_particles = [p for p in _burst_particles if p["life"] > 0]

    # 충격파 업데이트
    for sw in _burst_shockwaves:
        sw["radius"] += sw["speed"]
        sw["alpha"] = max(0, int(220 * (1 - sw["radius"] / sw["max_radius"])))
    _burst_shockwaves = [sw for sw in _burst_shockwaves if sw["radius"] < sw["max_radius"]]


def draw_soul_burst_effects(screen):
    """매 프레임 호출 - 이펙트 렌더링."""
    import pygame

    # 충격파 그리기 (보라색 링)
    for sw in _burst_shockwaves:
        if sw["alpha"] <= 0:
            continue
        r = int(sw["radius"])
        alpha = sw["alpha"]
        # 외곽 링
        ring_surf = pygame.Surface((r * 2 + 4, r * 2 + 4), pygame.SRCALPHA)
        pygame.draw.circle(ring_surf, (180, 100, 255, alpha), (r + 2, r + 2), r, max(2, r // 6))
        # 내부 글로우
        if r > 10:
            pygame.draw.circle(ring_surf, (220, 160, 255, alpha // 3), (r + 2, r + 2), r - 2, max(1, r // 10))
        screen.blit(ring_surf, (int(sw["x"]) - r - 2, int(sw["y"]) - r - 2))

    # 파티클 그리기
    for p in _burst_particles:
        if p["life"] <= 0:
            continue
        t = p["life"] / p["max_life"]
        alpha = int(255 * t)
        size = max(1, int(p["size"]))
        # 코어: 밝은 보라
        core_color = (220, 160, 255, alpha)
        # 외곽: 짙은 보라
        glow_color = (140, 60, 220, alpha // 2)
        ps = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        center = size * 2
        pygame.draw.circle(ps, glow_color, (center, center), size * 2)
        pygame.draw.circle(ps, core_color, (center, center), size)
        screen.blit(ps, (int(p["x"]) - center, int(p["y"]) - center))


def clear_soul_burst_effects():
    """이펙트 초기화."""
    global _burst_particles, _burst_shockwaves
    _burst_particles.clear()
    _burst_shockwaves.clear()


# 싱글턴 인스턴스
_soul_burst_instance = None


def get_soul_burst_instance():
    global _soul_burst_instance
    if _soul_burst_instance is None:
        _soul_burst_instance = SoulBurst()
    return _soul_burst_instance


def activate_soul_burst():
    sb = get_soul_burst_instance()
    sb.activate()
    return True


def deactivate_soul_burst():
    sb = get_soul_burst_instance()
    sb.deactivate()
    clear_soul_burst_effects()
