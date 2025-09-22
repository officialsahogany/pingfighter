"""일시정지 관련 UI 컴포넌트."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import pygame

from pixel_font_manager import FontStyle
from game_state.audio import clamp_volume
from config import constants as const


@dataclass(slots=True)
class PauseOptionsContext:
    screen: pygame.Surface
    width: int
    height: int
    draw_field: Callable[[], None]
    draw_shaking_screen: Callable[[], None]
    draw_objects: Callable[[], None]
    draw_water_trail: Callable[[], None]
    play_button_click_sound: Callable[[], None]
    get_bgm_runtime_volume: Callable[[], float]
    apply_bgm_volume: Callable[[float], None]
    store_bgm_volume: Callable[[float], float]
    get_sfx_volume: Callable[[], float]
    set_sfx_volume: Callable[[float], float]
    get_modern_loop_enabled: Callable[[], bool]
    set_modern_loop_enabled: Callable[[bool], None]
    clock_factory: Callable[[], pygame.time.Clock] = pygame.time.Clock


def show_pause_options(ctx: PauseOptionsContext) -> None:
    """일시정지 옵션 메뉴 - 볼륨 조절 UI"""

    font_large = FontStyle.subtitle()
    font_medium = FontStyle.body()
    font_small = FontStyle.small()

    current_bgm_volume = clamp_volume(ctx.get_bgm_runtime_volume())
    current_sfx_volume = clamp_volume(ctx.get_sfx_volume())

    slider_width = 400
    slider_height = 10
    handle_size = 20

    panel_width = 600
    panel_height = 400
    panel_x = (ctx.width - panel_width) // 2
    panel_y = (ctx.height - panel_height) // 2

    bgm_slider_x = panel_x + (panel_width - slider_width) // 2
    bgm_slider_y = panel_y + 120
    sfx_slider_x = panel_x + (panel_width - slider_width) // 2
    sfx_slider_y = panel_y + 220

    back_button_width = 150
    back_button_height = 50
    back_button_x = panel_x + (panel_width - back_button_width) // 2
    back_button_y = panel_y + 320
    back_button_rect = pygame.Rect(back_button_x, back_button_y, back_button_width, back_button_height)

    selected_slider: str | None = None
    dragging = False

    clock = ctx.clock_factory()
    running = True

    while running:
        ctx.draw_field()
        ctx.draw_shaking_screen()
        ctx.draw_objects()
        ctx.draw_water_trail()

        overlay = pygame.Surface((ctx.width, ctx.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        ctx.screen.blit(overlay, (0, 0))

        panel = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        panel.fill((30, 30, 40, 240))
        pygame.draw.rect(panel, const.CYAN, (0, 0, panel_width, panel_height), 3, border_radius=10)
        ctx.screen.blit(panel, (panel_x, panel_y))

        title_text = font_large.render("음악 설정", True, const.WHITE)
        title_rect = title_text.get_rect(center=(ctx.width // 2, panel_y + 40))
        ctx.screen.blit(title_text, title_rect)

        bgm_label = font_medium.render("BGM 볼륨", True, const.WHITE)
        bgm_label_rect = bgm_label.get_rect(left=bgm_slider_x, bottom=bgm_slider_y - 10)
        ctx.screen.blit(bgm_label, bgm_label_rect)

        pygame.draw.rect(ctx.screen, (60, 60, 60), (bgm_slider_x, bgm_slider_y, slider_width, slider_height), border_radius=5)
        pygame.draw.rect(
            ctx.screen,
            (0, 200, 255),
            (bgm_slider_x, bgm_slider_y, int(slider_width * current_bgm_volume), slider_height),
            border_radius=5,
        )

        bgm_handle_x = bgm_slider_x + int(slider_width * current_bgm_volume)
        bgm_handle_rect = pygame.Rect(
            bgm_handle_x - handle_size // 2,
            bgm_slider_y - (handle_size - slider_height) // 2,
            handle_size,
            handle_size,
        )
        pygame.draw.circle(
            ctx.screen,
            const.WHITE if selected_slider == "bgm" else (200, 200, 200),
            (bgm_handle_x, bgm_slider_y + slider_height // 2),
            handle_size // 2,
        )

        bgm_percent = font_small.render(f"{int(current_bgm_volume * 100)}%", True, const.CYAN)
        bgm_percent_rect = bgm_percent.get_rect(left=bgm_slider_x + slider_width + 20, centery=bgm_slider_y + slider_height // 2)
        ctx.screen.blit(bgm_percent, bgm_percent_rect)

        sfx_label = font_medium.render("효과음 볼륨", True, const.WHITE)
        sfx_label_rect = sfx_label.get_rect(left=sfx_slider_x, bottom=sfx_slider_y - 10)
        ctx.screen.blit(sfx_label, sfx_label_rect)

        pygame.draw.rect(ctx.screen, (60, 60, 60), (sfx_slider_x, sfx_slider_y, slider_width, slider_height), border_radius=5)
        pygame.draw.rect(
            ctx.screen,
            (0, 255, 100),
            (sfx_slider_x, sfx_slider_y, int(slider_width * current_sfx_volume), slider_height),
            border_radius=5,
        )

        sfx_handle_x = sfx_slider_x + int(slider_width * current_sfx_volume)
        sfx_handle_rect = pygame.Rect(
            sfx_handle_x - handle_size // 2,
            sfx_slider_y - (handle_size - slider_height) // 2,
            handle_size,
            handle_size,
        )
        pygame.draw.circle(
            ctx.screen,
            const.WHITE if selected_slider == "sfx" else (200, 200, 200),
            (sfx_handle_x, sfx_slider_y + slider_height // 2),
            handle_size // 2,
        )

        sfx_percent = font_small.render(f"{int(current_sfx_volume * 100)}%", True, (0, 255, 100))
        sfx_percent_rect = sfx_percent.get_rect(left=sfx_slider_x + slider_width + 20, centery=sfx_slider_y + slider_height // 2)
        ctx.screen.blit(sfx_percent, sfx_percent_rect)

        button_color = (100, 150, 255) if back_button_rect.collidepoint(pygame.mouse.get_pos()) else (50, 50, 50)
        pygame.draw.rect(ctx.screen, button_color, back_button_rect, border_radius=5)
        pygame.draw.rect(ctx.screen, const.WHITE, back_button_rect, 2, border_radius=5)

        back_text = font_medium.render("뒤로가기", True, const.WHITE)
        back_text_rect = back_text.get_rect(center=back_button_rect.center)
        ctx.screen.blit(back_text, back_text_rect)

        hint_text = font_small.render("마우스 클릭/드래그/휠로 조절, ESC로 돌아가기", True, (150, 150, 150))
        hint_rect = hint_text.get_rect(center=(ctx.width // 2, panel_y + panel_height - 30))
        ctx.screen.blit(hint_text, hint_rect)

        pygame.display.flip()
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    current_bgm_volume = ctx.store_bgm_volume(current_bgm_volume)
                    current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                    return
                if event.key == pygame.K_LEFT:
                    if selected_slider == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume - 0.05)
                        ctx.apply_bgm_volume(current_bgm_volume)
                    elif selected_slider == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume - 0.05)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                elif event.key == pygame.K_RIGHT:
                    if selected_slider == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume + 0.05)
                        ctx.apply_bgm_volume(current_bgm_volume)
                    elif selected_slider == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume + 0.05)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                elif event.key == pygame.K_UP:
                    selected_slider = "bgm"
                elif event.key == pygame.K_DOWN:
                    selected_slider = "sfx"

            elif event.type == pygame.MOUSEBUTTONDOWN:
                mouse_pos = pygame.mouse.get_pos()
                mouse_x = mouse_pos[0]

                if back_button_rect.collidepoint(mouse_pos):
                    ctx.play_button_click_sound()
                    current_bgm_volume = ctx.store_bgm_volume(current_bgm_volume)
                    current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                    return

                bgm_slider_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 10, slider_width, slider_height + 20)
                if bgm_slider_rect.collidepoint(mouse_pos) or bgm_handle_rect.collidepoint(mouse_pos):
                    selected_slider = "bgm"
                    dragging = True
                    relative_x = mouse_x - bgm_slider_x
                    current_bgm_volume = clamp_volume(relative_x / slider_width)
                    ctx.apply_bgm_volume(current_bgm_volume)

                sfx_slider_rect = pygame.Rect(sfx_slider_x, sfx_slider_y - 10, slider_width, slider_height + 20)
                if sfx_slider_rect.collidepoint(mouse_pos) or sfx_handle_rect.collidepoint(mouse_pos):
                    selected_slider = "sfx"
                    dragging = True
                    relative_x = mouse_x - sfx_slider_x
                    current_sfx_volume = clamp_volume(relative_x / slider_width)
                    current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)

            elif event.type == pygame.MOUSEBUTTONUP:
                dragging = False
                if selected_slider:
                    ctx.play_button_click_sound()

            elif event.type == pygame.MOUSEMOTION and dragging:
                mouse_x = pygame.mouse.get_pos()[0]
                if selected_slider == "bgm":
                    relative_x = mouse_x - bgm_slider_x
                    current_bgm_volume = clamp_volume(relative_x / slider_width)
                    ctx.apply_bgm_volume(current_bgm_volume)
                elif selected_slider == "sfx":
                    relative_x = mouse_x - sfx_slider_x
                    current_sfx_volume = clamp_volume(relative_x / slider_width)
                    current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)

            elif event.type == pygame.MOUSEWHEEL:
                mouse_pos = pygame.mouse.get_pos()
                bgm_slider_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 10, slider_width, slider_height + 20)
                sfx_slider_rect = pygame.Rect(sfx_slider_x, sfx_slider_y - 10, slider_width, slider_height + 20)

                if bgm_slider_rect.collidepoint(mouse_pos) or selected_slider == "bgm":
                    current_bgm_volume = clamp_volume(current_bgm_volume + event.y * 0.02)
                    ctx.apply_bgm_volume(current_bgm_volume)
                    selected_slider = "bgm"
                elif sfx_slider_rect.collidepoint(mouse_pos) or selected_slider == "sfx":
                    current_sfx_volume = clamp_volume(current_sfx_volume + event.y * 0.02)
                    current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                    selected_slider = "sfx"

    ctx.store_bgm_volume(current_bgm_volume)
    ctx.set_sfx_volume(current_sfx_volume)
