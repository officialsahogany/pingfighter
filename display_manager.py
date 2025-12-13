"""화면 및 해상도 관련 유틸리티."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Sequence, Tuple, Optional

import pygame

# 전체화면 모드 설정 (pingfighter.py에서 설정됨)
_fullscreen_mode_active = False
_fullscreen_game_surface: Optional[pygame.Surface] = None

def set_fullscreen_mode(active: bool, game_surface: Optional[pygame.Surface] = None):
    """전체화면 모드 설정 (pingfighter.py에서 호출)"""
    global _fullscreen_mode_active, _fullscreen_game_surface
    _fullscreen_mode_active = active
    _fullscreen_game_surface = game_surface

ResolutionOption = Tuple[int, int]


@dataclass
class DisplayFactories:
    draw: Callable[[pygame.Surface], object]
    unified_renderer: Callable[[pygame.Surface, int, int], object]
    dialog_system: Callable[[pygame.Surface, int, int], object]
    menu_system: Callable[[pygame.Surface, int, int], object]
    trade_point_with_size: Callable[[pygame.Surface, int, int], object]
    trade_point_simple: Callable[[pygame.Surface], object]
    ui_manager_init: Callable[[pygame.Surface, object, int, int], None]
    effects_manager_init: Callable[[pygame.Surface, int, int], None]
    physics_manager_init: Callable[[pygame.Surface, object, object, object, int, int], None]
    initialize_legendary_effects: Callable[[int, int], None]
    initialize_item_effects: Callable[[int, int], None]


@dataclass
class ChangeResolutionResult:
    screen: pygame.Surface
    width: int
    height: int
    draw: object
    unified_renderer: object
    dialog_system: object
    menu_system: object
    trade_point_system: object
    index: int


def change_resolution(
    *,
    direction: int,
    current_resolution_index: int,
    resolution_options: Sequence[ResolutionOption],
    internal_width: int,
    internal_height: int,
    factories: DisplayFactories,
    font: object,
    ball: object,
    player: object,
    boss: object,
    screen_flags: int = pygame.SCALED,
) -> ChangeResolutionResult:
    """화면 스케일 해상도를 변경하고 관련 시스템을 재구성한다."""

    next_index = (current_resolution_index + direction) % len(resolution_options)
    new_width, new_height = resolution_options[next_index]

    # 전체화면 모드에서는 기존 게임 Surface를 유지
    if _fullscreen_mode_active and _fullscreen_game_surface is not None:
        screen = _fullscreen_game_surface
        # 전체화면 모드에서는 해상도 변경 무시 (게임 크기 고정)
        new_width = internal_width
        new_height = internal_height
    else:
        screen = pygame.display.set_mode((new_width, new_height), screen_flags)

    draw = factories.draw(screen)
    unified_renderer = factories.unified_renderer(screen, internal_width, internal_height)
    dialog_system = factories.dialog_system(screen, internal_width, internal_height)
    menu_system = factories.menu_system(screen, internal_width, internal_height)
    trade_point_system = factories.trade_point_with_size(screen, internal_width, internal_height)

    factories.ui_manager_init(screen, font, internal_width, internal_height)
    factories.effects_manager_init(screen, internal_width, internal_height)
    factories.physics_manager_init(screen, ball, player, boss, internal_width, internal_height)

    factories.initialize_legendary_effects(internal_width, internal_height)
    factories.initialize_item_effects(internal_width, internal_height)

    return ChangeResolutionResult(
        screen=screen,
        width=new_width,
        height=new_height,
        draw=draw,
        unified_renderer=unified_renderer,
        dialog_system=dialog_system,
        menu_system=menu_system,
        trade_point_system=trade_point_system,
        index=next_index,
    )


@dataclass
class ChangeInternalResolutionResult:
    screen: pygame.Surface
    draw: object
    unified_renderer: object
    dialog_system: object
    menu_system: object
    trade_point_system: object


def change_internal_resolution(
    *,
    new_width: int,
    new_height: int,
    factories: DisplayFactories,
    ball: object,
    player: object,
    boss: object,
) -> ChangeInternalResolutionResult:
    """게임 내부 해상도를 변경하면서 화면/객체를 재설정한다."""

    # 전체화면 모드에서는 기존 게임 Surface를 유지
    if _fullscreen_mode_active and _fullscreen_game_surface is not None:
        screen = _fullscreen_game_surface
    else:
        screen = pygame.display.set_mode((new_width, new_height))

    draw = factories.draw(screen)
    unified_renderer = factories.unified_renderer(screen, new_width, new_height)
    dialog_system = factories.dialog_system(screen, new_width, new_height)
    menu_system = factories.menu_system(screen, new_width, new_height)
    trade_point_system = factories.trade_point_simple(screen)

    factories.ui_manager_init(screen, None, new_width, new_height)
    factories.effects_manager_init(screen, new_width, new_height)
    factories.physics_manager_init(screen, ball, player, boss, new_width, new_height)

    return ChangeInternalResolutionResult(
        screen=screen,
        draw=draw,
        unified_renderer=unified_renderer,
        dialog_system=dialog_system,
        menu_system=menu_system,
        trade_point_system=trade_point_system,
    )
