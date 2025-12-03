"""일시정지 관련 UI 컴포넌트."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, List, Optional, Sequence, Tuple

import pygame

from core.input_keys import is_move_down_event

from pixel_font_manager import FontStyle
from config.settings_system import get_settings_manager
from managers.sound_manager import get_sound_manager
from game_state.audio import clamp_volume
from config import constants as const

__all__ = ["PauseMenu", "PauseOptionsContext", "show_pause_options"]


class PauseMenu:
    """간단한 일시정지 메뉴.

    레거시 함수 기반 일시정지 UI 대신 객체 지향 인터페이스를 제공해
    `core.game_engine.GameEngine`에서 쉽게 제어할 수 있도록 한다.
    """

    _OPTIONS: Sequence[Tuple[str, str]] = (
        ("계속하기", "resume"),
        ("라운드 재시작", "restart"),
        ("메인 메뉴", "quit"),
    )

    def __init__(self, screen: pygame.Surface):
        self.screen = screen
        self.width, self.height = screen.get_size()
        self.options: List[Tuple[str, str]] = list(self._OPTIONS)
        self.selected_index = 0
        self._pending_action: Optional[str] = None
        self._option_rects: List[pygame.Rect] = []

        # 폰트는 반복적으로 로드하지 않도록 캐시한다.
        self._font_title = None
        self._font_option = None
        self._font_hint = None
        self._ensure_fonts()

    # 공개 API ---------------------------------------------------------------
    def reset(self) -> None:
        """화면 크기와 선택 상태를 초기화."""

        self.width, self.height = self.screen.get_size()
        self.selected_index = 0
        self._pending_action = None

    def update(self, _dt: float) -> Optional[str]:
        """대기 중이던 액션을 반환한다."""

        action = self._pending_action
        self._pending_action = None
        return action

    def render(self) -> None:
        """일시정지 오버레이를 그린다."""

        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        box_rect, option_rects = self._compute_layout()
        self._option_rects = option_rects

        pygame.draw.rect(self.screen, (25, 25, 35), box_rect, border_radius=12)
        pygame.draw.rect(self.screen, const.CYAN, box_rect, 3, border_radius=12)

        title_surface = self._font_title.render("일시정지", True, const.WHITE)
        title_rect = title_surface.get_rect(center=(self.width // 2, box_rect.top + 60))
        self.screen.blit(title_surface, title_rect)

        hint_surface = self._font_hint.render("↑↓ 선택 · Enter/Space 확인 · Esc 취소", True, (170, 170, 180))
        hint_rect = hint_surface.get_rect(center=(self.width // 2, box_rect.bottom - 40))
        self.screen.blit(hint_surface, hint_rect)

        for idx, (label, _) in enumerate(self.options):
            option_rect = option_rects[idx]
            is_selected = idx == self.selected_index

            if is_selected:
                highlight_rect = option_rect.inflate(20, 8)
                highlight_surface = pygame.Surface(highlight_rect.size, pygame.SRCALPHA)
                highlight_surface.fill((*const.CYAN, 60))
                self.screen.blit(highlight_surface, highlight_rect.topleft)
                pygame.draw.rect(self.screen, const.CYAN, highlight_rect, 2, border_radius=10)

            text_color = const.CYAN if is_selected else const.WHITE
            option_surface = self._font_option.render(label, True, text_color)
            text_rect = option_surface.get_rect(center=option_rect.center)
            self.screen.blit(option_surface, text_rect)

    def handle_click(self, pos: Tuple[int, int]) -> Optional[str]:
        """클릭 위치에 따라 액션을 결정한다."""

        if not self._option_rects:
            _, option_rects = self._compute_layout()
        else:
            option_rects = self._option_rects

        for idx, rect in enumerate(option_rects):
            if rect.collidepoint(pos):
                self.selected_index = idx
                return self._select_current()
        return None

    def handle_keydown(self, event: pygame.event.Event) -> Optional[str]:
        """키보드 입력 처리."""

        if event.key in (pygame.K_UP, pygame.K_w):
            self.selected_index = (self.selected_index - 1) % len(self.options)
        elif event.key in (pygame.K_DOWN, pygame.K_s) or is_move_down_event(event):
            self.selected_index = (self.selected_index + 1) % len(self.options)
        elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
            return self._select_current()
        elif event.key == pygame.K_TAB:
            self.selected_index = (self.selected_index + 1) % len(self.options)
        return None

    # 내부 --------------------------------------------------------------------
    def _ensure_fonts(self) -> None:
        if self._font_title is None:
            try:
                self._font_title = pygame.font.Font("NanumSquareEB.ttf", 44)
                self._font_option = pygame.font.Font("NanumSquareB.ttf", 30)
                self._font_hint = pygame.font.Font("NanumSquareR.ttf", 20)
            except Exception:
                self._font_title = pygame.font.Font(None, 44)
                self._font_option = pygame.font.Font(None, 30)
                self._font_hint = pygame.font.Font(None, 20)

    def _select_current(self) -> Optional[str]:
        action = self.options[self.selected_index][1]
        self._pending_action = action
        return action

    def _compute_layout(self) -> Tuple[pygame.Rect, List[pygame.Rect]]:
        box_width = min(480, max(320, int(self.width * 0.65)))
        box_height = 180 + len(self.options) * 60
        box_x = (self.width - box_width) // 2
        box_y = (self.height - box_height) // 2

        box_rect = pygame.Rect(box_x, box_y, box_width, box_height)

        option_rects: List[pygame.Rect] = []
        for idx in range(len(self.options)):
            center_y = box_y + 120 + idx * 60
            option_rects.append(pygame.Rect(
                box_x + 60,
                center_y - 22,
                box_width - 120,
                44,
            ))
        return box_rect, option_rects


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
    # 사운드 매니저 기반 옵션 읽기
    sm = get_sound_manager()
    # 컨트롤 설정
    settings = get_settings_manager()
    control_scheme = settings.get_setting('controls', 'control_scheme', 'keyboard')
    modern_loop_enabled = ctx.get_modern_loop_enabled()

    # 크고 겹치지 않는 고급 레이아웃
    slider_height = 10
    handle_size = 14

    panel_width = min(900, max(640, int(ctx.width * 0.82)))
    panel_height = 280  # 패널 높이 축소 (토글 제거로 인해)
    panel_x = (ctx.width - panel_width) // 2
    panel_y = (ctx.height - panel_height) // 2

    margin_x = 29
    label_w = 160
    value_w = 48
    slider_width = max(360, panel_width - (margin_x * 2 + label_w + value_w))

    bgm_slider_x = panel_x + margin_x + label_w
    bgm_slider_y = panel_y + 100
    sfx_slider_x = panel_x + margin_x + label_w
    sfx_slider_y = panel_y + 150

    back_button_width = 144
    back_button_height = 45
    back_button_x = panel_x + (panel_width - back_button_width) // 2
    back_button_y = panel_y + panel_height - 70
    back_button_rect = pygame.Rect(back_button_x, back_button_y, back_button_width, back_button_height)

    selected_slider: str | None = None  # 드래그 중인 슬라이더 식별자
    focus: str = "bgm"  # 키보드 포커스: bgm / sfx / back
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

        # 고급 패널 스타일: 반투명 박스 + 이중 외곽선 + 상단 헤더
        panel = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        pygame.draw.rect(panel, (28, 30, 40, 230), (0, 0, panel_width, panel_height), border_radius=12)
        pygame.draw.rect(panel, (90, 160, 220, 200), (1, 1, panel_width - 2, panel_height - 2), 2, border_radius=10)
        pygame.draw.rect(panel, (40, 80, 120, 180), (4, 4, panel_width - 8, panel_height - 8), 2, border_radius=8)
        header_rect = pygame.Rect(0, 0, panel_width, 60)
        pygame.draw.rect(panel, (38, 50, 70, 230), header_rect, border_radius=10)
        pygame.draw.line(panel, (90, 160, 220, 180), (14, 60), (panel_width - 14, 60), 2)
        ctx.screen.blit(panel, (panel_x, panel_y))

        # 탭 렌더링
        current_tab = locals().get('current_tab', 'sound')  # 유지용
        # 탭 영역
        tabs_y = panel_y + 10
        tab_w = 120
        tab_h = 36
        sound_tab_rect = pygame.Rect(panel_x + 20, tabs_y, tab_w, tab_h)
        ctrl_tab_rect = pygame.Rect(panel_x + 20 + tab_w + 12, tabs_y, tab_w, tab_h)
        # 현재 탭 상태 유지
        if 'current_tab' not in locals():
            current_tab = 'sound'
        # 그리기 함수
        def _draw_tab(rect: pygame.Rect, label: str, active: bool):
            base = (70, 100, 140) if active else (50, 60, 80)
            pygame.draw.rect(ctx.screen, base, rect, border_radius=8)
            pygame.draw.rect(ctx.screen, (140, 180, 220), rect, 2, border_radius=8)
            t = font_small.render(label, True, const.WHITE)
            ctx.screen.blit(t, t.get_rect(center=rect.center))
        _draw_tab(sound_tab_rect, '사운드', current_tab == 'sound')
        _draw_tab(ctrl_tab_rect, '컨트롤', current_tab == 'controls')

        # 컨텐츠 렌더링 -------------------------------------------------------
        if current_tab == 'controls':
            # 조작 방식 선택(키보드만 / 마우스+키보드)
            label = font_medium.render("조작 방식", True, const.WHITE)
            ctx.screen.blit(label, (panel_x + margin_x, bgm_slider_y + slider_height // 2 - 10))
            # 두 개의 선택 버튼
            pill_w, pill_h = 180, 36
            kb_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 8, pill_w, pill_h)
            mk_rect = pygame.Rect(bgm_slider_x + pill_w + 14, bgm_slider_y - 8, pill_w + 20, pill_h)
            def _draw_pill(rect: pygame.Rect, text: str, selected: bool, focused: bool):
                col = (60, 90, 130) if selected else (45, 55, 70)
                pygame.draw.rect(ctx.screen, col, rect, border_radius=18)
                pygame.draw.rect(ctx.screen, (140, 180, 220) if focused else const.WHITE, rect, 2, border_radius=18)
                s = font_small.render(text, True, const.WHITE)
                ctx.screen.blit(s, s.get_rect(center=rect.center))
            _draw_pill(kb_rect, '키보드만', control_scheme == 'keyboard', locals().get('focus','bgm') == 'scheme')
            _draw_pill(mk_rect, '마우스+키보드', control_scheme == 'mouse_keyboard', locals().get('focus','bgm') == 'scheme')
        else:
            # -------- 사운드 탭 --------
            bgm_label = font_medium.render("BGM 볼륨", True, const.WHITE)
            bgm_label_rect = bgm_label.get_rect(left=panel_x + margin_x, centery=bgm_slider_y + slider_height // 2)
            ctx.screen.blit(bgm_label, bgm_label_rect)

        if current_tab == 'sound':
            pygame.draw.rect(ctx.screen, (64, 66, 76), (bgm_slider_x, bgm_slider_y, slider_width, slider_height), border_radius=6)
            pygame.draw.rect(
                ctx.screen,
                (0, 200, 255),
                (bgm_slider_x, bgm_slider_y, int(slider_width * current_bgm_volume), slider_height),
                border_radius=6,
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
                const.WHITE if (selected_slider == "bgm" or focus == "bgm") else (210, 210, 210),
                (bgm_handle_x, bgm_slider_y + slider_height // 2),
                handle_size // 2,
            )

            bgm_percent = font_small.render(f"{int(current_bgm_volume * 100)}%", True, const.CYAN)
            bgm_percent_rect = bgm_percent.get_rect(left=bgm_slider_x + slider_width + 12, centery=bgm_slider_y + slider_height // 2)
            ctx.screen.blit(bgm_percent, bgm_percent_rect)

            sfx_label = font_medium.render("효과음 볼륨", True, const.WHITE)
            sfx_label_rect = sfx_label.get_rect(left=panel_x + margin_x, centery=sfx_slider_y + slider_height // 2)
            ctx.screen.blit(sfx_label, sfx_label_rect)

            pygame.draw.rect(ctx.screen, (64, 66, 76), (sfx_slider_x, sfx_slider_y, slider_width, slider_height), border_radius=6)
            pygame.draw.rect(
                ctx.screen,
                (0, 255, 100),
                (sfx_slider_x, sfx_slider_y, int(slider_width * current_sfx_volume), slider_height),
                border_radius=6,
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
                const.WHITE if (selected_slider == "sfx" or focus == "sfx") else (210, 210, 210),
                (sfx_handle_x, sfx_slider_y + slider_height // 2),
                handle_size // 2,
            )

            sfx_percent = font_small.render(f"{int(current_sfx_volume * 100)}%", True, (0, 255, 100))
            sfx_percent_rect = sfx_percent.get_rect(left=sfx_slider_x + slider_width + 12, centery=sfx_slider_y + slider_height // 2)
            ctx.screen.blit(sfx_percent, sfx_percent_rect)

        # (미니멀 구성: UI/환경 슬라이더 제거)

        button_hover = back_button_rect.collidepoint(pygame.mouse.get_pos()) or (focus == "back")
        button_color = (100, 150, 255) if button_hover else (50, 50, 50)
        pygame.draw.rect(ctx.screen, button_color, back_button_rect, border_radius=5)
        pygame.draw.rect(ctx.screen, const.WHITE, back_button_rect, 2, border_radius=5)

        back_text = font_medium.render("뒤로가기", True, const.WHITE)
        back_text_rect = back_text.get_rect(center=back_button_rect.center)
        ctx.screen.blit(back_text, back_text_rect)

        # 하단 힌트 문구 제거(요청)

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
                    # 컨트롤 스킴 저장
                    settings.set_setting('controls','control_scheme', control_scheme)
                    settings.save_settings()
                    return
                if event.key == pygame.K_TAB:
                    current_tab = 'controls' if current_tab == 'sound' else 'sound'
                if event.key == pygame.K_LEFT:
                    if current_tab == 'controls':
                        if locals().get('focus','bgm') in ('scheme','back'):
                            control_scheme = 'keyboard'
                    elif focus == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume - 0.05)
                        ctx.apply_bgm_volume(current_bgm_volume)
                        selected_slider = "bgm"
                    elif focus == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume - 0.05)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        selected_slider = "sfx"
                elif event.key == pygame.K_RIGHT:
                    if current_tab == 'controls':
                        if locals().get('focus','bgm') in ('scheme','back'):
                            control_scheme = 'mouse_keyboard'
                    elif focus == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume + 0.05)
                        ctx.apply_bgm_volume(current_bgm_volume)
                        selected_slider = "bgm"
                    elif focus == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume + 0.05)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        selected_slider = "sfx"
                elif event.key == pygame.K_UP:
                    order = ["scheme"] if current_tab == 'controls' else ["bgm", "sfx"]
                    order += ["back"]
                    focus = order[(order.index(focus) - 1) % len(order)] if focus in order else "bgm"
                elif event.key == pygame.K_DOWN:
                    order = ["scheme"] if current_tab == 'controls' else ["bgm", "sfx"]
                    order += ["back"]
                    focus = order[(order.index(focus) + 1) % len(order)] if focus in order else "bgm"
                elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                    if current_tab == 'controls' and focus == 'scheme':
                        control_scheme = 'mouse_keyboard' if control_scheme == 'keyboard' else 'keyboard'
                    elif focus == "back":
                        ctx.play_button_click_sound()
                        current_bgm_volume = ctx.store_bgm_volume(current_bgm_volume)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        return
            elif event.type == pygame.MOUSEBUTTONDOWN:
                # 왼쪽 버튼(1)으로만 토글/슬라이더 조작 허용
                if event.button == 1:
                    mouse_pos = pygame.mouse.get_pos()
                    mouse_x = mouse_pos[0]

                    # 탭 클릭 처리
                    if sound_tab_rect.collidepoint(mouse_pos):
                        current_tab = 'sound'
                        continue
                    if ctrl_tab_rect.collidepoint(mouse_pos):
                        current_tab = 'controls'
                        continue

                    if back_button_rect.collidepoint(mouse_pos):
                        ctx.play_button_click_sound()
                        current_bgm_volume = ctx.store_bgm_volume(current_bgm_volume)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        return
                    # 컨트롤 탭 처리
                    if current_tab == 'controls':
                        if 'kb_rect' in locals() and kb_rect.collidepoint(mouse_pos):
                            control_scheme = 'keyboard'
                            continue
                        if 'mk_rect' in locals() and mk_rect.collidepoint(mouse_pos):
                            control_scheme = 'mouse_keyboard'
                            continue

                    bgm_slider_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 10, slider_width, slider_height + 20)
                    if current_tab == 'sound' and (bgm_slider_rect.collidepoint(mouse_pos) or ('bgm_handle_rect' in locals() and bgm_handle_rect.collidepoint(mouse_pos))):
                        selected_slider = "bgm"
                        dragging = True
                        relative_x = mouse_x - bgm_slider_x
                        current_bgm_volume = clamp_volume(relative_x / slider_width)
                        ctx.apply_bgm_volume(current_bgm_volume)

                    sfx_slider_rect = pygame.Rect(sfx_slider_x, sfx_slider_y - 10, slider_width, slider_height + 20)
                    if current_tab == 'sound' and (sfx_slider_rect.collidepoint(mouse_pos) or ('sfx_handle_rect' in locals() and sfx_handle_rect.collidepoint(mouse_pos))):
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
                if current_tab == 'sound' and selected_slider == "bgm":
                    relative_x = mouse_x - bgm_slider_x
                    current_bgm_volume = clamp_volume(relative_x / slider_width)
                    ctx.apply_bgm_volume(current_bgm_volume)
                elif current_tab == 'sound' and selected_slider == "sfx":
                    relative_x = mouse_x - sfx_slider_x
                    current_sfx_volume = clamp_volume(relative_x / slider_width)
                    current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                # (미니멀 구성: UI/ENV 슬라이더 제거)

            elif event.type == pygame.MOUSEWHEEL:
                mouse_pos = pygame.mouse.get_pos()
                bgm_slider_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 10, slider_width, slider_height + 20)
                sfx_slider_rect = pygame.Rect(sfx_slider_x, sfx_slider_y - 10, slider_width, slider_height + 20)

                if current_tab == 'sound' and (bgm_slider_rect.collidepoint(mouse_pos) or selected_slider == "bgm"):
                    current_bgm_volume = clamp_volume(current_bgm_volume + event.y * 0.02)
                    ctx.apply_bgm_volume(current_bgm_volume)
                    selected_slider = "bgm"
                elif current_tab == 'sound' and (sfx_slider_rect.collidepoint(mouse_pos) or selected_slider == "sfx"):
                    current_sfx_volume = clamp_volume(current_sfx_volume + event.y * 0.02)
                    current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                    selected_slider = "sfx"
                # (미니멀 구성: UI/ENV 휠 조정 제거)

    ctx.store_bgm_volume(current_bgm_volume)
    ctx.set_sfx_volume(current_sfx_volume)
