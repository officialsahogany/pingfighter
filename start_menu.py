"""메인 시작 메뉴 화면 로직."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, List, Optional, Sequence, Tuple

import math
import pygame

from start_menu_decorations import (
    StarField,
    draw_neon_particles,
    draw_scan_lines,
    draw_star_field,
)
from start_menu_config import (
    ENABLE_NEON_PARTICLES,
    ENABLE_SCAN_LINES,
    IDLE_CINEMATIC_DELAY_MS,
)

BASE_MENU_OPTIONS = ["경기장 입장", "개발테스트", "메달샵", "크레딧"]
MENU_ICONS = {
    "경기장 입장": "▶",
    "AI 플레이": "🤖",
    "테스트메뉴": "★",
    "개발테스트": "🧪",
    "메달샵": "◆",
    "크레딧": "●",
    "개발자": "⚙",
}
VERSION_TEXT = "1.4v beta"
DEV_CODE = [1]
ITEM_CODE = [2]

MEDAL_FRAME_DURATION = 0.085
MEDAL_BASE_SIZE = 40


def _ensure_medal_animation_assets(ctx: MenuContext, state: MenuState) -> None:
    """메달 애니메이션에 필요한 프레임을 초기화."""
    if state.medal_icon_frames:
        return

    base_icon: pygame.Surface | None = None
    try:
        medal_path = ctx.resource_path("medal.png")
        base_icon = pygame.image.load(medal_path).convert_alpha()
    except Exception:
        base_icon = None

    if base_icon is not None:
        base_icon = pygame.transform.smoothscale(base_icon, (MEDAL_BASE_SIZE, MEDAL_BASE_SIZE))
    else:
        # 이미지 로드 실패 시 간단한 원형 아이콘 생성
        base_icon = pygame.Surface((MEDAL_BASE_SIZE, MEDAL_BASE_SIZE), pygame.SRCALPHA)
        center = MEDAL_BASE_SIZE // 2
        pygame.draw.circle(base_icon, (255, 220, 120), (center, center), center)
        pygame.draw.circle(base_icon, (255, 240, 200), (center, center), center - 4)
        pygame.draw.circle(base_icon, (240, 180, 60), (center, center), center - 8)

    scales = [1.0]
    for scale in scales:
        size = max(8, int(MEDAL_BASE_SIZE * scale))
        frame = pygame.transform.smoothscale(base_icon, (size, size))
        state.medal_icon_frames.append(frame)


def _advance_medal_animation(state: MenuState, elapsed: float) -> None:
    """프레임 타이머를 업데이트하고 현재 프레임을 선택."""
    if not state.medal_icon_frames:
        return

    state.medal_frame_timer += elapsed
    if state.medal_frame_timer >= MEDAL_FRAME_DURATION:
        steps = int(state.medal_frame_timer / MEDAL_FRAME_DURATION)
        state.medal_frame_timer -= MEDAL_FRAME_DURATION * steps
        state.medal_frame_index = (state.medal_frame_index + steps) % len(state.medal_icon_frames)

def _run_idle_cinematic_if_needed(
    ctx: MenuContext,
    state: MenuState,
    screen: pygame.Surface,
    width: int,
    height: int,
    current_time: int,
) -> None:
    if current_time - state.idle_start_time >= IDLE_CINEMATIC_DELAY_MS:
        ctx.idle_cinematic(screen, width, height)
        state.idle_start_time = pygame.time.get_ticks()


def _update_background_layers(
    ctx: MenuContext,
    state: MenuState,
    dt: float,
    screen: pygame.Surface,
    width: int,
    height: int,
) -> None:
    simple_bg = ctx.simple_bg
    if simple_bg is not None:
        simple_bg.update(dt)
        simple_bg.draw(screen)

    state.star_field = draw_star_field(screen, width, height, state.animation_timer, state.star_field)
    if ENABLE_NEON_PARTICLES:
        state.neon_particles = draw_neon_particles(
            screen,
            width,
            height,
            state.animation_timer,
            state.neon_particles,
        )
    elif state.neon_particles:
        state.neon_particles.clear()
    if ENABLE_SCAN_LINES:
        state.scan_lines = draw_scan_lines(screen, width, height, state.scan_lines)


def _build_menu_options(state: MenuState) -> List[str]:
    menu_options = list(BASE_MENU_OPTIONS)
    if state.developer_unlocked and "개발자" not in menu_options:
        menu_options.append("개발자")
    if state.selected >= len(menu_options):
        state.selected = max(0, len(menu_options) - 1)
    return menu_options


def _render_menu(
    ctx: MenuContext,
    state: MenuState,
    screen: pygame.Surface,
    width: int,
    height: int,
    current_menu_options: List[str],
) -> None:
    _ensure_medal_animation_assets(ctx, state)

    elapsed = max(0.0, state.animation_timer - state.medal_anim_prev_time)
    state.medal_anim_prev_time = state.animation_timer
    _advance_medal_animation(state, elapsed)

    medal_center_x = width - 70
    medal_center_y = 45

    if state.medal_icon_frames:
        current_frame = state.medal_icon_frames[state.medal_frame_index]
        frame_rect = current_frame.get_rect(center=(medal_center_x, medal_center_y))

        glow_radius = int(max(frame_rect.width, frame_rect.height) * 0.6)
        glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        glow_alpha = 40 + int(30 * (math.sin(state.animation_timer * 2.0) * 0.5 + 0.5))
        pygame.draw.circle(glow_surface, (255, 215, 140, glow_alpha), (glow_radius, glow_radius), glow_radius)
        screen.blit(glow_surface, (frame_rect.centerx - glow_radius, frame_rect.centery - glow_radius))

        screen.blit(current_frame, frame_rect)
    else:
        fallback_size = MEDAL_BASE_SIZE
        fallback_surface = pygame.Surface((fallback_size, fallback_size), pygame.SRCALPHA)
        pygame.draw.circle(fallback_surface, (255, 220, 120), (fallback_size // 2, fallback_size // 2), fallback_size // 2)
        frame_rect = fallback_surface.get_rect(center=(medal_center_x, medal_center_y))
        screen.blit(fallback_surface, frame_rect)

    font_medal = ctx.FontStyle.body()
    medal_value = str(ctx.medal_score_getter())
    text_surface = font_medal.render(medal_value, True, (255, 230, 150))
    shadow_surface = font_medal.render(medal_value, True, (40, 30, 10))
    text_rect = text_surface.get_rect(midleft=(frame_rect.right + 12, frame_rect.centery))
    shadow_rect = text_rect.copy()
    shadow_rect.x += 2
    shadow_rect.y += 2
    screen.blit(shadow_surface, shadow_rect)
    screen.blit(text_surface, text_rect)

    _draw_titles(ctx, screen, width, state.animation_timer)

    menu_y = height - 180
    menu_item_width = 120
    menu_spacing = 15
    total_width = len(current_menu_options) * menu_item_width + (len(current_menu_options) - 1) * menu_spacing
    menu_start_x = (width - total_width) // 2
    font_menu = ctx.FontStyle.small()
    font_icon = ctx.get_font(36)

    for idx, option in enumerate(current_menu_options):
        x = menu_start_x + idx * (menu_item_width + menu_spacing)
        if idx == state.selected:
            glow_surf = pygame.Surface((menu_item_width + 16, 70), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (0, 255, 255, 30), (0, 0, menu_item_width + 16, 70), border_radius=12)
            screen.blit(glow_surf, (x - 8, menu_y - 8))
            container = pygame.Surface((menu_item_width, 54), pygame.SRCALPHA)
            pygame.draw.rect(container, (0, 50, 80, 180), (0, 0, menu_item_width, 54), border_radius=8)
            pygame.draw.rect(container, (0, 255, 255, 255), (0, 0, menu_item_width, 54), 2, border_radius=8)
            screen.blit(container, (x, menu_y))
            for j in range(3):
                dot_x = x + menu_item_width // 2 + (j - 1) * 12
                dot_y = menu_y + 62
                dot_size = 2 + abs(math.sin(state.animation_timer * 3 + j)) * 1.5
                pygame.draw.circle(screen, (0, 255, 255), (int(dot_x), int(dot_y)), int(dot_size))
        else:
            container = pygame.Surface((menu_item_width, 54), pygame.SRCALPHA)
            pygame.draw.rect(container, (20, 30, 50, 120), (0, 0, menu_item_width, 54), border_radius=8)
            pygame.draw.rect(container, (100, 150, 200, 100), (0, 0, menu_item_width, 54), 1, border_radius=8)
            screen.blit(container, (x, menu_y))

        icon = MENU_ICONS.get(option, "")
        if icon:
            icon_surface = font_icon.render(icon, True, (0, 255, 255))
            icon_rect = icon_surface.get_rect(center=(x + menu_item_width // 2, menu_y + 18))
            screen.blit(icon_surface, icon_rect)

        display_text = option
        if option == "경기장 입장":
            display_text = "경기장"
        elif option == "AI 플레이":
            display_text = "AI플레이"
        elif option == "테스트메뉴":
            display_text = "테스트"
        elif option == "개발테스트":
            display_text = "개발테스트"
        text_surface = font_menu.render(display_text, True, (255, 255, 255))
        text_rect = text_surface.get_rect(center=(x + menu_item_width // 2, menu_y + 38))
        screen.blit(text_surface, text_rect)

        if idx == state.selected and option == "개발테스트":
            font_desc = ctx.FontStyle.tiny()
            desc = font_desc.render("개발용 AI/테스트 모드", True, (200, 200, 255))
            desc_rect = desc.get_rect(center=(width // 2, menu_y + 75))
            screen.blit(desc, desc_rect)

    if state.locked_message_timer > 0:
        message_width = 400
        message_height = 40
        message_x = width // 2 - message_width // 2
        message_y = menu_y + 100
        for j in range(10, 0, -2):
            alpha = int(60 * (1 - j / 10))
            glow_surface = pygame.Surface((message_width + j * 2, message_height + j * 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surface, (255, 100, 100, alpha), (0, 0, message_width + j * 2, message_height + j * 2), border_radius=ctx.default_radius)
            screen.blit(glow_surface, (message_x - j, message_y - j))
        message_bg = pygame.Surface((message_width, message_height), pygame.SRCALPHA)
        pygame.draw.rect(message_bg, (255, 100, 100, 40), (0, 0, message_width, message_height), border_radius=ctx.default_radius)
        pygame.draw.rect(message_bg, (255, 100, 100, 120), (0, 0, message_width, message_height), 2, border_radius=ctx.default_radius)
        screen.blit(message_bg, (message_x, message_y))
        font_message = ctx.FontStyle.body()
        shadow = font_message.render("모든 보스를 클리어시 해금됩니다", True, (100, 50, 50))
        shadow_rect = shadow.get_rect(center=(width // 2 + 1, 600 + 1))
        screen.blit(shadow, shadow_rect)
        text = font_message.render("모든 보스를 클리어시 해금됩니다", True, (255, 150, 150))
        text_rect = text.get_rect(center=(width // 2, 600))
        screen.blit(text, text_rect)
        state.locked_message_timer -= 1

    font_tiny = ctx.FontStyle.tiny()
    version_surface = font_tiny.render(VERSION_TEXT, True, (160, 200, 255))
    version_rect = version_surface.get_rect(bottomleft=(10, height - 10))
    screen.blit(version_surface, version_rect)

    res_index = ctx.get_current_resolution_index()
    res_width, res_height = ctx.resolution_options[res_index]
    resolution_text = f"해상도: {res_width}x{res_height} (F9/F10으로 변경)"
    resolution_surface = font_tiny.render(resolution_text, True, (150, 200, 255))
    resolution_rect = resolution_surface.get_rect(bottomright=(width - 10, height - 10))
    screen.blit(resolution_surface, resolution_rect)


def _run_ai_play_flow(ctx: MenuContext) -> bool:
    """AI 플레이 캐릭터 선택 후 게임 시작."""
    ai_chars = [
        ("smasher", "스매셔"),
        ("soldier", "코만도"),
        ("blacksmith", "발토르"),
    ]
    selected = 0
    clock = pygame.time.Clock()
    font_title = ctx.FontStyle.body()
    font_item = ctx.FontStyle.body()
    running = True
    while running:
        clock.tick(60)
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit
            if ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_RIGHT, pygame.K_d):
                    selected = (selected + 1) % len(ai_chars)
                elif ev.key in (pygame.K_LEFT, pygame.K_a):
                    selected = (selected - 1) % len(ai_chars)
                elif ev.key in (pygame.K_RETURN, pygame.K_SPACE):
                    running = False
                elif ev.key == pygame.K_ESCAPE:
                    return False
            if ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mx, my = pygame.mouse.get_pos()
                width, height = ctx.get_dimensions()
                menu_y = height // 2
                item_w = 180
                spacing = 30
                total_w = len(ai_chars) * item_w + (len(ai_chars) - 1) * spacing
                start_x = (width - total_w) // 2
                for idx, (_cid, label) in enumerate(ai_chars):
                    rect = pygame.Rect(start_x + idx * (item_w + spacing), menu_y - 40, item_w, 80)
                    if rect.collidepoint(mx, my):
                        selected = idx
                        running = False
                        break

        # 렌더링
        screen = ctx.get_screen()
        width, height = ctx.get_dimensions()
        screen.fill((10, 20, 30))
        title = font_title.render("AI 플레이 캐릭터 선택", True, (200, 230, 255))
        screen.blit(title, title.get_rect(center=(width // 2, height // 2 - 100)))
        item_w = 180
        spacing = 30
        total_w = len(ai_chars) * item_w + (len(ai_chars) - 1) * spacing
        start_x = (width - total_w) // 2
        for idx, (_cid, label) in enumerate(ai_chars):
            x = start_x + idx * (item_w + spacing)
            rect = pygame.Rect(x, height // 2 - 40, item_w, 80)
            is_sel = idx == selected
            color = (60, 120, 200) if is_sel else (40, 60, 90)
            pygame.draw.rect(screen, color, rect, border_radius=10)
            pygame.draw.rect(screen, (160, 200, 255), rect, 2 if is_sel else 1, border_radius=10)
            label_surface = font_item.render(label, True, (255, 255, 255))
            screen.blit(label_surface, label_surface.get_rect(center=rect.center))
        pygame.display.flip()

    char_id, _ = ai_chars[selected]
    ctx.start_ai_play(character=char_id)
    return True


def _show_dev_test_menu(ctx: MenuContext, state: MenuState) -> bool:
    """메인 메뉴 하위 개발/테스트 묶음."""
    options = ["AI 플레이", "테스트메뉴", "뒤로"]
    selected = 0
    clock = pygame.time.Clock()
    while True:
        dt = clock.tick(60) / 1000.0
        state.animation_timer += dt
        screen = ctx.get_screen()
        width, height = ctx.get_dimensions()
        _update_background_layers(ctx, state, dt, screen, width, height)

        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit
            if ev.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN, pygame.MOUSEMOTION):
                state.idle_start_time = pygame.time.get_ticks()
            if ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_RIGHT, pygame.K_d, pygame.K_DOWN, pygame.K_s):
                    selected = (selected + 1) % len(options)
                elif ev.key in (pygame.K_LEFT, pygame.K_a, pygame.K_UP, pygame.K_w):
                    selected = (selected - 1) % len(options)
                elif ev.key in (pygame.K_RETURN, pygame.K_SPACE):
                    choice = options[selected]
                    if choice == "AI 플레이":
                        return _run_ai_play_flow(ctx)
                    if choice == "테스트메뉴":
                        ctx.start_test_mode()
                        return True
                    return False
                elif ev.key == pygame.K_ESCAPE:
                    return False
            if ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mx, my = ev.pos
                menu_y = height // 2
                item_w = 220
                spacing = 24
                total_w = len(options) * item_w + (len(options) - 1) * spacing
                start_x = (width - total_w) // 2
                for idx, opt in enumerate(options):
                    rect = pygame.Rect(start_x + idx * (item_w + spacing), menu_y - 40, item_w, 90)
                    if rect.collidepoint(mx, my):
                        selected = idx
                        if opt == "AI 플레이":
                            return _run_ai_play_flow(ctx)
                        if opt == "테스트메뉴":
                            ctx.start_test_mode()
                            return True
                        return False

        font_title = ctx.FontStyle.title()
        font_item = ctx.FontStyle.body()
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 120))
        screen.blit(overlay, (0, 0))

        title = font_title.render("개발 테스트", True, (200, 230, 255))
        screen.blit(title, title.get_rect(center=(width // 2, height // 2 - 130)))

        item_w = 220
        spacing = 24
        total_w = len(options) * item_w + (len(options) - 1) * spacing
        start_x = (width - total_w) // 2
        for idx, opt in enumerate(options):
            x = start_x + idx * (item_w + spacing)
            rect = pygame.Rect(x, height // 2 - 40, item_w, 90)
            is_sel = idx == selected
            bg_color = (50, 90, 140) if is_sel else (30, 40, 60)
            pygame.draw.rect(screen, bg_color, rect, border_radius=12)
            pygame.draw.rect(screen, (140, 200, 255), rect, 2 if is_sel else 1, border_radius=12)
            label_surface = font_item.render(opt, True, (255, 255, 255))
            screen.blit(label_surface, label_surface.get_rect(center=rect.center))
            if is_sel and opt in ("AI 플레이", "테스트메뉴"):
                hint = "AI 대전 시작" if opt == "AI 플레이" else "테스트/디버그 메뉴"
                hint_surf = ctx.FontStyle.tiny().render(hint, True, (210, 220, 255))
                screen.blit(hint_surf, hint_surf.get_rect(center=(rect.centerx, rect.bottom + 24)))

        pygame.display.flip()


def _activate_menu_choice(ctx: MenuContext, state: MenuState, choice: str) -> bool:
    if choice == "경기장 입장":
        if ctx.show_tutorial_dialog():
            ctx.start_tutorial_game()
        else:
            character = ctx.show_character_selection()
            if character is not None:
                difficulty = ctx.show_difficulty_selection()
                if difficulty is not None:
                    ctx.start_game_with_difficulty(character, difficulty)
        return True
    if choice == "AI 플레이":
        return _run_ai_play_flow(ctx)
    if choice == "테스트메뉴":
        ctx.start_test_mode()
        return True
    if choice == "개발테스트":
        return _show_dev_test_menu(ctx, state)
    if choice == "메달샵":
        state.locked_message_timer = ctx.two_seconds_frames
        return False
    if choice == "크레딧":
        ctx.show_credits_screen()
        return True
    if choice == "개발자":
        ctx.show_developer_stage_select()
        return True
    return False


def _handle_menu_events(
    ctx: MenuContext,
    state: MenuState,
    current_menu_options: List[str],
) -> bool:
    # 첫 진입 그레이스: 이벤트 큐를 읽기 전에 현재 마우스 다운 상태를 1회 클릭으로 취급
    # 최신 입력 상태 반영을 위해 우선 pump 수행
    pygame.event.pump()
    if state.first_click_grace_frames > 0:
        mb = pygame.mouse.get_pressed()
        if mb and len(mb) >= 1:
            left_now = bool(mb[0])
            if left_now and not state.last_mb_left_state:
                mouse_pos = pygame.mouse.get_pos()
                width = ctx.get_dimensions()[0]
                height = ctx.get_dimensions()[1]
                menu_y = height - 180
                menu_item_width = 120
                menu_spacing = 15
                total_width = len(current_menu_options) * menu_item_width + (len(current_menu_options) - 1) * menu_spacing
                menu_start_x = (width - total_width) // 2
                for idx, option in enumerate(current_menu_options):
                    x = menu_start_x + idx * (menu_item_width + menu_spacing)
                    option_rect = pygame.Rect(x, menu_y, menu_item_width, 54)
                    if option_rect.collidepoint(mouse_pos):
                        state.selected = idx
                        ctx.play_click_sound()
                        if _activate_menu_choice(ctx, state, option):
                            return False
                        break
            state.last_mb_left_state = left_now
        state.first_click_grace_frames = max(0, state.first_click_grace_frames - 1)

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit()
            raise SystemExit
        if event.type in (pygame.MOUSEBUTTONDOWN, pygame.MOUSEMOTION, pygame.KEYDOWN):
            state.idle_start_time = pygame.time.get_ticks()
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                pygame.quit()
                raise SystemExit
            if event.key == pygame.K_F9:
                _handle_resolution_change(ctx, state, -1)
                continue
            if event.key == pygame.K_F10:
                _handle_resolution_change(ctx, state, 1)
                continue
            if event.key == pygame.K_1:
                ctx.play_click_sound()
                ctx.show_developer_stage_select()
                return False
            if event.key == pygame.K_2 and state.item_manager_unlocked:
                ctx.play_click_sound()
                ctx.show_item_manager_menu()
                return False
            if pygame.K_0 <= event.key <= pygame.K_9:
                num = event.key - pygame.K_0
                state.input_buffer.append(num)
                state.input_buffer = state.input_buffer[-4:]
                if state.input_buffer[-len(DEV_CODE):] == DEV_CODE:
                    state.developer_unlocked = True
                if state.input_buffer[-len(ITEM_CODE):] == ITEM_CODE:
                    state.item_manager_unlocked = True
            if event.key in (pygame.K_RIGHT, pygame.K_d):
                ctx.play_hover_sound()
                state.selected = (state.selected + 1) % len(current_menu_options)
            elif event.key in (pygame.K_LEFT, pygame.K_a):
                ctx.play_hover_sound()
                state.selected = (state.selected - 1) % len(current_menu_options)
            elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                ctx.play_click_sound()
                choice = current_menu_options[state.selected]
                if _activate_menu_choice(ctx, state, choice):
                    return False
        if event.type == pygame.MOUSEMOTION:
            mouse_pos = event.pos
            if current_menu_options:
                # 호버에 따른 선택 이동은 추후 필요 시 구현
                pass
        if event.type == pygame.MOUSEBUTTONDOWN:
            mouse_pos = event.pos
            if event.button == 1:
                width = ctx.get_dimensions()[0]
                height = ctx.get_dimensions()[1]
                menu_y = height - 180
                menu_item_width = 120
                menu_spacing = 15
                total_width = len(current_menu_options) * menu_item_width + (len(current_menu_options) - 1) * menu_spacing
                menu_start_x = (width - total_width) // 2
                for idx, option in enumerate(current_menu_options):
                    x = menu_start_x + idx * (menu_item_width + menu_spacing)
                    option_rect = pygame.Rect(x, menu_y, menu_item_width, 54)
                    if option_rect.collidepoint(mouse_pos):
                        state.selected = idx
                        ctx.play_click_sound()
                        if _activate_menu_choice(ctx, state, option):
                            return False
                        break
        # 그레이스 윈도 내에 MOUSEBUTTONUP만 들어와도 클릭으로 인정 (경계에서 DOWN이 소거된 경우 보정)
        if (
            event.type == pygame.MOUSEBUTTONUP
            and getattr(event, 'button', None) == 1
            and state.first_click_grace_frames > 0
        ):
            mouse_pos = pygame.mouse.get_pos()
            width = ctx.get_dimensions()[0]
            height = ctx.get_dimensions()[1]
            menu_y = height - 180
            menu_item_width = 120
            menu_spacing = 15
            total_width = len(current_menu_options) * menu_item_width + (len(current_menu_options) - 1) * menu_spacing
            menu_start_x = (width - total_width) // 2
            for idx, option in enumerate(current_menu_options):
                x = menu_start_x + idx * (menu_item_width + menu_spacing)
                option_rect = pygame.Rect(x, menu_y, menu_item_width, 54)
                if option_rect.collidepoint(mouse_pos):
                    state.selected = idx
                    ctx.play_click_sound()
                    if _activate_menu_choice(ctx, state, option):
                        return False
                    break
    return True


@dataclass
class MenuContext:
    get_screen: Callable[[], pygame.Surface]
    get_dimensions: Callable[[], Tuple[int, int]]
    get_internal_dimensions: Callable[[], Tuple[int, int]]
    menu_system: object
    set_menu_system: Callable[[object], None]
    menu_system_factory: Callable[[pygame.Surface, int, int], object]
    simple_bg: object
    simple_bg_factory: Callable[[int, int], object]
    play_hover_sound: Callable[[], None]
    play_click_sound: Callable[[], None]
    change_resolution: Callable[[int], None]
    show_tutorial_dialog: Callable[[], bool]
    show_character_selection: Callable[[], Optional[str]]
    show_difficulty_selection: Callable[[], Optional[str]]
    start_game_with_difficulty: Callable[[str, str], None]
    start_tutorial_game: Callable[[], None]
    start_ai_play: Callable[[], None]
    start_test_mode: Callable[[], None]
    show_item_manager_menu: Callable[[], None]
    show_developer_stage_select: Callable[[], None]
    show_credits_screen: Callable[[], None]
    medal_score_getter: Callable[[], int]
    get_font: Callable[[int], pygame.font.Font]
    FontStyle: object
    resource_path: Callable[[str], str]
    default_alpha: int
    default_radius: int
    resolution_options: Sequence[Tuple[int, int]]
    get_current_resolution_index: Callable[[], int]
    two_seconds_frames: int
    idle_cinematic: Callable[[pygame.Surface, int, int], None]


@dataclass
class MenuState:
    selected: int = 0
    developer_unlocked: bool = False
    item_manager_unlocked: bool = False
    idle_start_time: int = 0
    animation_timer: float = 0.0
    star_field: StarField = field(default_factory=StarField)
    neon_particles: List[dict] = field(default_factory=list)
    scan_lines: List[dict] = field(default_factory=list)
    input_buffer: List[int] = field(default_factory=list)
    locked_message_timer: int = 0
    medal_icon_frames: List[pygame.Surface] = field(default_factory=list)
    medal_frame_index: int = 0
    medal_frame_timer: float = 0.0
    medal_anim_prev_time: float = 0.0
    # 첫 진입 원클릭 보장: 초반 N프레임 동안 다운/업 보정 허용
    first_click_grace_frames: int = 12
    last_mb_left_state: bool = False


def _draw_titles(ctx: MenuContext, screen: pygame.Surface, width: int, animation_timer: float) -> None:
    FontStyle = ctx.FontStyle
    font_title = FontStyle.title_large()
    font_subtitle = FontStyle.tiny()
    title_y = 100

    for offset in range(15, 0, -3):
        glow_alpha = int(30 * (1 - offset / 15))
        glow_color = (0, 255, 255, glow_alpha)
        glow_surf = font_title.render("PINGFIGHTER", True, glow_color)
        glow_rect = glow_surf.get_rect(center=(width // 2, title_y))
        for dx in [-offset, 0, offset]:
            for dy in [-offset, 0, offset]:
                if dx == 0 and dy == 0:
                    continue
                temp_rect = glow_rect.copy()
                temp_rect.x += dx
                temp_rect.y += dy
                screen.blit(glow_surf, temp_rect)

    neon_color = (0, 200, 255)
    neon_surf = font_title.render("PINGFIGHTER", True, neon_color)
    neon_rect = neon_surf.get_rect(center=(width // 2, title_y))
    for _ in range(3):
        screen.blit(neon_surf, neon_rect)

    highlight_color = (150, 255, 255)
    highlight_surf = font_title.render("PINGFIGHTER", True, highlight_color)
    highlight_rect = highlight_surf.get_rect(center=(width // 2 - 1, title_y - 1))
    screen.blit(highlight_surf, highlight_rect)

    main_color = (255, 255, 255)
    title_text = font_title.render("PINGFIGHTER", True, main_color)
    title_rect = title_text.get_rect(center=(width // 2, title_y))
    screen.blit(title_text, title_rect)

    subtitle_text = "탁구로 보스를 이겨라!"
    subtitle_color = (0, 255, 200)
    subtitle_surf = font_subtitle.render(subtitle_text, True, subtitle_color)
    subtitle_rect = subtitle_surf.get_rect(center=(width // 2, title_y + 45))
    for i in range(3):
        sub_glow = font_subtitle.render(subtitle_text, True, (0, 100, 150))
        sub_glow_rect = subtitle_rect.copy()
        sub_glow_rect.x += i - 1
        sub_glow_rect.y += i - 1
        screen.blit(sub_glow, sub_glow_rect)
    screen.blit(subtitle_surf, subtitle_rect)

    line_y = title_y + 65
    line_color = (0, 150, 200)
    for i in range(3):
        pygame.draw.line(screen, line_color, (width // 2 - 200, line_y + i), (width // 2 - 50, line_y + i), 2)
        pygame.draw.line(screen, line_color, (width // 2 + 50, line_y + i), (width // 2 + 200, line_y + i), 2)
    pygame.draw.circle(screen, (0, 255, 255), (width // 2 - 200, line_y + 1), 4)
    pygame.draw.circle(screen, (0, 255, 255), (width // 2 + 200, line_y + 1), 4)


def _handle_resolution_change(ctx: MenuContext, state: MenuState, direction: int) -> None:
    ctx.change_resolution(direction)
    screen = ctx.get_screen()
    iw, ih = ctx.get_internal_dimensions()
    menu_system = ctx.menu_system_factory(screen, iw, ih)
    ctx.set_menu_system(menu_system)
    ctx.menu_system = menu_system
    simple_bg = ctx.simple_bg_factory(iw, ih)
    ctx.simple_bg = simple_bg
    state.star_field = StarField()
    state.neon_particles.clear()
    state.scan_lines.clear()


def run_start_menu(ctx: MenuContext, state: MenuState | None = None) -> MenuState:
    if state is None:
        state = MenuState()
    # 메뉴 진입 시 항상 원클릭 그레이스 리셋
    state.first_click_grace_frames = 12
    state.last_mb_left_state = False

    clock = pygame.time.Clock()
    state.idle_start_time = pygame.time.get_ticks()

    menu_system = ctx.menu_system
    if menu_system is None:
        screen = ctx.get_screen()
        iw, ih = ctx.get_internal_dimensions()
        menu_system = ctx.menu_system_factory(screen, iw, ih)
        ctx.set_menu_system(menu_system)
    ctx.menu_system = menu_system

    if ctx.simple_bg is None:
        iw, ih = ctx.get_internal_dimensions()
        ctx.simple_bg = ctx.simple_bg_factory(iw, ih)

    while True:
        screen = ctx.get_screen()
        width, height = ctx.get_dimensions()
        dt = clock.tick(60) / 1000.0
        state.animation_timer += dt
        current_time = pygame.time.get_ticks()
        _run_idle_cinematic_if_needed(ctx, state, screen, width, height, current_time)
        _update_background_layers(ctx, state, dt, screen, width, height)

        current_menu_options = _build_menu_options(state)
        _render_menu(ctx, state, screen, width, height, current_menu_options)

        pygame.display.flip()

        if not _handle_menu_events(ctx, state, current_menu_options):
            return state


_MENU_STATE_CACHE: MenuState | None = None


def show_start_menu(ctx: MenuContext) -> MenuState:
    """캐시된 상태를 활용해 시작 메뉴를 실행."""
    global _MENU_STATE_CACHE
    _MENU_STATE_CACHE = run_start_menu(ctx, _MENU_STATE_CACHE)
    return _MENU_STATE_CACHE


def reset_menu_state() -> None:
    """메뉴 상태 캐시를 초기화."""
    global _MENU_STATE_CACHE
    _MENU_STATE_CACHE = None
