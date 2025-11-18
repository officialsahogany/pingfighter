"""
메뉴 시스템 모듈
- 메인 메뉴
- 캐릭터 선택
- 난이도 선택
- 일시정지 메뉴
- 기타 게임 내 메뉴
"""

import pygame
import random
import math
import sys

# 게임 모듈 임포트 (필요시 bosspong.py에서 전달받음)
import items
import academy
import cinematic
import ui_manager
import gacha
import option as option_module


class MenuSystem:
    """메뉴 시스템 클래스"""
    
    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        
        # 폰트 초기화
        try:
            self.font_large = pygame.font.Font("NanumSquareEB.ttf", 48)
            self.font_medium = pygame.font.Font("NanumSquareB.ttf", 36)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 24)
        except:
            self.font_large = pygame.font.Font(None, 48)
            self.font_medium = pygame.font.Font(None, 36)
            self.font_small = pygame.font.Font(None, 24)
        
        # 색상 정의
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)
        self.RED = (255, 0, 0)
        self.GREEN = (0, 255, 0)
        self.BLUE = (0, 0, 255)
        self.YELLOW = (255, 255, 0)
        self.CYAN = (0, 255, 255)
        self.MAGENTA = (255, 0, 255)
        
        # 메뉴 상태
        self.selected_index = 0
        self.menu_active = False
        
        # 애니메이션 변수
        self.animation_timer = 0
        self.particles = []
        
    def draw_gradient_background(self, color1=(10, 20, 40), color2=(40, 60, 100)):
        """그라데이션 배경 그리기"""
        for y in range(self.height):
            ratio = y / self.height
            r = int(color1[0] + ratio * (color2[0] - color1[0]))
            g = int(color1[1] + ratio * (color2[1] - color1[1]))
            b = int(color1[2] + ratio * (color2[2] - color1[2]))
            pygame.draw.line(self.screen, (r, g, b), (0, y), (self.width, y))
    
    def draw_cyberpunk_particles(self):
        """사이버펑크 스타일 파티클 효과"""
        # 파티클 생성
        if len(self.particles) < 20 and random.random() < 0.3:
            self.particles.append({
                "x": random.randint(0, self.width),
                "y": random.randint(0, self.height),
                "vx": random.uniform(-1, 1),
                "vy": random.uniform(-1, 1),
                "size": random.randint(1, 3),
                "color": random.choice([self.CYAN, self.MAGENTA, self.YELLOW]),
                "alpha": 255,
                "fade": random.uniform(2, 5)
            })
        
        # 파티클 업데이트 및 그리기
        for particle in self.particles[:]:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["alpha"] -= particle["fade"]
            
            if particle["alpha"] > 0:
                color = (*particle["color"], int(particle["alpha"]))
                surf = pygame.Surface((particle["size"]*2, particle["size"]*2), pygame.SRCALPHA)
                pygame.draw.circle(surf, color, (particle["size"], particle["size"]), particle["size"])
                self.screen.blit(surf, (particle["x"], particle["y"]))
            else:
                self.particles.remove(particle)
    
    def draw_menu_option(self, text, x, y, selected=False, locked=False):
        """메뉴 옵션 그리기"""
        if locked:
            color = (100, 100, 100)
            text += " 🔒"
        elif selected:
            # 선택된 옵션 - 홀로그램 효과
            color = self.CYAN
            # 글리치 효과
            if random.random() < 0.1:
                offset = random.randint(-2, 2)
                ghost_color = (255, 0, 128, 100)
                ghost_surf = self.font_medium.render(text, True, ghost_color)
                self.screen.blit(ghost_surf, (x + offset, y))
        else:
            color = self.WHITE
        
        # 텍스트 렌더링
        text_surf = self.font_medium.render(text, True, color)
        text_rect = text_surf.get_rect(center=(x, y))
        
        if selected:
            # 선택 하이라이트 박스
            padding = 20
            box_rect = text_rect.inflate(padding*2, padding)
            
            # 네온 테두리 효과
            for i in range(3):
                alpha = 100 - i * 30
                width = 3 - i
                color_with_alpha = (*self.CYAN, alpha)
                pygame.draw.rect(self.screen, color_with_alpha, box_rect.inflate(i*4, i*4), width)
        
        self.screen.blit(text_surf, text_rect)
        
        return text_rect
    
    def show_start_screen(self, game_state=None):
        """메인 메뉴 표시
        
        Returns:
            str: 선택된 메뉴 옵션 ("start", "boss_battle", "medal_shop", "options", "quit")
            None: 메뉴가 아직 활성화 중
        """
        menu_options = ["경기시작", "NEW BOSS BATTLE", "메달샵", "옵션", "게임종료"]
        menu_actions = ["start", "boss_battle", "medal_shop", "options", "quit"]
        
        clock = pygame.time.Clock()
        selected = 0
        idle_timer = 0
        
        while True:
            self.animation_timer += 1
            idle_timer += 1
            
            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return "quit"
                
                if event.type == pygame.KEYDOWN:
                    idle_timer = 0  # 입력시 타이머 리셋
                    
                    if event.key == pygame.K_UP:
                        selected = (selected - 1) % len(menu_options)
                    elif event.key == pygame.K_DOWN:
                        selected = (selected + 1) % len(menu_options)
                    elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                        return menu_actions[selected]
                    elif event.key == pygame.K_ESCAPE:
                        return "quit"
            
            # 배경 그리기
            self.draw_gradient_background()
            self.draw_cyberpunk_particles()
            
            # 타이틀
            title_text = "BOSS PONG"
            title_surf = self.font_large.render(title_text, True, self.YELLOW)
            title_rect = title_surf.get_rect(center=(self.width//2, 150))
            
            # 타이틀 네온 효과
            glow_surf = self.font_large.render(title_text, True, (255, 255, 100, 50))
            for i in range(3):
                offset = math.sin(self.animation_timer * 0.05 + i) * 2
                self.screen.blit(glow_surf, (title_rect.x + offset, title_rect.y))
            
            self.screen.blit(title_surf, title_rect)
            
            # 메뉴 옵션들
            menu_y = 300
            for i, option in enumerate(menu_options):
                y_pos = menu_y + i * 60
                self.draw_menu_option(option, self.width//2, y_pos, selected=(i == selected))
            
            # 15초 후 시네마틱 재생
            if idle_timer > 15 * 60:  # 60 FPS 기준
                if game_state and hasattr(cinematic, 'show_cinematic_scenes'):
                    cinematic.show_cinematic_scenes(self.screen, self.width, self.height)
                idle_timer = 0
            
            pygame.display.flip()
            clock.tick(60)
    
    def show_character_selection(self):
        """캐릭터 선택 화면

        Returns:
            str: 선택된 캐릭터 ("ufo", "eagle", "back")
        """
        characters = [
            {"name": "UFO", "id": "ufo", "color": self.CYAN},
            {"name": "EAGLE", "id": "eagle", "color": self.YELLOW}
        ]
        
        selected = 0
        clock = pygame.time.Clock()
        
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_LEFT:
                        selected = (selected - 1) % len(characters)
                    elif event.key == pygame.K_RIGHT:
                        selected = (selected + 1) % len(characters)
                    elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                        return characters[selected]["id"]
                    elif event.key == pygame.K_ESCAPE:
                        return "back"
                elif event.type == pygame.MOUSEWHEEL:
                    # 휠 위=이전, 아래=다음 + 수평 스크롤 지원
                    if getattr(event, 'x', 0) > 0 or event.y < 0:
                        selected = (selected + 1) % len(characters)
                    elif getattr(event, 'x', 0) < 0 or event.y > 0:
                        selected = (selected - 1) % len(characters)
                elif event.type == pygame.MOUSEBUTTONDOWN:
                    # 레거시 휠(버튼 4/5)도 지원
                    if event.button == 4:
                        selected = (selected - 1) % len(characters)
                    elif event.button == 5:
                        selected = (selected + 1) % len(characters)
            
            # 배경
            self.draw_gradient_background((20, 10, 40), (60, 30, 80))
            
            # 타이틀
            title_surf = self.font_large.render("캐릭터 선택", True, self.WHITE)
            title_rect = title_surf.get_rect(center=(self.width//2, 100))
            self.screen.blit(title_surf, title_rect)
            
            # 캐릭터 카드들
            card_width = 200
            card_height = 300
            spacing = 50
            total_width = len(characters) * card_width + (len(characters) - 1) * spacing
            start_x = (self.width - total_width) // 2
            
            for i, char in enumerate(characters):
                x = start_x + i * (card_width + spacing)
                y = 200
                
                # 카드 배경
                card_rect = pygame.Rect(x, y, card_width, card_height)
                
                if i == selected:
                    # 선택된 카드 - 빛나는 테두리
                    for j in range(3):
                        alpha = 150 - j * 50
                        width = 5 - j
                        pygame.draw.rect(self.screen, (*char["color"], alpha), 
                                       card_rect.inflate(j*10, j*10), width)
                    pygame.draw.rect(self.screen, char["color"], card_rect, 3)
                else:
                    pygame.draw.rect(self.screen, (100, 100, 100), card_rect, 2)
                
                # 캐릭터 이미지 자리 (실제 이미지가 있다면 여기에 표시)
                pygame.draw.circle(self.screen, char["color"], 
                                 (x + card_width//2, y + card_height//2), 50)
                
                # 캐릭터 이름
                name_surf = self.font_medium.render(char["name"], True, self.WHITE)
                name_rect = name_surf.get_rect(center=(x + card_width//2, y + card_height - 40))
                self.screen.blit(name_surf, name_rect)
            
            # 안내 텍스트
            help_text = "← → 선택   ENTER 확인   ESC 뒤로"
            help_surf = self.font_small.render(help_text, True, (200, 200, 200))
            help_rect = help_surf.get_rect(center=(self.width//2, self.height - 50))
            self.screen.blit(help_surf, help_rect)
            
            pygame.display.flip()
            clock.tick(60)
            self.animation_timer += 1
    
    def show_pause_menu(self):
        """일시정지 메뉴
        
        Returns:
            str: 선택된 옵션 ("resume", "restart", "quit")
        """
        options = ["계속하기", "재시작", "메인메뉴"]
        actions = ["resume", "restart", "quit"]
        selected = 0
        
        # 현재 화면을 어둡게 만들기 위한 오버레이
        overlay = pygame.Surface((self.width, self.height))
        overlay.set_alpha(180)
        overlay.fill(self.BLACK)
        
        clock = pygame.time.Clock()
        
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return "quit"
                
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_UP:
                        selected = (selected - 1) % len(options)
                    elif event.key == pygame.K_DOWN:
                        selected = (selected + 1) % len(options)
                    elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                        return actions[selected]
                    elif event.key == pygame.K_ESCAPE or event.key == pygame.K_p:
                        return "resume"
            
            # 어두운 오버레이
            self.screen.blit(overlay, (0, 0))
            
            # 일시정지 박스
            box_width = 400
            box_height = 300
            box_x = (self.width - box_width) // 2
            box_y = (self.height - box_height) // 2
            
            # 박스 배경
            box_rect = pygame.Rect(box_x, box_y, box_width, box_height)
            pygame.draw.rect(self.screen, (20, 20, 30), box_rect)
            pygame.draw.rect(self.screen, self.CYAN, box_rect, 3)
            
            # 타이틀
            title_surf = self.font_medium.render("일시정지", True, self.WHITE)
            title_rect = title_surf.get_rect(center=(self.width//2, box_y + 50))
            self.screen.blit(title_surf, title_rect)
            
            # 옵션들
            for i, option in enumerate(options):
                y_pos = box_y + 120 + i * 50
                color = self.CYAN if i == selected else self.WHITE
                
                if i == selected:
                    # 선택 표시
                    select_rect = pygame.Rect(box_x + 50, y_pos - 20, box_width - 100, 40)
                    pygame.draw.rect(self.screen, (*self.CYAN, 30), select_rect)
                    pygame.draw.rect(self.screen, self.CYAN, select_rect, 1)
                
                option_surf = self.font_small.render(option, True, color)
                option_rect = option_surf.get_rect(center=(self.width//2, y_pos))
                self.screen.blit(option_surf, option_rect)
            
            pygame.display.flip()
            clock.tick(60)


# 기존 bosspong.py와의 호환성을 위한 래퍼 함수들
_menu_system = None

def init_menu_system(screen, width, height):
    """메뉴 시스템 초기화"""
    global _menu_system
    _menu_system = MenuSystem(screen, width, height)
    return _menu_system

def show_start_screen(screen=None, width=600, height=750, game_state=None):
    """메인 메뉴 표시 (호환성 래퍼)"""
    global _menu_system
    if _menu_system is None:
        _menu_system = MenuSystem(screen, width, height)
    return _menu_system.show_start_screen(game_state)

def show_character_selection(screen=None, width=600, height=750):
    """캐릭터 선택 화면 (호환성 래퍼)"""
    global _menu_system
    if _menu_system is None:
        _menu_system = MenuSystem(screen, width, height)
    return _menu_system.show_character_selection()

def show_pause_menu(screen=None, width=600, height=750):
    """일시정지 메뉴 (호환성 래퍼)"""
    global _menu_system
    if _menu_system is None:
        _menu_system = MenuSystem(screen, width, height)
    return _menu_system.show_pause_menu()
