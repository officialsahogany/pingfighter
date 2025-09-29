"""
show_character_selection 함수 - bosspong.py에서 추출
"""

import pygame
import math
import random
import sys
import os

# bosspong.py의 경로를 sys.path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 게임 상수 임포트
from config.constants import WIDTH, HEIGHT

# 전역 screen 객체 가져오기
def get_screen():
    return pygame.display.get_surface() or pygame.display.set_mode((WIDTH, HEIGHT))

# 사운드 초기화
def init_sounds():
    sounds = {}
    try:
        sounds['SOUND_BUTTON_CLICK'] = pygame.mixer.Sound("sounds/button_click.wav")
        sounds['SOUND_BUTTON_HOVER'] = pygame.mixer.Sound("sounds/button_hover.wav")
    except (FileNotFoundError, pygame.error):
        # 사운드 파일이 없을 경우 더미 사운드 객체 생성
        class DummySound:
            def play(self): pass
            def set_volume(self, vol): pass
        sounds['SOUND_BUTTON_CLICK'] = DummySound()
        sounds['SOUND_BUTTON_HOVER'] = DummySound()
    return sounds

def show_character_selection():
    """사이버펑크 스타일 홀로그램 캐릭터 선택 화면"""
    SCREEN = get_screen()
    sounds = init_sounds()
    SOUND_BUTTON_CLICK = sounds['SOUND_BUTTON_CLICK']
    SOUND_BUTTON_HOVER = sounds['SOUND_BUTTON_HOVER']
    clock = pygame.time.Clock()
    
    # 6개 캐릭터 정의 (해금 시스템 포함)
    characters = [
        {
            "id": "ufo_player",
            "name": "스매셔",
            "description": "게이지 폭발로 연속 파워스매시.\n공격 템포를 쥐는 핵심 스트라이커.",
            "image": "ufo_player.png",
            "stats": {"속도": 5, "파워": 5, "방어": 5},
            "special": "🌟 평범하지만 안정적인 플레이",
            "unlocked": True,
            "card_color": (0, 255, 255),  # 사이버 청록
            "glow_color": (0, 200, 255),
            "card_suit": "◆"
        },
        {
            "id": "speed_player",
            "name": "스피드 레이서",
            "description": "순간 가속과 체공 드리프트.\n스텝 페인트로 빈틈을 찌름.",
            "image": "speed_player.png",
            "stats": {"속도": 8, "파워": 3, "방어": 4},
            "special": "⚡ 고속 이동과 빠른 반응",
            "unlocked": False,
            "card_color": (255, 0, 128),  # 네온 핑크
            "glow_color": (255, 50, 150),
            "card_suit": "◆"
        },
        {
            "id": "power_player", 
            "name": "파워 스매셔",
            "description": "초중량 파워샷 한 방 역전.\n충돌 이후에도 압박 지속.",
            "image": "power_player.png",
            "stats": {"속도": 3, "파워": 8, "방어": 4},
            "special": "💪 강력한 스매싱과 파워샷",
            "unlocked": False,
            "card_color": (255, 128, 0),  # 네온 오렌지
            "glow_color": (255, 150, 50),
            "card_suit": "◆"
        },
        {
            "id": "defense_player",
            "name": "가디언",
            "description": "다층 방벽으로 라인 봉쇄.\n정밀 카운터로 역습 완성.",
            "image": "defense_player.png", 
            "stats": {"속도": 4, "파워": 3, "방어": 8},
            "special": "🛡️ 뛰어난 방어력과 카운터",
            "unlocked": False,
            "card_color": (128, 255, 0),  # 네온 그린
            "glow_color": (150, 255, 50),
            "card_suit": "◆"
        },
        {
            "id": "tech_player",
            "name": "테크 마스터",
            "description": "드론·트랩으로 리듬 해킹.\n상황별 버프로 멀티 컨트롤.",
            "image": "tech_player.png",
            "stats": {"속도": 6, "파워": 6, "방어": 3},
            "special": "🔧 특수 아이템과 기술력",
            "unlocked": False,
            "card_color": (128, 0, 255),  # 네온 퍼플
            "glow_color": (150, 50, 255),
            "card_suit": "◆"
        },
        {
            "id": "mystic_player",
            "name": "미스틱",
            "description": "시간 왜곡으로 타이밍 파괴.\n궤도 교란으로 패턴 전복.",
            "image": "mystic_player.png",
            "stats": {"속도": 7, "파워": 7, "방어": 1},
            "special": "🌟 예측 불가능한 특수 능력",
            "unlocked": False,
            "card_color": (255, 255, 0),  # 네온 옐로우
            "glow_color": (255, 255, 100),
            "card_suit": "◆"
        }
    ]
    
    selected = 0
    animation_timer = 0
    card_flip_timer = 0
    card_hover_offset = 0
    transition_progress = 0
    
    # 카드 이동 애니메이션 관련
    card_transition_active = False
    card_transition_progress = 0.0
    card_transition_duration = 45  # 더 부드러운 애니메이션
    previous_selected = 0
    
    # 카드 위치 저장용
    card_start_pos = (0, 0)
    card_target_pos = (0, 0)
    
    # 홀로그램 카드 관련 변수들
    card_width = 140  # 더 큰 카드
    card_height = 200
    
    # 선택된 카드는 더 크게
    selected_card_width = 160
    selected_card_height = 220
    
    # 부채꼴 카드들 위치 (하단, 더 넓은 배치)
    fan_radius = 320
    fan_angle_range = 120  # 더 넓은 부채꼴
    center_x = WIDTH // 2
    center_y = HEIGHT - 100
    
    # 홀로그램 카드 뒷면 패턴들 (사이버펑크 스타일)
    card_back_patterns = [
        {"color": (0, 20, 40), "pattern": "circuit", "accent": (0, 255, 255)},
        {"color": (40, 0, 20), "pattern": "matrix", "accent": (255, 0, 128)},
        {"color": (20, 40, 0), "pattern": "grid", "accent": (128, 255, 0)},
        {"color": (40, 30, 0), "pattern": "wave", "accent": (255, 128, 0)},
        {"color": (20, 0, 40), "pattern": "hex", "accent": (128, 0, 255)},
        {"color": (40, 40, 0), "pattern": "scan", "accent": (255, 255, 0)}
    ]
    
    # 사이버펑크 배경 효과용 변수들
    neon_particles = []
    for _ in range(50):  # 더 많은 네온 파티클
        neon_particles.append({
            "x": random.randint(0, WIDTH),
            "y": random.randint(0, HEIGHT),
            "vx": random.uniform(-1, 1),
            "vy": random.uniform(-1, 1),
            "size": random.randint(1, 3),
            "color": random.choice([(0, 255, 255), (255, 0, 255), (255, 255, 0)]),
            "alpha": random.randint(40, 100),
            "pulse_speed": random.uniform(0.05, 0.15)
        })
    
    # 스캔라인 효과
    scan_lines = []
    for i in range(5):  # 더 많은 스캔라인
        scan_lines.append({
            "y": random.randint(0, HEIGHT),
            "speed": random.uniform(2, 4),
            "alpha": random.randint(20, 40)
        })
    
    # 홀로그램 글리치 효과
    glitch_timer = 0
    glitch_active = False
    
    while True:
        animation_timer += 1
        card_flip_timer += 1
        glitch_timer += 1
        
        # 랜덤 글리치 효과 활성화
        if random.randint(0, 300) == 0:
            glitch_active = True
        if glitch_timer > 10:
            glitch_active = False
            glitch_timer = 0
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pass
                    return None  # 메인 메뉴로 돌아가기
                elif event.key in [pygame.K_LEFT, pygame.K_a]:
                    if not card_transition_active:
                        previous_selected = selected
                        selected = (selected - 1) % len(characters)
                        start_card_transition()
                        SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_RIGHT, pygame.K_d]:
                    if not card_transition_active:
                        previous_selected = selected
                        selected = (selected + 1) % len(characters)
                        start_card_transition()
                        SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_SPACE, pygame.K_RETURN]:
                    if characters[selected]["unlocked"]:
                        SOUND_BUTTON_CLICK.play()
                        return characters[selected]["id"]
                    else:
                        pass
                        # 해금 안된 캐릭터 선택 시 효과음 (선택 불가 사운드)
                        pass
        
        # 사이버펑크 배경 그리기 (그라데이션)
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            r = int(10 + ratio * 30)  # 더 밝은 빨강
            g = int(20 + ratio * 40)  # 더 밝은 초록
            b = int(40 + ratio * 60)  # 더 밝은 파랑
            color = (r, g, b)
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
        
        # 홀로그램 격자 패턴
        grid_color = (0, 150, 200, 25)
        grid_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        for x in range(0, WIDTH, 30):
            pygame.draw.line(grid_surface, grid_color, (x, 0), (x, HEIGHT))
        for y in range(0, HEIGHT, 30):
            pygame.draw.line(grid_surface, grid_color, (0, y), (WIDTH, y))
        SCREEN.blit(grid_surface, (0, 0))
        
        # 디지털 매트릭스 효과 (최소화)
        try:
            font_matrix = pygame.font.Font(None, 10)
        except:
            font_matrix = pygame.font.Font(None, 10)
        
        # 정적 매트릭스 배경 (매우 절제)
        for i in range(3):  # 열 수 대폭 감소
            x = 100 + i * 200  # 넓은 간격
            y = 150 + (i % 2) * 100  # 엇갈린 배치
            if random.random() < 0.1:  # 10% 확률로만 표시
                char = random.choice(["0", "1"])
                char_surface = font_matrix.render(char, True, (0, 60, 80))
                char_surface.set_alpha(20)  # 매우 희미하게
                SCREEN.blit(char_surface, (x, y))
        
        # 폰트 로드
        try:
            font_title = pygame.font.Font("NanumSquareB.ttf", 56)  # 더 큰 제목
            font_subtitle = pygame.font.Font("NanumSquareR.ttf", 28)
            font_desc = pygame.font.Font("NanumSquareR.ttf", 20)
            font_card = pygame.font.Font("NanumSquareB.ttf", 18)
            font_small = pygame.font.Font("NanumSquareR.ttf", 16)
        except:
            font_title = pygame.font.Font(None, 56)
            font_subtitle = pygame.font.Font(None, 28)
            font_desc = pygame.font.Font(None, 20)
            font_card = pygame.font.Font(None, 18)
            font_small = pygame.font.Font(None, 16)
        
        # 제목
        # 홀로그램 스타일 제목
        title_main = "◆ NEURAL SELECT PROTOCOL ◆"
        title_sub = ">> PILOT ACQUISITION SYSTEM <<"
        
        # 메인 제목 - 네온 글로우 효과
        title_y = 35
        
        # 글리치 효과 적용
        glitch_offset_x = 0
        glitch_offset_y = 0
        if glitch_active:
            glitch_offset_x = random.randint(-3, 3)
            glitch_offset_y = random.randint(-1, 1)
        
        # 네온 글로우 레이어들
        for i, (offset, color, alpha) in enumerate([(4, (0, 255, 255), 60), (2, (255, 0, 128), 120), (0, (255, 255, 255), 255)]):
            glow_text = font_title.render(title_main, True, (*color[:3], alpha))
            glow_rect = glow_text.get_rect(center=(WIDTH // 2 + offset + glitch_offset_x, title_y + glitch_offset_y))
            if alpha < 255:  # 글로우 레이어
                glow_surface = pygame.Surface(glow_text.get_size(), pygame.SRCALPHA)
                glow_surface.blit(glow_text, (0, 0))
                SCREEN.blit(glow_surface, glow_rect)
            else:  # 메인 텍스트
                SCREEN.blit(glow_text, glow_rect)
        
        # 서브 제목
        sub_text = font_subtitle.render(title_sub, True, (0, 255, 255))
        sub_rect = sub_text.get_rect(center=(WIDTH // 2, title_y + 45))
        SCREEN.blit(sub_text, sub_rect)
        
        # 타이핑 효과를 위한 커서 깜박이는 언더스코어
        if animation_timer % 60 < 30:  # 0.5초마다 깜박임
            cursor_surface = pygame.Surface((200, 3), pygame.SRCALPHA)
            pygame.draw.rect(cursor_surface, (0, 255, 255, 150), (0, 0, 200, 3))
            SCREEN.blit(cursor_surface, (WIDTH // 2 - 100, title_y + 55))
        
        # 애니메이션 관련 함수들
        def start_card_transition():
            nonlocal card_transition_active, card_transition_progress
            nonlocal card_start_pos, card_target_pos
            
            card_transition_active = True
            card_transition_progress = 0.0
            
            # 이전 카드의 중앙 위치 (시작점)
            card_start_pos = (WIDTH // 2 - card_width // 2, HEIGHT // 2 - card_height // 2)
            
            # 새 카드의 하단 부채꼴 위치 계산 (목표점)
            if len(characters) > 1:
                remaining_cards = len(characters) - 1
                if remaining_cards > 1:
                    angle_step = 90 / (remaining_cards - 1)  # fan_angle_range = 90
                    card_index = selected if selected < previous_selected else selected - 1
                    angle = -45 + card_index * angle_step  # -fan_angle_range/2
                else:
                    pass
                    angle = 0
            else:
                angle = 0
            
            angle_rad = math.radians(angle)
            target_x = center_x + math.sin(angle_rad) * 180 - card_width // 2  # fan_radius = 180
            target_y = center_y - math.cos(angle_rad) * 180 * 0.2 - card_height // 2
            card_target_pos = (target_x, target_y)
        
        def update_card_transition():
            nonlocal card_transition_active, card_transition_progress
            
            if card_transition_active:
                card_transition_progress += 1.0 / card_transition_duration
                if card_transition_progress >= 1.0:
                    card_transition_progress = 1.0
                    card_transition_active = False
        
        def get_transition_position(start_pos, target_pos, progress):
            # 이지-아웃 애니메이션 (부드러운 감속)
            eased_progress = 1 - (1 - progress) ** 3
            
            x = start_pos[0] + (target_pos[0] - start_pos[0]) * eased_progress
            y = start_pos[1] + (target_pos[1] - start_pos[1]) * eased_progress
            
            # 약간의 아치 효과 (카드가 위로 올라갔다 내려오는 느낌)
            arc_height = -30 * math.sin(progress * math.pi)
            y += arc_height
            
            return (x, y)
        
        # 애니메이션 업데이트
        update_card_transition()
        transition_progress = min(transition_progress + 0.1, 1.0)
        card_hover_offset = math.sin(animation_timer * 0.08) * 8
        
        # 포커 카드 렌더링 (애니메이션 적용)
        def draw_card_fan():
            # 애니메이션 중인 카드들 추적
            animated_cards = []
            
            # 1. 선택되지 않은 카드들을 하단 부채꼴로 그리기
            fan_angle_range = 90
            fan_radius = 180
            
            for i, character in enumerate(characters):
                is_selected = (i == selected)
                is_previous = (i == previous_selected)
                
                # 현재 애니메이션 중인지 확인
                if card_transition_active and (is_selected or is_previous):
                    animated_cards.append(i)
                    continue
                
                if not is_selected:
                    pass
                    # 선택되지 않은 카드들 - 하단 부채꼴 배치
                    if len(characters) > 1:
                        remaining_cards = len(characters) - 1
                        if remaining_cards > 1:
                            angle_step = fan_angle_range / (remaining_cards - 1)
                            card_index = i if i < selected else i - 1
                            angle = -fan_angle_range/2 + card_index * angle_step
                        else:
                            pass
                            angle = 0
                    else:
                        angle = 0
                    
                    angle_rad = math.radians(angle)
                    card_x = center_x + math.sin(angle_rad) * fan_radius - card_width // 2
                    card_y = center_y - math.cos(angle_rad) * fan_radius * 0.2 - card_height // 2
                    
                    # 뒷면으로 그리기
                    draw_character_card(character, card_x, card_y, angle, False, i, 
                                      card_width, card_height)
            
            # 2. 애니메이션 중이 아닌 선택된 카드를 중앙에 그리기
            if not card_transition_active:
                selected_char = characters[selected]
                selected_x = (WIDTH - card_width) // 2
                selected_y = HEIGHT // 2 - card_height // 2
                
                # 앞면으로 그리기
                draw_character_card(selected_char, selected_x, selected_y, 0, True, selected,
                                  card_width, card_height)
            
            # 3. 애니메이션 중인 카드들 그리기
            if card_transition_active:
                pass
                # 이전 카드 (중앙에서 하단으로 이동)
                if previous_selected < len(characters):
                    prev_char = characters[previous_selected]
                    transition_pos = get_transition_position(card_start_pos, card_target_pos, 
                                                           card_transition_progress)
                    
                    # 뒷면으로 그리기 (애니메이션 진행에 따라)
                    draw_character_card(prev_char, transition_pos[0], transition_pos[1], 0, 
                                      False, previous_selected, card_width, card_height)
                
                # 새 선택된 카드 (하단에서 중앙으로 이동)
                selected_char = characters[selected]
                
                # 새 카드의 시작 위치 (하단 부채꼴)
                if len(characters) > 1:
                    remaining_cards = len(characters) - 1
                    if remaining_cards > 1:
                        angle_step = 90 / (remaining_cards - 1)
                        card_index = selected if selected < previous_selected else selected - 1
                        angle = -45 + card_index * angle_step
                    else:
                        pass
                        angle = 0
                else:
                    angle = 0
                
                angle_rad = math.radians(angle)
                start_x = center_x + math.sin(angle_rad) * 180 - card_width // 2
                start_y = center_y - math.cos(angle_rad) * 180 * 0.2 - card_height // 2
                
                # 목표 위치 (중앙)
                target_x = WIDTH // 2 - card_width // 2
                target_y = HEIGHT // 2 - card_height // 2
                
                new_card_pos = get_transition_position((start_x, start_y), (target_x, target_y),
                                                     card_transition_progress)
                
                # 앞면으로 그리기
                draw_character_card(selected_char, new_card_pos[0], new_card_pos[1], 0, 
                                  True, selected, card_width, card_height)
        
        def draw_character_card(character, x, y, angle, is_selected, card_index, 
                               current_card_width=None, current_card_height=None):
            # 카드 크기 설정
            if current_card_width is None:
                current_card_width = card_width
            if current_card_height is None:
                current_card_height = card_height
                
            # 카드 표면 생성
            card_surface = pygame.Surface((current_card_width, current_card_height), pygame.SRCALPHA)
            
            # 카드 앞면/뒷면 로직 수정: 선택된 카드만 앞면, 나머지는 모두 뒷면
            if character["unlocked"] and is_selected:
                pass
                # 해금된 카드 중 선택된 것만 앞면
                draw_card_front(card_surface, character, is_selected, 
                              current_card_width, current_card_height)
            else:
                pass
                # 해금 안된 카드 또는 선택되지 않은 카드는 뒷면
                draw_card_back(card_surface, card_index, is_selected, 
                             current_card_width, current_card_height)
            
            # 카드 회전 및 배치
            if angle != 0:
                rotated_card = pygame.transform.rotate(card_surface, -angle)
                rotated_rect = rotated_card.get_rect(center=(x + current_card_width//2, y + current_card_height//2))
                SCREEN.blit(rotated_card, rotated_rect)
            else:
                SCREEN.blit(card_surface, (x, y))
        
        def draw_card_front(surface, character, is_selected, w, h):
            """홀로그램 스타일 카드 앞면 그리기"""
            border_color = character["card_color"] if is_selected else (150, 150, 150)
            glow_color = character.get("glow_color", border_color)
            
            # 홀로그램 글로우 효과 (다층 글로우)
            if is_selected:
                for glow_layer in range(5, 0, -1):
                    glow_intensity = int(abs(math.sin(animation_timer * 0.12 + glow_layer)) * 30) + 40
                    glow_size = glow_layer * 4
                    glow_surface = pygame.Surface((w + glow_size, h + glow_size), pygame.SRCALPHA)
                    pygame.draw.rect(glow_surface, (*glow_color, glow_intensity // glow_layer), 
                                   (0, 0, w + glow_size, h + glow_size), border_radius=20)
                    surface.blit(glow_surface, (-glow_size//2, -glow_size//2))
            
            # 홀로그램 카드 본체 (반투명 대신 어두운 배경)
            card_bg_color = (10, 15, 25, 220)  # 매우 어두운 반투명
            card_surface = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.rect(card_surface, card_bg_color, (0, 0, w, h), border_radius=15)
            surface.blit(card_surface, (0, 0))
            
            # 네온 테두리
            pygame.draw.rect(surface, border_color, (0, 0, w, h), 2, border_radius=15)
            
            # 내부 테두리 (네온 전자 회로 느낌)
            inner_border = 4
            pygame.draw.rect(surface, (*border_color, 100), 
                           (inner_border, inner_border, w - inner_border*2, h - inner_border*2), 
                           1, border_radius=12)
            
            # 카드 모서리 장식 (트럼프 카드 스타일)
            suit_color = border_color
            suit_size = max(16, min(24, w // 6))  # 카드 크기에 비례한 폰트 크기
            suit_font = pygame.font.Font(None, suit_size)
            suit_text = suit_font.render(character["card_suit"], True, suit_color)
            # 좌상단
            surface.blit(suit_text, (8, 8))
            # 우하단 (회전)
            rotated_suit = pygame.transform.rotate(suit_text, 180)
            surface.blit(rotated_suit, (w - suit_text.get_width() - 8, h - suit_text.get_height() - 8))
            
            # 캐릭터 이미지 영역
            image_size = min(w - 20, h // 3)  # 카드 크기에 비례
            try:
                pass  # Empty try block fix
#                 char_image = pygame.image.load(character["image"])
#                 char_image = pygame.transform.scale(char_image, (image_size, image_size))
                image_x = (w - image_size) // 2
                image_y = 30
                surface.blit(char_image, (image_x, image_y))
            except:
                # 이미지 로드 실패 시 대체 그래픽
                radius = image_size // 2
                pygame.draw.circle(surface, border_color, (w//2, 30 + radius), radius)
                pygame.draw.circle(surface, (255, 255, 255), (w//2, 30 + radius), radius - 5, 3)
            
            # 캐릭터 이름 (카드가 클 때만)
            if is_selected and w > 120:
                name_text = font_card.render(character["name"], True, (30, 30, 30))
                name_rect = name_text.get_rect(center=(w//2, 30 + image_size + 20))
                surface.blit(name_text, name_rect)
                
                # 간단한 스탯 표시 (선택된 카드일 때만)
                stats_y = 30 + image_size + 45
                for stat_name, stat_value in character["stats"].items():
                    stat_text = font_small.render(f"{stat_name}: {'★' * stat_value}", True, (60, 60, 60))
                    stat_rect = stat_text.get_rect(center=(w//2, stats_y))
                    surface.blit(stat_text, stat_rect)
                    stats_y += 15
        
        def draw_card_back(surface, card_index, is_selected, w, h):
            pattern = card_back_patterns[card_index % len(card_back_patterns)]
            base_color = pattern["color"]
            accent_color = pattern["accent"]
            
            # 선택 여부에 따른 색상 조정
            if is_selected:
                pass
                # 선택된 카드는 더 밝게
                base_color = tuple(min(255, c + 30) for c in base_color)
                accent_color = tuple(min(255, c + 50) for c in accent_color)
                
                # 글로우 효과
                glow_intensity = int(abs(math.sin(animation_timer * 0.15)) * 30) + 40
                glow_surface = pygame.Surface((w + 10, h + 10), pygame.SRCALPHA)
                pygame.draw.rect(glow_surface, (*accent_color, glow_intensity), 
                               (0, 0, w + 10, h + 10), border_radius=15)
                surface.blit(glow_surface, (-5, -5))
            else:
                pass
                # 선택되지 않은 카드는 더 어둡게
                base_color = tuple(max(20, c - 20) for c in base_color)
                accent_color = tuple(max(50, c - 30) for c in accent_color)
            
            # 카드 배경
            pygame.draw.rect(surface, base_color, (0, 0, w, h), border_radius=10)
            pygame.draw.rect(surface, accent_color, (0, 0, w, h), 3, border_radius=10)
            
            # 패턴 그리기
            draw_card_pattern(surface, pattern, w, h)
            
            # 물음표 또는 잠금 아이콘 (해금 여부에 따라)
            # characters 리스트에서 실제 해금 상태 확인
            character = characters[card_index] if card_index < len(characters) else None
            icon_size = max(16, min(32, w // 5))  # 카드 크기에 비례한 아이콘 크기
            icon_font = pygame.font.Font(None, icon_size)
            
            if character and not character["unlocked"]:
                pass
                # 해금 안된 카드는 잠금 아이콘
                lock_icon = icon_font.render("🔒", True, accent_color)
                lock_rect = lock_icon.get_rect(center=(w//2, h//2))
                surface.blit(lock_icon, lock_rect)
            else:
                pass
                # 해금된 카드는 물음표 (선택되지 않아서 뒷면)
                question_icon = icon_font.render("?", True, accent_color)
                question_rect = question_icon.get_rect(center=(w//2, h//2))
                surface.blit(question_icon, question_rect)
        
        def draw_card_pattern(surface, pattern, width, height):
            """사이버펑크 스타일 카드 패턴 그리기"""
            pattern_type = pattern["pattern"]
            color = pattern["accent"]
            
            # 카드 크기에 맞춘 패턴 간격 계산
            margin = 8
            pattern_width = width - 2 * margin
            pattern_height = height - 2 * margin
            
            # 사이버펑크 패턴별 그리기
            if pattern_type == "circuit":
                pass
                # 전자 회로 패턴
                # 가로선
                for y in range(margin, margin + pattern_height, 20):
                    alpha = int(abs(math.sin(animation_timer * 0.1 + y * 0.05)) * 100) + 50
                    line_color = (*color, alpha)
                    line_surface = pygame.Surface((pattern_width, 2), pygame.SRCALPHA)
                    pygame.draw.rect(line_surface, line_color, (0, 0, pattern_width, 2))
                    surface.blit(line_surface, (margin, y))
                
                # 세로선
                for x in range(margin, margin + pattern_width, 25):
                    alpha = int(abs(math.sin(animation_timer * 0.08 + x * 0.03)) * 80) + 40
                    line_color = (*color, alpha)
                    line_surface = pygame.Surface((2, pattern_height), pygame.SRCALPHA)
                    pygame.draw.rect(line_surface, line_color, (0, 0, 2, pattern_height))
                    surface.blit(line_surface, (x, margin))
                
                # 접점 노드
                for x in range(margin, margin + pattern_width, 25):
                    for y in range(margin, margin + pattern_height, 20):
                        node_alpha = int(abs(math.sin(animation_timer * 0.15 + x * 0.01 + y * 0.01)) * 150) + 80
                        pygame.draw.circle(surface, (*color, node_alpha), (x, y), 2)
            
            elif pattern_type == "matrix":
                pass
                # 매트릭스 코드 패턴
                chars = "01"
                font_size = 12
                try:
                    matrix_font = pygame.font.Font(None, font_size)
                except:
                    matrix_font = pygame.font.Font(None, font_size)
                
                for x in range(margin, margin + pattern_width, 15):
                    for y in range(margin, margin + pattern_height, 16):
                        if random.randint(0, 3) == 0:  # 25% 확률로 문자 표시
                            char = random.choice(chars)
                            alpha = int(abs(math.sin(animation_timer * 0.2 + x * 0.1 + y * 0.1)) * 120) + 60
                            char_surface = matrix_font.render(char, True, (*color, alpha))
                            surface.blit(char_surface, (x, y))
            
            elif pattern_type == "grid":
                pass
                # 네온 그리드 패턴
                grid_size = 15
                for x in range(margin, margin + pattern_width, grid_size):
                    for y in range(margin, margin + pattern_height, grid_size):
                        alpha = int(abs(math.sin(animation_timer * 0.1 + x * 0.02 + y * 0.02)) * 60) + 30
                        pygame.draw.rect(surface, (*color, alpha), (x, y, grid_size-1, grid_size-1), 1)
            
            elif pattern_type == "wave":
                pass
                # 사인 웨이브 패턴
                for y in range(margin, margin + pattern_height, 10):
                    points = []
                    for x in range(margin, margin + pattern_width, 5):
                        wave_y = y + math.sin((x + animation_timer) * 0.1) * 5
                        points.append((x, wave_y))
                    
                    if len(points) > 1:
                        alpha = int(abs(math.sin(animation_timer * 0.05 + y * 0.05)) * 80) + 40
                        for i in range(len(points) - 1):
                            pygame.draw.line(surface, (*color, alpha), points[i], points[i+1])
            
            elif pattern_type == "hex":
                pass
                # 육각형 허니컴 패턴
                hex_size = 12
                for x in range(margin, margin + pattern_width, hex_size * 2):
                    for y in range(margin, margin + pattern_height, hex_size * 2):
                        alpha = int(abs(math.sin(animation_timer * 0.12 + x * 0.05 + y * 0.05)) * 100) + 50
                        draw_hexagon(surface, x + hex_size, y + hex_size, hex_size//2, (*color, alpha))
            
            elif pattern_type == "scan":
                pass
                # 스캔라인 패턴
                for i in range(5):
                    scan_y = margin + (animation_timer * 2 + i * 30) % pattern_height
                    alpha = 150 - i * 20
                    if alpha > 0:
                        scan_surface = pygame.Surface((pattern_width, 3), pygame.SRCALPHA)
                        pygame.draw.rect(scan_surface, (*color, alpha), (0, 0, pattern_width, 3))
                        surface.blit(scan_surface, (margin, scan_y))
            
            # 기존 패턴 처리 (하위 호환성)
            elif pattern_type == "diamond":
                cols = max(3, int(pattern_width // 20))
                rows = max(4, int(pattern_height // 25))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        points = [(x, y-size), (x+size, y), (x, y+size), (x-size, y)]
                        pygame.draw.polygon(surface, color, points)
            
            elif pattern_type == "circle":
                cols = max(4, int(pattern_width // 15))
                rows = max(5, int(pattern_height // 20))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        radius = min(spacing_x, spacing_y) * 0.25
                        pygame.draw.circle(surface, color, (int(x), int(y)), int(radius))
            
            elif pattern_type == "star":
                cols = max(3, int(pattern_width // 25))
                rows = max(4, int(pattern_height // 30))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        draw_star(surface, int(x), int(y), int(size), color)
            
            elif pattern_type == "triangle":
                cols = max(4, int(pattern_width // 18))
                rows = max(5, int(pattern_height // 22))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        points = [(x, y-size), (x-size, y+size), (x+size, y+size)]
                        pygame.draw.polygon(surface, color, points)
            
            elif pattern_type == "hexagon":
                cols = max(3, int(pattern_width // 22))
                rows = max(4, int(pattern_height // 25))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        draw_hexagon(surface, int(x), int(y), int(size), color)
            
            elif pattern_type == "cross":
                cols = max(4, int(pattern_width // 20))
                rows = max(5, int(pattern_height // 23))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.25
                        pygame.draw.rect(surface, color, (int(x-size), int(y-size/3), int(size*2), int(size*2/3)))
                        pygame.draw.rect(surface, color, (int(x-size/3), int(y-size), int(size*2/3), int(size*2)))
        
        def draw_star(surface, x, y, size, color):
            points = []
            for i in range(5):
                angle = i * 2 * math.pi / 5 - math.pi/2
                outer_x = x + math.cos(angle) * size
                outer_y = y + math.sin(angle) * size
                points.append((outer_x, outer_y))
                
                angle = (i + 0.5) * 2 * math.pi / 5 - math.pi/2
                inner_x = x + math.cos(angle) * size * 0.4
                inner_y = y + math.sin(angle) * size * 0.4
                points.append((inner_x, inner_y))
            pygame.draw.polygon(surface, color, points)
        
        def draw_hexagon(surface, x, y, size, color):
            points = []
            for i in range(6):
                angle = i * math.pi / 3
                point_x = x + math.cos(angle) * size
                point_y = y + math.sin(angle) * size
                points.append((point_x, point_y))
            pygame.draw.polygon(surface, color, points)
        
        # 네온 파티클 업데이트 및 그리기
        for particle in neon_particles:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            
            # 화면 경계 처리
            if particle["x"] < 0 or particle["x"] > WIDTH:
                particle["vx"] *= -1
            if particle["y"] < 0 or particle["y"] > HEIGHT:
                particle["vy"] *= -1
            
            # 펄스 효과
            pulse = abs(math.sin(animation_timer * particle["pulse_speed"]))
            current_alpha = int(particle["alpha"] * (0.5 + pulse * 0.5))
            
            # 네온 글로우 파티클
            for i in range(2):
                glow_size = particle["size"] + i * 2
                glow_alpha = current_alpha // (i + 1)
                glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*particle["color"], glow_alpha),
                                 (glow_size * 2, glow_size * 2), glow_size)
                SCREEN.blit(glow_surf, (particle["x"] - glow_size * 2, 
                                       particle["y"] - glow_size * 2))
        
        # 스캔라인 효과
        for scan_line in scan_lines:
            scan_line["y"] += scan_line["speed"]
            if scan_line["y"] > HEIGHT:
                scan_line["y"] = -10
            
            # 더 화려한 스캔라인
            for i in range(3):
                scan_alpha = scan_line["alpha"] - i * 10
                if scan_alpha > 0:
                    scan_surf = pygame.Surface((WIDTH, 2 - i), pygame.SRCALPHA)
                    scan_surf.fill((0, 255, 255, scan_alpha))
                    SCREEN.blit(scan_surf, (0, scan_line["y"] + i))
        
        # 카드 부채꼴 그리기
        draw_card_fan()
        
        # 홀로그램 상세 정보 패널 (상단)
        current_char = characters[selected]
        detail_card_width = 480  # 더 넓게
        detail_card_height = 160  # 더 높게
        detail_x = (WIDTH - detail_card_width) // 2
        detail_y = 90  # 제목 아래로 이동
        
        # 홀로그램 상세 정보 패널 배경
        border_color = current_char["card_color"] if current_char["unlocked"] else (100, 100, 100)
        glow_color = current_char.get("glow_color", border_color) if current_char["unlocked"] else (80, 80, 80)
        
        # 다층 글로우 효과
        for glow_layer in range(3, 0, -1):
            glow_intensity = int(abs(math.sin(animation_timer * 0.1 + glow_layer)) * 40) + 30
            glow_size = glow_layer * 6
            glow_surface = pygame.Surface((detail_card_width + glow_size, detail_card_height + glow_size), pygame.SRCALPHA)
            pygame.draw.rect(glow_surface, (*glow_color, glow_intensity // glow_layer), 
                           (0, 0, detail_card_width + glow_size, detail_card_height + glow_size), border_radius=20)
            SCREEN.blit(glow_surface, (detail_x - glow_size//2, detail_y - glow_size//2))
        
        # 메인 패널 배경
        detail_surface = pygame.Surface((detail_card_width, detail_card_height), pygame.SRCALPHA)
        detail_surface.fill((5, 10, 20, 240))  # 매우 어두운 반투명
        
        # 네온 테두리
        pygame.draw.rect(detail_surface, border_color, (0, 0, detail_card_width, detail_card_height), 2, border_radius=15)
        
        # 내부 전자 회로 패턴
        for x in range(0, detail_card_width, 40):
            for y in range(0, detail_card_height, 30):
                if random.randint(0, 5) == 0:  # 랜덤 전자 회로 노드
                    node_alpha = int(abs(math.sin(animation_timer * 0.2 + x * 0.1 + y * 0.1)) * 60) + 20
                    pygame.draw.circle(detail_surface, (*glow_color, node_alpha), (x, y), 1)
        
        SCREEN.blit(detail_surface, (detail_x, detail_y))
        
        if current_char["unlocked"]:
            pass
            # 해금된 캐릭터 - 홀로그램 스타일 정보 표시
            
            # 캐릭터 이름 (네온 글로우 효과)
            name_y = detail_y + 25
            for glow_offset in [(2, 2), (1, 1), (0, 0)]:
                alpha = 100 if glow_offset != (0, 0) else 255
                name_color = (*glow_color, alpha) if glow_offset != (0, 0) else (255, 255, 255)
                name_text = font_subtitle.render(current_char["name"], True, name_color)
                name_rect = name_text.get_rect(center=(detail_x + detail_card_width//2 + glow_offset[0], name_y + glow_offset[1]))
                SCREEN.blit(name_text, name_rect)
            
            # 캐릭터 설명 (홀로그램 스타일)
            desc_y = detail_y + 55
            desc_text = font_desc.render(current_char["description"], True, (180, 220, 255))
            desc_rect = desc_text.get_rect(center=(detail_x + detail_card_width//2, desc_y))
            SCREEN.blit(desc_text, desc_rect)
            
            # 특수 능력 (네온 강조)
            special_y = detail_y + 80
            for glow_offset in [(1, 1), (0, 0)]:
                alpha = 120 if glow_offset != (0, 0) else 255
                special_color = (*glow_color, alpha) if glow_offset != (0, 0) else glow_color
                special_text = font_desc.render(current_char["special"], True, special_color)
                special_rect = special_text.get_rect(center=(detail_x + detail_card_width//2 + glow_offset[0], special_y + glow_offset[1]))
                SCREEN.blit(special_text, special_rect)
            
            # 홀로그램 스탯 표시
            stats_start_y = detail_y + 110
            stats_start_x = detail_x + 60
            stat_width = 120  # 더 넓은 간격
            
            for i, (stat_name, stat_value) in enumerate(current_char["stats"].items()):
                stat_x = stats_start_x + (i * stat_width)
                # 스탯명
                stat_name_text = font_small.render(stat_name, True, glow_color)
                stat_name_rect = stat_name_text.get_rect(center=(stat_x, stats_start_y))
                SCREEN.blit(stat_name_text, stat_name_rect)
                
                # 홀로그램 스탯 바
                bar_width = 80
                bar_height = 6
                bar_x = stat_x - bar_width // 2
                bar_y = stats_start_y + 18
                
                # 홀로그램 배경 바
                draw.rect((10, 20, 30), (bar_x, bar_y, bar_width, bar_height), border_radius=3)
                draw.rect((*glow_color, 80), (bar_x, bar_y, bar_width, bar_height), 1, border_radius=3)
                
                # 네온 값 바 (글로우 효과)
                filled_width = int((stat_value / 8) * bar_width)
                if filled_width > 0:
                    pass
                    # 메인 바
                    draw.rect( glow_color, (bar_x, bar_y, filled_width, bar_height), border_radius=3)
                    
                    # 글로우 효과
                    for glow_layer in range(2, 0, -1):
                        glow_intensity = int(abs(math.sin(animation_timer * 0.15 + i)) * 30) + 50
                        glow_surface = pygame.Surface((filled_width + glow_layer*2, bar_height + glow_layer*2), pygame.SRCALPHA)
                        pygame.draw.rect(glow_surface, (*glow_color, glow_intensity // glow_layer), 
                                       (0, 0, filled_width + glow_layer*2, bar_height + glow_layer*2), border_radius=3)
                        SCREEN.blit(glow_surface, (bar_x - glow_layer, bar_y - glow_layer))
                
                # 홀로그램 숫자 표시
                value_text = font_small.render(str(stat_value), True, glow_color)
                value_rect = value_text.get_rect(center=(stat_x, stats_start_y + 38))
                SCREEN.blit(value_text, value_rect)
        else:
            pass
            # 해금되지 않은 캐릭터 - ???? 표시
            # 캐릭터 이름
            name_text = font_subtitle.render("????", True, (150, 150, 150))
            name_rect = name_text.get_rect(center=(detail_x + detail_card_width//2, detail_y + 25))
            SCREEN.blit(name_text, name_rect)
            
            # 캐릭터 설명
            desc_text = font_desc.render("????????????", True, (120, 120, 120))
            desc_rect = desc_text.get_rect(center=(detail_x + detail_card_width//2, detail_y + 50))
            SCREEN.blit(desc_text, desc_rect)
            
            # 특수 능력
            special_text = font_desc.render("?? ???????", True, (100, 120, 100))
            special_rect = special_text.get_rect(center=(detail_x + detail_card_width//2, detail_y + 75))
            SCREEN.blit(special_text, special_rect)
            
            # 상세 스탯 - ??? 표시
            stats_start_y = detail_y + 100
            stats_start_x = detail_x + 50
            stat_width = 80
            
            for i in range(3):  # 3개의 스탯
                stat_x = stats_start_x + (i * stat_width)
                # 스탯명
                stat_name_text = font_small.render("???", True, (150, 150, 150))
                stat_name_rect = stat_name_text.get_rect(center=(stat_x, stats_start_y))
                SCREEN.blit(stat_name_text, stat_name_rect)
                
                # 스탯 바 (빈 상태)
                bar_width = 60
                bar_height = 8
                bar_x = stat_x - bar_width // 2
                bar_y = stats_start_y + 15
                
                # 배경 바만 표시
                draw.rect((60, 60, 60), (bar_x, bar_y, bar_width, bar_height), border_radius=4)
                
                # 물음표 표시
                value_text = font_small.render("?", True, (150, 150, 150))
                value_rect = value_text.get_rect(center=(stat_x, stats_start_y + 35))
                SCREEN.blit(value_text, value_rect)

        # 홀로그램 캐릭터 선택 인디케이터 - 제거됨
        # indicator_y = HEIGHT - 30
        # total_width = len(characters) * 35  # 더 넓은 간격
        # start_x = (WIDTH - total_width) // 2
        # for i in range(len(characters)):
        #     indicator_x = start_x + i * 35 + 17
        #     char_glow = characters[i].get("glow_color", characters[i]["card_color"])
        #     if i == selected:
        #         # 선택된 인디케이터 (네온 글로우)
        #         color = char_glow if characters[i]["unlocked"] else (120, 120, 120)
        #         # 다층 글로우 효과
        #         for glow_size in [12, 10, 8]:
        #             glow_intensity = int(abs(math.sin(animation_timer * 0.2 + i)) * 50) + 80
        #             if glow_size == 8:
        #                 glow_intensity = 255  # 중심은 완전 불투명
        #             indicator_surface = pygame.Surface((glow_size*2, glow_size*2), pygame.SRCALPHA)
        #             pygame.draw.circle(indicator_surface, (*color, glow_intensity), (glow_size, glow_size), glow_size)
        #             SCREEN.blit(indicator_surface, (indicator_x - glow_size, indicator_y - glow_size))
        #         # 내부 네온 링
        #         draw.circle((255, 255, 255), (indicator_x, indicator_y), 6, 2)
        #     else:
        #         # 비선택 인디케이터
        #         if characters[i]["unlocked"]:
        #             # 해금된 캐릭터 - 어두운 네온
        #             color = tuple(c // 3 for c in char_glow)  # 더 어둑게
        #             draw.circle(color, (indicator_x, indicator_y), 6)
        #             draw.circle( (*color, 150), (indicator_x, indicator_y), 8, 1)
        #         else:
        #             # 잠긴 캐릭터 - 매우 어두운 링
        #             draw.circle((50, 50, 50), (indicator_x, indicator_y), 4, 2)
        
        pygame.display.flip()
        clock.tick(60)
