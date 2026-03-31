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

# 패들 이동 침식 (걷기)
WALK_ERODE_AMOUNT = 0.8       # 프레임당 깎이는 깊이 (매우 소량)
WALK_ERODE_RADIUS_SEGS = 3    # 패들 중심 기준 좌우 세그먼트 수

# 패들 대쉬 침식
DASH_ERODE_AMOUNT = 6.0       # 대쉬 시 세그먼트당 깎이는 깊이
DASH_ERODE_RADIUS_SEGS = 2    # 대쉬 경로 좌우 세그먼트 수

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
        # 녹아내림(dissolve) 연출 상태
        self.dissolving = False
        self._dissolve_timer = 0
        self._dissolve_duration = 90  # 1.5초 (60fps 기준)
        self._dissolve_alpha = 255  # 전체 투명도
        self._dissolve_particle_timer = 0
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
        if self.dissolving and self._dissolve_alpha < 255:
            # 녹아내리는 중: 투명도 적용하여 그리기
            for wall in self.walls:
                if wall.is_empty():
                    continue
                if wall._dirty or wall._surface is None:
                    wall._rebuild_surface()
                if wall._surface:
                    faded = wall._surface.copy()
                    faded.set_alpha(self._dissolve_alpha)
                    screen.blit(faded, wall._surf_offset)
        else:
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

    def erode_area(self, cx: float, cy: float, radius: float) -> float:
        """원형 범위 내 모래 지형 침식 (폭발용). 반환: 총 깎인 양

        Args:
            cx, cy: 폭발 중심 좌표
            radius: 폭발 반경 (px)
        """
        total_eroded = 0.0
        radius_sq = radius * radius

        for wall in self.walls:
            if wall.is_empty():
                continue

            wall_eroded = 0.0
            for i in range(wall.num_segs):
                if wall.depths[i] < 1:
                    continue

                # 세그먼트 중심의 월드 좌표
                seg_center = wall.start + i * SEG_SIZE + SEG_SIZE // 2
                if wall.side == "left":
                    sx = wall.depths[i] * 0.5
                    sy = float(seg_center)
                elif wall.side == "right":
                    sx = WIDTH - wall.depths[i] * 0.5
                    sy = float(seg_center)
                elif wall.side == "top":
                    sx = float(seg_center)
                    sy = wall.depths[i] * 0.5
                else:  # bottom
                    sx = float(seg_center)
                    sy = HEIGHT - wall.depths[i] * 0.5

                dx = cx - sx
                dy = cy - sy
                dist_sq = dx * dx + dy * dy
                if dist_sq > radius_sq:
                    continue

                dist = math.sqrt(dist_sq)
                # 중심에 가까울수록 많이 깎임 (중심=100%, 가장자리=0%)
                factor = 1.0 - (dist / radius)
                erode_val = wall.depths[i] * factor
                old = wall.depths[i]
                wall.depths[i] = max(0.0, old - erode_val)
                wall_eroded += old - wall.depths[i]

            if wall_eroded > 0:
                wall._dirty = True
                total_eroded += wall_eroded

        # 폭발 파티클 생성
        if total_eroded > 0:
            count = max(5, min(20, int(total_eroded / 5)))
            for _ in range(count):
                angle = random.uniform(0, 2 * math.pi)
                speed = random.uniform(2.0, 5.0)
                self.particles.append({
                    "x": cx + random.uniform(-radius * 0.3, radius * 0.3),
                    "y": cy + random.uniform(-radius * 0.3, radius * 0.3),
                    "vx": math.cos(angle) * speed,
                    "vy": math.sin(angle) * speed,
                    "size": random.randint(2, 5),
                    "color": random.choice(SAND_PARTICLE_COLORS),
                    "life": random.randint(20, 40),
                    "max_life": 40,
                    "gravity": 0.15,
                })

        return total_eroded

    def start_dissolve(self) -> None:
        """녹아내림 연출 시작"""
        if self.dissolving:
            return
        self.dissolving = True
        self._dissolve_timer = 0
        self._dissolve_alpha = 255
        self._dissolve_particle_timer = 0

    def update_dissolve(self) -> bool:
        """녹아내림 연출 업데이트. 반환: True면 완전히 사라짐 (제거 가능)"""
        if not self.dissolving:
            return False

        self._dissolve_timer += 1
        progress = min(1.0, self._dissolve_timer / self._dissolve_duration)

        # 투명도 감소 (ease-in: 처음엔 천천히, 나중엔 빠르게)
        ease = progress * progress
        self._dissolve_alpha = max(0, int(255 * (1.0 - ease)))

        # 모래 깊이를 점진적으로 줄임 (사르르 녹는 효과)
        shrink_rate = 0.06 + 0.12 * progress  # 갈수록 빠르게
        for wall in self.walls:
            changed = False
            for i in range(wall.num_segs):
                if wall.depths[i] > 0:
                    wall.depths[i] = max(0, wall.depths[i] - wall.depths[i] * shrink_rate)
                    if wall.depths[i] < 0.5:
                        wall.depths[i] = 0
                    changed = True
            if changed:
                wall._dirty = True

        # 주기적으로 모래 파티클 흩날림 (녹아내리는 모래 알갱이)
        self._dissolve_particle_timer += 1
        if self._dissolve_particle_timer >= 3:  # 3프레임마다
            self._dissolve_particle_timer = 0
            self._spawn_dissolve_particles(progress)

        # 완료 판정
        if self._dissolve_timer >= self._dissolve_duration:
            self.dissolving = False
            return True
        return False

    def _spawn_dissolve_particles(self, progress: float) -> None:
        """녹아내릴 때 모래 알갱이 파티클 생성"""
        # 진행도에 따라 파티클 수 감소 (초반에 많이, 후반에 적게)
        count_per_wall = max(1, int(4 * (1.0 - progress)))

        for wall in self.walls:
            if wall.is_empty():
                continue
            for _ in range(count_per_wall):
                # 남아있는 세그먼트 중 랜덤 선택
                valid = [(i, d) for i, d in enumerate(wall.depths) if d > 1]
                if not valid:
                    continue
                idx, depth = random.choice(valid)
                seg_center = wall.start + idx * SEG_SIZE + SEG_SIZE // 2

                # 세그먼트 위치 → 월드 좌표
                if wall.side == "left":
                    px = depth * 0.5
                    py = float(seg_center)
                    vx = random.uniform(0.3, 1.5)
                    vy = random.uniform(0.5, 2.0)
                elif wall.side == "right":
                    px = WIDTH - depth * 0.5
                    py = float(seg_center)
                    vx = random.uniform(-1.5, -0.3)
                    vy = random.uniform(0.5, 2.0)
                elif wall.side == "top":
                    px = float(seg_center)
                    py = depth * 0.5
                    vx = random.uniform(-1.0, 1.0)
                    vy = random.uniform(0.5, 2.5)
                else:  # bottom
                    px = float(seg_center)
                    py = HEIGHT - depth * 0.5
                    vx = random.uniform(-1.0, 1.0)
                    vy = random.uniform(-0.5, 1.0)

                self.particles.append({
                    "x": px + random.uniform(-4, 4),
                    "y": py + random.uniform(-4, 4),
                    "vx": vx,
                    "vy": vy,
                    "size": random.randint(1, 3),
                    "color": random.choice(SAND_PARTICLE_COLORS),
                    "life": random.randint(20, 45),
                    "max_life": 45,
                    "gravity": 0.15,
                })

    def erode_by_paddle(self, paddle_rect: pygame.Rect, side: str) -> float:
        """패들이 이동할 때 인접 벽면 모래를 조금씩 깎음 (걷기 침식).

        Args:
            paddle_rect: 패들의 Rect (BOSS 또는 PLAYER)
            side: 'top' (보스) 또는 'bottom' (플레이어)
        Returns:
            실제 깎인 총량
        """
        wall = None
        for w in self.walls:
            if w.side == side:
                wall = w
                break
        if wall is None or wall.is_empty():
            return 0.0

        # 패들 중심 X → 세그먼트 인덱스
        world_pos = float(paddle_rect.centerx)
        local = world_pos - wall.start
        center_seg = local / SEG_SIZE
        total_eroded = 0.0

        for offset in range(-WALK_ERODE_RADIUS_SEGS, WALK_ERODE_RADIUS_SEGS + 1):
            idx = int(center_seg) + offset
            if idx < 0 or idx >= wall.num_segs:
                continue
            dist_factor = 1.0 - abs(offset) / (WALK_ERODE_RADIUS_SEGS + 1)
            erode = WALK_ERODE_AMOUNT * dist_factor
            old = wall.depths[idx]
            wall.depths[idx] = max(0, old - erode)
            total_eroded += old - wall.depths[idx]

        if total_eroded > 0.5:
            wall._dirty = True
            # 소량 파티클 (가끔만)
            if random.random() < 0.15:
                self._spawn_walk_particles(side, paddle_rect.centerx, paddle_rect.centery, total_eroded)
        return total_eroded

    def erode_by_dash(self, start_x: float, end_x: float, side: str) -> float:
        """대쉬 경로를 따라 모래를 크게 깎음.

        Args:
            start_x: 대쉬 시작 X 좌표
            end_x: 대쉬 끝 X 좌표
            side: 'top' (보스) 또는 'bottom' (플레이어)
        Returns:
            실제 깎인 총량
        """
        wall = None
        for w in self.walls:
            if w.side == side:
                wall = w
                break
        if wall is None or wall.is_empty():
            return 0.0

        # 대쉬 경로의 세그먼트 범위 계산
        x_min = min(start_x, end_x)
        x_max = max(start_x, end_x)
        local_min = (x_min - wall.start) / SEG_SIZE
        local_max = (x_max - wall.start) / SEG_SIZE
        seg_start = max(0, int(local_min) - DASH_ERODE_RADIUS_SEGS)
        seg_end = min(wall.num_segs - 1, int(local_max) + DASH_ERODE_RADIUS_SEGS)

        total_eroded = 0.0
        for idx in range(seg_start, seg_end + 1):
            # 경로 중심에서의 거리 (세그먼트 단위)
            seg_world = wall.start + idx * SEG_SIZE + SEG_SIZE // 2
            if seg_world < x_min:
                dist_from_path = (x_min - seg_world) / SEG_SIZE
            elif seg_world > x_max:
                dist_from_path = (seg_world - x_max) / SEG_SIZE
            else:
                dist_from_path = 0.0

            if dist_from_path > DASH_ERODE_RADIUS_SEGS:
                continue

            dist_factor = 1.0 - dist_from_path / (DASH_ERODE_RADIUS_SEGS + 1)
            erode = DASH_ERODE_AMOUNT * dist_factor
            old = wall.depths[idx]
            wall.depths[idx] = max(0, old - erode)
            total_eroded += old - wall.depths[idx]

        if total_eroded > 0:
            wall._dirty = True
            # 대쉬 경로를 따라 파티클 생성
            dash_cx = (start_x + end_x) / 2
            if side == "top":
                dash_cy = max(wall.depths[max(0, min(wall.num_segs - 1, int(local_min)))] * 0.5, 10)
            else:
                dash_cy = HEIGHT - max(wall.depths[max(0, min(wall.num_segs - 1, int(local_min)))] * 0.5, 10)
            count = max(5, min(15, int(total_eroded / 3)))
            direction = 1 if end_x > start_x else -1
            for _ in range(count):
                px = random.uniform(x_min, x_max)
                self.particles.append({
                    "x": px,
                    "y": dash_cy + random.uniform(-8, 8),
                    "vx": direction * random.uniform(1.0, 4.0),
                    "vy": random.uniform(-2.0, -0.5) if side == "top" else random.uniform(0.5, 2.0),
                    "size": random.randint(2, 4),
                    "color": random.choice(SAND_PARTICLE_COLORS),
                    "life": random.randint(15, 30),
                    "max_life": 30,
                    "gravity": 0.12,
                })

        return total_eroded

    def _spawn_walk_particles(self, side: str, bx: int, by: int, eroded: float) -> None:
        """걷기 침식 시 소량 파티클"""
        count = max(1, min(4, int(eroded / 2)))
        for _ in range(count):
            if side == "top":
                vy = random.uniform(0.5, 2.0)
            else:
                vy = random.uniform(-2.0, -0.5)
            self.particles.append({
                "x": float(bx + random.randint(-10, 10)),
                "y": float(by + random.randint(-4, 4)) if side == "bottom" else random.uniform(5, 25),
                "vx": random.uniform(-1.0, 1.0),
                "vy": vy,
                "size": random.randint(1, 3),
                "color": random.choice(SAND_PARTICLE_COLORS),
                "life": random.randint(12, 25),
                "max_life": 25,
                "gravity": 0.1,
            })

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


def erode_sand_area(terrain: SandTerrain | None, cx: float, cy: float, radius: float) -> float:
    """폭발 범위 내 모래 침식. 반환: 총 깎인 양"""
    if isinstance(terrain, SandTerrain):
        return terrain.erode_area(cx, cy, radius)
    return 0.0


def erode_sand_by_paddle(terrain: SandTerrain | None, paddle_rect: pygame.Rect, side: str) -> float:
    """패들 이동(걷기) 시 인접 벽면 모래 침식. 반환: 총 깎인 양"""
    if isinstance(terrain, SandTerrain) and not terrain.dissolving:
        return terrain.erode_by_paddle(paddle_rect, side)
    return 0.0


def erode_sand_by_dash(terrain: SandTerrain | None, start_x: float, end_x: float, side: str) -> float:
    """대쉬 경로를 따라 모래 침식. 반환: 총 깎인 양"""
    if isinstance(terrain, SandTerrain) and not terrain.dissolving:
        return terrain.erode_by_dash(start_x, end_x, side)
    return 0.0


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
