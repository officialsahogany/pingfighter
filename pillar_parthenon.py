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

    OUTER_SCENE_IMAGE = os.path.join("backgrounds", "stage9_outer_pillar_scene.jpeg")
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
        self._use_outer_scene = False
        self._outer_scene_tiles = []
        self._disable_animated_torches = False

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
        self._torch_anchor_ratio = (0.48, 0.52)

        # 필러 이미지에 박혀있는 정적 불꽃을 깨끗한 패치로 덮어 지움
        self._erase_baked_flames()

        # 인게임 맵 테두리(액자형) 프레임 오버레이
        self._field_frame_img = None
        self._build_field_frame()

    # ------------------------------------------------------------
    def _prepare_images(self):
        outer_scene = _load_image(self.OUTER_SCENE_IMAGE)
        if outer_scene is not None and self._prepare_images_from_outer_scene(outer_scene):
            return
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

    @staticmethod
    def _is_dark_pixel(pixel, threshold=18):
        return max(pixel[0], pixel[1], pixel[2]) < threshold

    def _find_longest_dark_span(self, surface, scan_y=None, scan_x=None, threshold=18):
        if scan_y is not None:
            length = surface.get_width()
            getter = lambda idx: surface.get_at((idx, scan_y))
        else:
            length = surface.get_height()
            getter = lambda idx: surface.get_at((scan_x, idx))

        best_start = 0
        best_end = 0
        run_start = None
        for idx in range(length + 1):
            is_dark = idx < length and self._is_dark_pixel(getter(idx), threshold)
            if is_dark and run_start is None:
                run_start = idx
            elif not is_dark and run_start is not None:
                if idx - run_start > best_end - best_start:
                    best_start = run_start
                    best_end = idx
                run_start = None
        return best_start, best_end

    def _prepare_images_from_outer_scene(self, raw):
        raw_w, raw_h = raw.get_size()
        if raw_w <= 0 or raw_h <= 0:
            return False

        open_x0, open_x1 = self._find_longest_dark_span(raw, scan_y=raw_h // 2)
        open_y0, open_y1 = self._find_longest_dark_span(raw, scan_x=raw_w // 2)
        open_w = open_x1 - open_x0
        open_h = open_y1 - open_y0

        if open_w < int(raw_w * 0.35) or open_h < int(raw_h * 0.35):
            return False

        target_left_w = max(0, self.game_x)
        target_right_w = max(0, self.screen_width - self.game_x - self.game_width)
        target_top_h = max(0, self.game_y)
        target_bottom_h = max(0, self.screen_height - self.game_y - self.game_height)
        if (target_left_w + target_right_w + target_top_h + target_bottom_h) <= 0:
            return False

        self._outer_scene_tiles = []
        self._use_outer_scene = True
        self._disable_animated_torches = True

        def add_tile(src_rect, dest_rect):
            sx, sy, sw, sh = src_rect
            dx, dy, dw, dh = dest_rect
            if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0:
                return
            piece = raw.subsurface(pygame.Rect(sx, sy, sw, sh)).copy()
            if piece.get_size() != (dw, dh):
                piece = pygame.transform.smoothscale(piece, (dw, dh))
            self._outer_scene_tiles.append((piece, (dx, dy)))

        game_right = self.game_x + self.game_width
        game_bottom = self.game_y + self.game_height

        add_tile((0, 0, open_x0, open_y0), (0, 0, target_left_w, target_top_h))
        add_tile((open_x0, 0, open_w, open_y0), (self.game_x, 0, self.game_width, target_top_h))
        add_tile((open_x1, 0, raw_w - open_x1, open_y0), (game_right, 0, target_right_w, target_top_h))

        add_tile((0, open_y0, open_x0, open_h), (0, self.game_y, target_left_w, self.game_height))
        add_tile((open_x1, open_y0, raw_w - open_x1, open_h), (game_right, self.game_y, target_right_w, self.game_height))

        add_tile((0, open_y1, open_x0, raw_h - open_y1), (0, game_bottom, target_left_w, target_bottom_h))
        add_tile((open_x0, open_y1, open_w, raw_h - open_y1), (self.game_x, game_bottom, self.game_width, target_bottom_h))
        add_tile((open_x1, open_y1, raw_w - open_x1, raw_h - open_y1), (game_right, game_bottom, target_right_w, target_bottom_h))

        print(
            f"[ParthenonFrame] outer pillar scene active: "
            f"opening=({open_x0},{open_y0})-({open_x1},{open_y1})"
        )
        return len(self._outer_scene_tiles) > 0

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
    FIELD_FRAME_IMAGE = os.path.join("backgrounds", "stage9_frame.jpeg")

    # 박힌 불꽃 영역(필러 스케일 기준 정규화 박스): 덮어 지울 사각형
    # (x_ratio, y_ratio, w_ratio, h_ratio) — 실제 이미지에서 불꽃 tip~base 영역
    # 횃불이 벽 쪽(바깥)에 있으므로 x는 필러 바깥쪽을 덮음
    BAKED_FLAME_BOX = (0.36, 0.33, 0.26, 0.20)
    # 클린 패치 샘플링 y(필러 높이 기준) — 횃불 아래 기둥 샤프트 영역
    CLEAN_PATCH_SOURCE_Y_RATIO = 0.70

    def _erase_baked_flames(self):
        """스케일된 좌/우 필러 이미지에서 박혀있는 횃불 정적 불꽃 영역을
        근처 클린 영역 텍스처로 덮어써서 지움. 한 번만 수행."""
        if self._disable_animated_torches:
            return

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
        if self._disable_animated_torches:
            return

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

    def _build_field_frame(self):
        """게임 영역 위에 덮을 액자형 프레임 오버레이를 로드/스케일하고,
        검정 배경을 휘도 기반 알파로 변환해 매끄럽게 투명화한다.

        주의: Gemini가 생성한 원본 JPEG는 프레임 장식 주변에 검정 마진을
        포함하는 경우가 많다. 그대로 game_width x game_height로 스케일하면
        프레임 본체가 게임 영역 안쪽에 축소되어 떠 보인다. 따라서 비-검정
        바운딩 박스를 찾아 먼저 크롭한 뒤 풀 사이즈로 스케일한다.
        """
        if self._use_outer_scene:
            self._field_frame_img = None
            return

        if self.game_width <= 0 or self.game_height <= 0:
            return

        raw = _load_image(self.FIELD_FRAME_IMAGE)
        if raw is not None and self._try_build_field_frame_from_image(raw):
            return

        self._field_frame_img = self._build_procedural_field_frame()
        return

        try:
            import pygame.surfarray as sa
            import numpy as np
        except Exception:
            # numpy 없으면 폴백: 원본 그대로 스케일 + colorkey
            scaled = pygame.transform.smoothscale(raw, (self.game_width, self.game_height))
            scaled.set_colorkey((0, 0, 0))
            self._field_frame_img = scaled
            return

        # 1) 원본에서 비-검정 픽셀 바운딩 박스 산출 (프레임 주변 검정 마진 제거)
        try:
            raw_alpha = raw.convert_alpha()
            raw_rgb = sa.pixels3d(raw_alpha)  # (W, H, 3)
            raw_lum = np.max(raw_rgb, axis=2)
            mask = raw_lum >= 18  # 검정 마진 판정 임계값은 아래 휘도 컷과 동일
            del raw_rgb
            if mask.any():
                cols = np.any(mask, axis=1)
                rows = np.any(mask, axis=0)
                x0, x1 = int(np.argmax(cols)), int(len(cols) - np.argmax(cols[::-1]))
                y0, y1 = int(np.argmax(rows)), int(len(rows) - np.argmax(rows[::-1]))
                crop_rect = pygame.Rect(x0, y0, max(1, x1 - x0), max(1, y1 - y0))
                cropped = raw_alpha.subsurface(crop_rect).copy()
            else:
                cropped = raw_alpha
        except Exception:
            cropped = raw

        # 2) 크롭된 프레임을 게임 영역 풀 사이즈로 스케일
        scaled = pygame.transform.smoothscale(cropped, (self.game_width, self.game_height))

        # 3) 휘도 기반 알파: 어두운 픽셀일수록 투명 (JPEG 압축 헤일로도 자연스럽게 페이드)
        try:
            alpha_surf = scaled.convert_alpha()
            rgb = sa.pixels3d(alpha_surf)  # (W, H, 3)
            lum = np.max(rgb, axis=2).astype(np.uint8)
            lum = np.where(lum < 18, 0, lum)
            sa.pixels_alpha(alpha_surf)[:] = lum
            del rgb
            self._field_frame_img = alpha_surf
        except Exception:
            scaled.set_colorkey((0, 0, 0))
            self._field_frame_img = scaled

    def _try_build_field_frame_from_image(self, raw):
        target_ratio = self.game_width / max(1, self.game_height)
        raw_ratio = raw.get_width() / max(1, raw.get_height())

        if abs(raw_ratio - target_ratio) > 0.08:
            print(
                f"[ParthenonFrame] stage9_frame aspect mismatch: "
                f"{raw.get_width()}x{raw.get_height()} -> "
                f"{self.game_width}x{self.game_height}; using procedural frame"
            )
            return False

        try:
            import pygame.surfarray as sa
            import numpy as np
        except Exception:
            scaled = pygame.transform.smoothscale(raw, (self.game_width, self.game_height))
            scaled.set_colorkey((0, 0, 0))
            self._field_frame_img = scaled
            return True

        try:
            raw_alpha = raw.convert_alpha()
            raw_rgb = sa.pixels3d(raw_alpha)
            raw_lum = np.max(raw_rgb, axis=2)
            lum_threshold = 18
            mask = raw_lum >= lum_threshold
            del raw_rgb

            min_col_pixels = max(8, raw_alpha.get_height() // 90)
            min_row_pixels = max(8, raw_alpha.get_width() // 90)
            col_counts = np.count_nonzero(mask, axis=1)
            row_counts = np.count_nonzero(mask, axis=0)
            cols = np.where(col_counts >= min_col_pixels)[0]
            rows = np.where(row_counts >= min_row_pixels)[0]
            if len(cols) == 0 or len(rows) == 0:
                return False

            x0 = int(cols[0])
            x1 = int(cols[-1] + 1)
            y0 = int(rows[0])
            y1 = int(rows[-1] + 1)
            crop_rect = pygame.Rect(x0, y0, max(1, x1 - x0), max(1, y1 - y0))

            crop_ratio = crop_rect.width / max(1, crop_rect.height)
            if abs(crop_ratio - target_ratio) > 0.10:
                print(
                    f"[ParthenonFrame] stage9_frame content mismatch: "
                    f"{crop_rect.width}x{crop_rect.height} for "
                    f"{self.game_width}x{self.game_height}; using procedural frame"
                )
                return False

            cropped = raw_alpha.subsurface(crop_rect).copy()
            scaled = pygame.transform.smoothscale(cropped, (self.game_width, self.game_height))

            alpha_surf = scaled.convert_alpha()
            rgb = sa.pixels3d(alpha_surf)
            lum = np.max(rgb, axis=2).astype(np.uint8)
            lum = np.where(lum < lum_threshold, 0, lum)
            sa.pixels_alpha(alpha_surf)[:] = lum
            del rgb
            self._field_frame_img = alpha_surf
            return True
        except Exception as e:
            print(f"[ParthenonFrame] stage9_frame processing fallback: {e}")
            return False

    @staticmethod
    def _blend_color(color_a, color_b, t):
        t = max(0.0, min(1.0, t))
        return tuple(
            int(color_a[i] + (color_b[i] - color_a[i]) * t)
            for i in range(len(color_a))
        )

    def _draw_meander_band(self, surface, rect, color, horizontal=True):
        if rect.width <= 0 or rect.height <= 0:
            return

        if horizontal:
            stroke = max(1, rect.height // 3)
            tile = max(rect.height * 3, stroke * 6)
            y0 = rect.top
            y1 = rect.bottom - stroke
            ym = rect.top + rect.height // 2 - stroke // 2
            x = rect.left
            while x + stroke < rect.right:
                x2 = min(rect.right - stroke, x + tile - stroke)
                xm = min(rect.right - stroke, x + tile // 2)
                points = [
                    (x, y0),
                    (x2, y0),
                    (x2, ym),
                    (xm, ym),
                    (xm, y1),
                    (x, y1),
                    (x, ym),
                    (xm, ym),
                ]
                pygame.draw.lines(surface, color, False, points, stroke)
                x += tile
        else:
            stroke = max(1, rect.width // 3)
            tile = max(rect.width * 3, stroke * 6)
            x0 = rect.left
            x1 = rect.right - stroke
            xm = rect.left + rect.width // 2 - stroke // 2
            y = rect.top
            while y + stroke < rect.bottom:
                y2 = min(rect.bottom - stroke, y + tile - stroke)
                ym = min(rect.bottom - stroke, y + tile // 2)
                points = [
                    (x0, y),
                    (x0, y2),
                    (xm, y2),
                    (xm, ym),
                    (x1, ym),
                    (x1, y),
                    (xm, y),
                    (xm, ym),
                ]
                pygame.draw.lines(surface, color, False, points, stroke)
                y += tile

    def _draw_gem_medallion(self, surface, center, radius,
                            ring_dark, ring_bright, gem_dark, gem_mid, gem_bright):
        cx, cy = center
        pygame.draw.circle(surface, ring_dark, center, radius + 2, 2)
        pygame.draw.circle(surface, ring_bright, center, radius, 1)

        leaf_color = (156, 142, 82, 180)
        leaf_w = max(4, radius // 2)
        leaf_h = max(8, radius)
        for side in (-1, 1):
            for idx in range(3):
                ly = cy + (idx - 1) * max(4, radius // 3)
                lx = cx + side * (radius + 4 + idx * max(1, radius // 5))
                leaf_rect = pygame.Rect(0, 0, leaf_w, leaf_h)
                leaf_rect.center = (lx, ly)
                pygame.draw.ellipse(surface, leaf_color, leaf_rect, 1)

        outer = [
            (cx, cy - radius + 2),
            (cx + radius - 2, cy),
            (cx, cy + radius - 2),
            (cx - radius + 2, cy),
        ]
        inner = [
            (cx, cy - max(2, radius // 2)),
            (cx + max(2, radius // 2), cy),
            (cx, cy + max(2, radius // 2)),
            (cx - max(2, radius // 2), cy),
        ]
        pygame.draw.polygon(surface, gem_dark, outer)
        pygame.draw.polygon(surface, gem_mid, inner)
        highlight = [
            (cx, cy - max(2, radius // 2)),
            (cx + max(2, radius // 4), cy - max(1, radius // 4)),
            (cx, cy),
            (cx - max(2, radius // 4), cy - max(1, radius // 4)),
        ]
        pygame.draw.polygon(surface, gem_bright, highlight)

    def _build_procedural_field_frame(self):
        w, h = self.game_width, self.game_height
        surface = pygame.Surface((w, h), pygame.SRCALPHA)

        border = max(12, min(w, h) // 36)
        outer_pad = 1
        radius = max(4, border // 2)
        outer_rect = pygame.Rect(outer_pad, outer_pad, w - outer_pad * 2, h - outer_pad * 2)

        shadow = (42, 26, 8, 150)
        dark_gold = (112, 82, 36, 235)
        mid_gold = (185, 146, 70, 242)
        bright_gold = (244, 225, 170, 250)
        aqua_dark = (17, 97, 101, 245)
        aqua_mid = (66, 202, 198, 248)
        aqua_bright = (192, 255, 249, 255)
        pattern_gold = (221, 197, 131, 228)

        for i in range(border):
            rect = outer_rect.inflate(-i * 2, -i * 2)
            if rect.width <= 0 or rect.height <= 0:
                break
            t = i / max(1, border - 1)
            if t < 0.18:
                color = self._blend_color(shadow, dark_gold, t / 0.18)
            elif t < 0.62:
                color = self._blend_color(dark_gold, mid_gold, (t - 0.18) / 0.44)
            else:
                color = self._blend_color(mid_gold, bright_gold, (t - 0.62) / 0.38)
            pygame.draw.rect(surface, color, rect, 1, border_radius=radius)

        inner_highlight_count = max(2, border // 4)
        for i in range(inner_highlight_count):
            rect = outer_rect.inflate(-(border + i) * 2, -(border + i) * 2)
            if rect.width <= 0 or rect.height <= 0:
                break
            alpha = max(40, 120 - i * 28)
            pygame.draw.rect(
                surface,
                (255, 241, 202, alpha),
                rect,
                1,
                border_radius=max(0, radius - 1),
            )

        band_h = max(6, border // 2)
        band_w = max(6, border // 2)
        corner_clearance = border * 3
        top_band = pygame.Rect(
            outer_rect.left + corner_clearance,
            outer_rect.top + max(3, border // 3),
            max(0, outer_rect.width - corner_clearance * 2),
            band_h,
        )
        bottom_band = pygame.Rect(
            outer_rect.left + corner_clearance,
            outer_rect.bottom - max(3, border // 3) - band_h,
            max(0, outer_rect.width - corner_clearance * 2),
            band_h,
        )
        left_band = pygame.Rect(
            outer_rect.left + max(3, border // 3),
            outer_rect.top + corner_clearance,
            band_w,
            max(0, outer_rect.height - corner_clearance * 2),
        )
        right_band = pygame.Rect(
            outer_rect.right - max(3, border // 3) - band_w,
            outer_rect.top + corner_clearance,
            band_w,
            max(0, outer_rect.height - corner_clearance * 2),
        )

        self._draw_meander_band(surface, top_band, pattern_gold, horizontal=True)
        self._draw_meander_band(surface, bottom_band, pattern_gold, horizontal=True)
        self._draw_meander_band(surface, left_band, pattern_gold, horizontal=False)
        self._draw_meander_band(surface, right_band, pattern_gold, horizontal=False)

        medallion_r = max(8, border)
        medallion_inset = border + medallion_r + 4
        medallion_centers = [
            (outer_rect.left + medallion_inset, outer_rect.top + medallion_inset),
            (outer_rect.right - medallion_inset, outer_rect.top + medallion_inset),
            (outer_rect.left + medallion_inset, outer_rect.bottom - medallion_inset),
            (outer_rect.right - medallion_inset, outer_rect.bottom - medallion_inset),
            (w // 2, outer_rect.top + medallion_inset - 2),
            (w // 2, outer_rect.bottom - medallion_inset + 2),
        ]
        for center in medallion_centers:
            self._draw_gem_medallion(
                surface,
                center,
                medallion_r,
                dark_gold,
                bright_gold,
                aqua_dark,
                aqua_mid,
                aqua_bright,
            )

        return surface

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
        if self._use_outer_scene and self._outer_scene_tiles:
            for tile, pos in self._outer_scene_tiles:
                screen.blit(tile, pos)
            return

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

        # 4) 횃불 플리커 (좌/우 필러의 박혀있는 횃불 위에 덮어씀)
        self._draw_torch_flames(screen)

        # NOTE: 인게임 맵 액자 프레임은 여기서 그리면 이후 게임 영역 blit에 덮여
        # 안 보인다. 게임 렌더 이후 REAL_SCREEN 위에 별도로 덮도록
        # draw_field_frame_overlay()로 분리했다.

    def draw_field_frame_overlay(self, screen):
        """게임 영역 blit 이후 REAL_SCREEN 위에 덮는 액자형 프레임 오버레이."""
        if self._field_frame_img is not None:
            screen.blit(self._field_frame_img, (self.game_x, self.game_y))
