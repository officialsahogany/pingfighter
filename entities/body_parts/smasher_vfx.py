"""
SmasherVFX — 스매셔 캐릭터 비주얼 이펙트 모듈.

8가지 업그레이드 이펙트:
1. 라켓 스윙 트레일 (타격 시 아크 잔상)
2. 대시 잔상/스피드라인
3. 에너지 코어 HP 연동
4. 방패 충격파 리플
5. 림 라이트 (캐릭터 외곽 발광)
6. 이동 파티클 트레일
7. 아이들 서브모션 (바이저 깜빡임, 무기 돌리기 등)
8. 보드 감속/정지 이펙트
"""

import math
import pygame
from typing import Optional


# ─────────────────────────────────────────────
#  1. 라켓 스윙 트레일 (Swing Arc Trail)
# ─────────────────────────────────────────────

class SwingTrail:
    """타격 시 라켓 궤적을 따라 반투명 아크를 그림."""

    def __init__(self):
        self.active = False
        self.timer = 0.0
        self.duration = 0.35  # 초
        self.positions: list[tuple[int, int]] = []
        self.max_positions = 8

    def trigger(self, start_pos: tuple[int, int]):
        """타격 시작 시 호출."""
        self.active = True
        self.timer = self.duration
        self.positions = [start_pos]

    def update(self, dt: float, weapon_pos: tuple[int, int]):
        """매 프레임 호출."""
        if not self.active:
            return
        self.timer -= dt
        if self.timer <= 0:
            self.active = False
            self.positions.clear()
            return
        self.positions.append(weapon_pos)
        if len(self.positions) > self.max_positions:
            self.positions.pop(0)

    def draw(self, surface: pygame.Surface, palette: dict):
        """트레일 아크 렌더링."""
        if not self.active or len(self.positions) < 3:
            return
        progress = max(0.0, self.timer / self.duration)
        n = len(self.positions)
        for i in range(1, n):
            t = i / n
            alpha = int(180 * t * progress)
            width = max(1, int(5 * t * progress))
            color = palette.get("paddle_core", (244, 116, 132))
            seg_surf = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
            pygame.draw.line(seg_surf, (*color, alpha),
                           self.positions[i - 1], self.positions[i], width)
            surface.blit(seg_surf, (0, 0))

        # 끝 부분 글로우
        if self.positions:
            tip = self.positions[-1]
            glow_r = int(8 * progress)
            if glow_r > 1:
                glow_s = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
                color = palette.get("paddle_core", (244, 116, 132))
                pygame.draw.circle(glow_s, (*color, int(60 * progress)),
                                 (glow_r, glow_r), glow_r)
                surface.blit(glow_s,
                           (tip[0] - glow_r, tip[1] - glow_r),
                           special_flags=pygame.BLEND_RGBA_ADD)


# ─────────────────────────────────────────────
#  2. 대시 잔상 + 스피드라인 (Dash Afterimage)
# ─────────────────────────────────────────────

class DashAfterimage:
    """대시 시 고스트 잔상 + 스피드라인."""

    def __init__(self):
        self.ghosts: list[dict] = []  # {"surface", "pos", "alpha", "age"}
        self.speedlines: list[dict] = []
        self.active = False
        self.direction = 0  # -1 좌, 1 우

    def trigger(self, char_surface: pygame.Surface, pos: tuple[int, int], direction: int):
        """대시 시작 시 호출."""
        self.active = True
        self.direction = direction
        # 고스트 잔상 3개 생성
        tinted = char_surface.copy()
        blue_overlay = pygame.Surface(tinted.get_size(), pygame.SRCALPHA)
        blue_overlay.fill((80, 160, 255, 60))
        tinted.blit(blue_overlay, (0, 0))

        for i in range(3):
            self.ghosts.append({
                "surface": tinted.copy(),
                "pos": (pos[0] - direction * (i + 1) * 12, pos[1]),
                "alpha": 150 - i * 40,
                "age": 0.0,
                "max_age": 0.25 + i * 0.08,
            })

        # 스피드라인 생성
        import random
        for _ in range(6):
            y_off = random.randint(-30, 30)
            length = random.randint(15, 40)
            self.speedlines.append({
                "x": pos[0] - direction * random.randint(5, 25),
                "y": pos[1] + y_off,
                "length": length,
                "alpha": random.randint(100, 200),
                "age": 0.0,
                "max_age": 0.2 + random.random() * 0.15,
            })

    def update(self, dt: float):
        """매 프레임 갱신."""
        for g in self.ghosts:
            g["age"] += dt
        self.ghosts = [g for g in self.ghosts if g["age"] < g["max_age"]]

        for sl in self.speedlines:
            sl["age"] += dt
        self.speedlines = [sl for sl in self.speedlines if sl["age"] < sl["max_age"]]

        if not self.ghosts and not self.speedlines:
            self.active = False

    def draw(self, surface: pygame.Surface):
        """잔상 + 스피드라인 렌더링."""
        # 고스트 잔상
        for g in self.ghosts:
            progress = 1.0 - g["age"] / g["max_age"]
            ghost_surf = g["surface"].copy()
            ghost_surf.set_alpha(int(g["alpha"] * progress))
            surface.blit(ghost_surf, g["pos"])

        # 스피드라인
        for sl in self.speedlines:
            progress = 1.0 - sl["age"] / sl["max_age"]
            alpha = int(sl["alpha"] * progress)
            x, y = int(sl["x"]), int(sl["y"])
            length = int(sl["length"] * progress)
            line_surf = pygame.Surface((length + 2, 3), pygame.SRCALPHA)
            pygame.draw.line(line_surf, (180, 220, 255, alpha),
                           (0, 1), (length, 1), 2)
            surface.blit(line_surf, (x, y))


# ─────────────────────────────────────────────
#  3. 에너지 코어 HP 연동 (Energy Core HP Sync)
# ─────────────────────────────────────────────

class EnergyCoreState:
    """HP에 따라 에너지 코어 색상/맥동 속도를 변화시킴."""

    def __init__(self):
        self.hp_ratio = 1.0  # 0.0 ~ 1.0

    def set_hp(self, current_hp: float, max_hp: float):
        if max_hp > 0:
            self.hp_ratio = max(0.0, min(1.0, current_hp / max_hp))

    def get_core_color(self, base_color: tuple = (82, 178, 248)) -> tuple:
        """HP에 따른 코어 색상 반환."""
        r_base, g_base, b_base = base_color
        if self.hp_ratio > 0.6:
            # 정상: 파란색
            return base_color
        elif self.hp_ratio > 0.3:
            # 주의: 파란→노란
            t = (0.6 - self.hp_ratio) / 0.3
            return (
                int(r_base + (255 - r_base) * t),
                int(g_base + (200 - g_base) * t),
                int(b_base + (50 - b_base) * t),
            )
        else:
            # 위험: 노란→빨간
            t = (0.3 - self.hp_ratio) / 0.3
            return (
                int(255),
                int(200 - 150 * t),
                int(50 - 50 * t),
            )

    def get_pulse_speed(self) -> float:
        """HP 낮을수록 빠르게 맥동."""
        if self.hp_ratio > 0.6:
            return 2.5
        elif self.hp_ratio > 0.3:
            return 4.0
        else:
            return 7.0

    def get_pulse_intensity(self) -> float:
        """HP 낮을수록 더 격하게 맥동."""
        if self.hp_ratio > 0.6:
            return 0.4
        elif self.hp_ratio > 0.3:
            return 0.6
        else:
            return 0.9


# ─────────────────────────────────────────────
#  4. 방패 충격파 리플 (Shield Impact Ripple)
# ─────────────────────────────────────────────

class ShieldRipple:
    """방패에 공이 맞았을 때 확산하는 충격파 링."""

    def __init__(self):
        self.ripples: list[dict] = []

    def trigger(self, center: tuple[int, int]):
        """충격 발생."""
        self.ripples.append({
            "cx": center[0], "cy": center[1],
            "age": 0.0, "max_age": 0.5,
            "max_radius": 30,
        })

    def update(self, dt: float):
        for r in self.ripples:
            r["age"] += dt
        self.ripples = [r for r in self.ripples if r["age"] < r["max_age"]]

    def draw(self, surface: pygame.Surface, palette: dict):
        for r in self.ripples:
            progress = r["age"] / r["max_age"]
            radius = int(r["max_radius"] * progress)
            alpha = int(200 * (1.0 - progress))
            width = max(1, int(3 * (1.0 - progress)))

            if radius < 2:
                continue

            ring_surf = pygame.Surface((radius * 2 + 4, radius * 2 + 4), pygame.SRCALPHA)
            cx, cy = radius + 2, radius + 2
            color = palette.get("shield_core", (200, 252, 255))
            pygame.draw.circle(ring_surf, (*color, alpha), (cx, cy), radius, width)
            # 내부 글로우
            inner_alpha = int(60 * (1.0 - progress))
            inner_r = max(1, radius - 4)
            pygame.draw.circle(ring_surf, (*color, inner_alpha), (cx, cy), inner_r)

            surface.blit(ring_surf,
                        (r["cx"] - cx, r["cy"] - cy),
                        special_flags=pygame.BLEND_RGBA_ADD)


# ─────────────────────────────────────────────
#  5. 림 라이트 (Rim Light)
# ─────────────────────────────────────────────

def apply_rim_light(surface: pygame.Surface,
                    color: tuple = (120, 200, 255),
                    thickness: int = 1,
                    alpha: int = 80) -> pygame.Surface:
    """캐릭터 Surface의 알파 외곽을 따라 발광 윤곽선을 그림.

    Args:
        surface: 원본 SRCALPHA Surface (수정하지 않음)
        color: 림 라이트 색상
        thickness: 외곽선 두께
        alpha: 밝기 (0~255)

    Returns:
        림 라이트가 적용된 새 Surface.
    """
    w, h = surface.get_size()
    result = surface.copy()

    # 알파 마스크 추출
    mask = pygame.mask.from_surface(surface, 50)
    outline_points = mask.outline(every=2)

    if len(outline_points) < 3:
        return result

    # 외곽선 Surface 생성
    outline_surf = pygame.Surface((w, h), pygame.SRCALPHA)

    # 외곽 포인트 연결
    for i in range(len(outline_points)):
        p1 = outline_points[i]
        p2 = outline_points[(i + 1) % len(outline_points)]
        pygame.draw.line(outline_surf, (*color, alpha), p1, p2, thickness)

    # 글로우 레이어 (확장된 외곽)
    glow_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(len(outline_points)):
        p1 = outline_points[i]
        p2 = outline_points[(i + 1) % len(outline_points)]
        pygame.draw.line(glow_surf, (*color, alpha // 3), p1, p2, thickness + 2)

    result.blit(glow_surf, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)
    result.blit(outline_surf, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

    return result


# ─────────────────────────────────────────────
#  6. 이동 파티클 트레일 (Movement Particles)
# ─────────────────────────────────────────────

class MovementParticles:
    """이동 시 보드 아래에서 발생하는 에너지 파티클."""

    def __init__(self):
        self.particles: list[dict] = []
        self._spawn_timer = 0.0
        self.prev_x: Optional[float] = None

    def update(self, dt: float, board_cx: float, board_y: float, is_moving: bool):
        """매 프레임 갱신. is_moving이면 파티클 생성."""
        # 이동 속도 계산
        speed = 0.0
        if self.prev_x is not None:
            speed = abs(board_cx - self.prev_x) / max(0.001, dt)
        self.prev_x = board_cx

        # 파티클 생성
        if is_moving and speed > 10:
            self._spawn_timer += dt
            spawn_rate = 0.03  # 초당 ~33개
            while self._spawn_timer >= spawn_rate:
                self._spawn_timer -= spawn_rate
                import random
                self.particles.append({
                    "x": board_cx + random.uniform(-20, 20),
                    "y": board_y + random.uniform(0, 8),
                    "vx": random.uniform(-15, 15),
                    "vy": random.uniform(10, 30),
                    "size": random.uniform(1.5, 3.5),
                    "age": 0.0,
                    "max_age": random.uniform(0.3, 0.6),
                    "color_idx": random.randint(0, 2),
                })
        else:
            self._spawn_timer = 0.0

        # 파티클 업데이트
        for p in self.particles:
            p["age"] += dt
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt
            p["vy"] += 20 * dt  # 약간의 중력
            p["size"] *= 0.97  # 서서히 축소

        self.particles = [p for p in self.particles if p["age"] < p["max_age"]]

    def draw(self, surface: pygame.Surface, palette: dict):
        colors = [
            palette.get("board_glow", (100, 198, 255)),
            palette.get("accent", (118, 214, 255)),
            (200, 230, 255),
        ]
        for p in self.particles:
            progress = 1.0 - p["age"] / p["max_age"]
            alpha = int(180 * progress)
            r = max(1, int(p["size"]))
            color = colors[p["color_idx"] % len(colors)]
            if r <= 1:
                px, py = int(p["x"]), int(p["y"])
                if 0 <= px < surface.get_width() and 0 <= py < surface.get_height():
                    ps = pygame.Surface((3, 3), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (*color, alpha), (1, 1), 1)
                    surface.blit(ps, (px - 1, py - 1), special_flags=pygame.BLEND_RGBA_ADD)
            else:
                glow_size = r * 3
                gs = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
                center = glow_size // 2
                pygame.draw.circle(gs, (*color, alpha // 3), (center, center), r + 1)
                pygame.draw.circle(gs, (*color, alpha), (center, center), r)
                surface.blit(gs,
                           (int(p["x"]) - center, int(p["y"]) - center),
                           special_flags=pygame.BLEND_RGBA_ADD)


# ─────────────────────────────────────────────
#  7. 아이들 서브모션 (Idle Sub-motions)
# ─────────────────────────────────────────────

class IdleSubMotions:
    """대기 상태에서 간헐적으로 발생하는 서브 애니메이션들.

    - 바이저 깜빡임 (visor blink)
    - 어깨 스트레치
    - 무기 손목 돌리기
    """

    def __init__(self):
        self._blink_timer = 0.0
        self._blink_interval = 3.5  # 초마다 깜빡임
        self._blink_active = False
        self._blink_progress = 0.0
        self._blink_duration = 0.15

        self._stretch_timer = 0.0
        self._stretch_interval = 8.0
        self._stretch_active = False
        self._stretch_progress = 0.0
        self._stretch_duration = 1.2

        self._fidget_timer = 0.0
        self._fidget_interval = 5.5
        self._fidget_active = False
        self._fidget_progress = 0.0
        self._fidget_duration = 0.8

    def update(self, dt: float, is_idle: bool):
        """매 프레임 호출."""
        if not is_idle:
            self._blink_active = False
            self._stretch_active = False
            self._fidget_active = False
            self._blink_timer = 0.0
            self._stretch_timer = 0.0
            self._fidget_timer = 0.0
            return

        # 바이저 깜빡임
        if self._blink_active:
            self._blink_progress += dt / self._blink_duration
            if self._blink_progress >= 1.0:
                self._blink_active = False
                self._blink_progress = 0.0
        else:
            self._blink_timer += dt
            if self._blink_timer >= self._blink_interval:
                self._blink_timer = 0.0
                self._blink_active = True
                self._blink_progress = 0.0

        # 어깨 스트레치
        if self._stretch_active:
            self._stretch_progress += dt / self._stretch_duration
            if self._stretch_progress >= 1.0:
                self._stretch_active = False
                self._stretch_progress = 0.0
        else:
            self._stretch_timer += dt
            if self._stretch_timer >= self._stretch_interval:
                self._stretch_timer = 0.0
                self._stretch_active = True
                self._stretch_progress = 0.0

        # 무기 손목 흔들기
        if self._fidget_active:
            self._fidget_progress += dt / self._fidget_duration
            if self._fidget_progress >= 1.0:
                self._fidget_active = False
                self._fidget_progress = 0.0
        else:
            self._fidget_timer += dt
            if self._fidget_timer >= self._fidget_interval:
                self._fidget_timer = 0.0
                self._fidget_active = True
                self._fidget_progress = 0.0

    @property
    def visor_blink_alpha(self) -> float:
        """바이저 밝기 멀티플라이어 (1.0=정상, 0.3=깜빡임 중)."""
        if not self._blink_active:
            return 1.0
        # 빠르게 어두워졌다 밝아짐
        t = self._blink_progress
        return 0.3 + 0.7 * abs(2.0 * t - 1.0)

    def get_sub_pose(self) -> dict[str, float]:
        """현재 서브모션의 추가 관절 각도."""
        pose = {}

        # 어깨 스트레치 (양팔을 살짝 들었다 내림)
        if self._stretch_active:
            t = self._stretch_progress
            # 부드러운 올림→내림 커브
            strength = math.sin(t * math.pi)
            pose["l_shoulder"] = -8.0 * strength
            pose["r_shoulder"] = -8.0 * strength
            pose["torso"] = 2.0 * strength
            pose["head"] = -3.0 * strength

        # 무기 손목 흔들기
        if self._fidget_active:
            t = self._fidget_progress
            wave = math.sin(t * math.pi * 3)  # 1.5 왕복
            pose["l_wrist"] = pose.get("l_wrist", 0.0) + 15.0 * wave
            pose["l_elbow"] = pose.get("l_elbow", 0.0) + 5.0 * wave

        return pose


# ─────────────────────────────────────────────
#  8. 보드 감속/정지 이펙트 (Board Decel Effect)
# ─────────────────────────────────────────────

class BoardDecelEffect:
    """이동→정지 전환 시 에너지 방출 + 먼지 파티클."""

    def __init__(self):
        self._was_moving = False
        self._decel_active = False
        self._decel_timer = 0.0
        self._decel_duration = 0.4
        self._decel_x = 0.0
        self._decel_y = 0.0
        self._dust_particles: list[dict] = []

    def update(self, dt: float, board_cx: float, board_y: float, is_moving: bool):
        """이동→정지 전환 감지."""
        if self._was_moving and not is_moving:
            self._decel_active = True
            self._decel_timer = self._decel_duration
            self._decel_x = board_cx
            self._decel_y = board_y
            # 먼지 파티클 생성
            import random
            for _ in range(8):
                self._dust_particles.append({
                    "x": board_cx + random.uniform(-25, 25),
                    "y": board_y + random.uniform(-2, 5),
                    "vx": random.uniform(-40, 40),
                    "vy": random.uniform(-15, 5),
                    "size": random.uniform(1.0, 2.5),
                    "age": 0.0,
                    "max_age": random.uniform(0.2, 0.45),
                })
        self._was_moving = is_moving

        if self._decel_active:
            self._decel_timer -= dt
            if self._decel_timer <= 0:
                self._decel_active = False

        # 먼지 파티클 업데이트
        for p in self._dust_particles:
            p["age"] += dt
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt
            p["vy"] += 50 * dt  # 중력
            p["size"] *= 0.95
        self._dust_particles = [p for p in self._dust_particles
                                 if p["age"] < p["max_age"]]

    def draw(self, surface: pygame.Surface, palette: dict):
        # 에너지 방출 링
        if self._decel_active:
            progress = 1.0 - self._decel_timer / self._decel_duration
            ring_r = int(20 * progress)
            alpha = int(120 * (1.0 - progress))
            if ring_r > 2:
                ring_w = max(ring_r * 2, 4)
                ring_h = max(int(ring_r * 0.5), 2)
                rs = pygame.Surface((ring_w * 2, ring_h * 2), pygame.SRCALPHA)
                color = palette.get("board_glow", (100, 198, 255))
                pygame.draw.ellipse(rs, (*color, alpha),
                                   (ring_w - ring_r, ring_h - ring_h // 2,
                                    ring_r * 2, ring_h), 2)
                surface.blit(rs,
                           (int(self._decel_x) - ring_w,
                            int(self._decel_y) - ring_h),
                           special_flags=pygame.BLEND_RGBA_ADD)

        # 먼지 파티클
        for p in self._dust_particles:
            prog = 1.0 - p["age"] / p["max_age"]
            alpha = int(120 * prog)
            r = max(1, int(p["size"]))
            ps = pygame.Surface((r * 2 + 2, r * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (180, 200, 220, alpha),
                             (r + 1, r + 1), r)
            surface.blit(ps,
                        (int(p["x"]) - r - 1, int(p["y"]) - r - 1))


# ─────────────────────────────────────────────
#  SmasherVFXManager — 전체 이펙트 통합 관리
# ─────────────────────────────────────────────

class SmasherVFXManager:
    """스매셔 캐릭터의 모든 VFX를 통합 관리.

    Usage:
        vfx = get_smasher_vfx()
        vfx.update(dt, ...)
        # 캐릭터 Surface 렌더링 후:
        surface = vfx.post_process(surface)
        # 월드 공간 이펙트:
        vfx.draw_world_effects(screen, player_x, player_y)
    """

    def __init__(self):
        self.swing_trail = SwingTrail()
        self.dash_afterimage = DashAfterimage()
        self.energy_core = EnergyCoreState()
        self.shield_ripple = ShieldRipple()
        self.movement_particles = MovementParticles()
        self.idle_sub_motions = IdleSubMotions()
        self.board_decel = BoardDecelEffect()

        self._rim_light_enabled = True
        self._rim_light_color = (120, 200, 255)

    def update(self, dt: float, *,
               is_idle: bool = False,
               is_moving: bool = False,
               board_cx: float = 0.0,
               board_y: float = 0.0,
               weapon_pos: tuple[int, int] = (0, 0)):
        """모든 VFX 상태 갱신."""
        self.swing_trail.update(dt, weapon_pos)
        self.dash_afterimage.update(dt)
        self.shield_ripple.update(dt)
        self.movement_particles.update(dt, board_cx, board_y, is_moving)
        self.idle_sub_motions.update(dt, is_idle)
        self.board_decel.update(dt, board_cx, board_y, is_moving)

    def post_process(self, surface: pygame.Surface, palette: dict) -> pygame.Surface:
        """캐릭터 Surface에 림 라이트 등 후처리 적용."""
        result = surface
        if self._rim_light_enabled:
            # HP에 따라 림 라이트 색상 변화
            hp = self.energy_core.hp_ratio
            if hp > 0.6:
                rim_color = self._rim_light_color
                rim_alpha = 70
            elif hp > 0.3:
                rim_color = (200, 200, 100)
                rim_alpha = 90
            else:
                rim_color = (255, 100, 80)
                rim_alpha = 110
            result = apply_rim_light(result, rim_color, thickness=1, alpha=rim_alpha)
        return result

    def draw_char_effects(self, surface: pygame.Surface, palette: dict):
        """캐릭터 Surface 위에 그리는 이펙트 (스윙 트레일 등)."""
        self.swing_trail.draw(surface, palette)

    def draw_world_effects(self, screen: pygame.Surface,
                           player_x: float, player_y: float,
                           palette: dict):
        """월드 공간에 그리는 이펙트 (대시 잔상, 파티클 등)."""
        self.dash_afterimage.draw(screen)
        self.shield_ripple.draw(screen, palette)
        self.movement_particles.draw(screen, palette)
        self.board_decel.draw(screen, palette)

    # ── 트리거 메서드들 ──

    def trigger_swing(self, start_pos: tuple[int, int]):
        self.swing_trail.trigger(start_pos)

    def trigger_dash(self, char_surface: pygame.Surface,
                     pos: tuple[int, int], direction: int):
        self.dash_afterimage.trigger(char_surface, pos, direction)

    def trigger_shield_hit(self, center: tuple[int, int]):
        self.shield_ripple.trigger(center)

    def set_hp(self, current_hp: float, max_hp: float):
        self.energy_core.set_hp(current_hp, max_hp)


# ── 싱글톤 ──
_smasher_vfx: Optional[SmasherVFXManager] = None


def get_smasher_vfx() -> SmasherVFXManager:
    """스매셔 VFX 매니저 싱글톤."""
    global _smasher_vfx
    if _smasher_vfx is None:
        _smasher_vfx = SmasherVFXManager()
    return _smasher_vfx


def reset_smasher_vfx():
    """게임 리셋 시 호출."""
    global _smasher_vfx
    _smasher_vfx = None
