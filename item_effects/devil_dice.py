"""
😈 Devil's Dice Active Item (개편)
악마의 주사위 - 사용 시 7가지 스탯을 -10%~+10% 영구적으로 조정하는 아이템
여러 번 사용 시 효과가 누적됨
최대 3번 다시 굴리기 가능
"""

import pygame
import random
import math
from typing import Dict, Any

from resource_path import resource_path


# 스탯 키 정의 (한글 이름 매핑)
STAT_KEYS = [
    ('player_speed',  '이동속도'),
    ('paddle_size',   '몸집크기'),
    ('skill_gauge',   '최대 게이지'),
    ('dash_distance', '대쉬거리'),
    ('dash_recovery', '대쉬후딜시간'),
    ('dash_cooldown', '대쉬쿨타임'),
    ('item_cooldown', '아이템쿨타임'),
]

# 감소가 이득인 스탯 (색상 반전용)
LOWER_IS_BETTER = {'dash_recovery', 'dash_cooldown', 'item_cooldown'}

MAX_REROLLS = 3  # 최대 굴리기 횟수 (첫 굴림 포함)


class DevilDice:
    """악마의 주사위 - 영구 스탯 조정 아이템"""

    def __init__(self):
        # 영구 누적 보너스 (백분율, 매 사용마다 -10~+10 누적)
        self.permanent_bonuses: Dict[str, int] = {key: 0 for key, _ in STAT_KEYS}

        # 마지막 굴림 결과 (표시용, 아직 적용되지 않은 값)
        self.last_roll: Dict[str, int] = {key: 0 for key, _ in STAT_KEYS}

        self.use_count = 0  # 총 사용 횟수
        self._roll_applied = False  # 현재 굴림이 적용되었는지

        # 다시 굴리기
        self.rerolls_remaining = 0  # 남은 굴리기 횟수
        self.reroll_requested = False  # 다시 굴리기 요청 플래그
        self.selected_button = 1  # 0=다시굴리기, 1=확정 (기본: 확정 선택)
        self.confirm_pressed = False  # 확정/선택 입력 플래그

        # 주사위 굴리기 애니메이션
        self.is_rolling = False
        self.roll_animation_timer = 0
        self.roll_animation_duration = 120  # 2초 (60fps)
        self.waiting_for_confirm = False
        self.displayed_face_value = 1
        self.locked_face_value = None
        self.final_idle_phase = 0.0
        self.dice_offset_y = 0.0
        self.dice_vertical_velocity = 0.0
        self.dice_gravity = 0.45

        # 패들 이펙트 (사용 후 3초간만 표시)
        self.paddle_effect_timer = 0  # 남은 프레임 (0이면 비활성)
        self.paddle_effect_duration = 180  # 3초 (60fps)
        self.flame_particles = []

        # 폰트
        self.font = None
        self.small_font = None
        self.init_fonts()

    def init_fonts(self):
        """폰트 초기화"""
        try:
            from pixel_font_manager import get_pixel_font_path
            _pfp = get_pixel_font_path()
        except Exception:
            _pfp = resource_path("PFStardust.ttf")
        font_candidates = [
            _pfp,
            resource_path("NanumSquareB.ttf"),
            resource_path("NanumSquareR.ttf"),
        ]
        for path in font_candidates:
            try:
                self.font = pygame.font.Font(path, 24)
                self.small_font = pygame.font.Font(path, 16)
                break
            except Exception:
                self.font = None
                self.small_font = None
        if self.font is None or self.small_font is None:
            self.font = pygame.font.Font(None, 24)
            self.small_font = pygame.font.Font(None, 16)

    def activate(self, game_state: Dict[str, Any], current_stage: int) -> Dict[str, float]:
        """악마의 주사위 발동 - 각 스탯에 -10%~+10% 영구 조정"""
        if self.is_rolling:
            return self.get_current_multipliers()

        self.rerolls_remaining = MAX_REROLLS - 1  # 첫 굴림 제외한 남은 횟수
        self._start_roll()

        print("😈 악마의 주사위를 굴립니다...")
        return self.get_current_multipliers()

    def _start_roll(self):
        """주사위 굴리기 시작 (첫 굴림/다시 굴리기 공용)"""
        for key, _ in STAT_KEYS:
            self.last_roll[key] = random.randint(-10, 10)

        self._roll_applied = False
        self.reroll_requested = False
        self.confirm_pressed = False
        self.selected_button = 1  # 기본: 확정 선택

        self.is_rolling = True
        self.roll_animation_timer = 0
        self.waiting_for_confirm = False
        self.locked_face_value = None
        self.displayed_face_value = random.randint(1, 6)
        self.final_idle_phase = 0.0
        self.dice_offset_y = 0.0
        self.dice_vertical_velocity = -8.5

    def _apply_roll(self):
        """마지막 굴림 결과를 영구 보너스에 적용"""
        if self._roll_applied:
            return
        for key, _ in STAT_KEYS:
            self.permanent_bonuses[key] += self.last_roll[key]
        self.use_count += 1
        self._roll_applied = True
        self._print_results()

    def _print_results(self):
        """굴림 결과 콘솔 출력"""
        print(f"😈 악마의 주사위 결과 (#{self.use_count}):")
        for key, name in STAT_KEYS:
            val = self.last_roll[key]
            sign = "+" if val >= 0 else ""
            total = self.permanent_bonuses[key]
            total_sign = "+" if total >= 0 else ""
            print(f"  {name}: {sign}{val}% (누적: {total_sign}{total}%)")

    def _update_dice_face(self):
        """굴림 애니메이션용 주사위 눈 업데이트"""
        if self.locked_face_value is not None:
            self.displayed_face_value = self.locked_face_value
            return
        if self.roll_animation_timer % 2 == 0:
            self.displayed_face_value = random.randint(1, 6)

    def get_current_multipliers(self) -> Dict[str, float]:
        """현재 영구 배율 반환 (1.0 = 변화없음)"""
        result = {}
        for key, _ in STAT_KEYS:
            result[key] = 1.0 + self.permanent_bonuses[key] / 100.0
        # 하위 호환: 제거된 스탯은 항상 1.0
        result['item_spawn'] = 1.0
        result['dash_cost'] = 1.0
        return result

    def has_bonuses(self) -> bool:
        """영구 보너스가 존재하는지 확인"""
        return any(v != 0 for v in self.permanent_bonuses.values())

    def update(self, current_stage: int) -> bool:
        """애니메이션 업데이트 (영구 아이템이므로 시간 감소 없음)"""
        if not self.is_rolling:
            return self.has_bonuses()

        # 굴리기 애니메이션 업데이트
        if not self.waiting_for_confirm:
            self.roll_animation_timer += 1

        self._update_dice_face()

        if not self.waiting_for_confirm:
            self.dice_vertical_velocity += self.dice_gravity
            self.dice_offset_y += self.dice_vertical_velocity
            if self.dice_offset_y > 0:
                self.dice_offset_y = 0
                self.dice_vertical_velocity *= -0.65
                if abs(self.dice_vertical_velocity) < 0.8:
                    self.dice_vertical_velocity = -2.5
            elif self.dice_offset_y < -90:
                self.dice_offset_y = -90
                if self.dice_vertical_velocity < 0:
                    self.dice_vertical_velocity *= -0.6

        if self.roll_animation_timer >= self.roll_animation_duration:
            if self.locked_face_value is None:
                total_score = sum(abs(v) for v in self.last_roll.values())
                self.locked_face_value = (total_score % 6) + 1
            self.displayed_face_value = self.locked_face_value

            if not self.waiting_for_confirm:
                self.waiting_for_confirm = True
                self.dice_vertical_velocity = -4.0
        else:
            pass  # 랜덤 값 표시는 draw에서 처리

        # 확정/선택 입력 처리
        if self.waiting_for_confirm and self.confirm_pressed:
            self.confirm_pressed = False
            if self.selected_button == 0 and self.rerolls_remaining > 0:
                # 다시 굴리기 선택
                self.rerolls_remaining -= 1
                print(f"😈 다시 굴립니다! (남은 횟수: {self.rerolls_remaining})")
                self._start_roll()
                return True
            else:
                # 확정 선택
                self._apply_roll()
                self.is_rolling = False
                self.waiting_for_confirm = False
            self.locked_face_value = None
            self.displayed_face_value = 1
            self.final_idle_phase = 0.0
            self.dice_offset_y = 0.0
            self.dice_vertical_velocity = 0.0
            self.paddle_effect_timer = self.paddle_effect_duration

        if self.waiting_for_confirm:
            self.final_idle_phase += 0.08
            hover_base = -12
            hover_amp = 4
            self.dice_offset_y = hover_base + math.sin(self.final_idle_phase * 0.8) * hover_amp
        else:
            self.final_idle_phase = 0.0

        return True

    def draw_paddle_effect(self, screen: pygame.Surface, paddle_rect: pygame.Rect):
        """패들에 어두운 기운 효과 그리기 (사용 후 3초간, 서서히 사라짐)"""
        if self.paddle_effect_timer <= 0:
            if not self.flame_particles:
                return
        else:
            self.paddle_effect_timer -= 1

        fade = self.paddle_effect_timer / self.paddle_effect_duration if self.paddle_effect_timer > 0 else 0.0

        if fade > 0 and random.random() < 0.3 * fade:
            particle = {
                'x': paddle_rect.centerx + random.randint(-paddle_rect.width // 2, paddle_rect.width // 2),
                'y': paddle_rect.centery,
                'vx': random.uniform(-1, 1),
                'vy': random.uniform(-3, -1),
                'size': random.randint(3, 8),
                'life': random.randint(20, 40),
                'color': random.choice([
                    (139, 0, 0),
                    (75, 0, 130),
                    (25, 25, 112),
                    (128, 0, 128),
                ])
            }
            self.flame_particles.append(particle)

        for particle in self.flame_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['size'] *= 0.95
            if particle['life'] <= 0 or particle['size'] < 1:
                self.flame_particles.remove(particle)
                continue

            alpha = particle['life'] / 40 * max(fade, 0.15)
            for i in range(3):
                glow_size = int(particle['size'] * (1 + i * 0.5))
                glow_alpha = alpha * (0.3 - i * 0.1)
                if glow_alpha > 0:
                    glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surface, (*particle['color'], int(255 * glow_alpha)),
                                       (glow_size, glow_size), glow_size)
                    screen.blit(glow_surface, (particle['x'] - glow_size, particle['y'] - glow_size))

            pygame.draw.circle(screen, particle['color'],
                               (int(particle['x']), int(particle['y'])),
                               int(particle['size']))

    def _draw_dice_animation(self, screen: pygame.Surface, center_x: int, center_y: int):
        """붉은 기운이 도는 주사위 애니메이션"""
        base_size = 140
        spinning = self.locked_face_value is None

        if spinning:
            phase = self.roll_animation_timer * 0.25
            scale_wave = math.sin(phase)
            scale_amount = 0.16
        else:
            phase = self.final_idle_phase
            scale_wave = math.sin(phase * 0.7)
            scale_amount = 0.05

        dice_size = int(base_size * (1.0 + scale_wave * scale_amount))
        dice_size = max(90, dice_size)

        final_center_y = int(center_y + self.dice_offset_y)

        dice_surface = pygame.Surface((dice_size, dice_size), pygame.SRCALPHA)
        rect = dice_surface.get_rect()
        outer_radius = int(dice_size * 0.18)
        inner_radius = max(6, int(dice_size * 0.14))

        pygame.draw.rect(dice_surface, (70, 0, 0, 235), rect, border_radius=outer_radius)
        inner_rect = rect.inflate(-int(dice_size * 0.18), -int(dice_size * 0.18))
        pygame.draw.rect(dice_surface, (220, 40, 40, 255), inner_rect, border_radius=inner_radius)
        pygame.draw.rect(dice_surface, (255, 200, 200, 90), inner_rect, width=3, border_radius=inner_radius)

        highlight_height = max(8, int(inner_rect.height * 0.35))
        highlight_surface = pygame.Surface((inner_rect.width, highlight_height), pygame.SRCALPHA)
        pygame.draw.rect(highlight_surface, (255, 180, 180, 90), highlight_surface.get_rect(),
                         border_radius=int(inner_rect.width * 0.08))
        dice_surface.blit(highlight_surface, (inner_rect.left, inner_rect.top))

        pip_layouts = {
            1: [(0, 0)],
            2: [(-1, -1), (1, 1)],
            3: [(-1, -1), (0, 0), (1, 1)],
            4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
            5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
            6: [(-1, -1.2), (1, -1.2), (-1, 0), (1, 0), (-1, 1.2), (1, 1.2)],
        }

        face_value = max(1, min(6, self.displayed_face_value))
        pip_offset = dice_size * 0.26
        pip_radius = max(5, int(dice_size * 0.08))

        for px, py in pip_layouts.get(face_value, [(0, 0)]):
            cx = int(rect.centerx + px * pip_offset)
            cy = int(rect.centery + py * pip_offset)
            pygame.draw.circle(dice_surface, (150, 20, 20, 110), (cx, cy), pip_radius + 3)
            pygame.draw.circle(dice_surface, (255, 240, 240), (cx, cy), pip_radius)
            pygame.draw.circle(dice_surface, (255, 80, 80), (cx, cy), max(2, pip_radius - 3))

        if spinning:
            rotation = (self.roll_animation_timer * 12) % 360 + math.sin(self.roll_animation_timer * 0.3) * 12
        else:
            rotation = math.sin(self.final_idle_phase * 0.6) * 5

        rotated = pygame.transform.rotozoom(dice_surface, rotation, 1.0)
        rotated_rect = rotated.get_rect(center=(center_x, final_center_y))
        screen.blit(rotated, rotated_rect)

    def _draw_button(self, screen, text, center_x, center_y, color, selected=False):
        """버튼 그리기"""
        btn_w, btn_h = 160, 36
        rect = pygame.Rect(0, 0, btn_w, btn_h)
        rect.center = (center_x, center_y)

        # 선택된 버튼은 밝게, 아니면 어둡게
        if selected:
            bg_color = tuple(min(255, c + 40) for c in color)
            border_color = (255, 255, 100)
            border_w = 3
        else:
            bg_color = tuple(max(0, c - 20) for c in color)
            border_color = tuple(min(255, c + 30) for c in color)
            border_w = 1

        pygame.draw.rect(screen, bg_color, rect, border_radius=8)
        pygame.draw.rect(screen, border_color, rect, border_w, border_radius=8)

        if self.small_font:
            txt_color = (255, 255, 255) if selected else (160, 160, 160)
            txt_surface = self.small_font.render(text, True, txt_color)
            txt_rect = txt_surface.get_rect(center=rect.center)
            screen.blit(txt_surface, txt_rect)

        return rect

    def draw_dice_results(self, screen: pygame.Surface, x: int, y: int):
        """주사위 결과 표시 (굴리기 애니메이션 포함)"""
        if not self.is_rolling:
            return

        # 전체 화면 반투명 오버레이
        full_overlay = pygame.Surface((screen.get_width(), screen.get_height()), pygame.SRCALPHA)
        full_overlay.fill((0, 0, 0, 150))
        screen.blit(full_overlay, (0, 0))

        panel_width = 500
        panel_height = 490
        panel_x = (screen.get_width() - panel_width) // 2
        panel_y = (screen.get_height() - panel_height) // 2

        dice_center_x = screen.get_width() // 2
        base_center_y = panel_y + 130
        self._draw_dice_animation(screen, dice_center_x, base_center_y)

        # 결과 영역
        text_panel_y = panel_y + 205
        text_panel_height = len(STAT_KEYS) * 34 + 130  # 행 간격 축소 + 버튼 영역 확보
        text_panel = pygame.Surface((panel_width, text_panel_height), pygame.SRCALPHA)
        pygame.draw.rect(text_panel, (20, 0, 0, 180), (0, 0, panel_width, text_panel_height), border_radius=15)
        pygame.draw.rect(text_panel, (139, 0, 0, 200), (0, 0, panel_width, text_panel_height), 2, border_radius=15)
        screen.blit(text_panel, (panel_x, text_panel_y))

        start_y = text_panel_y + 20

        for i, (key, name) in enumerate(STAT_KEYS):
            y_pos = start_y + i * 34

            if self.small_font:
                name_text = self.small_font.render(f"{name}:", True, (255, 255, 255))
                screen.blit(name_text, (panel_x + 50, y_pos))

                if self.roll_animation_timer < self.roll_animation_duration - 30:
                    if self.roll_animation_timer % 6 < 3:
                        result_text = "???"
                        result_color = (150, 150, 150)
                    else:
                        temp_val = random.randint(-10, 10)
                        sign = "+" if temp_val >= 0 else ""
                        result_text = f"{sign}{temp_val}%"
                        result_color = (100, 100, 100)
                else:
                    val = self.last_roll[key]
                    sign = "+" if val >= 0 else ""
                    result_text = f"{sign}{val}%"

                    if val == 0:
                        result_color = (200, 200, 200)
                    elif key in LOWER_IS_BETTER:
                        result_color = (100, 255, 100) if val < 0 else (255, 100, 100)
                    else:
                        result_color = (100, 255, 100) if val > 0 else (255, 100, 100)

                    if self.roll_animation_timer < self.roll_animation_duration + 30:
                        flash = abs(math.sin((self.roll_animation_timer - self.roll_animation_duration) * 0.3))
                        result_color = tuple(min(255, int(c + flash * 50)) for c in result_color)

                result_surface = self.small_font.render(result_text, True, result_color)
                result_rect = result_surface.get_rect(left=panel_x + 280, centery=y_pos + 10)
                screen.blit(result_surface, result_rect)

                # 누적값 표시
                if self.roll_animation_timer >= self.roll_animation_duration - 30:
                    total = self.permanent_bonuses[key] + self.last_roll[key]
                    total_sign = "+" if total >= 0 else ""
                    total_text = f"({total_sign}{total}%)"
                    total_color = (160, 160, 180)
                    total_surface = self.small_font.render(total_text, True, total_color)
                    total_rect = total_surface.get_rect(left=panel_x + 380, centery=y_pos + 10)
                    screen.blit(total_surface, total_rect)

        # 버튼 영역 (결과 확정 후)
        if self.waiting_for_confirm and self.small_font:
            mouse_pos = pygame.mouse.get_pos()
            btn_y = text_panel_y + text_panel_height - 50
            center_x = screen.get_width() // 2

            # 남은 횟수 표시
            remaining_text = f"남은 굴리기: {self.rerolls_remaining}회"
            remaining_color = (255, 200, 100) if self.rerolls_remaining > 0 else (120, 120, 120)
            remaining_surface = self.small_font.render(remaining_text, True, remaining_color)
            remaining_rect = remaining_surface.get_rect(centerx=center_x, y=btn_y - 24)
            screen.blit(remaining_surface, remaining_rect)

            # 마우스 호버 → 선택 커서 자동 이동
            if self.rerolls_remaining > 0:
                reroll_rect = pygame.Rect(0, 0, 160, 36)
                reroll_rect.center = (center_x - 90, btn_y)
                confirm_rect = pygame.Rect(0, 0, 160, 36)
                confirm_rect.center = (center_x + 90, btn_y)
                if reroll_rect.collidepoint(mouse_pos):
                    self.selected_button = 0
                elif confirm_rect.collidepoint(mouse_pos):
                    self.selected_button = 1
                # 선택 불가능한 상태면 확정으로 강제
                if self.selected_button == 0 and self.rerolls_remaining <= 0:
                    self.selected_button = 1

                self._draw_button(screen, "다시 굴리기", center_x - 90, btn_y,
                                  (100, 40, 40), selected=(self.selected_button == 0))
                self._draw_button(screen, "확정", center_x + 90, btn_y,
                                  (40, 80, 40), selected=(self.selected_button == 1))

                self._reroll_btn_rect = reroll_rect
                self._confirm_btn_rect = confirm_rect
            else:
                # 횟수 소진: [확정] 버튼만
                self.selected_button = 1
                confirm_rect = pygame.Rect(0, 0, 160, 36)
                confirm_rect.center = (center_x, btn_y)

                self._draw_button(screen, "확정", center_x, btn_y,
                                  (40, 80, 40), selected=True)

                self._reroll_btn_rect = None
                self._confirm_btn_rect = confirm_rect

            # 조작 안내
            guide_text = "◀ ▶ 선택  /  Space 확정"
            guide_surface = self.small_font.render(guide_text, True, (140, 140, 160))
            guide_rect = guide_surface.get_rect(centerx=center_x, y=btn_y + 24)
            screen.blit(guide_surface, guide_rect)

    def handle_confirm(self):
        """확정 입력 (Space/Enter) → 현재 선택된 버튼 실행"""
        if self.waiting_for_confirm:
            self.confirm_pressed = True

    def handle_move_left(self):
        """좌측 이동 (←/A) → 다시 굴리기 버튼 선택"""
        if self.waiting_for_confirm and self.rerolls_remaining > 0:
            self.selected_button = 0

    def handle_move_right(self):
        """우측 이동 (→/D) → 확정 버튼 선택"""
        if self.waiting_for_confirm:
            self.selected_button = 1

    def handle_mouse_click(self, mouse_pos):
        """마우스 클릭 처리 → 클릭된 버튼 즉시 실행"""
        if not self.waiting_for_confirm:
            return
        reroll_rect = getattr(self, '_reroll_btn_rect', None)
        if reroll_rect and reroll_rect.collidepoint(mouse_pos) and self.rerolls_remaining > 0:
            self.selected_button = 0
            self.confirm_pressed = True
            return
        confirm_rect = getattr(self, '_confirm_btn_rect', None)
        if confirm_rect and confirm_rect.collidepoint(mouse_pos):
            self.selected_button = 1
            self.confirm_pressed = True

    def reset(self):
        """모든 영구 보너스 초기화 (게임 오버 / 메인 메뉴 복귀 시)"""
        for key in self.permanent_bonuses:
            self.permanent_bonuses[key] = 0
        for key in self.last_roll:
            self.last_roll[key] = 0
        self.use_count = 0
        self._roll_applied = False
        self.rerolls_remaining = 0
        self.reroll_requested = False
        self.selected_button = 1
        self.confirm_pressed = False
        self.is_rolling = False
        self.waiting_for_confirm = False
        self.locked_face_value = None
        self.displayed_face_value = 1
        self.final_idle_phase = 0.0
        self.dice_offset_y = 0.0
        self.dice_vertical_velocity = 0.0
        self.flame_particles.clear()
        self._reroll_btn_rect = None
        self._confirm_btn_rect = None
        print("😈 악마의 주사위 영구 효과가 초기화되었습니다.")

    def get_save_data(self) -> Dict[str, Any]:
        """저장 데이터 반환"""
        return {
            'permanent_bonuses': self.permanent_bonuses.copy(),
            'use_count': self.use_count,
        }

    def load_save_data(self, data: Dict[str, Any]):
        """저장 데이터 로드"""
        saved_bonuses = data.get('permanent_bonuses', {})
        for key in self.permanent_bonuses:
            self.permanent_bonuses[key] = saved_bonuses.get(key, 0)
        self.use_count = data.get('use_count', 0)


# ──────────────────────────────────────────────
#  전역 인스턴스 & 외부 API
# ──────────────────────────────────────────────
devil_dice_instance = None


def get_devil_dice_instance() -> DevilDice:
    """악마의 주사위 인스턴스 반환"""
    global devil_dice_instance
    if devil_dice_instance is None:
        devil_dice_instance = DevilDice()
    return devil_dice_instance


def activate_devil_dice(game_state: Dict[str, Any], current_stage: int) -> Dict[str, float]:
    """악마의 주사위 발동 (외부 호출)"""
    instance = get_devil_dice_instance()
    return instance.activate(game_state, current_stage)


def update_devil_dice(current_stage: int) -> bool:
    """악마의 주사위 업데이트"""
    instance = get_devil_dice_instance()
    return instance.update(current_stage)


def draw_devil_dice_effects(screen: pygame.Surface, paddle_rect: pygame.Rect = None):
    """악마의 주사위 시각 효과 그리기"""
    instance = get_devil_dice_instance()
    if paddle_rect:
        instance.draw_paddle_effect(screen, paddle_rect)
    instance.draw_dice_results(screen, 300, 375)


def get_devil_dice_multipliers() -> Dict[str, float]:
    """현재 영구 배율 반환"""
    instance = get_devil_dice_instance()
    return instance.get_current_multipliers()


def is_devil_dice_active() -> bool:
    """악마의 주사위 효과 존재 여부 (영구 보너스 또는 애니메이션 중)"""
    instance = get_devil_dice_instance()
    return instance.has_bonuses() or instance.is_rolling


def get_devil_dice_duration_ratio() -> float:
    """지속시간 비율 (영구 아이템이므로 항상 1.0 또는 0.0)"""
    instance = get_devil_dice_instance()
    if instance.has_bonuses():
        return 1.0
    return 0.0


def handle_devil_dice_spacebar():
    """악마의 주사위 확정 입력 (Space/Enter)"""
    instance = get_devil_dice_instance()
    instance.handle_confirm()


def handle_devil_dice_move_left():
    """악마의 주사위 좌측 이동 (←/A)"""
    instance = get_devil_dice_instance()
    instance.handle_move_left()


def handle_devil_dice_move_right():
    """악마의 주사위 우측 이동 (→/D)"""
    instance = get_devil_dice_instance()
    instance.handle_move_right()


def handle_devil_dice_mouse_click(mouse_pos):
    """악마의 주사위 마우스 클릭 처리"""
    instance = get_devil_dice_instance()
    instance.handle_mouse_click(mouse_pos)


def is_devil_dice_waiting_confirm() -> bool:
    """악마의 주사위가 확정/다시굴리기 대기 중인지 확인"""
    instance = get_devil_dice_instance()
    return instance.waiting_for_confirm


def is_devil_dice_rolling() -> bool:
    """악마의 주사위가 굴려지는 중인지 확인 (게임 일시정지용)"""
    instance = get_devil_dice_instance()
    return instance.is_rolling


def deactivate_devil_dice():
    """악마의 주사위 효과 강제 종료 → 영구 보너스 초기화"""
    instance = get_devil_dice_instance()
    instance.reset()


def get_devil_dice_permanent_bonuses() -> Dict[str, int]:
    """영구 보너스 백분율 딕셔너리 반환 (TAB 스탯 표시용)"""
    instance = get_devil_dice_instance()
    return instance.permanent_bonuses.copy()
