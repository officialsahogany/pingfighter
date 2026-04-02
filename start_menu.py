"""메인 시작 메뉴 화면 로직."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, List, Optional, Sequence, Tuple

import math
import random
import sys
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
from localization.manager import get_localization_manager
from config.language_options import LANGUAGE_OPTIONS, LANGUAGE_CODES

BASE_MENU_OPTIONS = ["경기장 입장", "멀티플레이", "개발테스트", "메달샵", "설정", "크레딧"]
MENU_ICONS = {
    "경기장 입장": "▶",
    "계속하기": "▷",
    "멀티플레이": "★",
    "온라인 대전": "◈",
    "로컬플레이": "▷",
    "AI 플레이": "◇",
    "개발테스트": "▣",
    "메달샵": "◆",
    "설정": "⚙",
    "크레딧": "●",
    "개발자": "☆",
}
VERSION_TEXT = "2.1v beta"
DEV_CODE = [1]
ITEM_CODE = [2]

# 관리자 모드 시스템
ADMIN_MODE_ENABLED = False  # 관리자 모드 활성화 여부
ADMIN_KEY_SEQUENCE = []  # 7키 입력 시퀀스 추적
ADMIN_KEY_LAST_TIME = 0  # 마지막 7키 입력 시간
ADMIN_KEY_TIMEOUT = 1.0  # 연타 제한 시간 (1초 이내에 2번)
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

    # 77 입력 확인 (2번)
    if len(ADMIN_KEY_SEQUENCE) >= 2 and ADMIN_KEY_SEQUENCE[-2:] == [7, 7]:
        activate_admin_mode()
        ADMIN_KEY_SEQUENCE = []
        return True

    return False

# ── 메인 메뉴 호버 보더 시스템 ──
_menu_hover_glow_timer = 0.0
_menu_hover_particles: list = []
_menu_hover_prev_id = ""

def _menu_update_hover(dt: float = 1/60):
    global _menu_hover_glow_timer, _menu_hover_particles
    _menu_hover_glow_timer += dt
    for p in _menu_hover_particles:
        p["life"] -= dt; p["x"] += p["vx"] * dt; p["y"] += p["vy"] * dt
        p["alpha"] = max(0, p["alpha"] - 200 * dt)
    _menu_hover_particles = [p for p in _menu_hover_particles if p["life"] > 0]

def _menu_spawn_particles(rx, ry, rw, rh):
    import random as _r
    for t in range(8):
        f = t / 7
        _menu_hover_particles.append({"x": rx+rw*f, "y": ry, "vx": _r.uniform(-10,10), "vy": _r.uniform(-25,-10), "alpha": 120.0, "life": _r.uniform(0.3,0.55), "color": (0,255,255)})
        _menu_hover_particles.append({"x": rx+rw*f, "y": ry+rh, "vx": _r.uniform(-10,10), "vy": _r.uniform(10,25), "alpha": 120.0, "life": _r.uniform(0.3,0.55), "color": (0,255,255)})
    for t in range(6):
        f = t / 5
        _menu_hover_particles.append({"x": rx, "y": ry+rh*f, "vx": _r.uniform(-25,-10), "vy": _r.uniform(-10,10), "alpha": 120.0, "life": _r.uniform(0.3,0.55), "color": (0,255,255)})
        _menu_hover_particles.append({"x": rx+rw, "y": ry+rh*f, "vx": _r.uniform(10,25), "vy": _r.uniform(-10,10), "alpha": 120.0, "life": _r.uniform(0.3,0.55), "color": (0,255,255)})

def _menu_check_hover(hover_id: str, rect: pygame.Rect, mpos, play_sound_fn=None) -> bool:
    global _menu_hover_prev_id
    if rect.collidepoint(mpos):
        if _menu_hover_prev_id != hover_id:
            _menu_hover_prev_id = hover_id
            if play_sound_fn:
                play_sound_fn()
            _menu_spawn_particles(rect.x, rect.y, rect.w, rect.h)
        return True
    return False

def _menu_draw_hover_border(scr, rx, ry, rw, rh, color=(0, 255, 255)):
    pulse = 0.6 + 0.4 * abs(math.sin(_menu_hover_glow_timer * 4.0))
    al = int(120 * pulse)
    gs = pygame.Surface((rw+12, rh+12), pygame.SRCALPHA)
    pygame.draw.rect(gs, (*color, al//3), (0,0,rw+12,rh+12), border_radius=10)
    scr.blit(gs, (rx-6, ry-6))
    bs = pygame.Surface((rw+4, rh+4), pygame.SRCALPHA)
    pygame.draw.rect(bs, (*color, al), (0,0,rw+4,rh+4), 2, border_radius=10)
    scr.blit(bs, (rx-2, ry-2))
    ln = int(14 + 4 * pulse); la = int(200 * pulse)
    lsf = pygame.Surface((rw+20, rh+20), pygame.SRCALPHA)
    ox, oy = 10, 10
    for c, he, ve in [((ox,oy),(ox+ln,oy),(ox,oy+ln)),((ox+rw,oy),(ox+rw-ln,oy),(ox+rw,oy+ln)),((ox,oy+rh),(ox+ln,oy+rh),(ox,oy+rh-ln)),((ox+rw,oy+rh),(ox+rw-ln,oy+rh),(ox+rw,oy+rh-ln))]:
        pygame.draw.line(lsf, (*color, la), c, he, 2)
        pygame.draw.line(lsf, (*color, la), c, ve, 2)
    scr.blit(lsf, (rx-10, ry-10))
    for p in _menu_hover_particles:
        if p["alpha"] > 3:
            ps = pygame.Surface((3,3), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*p["color"], int(p["alpha"])), (1,1), 1)
            scr.blit(ps, (int(p["x"])-1, int(p["y"])-1))

def _menu_reset_hover():
    global _menu_hover_prev_id, _menu_hover_particles
    _menu_hover_prev_id = ""
    _menu_hover_particles = []

# ── 모드 선택 화면 강화 비주얼 시스템 ──
_mode_card_tilt_y = [0.0, 0.0]       # 각 카드 Y축 기울기 (좌우)
_mode_card_tilt_x = [0.0, 0.0]       # 각 카드 X축 기울기 (상하)
_mode_shine_offset = [0.0, 0.0]      # 광택 스윕 오프셋
_mode_entry_timer = 0.0              # 진입 애니메이션 타이머
_mode_entry_done = False             # 진입 애니메이션 완료 여부
_mode_bg_glitch_timer = 0.0          # 배경 글리치 타이머
_mode_mouse_trail: list = []         # 마우스 궤적 파티클
_mode_bg_energy_particles: list = [] # 배경 에너지 파티클
_mode_card_flash = [0.0, 0.0]        # 카드 선택 전환 시 플래시

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
    # 게임 화면 안쪽 배경
    simple_bg = ctx.simple_bg
    if simple_bg is not None:
        # 마우스 좌표를 넘겨 패럴랙스 & 트레일 활성화
        mouse_pos = pygame.mouse.get_pos()
        simple_bg.update(dt, mouse_pos=mouse_pos)
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

    # 애니 감성 효과 (하트, 별, 키라키라 등)
    if simple_bg is not None and hasattr(simple_bg, '_draw_anime_effects'):
        simple_bg._draw_anime_effects(screen)

    # [NEW] 비네팅 + UI 다크패널 + 마우스 트레일 (모든 이펙트 위에)
    if simple_bg is not None and hasattr(simple_bg, 'draw_overlays'):
        simple_bg.draw_overlays(screen)

    # 바로크 스타일 액자는 pillar_background.py의 stage 0에서 처리됨
    # (_fullscreen_flip에서 pillar_renderer.draw()를 통해 그려짐)


def _build_menu_options(state: MenuState) -> List[str]:
    menu_options = list(BASE_MENU_OPTIONS)

    # 저장 데이터가 있으면 "계속하기" 버튼을 맨 앞에 추가
    try:
        from pingfighter import has_save_data
        if has_save_data() and "계속하기" not in menu_options:
            menu_options.insert(0, "계속하기")
    except ImportError:
        pass

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

    # 호버 업데이트
    _menu_update_hover()

    # 가로 배열 메뉴 설정 (화면에 맞게 동적 사이즈)
    menu_start_x, menu_y, menu_item_width, menu_item_height, menu_spacing = \
        _get_horizontal_menu_rects(width, height, len(current_menu_options))
    font_menu = ctx.FontStyle.small()
    font_icon = ctx.get_font(26)

    # 마우스 호버 체크
    _mpos = pygame.mouse.get_pos()
    for idx, option in enumerate(current_menu_options):
        _mr = pygame.Rect(menu_start_x + idx * (menu_item_width + menu_spacing), menu_y, menu_item_width, menu_item_height)
        _menu_check_hover(f"mm_{idx}", _mr, _mpos)

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
            # 호버 보더 (코너 라인 + 파티클)
            _menu_draw_hover_border(screen, x, menu_y, menu_item_width, menu_item_height)
        else:
            container = pygame.Surface((menu_item_width, menu_item_height), pygame.SRCALPHA)
            pygame.draw.rect(container, (20, 30, 50, 120), (0, 0, menu_item_width, menu_item_height), border_radius=8)
            pygame.draw.rect(container, (100, 150, 200, 100), (0, 0, menu_item_width, menu_item_height), 1, border_radius=8)
            screen.blit(container, (x, menu_y))

        # 아이콘과 텍스트를 세로로 배치 (가로 메뉴이므로)
        icon = MENU_ICONS.get(option, "")
        display_text = option
        _loc = get_localization_manager()
        if option == "경기장 입장":
            display_text = _loc.get_text("menu.enter_short", "입장")
        elif option == "계속하기":
            display_text = _loc.get_text("menu.continue_short", "계속")
        elif option == "AI 플레이":
            display_text = "AI"
        elif option == "테스트메뉴":
            display_text = _loc.get_text("menu.test_short", "테스트")
        elif option == "개발테스트":
            display_text = _loc.get_text("menu.dev_short", "개발")
        elif option == "멀티플레이":
            display_text = _loc.get_text("menu.multi_short", "멀티")
        elif option == "메달샵":
            display_text = _loc.get_text("menu.medal_shop", "메달샵")
        elif option == "설정":
            display_text = _loc.get_text("menu.settings", "설정")
        elif option == "크레딧":
            display_text = _loc.get_text("menu.credits", "크레딧")
        elif option == "개발자":
            display_text = _loc.get_text("menu.developer", "개발자")

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

        # 선택된 메뉴일 때 설명 표시
        if idx == state.selected and option == "개발테스트":
            font_desc = ctx.FontStyle.tiny()
            desc = font_desc.render(get_localization_manager().get_text("menu.dev_ai_test_desc", "개발용 AI/테스트 모드"), True, (200, 200, 255))
            desc_rect = desc.get_rect(center=(width // 2, menu_y + menu_item_height + 35))
            screen.blit(desc, desc_rect)

        # 계속하기 선택 시 저장된 스테이지 정보 표시
        if idx == state.selected and option == "계속하기":
            font_desc = ctx.FontStyle.tiny()
            try:
                from pingfighter import load_game_progress
                save_data = load_game_progress()
                if save_data:
                    stage_num = save_data.get("stage_number", "?")
                    desc_text = get_localization_manager().get_text("menu.continue_downtown_desc", "스테이지 {stage_num} 광장에서 이어하기").replace("{stage_num}", str(stage_num))
                else:
                    desc_text = get_localization_manager().get_text("menu.load_save_desc", "저장된 게임 불러오기")
            except Exception:
                desc_text = get_localization_manager().get_text("menu.load_save_desc", "저장된 게임 불러오기")
            desc = font_desc.render(desc_text, True, (100, 255, 150))
            desc_rect = desc.get_rect(center=(width // 2, menu_y + menu_item_height + 35))
            screen.blit(desc, desc_rect)

        # 설정 선택 시 설명 표시
        if idx == state.selected and option == "설정":
            font_desc = ctx.FontStyle.tiny()
            desc = font_desc.render(get_localization_manager().get_text("menu.settings_desc", "BGM/효과음 볼륨, 조작 방식 설정"), True, (200, 220, 255))
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
        _locked_msg = get_localization_manager().get_text("menu.unlock_all_bosses", "모든 보스를 클리어시 해금됩니다")
        shadow = font_message.render(_locked_msg, True, (100, 50, 50))
        shadow_rect = shadow.get_rect(center=(width // 2 + 1, message_y_pos + message_height // 2 + 1))
        screen.blit(shadow, shadow_rect)
        text = font_message.render(_locked_msg, True, (255, 150, 150))
        text_rect = text.get_rect(center=(width // 2, message_y_pos + message_height // 2))
        screen.blit(text, text_rect)
        state.locked_message_timer -= 1

    font_tiny = ctx.FontStyle.tiny()
    version_surface = font_tiny.render(VERSION_TEXT, True, (160, 200, 255))
    version_rect = version_surface.get_rect(bottomleft=(10, height - 10))
    screen.blit(version_surface, version_rect)

    # F9/F10 단축키 안내 텍스트 (우측 하단)
    shortcut_text = get_localization_manager().get_text("menu.fullscreen_shortcut", "F9 전체화면  F10 창모드")
    shortcut_surface = font_tiny.render(shortcut_text, True, (160, 200, 255))
    shortcut_rect = shortcut_surface.get_rect(bottomright=(width - 10, height - 10))
    screen.blit(shortcut_surface, shortcut_rect)

    # BGM 토글 안내 (우측 하단, F9/F10 위) - B 키캡 아이콘 + 텍스트
    bgm_label_surface = font_tiny.render(get_localization_manager().get_text("menu.bgm_toggle", "BGM 켜기/끄기"), True, (160, 200, 255))
    bgm_label_h = bgm_label_surface.get_height()
    cap_size = max(bgm_label_h, 16)
    gap = 5  # 키캡과 텍스트 사이 간격
    total_w = cap_size + gap + bgm_label_surface.get_width()
    bgm_hint_x = width - 10 - total_w
    bgm_hint_y = shortcut_rect.top - 4 - cap_size
    # 키캡 배경
    pygame.draw.rect(screen, (50, 60, 80), (bgm_hint_x, bgm_hint_y, cap_size, cap_size), border_radius=4)
    pygame.draw.rect(screen, (100, 120, 150), (bgm_hint_x, bgm_hint_y, cap_size, cap_size), 2, border_radius=4)
    # 키캡 문자
    b_surf = font_tiny.render("B", True, (220, 220, 220))
    b_rect = b_surf.get_rect(center=(bgm_hint_x + cap_size // 2, bgm_hint_y + cap_size // 2))
    screen.blit(b_surf, b_rect)
    # 라벨 텍스트
    screen.blit(bgm_label_surface, (bgm_hint_x + cap_size + gap, bgm_hint_y + (cap_size - bgm_label_h) // 2))

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
        admin_text = font_admin.render(get_localization_manager().get_text("menu.admin_mode", "🔓 관리자 모드 시작"), True, (255, 220, 100))
        admin_text_rect = admin_text.get_rect(center=(width // 2, admin_msg_y + admin_msg_height // 2))

        # 텍스트 알파 적용
        admin_text.set_alpha(fade_alpha)
        screen.blit(admin_text, admin_text_rect)


def _run_ai_play_flow(ctx: MenuContext) -> bool:
    """AI 플레이 캐릭터 선택 후 게임 시작."""
    _loc = get_localization_manager()
    ai_chars = [
        ("smasher", _loc.get_text("char.smasher", "스매셔")),
        ("soldier", _loc.get_text("char.soldier", "코만도")),
        ("blacksmith", _loc.get_text("char.blacksmith", "발토르")),
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
        title = font_title.render(get_localization_manager().get_text("menu.ai_char_select", "AI 플레이 캐릭터 선택"), True, (200, 230, 255))
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
    options = ["온라인 대전", "로컬플레이", "뒤로"]
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
                    if choice == "온라인 대전":
                        if hasattr(ctx, 'start_online_multiplayer') and ctx.start_online_multiplayer:
                            ctx.start_online_multiplayer()
                            return True
                        return False
                    elif choice == "로컬플레이":
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
                        if opt == "온라인 대전":
                            if hasattr(ctx, 'start_online_multiplayer') and ctx.start_online_multiplayer:
                                ctx.start_online_multiplayer()
                                return True
                            return False
                        elif opt == "로컬플레이":
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

        title = font_title.render(get_localization_manager().get_text("menu.local_play_title", "멀티플레이"), True, (200, 230, 255))
        screen.blit(title, title.get_rect(center=(width // 2, height // 2 - 130)))

        # 설명 텍스트
        desc_font = ctx.FontStyle.tiny()
        desc_text = get_localization_manager().get_text("menu.local_play_desc", "같은 PC에서 2명이 대결합니다")
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

            _mp_label_map = {"로컬플레이": "menu.local_play", "뒤로": "menu.back"}
            _opt_display = get_localization_manager().get_text(_mp_label_map.get(opt, ""), opt) if opt in _mp_label_map else opt
            label_surface = font_item.render(_opt_display, True, (255, 255, 255))
            screen.blit(label_surface, label_surface.get_rect(center=(rect.centerx, rect.centery + 15)))

            if is_sel and opt == "온라인 대전":
                hint = "IP 주소로 다른 PC와 1:1 대전"
                hint_surf = ctx.FontStyle.tiny().render(hint, True, (210, 220, 255))
                screen.blit(hint_surf, hint_surf.get_rect(center=(width // 2, rect.bottom + 30)))
            elif is_sel and opt == "로컬플레이":
                hint = get_localization_manager().get_text("menu.local_play_controls", "P1: 방향키/Shift  |  P2: WASD/Space")
                hint_surf = ctx.FontStyle.tiny().render(hint, True, (210, 220, 255))
                screen.blit(hint_surf, hint_surf.get_rect(center=(width // 2, rect.bottom + 30)))

        pygame.display.flip()


def _show_dev_test_menu(ctx: MenuContext, state: MenuState) -> bool:
    """메인 메뉴 하위 개발/테스트 묶음."""
    options = ["AI 플레이", "뒤로"]
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
                    return False
                elif ev.key == pygame.K_ESCAPE:
                    return False
            if ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mx, my = ev.pos
                menu_y = height // 2
                item_w = 160
                spacing = 16
                total_w = len(options) * item_w + (len(options) - 1) * spacing
                start_x = (width - total_w) // 2
                for idx, opt in enumerate(options):
                    rect = pygame.Rect(start_x + idx * (item_w + spacing), menu_y - 40, item_w, 90)
                    if rect.collidepoint(mx, my):
                        selected = idx
                        if opt == "AI 플레이":
                            return _run_ai_play_flow(ctx)
                        return False

        font_title = ctx.FontStyle.title()
        font_item = ctx.FontStyle.body()
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 120))
        screen.blit(overlay, (0, 0))

        title = font_title.render(get_localization_manager().get_text("menu.dev_test_title", "개발 테스트"), True, (200, 230, 255))
        screen.blit(title, title.get_rect(center=(width // 2, height // 2 - 130)))

        _dev_label_map = {"AI 플레이": "menu.ai_play", "뒤로": "menu.back"}
        item_w = 160
        spacing = 16
        total_w = len(options) * item_w + (len(options) - 1) * spacing
        start_x = (width - total_w) // 2
        for idx, opt in enumerate(options):
            x = start_x + idx * (item_w + spacing)
            rect = pygame.Rect(x, height // 2 - 40, item_w, 90)
            is_sel = idx == selected
            bg_color = (50, 90, 140) if is_sel else (30, 40, 60)
            pygame.draw.rect(screen, bg_color, rect, border_radius=12)
            pygame.draw.rect(screen, (140, 200, 255), rect, 2 if is_sel else 1, border_radius=12)
            _dev_display = get_localization_manager().get_text(_dev_label_map.get(opt, ""), opt) if opt in _dev_label_map else opt
            label_surface = font_item.render(_dev_display, True, (255, 255, 255))
            screen.blit(label_surface, label_surface.get_rect(center=rect.center))
            if is_sel and opt == "AI 플레이":
                hint_surf = ctx.FontStyle.tiny().render(get_localization_manager().get_text("menu.ai_battle_start", "AI 대전 시작"), True, (210, 220, 255))
                screen.blit(hint_surf, hint_surf.get_rect(center=(rect.centerx, rect.bottom + 24)))

        pygame.display.flip()


# ─── 모드 선택 화면 (아케이드 / 투기장) ───────────────────────────────

_mode_card_preview_cache: dict = {}


def _load_mode_preview(path_key: str, resource_path_fn) -> "pygame.Surface | None":
    """모드 카드 미리보기 이미지를 로드하고 캐시한다."""
    if path_key in _mode_card_preview_cache:
        return _mode_card_preview_cache[path_key]
    import os
    full_path = resource_path_fn(path_key)
    if os.path.exists(full_path):
        try:
            img = pygame.image.load(full_path).convert_alpha()
            _mode_card_preview_cache[path_key] = img
            return img
        except Exception:
            pass
    _mode_card_preview_cache[path_key] = None
    return None


# ── 모드 선택 비주얼 헬퍼 함수들 ──

def _mode_draw_plasma_border(screen, rect, accent, anim_t, intensity=1.0):
    """불규칙하게 맥동하는 네온 플라즈마 테두리 — 3중 레이어 + 코너 불꽃."""
    x, y, w, h = rect.x, rect.y, rect.w, rect.h
    br = 18

    for layer in range(3):
        thickness = 4 - layer
        base_alpha = int((200 - layer * 60) * intensity)
        # 시간에 따라 색상이 미세하게 흐름
        phase = anim_t * (3.0 + layer * 0.7)
        shift = int(math.sin(phase) * 35)
        shift2 = int(math.cos(phase * 0.7) * 25)
        c = (
            max(0, min(255, accent[0] + shift)),
            max(0, min(255, accent[1] - shift2)),
            max(0, min(255, accent[2] + shift2)),
        )
        expand = layer * 3
        surf = pygame.Surface((w + expand * 2 + 2, h + expand * 2 + 2), pygame.SRCALPHA)
        pygame.draw.rect(
            surf, (*c, base_alpha),
            (0, 0, w + expand * 2 + 2, h + expand * 2 + 2),
            thickness, border_radius=br + layer * 2,
        )
        screen.blit(surf, (x - expand - 1, y - expand - 1))

    # 코너 불꽃 파티클 (4코너에서 불규칙 스파크)
    corners = [(x, y), (x + w, y), (x, y + h), (x + w, y + h)]
    for ci, (cx, cy) in enumerate(corners):
        spark_phase = (anim_t * 6.0 + ci * 1.57) % (math.pi * 2)
        if math.sin(spark_phase) > 0.3:
            spark_len = int(6 + 8 * math.sin(spark_phase) * intensity)
            spark_alpha = int(180 * math.sin(spark_phase) * intensity)
            # 대각선 방향 스파크
            dx = -1 if cx == x else 1
            dy = -1 if cy == y else 1
            sp = pygame.Surface((spark_len * 2 + 4, spark_len * 2 + 4), pygame.SRCALPHA)
            pygame.draw.line(sp, (*accent, spark_alpha), (spark_len + 2, spark_len + 2),
                             (spark_len + 2 + dx * spark_len, spark_len + 2 + dy * spark_len), 2)
            # 십자 스파크
            pygame.draw.line(sp, (*accent, spark_alpha // 2), (spark_len + 2 - 3, spark_len + 2),
                             (spark_len + 2 + 3, spark_len + 2), 1)
            pygame.draw.line(sp, (*accent, spark_alpha // 2), (spark_len + 2, spark_len + 2 - 3),
                             (spark_len + 2, spark_len + 2 + 3), 1)
            screen.blit(sp, (cx - spark_len - 2, cy - spark_len - 2))


def _mode_draw_shine_sweep(card_surf, w, h, offset, accent):
    """카드 표면에 프리미엄 대각선 광택 스윕 — 이중 반사 + 백색 발광 (수정본)."""
    sweep_w = 180  # 광택 전체 너비
    skew = int(h * 0.7)  # 기울기 (상단이 우측으로 얼마나 밀릴지 결정)

    # 오프셋 범위 계산 (완전히 화면 밖에서 시작해서 완전히 밖으로 나가도록)
    total_travel = w + sweep_w + skew
    pos = int(offset * 2.5) % (total_travel * 2) - (sweep_w + skew)

    shine = pygame.Surface((w, h), pygame.SRCALPHA)

    # 2픽셀 단위로 렌더링하여 성능과 퀄리티를 동시에 잡음
    for col_i in range(0, sweep_w, 2):
        t = col_i / sweep_w

        # 이중 반사: 0.6 위치에 넓은 메인 빔, 0.3 위치에 얇은 서브 빔
        main_peak = math.exp(-((t - 0.6) ** 2) / 0.015)
        sub_peak = math.exp(-((t - 0.3) ** 2) / 0.005) * 0.5
        brightness = min(main_peak + sub_peak, 1.0)

        alpha = int(180 * brightness)
        if alpha < 3:
            continue

        # 코어 백색 발광 (가장 밝은 부분은 테마색 -> 순백색으로 타오름)
        core = max(0.0, (brightness - 0.6) / 0.4)
        r = int(accent[0] + (255 - accent[0]) * core)
        g = int(accent[1] + (255 - accent[1]) * core)
        b = int(accent[2] + (255 - accent[2]) * core)

        # X축으로 기울기(Shear) 적용 (Y좌표는 고정하고 X를 비틂)
        bot_x = pos + col_i          # 하단 X좌표
        top_x = bot_x + skew         # 상단 X좌표 (기울기만큼 우측으로 밀림)

        # 화면 밖 렌더링 최적화
        if top_x + 3 < 0 and bot_x + 3 < 0:
            continue
        if top_x > w and bot_x > w:
            continue

        # 완벽한 대각선 폴리곤 (빈틈 방지를 위해 너비 3px 평행사변형)
        pts = [
            (top_x, 0),
            (top_x + 3, 0),
            (bot_x + 3, h),
            (bot_x, h),
        ]
        pygame.draw.polygon(shine, (r, g, b, alpha), pts)

    card_surf.blit(shine, (0, 0), special_flags=pygame.BLEND_ADD)


def _mode_update_mouse_trail(dt, width, height):
    """마우스 궤적 파티클 업데이트."""
    global _mode_mouse_trail
    mx, my = pygame.mouse.get_pos()

    # 새 파티클 생성 (마우스 이동 시)
    if random.random() < 0.4:
        _mode_mouse_trail.append({
            "x": mx + random.uniform(-3, 3),
            "y": my + random.uniform(-3, 3),
            "vx": random.uniform(-0.8, 0.8),
            "vy": random.uniform(-2.0, -0.5),
            "life": random.uniform(0.4, 0.8),
            "max_life": 0.8,
            "color": random.choice([(0, 200, 255), (255, 200, 80), (200, 100, 255), (255, 255, 255)]),
            "size": random.uniform(1.5, 3.5),
        })

    # 업데이트
    alive = []
    for p in _mode_mouse_trail:
        p["life"] -= dt
        if p["life"] <= 0:
            continue
        p["x"] += p["vx"]
        p["y"] += p["vy"]
        p["vy"] -= 0.5 * dt  # 약간 위로 떠오름
        alive.append(p)
    _mode_mouse_trail = alive[-80:]  # 최대 80개


def _mode_draw_mouse_trail(screen):
    """마우스 궤적 파티클 렌더링."""
    for p in _mode_mouse_trail:
        ratio = max(0, p["life"] / p["max_life"])
        alpha = int(180 * ratio)
        size = max(1, int(p["size"] * ratio))
        if alpha < 3:
            continue
        ps = pygame.Surface((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
        # 글로우 헤일로
        pygame.draw.circle(ps, (*p["color"], alpha // 3), (size + 2, size + 2), size + 2)
        # 코어
        pygame.draw.circle(ps, (*p["color"], alpha), (size + 2, size + 2), size)
        screen.blit(ps, (int(p["x"]) - size - 2, int(p["y"]) - size - 2))


def _mode_update_bg_energy(dt, width, height, accents):
    """배경 에너지 파티클 (카드 테마 색상으로 공간을 채움)."""
    global _mode_bg_energy_particles

    # 새 파티클 생성
    if len(_mode_bg_energy_particles) < 60 and random.random() < 0.3:
        _mode_bg_energy_particles.append({
            "x": random.uniform(0, width),
            "y": random.uniform(0, height),
            "vx": random.uniform(-0.3, 0.3),
            "vy": random.uniform(-0.5, -0.1),
            "life": random.uniform(2.0, 5.0),
            "max_life": 5.0,
            "color": random.choice(accents),
            "size": random.uniform(1.0, 2.5),
            "phase": random.uniform(0, math.pi * 2),
        })

    alive = []
    for p in _mode_bg_energy_particles:
        p["life"] -= dt
        if p["life"] <= 0:
            continue
        p["x"] += p["vx"] + math.sin(p["phase"]) * 0.2
        p["y"] += p["vy"]
        p["phase"] += dt * 1.5
        # 화면 밖으로 나가면 제거
        if p["y"] < -10 or p["x"] < -10 or p["x"] > width + 10:
            continue
        alive.append(p)
    _mode_bg_energy_particles = alive


def _mode_draw_bg_energy(screen):
    """배경 에너지 파티클 렌더링."""
    for p in _mode_bg_energy_particles:
        ratio = max(0, min(1, p["life"] / p["max_life"]))
        # 페이드인 + 페이드아웃
        if ratio > 0.8:
            alpha_f = (1.0 - ratio) / 0.2
        else:
            alpha_f = min(1.0, ratio / 0.3)
        alpha = int(100 * alpha_f)
        size = max(1, int(p["size"] * (0.5 + 0.5 * alpha_f)))
        if alpha < 2:
            continue
        ps = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        pygame.draw.circle(ps, (*p["color"], alpha // 2), (size * 2, size * 2), size * 2)
        pygame.draw.circle(ps, (*p["color"], alpha), (size * 2, size * 2), size)
        screen.blit(ps, (int(p["x"]) - size * 2, int(p["y"]) - size * 2))


def _mode_draw_bg_glitch(screen, width, height, anim_t):
    """미세한 배경 글리치 라인 (가로 노이즈)."""
    global _mode_bg_glitch_timer
    _mode_bg_glitch_timer += 1.0 / 60.0

    # 5% 확률 + 쿨다운
    if random.random() < 0.04 and _mode_bg_glitch_timer > 0.3:
        _mode_bg_glitch_timer = 0
        num_lines = random.randint(1, 3)
        for _ in range(num_lines):
            gy = random.randint(0, height)
            gh = random.randint(1, 4)
            gw = random.randint(width // 4, width)
            gx = random.randint(0, width - gw)
            g_color = random.choice([(0, 200, 255, 25), (255, 200, 80, 20), (255, 255, 255, 15)])
            gs = pygame.Surface((gw, gh), pygame.SRCALPHA)
            gs.fill(g_color)
            screen.blit(gs, (gx, gy))


def _mode_draw_title_ghost(screen, font, text, center, anim_t, accent):
    """타이틀 고스트(잔상) + 네온 효과."""
    cx, cy = center

    # 잔상 레이어 (뒤에서 앞으로)
    for i in range(5, 0, -1):
        ghost_alpha = max(0, 60 - i * 12)
        scale_add = i * 0.015 + math.sin(anim_t * 2.0 + i * 0.3) * 0.005
        y_shift = int(math.sin(anim_t * 1.5 + i * 0.7) * (i * 0.8))

        gs = font.render(text, True, (*accent, ghost_alpha))
        if scale_add > 0.001:
            new_w = int(gs.get_width() * (1.0 + scale_add))
            new_h = int(gs.get_height() * (1.0 + scale_add))
            if new_w > 0 and new_h > 0:
                gs = pygame.transform.smoothscale(gs, (new_w, new_h))
        gs.set_alpha(ghost_alpha)
        screen.blit(gs, gs.get_rect(center=(cx, cy + y_shift)))

    # 메인 타이틀 네온 글로우
    for offset in range(8, 0, -2):
        glow_alpha = int(40 * (1 - offset / 8))
        glow_surf = font.render(text, True, (*accent, glow_alpha))
        for dx in [-offset, 0, offset]:
            for dy in [-offset, 0, offset]:
                if dx == 0 and dy == 0:
                    continue
                screen.blit(glow_surf, glow_surf.get_rect(center=(cx + dx, cy + dy)))

    # 메인 텍스트 (밝은 화이트)
    main = font.render(text, True, (255, 255, 255))
    screen.blit(main, main.get_rect(center=center))


def _draw_mode_card(
    screen: pygame.Surface,
    x: int, y: int, w: int, h: int,
    title: str, subtitle: str,
    color_top: tuple, color_bot: tuple,
    accent: tuple, icon_char: str,
    is_selected: bool, scale: float,
    y_offset: float, anim_t: float,
    ctx: "MenuContext",
    preview_img: "pygame.Surface | None" = None,
    card_index: int = 0,
    flash_intensity: float = 0.0,
):
    """모드 선택 카드 — 3D 기울기, 광택 스윕, 플라즈마 테두리, 대형 아이콘 오버레이."""
    global _mode_card_tilt_y, _mode_card_tilt_x, _mode_shine_offset

    # scale 적용 (중심 기준)
    sw, sh = int(w * scale), int(h * scale)
    card_center_x = x + w // 2
    card_center_y = int(y + h // 2 + y_offset)

    # ── 3D 기울기 계산 (마우스 위치 기반) ──
    mpos = pygame.mouse.get_pos()
    if is_selected:
        dx = (mpos[0] - card_center_x) / max(w // 2, 1)
        dy = (mpos[1] - card_center_y) / max(h // 2, 1)
        target_ty = max(-12.0, min(12.0, dx * 12.0))
        target_tx = max(-8.0, min(8.0, -dy * 8.0))
    else:
        target_ty = 0.0
        target_tx = 0.0

    # 부드러운 보간
    _mode_card_tilt_y[card_index] += (target_ty - _mode_card_tilt_y[card_index]) * 0.12
    _mode_card_tilt_x[card_index] += (target_tx - _mode_card_tilt_x[card_index]) * 0.12
    tilt_y = _mode_card_tilt_y[card_index]
    tilt_x = _mode_card_tilt_x[card_index]

    # ── 카드 서피스 생성 ──
    card = pygame.Surface((sw, sh), pygame.SRCALPHA)

    if preview_img is not None:
        img_w, img_h = preview_img.get_size()
        img_scale = max(sw / img_w, sh / img_h) * 1.20
        scaled_w = int(img_w * img_scale)
        scaled_h = int(img_h * img_scale)
        scaled_img = pygame.transform.smoothscale(preview_img, (scaled_w, scaled_h))
        # 호버 시 패닝 + 기울기 방향으로 미세 시프트
        if is_selected:
            pan_x = int(math.sin(anim_t * 0.5) * (scaled_w - sw) * 0.3 + tilt_y * 1.5)
            pan_y = int(math.cos(anim_t * 0.4) * (scaled_h - sh) * 0.3 + tilt_x * 1.2)
        else:
            pan_x = 0
            pan_y = 0
        blit_x = -(scaled_w - sw) // 2 + pan_x
        blit_y = -(scaled_h - sh) // 2 + pan_y
        card.blit(scaled_img, (blit_x, blit_y))

        # 컬러 그라데이션 오버레이 (선택 시 테마 색상 틴트)
        grad_h = int(sh * 0.65)
        grad_surf = pygame.Surface((sw, grad_h), pygame.SRCALPHA)
        for row in range(grad_h):
            t = row / max(grad_h - 1, 1)
            if is_selected:
                a = int(180 * (t ** 1.5))
                r = int(accent[0] * 0.15 * t)
                g = int(accent[1] * 0.15 * t)
                b = int(accent[2] * 0.15 * t)
            else:
                a = int(200 * (t ** 1.2))
                r, g, b = 0, 0, 0
            pygame.draw.line(grad_surf, (r, g, b, a), (0, row), (sw - 1, row))
        card.blit(grad_surf, (0, sh - grad_h))

        # 비선택 시 어둡게 + 채도 감소 효과
        if not is_selected:
            dim = pygame.Surface((sw, sh), pygame.SRCALPHA)
            dim.fill((0, 0, 0, 120))
            card.blit(dim, (0, 0))
    else:
        # 폴백: 향상된 그라데이션 배경
        for row in range(sh):
            t = row / max(sh - 1, 1)
            r = int(color_top[0] + (color_bot[0] - color_top[0]) * t)
            g = int(color_top[1] + (color_bot[1] - color_top[1]) * t)
            b = int(color_top[2] + (color_bot[2] - color_top[2]) * t)
            pygame.draw.line(card, (r, g, b, 220), (0, row), (sw - 1, row))

    # ── 실시간 광택 스윕 (선택 시만) ──
    if is_selected:
        _mode_shine_offset[card_index] += 3.5  # 스윕 속도
        _mode_draw_shine_sweep(card, sw, sh, _mode_shine_offset[card_index], accent)
    else:
        # 비선택 시 오프셋 리셋 (다음 선택 시 처음부터)
        _mode_shine_offset[card_index] *= 0.95

    # ── 둥근 마스크 (모서리 깎기) ──
    mask = pygame.Surface((sw, sh), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255, 255, 255, 255), (0, 0, sw, sh), border_radius=18)
    card.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)

    # ── 타이틀 (하단 — 선택 시 네온 아웃라인) ──
    title_font = ctx.FontStyle.body()
    if is_selected:
        # 네온 아웃라인
        for ox, oy in [(-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (0, 1), (-1, 0), (1, 0)]:
            ts_glow = title_font.render(title, True, accent)
            card.blit(ts_glow, ts_glow.get_rect(center=(sw // 2 + ox, sh - 55 + oy)))
    ts = title_font.render(title, True, (255, 255, 255))
    card.blit(ts, ts.get_rect(center=(sw // 2, sh - 55)))

    # 부제
    sub_font = ctx.FontStyle.tiny()
    sub_color = (220, 230, 240) if is_selected else (170, 180, 195)
    ss = sub_font.render(subtitle, True, sub_color)
    card.blit(ss, ss.get_rect(center=(sw // 2, sh - 30)))

    # ── 3D 기울기 적용 (수평 스케일링으로 시뮬레이션) ──
    cos_y = math.cos(math.radians(tilt_y))
    final_w = max(1, int(sw * abs(cos_y)))
    if final_w != sw:
        card = pygame.transform.smoothscale(card, (final_w, sh))

    # ── 선택 전환 플래시 오버레이 ──
    if flash_intensity > 0.01:
        flash_surf = pygame.Surface((card.get_width(), sh), pygame.SRCALPHA)
        flash_surf.fill((*accent, int(120 * flash_intensity)))
        card.blit(flash_surf, (0, 0))

    # ── 화면에 blit ──
    final_rect = card.get_rect(center=(card_center_x, card_center_y))
    screen.blit(card, final_rect)

    # ── 테두리 & 글로우 ──
    if is_selected:
        # 플라즈마 네온 테두리
        _mode_draw_plasma_border(screen, final_rect, accent, anim_t)
        # 외곽 소프트 글로우
        pulse = 0.5 + 0.5 * math.sin(anim_t * 3.0)
        glow_s = pygame.Surface((final_rect.w + 20, final_rect.h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_s, (*accent, int(30 * pulse)), (0, 0, final_rect.w + 20, final_rect.h + 20), border_radius=26)
        screen.blit(glow_s, (final_rect.x - 10, final_rect.y - 10))
        # 코너 라인 + 파티클
        _menu_draw_hover_border(screen, final_rect.x, final_rect.y, final_rect.w, final_rect.h, accent)
    else:
        # 비선택: 은은한 테두리
        border_color = (accent[0] // 2, accent[1] // 2, accent[2] // 2)
        bs = pygame.Surface((final_rect.w + 4, final_rect.h + 4), pygame.SRCALPHA)
        pygame.draw.rect(bs, (*border_color, 100), (0, 0, final_rect.w + 4, final_rect.h + 4), 2, border_radius=20)
        screen.blit(bs, (final_rect.x - 2, final_rect.y - 2))

    return final_rect


def _draw_trophy_icon(surf, cx, cy, scale, accent, dim_f, sel_f, anim_t):
    """토너먼트용 트로피 아이콘 (큰 사이즈)."""
    s = scale
    al = lambda v: max(0, min(255, int(v * dim_f)))
    # 트로피 전체를 약간 위로 올림
    oy = -int(5 * s)
    cy = cy + oy

    # ── 받침대 (맨 아래) ──
    base_bw = int(72 * s)
    base_tw = int(60 * s)
    base_h = int(10 * s)
    base_y = cy + int(42 * s)
    base_pts = [
        (cx - base_tw // 2, base_y),
        (cx + base_tw // 2, base_y),
        (cx + base_bw // 2, base_y + base_h),
        (cx - base_bw // 2, base_y + base_h),
    ]
    pygame.draw.polygon(surf, (180, 145, 40, al(240)), base_pts)
    pygame.draw.polygon(surf, (130, 100, 25, al(220)), base_pts, 2)
    pygame.draw.line(surf, (220, 190, 80, al(140)),
                     (cx - base_tw // 2 + 4, base_y + 2),
                     (cx + base_tw // 2 - 4, base_y + 2), 1)

    # ── 두 번째 받침대 (살짝 위) ──
    p2_w = int(50 * s)
    p2_h = int(6 * s)
    p2_y = base_y - p2_h
    pygame.draw.rect(surf, (200, 165, 50, al(230)),
                     (cx - p2_w // 2, p2_y, p2_w, p2_h))
    pygame.draw.rect(surf, (150, 115, 30, al(200)),
                     (cx - p2_w // 2, p2_y, p2_w, p2_h), 1)

    # ── 줄기 ──
    stem_w = int(14 * s)
    stem_h = int(18 * s)
    stem_y = p2_y - stem_h
    pygame.draw.rect(surf, (210, 175, 55, al(230)),
                     (cx - stem_w // 2, stem_y, stem_w, stem_h))
    pygame.draw.rect(surf, (160, 125, 35, al(200)),
                     (cx - stem_w // 2, stem_y, stem_w, stem_h), 1)
    # 줄기 가운데 장식선
    pygame.draw.line(surf, (240, 210, 90, al(100)),
                     (cx, stem_y + 3), (cx, stem_y + stem_h - 3), 1)

    # ── 컵 본체 (큰 사이즈!) ──
    cup_tw = int(80 * s)    # 컵 상단 너비
    cup_bw = int(36 * s)    # 컵 하단 너비
    cup_ty = cy - int(46 * s)  # 컵 상단 Y
    cup_by = stem_y            # 컵 하단 Y = 줄기 상단

    # 컵 본체 그라데이션 (수평 슬라이스)
    slices = 20
    for si in range(slices):
        t = si / slices
        t2 = (si + 1) / slices
        w1 = cup_tw + (cup_bw - cup_tw) * t
        w2 = cup_tw + (cup_bw - cup_tw) * t2
        y1 = cup_ty + (cup_by - cup_ty) * t
        y2 = cup_ty + (cup_by - cup_ty) * t2
        r = int(255 - 60 * t)
        g = int(215 - 70 * t)
        b = int(55 + 30 * t)
        pts = [(cx - int(w1 / 2), int(y1)), (cx + int(w1 / 2), int(y1)),
               (cx + int(w2 / 2), int(y2)), (cx - int(w2 / 2), int(y2))]
        pygame.draw.polygon(surf, (r, g, b, al(230)), pts)

    # 좌측 반사 하이라이트
    for si in range(slices):
        t = si / slices
        t2 = (si + 1) / slices
        w1 = cup_tw + (cup_bw - cup_tw) * t
        w2 = cup_tw + (cup_bw - cup_tw) * t2
        y1 = cup_ty + (cup_by - cup_ty) * t
        y2 = cup_ty + (cup_by - cup_ty) * t2
        sw = int(8 * s)
        sx1 = cx - int(w1 / 2) + int(10 * s)
        sx2 = cx - int(w2 / 2) + int(10 * s)
        ha = al(int(70 * (1 - t * 0.6)))
        pts = [(sx1, int(y1)), (sx1 + sw, int(y1)),
               (sx2 + sw, int(y2)), (sx2, int(y2))]
        pygame.draw.polygon(surf, (255, 255, 220, ha), pts)

    # 컵 윤곽
    cup_out = [(cx - cup_tw // 2, cup_ty), (cx + cup_tw // 2, cup_ty),
               (cx + cup_bw // 2, cup_by), (cx - cup_bw // 2, cup_by)]
    pygame.draw.polygon(surf, (170, 130, 35, al(240)), cup_out, 2)

    # ── 컵 상단 림 ──
    rim_w = int(88 * s)
    rim_h = int(8 * s)
    rim_y = cup_ty - rim_h
    rim_pts = [(cx - rim_w // 2, rim_y), (cx + rim_w // 2, rim_y),
               (cx + rim_w // 2 - 3, rim_y + rim_h), (cx - rim_w // 2 + 3, rim_y + rim_h)]
    pygame.draw.polygon(surf, (255, 230, 120, al(240)), rim_pts)
    pygame.draw.polygon(surf, (190, 155, 50, al(220)), rim_pts, 2)
    # 림 상단 밝은 선
    pygame.draw.line(surf, (255, 250, 180, al(160)),
                     (cx - rim_w // 2 + 4, rim_y + 2),
                     (cx + rim_w // 2 - 4, rim_y + 2), 1)

    # ── 핸들 (좌우 C자 곡선) ──
    handle_r = int(18 * s)
    handle_cy_pos = cup_ty + int(24 * s)
    for side in (-1, 1):
        hcx = cx + side * (cup_tw // 2 + handle_r - int(6 * s))
        pts = []
        start_deg = 90 if side == 1 else -90
        sweep = 180
        for ai in range(17):
            ang = math.radians(start_deg + ai * (sweep / 16))
            pts.append((hcx + int(handle_r * math.cos(ang)),
                        handle_cy_pos + int(handle_r * math.sin(ang))))
        if len(pts) > 1:
            pygame.draw.lines(surf, (255, 215, 80, al(230)), False, pts, 5)
            pygame.draw.lines(surf, (190, 150, 40, al(200)), False, pts, 2)
        for ep in [pts[0], pts[-1]]:
            pygame.draw.circle(surf, (255, 225, 100, al(230)), ep, int(3 * s))

    # ── 컵 위 별 ──
    star_cy2 = cup_ty + int(28 * s)
    star_r = int(14 * s)
    star_ir = int(6 * s)
    star_pts = []
    for i in range(10):
        ang = math.radians(i * 36 - 90)
        r = star_r if i % 2 == 0 else star_ir
        star_pts.append((cx + int(r * math.cos(ang)),
                         star_cy2 + int(r * math.sin(ang))))
    pygame.draw.polygon(surf, (255, 255, 230, al(240)), star_pts)
    pygame.draw.polygon(surf, (200, 175, 70, al(200)), star_pts, 1)

    # ── 반짝임 ──
    sparkle_t = (anim_t * 1.0) % 5.0
    sparkles = [
        (cx - int(28 * s), cup_ty + int(10 * s)),
        (cx + int(25 * s), cup_ty + int(16 * s)),
        (cx + int(8 * s), rim_y - int(2 * s)),
        (cx - int(12 * s), rim_y + int(3 * s)),
    ]
    for si, (spx, spy) in enumerate(sparkles):
        phase = (sparkle_t + si * 1.2) % 5.0
        if phase < 0.8:
            br = phase / 0.8
        elif phase < 1.6:
            br = 1.0 - (phase - 0.8) / 0.8
        else:
            br = 0
        if br > 0.05:
            spa = int(220 * br * dim_f * sel_f)
            spl = int(7 * s * br)
            pygame.draw.line(surf, (255, 255, 255, spa),
                             (spx - spl, spy), (spx + spl, spy), 1)
            pygame.draw.line(surf, (255, 255, 255, spa),
                             (spx, spy - spl), (spx, spy + spl), 1)
            d = int(spl * 0.5)
            for ddx, ddy in [(-d, -d), (d, -d), (-d, d), (d, d)]:
                pygame.draw.line(surf, (255, 255, 200, spa // 2),
                                 (spx, spy), (spx + ddx, spy + ddy), 1)

    # ── 월계수 잎 (좌우) ──
    leaf_al = al(int(170 * sel_f))
    for side in (-1, 1):
        for li in range(5):
            la = math.radians(25 + li * 18) * side
            bx = cx + side * int(38 * s)
            by = cup_by - li * int(12 * s)
            ll = int((11 - li) * s)
            tx = bx + int(ll * math.cos(la))
            ty = by + int(ll * math.sin(la))
            pa = la + math.pi / 2
            lw = int(5 * s)
            p1 = (bx + int(lw * 0.3 * math.cos(pa)),
                   by + int(lw * 0.3 * math.sin(pa)))
            p2 = (bx - int(lw * 0.3 * math.cos(pa)),
                   by - int(lw * 0.3 * math.sin(pa)))
            pygame.draw.polygon(surf, (110, 190, 65, leaf_al),
                                [p1, (tx, ty), p2])
            pygame.draw.polygon(surf, (65, 130, 35, leaf_al // 2),
                                [p1, (tx, ty), p2], 1)


def _draw_swords_icon(surf, cx, cy, scale, accent, dim_f, sel_f, anim_t):
    """도장깨기용 교차 검 + 방패 아이콘 (레퍼런스 스타일 - 깔끔한 카툰)."""
    s = scale
    al = lambda v: max(0, min(255, int(v * dim_f)))

    # ── 색상 정의 (레퍼런스 기반) ──
    # 방패: 진한 빨강 본체 + 어두운 테두리
    shield_red = (180, 50, 55)
    shield_red_light = (200, 70, 72)
    shield_border_dark = (45, 40, 45)
    shield_border_mid = (80, 75, 80)
    # 검날: 밝은 실버/라이트그레이
    blade_light = (220, 225, 235)
    blade_mid = (190, 195, 210)
    blade_dark = (140, 145, 160)
    blade_outline = (60, 55, 65)
    # 가드: 골드/옐로우
    guard_gold = (210, 175, 55)
    guard_gold_light = (240, 210, 80)
    guard_gold_dark = (170, 130, 30)
    # 그립: 다크 네이비
    grip_navy = (35, 35, 80)
    grip_navy_light = (55, 55, 110)
    # 폼멜: 빨간 보석
    pommel_red = (190, 45, 50)
    pommel_outline = (60, 55, 65)

    # ════════════════════════════════════════
    # 1) 방패 (레퍼런스: 큰 방패가 중심, 검이 위에)
    # ════════════════════════════════════════
    sw = int(84 * s)   # 방패 너비 (68→84)
    sh = int(100 * s)  # 방패 높이 (82→100)
    st = cy - int(44 * s)  # 방패 상단 Y (36→44)

    # 방패 외곽 형태 (오각형 실드)
    shield = [
        (cx - sw // 2, st),                    # 좌상
        (cx + sw // 2, st),                    # 우상
        (cx + sw // 2, st + int(sh * 0.58)),   # 우중
        (cx, st + sh),                         # 하단 꼭짓점
        (cx - sw // 2, st + int(sh * 0.58)),   # 좌중
    ]

    # 방패 그림자
    shadow_off = int(3 * s)
    shield_shadow = [(px + shadow_off, py + shadow_off) for px, py in shield]
    pygame.draw.polygon(surf, (15, 15, 20, al(120)), shield_shadow)

    # 방패 테두리 (두꺼운 어두운 색)
    pygame.draw.polygon(surf, (*shield_border_dark, al(255)), shield)

    # 방패 본체 (안쪽 - 빨간색)
    bm = int(5 * s)  # 테두리 두께
    inner_shield = [
        (cx - sw // 2 + bm, st + bm),
        (cx + sw // 2 - bm, st + bm),
        (cx + sw // 2 - bm, st + int(sh * 0.56)),
        (cx, st + sh - int(6 * s)),
        (cx - sw // 2 + bm, st + int(sh * 0.56)),
    ]
    pygame.draw.polygon(surf, (*shield_red, al(255)), inner_shield)

    # 방패 밝은 면 (좌상 - 하이라이트)
    hi_shield = [
        inner_shield[0],
        (cx, st + bm),
        (cx, st + sh - int(6 * s)),
        inner_shield[4],
    ]
    pygame.draw.polygon(surf, (*shield_red_light, al(80)), hi_shield)

    # 방패 X 무늬 (레퍼런스의 대각선 장식)
    x_m = int(8 * s)
    x_top_l = (cx - sw // 2 + x_m, st + x_m)
    x_top_r = (cx + sw // 2 - x_m, st + x_m)
    x_bot = (cx, st + sh - int(10 * s))
    x_mid_l = (cx - sw // 2 + x_m, st + int(sh * 0.53))
    x_mid_r = (cx + sw // 2 - x_m, st + int(sh * 0.53))
    # 대각선 크로스
    pygame.draw.line(surf, (*shield_border_dark, al(60)), x_top_l, x_mid_r, max(2, int(2 * s)))
    pygame.draw.line(surf, (*shield_border_dark, al(60)), x_top_r, x_mid_l, max(2, int(2 * s)))

    # 방패 상단 테두리 하이라이트 (미세하게 밝은 라인)
    pygame.draw.line(surf, (*shield_border_mid, al(140)),
                     (cx - sw // 2 + 2, st + 1), (cx + sw // 2 - 2, st + 1), 1)

    # ════════════════════════════════════════
    # 2) 교차 검 (방패 위에 X자로 교차)
    # ════════════════════════════════════════
    for side in (-1, 1):
        # 검 각도: 수직 기준 ±42도 (칼끝이 위를 향함)
        sa = math.radians(42 * side)
        ddx = math.sin(sa)
        ddy = -math.cos(sa)
        ppx = -ddy  # 수직 방향
        ppy = ddx

        # 검의 기준점 (교차 중심은 방패 중앙 약간 위)
        cross_x = cx
        cross_y = cy - int(4 * s)

        # 검날: 교차점에서 위로 뻗는 부분
        blade_len = int(72 * s)   # 58→72
        tip_x = cross_x + ddx * blade_len
        tip_y = cross_y + ddy * blade_len

        # 그립: 교차점에서 아래로 뻗는 부분
        grip_total = int(40 * s)  # 32→40
        grip_end_x = cross_x - ddx * grip_total
        grip_end_y = cross_y - ddy * grip_total

        # ── 2a) 검날 (사다리꼴 - 넓은 밑, 좁은 끝) ──
        bw_base = int(10 * s)  # 검날 밑 반폭 (8→10)
        bw_tip = int(3 * s)   # 검날 끝 반폭 (2→3)
        blade_pts = [
            (int(cross_x - ppx * bw_base), int(cross_y - ppy * bw_base)),
            (int(cross_x + ppx * bw_base), int(cross_y + ppy * bw_base)),
            (int(tip_x + ppx * bw_tip), int(tip_y + ppy * bw_tip)),
            (int(tip_x - ppx * bw_tip), int(tip_y - ppy * bw_tip)),
        ]

        # 검날 그림자
        sh_off = int(2 * s)
        blade_sh = [(bx + sh_off, by + sh_off) for bx, by in blade_pts]
        pygame.draw.polygon(surf, (20, 20, 25, al(100)), blade_sh)

        # 검날 본체 (밝은 실버)
        pygame.draw.polygon(surf, (*blade_light, al(255)), blade_pts)

        # 검날 어두운 반쪽 (입체감)
        mid_base = ((blade_pts[0][0] + blade_pts[1][0]) // 2,
                    (blade_pts[0][1] + blade_pts[1][1]) // 2)
        mid_tip = ((blade_pts[2][0] + blade_pts[3][0]) // 2,
                   (blade_pts[2][1] + blade_pts[3][1]) // 2)
        dark_half = [blade_pts[0], mid_base, mid_tip, blade_pts[3]]
        pygame.draw.polygon(surf, (*blade_mid, al(200)), dark_half)

        # 검날 중심선 (밝은 하이라이트)
        pygame.draw.line(surf, (250, 252, 255, al(200)),
                         (int(cross_x + ddx * int(4*s)), int(cross_y + ddy * int(4*s))),
                         (int(tip_x - ddx * int(4*s)), int(tip_y - ddy * int(4*s))),
                         max(1, int(1.5 * s)))

        # 검날 외곽선 (어두운 아웃라인)
        pygame.draw.polygon(surf, (*blade_outline, al(255)), blade_pts, max(2, int(2 * s)))

        # 검끝 (삼각형 포인트 강조)
        tip_pt = ((blade_pts[2][0] + blade_pts[3][0]) // 2,
                  (blade_pts[2][1] + blade_pts[3][1]) // 2)
        pygame.draw.circle(surf, (*blade_light, al(255)), tip_pt, int(1.5 * s))

        # ── 2b) 가드 (십자형 크로스가드 - 골드) ──
        guard_len = int(17 * s)  # 14→17
        guard_w = int(5 * s)   # 4→5
        gcx = int(cross_x + ddx * int(1 * s))
        gcy = int(cross_y + ddy * int(1 * s))

        # 가드 본체 (직사각형 - 검에 수직)
        g1 = (gcx - int(ppx * guard_len), gcy - int(ppy * guard_len))
        g2 = (gcx + int(ppx * guard_len), gcy + int(ppy * guard_len))

        # 가드를 두꺼운 사각형으로
        gp1 = (int(g1[0] - ddx * guard_w), int(g1[1] - ddy * guard_w))
        gp2 = (int(g1[0] + ddx * guard_w), int(g1[1] + ddy * guard_w))
        gp3 = (int(g2[0] + ddx * guard_w), int(g2[1] + ddy * guard_w))
        gp4 = (int(g2[0] - ddx * guard_w), int(g2[1] - ddy * guard_w))
        guard_rect = [gp1, gp2, gp3, gp4]

        # 가드 본체
        pygame.draw.polygon(surf, (*guard_gold, al(255)), guard_rect)
        # 가드 하이라이트 (상반부)
        guard_hi = [gp1, gp2, ((gp2[0]+gp3[0])//2, (gp2[1]+gp3[1])//2),
                    ((gp1[0]+gp4[0])//2, (gp1[1]+gp4[1])//2)]
        pygame.draw.polygon(surf, (*guard_gold_light, al(120)), guard_hi)
        # 가드 아웃라인
        pygame.draw.polygon(surf, (*blade_outline, al(220)), guard_rect, max(1, int(1.5 * s)))

        # 가드 끝 장식 (양쪽 끝에 작은 돌출)
        for gp in [g1, g2]:
            pygame.draw.circle(surf, (*guard_gold, al(255)),
                               (int(gp[0]), int(gp[1])), int(3 * s))
            pygame.draw.circle(surf, (*blade_outline, al(200)),
                               (int(gp[0]), int(gp[1])), int(3 * s), 1)

        # ── 2c) 그립 (다크 네이비) ──
        grip_start_x = cross_x - ddx * int(3 * s)
        grip_start_y = cross_y - ddy * int(3 * s)
        grip_w = int(6 * s)   # 5→6

        # 그립 본체 (사각형)
        grip_pts = [
            (int(grip_start_x - ppx * grip_w), int(grip_start_y - ppy * grip_w)),
            (int(grip_start_x + ppx * grip_w), int(grip_start_y + ppy * grip_w)),
            (int(grip_end_x + ppx * grip_w), int(grip_end_y + ppy * grip_w)),
            (int(grip_end_x - ppx * grip_w), int(grip_end_y - ppy * grip_w)),
        ]
        pygame.draw.polygon(surf, (*grip_navy, al(255)), grip_pts)
        # 그립 하이라이트 스트라이프 (감김 표현)
        grip_seg = 5
        for gi in range(grip_seg):
            t1 = (gi * 2) / (grip_seg * 2)
            t2 = (gi * 2 + 1) / (grip_seg * 2)
            sx1 = grip_start_x + (grip_end_x - grip_start_x) * t1
            sy1 = grip_start_y + (grip_end_y - grip_start_y) * t1
            sx2 = grip_start_x + (grip_end_x - grip_start_x) * t2
            sy2 = grip_start_y + (grip_end_y - grip_start_y) * t2
            stripe = [
                (int(sx1 - ppx * grip_w), int(sy1 - ppy * grip_w)),
                (int(sx1 + ppx * grip_w), int(sy1 + ppy * grip_w)),
                (int(sx2 + ppx * grip_w), int(sy2 + ppy * grip_w)),
                (int(sx2 - ppx * grip_w), int(sy2 - ppy * grip_w)),
            ]
            pygame.draw.polygon(surf, (*grip_navy_light, al(180)), stripe)
        # 그립 아웃라인
        pygame.draw.polygon(surf, (*blade_outline, al(220)), grip_pts, max(1, int(1.5 * s)))

        # ── 2d) 폼멜 (빨간 보석 + 아웃라인) ──
        pom_x = int(grip_end_x)
        pom_y = int(grip_end_y)
        pom_r = int(6 * s)   # 5→6
        pygame.draw.circle(surf, (*pommel_outline, al(255)), (pom_x, pom_y), pom_r + int(1.5 * s))
        pygame.draw.circle(surf, (*pommel_red, al(255)), (pom_x, pom_y), pom_r)
        # 폼멜 하이라이트
        pygame.draw.circle(surf, (255, 200, 200, al(120)),
                           (pom_x - int(1*s), pom_y - int(1*s)), int(2 * s))
        # 폼멜 십자 장식
        cr = int(2 * s)
        pygame.draw.line(surf, (*pommel_outline, al(180)),
                         (pom_x - cr, pom_y), (pom_x + cr, pom_y), 1)
        pygame.draw.line(surf, (*pommel_outline, al(180)),
                         (pom_x, pom_y - cr), (pom_x, pom_y + cr), 1)

    # ── 선택 시 에너지 파티클 ──
    if sel_f >= 1.0:
        for pi in range(8):
            pa = (anim_t * 1.0 + pi * 0.785) % (math.pi * 2)
            pr = int(48 * s) + int(5 * math.sin(anim_t * 2 + pi))
            epx = cx + int(pr * math.cos(pa))
            epy = cy + int(pr * math.sin(pa))
            epa = int(100 * (0.5 + 0.5 * math.sin(anim_t * 3 + pi * 0.7)) * dim_f)
            pygame.draw.circle(surf, (*accent, epa), (epx, epy), int(2 * s))


def _draw_arena_emblem(
    screen: pygame.Surface,
    cx: int, cy: int, radius: int,
    label: str, sublabel: str,
    color: tuple, accent: tuple,
    icon_char: str,
    is_selected: bool,
    angle: float, glow: float,
    anim_t: float,
    ctx: "MenuContext",
    dimmed: bool = False,
    flip_angle: float = 0.0,
):
    """투기장 하위 모드 엠블럼 1개를 그린다."""
    margin = 50
    surf_size = radius * 2 + margin * 2
    surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
    center = surf_size // 2

    dim_f = 0.4 if dimmed else 1.0
    sel_f = 1.0 if is_selected else 0.7
    sc = radius / 90.0  # 스케일

    # accent 색상 변형
    acc_bright = tuple(min(255, c + 70) for c in accent)
    acc_dark = tuple(max(0, c - 60) for c in accent)

    ba = int((240 if is_selected else 160) * dim_f)
    ba_dim = int((160 if is_selected else 90) * dim_f)
    ba_hi = int((255 if is_selected else 180) * dim_f)

    # ── 1) 외곽 글로우 ──
    if glow > 0.05 and not dimmed:
        for ring in range(6, 0, -1):
            ga = int(20 * glow * (1 - ring / 7) * sel_f)
            pygame.draw.circle(surf, (*accent, ga), (center, center), radius + ring * 5, 2)

    # ── 2) 배경 원 (진한 불투명) ──
    pygame.draw.circle(surf, (*color, int(210 * dim_f)), (center, center), radius)

    # ── 3) 아이콘 그리기 ──
    icon_scale = sc
    if icon_char == "T":
        _draw_trophy_icon(surf, center, center, icon_scale, accent, dim_f, sel_f, anim_t)
    elif icon_char == "D":
        _draw_swords_icon(surf, center, center, icon_scale, accent, dim_f, sel_f, anim_t)

    # ══════════════════════════════════════════════════
    # ── 4) 고급스러운 원형 프레임 ──
    # ══════════════════════════════════════════════════

    # 4a) 외곽 두꺼운 링 (베벨 - 3겹 동심원)
    pygame.draw.circle(surf, (*acc_dark, ba_dim), (center, center), radius + 3, 2)
    pygame.draw.circle(surf, (*accent, ba), (center, center), radius + 1, 2)
    pygame.draw.circle(surf, (*acc_bright, ba_hi), (center, center), radius - 1, 2)
    # 안쪽 가느다란 선
    pygame.draw.circle(surf, (*acc_dark, int(50 * dim_f * sel_f)), (center, center), radius - 4, 1)

    # 4b) 8방위 메달리온 장식 (왕관/보석 느낌)
    num_medallions = 8
    for i in range(num_medallions):
        ang = math.radians(i * 360 / num_medallions) + angle
        # 메달리온 중심 (테두리 위)
        mx = center + int((radius + 1) * math.cos(ang))
        my = center + int((radius + 1) * math.sin(ang))

        # 바깥 방향 / 수직 방향 단위 벡터
        ox, oy = math.cos(ang), math.sin(ang)
        px, py = -oy, ox

        # ─ 외곽 방패 형태 (뾰족한 다이아몬드) ─
        d_out = int(10 * sc)
        d_in = int(5 * sc)
        d_side = int(5 * sc)
        dia = [
            (int(mx + ox * d_out), int(my + oy * d_out)),   # 바깥 꼭짓점
            (int(mx + px * d_side), int(my + py * d_side)),  # 좌
            (int(mx - ox * d_in), int(my - oy * d_in)),      # 안쪽
            (int(mx - px * d_side), int(my - py * d_side)),  # 우
        ]
        # 그림자
        dia_shadow = [(dx + 1, dy + 1) for dx, dy in dia]
        pygame.draw.polygon(surf, (0, 0, 0, int(40 * dim_f)), dia_shadow)
        # 본체
        pygame.draw.polygon(surf, (*accent, ba), dia)
        # 밝은 하이라이트 (상단 반)
        half_dia = [dia[0], dia[1], (int(mx), int(my)), dia[3]]
        pygame.draw.polygon(surf, (*acc_bright, int(ba * 0.4)), half_dia)
        # 테두리
        pygame.draw.polygon(surf, (*acc_bright, ba_dim), dia, 1)
        # 중앙 보석 점
        pygame.draw.circle(surf, (*acc_bright, ba_hi),
                           (int(mx + ox * int(2 * sc)), int(my + oy * int(2 * sc))),
                           int(2 * sc))

    # 4c) 메달리온 사이 아치형 연결 장식 (커브 + 소용돌이)
    for i in range(num_medallions):
        ang1 = math.radians(i * 360 / num_medallions) + angle
        ang2 = math.radians((i + 1) * 360 / num_medallions) + angle
        mid_ang = (ang1 + ang2) / 2

        # 아치 중간점 (살짝 바깥으로 돌출)
        arch_r = radius + int(5 * sc)
        amx = center + int(arch_r * math.cos(mid_ang))
        amy = center + int(arch_r * math.sin(mid_ang))

        # 아치 곡선 (5점 보간)
        arch_pts = []
        for ai in range(9):
            t = ai / 8.0
            a_ang = ang1 + (ang2 - ang1) * t
            # 중간이 볼록하게 (사인 곡선으로 반경 변화)
            bulge = math.sin(t * math.pi) * int(5 * sc)
            ar = radius + 1 + bulge
            arch_pts.append((
                center + int(ar * math.cos(a_ang)),
                center + int(ar * math.sin(a_ang))
            ))
        if len(arch_pts) > 1:
            pygame.draw.lines(surf, (*accent, int(ba * 0.5)), False, arch_pts, 1)

        # 아치 꼭대기에 작은 장식 점
        pygame.draw.circle(surf, (*accent, ba_dim), (amx, amy), int(2 * sc))

        # 안쪽 대칭 아치 (거울 반사)
        inner_arch_pts = []
        for ai in range(9):
            t = ai / 8.0
            a_ang = ang1 + (ang2 - ang1) * t
            bulge = math.sin(t * math.pi) * int(4 * sc)
            ar = radius - 5 - bulge
            inner_arch_pts.append((
                center + int(ar * math.cos(a_ang)),
                center + int(ar * math.sin(a_ang))
            ))
        if len(inner_arch_pts) > 1:
            pygame.draw.lines(surf, (*accent, int(ba * 0.25)), False, inner_arch_pts, 1)

    # 4d) 내부 장식 원 (이중선)
    inner_r = radius - int(10 * sc)
    pygame.draw.circle(surf, (*acc_dark, int(35 * dim_f * sel_f)), (center, center), inner_r, 1)
    pygame.draw.circle(surf, (*accent, int(18 * dim_f * sel_f)), (center, center), inner_r - int(3 * sc), 1)

    # 4e) 내부 원 위에 8방위 작은 장식 점
    for i in range(num_medallions):
        ang = math.radians(i * 360 / num_medallions + 22.5) + angle
        dx = center + int(inner_r * math.cos(ang))
        dy = center + int(inner_r * math.sin(ang))
        pygame.draw.circle(surf, (*accent, int(60 * dim_f * sel_f)), (dx, dy), int(2 * sc))

    # ── 5) 선택 시 회전 장식 ──
    if is_selected and not dimmed and glow > 0.1:
        spin = anim_t * 0.8
        for i in range(12):
            da = math.radians(i * 30) + spin
            dr = radius + int(16 * sc)
            dpx = center + int(dr * math.cos(da))
            dpy = center + int(dr * math.sin(da))
            dot_a = int(80 * glow * (0.5 + 0.5 * math.sin(anim_t * 2.5 + i * 0.5)))
            pygame.draw.circle(surf, (*accent, dot_a), (dpx, dpy), 1)

    # ── X축 3D 회전 (수평 스케일링으로 시뮬레이션) ──
    x_scale = abs(math.cos(flip_angle))
    if x_scale < 0.05:
        x_scale = 0.05  # 완전히 사라지지 않게
    if x_scale < 0.99:
        scaled_w = max(1, int(surf_size * x_scale))
        scaled_surf = pygame.transform.smoothscale(surf, (scaled_w, surf_size))
        screen.blit(scaled_surf, (cx - scaled_w // 2, cy - surf_size // 2))
    else:
        screen.blit(surf, (cx - surf_size // 2, cy - surf_size // 2))

    # ── 라벨 ──
    label_font = ctx.FontStyle.body()
    lc = (255, 255, 255) if not dimmed else (120, 120, 120)
    ls = label_font.render(label, True, lc)
    screen.blit(ls, ls.get_rect(center=(cx, cy + radius + 25)))
    sub_font = ctx.FontStyle.tiny()
    sc = (180, 190, 210) if not dimmed else (90, 90, 100)
    ss = sub_font.render(sublabel, True, sc)
    screen.blit(ss, ss.get_rect(center=(cx, cy + radius + 50)))

    if is_selected and not dimmed:
        _menu_draw_hover_border(screen, cx - radius - 2, cy - radius - 2, radius * 2 + 4, radius * 2 + 4, accent)

    return pygame.Rect(cx - radius, cy - radius, radius * 2, radius * 2)


def _show_mode_selection(ctx: "MenuContext", state: "MenuState") -> bool:
    """모드 선택 화면 — 3D 카드, 플라즈마 테두리, 광택 스윕, 마우스 파티클, 타이틀 고스트."""
    global _mode_entry_timer, _mode_entry_done, _mode_card_flash
    global _mode_mouse_trail, _mode_bg_energy_particles

    # 입장 버튼 클릭 사운드 재생
    try:
        import os as _os
        _sp = ctx.resource_path(_os.path.join("sounds", "startbutton.wav"))
        if _os.path.exists(_sp):
            _snd = pygame.mixer.Sound(_sp)
            _snd.set_volume(0.7)
            _snd.play()
    except Exception:
        pass

    # 하트 비 트랜지션 재생
    _play_rainbow_transition(ctx.get_screen(), 1000)

    selected = 0  # 0=아케이드, 1=투기장
    prev_selected = -1  # 선택 전환 감지
    hover_scales = [1.0, 1.0]
    clock = pygame.time.Clock()
    click_anim = None  # {"card": idx, "timer": 0, "dur": 0.3}

    CARD_W, CARD_H = 270, 340  # 약간 크게
    GAP = 32

    # 진입 애니메이션 초기화
    _mode_entry_timer = 0.0
    _mode_entry_done = False
    _mode_card_flash = [0.0, 0.0]
    _mode_card_tilt_y[0] = 0.0
    _mode_card_tilt_y[1] = 0.0
    _mode_card_tilt_x[0] = 0.0
    _mode_card_tilt_x[1] = 0.0
    _mode_shine_offset[0] = 0.0
    _mode_shine_offset[1] = 0.0
    _mode_mouse_trail.clear()
    _mode_bg_energy_particles.clear()

    # 미리보기 이미지 로드
    import os
    story_preview = _load_mode_preview(
        os.path.join("ui", "story.PNG"), ctx.resource_path)
    arena_preview = _load_mode_preview(
        os.path.join("ui", "arena.jpg"), ctx.resource_path)

    _loc = get_localization_manager()
    cards_info = [
        {"title": _loc.get_text("mode.arcade", "아케이드"), "subtitle": _loc.get_text("mode.arcade_desc", "보스를 쓰러트려라!"),
         "top": (26, 26, 62), "bot": (58, 26, 94), "accent": (0, 200, 255), "icon": "VS",
         "preview": story_preview},
        {"title": _loc.get_text("mode.colosseum", "투기장"), "subtitle": _loc.get_text("mode.colosseum_desc", "최강의 영웅은 누구?"),
         "top": (62, 26, 26), "bot": (62, 58, 26), "accent": (255, 200, 80), "icon": "PVP",
         "preview": arena_preview},
    ]

    # 배경 에너지 파티클 테마 색상
    bg_accents = [(0, 200, 255), (255, 200, 80), (100, 150, 255), (255, 150, 100)]

    while True:
        dt = clock.tick(60) / 1000.0
        state.animation_timer += dt
        screen = ctx.get_screen()
        width, height = ctx.get_dimensions()

        # ── 진입 애니메이션 타이머 ──
        if not _mode_entry_done:
            _mode_entry_timer += dt
            if _mode_entry_timer >= 0.6:
                _mode_entry_done = True

        # ── 선택 전환 플래시 ──
        if prev_selected != selected:
            if prev_selected >= 0:
                _mode_card_flash[selected] = 1.0  # 새로 선택된 카드 플래시
            prev_selected = selected
        for fi in range(2):
            _mode_card_flash[fi] = max(0.0, _mode_card_flash[fi] - dt * 4.0)

        # 기본 배경 렌더링
        _update_background_layers(ctx, state, dt, screen, width, height)

        # 짙은 오버레이 (약간 푸른빛)
        ov = pygame.Surface((width, height), pygame.SRCALPHA)
        ov.fill((8, 12, 25, 190))
        screen.blit(ov, (0, 0))

        # ── 배경 에너지 파티클 ──
        _mode_update_bg_energy(dt, width, height, bg_accents)
        _mode_draw_bg_energy(screen)

        # ── 배경 글리치 ──
        _mode_draw_bg_glitch(screen, width, height, state.animation_timer)

        # ── 마우스 궤적 파티클 ──
        _mode_update_mouse_trail(dt, width, height)

        # 클릭 애니메이션 업데이트
        if click_anim is not None:
            click_anim["timer"] += dt
            if click_anim["timer"] >= click_anim["dur"]:
                chosen = click_anim["card"]
                click_anim = None
                if chosen == 0:
                    # 아케이드 - 기존 플로우
                    character = ctx.show_character_selection()
                    if character == "__TUTORIAL__":
                        ctx.set_tutorial_mode(True)
                        ctx.start_game_with_difficulty("ufo_player", "junior")
                        return True
                    if character is not None:
                        difficulty = ctx.show_difficulty_selection()
                        if difficulty is not None:
                            ctx.set_tutorial_mode(False)
                            ctx.start_game_with_difficulty(character, difficulty)
                    return True
                else:
                    # 투기장 하위 선택
                    result = _show_arena_sub_selection(ctx, state)
                    if result:
                        return True
                    # 돌아오면 계속 루프
                    continue

        # 이벤트 처리
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit
            if ev.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN, pygame.MOUSEMOTION):
                state.idle_start_time = pygame.time.get_ticks()

            if click_anim is not None:
                continue  # 애니메이션 중 입력 무시

            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    return False
                if ev.key in (pygame.K_LEFT, pygame.K_a):
                    if selected != 0:
                        selected = 0
                        ctx.play_hover_sound()
                elif ev.key in (pygame.K_RIGHT, pygame.K_d):
                    if selected != 1:
                        selected = 1
                        ctx.play_hover_sound()
                elif ev.key in (pygame.K_RETURN, pygame.K_SPACE):
                    ctx.play_click_sound()
                    if selected == 1:
                        # 투기장 → 즉시 하위 선택으로
                        result = _show_arena_sub_selection(ctx, state)
                        if result:
                            return True
                    else:
                        click_anim = {"card": selected, "timer": 0.0, "dur": 0.3}

            if ev.type == pygame.MOUSEMOTION:
                mx, my = ev.pos
                total_w = CARD_W * 2 + GAP
                sx = (width - total_w) // 2
                cy = (height - CARD_H) // 2 + 20
                for i in range(2):
                    rx = sx + i * (CARD_W + GAP)
                    if pygame.Rect(rx, cy, CARD_W, CARD_H).collidepoint(mx, my):
                        if selected != i:
                            selected = i
                            ctx.play_hover_sound()

            if ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mx, my = ev.pos
                total_w = CARD_W * 2 + GAP
                sx = (width - total_w) // 2
                cy = (height - CARD_H) // 2 + 20
                for i in range(2):
                    rx = sx + i * (CARD_W + GAP)
                    if pygame.Rect(rx, cy, CARD_W, CARD_H).collidepoint(mx, my):
                        selected = i
                        ctx.play_click_sound()
                        if i == 1:
                            # 투기장 → 즉시 하위 선택으로
                            result = _show_arena_sub_selection(ctx, state)
                            if result:
                                return True
                        else:
                            click_anim = {"card": i, "timer": 0.0, "dur": 0.3}

        # 호버 스케일 업데이트
        for i in range(2):
            target = 1.07 if i == selected else 0.97  # 비선택 카드 약간 축소
            if click_anim and click_anim["card"] == i:
                prog = click_anim["timer"] / click_anim["dur"]
                target = 1.07 + 0.15 * prog  # 클릭 시 더 확대
            hover_scales[i] += (target - hover_scales[i]) * min(1.0, 8.0 * dt)

        # ── 카드 그리기 ──
        total_w = CARD_W * 2 + GAP
        start_x = (width - total_w) // 2
        base_card_y = (height - CARD_H) // 2 + 20
        card_rects = []

        for i, info in enumerate(cards_info):
            cx = start_x + i * (CARD_W + GAP)

            # 부유 애니메이션
            y_off = math.sin(state.animation_timer * 1.5 + i * math.pi) * 4

            # 진입 애니메이션: 아래에서 바운스하며 올라옴
            if not _mode_entry_done:
                entry_t = min(1.0, _mode_entry_timer / 0.5)
                # 각 카드에 약간의 딜레이 (i * 0.08초)
                card_entry_t = max(0.0, min(1.0, (_mode_entry_timer - i * 0.08) / 0.45))
                # cubic ease-out + 약간의 오버슈트
                ease = 1.0 - (1.0 - card_entry_t) ** 3
                if card_entry_t > 0.7:
                    # 살짝 위로 갔다가 내려오는 바운스
                    bounce = math.sin((card_entry_t - 0.7) / 0.3 * math.pi) * 8
                else:
                    bounce = 0
                entry_offset = (1.0 - ease) * (height + 50) - bounce
                y_off += entry_offset

                # 진입 중 초기 스케일 (작게 → 크게)
                if card_entry_t < 1.0:
                    hover_scales[i] = 0.85 + 0.15 * card_entry_t

            rect = _draw_mode_card(
                screen, cx, base_card_y, CARD_W, CARD_H,
                info["title"], info["subtitle"],
                info["top"], info["bot"], info["accent"], info["icon"],
                i == selected, hover_scales[i], y_off,
                state.animation_timer, ctx,
                preview_img=info.get("preview"),
                card_index=i,
                flash_intensity=_mode_card_flash[i],
            )
            card_rects.append(rect)

        # ── 마우스 궤적 파티클 (카드 위에 그리기) ──
        _mode_draw_mouse_trail(screen)

        # ── 타이틀 (고스트 잔상 + 네온 글로우) ──
        title_font = ctx.FontStyle.title()
        _loc = get_localization_manager()
        title_text = _loc.get_text("mode.select", "모드 선택")

        # 선택된 카드 테마에 맞춰 타이틀 색상 변화
        sel_accent = cards_info[selected]["accent"]
        _mode_draw_title_ghost(screen, title_font, title_text,
                               (width // 2, 100), state.animation_timer, sel_accent)

        # 서브타이틀 (네온 깜빡임 효과)
        sub_font = ctx.FontStyle.tiny()
        sub_text = _loc.get_text("mode.select_desc", "플레이할 모드를 선택하세요")
        sub_alpha = int(200 + 55 * math.sin(state.animation_timer * 4.0))
        sub_color = (
            max(0, min(255, 100 + int(sel_accent[0] * 0.3))),
            max(0, min(255, 140 + int(sel_accent[1] * 0.3))),
            max(0, min(255, 180 + int(sel_accent[2] * 0.2))),
        )
        ss = sub_font.render(sub_text, True, sub_color)
        ss.set_alpha(sub_alpha)
        screen.blit(ss, ss.get_rect(center=(width // 2, 142)))

        # 구분선 (선택 테마 색상)
        line_y = 162
        line_pulse = 0.6 + 0.4 * math.sin(state.animation_timer * 3.0)
        line_alpha = int(120 * line_pulse)
        line_surf = pygame.Surface((width, 3), pygame.SRCALPHA)
        for lx in range(width // 2 - 180, width // 2 + 180):
            dist = abs(lx - width // 2) / 180.0
            la = int(line_alpha * (1.0 - dist ** 2))
            if la > 0:
                pygame.draw.line(line_surf, (*sel_accent, la), (lx, 1), (lx, 1))
        screen.blit(line_surf, (0, line_y))

        # ── 선택된 모드 설명 텍스트 (카드 하단) ──
        desc_font = ctx.FontStyle.tiny()
        if selected == 0:
            desc = _loc.get_text("mode.arcade_long_desc", "스테이지별 보스와 1:1 탁구 대결!")
        else:
            desc = _loc.get_text("mode.colosseum_long_desc", "영웅들의 토너먼트에 참가하라!")
        desc_surf = desc_font.render(desc, True, (*sel_accent, 200))
        desc_rect = desc_surf.get_rect(center=(width // 2, base_card_y + CARD_H + 55))
        # 네온 글로우 배경
        desc_glow = pygame.Surface((desc_rect.w + 40, desc_rect.h + 16), pygame.SRCALPHA)
        pygame.draw.rect(desc_glow, (*sel_accent, 15), (0, 0, desc_glow.get_width(), desc_glow.get_height()), border_radius=10)
        screen.blit(desc_glow, (desc_rect.x - 20, desc_rect.y - 8))
        screen.blit(desc_surf, desc_rect)

        # ESC 힌트
        esc = sub_font.render(_loc.get_text("menu.esc_back", "ESC: 뒤로"), True, (80, 90, 110))
        screen.blit(esc, esc.get_rect(center=(width // 2, height - 40)))

        pygame.display.flip()


def _show_arena_sub_selection(ctx: "MenuContext", state: "MenuState") -> bool:
    """투기장 하위 모드 선택 - 토너먼트 vs 도장깨기."""
    selected = 0  # 0=토너먼트, 1=도장깨기
    emblem_angles = [0.0, 0.0]
    emblem_glows = [0.0, 0.0]
    emblem_flip_angles = [0.0, 0.0]  # X축 3D 회전 각도 (라디안)
    clock = pygame.time.Clock()
    preparing_timer = 0.0  # "준비 중" 메시지 타이머
    click_anim = None

    EMBLEM_R = 90
    GAP = 40

    _loc = get_localization_manager()
    emblems_info = [
        {"label": _loc.get_text("mode.tournament", "토너먼트"), "sublabel": _loc.get_text("mode.tournament_desc", "8인 토너먼트 대전"),
         "color": (80, 60, 20), "accent": (255, 215, 0), "icon": "T", "dimmed": False},
        {"label": _loc.get_text("mode.dojo", "도장깨기"), "sublabel": _loc.get_text("mode.dojo_desc", "끊임없는 1:1 대결"),
         "color": (20, 60, 60), "accent": (0, 200, 200), "icon": "D", "dimmed": False},
    ]

    while True:
        dt = clock.tick(60) / 1000.0
        state.animation_timer += dt
        screen = ctx.get_screen()
        width, height = ctx.get_dimensions()
        _update_background_layers(ctx, state, dt, screen, width, height)

        # 오버레이
        ov = pygame.Surface((width, height), pygame.SRCALPHA)
        ov.fill((0, 0, 0, 160))
        screen.blit(ov, (0, 0))

        # 클릭 애니메이션
        if click_anim is not None:
            click_anim["timer"] += dt
            if click_anim["timer"] >= click_anim["dur"]:
                chosen = click_anim["card"]
                click_anim = None
                if chosen == 0:
                    ctx.start_arena_dev()
                    return True
                elif chosen == 1:
                    # 도장깨기 준비 중
                    preparing_timer = 2.0

        # 준비 중 타이머
        if preparing_timer > 0:
            preparing_timer -= dt

        # 이벤트
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit
            if ev.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN, pygame.MOUSEMOTION):
                state.idle_start_time = pygame.time.get_ticks()

            if click_anim is not None:
                continue

            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    return False
                if ev.key in (pygame.K_LEFT, pygame.K_a):
                    if selected != 0:
                        selected = 0
                        ctx.play_hover_sound()
                elif ev.key in (pygame.K_RIGHT, pygame.K_d):
                    if selected != 1:
                        selected = 1
                        ctx.play_hover_sound()
                elif ev.key in (pygame.K_RETURN, pygame.K_SPACE):
                    if selected == 0:
                        ctx.play_click_sound()
                        click_anim = {"card": 0, "timer": 0.0, "dur": 0.3}
                    elif selected == 1:
                        # 도장깨기 준비 중
                        ctx.play_click_sound()
                        preparing_timer = 2.0

            if ev.type == pygame.MOUSEMOTION:
                mx, my = ev.pos
                total_w = EMBLEM_R * 4 + GAP
                sx = (width - total_w) // 2 + EMBLEM_R
                ey = height // 2
                for i in range(2):
                    ecx = sx + i * (EMBLEM_R * 2 + GAP)
                    if (mx - ecx) ** 2 + (my - ey) ** 2 <= EMBLEM_R ** 2:
                        if selected != i:
                            selected = i
                            ctx.play_hover_sound()

            if ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mx, my = ev.pos
                total_w = EMBLEM_R * 4 + GAP
                sx = (width - total_w) // 2 + EMBLEM_R
                ey = height // 2
                for i in range(2):
                    ecx = sx + i * (EMBLEM_R * 2 + GAP)
                    if (mx - ecx) ** 2 + (my - ey) ** 2 <= EMBLEM_R ** 2:
                        selected = i
                        ctx.play_click_sound()
                        if i == 1:
                            # 도장깨기 준비 중
                            preparing_timer = 2.0
                        else:
                            click_anim = {"card": i, "timer": 0.0, "dur": 0.3}

        # 엠블럼 애니메이션 업데이트
        for i in range(2):
            if i == selected and not emblems_info[i]["dimmed"]:
                emblem_angles[i] = math.sin(state.animation_timer * 2.5) * 0.08
                emblem_glows[i] += (1.0 - emblem_glows[i]) * min(1.0, 6.0 * dt)
                # 호버 시 X축 회전 (천천히 360도 반복)
                emblem_flip_angles[i] += dt * 1.8  # ~3.5초에 1회전
            else:
                emblem_angles[i] *= 0.9
                emblem_glows[i] += (0.0 - emblem_glows[i]) * min(1.0, 6.0 * dt)
                # 비호버 시 가장 가까운 0도(정면)로 부드럽게 복귀
                cur = emblem_flip_angles[i] % (math.pi * 2)
                if cur > 0.05:
                    # 가까운 쪽(0 또는 2pi)으로 이동
                    if cur < math.pi:
                        emblem_flip_angles[i] -= dt * 3.0
                        if emblem_flip_angles[i] % (math.pi * 2) > cur:
                            emblem_flip_angles[i] = 0.0
                    else:
                        emblem_flip_angles[i] += dt * 3.0
                else:
                    emblem_flip_angles[i] = 0.0

        # 엠블럼 그리기
        total_w = EMBLEM_R * 4 + GAP
        start_cx = (width - total_w) // 2 + EMBLEM_R
        emblem_cy = height // 2

        for i, info in enumerate(emblems_info):
            ecx = start_cx + i * (EMBLEM_R * 2 + GAP)
            _draw_arena_emblem(
                screen, ecx, emblem_cy, EMBLEM_R,
                info["label"], info["sublabel"],
                info["color"], info["accent"], info["icon"],
                i == selected, emblem_angles[i], emblem_glows[i],
                state.animation_timer, ctx, dimmed=info["dimmed"],
                flip_angle=emblem_flip_angles[i],
            )

        # 타이틀
        title_font = ctx.FontStyle.title_large()
        ts = title_font.render(_loc.get_text("mode.colosseum", "투기장"), True, (255, 220, 100))
        screen.blit(ts, ts.get_rect(center=(width // 2, 120)))
        sub_font = ctx.FontStyle.tiny()
        ss = sub_font.render(_loc.get_text("mode.select_mode", "모드를 선택하세요"), True, (180, 170, 140))
        screen.blit(ss, ss.get_rect(center=(width // 2, 158)))

        # "준비 중입니다" 토스트 메시지
        if preparing_timer > 0:
            _toast_alpha = min(255, int(preparing_timer * 255))
            _toast_font = ctx.FontStyle.body()
            _toast_surf = _toast_font.render(_loc.get_text("menu.preparing", "준비 중입니다"), True, (255, 200, 100))
            _toast_bg = pygame.Surface((_toast_surf.get_width() + 30, _toast_surf.get_height() + 16), pygame.SRCALPHA)
            pygame.draw.rect(_toast_bg, (30, 30, 30, min(200, _toast_alpha)),
                             (0, 0, _toast_bg.get_width(), _toast_bg.get_height()), border_radius=8)
            pygame.draw.rect(_toast_bg, (255, 180, 0, min(180, _toast_alpha)),
                             (0, 0, _toast_bg.get_width(), _toast_bg.get_height()), width=2, border_radius=8)
            _toast_bg.blit(_toast_surf, (15, 8))
            _toast_bg.set_alpha(_toast_alpha)
            screen.blit(_toast_bg, (_toast_bg.get_rect(center=(width // 2, height - 100))))

        # ESC 힌트
        esc = sub_font.render(_loc.get_text("menu.esc_back", "ESC: 뒤로"), True, (100, 110, 130))
        screen.blit(esc, esc.get_rect(center=(width // 2, height - 50)))

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

    # === 페이드아웃 효과 (검은 화면으로 전환) ===
    fade_duration = 500  # 0.5초 페이드아웃
    fade_start = pygame.time.get_ticks()

    # 현재 화면 캡처 (페이드아웃 시작점)
    fade_surface = screen.copy()

    while True:
        fade_elapsed = pygame.time.get_ticks() - fade_start
        fade_progress = min(1.0, fade_elapsed / fade_duration)

        if fade_elapsed >= fade_duration:
            break

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                # ESC로 스킵 시 즉시 검은 화면
                screen.fill((0, 0, 0))
                pygame.display.flip()
                return

        # 캡처된 화면 그리기
        screen.blit(fade_surface, (0, 0))

        # 검은 오버레이 (점점 어두워짐)
        fade_alpha = int(255 * fade_progress)
        fade_overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        fade_overlay.fill((0, 0, 0, fade_alpha))
        screen.blit(fade_overlay, (0, 0))

        pygame.display.flip()
        clock.tick(60)

    # 완전히 검은 화면으로 마무리
    screen.fill((0, 0, 0))
    pygame.display.flip()


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


def _show_settings_screen(ctx: MenuContext, state: MenuState) -> None:
    """메인 메뉴 설정 화면 - 볼륨/조작 설정 (show_pause_options 패턴 기반)"""
    import bgm_manager as _bgm_mod
    from game_state.audio import (
        clamp_volume, get_bgm_muted, set_bgm_muted,
        get_sfx_muted, set_sfx_muted, resolve_runtime_bgm_volume,
        set_bgm_volume, set_sfx_volume,
    )
    from config.settings_system import get_settings_manager

    _loc = get_localization_manager()
    def _t(key: str, fallback: str) -> str:
        return _loc.get_text(key, fallback)

    clock = pygame.time.Clock()
    bgm_mgr = getattr(_bgm_mod, "bgm_manager", None)
    settings = get_settings_manager()

    # 현재 값 읽기
    current_bgm_volume = clamp_volume(
        resolve_runtime_bgm_volume(bgm_mgr, 0.4)
    )
    current_sfx_volume = clamp_volume(
        settings.get_setting("audio", "sfx_volume", 0.7)
    )
    bgm_muted = get_bgm_muted()
    sfx_muted = get_sfx_muted()
    control_scheme = settings.get_setting("controls", "control_scheme", "keyboard")
    paddle_hit_sound = int(settings.get_setting("audio", "paddle_hit_sound", 1))
    ball_type = settings.get_setting("gameplay", "ball_type", "energy")
    current_language = settings.get_setting("language", "language", "ko")
    _loc.set_language(current_language)  # 폰트 언어 동기화 (ja/zh → CJK 폰트)

    # 패들 타격 사운드 프리로드
    _paddle_sounds = {}
    try:
        from sound_effects import SOUND_PATHS
        for _sk in ("PADDLE", "PADDLE2", "PADDLE3"):
            _rp = SOUND_PATHS.get(_sk)
            if _rp:
                _paddle_sounds[_sk] = pygame.mixer.Sound(ctx.resource_path(_rp))
    except Exception as _e:
        print(f"[WARN] paddle sound preload: {_e}")

    # 폰트
    font_medium = ctx.FontStyle.body()
    font_small = ctx.FontStyle.small()
    font_tiny = ctx.FontStyle.tiny()

    # 디스플레이 모드 상태
    try:
        from pingfighter import get_display_mode as _get_dm
        display_mode = _get_dm()
        if display_mode in ("borderless", "large_windowed"):
            display_mode = "windowed"  # 보더리스/큰창모드 제거됨 → 창모드로 폴백
        # fullscreen은 '전체화면'로 유지
    except Exception:
        display_mode = "windowed"

    # 상태
    current_tab = "sound"
    focus = "bgm"  # bgm / sfx / hitsound / back (sound) | scheme / back (controls) | dispmode / back (display)
    selected_slider = None
    dragging = False
    hit_pills = []
    ball_pills = []
    lang_pills = []

    running = True
    while running:
        dt = clock.tick(60) / 1000.0
        state.animation_timer += dt

        screen = ctx.get_screen()
        width, height = ctx.get_dimensions()

        # 메뉴 배경 렌더링
        _update_background_layers(ctx, state, dt, screen, width, height)
        pillar_renderer = get_pillar_renderer()
        if pillar_renderer is not None:
            pillar_renderer.update(dt)

        # 반투명 오버레이
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        screen.blit(overlay, (0, 0))

        # ─── 패널 ───
        panel_width = min(600, max(500, int(width * 0.82)))
        panel_height = 340 if current_tab == "sound" else 300
        panel_x = (width - panel_width) // 2
        panel_y = (height - panel_height) // 2

        panel = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        pygame.draw.rect(panel, (28, 30, 40, 230), (0, 0, panel_width, panel_height), border_radius=12)
        pygame.draw.rect(panel, (0, 200, 255, 200), (1, 1, panel_width - 2, panel_height - 2), 2, border_radius=10)
        pygame.draw.rect(panel, (38, 50, 70, 230), (0, 0, panel_width, 60), border_radius=10)
        pygame.draw.line(panel, (0, 200, 255, 180), (14, 60), (panel_width - 14, 60), 2)
        screen.blit(panel, (panel_x, panel_y))

        # ─── 탭 (동적 너비 — CJK 오버플로우 방지) ───
        tab_h = 36
        tab_gap = 6
        tabs_y = panel_y + 12
        _tab_labels = [
            _t("settings.tab.sound", "사운드"),
            _t("settings.tab.controls", "컨트롤"),
            _t("settings.tab.display", "디스플레이"),
            _t("settings.tab.play", "플레이"),
            _t("settings.tab.language", "언어"),
        ]
        _max_tw = max(font_small.size(lbl)[0] for lbl in _tab_labels)
        tab_w = max(85, _max_tw + 20)
        # 패널 초과 시 축소
        if tab_w * 5 + tab_gap * 4 + 32 > panel_width:
            tab_w = (panel_width - 32 - tab_gap * 4) // 5
        sound_tab_rect = pygame.Rect(panel_x + 16, tabs_y, tab_w, tab_h)
        ctrl_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap), tabs_y, tab_w, tab_h)
        disp_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap) * 2, tabs_y, tab_w, tab_h)
        play_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap) * 3, tabs_y, tab_w, tab_h)
        lang_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap) * 4, tabs_y, tab_w, tab_h)

        for tab_rect, label, active in [
            (sound_tab_rect, _t("settings.tab.sound", "사운드"), current_tab == "sound"),
            (ctrl_tab_rect, _t("settings.tab.controls", "컨트롤"), current_tab == "controls"),
            (disp_tab_rect, _t("settings.tab.display", "디스플레이"), current_tab == "display"),
            (play_tab_rect, _t("settings.tab.play", "플레이"), current_tab == "play"),
            (lang_tab_rect, _t("settings.tab.language", "언어"), current_tab == "language"),
        ]:
            base = (70, 100, 140) if active else (50, 60, 80)
            pygame.draw.rect(screen, base, tab_rect, border_radius=8)
            pygame.draw.rect(screen, (0, 255, 255) if active else (140, 180, 220), tab_rect, 2, border_radius=8)
            t = font_small.render(label, True, (255, 255, 255))
            screen.blit(t, t.get_rect(center=tab_rect.center))

        # ─── 컨텐츠 영역 ───
        margin_x = 29
        label_w = 140
        slider_width = max(200, panel_width - margin_x * 2 - label_w - 120)
        slider_x = panel_x + margin_x + label_w
        slider_height = 10
        handle_size = 14
        checkbox_size = 20

        content_y = panel_y + 80

        if current_tab == "sound":
            # ── BGM 볼륨 ──
            bgm_y = content_y + 20
            bgm_label = font_medium.render(_t("settings.sound.bgm", "BGM 볼륨"), True, (255, 255, 255))
            screen.blit(bgm_label, bgm_label.get_rect(left=panel_x + margin_x, centery=bgm_y + slider_height // 2))

            # BGM 슬라이더 트랙
            pygame.draw.rect(screen, (64, 66, 76), (slider_x, bgm_y, slider_width, slider_height), border_radius=6)
            fill_color = (100, 100, 100) if bgm_muted else (0, 200, 255)
            pygame.draw.rect(screen, fill_color, (slider_x, bgm_y, int(slider_width * current_bgm_volume), slider_height), border_radius=6)

            # BGM 핸들
            bgm_handle_x = slider_x + int(slider_width * current_bgm_volume)
            bgm_handle_rect = pygame.Rect(bgm_handle_x - handle_size // 2, bgm_y - (handle_size - slider_height) // 2, handle_size, handle_size)
            pygame.draw.circle(screen, (255, 255, 255) if (selected_slider == "bgm" or focus == "bgm") else (210, 210, 210),
                               (bgm_handle_x, bgm_y + slider_height // 2), handle_size // 2)

            # BGM 퍼센트
            bgm_pct_color = (100, 100, 100) if bgm_muted else (0, 200, 255)
            bgm_pct = font_small.render(f"{int(current_bgm_volume * 100)}%", True, bgm_pct_color)
            screen.blit(bgm_pct, bgm_pct.get_rect(left=slider_x + slider_width + 12, centery=bgm_y + slider_height // 2))

            # BGM 음소거 체크박스
            bgm_cb_x = slider_x + slider_width + 60
            bgm_cb_y = bgm_y + slider_height // 2 - checkbox_size // 2
            bgm_checkbox_rect = pygame.Rect(bgm_cb_x, bgm_cb_y, checkbox_size, checkbox_size)
            pygame.draw.rect(screen, (80, 80, 100), bgm_checkbox_rect, border_radius=4)
            pygame.draw.rect(screen, (0, 200, 255) if bgm_muted else (150, 150, 150), bgm_checkbox_rect, 2, border_radius=4)
            if bgm_muted:
                pygame.draw.line(screen, (255, 80, 80), (bgm_cb_x + 4, bgm_cb_y + 4), (bgm_cb_x + checkbox_size - 4, bgm_cb_y + checkbox_size - 4), 3)
                pygame.draw.line(screen, (255, 80, 80), (bgm_cb_x + checkbox_size - 4, bgm_cb_y + 4), (bgm_cb_x + 4, bgm_cb_y + checkbox_size - 4), 3)
            mute_lbl = font_small.render("OFF", True, (255, 80, 80) if bgm_muted else (120, 120, 120))
            screen.blit(mute_lbl, (bgm_cb_x + checkbox_size + 5, bgm_cb_y + 2))

            # ── 효과음 볼륨 ──
            sfx_y = content_y + 70
            sfx_label = font_medium.render(_t("settings.sound.sfx", "효과음 볼륨"), True, (255, 255, 255))
            screen.blit(sfx_label, sfx_label.get_rect(left=panel_x + margin_x, centery=sfx_y + slider_height // 2))

            pygame.draw.rect(screen, (64, 66, 76), (slider_x, sfx_y, slider_width, slider_height), border_radius=6)
            sfx_fill = (100, 100, 100) if sfx_muted else (0, 255, 100)
            pygame.draw.rect(screen, sfx_fill, (slider_x, sfx_y, int(slider_width * current_sfx_volume), slider_height), border_radius=6)

            sfx_handle_x = slider_x + int(slider_width * current_sfx_volume)
            sfx_handle_rect = pygame.Rect(sfx_handle_x - handle_size // 2, sfx_y - (handle_size - slider_height) // 2, handle_size, handle_size)
            pygame.draw.circle(screen, (255, 255, 255) if (selected_slider == "sfx" or focus == "sfx") else (210, 210, 210),
                               (sfx_handle_x, sfx_y + slider_height // 2), handle_size // 2)

            sfx_pct_color = (100, 100, 100) if sfx_muted else (0, 255, 100)
            sfx_pct = font_small.render(f"{int(current_sfx_volume * 100)}%", True, sfx_pct_color)
            screen.blit(sfx_pct, sfx_pct.get_rect(left=slider_x + slider_width + 12, centery=sfx_y + slider_height // 2))

            sfx_cb_x = slider_x + slider_width + 60
            sfx_cb_y = sfx_y + slider_height // 2 - checkbox_size // 2
            sfx_checkbox_rect = pygame.Rect(sfx_cb_x, sfx_cb_y, checkbox_size, checkbox_size)
            pygame.draw.rect(screen, (80, 80, 100), sfx_checkbox_rect, border_radius=4)
            pygame.draw.rect(screen, (0, 255, 100) if sfx_muted else (150, 150, 150), sfx_checkbox_rect, 2, border_radius=4)
            if sfx_muted:
                pygame.draw.line(screen, (255, 80, 80), (sfx_cb_x + 4, sfx_cb_y + 4), (sfx_cb_x + checkbox_size - 4, sfx_cb_y + checkbox_size - 4), 3)
                pygame.draw.line(screen, (255, 80, 80), (sfx_cb_x + checkbox_size - 4, sfx_cb_y + 4), (sfx_cb_x + 4, sfx_cb_y + checkbox_size - 4), 3)
            sfx_mute_lbl = font_small.render("OFF", True, (255, 80, 80) if sfx_muted else (120, 120, 120))
            screen.blit(sfx_mute_lbl, (sfx_cb_x + checkbox_size + 5, sfx_cb_y + 2))

        elif current_tab == "controls":
            scheme_y = content_y + 20
            scheme_label = font_medium.render(_t("settings.controls.label", "조작 방식"), True, (255, 255, 255))
            screen.blit(scheme_label, (panel_x + margin_x, scheme_y))

            _ctrl_labels = [_t("settings.controls.keyboard_only", "키보드만"), _t("settings.controls.mouse_keyboard", "마우스+키보드")]
            _max_cw = max(font_small.size(lbl)[0] for lbl in _ctrl_labels)
            pill_w = max(160, _max_cw + 30)
            pill_h = 36
            kb_rect = pygame.Rect(slider_x, scheme_y - 8, pill_w, pill_h)
            mk_rect = pygame.Rect(slider_x + pill_w + 14, scheme_y - 8, pill_w + 20, pill_h)
            for rect, label, is_sel in [
                (kb_rect, _t("settings.controls.keyboard_only", "키보드만"), control_scheme == "keyboard"),
                (mk_rect, _t("settings.controls.mouse_keyboard", "마우스+키보드"), control_scheme == "mouse_keyboard"),
            ]:
                col = (60, 90, 130) if is_sel else (45, 55, 70)
                pygame.draw.rect(screen, col, rect, border_radius=18)
                pygame.draw.rect(screen, (0, 255, 255) if is_sel else (150, 150, 150), rect, 2, border_radius=18)
                s = font_small.render(label, True, (255, 255, 255))
                screen.blit(s, s.get_rect(center=rect.center))

        elif current_tab == "play":
            # ── 공 선택 ──
            ball_sel_y = content_y + 20
            ball_sel_label = font_medium.render(_t("settings.play.ball_label", "공 선택"), True, (255, 255, 255))
            screen.blit(ball_sel_label, ball_sel_label.get_rect(left=panel_x + margin_x, centery=ball_sel_y + 16))

            _bt_names = {"energy": _t("settings.play.ball_energy", "에너지볼"), "pingpong": _t("settings.play.ball_pingpong", "탁구공")}
            _max_bw = max(font_small.size(lbl)[0] for lbl in _bt_names.values())
            pill_w_b = max(110, _max_bw + 24)
            pill_h_b = 32
            pill_gap_b = 10
            ball_pills = []
            for i, (val, lbl) in enumerate(_bt_names.items()):
                px = slider_x + i * (pill_w_b + pill_gap_b)
                py = ball_sel_y + 2
                r = pygame.Rect(px, py, pill_w_b, pill_h_b)
                ball_pills.append((r, val, lbl))
                is_sel = (ball_type == val)
                col = (60, 90, 130) if is_sel else (45, 55, 70)
                pygame.draw.rect(screen, col, r, border_radius=16)
                border_col = (0, 255, 255) if is_sel else (150, 150, 150)
                if focus == "balltype" and is_sel:
                    border_col = (0, 255, 255)
                pygame.draw.rect(screen, border_col, r, 2, border_radius=16)
                s = font_small.render(lbl, True, (255, 255, 255))
                screen.blit(s, s.get_rect(center=r.center))

            # 공 설명
            _bt_descs = {
                "energy": _t("settings.play.ball_energy_desc", "속도에 따라 색상과 이펙트가 변합니다"),
                "pingpong": _t("settings.play.ball_pingpong_desc", "탁구공 이미지, 이펙트 없음"),
            }
            bt_desc = font_tiny.render(_bt_descs.get(ball_type, ""), True, (150, 180, 200))
            screen.blit(bt_desc, bt_desc.get_rect(centerx=width // 2, top=ball_sel_y + 44))

            # ── 타격 사운드 (에너지볼일 때만 활성) ──
            _hs_disabled = (ball_type == "pingpong")
            hit_y = ball_sel_y + 70
            _hs_label_col = (100, 100, 100) if _hs_disabled else (255, 255, 255)
            hit_label = font_medium.render(_t("settings.play.hitsound_label", "타격 사운드"), True, _hs_label_col)
            screen.blit(hit_label, hit_label.get_rect(left=panel_x + margin_x, centery=hit_y + 18))

            _hs_names = {1: _t("settings.play.sound_1", "사운드 1"), 2: _t("settings.play.sound_2", "사운드 2"), 3: _t("settings.play.sound_3", "사운드 3")}
            _max_hw = max(font_small.size(lbl)[0] for lbl in _hs_names.values())
            pill_w_h = max(90, _max_hw + 24)
            pill_h_h = 32
            pill_gap_h = 8
            hit_pills = []
            for i, (val, lbl) in enumerate(_hs_names.items()):
                px = slider_x + i * (pill_w_h + pill_gap_h)
                py = hit_y + 2
                r = pygame.Rect(px, py, pill_w_h, pill_h_h)
                hit_pills.append((r, val, lbl))
                is_sel = (paddle_hit_sound == val)
                if _hs_disabled:
                    col = (35, 38, 42)
                    border_col = (70, 70, 70)
                    txt_col = (80, 80, 80)
                else:
                    col = (60, 90, 130) if is_sel else (45, 55, 70)
                    border_col = (0, 255, 255) if (is_sel and focus == "hitsound") else ((0, 255, 255) if is_sel else (150, 150, 150))
                    txt_col = (255, 255, 255)
                pygame.draw.rect(screen, col, r, border_radius=16)
                pygame.draw.rect(screen, border_col, r, 2, border_radius=16)
                s = font_small.render(lbl, True, txt_col)
                screen.blit(s, s.get_rect(center=r.center))

        elif current_tab == "display":
            disp_y = content_y + 20
            disp_label = font_medium.render(_t("settings.display.label", "화면 모드"), True, (255, 255, 255))
            screen.blit(disp_label, (panel_x + margin_x, disp_y))

            _disp_labels = [_t("settings.display.fullscreen", "전체화면"), _t("settings.display.cinema", "전체화면(저화질)"), _t("settings.display.windowed", "창모드")]
            _max_dw = max(font_small.size(lbl)[0] for lbl in _disp_labels)
            dpill_w = max(110, _max_dw + 24)
            dpill_h = 36
            _dpill_gap = 8
            fs_rect = pygame.Rect(slider_x, disp_y - 8, dpill_w, dpill_h)
            cm_rect = pygame.Rect(slider_x + dpill_w + _dpill_gap, disp_y - 8, dpill_w, dpill_h)
            win_rect = pygame.Rect(slider_x + (dpill_w + _dpill_gap) * 2, disp_y - 8, dpill_w, dpill_h)
            for rect, label, is_sel in [
                (fs_rect, _t("settings.display.fullscreen", "전체화면"), display_mode == "fullscreen"),
                (cm_rect, _t("settings.display.cinema", "전체화면(저화질)"), display_mode == "cinema"),
                (win_rect, _t("settings.display.windowed", "창모드"), display_mode == "windowed"),
            ]:
                col = (60, 90, 130) if is_sel else (45, 55, 70)
                pygame.draw.rect(screen, col, rect, border_radius=18)
                pygame.draw.rect(screen, (0, 255, 255) if is_sel else (150, 150, 150), rect, 2, border_radius=18)
                s = font_small.render(label, True, (255, 255, 255))
                screen.blit(s, s.get_rect(center=rect.center))

            # 설명 텍스트
            desc_y = disp_y + 50
            _disp_descs = {
                "fullscreen": _t("settings.display.fullscreen_desc", "네이티브 해상도 전체화면 (최고 화질)"),
                "cinema": _t("settings.display.cinema_desc", "해상도를 낮춰 성능을 높이고 화면을 꽉 채웁니다"),
                "windowed": _t("settings.display.windowed_desc", "필러 배경 포함 창모드로 표시합니다"),
            }
            desc = font_tiny.render(_disp_descs.get(display_mode, ""), True, (150, 180, 200))
            screen.blit(desc, desc.get_rect(centerx=width // 2, top=desc_y))

        elif current_tab == "language":
            lang_y = content_y + 20
            lang_label = font_medium.render(_t("settings.language.label", "언어 선택"), True, (255, 255, 255))
            screen.blit(lang_label, (panel_x + margin_x, lang_y))
            _lang_options = LANGUAGE_OPTIONS
            _lpill_w, _lpill_h = 100, 36
            _lpill_gap = 10
            lang_pills = []
            for i, (_lcode, _llabel) in enumerate(_lang_options):
                px = slider_x + i * (_lpill_w + _lpill_gap)
                py = lang_y - 8
                r = pygame.Rect(px, py, _lpill_w, _lpill_h)
                lang_pills.append((r, _lcode, _llabel))
                is_sel = (current_language == _lcode)
                col = (60, 90, 130) if is_sel else (45, 55, 70)
                pygame.draw.rect(screen, col, r, border_radius=18)
                border_col = (0, 255, 255) if is_sel else (150, 150, 150)
                pygame.draw.rect(screen, border_col, r, 2, border_radius=18)
                # ja/zh 라벨은 CJK 폰트 사용 (픽셀폰트 미지원)
                if _lcode in ("ja", "zh"):
                    from pixel_font_manager import get_cjk_font
                    _pill_font = get_cjk_font(18)
                else:
                    _pill_font = font_small
                s = _pill_font.render(_llabel, True, (255, 255, 255))
                screen.blit(s, s.get_rect(center=r.center))

        # ─── 뒤로가기 버튼 ───
        back_w, back_h = 144, 45
        back_x = panel_x + (panel_width - back_w) // 2
        back_y = panel_y + panel_height - 70
        back_rect = pygame.Rect(back_x, back_y, back_w, back_h)

        mpos = pygame.mouse.get_pos()
        button_hover = back_rect.collidepoint(mpos) or focus == "back"
        button_color = (0, 100, 150) if button_hover else (50, 50, 50)
        pygame.draw.rect(screen, button_color, back_rect, border_radius=8)
        pygame.draw.rect(screen, (0, 255, 255), back_rect, 2, border_radius=8)
        back_text = font_medium.render(_t("settings.back", "뒤로가기"), True, (255, 255, 255))
        screen.blit(back_text, back_text.get_rect(center=back_rect.center))

        # 힌트
        hint = font_tiny.render(_t("settings.hint", "TAB: 탭 전환  |  ←→: 조절  |  ESC: 뒤로"), True, (150, 180, 200))
        screen.blit(hint, hint.get_rect(center=(width // 2, panel_y + panel_height + 20)))

        pygame.display.flip()

        # ─── 이벤트 처리 ───
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                _save_menu_settings(settings, bgm_mgr, current_bgm_volume, current_sfx_volume, bgm_muted, sfx_muted, control_scheme, paddle_hit_sound, ball_type, current_language)
                pygame.quit()
                raise SystemExit

            if event.type == pygame.KEYDOWN:
                state.idle_start_time = pygame.time.get_ticks()
                if event.key == pygame.K_ESCAPE:
                    _save_menu_settings(settings, bgm_mgr, current_bgm_volume, current_sfx_volume, bgm_muted, sfx_muted, control_scheme, paddle_hit_sound, ball_type, current_language)
                    # 디스플레이 모드 변경 적용
                    try:
                        from pingfighter import switch_display_mode, get_display_mode
                        if display_mode != get_display_mode():
                            switch_display_mode(display_mode)
                    except Exception as _e:
                        print(f"[디스플레이 전환 오류] {_e}")
                    return

                if event.key == pygame.K_TAB:
                    _tab_order = ["sound", "controls", "display", "play", "language"]
                    _tab_idx = _tab_order.index(current_tab) if current_tab in _tab_order else 0
                    current_tab = _tab_order[(_tab_idx + 1) % len(_tab_order)]
                    focus = {"sound": "bgm", "controls": "scheme", "display": "dispmode", "play": "balltype", "language": "lang"}.get(current_tab, "bgm")

                if event.key == pygame.K_LEFT:
                    if current_tab == "language" and focus == "lang":
                        _li = LANGUAGE_CODES.index(current_language) if current_language in LANGUAGE_CODES else 0
                        current_language = LANGUAGE_CODES[max(0, _li - 1)]
                        _loc.set_language(current_language)
                        settings.set_setting("language", "language", current_language)
                        font_medium = ctx.FontStyle.body()
                        font_small = ctx.FontStyle.small()
                        font_tiny = ctx.FontStyle.tiny()
                    elif current_tab == "controls" and focus == "scheme":
                        control_scheme = "keyboard"
                    elif current_tab == "display" and focus == "dispmode":
                        _dm_order = ["fullscreen", "cinema", "windowed"]
                        _dm_idx = _dm_order.index(display_mode) if display_mode in _dm_order else 0
                        display_mode = _dm_order[max(0, _dm_idx - 1)]
                    elif current_tab == "sound" and focus == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume - 0.05)
                        if not bgm_muted and bgm_mgr:
                            bgm_mgr.volume = current_bgm_volume
                            pygame.mixer.music.set_volume(current_bgm_volume)
                        selected_slider = "bgm"
                    elif current_tab == "sound" and focus == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume - 0.05)
                        set_sfx_volume(current_sfx_volume)
                        selected_slider = "sfx"
                    elif current_tab == "play" and focus == "hitsound" and ball_type != "pingpong":
                        paddle_hit_sound = max(1, paddle_hit_sound - 1)
                        _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(paddle_hit_sound, "PADDLE")
                        _ps = _paddle_sounds.get(_hs_key)
                        if _ps:
                            _ps.set_volume(current_sfx_volume)
                            _ps.play()
                    elif current_tab == "play" and focus == "balltype":
                        _bt_order = ["energy", "pingpong"]
                        _bt_idx = _bt_order.index(ball_type) if ball_type in _bt_order else 0
                        ball_type = _bt_order[max(0, _bt_idx - 1)]

                elif event.key == pygame.K_RIGHT:
                    if current_tab == "language" and focus == "lang":
                        _li = LANGUAGE_CODES.index(current_language) if current_language in LANGUAGE_CODES else 0
                        current_language = LANGUAGE_CODES[min(len(LANGUAGE_CODES) - 1, _li + 1)]
                        _loc.set_language(current_language)
                        settings.set_setting("language", "language", current_language)
                        font_medium = ctx.FontStyle.body()
                        font_small = ctx.FontStyle.small()
                        font_tiny = ctx.FontStyle.tiny()
                    elif current_tab == "controls" and focus == "scheme":
                        control_scheme = "mouse_keyboard"
                    elif current_tab == "display" and focus == "dispmode":
                        _dm_order = ["fullscreen", "cinema", "windowed"]
                        _dm_idx = _dm_order.index(display_mode) if display_mode in _dm_order else 0
                        display_mode = _dm_order[min(len(_dm_order) - 1, _dm_idx + 1)]
                    elif current_tab == "sound" and focus == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume + 0.05)
                        if not bgm_muted and bgm_mgr:
                            bgm_mgr.volume = current_bgm_volume
                            pygame.mixer.music.set_volume(current_bgm_volume)
                        selected_slider = "bgm"
                    elif current_tab == "sound" and focus == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume + 0.05)
                        set_sfx_volume(current_sfx_volume)
                        selected_slider = "sfx"
                    elif current_tab == "play" and focus == "hitsound" and ball_type != "pingpong":
                        paddle_hit_sound = min(3, paddle_hit_sound + 1)
                        _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(paddle_hit_sound, "PADDLE")
                        _ps = _paddle_sounds.get(_hs_key)
                        if _ps:
                            _ps.set_volume(current_sfx_volume)
                            _ps.play()
                    elif current_tab == "play" and focus == "balltype":
                        _bt_order = ["energy", "pingpong"]
                        _bt_idx = _bt_order.index(ball_type) if ball_type in _bt_order else 0
                        ball_type = _bt_order[min(len(_bt_order) - 1, _bt_idx + 1)]

                elif event.key == pygame.K_UP:
                    if current_tab == "language":
                        order = ["lang", "back"]
                    elif current_tab == "controls":
                        order = ["scheme", "back"]
                    elif current_tab == "display":
                        order = ["dispmode", "back"]
                    elif current_tab == "play":
                        order = ["balltype", "hitsound", "back"] if ball_type != "pingpong" else ["balltype", "back"]
                    else:
                        order = ["bgm", "sfx", "back"]
                    focus = order[(order.index(focus) - 1) % len(order)] if focus in order else order[0]

                elif event.key == pygame.K_DOWN:
                    if current_tab == "language":
                        order = ["lang", "back"]
                    elif current_tab == "controls":
                        order = ["scheme", "back"]
                    elif current_tab == "display":
                        order = ["dispmode", "back"]
                    elif current_tab == "play":
                        order = ["balltype", "hitsound", "back"] if ball_type != "pingpong" else ["balltype", "back"]
                    else:
                        order = ["bgm", "sfx", "back"]
                    focus = order[(order.index(focus) + 1) % len(order)] if focus in order else order[0]

                elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                    if focus == "back":
                        ctx.play_click_sound()
                        _save_menu_settings(settings, bgm_mgr, current_bgm_volume, current_sfx_volume, bgm_muted, sfx_muted, control_scheme, paddle_hit_sound, ball_type, current_language)
                        # 디스플레이 모드 변경 적용
                        try:
                            from pingfighter import switch_display_mode, get_display_mode
                            if display_mode != get_display_mode():
                                switch_display_mode(display_mode)
                        except Exception as _e:
                            print(f"[디스플레이 전환 오류] {_e}")
                        return
                    elif current_tab == "language" and focus == "lang":
                        _li = LANGUAGE_CODES.index(current_language) if current_language in LANGUAGE_CODES else 0
                        current_language = LANGUAGE_CODES[(_li + 1) % len(LANGUAGE_CODES)]
                        _loc.set_language(current_language)
                        settings.set_setting("language", "language", current_language)
                        font_medium = ctx.FontStyle.body()
                        font_small = ctx.FontStyle.small()
                        font_tiny = ctx.FontStyle.tiny()
                    elif current_tab == "display" and focus == "dispmode":
                        _dm_order = ["fullscreen", "cinema", "windowed"]
                        _dm_idx = _dm_order.index(display_mode) if display_mode in _dm_order else 0
                        display_mode = _dm_order[(_dm_idx + 1) % len(_dm_order)]
                    elif current_tab == "controls" and focus == "scheme":
                        control_scheme = "mouse_keyboard" if control_scheme == "keyboard" else "keyboard"
                    elif current_tab == "sound" and focus == "bgm":
                        bgm_muted = not bgm_muted
                        set_bgm_muted(bgm_muted)
                        if bgm_muted:
                            pygame.mixer.music.set_volume(0)
                        elif bgm_mgr:
                            bgm_mgr.volume = current_bgm_volume
                            pygame.mixer.music.set_volume(current_bgm_volume)
                    elif current_tab == "sound" and focus == "sfx":
                        sfx_muted = not sfx_muted
                        set_sfx_muted(sfx_muted)
                    elif current_tab == "play" and focus == "hitsound" and ball_type != "pingpong":
                        paddle_hit_sound = (paddle_hit_sound % 3) + 1
                        _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(paddle_hit_sound, "PADDLE")
                        _ps = _paddle_sounds.get(_hs_key)
                        if _ps:
                            _ps.set_volume(current_sfx_volume)
                            _ps.play()
                    elif current_tab == "play" and focus == "balltype":
                        ball_type = "pingpong" if ball_type == "energy" else "energy"

            elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                state.idle_start_time = pygame.time.get_ticks()
                mp = event.pos

                # 탭 클릭
                if sound_tab_rect.collidepoint(mp):
                    current_tab = "sound"
                    focus = "bgm"
                    continue
                if ctrl_tab_rect.collidepoint(mp):
                    current_tab = "controls"
                    focus = "scheme"
                    continue
                if disp_tab_rect.collidepoint(mp):
                    current_tab = "display"
                    focus = "dispmode"
                    continue
                if play_tab_rect.collidepoint(mp):
                    current_tab = "play"
                    focus = "balltype"
                    continue
                if lang_tab_rect.collidepoint(mp):
                    current_tab = "language"
                    focus = "lang"
                    continue

                # 언어 탭 - 언어 pill 클릭
                if current_tab == "language":
                    for _lr, _lc, _ll in lang_pills:
                        if _lr.collidepoint(mp):
                            current_language = _lc
                            _loc.set_language(current_language)
                            settings.set_setting("language", "language", current_language)
                            font_medium = ctx.FontStyle.body()
                            font_small = ctx.FontStyle.small()
                            font_tiny = ctx.FontStyle.tiny()
                            focus = "lang"
                            break

                # 플레이 탭 - 공 선택 및 타격 사운드 클릭
                if current_tab == "play":
                    for _br, _bv, _bl in ball_pills:
                        if _br.collidepoint(mp):
                            ball_type = _bv
                            focus = "balltype"
                            break
                    if ball_type != "pingpong":
                        for _hr, _hv, _hl in hit_pills:
                            if _hr.collidepoint(mp):
                                paddle_hit_sound = _hv
                                focus = "hitsound"
                                _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(_hv, "PADDLE")
                                _ps = _paddle_sounds.get(_hs_key)
                                if _ps:
                                    _ps.set_volume(current_sfx_volume)
                                    _ps.play()
                                break

                # 뒤로가기
                if back_rect.collidepoint(mp):
                    ctx.play_click_sound()
                    _save_menu_settings(settings, bgm_mgr, current_bgm_volume, current_sfx_volume, bgm_muted, sfx_muted, control_scheme, paddle_hit_sound, ball_type, current_language)
                    # 디스플레이 모드 변경 적용
                    try:
                        from pingfighter import switch_display_mode, get_display_mode
                        if display_mode != get_display_mode():
                            switch_display_mode(display_mode)
                    except Exception as _e:
                        print(f"[디스플레이 전환 오류] {_e}")
                    return

                if current_tab == "controls":
                    if kb_rect.collidepoint(mp):
                        control_scheme = "keyboard"
                        continue
                    if mk_rect.collidepoint(mp):
                        control_scheme = "mouse_keyboard"
                        continue

                if current_tab == "display":
                    if fs_rect.collidepoint(mp):
                        display_mode = "fullscreen"
                        continue
                    if cm_rect.collidepoint(mp):
                        display_mode = "cinema"
                        continue
                    if win_rect.collidepoint(mp):
                        display_mode = "windowed"
                        continue

                if current_tab == "sound":
                    # BGM 음소거 체크박스
                    if bgm_checkbox_rect.collidepoint(mp):
                        bgm_muted = not bgm_muted
                        set_bgm_muted(bgm_muted)
                        if bgm_muted:
                            pygame.mixer.music.set_volume(0)
                        elif bgm_mgr:
                            bgm_mgr.volume = current_bgm_volume
                            pygame.mixer.music.set_volume(current_bgm_volume)
                        ctx.play_click_sound()
                        continue

                    # SFX 음소거 체크박스
                    if sfx_checkbox_rect.collidepoint(mp):
                        sfx_muted = not sfx_muted
                        set_sfx_muted(sfx_muted)
                        ctx.play_click_sound()
                        continue

                    # BGM 슬라이더 클릭
                    bgm_slider_area = pygame.Rect(slider_x, bgm_y - 10, slider_width, slider_height + 20)
                    if bgm_slider_area.collidepoint(mp) or bgm_handle_rect.collidepoint(mp):
                        selected_slider = "bgm"
                        dragging = True
                        current_bgm_volume = clamp_volume((mp[0] - slider_x) / slider_width)
                        if not bgm_muted and bgm_mgr:
                            bgm_mgr.volume = current_bgm_volume
                            pygame.mixer.music.set_volume(current_bgm_volume)

                    # SFX 슬라이더 클릭
                    sfx_slider_area = pygame.Rect(slider_x, sfx_y - 10, slider_width, slider_height + 20)
                    if sfx_slider_area.collidepoint(mp) or sfx_handle_rect.collidepoint(mp):
                        selected_slider = "sfx"
                        dragging = True
                        current_sfx_volume = clamp_volume((mp[0] - slider_x) / slider_width)
                        if not sfx_muted:
                            set_sfx_volume(current_sfx_volume)

            elif event.type == pygame.MOUSEBUTTONUP:
                if dragging:
                    ctx.play_click_sound()
                dragging = False

            elif event.type == pygame.MOUSEMOTION and dragging:
                mx = event.pos[0]
                if current_tab == "sound" and selected_slider == "bgm":
                    current_bgm_volume = clamp_volume((mx - slider_x) / slider_width)
                    if not bgm_muted and bgm_mgr:
                        bgm_mgr.volume = current_bgm_volume
                        pygame.mixer.music.set_volume(current_bgm_volume)
                elif current_tab == "sound" and selected_slider == "sfx":
                    current_sfx_volume = clamp_volume((mx - slider_x) / slider_width)
                    if not sfx_muted:
                        set_sfx_volume(current_sfx_volume)

            elif event.type == pygame.MOUSEWHEEL:
                mp = pygame.mouse.get_pos()
                if current_tab == "sound":
                    bgm_area = pygame.Rect(slider_x, bgm_y - 10, slider_width, slider_height + 20)
                    sfx_area = pygame.Rect(slider_x, sfx_y - 10, slider_width, slider_height + 20)
                    if bgm_area.collidepoint(mp) or focus == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume + event.y * 0.02)
                        if not bgm_muted and bgm_mgr:
                            bgm_mgr.volume = current_bgm_volume
                            pygame.mixer.music.set_volume(current_bgm_volume)
                    elif sfx_area.collidepoint(mp) or focus == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume + event.y * 0.02)
                        if not sfx_muted:
                            set_sfx_volume(current_sfx_volume)

    _save_menu_settings(settings, bgm_mgr, current_bgm_volume, current_sfx_volume, bgm_muted, sfx_muted, control_scheme, paddle_hit_sound, ball_type, current_language)


def _save_menu_settings(settings, bgm_mgr, bgm_vol, sfx_vol, bgm_muted, sfx_muted, control_scheme, paddle_hit_sound=1, ball_type="energy", language=None):
    """설정 값 저장"""
    from game_state.audio import set_bgm_volume, set_sfx_volume, set_bgm_muted, set_sfx_muted
    try:
        set_bgm_volume(bgm_vol)
        set_sfx_volume(sfx_vol)
        set_bgm_muted(bgm_muted)
        set_sfx_muted(sfx_muted)
        if bgm_mgr:
            bgm_mgr.volume = bgm_vol
            if not bgm_muted:
                pygame.mixer.music.set_volume(bgm_vol)
        settings.set_setting("audio", "sfx_volume", sfx_vol)
        settings.set_setting("audio", "music_volume", bgm_vol)
        settings.set_setting("audio", "paddle_hit_sound", paddle_hit_sound)
        settings.set_setting("gameplay", "ball_type", ball_type)
        settings.set_setting("controls", "control_scheme", control_scheme)
        if language is not None:
            settings.set_setting("language", "language", language)
        settings.save_settings()
    except Exception as e:
        print(f"[설정 저장 오류] {e}")


def _activate_menu_choice(ctx: MenuContext, state: MenuState, choice: str) -> bool:
    if choice == "계속하기":
        # 저장된 게임 데이터 불러오기
        try:
            import pingfighter as pf_module
            from pingfighter import (
                load_game_progress, apply_loaded_progress, run_downtown_hub,
                apply_character_selection, main as pingfighter_main, items,
                effects_manager, reset_damage_manager, get_net_gun_instance,
                preload_stage_intro_resources, play_stage_intro_video,
                complete_stage_intro_transition,
                STAGE2_INTRO_VIDEO_PATH, STAGE3_INTRO_VIDEO_PATH, STAGE4_INTRO_VIDEO_PATH,
                STAGE5_INTRO_VIDEO_PATH, STAGE6_INTRO_VIDEO_PATH, STAGE7_INTRO_VIDEO_PATH,
                STAGE8_INTRO_VIDEO_PATH
            )

            save_data = load_game_progress()
            if save_data:
                # 클릭 사운드 재생
                ctx.play_click_sound()

                # 저장된 데이터 적용
                apply_loaded_progress(save_data)

                # 저장된 캐릭터 타입 적용
                char_type = save_data.get("character_type", "smasher")
                try:
                    apply_character_selection(char_type)
                except Exception as char_err:
                    print(f"[계속하기] 캐릭터 적용 실패: {char_err}")

                # === UI 활성화 및 게임 상태 초기화 ===
                # 필러 UI 활성화 (중요! 없으면 게이지, 점수판 등 UI가 안 보임)
                pf_module._pillar_ui_enabled = True

                # AI 모드 설정 (저장된 값 또는 기본값)
                ai_mode = save_data.get("ai_mode", "junior")
                pf_module.ai_mode = ai_mode
                pf_module.ai_enabled = True

                # 난이도별 패들 스케일 적용
                try:
                    pf_module.apply_player_paddle_scale(ai_mode)
                except Exception:
                    pass

                # 저장된 스테이지의 광장으로 이동
                stage_num = save_data.get("stage_number", 1)

                # 무지개 파티클 트랜지션 효과 재생
                _play_rainbow_transition(ctx.get_screen(), 800)

                # 광장으로 직접 이동
                should_continue = run_downtown_hub(stage_num)

                # 저장 NPC를 통해 메인메뉴로 복귀하는 경우
                if not should_continue:
                    # Alt+F4로 종료한 경우 게임 완전 종료
                    if getattr(pf_module, 'game_should_exit', False):
                        pygame.quit()
                        sys.exit()
                    # 메인메뉴로 복귀 (루프 재시작)
                    return False

                # === 광장 종료 후 다음 스테이지로 전환 ===
                # 다음 스테이지 번호 계산 (광장 stage_num은 클리어한 스테이지, 다음은 +1)
                next_stage_display = stage_num + 1

                # 아이템 및 상태 초기화
                items.clear_field_items()
                try:
                    get_net_gun_instance().reset()
                except Exception:
                    pass

                # === 저장 파일 삭제 (다음 스테이지 진입 시) ===
                # 이제 광장에서 나가면 저장 데이터는 더 이상 유효하지 않음
                try:
                    from pingfighter import delete_save_data
                    delete_save_data()
                    print(f"[계속하기] 저장 파일 삭제 완료 - 다음 스테이지 {next_stage_display} 진입")
                except Exception as del_err:
                    print(f"[계속하기] 저장 파일 삭제 실패: {del_err}")

                # 다음 스테이지 인트로 재생
                _stage_intro_map = {
                    2: (STAGE2_INTRO_VIDEO_PATH, "STAGE 2", "악어장군", (240, 220, 180), (200, 110, 160)),
                    3: (STAGE3_INTRO_VIDEO_PATH, "STAGE 3", "멘헤라걸", (255, 180, 255), (200, 110, 210)),
                    4: (STAGE4_INTRO_VIDEO_PATH, "STAGE 4", "퐁크", (255, 240, 200), (220, 150, 120)),
                    5: (STAGE5_INTRO_VIDEO_PATH, "STAGE 5", "네메시스", (0, 255, 255), (150, 200, 255)),
                    6: (STAGE6_INTRO_VIDEO_PATH, "STAGE 6", "홍련", (255, 150, 100), (200, 80, 120)),
                    7: (STAGE7_INTRO_VIDEO_PATH, "STAGE 7", "테트리서", (120, 180, 255), (90, 210, 255)),
                    8: (STAGE8_INTRO_VIDEO_PATH, "STAGE 8", "???", (200, 200, 200), (180, 180, 180)),
                }
                intro_info = _stage_intro_map.get(next_stage_display)
                if intro_info:
                    vid_path, stg_text, boss_name, stg_color, boss_color = intro_info
                    preload_stage_intro_resources(vid_path)
                    played, _ = play_stage_intro_video(
                        vid_path,
                        stage_text=stg_text,
                        boss_text=boss_name,
                        stage_color=stg_color,
                        boss_color=boss_color,
                        post_hold_ms=0,
                    )
                    if played:
                        complete_stage_intro_transition()

                # 이펙트 및 상태 초기화
                try:
                    effects_manager.clear_all_effects()
                except Exception:
                    pass
                try:
                    reset_damage_manager()
                except Exception:
                    pass

                # 다음 스테이지 게임 시작
                if not getattr(pf_module, 'game_should_exit', False):
                    pingfighter_main(next_stage_display)

                return True
            else:
                print("[계속하기] 저장 데이터 없음")
        except Exception as e:
            print(f"[계속하기 오류] {e}")
            import traceback
            traceback.print_exc()
        return False

    if choice == "경기장 입장":
        return _show_mode_selection(ctx, state)
    if choice == "멀티플레이":
        return _show_multiplayer_menu(ctx, state)
    if choice == "AI 플레이":
        return _run_ai_play_flow(ctx)
    if choice == "개발테스트":
        return _show_dev_test_menu(ctx, state)
    if choice == "메달샵":
        state.locked_message_timer = ctx.two_seconds_frames
        return False
    if choice == "설정":
        _show_settings_screen(ctx, state)
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
    menu_spacing = 8
    # 버튼 수가 많을 때 자동으로 너비 축소하여 오버플로 방지
    if num_options <= 6:
        menu_item_width = 100
    elif num_options == 7:
        menu_item_width = 90
    else:
        menu_item_width = 80
    menu_item_height = 70
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
                # F9: 전체화면 전환
                from pingfighter import switch_display_mode, get_display_mode
                if get_display_mode() != "fullscreen":
                    switch_display_mode("fullscreen")
                continue
            if event.key == pygame.K_F10:
                # F10: 창모드 전환
                from pingfighter import switch_display_mode, get_display_mode
                if get_display_mode() != "windowed":
                    switch_display_mode("windowed")
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
                # 키보드 이동 시에도 파티클 생성
                width_k = ctx.get_dimensions()[0]
                height_k = ctx.get_dimensions()[1]
                _sx, _sy, _sw, _sh, _sp = _get_horizontal_menu_rects(width_k, height_k, len(current_menu_options))
                _kx = _sx + state.selected * (_sw + _sp)
                _menu_spawn_particles(_kx, _sy, _sw, _sh)
            elif event.key in (pygame.K_LEFT, pygame.K_a):
                ctx.play_hover_sound()
                state.selected = (state.selected - 1) % len(current_menu_options)
                width_k = ctx.get_dimensions()[0]
                height_k = ctx.get_dimensions()[1]
                _sx, _sy, _sw, _sh, _sp = _get_horizontal_menu_rects(width_k, height_k, len(current_menu_options))
                _kx = _sx + state.selected * (_sw + _sp)
                _menu_spawn_particles(_kx, _sy, _sw, _sh)
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
    set_tutorial_mode: Callable[[bool], None]  # 튜토리얼 모드 플래그 설정
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

    subtitle_text = get_localization_manager().get_text("menu.subtitle", "탁구로 보스를 이겨라!")
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

    # 언어/폰트 초기화 (저장된 언어 설정에 맞춰 CJK 폰트 전환)
    try:
        from config.settings_system import get_settings_manager
        _saved_lang = get_settings_manager().get_setting("language", "language", "ko")
        get_localization_manager().set_language(_saved_lang)
    except Exception:
        pass

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
