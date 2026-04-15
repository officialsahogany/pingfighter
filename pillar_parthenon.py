# -*- coding: utf-8 -*-
"""
그리스 파르테논 신전 스타일 필러 배경 (Stage 9) — v6 Aquamarine Image-based

이미지 3장 기반:
- backgrounds/stage9_pillar_left.jpeg   : 좌측 필러 (우측 flip으로 우측 필러 사용)
- backgrounds/stage9_frieze_top.jpeg    : 상단 프레임 (펜디먼트 + 월계관 + 덴틸)
- backgrounds/stage9_frieze_bottom.jpeg : 하단 프레임 (스타일로베이트 + 계단 베이스)

아쿠아마린 크리스털 기둥 테마. 동적 이펙트(별 트윙클, god ray)는 이미지 위에 얹음.
"""

import math
import os
import random
import sys

import pygame


def _resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


def _load_image(rel_path):
    path = _resource_path(rel_path)
    if not os.path.exists(path):
        print(f"[ParthenonFrame] 경고: 이미지 없음 → {path}")
        return None
    try:
        return pygame.image.load(path).convert_alpha()
    except Exception as e:
        print(f"[ParthenonFrame] 이미지 로드 실패 ({rel_path}): {e}")
        return None


class ParthenonFrame:
    """파르테논 필러 v6 — 이미지 기반 (아쿠아마린) + 상/하단 프리즈 + 동적 오버레이"""

    PILLAR_IMAGE = os.path.join("backgrounds", "stage9_pillar_left.jpeg")
    TOP_IMAGE = os.path.join("backgrounds", "stage9_frieze_top.jpeg")
    BOTTOM_IMAGE = os.path.join("backgrounds", "stage9_frieze_bottom.jpeg")

    # 기둥 이미지 중 콘텐츠 영역 비율 (우측 검정 페이드 제외)
    PILLAR_CONTENT_RATIO = 0.62
    # 상/하단 프리즈 이미지 좌우 검정 페이드 제외 비율
    FRIEZE_CONTENT_RATIO_H = 0.92  # 좌/우 각각 ~4%씩 페이드 가정

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int,
                 offset_x: int = None, offset_y: int = None,
                 original_game_width: int = None, original_game_height: int = None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.game_x = offset_x if offset_x is not None else (screen_width - game_width) // 2
        self.game_y = offset_y if offset_y is not None else (screen_height - game_height) // 2

        self.left_pillar_w = max(1, self.game_x)
        self.right_pillar_w = max(1, self.screen_width - self.game_x - self.game_width)
        self.top_strip_h = max(0, self.game_y)
        self.bottom_strip_h = max(0, self.screen_height - self.game_y - self.game_height)

        self.time = 0.0

        # 이미지 준비
        self._left_pillar_img = None
        self._right_pillar_img = None
        self._top_frieze_img = None
        self._bottom_frieze_img = None
        self._prepare_images()

        # 별 트윙클
        self._stars = []
        self._init_stars()

        # 신성광
        self._god_ray_alpha_steps = []
        self._god_ray_step_count = 8
        self._build_god_rays()

        # 횃불 애니메이션 (좌/우 필러)
        self._flame_frames = []          # 사전 렌더된 불꽃 프레임 리스트
        self._flame_glow = None          # 하단 발광 헤일로
        self._flame_w = 0
        self._flame_h = 0
        self._build_flame_sprites()
        # 각 횃불의 랜덤 페이즈/속도 (좌우 독립 플리커)
        self._torch_states = [
            {'phase': random.uniform(0, math.tau), 'speed': random.uniform(11.0, 14.5),
             'glow_phase': random.uniform(0, math.tau), 'glow_speed': random.uniform(3.2, 4.8)},
            {'phase': random.uniform(0, math.tau), 'speed': random.uniform(11.0, 14.5),
             'glow_phase': random.uniform(0, math.tau), 'glow_speed': random.uniform(3.2, 4.8)},
        ]
        # 필러 이미지 기준 횃불 위치(정규화): (x_ratio_in_pillar_content, y_ratio_of_screen_height)
        # 이미지에서 불꽃 팁 중심이 대략 x=15%, y=38% 위치
        self._torch_anchor_ratio = (0.15, 0.38)

    # ------------------------------------------------------------
    def _prepare_images(self):
        # 기둥
        raw = _load_image(self.PILLAR_IMAGE)
        if raw is not None:
            img_w, img_h = raw.get_size()
            content_w = int(img_w * self.PILLAR_CONTENT_RATIO)
            content = raw.subsurface(pygame.Rect(0, 0, content_w, img_h)).copy()
            if self.left_pillar_w > 0:
                self._left_pillar_img = pygame.transform.smoothscale(
                    content, (self.left_pillar_w, self.screen_height))
            if self.right_pillar_w > 0:
                right_scaled = pygame.transform.smoothscale(
                    content, (self.right_pillar_w, self.screen_height))
                self._right_pillar_img = pygame.transform.flip(right_scaled, True, False)

        # 상단 프리즈 — 필러 사이(게임 영역 위) 영역에 채움
        top_raw = _load_image(self.TOP_IMAGE)
        if top_raw is not None and self.top_strip_h > 0:
            img_w, img_h = top_raw.get_size()
            # 좌우 페이드 제외 중앙 콘텐츠
            margin = int(img_w * (1 - self.FRIEZE_CONTENT_RATIO_H) * 0.5)
            content_rect = pygame.Rect(margin, 0, img_w - margin * 2, img_h)
            content = top_raw.subsurface(content_rect).copy()
            self._top_frieze_img = pygame.transform.smoothscale(
                content, (self.game_width, self.top_strip_h))

        # 하단 프리즈
        bot_raw = _load_image(self.BOTTOM_IMAGE)
        if bot_raw is not None and self.bottom_strip_h > 0:
            img_w, img_h = bot_raw.get_size()
            margin = int(img_w * (1 - self.FRIEZE_CONTENT_RATIO_H) * 0.5)
            content_rect = pygame.Rect(margin, 0, img_w - margin * 2, img_h)
            content = bot_raw.subsurface(content_rect).copy()
            self._bottom_frieze_img = pygame.transform.smoothscale(
                content, (self.game_width, self.bottom_strip_h))

    def _init_stars(self):
        sky_h = max(40, self.game_y)
        for _ in range(25):
            x = random.randint(0, self.screen_width)
            y = random.randint(0, sky_h)
            self._stars.append({
                'x': x, 'y': y,
                'r': random.choice([1, 1, 2]),
                'phase': random.uniform(0, math.tau),
                'speed': random.uniform(0.6, 2.4),
                'base': random.randint(130, 210),
                'warm': random.random() < 0.20,
            })

    def _build_god_rays(self):
        sw, sh = self.screen_width, self.screen_height
        surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
        ray_origins = [
            (self.left_pillar_w + int(self.game_width * 0.22), 0),
            (self.left_pillar_w + int(self.game_width * 0.50), 0),
            (self.left_pillar_w + int(self.game_width * 0.78), 0),
        ]
        # 아쿠아마린 테마에 맞춰 쿨톤 빛줄기
        ray_color = (180, 230, 245)
        for sx, sy in ray_origins:
            for k in range(0, 50, 2):
                ratio = k / 50.0
                a = int(22 * (1 - ratio) ** 1.4)
                if a <= 0:
                    continue
                offset = k - 25
                pygame.draw.line(surf, (*ray_color, a),
                                 (sx + offset, sy),
                                 (sx + offset // 2 + 12, sh), 1)

        for i in range(self._god_ray_step_count):
            step_surf = surf.copy()
            t = i / max(1, self._god_ray_step_count - 1)
            alpha = int(40 + (105 - 40) * t)
            step_surf.set_alpha(alpha)
            self._god_ray_alpha_steps.append(step_surf)

    # ------------------------------------------------------------
    def _build_flame_sprites(self):
        """불꽃 프레임(8장) + 헤일로 사전 렌더. 불꽃 크기는 필러 너비에 비례."""
        base_w = max(self.left_pillar_w, self.right_pillar_w, 40)
        # 불꽃 스프라이트 크기
        fw = max(24, int(base_w * 0.36))
        fh = int(fw * 1.7)
        self._flame_w, self._flame_h = fw, fh

        frame_count = 8
        rng = random.Random(9109)  # 재현 가능한 흔들림
        for fi in range(frame_count):
            surf = pygame.Surface((fw, fh), pygame.SRCALPHA)
            # 불꽃 레이어(외곽→내부) — 타원 겹쳐 올리기
            # 바닥 중심을 하단 중앙으로, 위로 길쭉하게
            bx = fw // 2
            by = int(fh * 0.90)
            # 각 프레임마다 흔들림 파라미터
            sway = rng.uniform(-0.08, 0.08)      # 좌우 기울기
            stretch = 1.0 + rng.uniform(-0.12, 0.15)  # 세로 스트레치
            wobble = rng.uniform(-0.10, 0.10)    # 상단 좌우 이탈

            layers = [
                # (색, 알파, 너비 배율, 높이 배율)
                ((255, 100, 30), 110, 0.95, 1.00),  # 외곽 오렌지
                ((255, 150, 40), 160, 0.78, 0.88),  # 중간 오렌지
                ((255, 200, 70), 200, 0.58, 0.72),  # 밝은 노랑
                ((255, 240, 170), 230, 0.38, 0.55), # 코어 크림
                ((255, 255, 230), 250, 0.20, 0.35), # 하이라이트
            ]
            for color, alpha, wr, hr in layers:
                lw = max(2, int(fw * wr))
                lh = max(4, int(fh * hr * stretch))
                # 상단이 옆으로 살짝 휘도록 다중 타원으로 그림
                segments = 6
                for s in range(segments):
                    t = s / (segments - 1)
                    cx = int(bx + sway * lh * t + wobble * lh * (t ** 2) * (1 - t) * 4)
                    cy = int(by - lh * (0.15 + 0.85 * t))
                    seg_w = int(lw * (1.0 - t * 0.75))
                    seg_h = max(3, int(lh * 0.35 * (1.0 - t * 0.55)))
                    rect = pygame.Rect(cx - seg_w // 2, cy - seg_h // 2, seg_w, seg_h)
                    col = (*color, alpha)
                    pygame.draw.ellipse(surf, col, rect)
            self._flame_frames.append(surf)

        # 헤일로(발광) — 불꽃 주변 따뜻한 빛
        gw, gh = fw * 2, fh * 2
        glow = pygame.Surface((gw, gh), pygame.SRCALPHA)
        gcx, gcy = gw // 2, int(gh * 0.55)
        for r, a in ((int(fw * 1.05), 12), (int(fw * 0.85), 20),
                     (int(fw * 0.65), 32), (int(fw * 0.45), 50),
                     (int(fw * 0.28), 70)):
            pygame.draw.circle(glow, (255, 170, 90, a), (gcx, gcy), r)
        self._flame_glow = glow

    def _draw_torch_flames(self, screen):
        if not self._flame_frames:
            return
        fw, fh = self._flame_w, self._flame_h
        ax, ay = self._torch_anchor_ratio
        flame_y = int(self.screen_height * ay)

        # 좌측 횃불 기준점 (필러 이미지 내부 x)
        left_torch_x = int(self.left_pillar_w * ax)
        # 우측 필러는 flip되어 있으므로 좌우 대칭 위치
        right_pillar_start = self.screen_width - self.right_pillar_w
        right_torch_x = right_pillar_start + int(self.right_pillar_w * (1.0 - ax))

        for idx, tx in enumerate((left_torch_x, right_torch_x)):
            st = self._torch_states[idx]
            # 플리커: 빠른 랜덤한 프레임 전환 + 부드러운 알파 펄스
            phase = self.time * st['speed'] + st['phase']
            # 8프레임을 비선형적으로 넘김(두 사인 합성으로 자연스러운 떨림)
            fidx = int((math.sin(phase) * 0.5 + math.sin(phase * 1.73 + 1.1) * 0.5 + 1.0)
                       * 0.5 * len(self._flame_frames)) % len(self._flame_frames)
            frame = self._flame_frames[fidx]

            # 알파/수직 오프셋 흔들림
            flicker = 0.5 + 0.5 * math.sin(phase * 0.8 + 0.3)
            alpha = int(210 + flicker * 45)
            y_jitter = int(math.sin(phase * 1.9) * 1.5)

            # 헤일로 먼저 (가산 블렌딩)
            glow_pulse = 0.5 + 0.5 * math.sin(self.time * st['glow_speed'] + st['glow_phase'])
            glow_alpha = int(70 + glow_pulse * 85)
            self._flame_glow.set_alpha(glow_alpha)
            gw, gh = self._flame_glow.get_size()
            screen.blit(self._flame_glow,
                        (tx - gw // 2, flame_y - int(gh * 0.55) + y_jitter),
                        special_flags=pygame.BLEND_ADD)

            # 불꽃 본체
            frame.set_alpha(alpha)
            screen.blit(frame, (tx - fw // 2, flame_y - int(fh * 0.90) + y_jitter))

    def update(self, dt):
        self.time += dt

    def draw(self, screen):
        # 1) 좌/우 필러
        if self._left_pillar_img is not None:
            screen.blit(self._left_pillar_img, (0, 0))
        if self._right_pillar_img is not None:
            screen.blit(self._right_pillar_img,
                        (self.screen_width - self.right_pillar_w, 0))

        # 2) 상단 프리즈 (필러 사이, 게임 영역 위)
        if self._top_frieze_img is not None:
            screen.blit(self._top_frieze_img, (self.game_x, 0))

        # 3) 하단 프리즈 (필러 사이, 게임 영역 아래)
        if self._bottom_frieze_img is not None:
            screen.blit(self._bottom_frieze_img,
                        (self.game_x, self.game_y + self.game_height))

        # 4) 별 트윙클 오버레이
        for s in self._stars:
            br = s['base'] + int(55 * math.sin(self.time * s['speed'] + s['phase']))
            br = max(60, min(255, br))
            if s.get('warm'):
                color = (br, int(br * 0.88), int(br * 0.60))
            else:
                color = (br, br, min(255, br + 25))
            pygame.draw.circle(screen, color, (s['x'], s['y']), s['r'])

        # 5) 신성광 (아쿠아마린 쿨톤)
        if self._god_ray_alpha_steps:
            pulse = 0.5 + 0.5 * math.sin(self.time * 0.5)
            idx = int(pulse * (self._god_ray_step_count - 1))
            screen.blit(self._god_ray_alpha_steps[idx], (0, 0),
                        special_flags=pygame.BLEND_ADD)

        # 6) 횃불 플리커 (좌/우 필러의 박혀있는 횃불 위에 덮어씀)
        self._draw_torch_flames(screen)
