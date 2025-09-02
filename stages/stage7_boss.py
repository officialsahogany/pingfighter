"""
Stage 7: 암흑 대마왕 (Dark Overlord)
최종 보스 이후의 숨겨진 보스!
"""

import pygame
import random
import math

class Stage7Boss:
    """Stage 7 - 암흑 대마왕"""
    
    def __init__(self):
        self.name = "암흑 대마왕"
        self.max_health = 1500  # Stage 6보다 더 강함
        self.current_health = 1500
        self.phase = 1  # 1~3 페이즈
        self.x = 300
        self.y = 100
        self.width = 200
        self.height = 80
        self.rect = pygame.Rect(self.x - self.width//2, self.y - self.height//2, self.width, self.height)
        
        # 특수 패턴들
        self.patterns = {
            1: ["dark_wave", "shadow_clone", "teleport"],
            2: ["void_cannon", "black_hole", "meteor_shower"],
            3: ["ultimate_darkness", "time_stop", "dimension_slash"]
        }
        self.current_pattern = 0
        self.pattern_timer = 0
        
        # 특수 능력 관련
        self.shadow_clones = []
        self.black_holes = []
        self.void_cannons = []
        self.meteors = []
        self.darkness_level = 0  # 화면 어두워지는 효과
        self.time_stopped = False
        self.time_stop_duration = 0
        
    def update(self, ball_rect, player_rect, frame_counter):
        """보스 업데이트"""
        # 페이즈 체크
        health_ratio = self.current_health / self.max_health
        if health_ratio <= 0.33:
            self.phase = 3
        elif health_ratio <= 0.66:
            self.phase = 2
        else:
            self.phase = 1
            
        # 패턴 실행
        if self.pattern_timer <= 0:
            self.execute_pattern(ball_rect, player_rect, frame_counter)
            self.pattern_timer = 180  # 3초마다 패턴 변경
        else:
            self.pattern_timer -= 1
            
        # 특수 효과 업데이트
        self.update_special_effects(ball_rect, player_rect)
        
        # 보스 이동 (페이즈에 따라 속도 증가)
        speed = 2 + self.phase
        self.x += math.sin(frame_counter * 0.02) * speed
        self.x = max(100, min(500, self.x))
        self.rect.x = self.x - self.width // 2
        
    def execute_pattern(self, ball_rect, player_rect, frame_counter):
        """패턴 실행"""
        patterns = self.patterns[self.phase]
        pattern = random.choice(patterns)
        
        if pattern == "dark_wave":
            self.create_dark_wave()
        elif pattern == "shadow_clone":
            self.create_shadow_clones()
        elif pattern == "teleport":
            self.teleport()
        elif pattern == "void_cannon":
            self.fire_void_cannon(player_rect)
        elif pattern == "black_hole":
            self.create_black_hole()
        elif pattern == "meteor_shower":
            self.summon_meteors()
        elif pattern == "ultimate_darkness":
            self.ultimate_darkness()
        elif pattern == "time_stop":
            self.activate_time_stop()
        elif pattern == "dimension_slash":
            self.dimension_slash(player_rect)
            
    def create_dark_wave(self):
        """암흑 파동 생성"""
        # 보스 위치에서 전방향으로 퍼지는 검은 파동
        return {
            'type': 'dark_wave',
            'x': self.x,
            'y': self.y,
            'radius': 0,
            'max_radius': 400,
            'damage': 20
        }
        
    def create_shadow_clones(self):
        """그림자 분신 생성"""
        for i in range(3):
            clone = {
                'x': random.randint(100, 500),
                'y': random.randint(50, 150),
                'width': 150,
                'height': 60,
                'alpha': 128,
                'lifetime': 300
            }
            self.shadow_clones.append(clone)
            
    def teleport(self):
        """순간이동"""
        self.x = random.randint(100, 500)
        self.y = random.randint(50, 150)
        return {'type': 'teleport_effect', 'x': self.x, 'y': self.y}
        
    def fire_void_cannon(self, player_rect):
        """공허 캐논 발사"""
        angle = math.atan2(player_rect.centery - self.y, player_rect.centerx - self.x)
        cannon = {
            'x': self.x,
            'y': self.y,
            'angle': angle,
            'speed': 8,
            'width': 30,
            'damage': 50
        }
        self.void_cannons.append(cannon)
        
    def create_black_hole(self):
        """블랙홀 생성"""
        hole = {
            'x': random.randint(100, 500),
            'y': random.randint(200, 500),
            'radius': 50,
            'pull_force': 5,
            'lifetime': 600  # 10초
        }
        self.black_holes.append(hole)
        
    def summon_meteors(self):
        """운석 소환"""
        for _ in range(5):
            meteor = {
                'x': random.randint(50, 550),
                'y': -50,
                'speed': random.uniform(3, 6),
                'size': random.randint(20, 40),
                'angle': random.uniform(-0.2, 0.2)
            }
            self.meteors.append(meteor)
            
    def ultimate_darkness(self):
        """궁극의 어둠"""
        self.darkness_level = min(200, self.darkness_level + 50)
        return {'type': 'screen_darkness', 'level': self.darkness_level}
        
    def activate_time_stop(self):
        """시간 정지"""
        self.time_stopped = True
        self.time_stop_duration = 180  # 3초
        return {'type': 'time_stop', 'duration': self.time_stop_duration}
        
    def dimension_slash(self, player_rect):
        """차원 베기"""
        # 플레이어 방향으로 거대한 베기
        return {
            'type': 'dimension_slash',
            'start_x': self.x,
            'start_y': self.y,
            'end_x': player_rect.centerx,
            'end_y': player_rect.centery,
            'width': 20,
            'damage': 100
        }
        
    def update_special_effects(self, ball_rect, player_rect):
        """특수 효과 업데이트"""
        # 그림자 분신 업데이트
        for clone in self.shadow_clones[:]:
            clone['lifetime'] -= 1
            if clone['lifetime'] <= 0:
                self.shadow_clones.remove(clone)
                
        # 블랙홀 업데이트 (공을 끌어당김)
        for hole in self.black_holes[:]:
            hole['lifetime'] -= 1
            if hole['lifetime'] <= 0:
                self.black_holes.remove(hole)
            else:
                # 공을 블랙홀로 끌어당기는 효과
                dx = hole['x'] - ball_rect.centerx
                dy = hole['y'] - ball_rect.centery
                dist = math.sqrt(dx**2 + dy**2)
                if dist > 0 and dist < hole['radius'] * 3:
                    pull_strength = hole['pull_force'] * (1 - dist / (hole['radius'] * 3))
                    # bosspong.py의 공 속도에 영향을 줄 데이터 반환
                    return {'pull_x': dx/dist * pull_strength, 'pull_y': dy/dist * pull_strength}
                    
        # 운석 업데이트
        for meteor in self.meteors[:]:
            meteor['y'] += meteor['speed']
            meteor['x'] += meteor['angle'] * meteor['speed']
            if meteor['y'] > 800:
                self.meteors.remove(meteor)
                
        # 시간 정지 업데이트
        if self.time_stopped:
            self.time_stop_duration -= 1
            if self.time_stop_duration <= 0:
                self.time_stopped = False
                
        return None
        
    def draw(self, screen):
        """보스 그리기"""
        # 어둠 효과
        if self.darkness_level > 0:
            dark_surface = pygame.Surface((600, 750))
            dark_surface.set_alpha(self.darkness_level)
            dark_surface.fill((0, 0, 0))
            screen.blit(dark_surface, (0, 0))
            
        # 그림자 분신들
        for clone in self.shadow_clones:
            clone_surface = pygame.Surface((clone['width'], clone['height']))
            clone_surface.set_alpha(clone['alpha'])
            clone_surface.fill((50, 0, 50))
            screen.blit(clone_surface, (clone['x'] - clone['width']//2, clone['y'] - clone['height']//2))
            
        # 블랙홀들
        for hole in self.black_holes:
            # 블랙홀 중심
            pygame.draw.circle(screen, (0, 0, 0), (int(hole['x']), int(hole['y'])), hole['radius'])
            # 회전하는 고리
            for i in range(3):
                radius = hole['radius'] + i * 20
                pygame.draw.circle(screen, (100, 0, 100), (int(hole['x']), int(hole['y'])), radius, 2)
                
        # 운석들
        for meteor in self.meteors:
            # 운석 본체
            pygame.draw.circle(screen, (100, 50, 30), 
                             (int(meteor['x']), int(meteor['y'])), meteor['size'])
            # 불타는 효과
            pygame.draw.circle(screen, (255, 100, 0), 
                             (int(meteor['x']), int(meteor['y'] - meteor['size']//2)), 
                             meteor['size']//2)
            
        # 메인 보스
        # 페이즈별 색상
        colors = {
            1: (100, 0, 100),  # 보라색
            2: (150, 0, 50),   # 진한 붉은색
            3: (0, 0, 0)       # 검은색
        }
        boss_color = colors[self.phase]
        
        # 보스 본체
        pygame.draw.rect(screen, boss_color, self.rect)
        
        # 보스 눈 (빨간색으로 빛남)
        eye_glow = abs(math.sin(pygame.time.get_ticks() * 0.003)) * 255
        pygame.draw.circle(screen, (eye_glow, 0, 0), 
                         (self.x - 30, self.y), 10)
        pygame.draw.circle(screen, (eye_glow, 0, 0), 
                         (self.x + 30, self.y), 10)
        
        # 체력바
        bar_width = 400
        bar_height = 20
        bar_x = 100
        bar_y = 30
        
        # 체력바 배경
        pygame.draw.rect(screen, (50, 50, 50), 
                        (bar_x, bar_y, bar_width, bar_height))
        
        # 현재 체력
        health_ratio = self.current_health / self.max_health
        current_bar_width = int(bar_width * health_ratio)
        
        # 페이즈별 체력바 색상
        health_colors = {
            1: (150, 0, 150),
            2: (200, 0, 100),
            3: (255, 0, 0)
        }
        pygame.draw.rect(screen, health_colors[self.phase], 
                        (bar_x, bar_y, current_bar_width, bar_height))
        
        # 보스 이름과 페이즈
        font = pygame.font.Font("NanumSquareR.ttf", 25)
        name_text = font.render(f"{self.name} - Phase {self.phase}", True, (255, 255, 255))
        name_rect = name_text.get_rect(center=(300, 60))
        screen.blit(name_text, name_rect)
        
        # 시간 정지 효과
        if self.time_stopped:
            time_surface = pygame.Surface((600, 750))
            time_surface.set_alpha(100)
            time_surface.fill((0, 100, 200))
            screen.blit(time_surface, (0, 0))
            
            stop_font = pygame.font.Font("NanumSquareR.ttf", 50)
            stop_text = stop_font.render("TIME STOP!", True, (255, 255, 255))
            stop_rect = stop_text.get_rect(center=(300, 375))
            screen.blit(stop_text, stop_rect)

# Stage 7 배경
def load_stage7_background():
    """Stage 7 배경 로드 (또는 생성)"""
    background = pygame.Surface((600, 750))
    # 어두운 우주 배경
    background.fill((10, 0, 20))
    
    # 별들 추가
    for _ in range(100):
        x = random.randint(0, 600)
        y = random.randint(0, 750)
        size = random.randint(1, 3)
        brightness = random.randint(100, 255)
        pygame.draw.circle(background, (brightness, brightness, brightness), (x, y), size)
    
    return background

# bosspong.py와 연동하기 위한 인터페이스
def get_stage7_config():
    """Stage 7 설정 반환"""
    return {
        'stage_number': 7,
        'boss_class': Stage7Boss,
        'background': load_stage7_background(),
        'bgm': 'sounds/stage7_bgm.mp3',  # 나중에 추가
        'victory_bonus': 50000,
        'unlock_requirement': 'beat_stage_6_no_damage'  # Stage 6을 노데미지로 클리어
    }