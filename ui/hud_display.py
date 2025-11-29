"""
HUD 디스플레이 모듈
- 점수 표시 (KBO 프리미엄 야구 전광판 스타일)
- 메달 점수 표시
- 대시 관련 시각 효과
"""

import pygame
import math
import random
import sys
import os
# 상위 디렉토리를 경로에 추가하여 pixel_font_manager import 가능하게 함
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from pixel_font_manager import get_font, FontStyle

# 대시 스피릿 레이저 관련 상수
DASH_SPIRIT_LASER_DURATION = 360  # 6초 (60fps 기준)


def draw_premium_led(surface, x, y, color, size=5, intensity=1.0, is_on=True):
    """프리미엄 LED 도트 - 실제 LED처럼 발광 효과"""
    if is_on:
        # 외부 글로우 (여러 레이어)
        for i in range(6, 0, -1):
            glow_radius = size + i * 2
            glow_alpha = int(40 * intensity / i)
            glow_surf = pygame.Surface((glow_radius * 2 + 10, glow_radius * 2 + 10), pygame.SRCALPHA)
            glow_color = (color[0], color[1], color[2], glow_alpha)
            pygame.draw.circle(glow_surf, glow_color, (glow_radius + 5, glow_radius + 5), glow_radius)
            surface.blit(glow_surf, (x - glow_radius - 5 + size//2, y - glow_radius - 5 + size//2))

        # 메인 LED 바디
        pygame.draw.circle(surface, color, (x, y), size)

        # 밝은 중심부
        bright_color = (min(255, color[0] + 80), min(255, color[1] + 80), min(255, color[2] + 80))
        pygame.draw.circle(surface, bright_color, (x, y), size - 2)

        # 하이라이트 (반짝임)
        highlight = (min(255, color[0] + 150), min(255, color[1] + 150), min(255, color[2] + 150))
        pygame.draw.circle(surface, highlight, (x - size//3, y - size//3), size // 3)
    else:
        # 꺼진 LED (미묘한 반사)
        dim_color = (max(10, color[0] // 12), max(10, color[1] // 12), max(10, color[2] // 12))
        pygame.draw.circle(surface, dim_color, (x, y), size - 1)
        # 유리 반사
        pygame.draw.circle(surface, (30, 30, 35), (x - size//4, y - size//4), size // 4)


def draw_slim_digit(surface, x, y, digit, color, size=110, dot_radius=3):
    """슬림 도트 매트릭스 숫자 - 7x11 해상도 (더 얇고 세련된 디자인)"""
    patterns = {
        '0': [
            " 11111 ",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            " 11111 "
        ],
        '1': [
            "   11  ",
            "  111  ",
            " 1111  ",
            "   11  ",
            "   11  ",
            "   11  ",
            "   11  ",
            "   11  ",
            "   11  ",
            "   11  ",
            " 111111"
        ],
        '2': [
            " 11111 ",
            "11   11",
            "     11",
            "     11",
            "    11 ",
            "   11  ",
            "  11   ",
            " 11    ",
            "11     ",
            "11   11",
            "1111111"
        ],
        '3': [
            " 11111 ",
            "11   11",
            "     11",
            "     11",
            "  1111 ",
            "     11",
            "     11",
            "     11",
            "     11",
            "11   11",
            " 11111 "
        ],
        '4': [
            "    111",
            "   1111",
            "  11 11",
            " 11  11",
            "11   11",
            "11   11",
            "1111111",
            "     11",
            "     11",
            "     11",
            "     11"
        ],
        '5': [
            "1111111",
            "11     ",
            "11     ",
            "11     ",
            "111111 ",
            "     11",
            "     11",
            "     11",
            "     11",
            "11   11",
            " 11111 "
        ],
        '6': [
            " 11111 ",
            "11   11",
            "11     ",
            "11     ",
            "111111 ",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            " 11111 "
        ],
        '7': [
            "1111111",
            "11   11",
            "     11",
            "    11 ",
            "    11 ",
            "   11  ",
            "   11  ",
            "  11   ",
            "  11   ",
            "  11   ",
            "  11   "
        ],
        '8': [
            " 11111 ",
            "11   11",
            "11   11",
            "11   11",
            " 11111 ",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            "11   11",
            " 11111 "
        ],
        '9': [
            " 11111 ",
            "11   11",
            "11   11",
            "11   11",
            " 111111",
            "     11",
            "     11",
            "     11",
            "     11",
            "11   11",
            " 11111 "
        ]
    }

    pattern = patterns.get(str(digit), patterns['0'])
    rows = 11
    cols = 7
    spacing = size // rows

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2
            draw_premium_led(surface, dot_x, dot_y, color, dot_radius, 1.0, char == '1')


def draw_brushed_metal(surface, rect, base_color=(70, 75, 85), direction='horizontal'):
    """브러시드 메탈 효과"""
    x, y, w, h = rect
    for i in range(h if direction == 'horizontal' else w):
        variation = random.randint(-8, 8)
        line_color = tuple(max(0, min(255, c + variation)) for c in base_color)
        if direction == 'horizontal':
            pygame.draw.line(surface, line_color, (x, y + i), (x + w, y + i))
        else:
            pygame.draw.line(surface, line_color, (x + i, y), (x + i, y + h))


def draw_premium_frame(surface, rect, frame_color=(75, 80, 90), thickness=18):
    """프리미엄 금속 프레임 - 3D 효과"""
    x, y, w, h = rect

    # 외부 그림자
    shadow = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
    pygame.draw.rect(shadow, (0, 0, 0, 80), (10, 10, w, h), border_radius=8)
    surface.blit(shadow, (x - 5, y - 5))

    # 프레임 배경 (브러시드 메탈)
    frame_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    draw_brushed_metal(frame_surf, (0, 0, w, thickness), frame_color)
    draw_brushed_metal(frame_surf, (0, h - thickness, w, thickness), frame_color)
    draw_brushed_metal(frame_surf, (0, 0, thickness, h), frame_color, 'vertical')
    draw_brushed_metal(frame_surf, (w - thickness, 0, thickness, h), frame_color, 'vertical')
    surface.blit(frame_surf, (x, y))

    # 하이라이트 (상단/좌측)
    highlight = tuple(min(255, c + 50) for c in frame_color)
    pygame.draw.line(surface, highlight, (x, y), (x + w - 1, y), 2)
    pygame.draw.line(surface, highlight, (x, y), (x, y + h - 1), 2)

    # 그림자 (하단/우측)
    shadow_color = tuple(max(0, c - 40) for c in frame_color)
    pygame.draw.line(surface, shadow_color, (x + 1, y + h - 1), (x + w, y + h - 1), 3)
    pygame.draw.line(surface, shadow_color, (x + w - 1, y + 1), (x + w - 1, y + h), 3)

    # 볼트 장식 (모서리)
    bolt_positions = [
        (x + thickness//2, y + thickness//2),
        (x + w - thickness//2, y + thickness//2),
        (x + thickness//2, y + h - thickness//2),
        (x + w - thickness//2, y + h - thickness//2)
    ]
    for bx, by in bolt_positions:
        # 볼트 구멍
        pygame.draw.circle(surface, (40, 45, 50), (bx, by), 8)
        pygame.draw.circle(surface, (60, 65, 70), (bx, by), 6)
        # + 모양
        pygame.draw.line(surface, (50, 55, 60), (bx - 4, by), (bx + 4, by), 2)
        pygame.draw.line(surface, (50, 55, 60), (bx, by - 4), (bx, by + 4), 2)
        # 하이라이트
        pygame.draw.circle(surface, (90, 95, 100), (bx - 2, by - 2), 2)


class HUDDisplay:
    """HUD 표시 시스템"""

    def __init__(self, screen, width, height, draw_field_func=None, draw_objects_func=None):
        self.screen = screen
        self.width = width
        self.height = height
        self.draw_field_func = draw_field_func
        self.draw_objects_func = draw_objects_func

        # 폰트 초기화 - 네오둥근모 픽셀 폰트 사용
        self.font_title = FontStyle.title()  # 48pt 픽셀 폰트
        self.font_score = get_font(140)  # 140pt 픽셀 폰트 (숫자)
        self.font_subtitle = FontStyle.menu()  # 28pt 픽셀 폰트 (PLAYER, BOSS)
        self.font_vs = get_font(36)  # 36pt 픽셀 폰트 (VS)
        self.font_medal = FontStyle.body()  # 24pt 픽셀 폰트 (메달 점수)
        self.font_large = get_font(60)  # 60pt 폰트 (팀 이름)
        self.font_medium = get_font(36)  # 36pt 폰트
        self.font_small = get_font(24)  # 24pt 폰트

        # 색상 정의
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)

    def show_score(self, player_score, ai_score):
        """KBO 프리미엄 야구 전광판 스타일 점수판"""

        # 키 이벤트 큐 비우기 - 대쉬 버그 방지
        pygame.event.clear()
        pygame.event.pump()

        # 점수판 크기 및 위치 설정 (화면 크기에 맞게 조정)
        board_width = min(680, self.width - 40)
        board_height = min(380, self.height - 80)
        board_x = (self.width - board_width) // 2
        board_y = (self.height - board_height) // 2

        # 내부 영역 계산
        inner_x = board_x + 24
        inner_y = board_y + 24
        inner_w = board_width - 48
        inner_h = board_height - 48

        clock = pygame.time.Clock()
        animation_timer = 0

        # 페이드인 애니메이션
        for alpha in range(0, 256, 18):
            self._draw_kbo_scoreboard(player_score, ai_score, board_x, board_y,
                                      board_width, board_height, inner_x, inner_y,
                                      inner_w, inner_h, animation_timer, alpha)
            pygame.display.flip()
            clock.tick(60)
            animation_timer += 1

        # 점수판 표시 시간 (1.5초)
        for _ in range(90):
            self._draw_kbo_scoreboard(player_score, ai_score, board_x, board_y,
                                      board_width, board_height, inner_x, inner_y,
                                      inner_w, inner_h, animation_timer, 255)
            pygame.display.flip()
            clock.tick(60)
            animation_timer += 1

    def _draw_kbo_scoreboard(self, player_score, ai_score, board_x, board_y,
                              board_width, board_height, inner_x, inner_y,
                              inner_w, inner_h, animation_timer, alpha):
        """KBO 스타일 점수판 그리기"""
        # 배경 그리기
        if self.draw_field_func:
            self.draw_field_func()
        if self.draw_objects_func:
            self.draw_objects_func()

        # 반투명 오버레이
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, int(180 * alpha / 255)))
        self.screen.blit(overlay, (0, 0))

        # 메인 점수판 서피스
        board_surface = pygame.Surface((board_width + 40, board_height + 40), pygame.SRCALPHA)

        # 네이비 배경
        pygame.draw.rect(board_surface, (8, 12, 30), (20, 20, board_width, board_height))

        # 골드 프레임
        draw_premium_frame(board_surface, (20, 20, board_width, board_height), (90, 80, 60), 18)

        # 내부 LED 패널
        pygame.draw.rect(board_surface, (5, 8, 22), (44, 44, inner_w, inner_h))

        # 상단 팀 로고 영역
        header_x = 54
        header_y = 52
        header_w = inner_w - 20
        header_h = 60
        pygame.draw.rect(board_surface, (12, 18, 40), (header_x, header_y, header_w, header_h))
        pygame.draw.rect(board_surface, (200, 170, 80), (header_x, header_y, header_w, header_h), 2)

        # 플레이어 로고 (파란색 원) - 글로우 효과 추가
        p_logo_x = header_x + 50
        p_logo_y = header_y + 30
        # 글로우 효과
        for i in range(4, 0, -1):
            glow_surf = pygame.Surface((70, 70), pygame.SRCALPHA)
            glow_color = (50, 120, 200, 50 // i)
            pygame.draw.circle(glow_surf, glow_color, (35, 35), 22 + i * 4)
            board_surface.blit(glow_surf, (p_logo_x - 35, p_logo_y - 35))
        pygame.draw.circle(board_surface, (30, 80, 180), (p_logo_x, p_logo_y), 22)
        pygame.draw.circle(board_surface, (80, 140, 255), (p_logo_x, p_logo_y), 18)
        pygame.draw.circle(board_surface, (120, 180, 255), (p_logo_x, p_logo_y), 14)
        p_icon = self.font_medium.render("P", True, self.WHITE)
        p_icon_rect = p_icon.get_rect(center=(p_logo_x, p_logo_y))
        board_surface.blit(p_icon, p_icon_rect)

        # 플레이어 이름
        p_name = self.font_large.render("플레이어", True, (100, 180, 255))
        board_surface.blit(p_name, (header_x + 85, header_y + 12))

        # 보스 로고 (빨간색 원) - 글로우 효과 추가
        b_logo_x = header_x + header_w - 50
        b_logo_y = header_y + 30
        # 글로우 효과
        for i in range(4, 0, -1):
            glow_surf = pygame.Surface((70, 70), pygame.SRCALPHA)
            glow_color = (200, 80, 80, 50 // i)
            pygame.draw.circle(glow_surf, glow_color, (35, 35), 22 + i * 4)
            board_surface.blit(glow_surf, (b_logo_x - 35, b_logo_y - 35))
        pygame.draw.circle(board_surface, (180, 50, 50), (b_logo_x, b_logo_y), 22)
        pygame.draw.circle(board_surface, (255, 100, 100), (b_logo_x, b_logo_y), 18)
        pygame.draw.circle(board_surface, (255, 140, 140), (b_logo_x, b_logo_y), 14)
        b_icon = self.font_medium.render("B", True, self.WHITE)
        b_icon_rect = b_icon.get_rect(center=(b_logo_x, b_logo_y))
        board_surface.blit(b_icon, b_icon_rect)

        # 보스 이름
        b_name = self.font_large.render("보스", True, (255, 120, 120))
        b_name_rect = b_name.get_rect(right=header_x + header_w - 85, top=header_y + 12)
        board_surface.blit(b_name, b_name_rect)

        # 점수 영역
        score_area_x = header_x + 5
        score_area_y = header_y + header_h + 15
        score_area_w = header_w - 10
        score_area_h = inner_h - header_h - 70
        pygame.draw.rect(board_surface, (8, 12, 28), (score_area_x, score_area_y, score_area_w, score_area_h))
        pygame.draw.rect(board_surface, (180, 150, 70), (score_area_x, score_area_y, score_area_w, score_area_h), 3)

        # 중앙 분리선
        center_x = 20 + board_width // 2
        pygame.draw.line(board_surface, (180, 150, 70),
                        (center_x, score_area_y + 5), (center_x, score_area_y + score_area_h - 5), 3)

        # LED 점수 (펄스 애니메이션)
        pulse = 0.85 + 0.15 * math.sin(animation_timer * 0.1)
        blue_led = (80, 180, 255)
        red_led = (255, 100, 100)

        # 슬림 LED 크기 계산 (7x11 패턴)
        led_size = min(100, score_area_h - 25)
        dot_radius = max(2, led_size // 35)

        # 슬림 도트 매트릭스 숫자의 실제 크기 계산 (7열 x 11행)
        digit_width = 7 * (led_size // 11)
        digit_height = led_size

        # 왼쪽 영역 (플레이어): score_area_x ~ center_x
        left_area_width = center_x - score_area_x
        # 오른쪽 영역 (보스): center_x ~ score_area_x + score_area_w
        right_area_width = (score_area_x + score_area_w) - center_x

        # 플레이어 점수 - 왼쪽 영역 중앙
        p_score_x = score_area_x + (left_area_width - digit_width) // 2
        p_score_y = score_area_y + (score_area_h - digit_height) // 2
        p_color = (int(blue_led[0]*pulse), int(blue_led[1]*pulse), int(blue_led[2]*pulse))
        draw_slim_digit(board_surface, p_score_x, p_score_y, player_score, p_color, led_size, dot_radius)

        # 보스 점수 - 오른쪽 영역 중앙
        b_score_x = center_x + (right_area_width - digit_width) // 2
        b_score_y = score_area_y + (score_area_h - digit_height) // 2
        b_color = (int(red_led[0]*pulse), int(red_led[1]*pulse), int(red_led[2]*pulse))
        draw_slim_digit(board_surface, b_score_x, b_score_y, ai_score, b_color, led_size, dot_radius)

        # VS 배지
        vs_bg_x = center_x - 28
        vs_bg_y = score_area_y + score_area_h // 2 - 22
        pygame.draw.rect(board_surface, (50, 40, 20), (vs_bg_x, vs_bg_y, 56, 44))
        pygame.draw.rect(board_surface, (200, 170, 80), (vs_bg_x, vs_bg_y, 56, 44), 2)
        vs_text = self.font_medium.render("VS", True, (255, 220, 120))
        vs_rect = vs_text.get_rect(center=(center_x, score_area_y + score_area_h // 2))
        board_surface.blit(vs_text, vs_rect)

        # 하단 정보
        footer_x = header_x + 5
        footer_y = inner_y + inner_h - 52
        footer_w = header_w - 10
        footer_h = 36
        pygame.draw.rect(board_surface, (15, 22, 45), (footer_x, footer_y, footer_w, footer_h))
        pygame.draw.rect(board_surface, (150, 130, 60), (footer_x, footer_y, footer_w, footer_h), 2)

        info_text = self.font_medium.render("◆ 3점 선취 승리 ◆", True, (255, 220, 120))
        info_rect = info_text.get_rect(center=(20 + board_width // 2, footer_y + footer_h // 2))
        board_surface.blit(info_text, info_rect)

        # 알파 적용 및 화면에 그리기
        board_surface.set_alpha(alpha)
        self.screen.blit(board_surface, (board_x - 20, board_y - 20))

    def draw_medal_score(self, medal_score):
        """메달 점수 표시"""
        medal_text = f"🏅 {medal_score}"
        text_surface = self.font_medal.render(medal_text, True, (255, 215, 0))
        text_rect = text_surface.get_rect()
        text_rect.topright = (self.width - 20, 20)

        # 배경 박스
        padding = 10
        bg_rect = text_rect.inflate(padding * 2, padding)
        pygame.draw.rect(self.screen, (0, 0, 0, 128), bg_rect)
        pygame.draw.rect(self.screen, (255, 215, 0), bg_rect, 2)

        self.screen.blit(text_surface, text_rect)

    def draw_dash_spirit_lasers(self, player_rect, dash_spirits):
        """대시 스피릿 레이저 그리기 - 매우 얇고 긴 타원형"""
        for laser in dash_spirits:
            # 레이저가 유효한 경우에만 그리기
            if laser.get('remaining_time', 0) > 0:
                start_x = int(laser['start_x'])
                start_y = int(laser['start_y'])
                end_x = int(laser['end_x'])
                end_y = int(laser['end_y'])
                alpha = laser.get('alpha', 255)

                # 알파값이 너무 낮으면 그리지 않음
                if alpha < 10:
                    continue

                # 타원의 중심점과 크기 계산
                center_x = (start_x + end_x) // 2
                center_y = (start_y + end_y) // 2

                # 타원의 가로 반경 (레이저 길이의 절반)
                ellipse_width = abs(end_x - start_x) // 2
                # 타원의 세로 반경 (매우 얇게 - 3~8 픽셀)
                ellipse_height = 5  # 기본 높이

                # 타원을 그리기 위한 rect 생성
                if ellipse_width > 0:
                    # 외부 글로우 타원들 (여러 층으로 그려서 글로우 효과)
                    for i in range(5, 0, -1):
                        glow_alpha = min(255, int(alpha * 0.2 / i))
                        glow_color = (100, 200, 255)

                        if glow_alpha > 0:
                            # 글로우 타원 (점점 큰 타원으로 글로우 효과)
                            glow_height = ellipse_height + i * 2
                            glow_rect = pygame.Rect(center_x - ellipse_width - i*2,
                                                   center_y - glow_height,
                                                   (ellipse_width + i*2) * 2,
                                                   glow_height * 2)

                            # 타원 그리기 (filled=False로 외곽선만)
                            try:
                                glow_surface = pygame.Surface((glow_rect.width, glow_rect.height), pygame.SRCALPHA)
                                pygame.draw.ellipse(glow_surface, (*glow_color, glow_alpha),
                                                  (0, 0, glow_rect.width, glow_rect.height))
                                self.screen.blit(glow_surface, glow_rect.topleft)
                            except:
                                pass

                    # 메인 레이저 타원 (채워진 타원)
                    main_rect = pygame.Rect(center_x - ellipse_width,
                                           center_y - ellipse_height,
                                           ellipse_width * 2,
                                           ellipse_height * 2)

                    # 메인 타원 색상 (밝은 청백색)
                    main_color = (200, 230, 255)
                    main_alpha = min(255, alpha)

                    try:
                        main_surface = pygame.Surface((main_rect.width, main_rect.height), pygame.SRCALPHA)
                        pygame.draw.ellipse(main_surface, (*main_color, main_alpha),
                                          (0, 0, main_rect.width, main_rect.height))
                        self.screen.blit(main_surface, main_rect.topleft)
                    except:
                        pass

                    # 코어 타원 (더 밝고 작은 중심부)
                    core_height = ellipse_height - 2
                    core_width = ellipse_width - 10
                    if core_width > 0 and core_height > 0:
                        core_rect = pygame.Rect(center_x - core_width,
                                               center_y - core_height,
                                               core_width * 2,
                                               core_height * 2)

                        core_color = (255, 255, 255)
                        core_alpha = min(255, int(alpha * 0.8))

                        try:
                            core_surface = pygame.Surface((core_rect.width, core_rect.height), pygame.SRCALPHA)
                            pygame.draw.ellipse(core_surface, (*core_color, core_alpha),
                                              (0, 0, core_rect.width, core_rect.height))
                            self.screen.blit(core_surface, core_rect.topleft)
                        except:
                            pass

                # 레이저 시작 부분 이펙트 (원형 발광)
                if laser.get('remaining_time', 0) > DASH_SPIRIT_LASER_DURATION - 10:
                    # 생성 초기 충격파 효과
                    impact_radius = (10 - (DASH_SPIRIT_LASER_DURATION - laser['remaining_time'])) * 3
                    pygame.draw.circle(self.screen, (150, 220, 255, 100),
                                     (start_x, start_y), impact_radius, 2)

                # 타원 주변 스파크 효과
                for _ in range(3):
                    # 타원 경로상의 랜덤 위치
                    t = random.random()
                    spark_x = int(start_x + t * (end_x - start_x) + random.randint(-3, 3))
                    spark_y = center_y + random.randint(-ellipse_height-2, ellipse_height+2)
                    spark_size = random.randint(1, 2)
                    spark_alpha = int(alpha * random.uniform(0.5, 1.0))
                    pygame.draw.circle(self.screen, (200, 230, 255, spark_alpha),
                                     (spark_x, spark_y), spark_size)


# 싱글톤 인스턴스
_hud_display = None

def init_hud_display(screen, width, height, draw_field_func=None, draw_objects_func=None):
    """HUD 디스플레이 초기화"""
    global _hud_display
    _hud_display = HUDDisplay(screen, width, height, draw_field_func, draw_objects_func)
    return _hud_display

# 호환성을 위한 래퍼 함수들
def show_score(screen, player_score, ai_score, width=600, height=750, draw_field_func=None, draw_objects_func=None):
    """점수 표시 (호환성 래퍼)"""
    global _hud_display
    if _hud_display is None:
        _hud_display = HUDDisplay(screen, width, height, draw_field_func, draw_objects_func)
    else:
        # 함수가 전달되면 업데이트
        if draw_field_func is not None:
            _hud_display.draw_field_func = draw_field_func
        if draw_objects_func is not None:
            _hud_display.draw_objects_func = draw_objects_func
    _hud_display.show_score(player_score, ai_score)

def draw_medal_score(screen, medal_score, width=600, height=750):
    """메달 점수 표시 (호환성 래퍼)"""
    global _hud_display
    if _hud_display is None:
        _hud_display = HUDDisplay(screen, width, height)
    _hud_display.draw_medal_score(medal_score)

def draw_dash_spirit_lasers(screen, player_rect, dash_spirits, width=600, height=750):
    """대시 스피릿 레이저 그리기 (호환성 래퍼)"""
    global _hud_display
    if _hud_display is None:
        _hud_display = HUDDisplay(screen, width, height)
    _hud_display.draw_dash_spirit_lasers(player_rect, dash_spirits)
