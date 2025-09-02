"""
대화창 및 결과창 시스템 모듈
- 게임 결과 화면
- 승리/패배 화면
- 스테이지 클리어 화면
- 아이템 획득 알림
- 각종 대화창 및 알림
"""

import pygame
import math
import random


class DialogSystem:
    """대화창 시스템 클래스"""
    
    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        
        # 폰트 초기화
        try:
            self.font_large = pygame.font.Font("NanumSquareEB.ttf", 48)
            self.font_medium = pygame.font.Font("NanumSquareB.ttf", 36)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 24)
            self.font_tiny = pygame.font.Font("NanumSquareR.ttf", 18)
        except:
            self.font_large = pygame.font.Font(None, 48)
            self.font_medium = pygame.font.Font(None, 36)
            self.font_small = pygame.font.Font(None, 24)
            self.font_tiny = pygame.font.Font(None, 18)
        
        # 색상 정의
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)
        self.RED = (255, 0, 0)
        self.GREEN = (0, 255, 0)
        self.BLUE = (0, 0, 255)
        self.YELLOW = (255, 255, 0)
        self.GOLD = (255, 215, 0)
        self.SILVER = (192, 192, 192)
        self.BRONZE = (205, 127, 50)
        
        # 대화창 애니메이션
        self.dialog_alpha = 0
        self.dialog_scale = 0
        
    def draw_panel_background(self, rect, color=(20, 20, 30), border_color=(100, 100, 255)):
        """패널 배경 그리기"""
        # 메인 패널
        pygame.draw.rect(self.screen, color, rect)
        pygame.draw.rect(self.screen, border_color, rect, 3)
        
        # 코너 장식
        corner_size = 10
        corners = [
            (rect.left, rect.top),
            (rect.right - corner_size, rect.top),
            (rect.left, rect.bottom - corner_size),
            (rect.right - corner_size, rect.bottom - corner_size)
        ]
        
        for x, y in corners:
            pygame.draw.rect(self.screen, border_color, 
                           (x, y, corner_size, corner_size))
            inner_color = tuple(min(255, c + 50) for c in border_color)
            pygame.draw.rect(self.screen, inner_color,
                           (x + 2, y + 2, corner_size - 4, corner_size - 4))
    
    def show_victory_screen(self, stage_number, score, rewards=None):
        """승리 화면 표시
        
        Args:
            stage_number: 클리어한 스테이지 번호
            score: 최종 점수
            rewards: 획득한 보상 딕셔너리
        
        Returns:
            str: 선택된 액션 ("next", "retry", "menu")
        """
        clock = pygame.time.Clock()
        animation_timer = 0
        selected = 0
        options = ["다음 스테이지", "다시 시도", "메인 메뉴"]
        actions = ["next", "retry", "menu"]
        
        # 별 파티클 효과
        stars = []
        for _ in range(50):
            stars.append({
                "x": random.randint(0, self.width),
                "y": random.randint(-self.height, 0),
                "speed": random.uniform(1, 3),
                "size": random.randint(1, 3),
                "twinkle": random.uniform(0, math.pi * 2)
            })
        
        while True:
            animation_timer += 1
            
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return "menu"
                
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_UP:
                        selected = (selected - 1) % len(options)
                    elif event.key == pygame.K_DOWN:
                        selected = (selected + 1) % len(options)
                    elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                        return actions[selected]
                    elif event.key == pygame.K_ESCAPE:
                        return "menu"
            
            # 배경 (어두운 그라데이션)
            for y in range(self.height):
                ratio = y / self.height
                color = (int(10 + ratio * 20), int(20 + ratio * 30), int(40 + ratio * 50))
                pygame.draw.line(self.screen, color, (0, y), (self.width, y))
            
            # 별 파티클 애니메이션
            for star in stars:
                star["y"] += star["speed"]
                star["twinkle"] += 0.1
                
                if star["y"] > self.height:
                    star["y"] = -20
                    star["x"] = random.randint(0, self.width)
                
                alpha = int(128 + 127 * math.sin(star["twinkle"]))
                color = (255, 255, 200, alpha)
                
                star_surf = pygame.Surface((star["size"]*2, star["size"]*2), pygame.SRCALPHA)
                pygame.draw.circle(star_surf, color, (star["size"], star["size"]), star["size"])
                self.screen.blit(star_surf, (star["x"], star["y"]))
            
            # 메인 패널
            panel_width = 500
            panel_height = 400
            panel_x = (self.width - panel_width) // 2
            panel_y = (self.height - panel_height) // 2
            panel_rect = pygame.Rect(panel_x, panel_y, panel_width, panel_height)
            
            self.draw_panel_background(panel_rect, border_color=self.GOLD)
            
            # VICTORY 텍스트 (애니메이션)
            victory_scale = 1 + 0.1 * math.sin(animation_timer * 0.1)
            victory_font = pygame.font.Font(None, int(64 * victory_scale))
            victory_text = victory_font.render("VICTORY!", True, self.GOLD)
            victory_rect = victory_text.get_rect(center=(self.width // 2, panel_y + 60))
            
            # 빛나는 효과
            for i in range(3):
                glow_surf = victory_font.render("VICTORY!", True, (255, 215, 0, 50 - i*15))
                glow_rect = glow_surf.get_rect(center=(self.width // 2, panel_y + 60))
                self.screen.blit(glow_surf, glow_rect.inflate(i*4, i*4))
            
            self.screen.blit(victory_text, victory_rect)
            
            # 스테이지 정보
            stage_text = f"Stage {stage_number} Clear!"
            stage_surf = self.font_medium.render(stage_text, True, self.WHITE)
            stage_rect = stage_surf.get_rect(center=(self.width // 2, panel_y + 120))
            self.screen.blit(stage_surf, stage_rect)
            
            # 점수
            score_text = f"Score: {score:,}"
            score_surf = self.font_small.render(score_text, True, self.YELLOW)
            score_rect = score_surf.get_rect(center=(self.width // 2, panel_y + 160))
            self.screen.blit(score_surf, score_rect)
            
            # 보상 표시
            if rewards:
                reward_y = panel_y + 200
                reward_text = "Rewards:"
                reward_surf = self.font_small.render(reward_text, True, self.WHITE)
                self.screen.blit(reward_surf, (panel_x + 50, reward_y))
                
                if "medals" in rewards:
                    medal_text = f"🏅 Medals: +{rewards['medals']}"
                    medal_surf = self.font_small.render(medal_text, True, self.GOLD)
                    self.screen.blit(medal_surf, (panel_x + 50, reward_y + 30))
                
                if "exp" in rewards:
                    exp_text = f"⭐ EXP: +{rewards['exp']}"
                    exp_surf = self.font_small.render(exp_text, True, self.GREEN)
                    self.screen.blit(exp_surf, (panel_x + 250, reward_y + 30))
            
            # 옵션 버튼들
            button_y = panel_y + 280
            for i, option in enumerate(options):
                button_x = panel_x + 50 + i * 150
                button_rect = pygame.Rect(button_x, button_y, 130, 40)
                
                if i == selected:
                    pygame.draw.rect(self.screen, self.GOLD, button_rect, 3)
                    button_color = self.GOLD
                else:
                    pygame.draw.rect(self.screen, self.WHITE, button_rect, 1)
                    button_color = self.WHITE
                
                option_surf = self.font_small.render(option, True, button_color)
                option_rect = option_surf.get_rect(center=button_rect.center)
                self.screen.blit(option_surf, option_rect)
            
            pygame.display.flip()
            clock.tick(60)
    
    def show_defeat_screen(self, stage_number, score):
        """패배 화면 표시
        
        Returns:
            str: 선택된 액션 ("retry", "menu")
        """
        clock = pygame.time.Clock()
        animation_timer = 0
        selected = 0
        options = ["다시 시도", "메인 메뉴"]
        actions = ["retry", "menu"]
        
        # 떨어지는 파티클 효과 (패배 분위기)
        particles = []
        for _ in range(30):
            particles.append({
                "x": random.randint(0, self.width),
                "y": random.randint(-self.height, 0),
                "speed": random.uniform(0.5, 2),
                "size": random.randint(2, 5),
                "color": random.choice([(100, 100, 100), (150, 50, 50), (50, 50, 150)])
            })
        
        while True:
            animation_timer += 1
            
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return "menu"
                
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_LEFT:
                        selected = (selected - 1) % len(options)
                    elif event.key == pygame.K_RIGHT:
                        selected = (selected + 1) % len(options)
                    elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                        return actions[selected]
                    elif event.key == pygame.K_ESCAPE:
                        return "menu"
            
            # 어두운 배경
            self.screen.fill((20, 20, 30))
            
            # 떨어지는 파티클
            for particle in particles:
                particle["y"] += particle["speed"]
                
                if particle["y"] > self.height:
                    particle["y"] = -20
                    particle["x"] = random.randint(0, self.width)
                
                pygame.draw.circle(self.screen, particle["color"], 
                                 (int(particle["x"]), int(particle["y"])), 
                                 particle["size"])
            
            # 메인 패널
            panel_width = 400
            panel_height = 300
            panel_x = (self.width - panel_width) // 2
            panel_y = (self.height - panel_height) // 2
            panel_rect = pygame.Rect(panel_x, panel_y, panel_width, panel_height)
            
            self.draw_panel_background(panel_rect, border_color=self.RED)
            
            # DEFEAT 텍스트
            defeat_text = self.font_large.render("DEFEAT", True, self.RED)
            defeat_rect = defeat_text.get_rect(center=(self.width // 2, panel_y + 60))
            
            # 흔들림 효과
            shake_x = random.randint(-2, 2) if animation_timer % 10 < 5 else 0
            defeat_rect.x += shake_x
            
            self.screen.blit(defeat_text, defeat_rect)
            
            # 스테이지 정보
            stage_text = f"Stage {stage_number} Failed"
            stage_surf = self.font_medium.render(stage_text, True, (200, 200, 200))
            stage_rect = stage_surf.get_rect(center=(self.width // 2, panel_y + 120))
            self.screen.blit(stage_surf, stage_rect)
            
            # 점수
            score_text = f"Final Score: {score:,}"
            score_surf = self.font_small.render(score_text, True, (150, 150, 150))
            score_rect = score_surf.get_rect(center=(self.width // 2, panel_y + 160))
            self.screen.blit(score_surf, score_rect)
            
            # 옵션 버튼들
            button_y = panel_y + 220
            button_spacing = 150
            start_x = (self.width - (len(options) - 1) * button_spacing) // 2
            
            for i, option in enumerate(options):
                button_x = start_x + i * button_spacing
                
                if i == selected:
                    color = self.YELLOW
                    # 선택 표시
                    select_rect = pygame.Rect(button_x - 70, button_y - 10, 140, 40)
                    pygame.draw.rect(self.screen, (255, 255, 0, 30), select_rect)
                    pygame.draw.rect(self.screen, self.YELLOW, select_rect, 2)
                else:
                    color = self.WHITE
                
                option_surf = self.font_small.render(option, True, color)
                option_rect = option_surf.get_rect(center=(button_x, button_y + 10))
                self.screen.blit(option_surf, option_rect)
            
            pygame.display.flip()
            clock.tick(60)
    
    def show_item_obtained(self, item_name, item_description="", duration=120):
        """아이템 획득 알림 표시
        
        Args:
            item_name: 아이템 이름
            item_description: 아이템 설명
            duration: 표시 시간 (프레임)
        """
        # 알림 박스 크기 및 위치
        box_width = 400
        box_height = 100
        box_x = (self.width - box_width) // 2
        box_y = 100
        
        # 애니메이션 (슬라이드 인)
        for frame in range(duration):
            # 배경 박스
            alpha = min(255, frame * 10)
            box_surf = pygame.Surface((box_width, box_height), pygame.SRCALPHA)
            box_surf.fill((20, 20, 30, alpha))
            
            # 테두리
            pygame.draw.rect(box_surf, self.GOLD, box_surf.get_rect(), 3)
            
            # 아이템 획득 텍스트
            title_text = "아이템 획득!"
            title_surf = self.font_small.render(title_text, True, self.GOLD)
            title_rect = title_surf.get_rect(centerx=box_width // 2, y=10)
            box_surf.blit(title_surf, title_rect)
            
            # 아이템 이름
            name_surf = self.font_medium.render(item_name, True, self.WHITE)
            name_rect = name_surf.get_rect(centerx=box_width // 2, y=35)
            box_surf.blit(name_surf, name_rect)
            
            # 설명 (있을 경우)
            if item_description:
                desc_surf = self.font_tiny.render(item_description, True, (200, 200, 200))
                desc_rect = desc_surf.get_rect(centerx=box_width // 2, y=70)
                box_surf.blit(desc_surf, desc_rect)
            
            # 화면에 그리기
            slide_offset = max(0, (20 - frame) * 5)
            self.screen.blit(box_surf, (box_x, box_y - slide_offset))
            
            yield  # 프레임별로 제어 반환
    
    def show_stage_intro(self, stage_number, stage_name, boss_name=""):
        """스테이지 인트로 화면
        
        Args:
            stage_number: 스테이지 번호
            stage_name: 스테이지 이름
            boss_name: 보스 이름
        
        Returns:
            bool: 스킵 여부
        """
        clock = pygame.time.Clock()
        animation_timer = 0
        fade_in = 0
        
        while animation_timer < 180:  # 3초
            animation_timer += 1
            fade_in = min(255, fade_in + 5)
            
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return True
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_SPACE or event.key == pygame.K_RETURN:
                        return False  # 스킵
            
            # 검은 배경
            self.screen.fill(self.BLACK)
            
            # 스테이지 번호 (큰 글씨)
            stage_text = f"STAGE {stage_number}"
            stage_font = pygame.font.Font(None, 72)
            stage_surf = stage_font.render(stage_text, True, self.WHITE)
            stage_surf.set_alpha(fade_in)
            stage_rect = stage_surf.get_rect(center=(self.width // 2, self.height // 2 - 50))
            self.screen.blit(stage_surf, stage_rect)
            
            # 스테이지 이름
            if animation_timer > 30:
                name_surf = self.font_medium.render(stage_name, True, self.YELLOW)
                name_surf.set_alpha(min(255, (animation_timer - 30) * 5))
                name_rect = name_surf.get_rect(center=(self.width // 2, self.height // 2 + 20))
                self.screen.blit(name_surf, name_rect)
            
            # 보스 이름
            if boss_name and animation_timer > 60:
                boss_text = f"Boss: {boss_name}"
                boss_surf = self.font_small.render(boss_text, True, self.RED)
                boss_surf.set_alpha(min(255, (animation_timer - 60) * 5))
                boss_rect = boss_surf.get_rect(center=(self.width // 2, self.height // 2 + 80))
                self.screen.blit(boss_surf, boss_rect)
            
            # 스킵 안내
            if animation_timer > 90:
                skip_text = "Press SPACE to skip"
                skip_surf = self.font_tiny.render(skip_text, True, (100, 100, 100))
                skip_surf.set_alpha(min(100, (animation_timer - 90) * 3))
                skip_rect = skip_surf.get_rect(center=(self.width // 2, self.height - 50))
                self.screen.blit(skip_surf, skip_rect)
            
            pygame.display.flip()
            clock.tick(60)
        
        return False
    
    def show_message(self, message, duration=60, position="center", color=None):
        """간단한 메시지 표시
        
        Args:
            message: 표시할 메시지
            duration: 표시 시간 (프레임)
            position: 위치 ("center", "top", "bottom")
            color: 텍스트 색상
        """
        if color is None:
            color = self.WHITE
        
        # 위치 설정
        if position == "center":
            y = self.height // 2
        elif position == "top":
            y = 100
        elif position == "bottom":
            y = self.height - 100
        else:
            y = self.height // 2
        
        # 메시지 렌더링
        text_surf = self.font_medium.render(message, True, color)
        text_rect = text_surf.get_rect(center=(self.width // 2, y))
        
        # 배경 박스
        padding = 20
        box_rect = text_rect.inflate(padding * 2, padding)
        box_surf = pygame.Surface((box_rect.width, box_rect.height), pygame.SRCALPHA)
        box_surf.fill((0, 0, 0, 180))
        
        # 표시
        for frame in range(duration):
            alpha = 255
            if frame < 10:  # 페이드 인
                alpha = frame * 25
            elif frame > duration - 10:  # 페이드 아웃
                alpha = (duration - frame) * 25
            
            box_surf.set_alpha(alpha)
            text_surf.set_alpha(alpha)
            
            self.screen.blit(box_surf, box_rect)
            self.screen.blit(text_surf, text_rect)
            
            yield  # 프레임별로 제어 반환


# 싱글톤 인스턴스
_dialog_system = None

def init_dialog_system(screen, width, height):
    """대화창 시스템 초기화"""
    global _dialog_system
    _dialog_system = DialogSystem(screen, width, height)
    return _dialog_system

# 호환성을 위한 래퍼 함수들
def show_victory_screen(screen, stage_number, score, rewards=None, width=600, height=750):
    """승리 화면 표시 (호환성 래퍼)"""
    global _dialog_system
    if _dialog_system is None:
        _dialog_system = DialogSystem(screen, width, height)
    return _dialog_system.show_victory_screen(stage_number, score, rewards)

def show_result(screen, won, stage_number=1, score=0, width=600, height=750):
    """게임 결과 화면 표시 (호환성 래퍼)"""
    global _dialog_system
    if _dialog_system is None:
        _dialog_system = DialogSystem(screen, width, height)
    
    if won:
        return _dialog_system.show_victory_screen(stage_number, score)
    else:
        return _dialog_system.show_defeat_screen(stage_number, score)