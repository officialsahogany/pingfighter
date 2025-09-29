import pygame
import sys
import os

from config.language_options import LANGUAGE_CODES, DEFAULT_LANGUAGE
from localization.manager import get_localization_manager
from config.settings_system import get_settings_manager

# 전역 설정 변수들
AVAILABLE_LANGUAGE_CODES = LANGUAGE_CODES
LEGACY_LANGUAGE_MAP = {
    "한국어": "ko",
    "English": "en",
    "english": "en",
    "日本語": "ja",
    "Japanese": "ja",
    "japanese": "ja"
}
LANGUAGE = DEFAULT_LANGUAGE  # 언어 코드는 config.language_options 기준
BGM_VOLUME = 0.7  # 0.0 ~ 1.0
SFX_VOLUME = 0.8  # 0.0 ~ 1.0
FULLSCREEN = False  # True: 전체화면, False: 창모드
CONTROL_MODE = "키보드"  # 키보드, 마우스, 조이패드
CONTROL_OPTIONS = [
    ("키보드", "option.controls.keyboard"),
    ("마우스", "option.controls.mouse"),
    ("조이패드", "option.controls.gamepad"),
]

def save_settings():
    """설정을 파일에 저장"""
    try:
        with open("settings.txt", "w", encoding="utf-8") as f:
            language_code = LANGUAGE if LANGUAGE in AVAILABLE_LANGUAGE_CODES else DEFAULT_LANGUAGE
            f.write(f"LANGUAGE={language_code}\n")
            f.write(f"BGM_VOLUME={BGM_VOLUME}\n")
            f.write(f"SFX_VOLUME={SFX_VOLUME}\n")
            f.write(f"FULLSCREEN={FULLSCREEN}\n")
            f.write(f"CONTROL_MODE={CONTROL_MODE}\n")
    except:
        pass

    try:
        settings_manager = get_settings_manager()
        settings_manager.set_setting('language', 'language', LANGUAGE)
    except Exception:
        pass

def load_settings():
    """파일에서 설정을 불러오기"""
    global LANGUAGE, BGM_VOLUME, SFX_VOLUME, FULLSCREEN, CONTROL_MODE
    
    try:
        if os.path.exists("settings.txt"):
            with open("settings.txt", "r", encoding="utf-8") as f:
                for line in f:
                    if "=" in line:
                        key, value = line.strip().split("=", 1)
                        if key == "LANGUAGE":
                            LANGUAGE = normalize_language_code(value)
                        elif key == "BGM_VOLUME":
                            BGM_VOLUME = float(value)
                        elif key == "SFX_VOLUME":
                            SFX_VOLUME = float(value)
                        elif key == "FULLSCREEN":
                            FULLSCREEN = value == "True"
                        elif key == "CONTROL_MODE":
                            CONTROL_MODE = value
    except:
        pass

    try:
        settings_manager = get_settings_manager()
        LANGUAGE = normalize_language_code(
            settings_manager.get_setting('language', 'language', LANGUAGE)
        )
        settings_manager.set_setting('language', 'language', LANGUAGE)
    except Exception:
        pass

    get_localization_manager().set_language(LANGUAGE)


def normalize_language_code(value: str) -> str:
    if value in AVAILABLE_LANGUAGE_CODES:
        return value
    mapped = LEGACY_LANGUAGE_MAP.get(value, None)
    if mapped:
        return mapped
    return DEFAULT_LANGUAGE


def translate(key: str, fallback: str) -> str:
    return get_localization_manager().get_text(key, fallback)


def get_language_display_name(code: str) -> str:
    return get_localization_manager().get_language_label(code)

def draw_slider(surface, x, y, width, height, value, min_val, max_val, color=(100, 150, 255)):
    """슬라이더 그리기"""
    # 슬라이더 배경
    pygame.draw.rect(surface, (60, 60, 80), (x, y, width, height))
    pygame.draw.rect(surface, (100, 100, 120), (x, y, width, height), 2)
    
    # 슬라이더 핸들 위치 계산
    handle_x = x + (value - min_val) / (max_val - min_val) * (width - 20)
    handle_y = y + height // 2 - 10
    
    # 슬라이더 핸들
    pygame.draw.rect(surface, color, (handle_x, handle_y, 20, 20))
    pygame.draw.rect(surface, (255, 255, 255), (handle_x, handle_y, 20, 20), 2)
    
    # 값 표시
    font = pygame.font.Font("NanumSquareR.ttf", 16)
    value_text = font.render(f"{int(value * 100)}%", True, (255, 255, 255))
    surface.blit(value_text, (x + width + 10, y + height // 2 - 8))

def draw_button(surface, x, y, width, height, text, selected=False, color=(100, 150, 255)):
    """버튼 그리기"""
    # 버튼 배경
    if selected:
        pygame.draw.rect(surface, color, (x, y, width, height))
        pygame.draw.rect(surface, (255, 255, 255), (x, y, width, height), 3)
    else:
        pygame.draw.rect(surface, (60, 60, 80), (x, y, width, height))
        pygame.draw.rect(surface, (100, 100, 120), (x, y, width, height), 2)
    
    # 텍스트
    font = pygame.font.Font("NanumSquareR.ttf", 18)
    text_surface = font.render(text, True, (255, 255, 255))
    text_rect = text_surface.get_rect(center=(x + width // 2, y + height // 2))
    surface.blit(text_surface, text_rect)

def show_options_menu(screen, width, height):
    """옵션 메뉴 표시"""
    global LANGUAGE, BGM_VOLUME, SFX_VOLUME, FULLSCREEN, CONTROL_MODE
    
    # 설정 불러오기
    load_settings()
    localization_manager = get_localization_manager()
    localization_manager.set_language(LANGUAGE)
    
    # 메인 게임의 CONTROL_MODE도 업데이트
    import bosspong
    bosspong.CONTROL_MODE = CONTROL_MODE
    
    # 전체화면 전환 함수 import
    import bosspong
    
    # 사운드 로드 (메인 게임에서 사용하는 사운드들)
    try:
        SOUND_BUTTON_CLICK = pygame.mixer.Sound("sounds/button_click.wav")
        SOUND_BUTTON_HOVER = pygame.mixer.Sound("sounds/button_hover.wav")
    except:
        # 사운드 파일이 없으면 빈 사운드 생성
        SOUND_BUTTON_CLICK = pygame.mixer.Sound(buffer=bytes([0]*44))
        SOUND_BUTTON_HOVER = pygame.mixer.Sound(buffer=bytes([0]*44))
    
    # 메뉴 상태
    selected_category = 0  # 0: 언어, 1: 사운드, 2: 화면, 3: 조작
    selected_option = 0  # 각 카테고리 내에서 선택된 옵션
    category_keys = ["language", "sound", "screen", "controls"]
    selected_option = 1 if FULLSCREEN else 0
    
    # 애니메이션 변수
    animation_timer = 0
    particles = []
    
    # 색상 팔레트
    color_palettes = [
        [(20, 12, 35), (35, 25, 65), (50, 35, 95)],  # 보라빛
        [(35, 20, 12), (55, 35, 25), (75, 50, 35)],  # 주황빛
        [(12, 35, 20), (25, 55, 35), (35, 75, 50)],  # 초록빛
        [(35, 12, 20), (55, 25, 35), (75, 35, 50)]   # 붉은빛
    ]
    
    while True:
        animation_timer += 1
        
        # 배경 그리기 (메인 메뉴와 동일한 스타일)
        color_cycle = (animation_timer // 540) % len(color_palettes)
        current_palette = color_palettes[color_cycle]
        next_palette = color_palettes[(color_cycle + 1) % len(color_palettes)]
        
        transition_ratio = (animation_timer % 540) / 540
        transition_ratio = (1 - math.cos(transition_ratio * math.pi)) / 2
        
        for y in range(height):
            color_ratio = y / height
            time_factor = math.sin(animation_timer * 0.005) * 0.15 + 0.85
            
            r1, g1, b1 = current_palette[0]
            r2, g2, b2 = next_palette[0]
            r = int(r1 + (r2 - r1) * transition_ratio)
            g = int(g1 + (g2 - g1) * transition_ratio)
            b = int(b1 + (b2 - b1) * transition_ratio)
            
            r = int(r + color_ratio * (current_palette[2][0] - r) * time_factor * 0.6)
            g = int(g + color_ratio * (current_palette[2][1] - g) * time_factor * 0.6)
            b = int(b + color_ratio * (current_palette[2][2] - b) * time_factor * 0.6)
            
            r = max(10, min(80, r))
            g = max(10, min(80, g))
            b = max(10, min(80, b))
            
            pygame.draw.line(screen, (r, g, b), (0, y), (width, y))
        
        # 제목
        title_font = pygame.font.Font("NanumSquareB.ttf", 48)
        title_value = translate("option.title", "옵션")
        title_text = title_font.render(title_value, True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(width // 2, 80))
        
        # 제목 그림자
        title_shadow = title_font.render(title_value, True, (100, 100, 100))
        screen.blit(title_shadow, (title_rect.x + 2, title_rect.y + 2))
        screen.blit(title_text, title_rect)
        
        # 카테고리 버튼들
        categories = [translate(f"option.category.{key}", key.title()) for key in category_keys]
        category_width = 120
        category_height = 40
        category_spacing = 20
        total_width = len(categories) * category_width + (len(categories) - 1) * category_spacing
        start_x = (width - total_width) // 2
        
        for i, category in enumerate(categories):
            x = start_x + i * (category_width + category_spacing)
            y = 150
            selected = (i == selected_category)
            draw_button(screen, x, y, category_width, category_height, category, selected)
        
        # 옵션 내용 영역
        content_y = 220
        content_height = 300
        
        # 선택된 카테고리에 따른 내용 표시
        if selected_category == 0:  # 언어
            for i, language_code in enumerate(AVAILABLE_LANGUAGE_CODES):
                x = width // 2 - 100
                y = content_y + i * 60
                selected = (LANGUAGE == language_code)
                draw_button(
                    screen,
                    x,
                    y,
                    200,
                    50,
                    get_language_display_name(language_code),
                    selected,
                )
                
        elif selected_category == 1:  # 사운드
            # BGM 볼륨
            font = pygame.font.Font("NanumSquareR.ttf", 20)
            bgm_text = font.render(translate("option.sound.bgm_volume", "BGM"), True, (255, 255, 255))
            screen.blit(bgm_text, (width // 2 - 200, content_y))
            draw_slider(screen, width // 2 - 150, content_y + 30, 300, 20, BGM_VOLUME, 0.0, 1.0)
            
            # 효과음 볼륨
            sfx_text = font.render(translate("option.sound.sfx_volume", "SFX"), True, (255, 255, 255))
            screen.blit(sfx_text, (width // 2 - 200, content_y + 80))
            draw_slider(screen, width // 2 - 150, content_y + 110, 300, 20, SFX_VOLUME, 0.0, 1.0)
            
        elif selected_category == 2:  # 화면
            modes = [
                (0, translate("option.screen.windowed", "Windowed")),
                (1, translate("option.screen.fullscreen", "Fullscreen"))
            ]
            for i, mode in enumerate(modes):
                x = width // 2 - 100
                y = content_y + i * 60
                selected = (selected_option == i)  # 선택된 옵션으로 변경
                draw_button(screen, x, y, 200, 50, mode[1], selected)
                
            # 안내 텍스트
            guide_font = pygame.font.Font("NanumSquareR.ttf", 16)
            guide_text = guide_font.render(
                translate("option.screen.guide", "Use ↑↓ to choose, Space/Enter to apply"),
                True,
                (200, 200, 200)
            )
            screen.blit(guide_text, (width // 2 - 150, content_y + 150))
                
        elif selected_category == 3:  # 조작
            for i, (canonical_value, translation_key) in enumerate(CONTROL_OPTIONS):
                x = width // 2 - 100
                y = content_y + i * 60
                control_label = translate(translation_key, canonical_value)
                selected = (CONTROL_MODE == canonical_value)
                draw_button(screen, x, y, 200, 50, control_label, selected)
            
            # 마우스 조작 안내 텍스트
            mouse_hint = translate("option.controls.mouse_hint", "Mouse hint")
            if CONTROL_MODE == "마우스":
                guide_font = pygame.font.Font("NanumSquareR.ttf", 14)
                guide_text = guide_font.render(mouse_hint, True, (200, 200, 200))
                screen.blit(guide_text, (width // 2 - 200, content_y + 150))
        
        # 뒤로가기 버튼
        back_button_rect = pygame.Rect(50, height - 80, 120, 40)
        draw_button(
            screen,
            back_button_rect.x,
            back_button_rect.y,
            back_button_rect.width,
            back_button_rect.height,
            translate("option.back", "Back")
        )
        
        # 적용 버튼
        apply_button_rect = pygame.Rect(width - 170, height - 80, 120, 40)
        draw_button(
            screen,
            apply_button_rect.x,
            apply_button_rect.y,
            apply_button_rect.width,
            apply_button_rect.height,
            translate("option.apply", "Apply")
        )
        
        pygame.display.flip()
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
                
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return
                    
                elif event.key == pygame.K_LEFT:
                    if selected_category > 0:
                        selected_category -= 1
                        SOUND_BUTTON_HOVER.play()
                elif event.key == pygame.K_RIGHT:
                    if selected_category < len(category_keys) - 1:
                        selected_category += 1
                        SOUND_BUTTON_HOVER.play()
                        
                elif event.key == pygame.K_UP:
                    if selected_category == 0:  # 언어
                        if LANGUAGE not in AVAILABLE_LANGUAGE_CODES:
                            LANGUAGE = DEFAULT_LANGUAGE
                        current_index = AVAILABLE_LANGUAGE_CODES.index(LANGUAGE)
                        LANGUAGE = AVAILABLE_LANGUAGE_CODES[(current_index - 1) % len(AVAILABLE_LANGUAGE_CODES)]
                        get_localization_manager().set_language(LANGUAGE)
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 2:  # 화면
                        selected_option = (selected_option - 1) % 2
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 3:  # 조작
                        controls = [value for value, _ in CONTROL_OPTIONS]
                        current_index = controls.index(CONTROL_MODE)
                        CONTROL_MODE = controls[(current_index - 1) % len(controls)]
                        bosspong.CONTROL_MODE = CONTROL_MODE  # 메인 게임 업데이트
                        SOUND_BUTTON_HOVER.play()
                        
                elif event.key == pygame.K_DOWN:
                    if selected_category == 0:  # 언어
                        if LANGUAGE not in AVAILABLE_LANGUAGE_CODES:
                            LANGUAGE = DEFAULT_LANGUAGE
                        current_index = AVAILABLE_LANGUAGE_CODES.index(LANGUAGE)
                        LANGUAGE = AVAILABLE_LANGUAGE_CODES[(current_index + 1) % len(AVAILABLE_LANGUAGE_CODES)]
                        get_localization_manager().set_language(LANGUAGE)
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 2:  # 화면
                        selected_option = (selected_option + 1) % 2
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 3:  # 조작
                        controls = [value for value, _ in CONTROL_OPTIONS]
                        current_index = controls.index(CONTROL_MODE)
                        CONTROL_MODE = controls[(current_index + 1) % len(controls)]
                        bosspong.CONTROL_MODE = CONTROL_MODE  # 메인 게임 업데이트
                        SOUND_BUTTON_HOVER.play()
                        
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    if selected_category == 2:  # 화면 카테고리에서
                        # 선택된 옵션에 따라 화면 모드 변경
                        new_fullscreen = (selected_option == 1)
                        if FULLSCREEN != new_fullscreen:
                            FULLSCREEN = new_fullscreen
                            bosspong.toggle_fullscreen()
                        SOUND_BUTTON_CLICK.play()
                    else:
                        SOUND_BUTTON_CLICK.play()
                        save_settings()
                        return
                    
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mouse_x, mouse_y = pygame.mouse.get_pos()
                
                # 카테고리 버튼 클릭
                for i, category in enumerate(categories):
                    x = start_x + i * (category_width + category_spacing)
                    y = 150
                    if x <= mouse_x <= x + category_width and y <= mouse_y <= y + category_height:
                        selected_category = i
                        # 화면 카테고리로 이동할 때 현재 화면 모드에 맞게 selected_option 설정
                        if i == 2:  # 화면 카테고리
                            selected_option = 1 if FULLSCREEN else 0
                        SOUND_BUTTON_HOVER.play()
                        break
                
                # 뒤로가기 버튼 클릭
                if back_button_rect.collidepoint(mouse_x, mouse_y):
                    SOUND_BUTTON_CLICK.play()
                    return
                    
                # 적용 버튼 클릭
                if apply_button_rect.collidepoint(mouse_x, mouse_y):
                    SOUND_BUTTON_CLICK.play()
                    save_settings()
                    return
                
                # 슬라이더 클릭 (사운드 카테고리)
                if selected_category == 1:
                    if content_y + 30 <= mouse_y <= content_y + 50:  # BGM 슬라이더
                        if width // 2 - 150 <= mouse_x <= width // 2 + 150:
                            ratio = (mouse_x - (width // 2 - 150)) / 300
                            BGM_VOLUME = max(0.0, min(1.0, ratio))
                    elif content_y + 110 <= mouse_y <= content_y + 130:  # SFX 슬라이더
                        if width // 2 - 150 <= mouse_x <= width // 2 + 150:
                            ratio = (mouse_x - (width // 2 - 150)) / 300
                            SFX_VOLUME = max(0.0, min(1.0, ratio))
                
                # 옵션 버튼 클릭
                if selected_category == 0:  # 언어
                    for i, language_code in enumerate(AVAILABLE_LANGUAGE_CODES):
                        x = width // 2 - 100
                        y = content_y + i * 60
                        if x <= mouse_x <= x + 200 and y <= mouse_y <= y + 50:
                            LANGUAGE = language_code
                            get_localization_manager().set_language(LANGUAGE)
                            SOUND_BUTTON_CLICK.play()
                            break
                            
                elif selected_category == 2:  # 화면
                    modes = [
                        (0, translate("option.screen.windowed", "Windowed")),
                        (1, translate("option.screen.fullscreen", "Fullscreen"))
                    ]
                    for i, mode in enumerate(modes):
                        x = width // 2 - 100
                        y = content_y + i * 60
                        if x <= mouse_x <= x + 200 and y <= mouse_y <= y + 50:
                            selected_option = i
                            SOUND_BUTTON_CLICK.play()
                            # 선택된 옵션에 따라 화면 모드 변경
                            new_fullscreen = (selected_option == 1)
                            if FULLSCREEN != new_fullscreen:
                                FULLSCREEN = new_fullscreen
                                bosspong.toggle_fullscreen()
                            break
                            
                elif selected_category == 3:  # 조작
                    for i, (canonical_value, translation_key) in enumerate(CONTROL_OPTIONS):
                        control_label = translate(translation_key, canonical_value)
                        x = width // 2 - 100
                        y = content_y + i * 60
                        if x <= mouse_x <= x + 200 and y <= mouse_y <= y + 50:
                            CONTROL_MODE = canonical_value
                            bosspong.CONTROL_MODE = CONTROL_MODE  # 메인 게임 업데이트
                            SOUND_BUTTON_CLICK.play()
                            break

# 수학 모듈 import 추가
import math
