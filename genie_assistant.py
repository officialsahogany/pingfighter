import math
import random
from typing import List, Sequence, Tuple

import pygame

from pixel_font_manager import FontStyle, get_font

ANIMATION_DURATION_MS = 2000
SMOKE_PARTICLE_COUNT = 18
COLOR_OVERLAY_BG = (12, 20, 35, 220)
COLOR_MENU_BG = (26, 36, 62, 220)
COLOR_MENU_BORDER = (80, 110, 170, 255)
COLOR_MENU_ACTIVE = (115, 160, 255, 235)
COLOR_DETAIL_BG = (18, 24, 40, 235)
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
            "keys": ["SPACE", "←/→"],
            "details": [
                "SPACE 키를 눌러 현재 장비한 화기를 발사합니다. 서브 직후 3초 동안은 안전 대기 구간이라 경고 메시지가 출력됩니다.",
                "←/→ 방향키로 이동하며 사격 각도를 미세하게 조절할 수 있습니다.",
                "↑ 키를 누르고 있을 때는 물자보급 입력이 우선되어 사격이 잠시 차단됩니다.",
            ],
            "animation": "fire",
        },
        {
            "id": "reload",
            "title": "권총 재장전",
            "summary": "빈 탄창을 SPACE로 채우기",
            "keys": ["SPACE (탄약 0)"],
            "details": [
                "탄약이 0이 된 상태에서 SPACE를 누르면 2초간 재장전이 진행되며 스페셜 게이지 150을 소비합니다.",
                "재장전 중에는 사격이 불가능하고 화기 UI에 진행도가 표시됩니다.",
                "UP 키를 누른 채로는 재장전이 시작되지 않으니 물자보급 입력과 겹치지 않도록 주의하세요.",
            ],
            "animation": "reload",
        },
        {
            "id": "supply_drop",
            "title": "물자보급 요청",
            "summary": "↓키 홀드로 보급상자 호출",
            "keys": ["↓ (1초 홀드)", "게이지 350"],
            "details": [
                "↓ 키를 1초 이상 누르면 무전기가 켜지고, 게이지 350을 소비해 보급 비행기를 호출합니다.",
                "서브 중일 때는 6초가 지나야 호출할 수 있으며, 호출 도중에는 플레이어가 0.5초 동안 고정됩니다.",
                "보급 상자가 떨어지면 탄약, 화력지원, 특수 아이템 중 하나를 즉시 획득합니다.",
            ],
            "animation": "supply",
        },
        {
            "id": "emergency",
            "title": "비상보급",
            "summary": "↓ ↓ 더블탭으로 즉시 장전",
            "keys": ["↓ ↓", "게이지 500"],
            "details": [
                "↓ 키를 빠르게 두 번 탭하면 스페셜 게이지 500을 소비해 현재 무기의 탄약을 즉시 가득 채웁니다.",
                "스테이지마다 1회만 사용할 수 있으며, 화력지원 호출 중에는 발동하지 않습니다.",
                "더블탭 속도는 약 0.25초 이내여야 하므로 연습을 통해 리듬을 익혀 두세요.",
            ],
            "animation": "emergency",
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

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def is_active(self) -> bool:
        return self.active

    def activate(self, screen: pygame.Surface, character_type: str | None) -> None:
        if self.active:
            self.deactivate()
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

    def deactivate(self) -> None:
        self.active = False
        self.phase = "inactive"
        self.overlay_surface = None
        self.smoke_particles.clear()

    def update(self, dt_ms: float) -> None:
        if not self.active:
            return
        self.elapsed_ms += dt_ms

        if self.phase == "animation" and self.elapsed_ms >= ANIMATION_DURATION_MS:
            self._enter_menu_phase()

        self._update_smoke_particles(dt_ms)

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
            if event.key in (pygame.K_ESCAPE, pygame.K_u):
                self.deactivate()
                return True
            if self.phase == "animation" and event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._enter_menu_phase()
                return True
            if self.phase == "menu":
                if event.key in (pygame.K_UP, pygame.K_w):
                    self._move_selection(-1)
                    return True
                if event.key in (pygame.K_DOWN, pygame.K_s):
                    self._move_selection(1)
                    return True
                if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                    # 메뉴에서는 상세 패널이 항상 열려 있으므로 입력을 소비만 한다.
                    return True
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if self.phase == "animation":
                self._enter_menu_phase()
                return True
            if self.phase == "menu" and event.button == 1:
                pos = event.pos
                for idx, rect in enumerate(self.menu_item_rects):
                    if rect.collidepoint(pos):
                        self.selected_index = idx
                        return True
                # 메뉴 밖 클릭은 닫기
                self.deactivate()
                return True

        elif event.type == pygame.MOUSEMOTION and self.phase == "menu":
            for idx, rect in enumerate(self.menu_item_rects):
                if rect.collidepoint(event.pos):
                    self.selected_index = idx
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
        margin_x = 80
        header_y = 70

        header = self.title_font.render("지니 전술 훈련", True, COLOR_TEXT_MAIN)
        surface.blit(header, header.get_rect(midtop=(width // 2, header_y)))

        character_label = CHARACTER_LABELS.get(self.character_type, "전투원")
        sub = self.small_font.render(f"코만도 지침" if self.character_type == "soldier" else f"{character_label} 지침", True, COLOR_TEXT_DIM)
        surface.blit(sub, sub.get_rect(midtop=(width // 2, header_y + 48)))

        menu_width = max(300, int(width * 0.32))
        menu_rect = pygame.Rect(margin_x, header_y + 90, menu_width, height - (header_y + 180))
        detail_rect = pygame.Rect(menu_rect.right + 24, menu_rect.top, width - margin_x - menu_rect.width - 24 * 2, menu_rect.height)

        pygame.draw.rect(surface, COLOR_MENU_BG, menu_rect, border_radius=18)
        pygame.draw.rect(surface, COLOR_MENU_BORDER, menu_rect, width=2, border_radius=18)

        pygame.draw.rect(surface, COLOR_DETAIL_BG, detail_rect, border_radius=18)
        pygame.draw.rect(surface, (90, 120, 190, 140), detail_rect, width=2, border_radius=18)

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
        text_rect = pygame.Rect(detail_rect.left + 28, text_top, detail_rect.width - 56, detail_rect.bottom - text_top - 24)
        self._draw_detail_text(surface, text_rect, item.get("details", []))

    def _draw_detail_text(self, surface: pygame.Surface, text_rect: pygame.Rect, lines: Sequence[str]) -> None:
        y = text_rect.top
        for paragraph in lines:
            wrapped = _wrap_text(self.detail_font, paragraph, text_rect.width)
            for wrapped_line in wrapped:
                if y > text_rect.bottom - self.detail_font.get_height():
                    return
                line_surface = self.detail_font.render(wrapped_line, True, COLOR_TEXT_MAIN)
                surface.blit(line_surface, (text_rect.left, y))
                y += self.detail_font.get_height() + 4
            y += 6

    def _draw_animation_preview(self, surface: pygame.Surface, rect: pygame.Rect, animation_id: str | None) -> None:
        pygame.draw.rect(surface, (40, 52, 80, 200), rect, border_radius=16)
        pygame.draw.rect(surface, (90, 120, 190, 120), rect, width=1, border_radius=16)
        center_x = rect.centerx
        center_y = rect.centery
        ticks = pygame.time.get_ticks()

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
            text = self.small_font.render("게이지 150 소모", True, COLOR_TEXT_DIM)
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
            label = self.small_font.render("게이지 350", True, COLOR_TEXT_DIM)
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
        else:
            idle_text = self.small_font.render("자료 수집 중...", True, COLOR_TEXT_DIM)
            surface.blit(idle_text, idle_text.get_rect(center=rect.center))

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
