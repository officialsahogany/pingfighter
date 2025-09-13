# -*- coding: utf-8 -*-
"""
Stage 3: 멘헤라 월드 테마 맵
Stage 2의 테두리 구조를 유지하면서 멘헤라 컨셉으로 변경
파스텔 톤과 의료/감정 테마를 조합한 귀여운 다크니스
"""

import pygame
import math
import random
from typing import Tuple, List

# 화면 크기
WIDTH = 600
HEIGHT = 750

# 색상 정의 - 멘헤라 파스텔 색상 팔레트
PASTEL_PINK = (255, 182, 193)      # 파스텔 핑크
LAVENDER = (230, 190, 255)          # 라벤더
DEEP_PURPLE = (139, 0, 139)         # 진한 보라
MINT = (189, 252, 201)              # 민트 (병원 느낌)
WHITE = (255, 255, 255)             # 흰색
SOFT_BLACK = (60, 60, 60)           # 부드러운 검은색
CRIMSON = (220, 20, 60)             # 크림슨 (액센트)
BABY_BLUE = (137, 207, 240)         # 베이비 블루
SOFT_YELLOW = (255, 255, 200)      # 부드러운 노란색
MINT_GREEN = (152, 255, 152)       # 민트 그린

class Stage3MenheraWorld:
    def __init__(self):
        self.time = 0
        self.heart_particles = []
        self.star_particles = []
        self.emotional_phase = 0  # 감정 페이즈 (0: 평온, 1: 행복, 2: 슬픔)
        self.emotional_timer = 0
        self.pulse_value = 0
        self.round_count = 0  # 라운드 카운터 추가
        self.tail_whip_active = False  # 꼬리 채찍 상태
        self.tail_whip_progress = 0.0  # 꼬리 채찍 애니메이션 진행도
        self.tail_points = []  # 꼬리 포인트 저장
        self.tail_whip_target = None  # 채찍 타겟 위치 (공의 위치)
        self.tail_whip_hit = False  # 채찍이 공을 맞췄는지 여부
        
        # 공 먹기 이벤트 관련 변수
        self.eating_active = False
        self.eating_timer = 0
        self.mouth_open = 0  # 입 열림 정도 (0~1)
        self.chewing_phase = 0
        self.chewing_particles = []
        self.spit_angle = None  # 뱉을 방향 미리 결정
        self.mouth_direction = 0  # 입 방향 (라디안)
        
        self.init_decorations()
        
    def init_decorations(self):
        """하트와 별 파티클 초기화"""
        # 초기 하트 생성
        for _ in range(5):
            self.heart_particles.append({
                'x': random.randint(50, WIDTH - 50),
                'y': random.randint(100, HEIGHT - 100),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-1, -0.5),
                'size': random.randint(10, 20),
                'broken': random.random() < 0.3,  # 30% 확률로 깨진 하트
                'color': random.choice([PASTEL_PINK, LAVENDER, CRIMSON]),
                'life': random.randint(200, 400)
            })
    
    def update(self, dt, round_count=None):
        """애니메이션 업데이트"""
        self.time += dt
        self.pulse_value = abs(math.sin(self.time * 0.003)) * 0.5 + 0.5
        
        # 라운드가 변경되면 감정 페이즈 변화
        if round_count is not None and round_count != self.round_count:
            self.round_count = round_count
            self.emotional_phase = (self.emotional_phase + 1) % 3
            self.emotional_timer = 0
        
        # 하트 파티클 생성 (더 적게)
        if random.random() < 0.01:  # 빈도 감소
            self.heart_particles.append({
                'x': random.randint(100, WIDTH - 100),
                'y': HEIGHT + 20,
                'vx': random.uniform(-0.3, 0.3),
                'vy': random.uniform(-1.5, -0.8),
                'size': random.randint(8, 15),
                'broken': self.emotional_phase == 2,  # 슬픈 페이즈에서는 깨진 하트
                'color': self.get_emotional_color(),
                'life': 400
            })
        
        # 별 파티클 생성 (더 적게)
        if random.random() < 0.015:  # 빈도 감소
            self.star_particles.append({
                'x': random.randint(50, WIDTH - 50),
                'y': random.randint(50, HEIGHT - 50),
                'size': random.randint(2, 4),
                'twinkle': random.random() * math.pi,
                'speed': random.uniform(0.03, 0.08),
                'life': 100
            })
        
        # 하트 파티클 업데이트
        self.heart_particles = [
            {**p, 
             'y': p['y'] + p['vy'], 
             'x': p['x'] + p['vx'] + math.sin(self.time * 0.005 + p['y'] * 0.01) * 0.5,
             'life': p['life'] - 1}
            for p in self.heart_particles if p['life'] > 0 and p['y'] > -50
        ]
        
        # 별 파티클 업데이트
        self.star_particles = [
            {**p, 
             'twinkle': p['twinkle'] + p['speed'],
             'life': p['life'] - 1}
            for p in self.star_particles if p['life'] > 0
        ]
    
    def get_emotional_color(self):
        """감정 페이즈에 따른 색상 반환"""
        if self.emotional_phase == 0:  # 평온
            return LAVENDER
        elif self.emotional_phase == 1:  # 행복
            return PASTEL_PINK
        else:  # 슬픔
            return BABY_BLUE
    
    def activate_tail_whip(self, ball_pos=None):
        """꼬리 채찍 발동"""
        self.tail_whip_active = True
        self.tail_whip_progress = 0.0
        self.tail_whip_target = ball_pos  # 공의 현재 위치 저장
        self.tail_whip_hit = False
        
    def deactivate_tail_whip(self):
        """꼬리 채찍 종료"""
        self.tail_whip_active = False
        self.tail_whip_progress = 0.0
        self.tail_whip_target = None
        self.tail_whip_hit = False
    
    def update_tail_whip(self, progress, ball_pos=None):
        """꼬리 채찍 애니메이션 진행도 업데이트"""
        self.tail_whip_progress = progress
        # 타겟 위치 업데이트 (공 추적)
        if ball_pos and progress < 0.5:  # 전반부에만 추적
            self.tail_whip_target = ball_pos
    
    def check_tail_collision(self, ball_rect):
        """꼬리와 공의 충돌 체크"""
        if not self.tail_whip_active:
            return False
            
        if not self.tail_points:
            print(f" [TAIL] tail_points ! tail_whip_active={self.tail_whip_active}")
            return False
        
        # 디버깅: 매 프레임마다 상태 출력
        print(f" [TAIL CHECK] Progress: {self.tail_whip_progress:.2f}, tail_points : {len(self.tail_points)},  : ({ball_rect.centerx}, {ball_rect.centery})")
        
        # 꼬리 채찍이 활성화 중일 때 충돌 체크 (범위 확대: 0.2~0.8)
        if 0.2 <= self.tail_whip_progress <= 0.8:
            # 꼬리 전체 부분과 공의 충돌 체크 (더 많은 포인트 체크)
            check_range = 10  # 체크할 포인트 범위 확대
            mid_idx = len(self.tail_points) // 2
            
            # 가장 가까운 꼬리 포인트 찾기
            min_distance = float('inf')
            closest_point = None
            
            for i in range(max(0, mid_idx - check_range), min(len(self.tail_points), mid_idx + check_range + 1)):
                if i < len(self.tail_points):
                    tail_x, tail_y = self.tail_points[i]
                    # 꼬리 포인트와 공의 거리 체크
                    distance = math.sqrt((tail_x - ball_rect.centerx) ** 2 + 
                                       (tail_y - ball_rect.centery) ** 2)
                    if distance < min_distance:
                        min_distance = distance
                        closest_point = (tail_x, tail_y, i)
            
            # 디버깅: 가장 가까운 포인트 정보 출력
            if closest_point:
                print(f" [CLOSEST]    : idx={closest_point[2]}, pos=({closest_point[0]:.0f}, {closest_point[1]:.0f}), : {min_distance:.1f}px")
            
            # 충돌 판정 (반경 80으로 더 확대)
            if min_distance < 80:
                print(f" [TAIL HIT!!!]   ! : {min_distance:.1f}px < 80px")
                return True
        else:
            print(f"⏰ [TAIL] Progress {self.tail_whip_progress:.2f}   (0.2~0.8)")
        
        return False
    
    def draw_border(self, screen):
        """Stage 2와 동일한 두께의 멘헤라 테두리"""
        border_thickness = 10  # Stage 2와 동일
        
        # 기본 테두리 - 파스텔 핑크
        base_color = self.get_emotional_color()
        pygame.draw.rect(screen, base_color, (0, 0, WIDTH, border_thickness))
        pygame.draw.rect(screen, base_color, (0, HEIGHT - border_thickness, WIDTH, border_thickness))
        pygame.draw.rect(screen, base_color, (0, 0, border_thickness, HEIGHT))
        pygame.draw.rect(screen, base_color, (WIDTH - border_thickness, 0, border_thickness, HEIGHT))
        
        # 내부 흰색 레이스 테두리
        inner_thickness = 2
        pygame.draw.rect(screen, WHITE, 
                        (border_thickness - inner_thickness, border_thickness - inner_thickness,
                         WIDTH - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(screen, WHITE,
                        (border_thickness - inner_thickness, HEIGHT - border_thickness,
                         WIDTH - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(screen, WHITE,
                        (border_thickness - inner_thickness, border_thickness - inner_thickness,
                         inner_thickness, HEIGHT - 2*(border_thickness - inner_thickness)))
        pygame.draw.rect(screen, WHITE,
                        (WIDTH - border_thickness, border_thickness - inner_thickness,
                         inner_thickness, HEIGHT - 2*(border_thickness - inner_thickness)))
        
        # 하트와 별 패턴 장식
        pattern_size = 15
        for i in range(0, WIDTH, pattern_size * 2):
            # 상단 장식
            if i % (pattern_size * 4) == 0:
                self.draw_mini_heart(screen, i + pattern_size//2, border_thickness//2, 4, WHITE)
            else:
                self.draw_mini_star(screen, i + pattern_size//2, border_thickness//2, 3, WHITE)
            
            # 하단 장식
            if i % (pattern_size * 4) == 0:
                self.draw_mini_heart(screen, i + pattern_size//2, HEIGHT - border_thickness//2, 4, WHITE)
            else:
                self.draw_mini_star(screen, i + pattern_size//2, HEIGHT - border_thickness//2, 3, WHITE)
        
        for i in range(0, HEIGHT, pattern_size * 2):
            # 좌측 장식
            if i % (pattern_size * 4) == 0:
                self.draw_mini_heart(screen, border_thickness//2, i + pattern_size//2, 4, WHITE)
            else:
                self.draw_mini_star(screen, border_thickness//2, i + pattern_size//2, 3, WHITE)
            
            # 우측 장식
            if i % (pattern_size * 4) == 0:
                self.draw_mini_heart(screen, WIDTH - border_thickness//2, i + pattern_size//2, 4, WHITE)
            else:
                self.draw_mini_star(screen, WIDTH - border_thickness//2, i + pattern_size//2, 3, WHITE)
        
        # 코너 장식 (붕대 리본)
        corner_size = 8
        # 좌상단
        self.draw_bandage_ribbon(screen, border_thickness//2, border_thickness//2, corner_size, PASTEL_PINK)
        # 우상단
        self.draw_bandage_ribbon(screen, WIDTH - border_thickness//2, border_thickness//2, corner_size, PASTEL_PINK)
        # 좌하단
        self.draw_bandage_ribbon(screen, border_thickness//2, HEIGHT - border_thickness//2, corner_size, PASTEL_PINK)
        # 우하단
        self.draw_bandage_ribbon(screen, WIDTH - border_thickness//2, HEIGHT - border_thickness//2, corner_size, PASTEL_PINK)
    
    def draw_mini_heart(self, screen, x, y, size, color):
        """작은 하트 그리기"""
        # 간단한 하트 모양
        pygame.draw.circle(screen, color, (x - size//2, y - size//2), size//2)
        pygame.draw.circle(screen, color, (x + size//2, y - size//2), size//2)
        points = [
            (x - size, y),
            (x, y + size),
            (x + size, y)
        ]
        pygame.draw.polygon(screen, color, points)
    
    def draw_mini_star(self, screen, x, y, size, color):
        """작은 별 그리기"""
        # 5각 별
        points = []
        for i in range(10):
            angle = math.pi * i / 5 - math.pi / 2
            if i % 2 == 0:
                radius = size
            else:
                radius = size // 2
            px = x + radius * math.cos(angle)
            py = y + radius * math.sin(angle)
            points.append((px, py))
        pygame.draw.polygon(screen, color, points)
    
    def draw_bandage_ribbon(self, screen, x, y, size, color):
        """붕대 리본 장식"""
        # X자 모양
        pygame.draw.line(screen, color, (x - size, y - size), (x + size, y + size), 2)
        pygame.draw.line(screen, color, (x - size, y + size), (x + size, y - size), 2)
        # 중앙 원
        pygame.draw.circle(screen, WHITE, (x, y), size//2)
    
    def draw_stadium_line(self, screen, ball_pos=None):
        """중앙 스타디움 라인 - Stage 2와 동일한 구조"""
        center_y = HEIGHT // 2
        center_x = WIDTH // 2
        
        # 중앙 원 (Stage 2와 동일한 크기 - 반지름 120)
        # 외부 큰 원
        pygame.draw.circle(screen, WHITE, (center_x, center_y), 120, 3)
        # 중간 원 (감정 색상)
        pygame.draw.circle(screen, self.get_emotional_color(), (center_x, center_y), 115, 2)
        # 내부 원 (은은한 색상)
        pygame.draw.circle(screen, (*LAVENDER, 100), (center_x, center_y), 110, 1)
        
        # 메인 중앙선 (점선) - 원 밖에서만 그리기
        dash_length = 20
        gap_length = 15
        line_color = self.get_emotional_color()
        
        # 왼쪽 선 (원 밖)
        for x in range(0, center_x - 120, dash_length + gap_length):
            end_x = min(x + dash_length, center_x - 120)
            pygame.draw.line(screen, line_color, (x, center_y), (end_x, center_y), 3)
        
        # 오른쪽 선 (원 밖)
        for x in range(center_x + 120, WIDTH, dash_length + gap_length):
            end_x = min(x + dash_length, WIDTH)
            pygame.draw.line(screen, line_color, (x, center_y), (end_x, center_y), 3)
        
        # 중앙에 쿠로미 그리기 (공 위치 전달)
        self.draw_kuromi(screen, center_x, center_y, 60, ball_pos)
        
    
    def draw_kuromi(self, screen, x, y, size, ball_pos=None):
        """울트라 카와이 쿠로미 - 산리오 x 포켓몬 스타일 (일본 만화 디테일)"""
        # 크기 조정 (더 둥글고 귀여운 비율)
        head_size = int(size * 0.6)  # 더 큰 머리 (치비 스타일)
        
        # 씹기 애니메이션에 따른 얼굴 변형 계산
        face_distortion_x = 0
        face_distortion_y = 0
        cheek_bulge_left = 0
        cheek_bulge_right = 0
        
        if self.eating_active and self.chewing_phase > 0:
            # 씹기 동작에 따른 얼굴 변형
            chew_cycle = math.sin(self.chewing_phase * math.pi * 8)
            
            # 턱 움직임 (위아래)
            face_distortion_y = int(abs(chew_cycle) * 8)
            
            # 좌우 볼 움직임 (번갈아가며)
            if int(self.chewing_phase * 8) % 2 == 0:
                cheek_bulge_left = abs(chew_cycle) * 15
                cheek_bulge_right = -abs(chew_cycle) * 5
            else:
                cheek_bulge_left = -abs(chew_cycle) * 5
                cheek_bulge_right = abs(chew_cycle) * 15
            
            # 좌우 흔들림
            face_distortion_x = int(math.sin(self.chewing_phase * math.pi * 4) * 3)
        
        # 🌸 부드러운 그림자 효과 (깊이감)
        shadow_surface = pygame.Surface((head_size * 3, head_size * 3), pygame.SRCALPHA)
        shadow_center = head_size * 1.5
        for i in range(10, 0, -1):
            alpha = 3 * i
            radius = head_size + i * 2
            pygame.draw.circle(shadow_surface, (*LAVENDER, alpha), 
                             (shadow_center, shadow_center), radius)
        screen.blit(shadow_surface, (x - shadow_center + face_distortion_x, y - shadow_center + 10))
        
        # 얼굴 (씹을 때 변형)
        face_rect = pygame.Rect(x - head_size + face_distortion_x, 
                               y - head_size + 8, 
                               head_size * 2, 
                               int(head_size * 1.9 + face_distortion_y))
        
        # 얼굴 그라데이션 효과
        for i in range(5):
            color = (255 - i*2, 250 - i*2, 255 - i*3)
            inner_rect = pygame.Rect(x - head_size + i*2, y - head_size + 8 + i*2, 
                                    head_size * 2 - i*4, int(head_size * 1.9 - i*4))
            pygame.draw.ellipse(screen, color, inner_rect)
        
        # 얼굴 테두리 (부드러운 파스텔 핑크)
        pygame.draw.ellipse(screen, (*PASTEL_PINK, 200), face_rect, 3)
        pygame.draw.ellipse(screen, SOFT_BLACK, face_rect, 1)
        
        # 씹을 때 볼 부풀리기 효과
        if self.eating_active and self.chewing_phase > 0:
            # 왼쪽 볼
            if cheek_bulge_left > 0:
                cheek_x = x - head_size * 0.7
                cheek_y = y + head_size * 0.2
                bulge_size = int(head_size * 0.4 + cheek_bulge_left)
                
                # 볼 그라데이션
                for i in range(3):
                    bulge_alpha = 100 - i * 30
                    bulge_color = (*PASTEL_PINK, bulge_alpha)
                    pygame.draw.ellipse(screen, bulge_color,
                                      (cheek_x - bulge_size//2 - i*2, 
                                       cheek_y - bulge_size//2 - i*2,
                                       bulge_size + i*4, bulge_size + i*4))
                
                # 볼 메인
                pygame.draw.ellipse(screen, (255, 230, 240),
                                  (cheek_x - bulge_size//2, cheek_y - bulge_size//2,
                                   bulge_size, bulge_size))
                
                # 볼 하이라이트
                pygame.draw.ellipse(screen, (*WHITE, 180),
                                  (cheek_x - bulge_size//4, cheek_y - bulge_size//3,
                                   bulge_size//3, bulge_size//3))
            
            # 오른쪽 볼
            if cheek_bulge_right > 0:
                cheek_x = x + head_size * 0.7
                cheek_y = y + head_size * 0.2
                bulge_size = int(head_size * 0.4 + cheek_bulge_right)
                
                # 볼 그라데이션
                for i in range(3):
                    bulge_alpha = 100 - i * 30
                    bulge_color = (*PASTEL_PINK, bulge_alpha)
                    pygame.draw.ellipse(screen, bulge_color,
                                      (cheek_x - bulge_size//2 - i*2, 
                                       cheek_y - bulge_size//2 - i*2,
                                       bulge_size + i*4, bulge_size + i*4))
                
                # 볼 메인
                pygame.draw.ellipse(screen, (255, 230, 240),
                                  (cheek_x - bulge_size//2, cheek_y - bulge_size//2,
                                   bulge_size, bulge_size))
                
                # 볼 하이라이트
                pygame.draw.ellipse(screen, (*WHITE, 180),
                                  (cheek_x - bulge_size//4, cheek_y - bulge_size//3,
                                   bulge_size//3, bulge_size//3))
        
        # 🐰 울트라 카와이 토끼 귀 (더 둥글고 부드럽게)
        ear_height = int(head_size * 1.4)
        ear_width = int(head_size * 0.5)
        
        # 귀 움직임 애니메이션 (미세한 흔들림)
        ear_wiggle = math.sin(self.time * 0.008) * 2
        
        # 왼쪽 귀 (곡선으로 더 부드럽게)
        left_ear_base_x = x - head_size//2
        left_ear_base_y = y - head_size//2 + 5
        left_ear_tip_x = x - head_size//2 - ear_width//2 + ear_wiggle
        left_ear_tip_y = y - head_size - ear_height
        
        # 귀 그라데이션 (여러 층으로)
        for i in range(5):
            scale = 1 - i * 0.15
            color = (255 - i*10, 250 - i*10, 255 - i*15)
            left_ear_points = [
                (left_ear_base_x, left_ear_base_y),
                (left_ear_tip_x * scale + x * (1-scale), left_ear_tip_y * scale + y * (1-scale)),
                (x - head_size//4, left_ear_base_y)
            ]
            pygame.draw.polygon(screen, color, left_ear_points)
        
        # 귀 테두리
        left_ear_outline = [
            (left_ear_base_x, left_ear_base_y),
            (left_ear_tip_x, left_ear_tip_y),
            (x - head_size//4, left_ear_base_y)
        ]
        pygame.draw.polygon(screen, (*LAVENDER, 150), left_ear_outline, 2)
        
        # 오른쪽 귀
        right_ear_base_x = x + head_size//2
        right_ear_base_y = y - head_size//2 + 5
        right_ear_tip_x = x + head_size//2 + ear_width//2 - ear_wiggle
        right_ear_tip_y = y - head_size - ear_height
        
        for i in range(5):
            scale = 1 - i * 0.15
            color = (255 - i*10, 250 - i*10, 255 - i*15)
            right_ear_points = [
                (right_ear_base_x, right_ear_base_y),
                (right_ear_tip_x * scale + x * (1-scale), right_ear_tip_y * scale + y * (1-scale)),
                (x + head_size//4, right_ear_base_y)
            ]
            pygame.draw.polygon(screen, color, right_ear_points)
        
        # 귀 테두리
        right_ear_outline = [
            (right_ear_base_x, right_ear_base_y),
            (right_ear_tip_x, right_ear_tip_y),
            (x + head_size//4, right_ear_base_y)
        ]
        pygame.draw.polygon(screen, (*LAVENDER, 150), right_ear_outline, 2)
        
        # 🌸 귀 내부 디테일 (키라키라 효과)
        left_inner_ear = [
            (left_ear_base_x + 4, left_ear_base_y),
            (left_ear_tip_x + 8, left_ear_tip_y + 15),
            (x - head_size//3, left_ear_base_y)
        ]
        pygame.draw.polygon(screen, (*PASTEL_PINK, 180), left_inner_ear)
        
        # 귀 내부 하이라이트
        pygame.draw.circle(screen, (*WHITE, 150), 
                         (left_ear_tip_x + 10, left_ear_tip_y + 20), 3)
        
        right_inner_ear = [
            (right_ear_base_x - 4, right_ear_base_y),
            (right_ear_tip_x - 8, right_ear_tip_y + 15),
            (x + head_size//3, right_ear_base_y)
        ]
        pygame.draw.polygon(screen, (*PASTEL_PINK, 180), right_inner_ear)
        
        # 귀 내부 하이라이트
        pygame.draw.circle(screen, (*WHITE, 150),
                         (right_ear_tip_x - 10, right_ear_tip_y + 20), 3)
        
        # 💀 울트라 카와이 해골 장식 (쿠로미 시그니처)
        skull_y = y - head_size - ear_height//2 + 5
        skull_size = int(ear_width * 0.7)
        
        # 해골 광택 효과
        for i in range(3):
            pygame.draw.circle(screen, (*PASTEL_PINK, 100 - i*20), 
                             (x, skull_y), skull_size + 3 - i)
        
        # 해골 베이스 (그라데이션)
        pygame.draw.circle(screen, PASTEL_PINK, (x, skull_y), skull_size)
        pygame.draw.circle(screen, (255, 220, 230), (x, skull_y), skull_size - 2)
        pygame.draw.circle(screen, WHITE, (x, skull_y), skull_size - 4)
        
        # 해골 눈구멍 (하트 모양으로 귀엽게)
        heart_eye_size = 3
        # 왼쪽 하트 눈
        pygame.draw.circle(screen, SOFT_BLACK, (x - skull_size//3 - 1, skull_y - 2), 2)
        pygame.draw.circle(screen, SOFT_BLACK, (x - skull_size//3 + 1, skull_y - 2), 2)
        pygame.draw.polygon(screen, SOFT_BLACK, [
            (x - skull_size//3 - 2, skull_y),
            (x - skull_size//3, skull_y + 2),
            (x - skull_size//3 + 2, skull_y)
        ])
        
        # 오른쪽 하트 눈
        pygame.draw.circle(screen, SOFT_BLACK, (x + skull_size//3 - 1, skull_y - 2), 2)
        pygame.draw.circle(screen, SOFT_BLACK, (x + skull_size//3 + 1, skull_y - 2), 2)
        pygame.draw.polygon(screen, SOFT_BLACK, [
            (x + skull_size//3 - 2, skull_y),
            (x + skull_size//3, skull_y + 2),
            (x + skull_size//3 + 2, skull_y)
        ])
        
        # 해골 코 (작은 하트)
        pygame.draw.circle(screen, (*PASTEL_PINK, 150), (x - 1, skull_y + 4), 1)
        pygame.draw.circle(screen, (*PASTEL_PINK, 150), (x + 1, skull_y + 4), 1)
        pygame.draw.polygon(screen, (*PASTEL_PINK, 150), [
            (x - 2, skull_y + 5),
            (x, skull_y + 7),
            (x + 2, skull_y + 5)
        ])
        
        # 리본 장식 (해골 양옆)
        ribbon_color = (255, 150, 200)
        pygame.draw.ellipse(screen, ribbon_color, 
                          (x - skull_size - 5, skull_y - 3, 6, 8))
        pygame.draw.ellipse(screen, ribbon_color,
                          (x + skull_size - 1, skull_y - 3, 6, 8))
        
        # ✨ 울트라 빅 아이즈 (일본 만화 스타일 - 초대형)
        eye_y = y - head_size//10
        eye_spacing = head_size//2.2
        eye_width = int(head_size * 0.55)  # 훨씬 더 큰 눈
        eye_height = int(head_size * 0.65)  # 세로로 더 길게
        
        # 감정에 따른 눈 표정 변화
        emotion_offset = 0
        if self.emotional_phase == 1:  # 행복
            emotion_offset = -2
        elif self.emotional_phase == 2:  # 슬픔
            emotion_offset = 3
        
        # 👁️ 왼쪽 눈 (초대형 만화 스타일)
        left_eye_x = x - eye_spacing
        left_eye_y = eye_y + emotion_offset
        
        # 눈 외곽 그림자 (깊이감)
        for i in range(3):
            shadow_rect = pygame.Rect(left_eye_x - eye_width//2 - i, 
                                     left_eye_y - eye_height//2 - i,
                                     eye_width + i*2, eye_height + i*2)
            pygame.draw.ellipse(screen, (*LAVENDER, 30 - i*8), shadow_rect)
        
        # 눈 흰자위
        left_eye_rect = pygame.Rect(left_eye_x - eye_width//2, left_eye_y - eye_height//2,
                                    eye_width, eye_height)
        pygame.draw.ellipse(screen, (255, 252, 255), left_eye_rect)
        pygame.draw.ellipse(screen, SOFT_BLACK, left_eye_rect, 2)
        
        # 홍채 (그라데이션 효과)
        iris_width = int(eye_width * 0.7)
        iris_height = int(eye_height * 0.75)
        iris_x = left_eye_x - iris_width//2
        iris_y = left_eye_y - iris_height//2 + 2
        
        # 홍채 그라데이션 (여러 층)
        iris_colors = [
            (220, 180, 255),  # 밝은 보라
            (200, 160, 240),
            (180, 140, 220),
            (160, 120, 200),
            (140, 100, 180),  # 진한 보라
        ]
        
        for i, color in enumerate(iris_colors):
            iris_rect = pygame.Rect(iris_x + i*2, iris_y + i*2,
                                   iris_width - i*4, iris_height - i*4)
            pygame.draw.ellipse(screen, color, iris_rect)
        
        # 동공 (반짝이는 효과)
        pupil_size = int(iris_width * 0.35)
        pupil_pulse = abs(math.sin(self.time * 0.005)) * 2
        pygame.draw.ellipse(screen, SOFT_BLACK,
                          (left_eye_x - pupil_size//2, left_eye_y - pupil_size//2 + 2,
                           pupil_size + pupil_pulse, pupil_size + pupil_pulse))
        
        # ✨ 초대형 하이라이트 (여러 개)
        # 메인 하이라이트
        pygame.draw.ellipse(screen, WHITE,
                          (left_eye_x - eye_width//4, left_eye_y - eye_height//3,
                           eye_width//3, eye_height//4))
        pygame.draw.ellipse(screen, (255, 240, 250),
                          (left_eye_x - eye_width//4 + 2, left_eye_y - eye_height//3 + 2,
                           eye_width//4, eye_height//5))
        
        # 서브 하이라이트들
        pygame.draw.circle(screen, WHITE, (left_eye_x + eye_width//5, left_eye_y - eye_height//4), 4)
        pygame.draw.circle(screen, (255, 230, 240), (left_eye_x - eye_width//6, left_eye_y + eye_height//6), 3)
        pygame.draw.circle(screen, WHITE, (left_eye_x + eye_width//8, left_eye_y + eye_height//5), 2)
        
        # 별 모양 반짝임
        star_twinkle = abs(math.sin(self.time * 0.01)) * 255
        if star_twinkle > 200:
            self.draw_mini_star(screen, left_eye_x - eye_width//3, left_eye_y - eye_height//4, 
                              2, (*WHITE, int(star_twinkle)))
        
        # 👁️ 오른쪽 눈 (동일한 스타일)
        right_eye_x = x + eye_spacing
        right_eye_y = eye_y + emotion_offset
        
        # 눈 외곽 그림자
        for i in range(3):
            shadow_rect = pygame.Rect(right_eye_x - eye_width//2 - i,
                                     right_eye_y - eye_height//2 - i,
                                     eye_width + i*2, eye_height + i*2)
            pygame.draw.ellipse(screen, (*LAVENDER, 30 - i*8), shadow_rect)
        
        # 눈 흰자위
        right_eye_rect = pygame.Rect(right_eye_x - eye_width//2, right_eye_y - eye_height//2,
                                     eye_width, eye_height)
        pygame.draw.ellipse(screen, (255, 252, 255), right_eye_rect)
        pygame.draw.ellipse(screen, SOFT_BLACK, right_eye_rect, 2)
        
        # 홍채 그라데이션
        iris_x = right_eye_x - iris_width//2
        iris_y = right_eye_y - iris_height//2 + 2
        
        for i, color in enumerate(iris_colors):
            iris_rect = pygame.Rect(iris_x + i*2, iris_y + i*2,
                                   iris_width - i*4, iris_height - i*4)
            pygame.draw.ellipse(screen, color, iris_rect)
        
        # 동공
        pygame.draw.ellipse(screen, SOFT_BLACK,
                          (right_eye_x - pupil_size//2, right_eye_y - pupil_size//2 + 2,
                           pupil_size + pupil_pulse, pupil_size + pupil_pulse))
        
        # 하이라이트들
        pygame.draw.ellipse(screen, WHITE,
                          (right_eye_x - eye_width//4, right_eye_y - eye_height//3,
                           eye_width//3, eye_height//4))
        pygame.draw.ellipse(screen, (255, 240, 250),
                          (right_eye_x - eye_width//4 + 2, right_eye_y - eye_height//3 + 2,
                           eye_width//4, eye_height//5))
        
        pygame.draw.circle(screen, WHITE, (right_eye_x + eye_width//5, right_eye_y - eye_height//4), 4)
        pygame.draw.circle(screen, (255, 230, 240), (right_eye_x - eye_width//6, right_eye_y + eye_height//6), 3)
        pygame.draw.circle(screen, WHITE, (right_eye_x + eye_width//8, right_eye_y + eye_height//5), 2)
        
        if star_twinkle > 200:
            self.draw_mini_star(screen, right_eye_x - eye_width//3, right_eye_y - eye_height//4,
                              2, (*WHITE, int(star_twinkle)))
        
        # 🌸 속눈썹 제거 (사용자 요청에 따라 눈 위 속눈썹/눈썹 제거)
        # lash_length = 8
        # lash_count = 5
        # for i in range(lash_count):
        #     angle = math.pi * (0.15 + i * 0.06)
        #     lash_x = left_eye_x - eye_width//2 + i * (eye_width//lash_count)
        #     lash_y = left_eye_y - eye_height//2
        #     end_x = lash_x + math.cos(angle) * lash_length
        #     end_y = lash_y - math.sin(angle) * lash_length
        #     pygame.draw.line(screen, SOFT_BLACK, (lash_x, lash_y), (end_x, end_y), 2)
        #     
        #     # 오른쪽 눈 속눈썹
        #     lash_x = right_eye_x - eye_width//2 + i * (eye_width//lash_count)
        #     angle = math.pi * (0.85 - i * 0.06)
        #     end_x = lash_x + math.cos(angle) * lash_length
        #     end_y = lash_y - math.sin(angle) * lash_length
        #     pygame.draw.line(screen, SOFT_BLACK, (lash_x, lash_y), (end_x, end_y), 2)
        
        # 아래 속눈썹 (짧게)
        for i in range(3):
            angle = -math.pi * (0.3 + i * 0.2)
            lash_x = left_eye_x - eye_width//4 + i * (eye_width//3)
            lash_y = left_eye_y + eye_height//2
            end_x = lash_x + math.cos(angle) * 4
            end_y = lash_y - math.sin(angle) * 4
            pygame.draw.line(screen, (*SOFT_BLACK, 100), (lash_x, lash_y), (end_x, end_y), 1)
            
            # 오른쪽
            lash_x = right_eye_x - eye_width//4 + i * (eye_width//3)
            pygame.draw.line(screen, (*SOFT_BLACK, 100), (lash_x, lash_y), 
                           (lash_x + math.cos(angle) * 4, lash_y - math.sin(angle) * 4), 1)
        
        # 🌸 미니 코 (점 하나로 초 간단하게)
        nose_y = y + head_size//6
        pygame.draw.circle(screen, (*PASTEL_PINK, 180), (x, nose_y), 2)
        pygame.draw.circle(screen, (*SOFT_BLACK, 100), (x, nose_y), 1)
        
        # 😊 카와이 입 (W 모양 고양이 입)
        mouth_y = y + head_size//4
        
        # 공 먹기 이벤트 중에는 입을 크게 벌림
        if self.eating_active and self.mouth_open > 0:
            # 입 벌림 애니메이션 (더 리얼하게)
            mouth_size = int(head_size * 0.45 * self.mouth_open)
            mouth_height = int(head_size * 0.6 * self.mouth_open)
            
            # 뱉기 준비 시 입 방향 조정
            mouth_offset_x = 0
            mouth_offset_y = 0
            if self.mouth_direction != 0 and self.eating_timer >= 210:  # 뱉기 준비 단계
                # 발사 방향으로 입 이동
                direction_strength = (self.eating_timer - 210) / 10  # 0~1
                mouth_offset_x = int(math.cos(self.mouth_direction) * 15 * direction_strength)
                mouth_offset_y = int(math.sin(self.mouth_direction) * 10 * direction_strength)
                
                # 방향 표시 화살표 그리기
                arrow_length = 40 + direction_strength * 20
                arrow_start_x = x + mouth_offset_x
                arrow_start_y = mouth_y + mouth_offset_y
                arrow_end_x = arrow_start_x + int(math.cos(self.mouth_direction) * arrow_length)
                arrow_end_y = arrow_start_y + int(math.sin(self.mouth_direction) * arrow_length)
                
                # 화살표 라인 (점선 효과)
                for i in range(0, int(arrow_length), 5):
                    if i % 10 < 5:  # 점선 패턴
                        dot_x = arrow_start_x + int(math.cos(self.mouth_direction) * i)
                        dot_y = arrow_start_y + int(math.sin(self.mouth_direction) * i)
                        alpha = int(255 * direction_strength * (1 - i / arrow_length * 0.3))
                        pygame.draw.circle(screen, (*CRIMSON, alpha), (dot_x, dot_y), 2)
                
                # 화살표 머리
                arrowhead_size = 8 + direction_strength * 4
                angle1 = self.mouth_direction + math.pi * 0.8
                angle2 = self.mouth_direction - math.pi * 0.8
                arrowhead_x1 = arrow_end_x + int(math.cos(angle1) * arrowhead_size)
                arrowhead_y1 = arrow_end_y + int(math.sin(angle1) * arrowhead_size)
                arrowhead_x2 = arrow_end_x + int(math.cos(angle2) * arrowhead_size)
                arrowhead_y2 = arrow_end_y + int(math.sin(angle2) * arrowhead_size)
                
                arrow_color = (*CRIMSON, int(200 * direction_strength))
                pygame.draw.polygon(screen, arrow_color, 
                                  [(arrow_end_x, arrow_end_y), 
                                   (arrowhead_x1, arrowhead_y1), 
                                   (arrowhead_x2, arrowhead_y2)])
            
            # 입술 윤곽 (먼저 그리기)
            lip_thickness = 3
            pygame.draw.ellipse(screen, (*CRIMSON, 150),
                              (x - mouth_size//2 - lip_thickness + mouth_offset_x, 
                               mouth_y - mouth_height//4 - lip_thickness + mouth_offset_y, 
                               mouth_size + lip_thickness*2, 
                               mouth_height + lip_thickness*2))
            
            # 입 안 (검은색 - 깊이감)
            pygame.draw.ellipse(screen, SOFT_BLACK,
                              (x - mouth_size//2 + mouth_offset_x, mouth_y - mouth_height//4 + mouth_offset_y, 
                               mouth_size, mouth_height))
            
            # 입 안쪽 그라데이션 효과
            for i in range(3):
                inner_size = mouth_size - 4 - i*4
                inner_height = mouth_height - 4 - i*4
                alpha = 200 - i*40
                pygame.draw.ellipse(screen, (*CRIMSON, alpha),
                                  (x - inner_size//2 + mouth_offset_x, mouth_y - inner_height//4 + mouth_offset_y,
                                   inner_size, inner_height))
            
            # 혀 그리기
            if self.mouth_open > 0.5:
                tongue_width = int(mouth_size * 0.6)
                tongue_height = int(mouth_height * 0.4)
                tongue_y = mouth_y + mouth_height//6 + mouth_offset_y
                
                # 혀 본체
                pygame.draw.ellipse(screen, (*PASTEL_PINK, 180),
                                  (x - tongue_width//2 + mouth_offset_x, tongue_y - tongue_height//2,
                                   tongue_width, tongue_height))
                # 혀 중앙선
                pygame.draw.line(screen, (*CRIMSON, 100),
                               (x + mouth_offset_x, tongue_y - tongue_height//3),
                               (x + mouth_offset_x, tongue_y + tongue_height//3), 2)
            
            # 씹기 애니메이션 (더 리얼한 오물거림)
            if self.chewing_phase > 0:
                # 턱의 실제 움직임 모션
                chew_cycle = math.sin(self.chewing_phase * math.pi * 8)
                chew_offset = chew_cycle * 8  # 턱 위아래 움직임
                
                # 입의 좌우 움직임 (음식을 옮기는 듯한)
                mouth_shift_x = math.sin(self.chewing_phase * math.pi * 4) * 5
                
                # 입 모양 변화 (오물거릴 때 입이 약간 벌어졌다 닫힘)
                mouth_open_variation = 0.2 + abs(chew_cycle) * 0.3
                actual_mouth_size = int(mouth_size * mouth_open_variation)
                actual_mouth_height = int(mouth_height * (0.5 + abs(chew_cycle) * 0.5))
                
                # 위 이빨 (입의 움직임에 따라 이동)
                teeth_count = 5
                teeth_width = actual_mouth_size // (teeth_count + 1)
                for i in range(teeth_count):
                    tooth_x = x - actual_mouth_size//2 + teeth_width * (i + 1) + mouth_shift_x
                    tooth_y = mouth_y - actual_mouth_height//4 + 5
                    tooth_size = 4
                    pygame.draw.polygon(screen, WHITE,
                                      [(tooth_x - tooth_size, tooth_y),
                                       (tooth_x, tooth_y + tooth_size),
                                       (tooth_x + tooth_size, tooth_y)])
                
                # 아래 이빨 (씹을 때 크게 움직임)
                for i in range(teeth_count):
                    tooth_x = x - actual_mouth_size//2 + teeth_width * (i + 1) + mouth_shift_x
                    tooth_y = mouth_y + actual_mouth_height//4 - 5 + chew_offset
                    tooth_size = 4
                    
                    # 씹을 때 이빨이 약간 기울어짐
                    tilt = math.sin((self.chewing_phase + i * 0.2) * math.pi * 8) * 0.1
                    points = [
                        (tooth_x - tooth_size + tilt * tooth_size, tooth_y),
                        (tooth_x, tooth_y - tooth_size),
                        (tooth_x + tooth_size - tilt * tooth_size, tooth_y)
                    ]
                    pygame.draw.polygon(screen, WHITE, points)
                
                # 입술 움직임 (오물거리는 효과)
                # 위 입술
                lip_curve = abs(chew_cycle) * 5
                pygame.draw.arc(screen, (*CRIMSON, 100),
                              (x - actual_mouth_size//2 + mouth_shift_x, 
                               mouth_y - actual_mouth_height//2 - lip_curve,
                               actual_mouth_size, actual_mouth_height//2),
                              0, math.pi, 3)
                
                # 아래 입술 (더 크게 움직임)
                pygame.draw.arc(screen, (*CRIMSON, 100),
                              (x - actual_mouth_size//2 + mouth_shift_x, 
                               mouth_y + chew_offset,
                               actual_mouth_size, actual_mouth_height//2),
                              math.pi, math.pi * 2, 3)
                
                # 씹는 동작 강조선
                if int(self.chewing_phase * 8) % 2 == 0:
                    # 좌우 움직임 선
                    for i in range(3):
                        line_x = x - mouth_size//2 - 10 - i*5
                        line_y = mouth_y + random.randint(-10, 10)
                        pygame.draw.line(screen, (*SOFT_YELLOW, 100 - i*20),
                                       (line_x, line_y - 5), (line_x - 10, line_y), 2)
                        
                        line_x = x + mouth_size//2 + 10 + i*5
                        pygame.draw.line(screen, (*SOFT_YELLOW, 100 - i*20),
                                       (line_x, line_y - 5), (line_x + 10, line_y), 2)
        # 감정에 따른 입 모양
        elif self.emotional_phase == 1:  # 행복
            # 큰 웃음
            pygame.draw.arc(screen, SOFT_BLACK,
                          (x - head_size//5, mouth_y - 5, head_size//5, 15),
                          0, math.pi, 2)
            pygame.draw.arc(screen, SOFT_BLACK,
                          (x, mouth_y - 5, head_size//5, 15),
                          0, math.pi, 2)
            # 입 안 (핑크색)
            pygame.draw.arc(screen, (*PASTEL_PINK, 150),
                          (x - head_size//5 + 2, mouth_y - 3, head_size//5 - 4, 10),
                          0, math.pi, 6)
        elif self.emotional_phase == 2:  # 슬픔
            # 처진 입
            pygame.draw.arc(screen, SOFT_BLACK,
                          (x - head_size//6, mouth_y + 2, head_size//3, 10),
                          math.pi * 0.2, math.pi * 0.8, 2)
        else:  # 평온
            # 기본 W 모양
            pygame.draw.arc(screen, SOFT_BLACK,
                          (x - head_size//6, mouth_y - 4, head_size//6, 10),
                          0, math.pi, 2)
            pygame.draw.arc(screen, SOFT_BLACK,
                          (x, mouth_y - 4, head_size//6, 10),
                          0, math.pi, 2)
        
        # 입 중앙선 (코에서 입까지)
        pygame.draw.line(screen, (*SOFT_BLACK, 80), (x, nose_y + 2), (x, mouth_y - 3), 1)
        
        # 🎀 울트라 카와이 꼬리 (공을 따라 원 안에서 회전 + 채찍 모드)
        if self.tail_whip_active and self.tail_whip_target:
            # 꼬리 채찍 모드: 공을 향해 빠르게 뻗어나가는 모션
            target_x, target_y = self.tail_whip_target
            
            # 캐릭터에서 타겟까지의 각도와 거리
            angle_to_target = math.atan2(target_y - y, target_x - x)
            distance_to_target = math.sqrt((target_x - x) ** 2 + (target_y - y) ** 2)
            
            # 진행도에 따른 꼬리 움직임
            if self.tail_whip_progress < 0.3:
                # 준비 동작: 뒤로 당기기
                angle_to_ball = angle_to_target + math.pi  # 반대 방향
                tail_orbit_radius = head_size * 0.8
            elif self.tail_whip_progress < 0.6:
                # 타격 동작: 빠르게 공을 향해
                angle_to_ball = angle_to_target
                # 빠르게 늘어나는 효과
                extension = (self.tail_whip_progress - 0.3) / 0.3
                tail_orbit_radius = head_size * 0.8 + (distance_to_target * 0.7 * extension)
            else:
                # 회수 동작
                angle_to_ball = angle_to_target
                recovery = (self.tail_whip_progress - 0.6) / 0.4
                tail_orbit_radius = distance_to_target * 0.7 * (1 - recovery) + head_size * 0.9 * recovery
        elif ball_pos:
            ball_x, ball_y = ball_pos
            # 공의 각도 계산 (원 중심 기준)
            angle_to_ball = math.atan2(ball_y - y, ball_x - x)
            tail_orbit_radius = head_size * 0.9
        else:
            # 기본 각도 (시간에 따라 자동 회전)
            angle_to_ball = self.time * 0.002
            tail_orbit_radius = head_size * 0.9
        
        # 꼬리 베이스 위치
        if self.tail_whip_active and self.tail_whip_target:
            # 채찍 모드: 타겟을 향해 직접 뻗어나감
            tail_base_angle = angle_to_ball
            tail_base_x = x
            tail_base_y = y
        else:
            # 일반 모드: 캐릭터 뒤쪽, 공 반대 방향
            tail_base_angle = angle_to_ball + math.pi
            tail_base_x = x + int(tail_orbit_radius * math.cos(tail_base_angle))
            tail_base_y = y + int(tail_orbit_radius * math.sin(tail_base_angle) * 0.7)  # 타원형 궤도
        
        # 꼬리 세그먼트 (더 많고 부드러운 곡선)
        tail_segments = 30 if self.tail_whip_active else 20
        tail_points = []
        
        for i in range(tail_segments):
            t = i / (tail_segments - 1)
            
            if self.tail_whip_active and self.tail_whip_target:
                # 채찍 모드: 공을 향한 직접적인 타격
                target_x, target_y = self.tail_whip_target
                
                if self.tail_whip_progress < 0.3:
                    # 준비: 꼬리를 뒤로 말아올림
                    spiral = t * math.pi * 4
                    wave_amplitude = 30 * (1 - t * 0.5)
                    wave = math.sin(spiral - self.tail_whip_progress * math.pi * 3) * wave_amplitude
                    distance = 25 * t * t * (1 - self.tail_whip_progress * 2)
                    depth_offset = 0
                elif self.tail_whip_progress < 0.6:
                    # 타격: 직선적으로 뻗어나감
                    whip_power = (self.tail_whip_progress - 0.3) / 0.3
                    # 타겟을 향한 직선 움직임
                    distance = distance_to_target * t * whip_power
                    # 약간의 탄성 효과
                    wave_amplitude = 5 * (1 - t) * (1 - whip_power)
                    wave = math.sin(t * math.pi * 2) * wave_amplitude
                    depth_offset = 0
                else:
                    # 회수: 부드럽게 원위치
                    recovery = (self.tail_whip_progress - 0.6) / 0.4
                    spiral = t * math.pi * 2
                    wave_amplitude = 15 * (1 - t * 0.5) * recovery
                    wave = math.sin(spiral + self.time * 0.01) * wave_amplitude
                    distance = 35 * t * t * (0.5 + recovery * 0.5)
                    depth_offset = math.cos(self.time * 0.008 + t * 3) * 8 * (1 - t) * recovery
            else:
                # 일반 모드: 부드러운 움직임
                spiral = t * math.pi * 2
                wave_amplitude = 20 * (1 - t * 0.5)
                wave = math.sin(spiral + self.time * 0.01) * wave_amplitude
                distance = 35 * t * t
                depth_offset = math.cos(self.time * 0.008 + t * 3) * 8 * (1 - t)
            
            # 꼬리 포인트 계산
            tail_angle = tail_base_angle + wave * 0.02
            tx = tail_base_x + int(distance * math.cos(tail_angle) + depth_offset * math.sin(tail_angle))
            ty = tail_base_y + int(distance * math.sin(tail_angle) - depth_offset * math.cos(tail_angle))
            
            tail_points.append((tx, ty))
        
        # 꼬리 포인트를 클래스 변수에 저장 (충돌 체크용)
        self.tail_points = tail_points
        
        # 꼬리 그라데이션 그리기 (여러 층으로)
        if len(tail_points) > 1:
            # 그림자 효과
            for i in range(len(tail_points) - 1):
                thickness = max(1, int((8 - i * 0.3) * 1.5))
                shadow_color = (*LAVENDER, 50)
                pygame.draw.line(screen, shadow_color, 
                               (tail_points[i][0] + 2, tail_points[i][1] + 2),
                               (tail_points[i + 1][0] + 2, tail_points[i + 1][1] + 2),
                               thickness + 2)
            
            # 메인 꼬리 (그라데이션 색상)
            for i in range(len(tail_points) - 1):
                progress = i / len(tail_points)
                
                if self.tail_whip_active:
                    # 채찍 모드: 원래 색상 유지 (검은색 → 보라색)
                    color_r = int(SOFT_BLACK[0] * (1 - progress) + LAVENDER[0] * progress)
                    color_g = int(SOFT_BLACK[1] * (1 - progress) + LAVENDER[1] * progress)
                    color_b = int(SOFT_BLACK[2] * (1 - progress) + LAVENDER[2] * progress)
                    thickness = max(2, int(10 - i * 0.3))  # 더 두꺼운 꼬리
                else:
                    # 일반 모드: 검은색 → 보라색
                    color_r = int(SOFT_BLACK[0] * (1 - progress) + LAVENDER[0] * progress)
                    color_g = int(SOFT_BLACK[1] * (1 - progress) + LAVENDER[1] * progress)
                    color_b = int(SOFT_BLACK[2] * (1 - progress) + LAVENDER[2] * progress)
                    thickness = max(1, int(8 - i * 0.35))
                
                pygame.draw.line(screen, (color_r, color_g, color_b), 
                               tail_points[i], tail_points[i + 1], thickness)
            
            # 하이라이트 (윤기)
            for i in range(0, len(tail_points) - 1, 3):
                if i < len(tail_points) // 2:  # 앞쪽 절반만
                    pygame.draw.circle(screen, (*WHITE, 80),
                                     tail_points[i], max(1, 3 - i // 4))
            
            # 채찍 타격 시 임팩트 효과
            if self.tail_whip_active and 0.4 <= self.tail_whip_progress <= 0.6:
                # 꼬리 끝 부분에 타격 효과
                if len(tail_points) > 20:
                    impact_point = tail_points[-5]  # 끝에서 5번째 포인트
                    # 충격파
                    impact_radius = int(20 * (self.tail_whip_progress - 0.4) / 0.2)
                    for r in range(3):
                        alpha = 100 - r * 30
                        impact_surf = pygame.Surface((impact_radius * 2, impact_radius * 2), pygame.SRCALPHA)
                        pygame.draw.circle(impact_surf, (*LAVENDER, alpha), 
                                         (impact_radius, impact_radius), impact_radius - r * 3, 2)
                        screen.blit(impact_surf, (impact_point[0] - impact_radius, 
                                                 impact_point[1] - impact_radius))
        
        # 💝 꼬리 끝 장식 (울트라 카와이 하트)
        if tail_points:
            end_x, end_y = tail_points[-1]
            
            # 하트 펄스 효과
            heart_pulse = abs(math.sin(self.time * 0.015)) * 2 + 8
            
            # 하트 광채
            for i in range(3):
                alpha = 60 - i * 15
                size = heart_pulse + i * 2
                glow_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (*PASTEL_PINK, alpha),
                                 (size, size), size)
                screen.blit(glow_surface, (end_x - size, end_y - size))
            
            # 메인 하트 (더 정교하게)
            heart_size = int(heart_pulse)
            # 하트 윗부분 (두 원)
            pygame.draw.circle(screen, PASTEL_PINK, 
                             (end_x - heart_size//3, end_y - heart_size//3), heart_size//2)
            pygame.draw.circle(screen, PASTEL_PINK,
                             (end_x + heart_size//3, end_y - heart_size//3), heart_size//2)
            # 하트 아래 삼각형
            heart_bottom = [
                (end_x - heart_size, end_y),
                (end_x, end_y + heart_size),
                (end_x + heart_size, end_y)
            ]
            pygame.draw.polygon(screen, PASTEL_PINK, heart_bottom)
            
            # 하트 테두리
            pygame.draw.circle(screen, SOFT_BLACK,
                             (end_x - heart_size//3, end_y - heart_size//3), heart_size//2, 1)
            pygame.draw.circle(screen, SOFT_BLACK,
                             (end_x + heart_size//3, end_y - heart_size//3), heart_size//2, 1)
            pygame.draw.lines(screen, SOFT_BLACK, False, heart_bottom, 1)
            
            # 하트 하이라이트
            pygame.draw.circle(screen, (*WHITE, 200),
                             (end_x - heart_size//4, end_y - heart_size//3), 2)
            pygame.draw.circle(screen, (*WHITE, 150),
                             (end_x + heart_size//5, end_y - heart_size//4), 1)
            
            # 작은 별 장식 (반짝임)
            if self.time % 60 < 30:  # 주기적으로 반짝임
                for angle in range(0, 360, 72):  # 5개의 별
                    star_x = end_x + int(math.cos(math.radians(angle)) * (heart_size + 5))
                    star_y = end_y + int(math.sin(math.radians(angle)) * (heart_size + 5))
                    self.draw_mini_star(screen, star_x, star_y, 2, (*WHITE, 180))
        
        # 💖 울트라 카와이 블러시 (애니메이션 효과)
        blush_y = y + head_size//5
        blush_intensity = int(100 + abs(math.sin(self.time * 0.006)) * 50)
        
        # 왼쪽 볼
        for i in range(3):
            blush_size = 15 - i * 3
            alpha = blush_intensity - i * 30
            pygame.draw.ellipse(screen, (*PASTEL_PINK, alpha),
                              (left_eye_x - blush_size//2, blush_y - blush_size//3,
                               blush_size, blush_size//2))
        
        # 오른쪽 볼
        for i in range(3):
            blush_size = 15 - i * 3
            alpha = blush_intensity - i * 30
            pygame.draw.ellipse(screen, (*PASTEL_PINK, alpha),
                              (right_eye_x - blush_size//2, blush_y - blush_size//3,
                               blush_size, blush_size//2))
        
        # ✨ 주변 떠다니는 장식들 (키라키라 효과)
        decoration_time = self.time * 0.003
        
        # 하트 버블들
        for i in range(3):
            bubble_angle = decoration_time + i * (math.pi * 2 / 3)
            bubble_radius = head_size * 1.5 + math.sin(decoration_time * 2 + i) * 10
            bubble_x = x + int(math.cos(bubble_angle) * bubble_radius)
            bubble_y = y + int(math.sin(bubble_angle) * bubble_radius * 0.7)
            
            # 투명 하트
            bubble_alpha = 80 + int(math.sin(decoration_time * 3 + i * 2) * 40)
            self.draw_heart(screen, bubble_x, bubble_y, 5, (*PASTEL_PINK, bubble_alpha))
        
        # 별 이펙트
        for i in range(5):
            star_angle = -decoration_time * 1.5 + i * (math.pi * 2 / 5)
            star_radius = head_size * 1.3 + math.cos(decoration_time * 2.5 + i) * 8
            star_x = x + int(math.cos(star_angle) * star_radius)
            star_y = y + int(math.sin(star_angle) * star_radius * 0.7)
            
            star_alpha = 120 + int(math.cos(decoration_time * 4 + i * 3) * 60)
            self.draw_mini_star(screen, star_x, star_y, 3, (*WHITE, star_alpha))
        
        # 🌈 감정 파티클 (감정 상태에 따라)
        if self.emotional_phase == 1:  # 행복
            # 무지개 색 스파클
            for i in range(4):
                sparkle_angle = decoration_time * 3 + i * math.pi/2
                sparkle_radius = head_size + 20
                sparkle_x = x + int(math.cos(sparkle_angle) * sparkle_radius)
                sparkle_y = y + int(math.sin(sparkle_angle) * sparkle_radius * 0.5)
                
                rainbow_colors = [(255, 182, 193), (255, 218, 185), (255, 255, 224),
                                 (185, 255, 185), (185, 218, 255), (218, 185, 255)]
                color = rainbow_colors[i % len(rainbow_colors)]
                pygame.draw.circle(screen, (*color, 150), (sparkle_x, sparkle_y), 3)
        
        elif self.emotional_phase == 2:  # 슬픔
            # 눈물 효과
            tear_offset = abs(math.sin(self.time * 0.004)) * 5
            pygame.draw.circle(screen, (*BABY_BLUE, 180),
                             (left_eye_x, left_eye_y + eye_height//2 + tear_offset), 2)
            pygame.draw.circle(screen, (*BABY_BLUE, 180),
                             (right_eye_x, right_eye_y + eye_height//2 + tear_offset + 2), 2)
    
    def draw_heart(self, screen, x, y, size, color):
        """하트 그리기"""
        # 두 원으로 상단 부분
        pygame.draw.circle(screen, color, (x - size//3, y - size//3), size//2)
        pygame.draw.circle(screen, color, (x + size//3, y - size//3), size//2)
        # 삼각형으로 하단 부분
        points = [
            (x - size, y),
            (x, y + size),
            (x + size, y)
        ]
        pygame.draw.polygon(screen, color, points)
    
    def draw_broken_heart(self, screen, x, y, size, color):
        """깨진 하트 그리기"""
        # 지그재그 선으로 갈라진 효과
        self.draw_heart(screen, x, y, size, color)
        # 균열 선
        crack_points = [
            (x - 2, y - size//2),
            (x + 2, y - size//3),
            (x - 3, y),
            (x + 1, y + size//3),
            (x - 2, y + size)
        ]
        pygame.draw.lines(screen, SOFT_BLACK, False, crack_points, 2)
    
    def draw_particles(self, screen):
        """하트와 별 파티클 그리기 (은은하게)"""
        # 별 파티클 (더 은은하게)
        for star in self.star_particles:
            alpha = abs(math.sin(star['twinkle'])) * star['life'] / 200  # 알파값 감소
            if alpha > 0:
                # 은은한 빛나는 효과
                star_surface = pygame.Surface((star['size'] * 4, star['size'] * 4), pygame.SRCALPHA)
                center = star['size'] * 2
                pygame.draw.circle(star_surface, (*WHITE, int(alpha * 100)), 
                                 (center, center), star['size'] * 2)
                screen.blit(star_surface, (star['x'] - center, star['y'] - center))
                self.draw_mini_star(screen, int(star['x']), int(star['y']), star['size'], (*WHITE, int(alpha * 200)))
        
        # 하트 파티클 (더 은은하게)
        for heart in self.heart_particles:
            alpha = heart['life'] / 600  # 알파값 감소
            if alpha > 0 and alpha < 0.8:  # 너무 진하지 않게
                # 하트 색상 조정 (더 파스텔톤으로)
                faded_color = tuple(min(255, c + 50) for c in heart['color'])
                if heart['broken']:
                    self.draw_broken_heart(screen, int(heart['x']), int(heart['y']), 
                                         heart['size'], (*faded_color, int(alpha * 150)))
                else:
                    self.draw_heart(screen, int(heart['x']), int(heart['y']), 
                                  heart['size'], (*faded_color, int(alpha * 150)))
    
    def draw_background_pattern(self, screen):
        """배경 패턴 - Stage 5 스타일로 깔끔하게"""
        tile_size = 50
        
        # 기본 배경 색상 (감정에 따라 변화)
        if self.emotional_phase == 0:  # 평온
            base_color = (55, 45, 65)  # 보라빛 어둠
        elif self.emotional_phase == 1:  # 행복
            base_color = (65, 40, 55)  # 핑크빛 어둠
        else:  # 슬픔
            base_color = (40, 50, 70)  # 블루빛 어둠
        
        # 체크무늬 패턴 (전체, 은은하게)
        for x in range(0, WIDTH, tile_size):
            for y in range(0, HEIGHT, tile_size):
                if (x // tile_size + y // tile_size) % 2 == 0:
                    color = base_color
                else:
                    color = (base_color[0] + 10, base_color[1] + 8, base_color[2] + 10)
                
                pygame.draw.rect(screen, color, (x, y, tile_size, tile_size))
                
                # 타일 테두리 (매우 은은하게)
                border_color = (base_color[0] - 5, base_color[1] - 5, base_color[2] - 5)
                pygame.draw.rect(screen, border_color, (x, y, tile_size, tile_size), 1)
    
    def draw_medical_cross(self, screen, x, y, size, color):
        """의료 십자가 심볼"""
        # 가로선
        pygame.draw.rect(screen, color, (x - size, y - size//3, size * 2, size//1.5))
        # 세로선
        pygame.draw.rect(screen, color, (x - size//3, y - size, size//1.5, size * 2))
    
    def draw_diamond_pattern(self, screen, x, y, size, color):
        """다이아몬드 패턴 장식"""
        points = [
            (x, y - size),
            (x + size, y),
            (x, y + size),
            (x - size, y)
        ]
        pygame.draw.polygon(screen, color, points, 2)
    
    def draw(self, screen, ball_pos=None):
        """전체 스테이지 3 맵 그리기"""
        # 배경 패턴
        self.draw_background_pattern(screen)
        
        # 파티클 효과 (배경) - 은은하게
        self.draw_particles(screen)
        
        # 중앙 스타디움 라인 (공 위치 전달)
        self.draw_stadium_line(screen, ball_pos)
        
        # 테두리 (마지막에 그려서 위에 표시)
        self.draw_border(screen)
    
    def draw_emotional_indicator(self, screen):
        """감정 상태 인디케이터"""
        x, y = WIDTH - 50, 30
        
        # 배경 원
        pygame.draw.circle(screen, WHITE, (x, y), 20, 2)
        pygame.draw.circle(screen, self.get_emotional_color(), (x, y), 17)
        
        # 감정 아이콘
        if self.emotional_phase == 0:  # 평온
            # 일반 얼굴
            pygame.draw.circle(screen, WHITE, (x - 5, y - 5), 2)
            pygame.draw.circle(screen, WHITE, (x + 5, y - 5), 2)
            pygame.draw.arc(screen, WHITE, (x - 8, y - 2, 16, 12), 0, math.pi, 2)
        elif self.emotional_phase == 1:  # 행복
            # 웃는 얼굴
            pygame.draw.circle(screen, WHITE, (x - 5, y - 5), 2)
            pygame.draw.circle(screen, WHITE, (x + 5, y - 5), 2)
            pygame.draw.arc(screen, WHITE, (x - 10, y - 5, 20, 15), 0, math.pi, 2)
        else:  # 슬픔
            # 우는 얼굴
            pygame.draw.circle(screen, WHITE, (x - 5, y - 5), 2)
            pygame.draw.circle(screen, WHITE, (x + 5, y - 5), 2)
            pygame.draw.arc(screen, WHITE, (x - 8, y + 5, 16, 12), math.pi, 2*math.pi, 2)
            # 눈물
            pygame.draw.circle(screen, BABY_BLUE, (x - 5, y), 1)
            pygame.draw.circle(screen, BABY_BLUE, (x + 5, y), 1)
    
    def check_ball_eating(self, ball_rect):
        """공이 쿠로미 근처에 있는지 확인 (50% 확률)"""
        if self.eating_active:
            return False  # 이미 먹는 중이면 스킵
        
        # 중앙 캐릭터 위치
        center_x = WIDTH // 2
        center_y = HEIGHT // 2
        kuromi_rect = pygame.Rect(center_x - 60, center_y - 60, 120, 120)
        
        # 공이 쿠로미와 충돌하면 50% 확률로 먹기
        if kuromi_rect.colliderect(ball_rect):
            if random.random() < 0.5:  # 50% 확률
                return True
        return False
    
    def start_eating(self):
        """공 먹기 이벤트 시작"""
        self.eating_active = True
        self.eating_timer = 0
        self.mouth_open = 0
        self.chewing_phase = 0
        self.chewing_particles = []
        self.spit_angle = None  # 발사 각도 초기화
        self.mouth_direction = 0  # 입 방향 초기화
    
    def update_eating(self, dt):
        """공 먹기 애니메이션 업데이트 - 더 리얼하고 생동감 있게"""
        if not self.eating_active:
            return False  # 공이 여전히 화면에 표시됨
        
        self.eating_timer += dt / 16.67  # 60FPS 기준으로 정규화
        
        if self.eating_timer < 90:  # 1.5초 - 입 벌리기
            # Elastic easing으로 더 다이나믹한 입 열기
            t = min(1.0, self.eating_timer / 90)
            if t < 0.4:
                self.mouth_open = t * t * 2.5
            else:
                # 입이 벌어질 때 탄성 효과
                self.mouth_open = 1 + math.sin((t - 0.4) * math.pi * 4) * 0.15 * (1 - t)
            
            # 침 떨어지는 효과 (입 벌릴 때)
            if self.eating_timer < 30 and random.random() < 0.4:
                for _ in range(2):
                    particle_x = WIDTH // 2 + random.randint(-15, 15)
                    particle_y = HEIGHT // 2 + 25
                    self.chewing_particles.append({
                        'x': particle_x,
                        'y': particle_y,
                        'vx': random.uniform(-1.5, 1.5),
                        'vy': random.uniform(2, 4),
                        'life': 25,
                        'color': (*LAVENDER, 120),
                        'type': 'saliva',
                        'size': random.uniform(2, 4)
                    })
            
            # 빨아들이는 바람 효과 (공이 입으로)
            if self.eating_timer > 60:
                for _ in range(3):
                    angle = random.uniform(0, math.pi * 2)
                    dist = random.uniform(40, 80)
                    particle_x = WIDTH // 2 + math.cos(angle) * dist
                    particle_y = HEIGHT // 2 + math.sin(angle) * dist
                    self.chewing_particles.append({
                        'x': particle_x,
                        'y': particle_y,
                        'vx': -math.cos(angle) * 5,
                        'vy': -math.sin(angle) * 5,
                        'life': 15,
                        'color': (*WHITE, 80),
                        'type': 'wind',
                        'size': random.uniform(1, 3)
                    })
            
            return True  # 공을 숨김
            
        elif self.eating_timer < 210:  # 2초 - 씹기
            # 더 리얼한 씹기 모션
            chew_progress = (self.eating_timer - 90) / 120
            self.chewing_phase = chew_progress
            
            # 턱 움직임 (위아래로 씹기)
            chew_cycle = math.sin(chew_progress * math.pi * 8)  # 더 빠른 씹기
            self.mouth_open = 0.15 + abs(chew_cycle) * 0.35
            
            # 씹는 파티클 효과 (간소화 - 실제 움직임에 집중)
            if random.random() < 0.3:  # 빈도 감소
                # 음식 조각 (적게)
                particle_x = WIDTH // 2 + random.randint(-20, 20)
                particle_y = HEIGHT // 2 + random.randint(-10, 10)
                particle_color = random.choice([PASTEL_PINK, WHITE])
                self.chewing_particles.append({
                    'x': particle_x,
                    'y': particle_y,
                    'vx': random.uniform(-3, 3),
                    'vy': random.uniform(-4, -1),
                    'life': 30,
                    'color': particle_color,
                    'type': 'food',
                    'size': random.uniform(2, 4),
                    'rotation': random.uniform(0, math.pi * 2),
                    'rotation_speed': random.uniform(-0.3, 0.3)
                })
            
            # 증기 효과 (간소화)
            if random.random() < 0.1:  # 빈도 대폭 감소
                particle_x = WIDTH // 2 + random.randint(-15, 15)
                particle_y = HEIGHT // 2 - 10
                self.chewing_particles.append({
                    'x': particle_x,
                    'y': particle_y,
                    'vx': random.uniform(-1, 1),
                    'vy': random.uniform(-2, -1),
                    'life': 40,
                    'color': (*WHITE, 40),
                    'type': 'steam',
                    'size': random.uniform(5, 8)
                })
            
            # 파티클 업데이트 (물리 효과 적용)
            updated_particles = []
            for p in self.chewing_particles:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['life'] -= 1
                
                # 타입별 특수 효과
                if p['type'] == 'food':
                    p['vy'] += 0.4  # 중력
                    if 'rotation' in p:
                        p['rotation'] += p.get('rotation_speed', 0)
                elif p['type'] == 'steam':
                    p['vy'] -= 0.08  # 위로 올라감
                    p['size'] *= 1.03  # 퍼짐
                    p['vx'] *= 0.95  # 감속
                elif p['type'] == 'saliva':
                    p['vy'] += 0.6  # 중력
                elif p['type'] == 'shockwave':
                    # 충격파 확장
                    expansion = (10 - p['life']) / 10
                    p['size'] = p.get('max_size', 30) * expansion
                elif p['type'] == 'wind':
                    p['vx'] *= 0.9  # 감속
                    p['vy'] *= 0.9
                
                if p['life'] > 0:
                    updated_particles.append(p)
            
            self.chewing_particles = updated_particles
            return True  # 공을 숨김
            
        elif self.eating_timer < 220:  # 0.17초 - 뱉기 준비
            # 뱉을 방향 미리 결정 (처음 한 번만)
            if self.spit_angle is None:
                self.spit_angle = random.uniform(-math.pi * 0.7, math.pi * 0.7)
                self.mouth_direction = self.spit_angle  # 입 방향 설정
            
            # 볼 부풀리기 (압력 증가)
            buildup = (self.eating_timer - 210) / 10
            self.mouth_open = 0.2 + buildup * 0.6
            self.chewing_phase = 0
            
            # 압력 파티클
            if random.random() < 0.8:
                for _ in range(2):
                    particle_x = WIDTH // 2 + random.randint(-10, 10)
                    particle_y = HEIGHT // 2 + random.randint(-5, 5)
                    self.chewing_particles.append({
                        'x': particle_x,
                        'y': particle_y,
                        'vx': random.uniform(-3, 3),
                        'vy': random.uniform(-1, 1),
                        'life': 8,
                        'color': (*CRIMSON, 180),
                        'type': 'pressure',
                        'size': random.uniform(3, 5)
                    })
            
            return True
            
        else:  # 3.67초 이후 - 폭발적으로 뱉기
            if self.eating_timer < 225:  # 뱉는 순간
                # 대폭발 효과
                for _ in range(25):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(8, 20)
                    particle_x = WIDTH // 2
                    particle_y = HEIGHT // 2
                    particle_color = random.choice([
                        PASTEL_PINK, LAVENDER, WHITE, SOFT_YELLOW,
                        (*CRIMSON, 200), (*MINT_GREEN, 150)
                    ])
                    self.chewing_particles.append({
                        'x': particle_x,
                        'y': particle_y,
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed,
                        'life': 35,
                        'color': particle_color,
                        'type': 'explosion',
                        'size': random.uniform(5, 10)
                    })
                
                # 큰 충격파
                self.chewing_particles.append({
                    'x': WIDTH // 2,
                    'y': HEIGHT // 2,
                    'vx': 0,
                    'vy': 0,
                    'life': 20,
                    'color': (*WHITE, 150),
                    'type': 'shockwave',
                    'size': 10,
                    'max_size': 100
                })
            
            self.eating_active = False
            self.mouth_open = 0
            self.chewing_phase = 0
            self.spit_angle = None  # 발사 각도 리셋
            self.mouth_direction = 0  # 입 방향 리셋
            return False  # 공을 다시 표시
    
    def get_spit_velocity(self):
        """미리 결정된 방향으로 공을 뱉어낼 속도 벡터 반환 - 2배 빠르게"""
        # 미리 결정된 각도 사용 (없으면 랜덤)
        if self.spit_angle is not None:
            angle = self.spit_angle
        else:
            angle = random.uniform(-math.pi * 0.7, math.pi * 0.7)
        
        # 기본 속도를 2배로 증가 (8-12 → 16-24)
        base_speed = random.uniform(8, 12)
        speed = base_speed * 2.0  # 2배 증가
        
        vx = speed * math.cos(angle)
        vy = speed * math.sin(angle)
        
        # 위 또는 아래로 더 강하게
        if random.random() < 0.5:
            vy = -abs(vy) if random.random() < 0.5 else abs(vy)
        
        # 뱉을 때 특수 이펙트 파티클 생성
        self.create_spit_effect_particles(angle, speed)
        
        return vx, vy
    
    def create_spit_effect_particles(self, angle, speed):
        """공을 뱉을 때 특수 이펙트 생성"""
        # 스피드 라인 효과
        for i in range(15):
            line_angle = angle + random.uniform(-0.3, 0.3)
            line_speed = speed * random.uniform(0.8, 1.5)
            particle_x = WIDTH // 2
            particle_y = HEIGHT // 2
            
            self.chewing_particles.append({
                'x': particle_x,
                'y': particle_y,
                'vx': math.cos(line_angle) * line_speed,
                'vy': math.sin(line_angle) * line_speed,
                'life': 20,
                'color': (*SOFT_YELLOW, 200),
                'type': 'speed_line',
                'size': random.uniform(15, 25),
                'angle': line_angle
            })
        
        # 파워 링 효과 (충격파)
        self.chewing_particles.append({
            'x': WIDTH // 2,
            'y': HEIGHT // 2,
            'vx': 0,
            'vy': 0,
            'life': 30,
            'color': (*WHITE, 255),
            'type': 'power_ring',
            'size': 20,
            'max_size': 150
        })
        
        # 침 폭발 효과
        for _ in range(20):
            splash_angle = random.uniform(0, math.pi * 2)
            splash_speed = random.uniform(5, 15)
            self.chewing_particles.append({
                'x': WIDTH // 2,
                'y': HEIGHT // 2,
                'vx': math.cos(splash_angle) * splash_speed,
                'vy': math.sin(splash_angle) * splash_speed,
                'life': 25,
                'color': (*LAVENDER, 150),
                'type': 'spit_splash',
                'size': random.uniform(3, 6)
            })
    
    def draw_chewing_effects(self, screen):
        """씹는 이펙트 그리기 - 더 다양하고 생동감 있게"""
        for particle in self.chewing_particles:
            p_type = particle.get('type', 'default')
            
            if p_type == 'saliva':
                # 침 방울 (반투명 물방울)
                alpha = int(180 * (particle['life'] / 25))
                size = particle.get('size', 3)
                color = (*particle['color'][:3], alpha)
                pygame.draw.circle(screen, color, 
                                 (int(particle['x']), int(particle['y'])), 
                                 int(size))
                # 하이라이트
                pygame.draw.circle(screen, (*WHITE, alpha//2),
                                 (int(particle['x'] - size//3), int(particle['y'] - size//3)),
                                 max(1, int(size//3)))
                
            elif p_type == 'food':
                # 음식 조각 (회전하는 사각형/다각형)
                alpha = int(255 * (particle['life'] / 45))
                size = particle.get('size', 5)
                color = (*particle['color'][:3], alpha)
                rotation = particle.get('rotation', 0)
                
                # 회전하는 음식 조각
                points = []
                sides = random.choice([3, 4, 5])
                for i in range(sides):
                    angle = rotation + (i * 2 * math.pi / sides)
                    px = particle['x'] + size * math.cos(angle)
                    py = particle['y'] + size * math.sin(angle)
                    points.append((int(px), int(py)))
                
                if len(points) >= 3:
                    pygame.draw.polygon(screen, color, points)
                
            elif p_type == 'steam':
                # 증기 (부드러운 원형, 퍼지면서 사라짐)
                alpha = int(60 * (particle['life'] / 60))
                size = particle.get('size', 10)
                color = (*particle['color'][:3], alpha)
                
                # 여러 겹의 원으로 부드러운 증기 효과
                for i in range(3):
                    layer_size = size + i * 3
                    layer_alpha = max(0, alpha - i * 20)
                    if layer_alpha > 0:
                        pygame.draw.circle(screen, (*color[:3], layer_alpha),
                                         (int(particle['x']), int(particle['y'])),
                                         int(layer_size), 1)
                
            elif p_type == 'wind':
                # 바람 효과 (선)
                alpha = int(80 * (particle['life'] / 15))
                size = particle.get('size', 2)
                color = (*particle['color'][:3], alpha)
                
                # 속도 방향으로 선 그리기
                end_x = particle['x'] - particle['vx'] * 3
                end_y = particle['y'] - particle['vy'] * 3
                pygame.draw.line(screen, color,
                               (int(particle['x']), int(particle['y'])),
                               (int(end_x), int(end_y)), max(1, int(size)))
                
            elif p_type == 'shockwave':
                # 충격파 (확장하는 원)
                alpha = int(150 * (particle['life'] / 20))
                size = particle.get('size', 10)
                color = (*particle['color'][:3], alpha)
                
                # 여러 겹의 원으로 충격파 효과
                pygame.draw.circle(screen, color,
                                 (int(particle['x']), int(particle['y'])),
                                 int(size), max(1, 3 - int(size/20)))
                
                # 내부 밝은 원
                if size > 15:
                    pygame.draw.circle(screen, (*WHITE, alpha//2),
                                     (int(particle['x']), int(particle['y'])),
                                     int(size * 0.7), 1)
                
            elif p_type == 'pressure':
                # 압력 파티클 (진동하는 점)
                alpha = int(180 * (particle['life'] / 8))
                size = particle.get('size', 3)
                color = (*particle['color'][:3], alpha)
                
                # 진동 효과
                vibrate_x = particle['x'] + random.uniform(-2, 2)
                vibrate_y = particle['y'] + random.uniform(-2, 2)
                pygame.draw.circle(screen, color,
                                 (int(vibrate_x), int(vibrate_y)),
                                 int(size))
                
            elif p_type == 'explosion':
                # 폭발 파티클 (빛나는 별)
                alpha = int(255 * (particle['life'] / 35))
                size = particle.get('size', 7)
                color = (*particle['color'][:3], alpha)
                
                # 별 모양 또는 빛나는 원
                if random.random() < 0.3:
                    self.draw_mini_star(screen, int(particle['x']), int(particle['y']),
                                      int(size), color)
                else:
                    # 빛나는 원
                    pygame.draw.circle(screen, color,
                                     (int(particle['x']), int(particle['y'])),
                                     int(size))
                    # 광채 효과
                    for i in range(1, 3):
                        glow_alpha = max(0, alpha - i * 60)
                        if glow_alpha > 0:
                            pygame.draw.circle(screen, (*color[:3], glow_alpha),
                                             (int(particle['x']), int(particle['y'])),
                                             int(size + i * 3), 1)
            
            elif p_type == 'speed_line':
                # 스피드 라인 효과 (뱉을 때)
                alpha = int(200 * (particle['life'] / 20))
                size = particle.get('size', 20)
                color = (*particle['color'][:3], alpha)
                angle = particle.get('angle', 0)
                
                # 선의 시작점과 끝점
                start_x = particle['x']
                start_y = particle['y']
                end_x = start_x - math.cos(angle) * size
                end_y = start_y - math.sin(angle) * size
                
                # 두께가 변하는 선
                for i in range(3):
                    line_alpha = max(0, alpha - i * 50)
                    if line_alpha > 0:
                        pygame.draw.line(screen, (*color[:3], line_alpha),
                                       (int(start_x), int(start_y)),
                                       (int(end_x), int(end_y)), 
                                       max(1, 4 - i))
            
            elif p_type == 'power_ring':
                # 파워 링 효과 (충격파)
                alpha = int(255 * (particle['life'] / 30))
                expansion = (30 - particle['life']) / 30
                size = particle.get('max_size', 150) * expansion
                color = (*particle['color'][:3], alpha)
                
                # 여러 겹의 링
                for i in range(3):
                    ring_alpha = max(0, alpha - i * 50)
                    ring_size = size - i * 10
                    if ring_alpha > 0 and ring_size > 0:
                        pygame.draw.circle(screen, (*color[:3], ring_alpha),
                                         (int(particle['x']), int(particle['y'])),
                                         int(ring_size), max(1, 5 - int(expansion * 4)))
            
            elif p_type == 'spit_splash':
                # 침 스플래시 효과
                alpha = int(150 * (particle['life'] / 25))
                size = particle.get('size', 4)
                color = (*particle['color'][:3], alpha)
                
                # 물방울 효과
                pygame.draw.circle(screen, color,
                                 (int(particle['x']), int(particle['y'])),
                                 int(size))
                # 하이라이트
                if size > 2:
                    pygame.draw.circle(screen, (*WHITE, alpha//2),
                                     (int(particle['x'] - size//3), 
                                      int(particle['y'] - size//3)),
                                     max(1, int(size//2)))
            
            else:
                # 기본 파티클 (별/하트)
                alpha = int(255 * (particle['life'] / 30))
                size = 3 + particle['life'] // 10
                color = (*particle['color'][:3], alpha)
                
                if random.random() < 0.5:
                    self.draw_mini_star(screen, int(particle['x']), int(particle['y']), 
                                      size, color)
                else:
                    self.draw_mini_heart(screen, int(particle['x']), int(particle['y']), 
                                       size, color)


# 테스트 코드
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 3 - 멘헤라 월드")
    clock = pygame.time.Clock()
    
    stage3 = Stage3MenheraWorld()
    
    running = True
    while running:
        dt = clock.tick(60)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 업데이트 (라운드 카운터 시뮬레이션)
        # R 키를 누르면 라운드 변경 시뮬레이션
        keys = pygame.key.get_pressed()
        if keys[pygame.K_r]:
            stage3.round_count += 1
        
        stage3.update(dt, stage3.round_count)
        
        # 그리기
        screen.fill((40, 30, 45))  # 어두운 배경
        stage3.draw(screen)
        
        pygame.display.flip()
    
    pygame.quit()