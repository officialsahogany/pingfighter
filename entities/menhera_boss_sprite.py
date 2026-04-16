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
    ATTACK_SHEET_PATH_PNG = os.path.join("items", "menhera_boss_attack.png")
    ATTACK_SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_attack.jpeg")
    DASH_SHEET_PATH_PNG = os.path.join("items", "menhera_boss_dash.png")
    DASH_SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_dash.jpeg")
    GRID_COLS = 4
    GRID_ROWS = 2
    FRAME_ORDER = (
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1), (2, 1), (3, 1),
    )
    FRAME_DURATION = 0.10
    ATTACK_FRAME_DURATION = 0.055
    DASH_FRAME_DURATION = 0.07
    LIGHT_BG_TOLERANCE = 22
    FRAME_INSET = 14
    TURN_HOLD_DURATION = 0.08
    MOVE_RELEASE_DURATION = 0.12

    def __init__(self, width: int = 72, height: int = 80):
        self.target_w = width
        self.target_h = height
        self._frames_right: list[pygame.Surface] = []
        self._frames_left: list[pygame.Surface] = []
        self._attack_frames_right: list[pygame.Surface] = []
        self._attack_frames_left: list[pygame.Surface] = []
        self._dash_frames_right: list[pygame.Surface] = []
        self._dash_frames_left: list[pygame.Surface] = []
        self.anim_time = 0.0
        self.frame_index = 0
        self.facing = "right"
        self.is_moving = False
        self._pending_facing: str | None = None
        self._facing_turn_timer = 0.0
        self._move_release_timer = 0.0
        self.is_attacking = False
        self.attack_time = 0.0
        self.attack_frame_index = 0
        self.is_dashing = False
        self.dash_time = 0.0
        self.dash_frame_index = 0
        self._load_frames()
        self._load_attack_frames()
        self._load_dash_frames()

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
            print(f"[MenheraBossSprite] Attack load failed: {exc}")
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
            self._attack_frames_right.append(frame)
            self._attack_frames_left.append(pygame.transform.flip(frame, True, False))

    def _load_dash_frames(self) -> None:
        png_path = resource_path(self.DASH_SHEET_PATH_PNG)
        jpeg_path = resource_path(self.DASH_SHEET_PATH_JPEG)
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
            print(f"[MenheraBossSprite] Dash load failed: {exc}")
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
            self._dash_frames_right.append(frame)
            self._dash_frames_left.append(pygame.transform.flip(frame, True, False))

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

    def _update_requested_facing(self, dt: float, facing: str | None, moving: bool) -> None:
        if facing not in ("left", "right"):
            return

        if facing == self.facing:
            self._pending_facing = None
            self._facing_turn_timer = 0.0
            return

        if not moving:
            self._pending_facing = None
            self._facing_turn_timer = 0.0
            return

        if self._pending_facing != facing:
            self._pending_facing = facing
            self._facing_turn_timer = 0.0

        self._facing_turn_timer += dt
        if self._facing_turn_timer < self.TURN_HOLD_DURATION:
            return

        self.facing = facing
        self._pending_facing = None
        self._facing_turn_timer = 0.0

    def _update_requested_motion(self, dt: float, moving: bool) -> None:
        if moving:
            self.is_moving = True
            self._move_release_timer = self.MOVE_RELEASE_DURATION
            return

        if self._move_release_timer > 0.0:
            self._move_release_timer = max(0.0, self._move_release_timer - dt)
            self.is_moving = self._move_release_timer > 0.0
            return

        self.is_moving = False

    def update(self, dt: float, moving: bool = True, facing: str | None = None) -> None:
        dt = max(0.0, dt)
        self._update_requested_facing(dt, facing, moving)
        self._update_requested_motion(dt, moving)

        if self.is_dashing and self._dash_frames_right:
            self.dash_time += dt
            total_frames = len(self._dash_frames_right)
            while self.dash_time >= self.DASH_FRAME_DURATION:
                self.dash_time -= self.DASH_FRAME_DURATION
                self.dash_frame_index += 1
                if self.dash_frame_index >= total_frames:
                    self.is_dashing = False
                    self.dash_frame_index = 0
                    self.dash_time = 0.0
                    break
            return

        if self.is_attacking and self._attack_frames_right:
            self.attack_time += dt
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
        if self.is_moving:
            self.anim_time += dt
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

    def trigger_dash(self, start_frame: int = 0) -> None:
        if self.is_dashing or not self._dash_frames_right:
            return
        self.is_dashing = True
        self.is_attacking = False
        max_index = len(self._dash_frames_right) - 1
        self.dash_frame_index = max(0, min(start_frame, max_index))
        self.dash_time = 0.0

    def get_current_frame(self, size: tuple[int, int] | None = None) -> pygame.Surface | None:
        if self.is_dashing and self._dash_frames_right:
            frames = self._dash_frames_left if self.facing == "left" else self._dash_frames_right
            frame = frames[min(self.dash_frame_index, len(frames) - 1)]
        elif self.is_attacking and self._attack_frames_right:
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
