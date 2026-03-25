"""
모래 장애물 시스템 (Sand Obstacles)
- 라운드 시작 시 벽면에 붙어서 생성 (동굴 고드름/종유석 느낌)
- 공에 닿으면 부서지며 사라짐
- 벽에서 안쪽으로 튀어나온 불규칙한 지형 형태
"""
from __future__ import annotations

import math
import random
import pygame


# ── 상수 ──────────────────────────────────────────────
WIDTH = 760
HEIGHT = 750

# 돌출 크기 범위 (벽에서 안쪽으로 얼마나 튀어나오는지)
PROTRUDE_MIN = 25
PROTRUDE_MAX = 55
# 벽면을 따라 차지하는 폭/높이
SPAN_MIN = 30
SPAN_MAX = 70

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


def _generate_wall_shape(wall_side: str, span: int, protrude: int) -> list[tuple[int, int]]:
    """벽에 붙은 지형 폴리곤 생성 (고드름/종유석 형태)

    wall_side: 'left', 'right', 'top', 'bottom'
    span: 벽면을 따라 차지하는 길이
    protrude: 벽에서 안쪽으로 튀어나오는 깊이

    반환: 서피스 로컬 좌표 (0,0 기준) 폴리곤 포인트 리스트
    """
    points = []

    if wall_side == "left":
        # 좌벽: x=0이 벽면, 오른쪽으로 돌출
        # 벽면 상단 시작
        points.append((0, 0))
        # 울퉁불퉁한 돌출 (위→아래로)
        num_bumps = random.randint(3, 5)
        for i in range(num_bumps):
            t = (i + 1) / (num_bumps + 1)
            y = int(span * t)
            # 중앙부가 가장 많이 튀어나오는 형태
            center_factor = 1.0 - abs(t - 0.5) * 2  # 0→1→0
            depth = int(protrude * (0.4 + 0.6 * center_factor) * random.uniform(0.7, 1.0))
            points.append((depth, y + random.randint(-3, 3)))
        # 벽면 하단 끝
        points.append((0, span))

    elif wall_side == "right":
        # 우벽: x=protrude가 벽면(오른쪽), 왼쪽으로 돌출
        points.append((protrude, 0))
        num_bumps = random.randint(3, 5)
        for i in range(num_bumps):
            t = (i + 1) / (num_bumps + 1)
            y = int(span * t)
            center_factor = 1.0 - abs(t - 0.5) * 2
            depth = int(protrude * (0.4 + 0.6 * center_factor) * random.uniform(0.7, 1.0))
            points.append((protrude - depth, y + random.randint(-3, 3)))
        points.append((protrude, span))

    elif wall_side == "top":
        # 상단벽: y=0이 벽면, 아래로 돌출 (고드름)
        points.append((0, 0))
        num_bumps = random.randint(3, 5)
        for i in range(num_bumps):
            t = (i + 1) / (num_bumps + 1)
            x = int(span * t)
            center_factor = 1.0 - abs(t - 0.5) * 2
            depth = int(protrude * (0.4 + 0.6 * center_factor) * random.uniform(0.7, 1.0))
            points.append((x + random.randint(-3, 3), depth))
        points.append((span, 0))

    elif wall_side == "bottom":
        # 하단벽: y=protrude가 벽면(아래쪽), 위로 돌출 (석순)
        points.append((0, protrude))
        num_bumps = random.randint(3, 5)
        for i in range(num_bumps):
            t = (i + 1) / (num_bumps + 1)
            x = int(span * t)
            center_factor = 1.0 - abs(t - 0.5) * 2
            depth = int(protrude * (0.4 + 0.6 * center_factor) * random.uniform(0.7, 1.0))
            points.append((x + random.randint(-3, 3), protrude - depth))
        points.append((span, protrude))

    return points


def _render_sand_surface(
    wall_side: str, span: int, protrude: int, shape: list[tuple[int, int]], color: tuple
) -> pygame.Surface:
    """모래 지형 서피스 렌더링"""
    pad = 3
    if wall_side in ("left", "right"):
        sw, sh = protrude + pad * 2, span + pad * 2
    else:
        sw, sh = span + pad * 2, protrude + pad * 2

    surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
    shifted = [(px + pad, py + pad) for px, py in shape]

    if len(shifted) < 3:
        return surf

    # 그림자
    shadow_off = 2
    shadow_pts = [(px + shadow_off, py + shadow_off) for px, py in shifted]
    pygame.draw.polygon(surf, (0, 0, 0, 35), shadow_pts)

    # 본체
    pygame.draw.polygon(surf, color, shifted)
    # 윤곽선 (약간 어두운 색)
    outline = tuple(max(0, c - 40) for c in color)
    pygame.draw.polygon(surf, outline, shifted, 2)

    # 모래 질감 - 밝은 점
    # 폴리곤 바운딩박스 내에서만 점 찍기
    min_x = min(p[0] for p in shifted)
    max_x = max(p[0] for p in shifted)
    min_y = min(p[1] for p in shifted)
    max_y = max(p[1] for p in shifted)
    for _ in range(random.randint(4, 9)):
        dx = random.randint(min_x + 2, max(min_x + 3, max_x - 2))
        dy = random.randint(min_y + 2, max(min_y + 3, max_y - 2))
        r = random.randint(1, 3)
        highlight = tuple(min(255, c + random.randint(25, 55)) for c in color) + (160,)
        pygame.draw.circle(surf, highlight, (dx, dy), r)
    # 어두운 점
    for _ in range(random.randint(2, 5)):
        dx = random.randint(min_x + 2, max(min_x + 3, max_x - 2))
        dy = random.randint(min_y + 2, max(min_y + 3, max_y - 2))
        r = random.randint(1, 2)
        dark = tuple(max(0, c - random.randint(35, 65)) for c in color) + (130,)
        pygame.draw.circle(surf, dark, (dx, dy), r)
    # 가로 줄무늬 (지층 느낌)
    for _ in range(random.randint(1, 3)):
        ly = random.randint(min_y + 4, max(min_y + 5, max_y - 4))
        lx1 = random.randint(min_x + 2, max(min_x + 3, (min_x + max_x) // 2))
        lx2 = random.randint((min_x + max_x) // 2, max((min_x + max_x) // 2 + 1, max_x - 2))
        line_color = tuple(max(0, c - random.randint(15, 30)) for c in color) + (100,)
        pygame.draw.line(surf, line_color, (lx1, ly), (lx2, ly), 1)

    return surf


def _create_wall_sand(wall_side: str, pos_along_wall: int) -> dict:
    """벽면에 붙은 모래 장애물 하나 생성

    Args:
        wall_side: 'left', 'right', 'top', 'bottom'
        pos_along_wall: 벽면을 따라 어느 위치에 배치할지 (px)
    """
    span = random.randint(SPAN_MIN, SPAN_MAX)
    protrude = random.randint(PROTRUDE_MIN, PROTRUDE_MAX)
    color = random.choice(SAND_COLORS)
    shape = _generate_wall_shape(wall_side, span, protrude)
    surface = _render_sand_surface(wall_side, span, protrude, shape, color)
    pad = 3

    # 월드 좌표 결정 (벽면에 딱 붙도록)
    if wall_side == "left":
        x = -pad  # 좌벽에 밀착
        y = pos_along_wall - pad
        rect_x, rect_y = 0, pos_along_wall
        rect_w, rect_h = protrude, span
    elif wall_side == "right":
        x = WIDTH - protrude - pad  # 우벽에 밀착
        y = pos_along_wall - pad
        rect_x, rect_y = WIDTH - protrude, pos_along_wall
        rect_w, rect_h = protrude, span
    elif wall_side == "top":
        x = pos_along_wall - pad
        y = -pad  # 상단벽에 밀착
        rect_x, rect_y = pos_along_wall, 0
        rect_w, rect_h = span, protrude
    else:  # bottom
        x = pos_along_wall - pad
        y = HEIGHT - protrude - pad  # 하단벽에 밀착
        rect_x, rect_y = pos_along_wall, HEIGHT - protrude
        rect_w, rect_h = span, protrude

    return {
        "x": x,
        "y": y,
        "rect": pygame.Rect(rect_x, rect_y, rect_w, rect_h),
        "wall_side": wall_side,
        "span": span,
        "protrude": protrude,
        "color": color,
        "shape": shape,
        "surface": surface,
        "alive": True,
    }


def spawn_sand_obstacles(count_range: tuple[int, int] = (5, 10)) -> list[dict]:
    """라운드 시작 시 벽면에 붙은 모래 장애물 배치

    Args:
        count_range: (최소, 최대) 생성 개수
    Returns:
        생성된 모래 장애물 리스트
    """
    obstacles: list[dict] = []
    count = random.randint(*count_range)

    # 각 벽면별 배치 가능 범위 (패들 영역 피해서)
    wall_ranges = {
        "left": (80, 670),    # Y: 패들 위 ~ 패들 아래 사이
        "right": (80, 670),
        "top": (60, 700),     # X: 좌우 여백 제외
        "bottom": (60, 700),
    }
    wall_sides = list(wall_ranges.keys())

    for _ in range(count):
        side = random.choice(wall_sides)
        range_min, range_max = wall_ranges[side]

        # 겹침 방지 시도 (최대 15회)
        for _attempt in range(15):
            pos = random.randint(range_min, range_max)
            sand = _create_wall_sand(side, pos)

            # 기존 장애물과 겹치는지 확인
            overlap = False
            for obs in obstacles:
                if obs["rect"].inflate(8, 8).colliderect(sand["rect"]):
                    overlap = True
                    break
            if not overlap:
                obstacles.append(sand)
                break

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
    """모래 파괴 시 파티클 생성 - 벽 반대쪽으로 흩어짐"""
    particles = []
    rect = sand["rect"]
    cx = rect.centerx
    cy = rect.centery
    side = sand["wall_side"]

    for _ in range(random.randint(8, 14)):
        # 벽 반대 방향으로 파티클이 날아가도록
        if side == "left":
            vx = random.uniform(1.5, 4.5)
            vy = random.uniform(-2.0, 2.0)
        elif side == "right":
            vx = random.uniform(-4.5, -1.5)
            vy = random.uniform(-2.0, 2.0)
        elif side == "top":
            vx = random.uniform(-2.0, 2.0)
            vy = random.uniform(1.5, 4.5)
        else:  # bottom
            vx = random.uniform(-2.0, 2.0)
            vy = random.uniform(-4.5, -1.5)

        size = random.randint(2, 5)
        particles.append({
            "x": float(cx + random.randint(-rect.width // 3, rect.width // 3)),
            "y": float(cy + random.randint(-rect.height // 3, rect.height // 3)),
            "vx": vx,
            "vy": vy,
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
        screen.blit(sand["surface"], (sand["x"], sand["y"]))


def draw_sand_particles(screen: pygame.Surface, particles: list[dict]) -> None:
    """모래 파티클 그리기"""
    for p in particles:
        alpha = int(255 * (p["life"] / p["max_life"]))
        color = p["color"]
        size = max(1, int(p["size"] * (p["life"] / p["max_life"])))
        if alpha > 20:
            s = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, (*color, alpha), (size, size), size)
            screen.blit(s, (int(p["x"]) - size, int(p["y"]) - size))
