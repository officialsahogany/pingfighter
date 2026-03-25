"""
모래 지형 시스템 (Sand Terrain)
- 각 벽면에 하나의 연속된 모래 지형이 붙어 있음
- 높이맵(height-map) 기반: 벽면을 따라 세그먼트별 돌출 깊이를 저장
- 공이 닿으면 해당 부분이 조금씩 깎여나감 (침식)
"""
from __future__ import annotations

import math
import random
import pygame


# ── 상수 ──────────────────────────────────────────────
WIDTH = 760
HEIGHT = 750

# 세그먼트 크기 (px) — 하나의 세그먼트 = 지형의 최소 해상도 단위
SEG_SIZE = 12

# 돌출 깊이 범위 (벽에서 안쪽으로 px)
DEPTH_MIN = 8
DEPTH_MAX = 45

# 침식량 (공 한 번 닿을 때 깎이는 깊이)
ERODE_AMOUNT = 30
# 침식 반경 (공 중심 기준 좌우로 몇 세그먼트까지 영향)
ERODE_RADIUS_SEGS = 6

# 모래 색상
SAND_BASE = (205, 175, 115)
SAND_DARK = (175, 148, 90)
SAND_LIGHT = (230, 205, 150)
SAND_OUTLINE = (155, 130, 80)

# 파티클 색상
SAND_PARTICLE_COLORS = [
    (230, 200, 150),
    (210, 180, 120),
    (200, 170, 100),
    (240, 215, 160),
    (180, 150, 95),
]


class SandWall:
    """한 벽면의 연속 모래 지형"""

    def __init__(self, side: str, start: int, end: int):
        """
        Args:
            side: 'left', 'right', 'top', 'bottom'
            start: 벽면을 따라 지형이 시작하는 위치 (px)
            end: 벽면을 따라 지형이 끝나는 위치 (px)
        """
        self.side = side
        self.start = start
        self.end = end
        self.num_segs = max(1, (end - start) // SEG_SIZE)

        # 높이맵: 각 세그먼트의 돌출 깊이 (0 = 벽면과 같음, 양수 = 안쪽으로 돌출)
        self.depths: list[float] = []
        self._generate_terrain()

        # 캐시: 변경 시 다시 그림
        self._dirty = True
        self._surface: pygame.Surface | None = None
        self._surf_offset: tuple[int, int] = (0, 0)

    def _generate_terrain(self) -> None:
        """랜덤한 모양의 지형 생성 — 덩어리/빈틈/뾰족함이 제각각"""
        self.depths = [0.0] * self.num_segs

        # 랜덤 개수의 덩어리(클러스터)를 배치
        num_clusters = random.randint(2, 5)
        for _ in range(num_clusters):
            # 덩어리 중심 위치, 폭, 최대 깊이를 각각 랜덤
            center = random.uniform(0.05, 0.95)  # 0~1 비율
            half_width = random.uniform(0.05, 0.25)  # 덩어리 반폭
            peak_depth = random.uniform(DEPTH_MIN + 5, DEPTH_MAX)
            # 모양 타입: 둥근형, 뾰족형, 평탄형 랜덤 선택
            shape_type = random.choice(["round", "sharp", "flat", "jagged"])

            for i in range(self.num_segs):
                t = i / max(1, self.num_segs - 1)
                dist = abs(t - center) / half_width
                if dist > 1.0:
                    continue

                if shape_type == "round":
                    # 매끄러운 반원형
                    factor = math.cos(dist * math.pi * 0.5) ** 2
                elif shape_type == "sharp":
                    # 뾰족한 삼각형
                    factor = 1.0 - dist
                elif shape_type == "flat":
                    # 꼭대기가 평평한 사다리꼴
                    factor = 1.0 if dist < 0.5 else 2.0 * (1.0 - dist)
                else:  # jagged
                    # 톱니 형태
                    factor = (1.0 - dist) * random.uniform(0.5, 1.0)

                # 작은 노이즈 추가
                factor *= random.uniform(0.8, 1.0)
                self.depths[i] = max(self.depths[i], peak_depth * factor)

        # 양 끝을 벽면에 자연스럽게 녹여줌 (페이드)
        fade_segs = max(2, self.num_segs // 8)
        for i in range(fade_segs):
            fade = i / fade_segs
            self.depths[i] *= fade
            self.depths[self.num_segs - 1 - i] *= fade

        # 세그먼트 간 약간의 스무딩 (너무 들쭉날쭉 방지, 1회만)
        smoothed = list(self.depths)
        for i in range(1, self.num_segs - 1):
            smoothed[i] = self.depths[i] * 0.6 + (self.depths[i - 1] + self.depths[i + 1]) * 0.2
        self.depths = smoothed

        self._dirty = True

    def is_empty(self) -> bool:
        """지형이 전부 깎였는지"""
        return all(d <= 0.5 for d in self.depths)

    def erode_at(self, world_pos: float, amount: float = ERODE_AMOUNT) -> float:
        """특정 월드 좌표에서 침식. 반환: 실제 깎인 총량"""
        # 월드 좌표 → 세그먼트 인덱스
        local = world_pos - self.start
        center_seg = local / SEG_SIZE
        total_eroded = 0.0

        for offset in range(-ERODE_RADIUS_SEGS, ERODE_RADIUS_SEGS + 1):
            idx = int(center_seg) + offset
            if idx < 0 or idx >= self.num_segs:
                continue
            # 중심에서 멀수록 적게 깎임
            dist_factor = 1.0 - abs(offset) / (ERODE_RADIUS_SEGS + 1)
            erode = amount * dist_factor
            old = self.depths[idx]
            self.depths[idx] = max(0, old - erode)
            total_eroded += old - self.depths[idx]

        if total_eroded > 0:
            self._dirty = True
        return total_eroded

    def get_collision_rects(self) -> list[tuple[int, pygame.Rect]]:
        """충돌 판정용 (세그먼트 인덱스, 렉트) 리스트"""
        rects = []
        for i, d in enumerate(self.depths):
            if d < 2:
                continue
            pos = self.start + i * SEG_SIZE
            di = int(d)
            if self.side == "left":
                rects.append((i, pygame.Rect(0, pos, di, SEG_SIZE)))
            elif self.side == "right":
                rects.append((i, pygame.Rect(WIDTH - di, pos, di, SEG_SIZE)))
            elif self.side == "top":
                rects.append((i, pygame.Rect(pos, 0, SEG_SIZE, di)))
            elif self.side == "bottom":
                rects.append((i, pygame.Rect(pos, HEIGHT - di, SEG_SIZE, di)))
        return rects

    def get_surface_normal(self, seg_idx: int) -> tuple[float, float]:
        """해당 세그먼트 위치의 지형 표면 법선벡터 반환 (단위벡터)

        인접 세그먼트의 깊이 차이로 표면 기울기를 구하고,
        그 기울기에 수직인 방향 = 법선.
        """
        # 인접 세그먼트 깊이
        d_prev = self.depths[seg_idx - 1] if seg_idx > 0 else 0
        d_next = self.depths[seg_idx + 1] if seg_idx < self.num_segs - 1 else 0
        d_curr = self.depths[seg_idx]

        # 기울기: 벽면을 따른 방향(접선)에서 깊이 변화
        slope = (d_next - d_prev) / (2 * SEG_SIZE)  # 깊이 변화율

        if self.side == "left":
            # 표면이 오른쪽으로 돌출 → 기본 법선: (+1, 0)
            # slope > 0이면 아래로 갈수록 더 돌출 → 법선이 위쪽으로 기울어짐
            nx, ny = 1.0, -slope
        elif self.side == "right":
            # 기본 법선: (-1, 0)
            nx, ny = -1.0, -slope
        elif self.side == "top":
            # 기본 법선: (0, +1)
            nx, ny = -slope, 1.0
        elif self.side == "bottom":
            # 기본 법선: (0, -1)
            nx, ny = -slope, -1.0
        else:
            nx, ny = 0.0, -1.0

        # 정규화
        length = math.sqrt(nx * nx + ny * ny)
        if length < 0.001:
            # 폴백: 벽 기본 법선
            if self.side == "left":
                return (1.0, 0.0)
            elif self.side == "right":
                return (-1.0, 0.0)
            elif self.side == "top":
                return (0.0, 1.0)
            else:
                return (0.0, -1.0)
        return (nx / length, ny / length)

    def _rebuild_surface(self) -> None:
        """폴리곤 서피스 재생성"""
        if self.side in ("left", "right"):
            max_d = max(max(self.depths, default=0), 1)
            sw = int(max_d) + 6
            sh = (self.end - self.start) + 6
        else:
            max_d = max(max(self.depths, default=0), 1)
            sw = (self.end - self.start) + 6
            sh = int(max_d) + 6

        surf = pygame.Surface((sw, sh), pygame.SRCALPHA)

        # 폴리곤 포인트 구성
        points = self._build_polygon(sw, sh)
        if len(points) < 3:
            self._surface = surf
            self._dirty = False
            return

        # 본체
        pygame.draw.polygon(surf, SAND_BASE, points)
        # 윤곽선
        pygame.draw.lines(surf, SAND_OUTLINE, False, points, 2)

        # 질감: 지층 줄무늬
        self._draw_texture(surf, points)

        self._surface = surf
        self._dirty = False

        # 오프셋 결정
        if self.side == "left":
            self._surf_offset = (-3, self.start - 3)
        elif self.side == "right":
            self._surf_offset = (WIDTH - int(max_d) - 3, self.start - 3)
        elif self.side == "top":
            self._surf_offset = (self.start - 3, -3)
        elif self.side == "bottom":
            self._surf_offset = (self.start - 3, HEIGHT - int(max_d) - 3)

    def _build_polygon(self, sw: int, sh: int) -> list[tuple[int, int]]:
        """연속 폴리곤 포인트 리스트 생성"""
        pad = 3
        pts: list[tuple[int, int]] = []

        if self.side == "left":
            # 위에서 아래로: 벽면(x=0) 시작 → 돌출 끝 → 벽면 복귀
            pts.append((pad, pad))  # 벽면 상단
            for i, d in enumerate(self.depths):
                y = pad + i * SEG_SIZE
                pts.append((pad + int(d), y + SEG_SIZE // 2))
            pts.append((pad, pad + self.num_segs * SEG_SIZE))  # 벽면 하단

        elif self.side == "right":
            max_d = int(max(max(self.depths, default=0), 1))
            wall_x = pad + max_d  # 벽면(오른쪽)의 서피스 내 x
            pts.append((wall_x, pad))
            for i, d in enumerate(self.depths):
                y = pad + i * SEG_SIZE
                pts.append((wall_x - int(d), y + SEG_SIZE // 2))
            pts.append((wall_x, pad + self.num_segs * SEG_SIZE))

        elif self.side == "top":
            pts.append((pad, pad))  # 벽면 좌단
            for i, d in enumerate(self.depths):
                x = pad + i * SEG_SIZE
                pts.append((x + SEG_SIZE // 2, pad + int(d)))
            pts.append((pad + self.num_segs * SEG_SIZE, pad))  # 벽면 우단

        elif self.side == "bottom":
            max_d = int(max(max(self.depths, default=0), 1))
            wall_y = pad + max_d
            pts.append((pad, wall_y))
            for i, d in enumerate(self.depths):
                x = pad + i * SEG_SIZE
                pts.append((x + SEG_SIZE // 2, wall_y - int(d)))
            pts.append((pad + self.num_segs * SEG_SIZE, wall_y))

        return pts

    def _draw_texture(self, surf: pygame.Surface, points: list[tuple[int, int]]) -> None:
        """지형 위에 질감 그리기"""
        if len(points) < 3:
            return
        min_x = min(p[0] for p in points)
        max_x = max(p[0] for p in points)
        min_y = min(p[1] for p in points)
        max_y = max(p[1] for p in points)

        # 밝은 점 (모래알)
        for _ in range(min(25, max(5, (max_x - min_x) * (max_y - min_y) // 200))):
            dx = random.randint(min_x + 1, max(min_x + 2, max_x - 1))
            dy = random.randint(min_y + 1, max(min_y + 2, max_y - 1))
            r = random.randint(1, 2)
            c = (*SAND_LIGHT, random.randint(100, 180))
            pygame.draw.circle(surf, c, (dx, dy), r)

        # 어두운 점
        for _ in range(min(15, max(3, (max_x - min_x) * (max_y - min_y) // 350))):
            dx = random.randint(min_x + 1, max(min_x + 2, max_x - 1))
            dy = random.randint(min_y + 1, max(min_y + 2, max_y - 1))
            r = random.randint(1, 2)
            c = (*SAND_DARK, random.randint(80, 140))
            pygame.draw.circle(surf, c, (dx, dy), r)

    def draw(self, screen: pygame.Surface) -> None:
        """화면에 그리기"""
        if self.is_empty():
            return
        if self._dirty or self._surface is None:
            self._rebuild_surface()
        if self._surface:
            screen.blit(self._surface, self._surf_offset)


class SandTerrain:
    """4면 모래 지형 총괄 관리"""

    def __init__(self):
        self.walls: list[SandWall] = []
        self.particles: list[dict] = []
        self._generate()

    def _generate(self) -> None:
        """4면 지형 생성"""
        self.walls.clear()
        # 좌벽 (Y: 60 ~ 690)
        self.walls.append(SandWall("left", 60, 690))
        # 우벽
        self.walls.append(SandWall("right", 60, 690))
        # 상단 (X: 40 ~ 720)
        self.walls.append(SandWall("top", 40, 720))
        # 하단
        self.walls.append(SandWall("bottom", 40, 720))

    def check_ball_collision(self, ball_rect: pygame.Rect, ball_vel: list[float]) -> bool:
        """공과 지형 충돌 → 표면 각도로 반사 + 침식 + 파티클. 반환: 충돌 여부"""
        hit = False
        for wall in self.walls:
            if wall.is_empty():
                continue
            for seg_idx, r in wall.get_collision_rects():
                if ball_rect.colliderect(r):
                    # 1) 표면 법선 계산
                    nx, ny = wall.get_surface_normal(seg_idx)

                    # 2) 법선 기준 반사: v' = v - 2(v·n)n
                    dot = ball_vel[0] * nx + ball_vel[1] * ny
                    if dot < 0:  # 표면을 향해 다가오는 경우만 반사
                        ball_vel[0] -= 2 * dot * nx
                        ball_vel[1] -= 2 * dot * ny
                        # 약간 감속 (모래에 부딪힌 느낌)
                        ball_vel[0] *= 0.95
                        ball_vel[1] *= 0.95

                    # 3) 공 위치를 지형 밖으로 밀어냄 (관통 방지)
                    self._push_ball_out(wall, seg_idx, ball_rect)

                    # 4) 침식
                    if wall.side in ("left", "right"):
                        world_pos = float(ball_rect.centery)
                    else:
                        world_pos = float(ball_rect.centerx)
                    eroded = wall.erode_at(world_pos)

                    # 5) 파티클
                    if eroded > 0:
                        self._spawn_particles(wall.side, ball_rect.centerx, ball_rect.centery, eroded)

                    hit = True
                    break  # 이 벽에서는 한 곳만 처리
        return hit

    @staticmethod
    def _push_ball_out(wall: SandWall, seg_idx: int, ball_rect: pygame.Rect) -> None:
        """공을 지형 표면 바깥으로 밀어냄"""
        d = wall.depths[seg_idx]
        if d < 1:
            return
        di = int(d)
        if wall.side == "left":
            if ball_rect.left < di:
                ball_rect.left = di + 1
        elif wall.side == "right":
            edge = WIDTH - di
            if ball_rect.right > edge:
                ball_rect.right = edge - 1
        elif wall.side == "top":
            if ball_rect.top < di:
                ball_rect.top = di + 1
        elif wall.side == "bottom":
            edge = HEIGHT - di
            if ball_rect.bottom > edge:
                ball_rect.bottom = edge - 1

    def _spawn_particles(self, side: str, bx: int, by: int, eroded: float) -> None:
        """침식 시 파티클 생성"""
        count = max(3, min(10, int(eroded / 3)))
        for _ in range(count):
            # 벽 반대 방향으로 날림
            if side == "left":
                vx = random.uniform(1.0, 3.5)
                vy = random.uniform(-1.5, 1.5)
            elif side == "right":
                vx = random.uniform(-3.5, -1.0)
                vy = random.uniform(-1.5, 1.5)
            elif side == "top":
                vx = random.uniform(-1.5, 1.5)
                vy = random.uniform(1.0, 3.5)
            else:
                vx = random.uniform(-1.5, 1.5)
                vy = random.uniform(-3.5, -1.0)

            self.particles.append({
                "x": float(bx + random.randint(-6, 6)),
                "y": float(by + random.randint(-6, 6)),
                "vx": vx,
                "vy": vy,
                "size": random.randint(2, 4),
                "color": random.choice(SAND_PARTICLE_COLORS),
                "life": random.randint(18, 35),
                "max_life": 35,
                "gravity": 0.12,
            })

    def update_particles(self) -> None:
        """파티클 업데이트"""
        for p in self.particles[:]:
            p["x"] += p["vx"]
            p["y"] += p["vy"]
            p["vy"] += p["gravity"]
            p["vx"] *= 0.95
            p["life"] -= 1
            if p["life"] <= 0:
                self.particles.remove(p)

    def draw(self, screen: pygame.Surface) -> None:
        """전체 지형 + 파티클 그리기"""
        for wall in self.walls:
            wall.draw(screen)
        # 파티클
        for p in self.particles:
            alpha = int(255 * (p["life"] / p["max_life"]))
            size = max(1, int(p["size"] * (p["life"] / p["max_life"])))
            if alpha > 20:
                s = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(s, (*p["color"], alpha), (size, size), size)
                screen.blit(s, (int(p["x"]) - size, int(p["y"]) - size))

    def is_all_empty(self) -> bool:
        """모든 벽면이 깎였는지"""
        return all(w.is_empty() for w in self.walls)


# ── 하위 호환용 래퍼 함수 (pingfighter.py 연동) ──────

def spawn_sand_obstacles(*_args, **_kwargs) -> SandTerrain:
    """새 모래 지형 생성 (SandTerrain 인스턴스 반환)"""
    return SandTerrain()


def check_sand_ball_collision(
    terrain: SandTerrain | list,
    ball_rect: pygame.Rect,
    ball_vel: list[float],
) -> bool:
    """공-지형 충돌. 반환: 충돌 여부"""
    if isinstance(terrain, SandTerrain):
        return terrain.check_ball_collision(ball_rect, ball_vel)
    return False


def draw_sand_obstacles(screen: pygame.Surface, terrain: SandTerrain | list) -> None:
    """지형 그리기"""
    if isinstance(terrain, SandTerrain):
        terrain.update_particles()
        terrain.draw(screen)


# 더 이상 사용 안 함 — 호환용 빈 함수
def create_sand_particles(*_a, **_kw) -> list:
    return []

def update_sand_particles(*_a, **_kw) -> None:
    pass

def draw_sand_particles(*_a, **_kw) -> None:
    pass
