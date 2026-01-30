# downtown/performance_stage.py
# 광장 공연 스테이지 시스템 (NPC 이벤트/공연용) - 고퀄리티 버전

import pygame
import math
import random
from .constants import TILE_SIZE, SCREEN_WIDTH, SCREEN_HEIGHT


class PerformanceStage:
    """
    광장 중앙 공연 스테이지 (Premium Quality)
    - 홀로그램 배경 연출 (다양한 패턴)
    - 네온 조명 효과 (스포트라이트, 레이저)
    - 파티클 이펙트 (글로우, 스파클)
    - 바닥 LED 원형 장식
    - 메탈 지지대 및 트러스 구조물
    - NPC 공연/이벤트용
    """

    def __init__(self, center_x, center_y):
        """
        Args:
            center_x: 스테이지 중심 X 좌표 (픽셀)
            center_y: 스테이지 중심 Y 좌표 (픽셀)
        """
        # 위치
        self.center_x = center_x
        self.center_y = center_y

        # 스테이지 크기 (더 크고 웅장하게)
        self.stage_width = 320  # 무대 너비
        self.stage_height = 70  # 무대 높이 (플랫폼)
        self.backdrop_width = 300  # 배경 화면 너비
        self.backdrop_height = 200  # 배경 화면 높이

        # 바닥 원형 장식 (더 크고 화려하게)
        self.floor_circle_radius = 240  # 바닥 큰 원 반경
        self.floor_inner_circles = 4     # 내부 동심원 개수

        # 지지대 설정
        self.support_pillars = []
        self._init_support_pillars()

        # 트러스 구조물
        self.truss_segments = []
        self._init_truss()

        # 금지 영역 반경 (건물/NPC 스폰 금지)
        self.exclusion_radius = 350  # 픽셀 단위

        # 애니메이션 타이머
        self.animation_timer = 0

        # 홀로그램 효과 (더 다양한 색상)
        self.hologram_phase = 0
        self.hologram_colors = [
            (0, 255, 255),    # 시안
            (255, 0, 255),    # 마젠타
            (255, 255, 0),    # 옐로우
            (0, 255, 128),    # 민트
            (255, 128, 0),    # 오렌지
            (128, 0, 255),    # 바이올렛
            (255, 64, 128),   # 핫핑크
        ]
        self.current_color_index = 0
        self.color_transition = 0

        # 파티클 (더 많이)
        self.particles = []
        self.max_particles = 80

        # 조명
        self.spotlights = []
        self._init_spotlights()

        # 홀로그램 패턴 (동적 변경)
        self.hologram_pattern = "wave"
        self.pattern_change_timer = 0

        # 스테이지 활성화 상태
        self.is_active = True
        self.performance_mode = "idle"

        # LED 바 상태 (더 많이)
        self.led_bars = []
        # self._init_led_bars()  # LED 바 비활성화

        # 레이저 효과
        self.lasers = []
        self._init_lasers()

        # 스피커 위치
        self.speakers = []
        self._init_speakers()

        # 바닥 LED 타일
        self.floor_led_tiles = []
        # self._init_floor_led_tiles()  # 바닥 LED 타일 비활성화

    def _init_spotlights(self):
        """스포트라이트 초기화 (더 많이, 더 다양하게)"""
        self.spotlights = [
            {"x": -120, "angle": 45, "color": (255, 100, 100), "intensity": 0.9, "sweep_speed": 0.8},
            {"x": 120, "angle": 135, "color": (100, 100, 255), "intensity": 0.9, "sweep_speed": -0.7},
            {"x": 0, "angle": 90, "color": (255, 255, 255), "intensity": 1.0, "sweep_speed": 0},
            {"x": -70, "angle": 60, "color": (100, 255, 100), "intensity": 0.8, "sweep_speed": 1.0},
            {"x": 70, "angle": 120, "color": (255, 255, 100), "intensity": 0.8, "sweep_speed": -0.9},
            {"x": -40, "angle": 75, "color": (255, 150, 255), "intensity": 0.7, "sweep_speed": 0.6},
            {"x": 40, "angle": 105, "color": (150, 255, 255), "intensity": 0.7, "sweep_speed": -0.5},
        ]

    def _init_led_bars(self):
        """LED 바 초기화 (더 많이)"""
        num_bars = 16
        for i in range(num_bars):
            self.led_bars.append({
                "offset": i * 18 - (num_bars * 9),
                "height": random.randint(15, 50),
                "target_height": random.randint(15, 50),
                "color_index": i % len(self.hologram_colors),
                "phase": random.uniform(0, math.pi * 2),
            })

    def _init_lasers(self):
        """레이저 효과 초기화 (더 많이)"""
        self.lasers = [
            {"angle": 30, "speed": 2.5, "color": (0, 255, 255), "width": 3},
            {"angle": 150, "speed": -2.0, "color": (255, 0, 255), "width": 3},
            {"angle": 90, "speed": 3.0, "color": (0, 255, 0), "width": 2},
            {"angle": 60, "speed": -1.5, "color": (255, 255, 0), "width": 2},
            {"angle": 120, "speed": 1.8, "color": (255, 128, 0), "width": 2},
        ]

    def _init_support_pillars(self):
        """무대 지지대 초기화 (더 정교하게)"""
        pillar_offset_x = self.stage_width // 2 - 25
        pillar_offset_y = 50

        self.support_pillars = [
            # 앞쪽 메인 지지대
            {"x": -pillar_offset_x, "y": pillar_offset_y, "height": 90, "width": 18, "type": "front"},
            {"x": pillar_offset_x, "y": pillar_offset_y, "height": 90, "width": 18, "type": "front"},
            # 뒤쪽 배경 지지대
            {"x": -pillar_offset_x - 15, "y": -self.backdrop_height - 10, "height": self.backdrop_height + 60, "width": 14, "type": "back"},
            {"x": pillar_offset_x + 15, "y": -self.backdrop_height - 10, "height": self.backdrop_height + 60, "width": 14, "type": "back"},
            # 중간 보조 지지대
            {"x": -pillar_offset_x // 2, "y": -self.backdrop_height - 10, "height": self.backdrop_height + 60, "width": 10, "type": "back"},
            {"x": pillar_offset_x // 2, "y": -self.backdrop_height - 10, "height": self.backdrop_height + 60, "width": 10, "type": "back"},
        ]

    def _init_truss(self):
        """트러스 구조물 초기화"""
        # 상단 수평 트러스
        self.truss_segments = [
            {"x1": -self.stage_width // 2, "y1": -self.backdrop_height - 30,
             "x2": self.stage_width // 2, "y2": -self.backdrop_height - 30, "type": "horizontal"},
            # 대각선 지지대
            {"x1": -self.stage_width // 2 + 20, "y1": -self.backdrop_height - 30,
             "x2": -self.stage_width // 2 - 10, "y2": -self.backdrop_height + 40, "type": "diagonal"},
            {"x1": self.stage_width // 2 - 20, "y1": -self.backdrop_height - 30,
             "x2": self.stage_width // 2 + 10, "y2": -self.backdrop_height + 40, "type": "diagonal"},
        ]

    def _init_speakers(self):
        """스피커 위치 초기화"""
        self.speakers = [
            {"x": -self.stage_width // 2 - 30, "y": -60, "size": 45},
            {"x": self.stage_width // 2 + 30, "y": -60, "size": 45},
            {"x": -self.stage_width // 2 - 20, "y": -130, "size": 35},
            {"x": self.stage_width // 2 + 20, "y": -130, "size": 35},
        ]

    def _init_floor_led_tiles(self):
        """바닥 LED 타일 초기화"""
        num_tiles = 24
        for i in range(num_tiles):
            angle = i * (2 * math.pi / num_tiles)
            radius = self.floor_circle_radius - 30
            self.floor_led_tiles.append({
                "angle": angle,
                "radius": radius,
                "size": 20,
                "color_index": i % len(self.hologram_colors),
                "pulse_phase": random.uniform(0, math.pi * 2),
            })

    def update(self, dt):
        """스테이지 업데이트"""
        self.animation_timer += dt
        self.hologram_phase += dt * 2.5

        # 색상 전환 (더 부드럽게)
        self.color_transition += dt * 0.4
        if self.color_transition >= 1:
            self.color_transition = 0
            self.current_color_index = (self.current_color_index + 1) % len(self.hologram_colors)

        # 패턴 변경
        self.pattern_change_timer += dt
        if self.pattern_change_timer > 4:
            self.pattern_change_timer = 0
            patterns = ["wave", "pulse", "grid", "spiral", "rainbow", "matrix", "rings"]
            self.hologram_pattern = random.choice(patterns)

        # LED 바 애니메이션 (더 역동적으로)
        for bar in self.led_bars:
            bar["phase"] += dt * 5
            target_from_wave = 20 + 30 * abs(math.sin(bar["phase"]))
            diff = target_from_wave - bar["height"]
            bar["height"] += diff * dt * 8

            if random.random() < dt * 3:
                bar["target_height"] = random.randint(15, 60)

        # 레이저 각도 업데이트
        for laser in self.lasers:
            laser["angle"] += laser["speed"] * dt * 40
            if laser["angle"] > 180:
                laser["angle"] = 0
            elif laser["angle"] < 0:
                laser["angle"] = 180

        # 스포트라이트 스윕
        for spot in self.spotlights:
            sweep = spot.get("sweep_speed", 0)
            if sweep != 0:
                spot["angle"] = 60 + 60 * math.sin(self.animation_timer * sweep)
            spot["intensity"] = 0.6 + 0.4 * abs(math.sin(self.animation_timer * 2.5 + spot["x"] * 0.01))

        # 파티클 업데이트
        self._update_particles(dt)

    def _update_particles(self, dt):
        """파티클 업데이트 (더 다양하게)"""
        for p in self.particles[:]:
            p["life"] -= dt
            p["y"] -= p["vy"] * dt
            p["x"] += p["vx"] * dt
            p["vy"] += p.get("gravity", 0) * dt
            p["alpha"] = int(255 * (p["life"] / p["max_life"]))

            # 스파클 효과
            if p.get("sparkle"):
                p["size"] = p["base_size"] * (0.8 + 0.4 * abs(math.sin(self.animation_timer * 10 + p["x"])))

            if p["life"] <= 0:
                self.particles.remove(p)

        # 새 파티클 생성 (더 다양한 타입)
        if len(self.particles) < self.max_particles:
            if random.random() < dt * 30:
                self._spawn_particle()

    def _spawn_particle(self):
        """파티클 생성 (다양한 타입)"""
        particle_type = random.choice(["glow", "sparkle", "star", "confetti"])
        color = random.choice(self.hologram_colors)

        base_x = self.center_x + random.randint(-self.backdrop_width // 2, self.backdrop_width // 2)
        base_y = self.center_y - self.stage_height // 2

        if particle_type == "glow":
            self.particles.append({
                "x": base_x,
                "y": base_y,
                "vx": random.uniform(-15, 15),
                "vy": random.uniform(40, 80),
                "gravity": -10,
                "size": random.uniform(4, 8),
                "base_size": random.uniform(4, 8),
                "color": color,
                "life": random.uniform(1.5, 3),
                "max_life": random.uniform(1.5, 3),
                "alpha": 255,
                "type": "glow",
            })
        elif particle_type == "sparkle":
            self.particles.append({
                "x": base_x,
                "y": base_y + random.randint(-100, 50),
                "vx": random.uniform(-30, 30),
                "vy": random.uniform(20, 60),
                "gravity": -5,
                "size": random.uniform(2, 5),
                "base_size": random.uniform(2, 5),
                "color": (255, 255, 255),
                "life": random.uniform(0.8, 1.5),
                "max_life": random.uniform(0.8, 1.5),
                "alpha": 255,
                "type": "sparkle",
                "sparkle": True,
            })
        elif particle_type == "star":
            self.particles.append({
                "x": base_x + random.randint(-50, 50),
                "y": base_y - random.randint(0, 150),
                "vx": random.uniform(-5, 5),
                "vy": random.uniform(10, 30),
                "gravity": 0,
                "size": random.uniform(3, 6),
                "base_size": random.uniform(3, 6),
                "color": color,
                "life": random.uniform(2, 4),
                "max_life": random.uniform(2, 4),
                "alpha": 255,
                "type": "star",
            })
        else:  # confetti
            self.particles.append({
                "x": base_x,
                "y": base_y - random.randint(50, 150),
                "vx": random.uniform(-40, 40),
                "vy": random.uniform(-20, 20),
                "gravity": 30,
                "size": random.uniform(3, 6),
                "base_size": random.uniform(3, 6),
                "color": color,
                "life": random.uniform(2, 4),
                "max_life": random.uniform(2, 4),
                "alpha": 255,
                "type": "confetti",
                "rotation": random.uniform(0, 360),
                "rot_speed": random.uniform(-180, 180),
            })

    def draw(self, screen, camera_x, camera_y):
        """스테이지 렌더링"""
        sx = self.center_x - camera_x
        sy = self.center_y - camera_y

        # 화면 밖이면 렌더링 스킵
        if (sx < -self.stage_width - 100 or sx > SCREEN_WIDTH + self.stage_width + 100 or
            sy < -self.backdrop_height - 200 or sy > SCREEN_HEIGHT + 200):
            return

        # 레이어별 렌더링 (간소화 - 스포트라이트만)
        # self._draw_floor_circle(screen, sx, sy)           # 바닥 큰 원 비활성화
        # self._draw_floor_led_tiles(screen, sx, sy)        # 바닥 LED 타일 비활성화
        self._draw_support_pillars_back(screen, sx, sy)   # 뒤쪽 지지대
        # self._draw_truss(screen, sx, sy)                  # 트러스 비활성화
        # self._draw_speakers(screen, sx, sy)               # 스피커 비활성화
        self._draw_stage_base(screen, sx, sy)             # 무대 베이스
        self._draw_backdrop_frame(screen, sx, sy)         # 배경 프레임
        # self._draw_hologram_backdrop(screen, sx, sy)      # 홀로그램 배경 비활성화
        # self._draw_led_bars(screen, sx, sy)               # LED 바 비활성화
        self._draw_spotlights(screen, sx, sy)             # 스포트라이트
        # self._draw_lasers(screen, sx, sy)                 # 레이저 비활성화
        # self._draw_particles(screen, camera_x, camera_y)  # 파티클 비활성화
        self._draw_stage_floor(screen, sx, sy)            # 무대 바닥
        self._draw_support_pillars_front(screen, sx, sy)  # 앞쪽 지지대
        # self._draw_neon_trim(screen, sx, sy)              # 네온 테두리 비활성화

    def _draw_floor_circle(self, screen, sx, sy):
        """바닥 큰 원형 장식 (고퀄리티)"""
        t = self.color_transition
        current_color = self.hologram_colors[self.current_color_index]
        next_color = self.hologram_colors[(self.current_color_index + 1) % len(self.hologram_colors)]
        blend_color = (
            int(current_color[0] * (1 - t) + next_color[0] * t),
            int(current_color[1] * (1 - t) + next_color[1] * t),
            int(current_color[2] * (1 - t) + next_color[2] * t),
        )

        circle_center_y = sy + 70

        outer_radius = self.floor_circle_radius
        circle_surf = pygame.Surface((outer_radius * 2 + 40, outer_radius * 2 + 40), pygame.SRCALPHA)
        center = outer_radius + 20

        # 바깥 글로우 (더 넓게)
        for thickness in range(15, 0, -1):
            glow_alpha = int(25 * thickness / 15)
            pygame.draw.circle(circle_surf, (*blend_color, glow_alpha),
                             (center, center), outer_radius + thickness, 3)

        # 메인 원 (더 두껍게)
        pygame.draw.circle(circle_surf, (*blend_color, 200),
                          (center, center), outer_radius, 4)

        # 동심원들 (더 많이, 더 선명하게)
        for i in range(1, self.floor_inner_circles + 2):
            inner_radius = outer_radius - i * 45
            if inner_radius > 30:
                alpha = int(150 - i * 25)
                pygame.draw.circle(circle_surf, (*blend_color, alpha),
                                  (center, center), inner_radius, 3)

        # 방사형 라인 (더 많이, 회전)
        num_rays = 12
        for i in range(num_rays):
            angle = self.animation_timer * 0.5 + i * (2 * math.pi / num_rays)
            inner_r = 50
            outer_r = outer_radius - 15

            start_x = center + math.cos(angle) * inner_r
            start_y = center + math.sin(angle) * inner_r
            end_x = center + math.cos(angle) * outer_r
            end_y = center + math.sin(angle) * outer_r

            # 그라데이션 라인
            line_alpha = int(100 + 50 * abs(math.sin(self.animation_timer * 3 + i)))
            pygame.draw.line(circle_surf, (*blend_color, line_alpha),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), 3)

        # 중앙 장식 (더 화려하게)
        pulse = abs(math.sin(self.animation_timer * 2.5))
        center_alpha = int(150 + 105 * pulse)

        # 외곽 링
        pygame.draw.circle(circle_surf, (*blend_color, int(center_alpha * 0.7)),
                          (center, center), 50, 3)
        # 내부 원
        pygame.draw.circle(circle_surf, (*blend_color, center_alpha),
                          (center, center), 35)
        # 코어
        pygame.draw.circle(circle_surf, (255, 255, 255, int(center_alpha * 0.8)),
                          (center, center), 20)
        # 하이라이트
        pygame.draw.circle(circle_surf, (255, 255, 255, int(center_alpha * 0.5)),
                          (center - 5, center - 5), 8)

        screen.blit(circle_surf, (sx - center, circle_center_y - center))

    def _draw_floor_led_tiles(self, screen, sx, sy):
        """바닥 LED 타일 렌더링"""
        circle_center_y = sy + 70

        for tile in self.floor_led_tiles:
            angle = tile["angle"] + self.animation_timer * 0.3
            x = sx + math.cos(angle) * tile["radius"]
            y = circle_center_y + math.sin(angle) * tile["radius"] * 0.6  # 원근감

            # 펄스 효과
            pulse = abs(math.sin(self.animation_timer * 4 + tile["pulse_phase"]))
            alpha = int(100 + 155 * pulse)

            color = self.hologram_colors[tile["color_index"]]
            size = int(tile["size"] * (0.8 + 0.3 * pulse))

            # 글로우
            glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
            for r in range(size * 2, 0, -2):
                glow_alpha = int(alpha * r / (size * 2) * 0.4)
                pygame.draw.circle(glow_surf, (*color, glow_alpha),
                                  (size * 2, size * 2), r)

            # 코어
            pygame.draw.circle(glow_surf, (*color, alpha),
                              (size * 2, size * 2), size // 2)

            screen.blit(glow_surf, (x - size * 2, y - size * 2))

    def _draw_support_pillars_back(self, screen, sx, sy):
        """뒤쪽 지지대 렌더링"""
        for pillar in self.support_pillars:
            if pillar["type"] == "back":
                self._draw_single_pillar(screen, sx, sy, pillar)

    def _draw_support_pillars_front(self, screen, sx, sy):
        """앞쪽 지지대 렌더링"""
        for pillar in self.support_pillars:
            if pillar["type"] == "front":
                self._draw_single_pillar(screen, sx, sy, pillar)

    def _draw_single_pillar(self, screen, sx, sy, pillar):
        """단일 지지대 렌더링 (고퀄리티)"""
        px = sx + pillar["x"]
        py = sy + pillar["y"]
        pw = pillar["width"]
        ph = pillar["height"]

        pillar_surf = pygame.Surface((pw + 20, ph + 20), pygame.SRCALPHA)

        # 메인 기둥 (메탈릭 그라데이션)
        for i in range(ph):
            progress = i / ph
            base_brightness = 90 - int(progress * 40)
            # 메탈 하이라이트
            highlight = int(20 * abs(math.sin(progress * math.pi * 3)))
            pillar_color = (
                base_brightness + highlight,
                base_brightness + highlight + 5,
                base_brightness + highlight + 15
            )
            pygame.draw.line(pillar_surf, pillar_color,
                           (10, 10 + i), (10 + pw, 10 + i), 1)

        # 왼쪽 하이라이트 (더 선명하게)
        pygame.draw.line(pillar_surf, (140, 140, 155),
                        (10, 10), (10, 10 + ph), 3)

        # 오른쪽 그림자
        pygame.draw.line(pillar_surf, (30, 30, 40),
                        (10 + pw, 10), (10 + pw, 10 + ph), 3)

        # 상단 캡 (3D 효과)
        pygame.draw.rect(pillar_surf, (120, 120, 135),
                        (6, 6, pw + 8, 10), 0, 3)
        pygame.draw.rect(pillar_surf, (80, 80, 95),
                        (6, 6, pw + 8, 10), 1, 3)

        # 하단 캡
        pygame.draw.rect(pillar_surf, (70, 70, 85),
                        (6, ph + 5, pw + 8, 12), 0, 3)

        # 볼트/리벳 (더 많이)
        bolt_color = (170, 170, 185)
        bolt_positions = [(12, 14), (pw + 8, 14), (12, ph), (pw + 8, ph),
                         (12, ph // 3), (pw + 8, ph // 3), (12, ph * 2 // 3), (pw + 8, ph * 2 // 3)]
        for bx, by in bolt_positions:
            pygame.draw.circle(pillar_surf, bolt_color, (bx, by + 5), 3)
            pygame.draw.circle(pillar_surf, (200, 200, 215), (bx - 1, by + 4), 1)

        screen.blit(pillar_surf, (px - pw // 2 - 10, py - 10))

    def _draw_truss(self, screen, sx, sy):
        """트러스 구조물 렌더링"""
        truss_color = (100, 100, 115)
        truss_highlight = (140, 140, 155)

        for seg in self.truss_segments:
            x1 = sx + seg["x1"]
            y1 = sy + seg["y1"]
            x2 = sx + seg["x2"]
            y2 = sy + seg["y2"]

            # 메인 트러스
            pygame.draw.line(screen, truss_color, (x1, y1), (x2, y2), 6)
            pygame.draw.line(screen, truss_highlight, (x1, y1 - 1), (x2, y2 - 1), 2)

            # 수평 트러스에 조명 장착
            if seg["type"] == "horizontal":
                num_lights = 6
                for i in range(num_lights):
                    light_x = x1 + (x2 - x1) * (i + 0.5) / num_lights
                    light_y = y1 + 8

                    # 조명 하우징
                    pygame.draw.rect(screen, (60, 60, 70),
                                    (light_x - 8, light_y, 16, 12), 0, 2)

                    # 조명 빔
                    pulse = abs(math.sin(self.animation_timer * 3 + i))
                    color = self.hologram_colors[i % len(self.hologram_colors)]
                    alpha = int(100 + 100 * pulse)

                    light_surf = pygame.Surface((40, 60), pygame.SRCALPHA)
                    pygame.draw.polygon(light_surf, (*color, alpha),
                                       [(20, 0), (5, 60), (35, 60)])
                    screen.blit(light_surf, (light_x - 20, light_y + 10))

    def _draw_speakers(self, screen, sx, sy):
        """스피커 렌더링"""
        for speaker in self.speakers:
            spx = sx + speaker["x"]
            spy = sy + speaker["y"]
            size = speaker["size"]

            # 스피커 바디
            pygame.draw.rect(screen, (40, 40, 50),
                            (spx - size // 2, spy - size // 2, size, size), 0, 5)
            pygame.draw.rect(screen, (60, 60, 70),
                            (spx - size // 2, spy - size // 2, size, size), 2, 5)

            # 우퍼
            pygame.draw.circle(screen, (30, 30, 35), (spx, spy), size // 3)
            pygame.draw.circle(screen, (50, 50, 55), (spx, spy), size // 3, 2)

            # 트위터
            pygame.draw.circle(screen, (70, 70, 80), (spx, spy - size // 4), size // 8)

            # 음파 효과 (애니메이션)
            wave_alpha = int(100 * abs(math.sin(self.animation_timer * 8)))
            for i in range(3):
                wave_radius = size // 2 + i * 10 + int(self.animation_timer * 20) % 30
                if wave_radius < size + 40:
                    wave_surf = pygame.Surface((wave_radius * 2, wave_radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(wave_surf, (100, 100, 120, wave_alpha // (i + 1)),
                                      (wave_radius, wave_radius), wave_radius, 2)
                    screen.blit(wave_surf, (spx - wave_radius, spy - wave_radius))

    def _draw_stage_base(self, screen, sx, sy):
        """무대 베이스 (고퀄리티)"""
        # 그림자 (더 크고 부드럽게)
        shadow_surf = pygame.Surface((self.stage_width + 60, 50), pygame.SRCALPHA)
        for i in range(25, 0, -1):
            alpha = int(3 * i)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, alpha),
                              (30 - i, 25 - i // 2, self.stage_width + i * 2, 25 + i))
        screen.blit(shadow_surf, (sx - self.stage_width // 2 - 30, sy + 15))

        # 플랫폼 측면 (3D 효과, 더 깊게)
        side_height = self.stage_height // 2 + 10
        platform_points = [
            (sx - self.stage_width // 2, sy),
            (sx + self.stage_width // 2, sy),
            (sx + self.stage_width // 2 - 15, sy + side_height),
            (sx - self.stage_width // 2 + 15, sy + side_height),
        ]
        pygame.draw.polygon(screen, (35, 35, 45), platform_points)

        # 측면 그라데이션
        for i in range(side_height):
            progress = i / side_height
            color_val = int(35 + progress * 15)
            left_x = sx - self.stage_width // 2 + int(15 * progress)
            right_x = sx + self.stage_width // 2 - int(15 * progress)
            pygame.draw.line(screen, (color_val, color_val, color_val + 10),
                           (left_x, sy + i), (right_x, sy + i), 1)

        # 플랫폼 앞면 (LED 스트립 포함)
        front_rect = pygame.Rect(sx - self.stage_width // 2, sy, self.stage_width, 20)
        pygame.draw.rect(screen, (55, 55, 65), front_rect, 0, 3)
        pygame.draw.rect(screen, (85, 85, 95), front_rect, 2, 3)

        # LED 스트립 (애니메이션)
        led_y = sy + 10
        num_leds = 20
        for i in range(num_leds):
            led_x = sx - self.stage_width // 2 + 15 + i * (self.stage_width - 30) // num_leds
            pulse = abs(math.sin(self.animation_timer * 5 + i * 0.5))
            color = self.hologram_colors[(i + int(self.animation_timer * 2)) % len(self.hologram_colors)]
            alpha = int(150 + 105 * pulse)
            led_surf = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(led_surf, (*color, alpha), (4, 4), 4)
            screen.blit(led_surf, (led_x - 4, led_y - 4))

    def _draw_backdrop_frame(self, screen, sx, sy):
        """배경 화면 프레임 (고퀄리티)"""
        frame_x = sx - self.backdrop_width // 2 - 15
        frame_y = sy - self.backdrop_height - 30
        frame_w = self.backdrop_width + 30
        frame_h = self.backdrop_height + 30

        # 외곽 프레임 (두꺼운 메탈)
        pygame.draw.rect(screen, (50, 50, 60),
                        (frame_x - 5, frame_y - 5, frame_w + 10, frame_h + 10), 0, 8)
        pygame.draw.rect(screen, (70, 70, 85),
                        (frame_x, frame_y, frame_w, frame_h), 0, 6)
        pygame.draw.rect(screen, (110, 110, 125),
                        (frame_x, frame_y, frame_w, frame_h), 4, 6)

        # 코너 장식
        corner_size = 20
        corner_color = (130, 130, 145)
        corners = [
            (frame_x, frame_y),
            (frame_x + frame_w - corner_size, frame_y),
            (frame_x, frame_y + frame_h - corner_size),
            (frame_x + frame_w - corner_size, frame_y + frame_h - corner_size),
        ]
        for cx, cy in corners:
            pygame.draw.rect(screen, corner_color,
                            (cx, cy, corner_size, corner_size), 0, 4)
            pygame.draw.rect(screen, (90, 90, 105),
                            (cx, cy, corner_size, corner_size), 2, 4)

    def _draw_hologram_backdrop(self, screen, sx, sy):
        """홀로그램 배경 화면 (고퀄리티)"""
        backdrop_x = sx - self.backdrop_width // 2
        backdrop_y = sy - self.backdrop_height - 15

        backdrop_surf = pygame.Surface((self.backdrop_width, self.backdrop_height), pygame.SRCALPHA)
        backdrop_surf.fill((5, 5, 15, 250))

        t = self.color_transition
        current_color = self.hologram_colors[self.current_color_index]
        next_color = self.hologram_colors[(self.current_color_index + 1) % len(self.hologram_colors)]
        blend_color = (
            int(current_color[0] * (1 - t) + next_color[0] * t),
            int(current_color[1] * (1 - t) + next_color[1] * t),
            int(current_color[2] * (1 - t) + next_color[2] * t),
        )

        # 패턴 렌더링
        if self.hologram_pattern == "wave":
            self._draw_wave_pattern(backdrop_surf, blend_color)
        elif self.hologram_pattern == "pulse":
            self._draw_pulse_pattern(backdrop_surf, blend_color)
        elif self.hologram_pattern == "grid":
            self._draw_grid_pattern(backdrop_surf, blend_color)
        elif self.hologram_pattern == "spiral":
            self._draw_spiral_pattern(backdrop_surf, blend_color)
        elif self.hologram_pattern == "rainbow":
            self._draw_rainbow_pattern(backdrop_surf)
        elif self.hologram_pattern == "matrix":
            self._draw_matrix_pattern(backdrop_surf, blend_color)
        elif self.hologram_pattern == "rings":
            self._draw_rings_pattern(backdrop_surf, blend_color)

        self._draw_scanlines(backdrop_surf)

        if random.random() < 0.015:
            self._draw_glitch_effect(backdrop_surf)

        screen.blit(backdrop_surf, (backdrop_x, backdrop_y))

    def _draw_wave_pattern(self, surf, color):
        """웨이브 패턴 (더 복잡하게)"""
        w, h = surf.get_size()

        for i in range(12):
            points = []
            for x in range(0, w, 3):
                wave_y = h // 2 + math.sin(x * 0.025 + self.hologram_phase + i * 0.4) * (25 + i * 6)
                wave_y += math.sin(x * 0.01 + self.hologram_phase * 0.5) * 15
                points.append((x, int(wave_y)))

            if len(points) > 1:
                alpha = int(180 - i * 12)
                wave_color = (*color, alpha)
                pygame.draw.lines(surf, wave_color, False, points, 3 - i // 4)

    def _draw_pulse_pattern(self, surf, color):
        """펄스 패턴 (더 많은 원)"""
        w, h = surf.get_size()
        center_x, center_y = w // 2, h // 2

        num_circles = 12
        max_radius = min(w, h) // 2 + 80

        for i in range(num_circles):
            phase = (self.hologram_phase * 0.8 + i * 0.25) % 3.5
            radius = int(phase / 3.5 * max_radius)
            alpha = int(220 * (1 - phase / 3.5))

            if radius > 5 and alpha > 10:
                circle_surf = pygame.Surface((radius * 2 + 4, radius * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(circle_surf, (*color, alpha), (radius + 2, radius + 2), radius, 3)
                surf.blit(circle_surf, (center_x - radius - 2, center_y - radius - 2))

    def _draw_grid_pattern(self, surf, color):
        """그리드 패턴 (더 역동적으로)"""
        w, h = surf.get_size()
        grid_size = 25

        for x in range(0, w, grid_size):
            offset_x = int(math.sin(self.hologram_phase + x * 0.08) * 4)
            alpha = int(100 + 60 * abs(math.sin(self.hologram_phase * 2.5 + x * 0.04)))
            pygame.draw.line(surf, (*color, alpha),
                           (x + offset_x, 0), (x + offset_x, h), 2)

        for y in range(0, h, grid_size):
            offset_y = int(math.sin(self.hologram_phase + y * 0.08) * 4)
            alpha = int(100 + 60 * abs(math.sin(self.hologram_phase * 2.5 + y * 0.04)))
            pygame.draw.line(surf, (*color, alpha),
                           (0, y + offset_y), (w, y + offset_y), 2)

        # 교차점 강조
        for x in range(0, w, grid_size):
            for y in range(0, h, grid_size):
                if (x // grid_size + y // grid_size) % 2 == 0:
                    pulse = abs(math.sin(self.hologram_phase * 3 + x * 0.05 + y * 0.05))
                    point_alpha = int(150 + 100 * pulse)
                    pygame.draw.circle(surf, (*color, point_alpha), (x, y), 4)

    def _draw_spiral_pattern(self, surf, color):
        """스파이럴 패턴 (더 복잡하게)"""
        w, h = surf.get_size()
        center_x, center_y = w // 2, h // 2

        num_arms = 6
        for arm in range(num_arms):
            points = []
            for i in range(150):
                angle = self.hologram_phase + arm * (2 * math.pi / num_arms) + i * 0.08
                radius = i * 1.2
                x = center_x + math.cos(angle) * radius
                y = center_y + math.sin(angle) * radius
                if 0 <= x < w and 0 <= y < h:
                    points.append((int(x), int(y)))

            if len(points) > 1:
                alpha = 180
                pygame.draw.lines(surf, (*color, alpha), False, points, 3)

    def _draw_rainbow_pattern(self, surf):
        """레인보우 패턴 (더 화려하게)"""
        w, h = surf.get_size()

        for i, color in enumerate(self.hologram_colors):
            y_offset = h // 2 + i * 22 - 70
            wave_amp = 25 + i * 5

            points = []
            for x in range(0, w, 3):
                wave_y = y_offset + math.sin(x * 0.025 + self.hologram_phase + i * 0.3) * wave_amp
                points.append((x, int(wave_y)))

            if len(points) > 1:
                pygame.draw.lines(surf, (*color, 200), False, points, 4)

    def _draw_matrix_pattern(self, surf, color):
        """매트릭스 패턴 (떨어지는 코드)"""
        w, h = surf.get_size()

        num_columns = 15
        for i in range(num_columns):
            x = i * (w // num_columns) + 10
            # 각 열마다 다른 속도와 시작점
            speed = 1.5 + (i % 3) * 0.5
            offset = (self.animation_timer * speed * 50 + i * 30) % (h + 100)

            for j in range(8):
                y = int(offset - j * 20) % h
                char_alpha = int(200 - j * 25)
                if char_alpha > 0:
                    char_surf = pygame.Surface((12, 16), pygame.SRCALPHA)
                    pygame.draw.rect(char_surf, (*color, char_alpha), (2, 2, 8, 12))
                    surf.blit(char_surf, (x, y))

    def _draw_rings_pattern(self, surf, color):
        """링 패턴 (회전하는 링들)"""
        w, h = surf.get_size()
        center_x, center_y = w // 2, h // 2

        for i in range(5):
            radius = 30 + i * 30
            rotation = self.hologram_phase * (1 + i * 0.2)

            # 끊어진 원
            num_segments = 8 + i * 2
            for j in range(num_segments):
                if j % 2 == 0:
                    start_angle = rotation + j * (2 * math.pi / num_segments)
                    end_angle = rotation + (j + 0.7) * (2 * math.pi / num_segments)

                    points = []
                    for k in range(10):
                        angle = start_angle + (end_angle - start_angle) * k / 9
                        px = center_x + math.cos(angle) * radius
                        py = center_y + math.sin(angle) * radius
                        points.append((int(px), int(py)))

                    if len(points) > 1:
                        alpha = int(180 - i * 25)
                        pygame.draw.lines(surf, (*color, alpha), False, points, 3)

    def _draw_scanlines(self, surf):
        """스캔라인 효과 (더 미세하게)"""
        w, h = surf.get_size()

        for y in range(0, h, 3):
            alpha = 20 + int(10 * abs(math.sin(y * 0.15 + self.hologram_phase)))
            pygame.draw.line(surf, (0, 0, 0, alpha), (0, y), (w, y), 1)

    def _draw_glitch_effect(self, surf):
        """글리치 효과"""
        w, h = surf.get_size()

        for _ in range(random.randint(3, 7)):
            y = random.randint(0, h - 15)
            slice_h = random.randint(5, 15)
            offset = random.randint(-25, 25)

            if 0 <= y < h and 0 <= y + slice_h < h:
                try:
                    temp = surf.subsurface((0, y, w, min(slice_h, h - y))).copy()
                    surf.blit(temp, (offset, y))
                except:
                    pass

    def _draw_led_bars(self, screen, sx, sy):
        """LED 이퀄라이저 바 (고퀄리티)"""
        bar_width = 14
        base_y = sy - self.stage_height // 2 - 15

        for bar in self.led_bars:
            bar_x = sx + bar["offset"]
            bar_h = int(bar["height"])
            color = self.hologram_colors[bar["color_index"]]

            if bar_h < 5:
                continue

            # 바 서피스
            bar_surf = pygame.Surface((bar_width + 8, bar_h + 10), pygame.SRCALPHA)

            # 그라데이션 바
            for i in range(bar_h):
                progress = i / max(1, bar_h)
                brightness = 0.6 + 0.4 * progress
                bar_alpha = int(220 + 35 * progress)
                bar_color = (
                    min(255, int(color[0] * brightness)),
                    min(255, int(color[1] * brightness)),
                    min(255, int(color[2] * brightness)),
                )
                pygame.draw.line(bar_surf, (*bar_color, bar_alpha),
                               (4, bar_h - i + 5), (bar_width + 4, bar_h - i + 5), 1)

            # 상단 글로우
            glow_color = (*color, 180)
            pygame.draw.rect(bar_surf, glow_color,
                           (4, 5, bar_width, 5), 0, 2)

            # 하이라이트
            pygame.draw.rect(bar_surf, (255, 255, 255, 100),
                           (6, 6, bar_width - 4, 3))

            screen.blit(bar_surf, (bar_x - bar_width // 2 - 4, base_y - bar_h - 5))

    def _draw_spotlights(self, screen, sx, sy):
        """스포트라이트 효과 - 등대처럼 원점에서 퍼지는 빛"""
        for spot in self.spotlights:
            spot_x = sx + spot["x"]
            spot_y = sy - self.backdrop_height - 35

            angle_rad = math.radians(spot["angle"])
            color = spot["color"]
            intensity = spot["intensity"]

            # 빛의 길이와 퍼짐 각도
            beam_length = 320
            spread_angle = 0.25  # 퍼짐 각도 (라디안)

            # 큰 서피스 생성
            surf_size = 700
            cone_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
            center = surf_size // 2

            # 등대 빛 효과 - 원점에서 시작해서 점점 넓어지는 빔
            num_segments = 40
            for i in range(num_segments):
                # 거리에 따른 진행도 (0 ~ 1)
                progress = i / num_segments
                dist = progress * beam_length

                # 거리에 따라 빔 너비 증가 (등대 효과)
                beam_width_at_dist = dist * math.tan(spread_angle) * 2

                # 거리에 따라 알파 감소 (빛의 감쇠)
                segment_alpha = int(50 * intensity * (1 - progress * 0.7))

                if segment_alpha <= 0:
                    continue

                # 빔 세그먼트의 시작점과 끝점
                seg_start_dist = dist
                seg_end_dist = dist + beam_length / num_segments

                start_width = seg_start_dist * math.tan(spread_angle)
                end_width = seg_end_dist * math.tan(spread_angle)

                # 4개의 점으로 사다리꼴 그리기
                cos_a = math.cos(angle_rad)
                sin_a = math.sin(angle_rad)
                perp_cos = math.cos(angle_rad + math.pi / 2)
                perp_sin = math.sin(angle_rad + math.pi / 2)

                p1 = (center + cos_a * seg_start_dist - perp_cos * start_width,
                      center + sin_a * seg_start_dist - perp_sin * start_width)
                p2 = (center + cos_a * seg_start_dist + perp_cos * start_width,
                      center + sin_a * seg_start_dist + perp_sin * start_width)
                p3 = (center + cos_a * seg_end_dist + perp_cos * end_width,
                      center + sin_a * seg_end_dist + perp_sin * end_width)
                p4 = (center + cos_a * seg_end_dist - perp_cos * end_width,
                      center + sin_a * seg_end_dist - perp_sin * end_width)

                pygame.draw.polygon(cone_surf, (*color, segment_alpha),
                                   [p1, p2, p3, p4])

            # 빛의 중심 코어 (더 밝은 중앙선)
            core_alpha = int(80 * intensity)
            for w in range(6, 0, -1):
                line_alpha = int(core_alpha * w / 6)
                end_x = center + math.cos(angle_rad) * beam_length
                end_y = center + math.sin(angle_rad) * beam_length
                pygame.draw.line(cone_surf, (*color, line_alpha),
                               (center, center), (int(end_x), int(end_y)), w)

            # 광원 글로우 (시작점)
            for r in range(20, 0, -2):
                glow_alpha = int(100 * intensity * r / 20)
                pygame.draw.circle(cone_surf, (*color, glow_alpha), (center, center), r)

            # 흰색 코어
            pygame.draw.circle(cone_surf, (255, 255, 255, int(200 * intensity)), (center, center), 5)

            screen.blit(cone_surf, (spot_x - center, spot_y - center))

    def _draw_lasers(self, screen, sx, sy):
        """레이저 효과 - 등대처럼 원점에서 퍼지는 실제 빛"""
        laser_origin_y = sy - self.backdrop_height - 20

        for laser in self.lasers:
            angle_rad = math.radians(laser["angle"])
            color = laser["color"]
            base_width = laser["width"]

            # 레이저 빔 파라미터
            beam_length = 400
            start_width = 2  # 시작점 너비 (좁음)
            end_width = 35   # 끝점 너비 (넓음) - 등대 효과

            # 레이저 서피스
            surf_size = 500
            laser_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
            center = surf_size // 2

            cos_a = math.cos(angle_rad)
            sin_a = math.sin(angle_rad)
            perp_cos = math.cos(angle_rad + math.pi / 2)
            perp_sin = math.sin(angle_rad + math.pi / 2)

            # 빔을 세그먼트로 나눠서 그라데이션 효과
            num_segments = 30
            for i in range(num_segments):
                progress_start = i / num_segments
                progress_end = (i + 1) / num_segments

                dist_start = progress_start * beam_length
                dist_end = progress_end * beam_length

                # 거리에 따라 너비 증가 (선형 보간)
                width_start = start_width + (end_width - start_width) * progress_start
                width_end = start_width + (end_width - start_width) * progress_end

                # 거리에 따라 알파 변화 (중간이 가장 밝고 끝으로 갈수록 어두워짐)
                # 대기 중 먼지에 의한 산란 효과
                brightness = 1 - (progress_start * 0.6)
                segment_alpha = int(70 * brightness)

                if segment_alpha <= 0:
                    continue

                # 사다리꼴 꼭지점 계산
                p1 = (center + cos_a * dist_start - perp_cos * width_start / 2,
                      center + sin_a * dist_start - perp_sin * width_start / 2)
                p2 = (center + cos_a * dist_start + perp_cos * width_start / 2,
                      center + sin_a * dist_start + perp_sin * width_start / 2)
                p3 = (center + cos_a * dist_end + perp_cos * width_end / 2,
                      center + sin_a * dist_end + perp_sin * width_end / 2)
                p4 = (center + cos_a * dist_end - perp_cos * width_end / 2,
                      center + sin_a * dist_end - perp_sin * width_end / 2)

                # 외곽 글로우
                pygame.draw.polygon(laser_surf, (*color, segment_alpha // 2),
                                   [p1, p2, p3, p4])

            # 중심 코어 빔 (더 밝고 좁은 중앙선)
            for i in range(num_segments):
                progress = i / num_segments
                dist = progress * beam_length
                core_width = start_width * 0.5 + (end_width * 0.3 - start_width * 0.5) * progress
                core_alpha = int(150 * (1 - progress * 0.5))

                next_progress = (i + 1) / num_segments
                next_dist = next_progress * beam_length
                next_core_width = start_width * 0.5 + (end_width * 0.3 - start_width * 0.5) * next_progress

                p1 = (center + cos_a * dist - perp_cos * core_width / 2,
                      center + sin_a * dist - perp_sin * core_width / 2)
                p2 = (center + cos_a * dist + perp_cos * core_width / 2,
                      center + sin_a * dist + perp_sin * core_width / 2)
                p3 = (center + cos_a * next_dist + perp_cos * next_core_width / 2,
                      center + sin_a * next_dist + perp_sin * next_core_width / 2)
                p4 = (center + cos_a * next_dist - perp_cos * next_core_width / 2,
                      center + sin_a * next_dist - perp_sin * next_core_width / 2)

                pygame.draw.polygon(laser_surf, (*color, core_alpha), [p1, p2, p3, p4])

            # 광원 (시작점 글로우)
            for r in range(15, 0, -1):
                glow_alpha = int(200 * r / 15)
                pygame.draw.circle(laser_surf, (*color, glow_alpha), (center, center), r)

            # 밝은 흰색 코어
            pygame.draw.circle(laser_surf, (255, 255, 255, 250), (center, center), 4)
            pygame.draw.circle(laser_surf, (*color, 255), (center, center), 6, 2)

            screen.blit(laser_surf, (sx - center, laser_origin_y - center))

    def _draw_particles(self, screen, camera_x, camera_y):
        """파티클 렌더링 (고퀄리티)"""
        for p in self.particles:
            px = p["x"] - camera_x
            py = p["y"] - camera_y

            alpha = max(0, min(255, p["alpha"]))
            color = p["color"]
            size = int(p["size"])

            if alpha <= 0 or size <= 0:
                continue

            if p["type"] == "glow":
                particle_surf = pygame.Surface((size * 6, size * 6), pygame.SRCALPHA)
                for r in range(size * 3, 0, -1):
                    glow_alpha = int(alpha * r / (size * 3) * 0.6)
                    pygame.draw.circle(particle_surf, (*color, glow_alpha),
                                      (size * 3, size * 3), r)
                pygame.draw.circle(particle_surf, (*color, alpha),
                                  (size * 3, size * 3), size)
                screen.blit(particle_surf, (px - size * 3, py - size * 3))

            elif p["type"] == "sparkle":
                # 십자 스파클
                sparkle_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                center = size * 2
                pygame.draw.line(sparkle_surf, (*color, alpha),
                               (center - size, center), (center + size, center), 2)
                pygame.draw.line(sparkle_surf, (*color, alpha),
                               (center, center - size), (center, center + size), 2)
                pygame.draw.circle(sparkle_surf, (255, 255, 255, alpha),
                                  (center, center), size // 2)
                screen.blit(sparkle_surf, (px - size * 2, py - size * 2))

            elif p["type"] == "star":
                # 별 모양
                star_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                center = size * 2
                num_points = 5
                for i in range(num_points * 2):
                    angle = i * math.pi / num_points - math.pi / 2
                    radius = size * 1.5 if i % 2 == 0 else size * 0.7
                    x = center + math.cos(angle) * radius
                    y = center + math.sin(angle) * radius
                    if i == 0:
                        points = [(int(x), int(y))]
                    else:
                        points.append((int(x), int(y)))
                pygame.draw.polygon(star_surf, (*color, alpha), points)
                screen.blit(star_surf, (px - size * 2, py - size * 2))

            else:  # confetti
                confetti_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                rotated_rect = pygame.Surface((size, size * 2), pygame.SRCALPHA)
                pygame.draw.rect(rotated_rect, (*color, alpha), (0, 0, size, size * 2))
                rotation = p.get("rotation", 0) + self.animation_timer * p.get("rot_speed", 0)
                rotated = pygame.transform.rotate(rotated_rect, rotation)
                screen.blit(rotated, (px - rotated.get_width() // 2, py - rotated.get_height() // 2))

    def _draw_stage_floor(self, screen, sx, sy):
        """무대 바닥 (고퀄리티)"""
        floor_width = self.stage_width - 50
        floor_height = 35
        floor_x = sx - floor_width // 2
        floor_y = sy - 8

        floor_surf = pygame.Surface((floor_width, floor_height), pygame.SRCALPHA)

        # 그라데이션 배경
        for i in range(floor_height):
            alpha = int(100 * (1 - i / floor_height))
            pygame.draw.line(floor_surf, (50, 50, 60, alpha),
                           (0, i), (floor_width, i), 1)

        # 조명 반사 (더 화려하게)
        t = self.color_transition
        current_color = self.hologram_colors[self.current_color_index]
        next_color = self.hologram_colors[(self.current_color_index + 1) % len(self.hologram_colors)]
        reflect_color = (
            int(current_color[0] * (1 - t) + next_color[0] * t),
            int(current_color[1] * (1 - t) + next_color[1] * t),
            int(current_color[2] * (1 - t) + next_color[2] * t),
        )

        reflect_alpha = int(80 + 50 * abs(math.sin(self.animation_timer * 2.5)))
        pygame.draw.ellipse(floor_surf, (*reflect_color, reflect_alpha),
                          (floor_width // 4, 5, floor_width // 2, 20))

        # 하이라이트 스트라이프
        for i in range(5):
            stripe_x = floor_width // 6 + i * floor_width // 6
            stripe_alpha = int(60 + 40 * abs(math.sin(self.animation_timer * 3 + i)))
            pygame.draw.line(floor_surf, (255, 255, 255, stripe_alpha),
                           (stripe_x, 3), (stripe_x, floor_height - 3), 2)

        screen.blit(floor_surf, (floor_x, floor_y))

    def _draw_neon_trim(self, screen, sx, sy):
        """네온 테두리 (고퀄리티)"""
        t = self.color_transition
        current_color = self.hologram_colors[self.current_color_index]
        next_color = self.hologram_colors[(self.current_color_index + 1) % len(self.hologram_colors)]
        neon_color = (
            int(current_color[0] * (1 - t) + next_color[0] * t),
            int(current_color[1] * (1 - t) + next_color[1] * t),
            int(current_color[2] * (1 - t) + next_color[2] * t),
        )

        pulse = abs(math.sin(self.animation_timer * 3.5))
        alpha = int(180 + 75 * pulse)

        # 하단 네온 라인 (더 두껍게, 글로우 효과)
        for thickness in range(8, 0, -1):
            line_alpha = int(alpha * thickness / 8 * 0.5)
            neon_surf = pygame.Surface((self.stage_width + 20, 15), pygame.SRCALPHA)
            pygame.draw.line(neon_surf, (*neon_color, line_alpha),
                           (10, 7), (self.stage_width + 10, 7), thickness)
            screen.blit(neon_surf, (sx - self.stage_width // 2 - 10, sy + 15))

        # 측면 네온 기둥
        pillar_height = self.backdrop_height + 60
        for side in [-1, 1]:
            pillar_x = sx + side * (self.stage_width // 2)

            for thickness in range(6, 0, -1):
                line_alpha = int(alpha * thickness / 6 * 0.7)
                pillar_surf = pygame.Surface((15, pillar_height), pygame.SRCALPHA)
                pygame.draw.line(pillar_surf, (*neon_color, line_alpha),
                               (7, 0), (7, pillar_height), thickness)
                screen.blit(pillar_surf, (pillar_x - 7, sy - pillar_height + 15))

    def get_collision_rect(self):
        """충돌 영역 반환"""
        return pygame.Rect(
            self.center_x - self.stage_width // 2,
            self.center_y - self.stage_height,
            self.stage_width,
            self.stage_height + 30
        )

    def set_performance_mode(self, mode):
        """공연 모드 설정"""
        self.performance_mode = mode
        if mode == "concert":
            self.max_particles = 120
        elif mode == "dj":
            self.max_particles = 100
        else:
            self.max_particles = 80

    def is_in_exclusion_zone(self, x, y):
        """해당 좌표가 스테이지 금지 영역 내에 있는지 확인"""
        dx = x - self.center_x
        dy = y - self.center_y
        distance = math.sqrt(dx * dx + dy * dy)
        return distance < self.exclusion_radius

    def get_exclusion_zone(self):
        """금지 영역 정보 반환"""
        return {
            'center_x': self.center_x,
            'center_y': self.center_y,
            'radius': self.exclusion_radius
        }


class PerformanceStageManager:
    """
    공연 스테이지 매니저
    """

    def __init__(self):
        self.stages = []

    def create_stage_at_plaza(self, plaza_center_x, plaza_center_y):
        """광장 중앙에 스테이지 생성"""
        stage = PerformanceStage(plaza_center_x, plaza_center_y)
        self.stages.append(stage)
        return stage

    def update(self, dt):
        """모든 스테이지 업데이트"""
        for stage in self.stages:
            stage.update(dt)

    def draw(self, screen, camera_x, camera_y):
        """모든 스테이지 렌더링"""
        for stage in self.stages:
            stage.draw(screen, camera_x, camera_y)

    def get_collision_rects(self):
        """모든 스테이지 충돌 영역 반환"""
        return [stage.get_collision_rect() for stage in self.stages]

    def is_in_any_exclusion_zone(self, x, y):
        """해당 좌표가 어떤 스테이지의 금지 영역에라도 있는지 확인"""
        for stage in self.stages:
            if stage.is_in_exclusion_zone(x, y):
                return True
        return False

    def get_all_exclusion_zones(self):
        """모든 스테이지의 금지 영역 정보 반환"""
        return [stage.get_exclusion_zone() for stage in self.stages]

    def clear(self):
        """모든 스테이지 제거"""
        self.stages.clear()
