# -*- coding: utf-8 -*-
"""Stage 6 Honglyeon boss sprite support."""

import os
import sys

import numpy as np
import pygame


def resource_path(relative_path: str) -> str:
    """Resolve resources for both dev runs and PyInstaller builds."""
    try:
        base_path = sys._MEIPASS  # type: ignore[attr-defined]
    except Exception:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    normalized = relative_path.replace("/", os.sep).replace("\\", os.sep)
    return os.path.join(base_path, normalized)


class HonglyeonBossSprite:
    """4x2 sprite-sheet walker with optional attack animation."""

    SHEET_PATH_PNG = os.path.join("items", "honglyeon_boss_sheet.png")
    SHEET_PATH_JPEG = os.path.join("items", "honglyeon_boss_sheet.jpeg")
    ATTACK_SHEET_PATH_PNG = os.path.join("items", "honglyeon_boss_attack.png")
    ATTACK_SHEET_PATH_JPEG = os.path.join("items", "honglyeon_boss_attack.jpeg")
    GRID_COLS = 4
    GRID_ROWS = 2
    FRAME_ORDER = (
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1), (2, 1), (3, 1),
    )
    FRAME_DURATION = 0.10
    ATTACK_FRAME_DURATION = 0.055
    LIGHT_BG_TOLERANCE = 18
    FRAME_INSET = 14
    OUTLINE_MARGIN = 2
    OUTLINE_COLOR = (10, 8, 8)
    EDGE_HALO_RGB_MIN = 228
    EDGE_HALO_SATURATION = 42
    EDGE_HALO_MIN_ALPHA = 1
    EDGE_HALO_SOFT_ALPHA = 160

    def __init__(self, width: int = 95, height: int = 86):
        self.target_w = width
        self.target_h = height
        self._frames_right: list[pygame.Surface] = []
        self._frames_left: list[pygame.Surface] = []
        self._attack_frames_right: list[pygame.Surface] = []
        self._attack_frames_left: list[pygame.Surface] = []

        self.anim_time = 0.0
        self.frame_index = 0
        self.facing = "right"
        self.is_moving = False

        self.is_attacking = False
        self.attack_time = 0.0
        self.attack_frame_index = 0

        self._load_frames()
        self._load_attack_frames()

    def _load_frames(self) -> None:
        png_path = resource_path(self.SHEET_PATH_PNG)
        jpeg_path = resource_path(self.SHEET_PATH_JPEG)
        if os.path.exists(png_path):
            path = png_path
            use_png = True
        elif os.path.exists(jpeg_path):
            path = jpeg_path
            use_png = False
        else:
            print(f"[HonglyeonBossSprite] Missing sprite sheet: {png_path} / {jpeg_path}")
            return

        try:
            sheet = pygame.image.load(path).convert_alpha()
        except Exception as exc:
            print(f"[HonglyeonBossSprite] Load failed: {exc}")
            return

        if not use_png:
            sheet = self._remove_light_background(sheet)

        sheet_w, sheet_h = sheet.get_size()
        cell_w = sheet_w // self.GRID_COLS
        cell_h = sheet_h // self.GRID_ROWS
        inset_x = min(self.FRAME_INSET, max(2, cell_w // 32))
        inset_y = min(self.FRAME_INSET, max(2, cell_h // 32))

        for col, row in self.FRAME_ORDER:
            rect = pygame.Rect(
                col * cell_w + inset_x,
                row * cell_h + inset_y,
                max(1, cell_w - inset_x * 2),
                max(1, cell_h - inset_y * 2),
            )
            frame = sheet.subsurface(rect).copy()
            frame = self._cleanup_edge_halo(frame)
            frame = self._trim_to_visible_bounds(frame)
            frame = self._scale_to_target(frame)
            self._frames_right.append(frame)
            self._frames_left.append(pygame.transform.flip(frame, True, False))

    def _load_attack_frames(self) -> None:
        png_path = resource_path(self.ATTACK_SHEET_PATH_PNG)
        jpeg_path = resource_path(self.ATTACK_SHEET_PATH_JPEG)
        if os.path.exists(png_path):
            path = png_path
            use_png = True
        elif os.path.exists(jpeg_path):
            path = jpeg_path
            use_png = False
        else:
            return

        try:
            sheet = pygame.image.load(path).convert_alpha()
        except Exception as exc:
            print(f"[HonglyeonBossSprite] Attack load failed: {exc}")
            return

        if not use_png:
            sheet = self._remove_light_background(sheet)

        sheet_w, sheet_h = sheet.get_size()
        cell_w = sheet_w // self.GRID_COLS
        cell_h = sheet_h // self.GRID_ROWS
        inset_x = min(self.FRAME_INSET, max(2, cell_w // 32))
        inset_y = min(self.FRAME_INSET, max(2, cell_h // 32))

        for col, row in self.FRAME_ORDER:
            rect = pygame.Rect(
                col * cell_w + inset_x,
                row * cell_h + inset_y,
                max(1, cell_w - inset_x * 2),
                max(1, cell_h - inset_y * 2),
            )
            frame = sheet.subsurface(rect).copy()
            frame = self._cleanup_edge_halo(frame)
            frame = self._trim_to_visible_bounds(frame)
            frame = self._scale_to_target(frame)
            self._attack_frames_right.append(frame)
            self._attack_frames_left.append(pygame.transform.flip(frame, True, False))

    def _remove_light_background(self, surface: pygame.Surface) -> pygame.Surface:
        cleaned = surface.copy().convert_alpha()
        rgb = pygame.surfarray.pixels3d(cleaned)
        alpha = pygame.surfarray.pixels_alpha(cleaned)
        tol = self.LIGHT_BG_TOLERANCE
        mask = (
            (rgb[:, :, 0] >= 255 - tol)
            & (rgb[:, :, 1] >= 255 - tol)
            & (rgb[:, :, 2] >= 255 - tol)
        )
        alpha[mask] = 0
        del rgb, alpha
        return cleaned

    def _trim_to_visible_bounds(self, frame: pygame.Surface) -> pygame.Surface:
        mask = pygame.mask.from_surface(frame)
        rects = mask.get_bounding_rects()
        if not rects:
            return frame

        bounds = rects[0].copy()
        for rect in rects[1:]:
            bounds.union_ip(rect)
        return frame.subsurface(bounds).copy()

    def _cleanup_edge_halo(self, frame: pygame.Surface) -> pygame.Surface:
        cleaned = frame.copy().convert_alpha()
        alpha = pygame.surfarray.pixels_alpha(cleaned)
        rgb = pygame.surfarray.pixels3d(cleaned)
        visible = alpha >= self.EDGE_HALO_MIN_ALPHA
        if not np.any(visible):
            del rgb, alpha
            return cleaned

        transparent = ~visible
        touch_bg = np.zeros_like(visible)
        touch_bg[1:, :] |= transparent[:-1, :]
        touch_bg[:-1, :] |= transparent[1:, :]
        touch_bg[:, 1:] |= transparent[:, :-1]
        touch_bg[:, :-1] |= transparent[:, 1:]
        touch_bg[1:, 1:] |= transparent[:-1, :-1]
        touch_bg[1:, :-1] |= transparent[:-1, 1:]
        touch_bg[:-1, 1:] |= transparent[1:, :-1]
        touch_bg[:-1, :-1] |= transparent[1:, 1:]

        min_rgb = np.minimum(np.minimum(rgb[:, :, 0], rgb[:, :, 1]), rgb[:, :, 2])
        max_rgb = np.maximum(np.maximum(rgb[:, :, 0], rgb[:, :, 1]), rgb[:, :, 2])
        low_sat = (max_rgb - min_rgb) <= self.EDGE_HALO_SATURATION
        near_white = min_rgb >= self.EDGE_HALO_RGB_MIN

        hard_halo = visible & touch_bg & near_white & low_sat
        alpha[hard_halo] = 0

        soft_halo = (alpha > 0) & touch_bg & (alpha < 255)
        alpha[soft_halo] = np.minimum(alpha[soft_halo], self.EDGE_HALO_SOFT_ALPHA)

        del rgb, alpha
        return cleaned

    def _scale_to_target(self, frame: pygame.Surface) -> pygame.Surface:
        src_w, src_h = frame.get_size()
        if src_w <= 0 or src_h <= 0:
            return frame

        inner_w = max(1, self.target_w - self.OUTLINE_MARGIN * 2)
        inner_h = max(1, self.target_h - self.OUTLINE_MARGIN * 2)
        scale = min(inner_w / src_w, inner_h / src_h)
        dst_w = max(1, int(round(src_w * scale)))
        dst_h = max(1, int(round(src_h * scale)))
        scaled = pygame.transform.scale(frame, (dst_w, dst_h))
        canvas = pygame.Surface((self.target_w, self.target_h), pygame.SRCALPHA)
        canvas.blit(
            scaled,
            scaled.get_rect(center=(self.target_w // 2, self.target_h // 2)),
        )
        canvas = self._cleanup_edge_halo(canvas)
        return self._add_outer_outline(canvas)

    def _add_outer_outline(self, frame: pygame.Surface) -> pygame.Surface:
        result = frame.copy().convert_alpha()
        alpha = pygame.surfarray.pixels_alpha(result)
        rgb = pygame.surfarray.pixels3d(result)
        opaque = alpha > 0

        dilated = opaque.copy()
        dilated[1:, :] |= opaque[:-1, :]
        dilated[:-1, :] |= opaque[1:, :]
        dilated[:, 1:] |= opaque[:, :-1]
        dilated[:, :-1] |= opaque[:, 1:]
        dilated[1:, 1:] |= opaque[:-1, :-1]
        dilated[1:, :-1] |= opaque[:-1, 1:]
        dilated[:-1, 1:] |= opaque[1:, :-1]
        dilated[:-1, :-1] |= opaque[1:, 1:]

        outline = dilated & ~opaque
        if np.any(outline):
            rgb[outline] = self.OUTLINE_COLOR
            alpha[outline] = 255

        del rgb, alpha
        return result

    def update(self, dt: float, moving: bool = True, facing: str | None = None) -> None:
        if facing in ("left", "right"):
            self.facing = facing
        self.is_moving = moving

        if self.is_attacking and self._attack_frames_right:
            self.attack_time += max(0.0, dt)
            total_frames = len(self._attack_frames_right)
            while self.attack_time >= self.ATTACK_FRAME_DURATION:
                self.attack_time -= self.ATTACK_FRAME_DURATION
                self.attack_frame_index += 1
                if self.attack_frame_index >= total_frames:
                    self.is_attacking = False
                    self.attack_frame_index = 0
                    self.attack_time = 0.0
                    break
            return

        if not self._frames_right:
            return

        if moving:
            self.anim_time += max(0.0, dt)
            while self.anim_time >= self.FRAME_DURATION:
                self.anim_time -= self.FRAME_DURATION
                self.frame_index = (self.frame_index + 1) % len(self._frames_right)
        else:
            self.anim_time = 0.0
            self.frame_index = 0

    def trigger_attack(self, start_frame: int = 0) -> None:
        if self.is_attacking or not self._attack_frames_right:
            return
        self.is_attacking = True
        max_index = len(self._attack_frames_right) - 1
        self.attack_frame_index = max(0, min(start_frame, max_index))
        self.attack_time = 0.0

    def get_current_frame(self, size: tuple[int, int] | None = None) -> pygame.Surface | None:
        if self.is_attacking and self._attack_frames_right:
            frames = self._attack_frames_left if self.facing == "left" else self._attack_frames_right
            frame = frames[min(self.attack_frame_index, len(frames) - 1)]
        else:
            frames = self._frames_left if self.facing == "left" else self._frames_right
            if not frames:
                return None
            frame = frames[self.frame_index]

        if size is None or frame.get_size() == size:
            return frame
        return pygame.transform.scale(frame, size)

    def get_preview_frame(
        self,
        facing: str = "right",
        size: tuple[int, int] | None = None,
    ) -> pygame.Surface | None:
        frames = self._frames_left if facing == "left" else self._frames_right
        if not frames:
            return None
        frame = frames[0]
        if size is None or frame.get_size() == size:
            return frame
        return pygame.transform.scale(frame, size)

    def draw(self, screen: pygame.Surface, cx: float, cy: float) -> None:
        frame = self.get_current_frame()
        if frame is None:
            return
        rect = frame.get_rect(center=(int(cx), int(cy)))
        screen.blit(frame, rect)

    def get_size(self) -> tuple[int, int]:
        frame = self.get_current_frame()
        if frame is None:
            return (self.target_w, self.target_h)
        return frame.get_size()


_honglyeon_boss_sprite_instance: HonglyeonBossSprite | None = None


def get_honglyeon_boss_sprite() -> HonglyeonBossSprite:
    global _honglyeon_boss_sprite_instance
    if _honglyeon_boss_sprite_instance is None:
        _honglyeon_boss_sprite_instance = HonglyeonBossSprite()
    return _honglyeon_boss_sprite_instance


def init_honglyeon_boss_sprite(width: int = 95, height: int = 86) -> HonglyeonBossSprite:
    global _honglyeon_boss_sprite_instance
    _honglyeon_boss_sprite_instance = HonglyeonBossSprite(width=width, height=height)
    return _honglyeon_boss_sprite_instance


def reset_honglyeon_boss_sprite() -> None:
    global _honglyeon_boss_sprite_instance
    _honglyeon_boss_sprite_instance = None
