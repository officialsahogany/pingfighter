# -*- coding: utf-8 -*-
"""
스테이지 6 배경: 바다 위 사이버펑크 스타디움
해상 플랫폼 경기장 - 바다 위 + 사이버펑크 + 스포츠 스타디움
"""

import pygame
import math
import random

# 화면 크기 - config에서 가져오기
try:
    from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH, SCREEN_HEIGHT
    PILLAR_OFFSET = PILLAR_UI_WIDTH  # 80px
    GAME_WIDTH = GAME_PLAY_WIDTH  # 600px
    HEIGHT = SCREEN_HEIGHT  # 750px
except ImportError:
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600
    HEIGHT = 750

class AnimatedBackgroundStage6:
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.time = 0
        
        # 색상 팔레트 (바다 위 + 하늘)
        self.sky_blue = (135, 206, 235)  # 하늘색
        self.horizon_color = (255, 200, 150)  # 수평선 노을색
        self.ocean_surface = (0, 119, 190)  # 바다 표면
        self.ocean_deep = (0, 80, 140)  # 바다 깊은 부분
        self.wave_foam = (255, 255, 255)  # 파도 거품
        self.cyan_glow = (0, 200, 220)  # 네온 청록색
        self.arena_color = (0, 180, 200)  # 경기장 라인색
        
        # 파도 효과
        self.waves = []
        for i in range(5):
            self.waves.append({
                'y': height // 2 + i * 30,
                'amplitude': random.uniform(5, 15),
                'frequency': random.uniform(0.01, 0.03),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.02, 0.04)
            })
        
        # 구름
        self.clouds = []
        for _ in range(4):
            self.clouds.append({
                'x': random.randint(0, width),
                'y': random.randint(50, 200),
                'size': random.randint(40, 80),
                'speed': random.uniform(0.1, 0.3),
                'opacity': random.randint(30, 60)
            })
        
        # 경기장 중앙 원형 라인
        self.arena_center_x = width // 2
        self.arena_center_y = height // 2
        self.arena_radius = min(width, height) // 3
        
        # 불타는 스타디움 라인 애니메이션
        self.fire_line_particles = []  # 불꽃 파티클들
        self.fire_glow_phase = 0  # 불꽃 빛나는 애니메이션 위상
        self.center_circle_radius = 80  # 중앙 원 반지름
        self.stadium_line_y = 375  # 스타디움 가로 라인 y 위치 (중앙)
        self.fire_colors = [
            (255, 100, 50),   # 밝은 주황
            (255, 80, 30),    # 진한 주황
            (200, 60, 20),    # 붉은 주황
            (150, 40, 10),    # 어두운 빨강
        ]
        
    def update(self):
        self.time += 1
        self.fire_glow_phase += 0.05  # 불꽃 맥동 애니메이션
        
        # 파도 업데이트
        for wave in self.waves:
            wave['phase'] += wave['speed']
        
        # 구름 업데이트
        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.width + cloud['size']:
                cloud['x'] = -cloud['size']
                cloud['y'] = random.randint(50, 200)
        
        # 불타는 라인 파티클 업데이트
        self._update_fire_lines()
    
    def draw(self, screen):
        # 하늘 그라데이션 (위에서 아래로)
        for y in range(0, self.height // 2, 4):
            factor = y / (self.height // 2)
            # 하늘색에서 수평선 색으로 그라데이션
            color = (
                int(self.sky_blue[0] + (self.horizon_color[0] - self.sky_blue[0]) * factor),
                int(self.sky_blue[1] + (self.horizon_color[1] - self.sky_blue[1]) * factor),
                int(self.sky_blue[2] + (self.horizon_color[2] - self.sky_blue[2]) * factor)
            )
            pygame.draw.rect(screen, color, (0, y, self.width, 4))
        
        # 구름 그리기
        self._draw_clouds(screen)
        
        # 바다 그라데이션 (수평선 아래)
        for y in range(self.height // 2, self.height, 4):
            factor = (y - self.height // 2) / (self.height // 2)
            color = (
                int(self.ocean_surface[0] + (self.ocean_deep[0] - self.ocean_surface[0]) * factor),
                int(self.ocean_surface[1] + (self.ocean_deep[1] - self.ocean_surface[1]) * factor),
                int(self.ocean_surface[2] + (self.ocean_deep[2] - self.ocean_surface[2]) * factor)
            )
            pygame.draw.rect(screen, color, (0, y, self.width, 4))
        
        # 파도 그리기
        self._draw_waves(screen)
        
        # 수평선
        pygame.draw.line(screen, self.horizon_color, 
                        (0, self.height // 2), (self.width, self.height // 2), 2)
        
        # 경기장 플랫폼 (바다 위에 떠있는 느낌)
        self._draw_floating_platform(screen)
        
        # 불타는 스타디움 라인 그리기
        self._draw_fire_lines(screen)

        # 경기장 중앙 원형 라인 (비활성화됨)
        # self._draw_arena_circle(screen)

        # 테두리 (마지막에 그려서 위에 표시)
        self._draw_border(screen)

    def _draw_border(self, screen):
        """해상 사이버펑크 테마 테두리 그리기"""
        border_thickness = 10
        # SCREEN Surface 전체를 감싸는 테두리 (SCREEN은 이미 게임 전체 영역)
        x_off = 0
        game_w = self.width
        h = self.height

        # 기본 테두리 색상 (진한 청록색/해양색)
        base_color = (0, 60, 80)  # 어두운 바다색
        cyan_color = (0, 120, 150)  # 청록색
        glow_accent = (0, 200, 220)  # 네온 청록 악센트

        # 메인 테두리
        pygame.draw.rect(screen, base_color, (x_off, 0, game_w, border_thickness))
        pygame.draw.rect(screen, base_color, (x_off, h - border_thickness, game_w, border_thickness))
        pygame.draw.rect(screen, base_color, (x_off, 0, border_thickness, h))
        pygame.draw.rect(screen, base_color, (x_off + game_w - border_thickness, 0, border_thickness, h))

        # 내부 테두리 (깊이감)
        inner_thickness = 2
        pygame.draw.rect(screen, cyan_color,
                        (x_off + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(screen, cyan_color,
                        (x_off + border_thickness - inner_thickness, h - border_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(screen, cyan_color,
                        (x_off + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         inner_thickness, h - 2*(border_thickness - inner_thickness)))
        pygame.draw.rect(screen, cyan_color,
                        (x_off + game_w - border_thickness, border_thickness - inner_thickness,
                         inner_thickness, h - 2*(border_thickness - inner_thickness)))

        # 코너 장식 (네온 글로우)
        corner_radius = 5
        # 좌상단
        pygame.draw.circle(screen, glow_accent, (x_off + border_thickness//2, border_thickness//2), corner_radius)
        # 우상단
        pygame.draw.circle(screen, glow_accent, (x_off + game_w - border_thickness//2, border_thickness//2), corner_radius)
        # 좌하단
        pygame.draw.circle(screen, glow_accent, (x_off + border_thickness//2, h - border_thickness//2), corner_radius)
        # 우하단
        pygame.draw.circle(screen, glow_accent, (x_off + game_w - border_thickness//2, h - border_thickness//2), corner_radius)
    
    def _draw_arena_circle(self, screen):
        """중앙 경기장 원형 라인 그리기"""
        # 메인 원
        pygame.draw.circle(screen, self.arena_color, 
                         (self.arena_center_x, self.arena_center_y), 
                         self.arena_radius, 3)
        
        # 네온 글로우 효과
        glow_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        pygame.draw.circle(glow_surface, (*self.cyan_glow, 30), 
                         (self.arena_center_x, self.arena_center_y), 
                         self.arena_radius + 5, 2)
        screen.blit(glow_surface, (0, 0))
        
        # 중앙 십자선
        line_length = 40
        pygame.draw.line(screen, self.arena_color,
                        (self.arena_center_x - line_length, self.arena_center_y),
                        (self.arena_center_x + line_length, self.arena_center_y), 2)
        pygame.draw.line(screen, self.arena_color,
                        (self.arena_center_x, self.arena_center_y - line_length),
                        (self.arena_center_x, self.arena_center_y + line_length), 2)
    
    def _draw_clouds(self, screen):
        """구름 그리기"""
        for cloud in self.clouds:
            cloud_surface = pygame.Surface((cloud['size'] * 2, cloud['size']), pygame.SRCALPHA)
            # 구름 모양 (여러 원으로 구성)
            for i in range(3):
                x = cloud['size'] // 2 + i * cloud['size'] // 3
                y = cloud['size'] // 2
                radius = cloud['size'] // 3
                pygame.draw.circle(cloud_surface, (255, 255, 255, cloud['opacity']), 
                                 (x, y), radius)
            screen.blit(cloud_surface, (cloud['x'], cloud['y']))
    
    def _draw_waves(self, screen):
        """파도 그리기"""
        for wave in self.waves:
            wave_surface = pygame.Surface((self.width, 40), pygame.SRCALPHA)
            
            for x in range(0, self.width, 5):
                # 사인파 형태의 파도
                y = 20 + wave['amplitude'] * math.sin(x * wave['frequency'] + wave['phase'])
                
                # 파도 그리기
                pygame.draw.circle(wave_surface, (*self.ocean_surface, 40), 
                                 (x, int(y)), 8)
                
                # 파도 거품
                if random.random() < 0.1:
                    pygame.draw.circle(wave_surface, (*self.wave_foam, 60), 
                                     (x, int(y) - 5), 3)
            
            screen.blit(wave_surface, (0, wave['y']))
    
    def _draw_floating_platform(self, screen):
        """바다 위에 떠있는 플랫폼"""
        platform_y = self.height // 2 + 100
        
        # 플랫폼 그림자 (바다에 비치는)
        shadow_surface = pygame.Surface((self.width, 100), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surface, (0, 0, 0, 30), 
                          (self.width // 4, 20, self.width // 2, 60))
        screen.blit(shadow_surface, (0, platform_y + 20))
        
        # 플랫폼 본체
        platform_surface = pygame.Surface((self.width, 100), pygame.SRCALPHA)
        pygame.draw.rect(platform_surface, (80, 80, 100, 100), 
                        (self.width // 4, 30, self.width // 2, 40))
        pygame.draw.rect(platform_surface, self.cyan_glow, 
                        (self.width // 4, 30, self.width // 2, 40), 2)
        
        # 플랫폼 지지대
        for i in range(3):
            x = self.width // 4 + (self.width // 8) * (i + 1)
            pygame.draw.line(platform_surface, (60, 60, 80), 
                           (x, 70), (x, 90), 3)
        
        screen.blit(platform_surface, (0, platform_y))
    
    def _update_fire_lines(self):
        """불타는 라인 애니메이션 업데이트"""
        # 새로운 불꽃 파티클 생성 (원형 라인과 가로 라인에서)
        if random.random() < 0.3:  # 30% 확률로 생성
            # 중앙 원형 라인에서 불꽃 생성
            angle = random.uniform(0, math.pi * 2)
            x = self.width // 2 + math.cos(angle) * self.center_circle_radius
            y = self.stadium_line_y + math.sin(angle) * self.center_circle_radius
            self._create_fire_particle(x, y)
            
            # 가로 스타디움 라인에서 불꽃 생성
            if random.random() < 0.5:  # 점선 효과를 위해 50% 확률
                x = random.randint(50, self.width - 50)
                self._create_fire_particle(x, self.stadium_line_y)
        
        # 파티클 업데이트
        for particle in self.fire_line_particles[:]:
            particle['y'] -= particle['vy']  # 위로 올라감
            particle['x'] += particle['vx']  # 약간 좌우로 흔들림
            particle['life'] -= 1
            particle['size'] *= 0.95  # 점점 작아짐
            
            if particle['life'] <= 0 or particle['size'] < 0.5:
                self.fire_line_particles.remove(particle)
    
    def _create_fire_particle(self, x, y):
        """불꽃 파티클 생성"""
        if len(self.fire_line_particles) < 100:  # 최대 파티클 수 제한
            particle = {
                'x': x,
                'y': y,
                'vx': random.uniform(-0.5, 0.5),  # 좌우 속도
                'vy': random.uniform(0.5, 2.0),   # 위로 올라가는 속도
                'size': random.uniform(2, 4),
                'life': random.randint(20, 40),
                'color': random.choice(self.fire_colors),
                'glow': random.uniform(0.6, 1.0),
            }
            self.fire_line_particles.append(particle)
    
    def _draw_fire_lines(self, screen):
        """불타는 스타디움 라인 그리기"""
        # 불꽃 빛나기 효과 계산
        glow_intensity = (math.sin(self.fire_glow_phase) + 1) * 0.3 + 0.4  # 0.4 ~ 1.0
        
        # 중앙 원형 라인 (은은한 불꽃 효과)
        center_x = self.width // 2
        center_y = self.stadium_line_y
        
        # 여러 겹의 글로우 효과로 불타는 느낌
        for i in range(3):
            alpha = int(25 * glow_intensity * (1 - i * 0.3))
            radius = self.center_circle_radius + i * 2
            color = (200 + int(55 * glow_intensity), 
                    60 + int(40 * glow_intensity), 
                    20)
            
            # 글로우 서피스에 그리기
            glow_surface = pygame.Surface((radius * 2 + 20, radius * 2 + 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*color, alpha), 
                             (radius + 10, radius + 10), radius, 2 + i)
            screen.blit(glow_surface, (center_x - radius - 10, center_y - radius - 10))
        
        # 메인 원형 라인 (얇고 밝은 불꽃색)
        main_color = (255, int(100 + 50 * glow_intensity), 50)
        pygame.draw.circle(screen, main_color, (center_x, center_y), 
                          self.center_circle_radius, 1)
        
        # 가로 스타디움 라인 (점선 효과로 은은한 불꽃)
        line_start_x = 50
        line_end_x = self.width - 50
        dash_length = 20  # 점선 길이
        gap_length = 15  # 간격 길이
        
        # 점선 그리기
        current_x = line_start_x
        while current_x < line_end_x:
            dash_end = min(current_x + dash_length, line_end_x)
            
            # 여러 겹의 글로우 효과
            for i in range(2):
                alpha = int(20 * glow_intensity * (1 - i * 0.4))
                thickness = 1 + i
                color = (200 + int(55 * glow_intensity),
                        60 + int(40 * glow_intensity),
                        20)
                
                # 글로우 라인
                glow_surface = pygame.Surface((dash_length + 10, 10), pygame.SRCALPHA)
                pygame.draw.line(glow_surface, (*color, alpha),
                               (5, 5), (dash_length + 5, 5), thickness)
                screen.blit(glow_surface, (current_x - 5, self.stadium_line_y - 5))
            
            # 메인 점선 (얇고 밝은 불꽃색)
            pygame.draw.line(screen, main_color,
                            (current_x, self.stadium_line_y),
                            (dash_end, self.stadium_line_y), 1)
            
            current_x += dash_length + gap_length
        
        # 불꽃 파티클 그리기
        for particle in self.fire_line_particles:
            # 파티클 글로우 효과
            glow_alpha = int(particle['glow'] * particle['life'] * 1.5)
            if glow_alpha > 0:
                glow_size = particle['size'] * 1.5
                glow_surface = pygame.Surface((int(glow_size * 2), int(glow_size * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (*particle['color'], min(glow_alpha, 100)),
                                 (int(glow_size), int(glow_size)), int(glow_size))
                screen.blit(glow_surface, (particle['x'] - glow_size, particle['y'] - glow_size))
            
            # 파티클 본체
            pygame.draw.circle(screen, particle['color'],
                             (int(particle['x']), int(particle['y'])),
                             int(particle['size']))