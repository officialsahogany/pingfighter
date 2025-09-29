import math
import random
from typing import List, Tuple

import pygame

from pixel_font_manager import FontStyle, get_font


class GenieAssistant:
    """U 키로 호출되는 지니 상담 오버레이"""

    def __init__(self) -> None:
        self.active: bool = False
        self.phase: str = "inactive"  # animation, input, response
        self.elapsed_ms: float = 0.0
        self.animation_duration_ms: int = 2000
        self.screen_size: Tuple[int, int] = (0, 0)
        self.overlay_surface: pygame.Surface | None = None
        self.smoke_particles: List[dict] = []
        self.cursor_timer_ms: float = 0.0
        self.cursor_visible: bool = True
        self.input_text: str = ""
        self.response_text: str = ""
        self.last_question: str = ""
        self.prompt_font = FontStyle.body()
        self.small_font = FontStyle.small()
        self.title_font = FontStyle.large()
        self.response_font = get_font(20)
        self._text_input_enabled: bool = False

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def is_active(self) -> bool:
        return self.active

    def activate(self, screen: pygame.Surface) -> None:
        if self.active:
            return
        self.active = True
        self.phase = "animation"
        self.elapsed_ms = 0.0
        self.cursor_timer_ms = 0.0
        self.cursor_visible = True
        self.input_text = ""
        self.response_text = ""
        self.last_question = ""
        self.screen_size = screen.get_size()
        self.overlay_surface = pygame.Surface(self.screen_size, pygame.SRCALPHA)
        self._init_smoke_particles()
        self._disable_text_input()

    def deactivate(self) -> None:
        if not self.active:
            return
        self.active = False
        self.phase = "inactive"
        self._disable_text_input()

    def update(self, dt_ms: float) -> None:
        if not self.active:
            return
        self.elapsed_ms += dt_ms
        self.cursor_timer_ms += dt_ms
        if self.cursor_timer_ms >= 450:
            self.cursor_timer_ms %= 450
            self.cursor_visible = not self.cursor_visible

        if self.phase == "animation" and self.elapsed_ms >= self.animation_duration_ms:
            self._enter_input_phase()

        if self.phase == "animation":
            self._update_smoke_particles(dt_ms)
        elif self.phase in ("input", "response"):
            self._update_smoke_particles(dt_ms, fade_out=True)

    def draw(self, surface: pygame.Surface) -> None:
        if not self.active or self.overlay_surface is None:
            return

        self.overlay_surface.fill((0, 0, 0, 180))
        lamp_center = (self.screen_size[0] // 2, self.screen_size[1] // 2 + 80)
        progress = min(1.0, self.elapsed_ms / self.animation_duration_ms) if self.animation_duration_ms else 1.0
        self._draw_lamp(self.overlay_surface, lamp_center, progress)
        self._draw_smoke(self.overlay_surface, lamp_center, progress)
        self._draw_genie(self.overlay_surface, lamp_center, progress)
        self._draw_text_layer(self.overlay_surface, progress)
        surface.blit(self.overlay_surface, (0, 0))

    def handle_event(self, event: pygame.event.Event) -> bool:
        if not self.active:
            return False

        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.deactivate()
                return True
            if self.phase == "animation" and event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._enter_input_phase(force=True)
                return True

        if self.phase == "input":
            if event.type == pygame.TEXTINPUT:
                self.input_text += event.text
                return True
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_BACKSPACE:
                    self.input_text = self.input_text[:-1]
                    return True
                if event.key == pygame.K_RETURN:
                    if self.input_text.strip():
                        self.last_question = self.input_text.strip()
                        self.response_text = self._answer_question(self.last_question)
                        self.phase = "response"
                        self.input_text = ""
                        self.cursor_visible = True
                        self.cursor_timer_ms = 0.0
                        self._disable_text_input()
                    else:
                        self.deactivate()
                    return True

        if self.phase == "response" and event.type == pygame.KEYDOWN:
            if event.key == pygame.K_RETURN:
                self.phase = "input"
                self.response_text = ""
                self.cursor_visible = True
                self.cursor_timer_ms = 0.0
                self._enable_text_input()
                return True

        if self.phase == "response" and event.type == pygame.TEXTINPUT:
            # 사용자가 바로 타이핑을 시작하면 입력 단계로 전환
            self.phase = "input"
            self.response_text = ""
            self.input_text = event.text
            self.cursor_visible = True
            self.cursor_timer_ms = 0.0
            self._enable_text_input()
            return True

        if self.phase == "input" and event.type == pygame.KEYDOWN:
            # 일반 키 입력 처리 (텍스트 입력 활성화되어도 일부 키는 TEXTINPUT으로 오지 않음)
            char = event.unicode
            if char and not event.key in (pygame.K_RETURN, pygame.K_BACKSPACE):
                self.input_text += char
                return True

        return True

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _init_smoke_particles(self) -> None:
        self.smoke_particles = []
        for _ in range(18):
            particle = {
                "delay": random.uniform(0, self.animation_duration_ms * 0.8),
                "life": random.uniform(750, 1400),
                "born": 0.0,
                "x": random.uniform(-30, 30),
                "radius": random.uniform(8, 22),
            }
            self.smoke_particles.append(particle)

    def _update_smoke_particles(self, dt_ms: float, *, fade_out: bool = False) -> None:
        for particle in self.smoke_particles:
            particle["born"] += dt_ms
            total_life = particle["delay"] + particle["life"]
            if particle["born"] > total_life:
                particle["born"] = 0.0
                particle["delay"] = random.uniform(0, self.animation_duration_ms * (0.5 if fade_out else 0.8))
                particle["life"] = random.uniform(750, 1400)
                particle["x"] = random.uniform(-30, 30)
                particle["radius"] = random.uniform(8, 22)

    def _draw_lamp(self, surface: pygame.Surface, center: Tuple[int, int], progress: float) -> None:
        wiggle = math.sin(self.elapsed_ms / 180.0) * 6
        base_color = (210, 170, 20)
        neck_color = (235, 200, 60)
        x, y = center
        # 본체
        body_rect = pygame.Rect(0, 0, 180, 70)
        body_rect.center = (x + wiggle, y)
        pygame.draw.ellipse(surface, base_color, body_rect)
        pygame.draw.ellipse(surface, (250, 230, 120), body_rect, 3)
        # 손잡이
        handle_rect = pygame.Rect(0, 0, 70, 40)
        handle_rect.center = (body_rect.left - 25, body_rect.centery)
        pygame.draw.ellipse(surface, base_color, handle_rect, 5)
        # 주둥이
        spout_points = [
            (body_rect.right - 15, body_rect.centery - 12),
            (body_rect.right + 55, body_rect.centery - 5 + wiggle * 0.1),
            (body_rect.right - 15, body_rect.centery + 12),
        ]
        pygame.draw.polygon(surface, neck_color, spout_points)
        pygame.draw.polygon(surface, (255, 240, 180), spout_points, 2)
        # 뚜껑
        lid_rect = pygame.Rect(0, 0, 90, 24)
        lid_rect.center = (body_rect.centerx + wiggle, body_rect.top - 6)
        pygame.draw.ellipse(surface, neck_color, lid_rect)
        pygame.draw.ellipse(surface, (255, 240, 180), lid_rect, 2)

    def _draw_smoke(self, surface: pygame.Surface, center: Tuple[int, int], progress: float) -> None:
        x, y = center
        for particle in self.smoke_particles:
            delay = particle["delay"]
            life = particle["life"]
            age = particle["born"]
            if age < delay:
                continue
            smoke_age = age - delay
            t = min(1.0, smoke_age / life)
            alpha = int(190 * (1.0 - t))
            if progress >= 1.0:
                alpha = max(0, alpha - int(120 * (t)))
            radius = particle["radius"] * (0.6 + 0.6 * (1 - t))
            offset_y = y - 60 - 90 * t
            offset_x = x + particle["x"] + math.sin(self.elapsed_ms / 220.0 + particle["x"]) * (12 * (1 - t))
            circle_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(circle_surface, (180, 220, 255, alpha), (radius, radius), radius)
            surface.blit(circle_surface, (offset_x - radius, offset_y - radius))

    def _draw_genie(self, surface: pygame.Surface, center: Tuple[int, int], progress: float) -> None:
        if self.phase == "animation" and progress < 0.15:
            return
        appear_t = progress if self.phase == "animation" else 1.0
        appear_t = min(1.0, max(0.0, appear_t))
        x, y = center
        body_height = 220 * appear_t
        body_width = 140 * appear_t
        genie_surface = pygame.Surface((int(body_width), int(body_height)), pygame.SRCALPHA)
        rect = genie_surface.get_rect(midbottom=(x, y - 80))
        torso_rect = pygame.Rect(0, 0, int(body_width * 0.7), int(body_height * 0.55))
        torso_rect.midtop = (genie_surface.get_width() // 2, int(body_height * 0.15))
        pygame.draw.ellipse(genie_surface, (120, 200, 255, 220), torso_rect)
        head_radius = max(10, int(body_width * 0.18))
        head_center = (genie_surface.get_width() // 2, int(body_height * 0.08) + head_radius)
        pygame.draw.circle(genie_surface, (200, 230, 255, 235), head_center, head_radius)
        lower_points = [
            (genie_surface.get_width() // 2 - body_width * 0.2, int(body_height * 0.55)),
            (genie_surface.get_width() // 2 + body_width * 0.2, int(body_height * 0.55)),
            (genie_surface.get_width() // 2 + body_width * 0.05, int(body_height * 0.95)),
            (genie_surface.get_width() // 2 - body_width * 0.05, int(body_height * 0.95)),
        ]
        pygame.draw.polygon(genie_surface, (90, 180, 240, 210), lower_points)
        surface.blit(genie_surface, rect)

    def _draw_text_layer(self, surface: pygame.Surface, progress: float) -> None:
        center_x = self.screen_size[0] // 2
        top_y = self.screen_size[1] // 2 - 160

        if self.phase == "animation":
            title = self.title_font.render("램프가 깨어납니다...", True, (255, 240, 200))
            surface.blit(title, title.get_rect(center=(center_x, top_y)))
            subtitle = self.prompt_font.render("잠시만 기다려 주세요", True, (220, 220, 255))
            surface.blit(subtitle, subtitle.get_rect(center=(center_x, top_y + 42)))
            return

        prompt = self.prompt_font.render("무엇이 궁금하신가요?", True, (255, 240, 200))
        surface.blit(prompt, prompt.get_rect(center=(center_x, top_y)))

        box_width = min(700, self.screen_size[0] - 120)
        box_height = 70
        box_rect = pygame.Rect(0, 0, box_width, box_height)
        box_rect.center = (center_x, top_y + 70)
        pygame.draw.rect(surface, (25, 40, 60, 220), box_rect, border_radius=16)
        pygame.draw.rect(surface, (180, 220, 255, 230), box_rect, 3, border_radius=16)

        if self.phase == "input":
            display_text = self.input_text
            if self.cursor_visible:
                display_text += "|"
            input_surface = self.response_font.render(display_text, True, (255, 255, 255))
            text_rect = input_surface.get_rect(midleft=(box_rect.left + 20, box_rect.centery))
            surface.blit(input_surface, text_rect)
            guide = self.small_font.render("ENTER: 질문 보내기  /  ESC: 닫기", True, (200, 210, 240))
            surface.blit(guide, guide.get_rect(center=(center_x, box_rect.bottom + 26)))
        elif self.phase == "response":
            question_surface = self.small_font.render(f"Q: {self.last_question}", True, (255, 255, 255))
            question_rect = question_surface.get_rect(midleft=(box_rect.left + 20, box_rect.centery - 16))
            surface.blit(question_surface, question_rect)
            self._draw_multiline_response(surface, box_rect.left + 20, box_rect.centery + 10, box_rect.width - 40)
            guide = self.small_font.render("ENTER: 또 물어보기  /  ESC: 닫기", True, (200, 210, 240))
            surface.blit(guide, guide.get_rect(center=(center_x, box_rect.bottom + 26)))

    def _draw_multiline_response(self, surface: pygame.Surface, start_x: int, start_y: int, max_width: int) -> None:
        if not self.response_text:
            return
        words = self.response_text.split()
        lines: List[str] = []
        current = ""
        for word in words:
            test = f"{current} {word}".strip()
            if self.response_font.size(test)[0] <= max_width:
                current = test
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        for idx, line in enumerate(lines[:4]):
            line_surface = self.response_font.render(line, True, (255, 255, 255))
            surface.blit(line_surface, line_surface.get_rect(midleft=(start_x, start_y + idx * 24)))

    def _enter_input_phase(self, force: bool = False) -> None:
        if self.phase == "input" and not force:
            return
        self.phase = "input"
        self.elapsed_ms = max(self.elapsed_ms, float(self.animation_duration_ms))
        self.cursor_timer_ms = 0.0
        self.cursor_visible = True
        self._enable_text_input()

    def _enable_text_input(self) -> None:
        if not self._text_input_enabled:
            pygame.key.start_text_input()
            self._text_input_enabled = True

    def _disable_text_input(self) -> None:
        if self._text_input_enabled:
            pygame.key.stop_text_input()
            self._text_input_enabled = False

    def _answer_question(self, question: str) -> str:
        normalized = question.lower()
        answers = [
            ("stopwatch", "스톱워치는 발동 중에는 패들과 게이지가 멈추고, 복구될 때 위쪽 고정이 풀리는지 꼭 확인하세요."),
            ("스톱워치", "스톱워치가 켜지면 충돌과 게이지가 모두 멈추고, 회복 직후엔 위쪽 각도 잠금이 해제돼야 해요."),
            ("dash", "대쉬는 스페이스로 발동되고, 하프대쉬는 방향키와의 프레임 타이밍을 맞춰야 해요."),
            ("대쉬", "대쉬는 게이지를 100 채우고 스페이스를 눌러 사용하세요. 하프대쉬는 좌/우 입력과 스페이스를 거의 동시에 눌러야 성공합니다."),
            ("item", "아이템은 `items.spawn_random_item()`에서 떨어지고, 아이템 관리 화면은 메인 메뉴 단축키 2번으로 들어갈 수 있어요."),
            ("아이템", "새 아이템을 추가했다면 `items.reset_items()`과 `ItemManager.reset()`에 초기화 로직을 꼭 넣어야 버프가 남지 않습니다."),
            ("boss", "보스는 스테이지마다 전담 패턴이 다르니, 스테이지 3 쿠로미 각성처럼 특별 이벤트가 있는지 미리 확인하세요."),
            ("tutorial", "튜토리얼(스테이지 50)은 Chapter 1~3으로 나뉘고, 8번 키로 강제 완료 후 다음 챕터로 이동할 수 있어요."),
            ("튜토리얼", "튜토리얼은 50번 스테이지에서만 열리고, 대쉬와 드라이브 연습은 가이드 대화가 끝나야 시작됩니다."),
            ("fps", "프레임 드랍이 보이면 새로운 이펙트에서 매 프레임 Surface를 생성하고 있지 않은지 확인하세요."),
        ]
        for keyword, answer in answers:
            if keyword in normalized:
                return answer
        return "지니도 공부 중이에요. 튜토리얼과 메뉴에서 힌트를 찾아보거나, 아이템 관리자에서 능력을 확인해 보세요!"
