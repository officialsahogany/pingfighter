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
        # 필러 이미지 기준 횃불 잔받침 꼭대기 위치(정규화)
        # (x_ratio_in_pillar, y_ratio_of_screen_height) — 애니메이션 스프라이트의 불꽃 밑변이 여기 옴
        # 좌필러 기준 x: 작을수록 화면 바깥쪽(벽 반대), 우필러는 (1-x)로 자동 미러
        self._torch_anchor_ratio = (0.15, 0.52)

        # 필러 이미지에 박혀있는 정적 불꽃을 깨끗한 패치로 덮어 지움
        self._erase_baked_flames()

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
    FLAME_SHEET_IMAGE = os.path.join("backgrounds", "stage9_flame_sheet.jpeg")
    FLAME_FRAME_COUNT = 6

    # 박힌 불꽃 영역(필러 스케일 기준 정규화 박스): 덮어 지울 사각형
    # (x_ratio, y_ratio, w_ratio, h_ratio) — 실제 이미지에서 불꽃 tip~base 영역
    # 횃불이 벽 쪽(바깥)에 있으므로 x는 필러 바깥쪽을 덮음
    BAKED_FLAME_BOX = (0.04, 0.33, 0.26, 0.20)
    # 클린 패치 샘플링 y(필러 높이 기준) — 횃불 아래 기둥 샤프트 영역
    CLEAN_PATCH_SOURCE_Y_RATIO = 0.70

    def _erase_baked_flames(self):
        """스케일된 좌/우 필러 이미지에서 박혀있는 횃불 정적 불꽃 영역을
        근처 클린 영역 텍스처로 덮어써서 지움. 한 번만 수행."""
        for is_right, img in ((False, self._left_pillar_img), (True, self._right_pillar_img)):
            if img is None:
                continue
            pw, ph = img.get_size()
            fx, fy, fw_r, fh_r = self.BAKED_FLAME_BOX
            rw = max(4, int(pw * fw_r))
            rh = max(4, int(ph * fh_r))
            # 좌/우 대칭 처리: 우측은 flip된 필러 이미지라 원본 x가 반대에 옴 → 같은 좌표로 OK
            # (flip 후 좌표계 기준 동일 비율 위치가 횃불 자리)
            rx = int(pw * fx)
            ry = int(ph * fy)
            # 경계 클리핑
            dst_rect = pygame.Rect(rx, ry, rw, rh).clip(img.get_rect())
            if dst_rect.width <= 0 or dst_rect.height <= 0:
                continue
            # 소스 패치: 같은 x, 더 아래쪽 y
            sy = int(ph * self.CLEAN_PATCH_SOURCE_Y_RATIO)
            src_rect = pygame.Rect(rx, sy, dst_rect.width, dst_rect.height).clip(img.get_rect())
            if src_rect.width <= 0 or src_rect.height <= 0:
                continue
            patch = img.subsurface(src_rect).copy()
            # 패치 크기가 dst와 다를 수 있으니 맞춤
            if patch.get_size() != dst_rect.size:
                patch = pygame.transform.smoothscale(patch, dst_rect.size)
            # 깃털 마스크: 가장자리 페이드로 자연스럽게 합성
            mask = pygame.Surface(dst_rect.size, pygame.SRCALPHA)
            feather = 6
            inner = pygame.Rect(feather, feather,
                                max(1, dst_rect.width - feather * 2),
                                max(1, dst_rect.height - feather * 2))
            # 중앙부 불투명
            pygame.draw.rect(mask, (255, 255, 255, 255), inner)
            # 바깥 테두리 단계적 알파
            for i in range(feather):
                a = int(255 * (1 - (i + 1) / (feather + 1)))
                r = pygame.Rect(feather - i - 1, feather - i - 1,
                                dst_rect.width - 2 * (feather - i - 1),
                                dst_rect.height - 2 * (feather - i - 1))
                pygame.draw.rect(mask, (255, 255, 255, a), r, 1)
            # mask를 알파 채널로 사용하여 patch에 곱하기
            patch.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
            img.blit(patch, dst_rect.topleft)

    def _build_flame_sprites(self):
        """일러스트 불꽃 스프라이트시트(6프레임) 로드 + 프레임별 리사이즈.
        검정 배경은 BLEND_ADD로 자연스럽게 투명화되어 필러 위에 가산 발광."""
        sheet = _load_image(self.FLAME_SHEET_IMAGE)
        if sheet is None:
            return

        sheet_w, sheet_h = sheet.get_size()
        frame_src_w = sheet_w // self.FLAME_FRAME_COUNT
        frame_src_h = sheet_h

        # 불꽃 크기는 필러 너비에 비례
        base_w = max(self.left_pillar_w, self.right_pillar_w, 40)
        fw = max(28, int(base_w * 0.46))
        fh = int(fw * frame_src_h / max(1, frame_src_w))
        self._flame_w, self._flame_h = fw, fh

        for i in range(self.FLAME_FRAME_COUNT):
            src = sheet.subsurface(pygame.Rect(i * frame_src_w, 0,
                                               frame_src_w, frame_src_h)).copy()
            scaled = pygame.transform.smoothscale(src, (fw, fh))
            self._flame_frames.append(scaled)

        # 하단 발광 헤일로(따뜻한 빛) — 필러에 빛 반사
        gw, gh = fw * 2, fh * 2
        glow = pygame.Surface((gw, gh), pygame.SRCALPHA)
        gcx, gcy = gw // 2, int(gh * 0.55)
        for r, a in ((int(fw * 1.05), 12), (int(fw * 0.85), 20),
                     (int(fw * 0.65), 30), (int(fw * 0.45), 46),
                     (int(fw * 0.28), 64)):
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
            # 플리커: 시간 기반 프레임 전환(약 12fps 기본 + 미세 지터)
            phase = self.time * st['speed'] + st['phase']
            fidx = int(self.time * 10.0 + st['phase'] * 2.0) % len(self._flame_frames)
            frame = self._flame_frames[fidx]

            # 알파/수직 오프셋 흔들림
            flicker = 0.5 + 0.5 * math.sin(phase * 0.7 + 0.3)
            alpha = int(180 + flicker * 60)  # 180 ~ 240
            y_jitter = int(math.sin(phase * 1.6) * 2.0)

            # 불꽃 본체 — BLEND_ADD로 검정 배경 자동 투명 + 기존 박힌 불꽃과 가산 합성
            frame.set_alpha(alpha)
            screen.blit(frame, (tx - fw // 2, flame_y - int(fh * 0.85) + y_jitter),
                        special_flags=pygame.BLEND_ADD)

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
