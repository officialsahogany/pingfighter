"""천사의 주사위 패시브 효과 관리 모듈.

천사의 주사위는 전설 아이템 "holy_laurel"이 활성화된 동안
스테이지 시작 시 1~6 사이의 눈을 굴려 7가지 버프 중 복수 선택하여
라운드 전체에 걸쳐 능력치를 강화한다.

버프 목록 (각각 50% 증감):
    - paddle_size: 패들 크기 1.5배
    - skill_gauge: 스킬 게이지 최대치 1.5배
    - item_spawn: 아이템 스폰 속도 1.5배
    - item_cooldown: 아이템 쿨타임 0.5배
    - skill_dash_cost: 스킬/대쉬 비용 0.5배
    - dash_cooldown: 대쉬 쿨타임 0.5배
    - player_speed: 이동 속도 1.5배
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import Dict, List

import pygame


BUFF_KEYS: List[str] = [
    "paddle_size",
    "skill_gauge",
    "item_spawn",
    "item_cooldown",
    "skill_dash_cost",
    "dash_cooldown",
    "player_speed",
]


def _default_multipliers() -> Dict[str, float]:
    """기본 배율 사전 (모든 항목 1.0)."""

    return {key: 1.0 for key in BUFF_KEYS}


@dataclass
class AngelDiceState:
    """천사의 주사위 상태"""

    active: bool = False
    current_stage: int | None = None
    roll_value: int = 0
    active_buffs: List[str] = field(default_factory=list)
    multipliers: Dict[str, float] = field(default_factory=_default_multipliers)
    animating: bool = False
    animation_timer: int = 0
    face_value: int = 1
    wait_for_space: bool = False
    visible_buffs: int = 0
    dice_offset_y: float = 0.0
    dice_velocity: float = 0.0
    idle_phase: float = 0.0

    def reset_stage(self) -> None:
        """스테이지 종료 시 배율 초기화."""

        self.roll_value = 0
        self.current_stage = None
        self.active_buffs.clear()
        self.multipliers = _default_multipliers()
        self.animating = False
        self.animation_timer = 0
        self.face_value = 1
        self.wait_for_space = False
        self.visible_buffs = 0
        self.dice_offset_y = 0.0
        self.dice_velocity = 0.0
        self.idle_phase = 0.0


_TOTAL_DURATION = 5.0  # seconds
_BUFF_REVEAL_INTERVAL = 20  # frames (~0.33초)
_BUFF_FADE_FRAMES = 30
_DICE_GRAVITY = 0.55
_DICE_MIN_BOUNCE = -90
_DICE_IDLE_BASE = -12
_DICE_IDLE_AMPLITUDE = 4
_STATE = AngelDiceState()


def _calculate_phases():
    total_frames = int(_TOTAL_DURATION * 60)
    fall_end = int(total_frames * 0.35)
    reveal = int(total_frames * 0.5)
    buff_start = int(total_frames * 0.6)
    return total_frames, fall_end, reveal, buff_start


def activate_angel_dice() -> None:
    """천사의 주사위 패시브 활성화."""

    _STATE.active = True


def deactivate_angel_dice() -> None:
    """천사의 주사위 패시브 비활성화 및 상태 리셋."""

    _STATE.active = False
    _STATE.reset_stage()


def on_stage_start(stage_num: int) -> None:
    """스테이지 시작 시 주사위를 굴리고 버프를 적용한다."""

    # 이전 스테이지 잔여 버프 초기화
    _STATE.reset_stage()

    if not _STATE.active:
        return

    _STATE.current_stage = stage_num

    # 1~6 중 랜덤 눈 굴리기
    roll = random.randint(1, 6)
    _STATE.roll_value = roll

    # 버프 목록에서 roll 개수만큼 무작위 선택 (최대 7)
    count = min(roll, len(BUFF_KEYS))
    _STATE.active_buffs = random.sample(BUFF_KEYS, count)

    multipliers = _default_multipliers()
    for key in _STATE.active_buffs:
        if key in {"item_cooldown", "skill_dash_cost", "dash_cooldown"}:
            multipliers[key] = 0.5  # 50% 감소
        else:
            multipliers[key] = 1.5  # 50% 증가

    _STATE.multipliers = multipliers

    _log_stage_roll(stage_num, roll, _STATE.active_buffs)

    total_frames, fall_end, reveal, buff_start = _calculate_phases()
    _STATE.animating = True
    _STATE.animation_timer = 0
    _STATE.face_value = random.randint(1, 6)
    _STATE._anim_total_frames = total_frames
    _STATE._anim_fall_end = fall_end
    _STATE._anim_reveal = reveal
    _STATE._anim_buff_start = buff_start
    _STATE.wait_for_space = False
    _STATE.visible_buffs = 0
    _STATE.dice_offset_y = 0.0
    _STATE.dice_velocity = -9.0
    _STATE.idle_phase = 0.0


def on_stage_end() -> None:
    """스테이지 종료 시 버프 제거."""

    _STATE.reset_stage()


def is_angel_dice_active() -> bool:
    """현재 천사의 주사위 버프가 적용 중인지 여부."""

    return _STATE.active and bool(_STATE.active_buffs)


def get_angel_dice_multipliers() -> Dict[str, float]:
    """현재 적용 중인 천사의 주사위 배율을 반환한다."""

    return _STATE.multipliers.copy()


def is_angel_dice_animating() -> bool:
    """주사위 연출 애니메이션 중인지 여부."""

    return _STATE.animating


def is_angel_dice_waiting_for_space() -> bool:
    """주사위 연출이 스페이스 입력을 기다리는지 여부."""

    return _STATE.wait_for_space


def update_angel_dice(current_stage: int) -> None:
    """천사의 주사위 애니메이션 업데이트."""

    if not _STATE.active:
        return

    if _STATE.current_stage is not None and current_stage != _STATE.current_stage:
        _STATE.reset_stage()
        return

    if not _STATE.animating and not _STATE.wait_for_space:
        return

    if _STATE.animating:
        _STATE.animation_timer += 1

        if _STATE.animation_timer < _STATE._anim_reveal and _STATE.animation_timer % 3 == 0:
            _STATE.face_value = random.randint(1, 6)
        elif _STATE.animation_timer >= _STATE._anim_reveal:
            _STATE.face_value = max(1, _STATE.roll_value)

        if _STATE.animation_timer >= _STATE._anim_buff_start:
            reveal_elapsed = _STATE.animation_timer - _STATE._anim_buff_start
            visible = min(len(_STATE.active_buffs), max(0, reveal_elapsed // _BUFF_REVEAL_INTERVAL + 1))
            if visible != _STATE.visible_buffs:
                _STATE.visible_buffs = visible
            if visible >= len(_STATE.active_buffs) and _STATE.active_buffs:
                _STATE.wait_for_space = True

        if _STATE.animation_timer >= _STATE._anim_total_frames:
            if len(_STATE.active_buffs) and _STATE.visible_buffs < len(_STATE.active_buffs):
                _STATE._anim_total_frames = _STATE.animation_timer + 1
            else:
                _STATE.animating = False
                _STATE.visible_buffs = len(_STATE.active_buffs)
                _STATE.wait_for_space = bool(_STATE.active_buffs)

    if _STATE.animating:
        _STATE.dice_velocity += _DICE_GRAVITY
        _STATE.dice_offset_y += _STATE.dice_velocity

        if _STATE.dice_offset_y > 0:
            _STATE.dice_offset_y = 0
            _STATE.dice_velocity *= -0.6
            if abs(_STATE.dice_velocity) < 1.2:
                _STATE.dice_velocity = -2.4
        elif _STATE.dice_offset_y < _DICE_MIN_BOUNCE:
            _STATE.dice_offset_y = _DICE_MIN_BOUNCE
            if _STATE.dice_velocity < 0:
                _STATE.dice_velocity *= -0.6
    elif _STATE.wait_for_space:
        _STATE.idle_phase += 0.08
        _STATE.dice_offset_y = _DICE_IDLE_BASE + math.sin(_STATE.idle_phase * 0.9) * _DICE_IDLE_AMPLITUDE
        _STATE.dice_velocity = 0.0
    else:
        _STATE.dice_offset_y = 0.0
        _STATE.dice_velocity = 0.0
        _STATE.idle_phase = 0.0


def get_angel_dice_results() -> Dict[str, object]:
    """주사위 결과 정보를 반환 (UI 디버그 용도)."""

    return {
        "active": _STATE.active,
        "stage": _STATE.current_stage,
        "roll": _STATE.roll_value,
        "buffs": list(_STATE.active_buffs),
        "multipliers": _STATE.multipliers.copy(),
    }


def _log_stage_roll(stage_num: int, roll_value: int, buffs: List[str]) -> None:
    """디버그 로그 출력."""

    try:
        buff_labels = {
            "paddle_size": "패들 크기 +50%",
            "skill_gauge": "스킬 게이지 +50%",
            "item_spawn": "아이템 스폰률 +50%",
            "item_cooldown": "아이템 쿨타임 -50%",
            "skill_dash_cost": "스킬/대쉬 비용 -50%",
            "dash_cooldown": "대쉬 쿨타임 -50%",
            "player_speed": "이동 속도 +50%",
        }
        selected = ", ".join(buff_labels[buff] for buff in buffs)
        print(f"🎲 천사의 주사위 (Stage {stage_num}) - 눈: {roll_value}, 버프: {selected}")
    except Exception:
        # 로깅 실패 시 조용히 무시
        pass


def draw_angel_dice_overlay(screen: pygame.Surface) -> None:
    """천사의 주사위 연출을 화면에 그린다."""

    if not _STATE.animating and not _STATE.wait_for_space:
        return

    width, height = screen.get_width(), screen.get_height()
    overlay = pygame.Surface((width, height), pygame.SRCALPHA)
    overlay.fill((15, 25, 55, 180))
    screen.blit(overlay, (0, 0))

    panel_width = 520
    panel_height = 420
    panel_x = (width - panel_width) // 2
    panel_y = (height - panel_height) // 2

    panel_surface = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
    pygame.draw.rect(panel_surface, (220, 230, 255, 235), panel_surface.get_rect(), border_radius=22)
    pygame.draw.rect(panel_surface, (120, 160, 255, 60), panel_surface.get_rect(), 6, border_radius=22)
    screen.blit(panel_surface, (panel_x, panel_y))

    title_font, body_font, small_font = _ensure_fonts()

    title = title_font.render("천사의 주사위", True, (40, 60, 140))
    title_rect = title.get_rect(center=(width // 2, panel_y + 40))
    screen.blit(title, title_rect)

    subtitle = body_font.render("천상의 축복이 선택됩니다", True, (70, 90, 170))
    subtitle_rect = subtitle.get_rect(center=(width // 2, panel_y + 80))
    screen.blit(subtitle, subtitle_rect)

    dice_center_x = width // 2
    dice_center_y = panel_y + 200 + int(_STATE.dice_offset_y)
    _draw_dice(screen, dice_center_x, dice_center_y, 160, _STATE.face_value, 0.0, 0.0)

    reveal = _STATE.animation_timer >= _STATE._anim_reveal
    buff_phase = _STATE.animation_timer >= _STATE._anim_buff_start

    buff_labels = _BUFF_LABELS
    active_buffs = list(_STATE.active_buffs)

    visible_buffs = _STATE.visible_buffs if buff_phase else 0

    if buff_phase and visible_buffs > 0:
        text_panel_height = 40 + visible_buffs * 34
        text_panel = pygame.Surface((panel_width - 40, text_panel_height), pygame.SRCALPHA)
        pygame.draw.rect(text_panel, (210, 220, 255, 220), text_panel.get_rect(), border_radius=18)
        screen.blit(text_panel, (panel_x + 20, panel_y + 240))

        start_y = panel_y + 262
        line_spacing = 34

        for idx, key in enumerate(active_buffs[:visible_buffs]):
            label = buff_labels[key]
            y_pos = start_y + idx * line_spacing

            color = (80, 180, 200) if key in {"item_cooldown", "skill_dash_cost", "dash_cooldown"} else (120, 200, 120)

            if small_font:
                label_surface = small_font.render(label, True, (70, 90, 130))
                value_surface = small_font.render("발동", True, color)
                reveal_time = _STATE._anim_buff_start + idx * _BUFF_REVEAL_INTERVAL
                fade_progress = min(1.0, max(0.0, (_STATE.animation_timer - reveal_time) / float(_BUFF_FADE_FRAMES)))
                alpha = int(255 * fade_progress)
                if alpha < 255:
                    label_surface.set_alpha(alpha)
                    value_surface.set_alpha(alpha)
                screen.blit(label_surface, (panel_x + 60, y_pos))
                value_rect = value_surface.get_rect(right=panel_x + panel_width - 60, centery=y_pos + 8)
                screen.blit(value_surface, value_rect)

    # 버프 수가 적어도 하단 안내 문구는 숨겨 UI가 겹치지 않도록 유지한다.


def handle_angel_dice_space() -> None:
    """천사의 주사위 애니메이션이 끝난 후 스페이스 입력 처리."""

    if _STATE.wait_for_space:
        _STATE.animating = False
        _STATE.animation_timer = _STATE._anim_total_frames
        _STATE.wait_for_space = False
        _STATE.dice_offset_y = 0.0
        _STATE.dice_velocity = 0.0
        _STATE.idle_phase = 0.0


def _draw_dice(
    screen: pygame.Surface,
    center_x: int,
    center_y: int,
    size: int,
    face: int,
    angle: float,
    flash: float,
) -> None:
    """천사의 주사위 주사면을 그린다."""

    size = max(90, size)
    surface = pygame.Surface((size, size), pygame.SRCALPHA)
    rect = surface.get_rect()

    glow_radius = int(size * 0.55)
    glow_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
    pygame.draw.circle(glow_surface, (220, 235, 255, 120), (size, size), glow_radius)
    pygame.draw.circle(glow_surface, (180, 210, 255, 90), (size, size), int(glow_radius * 0.7))
    screen.blit(glow_surface, (center_x - size, center_y - size), special_flags=pygame.BLEND_PREMULTIPLIED)

    border_radius = int(size * 0.22)
    inner_radius = max(6, int(size * 0.18))

    pygame.draw.rect(surface, (240, 245, 255), rect, border_radius=border_radius)
    inner_rect = rect.inflate(-int(size * 0.22), -int(size * 0.22))
    pygame.draw.rect(surface, (200, 215, 255), inner_rect, border_radius=inner_radius)
    pygame.draw.rect(surface, (255, 255, 255), inner_rect, width=3, border_radius=inner_radius)

    highlight_height = max(8, int(inner_rect.height * 0.28))
    highlight_surface = pygame.Surface((inner_rect.width, highlight_height), pygame.SRCALPHA)
    pygame.draw.rect(highlight_surface, (255, 255, 255, 120), highlight_surface.get_rect(), border_radius=int(inner_rect.width * 0.12))
    surface.blit(highlight_surface, (inner_rect.left, inner_rect.top - 4))

    pip_layouts = {
        1: [(0, 0)],
        2: [(-1, -1), (1, 1)],
        3: [(-1, -1), (0, 0), (1, 1)],
        4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
        5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
        6: [(-1, -1.1), (1, -1.1), (-1, 0), (1, 0), (-1, 1.1), (1, 1.1)],
    }

    pip_offset = size * 0.26
    pip_radius = max(5, int(size * 0.08))
    face_value = max(1, min(6, face))

    for px, py in pip_layouts.get(face_value, [(0, 0)]):
        cx = int(rect.centerx + px * pip_offset)
        cy = int(rect.centery + py * pip_offset)
        pygame.draw.circle(surface, (190, 210, 255, 130), (cx, cy), pip_radius + 3)
        pygame.draw.circle(surface, (255, 255, 255), (cx, cy), pip_radius)
        pygame.draw.circle(surface, (140, 170, 240), (cx, cy), max(2, pip_radius - 3))

    rotation = angle
    rotated = pygame.transform.rotozoom(surface, rotation, 1.0)
    rotated_rect = rotated.get_rect(center=(center_x, center_y))
    screen.blit(rotated, rotated_rect)


def _ensure_fonts():
    global _FONT_TITLE, _FONT_BODY, _FONT_SMALL
    if _FONT_TITLE is not None:
        return _FONT_TITLE, _FONT_BODY, _FONT_SMALL

    try:
        _FONT_TITLE = pygame.font.Font(resource_path("fonts/pixel/NeoDunggeunmoPro.ttf"), 42)
        _FONT_BODY = pygame.font.Font(resource_path("fonts/pixel/NeoDunggeunmoPro.ttf"), 26)
        _FONT_SMALL = pygame.font.Font(resource_path("fonts/pixel/NeoDunggeunmoPro.ttf"), 20)
    except Exception:
        _FONT_TITLE = pygame.font.Font(None, 42)
        _FONT_BODY = pygame.font.Font(None, 26)
        _FONT_SMALL = pygame.font.Font(None, 20)

    return _FONT_TITLE, _FONT_BODY, _FONT_SMALL


try:
    from resource_path import resource_path
except Exception:
    def resource_path(path: str) -> str:  # type: ignore
        return path


_ANIMATION_DURATION = 120
_REVEAL_FRAME = 45
_FONT_TITLE = None
_FONT_BODY = None
_FONT_SMALL = None
_BUFF_LABELS = {
    "paddle_size": "패들 크기 +50%",
    "skill_gauge": "스킬 게이지 +50%",
    "item_spawn": "아이템 스폰률 +50%",
    "item_cooldown": "아이템 쿨타임 -50%",
    "skill_dash_cost": "스킬/대쉬 비용 -50%",
    "dash_cooldown": "대쉬 쿨타임 -50%",
    "player_speed": "이동 속도 +50%",
}
