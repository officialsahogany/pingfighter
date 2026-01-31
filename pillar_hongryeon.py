# -*- coding: utf-8 -*-
"""
홍련 중국 전통 필러 배경 (고퀄리티 버전)
- 게임 내 실제 스테이지 6 (홍련) = 코드 상 current_stage == 5
- 인게임 색상과 일치하는 어두운 마룬/크림슨 톤
- 그라데이션 기반 고급스러운 디자인
- 육각형 패턴, 등불, 소용돌이 장식
- 광폭화 모드: 항아리에서 뱀이 나와 화염탄 발사
"""

import math
import random
import pygame
from typing import Callable, Optional, List, Tuple


class SnakePot:
    """항아리에서 나오는 뱀 클래스 - 광폭화 모드 전용"""

    # 뱀 상태
    STATE_IDLE = "idle"           # 항아리 안에 숨어있음
    STATE_RISING = "rising"       # 뱀이 올라오는 중
    STATE_AIMING = "aiming"       # 조준 중 (머리 흔들림)
    STATE_FIRING = "firing"       # 발사 중
    STATE_HIDING = "hiding"       # 다시 숨는 중

    # 색상 (뱀)
    SNAKE_COLORS = {
        'body_dark': (45, 80, 35),        # 어두운 녹색
        'body_mid': (65, 120, 50),         # 중간 녹색
        'body_light': (90, 160, 70),       # 밝은 녹색
        'pattern': (180, 60, 40),          # 붉은 무늬
        'eye': (255, 200, 50),             # 노란 눈
        'tongue': (200, 50, 60),           # 붉은 혀
    }

    # 항아리 색상 (중국 도자기 스타일)
    POT_COLORS = {
        'body_dark': (60, 35, 25),         # 어두운 갈색
        'body_mid': (100, 60, 40),         # 중간 갈색
        'body_light': (140, 90, 60),       # 밝은 갈색
        'rim_gold': (200, 160, 80),        # 금색 테두리
        'pattern_red': (180, 50, 40),      # 붉은 문양
        'lid': (80, 50, 35),               # 뚜껑
    }

    def __init__(self, x: int, y: int, side: str, index: int):
        """
        Args:
            x: 항아리 중심 X 좌표
            y: 항아리 중심 Y 좌표
            side: 'left' 또는 'right' (필러 위치)
            index: 항아리 인덱스 (0, 1, 2)
        """
        self.x = x
        self.y = y
        self.side = side
        self.index = index

        # 호리병(등불) 크기 - 기존 _draw_lanterns와 일치
        self.lantern_size = 35  # 등불 크기
        self.vase_height = int(self.lantern_size * 2.8)  # 호리병 높이 (약 98)

        # 뱀 상태
        self.state = self.STATE_IDLE
        self.state_timer = 0.0

        # 뱀 애니메이션
        self.snake_rise_progress = 0.0  # 0.0 ~ 1.0 (뱀이 얼마나 올라왔는지)
        self.snake_max_height = 80      # 뱀이 올라오는 최대 높이
        self.snake_head_angle = 0.0     # 뱀 머리 각도 (플레이어 조준)
        self.snake_wobble = 0.0         # 뱀 머리 흔들림
        self.tongue_flick = 0.0         # 혀 날름거림 타이머

        # 타이밍 상수
        self.RISE_DURATION = 0.8        # 올라오는 시간 (초)
        self.AIM_DURATION = 0.6         # 조준 시간 (초)
        self.FIRE_DURATION = 0.3        # 발사 애니메이션 시간 (초)
        self.HIDE_DURATION = 0.5        # 숨는 시간 (초)

        # 발사 콜백 (pingfighter.py에서 설정)
        self.fire_callback: Optional[Callable[[int, int, int, int], None]] = None

        # 플레이어 위치 (조준용)
        self.target_x = 380  # 기본값 (게임 중앙)
        self.target_y = 710  # 플레이어 Y 위치

        # 발사 완료 플래그
        self.fired_this_cycle = False

    def start_attack(self, target_x: int, target_y: int):
        """뱀 공격 시작"""
        if self.state != self.STATE_IDLE:
            return False

        self.state = self.STATE_RISING
        self.state_timer = 0.0
        self.snake_rise_progress = 0.0
        self.target_x = target_x
        self.target_y = target_y
        self.fired_this_cycle = False
        return True

    def update(self, dt: float):
        """뱀 상태 업데이트"""
        self.state_timer += dt
        self.tongue_flick += dt * 8  # 혀 애니메이션

        if self.state == self.STATE_RISING:
            # 뱀이 올라오는 중
            progress = min(1.0, self.state_timer / self.RISE_DURATION)
            # 이징: ease-out
            self.snake_rise_progress = 1.0 - (1.0 - progress) ** 2

            if self.state_timer >= self.RISE_DURATION:
                self.state = self.STATE_AIMING
                self.state_timer = 0.0

        elif self.state == self.STATE_AIMING:
            # 조준 중 - 머리 흔들림
            self.snake_wobble = math.sin(self.state_timer * 12) * 0.15

            # 플레이어 방향 계산
            snake_head_x = self.x
            snake_head_y = self.y - self.vase_height // 2 - self.snake_max_height * self.snake_rise_progress
            dx = self.target_x - snake_head_x
            dy = self.target_y - snake_head_y
            target_angle = math.atan2(dy, dx)

            # 부드러운 조준 (lerp)
            angle_diff = target_angle - self.snake_head_angle
            while angle_diff > math.pi:
                angle_diff -= 2 * math.pi
            while angle_diff < -math.pi:
                angle_diff += 2 * math.pi
            self.snake_head_angle += angle_diff * dt * 5

            if self.state_timer >= self.AIM_DURATION:
                self.state = self.STATE_FIRING
                self.state_timer = 0.0

        elif self.state == self.STATE_FIRING:
            # 발사 - 콜백 호출
            if not self.fired_this_cycle and self.fire_callback:
                snake_head_x = int(self.x)
                snake_head_y = int(self.y - self.vase_height // 2 - self.snake_max_height * self.snake_rise_progress)
                self.fire_callback(snake_head_x, snake_head_y, self.target_x, self.target_y)
                self.fired_this_cycle = True

            if self.state_timer >= self.FIRE_DURATION:
                self.state = self.STATE_HIDING
                self.state_timer = 0.0

        elif self.state == self.STATE_HIDING:
            # 다시 숨는 중
            progress = min(1.0, self.state_timer / self.HIDE_DURATION)
            # 이징: ease-in
            self.snake_rise_progress = 1.0 - progress ** 2

            if self.state_timer >= self.HIDE_DURATION:
                self.state = self.STATE_IDLE
                self.state_timer = 0.0
                self.snake_rise_progress = 0.0

    def draw(self, screen: pygame.Surface):
        """뱀만 그리기 (호리병은 기존 _draw_lanterns에서 그려짐)"""
        # 뱀 그리기 (올라와 있을 때만)
        if self.snake_rise_progress > 0.01:
            self._draw_snake(screen)

    def _draw_pot(self, screen: pygame.Surface):
        """항아리 본체 그리기"""
        cx, cy = self.x, self.y
        w, h = self.pot_width, self.pot_height

        # 항아리 형태 (타원형 본체)
        # 그림자
        shadow_rect = pygame.Rect(cx - w//2 + 3, cy - h//2 + 5, w, h)
        pygame.draw.ellipse(screen, (20, 10, 10), shadow_rect)

        # 본체 외곽 (어두운)
        body_rect = pygame.Rect(cx - w//2, cy - h//2, w, h)
        pygame.draw.ellipse(screen, self.POT_COLORS['body_dark'], body_rect)

        # 본체 중간층
        inner_rect = pygame.Rect(cx - w//2 + 4, cy - h//2 + 4, w - 8, h - 8)
        pygame.draw.ellipse(screen, self.POT_COLORS['body_mid'], inner_rect)

        # 하이라이트
        highlight_rect = pygame.Rect(cx - w//4, cy - h//3, w//3, h//3)
        pygame.draw.ellipse(screen, self.POT_COLORS['body_light'], highlight_rect)

        # 붉은 문양 (중국 스타일)
        pattern_y = cy
        pygame.draw.ellipse(screen, self.POT_COLORS['pattern_red'],
                           (cx - w//3, pattern_y - 4, w*2//3, 8), 2)

        # 금색 테두리 (입구)
        rim_y = cy - h//2 + 2
        pygame.draw.ellipse(screen, self.POT_COLORS['rim_gold'],
                           (cx - w//3 - 2, rim_y - 4, w*2//3 + 4, 10), 3)

    def _draw_pot_lid(self, screen: pygame.Surface):
        """항아리 뚜껑 그리기 (뱀이 나와있으면 기울어진 상태)"""
        cx, cy = self.x, self.y
        w = self.pot_width
        lid_y = cy - self.pot_height // 2 - 2

        if self.snake_rise_progress > 0.1:
            # 뚜껑이 열린 상태 - 옆으로 기울어짐
            lid_offset = int(self.snake_rise_progress * 25)
            lid_tilt = self.snake_rise_progress * 0.4

            # 기울어진 뚜껑
            if self.side == 'left':
                lid_x = cx - w//3 - lid_offset
            else:
                lid_x = cx + w//3 + lid_offset - 20

            # 뚜껑 (타원)
            lid_surf = pygame.Surface((30, 15), pygame.SRCALPHA)
            pygame.draw.ellipse(lid_surf, self.POT_COLORS['lid'], (0, 0, 30, 15))
            pygame.draw.ellipse(lid_surf, self.POT_COLORS['rim_gold'], (0, 0, 30, 15), 2)

            # 회전
            rotated_lid = pygame.transform.rotate(lid_surf, lid_tilt * 30)
            screen.blit(rotated_lid, (lid_x, lid_y - 10))
        else:
            # 뚜껑이 닫힌 상태
            pygame.draw.ellipse(screen, self.POT_COLORS['lid'],
                               (cx - w//3, lid_y - 8, w*2//3, 16))
            pygame.draw.ellipse(screen, self.POT_COLORS['rim_gold'],
                               (cx - w//3, lid_y - 8, w*2//3, 16), 2)
            # 뚜껑 손잡이
            pygame.draw.circle(screen, self.POT_COLORS['rim_gold'],
                              (cx, lid_y - 12), 6)
            pygame.draw.circle(screen, self.POT_COLORS['body_mid'],
                              (cx, lid_y - 12), 4)

    def _draw_snake(self, screen: pygame.Surface):
        """뱀 그리기 - 호리병 입구에서 나옴"""
        cx = self.x
        base_y = self.y - self.vase_height // 2  # 호리병 입구
        rise_height = self.snake_max_height * self.snake_rise_progress

        # 뱀 몸통 (곡선으로 여러 세그먼트)
        segments = 12
        body_points = []

        for i in range(segments + 1):
            t = i / segments
            seg_y = base_y - rise_height * t

            # S자 곡선 + 흔들림
            wobble = math.sin(t * math.pi * 2 + self.state_timer * 6) * 8 * (1 - t)
            seg_x = cx + wobble

            body_points.append((seg_x, seg_y))

        # 몸통 그리기 (두꺼운 선)
        if len(body_points) >= 2:
            # 그라데이션 효과를 위해 여러 번 그리기
            for thickness, color in [(14, self.SNAKE_COLORS['body_dark']),
                                      (10, self.SNAKE_COLORS['body_mid']),
                                      (6, self.SNAKE_COLORS['body_light'])]:
                pygame.draw.lines(screen, color, False, body_points, thickness)

            # 붉은 무늬 (지그재그)
            for i in range(0, len(body_points) - 2, 3):
                if i + 1 < len(body_points):
                    pygame.draw.line(screen, self.SNAKE_COLORS['pattern'],
                                    body_points[i], body_points[i + 1], 3)

        # 뱀 머리
        head_x, head_y = body_points[-1]
        head_angle = self.snake_head_angle + self.snake_wobble

        # 머리 방향으로 오프셋
        head_offset = 15
        head_x += math.cos(head_angle) * head_offset
        head_y += math.sin(head_angle) * head_offset

        # 머리 (삼각형 + 타원)
        head_size = 18
        head_points = [
            (head_x + math.cos(head_angle) * head_size,
             head_y + math.sin(head_angle) * head_size),
            (head_x + math.cos(head_angle + 2.3) * head_size * 0.7,
             head_y + math.sin(head_angle + 2.3) * head_size * 0.7),
            (head_x + math.cos(head_angle - 2.3) * head_size * 0.7,
             head_y + math.sin(head_angle - 2.3) * head_size * 0.7),
        ]
        pygame.draw.polygon(screen, self.SNAKE_COLORS['body_mid'], head_points)
        pygame.draw.polygon(screen, self.SNAKE_COLORS['body_light'], head_points, 2)

        # 눈 (두 개)
        eye_offset = 6
        for side_mult in [-1, 1]:
            eye_x = head_x + math.cos(head_angle + side_mult * 0.6) * eye_offset
            eye_y = head_y + math.sin(head_angle + side_mult * 0.6) * eye_offset
            pygame.draw.circle(screen, self.SNAKE_COLORS['eye'], (int(eye_x), int(eye_y)), 4)
            pygame.draw.circle(screen, (0, 0, 0), (int(eye_x), int(eye_y)), 2)

        # 혀 (깜빡임)
        if math.sin(self.tongue_flick) > 0.3:
            tongue_length = 12 + math.sin(self.tongue_flick * 2) * 4
            tongue_tip_x = head_x + math.cos(head_angle) * (head_size + tongue_length)
            tongue_tip_y = head_y + math.sin(head_angle) * (head_size + tongue_length)
            tongue_start_x = head_x + math.cos(head_angle) * head_size
            tongue_start_y = head_y + math.sin(head_angle) * head_size

            pygame.draw.line(screen, self.SNAKE_COLORS['tongue'],
                            (int(tongue_start_x), int(tongue_start_y)),
                            (int(tongue_tip_x), int(tongue_tip_y)), 2)
            # 갈라진 혀 끝
            for angle_offset in [-0.3, 0.3]:
                fork_x = tongue_tip_x + math.cos(head_angle + angle_offset) * 5
                fork_y = tongue_tip_y + math.sin(head_angle + angle_offset) * 5
                pygame.draw.line(screen, self.SNAKE_COLORS['tongue'],
                                (int(tongue_tip_x), int(tongue_tip_y)),
                                (int(fork_x), int(fork_y)), 2)

    def is_active(self) -> bool:
        """뱀이 활동 중인지 확인"""
        return self.state != self.STATE_IDLE


class HongryeonFrame:
    """홍련 스타일 중국 전통 필러 배경 - 고퀄리티"""

    # 인게임과 일치하는 색상 팔레트 (어두운 마룬/크림슨)
    COLORS = {
        # 배경 그라데이션 (인게임 매칭)
        'bg_darkest': (25, 8, 12),            # 가장 어두운 마룬
        'bg_dark': (45, 15, 20),              # 어두운 마룬
        'bg_mid': (65, 20, 28),               # 중간 마룬
        'bg_light': (85, 28, 35),             # 밝은 마룬

        # 인게임 붉은 톤
        'crimson_dark': (120, 35, 40),        # 어두운 크림슨
        'crimson_mid': (160, 50, 55),         # 중간 크림슨
        'crimson_light': (200, 70, 70),       # 밝은 크림슨

        # 등불/발광 색상 - 붉은색 (인게임 오렌지-레드)
        'lantern_red_core': (255, 120, 60),       # 붉은 등불 중심
        'lantern_red_glow': (255, 80, 40),        # 붉은 등불 글로우
        'lantern_red_outer': (200, 50, 30),       # 붉은 등불 외곽

        # 등불/발광 색상 - 검보라색
        'lantern_purple_core': (120, 60, 160),    # 보라 등불 중심
        'lantern_purple_glow': (80, 40, 120),     # 보라 등불 글로우
        'lantern_purple_outer': (50, 25, 80),     # 보라 등불 외곽

        # 금색 장식
        'gold_bright': (255, 200, 100),       # 밝은 금
        'gold_mid': (200, 150, 60),           # 중간 금
        'gold_dark': (150, 100, 40),          # 어두운 금

        # 소용돌이/라인 (인게임 매칭)
        'line_red': (180, 60, 50),            # 붉은 라인
        'line_glow': (220, 80, 60),           # 라인 글로우

        # 육각형 패턴
        'hex_line': (80, 30, 35),             # 육각형 테두리
        'hex_fill': (55, 18, 25),             # 육각형 내부
    }

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 게임 영역 위치
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 필러 크기
        self.left_width = self.game_x
        self.right_width = screen_width - game_width - self.game_x

        # 애니메이션 상태
        self.time = 0.0
        self.excitement = 1.0

        # 등불
        self.lanterns = []
        self._init_lanterns()

        # 떠다니는 불씨
        self.embers = []
        self._init_embers()

        # === 광폭화 모드: 항아리 뱀 시스템 ===
        self.snake_pots: List[SnakePot] = []
        self._init_snake_pots()

        # 뱀 공격 쿨타임 (10~20초)
        self.snake_attack_cooldown = 0.0
        self.SNAKE_COOLDOWN_MIN = 10.0  # 최소 쿨타임 (초)
        self.SNAKE_COOLDOWN_MAX = 20.0  # 최대 쿨타임 (초)

        # 광폭화 모드 상태
        self.enraged_mode = False

        # 화염탄 발사 콜백 (pingfighter.py에서 설정)
        self.fire_callback: Optional[Callable[[int, int, int, int], None]] = None

        # 플레이어 위치 (조준용)
        self.player_x = 380
        self.player_y = 710

        # 프레임 서피스 생성
        self._static_surface = None
        self._create_static_surface()

    def _init_lanterns(self):
        """등불 초기화"""
        # 왼쪽 필러 등불
        if self.left_width > 50:
            positions = [
                (self.left_width // 2, self.game_y + 80),
                (self.left_width // 2, self.game_y + self.game_height // 2),
                (self.left_width // 2, self.game_y + self.game_height - 80),
            ]
            for x, y in positions:
                self.lanterns.append({
                    'x': x, 'y': y,
                    'size': 35,
                    'phase': random.uniform(0, math.pi * 2),
                    'pulse_speed': random.uniform(2.0, 3.0),
                })

        # 오른쪽 필러 등불
        if self.right_width > 50:
            start_x = self.game_x + self.game_width
            positions = [
                (start_x + self.right_width // 2, self.game_y + 80),
                (start_x + self.right_width // 2, self.game_y + self.game_height // 2),
                (start_x + self.right_width // 2, self.game_y + self.game_height - 80),
            ]
            for x, y in positions:
                self.lanterns.append({
                    'x': x, 'y': y,
                    'size': 35,
                    'phase': random.uniform(0, math.pi * 2),
                    'pulse_speed': random.uniform(2.0, 3.0),
                })

    def _init_embers(self):
        """떠다니는 불씨 초기화"""
        for _ in range(25):
            side = random.choice(['left', 'right'])
            if side == 'left' and self.left_width > 20:
                x = random.randint(10, self.left_width - 10)
            elif side == 'right' and self.right_width > 20:
                x = self.game_x + self.game_width + random.randint(10, self.right_width - 10)
            else:
                continue

            self.embers.append({
                'x': x,
                'y': random.randint(0, self.screen_height),
                'base_x': x,
                'size': random.uniform(2, 5),
                'speed': random.uniform(15, 40),
                'wobble_phase': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(1.5, 3.0),
                'wobble_amount': random.uniform(8, 20),
                'alpha': random.randint(150, 255),
                'side': side,
            })

    def _init_snake_pots(self):
        """뱀 초기화 - 기존 호리병(등불) 위치와 동일하게 배치 (총 6개)"""
        self.snake_pots.clear()

        # 등불과 동일한 Y 위치 사용 (_init_lanterns와 일치)
        lantern_y_positions = [
            self.game_y + 80,                           # 상단
            self.game_y + self.game_height // 2,        # 중앙
            self.game_y + self.game_height - 80,        # 하단
        ]

        # 왼쪽 필러 (3개) - 등불 위치와 동일
        if self.left_width > 50:
            pot_x = self.left_width // 2
            for i, pot_y in enumerate(lantern_y_positions):
                pot = SnakePot(pot_x, pot_y, 'left', i)
                self.snake_pots.append(pot)

        # 오른쪽 필러 (3개) - 등불 위치와 동일
        if self.right_width > 50:
            start_x = self.game_x + self.game_width
            pot_x = start_x + self.right_width // 2
            for i, pot_y in enumerate(lantern_y_positions):
                pot = SnakePot(pot_x, pot_y, 'right', i + 3)
                self.snake_pots.append(pot)

    def set_enraged_mode(self, active: bool):
        """광폭화 모드 설정"""
        print(f"[홍련 필러] set_enraged_mode 호출: {active}, 현재 상태: {self.enraged_mode}")
        if self.enraged_mode != active:
            self.enraged_mode = active
            if active:
                # 광폭화 시작 시 쿨타임 초기화 (3초 후 첫 공격)
                self.snake_attack_cooldown = 3.0
                print(f"[홍련 필러] 광폭화 모드 활성화 - 뱀 공격 시스템 가동! 뱀 개수: {len(self.snake_pots)}")
                for i, pot in enumerate(self.snake_pots):
                    print(f"  - 뱀 #{i}: 위치 ({pot.x}, {pot.y}), 상태: {pot.state}")
            else:
                # 광폭화 종료 시 모든 뱀 숨기기
                for pot in self.snake_pots:
                    if pot.state != SnakePot.STATE_IDLE:
                        pot.state = SnakePot.STATE_HIDING
                        pot.state_timer = 0.0
                print("[홍련 필러] 광폭화 모드 비활성화")

    def set_fire_callback(self, callback: Callable[[int, int, int, int], None]):
        """화염탄 발사 콜백 설정
        callback(start_x, start_y, target_x, target_y): 화염탄 발사 함수
        """
        self.fire_callback = callback
        # 모든 항아리에도 콜백 설정
        print(f"[홍련 필러] 화염탄 콜백 설정! 뱀 개수: {len(self.snake_pots)}")
        for pot in self.snake_pots:
            pot.fire_callback = callback

    def update_player_position(self, player_x: int, player_y: int):
        """플레이어 위치 업데이트 (조준용)"""
        self.player_x = player_x
        self.player_y = player_y

    def _trigger_snake_attack(self):
        """뱀 공격 트리거 - 6개 중 랜덤으로 1개 선택"""
        # 현재 활동 중이지 않은 항아리만 선택
        available_pots = [pot for pot in self.snake_pots if pot.state == SnakePot.STATE_IDLE]

        if not available_pots:
            return False

        # 랜덤 선택
        selected_pot = random.choice(available_pots)
        result = selected_pot.start_attack(self.player_x, self.player_y)

        if result:
            print(f"[홍련 필러] 뱀 공격! 항아리 #{selected_pot.index} ({selected_pot.side})")

        return result


    def _create_static_surface(self):
        """정적 배경 서피스 생성"""
        self._static_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 그라데이션 배경
        self._draw_gradient_background(self._static_surface)

        # 육각형 패턴
        self._draw_hexagon_pattern(self._static_surface)

        # 게임 영역 테두리
        self._draw_game_border(self._static_surface)

    def _draw_gradient_background(self, surface: pygame.Surface):
        """수직 그라데이션 배경 (멘헤라 스타일)"""
        colors = [
            self.COLORS['bg_darkest'],
            self.COLORS['bg_dark'],
            self.COLORS['bg_mid'],
            self.COLORS['bg_dark'],
            self.COLORS['bg_darkest'],
        ]

        num_bands = len(colors) - 1
        band_height = self.screen_height // num_bands

        for band in range(num_bands):
            start_color = colors[band]
            end_color = colors[band + 1]
            start_y = band * band_height

            for y in range(band_height):
                ratio = y / band_height
                r = int(start_color[0] + (end_color[0] - start_color[0]) * ratio)
                g = int(start_color[1] + (end_color[1] - start_color[1]) * ratio)
                b = int(start_color[2] + (end_color[2] - start_color[2]) * ratio)

                current_y = start_y + y

                # 왼쪽 필러
                if self.left_width > 0:
                    pygame.draw.line(surface, (r, g, b, 255),
                                   (0, current_y), (self.left_width, current_y))

                # 오른쪽 필러
                if self.right_width > 0:
                    start_x = self.game_x + self.game_width
                    pygame.draw.line(surface, (r, g, b, 255),
                                   (start_x, current_y), (self.screen_width, current_y))

        # 상단 필러
        if self.game_y > 0:
            for y in range(self.game_y):
                ratio = y / max(self.game_y, 1)
                color = self.COLORS['bg_darkest']
                pygame.draw.line(surface, (*color, 255),
                               (self.game_x, y), (self.game_x + self.game_width, y))

        # 하단 필러
        bottom_start = self.game_y + self.game_height
        if bottom_start < self.screen_height:
            for y in range(bottom_start, self.screen_height):
                color = self.COLORS['bg_darkest']
                pygame.draw.line(surface, (*color, 255),
                               (self.game_x, y), (self.game_x + self.game_width, y))

    def _draw_hexagon_pattern(self, surface: pygame.Surface):
        """육각형 패턴 (인게임과 매칭)"""
        hex_size = 25
        hex_color = self.COLORS['hex_line']

        # 육각형 그리기 함수
        def draw_hexagon(cx, cy, size):
            points = []
            for i in range(6):
                angle = math.pi / 6 + i * math.pi / 3
                px = cx + size * math.cos(angle)
                py = cy + size * math.sin(angle)
                points.append((px, py))
            pygame.draw.polygon(surface, (*hex_color, 40), points, 1)

        # 왼쪽 필러에 육각형 패턴
        if self.left_width > 30:
            for row in range(self.screen_height // int(hex_size * 1.5) + 2):
                for col in range(self.left_width // int(hex_size * 1.7) + 2):
                    cx = col * hex_size * 1.7 + (hex_size * 0.85 if row % 2 else 0)
                    cy = row * hex_size * 1.5
                    if cx < self.left_width:
                        draw_hexagon(cx, cy, hex_size)

        # 오른쪽 필러에 육각형 패턴
        if self.right_width > 30:
            start_x = self.game_x + self.game_width
            for row in range(self.screen_height // int(hex_size * 1.5) + 2):
                for col in range(self.right_width // int(hex_size * 1.7) + 2):
                    cx = start_x + col * hex_size * 1.7 + (hex_size * 0.85 if row % 2 else 0)
                    cy = row * hex_size * 1.5
                    if cx < self.screen_width:
                        draw_hexagon(cx, cy, hex_size)

    def _draw_game_border(self, surface: pygame.Surface):
        """게임 영역 테두리"""
        border_color = self.COLORS['crimson_dark']
        glow_color = self.COLORS['line_red']

        # 외곽 글로우 (여러 레이어)
        for i in range(4, 0, -1):
            alpha = 30 * i
            rect = pygame.Rect(
                self.game_x - i * 2, self.game_y - i * 2,
                self.game_width + i * 4, self.game_height + i * 4
            )
            pygame.draw.rect(surface, (*glow_color, alpha), rect, 2)

        # 메인 테두리
        pygame.draw.rect(surface, (*border_color, 255),
                        (self.game_x - 2, self.game_y - 2,
                         self.game_width + 4, self.game_height + 4), 3)

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt

        # 흥분도 감쇠
        self.excitement = max(1.0, self.excitement - dt * 0.5)

        # 불씨 업데이트
        for ember in self.embers:
            ember['y'] -= ember['speed'] * dt
            ember['wobble_phase'] += ember['wobble_speed'] * dt
            ember['x'] = ember['base_x'] + math.sin(ember['wobble_phase']) * ember['wobble_amount']

            # 화면 위로 나가면 다시 아래로
            if ember['y'] < -20:
                ember['y'] = self.screen_height + random.randint(10, 50)
                if ember['side'] == 'left' and self.left_width > 20:
                    ember['base_x'] = random.randint(10, self.left_width - 10)
                elif ember['side'] == 'right' and self.right_width > 20:
                    ember['base_x'] = self.game_x + self.game_width + random.randint(10, self.right_width - 10)
                ember['x'] = ember['base_x']

        # === 광폭화 모드: 항아리 뱀 업데이트 ===
        if self.enraged_mode:
            # 뱀 공격 쿨타임 처리
            if self.snake_attack_cooldown > 0:
                self.snake_attack_cooldown -= dt
                # 디버그: 쿨타임 로그 (비활성화 - 너무 자주 출력됨)
                # if int(self.snake_attack_cooldown * 10) % 30 == 0:
                #     print(f"[홍련] 뱀 쿨타임: {self.snake_attack_cooldown:.1f}s, 뱀 개수: {len(self.snake_pots)}")
            else:
                # 쿨타임 만료 시 뱀 공격 트리거
                print(f"[홍련] 뱀 공격 트리거 시도! 플레이어: ({self.player_x}, {self.player_y})")
                if self._trigger_snake_attack():
                    # 다음 쿨타임 설정 (10~20초)
                    self.snake_attack_cooldown = random.uniform(
                        self.SNAKE_COOLDOWN_MIN, self.SNAKE_COOLDOWN_MAX
                    )
                    print(f"[홍련] 뱀 공격 성공! 다음 쿨타임: {self.snake_attack_cooldown:.1f}s")
                else:
                    print(f"[홍련] 뱀 공격 실패 - 가용 항아리 없음")

        # 모든 항아리 뱀 업데이트 (광폭화 여부와 관계없이 - 숨는 애니메이션 처리)
        for pot in self.snake_pots:
            pot.update(dt)

    def draw(self, screen: pygame.Surface):
        """필러 배경 그리기"""
        # 정적 배경
        if self._static_surface:
            screen.blit(self._static_surface, (0, 0))

        # 호리병 등불
        self._draw_lanterns(screen)

        # 떠다니는 불씨
        self._draw_embers(screen)

        # === 광폭화 모드: 항아리 뱀 그리기 ===
        for pot in self.snake_pots:
            pot.draw(screen)

        # 테두리 글로우 효과 (애니메이션)
        self._draw_animated_border_glow(screen)

    def _lerp_color(self, color1: tuple, color2: tuple, t: float) -> tuple:
        """두 색상 사이를 선형 보간"""
        t = max(0.0, min(1.0, t))
        return (
            int(color1[0] + (color2[0] - color1[0]) * t),
            int(color1[1] + (color2[1] - color1[1]) * t),
            int(color1[2] + (color2[2] - color1[2]) * t),
        )

    def _draw_lanterns(self, screen: pygame.Surface):
        """호리병/매화병 스타일 등불 그리기 - 검보라색 <-> 붉은색 그라데이션 변화"""
        for lantern in self.lanterns:
            # 밝기 맥동
            pulse = math.sin(self.time * lantern['pulse_speed'] + lantern['phase'])
            intensity = 0.7 + 0.3 * pulse
            size = lantern['size']
            x, y = int(lantern['x']), int(lantern['y'])

            # 색상 변화 (천천히 보라 <-> 빨강, 각 등불마다 다른 위상)
            # 약 8초 주기로 색상 순환
            color_cycle = (math.sin(self.time * 0.4 + lantern['phase']) + 1) * 0.5

            # 현재 색상 계산 (보라 -> 빨강 보간)
            current_core = self._lerp_color(
                self.COLORS['lantern_purple_core'],
                self.COLORS['lantern_red_core'],
                color_cycle
            )
            current_glow = self._lerp_color(
                self.COLORS['lantern_purple_glow'],
                self.COLORS['lantern_red_glow'],
                color_cycle
            )
            current_outer = self._lerp_color(
                self.COLORS['lantern_purple_outer'],
                self.COLORS['lantern_red_outer'],
                color_cycle
            )

            # 금색 테두리/장식 색상
            gold_dark = self._lerp_color(
                (120, 100, 140),  # 보라색일 때 어두운 보라금
                self.COLORS['gold_dark'],
                color_cycle
            )
            gold_color = self._lerp_color(
                (180, 150, 200),  # 보라색일 때 연한 보라금
                self.COLORS['gold_mid'],
                color_cycle
            )
            gold_bright = self._lerp_color(
                (220, 200, 255),  # 보라색일 때 밝은 라벤더
                self.COLORS['gold_bright'],
                color_cycle
            )

            # === 외부 글로우 (부드러운 빛 퍼짐) ===
            for r in range(8, 0, -1):
                glow_size = size + r * 15
                alpha = int(18 * intensity * (9 - r) / 8)
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*current_glow, alpha),
                                 (glow_size, glow_size), glow_size)
                screen.blit(glow_surf, (x - glow_size, y - glow_size))

            # === 호리병 본체 (곡선형 실루엣) ===
            vase_height = int(size * 2.8)
            vase_top = y - vase_height // 2
            segments = 32  # 더 부드러운 곡선

            def get_vase_width(t):
                """호리병 곡선 계산 - 더 정교한 형태"""
                if t < 0.08:  # 입구 (좁게 시작)
                    return 0.22 + t * 2.0
                elif t < 0.15:  # 목 (살짝 넓어짐)
                    return 0.38 + (t - 0.08) * 1.2
                elif t < 0.25:  # 어깨 (급격히 넓어짐)
                    return 0.46 + (t - 0.15) * 5.0
                elif t < 0.7:  # 몸통 (가장 넓은 부분, 곡선)
                    mid_t = (t - 0.25) / 0.45
                    return 0.96 + 0.18 * math.sin(mid_t * math.pi)
                else:  # 바닥 (좁아짐)
                    return 1.14 - (t - 0.7) * 2.0

            # 호리병 외곽선
            vase_points = []
            for i in range(segments + 1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.55 * max(0.18, get_vase_width(t)))
                vase_points.append((x - half_width, seg_y))
            for i in range(segments, -1, -1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.55 * max(0.18, get_vase_width(t)))
                vase_points.append((x + half_width, seg_y))

            # 1. 외곽 그림자 (3D 효과)
            shadow_points = [(p[0] + 3, p[1] + 2) for p in vase_points]
            pygame.draw.polygon(screen, (20, 10, 15), shadow_points)

            # 2. 외곽 (가장 어두운)
            pygame.draw.polygon(screen, current_outer, vase_points)

            # 3. 중간층 (그라데이션)
            mid_points = []
            for i in range(segments + 1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.48 * max(0.15, get_vase_width(t)))
                mid_points.append((x - half_width, seg_y))
            for i in range(segments, -1, -1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.48 * max(0.15, get_vase_width(t)))
                mid_points.append((x + half_width, seg_y))
            pygame.draw.polygon(screen, current_glow, mid_points)

            # 4. 내부 발광층
            inner_points = []
            for i in range(segments + 1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.38 * max(0.12, get_vase_width(t)))
                inner_points.append((x - half_width, seg_y))
            for i in range(segments, -1, -1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.38 * max(0.12, get_vase_width(t)))
                inner_points.append((x + half_width, seg_y))

            # 발광 블렌딩
            inner_color = self._lerp_color(current_glow, current_core, 0.5)
            pygame.draw.polygon(screen, inner_color, inner_points)

            # 5. 중심 코어 발광
            core_y = y + int(size * 0.25)
            core_width = int(size * 0.28)
            core_height = int(size * 0.7)
            for i in range(3, 0, -1):
                core_surf = pygame.Surface((core_width * 2 + i * 8, core_height + i * 6), pygame.SRCALPHA)
                pygame.draw.ellipse(core_surf, (*current_core, 50 + i * 20),
                                  (0, 0, core_width * 2 + i * 8, core_height + i * 6))
                screen.blit(core_surf, (x - core_width - i * 4, core_y - core_height // 2 - i * 3))

            # === 정교한 금색 장식 ===
            # 입구 테두리 (립)
            lip_y = vase_top + int(vase_height * 0.02)
            lip_width = int(size * 0.15)
            # 립 외곽
            pygame.draw.ellipse(screen, gold_dark,
                              (x - lip_width - 4, lip_y - 4, (lip_width + 4) * 2, 8))
            # 립 내부
            pygame.draw.ellipse(screen, gold_color,
                              (x - lip_width - 2, lip_y - 2, (lip_width + 2) * 2, 5))
            # 립 하이라이트
            pygame.draw.ellipse(screen, gold_bright,
                              (x - lip_width + 2, lip_y - 1, lip_width, 2))

            # 목 장식 링 (이중)
            neck_y1 = vase_top + int(vase_height * 0.10)
            neck_y2 = vase_top + int(vase_height * 0.14)
            neck_width = int(size * 0.22)
            pygame.draw.ellipse(screen, gold_dark,
                              (x - neck_width - 2, neck_y1 - 2, (neck_width + 2) * 2, 4))
            pygame.draw.ellipse(screen, gold_color,
                              (x - neck_width, neck_y1 - 1, neck_width * 2, 3))
            pygame.draw.ellipse(screen, gold_dark,
                              (x - neck_width - 1, neck_y2 - 2, (neck_width + 1) * 2, 4))
            pygame.draw.ellipse(screen, gold_color,
                              (x - neck_width + 1, neck_y2 - 1, (neck_width - 1) * 2, 3))

            # 어깨 장식 (넓은 금테)
            shoulder_y = vase_top + int(vase_height * 0.24)
            shoulder_width = int(size * 0.52)
            # 어깨 그림자
            pygame.draw.ellipse(screen, gold_dark,
                              (x - shoulder_width - 2, shoulder_y - 3, (shoulder_width + 2) * 2, 7))
            # 어깨 메인
            pygame.draw.ellipse(screen, gold_color,
                              (x - shoulder_width, shoulder_y - 2, shoulder_width * 2, 5))
            # 어깨 하이라이트
            pygame.draw.ellipse(screen, gold_bright,
                              (x - shoulder_width + 4, shoulder_y - 1, shoulder_width - 8, 2))

            # 몸통 중앙 장식 띠
            mid_band_y = y + int(size * 0.15)
            mid_band_width = int(size * 0.58)
            pygame.draw.ellipse(screen, gold_dark,
                              (x - mid_band_width, mid_band_y - 2, mid_band_width * 2, 4))
            pygame.draw.ellipse(screen, gold_color,
                              (x - mid_band_width + 2, mid_band_y - 1, (mid_band_width - 2) * 2, 2))

            # 바닥 받침대 (다층)
            bottom_y = vase_top + vase_height - 8
            bottom_width = int(size * 0.38)
            # 받침대 베이스
            pygame.draw.ellipse(screen, gold_dark,
                              (x - bottom_width - 4, bottom_y, (bottom_width + 4) * 2, 10))
            # 받침대 상단
            pygame.draw.ellipse(screen, gold_color,
                              (x - bottom_width - 2, bottom_y + 1, (bottom_width + 2) * 2, 6))
            # 받침대 하이라이트
            pygame.draw.ellipse(screen, gold_bright,
                              (x - bottom_width + 4, bottom_y + 2, bottom_width - 4, 2))

            # === 병 표면 문양 (매화/구름) ===
            pattern_color = self._lerp_color(
                (100, 80, 130, 60),
                (180, 100, 80, 60),
                color_cycle
            )
            # 매화 문양 (단순화된 점 패턴)
            pattern_y1 = y - int(size * 0.1)
            pattern_y2 = y + int(size * 0.4)
            for py in [pattern_y1, pattern_y2]:
                for px_offset in [-8, 0, 8]:
                    pygame.draw.circle(screen, (*pattern_color[:3], 40),
                                     (x + px_offset, py), 3)

            # === 불꽃 효과 (병 입구에서 나오는 빛) ===
            flame_base_y = vase_top + 2
            flame_height = int(size * 0.6 * intensity)
            flame_wobble = math.sin(self.time * 6 + lantern['phase']) * 4
            flame_wobble2 = math.sin(self.time * 9 + lantern['phase'] + 1) * 2

            # 외부 글로우 (가장 넓은)
            for f in range(4, 0, -1):
                flame_w = 12 + f * 5
                flame_h = flame_height + f * 10
                flame_surf = pygame.Surface((flame_w * 2, flame_h), pygame.SRCALPHA)
                # 불꽃 형태 (여러 삼각형 합성)
                main_points = [
                    (flame_w + flame_wobble, 0),
                    (flame_w - flame_w * 0.7, flame_h),
                    (flame_w + flame_w * 0.7, flame_h),
                ]
                pygame.draw.polygon(flame_surf, (*current_glow, 40 // f), main_points)
                screen.blit(flame_surf, (x - flame_w, flame_base_y - flame_h))

            # 메인 불꽃 (3층)
            # 외부 불꽃
            outer_flame = [
                (x + flame_wobble, flame_base_y - flame_height),
                (x - 10, flame_base_y),
                (x + 10, flame_base_y),
            ]
            pygame.draw.polygon(screen, current_glow, outer_flame)

            # 중간 불꽃
            mid_flame = [
                (x + flame_wobble * 0.7, flame_base_y - flame_height * 0.85),
                (x - 7, flame_base_y),
                (x + 7, flame_base_y),
            ]
            pygame.draw.polygon(screen, current_core, mid_flame)

            # 내부 불꽃 (가장 밝은)
            inner_flame = [
                (x + flame_wobble2, flame_base_y - flame_height * 0.6),
                (x - 4, flame_base_y),
                (x + 4, flame_base_y),
            ]
            pygame.draw.polygon(screen, gold_bright, inner_flame)

            # 불꽃 스파크 (작은 불씨들)
            for i in range(3):
                spark_x = x + flame_wobble + random.randint(-6, 6)
                spark_y = flame_base_y - flame_height * 0.3 - i * 8
                spark_size = 2 - i * 0.5
                if spark_size > 0:
                    pygame.draw.circle(screen, gold_bright, (int(spark_x), int(spark_y)), int(spark_size))

            # === 하이라이트 (3D 입체감) ===
            # 왼쪽 반사광 (세로 하이라이트)
            highlight_x = x - int(size * 0.3)
            highlight_y = y - int(size * 0.2)
            highlight_surf = pygame.Surface((8, int(size * 1.2)), pygame.SRCALPHA)
            for i in range(8):
                alpha = 60 - i * 8
                if alpha > 0:
                    pygame.draw.line(highlight_surf, (*gold_bright, alpha),
                                   (i, 0), (i, int(size * 1.2)))
            screen.blit(highlight_surf, (highlight_x, highlight_y))

            # 오른쪽 림라이트 (미세한)
            rim_x = x + int(size * 0.25)
            rim_surf = pygame.Surface((4, int(size * 0.8)), pygame.SRCALPHA)
            for i in range(4):
                alpha = 30 - i * 8
                if alpha > 0:
                    pygame.draw.line(rim_surf, (*gold_bright, alpha),
                                   (3 - i, 0), (3 - i, int(size * 0.8)))
            screen.blit(rim_surf, (rim_x, y))

    def _draw_embers(self, screen: pygame.Surface):
        """떠다니는 불씨 그리기 - 등불과 동기화된 색상 변화"""
        for ember in self.embers:
            x, y = int(ember['x']), int(ember['y'])
            size = ember['size']

            # 색상 변화 (등불과 비슷하게, 위치에 따른 위상 차이)
            color_cycle = (math.sin(self.time * 0.4 + ember['wobble_phase'] * 0.5) + 1) * 0.5

            # 현재 색상 계산
            current_glow = self._lerp_color(
                self.COLORS['lantern_purple_glow'],
                self.COLORS['lantern_red_glow'],
                color_cycle
            )
            current_core = self._lerp_color(
                self.COLORS['lantern_purple_core'],
                self.COLORS['lantern_red_core'],
                color_cycle
            )

            # 불씨 (다이아몬드 모양, 인게임 스타일)
            points = [
                (x, y - size * 1.5),  # 위
                (x + size * 0.6, y),   # 오른쪽
                (x, y + size * 0.8),   # 아래
                (x - size * 0.6, y),   # 왼쪽
            ]

            # 글로우
            glow_surf = pygame.Surface((int(size * 4), int(size * 4)), pygame.SRCALPHA)
            glow_center = (int(size * 2), int(size * 2))
            pygame.draw.circle(glow_surf, (*current_glow, 40),
                             glow_center, int(size * 1.5))
            screen.blit(glow_surf, (x - size * 2, y - size * 2))

            # 본체
            pygame.draw.polygon(screen, current_core, points)

    def _draw_animated_border_glow(self, screen: pygame.Surface):
        """애니메이션 테두리 글로우"""
        pulse = (math.sin(self.time * 2) + 1) * 0.5
        intensity = 0.3 + pulse * 0.4 * self.excitement

        glow_width = int(6 * intensity)
        if glow_width > 0:
            alpha = int(50 * intensity)
            color = (*self.COLORS['line_glow'], alpha)

            # 좌측 글로우
            glow_surf = pygame.Surface((glow_width, self.game_height), pygame.SRCALPHA)
            glow_surf.fill(color)
            screen.blit(glow_surf, (self.game_x - glow_width, self.game_y))

            # 우측 글로우
            screen.blit(glow_surf, (self.game_x + self.game_width, self.game_y))

    def trigger_excitement(self, level: float = 1.5):
        """흥분도 트리거"""
        self.excitement = min(3.0, self.excitement + level)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.__init__(screen_width, screen_height, game_width, game_height)


# 전역 인스턴스
_hongryeon_bg = None


def init_hongryeon_background(screen_width: int, screen_height: int,
                              game_width: int, game_height: int) -> HongryeonFrame:
    """홍련 배경 초기화"""
    global _hongryeon_bg
    _hongryeon_bg = HongryeonFrame(screen_width, screen_height, game_width, game_height)
    return _hongryeon_bg


def get_hongryeon_background() -> HongryeonFrame:
    """홍련 배경 인스턴스 반환"""
    return _hongryeon_bg


def set_hongryeon_enraged(active: bool):
    """홍련 필러 광폭화 모드 설정 (전역 함수)"""
    if _hongryeon_bg is not None:
        _hongryeon_bg.set_enraged_mode(active)


def set_hongryeon_fire_callback(callback: Callable[[int, int, int, int], None]):
    """홍련 필러 화염탄 발사 콜백 설정 (전역 함수)
    callback(start_x, start_y, target_x, target_y): 화염탄 발사 함수
    """
    if _hongryeon_bg is not None:
        _hongryeon_bg.set_fire_callback(callback)


def update_hongryeon_player_position(player_x: int, player_y: int):
    """홍련 필러 플레이어 위치 업데이트 (전역 함수)"""
    if _hongryeon_bg is not None:
        _hongryeon_bg.update_player_position(player_x, player_y)
