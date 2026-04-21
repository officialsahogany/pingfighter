# -*- coding: utf-8 -*-
"""Stage 3 menhera-girl boss sprite support."""

import math
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
    """4x2 walker with an 8-frame frontal turn gesture for stage 3 Menhera."""

    ENABLE_TURN_TRANSITIONS = True
    # Menhera's accepted R1 turn sheet is a runtime-only auxiliary sheet.
    # Keep the main walk as the sole identity anchor, but allow visible turn
    # playback now that the 4x2 runtime sheet has passed local asset QA.
    RENDER_TURN_FRAMES = True
    SHEET_PATH_PNG = os.path.join("items", "menhera_boss_sheet.png")
    SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_sheet.jpeg")
    ATTACK_SHEET_PATH_PNG = os.path.join("items", "menhera_boss_attack.png")
    ATTACK_SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_attack.jpeg")
    DASH_SHEET_PATH_PNG = os.path.join("items", "menhera_boss_dash.png")
    DASH_SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_dash.jpeg")
    TURN_SHEET_PATH_PNG = os.path.join("items", "menhera_boss_turn.png")
    TURN_SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_turn.jpeg")
    VICTORY_SHEET_PATH_PNG = os.path.join("items", "menhera_boss_victory.png")
    VICTORY_SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_victory.jpeg")
    DEFEAT_SHEET_PATH_PNG = os.path.join("items", "menhera_boss_defeat.png")
    DEFEAT_SHEET_PATH_JPEG = os.path.join("items", "menhera_boss_defeat.jpeg")
    GRID_COLS = 4
    GRID_ROWS = 2
    FRAME_ORDER = (
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1), (2, 1), (3, 1),
    )
    TURN_GRID_COLS = 4
    TURN_GRID_ROWS = 2
    TURN_FRAME_ORDER = (
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1), (2, 1), (3, 1),
    )
    TURN_PLAYBACK_FRAME_COUNT = 7
    FRAME_DURATION = 0.08
    ATTACK_FRAME_DURATION = 0.055
    ATTACK_IMPACT_FRAME = 5
    ATTACK_IMPACT_HOLD_DURATION = 0.12
    DASH_FRAME_DURATION = 0.07
    VICTORY_FRAME_DURATION = 0.09
    DEFEAT_FRAME_DURATION = 0.10
    LIGHT_BG_TOLERANCE = 22
    FRAME_INSET = 14
    TURN_HOLD_DURATION = 0.08
    TURN_FRAME_DURATION = 0.055
    MOVE_RELEASE_DURATION = 0.12
    TURN_HOP_HEIGHT_RATIO = 0.018
    TURN_BBOX_PAD = 1

    def __init__(self, width: int = 79, height: int = 88):
        self.target_w = width
        self.target_h = height
        self._frames_right: list[pygame.Surface] = []
        self._frames_left: list[pygame.Surface] = []
        self._turn_frames: list[pygame.Surface] = []
        self._attack_frames_right: list[pygame.Surface] = []
        self._attack_frames_left: list[pygame.Surface] = []
        self._dash_frames_right: list[pygame.Surface] = []
        self._dash_frames_left: list[pygame.Surface] = []
        self._victory_frames_right: list[pygame.Surface] = []
        self._victory_frames_left: list[pygame.Surface] = []
        self._defeat_frames_right: list[pygame.Surface] = []
        self._defeat_frames_left: list[pygame.Surface] = []
        self._walk_scale_reference: tuple[int, int] | None = None
        self._walk_bbox_reference: tuple[int, int] | None = None
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
        self.is_victorious = False
        self.victory_time = 0.0
        self.victory_frame_index = 0
        self.victory_finished = False
        self.is_defeated = False
        self.defeat_time = 0.0
        self.defeat_frame_index = 0
        self.defeat_finished = False
        self.is_turning = False
        self.turn_time = 0.0
        self.turn_target_facing: str | None = None
        self._load_frames()
        self._load_turn_frames()
        self._load_attack_frames()
        self._load_dash_frames()
        self._load_victory_frames()
        self._load_defeat_frames()

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

        trimmed_frames: list[pygame.Surface] = []
        for col, row in self.FRAME_ORDER:
            rect = pygame.Rect(
                col * cell_w + inset_x,
                row * cell_h + inset_y,
                max(1, cell_w - inset_x * 2),
                max(1, cell_h - inset_y * 2),
            )
            frame = sheet.subsurface(rect).copy()
            frame = self._trim_to_visible_bounds(frame)
            trimmed_frames.append(frame)

        self._walk_scale_reference = self._compute_reference_size(trimmed_frames)
        for frame in trimmed_frames:
            frame = self._scale_to_target(frame, use_canvas=True)
            self._frames_right.append(frame)
            # Menhera's walk sheet is authored as a front-biased cycle,
            # so stable left/right travel should keep the same frontal read.
            self._frames_left.append(frame.copy())
        self._walk_bbox_reference = self._compute_canvas_bbox_reference(self._frames_right)

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
            # Menhera's attack sheet is authored as a front-facing strike,
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
            print(f"[MenheraBossSprite] Turn load failed: {exc}")
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
            frame = self._trim_to_visible_bounds(frame)
            trimmed_frames.append(frame)

        # Menhera's accepted turn sheet was exported at a much larger raw
        # source resolution than the walk sheet. Reusing the walk sheet's raw
        # reference size here can over-scale the turn frames so they exceed the
        # 79x88 canvas and clip the head before draw-time. Keep turn playback
        # internally consistent against its own sheet first, then clamp the
        # final visible body read against the walk bbox below.
        scale_reference = self._compute_reference_size(trimmed_frames)
        self._turn_frames.clear()
        for frame in trimmed_frames:
            scaled_frame = self._scale_to_target(frame, source_size=scale_reference, use_canvas=True)
            scaled_frame = self._fit_turn_frame_to_walk_bbox(scaled_frame)
            self._turn_frames.append(scaled_frame)

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

        trimmed_frames: list[pygame.Surface] = []
        for col, row in self.FRAME_ORDER:
            rect = pygame.Rect(
                col * cell_w + inset_x,
                row * cell_h + inset_y,
                max(1, cell_w - inset_x * 2),
                max(1, cell_h - inset_y * 2),
            )
            frame = sheet.subsurface(rect).copy()
            frame = self._trim_to_visible_bounds(frame)
            trimmed_frames.append(frame)

        scale_reference = self._walk_scale_reference or self._compute_reference_size(trimmed_frames)
        for frame in trimmed_frames:
            frame = self._scale_to_target(frame, source_size=scale_reference, use_canvas=True)
            self._dash_frames_right.append(frame)
            self._dash_frames_left.append(pygame.transform.flip(frame, True, False))

    def _load_victory_frames(self) -> None:
        png_path = resource_path(self.VICTORY_SHEET_PATH_PNG)
        jpeg_path = resource_path(self.VICTORY_SHEET_PATH_JPEG)
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
            print(f"[MenheraBossSprite] Victory load failed: {exc}")
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
            frame = self._trim_to_visible_bounds(frame)
            trimmed_frames.append(frame)

        scale_reference = self._walk_scale_reference or self._compute_reference_size(trimmed_frames)
        for frame in trimmed_frames:
            frame = self._scale_to_target(frame, source_size=scale_reference, use_canvas=True)
            self._victory_frames_right.append(frame)
            # Victory sheet is authored as a front-facing celebration pose.
            self._victory_frames_left.append(frame.copy())

    def _load_defeat_frames(self) -> None:
        png_path = resource_path(self.DEFEAT_SHEET_PATH_PNG)
        jpeg_path = resource_path(self.DEFEAT_SHEET_PATH_JPEG)
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
            print(f"[MenheraBossSprite] Defeat load failed: {exc}")
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
            frame = self._trim_to_visible_bounds(frame)
            trimmed_frames.append(frame)

        scale_reference = self._walk_scale_reference or self._compute_reference_size(trimmed_frames)
        for frame in trimmed_frames:
            frame = self._scale_to_target(frame, source_size=scale_reference, use_canvas=True)
            self._defeat_frames_right.append(frame)
            # Defeat sheet is authored as a front-facing collapse sequence.
            self._defeat_frames_left.append(frame.copy())

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

    def _compute_canvas_bbox_reference(self, frames: list[pygame.Surface]) -> tuple[int, int]:
        if not frames:
            return (self.target_w, self.target_h)

        max_w = 1
        max_h = 1
        for frame in frames:
            bounds = frame.get_bounding_rect(min_alpha=1)
            if bounds.w <= 0 or bounds.h <= 0:
                continue
            max_w = max(max_w, bounds.w)
            max_h = max(max_h, bounds.h)
        return (max_w, max_h)

    def _fit_turn_frame_to_walk_bbox(
        self,
        frame: pygame.Surface,
    ) -> pygame.Surface:
        walk_bbox = self._walk_bbox_reference
        if walk_bbox is None:
            return frame

        bounds = frame.get_bounding_rect(min_alpha=1)
        if bounds.w <= 0 or bounds.h <= 0:
            return frame

        limit_w = max(1, walk_bbox[0] + self.TURN_BBOX_PAD)
        limit_h = max(1, walk_bbox[1] + self.TURN_BBOX_PAD)
        scale = min(limit_w / bounds.w, limit_h / bounds.h, 1.0)
        if scale >= 0.999:
            return frame

        scaled_w = max(1, int(round(frame.get_width() * scale)))
        scaled_h = max(1, int(round(frame.get_height() * scale)))
        scaled = pygame.transform.scale(frame, (scaled_w, scaled_h))
        canvas = pygame.Surface((self.target_w, self.target_h), pygame.SRCALPHA)
        canvas.blit(
            scaled,
            scaled.get_rect(midbottom=(self.target_w // 2, self.target_h)),
        )
        return canvas

    def _scale_to_target(
        self,
        frame: pygame.Surface,
        source_size: tuple[int, int] | None = None,
        use_canvas: bool = False,
    ) -> pygame.Surface:
        src_w, src_h = frame.get_size()
        if src_w <= 0 or src_h <= 0:
            return frame
        ref_w, ref_h = source_size or (src_w, src_h)
        ref_w = max(1, ref_w)
        ref_h = max(1, ref_h)
        scale = min(self.target_w / ref_w, self.target_h / ref_h)
        dst_w = max(1, int(round(src_w * scale)))
        dst_h = max(1, int(round(src_h * scale)))
        scaled = pygame.transform.scale(frame, (dst_w, dst_h))
        if not use_canvas:
            return scaled

        canvas = pygame.Surface((self.target_w, self.target_h), pygame.SRCALPHA)
        canvas.blit(
            scaled,
            scaled.get_rect(midbottom=(self.target_w // 2, self.target_h)),
        )
        return canvas

    def _cancel_turn_transition(self) -> None:
        self.is_turning = False
        self.turn_target_facing = None
        self.turn_time = 0.0

    def _start_turn_transition(self, facing: str) -> None:
        self.is_turning = True
        self.turn_target_facing = facing
        self.turn_time = 0.0

    def _get_turn_progress(self) -> float:
        if not self.is_turning:
            return 0.0

        playback_count = max(1, min(self.TURN_PLAYBACK_FRAME_COUNT, len(self._turn_frames)))
        total_duration = max(0.001, self.TURN_FRAME_DURATION * playback_count)
        return max(0.0, min(1.0, self.turn_time / total_duration))

    def _current_turn_hop_offset(self, rendered_height: int | None = None) -> int:
        if (
            not self.is_turning
            or self.is_attacking
            or self.is_dashing
            or self.is_victorious
            or self.is_defeated
        ):
            return 0

        progress = self._get_turn_progress()
        if progress <= 0.0 or progress >= 1.0:
            return 0

        body_height = max(1, rendered_height or self.target_h)
        peak = max(1, int(round(body_height * self.TURN_HOP_HEIGHT_RATIO)))
        return -int(round(peak * math.sin(math.pi * progress)))

    def current_y_offset(self, rendered_height: int | None = None) -> int:
        return self._current_turn_hop_offset(rendered_height=rendered_height)

    def _update_requested_facing(self, dt: float, facing: str | None, moving: bool) -> None:
        if facing not in ("left", "right"):
            return

        if not self.ENABLE_TURN_TRANSITIONS:
            self.facing = facing
            self._cancel_turn_transition()
            self._pending_facing = None
            self._facing_turn_timer = 0.0
            return

        if self.is_turning:
            if moving and facing != self.turn_target_facing:
                self.turn_target_facing = facing
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

        self._start_turn_transition(facing)
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

    def _update_turn_transition(self, dt: float) -> None:
        if not self.is_turning:
            return

        playback_count = max(1, min(self.TURN_PLAYBACK_FRAME_COUNT, len(self._turn_frames) or self.TURN_PLAYBACK_FRAME_COUNT))
        total_duration = self.TURN_FRAME_DURATION * playback_count
        self.turn_time += dt
        if self.turn_time < total_duration:
            return

        if self.turn_target_facing in ("left", "right"):
            self.facing = self.turn_target_facing
        self._cancel_turn_transition()

    def _get_turn_frame(self) -> pygame.Surface | None:
        if not self._turn_frames:
            return None
        playback_count = max(1, min(self.TURN_PLAYBACK_FRAME_COUNT, len(self._turn_frames)))
        frame_index = min(int(self.turn_time / self.TURN_FRAME_DURATION), playback_count - 1)
        return self._turn_frames[frame_index]

    def update(self, dt: float, moving: bool = True, facing: str | None = None) -> None:
        dt = max(0.0, dt)
        if self.is_defeated and self._defeat_frames_right:
            if not self.defeat_finished:
                self.defeat_time += dt
                total_frames = len(self._defeat_frames_right)
                while self.defeat_time >= self.DEFEAT_FRAME_DURATION:
                    self.defeat_time -= self.DEFEAT_FRAME_DURATION
                    self.defeat_frame_index += 1
                    if self.defeat_frame_index >= total_frames:
                        self.defeat_frame_index = total_frames - 1
                        self.defeat_finished = True
                        break
            return

        if self.is_victorious and self._victory_frames_right:
            if not self.victory_finished:
                self.victory_time += dt
                total_frames = len(self._victory_frames_right)
                while self.victory_time >= self.VICTORY_FRAME_DURATION:
                    self.victory_time -= self.VICTORY_FRAME_DURATION
                    self.victory_frame_index += 1
                    if self.victory_frame_index >= total_frames:
                        self.victory_frame_index = total_frames - 1
                        self.victory_finished = True
                        break
            return

        self._update_requested_facing(dt, facing, moving)
        self._update_requested_motion(dt, moving)
        self._update_turn_transition(dt)

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
        if self.is_defeated or self.is_victorious or self.is_attacking or not self._attack_frames_right:
            return
        self.is_attacking = True
        max_index = len(self._attack_frames_right) - 1
        self.attack_frame_index = max(0, min(start_frame, max_index))
        self.attack_time = 0.0

    def trigger_dash(self, start_frame: int = 0) -> None:
        if self.is_defeated or self.is_victorious or self.is_dashing or not self._dash_frames_right:
            return
        self.is_dashing = True
        self.is_attacking = False
        max_index = len(self._dash_frames_right) - 1
        self.dash_frame_index = max(0, min(start_frame, max_index))
        self.dash_time = 0.0

    def trigger_victory(self, start_frame: int = 0) -> None:
        if self.is_defeated or not self._victory_frames_right:
            return
        self.is_victorious = True
        max_index = len(self._victory_frames_right) - 1
        self.victory_frame_index = max(0, min(start_frame, max_index))
        self.victory_time = 0.0
        self.victory_finished = False
        self.is_attacking = False
        self.attack_time = 0.0
        self.attack_frame_index = 0
        self.is_dashing = False
        self.dash_time = 0.0
        self.dash_frame_index = 0
        self._cancel_turn_transition()
        self._pending_facing = None
        self._facing_turn_timer = 0.0
        self._move_release_timer = 0.0
        self.is_moving = False

    def trigger_defeat(self, start_frame: int = 0) -> None:
        if not self._defeat_frames_right:
            return
        self.is_defeated = True
        max_index = len(self._defeat_frames_right) - 1
        self.defeat_frame_index = max(0, min(start_frame, max_index))
        self.defeat_time = 0.0
        self.defeat_finished = False
        self.is_victorious = False
        self.victory_time = 0.0
        self.victory_frame_index = 0
        self.victory_finished = False
        self.is_attacking = False
        self.attack_time = 0.0
        self.attack_frame_index = 0
        self.is_dashing = False
        self.dash_time = 0.0
        self.dash_frame_index = 0
        self._cancel_turn_transition()
        self._pending_facing = None
        self._facing_turn_timer = 0.0
        self._move_release_timer = 0.0
        self.is_moving = False

    def clear_victory(self) -> None:
        self.is_victorious = False
        self.victory_time = 0.0
        self.victory_frame_index = 0
        self.victory_finished = False

    def clear_defeat(self) -> None:
        self.is_defeated = False
        self.defeat_time = 0.0
        self.defeat_frame_index = 0
        self.defeat_finished = False

    def get_current_frame(self, size: tuple[int, int] | None = None) -> pygame.Surface | None:
        if self.is_defeated and self._defeat_frames_right:
            frames = self._defeat_frames_left if self.facing == "left" else self._defeat_frames_right
            frame = frames[min(self.defeat_frame_index, len(frames) - 1)]
        elif self.is_victorious and self._victory_frames_right:
            frames = self._victory_frames_left if self.facing == "left" else self._victory_frames_right
            frame = frames[min(self.victory_frame_index, len(frames) - 1)]
        elif self.is_dashing and self._dash_frames_right:
            frames = self._dash_frames_left if self.facing == "left" else self._dash_frames_right
            frame = frames[min(self.dash_frame_index, len(frames) - 1)]
        elif self.is_attacking and self._attack_frames_right:
            frames = self._attack_frames_left if self.facing == "left" else self._attack_frames_right
            frame = frames[min(self.attack_frame_index, len(frames) - 1)]
        elif self.is_turning and self.RENDER_TURN_FRAMES and self._turn_frames:
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


def init_menhera_boss_sprite(width: int = 79, height: int = 88) -> MenheraBossSprite:
    global _menhera_boss_sprite_instance
    _menhera_boss_sprite_instance = MenheraBossSprite(width=width, height=height)
    return _menhera_boss_sprite_instance


def reset_menhera_boss_sprite() -> None:
    global _menhera_boss_sprite_instance
    _menhera_boss_sprite_instance = None
