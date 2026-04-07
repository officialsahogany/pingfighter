"""일시정지 관련 UI 컴포넌트."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, List, Optional, Sequence, Tuple

import pygame

from core.input_keys import is_move_down_event

from pixel_font_manager import FontStyle
from config.settings_system import get_settings_manager
from game_state.audio import clamp_volume, get_bgm_muted, set_bgm_muted, get_sfx_muted, set_sfx_muted
from config import constants as const
from localization.manager import get_localization_manager
from config.language_options import LANGUAGE_OPTIONS, LANGUAGE_CODES

__all__ = ["PauseMenu", "PauseOptionsContext", "show_pause_options"]


class PauseMenu:
    """간단한 일시정지 메뉴.

    레거시 함수 기반 일시정지 UI 대신 객체 지향 인터페이스를 제공해
    `core.game_engine.GameEngine`에서 쉽게 제어할 수 있도록 한다.
    """

    _OPTION_KEYS: Sequence[Tuple[str, str, str]] = (
        ("pause.resume", "계속하기", "resume"),
        ("pause.restart", "라운드 재시작", "restart"),
        ("pause.quit", "메인 메뉴", "quit"),
    )

    def __init__(self, screen: pygame.Surface):
        self.screen = screen
        self.width, self.height = screen.get_size()
        self.options: List[Tuple[str, str]] = self._build_options()
        self.selected_index = 0
        self._pending_action: Optional[str] = None
        self._option_rects: List[pygame.Rect] = []

        # 폰트는 반복적으로 로드하지 않도록 캐시한다.
        self._font_title = None
        self._font_option = None
        self._font_hint = None
        self._ensure_fonts()

    def _build_options(self) -> List[Tuple[str, str]]:
        loc = get_localization_manager()
        return [(loc.get_text(key, fallback), action) for key, fallback, action in self._OPTION_KEYS]

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

        # 언어 변경 시 옵션 라벨 갱신
        self.options = self._build_options()

        loc = get_localization_manager()

        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        box_rect, option_rects = self._compute_layout()
        self._option_rects = option_rects

        pygame.draw.rect(self.screen, (25, 25, 35), box_rect, border_radius=12)
        pygame.draw.rect(self.screen, const.CYAN, box_rect, 3, border_radius=12)

        title_surface = self._font_title.render(loc.get_text("pause.title", "일시정지"), True, const.WHITE)
        title_rect = title_surface.get_rect(center=(self.width // 2, box_rect.top + 60))
        self.screen.blit(title_surface, title_rect)

        hint_surface = self._font_hint.render(loc.get_text("pause.hint", "↑↓ 선택 · Enter/Space 확인 · Esc 취소"), True, (170, 170, 180))
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

    _loc = get_localization_manager()
    def _t(key: str, fallback: str) -> str:
        return _loc.get_text(key, fallback)

    font_large = FontStyle.subtitle()
    font_medium = FontStyle.body()
    font_small = FontStyle.small()

    current_bgm_volume = clamp_volume(ctx.get_bgm_runtime_volume())
    current_sfx_volume = clamp_volume(ctx.get_sfx_volume())
    # 음소거 상태
    bgm_muted = get_bgm_muted()
    sfx_muted = get_sfx_muted()
    # NOTE: get_sound_manager() 호출 제거 — SoundManager 싱글톤 생성이
    # mixer를 재초기화하여 채널 수를 64→16으로 줄이는 버그가 있었음
    # 컨트롤 설정
    settings = get_settings_manager()
    control_scheme = settings.get_setting('controls', 'control_scheme', 'keyboard')
    paddle_hit_sound = int(settings.get_setting('audio', 'paddle_hit_sound', 1))
    ball_type = settings.get_setting('gameplay', 'ball_type', 'energy')
    modern_loop_enabled = ctx.get_modern_loop_enabled()
    # 언어 설정
    current_language = settings.get_setting('language', 'language', 'ko')
    _loc.set_language(current_language)  # 폰트 언어 동기화 (ja/zh → CJK 폰트)

    # 패들 타격 사운드 프리로드
    _paddle_sounds = {}
    try:
        from sound_effects import SOUND_PATHS
        from pingfighter import resource_path as _res_path
        for _sk in ("PADDLE", "PADDLE2", "PADDLE3"):
            _rp = SOUND_PATHS.get(_sk)
            if _rp:
                _paddle_sounds[_sk] = pygame.mixer.Sound(_res_path(_rp))
    except Exception as _e:
        print(f"[WARN] paddle sound preload: {_e}")

    # 디스플레이 모드 상태
    try:
        from pingfighter import get_display_mode as _get_dm
        display_mode = _get_dm()
        if display_mode in ('borderless', 'large_windowed'):
            display_mode = 'windowed'  # 보더리스/큰창모드 제거됨 → 창모드로 폴백
        # fullscreen은 '전체화면'로 유지
    except Exception:
        display_mode = "windowed"

    # 크고 겹치지 않는 고급 레이아웃
    slider_height = 10
    handle_size = 14
    checkbox_size = 20  # 체크박스 크기

    panel_width = min(900, max(640, int(ctx.width * 0.82)))
    panel_height = 320
    panel_x = (ctx.width - panel_width) // 2
    panel_y = (ctx.height - panel_height) // 2

    margin_x = 29
    label_w = 160
    value_w = 48
    checkbox_margin = 70  # 체크박스와 퍼센트 사이 간격
    slider_width = max(300, panel_width - (margin_x * 2 + label_w + value_w + checkbox_margin))

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
    focus: str = "bgm"  # 키보드 포커스: bgm / sfx / hitsound / back
    dragging = False
    hit_pills = []
    ball_pills = []
    lang_pills = []

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
        tab_gap = 6
        tab_h = 36
        # 동적 탭 너비 (CJK 오버플로우 방지)
        _tab_labels = [
            _t("settings.tab.sound", "사운드"),
            _t("settings.tab.controls", "컨트롤"),
            _t("settings.tab.display", "디스플레이"),
            _t("settings.tab.play", "플레이"),
            _t("settings.tab.language", "언어"),
        ]
        _max_tw = max(font_small.size(lbl)[0] for lbl in _tab_labels)
        tab_w = max(85, _max_tw + 20)
        if tab_w * 5 + tab_gap * 4 + 32 > panel_width:
            tab_w = (panel_width - 32 - tab_gap * 4) // 5
        sound_tab_rect = pygame.Rect(panel_x + 16, tabs_y, tab_w, tab_h)
        ctrl_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap), tabs_y, tab_w, tab_h)
        disp_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap) * 2, tabs_y, tab_w, tab_h)
        play_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap) * 3, tabs_y, tab_w, tab_h)
        lang_tab_rect = pygame.Rect(panel_x + 16 + (tab_w + tab_gap) * 4, tabs_y, tab_w, tab_h)
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
        _draw_tab(sound_tab_rect, _t("settings.tab.sound", "사운드"), current_tab == 'sound')
        _draw_tab(ctrl_tab_rect, _t("settings.tab.controls", "컨트롤"), current_tab == 'controls')
        _draw_tab(disp_tab_rect, _t("settings.tab.display", "디스플레이"), current_tab == 'display')
        _draw_tab(play_tab_rect, _t("settings.tab.play", "플레이"), current_tab == 'play')
        _draw_tab(lang_tab_rect, _t("settings.tab.language", "언어"), current_tab == 'language')

        # 컨텐츠 렌더링 -------------------------------------------------------
        if current_tab == 'play':
            # ── 공 선택 ──
            ball_sel_y = bgm_slider_y
            ball_sel_label = font_medium.render(_t("settings.play.ball_label", "공 선택"), True, const.WHITE)
            ctx.screen.blit(ball_sel_label, ball_sel_label.get_rect(left=panel_x + margin_x, centery=ball_sel_y + 16))

            _bt_names = {"energy": _t("settings.play.ball_energy", "에너지볼"), "pingpong": _t("settings.play.ball_pingpong", "탁구공")}
            _max_bw = max(font_small.size(lbl)[0] for lbl in _bt_names.values())
            pill_w_b = max(110, _max_bw + 24)
            pill_h_b = 32
            pill_gap_b = 10
            ball_pills = []
            for i, (val, lbl) in enumerate(_bt_names.items()):
                px = bgm_slider_x + i * (pill_w_b + pill_gap_b)
                py = ball_sel_y + 2
                r = pygame.Rect(px, py, pill_w_b, pill_h_b)
                ball_pills.append((r, val, lbl))
                is_sel = (ball_type == val)
                col = (60, 90, 130) if is_sel else (45, 55, 70)
                pygame.draw.rect(ctx.screen, col, r, border_radius=16)
                border_col = (0, 255, 255) if is_sel else (150, 150, 150)
                if focus == "balltype" and is_sel:
                    border_col = (0, 255, 255)
                pygame.draw.rect(ctx.screen, border_col, r, 2, border_radius=16)
                s = font_small.render(lbl, True, const.WHITE)
                ctx.screen.blit(s, s.get_rect(center=r.center))

            _bt_descs = {
                "energy": _t("settings.play.ball_energy_desc", "속도에 따라 색상과 이펙트가 변합니다"),
                "pingpong": _t("settings.play.ball_pingpong_desc", "탁구공 이미지, 이펙트 없음"),
            }
            bt_desc = font_small.render(_bt_descs.get(ball_type, ''), True, (150, 180, 200))
            ctx.screen.blit(bt_desc, bt_desc.get_rect(centerx=ctx.width // 2, top=ball_sel_y + 44))

            # ── 타격 사운드 (에너지볼일 때만 활성) ──
            _hs_disabled = (ball_type == "pingpong")
            hit_y = ball_sel_y + 70
            _hs_label_col = (100, 100, 100) if _hs_disabled else const.WHITE
            hit_label = font_medium.render(_t("settings.play.hitsound_label", "타격 사운드"), True, _hs_label_col)
            ctx.screen.blit(hit_label, hit_label.get_rect(left=panel_x + margin_x, centery=hit_y + 16))

            _hs_names = {1: _t("settings.play.sound_1", "사운드 1"), 2: _t("settings.play.sound_2", "사운드 2"), 3: _t("settings.play.sound_3", "사운드 3")}
            _max_hw = max(font_small.size(lbl)[0] for lbl in _hs_names.values())
            pill_w_h = max(90, _max_hw + 24)
            pill_h_h = 32
            pill_gap_h = 8
            hit_pills = []
            for i, (val, lbl) in enumerate(_hs_names.items()):
                px = bgm_slider_x + i * (pill_w_h + pill_gap_h)
                py = hit_y
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
                    txt_col = const.WHITE
                pygame.draw.rect(ctx.screen, col, r, border_radius=16)
                pygame.draw.rect(ctx.screen, border_col, r, 2, border_radius=16)
                s = font_small.render(lbl, True, txt_col)
                ctx.screen.blit(s, s.get_rect(center=r.center))

        elif current_tab == 'controls':
            # 조작 방식 선택(키보드만 / 마우스+키보드)
            label = font_medium.render(_t("settings.controls.label", "조작 방식"), True, const.WHITE)
            ctx.screen.blit(label, (panel_x + margin_x, bgm_slider_y + slider_height // 2 - 10))
            # 두 개의 선택 버튼
            _ctrl_labels = [_t("settings.controls.keyboard_only", "키보드만"), _t("settings.controls.mouse_keyboard", "마우스+키보드")]
            _max_cw = max(font_small.size(lbl)[0] for lbl in _ctrl_labels)
            pill_w = max(180, _max_cw + 30)
            pill_h = 36
            kb_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 8, pill_w, pill_h)
            mk_rect = pygame.Rect(bgm_slider_x + pill_w + 14, bgm_slider_y - 8, pill_w + 20, pill_h)
            def _draw_pill(rect: pygame.Rect, text: str, selected: bool, focused: bool):
                col = (60, 90, 130) if selected else (45, 55, 70)
                pygame.draw.rect(ctx.screen, col, rect, border_radius=18)
                pygame.draw.rect(ctx.screen, (140, 180, 220) if focused else const.WHITE, rect, 2, border_radius=18)
                s = font_small.render(text, True, const.WHITE)
                ctx.screen.blit(s, s.get_rect(center=rect.center))
            _draw_pill(kb_rect, _t("settings.controls.keyboard_only", "키보드만"), control_scheme == 'keyboard', locals().get('focus','bgm') == 'scheme')
            _draw_pill(mk_rect, _t("settings.controls.mouse_keyboard", "마우스+키보드"), control_scheme == 'mouse_keyboard', locals().get('focus','bgm') == 'scheme')
        elif current_tab == 'display':
            # 화면 모드 선택 (전체화면 / 시네마모드 / 창모드)
            disp_label = font_medium.render(_t("settings.display.label", "화면 모드"), True, const.WHITE)
            ctx.screen.blit(disp_label, (panel_x + margin_x, bgm_slider_y + slider_height // 2 - 10))
            _disp_labels = [_t("settings.display.fullscreen", "전체화면"), _t("settings.display.cinema", "전체화면(저화질)"), _t("settings.display.windowed", "창모드")]
            _max_dw = max(font_small.size(lbl)[0] for lbl in _disp_labels)
            dpill_w = max(110, _max_dw + 24)
            dpill_h = 36
            _dpill_gap = 8
            fs_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 8, dpill_w, dpill_h)
            cm_rect = pygame.Rect(bgm_slider_x + dpill_w + _dpill_gap, bgm_slider_y - 8, dpill_w, dpill_h)
            win_rect = pygame.Rect(bgm_slider_x + (dpill_w + _dpill_gap) * 2, bgm_slider_y - 8, dpill_w, dpill_h)
            for _drect, _dlabel, _dsel in [
                (fs_rect, _t("settings.display.fullscreen", "전체화면"), display_mode == 'fullscreen'),
                (cm_rect, _t("settings.display.cinema", "전체화면(저화질)"), display_mode == 'cinema'),
                (win_rect, _t("settings.display.windowed", "창모드"), display_mode == 'windowed'),
            ]:
                _dcol = (60, 90, 130) if _dsel else (45, 55, 70)
                pygame.draw.rect(ctx.screen, _dcol, _drect, border_radius=18)
                pygame.draw.rect(ctx.screen, (140, 180, 220) if _dsel else const.WHITE, _drect, 2, border_radius=18)
                _ds = font_small.render(_dlabel, True, const.WHITE)
                ctx.screen.blit(_ds, _ds.get_rect(center=_drect.center))
            # 설명 텍스트
            _desc_y = bgm_slider_y + 45
            _disp_descs = {
                'fullscreen': _t("settings.display.fullscreen_desc", "네이티브 해상도 전체화면 (최고 화질)"),
                'cinema': _t("settings.display.cinema_desc", "해상도를 낮춰 성능을 높이고 화면을 꽉 채웁니다"),
                'windowed': _t("settings.display.windowed_desc", "필러 배경 포함 창모드로 표시합니다"),
            }
            _desc_t = font_small.render(_disp_descs.get(display_mode, ''), True, (150, 180, 200))
            ctx.screen.blit(_desc_t, _desc_t.get_rect(centerx=ctx.width // 2, top=_desc_y))
        elif current_tab == 'language':
            # -------- 언어 탭 --------
            lang_label = font_medium.render(_t("settings.language.label", "언어 선택"), True, const.WHITE)
            ctx.screen.blit(lang_label, (panel_x + margin_x, bgm_slider_y + slider_height // 2 - 10))
            _lang_options = LANGUAGE_OPTIONS
            # 동적 버튼 너비: CJK 라벨이 잘리지 않도록 최대 텍스트 폭 기준 계산
            _max_lw = 70
            for _lc, _ll in _lang_options:
                try:
                    if _lc in ("ja", "zh"):
                        from pixel_font_manager import get_cjk_font
                        _tw = get_cjk_font(18).size(_ll)[0]
                    else:
                        _tw = font_small.size(_ll)[0]
                    _max_lw = max(_max_lw, _tw)
                except Exception:
                    pass
            _lpill_w, _lpill_h = max(100, _max_lw + 24), 36
            _lpill_gap = 10
            lang_pills = []
            for i, (_lcode, _llabel) in enumerate(_lang_options):
                px = bgm_slider_x + i * (_lpill_w + _lpill_gap)
                py = bgm_slider_y - 8
                r = pygame.Rect(px, py, _lpill_w, _lpill_h)
                lang_pills.append((r, _lcode, _llabel))
                is_sel = (current_language == _lcode)
                col = (60, 90, 130) if is_sel else (45, 55, 70)
                pygame.draw.rect(ctx.screen, col, r, border_radius=18)
                border_col = (0, 255, 255) if is_sel else (150, 150, 150)
                pygame.draw.rect(ctx.screen, border_col, r, 2, border_radius=18)
                # ja/zh 라벨은 CJK 폰트 사용 (픽셀폰트 미지원)
                if _lcode in ("ja", "zh"):
                    from pixel_font_manager import get_cjk_font
                    _pill_font = get_cjk_font(18)
                else:
                    _pill_font = font_small
                s = _pill_font.render(_llabel, True, const.WHITE)
                ctx.screen.blit(s, s.get_rect(center=r.center))
        else:
            # -------- 사운드 탭 --------
            bgm_label = font_medium.render(_t("settings.sound.bgm", "BGM 볼륨"), True, const.WHITE)
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

            bgm_percent = font_small.render(f"{int(current_bgm_volume * 100)}%", True, const.CYAN if not bgm_muted else (100, 100, 100))
            bgm_percent_rect = bgm_percent.get_rect(left=bgm_slider_x + slider_width + 12, centery=bgm_slider_y + slider_height // 2)
            ctx.screen.blit(bgm_percent, bgm_percent_rect)

            # BGM 음소거 체크박스
            bgm_checkbox_x = bgm_slider_x + slider_width + 60
            bgm_checkbox_y = bgm_slider_y + slider_height // 2 - checkbox_size // 2
            bgm_checkbox_rect = pygame.Rect(bgm_checkbox_x, bgm_checkbox_y, checkbox_size, checkbox_size)
            pygame.draw.rect(ctx.screen, (80, 80, 100), bgm_checkbox_rect, border_radius=4)
            pygame.draw.rect(ctx.screen, (0, 200, 255) if bgm_muted else (150, 150, 150), bgm_checkbox_rect, 2, border_radius=4)
            if bgm_muted:
                # 체크 표시 (X 모양)
                pygame.draw.line(ctx.screen, (255, 80, 80), (bgm_checkbox_x + 4, bgm_checkbox_y + 4), (bgm_checkbox_x + checkbox_size - 4, bgm_checkbox_y + checkbox_size - 4), 3)
                pygame.draw.line(ctx.screen, (255, 80, 80), (bgm_checkbox_x + checkbox_size - 4, bgm_checkbox_y + 4), (bgm_checkbox_x + 4, bgm_checkbox_y + checkbox_size - 4), 3)
            # 음소거 라벨
            mute_label = font_small.render("OFF", True, (255, 80, 80) if bgm_muted else (120, 120, 120))
            ctx.screen.blit(mute_label, (bgm_checkbox_x + checkbox_size + 5, bgm_checkbox_y + 2))

            sfx_label = font_medium.render(_t("settings.sound.sfx", "효과음 볼륨"), True, const.WHITE)
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

            sfx_percent = font_small.render(f"{int(current_sfx_volume * 100)}%", True, (0, 255, 100) if not sfx_muted else (100, 100, 100))
            sfx_percent_rect = sfx_percent.get_rect(left=sfx_slider_x + slider_width + 12, centery=sfx_slider_y + slider_height // 2)
            ctx.screen.blit(sfx_percent, sfx_percent_rect)

            # SFX 음소거 체크박스
            sfx_checkbox_x = sfx_slider_x + slider_width + 60
            sfx_checkbox_y = sfx_slider_y + slider_height // 2 - checkbox_size // 2
            sfx_checkbox_rect = pygame.Rect(sfx_checkbox_x, sfx_checkbox_y, checkbox_size, checkbox_size)
            pygame.draw.rect(ctx.screen, (80, 80, 100), sfx_checkbox_rect, border_radius=4)
            pygame.draw.rect(ctx.screen, (0, 255, 100) if sfx_muted else (150, 150, 150), sfx_checkbox_rect, 2, border_radius=4)
            if sfx_muted:
                # 체크 표시 (X 모양)
                pygame.draw.line(ctx.screen, (255, 80, 80), (sfx_checkbox_x + 4, sfx_checkbox_y + 4), (sfx_checkbox_x + checkbox_size - 4, sfx_checkbox_y + checkbox_size - 4), 3)
                pygame.draw.line(ctx.screen, (255, 80, 80), (sfx_checkbox_x + checkbox_size - 4, sfx_checkbox_y + 4), (sfx_checkbox_x + 4, sfx_checkbox_y + checkbox_size - 4), 3)
            # 음소거 라벨
            sfx_mute_label = font_small.render("OFF", True, (255, 80, 80) if sfx_muted else (120, 120, 120))
            ctx.screen.blit(sfx_mute_label, (sfx_checkbox_x + checkbox_size + 5, sfx_checkbox_y + 2))

        # (미니멀 구성: UI/환경 슬라이더 제거)

        button_hover = back_button_rect.collidepoint(pygame.mouse.get_pos()) or (focus == "back")
        button_color = (100, 150, 255) if button_hover else (50, 50, 50)
        pygame.draw.rect(ctx.screen, button_color, back_button_rect, border_radius=5)
        pygame.draw.rect(ctx.screen, const.WHITE, back_button_rect, 2, border_radius=5)

        back_text = font_medium.render(_t("settings.back", "뒤로가기"), True, const.WHITE)
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
                    # 컨트롤 스킴 및 타격 사운드 저장
                    settings.set_setting('controls','control_scheme', control_scheme)
                    settings.set_setting('audio', 'paddle_hit_sound', paddle_hit_sound)
                    settings.set_setting('gameplay', 'ball_type', ball_type)
                    settings.set_setting('language', 'language', current_language)
                    settings.save_settings()
                    # 디스플레이 모드 변경 적용
                    try:
                        from pingfighter import switch_display_mode, get_display_mode
                        if display_mode != get_display_mode():
                            switch_display_mode(display_mode)
                    except Exception as _e:
                        print(f"[디스플레이 전환 오류] {_e}")
                    return
                if event.key == pygame.K_TAB:
                    _tab_order = ['sound', 'controls', 'display', 'play', 'language']
                    _tidx = _tab_order.index(current_tab) if current_tab in _tab_order else 0
                    current_tab = _tab_order[(_tidx + 1) % len(_tab_order)]
                    focus = {'sound': 'bgm', 'controls': 'scheme', 'display': 'dispmode', 'play': 'balltype', 'language': 'lang'}.get(current_tab, 'bgm')
                if event.key == pygame.K_LEFT:
                    if current_tab == 'language' and focus == 'lang':
                        _li = LANGUAGE_CODES.index(current_language) if current_language in LANGUAGE_CODES else 0
                        current_language = LANGUAGE_CODES[max(0, _li - 1)]
                        get_localization_manager().set_language(current_language)
                        settings.set_setting('language', 'language', current_language)
                        font_medium = FontStyle.body()
                        font_small = FontStyle.small()
                    elif current_tab == 'controls':
                        if locals().get('focus','bgm') in ('scheme','back'):
                            control_scheme = 'keyboard'
                    elif current_tab == 'display' and focus == 'dispmode':
                        _dm_order = ['fullscreen', 'cinema', 'windowed']
                        _dm_idx = _dm_order.index(display_mode) if display_mode in _dm_order else 0
                        display_mode = _dm_order[max(0, _dm_idx - 1)]
                    elif focus == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume - 0.05)
                        if not bgm_muted:
                            ctx.apply_bgm_volume(current_bgm_volume)
                        selected_slider = "bgm"
                    elif focus == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume - 0.05)
                        if not sfx_muted:
                            current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        selected_slider = "sfx"
                    elif current_tab == 'play' and focus == 'hitsound' and ball_type != 'pingpong':
                        paddle_hit_sound = max(1, paddle_hit_sound - 1)
                        _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(paddle_hit_sound, "PADDLE")
                        _ps = _paddle_sounds.get(_hs_key)
                        if _ps:
                            _ps.set_volume(current_sfx_volume)
                            _ps.play()
                    elif current_tab == 'play' and focus == 'balltype':
                        _bt_order = ["energy", "pingpong"]
                        _bt_idx = _bt_order.index(ball_type) if ball_type in _bt_order else 0
                        ball_type = _bt_order[max(0, _bt_idx - 1)]
                elif event.key == pygame.K_RIGHT:
                    if current_tab == 'language' and focus == 'lang':
                        _li = LANGUAGE_CODES.index(current_language) if current_language in LANGUAGE_CODES else 0
                        current_language = LANGUAGE_CODES[min(len(LANGUAGE_CODES) - 1, _li + 1)]
                        get_localization_manager().set_language(current_language)
                        settings.set_setting('language', 'language', current_language)
                        font_medium = FontStyle.body()
                        font_small = FontStyle.small()
                    elif current_tab == 'controls':
                        if locals().get('focus','bgm') in ('scheme','back'):
                            control_scheme = 'mouse_keyboard'
                    elif current_tab == 'display' and focus == 'dispmode':
                        _dm_order = ['fullscreen', 'cinema', 'windowed']
                        _dm_idx = _dm_order.index(display_mode) if display_mode in _dm_order else 0
                        display_mode = _dm_order[min(len(_dm_order) - 1, _dm_idx + 1)]
                    elif focus == "bgm":
                        current_bgm_volume = clamp_volume(current_bgm_volume + 0.05)
                        if not bgm_muted:
                            ctx.apply_bgm_volume(current_bgm_volume)
                        selected_slider = "bgm"
                    elif focus == "sfx":
                        current_sfx_volume = clamp_volume(current_sfx_volume + 0.05)
                        if not sfx_muted:
                            current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        selected_slider = "sfx"
                    elif current_tab == 'play' and focus == 'hitsound' and ball_type != 'pingpong':
                        paddle_hit_sound = min(3, paddle_hit_sound + 1)
                        _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(paddle_hit_sound, "PADDLE")
                        _ps = _paddle_sounds.get(_hs_key)
                        if _ps:
                            _ps.set_volume(current_sfx_volume)
                            _ps.play()
                    elif current_tab == 'play' and focus == 'balltype':
                        _bt_order = ["energy", "pingpong"]
                        _bt_idx = _bt_order.index(ball_type) if ball_type in _bt_order else 0
                        ball_type = _bt_order[min(len(_bt_order) - 1, _bt_idx + 1)]
                elif event.key == pygame.K_UP:
                    if current_tab == 'language':
                        order = ["lang", "back"]
                    elif current_tab == 'controls':
                        order = ["scheme", "back"]
                    elif current_tab == 'display':
                        order = ["dispmode", "back"]
                    elif current_tab == 'play':
                        order = ["balltype", "hitsound", "back"] if ball_type != "pingpong" else ["balltype", "back"]
                    else:
                        order = ["bgm", "sfx", "back"]
                    focus = order[(order.index(focus) - 1) % len(order)] if focus in order else order[0]
                elif event.key == pygame.K_DOWN:
                    if current_tab == 'language':
                        order = ["lang", "back"]
                    elif current_tab == 'controls':
                        order = ["scheme", "back"]
                    elif current_tab == 'display':
                        order = ["dispmode", "back"]
                    elif current_tab == 'play':
                        order = ["balltype", "hitsound", "back"] if ball_type != "pingpong" else ["balltype", "back"]
                    else:
                        order = ["bgm", "sfx", "back"]
                    focus = order[(order.index(focus) + 1) % len(order)] if focus in order else order[0]
                elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                    if current_tab == 'language' and focus == 'lang':
                        _li = LANGUAGE_CODES.index(current_language) if current_language in LANGUAGE_CODES else 0
                        current_language = LANGUAGE_CODES[(_li + 1) % len(LANGUAGE_CODES)]
                        get_localization_manager().set_language(current_language)
                        settings.set_setting('language', 'language', current_language)
                        font_medium = FontStyle.body()
                        font_small = FontStyle.small()
                    elif current_tab == 'display' and focus == 'dispmode':
                        _dm_order = ['fullscreen', 'cinema', 'windowed']
                        _dm_idx = _dm_order.index(display_mode) if display_mode in _dm_order else 0
                        display_mode = _dm_order[(_dm_idx + 1) % len(_dm_order)]
                    elif current_tab == 'controls' and focus == 'scheme':
                        control_scheme = 'mouse_keyboard' if control_scheme == 'keyboard' else 'keyboard'
                    elif current_tab == 'play' and focus == 'hitsound' and ball_type != 'pingpong':
                        paddle_hit_sound = (paddle_hit_sound % 3) + 1
                        _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(paddle_hit_sound, "PADDLE")
                        _ps = _paddle_sounds.get(_hs_key)
                        if _ps:
                            _ps.set_volume(current_sfx_volume)
                            _ps.play()
                    elif current_tab == 'play' and focus == 'balltype':
                        ball_type = "pingpong" if ball_type == "energy" else "energy"
                    elif focus == "back":
                        ctx.play_button_click_sound()
                        current_bgm_volume = ctx.store_bgm_volume(current_bgm_volume)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        settings.set_setting('controls', 'control_scheme', control_scheme)
                        settings.set_setting('audio', 'paddle_hit_sound', paddle_hit_sound)
                        settings.set_setting('gameplay', 'ball_type', ball_type)
                        settings.save_settings()
                        # 디스플레이 모드 변경 적용
                        try:
                            from pingfighter import switch_display_mode, get_display_mode
                            if display_mode != get_display_mode():
                                switch_display_mode(display_mode)
                        except Exception:
                            pass
                        return
            elif event.type == pygame.MOUSEBUTTONDOWN:
                # 왼쪽 버튼(1)으로만 토글/슬라이더 조작 허용
                if event.button == 1:
                    mouse_pos = pygame.mouse.get_pos()
                    mouse_x = mouse_pos[0]

                    # 탭 클릭 처리
                    if sound_tab_rect.collidepoint(mouse_pos):
                        current_tab = 'sound'
                        focus = 'bgm'
                        continue
                    if ctrl_tab_rect.collidepoint(mouse_pos):
                        current_tab = 'controls'
                        focus = 'scheme'
                        continue
                    if disp_tab_rect.collidepoint(mouse_pos):
                        current_tab = 'display'
                        focus = 'dispmode'
                        continue
                    if play_tab_rect.collidepoint(mouse_pos):
                        current_tab = 'play'
                        focus = 'balltype'
                        continue
                    if lang_tab_rect.collidepoint(mouse_pos):
                        current_tab = 'language'
                        focus = 'lang'
                        continue

                    if back_button_rect.collidepoint(mouse_pos):
                        ctx.play_button_click_sound()
                        current_bgm_volume = ctx.store_bgm_volume(current_bgm_volume)
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                        settings.set_setting('controls', 'control_scheme', control_scheme)
                        settings.set_setting('audio', 'paddle_hit_sound', paddle_hit_sound)
                        settings.set_setting('gameplay', 'ball_type', ball_type)
                        settings.save_settings()
                        # 디스플레이 모드 변경 적용
                        try:
                            from pingfighter import switch_display_mode, get_display_mode
                            if display_mode != get_display_mode():
                                switch_display_mode(display_mode)
                        except Exception:
                            pass
                        return
                    # 컨트롤 탭 처리
                    if current_tab == 'controls':
                        if 'kb_rect' in locals() and kb_rect.collidepoint(mouse_pos):
                            control_scheme = 'keyboard'
                            continue
                        if 'mk_rect' in locals() and mk_rect.collidepoint(mouse_pos):
                            control_scheme = 'mouse_keyboard'
                            continue
                    # 언어 탭 처리
                    if current_tab == 'language':
                        for _lr, _lc, _ll in lang_pills:
                            if _lr.collidepoint(mouse_pos):
                                current_language = _lc
                                get_localization_manager().set_language(current_language)
                                settings.set_setting('language', 'language', current_language)
                                font_medium = FontStyle.body()
                                font_small = FontStyle.small()
                                focus = 'lang'
                                break
                    # 디스플레이 탭 처리
                    if current_tab == 'display':
                        if 'fs_rect' in locals() and fs_rect.collidepoint(mouse_pos):
                            display_mode = 'fullscreen'
                            continue
                        if 'cm_rect' in locals() and cm_rect.collidepoint(mouse_pos):
                            display_mode = 'cinema'
                            continue
                        if 'win_rect' in locals() and win_rect.collidepoint(mouse_pos):
                            display_mode = 'windowed'
                            continue

                    # BGM 체크박스 클릭 처리
                    if current_tab == 'sound' and 'bgm_checkbox_rect' in dir() and bgm_checkbox_rect.collidepoint(mouse_pos):
                        bgm_muted = not bgm_muted
                        set_bgm_muted(bgm_muted)
                        # 실제 BGM 음소거 적용
                        if bgm_muted:
                            pygame.mixer.music.set_volume(0)
                        else:
                            ctx.apply_bgm_volume(current_bgm_volume)
                        ctx.play_button_click_sound()
                        continue

                    # SFX 체크박스 클릭 처리
                    if current_tab == 'sound' and 'sfx_checkbox_rect' in dir() and sfx_checkbox_rect.collidepoint(mouse_pos):
                        sfx_muted = not sfx_muted
                        set_sfx_muted(sfx_muted)
                        # 실제 SFX 음소거 적용
                        if sfx_muted:
                            for i in range(pygame.mixer.get_num_channels()):
                                pygame.mixer.Channel(i).set_volume(0)
                        else:
                            for i in range(pygame.mixer.get_num_channels()):
                                pygame.mixer.Channel(i).set_volume(current_sfx_volume)
                        ctx.play_button_click_sound()
                        continue

                    # 플레이 탭 - 공 선택 및 타격 사운드 클릭
                    if current_tab == 'play':
                        for _br, _bv, _bl in ball_pills:
                            if _br.collidepoint(mouse_pos):
                                ball_type = _bv
                                focus = "balltype"
                                break
                        if ball_type != "pingpong":
                            for _hr, _hv, _hl in hit_pills:
                                if _hr.collidepoint(mouse_pos):
                                    paddle_hit_sound = _hv
                                    focus = "hitsound"
                                    _hs_key = {1: "PADDLE", 2: "PADDLE2", 3: "PADDLE3"}.get(_hv, "PADDLE")
                                    _ps = _paddle_sounds.get(_hs_key)
                                    if _ps:
                                        _ps.set_volume(current_sfx_volume)
                                        _ps.play()
                                    break

                    bgm_slider_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 10, slider_width, slider_height + 20)
                    if current_tab == 'sound' and (bgm_slider_rect.collidepoint(mouse_pos) or ('bgm_handle_rect' in locals() and bgm_handle_rect.collidepoint(mouse_pos))):
                        selected_slider = "bgm"
                        dragging = True
                        relative_x = mouse_x - bgm_slider_x
                        current_bgm_volume = clamp_volume(relative_x / slider_width)
                        if not bgm_muted:
                            ctx.apply_bgm_volume(current_bgm_volume)

                    sfx_slider_rect = pygame.Rect(sfx_slider_x, sfx_slider_y - 10, slider_width, slider_height + 20)
                    if current_tab == 'sound' and (sfx_slider_rect.collidepoint(mouse_pos) or ('sfx_handle_rect' in locals() and sfx_handle_rect.collidepoint(mouse_pos))):
                        selected_slider = "sfx"
                        dragging = True
                        relative_x = mouse_x - sfx_slider_x
                        current_sfx_volume = clamp_volume(relative_x / slider_width)
                        if not sfx_muted:
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
                    if not bgm_muted:
                        ctx.apply_bgm_volume(current_bgm_volume)
                elif current_tab == 'sound' and selected_slider == "sfx":
                    relative_x = mouse_x - sfx_slider_x
                    current_sfx_volume = clamp_volume(relative_x / slider_width)
                    if not sfx_muted:
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                # (미니멀 구성: UI/ENV 슬라이더 제거)

            elif event.type == pygame.MOUSEWHEEL:
                mouse_pos = pygame.mouse.get_pos()
                bgm_slider_rect = pygame.Rect(bgm_slider_x, bgm_slider_y - 10, slider_width, slider_height + 20)
                sfx_slider_rect = pygame.Rect(sfx_slider_x, sfx_slider_y - 10, slider_width, slider_height + 20)

                if current_tab == 'sound' and (bgm_slider_rect.collidepoint(mouse_pos) or selected_slider == "bgm"):
                    current_bgm_volume = clamp_volume(current_bgm_volume + event.y * 0.02)
                    if not bgm_muted:
                        ctx.apply_bgm_volume(current_bgm_volume)
                    selected_slider = "bgm"
                elif current_tab == 'sound' and (sfx_slider_rect.collidepoint(mouse_pos) or selected_slider == "sfx"):
                    current_sfx_volume = clamp_volume(current_sfx_volume + event.y * 0.02)
                    if not sfx_muted:
                        current_sfx_volume = ctx.set_sfx_volume(current_sfx_volume)
                    selected_slider = "sfx"
                # (미니멀 구성: UI/ENV 휠 조정 제거)

    ctx.store_bgm_volume(current_bgm_volume)
    ctx.set_sfx_volume(current_sfx_volume)
    settings.set_setting('audio', 'paddle_hit_sound', paddle_hit_sound)
    settings.set_setting('gameplay', 'ball_type', ball_type)
    settings.set_setting('language', 'language', current_language)
    settings.save_settings()
