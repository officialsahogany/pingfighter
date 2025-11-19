import math
import random
from typing import Callable, List, Tuple

import pygame

from pixel_font_manager import FontStyle, get_font
from bgm_manager import bgm_manager as global_bgm_manager

ANIMATION_DURATION_MS = 2000
SMOKE_PARTICLE_COUNT = 18
COLOR_OVERLAY_BG = (12, 20, 35, 220)
COLOR_MENU_BG = (26, 36, 62, 220)
COLOR_MENU_BORDER = (80, 110, 170, 255)
COLOR_MENU_ACTIVE = (115, 160, 255, 235)
COLOR_DETAIL_BG = (18, 24, 40, 235)
COLOR_DETAIL_BORDER = (90, 120, 190, 140)
COLOR_DETAIL_BORDER_FOCUS = (135, 175, 255, 210)
COLOR_SCROLL_TRACK = (30, 42, 70, 180)
COLOR_SCROLL_HANDLE = (145, 170, 220, 220)
COLOR_TEXT_MAIN = (235, 240, 255)
COLOR_TEXT_DIM = (170, 185, 210)
COLOR_KEY_BG = (255, 215, 120)
COLOR_KEY_TEXT = (20, 30, 50)

CHARACTER_LABELS = {
    "soldier": "코만도",
    "blacksmith": "발토르",
    "smasher": "스매셔",
    "optimus": "옵티머스",
    "normal": "일반 플레이어",
}

TUTORIAL_LIBRARY: dict[str, List[dict]] = {
    "soldier": [
        {
            "id": "firearms",
            "title": "화기류 사용법",
            "summary": "주무기 발사와 안전 제한",
            "keys": ["SPACE"],
            "details": [
                "SPACE 키를 눌러 현재 장비한 화기를 발사합니다.",
                "코만도는 기본 화기류로 권총이 지급되며 다른 화기류들은 물자보급을 통하여 얻을 수 있습니다",
                "현재 사용중인 화기류는 왼쪽 하단에 화기류박스를 통해 확인할 수 있으며 하단에 남은 탄환도 표시됩니다",
            ],
            "animation": "fire",
        },
        {
            "id": "reload",
            "title": "권총 재장전",
            "summary": "빈 탄창을 SPACE로 채우기",
            "keys": ["SPACE"],
            "details": [
                "탄약이 0이 된 상태에서 SPACE를 누르면 2초간 재장전이 진행되며 스킬 게이지 150을 소비합니다.",
                "재장전 중에는 사격이 불가능하고 총알을 재장전하는 모션이 표시됩니다.",
                "권총을 제외한 다른 화기류들은 물자보급에서 획득한 탄약상자, 비상보급스킬로만 재장전이 가능합니다."
                
            ],
            "animation": "reload",
        },
        {
            "id": "weapon_switch",
            "title": "화기류 교체",
            "summary": "짧게 눌러 순환, 길게 눌러 메뉴",
            "keys": ["↑"],
            "details": [
                "↑ 키를 입력하면 보유 중인 화기가 순서대로 순환합니다. 전투 중 급히 무기를 바꿀 때 가장 빠른 방법입니다.",
                "↑ 키를 약 0.3초 이상 누르고 있으면 무기 선택 메뉴가 열립니다. 숫자키 1~5으로 원하는 무기를 고르세요.",
                
            ],
            "animation": "switch",
        },
        {
            "id": "supply_drop",
            "title": "물자보급 요청",
            "summary": "↓키 홀드로 보급상자 호출",
            "keys": ["↓ (1초 홀드)", "게이지 350"],
            "details": [
                "↓ 키를 1초 이상 누르면 무전기가 켜지고, 스킬 게이지 350을 소비해 보급 비행기를 호출합니다.",
                "호출 도중에는 플레이어가 잠시 움직일 수 없습니다",
                "보급상자에서 탄약상자, 화기류, 아이템 등 전투에 유용한 다양한 물자를 획득할 수 있습니다.",
            ],
            "animation": "supply",
        },
        {
            "id": "emergency",
            "title": "비상보급",
            "summary": "↓ ↓ 더블탭으로 즉시 장전",
            "keys": ["↓ ↓", "게이지 500"],
            "details": [
                "↓ 키를 빠르게 두 번 입력하면 스킬 게이지 500을 소비해 현재 착용중인 화기류의 탄약을 즉시 가득 채웁니다.",
                "스테이지마다 1회만 사용할 수 있습니다",
                
                
            ],
            "animation": "emergency",
        },
    ],
    "blacksmith": [
        {
            "id": "thor_shield",
            "title": "토르쉴드",
            "summary": "↑로 전개, SPACE+방향으로 반격",
            "keys": ["↑", "SPACE+←/→"],
            "details": [
                "↑ 키를 눌러 토르쉴드를 펼치거나 접습니다. 직접 공을 타격할때보다 많은 양의 게이지를 얻을 수 있어 사실상 발토르의 유일한 게이지 획득 수단입니다.",
                " 토르쉴드로 공을 방어시 우측 하단에 표시된 방패내구도가 1개 소모되며 5개를 소모할 경우 자동으로 접힙니다 내구도는 시간이 지나면 1칸씩 회복됩니다.",
                "이동속도가 매우 느려지며 대쉬 ,건설 ,아이템사용 ,포탑수동조작 ,해머쇼크발동 등 모든 조작에 제한이 생깁니다.",
                "토르쉴드를 펼친 상태에서 SPACE와 ← 혹은 →키를 동시에 누르면 해당 방향으로 스윙을 합니다",
                "공에 닿을 때 동시에 타이밍에 맞춰 ↑키를 눌러 방패를 접으면 게이지만 증가하고 방패내구도는 소모가 되지않는 blocking이 가능합니다"
            ],
            "animation": "thor_shield",
        },
        {
            "id": "build_menu",
            "title": "건설 메뉴",
            "summary": "↓ 홀드로 청사진 선택",
            "keys": ["↓ (0.5초 홀드)", "1/2", "ESC/↓"],
            "details": [
                "↓ 키를 약 0.5초 동안 누르면 발토르 건설 메뉴가 열리며 현재 설치 가능한 설비를 확인할 수 있습니다.",
                "숫자 1은 포탑, 2는 디바인스톤을 선택합니다. 선택 즉시 플레이어 발밑에 청사진이 생성됩니다.",
                "ESC 또는 ↓ 키로 메뉴를 닫을 수 있으며, 건설 메뉴가 열린 동안에는 스페이스·아이템 입력이 잠시 비활성화됩니다.",
            ],
            "animation": "blacksmith_build",
        },
        {
            "id": "turret",
            "title": "포탑",
            "summary": "↓ 유지로 건설, SPACE로 수동 발사",
            "keys": ["건설→1", "↓ 유지", "SPACE"],
            "details": [
                "포탑 청사진 위에서 ↓ 키를 계속 누르면 해머질이 진행되며 스킬 게이지가 초당 45씩 소모되어 약 5초(220 게이지) 만에 완성됩니다.",
                "건설 범위는 플레이어 기준 좌우 70px이므로 청사진 중앙에 맞춰 서야 진행도가 올라갑니다. 완성 후에는 5초 간격으로 자동 미사일을 발사합니다.",
                "포탑 위에서 SPACE를 짧게 누르면 게이지 60을 소모해 즉시 미사일을 발사합니다(쿨다운 0.6초). 토르쉴드가 열린 동안에는 수동 발사가 막힙니다.",
                "완성된 포탑 위에서 다시 ↓ 키를 유지하면 강화 게이지가 쌓입니다. 약 10초 동안 게이지 250을 소모하면 '강화 포탑'으로 진화합니다.",
                "강화 포탑 상태에서만 포탑 앞에서 ↓ 키로 게이지를 꽉 채운 뒤 SPACE를 눌러 오버드라이브(디바인스톤 활성 시 메가드라이브)를 발동할 수 있습니다.",
            ],
            "animation": "blacksmith_turret",
        },
        {
            "id": "divine_stone",
            "title": "디바인스톤",
            "summary": "공 튕기고 토르쉴드 지원",
            "keys": ["건설→2", "↓ 유지"],
            "details": [
                "청사진 위에서 ↓ 키를 유지하면 스킬 게이지가 초당 45씩 소모되어 약 7초(330 게이지) 만에 디바인스톤이 완성됩니다.",
                "완성된 디바인스톤은 공을 튕겨내고 체력이 3칸입니다. 파괴되면 다시 건설해야 하며, 전투 중 자동으로 맵 중앙 근처에 고정됩니다.",
                "활성 상태에서는 토르쉴드 회복 주기가 7초→5초로 단축되고 해머쇼크 사용 조건을 충족시킵니다.",
            ],
            "animation": "blacksmith_divine",
        },
        {
            "id": "hammer_shock",
            "title": "해머쇼크",
            "summary": "디바인스톤 + SPACE 홀드",
            "keys": ["SPACE 홀드", "SPACE 릴리즈", "(디바인스톤 활성)"],
            "details": [
                "디바인스톤이 살아 있고 스킬 게이지가 200 이상이면 SPACE를 누르는 순간 해머쇼크 차지가 시작됩니다. 토르쉴드가 열려 있으면 차지가 막힙니다.",
                "SPACE를 유지한 시간에 따라 단계가 상승합니다: 1초(200 게이지), 2초(260), 3초(320). 게이지가 부족하면 해당 단계로 넘어가지 않습니다.",
                "SPACE를 놓으면 해머를 투척해 충격파를 일으키며 큰 피해와 넉백을 줍니다. 포탑 옆에서 수동 발사를 건너뛰고 해머쇼크를 쓰려면 SPACE를 누를 때 ↓ 키를 함께 눌러 주세요.",
            ],
            "animation": "blacksmith_hammer_shock",
        },
    ],
    "smasher": [
        {
            "id": "drive",
            "title": "드라이브",
            "summary": "←/→ + SPACE로 방향 드라이브",
            "keys": ["SPACE+←/→", "게이지 160"],
            "details": [
                "특수 게이지가 160 이상일 때 퍼펙트 타이밍 링이 점등하면 드라이브를 준비할 수 있습니다.",
                "← 또는 →와 SPACE를 동시에 눌러 원하는 방향으로 공을 찍어내면 드라이브가 발동하며 게이지 160을 소비합니다.",
                "발동 후 공은 연두색 궤적과 함께 속도가 크게 증가하고, 보스에 적중하면 위쪽 잠금이 해제되며 드라이브 카운터가 초기화됩니다.",
                "연속 드라이브를 노릴 경우 전역 쿨다운과 게이지 회복 시간을 염두에 두고 타이밍을 맞춰주세요.",
            ],
            "animation": "smasher_drive",
        },
        {
            "id": "power_smash",
            "title": "파워스매싱",
            "summary": "SPACE 홀드로 3방향 폭발",
            "keys": ["SPACE 홀드", "게이지 350", "←/→/직선"],
            "details": [
                "퍼펙트 타이밍 윈도우에서 SPACE를 계속 유지하고 게이지가 350 이상이면 파워스매싱이 준비됩니다.",
                "←을 유지하면 왼쪽 곡선, →을 유지하면 오른쪽 곡선, 방향키 없이 SPACE만 유지하면 직선 파워스매싱이 발사됩니다.",
                "발동 순간 짧은 정지 후 공을 강제로 맞춰 폭발적인 속도로 쏘며, 보스에게 큰 피해와 넉백을 부여합니다.",
                "성공 시 쇼트 카운터와 드라이브 잠금이 모두 초기화되어 다음 연계를 즉시 준비할 수 있습니다.",
            ],
            "animation": "smasher_power",
        },
        {
            "id": "short",
            "title": "쇼트",
            "summary": "↑로 수직 쇼트 & 드라이브 버프",
            "keys": ["↑", "게이지 100"],
            "details": [
                "공이 패들과 맞닿는 순간 ↑ 키(또는 W)를 입력하면 게이지 100을 소비해 수직 쇼트를 발동합니다.",
                "공은 잠시 수직으로 치솟은 뒤 보스 방향으로 곡선을 그리며, 성공 시 쇼트 카운터가 활성화됩니다.",
                "쇼트 카운터 동안 드라이브나 파워스매싱을 적중시키면 추가 속도 보너스와 전용 연출이 적용됩니다.",
                "서브 중이나 스톱워치 정지 상태에서는 발동하지 않으므로 조건을 확인하고 사용하세요.",
            ],
            "animation": "smasher_short",
        },
    ],
    "default": [
        {
            "id": "coming_soon",
            "title": "튜토리얼 준비 중",
            "summary": "지니 데이터가 곧 업데이트됩니다",
            "keys": [],
            "details": [
                "선택한 캐릭터에 대한 전용 튜토리얼이 아직 준비되지 않았습니다.",
                "최신 패치 노트를 확인하거나 기본 조작법을 다시 살펴보세요.",
            ],
            "animation": "idle",
        }
    ],
}


def _wrap_text(font: pygame.font.Font, text: str, max_width: int) -> List[str]:
    words = text.split()
    if not words:
        return [""]
    lines: List[str] = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        if font.size(candidate)[0] <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


class GenieAssistant:
    """지니 애니메이션을 포함한 캐릭터별 튜토리얼 오버레이."""

    def __init__(self) -> None:
        self.active: bool = False
        self.phase: str = "inactive"  # inactive, animation, menu
        self.elapsed_ms: float = 0.0
        self.screen_size: Tuple[int, int] = (0, 0)
        self.overlay_surface: pygame.Surface | None = None
        self.smoke_particles: List[dict] = []

        self.character_type: str = "normal"
        self.tutorial_items: List[dict] = []
        self.selected_index: int = 0
        self.menu_item_rects: List[pygame.Rect] = []

        self.title_font = FontStyle.large()
        self.menu_font = FontStyle.body()
        self.detail_font = get_font(20)
        self.small_font = get_font(16)
        self.key_font = get_font(18)

        self.previous_bgm: str | None = None
        self.previous_bgm_was_playing: bool = False

        self.detail_scroll_offset: float = 0.0
        self.detail_scroll_direction: int = 1
        self.detail_scroll_wait: float = 0.0
        self.detail_scroll_pause: float = 4000.0  # ms 대기
        self.detail_scroll_speed: float = 26.0  # px/sec
        self.detail_focus: bool = False
        self.detail_manual_scroll: bool = False
        self.detail_scroll_input: int = 0
        self.detail_manual_scroll_speed: float = 220.0
        self._detail_lines: List[dict] = []
        self._detail_total_height: float = 0.0
        self._detail_view_height: float = 0.0
        self._detail_layout_key: Tuple[str | None, int] | None = None
        self.preview_renderer: Callable[[pygame.Surface, pygame.Rect, str, int], bool] | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def is_active(self) -> bool:
        return self.active

    def activate(self, screen: pygame.Surface, character_type: str | None) -> None:
        if self.active:
            self.deactivate()
        self.previous_bgm = global_bgm_manager.current_bgm
        self.previous_bgm_was_playing = global_bgm_manager.is_playing()
        self.active = True
        self.phase = "animation"
        self.elapsed_ms = 0.0
        self.screen_size = screen.get_size()
        self.overlay_surface = pygame.Surface(self.screen_size, pygame.SRCALPHA)
        self.character_type = character_type or "normal"
        self.tutorial_items = self._resolve_tutorials(self.character_type)
        self.selected_index = 0
        self.menu_item_rects = []
        self._init_smoke_particles()
        self._reset_detail_scroll(reset_layout=True)

        try:
            if (
                global_bgm_manager.current_bgm != 'tutorial_genie'
                or not global_bgm_manager.is_playing()
            ):
                global_bgm_manager.play_bgm('tutorial_genie')
        except Exception:
            pass

    def deactivate(self) -> None:
        try:
            if self.previous_bgm_was_playing and self.previous_bgm:
                global_bgm_manager.play_bgm(self.previous_bgm)
            elif not self.previous_bgm_was_playing:
                global_bgm_manager.stop_bgm()
        except Exception:
            pass

        self.previous_bgm = None
        self.previous_bgm_was_playing = False

        self.active = False
        self.phase = "inactive"
        self.overlay_surface = None
        self.smoke_particles.clear()
        self.detail_focus = False
        self.detail_manual_scroll = False
        self.detail_scroll_input = 0

    def set_preview_renderer(
        self,
        renderer: Callable[[pygame.Surface, pygame.Rect, str, int], bool] | None,
    ) -> None:
        """지니 애니메이션 프리뷰를 커스터마이징하기 위한 렌더러를 설정한다."""

        self.preview_renderer = renderer

    def update(self, dt_ms: float) -> None:
        if not self.active:
            return
        self.elapsed_ms += dt_ms

        if self.phase == "animation" and self.elapsed_ms >= ANIMATION_DURATION_MS:
            self._enter_menu_phase()

        self._update_smoke_particles(dt_ms)

        if (
            self.phase == "menu"
            and self._detail_total_height > 0
            and self._detail_view_height > 0
            and not self.detail_focus
            and not self.detail_manual_scroll
        ):
            overflow = self._detail_total_height - self._detail_view_height
            if overflow > 4:
                if self.detail_scroll_wait < self.detail_scroll_pause:
                    self.detail_scroll_wait = min(self.detail_scroll_pause, self.detail_scroll_wait + dt_ms)
                else:
                    step = self.detail_scroll_speed * (dt_ms / 1000.0) * self.detail_scroll_direction
                    self.detail_scroll_offset += step
                    max_offset = max(0.0, overflow)
                    if self.detail_scroll_offset >= max_offset:
                        self.detail_scroll_offset = max_offset
                        self.detail_scroll_direction = -1
                        self.detail_scroll_wait = 0.0
                    elif self.detail_scroll_offset <= 0.0:
                        self.detail_scroll_offset = 0.0
                        self.detail_scroll_direction = 1
                        self.detail_scroll_wait = 0.0
            else:
                if self.detail_scroll_offset != 0.0:
                    self.detail_scroll_offset = 0.0
                self.detail_scroll_direction = 1
                self.detail_scroll_wait = 0.0
        else:
            if not self.detail_focus and not self.detail_manual_scroll:
                if self.detail_scroll_offset != 0.0:
                    self.detail_scroll_offset = 0.0
                self.detail_scroll_direction = 1
                self.detail_scroll_wait = 0.0

        if (
            self.phase == "menu"
            and self.detail_focus
            and self.detail_scroll_input != 0
            and self._detail_total_height > self._detail_view_height
            and self._detail_view_height > 0
        ):
            try:
                mods = pygame.key.get_mods()
            except pygame.error:
                mods = 0
            speed_multiplier = 2.0 if mods & pygame.KMOD_SHIFT else 1.0
            manual_speed = self.detail_manual_scroll_speed * speed_multiplier
            delta = manual_speed * (dt_ms / 1000.0) * self.detail_scroll_input
            if delta:
                self._scroll_detail_by(delta)

    def draw(self, surface: pygame.Surface) -> None:
        if not self.active or self.overlay_surface is None:
            return

        bg_surface = self.overlay_surface
        bg_surface.fill(COLOR_OVERLAY_BG)

        lamp_center = (self.screen_size[0] // 2, self.screen_size[1] // 2 + 160)
        progress = min(1.0, self.elapsed_ms / ANIMATION_DURATION_MS) if ANIMATION_DURATION_MS else 1.0
        self._draw_lamp(bg_surface, lamp_center, progress)
        self._draw_smoke(bg_surface, lamp_center, progress)

        if self.phase == "animation":
            self._draw_animation_intro(bg_surface)
        else:
            self._draw_tutorial_menu(bg_surface)

        surface.blit(bg_surface, (0, 0))

    def handle_event(self, event: pygame.event.Event) -> bool:
        if not self.active:
            return False

        if event.type == pygame.KEYDOWN:
            mods = event.mod if hasattr(event, "mod") else 0
            if event.key in (pygame.K_ESCAPE, pygame.K_t):
                self.deactivate()
                return True
            if self.phase == "animation" and event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._enter_menu_phase()
                return True
            if self.phase == "menu":
                if self.detail_focus:
                    if event.key in (pygame.K_LEFT, pygame.K_a) or (event.key == pygame.K_TAB and (mods & pygame.KMOD_SHIFT)):
                        self.detail_focus = False
                        self.detail_scroll_wait = 0.0
                        self.detail_scroll_direction = 1
                        self.detail_scroll_input = 0
                        return True
                    if event.key in (pygame.K_UP, pygame.K_w):
                        self._scroll_detail_by(-self._detail_scroll_step())
                        self.detail_scroll_input = -1
                        return True
                    if event.key in (pygame.K_DOWN, pygame.K_s):
                        self._scroll_detail_by(self._detail_scroll_step())
                        self.detail_scroll_input = 1
                        return True
                    if event.key == pygame.K_PAGEUP:
                        self._scroll_detail_by(-self._page_scroll_step())
                        self.detail_scroll_input = 0
                        return True
                    if event.key == pygame.K_PAGEDOWN:
                        self._scroll_detail_by(self._page_scroll_step())
                        self.detail_scroll_input = 0
                        return True
                    if event.key == pygame.K_HOME:
                        self._set_detail_scroll_ratio(0.0)
                        self.detail_scroll_input = 0
                        return True
                    if event.key == pygame.K_END:
                        self._set_detail_scroll_ratio(1.0)
                        self.detail_scroll_input = 0
                        return True
                else:
                    if event.key in (pygame.K_RIGHT, pygame.K_d) or (event.key == pygame.K_TAB and not (mods & pygame.KMOD_SHIFT)):
                        self.detail_focus = True
                        self.detail_scroll_wait = 0.0
                        self.detail_scroll_direction = 1
                        self.detail_scroll_input = 0
                        return True
                    if event.key in (pygame.K_UP, pygame.K_w):
                        self._move_selection(-1)
                        return True
                    if event.key in (pygame.K_DOWN, pygame.K_s):
                        self._move_selection(1)
                        return True
                if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                    # 메뉴에서는 상세 패널이 항상 열려 있으므로 입력을 소비만 한다.
                    return True
        elif event.type == pygame.KEYUP:
            if self.phase == "menu" and self.detail_focus:
                if event.key in (pygame.K_UP, pygame.K_w, pygame.K_DOWN, pygame.K_s):
                    if self.detail_scroll_input != 0:
                        self.detail_scroll_input = 0
                    return True
                if event.key == pygame.K_TAB:
                    return True
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if self.phase == "animation":
                self._enter_menu_phase()
                return True
            if self.phase == "menu" and event.button == 1:
                pos = event.pos
                for idx, rect in enumerate(self.menu_item_rects):
                    if rect.collidepoint(pos):
                        if idx != self.selected_index:
                            self.selected_index = idx
                            self._reset_detail_scroll(reset_layout=True)
                        return True
                # 메뉴 밖 클릭은 닫기
                self.deactivate()
                return True

        elif event.type == pygame.MOUSEMOTION and self.phase == "menu":
            for idx, rect in enumerate(self.menu_item_rects):
                if rect.collidepoint(event.pos):
                    if idx != self.selected_index:
                        self.selected_index = idx
                        self._reset_detail_scroll(reset_layout=True)
                    break
        return True

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _resolve_tutorials(self, character_type: str) -> List[dict]:
        if character_type in TUTORIAL_LIBRARY:
            return list(TUTORIAL_LIBRARY[character_type])
        return list(TUTORIAL_LIBRARY["default"])

    def _enter_menu_phase(self) -> None:
        self.phase = "menu"
        self.elapsed_ms = max(self.elapsed_ms, float(ANIMATION_DURATION_MS))

    def _move_selection(self, delta: int) -> None:
        if not self.tutorial_items:
            return
        self.selected_index = (self.selected_index + delta) % len(self.tutorial_items)
        self._reset_detail_scroll(reset_layout=True)

    def _init_smoke_particles(self) -> None:
        self.smoke_particles = []
        for _ in range(SMOKE_PARTICLE_COUNT):
            self.smoke_particles.append(
                {
                    "delay": random.uniform(0, ANIMATION_DURATION_MS * 0.8),
                    "life": random.uniform(750, 1400),
                    "born": 0.0,
                    "x": random.uniform(-30, 30),
                    "radius": random.uniform(8, 22),
                }
            )

    def _update_smoke_particles(self, dt_ms: float) -> None:
        for particle in self.smoke_particles:
            particle["born"] += dt_ms
            total_life = particle["delay"] + particle["life"]
            if particle["born"] > total_life:
                particle["born"] = 0.0
                particle["delay"] = random.uniform(0, ANIMATION_DURATION_MS * 0.5)
                particle["life"] = random.uniform(750, 1400)
                particle["x"] = random.uniform(-30, 30)
                particle["radius"] = random.uniform(8, 22)

    def _draw_animation_intro(self, surface: pygame.Surface) -> None:
        width, height = self.screen_size
        title = self.title_font.render("지니 전술 훈련", True, COLOR_TEXT_MAIN)
        title_rect = title.get_rect(center=(width // 2, height // 2 - 120))
        surface.blit(title, title_rect)

        character_label = CHARACTER_LABELS.get(self.character_type, "전투원")
        subtitle_font = FontStyle.body()
        subtitle = subtitle_font.render(f"{character_label}용 지침을 준비합니다...", True, COLOR_TEXT_DIM)
        subtitle_rect = subtitle.get_rect(center=(width // 2, height // 2 - 70))
        surface.blit(subtitle, subtitle_rect)

        hint = self.small_font.render("SPACE/ENTER로 건너뛰기", True, COLOR_TEXT_DIM)
        hint_rect = hint.get_rect(center=(width // 2, height // 2 - 20))
        surface.blit(hint, hint_rect)

    def _draw_tutorial_menu(self, surface: pygame.Surface) -> None:
        width, height = self.screen_size
        header_y = 70

        header = self.title_font.render("지니 전술 훈련", True, COLOR_TEXT_MAIN)
        surface.blit(header, header.get_rect(midtop=(width // 2, header_y)))

        character_label = CHARACTER_LABELS.get(self.character_type, "전투원")
        sub = self.small_font.render(f"코만도 지침" if self.character_type == "soldier" else f"{character_label} 지침", True, COLOR_TEXT_DIM)
        surface.blit(sub, sub.get_rect(midtop=(width // 2, header_y + 48)))

        spacing = 36
        min_padding = 40
        menu_width = max(300, int(width * 0.3))
        detail_width = max(420, int(width * 0.4))
        total_width = menu_width + detail_width + spacing

        if total_width > width - 2 * min_padding:
            detail_width = width - 2 * min_padding - menu_width - spacing
            if detail_width < 360:
                detail_width = 360
                menu_width = width - 2 * min_padding - spacing - detail_width
                menu_width = max(260, menu_width)
                detail_width = width - 2 * min_padding - spacing - menu_width

        container_left = max(min_padding, (width - (menu_width + detail_width + spacing)) // 2)
        menu_rect = pygame.Rect(container_left, header_y + 90, menu_width, height - (header_y + 180))
        detail_rect = pygame.Rect(menu_rect.right + spacing, menu_rect.top, detail_width, menu_rect.height)

        pygame.draw.rect(surface, COLOR_MENU_BG, menu_rect, border_radius=18)
        pygame.draw.rect(surface, COLOR_MENU_BORDER, menu_rect, width=2, border_radius=18)

        pygame.draw.rect(surface, COLOR_DETAIL_BG, detail_rect, border_radius=18)
        detail_border = COLOR_DETAIL_BORDER_FOCUS if self.detail_focus else COLOR_DETAIL_BORDER
        pygame.draw.rect(surface, detail_border, detail_rect, width=2, border_radius=18)

        self._draw_menu_items(surface, menu_rect)
        self._draw_detail_panel(surface, detail_rect)

        footer_text = self.small_font.render("ESC 또는 U: 닫기", True, COLOR_TEXT_DIM)
        surface.blit(footer_text, footer_text.get_rect(midbottom=(width // 2, height - 40)))

    def _draw_menu_items(self, surface: pygame.Surface, menu_rect: pygame.Rect) -> None:
        items = self.tutorial_items
        self.menu_item_rects = []
        if not items:
            empty_text = self.menu_font.render("튜토리얼이 없습니다", True, COLOR_TEXT_DIM)
            surface.blit(empty_text, empty_text.get_rect(center=menu_rect.center))
            return

        item_height = 72
        padding_y = 12
        start_y = menu_rect.top + 24
        inner_x = menu_rect.left + 20
        inner_width = menu_rect.width - 40

        for idx, item in enumerate(items):
            rect = pygame.Rect(inner_x, start_y + idx * (item_height + padding_y), inner_width, item_height)
            if rect.bottom > menu_rect.bottom - 24:
                break
            is_selected = idx == self.selected_index
            bg_color = COLOR_MENU_ACTIVE if is_selected else (20, 28, 48, 210)
            pygame.draw.rect(surface, bg_color, rect, border_radius=14)
            pygame.draw.rect(surface, COLOR_MENU_BORDER, rect, width=1, border_radius=14)

            index_text = self.small_font.render(f"{idx + 1:02}", True, COLOR_TEXT_DIM)
            surface.blit(index_text, index_text.get_rect(midleft=(rect.left + 12, rect.centery)))

            title_surface = self.menu_font.render(item["title"], True, COLOR_TEXT_MAIN if is_selected else COLOR_TEXT_DIM)
            surface.blit(title_surface, title_surface.get_rect(midleft=(rect.left + 58, rect.centery - 12)))

            keys = item.get("keys", [])
            if keys:
                key_x = rect.left + 58
                key_y = rect.centery + 16
                for key in keys[:2]:
                    key_rect = pygame.Rect(key_x, key_y, self.key_font.size(key)[0] + 16, 24)
                    pygame.draw.rect(surface, COLOR_KEY_BG, key_rect, border_radius=8)
                    pygame.draw.rect(surface, (255, 255, 255), key_rect, width=1, border_radius=8)
                    key_surface = self.key_font.render(key, True, COLOR_KEY_TEXT)
                    surface.blit(key_surface, key_surface.get_rect(center=key_rect.center))
                    key_x += key_rect.width + 8

            self.menu_item_rects.append(rect)

    def _draw_detail_panel(self, surface: pygame.Surface, detail_rect: pygame.Rect) -> None:
        if not self.tutorial_items:
            info = self.menu_font.render("지침이 준비되지 않았습니다", True, COLOR_TEXT_DIM)
            surface.blit(info, info.get_rect(center=detail_rect.center))
            return

        item = self.tutorial_items[self.selected_index]
        title_surface = self.menu_font.render(item["title"], True, COLOR_TEXT_MAIN)
        surface.blit(title_surface, title_surface.get_rect(topleft=(detail_rect.left + 24, detail_rect.top + 24)))

        summary_surface = self.small_font.render(item.get("summary", ""), True, COLOR_TEXT_DIM)
        surface.blit(summary_surface, summary_surface.get_rect(topleft=(detail_rect.left + 24, detail_rect.top + 60)))

        keys = item.get("keys", [])
        if keys:
            key_x = detail_rect.left + 24
            key_y = detail_rect.top + 92
            for key in keys:
                badge_width = self.key_font.size(key)[0] + 20
                badge_rect = pygame.Rect(key_x, key_y, badge_width, 28)
                pygame.draw.rect(surface, COLOR_KEY_BG, badge_rect, border_radius=10)
                pygame.draw.rect(surface, (255, 255, 255), badge_rect, width=1, border_radius=10)
                key_surface = self.key_font.render(key, True, COLOR_KEY_TEXT)
                surface.blit(key_surface, key_surface.get_rect(center=badge_rect.center))
                key_x += badge_rect.width + 10

        animation_height = 140
        animation_rect = pygame.Rect(
            detail_rect.left + 24,
            detail_rect.top + 132,
            detail_rect.width - 48,
            animation_height,
        )
        self._draw_animation_preview(surface, animation_rect, item.get("animation"))

        text_top = animation_rect.bottom + 20
        scrollbar_width = 12
        scrollbar_gap = 8
        text_rect = pygame.Rect(
            detail_rect.left + 28,
            text_top,
            detail_rect.width - 56 - scrollbar_width - scrollbar_gap,
            detail_rect.bottom - text_top - 24,
        )
        scrollbar_rect = pygame.Rect(
            text_rect.right + scrollbar_gap,
            text_rect.top,
            scrollbar_width,
            text_rect.height,
        )
        self._detail_view_height = text_rect.height
        self._update_detail_layout(item, text_rect.width)
        self._draw_detail_text(surface, text_rect)
        self._draw_detail_scrollbar(surface, scrollbar_rect)

        hint_color = COLOR_TEXT_MAIN if self.detail_focus else COLOR_TEXT_DIM
        hint_surface = self.small_font.render("←: 목록   ↑↓: 스크롤", True, hint_color)
        hint_pos = (detail_rect.left + 24, detail_rect.bottom - 28)
        surface.blit(hint_surface, hint_pos)

    def _draw_detail_text(self, surface: pygame.Surface, text_rect: pygame.Rect) -> None:
        if not self._detail_lines:
            return

        y = text_rect.top - self.detail_scroll_offset
        fade_top = 36
        fade_bottom = 48
        top_bound = text_rect.top - fade_top
        bottom_bound = text_rect.bottom + fade_bottom

        for entry in self._detail_lines:
            text = entry["text"]
            height = entry["height"]

            if text is None:
                y += height
                continue

            if y + height < top_bound:
                y += height
                continue

            if y > bottom_bound:
                break

            line_surface = self.detail_font.render(text, True, COLOR_TEXT_MAIN)

            alpha = 255
            if y < text_rect.top:
                if y <= top_bound:
                    y += height
                    continue
                ratio = (y - top_bound) / max(1.0, (text_rect.top - top_bound))
                alpha = int(255 * max(0.0, min(1.0, ratio)))
            elif y + height > text_rect.bottom:
                if y + height >= bottom_bound:
                    y += height
                    continue
                ratio = (bottom_bound - (y + height)) / max(1.0, (bottom_bound - text_rect.bottom))
                alpha = int(255 * max(0.0, min(1.0, ratio)))

            if alpha < 255:
                line_surface = line_surface.copy()
                line_surface.set_alpha(alpha)

            surface.blit(line_surface, (text_rect.left, y))
            y += height

    def _draw_detail_scrollbar(self, surface: pygame.Surface, rect: pygame.Rect) -> None:
        if self._detail_total_height <= 0 or self._detail_view_height <= 0:
            return

        overflow = self._detail_total_height - self._detail_view_height
        if overflow <= 4:
            return

        pygame.draw.rect(surface, COLOR_SCROLL_TRACK, rect, border_radius=4)

        max_offset = max(0.0, overflow)
        visible_ratio = self._detail_view_height / self._detail_total_height
        visible_ratio = max(0.08, min(1.0, visible_ratio))
        handle_height = max(20.0, rect.height * visible_ratio)
        scroll_ratio = 0.0 if max_offset <= 0 else self.detail_scroll_offset / max_offset
        scroll_ratio = max(0.0, min(1.0, scroll_ratio))
        available = rect.height - handle_height
        handle_top = rect.top + available * scroll_ratio if available > 0 else rect.top
        handle_rect = pygame.Rect(rect.left + 1, int(handle_top), rect.width - 2, int(handle_height))

        handle_color = COLOR_MENU_ACTIVE if self.detail_focus else COLOR_SCROLL_HANDLE
        pygame.draw.rect(surface, handle_color, handle_rect, border_radius=4)
        pygame.draw.rect(surface, (255, 255, 255, 100), handle_rect, width=1, border_radius=4)

    def _detail_scroll_step(self) -> float:
        return max(24.0, float(self.detail_font.get_height() + 6))

    def _page_scroll_step(self) -> float:
        if self._detail_view_height <= 0:
            return self._detail_scroll_step()
        return max(self._detail_scroll_step(), float(self._detail_view_height) * 0.85)

    def _scroll_detail_by(self, delta: float) -> None:
        if self._detail_total_height <= self._detail_view_height or self._detail_view_height <= 0:
            if self.detail_focus:
                self.detail_manual_scroll = True
            return

        max_offset = max(0.0, self._detail_total_height - self._detail_view_height)
        new_offset = max(0.0, min(max_offset, self.detail_scroll_offset + delta))
        self.detail_scroll_offset = new_offset
        if self.detail_focus:
            self.detail_manual_scroll = True

    def _set_detail_scroll_ratio(self, ratio: float) -> None:
        if self._detail_total_height <= self._detail_view_height or self._detail_view_height <= 0:
            self.detail_scroll_offset = 0.0
        else:
            ratio = max(0.0, min(1.0, ratio))
            max_offset = max(0.0, self._detail_total_height - self._detail_view_height)
            self.detail_scroll_offset = max_offset * ratio
        if self.detail_focus:
            self.detail_manual_scroll = True

    def _draw_animation_preview(self, surface: pygame.Surface, rect: pygame.Rect, animation_id: str | None) -> None:
        pygame.draw.rect(surface, (40, 52, 80, 200), rect, border_radius=16)
        pygame.draw.rect(surface, (90, 120, 190, 120), rect, width=1, border_radius=16)
        center_x = rect.centerx
        center_y = rect.centery
        ticks = pygame.time.get_ticks()

        if self.preview_renderer and animation_id is not None:
            try:
                if self.preview_renderer(surface, rect, animation_id, ticks):
                    return
            except Exception:
                pass

        if animation_id == "fire":
            gun_rect = pygame.Rect(rect.left + 24, center_y - 20, 110, 40)
            pygame.draw.rect(surface, (70, 90, 120), gun_rect, border_radius=8)
            muzzle_x = gun_rect.right + 10
            muzzle_y = center_y
            travel = rect.width - (gun_rect.width + 60)
            t = (ticks % 1200) / 1200.0
            bullet_x = muzzle_x + travel * t
            bullet_rect = pygame.Rect(int(bullet_x), muzzle_y - 6, 18, 12)
            pygame.draw.rect(surface, (255, 180, 90), bullet_rect, border_radius=4)
            pygame.draw.circle(surface, (255, 230, 160), (muzzle_x, muzzle_y), 16)
        elif animation_id == "reload":
            radius = min(rect.width, rect.height) // 3
            pygame.draw.circle(surface, (60, 80, 120), (center_x, center_y), radius, width=4)
            progress = (ticks % 2000) / 2000.0
            end_angle = -math.pi / 2 + progress * 2 * math.pi
            pygame.draw.arc(
                surface,
                (255, 200, 80),
                pygame.Rect(center_x - radius, center_y - radius, radius * 2, radius * 2),
                -math.pi / 2,
                end_angle,
                6,
            )
            text = self.small_font.render("스킬 게이지 150 소모", True, COLOR_TEXT_DIM)
            surface.blit(text, text.get_rect(center=(center_x, center_y + radius + 18)))
        elif animation_id == "supply":
            drop_height = rect.height - 40
            t = (ticks % 1600) / 1600.0
            crate_y = rect.top + 20 + drop_height * t
            crate_rect = pygame.Rect(center_x - 36, int(crate_y), 72, 48)
            pygame.draw.rect(surface, (120, 90, 60), crate_rect, border_radius=8)
            pygame.draw.rect(surface, (255, 225, 150), crate_rect, width=2, border_radius=8)
            rope_y = rect.top + 20
            pygame.draw.line(surface, (200, 200, 220), (center_x - 10, rope_y), (center_x - 10, crate_rect.top), 2)
            pygame.draw.line(surface, (200, 200, 220), (center_x + 10, rope_y), (center_x + 10, crate_rect.top), 2)
            plane = pygame.Rect(center_x - 70, rect.top + 10, 140, 16)
            pygame.draw.rect(surface, (160, 180, 220), plane, border_radius=6)
            label = self.small_font.render("스킬 게이지 350", True, COLOR_TEXT_DIM)
            surface.blit(label, label.get_rect(center=(center_x, rect.bottom - 18)))
        elif animation_id == "emergency":
            arrow_color = (255, 180, 120)
            base_y = center_y
            phase = math.sin(ticks / 160.0)
            for offset in (-1, 1):
                points = [
                    (center_x + offset * 80, base_y - 20),
                    (center_x + offset * 40, base_y - 20),
                    (center_x + offset * 40, base_y - 40),
                    (center_x + offset * 10, base_y),
                    (center_x + offset * 40, base_y + 40),
                    (center_x + offset * 40, base_y + 20),
                    (center_x + offset * 80, base_y + 20),
                ]
                jittered = [(x, y + phase * 4) for x, y in points]
                pygame.draw.polygon(surface, arrow_color, jittered)
            tap_text = self.small_font.render("0.25초 이내로 더블탭!", True, COLOR_TEXT_DIM)
            surface.blit(tap_text, tap_text.get_rect(center=(center_x, rect.bottom - 18)))
        elif animation_id == "switch":
            panel_rect = pygame.Rect(rect.left + 24, center_y - 40, rect.width - 48, 80)
            pygame.draw.rect(surface, (55, 70, 110), panel_rect, border_radius=12)
            pygame.draw.rect(surface, (120, 150, 210), panel_rect, width=1, border_radius=12)

            slots = ["권총", "바주카", "AK-47"]
            slot_width = (panel_rect.width - 40) // len(slots)
            base_y = panel_rect.centery
            highlight = (ticks // 400) % len(slots)
            for idx, label in enumerate(slots):
                slot_rect = pygame.Rect(panel_rect.left + 20 + idx * slot_width, base_y - 22, slot_width - 10, 44)
                is_active = idx == highlight
                pygame.draw.rect(
                    surface,
                    (200, 220, 255) if is_active else (90, 110, 150),
                    slot_rect,
                    border_radius=10,
                )
                pygame.draw.rect(surface, (255, 255, 255), slot_rect, width=1, border_radius=10)
                text_surface = self.small_font.render(label, True, (20, 30, 50) if is_active else (220, 230, 255))
                surface.blit(text_surface, text_surface.get_rect(center=slot_rect.center))

            arrow_surface = self.small_font.render("↑ 홀드", True, COLOR_TEXT_DIM)
            surface.blit(arrow_surface, arrow_surface.get_rect(center=(center_x, rect.bottom - 20)))
        elif animation_id == "thor_shield":
            _draw_thor_shield_preview(surface, rect, ticks)
        elif animation_id == "blacksmith_build":
            _draw_blacksmith_build_preview(surface, rect, ticks, self.small_font)
        elif animation_id == "blacksmith_turret":
            _draw_blacksmith_turret_preview(surface, rect, ticks)
        elif animation_id == "blacksmith_divine":
            _draw_blacksmith_divine_preview(surface, rect, ticks)
        elif animation_id == "blacksmith_hammer_shock":
            _draw_blacksmith_hammer_shock_preview(surface, rect, ticks)
        else:
            idle_text = self.small_font.render("자료 수집 중...", True, COLOR_TEXT_DIM)
            surface.blit(idle_text, idle_text.get_rect(center=rect.center))

    def _reset_detail_scroll(self, *, reset_layout: bool = False) -> None:
        self.detail_scroll_offset = 0.0
        self.detail_scroll_direction = 1
        self.detail_scroll_wait = 0.0
        self._detail_view_height = 0.0
        self.detail_manual_scroll = False
        self.detail_scroll_input = 0
        if reset_layout:
            self.detail_focus = False
            self._detail_lines = []
            self._detail_total_height = 0.0
            self._detail_layout_key = None

    def _update_detail_layout(self, item: dict, text_width: int) -> None:
        key = (item.get("id"), text_width)
        if self._detail_layout_key == key:
            return

        base_height = self.detail_font.get_height() + 6
        lines: List[dict] = []
        total_height = 0

        paragraphs = item.get("details", [])
        for idx, paragraph in enumerate(paragraphs):
            wrapped = _wrap_text(self.detail_font, paragraph, text_width)
            if not wrapped:
                wrapped = [""]
            for line in wrapped:
                entry = {"text": line, "height": base_height}
                lines.append(entry)
                total_height += entry["height"]
            if idx < len(paragraphs) - 1:
                gap = {"text": None, "height": 12}
                lines.append(gap)
                total_height += gap["height"]

        if not lines:
            entry = {"text": "", "height": base_height}
            lines = [entry]
            total_height = entry["height"]

        self._detail_lines = lines
        self._detail_total_height = total_height
        self.detail_scroll_offset = 0.0
        self.detail_scroll_direction = 1
        self.detail_scroll_wait = 0.0
        self._detail_layout_key = key

    def _draw_lamp(self, surface: pygame.Surface, center: Tuple[int, int], progress: float) -> None:
        wiggle = math.sin(self.elapsed_ms / 180.0) * 6
        base_color = (210, 170, 20)
        accent_color = (235, 200, 60)
        x, y = center

        body_rect = pygame.Rect(0, 0, 200, 70)
        body_rect.center = (x + wiggle, y)
        pygame.draw.ellipse(surface, base_color, body_rect)
        pygame.draw.ellipse(surface, (255, 240, 160), body_rect, 3)

        handle_rect = pygame.Rect(0, 0, 70, 42)
        handle_rect.center = (body_rect.left - 28, body_rect.centery)
        pygame.draw.ellipse(surface, base_color, handle_rect, 5)

        spout_points = [
            (body_rect.right - 20, body_rect.centery - 10),
            (body_rect.right + 70, body_rect.centery - 4 + wiggle * 0.1),
            (body_rect.right - 20, body_rect.centery + 10),
        ]
        pygame.draw.polygon(surface, accent_color, spout_points)
        pygame.draw.polygon(surface, (255, 240, 200), spout_points, 2)

        lid_rect = pygame.Rect(0, 0, 110, 24)
        lid_rect.center = (body_rect.centerx + wiggle, body_rect.top - 8)
        pygame.draw.ellipse(surface, accent_color, lid_rect)
        pygame.draw.ellipse(surface, (255, 240, 200), lid_rect, 2)

        if self.phase == "animation":
            glow_ratio = min(1.0, progress)
            glow_surface = pygame.Surface((body_rect.width + 80, body_rect.height + 80), pygame.SRCALPHA)
            pygame.draw.circle(
                glow_surface,
                (120, 180, 255, int(120 * glow_ratio)),
                (glow_surface.get_width() // 2, glow_surface.get_height() // 2),
                int(140 * glow_ratio),
            )
            surface.blit(glow_surface, glow_surface.get_rect(center=(x, y - 20)))

    def _draw_smoke(self, surface: pygame.Surface, center: Tuple[int, int], progress: float) -> None:
        x, y = center
        ticks = self.elapsed_ms
        for particle in self.smoke_particles:
            delay = particle["delay"]
            life = particle["life"]
            age = particle["born"]
            if age < delay:
                continue
            smoke_age = age - delay
            t = min(1.0, smoke_age / life)
            alpha = int(180 * (1.0 - t))
            radius = particle["radius"] * (0.7 + 0.5 * (1 - t))
            offset_y = y - 70 - 110 * t
            offset_x = x + particle["x"] + math.sin(ticks / 260.0 + particle["x"]) * (14 * (1 - t))

            circle_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(circle_surface, (150, 200, 255, alpha), (radius, radius), radius)
            surface.blit(circle_surface, (offset_x - radius, offset_y - radius))
