"""
스테이지 배경 로더 모듈
"""
import pygame
import math
import random
from core.constants import SCREEN_WIDTH, SCREEN_HEIGHT

class StageLoader:
    """스테이지 배경 로딩 및 생성 클래스"""
    
    def __init__(self):
        self.backgrounds = {}
        self.animated_backgrounds = {}
        
    def load_stage_background(self, stage_num):
        """스테이지 배경 로드 또는 생성"""
        try:
            # 파일에서 배경 로드 시도
            bg_path = f"stage{stage_num}_field.png"
            background = pygame.image.load(bg_path).convert()
            background = pygame.transform.scale(background, (SCREEN_WIDTH, SCREEN_HEIGHT))
            
            # 애니메이션 배경도 로드 시도
            if stage_num <= 5:
                from backgrounds import (
                    AnimatedBackground,
                    AnimatedBackgroundStage2,
                    AnimatedBackgroundStage3,
                    AnimatedBackgroundStage4,
                    AnimatedBackgroundStage5
                )
                
                animated_classes = {
                    1: AnimatedBackground,
                    2: AnimatedBackgroundStage2,
                    3: AnimatedBackgroundStage3,
                    4: AnimatedBackgroundStage4,
                    5: AnimatedBackgroundStage5
                }
                
                if stage_num in animated_classes:
                    animated_bg = animated_classes[stage_num](bg_path)
                    self.animated_backgrounds[stage_num] = animated_bg
                    
        except:
            # 파일이 없으면 프로시저럴 생성
            background = self._generate_stage_background(stage_num)
            self.animated_backgrounds[stage_num] = None
            
        self.backgrounds[stage_num] = background
        return background
    
    def _generate_stage_background(self, stage_num):
        """스테이지별 배경 프로시저럴 생성"""
        surface = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
        
        generators = {
            1: self._generate_cyber_background,
            2: self._generate_ocean_background,
            3: self._generate_neon_background,
            4: self._generate_golden_background,
            5: self._generate_lava_background,
            6: self._generate_space_background
        }
        
        if stage_num in generators:
            return generators[stage_num](surface)
        else:
            return self._generate_default_background(surface)
    
    def _generate_cyber_background(self, surface):
        """사이버펑크 스타일 배경 생성"""
        for y in range(SCREEN_HEIGHT):
            ratio = y / SCREEN_HEIGHT
            r = int(10 + ratio * 20)
            g = int(50 + ratio * 50)
            b = int(20 + ratio * 30)
            pygame.draw.line(surface, (r, g, b), (0, y), (SCREEN_WIDTH, y))
        
        # 격자 패턴
        for x in range(0, SCREEN_WIDTH, 40):
            pygame.draw.line(surface, (0, 150, 100, 50), (x, 0), (x, SCREEN_HEIGHT))
        for y in range(0, SCREEN_HEIGHT, 40):
            pygame.draw.line(surface, (0, 150, 100, 50), (0, y), (SCREEN_WIDTH, y))
        
        return surface
    
    def _generate_ocean_background(self, surface):
        """심해 테마 배경 생성"""
        for y in range(SCREEN_HEIGHT):
            ratio = y / SCREEN_HEIGHT
            r = int(5 + ratio * 15)
            g = int(10 + ratio * 30)
            b = int(40 + ratio * 60)
            pygame.draw.line(surface, (r, g, b), (0, y), (SCREEN_WIDTH, y))
        
        # 물결 패턴
        for y in range(0, SCREEN_HEIGHT, 30):
            wave_color = (0, 100, 200, 40)
            for x in range(SCREEN_WIDTH):
                wave_y = y + math.sin(x * 0.02) * 10
                if 0 <= wave_y < SCREEN_HEIGHT:
                    pygame.draw.circle(surface, wave_color, (x, int(wave_y)), 2)
        
        return surface
    
    def _generate_neon_background(self, surface):
        """네온 핑크 배경 생성"""
        for y in range(SCREEN_HEIGHT):
            ratio = y / SCREEN_HEIGHT
            r = int(80 + ratio * 40)
            g = int(10 + ratio * 30)
            b = int(80 + ratio * 40)
            pygame.draw.line(surface, (r, g, b), (0, y), (SCREEN_WIDTH, y))
        
        # 네온 그리드
        for x in range(0, SCREEN_WIDTH, 50):
            for y in range(0, SCREEN_HEIGHT, 50):
                pygame.draw.rect(surface, (255, 0, 128, 30), (x, y, 45, 45), 1)
        
        return surface
    
    def _generate_golden_background(self, surface):
        """황금 테마 배경 생성"""
        for y in range(SCREEN_HEIGHT):
            ratio = y / SCREEN_HEIGHT
            r = int(60 + ratio * 60)
            g = int(50 + ratio * 40)
            b = int(20 + ratio * 20)
            pygame.draw.line(surface, (r, g, b), (0, y), (SCREEN_WIDTH, y))
        
        # 육각형 패턴
        for x in range(0, SCREEN_WIDTH, 60):
            for y in range(0, SCREEN_HEIGHT, 52):
                points = []
                for i in range(6):
                    angle = math.radians(60 * i)
                    px = x + 25 * math.cos(angle)
                    py = y + 25 * math.sin(angle)
                    points.append((px, py))
                pygame.draw.polygon(surface, (255, 215, 0, 20), points, 1)
        
        return surface
    
    def _generate_lava_background(self, surface):
        """용암 테마 배경 생성"""
        for y in range(SCREEN_HEIGHT):
            ratio = y / SCREEN_HEIGHT
            r = int(100 + ratio * 55)
            g = int(20 + ratio * 20)
            b = int(0 + ratio * 10)
            pygame.draw.line(surface, (r, g, b), (0, y), (SCREEN_WIDTH, y))
        
        # 화염 효과
        for _ in range(30):
            flame_x = random.randint(0, SCREEN_WIDTH)
            flame_y = random.randint(SCREEN_HEIGHT//2, SCREEN_HEIGHT)
            flame_size = random.randint(20, 40)
            for i in range(flame_size, 0, -5):
                alpha = 50 - i
                color = (255, 100 - i*2, 0)
                pygame.draw.circle(surface, color, (flame_x, flame_y), i)
        
        return surface
    
    def _generate_space_background(self, surface):
        """우주/바다 배경 생성"""
        for y in range(SCREEN_HEIGHT):
            intensity = 1 - (y / SCREEN_HEIGHT) * 0.4
            red = int(20 * intensity)
            green = int(40 * intensity)
            blue = int(120 * intensity)
            pygame.draw.line(surface, (red, green, blue), (0, y), (SCREEN_WIDTH, y))
        
        return surface
    
    def _generate_default_background(self, surface):
        """기본 배경 생성"""
        surface.fill((20, 20, 40))
        return surface
    
    def get_background(self, stage_num):
        """캐싱된 배경 반환"""
        if stage_num not in self.backgrounds:
            self.load_stage_background(stage_num)
        return self.backgrounds[stage_num]
    
    def get_animated_background(self, stage_num):
        """애니메이션 배경 반환"""
        return self.animated_backgrounds.get(stage_num, None)