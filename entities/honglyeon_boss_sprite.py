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
    DASH_SHEET_PATH_PNG = os.path.join("items", "honglyeon_boss_dash.png")
    DASH_SHEET_PATH_JPEG = os.path.join("items", "honglyeon_boss_dash.jpeg")
    TURN_SHEET_PATH_PNG = os.path.join("items", "honglyeon_boss_turn.png")
    TURN_SHEET_PATH_JPEG = os.path.join("items", "honglyeon_boss_turn.jpeg")
    GRID_COLS = 4
    GRID_ROWS = 2
    FRAME_ORDER = (
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1), (2, 1), (3, 1),
    )
    TURN_GRID_COLS = 7
    TURN_GRID_ROWS = 2
    TURN_FRAME_ORDER = (
        (0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0),
        (0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1),
    )
    TURN_ANGLE_STEPS = (90, 75, 60, 45, 30, 15, 0, -15, -30, -45, -60, -75, -90)
    TURN_ACTIVE_START_INDEX = 2
    TURN_ACTIVE_END_INDEX = 10
    FRAME_DURATION = 0.10
    ATTACK_FRAME_DURATION = 0.055
    ATTACK_IMPACT_FRAME = 5
    ATTACK_IMPACT_HOLD_DURATION = 0.12
    DASH_FRAME_DURATION = 0.07
    ATTACK_MIN_VISIBLE_HEIGHT_RATIO = 0.90
    DASH_MIN_VISIBLE_HEIGHT_RATIO = 0.64
    DASH_MIN_VISIBLE_WIDTH_RATIO = 1.05
    LIGHT_BG_TOLERANCE = 18
    FRAME_INSET = 14
    OUTLINE_MARGIN = 2
    OUTLINE_COLOR = (10, 8, 8)
    EDGE_HALO_RGB_MIN = 228
    EDGE_HALO_SATURATION = 42
    EDGE_HALO_MIN_ALPHA = 1
    EDGE_HALO_SOFT_ALPHA = 160
    TURN_HOLD_DURATION = 0.08
    MOVE_RELEASE_DURATION = 0.12
    TURN_DEGREES_PER_SECOND = 900.0

    def __init__(self, width: int = 100, height: int = 88):
        self.target_w = width
        self.target_h = height
        self._frames_right: list[pygame.Surface] = []
        self._frames_left: list[pygame.Surface] = []
        self._turn_frames: list[pygame.Surface] = []
        self._attack_frames_right: list[pygame.Surface] = []
        self._attack_frames_left: list[pygame.Surface] = []
        self._dash_frames_right: list[pygame.Surface] = []
        self._dash_frames_left: list[pygame.Surface] = []
        self._walk_scale_reference: tuple[int, int] | None = None
        self._walk_visible_reference: tuple[int, int] | None = None

        self.anim_time = 0.0
        self.frame_index = 0
        self.facing = "right"
        self.is_moving = False
        self._pending_facing: str | None = None
        self._facing_turn_timer = 0.0
        self._move_release_timer = 0.0
        self.is_turning = False
        self.turn_angle = 0.0
        self.turn_target_angle = 0.0
        self.turn_target_facing: str | None = None

        self.is_attacking = False
        self.attack_time = 0.0
        self.attack_frame_index = 0

        self.is_dashing = False
        self.dash_time = 0.0
        self.dash_frame_index = 0

        self._load_frames()
        self._load_turn_frames()
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

        trimmed_frames: list[pygame.Surface] = []
        scale_reference = self._walk_scale_reference
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
            trimmed_frames.append(frame)

        self._walk_scale_reference = self._compute_reference_size(trimmed_frames)
        for frame in trimmed_frames:
            frame = self._scale_to_target(frame, source_size=self._walk_scale_reference)
            self._frames_right.append(frame)
            self._frames_left.append(pygame.transform.flip(frame, True, False))
        self._walk_visible_reference = self._compute_visible_reference_size(self._frames_right)

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
        scale_reference = self._walk_scale_reference

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
            if self._walk_visible_reference is not None:
                frame = self._scale_to_visible_reference(frame, self._walk_visible_reference)
                frame = self._ensure_min_visible_presence(
                    frame,
                    min_height=int(round(self._walk_visible_reference[1] * self.ATTACK_MIN_VISIBLE_HEIGHT_RATIO)),
                )
            else:
                frame = self._scale_to_target(frame, source_size=scale_reference)
            self._attack_frames_right.append(frame)
            # Honglyeon's attack sheet is authored as a frontal strike,
            # so both directions should use the same unflipped frames.
            self._attack_frames_left.append(frame.copy())

    def _load_turn_frames(self) -> None:
        png_path = resource_path(self.TURN_SHEET_PATH_PNG)
        jpeg_path = resource_path(self.TURN_SHEET_PATH_JPEG)
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
            print(f"[HonglyeonBossSprite] Turn load failed: {exc}")
            return

        if not use_png:
            sheet = self._remove_light_background(sheet)

        sheet_w, sheet_h = sheet.get_size()
        cell_w = sheet_w // self.TURN_GRID_COLS
        cell_h = sheet_h // self.TURN_GRID_ROWS
        inset_x = min(self.FRAME_INSET, max(2, cell_w // 32))
        inset_y = min(self.FRAME_INSET, max(2, cell_h // 32))

        trimmed_frames: list[pygame.Surface] = []
        for col, row in self.TURN_FRAME_ORDER:
            rect = pygame.Rect(
                col * cell_w + inset_x,
                row * cell_h + inset_y,
                max(1, cell_w - inset_x * 2),
                max(1, cell_h - inset_y * 2),
            )
            frame = sheet.subsurface(rect).copy()
            frame = self._cleanup_edge_halo(frame)
            frame = self._trim_to_visible_bounds(frame)
            trimmed_frames.append(frame)

        scale_reference = self._walk_scale_reference or self._compute_reference_size(trimmed_frames)
        for frame in trimmed_frames:
            if self._walk_visible_reference is not None:
                frame = self._scale_to_visible_reference(frame, self._walk_visible_reference)
            else:
                frame = self._scale_to_target(frame, source_size=scale_reference)
            self._turn_frames.append(frame)

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
            print(f"[HonglyeonBossSprite] Dash load failed: {exc}")
            return

        if not use_png:
            sheet = self._remove_light_background(sheet)

        sheet_w, sheet_h = sheet.get_size()
        cell_w = sheet_w // self.GRID_COLS
        cell_h = sheet_h // self.GRID_ROWS
        inset_x = min(self.FRAME_INSET, max(2, cell_w // 32))
        inset_y = min(self.FRAME_INSET, max(2, cell_h // 32))

        trimmed_frames: list[pygame.Surface] = []
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
            trimmed_frames.append(frame)

        scale_reference = self._walk_scale_reference or self._compute_reference_size(trimmed_frames)
        for frame in trimmed_frames:
            frame = self._scale_to_target(frame, source_size=scale_reference)
            if self._walk_visible_reference is not None:
                frame = self._ensure_min_visible_presence(
                    frame,
                    min_height=int(round(self._walk_visible_reference[1] * self.DASH_MIN_VISIBLE_HEIGHT_RATIO)),
                    min_width=int(round(self._walk_visible_reference[0] * self.DASH_MIN_VISIBLE_WIDTH_RATIO)),
                )
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

    def _compute_reference_size(self, frames: list[pygame.Surface]) -> tuple[int, int]:
        if not frames:
            return (self.target_w, self.target_h)

        max_w = 1
        max_h = 1
        for frame in frames:
            src_w, src_h = frame.get_size()
            max_w = max(max_w, src_w)
            max_h = max(max_h, src_h)
        return (max_w, max_h)

    def _measure_visible_bounds(self, frame: pygame.Surface) -> tuple[int, int] | None:
        mask = pygame.mask.from_surface(frame)
        rects = mask.get_bounding_rects()
        if not rects:
            return None

        bounds = rects[0].copy()
        for rect in rects[1:]:
            bounds.union_ip(rect)
        return (bounds.width, bounds.height)

    def _compute_visible_reference_size(self, frames: list[pygame.Surface]) -> tuple[int, int] | None:
        max_w = 0
        max_h = 0
        for frame in frames:
            measured = self._measure_visible_bounds(frame)
            if measured is None:
                continue
            max_w = max(max_w, measured[0])
            max_h = max(max_h, measured[1])
        if max_w <= 0 or max_h <= 0:
            return None
        return (max_w, max_h)

    def _ensure_min_visible_presence(
        self,
        frame: pygame.Surface,
        min_height: int | None = None,
        min_width: int | None = None,
    ) -> pygame.Surface:
        rect = frame.get_bounding_rect(min_alpha=1)
        if rect.width <= 0 or rect.height <= 0:
            return frame

        scale = 1.0
        if min_height is not None and rect.height < min_height:
            scale = max(scale, min_height / rect.height)
        if min_width is not None and rect.width < min_width:
            scale = max(scale, min_width / rect.width)
        if scale <= 1.0:
            return frame

        visible = frame.subsurface(rect).copy()
        dst_w = max(1, int(round(visible.get_width() * scale)))
        dst_h = max(1, int(round(visible.get_height() * scale)))
        scaled = pygame.transform.scale(visible, (dst_w, dst_h))
        canvas = pygame.Surface((self.target_w, self.target_h), pygame.SRCALPHA)
        canvas.blit(
            scaled,
            scaled.get_rect(midbottom=(self.target_w // 2, self.target_h - self.OUTLINE_MARGIN)),
        )
        return canvas

    def _compose_on_canvas(self, scaled: pygame.Surface) -> pygame.Surface:
        canvas = pygame.Surface((self.target_w, self.target_h), pygame.SRCALPHA)
        canvas.blit(
            scaled,
            scaled.get_rect(midbottom=(self.target_w // 2, self.target_h - self.OUTLINE_MARGIN)),
        )
        canvas = self._cleanup_edge_halo(canvas)
        return self._add_outer_outline(canvas)

    def _scale_to_target(
        self,
        frame: pygame.Surface,
        source_size: tuple[int, int] | None = None,
    ) -> pygame.Surface:
        src_w, src_h = frame.get_size()
        if src_w <= 0 or src_h <= 0:
            return frame

        ref_w, ref_h = source_size or (src_w, src_h)
        ref_w = max(1, ref_w)
        ref_h = max(1, ref_h)
        inner_w = max(1, self.target_w - self.OUTLINE_MARGIN * 2)
        inner_h = max(1, self.target_h - self.OUTLINE_MARGIN * 2)
        scale = min(inner_w / ref_w, inner_h / ref_h)
        dst_w = max(1, int(round(src_w * scale)))
        dst_h = max(1, int(round(src_h * scale)))
        scaled = pygame.transform.scale(frame, (dst_w, dst_h))
        return self._compose_on_canvas(scaled)

    def _scale_to_visible_reference(
        self,
        frame: pygame.Surface,
        visible_reference: tuple[int, int],
    ) -> pygame.Surface:
        src_w, src_h = frame.get_size()
        if src_w <= 0 or src_h <= 0:
            return frame

        ref_w = max(1, visible_reference[0])
        ref_h = max(1, visible_reference[1])
        scale = min(ref_w / src_w, ref_h / src_h)
        dst_w = max(1, int(round(src_w * scale)))
        dst_h = max(1, int(round(src_h * scale)))
        scaled = pygame.transform.scale(frame, (dst_w, dst_h))
        return self._compose_on_canvas(scaled)

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

    def _update_requested_facing(self, dt: float, facing: str | None, moving: bool) -> None:
        if facing not in ("left", "right"):
            return

        if self.is_turning:
            if moving and facing != self.turn_target_facing:
                self.turn_target_facing = facing
                self.turn_target_angle = 90.0 if facing == "right" else -90.0
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

        if not self._turn_frames:
            self.facing = facing
            self._pending_facing = None
            self._facing_turn_timer = 0.0
            return

        self.is_turning = True
        self.turn_angle = 90.0 if self.facing == "right" else -90.0
        self.turn_target_angle = 90.0 if facing == "right" else -90.0
        self.turn_target_facing = facing
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

    def _update_turn_angle(self, dt: float) -> None:
        if not self.is_turning:
            return
        max_step = self.TURN_DEGREES_PER_SECOND * dt
        delta = self.turn_target_angle - self.turn_angle
        if abs(delta) <= max_step:
            self.turn_angle = self.turn_target_angle
            if self.turn_target_facing in ("left", "right"):
                self.facing = self.turn_target_facing
            self.is_turning = False
            self.turn_target_facing = None
            return
        self.turn_angle += max_step if delta > 0 else -max_step

    def _get_turn_frame(self) -> pygame.Surface | None:
        if not self._turn_frames:
            return None

        start = max(0, min(self.TURN_ACTIVE_START_INDEX, len(self._turn_frames) - 1))
        end = max(start, min(self.TURN_ACTIVE_END_INDEX, len(self._turn_frames) - 1))
        best_index = min(
            range(start, end + 1),
            key=lambda idx: abs(self.TURN_ANGLE_STEPS[idx] - self.turn_angle),
        )
        return self._turn_frames[best_index]

    def update(self, dt: float, moving: bool = True, facing: str | None = None) -> None:
        dt = max(0.0, dt)
        self._update_requested_facing(dt, facing, moving)
        self._update_requested_motion(dt, moving)
        self._update_turn_angle(dt)

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
            while True:
                frame_duration = (
                    self.ATTACK_IMPACT_HOLD_DURATION
                    if self.attack_frame_index == self.ATTACK_IMPACT_FRAME
                    else self.ATTACK_FRAME_DURATION
                )
                if self.attack_time < frame_duration:
                    break
                self.attack_time -= frame_duration
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
        elif self.is_turning and self._turn_frames:
            frame = self._get_turn_frame()
            if frame is None:
                return None
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


def init_honglyeon_boss_sprite(width: int = 100, height: int = 88) -> HonglyeonBossSprite:
    global _honglyeon_boss_sprite_instance
    _honglyeon_boss_sprite_instance = HonglyeonBossSprite(width=width, height=height)
    return _honglyeon_boss_sprite_instance


def reset_honglyeon_boss_sprite() -> None:
    global _honglyeon_boss_sprite_instance
    _honglyeon_boss_sprite_instance = None
