# -*- coding: utf-8 -*-
"""Stage 3 menhera-girl boss sprite support."""

import os
import sys

import pygame


def resource_path(relative_path: str) -> str:
    """Resolve resources for both dev runs and PyInstaller builds."""
    try:
        base_path = sys._MEIPASS  # type: ignore[attr-defined]
    except Exception:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    normalized = relative_path.replace("/", os.sep).replace("\\", os.sep)
    return os.path.join(base_path, normalized)


class MenheraBossSprite:
    """4x2 sprite-sheet walker with left/right facing for stage 3 menhera girl."""

    SHEET_PATH_PNG = os.path.join("items", "menhera_boss_sheet.png")
    SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_sheet.jpeg")
    GRID_COLS = 4
    GRID_ROWS = 2
    FRAME_ORDER = (
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1), (2, 1), (3, 1),
    )
    FRAME_DURATION = 0.10
    LIGHT_BG_TOLERANCE = 22
    FRAME_INSET = 14

    def __init__(self, width: int = 72, height: int = 80):
        self.target_w = width
        self.target_h = height
        self._frames_right: list[pygame.Surface] = []
        self._frames_left: list[pygame.Surface] = []
        self.anim_time = 0.0
        self.frame_index = 0
        self.facing = "right"
        self.is_moving = False
        self._load_frames()

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
            print(f"[MenheraBossSprite] Missing sprite sheet: {png_path} / {jpeg_path}")
            return

        try:
            sheet = pygame.image.load(path).convert_alpha()
        except Exception as exc:
            print(f"[MenheraBossSprite] Load failed: {exc}")
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
            frame = self._trim_to_visible_bounds(frame)
            frame = self._scale_to_target(frame)
            self._frames_right.append(frame)
            self._frames_left.append(pygame.transform.flip(frame, True, False))

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

    def _scale_to_target(self, frame: pygame.Surface) -> pygame.Surface:
        src_w, src_h = frame.get_size()
        if src_w <= 0 or src_h <= 0:
            return frame
        scale = min(self.target_w / src_w, self.target_h / src_h)
        dst_w = max(1, int(round(src_w * scale)))
        dst_h = max(1, int(round(src_h * scale)))
        return pygame.transform.scale(frame, (dst_w, dst_h))

    def update(self, dt: float, moving: bool = True, facing: str | None = None) -> None:
        if facing in ("left", "right"):
            self.facing = facing
        self.is_moving = moving
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

    def get_current_frame(self, size: tuple[int, int] | None = None) -> pygame.Surface | None:
        frames = self._frames_left if self.facing == "left" else self._frames_right
        if not frames:
            return None
        frame = frames[self.frame_index]
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


_menhera_boss_sprite_instance: MenheraBossSprite | None = None


def get_menhera_boss_sprite() -> MenheraBossSprite:
    global _menhera_boss_sprite_instance
    if _menhera_boss_sprite_instance is None:
        _menhera_boss_sprite_instance = MenheraBossSprite()
    return _menhera_boss_sprite_instance


def init_menhera_boss_sprite(width: int = 72, height: int = 80) -> MenheraBossSprite:
    global _menhera_boss_sprite_instance
    _menhera_boss_sprite_instance = MenheraBossSprite(width=width, height=height)
    return _menhera_boss_sprite_instance


def reset_menhera_boss_sprite() -> None:
    global _menhera_boss_sprite_instance
    _menhera_boss_sprite_instance = None
