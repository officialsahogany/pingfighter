"""메인 시작 메뉴 화면 로직."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, List, Optional, Sequence, Tuple

import math
import random
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
# baroque frame은 pillar_background.py에서 stage 0으로 처리됨
from pillar_background import get_pillar_renderer

BASE_MENU_OPTIONS = ["경기장 입장", "멀티플레이", "개발테스트", "메달샵", "크레딧"]
MENU_ICONS = {
    "경기장 입장": "▶",
    "멀티플레이": "★",
    "로컬플레이": "▷",
    "AI 플레이": "◇",
    "테스트메뉴": "◆",
    "개발테스트": "▣",
    "메달샵": "◆",
    "크레딧": "●",
    "개발자": "☆",
}
VERSION_TEXT = "1.4v beta"
DEV_CODE = [1]
ITEM_CODE = [2]

# 관리자 모드 시스템
ADMIN_MODE_ENABLED = False  # 관리자 모드 활성화 여부
ADMIN_KEY_SEQUENCE = []  # 7키 입력 시퀀스 추적
ADMIN_KEY_LAST_TIME = 0  # 마지막 7키 입력 시간
ADMIN_KEY_TIMEOUT = 1.0  # 연타 제한 시간 (1초 이내에 3번)
ADMIN_MODE_MESSAGE_TIMER = 0  # 활성화 메시지 표시 타이머
ADMIN_MODE_MESSAGE_DURATION = 2.0  # 메시지 표시 시간 (2초)

def is_admin_mode_enabled() -> bool:
    """관리자 모드 활성화 여부 반환"""
    return ADMIN_MODE_ENABLED

def activate_admin_mode():
    """관리자 모드 활성화"""
    global ADMIN_MODE_ENABLED, ADMIN_MODE_MESSAGE_TIMER
    ADMIN_MODE_ENABLED = True
    ADMIN_MODE_MESSAGE_TIMER = ADMIN_MODE_MESSAGE_DURATION
    print("[ADMIN] 관리자 모드가 활성화되었습니다!")

def check_admin_key_sequence(current_time: float) -> bool:
    """7키 연타 시퀀스 확인 및 처리"""
    global ADMIN_KEY_SEQUENCE, ADMIN_KEY_LAST_TIME, ADMIN_MODE_ENABLED

    if ADMIN_MODE_ENABLED:
        return False  # 이미 활성화됨

    # 시간 초과 시 시퀀스 리셋
    if current_time - ADMIN_KEY_LAST_TIME > ADMIN_KEY_TIMEOUT:
        ADMIN_KEY_SEQUENCE = []

    ADMIN_KEY_SEQUENCE.append(7)
    ADMIN_KEY_LAST_TIME = current_time

    # 777 입력 확인
    if len(ADMIN_KEY_SEQUENCE) >= 3 and ADMIN_KEY_SEQUENCE[-3:] == [7, 7, 7]:
        activate_admin_mode()
        ADMIN_KEY_SEQUENCE = []
        return True

    return False

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
    # 게임 화면 안쪽 배경 (기존 그대로)
    simple_bg = ctx.simple_bg
    if simple_bg is not None:
        simple_bg.update(dt)
        # 행성과 기본 배경만 그리기 (애니 효과는 나중에)
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

    # 애니 감성 효과를 맨 마지막에 그리기 (하트, 별, 키라키라 등)
    if simple_bg is not None and hasattr(simple_bg, '_draw_anime_effects'):
        simple_bg._draw_anime_effects(screen)

    # 바로크 스타일 액자는 pillar_background.py의 stage 0에서 처리됨
    # (_fullscreen_flip에서 pillar_renderer.draw()를 통해 그려짐)


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

    # 바로크 액자는 _update_background_layers에서 필러 영역에 렌더링됨

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

    # 가로 배열 메뉴 설정 (화면에 맞게 작은 사이즈)
    menu_item_width = 100
    menu_item_height = 70
    menu_spacing = 8
    total_width = len(current_menu_options) * menu_item_width + (len(current_menu_options) - 1) * menu_spacing
    menu_start_x = (width - total_width) // 2
    menu_y = height // 2 + 80  # 타이틀 아래 배치
    font_menu = ctx.FontStyle.small()
    font_icon = ctx.get_font(26)

    for idx, option in enumerate(current_menu_options):
        x = menu_start_x + idx * (menu_item_width + menu_spacing)
        if idx == state.selected:
            # 선택된 메뉴 항목 - 글로우 효과
            glow_surf = pygame.Surface((menu_item_width + 16, menu_item_height + 16), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (0, 255, 255, 30), (0, 0, menu_item_width + 16, menu_item_height + 16), border_radius=10)
            screen.blit(glow_surf, (x - 8, menu_y - 8))
            container = pygame.Surface((menu_item_width, menu_item_height), pygame.SRCALPHA)
            pygame.draw.rect(container, (0, 50, 80, 180), (0, 0, menu_item_width, menu_item_height), border_radius=8)
            pygame.draw.rect(container, (0, 255, 255, 255), (0, 0, menu_item_width, menu_item_height), 2, border_radius=8)
            screen.blit(container, (x, menu_y))
            # 하단에 선택 표시 점들
            for j in range(3):
                dot_x = x + menu_item_width // 2 + (j - 1) * 10
                dot_y = menu_y + menu_item_height + 12
                dot_size = 2 + abs(math.sin(state.animation_timer * 3 + j)) * 1.5
                pygame.draw.circle(screen, (0, 255, 255), (int(dot_x), int(dot_y)), int(dot_size))
        else:
            container = pygame.Surface((menu_item_width, menu_item_height), pygame.SRCALPHA)
            pygame.draw.rect(container, (20, 30, 50, 120), (0, 0, menu_item_width, menu_item_height), border_radius=8)
            pygame.draw.rect(container, (100, 150, 200, 100), (0, 0, menu_item_width, menu_item_height), 1, border_radius=8)
            screen.blit(container, (x, menu_y))

        # 아이콘과 텍스트를 세로로 배치 (가로 메뉴이므로)
        icon = MENU_ICONS.get(option, "")
        display_text = option
        if option == "경기장 입장":
            display_text = "입장"
        elif option == "AI 플레이":
            display_text = "AI"
        elif option == "테스트메뉴":
            display_text = "테스트"
        elif option == "개발테스트":
            display_text = "개발"
        elif option == "멀티플레이":
            display_text = "멀티"
        elif option == "메달샵":
            display_text = "메달샵"
        elif option == "크레딧":
            display_text = "크레딧"
        elif option == "개발자":
            display_text = "개발자"

        # 아이콘과 텍스트 세로 배치
        center_x = x + menu_item_width // 2
        if icon:
            icon_surface = font_icon.render(icon, True, (0, 255, 255))
            icon_rect = icon_surface.get_rect(center=(center_x, menu_y + menu_item_height // 2 - 12))
            screen.blit(icon_surface, icon_rect)
            text_surface = font_menu.render(display_text, True, (255, 255, 255))
            text_rect = text_surface.get_rect(center=(center_x, menu_y + menu_item_height // 2 + 16))
            screen.blit(text_surface, text_rect)
        else:
            text_surface = font_menu.render(display_text, True, (255, 255, 255))
            text_rect = text_surface.get_rect(center=(center_x, menu_y + menu_item_height // 2))
            screen.blit(text_surface, text_rect)

        # 선택된 개발테스트 메뉴일 때 설명 표시
        if idx == state.selected and option == "개발테스트":
            font_desc = ctx.FontStyle.tiny()
            desc = font_desc.render("개발용 AI/테스트 모드", True, (200, 200, 255))
            desc_rect = desc.get_rect(center=(width // 2, menu_y + menu_item_height + 35))
            screen.blit(desc, desc_rect)

    if state.locked_message_timer > 0:
        message_width = 400
        message_height = 40
        message_x = width // 2 - message_width // 2
        message_y_pos = menu_y + menu_item_height + 50
        for j in range(10, 0, -2):
            alpha = int(60 * (1 - j / 10))
            glow_surface = pygame.Surface((message_width + j * 2, message_height + j * 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surface, (255, 100, 100, alpha), (0, 0, message_width + j * 2, message_height + j * 2), border_radius=ctx.default_radius)
            screen.blit(glow_surface, (message_x - j, message_y_pos - j))
        message_bg = pygame.Surface((message_width, message_height), pygame.SRCALPHA)
        pygame.draw.rect(message_bg, (255, 100, 100, 40), (0, 0, message_width, message_height), border_radius=ctx.default_radius)
        pygame.draw.rect(message_bg, (255, 100, 100, 120), (0, 0, message_width, message_height), 2, border_radius=ctx.default_radius)
        screen.blit(message_bg, (message_x, message_y_pos))
        font_message = ctx.FontStyle.body()
        shadow = font_message.render("모든 보스를 클리어시 해금됩니다", True, (100, 50, 50))
        shadow_rect = shadow.get_rect(center=(width // 2 + 1, message_y_pos + message_height // 2 + 1))
        screen.blit(shadow, shadow_rect)
        text = font_message.render("모든 보스를 클리어시 해금됩니다", True, (255, 150, 150))
        text_rect = text.get_rect(center=(width // 2, message_y_pos + message_height // 2))
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

    # 관리자 모드 활성화 메시지 표시
    global ADMIN_MODE_MESSAGE_TIMER
    if ADMIN_MODE_MESSAGE_TIMER > 0:
        ADMIN_MODE_MESSAGE_TIMER -= 1 / 60.0  # 60fps 기준

        # 메시지 박스 설정
        admin_msg_width = 350
        admin_msg_height = 50
        admin_msg_x = width // 2 - admin_msg_width // 2
        admin_msg_y = height // 3

        # 페이드 효과를 위한 알파값 계산 (0-255 범위 보장)
        fade_alpha = max(0, min(255, int(ADMIN_MODE_MESSAGE_TIMER * 127.5)))
        bg_alpha = max(0, min(255, int(fade_alpha * 0.8)))

        # 외곽 글로우 효과 (황금색)
        for j in range(15, 0, -3):
            glow_alpha = max(0, min(255, int(fade_alpha * 0.3 * (1 - j / 15))))
            glow_surface = pygame.Surface((admin_msg_width + j * 2, admin_msg_height + j * 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surface, (255, 200, 50, glow_alpha), (0, 0, admin_msg_width + j * 2, admin_msg_height + j * 2), border_radius=10)
            screen.blit(glow_surface, (admin_msg_x - j, admin_msg_y - j))

        # 배경 박스
        admin_bg = pygame.Surface((admin_msg_width, admin_msg_height), pygame.SRCALPHA)
        pygame.draw.rect(admin_bg, (50, 40, 10, bg_alpha), (0, 0, admin_msg_width, admin_msg_height), border_radius=8)
        pygame.draw.rect(admin_bg, (255, 200, 50, fade_alpha), (0, 0, admin_msg_width, admin_msg_height), 3, border_radius=8)
        screen.blit(admin_bg, (admin_msg_x, admin_msg_y))

        # 텍스트 렌더링
        font_admin = ctx.FontStyle.body()
        admin_text = font_admin.render("🔓 관리자 모드 시작", True, (255, 220, 100))
        admin_text_rect = admin_text.get_rect(center=(width // 2, admin_msg_y + admin_msg_height // 2))

        # 텍스트 알파 적용
        admin_text.set_alpha(fade_alpha)
        screen.blit(admin_text, admin_text_rect)


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


def _show_multiplayer_menu(ctx: MenuContext, state: MenuState) -> bool:
    """멀티플레이 서브메뉴 - 로컬 플레이 등 선택."""
    options = ["로컬플레이", "뒤로"]
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
                    if choice == "로컬플레이":
                        # 로컬 멀티플레이 시작
                        if hasattr(ctx, 'start_local_multiplayer') and ctx.start_local_multiplayer:
                            ctx.start_local_multiplayer()
                            return True
                        return False
                    return False  # 뒤로
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
                        if opt == "로컬플레이":
                            if hasattr(ctx, 'start_local_multiplayer') and ctx.start_local_multiplayer:
                                ctx.start_local_multiplayer()
                                return True
                            return False
                        return False

        font_title = ctx.FontStyle.title()
        font_item = ctx.FontStyle.body()
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 120))
        screen.blit(overlay, (0, 0))

        title = font_title.render("멀티플레이", True, (200, 230, 255))
        screen.blit(title, title.get_rect(center=(width // 2, height // 2 - 130)))

        # 설명 텍스트
        desc_font = ctx.FontStyle.tiny()
        desc_text = "같은 PC에서 2명이 대결합니다"
        desc_surf = desc_font.render(desc_text, True, (180, 200, 220))
        screen.blit(desc_surf, desc_surf.get_rect(center=(width // 2, height // 2 - 90)))

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

            # 아이콘 표시
            icon = MENU_ICONS.get(opt, "")
            if icon:
                icon_font = ctx.get_font(28)
                icon_surface = icon_font.render(icon, True, (0, 255, 255))
                icon_rect = icon_surface.get_rect(center=(rect.centerx, rect.centery - 15))
                screen.blit(icon_surface, icon_rect)

            label_surface = font_item.render(opt, True, (255, 255, 255))
            screen.blit(label_surface, label_surface.get_rect(center=(rect.centerx, rect.centery + 15)))

            if is_sel and opt == "로컬플레이":
                hint = "P1: 방향키/Shift  |  P2: WASD/Space"
                hint_surf = ctx.FontStyle.tiny().render(hint, True, (210, 220, 255))
                screen.blit(hint_surf, hint_surf.get_rect(center=(width // 2, rect.bottom + 30)))

        pygame.display.flip()


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


def _play_rainbow_transition(screen: pygame.Surface, duration_ms: int = 1000):
    """무지개 파티클이 쏟아지며 화면이 깜빡이는 트랜지션 효과"""
    clock = pygame.time.Clock()
    width, height = screen.get_size()
    start_time = pygame.time.get_ticks()

    # 무지개 색상 팔레트
    rainbow_colors = [
        (255, 100, 150),   # 핑크
        (255, 150, 100),   # 오렌지
        (255, 255, 100),   # 옐로우
        (150, 255, 150),   # 그린
        (100, 200, 255),   # 시안
        (150, 150, 255),   # 블루
        (200, 100, 255),   # 퍼플
        (255, 100, 200),   # 마젠타
    ]

    # 파티클 생성 (위에서 쏟아지는 느낌)
    particles = []
    for _ in range(150):
        particles.append({
            'x': random.randint(0, width),
            'y': random.randint(-height, 0),
            'vx': random.uniform(-2, 2),
            'vy': random.uniform(8, 20),
            'size': random.randint(4, 12),
            'color': random.choice(rainbow_colors),
            'type': random.choice(['circle', 'star', 'heart']),
            'rotation': random.uniform(0, math.pi * 2),
            'rot_speed': random.uniform(-0.2, 0.2),
            'alpha': 255
        })

    # 스파크/별똥별 효과
    sparks = []
    for _ in range(30):
        sparks.append({
            'x': random.randint(0, width),
            'y': random.randint(0, height),
            'size': random.randint(2, 6),
            'color': random.choice(rainbow_colors),
            'life': 1.0,
            'phase': random.uniform(0, math.pi * 2)
        })

    # 기존 화면 캡처 (배경으로 사용)
    bg_surface = screen.copy()

    while True:
        elapsed = pygame.time.get_ticks() - start_time
        progress = min(1.0, elapsed / duration_ms)

        if elapsed >= duration_ms:
            break

        # 이벤트 처리 (ESC로 스킵 가능)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                return

        # 배경 그리기 (점점 밝아짐)
        screen.blit(bg_surface, (0, 0))

        # 화면 깜빡임 효과 (화이트 플래시)
        flash_alpha = 0
        if progress < 0.15:
            # 초반 강한 플래시
            flash_alpha = int(200 * (1 - progress / 0.15))
        elif progress > 0.85:
            # 후반 페이드 아웃 플래시
            flash_alpha = int(255 * ((progress - 0.85) / 0.15))

        # 중간중간 깜빡임
        flicker = abs(math.sin(progress * math.pi * 8))
        if flicker > 0.9:
            flash_alpha = max(flash_alpha, int(100 * (flicker - 0.9) * 10))

        # 파티클 업데이트 및 그리기
        for p in particles:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['rotation'] += p['rot_speed']
            p['vy'] += 0.3  # 중력

            # 화면 밖으로 나가면 위에서 다시 시작
            if p['y'] > height + 20:
                p['y'] = random.randint(-50, -10)
                p['x'] = random.randint(0, width)
                p['vy'] = random.uniform(8, 15)

            # 파티클 그리기
            if p['type'] == 'circle':
                pygame.draw.circle(screen, p['color'], (int(p['x']), int(p['y'])), p['size'])
                # 글로우
                glow_surf = pygame.Surface((p['size'] * 4, p['size'] * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*p['color'], 80),
                                 (p['size'] * 2, p['size'] * 2), p['size'] * 2)
                screen.blit(glow_surf, (int(p['x'] - p['size'] * 2), int(p['y'] - p['size'] * 2)))
            elif p['type'] == 'star':
                # 별 모양
                _draw_transition_star(screen, int(p['x']), int(p['y']), p['size'], p['color'], p['rotation'])
            else:  # heart
                # 하트 모양
                _draw_transition_heart(screen, int(p['x']), int(p['y']), p['size'], p['color'])

        # 스파크 효과
        for spark in sparks:
            spark['phase'] += 0.3
            spark['life'] -= 0.02
            if spark['life'] <= 0:
                spark['life'] = 1.0
                spark['x'] = random.randint(0, width)
                spark['y'] = random.randint(0, height)
                spark['color'] = random.choice(rainbow_colors)

            pulse = abs(math.sin(spark['phase']))
            size = int(spark['size'] * pulse)
            alpha = int(255 * spark['life'] * pulse)
            if size > 0 and alpha > 0:
                # 십자가 모양 반짝임
                pygame.draw.line(screen, (*spark['color'], alpha),
                               (spark['x'] - size * 2, spark['y']),
                               (spark['x'] + size * 2, spark['y']), 2)
                pygame.draw.line(screen, (*spark['color'], alpha),
                               (spark['x'], spark['y'] - size * 2),
                               (spark['x'], spark['y'] + size * 2), 2)

        # 무지개빛 테두리 효과
        border_alpha = int(150 * (0.5 + abs(math.sin(progress * math.pi * 4)) * 0.5))
        for i in range(3):
            hue = (progress * 360 + i * 40) % 360
            border_color = _hsv_to_rgb_transition(hue, 0.8, 1.0)
            border_rect = pygame.Rect(i * 3, i * 3, width - i * 6, height - i * 6)
            border_surf = pygame.Surface((width, height), pygame.SRCALPHA)
            pygame.draw.rect(border_surf, (*border_color, border_alpha - i * 30), border_rect, 4)
            screen.blit(border_surf, (0, 0))

        # 화이트 플래시 오버레이
        if flash_alpha > 0:
            flash_surf = pygame.Surface((width, height), pygame.SRCALPHA)
            flash_surf.fill((255, 255, 255, min(255, flash_alpha)))
            screen.blit(flash_surf, (0, 0))

        pygame.display.flip()
        clock.tick(60)


def _draw_transition_star(surface: pygame.Surface, x: int, y: int, size: int, color: Tuple, rotation: float):
    """트랜지션용 별 그리기"""
    points = []
    for i in range(10):
        r = size if i % 2 == 0 else size * 0.4
        angle = i * math.pi / 5 - math.pi / 2 + rotation
        px = x + math.cos(angle) * r
        py = y + math.sin(angle) * r
        points.append((px, py))
    if len(points) > 2:
        pygame.draw.polygon(surface, color, points)


def _draw_transition_heart(surface: pygame.Surface, x: int, y: int, size: int, color: Tuple):
    """트랜지션용 하트 그리기"""
    points = []
    for i in range(20):
        t = i / 20 * 2 * math.pi
        hx = 16 * (math.sin(t) ** 3)
        hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        points.append((x + hx * size / 18, y + hy * size / 18))
    if len(points) > 2:
        pygame.draw.polygon(surface, color, points)


def _hsv_to_rgb_transition(h: float, s: float, v: float) -> Tuple[int, int, int]:
    """HSV를 RGB로 변환 (트랜지션용)"""
    h = h % 360
    c = v * s
    x = c * (1 - abs((h / 60) % 2 - 1))
    m = v - c

    if h < 60:
        r, g, b = c, x, 0
    elif h < 120:
        r, g, b = x, c, 0
    elif h < 180:
        r, g, b = 0, c, x
    elif h < 240:
        r, g, b = 0, x, c
    elif h < 300:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x

    return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))


def _activate_menu_choice(ctx: MenuContext, state: MenuState, choice: str) -> bool:
    if choice == "경기장 입장":
        # 무지개 파티클 트랜지션 효과 재생
        _play_rainbow_transition(ctx.screen, 1000)
        # 캐릭터 선택으로 진행
        character = ctx.show_character_selection()
        if character is not None:
            difficulty = ctx.show_difficulty_selection()
            if difficulty is not None:
                ctx.start_game_with_difficulty(character, difficulty)
        return True
    if choice == "멀티플레이":
        return _show_multiplayer_menu(ctx, state)
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


def _get_horizontal_menu_rects(width: int, height: int, num_options: int) -> tuple:
    """가로 메뉴 레이아웃 계산을 위한 헬퍼 함수."""
    menu_item_width = 100
    menu_item_height = 70
    menu_spacing = 8
    total_width = num_options * menu_item_width + (num_options - 1) * menu_spacing
    menu_start_x = (width - total_width) // 2
    menu_y = height // 2 + 80
    return menu_start_x, menu_y, menu_item_width, menu_item_height, menu_spacing


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
                # 가로 메뉴 레이아웃
                menu_start_x, menu_y, menu_item_width, menu_item_height, menu_spacing = _get_horizontal_menu_rects(width, height, len(current_menu_options))
                for idx, option in enumerate(current_menu_options):
                    x = menu_start_x + idx * (menu_item_width + menu_spacing)
                    option_rect = pygame.Rect(x, menu_y, menu_item_width, menu_item_height)
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
            # 관리자 모드 활성화 (7키 연타)
            if event.key == pygame.K_7:
                import time
                if check_admin_key_sequence(time.time()):
                    ctx.play_click_sound()  # 활성화 시 효과음
            # 관리자 전용 키들 (관리자 모드에서만 작동)
            if event.key == pygame.K_2 and is_admin_mode_enabled():
                ctx.play_click_sound()
                ctx.show_item_manager_menu()
                return False
            # 개발자용: 0번 키로 광장 직접 입장 (관리자 모드에서만)
            if event.key == pygame.K_0 and is_admin_mode_enabled():
                ctx.play_click_sound()
                if hasattr(ctx, 'enter_downtown_dev') and ctx.enter_downtown_dev:
                    ctx.enter_downtown_dev()
                    return False
            if pygame.K_0 <= event.key <= pygame.K_9:
                num = event.key - pygame.K_0
                state.input_buffer.append(num)
                state.input_buffer = state.input_buffer[-4:]
                if state.input_buffer[-len(DEV_CODE):] == DEV_CODE:
                    state.developer_unlocked = True
                if state.input_buffer[-len(ITEM_CODE):] == ITEM_CODE:
                    state.item_manager_unlocked = True
            # 가로 메뉴: 좌우 방향키로 이동
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
                # 마우스 호버에 따른 선택 이동
                width = ctx.get_dimensions()[0]
                height = ctx.get_dimensions()[1]
                menu_start_x, menu_y, menu_item_width, menu_item_height, menu_spacing = _get_horizontal_menu_rects(width, height, len(current_menu_options))
                for idx, option in enumerate(current_menu_options):
                    x = menu_start_x + idx * (menu_item_width + menu_spacing)
                    option_rect = pygame.Rect(x, menu_y, menu_item_width, menu_item_height)
                    if option_rect.collidepoint(mouse_pos):
                        if state.selected != idx:
                            state.selected = idx
                            ctx.play_hover_sound()
                        break
        if event.type == pygame.MOUSEBUTTONDOWN:
            mouse_pos = event.pos
            if event.button == 1:
                width = ctx.get_dimensions()[0]
                height = ctx.get_dimensions()[1]
                # 가로 메뉴 레이아웃
                menu_start_x, menu_y, menu_item_width, menu_item_height, menu_spacing = _get_horizontal_menu_rects(width, height, len(current_menu_options))
                for idx, option in enumerate(current_menu_options):
                    x = menu_start_x + idx * (menu_item_width + menu_spacing)
                    option_rect = pygame.Rect(x, menu_y, menu_item_width, menu_item_height)
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
            # 가로 메뉴 레이아웃
            menu_start_x, menu_y, menu_item_width, menu_item_height, menu_spacing = _get_horizontal_menu_rects(width, height, len(current_menu_options))
            for idx, option in enumerate(current_menu_options):
                x = menu_start_x + idx * (menu_item_width + menu_spacing)
                option_rect = pygame.Rect(x, menu_y, menu_item_width, menu_item_height)
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
    # 전체화면 서피스 (필러 렌더링용, 없으면 get_screen 사용)
    get_fullscreen: Optional[Callable[[], pygame.Surface]] = None


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
    # 바로크 스타일 액자는 pillar_background.py에서 처리됨 (stage 0)


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
    # 바로크 액자는 pillar_background.py에서 처리됨


def run_start_menu(ctx: MenuContext, state: MenuState | None = None) -> MenuState:
    if state is None:
        state = MenuState()
    # 메뉴 진입 시 항상 원클릭 그레이스 리셋
    state.first_click_grace_frames = 12
    state.last_mb_left_state = False

    # 바로크 액자 애니메이션 리셋은 pillar_background.py의 set_stage(0)에서 처리됨

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

        # 필러 배경 애니메이션 업데이트 (바로크 액자 애니메이션용)
        pillar_renderer = get_pillar_renderer()
        if pillar_renderer is not None:
            pillar_renderer.update(dt)

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
