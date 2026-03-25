"""
모래 장애물 시스템 (Sand Obstacles)
- 라운드 시작 시 벽 주변에 랜덤 생성
- 공에 닿으면 부서지며 사라짐
- 불규칙한 모래 형태 (정사각형이 아닌 유기적 모양)
"""
from __future__ import annotations

import math
import random
import pygame


# ── 상수 ──────────────────────────────────────────────
WIDTH = 760
HEIGHT = 750
BOSS_Y = 25
PLAYER_Y = 710

# 모래 블록 크기 범위
SAND_MIN_W = 28
SAND_MAX_W = 50
SAND_MIN_H = 18
SAND_MAX_H = 36

# 벽 근처 스폰 거리 (벽으로부터 최대 px)
WALL_MARGIN = 60

# 모래 색상 팔레트
SAND_COLORS = [
    (210, 180, 120),  # 기본 모래
    (194, 164, 108),  # 어두운 모래
    (225, 200, 140),  # 밝은 모래
    (200, 170, 110),  # 중간 모래
    (180, 155, 100),  # 짙은 모래
]

# 파티클 색상
SAND_PARTICLE_COLORS = [
    (230, 200, 150),
    (210, 180, 120),
    (200, 170, 100),
    (240, 215, 160),
    (180, 150, 95),
]


def _generate_sand_shape(w: int, h: int) -> list[tuple[int, int]]:
    """불규칙한 모래 블록 폴리곤 좌표 생성 (원점 기준)"""
    points = []
    num_points = random.randint(7, 11)
    for i in range(num_points):
        angle = (2 * math.pi * i) / num_points + random.uniform(-0.3, 0.3)
        # 타원형 기반 + 랜덤 울퉁불퉁
        rx = (w / 2) * random.uniform(0.7, 1.0)
        ry = (h / 2) * random.uniform(0.7, 1.0)
        px = int(w / 2 + rx * math.cos(angle))
        py = int(h / 2 + ry * math.sin(angle))
        px = max(0, min(w, px))
        py = max(0, min(h, py))
        points.append((px, py))
    return points


def create_sand_obstacle(x: int, y: int) -> dict:
    """단일 모래 장애물 생성"""
    w = random.randint(SAND_MIN_W, SAND_MAX_W)
    h = random.randint(SAND_MIN_H, SAND_MAX_H)
    color = random.choice(SAND_COLORS)
    shape = _generate_sand_shape(w, h)

    # 미리 렌더링된 서피스 생성
    surf = pygame.Surface((w + 4, h + 4), pygame.SRCALPHA)
    # 그림자 (약간 아래로)
    shadow_pts = [(px + 2, py + 2) for px, py in shape]
    pygame.draw.polygon(surf, (0, 0, 0, 40), shadow_pts)
    # 본체
    shifted = [(px + 2, py + 2) for px, py in shape]
    pygame.draw.polygon(surf, color, shifted)
    # 하이라이트 점들 (모래 질감)
    for _ in range(random.randint(3, 7)):
        dx = random.randint(4, w - 2)
        dy = random.randint(4, h - 2)
        r = random.randint(1, 3)
        highlight = tuple(min(255, c + random.randint(20, 50)) for c in color) + (180,)
        pygame.draw.circle(surf, highlight, (dx + 2, dy + 2), r)
    # 어두운 점들
    for _ in range(random.randint(2, 5)):
        dx = random.randint(4, w - 2)
        dy = random.randint(4, h - 2)
        r = random.randint(1, 2)
        dark = tuple(max(0, c - random.randint(30, 60)) for c in color) + (150,)
        pygame.draw.circle(surf, dark, (dx + 2, dy + 2), r)

    return {
        "x": x,
        "y": y,
        "w": w,
        "h": h,
        "rect": pygame.Rect(x, y, w, h),
        "color": color,
        "shape": shape,
        "surface": surf,
        "alive": True,
        "fade_alpha": 255,  # 파괴 시 페이드아웃용
    }


def spawn_sand_obstacles(count_range: tuple[int, int] = (4, 8)) -> list[dict]:
    """라운드 시작 시 벽 주변에 모래 장애물 배치

    Args:
        count_range: (최소, 최대) 생성 개수
    Returns:
        생성된 모래 장애물 리스트
    """
    obstacles: list[dict] = []
    count = random.randint(*count_range)

    # 스폰 가능 영역 정의 (벽 주변 4곳)
    zones = []

    # 좌벽 근처 (x: 0~WALL_MARGIN, y: 120~630 중립지대)
    zones.append(("left", 0, WALL_MARGIN, 100, 650))
    # 우벽 근처
    zones.append(("right", WIDTH - WALL_MARGIN, WIDTH, 100, 650))
    # 보스쪽 벽 근처 (상단, y: 50~120)
    zones.append(("top", 60, WIDTH - 60, 50, 130))
    # 플레이어쪽 벽 근처 (하단, y: 630~700)
    zones.append(("bottom", 60, WIDTH - 60, 640, 700))

    for _ in range(count):
        zone = random.choice(zones)
        _name, x_min, x_max, y_min, y_max = zone

        # 크기 먼저 결정
        w = random.randint(SAND_MIN_W, SAND_MAX_W)
        h = random.randint(SAND_MIN_H, SAND_MAX_H)

        # 겹침 방지 시도 (최대 10회)
        for _attempt in range(10):
            x = random.randint(x_min, max(x_min, x_max - w))
            y = random.randint(y_min, max(y_min, y_max - h))
            new_rect = pygame.Rect(x, y, w, h)

            # 기존 장애물과 겹치는지 확인
            overlap = False
            for obs in obstacles:
                if obs["rect"].inflate(10, 10).colliderect(new_rect):
                    overlap = True
                    break
            if not overlap:
                break
        else:
            continue  # 10번 시도해도 겹치면 스킵

        obstacles.append(create_sand_obstacle(x, y))

    return obstacles


def check_sand_ball_collision(
    sand_list: list[dict],
    ball_rect: pygame.Rect,
    ball_vel: list[float],
) -> list[dict]:
    """공과 모래 장애물 충돌 체크

    Returns:
        파괴된 모래 장애물 리스트 (파티클 생성용)
    """
    destroyed = []
    for sand in sand_list:
        if not sand["alive"]:
            continue
        if ball_rect.colliderect(sand["rect"]):
            sand["alive"] = False
            destroyed.append(sand)

            # 공 속도 살짝 감소 (모래에 닿았으므로)
            ball_vel[0] *= 0.95
            ball_vel[1] *= 0.95
    return destroyed


def create_sand_particles(sand: dict) -> list[dict]:
    """모래 파괴 시 파티클 생성"""
    particles = []
    cx = sand["x"] + sand["w"] // 2
    cy = sand["y"] + sand["h"] // 2

    for _ in range(random.randint(8, 14)):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(1.5, 4.0)
        size = random.randint(2, 5)
        particles.append({
            "x": cx + random.randint(-sand["w"] // 3, sand["w"] // 3),
            "y": cy + random.randint(-sand["h"] // 3, sand["h"] // 3),
            "vx": math.cos(angle) * speed,
            "vy": math.sin(angle) * speed + random.uniform(-1, 0.5),
            "size": size,
            "color": random.choice(SAND_PARTICLE_COLORS),
            "life": random.randint(20, 40),
            "max_life": 40,
            "gravity": 0.15,
        })
    return particles


def update_sand_particles(particles: list[dict]) -> None:
    """모래 파티클 업데이트 (매 프레임)"""
    for p in particles[:]:
        p["x"] += p["vx"]
        p["y"] += p["vy"]
        p["vy"] += p["gravity"]
        p["vx"] *= 0.96  # 공기 저항
        p["life"] -= 1
        if p["life"] <= 0:
            particles.remove(p)


def draw_sand_obstacles(screen: pygame.Surface, sand_list: list[dict]) -> None:
    """모래 장애물 그리기"""
    for sand in sand_list:
        if not sand["alive"]:
            continue
        screen.blit(sand["surface"], (sand["x"] - 2, sand["y"] - 2))


def draw_sand_particles(screen: pygame.Surface, particles: list[dict]) -> None:
    """모래 파티클 그리기"""
    for p in particles:
        alpha = int(255 * (p["life"] / p["max_life"]))
        color = p["color"]
        size = max(1, int(p["size"] * (p["life"] / p["max_life"])))
        # 간단한 원형 파티클
        if alpha > 20:
            s = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, (*color, alpha), (size, size), size)
            screen.blit(s, (int(p["x"]) - size, int(p["y"]) - size))
